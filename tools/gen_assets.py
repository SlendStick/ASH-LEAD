#!/usr/bin/env python3
"""Procedural asset generator for ASH&LEAD.

Generates original textures, character sprites, UI icons, sound effects and
music loops. Everything is synthesized from scratch - no copyrighted material.

Usage: python3 tools/gen_assets.py
"""
import math
import os
import random
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
SND = os.path.join(ROOT, "assets", "sounds")
MUS = os.path.join(ROOT, "assets", "music")
for d in (TEX, SND, MUS):
    os.makedirs(d, exist_ok=True)

rng = random.Random(20261121)


# ----------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------
def canvas(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)


def noise_fill(img, base, amp=18, cell=4):
    """Deterministic per-pixel brightness noise around `base` color."""
    w, h = img.size
    arr = np.array(img).astype(np.int16)
    n = rng.randrange(0, 1 << 30)
    r = np.random.RandomState(n)
    for y in range(h):
        for x in range(w):
            a = arr[y, x, 3]
            if a == 0:
                continue
            d = int(r.randint(-amp, amp + 1))
            arr[y, x, 0] = max(0, min(255, int(arr[y, x, 0]) + d))
            arr[y, x, 1] = max(0, min(255, int(arr[y, x, 1]) + d))
            arr[y, x, 2] = max(0, min(255, int(arr[y, x, 2]) + d))
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def save(img, name):
    path = os.path.join(TEX, name)
    img.save(path)
    return path


def vgrad(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for y in range(h):
        t = y / max(1, h - 1)
        c = [int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)] + [255]
        arr[y, :, :] = c
    return Image.fromarray(arr, "RGBA")


# ----------------------------------------------------------------------------
# floor / wall tiles
# ----------------------------------------------------------------------------
def tile_floor_concrete():
    img = canvas(64, 64, (46, 50, 58, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 63], outline=(34, 37, 44, 255), width=2)
    for _ in range(26):
        x, y = rng.randint(0, 63), rng.randint(0, 63)
        r = rng.randint(1, 2)
        c = rng.choice([(58, 62, 70, 255), (38, 41, 48, 255), (66, 70, 78, 255)])
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    return noise_fill(img, (46, 50, 58), 10)


def tile_floor_tile():
    img = canvas(64, 64, (52, 58, 66, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 31], fill=(58, 66, 76, 255))
    d.rectangle([32, 32, 63, 63], fill=(58, 66, 76, 255))
    d.rectangle([0, 0, 63, 63], outline=(30, 34, 40, 255), width=2)
    d.line([32, 0, 32, 64], fill=(30, 34, 40, 255), width=2)
    d.line([0, 32, 64, 32], fill=(30, 34, 40, 255), width=2)
    return noise_fill(img, (52, 58, 66), 9)


def tile_floor_wood():
    img = canvas(64, 64, (74, 56, 38, 255))
    d = ImageDraw.Draw(img)
    for i in range(0, 64, 16):
        d.line([0, i, 64, i], fill=(56, 42, 28, 255), width=2)
        off = (i // 16 % 2) * 32
        for j in range(off, 64, 64):
            d.line([j, i, j, i + 16], fill=(56, 42, 28, 255), width=2)
    for _ in range(30):
        x = rng.randint(0, 63)
        y = rng.randint(0, 63)
        d.point((x, y), fill=(86, 66, 46, 255))
    return noise_fill(img, (74, 56, 38), 9)


def tile_floor_carpet():
    img = canvas(64, 64, (44, 40, 62, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 59, 59], outline=(34, 31, 50, 255), width=2)
    d.rectangle([12, 12, 51, 51], outline=(58, 52, 80, 255), width=2)
    return noise_fill(img, (44, 40, 62), 12)


def tile_wall():
    img = vgrad((64, 64), (86, 92, 104, 255), (52, 56, 66, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 6], fill=(108, 116, 130, 255))
    d.rectangle([0, 6, 63, 8], fill=(38, 41, 48, 255))
    d.line([0, 63, 63, 63], fill=(24, 26, 32, 255), width=2)
    return noise_fill(img, (70, 76, 86), 10)


def tile_wall_dark():
    img = vgrad((64, 64), (58, 62, 74, 255), (34, 37, 45, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 5], fill=(78, 84, 98, 255))
    return noise_fill(img, (48, 52, 62), 9)


def tile_glass():
    img = canvas(64, 64, (120, 190, 200, 70))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 63, 63], outline=(190, 230, 235, 200), width=3)
    d.line([10, 54, 54, 10], fill=(210, 240, 245, 90), width=4)
    d.line([20, 58, 58, 20], fill=(210, 240, 245, 50), width=2)
    return img


def tile_door():
    img = canvas(64, 64, (70, 52, 34, 255))
    d = ImageDraw.Draw(img)
    for i in range(0, 64, 12):
        d.line([i, 0, i, 64], fill=(52, 38, 24, 255), width=2)
    d.rectangle([0, 0, 63, 63], outline=(36, 26, 16, 255), width=3)
    d.ellipse([50, 28, 58, 36], fill=(160, 140, 80, 255))
    return noise_fill(img, (70, 52, 34), 8)


def tile_road():
    img = canvas(64, 64, (34, 36, 42, 255))
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x, y = rng.randint(0, 63), rng.randint(0, 63)
        d.point((x, y), fill=(46, 48, 56, 255))
    return noise_fill(img, (34, 36, 42), 8)


def tile_pavement():
    img = canvas(64, 64, (58, 62, 70, 255))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 31, 31], outline=(44, 47, 54, 255), width=2)
    d.rectangle([32, 32, 63, 63], outline=(44, 47, 54, 255), width=2)
    return noise_fill(img, (58, 62, 70), 9)


def tile_grate():
    img = canvas(64, 64, (40, 44, 50, 255))
    d = ImageDraw.Draw(img)
    for y in range(4, 64, 12):
        d.line([2, y, 62, y], fill=(24, 26, 32, 255), width=4)
    for x in range(4, 64, 16):
        d.line([x, 0, x, 64], fill=(58, 62, 70, 255), width=2)
    return noise_fill(img, (40, 44, 50), 8)


def tile_puddle():
    img = canvas(64, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 20, 58, 46], fill=(40, 60, 84, 120))
    d.ellipse([16, 26, 48, 40], fill=(70, 110, 150, 90))
    d.ellipse([22, 29, 36, 36], fill=(150, 200, 235, 80))
    return img


