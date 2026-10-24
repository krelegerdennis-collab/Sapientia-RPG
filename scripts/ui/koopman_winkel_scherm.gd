extends "res://scripts/ui/shop_screen.gd"
## Winkel van de Koopman (H-5): hetzelfde winkelraam als Wilgendal (shop_screen.gd / menu_screen.gd),
## maar voorraad en prijzen uit scripts/data/koopman_winkel.gd. Tekst Engels.

const Winkel := preload("res://scripts/data/koopman_winkel.gd")

var run_seed := 0
var bezoek := 1
## Verdieping (besluit Dennis 14 okt 2026: waren geschaald op de verdieping); 0 = oude regel.
var verdieping := 0
## Laatste melding (voor de tests).
var last_text := ""


func _build() -> void:
	header.text = "The Merchant  %dg" % GameState.gold
	set_hint("A: choose   B: back")
	_show_koop()


func _show_koop() -> void:
	mode = "koop"
	_clear()
	header.text = "The Merchant  %dg" % GameState.gold
	var switch := UiMenu.button("Sell")
	switch.pressed.connect(_show_verkoop)
	content.add_child(switch)
	for row in Winkel.voorraad(run_seed, bezoek, GameState.koopman_gekocht, verdieping):
		var label := "%s  %dg" % [str(row["name"]), int(row["price"])]
		if int(row.get("grade", 0)) > 0:
			label = "[G%d] %s" % [int(row["grade"]), label]
		var b := UiMenu.button(label)
		b.pressed.connect(_on_buy.bind(str(row["id"]), "item"))
		content.add_child(b)
	if content.get_child_count() > 1:
		(content.get_child(1) as Control).grab_focus()


func _show_verkoop() -> void:
	mode = "verkoop"
	_clear()
	header.text = "The Merchant  %dg" % GameState.gold
	var back_b := UiMenu.button("Buy")
	back_b.pressed.connect(_show_koop)
	content.add_child(back_b)
	var rows: Array = Winkel.verkoopbaar()
	if rows.is_empty():
		content.add_child(UiMenu.label("Nothing to sell.", MenuColors.TEXT_DIM))
		back_b.grab_focus()
		return
	for row in rows:
		var b := UiMenu.button("%s x%d  %dg" % [str(row["name"]), int(row["n"]), int(row["price"])])
		b.pressed.connect(_on_sell.bind(str(row["id"])))
		content.add_child(b)
	(content.get_child(1) as Control).grab_focus()


func _on_buy(id: String, _kind: String) -> void:
	var r := Winkel.koop(run_seed, bezoek, GameState.koopman_gekocht, id, verdieping)
	last_text = str(r["text"])
	show_message(last_text)
	UiSfx.play(UiSfx.COINS if r["ok"] else UiSfx.ERROR)
	if r["ok"]:
		_show_koop()


func _on_sell(id: String) -> void:
	var r := Winkel.verkoop(id)
	last_text = str(r["text"])
	show_message(last_text)
	UiSfx.play(UiSfx.COINS if r["ok"] else UiSfx.ERROR)
	_show_verkoop()
