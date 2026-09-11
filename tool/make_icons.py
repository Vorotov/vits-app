#!/usr/bin/env python3
"""Generates every app-icon asset from one vector description.

The mark is the product's own signature: three pill bars, the middle one
broken by a gap. That is the Цикли gantt reduced until it still reads at
29px — a schedule with an off-week in it, which is the one thing this app
does that a to-do list does not.

Two colours, both tokens, no third: BqColors.accent on the ground and
BqColors.paper on the bars (lib/core/theme/tokens.dart:46 and :19). No
gradient and no shadow, because the design system has no elevation anywhere
and an icon is not the place to introduce the first one.

Everything is drawn at 4x and downsampled with LANCZOS, so the pill ends stay
clean at 20px. Run it from the repo root:

    python3 tool/make_icons.py
"""

from __future__ import annotations

import json
import pathlib
import shutil

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
ACCENT = (0x4A, 0x4E, 0x7C)   # BqColors.accent
PAPER = (0xF7, 0xF6, 0xF3)    # BqColors.paper

SS = 4          # supersampling factor
BASE = 1024     # the canvas every geometry constant below is expressed in

# Geometry on a 1024 canvas. The block is centred both ways. The bars start at
# DIFFERENT x positions on purpose: left-aligned pills read as a hamburger menu
# or a text-align control, which is what the first draft looked like. Staggered
# starts read as bars on a timeline, which is what the app actually shows.
BAR_H = 132
ROW_GAP = 76
ROWS = [
    [(190, 700)],
    [(300, 560), (640, 834)],  # on, off, on — the gap is the whole point
    [(236, 640)],
]
_BLOCK_H = len(ROWS) * BAR_H + (len(ROWS) - 1) * ROW_GAP
Y0 = (BASE - _BLOCK_H) // 2

# Android adaptive icons guarantee only the central 66dp of a 108dp canvas.
# The mark's bounding box spans ~83% of the full-bleed canvas diagonally, so
# the foreground layer draws it smaller. 0.72 leaves margin over the 0.74
# that would exactly touch the safe circle.
ADAPTIVE_SCALE = 0.72


def draw_mark(size: int, background: tuple | None, scale: float = 1.0) -> Image.Image:
    """Renders the mark at `size` px. `background=None` gives transparency."""
    px = size * SS
    mode = "RGB" if background else "RGBA"
    fill = background if background else (0, 0, 0, 0)
    img = Image.new(mode, (px, px), fill)
    d = ImageDraw.Draw(img)
    k = px / BASE * scale
    off = (px - BASE * k) / 2  # re-centre after scaling
    for row, segments in enumerate(ROWS):
        top = Y0 + row * (BAR_H + ROW_GAP)
        for x_start, x_end in segments:
            box = [
                off + x_start * k,
                off + top * k,
                off + x_end * k,
                off + (top + BAR_H) * k,
            ]
            d.rounded_rectangle(box, radius=BAR_H * k / 2, fill=PAPER)
    return img.resize((size, size), Image.LANCZOS)


def write(img: Image.Image, path: pathlib.Path, *, flatten: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if flatten and img.mode != "RGB":
        img = img.convert("RGB")
    img.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


def build_ios() -> None:
    """Every size Contents.json names. It named fifteen and one existed."""
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((catalog / "Contents.json").read_text())
    wanted: dict[str, int] = {}
    for entry in contents["images"]:
        side = float(entry["size"].split("x")[0])
        px = round(side * float(entry["scale"].rstrip("x")))
        wanted[entry["filename"]] = px
    print("iOS app icon:")
    for filename, px in sorted(wanted.items(), key=lambda kv: kv[1]):
        # App Store Connect rejects an icon with an alpha channel outright.
        write(draw_mark(px, ACCENT), catalog / filename, flatten=True)


def build_android() -> None:
    res = ROOT / "android/app/src/main/res"
    print("Android legacy launcher icon:")
    for bucket, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                       ("xxhdpi", 144), ("xxxhdpi", 192)]:
        write(draw_mark(px, ACCENT), res / f"mipmap-{bucket}/ic_launcher.png",
              flatten=True)

    print("Android adaptive icon foreground:")
    for bucket, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
                       ("xxhdpi", 324), ("xxxhdpi", 432)]:
        write(draw_mark(px, None, ADAPTIVE_SCALE),
              res / f"drawable-{bucket}/ic_launcher_foreground.png")

    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    (res / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- BqColors.accent, lib/core/theme/tokens.dart:46. The adaptive\n'
        '         icon\'s ground; the foreground layer carries only the bars. -->\n'
        '    <color name="ic_launcher_background">#4A4E7C</color>\n'
        '</resources>\n'
    )
    print("  mipmap-anydpi-v26/ic_launcher.xml + values/ic_launcher_background.xml")


def build_store() -> None:
    print("Store listings:")
    store = ROOT / "store/icon"
    if store.exists():
        shutil.rmtree(store)
    # Google Play: 512x512, 32-bit PNG, alpha allowed but the ground is opaque.
    write(draw_mark(512, ACCENT), store / "play-icon-512.png", flatten=True)
    # App Store Connect reads the 1024 out of the asset catalog, but the
    # listing tooling and the Devpost write-up both want a loose file.
    write(draw_mark(1024, ACCENT), store / "appstore-icon-1024.png", flatten=True)
    # A transparent-ground copy for slides and the README.
    write(draw_mark(1024, None), store / "mark-on-transparent-1024.png")


if __name__ == "__main__":
    build_ios()
    build_android()
    build_store()
    print("\nDone. Nothing here is hand-edited: re-run the script instead.")
