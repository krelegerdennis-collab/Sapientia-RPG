extends Control
## F6-2: onzichtbare laag bovenop een menuscherm die de extra tikrand van lijstregels (touch_row.gd)
## opvangt. Claimt alleen punten buiten elke zichtbare knop die bij precies één lijstregel horen
## (touch_row.owns); al het andere valt erdoorheen naar het scherm eronder. Tekent niets.
## Wordt door touch_row.gd zelf aangemaakt (één per scherm); niet met de hand toevoegen.

const NODE_NAME := "TouchRowZones"
const GROUP := "touch_row"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


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


func _has_point(point: Vector2) -> bool:
	return owner_at(get_global_transform() * point) != null


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var b := owner_at(get_global_transform() * mb.position)
	if b == null:
		return
	accept_event()
	if b.disabled:
		return
	if b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()
	b.pressed.emit()
