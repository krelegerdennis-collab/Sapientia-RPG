extends Control
## Virtuele D-pad (linksonder) en A- en B-knop (rechtsonder) voor telefoons.
## Ze "drukken" dezelfde input actions in als het toetsenbord
## (move_up/down/left/right, interact = A, cancel = B), dus de rest van het spel
## merkt geen verschil tussen toetsenbord en touch.
## Werkt met multi-touch: elke vinger wordt apart bijgehouden.
## Op PC kun je met de muis klikken (emulate_touch_from_mouse staat aan).

## (preload i.p.v. class_name: dit script wordt al door een autoload geladen)
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const SomDataC := preload("res://scripts/data/som_data.gd")

@export var dpad_radius := 30.0
@export var button_radius := 15.0
@export var edge_margin := 8.0
## Vingers binnen dit deel van de straal in het midden doen niets.
@export var dead_zone := 0.25
## v0.11: grootte (schaal van de stralen) en zichtbaarheid komen uit de Opties
## (autoload Settings: touch_size / touch_opacity). Dit zijn de waarden bij schaal 1.
var _base_dpad_radius := 0.0
var _base_button_radius := 0.0

const DPAD_ACTIONS := {
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
	Vector2i.LEFT: "move_left",
	Vector2i.RIGHT: "move_right",
}

## v0.10: kleine MENU-knop rechtsboven (alleen in de overworld, map.gd zet hem aan).
var show_menu := false:
	set(v):
		show_menu = v
		queue_redraw()
## v0.16 KERN-knop (Kernkracht-vuurbal): alleen zichtbaar als hij vrijgespeeld is; de kaart
## (scripts/kern/kern_kracht_veld.gd) zet dit aan/uit. Drukt de actie "kern" in.
var show_kern := false:
	set(v):
		show_kern = v
		if not v:
			for i in _touch_owner.keys():
				if _touch_owner[i] == "kern":
					_set_touch_action(i, "")
					_touch_owner.erase(i)
		queue_redraw()
## TODO.md "run feature": RUN-knop (toggle) boven de CORE-plek; zichtbaar zoals MENU (in het veld).
## Drukt de actie "run"; de stand komt uit Settings ("run").
var show_run := false:
	set(v):
		show_run = v
		if not v:
			for i in _touch_owner.keys():
				if _touch_owner[i] == "run":
					_set_touch_action(i, "")
					_touch_owner.erase(i)
		queue_redraw()
## SoM-proef (Action): de D-pad wordt een analoge joystick. Geen move_*-acties; de vinger geeft
## joy_raw (-1..1, t.o.v. het midden, lengte max 1). De speler leest hem (scripts/som/som_move.gd).
var joystick_mode := false:
	set(v):
		joystick_mode = v
		joy_raw = Vector2.ZERO
		queue_redraw()
var joy_raw := Vector2.ZERO
var _touch_owner := {}    # vinger-index -> "dpad" of "a"
var _touch_action := {}   # vinger-index -> actie die die vinger nu indrukt
var _press_count := {}    # actie -> aantal vingers dat hem indrukt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(refit)
	_base_dpad_radius = dpad_radius
	_base_button_radius = button_radius
	var settings := get_node_or_null("/root/Settings")
	if settings:
		settings.changed.connect(_on_setting_changed)
	apply_settings()
	refit()


## v0.11 Grootte en zichtbaarheid uit de Opties toepassen.
func apply_settings() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	dpad_radius = _base_dpad_radius * settings.touch_scale()
	button_radius = _base_button_radius * settings.touch_scale()
	modulate.a = settings.touch_alpha()
	queue_redraw()


func _on_setting_changed(key: String) -> void:
	if key in ["touch_size", "touch_opacity"]:
		apply_settings()


## Vul het scherm. Als de CanvasLayer geschaald is (in gevechten 2x, voor het
## fijne raster), dan rekenen de knoppen gewoon in 384x216-eenheden verder.
func refit() -> void:
	if not is_inside_tree():
		return
	var layer := get_parent() as CanvasLayer
	var s := layer.scale if layer else Vector2.ONE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size / s
	queue_redraw()


