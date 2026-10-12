class_name WorldWarperDestinations
extends RefCounted
## Bestemmingen van de World Warper.
## Geen scènes en geen autoload-schrijfacties: alleen data.
## De hub-scène wordt hier niet geladen. Terugreis-constanten staan klaar
## voor later; ze zijn geen keuze in dit menu.

## Zelfde pad en spawn als de hub-binnenkomst (world_warper/flow/enter.gd).
const HUB_RETURN_PATH := "res://world_warper/maps/exterieur.tscn"
const HUB_RETURN_SPAWN := "ingang"

const WM1 := "WM1"
const WM2 := "WM2"
const WM3 := "WM3"

## TODO(design): er is geen eigen warp-landing op de wereldkaart. Die scène
## mag niet gewijzigd worden. van_dorp is de bestaande betastart-spawn
## (Marker2D onder Spawns in wereldkaart.tscn).
const WORLD_MAP_SPAWN := "van_dorp"

## Dorp Wilgendal. wilgendal.tscn is het Wachtershuis, geen tweede dorp.
const WILGENDAL_PATH := "res://scenes/maps/dorp_wilgendal.tscn"
const WILGENDAL_SPAWN := "zuid_ingang"

const ESDOORN_PATH := "res://scenes/maps/esdoorn.tscn"
const ESDOORN_SPAWN := "zuid_ingang"

const PLACE_WERELDKAART := "wereldkaart"
const PLACE_WILGENDAL := "wilgendal"
const PLACE_ESDOORN := "esdoorn"


## WM1, WM2 en WM3. WM2 en WM3 hebben nog geen eilandscènes.
static func worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# TODO(design): er zijn nog geen spelersnamen voor de eilanden.
	out.append({"id": WM1, "label": "Wereld 1"})
	out.append({"id": WM2, "label": "Wereld 2"})
	out.append({"id": WM3, "label": "Wereld 3"})
	return out


## Plaatsen van één wereld. Leeg bij een onbekend id of een gesloten eiland.
static func places(wm_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if wm_id != WM1:
		return out
	out.append({
		"id": PLACE_WERELDKAART,
		"label": "Wereldkaart",
		"path": GameState.WORLD_MAP,
		"spawn": WORLD_MAP_SPAWN,
	})
	out.append({
		"id": PLACE_WILGENDAL,
		"label": "Wilgendal",
		"path": WILGENDAL_PATH,
		"spawn": WILGENDAL_SPAWN,
	})
	out.append({
		"id": PLACE_ESDOORN,
		"label": "Esdoorn",
		"path": ESDOORN_PATH,
		"spawn": ESDOORN_SPAWN,
	})
	return out


## WM1 is open. WM2 en WM3 blijven dicht: er zijn nog geen eilandscènes.
## TODO(design): unlock-vlaggen voor WM2 en WM3 bestaan nog niet.
## `flags` blijft in de handtekening tot die namen vastliggen; de inhoud telt nog niet.
static func is_world_open(wm_id: String, flags: Dictionary) -> bool:
	var _later: Dictionary = flags
	return wm_id == WM1


## Oude saves zonder bezoeklijst: de drie WM1-plekken tellen als bezocht.
static func legacy_bezocht() -> Array[String]:
	var out: Array[String] = []
	out.append(str(GameState.WORLD_MAP))
	out.append(WILGENDAL_PATH)
	out.append(ESDOORN_PATH)
	return out


## Dorp of wereldkaart op WM1: alleen als dat pad al bezocht is.
static func is_place_open(place: Dictionary, bezocht: Array) -> bool:
	var id := str(place.get("id", ""))
	if id != PLACE_WERELDKAART and id != PLACE_WILGENDAL and id != PLACE_ESDOORN:
		return true
	var path := str(place.get("path", ""))
	if path.is_empty():
		return false
	for pad in bezocht:
		if str(pad) == path:
			return true
	return false


static func huidige_bezocht() -> Array:
	if not is_instance_valid(GameState):
		return []
	var raw: Variant = GameState.get("bezochte_kaarten")
	if raw is Array:
		return raw
	return []


## Lege dictionary als de wereld dicht is, het dorp nog niet bezocht is,
## of het plaats-id niet bestaat.
static func resolve(wm_id: String, place_id: String, flags: Dictionary) -> Dictionary:
	if not is_world_open(wm_id, flags):
		return {}
	var gezien := huidige_bezocht()
	for place in places(wm_id):
		if str(place.get("id", "")) != place_id:
			continue
		if str(place.get("path", "")).is_empty() or str(place.get("spawn", "")).is_empty():
			return {}
		if not is_place_open(place, gezien):
			return {}
		return place
	return {}
