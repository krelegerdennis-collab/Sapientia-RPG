extends CanvasLayer
## Continue / Leave na een wave, en het resultaatscherm. Tikknoppen op 48dp.

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiTouch := preload("res://scripts/ui/ui_touch.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const LOBBY := "res://scenes/maps/arena_lobby.tscn"

var run: Node
var box: VBoxContainer


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := UiMenu.panel()
	panel.name = "ArenaPanel"
	panel.offset_left = 48.0
	panel.offset_top = 36.0
	panel.offset_right = 336.0
	panel.offset_bottom = 210.0
	root.add_child(panel)
	box = VBoxContainer.new()
	box.name = "Choices"
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)


func bind(arena: Node) -> void:
	run = arena
	if not run.phase_changed.is_connected(_refresh):
		run.phase_changed.connect(_refresh)
	_refresh(str(run.phase))


func _refresh(_phase: String) -> void:
	if box == null or run == null:
		return
	# Niet free() tijdens pressed: de knop zit dan nog in het signaal.
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var phase := str(run.phase)
	if phase == RunScript.PHASE_LOBBY:
		return
	if phase == RunScript.PHASE_WAVE:
		box.add_child(UiMenu.label("Wave %d" % int(run.wave)))
		return
	if phase == RunScript.PHASE_CHOICE:
		box.add_child(UiMenu.label("Wave %d cleared." % int(run.wave)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_button("Continue", _on_continue))
		row.add_child(_button("Leave", _on_leave))
		box.add_child(row)
		return
	if phase == RunScript.PHASE_RESULTS:
		_show_results()


func _show_results() -> void:
	var s: Dictionary = run.summary()
	if bool(s.get("wiped", false)):
		box.add_child(UiMenu.label("The party is down."))
		box.add_child(UiMenu.label("Rewards earned so far are kept."))
	else:
		box.add_child(UiMenu.label("Colosseum"))
	box.add_child(UiMenu.label("Waves cleared: %d" % int(s.get("waves", 0))))
	box.add_child(UiMenu.label("XP each: %d" % int(s.get("xp", 0))))
	box.add_child(UiMenu.label("Arena Tokens earned: %d" % int(s.get("tokens", 0))))
	box.add_child(UiMenu.label("Arena Tokens: %d" % int(s.get("wallet", 0))))
	var notes: Array = s.get("notes", [])
	for line in notes:
		box.add_child(UiMenu.label(str(line)))
	box.add_child(_button("Back to the lobby", _on_lobby))


func _button(text: String, cb: Callable) -> Button:
	var b := UiMenu.button(text)
	b.name = text
	b.custom_minimum_size = Vector2(120, UiTouch.TOUCH_MIN)
	b.pressed.connect(cb)
	return b


func _on_continue() -> void:
	if run != null:
		run.choose_continue()


func _on_leave() -> void:
	if run != null:
		run.choose_leave()


func _on_lobby() -> void:
	if run != null:
		run.acknowledge()
	var tree := get_tree()
	if tree == null:
		return
	var sc := tree.current_scene
	if sc != null and str(sc.scene_file_path).ends_with("/arena_hall.tscn"):
		GameState.change_map(LOBBY, "ingang")
