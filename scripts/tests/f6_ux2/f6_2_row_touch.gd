extends RefCounted
## F6-2: elke zichtbare keuzeregel in de menuschermen heeft een echt tikvlak van minstens TOUCH_MIN
## (UiTouch.big_enough), gemeten op het tikvlak dat de knop accepteert (touch_row.gd: hit_rect binnen de
## knippende ScrollContainer), niet op custom_minimum_size. De zichtbare regel mag 16 blijven.
## Plus: overlappende tikvlakken hebben precies één eigenaar, en een tik op een zichtbare regel gaat
## altijd naar die regel (de buurregel steelt niets).
## Schermen: Items, Equipment, Magic, Party, Quest Log, Bestiary, Scenes (+ Music), Codex (Fusion-knop).

const GameDataS := preload("res://scripts/data/game_data.gd")
const MenuScreenS := preload("res://scripts/ui/menu_screen.gd")
const UiMenuS := preload("res://scripts/ui/ui_menu.gd")
const SCREENS: Array[String] = ["menu_items", "menu_equipment", "menu_magic", "menu_party", "menu_quests",
		"menu_bestiary", "menu_codex", "scenes", "scenes_music"]


func needs_game() -> bool:
	return true


## Het echte tikvlak van een knop: touch_row-knoppen geven het zelf; gewone knoppen = eigen rechthoek
## binnen de knippende voorouder.
static func touch_rect(b: Button) -> Rect2:
	if b.has_method("touch_rect_global"):
		return b.touch_rect_global()
	var r := b.get_global_rect()
	var n := b.get_parent()
	while n != null and n is Control:
		if (n as Control).clip_contents:
			return r.intersection((n as Control).get_global_rect())
		n = n.get_parent()
	return r


