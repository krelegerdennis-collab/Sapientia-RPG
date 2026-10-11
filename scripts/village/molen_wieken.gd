extends "res://scripts/story_object.gd"
class_name MolenWieken
## Molen van Gerrit op het plein van Wilgendal.
## Stil tot Het Zingende Graan klaar is. De zangscène (zing) laat de wieken draaien
## en speelt zacht gezang uit de noten in story_data. Geen extra dialoog.
## Het plaatje is een PLACEHOLDER (magenta hoekjes, letters PH). Geen definitieve art.

const SD := preload("res://scripts/data/story_data.gd")

signal begon_te_zingen

const FRAME_W := 48
const FRAME_H := 64
const FRAMES := 4
const CENTER_X := 24
const CENTER_Y := 26
const LENGTE := 16
const RATE := 22050
const ZANG_GAIN := 0.12
const MAGENTA := Color(1.0, 30.0 / 255.0, 230.0 / 255.0, 1.0)

const _TOREN := Color(0.42, 0.36, 0.28, 1.0)
const _DAK := Color(0.33, 0.22, 0.16, 1.0)
const _ZEIL := Color(0.62, 0.52, 0.32, 1.0)
const _NAAF := Color(0.22, 0.16, 0.1, 1.0)
const _DEUR := Color(0.16, 0.12, 0.1, 1.0)
const _NOOT := Color(0.95, 0.86, 0.62, 1.0)
## Eerste pixel van de letters PH op frame 0. Blijft magenta na het stempelen.
const _PH := [
	"###.#.#.#",
	"#.#.#.#.#",
	"###.#####",
	"#...#.#.#",
	"#...#.#.#",
]

static var _sheet: ImageTexture
static var _noot: ImageTexture

var gezongen := false
var noten := 0
var laatste_zang: AudioStreamWAV
var _zang: AudioStreamPlayer


func _ready() -> void:
	var sheet := placeholder_sheet()
	texture = sheet
	loop_texture = sheet
	hframes = FRAMES
	loop_frames = FRAMES
	add_to_group("molen_wieken")
	super._ready()


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


static func placeholder_sheet() -> ImageTexture:
	if _sheet == null:
		_sheet = ImageTexture.create_from_image(_teken())
	return _sheet


static func merk_pixel() -> Vector2i:
	return Vector2i(18, 50)


## Punt van de eerste wiek in dit frame. Frame 0 wijst naar rechts.
static func zeil_punt(frame: int) -> Vector2i:
	var ang := float(frame) * (PI / 4.0)
	var x := int(round(float(CENTER_X) + cos(ang) * float(LENGTE)))
	var y := int(round(float(CENTER_Y) + sin(ang) * float(LENGTE)))
	return Vector2i(frame * FRAME_W + x, y)


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
		s.position = Vector2(8 + i * 8, 10)
		s.modulate = Color(_NOOT.r, _NOOT.g, _NOOT.b, 0.0)
		add_child(s)
		noten += 1
		var tw := s.create_tween()
		tw.tween_interval(0.12 * float(i))
		tw.tween_property(s, "modulate:a", 0.8, 0.2)
		tw.tween_property(s, "position:y", -8.0, 1.5)
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


static func _teken() -> Image:
	var img := Image.create(FRAME_W * FRAMES, FRAME_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in FRAMES:
		var ox := f * FRAME_W
		for y in range(40, 61):
			for x in range(16, 33):
				_pixel(img, ox + x, y, _TOREN)
		for y in range(32, 41):
			var k := float(y - 32) / 8.0
			var half := int(round(lerpf(3.0, 9.0, k)))
			for x in range(CENTER_X - half, CENTER_X + half + 1):
				_pixel(img, ox + x, y, _DAK)
		for y in range(50, 61):
			for x in range(22, 27):
				_pixel(img, ox + x, y, _DEUR)
		var basis := float(f) * (PI / 4.0)
		for blad in 4:
			_zeil(img, ox, basis + float(blad) * (PI / 2.0))
		_pixel(img, ox + CENTER_X, CENTER_Y, _NAAF)
		_letters(img, ox)
		_stempel(img, ox)
	return img


static func _zeil(img: Image, ox: int, ang: float) -> void:
	for t in LENGTE + 1:
		var x := int(round(float(CENTER_X) + cos(ang) * float(t)))
		var y := int(round(float(CENTER_Y) + sin(ang) * float(t)))
		for dy in range(-1, 2):
			_pixel(img, ox + x, y + dy, _ZEIL)


static func _letters(img: Image, ox: int) -> void:
	var oorsprong := merk_pixel()
	for y in _PH.size():
		var rij: String = _PH[y]
		for x in rij.length():
			if rij[x] == "#":
				_pixel(img, ox + oorsprong.x + x, oorsprong.y + y, MAGENTA)


static func _stempel(img: Image, ox: int) -> void:
	for ty in range(0, FRAME_H, 16):
		for tx in range(0, FRAME_W, 16):
			for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
					Vector2i(14, 0), Vector2i(15, 0), Vector2i(14, 1), Vector2i(15, 1),
					Vector2i(0, 14), Vector2i(1, 14), Vector2i(0, 15), Vector2i(1, 15),
					Vector2i(14, 14), Vector2i(15, 14), Vector2i(14, 15), Vector2i(15, 15)]:
				_pixel(img, ox + tx + c.x, ty + c.y, MAGENTA)


static func _pixel(img: Image, x: int, y: int, kleur: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, kleur)
