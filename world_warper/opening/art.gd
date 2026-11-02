class_name WorldWarperOpeningArt
extends RefCounted
## Paden en maten voor de WM1-opening (RPG ART, 384×216).

const DIR := "res://assets/sprites/opening/"

const BG_FAR := DIR + "drift_bg_far.png"
const BG_NEBULA := DIR + "drift_bg_nebula.png"
const BG_NEAR := DIR + "drift_bg_near.png"
const WORMHOLE := DIR + "wormhole_ring_cycle_strip.png"
const WARPER := DIR + "world_warper_drift_strip.png"
const ECHO_GLITCH := DIR + "echo_glitch_strip.png"

const VIEW_W := 384
const VIEW_H := 216

const WORMHOLE_FRAME := Vector2i(32, 32)
const WORMHOLE_FRAMES := 4
const WORMHOLE_POS := Vector2i(94, 82)
const WORMHOLE_TICKS_PER_FRAME := 3

const WARPER_FRAME := Vector2i(128, 104)
const WARPER_FRAMES := 8
## Midden van het schip ongeveer in het midden van het beeld.
const WARPER_POS := Vector2(128, 56)

const ECHO_FRAME := Vector2i(16, 24)
const ECHO_FRAMES := 4

## Parallax-scroll far:nebula:near = 1:2:4 (pixels/s bij speed 1).
const SCROLL_BASE := 14.0
