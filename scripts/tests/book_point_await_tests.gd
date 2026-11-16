extends Node
## book_point await-guards (--bookpointawaittest): object verdwijnt of kaart wisselt terwijl interact loopt.
## Start: godot --path . -- --bookpointawaittest

const SD := preload("res://scripts/data/story_data.gd")
const BookData := preload("res://scripts/data/book_data.gd")
const BookPointScene := preload("res://scenes/book_point.tscn")
const TITLE := "res://scenes/ui/title.tscn"

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
	await _wacht_preload()
	await _test_release_during_interact()
	await _test_map_change_during_deferred_uitleg()
	await _test_go_to_title_during_ask_slot()
	print("BOOKPOINTAWAITTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await _pframes(5)
	get_tree().quit(1 if failures else 0)


func _wacht_preload() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000.0:
		if GameState._preloading.is_empty():
			return
		await get_tree().process_frame


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _wait_until(cond: Callable, timeout := 8.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _mock_player() -> Node2D:
	var pl := Node2D.new()
	pl.set_script(preload("res://scripts/tests/book_point_await_mock_player.gd"))
	pl.name = "MockPlayer"
	get_tree().root.add_child(pl)
	return pl


func _try_player() -> Node:
	var sc := get_tree().current_scene
	if sc == null:
		return null
	return sc.get_node_or_null("Objects/Player")


func _flow_clean(label: String) -> void:
	check("%s: Dialog dicht" % label, not Dialog.is_open)
	check("%s: Story niet actief" % label, not Story.running)
	check("%s: FlowState veld vrij" % label, GameState.field_free())
	var pl := _try_player()
	if pl != null and "input_locked" in pl:
		check("%s: geen input-lock op speler" % label, not pl.input_locked)
	else:
		check("%s: geen input-lock (geen veldspeler)" % label, true)


func _ensure_dialog_gone() -> void:
	if Dialog.is_open:
		Dialog.close()
	Story.running = false
	await _pframes(3)


## Boekpunt weg tijdens await van interact (regel vóór save-vraag).
func _test_release_during_interact() -> void:
	print("=== vrijgeven tijdens interact ===")
	await _ensure_dialog_gone()
	GameState.new_game("T")
	var bp: Node = BookPointScene.instantiate()
	bp.type = "save"
	get_tree().root.add_child(bp)
	await _pframes(4)
	var pl := _mock_player()
	bp.interact(pl)
	var ok_open := await _wait_until(func(): return Dialog.is_open, 5.0)
	check("interact opent tekstvak", ok_open)
	await _pframes(2)
	bp.queue_free()
	await _pframes(20)
	pl.queue_free()
	_flow_clean("vrijgeven tijdens interact")


## Kaart wisselen terwijl _deferred_save_uitleg wacht op Dialog.finished.
func _test_map_change_during_deferred_uitleg() -> void:
	print("=== kaartwissel tijdens _deferred_save_uitleg ===")
	await _ensure_dialog_gone()
	GameState.new_game("T")
	GameState.story_step = SD.NACHT
	GameState.story_flags.erase(SD.SAVE_UITLEG_FLAG)
	GameState.change_map("res://scenes/maps/huis_wilgendal.tscn", "bed")
	var huis_ok := await _wait_until(func() -> bool:
		var s := get_tree().current_scene
		return s != null and s.name == "Huis" and s.is_node_ready() and not GameState.changing_map, 15.0)
	check("huis voor deferred-uitleg", huis_ok)
	await _pframes(15)
	var book: Node = get_tree().current_scene.get_node_or_null("Objects/SaveBook")
	check("SaveBook aanwezig", book != null)
	if book == null:
		return
	var pl := _try_player()
	book.interact(pl)
	await _wait_until(func(): return Dialog.is_open and not Dialog._is_typing(), 6.0)
	await _advance_to_save_question()
	if Dialog.has_choices():
		Dialog.choose(1)  # Nee -> timer -> _deferred_save_uitleg
	await _wait_until(func(): return Dialog.is_open and str(Dialog._lines).contains(SD.SAVE_UITLEG_LINE), 8.0)
	check("save-uitleg na Nee", str(Dialog._lines).contains(SD.SAVE_UITLEG_LINE))
	GameState.change_map("res://scenes/maps/wereldkaart.tscn", "start")
	await _wait_until(func(): return not GameState.changing_map, 12.0)
	await _pframes(25)
	_flow_clean("kaartwissel tijdens _deferred_save_uitleg")


## Titelscherm tijdens ask_slot (na 'Other slot').
func _test_go_to_title_during_ask_slot() -> void:
	print("=== go_to_title tijdens ask_slot ===")
	await _ensure_dialog_gone()
	GameState.new_game("T")
	GameState.story_step = SD.NACHT
	GameState.change_map("res://scenes/maps/huis_wilgendal.tscn", "bed")
	var huis_ok := await _wait_until(func() -> bool:
		var s := get_tree().current_scene
		return s != null and s.name == "Huis" and s.is_node_ready() and not GameState.changing_map, 15.0)
	check("huis geladen voor ask_slot", huis_ok)
	await _pframes(15)
	var book: Node = get_tree().current_scene.get_node_or_null("Objects/SaveBook")
	check("SaveBook aanwezig", book != null)
	if book == null:
		return
	var pl := _try_player()
	if pl == null:
		pl = _mock_player()
	book.interact(pl)
	await _wait_until(func(): return Dialog.is_open and not Dialog._is_typing(), 6.0)
	await _advance_to_save_question()
	if Dialog.has_choices():
		Dialog.choose(2)  # Other slot
	await _wait_until(func() -> bool:
		return Dialog.is_open and Dialog.has_choices() and "which slot" in str(Dialog._lines).to_lower(), 6.0)
	check("slotkiezer open vóór go_to_title", Dialog.has_choices())
	GameState.go_to_title(true)
	await _wait_until(func() -> bool:
		var s := get_tree().current_scene
		return s != null and s.scene_file_path == TITLE, 12.0)
	await _pframes(20)
	_flow_clean("go_to_title tijdens ask_slot")


func _advance_to_save_question() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		if Dialog.has_choices():
			return
		if Dialog.is_open and not Dialog._is_typing():
			await _press_interact()
			continue
		await _pframes(2)


func _press_interact() -> void:
	Input.action_press("interact")
	await _pframes(2)
	Input.action_release("interact")
	await _pframes(2)