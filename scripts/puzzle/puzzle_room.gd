class_name PuzzleRoom
extends "res://scripts/map.gd"
## Puzzelkamer (De Vergeten Archieven), helemaal gebouwd uit DATA: kies room_id (een sleutel
## uit scripts/data/puzzle_rooms.gd). In _ready, VÓÓR map.gd zijn werk doet, bouwt deze
## node: de vloer/muren (Ground, tileset binnen.tres), het spawnpunt 'ingang', de uitgangen,
## de puzzelobjecten (kasten/hendels/stenen in Objects met y-sort, platen/poorten in de laag
## PuzzleFloor eronder) en een PuzzleLogic (het rekenmodel). Elke frame krijgt de logica
## de tile van de speler (en waar hij heen loopt), zodat platen en poorten kloppen.
##
## Vergrendelde poorten (latch) worden per spel onthouden in GameState.puzzle_latched
## (gaat mee in de save). Bestaat dat veld niet (oudere game_state.gd), dan alleen voor deze
## sessie in de static _session_latched.
## Kasten/hendels gaan terug naar het begin als je de kamer verlaat (zoals in Lufia 2),
## BEHALVE na een gevecht: dan komt de puzzel terug zoals hij was (_battle_snapshots).
##
## v0.15 (ARCHIEF1): geheime deur ("secret"), los boek ("book"), schatkist ("chest") en
## verborgen vloer (','). Deur en boek worden onthouden zoals vergrendelde poorten
## (puzzle_latched); een kist via GameState.story_flags[flag] (eenmalig, gaat mee in de save,
## na het openen ook een autosave). Zie HANDOFF_ARCHIEF1.md.

const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const PushBlock := preload("res://scripts/puzzle/push_block.gd")
const Lever := preload("res://scripts/puzzle/lever.gd")
const PressurePlate := preload("res://scripts/puzzle/pressure_plate.gd")
const Gate := preload("res://scripts/puzzle/gate.gd")
const ResetStone := preload("res://scripts/puzzle/reset_stone.gd")
const SecretDoor := preload("res://scripts/puzzle/secret_door.gd")
const BookSwitch := preload("res://scripts/puzzle/book_switch.gd")
const TreasureChest := preload("res://scripts/puzzle/treasure_chest.gd")
const GrowPlate := preload("res://scripts/puzzle/grow_plate.gd")
const GameData := preload("res://scripts/data/game_data.gd")
## Standaardteksten (Nederlands); per object te vervangen in de data.
const SECRET_HINT := ["There's a little draft behind this cabinet...",
		"Something in this room is surely sticking out."]
