#!/usr/bin/env python3
"""Shadow Pong's three BMPs (ext/) as the Amiga port's PNGs.

    python3 tools/shadowpong8.py UPSTREAM OUT

UPSTREAM is the unpacked shadowpong-1.6 (its ShadowPong drawer); OUT gets
data/background.png, data/ball.png and data/paddle.png. Upstream's pictures
are black and white only, so each PNG is 8-bit paletted with the same two
colours (0 black, 1 white): the screen palette the game sets on the Amiga.
Any other colour stops the conversion. The same input makes the same bytes.

Copyright (c) 2026 AmiCradle Team. BSD-2-Clause.
"""
import os
import sys

from PIL import Image

PALETTE = [(0, 0, 0), (255, 255, 255)]
NAMES = ("background", "ball", "paddle")


def convert(src, dst):
    rgb = Image.open(src).convert("RGB")
    index = {c: i for i, c in enumerate(PALETTE)}
    out = Image.new("P", rgb.size)
    flat = []
    for c in PALETTE:
        flat.extend(c)
    out.putpalette(flat + [0] * (768 - len(flat)))
    pixels = []
    raw = rgb.tobytes()
    for k in range(0, len(raw), 3):
        c = (raw[k], raw[k + 1], raw[k + 2])
        if c not in index:
            raise SystemExit("%s: colour %r is not black or white" % (src, c))
        pixels.append(index[c])
    out.putdata(pixels)
    out.save(dst, optimize=False, bits=8)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    src, out = sys.argv[1], os.path.join(sys.argv[2], "data")
    os.makedirs(out, exist_ok=True)
    for n in NAMES:
        convert(os.path.join(src, "ext", n + ".bmp"), os.path.join(out, n + ".png"))
        print("data/%s.png" % n)


if __name__ == "__main__":
    main()
