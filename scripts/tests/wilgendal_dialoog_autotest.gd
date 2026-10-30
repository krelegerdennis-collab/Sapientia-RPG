extends RefCounted
## WM1 T1: elke NPC in Wilgendal (playtest-gebied "wilgendal": dorp_wilgendal + wilgendal_binnen) heeft
## een oplosbare ENGELSE dialoog. Binnen --autotest (scripts/debug_autotest.gd), geen eigen CI-suite.
## Wat telt als oplosbaar: een "shop"-event met een bestaande winkel, een story-event met een passende
## variant die iets zegt (say/choice, ook via jump/run/choice-doelen), of anders niet-lege 'lines'.
## Spelerstekst moet Engels zijn (ids blijven Nederlands): een korte lijst Nederlandse woorden mag er niet in.

const SD := preload("res://scripts/data/story_data.gd")
const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const Shop := preload("res://scripts/data/shop_data.gd")

## Hele woorden (kleine letters) die in Engelse spelerstekst niet horen.
const NL_WOORDEN := ["de", "het", "een", "niet", "ik", "jij", "je", "wij", "zijn", "maar", "ook", "naar",
		"met", "dat", "wat", "hier", "daar", "nog", "geen", "winkel", "deur", "jongen", "kom", "ga", "gaat",
		"heb", "hebt", "heeft", "wordt", "jullie", "mijn", "jouw", "dorp", "molen", "kast", "hallo", "dank",
		"alsjeblieft", "goedemorgen", "opa", "wilgendal", "tante", "smid", "molenaar", "herbergier"]

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	var oude_mult: float = GameState.encounter_multiplier
	GameState.encounter_multiplier = 0.0
	_statisch()
	# twee standen: vlak na de proloog (Vesper nog niet in de groep) en met Vesper (Gerrit-opdracht open)
	for stand in [{"naam": "zonder Vesper", "flags": {}}, {"naam": "met Vesper", "flags": {"noor_lid": true}}]:
		GameState.new_game("Dax")
		GameState.story_step = SD.KLAAR
		for f in stand["flags"]:
			GameState.story_flags[f] = stand["flags"][f]
		GameState.pending_spawn = Data.SPAWN_ZUID
		var dorp: Node = await _laad(Data.DORP)
		t.check("wilgendal-dialoog (%s): dorp laadt" % stand["naam"], dorp != null)
		if dorp == null:
			continue
		await t.frames(4)
		var npcs := _npcs(dorp)
		# Gerrit + 5 sfeer-NPC's + 3 vaste dorpelingen
		t.check("wilgendal-dialoog (%s): minstens 9 NPC's in het dorp (%d)" % [stand["naam"], npcs.size()], npcs.size() >= 9)
		for npc in npcs:
			if str(npc.name) == "Gerrit" and not GameState.story_flags.has("noor_lid"):
				# Bewust: Gerrit praat pas met Vesper in de groep; zijn tekst is canon (woud_tests: precies de
				# canon-zinnen). Hier alleen vastleggen dat dat de enige stille variant is.
				var v: Dictionary = Story.pick("gerrit")
				t.check("wilgendal-dialoog: Gerrit zwijgt vóór Vesper alleen via de lege canon-variant",
						not v.is_empty() and v.get("do") is Array and (v["do"] as Array).is_empty()
						and v.get("if", {}).get("not_flags", []) == ["noor_lid"])
				continue
			_controleer(npc, "dorp/%s (%s)" % [npc.name, stand["naam"]])
	# winkeliers en bewoners binnen (wilgendal_binnen.tscn, spawn = pand-id)
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	var n_keepers := 0
	for ruw in Data.PANDEN:
		var rij: Dictionary = ruw
		if Data.kamer_rijen(str(rij["id"])).is_empty():
			continue
		GameState.pending_spawn = str(rij["id"])
		var binnen: Node = await _laad(Data.BINNEN)
		t.check("wilgendal-dialoog: interieur %s laadt" % rij["id"], binnen != null)
		if binnen == null:
			continue
		await t.frames(2)
		t.check("wilgendal-dialoog: kaartnaam %s Engels (%s)" % [rij["id"], binnen.map_name], _engels(str(binnen.map_name)))
		var keeper: Node = binnen.get_node_or_null("Objects/Winkelier")
		if str(rij.get("keeper_naam", "")) != "":
			t.check("wilgendal-dialoog: %s heeft een winkelier" % rij["id"], keeper != null)
		if keeper != null:
			n_keepers += 1
			_controleer(keeper, "binnen/%s" % rij["id"])
		var bord: Node = binnen.get_node_or_null("Objects/Bord")
		if bord != null:
			var regels: Array = bord.lines
			t.check("wilgendal-dialoog: bord in %s heeft Engelse tekst" % rij["id"], not regels.is_empty() and _alles_engels(regels))
	t.check("wilgendal-dialoog: 5 winkeliers binnen (%d)" % n_keepers, n_keepers == 5)
	GameState.encounter_multiplier = oude_mult


