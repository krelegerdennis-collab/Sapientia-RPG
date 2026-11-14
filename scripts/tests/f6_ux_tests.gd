extends Node
## F6-6: change_map blijft niet op zwart hangen als het doelpad ontbreekt (--f6uxtest).
## F6-6b: een deur zet input pas vast als change_map echt start.
## F6-7: een tweede show_lines wacht in een wachtrij en steelt een open ask niet.
## Start: godot --path . -- --f6uxtest

const TOWN := "res://scenes/maps/wilgendal.tscn"
const MISSING := "res://scenes/maps/f66_bestaat_niet.tscn"
const DOOR_SCENE := preload("res://scenes/door.tscn")
const SD := preload("res://scripts/data/story_data.gd")
## Eén tegelstap is 16 px bij 64 px/s (~15 frames op 60 Hz). Ruim erboven, wel begrensd.
const STAP_FRAMES := 90
const WISSEL_FRAMES := 900

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
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	await _wacht(func() -> bool: return Transition.overlay_alpha() == 0.0, 2.0)
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.in_battle = false
	GameState.changing_map = false
	await _missing_path()
	await _valid_path()
	await _exit_missing()
	await _dialog_queue()
	await _door_missing()
	await _door_valid()
	print("F6UXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


## (1) Ontbrekend pad: false, geen wissel, overlay weer vrij.
func _missing_path() -> void:
	var scene_voor: Node = get_tree().current_scene
	var pad_voor := ""
	if scene_voor != null:
		pad_voor = str(scene_voor.scene_file_path)
	var current_voor := GameState.current_map
	var gestart: bool = GameState.change_map(MISSING, "start")
	check("ontbrekend pad: change_map geeft false", gestart == false)
	check("ontbrekend pad: changing_map blijft false", not GameState.changing_map)
	check("ontbrekend pad: current_map ongewijzigd", GameState.current_map == current_voor)
	await _frames(3)
	var scene_na: Node = get_tree().current_scene
	var pad_na := ""
	if scene_na != null:
		pad_na = str(scene_na.scene_file_path)
	check("ontbrekend pad: scène ongewijzigd", scene_na == scene_voor and pad_na == pad_voor)
	check("ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)
	check("ontbrekend pad: changing_map na frames nog false", not GameState.changing_map)


## (2) Bestaand pad: wissel start, en changing_map zakt weer na de nieuwe scène.
func _valid_path() -> void:
	var voor: Node = get_tree().current_scene
	var pad_voor := "" if voor == null else str(voor.scene_file_path)
	var gestart: bool = GameState.change_map(TOWN, "start")
	check("geldig pad: change_map geeft true", gestart == true)
	check("geldig pad: changing_map aan bij start", GameState.changing_map)
	# Pad als String vastleggen: de oude scène is vrijgegeven zodra de wissel klaar is.
	var ok := await _wacht(func() -> bool:
		var s := get_tree().current_scene
		return s != null and str(s.scene_file_path) == TOWN and str(s.scene_file_path) != pad_voor \
				and s.is_node_ready() and not GameState.changing_map
	, 15.0)
	check("geldig pad: scène gewisseld en changing_map weer false", ok)


## (3) Uitgang naar een ontbrekend pad zet de speler niet op slot.
func _exit_missing() -> void:
	var map := get_tree().current_scene
	if map == null or not map.has_method("_use_exit"):
		check("uitgang: kaart met _use_exit", false)
		return
	var player := map.get_node_or_null("Objects/Player")
	var exits := map.get_node_or_null("Exits")
	if player == null or exits == null or not ("input_locked" in player):
		check("uitgang: speler en Exits aanwezig", false)
		return
	check("uitgang: speler en Exits aanwezig", true)
	player.set("input_locked", false)
	var exit := MapExit.new()
	exit.name = "F66Missing"
	exit.target_map = MISSING
	exit.target_spawn = "start"
	exits.add_child(exit)
	map.call("_use_exit", exit)
	check("uitgang ontbrekend pad: input_locked blijft false", bool(player.get("input_locked")) == false)
	check("uitgang ontbrekend pad: changing_map false", not GameState.changing_map)
	await _frames(3)
	check("uitgang ontbrekend pad: scène ongewijzigd", get_tree().current_scene == map)
	check("uitgang ontbrekend pad: input_locked na frames nog false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("uitgang ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)


## F6-7: wachtrij. Drie controles, plus de story-stijl (show_lines + await finished per regel).
func _dialog_queue() -> void:
	await _drain_dialog()
	await _ask_then_lines()
	await _drain_dialog()
	await _two_lines_in_order()
	await _drain_dialog()
	await _story_style_awaits()
	await _drain_dialog()
	await _two_asks()
	await _drain_dialog()
	await _close_when_shut()
	await _queue_cap()
	await _drain_dialog()
	await _frames(3)
	check("wachtrij leeg en vak dicht na alles", Dialog.queue_empty() and not Dialog.is_open)


## (1) ask met twee keuzes; show_lines tijdens het wachten laat de vraag staan.
## Na een echte keuze is het resultaat 0 of 1, niet -1 en niet stil de standaard.
## De tweede tekst komt daarna.
func _ask_then_lines() -> void:
	var bucket := {"done": false, "value": -99}
	_capture_ask(bucket)
	var opened: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.has_choices()
	, 2.0)
	check("ask: vraag staat open", opened)
	if Dialog.is_open and Dialog.phase() == Dialog.PHASE_TYPING:
		Dialog.advance()
	var waiting: bool = Dialog.is_open and Dialog.phase() == Dialog.PHASE_CHOOSING \
			and Dialog.text_label.text == "Stay or follow?" and Dialog.choices.size() == 2
	check("ask: twee keuzes, vraag blijft leesbaar", waiting)
	Dialog.show_lines(["Other"])
	await _frames(2)
	var stayed: bool = Dialog.is_open and Dialog.has_choices() \
			and Dialog.phase() == Dialog.PHASE_CHOOSING \
			and Dialog.text_label.text == "Stay or follow?" \
			and Dialog.choices.size() == 2 \
			and str(Dialog.choices[0]) == "Stay" and str(Dialog.choices[1]) == "Follow" \
			and not bool(bucket["done"])
	check("show_lines tijdens ask: eerste vraag blijft", stayed)
	# Standaardindex is 0; kies bewust de andere, zodat een stille default faalt.
	Dialog.choose(1)
	var answered: bool = await _wacht(func() -> bool: return bool(bucket["done"]), 2.0)
	var value := int(bucket["value"])
	check("ask-resultaat is 0 of 1, niet -1", answered and (value == 0 or value == 1) and value != -1)
	check("ask-resultaat is de gekozen index, niet de standaard", answered and value == 1)
	var second: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.text_label.text == "Other" and not Dialog.has_choices()
	, 2.0)
	check("tweede tekst komt na de keuze", second)
	_dismiss_one()
	var clear: bool = await _wacht(func() -> bool:
		return Dialog.queue_empty() and not Dialog.is_open
	, 2.0)
	check("na ask + tweede tekst: wachtrij leeg en vak dicht", clear)


