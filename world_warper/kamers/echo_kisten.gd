class_name EchoKisten
extends Node2D
## Drie kisten in ECHO's Kamer: Codex, Uitrusting, Accessoire.
## Leeg zolang de act dat zegt. Na elke voltooide grot-run licht er één op.
## Act 6: de gevulde kisten pulseren en ECHO wordt feller.
## Geen buit en geen verhaal-twist. Kleurvlakken, geen art-bestand.

const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Kamers := preload("res://world_warper/kamers/kamers.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

const FLAG_GETELD := "echo_kisten_geteld"
const SOORTEN: Array[String] = ["codex", "uitrusting", "accessoire"]
const NAMEN := {
	"codex": "Codex",
	"uitrusting": "Uitrusting",
	"accessoire": "Accessoire",
}
const KLEUREN := {
	"codex": Color("9b6dff"),
	"uitrusting": Color("4aa3ff"),
	"accessoire": Color("3ddec0"),
}
const LEEG := Color(0.12, 0.13, 0.18, 1)
const ECHO_FELLER := Color(1.55, 1.25, 1.85, 1)

var _vlakken: Array[Sprite2D] = []
var _pulse := false
var _t := 0.0


static func gevulde(act: int) -> int:
	if act <= 2:
		return 0
	if act == 3:
		return 1
	if act == 4:
		return 2
	return 3


static func pulseren(act: int) -> bool:
	return act >= 6


static func echo_feller(act: int) -> bool:
	return act >= 6


## Telt een afgeronde run één keer, zolang echo_grot_resultaat aan staat.
## De vlag zelf blijft: ECHO leest hem nog voor.
static func tel_resultaat(flags: Dictionary, teller: int) -> int:
	var aan: bool = flags.get(EchoGrot.FLAG_RESULTAAT, false) == true
	if aan and flags.get(FLAG_GETELD, false) != true:
		flags[FLAG_GETELD] = true
		return teller + 1
	if not aan:
		flags.erase(FLAG_GETELD)
	return teller


func _ready() -> void:
	var x0 := 40.0
	for i in SOORTEN.size():
		var soort := SOORTEN[i]
		var vlak := Sprite2D.new()
		vlak.name = "Kist" + str(i)
		vlak.position = Vector2(x0 + float(i) * 32.0, 88.0)
		vlak.centered = true
		vlak.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vlak.texture = _vlak(LEEG)
		vlak.set_meta("soort", soort)
		vlak.set_meta("gevuld", false)
		vlak.set_meta("licht", false)
		add_child(vlak)
		_vlakken.append(vlak)
		var lab := Label.new()
		lab.text = str(NAMEN[soort])
		lab.position = Vector2(-16, -18)
		lab.size = Vector2(36, 10)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_override("font", FONT)
		lab.add_theme_font_size_override("font_size", 6)
		lab.add_theme_color_override("font_color", Color("f2e9d8"))
		vlak.add_child(lab)
	GameState.echo_grot_voltooid = tel_resultaat(GameState.story_flags, GameState.echo_grot_voltooid)
	ververs()


func ververs() -> void:
	var act := Kamers.huidige_act(GameState.party)
	pas_toe(act, GameState.echo_grot_voltooid)


func pas_toe(act: int, runs: int) -> void:
	var vol := gevulde(act)
	var licht := mini(maxi(runs, 0), SOORTEN.size())
	_pulse = pulseren(act)
	_t = 0.0
	for i in _vlakken.size():
		var soort := SOORTEN[i]
		var basis: Color = KLEUREN[soort]
		var vlak := _vlakken[i]
		var vol_deze := i < vol
		var licht_deze := i < licht
		vlak.texture = _vlak(basis if vol_deze else LEEG)
		vlak.set_meta("gevuld", vol_deze)
		vlak.set_meta("licht", licht_deze)
		if licht_deze:
			vlak.modulate = Color(1.35, 1.25, 1.5, 1)
		else:
			vlak.modulate = Color(0.55, 0.55, 0.62, 1)
	_echo_tint(echo_feller(act))
	set_process(_pulse)


func gevuld_aantal() -> int:
	var n := 0
	for vlak in _vlakken:
		if bool(vlak.get_meta("gevuld", false)):
			n += 1
	return n


func licht_aantal() -> int:
	var n := 0
	for vlak in _vlakken:
		if bool(vlak.get_meta("licht", false)):
			n += 1
	return n


func _process(delta: float) -> void:
	if not _pulse:
		return
	_t += delta
	var golf := 0.65 + 0.35 * sin(_t * 4.0)
	for vlak in _vlakken:
		if bool(vlak.get_meta("gevuld", false)):
			vlak.modulate = Color(1.2 + golf * 0.4, 1.1 + golf * 0.3, 1.4 + golf * 0.4, 0.75 + golf * 0.25)


func _vlak(kleur: Color) -> ImageTexture:
	var img := Image.create(18, 14, false, Image.FORMAT_RGBA8)
	img.fill(kleur)
	return ImageTexture.create_from_image(img)


func _echo_tint(feller: bool) -> void:
	var echo: Node = null
	if get_parent() != null:
		echo = get_parent().get_node_or_null("Echo")
	if echo == null:
		return
	var spr := echo.get_node_or_null("Sprite2D") as CanvasItem
	if spr == null:
		return
	spr.modulate = ECHO_FELLER if feller else Color.WHITE
