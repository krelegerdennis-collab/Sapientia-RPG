extends RefCounted
## Pure Action-gevechtskern (roadmap stap 3b, COMBAT_DESIGN.md §16). Geen nodes, geen scène, geen Input.
## - Klok: frametijd -> vaste stappen van 1/60 s (gelijk aan NetProtocol.SIM_HZ), met plafond per frame.
## - Vijand-AI volgt later (na de O-1-fix van RPG CODE in SomArena._enemy_ai), om conflicten te vermijden.
## - Meters: charge/swing-lock/iframes per stap.
## SomArena (scripts/som/som_arena.gd) roept dit aan en voert de effecten uit (sprites, schade, FX).
## Formules en tijden komen uit SomData/de balans (#208); hier staan geen balansgetallen.

const TICK_HZ := 60
const TICK_DT := 1.0 / float(TICK_HZ)
## Plafond per frame (geen "spiral of death" na een hapering): 12 stappen = tot 5 fps loopt het gevecht op
## echte tijd; daaronder vervalt de achterstand (was 5 in stap 3a; te krap op drukke CI-runners).
const MAX_TICKS_PER_FRAME := 12

var tick := 0
var acc := 0.0


## Frametijd erbij; geeft hoeveel vaste stappen nu gedraaid moeten worden (0..MAX_TICKS_PER_FRAME).
func frames_to_ticks(delta: float) -> int:
	acc += maxf(0.0, delta)
	var n := 0
	while acc >= TICK_DT - 0.000001 and n < MAX_TICKS_PER_FRAME:
		acc -= TICK_DT
		n += 1
	if n == MAX_TICKS_PER_FRAME and acc >= TICK_DT:
		acc = 0.0
	return n


## Meter na één stap (zelfde regel als het oude _process).
static func charge_after(charge: float, swing_lock: float, charge_after_anim: bool, charge_time: float, dt: float) -> float:
	if swing_lock <= 0.0 or not charge_after_anim:
		return minf(1.0, charge + dt / charge_time)
	return charge


## Alle timers in een Dictionary (bv. iframes per held) één stap omlaag, niet onder 0.
static func tick_down(timers: Dictionary, dt: float) -> void:
	for k in timers.keys():
		timers[k] = maxf(0.0, float(timers[k]) - dt)
