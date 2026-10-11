extends Node
## ALLEEN VOOR TESTEN — sfx per held en per monster.
## Start:  godot --path . -- --actorsfxtest
##   Elke held en elk monster heeft een plek (map + vier wavs) en een sleutel
##   in de AudioManager. De placeholders zijn afspeelbaar. Een onbekende id
##   blijft stil, zonder error.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const CATALOG := "res://assets/audio/actor_sfx.json"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Acteur-sfx ===")
	var catalog := _catalog()
	check("catalogus is een object", not catalog.is_empty())
	check("slots zijn aanval, raak, dood, vaardigheid", catalog.get("slots", []) == ActorSfx.SLOTS)
	_ids(catalog)
	_bestanden(catalog)
	_audio(catalog)
	_sleutels()
	print("ACTORSFXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await _frames(10)
	get_tree().quit(1 if failures else 0)


func _catalog() -> Dictionary:
	if not FileAccess.file_exists(CATALOG):
		check("catalogus bestaat", false)
		return {}
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(CATALOG))
	check("catalogus is geldige JSON", err == OK and typeof(json.data) == TYPE_DICTIONARY)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _ids(catalog: Dictionary) -> void:
	var helden: Dictionary = catalog.get("helden", {})
	var monsters: Dictionary = catalog.get("monsters", {})
	var hero_ids: Array = []
	for h in GD.HEROES:
		hero_ids.append(str(h["id"]))
	hero_ids.sort()
	var catalog_heroes: Array = helden.keys()
	catalog_heroes.sort()
	check("elke held heeft een sfx-map", catalog_heroes == hero_ids)
	var enemy_ids: Array = GD.ENEMIES.keys()
	enemy_ids.sort()
	var catalog_monsters: Array = monsters.keys()
	catalog_monsters.sort()
	check("elk monster heeft een sfx-map", catalog_monsters == enemy_ids)
	for id in hero_ids:
		var entry: Dictionary = helden.get(id, {})
		check("held %s heeft naam, stem en vier slots" % id, _entry_ok(entry))
	for id in enemy_ids:
		var entry: Dictionary = monsters.get(id, {})
		check("monster %s heeft naam, stem en vier slots" % id, _entry_ok(entry))


func _entry_ok(entry: Dictionary) -> bool:
	if str(entry.get("naam", "")) == "" or str(entry.get("stem", "")) == "":
		return false
	var slots: Dictionary = entry.get("slots", {})
	for slot in ActorSfx.SLOTS:
		if str(slots.get(slot, "")) == "":
			return false
	return true


func _bestanden(catalog: Dictionary) -> void:
	for soort in ["helden", "monsters"]:
		var groep: Dictionary = catalog.get(soort, {})
		for id in groep:
			for slot in ActorSfx.SLOTS:
				var path := ActorSfx.bestand(soort, str(id), slot)
				var ok := FileAccess.file_exists(path)
				if ok:
					var f := FileAccess.open(path, FileAccess.READ)
					ok = f != null and f.get_length() > 1000 and f.get_buffer(4) == "RIFF".to_utf8_buffer()
					if f != null:
						f.close()
				check("%s/%s/%s.wav is een wav" % [soort, id, slot], ok)


func _audio(catalog: Dictionary) -> void:
	check("manifest nog geladen (main_menu)", AudioManager.has_music("main_menu"))
	check("algemeen zwaardgeluid blijft in het manifest", AudioManager.has_sfx("sword_swing"))
	for soort in [["helden", "held"], ["monsters", "monster"]]:
		var groep: Dictionary = catalog.get(soort[0], {})
		for id in groep:
			for slot in ActorSfx.SLOTS:
				var k := ActorSfx.key(soort[1], str(id), slot)
				var heeft := AudioManager.has_sfx(k)
				check("sleutel %s" % k, heeft)
				if heeft:
					check("speelt %s" % k, AudioManager.play_sfx(k))


func _sleutels() -> void:
	check("sleutel held", ActorSfx.key("held", "dennis", "aanval") == "held_dennis_aanval")
	check("sleutel monster", ActorSfx.key("monster", "mosslijm", "dood") == "monster_mosslijm_dood")
	check("lege id geeft geen sleutel", ActorSfx.key("held", "", "aanval") == "")
	check("verkeerd slot geeft geen sleutel", ActorSfx.key("held", "dennis", "nope") == "")
	var held := {"is_hero": true, "s": {"id": "noor"}}
	var vijand := {"is_hero": false, "id": "glitchmot", "s": {}}
	var bondgenoot := {"is_hero": true, "ally": true, "s": {"species": "papiergeest"}}
	check("held-combatant is Noor", ActorSfx.soort_en_id(held) == PackedStringArray(["held", "noor"]))
	check("vijand-combatant is Glitch Moth", ActorSfx.soort_en_id(vijand) == PackedStringArray(["monster", "glitchmot"]))
	check("bondgenoot gebruikt de monsterstem", ActorSfx.soort_en_id(bondgenoot) == PackedStringArray(["monster", "papiergeest"]))
	check("afspelen van Noor lukt", ActorSfx.play(held, "aanval"))
	check("onbekende vijand blijft stil", not ActorSfx.play({"is_hero": false, "id": "geen_monster", "s": {}}, "aanval"))
	check("leeg doelwit blijft stil", not ActorSfx.play({}, "raak"))


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
