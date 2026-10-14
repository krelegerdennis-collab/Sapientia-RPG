extends Node
## Catalogus t/m het einde: act-banden, nieuwe items en uitrustingslijnen.
## Start:  godot --path . -- --catalogustest
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const LS := preload("res://scripts/data/level_scale.gd")
const Equipment := preload("res://scripts/equipment.gd")
const Party := preload("res://scripts/party_actions.gd")
const Scale := preload("res://scripts/data/dungeon100_scaling.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const WoudRooms := preload("res://scripts/data/woud_rooms.gd")
const Kast := preload("res://scripts/dungeon/inktwurm_kast.gd")

const CLASSES := ["krijger", "magier", "priester"]
const COLS := 13
## Beginset die de 100-verdiepingen-kisten al gebruikten (niveau 1). Nieuwe stukken horen daar niet in.
const ARCHIEF_BASIS := ["kort_zwaard", "eiken_staf", "houten_schild", "leren_kap", "leren_harnas", "bladwijzer",
		"drankje", "kruid"]

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_band_tests()
	_catalog_tests()
	_line_tests()
	_place_tests()
	print("CATALOGUSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _band_tests() -> void:
	check("EXP-formule ongewijzigd (Lv2=15, Lv3=60, Lv10=1215)",
			GD.exp_for_level(2) == 15 and GD.exp_for_level(3) == 60 and GD.exp_for_level(10) == 1215
			and GD.exp_for_level(1) == 0)
	var covered := {}
	var prev_max := 0
	var acts_ok := LS.ACTS.size() == 6
	for i in LS.ACTS.size():
		var b: Dictionary = LS.ACTS[i]
		var act := int(b["act"])
		acts_ok = acts_ok and act == i + 1 and int(b["min"]) == prev_max + 1 and int(b["max"]) >= int(b["min"])
		for lv in range(int(b["min"]), int(b["max"]) + 1):
			covered[lv] = act
		prev_max = int(b["max"])
	var span_ok := prev_max == LS.VERHAAL_MAX and covered.size() == LS.VERHAAL_MAX
	for lv in range(1, LS.VERHAAL_MAX + 1):
		span_ok = span_ok and LS.act_for_level(lv) == int(covered.get(lv, -1))
	check("act-banden 1-6 sluiten op elkaar aan en dekken level 1-%d" % LS.VERHAAL_MAX, acts_ok and span_ok)
	check("Act 1 loopt t/m 13 (Golem en Donker Woud), Act 6 is 37-40",
			LS.act_for_level(1) == 1 and LS.act_for_level(13) == 1 and LS.act_for_level(14) == 2
			and LS.act_for_level(36) == 5 and LS.act_for_level(37) == 6 and LS.act_for_level(40) == 6)
	check("voorbij 40 (de kerker) blijft Act 6, level 0 is geen act",
			LS.act_for_level(41) == 6 and LS.act_for_level(100) == 6 and LS.act_for_level(0) == 0)


func _def(id: String) -> Dictionary:
	if GD.EQUIPMENT.has(id):
		return GD.EQUIPMENT[id]
	if GD.ITEMS.has(id):
		return GD.ITEMS[id]
	return {}


func _list_ok(id: String) -> bool:
	var it := _def(id)
	var name := str(it.get("name", ""))
	if name == "":
		return false
	var shown := Party.item_list_name(id, COLS)
	if shown.length() > COLS:
		return false
	if name.length() > COLS:
		var short := str(it.get("short", ""))
		if short == "" or short.length() > COLS:
			return false
	return true


func _catalog_tests() -> void:
	var seen := {}
	var ids_ok := true
	var names_ok := true
	var who_ok := true
	var slot_ok := true
	for lname in LS.LIJNEN:
		var line: Dictionary = LS.LIJNEN[lname]
		var vak := str(line.get("vak", ""))
		for id in line["ids"]:
			var sid := str(id)
			var it := _def(sid)
			if it.is_empty():
				ids_ok = false
				continue
			seen[sid] = int(seen.get(sid, 0)) + 1
			names_ok = names_ok and _list_ok(sid)
			var wie = it.get("wie", null)
			if wie != null:
				if not (wie is Array) or (wie as Array).is_empty():
					who_ok = false
				else:
					for w in wie:
						who_ok = who_ok and str(w) in CLASSES
			if vak == "":
				slot_ok = slot_ok and GD.ITEMS.has(sid) and (int(it.get("heal_hp", 0)) > 0 or int(it.get("heal_mp", 0)) > 0)
			else:
				slot_ok = slot_ok and GD.EQUIPMENT.has(sid) and str(it.get("slot", "")) == vak
				slot_ok = slot_ok and str(it.get("slot", "")) in GD.EQUIP_SLOTS
	var share_ok := true
	for sid in seen:
		var n := int(seen[sid])
		if n > 1:
			share_ok = share_ok and str(sid) in LS.GEDEELD
		else:
			share_ok = share_ok and not (str(sid) in LS.GEDEELD)
	check("elke id in een lijn bestaat, het vak klopt, en alleen eiken_staf/leren_kap zijn gedeeld",
			ids_ok and slot_ok and share_ok)
	check("dragers zijn alleen krijger, magier of priester", who_ok)
	check("namen in de smalle lijst blijven binnen %d tekens" % COLS, names_ok)
	var start_ok := true
	for sid in seen:
		if _def(sid).has("bron") or str(sid) in LS.NU_TE_VINDEN:
			start_ok = start_ok and not GD.START_INVENTORY.has(sid)
	start_ok = start_ok and GD.KEY_ITEMS.has("hanger") and not GD.START_INVENTORY.has("hanger")
	check("nieuwe stukken en the Pendant zitten niet in de startvoorraad", start_ok)


func _score(id: String, etype: String) -> float:
	if etype == "":
		var it := _def(id)
		return float(int(it.get("heal_hp", 0)) + int(it.get("heal_mp", 0)))
	return Equipment.score({"equip_type": etype}, id)


func _line_tests() -> void:
	var mono := true
	var wear := true
	var act_ok := true
	var orde_ok := true
	var beyond := true
	for lname in LS.LIJNEN:
		var line: Dictionary = LS.LIJNEN[lname]
		var etype := str(line.get("type", ""))
		var ids: Array = line["ids"]
		var prev := -1.0
		var prev_act := 0
		for i in ids.size():
			var sid := str(ids[i])
			var it := _def(sid)
			var sc := _score(sid, etype)
			if sc <= prev:
				mono = false
				print("INFO  lijn %s: %s (%.2f) niet sterker dan de vorige" % [lname, sid, sc])
			prev = sc
			var act := int(it.get("act", 0))
			if act < prev_act or LS.band(act).is_empty():
				act_ok = false
			prev_act = act
			if str(it.get("lijn", "")) == str(lname) and int(it.get("orde", -1)) != i + 1:
				orde_ok = false
			if etype != "":
				var hero_type := etype if etype != "standaard" else "krijger"
				if not Equipment.can_wear({"equip_type": hero_type, "name": "Test"}, sid):
					wear = false
					print("INFO  %s kan %s niet dragen" % [hero_type, sid])
		if LS.VOORBIJ_ARCHIEF.has(lname):
			var top := str(ids[ids.size() - 1])
			var arch := str(LS.VOORBIJ_ARCHIEF[lname])
			if _score(top, etype) <= _score(arch, etype):
				beyond = false
				print("INFO  %s (%.2f) haalt %s (%.2f) niet voorbij" % [top, _score(top, etype), arch, _score(arch, etype)])
	check("binnen elke lijn is een later stuk strikt sterker", mono)
	check("de klasse van de lijn mag elk stuk in die lijn dragen", wear)
	check("het act-nummer stijgt niet achteruit en de orde klopt", act_ok and orde_ok)
	check("het laatste stuk van elke verhaallijn is sterker dan de zegel-set", beyond)


func _place_tests() -> void:
	var find_ok := true
	for sid in LS.NU_TE_VINDEN:
		find_ok = find_ok and not _def(str(sid)).is_empty()
	check("de drie Act 1-vondsten bestaan", find_ok)
	check("Vesper geeft het wambuis en Elise de kruidenthee",
			_gives("noor_bevrijd", "wambuis") and _gives("ilse", "kruidenthee"))
	var drop: Array = GD.ENEMIES["inktwurm"].get("drops", [])
	check("het bestiarium noemt de inktfles, de kast deelt hem uit",
			drop.size() >= 1 and str(drop[0].get("item", "")) == "gloeiende_inktfles"
			and str(Kast.INKT_FLAG) == "gloeiende_inktfles")
	var chest_ok := true
	for rooms in [DungeonRooms.ROOMS, WoudRooms.ROOMS]:
		for rid in rooms:
			for c in rooms[rid].get("chests", []):
				var sid := str(c.get("item", ""))
				var it := _def(sid)
				if int(it.get("act", 1)) >= 2 or it.has("bron") or str(sid) in LS.NU_TE_VINDEN:
					chest_ok = false
	check("verhaalstukken liggen niet in de kisten van Archief 1 of het Donker Woud", chest_ok)
	var gear_ok := true
	for kind in Scale.GEAR:
		for id in Scale.GEAR[kind]:
			var sid := str(id)
			if not (sid in ARCHIEF_BASIS) and not sid.begins_with("d100_"):
				gear_ok = false
			if _def(sid).has("bron"):
				gear_ok = false
	for pool in Scale.POTIONS:
		for id in pool:
			var sid2 := str(id)
			if _def(sid2).has("bron") or (int(_def(sid2).get("act", 0)) >= 2):
				gear_ok = false
	check("de 100-verdiepingen-kisten blijven de archiefset (geen verhaalstukken van Act 2-6)", gear_ok)


func _gives(event_name: String, item_id: String) -> bool:
	for variant in StoryData.EVENTS.get(event_name, []):
		var do_list = variant.get("do", [])
		if not (do_list is Array):
			continue
		for cmd in do_list:
			if cmd is Array and cmd.size() >= 3 and str(cmd[0]) == "give" and str(cmd[1]) == item_id and int(cmd[2]) >= 1:
				return true
	return false
