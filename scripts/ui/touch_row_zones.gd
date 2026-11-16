extends Control
## F6-2: onzichtbare laag bovenop een menuscherm die de extra tikrand van lijstregels (touch_row.gd)
## opvangt. Claimt alleen punten buiten elke zichtbare knop die bij precies één lijstregel horen
## (touch_row.owns); al het andere valt erdoorheen naar het scherm eronder. Tekent niets.
## Wordt door touch_row.gd zelf aangemaakt (één per scherm); niet met de hand toevoegen.
## 'pressed' gaat pas bij loslaten als de vinger binnen TAP_SLOP bleef en de ScrollContainer niet scrollde.

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")

const NODE_NAME := "TouchRowZones"
const GROUP := "touch_row"
const MOUSE_PTR := -1
const SCROLL_EPS := 0.5

var _pending: Dictionary = {}
var _touch_held := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Schermpositie (viewport/canvas) van een gui-invoer gebeurtenis.
func _gp(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return get_global_transform() * (event as InputEvent).position
	if event is InputEventMouse:
		var m := event as InputEventMouse
		if m.global_position.length_squared() > 0.01:
			return m.global_position
		return get_global_transform() * m.position
	return Vector2.ZERO


## De lijstregel (van dit scherm) die een tik op dit schermpunt krijgt, of null.
func owner_at(gp: Vector2) -> Button:
	var top := get_parent()
	if top == null:
		return null
	for n in get_tree().get_nodes_in_group(GROUP):
		if top.is_ancestor_of(n) and n.owns(gp):
			# een zichtbare knop of het 'Back'-vlak ligt hier: dan doet het scherm zelf het werk
			if (n as Control).get_global_rect().has_point(gp) or _blocked(top, gp):
				return null
			return n as Button
	return null


func _blocked(n: Node, gp: Vector2) -> bool:
	for c in n.get_children():
		if c == self or not (c is Control) or not (c as Control).visible:
			continue
		var ctl := c as Control
		if (ctl is BaseButton or ctl is Range or ctl is LineEdit or ctl.name == "BackZone") and ctl.get_global_rect().has_point(gp):
			return true
		if _blocked(c, gp):
			return true
	return false


func _scroll_for(btn: Button) -> ScrollContainer:
	var n: Node = btn
	while n != null:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null


func _has_point(point: Vector2) -> bool:
	return owner_at(get_global_transform() * point) != null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		if _touch_held > 0 or (event as InputEventMouseButton).device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _touch_held > 0 or _pending.is_empty() or _pending.get("ptr", MOUSE_PTR) != MOUSE_PTR:
			return
		var mot := event as InputEventMouseMotion
		if (mot.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_track_motion(_gp(mot), event)


func _on_screen_touch(ev: InputEventScreenTouch) -> void:
	var gp := _gp(ev)
	if ev.pressed:
		_touch_held += 1
		_begin_press(gp, ev.index)
	else:
		_touch_held = maxi(0, _touch_held - 1)
		if not _pending.is_empty() and _pending.get("ptr", MOUSE_PTR) == ev.index:
			_track_motion(gp, ev)
			_finish_press(gp)


func _on_screen_drag(ev: InputEventScreenDrag) -> void:
	if _pending.is_empty() or _pending.get("ptr", MOUSE_PTR) != ev.index:
		return
	_track_motion(_gp(ev), ev)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var gp := _gp(mb)
	if mb.pressed:
		_begin_press(gp, MOUSE_PTR)
	else:
		if not _pending.is_empty() and _pending.get("ptr", MOUSE_PTR) == MOUSE_PTR:
			_track_motion(gp, mb)
			_finish_press(gp)


func _begin_press(gp: Vector2, ptr: int) -> void:
	_pending = {}
	var b := owner_at(gp)
	if b == null or b.disabled:
		return
	var scroll := _scroll_for(b)
	_pending = {
		"button": b,
		"start_gp": gp,
		"ptr": ptr,
		"max_dist": 0.0,
		"scroll": scroll,
		"scroll_y": scroll.scroll_vertical if scroll != null else 0.0,
		"yielded": false,
	}


func _track_motion(gp: Vector2, raw: InputEvent) -> void:
	if _pending.is_empty():
		return
	if _pending.get("yielded", false):
		_apply_scroll_drag(_pending, gp)
		return
	var d := gp.distance_to(_pending.start_gp)
	_pending.max_dist = maxf(_pending.max_dist, d)
	if _pending.max_dist <= UiTouchC.TAP_SLOP:
		return
	_yield_scroll()


func _apply_scroll_drag(p: Dictionary, gp: Vector2) -> void:
	var scroll: ScrollContainer = p.scroll
	if scroll == null:
		return
	var dy := gp.y - (p.start_gp as Vector2).y
	var maxv := scroll.get_v_scroll_bar().max_value
	scroll.scroll_vertical = clampi(int(p.scroll_y) - int(dy), 0, maxv)


func _yield_scroll() -> void:
	if _pending.is_empty():
		return
	_pending.yielded = true
	_apply_scroll_drag(_pending, _pending.start_gp)


func _finish_press(_gp_end: Vector2) -> void:
	if _pending.is_empty():
		return
	if _pending.get("yielded", false):
		_apply_scroll_drag(_pending, _gp_end)
		_pending = {}
		return
	var p := _pending
	_pending = {}
	var scroll: ScrollContainer = p.scroll
	var scrolled := scroll != null and absf(scroll.scroll_vertical - float(p.scroll_y)) > SCROLL_EPS
	if p.max_dist > UiTouchC.TAP_SLOP or scrolled:
		return
	var b: Button = p.button
	if b == null or not is_instance_valid(b) or b.disabled:
		return
	accept_event()
	if b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()
	b.pressed.emit()