# ----------------------------------------------------------------------------
# props (top-down)
# ----------------------------------------------------------------------------
def prop_crate():
    img = canvas(64, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 59, 59], fill=(96, 74, 46, 255), outline=(56, 42, 24, 255), width=3)
    d.line([4, 4, 59, 59], fill=(72, 55, 32, 255), width=2)
    d.line([59, 4, 4, 59], fill=(72, 55, 32, 255), width=2)
    d.rectangle([10, 10, 53, 53], outline=(72, 55, 32, 255), width=2)
    return img


def prop_shelf(long=False):
    w, h = (128, 48) if long else (48, 96)
    img = canvas(w, h, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(62, 66, 74, 255), outline=(30, 33, 38, 255), width=3)
    if long:
        for y in range(8, h, 12):
            d.line([4, y, w - 4, y], fill=(86, 92, 102, 255), width=2)
        for _ in range(26):
            x = rng.randint(6, w - 10)
            y = rng.randint(4, h - 12)
            d.rectangle([x, y, x + rng.randint(4, 12), y + rng.randint(4, 8)],
                        fill=rng.choice([(120, 90, 60, 255), (90, 100, 120, 255), (110, 110, 100, 255)]))
    else:
        for x in range(8, w, 12):
            d.line([x, 4, x, h - 4], fill=(86, 92, 102, 255), width=2)
        for _ in range(26):
            x = rng.randint(4, w - 12)
            y = rng.randint(6, h - 10)
            d.rectangle([x, y, x + rng.randint(4, 8), y + rng.randint(4, 12)],
                        fill=rng.choice([(120, 90, 60, 255), (90, 100, 120, 255), (110, 110, 100, 255)]))
    return img


def prop_table():
    img = canvas(72, 56, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 2, 69, 53], radius=6, fill=(88, 70, 50, 255), outline=(50, 40, 28, 255), width=3)
    d.rounded_rectangle([8, 8, 63, 47], radius=4, outline=(110, 90, 66, 255), width=2)
    return img


def prop_desk():
    img = canvas(96, 56, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 95, 55], fill=(70, 74, 84, 255), outline=(34, 37, 44, 255), width=3)
    d.rectangle([8, 8, 40, 30], fill=(30, 34, 42, 255))
    d.rectangle([12, 12, 36, 26], fill=(60, 160, 170, 255))
    d.rectangle([52, 10, 86, 20], fill=(180, 180, 170, 255))
    d.rectangle([52, 26, 76, 44], fill=(52, 56, 64, 255))
    return img


def prop_bed():
    img = canvas(96, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 95, 63], fill=(66, 70, 82, 255), outline=(34, 37, 44, 255), width=3)
    d.rectangle([4, 4, 91, 24], fill=(150, 155, 160, 255))
    d.rectangle([4, 28, 91, 59], fill=(70, 90, 120, 255))
    d.line([4, 28, 91, 28], fill=(40, 50, 66, 255), width=2)
    return img


def prop_locker():
    img = canvas(40, 80, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 39, 79], fill=(58, 66, 76, 255), outline=(30, 34, 40, 255), width=3)
    d.line([20, 4, 20, 76], fill=(36, 42, 50, 255), width=2)
    d.rectangle([10, 12, 16, 22], fill=(150, 160, 170, 255))
    d.rectangle([24, 12, 30, 22], fill=(150, 160, 170, 255))
    return img


def prop_server():
    img = canvas(48, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 47, 63], fill=(28, 32, 40, 255), outline=(16, 18, 24, 255), width=3)
    for y in range(6, 60, 10):
        d.rectangle([4, y, 43, y + 6], fill=(40, 46, 56, 255))
        for x in range(7, 40, 8):
            c = rng.choice([(30, 220, 180, 255), (220, 60, 80, 255), (220, 180, 60, 255), (90, 100, 120, 255)])
            d.rectangle([x, y + 2, x + 3, y + 4], fill=c)
    return img


def prop_sofa():
    img = canvas(96, 48, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 2, 93, 45], radius=8, fill=(70, 60, 92, 255), outline=(40, 34, 56, 255), width=3)
    d.rounded_rectangle([8, 8, 87, 30], radius=6, fill=(86, 74, 112, 255))
    d.line([8, 34, 87, 34], fill=(40, 34, 56, 255), width=2)
    return img


def prop_vending():
    img = canvas(48, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 47, 63], fill=(150, 40, 60, 255), outline=(70, 20, 30, 255), width=3)
    d.rectangle([6, 6, 30, 44], fill=(30, 40, 60, 255))
    for y in range(10, 40, 10):
        d.rectangle([9, y, 27, y + 5], fill=rng.choice([(90, 200, 120, 255), (200, 190, 80, 255), (90, 140, 220, 255)]))
    d.rectangle([34, 10, 42, 30], fill=(220, 60, 80, 255))
    d.rectangle([34, 36, 42, 56], fill=(40, 40, 48, 255))
    return img


def prop_plant():
    img = canvas(48, 48, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([12, 30, 36, 46], fill=(120, 70, 40, 255))
    for _ in range(9):
        x = rng.randint(12, 36)
        y = rng.randint(6, 30)
        r = rng.randint(4, 9)
        d.ellipse([x - r, y - r, x + r, y + r], fill=rng.choice([(40, 100, 60, 255), (60, 140, 80, 255), (30, 80, 50, 255)]))
    return img


def prop_sandbags():
    img = canvas(96, 32, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for row in range(2):
        for i in range(6 - row):
            x = 4 + i * 16 + row * 8
            y = 3 + row * 14
            d.rounded_rectangle([x, y, x + 14, y + 12], radius=5, fill=(120, 108, 74, 255), outline=(80, 72, 48, 255))
    return img


def prop_car(color=(60, 90, 140)):
    img = canvas(160, 80, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 8, 155, 71], radius=14, fill=color + (255,), outline=(20, 24, 30, 255), width=3)
    d.rounded_rectangle([48, 14, 108, 65], radius=8, fill=(24, 30, 40, 255))
    d.rounded_rectangle([56, 18, 100, 61], radius=6, fill=(70, 90, 110, 255))
    d.rectangle([118, 16, 140, 26], fill=(230, 220, 140, 255))
    d.rectangle([118, 54, 140, 64], fill=(230, 220, 140, 255))
    for wx in (26, 128):
        d.rectangle([wx - 8, 4, wx + 8, 10], fill=(18, 20, 26, 255))
        d.rectangle([wx - 8, 70, wx + 8, 76], fill=(18, 20, 26, 255))
    return img


def prop_counter():
    img = canvas(128, 48, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 127, 47], fill=(74, 78, 88, 255), outline=(36, 39, 46, 255), width=3)
    d.rectangle([0, 0, 127, 10], fill=(96, 102, 114, 255))
    d.rectangle([10, 16, 40, 38], fill=(30, 34, 42, 255))
    d.rectangle([60, 14, 90, 34], fill=(170, 170, 160, 255))
    return img


