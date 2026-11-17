/* The Amiga port's start: the stack and the version string. Shadow Pong
 * keeps nothing of its own on disk.
 * Copyright (c) 2026 AmiCradle Team. BSD-2-Clause. */

/* A Shell gives 4 KB of stack; the game and acsdl12 want more. libnix's
 * startup sets this much up. */
unsigned long __stack = 64 * 1024;
static const char version[] __attribute__((used)) =
    "$VER: ShadowPong 1.6 (17.11.2026)";
