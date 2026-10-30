extends StaticBody2D
## Interactie in een extra kamer: tekst, poort, diensten of een bestaand scherm.

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")
const Kamers := preload("res://world_warper/kamers/kamers.gd")
const Gesprek := preload("res://world_warper/kamers/echo_gesprek.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")
const WerkScherm := preload("res://scripts/ui/werkplaats_scherm.gd")

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
	if p.has("tint"):
		spr.modulate = p["tint"]
	add_child(spr)
	var titel := Kamers.label(bron)
	if titel == "":
		return
	var breed := 72.0 if bron == "grot_ingang" else 56.0
	var lab := Label.new()
	lab.text = titel
	lab.position = Vector2(-breed * 0.5, -28)
	lab.size = Vector2(breed, 12)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", FONT)
	lab.add_theme_font_size_override("font_size", 10)  # Dauwpixel is 1:1 op 10; op 8 vallen pixelkolommen weg (W leek V)
	lab.add_theme_color_override("font_color", Color("f2e9d8"))
	add_child(lab)


func interact(player: Node) -> void:
	match bron:
		"echo":
			_zeg(Kamers.ECHO_REGELS, "ECHO")
		"echo_grot", "grot_ingang":
			_grot(player)
		"werk":
			_werk(player)
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


func _werk(player: Node) -> void:
	if Kamers.RECEPTEN.is_empty():
		_zeg(Kamers.WERK_REGELS, "")
		return
	if get_tree().current_scene.get_node_or_null("WerkScherm") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var scherm := WerkScherm.new()
	scherm.name = "WerkScherm"
	scherm.closed.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(scherm)


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
	if ok:
		UiSfx.play(UiSfx.SAVE)
	_zeg([Kamers.OPGESLAGEN if ok else Kamers.OPSLAAN_MISLUKT], "")


func _wissel(player: Node) -> void:
	if not PartyBench.in_rustkamer(str(GameState.current_map)):
		_zeg([PartyBench.ALLEEN_HIER], "")
		return
	if get_tree().current_scene.get_node_or_null("WisselScherm") != null:
		return
	if "input_locked" in player:
		player.input_locked = true
	var scherm := PartyWissel.new()
	scherm.name = "WisselScherm"
	scherm.dicht.connect(func() -> void:
		if is_instance_valid(player) and "input_locked" in player:
			player.input_locked = false
	)
	get_tree().current_scene.add_child(scherm)