## Volledig zichtbare knoppen onder n (binnen de knippende ouder), zonder de Back-knop (die heeft BackZone).
static func visible_buttons(n: Node, back: Button, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Button and n != back and (n as Button).text.strip_edges() != "":
		var b := n as Button
		var g := b.get_global_rect()
		var clip := Rect2()
		var p := b.get_parent()
		while p != null and p is Control:
			if (p as Control).clip_contents:
				clip = (p as Control).get_global_rect()
				break
			p = p.get_parent()
		if g.size.y > 0.0 and (clip.size == Vector2.ZERO or clip.grow(0.5).encloses(g)):
			out.append(b)
	for c in n.get_children():
		visible_buttons(c, back, out)


## Welke knoppen krijgen een tik op dit schermpunt? touch_row-regels via owns() (dezelfde regel als de
## zones-laag); gewone knoppen via hun eigen rechthoek.
static func owners(buttons: Array, gp: Vector2) -> Array:
	var out: Array = []
	for b in buttons:
		var hit: bool = b.owns(gp) if b.has_method("owns") else touch_rect(b).has_point(gp)
		if hit:
			out.append(b)
	return out


## Punt in de extra tikrand (binnen touch_rect, buiten zichtbare regel) met één eigenaar.
static func _padding_point(btns: Array) -> Array:
	if btns.is_empty():
		return []
	for pick in btns:
		if not pick.has_method("owns"):
			continue
		var g := (pick as Control).get_global_rect()
		var r := touch_rect(pick)
		if r.size.y <= g.size.y + 0.5:
			continue
		var probes: Array[Vector2] = [
				Vector2(g.get_center().x, g.position.y - 2.0),
				Vector2(g.get_center().x, g.end.y + 2.0),
				Vector2(r.get_center().x, r.position.y + 1.0),
				Vector2(r.get_center().x, r.end.y - 1.0),
		]
		for gp in probes:
			if r.has_point(gp) and not g.has_point(gp) and pick.owns(gp):
				return [pick, gp]
	return []


## Eerste (knop, punt) met een punt in het tikvlak maar buiten de zichtbare knop, dat alleen die knop heeft.
static func _probe(btns: Array) -> Array:
	for b in btns:
		if not b.has_method("touch_rect_global"):
			continue
		var g := (b as Control).get_global_rect()
		var r := touch_rect(b)
		for gp in [Vector2(g.get_center().x, g.end.y + 2.0), Vector2(g.get_center().x, g.position.y - 2.0),
				Vector2(g.end.x + 2.0, g.get_center().y), Vector2(g.position.x - 2.0, g.get_center().y)]:
			if r.has_point(gp) and not g.has_point(gp):
				var o := owners(btns, gp)
				if o.size() == 1 and o[0] == b:
					return [b, gp]
	return []


static func _click(t: Node, gp: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = gp
	m.global_position = gp
	t.get_viewport().push_input(m, true)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = gp
		e.global_position = gp
		t.get_viewport().push_input(e, true)


static func _win_pos(t: Node, gp: Vector2) -> Vector2:
	return t.get_tree().root.get_final_transform() * gp


static func _drag_vertical(t: Node, gp: Vector2, dy: float) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = _win_pos(t, gp)
	mb.global_position = gp
	Input.parse_input_event(mb)
	await t.pframes(2)
	var steps := 5
	for i in range(1, steps + 1):
		var y := gp.y + dy * float(i) / float(steps)
		var mot := InputEventMouseMotion.new()
		mot.position = _win_pos(t, Vector2(gp.x, y))
		mot.global_position = Vector2(gp.x, y)
		mot.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mot)
		await t.pframes(1)
	mb = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = _win_pos(t, Vector2(gp.x, gp.y + dy))
	mb.global_position = Vector2(gp.x, gp.y + dy)
	Input.parse_input_event(mb)


static func _touch_tap(t: Node, zones: Control, gp: Vector2) -> void:
	var local := zones.get_global_transform().affine_inverse() * gp
	var st := InputEventScreenTouch.new()
	st.index = 0
	st.device = 0
	st.pressed = true
	st.position = local
	zones._gui_input(st)
	await t.pframes(2)
	var rel := InputEventScreenTouch.new()
	rel.index = 0
	rel.device = 0
	rel.pressed = false
	rel.position = local
	zones._gui_input(rel)


## Tik/sleep in de extra tikrand (padding): pressed alleen bij tik, scroll bij sleep; touch zonder dubbele pressed.
func _padding_gesture_tests(t: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	t.get_tree().root.add_child(layer)
	var panel := Control.new()
	panel.position = Vector2.ZERO
	panel.size = t.get_viewport().get_visible_rect().size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(panel)
	panel.theme = load(UiMenuS.THEME_PATH)
	var scroll := ScrollContainer.new()
	scroll.name = "HarnessScroll"
	scroll.clip_contents = true
	scroll.position = Vector2(40, 40)
	scroll.custom_minimum_size = Vector2(120, 48)
	scroll.scroll_deadzone = 6
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var btns: Array = []
	for i in 6:
		var b := MenuScreenS.touch_row(UiMenuS.button("R%d" % i))
		b.custom_minimum_size = Vector2(96, 16)
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		list.add_child(b)
		btns.append(b)
	await t.pframes(4)
	scroll.scroll_vertical = 20
	await t.pframes(2)
	var probe := _padding_point(btns)
	t.check("F6-2 padding: proefpunt in tikrand", not probe.is_empty())
	if probe.is_empty():
		layer.queue_free()
		return
	var target: Button = probe[0]
	var gp: Vector2 = probe[1]
	var presses := [0]
	var cb := func() -> void:
		presses[0] += 1
	target.pressed.connect(cb)
	_click(t, gp)
	await t.pframes(3)
	t.check("F6-2 padding-tik: pressed bij loslaten in tikrand", presses[0] == 1)
	target.pressed.disconnect(cb)
	presses[0] = 0
	target.pressed.connect(cb)
	var zones: Control = panel.get_node_or_null("TouchRowZones") as Control
	t.check("F6-2 touch: zones-laag aanwezig", zones != null)
	if zones != null:
		await _touch_tap(t, zones, gp)
		await t.pframes(3)
		t.check("F6-2 touch-tikrand: precies één pressed (was %d)" % presses[0], presses[0] == 1)
	target.pressed.disconnect(cb)
	presses[0] = 0
	target.pressed.connect(cb)
	var y0 := scroll.scroll_vertical
	await _drag_vertical(t, gp, 24.0)
	await t.pframes(4)
	t.check("F6-2 padding-sleep: geen pressed", presses[0] == 0)
	t.check("F6-2 padding-sleep: lijst scrollt", scroll.scroll_vertical != y0)
	if is_instance_valid(target):
		target.pressed.disconnect(cb)
	layer.queue_free()


func _open(t: Node, name: String) -> Node:
	if name.begins_with("scenes"):
		var fm: Node = await t.sc.open_field_menu()
		if fm == null:
			return null
		fm.open_scenes()
		await t.pframes(6)
		if name == "scenes_music" and fm.sub != null:
			fm.sub.kies_tab("music")
			await t.pframes(6)
		return fm.sub
	if not await t.sc.open(name):
		return null
	var fm2: Node = t.sc.field_menu()
	return fm2.sub if fm2 != null else null


func run(t: Node) -> void:
	# genoeg spullen voor een lijst die scrollt (ook de rand van de ScrollContainer wordt zo gemeten)
	var n := 0
	for id in GameDataS.ITEMS.keys():
		GameState.set_item_count(str(id), 2)
		n += 1
		if n >= 14:
			break
	await _padding_gesture_tests(t)
	for p in ["16x9", "19_5x9_notch"]:
		await t.sc.set_profile(p)
		for name in SCREENS:
			var sub: Node = await _open(t, name)
			var tag := "F6-2 [%s] %s" % [p, name]
			if sub == null:
				t.check(tag + ": scherm open", false)
				await t.sc.close_all()
				continue
			await t.pframes(4)
			var back: Button = sub.get("back_button") as Button
			var btns: Array = []
			visible_buttons(sub, back, btns)
			var small: Array = []
			for b in btns:
				var r := touch_rect(b)
				if not UiTouch.big_enough(r):
					small.append("%s %s" % [(b as Button).text.strip_edges(), r.size])
			t.check("%s: %d zichtbare keuzeregels, allemaal echt tikvlak >= %d (te klein: %s)"
					% [tag, btns.size(), int(UiTouch.TOUCH_MIN), small], not btns.is_empty() and small.is_empty())
			# één eigenaar per punt, en de zichtbare regel wint altijd: raster over alle tikvlakken
			var dubbel := 0
			var gestolen := 0
			for b in btns:
				var r := touch_rect(b)
				var y := r.position.y + 0.5
				while y < r.end.y:
					var gp := Vector2(r.get_center().x, y)
					var o := owners(btns, gp)
					if o.size() > 1:
						dubbel += 1
					for v in btns:
						if (v as Control).get_global_rect().has_point(gp) and not (o.size() == 1 and o[0] == v):
							gestolen += 1
					y += 1.0
			t.check("%s: elk punt hoort bij één regel (dubbel: %d) en een tik op een zichtbare regel gaat naar die regel (anders: %d)"
					% [tag, dubbel, gestolen], dubbel == 0 and gestolen == 0)
			# de zichtbare regelhoogte blijft (lijsten niet opnieuw ontworpen)
			var rows16 := btns.filter(func(b): return absf((b as Control).size.y - 16.0) < 0.5).size()
			print("INFO  %s: %d van %d regels zijn zichtbaar 16 hoog" % [tag, rows16, btns.size()])
			await t.shot("f6_2_%s_%s" % [p, name])
			# echte tik (Viewport-invoer) net naast de zichtbare regel, binnen het extra tikvlak: komt bij de regel aan
			var probe := _probe(btns)
			print("INFO  %s: proefpunt buiten een zichtbare regel: %s" % [tag, "geen (alles grenst aan een buur)" if probe.is_empty() else str(probe[1])])
			if not probe.is_empty():
				var target: Button = probe[0]
				var got := [false]
				var cb := func() -> void:
					got[0] = true
				target.pressed.connect(cb)
				_click(t, probe[1])
				await t.pframes(3)
				if is_instance_valid(target):
					target.pressed.disconnect(cb)
				t.check("%s: tik op %s (buiten de zichtbare regel '%s') komt bij die regel aan"
						% [tag, probe[1], target.text.strip_edges() if is_instance_valid(target) else "?"], got[0])
			await t.sc.close_all()
