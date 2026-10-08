class_name DungeonChest
extends StaticBody2D
## v0.14 Gewone KIST in een dungeonkamer (dungeon_rooms.gd "chests"). 1 tile, blokkeert.
## A ervoor = openen: het voorwerp gaat in de tas (GameState.inventory; uitrusting ook, die kun
## je daarna aantrekken in Menu > Uitrusting). EENMALIG per spel: de vlag "kist:<id>" staat in
## GameState.story_flags en gaat mee in de save. Open kist = frame 1 (blijft open).
## Plaatje: assets/sprites/buiten/kist.png (RPG ART, 2 frames 16x16: dicht/open).
## (De speciale schatkist met het zwaard in de puzzelkamer is van RPG CODE, zie HANDOFF_ARCHIEF1.md.)

const TEX := "res://assets/sprites/buiten/kist.png"
## v0.15: plaatje in het thema van de kamer (DungeonRooms.THEMES), zie dungeon_rooms.gd.
const DungeonRoomsTheme := preload("res://scripts/data/dungeon_rooms.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const EMPTY_LINES := ["De kist is leeg."]

var chest_id := ""
var item := ""
var count := 1
var sprite: Sprite2D
## Voor de tests: "", "gekregen" of "leeg".
var last_result := ""


static func flag_of(id: String) -> String:
	return "kist:" + id


static func item_name(id: String) -> String:
	if GameData.ITEMS.has(id):
		return str(GameData.ITEMS[id]["name"])
	if GameData.EQUIPMENT.has(id):
		return str(GameData.EQUIPMENT[id]["name"])
	return id


func setup(d: Dictionary) -> void:
	chest_id = str(d.get("id", "kist"))
	name = "Kist_" + chest_id
	item = str(d.get("item", "drankje"))
	count = maxi(1, int(d.get("n", 1)))
	var t: Array = d.get("tile", [0, 0])
	position = Vector2(int(t[0]), int(t[1])) * 16 + Vector2(8, 8)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	cs.shape = rect
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(DungeonRoomsTheme.themed(TEX))
	sprite.hframes = 2
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.frame = 1 if is_open() else 0


func tile() -> Vector2i:
	return Vector2i((position / 16.0).floor())


func is_open() -> bool:
	return GameState.story_flags.has(flag_of(chest_id))


func interact(_player: Node2D) -> void:
	if Dialog.is_open:
		return
	if is_open():
		last_result = "leeg"
		Dialog.show_lines(EMPTY_LINES)
		return
	# eerst de vlag, dan het voorwerp: nooit dubbel
	GameState.story_flags[flag_of(chest_id)] = true
	GameState.inventory[item] = GameState.item_count(item) + count
	sprite.frame = 1
	last_result = "gekregen"
	var nm := item_name(item)
	Dialog.show_lines(["{naam} opent de kist...", "{naam} vindt: %s!" % (nm if count == 1 else "%dx %s" % [count, nm])])
