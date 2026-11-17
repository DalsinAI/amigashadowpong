#!/usr/bin/env python3
"""amiga/data against upstream's ext/ BMPs: the same size and, pixel for
pixel, the same colour; 8-bit paletted, black at 0 and white at 1.

    python3 tests/host/check_pictures.py UPSTREAM amiga/data

Copyright (c) 2026 AmiCradle Team. BSD-2-Clause.
"""
import os
import sys

from PIL import Image


def main():
    up, data = sys.argv[1], sys.argv[2]
    for n in ("background", "ball", "paddle"):
        a = Image.open(os.path.join(up, "ext", n + ".bmp")).convert("RGB")
        b = Image.open(os.path.join(data, n + ".png"))
        if b.mode != "P":
            raise SystemExit("FAIL: %s.png is %s, not paletted" % (n, b.mode))
        if b.getpalette()[:6] != [0, 0, 0, 255, 255, 255]:
            raise SystemExit("FAIL: %s.png: palette does not start black, white" % n)
        if a.size != b.size:
            raise SystemExit("FAIL: %s.png is %r, upstream %r" % (n, b.size, a.size))
        if a.tobytes() != b.convert("RGB").tobytes():
            raise SystemExit("FAIL: %s.png differs from upstream's pixels" % n)
    print("ok: amiga/data has upstream's three pictures, pixel for pixel, in 2 colours")


if __name__ == "__main__":
    main()
