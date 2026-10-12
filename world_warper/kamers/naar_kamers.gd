extends StaticBody2D
## Deur in de bestaande hub naar De Hal. Vervangt die hub niet.

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")


func _ready() -> void:
	var lab := Label.new()
	lab.text = "ECHO"
	lab.position = Vector2(-20, -22)
	lab.size = Vector2(40, 12)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", FONT)
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", Color("f2e9d8"))
	add_child(lab)


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
