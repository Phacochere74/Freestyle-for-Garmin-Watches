#!/usr/bin/env python3
"""Genere resources/drawables/launcher_icon.png sans dependance externe.

L'icone est rendue en 4x puis reduite (anti-aliasing par moyenne) : un cercle
sombre, une courbe de glycemie montante et un point de mesure en evidence.
Relancer ce script apres toute modification du dessin.
"""
import math
import struct
import zlib
from pathlib import Path

SIZE = 60          # taille finale en pixels
SS = 4             # facteur de suréchantillonnage
W = SIZE * SS

BG = (18, 26, 38)          # fond du cercle
LINE = (86, 200, 138)      # courbe, vert
DOT = (255, 176, 46)       # dernier point, ambre
RING = (52, 74, 96)        # liseré


def blank():
    return [[(0, 0, 0, 0)] * W for _ in range(W)]


def put(buf, x, y, rgb, alpha=255):
    if 0 <= x < W and 0 <= y < W:
        buf[y][x] = (rgb[0], rgb[1], rgb[2], alpha)


def disc(buf, cx, cy, r, rgb):
    r2 = r * r
    for y in range(max(0, int(cy - r)), min(W, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r) + 1)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                put(buf, x, y, rgb)


def ring(buf, cx, cy, r, thickness, rgb):
    outer = r * r
    inner = (r - thickness) ** 2
    for y in range(max(0, int(cy - r)), min(W, int(cy + r) + 1)):
        for x in range(max(0, int(cx - r)), min(W, int(cx + r) + 1)):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if inner <= d <= outer:
                put(buf, x, y, rgb)


def thick_line(buf, x0, y0, x1, y1, width, rgb):
    steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(steps + 1):
        t = i / steps
        disc(buf, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2.0, rgb)


def downsample(buf):
    out = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            r = g = b = a = 0
            for dy in range(SS):
                for dx in range(SS):
                    pr, pg, pb, pa = buf[y * SS + dy][x * SS + dx]
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            if a == 0:
                row.append((0, 0, 0, 0))
            else:
                n = SS * SS
                row.append((r // a, g // a, b // a, a // n))
        out.append(row)
    return out


def write_png(path, pixels):
    raw = bytearray()
    for row in pixels:
        raw.append(0)  # filtre "None"
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    Path(path).write_bytes(png)


def main():
    buf = blank()
    c = W / 2.0
    disc(buf, c, c, c - SS, BG)
    ring(buf, c, c, c - SS, 1.5 * SS, RING)

    # Courbe de glycemie : quatre segments montants puis un palier.
    points = [(0.20, 0.68), (0.36, 0.74), (0.52, 0.52), (0.68, 0.40), (0.82, 0.34)]
    scaled = [(px * W, py * W) for px, py in points]
    for i in range(len(scaled) - 1):
        thick_line(buf, scaled[i][0], scaled[i][1],
                   scaled[i + 1][0], scaled[i + 1][1], 3.4 * SS, LINE)

    # Dernier point mis en avant.
    disc(buf, scaled[-1][0], scaled[-1][1], 4.6 * SS, BG)
    disc(buf, scaled[-1][0], scaled[-1][1], 3.4 * SS, DOT)

    write_png("resources/drawables/launcher_icon.png", downsample(buf))
    print("resources/drawables/launcher_icon.png ecrit ({}x{})".format(SIZE, SIZE))


if __name__ == "__main__":
    main()
