extends Control
## Titelscherm: vier save-slots. Doorgaan en Laden openen allebei deze lijst.
## Lege slots zijn uit (grijs). Het nieuwste gevulde slot krijgt de focus.
## Laden toont onderaan ook de aparte autosave ('Autosave', slot 0, signaal picked(0)).
## mode "new" (Nieuw spel): alleen slot 1..4, ook lege slots kiesbaar; het actieve/eerste lege
## slot krijgt de focus. Het titelscherm vraagt zelf om bevestiging bij een gevuld slot.

signal picked(slot: int)
signal cancelled

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")

var slot_buttons: Array[Button] = []
var venster: PanelContainer
var dim: ColorRect
var _placing := false
## Zelfde rust-frame als menu_screen: geen cancel in het openingsframe.
var _quiet_frame := -1
## Laatste viewport, insets en oudergrootte waarvoor het venster is gezet (party_select).
var _lay_vp := Vector2(-1, -1)
var _lay_ins := Vector4(-1, -1, -1, -1)
var _lay_psz := Vector2(-1, -1)
## "load" (standaard) of "new"
## Waarvoor staat de lijst open (docs/STATE_MACHINES.md §5): LOAD (Continue, standaard) | NEW (New Game).
## title_screen.gd zet hem vóór het vullen.
const MODE_LOAD := "load"
const MODE_NEW := "new"
const MODES: Array[String] = [MODE_LOAD, MODE_NEW]
var mode := MODE_LOAD
var autosave_button: Button = null


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
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
	var is_new := mode == MODE_NEW
	list.add_child(UiMenu.label("New game: choose a slot" if is_new else "Choose a slot", UiStyleC.TEXT))
	var focus_btn: Button = null
	var best := -1.0
	for i in range(1, GameState.SLOT_COUNT + 1):
		var rec := GameState.slot_record(i)
		var b := UiMenu.button(_label(i, rec))
		b.name = "Slot%d" % i
		b.custom_minimum_size = Vector2(168, UiTouch.TOUCH_MIN)
		var unreadable := bool(rec.get("corrupt", false))
		var off := (rec.is_empty() or unreadable) and not is_new
		b.disabled = off
		b.focus_mode = Control.FOCUS_NONE if off else Control.FOCUS_ALL
		b.pressed.connect(picked.emit.bind(i))
		list.add_child(b)
		slot_buttons.append(b)
		if is_new:
			if focus_btn == null and rec.is_empty():
				focus_btn = b
		elif not off and float(rec.get("stamp", 0.0)) > best:
			best = float(rec["stamp"])
			focus_btn = b
	if not is_new:
		var arec := GameState.slot_record(GameState.AUTOSAVE_SLOT)
		var ab := UiMenu.button(_label(GameState.AUTOSAVE_SLOT, arec))
		ab.name = "Autosave"
		ab.custom_minimum_size = Vector2(168, UiTouch.TOUCH_MIN)
		var a_off := arec.is_empty() or bool(arec.get("corrupt", false))
		ab.disabled = a_off
		ab.focus_mode = Control.FOCUS_NONE if a_off else Control.FOCUS_ALL
		ab.pressed.connect(picked.emit.bind(GameState.AUTOSAVE_SLOT))
		list.add_child(ab)
		autosave_button = ab
		if not a_off and float(arec.get("stamp", 0.0)) > best:
			focus_btn = ab
	elif focus_btn == null and not slot_buttons.is_empty():
		focus_btn = slot_buttons[0]
	var back := UiMenu.button("Back")
	back.name = "Terug"
	back.custom_minimum_size = Vector2(168, UiTouch.TOUCH_MIN)
	UiSfx.tag(back, UiSfx.CANCEL)
	back.pressed.connect(func() -> void: cancelled.emit())
	list.add_child(back)
	if focus_btn != null:
		focus_btn.grab_focus()
	else:
		back.grab_focus()
	resized.connect(_place)
	_place.call_deferred()


## Insets kunnen wisselen zonder dat de viewport van maat verandert (notch-test).
func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var ins := UiTouch.insets(get_viewport())
	var parent := get_parent() as Control
	var psz := parent.size if parent != null else vp
	if vp != _lay_vp or ins != _lay_ins or psz != _lay_psz:
		_lay_vp = vp
		_lay_ins = ins
		_lay_psz = psz
		_place()
	if Engine.get_process_frames() <= _quiet_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		cancelled.emit()
		# Loslaten in hetzelfde beeld: anders ziet een ouder/sibling die later in _process
		# draait (bv. veldmenu als Load net dichtgaat) dezelfde synthetische terugdruk nog.
		if InputMap.has_action("cancel") and Input.is_action_pressed("cancel"):
			Input.action_release("cancel")
		if InputMap.has_action("menu") and Input.is_action_pressed("menu"):
			Input.action_release("menu")


## Het venster staat in het midden van UiTouch.safe_rect (notch, gebarenbalk).
## Bij insets 0 blijft dat dezelfde pixel als het midden van de ouder.
## Ankers op een nog lege ouder landen anders links boven het beeld.
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
	var ins := UiTouch.insets(get_viewport())
	if ins == Vector4.ZERO:
		venster.position = ((psz - venster.size) / 2.0).floor()
	else:
		# Zelfde klem als party_select._binnen_veilig: helemaal in het veilige gebied,
		# en als het past het midden daarvan (niet het midden van de volle viewport).
		var vp := get_viewport_rect().size
		var safe := UiTouch.safe_rect(vp, get_viewport())
		var pos := (safe.position + (safe.size - venster.size) / 2.0).floor()
		pos.x = clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - venster.size.x))
		pos.y = clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - venster.size.y))
		venster.global_position = pos
	_placing = false


func _label(slot: int, rec: Dictionary) -> String:
	var title := "Autosave" if slot == GameState.AUTOSAVE_SLOT else "Slot %d" % slot
	if rec.is_empty():
		return "%s: empty" % title
	if bool(rec.get("corrupt", false)):
		return "%s: unreadable save" % title
	var tail := " (backup)" if bool(rec.get("from_backup", false)) else ""
	if bool(rec.get("newer_version", false)):
		tail += " (newer version)"
	return "%s: %s%s" % [title, summary(rec.get("data", {})), tail]


## Korte samenvatting van een save: naam, Lv en speeltijd.
static func summary(d: Dictionary) -> String:
	var who := str(d.get("player_name", ""))
	var p = d.get("party", [])
	if p is Array and not p.is_empty() and p[0] is Dictionary:
		var lv = p[0].get("level", 1)
		who += " Lv %d" % (int(lv) if (lv is int or lv is float) else 1)
	var t: Variant = d.get("play_time", 0.0)
	return "%s %s" % [who, UiMenu.format_time(float(t) if (t is int or t is float) else 0.0)]