## (2) twee show_lines achter elkaar, zonder ask: beide teksten, in volgorde.
## Elke await finished hervat pas nadat díe tekst klaar is.
func _two_lines_in_order() -> void:
	var order: Array = []
	_await_line("First", order)
	_await_line("Second", order)
	var first: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.text_label.text == "First" and order.is_empty()
	, 2.0)
	check("twee show_lines: eerst de eerste tekst", first)
	_dismiss_one()
	var second: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.text_label.text == "Second" \
				and order.size() == 1 and str(order[0]) == "First"
	, 2.0)
	check("twee show_lines: daarna de tweede tekst", second)
	check("wachter van de eerste tekst hervat vóór de tweede klaar is", second)
	_dismiss_one()
	var both: bool = await _wacht(func() -> bool:
		return order.size() == 2 and str(order[0]) == "First" and str(order[1]) == "Second" \
				and Dialog.queue_empty() and not Dialog.is_open
	, 2.0)
	check("twee show_lines: beide teksten af, in volgorde", both)


## Zelfde patroon als story.gd say: show_lines en meteen await finished, daarna de volgende regel.
func _story_style_awaits() -> void:
	var log: Array = []
	_story_chain(log)
	var alpha: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.text_label.text == "Alpha" and log.is_empty()
	, 2.0)
	check("story-stijl: eerste regel open", alpha)
	_dismiss_one()
	var beta: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.text_label.text == "Beta" \
				and log.size() == 1 and str(log[0]) == "a"
	, 2.0)
	check("story-stijl: tweede regel pas na finished van de eerste", beta)
	_dismiss_one()
	var done: bool = await _wacht(func() -> bool:
		return log.size() == 2 and str(log[1]) == "b" and Dialog.queue_empty() and not Dialog.is_open
	, 2.0)
	check("story-stijl: beide awaits hervatten na hun eigen regel", done)


