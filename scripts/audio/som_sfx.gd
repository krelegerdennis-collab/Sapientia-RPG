class_name SomSfx
extends RefCounted
## Post-RC Action-sfx: sleutels en afspelen voor SomArena.
## som_arena.gd roept deze helpers aan op events (geen per-frame-allocatie).
## Geluid gaat via WorldSfx -> UiSfx.play -> AudioManager (manifest: volume, pitch,
## varianten, min_interval_ms). Alleen bestaande manifest-sleutels; geen nieuwe bestandsnamen.
## perfect_dodge heeft geen eigen sleutel: zelfde "dodge" als een gewone ontwijking.
## sword_hit_armor bestaat in het manifest maar wordt niet gekoppeld (geen pantser-detectie).

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")
const Spells := preload("res://scripts/data/spells.gd")

const DODGE := "dodge"
const SWORD_SWING := "sword_swing"
const SWORD_HIT := "sword_hit_flesh"
const PLAYER_HURT := "player_hurt"
const PLAYER_DEATH := "player_death"
const HEAL := "heal"
const BUFF := "buff_apply"
## element -> sleutel. "natuur" heeft (nog) geen eigen wav: tijdelijk de arcane straal.
const SPELL_BY_ELEMENT := {
	"vuur": "spell_fire",
	"ijs": "spell_ice",
	"bliksem": "spell_lightning",
	"licht": "spell_arcane_beam",
	"natuur": "spell_arcane_beam",
}
const SPELL_BY_TYPE := {"heal": HEAL, "hot": HEAL, "revive": HEAL, "buff": BUFF}

const ALL := [DODGE, SWORD_SWING, SWORD_HIT, PLAYER_HURT, PLAYER_DEATH, HEAL, BUFF,
		"spell_fire", "spell_ice", "spell_lightning", "spell_arcane_beam", WorldSfx.LEVEL_UP]


static func spell_key(spell_id: String) -> String:
	var sp: Dictionary = Spells.SPELLS.get(spell_id, {})
	if sp.is_empty():
		return ""
	var t := str(sp.get("type", ""))
	if SPELL_BY_TYPE.has(t):
		return str(SPELL_BY_TYPE[t])
	return str(SPELL_BY_ELEMENT.get(str(sp.get("element", "")), ""))


static func play(key: String) -> bool:
	return WorldSfx.play(key)


static func play_dodge() -> bool:
	return play(DODGE)


## Geen eigen perfect_dodge-sleutel in het manifest; zelfde geluid als dodge.
static func play_perfect_dodge() -> bool:
	return play(DODGE)


static func play_sword_swing() -> bool:
	return play(SWORD_SWING)


static func play_sword_hit() -> bool:
	return play(SWORD_HIT)


static func play_spell(spell_id: String) -> bool:
	return play(spell_key(spell_id))


static func play_player_hurt() -> bool:
	return play(PLAYER_HURT)


static func play_player_death() -> bool:
	return play(PLAYER_DEATH)


static func play_level_up() -> bool:
	return play(WorldSfx.LEVEL_UP)
