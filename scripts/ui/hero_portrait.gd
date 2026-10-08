extends RefCounted
## v0.14 (RPG CODE, menu L2) EÉN hulpje voor het plaatje van een held in het veldmenu
## (Status, Uitrusting, Opslaan). Volgorde:
##   1. portret van RPG ART:  res://assets/ui/portrait_<held-id>.png  (64x80, vooraanzicht)
##   2. anders het vooraanzicht uit de loop-sheet van de held ("field_sprite" in
##      game_data.gd, 3 kolommen x 4 rijen; rij 0 = naar beneden kijken, kolom 0 = stil)
##   3. anders frame 0 ('stil') van de gevechtssprite, bijgesneden. NOOIT een rugaanzicht
##      (bestanden met '_rug' in de naam worden overgeslagen).
## Kleine plaatjes (portret, loopframe) worden met een HEEL getal vergroot en zonder
## vervaging (nearest) getekend: scherpe pixels. Het portret van 64x80 staat dus op precies
## 64x80 (of 128x160 bij 2x), nooit op een 'krom' formaat.
## Klein plaatje (Opslaan): een uitsnede van het hoofd uit het portret (MINI_CROP, 1:1, scherp);
## zonder portret het vooraanzicht-loopframe, pas daarna het gevechtsframe.
## (preload i.p.v. class_name, zoals de andere UI-hulpjes)

const PORTRAIT_SIZE := Vector2i(64, 80)
## Uitsnede (hoofd + hals) uit een portret van 64x80 voor het kleine plaatje.
const MINI_CROP := Rect2(10, 4, 44, 44)
## Gevechtssprites: strook met frames van FRAME_PX x FRAME_PX, frame 0 = 'stil'.
const FRAME_PX := 210
## Loop-sheet: 3 kolommen x 4 rijen (zelfde indeling als player.png / npc.png).
const SHEET_COLS := 3
const SHEET_ROWS := 4
const FRONT_ROW := 0
const STAND_COL := 0

## Map met de portretten. Alleen de menutest zet dit tijdelijk ergens anders heen.
static var portrait_dir := "res://assets/ui/"
static var _cache := {}


static func portrait_path(hero: Dictionary) -> String:
	return portrait_dir.path_join("portrait_%s.png" % str(hero.get("id", "")))


## Welke bron wordt gebruikt: "portrait", "front", "battle" of "" (niets).
static func source(hero: Dictionary) -> String:
	if _load_png(portrait_path(hero)) != null:
		return "portrait"
	if front_frame(hero) != null:
		return "front"
	if battle_frame(hero) != null:
		return "battle"
	return ""


## Groot plaatje (Status, Uitrusting): portret -> vooraanzicht -> gevechtsframe.
static func portrait(hero: Dictionary) -> Texture2D:
	var tex := _load_png(portrait_path(hero))
	if tex != null:
		return tex
	tex = front_frame(hero)
	return tex if tex != null else battle_frame(hero)


## Klein plaatje (Opslaan): hoofd uit het portret -> loopframe -> gevechtsframe.
## (Eerst het portret, zodat de hele groep er hetzelfde uitziet.)
static func mini_sprite(hero: Dictionary) -> Texture2D:
	var tex := portrait_crop(hero)
	if tex != null:
		return tex
	tex = front_frame(hero)
	return tex if tex != null else battle_frame(hero)


## Bron van het kleine plaatje: "front", "portrait_crop", "battle" of "".
static func mini_source(hero: Dictionary) -> String:
	if portrait_crop(hero) != null:
		return "portrait_crop"
	if front_frame(hero) != null:
		return "front"
	return "battle" if battle_frame(hero) != null else ""


## Hoofd-uitsnede uit portrait_<id>.png (1:1), of null als er geen portret is.
static func portrait_crop(hero: Dictionary) -> Texture2D:
	var path := portrait_path(hero)
	var key := "crop:" + path
	if _cache.has(key):
		return _cache[key]
	var full := _load_png(path)
	if full == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = full
	at.region = MINI_CROP if full.get_size() == Vector2(PORTRAIT_SIZE) else Rect2(Vector2.ZERO, full.get_size())
	_cache[key] = at
	return at


## Vooraanzicht (stil, naar beneden) uit de loop-sheet, of null.
static func front_frame(hero: Dictionary) -> Texture2D:
	var path := str(hero.get("field_sprite", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var key := "front:" + path
	if _cache.has(key):
		return _cache[key]
	var sheet: Texture2D = load(path)
	if sheet == null:
		return null
	var fw := sheet.get_width() / SHEET_COLS
	var fh := sheet.get_height() / SHEET_ROWS
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(STAND_COL * fw, FRONT_ROW * fh, fw, fh)
	_cache[key] = at
	return at


## Frame 0 van de gevechtssprite, bijgesneden tot de figuur (geen rugaanzicht).
static func battle_frame(hero: Dictionary) -> Texture2D:
	var path := str(hero.get("battle_sprite", ""))
	if path.get_file().contains("_rug"):
		path = path.replace("_rug", "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var key := "battle:" + path
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var frame_px := mini_i(FRAME_PX, tex.get_height())
	var region := Rect2(0, 0, frame_px, frame_px)
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var used := img.get_region(Rect2i(region)).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			region = Rect2(used)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	_cache[key] = at
	return at


static func mini_i(a: int, b: int) -> int:
	return a if a < b else b


## PNG laden: geïmporteerd (res://) of los bestand (bv. net neergezet, of user:// in de test).
static func _load_png(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_cache[path] = tex
	return tex


## Cache legen (de test wisselt tussen 'wel' en 'geen' portret).
static func clear_cache() -> void:
	_cache.clear()


## Een TextureRect die het plaatje in een vak van 'box' pixels zet: kleine plaatjes met
## een heel getal vergroot (scherp), grote passend verkleind. In een CenterContainer.
static func make_view(box: Vector2) -> CenterContainer:
	var c := CenterContainer.new()
	c.custom_minimum_size = box
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.name = "Picture"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	return c


static func view_rect(view: CenterContainer) -> TextureRect:
	return view.get_node("Picture") as TextureRect


## Plaatje in een view zetten (zie make_view). Geeft de gebruikte schaal terug.
static func show_in(view: CenterContainer, tex: Texture2D, src := "") -> float:
	var r := view_rect(view)
	r.texture = tex
	r.set_meta("source", src)
	if tex == null:
		r.custom_minimum_size = Vector2.ZERO
		return 0.0
	var box := view.custom_minimum_size
	var ts := Vector2(tex.get_width(), tex.get_height())
	var fit := minf(box.x / ts.x, box.y / ts.y)
	# Altijd een HEEL getal (1x, 2x, ...) of een hele deler (1/2, 1/3 ...) en altijd nearest:
	# zo blijven de pixels scherp, ook als een te groot plaatje in een klein vak moet.
	var scale := floorf(fit) if fit >= 1.0 else 1.0 / ceilf(1.0 / fit)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = (ts * scale).floor()
	r.set_meta("scale", scale)
	return scale


## Portret van een held in een view (bron in meta 'source', zie source()).
static func show_portrait(view: CenterContainer, hero: Dictionary) -> float:
	return show_in(view, portrait(hero), source(hero))


static func show_mini(view: CenterContainer, hero: Dictionary) -> float:
	return show_in(view, mini_sprite(hero), mini_source(hero))
