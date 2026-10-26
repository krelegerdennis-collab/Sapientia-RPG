extends Area2D
## Warp-pad in de eerste hub van de World Warper. Opslaan, of terug naar de kaart.
## TODO(design): WM2 en WM3 hebben nog geen eiland. Die keuze doet niets.

const Archief2 := preload("res://scripts/data/archief2.gd")


func setup(t: Vector2i) -> void:
	name = "WarpPad"
	position = Vector2(t) * 16.0 + Vector2(8, 8)
	monitoring = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	cs.shape = rect
	add_child(cs)


func interact(speler: Node2D) -> void:
	if Dialog.is_open:
		return
	var i := await Dialog.ask("ECHO: Where to?", ["Save", "Willowdale", "Archive entrance", "Other islands"], "ECHO")
	if i < 0 or Dialog.is_open:
		return
	match i:
		0:
			var tile := Vector2i.ZERO
			var facing := Vector2i.DOWN
			if speler.has_method("get_tile"):
				tile = speler.get_tile()
				facing = speler.facing
			if GameState.save_game(tile, facing):
				Dialog.show_lines(["Saved."], "ECHO")
			else:
				Dialog.show_lines(["Saving failed."], "ECHO")
		1:
			_warp("wilgendal")
		2:
			_warp("archief")
		3:
			Dialog.show_lines(Archief2.EILANDEN_DICHT, "ECHO")


func _warp(keuze: String) -> void:
	var doel := Archief2.warp_doel(keuze)
	if doel.is_empty():
		Dialog.show_lines(Archief2.EILANDEN_DICHT, "ECHO")
		return
	GameState.change_map(str(doel["map"]), str(doel["spawn"]))