def prop_reception():
    img = canvas(144, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2, 6, 141, 57], radius=6, fill=(70, 74, 86, 255), outline=(34, 37, 44, 255), width=3)
    d.rectangle([8, 12, 136, 22], fill=(92, 98, 112, 255))
    d.rectangle([16, 30, 48, 48], fill=(30, 34, 42, 255))
    d.rectangle([56, 30, 96, 48], fill=(60, 66, 78, 255))
    return img


def prop_archive_shelf():
    img = canvas(112, 44, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 111, 43], fill=(64, 62, 58, 255), outline=(32, 31, 29, 255), width=3)
    for y in range(6, 40, 10):
        d.line([3, y, 108, y], fill=(88, 86, 80, 255), width=2)
        x = 6
        while x < 104:
            w = rng.randint(4, 10)
            d.rectangle([x, y - 8, x + w, y - 1], fill=rng.choice([(110, 90, 70, 255), (90, 100, 90, 255), (120, 110, 95, 255)]))
            x += w + 1
    return img


def prop_bookshelf():
    img = canvas(120, 44, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 119, 43], fill=(72, 58, 40, 255), outline=(36, 28, 18, 255), width=3)
    for y in range(6, 40, 10):
        d.line([3, y, 116, y], fill=(94, 76, 52, 255), width=2)
        x = 5
        while x < 112:
            w = rng.randint(3, 7)
            d.rectangle([x, y - 8, x + w, y - 1], fill=rng.choice([(120, 70, 60, 255), (70, 100, 80, 255), (90, 90, 120, 255), (140, 120, 80, 255)]))
            x += w + 1
    return img


def prop_filing():
    img = canvas(40, 56, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 39, 55], fill=(78, 80, 86, 255), outline=(36, 38, 42, 255), width=3)
    for y in range(6, 52, 14):
        d.rectangle([4, y, 35, y + 10], fill=(60, 62, 68, 255))
        d.rectangle([14, y + 3, 25, y + 6], fill=(170, 170, 160, 255))
    return img


def prop_stage():
    img = canvas(160, 96, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 159, 95], fill=(56, 44, 66, 255), outline=(30, 24, 38, 255), width=3)
    d.rectangle([8, 8, 151, 79], outline=(90, 70, 110, 255), width=2)
    d.rectangle([60, 12, 100, 40], fill=(150, 60, 110, 255))
    d.rectangle([70, 20, 90, 32], fill=(220, 190, 220, 255))
    return img


def prop_cinema_rows():
    img = canvas(128, 96, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(6, 92, 18):
        for x in range(4, 124, 20):
            d.rounded_rectangle([x, y, x + 14, y + 12], radius=3, fill=(120, 40, 56, 255), outline=(60, 20, 28, 255))
    return img


def prop_gym_mat():
    img = canvas(128, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 127, 63], fill=(40, 90, 110, 255), outline=(24, 56, 70, 255), width=3)
    d.line([0, 32, 127, 32], fill=(24, 56, 70, 255), width=2)
    return img


def prop_popcorn():
    img = canvas(56, 56, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 10, 50, 50], radius=6, fill=(170, 60, 60, 255), outline=(90, 30, 30, 255), width=3)
    for i in range(5):
        x = 12 + i * 8
        d.line([x, 10, x, 50], fill=(230, 200, 120, 255), width=2)
    d.ellipse([12, 4, 44, 16], fill=(240, 230, 190, 255))
    return img


def prop_dumpster():
    img = canvas(96, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 6, 95, 63], fill=(52, 76, 60, 255), outline=(28, 42, 32, 255), width=3)
    d.rectangle([0, 0, 95, 12], fill=(66, 94, 76, 255), outline=(28, 42, 32, 255), width=3)
    for x in range(8, 92, 16):
        d.line([x, 14, x, 62], fill=(36, 54, 42, 255), width=2)
    return img


def prop_barrel():
    img = canvas(32, 32, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 30, 30], fill=(120, 84, 40, 255), outline=(60, 42, 20, 255), width=3)
    d.ellipse([6, 6, 25, 25], outline=(90, 62, 30, 255), width=2)
    return img


def prop_kiosk():
    img = canvas(64, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 59, 59], fill=(56, 70, 88, 255), outline=(26, 34, 44, 255), width=3)
    d.rectangle([10, 10, 53, 34], fill=(30, 60, 80, 255))
    d.rectangle([14, 14, 49, 30], fill=(80, 200, 220, 255))
    d.rectangle([10, 40, 53, 52], fill=(40, 50, 62, 255))
    return img


def prop_atm():
    img = canvas(48, 64, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 47, 63], fill=(60, 66, 76, 255), outline=(30, 34, 40, 255), width=3)
    d.rectangle([6, 8, 41, 28], fill=(90, 200, 220, 255))
    d.rectangle([6, 34, 41, 52], fill=(36, 40, 48, 255))
    return img