func dpad_center() -> Vector2:
	if joystick_mode:
		# SoM-proef (feedback Dennis): kleiner en hoger, ongeveer midden-links
		return Vector2(edge_margin + 6.0 + joy_radius(), roundf(size.y * SomDataC.JOY_CENTER_Y))
	return Vector2(edge_margin + dpad_radius, size.y - edge_margin - dpad_radius)


## Straal van de analoge joystick (kleiner dan de D-pad; de vinger mag er ruim omheen: JOY_TOUCH_REACH).
func joy_radius() -> float:
	return roundf(dpad_radius * SomDataC.JOY_SCALE)


## SoM-proef: bovenste rij rechts = [RUN][Swap][Ring][MENU]; Swap/Ring zet de HUD (som_hud.gd) neer.
func som_row_slot(i: int) -> Rect2:
	var m := menu_rect()
	var w: float = SomDataC.TOP_BUTTON_SIZE.x
	var gap: float = SomDataC.TOP_BUTTON_GAP
	var x := m.position.x - (gap + w) * float(i + 1)
	return Rect2(Vector2(x, m.get_center().y - SomDataC.TOP_BUTTON_SIZE.y / 2.0), SomDataC.TOP_BUTTON_SIZE)


func a_center() -> Vector2:
	return Vector2(size.x - edge_margin - button_radius - 6.0, size.y - edge_margin - button_radius - 10.0)


func menu_rect() -> Rect2:
	return Rect2(size.x - edge_margin - 38.0, edge_margin - 2.0, 38.0, 14.0)


## v0.16 KERN-knop: een paars 'pilletje' zoals MENU (vuurbal-icoon + "KERN"), recht boven de
## A-knop (rechterduim), rechts uitgelijnd met A.
const KERN_SIZE := Vector2(46, 17)


func kern_rect() -> Rect2:
	var right := a_center().x + button_radius
	var bottom := a_center().y - button_radius - 9.0
	return Rect2(Vector2(right - KERN_SIZE.x, bottom - KERN_SIZE.y), KERN_SIZE)


## RUN-knop: zelfde maat als CORE, recht erboven (ook als CORE nog niet vrijgespeeld is).
func run_rect() -> Rect2:
	if joystick_mode:
		var s := som_row_slot(2)          # links van Swap en Ring
		var rs: Vector2 = SomDataC.TOP_BUTTON_SIZE
		return Rect2(Vector2(s.end.x - KERN_SIZE.x, s.position.y), Vector2(KERN_SIZE.x, rs.y))
	var kr := kern_rect()
	return Rect2(kr.position - Vector2(0, KERN_SIZE.y + 5.0), KERN_SIZE)


## Schermrechthoeken (384x216-eenheden) van alle zichtbare knoppen; o.a. de World Warper
## op de wereldkaart vliegt hier omheen (world_warper/art/flyover.gd).
func button_rects() -> Array[Rect2]:
	var uit: Array[Rect2] = []
	if not is_visible_in_tree():
		return uit
	var d := dpad_center()
	var dr := dpad_radius * 1.35  # incl. de printplaat-sporen eromheen
	uit.append(Rect2(d - Vector2.ONE * dr, Vector2.ONE * dr * 2.0))
	for c in [a_center(), b_center()]:
		uit.append(Rect2(c - Vector2.ONE * button_radius, Vector2.ONE * button_radius * 2.0))
	if show_menu:
		uit.append(menu_rect())
	if show_run:
		uit.append(run_rect())
	if show_kern:
		uit.append(kern_rect())
	return uit


func run_on() -> bool:
	var st := get_node_or_null("/root/Settings")
	return st != null and bool(st.get_value("run"))


func kern_center() -> Vector2:
	return kern_rect().get_center()


## B-knop: linksonder van de A-knop (zoals op een SNES-controller).
func b_center() -> Vector2:
	return a_center() + Vector2(-button_radius * 2.3, button_radius * 0.8)


