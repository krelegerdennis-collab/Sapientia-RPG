extends StaticBody2D
## v0.11 BOEKPUNT (was v0.10 save_point.gd): een gloeiend open boek op een lessenaar (1 tile,
## blokkeert). Sta ervoor, kijk ernaar en druk op A. Wat het boek doet staat als data in
## scripts/data/book_data.gd, gekozen met 'type':
##   "save" (cyaan) : HP en MP van de party vol, "Een warme gloed herstelt je krachten en je geest.", dan
##                    "Het boek gloeit zacht. Voortgang opslaan?" Ja = GameState.save_game().
##   "mp"   (groen) : alleen MP vol, niet opslaan.
##   "hp"   (rood)  : alleen HP vol, niet opslaan.
## Plaatje: 4 frames van 16x16 naast elkaar (RPG ART), speelt in een lus.
## AURA: een zachte ronde gloed (in code gemaakte GradientTexture2D, één per kleur) met
## additieve blending achter/rond het boek. Alpha en grootte gaan zacht op en neer
## (AURA_PERIOD). Eén sprite, geen Light2D: goedkoop op telefoons (gl_compatibility).

const BookData := preload("res://scripts/data/book_data.gd")

const FRAME_TIME := 0.22
const ORDER := [0, 1, 2, 3]
const AURA_RADIUS := 44.0          # pixels (±2,75 tiles)
const AURA_PERIOD := 1.8           # seconden per puls
const AURA_ALPHA := Vector2(0.25, 0.6)
const AURA_SCALE := Vector2(0.88, 1.08)

static var _aura_textures := {}

## "save", "hp" of "mp" (zie BookData.TYPES).
@export_enum("save", "hp", "mp", "save_bibliotheek") var type := "save"

var aura: Sprite2D
var _aura_t := 0.0
var info: Dictionary
## Kleur van de aura (uit de data).
var aura_color: Color

@onready var sprite: Sprite2D = $Sprite2D
var _t := 0.0
var _i := 0
var busy := false
## Laatste uitkomst (voor de autotest): "", "saved", "declined", "failed" of "restored".
var last_result := ""


func _ready() -> void:
	info = BookData.TYPES.get(type, BookData.TYPES["save"])
	aura_color = info["aura"]
	var tex: Texture2D = load(info["texture"]) if ResourceLoader.exists(info["texture"]) else null
	if tex:
		sprite.texture = tex
	sprite.hframes = 4
	aura = Sprite2D.new()
	aura.name = "Aura"
	aura.texture = aura_texture(aura_color)
	aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	aura.show_behind_parent = true
	aura.position = Vector2(0, 2)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura.material = mat
	add_child(aura)
	move_child(aura, 0)
	_update_aura()


## Zachte ronde gloed (wit-getint midden -> doorzichtig), één keer per kleur gemaakt en gedeeld.
static func aura_texture(c: Color) -> Texture2D:
	var key := c.to_html()
	if not _aura_textures.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(c.lerp(Color.WHITE, 0.35), 0.95),
				Color(c, 0.6), Color(c, 0.18), Color(c, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = int(AURA_RADIUS * 2.0)
		t.height = int(AURA_RADIUS * 2.0)
		_aura_textures[key] = t
	return _aura_textures[key]


## 0..1..0 in AURA_PERIOD seconden (zacht, cosinus).
func aura_pulse() -> float:
	return 0.5 - 0.5 * cos(TAU * _aura_t / AURA_PERIOD)


func _update_aura() -> void:
	var k := aura_pulse()
	aura.modulate = Color(1, 1, 1, lerpf(AURA_ALPHA.x, AURA_ALPHA.y, k))
	var sc := lerpf(AURA_SCALE.x, AURA_SCALE.y, k)
	aura.scale = Vector2(sc, sc)


func _process(delta: float) -> void:
	_aura_t = fmod(_aura_t + delta, AURA_PERIOD)
	_update_aura()
	_t += delta
	if _t >= FRAME_TIME:
		_t -= FRAME_TIME
		_i = (_i + 1) % ORDER.size()
		sprite.frame = ORDER[_i]


## Vult HP en/of MP van de hele party aan (ook KO = 0 HP komt terug).
func restore() -> void:
	for h in GameState.party:
		if h == null:
			continue
		if info.get("hp", false):
			h["hp"] = h["max_hp"]
		if info.get("mp", false):
			h["mp"] = h["max_mp"]
	# Codex: de ingeschreven monsters rusten mee (ook een KO-bondgenoot)
	for p in GameState.codex_pages:
		if info.get("hp", false):
			p["hp"] = p["max_hp"]
		if info.get("mp", false):
			p["mp"] = p["max_mp"]


func interact(player: Node2D) -> void:
	if busy or Dialog.is_open:
		return
	busy = true
	restore()
	last_result = "restored"
	var line: String = info.get("line", "")
	if line != "":
		Dialog.show_lines([line])
		await Dialog.finished
	if info.get("save", false):
		var choice: int = await Dialog.ask(info.get("question", "Save progress?"), ["Yes", "No"])
		if choice == 0:
			if GameState.save_game(player.get_tile(), player.facing):
				last_result = "saved"
				Dialog.show_lines(["Saved."])
			else:
				last_result = "failed"
				Dialog.show_lines(["Save failed."])
		else:
			last_result = "declined"
	busy = false
