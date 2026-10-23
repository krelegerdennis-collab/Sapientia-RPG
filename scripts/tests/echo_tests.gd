extends Node
## ECHO quest log (--echotest): actieve/klaar-tabs, doel in detail, Story.event_finished, save/load.
## Start: godot --path . -- --echotest [--shots=/pad/map]

const QD := preload("res://scripts/data/quest_data.gd")
const QLScherm := preload("res://scripts/ui/questlog_screen.gd")
const SD := preload("res://scripts/data/story_data.gd")
const MenuScreen := preload("res://scripts/ui/menu_screen.gd")

const TOUCH_MIN := 24

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_voortgang_tests()
	await _scherm_tests()
	_save_tests()
	print("ECHOTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _voortgang_tests() -> void:
	GameState.new_game("Dax")
	check("nieuw spel: geen voortgang", GameState.quest_progress.is_empty())
	GameState.story_step = SD.START
	Story.event_finished.emit("achterna")
	check("gestart: stap via event_finished", (GameState.quest_progress.get("archieven_in", {}).get("steps", []) as Array).has("achterna"))
	var actief := QD.voor_tab("akte_1", "actief", GameState.story_flags, GameState.story_step, GameState.quest_progress)
	var titels := actief.map(func(q): return str(q["title"]))
	check("actief: The Archives of Sapientia zichtbaar", titels.has("The Archives of Sapientia"))
	check("actief: nog niet klaar", not QD.quest_klaar(QD.quest("archieven_in"), GameState.story_flags,
			GameState.story_step, GameState.quest_progress))
	GameState.story_step = SD.NACHT
	GameState.quest_sync()
	check("klaar: The Archives of Sapientia in Done-tab", QD.voor_tab("akte_1", "klaar", GameState.story_flags,
			GameState.story_step, GameState.quest_progress).any(func(q): return str(q["id"]) == "archieven_in"))
	check("actief: The Archives of Sapientia weg", not QD.voor_tab("akte_1", "actief", GameState.story_flags,
			GameState.story_step, GameState.quest_progress).any(func(q): return str(q["id"]) == "archieven_in"))


func _scherm_tests() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.START
	Story.event_finished.emit("achterna")
	var scherm: CanvasLayer = QLScherm.new()
	scherm.layer = 120
	get_tree().root.add_child(scherm)
	await _pframes(5)
	check("schermtitel ECHO", scherm.header.text == QD.TITEL and QD.TITEL == "ECHO")
	check("detail: current objective", scherm.detail.text.contains(QD.OBJECTIVE_LABEL))
	var groot: bool = scherm.rows.all(func(b): return b.custom_minimum_size.y >= TOUCH_MIN)
	for t in scherm.tab_buttons.values():
		groot = groot and (t as Button).custom_minimum_size.y >= TOUCH_MIN
	check("tikvlakken >= %d px" % TOUCH_MIN, groot)
	await _screenshot("echo_questlog_actief")
	scherm.queue_free()


func _save_tests() -> void:
	var pad := "user://echotest_save.json"
	GameState.new_game("Dax")
	GameState.story_step = SD.START
	Story.event_finished.emit("achterna")
	var voor: Dictionary = GameState.quest_progress.duplicate(true)
	check("voor save: stap achterna", (voor.get("archieven_in", {}).get("steps", []) as Array).has("achterna"))
	var ok := GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, pad)
	GameState.new_game("Dax")
	check("nieuw spel wist quests", GameState.quest_progress.is_empty())
	var geladen := GameState.load_game(pad)
	check("load: quest_progress terug", geladen and GameState.quest_progress == voor)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))
