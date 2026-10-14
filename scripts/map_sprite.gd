extends RefCounted
class_name MapSprite
## Kaartsprites van spelers en NPC's in twee maten (SoM-stijl, Dennis 14 okt 2026):
## - oud: 16x24 per frame (sheet 48x96 = 3 loopframes x 4 richtingen)
## - nieuw: 24x32 per frame (sheet 72x128, zelfde indeling)
## Het raster blijft 16 px. De node staat op het midden van zijn tegel; de voeten (onderrand van het
## frame) staan altijd op de onderrand van die tegel (+8 px), zodat de botsing 14x14 aan de voeten
## blijft en de y-sort (op de node-positie) voor beide maten gelijk werkt.
## Eén los frame (bv. dax_24x32_v3.png) mag ook: dan is er geen loop- of richtingsanimatie.

const OUD := Vector2i(16, 24)
const NIEUW := Vector2i(24, 32)
const KOLOMMEN := 3
const RIJEN := 4
const TEGEL := 16


## Framemaat van een sheet: 3x4-raster, of één los frame als het niet in een raster past.
static func frame_maat(tex: Texture2D) -> Vector2i:
	if tex == null:
		return OUD
	var w := tex.get_width()
	var h := tex.get_height()
	if w % KOLOMMEN == 0 and h % RIJEN == 0:
		return Vector2i(w / KOLOMMEN, h / RIJEN)
	return Vector2i(w, h)


## Is dit een nieuwe 24x32-sprite (sheet van 3x4 of één los frame)?
static func is_nieuw(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var w := tex.get_width()
	var h := tex.get_height()
	return Vector2i(w, h) == NIEUW or Vector2i(w, h) == NIEUW * Vector2i(KOLOMMEN, RIJEN)


## Verticale offset zodat de onderrand van het frame op de voeten (+8) staat.
static func voet_offset(frame: Vector2i) -> Vector2:
	return Vector2(0, TEGEL / 2.0 - frame.y / 2.0)


## Zet hframes/vframes/offset op de sprite.
## maat = ZERO (standaard): alleen 24x32-sprites worden aangepast; oude sheets blijven precies zoals de
## scène ze zet (geen zichtbare wijziging). Een expliciete maat geldt altijd.
static func pas_toe(sprite: Sprite2D, maat := Vector2i.ZERO) -> Vector2i:
	if sprite == null or sprite.texture == null:
		return OUD
	var tex := sprite.texture
	var f := maat
	if f == Vector2i.ZERO:
		if not is_nieuw(tex):
			return Vector2i(tex.get_width() / maxi(1, sprite.hframes), tex.get_height() / maxi(1, sprite.vframes))
		f = NIEUW
	sprite.centered = true
	sprite.hframes = maxi(1, tex.get_width() / f.x)
	sprite.vframes = maxi(1, tex.get_height() / f.y)
	sprite.offset = voet_offset(f)
	return f


## Veilig frame kiezen: richting-rij en loopkolom, of 0 bij één los frame.
static func zet_frame(sprite: Sprite2D, rij: int, kolom: int) -> void:
	if sprite == null:
		return
	if sprite.vframes < RIJEN or sprite.hframes < KOLOMMEN:
		sprite.frame = 0
		return
	sprite.frame = rij * sprite.hframes + kolom
