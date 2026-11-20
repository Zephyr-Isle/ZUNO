package com.zuno.wallpaper.wallpaper

/**
 * 性能档位（高 / 中 / 低），默认“中”。
 *
 * 各渲染路径的映射规则（与产品规格一致）：
 * - 视频壁纸：HIGH/MEDIUM 正常播放；LOW 降级为“静态首帧”（解码器无法按帧节流，
 *   最省电且可预期的降级方式就是停止解码）。
 * - 深度视差壁纸：30 / 20 / 15 fps（[depthFps]）。
 * - HTML 壁纸：HIGH 不限制（跟随 vsync）、MEDIUM 限制到 ~30fps、LOW 冻结 CSS 动画 + ~15fps。
 */
enum class PerformanceTier(val depthFps: Int, val htmlFrameIntervalMs: Long, val htmlFrozen: Boolean) {
    LOW(depthFps = 15, htmlFrameIntervalMs = 66, htmlFrozen = true),
    MEDIUM(depthFps = 20, htmlFrameIntervalMs = 33, htmlFrozen = false),
    HIGH(depthFps = 30, htmlFrameIntervalMs = 16, htmlFrozen = false);

    companion object {
        fun parse(raw: String?): PerformanceTier = when (raw?.lowercase()) {
            "low" -> LOW
            "high" -> HIGH
            else -> MEDIUM
        }
    }
}
