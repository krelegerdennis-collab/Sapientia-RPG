extends Node
## ALLEEN VOOR TESTEN - mobiele pauze-save + atomair schrijven + herstel (compacte suite).
## Start: godot --path . -- --saverobusttest
##   Pauze/close-notificaties, corrupte save -> .bak, achtergebleven .tmp, schone mislukking zonder crash.

const TOWN := "res://scenes/maps/wilgendal.tscn"
const SAVE := "user://saverobusttest_save_1.json"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.encounter_multiplier = 0.0
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


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _notify(what: int) -> void:
	get_tree().root.propagate_notification(what)


func _good_save_text(gold: int) -> String:
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.gold = gold
	GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, SAVE)
	return FileAccess.get_file_as_string(SAVE)


func _run() -> void:
	await _wacht_preload()
	_atomic_tests()
	_corruption_tests()
	await _notification_tests()
	_remove_save(SAVE)
	print("SAVEROBUSTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _wacht_preload() -> void:
	var t := 0.0
	while not GameState._preloading.is_empty() and t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()


func _atomic_tests() -> void:
	_remove_save(SAVE)
	GameState.new_game("Dax")
	GameState.current_map = TOWN
	GameState.gold = 11
	check("atomaire save schrijft geld 11", GameState.save_game(Vector2i(1, 1), Vector2i.DOWN, SAVE)
			and int(GameState._read_save_file(SAVE).get("gold", -1)) == 11)
	GameState.gold = 22
	check("tweede save: reservekopie bewaart 11",
			GameState.save_game(Vector2i(2, 2), Vector2i.UP, SAVE)
			and int(GameState._read_save_file(SAVE + ".bak").get("gold", -1)) == 11
			and not FileAccess.file_exists(SAVE + ".tmp"))
	_write(SAVE + ".tmp", "{\"gold\":")
	GameState.gold = 33
	check("halve .tmp blokkeert volgende save niet",
			GameState.save_game(Vector2i(3, 3), Vector2i.LEFT, SAVE)
			and not FileAccess.file_exists(SAVE + ".tmp")
			and int(GameState._read_save_file(SAVE).get("gold", -1)) == 33)


func _corruption_tests() -> void:
	_remove_save(SAVE)
	var good := _good_save_text(50)
	_write(SAVE + ".bak", good)
	_write(SAVE, "{\"map\":")
	GameState.new_game("Dax")
	GameState.gold = 0
	var recovered: Array = []
	var on_rec := func(p: String, bak: String) -> void: recovered.append([p, bak])
	GameState.save_recovered.connect(on_rec)
	check("afgekapte hoofd-save laadt .bak (goud 50)",
			GameState.load_game(SAVE) and GameState.gold == 50)
	GameState.save_recovered.disconnect(on_rec)
	check("herstel meldt save_recovered", recovered.size() == 1 and recovered[0][1].ends_with(".bak"))
	check("last_load_notice is hersteltekst",
			GameState.last_load_notice == GameState.NOTICE_RECOVERED)
	check("succesvol laden ruimt achtergebleven .tmp op",
			not FileAccess.file_exists(SAVE + ".tmp"))
	_remove_save(SAVE)
	_write(SAVE, "garbage")
	_write(SAVE + ".bak", "also garbage")
	GameState.new_game("Dax")
	var before := GameState.gold
	check("beide kapot: load_game false, geen crash",
			not GameState.load_game(SAVE) and GameState.last_load_notice == GameState.NOTICE_UNREADABLE
			and GameState.gold == before)


func _notification_tests() -> void:
	var orig_autosave := Settings.autosave_enabled()
	_remove_save(GameState.autosave_path)
	GameState.new_game("Dax")
	GameState.story_step = preload("res://scripts/data/story_data.gd").KLAAR
	GameState.change_map(TOWN, "start")
	var ok := await _wait_scene("Wilgendal")
	check("kaart geladen voor pauze-save", ok)
	if not ok:
		Settings.set_value("autosave", orig_autosave)
		return
	await _frames(15)
	var n0 := GameState.autosave_count
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("PAUSED schrijft pauze-save (achtergrond)",
			GameState.autosave_count == n0 + 1
			and GameState.last_autosave_reason == "achtergrond"
			and FileAccess.file_exists(GameState.autosave_path))
	var n1 := GameState.autosave_count
	_notify(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check("WM_CLOSE_REQUEST schrijft pauze-save wanneer veilig",
			GameState.autosave_count == n1 + 1
			and GameState.last_autosave_reason == "achtergrond")
	Settings.set_value("autosave", false)
	var n2 := GameState.autosave_count
	_notify(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check("WM_CLOSE met autosave-optie uit: pauze-save blijft verplicht",
			GameState.autosave_count == n2 + 1
			and GameState.last_autosave_reason == "achtergrond")
	Settings.set_value("autosave", true)
	var blocked := GameState.autosave_count
	GameState.in_battle = true
	_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
	_notify(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	GameState.in_battle = false
	check("gevecht: pauze/close schrijven niet", GameState.autosave_count == blocked)
	var story := get_node_or_null("/root/Story")
	if story != null:
		story.running = true
		_notify(Node.NOTIFICATION_APPLICATION_PAUSED)
		_notify(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		story.running = false
	check("cutscene: pauze/close schrijven niet", GameState.autosave_count == blocked)
	Settings.set_value("autosave", orig_autosave)
