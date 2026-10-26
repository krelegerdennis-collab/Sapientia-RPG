extends CanvasLayer
## Tekstvak (autoload "Dialog"). Overal te gebruiken met:
##     Dialog.show_lines(["Regel 1", "Regel 2"], "Naam")
##     Dialog.show_lines(lines, "Naam", spreker_node)   (v0.16: node waar de ballon naar wijst)
## 'interact' (Spatie/Enter/A-knop) gaat naar de volgende regel.
## v0.10: "{naam}" in een regel wordt de naam van de speler.
## Vraag met keuzes:  var i: int = await Dialog.ask("Opslaan?", ["Ja", "Nee"])
##   omhoog/omlaag kiest, A bevestigt, B = laatste keuze (meestal "Nee"), of tik erop.
##
## v0.16 LUFIA 2-STIJL (wens Dennis, ref. Lufia 2; art van RPG ART, art_tekstvak_v15/out):
##   - personage praat (spreker ingevuld) -> blauwe SPRAAKBALLON (assets/ui/ballon_blauw.png) met
##     een staartje (assets/ui/ballon_staart.png) dat naar de spreker op het scherm wijst:
##     staart omhoog als de ballon ONDER de spreker staat, omlaag als hij erboven staat. Geen
##     spreker in beeld (of niet te vinden) -> ballon zonder staart. De naam staat in een klein
##     blauw tabje linksboven (rechts als de staart daar zit).
##   - verteller / systeem / tutorial / kisten (geen spreker) -> blauw TEKSTVAK
##     (assets/ui/tekstvak_blauw.png).
##   - de oude pixel-ruis (GlitchNoise) is weg: de vakken zijn volledig dekkend.
## PLEK (v0.16): standaard ONDERIN, net boven de touch-knoppen (D-pad links, A/B rechts), zodat
## die de tekst niet bedekken. Zou het vak daar over de speler of over het ding waar hij mee
## praat vallen (kist, NPC, bordje), dan eerst een smaller vak rechts van de D-pad (dat kan
## lager, tot net boven A/B), en pas als ook dat niet kan bovenin. Gekozen bij het openen.
## Zonder speler (titel, gevecht) gewoon onderin.

signal finished

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")

## Letters per seconde voor het typemachine-effect.
@export var chars_per_second := 40.0

var is_open := false
var _lines: Array = []
var _index := 0
var _shown := 0.0
var _blink := 0.0
## Keuzes (leeg = gewoon tekst)
var choices: Array = []
var choice_index := 0
var choice_result := -1
var _choice_box: BoxContainer
var _choice_labels: Array[Label] = []
## Plek van het tekstvak: true = onderin (standaard, v0.16), false = bovenin.
var at_bottom := true
## v0.16 Welke plek is gekozen: "onder" (volle breedte boven de knoppen), "onder_smal" (rechts
## van de D-pad, tot net boven A/B) of "boven".
var placement := "onder"
## v0.16 Stijl: "ballon" (personage) of "vak" (verteller/systeem).
var style_kind := "vak"
## v0.16 Staartje: "" (geen), "up" (ballon onder de spreker) of "down" (ballon erboven).
var tail_dir := ""
## v0.16 De spreker (Node2D op de map) of null.
var speaker_node: Node2D = null
## Bovenkant van het vak bovenin (y) en minimale hoogte (2 regels, zoals vroeger 48).
const TOP_Y := 15.0
## Hoogste y waar een vak mag beginnen: erboven valt het naamtabje (11 hoog) buiten beeld.
const MIN_TOP := 12.0
const MIN_H := 44.0
const SIDE := 8.0
## Ruimte onder het onderste vak als er geen touch-knoppen zijn: 8 px (zoals de zijkanten).
const BOTTOM_MARGIN := 8.0
## Ruimte boven het midden van speler/ding die vrij moet blijven (sprite + icoon erboven).
const CLEAR_ABOVE := 26.0
## Binnenmarges van de tekst (zie TextLabel in dialog_box.tscn).
const PAD_L := 10.0
const PAD_R := 12.0
const PAD_T := 8.0
const PAD_B := 4.0
const LINE_SPACING := 4
## Keuzes: tikmaat (25 hoog, ~48 dp). Korte keuzes (Yes/No, Next/Skip) staan rechtsonder onder elkaar, zoals altijd.
## Langere keuzes (tot 3) staan op een rij onderin het vak, zodat het vak laag blijft en de speler niet bedekt;
## bij 4+ keuzes staan ze onder elkaar met 20 hoog.
const CHOICE_ROW_TOUCH := 25.0
const CHOICE_ROW_MANY := 20.0
const CHOICE_MIN_W := 60.0
const CHOICE_GAP := 4.0
## Zijn alle keuzes smaller dan dit (met '> '), dan blijven ze rechtsonder onder elkaar staan.
const CHOICE_STACK_MAX_W := 84.0
const CHOICE_ROW_BOTTOM := 3.0     # ruimte onder een rij keuzes (binnen de rand van het vak)
const CHOICE_PAD_W := 12.0
## Staart (16x12 per frame): punt op (6,10) bij omlaag, (6,1) bij omhoog (LEESMIJ.txt).
const TAIL_SIZE := Vector2(16, 12)
const TAIL_TIP_X := 6.0