func _input(event: InputEvent) -> void:
	# v0.11: verborgen (bv. tijdens het veldmenu) = knoppen doen niets
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var pos := _local(event.position)
		if event.pressed:
			if joystick_mode and pos.distance_to(dpad_center()) <= joy_radius() * SomDataC.JOY_TOUCH_REACH:
				_touch_owner[event.index] = "joy"
				_set_joy(pos)
				get_viewport().set_input_as_handled()
			elif pos.distance_to(dpad_center()) <= dpad_radius * 1.2:
				_touch_owner[event.index] = "dpad"
				_set_touch_action(event.index, _dpad_action(pos))
				get_viewport().set_input_as_handled()
			elif pos.distance_to(a_center()) <= button_radius * 1.25:
				_touch_owner[event.index] = "a"
				_set_touch_action(event.index, "interact")
				get_viewport().set_input_as_handled()
			elif pos.distance_to(b_center()) <= button_radius * 1.25:
				_touch_owner[event.index] = "b"
				_set_touch_action(event.index, "cancel")
				get_viewport().set_input_as_handled()
			elif show_kern and InputMap.has_action("kern") and kern_rect().grow(4.0).has_point(pos):
				_touch_owner[event.index] = "kern"
				_set_touch_action(event.index, "kern")
				get_viewport().set_input_as_handled()
			elif show_run and InputMap.has_action("run") and run_rect().grow(2.0).has_point(pos):
				_touch_owner[event.index] = "run"
				_set_touch_action(event.index, "run")
				get_viewport().set_input_as_handled()
			elif show_menu and menu_rect().grow(4.0).has_point(pos):
				_touch_owner[event.index] = "menu"
				_set_touch_action(event.index, "menu")
				get_viewport().set_input_as_handled()
		else:
			if _touch_owner.get(event.index, "") == "joy":
				joy_raw = Vector2.ZERO
				queue_redraw()
			_set_touch_action(event.index, "")
			_touch_owner.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touch_owner.get(event.index, "") == "joy":
			_set_joy(_local(event.position))
			get_viewport().set_input_as_handled()
			return
		# Over de D-pad schuiven verandert de richting (zoals op een echte D-pad).
		if _touch_owner.get(event.index, "") == "dpad":
			_set_touch_action(event.index, _dpad_action(_local(event.position)))
			get_viewport().set_input_as_handled()


