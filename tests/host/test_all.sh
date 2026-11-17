#!/bin/sh
# Host tests (Linux, gcc/g++, zlib's headers, Pillow):
#  1. upstream's tarball matches the lock's sha256; amiga/patches apply;
#  2. amiga/data: check_pictures.py (upstream's pixels exactly, black and
#     white), and tools/shadowpong8.py makes the same files again, byte for
#     byte;
#  3. the game built with the host's compiler on acsdl12 and ACGame at the
#     locked commits (all of acsdl12's own code, as on the Amiga) with
#     tests/host/acgame_host.c for ACGame's screen and keyboard, and played
#     from a script: the game starts on a 640 x 480 screen in black and
#     white, the ball and the paddles move, the player's paddle answers the
#     cursor keys, and Right Amiga + Q ends it.
# ACSDL (a gameports/acsdl12) and ACGAME (DalsinAI/acgame) override the
# fetches. Frames: $T/shot-*.ppm.
# Copyright (c) 2026 AmiCradle Team. BSD-2-Clause.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
. "$ROOT/package/shadowpong.lock"
T=${WORK:-"${TMPDIR:-/tmp}/amigashadowpong-test"}
mkdir -p "$T"
T=$(CDPATH= cd -- "$T" && pwd)
cd "$ROOT"
ok() { echo "ok: $*"; }
fetch() {   # fetch DIR URL COMMIT
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "$1"; mkdir -p "$1"
        git -C "$1" init -q
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
    fi
    git -C "$1" checkout -q -- . && git -C "$1" clean -qfdx
}

# 1. upstream + patches
TAR="$T/shadowpong-$SHADOWPONG_VERSION.tar.bz2"
[ "$(sha256sum "$TAR" 2>/dev/null | cut -d' ' -f1)" = "$SHADOWPONG_SHA256" ] ||
    curl -fsSL --retry 3 -o "$TAR" "$SHADOWPONG_URL"
[ "$(sha256sum "$TAR" | cut -d' ' -f1)" = "$SHADOWPONG_SHA256" ] || { echo "FAIL: upstream tarball sha256"; exit 1; }
rm -rf "$T/up"; mkdir -p "$T/up"; tar xjf "$TAR" -C "$T/up"
UP="$T/up/ShadowPong"
rm -rf "$T/orig"; cp -r "$UP" "$T/orig"
for p in amiga/patches/*.patch; do patch -s -p1 -d "$UP" < "$p"; done
ok "upstream tarball checks out; patches apply"

# 2. the pictures
python3 tests/host/check_pictures.py "$T/orig" amiga/data
rm -rf "$T/data8"; python3 tools/shadowpong8.py "$T/orig" "$T/data8" > /dev/null
diff -r amiga/data "$T/data8/data" > /dev/null || { echo "FAIL: tools/shadowpong8.py makes other pictures than amiga/data"; exit 1; }
ok "tools/shadowpong8.py makes amiga/data again, byte for byte"

# 3. built on acsdl12 and played
if [ -z "${ACSDL:-}" ]; then
    G="$T/guest"
    if [ "$(git -C "$G" rev-parse HEAD 2>/dev/null)" != "$GUEST_REF" ]; then
        rm -rf "$G"; git init -q "$G"
        git -C "$G" sparse-checkout set gameports/acsdl12
        git -C "$G" fetch -q --depth 1 --filter=blob:none https://github.com/DalsinAI/amicradle-guest "$GUEST_REF"
        git -C "$G" checkout -q FETCH_HEAD
    fi
    ACSDL="$G/gameports/acsdl12"
fi
if [ -z "${ACGAME:-}" ]; then
    fetch "$T/acgame" https://github.com/DalsinAI/acgame "$ACGAME_REF"
    ACGAME="$T/acgame"
fi
B="$T/build"; rm -rf "$B"; mkdir -p "$B"
g++ -std=gnu++98 -O1 -Wall -Wno-write-strings -Wno-unused-variable -Wno-misleading-indentation -Werror -D__amigaos__ -DSPDATA=\"Data/\" \
    -I"$ACSDL/include" -I"$ACSDL/include/SDL" -I"$ACGAME/include" -c "$UP/game.cpp" -o "$B/game.o"
for f in "$ACSDL"/src/*.c; do
    gcc -std=gnu99 -O1 -w -I"$ACSDL/include/SDL" -I"$ACSDL/src" -I"$ACGAME/include" -c "$f" -o "$B/acsdl_$(basename "$f" .c).o"
done
gcc -O1 -Wall -Wextra -Werror -I"$ACGAME/include" -c tests/host/acgame_host.c -o "$B/acgame_host.o"
g++ -o "$B/shadowpong" "$B"/*.o -lz -lpthread -lm
ok "game builds on the host (-Wall -Werror) on acsdl12 $GUEST_REF and ACGame $ACGAME_REF"

rm -rf "$T/play"; mkdir -p "$T/play/Data"; cp amiga/data/*.png "$T/play/Data/"
cat > "$T/play.txt" <<EOS
600 shot $T/shot-0.ppm
1400 shot $T/shot-1.ppm
1500 down 4c
2600 up 4c
2700 shot $T/shot-up.ppm
2800 down 4d
4400 up 4d
4500 shot $T/shot-down.ppm
5000 quit
EOS
(cd "$T/play" && ACG_SCRIPT="$T/play.txt" ACG_LOG="$T/play.frames" timeout -s KILL 30 "$B/shadowpong") > "$T/play.out" 2>&1 ||
    { echo "FAIL: the game did not end on Right Amiga + Q"; tail "$T/play.out"; exit 1; }
for s in 0 1 up down; do
    [ "$(head -c 15 "$T/shot-$s.ppm" | tr '\n' ' ')" = "P6 640 480 255 " ] || { echo "FAIL: no 640 x 480 frame $s"; exit 1; }
done
python3 - "$T" <<'EOP'
import sys
t = sys.argv[1]
def load(n):
    d = open("%s/shot-%s.ppm" % (t, n), "rb").read()
    return d[len(b"P6 640 480 255\n"):]
def colours(px):
    return {px[i:i + 3] for i in range(0, len(px), 3)}
def paddle_y(px):
    # the player's paddle: the white run in column 630 (x = 640 - 10 - 1 .. 638)
    rows = [y for y in range(480) if px[(y * 640 + 634) * 3] == 255]
    return (min(rows) + max(rows)) // 2 if rows else None
s0, s1, su, sd = (load(n) for n in ("0", "1", "up", "down"))
c = colours(s0) | colours(s1) | colours(su) | colours(sd)
assert c <= {b"\0\0\0", b"\xff\xff\xff"}, "colours other than black and white: %r" % c
assert s0 != s1, "nothing moved"
y1, yu, yd = paddle_y(s1), paddle_y(su), paddle_y(sd)
assert None not in (y1, yu, yd), "no player paddle at the right"
assert yu < y1 - 50, "cursor up did not move the paddle up (%d -> %d)" % (y1, yu)
assert yd > yu + 50, "cursor down did not move the paddle down (%d -> %d)" % (yu, yd)
print("ok: played: black and white, the ball moves, paddle %d -> %d (up) -> %d (down)" % (y1, yu, yd))
EOP
ok "$(wc -l < "$T/play.frames") frames, ended on Right Amiga + Q"
echo "all host tests passed"
