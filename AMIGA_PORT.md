Shadow Pong 1.6 for GFOS and AmigaOS 3.x
========================================

Shadow Pong is a small Pong in black and white by Matthew Little (2006):
your paddle on the right against the computer's on the left.

This port runs it on ACGame, the AmiCradle game layer, through acsdl12
(SDL 1.2 on ACGame): a 640 x 480 screen in two colours, AGA or RTG alike.

Needs
-----

- A 68040 or 68060 with an FPU.
- AmigaOS 3.x with an AGA chipset or an RTG card (GFOS on AmiCradle has
  both). On AGA the 640 x 480 screen is high resolution and interlaced.
- Under 400 KB of disk.

Its own acgame.library is in the drawer's Libs/, so nothing else is
needed.

Install
-------

Double-click Install-ShadowPong (it asks where; Work:Games by default),
or drag the ShadowPong drawer anywhere. On GFOS: GFOpenUpTool INSTALL
Parts/ShadowPong.

Playing
-------

- Cursor up and down: move your paddle (the right one).
- Esc: leave the game.
- Right Amiga + Q: quit; Right Amiga + P: pause; Right Amiga + M: grab the
  mouse (ACGame's own keys, as in every ACGame game).

The scores are printed in the Shell when the game ends, as upstream does.

Port notes
----------

- Upstream's three BMPs are PNGs here, pixel for pixel, in a two-colour
  palette (tools/shadowpong8.py); the game sets the screen to black and
  white.
- Upstream keys the paddle's first byte as transparent, which never matches
  on a 24-bit screen; on an 8-bit screen it would hide the whole paddle, so
  the port draws the paddles solid, as they look upstream.

Designed, tested and delivered by The AmiCradle Team.
