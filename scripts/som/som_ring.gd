extends CanvasLayer
## SoM-proef: PAUZE-RINGMENU (Secret of Mana-stijl). Openen = get_tree().paused (alles bevriest);
## dit menu draait door (PROCESS_MODE_ALWAYS). Twee ringen: Items en Skills (bestaande data).
## Bediening: tik op een keuze, of links/rechts draaien + A kiezen; omhoog/omlaag = andere ring;
## B (cancel) of de Ring-knop = sluiten zonder keuze. De keuze landt na het sluiten in realtime
## (SomArena.on_ring_closed -> resolve). PLACEHOLDER-opmaak (gewone knoppen op een cirkel).

const SomData := preload("res://scripts/data/som_data.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const THEME := preload("res://assets/theme.tres")
const RADIUS := Vector2(86, 52)

var arena: Node
var is_open := false
var tab := "items"
var selected := 0
var entries: Array = []
var root: Control
var buttons: Array[Button] = []
var title: Label
var _was_paused := false
var _open_frame := -1
## Frame waarin het menu sloot (dan telt dezelfde A niet ook als slag).
var closed_frame := -1


func _ready() -> void:
	layer = 12
	name = "SomRing"
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close({}))
	root.add_child(dim)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	root.add_child(title)


func open() -> void:
	is_open = true
	_open_frame = Engine.get_process_frames()
	_was_paused = get_tree().paused
	get_tree().paused = true
	root.visible = true
	_build()


func close(choice: Dictionary) -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	get_tree().paused = _was_paused
	closed_frame = Engine.get_process_frames()
	arena.on_ring_closed(choice)


func switch_tab() -> void:
	tab = "skills" if tab == "items" else "items"
	selected = 0
	_build()


func _build() -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	entries = arena.ring_entries().get(tab, [])
	var vs := root.get_viewport_rect().size
	var c := vs / 2.0
	title.text = "< %s >" % (SomData.TXT_ITEMS if tab == "items" else SomData.TXT_SKILLS)
	title.size = Vector2(120, 12)
	title.position = (c - Vector2(60, 8)).round()
	var n := maxi(1, entries.size())
	for i in entries.size():
		var b := UiMenu.button(str(entries[i]["label"]))
		b.name = "Ring_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(b)
		b.reset_size()
		var a := -PI / 2.0 + TAU * float(i) / float(n)
		b.position = (c + Vector2(cos(a), sin(a)) * RADIUS - b.size / 2.0).round()
		b.pressed.connect(func() -> void: choose(i))
		buttons.append(b)
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	_highlight()


func _highlight() -> void:
	for i in buttons.size():
		buttons[i].modulate = Color(1, 1, 0.5) if i == selected else Color(0.75, 0.75, 0.8)


func choose(i: int) -> void:
	if i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	close({"kind": e["kind"], "id": e["id"], "caster": e.get("caster", "")})


func _process(_delta: float) -> void:
	if not is_open or Engine.get_process_frames() == _open_frame:
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed(arena.RING_ACTION):
		close({})
	elif Input.is_action_just_pressed("interact"):
		choose(selected)
	elif Input.is_action_just_pressed("move_right"):
		selected = (selected + 1) % maxi(1, entries.size())
		_highlight()
	elif Input.is_action_just_pressed("move_left"):
		selected = (selected - 1 + maxi(1, entries.size())) % maxi(1, entries.size())
		_highlight()
	elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		switch_tab()
