"""Composes the Devpost image gallery: 3:2 cards from the listing screenshots.

Devpost recommends 3:2; the listing screenshots are 1320x2868 portrait, so each
card pairs one screenshot with a caption instead of letterboxing it. Colours are
read from the app's own tokens, not invented.
"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1800, 1200
BG      = (242, 241, 238)   # BqColors.chip
SURFACE = (255, 255, 255)
INK     = (23, 23, 27)      # BqColors.ink
SECOND  = (92, 92, 102)     # BqColors.textSecondary
MUTED   = (142, 142, 153)   # BqColors.textMuted
ACCENT  = (74, 78, 124)     # BqColors.accent

SANS = "assets/fonts/InstrumentSans[wdth,wght].ttf"
MONO = "assets/fonts/JetBrainsMono[wght].ttf"


def font(path, size, weight=None):
    f = ImageFont.truetype(path, size)
    if weight is not None:
        try:
            f.set_variation_by_axes([100.0, float(weight)] if "wdth" in path else [float(weight)])
        except Exception:
            pass
    return f


CARDS = [
    ("store/screenshots/ios-6.9/01-stack.png", "STACK",
     "Every supplement in one list",
     "Name, dose, the schedule it runs on, and whether it is on or in a break today."),
    ("store/screenshots/ios-6.9/02-today.png", "TODAY",
     "What to take today, and nothing else",
     "Tap a row to mark it taken. The ring fills as the day goes, with no streaks and no blame."),
    ("store/screenshots/ios-6.9/03-cycles.png", "CYCLES",
     "On weeks and off weeks, drawn",
     "Every schedule as a bar across the months. Breaks are hatched, overlaps are visible."),
    ("store/screenshots/ios-6.9/04-year.png", "YEAR",
     "A whole year at a glance",
     "Which months are covered, which ones stack up, and where the gaps are."),
    ("store/screenshots/ios-6.9/05-schedule.png", "SCHEDULE",
     "Set the cycle once",
     "Eight weeks on, four weeks off, two times a day. The calendar works the rest out."),
    ("store/screenshots/iap-review/tip-review.png", "SUPPORT",
     "Three tips, powered by RevenueCat",
     "Consumables that unlock nothing. No ads, no account, no paywall, no feature gate."),
]


def wrap(draw, text, fnt, max_w):
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            line = trial
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)
    return lines


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1],
                                           radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


f_eyebrow = font(MONO, 30, 600)
f_head    = font(SANS, 72, 650)
f_body    = font(SANS, 34, 400)

for i, (shot, eyebrow, head, body) in enumerate(CARDS, start=1):
    card = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(card)

    # The phone, on the right, sized so it bleeds slightly off the bottom edge
    # the way the device sits in a hand rather than floating in a box.
    ph = Image.open(shot).convert("RGB")
    target_h = 1060
    target_w = round(ph.width * target_h / ph.height)
    ph = ph.resize((target_w, target_h), Image.LANCZOS)
    ph = rounded(ph, 52)
    px, py = W - target_w - 120, (H - target_h) // 2
    card.paste(ph, (px, py), ph)
    d.rounded_rectangle([px, py, px + target_w - 1, py + target_h - 1],
                        radius=52, outline=(226, 225, 220), width=2)

    # The caption column
    x, max_w = 120, px - 120 - 90
    y = 300
    d.text((x, y), eyebrow, font=f_eyebrow, fill=ACCENT)
    y += 78
    for line in wrap(d, head, f_head, max_w):
        d.text((x, y), line, font=f_head, fill=INK)
        y += 86
    y += 26
    for line in wrap(d, body, f_body, max_w):
        d.text((x, y), line, font=f_body, fill=SECOND)
        y += 48

    d.text((x, H - 150), "VitoMy", font=font(SANS, 38, 650), fill=INK)
    d.text((x + 145, H - 146), "vitomy.app", font=f_body, fill=MUTED)

    out = f"store/devpost/gallery/{i:02d}-{eyebrow.lower()}.png"
    card.save(out)
    print(out, card.size)
