extends Node
## ALLEEN VOOR TESTEN - v0.22 partylimiet (scripts/party_limiet.gd, HANDOFF_PARTY.md).
## Start:  godot --path . -- --partytest [--shots=/pad/map] [--alleen=ABCD]
##   Deel A: regels: max 4 helden + 1 monster, reserve (party_bench + niet-actieve Codex-pagina's),
##           wisselen buiten het gevecht (wissel / naar reserve / erbij / monster kiezen),
##           Dennis en gasten blijven, een nieuwe held bij een volle groep gaat naar de reserve.
##   Deel B: save/load: reserve in de save, oude save zonder "party_bank", oude save met te veel
##           helden in "party" (migratie: de rest naar de reserve).
##   Deel C: gevecht: 4 helden + 1 monster (4 heldenvakken onderaan, monster als zijspeler boven B), de reserve-held
##           vecht niet mee, beurtvolgorde telt alleen de actieve combatanten, wisselen geblokkeerd.
##   Deel D: veldmenu > Party: scherm open, wisselen via het scherm, monster kiezen.
## Met --shots=map: party_gevecht_5_plekken, party_veldmenu, veldmenu_magic, veldmenu_knoppen, veldmenu_laden_bevestigen, party_menu, party_menu_gewisseld (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const PartyLimiet := preload("res://scripts/party_limiet.gd")
const PartyScreen := preload("res://scripts/ui/party_screen.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const VERDEDIG := 3

var failures := 0
var passes := 0
var shots := ""
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		if arg.begins_with("--alleen="):
			only = arg.get_slice("=", 1)
	seed(2026)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	if part("A"):
		print("=== Deel A: regels ===")
		_regel_tests()
	if part("B"):
		print("=== Deel B: save/load en migratie ===")
		_save_tests()
		_namen_migratie_tests()
	if part("C"):
		print("=== Deel C: gevecht ===")
		await _gevecht_tests()
	if part("D"):
		print("=== Deel D: veldmenu > Party ===")
		await _menu_tests()
	if part("E"):
		print("=== Deel E: veldmenu > Scenes ===")
		await _scenes_tests()
	print("PARTYTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ helpers
func part(k: String) -> bool:
	return only == "" or k in only


func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	return await wait_until(func():
		var s := scene()
		return s != null and s.scene_file_path == path and s.is_node_ready(), timeout)


func wait_scene_named(n: String, timeout := 15.0) -> bool:
	return await wait_until(func():
		var s := scene()
		return s != null and s.name == n and s.is_node_ready(), timeout)


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	for i in 30:
		if not Dialog.is_open:
			break
		await press_interact()
		await pframes(2)
	await pframes(2)


func enter(path: String, spawn: String) -> Node:
	GameState.has_return_point = false
	GameState.map_monster_battle = {}
	GameState.change_map(path, spawn)
	if not await wait_scene_path(path):
		return null
	await wait_fade()
	await wait_until(func(): return not Story.running, 5.0)
	await close_dialog()
	await pframes(6)
	var s := scene()
	if s != null and "monsters" in s:
		for m in s.monsters:
			if is_instance_valid(m):
				m.moves = false
	return s


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size(), " + _3x ", big.get_size())


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


func defend(b: Node) -> void:
	if await wait_battle_state(["command"]) != "command":
		return
	await pframes(4)
	await cross_to(b, VERDEDIG)
	await tap("interact")


func flee(b: Node) -> void:
	var wb: WeakRef = weakref(b)
	for i in 12:
		if wb.get_ref() == null or battle() == null:
			break
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "message_wait":
			await tap("interact")
			continue
		if st != "command":
			break
		b.can_flee = true
		b.cross.enabled[4] = true
		await cross_to(b, 4)
		await tap("interact")
		await pframes(8)
		await wait_until(func(): return battle() == null or wb.get_ref() == null or (wb.get_ref() as Node).state == "command", 15.0)
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


func setup() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.pending_kern_absorb = ""
	GameState.in_battle = false


## Testheld: kopie van een bestaande held met een eigen naam (er zijn in de data maar 3 helden).
func test_held(van: String, naam: String) -> Dictionary:
	var h := GameState.hero_template(van)
	h["name"] = naam
	return h


## Dennis, Noor, Lotte + testhelden tot 'n' helden in totaal (zonder normaliseren).
func zes_helden(n := 6) -> void:
	GameState.party = []
	GameState.party_bench = []
	GameState.party.append(GameState.hero_template("dennis"))
	GameState.party.append(GameState.hero_template("noor"))
	GameState.party.append(GameState.hero_template("lotte"))
	var extra := ["Kai", "Sem", "Ivo"]
	for i in maxi(0, n - 3):
		GameState.party.append(test_held("noor" if i % 2 == 0 else "lotte", extra[i % extra.size()]))


func namen(lijst: Array) -> Array:
	return lijst.map(func(h): return str(h.get("name", "")))


# ================================================================ deel A: regels
func _regel_tests() -> void:
	setup()
	check("limiet: 4 helden + 1 monster = 5", PartyLimiet.MAX_HELDEN == 4 and PartyLimiet.MAX_MONSTERS == 1
			and PartyLimiet.MAX_GEVECHT == 5 and PartyBench.MAX_ACTIEF == 4)
	zes_helden(6)
	var verplaatst := PartyLimiet.normaliseer()
	check("6 helden -> 4 actief + 2 reserve (%s | %s)" % [namen(GameState.party), namen(GameState.party_bench)],
			verplaatst == 2 and GameState.party.size() == 4 and GameState.party_bench.size() == 2
			and namen(GameState.party) == ["Dax", "Vesper", "Seren", "Kai"] and namen(GameState.party_bench) == ["Sem", "Ivo"])
	check("normaliseren is idempotent", PartyLimiet.normaliseer() == 0 and GameState.party.size() == 4)
	check("gevechts_helden: max 4", PartyLimiet.gevechts_helden([1, 2, 3, 4, 5, 6]) == [1, 2, 3, 4])
	# wisselen buiten het gevecht
	var t := PartyLimiet.wissel(1, 0)
	check("wissel Vesper <-> Sem: '%s'" % t, t == PartyLimiet.GEWISSELD % ["Sem", "Vesper"]
			and str(GameState.party[1]["name"]) == "Sem" and str(GameState.party_bench[0]["name"]) == "Vesper"
			and GameState.party.size() == 4 and GameState.party_bench.size() == 2)
	check("Dax kan niet naar de reserve", PartyLimiet.wissel(0, 0) == PartyLimiet.DENNIS_BLIJFT
			and PartyLimiet.naar_reserve(0) == PartyLimiet.DENNIS_BLIJFT and str(GameState.party[0]["id"]) == "dennis")
	check("volle groep: erbij geweigerd", PartyLimiet.naar_groep(0) == PartyLimiet.VOL and GameState.party.size() == 4)
	t = PartyLimiet.naar_reserve(3)
	check("Kai naar de reserve: '%s'" % t, t == PartyLimiet.NAAR_RESERVE % "Kai" and GameState.party.size() == 3
			and GameState.party_bench.size() == 3 and str(GameState.party_bench[2]["name"]) == "Kai")
	t = PartyLimiet.naar_groep(0)
	check("Vesper terug erbij: '%s'" % t, t == PartyLimiet.IN_GROEP % "Vesper" and GameState.party.size() == 4
			and str(GameState.party[3]["name"]) == "Vesper" and GameState.party_bench.size() == 2)
	var gast := {"id": "gast", "name": "Gast", "species": "mosslijm", "uid": "tijdelijk-1", "tijdelijk": true,
			"hp": 1, "max_hp": 1, "mp": 0, "max_mp": 0, "level": 1}
	GameState.party[3] = gast
	check("tijdelijke gast kan niet naar de reserve", PartyLimiet.naar_reserve(3) == PartyLimiet.GAST_BLIJFT
			and PartyLimiet.wissel(3, 0) == PartyLimiet.GAST_BLIJFT and GameState.party[3] == gast)
	GameState.party.remove_at(3)
	# nieuwe held bij een volle groep -> reserve
	setup()
	GameState.add_member("noor")
	GameState.party.append(test_held("noor", "Kai"))
	GameState.party.append(test_held("noor", "Sem"))
	var ok := GameState.join_member("lotte", 5)
	check("join_member bij volle groep: Seren naar de reserve, op niveau 5", ok and GameState.party.size() == 4
			and GameState.party_bench.size() == 1 and str(GameState.party_bench[0]["id"]) == "lotte"
			and int(GameState.party_bench[0]["level"]) == 5 and GameState.has_member("lotte"))
	# monster
	setup()
	var p1 := GameState.codex_add("mosslijm", 2)
	var p2 := GameState.codex_add("papiergeest", 2)
	check("monster: 1 actief, de rest in de reserve", GameState.codex_active == str(p1["uid"])
			and PartyLimiet.reserve_monsters().size() == 1 and str(PartyLimiet.reserve_monsters()[0]["uid"]) == str(p2["uid"]))
	t = PartyLimiet.kies_monster(str(p2["uid"]))
	check("monster wisselen buiten het gevecht: '%s'" % t, GameState.codex_active == str(p2["uid"])
			and t == PartyLimiet.MONSTER_ACTIEF % str(p2["name"]) and str(PartyLimiet.reserve_monsters()[0]["uid"]) == str(p1["uid"]))
	p1["hp"] = 0
	check("KO-monster kan niet actief worden", PartyLimiet.kies_monster(str(p1["uid"])) == PartyLimiet.MONSTER_KO % str(p1["name"])
			and GameState.codex_active == str(p2["uid"]))
	p1["hp"] = p1["max_hp"]
	check("monster naar de reserve ('none')", PartyLimiet.kies_monster("") == PartyLimiet.GEEN_MONSTER and GameState.codex_active == ""
			and PartyLimiet.reserve_monsters().size() == 2)
	# geblokkeerd in een gevecht
	zes_helden(6)
	PartyLimiet.normaliseer()
	GameState.codex_set_active(str(p1["uid"]))
	var voor_party := namen(GameState.party)
	var voor_bank := namen(GameState.party_bench)
	GameState.in_battle = true
	var geweigerd := [PartyLimiet.wissel(1, 0), PartyLimiet.naar_reserve(1), PartyLimiet.naar_groep(0),
			PartyLimiet.kies_monster(str(p2["uid"])), PartyLimiet.kies_monster("")]
	GameState.in_battle = false
	check("in een gevecht: elke wissel geweigerd %s" % [geweigerd], geweigerd.all(func(x): return x == PartyLimiet.IN_GEVECHT)
			and namen(GameState.party) == voor_party and namen(GameState.party_bench) == voor_bank
			and GameState.codex_active == str(p1["uid"]))


# ================================================================ deel B: save/load
func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func _save_tests() -> void:
	setup()
	zes_helden(6)
	PartyLimiet.normaliseer()
	var pad := "user://partytest_save.json"
	var weg := GameState.save_game(Vector2i(3, 3), Vector2i.DOWN, pad)
	var ruw := GameState.read_save(pad)
	check("save: 4 in party, 2 in party_bank", weg and (ruw.get("party") as Array).size() == 4 and (ruw.get("party_bank") as Array).size() == 2)
	GameState.party_bench = []
	var geladen := GameState.load_game(pad)
	check("load: reserve terug (%s)" % [namen(GameState.party_bench)], geladen and GameState.party.size() == 4
			and namen(GameState.party_bench) == ["Sem", "Ivo"])
	# oude save (v0.20-) zonder "party_bank", 3 helden: ongewijzigd, lege reserve
	var oud := ruw.duplicate(true)
	oud.erase("party_bank")
	oud["party"] = (ruw["party"] as Array).slice(0, 3)
	_write("user://partytest_oud.json", oud)
	geladen = GameState.load_game("user://partytest_oud.json")
	check("oude save zonder party_bank: 3 actief, reserve leeg", geladen and namen(GameState.party) == ["Dax", "Vesper", "Seren"]
			and GameState.party_bench.is_empty())
	# oude save met te veel helden in "party": migratie naar de reserve
	var vol := ruw.duplicate(true)
	vol.erase("party_bank")
	vol["party"] = (ruw["party"] as Array) + (ruw["party_bank"] as Array)
	_write("user://partytest_migratie.json", vol)
	geladen = GameState.load_game("user://partytest_migratie.json")
	check("migratie: 6 helden in party -> 4 actief + 2 reserve (%s | %s)" % [namen(GameState.party), namen(GameState.party_bench)],
			geladen and namen(GameState.party) == ["Dax", "Vesper", "Seren", "Kai"] and namen(GameState.party_bench) == ["Sem", "Ivo"])
	# oude save met party_bank én te veel actief: de extra's komen vóór de bestaande reserve
	var beide := ruw.duplicate(true)
	beide["party"] = (ruw["party"] as Array) + [(ruw["party_bank"] as Array)[0]]
	beide["party_bank"] = [(ruw["party_bank"] as Array)[1]]
	_write("user://partytest_beide.json", beide)
	geladen = GameState.load_game("user://partytest_beide.json")
	check("migratie met bestaande reserve: niemand kwijt (%s | %s)" % [namen(GameState.party), namen(GameState.party_bench)],
			geladen and GameState.party.size() == 4 and namen(GameState.party_bench) == ["Sem", "Ivo"])
	GameState.save_game(Vector2i(3, 3), Vector2i.DOWN, pad)
	check("na migratie opnieuw opgeslagen: party max 4", (GameState.read_save(pad).get("party") as Array).size() == 4)


# ================================================================ deel C: gevecht
func _gevecht_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	# 5 helden in de party (zonder normaliseren: het gevecht moet zelf op 4 stoppen) + 2 monsters
	zes_helden(5)
	for h in GameState.party:
		GameState.give_exp(h, GD.exp_for_level(6))
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	var p1 := GameState.codex_add("mosslijm", 4)
	GameState.codex_add("papiergeest", 3)
	GameState.codex_set_active(str(p1["uid"]))
	var p := player()
	GameState.start_battle(["papiergeest", "glitchmot"], p.get_tile(), p.facing, "archief", false)
	if not await wait_scene_named("Battle"):
		check("gevecht gestart", false)
		return
	var b := battle()
	await wait_battle_state(["command"])
	await pframes(12)
	var helden: Array = b.heroes.filter(func(c): return not c.get("ally", false))
	var monsters: Array = b.heroes.filter(func(c): return c.get("ally", false))
	check("gevecht: 4 helden + 1 monster = 5 combatanten (%s)" % [b.heroes.map(func(c): return c["name"])],
			helden.size() == 4 and monsters.size() == 1 and b.heroes.size() == PartyLimiet.MAX_GEVECHT)
	check("5e held (Sem) vecht niet mee", not b.heroes.any(func(c): return str(c["name"]) == "Sem"))
	check("monster = de actieve Codex-pagina", str(monsters[0].get("page", "")) == str(p1["uid"]) if monsters.size() == 1 else false)
	check("5 statusvakken en 5 figuren", b.status_boxes.size() == 5 and b.hero_nodes.size() == 5)
	var boxes: Array = b.status_boxes
	var rij: Array = boxes.slice(0, 4)
	var zij: Control = boxes[4]
	var onder := true
	var binnen := true
	for bx in rij:
		onder = onder and bx.position.y > b.size.y * 0.7
		binnen = binnen and bx.position.x >= 0.0 and bx.position.x + bx.size.x <= b.size.x
	check("statusrij: 4 heldenvakken onderaan, binnen beeld", onder and binnen and rij.all(func(x): return not bool(x.monster)))
	var los := true
	for i in range(1, rij.size()):
		los = los and rij[i].position.x >= rij[i - 1].position.x + rij[i - 1].size.x
	check("heldenvakken overlappen niet, van links naar rechts", los)
	check("monster heeft geen vak in de rij: zijspeler-label (klein, geen balken)", bool(zij.monster)
			and zij.size == zij.SIDE_SIZE and zij.size.y < rij[0].size.y / 2.0
			and zij.get_rect().end.y <= rij[0].position.y)
	check("monster-icoon van RPG ART geladen (7x6)", zij._monster_icon != null and zij._monster_icon.get_size() == Vector2(7, 6))
	var tc: Node = b.touch
	if tc != null and tc.has_method("b_center"):
		var bc: Vector2 = tc.b_center()
		check("zijspeler boven de B-knop (label %s, B %s)" % [zij.get_rect(), bc], zij.get_rect().end.y <= bc.y - tc.button_radius
				and absf(zij.get_rect().get_center().x - bc.x) < 30.0 and zij.position.x + zij.size.x <= b.size.x)
	var mnode: Control = monsters[0]["node"]
	check("monster-sprite staat boven zijn label", absf(mnode.home.x - zij.get_rect().get_center().x) < 1.5
			and mnode.home.y <= zij.position.y + 0.5)
	check("in het gevecht: monster wisselen uit (Codex-knop 'Swap' grijs)", not b.codex.can_swap())
	check("in het gevecht: party wisselen geweigerd", GameState.in_battle and PartyLimiet.wissel(1, 0) == PartyLimiet.IN_GEVECHT
			and PartyLimiet.kies_monster("") == PartyLimiet.IN_GEVECHT and GameState.codex_active == str(p1["uid"]))
	check("HUD v2: perkamentkaart-art geladen", boxes[0].hud_tex("kaart_normaal") != null and boxes[0].hud_tex("vul_hp") != null)
	check("HUD v2: kaartsoort volgt de staat", boxes.all(func(x): return x.card_kind() in ["normaal", "actief", "doelwit", "ko"]))
	await screenshot("party_gevecht_5_plekken")
	# één ronde: iedereen verdedigt, vijanden doen weinig; daarna de beurtvolgorde bekijken
	for e in b.enemies:
		e["s"]["max_hp"] = 999
		e["s"]["hp"] = 999
		e["s"]["atk"] = 0
	b.codex.force_skill = "attack"
	for i in 4:
		await defend(b)
	await wait_until(func(): return not b.last_plan.is_empty(), 20.0)
	var spelers: Array = b.last_plan.map(func(a): return a["actor"])
	var held_acties := spelers.filter(func(c): return b.heroes.has(c))
	var vijand_acties := spelers.filter(func(c): return b.enemies.has(c))
	check("beurtvolgorde: %d acties, alleen actieve combatanten (%s)" % [spelers.size(), spelers.map(func(c): return c["name"])],
			spelers.size() == held_acties.size() + vijand_acties.size() and held_acties.size() == 5
			and not spelers.any(func(c): return str(c["name"]) == "Sem"))
	check("beurtvolgorde: het monster telt mee, max 5 aan onze kant", held_acties.filter(func(c): return c.get("ally", false)).size() == 1)
	await flee(b)
	check("gevecht voorbij", battle() == null and not GameState.in_battle)


# ================================================================ deel D: veldmenu
func field_menu() -> Node:
	var s := scene()
	return s.get_node_or_null("FieldMenu") if s != null else null


func _menu_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	zes_helden(6)
	PartyLimiet.normaliseer()
	var p1 := GameState.codex_add("mosslijm", 4)
	var p2 := GameState.codex_add("papiergeest", 3)
	GameState.codex_set_active(str(p1["uid"]))
	var m: Node = null
	for poging in 10:
		await tap("menu")
		await frames(3)
		m = field_menu()
		if m != null:
			break
		await pframes(20)
	check("veldmenu open, knop 'Party' aanwezig", m != null and m.buttons.has("party"))
	if m == null:
		return
	await pframes(3)
	# r7-3 #5: Warp in een Diepe Grot-run weigert met een melding en wisselt niet van map.
	GameState.dungeon100_floor = 1
	m.open_warp()
	check("Warp geweigerd in Diepe Grot-run (melding '%s')" % m.message_label.text,
		m.message_label.text == m.WARP_IN_RUN and not GameState.changing_map and scene().scene_file_path == GOLEM_SCENE)
	GameState.dungeon100_floor = 0
	m.message_label.visible = false
	check("Warpen compact (%s), Party eronder, tikhoogte >= 16" % m.buttons["warp"].size, m.buttons["warp"].size.y >= 16.0
			and m.buttons["warp"].size.y < m.buttons["equip"].size.y and m.buttons["party"].position.y > m.buttons["warp"].position.y)
	await screenshot("party_veldmenu")
	await click(m.buttons["party"])
	await pframes(4)
	var s: Node = m.sub
	check("Party-scherm open", s != null and s.get_script() == PartyScreen)
	if s == null:
		return
	check("4 heldenplekken + 1 monsterplek, reserve 2 helden + 1 monster",
			s.actief_knoppen.size() == 4 and s.monster_knop != null and s.reserve_held_knoppen.size() == 2
			and s.reserve_monster_knoppen.size() == 1 and str(s.monster_knop.get_meta("label")).contains(str(p1["name"])))
	var r := Rect2(Vector2.ZERO, s.root.size)
	var binnen := true
	for bt in s.actief_knoppen + [s.monster_knop] + s.reserve_held_knoppen + s.reserve_monster_knoppen:
		binnen = binnen and r.encloses(bt.get_global_rect()) and bt.size.y >= s.ROW_H
	check("alle regels binnen beeld en >= 16 hoog", binnen)
	await screenshot("party_menu")
	# via tikken: Noor (actief 1) en Sem (reserve 0) ruilen
	await click(s.actief_knoppen[1])
	check("held gemarkeerd", s.gekozen == 1)
	await click(s.reserve_held_knoppen[0])
	check("gewisseld via het scherm: Sem actief, Vesper in de reserve (%s)" % s.laatste_tekst,
			str(GameState.party[1]["name"]) == "Sem" and str(GameState.party_bench[0]["name"]) == "Vesper" and s.gekozen == -1)
	await click(s.reserve_monster_knoppen[0])
	check("monster gewisseld via het scherm", GameState.codex_active == str(p2["uid"])
			and str(s.monster_knop.get_meta("label")).contains(str(p2["name"])))
	await pframes(3)
	await screenshot("party_menu_gewisseld")
	await click(s.actief_knoppen[0])
	await click(s.actief_knoppen[0])
	check("Dax 2x tikken: blijft (melding)", s.laatste_tekst == PartyLimiet.DENNIS_BLIJFT and str(GameState.party[0]["id"]) == "dennis")
	s.back()
	await pframes(3)
	check("B sluit het scherm", m.sub == null)
	# v0.22 (Dennis): Magic weer direct in het veldmenu (geen tussenstap); genezen werkt buiten gevechten
	check("veldmenu: knop 'Magic' in de linkerkolom", m.buttons.has("magic")
			and is_equal_approx(m.buttons["magic"].position.x, m.buttons["equip"].position.x)
			and m.buttons["magic"].position.y > m.buttons["items"].position.y)
	var dennis: Dictionary = GameState.party[0]
	dennis["hp"] = maxi(1, int(dennis["max_hp"]) / 3)
	await click(m.buttons["magic"])
	await pframes(4)
	var ms: Node = m.sub
	check("tik op Magic opent meteen het Magie-scherm", ms != null and ms.name == "Magic")
	if ms != null:
		var li := -1
		for i in GameState.party.size():
			if str(GameState.party[i]["id"]) == "lotte":
				li = i
		ms.show_caster(li)
		await pframes(3)
		check("Seren: genezing niet grijs in het veld", ms.entries.size() > 0 and not ms.is_greyed(0))
		await screenshot("veldmenu_magic")
		var hp0 := int(dennis["hp"])
		var genees_r: Dictionary = PartyActions.cast_spell(GameState.party[li], "genees", dennis)
		check("genezen buiten het gevecht: Dax %d -> %d HP" % [hp0, int(dennis["hp"])], bool(genees_r["ok"]) and int(dennis["hp"]) > hp0)
		ms.close()
		await pframes(3)
	# v0.22 (Dennis): Settings en Load in het veldmenu
	check("veldmenu: Settings en Load rechts onder Party, binnen beeld", m.buttons.has("options") and m.buttons.has("load")
			and m.buttons["options"].position.y > m.buttons["party"].position.y
			and m.buttons["load"].position.y > m.buttons["options"].position.y
			and Rect2(Vector2.ZERO, m.root.size).encloses(m.buttons["load"].get_global_rect())
			and m.buttons["load"].size.y >= 16.0)
	await screenshot("veldmenu_knoppen")
	await click(m.buttons["options"])
	await pframes(4)
	check("Settings opent het Opties-scherm", m.sub != null and m.sub.name == "Options")
	if m.sub != null:
		m.sub.close()
		await pframes(4)
	var opgeslagen := GameState.save_game(player().get_tile(), player().facing)
	var naam_voor := str(GameState.party[1]["name"])
	GameState.party[1]["name"] = "Gewijzigd"
	await click(m.buttons["load"])
	await pframes(6)
	var ls: Node = m.sub
	check("Load opent de slotlijst", opgeslagen and ls != null and ls.name == "Load" and ls.list != null
			and not ls.list.slot_buttons[0].disabled)
	if ls != null:
		await click(ls.list.slot_buttons[0])
		await pframes(4)
		check("slot kiezen vraagt eerst om bevestiging ('No' heeft de focus)", ls.prompt != null
				and ls.prompt.no_button.has_focus() and ls.prompt.detail == ls.DETAIL)
		await screenshot("veldmenu_laden_bevestigen")
		if ls.prompt != null:
			await click(ls.prompt.no_button)
			await pframes(3)
		check("'No': niets geladen, lijst blijft open", ls.result == "declined" and str(GameState.party[1]["name"]) == "Gewijzigd"
				and is_instance_valid(ls) and m.sub == ls)
		ls.close()
		await pframes(4)
	check("terug in het veldmenu", m.sub == null)
	GameState.party[1]["name"] = naam_voor
	# in een gevecht opent het scherm niet
	GameState.in_battle = true
	m.open_party()
	GameState.in_battle = false
	await pframes(2)
	check("veldmenu > Party geweigerd tijdens een gevecht", m.sub == null and m.message_label.text == PartyLimiet.IN_GEVECHT)
	m.close()
	await pframes(3)
	# Load > slot 1 > 'Yes': de save wordt geladen (voortgang erna is weg)
	GameState.party[1]["name"] = "Gewijzigd"
	m = null
	for poging in 10:
		await tap("menu")
		await frames(3)
		m = field_menu()
		if m != null:
			break
		await pframes(20)
	if m == null:
		check("veldmenu opnieuw open", false)
		return
	m.open_load()
	await pframes(6)
	var ls2: Node = m.sub
	if ls2 == null:
		check("Load opnieuw open", false)
		return
	ls2._on_picked(1)
	await pframes(3)
	await click(ls2.prompt.yes_button)
	var klaar := func() -> bool: return not GameState.changing_map and scene() != null and scene().scene_file_path == GOLEM_SCENE and field_menu() == null
	await pframes(10)
	var terug: bool = await wait_until(klaar, 15.0)
	await wait_fade()
	check("'Yes': slot geladen, terug op de kaart, niet-opgeslagen wijziging weg (%s)" % str(GameState.party[1]["name"]),
			terug and str(GameState.party[1]["name"]) != "Gewijzigd")


# ================================================================ Deel E: Scenes
const ScenesDataT := preload("res://scripts/data/scenes_data.gd")


func _scenes_tests() -> void:
	# save-roundtrip en migratie (zonder scherm)
	GameState.story_flags.erase(ScenesDataT.WORLDMAP_FLAG)
	GameState.story_flags.erase(ScenesDataT.HANGER_FLAG)
	for cf in [ScenesDataT.CANON_GENEZER_FLAG, ScenesDataT.CANON_HANGER_FLAG, ScenesDataT.CANON_DREIGING_FLAG]:
		GameState.story_flags.erase(cf)
	GameState.scenes_seen = []
	check("scenes: lijst = alleen de video-cutscenes (%s)" % [ScenesDataT.ids()], ScenesDataT.ids() == ["wereldkaart", "ww_warper"]
			and GameState.seen_scenes().is_empty())
	GameState.mark_scene_seen("ww_warper")
	GameState.mark_scene_seen("hanger")         # v0.24 niet meer in de lijst: telt niet
	GameState.mark_scene_seen("bestaat_niet")
	var pad := "user://partytest_scenes.json"
	var weg := GameState.save_game(Vector2i(3, 3), Vector2i.DOWN, pad)
	var ruw := GameState.read_save(pad)
	check("save: scenes_seen = ['ww_warper'] (%s)" % [ruw.get("scenes_seen")], weg and ruw.get("scenes_seen") == ["ww_warper"])
	GameState.scenes_seen = []
	GameState.story_flags.erase(ScenesDataT.HANGER_FLAG)
	GameState.story_flags.erase(ScenesDataT.CANON_GENEZER_FLAG)
	var ok := GameState.load_game(pad)
	check("load: scenes_seen terug", ok and GameState.scenes_seen == ["ww_warper"] and not GameState.scene_seen("wereldkaart"))
	var oud := ruw.duplicate(true)
	oud.erase("scenes_seen")
	(oud["story"] as Dictionary)["flags"] = [ScenesDataT.WORLDMAP_FLAG]
	_write("user://partytest_scenes_oud.json", oud)
	ok = GameState.load_game("user://partytest_scenes_oud.json")
	check("migratie: oude save zonder scenes_seen, vlag wereldkaart gezet -> gezien (%s)" % [GameState.scenes_seen],
			ok and GameState.scenes_seen == ["wereldkaart"])
	# scherm
	GameState.scenes_seen = []
	GameState.story_flags.erase(ScenesDataT.WORLDMAP_FLAG)
	GameState.story_flags.erase(ScenesDataT.HANGER_FLAG)
	for cf in [ScenesDataT.CANON_GENEZER_FLAG, ScenesDataT.CANON_HANGER_FLAG, ScenesDataT.CANON_DREIGING_FLAG]:
		GameState.story_flags.erase(cf)
	var m: Node = null
	for poging in 10:
		await tap("menu")
		await frames(3)
		m = field_menu()
		if m != null:
			break
		await pframes(20)
	if m == null:
		check("veldmenu open (scenes)", false)
		return
	await pframes(4)
	check("veldmenu: Bestiary en Scenes aanwezig, binnen beeld", m.buttons.has("bestiary") and m.buttons.has("scenes")
			and Rect2(Vector2.ZERO, m.root.size).encloses(m.buttons["bestiary"].get_global_rect())
			and Rect2(Vector2.ZERO, m.root.size).encloses(m.buttons["load"].get_global_rect()))
	var overlap := false
	var ids: Array = m.buttons.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			overlap = overlap or m.buttons[ids[i]].get_global_rect().intersects(m.buttons[ids[j]].get_global_rect())
	check("veldmenu: geen knoppen over elkaar", not overlap)
	await screenshot("veldmenu_scenes_knop")
	await click(m.buttons["bestiary"])
	await pframes(4)
	check("Bestiary opent het bestiarium", m.sub != null and m.sub.name == "Bestiary")
	if m.sub != null:
		m.sub.close()
		await pframes(4)
	await click(m.buttons["scenes"])
	await pframes(4)
	var sc: Node = m.sub
	check("Scenes opent het scenes-scherm", sc != null and sc.name == "Scenes" and sc.buttons.size() == 2)
	if sc == null:
		return
	check("niet bekeken: '???' en op slot", sc.buttons[0].text.ends_with("???") and sc.is_locked(0) and sc.is_locked(1))
	await screenshot("scenes_op_slot")
	sc.choose("wereldkaart")
	await pframes(2)
	check("op slot: speelt niet af", sc.playing == null and sc.message_text() == sc.LOCKED_MSG)
	# bekijken = ontgrendelen (de Hanger-scène zet zelf zijn vlag / mark_scene_seen)
	var h: Node = load("res://world_warper/cutscene/hanger_scene.tscn").instantiate()
	var bron := ScenesDataT.FlagBron.new()
	h.add_child(bron)
	get_tree().root.add_child(h)
	h.maybe_play(bron)
	await pframes(2)
	h._finish()
	h.queue_free()
	await pframes(2)
	check("Hanger-scène speelt nog in het verhaal (vlag gezet), maar staat niet in de lijst; 'The World Warper' nog op slot",
			GameState.story_flags.has(ScenesDataT.HANGER_FLAG) and not GameState.seen_scenes().has("hanger")
			and not GameState.scene_seen("ww_warper") and not GameState.scenes_seen.has("hanger"))
	GameState.story_flags[ScenesDataT.CANON_GENEZER_FLAG] = true     # = WorldWarperGenezerScene na De Genezer
	check("canon: vlag ww_canon_genezer_gezien -> 'The World Warper' ontgrendeld", GameState.scene_seen("ww_warper"))
	WorldmapCutscene.start_on(scene())
	await pframes(2)
	for c in scene().get_children():
		if c is WorldmapCutscene:
			c._finish()
	await pframes(3)
	check("wereldkaart bekeken -> ontgrendeld", GameState.scene_seen("wereldkaart") and GameState.scenes_seen.has("wereldkaart"))
	sc._fill()
	await pframes(2)
	var titels_ok := true
	for i in ScenesDataT.SCENES.size():
		titels_ok = titels_ok and sc.buttons[i].text.ends_with(ScenesDataT.SCENES[i]["title"]) and not sc.is_locked(i)
	check("lijst toont nu de titels (Into the Wide World / The World Warper), geen Hanger/Sapientia", titels_ok
			and sc.buttons.size() == 2 and ScenesDataT.scene("ww_warper")["title"] == "The World Warper"
			and ScenesDataT.scene("hanger").is_empty() and ScenesDataT.scene("ww_hanger").is_empty() and ScenesDataT.scene("ww_sapientia").is_empty())
	var flags_voor: Dictionary = GameState.story_flags.duplicate()
	var map_voor := scene().scene_file_path
	await screenshot("scenes_scherm")
	# herhaling: afspelen en terug naar het scherm
	for id in ["wereldkaart", "ww_warper"]:
		await click(sc.buttons[ScenesDataT.ids().find(id)])
		await pframes(4)
		check("%s: herhaling speelt" % id, sc.playing != null and is_instance_valid(sc.playing))
		if id == "ww_warper":
			await pframes(10)
			var gz: Node = get_tree().root.get_node_or_null("SceneReplay/CanonGenezer")
			var vs: Node = gz.video_speler if gz != null else null
			check("ww_warper: herhaling start met Dax' filmpje (ook als het al gezien is)", vs != null and is_instance_valid(vs)
					and str(vs.video_path).ends_with("genezer_warper.ogv"))
			await get_tree().create_timer(1.5).timeout
			await screenshot("scenes_herhaling_warper_video")
			if vs != null and is_instance_valid(vs):
				vs.skip_now()
			await pframes(30)
			# v0.25 bug Dennis: na het filmpje GEEN tweede (gescripte) cutscene meer; meteen terug in de lijst
			check("ww_warper: na het filmpje geen gescripte scène erachteraan (geen dialoog, geen regels)",
					not Dialog.is_open and (not is_instance_valid(gz) or gz.regels_getoond.is_empty()))
			check("ww_warper: na het filmpje vanzelf terug in de lijst", sc.playing == null)
			await pframes(6)
			check("ww_warper: na terugkomst menu bruikbaar (focus, dialoog dicht en op laag 5, geen restanten)",
					sc.buttons.any(func(b): return b.has_focus()) and not Dialog.is_open and Dialog.layer == 5
					and get_tree().root.get_node_or_null("SceneReplay") == null and get_tree().root.get_node_or_null("SceneReplayWeg") == null)
			await screenshot("scenes_terug_na_warper")
			# en B werkt weer gewoon: het scherm reageert op invoer
			await click(sc.buttons[ScenesDataT.ids().find("ww_warper")])
			await pframes(4)
			check("ww_warper: na terugkomst nog eens af te spelen", sc.playing != null)
		sc.finish_replay()
		await pframes(4)
		check("%s: na afloop terug in Scenes (focus in de lijst)" % id, sc.playing == null and m.sub == sc and is_instance_valid(sc)
				and get_tree().root.get_node_or_null("SceneReplay") == null and sc.buttons.any(func(b): return b.has_focus()))
	check("herhalingen raken het verhaal niet (vlaggen en map gelijk, dialooglaag terug)", GameState.story_flags == flags_voor
			and scene().scene_file_path == map_voor and Dialog.layer == 5 and not Dialog.is_open)
	sc.close()
	await pframes(4)
	check("Scenes dicht: terug in het veldmenu", m.sub == null and m.buttons["scenes"].has_focus())
	m.close()
	await pframes(3)


func tik_scherm() -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = get_tree().root.get_visible_rect().size * Vector2(0.5, 0.3)
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(2)


func click(c: Control) -> void:
	await get_tree().physics_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = get_tree().root.get_final_transform() * c.get_global_rect().get_center()
	ev.global_position = ev.position
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(3)


## Namen-migratie: een oude save met Dennis/Noor/Lotte laadt als Dax/Vesper/Seren (ids gelijk).
func _namen_migratie_tests() -> void:
	var oud := {"map": "res://scenes/maps/wilgendal.tscn", "player_name": "Dennis", "party": [
		{"id": "dennis", "name": "Dennis"}, {"id": "noor", "name": "Noor"}, {"id": "lotte", "name": "Lotte"}]}
	var ok := GameState.apply_state(oud)
	check("namen-migratie: oude save laadt", ok)
	check("namen-migratie: speler heet Dax", GameState.player_name == "Dax")
	check("namen-migratie: party heet Dax/Vesper/Seren (%s)" % namen(GameState.party),
		GameState.party.size() == 3 and GameState.party[0]["name"] == "Dax"
		and GameState.party[1]["name"] == "Vesper" and GameState.party[2]["name"] == "Seren"
		and GameState.party[1]["id"] == "noor" and GameState.party[2]["id"] == "lotte")
	check("namen-migratie: eigen naam blijft", GameState.migrate_name("Kees") == "Kees")
	check("namen-migratie: losse namen", GameState.migrate_name("Dennis") == "Dax" and GameState.migrate_name("Noor") == "Vesper"
		and GameState.migrate_name("Lotte") == "Seren" and GameState.migrate_name("Dax") == "Dax")
	check("nieuw spel: standaardnaam is Dax", GameState.DEFAULT_NAME == "Dax")
	# r7-3 #3: een nieuwe save (met NAMES_KEY) houdt de gekozen naam "Dennis", ook bij herladen.
	check("namen-migratie: state_data schrijft %s" % GameState.NAMES_KEY,
		GameState.state_data(Vector2i.ZERO, Vector2i.DOWN).get(GameState.NAMES_KEY, false) == true)
	var nieuw := oud.duplicate(true)
	nieuw[GameState.NAMES_KEY] = true
	check("namen-migratie: nieuwe save laadt", GameState.apply_state(nieuw))
	check("namen-migratie: nieuwe save houdt 'Dennis' (%s)" % GameState.player_name, GameState.player_name == "Dennis"
		and GameState.party[0]["name"] == "Dennis" and GameState.party[1]["name"] == "Noor")
	var terug := GameState.state_data(Vector2i.ZERO, Vector2i.DOWN)
	check("namen-migratie: save -> load blijft 'Dennis'", GameState.apply_state(terug) and GameState.player_name == "Dennis")
	# r7-3 #1/#2: vluchten of verliezen wist het "after"-event; alleen winst houdt het.
	for r in ["flee", "lose"]:
		Story.after_battle_event = "zingend_zaad_na"
		GameState.battle_ended.emit(r)
		check("after-event gewist na '%s'" % r, Story.after_battle_event == "")
	Story.after_battle_event = "zingend_zaad_na"
	GameState.battle_ended.emit("win")
	check("after-event blijft na 'win'", Story.after_battle_event == "zingend_zaad_na")
	Story.after_battle_event = ""
