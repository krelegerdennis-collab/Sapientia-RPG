extends RefCounted
## Item-iconen v1.5 in Items / Equipment / Shop, binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-item-icons [--shots=/pad]
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.

const ItemIcons := preload("res://scripts/data/item_icons.gd")
const ItemsScreen := preload("res://scripts/ui/items_screen.gd")
const EquipmentScreen := preload("res://scripts/ui/equipment_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")

var t: Node
var shots := ""


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--item-icon-shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--shots=") and shots == "":
			shots = arg.get_slice("=", 1)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)


func run() -> void:
	print("=== Item-iconen v1.5 (Items / Equipment / Shop) ===")
	_mapping_checks()
	_fallback_check()
	_shared_spell_check()
	GameState.new_game("Dax")
	GameState.gold = 200
	GameState.inventory["kort_zwaard"] = 1
	GameState.inventory["dolk"] = 1
	await _items_ui()
	await _equipment_ui()
	await _shop_ui()


func _mapping_checks() -> void:
	var ids: Array[String] = ItemIcons.catalog_ids()
	t.check("catalogus heeft item_ids", ids.size() > 0)
	var missing: Array[String] = []
	var bad_size: Array[String] = []
	for id in ids:
		var p16 := ItemIcons.path16(id)
		var p32 := ItemIcons.path32(id)
		if not ResourceLoader.exists(p16) or not ResourceLoader.exists(p32):
			missing.append("%s (%s / %s)" % [id, p16, p32])
			continue
		var t16 := ItemIcons.tex16(id)
		var t32 := ItemIcons.tex32(id)
		if not ItemIcons.is_px(t16, ItemIcons.SIZE16) or not ItemIcons.is_px(t32, ItemIcons.SIZE32):
			bad_size.append(id)
	t.check("elke item_id heeft bestaande 16px- en 32px-iconen (%d, ontbreekt %s)" % [ids.size(), missing],
			missing.is_empty())
	t.check("elke item_id laadt 16x16 en 32x32 (%s)" % [bad_size], bad_size.is_empty())


func _fallback_check() -> void:
	var tex: Texture2D = ItemIcons.tex16("__geen_item__")
	t.check("onbekende item_id valt terug op categorie-icoon",
			tex != null and ResourceLoader.exists(ItemIcons.path16("__geen_item__"))
			and str(ItemIcons.path16("__geen_item__")).begins_with("res://assets/ui/icons/cat_"))


func _shared_spell_check() -> void:
	var ok := true
	for paar in ItemIcons.SHARED_SPELLS:
		ok = ok and ItemIcons.has_mapping(str(paar[0])) and ItemIcons.has_mapping(str(paar[1]))
		ok = ok and ItemIcons.tex16(str(paar[0])) != null and ItemIcons.tex16(str(paar[1])) != null
	t.check("drie spreukparen hebben allebei een icoon", ok)


func _row_icon_ok(b: Button) -> bool:
	if b == null:
		return false
	return ItemIcons.is_px(b.icon, ItemIcons.SIZE16) \
			and int(b.get_meta("item_icon_size", 0)) == ItemIcons.SIZE16


func _detail_ok(r: TextureRect, id: String) -> bool:
	if r == null or not r.visible:
		return false
	return ItemIcons.is_px(r.texture, ItemIcons.SIZE32) \
			and str(r.get_meta("item_icon_id", "")) == id \
			and int(r.get_meta("item_icon_size", 0)) == ItemIcons.SIZE32


func _items_ui() -> void:
	var s: Node = ItemsScreen.new()
	s.name = "Items"
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	t.check("Items-scherm heeft rijen", s.entries.size() >= 2)
	var rows_ok := true
	for b in s.entries:
		rows_ok = rows_ok and _row_icon_ok(b)
	t.check("Items-rijen tonen een 16px-icoon", rows_ok)
	if s.entries.size() > 0:
		s.entries[0].grab_focus()
		await t.pframes(2)
	t.check("Items-detailvak toont het 32px-icoon", _detail_ok(s.detail_icon, str(s.selected_id)))
	await _shot("items")
	s.queue_free()
	await t.pframes(3)


func _equipment_ui() -> void:
	var s: Node = EquipmentScreen.new()
	s.name = "Equipment"
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	s.open_list("wapen")
	await t.pframes(4)
	t.check("Equipment-lijst heeft rijen", s.list_buttons.size() >= 1)
	var rows_ok := true
	for b in s.list_buttons:
		rows_ok = rows_ok and _row_icon_ok(b)
	t.check("Equipment-rijen tonen een 16px-icoon", rows_ok)
	var focus_id := str(s.list_ids[0]) if s.list_ids.size() > 0 else ""
	t.check("Equipment-detailvak toont het 32px-icoon", _detail_ok(s.detail_icon, focus_id))
	await _shot("equipment")
	s.queue_free()
	await t.pframes(3)


func _shop_ui() -> void:
	var s: Node = ShopScreen.new()
	s.name = "ShopScreen"
	s.shop_id = "wilgendal_wapen"
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	var item_rows: Array = []
	for c in s.content.get_children():
		if c is Button and str(c.get_meta("item_icon_id", "")) != "":
			item_rows.append(c)
	t.check("Shop-scherm heeft itemrijen", item_rows.size() >= 1)
	var rows_ok := true
	for b in item_rows:
		rows_ok = rows_ok and _row_icon_ok(b)
	t.check("Shop-rijen tonen een 16px-icoon", rows_ok)
	if item_rows.size() > 0:
		(item_rows[0] as Button).grab_focus()
		await t.pframes(2)
	var sid := str(item_rows[0].get_meta("item_icon_id", "")) if item_rows.size() > 0 else ""
	t.check("Shop-detailvak toont het 32px-icoon", _detail_ok(s.detail_icon, sid))
	await _shot("shop")
	s.queue_free()
	await t.pframes(3)


func _shot(naam: String) -> void:
	if shots == "":
		return
	await t.screenshot("%s/item_icons_%s.png" % [shots, naam])
