extends Node2D
## Actieve Codex-bondgenoot die achter de speler aanloopt.
## Wel: kerkers (Archieven, Donker Woud, Diepe Grot) en de wereldkaart.
## Niet: dorpen en huizen (Esdoorn, herberg, Wilgendal, het huis).
## Plaatje: assets/map_monsters/<vijand>.png (16x16, 2 stapframes x 4 richtingen),
## dezelfde indeling als de map-monsters. Geen botsing: hij loopt het pad van de speler na.

const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const TILE := 16.0
const FOLLOW_DIST := 16.0
const TELEPORT := 48.0
const FRAME := 16
const SPRITE_DIR := "res://assets/map_monsters/"
const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
## Scènes die een kerker zijn maar niet in de archief/woud-graaf zitten.
const DUNGEON_NAMES: Array[String] = ["dungeon100", "kern_demo"]

var player: CharacterBody2D
var sprite: Sprite2D
var species_id := ""
var texture_path := ""
var facing := Vector2i.DOWN
var _directional := false
var _walking := false
var _walked := 0.0
var _path: Array[Vector2] = []
var _path_len := 0.0


## Mag de bondgenoot op deze scène meelopen?
static func allowed(scene_path: String) -> bool:
	var base := scene_path.get_file().get_basename()
	if base == "wereldkaart":
		return true
	if base in DUNGEON_NAMES or base.begins_with("archief_") or base.begins_with("woud_"):
		return true
	return DungeonRooms.boss_distance(scene_path) >= 0


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	if not GameState.codex_changed.is_connected(_on_codex_changed):
		GameState.codex_changed.connect(_on_codex_changed)
	_on_codex_changed()
	if player != null:
		_reset_path(player.position)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		visible = false
		return
	if species_id == "":
		visible = false
		return
	var p: Vector2 = player.position
	if _path.is_empty() or p.distance_to(_path[_path.size() - 1]) > TELEPORT:
		_reset_path(p)
	elif p.distance_to(_path[_path.size() - 1]) > 0.01:
		_path_len += p.distance_to(_path[_path.size() - 1])
		_path.append(p)
		_trim_path()
	var pos := _sample(_path_len - FOLLOW_DIST)
	var moved := pos - position
	position = pos
	if moved.length() > 0.15:
		_walked += moved.length()
		_face_toward(moved)
		_walking = true
	else:
		_walking = false
		if "facing" in player:
			facing = player.facing
	_apply_frame()
	visible = pos.distance_to(p) >= 6.0


func _on_codex_changed() -> void:
	var page := GameState.codex_active_page()
	var id := ""
	if not page.is_empty():
		id = str(page.get("species", ""))
	if id == species_id:
		return
	var was_empty := species_id == ""
	species_id = id
	_load_sprite(id)
	if (id == "" or was_empty) and player != null and is_instance_valid(player):
		_reset_path(player.position)
	if id == "":
		visible = false


func _load_sprite(id: String) -> void:
	texture_path = ""
	_directional = false
	if sprite == null:
		return
	sprite.texture = null
	sprite.scale = Vector2.ONE
	sprite.hframes = 1
	sprite.vframes = 1
	sprite.position = Vector2.ZERO
	if id == "":
		return
	var sp := CodexData.species(id)
	var enemy := str(sp.get("enemy", id))
	var path := SPRITE_DIR + enemy + ".png"
	var tex: Texture2D = null
	var fh := float(FRAME)
	var hframes := 1
	var vframes := 1
	if ResourceLoader.exists(path):
		tex = load(path)
		texture_path = path
		hframes = maxi(1, int(tex.get_width() / FRAME))
		vframes = maxi(1, int(tex.get_height() / FRAME))
		_directional = vframes >= 4
	else:
		var front := str(sp.get("front", ""))
		if front != "" and ResourceLoader.exists(front):
			tex = load(front)
			texture_path = front
			var k := 16.0 / maxf(float(tex.get_width()), float(tex.get_height()))
			sprite.scale = Vector2(k, k)
			fh = float(tex.get_height()) * k
	sprite.texture = tex
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0
	sprite.position = Vector2(0, 8.0 - fh / 2.0)


func _reset_path(p: Vector2) -> void:
	_path = [p]
	_path_len = 0.0
	position = p
	_walking = false


func _trim_path() -> void:
	while _path.size() > 2:
		var seg := _path[0].distance_to(_path[1])
		if _path_len - seg + 0.001 < FOLLOW_DIST:
			break
		_path_len -= seg
		_path.pop_front()


func _sample(dist: float) -> Vector2:
	if _path.is_empty():
		return position
	if dist <= 0.0:
		return _path[0]
	var left := dist
	for i in range(_path.size() - 1):
		var a: Vector2 = _path[i]
		var b: Vector2 = _path[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.0001:
			continue
		if left <= seg:
			return a.lerp(b, left / seg)
		left -= seg
	return _path[_path.size() - 1]


func _face_toward(delta: Vector2) -> void:
	if absf(delta.x) > absf(delta.y):
		facing = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP


func _apply_frame() -> void:
	if sprite == null or sprite.texture == null:
		return
	var col := 0
	if _walking and sprite.hframes > 1:
		col = int(_walked / 8.0) % sprite.hframes
	var row := 0
	if _directional:
		row = mini(int(DIR_ROW.get(facing, 0)), sprite.vframes - 1)
	sprite.frame = row * sprite.hframes + col
