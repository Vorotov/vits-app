#!/usr/bin/env python3
"""Generates every app-icon asset from the approved mark.

The mark is a V built from two capsules — the letter of the name and, read the
other way, a check. Both capsules are split across their length, which is the
calendar's own language: a course that is part taken and part still planned.

Source of truth is the Claude Design project
`dce8f720-1a6a-4152-90c2-6a6a76a471ac`, file `VitoMy Icon.dc.html`, turn 3
("Тісніша вершина"). Two colourways were approved there and both are built
here: `3a` on ochre and `3b` on cream. Every number below is transcribed from
that document's CSS on its own 236px artboard and scaled up, so a change there
is a change to the four constants in `_GEOMETRY` and nothing else.

Run it from the repo root:

    python3 tool/make_icons.py            # builds both, installs the default
    python3 tool/make_icons.py 3b         # builds both, installs 3b

Installing means writing into `ios/Runner/Assets.xcassets` and
`android/app/src/main/res`. Both colourways are always written to
`store/icon/<variant>/` so they can be compared without rebuilding.
"""

from __future__ import annotations

import json
import math
import pathlib
import shutil
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent

SS = 4            # supersampling factor
BASE = 1024       # output canvas
ARTBOARD = 236.0  # the design document's own artboard; every constant is in it

# 3b ships. navy #4b5079 and ochre #b98a2e are BqSeriesColors.palette[7] and
# palette[0] — the app's own supplement-tag colours — so the icon and the
# interface read as one product. 3a is louder on a home screen, but no
# surface that loud exists anywhere in the app. Decided 2026-09-11.
DEFAULT_VARIANT = "3b"

# --- geometry, transcribed from turn 3 of the design doc ------------------
# Both capsules share one box and one pivot; only the rotation sign differs.
# Turn 3's whole point is raising the pivot INSIDE the capsule (turn 2 had it
# just below, at 1.02), so the arms cross and the V closes into a single mark
# rather than two objects leaning together. See the pivot note below.
_GEOMETRY = {
    "capsule_w": 45.0,
    "capsule_h": 166.0,
    "bottom": 44.0,          # from the artboard's bottom edge
    "rotation_deg": 26.0,
}

# The pivot is DERIVED, not transcribed. The design document uses 0.88, which is
# close to the centre of the capsule's bottom cap but not on it: the cap is a
# semicircle of radius w/2, so its centre sits at (h - w/2)/h = 0.8645 of the
# length. Rotating about a point 2.6 units below that centre swings each cap
# sideways by ~1.1, the two caps miss each other by ~2.3, and the back capsule
# shows as a crescent sticking out from under the front one at the bottom of the
# V — visible at any size above about 120px.
#
# Put the pivot ON the cap centre and the rotation maps that circle onto itself.
# Both capsules then end in the SAME disc, whatever the angle, and the V closes
# to one clean point. Deriving it rather than hard-coding 0.8645 keeps that true
# if the capsule's width or length ever changes.
_GEOMETRY["pivot_y_fraction"] = (
    _GEOMETRY["capsule_h"] - _GEOMETRY["capsule_w"] / 2
) / _GEOMETRY["capsule_h"]

# Each capsule is (top colour, bottom colour); the second is drawn over the
# first. Colours are the design's own, NOT snapped to lib/core/theme/tokens.dart
# — see the note in store/listing.md. navy #4b5079 and cream #f6f3ec are within
# a few units of BqColors.accent and BqColors.paper; the ochre and the teal are
# genuinely new and exist only in the brand mark.
VARIANTS: dict[str, dict] = {
    "3a": {
        "label": "ochre ground, navy + teal",
        "background": "#e2b95c",
        "back_capsule": ("#4b5079", "#f6f3ec"),
        "front_capsule": ("#f6f3ec", "#3f7d8c"),
    },
    "3b": {
        "label": "cream ground, navy + ochre",
        "background": "#f6f3ec",
        "back_capsule": ("#4b5079", "#8d93b8"),
        "front_capsule": ("#e2b95c", "#b98a2e"),
    },
}


def _rgb(hex_colour: str) -> tuple[int, int, int]:
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _capsule(px: int, k: float, css_angle: float,
             top: str, bottom: str) -> Image.Image:
    """One capsule, split lengthwise, rotated about the shared pivot.

    `k` maps artboard units to pixels. CSS rotates clockwise for a positive
    angle and PIL rotates counter-clockwise, hence the sign flip.
    """
    g = _GEOMETRY
    w, h = g["capsule_w"], g["capsule_h"]
    left = ARTBOARD / 2 - w / 2
    top_y = ARTBOARD - (g["bottom"] + h)
    pivot = (ARTBOARD / 2, top_y + g["pivot_y_fraction"] * h)

    layer = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([left * k, top_y * k, (left + w) * k, (top_y + h / 2) * k],
                fill=_rgb(top))
    d.rectangle([left * k, (top_y + h / 2) * k, (left + w) * k, (top_y + h) * k],
                fill=_rgb(bottom))

    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [left * k, top_y * k, (left + w) * k, (top_y + h) * k],
        radius=w * k / 2, fill=255)
    layer.putalpha(mask)

    return layer.rotate(-css_angle, resample=Image.BICUBIC,
                        center=(pivot[0] * k, pivot[1] * k))


