extends PanelContainer
## Commandomenu ('De Vergeten Bibliotheek'): donker venster, elke regel met een ▶-pijltje;
## de gekozen regel krijgt een magenta pijl en een zachte neon-gloed. De titel (naam van
## de held, of 'Magie'/'Item') staat in een tabje boven het venster (MenuTab).
## Werkt op 3 manieren:
##   - tikken / klikken op een regel
##   - D-pad of pijltjes omhoog/omlaag + A (interact)
##   - B (cancel) = terug
## Gebruik:  menu.open("Titel", [{"text": "Aanval", "enabled": true}, ...])
##           var keuze: int = await menu.finished      (-1 = terug)
## De plek (v9): battle.gd zet met anchor_to() de linkerkant + onderkant (boven het statusvak
## van de held die aan de beurt is). Bij een andere held schuift het menu er kort naartoe.
## Zonder anchor (bottom_edge < 0) geldt de oude plek: 'right_edge' en 'top_edge'.
## v0.19 (Codex-knop): open(..., row_h, rows_max). row_h = minimale regelhoogte (Codex-menu's: 16,
## vingervriendelijk). rows_max > 0 en meer regels dan dat = een VENSTER van rows_max regels met
## een ▲- en een ▼-regel (row_h hoog, tikbaar) om te scrollen; de keuze-indexen blijven
## gewoon de index in 'entries'. De D-pad scrolt vanzelf mee.

signal finished(index: int)

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const ROW_HEIGHT := 11
const ARROW_W := 10.0            # ruimte voor het pijltje vóór de tekst (eenheden)

var active := false
var selected := 0
var allow_cancel := true
var right_edge := 336.0
var top_edge := 100.0
var bottom_edge := -1.0          # v9: onderkant vast (boven het statusvak); < 0 = oude plek
var left_edge := 0.0             # v9: gewenste linkerkant (= linkerkant van het statusvak)
var min_x := 0.0                 # niet links hiervan (D-pad)
var max_x := 384.0               # niet rechts hiervan (A/B-knoppen)
var last_result := -2            # laatste keuze (ook na 'finished'), -1 = terug
var show_tab := true             # titel-tabje tonen (v9: alleen bij Magie/Item/Doel)
const SLIDE_TIME := 0.18         # seconden: naar het statusvak van de volgende held schuiven
var _tween: Tween
var _slide_x := 0.0
var _entries: Array = []
var _buttons: Array[Button] = []
var _opened_frame := -1
var row_height := ROW_HEIGHT     # v0.19
var max_rows := 0                # v0.19: 0 = alle regels tonen
var first_row := 0               # v0.19: eerste zichtbare regel (venster)
var _scroll_up: Button = null
var _scroll_down: Button = null

@onready var list: VBoxContainer = $Margin/VBox/List
@onready var highlight: Control = $Highlight
@onready var tab: Control = get_node_or_null("../MenuTab")
@onready var title_label: Label = tab.get_node("Title") if tab else Label.new()


func _ready() -> void:
	highlight.draw.connect(_draw_highlight)
	resized.connect(place)
	if tab:
		tab.hide()


func open(title: String, entries: Array, start_index := 0, can_cancel := true, row_h := ROW_HEIGHT,
		rows_max := 0) -> void:
	for b in _buttons:
		list.remove_child(b)   # meteen weghalen, anders telt de oude hoogte nog mee
		b.queue_free()
	_buttons.clear()
	for sb in [_scroll_up, _scroll_down]:
		if sb != null:
			list.remove_child(sb)
			sb.queue_free()
	_scroll_up = null
	_scroll_down = null
	row_height = row_h
	max_rows = rows_max if rows_max > 0 and entries.size() > rows_max else 0
	first_row = 0
	_entries = entries
	title_label.text = title
	for i in entries.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE        # wij regelen de cursor zelf
		# reageren bij het indrukken (niet pas bij loslaten): werkt ook als het menu net
		# naar de volgende held schuift, en voelt directer op een telefoon
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, row_height)
		b.disabled = not entries[i].get("enabled", true)
		b.text = "  " + str(entries[i]["text"])   # 2 tekens ruimte voor het ▶-pijltje
		b.pressed.connect(_on_button_pressed.bind(i))
		list.add_child(b)
		_buttons.append(b)
	if max_rows > 0:
		_scroll_up = _make_scroll_button(-1)
		list.add_child(_scroll_up)
		list.move_child(_scroll_up, 0)
		_scroll_down = _make_scroll_button(1)
		list.add_child(_scroll_down)
	selected = clampi(start_index, 0, maxi(entries.size() - 1, 0))
	if not _is_enabled(selected):
		_move(1)
	_apply_window()
	allow_cancel = can_cancel
	last_result = -2
	active = true
	_opened_frame = Engine.get_process_frames()
	show()
	if tab:
		tab.visible = show_tab and title != ""
		if tab.has_method("set_text"):
			tab.set_text(title)
	_refresh()
	# Venster even groot maken als de inhoud (krimpt ook weer bij een korter menu).
	size = Vector2.ZERO
	reset_size.call_deferred()
	place.call_deferred()


