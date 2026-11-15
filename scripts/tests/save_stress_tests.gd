extends Node
## ALLEEN VOOR TESTEN - opslag- en hervat-stresstest voor de interne RC (WM1).
## Start:  godot --path . -- --savestresstest
##   Deel A: round-trip op vaste WM1-momenten (party, tas, goud, vlaggen, positie) + tweede round-trip is identiek
##   Deel B: lege / afgekapte / half geschreven / willekeurig beschadigde save -> .bak of nette melding,
##           nooit een kapot bestand over een goede reservekopie heen
##   Deel C: pauze/hervat (PAUSED, FOCUS_OUT, FOCUS_IN, RESUMED) in menu, dialoog en gevecht (save_stress_pause.gd)
##   Deel D: twee keer snel opslaan, opslaan binnen een save/autosave (re-entrant), 25 saves achter elkaar
##   Deel E: save van vóór het versienummer laadt en wordt gemigreerd; nieuwere versie blijft alleen-lezen
## Vult savetest / savefuzztest / saveroundtriptest / saverobusttest / savehardeningtest aan, vervangt ze niet.
## Werkt alleen op user://savestress_*; echte saves worden niet aangeraakt. Zit niet in de export (scripts/tests/*).

const F := preload("res://scripts/tests/save_stress_fixtures.gd")
const PausePart := preload("res://scripts/tests/save_stress_pause.gd")
const StoryData := preload("res://scripts/data/story_data.gd")

const TOWN := "res://scenes/maps/wilgendal.tscn"
const RT := "user://savestress_rt.json"
const RT2 := "user://savestress_rt2.json"
const CORRUPT := "user://savestress_corrupt.json"
const DUBBEL := "user://savestress_dubbel.json"
const SNEL := "user://savestress_snel.json"
const OUD := "user://savestress_oud.json"
const SEED := 20261115
## Vlaggen die laden er zelf bij mag zetten (migratie in world_warper/opening/flow.gd en _unique_seen_flags).
const MIGRATIE_VLAGGEN := ["warper_drift_done", "tutorial_inktwurm_gezien", "tutorial_codex_vangen_gezien"]

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(SEED)
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


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _gold_in(path: String) -> int:
	var d := GameState._read_save_file(path)
	var g = d.get("gold", -1)
	return int(g) if (g is int or g is float) else -1


func _valid(path: String) -> bool:
	return GameState._valid_save_data(GameState._read_save_file(path))


func _no_temp(path: String) -> bool:
	return not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak.tmp")


## Voortgang als genormaliseerde tekst (zonder speeltijd), om twee toestanden te vergelijken.
func _sig(tile: Vector2i, facing: Vector2i, map: String) -> String:
	var d := GameState.state_data(tile, facing, map)
	d.erase("play_time")
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


## Welke bovenste sleutels verschillen tussen twee _sig()-teksten?
func _diff(a: String, b: String) -> Array:
	var da := JSON.parse_string(a) as Dictionary
	var db := JSON.parse_string(b) as Dictionary
	var out: Array = []
	for k in da:
		if JSON.stringify(da[k], "", true) != JSON.stringify(db.get(k), "", true):
			out.append(k)
	for k in db:
		if not da.has(k):
			out.append(k)
	return out


func _sorted_flags() -> Array:
	var out: Array = GameState.story_flags.keys()
	out.sort()
	return out


func _json(v) -> String:
	return JSON.stringify(v, "", true)


## Save zonder tijdstempels (die verschillen per save, de rest niet).
func _content(path: String) -> String:
	var d := GameState._read_save_file(path)
	for k in ["saved_at", "saved_unix", "play_time"]:
		d.erase(k)
	return _json(d)


func _wacht_preload() -> void:
	var t := 0.0
	while not GameState._preloading.is_empty() and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()


