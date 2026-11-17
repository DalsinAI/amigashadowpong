#!/bin/sh
# The release archive and the GFOpenUp part, for Cradle's stove_build
# (target package):
#  1. upstream Shadow Pong 1.6, the tarball package/shadowpong.lock names,
#     checked against its sha256 (it is never kept in this repository), with
#     amiga/patches applied;
#  2. what it is built on, at the commits the lock names: acgame.library
#     and its stubs (DalsinAI/acgame), and acsdl12 (amicradle-guest
#     gameports/acsdl12, SDL 1.2 on ACGame) on zlib 1.3.1's inflate, built
#     without its own copy of ACGame;
#  3. the game built by amiga/Makefile.amigaos;
#  4. the drawer, its icon and the Installer script beside it packed as
#     ShadowPong-VERSION-68040.lha (tools/pack_dist.py), with its .sha256 and a
#     short .readme;
#  5. OUT/Parts/ShadowPong, a GFOpenUp part: its Part file and the drawer's
#     files for SYS:Games/ShadowPong, installed with
#       GFOpenUpTool INSTALL Parts/ShadowPong
#     The drawer carries its own acgame.library (Libs/), so the part needs
#     nothing but a 68040.
# Nothing is published from here.
# Copyright (c) 2026 AmiCradle Team. BSD-2-Clause.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
. "$HERE/package.env"
. "$HERE/shadowpong.lock"
OUT=${OUT:-"$ROOT/build-amiga-package"}
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
STOVE=${STOVE:-"$HOME/AmiCradle/kitchen/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK=${WORK:-"$HOME/.cache/amigashadowpong"}
mkdir -p "$WORK"
cd "$ROOT"
if [ -x "$STOVE/prefix/bin/m68k-amigaos-gcc" ]; then PREFIX="$STOVE/prefix"; else PREFIX="$STOVE"; fi

fetch() {   # fetch DIR URL COMMIT: DIR at COMMIT, clean
    if [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]; then
        rm -rf "$1"; mkdir -p "$1"
        git -C "$1" init -q
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
    fi
    git -C "$1" checkout -q -- . && git -C "$1" clean -qfdx
}

# 1. upstream's tarball, checked, unpacked and patched afresh every time
TAR="$WORK/shadowpong-$SHADOWPONG_VERSION.tar.bz2"
if [ "$(sha256sum "$TAR" 2>/dev/null | cut -d' ' -f1)" != "$SHADOWPONG_SHA256" ]; then
    curl -fsSL --retry 3 -o "$TAR" "$SHADOWPONG_URL"
    [ "$(sha256sum "$TAR" | cut -d' ' -f1)" = "$SHADOWPONG_SHA256" ] ||
        { echo "upstream tarball: wrong sha256"; exit 1; }
fi
rm -rf "$WORK/up"; mkdir -p "$WORK/up"
tar xjf "$TAR" -C "$WORK/up"
SRC="$WORK/up/ShadowPong"
for p in "$ROOT"/amiga/patches/*.patch; do
    patch -s -p1 -d "$SRC" < "$p"
done

# 2. acgame.library and acsdl12
fetch "$WORK/acgame" https://github.com/DalsinAI/acgame "$ACGAME_REF"
ACGAMELIB="$WORK/acgame-out"
rm -rf "$ACGAMELIB"
CC="$PREFIX/bin/m68k-amigaos-gcc" AR="$PREFIX/bin/m68k-amigaos-ar" NM="$PREFIX/bin/m68k-amigaos-nm" \
    STOVE="$STOVE" OUT="$ACGAMELIB" sh "$WORK/acgame/build-amiga.sh" > "$OUT/acgame-output.txt" 2>&1 ||
    { tail -n 60 "$OUT/acgame-output.txt"; exit 1; }
GUEST="$WORK/guest"
if [ "$(git -C "$GUEST" rev-parse HEAD 2>/dev/null)" != "$GUEST_REF" ]; then
    rm -rf "$GUEST"; git init -q "$GUEST"
    git -C "$GUEST" sparse-checkout set gameports/acsdl12
    git -C "$GUEST" fetch -q --depth 1 --filter=blob:none https://github.com/DalsinAI/amicradle-guest "$GUEST_REF"
    git -C "$GUEST" checkout -q FETCH_HEAD
fi
fetch "$WORK/zlib" https://github.com/madler/zlib "$ZLIB_REF"
if [ -z "${NDK:-}" ]; then
    [ -d "$WORK/gfopensdk/.git" ] || git clone -q --depth 1 https://github.com/DalsinAI/gfopensdk "$WORK/gfopensdk"
    NDK="$WORK/gfopensdk/OpenNDK/Include_H"
fi
ACSDL="$GUEST/gameports/acsdl12"
ACSDLLIB="$WORK/acsdl12-out"
rm -rf "$ACSDLLIB"
# ACG= leaves ACGame's own sources out of libacsdl12.a: the game gets ACGame
# from acgame.library, through the stubs in libacgame.a.
make -C "$ACSDL" -f Makefile.amigaos STOVE="$PREFIX" NDK="$NDK" ACGAME="$WORK/acgame" ZLIB="$WORK/zlib" \
    ACG= BUILD="$ACSDLLIB" -j4 > "$OUT/acsdl12-output.txt" 2>&1 ||
    { tail -n 60 "$OUT/acsdl12-output.txt"; exit 1; }

# 3. the game
rm -rf "$DIST"
make -f amiga/Makefile.amigaos SHADOWPONG="$SRC" STOVE="$STOVE" PREFIX="$PREFIX" \
    ACSDL="$ACSDL" ACSDLLIB="$ACSDLLIB" ACGAME="$WORK/acgame" ACGAMELIB="$ACGAMELIB" \
    -j4 $TARGET > "$OUT/build-output.txt" 2>&1 || { tail -n 60 "$OUT/build-output.txt"; exit 1; }

# 4. the archive
python3 "$ROOT/tools/pack_dist.py" --dist "$DIST" --name "$NAME" --out "$OUT"

# 5. the GFOpenUp part
sh "$ROOT/package/write-part.sh" "$DIST/$NAME" "$OUT/Parts/$NAME" "$NAME" "$PORT_VERSION" \
    "Shadow Pong: Pong against the computer, in black and white"
echo "part: $(grep -c '^copy' "$OUT/Parts/$NAME/Part") files, $(du -sk "$OUT/Parts/$NAME" | cut -f1) KB"
ls -l "$DIST/$NAME/$NAME"