## Twee asks: de tweede komt binnen terwijl de eerste nog open is.
## Beide keren de gekozen index terug, nooit -1, en in die volgorde.
func _two_asks() -> void:
	var first := {"done": false, "value": -99}
	var second := {"done": false, "value": -99}
	_capture_ask_at(first, "First question?", ["Stay", "Follow"])
	var opened: bool = await _wacht(func() -> bool:
		return Dialog.is_open and Dialog.has_choices() and Dialog.text_label.text == "First question?"
	, 2.0)
	check("twee asks: eerste vraag open", opened)
	if Dialog.is_open and Dialog.phase() == Dialog.PHASE_TYPING:
		Dialog.advance()
	_capture_ask_at(second, "Second question?", ["Yes", "No"])
	await _frames(2)
	var stayed: bool = Dialog.is_open and Dialog.phase() == Dialog.PHASE_CHOOSING \
			and Dialog.text_label.text == "First question?" and Dialog.choices.size() == 2 \
			and not bool(first["done"]) and not bool(second["done"])
	check("twee asks: tweede wacht, eerste vraag blijft", stayed)
	Dialog.choose(0)
	var first_done: bool = await _wacht(func() -> bool:
		return bool(first["done"]) and int(first["value"]) == 0 \
				and Dialog.is_open and Dialog.text_label.text == "Second question?" \
				and Dialog.has_choices() and not bool(second["done"])
	, 2.0)
	check("twee asks: eerste geeft 0, daarna de tweede vraag", first_done)
	if Dialog.is_open and Dialog.phase() == Dialog.PHASE_TYPING:
		Dialog.advance()
	Dialog.choose(1)
	var second_done: bool = await _wacht(func() -> bool:
		return bool(second["done"]) and int(second["value"]) == 1 and int(second["value"]) != -1 \
				and int(first["value"]) == 0 and Dialog.queue_empty() and not Dialog.is_open
	, 2.0)
	check("twee asks: tweede geeft 1, niet -1", second_done)


## close() op een vak dat al dicht is geeft nog steeds finished, en opent niets.
func _close_when_shut() -> void:
	var woke := {"done": false}
	check("dicht voor extra close", not Dialog.is_open and Dialog.queue_empty())
	_note_finished(woke)
	Dialog.close()
	var ok: bool = await _wacht(func() -> bool: return bool(woke["done"]), 2.0)
	check("close op een dicht vak geeft finished", ok)
	await _frames(2)
	check("close op een dicht vak laat het vak dicht", not Dialog.is_open and Dialog.queue_empty() and ok)


