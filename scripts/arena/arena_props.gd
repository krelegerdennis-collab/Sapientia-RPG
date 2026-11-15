extends RefCounted
## Props uit data/hd2d/placements_arena.json. Offsets en voeten volgen docs/arena/ART_README.md.
## De koopman staat als npc, niet als losse sprite.

const PATH := "res://data/hd2d/placements_arena.json"
const TorchScript := preload("res://scripts/arena/arena_torch.gd")

const FRAME := {
	"arena_gate": Vector2i(48, 48),
	"arena_torch": Vector2i(16, 32),
	"arena_banner": Vector2i(16, 32),
	"arena_counter": Vector2i(48, 32),
	"arena_weapon_rack": Vector2i(32, 32),
	"arena_notice_board": Vector2i(32, 32),
}

static var _maps: Dictionary = {}


static func place(map: Node2D, kind: String) -> void:
	var objects := map.get_node_or_null("Objects") as Node2D
	if objects == null:
		return
	var key := "arena_hal" if kind == "hall" else "arena_lobby"
	var rows: Array = _list(key)
	var n := 0
	for row in rows:
		if not (row is Dictionary):
			continue
		var spec: Dictionary = row
		var prop := str(spec.get("prop", ""))
		if prop == "" or prop.begins_with("arena_koopman"):
			continue
		if not FRAME.has(prop):
			continue
		var tex := load("res://" + str(spec.get("albedo", ""))) as Texture2D
		if tex == null:
			continue
		n += 1
		var frame_px: Vector2i = FRAME[prop]
		var body := StaticBody2D.new()
		body.name = "%s_%d" % [prop, n]
		body.position = Vector2(float(spec.get("x", 0)), float(spec.get("y", 0)))
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		spr.centered = false
		spr.texture = tex
		spr.offset = Vector2(-frame_px.x * 0.5, -float(frame_px.y))
		spr.hframes = maxi(1, int(spec.get("hframes", 1)))
		spr.frame = int(spec.get("frame", 0))
		spr.flip_h = bool(spec.get("flip", false))
		if prop == "arena_torch":
			spr.set_script(TorchScript)
		body.add_child(spr)
		_feet(body, prop, int(spec.get("frame", 0)))
		objects.add_child(body)


static func _list(key: String) -> Array:
	if _maps.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		var root: Dictionary = parsed if parsed is Dictionary else {}
		var maps: Variant = root.get("maps", {})
		_maps = maps if maps is Dictionary else {}
	var rows: Variant = _maps.get(key, [])
	return rows if rows is Array else []


static func _feet(body: StaticBody2D, prop: String, frame: int) -> void:
	match prop:
		"arena_gate":
			_rect(body, Vector2(-20, -4), Vector2(8, 8))
			_rect(body, Vector2(20, -4), Vector2(8, 8))
			# f0 dicht: het midden (32 px) is muur. f1 laat die 32 px open.
			if frame == 0:
				_rect(body, Vector2(0, -4), Vector2(32, 8))
		"arena_torch":
			_rect(body, Vector2(0, -2), Vector2(6, 4))
		"arena_counter":
			_rect(body, Vector2(0, -6), Vector2(44, 12))
		"arena_weapon_rack":
			_rect(body, Vector2(0, -3), Vector2(28, 6))
		"arena_notice_board":
			# Twee palen, sprite-lokaal x3 en x27, 4x4. Sprite-oorsprong ligt 16 px links van de node.
			_rect(body, Vector2(-11, -2), Vector2(4, 4))
			_rect(body, Vector2(13, -2), Vector2(4, 4))


static func _rect(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	col.position = center
	body.add_child(col)