@onready var panel: Panel = $Panel
@onready var name_tab: Control = $Panel/NameTab
@onready var name_label: Label = $Panel/NameTab/NameLabel
@onready var text_label: Label = $Panel/TextLabel
@onready var arrow: Control = $Panel/Arrow
@onready var tail: TextureRect = $Panel/Tail

var _styles := {}
var _tail_frames: Array[AtlasTexture] = []


func _ready() -> void:
	# Thema (pixel-lettertype) pas hier laden: dit tekstvak is een autoload en wordt
	# al geladen voordat Godot bij de allereerste keer openen de assets heeft geïmporteerd.
	panel.theme = load("res://assets/theme.tres")
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_styles = {"vak": UiStyleC.blue_box("vak"), "ballon": UiStyleC.blue_box("ballon")}
	var tab_style := UiStyleC.blue_box("ballon", Vector4(5, 0, 5, 0))
	name_tab.add_theme_stylebox_override("panel", tab_style)
	if name_tab.has_method("set_color"):
		name_tab.set_color(UiStyleC.BOX_NAME)
	text_label.add_theme_color_override("font_color", UiStyleC.BOX_TEXT)
	text_label.add_theme_color_override("font_shadow_color", UiStyleC.BOX_SHADOW)
	text_label.add_theme_constant_override("line_spacing", LINE_SPACING)
	var sheet: Texture2D = load(UiStyleC.TAIL_TEXTURE)
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * TAIL_SIZE.x, 0, TAIL_SIZE.x, TAIL_SIZE.y)
		_tail_frames.append(at)
	tail.texture = _tail_frames[0]
	tail.size = TAIL_SIZE
	_apply_style("vak")
	panel.hide()


## v0.16 De StyleBox van het vak nu (voor de tests).
func box_style() -> StyleBox:
	return panel.get_theme_stylebox("panel")


func _apply_style(kind: String) -> void:
	style_kind = kind
	panel.add_theme_stylebox_override("panel", _styles.get(kind, _styles["vak"]))


func show_lines(lines: Array, speaker := "", source: Node = null) -> void:
	if lines.is_empty():
		return
	if not _asking:
		choices = []
		_clear_choices()
	var named: Array = []
	for l in lines:
		named.append(str(l).replace("{naam}", GameState.player_name))
	_lines = named
	_index = 0
	name_label.text = speaker
	name_tab.visible = speaker != ""
	if name_tab.has_method("set_text"):
		name_tab.set_text(speaker)
	speaker_node = _find_speaker(speaker, source)
	_apply_style("ballon" if speaker != "" else "vak")
	_update_placement()
	is_open = true
	panel.show()
	_show_current()


var _asking := false
var _blip_at := 0
const BLIP_EVERY := 3


## Toon een vraag met keuzes en wacht tot er gekozen is. Geeft de index terug.
func ask(question: String, options: Array, speaker := "", default_index := 0) -> int:
	_asking = true
	choices = options.duplicate()
	choice_index = clampi(default_index, 0, maxi(0, options.size() - 1))
	choice_result = -1
	show_lines([question], speaker)
	_asking = false
	_build_choices()
	await finished
	return choice_result