## Data zonder scène: elke rij heeft een naam en Engelse regels; elk story-doel (jump/run/choice) bestaat.
func _statisch() -> void:
	var fout: Array[String] = []
	for lijst in [Data.SFEER, Data.P10_DORPELINGEN]:
		for ruw in lijst:
			var rij: Dictionary = ruw
			var regels: Array = rij.get("lines", [])
			if str(rij.get("naam", "")) == "" or regels.is_empty() or not _alles_engels(regels) or not _engels(str(rij["naam"])):
				fout.append(str(rij.get("node", "?")))
	for ruw in Data.PANDEN:
		var rij: Dictionary = ruw
		for k in ["keeper_naam", "map_naam", "dicht", "bord"]:
			if not _engels(str(rij.get(k, ""))):
				fout.append("%s.%s" % [rij["id"], k])
		if not _alles_engels(rij.get("keeper_lines", [])):
			fout.append("%s.keeper_lines" % rij["id"])
		if str(rij.get("keeper_naam", "")) != "" and (rij.get("keeper_lines", []) as Array).is_empty():
			fout.append("%s: winkelier zonder regels" % rij["id"])
		if str(rij.get("shop_id", "")) != "" and not Shop.SHOPS.has(str(rij["shop_id"])):
			fout.append("%s: winkel %s bestaat niet" % [rij["id"], rij["shop_id"]])
	t.check("wilgendal-dialoog: data (SFEER, dorpelingen, panden) compleet en Engels %s" % [fout], fout.is_empty())
	var dood: Array[String] = []
	var tekst: Array = []
	for id in ["gerrit"]:
		_volg(id, {}, dood, tekst)
	t.check("wilgendal-dialoog: geen dode takken vanaf Gerrit %s" % [dood], dood.is_empty())
	var nl: Array = tekst.filter(func(s): return not _engels(str(s)))
	t.check("wilgendal-dialoog: alle Gerrit-tekst Engels %s" % [nl], nl.is_empty() and tekst.size() >= 8)
	t.check("wilgendal-dialoog: elke winkel heeft een Engelse naam", Shop.SHOPS.keys().all(
			func(k): return _engels(Shop.shop_name(str(k))))
			and Shop.shop_name("bestaat_niet") == "Shop")


## Loopt een event af (alle varianten) en verzamelt tekst en doelen die niet bestaan.
func _volg(id: String, gezien: Dictionary, dood: Array[String], tekst: Array) -> void:
	if id == "" or gezien.has(id):
		return
	gezien[id] = true
	if not SD.EVENTS.has(id):
		dood.append(id)
		return
	for v in SD.EVENTS[id]:
		var doe = v.get("do", [])
		if doe is Array:
			_volg_cmds(doe, gezien, dood, tekst)


func _volg_cmds(cmds: Array, gezien: Dictionary, dood: Array[String], tekst: Array) -> void:
	for raw in cmds:
		if not (raw is Array) or raw.is_empty():
			continue
		match str(raw[0]):
			"say":
				tekst.append(str(raw[1]))
				for r in raw[2]:
					tekst.append(str(r))
			"choice":
				tekst.append(str(raw[1]))
				for o in raw[2]:
					tekst.append(str(o))
				for d in raw[3]:
					_volg(str(d), gezien, dood, tekst)
			"jump", "run":
				_volg(str(raw[1]), gezien, dood, tekst)
			"if":
				for i in range(2, raw.size()):
					if raw[i] is Array:
						_volg_cmds(raw[i], gezien, dood, tekst)


## Eén NPC-node: naam, oplosbare dialoog, Engelse tekst.
func _controleer(npc: Node, label: String) -> void:
	var naam := str(npc.npc_name)
	t.check("wilgendal-dialoog %s: Engelse naam '%s'" % [label, naam], naam != "" and _engels(naam))
	var ev := str(npc.event)
	var regels: Array = npc.lines
	var spreekt := false
	var tekst: Array = []
	if ev == "shop":
		spreekt = Shop.SHOPS.has(str(npc.event_arg)) and not regels.is_empty()
		tekst = regels
	elif ev != "" and SD.EVENTS.has(ev):
		var v: Dictionary = Story.pick(ev, str(npc.event_arg))
		if v.is_empty() or v.get("do") is String:
			spreekt = not regels.is_empty()
			tekst = regels
		else:
			var dood: Array[String] = []
			_volg_cmds(v["do"], {}, dood, tekst)
			spreekt = not tekst.is_empty() and dood.is_empty()
	elif ev == "":
		spreekt = not regels.is_empty()
		tekst = regels
	t.check("wilgendal-dialoog %s: oplosbare dialoog (event '%s')" % [label, ev], spreekt)
	var leeg := tekst.filter(func(s): return str(s).strip_edges() in ["", "...", "Hello!"])
	t.check("wilgendal-dialoog %s: echte, Engelse tekst %s" % [label, tekst], leeg.is_empty() and _alles_engels(tekst))


func _npcs(map: Node) -> Array:
	var uit := []
	for n in map.get_node("Objects").get_children():
		if n.has_method("interact") and "npc_name" in n and "lines" in n and n.visible:
			uit.append(n)
	return uit


func _alles_engels(regels: Array) -> bool:
	return regels.all(func(s): return _engels(str(s)))


func _engels(s: String) -> bool:
	var woorden := s.to_lower().replace("{naam}", "").split(" ", false)
	for w in woorden:
		var kaal := ""
		for c in w:
			if (c >= "a" and c <= "z") or c == "'":
				kaal += c
		if kaal in NL_WOORDEN:
			return false
	return true


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.has_return_point = false
	t.get_tree().change_scene_to_file(pad)
	for i in 180:
		await t.get_tree().process_frame
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null