# ---------------------------------------------------------------- run
func _run() -> void:
	await _wacht_preload()
	var orig_autosave := Settings.autosave_enabled()
	var orig_style = Settings.get_value("battle_style")
	print("=== Deel A: round-trip op WM1-momenten ===")
	_roundtrip_tests()
	print("=== Deel B: kapotte saves ===")
	_corruption_tests()
	print("=== Deel D: snel / dubbel opslaan ===")
	_double_save_tests()
	print("=== Deel E: oudere en nieuwere save-versie ===")
	_version_tests()
	print("=== Deel C: pauze/hervat in menu, dialoog en gevecht ===")
	var pause := PausePart.new()
	pause.name = "SaveStressPause"
	pause.check_cb = check
	add_child(pause)
	await pause.run()
	Settings.set_value("autosave", orig_autosave)
	Settings.set_value("battle_style", orig_style)
	for p in [RT, RT2, CORRUPT, DUBBEL, SNEL, OUD]:
		_remove_save(p)
	print("SAVESTRESSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- A: round-trip
func _roundtrip_tests() -> void:
	for m in F.moments():
		var naam := str(m["name"])
		var map := str(m["map"])
		var tile: Vector2i = m["tile"]
		var facing: Vector2i = m["facing"]
		F.apply_moment(m)
		_remove_save(RT)
		_remove_save(RT2)
		var saved := GameState.save_game(tile, facing, RT)
		check("[%s] save_game lukt" % naam, saved and _valid(RT) and _no_temp(RT))
		var before := _sig(tile, facing, map)
		var party_before := _json(GameState._party_save())
		var bench_before := _json(GameState._party_save_from(GameState.party_bench))
		var inv_before := _json(GameState.inventory)
		var gold_before := GameState.gold
		var step_before := GameState.story_step
		var flags_before := _sorted_flags()
		var leader_before := GameState.leader_id

		# alles wissen, dan laden
		GameState.new_game("Zed")
		GameState.gold = 1
		GameState.inventory = {}
		check("[%s] load_game lukt" % naam, GameState.load_game(RT) and GameState.last_load_notice == "")
		check("[%s] party gelijk (ids, level, exp, HP/MP, stats, uitrusting)" % naam,
				_json(GameState._party_save()) == party_before
				and _json(GameState._party_save_from(GameState.party_bench)) == bench_before
				and GameState.leader_id == leader_before)
		check("[%s] tas gelijk (%s)" % [naam, inv_before], _json(GameState.inventory) == inv_before)
		check("[%s] goud gelijk (%d)" % [naam, gold_before], GameState.gold == gold_before)
		var flags_after := _sorted_flags()
		var missing: Array = flags_before.filter(func(f): return not flags_after.has(f))
		var extra: Array = flags_after.filter(func(f): return not flags_before.has(f) and not MIGRATIE_VLAGGEN.has(f))
		check("[%s] verhaalstap %d en vlaggen gelijk (weg: %s, onverwacht erbij: %s)" % [naam, step_before, missing, extra],
				GameState.story_step == step_before and missing.is_empty() and extra.is_empty())
		check("[%s] positie gelijk (%s %s %s)" % [naam, map.get_file(), tile, facing],
				GameState.return_map == map and GameState.return_tile == tile and GameState.return_facing == facing
				and GameState.has_return_point)
		check("[%s] na laden niet in gevecht, niet alleen-lezen" % naam,
				not GameState.in_battle and not GameState.save_readonly)
		var after := _sig(tile, facing, map)
		var verschil := _diff(before, after)
		check("[%s] volledige staat gelijk, op migratievlaggen na (verschil: %s)" % [naam, verschil],
				verschil.is_empty() or verschil == ["story"])

		# tweede round-trip: opslaan wat er geladen is moet exact hetzelfde opleveren
		GameState.save_game(GameState.return_tile, GameState.return_facing, RT2)
		var sig1 := _sig(tile, facing, map)
		GameState.new_game("Zed")
		GameState.load_game(RT2)
		var sig2 := _sig(tile, facing, map)
		check("[%s] tweede round-trip byte-gelijk (verschil: %s)" % [naam, _diff(sig1, sig2)], sig1 == sig2)
		check("[%s] save-inhoud stabiel: opnieuw opslaan geeft dezelfde inhoud" % naam,
				GameState.save_game(GameState.return_tile, GameState.return_facing, RT2)
				and _content(RT2) == _content(RT2 + ".bak"))
	_remove_save(RT)
	_remove_save(RT2)


# ---------------------------------------------------------------- B: kapotte saves
func _corrupt_variants(good: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := good.size()
	out.append({"name": "leeg bestand (0 bytes)", "bytes": PackedByteArray()})
	out.append({"name": "alleen witruimte", "bytes": " \n\t \n".to_utf8_buffer()})
	var nul := PackedByteArray()
	nul.resize(n)
	out.append({"name": "alleen nul-bytes (blok niet geschreven)", "bytes": nul})
	for frac in [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99]:
		var cut := int(float(n) * float(frac))
		out.append({"name": "afgekapt op %d%% (%d/%d bytes)" % [int(float(frac) * 100.0), cut, n], "bytes": good.slice(0, cut)})
	out.append({"name": "laatste byte weg", "bytes": good.slice(0, n - 1)})
	var half := good.duplicate()
	for i in range(n / 2, n):
		half[i] = 0
	out.append({"name": "half geschreven (2e helft nul-bytes)", "bytes": half})
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for k in 24:
		var b := good.duplicate()
		var flips := rng.randi_range(1, 8)
		for j in flips:
			b[rng.randi_range(0, n - 1)] = rng.randi_range(0, 255)
		out.append({"name": "willekeurig beschadigd #%02d (%d bytes)" % [k, flips], "bytes": b})
	var junk := PackedByteArray()
	junk.resize(512)
	for i in 512:
		junk[i] = rng.randi_range(0, 255)
	out.append({"name": "willekeurige rommel (512 bytes)", "bytes": junk})
	for t in ["[]", "null", "{}", "\"save\"", "{\"map\": 5, \"party\": []}", "{\"gold\": 999999}"]:
		out.append({"name": "geldige JSON, geen save: %s" % t, "bytes": str(t).to_utf8_buffer()})
	return out


func _corruption_tests() -> void:
	_remove_save(CORRUPT)
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.gold = 777
	GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, CORRUPT)
	GameState.gold = 888
	GameState.save_game(Vector2i(4, 5), Vector2i.UP, CORRUPT)
	check("opzet: hoofd-save goud 888, reservekopie goud 777",
			_gold_in(CORRUPT) == 888 and _gold_in(CORRUPT + ".bak") == 777)
	var good_main := _bytes(CORRUPT)
	var good_bak := _bytes(CORRUPT + ".bak")

	# 1) kapotte hoofd-save + goede reservekopie
	var bad_load: Array = []
	var bad_after_save: Array = []
	var recovered := 0
	var variants := _corrupt_variants(good_main)
	for v in variants:
		var vnaam := str(v["name"])
		_remove_save(CORRUPT)
		_write_bytes(CORRUPT, v["bytes"])
		_write_bytes(CORRUPT + ".bak", good_bak)
		var main_still_valid := _valid(CORRUPT)
		GameState.new_game("Zed")
		GameState.gold = 5
		var ok := GameState.load_game(CORRUPT)
		var good: bool
		if main_still_valid:
			# een bitflip in witruimte of tekst kan geldige JSON laten: dan geldt de hoofd-save (opgeschoond)
			good = ok and GameState.last_load_notice == "" and not GameState.party.is_empty() \
					and GameState.gold >= 0 and GameState.gold <= GameState.MAX_GOLD
		else:
			good = ok and GameState.gold == 777 and GameState.last_load_notice == GameState.NOTICE_RECOVERED
			if good:
				recovered += 1
		if not good:
			bad_load.append(vnaam)
		# daarna opslaan: nooit een kapot bestand als reservekopie, en een goede .bak blijft goed
		GameState.gold = 999
		var readonly := GameState.save_readonly      # bitflip in "version" -> 'nieuwere save': niet overschrijven
		var main_voor := _bytes(CORRUPT)
		var saved := GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, CORRUPT)
		var bak_ok := _valid(CORRUPT + ".bak")
		if not main_still_valid:
			bak_ok = bak_ok and _gold_in(CORRUPT + ".bak") == 777
		var after_ok: bool
		if readonly:
			after_ok = not saved and _bytes(CORRUPT) == main_voor and bak_ok
		else:
			after_ok = saved and _gold_in(CORRUPT) == 999 and bak_ok and _no_temp(CORRUPT)
		if not after_ok:
			bad_after_save.append(vnaam)
	check("%d kapotte varianten: laden crasht niet en geeft de .bak of de (nog geldige) hoofd-save (%d hersteld; misser: %s)"
			% [variants.size(), recovered, bad_load], bad_load.is_empty())
	check("%d kapotte varianten: opslaan daarna lukt, hoofd-save goud 999, .bak blijft de goede 777 (misser: %s)"
			% [variants.size(), bad_after_save], bad_after_save.is_empty())
	check("de meeste varianten testen echt het herstelpad (%d van %d)" % [recovered, variants.size()],
			recovered >= variants.size() - 12)

	# 2) kapotte hoofd-save zonder reservekopie: nette melding, staat en bestand onaangeroerd
	var no_bak_bad: Array = []
	for i in [0, 3, 6, 10, variants.size() - 7]:
		var v: Dictionary = variants[i]
		_remove_save(CORRUPT)
		_write_bytes(CORRUPT, v["bytes"])
		if _valid(CORRUPT):
			continue
		GameState.new_game("Zed")
		GameState.gold = 5
		GameState.set_item_count("drankje", 2)
		var ok := GameState.load_game(CORRUPT)
		if ok or GameState.last_load_notice != GameState.NOTICE_UNREADABLE or GameState.gold != 5 \
				or GameState.item_count("drankje") != 2 or _bytes(CORRUPT) != (v["bytes"] as PackedByteArray):
			no_bak_bad.append(str(v["name"]))
	check("geen .bak: load_game false + 'can't be read', huidige staat en kapot bestand onaangeroerd (misser: %s)" % [no_bak_bad],
			no_bak_bad.is_empty())
	_remove_save(CORRUPT)
	_write(CORRUPT, "")
	GameState.new_game("Zed")
	check("geen .bak, leeg bestand: read_save geeft {} en de titel-check (has_any_save) crasht niet",
			GameState.read_save(CORRUPT).is_empty() and (GameState.has_any_save() or true))

	# 3) goede hoofd-save + kapotte reservekopie: hoofd-save laadt, volgende save herstelt de .bak
	_remove_save(CORRUPT)
	_write_bytes(CORRUPT, good_main)
	_write(CORRUPT + ".bak", "{\"map\":")
	GameState.new_game("Zed")
	check("kapotte .bak, goede hoofd-save: laadt goud 888 zonder herstelmelding",
			GameState.load_game(CORRUPT) and GameState.gold == 888 and GameState.last_load_notice == "")
	GameState.gold = 1000
	check("kapotte .bak: volgende save maakt een geldige .bak van de vorige goede save (888)",
			GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, CORRUPT)
			and _gold_in(CORRUPT) == 1000 and _gold_in(CORRUPT + ".bak") == 888)

	# 4) achtergebleven tijdelijke bestanden (proces gestopt midden in een save)
	_remove_save(CORRUPT)
	_write_bytes(CORRUPT, good_main)
	_write_bytes(CORRUPT + ".bak", good_bak)
	_write_bytes(CORRUPT + ".tmp", good_main.slice(0, good_main.size() / 3))
	_write_bytes(CORRUPT + ".bak.tmp", good_bak.slice(0, 10))
	GameState.new_game("Zed")
	check("halve .tmp en .bak.tmp naast een goede save: hoofd-save laadt (888), tijdelijke bestanden opgeruimd",
			GameState.load_game(CORRUPT) and GameState.gold == 888 and GameState.last_load_notice == ""
			and _no_temp(CORRUPT))
	# een volledige .tmp die nooit hernoemd werd: de oude hoofd-save blijft de waarheid
	GameState.gold = 4444
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, RT)
	_write_bytes(CORRUPT, good_main)
	_write_bytes(CORRUPT + ".tmp", _bytes(RT))
	GameState.new_game("Zed")
	check("volledige maar niet hernoemde .tmp: de laatste echte save (888) laadt, .tmp opgeruimd",
			GameState.load_game(CORRUPT) and GameState.gold == 888 and not FileAccess.file_exists(CORRUPT + ".tmp"))
	_remove_save(RT)

	# 5) beide kapot: nette melding, geen crash, niets overschreven
	_remove_save(CORRUPT)
	_write(CORRUPT, "garbage")
	_write(CORRUPT + ".bak", "{}")
	GameState.new_game("Zed")
	GameState.gold = 5
	check("hoofd-save en .bak kapot: load_game false, melding, goud blijft 5",
			not GameState.load_game(CORRUPT) and GameState.last_load_notice == GameState.NOTICE_UNREADABLE
			and GameState.gold == 5)
	check("hoofd-save en .bak kapot: bestanden niet stil vervangen", _bytes(CORRUPT) == "garbage".to_utf8_buffer()
			and _bytes(CORRUPT + ".bak") == "{}".to_utf8_buffer())
	_remove_save(CORRUPT)