# ---------------------------------------------------------------- spreker
## v0.16 Wie praat er? 1) de meegegeven node, 2) de speler (zijn eigen naam), 3) een object
## op de map met npc_name == spreker (zichtbaar). Anders null (dan geen staartje).
func _find_speaker(speaker: String, source: Node) -> Node2D:
	if speaker == "" or not is_inside_tree() or GameState.in_battle:
		return null
	if source is Node2D and is_instance_valid(source) and source.is_inside_tree():
		return source
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var p = scene.get("player") if "player" in scene else null
	if p is Node2D and is_instance_valid(p) and speaker == GameState.player_name:
		return p
	var objects := scene.get_node_or_null("Objects")
	if objects == null:
		return null
	for n in objects.get_children():
		if n is Node2D and n.visible and "npc_name" in n and str(n.get("npc_name")) == speaker:
			return n
	return null


## Plek van de spreker op het scherm (midden van zijn tile) of null als hij er niet is.
func speaker_screen_pos():
	if speaker_node == null or not is_instance_valid(speaker_node) or not speaker_node.is_inside_tree():
		return null
	var pos: Vector2 = speaker_node.get_global_transform_with_canvas().origin
	var vs := get_viewport().get_visible_rect().size
	if not Rect2(Vector2.ZERO, vs).has_point(pos):
		return null
	return pos


# ---------------------------------------------------------------- plek
## v0.16 Kies de plek: de eerste kandidaat (onder, onder_smal, boven) die niet over de speler of
## het ding waar hij naar kijkt valt. Valt alles erover, dan de kandidaat met de minste overlap.
func _update_placement() -> void:
	var focus := _focus_rects()
	var cands := candidates()
	var best: Dictionary = cands[0]
	var best_overlap := INF
	for c in cands:
		var overlap := 0.0
		for r in focus:
			for b in _rects_for(c["rect"]):
				var i: Rect2 = b.intersection(r)
				if b.intersects(r):
					overlap += maxf(i.get_area(), 0.01)
		if overlap <= 0.0:
			best = c
			break
		if overlap < best_overlap:
			best_overlap = overlap
			best = c
	_place(best)


## Alle plekken (in volgorde van voorkeur) voor de huidige tekst: [{"name", "rect", "bottom"}].
func candidates() -> Array:
	var vs := get_viewport().get_visible_rect().size
	var ctrl := _touch_rects()
	var out := []
	var ins := UiTouchC.insets(get_viewport())
	var x0 := SIDE + ins.x
	var x1 := vs.x - SIDE - ins.z
	var min_y := MIN_TOP + ins.y
	var low := _low_candidate("onder", x0, x1, ctrl, vs)
	if (low["rect"] as Rect2).position.y >= min_y:
		out.append(low)
	if ctrl.has("dpad"):
		var dx: float = (ctrl["dpad"] as Rect2).end.x + 4.0
		if x1 - dx >= 200.0:
			var narrow := _low_candidate("onder_smal", dx, x1, ctrl, vs)
			if (narrow["rect"] as Rect2).position.y >= min_y:
				out.append(narrow)
	var w := x1 - x0
	out.append({"name": "boven", "rect": Rect2(x0, TOP_Y + ins.y, w, needed_height(w)), "bottom": false})
	return out


func _low_candidate(cname: String, x0: float, x1: float, ctrl: Dictionary, vs: Vector2) -> Dictionary:
	var w := x1 - x0
	var h := needed_height(w)
	var bottom := vs.y - BOTTOM_MARGIN - UiTouchC.insets(get_viewport()).w
	for k in ctrl:
		var r: Rect2 = ctrl[k]
		if r.position.x < x1 and r.end.x > x0:
			bottom = minf(bottom, r.position.y - 2.0)
	return {"name": cname, "rect": Rect2(x0, roundf(bottom - h), w, h), "bottom": true}


## Hoogte van het vak voor alle regels (en de keuzes) bij deze breedte; minstens MIN_H.
func needed_height(w: float) -> float:
	var font: Font = text_label.get_theme_font("font")
	var fs: int = text_label.get_theme_font_size("font_size")
	var lh := font.get_height(fs)
	var tw := maxf(w - PAD_L - PAD_R, 16.0)
	var lines := 1
	for l in _lines:
		var sz := font.get_multiline_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, tw, fs, -1,
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		lines = maxi(lines, maxi(1, roundi(sz.y / lh)))
	var text_h := lines * lh + (lines - 1) * LINE_SPACING
	var h := PAD_T + text_h + PAD_B + 2.0
	if not choices.is_empty():
		var lay := choice_layout(w)
		if bool(lay["horizontal"]):
			h = maxf(h, PAD_T + text_h + float(lay["row_h"]) + CHOICE_ROW_BOTTOM)
		else:
			h = maxf(h, PAD_T + lh + choices.size() * (choice_row_h() + 1.0) + 4.0)
	return ceilf(maxf(MIN_H, h))


