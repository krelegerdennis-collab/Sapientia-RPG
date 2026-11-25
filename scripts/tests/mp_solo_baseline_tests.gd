extends Node
## MP-split fase 0: vast golden solo-session (save-bytes + state_data SHA-256). Geen MP, geen toeval.
##   godot --path . -- --mpsolobaselinetest
##   godot --path . -- --mpsolobaselinetest --regen-golden   (alleen lokaal: schrijft golden files)

const Equipment := preload("res://scripts/equipment.gd")
const GoldenDir := "res://scripts/tests/golden/mp_solo_baseline/"
const MAP := "res://scenes/maps/wilgendal.tscn"
const TILE := Vector2i(11, 14)
const FACE := Vector2i(0, -1)
const PATH_MANUAL := "user://mpsolobaselinetest_manual.json"
const PATH_ROUNDTRIP := "user://mpsolobaselinetest_roundtrip.json"

## Alleen deze sleutels (top-level in save-json) mogen per run verschillen; vóór vergelijking vast gezet.
const VOLATILE_KEYS := {
	"play_time": "reële speeltijd (klok)",
	"saved_at": "tijdstempel bij opslaan",
	"saved_unix": "unix-tijdstempel bij opslaan",
	"heard_music": "huidige track via AudioManager (_hoor_huidige_muziek bij laden)",
}

const _NORM_PLAY_TIME := 42.5
const _NORM_SAVED_AT := "2026-01-15T12:00:00"
const _NORM_SAVED_UNIX := 1736935200

var failures := 0
var passes := 0
var _regen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if str(a) == "--regen-golden":
			_regen = true
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


func _fix_play_clock() -> void:
	GameState._play_time_base = _NORM_PLAY_TIME
	GameState._clock_start_ms = Time.get_ticks_msec()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _parse_json(text: String) -> Dictionary:
	if text == "":
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data


func _apply_volatile(d: Dictionary) -> void:
	for k in VOLATILE_KEYS:
		if not d.has(k):
			continue
		match k:
			"play_time":
				d[k] = _NORM_PLAY_TIME
			"saved_at":
				d[k] = _NORM_SAVED_AT
			"saved_unix":
				d[k] = _NORM_SAVED_UNIX
			"heard_music":
				d[k] = []


func _normalize_tree(d) -> void:
	if d is Dictionary:
		_apply_volatile(d)
		for v in d.values():
			_normalize_tree(v)
	elif d is Array:
		for v in d:
			_normalize_tree(v)


func _normalized_save_text(path: String) -> String:
	var d := _parse_json(_read_text(path))
	if d.is_empty():
		return ""
	_normalize_tree(d)
	return JSON.stringify(d, "  ")


static func diff(a, b, pad := "") -> String:
	var a_num := a is int or a is float
	var b_num := b is int or b is float
	if a_num or b_num:
		return "" if a_num and b_num and float(a) == float(b) else "%s: %s != %s" % [pad, a, b]
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				return "%s.%s ontbreekt" % [pad, k]
			var d := diff(a[k], b[k], "%s.%s" % [pad, k])
			if d != "":
				return d
		for k in b:
			if not a.has(k):
				return "%s.%s extra" % [pad, k]
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


func _state_hash() -> String:
	_fix_play_clock()
	var d: Dictionary = GameState.state_data(TILE, FACE, MAP)
	_normalize_tree(d)
	return JSON.stringify(d, "", true).sha256_text()


func _is_suite_user_file(name: String) -> bool:
	return name.begins_with("mpsolobaselinetest")


func _check_user_dir_clean() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("user://")
	var extra: Array[String] = []
	for f in files:
		if not _is_suite_user_file(str(f)):
			extra.append(str(f))
	check("geen extra bestanden in user:// (%d)" % extra.size(), extra.is_empty())


