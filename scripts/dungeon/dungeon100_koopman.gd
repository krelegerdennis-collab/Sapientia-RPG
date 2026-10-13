extends StaticBody2D
## DE KOOPMAN (H-5) in de Diepe Grot, met zijn kraam (grot_kamers.png rij 2). Gemaakt door
## dungeon100_room.gd op een koopmanverdieping (scripts/data/grot_kamers.gd). 1 tile, blokkeert;
## de kraam erboven (4 breed) blokkeert ook. A = gesprek (scripts/data/koopman_data.gd): het eerste
## gesprek op deze verdieping in deze run telt als bezoek; bij fase 3 eenmalig H-5's Token.

const Data := preload("res://scripts/data/koopman_data.gd")
const Kamers := preload("res://scripts/data/grot_kamers.gd")
const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}

var facing := Vector2i.DOWN
var sprite: Sprite2D
## Voor de tests: regels van het laatste gesprek en de fase.
var last_lines: Array[String] = []
var last_fase := 0
var bezoek_sleutel := ""


## kraam_links = linkertegel van de kraam (de Koopman staat op kraam_links + (1, 1)).
static func create(kraam_links: Vector2i, sleutel: String) -> Node2D:
	var root := Node2D.new()
	root.name = "KoopmanKraam"
	var kraam := StaticBody2D.new()
	kraam.name = "Kraam"
	kraam.position = Vector2(kraam_links) * 16.0
	for i in Kamers.KRAAM_KOLOMMEN.size():
		var s := Sprite2D.new()
		s.texture = Kamers.tegel(Kamers.KRAAM_KOLOMMEN[i], 2)
		s.centered = false
		s.position = Vector2(i * 16, 0)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		kraam.add_child(s)
	var ks := CollisionShape2D.new()
	var kr := RectangleShape2D.new()
	kr.size = Vector2(64, 14)
	ks.shape = kr
	ks.position = Vector2(32, 8)
	kraam.add_child(ks)
	root.add_child(kraam)
	var kleed := Sprite2D.new()
	kleed.name = "Kleed"
	kleed.texture = Kamers.tegel(Kamers.KLEED_KOLOM, 2)
	kleed.centered = false
	kleed.position = Vector2(kraam_links + Vector2i(2, 1)) * 16.0
	kleed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(kleed)
	var k: Node2D = (load("res://scripts/dungeon/dungeon100_koopman.gd") as GDScript).new()
	k.name = "Koopman"
	k.position = Vector2(kraam_links + Vector2i(1, 1)) * 16.0 + Vector2(8, 8)
	k.set("bezoek_sleutel", sleutel)
	root.add_child(k)
	return root


func _init() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = Data.SPRITE
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.offset = Vector2(0, -4)     # 16x24-frame: voeten op de tegel
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 14)
	cs.shape = r
	add_child(cs)


func _ready() -> void:
	add_to_group("koopman")
	_update_sprite()


func get_tile() -> Vector2i:
	return Vector2i((position / 16.0).floor())


func _update_sprite() -> void:
	sprite.frame = int(DIR_ROW.get(facing, 0)) * 3


## Het gesprek zelf (zonder Dialog), ook voor de tests: telt het bezoek, geeft eventueel de token.
func praat() -> Array[String]:
	var n: int = GameState.koopman_bezoek(bezoek_sleutel)
	var na_a5: bool = GameState.story_flags.has("archief5_voltooid")
	last_fase = Data.fase(n, na_a5)
	last_lines = Data.gesprek(n, GameState.koopman_token, na_a5)
	if last_fase == Data.FASE_WAARHEID and not GameState.koopman_token:
		GameState.koopman_token = true
	return last_lines


func interact(player: Node2D) -> void:
	if Dialog.is_open:
		return
	if "facing" in player:
		facing = -player.facing
		_update_sprite()
	Dialog.show_lines(praat(), Data.NAAM, self)
