class_name Hd2dUnmodulated
extends RefCounted
## Combat/HUD-tekening buiten HD-2D tint en PointLight2D (licht_mask 0 + modulate-compensatie).

const GROUP := "hd2d_unmodulated"
## Alleen deze bit krijgt kaartlicht; combat/HUD gebruikt 0.
const WORLD_LIGHT_MASK := 1


static func mark(node: Node) -> void:
	if node == null:
		return
	if not node.is_in_group(GROUP):
		node.add_to_group(GROUP)
	if node is CanvasItem:
		(node as CanvasItem).light_mask = 0


static func mark_descendants(root: Node) -> void:
	if root is CanvasItem:
		mark(root as CanvasItem)
	for c in root.get_children():
		mark_descendants(c)


static func inverse_modulate(tint: Color) -> Color:
	return Color(
			1.0 / maxf(tint.r, 0.001),
			1.0 / maxf(tint.g, 0.001),
			1.0 / maxf(tint.b, 0.001),
			1.0)


static func _tree() -> SceneTree:
	var ml := Engine.get_main_loop()
	return ml as SceneTree if ml is SceneTree else null


static func apply_compensation(tint: Color) -> void:
	var st := _tree()
	if st == null:
		return
	var comp := inverse_modulate(tint)
	for n in st.get_nodes_in_group(GROUP):
		if n is CanvasItem and is_instance_valid(n):
			(n as CanvasItem).modulate = comp


static func reset_compensation() -> void:
	var st := _tree()
	if st == null:
		return
	for n in st.get_nodes_in_group(GROUP):
		if n is CanvasItem and is_instance_valid(n):
			(n as CanvasItem).modulate = Color.WHITE


static func canvas_tint_on_map(map: Node) -> Color:
	if map == null:
		return Color.WHITE
	var out := Color.WHITE
	for n in map.find_children("*", "CanvasModulate", true, false):
		out *= (n as CanvasModulate).color
	return out
