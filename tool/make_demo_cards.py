from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080
BG      = (242, 241, 238)
INK     = (23, 23, 27)
SECOND  = (92, 92, 102)
MUTED   = (142, 142, 153)
ACCENT  = (74, 78, 124)
SANS = "assets/fonts/InstrumentSans[wdth,wght].ttf"
MONO = "assets/fonts/JetBrainsMono[wght].ttf"
OUT = __import__("sys").argv[1]  # where the PNGs land; tool/make_demo_video.sh passes a scratch dir

# The phone's place on the canvas, shared with the ffmpeg overlay.
PX, PY, PW, PH = 1290, 40, 460, 1000


def font(path, size, weight=None):
    f = ImageFont.truetype(path, size)
    if weight is not None:
        try:
            f.set_variation_by_axes([100.0, float(weight)] if "wdth" in path else [float(weight)])
        except Exception:
            pass
    return f


def wrap(d, text, fnt, max_w):
    words, lines, line = text.split(), [], ""
    for w in words:
        t = (line + " " + w).strip()
        if d.textlength(t, font=fnt) <= max_w:
            line = t
        else:
            lines.append(line); line = w
    if line:
        lines.append(line)
    return lines


# ---- the mask that rounds the phone's corners -------------------------------
mask = Image.new("RGBA", (W, H), BG + (255,))
md = ImageDraw.Draw(mask)
md.rounded_rectangle([PX, PY, PX + PW - 1, PY + PH - 1], radius=48, fill=(0, 0, 0, 0))
mask.save(f"{OUT}/mask.png")

# ---- captions ---------------------------------------------------------------
CAPS = [
    ("stack",    "Every supplement in one list",
     "Name, dose, and the cycle it runs on."),
    ("cycle",    "Set the cycle once",
     "Eight weeks on, four weeks off. The calendar works the rest out."),
    ("today",    "What to take today",
     "Tap a row to mark it taken. No streaks, no blame."),
    ("cycles",   "On weeks and off weeks, drawn",
     "Breaks hatched, overlaps visible, at four-month range."),
    ("year",     "A whole year at a glance",
     "Which months are covered, and where the gaps are."),
    ("notif",    "A reminder at every dose time",
     "Local, and it never names what you take. A lock screen is public."),
]
f_head = font(SANS, 76, 650)
f_sub  = font(SANS, 36, 400)
for name, head, sub in CAPS:
    img = Image.new("RGBA", (1040, 420), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    y = 0
    for line in wrap(d, head, f_head, 1000):
        d.text((0, y), line, font=f_head, fill=INK)
        y += 92
    y += 24
    for line in wrap(d, sub, f_sub, 980):
        d.text((0, y), line, font=f_sub, fill=SECOND)
        y += 52
    img.save(f"{OUT}/cap-{name}.png")

# ---- title card -------------------------------------------------------------
title = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(title)
icon = Image.open("store/icon/3b/appstore-icon-1024.png").convert("RGBA").resize((220, 220), Image.LANCZOS)
mk = Image.new("L", (220, 220), 0)
ImageDraw.Draw(mk).rounded_rectangle([0, 0, 219, 219], radius=48, fill=255)
title.paste(icon, (200, 330), mk)
d.text((470, 350), "VitoMy", font=font(SANS, 118, 700), fill=INK)
d.text((476, 490), "Plan the cycle once. The calendar keeps it.",
       font=font(SANS, 42, 400), fill=SECOND)
d.text((476, 562), "vitomy.app", font=font(MONO, 34, 500), fill=ACCENT)
title.save(f"{OUT}/title.png")

# ---- end card ---------------------------------------------------------------
end = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(end)
d.text((200, 330), "VitoMy", font=font(SANS, 104, 700), fill=INK)
lines = [
    "Free on the App Store, iPhone and iPad",
    "Flutter · Riverpod · Drift · RevenueCat",
    "Everything stays on the device",
]
y = 480
for line in lines:
    d.text((204, y), line, font=font(SANS, 40, 400), fill=SECOND)
    y += 66
d.text((204, y + 24), "vitomy.app", font=font(MONO, 36, 500), fill=ACCENT)
end.save(f"{OUT}/end.png")
print("cards written to", OUT)