def prop_bench():
    img = canvas(96, 32, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in (6, 14, 22):
        d.rectangle([4, y, 91, y + 5], fill=(96, 76, 52, 255))
    d.rectangle([4, 0, 10, 31], fill=(50, 54, 62, 255))
    d.rectangle([85, 0, 91, 31], fill=(50, 54, 62, 255))
    return img


# ----------------------------------------------------------------------------
# characters (top-down, facing +X)
# ----------------------------------------------------------------------------
def base_char(size=96):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size // 2
    # soft shadow
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.ellipse([c - 20, c - 14, c + 22, c + 18], fill=(0, 0, 0, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(sh)
    return img, d


def char_body(img, d, body, shoulders, head, hood=False, helmet=False, cap=False,
              vest=False, armband=None, pack=False, stripes=None, coat=False,
              bag=False, hat=False, badge=None, size=96):
    c = size // 2
    # torso (pointing +X)
    d.rounded_rectangle([c - 22, c - 16, c + 20, c + 16], radius=12, fill=body + (255,), outline=(18, 20, 26, 255), width=2)
    # shoulders
    d.ellipse([c - 14, c - 22, c + 2, c - 6], fill=shoulders + (255,), outline=(18, 20, 26, 255), width=2)
    d.ellipse([c - 14, c + 6, c + 2, c + 22], fill=shoulders + (255,), outline=(18, 20, 26, 255), width=2)
    # head
    d.ellipse([c + 6, c - 9, c + 24, c + 9], fill=head + (255,), outline=(18, 20, 26, 255), width=2)
    if helmet:
        d.pieslice([c + 2, c - 13, c + 28, c + 13], 270, 90, fill=(30, 38, 48, 255))
        d.ellipse([c + 10, c - 7, c + 22, c + 7], fill=(140, 170, 200, 255))
    if cap:
        d.pieslice([c + 2, c - 12, c + 26, c + 12], 270, 90, fill=(26, 34, 52, 255))
        d.rectangle([c + 20, c - 4, c + 30, c + 4], fill=(26, 34, 52, 255))
    if hood:
        d.pieslice([c + 0, c - 13, c + 28, c + 13], 260, 100, fill=(24, 28, 34, 255))
    if hat:
        d.ellipse([c + 2, c - 12, c + 26, c + 12], fill=(40, 36, 30, 255))
        d.ellipse([c + 9, c - 6, c + 19, c + 6], fill=(52, 46, 38, 255))
    if vest:
        d.rounded_rectangle([c - 18, c - 12, c + 16, c + 12], radius=8, fill=(30, 36, 44, 255), outline=(14, 16, 20, 255), width=2)
    if stripes:
        for sy in stripes:
            d.rectangle([c - 6, c + sy, c + 8, c + sy + 3], fill=(200, 220, 120, 255))
    if armband:
        d.rectangle([c - 16, c - 20, c - 8, c - 14], fill=armband + (255,))
    if pack:
        d.rounded_rectangle([c - 30, c - 14, c - 18, c + 14], radius=5, fill=(70, 60, 40, 255), outline=(30, 26, 18, 255), width=2)
    if coat:
        d.polygon([(c - 22, c - 14), (c - 34, c - 20), (c - 34, c + 20), (c - 22, c + 14)], fill=body + (255,))
    if bag:
        d.rounded_rectangle([c - 36, c + 16, c - 20, c + 32], radius=4, fill=(150, 110, 60, 255), outline=(70, 50, 26, 255), width=2)
    if badge:
        d.rectangle([c - 2, c - 8, c + 6, c - 3], fill=badge + (255,))
    return img


def gun_arm(d, size=96, length=30, color=(20, 22, 28)):
    c = size // 2
    d.rectangle([c + 18, c - 4, c + 18 + length, c + 4], fill=color + (255,))
    d.rectangle([c + 14, c - 8, c + 22, c + 8], fill=(40, 36, 32, 255))


def save_char(img, name):
    return save(img, name)


CRIM_COLORS = [
    ((64, 74, 88), (40, 48, 60), (196, 160, 128)),   # hoodie
    ((88, 60, 44), (56, 38, 28), (180, 140, 110)),   # jacket
    ((52, 66, 58), (34, 44, 38), (200, 166, 132)),   # vest
    ((70, 52, 74), (46, 34, 50), (188, 150, 122)),   # courier
]
COP_COLORS = [
    ((34, 52, 84), (24, 38, 62), (196, 160, 128)),   # patrol
    ((30, 44, 66), (22, 32, 50), (190, 154, 124)),   # response
    ((52, 74, 84), (36, 52, 60), (196, 160, 128)),   # medic
    ((58, 62, 72), (40, 44, 52), (200, 166, 132)),   # negotiator
    ((48, 44, 56), (32, 30, 40), (188, 152, 124)),   # investigator
]
CIV_COLORS = [
    ((90, 82, 70), (64, 58, 48), (206, 172, 140)),
    ((72, 78, 84), (50, 54, 60), (198, 162, 130)),
    ((84, 66, 66), (58, 46, 46), (204, 168, 136)),
    ((66, 84, 74), (46, 60, 52), (200, 164, 132)),
    ((96, 88, 62), (68, 62, 42), (210, 176, 144)),
    ((78, 70, 90), (54, 48, 64), (196, 160, 130)),
]


def gen_characters():
    for i, (body, sh, head) in enumerate(CRIM_COLORS):
        img, d = base_char()
        char_body(img, d, body, sh, head, hood=(i == 0), pack=(i == 3), vest=(i == 2),
                  coat=(i == 1), bag=(i == 3))
        gun_arm(d)
        save_char(img, "char_crim_%d.png" % (i + 1))
    # police
    img, d = base_char()
    char_body(img, d, *COP_COLORS[0], cap=True, stripes=[-6, 0])
    gun_arm(d)
    save_char(img, "char_cop_patrol.png")
    img, d = base_char()
    char_body(img, d, *COP_COLORS[1], helmet=True, vest=True, stripes=[-6, 0])
    gun_arm(d)
    save_char(img, "char_cop_response.png")
    img, d = base_char()
    char_body(img, d, *COP_COLORS[2], armband=(190, 220, 230), stripes=[-6, 0])
    save_char(img, "char_cop_medic.png")
    img, d = base_char()
    char_body(img, d, *COP_COLORS[3], badge=(220, 190, 90))
    gun_arm(d, length=22)
    save_char(img, "char_cop_neg.png")
    img, d = base_char()
    char_body(img, d, *COP_COLORS[4], hat=True, coat=True)
    gun_arm(d, length=22)
    save_char(img, "char_cop_inv.png")
    for i, (body, sh, head) in enumerate(CIV_COLORS):
        img, d = base_char()
        char_body(img, d, body, sh, head, bag=(i % 2 == 1), hat=(i == 4))
        save_char(img, "char_civ_%d.png" % (i + 1))


# ----------------------------------------------------------------------------
# FX
# ----------------------------------------------------------------------------
def fx_blood(seed):
    r = random.Random(seed)
    img = canvas(64, 64)
    d = ImageDraw.Draw(img)
    cx, cy = 32, 32
    for _ in range(r.randint(8, 14)):
        ang = r.random() * math.tau
        dist = r.random() * 20
        x = cx + math.cos(ang) * dist
        y = cy + math.sin(ang) * dist
        rad = r.randint(2, 8)
        col = r.choice([(120, 12, 24, 220), (90, 8, 18, 200), (150, 20, 30, 210)])
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=col)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def fx_flash():
    img = canvas(64, 64)
    d = ImageDraw.Draw(img)
    d.ellipse([24, 24, 40, 40], fill=(255, 240, 180, 255))
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        x = 32 + math.cos(a) * 26
        y = 32 + math.sin(a) * 26
        d.line([32, 32, x, y], fill=(255, 210, 120, 220), width=3)
    return img.filter(ImageFilter.GaussianBlur(1.2))


def fx_smoke():
    img = canvas(128, 128)
    d = ImageDraw.Draw(img)
    for _ in range(40):
        x = rng.randint(20, 108)
        y = rng.randint(20, 108)
        rad = rng.randint(10, 26)
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(120, 130, 150, 26))
    return img.filter(ImageFilter.GaussianBlur(10))


def fx_tracer():
    img = canvas(64, 16)
    d = ImageDraw.Draw(img)
    for x in range(64):
        a = int(220 * (1.0 - x / 63.0))
        d.line([x, 6, x, 9], fill=(255, 220, 140, a))
    return img


def fx_shell():
    img = canvas(16, 16)
    d = ImageDraw.Draw(img)
    d.rectangle([3, 5, 12, 10], fill=(210, 180, 90, 255))
    d.rectangle([3, 5, 5, 10], fill=(160, 130, 60, 255))
    return img


# ----------------------------------------------------------------------------
# UI icons
# ----------------------------------------------------------------------------
def icon_bg(shape="square", color=(20, 26, 34)):
    img = canvas(48, 48, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if shape == "square":
        d.rounded_rectangle([3, 3, 44, 44], radius=8, fill=color + (230,), outline=(70, 80, 96, 255), width=2)
    elif shape == "circle":
        d.ellipse([3, 3, 44, 44], fill=color + (230,), outline=(70, 80, 96, 255), width=2)
    elif shape == "tri":
        d.polygon([(24, 3), (44, 42), (4, 42)], fill=color + (230,), outline=(70, 80, 96, 255))
    return img, d


def gen_icons():
    def weapon(name, draw):
        img, d = icon_bg("square")
        draw(d)
        save(img, "icon_%s.png" % name)

    weapon("pistol", lambda d: (d.rectangle([12, 20, 36, 27], fill=(200, 205, 215, 255)),
                                d.rectangle([15, 26, 22, 38], fill=(150, 155, 165, 255))))
    weapon("smg", lambda d: (d.rectangle([8, 20, 40, 27], fill=(190, 196, 208, 255)),
                             d.rectangle([18, 26, 25, 40], fill=(140, 146, 158, 255)),
                             d.rectangle([32, 27, 38, 33], fill=(140, 146, 158, 255))))
    weapon("carbine", lambda d: (d.rectangle([6, 21, 42, 27], fill=(196, 202, 214, 255)),
                                 d.rectangle([16, 27, 24, 39], fill=(146, 152, 164, 255)),
                                 d.rectangle([8, 17, 14, 22], fill=(120, 126, 138, 255))))
    weapon("shotgun", lambda d: (d.rectangle([6, 21, 42, 28], fill=(176, 150, 110, 255)),
                                 d.rectangle([20, 20, 28, 34], fill=(120, 96, 66, 255))))
    weapon("marksman", lambda d: (d.rectangle([6, 23, 42, 27], fill=(186, 192, 204, 255)),
                                  d.rectangle([20, 15, 28, 23], fill=(110, 150, 170, 255)),
                                  d.rectangle([16, 27, 24, 38], fill=(130, 136, 148, 255))))
    weapon("taser", lambda d: (d.rectangle([14, 18, 34, 30], fill=(90, 200, 220, 255)),
                               d.line([18, 30, 18, 40], fill=(200, 220, 230, 255), width=2),
                               d.line([30, 30, 30, 40], fill=(200, 220, 230, 255), width=2)))
    weapon("melee", lambda d: (d.line([14, 38, 34, 16], fill=(220, 224, 230, 255), width=5),
                               d.line([14, 38, 34, 16], fill=(150, 156, 166, 255), width=2)))

    def gadget(name, draw):
        img, d = icon_bg("circle")
        draw(d)
        save(img, "icon_%s.png" % name)

    gadget("medkit", lambda d: (d.rectangle([12, 16, 36, 34], fill=(220, 224, 228, 255)),
                                d.rectangle([21, 19, 27, 31], fill=(210, 50, 60, 255)),
                                d.rectangle([15, 23, 33, 27], fill=(210, 50, 60, 255))))
    gadget("armor", lambda d: (d.polygon([(24, 12), (36, 18), (36, 30), (24, 40), (12, 30), (12, 18)],
                                fill=(90, 110, 140, 255), outline=(200, 210, 225, 255))))
    gadget("flash", lambda d: (d.ellipse([16, 16, 32, 32], fill=(240, 240, 220, 255)),
                               d.line([24, 8, 24, 16], fill=(255, 220, 120, 255), width=3),
                               d.line([24, 32, 24, 40], fill=(255, 220, 120, 255), width=3)))
    gadget("smoke", lambda d: (d.ellipse([14, 18, 34, 34], fill=(150, 160, 175, 255)),
                               d.ellipse([20, 12, 30, 24], fill=(190, 198, 210, 255))))
    gadget("ammo", lambda d: (d.rectangle([14, 18, 22, 34], fill=(210, 180, 90, 255)),
                              d.rectangle([24, 18, 32, 34], fill=(190, 160, 70, 255)),
                              d.rectangle([15, 14, 21, 18], fill=(240, 210, 120, 255)),
                              d.rectangle([25, 14, 31, 18], fill=(240, 210, 120, 255))))
    gadget("radio", lambda d: (d.rectangle([18, 20, 30, 38], fill=(70, 90, 110, 255)),
                               d.line([24, 20, 24, 8], fill=(150, 170, 190, 255), width=2),
                               d.ellipse([21, 24, 27, 30], fill=(120, 220, 180, 255))))
    gadget("camera", lambda d: (d.rectangle([12, 18, 34, 32], fill=(60, 70, 84, 255)),
                                d.ellipse([19, 22, 27, 28], fill=(140, 220, 200, 255)),
                                d.rectangle([34, 22, 40, 28], fill=(80, 90, 104, 255))))
    gadget("breach", lambda d: (d.rectangle([14, 20, 34, 32], fill=(150, 120, 60, 255)),
                                d.line([24, 20, 24, 32], fill=(90, 70, 36, 255), width=3)))

    def role(name, draw):
        img, d = icon_bg("tri")
        draw(d)
        save(img, "icon_role_%s.png" % name)

    role("observer", lambda d: (d.ellipse([14, 18, 34, 34], fill=(200, 210, 225, 255)),
                                d.ellipse([21, 24, 27, 28], fill=(20, 26, 34, 255))))
    role("technician", lambda d: (d.line([18, 34, 32, 20], fill=(210, 215, 225, 255), width=4),
                                  d.rectangle([28, 14, 36, 24], fill=(210, 215, 225, 255))))
    role("medic", lambda d: (d.rectangle([21, 16, 27, 34], fill=(220, 60, 70, 255)),
                             d.rectangle([15, 22, 33, 28], fill=(220, 60, 70, 255))))
    role("support", lambda d: (d.rectangle([14, 22, 34, 32], fill=(210, 180, 90, 255)),
                               d.rectangle([18, 16, 30, 22], fill=(190, 160, 70, 255))))
    role("negotiator", lambda d: (d.ellipse([16, 16, 32, 32], fill=(150, 200, 220, 255)),
                                  d.rectangle([22, 24, 26, 36], fill=(90, 140, 170, 255))))
    role("guardian", lambda d: (d.polygon([(24, 14), (34, 19), (34, 30), (24, 38), (14, 30), (14, 19)],
                                   fill=(120, 160, 200, 255))))

    # team markers
    img, d = icon_bg("tri", (20, 40, 34))
    save(img, "marker_criminals.png")
    img, d = icon_bg("circle", (24, 34, 46))
    save(img, "marker_police.png")
    img, d = icon_bg("square", (36, 34, 30))
    save(img, "marker_civilian.png")
    img, d = icon_bg("tri", (34, 28, 20))
    d.polygon([(24, 10), (38, 36), (10, 36)], fill=(230, 190, 80, 255))
    save(img, "marker_objective.png")
    img, d = icon_bg("circle", (30, 26, 24))
    d.ellipse([16, 14, 32, 30], fill=(235, 235, 235, 255))
    d.ellipse([20, 18, 24, 24], fill=(20, 20, 20, 255))
    d.ellipse([26, 18, 30, 24], fill=(20, 20, 20, 255))
    save(img, "marker_skull.png")


# ----------------------------------------------------------------------------
# audio synthesis
# ----------------------------------------------------------------------------
SR = 22050


def write_wav(path, samples, rate=SR):
    samples = np.asarray(samples, dtype=np.float64)
    peak = np.max(np.abs(samples)) if samples.size else 1.0
    if peak > 0:
        samples = samples / peak * 0.85
    pcm = (samples * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def env(n, attack=0.01, release=0.3):
    e = np.ones(n)
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    e[:a] = np.linspace(0, 1, a)
    e[-r:] *= np.linspace(1, 0, r)
    return e


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def shot(dur, freq, noise_amt, decay, tone_amt=0.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = np.random.RandomState(int(freq * 1000) & 0xFFFF).randn(n)
    body = np.sin(2 * math.pi * freq * t) * np.exp(-t * 18)
    crack = noise * np.exp(-t * 40)
    sig = tone_amt * body + noise_amt * crack
    sig = lowpass(sig, 0.35)
    return sig * env(n, 0.002, decay)


def gen_sounds():
    specs = {
        "shoot_pistol": shot(0.22, 180, 1.0, 0.12),
        "shoot_smg": shot(0.14, 220, 0.9, 0.09),
        "shoot_carbine": shot(0.2, 160, 1.0, 0.11),
        "shoot_shotgun": shot(0.4, 110, 1.2, 0.25),
        "shoot_marksman": shot(0.5, 90, 1.1, 0.3),
        "dryfire": None,
        "reload_start": None,
        "reload_end": None,
        "footstep_concrete": None,
        "footstep_wood": None,
        "footstep_metal": None,
        "door_open": None,
        "door_close": None,
        "hit_flesh": None,
        "hit_armor": None,
        "glass_break": None,
        "alarm": None,
        "ui_click": None,
        "ui_hover": None,
        "radio_blip": None,
        "plant_beep": None,
        "defuse_beep": None,
        "pickup": None,
        "heal": None,
        "taser": None,
        "flashbang": None,
        "smoke": None,
        "siren": None,
        "order_ack": None,
        "objective": None,
        "round_win": None,
        "round_lose": None,
    }
    # dryfire
    n = int(0.06 * SR)
    specs["dryfire"] = np.random.RandomState(7).randn(n) * np.exp(-np.arange(n) / (0.012 * SR)) * 0.5
    # reload
    n = int(0.18 * SR)
    specs["reload_start"] = np.random.RandomState(11).randn(n) * np.exp(-np.arange(n) / (0.05 * SR)) * 0.5
    n = int(0.14 * SR)
    specs["reload_end"] = (np.sin(2 * math.pi * 900 * np.arange(n) / SR) * 0.3 + np.random.RandomState(12).randn(n) * 0.2) * np.exp(-np.arange(n) / (0.04 * SR))
    # footsteps
    for name, f, dur in [("footstep_concrete", 300, 0.09), ("footstep_wood", 420, 0.1), ("footstep_metal", 900, 0.12)]:
        n = int(dur * SR)
        r = np.random.RandomState(hash(name) & 0xFFFF)
        sig = r.randn(n) * np.exp(-np.arange(n) / (0.025 * SR))
        sig += 0.25 * np.sin(2 * math.pi * f * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.03 * SR))
        specs[name] = lowpass(sig, 0.2)
    # doors
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    specs["door_open"] = (np.sin(2 * math.pi * (140 + 90 * t) * t) * 0.4 + np.random.RandomState(21).randn(n) * 0.08) * env(n, 0.05, 0.35)
    n = int(0.2 * SR)
    specs["door_close"] = np.random.RandomState(22).randn(n) * np.exp(-np.arange(n) / (0.05 * SR)) * 0.6
    # hits
    n = int(0.15 * SR)
    specs["hit_flesh"] = (np.random.RandomState(31).randn(n) * 0.7 + np.sin(2 * math.pi * 120 * np.arange(n) / SR) * 0.4) * np.exp(-np.arange(n) / (0.04 * SR))
    n = int(0.12 * SR)
    specs["hit_armor"] = (np.random.RandomState(32).randn(n) * 0.4 + np.sin(2 * math.pi * 1400 * np.arange(n) / SR) * 0.5) * np.exp(-np.arange(n) / (0.02 * SR))
    # glass
    n = int(0.35 * SR)
    r = np.random.RandomState(33)
    specs["glass_break"] = (r.randn(n) * np.exp(-np.arange(n) / (0.08 * SR)) + 0.4 * np.sin(2 * math.pi * 2400 * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.05 * SR)))
    # alarm
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    specs["alarm"] = (np.sign(np.sin(2 * math.pi * 620 * t)) * 0.25 + np.sign(np.sin(2 * math.pi * 470 * t)) * 0.25) * (0.6 + 0.4 * np.sin(2 * math.pi * 2 * t)) * env(n, 0.02, 0.4)
    # ui
    n = int(0.07 * SR)
    specs["ui_click"] = np.sin(2 * math.pi * 1400 * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.015 * SR)) * 0.4
    n = int(0.05 * SR)
    specs["ui_hover"] = np.sin(2 * math.pi * 900 * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.012 * SR)) * 0.25
    # radio
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    specs["radio_blip"] = (np.sin(2 * math.pi * 1200 * t) * (t < 0.07) + np.sin(2 * math.pi * 800 * t) * (t >= 0.07)) * env(n, 0.004, 0.04) * 0.4
    # beeps
    for name, f, reps in [("plant_beep", 1000, 3), ("defuse_beep", 700, 2)]:
        segs = []
        for i in range(reps):
            n = int(0.09 * SR)
            segs.append(np.sin(2 * math.pi * f * np.arange(n) / SR) * env(n, 0.005, 0.03) * 0.4)
            segs.append(np.zeros(int(0.08 * SR)))
        specs[name] = np.concatenate(segs)
    # pickup / heal
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    specs["pickup"] = (np.sin(2 * math.pi * 660 * t) + 0.5 * np.sin(2 * math.pi * 990 * t)) * env(n, 0.005, 0.05) * 0.4
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    specs["heal"] = (np.sin(2 * math.pi * 520 * t) + 0.6 * np.sin(2 * math.pi * 780 * t) * (t > 0.12)) * env(n, 0.02, 0.2) * 0.35
    # taser
    n = int(0.3 * SR)
    specs["taser"] = np.sign(np.random.RandomState(41).randn(n)) * 0.3 * (0.5 + 0.5 * np.sin(2 * math.pi * 28 * np.arange(n) / SR)) * env(n, 0.005, 0.1)
    # flashbang
    n = int(0.8 * SR)
    specs["flashbang"] = (np.random.RandomState(42).randn(n) * np.exp(-np.arange(n) / (0.06 * SR)) + np.sin(2 * math.pi * 3400 * np.arange(n) / SR) * np.exp(-np.arange(n) / (0.3 * SR)) * 0.5)
    # smoke
    n = int(0.9 * SR)
    specs["smoke"] = lowpass(np.random.RandomState(43).randn(n), 0.08) * env(n, 0.05, 0.4) * 0.7
    # siren
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    specs["siren"] = (np.sin(2 * math.pi * (700 + 250 * np.sin(2 * math.pi * 0.8 * t)) * t) * 0.3) * env(n, 0.1, 0.5)
    # order ack
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    specs["order_ack"] = (np.sin(2 * math.pi * 880 * t) + np.sin(2 * math.pi * 1175 * t) * (t > 0.05)) * env(n, 0.005, 0.04) * 0.35
    # objective
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    specs["objective"] = (np.sin(2 * math.pi * 523 * t) + np.sin(2 * math.pi * 659 * t) * (t > 0.1) + np.sin(2 * math.pi * 784 * t) * (t > 0.2)) * env(n, 0.01, 0.2) * 0.35
    # round win/lose
    for name, base in [("round_win", 523), ("round_lose", 220)]:
        segs = []
        steps = [1.0, 1.25, 1.5] if name == "round_win" else [1.0, 0.9, 0.8]
        for k in steps:
            n = int(0.16 * SR)
            segs.append(np.sin(2 * math.pi * base * k * np.arange(n) / SR) * env(n, 0.01, 0.06) * 0.4)
            segs.append(np.zeros(int(0.07 * SR)))
        specs[name] = np.concatenate(segs)

    for name, sig in specs.items():
        if sig is None:
            continue
        write_wav(os.path.join(SND, name + ".wav"), sig)
    print("sounds:", len([k for k, v in specs.items() if v is not None]))


