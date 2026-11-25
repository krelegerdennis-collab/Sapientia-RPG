extends RefCounted
## C-11 pad-fix: één autosave per slot als autosave_N.json (geen autosave_N_M.json).
## Start vanuit een lege, geïsoleerde user:// met de echte productienamen, niet de
## test-flag paden uit game_state.gd (_ready r.796-798). Migratie van legacy
## autosave_1_1.json; Doorgaan (newest_save_path) kiest de nieuwste.
## Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const TOWN := "res://scenes/maps/wilgendal.tscn"
const BASE := "user://autosave.json"
const SAVE1 := "user://save_1.json"


func needs_game() -> bool:
	return false


func run(t: Node) -> void:
	var old_save: String = GameState.save_path
	var old_auto: String = GameState.autosave_path
	var old_story_save: String = GameState._story_save_path
	var old_story_auto: String = GameState._story_autosave_path
	var old_slot: int = GameState.active_slot
	var old_pending: int = GameState.pending_new_slot
	var old_gold: int = GameState.gold
	var old_map: String = GameState.current_map
	var old_beta: bool = GameState.playing_beta
	var old_eind: bool = GameState.playing_eind
	_wipe_prod()
	GameState.playing_beta = false
	GameState.playing_eind = false
	# Lege user://, productiepaden (niet user://f6uxtest2_autosave.json).
	GameState.save_path = SAVE1
	GameState.autosave_path = GameState.AUTOSAVE_PATH
	GameState._story_save_path = ""
	GameState._story_autosave_path = ""
	GameState.pending_new_slot = 1
	GameState.active_slot = 1
	# Zoals _ready ná new_game: autosave_path is al autosave_1.json, basis was leeg.
	t.check("ná active_slot (basis leeg): autosave_path is autosave_1.json",
			GameState.autosave_path == "user://autosave_1.json")
	GameState._bind_story_save_paths()
	t.check("_bind: _story_autosave_path is de basis autosave.json, niet autosave_1.json",
			GameState._story_autosave_path == BASE
			and GameState._autosave_base_path(GameState.autosave_path) == BASE)
	t.check("_bind: autosave_path blijft autosave_1.json (geen dubbele suffix)",
			GameState.autosave_path == "user://autosave_1.json"
			and GameState.autosave_slot_path(1) == "user://autosave_1.json")
	# Verdediging: oude toewijzing _story_autosave_path = autosave_path mag niet opnieuw _N plakken.
	GameState._story_autosave_path = GameState.autosave_path
	t.check("ook met per ongeluk gesuffixte basis: slots 1-4 zonder dubbele suffix",
			GameState.autosave_slot_path(1) == "user://autosave_1.json"
			and GameState.autosave_slot_path(2) == "user://autosave_2.json"
			and GameState.autosave_slot_path(3) == "user://autosave_3.json"
			and GameState.autosave_slot_path(4) == "user://autosave_4.json")
	GameState._bind_story_save_paths()
	t.check("_bind herstelt een gesuffixte basis naar autosave.json",
			GameState._story_autosave_path == BASE)
	GameState.current_map = TOWN
	GameState.gold = 41
	t.check("autosave schrijft autosave_1.json",
			GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, GameState.autosave_path)
			and FileAccess.file_exists("user://autosave_1.json")
			and not FileAccess.file_exists("user://autosave_1_1.json")
			and int(GameState.read_save("user://autosave_1.json").get("gold", -1)) == 41)
	# Geen dubbele suffix voor slots 1-4, elk in het eigen bestand.
	_wipe_prod()
	GameState._bind_story_save_paths()
	var slots_ok := true
	for s in range(1, GameState.SLOT_COUNT + 1):
		GameState.active_slot = s
		var want := "user://autosave_%d.json" % s
		var wrong_a := "user://autosave_1_%d.json" % s
		var wrong_b := "user://autosave_%d_%d.json" % [s, s]
		if GameState.autosave_path != want or GameState.autosave_slot_path(s) != want:
			slots_ok = false
			t.check("slot %d: pad is %s (was %s)" % [s, want, GameState.autosave_path], false)
			continue
		GameState.gold = 100 + s
		GameState.save_game(Vector2i(s, 1), Vector2i.DOWN, GameState.autosave_path)
		var wrote := FileAccess.file_exists(want) and not FileAccess.file_exists(wrong_a) \
				and not FileAccess.file_exists(wrong_b) \
				and int(GameState.read_save(want).get("gold", -1)) == 100 + s
		t.check("slot %d: bestand is %s, geen %s/%s" % [s, want.get_file(), wrong_a.get_file(), wrong_b.get_file()], wrote)
		slots_ok = slots_ok and wrote
	t.check("slots 1-4: geen dubbele suffix", slots_ok)
	# Migratie: alleen legacy autosave_1_1.json op een lege user://.
	_wipe_prod()
	GameState.save_path = SAVE1
	GameState._story_save_path = SAVE1
	GameState._story_autosave_path = BASE
	GameState.active_slot = 1
	GameState.sync_autosave_path()
	_write_min("user://autosave_1_1.json", 777, 1, 5000.0)
	t.check("vóór migratie: alleen de legacy autosave_1_1.json bestaat",
			FileAccess.file_exists("user://autosave_1_1.json")
			and not FileAccess.file_exists("user://autosave_1.json"))
	t.check("vóór migratie: has_autosave en newest zien de legacy (fallback)",
			GameState.has_autosave() and GameState.newest_save_path() == "user://autosave_1_1.json")
	GameState._migrate_double_suffix_autosaves()
	t.check("migratie: autosave_1_1.json verplaatst naar autosave_1.json (goud 777)",
			FileAccess.file_exists("user://autosave_1.json")
			and not FileAccess.file_exists("user://autosave_1_1.json")
			and int(GameState.read_save("user://autosave_1.json").get("gold", -1)) == 777)
	t.check("Doorgaan: newest is autosave_1.json na migratie",
			GameState.newest_save_path() == "user://autosave_1.json"
			and int(GameState.read_newest_save().get("gold", -1)) == 777)
	# .bak reist mee als het doel nog vrij is.
	_wipe_prod()
	_write_min("user://autosave_1_2.json", 222, 2, 5100.0)
	_write_min("user://autosave_1_2.json.bak", 221, 2, 5090.0)
	GameState._migrate_double_suffix_autosaves()
	t.check("migratie slot 2: autosave_1_2.json + .bak -> autosave_2.json",
			FileAccess.file_exists("user://autosave_2.json")
			and FileAccess.file_exists("user://autosave_2.json.bak")
			and not FileAccess.file_exists("user://autosave_1_2.json")
			and int(GameState.read_save("user://autosave_2.json").get("gold", -1)) == 222)
	# Juiste file nieuwer: niet overschrijven, legacy blijft (geen data kwijt).
	_wipe_prod()
	_write_min("user://autosave_1.json", 100, 1, 8000.0)
	_write_min("user://autosave_1_1.json", 200, 1, 1000.0)
	GameState._migrate_double_suffix_autosaves()
	t.check("beide aanwezig, juiste nieuwer: niet overschrijven, legacy blijft",
			int(GameState.read_save("user://autosave_1.json").get("gold", -1)) == 100
			and FileAccess.file_exists("user://autosave_1_1.json")
			and int(GameState.read_save("user://autosave_1_1.json").get("gold", -1)) == 200)
	t.check("Doorgaan kiest de nieuwste (autosave_1.json, goud 100)",
			GameState.newest_save_path() == "user://autosave_1.json"
			and int(GameState.read_newest_save().get("gold", -1)) == 100)
	# Legacy nieuwer: juiste file niet overschrijven, Doorgaan laadt de nieuwste (legacy).
	_wipe_prod()
	_write_min("user://autosave_1.json", 100, 1, 1000.0)
	_write_min("user://autosave_1_1.json", 200, 1, 9000.0)
	GameState._migrate_double_suffix_autosaves()
	t.check("beide aanwezig, legacy nieuwer: juiste file blijft, legacy blijft",
			int(GameState.read_save("user://autosave_1.json").get("gold", -1)) == 100
			and FileAccess.file_exists("user://autosave_1_1.json")
			and int(GameState.read_save("user://autosave_1_1.json").get("gold", -1)) == 200)
	t.check("Doorgaan kiest de nieuwste (legacy autosave_1_1.json, goud 200)",
			GameState.newest_save_path() == "user://autosave_1_1.json"
			and int(GameState.read_newest_save().get("gold", -1)) == 200)
	_wipe_prod()
	GameState.save_path = old_save
	GameState.autosave_path = old_auto
	GameState._story_save_path = old_story_save
	GameState._story_autosave_path = old_story_auto
	GameState.pending_new_slot = old_pending
	GameState.active_slot = old_slot
	GameState.gold = old_gold
	GameState.current_map = old_map
	GameState.playing_beta = old_beta
	GameState.playing_eind = old_eind
	GameState.sync_autosave_path()


func _write_min(path: String, gold: int, home_slot: int, saved_unix: float) -> void:
	var d := {
		"map": TOWN,
		"party": [{"id": "dennis"}],
		"gold": gold,
		"autosave": true,
		"slot": 0,
		"home_slot": home_slot,
		"saved_unix": saved_unix,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()


func _wipe_prod() -> void:
	var paths: Array[String] = [BASE, SAVE1]
	for s in range(1, 5):
		paths.append("user://save_%d.json" % s)
		paths.append("user://autosave_%d.json" % s)
		for k in range(1, 5):
			paths.append("user://autosave_%d_%d.json" % [k, s])
	for p in paths:
		_remove(p)
		_remove(p + ".bak")


func _remove(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
