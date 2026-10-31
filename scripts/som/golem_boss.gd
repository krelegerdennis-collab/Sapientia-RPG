extends RefCounted
class_name GolemBoss
## D3 PR B: de Golem (kennis_beest) als realtime Action-baas (docs/combat/d3_action_bosses.md §2, §7).
## Alleen data + registratie. Logica: golem_fight.gd (host-authoritatief, deterministisch, 60 Hz).
## Stats blijven ONGEWIJZIGD (game_data.gd kennis_beest.boss: HP 360, ATK 27, DEF 15).
## Alle tijden in ticks @ 60 Hz. BALANS = VOORSTEL voor Dennis (niet afgestemd op de sim).

const BossScript := preload("res://scripts/som/boss_script.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const ENEMY_ID := "kennis_beest"
const TICK_HZ := 60

## Regels uit §2/§7 (Dennis 31 okt 2026): windup >= 24, grote AoE >= 36; dodge-iframes 15 > actief.
const MIN_WINDUP_TICKS := 24
const MIN_WINDUP_LARGE_AOE_TICKS := 36
const MAX_ACTIVE_TICKS := 6

## Realtime kern (§7 Besluit 2): vaste cyclus 8 s, waarvan 2 s open, break 45. In ELKE fase.
const CORE := {
	"cycle_ticks": 480,       # 8 s
	"open_ticks": 120,        # 2 s (= golem_core_charge windup)
	"break_damage": 45,
	"stagger_ticks": 60,
	# closed_mult / open_mult / slam_power: NIET hier, maar uit game_data (kennis_beest.boss.core), zie core_config().
}
## Kern-velden die uit game_data komen (één bron met de Classic BossCore).
const CORE_FROM_GAME_DATA := ["closed_mult", "open_mult", "slam_power"]
## Aanvallen waarvan power = game_data slam_power (Hamerslag).
const SLAM_ATTACKS := ["golem_hammer_blow", "golem_hammer_blow_p3"]

## Aanvallen. shape/reach in tegels (16 px). large_aoe = AoE > 3 tegels -> windup >= 36.
## power = factor op de realtime klap (ATK-formule), zoals EnemyAttacks.power.
const ATTACKS := {
	"golem_sweep": {"shape": "melee_arc", "angle": 120, "reach_tiles": 2.0, "windup": 30, "active": 4, "recovery": 30,
		"power": 1.0, "large_aoe": false, "style": "red"},
	"golem_sweep_p2": {"shape": "melee_arc", "angle": 120, "reach_tiles": 2.0, "windup": 26, "active": 4, "recovery": 30,
		"power": 1.0, "large_aoe": false, "style": "red"},
	"golem_book_hammer": {"shape": "circle", "reach_tiles": 1.5, "windup": 36, "active": 4, "recovery": 40,
		"power": 1.5, "large_aoe": false, "style": "red", "aim": "target"},
	## Fase 3: twee keer achter elkaar (36 + 24).
	"golem_book_hammer_x2": {"shape": "circle", "reach_tiles": 1.5, "windup": 36, "windup2": 24, "active": 4,
		"recovery": 40, "power": 1.5, "large_aoe": false, "style": "red", "aim": "target", "repeat": 2},
	"golem_shockwave": {"shape": "line", "reach_tiles": 5.0, "lines": 3, "windup": 36, "active": 4, "recovery": 36,
		"power": 1.2, "large_aoe": true, "style": "red"},
	## Kern-mislukt: AoE r=3 tegels (ATK x slam_power). Na het open venster.
	"golem_hammer_blow": {"shape": "circle", "reach_tiles": 3.0, "windup": 42, "active": 6, "recovery": 40, "large_aoe": true, "style": "red"},
	## Fase 3: eenmalig bij hp < 10%, zonder kernvenster.
	"golem_hammer_blow_p3": {"shape": "circle", "reach_tiles": 3.0, "windup": 48, "active": 6, "recovery": 40, "large_aoe": true, "style": "red"},
}

## Fases (BossScript-formaat, PR A). hp_until = einde van de fase (fractie max HP).
const SCRIPT := {
	"phases": [
		{"hp_until": 0.60, "on_enter": "bewaker", "adds": [],
			"attacks": [{"id": "golem_sweep", "weight": 1.0}, {"id": "golem_book_hammer", "weight": 1.0}]},
		{"hp_until": 0.25, "on_enter": "ontwaakt", "adds": ["papiergeest", "papiergeest"],
			"attacks": [{"id": "golem_sweep_p2", "weight": 1.0}, {"id": "golem_shockwave", "weight": 1.0}]},
		{"hp_until": 0.0, "on_enter": "overbelast", "adds": [], "rune_floors": 2,
			"attacks": [{"id": "golem_sweep", "weight": 1.0}, {"id": "golem_book_hammer_x2", "weight": 1.0}]},
	],
	"core": CORE,
	"p3_low_hp_blow_below": 0.10,
	"max_boss_telegraphs": 2,
	"enrage": false,          # §7 Besluit 5
}

## Sprites uit PR #341 (RPG ART).
const SPRITE_TELEGRAPH := "res://assets/sprites/bosses/telegraph_marker.png"   # 96x32: 3 frames (windup-voortgang)
const SPRITE_TELEGRAPH_FRAMES := 3
const SPRITE_CORE_OPEN := "res://assets/sprites/bosses/golem_core_open.png"    # 60x30: 2 frames (gloed)
const SPRITE_CORE_OPEN_FRAMES := 2
const SPRITE_PHASE_FLASH := "res://assets/sprites/bosses/phase_flash.png"      # 256x64: 4 frames
const SPRITE_PHASE_FLASH_FRAMES := 4
const SPRITE_DAMAGED := "res://assets/sprites/enemies/golem_boss_v2_damaged.png"  # 196x182, vanaf fase 2
const SPRITE_NORMAL := "res://assets/sprites/enemies/golem_boss_v2.png"


## game_data kennis_beest.boss.core (Classic-bron, ongewijzigd).
static func game_data_core() -> Dictionary:
	return ((GameData.ENEMIES[ENEMY_ID]["boss"] as Dictionary)["core"] as Dictionary)


## Realtime kern-config: CORE (ticks, break) + closed_mult/open_mult/slam_power uit game_data.
static func core_config() -> Dictionary:
	var c: Dictionary = CORE.duplicate()
	var gd := game_data_core()
	for k in CORE_FROM_GAME_DATA:
		c[k] = float(gd[k])
	return c


## Aanval-data; Hamerslag-power = game_data slam_power.
static func attack(id: String) -> Dictionary:
	var a: Dictionary = ATTACKS.get(id, {})
	if id in SLAM_ATTACKS:
		a = a.duplicate()
		a["power"] = float(game_data_core()["slam_power"])
	return a


## Registreer de Golem in BossScript.REGISTRY (idempotent). Zie PR-body: wie dit aanroept.
static func ensure_registered() -> void:
	if not BossScript.has_script(ENEMY_ID):
		BossScript.register(ENEMY_ID, SCRIPT)


static func unregister() -> void:
	BossScript.unregister(ENEMY_ID)


## Ticks -> ms (voor TelegraphState / EnemyAttacks-vorm).
static func ticks_to_ms(ticks: int) -> int:
	return (ticks * 1000) / TICK_HZ   # afronden naar beneden: TelegraphState.ms_to_ticks (ceil) geeft exact ticks terug
