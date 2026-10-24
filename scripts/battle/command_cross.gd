extends Control
## v0.13 COMMANDO-KRUIS (Lufia 2-stijl). v0.15: LINKS naast de helden (battle.gd _place_cross).
##
##                [Magie]
##        [Item] [Aanval] [Verdedig]
##               [Vluchten] [Codex]
##
## Index = battle.gd COMMANDS: 0 Aanval (midden), 1 Magie (boven), 2 Item (links),
## 3 Verdedig (rechts), 4 Vluchten (onder), 5 Codex (v0.19, rechtsonder: vangen / bondgenoot
## wisselen). De Codex-knop is VERBORGEN als open() hem in 'hidden_list' krijgt (oefengevecht, of
## nog geen pagina's en geen Lege Boeken); verborgen = niet te zien, niet te kiezen, niet te tikken.
## Codex bereik je met rechts vanaf Vluchten (of door erop te tikken); vanaf Codex gaat omhoog naar
## Verdedig en links naar Vluchten. De oude paden (0-4) zijn ongewijzigd.
## Besturing: D-pad/pijltjes kiezen een arm (vanaf een arm terug naar het midden met de
## tegenovergestelde richting), A = kiezen, B = terug, of direct op een knop tikken.
## Uitgeschakelde commando's zijn grijs (frame 2); A of tikken doet dan niets.
## Art (RPG ART): assets/ui/knop_<id>.png = strook 72x24, 3 frames van 24x24:
## 0 = normaal, 1 = gekozen, 2 = uit. Ontbreekt een plaatje, dan tekent de code een
## eenvoudige reserve-knop (zie _draw_placeholder). Spec: art_specs_v13/BATTLE_UI_SPEC.md.
## Boven het kruis staat een klein naamlabel ('Kees: Aanval'): vervangt de oude strook
## 'Wat doet Kees?'.

signal finished(index: int)
signal denied(index: int)          # A/tik op een uitgeschakeld commando

