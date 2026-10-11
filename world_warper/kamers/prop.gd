extends StaticBody2D
## Interactie in een extra kamer: tekst, poort, diensten of een bestaand scherm.

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const Gesprek := preload("res://world_warper/kamers/echo_gesprek.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")

@export var bron := ""


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var vorm := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	vorm.shape = rect
	add_child(vorm)
	var p: Dictionary = Kamers.plaatje(bron)
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pad := str(p.get("pad", ""))
	if pad != "" and ResourceLoader.exists(pad):
		spr.texture = load(pad)
	spr.hframes = maxi(1, int(p.get("h", 1)))
	spr.vframes = maxi(1, int(p.get("v", 1)))
	spr.offset = p.get("offset", Vector2.ZERO)
	add_child(spr)
	var titel := Kamers.label(bron)
	if titel == "":
		return
	var lab := Label.new()
	lab.text = titel
	lab.position = Vector2(-28, -28)
	lab.size = Vector2(56, 12)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", FONT)
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", Color("f2e9d8"))
	add_child(lab)


func interact(player: Node) -> void:
	match bron:
		"echo":
			_zeg(Kamers.ECHO_REGELS, "ECHO")
		"echo_grot":
			_grot(player)
		"werk":
			_zeg(Kamers.WERK_REGELS, "")
		"kern":
			_zeg([Kamers.KERN_ZIN], "")
		"handel":
			_handel(player)
		"voortgang":
			_zeg(Kamers.voortgang_regels(GameState.story_step, GameState.story_flags, Story.active_quest()), "")
		"warp":
			_warp(player)
		"bestiarium", "codex":
			_open_scherm(bron, player)
		"oefening":
			_oefening(player)
		"opslaan":
			_opslaan(player)
		"helen":
			Kamers.helen(GameState.party)
			_zeg([Kamers.GEGENEZEN], "")
		"wisselen":
			_wissel(player)
		_:
			pass


func _zeg(regels: Array, spreker: String) -> void:
	var lines: Array[String] = []
	for r in regels:
		lines.append(str(r))
	Dialog.show_lines(lines, spreker)


func _grot(player: Node) -> void:
	if get_node_or_null("Gesprek") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var gesprek := Gesprek.new()
	gesprek.name = "Gesprek"
	gesprek.klaar.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player and not GameState.changing_map:
			player.input_locked = false
		if is_instance_valid(gesprek):
			gesprek.queue_free()
	)
	add_child(gesprek)
	gesprek.praat()


func _warp(player: Node) -> void:
	var doel := Kamers.warp_doel()
	if doel.is_empty() or str(doel.get("path", "")) == "":
		_zeg([Kamers.GEEN_POORT], "")
		return
	if "input_locked" in player:
		player.input_locked = true
	GameState.change_map(str(doel["path"]), str(doel["spawn"]))


func _handel(player: Node) -> void:
	var shop_id := Kamers.endgame_winkel()
	if shop_id == "":
		_zeg([Kamers.HANDEL_DICHT], "")
		return
	if get_tree().current_scene.get_node_or_null("ShopScreen") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var shop := ShopScreen.new()
	shop.name = "ShopScreen"
	shop.shop_id = shop_id
	shop.closed.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(shop)


func _open_scherm(welk: String, player: Node) -> void:
	if not Kamers.scherm_beschikbaar(welk):
		_zeg([Kamers.GEEN_SCHERM], "")
		return
	var scene := get_tree().current_scene
	if scene.get_node_or_null("BeeldScherm") != null:
		return
	var scherm: CanvasLayer = load(Kamers.scherm_pad(welk)).new()
	scherm.name = "BeeldScherm"
	if "input_locked" in player:
		player.input_locked = true
	if scherm.has_signal("closed"):
		scherm.closed.connect(func() -> void:
			if is_instance_valid(player) and "input_locked" in player:
				player.input_locked = false
		)
	scene.add_child(scherm)


func _oefening(player: Node) -> void:
	if GameState.in_battle or GameState.changing_map:
		return
	var tile := Vector2i.ZERO
	var facing := Vector2i.DOWN
	if player.has_method("get_tile"):
		tile = player.get_tile()
	if "facing" in player:
		facing = player.facing
	if "input_locked" in player:
		player.input_locked = true
	GameState.start_battle(Kamers.oefen_groep(), tile, facing, "", false, 0, false, true)
	if not GameState.in_battle and "input_locked" in player:
		player.input_locked = false


func _opslaan(player: Node) -> void:
	var tile := Vector2i.ZERO
	var facing := Vector2i.DOWN
	if player.has_method("get_tile"):
		tile = player.get_tile()
	if "facing" in player:
		facing = player.facing
	var ok := GameState.save_game(tile, facing)
	_zeg([Kamers.OPGESLAGEN if ok else Kamers.OPSLAAN_MISLUKT], "")


func _wissel(player: Node) -> void:
	if GameState.party.size() < 2:
		_zeg([Kamers.NIEMAND_WISSEL], "")
		return
	if get_tree().current_scene.get_node_or_null("WisselScherm") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var scherm := WisselScherm.new()
	scherm.name = "WisselScherm"
	scherm.gekozen.connect(func(index: int) -> void:
		if index < 0:
			return
		if not Kamers.naar_voren(GameState.party, index):
			_zeg([Kamers.AL_VOORAAN], "")
			return
		var held: Dictionary = GameState.party[0]
		_zeg([Kamers.VOORAAN % str(held.get("name", ""))], "")
	)
	scherm.dicht.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(scherm)


class WisselScherm extends CanvasLayer:
	signal gekozen(index: int)
	signal dicht

	const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

	func _ready() -> void:
		layer = 22
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.gui_input.connect(_op_gui)
		add_child(root)
		var kolom := VBoxContainer.new()
		kolom.position = Vector2(48, 24)
		kolom.size = Vector2(288, 168)
		kolom.add_theme_constant_override("separation", 4)
		root.add_child(kolom)
		var kop := Label.new()
		kop.text = "Zet iemand vooraan"
		kop.add_theme_font_override("font", FONT)
		kop.add_theme_font_size_override("font_size", 8)
		kop.add_theme_color_override("font_color", Color("f2e9d8"))
		kolom.add_child(kop)
		var i := 0
		for h in GameState.party:
			if h is Dictionary:
				var held := h as Dictionary
				var knop := Button.new()
				knop.text = str(held.get("name", ""))
				knop.custom_minimum_size = Vector2(0, 22)
				knop.add_theme_font_override("font", FONT)
				knop.add_theme_font_size_override("font_size", 8)
				knop.pressed.connect(_kies.bind(i))
				kolom.add_child(knop)
			i += 1
		var terug := Button.new()
		terug.text = "Terug"
		terug.custom_minimum_size = Vector2(0, 22)
		terug.add_theme_font_override("font", FONT)
		terug.add_theme_font_size_override("font_size", 8)
		terug.pressed.connect(_sluit)
		kolom.add_child(terug)

	func _kies(index: int) -> void:
		gekozen.emit(index)
		_sluit()

	func _op_gui(event: InputEvent) -> void:
		if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
			_sluit()

	func _sluit() -> void:
		dicht.emit()
		queue_free()
