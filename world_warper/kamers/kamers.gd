class_name WarperKamers
extends RefCounted
## Extra kamers van de World Warper. Data only: de scènes staan ernaast.
## De bestaande hub (world_warper/maps: Hal, hanger-nis, Sapientia-schot)
## wordt hier niet vervangen en niet nagebouwd.
##
## TODO(design): Archief 2 heeft nog geen kern-vlag (geen baas, geen kernfragment).
## hub_open() telt die vlag mee zodra ARCHIEF2_KERN_VLAG een naam heeft.
## Tot die tijd gaan de kamers open met warper_hub_open, of zodra de World Warper
## zelf open is (na De Genezer). Anders blijft ECHO's Kamer dicht en is de
## ingang van de Diepe Grot onbereikbaar.
## Handelskamer: winkel "handelskamer" in shop_data.gd (zelfde ShopScreen als Wilgendal).
## Werkplaats: recepten in scripts/data/werkplaats_recepten.gd (scherm: scripts/ui/werkplaats_scherm.gd).

const GameData := preload("res://scripts/data/game_data.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const ShopData := preload("res://scripts/data/shop_data.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const Recepten := preload("res://scripts/data/werkplaats_recepten.gd")

const FLAG_HUB := "warper_hub_open"
## Leeg tot Archief 2 een kern-vlag heeft. Geen verzonnen naam.
const ARCHIEF2_KERN_VLAG := ""

const GESLOTEN := "This room is still closed."
const ECHO_REGELS: Array[String] = ["I operate this hub."]
const WERK_REGELS: Array[String] = [Recepten.LEEG]
const HANDEL_DICHT := "The shop is still closed."
const KERN_ZIN := "The story of H-6 ends here."
const OEFEN_KLAAR := "Practice done. No loot."
const OEFEN_VERLIES := "The practice is over. You are back in the room."
const OEFEN_VANGEN := "Nothing is recorded in a practice."
const GEGENEZEN := "The party is healed."
const OPGESLAGEN := "Saved."
const OPSLAAN_MISLUKT := "Save failed."
const NIEMAND_WISSEL := "There is nobody to swap with."
const AL_VOORAAN := "They are already at the front."
const VOORAAN := "In front: %s."
const GEEN_SCHERM := "That screen doesn't exist yet."
const GEEN_POORT := "The gate doesn't work."

const OEFEN_VIJAND := "mosslijm"

const ART_ECHO := "res://world_warper/art/echo.png"
const ART_PC := "res://world_warper/art/pc.png"
const ART_WARP := "res://world_warper/art/warp_platform.png"
const ART_TAFEL := "res://world_warper/art/tafel.png"
const ART_TOONBANK := "res://world_warper/art/toonbank.png"
const ART_PARTY := "res://world_warper/art/party.png"
const ART_BORD := "res://world_warper/art/bord_kamers.png"

const WARP_PAD := "res://scenes/maps/wereldkaart.tscn"
const WARP_SPAWN := "van_wilgendal"

const HAL := """
###D####D###
#..........#
#..........#
#..........#
D..........D
#..........#
#..........#
#..........#
#..........#
###D##D##D##
"""
const KAMER_OOST := """
##########
#........#
#........#
#........D
#........#
#........#
#........#
##########
"""
const KAMER_WEST := """
##########
#........#
#........#
D........#
#........#
#........#
#........#
##########
"""
const KAMER_ZUID := """
##########
#........#
#........#
#........#
#........#
#........#
#........#
####D#####
"""
const KAMER_NOORD := """
####D#####
#........#
#........#
#........#
#........#
#........#
#........#
##########
"""

const ROOMS := {
	"hal": {"naam": "The Atrium", "min_act": 1, "layout": HAL,
		"scene": "res://world_warper/kamers/hal.tscn"},
	"rustkamer": {"naam": "The Rest Room", "min_act": 1, "layout": KAMER_OOST,
		"scene": "res://world_warper/kamers/rustkamer.tscn"},
	"echo_kamer": {"naam": "ECHO's Chamber", "min_act": 1, "layout": KAMER_WEST,
		"scene": "res://world_warper/kamers/echo_kamer.tscn"},
	"beeldkamer": {"naam": "The Screening Room", "min_act": 2, "layout": KAMER_ZUID,
		"scene": "res://world_warper/kamers/beeldkamer.tscn"},
	"trainingshal": {"naam": "The Training Hall", "min_act": 3, "layout": KAMER_ZUID,
		"scene": "res://world_warper/kamers/trainingshal.tscn"},
	"werkplaats": {"naam": "The Workshop", "min_act": 4, "layout": KAMER_NOORD,
		"scene": "res://world_warper/kamers/werkplaats.tscn"},
	"handelskamer": {"naam": "The Exchange", "min_act": 5, "layout": KAMER_NOORD,
		"scene": "res://world_warper/kamers/handelskamer.tscn"},
	"kern": {"naam": "The Core", "min_act": 6, "layout": KAMER_NOORD,
		"scene": "res://world_warper/kamers/kern.tscn"},
}

const DEUREN := {
	"hal": ["beeldkamer", "trainingshal", "rustkamer", "echo_kamer", "werkplaats", "kern", "handelskamer"],
	"rustkamer": ["hal"],
	"echo_kamer": ["hal"],
	"beeldkamer": ["hal"],
	"trainingshal": ["hal"],
	"werkplaats": ["hal"],
	"handelskamer": ["hal"],
	"kern": ["hal"],
}

## Data staat in scripts/data/werkplaats_recepten.gd.
const RECEPTEN: Array = Recepten.RECEPTEN
const HANDEL_WINKEL := "handelskamer"


static func hub_open(flags: Dictionary) -> bool:
	if flags.has(FLAG_HUB):
		return true
	if ARCHIEF2_KERN_VLAG != "" and flags.has(ARCHIEF2_KERN_VLAG):
		return true
	return Unlock.should_unlock(flags)


## Act zoals de winkels: hoogste level in de party, banden uit level_scale (act 2 = level 14).
static func huidige_act(party: Array) -> int:
	var lv := 1
	var gezien := false
	for h in party:
		if h is Dictionary:
			gezien = true
			lv = maxi(lv, int((h as Dictionary).get("level", 1)))
	if not gezien:
		return 1
	return maxi(1, GameData.act_for_level(lv))


static func is_open(room_id: String, flags: Dictionary, party: Array) -> bool:
	if not hub_open(flags):
		return false
	if not ROOMS.has(room_id):
		return false
	return huidige_act(party) >= int(ROOMS[room_id]["min_act"])


static func naam(room_id: String) -> String:
	if not ROOMS.has(room_id):
		return ""
	return str(ROOMS[room_id]["naam"])


static func scene_path(room_id: String) -> String:
	if not ROOMS.has(room_id):
		return ""
	return str(ROOMS[room_id]["scene"])


static func deuren(room_id: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = DEUREN.get(room_id, [])
	if raw is Array:
		for id in raw:
			out.append(str(id))
	return out


static func rijen(room_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not ROOMS.has(room_id):
		return out
	for line in str(ROOMS[room_id]["layout"]).split("\n"):
		var s := line.strip_edges()
		if s != "":
			out.append(s)
	return out


static func tegel(teken: String) -> Vector2i:
	if teken == "#":
		return Vector2i(2, 0)
	if teken == "D":
		return Vector2i(4, 0)
	return Vector2i(0, 0)


## Alleen de wereldkaart bij Wilgendal. Geen WM2 en geen WM3.
static func warp_doelen() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({
		"id": "wilgendal",
		"label": "World Map near Willowdale",
		"path": WARP_PAD,
		"spawn": WARP_SPAWN,
	})
	return out


static func warp_doel() -> Dictionary:
	var alle := warp_doelen()
	if alle.is_empty():
		return {}
	return alle[0]


static func helen(party: Array) -> void:
	for h in party:
		if h is Dictionary:
			var held := h as Dictionary
			held["hp"] = int(held.get("max_hp", held.get("hp", 0)))
			held["mp"] = int(held.get("max_mp", held.get("mp", 0)))


static func wissel(party: Array, a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= party.size() or b >= party.size():
		return false
	var tmp: Variant = party[a]
	party[a] = party[b]
	party[b] = tmp
	return true


static func naar_voren(party: Array, index: int) -> bool:
	return wissel(party, 0, index)


## Wat het spel al bijhoudt: stapnaam, lopende opdracht, aantal vlaggen. Geen nieuw plot.
static func voortgang_regels(step: int, flags: Dictionary, opdracht: String) -> Array[String]:
	var stapnaam := str(StoryData.STEP_NAMES.get(step, str(step)))
	var regels: Array[String] = []
	regels.append("Story step: %s." % stapnaam)
	if opdracht == "":
		regels.append("There is no active quest right now.")
	else:
		regels.append("Current quest: %s" % opdracht)
	regels.append("Known flags: %d." % flags.size())
	return regels


static func scherm_pad(welk: String) -> String:
	match welk:
		"bestiarium":
			return "res://scripts/ui/bestiary_screen.gd"
		"codex":
			return "res://scripts/ui/codex_screen.gd"
		_:
			return ""


static func scherm_beschikbaar(welk: String) -> bool:
	var pad := scherm_pad(welk)
	return pad != "" and ResourceLoader.exists(pad)


static func oefen_groep() -> Array:
	return [OEFEN_VIJAND]


## De Trainingshal geeft nooit buit. Een gewoon gevecht gaat niet via deze functie.
static func geeft_buit() -> bool:
	return false


## practice: de cijfers van het monster tellen niet. Anders blijven ze staan (geen training).
static func toegepaste_buit(practice: bool, exp: int, gold: int) -> Vector2i:
	if practice:
		return Vector2i.ZERO
	return Vector2i(exp, gold)


static func pas_buit_toe(practice: bool, gold: int, exp: int, inventory: Dictionary, enemy_gold: int, enemy_exp: int, items: Array) -> Dictionary:
	var buit := toegepaste_buit(practice, enemy_exp, enemy_gold)
	var zak: Dictionary = inventory.duplicate()
	if not practice:
		for id in items:
			var sleutel := str(id)
			zak[sleutel] = int(zak.get(sleutel, 0)) + 1
	return {"gold": gold + buit.y, "exp": exp + buit.x, "items": zak}


## De winkel van de Handelskamer (shop_data.gd). Leeg als die tabel er niet is.
static func endgame_winkel() -> String:
	return HANDEL_WINKEL if ShopData.SHOPS.has(HANDEL_WINKEL) else ""


static func handel_open() -> bool:
	return endgame_winkel() != ""


static func plaatje(bron: String) -> Dictionary:
	match bron:
		"echo", "echo_grot":
			return {"pad": ART_ECHO, "h": 3, "v": 4, "offset": Vector2(0, -10)}
		"grot_ingang":
			return {"pad": ART_WARP, "h": 1, "v": 1, "offset": Vector2(0, 0), "tint": Color(0.55, 0.35, 0.95)}
		"party":
			return {"pad": ART_PARTY, "h": 3, "v": 4, "offset": Vector2(0, -10)}
		"pc", "voortgang":
			return {"pad": ART_PC, "h": 1, "v": 1, "offset": Vector2(0, -8)}
		"warp":
			return {"pad": ART_WARP, "h": 1, "v": 1, "offset": Vector2(0, 0)}
		"werk":
			return {"pad": ART_TAFEL, "h": 1, "v": 1, "offset": Vector2(0, 0)}
		"handel":
			return {"pad": ART_TOONBANK, "h": 1, "v": 1, "offset": Vector2(0, 0)}
		_:
			return {"pad": ART_BORD, "h": 1, "v": 1, "offset": Vector2(0, -6)}


static func label(bron: String) -> String:
	match bron:
		"echo", "echo_grot":
			return "ECHO"
		"grot_ingang":
			return "Deep Learning Simulation"
		"warp":
			return "Gate"
		"voortgang":
			return "Progress"
		"bestiarium":
			return "Bestiary"
		"codex":
			return "Codex"
		"oefening":
			return "Practice"
		"opslaan":
			return "Save"
		"helen":
			return "Heal"
		"wisselen":
			return "Swap"
		"werk":
			return "Table"
		"handel":
			return "Counter"
		"kern":
			return "Core"
		"kamers":
			return "Rooms"
		_:
			return ""


static func speler_teksten() -> Array[String]:
	var out: Array[String] = []
	out.append_array(ECHO_REGELS)
	out.append_array(EchoGrot.speler_teksten())
	out.append_array(load("res://world_warper/data/echo_questlog.gd").speler_teksten())
	out.append_array(WERK_REGELS)
	out.append_array(Recepten.speler_teksten())
	out.append(HANDEL_DICHT)
	out.append(KERN_ZIN)
	out.append(GESLOTEN)
	out.append(OEFEN_KLAAR)
	out.append(OEFEN_VERLIES)
	out.append(OEFEN_VANGEN)
	out.append(GEGENEZEN)
	out.append(OPGESLAGEN)
	out.append(OPSLAAN_MISLUKT)
	out.append(NIEMAND_WISSEL)
	out.append(AL_VOORAAN)
	out.append(VOORAAN % "Dax")
	out.append(GEEN_SCHERM)
	out.append(GEEN_POORT)
	for id in ROOMS.keys():
		out.append(naam(str(id)))
	for bron in ["echo", "warp", "voortgang", "bestiarium", "codex", "oefening", "opslaan", "helen", "wisselen", "werk", "handel", "kern", "kamers"]:
		var lab := label(bron)
		if lab != "":
			out.append(lab)
	out.append_array(voortgang_regels(0, {}, ""))
	for doel in warp_doelen():
		out.append(str(doel.get("label", "")))
	return out