## Het 33e verzoek (bovenop het open vak) wordt niet getoond.
func _queue_cap() -> void:
	Dialog.show_lines(["Head"])
	for i in Dialog.QUEUE_MAX:
		Dialog.show_lines(["Slot %d" % i])
	Dialog.show_lines(["Overflow"])
	var seen: Array = []
	var guard := 0
	while (Dialog.is_open or not Dialog.queue_empty()) and guard < Dialog.QUEUE_MAX + 4:
		if Dialog.is_open and Dialog.phase() == Dialog.PHASE_TYPING:
			Dialog.advance()
		if Dialog.is_open:
			seen.append(str(Dialog.text_label.text))
			Dialog.advance()
		guard += 1
	var overflow := false
	for line in seen:
		if str(line) == "Overflow":
			overflow = true
	var order_ok := seen.size() == Dialog.QUEUE_MAX + 1 and str(seen[0]) == "Head" \
			and str(seen[seen.size() - 1]) == "Slot %d" % (Dialog.QUEUE_MAX - 1)
	check("wachtrij-limiet: overflow niet getoond", not overflow and order_ok)
	check("wachtrij-limiet: daarna leeg en dicht", Dialog.queue_empty() and not Dialog.is_open)


func _capture_ask(bucket: Dictionary) -> void:
	bucket["value"] = await Dialog.ask("Stay or follow?", ["Stay", "Follow"], "", 0)
	bucket["done"] = true


func _capture_ask_at(bucket: Dictionary, question: String, options: Array) -> void:
	bucket["value"] = await Dialog.ask(question, options, "", 0)
	bucket["done"] = true


func _note_finished(bucket: Dictionary) -> void:
	await Dialog.finished
	bucket["done"] = true


func _await_line(line: String, order: Array) -> void:
	Dialog.show_lines([line])
	await Dialog.finished
	order.append(line)


func _story_chain(log: Array) -> void:
	Dialog.show_lines(["Alpha"])
	await Dialog.finished
	log.append("a")
	Dialog.show_lines(["Beta"])
	await Dialog.finished
	log.append("b")


func _dismiss_one() -> void:
	if not Dialog.is_open:
		return
	if Dialog.phase() == Dialog.PHASE_TYPING:
		Dialog.advance()
	if Dialog.phase() == Dialog.PHASE_CHOOSING:
		Dialog.choose(0)
		return
	if Dialog.is_open:
		Dialog.advance()


func _drain_dialog() -> void:
	var guard := 0
	while (Dialog.is_open or not Dialog.queue_empty()) and guard < 40:
		_dismiss_one()
		guard += 1
		await get_tree().process_frame


