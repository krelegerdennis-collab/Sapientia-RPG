class_name WorldWarperRooms
extends RefCounted
## Kamers van de World Warper-hub.
## Act 1 is open. Act 2 en act 3 blijven dicht tot een story-vlag.
##
## TODO(design): niemand zet world_warper_act2 of world_warper_act3.
## Welk verhaalmoment die deuren openzet, hoort niet bij deze kaarten.
## TODO(design): een onbekende room_id is dicht en heeft geen scènepad.
## TODO(design): zijdeuren en de terugweg uit elke nis landen op hal-spawn "ingang".
## Eigen spawns per deur zijn niet afgesproken; alleen ingang en van_buiten staan vast.
## TODO(design): sapientia_schot blijft vanbinnen een dichte muur. De act-3-vlag
## zet die muur niet open.
## TODO(design): deze kaarten laten map.gd het kamer-checkpoint zetten (standaard aan)
## en hebben geen eigen music_track. Ambience hoort bij een ander systeem.
## TODO(design): de buitenkaart heet voor de speler "Buiten". De warp-ring is een
## rechthoek van paneeltegels, geen cirkel.

const FLAG_ACT2 := "world_warper_act2"
const FLAG_ACT3 := "world_warper_act3"

const ROOMS := {
	"exterieur": {
		"act": 1,
		"flag": "",
		"scene": "res://world_warper/maps/exterieur.tscn",
	},
	"hal": {
		"act": 1,
		"flag": "",
		"scene": "res://world_warper/maps/hal.tscn",
	},
	"warp_ring": {
		"act": 1,
		"flag": "",
		"scene": "res://world_warper/maps/warp_ring.tscn",
	},
	"hanger_nis": {
		"act": 1,
		"flag": "",
		"scene": "res://world_warper/maps/hanger_nis.tscn",
	},
	"codex_nis": {
		"act": 2,
		"flag": FLAG_ACT2,
		"scene": "res://world_warper/maps/codex_nis.tscn",
	},
	"sapientia_schot": {
		"act": 3,
		"flag": FLAG_ACT3,
		"scene": "res://world_warper/maps/sapientia_schot.tscn",
	},
}


## Open als de kamer geen vlag eist, of als die sleutel in flags staat.
## Zelfde regel als Story.has_flag: de sleutel telt, niet een losse waarde.
static func is_open(room_id: String, flags: Dictionary) -> bool:
	if not ROOMS.has(room_id):
		return false
	var flag := str(ROOMS[room_id]["flag"])
	if flag == "":
		return true
	return flags.has(flag)


static func scene_path(room_id: String) -> String:
	if not ROOMS.has(room_id):
		return ""
	return str(ROOMS[room_id]["scene"])