## v0.19: ▲/▼-regel van het venster (geen keuze; tik = een venster verder).
func _make_scroll_button(step: int) -> Button:
	var b := Button.new()
	b.name = "Scroll_" + ("op" if step < 0 else "neer")
	b.focus_mode = Control.FOCUS_NONE
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.custom_minimum_size = Vector2(0, row_height)
	b.text = ""
	b.pressed.connect(scroll.bind(step))
	return b


## v0.19: venster een pagina verder (step -1 = omhoog, 1 = omlaag); de keuze schuift mee.
func scroll(step: int) -> void:
	if max_rows <= 0 or not active:
		return
	first_row = clampi(first_row + step * max_rows, 0, _entries.size() - max_rows)
	if selected < first_row or selected >= first_row + max_rows:
		selected = first_row if step > 0 else first_row + max_rows - 1
		if not _is_enabled(selected):
			for k in max_rows:
				var i := first_row + k
				if _is_enabled(i):
					selected = i
					break
	_apply_window()
	_refresh()


## v0.19: alleen de regels in het venster tonen; het venster volgt de keuze.
func _apply_window() -> void:
	if max_rows <= 0:
		return
	if selected < first_row:
		first_row = selected
	elif selected >= first_row + max_rows:
		first_row = selected - max_rows + 1
	first_row = clampi(first_row, 0, maxi(0, _entries.size() - max_rows))
	for i in _buttons.size():
		_buttons[i].visible = i >= first_row and i < first_row + max_rows
	if _scroll_up:
		_scroll_up.disabled = first_row <= 0
	if _scroll_down:
		_scroll_down.disabled = first_row + max_rows >= _entries.size()


## v0.19: knoppen die nu in beeld zijn (voor tests en tikken).
func row_button(i: int) -> Button:
	return _buttons[i] if i >= 0 and i < _buttons.size() else null


func close() -> void:
	active = false
	hide()
	if tab:
		tab.hide()


## Waar het menu hoort te staan (linksonder vast en binnen min_x..max_x geklemd,
## of de oude plek: rechtsboven vast).
func target_position() -> Vector2:
	if bottom_edge < 0.0:
		return Vector2(roundf(right_edge - size.x), top_edge)
	var x := clampf(left_edge, min_x, maxf(min_x, max_x - size.x))
	return Vector2(roundf(x), roundf(bottom_edge - size.y))


## Zet het menu op zijn plek. Loopt er een schuif-animatie, dan schuift die naar de
## (eventueel nieuwe) plek door.
func place() -> void:
	var p := target_position()
	position.y = p.y
	if _tween and _tween.is_running():
		if absf(_slide_x - p.x) > 0.5:
			_slide(p.x)
	else:
		position.x = p.x
	_place_tab()


## v9: menu boven een statusvak. animate = kort schuiven (als het menu al in beeld is).
func anchor_to(left: float, bottom: float, lo: float, hi: float, animate: bool) -> void:
	left_edge = left
	bottom_edge = bottom
	min_x = lo
	max_x = hi
	var p := target_position()
	position.y = p.y
	if animate and visible and absf(position.x - p.x) > 0.5:
		_slide(p.x)
	else:
		if _tween:
			_tween.kill()
		position.x = p.x
	_place_tab()


func is_sliding() -> bool:
	return _tween != null and _tween.is_running()


func _slide(x: float) -> void:
	if _tween:
		_tween.kill()
	_slide_x = x
	_tween = create_tween()
	_tween.tween_property(self, "position:x", x, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): position.x = roundf(position.x))


func _place_tab() -> void:
	if tab:
		tab.position = Vector2(position.x + 5, position.y - tab.size.y + 3)


func _process(_delta: float) -> void:
	if is_sliding():
		_place_tab()
	if active:
		highlight.queue_redraw()        # zachte puls van de gloed
	# Negeer input in hetzelfde frame als het openen (anders telt één druk dubbel).
	if not active or Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("move_up"):
		_move(-1)
	elif Input.is_action_just_pressed("move_down"):
		_move(1)
	elif Input.is_action_just_pressed("interact"):
		_choose(selected)
	elif Input.is_action_just_pressed("cancel") and allow_cancel:
		UiSfx.play(UiSfx.CANCEL)
		active = false
		last_result = -1
		finished.emit(-1)