# ---------------------------------------------------------------- D: snel / dubbel opslaan
func _base_state(gold: int) -> void:
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.story_step = StoryData.KLAAR
	GameState.gold = gold
	GameState.set_item_count("drankje", 4)
	GameState.set_item_count("toverwater", 2)


func _double_save_tests() -> void:
	var t := Vector2i(3, 3)
	var f := Vector2i.DOWN

	# 1) twee saves in hetzelfde frame, toestand verandert ertussen
	_remove_save(DUBBEL)
	_base_state(100)
	var s1 := GameState.save_game(t, f, DUBBEL)
	GameState.gold = 200
	var s2 := GameState.save_game(t, f, DUBBEL)
	check("2x opslaan in één frame: beide lukken, laatste wint (200), .bak = vorige (100), geen .tmp",
			s1 and s2 and _gold_in(DUBBEL) == 200 and _gold_in(DUBBEL + ".bak") == 100 and _no_temp(DUBBEL))

	# 2) twee keer exact dezelfde toestand
	_remove_save(DUBBEL)
	_base_state(300)
	GameState.save_game(t, f, DUBBEL)
	GameState.save_game(t, f, DUBBEL)
	check("2x dezelfde toestand: hoofd-save en .bak hebben dezelfde inhoud (op tijdstempels na)",
			_valid(DUBBEL) and _content(DUBBEL) == _content(DUBBEL + ".bak"))
	GameState.new_game("Zed")
	GameState.load_game(DUBBEL)
	GameState.load_game(DUBBEL)
	check("2x opslaan + 2x laden: goud 300, 4 drankjes, 2 toverwater (niets dubbel)",
			GameState.gold == 300 and GameState.item_count("drankje") == 4 and GameState.item_count("toverwater") == 2)

	# 3) re-entrant: een save die binnen game_saved van een andere save start (zelfde bestand + autosave)
	_remove_save(DUBBEL)
	_base_state(500)
	GameState.sync_autosave_path()
	var auto := GameState.autosave_path
	_remove_save(auto)
	var depth := [0]
	var nested_ok := [false, false]
	var on_saved := func(p: String, _ok: bool) -> void:
		if depth[0] == 0 and p == DUBBEL:
			depth[0] = 1
			nested_ok[0] = GameState.save_game(t, f, DUBBEL)
			nested_ok[1] = GameState.autosave(t, f, "achtergrond")
			depth[0] = 2
	GameState.game_saved.connect(on_saved)
	var outer := GameState.save_game(t, f, DUBBEL)
	GameState.game_saved.disconnect(on_saved)
	check("save binnen een save (re-entrant): alle drie lukken (buiten %s, binnen %s)" % [outer, nested_ok],
			outer and nested_ok[0] and nested_ok[1])
	check("re-entrant: hoofd-save, .bak en autosave geldig, goud 500 in alle drie, geen .tmp",
			_gold_in(DUBBEL) == 500 and _gold_in(DUBBEL + ".bak") == 500 and _gold_in(auto) == 500
			and _no_temp(DUBBEL) and _no_temp(auto))
	GameState.new_game("Zed")
	GameState.load_game(DUBBEL)
	GameState.load_game(auto)
	check("re-entrant: handmatig + autosave na elkaar laden geeft goud 500 en 4 drankjes (geen optelling)",
			GameState.gold == 500 and GameState.item_count("drankje") == 4)

	# 4) handmatig opslaan terwijl een autosave bezig is (binnen game_saved van de autosave)
	_base_state(600)
	_remove_save(auto)
	_remove_save(DUBBEL)
	var manual_ok := [false]
	var on_auto := func(p: String, _ok: bool) -> void:
		if p == auto and not manual_ok[0]:
			GameState.add_gold(50)
			manual_ok[0] = GameState.save_game(t, f, DUBBEL)
	GameState.game_saved.connect(on_auto)
	var auto_ok := GameState.autosave(t, f, "achtergrond")
	GameState.game_saved.disconnect(on_auto)
	check("opslaan tijdens een autosave: beide lukken, autosave 600, handmatig 650",
			auto_ok and manual_ok[0] and _gold_in(auto) == 600 and _gold_in(DUBBEL) == 650
			and _no_temp(auto) and _no_temp(DUBBEL))
	GameState.new_game("Zed")
	GameState.load_game(DUBBEL)
	check("opslaan tijdens een autosave: handmatige save laadt 650 goud, 4 drankjes",
			GameState.gold == 650 and GameState.item_count("drankje") == 4)

	# 5) handmatig + pauze-save in hetzelfde frame (menu 'Save' en de app gaat net naar de achtergrond)
	_base_state(700)
	_remove_save(auto)
	_remove_save(DUBBEL)
	var a1 := GameState.save_game(t, f, DUBBEL)
	var a2 := GameState.autosave(t, f, "achtergrond")
	var a3 := GameState.save_game(t, f, DUBBEL)
	check("handmatig + pauze-save + handmatig in één frame: alles geldig, overal 700 goud",
			a1 and a2 and a3 and _gold_in(DUBBEL) == 700 and _gold_in(DUBBEL + ".bak") == 700 and _gold_in(auto) == 700)

	# 6) 25 saves direct achter elkaar, met een wijziging ertussen
	_remove_save(SNEL)
	_base_state(0)
	var all_ok := true
	for i in 25:
		GameState.add_gold(1)
		GameState.add_item("drankje", 1)
		all_ok = GameState.save_game(t, f, SNEL) and all_ok
	var d := GameState._read_save_file(SNEL)
	var inv: Dictionary = d.get("inventory", {}) if d.get("inventory") is Dictionary else {}
	check("25 saves achter elkaar: alle gelukt, bestand geldig, goud 25, drankjes 29, .bak = vorige (24)",
			all_ok and _valid(SNEL) and _gold_in(SNEL) == 25 and int(inv.get("drankje", -1)) == 29
			and _gold_in(SNEL + ".bak") == 24 and _no_temp(SNEL))
	GameState.new_game("Zed")
	check("25 saves achter elkaar: laden geeft precies 25 goud en 29 drankjes",
			GameState.load_game(SNEL) and GameState.gold == 25 and GameState.item_count("drankje") == 29)
	_remove_save(SNEL)
	_remove_save(DUBBEL)
	_remove_save(auto)


