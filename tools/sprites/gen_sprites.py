#!/usr/bin/env python3
"""Procedural pixel-art sprite generator for Galactic Fishing Co. vertical slice.
Draws chunky pixel sprites with PIL at small sizes; Godot scales them up with
nearest filtering. All sprites face RIGHT (flip via scale.x for left)."""
from PIL import Image, ImageDraw
import math, os, random

OUT = os.path.expanduser("~/workspace/gfc-build/assets/sprites")
os.makedirs(OUT, exist_ok=True)
random.seed(7)

# palette
YELLOW = (250, 200, 60); YELLOW_D = (205, 150, 40); YELLOW_DD = (160, 115, 30)
HELM = (150, 220, 245); HELM_D = (95, 165, 205); HELM_DD = (60, 120, 160)
SKIN = (255, 214, 175); SKIN_D = (230, 175, 140)
DARK = (25, 25, 35); GRAY = (145, 145, 155); GRAY_D = (95, 95, 110)
BROWN = (150, 100, 60); WHITE = (255, 255, 255); PINK = (255, 150, 170)
HULL = (45, 52, 70); HULL_D = (30, 35, 50); WIN = (255, 210, 120)
SEA = (40, 150, 110); SEA_D = (25, 110, 80)
ROCK = (70, 90, 120); ROCK_D = (45, 60, 85); ROCK_FAR = (32, 52, 84)

def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)

def ell(d, box, fill):
    d.ellipse(box, fill=fill)

# ---------------- DIVER (32x32, faces right) ----------------
def diver(frame):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    kick = 2 if frame == 1 else 0
    # legs trailing left
    d.rectangle([1, 12 - kick, 6, 16 - kick], fill=YELLOW)
    d.rectangle([1, 18 + kick, 6, 22 + kick], fill=YELLOW_D)
    d.rectangle([1, 12 - kick, 6, 13 - kick], fill=YELLOW_DD)
    # backpack
    d.rounded_rectangle([6, 10, 12, 22], radius=3, fill=GRAY_D)
    d.rectangle([8, 12, 10, 14], fill=(120, 220, 255))  # o2 light
    # body
    d.rounded_rectangle([10, 9, 22, 23], radius=5, fill=YELLOW)
    d.rounded_rectangle([10, 18, 22, 23], radius=3, fill=YELLOW_D)
    d.rectangle([10, 9, 22, 12], fill=YELLOW)  # top fill
    # belt
    d.rectangle([12, 19, 20, 21], fill=BROWN)
    # harpoon gun pointing right
    d.rectangle([20, 15, 29, 17], fill=GRAY)
    d.polygon([(29, 14), (32, 16), (29, 18)], fill=GRAY_D)
    d.rectangle([18, 17, 21, 21], fill=BROWN)
    # bubble helmet
    ell(d, [14, 4, 28, 18], HELM_DD)
    ell(d, [15, 5, 27, 17], HELM)
    # face inside (determined adult, slight smirk)
    ell(d, [17, 7, 25, 15], SKIN)
    d.rectangle([19, 9, 20, 10], fill=DARK)   # eyes
    d.rectangle([23, 9, 24, 10], fill=DARK)
    d.rectangle([20, 13, 23, 14], fill=SKIN_D)  # smirk-ish mouth
    d.rectangle([23, 13, 24, 13], fill=SKIN_D)
    # glass highlight
    d.rectangle([16, 6, 18, 8], fill=WHITE)
    return img

for f in (0, 1):
    save(diver(f), f"diver_{f}.png")

