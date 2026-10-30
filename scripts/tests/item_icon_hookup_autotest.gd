extends RefCounted
## WM1: item-iconen (PR #279) aangesloten — extra controles binnen --autotest.
## Draait mee aan het eind van de volledige --autotest en met -- --autotest --test-item-icons.
##  - elke item_id uit de data heeft een EIGEN icoon (icons16/ en icons32/, geen categorie-terugval)
##  - icon_for(id, maat) + cache (zelfde Texture-object bij tweede aanroep)
##  - Items/Equipment/Shop: elke itemrij 16px, detailvak 32px (en nooit 32px in een rij)
##  - ontbrekend bestand -> categorie-icoon; helemaal niets -> rij zonder icoon, detailvak verborgen

const ItemIcons := preload("res://scripts/data/item_icons.gd")
const ItemsScreen := preload("res://scripts/ui/items_screen.gd")
const EquipmentScreen := preload("res://scripts/ui/equipment_screen.gd")
const ShopScreen := preload("res://scripts/ui/shop_screen.gd")

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	print("=== WM1 item-iconen hookup ===")
	_data_checks()
	_cache_checks()
	_missing_file_fallback()
	_nothing_fallback()
	GameState.new_game("Dax")
	GameState.gold = 500
	GameState.inventory["kort_zwaard"] = 1
	GameState.inventory["dolk"] = 1
	GameState.inventory["leren_harnas"] = 1
	await _items_ui()
	await _equipment_ui()
	await _shop_ui()


func _data_checks() -> void:
	var ids: Array[String] = ItemIcons.catalog_ids()
	var bad: Array[String] = []
	for id in ids:
		var p16 := ItemIcons.path16(id)
		var p32 := ItemIcons.path32(id)
		var ok := ItemIcons.has_mapping(id) \
				and p16.begins_with(ItemIcons.ROOT + "icons16/") and ResourceLoader.exists(p16) \
				and p32.begins_with(ItemIcons.ROOT + "icons32/") and ResourceLoader.exists(p32) \
				and ItemIcons.is_px(ItemIcons.icon_for(id, 16), 16) \
				and ItemIcons.is_px(ItemIcons.icon_for(id, 32), 32)
		if not ok:
			bad.append(id)
	t.check("hookup: alle %d item_ids hebben een eigen 16+32px-icoon (fout: %s)" % [ids.size(), bad],
			ids.size() > 0 and bad.is_empty())


func _cache_checks() -> void:
	var a := ItemIcons.icon_for("drankje", 16)
	var b := ItemIcons.icon_for("drankje", 16)
	t.check("hookup: icon_for cachet (zelfde texture-object)", a != null and a == b)
	t.check("hookup: icon_for maat 32 != maat 16",
			ItemIcons.is_px(ItemIcons.icon_for("drankje", 32), 32) and ItemIcons.icon_for("drankje", 32) != a)


## Gemapte id met een verdwenen bestand: terugval op het categorie-icoon, geen crash.
func _missing_file_fallback() -> void:
	ItemIcons._ensure()
	var fake := "__wm1_kwijt__"
	ItemIcons._file16[fake] = ItemIcons.ROOT + "icons16/__bestaat_niet__.png"
	ItemIcons._file32[fake] = ItemIcons.ROOT + "icons32/__bestaat_niet__.png"
	var p16 := ItemIcons.path16(fake)
	var p32 := ItemIcons.path32(fake)
	t.check("hookup: ontbrekend 16px-bestand -> categorie-icoon (%s)" % p16,
			p16.begins_with("res://assets/ui/icons/cat_") and ItemIcons.is_px(ItemIcons.icon_for(fake, 16), 16))
	t.check("hookup: ontbrekend 32px-bestand -> categorie-icoon zonder crash",
			p32.begins_with("res://assets/ui/icons/cat_") and ItemIcons.icon_for(fake, 32) != null)
	var btn := Button.new()
	ItemIcons.apply16(btn, fake)
	var rect := ItemIcons.make_rect(ItemIcons.SIZE32)
	ItemIcons.show32(rect, fake)
	t.check("hookup: rij en detailvak met ontbrekend bestand tonen toch een icoon (geen gat)",
			btn.icon != null and rect.visible and rect.texture != null)
	btn.free()
	rect.free()
	ItemIcons._file16.erase(fake)
	ItemIcons._file32.erase(fake)


