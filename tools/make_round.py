"""Draw VoltUI's rounded-corner textures into VoltUI/Media (since VoltUI 1.66.0, the Obsidian look).

VoltUI draws a rounded box from pieces: four corners from these textures, and solid
flat-colour strips and 1px lines for everything straight, so the straight edges stay crisp at
any interface scale. The textures:
  CornerR.tga      a filled quarter circle, for a box with corners R units across
  CornerRingR.tga  the same corner's 1-unit outline, for its border
  DiscN.tga        a filled circle, for a dot or knob N units across

Each is drawn for the size it's shown at: a 32x32 texture stands for R (or N) units, and its
edge is softened over about 0.7 units, about one screen pixel, so it looks smooth whether the
game shows it a little bigger or smaller. The corner is the top-left one (the circle's centre
at the texture's bottom-right); the game flips it for the other three with SetTexCoord.
White, so the game tints them with SetVertexColor. 32-bit, uncompressed, bottom-left origin:
the plainest TGA the game reads.
Run from the repo root: python tools/make_round.py   (no packages needed)
"""
import glob
import math
import os
import struct

RADII = (2, 3, 4, 5, 6, 7, 8, 11, 12)
DISCS = (5, 6, 10, 12)
SIZE = 32
SOFT = 0.7  # units the edge is softened over
SS = 4      # samples per texel, each way
OUT = os.path.join(os.path.dirname(__file__), "..", "VoltUI", "Media")


def clamp(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def draw(alpha_at):
    """Rows top to bottom of alphas 0-255, alpha_at(x, y) in texels, averaged over samples."""
    rows = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            total = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    total += alpha_at(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
            row.append(round(255 * total / (SS * SS)))
        rows.append(row)
    return rows


def corner(units, ring):
    unit = SIZE / units          # texels per unit
    band = SOFT * unit           # the soft edge, in texels
    outer = SIZE

    def at(x, y):
        d = math.hypot(SIZE - x, SIZE - y)
        a = clamp((outer - d) / band + 0.5)
        if ring:
            a *= clamp((d - (outer - unit)) / band + 0.5)
        return a
    return draw(at)


def disc(units):
    band = SOFT * SIZE / units
    c = SIZE / 2
    return draw(lambda x, y: clamp((c - math.hypot(x - c, y - c)) / band + 0.5))


def write_tga(path, rows):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    body = bytearray()
    for row in reversed(rows):  # bottom-left origin
        for a in row:
            body += bytes((255, 255, 255, a))
    with open(path, "wb") as f:
        f.write(header + body)


def main():
    os.makedirs(OUT, exist_ok=True)
    # the first version's nine-sliced textures, which blurred at most interface scales
    for old in glob.glob(os.path.join(OUT, "Round*.tga")) + glob.glob(os.path.join(OUT, "Ring*.tga")) \
            + glob.glob(os.path.join(OUT, "Circle.tga")):
        os.remove(old)
    n = 0
    for r in RADII:
        write_tga(os.path.join(OUT, f"Corner{r}.tga"), corner(r, False))
        write_tga(os.path.join(OUT, f"CornerRing{r}.tga"), corner(r, True))
        n += 2
    for d in DISCS:
        write_tga(os.path.join(OUT, f"Disc{d}.tga"), disc(d))
        n += 1
    print("wrote", n, "textures to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