const BOOK_LINES := ["One book sticks out. You push it back...", "*click*"]
const BOOK_PRESSED_LINES := ["The book is stuck fast."]
const SECRET_OPEN_LINES := ["A cabinet slides aside!"]
const CHEST_EMPTY_LINES := ["The chest is empty."]
## v0.15 zware kast zonder de wereldvaardigheid 'Zware blokken duwen' (per kast te vervangen: "hint").
const HEAVY_HINT := ["This cabinet is full of runes and lead-heavy.", "It doesn't move a millimeter... That takes more strength."]
const GROW_WAIT := ["De plaat doet niets.", "Eerst de hendel."]
const GROW_STEP := ["De plaat groeit."]
const GROW_OPEN := ["De ranken sluiten zich tot een pad."]
const GROW_DONE := ["Het pad ligt er al."]
## v0.14 dungeon-stijl (Eerste Archief): tegels + legenda van de dungeonkamers.
const DungeonRoomScript := preload("res://scripts/dungeon/dungeon_room.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const KAST_VAST := "res://assets/puzzle/kast_vast.png"
## v0.14 HAAKJES voor de componenten van RPG CODE: hook-soort ("hook" in puzzle_rooms.gd) ->
## script met setup(room, id, tile, data). Nu PLACEHOLDERS (scripts/puzzle/hooks/). Zie
## docs/HANDOFF_ARCHIEF1.md: zijn echte componenten komen via "type" in de data (secret/plate/chest).
const HOOK_SCRIPTS := {
	"geheime_deur": preload("res://scripts/puzzle/hooks/ph_geheime_deur.gd"),
	"runeplaat": preload("res://scripts/puzzle/hooks/ph_runeplaat.gd"),
	"schatkist": preload("res://scripts/puzzle/hooks/ph_schatkist.gd"),
}

## Geluidshaakje (nog geen audio): "duw", "duw_mis", "hendel", "poort_open", "poort_dicht",
## "herstel"; v0.15 ook "klik", "geheime_deur", "kist". Verbind hier later een AudioStreamPlayer aan.
signal puzzle_sound(sound: String)

## Doorzicht: staat de speler direct BOVEN (achter) een duwbare kast, dan valt hij er bijna
## helemaal achter weg (de kast is 2 tiles hoog). Dan wordt de kast zo doorzichtig.
## 1.0 = uit.
const SEE_THROUGH_ALPHA := 0.6

## Sleutel in PuzzleRooms.ROOMS.
@export var room_id := "archief_test"

static var _session_latched := {}     # room_id -> Array (als GameState geen puzzle_latched heeft)
static var _battle_snapshots := {}    # room_id -> get_state() van vlak voor een gevecht

var room: Dictionary
var logic: PuzzleLogic
var floor_layer: Node2D
var nodes := {}          # id -> node (kasten, platen, hendels, poorten, stenen)
var _pushing := ""       # id van de kast die nu geduwd wordt (sync slaat hem over)
var _resetting := false
## Voor de autotest: "", "reset" of "declined".
var last_reset_result := ""
## v0.15 voor de tests: "", "gekregen" of "leeg".
var last_chest_result := ""
## v0.15 voor de tests: id van de zware kast die als laatste de hint gaf.
var last_heavy_hint := ""
var hidden_layer: TileMapLayer      # dekt de verborgen vloer (',') af tot een geheime deur opengaat (null = geen ',')
var _obj_data := {}                 # id -> data uit puzzle_rooms.gd
var _pending_lines: Array = []      # teksten van geheime deuren die net opengingen
var _busy := false                  # boek/kist-bericht loopt
## v0.14: afdekking van het verborgen deel ("dek", de schatkamer); null = geen.
var hidden_cover: Node2D


func _ready() -> void:
	_build()
	# Direct gestart (geen spawn/terugkeerpunt): toch bij de ingang beginnen.
	var returning: bool = GameState.has_return_point and GameState.return_map == scene_file_path
	if GameState.pending_spawn == "" and not returning:
		player.place_at(logic.spawn_tile, logic.spawn_facing)
	# Terug uit een gevecht: puzzel zoals hij was.
	if returning and _battle_snapshots.has(room_id):
		logic.set_state(_battle_snapshots[room_id])
		_sync_all()
	_battle_snapshots.erase(room_id)
	super._ready()
	# Veiligheid (bv. een oude save midden in een kast): terug naar de ingang.
	if logic.is_solid(player.get_tile()):
		player.place_at(logic.spawn_tile, logic.spawn_facing)
	logic.set_player_tile(player.get_tile())
	logic.changed.connect(_on_logic_changed)


func _exit_tree() -> void:
	if logic and GameState.in_battle:
		_battle_snapshots[room_id] = logic.get_state()


# ---------------------------------------------------------------- bouwen
func _build() -> void:
	room = PuzzleRooms.ROOMS.get(room_id, {})
	if room.is_empty():
		push_error("Puzzle Room '%s' bestaat niet in puzzle_rooms.gd" % room_id)
		return
	for e in PuzzleLogic.validate(room):
		push_error("Puzzle Room '%s': %s" % [room_id, e])
	if map_name == "":
		map_name = str(room.get("name", room_id))
	logic = PuzzleLogic.from_room(room, room_id, _latched_store().get(room_id, []))
	logic.abilities = GameState.world_abilities()   # v0.15: zware kasten (kernfragment)
	# v0.15 thema (dungeon-stijl: tegels + puzzelobjecten in de stijl van het archief; anders geen)
	DungeonRooms.current_theme = DungeonRooms.theme_of(room) if is_dungeon_style() else ""

	# 1) Vloer en muren (v0.14: of dungeontegels uit "look", botsing uit de layout)
	ground.clear()
	if is_dungeon_style():
		_build_dungeon_ground()
	else:
		var tiles := PuzzleLogic.autotile(room["layout"])
		for t in tiles:
			ground.set_cell(t, 0, Vector2i(tiles[t], 0))

	# 2) Laag voor platen en poorten: onder Objects, dus onder speler en kasten
	floor_layer = Node2D.new()
	floor_layer.name = "PuzzleFloor"
	add_child(floor_layer)
	move_child(floor_layer, $Objects.get_index())
	var objects: Node2D = $Objects
	for c in room.get("objects", {}):
		_obj_data[str(room["objects"][c].get("id", ""))] = room["objects"][c]
	# v0.15 verborgen vloer ',' (binnen-stijl): afgedekt met muurtop-tegels (eerst, dus onder deuren
	# en platen). In dungeon-stijl (Eerste Archief) gebruik je "dek" van Forge (reveal_hidden_area).
	if not logic.hidden.is_empty():
		hidden_layer = TileMapLayer.new()
		hidden_layer.name = "Verborgen"
		hidden_layer.tile_set = ground.tile_set
		hidden_layer.collision_enabled = false     # alleen beeld; massief is de deur zelf
		for t in logic.hidden:
			hidden_layer.set_cell(t, 0, Vector2i(PuzzleLogic.T_WALL_TOP, 0))
		floor_layer.add_child(hidden_layer)
		hidden_layer.visible = not logic.any_secret_open()
	for id in logic.plates:
		var p := PressurePlate.new()
		p.setup(id, logic.plates[id]["tile"], logic.plates[id]["heavy"], logic.plates[id].get("hidden", false))
		floor_layer.add_child(p)
		nodes[id] = p
	for id in logic.gates:
		if logic.gates[id].get("secret", false):
			var sd := SecretDoor.new()
			sd.setup(self, id, logic.gates[id]["tile"], logic.gate_open(id))
			floor_layer.add_child(sd)
			nodes[id] = sd
			continue
		var g := Gate.new()
		g.setup(id, logic.gates[id]["tile"], logic.gate_open(id))
		floor_layer.add_child(g)
		nodes[id] = g
	for id in logic.blocks:
		var b := PushBlock.new()
		b.setup(self, id, logic.blocks[id], logic.heavy_blocks.has(id))
		objects.add_child(b)
		nodes[id] = b
	for id in logic.levers:
		var l := Lever.new()
		l.setup(self, id, logic.levers[id]["tile"], logic.lever_on(id))
		objects.add_child(l)
		nodes[id] = l
	for id in logic.grows:
		var ginfo: Dictionary = logic.grows[id]
		var gp := GrowPlate.new()
		gp.setup(self, id, ginfo["tile"], logic.grow_stage(id), logic.grow_open(id))
		objects.add_child(gp)
		gp.attach_pad(floor_layer, ginfo["bridge"])
		nodes[id] = gp
	for id in logic.resets:
		var r := ResetStone.new()
		r.setup(self, id, logic.resets[id])
		objects.add_child(r)
		nodes[id] = r
	for id in logic.books:
		var bk := BookSwitch.new()
		bk.setup(self, id, logic.books[id]["tile"], logic.book_pressed(id))
		objects.add_child(bk)
		nodes[id] = bk
	for id in logic.chests:
		var c: Dictionary = logic.chests[id]
		var ch := TreasureChest.new()
		ch.setup(self, id, c["tile"], chest_taken(id), str(item_data(c["item"]).get("icon", "")))
		objects.add_child(ch)
		nodes[id] = ch
	# v0.14 haakjes (placeholders voor RPG CODE): vlakke dingen in PuzzleFloor, de rest in Objects
	var objdata := {}
	for c in room.get("objects", {}):
		objdata[str(room["objects"][c].get("id", ""))] = room["objects"][c]
	for id in logic.hooks:
		var kind: String = logic.hooks[id]["hook"]
		if not HOOK_SCRIPTS.has(kind):
			push_error("Puzzle Room '%s': onbekend haakje '%s'" % [room_id, kind])
			continue
		var hk: Node2D = HOOK_SCRIPTS[kind].new()
		hk.setup(self, id, logic.hooks[id]["tile"], objdata.get(id, {}))
		if logic.hooks[id]["solid"]:
			objects.add_child(hk)
		else:
			floor_layer.add_child(hk)
		nodes[id] = hk
	_sync_all()
	# v0.14 afdekking over het verborgen deel (de schatkamer) tot reveal_hidden_area()
	if room.has("dek"):
		_build_cover(room["dek"])
		if logic.any_secret_open():
			reveal_hidden_area(false)   # v0.15: geheime deur staat al open (save/terugkomen)
	# Kas (en andere thema's met "tint"): dezelfde kleurtint als een dungeonkamer.
	# archief_grijs heeft geen tint, dus het Eerste Archief blijft zoals het was.
	if is_dungeon_style():
		var td: Dictionary = DungeonRooms.theme_data(DungeonRooms.current_theme)
		if td.has("tint"):
			var cm := CanvasModulate.new()
			cm.name = "ThemaTint"
			cm.color = td["tint"]
			add_child(cm)

	# 3) Spawnpunt 'ingang' (naast E, kijkt de kamer in) + v0.14 extra spawns uit de data
	var spawn := MapSpawn.new()
	spawn.name = "ingang"
	spawn.position = Vector2(logic.spawn_tile) * 16 + Vector2(8, 8)
	spawn.facing = logic.spawn_facing
	$Spawns.add_child(spawn)
	var extra: Dictionary = room.get("spawns", {})
	for sp_name in extra:
		var v: Array = extra[sp_name]
		var sp := MapSpawn.new()
		sp.name = str(sp_name)
		sp.position = Vector2(int(v[0]), int(v[1])) * 16 + Vector2(8, 8)
		sp.facing = Story.dir_of(str(v[2]) if v.size() > 2 else "down")
		$Spawns.add_child(sp)

	# 4) Uitgangen (E en X) + onzichtbare blokkades net buiten de deuren
	for t in logic.exits:
		var kind: String = logic.exits[t]
		var data: Dictionary = room.get("entrance", {}) if kind == "E" else room.get("exit", {})
		var ex := MapExit.new()
		ex.name = "Ingang" if kind == "E" else "Uitgang"
		ex.position = Vector2(t) * 16
		ex.target_map = str(data.get("map", ""))
		ex.target_spawn = str(data.get("spawn", ""))
		var lines: Array[String] = []
		for s in data.get("lines", []):
			lines.append(str(s))
		ex.lines = lines
		$Exits.add_child(ex)
		var outside: Vector2i = t - logic.inward_dir(t)
		var wall := StaticBody2D.new()
		wall.name = "Rand_%d_%d" % [outside.x, outside.y]
		wall.position = Vector2(outside) * 16 + Vector2(8, 8)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 14)
		cs.shape = rect
		wall.add_child(cs)
		add_child(wall)


