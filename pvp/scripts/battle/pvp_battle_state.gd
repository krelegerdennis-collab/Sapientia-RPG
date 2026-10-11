extends RefCounted
class_name PvpBattleState
## Staat van één gevecht. Alleen de host roept apply_action aan.
## De gast vervangt zijn staat met load_snapshot.


var fighters: Array = []
var order: Array = []
var turn_i: int = 0
var round_no: int = 1
var over: bool = false
var winner: String = ""
var log: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(host_side: Array, guest_side: Array, seed_value: int) -> void:
	fighters = []
	for raw in host_side:
		fighters.append((raw as Dictionary).duplicate(true))
	for raw in guest_side:
		fighters.append((raw as Dictionary).duplicate(true))
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	over = false
	winner = ""
	round_no = 1
	log = []
	_rebuild_order()


func current_uid() -> String:
	if over or order.is_empty() or turn_i < 0 or turn_i >= order.size():
		return ""
	return str(order[turn_i])


func fighter(uid: String) -> Dictionary:
	for raw in fighters:
		var row: Dictionary = raw
		if str(row.get("uid", "")) == uid:
			return row
	return {}


func first_living_enemy(actor_uid: String) -> String:
	var actor := fighter(actor_uid)
	if actor.is_empty():
		return ""
	var seat := str(actor["seat"])
	for raw in fighters:
		var row: Dictionary = raw
		if str(row["seat"]) == seat:
			continue
		if int(row["hp"]) > 0:
			return str(row["uid"])
	return ""


func apply_action(actor_uid: String, action: String, target_uid: String, spell_id: String, item_id: String) -> Dictionary:
	if over:
		return _fail("Het gevecht is afgelopen.")
	if current_uid() != actor_uid:
		return _fail("Niet deze beurt.")
	var actor := fighter(actor_uid)
	if actor.is_empty() or int(actor["hp"]) <= 0:
		return _fail("Deze vechter doet niet meer mee.")
	var applied := false
	var line := ""
	match action:
		"attack":
			var hit := _attack(actor, target_uid)
			applied = bool(hit["ok"])
			line = str(hit["log"])
			if not applied:
				return hit
		"spell":
			var cast := _spell(actor, target_uid, spell_id)
			applied = bool(cast["ok"])
			line = str(cast["log"])
			if not applied:
				return cast
		"defend":
			actor["defending"] = true
			line = "%s verdedigt." % str(actor["display"])
			applied = true
		"item":
			var used := _item(actor, target_uid, item_id)
			applied = bool(used["ok"])
			line = str(used["log"])
			if not applied:
				return used
		_:
			return _fail("Onbekende actie.")
	_push_log(line)
	var win := PvpRules.winner_seat(fighters)
	if win != "":
		over = true
		winner = win
		return {"ok": true, "reason": "", "log": line, "finished": true}
	_advance()
	win = PvpRules.winner_seat(fighters)
	if win != "":
		over = true
		winner = win
		return {"ok": true, "reason": "", "log": line, "finished": true}
	return {"ok": true, "reason": "", "log": line, "finished": false}


func result_dict() -> Dictionary:
	var rows: Array = []
	for raw in fighters:
		var row: Dictionary = raw
		rows.append({
			"uid": str(row["uid"]),
			"name": str(row["display"]),
			"seat": str(row["seat"]),
			"hp": int(row["hp"]),
			"max_hp": int(row["max_hp"]),
		})
	return {"winner": winner, "hp": rows}


func serialize() -> Dictionary:
	return {
		"fighters": fighters.duplicate(true),
		"order": order.duplicate(),
		"turn_i": turn_i,
		"round_no": round_no,
		"over": over,
		"winner": winner,
	}


func load_snapshot(data: Dictionary) -> void:
	fighters = (data.get("fighters", []) as Array).duplicate(true)
	order = (data.get("order", []) as Array).duplicate()
	turn_i = int(data.get("turn_i", 0))
	round_no = int(data.get("round_no", 1))
	over = bool(data.get("over", false))
	winner = str(data.get("winner", ""))


func reset_for_rematch() -> void:
	for raw in fighters:
		var row: Dictionary = raw
		row["hp"] = int(row["max_hp"])
		row["mp"] = int(row["max_mp"])
		row["defending"] = false
		row["items"] = (row["items_initial"] as Dictionary).duplicate(true)
	over = false
	winner = ""
	log = []
	round_no = 1
	_rebuild_order()


func hp_list() -> Array:
	return result_dict()["hp"]


func _attack(actor: Dictionary, target_uid: String) -> Dictionary:
	var target := fighter(target_uid)
	if target.is_empty() or str(target["seat"]) == str(actor["seat"]) or int(target["hp"]) <= 0:
		return _fail("Kies een tegenstander.")
	var variance := PvpRules.roll_variance(rng)
	var dmg := PvpRules.physical_damage(int(actor["atk"]), int(target["def"]), 1.0, variance, bool(target["defending"]))
	target["hp"] = maxi(0, int(target["hp"]) - dmg)
	var line := "%s valt %s aan (%d)." % [str(actor["display"]), str(target["display"]), dmg]
	return {"ok": true, "reason": "", "log": line, "finished": false}


