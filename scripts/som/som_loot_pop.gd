extends RefCounted
## Visuele loot-opvering (client-only); geen inventaris-wijziging.

const _Self := preload("res://scripts/som/som_loot_pop.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const TICK_SEC := 1.0 / 60.0
const MAX_DROPS := 4


class LootDrop extends Node2D:
	var _tick := 0
	var _index := 0
	var _item_id := ""
	var _pop_done := false
	var _icon: Sprite2D
	var _ring: Sprite2D


	func setup(item_id: String, ground: Vector2, index: int) -> void:
		_item_id = item_id
		_index = index
		position = ground + Vector2(_side_px(index), 0.0)
		z_index = 26
		var tex: Texture2D = _Self._item_icon(item_id)
		if tex == null:
			queue_free()
			return
		_icon = Sprite2D.new()
		_icon.texture = tex
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.centered = false
		_icon.offset = Vector2(-8.0, -16.0)
		add_child(_icon)


	func _process(_delta: float) -> void:
		_tick += 1
		if _icon == null:
			queue_free()
			return
		var y: float = _Self.y_at_tick(_tick)
		_icon.position.y = -y
		if _tick == 19 and not _pop_done:
			_pop_done = true
			var pop := SomFx.oneshot(self, SomData.FX_LOOT_POP, Vector2.ZERO, "SomLootRing", Color.WHITE)
			if pop is Sprite2D:
				_ring = pop as Sprite2D
		if _tick >= 64:
			var phase := _tick - 64
			var blink_on := (phase / 2) % 2 == 0
			modulate.a = 1.0 if blink_on else 0.0
		if _tick >= 75:
			queue_free()


	func _side_px(index: int) -> float:
		return 3.0 if index % 2 == 0 else -3.0


static func y_at_tick(tick: int) -> float:
	if tick <= 0:
		return 0.0
	if tick <= 10:
		var t := float(tick) / 10.0
		return lerpf(0.0, 12.0, 1.0 - (1.0 - t) * (1.0 - t))
	if tick <= 19:
		var t := float(tick - 10) / 9.0
		return lerpf(12.0, 0.0, t * t)
	if tick <= 24:
		var t := float(tick - 19) / 5.0
		return lerpf(0.0, 4.0, 1.0 - (1.0 - t) * (1.0 - t))
	if tick <= 29:
		var t := float(tick - 24) / 5.0
		return lerpf(4.0, 0.0, t * t)
	match tick:
		30, 31:
			return 1.0
		_:
			return 0.0


static func spawn_group(parent: Node, ground: Vector2, got: Array) -> void:
	if got.is_empty():
		return
	var n := mini(got.size(), MAX_DROPS)
	for i in n:
		var id := str(got[i])
		if _Self._item_icon(id) == null:
			continue
		var drop := LootDrop.new()
		drop.name = "SomLootDrop_%d" % i
		parent.add_child(drop)
		drop.setup(id, ground, i)


static func _item_icon(item_id: String) -> Texture2D:
	var sheet: Texture2D = SomFx.tex(SomData.UI_RING_ICONS)
	if sheet == null:
		sheet = SomFx.tex(SomData.UI_RING_ICONS_8)
	if sheet == null:
		sheet = SomFx.tex(SomData.UI_RING_ICONS_FALLBACK)
	var idx := int(SomData.RING_ICON.get(item_id, -1))
	if sheet != null and idx >= 0 and (idx + 1) * 16 <= sheet.get_width():
		var a := AtlasTexture.new()
		a.atlas = sheet
		a.region = Rect2(idx * 16, 0, 16, 16)
		return a
	var path := "res://assets/ui/icons/%s.png" % item_id
	if ResourceLoader.exists(path):
		return SomFx.tex(path)
	return null