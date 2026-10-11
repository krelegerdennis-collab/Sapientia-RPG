extends RefCounted
## Zuivere checks voor de warp-bestemmingen. Geen scène en geen boom.
## Elke functie geeft de fouten terug (leeg = goed).

const Destinations := preload("res://world_warper/warp/destinations.gd")

## Spawns die in de scènes onder Spawns staan. Geen verzonnen dorp.
const ECHTE_SPAWN := {
	"res://scenes/maps/wereldkaart.tscn": "van_dorp",
	"res://scenes/maps/dorp_wilgendal.tscn": "zuid_ingang",
	"res://scenes/maps/esdoorn.tscn": "zuid_ingang",
}


static func wm2_dicht() -> PackedStringArray:
	var fouten := PackedStringArray()
	var flags := {
		"world_warper_unlocked": true,
		"bewaker:archief_v2_trapzaal/m2": true,
	}
	if Destinations.is_world_open(Destinations.WM2, {}):
		fouten.append("WM2 hoort dicht te zijn zonder vlaggen")
	if Destinations.is_world_open(Destinations.WM2, flags):
		fouten.append("WM2 hoort dicht te blijven zolang er geen eilandscène is")
	if not Destinations.places(Destinations.WM2).is_empty():
		fouten.append("WM2 hoort geen bestemmingen te hebben")
	if Destinations.is_world_open(Destinations.WM3, flags):
		fouten.append("WM3 hoort dicht te blijven")
	if not Destinations.places(Destinations.WM3).is_empty():
		fouten.append("WM3 hoort geen bestemmingen te hebben")
	if not Destinations.is_world_open(Destinations.WM1, {}):
		fouten.append("WM1 hoort open te zijn")
	if not _heeft_wereld(Destinations.WM2):
		fouten.append("WM2 hoort in de wereldenlijst te staan, ook als hij dicht is")
	return fouten


static func wm1_echte_bestemming() -> PackedStringArray:
	var fouten := PackedStringArray()
	var plaatsen: Array[Dictionary] = Destinations.places(Destinations.WM1)
	if plaatsen.is_empty():
		fouten.append("WM1 heeft geen bestemming")
		return fouten
	var echt := 0
	for place in plaatsen:
		var path := str(place.get("path", ""))
		var spawn := str(place.get("spawn", ""))
		if path == Destinations.HUB_RETURN_PATH:
			fouten.append("de hub is geen warp-bestemming")
			continue
		if path.ends_with("/wilgendal.tscn"):
			fouten.append("wilgendal.tscn is het Wachtershuis, niet Wilgendal")
			continue
		if str(ECHTE_SPAWN.get(path, "")) != spawn:
			fouten.append("geen echte scène: %s / %s" % [path, spawn])
			continue
		echt += 1
	if echt < 1:
		fouten.append("WM1 heeft geen echte bestemming")
	fouten.append_array(_eis_plaats(plaatsen, Destinations.PLACE_WERELDKAART, GameState.WORLD_MAP, "van_dorp"))
	fouten.append_array(_eis_plaats(plaatsen, Destinations.PLACE_WILGENDAL, "res://scenes/maps/dorp_wilgendal.tscn", "zuid_ingang"))
	fouten.append_array(_eis_plaats(plaatsen, Destinations.PLACE_ESDOORN, "res://scenes/maps/esdoorn.tscn", "zuid_ingang"))
	if GameState.WORLD_MAP != "res://scenes/maps/wereldkaart.tscn":
		fouten.append("GameState.WORLD_MAP wijkt af van wereldkaart.tscn")
	return fouten


static func onbekend_id_faalt() -> PackedStringArray:
	var fouten := PackedStringArray()
	if Destinations.is_world_open("onbekend", {}):
		fouten.append("onbekend wereld-id hoort te falen")
	if not Destinations.places("onbekend").is_empty():
		fouten.append("onbekend wereld-id hoort geen plaatsen te geven")
	if not Destinations.resolve(Destinations.WM1, "onbekend", {}).is_empty():
		fouten.append("onbekend plaats-id hoort te falen")
	if not Destinations.resolve("onbekend", Destinations.PLACE_WERELDKAART, {}).is_empty():
		fouten.append("een plaats op een onbekende wereld hoort te falen")
	if not Destinations.resolve(Destinations.WM2, Destinations.PLACE_ESDOORN, {}).is_empty():
		fouten.append("een plaats op WM2 hoort te falen")
	return fouten


static func _heeft_wereld(wm_id: String) -> bool:
	for wereld in Destinations.worlds():
		if str(wereld.get("id", "")) == wm_id:
			return true
	return false


static func _eis_plaats(plaatsen: Array[Dictionary], place_id: String, path: String, spawn: String) -> PackedStringArray:
	var fouten := PackedStringArray()
	for place in plaatsen:
		if str(place.get("id", "")) != place_id:
			continue
		if str(place.get("path", "")) != path or str(place.get("spawn", "")) != spawn:
			fouten.append("%s wijst niet naar %s / %s" % [place_id, path, spawn])
		return fouten
	fouten.append("WM1 mist %s" % place_id)
	return fouten
