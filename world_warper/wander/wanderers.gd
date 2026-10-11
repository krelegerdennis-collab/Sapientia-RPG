extends Node2D
class_name WorldWarperWanderers
## Rondlopers in de World Warper-hal: party en gevangen Codex-wezens.
## Eigen spawner. Geen FieldFollower (niet extend, geen pad van de speler).
## Decoratie: geen gevecht, geen dialoog, geen botsing.
##
## Placeholder: gekleurd vlak + displaynaam + de tekst PLACEHOLDER. Geen PNG.
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
const PLAATS := "PLACEHOLDER"

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
	var helden: Array[Dictionary] = Spawn.descriptors(_lees_party(), [])
	var wezens: Array[Dictionary] = Spawn.descriptors([], _lees_codex())
	var gebied := _gebied()
	for spec in helden:
		_maak(spec, true, gebied)
	for spec in wezens:
		_maak(spec, false, gebied)
	set_process(not _lopers.is_empty())


func _process(delta: float) -> void:
	# Alleen positie. Geen load(), geen padzoek, geen GameState.
	var gebied := _gebied()
	_anker_bevroren = true
	for loper in _lopers:
		_beweeg(loper, delta, gebied)


func _lees_party() -> Array:
	var uit: Array = []
	for lid in GameState.party:
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


func _maak(spec: Dictionary, party: bool, gebied: Rect2) -> void:
	var id := str(spec.get("id", ""))
	var naam := str(spec.get("naam", ""))
	var wortel := Node2D.new()
	wortel.name = _node_naam(id, _lopers.size())
	wortel.set_meta("ww_id", id)
	wortel.set_meta("ww_naam", naam)
	wortel.add_child(_vlak(id, party))
	wortel.add_child(_label(naam, Vector2(-28, -26), Color(0.95, 0.94, 0.88)))
	wortel.add_child(_label(PLAATS, Vector2(-36, 2), Color(1.0, 0.25, 0.72)))
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
	l.text = tekst
	l.position = pos
	l.size = Vector2(72, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 8)
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
