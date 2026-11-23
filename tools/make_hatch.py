"""Draw VoltUI's hatch texture into VoltUI/Media (since VoltUI 1.81.0, the hard-edged look).

Hatch.tga is a 16x16 tile of diagonal lines, two texels wide and eight apart, running up to the
right. VoltUI tiles it along the strip on each settings card's heading (S.Hatch in Style.lua) and
tints it with SetVertexColor, so it is white with the lines in its alpha. The lines wrap at the
tile's edges, so the pattern has no seam. Its edges are softened over one texel, so it stays
even when the game draws it a little larger or smaller than one texel to a pixel.
32-bit, uncompressed, bottom-left origin: the plainest TGA the game reads.
Run from the repo root: python tools/make_hatch.py   (no packages needed)
"""
import os
import struct

SIZE = 16
PERIOD = 8   # texels from one line to the next, across
WIDTH = 2    # texels of line
SS = 4       # samples per texel, each way
OUT = os.path.join(os.path.dirname(__file__), "..", "VoltUI", "Media")


def alpha_at(x, y):
    """1 on a line, 0 off it. Lines are where (x + y) mod PERIOD is under WIDTH."""
    return 1.0 if (x + y) % PERIOD < WIDTH else 0.0


def rows():
    out = []
    for py in range(SIZE):
        row = []
        for px in range(SIZE):
            total = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    total += alpha_at(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
            row.append(round(255 * total / (SS * SS)))
        out.append(row)
    return out


def write_tga(path, data):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    body = bytearray()
    for row in reversed(data):  # bottom-left origin
        for a in row:
            body += bytes((255, 255, 255, a))
    with open(path, "wb") as f:
        f.write(header + body)


def main():
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "Hatch.tga")
    write_tga(path, rows())
    print("wrote", os.path.normpath(path))


if __name__ == "__main__":
    main()
