extends Node
## Android launcher-icoon C (--launchertest): export_presets launcher_icons + bestandsgrootte.
## Start: godot --path . -- --launchertest
## Zit niet in de export (scripts/tests/*). Niet in de CI-matrix tot Dennis toevoegt.

const EXPECTED_MAIN := "res://assets/ui/launcher/launcher_main_192.png"
const EXPECTED_FG := "res://assets/ui/launcher/launcher_adaptive_fg_432.png"
const EXPECTED_BG := "res://assets/ui/launcher/launcher_adaptive_bg_432.png"

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
	_png_size_tests()
	_preset_tests()
	print("LAUNCHERTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures > 0 else 0)


func _png_size_tests() -> void:
	check("main launcher 192 bestaat", FileAccess.file_exists(EXPECTED_MAIN))
	check("adaptive fg 432 bestaat", FileAccess.file_exists(EXPECTED_FG))
	check("adaptive bg 432 bestaat", FileAccess.file_exists(EXPECTED_BG))
	_check_png("main 192x192", EXPECTED_MAIN, 192, 192)
	_check_png("adaptive fg 432x432", EXPECTED_FG, 432, 432)
	_check_png("adaptive bg 432x432", EXPECTED_BG, 432, 432)


func _check_png(label: String, res_path: String, w: int, h: int) -> void:
	var img := Image.new()
	var err := img.load(ProjectSettings.globalize_path(res_path))
	check("%s laadt (err=%d)" % [label, err], err == OK)
	if err != OK:
		return
	check("%s = %dx%d" % [label, w, h], img.get_width() == w and img.get_height() == h)


func _android_presets(cfg: ConfigFile) -> Array[String]:
	var found: Array[String] = []
	for sec in cfg.get_sections():
		var name := str(sec)
		if not name.ends_with(".options") and str(cfg.get_value(name, "platform", "")) == "Android":
			found.append(name)
	found.sort()
	return found


func _preset_tests() -> void:
	var cfg := ConfigFile.new()
	check("export_presets.cfg laadt", cfg.load("res://export_presets.cfg") == OK)
	var presets := _android_presets(cfg)
	check("drie Android-presets (nu %d)" % presets.size(), presets.size() == 3)
	for sec in presets:
		var opt := sec + ".options"
		var naam := str(cfg.get_value(sec, "name", sec))
		var main := str(cfg.get_value(opt, "launcher_icons/main_192x192", ""))
		var fg := str(cfg.get_value(opt, "launcher_icons/adaptive_foreground_432x432", ""))
		var bg := str(cfg.get_value(opt, "launcher_icons/adaptive_background_432x432", ""))
		check("%s: main_192x192 == %s" % [naam, EXPECTED_MAIN], main == EXPECTED_MAIN)
		check("%s: adaptive_foreground == %s" % [naam, EXPECTED_FG], fg == EXPECTED_FG)
		check("%s: adaptive_background == %s" % [naam, EXPECTED_BG], bg == EXPECTED_BG)