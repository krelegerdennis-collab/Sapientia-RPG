extends Node
## Post-RC sfx: geluid bij het realtime Action-gevecht (SomArena), ALLEEN via de bestaande signalen
## van som_arena.gd (swing_landed, spell_released, player_hit, member_down, enemy_defeated). Geen
## wijziging in som_arena.gd of battle.gd. Speelt via WorldSfx -> UiSfx.play -> AudioManager.play_sfx
## (manifest: volume, pitch, varianten en min_interval_ms). Aangemaakt door dungeon_room.gd en
## arena_room.gd direct na SomArena.setup(). Co-op: signalen vuren op de host (zie sfx_plan.md).

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")
const Spells := preload("res://scripts/data/spells.gd")

const SWORD_SWING := "sword_swing"
const SWORD_HIT := "sword_hit_flesh"
const PLAYER_HURT := "player_hurt"
const PLAYER_DEATH := "player_death"
const HEAL := "heal"
const BUFF := "buff_apply"
## element -> sleutel. "natuur" heeft (nog) geen eigen wav: tijdelijk de arcane straal (vraag Dennis).
const SPELL_BY_ELEMENT := {
	"vuur": "spell_fire",
	"ijs": "spell_ice",
	"bliksem": "spell_lightning",
	"licht": "spell_arcane_beam",
	"natuur": "spell_arcane_beam",
}
const SPELL_BY_TYPE := {"heal": HEAL, "hot": HEAL, "revive": HEAL, "buff": BUFF}

const ALL := [SWORD_SWING, SWORD_HIT, PLAYER_HURT, PLAYER_DEATH, HEAL, BUFF,
		"spell_fire", "spell_ice", "spell_lightning", "spell_arcane_beam"]

var arena: Node = null
## level per held-id bij het begin / na het laatste verslagen monster (level-up = verschil).
var _levels := {}


## Hangt de luisteraar onder de arena; geeft hem terug (tests). Twee keer aanroepen = één luisteraar.
static func attach(a: Node) -> Node:
	if a == null:
		return null
	var old := a.get_node_or_null("SomSfx")
	if old != null:
		return old
	var n: Node = (load("res://scripts/audio/som_sfx.gd") as GDScript).new()
	n.name = "SomSfx"
	n.arena = a
	a.add_child(n)
	n._connect()
	return n


func _connect() -> void:
	_levels = _party_levels()
	_c("swing_landed", _on_swing_landed)
	_c("spell_released", _on_spell_released)
	_c("player_hit", _on_player_hit)
	_c("member_down", _on_member_down)
	_c("enemy_defeated", _on_enemy_defeated)


func _c(sig: String, cb: Callable) -> void:
	if arena.has_signal(sig) and not arena.is_connected(sig, cb):
		arena.connect(sig, cb)


static func spell_key(spell_id: String) -> String:
	var sp: Dictionary = Spells.SPELLS.get(spell_id, {})
	if sp.is_empty():
		return ""
	var t := str(sp.get("type", ""))
	if SPELL_BY_TYPE.has(t):
		return str(SPELL_BY_TYPE[t])
	return str(SPELL_BY_ELEMENT.get(str(sp.get("element", "")), ""))


func _on_swing_landed(_hero_id: String, hits: int) -> void:
	WorldSfx.play(SWORD_HIT if hits > 0 else SWORD_SWING)


func _on_spell_released(spell_id: String, _caster_id: String) -> void:
	WorldSfx.play(spell_key(spell_id))


func _on_player_hit(dmg: int) -> void:
	if dmg > 0:
		WorldSfx.play(PLAYER_HURT)


func _on_member_down(_hero_id: String) -> void:
	WorldSfx.play(PLAYER_DEATH)


## EXP wordt in som_arena.gd vóór enemy_defeated uitgedeeld (GameState.give_exp). In de arena speelt
## arena_run.gd al level_up; daar niet nog eens.
func _on_enemy_defeated(_m: Node, _exp: int, _gold: int, _drops: Array) -> void:
	var now := _party_levels()
	var up := false
	for id in now:
		if int(now[id]) > int(_levels.get(id, now[id])):
			up = true
	_levels = now
	if up and not bool(arena.get("arena_mode")):
		WorldSfx.play(WorldSfx.LEVEL_UP)


func _party_levels() -> Dictionary:
	var out := {}
	if not is_instance_valid(GameState):
		return out
	for h in GameState.party:
		out[str(h.get("id", h.get("name", "")))] = int(h.get("level", 1))
	return out