## Zet het vak op een plek (+ staartje en naamtabje).
func _place(c: Dictionary) -> void:
	placement = str(c["name"])
	at_bottom = bool(c["bottom"])
	var r: Rect2 = c["rect"]
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.position = r.position
	panel.size = r.size
	_update_tail(r)


## v0.16 Staartje naar de spreker: omhoog als de ballon onder hem staat, omlaag als erboven.
func _update_tail(r: Rect2) -> void:
	tail_dir = ""
	name_tab.position = Vector2(6, -11)
	var sp = speaker_screen_pos() if style_kind == "ballon" else null
	if sp == null:
		tail.visible = false
		return
	var s: Vector2 = sp
	var head_y := s.y - 16.0
	var feet_y := s.y + 8.0
	if feet_y <= r.position.y + 2.0:
		tail_dir = "up"
	elif head_y >= r.end.y - 2.0:
		tail_dir = "down"
	else:
		tail_dir = "up" if s.y < r.get_center().y else "down"
	var tip_x := s.x
	# ballon vlak onder de voeten: punt net naast de spreker, niet over zijn sprite
	if tail_dir == "up" and r.position.y - feet_y < 9.0:
		tip_x = s.x + 10.0
	var lx := clampf(roundf(tip_x - r.position.x - TAIL_TIP_X), 8.0, r.size.x - 8.0 - TAIL_SIZE.x)
	tail.texture = _tail_frames[1 if tail_dir == "up" else 0]
	tail.size = TAIL_SIZE
	tail.position = Vector2(lx, -9.0 if tail_dir == "up" else r.size.y - 3.0)
	tail.visible = true
	# naamtabje niet onder het staartje: dan rechts
	if tail_dir == "up" and name_tab.visible:
		var tab_w := maxf(name_tab.get_combined_minimum_size().x, name_tab.size.x)
		if lx < 6.0 + tab_w + 2.0:
			name_tab.position = Vector2(r.size.x - tab_w - 6.0, -11)


## v0.16 Punt van het staartje op het scherm (of null zonder staart). Voor de tests.
func tail_tip():
	if not tail.visible or tail_dir == "":
		return null
	var base := panel.position + tail.position
	return base + (Vector2(TAIL_TIP_X, 1.0) if tail_dir == "up" else Vector2(TAIL_TIP_X, 10.0))


## Compatibel met v0.14/v0.15: true = onderin (eerste vrije onder-plek), false = bovenin.
func set_at_bottom(bottom: bool) -> void:
	var cands := candidates()
	_place(cands[0] if bottom else cands[cands.size() - 1])


