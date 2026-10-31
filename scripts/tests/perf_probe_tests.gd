extends Node
## T27: PerfProbe (--perfprobetest). Uit = geen data; aan = labels + geldige dump-JSON.
## Start: godot --path . -- --perfprobetest
## Zit niet in de export (scripts/tests/*). Niet in de CI-matrix (taak: workflows niet wijzigen).

const Probe := preload("res://scripts/perf/perf_probe.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 60 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_uit_tests()
	_gate_tests()
	_aan_tests()
	_dump_tests()
	_label_tests()
	_hook_bron_tests()
	print("PERFPROBETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func _uit_tests() -> void:
	Probe.enabled = false
	Probe.reset()
	check("standaard / na reset: uit", not Probe.enabled)
	check("--perfprobetest zet de probe niet aan (alleen exact --perfprobe)",
			not Probe._flag_aan(OS.get_cmdline_user_args()))
	Probe.begin("dorp_wilgendal")
	Probe.end("dorp_wilgendal")
	check("uit: begin/end laten geen data achter", Probe.snapshot().is_empty())
	var leeg := Probe.dump()
	check("uit: dump is leeg object", leeg == "{}")
	check("uit: snapshot blijft leeg na dump", Probe.snapshot().is_empty())


func _gate_tests() -> void:
	check("release + --perfprobe: blijft uit", not Probe.mag_aan(false, true, false))
	check("release + perf_probe=true: blijft uit", not Probe.mag_aan(false, false, true))
	check("release + flag en setting: blijft uit", not Probe.mag_aan(false, true, true))
	check("debug zonder flag/setting: uit", not Probe.mag_aan(true, false, false))
	check("debug + --perfprobe: aan", Probe.mag_aan(true, true, false))
	check("debug + perf_probe=true: aan", Probe.mag_aan(true, false, true))
	check("deze suite draait in een debug-build (headless Godot)", OS.is_debug_build())
	check("bootstrap zonder --perfprobe: enabled blijft uit",
			not Probe.mag_aan(OS.is_debug_build(), Probe._flag_aan(OS.get_cmdline_user_args()), false))


func _aan_tests() -> void:
	Probe.reset()
	Probe.enabled = true
	check("aan: enabled", Probe.enabled)
	for _i in 3:
		Probe.begin("dorp_wilgendal")
		var n := 0
		for _j in 200:
			n += _j
		Probe.end("dorp_wilgendal")
	Probe.begin("battle_gras")
	Probe.end("battle_gras")
	var snap: Dictionary = Probe.snapshot()
	check("aan: RISK-label dorp_wilgendal opgenomen", snap.has("dorp_wilgendal"))
	check("aan: RISK-label battle_gras opgenomen", snap.has("battle_gras"))
	var d: Dictionary = snap["dorp_wilgendal"]
	check("aan: count=3 voor drie samples", int(d.get("count", 0)) == 3)
	check("aan: min/max/sum aanwezig", d.has("min_us") and d.has("max_us") and d.has("sum_us"))
	check("aan: min <= max en sum >= min", int(d["min_us"]) <= int(d["max_us"]) and int(d["sum_us"]) >= int(d["min_us"]))
	check("aan: geen extra labels", snap.size() == 2)
	Probe.enabled = false
	Probe.begin("warper_hal")
	Probe.end("warper_hal")
	check("weer uit: geen nieuw label", not Probe.snapshot().has("warper_hal"))


func _dump_tests() -> void:
	Probe.enabled = true
	var text := Probe.dump()
	var parsed = JSON.parse_string(text)
	check("dump: geldige JSON (Dictionary)", parsed is Dictionary)
	if parsed is Dictionary:
		check("dump-JSON heeft dorp_wilgendal", parsed.has("dorp_wilgendal"))
		var rij: Dictionary = parsed["dorp_wilgendal"]
		check("dump-JSON: count/min/avg/max/sum",
				rij.has("count") and rij.has("min_us") and rij.has("avg_us") and rij.has("max_us") and rij.has("sum_us"))
		var count := int(rij["count"])
		var avg := int(rij["avg_us"])
		var som := int(rij["sum_us"])
		check("dump-JSON: avg = sum/count", count > 0 and avg == int(round(float(som) / float(count))))
	var pad := ProjectSettings.globalize_path(Probe.DUMP_PATH)
	check("dump schrijft user://perf_probe.json", FileAccess.file_exists(Probe.DUMP_PATH))
	if FileAccess.file_exists(Probe.DUMP_PATH):
		var bestand := FileAccess.get_file_as_string(Probe.DUMP_PATH)
		var uit_bestand = JSON.parse_string(bestand)
		check("bestand is geldige JSON", uit_bestand is Dictionary)
		check("bestand == dump-tekst", bestand == text)
		print("INFO  dump-pad %s" % pad)
	Probe.reset()
	Probe.enabled = false


func _label_tests() -> void:
	check("map_label dorp_wilgendal", Probe.map_label("res://scenes/maps/dorp_wilgendal.tscn") == "dorp_wilgendal")
	check("map_label warper_hal", Probe.map_label("res://world_warper/maps/hal.tscn") == "warper_hal")
	check("map_label woud_beek", Probe.map_label("res://scenes/maps/woud_beek.tscn") == "woud_beek")
	check("map_label onbekend is leeg (geen RISK)", Probe.map_label("res://scenes/maps/wereldkaart.tscn") == "")
	check("battle_label gras", Probe.battle_label("grass", false, ["mosslijm"]) == "battle_gras")
	check("battle_label woud", Probe.battle_label("forest_dark", false, ["wortelgeest"]) == "battle_woud")
	check("battle_label archief", Probe.battle_label("library", false, ["papiergeest"]) == "battle_archief")
	check("battle_label kas", Probe.battle_label("library_overgrown", false, ["glitchmot"]) == "battle_kas")
	check("battle_label baas golem",
			Probe.battle_label("boss", true, ["kennis_beest"]) == "battle_baas_golem")
	check("alle 8 RISK-ids in RISK_LABELS", Probe.RISK_LABELS.size() == 8
			and Probe.RISK_LABELS.has("dorp_wilgendal") and Probe.RISK_LABELS.has("warper_hal")
			and Probe.RISK_LABELS.has("woud_beek") and Probe.RISK_LABELS.has("battle_gras")
			and Probe.RISK_LABELS.has("battle_woud") and Probe.RISK_LABELS.has("battle_archief")
			and Probe.RISK_LABELS.has("battle_baas_golem") and Probe.RISK_LABELS.has("battle_kas"))


func _hook_bron_tests() -> void:
	var hooks := [
		["res://scripts/village/dorp_ground.gd", "dorp_wilgendal", "s25_check"],
		["res://scripts/village/dorp_opbouw.gd", "dorp_wilgendal", "s25_check"],
		["res://world_warper/flow/hub_boot.gd", "warper_hal", "s25_check"],
		["res://scripts/dungeon/woud_beek_kamer.gd", "woud_beek", "s25_check"],
		["res://scripts/map.gd", "map_label", "s25_check"],
		["res://scripts/battle/battle.gd", "battle_label", "s25_check"],
		["res://scripts/game_state.gd", "perf_probe", "s25_check"],
		["res://scripts/dungeon/woud_mist.gd", "woud_mist", "s25_check"],
		["res://scripts/dungeon/dungeon_room.gd", "woud_mist", "s25_check"],
	]
	for h in hooks:
		var pad: String = h[0]
		var naald: String = h[1]
		var doc: String = h[2]
		if not FileAccess.file_exists(pad):
			check("hook-bron bestaat: %s" % pad, false)
			continue
		var tekst := FileAccess.get_file_as_string(pad)
		check("hook %s noemt %s" % [pad.get_file(), naald], tekst.contains(naald) and tekst.contains("PerfProbe"))
		check("hook %s verwijst naar %s" % [pad.get_file(), doc], tekst.contains(doc))
	for pad in ["res://scripts/map.gd", "res://scripts/battle/battle.gd", "res://scripts/dungeon/woud_mist.gd"]:
		var tekst := FileAccess.get_file_as_string(pad)
		var i := tekst.find("func _process")
		var j := tekst.find("\nfunc ", i + 1) if i >= 0 else -1
		var stuk := ""
		if i >= 0:
			stuk = tekst.substr(i, j - i) if j > i else tekst.substr(i)
		var leest := stuk.contains("= PerfProbe.enabled") or stuk.contains("if PerfProbe.enabled")
		check("%s _process leest enabled niet per frame" % pad.get_file(),
				stuk != "" and stuk.contains("_pp_on") and not leest)
		check("%s cached enabled in _ready (_pp_on =)" % pad.get_file(),
				tekst.contains("_pp_on = PerfProbe.enabled"))
