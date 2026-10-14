extends Node2D
## PUZZLE ROOM in de Diepe Grot: bouwt de puzzel (scripts/data/grot_puzzels.gd) in een gewone
## Dungeon100Room, met de BESTAANDE puzzelstukken (PushBlock, PressurePlate, Gate, Lever, GrowPlate,
## ResetStone) en PuzzleLogic. Deze node is de 'room' voor die stukken (request_push / request_lever /
## request_grow / request_reset), zoals PuzzleRoom dat is. Duwen gaat zoals in de Archieven; er is
## geen nieuwe speler-mechaniek.
## Vergrendelde poort/groei-plaat: GameState.puzzle_latched onder de kamer-id (bevat de run-seed),
## dus na een save/laden blijft de nis open. De blauwe kist zelf is een gewone kist van de kamer.

const Puzzels := preload("res://scripts/data/grot_puzzels.gd")
const PushBlock := preload("res://scripts/puzzle/push_block.gd")
const Lever := preload("res://scripts/puzzle/lever.gd")
const PressurePlate := preload("res://scripts/puzzle/pressure_plate.gd")
const Gate := preload("res://scripts/puzzle/gate.gd")
const GrowPlate := preload("res://scripts/puzzle/grow_plate.gd")
const ResetStone := preload("res://scripts/puzzle/reset_stone.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const KAST_VAST := "res://assets/puzzle/kast_vast.png"
const SPLEET_KLEUR := Color("0b0a10")
const HEAVY_HINT := ["This cabinet is full of runes and lead-heavy.", "It doesn't move a millimeter... That takes more strength."]
const RESET_VRAAG := "Restore the puzzle?"
const RESET_BEZET := ["Step aside first."]

var map: Node2D            # de Dungeon100Room
var player: CharacterBody2D
var puzzel_id := ""
var origin := Vector2i.ZERO
var latch_key := ""
var logic: PuzzleLogic
var nodes := {}
var floor_layer: Node2D
var _pushing := ""
var _resetting := false
## Voor de tests: "", "reset", "declined" of "bezet".
var last_reset_result := ""


static func create(p_map: Node2D, info: Dictionary, key: String) -> Node2D:
	var n: Node2D = (load("res://scripts/dungeon/dungeon100_puzzel.gd") as GDScript).new()
	n.name = "Puzzel"
	n.map = p_map
	n.puzzel_id = str(info["id"])
	n.origin = Vector2i(int(info["origin"][0]), int(info["origin"][1]))
	n.latch_key = key
	return n


func _ready() -> void:
	player = map.player
	var layout: Array = map.room["layout"]
	var size := Vector2i(str(layout[0]).length(), layout.size())
	var lroom := Puzzels.logica_kamer(puzzel_id, origin, size)
	logic = PuzzleLogic.from_room(lroom, latch_key, _store().get(latch_key, []))
	logic.abilities = GameState.world_abilities()
	floor_layer = Node2D.new()
	floor_layer.name = "PuzzelVloer"
	add_child(floor_layer)
	var objects: Node2D = map.get_node("Objects")
	# vaste kasten (massief) en de spleet (donker; botsing komt van de groei-plaat)
	for t in logic.statics:
		var k := StaticBody2D.new()
		k.name = "VasteKast_%d_%d" % [t.x, t.y]
		k.position = Vector2(t) * 16 + Vector2(8, 8)
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 16)
		cs.shape = rect
		k.add_child(cs)
		var sp := Sprite2D.new()
		sp.texture = load(DungeonRooms.themed(KAST_VAST))
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.offset = Vector2(0, -8)
		k.add_child(sp)
		objects.add_child(k)
		nodes["vast_%d_%d" % [t.x, t.y]] = k
	for t in logic.gap_owner:
		var r := ColorRect.new()
		r.name = "Spleet_%d_%d" % [t.x, t.y]
		r.color = SPLEET_KLEUR
		r.position = Vector2(t) * 16
		r.size = Vector2(16, 16)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floor_layer.add_child(r)
	for id in logic.plates:
		var p := PressurePlate.new()
		p.setup(id, logic.plates[id]["tile"], logic.plates[id]["heavy"], false)
		floor_layer.add_child(p)
		nodes[id] = p
	for id in logic.gates:
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
		var gi: Dictionary = logic.grows[id]
		var gp := GrowPlate.new()
		gp.setup(self, id, gi["tile"], logic.grow_stage(id), logic.grow_open(id))
		objects.add_child(gp)
		gp.attach_pad(floor_layer, gi["bridge"])
		nodes[id] = gp
	for id in logic.resets:
		var rs := ResetStone.new()
		rs.setup(self, id, logic.resets[id])
		objects.add_child(rs)
		nodes[id] = rs
	_sync_all()
	logic.changed.connect(_on_logic_changed)
	if is_instance_valid(player):
		logic.set_player_tile(player.get_tile())


