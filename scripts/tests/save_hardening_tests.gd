extends Node
## ALLEEN VOOR TESTEN - save/load-hardening (docs/qa/SAVE_HARDENING.md). Vult save_tests.gd aan, vervangt het niet.
## Start:  godot --path . -- --savehardeningtest [--shots=/pad/map]
##   Deel A: corrupte / afgekapte save -> reservekopie (.bak) + duidelijke melding
##   Deel B: ontbrekende of kapotte velden (oudere saves) -> veilige standaardwaarden
##   Deel C: round-trip van alle voortgang (party, tas, goud, vlaggen, Codex, positie, slots, autosave)
##   Deel D: opslaan tijdens gevecht / menu / cutscene / dialoog / mapwissel
##   Deel E: geen dubbele spullen of goud door opslaan en opnieuw laden
## Zit niet in de export (scripts/tests/*).

const GameData := preload("res://scripts/data/game_data.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const ScenesData := preload("res://scripts/data/scenes_data.gd")
const MusicTracks := preload("res://scripts/data/music_tracks.gd")
const Equipment := preload("res://scripts/equipment.gd")
const SaveSlotList := preload("res://scripts/ui/save_slot_list.gd")
const DungeonChestScript := preload("res://scripts/dungeon/dungeon_chest.gd")

const TOWN := "res://scenes/maps/wilgendal.tscn"
const SAVE := "user://sh_main.json"
const HEROES := ["dennis", "lotte", "noor", "kael", "orion"]

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(4242)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


# ---------------------------------------------------------------- hulpjes
func _remove_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


## Voortgang als genormaliseerde tekst (zonder speeltijd), om twee toestanden te vergelijken.
func _sig(tile := Vector2i(7, 8), facing := Vector2i.UP) -> String:
	var d := GameState.state_data(tile, facing)
	d.erase("play_time")
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


## Welke bovenste sleutels verschillen tussen twee _sig()-teksten? (alleen voor de foutmelding)
func _diff(a: String, b: String) -> String:
	var da := JSON.parse_string(a) as Dictionary
	var db := JSON.parse_string(b) as Dictionary
	var out: Array = []
	for k in da:
		if JSON.stringify(da[k], "", true) != JSON.stringify(db.get(k), "", true):
			out.append(k)
	for k in db:
		if not da.has(k):
			out.append(k)
	return str(out)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


## Een rijke toestand met alle vijf de helden, uitrusting, Codex, vlaggen en een checkpoint.
func _rich_state() -> void:
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.story_step = StoryData.KLAAR
	GameState.story_flags = {"kist_open": true, "water_klaar": true, "proloog_gezien": true}
	GameState.join_member("lotte", 4, ["leren_kap"])
	GameState.join_member("noor", 5, ["eiken_staf"])
	GameState.join_member("kael", 6)
	GameState.join_member("orion", 3)
	GameState.inventory = {"drankje": 7, "toverwater": 2, "kort_zwaard": 1, "dolk": 2}
	GameState.inventory["kort_zwaard"] = 2
	Equipment.equip(GameState.party[0], GameState.inventory, "wapen", "kort_zwaard")
	GameState.gold = 4321
	GameState.party[0]["hp"] = maxi(1, int(GameState.party[0]["max_hp"]) - 3)
	GameState.party[1]["mp"] = maxi(0, int(GameState.party[1]["max_mp"]) - 2)
	GameState.party[2]["hp"] = 1
	GameState.leader_id = "lotte"
	GameState.codex_add("mosslijm", 3, {"tier": 2, "play_time": 12.0})
	var p2 := GameState.codex_add("papiergeest", 2, {"tier": 1, "play_time": 99.5})
	GameState.codex_set_active(str(p2.get("uid", "")))
	var enemy_id: String = str(GameData.ENEMIES.keys()[0])
	GameState.mark_seen(enemy_id)
	GameState.mark_defeated(enemy_id)
	GameState.mark_defeated(enemy_id)
	GameState.grant_kern(str(KernData.KERNFRAGMENTEN.keys()[0]))
	if GameState.is_unique("inktwurm"):
		GameState.unique_done["inktwurm"] = "verslagen"
	GameState._unique_seen_flags()
	GameState.scenes_seen = [str(ScenesData.ids()[0])]
	GameState.heard_music = [str(MusicTracks.ids()[0])]
	GameState.puzzle_latched = {"kamer_a": ["poort_1", "poort_2"]}
	GameState.koopman_bezoek("run1:5")
	GameState.koopman_token = true
	GameState.koopman_gekocht = ["tegengif"]
	GameState.dungeon100_reach_floor(25)
	GameState.archief2 = {"platen": {"kamer_x": 2}}
	GameState.bezochte_kaarten = [TOWN]
	GameState.echo_grot_voltooid = 2
	GameState.huis_herkomst = "dorp"
	GameState._play_time_base = 1234.5
	GameState._clock_start_ms = Time.get_ticks_msec()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.set_checkpoint(TOWN, Vector2i(3, 3), Vector2i.RIGHT)


func _total_of(id: String) -> int:
	var n := GameState.item_count(id)
	for h in GameState.party + GameState.party_bench:
		for s in Equipment.slots():
			if Equipment.equipped(h, s) == id:
				n += 1
	return n


# ---------------------------------------------------------------- run
func _run() -> void:
	print("=== Deel A: corrupte / afgekapte save ===")
	_corruption_tests()
	await _unreadable_slot_tests()
	print("=== Deel B: migratie en ontbrekende velden ===")
	_migration_tests()
	print("=== Deel C: round-trip van alle voortgang ===")
	_roundtrip_tests()
	print("=== Deel D: opslaan tijdens gevecht / menu / cutscene ===")
	_blocked_state_tests()
	await _scene_tests()
	print("=== Deel E: geen dubbele spullen of goud ===")
	_duplication_tests()
	_remove_save(SAVE)
	print("SAVEHARDENINGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- A: corruptie
func _two_good_saves() -> void:
	_remove_save(SAVE)
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.gold = 10
	GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, SAVE)
	GameState.gold = 20
	GameState.save_game(Vector2i(4, 5), Vector2i.UP, SAVE)


## Slotlijst en 'Doorgaan' met een onleesbaar slot (geen goede .bak): het goede slot blijft bruikbaar.
func _unreadable_slot_tests() -> void:
	var old_path := GameState.save_path
	var old_auto := GameState.autosave_path
	GameState.save_path = "user://sh_slots_save_1.json"
	GameState.autosave_path = "user://sh_slots_autosave.json"
	for s in range(1, GameState.SLOT_COUNT + 1):
		_remove_save(GameState.slot_path(s))
	_remove_save(GameState.autosave_path)
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.gold = 111
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, GameState.slot_path(1))
	GameState.gold = 222
	GameState.autosave(Vector2i(2, 2), Vector2i.DOWN, "achtergrond")
	_write(GameState.slot_path(2), "{\"gold\":")
	var good_auto := GameState.read_save(GameState.autosave_path)
	_write(GameState.autosave_path, "")
	check("onleesbare autosave (nieuwer dan slot 1) blokkeert 'Doorgaan' niet: newest = slot 1",
			GameState.newest_save_path() == GameState.slot_path(1) and int(GameState.read_newest_save().get("gold", -1)) == 111)
	check("onleesbaar slot 2 telt als corrupt, niet als leeg", bool(GameState.slot_record(2).get("corrupt", false)))
	var lst := SaveSlotList.new()
	add_child(lst)
	await _frames(2)
	check("slotlijst: onleesbaar slot en onleesbare autosave staan uit, slot 1 staat aan",
			lst.slot_buttons[1].disabled and lst.autosave_button.disabled and not lst.slot_buttons[0].disabled)
	check("slotlijst: label zegt 'unreadable save' (%s)" % lst.slot_buttons[1].text, lst.slot_buttons[1].text.contains("unreadable save"))
	lst.queue_free()
	_write(GameState.autosave_path, JSON.stringify(good_auto))
	check("goede autosave is weer het nieuwste", GameState.newest_save_path() == GameState.autosave_path)
	_remove_save(GameState.autosave_path)
	_write(GameState.slot_path(1), "{\"gold\":")
	check("alles onleesbaar: newest verwijst nog naar een bestand (laden meldt de fout)",
			GameState.has_any_save() and not GameState.load_game(GameState.newest_save_path())
			and GameState.last_load_notice == GameState.NOTICE_UNREADABLE)
	for s in range(1, GameState.SLOT_COUNT + 1):
		_remove_save(GameState.slot_path(s))
	_remove_save(GameState.autosave_path)
	GameState.save_path = old_path
	GameState.autosave_path = old_auto


