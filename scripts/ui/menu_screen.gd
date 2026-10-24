extends CanvasLayer
## v0.11 Basis voor een scherm van het veldmenu (Items, Status, Magie, Opties).
## Zelfde opbouw als het bestiarium: een donker venster over het hele scherm met
##   bovenaan: titel links, (optioneel extra knoppen) en een grote 'Terug'-knop rechts
##   midden:   'content' (VBoxContainer) - hier bouwt het scherm zijn inhoud in
##   onderaan: een hulpregel ('hint'), of tijdelijk een melding (show_message)
## Besturing: joystick/pijltjes + A (UiMenu.pad_nav), B / MENU = terug, en tikken.
## Een scherm erft hiervan met  extends "res://scripts/ui/menu_screen.gd"  en vult
## _build() en (optioneel) _handle_input() en back() in.

signal closed

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const PartyCard := preload("res://scripts/ui/party_card.gd")
const UiTouch := preload("res://scripts/ui/ui_touch.gd")
const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const SafeArea := preload("res://scripts/ui/safe_area.gd")

const LAYER := 21
const FRAME_INSET := 6         # afstand venster - schermrand
const PAD_X := 12              # inhoud - schermrand (links/rechts)
const PAD_Y := 9               # inhoud - schermrand (boven/onder)
## Oude minimale tikhoogte. Bestaande suites toetsen hier tegenaan (alles >= ROW_H, en 'alles binnen het scherm')
## en het uitrustingsscherm past alleen met regels van 16. Nieuwe en aangepaste knoppen gebruiken TOUCH_H.
const ROW_H := 16
## Tikdoel van 48dp (UiTouch.MIN_UNITS): minimale hoogte van een knop in een menu.
const TOUCH_H := UiTouch.MIN_UNITS
## Metadata op een knop die bewust compact blijft (te veel regels voor 216 hoog, bestaande suites toetsen de
## indeling). De test telt ze en vergelijkt met docs/UX_POLISH_WM1.md; nieuwe knoppen horen hier niet bij.
const META_EXEMPT := "touch_exempt"
const BACK_W := 56             # breedte van de 'Terug'-knop (groot genoeg voor een duim)
const MESSAGE_TIME := 2.5      # zo lang blijft een melding staan (seconden)
const DEFAULT_HINT := "A: choose   B: back"

var root: Control
var header_row: HBoxContainer
var header: Label
var back_button: Button
var content: VBoxContainer
var hint: Label
var hint_text := DEFAULT_HINT
var _message_left := 0.0
## Frame waarin dit scherm open ging (of een sub-stap wisselde): in dat frame geen
## knoppen verwerken, anders telt dezelfde druk op A/B dubbel.
var _quiet_frame := -1


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
	layer = LAYER
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# veilige zone (notch/camera-gat links of rechts, gebarenbalk onder): 0 op PC en headless
	var safe := SafeArea.insets(get_viewport())
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiMenu.window_style(MenuColors.BORDER_DARK, 0.97, true))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = FRAME_INSET + safe.x
	bg.offset_top = FRAME_INSET + safe.y
	bg.offset_right = -FRAME_INSET - safe.z
	bg.offset_bottom = -FRAME_INSET - safe.w
	root.add_child(bg)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = PAD_X + safe.x
	outer.offset_top = PAD_Y - 3.0 + safe.y   # de koprij is 48dp hoog (Back): 3 px terug zodat alles blijft passen
	outer.offset_right = -PAD_X - safe.z
	outer.offset_bottom = -PAD_Y + 2 - safe.w
	outer.add_theme_constant_override("separation", 3)
	root.add_child(outer)
	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	outer.add_child(header_row)
	header = UiMenu.label("", MenuColors.TITLE)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header)
	back_button = UiMenu.button("Back")
	back_button.custom_minimum_size = Vector2(BACK_W, TOUCH_H)
	UiSfx.tag(back_button, UiSfx.CANCEL)
	back_button.pressed.connect(back)
	header_row.add_child(back_button)
	var line := ColorRect.new()
	line.color = MenuColors.LINE
	line.custom_minimum_size = Vector2(0, 1)
	outer.add_child(line)
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	outer.add_child(content)
	hint = UiMenu.label(hint_text, MenuColors.TEXT_DIM)
	hint.clip_text = true
	outer.add_child(hint)
	_build()


## Inhoud opbouwen (in het scherm zelf).
func _build() -> void:
	pass