func _run_scripted_session() -> Dictionary:
	check("coop_role leeg bij start", GameState.coop_role == "")
	GameState.new_game("Dennis")
	GameState.join_member("lotte", 12)
	GameState.join_member("noor", 8)
	GameState.give_exp(GameState.party[0], 180)
	GameState.gold = 1234
	GameState.add_item("drankje", 2)
	var dex: Dictionary = GameState.party[0]
	GameState.add_item("kort_zwaard", 1)
	Equipment.equip(dex, GameState.inventory, "wapen", "kort_zwaard")
	GameState.story_step = 6
	GameState.story_flags["golem_verslagen"] = true
	GameState.story_flags["gesproken_gerrit"] = true
	# load_game roept opening-flow migrate aan; zet de vlag al vóór de eerste save (stabiele roundtrip).
	GameState.story_flags["warper_drift_done"] = true
	GameState.mark_defeated("mosslijm")
	GameState.codex_add("mosslijm", 5)
	GameState.dungeon100_floor = 2
	GameState.dungeon100_best = 3
	GameState.current_map = MAP
	GameState.set_checkpoint(MAP, TILE, FACE)
	check("coop_role leeg tijdens sessie", GameState.coop_role == "")

	_fix_play_clock()
	check("handmatige save lukt", GameState.save_game(TILE, FACE, PATH_MANUAL))
	var manual_norm := _normalized_save_text(PATH_MANUAL)

	check("laden na save lukt", GameState.load_game(PATH_MANUAL))
	_fix_play_clock()
	check("roundtrip-save lukt", GameState.save_game(TILE, FACE, PATH_ROUNDTRIP))
	var round_norm := _normalized_save_text(PATH_ROUNDTRIP)
	var rt_diff := diff(_parse_json(manual_norm), _parse_json(round_norm), "roundtrip")
	check("roundtrip JSON gelijk aan manual%s" % ("" if rt_diff == "" else " (%s)" % rt_diff), rt_diff == "")

	_fix_play_clock()
	check("autosave (map) lukt", GameState.autosave(TILE, FACE, "map"))
	var autosave_norm := _normalized_save_text(GameState.autosave_path)
	var state_sha := _state_hash()

	return {
		"manual": manual_norm,
		"roundtrip": round_norm,
		"autosave": autosave_norm,
		"state_sha": state_sha,
	}


func _write_golden(name: String, text: String) -> void:
	var path := GoldenDir + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	check("golden schrijven %s" % name, f != null)
	if f != null:
		f.store_string(text)
		f.close()


func _read_golden(name: String) -> String:
	var path := GoldenDir + name
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path).strip_edges()


func _compare_golden(label: String, got: String, file: String) -> void:
	var want := _read_golden(file)
	if want == "":
		check("%s: golden ontbreekt (%s)" % [label, file], false)
		return
	var d_got := _parse_json(got)
	var d_want := _parse_json(want)
	var d := diff(d_want, d_got, label)
	check("%s matcht golden%s" % [label, "" if d == "" else " (%s)" % d], d == "")


func _run() -> void:
	GameState._finish_preload()
	GameState.encounter_multiplier = 0.0
	_remove_save(PATH_MANUAL)
	_remove_save(PATH_ROUNDTRIP)
	_remove_save(GameState.autosave_path)

	var out1 := _run_scripted_session()
	_check_user_dir_clean()

	GameState.new_game("Zzz")
	_remove_save(PATH_MANUAL)
	_remove_save(PATH_ROUNDTRIP)
	_remove_save(GameState.autosave_path)
	var out2 := _run_scripted_session()
	check("twee runs: manual JSON identiek", out1["manual"] == out2["manual"])
	check("twee runs: state SHA identiek", out1["state_sha"] == out2["state_sha"])

	if _regen:
		_write_golden("save_manual.json", out1["manual"])
		_write_golden("save_roundtrip.json", out1["roundtrip"])
		_write_golden("autosave.json", out1["autosave"])
		_write_golden("state_data.sha256", out1["state_sha"] + "\n")
	else:
		_compare_golden("manual save", out1["manual"], "save_manual.json")
		_compare_golden("roundtrip save", out1["roundtrip"], "save_roundtrip.json")
		_compare_golden("autosave", out1["autosave"], "autosave.json")
		var want_sha := _read_golden("state_data.sha256")
		check("state_data SHA-256", want_sha != "" and out1["state_sha"] == want_sha)

	check("coop_role leeg aan einde", GameState.coop_role == "")

	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)