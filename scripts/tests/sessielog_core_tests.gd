extends Node
## SessieLog (scripts/core/sessie_log.gd): instelling (aan/uit/automatisch), events in het bestand
## (via de echte GameState-signals en Story), flush elke 10 s en bij app-pauze/afsluiten, max 2 MB,
## rotatie (max 5 bestanden) en tools/sessielog/samenvat.py met kapotte regels.
## Start: godot --path . -- --sessielogcoretest

const MAP := "user://sessielog_core_test"
const SAMENVAT_MAP := "user://sessielog_core_samenvat"
const SAVE := "user://sessielog_core_save.json"
const NAAM_RE := "^sessie_\\d{4}-\\d{2}-\\d{2}_\\d{6}(_\\d{2})?\\.jsonl$"

var failures := 0
var passes := 0
var sl: Node
var events_pad := ""


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _regels(p: String) -> Array:
	var uit: Array = []
	for r in FileAccess.get_file_as_string(p).split("\n", false):
		uit.append(JSON.parse_string(r))
	return uit


func _van_type(regels: Array, type: String) -> Array:
	return regels.filter(func(d): return d is Dictionary and str(d.get("type", "")) == type)


func _types(p: String) -> Array:
	return _regels(p).map(func(d): return str(d.get("type", "")) if d is Dictionary else "?")


func _leeg(map_pad: String) -> void:
	DirAccess.make_dir_recursive_absolute(map_pad)
	for f in DirAccess.get_files_at(map_pad):
		DirAccess.remove_absolute(map_pad.path_join(f))


