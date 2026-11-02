class_name WorldWarperOpeningStoryMode
extends RefCounted
## Story-only Hal na de drift: alleen Hal + Hanger-nis; rest toont "Not yet."

const Flow := preload("res://world_warper/opening/flow.gd")

const MSG := "Not yet."
const HAL_OPEN := ["NaarHanger"]
const HANGER_OPEN := ["NaarHal"]


static func actief() -> bool:
	return GameState.story_flags.has(Flow.FLAG_OPENING_HAL)


static func blocks_map_exit(map_path: String, exit_name: String) -> bool:
	if not actief():
		return false
	if map_path.ends_with("world_warper/maps/hal.tscn"):
		return not HAL_OPEN.has(exit_name)
	if map_path.ends_with("world_warper/maps/hanger_nis.tscn"):
		return not HANGER_OPEN.has(exit_name)
	return true


static func prep_hal(map: Node) -> void:
	if not actief() or map == null:
		return
	for naam in ["Kael", "Orion"]:
		var npc := map.get_node_or_null("Objects/" + naam)
		if npc is CanvasItem:
			(npc as CanvasItem).visible = false


static func toon_geblokkeerd(map: Node) -> void:
	if Dialog.is_open:
		return
	Dialog.show_lines([MSG], "")
	_flits_rood(map)


static func _flits_rood(map: Node) -> void:
	if map == null or not map.is_inside_tree():
		return
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.1, 0.15, 0.45)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 200
	map.add_child(flash)
	var t := map.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.35)
	t.finished.connect(flash.queue_free)
