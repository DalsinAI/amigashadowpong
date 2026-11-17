# Shadow Pong for GFOS and AmigaOS 3.x

The AmiCradle port of Shadow Pong 1.6, a small black and white Pong against
the computer, by Matthew Little (BSD licence). It runs on ACGame through
acsdl12, our SDL 1.2: a 640 x 480 screen on AGA or RTG, on a 68040 with an
FPU.

Upstream is never kept here: `package/build-amiga.sh` fetches the release
tarball `package/shadowpong.lock` names, checks its sha256 and applies
`amiga/patches`.

| Path | What |
| --- | --- |
| `amiga/patches/` | the patch to upstream: an 8-bit black and white screen, the pictures as PNGs from the drawer, solid paddles on 8 bits |
| `amiga/data/` | upstream's three pictures, pixel for pixel, made by `tools/shadowpong8.py` |
| `amiga/amiga_start.c` | stack and `$VER` |
| `amiga/Makefile.amigaos` | the build on the os32-gcc16-open6 stove |
| `amiga/icons/`, `amiga/Install-ShadowPong` | GlowIcons and the Installer script (amicradle `scripts/ports`) |
| `package/build-amiga.sh` | Cradle's `stove_build` (target `package`): the LHA archive and the GFOpenUp part `Parts/ShadowPong` |
| `tests/host/test_all.sh` | host tests: tarball checksum, patches, pictures, and the game built on acsdl12 and played from a script |

Player notes: [AMIGA_PORT.md](AMIGA_PORT.md). Licences:
[amiga/Licences.txt](amiga/Licences.txt).

Designed, tested and delivered by The AmiCradle Team.
