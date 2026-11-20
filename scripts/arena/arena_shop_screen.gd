extends CanvasLayer
## Kleine token-winkel. Tikrijen op dezelfde hoogte als de gewone winkel.

signal closed

const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const UiTouch := preload("res://scripts/ui/ui_touch.gd")
const Shop := preload("res://scripts/arena/arena_shop.gd")
const Data := preload("res://scripts/data/arena_shop_data.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const ItemIcons := preload("res://scripts/data/item_icons.gd")
const ICON_ARENA := preload("res://assets/ui/arena/icon_arena.png")
const ICON_TOKEN := preload("res://assets/ui/arena/icon_arena_token.png")

var box: VBoxContainer
var status: Label


func _ready() -> void:
	layer = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := UiMenu.panel()
	panel.name = "ShopPanel"
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 368.0
	panel.offset_bottom = 200.0
	root.add_child(panel)
	box = VBoxContainer.new()
	box.name = "Offers"
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	_fill()


func _fill() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()
	box.add_child(_icon_line(ICON_ARENA, "Colosseum shop"))
	var token_row := _icon_line(ICON_TOKEN, "Arena Tokens: %d" % GameState.arena_tokens)
	token_row.name = "TokenLine"
	status = token_row.get_node("Caption") as Label
	box.add_child(token_row)
	if not ReleaseFlags.arena_enabled():
		box.add_child(UiMenu.label("The Colosseum is closed."))
		box.add_child(_button("Close", _close))
		return
	for id in Data.offer_ids():
		var row := Data.offer(id)
		var item_id := str(row.get("item_id", ""))
		var price := int(row.get("price", 0))
		var label := "%s  %d" % [Data.display_name(item_id), price]
		var b := _button(label, _buy.bind(id))
		b.name = "buy_" + id
		# Post-RC: zelfde 16px-item-icoon als de gewone winkel (item_icon_overrides.gd)
		ItemIcons.apply16(b, item_id)
		box.add_child(b)
	box.add_child(_button("Close", _close))


func _icon_line(tex: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var caption := UiMenu.label(text)
	caption.name = "Caption"
	row.add_child(caption)
	return row


func _button(text: String, cb: Callable) -> Button:
	var b := UiMenu.button(text)
	b.custom_minimum_size = Vector2(160, UiTouch.TOUCH_MIN)
	b.pressed.connect(cb)
	return b


func _buy(offer_id: String) -> void:
	var res := Shop.buy(offer_id)
	if status != null:
		status.text = str(res.get("text", "")) + "  Arena Tokens: %d" % GameState.arena_tokens


func _close() -> void:
	closed.emit()
	queue_free()
