#!/usr/bin/env python3
"""Generates the App Store Connect creative asset, 5244x2950.

The redesigned product page has two OPTIONAL creative slots, Header and
Search Results, and their specifications overlap on exactly one size: a 16:9
master at 5244x2950 is valid in BOTH. Apple recommends that single master for
brand recognition, so one file is built here rather than two. Leaving the
slots empty is not a failure — Apple falls back to the screenshots — which
makes this an improvement to the listing, not a prerequisite for it.

Specifications, from Apple's creative-assets page: header 21:9 3840x1646 or
16:9 5244x2950; search results 3:2 1920x1280..3840x2560 or 16:9 5244x2950;
.png/.jpeg/.jpg; **alpha not allowed**. The canvas is RGB from the start for
that last reason, the same rule `make_feature_graphic.py` already follows for
Play — an alpha channel is an outright rejection, not a warning.

The safe area is DERIVED, not guessed, because Apple crops the 16:9 master
down to each slot's own ratio and the two crops cut on different axes:

    the 21:9 header crop keeps the full WIDTH  -> 5244 / (3840/1646) = 2248 px
                                                  of height, 76.2% of 2950
    the 3:2 search crop keeps the full HEIGHT  -> 2950 * 1.5        = 4425 px
                                                  of width,  84.4% of 5244

Only their intersection, 4425x2248 centred, survives both. Vertical is the
tighter of the two, which is why the composition is horizontal — mark left,
text right — rather than a tall stack, and why every size below is a fraction
of the SAFE height rather than of the canvas. An assert fails the run if the
drawn block leaves that box, and the margins are printed so a human can see
the headroom. The block is centred, so a centre crop cannot favour one end.

The mark comes from `make_icons.draw_mark('3b', …, ground=False)` — the
approved V of two capsules, colourway 3b, on a transparent ground so it sits
on the paper colour here. The geometry lives in make_icons.py and is not
duplicated.

Three colours are restated from `lib/core/theme/tokens.dart`, because a Python
tool cannot import a Dart file: paper `#F7F6F3`, accent `#4A4E7C`,
textSecondary `#5C5C66`. tokens.dart remains the only DART file allowed a hex
literal. The type is the bundled `assets/fonts/InstrumentSans[wdth,wght].ttf`
variable font — the wordmark at weight 620, the tagline at weight 500.
Everything is drawn at 2x and downsampled with LANCZOS.

The tagline is checked IN CODE against the vocabulary gate: the stem list is
read out of `test_release/legal_copy_safety_test.dart` rather than copied, so
the asset and the legal documents cannot drift. This is public marketing
material; it describes a planner and names no limit, threshold or verdict.

One cost worth knowing before you wonder: the mark is asked for at the
supersampled size, so make_icons renders it on its own 4x artboard — about
10k px square, a few seconds and ~2GB. That is the price of a crisp mark on a
5244px canvas and is paid once per run.

Run it from any directory:

    python3 tool/make_store_header.py ['Tagline.'] [out.png]

The default tagline is the approved one, the Play feature graphic's own first
line, and the default output is
`store/creative/universal-5244x2950.png`. Regenerate; never edit the PNG.
"""
import pathlib, re, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = pathlib.Path(__file__).resolve().parent.parent; sys.path.insert(0, str(ROOT / 'tool'))
import make_icons  # noqa: E402  (draw_mark, the V of two capsules, colourway 3b)

W, H, SS = 5244, 2950, 2
PAPER, ACCENT, TEXT2 = (0xF7, 0xF6, 0xF3), (0x4A, 0x4E, 0x7C), (0x5C, 0x5C, 0x66)  # tokens.dart
FONT = ROOT / 'assets/fonts/InstrumentSans[wdth,wght].ttf'
TAGLINE = sys.argv[1] if len(sys.argv) > 1 else 'Plan supplement cycles.'
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / 'store' / 'creative' / 'universal-5244x2950.png'
NAME = 'VitoMy'

