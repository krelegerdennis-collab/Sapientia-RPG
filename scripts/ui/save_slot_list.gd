extends Control
## Titelscherm: vier save-slots. Doorgaan en Laden openen allebei deze lijst.
## Lege slots zijn uit (grijs). Het nieuwste gevulde slot krijgt de focus.

signal picked(slot: int)
signal cancelled

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

var slot_buttons: Array[Button] = []
var venster: PanelContainer
var dim: ColorRect
var _placing := false


func _ready() -> void:
	name = "SaveSlotList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := PanelContainer.new()
	box.name = "Venster"
	box.add_theme_stylebox_override("panel", UiStyleC.panel("window"))
	venster = box
	add_child(box)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	box.add_child(list)
	list.add_child(UiMenu.label("Choose a slot", UiStyleC.TEXT))
	var focus_btn: Button = null
	var best := -1.0
	for i in range(1, GameState.SLOT_COUNT + 1):
		var rec := GameState.slot_record(i)
		var b := UiMenu.button(_label(i, rec))
		b.name = "Slot%d" % i
		b.custom_minimum_size = Vector2(148, 16)
		b.disabled = rec.is_empty()
		b.focus_mode = Control.FOCUS_NONE if rec.is_empty() else Control.FOCUS_ALL
		b.pressed.connect(picked.emit.bind(i))
		list.add_child(b)
		slot_buttons.append(b)
		if not rec.is_empty() and float(rec.get("stamp", 0.0)) > best:
			best = float(rec["stamp"])
			focus_btn = b
	var back := UiMenu.button("Terug")
	back.name = "Terug"
	back.pressed.connect(func() -> void: cancelled.emit())
	list.add_child(back)
	if focus_btn != null:
		focus_btn.grab_focus()
	else:
		back.grab_focus()
	resized.connect(_place)
	_place.call_deferred()


## Het venster staat in het midden. Ankers op een nog lege ouder landen anders links boven het beeld.
func _place() -> void:
	if _placing:
		return
	_placing = true
	var parent := get_parent() as Control
	var psz := parent.size if parent != null else get_viewport_rect().size
	if psz.x < 8.0:
		psz = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = psz
	position = Vector2.ZERO
	if dim != null:
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.size = psz
	if venster == null:
		_placing = false
		return
	venster.reset_size()
	venster.position = ((psz - venster.size) / 2.0).floor()
	_placing = false


func _label(slot: int, rec: Dictionary) -> String:
	if rec.is_empty():
		return "Slot %d: leeg" % slot
	var d: Dictionary = rec.get("data", {})
	var who := str(d.get("player_name", ""))
	var t: Variant = d.get("play_time", 0.0)
	var tijd := UiMenu.format_time(float(t) if (t is int or t is float) else 0.0)
	var auto := " (auto)" if bool(d.get("autosave", false)) else ""
	return "Slot %d: %s %s%s" % [slot, who, tijd, auto]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
