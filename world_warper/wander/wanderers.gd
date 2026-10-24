extends Node2D
class_name WorldWarperWanderers
## Rondlopers in de World Warper-hal: party en gevangen Codex-wezens.
## Eigen spawner. Geen FieldFollower (niet extend, geen pad van de speler).
## Decoratie: geen gevecht, geen dialoog, geen botsing.
##
## Sprite: AnimatedSprite2D met 16x24-frames uit een 48x96-veldsheet (3 kol x 4 rijen: kol 0 stil,
## 1 stap A, 2 stap B; rijen omlaag, links, rechts, omhoog; WALK_CYCLE [1,0,2,0]).
##   party  -> GameData.HEROES[*].field_sprite (player.png, noor_dorp.png, lotte_veld.png),
##             onbekend lid -> world_warper/art/party.png
##   Codex  -> assets/sprites/hub/<soort>_hub.png (RPG ART batch 9), echo -> echo.png
## Geen sheet te vinden: een gekleurd vlak met de naam.
## Hub: instantieer wanderers.tscn en roep refresh() aan na een wijziging
## in de party of de Codex. Optioneel anker: Node2D of Control in de groep
## "ww_anchor_wander" (deze node zelf telt niet). Zonder anker lopen ze
## rond de oorsprong van deze node.

