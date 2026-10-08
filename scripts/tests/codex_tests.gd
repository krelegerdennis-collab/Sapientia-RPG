extends Node
## ALLEEN VOOR TESTEN - Codex (Kernfragment stap 2): zie HANDOFF_CODEX.md.
## Start:  godot --path . -- --codextest [--shots=/pad/map] [--alleen=ABC]
##   Deel A: data (codex_data.gd geldig, nieuwe soort = alleen data, vangkans-curve, pagina's,
##           dubbele soorten, Codex vol, item Leeg Boek).
##   Deel B: gevecht: Leeg Boek gelukt (effect, pagina, gevecht klaar, geen EXP), mislukt (boek op),
##           baas weigert (boek blijft).
##   Deel C: bondgenoot: staat naast Dennis (rug-sprite), handelt zelf, kan geraakt en KO worden,
##           krijgt EXP + level-up (nieuwe vaardigheid), vluchten werkt nog.
##   Deel D: veldmenu > Codex: lijst, bondgenoot kiezen, 'Geen'.
##   Deel E: save/load (pagina's + actieve bondgenoot), oude save zonder codex, kapotte data.
## Met --shots=map: codex_boek_inschrijven, codex_gevangen, codex_bondgenoot, codex_bondgenoot_aanval,
## codex_levelup, codex_scherm (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const AllyScript := preload("res://scripts/battle/codex_ally.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const ITEM := 2
const VERDEDIG := 3

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
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
		print("=== Deel A: data ===")
		_data_tests()
	if part("B"):
		print("=== Deel B: Leeg Boek in het gevecht ===")
		await _capture_tests()
	if part("C"):
		print("=== Deel C: bondgenoot ===")
		await _ally_tests()
	if part("D"):
		print("=== Deel D: Codex-scherm ===")
		await _screen_tests()
	if part("E"):
		print("=== Deel E: save/load ===")
		await _save_tests()
	print("CODEXTEST %d PASS, %d FAIL" % [passes, failures])
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
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_scene_named(n: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == n and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


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


func setup() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""
	GameState.inventory[CD.BOOK_ITEM] = 3      # v0.17: geen startvoorraad meer; zoals de 3 van Marit (Esdoorn)


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


func _watch(b: Node) -> void:
	var wb: WeakRef = weakref(b)
	var last := ""
	while wb.get_ref() != null:
		var bb: Node = wb.get_ref()
		var t: String = bb.message_label.text
		if t != last:
			last = t
			messages.append(t)
		await get_tree().process_frame


func seen_message(text_part: String) -> bool:
	return messages.any(func(m): return text_part in m)


func start_battle(enemies: Array, boss := false) -> Node:
	var p := player()
	GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", boss)
	if not await wait_scene_named("Battle"):
		return null
	var b := battle()
	messages.clear()
	_watch(b)
	return b


func ally_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c.get("ally", false):
			return c
	return {}


func hero_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c["s"].get("id", "") == GameState.MAIN_HERO:
			return c
	return {}


## Item > Leeg Boek > vijand 'e'.
func use_book(b: Node, e: Dictionary) -> bool:
	if await wait_battle_state(["command"]) != "command":
		return false
	await pframes(4)
	await cross_to(b, ITEM)
	await tap("interact")
	if not await wait_until(func(): return b.menu.visible, 3.0):
		return false
	var k: int = b._available_items().find(CD.BOOK_ITEM)
	if k < 0:
		return false
	b.menu.select(k)
	await pframes(2)
	await tap("interact")
	if await wait_battle_state(["target_enemy"], 5) != "target_enemy":
		return false
	for i in 6:
		if b.target_list[b.target_index] == e:
			break
		await tap("move_right")
	await tap("interact")
	return true


func defend(b: Node) -> void:
	if await wait_battle_state(["command"]) != "command":
		return
	await pframes(4)
	await cross_to(b, VERDEDIG)
	await tap("interact")


## Klik alle berichten weg tot het gevecht klaar is; 'on_page' wordt per overwinningspagina aangeroepen.
func finish(on_page := Callable()) -> void:
	for guard in 80:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "message_wait":
			if on_page.is_valid() and b.victory_panel.visible:
				await on_page.call(b)
			await tap("interact")
			continue
		for e in b.enemies:
			if int(e["s"]["hp"]) > 1:
				e["s"]["hp"] = 1
		await cross_to(b, 0)
		await tap("interact")
		if await wait_battle_state(["target_enemy", "busy", "message_wait"], 5) == "target_enemy":
			await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


func flee(b: Node) -> void:
	var wb: WeakRef = weakref(b)
	for i in 8:
		if wb.get_ref() == null or battle() == null:
			break
		if await wait_battle_state(["command"], 30) != "command":
			break
		b.can_flee = true
		b.cross.enabled[4] = true
		await cross_to(b, 4)
		await tap("interact")
		await pframes(8)
		await wait_until(func(): return battle() == null or wb.get_ref() == null or (wb.get_ref() as Node).state == "command", 15.0)
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


# ================================================================ deel A: data
func _data_tests() -> void:
	var errs := CD.validate()
	check("CodexData.validate zonder fouten %s" % [errs], errs.is_empty())
	for id in ["mosslijm", "papiergeest", "glitchmot", "kennis_beest"]:
		var s := CD.species(id)
		check("soort %s: basis = ENEMIES (HP %d), groei, leert, AI, voor+rug, element, fusie-labels" % [id, CD.base_stats(id)["max_hp"]],
				not s.is_empty() and CD.base_stats(id)["max_hp"] == int(GD.ENEMIES[s["enemy"]]["max_hp"])
				and s["growth"].has("atk") and not CD.skills_at(id, 1).is_empty() and s["ai"].has("target")
				and str(s["front"]) == str(GD.ENEMIES[s["enemy"]]["sprite"]) and str(s["back"]) == str(GD.ENEMIES[s["enemy"]].get("sprite_back", ""))
				and str(s["back"]).ends_with("/%s_rug.png" % id) and ResourceLoader.exists(str(s["back"]))
				and (load(str(s["back"])) as Texture2D).get_size() == (load(str(s["front"])) as Texture2D).get_size()
				and str(s["element"]) != "" and (s["fusion_tags"] as Array).size() > 0)
	# nieuwe soort = alleen data: een regel met alleen "enemy" krijgt overal standaardwaarden
	check("art van RPG ART aanwezig: icoon 16x16, effect 192x48 (4x 48x48)", ResourceLoader.exists(CD.BOOK_ICON)
			and (load(CD.BOOK_ICON) as Texture2D).get_size() == Vector2(16, 16) and ResourceLoader.exists(CD.INSCRIBE_EFFECT)
			and (load(CD.INSCRIBE_EFFECT) as Texture2D).get_size() == Vector2(192, 48))
	check("Kennis-Beest als bondgenoot kleiner (ally_scale 0,75), effect 2x", is_equal_approx(float(CD.species("kennis_beest")["ally_scale"]), 0.75)
			and is_equal_approx(float(CD.species("kennis_beest")["fx_scale"]), 2.0) and is_equal_approx(float(CD.species("mosslijm")["ally_scale"]), 1.0))
	# v0.17 Donker Woud: 3 nieuwe soorten via data, De Wortelkoning (baas) niet te vangen
	for id in ["wortelkruiper", "mistuil", "sporenzwam"]:
		var ws := CD.species(id)
		check("v17 soort %s: basis = ENEMIES, rug = sprite_back (bestaat), leert op Lv 1" % id, not ws.is_empty()
				and CD.base_stats(id)["max_hp"] == int(GD.ENEMIES[id]["max_hp"]) and str(ws["back"]) == str(GD.ENEMIES[id]["sprite_back"])
				and ResourceLoader.exists(str(ws["back"])) and not CD.skills_at(id, 1).is_empty())
	check("De Wortelkoning: geen Codex-soort, kans 0 (ook buiten een baasgevecht)", CD.species_for_enemy("wortelkoning") == ""
			and CD.capture_chance("wortelkoning", 1, 440) == 0.0 and CD.capture_chance("wortelkoning", 1, 440, true) == 0.0)
	var mini := CD.species_from("nieuw", {"enemy": "moskonijn"})
	check("nieuwe soort met alleen {'enemy'}: standaard groei/leert/AI, rug uit ENEMIES (moskonijn: geen -> plaatsvervanger)", mini["growth"] == CD.DEFAULT_GROWTH
			and mini["learn"] == CD.DEFAULT_LEARN and mini["ai"]["target"] == CD.DEFAULT_AI["target"]
			and mini["back"] == "" and mini["name"] == "Moskonijn" and mini["capturable"] == true)
	check("onbekende vijand -> geen soort", CD.species_from("x", {"enemy": "bestaat_niet"}).is_empty() and CD.species_for_enemy("bestaat_niet") == "")
	# vangkans-curve
	var curve: Array = []
	for hp in [16, 12, 8, 4, 1]:
		curve.append(CD.capture_chance("papiergeest", hp, 16))
	var rising := true
	for i in range(1, curve.size()):
		rising = rising and curve[i] > curve[i - 1]
	check("vangkans stijgt als de HP daalt %s" % [curve.map(func(c): return snappedf(c, 0.01))], rising)
	check("volle HP ~2%%, halve ~35%%, 1 HP > 80%%, nooit > 95%%", is_equal_approx(curve[0], CD.CAPTURE_MIN)
			and absf(curve[2] - 0.349) < 0.01 and curve[4] > 0.8 and CD.capture_chance("papiergeest", 0, 16) <= CD.CAPTURE_MAX)
	check("baas: kans 0", CD.capture_chance("kennis_beest", 1, 400, true) == 0.0)
	check("capture_rate: Kennis-Beest lager (x0,6)", is_equal_approx(CD.capture_chance("kennis_beest", 1, 46), CD.capture_chance("mosslijm", 1, 46) * 0.6))
	# pagina's
	var p3 := CD.make_page("mosslijm", 3, "codex_x")
	var st3 := CD.stats_at("mosslijm", 3)
	check("pagina Lv 3: stats = basis + 2x groei, Mosheling geleerd, fusievelden", p3["max_hp"] == 10 + 2 * 5 and p3["max_hp"] == st3["max_hp"]
			and p3["skills"] == ["slijmklodder", "mosheling"] and p3["exp"] == GD.exp_for_level(3)
			and p3["fusion"] == {"generation": 0, "parents": []} and p3["element"] == "natuur")
	GameState.new_game("Dennis")
	var a := GameState.codex_add("mosslijm")
	var b2 := GameState.codex_add("mosslijm")
	check("dubbele soort: 2 pagina's met eigen uid, de eerste wordt bondgenoot", GameState.codex_pages.size() == 2
			and a["uid"] != b2["uid"] and GameState.codex_active == a["uid"])
	for i in CD.MAX_PAGES:
		GameState.codex_add("glitchmot")
	check("Codex vol na %d pagina's" % CD.MAX_PAGES, GameState.codex_pages.size() == CD.MAX_PAGES and GameState.codex_full()
			and GameState.codex_add("glitchmot").is_empty())
	GameState.new_game("Dennis")
	check("nieuw spel: lege Codex, geen bondgenoot", GameState.codex_pages.is_empty() and GameState.codex_active == "")
	var it: Dictionary = GD.ITEMS.get(CD.BOOK_ITEM, {})
	check("item Leeg Boek: op een vijand, alleen in gevecht, NIET in de startvoorraad (v0.17: van Marit + woudkisten)", it.get("target") == "enemy"
			and it.get("field") == false and it.get("capture") == true and GameState.item_count(CD.BOOK_ITEM) == 0
			and not GD.START_INVENTORY.has(CD.BOOK_ITEM))
	# EXP-groei
	var p := CD.make_page("papiergeest", 1, "codex_y")
	var msgs := CD.give_exp(p, GD.exp_for_level(4))
	check("EXP -> Lv 4 + Papierstorm geleerd %s" % [msgs], p["level"] == 4 and p["skills"].has("papierstorm")
			and p["atk"] == CD.stats_at("papiergeest", 4)["atk"] and msgs.size() == 4)


# ================================================================ deel B: vangen
func _capture_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	check("Golemhal geladen", room != null)
	if room == null:
		return
	var exp0: int = GameState.party[0]["exp"]
	# 1) gelukt
	var b := await start_battle(["mosslijm"])
	check("gevecht gestart, geen bondgenoot (Codex leeg)", b != null and b.heroes.size() == 1 and b.codex != null)
	if b == null:
		return
	var e: Dictionary = b.enemies[0]
	await wait_battle_state(["command"])
	e["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	check("Item-menu bevat 'Leeg Boek x3'", b._available_items().has(CD.BOOK_ITEM))
	check("Leeg Boek gekozen op Mosslijm", await use_book(b, e))
	check("inschrijf-effect speelt (art van RPG ART)", await wait_until(func(): return b.codex.fx_node != null and is_instance_valid(b.codex.fx_node), 6.0)
			and b.codex.fx_node.get_script() != null and b.codex.fx_node.has_method("setup"))
	await wait_until(func(): return b.codex.fx_node == null or int(b.codex.fx_node.get("frame")) >= 2, 2.0)
	await screenshot("codex_boek_inschrijven")
	check("bericht: ingeschreven in de Codex", await wait_until(func(): return seen_message("ingeschreven in de Codex"), 6.0))
	await pframes(6)
	await screenshot("codex_gevangen")
	check("vangkans bij 1/10 HP %.2f (> 0,8), resultaat 'gelukt'" % float(b.codex.last_capture.get("chance", 0.0)),
			b.codex.last_capture.get("result") == "gelukt" and float(b.codex.last_capture["chance"]) > 0.8)
	check("monster weg uit het gevecht (captured, geen 'verslagen')", e.get("captured", false) and int(e["s"]["hp"]) == 0
			and GameState.defeated_count("mosslijm") == 0)
	await finish()
	check("gevecht klaar als 'win' (laatste vijand), terug op de kaart", GameState.last_battle_result == "win" and scene().scene_file_path == GOLEM_SCENE)
	check("1 pagina: Mosslijm Lv 1, HP %d, Slijmklodder; meteen bondgenoot" % (GameState.codex_pages[0]["max_hp"] if not GameState.codex_pages.is_empty() else -1),
			GameState.codex_pages.size() == 1 and GameState.codex_pages[0]["species"] == "mosslijm" and GameState.codex_pages[0]["level"] == 1
			and GameState.codex_pages[0]["skills"] == ["slijmklodder"] and GameState.codex_active == GameState.codex_pages[0]["uid"])
	check("boek op (2 over), geen EXP voor een ingeschreven monster", GameState.item_count(CD.BOOK_ITEM) == 2 and GameState.party[0]["exp"] == exp0)
	# 2) mislukt (volle HP, vaste worp 0,999)
	b = await start_battle(["papiergeest"])
	if b == null:
		check("gevecht 2 gestart", false)
		return
	e = b.enemies[0]
	await wait_battle_state(["command"])
	b.codex.force_roll = 0.999
	await use_book(b, e)
	check("mislukt: 'Het boek blijft leeg'", await wait_until(func(): return seen_message("Het boek blijft leeg"), 8.0))
	check("mislukt: boek toch op (1 over), monster blijft, geen pagina", GameState.item_count(CD.BOOK_ITEM) == 1
			and not e.get("captured", false) and int(e["s"]["hp"]) > 0 and GameState.codex_pages.size() == 1
			and is_equal_approx(float(b.codex.last_capture["chance"]), CD.CAPTURE_MIN))
	await finish()
	# 3) baas weigert (boek blijft)
	b = await start_battle(["kennis_beest"], true)
	if b == null:
		check("baasgevecht gestart", false)
		return
	e = b.enemies[0]
	await wait_battle_state(["command"])
	check("baasgevecht: bondgenoot doet mee, niet vluchten", not ally_c(b).is_empty() and not b.can_flee)
	e["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	await use_book(b, e)
	check("baas: 'te machtig' (duidelijke melding)", await wait_until(func(): return seen_message("te machtig"), 8.0))
	check("baas: boek blijft (1), geen pagina, baas staat nog", GameState.item_count(CD.BOOK_ITEM) == 1
			and GameState.codex_pages.size() == 1 and int(e["s"]["hp"]) > 0 and b.codex.last_capture.get("result") == "baas")
	e["s"]["hp"] = 400
	await flee(b)
	check("baas: weggevlucht (test), terug op de kaart", not GameState.in_battle)


# ================================================================ deel C: bondgenoot
func _ally_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golemhal geladen", false)
		return
	var page := GameState.codex_add("mosslijm", 2)
	page["exp"] = GD.exp_for_level(2)
	var b := await start_battle(["papiergeest", "glitchmot"])
	if b == null:
		check("gevecht gestart", false)
		return
	await wait_battle_state(["command"])
	await pframes(10)
	var a := ally_c(b)
	var h := hero_c(b)
	check("bondgenoot in het gevecht: 2 combatanten, 2 statusvakken", not a.is_empty() and b.heroes.size() == 2 and b.status_boxes.size() == 2
			and a["s"] == page)
	if a.is_empty():
		return
	var node: Control = a["node"]
	check("naast Dennis (rechts ervan, zelfde hoogte), echte rug-sprite van ART (geen plaatsvervanger)", node.get_script() == AllyScript and not node.placeholder
			and node.texture_path == str(GD.ENEMIES["mosslijm"]["sprite_back"])
			and node.home.x > h["node"].home.x and absf(node.home.y - h["node"].home.y) < 1.0
			and (node.placeholder == not ResourceLoader.exists(str(GD.ENEMIES["mosslijm"].get("sprite_back", "")))))
	var feet_row: float = node.art_rect(node.home).end.y - node.home.y
	check("anker: voeten op rij H-6 van het plaatje (%.1f eenheden onder de voeten)" % feet_row, absf(feet_row - CD.FEET_FROM_BOTTOM * CD.ALLY_ART_SCALE) < 1.01)
	check("Dennis kiest, de bondgenoot niet (kruis staat bij Dennis)", b.current_hero == h["row"])
	await screenshot("codex_bondgenoot")
	# handelt zelf: Dennis verdedigt, de bondgenoot valt aan
	b.codex.force_skill = "slijmklodder"
	b.codex.last_ally_action = {}
	var hp_before: int = b.enemies.map(func(x): return int(x["s"]["hp"])).reduce(func(s, v): return s + v, 0)
	for x in b.enemies:
		x["s"]["hp"] = 200
		x["s"]["max_hp"] = 200
		x["s"]["atk"] = 0      # vijanden doen (bijna) niets: de bondgenoot moet aan de beurt komen
	hp_before = 400
	await defend(b)
	var acted := await wait_until(func(): return not b.codex.last_ally_action.is_empty(), 15.0)
	check("bondgenoot handelt zelf (Slijmklodder) %s" % [b.codex.last_ally_action], acted and b.codex.last_ally_action.get("skill") == "slijmklodder")
	await pframes(9)
	await screenshot("codex_bondgenoot_aanval")
	await wait_battle_state(["command"], 30)
	var hp_after: int = b.enemies.map(func(x): return int(x["s"]["hp"])).reduce(func(s, v): return s + v, 0)
	check("vijanden nemen schade van de bondgenoot (%d -> %d)" % [hp_before, hp_after], hp_after < hp_before
			and seen_message("%s: Slijmklodder!" % page["name"]))
	# kan geraakt worden
	var ahp := int(page["hp"])
	b._hit(a, 3)
	check("bondgenoot geraakt: HP %d -> %d (zelfde HP als de pagina)" % [ahp, int(page["hp"])], int(page["hp"]) == ahp - 3)
	# AI genezen: HP laag -> Mosheling (Lv 3) ... deze is Lv 2: kent het nog niet
	check("Lv 2 kent nog geen Mosheling", not (page["skills"] as Array).has("mosheling"))
	# KO
	b._hit(a, 999)
	await b._report_kos([a])
	check("bondgenoot KO (grijs, plat), Dennis vecht door", int(page["hp"]) == 0 and node.is_ko and b.state != "lose")
	b.codex.last_ally_action = {}
	await defend(b)
	await wait_battle_state(["command"], 30)
	check("KO-bondgenoot doet niets meer, geen game over", b.codex.last_ally_action.is_empty() and battle() != null)
	check("KO-bondgenoot staat niet in de keuze 'Op wie?' (alleen levenden)", b._alive(b.heroes).size() == 1)
	await finish()
	check("na het gevecht: bondgenoot weer op met 1 HP (zoals de helden)", int(page["hp"]) == 1)
	# EXP + level-up
	page["hp"] = page["max_hp"]
	b = await start_battle(["papiergeest"])
	if b == null:
		check("gevecht 3 gestart", false)
		return
	await wait_battle_state(["command"])
	b.enemies[0]["s"]["exp"] = GD.exp_for_level(3) - GD.exp_for_level(2) + 5
	var lv0 := int(page["level"])
	var atk0 := int(page["atk"])
	var got_page := [false]
	await finish(func(bb: Node):
		if (str(page["name"]) + " is nu level") in str(bb.victory_label.text) and not got_page[0]:
			got_page[0] = true
			await pframes(4)
			await screenshot("codex_levelup"))
	check("bondgenoot krijgt EXP en gaat naar Lv 3 (ATK %d -> %d)" % [atk0, int(page["atk"])], int(page["level"]) == lv0 + 1
			and int(page["atk"]) == CD.stats_at("mosslijm", 3)["atk"])
	check("level-up-pagina na de winst + nieuwe vaardigheid Mosheling", got_page[0] and (page["skills"] as Array).has("mosheling"))
	# AI geneest bij lage HP (Mosheling, Lv 3)
	b = await start_battle(["papiergeest"])
	if b == null:
		return
	await wait_battle_state(["command"])
	for x in b.enemies:
		x["s"]["hp"] = 200
		x["s"]["max_hp"] = 200
		x["s"]["atk"] = 0
	GameState.party[0]["hp"] = 3
	b.codex.last_ally_action = {}
	await defend(b)
	var healed := await wait_until(func(): return not b.codex.last_ally_action.is_empty(), 15.0)
	check("AI: Dennis bijna KO -> bondgenoot geneest met Mosheling %s" % [b.codex.last_ally_action], healed
			and b.codex.last_ally_action.get("skill") == "mosheling" and b.codex.last_ally_action.get("target") == GameState.party[0]["name"])
	await wait_battle_state(["command"], 30)
	check("Dennis is genezen (HP %d > 3)" % int(GameState.party[0]["hp"]), int(GameState.party[0]["hp"]) > 3)
	# vluchten werkt nog met een bondgenoot erbij
	await flee(b)
	check("vluchten met bondgenoot: gevecht klaar ('flee')", GameState.last_battle_result == "flee" and not GameState.in_battle)
	# Kennis-Beest als bondgenoot: kleiner dan 1:1 (ally_scale 0,75)
	var kb := GameState.codex_add("kennis_beest", 5)
	GameState.codex_set_active(kb["uid"])
	b = await start_battle(["papiergeest"])
	if b == null:
		return
	await wait_battle_state(["command"])
	await pframes(10)
	var kn: Control = ally_c(b)["node"]
	var kh: float = kn.art_rect(kn.home).size.y
	check("Kennis-Beest als bondgenoot: %.1f eenheden hoog (= 182 x 0,375), echte art" % kh, not kn.placeholder and absf(kh - 182.0 * 0.375) < 0.6)
	await screenshot("codex_bondgenoot_kennisbeest")
	await flee(b)


# ================================================================ deel D: Codex-scherm
func field_menu() -> Node:
	var s := scene()
	return s.get_node_or_null("FieldMenu") if s != null else null


func _screen_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golemhal geladen", false)
		return
	await tap("menu")
	await frames(3)
	var m := field_menu()
	check("veldmenu open, zonder pagina's geen 'Codex'", m != null and not m.buttons.has("codex"))
	if m:
		m.close()
	await pframes(6)
	var p1 := GameState.codex_add("mosslijm", 3)
	var p2 := GameState.codex_add("glitchmot", 2)
	GameState.codex_add("kennis_beest", 5)
	p2["hp"] = 7
	await tap("menu")
	await frames(3)
	m = field_menu()
	if m == null:
		check("veldmenu open", false)
		return
	var labels: Array = m.commands().map(func(c): return str(m.buttons[c[0]].get_meta("label")))
	check("menu: 'Codex' na 'Status' %s" % [labels], labels == ["Items", "Magie", "Uitrusting", "Status", "Codex", "Bestiarium", "Opties", "Opslaan", "Sluiten"])
	check("menuvensters overlappen niet (9 regels)", not m.command_box.get_global_rect().intersects(m.info_box.get_global_rect()))
	m.choose("codex")
	await frames(3)
	var s: Node = m.get_node_or_null("Codex")
	check("'Codex' opent het Codex-scherm", s != null)
	if s == null:
		return
	var texts: Array = []
	for i in s.entries.size():
		texts.append(s.entry_text(i))
	check("lijst: 3 pagina's + 'Geen', '*' = bondgenoot %s" % [texts], s.entries.size() == 4 and texts[0].begins_with("* Mosslijm")
			and "Lv3" in texts[0] and "Kennis-Beest" in texts[2] and texts[3].ends_with("Geen bondgenoot") and s.entries[0].has_focus())
	check("details: level, stats, vaardigheden", "Lv 3" in s.name_label.text and "ATK %d" % int(p1["atk"]) in s.stats_label.text
			and "Mosheling" in s.skills_label.text and "Vecht mee" in s.state_label.text)
	check("tikvlakken >= 16 hoog (mobiel)", s.entries.all(func(x): return x.size.y >= 16))
	await tap("move_down")
	await tap("interact")
	await frames(2)
	check("A op Glitchmot: nu de bondgenoot", GameState.codex_active == p2["uid"] and s.entry_text(1).begins_with("* Glitchmot")
			and s.entry_text(0).begins_with("  Mosslijm") and "HP 7/" in s.stats_label.text)
	await screenshot("codex_scherm")
	await click(s.entries[3])
	check("tik op 'Geen bondgenoot': niemand vecht mee", GameState.codex_active == "" and s.entry_text(3).begins_with("* Geen"))
	await click(s.entries[0])
	check("tik op Mosslijm: weer bondgenoot", GameState.codex_active == p1["uid"])
	await tap("cancel")
	await frames(3)
	check("B: terug naar het menu, focus op 'Codex'", m.get_node_or_null("Codex") == null and m.buttons["codex"].has_focus())
	m.close()
	await pframes(4)


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


# ================================================================ deel E: save/load
func _save_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golemhal geladen", false)
		return
	GameState.codex_add("mosslijm", 3)
	var p2 := GameState.codex_add("papiergeest", 4)
	p2["hp"] = 5
	GameState.codex_set_active(p2["uid"])
	var p := player()
	check("opslaan", GameState.save_game(p.get_tile(), p.facing))
	var raw := GameState.read_save(GameState.save_path)
	check("save bevat 'codex' (2 pagina's, actief, teller)", raw.get("codex", {}).get("pages", []).size() == 2
			and raw["codex"]["active"] == p2["uid"] and int(raw["codex"]["next"]) == 3)
	GameState.new_game("Dennis")
	check("nieuw spel: Codex leeg", GameState.codex_pages.is_empty())
	check("laden", GameState.load_game())
	var q := GameState.codex_page(p2["uid"])
	check("na laden: 2 pagina's, Papiergeest Lv 4 HP 5, Papierstorm, actief", GameState.codex_pages.size() == 2 and not q.is_empty()
			and q["level"] == 4 and q["hp"] == 5 and (q["skills"] as Array).has("papierstorm") and GameState.codex_active == p2["uid"])
	check("na laden: nieuwe pagina krijgt een nieuwe uid", GameState.codex_add("glitchmot")["uid"] == "codex_0003")
	# oude save (v16) zonder codex
	raw.erase("codex")
	_write(GameState.save_path, raw)
	check("oude save zonder 'codex' laadt: lege Codex", GameState.load_game() and GameState.codex_pages.is_empty() and GameState.codex_active == "")
	# kapotte codex-data
	raw["codex"] = {"pages": [{"uid": "codex_0007", "species": "mosslijm", "level": "x", "hp": "kapot"}, {"species": "bestaat_niet", "uid": "codex_0008"},
			"onzin", {"uid": "codex_0007", "species": "glitchmot"}], "active": "codex_0099", "next": "?"}
	_write(GameState.save_path, raw)
	var ok := GameState.load_game()
	check("kapotte codex: alleen de geldige pagina, geen bondgenoot, teller na de hoogste uid", ok and GameState.codex_pages.size() == 1
			and GameState.codex_pages[0]["level"] == 1 and GameState.codex_pages[0]["hp"] == GameState.codex_pages[0]["max_hp"]
			and GameState.codex_active == "" and GameState.codex_next_id == 8)
	raw["codex"] = "geen dict"
	_write(GameState.save_path, raw)
	check("codex = geen Dictionary: laadt, lege Codex", GameState.load_game() and GameState.codex_pages.is_empty())
	# game over: monsters ook genezen
	GameState.codex_add("mosslijm")
	GameState.codex_pages[0]["hp"] = 0
	GameState.respawn()
	check("game over (respawn): pagina's volledig genezen", GameState.codex_pages[0]["hp"] == GameState.codex_pages[0]["max_hp"])
	# rusten bij een HP-/savepunt-boek: monsters ook vol
	GameState.codex_pages[0]["hp"] = 1
	var bp: Node = load("res://scripts/book_point.gd").new()
	bp.info = {"hp": true, "mp": true}
	bp.restore()
	bp.free()
	check("HP-boek / savepunt: Codex-monsters ook vol", GameState.codex_pages[0]["hp"] == GameState.codex_pages[0]["max_hp"])


func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
