extends Area2D
## Groei-plaat in Het Levende Archief. Drie stadia: zaad, scheut, volgroeid.
## Plaatjes zijn placeholders (tools/art_archief2_placeholders.py).

const Archief2 := preload("res://scripts/data/archief2.gd")
const TEX := [
	preload("res://assets/sprites/archief2/plaat_zaad.png"),
	preload("res://assets/sprites/archief2/plaat_scheut.png"),
	preload("res://assets/sprites/archief2/plaat_volgroeid.png"),
]

var plaat_id := ""
var soort := "groei"
var staat := 0
var start := 0
var index := 0
var tile := Vector2i.ZERO
var room_id := ""
var kamer: Node = null
var sprite: Sprite2D


func setup(kamer_node: Node, d: Dictionary) -> void:
	kamer = kamer_node
	plaat_id = str(d.get("id", "p"))
	soort = str(d.get("soort", "groei"))
	start = int(d.get("start", 0 if soort != "tegen" else Archief2.STAAT_MAX))
	index = int(d.get("index", 0))
	var t: Array = d.get("tile", [0, 0])
	tile = Vector2i(int(t[0]), int(t[1]))
	room_id = str(kamer_node.room_id)
	name = "Plaat_" + plaat_id
	position = Vector2(tile) * 16.0 + Vector2(8, 8)
	monitoring = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	cs.shape = rect
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	staat = GameState.archief2_plaat(room_id, plaat_id, start)
	_teken()
	if kamer.has_method("zet_brug"):
		kamer.zet_brug(plaat_id, Archief2.brug_open(staat))


func raak(actie: String) -> void:
	if soort == "ketting" and actie == "stap":
		if kamer.has_method("ketting_stap"):
			kamer.ketting_stap(index)
		return
	var magie := Archief2.lotte_heeft_licht()
	var nieuw := Archief2.volgende_staat(soort, staat, actie, magie)
	if nieuw == staat:
		if soort == "licht" and actie == "licht" and not magie and not Dialog.is_open:
			Dialog.show_lines(["Alleen Lotte's licht laat deze plaat groeien."])
		return
	pas_toe(nieuw)


func pas_toe(nieuw: int) -> void:
	staat = clampi(nieuw, 0, Archief2.STAAT_MAX)
	GameState.archief2_zet_plaat(room_id, plaat_id, staat)
	_teken()
	if kamer.has_method("zet_brug"):
		kamer.zet_brug(plaat_id, Archief2.brug_open(staat))


func interact(_speler: Node2D) -> void:
	if soort != "licht" or Dialog.is_open:
		return
	raak("licht")


func _teken() -> void:
	var i := clampi(staat, 0, TEX.size() - 1)
	sprite.texture = TEX[i]