const Spawn := preload("res://world_warper/wander/spawn_test.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const FONT := preload("res://assets/fonts/Dauwpixel-Regular.ttf")

const ANKER_GROEP := "ww_anchor_wander"
const SNELHEID := 10.0
const AANKOMST := 1.0
const WACHT_MIN := 0.2
const WACHT_MAX := 0.7
const HUB_MAP := "res://assets/sprites/hub/%s_hub.png"
const MAP_SHEET := "res://assets/map_monsters/%s.png"
const PARTY_PLAATSHOUDER := "res://world_warper/art/party.png"
const ECHO_SHEET := "res://world_warper/art/echo.png"
const FRAME := Vector2i(16, 24)
const RICHTINGEN: Array[String] = ["omlaag", "links", "rechts", "omhoog"]
const WALK_CYCLE: Array[int] = [1, 0, 2, 0]
const LOOP_FPS := 6.0

const PARTY_KLEUREN: Array[Color] = [
	Color(0.29, 0.48, 0.86),
	Color(0.83, 0.36, 0.58),
	Color(0.28, 0.7, 0.66),
]
const CODEX_KLEUREN: Array[Color] = [
	Color(0.52, 0.78, 0.28),
	Color(0.9, 0.62, 0.2),
	Color(0.58, 0.4, 0.86),
	Color(0.86, 0.42, 0.28),
]

## Loopvlak in lokale pixels, rond deze node of rond het anker.
@export var half_breedte: float = 96.0
@export var half_hoogte: float = 52.0

## Elke loper: node (Node2D), doel (Vector2), snelheid (float), wacht (float).
var _lopers: Array[Dictionary] = []
var _anker_node: CanvasItem
## Na de eerste _process niet meer zoeken: dan is de boom compleet.
var _anker_bevroren := false
## Vaste hal-naambordjes (groep NAAM_GROEP, geen ww_loper): één keer per refresh().
var _vaste_naam_rects: Array[Rect2] = []
var _bezet_werk: Array[Rect2] = []


func _ready() -> void:
	refresh()


## Leest de party en de gevangen Codex opnieuw. Lege lijsten -> nul rondlopers.
## Muteert de party niet en roept codex_set_active niet aan.
func refresh() -> void:
	_wis()
	_anker_node = null
	_anker_bevroren = false
	# TODO(design): gevangen versus gezien.
	# De Codex-API heeft geen aparte publieke lijst "gezien" naast "gevangen".
	# Strikte lezing: alleen wat de speler echt heeft.
	#   - GameState.codex_pages  = ingeschreven pagina's (codex_add, fusie, save).
	#     Elk gevangen exemplaar is één pagina (uid). Dat zijn de rondlopers.
	#   - GameState.bestiary     = gezien / verslagen. Niet in bezit. Niet lezen.
	#   - GameState.unique_done  = "verslagen" of "gevangen" voor unieke vijanden.
	#     Zonder pagina telt dat niet als bezit. Niet lezen.
	#   - GameState.codex_active = gekozen bondgenoot (andere taak). Niet zetten,
	#     niet als filter gebruiken: élke pagina loopt, niet alleen de actieve.
	# Displaynaam = het bestaande veld "name" (party-kopie, bij de hoofdpersoon
	# al player_name). Leeg? dan GameData.HEROES / CodexData.species. Geen
	# aparte vertaling: de hal toont dezelfde naam als de rest van het spel.
	var party := _lees_party()
	var codex := _lees_codex()
	var helden: Array[Dictionary] = Spawn.descriptors(party, [])
	var wezens: Array[Dictionary] = Spawn.descriptors([], codex)
	var sheets := {}
	for lid in party:
		sheets[str(lid.get("id", ""))] = _sheet_held(str(lid.get("id", "")))
	for pagina in codex:
		var sleutel := ""
		for k in ["uid", "id", "species"]:
			if str(pagina.get(k, "")).strip_edges() != "":
				sleutel = str(pagina.get(k, "")).strip_edges()
				break
		sheets[sleutel] = _sheet_wezen(str(pagina.get("species", "")))
	var gebied := _gebied()
	for spec in helden:
		_maak(spec, true, gebied, str(sheets.get(str(spec.get("id", "")), "")))
	for spec in wezens:
		_maak(spec, false, gebied, str(sheets.get(str(spec.get("id", "")), "")))
	set_process(not _lopers.is_empty())
	_cache_vaste_naam_rects()
	schik_labels()


func _process(delta: float) -> void:
	# Alleen positie. Geen load(), geen padzoek, geen GameState.
	var gebied := _gebied()
	_anker_bevroren = true
	for loper in _lopers:
		_beweeg(loper, delta, gebied)
	schik_labels()


## Naambordjes mogen elkaar niet raken (ook niet die van vaste hal-NPC's, groep NAAM_GROEP).
## Vaste bordjes blijven staan; een loper-bordje schuift in stappen omhoog, past het nergens dan
## verbergen we het tot er weer ruimte is.
const NAAM_GROEP := "hub_naambord"
const LABEL_STAP := 10.0
func _cache_vaste_naam_rects() -> void:
	_vaste_naam_rects.clear()
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group(NAAM_GROEP):
		var c := n as Control
		if c and c.is_visible_in_tree() and not c.has_meta("ww_loper"):
			_vaste_naam_rects.append(c.get_global_rect())


func schik_labels() -> void:
	_bezet_werk.clear()
	_bezet_werk.append_array(_vaste_naam_rects)
	for loper in _lopers:
		var node: Node2D = loper["node"]
		if not is_instance_valid(node):
			continue
		var l := node.get_node_or_null("Naam") as Label
		if l == null:
			continue
		var basis: Vector2 = l.get_meta("ww_basis", l.position)
		l.set_meta("ww_basis", basis)
		l.visible = false
		for i in 4:
			l.position = basis - Vector2(0, LABEL_STAP * i)
			var r := Rect2(node.global_position + l.position * node.global_scale, l.size * node.global_scale)
			var vrij := true
			for b in _bezet_werk:
				if r.intersects(b):
					vrij = false
					break
			if vrij:
				l.visible = true
				_bezet_werk.append(r)
				break


## Alleen helden in de rustkamer (party_bench) lopen rond. De actieve party (met de leider = de
## speler zelf) nooit: anders liep er een tweede Dax door de hal (Forge, 21 okt 2026).
func _lees_party() -> Array:
	var uit: Array = []
	var actief := {}
	for lid in GameState.party:
		if lid is Dictionary:
			actief[str(lid.get("id", ""))] = true
	for lid in GameState.party_bench:
		if lid is Dictionary and actief.has(str(lid.get("id", ""))):
			continue
		if not (lid is Dictionary):
			continue
		uit.append({
			"id": lid.get("id", ""),
			"name": _naam_held(lid),
		})
	return uit


func _lees_codex() -> Array:
	var uit: Array = []
	for pagina in GameState.codex_pages:
		if not (pagina is Dictionary):
			continue
		uit.append({
			"uid": pagina.get("uid", ""),
			"id": pagina.get("id", ""),
			"species": pagina.get("species", ""),
			"name": _naam_codex(pagina),
		})
	return uit


func _naam_held(lid: Dictionary) -> String:
	var naam := str(lid.get("name", "")).strip_edges()
	if naam != "":
		return naam
	var id := str(lid.get("id", ""))
	for held in GameData.HEROES:
		if str(held.get("id", "")) == id:
			return str(held.get("name", "")).strip_edges()
	return ""


func _naam_codex(pagina: Dictionary) -> String:
	var naam := str(pagina.get("name", "")).strip_edges()
	if naam != "":
		return naam
	var soort := str(pagina.get("species", "")).strip_edges()
	if soort == "":
		return ""
	var sp: Dictionary = CodexData.species(soort)
	return str(sp.get("name", "")).strip_edges()


## Veldsheet van een held (of de party-plaatshouder).
static func _sheet_held(id: String) -> String:
	for held in GameData.HEROES:
		if str(held.get("id", "")) == id:
			var p := str(held.get("field_sprite", ""))
			if p != "" and ResourceLoader.exists(p):
				return p
	return PARTY_PLAATSHOUDER if ResourceLoader.exists(PARTY_PLAATSHOUDER) else ""


## Hub-sheet van een Codex-soort ("" = geen art, dan het placeholdervlak).
static func _sheet_wezen(soort: String) -> String:
	soort = soort.strip_edges()
	if soort == "echo":
		return ECHO_SHEET if ResourceLoader.exists(ECHO_SHEET) else ""
	if soort == "":
		return ""
	var p := HUB_MAP % soort
	if ResourceLoader.exists(p):
		return p
	# Geen hub-sheet: de kaart-sheet van het monster (32x64 = 2x4 frames van 16x16).
	p = MAP_SHEET % soort
	return p if ResourceLoader.exists(p) else ""


## SpriteFrames uit een 48x96-sheet: "stil_<richting>" (kol 0) en "loop_<richting>" (WALK_CYCLE).
static func frames_uit(tex: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var klein := tex != null and tex.get_width() == 32 and tex.get_height() == 64
	for r in RICHTINGEN.size():
		var stil := "stil_" + RICHTINGEN[r]
		var loop := "loop_" + RICHTINGEN[r]
		sf.add_animation(stil)
		sf.add_animation(loop)
		sf.set_animation_speed(loop, LOOP_FPS)
		if klein:
			sf.add_frame(stil, _frame_maat(tex, 0, r, Vector2i(16, 16)))
			for kol in [0, 1]:
				sf.add_frame(loop, _frame_maat(tex, kol, r, Vector2i(16, 16)))
			continue
		# 3x4-sheet: framemaat uit de sheet (48x96 -> 16x24, 72x128 -> 24x32 zoals Kael/Orion)
		var maat := FRAME
		if tex != null and tex.get_width() % 3 == 0 and tex.get_height() % 4 == 0:
			maat = Vector2i(tex.get_width() / 3, tex.get_height() / 4)
		sf.add_frame(stil, _frame_maat(tex, 0, r, maat))
		for kol in WALK_CYCLE:
			sf.add_frame(loop, _frame_maat(tex, kol, r, maat))
	return sf


static func _frame_maat(tex: Texture2D, kol: int, rij: int, maat: Vector2i) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(kol * maat.x, rij * maat.y, maat.x, maat.y)
	return a


static func _frame(tex: Texture2D, kol: int, rij: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(kol * FRAME.x, rij * FRAME.y, FRAME.x, FRAME.y)
	return a


func _maak(spec: Dictionary, party: bool, gebied: Rect2, sheet := "") -> void:
	var id := str(spec.get("id", ""))
	var naam := str(spec.get("naam", ""))
	var wortel := Node2D.new()
	wortel.name = _node_naam(id, _lopers.size())
	wortel.set_meta("ww_id", id)
	wortel.set_meta("ww_naam", naam)
	var tex: Texture2D = load(sheet) as Texture2D if sheet != "" else null
	if tex != null:
		var anim := AnimatedSprite2D.new()
		anim.name = "Sprite"
		anim.sprite_frames = frames_uit(tex)
		anim.offset = Vector2(0, -8 if tex.get_height() == 64 and tex.get_width() == 32 else -12)     # voeten op de oorsprong
		anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim.play("stil_omlaag")
		wortel.add_child(anim)
		wortel.set_meta("ww_sheet", sheet)
		wortel.add_child(_label(naam, Vector2(-36, -34), Color(0.95, 0.94, 0.88)))
	else:
		wortel.add_child(_vlak(id, party))
		wortel.add_child(_label(naam, Vector2(-28, -26), Color(0.95, 0.94, 0.88)))
	add_child(wortel)
	var start := _punt_in(gebied, Vector2.ZERO)
	wortel.position = start
	_lopers.append({
		"node": wortel,
		"snelheid": SNELHEID * (0.8 + float(_lopers.size() % 5) * 0.08),
		"wacht": 0.0,
		"doel": _punt_in(gebied, start),
	})


func _vlak(id: String, party: bool) -> ColorRect:
	var rand := ColorRect.new()
	rand.color = Color(1.0, 0.15, 0.72)
	rand.position = Vector2(-8, -16)
	rand.size = Vector2(16, 18)
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vul := ColorRect.new()
	vul.color = _kleur(id, party)
	vul.position = Vector2(1, 1)
	vul.size = Vector2(14, 16)
	vul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rand.add_child(vul)
	return rand


func _label(tekst: String, pos: Vector2, kleur: Color) -> Label:
	var l := Label.new()
	l.name = "Naam"
	l.add_to_group(NAAM_GROEP)
	l.set_meta("ww_loper", true)
	l.text = tekst
	l.position = pos
	l.size = Vector2(72, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 10)  # Dauwpixel is 1:1 op 10; op 8 vallen pixelkolommen weg (W leek V)
	l.add_theme_color_override("font_color", kleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return l


func _kleur(id: String, party: bool) -> Color:
	var palet: Array[Color] = PARTY_KLEUREN if party else CODEX_KLEUREN
	return palet[posmod(id.hash(), palet.size())]


func _beweeg(loper: Dictionary, delta: float, gebied: Rect2) -> void:
	var node: Node2D = loper["node"]
	if not is_instance_valid(node):
		return
	var wacht := float(loper["wacht"])
	if wacht > 0.0:
		loper["wacht"] = maxf(0.0, wacht - delta)
		_anim(node, Vector2.ZERO)
		return
	var doel: Vector2 = loper["doel"]
	if not gebied.has_point(doel):
		doel = _punt_in(gebied, node.position)
		loper["doel"] = doel
	var pos := node.position
	var naar := doel - pos
	var afstand := naar.length()
	if afstand <= AANKOMST:
		node.position = doel
		loper["wacht"] = randf_range(WACHT_MIN, WACHT_MAX)
		loper["doel"] = _punt_in(gebied, node.position)
		return
	# Float-positie bewust niet afronden: 10 px/s zou anders blijven steken.
	var stap := minf(float(loper["snelheid"]) * delta, afstand)
	node.position = pos + naar * (stap / afstand)
	_anim(node, naar)


## Loop- of stilstaande animatie in de looprichting (stil = laatste richting houden).
func _anim(node: Node2D, naar: Vector2) -> void:
	var a := node.get_node_or_null("Sprite") as AnimatedSprite2D
	if a == null:
		return
	var richting := str(node.get_meta("ww_richting", "omlaag"))
	if naar != Vector2.ZERO:
		if absf(naar.x) > absf(naar.y):
			richting = "rechts" if naar.x > 0.0 else "links"
		else:
			richting = "omlaag" if naar.y > 0.0 else "omhoog"
		node.set_meta("ww_richting", richting)
	var naam := ("loop_" if naar != Vector2.ZERO else "stil_") + richting
	if a.animation != naam:
		a.play(naam)


func _gebied() -> Rect2:
	var half := Vector2(maxf(8.0, half_breedte), maxf(8.0, half_hoogte))
	var midden := Vector2.ZERO
	var anker := _anker()
	if anker != null:
		midden = to_local(anker.global_position)
	return Rect2(midden - half, half * 2.0)


func _anker() -> CanvasItem:
	if _anker_node != null and is_instance_valid(_anker_node) and _anker_node.is_in_group(ANKER_GROEP):
		return _anker_node
	_anker_node = null
	if _anker_bevroren or not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group(ANKER_GROEP):
		if n is CanvasItem and n != self and is_instance_valid(n):
			_anker_node = n
			return _anker_node
	return null


func _punt_in(gebied: Rect2, van: Vector2) -> Vector2:
	if gebied.size.x <= 1.0 or gebied.size.y <= 1.0:
		return gebied.position
	var doel := gebied.position
	for _poging in 4:
		doel = Vector2(
			randf_range(gebied.position.x, gebied.position.x + gebied.size.x),
			randf_range(gebied.position.y, gebied.position.y + gebied.size.y)
		)
		if doel.distance_to(van) >= 12.0:
			return doel
	return doel


func _wis() -> void:
	for loper in _lopers:
		var n: Node = loper["node"]
		if n != null and is_instance_valid(n):
			if n.get_parent() == self:
				remove_child(n)
			n.queue_free()
	_lopers.clear()


func _node_naam(id: String, index: int) -> String:
	var veilig := ""
	for c in id:
		var ch := str(c)
		var letter := (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z")
		var cijfer := ch >= "0" and ch <= "9"
		veilig += ch if letter or cijfer or ch == "_" else "_"
	if veilig == "":
		veilig = "x"
	return "Loper_%d_%s" % [index, veilig]