## v0.14: dungeontegels i.p.v. binnen.png?
func is_dungeon_style() -> bool:
	return str(room.get("style", "")) == "dungeon"


## v0.14 Dungeon-stijl: beeld uit "look" (tegels van de dungeonkamers, ZONDER botsing), botsing
## uit de layout (muren en vaste kasten; één StaticBody2D 'Muren' met een vakje per muur-tile
## naast een open tile). Vaste kasten 'B' = kast_vast.png (16x32) in Objects.
func _build_dungeon_ground() -> void:
	ground.tile_set = DungeonRoomScript.tileset(false)
	var look: Array = room.get("look", [])
	var legend := DungeonRooms.legend_of(room)
	for y in look.size():
		var row := str(look[y])
		for x in row.length():
			var ch := row[x]
			if ch == " ":
				continue
			if not legend.has(ch):
				push_error("Puzzle Room '%s': onbekend look-teken '%s' op (%d,%d)" % [room_id, ch, x, y])
				continue
			var n: int = legend[ch]
			if ch == ".":
				n = DungeonRoomScript.floor_variant(x, y)
			DungeonRoomScript.set_tile(ground, Vector2i(x, y), n)
	var body := StaticBody2D.new()
	body.name = "Muren"
	add_child(body)
	for y in logic.size.y:
		for x in logic.size.x:
			var t := Vector2i(x, y)
			if not (logic.walls.has(t) or logic.statics.has(t)):
				continue
			var near_open := false
			for d in PuzzleLogic.DIRS:
				var n: Vector2i = t + d
				if logic.inside(n) and not logic.walls.has(n) and not logic.statics.has(n):
					near_open = true
			if not near_open:
				continue
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(16, 16)
			cs.shape = rect
			cs.position = Vector2(t) * 16 + Vector2(8, 8)
			body.add_child(cs)
	for t in logic.statics:
		var k := Sprite2D.new()
		k.name = "VasteKast_%d_%d" % [t.x, t.y]
		k.texture = load(DungeonRooms.themed(KAST_VAST))
		k.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		k.offset = Vector2(0, -8)
		k.position = Vector2(t) * 16 + Vector2(8, 8)
		$Objects.add_child(k)