## Korte hint van ECHO bij binnenkomst (één Engelse zin per puzzel).
func hint() -> String:
	return str(Puzzels.puzzel(puzzel_id).get("hint", ""))


func show_hint() -> void:
	if hint() != "" and not Dialog.is_open:
		Dialog.show_lines([hint()], Puzzels.HINT_SPREKER)


func _store() -> Dictionary:
	return GameState.puzzle_latched if "puzzle_latched" in GameState else {}


func _process(_delta: float) -> void:
	if logic == null or not is_instance_valid(player):
		return
	var target: Vector2i = player.get_tile()
	if player.is_moving:
		var target_px: Vector2 = player.get("_target")
		target = Vector2i((target_px / 16.0).floor())
	logic.set_player_tile(player.get_tile(), target)


func _can_act(p: Node2D) -> bool:
	return p == player and not _resetting and not Dialog.is_open and not GameState.changing_map


func request_push(block: Node, p: Node2D) -> bool:
	if p != player or player.is_moving or player.input_locked or Dialog.is_open \
			or GameState.changing_map or _resetting:
		return false
	var dir: Vector2i = player.facing
	var id: String = block.block_id
	if logic.blocks.get(id) != player.get_tile() + dir:
		return false
	logic.abilities = GameState.world_abilities()
	if logic.push_block_reason(id, dir) == "te zwaar":
		Dialog.show_lines(HEAVY_HINT)
		return false
	_pushing = id
	var ok := logic.try_push(id, dir)
	_pushing = ""
	if ok:
		block.slide_to(logic.blocks[id], dir, 16.0 / maxf(player.walk_speed, 1.0))
	return ok


func request_lever(lever: Node, p: Node2D) -> void:
	if p != player or _resetting or GameState.changing_map:
		return
	logic.toggle_lever(lever.lever_id)


func request_grow(plate: Node, p: Node2D) -> void:
	if not _can_act(p):
		return
	match logic.try_grow(plate.grow_id):
		"wacht":
			Dialog.show_lines(Puzzels.GROEI_WACHT)
		"groei":
			Dialog.show_lines(Puzzels.GROEI_STAP)
		"open":
			Dialog.show_lines(Puzzels.GROEI_OPEN)
		"klaar":
			Dialog.show_lines(Puzzels.GROEI_KLAAR)


func request_reset(p: Node2D) -> void:
	if p != player or _resetting or Dialog.is_open or GameState.changing_map:
		return
	_resetting = true
	var choice: int = await Dialog.ask(RESET_VRAAG, ["Yes", "No"])
	if choice == 0:
		if logic.block_start.values().has(player.get_tile()):
			last_reset_result = "bezet"
			Dialog.show_lines(RESET_BEZET)
		else:
			reset_puzzel()
			last_reset_result = "reset"
	else:
		last_reset_result = "declined"
	_resetting = false


func reset_puzzel() -> void:
	logic.reset()
	_sync_all()


## Is de nis open (poort of groei-pad)?
func opgelost() -> bool:
	for id in logic.gates:
		if logic.gate_open(id):
			return true
	for id in logic.grows:
		if logic.grow_open(id):
			return true
	return false


func _on_logic_changed(ids: Array) -> void:
	for id in ids:
		_sync(id, true)
	var latched := logic.latched_ids()
	if not latched.is_empty() and "puzzle_latched" in GameState:
		GameState.puzzle_latched[latch_key] = latched


func _sync_all() -> void:
	for id in logic.types:
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
		"gate":
			var open := logic.gate_open(id)
			if n.is_open != open:
				n.set_open(open, animate)
