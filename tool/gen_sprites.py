#!/usr/bin/env python3
"""Generates the original pixel art in assets/sprites/ (replaces the former
third-party sheets with the same file names, sizes and frame layouts).

    python3 tool/gen_sprites.py

Palette matches the render code: steel greys from the industrial theme.
"""
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
FAR = (0x86, 0x86, 0x96, 255)
MID = (0x64, 0x6A, 0x7D, 255)
LIGHT = (0xB0, 0xB0, 0xBF, 255)
PALE = (0xD8, 0xD8, 0xE2, 255)
WHITE = (0xFF, 0xFF, 0xFF, 255)
DARK = (0x4D, 0x4D, 0x59, 255)
INK = (0x35, 0x35, 0x3D, 255)
CLEAR = (0, 0, 0, 0)


def new(w, h):
    return Image.new('RGBA', (w, h), CLEAR)


def save(im, name):
    im.save(os.path.join(OUT, name + '.png'))


def skyline(seed, color, min_h, max_h, detail):
    """480x192 silhouette: the sky stays transparent, everything below the
    roofline is a flat fill so it can be tinted by the renderer's alpha."""
    rnd = random.Random(seed)
    im = new(480, 192)
    d = ImageDraw.Draw(im)
    x = -rnd.randint(0, 10)
    while x < 480:
        w = rnd.randint(14, 44)
        h = rnd.randint(min_h, max_h)
        top = 192 - h
        d.rectangle([x, top, x + w - 1, 191], fill=color)
        # Setbacks, parapets and roof furniture make each roofline distinct.
        if rnd.random() < 0.5:
            sw = rnd.randint(6, max(6, w - 6))
            sx = x + rnd.randint(0, max(0, w - sw))
            d.rectangle([sx, top - rnd.randint(4, 14), sx + sw - 1, top], fill=color)
        if rnd.random() < 0.35:
            ax = x + rnd.randint(2, max(2, w - 3))
            d.rectangle([ax, top - rnd.randint(8, 26), ax, top], fill=color)
        if detail and rnd.random() < 0.25:
            # Water tank on stilts.
            tx = x + rnd.randint(1, max(1, w - 9))
            d.rectangle([tx + 1, top - 9, tx + 7, top - 3], fill=color)
            d.rectangle([tx, top - 10, tx + 8, top - 9], fill=color)
            d.rectangle([tx + 1, top - 3, tx + 1, top], fill=color)
            d.rectangle([tx + 7, top - 3, tx + 7, top], fill=color)
        if detail and rnd.random() < 0.15:
            # Smokestack pair.
            cx = x + rnd.randint(1, max(1, w - 6))
            d.rectangle([cx, top - rnd.randint(18, 30), cx + 1, top], fill=color)
            d.rectangle([cx + 4, top - rnd.randint(14, 26), cx + 5, top], fill=color)
        x += w + rnd.randint(0, 3)
    # One tower crane per layer: mast, jib, counter-jib and hook line.
    cx = rnd.randint(120, 360)
    base = 192 - rnd.randint(min_h, max_h)
    jib_y = base - 48
    d.rectangle([cx, jib_y, cx + 2, base], fill=color)
    d.rectangle([cx - 14, jib_y - 1, cx + 44, jib_y], fill=color)
    d.rectangle([cx - 14, jib_y - 4, cx - 8, jib_y - 1], fill=color)
    d.line([(cx + 1, jib_y - 8), (cx + 44, jib_y - 1)], fill=color)
    d.line([(cx + 1, jib_y - 8), (cx - 14, jib_y - 1)], fill=color)
    d.rectangle([cx + 1, jib_y - 9, cx + 1, jib_y - 1], fill=color)
    hx = cx + rnd.randint(20, 40)
    d.rectangle([hx, jib_y, hx, jib_y + 14], fill=color)
    d.rectangle([hx - 1, jib_y + 14, hx + 1, jib_y + 16], fill=color)
    # Fill any gaps left below the roofs.
    d.rectangle([0, 150, 479, 191], fill=color)
    return im