## v0.14 Afdekking (leegte + muurtegels) over het verborgen deel van de kamer.
func _build_cover(d: Dictionary) -> void:
	hidden_cover = Node2D.new()
	hidden_cover.name = "PH_SchatkamerDek"
	hidden_cover.z_index = 5
	add_child(hidden_cover)
	var r: Array = d.get("rect", [0, 0, 0, 0])
	var void_rect := ColorRect.new()
	void_rect.name = "Leegte"
	void_rect.color = Color(0.02, 0.02, 0.025, 1)
	void_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_rect.position = Vector2(int(r[0]), int(r[1])) * 16
	void_rect.size = Vector2(int(r[2]), int(r[3])) * 16
	hidden_cover.add_child(void_rect)
	var layer := TileMapLayer.new()
	layer.name = "Muur"
	layer.tile_set = DungeonRoomScript.tileset(false)
	for e in d.get("tiles", []):
		DungeonRoomScript.set_tile(layer, Vector2i(int(e[0]), int(e[1])), int(e[2]))
	hidden_cover.add_child(layer)


## v0.14 HAAKJE voor RPG CODE: de geheime deur roept dit aan als hij opengaat (de schatkamer
## erachter wordt zichtbaar). animate = in 0,4 s vervagen.
func reveal_hidden_area(animate := true) -> void:
	if hidden_cover == null or not hidden_cover.visible:
		return
	if not animate:
		hidden_cover.visible = false
		return
	var tw := create_tween()
	tw.tween_property(hidden_cover, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): hidden_cover.visible = false)


