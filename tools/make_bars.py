"""Draw VoltUI's status bar textures into VoltUI/Media.

Each is light grey on white so the game tints it with SetVertexColor / SetStatusBarColor,
the same as the flat white VoltUI used before. All are 256x32, 32-bit, uncompressed TGA with a
bottom-left origin: the plainest TGA the game reads. They're fully opaque, so a bar never
shows the track through its own fill.

  BarSmooth.tga    a soft fall from light at the top to a little darker at the bottom
  BarGloss.tga     a bright band over the top half, a step, then a darker lower half
  BarSoft.tga      lightest through the middle, shaded towards both edges, like a tube
  BarMatte.tga     an even fill with a faint grain and a hairline shadow underneath
  BarStripes.tga   faint diagonal stripes over a soft fall
  BarGlass.tga     a thin shine along the top, a clear middle, a deeper bottom edge
  BarObsidian.tga  VoltUI's own look: a quiet fall with a one-pixel lit edge at the top

Run from the repo root: python tools/make_bars.py   (needs Pillow)
Pass --preview to also write a picture of every texture, tinted, beside this script's
output folder's parent (not committed).
"""
import math
import os
import random
import struct
import sys

from PIL import Image, ImageDraw

W, H = 256, 32
OUT = os.path.join(os.path.dirname(__file__), "..", "VoltUI", "Media")


def save_tga(path, rows):
    """rows: H lists of W grey values 0-1, top row first."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 8)
    data = bytearray()
    for y in range(H - 1, -1, -1):          # bottom-left origin
        for v in rows[y]:
            g = max(0, min(255, int(round(v * 255))))
            data += bytes((g, g, g, 255))   # BGRA
    with open(path, "wb") as f:
        f.write(header + bytes(data))


def column(fn):
    """A texture whose shade only changes from top to bottom: fn(t) for t 0 (top) to 1."""
    return [[fn(y / (H - 1))] * W for y in range(H)]


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    return lerp(1.0, 0.74, t ** 1.2)


def gloss(t):
    if t < 0.48:
        return lerp(1.0, 0.9, t / 0.48)
    return lerp(0.74, 0.8, (t - 0.48) / 0.52)


def soft(t):
    d = abs(t - 0.42) / 0.58                 # the light falls a little above the middle
    return lerp(0.98, 0.68, d ** 1.6)


def matte():
    rnd = random.Random(7)
    rows = []
    for y in range(H):
        t = y / (H - 1)
        base = lerp(0.9, 0.84, t)
        if y == H - 1:
            base = 0.7
        rows.append([base + (rnd.random() - 0.5) * 0.05 for _ in range(W)])
    return rows


def stripes():
    rows = []
    period = 8
    for y in range(H):
        t = y / (H - 1)
        base = smooth(t)
        row = []
        for x in range(W):
            # Diagonal stripes; W is a multiple of the period so the texture tiles cleanly.
            p = ((x + y) % period) / period
            band = 0.5 + 0.5 * math.cos(p * 2 * math.pi)
            row.append(base * (0.88 + 0.12 * band))
        rows.append(row)
    return rows


def glass(t):
    y = t * (H - 1)
    if y < 1.5:
        return 1.0
    if y < 4:
        return lerp(0.97, 0.86, (y - 1.5) / 2.5)
    if y > H - 3:
        return 0.6
    return lerp(0.86, 0.72, (y - 4) / (H - 7))


def obsidian(t):
    y = t * (H - 1)
    if y < 1:
        return 1.0
    return lerp(0.9, 0.7, ((y - 1) / (H - 2)) ** 0.9)


TEXTURES = [
    ("BarSmooth.tga", column(smooth)),
    ("BarGloss.tga", column(gloss)),
    ("BarSoft.tga", column(soft)),
    ("BarMatte.tga", matte()),
    ("BarStripes.tga", stripes()),
    ("BarGlass.tga", column(glass)),
    ("BarObsidian.tga", column(obsidian)),
]


def preview(path):
    """Every texture tinted like VoltUI's bars, at a few sizes, on VoltUI's panel colour."""
    colours = [(0.2, 0.8, 0.3), (0.9, 0.25, 0.2), (0.35, 0.55, 1.0), (0.78, 0.61, 0.43)]
    rowh, gap, label = 22, 10, 120
    img = Image.new("RGB", (label + 4 * (200 + gap) + gap, gap + len(TEXTURES) * (rowh + gap) + 20), (15, 15, 15))
    d = ImageDraw.Draw(img)
    for i, (name, rows) in enumerate(TEXTURES):
        y0 = gap + i * (rowh + gap)
        d.text((gap, y0 + 5), name[3:-4], fill=(220, 220, 220))
        tex = Image.new("L", (W, H))
        tex.putdata([int(v * 255) for r in rows for v in r])
        tex = tex.resize((200, rowh), Image.BILINEAR)
        for c, (r, g, b) in enumerate(colours):
            x0 = label + c * (200 + gap)
            fill = int(200 * (0.95 - c * 0.2))
            tinted = Image.merge("RGB", [tex.point(lambda v, k=k: int(v * k)) for k in (r, g, b)])
            d.rectangle((x0 - 1, y0 - 1, x0 + 200, y0 + rowh), fill=(30, 30, 30))
            img.paste(tinted.crop((0, 0, fill, rowh)), (x0, y0))
    img.save(path)


def main():
    for name, rows in TEXTURES:
        save_tga(os.path.join(OUT, name), rows)
    if "--preview" in sys.argv:
        at = sys.argv[sys.argv.index("--preview") + 1]
        preview(at)


if __name__ == "__main__":
    main()
