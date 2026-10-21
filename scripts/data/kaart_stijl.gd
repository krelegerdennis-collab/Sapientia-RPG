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
## anders <pad> zelf. <pad>_<npc_variant>_v2.png (fix-versie) gaat voor als die bestaat.
## Zo blijven handwerk-sheets staan en wijst de kaart naar de slanke versie.
static func npc_sheet_pad(pad: String) -> String:
	var v := str(config().get("npc_variant", ""))
	if v == "" or pad == "" or not pad.ends_with(".png") or pad.get_file().contains("_" + v):
		return pad
	var slank := pad.get_basename() + "_" + v + ".png"
	# Een gecorrigeerde versie (<pad>_<v>_v2.png) gaat voor, want de eerste slanke sheet kan handwerk zijn.
	var v2 := pad.get_basename() + "_" + v + "_v2.png"
	if ResourceLoader.exists(v2):
		return v2
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


## Held 24x32 (Forge, 21 okt 2026): los van de SoM-tilesets. Op elke map behalve deze de 24x32-sheet van
## de partijleider; daar blijft de oude 16x24 player.png (wereldkaart = kleine kaart, bouwplaats = eigen schaal).
const HELD_OUD_MAPS: Array[String] = ["wereldkaart", "berggrot_bouwplaats"]
const HELDEN := "res://assets/sprites/som/kaart/"
## Volgorde: slanke WM1-sheet, WM1-sheet, sheet zonder variant.
const HELD_VARIANTEN: Array[String] = ["_wm1_slim", "_wm1", ""]
## Vaste partijsheets (RPG ART, 21 okt 2026): Seren en Vesper gebruiken de goedgekeurde final_trio-sheets,
## niet de _slim-varianten (die zijn voor de veld-NPC's Lotte/Noor zonder staf).
const HELD_VAST := {"seren": "res://assets/sprites/som/kaart/seren_wm1.png", "vesper": "res://assets/sprites/som/kaart/vesper.png"}


## Toont deze map de held in 24x32?
static func held_nieuw_op(pad: String) -> bool:
	return pad != "" and not HELD_OUD_MAPS.has(pad.get_file().get_basename())


## 24x32-sheet voor een heldnaam ("Dax" -> dax_wm1_slim.png); "" = geen sheet (oude 16x24 blijft).
static func held_sheet(naam: String) -> String:
	var n := naam.to_lower().get_slice(" ", 0)
	if n == "":
		return ""
	if HELD_VAST.has(n) and ResourceLoader.exists(str(HELD_VAST[n])):
		return str(HELD_VAST[n])
	for v in HELD_VARIANTEN:
		var p := HELDEN + n + v + ".png"
		if ResourceLoader.exists(p):
			return p
	return ""


## Sheet van de huidige partijleider (GameState.party[0]); Dax als er geen party is.
static func leider_sheet() -> String:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or (gs.party as Array).is_empty():
		return held_sheet("Dax")
	return held_sheet(str((gs.party[0] as Dictionary).get("name", "")))


## Zet de 24x32-sheet van de leider op de speler van deze map (offset (0,-8), botsing blijft 14x14).
static func held_toepassen(map: Node) -> bool:
	if map == null or not held_nieuw_op(str(map.scene_file_path)):
		return false
	var p := map.get_node_or_null("Objects/Player")
	var sheet := leider_sheet()
	if p == null or sheet == "" or not p.has_method("zet_sheet"):
		return false
	p.zet_sheet(load(sheet))
	return true


## Na een leiderwissel (molen) de speler op de huidige map bijwerken.
static func ververs_held() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null:
		held_toepassen(tree.current_scene)


## Op een geladen map toepassen (map.gd _ready): eerst de held (elke map, los van de stijl), daarna in
## SoM-gebieden de tileset. In de oude stijl verandert er aan de grond niets.
static func toepassen(map: Node) -> bool:
	held_toepassen(map)
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
