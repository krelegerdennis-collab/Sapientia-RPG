extends Node
## ALLEEN VOOR TESTEN - F6 UX-fixes World Map 1 (tweede set: F6-1, F6-2, F6-5, F6-8). Nieuwe suite;
## raakt geen bestaande tests (--f6uxtest van RPG CODE is een andere suite).
## Start:  godot --path . -- --f6uxtest2 [--shots=/pad/map]   (scripts/tests/f6_ux2_tests.gd)
## De checks per ticket staan in scripts/tests/f6_ux2/*.gd (één bestand per ticket, op naam gesorteerd).
## Elk deel: extends RefCounted, func run(t: Node) -> void. 't' is deze runner (check, sc, hulpjes).
## Zo kan elk ticket een eigen PR zijn zonder dat de PR's elkaar in dit bestand raken.
## Zit niet in de export (scripts/tests/*).

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const PARTS_DIR := "res://scripts/tests/f6_ux2"

var failures := 0
var passes := 0
var shots := ""
var sc: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	sc = Scenarios.new()
	add_child(sc)
	sc.shots_dir = shots
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	print("INFO  screenshot: %s/%s.png %s" % [shots, name, img.get_size()])


## Rechthoek r ligt binnen bounds (halve eenheid speling voor afronding).
func within(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 \
			and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


## Het veilige gebied van de huidige viewport (UiTouch.insets_override of het platform).
func safe() -> Rect2:
	return UiTouch.safe_rect(get_viewport().get_visible_rect().size, get_viewport())


## De openings-cutscene van start_new_game (world_warper/opening/drift.gd, laag 125) wegtikken zoals de
## speler: anders ligt hij over elk scherm (screenshots) en vangt hij echte tikken af.
func _skip_opening() -> void:
	var d: Node = get_tree().root.find_child("OpeningDrift", true, false)
	if d != null and d.has_method("_klaar"):
		d.call("_klaar")
	var t0 := Time.get_ticks_msec()
	while get_tree().root.find_child("OpeningDrift", true, false) != null and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	d = get_tree().root.find_child("OpeningDrift", true, false)
	if d != null:
		d.queue_free()
		await pframes(2)
	print("INFO  openings-cutscene weg: %s" % (get_tree().root.find_child("OpeningDrift", true, false) == null))


func _parts() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(PARTS_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [PARTS_DIR, f])
	out.sort()
	return out


func _run() -> void:
	await sc.wait_scene("Title")
	await pframes(10)
	var parts := _parts()
	check("f6ux2: minstens één deel gevonden (%d)" % parts.size(), not parts.is_empty())
	var game_started := false
	for p in parts:
		print("=== %s ===" % p.get_file())
		var scr := load(p) as GDScript
		if scr == null or not scr.can_instantiate():
			check("%s laadt (geen parse-fout)" % p.get_file(), false)
			continue
		var part: Object = scr.new()
		if part.has_method("needs_game") and part.needs_game() and not game_started:
			game_started = await sc.start_game()
			check("spel start in Wilgendal", game_started)
			await _skip_opening()
		await part.run(self)
		await sc.close_all()
		await sc.set_profile("16x9")
		UiTouch.insets_override = null
	print("F6UXTEST2 %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)