# ---------------- FISH (20x14, faces right) ----------------
def fish(body, belly, frame, mechanical=False):
    img = Image.new("RGBA", (20, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wig = (-2, 0, 2)[frame]
    # tail
    d.polygon([(5, 7), (0 + wig, 3), (0 + wig, 11)], fill=body)
    # body
    ell(d, [4, 2, 17, 12], body)
    ell(d, [6, 7, 15, 12], belly)
    if mechanical:
        # panel lines + rivets
        d.line([8, 3, 8, 11], fill=GRAY_D, width=1)
        d.line([12, 3, 12, 11], fill=GRAY_D, width=1)
        for rx, ry in ((6, 4), (10, 9), (14, 4)):
            d.rectangle([rx, ry, rx + 1, ry + 1], fill=GRAY_D)
        # glowing eye
        d.rectangle([13, 4, 15, 6], fill=(140, 240, 255))
        d.rectangle([14, 5, 14, 5], fill=WHITE)
    else:
        d.rectangle([13, 4, 15, 6], fill=WHITE)
        d.rectangle([14, 5, 14, 5], fill=DARK)
    # blush (cute but wrong)
    d.rectangle([11, 8, 12, 9], fill=PINK)
    return img

SPECIES = {
    "fish_pink": ((255, 150, 180), (255, 190, 205), False),
    "fish_orange": ((255, 170, 70), (255, 205, 140), False),
    "fish_teal": ((110, 200, 190), (150, 225, 215), True),
}
for name, (body, belly, mech) in SPECIES.items():
    for f in range(3):
        save(fish(body, belly, f, mech), f"{name}_{f}.png")

# ---------------- HARPOON (16x6) ----------------
def harpoon():
    img = Image.new("RGBA", (16, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 2, 11, 3], fill=GRAY)
    d.rectangle([0, 2, 11, 2], fill=WHITE)
    d.polygon([(11, 1), (16, 3), (11, 5)], fill=GRAY_D)
    d.rectangle([2, 4, 5, 5], fill=BROWN)
    return img
save(harpoon(), "harpoon.png")

# ---------------- SEAWEED (16x40, 2 sway frames) ----------------
def seaweed(frame):
    img = Image.new("RGBA", (16, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(40):
        x = 8 + int(3.2 * math.sin(y / 7.0 + frame * math.pi))
        d.rectangle([x - 1, y, x + 1, y], fill=SEA if y % 2 == 0 else SEA_D)
        if y % 8 == 4:
            ell(d, [x - 4, y - 3, x - 1, y + 1], SEA)
    return img
for f in range(2):
    save(seaweed(f), f"seaweed_{f}.png")

# ---------------- FOREGROUND SEAWEED (24x64, dark silhouette) ----------------
def seaweed_fg(frame):
    img = Image.new("RGBA", (24, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = (18, 60, 70)
    for y in range(64):
        x = 12 + int(5 * math.sin(y / 10.0 + frame * math.pi))
        d.rectangle([x - 2, y, x + 2, y], fill=col)
        if y % 12 == 6:
            ell(d, [x - 7, y - 4, x - 1, y + 2], col)
    return img
for f in range(2):
    save(seaweed_fg(f), f"seaweed_fg_{f}.png")

# ---------------- ROCK (32x20) / FAR ROCK (64x40) ----------------
def rock():
    img = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ell(d, [0, 4, 32, 20], ROCK_D)
    ell(d, [2, 2, 28, 16], ROCK)
    for x, y in ((8, 6), (16, 4), (22, 8)):
        d.rectangle([x, y, x + 2, y + 1], fill=(95, 120, 155))
    return img
save(rock(), "rock.png")

def rock_far():
    img = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ell(d, [0, 8, 64, 40], ROCK_FAR)
    ell(d, [6, 4, 56, 32], (40, 64, 100))
    return img
save(rock_far(), "rock_far.png")

# ---------------- SHIP top-down (120x56) ----------------
def ship():
    img = Image.new("RGBA", (120, 56), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # hull
    d.rounded_rectangle([6, 8, 114, 48], radius=20, fill=HULL_D)
    d.rounded_rectangle([10, 12, 110, 44], radius=16, fill=HULL)
    # deck stripe
    d.rounded_rectangle([20, 24, 100, 32], radius=4, fill=(60, 70, 95))
    # windows
    for x in range(26, 100, 12):
        d.rectangle([x, 16, x + 5, 19], fill=WIN)
    # bridge
    d.rounded_rectangle([48, 34, 72, 46], radius=4, fill=(70, 82, 110))
    d.rectangle([52, 37, 68, 40], fill=(140, 230, 255))
    # thrusters (rear = left)
    for y in (14, 28, 42):
        d.rectangle([0, y - 3, 8, y + 3], fill=(140, 230, 255))
    return img
save(ship(), "ship.png")

# ---------------- WATER GRADIENT (8x512) ----------------
def gradient():
    img = Image.new("RGB", (8, 512))
    d = ImageDraw.Draw(img)
    top = (150, 232, 246); bot = (16, 60, 110)
    for y in range(512):
        t = y / 511
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        d.line([0, y, 8, y], fill=c)
    return img
save(gradient(), "water_gradient.png")

# ---------------- BUBBLE (8x8) / SNOW (4x4) ----------------
def bubble():
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ell(d, [1, 1, 7, 7], (200, 240, 255, 160))
    d.rectangle([2, 2, 3, 3], fill=(255, 255, 255, 220))
    return img
save(bubble(), "bubble.png")

def snow():
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 1, 2, 2], fill=(255, 255, 255, 140))
    return img
save(snow(), "snow.png")

def glow():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ell(d, [0, 0, 16, 16], (255, 240, 180, 90))
    ell(d, [4, 4, 12, 12], (255, 240, 180, 160))
    return img
save(glow(), "glow.png")

print("ALL SPRITES DONE")