# Apple's own listed pixel sizes for the two narrower slots, kept as the
# numbers Apple publishes so the derivation below is traceable to the page.
HEADER_AR = 3840 / 1646          # 21:9, the header slot
SEARCH_AR = 1920 / 1280          # 3:2, the search-results slot
SAFE_H = round(W / HEADER_AR)    # 2248 — the 21:9 crop keeps the full width
SAFE_W = round(H * SEARCH_AR)    # 4425 — the 3:2 crop keeps the full height


def forbidden_stems():
    """The vocabulary gate's stem list, read out of the Dart test, not copied.

    Comments are stripped first: the entry for `\\bcure` explains itself with
    'secure' and 'obscure' in quotes, and a naive scan would adopt both as
    stems. Stripping comments before scanning is this repo's rule for its own
    source gates; it applies to a gate that READS one too.
    """
    src = (ROOT / 'test_release/legal_copy_safety_test.dart').read_text()
    body = src.split('const legalForbiddenStems = <String>[', 1)[1].split('];', 1)[0]
    body = '\n'.join(re.sub(r'//.*', '', line) for line in body.split('\n'))
    return re.findall(r"r?'([^']*)'", body)


copy = f'{NAME} {TAGLINE}'
hits = [s for s in forbidden_stems() if re.search(s, copy, re.I)]
assert not hits, f'the asset copy carries banned vocabulary {hits}: {copy!r}'


def font(size, wght, wdth=100):
    f = ImageFont.truetype(str(FONT), size)
    vals = []
    for a in f.get_variation_axes():
        n = a.get('name', b'')
        n = n.decode() if isinstance(n, bytes) else str(n)
        vals.append(wght if 'eight' in n or n.lower() == 'wght' else wdth)
    f.set_variation_by_axes(vals)
    return f


img = Image.new('RGB', (W * SS, H * SS), PAPER)
d = ImageDraw.Draw(img)

# Layout: the mark on the left, the wordmark and one short line on the right,
# the whole block centred in the canvas — and therefore centred in both of
# Apple's centre crops. Every size is a fraction of the SAFE height, not of
# the canvas height, because the asset is only ever seen through a crop.
mark_h = int(SAFE_H * SS * 0.58)
mark = make_icons.draw_mark('3b', mark_h, ground=False)
f_name = font(int(SAFE_H * SS * 0.27), 620)
f_tag = font(int(SAFE_H * SS * 0.075), 500)
nb = d.textbbox((0, 0), NAME, font=f_name)
tb = d.textbbox((0, 0), TAGLINE, font=f_tag)
name_w, name_h = nb[2] - nb[0], nb[3] - nb[1]
tag_w, tag_h = tb[2] - tb[0], tb[3] - tb[1]
gap_mark_text = int(SAFE_W * SS * 0.035)
gap_name_tag = int(SAFE_H * SS * 0.075)
text_w = max(name_w, tag_w)
text_h = name_h + gap_name_tag + tag_h
block_w = mark_h + gap_mark_text + text_w
block_h = max(mark_h, text_h)
assert block_w <= SAFE_W * SS, f'block {block_w / SS:.0f} px wide leaves the {SAFE_W} px safe width'
assert block_h <= SAFE_H * SS, f'block {block_h / SS:.0f} px tall leaves the {SAFE_H} px safe height'

x0 = (W * SS - block_w) // 2
img.paste(mark, (x0, (H * SS - mark_h) // 2), mark)
tx = x0 + mark_h + gap_mark_text
ty = (H * SS - text_h) // 2
d.text((tx - nb[0], ty - nb[1]), NAME, font=f_name, fill=ACCENT)
d.text((tx - tb[0], ty + name_h + gap_name_tag - tb[1]), TAGLINE, font=f_tag, fill=TEXT2)

out = img.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, 'PNG', optimize=True)
print(OUT, out.size, out.mode)
print(f'safe box {SAFE_W}x{SAFE_H} centred (21:9 keeps {SAFE_H / H:.1%} of the height, '
      f'3:2 keeps {SAFE_W / W:.1%} of the width)')
print(f'block {block_w / SS:.0f}x{block_h / SS:.0f} centred, margin '
      f'{(SAFE_W * SS - block_w) / 2 / SS:.0f} px each side, '
      f'{(SAFE_H * SS - block_h) / 2 / SS:.0f} px top and bottom')
