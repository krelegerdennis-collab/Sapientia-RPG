extends Control
## Titelscherm: vier save-slots. Doorgaan en Laden openen allebei deze lijst.
## Lege slots zijn uit (grijs). Het nieuwste gevulde slot krijgt de focus.
## Laden toont onderaan ook de aparte autosave ('Autosave', slot 0, signaal picked(0)).
## mode "new" (Nieuw spel): alleen slot 1..4, ook lege slots kiesbaar; het actieve/eerste lege
## slot krijgt de focus. Het titelscherm vraagt zelf om bevestiging bij een gevuld slot.

signal picked(slot: int)
signal cancelled

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

var slot_buttons: Array[Button] = []
var venster: PanelContainer
var dim: ColorRect
var _placing := false
## "load" (standaard) of "new"
var mode := "load"
var autosave_button: Button = null


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
	var is_new := mode == "new"
	list.add_child(UiMenu.label("New game: choose a slot" if is_new else "Choose a slot", UiStyleC.TEXT))
	var focus_btn: Button = null
	var best := -1.0
	for i in range(1, GameState.SLOT_COUNT + 1):
		var rec := GameState.slot_record(i)
		var b := UiMenu.button(_label(i, rec))
		b.name = "Slot%d" % i
		b.custom_minimum_size = Vector2(168, 18)
		var off := rec.is_empty() and not is_new
		b.disabled = off
		b.focus_mode = Control.FOCUS_NONE if off else Control.FOCUS_ALL
		b.pressed.connect(picked.emit.bind(i))
		list.add_child(b)
		slot_buttons.append(b)
		if is_new:
			if focus_btn == null and rec.is_empty():
				focus_btn = b
		elif not rec.is_empty() and float(rec.get("stamp", 0.0)) > best:
			best = float(rec["stamp"])
			focus_btn = b
	if not is_new:
		var arec := GameState.slot_record(GameState.AUTOSAVE_SLOT)
		var ab := UiMenu.button(_label(GameState.AUTOSAVE_SLOT, arec))
		ab.name = "Autosave"
		ab.custom_minimum_size = Vector2(168, 18)
		ab.disabled = arec.is_empty()
		ab.focus_mode = Control.FOCUS_NONE if arec.is_empty() else Control.FOCUS_ALL
		ab.pressed.connect(picked.emit.bind(GameState.AUTOSAVE_SLOT))
		list.add_child(ab)
		autosave_button = ab
		if not arec.is_empty() and float(arec.get("stamp", 0.0)) > best:
			focus_btn = ab
	elif focus_btn == null and not slot_buttons.is_empty():
		focus_btn = slot_buttons[0]
	var back := UiMenu.button("Back")
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
	var title := "Autosave" if slot == GameState.AUTOSAVE_SLOT else "Slot %d" % slot
	if rec.is_empty():
		return "%s: empty" % title
	return "%s: %s" % [title, summary(rec.get("data", {}))]


## Korte samenvatting van een save: naam, Lv en speeltijd.
static func summary(d: Dictionary) -> String:
	var who := str(d.get("player_name", ""))
	var p = d.get("party", [])
	if p is Array and not p.is_empty() and p[0] is Dictionary:
		var lv = p[0].get("level", 1)
		who += " Lv %d" % (int(lv) if (lv is int or lv is float) else 1)
	var t: Variant = d.get("play_time", 0.0)
	return "%s %s" % [who, UiMenu.format_time(float(t) if (t is int or t is float) else 0.0)]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
