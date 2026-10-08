extends Node2D
## v0.14 PLACEHOLDER (haakje) voor de verborgen RUNEPLAAT van RPG CODE (puzzelkamer van het
## Eerste Archief, teken s, id plaat_s). Alleen het plaatje van RPG ART
## (assets/puzzle/drukplaat_rune.png, frame 0 = runentegel 11). Geen signaal, geen logica:
## een kast kan erop staan, maar er gebeurt niets. Vervangen: zie docs/HANDOFF_ARCHIEF1.md.

const PLACEHOLDER := true
const TEX := "res://assets/puzzle/drukplaat_rune.png"

var room: Node
var hook_id := ""
var tile := Vector2i.ZERO
var data := {}
var sprite: Sprite2D


func setup(p_room: Node, id: String, t: Vector2i, d: Dictionary) -> void:
	room = p_room
	hook_id = id
	name = "PH_" + id
	tile = t
	data = d
	position = Vector2(t) * 16 + Vector2(8, 8)
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(TEX)
	sprite.hframes = 2
	sprite.frame = 0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