def wall(variant):
    """48x16: three 16x16 frames. Frame 0 plain panel, 1 brick, 2 riveted."""
    im = new(48, 16)
    d = ImageDraw.Draw(im)
    for f in range(3):
        ox = f * 16
        d.rectangle([ox, 0, ox + 15, 15], fill=LIGHT)
        if f == 0:
            d.rectangle([ox, 15, ox + 15, 15], fill=FAR)
            if variant == 2:
                d.rectangle([ox + 7, 0, ox + 7, 15], fill=FAR)
        elif f == 1:
            for row in range(0, 16, 4):
                d.rectangle([ox, row + 3, ox + 15, row + 3], fill=FAR)
                shift = 0 if (row // 4) % 2 == 0 else 4
                for col in range(-8 + shift, 16, 8):
                    bx = ox + col
                    if 0 <= col < 16:
                        d.rectangle([bx, row, bx, row + 2], fill=FAR)
            if variant == 2:
                d.rectangle([ox + 3, 5, ox + 5, 6], fill=MID)
        else:
            d.rectangle([ox, 0, ox + 15, 0], fill=PALE)
            d.rectangle([ox, 15, ox + 15, 15], fill=FAR)
            for (px, py) in [(2, 2), (13, 2), (2, 13), (13, 13)]:
                d.point((ox + px, py), fill=FAR)
                d.point((ox + px + 1, py + 1), fill=WHITE)
    return im


def window(variant):
    """64x16: four 16x16 frames on the wall colour; dark glass with a glint."""
    im = new(64, 16)
    d = ImageDraw.Draw(im)
    for f in range(4):
        ox = f * 16
        d.rectangle([ox, 0, ox + 15, 15], fill=LIGHT)
        if f == 0:
            d.rectangle([ox + 3, 2, ox + 12, 13], fill=INK)
            d.rectangle([ox + 4, 3, ox + 11, 12], fill=DARK)
            d.rectangle([ox + 5, 4, ox + 6, 5], fill=WHITE)
        elif f == 1:
            d.rectangle([ox + 3, 2, ox + 12, 13], fill=INK)
            d.rectangle([ox + 4, 3, ox + 11, 12], fill=DARK)
            d.rectangle([ox + 8, 3, ox + 8, 12], fill=INK)
            d.rectangle([ox + 4, 8, ox + 11, 8], fill=INK)
            d.point((ox + 5, 4), fill=WHITE)
        elif f == 2:
            d.rectangle([ox + 2, 1, ox + 13, 13], fill=INK)
            d.rectangle([ox + 3, 2, ox + 12, 12], fill=DARK)
            for row in range(3, 12, 2):
                d.rectangle([ox + 3, row, ox + 12, row], fill=INK)
            d.rectangle([ox + 2, 14, ox + 13, 14], fill=PALE)
        else:
            d.rectangle([ox + 4, 2, ox + 11, 13], fill=INK)
            d.rectangle([ox + 5, 3, ox + 10, 12], fill=DARK)
            d.rectangle([ox + 5, 3, ox + 6, 4], fill=WHITE)
            d.rectangle([ox + 3, 14, ox + 12, 14], fill=variant == 2 and PALE or FAR)
    return im


def roof():
    """48x16: three 16x16 cornice frames; frame 1 is the one drawn."""
    im = new(48, 16)
    d = ImageDraw.Draw(im)
    for f in range(3):
        ox = f * 16
        d.rectangle([ox, 0, ox + 15, 15], fill=LIGHT)
        d.rectangle([ox, 0, ox + 15, 1], fill=WHITE)
        d.rectangle([ox, 2, ox + 15, 2], fill=PALE)
        d.rectangle([ox, 5, ox + 15, 5], fill=DARK)
        d.rectangle([ox, 6, ox + 15, 7], fill=FAR)
        if f == 1:
            for px in range(2, 16, 5):
                d.rectangle([ox + px, 9, ox + px + 1, 12], fill=MID)
        elif f == 2:
            d.rectangle([ox + 4, 8, ox + 11, 9], fill=DARK)
    return im


def crane():
    """96x32: three 32x32 steel frames; frame 1 (X truss) sits under the blades."""
    im = new(96, 32)
    d = ImageDraw.Draw(im)
    for f in range(3):
        ox = f * 32
        d.rectangle([ox, 0, ox + 31, 3], fill=LIGHT)
        d.rectangle([ox, 0, ox + 31, 0], fill=WHITE)
        d.rectangle([ox, 3, ox + 31, 3], fill=DARK)
        d.rectangle([ox, 28, ox + 31, 31], fill=LIGHT)
        d.rectangle([ox, 28, ox + 31, 28], fill=WHITE)
        d.rectangle([ox, 31, ox + 31, 31], fill=DARK)
        if f == 0:
            d.rectangle([ox, 4, ox + 31, 27], fill=MID)
            d.rectangle([ox + 2, 6, ox + 29, 25], fill=FAR)
        elif f == 1:
            for k in range(-1, 2):
                d.line([(ox + 2, 4 + k), (ox + 29, 27 + k)], fill=LIGHT)
                d.line([(ox + 29, 4 + k), (ox + 2, 27 + k)], fill=LIGHT)
            d.line([(ox + 2, 3), (ox + 29, 26)], fill=WHITE)
            d.line([(ox + 29, 3), (ox + 2, 26)], fill=WHITE)
            d.line([(ox + 2, 5), (ox + 29, 28)], fill=DARK)
            d.line([(ox + 29, 5), (ox + 2, 28)], fill=DARK)
            d.rectangle([ox, 4, ox + 1, 27], fill=LIGHT)
            d.rectangle([ox + 30, 4, ox + 31, 27], fill=LIGHT)
        else:
            d.rectangle([ox + 14, 4, ox + 17, 27], fill=LIGHT)
            d.rectangle([ox + 15, 4, ox + 15, 27], fill=WHITE)
            d.rectangle([ox + 17, 4, ox + 17, 27], fill=DARK)
        for px in (3, 28):
            for py in (1, 29):
                d.point((ox + px, py), fill=DARK)
    return im


def airship():
    """192x32 silhouette: a patrol blimp with a gondola and tail fins."""
    im = new(192, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([20, 4, 172, 24], fill=FAR)
    d.polygon([(150, 6), (182, 2), (176, 14), (150, 14)], fill=FAR)
    d.polygon([(150, 22), (182, 26), (176, 14), (150, 14)], fill=FAR)
    d.rectangle([70, 24, 110, 29], fill=FAR)
    d.rectangle([74, 29, 106, 30], fill=FAR)
    d.rectangle([84, 22, 96, 24], fill=FAR)
    for x in range(72, 110, 6):
        d.point((x, 27), fill=CLEAR)
    d.rectangle([2, 12, 20, 15], fill=FAR)
    return im


def ac_unit():
    """16x16 silhouette of a wall air conditioner with a fan grille."""
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 3, 15, 13], fill=DARK)
    d.ellipse([3, 4, 12, 12], fill=CLEAR)
    d.ellipse([5, 6, 10, 10], fill=DARK)
    d.rectangle([7, 4, 8, 12], fill=DARK)
    d.rectangle([3, 7, 12, 8], fill=DARK)
    d.rectangle([1, 14, 2, 15], fill=DARK)
    d.rectangle([13, 14, 14, 15], fill=DARK)
    return im


def fire_escape():
    """32x32 silhouette: landing with railing and a diagonal stair."""
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 14, 31, 15], fill=DARK)
    for x in range(0, 32, 4):
        d.rectangle([x, 6, x, 14], fill=DARK)
    d.rectangle([0, 6, 31, 6], fill=DARK)
    d.rectangle([0, 15, 0, 31], fill=DARK)
    d.rectangle([31, 15, 31, 31], fill=DARK)
    for i in range(8):
        x = 4 + i * 3
        d.rectangle([x, 16 + i * 2, x + 3, 16 + i * 2], fill=DARK)
    d.line([(4, 12), (28, 30)], fill=DARK)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    save(skyline(11, FAR, 60, 110, False), 'background')
    save(skyline(23, MID, 70, 125, True), 'midground1')
    save(skyline(37, MID, 55, 115, True), 'midground2')
    save(wall(1), 'wall1')
    save(wall(2), 'wall2')
    save(window(1), 'window1')
    save(window(2), 'window2')
    save(roof(), 'roof1')
    save(crane(), 'crane1')
    save(airship(), 'mothership')
    save(ac_unit(), 'ac')
    save(fire_escape(), 'escape')


if __name__ == '__main__':
    main()