func _spell(actor: Dictionary, target_uid: String, spell_id: String) -> Dictionary:
	if not (actor["spells"] as Array).has(spell_id):
		return _fail("Die spreuk ken je niet.")
	var spell := PvpSpells.get_spell(spell_id)
	if spell.is_empty():
		return _fail("Die spreuk ken je niet.")
	var cost := int(spell["mp"])
	if int(actor["mp"]) < cost:
		return _fail("Te weinig MP.")
	var amount := PvpRules.spell_amount(int(spell["power"]), int(actor["level"]))
	var kind := str(spell["type"])
	var target_kind := str(spell["target"])
	var line := ""
	if kind == "heal":
		var ally := fighter(target_uid)
		if ally.is_empty() or str(ally["seat"]) != str(actor["seat"]) or int(ally["hp"]) <= 0:
			return _fail("Kies een bondgenoot.")
		var before := int(ally["hp"])
		ally["hp"] = mini(int(ally["max_hp"]), before + amount)
		actor["mp"] = int(actor["mp"]) - cost
		var gained := int(ally["hp"]) - before
		line = "%s spreekt %s op %s (%d)." % [str(actor["display"]), str(spell["name"]), str(ally["display"]), gained]
		return {"ok": true, "reason": "", "log": line, "finished": false}
	if target_kind == "all_enemies":
		var any := false
		for raw in fighters:
			var foe_all: Dictionary = raw
			if str(foe_all["seat"]) == str(actor["seat"]) or int(foe_all["hp"]) <= 0:
				continue
			foe_all["hp"] = maxi(0, int(foe_all["hp"]) - amount)
			any = true
		if not any:
			return _fail("Er is geen doelwit.")
		actor["mp"] = int(actor["mp"]) - cost
		line = "%s spreekt %s (%d)." % [str(actor["display"]), str(spell["name"]), amount]
		return {"ok": true, "reason": "", "log": line, "finished": false}
	var foe := fighter(target_uid)
	if foe.is_empty() or str(foe["seat"]) == str(actor["seat"]) or int(foe["hp"]) <= 0:
		return _fail("Kies een tegenstander.")
	foe["hp"] = maxi(0, int(foe["hp"]) - amount)
	actor["mp"] = int(actor["mp"]) - cost
	line = "%s spreekt %s op %s (%d)." % [str(actor["display"]), str(spell["name"]), str(foe["display"]), amount]
	return {"ok": true, "reason": "", "log": line, "finished": false}


func _item(actor: Dictionary, target_uid: String, item_id: String) -> Dictionary:
	var bag: Dictionary = actor["items"]
	if int(bag.get(item_id, 0)) <= 0:
		return _fail("Dat drankje is op.")
	var item := PvpItems.get_item(item_id)
	if item.is_empty():
		return _fail("Onbekend drankje.")
	var ally := fighter(target_uid)
	if ally.is_empty() or str(ally["seat"]) != str(actor["seat"]) or int(ally["hp"]) <= 0:
		return _fail("Kies een bondgenoot.")
	var before_hp := int(ally["hp"])
	var before_mp := int(ally["mp"])
	ally["hp"] = mini(int(ally["max_hp"]), before_hp + int(item["heal_hp"]))
	ally["mp"] = mini(int(ally["max_mp"]), before_mp + int(item["heal_mp"]))
	bag[item_id] = int(bag[item_id]) - 1
	var gained := (int(ally["hp"]) - before_hp) + (int(ally["mp"]) - before_mp)
	var line := "%s gebruikt %s op %s (%d)." % [str(actor["display"]), str(item["name"]), str(ally["display"]), gained]
	return {"ok": true, "reason": "", "log": line, "finished": false}


func _advance() -> void:
	var guard := 0
	while guard < 12:
		turn_i += 1
		if turn_i >= order.size():
			_end_round()
			return
		var uid := str(order[turn_i])
		var row := fighter(uid)
		if not row.is_empty() and int(row["hp"]) > 0:
			return
		guard += 1
	_end_round()


func _end_round() -> void:
	for raw in fighters:
		(raw as Dictionary)["defending"] = false
	round_no += 1
	_rebuild_order()


func _rebuild_order() -> void:
	order = PvpRules.turn_order(fighters)
	turn_i = 0
	if order.is_empty():
		var win := PvpRules.winner_seat(fighters)
		if win != "":
			over = true
			winner = win


func _push_log(line: String) -> void:
	log.append(line)
	if log.size() > 6:
		log.pop_front()


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "log": "", "finished": false}