## (4) Deur naar een ontbrekend pad: niet vast, geen scriptfout, lopen en opnieuw proberen kan.
func _door_missing() -> void:
	var map := get_tree().current_scene
	var player := map.get_node_or_null("Objects/Player") if map != null else null
	var objects := map.get_node_or_null("Objects") if map != null else null
	if player == null or objects == null or not ("input_locked" in player) or not player.has_method("get_tile"):
		check("deur ontbrekend: speler aanwezig", false)
		return
	check("deur ontbrekend: speler aanwezig", true)
	player.set("input_locked", false)
	var door := DOOR_SCENE.instantiate() as Node2D
	door.name = "F66MissingDoor"
	door.set("target_map", MISSING)
	door.set("target_spawn", "start")
	door.position = Vector2(-160, -160)
	objects.add_child(door)
	var kaart_voor := str(map.scene_file_path)
	door.call("_enter", player)
	check("deur ontbrekend pad: input_locked blijft false", bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: changing_map false", not GameState.changing_map)
	check("deur ontbrekend pad: beweging niet op slot", str(player.call("movement_state")) != "locked")
	await _frames(3)
	check("deur ontbrekend pad: scène ongewijzigd", get_tree().current_scene == map)
	check("deur ontbrekend pad: input_locked na frames nog false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: overlay alpha 0", Transition.overlay_alpha() == 0.0)
	# Opnieuw proberen mag nog steeds geen vastzetting of wissel starten.
	door.call("_enter", player)
	check("deur ontbrekend pad: tweede poging input_locked false",
			is_instance_valid(player) and bool(player.get("input_locked")) == false)
	check("deur ontbrekend pad: tweede poging changing_map false", not GameState.changing_map)
	check("deur ontbrekend pad: tweede poging scène ongewijzigd",
			get_tree().current_scene == map and str(map.scene_file_path) == kaart_voor)
	var gelopen := await _stap_vrij(player)
	check("deur ontbrekend pad: speler kan nog een tegel lopen", gelopen)
	check("deur ontbrekend pad: na het lopen nog vrij en op dezelfde kaart",
			is_instance_valid(player) and bool(player.get("input_locked")) == false
			and get_tree().current_scene == map and not GameState.changing_map)
	if is_instance_valid(door):
		door.queue_free()


## (5) Deur naar een bestaand pad: input vast en de wissel loopt zoals eerder.
func _door_valid() -> void:
	var map := get_tree().current_scene
	var player := map.get_node_or_null("Objects/Player") if map != null else null
	var door := map.get_node_or_null("Objects/Door") if map != null else null
	if player == null or door == null or not door.has_method("_enter") or not ("input_locked" in player):
		check("deur geldig: speler en Door aanwezig", false)
		return
	check("deur geldig: speler en Door aanwezig", true)
	_los_richting()
	if bool(player.get("is_moving")):
		await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or not bool(player.get("is_moving"))
		, STAP_FRAMES)
	player.set("input_locked", false)
	var doel := str(door.get("target_map"))
	var pad_voor := str(map.scene_file_path)
	door.call("_enter", player)
	check("deur geldig pad: input_locked", is_instance_valid(player) and bool(player.get("input_locked")))
	check("deur geldig pad: changing_map aan bij start", GameState.changing_map)
	check("deur geldig pad: doel verschilt van de huidige kaart", doel != "" and doel != pad_voor)
	var ok := await _wacht_frames(func() -> bool:
		var s := get_tree().current_scene
		return s != null and str(s.scene_file_path) == doel and str(s.scene_file_path) != pad_voor \
				and s.is_node_ready() and not GameState.changing_map
	, WISSEL_FRAMES)
	check("deur geldig pad: scène gewisseld en changing_map weer false", ok)


## Eén tegel lopen via invoer (niet omhoog: daar staat de huisdeur). Begrensd in frames.
func _stap_vrij(player: Node) -> bool:
	if not is_instance_valid(player) or bool(player.get("input_locked")):
		return false
	var van: Vector2i = player.call("get_tile")
	for actie in ["move_down", "move_left", "move_right"]:
		Input.action_press(actie)
		var begon := false
		for _i in 8:
			await get_tree().process_frame
			if not is_instance_valid(player) or GameState.changing_map:
				Input.action_release(actie)
				return false
			if player.call("get_tile") != van or bool(player.get("is_moving")):
				begon = true
				break
		if not begon:
			Input.action_release(actie)
			continue
		var klaar := await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or player.call("get_tile") != van
		, STAP_FRAMES)
		Input.action_release(actie)
		if not klaar or not is_instance_valid(player):
			_los_richting()
			return false
		await _wacht_frames(func() -> bool:
			return not is_instance_valid(player) or not bool(player.get("is_moving"))
		, STAP_FRAMES)
		_los_richting()
		return is_instance_valid(player) and player.call("get_tile") != van \
				and not bool(player.get("input_locked")) and not GameState.changing_map
	_los_richting()
	return false


func _los_richting() -> void:
	for actie in ["move_up", "move_down", "move_left", "move_right"]:
		if InputMap.has_action(actie):
			Input.action_release(actie)


func _wacht_frames(cond: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _wacht(cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
