class_name Dungeon100Rustpunt
extends "res://scripts/book_point.gd"
## RUSTPUNT van de 100-verdiepingen-kerker: een gouden boekpunt op elke 10e verdieping
## (Dungeon100Rules.is_rest_floor). Hergebruikbaar: de generator zet er één neer op die verdiepingen,
##     var rp := Dungeon100Rustpunt.create(Vector2i(x, y))      # tile; scenes/dungeon100_rustpunt.tscn
##     objects.add_child(rp)
## of plaatst scenes/dungeon100_rustpunt.tscn zelf. 1 tile, blokkeert (zoals een boekpunt); de speler
## staat ervoor en drukt op A (de 'interact'-methode van elk object, zie player.gd).
##
## A = HP/MP van de party vol (BookPoint.restore) + dit verdiepingsnummer wordt het laatste rustpunt van
## DEZE RUN (GameState.dungeon100_checkpoint, gaat alleen omhoog). Het is GEEN terugkeerpunt: valt de
## groep, dan is de run voorbij en sta je in ECHO's Kamer. Daarna de vraag
## 'Voortgang opslaan?'. Staat het rustpunt op een verdieping zonder rustpunt-regel (niet 10, 20, ...)
## of buiten de kerker, dan herstelt en bewaart het wel, maar het checkpoint verandert niet.
## Plaatje: kampvuur van RPG ART (batch 10, grot_kamers.png rij 1, kol 0-3, ~0,15 s per frame) met een
## boomstam ernaast; het opslagboek blijft als (onzichtbare) basis voor de botsing en BookPoint.

const SCENE := "res://scenes/dungeon100_rustpunt.tscn"
const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")
const TINT := Color(1.0, 0.86, 0.62)
const GrotKamers := preload("res://scripts/data/grot_kamers.gd")
const ACTIVATED_LINE := "The party is restored. This is not a return point: falling means out of the Archive."

## Voor de tests: de laatste keer dat het rustpunt een NIEUW checkpoint werd.
var last_activated := false
## Het kampvuur (AnimatedSprite2D, 4 frames).
var vuur: AnimatedSprite2D


func _init() -> void:
	type = "rustpunt"


static func create(tile: Vector2i) -> Node2D:
	var rp: Node2D = load(SCENE).instantiate()
	rp.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	return rp


func _ready() -> void:
	super._ready()
	sprite.modulate = TINT
	sprite.visible = false
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", GrotKamers.VUUR_FPS)
	frames.set_animation_loop("default", true)
	for c in GrotKamers.VUUR_FRAMES:
		frames.add_frame("default", GrotKamers.tegel(c, 1))
	vuur = AnimatedSprite2D.new()
	vuur.name = "Kampvuur"
	vuur.sprite_frames = frames
	vuur.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(vuur)
	vuur.play("default")


func interact(player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	var floor_nr: int = GameState.dungeon100_floor
	var cp: int = RulesC.checkpoint_after_rest(GameState.dungeon100_checkpoint, floor_nr)
	last_activated = cp != GameState.dungeon100_checkpoint
	GameState.dungeon100_checkpoint = cp
	GameState.dungeon100_best = RulesC.best_after(GameState.dungeon100_best, floor_nr)
	restore()
	last_result = "restored"
	var lines: Array = [str(info.get("line", ""))]
	if last_activated:
		lines.append(ACTIVATED_LINE)
	Dialog.show_lines(lines)
	await Dialog.finished
	var choice: int = await Dialog.ask(str(info.get("question", "Save progress?")), ["Yes", "No"])
	if choice == 0:
		if GameState.save_game(player.get_tile(), player.facing):
			last_result = "saved"
			UiSfx.play(UiSfx.SAVE)
			Dialog.show_lines(["Saved."])
		else:
			last_result = "failed"
			Dialog.show_lines(["Save failed."])
	else:
		last_result = "declined"
	busy = false