## Schermpositie (viewport) -> positie binnen deze knoppen-laag.
func _local(viewport_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_pos


## Joystick: positie van de vinger -> joy_raw (lengte max 1). Dode zone/8 richtingen: som_move.gd.
func _set_joy(pos: Vector2) -> void:
	joy_raw = ((pos - dpad_center()) / maxf(1.0, joy_radius())).limit_length(1.0)
	queue_redraw()


func _dpad_action(pos: Vector2) -> String:
	var v := pos - dpad_center()
	if v.length() < dpad_radius * dead_zone:
		return ""
	var dir: Vector2i
	if absf(v.x) > absf(v.y):
		dir = Vector2i.RIGHT if v.x > 0 else Vector2i.LEFT
	else:
		dir = Vector2i.DOWN if v.y > 0 else Vector2i.UP
	return DPAD_ACTIONS[dir]


func _set_touch_action(index: int, action: String) -> void:
	var old: String = _touch_action.get(index, "")
	if old == action:
		return
	if old != "":
		_press_count[old] = _press_count.get(old, 1) - 1
		if _press_count[old] <= 0:
			_press_count.erase(old)
			Input.action_release(old)
	if action != "":
		_press_count[action] = _press_count.get(action, 0) + 1
		Input.action_press(action)
		_touch_action[index] = action
	else:
		_touch_action.erase(index)
	queue_redraw()


func release_all() -> void:
	for action in _press_count.keys():
		Input.action_release(action)
	_press_count.clear()
	_touch_action.clear()
	_touch_owner.clear()
	joy_raw = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	# App naar de achtergrond of venster kwijt: laat alle knoppen los.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
	# Sessielog 21 okt 2026 (vast in de Golemhal): deze laag verdwijnt met de oude kaart (warp) terwijl
	# een vinger nog op de D-pad ligt. Input.action_press is globaal en niemand liet move_* dan nog los:
	# op de nieuwe kaart bleef de richting 'ingedrukt', spawn_hold wachtte eeuwig op loslaten = niet lopen.
	elif what == NOTIFICATION_EXIT_TREE:
		release_all()


# ------------------------------------------------------------- tekenen
## v7 'De Vergeten Bibliotheek': grijze metalen D-pad met magenta 'printplaat'-sporen
## eromheen, A/B grijs met een neon rand (A cyaan, B magenta). Lijnen van 0,5 eenheid =
## 1 echte pixel in het gevecht (2x-raster); in de overworld worden ze 1 pixel.
## Alles wordt alleen opnieuw getekend als er iets verandert (geen werk per frame).
const CIRCUIT := [
	# [punten (in stralen t.o.v. het midden)], eindpunt krijgt een rondje
	[Vector2(0.55, -0.95), Vector2(0.95, -0.95), Vector2(1.12, -0.78)],
	[Vector2(0.95, -0.55), Vector2(1.12, -0.55)],
	[Vector2(-0.55, -0.95), Vector2(-0.95, -0.95), Vector2(-1.1, -1.1)],
	[Vector2(0.95, 0.55), Vector2(0.95, 0.95), Vector2(1.1, 1.1)],
	[Vector2(-0.95, 0.55), Vector2(-1.12, 0.55)],
	[Vector2(-0.55, 0.95), Vector2(-0.95, 0.95), Vector2(-1.12, 0.78)],
	[Vector2(0.38, -1.0), Vector2(0.38, -1.15)],
	[Vector2(-0.38, 1.0), Vector2(-0.38, 1.15)],
]


func _draw() -> void:
	var line := 0.5 if _fine() else 1.0
	var mag := UiStyleC.MAGENTA
	# D-pad
	var c := dpad_center()
	var r := dpad_radius
	if joystick_mode:
		r = joy_radius()
	draw_circle(c, r, Color(0, 0, 0, 0.28))
	if joystick_mode:
		_draw_joystick(c, r, line)
		_draw_rest(line)
		return
	# printplaat-sporen met gloed
	for path in CIRCUIT:
		var pts := PackedVector2Array()
		for q in path:
			pts.append((c + q * r).round())
		draw_polyline(pts, Color(mag.r, mag.g, mag.b, 0.18), line * 3.0)
		draw_polyline(pts, Color(mag.r, mag.g, mag.b, 0.75), line)
		draw_circle(pts[pts.size() - 1], line * 2.2, Color(mag.r, mag.g, mag.b, 0.85))
		draw_circle(pts[pts.size() - 1], line, Color(0.08, 0.02, 0.08, 1))
	draw_arc(c, r * 0.98, 0.0, TAU, 48, Color(mag.r, mag.g, mag.b, 0.22), line)
	var arm := roundf(r * 0.33)
	var reach := roundf(r * 0.86)
	var body := Color(0.16, 0.16, 0.18, 0.92)
	var lit := Color(0.46, 0.46, 0.5, 0.95)
	var dark := Color(0.04, 0.04, 0.05, 0.95)
	for rect in [Rect2(c.x - arm, c.y - reach, arm * 2, reach * 2), Rect2(c.x - reach, c.y - arm, reach * 2, arm * 2)]:
		draw_rect(rect.grow(line), dark)
		draw_rect(rect, body)
	# afschuining (licht linksboven, donker rechtsonder)
	draw_line(Vector2(c.x - arm, c.y - reach + line), Vector2(c.x + arm, c.y - reach + line), lit, line)
	draw_line(Vector2(c.x - reach + line, c.y - arm), Vector2(c.x - reach + line, c.y + arm), lit, line)
	draw_line(Vector2(c.x - arm, c.y + reach - line), Vector2(c.x + arm, c.y + reach - line), dark, line)
	draw_line(Vector2(c.x + reach - line, c.y - arm), Vector2(c.x + reach - line, c.y + arm), dark, line)
	draw_circle(c, arm * 0.55, Color(0.09, 0.09, 0.1, 1))
	draw_arc(c, arm * 0.55, 0.0, TAU, 20, Color(0.32, 0.32, 0.36, 1), line)
	for dir in DPAD_ACTIONS:
		var pressed := _press_count.has(DPAD_ACTIONS[dir])
		var d := Vector2(dir)
		var tip := c + d * reach * 0.82
		var side := Vector2(-d.y, d.x) * arm * 0.6
		var back := c + d * reach * 0.42
		var tri := PackedVector2Array([tip, back + side, back - side])
		if pressed:
			draw_colored_polygon(tri, UiStyleC.MAGENTA_HOT)
		else:
			draw_colored_polygon(tri, Color(mag.r, mag.g, mag.b, 0.25))
		draw_polyline(PackedVector2Array([tip, back + side, back - side, tip]), mag, line)
	_draw_rest(line)


## SoM-proef: joystick (PLACEHOLDER-opmaak): ring + knop die met de vinger meeschuift.
func _draw_joystick(c: Vector2, r: float, line: float) -> void:
	if _draw_joystick_art(c, r):
		return
	_draw_joystick_placeholder(c, r, line)


## RPG ART: joystick_ring (60x60, midden 30,30) geschaald naar de joystickstraal; de knop (24x24) schuift
## maximaal JOY_KNOB_TRAVEL (18) art-pixels uit. Geeft false als de art ontbreekt.
func _draw_joystick_art(c: Vector2, r: float) -> bool:
	var ring_t: Texture2D = _som_tex(SomDataC.UI_JOY_RING)
	var knob_t: Texture2D = _som_tex(SomDataC.UI_JOY_KNOB_PRESSED if joy_raw != Vector2.ZERO else SomDataC.UI_JOY_KNOB)
	if ring_t == null or knob_t == null:
		return false
	var s := maxf(1.0, floorf(r / SomDataC.JOY_ART_RADIUS))
	var rs := ring_t.get_size() * s
	draw_texture_rect(ring_t, Rect2((c - rs / 2.0).round(), rs), false)
	var k := joy_knob_pos(c, s)
	var ks := knob_t.get_size() * s
	draw_texture_rect(knob_t, Rect2((k - ks / 2.0).round(), ks), false)
	return true


## Midden van de knop: joy_raw (lengte <= 1) x 18 art-pixels x schaal.
func joy_knob_pos(c: Vector2, s: float) -> Vector2:
	return (c + joy_raw.limit_length(1.0) * SomDataC.JOY_KNOB_TRAVEL * s).round()


var _tex_cache := {}


func _som_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _draw_joystick_placeholder(c: Vector2, r: float, line: float) -> void:
	var mag := UiStyleC.MAGENTA
	draw_arc(c, r * 0.98, 0.0, TAU, 48, Color(mag.r, mag.g, mag.b, 0.6), line)
	draw_arc(c, r * dead_zone, 0.0, TAU, 16, Color(mag.r, mag.g, mag.b, 0.25), line)
	var k := (c + joy_raw * r * 0.7).round()
	draw_circle(k, r * 0.38, Color(0.16, 0.16, 0.18, 0.92))
	draw_arc(k, r * 0.38, 0.0, TAU, 24, UiStyleC.MAGENTA_HOT if joy_raw != Vector2.ZERO else mag, line)


func _draw_rest(line: float) -> void:
	var mag := UiStyleC.MAGENTA
	# A- en B-knop
	_draw_button(a_center(), "A", "interact", UiStyleC.CYAN, line)
	_draw_button(b_center(), "B", "cancel", UiStyleC.MAGENTA, line)
	if show_kern:
		_draw_kern_button(line)
	if show_run:
		_draw_run_button(line)
	if show_menu:
		var mr := menu_rect()
		var pressed := _press_count.has("menu")
		draw_rect(mr, Color(0.08, 0.08, 0.09, 0.8) if not pressed else Color(0.24, 0.24, 0.27, 0.9))
		draw_rect(mr, Color(mag.r, mag.g, mag.b, 0.8), false, line)
		var font := get_theme_default_font()
		var ts := font.get_string_size("MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var tp := Vector2(mr.get_center().x - ts.x / 2.0, mr.position.y + 11.0).round()
		draw_string(font, tp + Vector2(1, 1), "MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyleC.SHADOW)
		draw_string(font, tp, "MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyleC.TEXT)


func _fine() -> bool:
	var layer := get_parent() as CanvasLayer
	return layer != null and layer.scale.x >= 2.0


func _draw_button(center: Vector2, letter: String, action: String, neon: Color, line: float) -> void:
	var pressed := _press_count.has(action)
	var r := button_radius
	draw_circle(center, r + line * 2.0, Color(neon.r, neon.g, neon.b, 0.16 if not pressed else 0.4))   # gloed
	draw_circle(center, r, Color(0.13, 0.13, 0.15, 0.92) if not pressed else Color(0.24, 0.24, 0.27, 0.95))
	draw_arc(center, r - line * 1.5, PI * 0.75, PI * 1.75, 16, Color(0.5, 0.5, 0.55, 0.9), line)   # licht
	draw_arc(center, r - line * 1.5, -PI * 0.25, PI * 0.75, 16, Color(0.03, 0.03, 0.04, 0.9), line)  # schaduw
	draw_arc(center, r, 0.0, TAU, 40, neon if not pressed else Color.WHITE, line)
	var font := get_theme_default_font()
	var fs := 10
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := center + Vector2(-text_size.x / 2.0, fs / 2.0 - 1.0)
	draw_string(font, pos + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyleC.SHADOW)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, neon.lerp(Color.WHITE, 0.6) if pressed else UiStyleC.TEXT)


## v0.16 KERN-knop: zelfde stijl als MENU, maar paars, met het eerste frame van de vuurbal-art
## (assets/fx/kern_vuurbal.png; ontbreekt die, dan een paars bolletje) en "KERN".
const KERN_NEON := Color(0.68, 0.36, 1.0)
const KERN_ICON := "res://assets/fx/kern_vuurbal.png"
var _kern_icon: Texture2D


func _draw_kern_button(line: float) -> void:
	var kr := kern_rect()
	var pressed := _press_count.has("kern")
	draw_rect(kr.grow(line), Color(KERN_NEON.r, KERN_NEON.g, KERN_NEON.b, 0.16 if not pressed else 0.4))   # gloed
	draw_rect(kr, Color(0.1, 0.07, 0.14, 0.85) if not pressed else Color(0.28, 0.18, 0.38, 0.95))
	draw_rect(kr, KERN_NEON if not pressed else Color.WHITE, false, line)
	if _kern_icon == null and ResourceLoader.exists(KERN_ICON):
		_kern_icon = load(KERN_ICON)
	var icon_c := (kr.position + Vector2(11, kr.size.y / 2.0)).round()
	if _kern_icon:
		# frame 0 (16x16), wijst naar rechts; kern op (10,8) -> iets naar links zetten
		draw_texture_rect_region(_kern_icon, Rect2(icon_c - Vector2(10, 8), Vector2(16, 16)), Rect2(0, 0, 16, 16))
	else:
		draw_circle(icon_c, 4.0, KERN_NEON)
	var font := get_theme_default_font()
	var ts := font.get_string_size("CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var tp := Vector2(kr.end.x - 4.0 - ts.x, kr.position.y + 12.0).round()
	draw_string(font, tp + Vector2(1, 1), "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyleC.SHADOW)
	draw_string(font, tp, "CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, KERN_NEON.lerp(Color.WHITE, 0.7) if not pressed else Color.WHITE)


## RUN-knop: pilletje zoals CORE. AAN = groen gevuld, groene rand, groen lampje + gloed; UIT = donker, grijs, lampje uit.
const RUN_NEON := Color(0.35, 1.0, 0.55)


func _draw_run_button(line: float) -> void:
	var rr := run_rect()
	var on := run_on()
	var pressed := _press_count.has("run")
	var neon := RUN_NEON if on else Color(0.55, 0.55, 0.6)
	if on:
		draw_rect(rr.grow(line), Color(neon.r, neon.g, neon.b, 0.3))   # gloed
	draw_rect(rr, Color(0.08, 0.2, 0.11, 0.9) if on else Color(0.08, 0.08, 0.09, 0.8))
	if pressed:
		draw_rect(rr, Color(1, 1, 1, 0.15))
	draw_rect(rr, neon, false, line)
	# lampje links
	var lamp := (rr.position + Vector2(7, rr.size.y / 2.0)).round()
	draw_circle(lamp, 2.5, neon if on else Color(0.2, 0.2, 0.22))
	var font := get_theme_default_font()
	var txt := "RUN"
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var tp := Vector2(rr.end.x - 4.0 - ts.x, rr.position.y + 12.0).round()
	draw_string(font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyleC.SHADOW)
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE if on else UiStyleC.TEXT)
