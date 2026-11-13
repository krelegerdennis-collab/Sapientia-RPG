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
## Plaatje: assets/sprites/dungeon100_rustpunt.png (64x16, 4 frames van 16x16, zachte lus).
## Het opslagboek blijft de onzichtbare basis voor de botsing en BookPoint, zonder tint.

const SCENE := "res://scenes/dungeon100_rustpunt.tscn"
const RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const TINT := Color(1.0, 0.86, 0.62)
const SHEET := preload("res://assets/sprites/dungeon100_rustpunt.png")
const FRAME_COUNT := 4
const FRAME_PX := 16
## Zachte lus, binnen 6-8 fps.
const ANIM_FPS := 7.0
const ACTIVATED_LINE := "The party is restored. This is not a return point: falling means out of the Archive."

## Voor de tests: de laatste keer dat het rustpunt een NIEUW checkpoint werd.
var last_activated := false
## Zichtbare rustpunt-animatie (4 frames uit SHEET).
var art: AnimatedSprite2D


func _init() -> void:
	type = "rustpunt"


static func create(tile: Vector2i) -> Node2D:
	var rp: Node2D = load(SCENE).instantiate()
	rp.position = Vector2(tile) * 16.0 + Vector2(8, 8)
	return rp


func _ready() -> void:
	super._ready()
	# Boek (save_book.png) blijft de basis, maar wordt niet getint en niet getekend.
	sprite.modulate = Color.WHITE
	sprite.visible = false
	_plaats_art()


func _plaats_art() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", ANIM_FPS)
	frames.set_animation_loop("default", true)
	for i in FRAME_COUNT:
		frames.add_frame("default", _frame(i))
	art = AnimatedSprite2D.new()
	art.name = "RustpuntArt"
	art.sprite_frames = frames
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(art)
	art.play("default")


static func _frame(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(index * FRAME_PX, 0, FRAME_PX, FRAME_PX)
	return atlas


func interact(player: Node2D) -> void:
	# Solo-pad hieronder blijft hetzelfde. Alleen een online run slaat af.
	if Run.active:
		_interact_online(player)
		return
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


## Online: de host geneest de stoelen en laat down-stoelen opstaan.
## Geen dungeon100-checkpoint, geen solo-opslagvraag. De revive-teller blijft staan.
func _interact_online(_player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	last_activated = false
	var did := false
	var seen: Array = []
	for arena in _online_arenas():
		if arena == null or seen.has(arena):
			continue
		seen.append(arena)
		if arena.has_method("coop_apply_online_rest") and bool(arena.coop_apply_online_rest()):
			did = true
	last_result = "online_rest" if did else "online_skip"
	busy = false


func _online_arenas() -> Array:
	var out: Array = []
	var n: Node = get_parent()
	while n != null:
		if "som" in n and n.get("som") != null:
			out.append(n.som)
			break
		n = n.get_parent()
	var sess: Node = GameState._coop_session
	if sess != null and is_instance_valid(sess) and sess.get("arena") != null:
		out.append(sess.arena)
	return out