def draw_mark(variant: str, size: int, *, ground: bool, scale: float = 1.0
              ) -> Image.Image:
    """Renders the mark at `size` px. `ground=False` gives a transparent one."""
    v = VARIANTS[variant]
    px = size * SS
    k = px / ARTBOARD * scale
    art = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    for colours, sign in ((v["back_capsule"], -1), (v["front_capsule"], +1)):
        art.alpha_composite(
            _capsule(px, k, sign * _GEOMETRY["rotation_deg"], *colours))

    # `k` scaled about the artboard origin, so re-centre what it shrank.
    if scale != 1.0:
        offset = int(round(px * (1 - scale) / 2))
        shifted = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        shifted.alpha_composite(art, (offset, offset))
        art = shifted

    if ground:
        out = Image.new("RGBA", (px, px), _rgb(v["background"]) + (255,))
        out.alpha_composite(art)
    else:
        out = art
    return out.resize((size, size), Image.LANCZOS)


def adaptive_scale(variant: str) -> float:
    """How far to shrink the mark for an Android adaptive foreground.

    Android guarantees only the central 66dp of the 108dp canvas, so nothing
    outside a centred circle of 66/108 of the width is safe from a launcher's
    mask. Measured rather than estimated: render the mark, find the furthest
    painted pixel from the centre, and scale so that pixel lands on the circle.
    A bounding-box estimate would over-shrink, because the corners of this
    mark's box are empty.
    """
    probe = draw_mark(variant, 256, ground=False)
    alpha = probe.getchannel("A")
    centre = 256 / 2
    furthest = 0.0
    for y in range(256):
        row = alpha.crop((0, y, 256, y + 1)).tobytes()
        for x, a in enumerate(row):
            if a > 8:
                furthest = max(furthest, math.hypot(x + 0.5 - centre,
                                                    y + 0.5 - centre))
    safe_radius = 256 * (66 / 108) / 2
    return min(1.0, safe_radius / furthest)


def write(img: Image.Image, path: pathlib.Path, *, flatten: bool = False
          ) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if flatten and img.mode != "RGB":
        img = img.convert("RGB")
    img.save(path, "PNG")


def build_store(variant: str) -> None:
    out = ROOT / "store/icon" / variant
    if out.exists():
        shutil.rmtree(out)
    # Google Play: 512x512. App Store Connect reads the 1024 out of the asset
    # catalog, but the listing tooling and the write-up both want a loose file.
    write(draw_mark(variant, 512, ground=True), out / "play-icon-512.png",
          flatten=True)
    write(draw_mark(variant, 1024, ground=True),
          out / "appstore-icon-1024.png", flatten=True)
    write(draw_mark(variant, 1024, ground=False),
          out / "mark-on-transparent-1024.png")
    # The two sizes the design doc itself checks legibility at.
    for px in (60, 40):
        write(draw_mark(variant, px, ground=True), out / f"check-{px}.png",
              flatten=True)
    print(f"  store/icon/{variant}/  ({VARIANTS[variant]['label']})")


def install_ios(variant: str) -> None:
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((catalog / "Contents.json").read_text())
    wanted: dict[str, int] = {}
    for entry in contents["images"]:
        side = float(entry["size"].split("x")[0])
        wanted[entry["filename"]] = round(side * float(entry["scale"].rstrip("x")))
    for filename, px in wanted.items():
        # App Store Connect rejects an icon with an alpha channel outright, and
        # the corner radius is the OS's to apply — never bake either in.
        write(draw_mark(variant, px, ground=True), catalog / filename,
              flatten=True)
    print(f"  iOS: {len(wanted)} sizes")


def install_android(variant: str) -> None:
    res = ROOT / "android/app/src/main/res"
    for bucket, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                       ("xxhdpi", 144), ("xxxhdpi", 192)]:
        write(draw_mark(variant, px, ground=True),
              res / f"mipmap-{bucket}/ic_launcher.png", flatten=True)

    scale = adaptive_scale(variant)
    for bucket, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
                       ("xxhdpi", 324), ("xxxhdpi", 432)]:
        write(draw_mark(variant, px, ground=False, scale=scale),
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
        f'    <!-- Colourway {variant} of the brand mark. Generated by\n'
        '         tool/make_icons.py; not a lib/core/theme/tokens.dart value. -->\n'
        f'    <color name="ic_launcher_background">{VARIANTS[variant]["background"]}</color>\n'
        '</resources>\n'
    )
    print(f"  Android: 5 legacy + 5 adaptive (foreground at {scale:.3f} scale)")


def build_comparison() -> None:
    """One sheet, both colourways, at the sizes that actually decide it."""
    sizes = [(260, 1), (180, 1), (120, 1), (60, 2), (40, 3)]
    pad, gap = 28, 22
    row_w = pad * 2 + sum(rep * (px + gap) for px, rep in sizes) - gap
    sheet = Image.new("RGB", (row_w, pad * 2 + 260 * 2 + 40),
                      _rgb("#e7e3dc"))
    for row, variant in enumerate(VARIANTS):
        y = pad + row * (260 + 40)
        x = pad
        for px, rep in sizes:
            for _ in range(rep):
                sheet.paste(draw_mark(variant, px, ground=True).convert("RGB"),
                            (x, y + (260 - px) // 2))
                x += px + gap
    path = ROOT / "store/icon/comparison-3a-3b.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, "PNG")
    print(f"  {path.relative_to(ROOT)}")


if __name__ == "__main__":
    chosen = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_VARIANT
    if chosen not in VARIANTS:
        raise SystemExit(f"unknown variant {chosen!r}; pick one of "
                         f"{', '.join(VARIANTS)}")
    print("Store copies of both colourways:")
    for variant in VARIANTS:
        build_store(variant)
    build_comparison()
    print(f"\nInstalling {chosen} into the app:")
    install_ios(chosen)
    install_android(chosen)
    print("\nDone. Nothing here is hand-edited: re-run the script instead.")
