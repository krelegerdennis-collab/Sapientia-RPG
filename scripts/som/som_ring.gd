extends CanvasLayer
## SoM-proef: PAUZE-RINGMENU (Secret of Mana-stijl). Openen = get_tree().paused (alles bevriest);
## dit menu draait door (PROCESS_MODE_ALWAYS). Drie ringen: Items, Skills en Magie; een spreuk met één doel opent daarna de doelkeuze.
## Bediening: tik op een keuze, of links/rechts draaien + A kiezen; omhoog/omlaag = andere ring;
## B (cancel) of de Ring-knop = sluiten zonder keuze. De keuze landt na het sluiten in realtime
## (SomArena.on_ring_closed -> resolve). PLACEHOLDER-opmaak (gewone knoppen op een cirkel).

const SomData := preload("res://scripts/data/som_data.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const THEME := preload("res://assets/theme.tres")
const SomFx := preload("res://scripts/som/som_fx.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const RADIUS := Vector2(86, 52)

var arena: Node
var is_open := false
## Ringen in volgorde (omhoog/omlaag draait erdoor). "target" = doelkeuze na een spreuk uit de magie-ring.
const TABS := ["items", "skills", "magic"]
var tab := "items"
## Gekozen spreuk die nog een doel nodig heeft ({} = geen).
var pending_spell := {}
var selected := 0
var entries: Array = []
var root: Control
var buttons: Array[Button] = []
var title: Label
## Naam (+ aantal/MP) van de geselecteerde keuze, op een eigen regel ONDER de ring.
var name_label: Label
## Huidige ringstraal (groeit mee als korte labels elkaar anders zouden raken).
var radius := RADIUS
var bg: TextureRect
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
	var bg_tex := SomFx.tex(SomData.UI_RING_BG)
	if bg_tex:
		bg = TextureRect.new()
		bg.name = "RingBg"
		bg.texture = bg_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	root.add_child(title)
	name_label = Label.new()
	name_label.name = "RingName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	root.add_child(name_label)


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


func switch_tab(dir := 1) -> void:
	if tab == "target":
		tab = "magic"
		pending_spell = {}
	else:
		tab = TABS[(TABS.find(tab) + dir + TABS.size()) % TABS.size()]
	selected = 0
	_build()


func set_tab(t: String) -> void:
	tab = t
	pending_spell = {}
	selected = 0
	_build()


func _tab_title() -> String:
	match tab:
		"skills":
			return SomData.TXT_SKILLS
		"magic":
			return SomData.TXT_MAGIC
		"target":
			return SomData.TXT_TARGET % str(pending_spell.get("label", ""))
	return SomData.TXT_ITEMS


func _build() -> void:
	if tab == "target":
		build_with(arena.spell_targets(str(pending_spell.get("id", "")), str(pending_spell.get("caster", ""))))
	else:
		build_with(arena.ring_entries().get(tab, []))


## Kort label op de ring zelf: met icoon alleen het aantal ("x3") of niets; zonder icoon de
## eerste woord-afkorting. De volledige naam staat onder de ring (name_label).
static func short_label(e: Dictionary, has_icon: bool) -> String:
	if has_icon:
		return ("x%d" % int(e["count"])) if e.has("count") else ""
	var nm := str(e.get("name", e.get("label", "")))
	var w := nm.split(" ")[0] if nm != "" else ""
	return w.substr(0, SomData.RING_SHORT_MAX) if w.length() > SomData.RING_SHORT_MAX else w


## Bouwt de ring voor een gegeven lijst (los aanroepbaar voor de overlap-test).
func build_with(list: Array) -> void:
	for b in buttons:
		root.remove_child(b)
		b.queue_free()
	buttons.clear()
	entries = list
	var vs := root.get_viewport_rect().size
	var c := vs / 2.0
	if bg:
		bg.position = (c - bg.texture.get_size() / 2.0).round()
	title.text = "< %s >" % _tab_title()
	for i in entries.size():
		var ic := icon_for(entries[i])
		var b := UiMenu.button("")
		b.text = short_label(entries[i], ic != null)
		b.name = "Ring_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.icon = ic
		root.add_child(b)
		b.reset_size()
		b.pressed.connect(func() -> void: choose(i))
		b.mouse_entered.connect(func() -> void:
			selected = i
			_highlight())
		buttons.append(b)
	_layout(vs)
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	_highlight()


## Plaatst de knoppen op de ellips; groeit de straal tot geen twee knoppen elkaar raken.
func _layout(vs: Vector2) -> void:
	var c := vs / 2.0
	var n := maxi(1, buttons.size())
	var bw := 0.0
	var bh := 12.0
	for b in buttons:
		bw = maxf(bw, b.size.x)
		bh = maxf(bh, b.size.y)
	var th := title.get_minimum_size().y
	# max. straal: kop boven + naam onder moeten in beeld blijven
	var ry_max := c.y - bh / 2.0 - th * 2.0 - SomData.RING_LABEL_GAP * 2.0
	var rx_max := c.x - bw / 2.0 - 2.0
	radius = RADIUS
	for _k in 12:
		_place_buttons(c, n)
		if not _any_overlap():
			break
		radius = Vector2(minf(radius.x * 1.12, rx_max), minf(radius.y * 1.12, ry_max))
	title.size = title.get_minimum_size()
	title.position = (Vector2(c.x - title.size.x / 2.0, c.y - radius.y - bh / 2.0 - SomData.RING_LABEL_GAP - title.size.y)).round()
	name_label.position.y = roundf(c.y + radius.y + bh / 2.0 + SomData.RING_LABEL_GAP)


func _place_buttons(c: Vector2, n: int) -> void:
	for i in buttons.size():
		var a := -PI / 2.0 + TAU * float(i) / float(n)
		buttons[i].position = (c + Vector2(cos(a), sin(a)) * radius - buttons[i].size / 2.0).round()


func _any_overlap() -> bool:
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			if Rect2(buttons[i].position, buttons[i].size).grow(1).intersects(Rect2(buttons[j].position, buttons[j].size)):
				return true
	return false


## Alle tekst-/knop-rects van de open ring (voor de overlap-test).
func label_rects() -> Array:
	var out: Array = []
	for b in buttons:
		out.append(Rect2(b.position, b.size))
	out.append(Rect2(title.position, title.size))
	if name_label.text != "":
		out.append(Rect2(name_label.position, name_label.size))
	return out


## Icoon uit ring_icons.png (8 x 16x16) voor een item/spreuk; null = geen.
func icon_for(e: Dictionary) -> Texture2D:
	var sheet := SomFx.tex(SomData.UI_RING_ICONS)
	if sheet == null:
		sheet = SomFx.tex(SomData.UI_RING_ICONS_FALLBACK)
	if sheet == null:
		return null
	var id := str(e.get("id", ""))
	if str(e.get("kind", "")) == "spell":
		var si := spell_icon(id)
		if si:
			return si
	var idx := int(SomData.RING_ICON.get(id, -1))
	if idx < 0 and str(e.get("kind", "")) == "spell" and str(GameData.SPELLS.get(id, {}).get("type", "")) == "damage":
		idx = SomData.RING_ICON_DAMAGE
	if idx < 0 or (idx + 1) * 16 > sheet.get_width():
		return null
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(idx * 16, 0, 16, 16)
	return a


## Icoon uit spell_icons.png (4 x 16x16, n op x = 16n) voor een spreuk; null = geen art/geen icoon.
static func spell_icon(id: String) -> Texture2D:
	var sheet := SomFx.tex(SomData.UI_SPELL_ICONS)
	if sheet == null:
		return null
	var idx := int(SomData.SPELL_ICON.get(id, SomData.SPELL_ICON_BY_TYPE.get(str(GameData.SPELLS.get(id, {}).get("type", "")), -1)))
	if idx < 0 or (idx + 1) * 16 > sheet.get_width():
		return null
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(idx * 16, 0, 16, 16)
	return a


func _highlight() -> void:
	for i in buttons.size():
		buttons[i].modulate = Color(1, 1, 0.5) if i == selected else Color(0.75, 0.75, 0.8)
	name_label.text = str(entries[selected].get("label", "")) if selected < entries.size() else ""
	name_label.size = name_label.get_minimum_size()
	name_label.position.x = roundf(root.get_viewport_rect().size.x / 2.0 - name_label.size.x / 2.0)


func choose(i: int) -> void:
	if i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	if tab == "target":
		var q := {"kind": "spell", "id": pending_spell["id"], "caster": pending_spell["caster"], "target": e["target"]}
		pending_spell = {}
		tab = "magic"
		close(q)
		return
	if str(e["kind"]) == "spell" and arena.needs_target(str(e["id"])):
		pending_spell = e
		tab = "target"
		selected = 0
		_build()
		return
	close({"kind": e["kind"], "id": e["id"], "caster": e.get("caster", "")})


func _process(_delta: float) -> void:
	if not is_open or Engine.get_process_frames() == _open_frame:
		return
	if Input.is_action_just_pressed("cancel") and tab == "target":
		switch_tab()       # terug naar de magie-ring
	elif Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed(arena.RING_ACTION):
		close({})
	elif Input.is_action_just_pressed("interact"):
		choose(selected)
	elif Input.is_action_just_pressed("move_right"):
		selected = (selected + 1) % maxi(1, entries.size())
		_highlight()
	elif Input.is_action_just_pressed("move_left"):
		selected = (selected - 1 + maxi(1, entries.size())) % maxi(1, entries.size())
		_highlight()
	elif Input.is_action_just_pressed("move_up"):
		switch_tab(-1)
	elif Input.is_action_just_pressed("move_down"):
		switch_tab(1)
