extends "res://scripts/story_object.gd"
class_name MolenWieken
## Molen van Gerrit op het plein van Wilgendal.
## Stil tot Het Zingende Graan klaar is. De zangscène (zing) laat de wieken draaien
## en speelt zacht gezang uit de noten in story_data. Geen extra dialoog.
## v0.21 had een kleine molen (48x64) met zelf gedraaide tussenstappen; v3 gebruikt de reuzenmolen v2.

const SD := preload("res://scripts/data/story_data.gd")

signal begon_te_zingen

## v3 (Dennis 14 okt 2026): reuzenmolen v2 van RPG ART. Basis 224x320 (14x20 tegels), wieken 224x224
## met de naaf op (112,112). Vóór de quest van Gerrit (vlag zingend_graan_klaar): stille, versleten wieken
## (windmolen_wieken_stil_v2.png). Daarna de draaiende sheet (4 frames, 22.5 graden per frame, naadloos).
## De node staat op de LINKERONDERHOEK van de basis: y-sort op de onderrand, dus achter (noord van) de
## molen verdwijnt de speler achter de toren. Alleen de voet (kolommen 2-11, rijen 17-19) botst.
const MAP := "res://assets/sprites/buiten/wilgendal/"
const ART := MAP + "windmolen_wieken_v2.png"
const ART_STIL := MAP + "windmolen_wieken_stil_v2.png"
const ART_BASIS := MAP + "windmolen_basis_v2.png"
const FRAME_W := 224
const FRAME_H := 224
const FRAMES := 4
const BASIS := Vector2i(224, 320)
const NAAF := Vector2(112, 112)
const LENGTE := 108
const RATE := 22050
const ZANG_GAIN := 0.12
const STAP_GRADEN := 22.5
const STAPPEN := 4
const STAP_TIJD := 0.2   # 5 fps
## Voet in tegels t.o.v. de linkerbovenhoek van de basis.
const VOET := Rect2i(2, 17, 10, 3)
const _NOOT := Color(0.95, 0.86, 0.62, 1.0)

static var _noot: ImageTexture

var gezongen := false
var noten := 0
var laatste_zang: AudioStreamWAV
var _zang: AudioStreamPlayer


func _ready() -> void:
	texture = wieken_stil()
	hframes = 1
	loop_texture = wieken_sheet()
	loop_frames = STAPPEN
	loop_time = STAP_TIJD
	add_to_group("molen_wieken")
	super._ready()
	_opbouw()


## Basis, wieken (z+1, boven de speler) en botsing op de voet.
func _opbouw() -> void:
	var top := Vector2(0, -BASIS.y)
	var basis := get_node_or_null("Basis") as Sprite2D
	if basis == null:
		basis = Sprite2D.new()
		basis.name = "Basis"
		add_child(basis)
		move_child(basis, 0)
	basis.texture = load(ART_BASIS)
	basis.centered = false
	basis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	basis.position = top
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.position = top + NAAF
	sprite.z_index = 1
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		var vorm := RectangleShape2D.new()
		vorm.size = Vector2(VOET.size) * 16.0 - Vector2(2, 2)
		cs.shape = vorm
		cs.position = top + (Vector2(VOET.position) + Vector2(VOET.size) / 2.0) * 16.0
	if glow != null:
		glow.position = top + NAAF


## Naaf in lokale coördinaten (voor de noten en tests).
func naaf() -> Vector2:
	return Vector2(0, -BASIS.y) + NAAF


func stil() -> bool:
	return sprite != null and sprite.texture == wieken_stil()


func draait() -> bool:
	return looping


func frame_nu() -> int:
	return int(sprite.frame) if sprite != null else -1


func glow_aan() -> bool:
	return glow != null and glow.visible


## Eenmalige scène: de wieken slaan aan en de molen zingt zacht.
func zing() -> void:
	story_refresh()
	if not looping:
		looping = true
		set_process(true)
	_speel()
	_laat_noten_zien()
	gezongen = true
	begon_te_zingen.emit()
	await get_tree().create_timer(SD.MOLEN_ZANG_SEC).timeout
	if _zang != null:
		_zang.stop()


## Draaiende wieken: 4 frames van 224x224 (hframes = 4).
static func wieken_sheet() -> Texture2D:
	return load(ART) as Texture2D


## Stille, versleten wieken (vóór de quest van Gerrit).
static func wieken_stil() -> Texture2D:
	return load(ART_STIL) as Texture2D


## Het art-bestand (4 frames) als RGBA8-plaatje.
static func art_image() -> Image:
	var img := wieken_sheet().get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func hoek_van_stap(stap: int) -> float:
	return float(stap) * STAP_GRADEN


static func maak_zang() -> AudioStreamWAV:
	return maak_toon(SD.MOLEN_ZANG, SD.MOLEN_ZANG_SEC)


static func maak_toon(noten_in: Array, sec: float) -> AudioStreamWAV:
	var samples := maxi(1, int(round(sec * float(RATE))))
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	for i in samples:
		var t := float(i) / float(RATE)
		var s := 0.0
		for ruw in noten_in:
			var noot: Dictionary = ruw
			var t0 := float(noot["t"])
			var duur := float(noot["d"])
			if t < t0 or t >= t0 + duur:
				continue
			var u := (t - t0) / duur
			var env := sin(PI * u)
			var fase := TAU * float(noot["hz"]) * (t - t0)
			s += (sin(fase) + 0.25 * sin(fase * 2.0)) * env
		s *= ZANG_GAIN
		pcm.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = pcm
	return stream


static func piek(stream: AudioStreamWAV) -> float:
	if stream == null:
		return 0.0
	var data := stream.data
	var top := 0
	var i := 0
	while i + 1 < data.size():
		top = maxi(top, absi(data.decode_s16(i)))
		i += 2
	return float(top) / 32767.0


func _speel() -> void:
	if _zang == null:
		_zang = AudioStreamPlayer.new()
		_zang.name = "Zang"
		if AudioServer.get_bus_index("SFX") >= 0:
			_zang.bus = "SFX"
		add_child(_zang)
	laatste_zang = maak_zang()
	_zang.stream = laatste_zang
	_zang.play()


func _laat_noten_zien() -> void:
	noten = 0
	for i in 3:
		var s := Sprite2D.new()
		s.texture = _noot_tex()
		s.position = naaf() + Vector2(-8 + i * 8, -20)
		s.modulate = Color(_NOOT.r, _NOOT.g, _NOOT.b, 0.0)
		add_child(s)
		noten += 1
		var tw := s.create_tween()
		tw.tween_interval(0.12 * float(i))
		tw.tween_property(s, "modulate:a", 0.8, 0.2)
		tw.tween_property(s, "position:y", s.position.y - 18.0, 1.5)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 1.5)
		tw.finished.connect(s.queue_free)


static func _noot_tex() -> ImageTexture:
	if _noot == null:
		var img := Image.create(7, 11, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var bits := ["..#....", "..#....", "..#.#..", "..#.##.", "..###..", "..#....", ".#####.", "#..#..#"]
		for y in bits.size():
			var rij: String = bits[y]
			for x in rij.length():
				if rij[x] == "#":
					img.set_pixel(x, y + 2, _NOOT)
		_noot = ImageTexture.create_from_image(img)
	return _noot
