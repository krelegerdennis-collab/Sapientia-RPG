extends Node
## Playtest-kit (WM1): SessieLog alleen in debug-builds, gebieden, tijd per gebied, doden, crash-detectie
## en tools/sessielog/playtest_rapport.py. Start: godot --path . -- --playtestkittest
## Een release-build wordt nagebootst met ReleaseFlags.debug_build_override = 0 (altijd teruggezet).

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const SessieLogScript := preload("res://scripts/core/sessie_log.gd")

const MAP := "user://playtestkit_log"
const MAP_RELEASE := "user://playtestkit_release"
const MAP_TOOL := "user://playtestkit_tool"
const MAP_TOOL_SCHOON := "user://playtestkit_tool_schoon"
const MAP_LEEG := "user://playtestkit_leeg"
const DEV_MAPS := ["archief_test", "kern_demo"]

var failures := 0
var passes := 0
var sl: Node


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _leeg(map_pad: String) -> void:
	DirAccess.make_dir_recursive_absolute(map_pad)
	for f in DirAccess.get_files_at(map_pad):
		DirAccess.remove_absolute(map_pad.path_join(f))


func _regels(p: String) -> Array:
	var uit: Array = []
	for r in FileAccess.get_file_as_string(p).split("\n", false):
		var d: Variant = JSON.parse_string(r)
		if d is Dictionary:
			uit.append(d)
	return uit


func _van_type(regels: Array, type: String) -> Array:
	return regels.filter(func(d): return str(d.get("type", "")) == type)


func _regel(t: float, type: String, data: Dictionary = {}, scene := "") -> String:
	return JSON.stringify({"t": t, "type": type, "scene": scene, "data": data}, "", false)


func _schrijf(p: String, regels: Array) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("\n".join(regels) + "\n")
	f.close()


