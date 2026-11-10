extends "res://scripts/tests/golem_tests.gd"
## Issue #169: baasnaam in Classic-gevecht past binnen het scherm (16:9 en hog smal).
## Start: .github/scripts/run_suite.sh bossnametest

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const LONGEST_BOSS := "The Knowledge Beast"


func _run() -> void:
	var sc := Scenarios.new()
	add_child(sc)
	await _boss_name_profile_tests(sc, "16x9")
	await _boss_name_profile_tests(sc, "19_5x9")
	sc.queue_free()
	print("BOSSNAMETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(10)
	get_tree().quit(1 if failures else 0)


func _boss_name_profile_tests(sc: Node, prof: String) -> void:
	if get_tree().current_scene != null and get_tree().current_scene.name == "Battle":
		await GameState.end_battle("flee")
		await sc.wait_scene("Wilgendal", 30.0)
		await sc.pframes(10)
	await sc.set_profile(prof)
	await sc.pframes(10)
	Engine.time_scale = 2.0
	var b := await _start_boss(10)
	var tag := "[%s] " % prof
	check(tag + "baasgevecht met HP-balk", b != null and b.boss_bar != null)
	if b == null or b.boss_bar == null:
		return
	var bar: Control = b.boss_bar
	var lab: Label = bar.name_label
	check(tag + "naamtekst ongewijzigd ('%s')" % lab.text, lab.text == LONGEST_BOSS)
	var font: Font = lab.get_theme_font("font")
	var fs := lab.get_theme_font_size("font_size")
	var text_w := font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font != null else 0.0
	var fits_one_line := lab.autowrap_mode == TextServer.AUTOWRAP_OFF and text_w <= lab.size.x + 0.5
	var fits_wrap := lab.autowrap_mode != TextServer.AUTOWRAP_OFF
	check(tag + "naam leesbaar (één regel of wrap)", fits_one_line or fits_wrap)
	var safe := UiTouchC.insets(get_viewport())
	var gr := lab.get_global_rect()
	var vp := get_viewport().get_visible_rect()
	check(tag + "naamlabel binnen viewport (eind %.1f <= %.1f)" % [gr.end.x, vp.size.x - safe.z],
			gr.position.x >= safe.x - 0.5 and gr.end.x <= vp.size.x - safe.z + 0.5)
	check(tag + "HP-balk even breed als label (%.0f)" % bar.size.x, is_equal_approx(bar.size.x, lab.size.x))
	if shots != "":
		await pframes(6)
		await screenshot("bossname_%s" % prof)
	if b != null:
		await GameState.end_battle("flee")
		await sc.wait_scene("Wilgendal", 30.0)
		await sc.pframes(8)
