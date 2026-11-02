class_name PerfProbe
extends RefCounted
## T27: lichte profiler-haken voor de RISK-plekken uit docs/perf/s25_check.md
## (baseline: docs/perf/wm1_baseline.md). begin/end met Time.get_ticks_usec();
## per label een rollend min/avg/max. dump() print en schrijft user://perf_probe.json.
##
## Uit standaard. Aan alleen in een debug-build, via:
##   - command-line `--perfprobe` (exact; `--perfprobetest` zet hem níet aan)
##   - debug-instelling `perf_probe=true` in user://settings.cfg [instellingen]
##   - `PerfProbe.enabled = true` (tests / adb-debug; ook alleen zinvol in debug)
## Release-APK: blijft uit, ook met flag of setting. Uit: alleen een bool-check, geen allocaties.

const FLAG := "--perfprobe"
const DUMP_PATH := "user://perf_probe.json"
const SETTING_FILE := "user://settings.cfg"
const SETTING_SECTION := "instellingen"
const SETTING_KEY := "perf_probe"

## RISK-ids uit docs/perf/wm1_baseline.md (samengevat in s25_check.md).
const RISK_MAPS := {
	"res://scenes/maps/dorp_wilgendal.tscn": "dorp_wilgendal",
	"res://world_warper/maps/hal.tscn": "warper_hal",
	"res://scenes/maps/woud_beek.tscn": "woud_beek",
}
const RISK_BATTLES: Array[String] = [
	"battle_gras", "battle_woud", "battle_archief", "battle_baas_golem", "battle_kas",
]
const RISK_LABELS: Array[String] = [
	"dorp_wilgendal", "warper_hal", "woud_beek",
	"battle_gras", "battle_woud", "battle_archief", "battle_baas_golem", "battle_kas",
]

static var enabled: bool = false
static var _bootstrapped: bool = false
static var _open: Dictionary = {}   # label -> PackedInt64Array (start-usec, nestbaar)
static var _stats: Dictionary = {}  # label -> {count, sum_us, min_us, max_us}


static func bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true
	# Flag en setting mogen de probe alleen in een debug-build aanzetten (release blijft uit).
	if mag_aan(OS.is_debug_build(), _flag_aan(OS.get_cmdline_user_args()), _debug_setting_aan()):
		enabled = true
	if enabled:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and not tree.root.tree_exiting.is_connected(_dump_bij_einde):
			tree.root.tree_exiting.connect(_dump_bij_einde)


## Flag/setting zetten `enabled` alleen als dit een debug-build is. Release: altijd uit.
static func mag_aan(debug_build: bool, flag: bool, setting: bool) -> bool:
	return debug_build and (flag or setting)


static func _dump_bij_einde() -> void:
	if enabled and not _stats.is_empty():
		dump()


static func _flag_aan(args: PackedStringArray) -> bool:
	return FLAG in args


static func _debug_setting_aan() -> bool:
	if not FileAccess.file_exists(SETTING_FILE):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SETTING_FILE) != OK:
		return false
	if not cfg.has_section_key(SETTING_SECTION, SETTING_KEY):
		return false
	return bool(cfg.get_value(SETTING_SECTION, SETTING_KEY, false))


static func map_label(path: String) -> String:
	return str(RISK_MAPS.get(path, ""))


static func battle_label(backdrop_id: String, boss: bool, enemies: Array) -> String:
	if boss:
		for e in enemies:
			if str(e) == "kennis_beest":
				return "battle_baas_golem"
		if backdrop_id == "boss":
			return "battle_baas_golem"
	match backdrop_id:
		"grass":
			return "battle_gras"
		"forest_dark":
			return "battle_woud"
		"library":
			return "battle_archief"
		"library_overgrown":
			return "battle_kas"
		"boss":
			return "battle_baas_golem"
	return ""


static func begin(label: String) -> void:
	if not enabled:
		return
	if label.is_empty():
		return
	var stack: PackedInt64Array = _open.get(label, PackedInt64Array())
	stack.append(Time.get_ticks_usec())
	_open[label] = stack


static func end(label: String) -> void:
	if not enabled:
		return
	if label.is_empty() or not _open.has(label):
		return
	var stack: PackedInt64Array = _open[label]
	if stack.is_empty():
		return
	var start: int = stack[stack.size() - 1]
	stack.remove_at(stack.size() - 1)
	if stack.is_empty():
		_open.erase(label)
	else:
		_open[label] = stack
	_record(label, Time.get_ticks_usec() - start)


static func _record(label: String, dt: int) -> void:
	if dt < 0:
		dt = 0
	if not _stats.has(label):
		_stats[label] = {"count": 1, "sum_us": dt, "min_us": dt, "max_us": dt}
		return
	var s: Dictionary = _stats[label]
	s["count"] = int(s["count"]) + 1
	s["sum_us"] = int(s["sum_us"]) + dt
	s["min_us"] = mini(int(s["min_us"]), dt)
	s["max_us"] = maxi(int(s["max_us"]), dt)


static func snapshot() -> Dictionary:
	return _stats.duplicate(true)


static func reset() -> void:
	_open.clear()
	_stats.clear()


static func dump() -> String:
	var out := {}
	for label in _stats:
		var s: Dictionary = _stats[label]
		var count: int = int(s["count"])
		var sum_us: int = int(s["sum_us"])
		out[label] = {
			"count": count,
			"min_us": int(s["min_us"]),
			"max_us": int(s["max_us"]),
			"sum_us": sum_us,
			"avg_us": int(round(float(sum_us) / float(count))) if count > 0 else 0,
		}
	var text := JSON.stringify(out)
	print("PERFPROBE %s" % text)
	var f := FileAccess.open(DUMP_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		print("PERFPROBE file=%s" % DUMP_PATH)
	else:
		push_warning("PerfProbe: kon %s niet schrijven" % DUMP_PATH)
	return text