const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const IDS := ["aanval", "magie", "item", "verdedig", "vluchten", "codex"]
const NAMES := ["Attack", "Magic", "Item", "Defend", "Flee", "Codex"]
const CODEX := 5
## Plek van elke knop in het kruis (in knoppen; midden = 0,0)
const CELLS := [Vector2i(0, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
const BUTTON := 24.0
const GAP := 1.0
const ART_DIR := "res://assets/ui/"

var active := false
var selected := 0
var allow_cancel := true
var enabled: Array = [true, true, true, true, true, true]
var hidden_cmds: Array = []            # v0.19: indexen die niet getoond worden (bv. [CODEX])
var last_result := -2
var hero_name := ""
var buttons: Array[Control] = []    # 6 knoppen (TextureRect), index = commando
var name_tab: PanelContainer
var name_label: Label
var _frames := {}                   # id -> [normaal, gekozen, uit] (AtlasTexture) of leeg
var _opened_frame := -1
var _center := Vector2.ZERO
var _shake_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in IDS.size():
		var id: String = IDS[i]
		_frames[id] = _load_frames(ART_DIR + "knop_%s.png" % id)
		var b := TextureRect.new()
		b.name = "Knop_" + NAMES[i]
		b.size = Vector2(BUTTON, BUTTON)
		b.custom_minimum_size = b.size
		b.stretch_mode = TextureRect.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.gui_input.connect(_on_button_input.bind(i))
		b.draw.connect(_draw_placeholder.bind(b, i))
		add_child(b)
		buttons.append(b)
	name_tab = PanelContainer.new()
	name_tab.name = "NameTab"
	name_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_tab.add_theme_stylebox_override("panel", UiStyleC.panel("tab"))
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", UiStyleC.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_tab.add_child(name_label)
	add_child(name_tab)
	hide()
	_refresh()


## 3 frames van 24x24 uit een strook van 72x24 (leeg als het plaatje er niet is).
static func _load_frames(path: String) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var tex: Texture2D = load(path)
	if tex == null or tex.get_width() < 72:
		return []
	var out := []
	for f in 3:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(f * 24, 0, 24, 24)
		out.append(at)
	return out


## Heeft deze knop echte art? (voor de autotest)
func has_art(i: int) -> bool:
	return not _frames.get(IDS[i], []).is_empty()


## Midden van het kruis op (center) zetten (battle.gd _layout).
func place(center: Vector2) -> void:
	_center = center.round()
	position = Vector2.ZERO
	size = Vector2.ZERO
	for i in buttons.size():
		var c: Vector2i = CELLS[i]
		buttons[i].position = _center + Vector2(c) * (BUTTON + GAP) - Vector2(BUTTON, BUTTON) / 2.0
	_place_name()


## Rechthoek om het hele kruis (in battle-eenheden).
func cross_rect() -> Rect2:
	var r := Rect2(buttons[0].position, buttons[0].size)
	for i in buttons.size():
		if is_shown(i):
			r = r.merge(Rect2(buttons[i].position, buttons[i].size))
	return r


func button_rect(i: int) -> Rect2:
	return Rect2(buttons[i].position, buttons[i].size)


func open(who: String, enabled_list: Array, start_index := 0, can_cancel := true, hidden_list := []) -> void:
	hero_name = who
	enabled = enabled_list.duplicate()
	while enabled.size() < IDS.size():
		enabled.append(true)
	hidden_cmds = hidden_list.duplicate()
	for i in buttons.size():
		buttons[i].visible = is_shown(i)
	selected = clampi(start_index, 0, IDS.size() - 1)
	if not is_shown(selected):
		selected = 0
	allow_cancel = can_cancel
	last_result = -2
	active = true
	_opened_frame = Engine.get_process_frames()
	show()
	_refresh()


func close() -> void:
	active = false
	hide()


## Kruis zichtbaar laten maar niet meer bedienbaar (bv. tijdens het spreuken-/itemmenu).
func deactivate() -> void:
	active = false
	_refresh()


func is_enabled(i: int) -> bool:
	return i >= 0 and i < enabled.size() and bool(enabled[i]) and is_shown(i)


## v0.19: staat de knop in beeld? (de Codex-knop kan verborgen zijn)
func is_shown(i: int) -> bool:
	return i >= 0 and i < IDS.size() and not hidden_cmds.has(i)


## Welke knop krijg je als je vanaf 'from' in richting 'dir' drukt?
## v0.19: codex_shown = is de Codex-knop (rechtsonder) zichtbaar?
static func neighbour(from: int, dir: Vector2i, codex_shown := false) -> int:
	if from == CODEX:
		if dir == Vector2i.UP:
			return 3                   # Verdedig
		if dir == Vector2i.LEFT:
			return 4                   # Vluchten
		return CODEX
	if codex_shown and from == 4 and dir == Vector2i.RIGHT:
		return CODEX
	var cell: Vector2i = CELLS[from]
	if from != 0 and cell == -dir:
		return 0                       # tegenovergestelde richting: terug naar het midden
	return CELLS.find(dir)


func select(i: int) -> void:
	if not is_shown(i):
		return
	selected = clampi(i, 0, IDS.size() - 1)
	_refresh()


func _process(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		var b: Control = buttons[selected]
		var c: Vector2i = CELLS[selected]
		b.position = _center + Vector2(c) * (BUTTON + GAP) - Vector2(BUTTON, BUTTON) / 2.0 \
				+ Vector2(roundf(sin(_shake_t * 60.0) * 1.0) if _shake_t > 0.0 else 0.0, 0)
	if not active or Engine.get_process_frames() == _opened_frame:
		return
	for pair in [["move_up", Vector2i.UP], ["move_down", Vector2i.DOWN],
			["move_left", Vector2i.LEFT], ["move_right", Vector2i.RIGHT]]:
		if Input.is_action_just_pressed(pair[0]):
			select(neighbour(selected, pair[1], is_shown(CODEX)))
			return
	if Input.is_action_just_pressed("interact"):
		_choose(selected)
	elif Input.is_action_just_pressed("cancel") and allow_cancel:
		active = false
		last_result = -1
		_refresh()
		finished.emit(-1)


func _choose(i: int) -> void:
	if not is_enabled(i):
		_shake_t = 0.2
		denied.emit(i)
		return
	active = false
	last_result = i
	_refresh()
	finished.emit(i)


func _on_button_input(event: InputEvent, i: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed or not active or not is_shown(i):
		return
	buttons[i].accept_event()
	select(i)
	_choose(i)


func _refresh() -> void:
	for i in buttons.size():
		var fr: Array = _frames.get(IDS[i], [])
		var f := 2 if not is_enabled(i) else (1 if i == selected else 0)
		if not fr.is_empty():
			buttons[i].texture = fr[f]
		buttons[i].modulate = Color(1, 1, 1, 1.0 if active or i == selected else 0.85)
		buttons[i].queue_redraw()
	if name_label:
		var cmd: String = NAMES[selected]
		name_label.text = ("%s: %s" % [hero_name, cmd]) if hero_name != "" else cmd
		name_label.add_theme_color_override("font_color",
				UiStyleC.TEXT if is_enabled(selected) else UiStyleC.TEXT_OFF)
		_place_name()


func _place_name() -> void:
	# Een kruis dat al uit de boom is (gevecht net afgesloten) heeft geen viewport-rect (WM1-bugjacht O-3).
	if name_tab == null or buttons.is_empty() or not is_inside_tree():
		return
	name_tab.size = Vector2.ZERO
	name_tab.reset_size()
	var top := buttons[1].position.y
	var w := name_tab.size.x
	var vp_w := get_viewport_rect().size.x / maxf(get_global_transform().get_scale().x, 0.001)
	# v0.15: het tabje steekt niet rechts buiten het kruis uit (daar staat de held)
	var cross_right := buttons[3].position.x + BUTTON
	var x := clampf(roundf(_center.x - w / 2.0), 2.0, maxf(2.0, minf(vp_w - 2.0 - w, cross_right - w)))
	name_tab.position = Vector2(x, top - name_tab.size.y - 1.0)


## Reserve-knop (alleen als de art ontbreekt): donker vak, rand, letter.
func _draw_placeholder(b: Control, i: int) -> void:
	if has_art(i):
		return
	var sel := i == selected
	var on := is_enabled(i)
	var r := Rect2(Vector2.ZERO, b.size)
	b.draw_rect(r, Color(UiStyleC.INK, 0.9))
	b.draw_rect(r.grow(-0.5), UiStyleC.HILITE if sel else UiStyleC.BORDER_DIM, false, 1.0)
	if i == CODEX:
		# v0.19 reserve-icoon (tot ART knop_codex.png levert): open boekje met paarse rug
		var col: Color = UiStyleC.TEXT if on else UiStyleC.TEXT_OFF
		var glow: Color = Color(0.72, 0.45, 1.0) if on else UiStyleC.TEXT_OFF
		b.draw_rect(Rect2(5, 7, 6, 10), Color(col, 0.9))
		b.draw_rect(Rect2(13, 7, 6, 10), Color(col, 0.9))
		b.draw_rect(Rect2(11, 6, 2, 12), glow)
		b.draw_rect(Rect2(6, 9, 4, 1), Color(UiStyleC.INK, 0.8))
		b.draw_rect(Rect2(14, 9, 4, 1), Color(UiStyleC.INK, 0.8))
		b.draw_rect(Rect2(6, 12, 4, 1), Color(UiStyleC.INK, 0.8))
		b.draw_rect(Rect2(14, 12, 4, 1), Color(UiStyleC.INK, 0.8))
		return
	var font := b.get_theme_default_font()
	if font:
		b.draw_string(font, Vector2(8, 16), NAMES[i].left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				UiStyleC.TEXT if on else UiStyleC.TEXT_OFF)
