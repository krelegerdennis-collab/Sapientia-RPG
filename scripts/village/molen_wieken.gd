extends "res://scripts/story_object.gd"
class_name MolenWieken
## Molen van Gerrit op het plein van Wilgendal.
## Stil tot Het Zingende Graan klaar is. De zangscène (zing) laat de wieken draaien
## en speelt zacht gezang uit de noten in story_data. Geen extra dialoog.
## v0.21: echte art van RPG ART (assets/sprites/buiten/molen_wieken.png, 192x64 = 4 frames 48x64,
## wiek van frame f op f*45 graden). Wieken hebben 4 bladen, dus frame 0 = frame 2: alleen de
## 4 frames lopen zou als 2 beelden flikkeren. Daarom maakt wieken_sheet() er STAPPEN frames van
## 22.5 graden per stap van: even stappen = het art-frame zelf, oneven stappen = dezelfde toren met
## de wieklaag van het art-frame 22.5 graden gedraaid om de naaf (4x4 sub-samples, meeste kleur).

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
const ART := "res://assets/sprites/buiten/molen_wieken.png"
## v0.21: draaistappen voor een vloeiende draai: 22.5 graden per stap, 8 stappen = halve slag.
const STAP_GRADEN := 22.5
const STAPPEN := 8
const STAP_TIJD := 0.12
const _SUB := 4
const _NOOT := Color(0.95, 0.86, 0.62, 1.0)

static var _sheet: ImageTexture
static var _noot: ImageTexture

var gezongen := false
var noten := 0
var laatste_zang: AudioStreamWAV
var _zang: AudioStreamPlayer


func _ready() -> void:
	var sheet := wieken_sheet()
	texture = sheet
	loop_texture = sheet
	hframes = STAPPEN
	loop_frames = STAPPEN
	loop_time = STAP_TIJD
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


## Draaisheet: STAPPEN frames van 48x64, stap k = wiek op k * STAP_GRADEN.
static func wieken_sheet() -> ImageTexture:
	if _sheet == null:
		_sheet = ImageTexture.create_from_image(maak_stappen(art_image()))
	return _sheet


## Het art-bestand (4 frames) als RGBA8-plaatje.
static func art_image() -> Image:
	var tex: Texture2D = load(ART)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


static func hoek_van_stap(stap: int) -> float:
	return float(stap) * STAP_GRADEN


static func maak_stappen(art: Image) -> Image:
	var out := Image.create(FRAME_W * STAPPEN, FRAME_H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var f0 := art.get_region(Rect2i(0, 0, FRAME_W, FRAME_H))
	var f1 := art.get_region(Rect2i(FRAME_W, 0, FRAME_W, FRAME_H))
	var lagen := _splits(f0, f1)
	var achter: Image = lagen[0]
	var wiek: Image = lagen[1]
	for k in STAPPEN:
		var frame: Image
		if k % 2 == 0:
			var f := (k / 2) % FRAMES
			frame = art.get_region(Rect2i(f * FRAME_W, 0, FRAME_W, FRAME_H))
		else:
			frame = _draai(achter, wiek, deg_to_rad(hoek_van_stap(k)))
		out.blit_rect(frame, Rect2i(0, 0, FRAME_W, FRAME_H), Vector2i(k * FRAME_W, 0))
	return out


static func _wiek_kleur(c: Color) -> bool:
	if c.a < 0.5:
		return false
	var h := c.to_html(false)
	return h == "c8b88c" or h == "4a3424" or h == "6a4c32"


static func _is_wiek(a: Color, b: Color, x: int, y: int) -> bool:
	if Vector2(x - CENTER_X, y - CENTER_Y).length() > float(LENGTE) + 2.5:
		return false
	if a.is_equal_approx(b):
		return _wiek_kleur(a) and not (x == CENTER_X and y == CENTER_Y)
	if _wiek_kleur(a):
		return true
	if _wiek_kleur(b):
		return false
	return a.a > 0.5 and a.to_html(false) == "100e14"


## [achtergrond zonder wieken, wieklaag van frame 0] uit art-frames 0 (0 graden) en 1 (45 graden).
static func _splits(f0: Image, f1: Image) -> Array:
	var achter := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	var wiek := Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	achter.fill(Color(0, 0, 0, 0))
	wiek.fill(Color(0, 0, 0, 0))
	for y in FRAME_H:
		for x in FRAME_W:
			var a := f0.get_pixel(x, y)
			var b := f1.get_pixel(x, y)
			if _is_wiek(a, b, x, y):
				wiek.set_pixel(x, y, a)
				if not _is_wiek(b, a, x, y):
					achter.set_pixel(x, y, b)
			else:
				achter.set_pixel(x, y, a)
	return [achter, wiek]


static func _draai(achter: Image, wiek: Image, ang: float) -> Image:
	var img := achter.duplicate() as Image
	var c := cos(-ang)
	var s := sin(-ang)
	var drempel := int(ceil(float(_SUB * _SUB) * 0.4))
	for y in FRAME_H:
		for x in FRAME_W:
			var tel := {}
			var n := 0
			for j in _SUB:
				for i in _SUB:
					var dx := float(x) + (float(i) + 0.5) / float(_SUB) - 0.5 - float(CENTER_X)
					var dy := float(y) + (float(j) + 0.5) / float(_SUB) - 0.5 - float(CENTER_Y)
					var sx := int(round(float(CENTER_X) + dx * c - dy * s))
					var sy := int(round(float(CENTER_Y) + dx * s + dy * c))
					if sx < 0 or sy < 0 or sx >= FRAME_W or sy >= FRAME_H:
						continue
					var k := wiek.get_pixel(sx, sy)
					if k.a < 0.5:
						continue
					n += 1
					tel[k] = int(tel.get(k, 0)) + 1
			if n >= drempel:
				var beste := Color(0, 0, 0, 0)
				var top := -1
				for k in tel:
					if int(tel[k]) > top:
						top = int(tel[k])
						beste = k
				img.set_pixel(x, y, beste)
	return img


## Punt (op 3/4 van de wiek) van de eerste wiek in draaistap `stap` van wieken_sheet().
## Stap 0 wijst naar rechts.
static func zeil_punt(stap: int) -> Vector2i:
	var ang := deg_to_rad(hoek_van_stap(stap))
	var r := float(LENGTE) * 0.75
	var x := int(round(float(CENTER_X) + cos(ang) * r))
	var y := int(round(float(CENTER_Y) + sin(ang) * r))
	return Vector2i(stap * FRAME_W + x, y)


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
