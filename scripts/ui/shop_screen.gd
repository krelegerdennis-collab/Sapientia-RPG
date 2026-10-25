extends "res://scripts/ui/menu_screen.gd"
## Winkel in Wilgendal. Kopen en verkopen. Magie kiest eerst een held.
## Teksten die de speler ziet zijn Engels (ook in de Handelskamer).

const ShopData := preload("res://scripts/data/shop_data.gd")
const ItemIcons := preload("res://scripts/data/item_icons.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const GameData := preload("res://scripts/data/game_data.gd")

var shop_id := ""
var mode := "koop"
var _pending_spell := ""
var detail_row: HBoxContainer
var detail_icon: TextureRect
var detail_name: Label
var detail_desc: Label


func _build() -> void:
	header.text = ShopData.shop_name(shop_id)
	set_hint("A: choose   B: back")
	_wrap_scroll()
	_show_koop()


## Winkelregel op tikmaat (25 eenheden = ~48 dp). De lijst scrolt met de vinger of de joystick.
func _row(text: String, item_id := "") -> Button:
	var b := UiMenu.button(text)
	b.custom_minimum_size.y = UiTouchC.ROW_TOUCH
	if item_id != "":
		ItemIcons.apply16(b, item_id)
	b.focus_entered.connect(_on_row_focus.bind(item_id))
	return b


## Zet de inhoud in een ScrollContainer: grote regels passen niet altijd allemaal in beeld.
func _wrap_scroll() -> void:
	var outer := content.get_parent()
	var at := content.get_index()
	var sc := ScrollContainer.new()
	sc.name = "ShopScroll"
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 6
	sc.follow_focus = true
	outer.remove_child(content)
	content.size_flags_vertical = Control.SIZE_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	outer.add_child(sc)
	outer.move_child(sc, at)
	_ensure_detail()


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _ensure_detail() -> void:
	if detail_row != null:
		return
	detail_row = HBoxContainer.new()
	detail_row.name = "ItemDetail"
	detail_row.add_theme_constant_override("separation", 4)
	detail_icon = ItemIcons.make_rect(ItemIcons.SIZE32)
	detail_icon.name = "DetailIcon"
	detail_row.add_child(detail_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	detail_name = UiMenu.label("", MenuColors.TITLE)
	detail_name.clip_text = true
	detail_desc = UiMenu.label("", MenuColors.TEXT_DIM)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_desc.clip_text = true
	col.add_child(detail_name)
	col.add_child(detail_desc)
	detail_row.add_child(col)
	var hint_i := hint.get_index()
	_outer.add_child(detail_row)
	_outer.move_child(detail_row, hint_i)
	ItemIcons.show32(detail_icon, "")


func _on_row_focus(item_id: String) -> void:
	if item_id == "":
		ItemIcons.show32(detail_icon, "")
		if detail_name:
			detail_name.text = ""
		if detail_desc:
			detail_desc.text = ""
		return
	ItemIcons.show32(detail_icon, item_id)
	if detail_name:
		detail_name.text = _detail_name(item_id)
	if detail_desc:
		detail_desc.text = _detail_desc(item_id)


func _detail_name(id: String) -> String:
	if GameData.SPELLS.has(id):
		return str(GameData.SPELLS[id].get("name", id))
	return PartyActions.item_name(id)


func _detail_desc(id: String) -> String:
	if GameData.SPELLS.has(id):
		return str(GameData.SPELLS[id].get("desc", ""))
	return str(PartyActions.item_data(id).get("desc", ""))


func _show_koop() -> void:
	mode = "koop"
	_pending_spell = ""
	_clear()
	var switch := _row("Sell")
	switch.pressed.connect(_show_verkoop)
	content.add_child(switch)
	var rows: Array = ShopData.stock(shop_id)
	if rows.is_empty():
		content.add_child(UiMenu.label("The shelves are empty.", MenuColors.TEXT_DIM))
		return
	for row in rows:
		var id := str(row["id"])
		var b := _row("%s  %dg" % [str(row["name"]), int(row["price"])], id)
		b.pressed.connect(_on_buy.bind(id, str(row.get("kind", "item"))))
		content.add_child(b)
	if content.get_child_count() > 1:
		(content.get_child(1) as Control).grab_focus()


func _show_verkoop() -> void:
	mode = "verkoop"
	_clear()
	var back := _row("Buy")
	back.pressed.connect(_show_koop)
	content.add_child(back)
	var rows: Array = ShopData.sellable()
	if rows.is_empty():
		content.add_child(UiMenu.label("Nothing to sell.", MenuColors.TEXT_DIM))
		back.grab_focus()
		return
	for row in rows:
		var id := str(row["id"])
		var b := _row("%s x%d  %dg" % [str(row["name"]), int(row["n"]), int(row["price"])], id)
		b.pressed.connect(_on_sell.bind(id))
		content.add_child(b)


func _show_held(spell_id: String) -> void:
	mode = "held"
	_pending_spell = spell_id
	_clear()
	content.add_child(UiMenu.label("Who learns this?", MenuColors.TEXT))
	var any := false
	for h in GameState.party:
		if int(h.get("hp", 1)) <= 0:
			continue
		var hero: Dictionary = h
		var b := _row(str(hero.get("name", "?")))
		b.pressed.connect(_on_hero.bind(hero))
		content.add_child(b)
		if not any:
			b.grab_focus()
			any = true
	if not any:
		show_message("Nobody can learn this.")


func _on_buy(id: String, kind: String) -> void:
	if kind == "spell":
		_show_held(id)
		return
	var r := ShopData.buy_item(shop_id, id)
	show_message(str(r["text"]))
	if r["ok"]:
		_show_koop()


func _on_hero(hero: Dictionary) -> void:
	var r := ShopData.buy_spell(shop_id, _pending_spell, hero)
	show_message(str(r["text"]))
	_show_koop()


func _on_sell(id: String) -> void:
	var r := ShopData.sell(id)
	show_message(str(r["text"]))
	_show_verkoop()


func back() -> void:
	if mode == "held" or mode == "verkoop":
		_show_koop()
		return
	close()
