extends Node
## F6.15: RUN-knop in kerker, Rest Room en Koopman (backlog A11).
## Start: godot --path . -- --runknoptest [--shots=/pad/map]
## hudtest deel D dekt veld, dorp, hub-hal en wereldkaart. Deze suite laadt één kamer
## van de drie ontbrekende soorten en toetst de RUN-knop hetzelfde: aanwezig, zichtbaar,
## binnen het veilige gebied, en tikbaar (tikvlak >= UiTouch.TOUCH_MIN, zoals touch_controls
## de tik op RUN beoordeelt: hit_rect(run_rect(), 2)).
## In de CI-matrix (tests.yml). Zit niet in de export (scripts/tests/*).

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const GK := preload("res://scripts/data/grot_kamers.gd")
const SD := preload("res://scripts/data/story_data.gd")

const KERKER := "res://scenes/maps/archief_ingang.tscn"
const REST := "res://world_warper/kamers/rustkamer.tscn"
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const SEED := 4242
## Zelfde extra marge als de echte tik op RUN (touch_controls.gd).
const RUN_HIT_EXTRA := 2.0
## Notch-proef: links, boven, rechts, onder. Op headless is het platform-inset 0.
const NOTCH := Vector4(12, 10, 16, 8)

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 180 s", false)
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
	var kf := _verdieping(GK.SOORT_KOOPMAN)
	check("koopmanverdieping gevonden (seed %d -> %d)" % [SEED, kf], kf > 1 and GK.kamer_soort(SEED, kf) == GK.SOORT_KOOPMAN)
	var kamers: Array[Dictionary] = [
		{"naam": "kerker", "pad": KERKER, "spawn": "ingang"},
		{"naam": "rest", "pad": REST, "spawn": "ingang"},
		{"naam": "koopman", "pad": DUNGEON, "spawn": "omhoog", "verdieping": kf},
	]
	for kamer in kamers:
		await _kamer(kamer)
	UiTouchC.insets_override = null
	print("RUNKNOPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _verdieping(soort: String) -> int:
	for f in range(2, 100):
		if GK.kamer_soort(SEED, f) == soort:
			return f
	return -1


func _kamer(kamer: Dictionary) -> void:
	var naam := str(kamer["naam"])
	var pad := str(kamer["pad"])
	_voorbereiden()
	if kamer.has("verdieping"):
		GameState.dungeon100_seed = SEED
		GameState.dungeon100_floor = int(kamer["verdieping"])
	var gestart: bool = GameState.change_map(pad, str(kamer["spawn"]))
	var ok: bool = await _wacht(func() -> bool:
		var s := _scene()
		return s != null and s.scene_file_path == pad and s.is_node_ready() and not GameState.changing_map, 20.0)
	_stil_monsters()
	await _wacht_fade()
	await _pframes(8)
	await _sluit_dialoog()
	await _wacht(func() -> bool: return not Story.running and not Dialog.is_open, 8.0)
	await _pframes(6)
	_stil_monsters()
	var s := _scene()
	var soort_ok := _soort_klopt(naam, s, kamer)
	check("%s: kamer geladen (%s)" % [naam, pad.get_file()], gestart and ok and soort_ok)
	var t := _touch()
	var rect := Rect2()
	if t != null:
		rect = t.run_rect()
	var aanwezig: bool = t != null and rect.size.x > 1.0 and rect.size.y > 1.0
	check("%s: RUN-knop aanwezig" % naam, aanwezig)
	if t == null:
		check("%s: RUN-knop zichtbaar" % naam, false)
		check("%s: RUN-knop binnen het veilige gebied" % naam, false)
		check("%s: RUN-knop tikbaar (>= %.0f)" % [naam, UiTouchC.TOUCH_MIN], false)
		return
	var zichtbaar: bool = t.is_visible_in_tree() and bool(t.show_run) and bool(t.show_menu)
	check("%s: RUN-knop zichtbaar (show_run, laag aan)" % naam, zichtbaar)
	var safe := _safe(t)
	var binnen := _within(rect, safe)
	UiTouchC.insets_override = NOTCH
	t.refit()
	await _pframes(2)
	var notch_rect: Rect2 = t.run_rect()
	var notch_safe := _safe(t)
	var met_notch := _within(notch_rect, notch_safe)
	UiTouchC.insets_override = null
	t.refit()
	await _pframes(1)
	check("%s: RUN-knop binnen het veilige gebied (vlak %s in %s, met notch %s in %s)" % [naam, rect, safe, notch_rect, notch_safe],
			binnen and met_notch)
	var hit: Rect2 = UiTouchC.hit_rect(t.run_rect(), RUN_HIT_EXTRA)
	var tikbaar: bool = UiTouchC.big_enough(hit) and hit.has_point(t.run_rect().get_center()) and _tik_pakt_run(t)
	check("%s: RUN-knop tikbaar (vlak %s >= %.0f)" % [naam, hit.size, UiTouchC.TOUCH_MIN], tikbaar and zichtbaar)
	await _screenshot(naam)
	if t.has_method("release_all"):
		t.release_all()


## Zelfde stille start als de andere kamertests: voorbij de proloog, geen encounters, geen hub-intro.
func _voorbereiden() -> void:
	UiTouchC.insets_override = null
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.story_flags["archief_gezien"] = true
	GameState.story_flags["world_warper_intro_seen"] = true
	GameState.encounter_multiplier = 0.0
	GameState.in_battle = false
	if Settings.has_method("set_value"):
		Settings.set_value("run", false)


func _soort_klopt(naam: String, s: Node, kamer: Dictionary) -> bool:
	if s == null:
		return false
	if naam == "kerker":
		return str(s.get("room_id")) == "archief_ingang"
	if naam == "rest":
		return str(s.get("map_name")) == "The Rest Room"
	if naam == "koopman":
		return str(s.get("kamer_soort")) == GK.SOORT_KOOPMAN and int(s.get("floor_no")) == int(kamer.get("verdieping", -1))
	return false


func _stil_monsters() -> void:
	var s := _scene()
	if s == null or not ("monsters" in s):
		return
	for m in s.monsters:
		if is_instance_valid(m) and "moves" in m:
			m.moves = false


func _touch() -> Control:
	var s := _scene()
	if s == null:
		return null
	return s.get_node_or_null("TouchControls/Control") as Control


func _safe(t: Control) -> Rect2:
	return UiTouchC.safe_rect(t.size, t.get_viewport())


func _within(r: Rect2, bounds: Rect2) -> bool:
	return r.position.x >= bounds.position.x - 0.5 and r.position.y >= bounds.position.y - 0.5 \
			and r.end.x <= bounds.end.x + 0.5 and r.end.y <= bounds.end.y + 0.5


## Echte tik midden op de RUN-knop: de laag moet de vinger als "run" claimen.
func _tik_pakt_run(t: Control) -> bool:
	var ev := InputEventScreenTouch.new()
	ev.index = 4
	ev.pressed = true
	ev.position = t.get_global_transform_with_canvas() * t.run_rect().get_center()
	t._input(ev)
	var ok := str(t._touch_owner.get(4, "")) == "run"
	var los := ev.duplicate()
	los.pressed = false
	t._input(los)
	return ok


func _scene() -> Node:
	return get_tree().current_scene


func _pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wacht(cond: Callable, timeout := 8.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _wacht_fade() -> void:
	await _wacht(func() -> bool: return Transition._rect.color.a <= 0.01, 4.0)
	await _pframes(2)


func _sluit_dialoog() -> void:
	var n := 0
	while Dialog.is_open and n < 40:
		Dialog.cancel()
		await _pframes(2)
		n += 1


func _screenshot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join("run_" + naam + ".png"))
	print("INFO  screenshot: ", shots.path_join("run_" + naam + ".png"))
