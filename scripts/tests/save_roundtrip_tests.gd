extends Node
## Opslaan en laden van game_state.gd: party, castjoin-leden (later bijgekomen helden, ook op de
## reservebank), goud en inventaris komen na save + load identiek terug; corrupte savebestanden
## laten het spel niet crashen.
## Start: godot --path . -- --saveroundtriptest

const Equipment := preload("res://scripts/equipment.gd")
const SAVE := "user://saveroundtriptest_rt.json"
const MAP := "res://scenes/maps/wilgendal.tscn"

var failures := 0
var passes := 0
## Stap-teller: een scriptfout midden in een stap breekt _run af; de waakhond meldt dan waar.
var _stap := "start"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 120 s (laatste stap: %s)" % _stap, false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


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


## Diep vergelijken; getallen tellen op waarde (JSON maakt van elk int een float).
## Geeft "" bij gelijk, anders het pad van het eerste verschil.
static func diff(a, b, pad := "") -> String:
	var a_num := a is int or a is float
	var b_num := b is int or b is float
	if a_num or b_num:
		return "" if a_num and b_num and float(a) == float(b) else "%s: %s != %s" % [pad, a, b]
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				return "%s.%s ontbreekt na laden" % [pad, k]
			var d := diff(a[k], b[k], "%s.%s" % [pad, k])
			if d != "":
				return d
		for k in b:
			if not a.has(k):
				return "%s.%s is extra na laden" % [pad, k]
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: lengte %d != %d" % [pad, a.size(), b.size()]
		for i in a.size():
			var d := diff(a[i], b[i], "%s[%d]" % [pad, i])
			if d != "":
				return d
		return ""
	if typeof(a) != typeof(b) or a != b:
		return "%s: %s != %s" % [pad, a, b]
	return ""


func _check_same(label: String, voor, na) -> void:
	var d := diff(voor, na, label)
	check("%s identiek na save + load%s" % [label, "" if d == "" else " (" + d + ")"], d == "")


func _ids(groep: Array) -> Array:
	return groep.map(func(h): return str(h.get("id", "")))


## Een spel met afwijkende waarden: castjoin-leden (actief én op de bank), uitrusting, levels,
## beschadigde hp/mp, goud en een gemengde tas.
func _bouw_staat() -> void:
	GameState.new_game("Dax")
	GameState.current_map = MAP
	for id in ["noor", "kael", "orion", "lotte"]:
		GameState.add_member(id)
	GameState.inventory = {"toverwater": 3, "elixer": 1, "feniksveer": 12, "kort_zwaard": 2,
			"houten_schild": 1, "leren_kap": 1, "eiken_staf": 1}
	GameState.gold = 12345
	var dax: Dictionary = GameState.party[0]
	Equipment.equip(dax, GameState.inventory, "wapen", "kort_zwaard")
	Equipment.equip(dax, GameState.inventory, "schild", "houten_schild")
	var noor: Dictionary = GameState.party[1]
	Equipment.equip(noor, GameState.inventory, "wapen", "eiken_staf")
	Equipment.equip(noor, GameState.inventory, "helm", "leren_kap")
	var nr := 0
	for h in GameState.party + GameState.party_bench:
		nr += 1
		h["level"] = 3 + nr
		h["exp"] = 100 * nr
		h["hp"] = maxi(1, int(h["max_hp"]) - 2 * nr)
		h["mp"] = maxi(0, int(h["max_mp"]) - nr)
	GameState.leader_id = "noor"


