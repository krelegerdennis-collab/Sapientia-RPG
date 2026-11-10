extends RefCounted
class_name PageWardenBoss
## M9a: Page Warden (Easy-eindbaas, baas-sleutel 10) als realtime Action-baas.
## Zelfde datavorm als GolemBoss. Logica: page_warden_fight.gd.
## Stats-bron: Dungeon100Scaling.boss_stats(..., 10). Bestaande curve-getallen blijven staan.
## SEAT_* en ACTION_* en de kern-venster-getallen zijn VOORSTEL (balans), geen canon.
##
## Registratiesleutel is "page_warden", niet "papiergeest": dat id deelt hij met de gewone
## Paper Wraith en met The Voice (sleutel 99). Zo blijft de Classic-baas turn-based.

const BossScript := preload("res://scripts/som/boss_script.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

const SCRIPT_ID := "page_warden"
const ENEMY_ID := "papiergeest"
const BOSS_KEY := 10
const TICK_HZ := 60
const SNAPSHOT_ENEMY_BUDGET := 8

## Zelfde vloer als de Golem (COMBAT_DESIGN §11 / d3_action_bosses.md).
const MIN_WINDUP_TICKS := 24
const MIN_WINDUP_LARGE_AOE_TICKS := 36
const MAX_ACTIVE_TICKS := 6

## VOORSTEL. De gedeelde hook boss_party_scale() blijft 1.0 (Golem-tests).
## Deze tabel schaalt alleen Page Warden, ná die hook, per bezette stoel.
const SEAT_HP: Array = [0.0, 1.0, 2.60, 2.95, 3.35]
const SEAT_ATK: Array = [0.0, 1.0, 1.42, 1.43, 1.45]
## VOORSTEL (sim 200 seeds, Easy-level 74, win 60-90%). Sleutel 10 zelf blijft 783/51/26.
## Zie tools/battlesim/page_warden_rt_sim.gd. Geen bestaand getal.
const ACTION_HP_MULT := 3.8
const ACTION_ATK_MULT := 2.6

## VOORSTEL stagger-venster. Zelfde machine als de Golem (BossCoreRt), maar schade ×1
## (geen closed/open-mult uit de kennis-kern). Geen hamerslag bij een mislukt venster.
const STAGGER := {
	"cycle_ticks": 480,       # 8 s, zelfde klokvorm als de Golem
	"open_ticks": 72,         # 1,2 s
	"break_damage": 48,
	"closed_mult": 1.0,
	"open_mult": 1.0,
	"stagger_ticks": 60,
}

## shape/reach in tegels (16 px). large_aoe = reach > 3 → windup >= 36.
## power = factor op de realtime klap (ATK van de baas), zoals GolemBoss.
const ATTACKS := {
	"page_line": {"shape": "line", "reach_tiles": 4.5, "width_px": 16, "windup": 36, "active": 4, "recovery": 36,
		"power": 1.0, "large_aoe": true, "style": "red", "ranged": true},
	"page_circle": {"shape": "circle", "reach_tiles": 2.25, "windup": 30, "active": 4, "recovery": 40,
		"power": 1.15, "large_aoe": false, "style": "red", "ranged": false},
	"page_fan": {"shape": "cone", "angle": 56, "reach_tiles": 4.5, "windup": 36, "active": 4, "recovery": 36,
		"power": 0.9, "large_aoe": true, "style": "red", "ranged": true},
	## Fase 2: twee lijnen achter elkaar. Reach 3,0 tegel is niet "> 3", dus windup mag 24.
	"page_volley": {"shape": "line", "reach_tiles": 3.0, "width_px": 16, "windup": 28, "windup2": 24, "active": 4,
		"recovery": 28, "power": 0.85, "large_aoe": false, "style": "red", "ranged": true, "repeat": 2},
}

## hp_until = einde van de fase (fractie max HP). Fase 2 onder 50%.
## Eén papiergeest-add: baas + add = 2, ruim onder het snapshot-plafond van 8.
const SCRIPT := {
	"phases": [
		{"hp_until": 0.50, "on_enter": "wacht", "adds": [],
			"attacks": [
				{"id": "page_line", "weight": 1.0},
				{"id": "page_circle", "weight": 1.0},
				{"id": "page_fan", "weight": 1.0},
			]},
		{"hp_until": 0.0, "on_enter": "omslag", "adds": ["papiergeest"],
			"attacks": [
				{"id": "page_volley", "weight": 1.2},
				{"id": "page_fan", "weight": 1.0},
				{"id": "page_circle", "weight": 1.0},
			]},
	],
	"stagger": STAGGER,
	"max_boss_telegraphs": 2,
	"enrage": false,
}

## Bestaande baas-art (handwerk). Niet wijzigen.
const SPRITE_BODY := "res://assets/sprites/enemies/page_warden.png"
const SPRITE_BACK := "res://assets/sprites/enemies/page_warden_rug.png"
## Placeholders (magenta hoek + PH). Echte frames: PR "Nodig van RPG ART".
const SPRITE_ATTACK := "res://assets/sprites/bosses/page_warden_attack_ph.png"     # 512x200, 2×256x200
const SPRITE_ATTACK_FRAMES := 2
const SPRITE_HIT := "res://assets/sprites/bosses/page_warden_hit_ph.png"           # 256x200
const SPRITE_PHASE2 := "res://assets/sprites/bosses/page_warden_phase2_ph.png"     # 256x200
const SPRITE_PAGE := "res://assets/sprites/bosses/page_warden_page_ph.png"         # 16x16
## Gedeelde baas-VFX (al in het spel). Geen nieuwe telegraaf-shader.
const SPRITE_TELEGRAPH := "res://assets/sprites/bosses/telegraph_marker.png"
const SPRITE_TELEGRAPH_FRAMES := 3
const SPRITE_PHASE_FLASH := "res://assets/sprites/bosses/phase_flash.png"
const SPRITE_PHASE_FLASH_FRAMES := 4


static func attack(id: String) -> Dictionary:
	return (ATTACKS.get(id, {}) as Dictionary).duplicate(true)


## boss_stats sleutel 10, ongeschaald. Zelfde woordenboek als Classic.
static func base_stats() -> Dictionary:
	return Scaling.boss_stats((GameData.ENEMIES[ENEMY_ID] as Dictionary).duplicate(true), BOSS_KEY)


## Action-stats voor `seats` bezette stoelen (mens + AI). HP/ATK × hook × VOORSTEL.
static func stats_for_seats(seats: int) -> Dictionary:
	var n := clampi(seats, 1, 4)
	var d := base_stats()
	var hook := SomData.boss_party_scale(n)
	d["max_hp"] = maxi(1, roundi(float(d["max_hp"]) * hook * float(SEAT_HP[n]) * ACTION_HP_MULT))
	d["atk"] = maxi(1, roundi(float(d["atk"]) * hook * float(SEAT_ATK[n]) * ACTION_ATK_MULT))
	d["page_warden"] = true
	d["boss_key"] = BOSS_KEY
	return d


static func stagger_config() -> Dictionary:
	return STAGGER.duplicate(true)


static func ensure_registered() -> void:
	if not BossScript.has_script(SCRIPT_ID):
		BossScript.register(SCRIPT_ID, SCRIPT)


static func unregister() -> void:
	BossScript.unregister(SCRIPT_ID)


static func ticks_to_ms(ticks: int) -> int:
	return (ticks * 1000) / TICK_HZ


## Houd adds binnen het snapshot-plafond. `current` = vijanden die al meetellen (inclusief de baas).
static func clamp_adds(current: int, ids: Array, budget: int = SNAPSHOT_ENEMY_BUDGET) -> Array:
	var out: Array = []
	var n := current
	for id in ids:
		if n >= budget:
			break
		out.append(str(id))
		n += 1
	return out


static func budget_matches_protocol() -> bool:
	return SNAPSHOT_ENEMY_BUDGET == Protocol.SNAPSHOT_ENEMY_BUDGET


## EnemyAttacks-vorm (ms + px) voor TelegraphShape. Geen vijand-pool.
static func attack_px(id: String) -> Dictionary:
	var a := attack(id)
	if a.is_empty():
		return {}
	var out := {
		"id": id,
		"shape": str(a["shape"]),
		"reach": roundi(float(a["reach_tiles"]) * 16.0),
		"windup_ms": ticks_to_ms(int(a["windup"])),
		"active_ms": ticks_to_ms(int(a["active"])),
		"recovery_ms": ticks_to_ms(int(a["recovery"])),
		"power": float(a["power"]),
		"boss": true,
	}
	if a.has("angle"):
		out["angle"] = int(a["angle"])
	if str(a["shape"]) == "line":
		out["width"] = int(a.get("width_px", 16))
	return out


static func is_tank(hero_id: String) -> bool:
	for h in GameData.HEROES:
		if str(h["id"]) == hero_id:
			return str(h.get("class", "")) == "Warrior"
	return false
