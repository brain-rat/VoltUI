"""Draw VoltUI's bolt logo into VoltUI/Media (since VoltUI 1.105.0, the add-on's mark).

Bolt.tga is the lightning bolt from the project page's brand mark (docs/index.html: the path
"M8 0 0 9.2h5.2L4 16l9-9.6H7.6z" on a 13x16 box), filling the height of a 32x32 texture with a
texel to spare top and bottom, centred across. It is white with the bolt in its alpha, so VoltUI
tints it with SetVertexColor: dark on the gold minimap button, gold in the title strips. Edges
are smoothed by sampling each texel 8x8 times.
32-bit, uncompressed, bottom-left origin: the plainest TGA the game reads.
Run from the repo root: python tools/make_bolt.py   (no packages needed)
"""
import os
import struct

SIZE = 32
SS = 8  # samples per texel, each way
OUT = os.path.join(os.path.dirname(__file__), "..", "VoltUI", "Media")

# The page's bolt, on its 13x16 box.
BOLT = [(8, 0), (0, 9.2), (5.2, 9.2), (4, 16), (13, 6.4), (7.6, 6.4)]
BOX_W, BOX_H = 13, 16
MARGIN = 1  # texels above and below

SCALE = (SIZE - 2 * MARGIN) / BOX_H
LEFT = (SIZE - BOX_W * SCALE) / 2
POLY = [(LEFT + x * SCALE, MARGIN + y * SCALE) for x, y in BOLT]


def inside(px, py):
    """Even-odd rule: is the point inside the bolt?"""
    hit = False
    n = len(POLY)
    for i in range(n):
        x1, y1 = POLY[i]
        x2, y2 = POLY[(i + 1) % n]
        if (y1 > py) != (y2 > py):
            if px < x1 + (py - y1) * (x2 - x1) / (y2 - y1):
                hit = not hit
    return hit


def rows():
    out = []
    for ty in range(SIZE):
        row = []
        for tx in range(SIZE):
            n = 0
            for sy in range(SS):
                for sx in range(SS):
                    if inside(tx + (sx + 0.5) / SS, ty + (sy + 0.5) / SS):
                        n += 1
            row.append(round(255 * n / (SS * SS)))
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
    path = os.path.join(OUT, "Bolt.tga")
    data = rows()
    write_tga(path, data)
    print("wrote", os.path.normpath(path))
    for row in data:  # a quick look
        print("".join(" .:-=+*#%@"[min(9, a * 10 // 256)] for a in row))


if __name__ == "__main__":
    main()