## Schermrechthoeken van het vak op een plek: het venster zelf en (als er een naam bij staat)
## het naamtabje dat er linksboven uitsteekt.
func _rects_for(r: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = [r]
	if name_tab.visible:
		var tab_w := maxf(name_tab.get_combined_minimum_size().x, name_tab.size.x)
		out.append(Rect2(r.position.x + 6.0, r.position.y - 11.0, tab_w, 11.0))
	return out


## Schermrechthoek van het vak nu (voor de tests).
func box_rect() -> Rect2:
	return Rect2(panel.position, panel.size)


## Touch-knoppen in beeld (schermrechthoeken, iets ruimer dan de tikvlakken): "dpad", "a", "b".
func _touch_rects() -> Dictionary:
	var out := {}
	var scene := get_tree().current_scene if is_inside_tree() else null
	var touch: Control = scene.get_node_or_null("TouchControls/Control") as Control if scene else null
	if touch and touch.is_visible_in_tree() and touch.modulate.a > 0.01 and touch.has_method("dpad_center"):
		var xf := touch.get_global_transform_with_canvas()
		var sc := xf.get_scale().x
		var dr: float = (touch.joy_radius() if touch.has_method("joy_radius") else touch.dpad_radius) * 1.25 * sc
		var br: float = touch.button_radius * 1.3 * sc
		var d: Vector2 = xf * touch.dpad_center()
		var a: Vector2 = xf * touch.a_center()
		var b: Vector2 = xf * touch.b_center()
		out["dpad"] = Rect2(d - Vector2(dr, dr), Vector2(dr, dr) * 2.0)
		out["a"] = Rect2(a - Vector2(br, br), Vector2(br, br) * 2.0)
		out["b"] = Rect2(b - Vector2(br, br), Vector2(br, br) * 2.0)
	return out


## Waar moet het vak vanaf blijven? Speler + de tile voor hem (met ruimte voor een icoon erboven).
func _focus_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree() or GameState.in_battle:
		return out
	var scene := get_tree().current_scene
	if scene == null or not ("player" in scene):
		return out
	var p = scene.get("player")
	if not (p is Node2D) or not is_instance_valid(p) or not p.is_inside_tree():
		return out
	var xf: Transform2D = p.get_global_transform_with_canvas()
	var points: Array[Vector2] = [xf.origin]
	if "facing" in p:
		points.append(xf * (Vector2(p.facing) * 16.0))   # 16 = tile-grootte
	# v0.16: ook de spreker zelf niet bedekken (bv. Opa die vanaf een andere tile praat)
	var sp = speaker_screen_pos()
	if sp != null:
		points.append(sp)
	for c in points:
		out.append(Rect2(c + Vector2(-8, -CLEAR_ABOVE), Vector2(16, CLEAR_ABOVE + 8)))
	return out


## Hoogte van een keuzeregel (tikvlak).
func choice_row_h() -> float:
	return CHOICE_ROW_TOUCH if choices.size() <= 3 else CHOICE_ROW_MANY


## Indeling van de keuzes in een vak van breedte w: {"horizontal", "widths", "row_h"}.
## Korte keuzes en 4+ keuzes staan onder elkaar. Tot 3 langere keuzes staan op een rij (breedte naar tekst; past dat
## niet dan krimpen ze en lopen ze over twee regels). Zo blijft het vak laag en de keuzes >= 25 hoog (CHOICE_ROW_TOUCH).
func choice_layout(w: float) -> Dictionary:
	var stacked := {"horizontal": false, "widths": [], "row_h": choice_row_h()}
	var n := choices.size()
	if n == 0 or n > 3:
		return stacked
	var font: Font = text_label.get_theme_font("font")
	var fs: int = text_label.get_theme_font_size("font_size")
	var lh := font.get_height(fs)
	var avail := w - PAD_L - PAD_R - 8.0 - CHOICE_GAP * float(n - 1)
	var natural: Array[float] = []
	var sum := 0.0
	for c in choices:
		var nw := maxf(CHOICE_MIN_W, ceilf(font.get_string_size("> " + str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + CHOICE_PAD_W)
		natural.append(nw)
		sum += nw
	var widest := 0.0
	for nw in natural:
		widest = maxf(widest, nw)
	if widest <= CHOICE_STACK_MAX_W:
		return stacked
	if sum <= avail:
		return {"horizontal": true, "widths": natural, "row_h": CHOICE_ROW_TOUCH}
	var widths: Array[float] = []
	var total := 0.0
	var lines := 1
	for i in n:
		var wi := maxf(CHOICE_MIN_W, floorf(natural[i] * avail / sum))
		widths.append(wi)
		total += wi
		var sz := font.get_multiline_string_size("> " + str(choices[i]), HORIZONTAL_ALIGNMENT_LEFT, wi - CHOICE_PAD_W, fs, -1,
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		lines = maxi(lines, maxi(1, roundi(sz.y / lh)))
	if total > avail + 0.5 or lines > 2:
		return stacked
	return {"horizontal": true, "widths": widths, "row_h": maxf(CHOICE_ROW_TOUCH, float(lines) * lh + 4.0)}


## Passen de keuzes (max. 3) naast elkaar in een vak van breedte w?
func choices_horizontal(w: float) -> bool:
	return bool(choice_layout(w)["horizontal"])


## Schermrechthoeken van de keuzeregels (voor de tests): leeg zolang er geen keuzes zijn.
func choice_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for l in _choice_labels:
		out.append(l.get_global_rect())
	return out


func has_choices() -> bool:
	return is_open and not choices.is_empty()


## Keuze bevestigen (ook voor tikken op een keuze).
func choose(i: int) -> void:
	if not has_choices():
		return
	choice_result = clampi(i, 0, choices.size() - 1)
	UiSfx.play(UiSfx.CONFIRM)
	choices = []
	_clear_choices()
	close()


## B-knop: bij een vraag = laatste keuze ("Nee"); anders gewoon doorklikken.
func cancel() -> void:
	if has_choices() and not _is_typing():
		choose(choices.size() - 1)
	else:
		advance()


func _build_choices() -> void:
	_clear_choices()
	var lay := choice_layout(panel.size.x)
	var horizontal := bool(lay["horizontal"])
	_choice_box = HBoxContainer.new() if horizontal else VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", int(CHOICE_GAP) if horizontal else 1)
	panel.add_child(_choice_box)
	var widths: Array = lay["widths"]
	for i in choices.size():
		var l := Label.new()
		l.custom_minimum_size = Vector2(float(widths[i]) if horizontal else CHOICE_MIN_W, float(lay["row_h"]))
		if horizontal:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if horizontal else HORIZONTAL_ALIGNMENT_LEFT
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_choice_input.bind(i))
		_choice_box.add_child(l)
		_choice_labels.append(l)
	_choice_box.visible = false
	_update_choices()


func _clear_choices() -> void:
	if _choice_box:
		_choice_box.queue_free()
	_choice_box = null
	_choice_labels.clear()


func _on_choice_input(event: InputEvent, i: int) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		choice_index = i
		choose(i)


func _update_choices() -> void:
	if _choice_box == null:
		return
	for i in _choice_labels.size():
		var sel := i == choice_index
		_choice_labels[i].text = ("> " if sel else "  ") + str(choices[i])
		_choice_labels[i].add_theme_color_override("font_color", UiStyleC.HILITE if sel else UiStyleC.TEXT)
	_choice_box.reset_size()
	var bottom := CHOICE_ROW_BOTTOM if _choice_box is HBoxContainer else 4.0
	_choice_box.position = Vector2(panel.size.x - _choice_box.size.x - 16, panel.size.y - _choice_box.size.y - bottom)


## Volgende stap: eerst de hele regel tonen, daarna volgende regel, daarna sluiten.
func advance() -> void:
	if not is_open:
		return
	if _is_typing():
		text_label.visible_characters = -1  # -1 = alles tonen
		return
	if has_choices():
		choose(choice_index)
		return
	_index += 1
	UiSfx.play(UiSfx.ADVANCE)
	if _index >= _lines.size():
		close()
	else:
		_show_current()


func close() -> void:
	is_open = false
	panel.hide()
	finished.emit()


func _show_current() -> void:
	text_label.text = str(_lines[_index])
	text_label.visible_characters = 0
	_shown = 0.0
	_blip_at = 0


func _is_typing() -> bool:
	return text_label.visible_characters != -1


func _process(delta: float) -> void:
	if not is_open:
		return
	if _is_typing():
		_shown += chars_per_second * delta
		# zacht tikje om de BLIP_EVERY letters bij een sprekend personage (niet bij 'Instant' en niet bij de verteller)
		if style_kind == "ballon" and chars_per_second < 1000.0 and int(_shown) - _blip_at >= BLIP_EVERY:
			_blip_at = int(_shown)
			UiSfx.play(UiSfx.BLIP)
		var total := text_label.get_total_character_count()
		text_label.visible_characters = -1 if int(_shown) >= total else int(_shown)
		arrow.visible = false
	elif has_choices():
		arrow.visible = false
		if _choice_box and not _choice_box.visible:
			_choice_box.visible = true
			_update_choices()
		var horizontal := _choice_box is HBoxContainer
		var prev := Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up") \
				or (horizontal and (Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left")))
		var next := Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down") \
				or (horizontal and (Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right")))
		if prev:
			choice_index = (choice_index - 1 + choices.size()) % choices.size()
			UiSfx.play(UiSfx.CURSOR)
			_update_choices()
		elif next:
			choice_index = (choice_index + 1) % choices.size()
			UiSfx.play(UiSfx.CURSOR)
			_update_choices()
	else:
		# Knipperend pijltje: "druk op A om verder te gaan"
		_blink += delta
		arrow.visible = fmod(_blink, 0.8) < 0.5
