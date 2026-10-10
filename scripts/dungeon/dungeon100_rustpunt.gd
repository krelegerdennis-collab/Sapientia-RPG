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
## groep, dan is de run voorbij en sta je weer voor de ingang op de wereldkaart. Daarna de vraag
## 'Voortgang opslaan?'. Staat het rustpunt op een verdieping zonder rustpunt-regel (niet 10, 20, ...)
## of buiten de kerker, dan herstelt en bewaart het wel, maar het checkpoint verandert niet.
## Plaatje: voorlopig het opslagboek, warm getint (PLACEHOLDER, zie HANDOFF_DUNGEON100_REGELS.md).

const SCENE := "res://scenes/dungeon100_rustpunt.tscn"
const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")
const TINT := Color(1.0, 0.86, 0.62)
const ACTIVATED_LINE := "De groep is hersteld. Dit is geen terugkeerpunt: vallen betekent het Archief uit."

## Voor de tests: de laatste keer dat het rustpunt een NIEUW checkpoint werd.
var last_activated := false


func _init() -> void:
	type = "rustpunt"


static func create(tile: Vector2i) -> Node2D:
	var rp: Node2D = load(SCENE).instantiate()
	rp.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	return rp


func _ready() -> void:
	super._ready()
	sprite.modulate = TINT


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
	var choice: int = await Dialog.ask(str(info.get("question", "Voortgang opslaan?")), ["Ja", "Nee"])
	if choice == 0:
		if GameState.save_game(player.get_tile(), player.facing):
			last_result = "saved"
			Dialog.show_lines(["Opgeslagen."])
		else:
			last_result = "failed"
			Dialog.show_lines(["Opslaan is mislukt."])
	else:
		last_result = "declined"
	busy = false
