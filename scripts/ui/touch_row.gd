extends Button
## F6-2: lijstregel met een groter, onzichtbaar tikvlak (zoals BackZone in menu_screen.gd).
## De zichtbare regel blijft wat het scherm zet (ROW_H = 16); het tikvlak is UiTouch.hit_rect(regel):
## minstens TOUCH_MIN (25) hoog en breed, rond hetzelfde midden. Ligt de regel in een knippende ouder
## (ScrollContainer), dan schuift het tikvlak naar binnen, zodat het niet half buiten de lijst valt.
## Overlap met een buurregel: een tik op een zichtbare knop is altijd van die knop; daarbuiten wint de
## regel waarvan het midden het dichtst bij de tik ligt.
## De extra rand (buiten de zichtbare knop) vangt touch_row_zones.gd op: één onzichtbare laag bovenop het
## scherm, zodat een container die later in de boom staat de tik niet afpakt.
## Gebruik: MenuScreen.touch_row(UiMenu.button("...")) - zet dit script op een bestaande knop.

const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const ZonesS := preload("res://scripts/ui/touch_row_zones.gd")
const GROUP := "touch_row"


func _enter_tree() -> void:
	add_to_group(GROUP)
	_ensure_zones.call_deferred()


## Eén zones-laag per scherm: als laatste kind van de bovenste Control (de root van het scherm).
func _ensure_zones() -> void:
	if not is_inside_tree():
		return
	var top: Control = self
	while top.get_parent() is Control:
		top = top.get_parent() as Control
	if top == self:
		return
	var z := top.get_node_or_null(ZonesS.NODE_NAME)
	if z == null:
		z = ZonesS.new()
		z.name = ZonesS.NODE_NAME
		top.add_child(z)
	elif z.get_index() != top.get_child_count() - 1:
		# nieuwe inhoud kwam erna: de laag weer bovenop
		top.move_child(z, -1)


## Tikvlak in schermcoördinaten (vóór het knippen door de ScrollContainer).
func hit_rect_global() -> Rect2:
	var g := get_global_rect()
	var r := UiTouchC.hit_rect(g)
	var clip := clip_rect_global()
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return r
	if r.size.y <= clip.size.y:
		r.position.y = clampf(r.position.y, clip.position.y, clip.end.y - r.size.y)
	if r.size.x <= clip.size.x:
		r.position.x = clampf(r.position.x, clip.position.x, clip.end.x - r.size.x)
	return r


## Het echte tikvlak: hit_rect_global() binnen de knippende ouder (daarbuiten komt geen tik aan).
func touch_rect_global() -> Rect2:
	var r := hit_rect_global()
	var clip := clip_rect_global()
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return r
	return r.intersection(clip)


## Rechthoek van de dichtstbijzijnde voorouder die zijn inhoud knipt (leeg als er geen is).
func clip_rect_global() -> Rect2:
	var n := get_parent()
	while n != null and n is Control:
		if (n as Control).clip_contents:
			return (n as Control).get_global_rect()
		n = n.get_parent()
	return Rect2()


## Is een tik op dit schermpunt van deze regel? (zelfde regel voor de zones-laag en de tests)
func owns(gp: Vector2) -> bool:
	if not is_visible_in_tree() or not touch_rect_global().has_point(gp):
		return false
	if get_global_rect().has_point(gp):
		return true
	# een tik op een zichtbare buurknop (ook een gewone) is altijd van die knop
	var p := get_parent()
	if p != null:
		for s in p.get_children():
			if s != self and s is BaseButton and (s as Control).is_visible_in_tree() \
					and (s as Control).get_global_rect().has_point(gp):
				return false
	# overlap met andere lijstregels (ook in een naastgelegen kolom): het dichtstbijzijnde midden wint
	var mine := gp.distance_squared_to(get_global_rect().get_center())
	for n in get_tree().get_nodes_in_group(GROUP):
		if n == self or not (n as Control).is_visible_in_tree():
			continue
		var o := n as Control
		if o.get_global_rect().has_point(gp):
			return false
		if not n.touch_rect_global().has_point(gp):
			continue
		var theirs := gp.distance_squared_to(o.get_global_rect().get_center())
		# dichterbij wint; bij gelijke afstand de knop die het eerst in de boom staat
		if theirs < mine or (theirs == mine and not o.is_greater_than(self)):
			return false
	return true