func _corruption_tests() -> void:
	_two_good_saves()
	var good := _read(SAVE)
	var cuts := [0, 1, good.length() / 4, good.length() / 2, good.length() - 1]
	for cut in cuts:
		_write(SAVE, good.substr(0, cut))
		GameState.gold = 999
		var ok := GameState.load_game(SAVE)
		check("afgekapt op %d/%d tekens: valt terug op .bak (goud 10)" % [cut, good.length()],
				ok and GameState.gold == 10)
	var junk := {
		"leeg bestand": "",
		"alleen spaties": "   \n  ",
		"willekeurige tekst": "dit is geen json",
		"binaire rommel": String.chr(0) + String.chr(1) + String.chr(255) + "{}",
		"JSON-array i.p.v. object": "[1,2,3]",
		"JSON-getal": "42",
		"JSON null": "null",
		"leeg object": "{}",
		"party is geen lijst": "{\"map\":\"x\",\"party\":{}}",
		"map is geen tekst": "{\"map\":5,\"party\":[]}",
		"geen party": "{\"map\":\"res://x.tscn\"}",
	}
	for k in junk:
		_write(SAVE, junk[k])
		GameState.gold = 999
		var ok2 := GameState.load_game(SAVE)
		check("%s: valt terug op .bak (goud 10)" % k, ok2 and GameState.gold == 10)

	# melding
	_write(SAVE, good.substr(0, good.length() / 2))
	var seen: Array = []
	var on_rec := func(path: String, backup: String) -> void: seen.append([path, backup])
	GameState.save_recovered.connect(on_rec)
	GameState.gold = 999
	GameState.load_game(SAVE)
	GameState.save_recovered.disconnect(on_rec)
	check("terugval op .bak: signal save_recovered(pad, .bak)",
			seen.size() == 1 and seen[0][0] == SAVE and seen[0][1] == SAVE + ".bak")
	check("terugval op .bak: duidelijke Engelse melding (%s)" % GameState.last_load_notice,
			GameState.last_load_notice.contains("damaged") and GameState.last_load_notice.contains("backup"))
	check("terugval op .bak: de melding komt in de kaart (pending_respawn_msg)",
			GameState.pending_respawn_msg.size() == 2 and str(GameState.pending_respawn_msg[0]).contains("damaged"))
	var rec := GameState.slot_record(1) if GameState.slot_path(1) == SAVE else {}
	var old_path := GameState.save_path
	GameState.save_path = SAVE
	rec = GameState.slot_record(1)
	GameState.save_path = old_path
	check("slot_record meldt dat de data uit de reservekopie komt", bool(rec.get("from_backup", false)) and not bool(rec.get("corrupt", false)))
	var lst := SaveSlotList.new()
	var label := lst._label(1, rec)
	lst.free()
	check("slotlijst toont '(backup)' bij een slot dat uit de reservekopie komt (%s)" % label, label.contains("(backup)"))

	# normale load geeft geen melding
	_two_good_saves()
	GameState.load_game(SAVE)
	check("gewone load: geen melding en geen respawn-bericht",
			GameState.last_load_notice == "" and GameState.pending_respawn_msg.is_empty())

	# beide kapot: false, toestand blijft onaangeroerd
	_two_good_saves()
	_write(SAVE, "{\"gold\":")
	_write(SAVE + ".bak", "{\"par")
	GameState.new_game("Dax")
	GameState.gold = 555
	GameState.inventory = {"drankje": 9}
	var before := _sig()
	var emitted: Array = []
	var on_load := func(p: String, ok: bool) -> void: emitted.append([p, ok])
	GameState.game_loaded.connect(on_load)
	var ok3 := GameState.load_game(SAVE)
	GameState.game_loaded.disconnect(on_load)
	check("beide bestanden kapot: load_game geeft false en game_loaded(pad, false)",
			not ok3 and emitted.size() == 1 and emitted[0][0] == SAVE and emitted[0][1] == false)
	check("beide kapot: de lopende toestand (goud/tas/party) blijft ongewijzigd",
			_sig() == before and GameState.gold == 555)
	check("beide kapot: duidelijke melding (%s)" % GameState.last_load_notice,
			GameState.last_load_notice.contains("can't be read"))

	# een nieuwe save na corruptie verdringt de goede .bak niet
	_two_good_saves()
	_write(SAVE, "{\"gold\":")
	GameState.gold = 30
	check("opslaan boven een corrupte hoofd-save lukt", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE))
	check("goede .bak (goud 10) blijft staan na een save boven een corrupte hoofd-save",
			int(GameState._read_save_file(SAVE + ".bak").get("gold", -1)) == 10
			and int(GameState._read_save_file(SAVE).get("gold", -1)) == 30)

	# main weg, .bak aanwezig (bv. handmatig gewist / ouder bestandssysteem)
	_two_good_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	GameState.gold = 999
	check("hoofd-save weg maar .bak goed: load lukt met de .bak", GameState.load_game(SAVE) and GameState.gold == 10)

	# een volledig .tmp naast een goede hoofd-save mag niet worden geladen
	_two_good_saves()
	_write(SAVE + ".tmp", JSON.stringify({"map": "res://x.tscn", "party": [], "gold": 777}))
	GameState.gold = 999
	check("achtergebleven .tmp naast goede hoofd-save wordt genegeerd (goud 20)",
			GameState.load_game(SAVE) and GameState.gold == 20)

	# grote kapotte hoofd-save met geldige JSON-structuur maar verkeerde party-inhoud
	_write(SAVE, JSON.stringify({"map": TOWN, "party": ["x", 5, null, {"id": "bestaat_niet"}], "gold": 77}))
	GameState.new_game("Dax")
	check("party vol rommel: laadt, Dax wordt hersteld en andere ingangen vallen weg",
			GameState.load_game(SAVE) and GameState.party.size() == 1 and GameState.party[0]["id"] == "dennis"
			and GameState.gold == 77)
	_remove_save(SAVE)