func _run() -> void:
	sl = get_node("/root/SessieLog")
	var oud_override := ReleaseFlags.debug_build_override
	await _gebieden()
	await _debug_log()
	_crash_detectie()
	await _release()
	ReleaseFlags.debug_build_override = oud_override
	_rapport_tool()
	for m in [MAP, MAP_RELEASE, MAP_TOOL, MAP_TOOL_SCHOON, MAP_LEEG]:
		_leeg(m)
	print("PLAYTESTKITTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- 1) gebieden
func _gebieden() -> void:
	var lijst := PlaytestGebieden.gebieden()
	check("data/playtest_gebieden.json geladen (>= 10 gebieden)", lijst.size() >= 10)
	var ids: Array = lijst.map(func(g): return str(g.get("id", "")))
	check("gebied-id's uniek en niet leeg", _uniek(ids).size() == ids.size() and not ids.has(""))
	for want in ["wachtershuis", "wereldkaart", "wilgendal", "archief1", "esdoorn", "woud", "berggrot", "archief2", "hub", "diepe_grot"]:
		check("gebied %s bestaat" % want, ids.has(want))
	var cases := {
		"huis_wilgendal": "wachtershuis", "wilgendal": "wachtershuis", "wereldkaart": "wereldkaart",
		"dorp_wilgendal": "wilgendal", "wilgendal_binnen": "wilgendal",
		"archief_ingang": "archief1", "archief_golemhal": "archief1", "archief_puzzel": "archief1",
		"archief_2_v1_entree": "archief2", "archief_2_warper": "archief2", "leven_ingang": "archief2",
		"esdoorn": "esdoorn", "esdoorn_herberg": "esdoorn", "woud_rand": "woud", "woud_open_plek": "woud",
		"berggrot_mond": "berggrot", "berggrot_bouwplaats": "berggrot", "dungeon100": "diepe_grot",
		"hal": "hub", "echo_kamer": "hub", "bestaat_niet": "overig", "": "overig"}
	for k in cases:
		check("kaart '%s' -> %s" % [k, cases[k]], PlaytestGebieden.gebied_van(k) == cases[k])
	var ongedeeld: Array[String] = []
	for f in DirAccess.get_files_at("res://scenes/maps"):
		var naam := str(f).get_basename()
		if str(f).ends_with(".tscn") and not DEV_MAPS.has(naam) and PlaytestGebieden.gebied_van(naam) == "overig":
			ongedeeld.append(naam)
	check("elke WM1-kaart in scenes/maps hoort bij een gebied (ongedeeld: %s)" % [ongedeeld], ongedeeld.is_empty())
	await get_tree().process_frame


func _uniek(a: Array) -> Array:
	var d := {}
	for x in a:
		d[x] = true
	return d.keys()


# ---------------------------------------------------------------- 2) debug-build: logt kaarten, gevechten, doden
func _debug_log() -> void:
	ReleaseFlags.debug_build_override = 1
	_leeg(MAP)
	sl.map_pad = MAP
	GameState.current_map = ""
	check("debug-build: SessieLog.debug_build() is waar", sl.debug_build())
	check("debug-build: start() lukt", sl.start())
	var p: String = sl.pad
	GameState.current_map = "res://scenes/maps/huis_wilgendal.tscn"
	sl.kaart(GameState.current_map)
	sl._kaart_sinds_ms -= 5000
	GameState.current_map = "res://scenes/maps/wereldkaart.tscn"
	sl.kaart(GameState.current_map)
	sl.gevecht_start(["mosslijm"], false, "gras", Vector2i(3, 4))
	sl.gevecht_eind("win")
	sl.gevecht_start(["glitchmot"], false, "gras", Vector2i(3, 5))
	sl.gevecht_eind("lose")
	sl.dood("battle")
	sl._on_game_over(GameState.current_map)
	sl._kaart_sinds_ms -= 7000
	GameState.current_map = "res://scenes/maps/woud_pad.tscn"
	sl.kaart(GameState.current_map)
	sl._kaart_sinds_ms -= 3000
	sl.stop()
	var r := _regels(p)
	var kaarten := _van_type(r, "kaart")
	check("kaartregels dragen het WM1-gebied", kaarten.size() == 3 and kaarten[0]["data"].get("gebied_wm1") == "wachtershuis"
			and kaarten[1]["data"].get("gebied_wm1") == "wereldkaart" and kaarten[2]["data"].get("gebied_wm1") == "woud")
	check("kaartregel houdt de bestaande velden (kaart, stijl, hoe)", kaarten[0]["data"].has("kaart")
			and kaarten[0]["data"].has("stijl") and kaarten[0]["data"].has("hoe"))
	var kt := _van_type(r, "kaart_tijd")
	check("kaart_tijd per kaart met gebied (3 stuks)", kt.size() == 3 and kt[0]["data"].get("gebied_wm1") == "wachtershuis")
	check("kaart_tijd huis_wilgendal >= 5 s", float(kt[0]["data"]["secs"]) >= 5.0)
	var ge := _van_type(r, "gevecht_eind")
	check("2 gevechten: winst en verlies", ge.size() == 2 and ge[0]["data"]["resultaat"] == "win" and ge[1]["data"]["resultaat"] == "lose")
	var dood := _van_type(r, "dood")
	check("dood: kaart, gebied en reden", dood.size() == 1 and dood[0]["data"]["kaart"] == "wereldkaart"
			and dood[0]["data"]["gebied_wm1"] == "wereldkaart" and dood[0]["data"]["reden"] == "battle")
	check("game_over gelogd", _van_type(r, "game_over").size() == 1)
	var stop: Dictionary = _van_type(r, "sessie_stop")[0]
	var sv: Dictionary = stop["data"].get("samenvatting", {})
	check("sessie_stop heeft een samenvatting", not sv.is_empty())
	check("samenvatting: tijd per gebied", float(sv["gebied_secs"].get("wachtershuis", 0)) >= 5.0
			and float(sv["gebied_secs"].get("wereldkaart", 0)) >= 7.0 and float(sv["gebied_secs"].get("woud", 0)) >= 3.0)
	check("samenvatting: gevechten win 1, lose 1", int(sv["gevechten"].get("win", 0)) == 1 and int(sv["gevechten"].get("lose", 0)) == 1)
	check("samenvatting: 1 dood op wereldkaart, 1 game-over", int(sv["doden"].get("wereldkaart", 0)) == 1
			and int(sv["game_overs"].get("wereldkaart", 0)) == 1)
	check("samenvatting: geen crash in een nette sessie", int(sv["crashes"]) == 0)
	check("sessie_stop houdt build + duur", stop["data"].get("build") in ["debug", "release"] and stop["data"].has("duur"))
	var bytes := FileAccess.get_file_as_string(p).length()
	check("log is compact (< 20 KB voor deze sessie: %d)" % bytes, bytes < 20000)
	await _frames(1)


# ---------------------------------------------------------------- 3) crash-detectie
func _crash_detectie() -> void:
	ReleaseFlags.debug_build_override = 1
	_leeg(MAP)
	sl.map_pad = MAP
	var kapot := MAP.path_join("sessie_2020-01-01_120000.jsonl")
	_schrijf(kapot, [
		_regel(0.0, "sessie_start", {"versie": "0.20", "build": "debug"}),
		_regel(2.0, "kaart", {"kaart": "woud_pad"}, "woud_pad"),
		_regel(9.5, "pos", {"kaart": "woud_pad", "x": 3, "y": 4}, "woud_pad"),
	])
	check("start na een sessie zonder sessie_stop lukt", sl.start())
	var p: String = sl.pad
	sl.stop()
	var r := _regels(p)
	var cr := _van_type(r, "crash_vorige")
	check("crash_vorige gemeld (1x)", cr.size() == 1)
	if cr.size() == 1:
		var d: Dictionary = cr[0]["data"]
		check("crash_vorige: bestand, laatste kaart, laatste regel", d["bestand"] == kapot.get_file()
				and d["kaart"] == "woud_pad" and d["laatste_type"] == "pos" and float(d["laatste_t"]) == 9.5)
	check("sessie_start blijft de eerste regel, crash_vorige direct erna", r[0]["type"] == "sessie_start" and r[1]["type"] == "crash_vorige")
	check("samenvatting telt de crash", int(_van_type(r, "sessie_stop")[0]["data"]["samenvatting"]["crashes"]) == 1)
	check("start() na een nette sessie lukt", sl.start())
	var p2: String = sl.pad
	sl.stop()
	check("tweede start: geen crash_vorige meer", _van_type(_regels(p2), "crash_vorige").is_empty())

	_leeg(MAP)
	_schrijf(MAP.path_join("sessie_2020-01-01_120000.jsonl"), [
		_regel(0.0, "sessie_start", {}), _regel(3.0, "kaart", {"kaart": "esdoorn"}), "{kapotte regel"])
	sl.start()
	var p3: String = sl.pad
	sl.stop()
	check("kapotte laatste regel: nog steeds crash_vorige met laatste kaart",
			_van_type(_regels(p3), "crash_vorige").size() == 1 and _van_type(_regels(p3), "crash_vorige")[0]["data"]["kaart"] == "esdoorn")
	_leeg(MAP)
	check("lege logmap: geen crash_vorige", sl.start() and _van_type(_regels(sl.pad), "crash_vorige").is_empty())
	sl.stop()


# ---------------------------------------------------------------- 4) release-build: doet niets
func _release() -> void:
	_leeg(MAP_RELEASE)
	ReleaseFlags.debug_build_override = 0
	sl.map_pad = MAP_RELEASE
	check("release-build: debug_build() is onwaar", not sl.debug_build())
	check("release-build: start() weigert", not sl.start() and not sl.actief)
	check("release-build: geen logmap-bestand", DirAccess.get_files_at(MAP_RELEASE).is_empty())
	sl.kaart("res://scenes/maps/wereldkaart.tscn")
	sl.noteer("menu_open", {"welk": "x"})
	sl.gevecht_start(["mosslijm"], false, "gras", Vector2i.ZERO)
	sl.gevecht_eind("win")
	sl.dood("battle")
	sl.flush()
	check("release-build: noteer/kaart/gevecht/dood schrijven niets", DirAccess.get_files_at(MAP_RELEASE).is_empty()
			and sl.buffer.is_empty())
	var oud_waarde: Variant = Settings.get_value("sessie_log")
	Settings.set_value("sessie_log", 1)
	check("release-build: instelling 'aan' zet de log niet aan", not Settings.sessie_log_enabled())
	Settings.set_value("sessie_log", -1)
	check("release-build: instelling 'auto' = uit", not Settings.sessie_log_enabled())
	var vorig_volgt: bool = sl.volgt_instelling
	sl.volgt_instelling = true
	Settings.set_value("sessie_log", 1)
	sl.pas_toe()
	check("release-build: pas_toe() start niets", not sl.actief and DirAccess.get_files_at(MAP_RELEASE).is_empty())
	sl.volgt_instelling = vorig_volgt
	var uit: Dictionary = sl.exporteer()
	check("release-build: export weigert met een duidelijke melding", uit["ok"] == false and str(uit["bericht"]).contains("debug"))

	ReleaseFlags.debug_build_override = 1
	Settings.set_value("sessie_log", -1)
	check("debug-build: instelling 'auto' = aan", Settings.sessie_log_enabled())
	Settings.set_value("sessie_log", 0)
	check("debug-build: instelling 'uit' = uit", not Settings.sessie_log_enabled())
	sl.volgt_instelling = true
	Settings.set_value("sessie_log", 1)
	sl.pas_toe()
	check("debug-build: pas_toe() start de sessie bij 'aan'", sl.actief)
	ReleaseFlags.debug_build_override = 0
	sl.pas_toe()
	check("release na debug: pas_toe() stopt de sessie", not sl.actief)
	sl.volgt_instelling = vorig_volgt
	Settings.set_value("sessie_log", int(oud_waarde))

	# Een verse autoload in een release-build verbindt niets en loopt niet.
	var vers: Node = SessieLogScript.new()
	add_child(vers)
	check("release-build: verse autoload verbindt geen signals", not GameState.battle_started.is_connected(vers._on_battle_started)
			and not GameState.game_over.is_connected(vers._on_game_over) and not Story.event_finished.is_connected(vers._on_story_event))
	check("release-build: verse autoload loopt niet (geen _process/_input)", not vers.is_processing() and not vers.is_processing_input())
	vers.free()
	ReleaseFlags.debug_build_override = 1
	var vers2: Node = SessieLogScript.new()
	add_child(vers2)
	check("debug-build: verse autoload verbindt wel (controle op de test hierboven)",
			GameState.battle_started.is_connected(vers2._on_battle_started))
	vers2.free()
	await _frames(1)
	ReleaseFlags.debug_build_override = -1


# ---------------------------------------------------------------- 5) playtest_rapport.py
func _python(args: Array) -> Dictionary:
	var out: Array = []
	var script := ProjectSettings.globalize_path("res://tools/sessielog/playtest_rapport.py")
	var a: Array = [script]
	a.append_array(args)
	var code := OS.execute("python3", a, out, true)
	return {"code": code, "tekst": "\n".join(out)}


func _rapport_tool() -> void:
	var probe := _python(["--help"])
	if int(probe["code"]) == -1 or int(probe["code"]) == 127:
		print("SKIP  playtest_rapport.py: python3 niet gevonden (code %d)" % int(probe["code"]))
		return
	check("rapport-tool --help: exit 0 en uitleg", int(probe["code"]) == 0 and str(probe["tekst"]).contains("playtest_rapport"))
	_leeg(MAP_TOOL)
	_leeg(MAP_TOOL_SCHOON)
	_leeg(MAP_LEEG)
	var crashed := MAP_TOOL.path_join("sessie_2020-01-01_120000.jsonl")
	_schrijf(crashed, [
		_regel(0.0, "sessie_start", {"versie": "0.20", "build": "debug", "modus": "Action"}),
		_regel(1.0, "kaart", {"kaart": "huis_wilgendal"}, "huis_wilgendal"),
		_regel(31.0, "kaart_tijd", {"kaart": "huis_wilgendal", "secs": 30.0}),
		_regel(31.0, "kaart", {"kaart": "wereldkaart"}, "wereldkaart"),
		_regel(35.0, "gevecht_start", {"kaart": "wereldkaart", "vijanden": ["mosslijm"], "baas": false, "party_hp_pct": 100}),
		_regel(50.0, "gevecht_eind", {"kaart": "wereldkaart", "resultaat": "lose", "ronden": 4, "secs": 15.0, "hp_verlies": 33}),
		_regel(50.5, "dood", {"kaart": "wereldkaart", "reden": "battle"}),
		_regel(51.0, "game_over", {"plek": "wereldkaart"}),
		_regel(60.0, "gat", {"secs": 4.2}, "wereldkaart"),
		_regel(80.0, "app_hervat", {"pauze": 10.0}),
		_regel(100.0, "pos", {"kaart": "wereldkaart"}, "wereldkaart"),
		"{kapotte regel",
		"[1, 2]",
	])
	var r := _python(["--json", ProjectSettings.globalize_path(crashed)])
	check("rapport --json: exit 0", int(r["code"]) == 0)
	var j: Variant = JSON.parse_string(str(r["tekst"]))
	check("rapport --json: geldige JSON", j is Dictionary)
	if j is Dictionary:
		var s: Dictionary = j["sessies"][0]
		check("rapport: 2 kapotte regels overgeslagen", int(s["overgeslagen"]) == 2)
		check("rapport: tijd per gebied (wachtershuis 30 s)", is_equal_approx(float(s["gebied_secs"].get("wachtershuis", 0)), 30.0))
		check("rapport: afgebroken laatste kaart telt mee zonder pauze (wereldkaart 59 s)",
				is_equal_approx(float(s["gebied_secs"].get("wereldkaart", 0)), 59.0) and bool(s["laatste_kaart_afgebroken"]))
		check("rapport: 1 gevecht (verlies, wereldkaart)", s["gevechten"].size() == 1 and s["gevechten"][0]["uitkomst"] == "lose"
				and s["gevechten"][0]["gebied"] == "wereldkaart")
		check("rapport: 1 dood, 1 game-over", s["doden"].size() == 1 and s["game_overs"].size() == 1)
		check("rapport: vastloper van 4,2 s", s["vastlopers"].size() == 1)
		check("rapport: sessie zonder sessie_stop = niet netjes gestopt", not bool(s["netjes_gestopt"]))
		check("rapport: totaal telt 1 afgebroken sessie", int(j["totaal"]["afgebroken"]) == 1)
	var tekst := _python([ProjectSettings.globalize_path(MAP_TOOL)])
	var t := str(tekst["tekst"])
	check("rapport tekst: gebieden, gevechten, doden en crashes",
			t.contains("Wachtershuis-erf") and t.contains("Gevechten: 1") and t.contains("Doden: 1")
			and t.contains("Crashes en vastlopers: 2") and t.contains("GEEN sessie_stop"))
	check("rapport --strict: exit 3 bij crash/dood", int(_python(["--strict", ProjectSettings.globalize_path(MAP_TOOL)])["code"]) == 3)

	var schoon := MAP_TOOL_SCHOON.path_join("sessie_2026-01-02_120000.jsonl")
	_schrijf(schoon, [
		_regel(0.0, "sessie_start", {"versie": "0.20", "build": "debug", "modus": "Classic"}),
		_regel(1.0, "kaart", {"kaart": "esdoorn"}, "esdoorn"),
		_regel(13.0, "kaart_tijd", {"kaart": "esdoorn", "secs": 12.0}),
		_regel(14.0, "gevecht_start", {"kaart": "woud_pad", "vijanden": ["woudgeest"], "baas": true, "party_hp_pct": 100}),
		_regel(20.0, "gevecht_eind", {"kaart": "woud_pad", "resultaat": "win", "ronden": 3, "secs": 6.0, "hp_verlies": 5}),
		_regel(21.0, "sessie_stop", {"duur": 21.0}),
	])
	var rs := _python(["--strict", ProjectSettings.globalize_path(MAP_TOOL_SCHOON)])
	check("rapport --strict: schone sessie = exit 0", int(rs["code"]) == 0)
	check("rapport tekst: baasgevecht en 'geen crashes'", str(rs["tekst"]).contains("Baasgevechten:")
			and str(rs["tekst"]).contains("Crashes en vastlopers: geen") and str(rs["tekst"]).contains("Doden: geen"))
	var beide := _python(["--json", ProjectSettings.globalize_path(MAP_TOOL), ProjectSettings.globalize_path(MAP_TOOL_SCHOON)])
	var jb: Variant = JSON.parse_string(str(beide["tekst"]))
	check("rapport: twee mappen = 2 sessies met totaal", jb is Dictionary and int(jb["totaal"]["sessies"]) == 2
			and int(jb["totaal"]["gevechten"]) == 2 and is_equal_approx(float(jb["totaal"]["gebied_secs"].get("esdoorn", 0)), 12.0))

	var getrimd := MAP_TOOL_SCHOON.path_join("sessie_2026-01-03_120000.jsonl")
	_schrijf(getrimd, [
		_regel(0.0, "sessie_start", {"versie": "0.20", "build": "debug"}),
		_regel(9.0, "sessie_stop", {"duur": 9.0, "samenvatting": {"gebied_secs": {"woud": 8.0}, "kaart_secs": {"woud_pad": 8.0}}}),
	])
	var jt: Variant = JSON.parse_string(str(_python(["--json", ProjectSettings.globalize_path(getrimd)])["tekst"]))
	check("rapport: getrimde log valt terug op de samenvatting in sessie_stop",
			jt is Dictionary and is_equal_approx(float(jt["sessies"][0]["gebied_secs"].get("woud", 0)), 8.0))

	check("rapport: onbekende optie = exit 2", int(_python(["--onzin", ProjectSettings.globalize_path(MAP_TOOL)])["code"]) == 2)
	check("rapport: zonder argumenten = exit 2", int(_python([])["code"]) == 2)
	check("rapport: lege map = exit 1", int(_python([ProjectSettings.globalize_path(MAP_LEEG)])["code"]) == 1)
	var ruw := MAP_LEEG.path_join("sessie_2026-01-04_120000.jsonl")
	var f := FileAccess.open(ruw, FileAccess.WRITE)
	f.store_string("geen json\n\n")
	f.close()
	var rl := _python([ProjectSettings.globalize_path(ruw)])
	check("rapport: bestand zonder bruikbare regels breekt niet", int(rl["code"]) == 0 and str(rl["tekst"]).contains("Geen bruikbare regels"))