func _run() -> void:
	GameState._finish_preload()
	GameState.encounter_multiplier = 0.0

	# ---- 1. Volledige ronde: save -> ander spel -> load ----
	_stap = "roundtrip"
	_remove_save(SAVE)
	_bouw_staat()
	check("opzet: party is vol (4) met castjoin-leden",
			GameState.party.size() == 4 and _ids(GameState.party).has("noor"))
	check("opzet: castjoin-lid Seren staat op de reservebank",
			_ids(GameState.party_bench) == ["lotte"])
	var party_voor: Array = GameState.party.duplicate(true)
	var bank_voor: Array = GameState.party_bench.duplicate(true)
	var party_save_voor: Array = GameState._party_save()
	var bank_save_voor: Array = GameState._party_save_from(GameState.party_bench)
	var inv_voor: Dictionary = GameState.inventory.duplicate(true)
	var goud_voor: int = GameState.gold
	var leider_voor: String = GameState.leader_id
	check("save lukt", GameState.save_game(Vector2i(5, 6), Vector2i.LEFT, SAVE))

	GameState.new_game("Other")
	GameState.gold = 1
	GameState.inventory = {"elixer": 99}
	check("na new_game is de staat echt anders",
			GameState.party.size() == 1 and GameState.gold == 1)

	check("load lukt", GameState.load_game(SAVE))
	check("geen herstel-melding bij een goede save", GameState.last_load_notice == "")
	check("party-volgorde gelijk", _ids(GameState.party) == _ids(party_voor))
	check("reservebank-volgorde gelijk", _ids(GameState.party_bench) == _ids(bank_voor))
	_check_same("party (save-velden)", party_save_voor, GameState._party_save())
	_check_same("reservebank (save-velden)", bank_save_voor, GameState._party_save_from(GameState.party_bench))
	_check_same("party (volledige held)", party_voor, GameState.party)
	_check_same("reservebank (volledige held)", bank_voor, GameState.party_bench)
	_check_same("inventaris", inv_voor, GameState.inventory)
	check("inventaris-aantallen zijn int (geen float uit JSON)",
			GameState.inventory.values().all(func(v): return v is int))
	check("goud gelijk (%d)" % GameState.gold, GameState.gold == goud_voor)
	check("leider gelijk", GameState.leader_id == leider_voor)
	check("uitrusting Dax terug", Equipment.equipped(GameState.party[0], "wapen") == "kort_zwaard"
			and Equipment.equipped(GameState.party[0], "schild") == "houten_schild")
	check("uitrusting castjoin-lid Vesper terug", Equipment.equipped(GameState.party[1], "wapen") == "eiken_staf"
			and Equipment.equipped(GameState.party[1], "helm") == "leren_kap")
	check("terugkeerpunt uit de save", GameState.return_map == MAP
			and GameState.return_tile == Vector2i(5, 6) and GameState.return_facing == Vector2i.LEFT)

	# ---- 2. Tweede ronde: laden + opnieuw opslaan verandert niets ----
	_stap = "tweede ronde"
	var eerste := GameState._read_save_file(SAVE)
	check("tweede save lukt", GameState.save_game(Vector2i(5, 6), Vector2i.LEFT, SAVE))
	var tweede := GameState._read_save_file(SAVE)
	for k in ["party", "party_bank", "inventory", "gold", "leader"]:
		_check_same("bestand '%s' (save -> load -> save)" % k, eerste.get(k), tweede.get(k))

	# ---- 3. Castjoin na het laden: nieuw lid komt mee in de volgende save ----
	_stap = "castjoin na laden"
	GameState.new_game("Dax")
	GameState.current_map = MAP
	GameState.gold = 7
	check("save met alleen Dax lukt", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE))
	check("load met alleen Dax", GameState.load_game(SAVE) and _ids(GameState.party) == ["dennis"])
	check("castjoin Vesper na laden", GameState.add_member("noor"))
	check("save na castjoin lukt", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE))
	GameState.new_game("Dax")
	check("castjoin-lid Vesper overleeft save + load",
			GameState.load_game(SAVE) and _ids(GameState.party) == ["dennis", "noor"])
	check("castjoin-lid niet dubbel toe te voegen na laden", not GameState.add_member("noor"))

	# ---- 4. Corrupte savebestanden: niet crashen, niet half laden ----
	_stap = "corrupt"
	_bouw_staat()
	var gezond_goud: int = GameState.gold
	var gezonde_ids := _ids(GameState.party)
	var corrupt := {
		"leeg bestand": "",
		"afgekapt": "{\"map\": \"res://x.tscn\", \"party\": [{\"id\": \"den",
		"geen JSON": "dit is geen save",
		"JSON-lijst": "[1, 2, 3]",
		"JSON null": "null",
		"getal": "42",
		"party is tekst": "{\"map\": \"%s\", \"party\": \"dennis\"}" % MAP,
		"map is getal": "{\"map\": 5, \"party\": []}",
	}
	for naam in corrupt:
		_stap = "corrupt: " + naam
		_remove_save(SAVE)
		_write(SAVE, corrupt[naam])
		var ok := GameState.load_game(SAVE)
		check("corrupt (%s): load_game geeft false" % naam, not ok)
		check("corrupt (%s): melding voor de speler" % naam,
				GameState.last_load_notice == GameState.NOTICE_UNREADABLE)
		check("corrupt (%s): lopend spel onaangetast" % naam,
				GameState.gold == gezond_goud and _ids(GameState.party) == gezonde_ids)
		check("corrupt (%s): read_save is leeg" % naam, GameState.read_save(SAVE).is_empty())

	_stap = "corrupt: binair"
	_remove_save(SAVE)
	var rommel := PackedByteArray()
	for i in 512:
		rommel.append((i * 73 + 11) % 256)
	_write_bytes(SAVE, rommel)
	check("corrupt (binair): load_game geeft false", not GameState.load_game(SAVE))
	check("corrupt (binair): lopend spel onaangetast",
			GameState.gold == gezond_goud and _ids(GameState.party) == gezonde_ids)

	# Geldige vorm, kapotte velden: laden lukt met standaardwaarden, zonder scriptfout.
	_stap = "kapotte velden"
	_remove_save(SAVE)
	var kapot := {
		"map": MAP, "tile": "x", "facing": [1],
		"party": [{"id": "dennis", "level": "tien", "hp": [], "max_hp": -5, "spells": "geen",
				"equip": {"wapen": 12, "schild": "bestaat_niet"}, "base": "x"},
				{"id": 404}, "geen held", null, {"id": "noor", "level": 1e30, "exp": -3}],
		"party_bank": {"id": "lotte"},
		"gold": "veel", "inventory": ["elixer"], "leader": 7, "story": [], "codex": "x",
		"dungeon100": [], "koopman": 3, "kernen": "x", "uniek": [], "archief2": {"platen": []},
		"bezocht": "x", "puzzle_latched": [], "play_time": "x", "bestiary": [1],
		"quests": "x", "scenes_seen": {}, "heard_music": 5, "checkpoint": [], "slot": "x",
	}
	_write(SAVE, JSON.stringify(kapot))
	check("kapotte velden: load_game lukt toch", GameState.load_game(SAVE))
	check("kapotte velden: party bruikbaar (Dax + Vesper)", _ids(GameState.party) == ["dennis", "noor"])
	var dax: Dictionary = GameState.party[0]
	check("kapotte velden: hp/max_hp/level geldig",
			int(dax["max_hp"]) >= 1 and int(dax["hp"]) >= 0 and int(dax["hp"]) <= int(dax["max_hp"])
			and int(dax["level"]) >= 1 and dax["spells"] is Array)
	check("kapotte velden: belachelijk level wordt geen negatief getal",
			int(GameState.party[1]["level"]) >= 1 and int(GameState.party[1]["exp"]) >= 0)
	check("kapotte velden: goud 0, tas leeg (geen spook-uitrusting), bank leeg, leider = hoofdheld",
			GameState.gold == 0 and GameState.inventory.is_empty() and GameState.party_bench.is_empty()
			and GameState.leader_id == GameState.MAIN_HERO)
	check("kapotte velden: opnieuw opslaan lukt", GameState.save_game(Vector2i(2, 2), Vector2i.DOWN, SAVE))

	# Corrupte hoofd-save met een goede reservekopie: die wordt geladen.
	_stap = "reservekopie"
	_remove_save(SAVE)
	_bouw_staat()
	GameState.gold = 111
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE)
	GameState.gold = 222
	GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE)
	_write(SAVE, "{\"party\": [")
	GameState.new_game("Dax")
	check("corrupte hoofd-save: reservekopie geladen",
			GameState.load_game(SAVE) and GameState.gold == 111
			and GameState.last_load_notice == GameState.NOTICE_RECOVERED)
	check("corrupte hoofd-save: castjoin-leden uit de reservekopie",
			_ids(GameState.party).size() == 4 and _ids(GameState.party_bench) == ["lotte"])

	# Slotlijst met een corrupt slot crasht niet.
	_stap = "slotlijst"
	var oud_pad: String = GameState.save_path
	GameState.save_path = SAVE
	_remove_save(SAVE)
	_write(SAVE, "{kapot")
	var rec := GameState.slot_record(1)
	check("slotlijst: corrupt slot herkend (niet stil leeg)", bool(rec.get("corrupt", false)))
	GameState.save_path = oud_pad
	_remove_save(SAVE)

	_stap = "klaar"
	print("SAVEROUNDTRIPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 5:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
