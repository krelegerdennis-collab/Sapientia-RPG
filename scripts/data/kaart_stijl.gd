extends RefCounted
class_name KaartStijl
## Stijl per gebied: "oud" (huidige art) of "som" (Secret of Mana-stijl, 16px raster, 24x32 figuren,
## slot-tilesets met een palet per gebied). Nooit half: een "som"-gebied waarvan een tileset of de
## spelersprite ontbreekt, valt als geheel terug op "oud" (zie bruikbaar()).
## Config: res://assets/tilesets/som/gebieden.json (gemaakt/bijgewerkt door tools/som/export_tilesets.py).

const OUD := "oud"
const SOM := "som"
const CONFIG := "res://assets/tilesets/som/gebieden.json"
const MAP := "res://assets/tilesets/som/"

static var _cfg: Dictionary = {}
static var _geladen := false


static func config() -> Dictionary:
	if not _geladen:
		_geladen = true
		_cfg = {}
		if FileAccess.file_exists(CONFIG):
			var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
			if data is Dictionary:
				_cfg = data
	return _cfg


## Alleen voor tests: een andere config gebruiken (leeg = opnieuw laden van schijf).
static func zet_config(cfg: Dictionary) -> void:
	_cfg = cfg
	_geladen = not cfg.is_empty()


static func gebieden() -> Dictionary:
	return config().get("gebieden", {})


## NPC-sheet in de WM1-variant (20 okt 2026): <pad>.png -> <pad>_<npc_variant>.png als die bestaat,
## anders <pad> zelf. Zo blijven handwerk-sheets staan en wijst de kaart naar de slanke versie.
static func npc_sheet_pad(pad: String) -> String:
	var v := str(config().get("npc_variant", ""))
	if v == "" or pad == "" or not pad.ends_with(".png") or pad.ends_with("_" + v + ".png"):
		return pad
	var slank := pad.get_basename() + "_" + v + ".png"
	return slank if ResourceLoader.exists(slank) else pad


## Gebied van een map (bestandsnaam zonder .tscn), of "" als de map bij geen gebied hoort.
static func gebied_van_map(pad: String) -> String:
	var naam := pad.get_file().get_basename()
	for id in gebieden():
		if (gebieden()[id].get("maps", []) as Array).has(naam):
			return str(id)
	return ""


static func tileset_pad(gebied: String, set_naam: String) -> String:
	return str(config().get("map", MAP)).trim_suffix("/") + "/" + gebied + "/" + set_naam + ".tres"


## Wat ontbreekt er om dit gebied in SoM-stijl te tonen? Leeg = alles is er.
static func ontbreekt(gebied: String) -> Array[String]:
	var uit: Array[String] = []
	var g: Dictionary = gebieden().get(gebied, {})
	for s in g.get("tilesets", []):
		var p := tileset_pad(gebied, str(s))
		if not ResourceLoader.exists(p):
			uit.append(p)
	var speler := str(g.get("speler", ""))
	if speler != "" and not ResourceLoader.exists(speler):
		uit.append(speler)
	return uit


## Gevraagde stijl uit de config (zonder te kijken of de art er is).
static func gevraagd(gebied: String) -> String:
	if gebied == "":
		return str(config().get("standaard", OUD))
	return str(gebieden().get(gebied, {}).get("stijl", config().get("standaard", OUD)))


## Echte stijl: "som" alleen als het gebied het vraagt én alles er is; anders het hele gebied "oud".
static func stijl(gebied: String) -> String:
	if gevraagd(gebied) != SOM:
		return OUD
	return SOM if ontbreekt(gebied).is_empty() else OUD


static func stijl_van_map(pad: String) -> String:
	return stijl(gebied_van_map(pad))


static func is_som(pad: String) -> bool:
	return stijl_van_map(pad) == SOM


## Op een geladen map toepassen (map.gd _ready). In de oude stijl gebeurt er niets.
## SoM: Ground krijgt de eerste tileset van het gebied, de speler zijn 24x32-sprite.
static func toepassen(map: Node) -> bool:
	var pad := str(map.scene_file_path)
	if not is_som(pad):
		return false
	var gebied := gebied_van_map(pad)
	if gevraagd(gebied) == SOM and not ontbreekt(gebied).is_empty():
		push_warning("SoM-stijl voor %s onvolledig, blijft oud: %s" % [gebied, ontbreekt(gebied)])
		return false
	var g: Dictionary = gebieden()[gebied]
	var sets: Array = g.get("tilesets", [])
	var ground := map.get_node_or_null("Ground") as TileMapLayer
	# Een grondscript dat zelf SoM tekent (meta "som_klaar", bv. dorp_ground.gd) niet overschrijven.
	if ground != null and not sets.is_empty() and not ground.has_meta("som_klaar"):
		ground.tile_set = load(tileset_pad(gebied, str(sets[0])))
	var speler := speler_sheet(gebied)
	var p := map.get_node_or_null("Objects/Player")
	if p != null and speler != "" and p.has_method("zet_sheet"):
		p.zet_sheet(load(speler))
	return true


## Kaartsprite van de partijleider: <helden>/<voornaam>_<held_variant>.png als die er is (WM1: dax, seren),
## anders <helden>/<voornaam>.png (vesper, kael, orion), anders <helden>/<voornaam>_wm1.png (dax, seren),
## anders "speler" uit de config. WM2 staat in de wacht (wacht/wm2/, Dennis 20 okt 2026).
static func speler_sheet(gebied: String) -> String:
	var g: Dictionary = gebieden().get(gebied, {})
	var map_ := str(g.get("helden", ""))
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if map_ != "" and gs != null and not (gs.party as Array).is_empty():
		var naam := str((gs.party[0] as Dictionary).get("name", "")).to_lower().get_slice(" ", 0)
		var basis := map_.trim_suffix("/") + "/" + naam
		var variant := str(g.get("held_variant", ""))
		if naam != "" and variant != "" and ResourceLoader.exists(basis + "_" + variant + ".png"):
			return basis + "_" + variant + ".png"
		if naam != "" and ResourceLoader.exists(basis + ".png"):
			return basis + ".png"
		# 20 okt 2026: WM2 in de wacht, dus WM1 als terugval (dax.png/seren.png bestaan niet)
		if naam != "" and ResourceLoader.exists(basis + "_wm1.png"):
			return basis + "_wm1.png"
	return str(g.get("speler", ""))
