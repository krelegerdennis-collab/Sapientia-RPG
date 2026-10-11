extends StaticBody2D
## Deur in de bestaande hub naar De Hal. Vervangt die hub niet.

const Kamers := preload("res://world_warper/kamers/kamers.gd")


func interact(player: Node) -> void:
	if GameState.changing_map or GameState.in_battle:
		return
	if not Kamers.is_open("hal", GameState.story_flags, GameState.party):
		if not Dialog.is_open:
			Dialog.show_lines([Kamers.GESLOTEN], "")
		return
	if "input_locked" in player:
		player.input_locked = true
	GameState.change_map(Kamers.scene_path("hal"), "van_hub")
