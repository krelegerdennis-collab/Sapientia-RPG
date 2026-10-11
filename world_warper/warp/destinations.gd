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


## Lege dictionary als de wereld dicht is of het plaats-id niet bestaat.
static func resolve(wm_id: String, place_id: String, flags: Dictionary) -> Dictionary:
	if not is_world_open(wm_id, flags):
		return {}
	for place in places(wm_id):
		if str(place.get("id", "")) != place_id:
			continue
		if str(place.get("path", "")).is_empty() or str(place.get("spawn", "")).is_empty():
			return {}
		return place
	return {}