func _latched_store() -> Dictionary:
	if "puzzle_latched" in GameState:
		return GameState.puzzle_latched
	return _session_latched


# ---------------------------------------------------------------- elke frame
func _process(delta: float) -> void:
	super._process(delta)
	if logic == null or not is_instance_valid(player):
		return
	# player.gd heeft geen getter voor zijn doel-tile: _target (pixels) lezen.
	var target: Vector2i = player.get_tile()
	if player.is_moving:
		var target_px: Vector2 = player.get("_target")
		target = Vector2i((target_px / 16.0).floor())
	logic.set_player_tile(player.get_tile(), target)
	var behind: Vector2i = player.get_tile() + Vector2i.DOWN
	for id in logic.blocks:
		var b: Node = nodes.get(id)
		if b:
			b.visual.modulate.a = SEE_THROUGH_ALPHA if b.tile == behind else 1.0


# ---------------------------------------------------------------- acties van de objecten
## Speler loopt tegen een kast: duwen als het mag. true = geduwd.
func request_push(block: Node, p: Node2D) -> bool:
	if p != player or player.is_moving or player.input_locked or Dialog.is_open \
			or GameState.changing_map or _resetting:
		return false
	var dir: Vector2i = player.facing
	var id: String = block.block_id
	if logic.blocks.get(id) != player.get_tile() + dir:
		return false
	# v0.15 zware kast: zonder de wereldvaardigheid (kernfragment) alleen een hint
	logic.abilities = GameState.world_abilities()
	if logic.push_block_reason(id, dir) == "te zwaar":
		puzzle_sound.emit("duw_mis")
		last_heavy_hint = id
		Dialog.show_lines(_lines(id, "hint", HEAVY_HINT))
		return false
	_pushing = id
	var ok := logic.try_push(id, dir)
	_pushing = ""
	if ok:
		block.slide_to(logic.blocks[id], dir, 16.0 / maxf(player.walk_speed, 1.0))
		puzzle_sound.emit("duw")
	else:
		puzzle_sound.emit("duw_mis")
	return ok