func _is_enabled(i: int) -> bool:
	return i >= 0 and i < _entries.size() and _entries[i].get("enabled", true)


## Zet de cursor van buitenaf (bv. als een vijand wordt aangetikt of met links/rechts).
func select(i: int) -> void:
	if _is_enabled(i):
		selected = i
		_apply_window()
		_refresh()


func _move(step: int) -> void:
	var n := _entries.size()
	var before := selected
	for k in n:
		var i := posmod(selected + step * (k + 1), n)
		if _is_enabled(i):
			selected = i
			break
	if selected != before:
		UiSfx.play(UiSfx.CURSOR)
	_apply_window()
	_refresh()


func _choose(i: int) -> void:
	if not _is_enabled(i):
		return
	active = false
	last_result = i
	finished.emit(i)


func _on_button_pressed(i: int) -> void:
	if not active:
		return
	selected = i
	_refresh()
	_choose(i)


func _refresh() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var hot := i == selected
		b.add_theme_color_override("font_color", Color.WHITE if hot else UiStyle.TEXT)
		b.add_theme_color_override("font_hover_color", Color.WHITE if hot else UiStyle.TEXT)
	if highlight:
		highlight.queue_redraw()


## Pijltjes en de gloed achter de gekozen regel (tekent ACHTER de tekst).
func _draw_highlight() -> void:
	var inv := highlight.get_global_transform().affine_inverse()
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() / 220.0)
	for sb in [_scroll_up, _scroll_down]:
		if sb != null and sb.visible:
			var sr: Rect2 = inv * sb.get_global_rect()
			var c: Vector2 = sr.get_center().round()
			var up: bool = sb == _scroll_up
			var scol: Color = UiStyle.TEXT_DIM if not sb.disabled else UiStyle.TEXT_OFF
			var d := -1.0 if up else 1.0
			highlight.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -2 * d), c + Vector2(4, -2 * d),
					c + Vector2(0, 2 * d)]), scol)
	for i in _buttons.size():
		var b := _buttons[i]
		if not b.visible:
			continue
		var r: Rect2 = inv * b.get_global_rect()
		var hot := i == selected and active
		if hot:
			# gloed: zacht magenta vlak, fellere randjes boven/onder (1 fijne pixel)
			var g := Rect2(r.position.x - 3, r.position.y + 0.5, highlight.size.x + 6, r.size.y - 1)
			draw_glow_rect(g, pulse)
		var cy := r.position.y + r.size.y / 2.0
		var x := r.position.x + 1.0
		var enabled := _is_enabled(i)
		var col := UiStyle.MAGENTA if hot else (UiStyle.TEXT_DIM if enabled else UiStyle.TEXT_OFF)
		_draw_arrow(Vector2(x, cy), col, hot)


func draw_glow_rect(g: Rect2, pulse: float) -> void:
	var m := UiStyle.MAGENTA
	highlight.draw_rect(g, Color(m.r, m.g, m.b, 0.13 * pulse))
	highlight.draw_rect(Rect2(g.position, Vector2(g.size.x, 0.5)), Color(m.r, m.g, m.b, 0.45 * pulse))
	highlight.draw_rect(Rect2(g.position + Vector2(0, g.size.y - 0.5), Vector2(g.size.x, 0.5)),
			Color(m.r, m.g, m.b, 0.45 * pulse))
	highlight.draw_rect(Rect2(g.position, Vector2(0.5, g.size.y)), Color(m.r, m.g, m.b, 0.8 * pulse))


## ▶ van 4x7 eenheden (op het 2x-raster 8x14 fijne pixels): gevuld als hij gekozen is,
## anders alleen een omtrek.
func _draw_arrow(left_mid: Vector2, col: Color, filled: bool) -> void:
	var p := left_mid.round()
	var pts := PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(4.5, 0), p + Vector2(0, 3.5)])
	if filled:
		var m := UiStyle.MAGENTA
		highlight.draw_colored_polygon(PackedVector2Array([p + Vector2(-1, -4.5), p + Vector2(5.5, 0),
				p + Vector2(-1, 4.5)]), Color(m.r, m.g, m.b, 0.3))
		highlight.draw_colored_polygon(pts, col)
		highlight.draw_line(p + Vector2(0.25, -2.5), p + Vector2(0.25, 2.5), UiStyle.MAGENTA_HOT, 0.5)
	else:
		highlight.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), col, 0.5)
