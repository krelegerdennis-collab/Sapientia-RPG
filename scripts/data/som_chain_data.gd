extends RefCounted
## 3-slag aanvalsketen (combat T15 / plan T18): tap, tap, tap = hit1 -> hit2 -> finisher.
## Alleen Action-gevechten (scripts/som/); Classic (turn-based) heeft geen keten.
## Alle tuning hier (tijdelijke voorstellen, Dennis beslist; zie PR "VOORSTEL voor Dennis").
## Tick-gebaseerd (1 tick = CombatSim.TICK_DT = 1/60 s), geen toeval: host-autoritatief en deterministisch.

const STEP_HIT1 := 0
const STEP_HIT2 := 1
const STEP_FINISHER := 2
const CHAIN_LENGTH := 3
## Staat-/animatienaam per stap (som_arena.chain_state, meta "chain_state" op de SomAttackAnim).
const STEP_STATES: Array[String] = ["hit1", "hit2", "finisher"]

## Inputvenster (ticks) na het einde van de slag-animatie: binnen dit venster tappen = volgende stap,
## anders terug naar hit1.
const CHAIN_WINDOW_TICKS := 20
## Schademultiplier per stap (bovenop de wapenmeter, SomArena.charge_mult).
const DAMAGE_MULT: Array[float] = [1.0, 1.1, 1.6]
## Hitstop (ticks dat de geraakte vijand bevriest). hit1/hit2 = 0 zodat de gewone slag niet verandert.
const HITSTOP_TICKS: Array[int] = [0, 0, 6]
## Knockback in tegels (de bestaande _knockback was altijd 1 tegel).
const KNOCKBACK_TILES: Array[int] = [1, 1, 2]
## De finisher staggert altijd (telegraaf breken + knockback), ook met een niet-volle meter:
## snel tap-tap-tap laat de meter nooit vollopen, anders zou de finisher-knockback nooit vallen.
const FINISHER_ALWAYS_STAGGERS := true
## Bondgenoot-AI ketent net zo snel als een speler (Dennis 2026-10-30 16:03): zelfde CHAIN_WINDOW_TICKS, en de
## AI "tapt" de volgende ketenslag zoveel ticks na het einde van zijn slag-animatie (< CHAIN_WINDOW_TICKS).
const ALLY_FOLLOWUP_TICKS := 6
## F5 (Dennis 2026-10-31): hit2/finisher binnen het venster slaan minimaal op deze meter (aan: 1.0 = volle meter).
const FOLLOWUP_MIN_METER := 1.0
## F5 (Dennis 2026-10-31): tik tijdens de eigen slag-animatie negeren (aan).
const TAP_GATE := true

## TODO RPG ART: placeholder-animaties. hit2 en finisher hergebruiken de bestaande <held>_attack.png
## (zelfde frames), alleen met een ander tempo, zodat de staat wel verschilt. Echte frames: zie PR
## "Nodig van RPG ART" en tools/placeholders_v17.txt.
const STEP_MS := {
	"hit1": [],   # leeg = SomData.ATTACK_ANIMS[id]["ms"] (bestaande slag)
	"hit2": [80, 120, 40, 90, 70, 120],      # TODO RPG ART: <held>_attack2.png
	"finisher": [140, 220, 60, 140, 110, 220],   # TODO RPG ART: <held>_finisher.png
}


static func clamp_step(step: int) -> int:
	return clampi(step, 0, CHAIN_LENGTH - 1)


static func state_for(step: int) -> String:
	return STEP_STATES[clamp_step(step)]


static func damage_mult(step: int) -> float:
	return DAMAGE_MULT[clamp_step(step)]


static func hitstop_ticks(step: int) -> int:
	return HITSTOP_TICKS[clamp_step(step)]


static func knockback_tiles(step: int) -> int:
	return KNOCKBACK_TILES[clamp_step(step)]


static func is_finisher(step: int) -> bool:
	return clamp_step(step) == STEP_FINISHER


## Animatie-definitie voor stap 'step' van held 'base' (= SomData.ATTACK_ANIMS[id]); placeholder = zelfde
## sheet met eigen tempo (TODO RPG ART).
static func anim_def(base: Dictionary, step: int) -> Dictionary:
	var d := base.duplicate()
	var ms: Array = STEP_MS.get(state_for(step), [])
	if not ms.is_empty():
		d["ms"] = ms
	d["chain_state"] = state_for(step)
	d["placeholder"] = step != STEP_HIT1
	return d


static func anim_ticks(def: Dictionary, tick_dt: float) -> int:
	var tot := 0.0
	for v in def.get("ms", []):
		tot += float(v)
	return int(ceil(tot / 1000.0 / tick_dt - 0.0001))