func request_lever(lever: Node, p: Node2D) -> void:
	if p != player or _resetting or GameState.changing_map:
		return
	logic.toggle_lever(lever.lever_id)
	puzzle_sound.emit("hendel")


func request_grow(plate: Node, p: Node2D) -> void:
	if not _can_act(p):
		return
	var res := logic.try_grow(plate.grow_id)
	var lines: Array = []
	match res:
		"wacht":
			lines = _lines(plate.grow_id, "wait_lines", GROW_WAIT)
		"groei":
			lines = _lines(plate.grow_id, "lines", GROW_STEP)
		"open":
			lines = _lines(plate.grow_id, "open_lines", GROW_OPEN)
		"klaar":
			lines = _lines(plate.grow_id, "done_lines", GROW_DONE)
		_:
			return
	Dialog.show_lines(lines)


func request_reset(p: Node2D) -> void:
	if p != player or _resetting or Dialog.is_open or GameState.changing_map:
		return
	_resetting = true
	var choice: int = await Dialog.ask("Restore the room?", ["Yes", "No"])
	if choice == 0:
		player.input_locked = true
		await Transition.fade_out()
		reset_room()
		puzzle_sound.emit("herstel")
		await Transition.fade_in()
		player.input_locked = false
		last_reset_result = "reset"
	else:
		last_reset_result = "declined"
	_resetting = false


# ---------------------------------------------------------------- v0.15 geheim + kist
## Data van een voorwerp (ITEMS of EQUIPMENT), {} als het niet bestaat.
static func item_data(item: String) -> Dictionary:
	if GameData.ITEMS.has(item):
		return GameData.ITEMS[item]
	return GameData.EQUIPMENT.get(item, {})


## Is deze kist al eens geopend (in dit spel)?
func chest_taken(id: String) -> bool:
	var c: Dictionary = logic.chests.get(id, {})
	return not c.is_empty() and GameState.story_flags.has(str(c["flag"]))


func _lines(id: String, key: String, fallback: Array) -> Array:
	var l: Array = _obj_data.get(id, {}).get(key, [])
	return l if not l.is_empty() else fallback


func _can_act(p: Node2D) -> bool:
	return p == player and not _resetting and not _busy and not Dialog.is_open and not GameState.changing_map


## A voor een dichte geheime deur: de hint.
func request_secret(door: Node, p: Node2D) -> void:
	if not _can_act(p):
		return
	Dialog.show_lines(_lines(door.door_id, "hint", SECRET_HINT))


## A voor een los boek: terugduwen (eenmalig). Opent misschien een geheime deur.
func request_book(book: Node, p: Node2D) -> void:
	if not _can_act(p):
		return
	_busy = true
	var lines: Array
	if logic.press_book(book.book_id):
		puzzle_sound.emit("klik")
		lines = _lines(book.book_id, "lines", BOOK_LINES) + _pending_lines
	else:
		lines = _lines(book.book_id, "pressed_lines", BOOK_PRESSED_LINES)
	_pending_lines = []
	_busy = false
	Dialog.show_lines(lines)