def rain_loop(dur=10.0):
    n = int(dur * SR)
    r = np.random.RandomState(101)
    x = r.randn(n)
    # pink-ish: integrate + highpass mix
    y = lowpass(x, 0.12)
    y = y + 0.3 * x
    # slow amplitude modulation for gusts
    t = np.arange(n) / SR
    y *= 0.7 + 0.3 * np.sin(2 * math.pi * 0.13 * t)
    return y * env(n, 0.5, 1.0)


def room_loop(dur=8.0):
    n = int(dur * SR)
    r = np.random.RandomState(102)
    hum = np.sin(2 * np.pi * 60 * np.arange(n) / SR) * 0.12 + np.sin(2 * np.pi * 120 * np.arange(n) / SR) * 0.05
    air = lowpass(r.randn(n), 0.03) * 0.4
    t = np.arange(n) / SR
    return (hum + air) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.2 * t)) * env(n, 0.5, 1.0)


def music_loop(name, dur=16.0, bpm=92, root=55.0, mode="minor", bright=0.0, beat=True):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    # chord progression: i - VI - III - VII (minor)
    if mode == "minor":
        ratios = [[1, 1.189, 1.498], [0.841, 1, 1.189], [0.667, 0.841, 1], [0.561, 0.667, 0.841]]
    else:
        ratios = [[1, 1.26, 1.498], [0.794, 1, 1.26], [0.63, 0.794, 1], [0.891, 1.122, 1.335]]
    bar = 60.0 / bpm * 4
    for i, ch in enumerate(ratios):
        start = int(i * bar * SR)
        end = min(n, int((i + 1) * bar * SR))
        if start >= n:
            break
        seg = end - start
        tt = np.arange(seg) / SR
        pad = np.zeros(seg)
        for r in ch:
            f = root * r
            pad += np.sin(2 * np.pi * f * tt) * 0.12
            pad += np.sin(2 * math.pi * f * 2.001 * tt) * 0.03
        pad += np.sin(2 * math.pi * root * 0.5 * tt) * 0.16
        lfo = 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * tt)
        sig[start:end] += pad * lfo * env(seg, 0.4, 0.6)
    if beat:
        spb = 60.0 / bpm
        for k in range(int(dur / spb) + 1):
            start = int(k * spb * SR)
            if start >= n:
                break
            # kick
            ln = min(int(0.16 * SR), n - start)
            tt = np.arange(ln) / SR
            sig[start:start + ln] += np.sin(2 * np.pi * (90 * np.exp(-tt * 8) + 40) * tt) * np.exp(-tt * 14) * 0.5
            # hat on offbeat
            hs = start + int(spb * 0.5 * SR)
            if hs < n:
                ln2 = min(int(0.04 * SR), n - hs)
                sig[hs:hs + ln2] += np.random.RandomState(k).randn(ln2) * np.exp(-np.arange(ln2) / (0.008 * SR)) * (0.05 + bright * 0.08)
    # sparse lead line
    if bright > 0.2:
        scale = [1, 1.189, 1.335, 1.498, 1.782]
        r = np.random.RandomState(7 + int(bright * 10))
        for k in range(int(dur / (60.0 / bpm * 2))):
            if r.random() > 0.55:
                start = int(k * (60.0 / bpm * 2) * SR)
                ln = min(int(0.5 * SR), n - start)
                tt = np.arange(ln) / SR
                f = root * 4 * scale[r.randint(0, len(scale) - 1)]
                sig[start:start + ln] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 3) * 0.06 * bright
    return sig * env(n, 1.0, 2.0)