# ---------------------------------------------------------------- E: versies
func _version_tests() -> void:
	check("SAVE_VERSION is %d (migratie gaat per sleutel, niet per versienummer)" % GameState.SAVE_VERSION,
			GameState.SAVE_VERSION >= 1)
	for variant in ["zonder version", "version 0"]:
		var old := F.old_save_v0()
		if variant == "version 0":
			old["version"] = 0
		_remove_save(OUD)
		_write(OUD, JSON.stringify(old))
		GameState.new_game("Zed")
		Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
		var ok := GameState.load_game(OUD)
		check("oude save (%s) laadt zonder melding en is niet alleen-lezen" % variant,
				ok and GameState.last_load_notice == "" and not GameState.save_readonly)
		check("oude save (%s): held 'ruben' wordt 'dennis', namen Dennis -> Dax" % variant,
				not GameState.party.is_empty() and str(GameState.party[0]["id"]) == "dennis"
				and str(GameState.party[0]["name"]) == "Dax" and GameState.player_name == "Dax")
		check("oude save (%s): goud 250, tas (3 drankjes, 1 toverwater) als gehele getallen" % variant,
				GameState.gold == 250 and GameState.item_count("drankje") == 3 and GameState.item_count("toverwater") == 1
				and typeof(GameState.inventory["drankje"]) == TYPE_INT)
		check("oude save (%s): verhaalstap TAKEN, vlag water_klaar, positie (5,6) omlaag" % variant,
				GameState.story_step == StoryData.TAKEN and GameState.story_flags.has("water_klaar")
				and GameState.return_tile == Vector2i(5, 6) and GameState.return_facing == Vector2i(0, 1))
		check("oude save (%s): geen battle_style -> Classic, geen checkpoint" % variant,
				int(Settings.get_value("battle_style")) == Settings.BATTLE_STYLE_CLASSIC and GameState.checkpoint.is_empty())
		var tile := GameState.return_tile
		var facing := GameState.return_facing
		var map := GameState.return_map
		check("oude save (%s): opnieuw opslaan schrijft de huidige versie en names_v23" % variant,
				GameState.save_game(tile, facing, OUD)
				and int(GameState._read_save_file(OUD).get("version", -1)) == GameState.SAVE_VERSION
				and GameState._read_save_file(OUD).get(GameState.NAMES_KEY) == true)
		var sig1 := _sig(tile, facing, map)
		GameState.new_game("Zed")
		GameState.load_game(OUD)
		var sig2 := _sig(tile, facing, map)
		check("oude save (%s): na migratie is opslaan + laden stabiel (verschil: %s)" % [variant, _diff(sig1, sig2)],
				sig1 == sig2 and str(GameState.party[0]["name"]) == "Dax")

	# nieuwere versie dan deze build: laden mag, overschrijven niet
	_base_state(321)
	_remove_save(OUD)
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, OUD)
	var newer := GameState._read_save_file(OUD)
	newer["version"] = GameState.SAVE_VERSION + 1
	newer["nieuw_veld_uit_de_toekomst"] = {"x": [1, 2, 3]}
	_write(OUD, JSON.stringify(newer))
	var before := _bytes(OUD)
	GameState.new_game("Zed")
	check("nieuwere save-versie laadt (goud 321) en wordt alleen-lezen",
			GameState.load_game(OUD) and GameState.gold == 321 and GameState.save_readonly)
	GameState.gold = 1
	check("nieuwere save-versie: save_game weigert en het bestand blijft byte-gelijk",
			not GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, OUD) and _bytes(OUD) == before)
	GameState.sync_autosave_path()
	check("nieuwere save-versie: pauze-save weigert ook", not GameState.autosave(Vector2i(1, 1), Vector2i.DOWN, "achtergrond"))
	GameState.new_game("Zed")
	check("new_game heft alleen-lezen weer op", not GameState.save_readonly)
	_remove_save(OUD)
