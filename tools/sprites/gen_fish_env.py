#!/usr/bin/env python3
"""Unique fish species for Galactic Fishing Co. — distinct silhouettes, not palette swaps.
1. bubblescale: round puffer-like, pink
2. copperbelly: long slender, orange
3. worrywart: spiky/frilly, slightly mechanical teal (cute but wrong)
All face RIGHT. 3 wiggle frames each."""
from PIL import Image, ImageDraw
import os

OUT = os.path.expanduser("~/workspace/gfc-build/assets/sprites")
os.makedirs(OUT, exist_ok=True)

DARK = (25, 25, 35); WHITE = (255, 255, 255); PINK = (255, 150, 170)
GRAY_D = (95, 95, 110)

def save(img, name):
    img.save(os.path.join(OUT, name)); print("wrote", name, img.size)

# ---------- 1. BUBBLESCALE MINNOW: round puffer ----------
def bubblescale(frame):
    img = Image.new("RGBA", (22, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, belly = (255, 150, 180), (255, 195, 210)
    wig = (-2, 0, 2)[frame]
    # tiny tail
    d.polygon([(5, 9), (1 + wig, 5), (1 + wig, 13)], fill=body)
    # round body
    d.ellipse([4, 2, 19, 17], fill=body)
    d.ellipse([7, 8, 16, 16], fill=belly)
    # spots
    for sx, sy in ((8, 5), (13, 6), (10, 12)):
        d.rectangle([sx, sy, sx + 1, sy + 1], fill=(235, 110, 145))
    # little side fin
    d.ellipse([8 + wig, 10, 12 + wig, 13], fill=belly)
    # big cute eye + blush
    d.rectangle([14, 5, 16, 7], fill=WHITE)
    d.rectangle([15, 6, 15, 6], fill=DARK)
    d.rectangle([12, 10, 13, 11], fill=PINK)
    return img

# ---------- 2. COPPERBELLY GLINT: long slender ----------
def copperbelly(frame):
    img = Image.new("RGBA", (30, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, belly = (255, 170, 70), (255, 208, 145)
    bend = (-1, 0, 1)[frame]  # body bend
    # forked tail
    d.polygon([(6, 7), (0, 3 + bend), (3, 7), (0, 11 + bend)], fill=(235, 140, 55))
    # long body
    d.ellipse([5, 3, 27, 11], fill=body)
    d.ellipse([8, 7, 25, 11], fill=belly)
    # dorsal fin
    d.polygon([(12, 3), (17, 0), (20, 3)], fill=(235, 140, 55))
    # stripes
    for sx in (10, 15, 20):
        d.line([sx, 4 + bend, sx, 10 + bend], fill=(235, 140, 55), width=1)
    # pointed snout + eye
    d.polygon([(27, 5), (30, 7), (27, 9)], fill=body)
    d.rectangle([23, 5, 24, 6], fill=WHITE)
    d.rectangle([23, 5, 23, 5], fill=DARK)
    d.rectangle([21, 8, 22, 9], fill=PINK)
    return img

# ---------- 3. WORRYWART WRASSE: spiky/frilly, faintly mechanical ----------
def worrywart(frame):
    img = Image.new("RGBA", (26, 22), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body, dark = (105, 195, 185), (70, 150, 145)
    wig = (-2, 0, 2)[frame]
    # frilly spikes top and bottom
    for i, sx in enumerate(range(7, 20, 3)):
        h = 4 + ((i + frame) % 2)
        d.polygon([(sx, 5), (sx + 1, 5 - h), (sx + 2, 5)], fill=dark)
        d.polygon([(sx, 17), (sx + 1, 17 + h), (sx + 2, 17)], fill=dark)
    # tail with frill
    d.polygon([(6, 11), (1 + wig, 6), (1 + wig, 16)], fill=dark)
    # body
    d.ellipse([5, 5, 21, 17], fill=body)
    d.ellipse([8, 11, 18, 16], fill=(140, 220, 210))
    # faint panel seams + rivets (slightly off)
    d.line([11, 6, 11, 16], fill=dark, width=1)
    for rx, ry in ((9, 8), (14, 13)):
        d.rectangle([rx, ry, rx + 1, ry + 1], fill=GRAY_D)
    # glowing eye + blush
    d.rectangle([16, 7, 18, 9], fill=(150, 245, 255))
    d.rectangle([17, 8, 17, 8], fill=WHITE)
    d.rectangle([14, 12, 15, 13], fill=PINK)
    return img

for f in range(3):
    save(bubblescale(f), f"fish_pink_{f}.png")
    save(copperbelly(f), f"fish_orange_{f}.png")
    save(worrywart(f), f"fish_teal_{f}.png")

# ---------- CORALS for midground (48x48) ----------
def coral(color, dark, seed):
    import random
    random.seed(seed)
    img = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def branch(x, y, ang, length, w):
        if length < 4 or w < 1:
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=color); return
        import math
        nx = x + math.cos(ang) * length; ny = y + math.sin(ang) * length
        d.line([x, y, nx, ny], fill=dark, width=w + 1)
        d.line([x, y, nx, ny], fill=color, width=w)
        branch(nx, ny, ang - 0.5 + random.random() * 0.3, length * 0.72, w - 1)
        branch(nx, ny, ang + 0.4 + random.random() * 0.3, length * 0.72, w - 1)
    branch(24, 46, -math.pi / 2, 16, 4)
    d.ellipse([14, 38, 34, 48], fill=dark)  # base
    return img

import math
save(coral((255, 150, 180), (200, 100, 135), 11), "coral_0.png")
save(coral((170, 130, 230), (125, 90, 180), 23), "coral_1.png")
save(coral((120, 210, 190), (80, 160, 140), 37), "coral_2.png")

# ---------- SAND TILE (64x64) with speckles ----------
def sand():
    import random
    random.seed(5)
    img = Image.new("RGB", (64, 64), (232, 214, 165))
    d = ImageDraw.Draw(img)
    for _ in range(260):
        x, y = random.randint(0, 63), random.randint(0, 63)
        c = (214, 192, 140) if random.random() < 0.5 else (245, 228, 185)
        d.rectangle([x, y, x + 1, y + 1], fill=c)
    return img
save(sand(), "sand.png")

# ---------- LIGHT DAPPLE overlay blob (64x32, soft) ----------
def dapple():
    img = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, 64, 32], fill=(255, 250, 210, 60))
    d.ellipse([10, 6, 54, 26], fill=(255, 250, 210, 70))
    return img
save(dapple(), "dapple.png")

# ---------- SURFACE RIPPLE BAND (256x48, tileable-ish) ----------
def surface_band():
    import random
    random.seed(9)
    img = Image.new("RGBA", (256, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for row in range(4):
        y = 6 + row * 11
        for x in range(0, 256, 4):
            w = int(3 * math.sin(x / 18.0 + row * 1.7) + 3)
            a = 90 + int(50 * math.sin(x / 29.0 + row))
            d.rectangle([x, y + w - 3, x + 3, y + w], fill=(200, 245, 255, a))
    return img
save(surface_band(), "surface_band.png")

# ---------- VIGNETTE (256x256 radial) ----------
def vignette():
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for r in range(128, 0, -1):
        a = int(150 * (1 - r / 128) ** 2)
        d.ellipse([128 - r, 128 - r, 128 + r, 128 + r], outline=(4, 10, 30, 0))
    # draw filled rings from outside in
    for i in range(64):
        t = i / 63
        rad = 128 - int(t * 40)
        a = int(t * 130)
        d.ellipse([128 - rad, 128 - rad, 128 + rad, 128 + rad], fill=(4, 10, 30, 0))
    # simpler: per-pixel
    px = img.load()
    for y in range(256):
        for x in range(256):
            dx, dy = (x - 128) / 128, (y - 128) / 128
            dist = min(1.0, (dx * dx + dy * dy) ** 0.5)
            a = int(170 * max(0, (dist - 0.55) / 0.45) ** 1.8)
            px[x, y] = (4, 10, 30, a)
    return img
save(vignette(), "vignette.png")

print("FISH + ENV DONE")
