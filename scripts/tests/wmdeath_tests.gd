extends Node
## Regressie: geen softlock na GAME OVER op de wereldkaart (WM1) wanneer het respawn-bericht
## achter het wereldkaart-filmpje opent (checkpoint vóór cutscene-vlag).
## Start: godot --path . -- --wmdeathtest

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const Cutscene := preload("res://scripts/worldmap_cutscene.gd")
const WILGENDAL := "res://scenes/maps/wilgendal.tscn"
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(7617)
	get_tree().create_timer(420.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 420 s", false)
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
	await _softlock_scenario()
	Cutscene.allow_in_tests = false
	print("WMDEATHTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(20)
	get_tree().quit(1 if failures else 0)


func _softlock_scenario() -> void:
	Cutscene.allow_in_tests = true
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	h["mp"] = h["max_mp"]
	GameState.story_flags.erase(Cutscene.FLAG)
	check("vlag cutscene gewist", not GameState.story_flags.has(Cutscene.FLAG))
	var home := await enter(WILGENDAL, "start")
	check("Wilgendal geladen", home != null)
	if home == null:
		return
	var w := await enter(WORLD, "van_dorp")
	check("wereldkaart (van_dorp)", w != null)
	if w == null:
		return
	var c: Node = w.get_node_or_null("WorldmapCutscene")
	check("eerste bezoek: filmpje start", c != null)
	if c == null:
		return
	await get_tree().create_timer(Cutscene.SKIP_GRACE + 0.05).timeout
	await skip_action("interact")
	await pframes(4)
	check("filmpje over na skip", not is_instance_valid(c) or c.is_done())
	check("vlag gezet na filmpje", GameState.story_flags.has(Cutscene.FLAG))
	var cp_state: Dictionary = GameState.checkpoint.get("state", {})
	var cp_flags: Dictionary = cp_state.get("story_flags", {})
	check("checkpoint-state zonder cutscene-vlag (repro-basis)", not cp_flags.has(Cutscene.FLAG))
	var start := tile()
	GameState.debug_force_group = ["glitchmot", "glitchmot", "glitchmot"]
	await tap("debug_battle")
	check("gevecht op de wereldkaart", await wait_scene("Battle"))
	var over := await lose_battle()
	GameState.debug_force_group = []
	check("GAME OVER gezien", over.begins_with("GAME OVER"))
	check("terug op wereldkaart na respawn", await wait_scene("Wereldkaart"))
	await pframes(5)
	check("cutscene-vlag overleeft respawn", GameState.story_flags.has(Cutscene.FLAG))
	check("geen tweede filmpje-node", scene().get_node_or_null("WorldmapCutscene") == null)
	check("geen tweede filmpje (should_play)", not Cutscene.should_play(WORLD))
	check("respawn-tile = binnenkomst %s (nu %s)" % [start, tile()], tile() == start)
	var line := await respawn_line()
	check("respawn-bericht open", line.begins_with("The Current pulls you back"))
	var p := player()
	await close_dialog()
	await pframes(6)
	check("speler niet input_locked na bericht", p != null and not p.input_locked)
	var pos0 := p.position
	await walk("move_left", 1)
	await pframes(3)
	check("speler beweegt weer", p != null and p.position.distance_to(pos0) > 0.5)


# ================================================================ helpers
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


static func node_name_of(path: String) -> String:
	var out := ""
	for p in path.get_file().get_basename().split("_"):
		out += p.capitalize().replace(" ", "")
	return out


func enter(path: String, spawn: String) -> Node:
	if Dialog.is_open:
		Dialog.close()
	GameState.change_map(path, spawn)
	if not await wait_scene(node_name_of(path)):
		return null
	await wait_fade()
	return scene()


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var pl := player()
		if pl == null or scene() != start_scene or GameState.changing_map or GameState.in_battle:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(pl) and not pl.is_moving and waited < 8:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(pl) and pl.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open or GameState.in_battle:
			return


func tap(action: String) -> void:
	await pframes(1)
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(2)


func skip_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(2)


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


func lose_battle() -> String:
	var over := ""
	Engine.time_scale = 3.0
	for guard in 200:
		var st := await wait_battle_state(["command", "message_wait"], 40)
		if st == "" or battle() == null:
			break
		var b := battle()
		if st == "command":
			for hero in GameState.party:
				hero["hp"] = mini(int(hero["hp"]), 1)
			await cross_to(b, 3)
			await tap("interact")
		else:
			if "GAME OVER" in b.message_label.text:
				over = b.message_label.text
			await tap("interact")
	Engine.time_scale = 1.0
	return over


func respawn_line() -> String:
	if not await wait_until(func(): return Dialog.is_open, 4.0):
		return ""
	return str(Dialog._lines[0]) if not Dialog._lines.is_empty() else ""


func close_dialog() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		if not Dialog.is_open:
			return
		if Dialog._is_typing():
			await frames(2)
			continue
		await tap("interact")