## A voor een schatkist: eenmalig het voorwerp geven. Eerst de vlag, dan het voorwerp (dus
## nooit dubbel), daarna een autosave zodat het ook na een crash/afsluiten vast staat.
func request_chest(chest: Node, p: Node2D) -> void:
	if not _can_act(p):
		return
	var c: Dictionary = logic.chests.get(chest.chest_id, {})
	if c.is_empty():
		return
	if chest_taken(chest.chest_id):
		chest.set_open(true)
		last_chest_result = "leeg"
		Dialog.show_lines(_lines(chest.chest_id, "empty_lines", CHEST_EMPTY_LINES))
		return
	_busy = true
	GameState.story_flags[str(c["flag"])] = true
	var item := str(c["item"])
	GameState.inventory[item] = GameState.item_count(item) + int(c["n"])
	chest.set_open(true)
	chest.show_icon(true)
	puzzle_sound.emit("kist")
	last_chest_result = "gekregen"
	var nm := str(item_data(item).get("name", item))
	var fallback := ["{naam} finds: %s!" % (nm if int(c["n"]) == 1 else "%dx %s" % [c["n"], nm])]
	Dialog.show_lines(_lines(chest.chest_id, "lines", fallback))
	await Dialog.finished
	chest.show_icon(false)
	_busy = false
	if is_instance_valid(player):
		GameState.autosave(player.get_tile(), player.facing, "kist")


func _flush_pending() -> void:
	if _pending_lines.is_empty() or _busy or Dialog.is_open:
		return
	var lines := _pending_lines
	_pending_lines = []
	Dialog.show_lines(lines)


## Geheime deur open: verborgen vloer (',') en/of Forge's afdekking ("dek") weg.
func _reveal_hidden(animate: bool) -> void:
	reveal_hidden_area(animate)
	if hidden_layer == null or not hidden_layer.visible:
		return
	if not animate:
		hidden_layer.visible = false
		return
	var tw := create_tween()
	tw.tween_property(hidden_layer, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): hidden_layer.visible = false)


## Alles terug naar het begin, speler naar de ingang (zonder vraag of fade).
func reset_room() -> void:
	player.place_at(logic.spawn_tile, logic.spawn_facing)
	logic.set_player_tile(logic.spawn_tile)
	logic.reset()
	_sync_all()


# ---------------------------------------------------------------- nodes bijwerken
func _on_logic_changed(ids: Array) -> void:
	for id in ids:
		_sync(id, true)
	var latched := logic.latched_ids()
	if not latched.is_empty():
		_latched_store()[room_id] = latched
	if not _pending_lines.is_empty() and not _busy:
		_flush_pending.call_deferred()


func _sync_all() -> void:
	for id in nodes:
		_sync(id, false)


func _sync(id: String, animate: bool) -> void:
	var n: Node = nodes.get(id)
	if n == null:
		return
	match logic.types.get(id, ""):
		"block":
			if id != _pushing and n.tile != logic.blocks[id]:
				n.snap_to(logic.blocks[id])
		"plate":
			n.set_pressed(logic.plate_pressed(id))
		"lever":
			n.set_on(logic.lever_on(id))
		"grow":
			n.set_stage(logic.grow_stage(id), logic.grow_open(id))
		"book":
			n.set_pressed(logic.book_pressed(id))
		"secret":
			var sopen := logic.gate_open(id)
			if n.is_open != sopen:
				n.set_open(sopen, animate)
				if sopen:
					_reveal_hidden(animate)
					if animate:
						puzzle_sound.emit("geheime_deur")
						_pending_lines.append_array(_lines(id, "open_lines", SECRET_OPEN_LINES))
			elif sopen:
				_reveal_hidden(false)
		"chest":
			n.set_open(chest_taken(id))
		"gate":
			var open := logic.gate_open(id)
			if n.is_open != open:
				n.set_open(open, animate)
				if animate:
					puzzle_sound.emit("poort_open" if open else "poort_dicht")
			elif not animate:
				n.set_open(open, false)
