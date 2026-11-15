extends RefCounted
## Game-feel fase 1: impact-FX, gewichtsklassen, squash/nudge-tabellen.
## Alleen client-weergave; geen sim-knockback of netwerk.

## Fase 2: glitch-dood + loot-pop (client-only). false = oude death-sheet / fade.
const DEATH_GLITCH_ENABLED := true
const ENEMY_READ_DELAY_SEC := 2.0 / 60.0

const GameData := preload("res://scripts/data/game_data.gd")
const VALID_IMPACT_ELEMENTS: Array[String] = ["fysiek", "vuur", "ijs", "bliksem", "natuur", "licht"]

const WEIGHT_LIGHT: Array[String] = ["moskonijn", "glitchmot", "papiergeest"]
const WEIGHT_MEDIUM: Array[String] = ["mosslijm", "inktwurm"]


static func impact_element_for_spell(spell_id: String) -> String:
	var sp: Dictionary = GameData.SPELLS.get(spell_id, {})
	if str(sp.get("type", "")) == "heal":
		return ""
	var el := str(sp.get("element", ""))
	if el in VALID_IMPACT_ELEMENTS:
		return el
	return "fysiek"


static func weight_class_for_monster(m: Node, e: Dictionary) -> String:
	if e.has("golem"):
		return "zwaar"
	if "boss" in m and bool(m.boss):
		return "zwaar"
	var id := str(m.enemy_id) if "enemy_id" in m else ""
	if id in WEIGHT_LIGHT:
		return "licht"
	if id in WEIGHT_MEDIUM:
		return "middel"
	return "middel"


## Squash (sx, sy) per fase; alleen veelvouden van 1/16.
static func squash_for(weight: String, phase: int, finisher_only_heavy: bool) -> Vector2:
	if weight == "zwaar":
		if not finisher_only_heavy:
			return Vector2.ONE
		if phase == 0:
			return Vector2(1.0625, 0.9375)
		return Vector2.ONE
	match weight:
		"licht":
			match phase:
				0:
					return Vector2(1.125, 0.875)
				1:
					return Vector2(1.0625, 0.9375)
				2:
					return Vector2(0.9375, 1.0625)
				_:
					return Vector2.ONE
		_:
			match phase:
				0, 1:
					return Vector2(1.0625, 0.9375)
				2:
					return Vector2(0.9375, 1.0625)
				_:
					return Vector2.ONE
	return Vector2.ONE


## Visuele duw (px) langs slagrichting; alleen sprite.offset.
static func nudge_px(weight: String, t_ms: float) -> float:
	match weight:
		"licht":
			if t_ms <= 33.0:
				return 1.0
			if t_ms <= 66.0:
				return 2.0
			if t_ms <= 100.0:
				return 3.0
			if t_ms <= 210.0:
				return lerpf(3.0, 1.0, (t_ms - 100.0) / 110.0)
			if t_ms <= 270.0:
				return lerpf(1.0, 0.0, (t_ms - 210.0) / 60.0)
		"middel":
			if t_ms <= 50.0:
				return 1.0
			if t_ms <= 100.0:
				return 2.0
			if t_ms <= 210.0:
				return lerpf(2.0, 1.0, (t_ms - 100.0) / 110.0)
			if t_ms <= 270.0:
				return lerpf(1.0, 0.0, (t_ms - 210.0) / 60.0)
		"zwaar":
			if t_ms >= 50.0 and t_ms <= 100.0:
				return 1.0
			if t_ms > 100.0 and t_ms <= 160.0:
				return lerpf(1.0, 0.0, (t_ms - 100.0) / 60.0)
	return 0.0


static func squash_phase(t_ms: float) -> int:
	if t_ms < 50.0:
		return 0
	if t_ms < 100.0:
		return 1
	if t_ms < 150.0:
		return 2
	return 3
