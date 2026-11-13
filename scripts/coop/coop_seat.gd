class_name CoopSeat
extends RefCounted
## Eén stoel-record in online co-op (M8a): mens, AI-stoel of SomAlly.
## De sim en de arena delen dit Dictionary-record. Dit is geen controller.
## M6 (scripts/coop/seat_controller.gd, nog niet in deze branch) vult controller
## "ai" op slot 0..3 en roept CoopRevive.query_revive / begin_channel / end_channel.
## Geen tweede brein hier, anders botst dat bestand bij de merge.

const CONTROLLER_HUMAN := "human"
const CONTROLLER_AI := "ai"
const CONTROLLER_ALLY := "ally"

var row: Dictionary


func _init(r: Dictionary = {}) -> void:
	row = r


static func make(slot: int, hero_id: String, controller: String = CONTROLLER_HUMAN) -> Dictionary:
	return {
		"slot": slot,
		"hero_id": hero_id,
		"character_id": hero_id,
		"base_hero": hero_id,
		"controller": controller,
		"active": true,
		"participate": true,
		"x": 0,
		"y": 0,
		"hp": 1,
		"max_hp": 1,
		"down": false,
		"bleed_ticks": 0,
		"bleed_expired": false,
		"channel_ticks": 0,
		"channel_target": -1,
		"channel_seen": 0,
		"hit_seq": 0,
		"iframes": 0,
		"revives": 0,
		"flags": 0,
		"hp_ready": false,
	}


func hero_id() -> String:
	var base := str(row.get("base_hero", ""))
	if base != "":
		return base
	var cid := str(row.get("character_id", ""))
	if cid != "":
		return cid
	return str(row.get("hero_id", ""))


func controller() -> String:
	return str(row.get("controller", CONTROLLER_HUMAN))


func is_ai() -> bool:
	var c := controller()
	return c == CONTROLLER_AI or c == CONTROLLER_ALLY


func is_down() -> bool:
	return bool(row.get("down", false))


func is_active() -> bool:
	return bool(row.get("active", false)) and bool(row.get("participate", true))
