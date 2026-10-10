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
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const EMPTY_LINES := ["De kist is leeg."]
const MIMIC_LINES := ["{naam} tilt de deksel op...", "De kist bijt terug! Het is een Mimic!"]
## Het Gesimuleerde Archief: een Mimic-kist is wakker geworden (de kamer start het gevecht).
signal mimic_woke(chest: DungeonChest)
## Een Blauwe Kist is geopend en de databank is veiliggesteld (de kamer slaat dan automatisch op).
signal blue_secured(chest: DungeonChest)

var chest_id := ""
var item := ""
var count := 1
## Task #4 (dungeon van 100 verdiepingen): verdieping van deze kist (0 = gewone kist) en de buit
## ({"items": [{"item", "n"}], "gold", "tier"}, zie dungeon100_scaling.gd; leeg = gewone kist).
var floor_nr := 0
var loot := {}
## Soort kist (dungeon100_blue.gd): "normaal", "blauw" (permanente buit) of "mimic" (gevecht). De generator
## zet "kind" in de kistdata; zonder is de kist gewoon.
var kind := Blue.KIND_NORMAL
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
	_setup_loot(d)
	kind = str(d.get("kind", Blue.KIND_NORMAL)) if floor_nr > 0 and not loot.is_empty() else Blue.KIND_NORMAL
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
	if kind == Blue.KIND_BLUE:
		sprite.modulate = Blue.BLUE_TINT      # placeholder: de gewone kist, blauw getint


## Task #4: op een verdieping > 0 (eigen "floor" of GameState.dungeon100_floor) heeft de kist schaalbuit:
## "loot" uit de data (vooraf gerold door de generator) of, zonder, deterministisch gerold uit het
## kist-id + de verdieping ("boss": true = baaskist). Verdieping 0 en "item"/"n" in de data: ongewijzigd.
func _setup_loot(d: Dictionary) -> void:
	floor_nr = int(d.get("floor", GameState.dungeon100_floor))
	loot = {}
	if floor_nr <= 0:
		return
	if d.get("loot") is Dictionary:
		loot = d["loot"]
	elif not d.has("item"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s@%d" % [chest_id, floor_nr])
		loot = Dungeon100Scaling.chest_loot(floor_nr, rng, bool(d.get("boss", false)))


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
	if kind == Blue.KIND_MIMIC:
		last_result = "mimic"
		Dialog.show_lines(MIMIC_LINES)
		await Dialog.finished
		wake_mimic()
		return
	open_chest()


## De Mimic wordt wakker: de kamer start het gevecht (DungeonRoom.start_mimic_battle). De kist blijft dicht
## tot de Mimic verslagen is (open_after_mimic()); vlucht je, dan bijt hij de volgende keer opnieuw.
func wake_mimic() -> void:
	mimic_woke.emit(self)


## Na een gewonnen Mimic-gevecht: de kist gaat open en geeft zijn buit.
func open_after_mimic() -> void:
	if is_open():
		return
	_give_loot(["De Mimic is verslagen!"])


func open_chest() -> void:
	if is_open():
		return
	_give_loot(["{naam} opent de kist..."])


func _give_loot(intro: Array) -> void:
	# eerst de vlag, dan het voorwerp: nooit dubbel
	GameState.story_flags[flag_of(chest_id)] = true
	if not loot.is_empty():
		var gold := Dungeon100Scaling.grant_loot(loot, GameState.inventory)
		GameState.gold += gold
		sprite.frame = 1
		last_result = "gekregen"
		var lines := intro.duplicate()
		if kind == Blue.KIND_BLUE:
			_secure_blue()
			last_result = "blauw"
			lines.append("Een Blauwe Kist! Een databank van de Oude Mensheid.")
			lines.append("{naam} vindt: %s! Dit blijft bewaard, ook als je het Archief uit wordt gezet." % Dungeon100Scaling.loot_text(loot))
		else:
			lines.append("{naam} vindt: %s!" % Dungeon100Scaling.loot_text(loot))
		Dialog.show_lines(lines)
		if kind == Blue.KIND_BLUE:
			await Dialog.finished
			blue_secured.emit(self)
		return
	GameState.inventory[item] = GameState.item_count(item) + count
	sprite.frame = 1
	last_result = "gekregen"
	var nm := item_name(item)
	var lines2 := intro.duplicate()
	lines2.append("{naam} vindt: %s!" % (nm if count == 1 else "%dx %s" % [count, nm]))
	Dialog.show_lines(lines2)


## Blauwe buit ook in de permanente databank (GameState.dungeon100_permanent).
func _secure_blue() -> void:
	for it in loot.get("items", []):
		var id := str(it["item"])
		GameState.dungeon100_permanent[id] = int(GameState.dungeon100_permanent.get(id, 0)) + int(it.get("n", 1))