def gen_music():
    loops = {
        "music_menu": music_loop("menu", 20.0, 76, 55.0, "minor", 0.1, beat=False),
        "music_match": music_loop("match", 16.0, 100, 55.0, "minor", 0.35, beat=True),
        "music_tension": music_loop("tension", 16.0, 118, 61.7, "minor", 0.6, beat=True),
        "music_results": music_loop("results", 16.0, 84, 65.4, "major", 0.25, beat=False),
    }
    for name, sig in loops.items():
        write_wav(os.path.join(MUS, name + ".wav"), sig)
    write_wav(os.path.join(SND, "ambient_rain.wav"), rain_loop())
    write_wav(os.path.join(SND, "ambient_room.wav"), room_loop())
    print("music loops:", len(loops))


def bg_menu():
    w, h = 1920, 1080
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([0, y, w, y], fill=(int(8 + 10 * t), int(10 + 12 * t), int(16 + 20 * t), 255))
    x = 0
    while x < w:
        bw = rng.randint(60, 220)
        bh = rng.randint(220, 620)
        top = h - bh
        shade = rng.randint(12, 28)
        d.rectangle([x, top, x + bw, h], fill=(shade, shade + 2, shade + 6, 255))
        wy = top + 12
        while wy < h - 12:
            for wx in range(x + 8, x + bw - 10, 14):
                if rng.random() < 0.13:
                    col = rng.choice([(120, 220, 200), (220, 180, 90), (200, 90, 140), (90, 160, 230)])
                    d.rectangle([wx, wy, wx + 5, wy + 7], fill=col + (255,))
            wy += 18
        x += bw + rng.randint(6, 26)
    d.rectangle([0, h - 190, w, h], fill=(9, 11, 15, 255))
    for _ in range(220):
        rx = rng.randint(0, w - 60)
        ry = rng.randint(h - 180, h - 6)
        col = rng.choice([(60, 180, 160), (200, 90, 120), (90, 140, 220), (200, 170, 80)])
        d.line([rx, ry, rx + rng.randint(12, 70), ry], fill=col + (rng.randint(30, 110),))
    for _ in range(1100):
        rx = rng.randint(0, w)
        ry = rng.randint(0, h)
        ln = rng.randint(6, 18)
        d.line([rx, ry, rx - 2, ry + ln], fill=(160, 190, 220, rng.randint(16, 48)))
    for _ in range(16):
        sx = rng.randint(0, w - 130)
        sy = rng.randint(180, h - 320)
        sw = rng.randint(40, 130)
        sh = rng.randint(20, 70)
        col = rng.choice([(255, 60, 120), (60, 230, 200), (255, 180, 60), (140, 90, 255)])
        d.rectangle([sx, sy, sx + sw, sy + sh], outline=col + (255,), width=3)
        d.rectangle([sx + 4, sy + 4, sx + sw - 4, sy + sh - 4], outline=col + (110,), width=1)
    return img.filter(ImageFilter.GaussianBlur(0.5))


