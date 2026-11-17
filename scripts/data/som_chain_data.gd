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
## Hitstop (ticks dat de geraakte vijand bevriest): hit1 = 0, hit2 = 2, finisher = 6.
const HITSTOP_TICKS: Array[int] = [0, 2, 6]
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

## Eigen sheets per stap (T26, RPG ART): 288x192, 6x4 frames van 48x48, rijen onder/links/rechts/boven
## (zoals SomData.ATTACK_ANIMS), treffer aan het begin van frame 4 (SomData.ATTACK_HIT_FRAME).
## Helden zonder eigen sheet (of als het bestand ontbreekt) spelen hit2/finisher als placeholder van
## <held>_attack.png met het tempo uit STEP_MS.
const STEP_SHEETS := {
	"dennis": {"hit2": "res://assets/sprites/som/combat/dax_attack2.png", "finisher": "res://assets/sprites/som/combat/dax_finisher.png"},
	"lotte": {"hit2": "res://assets/sprites/som/combat/seren_attack2.png", "finisher": "res://assets/sprites/som/combat/seren_finisher.png"},
	"noor": {"hit2": "res://assets/sprites/som/combat/vesper_attack2.png", "finisher": "res://assets/sprites/som/combat/vesper_finisher.png"},
	"kael": {"hit2": "res://assets/sprites/som/combat/kael_attack2.png", "finisher": "res://assets/sprites/som/combat/kael_finisher.png"},
	"orion": {"hit2": "res://assets/sprites/som/combat/orion_attack2.png", "finisher": "res://assets/sprites/som/combat/orion_finisher.png"},
}
## Epic keten-FX (RPG ART): horizontale strips, anker midden, geen lus; zie docs/combat/chain_feel.md.
const FX_HIT1 := {"sheet": "res://assets/sprites/som/fx/fx_chain_hit1.png", "cell": [32, 32], "frames": 3, "ms": 50}
const FX_HIT2 := {"sheet": "res://assets/sprites/som/fx/fx_chain_hit2.png", "cell": [32, 32], "frames": 3, "ms": 50}
const FX_SHOCKWAVE := {"sheet": "res://assets/sprites/som/fx/fx_chain_shockwave.png", "cell": [48, 48], "frames": 4, "ms": 55,
	"anchor": [24, 24]}
const FINISHER_FX_MS: Array[int] = [50, 50, 60, 50, 50]
const FINISHER_FX_SHEETS := {
	"dennis": "res://assets/sprites/som/fx/fx_chain_finisher_dennis.png",
	"lotte": "res://assets/sprites/som/fx/fx_chain_finisher_lotte.png",
	"noor": "res://assets/sprites/som/fx/fx_chain_finisher_noor.png",
	"kael": "res://assets/sprites/som/fx/fx_chain_finisher_kael.png",
	"orion": "res://assets/sprites/som/fx/fx_chain_finisher_orion.png",
}
const AFTERIMAGE_TINT := {
	"dennis": Color8(164, 102, 240),
	"lotte": Color8(200, 244, 255),
	"noor": Color8(232, 184, 255),
	"kael": Color8(64, 224, 232),
	"orion": Color8(248, 232, 144),
}
const AFTERIMAGE_OFFSETS: Array[float] = [4.0, 8.0, 12.0]
const AFTERIMAGE_ALPHAS: Array[float] = [0.55, 0.35, 0.18]
const FINISHER_ENEMY_FLASH_SEC := 1.0 / 60.0

const STEP_MS := {
	"hit1": [],   # leeg = SomData.ATTACK_ANIMS[id]["ms"] (bestaande slag)
	"hit2": [80, 120, 40, 90, 70, 120],      # eigen sheet: STEP_SHEETS
	"finisher": [140, 220, 60, 140, 110, 220],   # eigen sheet: STEP_SHEETS
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


## Pad van de eigen sheet voor stap 'step' van held 'id', of "" (geen sheet / bestand ontbreekt = terugval).
static func step_sheet(id: String, step: int) -> String:
	if clamp_step(step) == STEP_HIT1:
		return ""
	var path := str(STEP_SHEETS.get(id, {}).get(state_for(step), ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return path


## Animatie-definitie voor stap 'step' van held 'base' (= SomData.ATTACK_ANIMS[id]). Met een eigen sheet
## (step_sheet) staat die in "sheet" en is "placeholder" false; anders = zelfde sheet met eigen tempo.
## De treffer blijft op base["hit_frame"] (frame 4).
static func anim_def(base: Dictionary, step: int, id := "") -> Dictionary:
	var d := base.duplicate()
	var ms: Array = STEP_MS.get(state_for(step), [])
	if not ms.is_empty():
		d["ms"] = ms
	d["chain_state"] = state_for(step)
	var own := step_sheet(id, step) if id != "" else ""
	if own != "":
		d["sheet"] = own
	d["placeholder"] = step != STEP_HIT1 and own == ""
	return d


static func fx_def_for_step(step: int, hero_id: String) -> Dictionary:
	match clamp_step(step):
		STEP_HIT1:
			return FX_HIT1.duplicate()
		STEP_HIT2:
			return FX_HIT2.duplicate()
		STEP_FINISHER:
			var sheet := finisher_fx_sheet(hero_id)
			if sheet == "":
				return {}
			return {"sheet": sheet, "cell": [32, 32], "frames": 5, "ms": FINISHER_FX_MS.duplicate()}
		_:
			return {}


static func finisher_fx_sheet(hero_id: String) -> String:
	var path := str(FINISHER_FX_SHEETS.get(hero_id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return path


static func anim_ticks(def: Dictionary, tick_dt: float) -> int:
	var tot := 0.0
	for v in def.get("ms", []):
		tot += float(v)
	return int(ceil(tot / 1000.0 / tick_dt - 0.0001))
