extends RefCounted
class_name PvpRoster
## Bouwt één kant van drie vechters. Dubbele helden krijgen een id-suffix
## en een eigen tas. Ze delen geen inventaris.


static func build_side(seat: String, team_id: String, mode_id: String) -> Array:
	var level := PvpModes.level_of(mode_id)
	var seen := {}
	var out: Array = []
	var index := 0
	for raw in PvpTeams.members(team_id):
		var cid := str(raw)
		var n := int(seen.get(cid, 0))
		seen[cid] = n + 1
		var suffix := "" if n == 0 else "_%d" % (n + 1)
		out.append(_one(seat, cid, suffix, n, index, level, mode_id))
		index += 1
	return out


static func _one(seat: String, cid: String, suffix: String, copy_index: int, index: int, level: int, mode_id: String) -> Dictionary:
	var base := PvpCharacters.scaled(cid, level)
	var bonus := PvpLoadouts.bonuses(str(base["equip_type"]), mode_id)
	var display := str(base["name"])
	if copy_index == 1:
		display += " II"
	elif copy_index > 1:
		display += " %d" % (copy_index + 1)
	var items := PvpItems.bag_for(mode_id)
	return {
		"uid": "%s:%s%s" % [seat, cid, suffix],
		"character_id": cid,
		"display": display,
		"seat": seat,
		"index": index,
		"level": level,
		"hp": int(base["max_hp"]),
		"max_hp": int(base["max_hp"]),
		"mp": int(base["max_mp"]),
		"max_mp": int(base["max_mp"]),
		"atk": int(base["atk"]) + int(bonus["atk"]),
		"def": int(base["def"]) + int(bonus["def"]),
		"agi": int(base["agi"]) + int(bonus["agi"]),
		"mag": int(base["mag"]) + int(bonus["mag"]),
		"mdef": int(base["mdef"]) + int(bonus["mdef"]),
		"spells": (base["spells"] as Array).duplicate(),
		"items": items,
		"items_initial": items.duplicate(true),
		"gear": PvpLoadouts.gear_ids(str(base["equip_type"]), mode_id),
		"defending": false,
	}