# ----------------------------------------------------------------------------
def gen_textures():
    save(tile_floor_concrete(), "floor_concrete.png")
    save(tile_floor_tile(), "floor_tile.png")
    save(tile_floor_wood(), "floor_wood.png")
    save(tile_floor_carpet(), "floor_carpet.png")
    save(tile_wall(), "wall.png")
    save(tile_wall_dark(), "wall_dark.png")
    save(tile_glass(), "glass.png")
    save(tile_door(), "door.png")
    save(tile_road(), "road.png")
    save(tile_pavement(), "pavement.png")
    save(tile_grate(), "grate.png")
    save(tile_puddle(), "puddle.png")

    save(prop_crate(), "prop_crate.png")
    save(prop_shelf(False), "prop_shelf.png")
    save(prop_shelf(True), "prop_shelf_long.png")
    save(prop_table(), "prop_table.png")
    save(prop_desk(), "prop_desk.png")
    save(prop_bed(), "prop_bed.png")
    save(prop_locker(), "prop_locker.png")
    save(prop_server(), "prop_server.png")
    save(prop_sofa(), "prop_sofa.png")
    save(prop_vending(), "prop_vending.png")
    save(prop_plant(), "prop_plant.png")
    save(prop_sandbags(), "prop_sandbags.png")
    save(prop_car((60, 90, 140)), "prop_car_blue.png")
    save(prop_car((140, 70, 60)), "prop_car_red.png")
    save(prop_counter(), "prop_counter.png")
    save(prop_reception(), "prop_reception.png")
    save(prop_archive_shelf(), "prop_archive_shelf.png")
    save(prop_bookshelf(), "prop_bookshelf.png")
    save(prop_filing(), "prop_filing.png")
    save(prop_stage(), "prop_stage.png")
    save(prop_cinema_rows(), "prop_cinema_rows.png")
    save(prop_gym_mat(), "prop_gym_mat.png")
    save(prop_popcorn(), "prop_popcorn.png")
    save(prop_dumpster(), "prop_dumpster.png")
    save(prop_barrel(), "prop_barrel.png")
    save(prop_kiosk(), "prop_kiosk.png")
    save(prop_atm(), "prop_atm.png")
    save(prop_bench(), "prop_bench.png")

    save(fx_blood(1), "fx_blood_1.png")
    save(fx_blood(2), "fx_blood_2.png")
    save(fx_blood(3), "fx_blood_3.png")
    save(fx_flash(), "fx_flash.png")
    save(fx_smoke(), "fx_smoke.png")
    save(fx_tracer(), "fx_tracer.png")
    save(fx_shell(), "fx_shell.png")
    save(bg_menu(), "bg_menu.png")
    print("textures done")


def main():
    gen_textures()
    gen_characters()
    gen_icons()
    gen_sounds()
    gen_music()
    print("ASSET GENERATION COMPLETE")


if __name__ == "__main__":
    main()
