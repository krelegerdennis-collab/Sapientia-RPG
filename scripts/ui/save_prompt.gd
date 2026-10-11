extends CanvasLayer
## v0.11 Kleine vraag in het veldmenu met Ja / Nee (v0.14: o.a. 'Kort zwaard weggooien?'
## in Uitrusting; het opslaan zelf heeft nu een eigen scherm, save_screen.gd).
## (Het tekstvak Dialog kan hier niet: dat ligt onder het menu en wordt door de speler
## doorgeklikt, die tijdens het menu op slot staat.)
## omhoog/omlaag + A, tikken, B = Nee.  Signaal answered(true = Ja).

signal answered(yes: bool)

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
## v0.14: menukleuren uit één bestand (menu_colors.gd), niet meer de neon van ui_style.gd
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const TargetList := preload("res://scripts/ui/target_list.gd")

const LAYER := 22
const BUTTON_SIZE := Vector2(72, 16)
const DIM_ALPHA := 0.4

var question := "Save progress?"
var detail := ""
## v0.14: 'Nee' heeft eerst de focus (bv. bij Weggooien in Uitrusting).
var default_no := false
var root: Control
var box: PanelContainer
var yes_button: Button
var no_button: Button
var _quiet_frame := -1
var _done := false


func _ready() -> void:
	_quiet_frame = Engine.get_process_frames()
	layer = LAYER
	root = Control.new()
	root.theme = load(UiMenu.THEME_PATH)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(MenuColors.DIM.r, MenuColors.DIM.g, MenuColors.DIM.b, DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	box = UiMenu.panel(MenuColors.BORDER)
	root.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	col.add_child(UiMenu.label(question, MenuColors.TEXT))
	if detail != "":
		col.add_child(UiMenu.label(detail, MenuColors.TEXT_DIM))
	yes_button = UiMenu.button("Yes")
	yes_button.custom_minimum_size = BUTTON_SIZE
	yes_button.pressed.connect(answer.bind(true))
	col.add_child(yes_button)
	no_button = UiMenu.button("No")
	no_button.custom_minimum_size = BUTTON_SIZE
	no_button.pressed.connect(answer.bind(false))
	col.add_child(no_button)
	TargetList.link_ring([yes_button, no_button])
	(no_button if default_no else yes_button).grab_focus()
	_center.call_deferred()


func _center() -> void:
	box.reset_size()
	box.position = ((root.size - box.size) / 2.0).round()


func answer(yes: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit(yes)
	queue_free()


func _process(_delta: float) -> void:
	if _done or Engine.get_process_frames() <= _quiet_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
		answer(false)
		return
	UiMenu.pad_nav(root.get_viewport())