func _wacht_scene(naam: String, timeout_ms := 15000) -> bool:
	var tot := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < tot:
		var s := get_tree().current_scene
		if s != null and s.name == naam and s.is_node_ready():
			return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _run() -> void:
	sl = get_node("/root/SessieLog")
	_uit_in_test()
	await _instelling()
	await _events()
	await _flush_en_pauze()
	_samenvat()
	_max_grootte()
	_rotatie()
	_leeg(MAP)
	_leeg(SAMENVAT_MAP)
	print("SESSIELOGCORETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- 1) uit in een test
func _uit_in_test() -> void:
	check("autoload SessieLog bestaat, staat in een test uit en volgt de instelling niet",
			sl != null and not sl.actief and not sl.volgt_instelling)
	# user://logs deelt de map met Godots eigen godot.log
	check("in een test: geen sessiebestand in user://logs",
			not Array(DirAccess.get_files_at(sl.MAP)).any(func(f): return str(f).begins_with(sl.PREFIX)))
	for s in ["battle_started", "battle_ended", "game_over", "game_saved", "game_loaded", "menu_opened"]:
		check("GameState heeft signal %s" % s, GameState.has_signal(s))


# ---------------------------------------------------------------- 2) instelling
func _instelling() -> void:
	check("Settings 'sessie_log' standaard -1 (automatisch)", int(Settings.DEFAULTS["sessie_log"]) == -1
			and int(Settings.get_value("sessie_log")) == -1)
	check("automatisch = aan in debug, uit in release (%s)" % OS.is_debug_build(),
			Settings.sessie_log_enabled() == OS.is_debug_build())
	check("waarde begrensd op -1..1", Settings._sanitize("sessie_log", 7) == 1 and Settings._sanitize("sessie_log", -9) == -1)
	_leeg(MAP)
	sl.map_pad = MAP
	sl.volgt_instelling = true
	Settings.set_value("sessie_log", 0)
	sl.pas_toe()
	await _frames(2)
	sl.noteer("menu_open", {"welk": "x"})
	sl.flush()
	check("uitgeschakeld: niet actief, geen bestand", not sl.actief and DirAccess.get_files_at(MAP).is_empty())
	Settings.set_value("sessie_log", 1)
	await _frames(2)
	check("aan via de instelling: actief, één bestand", sl.actief and DirAccess.get_files_at(MAP).size() == 1)
	var p: String = sl.pad
	Settings.set_value("sessie_log", 0)
	await _frames(2)
	var t := _types(p)
	check("weer uit: gestopt, eerste regel sessie_start, laatste sessie_stop", not sl.actief
			and t.size() >= 2 and t[0] == "sessie_start" and t[-1] == "sessie_stop")
	sl.volgt_instelling = false
	Settings.set_value("sessie_log", -1)
	check("na terugzetten op automatisch blijft hij (test) uit", not sl.actief)
	_leeg(MAP)


# ---------------------------------------------------------------- 3) events
func _events() -> void:
	GameState.player_name = "Testnaam Geheim"
	check("start() lukt", sl.start())
	events_pad = sl.pad
	check("bestandsnaam sessie_<datum>_<tijd>.jsonl in de logmap (%s)" % events_pad.get_file(),
			events_pad.get_base_dir() == MAP and RegEx.create_from_string(NAAM_RE).search(events_pad.get_file()) != null)
	var r := _regels(events_pad)
	check("sessie_start staat meteen op schijf", r.size() == 1 and r[0] is Dictionary and r[0]["type"] == "sessie_start")
	if r.size() >= 1 and r[0] is Dictionary:
		var d: Dictionary = r[0]
		check("regel = {t, type, scene, data}", d.keys() == ["t", "type", "scene", "data"] and d["data"] is Dictionary)
		check("sessie_start: versie + modus Classic/Action", str(d["data"].get("versie", "")) != ""
				and str(d["data"].get("modus", "")) in ["Classic", "Action"])

	GameState.menu_opened.emit("Status")
	check("save via GameState.save_game", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, SAVE))
	check("load via GameState.load_game", GameState.load_game(SAVE))
	check("mislukte load wordt ook gemeld", not GameState.load_game("user://bestaat_niet.json"))

	Story.event_finished.emit("mantel_aan")
	await _frames(3)

	sl._laatste_activiteit = sl._nu() - 30.0
	sl._activiteit()

	for h in GameState.party:
		h["hp"] = int(h["max_hp"])
	GameState.current_map = "res://scenes/maps/wereldkaart.tscn"
	GameState.start_battle(["glitchmot"], Vector2i(5, 5), Vector2i.DOWN)
	check("gevechtsscène geladen", await _wacht_scene("Battle"))
	await _frames(5)
	GameState.party[0]["hp"] = int(GameState.party[0]["max_hp"]) / 2
	await GameState.end_battle("lose")
	await _frames(5)
	sl.flush()

	r = _regels(events_pad)
	check("alle regels zijn geldige JSON", r.all(func(d): return d is Dictionary))
	var m := _van_type(r, "menu_open")
	check("menu_open (welk)", m.size() == 1 and m[0]["data"]["welk"] == "Status")
	var s := _van_type(r, "save")
	check("save: bestandsnaam + ok", s.size() == 1 and s[0]["data"]["bestand"] == SAVE.get_file() and s[0]["data"]["ok"] == true)
	var l := _van_type(r, "load")
	check("load: gelukt en mislukt", l.size() == 2 and l[0]["data"]["ok"] == true and l[1]["data"]["ok"] == false)
	var q := _van_type(r, "quest_update")
	check("quest_update na Story.event_finished (%s)" % [q], q.size() >= 1 and int(q[0]["data"]["stappen"]) >= 1)
	var st := _van_type(r, "stilstand")
	check("stilstand van ~30 s", st.size() == 1 and float(st[0]["data"]["secs"]) >= 29.0)
	var gs := _van_type(r, "gevecht_start")
	check("gevecht_start: vijanden, modus, party-HP%", gs.size() == 1 and gs[0]["data"]["vijanden"] == ["glitchmot"]
			and str(gs[0]["data"]["modus"]) in ["Classic", "Action"] and int(gs[0]["data"]["party_hp_pct"]) == 100)
	var ge := _van_type(r, "gevecht_einde")
	check("gevecht_einde: uitkomst, duur, beurten, party-HP%% (%s)" % [ge], ge.size() == 1
			and ge[0]["data"]["uitkomst"] == "lose" and float(ge[0]["data"]["duur"]) > 0.0
			and int(ge[0]["data"]["beurten"]) >= 0 and int(ge[0]["data"]["party_hp_pct"]) < 100
			and ge[0]["scene"] == "battle")
	var go := _van_type(r, "game_over")
	check("game_over met plek na echte nederlaag", go.size() == 1 and go[0]["data"]["plek"] == "wereldkaart")
	for h in GameState.party:
		h["hp"] = int(h["max_hp"])
	GameState.start_battle(["moskonijn"], Vector2i(2, 2), Vector2i.DOWN)
	check("vlucht-gevecht geladen", await _wacht_scene("Battle"))
	await _frames(5)
	await GameState.end_battle("flee")
	await _frames(5)
	sl.flush()
	r = _regels(events_pad)
	check("vluchten: geen extra game_over", _van_type(r, "game_over").size() == 1)
	get_tree().change_scene_to_file("res://scenes/maps/dorp_wilgendal.tscn")
	await _frames(40)
	sl.flush()
	r = _regels(events_pad)
	check("scene-wissel zonder nederlaag: nog steeds één game_over", _van_type(r, "game_over").size() == 1)
	var sw := _van_type(r, "scene_wissel")
	check("scene_wissel naar en van de gevechtsscène", sw.any(func(d): return d["data"]["naar"] == "battle")
			and sw.any(func(d): return d["data"]["van"] == "battle"))
	check("privacy: spelernaam staat nergens in het bestand",
			not FileAccess.get_file_as_string(events_pad).contains("Testnaam Geheim"))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)