## Zet 'content' in een ScrollContainer: een lange lijst met rijen van 48dp scrolt i.p.v. over de rand te lopen.
## 'content' blijft dezelfde VBox (kinderen en namen ongewijzigd). Aanroepen aan het begin van _build().
func scroll_content() -> ScrollContainer:
	var outer := content.get_parent()
	var at := content.get_index()
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.scroll_deadzone = 6
	outer.remove_child(content)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	outer.add_child(scroll)
	outer.move_child(scroll, at)
	return scroll


## Extra toetsen per frame (links/rechts e.d.), in het scherm zelf.
func _handle_input() -> void:
	pass


## B / MENU / 'Terug': standaard = scherm dicht. Een scherm met een tussenstap (doel
## kiezen) gaat eerst een stap terug.
func back() -> void:
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


## Melding in de onderste regel (bv. 'Kees krijgt 30 HP terug.'); daarna weer de hint.
func show_message(text: String, color := MenuColors.INFO) -> void:
	hint.text = text
	hint.add_theme_color_override("font_color", color)
	_message_left = MESSAGE_TIME


func clear_message() -> void:
	_message_left = 0.0
	if hint:
		hint.text = hint_text
		hint.add_theme_color_override("font_color", MenuColors.TEXT_DIM)


func set_hint(text: String) -> void:
	hint_text = text
	if _message_left <= 0.0 and hint:
		hint.text = text


## Laatste melding (of de hint) - handig voor de autotest.
func message_text() -> String:
	return hint.text


func quiet() -> void:
	_quiet_frame = Engine.get_process_frames()


## -1 = links, +1 = rechts, 0 = niets (joystick, pijltjes of A/D; telt één keer per druk).
static func horizontal_pressed() -> int:
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		return -1
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		return 1
	return 0


## Links/rechts mag de focus niet naar een andere knop laten springen (dat doen we zelf).
static func lock_horizontal_focus(c: Control) -> void:
	c.focus_neighbor_left = NodePath(".")
	c.focus_neighbor_right = NodePath(".")


## Kleine knop ('<', '>') die je alleen aantikt; de joystick doet hetzelfde met links/rechts.
static func arrow_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TOUCH_H, ROW_H)   # breed genoeg; de hoogte rekt mee met de rij waar hij in staat
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.add_theme_color_override("font_color", MenuColors.ACCENT_SOFT)
	b.add_theme_color_override("font_hover_color", MenuColors.ACCENT)
	b.add_theme_color_override("font_pressed_color", MenuColors.ACCENT)
	return b


## Regel die hier niet bruikbaar is: grijze tekst (ook met focus iets donker-magenta),
## maar wel te kiezen, zodat de uitleg/melding te zien is.
static func _grey(b: Button) -> void:
	b.set_meta("greyed", true)
	b.focus_entered.connect(func(): _recolor_grey(b))
	b.focus_exited.connect(func(): _recolor_grey(b))
	_recolor_grey(b)


static func _recolor_grey(b: Button) -> void:
	var c := MenuColors.ACCENT_GREY if b.has_focus() else MenuColors.TEXT_OFF
	if bool(b.get_meta("permanent", false)):
		c = MenuColors.PERMANENT if b.has_focus() else MenuColors.PERMANENT_DIM
	_set_button_color(b, c)


## Permanent item (Blauwe Kist, Het Gesimuleerde Archief): blauwe tekst. Een grijs item blijft grijs
## (donkerder blauw), een gewoon item houdt zijn focuskleur.
static func tint_permanent(b: Button) -> void:
	b.set_meta("permanent", true)
	if is_button_greyed(b):
		_recolor_grey(b)
	else:
		b.add_theme_color_override("font_color", MenuColors.PERMANENT)


static func is_button_greyed(b: Button) -> bool:
	return bool(b.get_meta("greyed", false))


## Het gekozen item/de gekozen spreuk blijft gemarkeerd (gedimd magenta) terwijl je een
## held kiest.
static func mark_chosen(b: Button) -> void:
	if b == null:
		return
	b.text = "> " + str(b.get_meta("label", ""))
	_set_button_color(b, MenuColors.ACCENT_SOFT)


static func _set_button_color(b: Button, c: Color) -> void:
	for k in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, c)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			hint.text = hint_text
			hint.add_theme_color_override("font_color", MenuColors.TEXT_DIM)
	if Engine.get_process_frames() <= _quiet_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		UiSfx.play(UiSfx.CANCEL)
		back()
		return
	_handle_input()
	UiMenu.pad_nav(root.get_viewport())
