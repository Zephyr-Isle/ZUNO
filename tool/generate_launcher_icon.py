# ZUNO 启动图标生成器（Pillow，一切从两张设计稿图层派生）。
#
# 用法：python -I tool/generate_launcher_icon.py
#
# 主源（设计稿，不要手改；换图标只替换这两个文件后重跑本脚本）：
#   assets/icon/app_icon_background_src.png  深空底：2000×2000 圆角矩形（边缘带 1px 高光描边）
#   assets/icon/app_icon_foreground_src.png  玻璃 Z：1748×1648 透明图层（自带投影）
#
# 产出：
#   assets/icon/app_icon.png             合成稿（flutter_launcher_icons 的 image_path）
#   assets/icon/app_icon_foreground.png  自适应前景（内容落在 72dp 遮罩安全区）
#   mipmap-*/ic_launcher.png             旧版圆角方图标（48/72/96/144/192）
#   mipmap-*/ic_launcher_round.png       旧版圆形图标
#   mipmap-*/ic_launcher_foreground.png  自适应前景（108dp 单位）
#   mipmap-anydpi-v26/ic_launcher(.round).xml  自适应图标 XML
#   res/values/colors.xml               自适应图标背景色
#
# 改完本脚本还要再跑一次 `dart run flutter_launcher_icons`：
# 它负责 @mipmap/launcher_icon（清单里的 android:icon），本脚本负责
# android:roundIcon 与旧版 ic_launcher*。

import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(ROOT, "assets", "icon")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

BG_SRC = os.path.join(ASSETS, "app_icon_background_src.png")
FG_SRC = os.path.join(ASSETS, "app_icon_foreground_src.png")

BASE = 2000        # 设计稿坐标系边长
# 前景图层在 2000 画布上的落点：由两张源图与既有合成稿逐像素对齐得出（alpha 误差 0）。
FG_POS = (141, 127)
ADAPTIVE_SCALE = 0.82  # Z 最远点距中心 0.384 画布宽 → 0.315，落在 72dp 圆形遮罩（0.333）内
ROUND_SCALE = 1.10     # 圆形图标：放大到把圆角与高光描边整个裁出内切圆


def _load() -> tuple[Image.Image, Image.Image]:
    bg = Image.open(BG_SRC).convert("RGBA")
    fg = Image.open(FG_SRC).convert("RGBA")
    if bg.size != (BASE, BASE):
        raise SystemExit(f"{BG_SRC} 必须是 {BASE}×{BASE}，实际 {bg.size}")
    return bg, fg


def _composite(bg: Image.Image, fg: Image.Image) -> Image.Image:
    out = bg.copy()
    out.alpha_composite(fg, FG_POS)
    return out


def _edge_colour(bg: Image.Image) -> tuple[int, int, int]:
    """背景带中位色：自适应图标外框与 `zuno_icon_bg` 用它，保证合成稿边缘无缝。"""
    w, h = bg.size
    px = bg.load()
    vals: list[tuple[int, int, int]] = []
    for y in range(80, h - 80, 8):
        for x in list(range(70, 120, 5)) + list(range(w - 120, w - 70, 5)):
            r, g, b, a = px[x, y]
            if a > 250:
                vals.append((r, g, b))
    for x in range(80, w - 80, 8):
        for y in list(range(70, 120, 5)) + list(range(h - 120, h - 70, 5)):
            r, g, b, a = px[x, y]
            if a > 250:
                vals.append((r, g, b))
    if not vals:
        return (3, 4, 30)
    vals.sort(key=lambda c: c[0] + c[1] + c[2])
    return vals[len(vals) // 2]


def _resize_premul(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """预乘 alpha 再缩放，避免透明角的白边渗进圆角。"""
    return im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def _scaled(im: Image.Image, factor: float) -> Image.Image:
    """以中心为原点整体缩放，再裁回原画布。"""
    w, h = im.size
    big = _resize_premul(im, (round(w * factor), round(h * factor)))
    left = (big.width - w) // 2
    top = (big.height - h) // 2
    return big.crop((left, top, left + w, top + h))


def _adaptive_foreground(
    fg: Image.Image, colour: tuple[int, int, int], size: int
) -> Image.Image:
    """自适应前景：纯色底 + 只叠玻璃 Z（自带投影），按安全区缩放居中。

    刻意不铺背景图层的像素：它沿圆角有 1px 高光描边，按矩形内缩裁不掉四角的
    弧线，缩到 82% 后会留下四条白弧。背景本身就是近纯色，用中位色铺底与
    合成稿边缘完全一致，遮罩形状（圆形/方圆形/水滴）怎么裁都不会切到 Z 的尖角。
    """
    layer = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    layer.alpha_composite(fg, FG_POS)
    side = max(1, round(size * ADAPTIVE_SCALE))
    out = Image.new("RGBA", (size, size), colour + (255,))
    out.alpha_composite(_resize_premul(layer, (side, side)),
                        ((size - side) // 2, (size - side) // 2))
    return out


def _round_icon(comp: Image.Image, size: int) -> Image.Image:
    """圆形图标：整体放大 ROUND_SCALE 后按内切圆裁剪。"""
    big = _scaled(comp, ROUND_SCALE)
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, big.size[0] - 1, big.size[1] - 1], fill=255)
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    out.paste(big, (0, 0), mask)
    return _resize_premul(out, (size, size))


def _save(img: Image.Image, rel: str, size: int) -> None:
    path = os.path.join(RES, rel.replace("/", os.sep))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    _resize_premul(img, (size, size)).save(path, "PNG")
    print("[ok]", rel, size)


def _save_asset(img: Image.Image, name: str, size: int) -> None:
    os.makedirs(ASSETS, exist_ok=True)
    out = img if img.size == (size, size) else _resize_premul(img, (size, size))
    out.save(os.path.join(ASSETS, name), "PNG")
    print("[ok] assets/icon/" + name, size)


def main() -> None:
    bg, fg = _load()
    comp = _composite(bg, fg)
    colour = _edge_colour(bg)
    print("[..] 背景色 #%02X%02X%02X" % colour)

    # flutter_launcher_icons 的输入：合成稿 + 自适应背景/前景。
    # 前景不透明，背景层实际看不到，但保持与主题同色，避免仓库里留旧配色。
    _save_asset(comp, "app_icon.png", BASE)
    _save_asset(Image.new("RGBA", (1024, 1024), colour + (255,)), "app_icon_background.png", 1024)
    _save_asset(_adaptive_foreground(fg, colour, BASE), "app_icon_foreground.png", 1024)

    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    fg_units = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

    round_img = _round_icon(comp, BASE)
    fg_img = _adaptive_foreground(fg, colour, BASE)

    for d, size in densities.items():
        _save(comp, f"mipmap-{d}/ic_launcher.png", size)
        _save(round_img, f"mipmap-{d}/ic_launcher_round.png", size)
    for d, size in fg_units.items():
        _save(fg_img, f"mipmap-{d}/ic_launcher_foreground.png", size)

    # 自适应图标 XML（v26+）：背景纯色，前景为上面的 PNG。
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/zuno_icon_bg"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(adaptive)
        print("[ok] mipmap-anydpi-v26/" + name)

    colors = os.path.join(RES, "values", "colors.xml")
    os.makedirs(os.path.dirname(colors), exist_ok=True)
    with open(colors, "w", encoding="utf-8", newline="\n") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="zuno_icon_bg">#{colour[0]:02X}{colour[1]:02X}{colour[2]:02X}</color>\n'
            "</resources>\n"
        )
    print("[ok] values/colors.xml")


if __name__ == "__main__":
    main()
