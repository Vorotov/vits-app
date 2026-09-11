#!/usr/bin/env python3
"""Generates the Google Play feature graphic, 1024x500.

Play requires one for a production listing. It is rendered from the same
sources as everything else in the store: the mark comes from
`make_icons.draw_mark('3b', …, ground=False)` — the approved V of two
capsules, colourway 3b, drawn on a transparent ground so it sits on the paper
colour here. The geometry lives in make_icons.py and is not duplicated.

Three colours are restated from `lib/core/theme/tokens.dart`, because a Python
tool cannot import a Dart file: paper `#F7F6F3`, accent `#4A4E7C`,
textSecondary `#5C5C66`. tokens.dart remains the only DART file allowed a hex
literal. The type is the bundled `assets/fonts/InstrumentSans[wdth,wght].ttf`
variable font — the wordmark at weight 620, the tagline at weight 500.

The layout follows Play's rules for this asset: JPEG or 24-bit PNG with no
alpha (so the canvas is RGB from the start); keep the focal point central —
the whole block is kept inside the central ~86% of the width because some
placements crop the edges; no store badges, no ranking or price claims; the
tagline stays small. Everything is drawn at 2x and downsampled with LANCZOS.

Run it from any directory:

    python3 tool/make_feature_graphic.py ['Line one.|Line two.'] [out.png]

The default tagline is the approved one and the default output is
`store/feature/feature-graphic-1024x500.png`. Regenerate; never edit the PNG.
"""
import pathlib, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = pathlib.Path(__file__).resolve().parent.parent; sys.path.insert(0, str(ROOT / 'tool'))
import make_icons  # noqa: E402  (draw_mark, the V of two capsules, colourway 3b)

W, H, SS = 1024, 500, 2
PAPER, ACCENT, TEXT2 = (0xF7, 0xF6, 0xF3), (0x4A, 0x4E, 0x7C), (0x5C, 0x5C, 0x66)  # tokens.dart
FONT = ROOT / 'assets/fonts/InstrumentSans[wdth,wght].ttf'
TAGLINE = sys.argv[1] if len(sys.argv) > 1 else 'Plan supplement cycles.|Get reminders. Mark what you take.'
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'store' / 'feature' / 'feature-graphic-1024x500.png'

def font(size, wght, wdth=100):
    f = ImageFont.truetype(str(FONT), size)
    axes = [a['name'] if isinstance(a, dict) else a for a in f.get_variation_axes()]
    vals = []
    for a in f.get_variation_axes():
        n = a.get('name', b'')
        n = n.decode() if isinstance(n, bytes) else str(n)
        vals.append(wght if 'eight' in n or n.lower() == 'wght' else wdth)
    f.set_variation_by_axes(vals)
    return f

img = Image.new('RGB', (W * SS, H * SS), PAPER)
d = ImageDraw.Draw(img)

# Layout: the mark on the left, the wordmark and a two-line tagline on the
# right, the whole block centred and kept inside the central 86% of the width
# (Play crops the edges in some placements; the guidance says keep the focal
# point central).
mark_h = int(H * SS * 0.56)                                  # 280 px of 500
mark = make_icons.draw_mark('3b', mark_h, ground=False)
f_name = font(int(H * SS * 0.25), 620)                       # 125 px
f_tag = font(int(H * SS * 0.062), 500)                       # 31 px
name = 'VitoMy'
lines = [l.strip() for l in TAGLINE.split('|')] if '|' in TAGLINE else [TAGLINE]
nb = d.textbbox((0, 0), name, font=f_name)
lbs = [d.textbbox((0, 0), l, font=f_tag) for l in lines]
name_w, name_h = nb[2] - nb[0], nb[3] - nb[1]
line_h = max(b[3] - b[1] for b in lbs); line_gap = int(line_h * 0.45)
tag_w = max(b[2] - b[0] for b in lbs)
gap_mark_text = int(W * SS * 0.04); gap_name_tag = int(H * SS * 0.07)
text_w = max(name_w, tag_w); block_w = mark_h + gap_mark_text + text_w
assert block_w <= W * SS * 0.90, f'block too wide: {block_w / SS:.0f} px of {W}'
x0 = (W * SS - block_w) // 2
img.paste(mark, (x0, (H * SS - mark_h) // 2), mark)
tx = x0 + mark_h + gap_mark_text
block_h = name_h + gap_name_tag + len(lines) * line_h + (len(lines) - 1) * line_gap
ty = (H * SS - block_h) // 2
d.text((tx - nb[0], ty - nb[1]), name, font=f_name, fill=ACCENT)
y = ty + name_h + gap_name_tag
for l, b in zip(lines, lbs):
    d.text((tx - b[0], y - b[1]), l, font=f_tag, fill=TEXT2)
    y += line_h + line_gap

out = img.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, 'PNG', optimize=True)
print(OUT, out.size, out.mode, 'block spans', round(x0 / SS), '->', round((x0 + block_w) / SS), 'of', W)
