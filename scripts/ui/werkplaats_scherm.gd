extends "res://scripts/ui/menu_screen.gd"
## Werkplaats van de World Warper: recepten uit scripts/data/werkplaats_recepten.gd.
## Zelfde menu-basis als de winkel (shop_screen.gd). Engelse speler-teksten.

const Recepten := preload("res://scripts/data/werkplaats_recepten.gd")
const ShopData := preload("res://scripts/data/shop_data.gd")


func _build() -> void:
	header.text = Recepten.TITEL
	set_hint("A: craft   B: back")
	toon()


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func toon() -> void:
	_clear()
	var rows: Array = Recepten.lijst(ShopData.current_act())
	if rows.is_empty():
		content.add_child(UiMenu.label(Recepten.LEEG, MenuColors.TEXT_DIM))
		return
	var eerste: Button = null
	for r in rows:
		var rec: Dictionary = r
		var id := str(rec["id"])
		var b := UiMenu.button("%s: %s" % [Recepten.item_naam(str(rec["uit"])),
				Recepten.ingredienten_tekst(rec, GameState.inventory)])
		b.name = "Recept_" + id
		if not Recepten.kan_maken(rec, GameState.inventory):
			_grey(b)
		b.pressed.connect(_on_maak.bind(id))
		content.add_child(b)
		if eerste == null:
			eerste = b
	if eerste != null:
		eerste.grab_focus()


func _on_maak(id: String) -> void:
	var r := Recepten.maak(id, GameState.inventory)
	show_message(str(r["text"]), MenuColors.INFO if r["ok"] else MenuColors.TEXT_DIM)
	toon()
	var b := content.get_node_or_null("Recept_" + id) as Button
	if b != null:
		b.grab_focus()