## Ook geen categorie-icoon: rij zonder icoon (tekst blijft), detailvak verborgen.
func _nothing_fallback() -> void:
	var btn := Button.new()
	btn.text = "Potion"
	btn.icon = ItemIcons.icon_for("drankje", 16)
	var rect := ItemIcons.make_rect(ItemIcons.SIZE32)
	ItemIcons.show32(rect, "drankje")
	# _tex met een niet-bestaand pad geeft null; apply16/show32 met lege id ruimen netjes op
	t.check("hookup: niet-bestaand pad laadt als null (geen crash)",
			ItemIcons._tex("res://assets/ui/icons/__nooit__.png") == null)
	ItemIcons.clear16(btn)
	ItemIcons.show32(rect, "")
	t.check("hookup: zonder icoon geen leeg vak (rij-icoon weg, tekst blijft, detail verborgen)",
			btn.icon == null and btn.text == "Potion" and not rect.visible)
	btn.free()
	rect.free()


func _row16(b: Button) -> bool:
	return b != null and ItemIcons.is_px(b.icon, 16) and int(b.get_meta("item_icon_size", 0)) == 16 \
			and b.icon == ItemIcons.icon_for(str(b.get_meta("item_icon_id", "")), 16)


func _detail32(r: TextureRect, id: String) -> bool:
	return r != null and r.visible and ItemIcons.is_px(r.texture, 32) \
			and r.texture == ItemIcons.icon_for(id, 32)


func _items_ui() -> void:
	var s: Node = ItemsScreen.new()
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	var ok: bool = s.entries.size() == s.ids.size() and s.entries.size() >= 3
	for i in s.entries.size():
		ok = ok and _row16(s.entries[i]) and str(s.entries[i].get_meta("item_icon_id", "")) == str(s.ids[i])
	t.check("hookup: Items — elke rij een 16px-icoon van zijn eigen item_id", ok)
	var last: Button = s.entries[s.entries.size() - 1]
	last.grab_focus()
	await t.pframes(2)
	t.check("hookup: Items — detailvak volgt de focus met 32px", _detail32(s.detail_icon, str(s.ids[s.ids.size() - 1])))
	s.queue_free()
	await t.pframes(3)


func _equipment_ui() -> void:
	var s: Node = EquipmentScreen.new()
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	var slots_ok := true
	for slot in s.slot_buttons:
		var b: Button = s.slot_buttons[slot]
		if str(b.get_meta("item_icon_id", "")) != "":
			slots_ok = slots_ok and _row16(b)
	t.check("hookup: Equipment — gevulde vakrijen 16px", slots_ok)
	s.open_list("wapen")
	await t.pframes(4)
	var ok: bool = s.list_buttons.size() >= 2
	for b in s.list_buttons:
		ok = ok and _row16(b)
	t.check("hookup: Equipment — keuzelijst-rijen 16px", ok)
	if s.list_buttons.size() >= 2:
		s.list_buttons[1].grab_focus()
		await t.pframes(2)
		t.check("hookup: Equipment — detailvak 32px volgt de focus", _detail32(s.detail_icon, str(s.list_ids[1])))
	s.queue_free()
	await t.pframes(3)


func _shop_ui() -> void:
	var s: Node = ShopScreen.new()
	s.shop_id = "wilgendal_wapen"
	t.get_tree().root.add_child(s)
	await t.pframes(8)
	var rows: Array = []
	for c in s.content.get_children():
		if c is Button and str(c.get_meta("item_icon_id", "")) != "":
			rows.append(c)
	var ok: bool = rows.size() >= 1
	for b in rows:
		ok = ok and _row16(b)
	t.check("hookup: Shop — itemrijen 16px (%d)" % rows.size(), ok)
	if rows.size() > 0:
		var b: Button = rows[rows.size() - 1]
		b.grab_focus()
		await t.pframes(2)
		t.check("hookup: Shop — detailvak 32px volgt de focus",
				_detail32(s.detail_icon, str(b.get_meta("item_icon_id", ""))))
	s.queue_free()
	await t.pframes(3)
