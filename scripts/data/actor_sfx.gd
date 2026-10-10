extends RefCounted
## Sfx per held en per monster.
##
## De plek in de repo:
##   res://assets/audio/sfx/helden/<id>/{aanval,raak,dood,vaardigheid}.wav
##   res://assets/audio/sfx/monsters/<id>/{aanval,raak,dood,vaardigheid}.wav
## De catalogus (naam, stem, volume) staat in res://assets/audio/actor_sfx.json.
## AudioManager leest die catalogus en maakt de sleutels held_<id>_<slot> en
## monster_<id>_<slot>. Ontbreekt een bestand of een id, dan blijft het stil.

const SLOTS := ["aanval", "raak", "dood", "vaardigheid"]
const CATALOG_PATH := "res://assets/audio/actor_sfx.json"


static func key(soort: String, id: String, slot: String) -> String:
	if id == "" or soort not in ["held", "monster"] or slot not in SLOTS:
		return ""
	return "%s_%s_%s" % [soort, id, slot]


## ["held"/"monster", id] voor een combatant uit battle.gd.
## Een Codex-bondgenoot gebruikt de monsterstem van zijn soort.
static func soort_en_id(combatant: Dictionary) -> PackedStringArray:
	var stats: Dictionary = combatant.get("s", {})
	if bool(combatant.get("ally", false)):
		return PackedStringArray(["monster", str(stats.get("species", ""))])
	if bool(combatant.get("is_hero", false)):
		return PackedStringArray(["held", str(stats.get("id", ""))])
	return PackedStringArray(["monster", str(combatant.get("id", ""))])


## Speelt het geluid. false als de sleutel of het bestand ontbreekt (geen error).
static func play(combatant: Dictionary, slot: String) -> bool:
	var si := soort_en_id(combatant)
	var k := key(si[0], si[1], slot)
	if k == "":
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio == null or not audio.has_sfx(k):
		return false
	return bool(audio.play_sfx(k))


static func bestand(soort_map: String, id: String, slot: String) -> String:
	return "res://assets/audio/sfx/%s/%s/%s.wav" % [soort_map, id, slot]