# ---------------------------------------------------------------- 4) flush
func _flush_en_pauze() -> void:
	sl.flush()
	sl._volgende_flush_ms = Time.get_ticks_msec() + int(sl.FLUSH_SECS * 1000.0)
	GameState.menu_opened.emit("Timertest")
	await get_tree().create_timer(5.0, true, false, true).timeout
	check("na 5 s nog in de buffer (niet per regel naar schijf)",
			not FileAccess.get_file_as_string(events_pad).contains("Timertest") and sl.buffer.size() >= 1)
	await get_tree().create_timer(5.5, true, false, true).timeout
	check("na 10 s op schijf (flush-timer)", FileAccess.get_file_as_string(events_pad).contains("Timertest"))

	GameState.menu_opened.emit("Pauzetest")
	check("vóór de pauze niet op schijf", not FileAccess.get_file_as_string(events_pad).contains("Pauzetest"))
	sl.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var t := _types(events_pad)
	check("app-pauze: buffer meteen op schijf, laatste regel app_pauze",
			FileAccess.get_file_as_string(events_pad).contains("Pauzetest") and t[-1] == "app_pauze")
	sl.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check("app_hervat in de buffer", sl.buffer.size() == 1 and sl.buffer[0].contains("app_hervat"))
	sl.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	t = _types(events_pad)
	check("afsluiten (WM_CLOSE_REQUEST): gestopt, sessie_stop als laatste regel",
			not sl.actief and t[-1] == "sessie_stop")
	check("app_hervat op schijf vóór sessie_stop", t.rfind("app_hervat") >= 0 and t.rfind("app_hervat") < t.size() - 1)
	var n := FileAccess.get_file_as_string(events_pad).length()
	sl.noteer("menu_open", {"welk": "na stop"})
	sl.flush()
	check("na stop: noteer schrijft niets", FileAccess.get_file_as_string(events_pad).length() == n)


# ---------------------------------------------------------------- 5) samenvat.py
func _samenvat() -> void:
	_leeg(SAMENVAT_MAP)
	var kapot := SAMENVAT_MAP.path_join("sessie_2026-01-01_120000.jsonl")
	var f := FileAccess.open(kapot, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(events_pad))
	f.store_string("{kapotte regel\nniet eens json\n[1, 2]\n{\"t\": \"x\", \"type\": \"menu_open\"}\n{\"t\": 99999, \"ty")
	f.close()
	var script := ProjectSettings.globalize_path("res://tools/sessielog/samenvat.py")
	var out: Array = []
	var code := OS.execute("python3", [script, ProjectSettings.globalize_path(kapot)], out, true)
	if code == -1 or code == 127:
		print("SKIP  samenvat.py: python3 niet gevonden (code %d)" % code)
		return
	var tekst := "\n".join(out)
	print(tekst)
	check("samenvat.py: exit 0 ondanks kapotte regels", code == 0)
	check("samenvat.py: 5 regels overgeslagen", tekst.contains("overgeslagen (kapot/onbekend): 5"))
	check("samenvat.py: speeltijd per scene (battle)", tekst.contains("Speeltijd per scene:") and tekst.contains("  battle"))
	check("samenvat.py: gevechten met verlies", tekst.contains("verlies 1"))
	check("samenvat.py: game-over per plek", tekst.contains("Game-overs: 1") and tekst.contains("wereldkaart"))
	check("samenvat.py: langste stilstand", tekst.contains("Langste stilstand: 30s"))
	out = []
	code = OS.execute("python3", [script, ProjectSettings.globalize_path(SAMENVAT_MAP)], out, true)
	check("samenvat.py: ook een hele map", code == 0 and "\n".join(out).contains("sessie_2026-01-01_120000.jsonl"))


# ---------------------------------------------------------------- 6) max 2 MB
func _max_grootte() -> void:
	_leeg(MAP)
	sl.start()
	var groot := "x".repeat(992)
	for i in 2500:
		sl.noteer("menu_open", {"welk": groot, "i": i})
		if i % 200 == 0:
			sl.flush()
	check("na ~2,5 MB aan regels: vol", sl.vol and sl.bytes <= sl.MAX_BYTES)
	sl.stop()
	var p: String = sl.pad
	var grootte := FileAccess.open(p, FileAccess.READ).get_length()
	var t := _types(p)
	check("bestand <= 2 MB (%d bytes)" % grootte, grootte <= sl.MAX_BYTES and grootte > sl.MAX_BYTES - 64 * 1024)
	check("één log_vol-regel en sessie_stop als laatste", t.count("log_vol") == 1 and t[-1] == "sessie_stop")


# ---------------------------------------------------------------- 7) rotatie
func _rotatie() -> void:
	_leeg(MAP)
	var ander := FileAccess.open(MAP.path_join("godot.log"), FileAccess.WRITE)
	ander.store_string("engine-log")
	ander.close()
	var gemaakt: Array[String] = []
	for i in 7:
		sl.start()
		gemaakt.append(sl.pad)
		sl.stop()
	var lijst: Array[String] = sl.bestanden()
	check("na 7 sessies: precies 5 bestanden (%d)" % lijst.size(), lijst.size() == sl.MAX_BESTANDEN)
	check("de 2 oudste zijn weg, de 5 nieuwste staan er", not FileAccess.file_exists(gemaakt[0])
			and not FileAccess.file_exists(gemaakt[1]) and lijst == gemaakt.slice(2))
	var namen := {}
	for p in gemaakt:
		namen[p] = true
	check("elke sessie een eigen bestandsnaam", namen.size() == 7)
	check("rotatie laat andere bestanden (godot.log) staan", FileAccess.file_exists(MAP.path_join("godot.log")))
