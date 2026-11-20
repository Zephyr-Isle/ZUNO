package com.zuno.wallpaper.wallpaper.gl

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * 深度视差渲染器：单次全屏 pass 的位移映射（displacement mapping）。
 *
 * 渲染管线刻意保持最小：
 * - 一个 program、两张纹理、一个全屏 quad、零顶点缓冲对象（4 顶点的 client array 开销可忽略）；
 * - 每帧只有一个 draw call + 6 次 uniform 上传，无任何临时对象分配（GC 零压力）；
 * - 不使用 Flutter：Flutter 的 raster 线程与 ImGUI 合成对 60fps 壁纸而言是多余的中间层，
 *   视差效果一张 GLSL 位移映射就够了。
 *
 * 内置着色器（也可被包内 shader.glsl 覆盖，契约见 README）：
 *   用深度图 (d-0.5) 缩放倾斜向量，产生“近景反向于背景移动”的视差。
 */
class ParallaxRenderer(
    private val colorImagePath: String,
    private val depthImagePath: String,
    private val customShaderPath: String?,
) {

    companion object {
        // GLSL ES 1.00（GLES20 环境强制）。Y 方向在顶点着色器里翻转（图像坐标 → GL 坐标）。
        const val VERTEX_SRC = """
            attribute vec2 aPos;
            varying vec2 vUV;
            void main() {
                vec2 uv = (aPos + 1.0) * 0.5;
                vUV = vec2(uv.x, 1.0 - uv.y);
                gl_Position = vec4(aPos, 0.0, 1.0);
            }
        """

        const val FRAGMENT_SRC = """
            precision mediump float;
            uniform sampler2D sColor;
            uniform sampler2D sDepth;
            uniform vec2 uTilt;             // 低通滤波后的设备倾斜，[-1,1]
            uniform float uStrength;        // 视差强度（UV 单位的最大位移）
            uniform float uZoom;            // 过扫描系数，防止位移采样越界
            uniform float uAspect;          // 宽高比，保证横竖屏位移速度一致
            varying vec2 vUV;
            void main() {
                float depth = texture2D(sDepth, vUV).r;   // 0=远 1=近
                vec2 center = vec2(0.5, 0.5);
                vec2 base = center + (vUV - center) * uZoom;
                vec2 shift = vec2(uTilt.x / uAspect, uTilt.y)
                             * uStrength * (depth - 0.5) * 2.0;
                gl_FragColor = texture2D(sColor, base - shift);
            }
        """
    }

    private var program = 0
    private var colorTexture = 0
    private var depthTexture = 0
    private var width = 0
    private var height = 0

    private lateinit var quad: FloatBuffer

    // uniform location 缓存：每帧查 location 是 GL 常见反模式（字符串查找开销）。
    private var uPosLoc = 0
    private var uColorLoc = 0
    private var uDepthLoc = 0
    private var uTiltLoc = 0
    private var uStrengthLoc = 0
    private var uZoomLoc = 0
    private var uAspectLoc = 0

    // 主线程（onConfigChanged）写、GL 线程每帧 draw 读：volatile 保证可见性。
    @Volatile private var strength = 0.06f

    /** 在 GL 线程上调用：编译 program、上传纹理。自定义 shader 编译失败时回退内置着色器。 */
    fun setup(viewW: Int, viewH: Int) {
        width = viewW
        height = viewH

        val fragment = loadFragmentSource()
        program = try {
            ShaderUtil.linkProgram(VERTEX_SRC, fragment)
        } catch (t: Throwable) {
            Log.e("ZunoGL", "custom shader failed, fallback to builtin", t)
            program = 0
            ShaderUtil.linkProgram(VERTEX_SRC, FRAGMENT_SRC)
        }
        GLES20.glUseProgram(program)

        // 全屏 quad（TRIANGLE_STRIP）：(-1,-1) (1,-1) (-1,1) (1,1)。
        quad = ByteBuffer.allocateDirect(4 * 2 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .apply {
                put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
                position(0)
            }

        uPosLoc = GLES20.glGetAttribLocation(program, "aPos")
        uColorLoc = GLES20.glGetUniformLocation(program, "sColor")
        uDepthLoc = GLES20.glGetUniformLocation(program, "sDepth")
        uTiltLoc = GLES20.glGetUniformLocation(program, "uTilt")
        uStrengthLoc = GLES20.glGetUniformLocation(program, "uStrength")
        uZoomLoc = GLES20.glGetUniformLocation(program, "uZoom")
        uAspectLoc = GLES20.glGetUniformLocation(program, "uAspect")

        colorTexture = uploadTexture(colorImagePath, grayscale = false)
        depthTexture = uploadTexture(depthImagePath, grayscale = true)
        ShaderUtil.checkGlError("ParallaxRenderer.setup")
    }

    /**
     * 包内 shader.glsl（GLSL ES 1.00 片段着色器）优先；
     * 必须保留与内置一致的 uniform 契约（sColor/sDepth/uTilt/uStrength/uZoom/uAspect）。
     */
    private fun loadFragmentSource(): String {
        val custom = customShaderPath?.let { path ->
            val f = File(path)
            if (f.isFile) {
                try {
                    f.readText()
                } catch (t: Throwable) {
                    Log.w("ZunoGL", "read shader.glsl failed, using builtin", t)
                    null
                }
            } else {
                null
            }
        }
        return custom ?: FRAGMENT_SRC
    }

    private fun uploadTexture(path: String, grayscale: Boolean): Int {
        val bitmap = decodeBitmap(path, grayscale)
            ?: throw IllegalStateException("texture missing: $path")
        val texture = IntArray(1)
        GLES20.glGenTextures(1, texture, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture[0])
        // CLAMP_TO_EDGE：位移采样只会越界几毫米，钳制比镜像便宜且无视觉差异。
        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR.toFloat())
        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE.toFloat())
        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE.toFloat())
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        bitmap.recycle()
        return texture[0]
    }

    /**
     * 深度图用 RGB_565 解码（灰度信息 256 级足够，显存减半）；
     * 超过 GPU 最大纹理尺寸时按比例缩放（GL_MAX_TEXTURE_SIZE 查询一次）。
     */
    private fun decodeBitmap(path: String, grayscale: Boolean): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0) return null
        val max = IntArray(1).also {
            GLES20.glGetIntegerv(GLES20.GL_MAX_TEXTURE_SIZE, it, 0)
        }[0]
        // 降采样：sample 必须满足 out/sample <= max（原条件写成"半尺寸 >= max 才继续
        // 加倍"，会漏掉 1.5x~2x 超限的图，导致 texImage2D 上传失败、壁纸黑屏）。
        var sample = 1
        while (bounds.outWidth / sample > max || bounds.outHeight / sample > max) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = if (grayscale) Bitmap.Config.RGB_565 else Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(path, opts)
    }

    fun setStrength(value: Float) {
        strength = value.coerceIn(0f, 0.2f)
    }

    /** 每帧调用（GL 线程）。tilt 为低通滤波后的倾斜 [-1,1]（由 DepthWallpaperEngine 提供）。 */
    fun draw(tiltX: Float, tiltY: Float) {
        GLES20.glViewport(0, 0, width, height)
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)

        quad.position(0)
        GLES20.glEnableVertexAttribArray(uPosLoc)
        GLES20.glVertexAttribPointer(uPosLoc, 2, GLES20.GL_FLOAT, false, 0, quad)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, colorTexture)
        if (uColorLoc >= 0) GLES20.glUniform1i(uColorLoc, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, depthTexture)
        if (uDepthLoc >= 0) GLES20.glUniform1i(uDepthLoc, 1)

        // location == -1 表示 uniform 被编译器裁剪（自定义 shader 可能未声明），GL 规范允许安全忽略。
        if (uTiltLoc >= 0) GLES20.glUniform2f(uTiltLoc, tiltX, tiltY)
        if (uStrengthLoc >= 0) GLES20.glUniform1f(uStrengthLoc, strength)
        // 过扫描：位移最大幅度 = strength，缩放 1 + 2*strength 保证任何位移都落在纹理内。
        if (uZoomLoc >= 0) GLES20.glUniform1f(uZoomLoc, 1f + strength * 2f)
        if (uAspectLoc >= 0 && height > 0) GLES20.glUniform1f(uAspectLoc, width.toFloat() / height.toFloat())

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(uPosLoc)
        ShaderUtil.checkGlError("ParallaxRenderer.draw")
    }

    fun teardown() {
        if (colorTexture != 0) GLES20.glDeleteTextures(1, intArrayOf(colorTexture), 0)
        if (depthTexture != 0) GLES20.glDeleteTextures(1, intArrayOf(depthTexture), 0)
        if (program != 0) GLES20.glDeleteProgram(program)
        colorTexture = 0
        depthTexture = 0
        program = 0
    }
}