# ---------------------------------------------------------------- B: migratie
func _full_save_dict() -> Dictionary:
	_rich_state()
	var d := GameState.state_data(Vector2i(5, 6), Vector2i.LEFT)
	d["checkpoint"] = GameState.checkpoint.duplicate(true)
	return JSON.parse_string(JSON.stringify(d))


func _load_dict(d: Dictionary) -> bool:
	_write(SAVE, JSON.stringify(d))
	_remove_file_if(SAVE + ".bak")
	GameState.new_game("Dax")
	var r = GameState.load_game(SAVE)
	return r == true


func _remove_file_if(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _sane_after_load(label: String) -> void:
	var ok := GameState.party.size() >= 1 and GameState.party.size() <= GameState.PartyLimiet.MAX_HELDEN
	for h in GameState.party + GameState.party_bench:
		ok = ok and int(h["level"]) >= 1 and int(h["max_hp"]) >= 1 and int(h["hp"]) >= 0 and int(h["hp"]) <= int(h["max_hp"]) \
				and int(h["mp"]) >= 0 and int(h["mp"]) <= int(h["max_mp"])
	ok = ok and GameState.gold >= 0 and GameState.leader_id is String
	for id in GameState.inventory:
		ok = ok and int(GameState.inventory[id]) >= 1
	check(label, ok)


func _migration_tests() -> void:
	var full := _full_save_dict()
	# 1) elke optionele sleutel afzonderlijk weg = een oudere save
	var optional: Array = []
	for k in full:
		if k != "map" and k != "party":
			optional.append(k)
	var bad_keys: Array = []
	for k in optional:
		var d: Dictionary = full.duplicate(true)
		d.erase(k)
		if not _load_dict(d):
			bad_keys.append(k)
	check("save zonder één optionele sleutel (%d sleutels) laadt altijd (misser: %s)" % [optional.size(), bad_keys], bad_keys.is_empty())
	# 2) elke sleutel met een verkeerd type
	var wrongs := [null, "tekst", [], {}, 3.7, true, -5, [1, "a", null], {"a": {"b": []}}]
	var crashers: Array = []
	for k in optional:
		for w in wrongs:
			var d2: Dictionary = full.duplicate(true)
			d2[k] = w
			if not _load_dict(d2):
				crashers.append("%s=%s" % [k, JSON.stringify(w)])
	check("elke sleutel met een verkeerd type laadt zonder fout (misser: %s)" % [crashers.slice(0, 6)], crashers.is_empty())
	_sane_after_load("na verkeerde types: party/HP/goud/tas zijn geldig")

	# 3) ontbrekende velden per held
	var hero_fail: Array = []
	var fields: Array = []
	for k in (full["party"][0] as Dictionary):
		if k != "id":
			fields.append(k)
	for k in fields:
		var d3: Dictionary = full.duplicate(true)
		for e in d3["party"]:
			(e as Dictionary).erase(k)
		if not _load_dict(d3):
			hero_fail.append(k)
	check("held zonder één veld (%d velden) laadt altijd (misser: %s)" % [fields.size(), hero_fail], hero_fail.is_empty())
	_sane_after_load("na held-velden weg: HP/MP/level binnen de grenzen")
	var d4: Dictionary = full.duplicate(true)
	for e in d4["party"]:
		var keep: String = str(e["id"])
		(e as Dictionary).clear()
		e["id"] = keep
	check("helden met alleen een id laden", _load_dict(d4) and GameState.party.size() == 4)
	var tmpl_ok := true
	for h in GameState.party:
		var t := GameState.hero_template(str(h["id"]))
		tmpl_ok = tmpl_ok and int(h["max_hp"]) == int(t["max_hp"]) and int(h["level"]) == int(t["level"]) \
				and int(h["hp"]) == int(h["max_hp"])
	check("helden met alleen een id krijgen de standaardwaarden van hun sjabloon (vol HP)", tmpl_ok)
	for id in HEROES:
		var d5 := {"map": TOWN, "party": [{"id": "dennis"}, {"id": id}]}
		_load_dict(d5)
		check("minimale save met held '%s' laadt (naam %s)" % [id, GameState.member(id).get("name", "?")],
				not GameState.member(id).is_empty())

	# 4) letterlijke oude saves
	var v011 := "{\"map\":\"res://scenes/maps/wilgendal.tscn\",\"tile\":[3,4],\"facing\":[0,1],\"player_name\":\"Dennis\"," \
			+ "\"party\":[{\"id\":\"ruben\",\"name\":\"Dennis\",\"level\":3,\"exp\":20,\"hp\":15,\"mp\":4,\"max_hp\":30,\"max_mp\":8," \
			+ "\"atk\":7,\"def\":4,\"agi\":5,\"weapon\":\"kort_zwaard\"},{\"id\":\"noor\",\"name\":\"Noor\",\"level\":2}]," \
			+ "\"inventory\":{\"drankje\":4},\"gold\":55}"
	_write(SAVE, v011)
	_remove_file_if(SAVE + ".bak")
	GameState.new_game("Dax")
	var ok_old: bool = GameState.load_game(SAVE) == true
	check("oude save (v0.11, 'ruben', zonder equip/base/mag): laadt", ok_old)
	check("oude namen migreren: Dennis->Dax, Noor->Vesper, held-id ruben->dennis",
			GameState.player_name == "Dax" and GameState.party[0]["id"] == "dennis" and GameState.party[0]["name"] == "Dax"
			and GameState.party[1]["name"] == "Vesper")
	check("oude save: wapen in het wapenvak, tas en goud intact",
			Equipment.equipped(GameState.party[0], "wapen") == "kort_zwaard" and GameState.item_count("drankje") == 4
			and GameState.gold == 55 and int(GameState.party[0]["hp"]) == 15)
	check("oude save: ontbrekende velden = standaard (story KLAAR, leider Dax, lege Codex, geen vlaggen, geen reserve)",
			GameState.story_step == StoryData.KLAAR and GameState.leader_id == GameState.MAIN_HERO
			and GameState.codex_pages.is_empty() and GameState.party_bench.is_empty() and GameState.checkpoint.is_empty())
	check("oude save: positie uit de save", GameState.return_map == TOWN and GameState.return_tile == Vector2i(3, 4)
			and GameState.return_facing == Vector2i(0, 1))
	check("oude save: speeltijd 0, SAVE_VERSION-vergelijking crasht niet", GameState.play_time() < 5.0)
	_sane_after_load("oude save: alles binnen de grenzen")

	# toekomstige versie met onbekende velden
	var fut: Dictionary = full.duplicate(true)
	fut["version"] = 999
	fut["nieuw_veld_uit_de_toekomst"] = {"a": [1, 2, 3]}
	check("save uit een nieuwere versie (onbekende velden) laadt", _load_dict(fut))

	# te veel helden in party -> reserve
	var many: Dictionary = {"map": TOWN, "party": []}
	for id in HEROES:
		many["party"].append({"id": id, "level": 2})
	_load_dict(many)
	check("save met 5 actieve helden: 4 in de groep, 1 in de reserve, Dax blijft",
			GameState.party.size() == 4 and GameState.party_bench.size() == 1 and GameState.party[0]["id"] == "dennis")

	# rare getallen
	var odd: Dictionary = {"map": TOWN, "party": [{"id": "dennis", "level": -4, "hp": 99999, "mp": -7, "max_hp": 0, "exp": -50}],
			"gold": -500, "inventory": {"drankje": -3, "toverwater": 0, "dolk": 2.9, "": 4}}
	_load_dict(odd)
	_sane_after_load("rare getallen (level < 1, HP > max, negatief goud/tas): alles wordt binnen de grenzen gezet")
	check("negatief goud wordt 0, negatieve en nul-aantallen vallen weg", GameState.gold == 0
			and not GameState.inventory.has("drankje") and not GameState.inventory.has("toverwater")
			and GameState.item_count("dolk") == 2)
	var huge: Dictionary = {"map": TOWN, "party": [{"id": "dennis"}], "gold": 1e30, "inventory": {"drankje": 1e30}}
	_load_dict(huge)
	check("absurd groot goud/aantal wordt begrensd (goud %d, drankje %d)" % [GameState.gold, GameState.item_count("drankje")],
			GameState.gold >= 0 and GameState.gold <= GameState.MAX_GOLD
			and GameState.item_count("drankje") >= 0 and GameState.item_count("drankje") <= GameState.MAX_ITEM_STACK)
	_remove_save(SAVE)


# ---------------------------------------------------------------- C: round-trip
func _roundtrip_tests() -> void:
	_rich_state()
	_remove_save(SAVE)
	var tile := Vector2i(9, 4)
	var facing := Vector2i.LEFT
	var before := _sig(tile, facing)
	var party_before := GameState._party_save()
	var bench_before := GameState._party_save_from(GameState.party_bench)
	check("rijke toestand: 4 actieve helden (Dax, Seren, Vesper, Kael) + Orion in de reserve",
			GameState.party.map(func(h): return h["id"]) == ["dennis", "lotte", "noor", "kael"]
			and GameState.party_bench.size() == 1 and GameState.party_bench[0]["id"] == "orion")
	check("save_game lukt en meldt true", GameState.save_game(tile, facing, SAVE))

	# helemaal wissen en dan laden
	GameState.new_game("Zed")
	GameState.gold = 1
	GameState.inventory = {}
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	check("na new_game is de toestand echt anders", _sig(tile, facing) != before)
	check("load_game lukt", GameState.load_game(SAVE))
	var after := _sig(tile, facing)
	check("round-trip: volledige voortgang is byte-voor-byte gelijk (zonder speeltijd) (verschil: %s)" % _diff(before, after), after == before)
	check("round-trip: party Dax/Seren/Vesper/Kael in volgorde, Orion in de reserve",
			GameState.party.map(func(h): return h["name"]) == ["Dax", "Seren", "Vesper", "Kael Voss"]
			and GameState.party_bench.map(func(h): return h["name"]) == ["Orion"])
	check("round-trip: party-gegevens (level/exp/hp/mp/stats/uitrusting) gelijk",
			JSON.stringify(GameState._party_save(), "", true) == JSON.stringify(party_before, "", true)
			and JSON.stringify(GameState._party_save_from(GameState.party_bench), "", true) == JSON.stringify(bench_before, "", true))
	check("round-trip: Dax draagt zijn zwaard, tas klopt, goud 4321",
			Equipment.equipped(GameState.party[0], "wapen") == "kort_zwaard" and GameState.item_count("drankje") == 7
			and GameState.item_count("kort_zwaard") == 1 and GameState.gold == 4321)
	check("round-trip: gedeeltelijke HP/MP (Dax -3, Vesper 1 HP, Seren -2 MP) blijven",
			int(GameState.party[2]["hp"]) == 1 and int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"]) - 3)
	check("round-trip: leider Seren, naam Dax, huis_herkomst, echo_grot, bezochte kaarten",
			GameState.leader_id == "lotte" and GameState.player_name == "Dax" and GameState.huis_herkomst == "dorp"
			and GameState.echo_grot_voltooid == 2 and GameState.bezochte_kaarten == [TOWN])
	check("round-trip: verhaalstap en vlaggen", GameState.story_step == StoryData.KLAAR
			and GameState.story_flags.has("kist_open") and GameState.story_flags.has("water_klaar"))
	check("round-trip: Codex (2 vangsten, actieve bondgenoot, volgende uid, vangstgegevens)",
			GameState.codex_pages.size() == 2 and GameState.codex_active == "codex_0002" and GameState.codex_next_id == 3
			and int(GameState.codex_pages[0]["level"]) == 3 and int(GameState.codex_pages[1]["caught"]["tier"]) == 1
			and str(GameState.codex_pages[0]["species"]) == "mosslijm")
	check("round-trip: bestiarium, kernfragment, scenes, muziek, puzzels, koopman, dungeon100, archief2",
			GameState.defeated_count(str(GameData.ENEMIES.keys()[0])) == 2 and GameState.kernfragmenten.size() == 1
			and GameState.scenes_seen.has(str(ScenesData.ids()[0])) and GameState.heard_music.has(str(MusicTracks.ids()[0]))
			and GameState.puzzle_latched.get("kamer_a") == ["poort_1", "poort_2"]
			and GameState.koopman_token and GameState.koopman_bezoeken == 1 and GameState.koopman_gekocht == ["tegengif"]
			and GameState.dungeon100_best >= 25 and GameState.dungeon100_warpers.has(25)
			and int(GameState.archief2["platen"].get("kamer_x", 0)) == 2)
	check("round-trip: gevechtsstijl (Action) reist mee", Settings.get_value("battle_style") == Settings.BATTLE_STYLE_ACTION)
	check("round-trip: checkpoint (kamer, tegel, kijkrichting)", GameState.has_checkpoint()
			and GameState.checkpoint["map"] == TOWN and GameState.checkpoint["tile"] == [3, 3])
	check("round-trip: positie (map, tegel, kijkrichting) komt terug als terugkeerpunt",
			GameState.return_map == TOWN and GameState.return_tile == tile and GameState.return_facing == facing
			and GameState.has_return_point)
	check("round-trip: speeltijd loopt door vanaf de opgeslagen waarde", GameState.play_time() >= 1234.0 and GameState.play_time() < 1240.0)

	# tweede ronde: opnieuw opslaan geeft dezelfde inhoud (idempotent)
	var first := JSON.parse_string(_read(SAVE)) as Dictionary
	GameState.save_game(tile, facing, SAVE)
	var second := JSON.parse_string(_read(SAVE)) as Dictionary
	for k in ["saved_at", "saved_unix", "play_time"]:
		first.erase(k)
		second.erase(k)
	check("save -> load -> save: inhoud blijft identiek (idempotent)",
			JSON.stringify(first, "", true) == JSON.stringify(second, "", true))
	check("opnieuw opslaan zet de vorige save als .bak",
			GameState._read_save_file(SAVE + ".bak").has("party"))

	# dezelfde ronde via de slots 1..4 en de autosave
	var old_path := GameState.save_path
	GameState.save_path = "user://sh_slots_save_1.json"
	for s in range(1, GameState.SLOT_COUNT + 1):
		_remove_save(GameState.slot_path(s))
		GameState.active_slot = s
		GameState.save_game(tile, facing)
	_remove_save(GameState.autosave_path)
	check("autosave-pad (pauze-save) schrijft de volledige toestand", GameState.autosave(tile, facing, "achtergrond"))
	var all_same := true
	for s in range(1, GameState.SLOT_COUNT + 1):
		GameState.new_game("Zed")
		var ok := GameState.load_game(GameState.slot_path(s))
		all_same = all_same and ok and _sig(tile, facing) == before and GameState.active_slot == s
	check("slot 1..4: elk slot geeft dezelfde toestand terug en onthoudt zijn slotnummer", all_same)
	GameState.new_game("Zed")
	check("autosave laden geeft dezelfde toestand terug", GameState.load_game(GameState.autosave_path) and _sig(tile, facing) == before)
	for s in range(1, GameState.SLOT_COUNT + 1):
		_remove_save(GameState.slot_path(s))
	_remove_save(GameState.autosave_path)
	GameState.save_path = old_path

	# een round-trip tijdens een Dungeon100-run (momentopname van de echte party/tas)
	_rich_state()
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 3
	GameState.inventory["drankje"] = 2
	GameState.gold = 15
	var in_run := _sig(tile, facing)
	GameState.save_game(tile, facing, SAVE)
	GameState.new_game("Zed")
	GameState.load_game(SAVE)
	check("round-trip midden in een Dungeon100-run (momentopname + run-tas)", _sig(tile, facing) == in_run
			and GameState.dungeon100_run_active() and GameState.dungeon100_floor == 3)
	GameState.dungeon100_end_run(true)
	check("run beëindigen na laden: echte tas, goud, party en uitrusting zijn terug",
			GameState.gold == 4321 and GameState.item_count("drankje") == 7
			and Equipment.equipped(GameState.party[0], "wapen") == "kort_zwaard" and GameState.party.size() == 4)
	_remove_save(SAVE)


# ---------------------------------------------------------------- D: geblokkeerde toestanden
func _blocked_state_tests() -> void:
	_rich_state()
	_remove_save(GameState.autosave_path)
	var count := GameState.autosave_count
	var tile := Vector2i(2, 2)

	GameState.in_battle = true
	check("tijdens een gevecht: can_autosave is false", not GameState.can_autosave(true))
	check("tijdens een gevecht: pauze-save schrijft niets", not GameState.autosave(tile, Vector2i.DOWN, "achtergrond")
			and not FileAccess.file_exists(GameState.autosave_path) and GameState.autosave_count == count)
	GameState.in_battle = false

	GameState.changing_map = true
	check("tijdens een mapwissel: pauze-save schrijft niets", not GameState.autosave(tile, Vector2i.DOWN, "achtergrond")
			and not FileAccess.file_exists(GameState.autosave_path))
	GameState.changing_map = false

	Story.running = true
	check("tijdens een cutscene (Story.running): pauze-save schrijft niets",
			not GameState.autosave(tile, Vector2i.DOWN, "achtergrond") and not FileAccess.file_exists(GameState.autosave_path))
	Story.running = false

	Dialog.is_open = true
	check("tijdens een dialoog: pauze-save schrijft niets",
			not GameState.autosave(tile, Vector2i.DOWN, "achtergrond") and not FileAccess.file_exists(GameState.autosave_path))
	Dialog.is_open = false

	check("onbekende redenen blijven geblokkeerd", not GameState.autosave(tile, Vector2i.DOWN, "battle")
			and not GameState.autosave(tile, Vector2i.DOWN, ""))
	check("vrije wereld: pauze-save werkt (autosave-instelling doet er niet toe)", GameState.autosave(tile, Vector2i.DOWN, "achtergrond")
			and FileAccess.file_exists(GameState.autosave_path))
	_remove_save(GameState.autosave_path)

	# gevecht-toestand: spullen verbruiken en HP verliezen in het gevecht gaat NIET de save in
	_rich_state()
	var save_path := "user://sh_battle.json"
	_remove_save(save_path)
	GameState.save_game(tile, Vector2i.DOWN, save_path)
	var pre_battle := _sig(tile, Vector2i.DOWN)
	GameState.in_battle = true
	GameState.inventory["drankje"] = 3
	GameState.party[0]["hp"] = 1
	GameState.gold += 500
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("app naar de achtergrond tijdens het gevecht: geen autosave en de oude save blijft ongewijzigd",
			not FileAccess.file_exists(GameState.autosave_path) and JSON.stringify(GameState._read_save_file(save_path)).contains("4321"))
	GameState.in_battle = false
	GameState.new_game("Zed")
	GameState.load_game(save_path)
	check("laden na een proces-kill tijdens het gevecht: terug naar de toestand van vóór het gevecht",
			_sig(tile, Vector2i.DOWN) == pre_battle and GameState.item_count("drankje") == 7 and GameState.gold == 4321)
	check("na laden is in_battle onwaar (nooit midden in een gevecht hervatten)", not GameState.in_battle)

	# een (verkeerde) handmatige save tijdens een gevecht slaat geen halve gevechtstoestand op als 'in gevecht'
	check("save_game schrijft geen gevechtsvlaggen in het bestand",
			not GameState.state_data(tile, Vector2i.DOWN).has("in_battle") and not GameState.state_data(tile, Vector2i.DOWN).has("pending_enemies"))
	_remove_save(save_path)


func _scene_tests() -> void:
	GameState.new_game("Kees")
	GameState.story_step = StoryData.KLAAR
	GameState.change_map(TOWN, "start")
	var ok := await _wait_scene("Wilgendal")
	check("testwereld: Wilgendal geladen", ok)
	if not ok:
		return
	await _frames(20)
	GameState.add_member("noor")
	GameState.gold = 123
	var map: Node = get_tree().current_scene
	var player: Node = map.get_node_or_null("Objects/Player")
	check("speler staat in de kaart", player != null)
	if player == null:
		return
	_remove_save(GameState.autosave_path)
	_remove_save(GameState.save_path)

	# menu open: pauze-save schrijft een geldig bestand, het menu blijft gewoon werken
	await _tap("menu")
	await _frames(3)
	var menu: Node = map.get_node_or_null("FieldMenu")
	check("veldmenu is open", menu != null)
	if menu != null:
		GameState.inventory["drankje"] = 5
		var gold_before := GameState.gold
		var count := GameState.autosave_count
		GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		var a := GameState.read_save(GameState.autosave_path)
		check("menu open + app naar de achtergrond: autosave geschreven (reden achtergrond)",
				GameState.autosave_count == count + 1 and GameState.last_autosave_reason == "achtergrond"
				and not a.is_empty() and bool(a.get("autosave", false)))
		check("menu open: de save bevat de huidige tas, goud en positie van de speler",
				int(a["gold"]) == gold_before and int(a["inventory"]["drankje"]) == 5
				and Vector2i(int(a["tile"][0]), int(a["tile"][1])) == player.get_tile())
		check("menu open: menu en speler zijn na de pauze-save onaangetast", is_instance_valid(menu) and GameState.gold == gold_before)
		check("menu: handmatig opslaan (save_now) lukt en meldt via game_saved(pad, true)", _menu_save(menu))
		GameState.autosave_count = count
		menu.close()
		await _frames(3)

	# focusverlies op mobiel = ook pauze-save; op desktop niet
	_remove_save(GameState.autosave_path)
	GameState.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("FOCUS_OUT: alleen op mobiel een pauze-save (headless desktop: geen)",
			FileAccess.file_exists(GameState.autosave_path) == OS.has_feature("mobile"))

	# cutscene: de kaart weigert, ook als de speler stilstaat
	_remove_save(GameState.autosave_path)
	Story.running = true
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("kaart + cutscene + pauze: niets geschreven", not FileAccess.file_exists(GameState.autosave_path))
	Story.running = false

	# het veldmenu (en dus handmatig opslaan) gaat niet open tijdens een cutscene, dialoog of gevecht
	var blockers := {"cutscene": func(on: bool) -> void: Story.running = on,
			"dialoog": func(on: bool) -> void: Dialog.is_open = on,
			"gevecht": func(on: bool) -> void: GameState.in_battle = on}
	for name in blockers:
		blockers[name].call(true)
		await _tap("menu")
		check("tijdens een %s opent het veldmenu niet" % name, map.get_node_or_null("FieldMenu") == null)
		blockers[name].call(false)
	await _frames(2)

	# speler halverwege een stap: geen save op een tussenpositie
	player.is_moving = true
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("speler halverwege een stap: geen pauze-save", not FileAccess.file_exists(GameState.autosave_path))
	player.is_moving = false
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("speler stil: pauze-save werkt weer", FileAccess.file_exists(GameState.autosave_path))
	_remove_save(GameState.autosave_path)
	_remove_save(GameState.save_path)


func _menu_save(menu: Node) -> bool:
	var seen: Array = []
	var on_saved := func(p: String, ok: bool) -> void: seen.append([p, ok])
	GameState.game_saved.connect(on_saved)
	var ok: bool = menu.save_now()
	GameState.game_saved.disconnect(on_saved)
	return ok and seen.size() == 1 and seen[0][1] == true and FileAccess.file_exists(str(seen[0][0]))


# ---------------------------------------------------------------- E: geen duplicatie
func _duplication_tests() -> void:
	_rich_state()
	var tile := Vector2i(1, 1)
	var swords := _total_of("kort_zwaard")
	var gold := GameState.gold
	var potions := GameState.item_count("drankje")

	# 1) laden vervangt de toestand; het telt nooit op
	_remove_save(SAVE)
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	for i in 5:
		GameState.load_game(SAVE)
	check("5x laden: goud, drankjes en zwaarden (tas + gedragen) blijven gelijk",
			GameState.gold == gold and GameState.item_count("drankje") == potions and _total_of("kort_zwaard") == swords)
	check("5x laden: Codex en reserve niet verdubbeld", GameState.codex_pages.size() == 2 and GameState.party_bench.size() == 1
			and GameState.party.size() == 4)

	# 2) spullen weggeven/gebruiken en terug laden geeft de oude toestand, geen extra
	GameState.inventory["drankje"] = 1
	GameState.gold = 3
	GameState.load_game(SAVE)
	check("verbruik + laden: precies de oude hoeveelheid (geen extra)", GameState.item_count("drankje") == potions and GameState.gold == gold)
	GameState.inventory["drankje"] = 50
	GameState.gold = 99999
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.inventory["drankje"] = 0
	GameState.load_game(SAVE)
	check("oogsten + laden telt niet dubbel", GameState.item_count("drankje") == 50 and GameState.gold == 99999)

	# 3) twee saves (handmatig + autosave) na elkaar laden telt niet op
	_rich_state()
	var a := "user://sh_a.json"
	var b := "user://sh_b.json"
	_remove_save(a)
	_remove_save(b)
	GameState.save_game(tile, Vector2i.DOWN, a)
	GameState.inventory["drankje"] = 1
	GameState.gold = 5
	GameState.save_game(tile, Vector2i.DOWN, b)
	GameState.load_game(a)
	GameState.load_game(b)
	GameState.load_game(a)
	check("A -> B -> A laden: de laatst geladen save wint volledig (geen optelling)",
			GameState.item_count("drankje") == 7 and GameState.gold == 4321)
	_remove_save(a)
	_remove_save(b)

	# 4) uitrusting: een stuk zit OF in de tas OF aan een held, ook na laden
	_rich_state()
	var before_total := _total_of("kort_zwaard")
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.load_game(SAVE)
	Equipment.unequip(GameState.party[0], GameState.inventory, "wapen")
	check("uitrusting uitdoen na laden: totaal blijft gelijk", _total_of("kort_zwaard") == before_total)
	Equipment.equip(GameState.party[0], GameState.inventory, "wapen", "kort_zwaard")
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.load_game(SAVE)
	check("uitrusten + opslaan + laden: totaal blijft gelijk", _total_of("kort_zwaard") == before_total)
	# een held die een stuk draagt dat hij niet mag dragen: het stuk gaat één keer terug in de tas
	var d := JSON.parse_string(_read(SAVE)) as Dictionary
	d["party"][2]["equip"]["wapen"] = "kort_zwaard"      # Vesper (magier) mag geen zwaard
	var inv_swords := _total_of("kort_zwaard")
	_write(SAVE, JSON.stringify(d))
	GameState.load_game(SAVE)
	check("onmogelijk uitrustingsstuk in een save: Vesper draagt het niet en het komt precies één keer in de tas",
			Equipment.equipped(GameState.member("noor"), "wapen") == "" and _total_of("kort_zwaard") == inv_swords + 1)

	# 5) kist: vlag eerst, dan buit; na laden is de kist niet opnieuw te openen
	_rich_state()
	GameState.story_flags.erase("kist:sh_testkist")
	var chest := DungeonChestScript.new() as DungeonChest
	chest.setup({"id": "sh_testkist", "item": "toverwater", "n": 3, "tile": [2, 2]})
	add_child(chest)
	var tw := GameState.item_count("toverwater")
	chest.open_chest()
	check("kist geeft zijn buit één keer", GameState.item_count("toverwater") == tw + 3 and chest.is_open())
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.load_game(SAVE)
	var chest2 := DungeonChestScript.new() as DungeonChest
	chest2.setup({"id": "sh_testkist", "item": "toverwater", "n": 3, "tile": [2, 2]})
	add_child(chest2)
	chest2.open_chest()
	chest2.open_chest()
	check("kist na save+load: blijft open, geen tweede buit", chest2.is_open() and GameState.item_count("toverwater") == tw + 3)
	# de truc: opslaan VOOR het openen, openen, laden = buit weg (geen kopie)
	GameState.story_flags.erase("kist:sh_testkist")
	GameState.inventory["toverwater"] = tw
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	var chest3 := DungeonChestScript.new() as DungeonChest
	chest3.setup({"id": "sh_testkist", "item": "toverwater", "n": 3, "tile": [2, 2]})
	add_child(chest3)
	chest3.open_chest()
	GameState.load_game(SAVE)
	check("kist openen en vóór-save laden: buit én vlag samen teruggedraaid", GameState.item_count("toverwater") == tw
			and not GameState.story_flags.has("kist:sh_testkist"))
	chest.free()
	chest2.free()
	chest3.free()

	# 6) Codex: uid's worden nooit hergebruikt, ook niet na laden of na vrijlaten
	_rich_state()
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.load_game(SAVE)
	var np := GameState.codex_add("moskonijn", 1, {})
	var uids := {}
	for p in GameState.codex_pages:
		uids[str(p["uid"])] = true
	check("Codex na laden: nieuwe vangst krijgt een nieuw uid (%s), geen dubbele uids" % np.get("uid", "?"),
			not np.is_empty() and uids.size() == GameState.codex_pages.size() and str(np["uid"]) == "codex_0003")
	var cd := JSON.parse_string(_read(SAVE)) as Dictionary
	cd["codex"]["pages"].append((cd["codex"]["pages"][0] as Dictionary).duplicate(true))
	_write(SAVE, JSON.stringify(cd))
	GameState.load_game(SAVE)
	check("Codex-pagina met dubbel uid in een save: maar één exemplaar", GameState.codex_pages.size() == 2)
	cd["codex"]["next"] = 0
	_write(SAVE, JSON.stringify(cd))
	GameState.load_game(SAVE)
	var nn := GameState.codex_add("moskonijn", 1, {})
	check("Codex 'next' ontbreekt of te laag: nooit een uid hergebruiken", str(nn["uid"]) == "codex_0003")

	# 7) game over + checkpoint: terugdraaien geeft geen extra of verloren spullen
	_rich_state()
	GameState.set_checkpoint(TOWN, Vector2i(3, 3), Vector2i.RIGHT)
	var cp_potions := GameState.item_count("drankje")
	var cp_gold := GameState.gold
	GameState.inventory["drankje"] = cp_potions + 10
	GameState.gold += 1000
	GameState.respawn_at_checkpoint(false)
	check("checkpoint-respawn: tas en goud terug naar het checkpoint (geen buit meegenomen)",
			GameState.item_count("drankje") == cp_potions and GameState.gold == cp_gold)
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	var cp_len := _read(SAVE).length()
	GameState.set_checkpoint(TOWN, Vector2i(3, 3), Vector2i.RIGHT)
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	var cp_len2 := _read(SAVE).length()
	check("het checkpoint groeit niet bij elke save (geen nestende kopieën: %d -> %d tekens)" % [cp_len, cp_len2],
			absi(cp_len2 - cp_len) < 64 and not (JSON.parse_string(_read(SAVE))["checkpoint"]["state"] as Dictionary).has("checkpoint"))

	# 8) Dungeon100: mid-run laden en het einde levert niet dubbel af
	_rich_state()
	GameState.dungeon100_permanent = {"kort_zwaard": 1}
	GameState.dungeon100_delivered = {}
	GameState.dungeon100_begin_run()
	GameState.dungeon100_floor = 2
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	var swords0 := _total_of("kort_zwaard")
	GameState.load_game(SAVE)
	GameState.load_game(SAVE)
	GameState.dungeon100_end_run(true)
	var swords_after := _total_of("kort_zwaard")
	GameState.dungeon100_deliver()
	GameState.dungeon100_deliver()
	check("Dungeon100: permanent item wordt eenmaal afgeleverd, ook na 2x laden en 2x deliver (%d -> %d)" % [swords0, swords_after],
			_total_of("kort_zwaard") == swords_after and swords_after <= 3 + 1)
	GameState.save_game(tile, Vector2i.DOWN, SAVE)
	GameState.load_game(SAVE)
	GameState.dungeon100_deliver()
	check("Dungeon100: na opslaan/laden na de run wordt er niets nogmaals afgeleverd", _total_of("kort_zwaard") == swords_after)
	_remove_save(SAVE)
