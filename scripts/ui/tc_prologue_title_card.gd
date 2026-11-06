extends Node
## TC-P: proloog-titelkaart (PLACEHOLDER — lay-out blijft placeholden tot definitieve art/typografie).
## Signaal `completed` als de kaart klaar is (fade-out). Tik/scherm/knop = overslaan.

signal completed

const FADE_SEC := 0.45
const HOLD_SEC := 2.8
const TITLE := "The Watcher's Vigil"
const LINE := "Grandpa stared at the ruins again. Today the air felt wrong."

var _layer: CanvasLayer
var _root_ui: Control
var _bg: ColorRect
var _skipped := false
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	_build_ui()
	_skipped = false
	_bg.modulate.a = 0.0
	_layer.show()
	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, FADE_SEC)
	await tw.finished
	var deadline := Time.get_ticks_msec() + int(HOLD_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline and not _skipped and is_inside_tree():
		await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(_bg, "modulate:a", 0.0, FADE_SEC)
	await tw.finished
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	completed.emit()
	queue_free()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 108
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	_root_ui = Control.new()
	_root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ui.focus_mode = Control.FOCUS_ALL
	_root_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ui.gui_input.connect(_on_gui_input)
	_layer.add_child(_root_ui)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.color = UiStyle.INK
	_root_ui.add_child(_bg)
	var box := MarginContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("margin_left", 16)
	box.add_theme_constant_override("margin_right", 16)
	box.add_theme_constant_override("margin_top", 20)
	box.add_theme_constant_override("margin_bottom", 20)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_bg.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	box.add_child(vbox)
	var title := Label.new()
	title.text = TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.theme = GameState.ui_theme
	title.add_theme_color_override("font_color", UiStyle.HILITE)
	title.add_theme_font_size_override("font_size", 14)
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(title)
	var line := Label.new()
	line.text = LINE
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.theme = GameState.ui_theme
	line.add_theme_color_override("font_color", UiStyle.TEXT)
	line.add_theme_font_size_override("font_size", 9)
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vbox.add_child(line)
	_root_ui.grab_focus()


func _on_gui_input(ev: InputEvent) -> void:
	_try_skip_from_event(ev, "gui_input")


func _input(ev: InputEvent) -> void:
	if _finished or not is_inside_tree():
		return
	if ev is InputEventKey and ev.pressed:
		_skipped = true
	elif ev is InputEventJoypadButton and ev.pressed:
		_skipped = true
	else:
		# parse_input_event (--tcptest) gaat door de normale input-pipeline, niet altijd naar gui_input.
		_try_skip_from_event(ev, "_input")


func _try_skip_from_event(ev: InputEvent, bron: String) -> void:
	if _finished:
		return
	if ev is InputEventScreenTouch and ev.pressed:
		if OS.get_cmdline_user_args().has("--tcptest"):
			print("TC-P-SKIP-RECEIPT [%s] ScreenTouch pressed=true index=%d pos=%s" % [bron, ev.index, ev.position])
		_skipped = true
	elif ev is InputEventMouseButton and ev.pressed:
		if OS.get_cmdline_user_args().has("--tcptest"):
			print("TC-P-SKIP-RECEIPT [%s] MouseButton button=%s pressed=true pos=%s" % [bron, ev.button_index, ev.position])
		_skipped = true
