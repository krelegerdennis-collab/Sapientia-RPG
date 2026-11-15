extends RefCounted
## Client-only glitch-dood overlay + scanline-jitter op de vijand-sprite.

const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomLootPop := preload("res://scripts/som/som_loot_pop.gd")

const SCAN_F1: Array[int] = [0, 1, 0, -1, 2, 0, -1, 1]
const SCAN_F2: Array[int] = [-2, 1, 3, -1, -3, 2, 0, -2]
const FRAME_MS := 60


class GlitchFx extends Node2D:
	var _monster: Node
	var _sprite_off0 := Vector2.ZERO
	var _big := false
	var _spec: Dictionary
	var _overlay: Sprite2D
	var _elapsed_ms := 0.0
	var _loot_spawned := false
	var _drops: Array = []
	var _ground := Vector2.ZERO


	func setup(monster: Node, big: bool, spec: Dictionary, center: Vector2, drops: Array) -> void:
		_monster = monster
		_big = big
		_spec = spec
		_drops = drops
		_ground = center
		if monster.sprite:
			_sprite_off0 = monster.sprite.offset
		var t := SomFx.tex(str(spec["sheet"]))
		if t != null:
			var anc: Array = spec["anchor"]
			_overlay = Sprite2D.new()
			_overlay.texture = t
			_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_overlay.hframes = int(spec["frames"])
			_overlay.centered = false
			_overlay.offset = Vector2(-float(anc[0]), -float(anc[1]))
			_overlay.z_index = 25
			add_child(_overlay)
		position = center
		z_index = 24


	func _process(delta: float) -> void:
		_elapsed_ms += delta * 1000.0
		var frame_idx := mini(int(_elapsed_ms / float(FRAME_MS)), int(_spec["frames"]) - 1)
		if _overlay:
			_overlay.frame = frame_idx
		_apply_scan(frame_idx)
		if not _loot_spawned and frame_idx >= 3:
			_loot_spawned = true
			SomLootPop.spawn_group(self.get_parent(), _ground, _drops)
		var total_ms := int(_spec["frames"]) * FRAME_MS
		if _elapsed_ms >= float(total_ms):
			if is_instance_valid(_monster):
				_monster.queue_free()
			queue_free()


	func _apply_scan(frame_idx: int) -> void:
		if not is_instance_valid(_monster) or _monster.sprite == null:
			return
		var spr: Sprite2D = _monster.sprite
		if frame_idx >= 2:
			spr.visible = false
			return
		spr.visible = true
		var row := mini(frame_idx, 1)
		var table: Array = SCAN_F1 if row == 0 else SCAN_F2
		var jitter := float(table[frame_idx % table.size()])
		spr.offset = _sprite_off0 + Vector2(jitter, 0.0)
		if row == 0 and _has_hurt(_monster):
			var hurt := SomFx.tex(SomData.MONSTER_SHEET_DIR + str(_monster.enemy_id) + "_hurt.png")
			if hurt != null:
				var hspec: Dictionary = SomData.MONSTER_SHEETS["hurt"]
				var cell: Array = hspec["cell"]
				spr.texture = hurt
				spr.hframes = maxi(1, hurt.get_width() / int(cell[0]))
				spr.vframes = maxi(1, hurt.get_height() / int(cell[1]))
				var dir_i := mini(SomFx.dir_index(_monster.facing), spr.vframes - 1)
				spr.frame = dir_i * spr.hframes


	func _has_hurt(m: Node) -> bool:
		return not m.placeholder and m.size == Vector2i.ONE


static func play(parent: Node, arena, m: Node, e: Dictionary, got: Array) -> void:
	if m == null or parent == null:
		if is_instance_valid(m):
			m.queue_free()
		return
	var big: bool = m.size != Vector2i.ONE
	var spec: Dictionary = SomData.FX_DEATH_GLITCH_48 if big else SomData.FX_DEATH_GLITCH
	arena._restore_monster(m, e)
	if m.sprite:
		m.sprite.modulate = Color.WHITE
	var center: Vector2 = arena.center_of(m)
	var node := GlitchFx.new()
	node.name = "SomDeathGlitch"
	parent.add_child(node)
	node.setup(m, big, spec, center, got.duplicate())


static func total_ms_for(monster: Node) -> int:
	if monster != null and monster.size != Vector2i.ONE:
		return int(SomData.FX_DEATH_GLITCH_48["frames"]) * FRAME_MS
	return int(SomData.FX_DEATH_GLITCH["frames"]) * FRAME_MS