extends Node
## Berggrot-monsters in Bestiarium en Codex (WM1-stabiliteitsfix): Stone Louse, Drip Slug, Vein Moth.
## Start:  godot --path . -- --berggrotdextest [--shots=/pad/map]
##   Deel A: data (bestiariumnummers, art bestaat al, Diepe Grot-pool, ENEMIES blijft ongewijzigd).
##   Deel B: bestiarium (gezien/verslagen registreren, lijst en detailscherm, save/load).
##   Deel C: Codex-soorten (validate, stats, vaardigheden, vangkans, pagina, fusie, eindstaat).
##   Deel D: gevecht: gezien/verslagen in de Berggrot, vangen met een Blank Book, ook in de Diepe Grot,
##           en als bondgenoot meevechten.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const BG := preload("res://scripts/data/berggrot_data.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")
const Content := preload("res://scripts/dungeon/dungeon100_content.gd")
const BestiaryScreen := preload("res://scripts/ui/bestiary_screen.gd")
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const ITEM := 2
const IDS := ["steenluis", "druipslak", "adermot"]
const NAMES := {"steenluis": "Stone Louse", "druipslak": "Drip Slug", "adermot": "Vein Moth"}
const NOS := {"steenluis": 43, "druipslak": 44, "adermot": 45}

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(2026)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await get_tree().process_frame
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: bestiarium ===")
	await _bestiary_tests()
	print("=== Deel C: Codex-soorten ===")
	_codex_tests()
	print("=== Deel D: gevecht ===")
	await _battle_tests()
	print("BERGGROTDEXTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func setup() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""
	GameState.inventory[CD.BOOK_ITEM] = 3


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
	print("INFO  screenshot: ", shots.path_join(name + ".png"))


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


func ally_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c.get("ally", false):
			return c
	return {}


## Gevecht in de Berggrot (terrein "berggrot", tier 0) of in de Diepe Grot (floor > 0, terrein "dungeon100").
func start_battle(enemies: Array, floor_nr := 0) -> Node:
	var p := player()
	var terrain := "dungeon100" if floor_nr > 0 else "berggrot"
	GameState.dungeon100_floor = floor_nr
	var tier := Content.tier_for_floor(floor_nr) if floor_nr > 0 else 0
	GameState.start_battle(enemies, p.get_tile(), p.facing, terrain, false, tier)
	if not await wait_scene_named("Battle"):
		return null
	var b := battle()
	messages.clear()
	_watch(b)
	return b


# ================================================================ deel A: data
func _data_tests() -> void:
	check("BerggrotData.MONSTERS heeft precies de drie monsters", BG.MONSTERS.size() == 3
			and IDS.all(func(i): return BG.has_enemy(i)))
	check("ENEMIES blijft ongewijzigd: de grotmonsters staan er niet in (berggrottest-afspraak)",
			IDS.all(func(i): return not GD.ENEMIES.has(i)))
	var nos := {}
	for id in GD.ENEMIES:
		nos[int(GD.ENEMIES[id].get("no", 0))] = id
	for f in EndgameBestiary.ids():
		nos[int(EndgameBestiary.entry(f)["no"])] = f
	for id in IDS:
		var e: Dictionary = BG.enemy(id)
		check("%s: bestiariumdata compleet (zelfde velden als de ENEMIES)" % id, e.has("no") and e.has("mp") and e.has("desc")
				and e.has("habitat") and e.has("drops") and e.has("weak") and e.has("resist") and e.has("exp") and e.has("gold")
				and e.has("max_hp") and e.has("atk") and e.has("def") and e.has("agi") and str(e.get("desc", "")) != "")
		check("%s: naam %s en nummer %d" % [id, NAMES[id], NOS[id]], str(e["name"]) == NAMES[id] and int(e["no"]) == NOS[id])
		check("%s: nummer is nog vrij (geen botsing met ENEMIES of Diepe Grot-bazen)" % id, not nos.has(int(e["no"])))
		check("%s: leefgebied Hollow Mountain en Diepe Grot" % id, (e["habitat"] as Array).has("berggrot") and (e["habitat"] as Array).has("dungeon100"))
		check("%s: voor- en rugart bestaat al en is echt (geen art_pending)" % id,
				ResourceLoader.exists(str(e["sprite"])) and ResourceLoader.exists(str(e["sprite_back"])) and not bool(e.get("art_pending", false)))
		check("%s: kaart-sprite bestaat" % id, ResourceLoader.exists("res://assets/map_monsters/%s.png" % id))
		check("%s: zit in de Diepe Grot-pool bergtunnel (verd. 51-100)" % id, Content.all_pool_enemies().has(id)
				and Content.enemy_pool(60).has(id) and Content.enemy_pool(100).has(id) and not Content.enemy_pool(40).has(id))
	check("bestiary_ids(): op nummer 043, 044, 045", BG.bestiary_ids() == ["steenluis", "druipslak", "adermot"])
	check("de Diepe Grot-bazen houden hun twaalf nummers 013-024", EndgameBestiary.ids().size() == 12)


# ================================================================ deel B: bestiarium
func _bestiary_tests() -> void:
	GameState.new_game("Dax")
	check("nieuw spel: niets gezien of verslagen", IDS.all(func(i): return not GameState.is_seen(i) and GameState.defeated_count(i) == 0))
	GameState.mark_seen("steenluis")
	check("mark_seen registreert Stone Louse", GameState.is_seen("steenluis") and GameState.defeated_count("steenluis") == 0
			and not GameState.is_seen("druipslak"))
	GameState.mark_defeated("steenluis")
	GameState.mark_defeated("steenluis")
	check("mark_defeated telt (2x) en zet ook gezien", GameState.defeated_count("steenluis") == 2 and GameState.is_seen("steenluis"))
	GameState.mark_seen("bestaat_niet")
	check("onbekende id komt niet in het bestiarium", not GameState.bestiary.has("bestaat_niet"))
	GameState.mark_seen("adermot")
	GameState.mark_defeated("adermot")
	var before: Dictionary = GameState.bestiary.duplicate(true)
	var path := "user://berggrotdex_save.json"
	check("opslaan", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, path))
	GameState.bestiary.clear()
	check("laden", GameState.load_game(path))
	GameState.has_return_point = false
	check("save/load bewaart het bestiarium van de grotmonsters", GameState.defeated_count("steenluis") == 2
			and GameState.is_seen("adermot") and GameState.defeated_count("adermot") == 1 and not GameState.is_seen("druipslak")
			and GameState.bestiary.size() == before.size())
	# scherm: ongeziene grotmonsters staan er niet tussen (vaste lijst en teller blijven gelijk)
	GameState.new_game("Dax")
	var n_vast := GD.ENEMIES.size() + EndgameBestiary.ids().size()
	var bs: Node = BestiaryScreen.new()
	get_tree().root.add_child(bs)
	await pframes(4)
	check("scherm zonder gezien grotmonster: vaste lijst (%d)" % bs.entries.size(), bs.entries.size() == n_vast
			and ("seen 0/%d" % n_vast) in bs.header.text)
	bs.queue_free()
	await pframes(2)
	GameState.mark_seen("druipslak")
	GameState.mark_seen("steenluis")
	GameState.mark_defeated("steenluis")
	bs = BestiaryScreen.new()
	get_tree().root.add_child(bs)
	await pframes(4)
	var texts: Array = []
	for i in bs.entries.size():
		texts.append(bs.entry_text(i))
	check("scherm: gezien -> 043 Stone Louse en 044 Drip Slug achteraan, nummers kloppen (%s)" % [texts.slice(n_vast)],
			bs.entries.size() == n_vast + 2 and texts[n_vast] == "043 Stone Louse" and texts[n_vast + 1] == "044 Drip Slug")
	check("scherm: Vein Moth (ongezien) staat er niet tussen", not texts.any(func(t): return str(t).contains("Vein Moth")))
	check("kop telt gezien/verslagen mee (%s)" % bs.header.text, ("seen 2/%d" % (n_vast + 2)) in bs.header.text
			and ("defeated 1/%d" % (n_vast + 2)) in bs.header.text)
	bs.show_entry("steenluis")
	check("verslagen: plaatje, naam, beschrijving en stats (HP 56, Weak, Drops, Lives)", bs.picture.texture != null
			and bs.picture.modulate == Color.WHITE and bs.name_label.text == "043 Stone Louse"
			and bs.desc_label.text == str(BG.MONSTERS["steenluis"]["desc"]) and bs.stats_visible()
			and "HP 56" in bs.stats_label.text and "Weak:" in bs.stats_label.text and "Drops:" in bs.stats_label.text
			and "Hollow Mountain" in bs.stats_label.text and "Deep Learning Simulation" in bs.stats_label.text)
	bs.show_entry("druipslak")
	check("alleen gezien: naam en beschrijving, nog geen stats", bs.name_label.text == "044 Drip Slug"
			and bs.picture.modulate == Color.WHITE and not bs.stats_visible() and bs.stats_label.text == "Defeat it to learn more.")
	await screenshot("berggrot_bestiarium")
	bs.queue_free()
	await pframes(2)


# ================================================================ deel C: Codex-soorten
func _codex_tests() -> void:
	check("CodexData.validate() en validate_fusion() blijven leeg (%s %s)" % [CD.validate(), CD.validate_fusion()],
			CD.validate().is_empty() and CD.validate_fusion().is_empty())
	for id in IDS:
		var e: Dictionary = BG.enemy(id)
		var sp := CD.species(id)
		check("%s: Codex-soort bestaat, vangbaar, naam %s" % [id, NAMES[id]], CD.has_species(id) and not sp.is_empty()
				and str(sp["name"]) == NAMES[id] and bool(sp["capturable"]) and not bool(sp["capture_always"]))
		check("%s: voor- en rugart uit BerggrotData (geen plaatsvervanger)" % id, str(sp["front"]) == str(e["sprite"])
				and str(sp["back"]) == str(e["sprite_back"]) and ResourceLoader.exists(str(sp["back"])))
		var st := CD.base_stats(id)
		check("%s: basis-stats = de gewone stats van de grotvijand" % id, int(st["max_hp"]) == int(e["max_hp"])
				and int(st["atk"]) == int(e["atk"]) and int(st["def"]) == int(e["def"]) and int(st["agi"]) == int(e["agi"])
				and int(st["max_mp"]) == int(e.get("mp", 0)))
		var l5 := CD.stats_at(id, 5)
		check("%s: stats groeien per level" % id, int(l5["max_hp"]) > int(st["max_hp"]) and int(l5["atk"]) > int(st["atk"]))
		var sk := CD.skills_at(id, 1)
		check("%s: leert op Lv 1 een eigen vaardigheid (%s)" % [id, sk], sk.size() == 1 and CD.SKILLS.has(sk[0])
				and str(CD.skill(sk[0])["name"]) != "")
		check("%s: soort per vijand-id gevonden" % id, CD.species_for_enemy(id) == id)
		check("%s: glitch-naam hoogstens %d tekens" % [id, CD.FUSION_NAME_MAX], CD.glitch_name(id).length() <= CD.FUSION_NAME_MAX
				and CD.glitch_name(id).begins_with("Glitch"))
		var cv: Array = []
		for hp in [56, 40, 20, 5, 1]:
			cv.append(CD.capture_chance(id, hp, 56))
		var stijgt := true
		for i in range(1, cv.size()):
			stijgt = stijgt and cv[i] > cv[i - 1]
		check("%s: vangkans stijgt bij minder HP (%s), volle HP %.2f, nooit boven 95%%" % [id, cv, cv[0]], stijgt
				and is_equal_approx(cv[0], CD.CAPTURE_MIN * float(sp["capture_rate"])) and cv[4] <= CD.CAPTURE_MAX
				and CD.capture_chance(id, 1, 56, true) == 0.0)
		check("%s: capture_level volgt het kamerniveau (tier 0 -> Lv 1, tier 4 -> Lv 4)" % id, CD.capture_level(0, id) == 1 and CD.capture_level(4, id) == 4)
	check("elke Berggrot-vaardigheid is een geldig soort (type damage)", ["steenbeet", "koude_druppel", "aderspark"].all(
			func(k): return CD.SKILLS.has(k) and str(CD.SKILLS[k]["type"]) == "damage"))
	# pagina, save/load van een pagina, dubbele exemplaren
	GameState.new_game("Dax")
	var a: Dictionary = GameState.codex_add("steenluis", 3, {"tier": 3, "play_time": 10})
	var b2: Dictionary = GameState.codex_add("druipslak", 2)
	var c: Dictionary = GameState.codex_add("adermot")
	var a2: Dictionary = GameState.codex_add("steenluis")
	check("codex_add: drie soorten + een dubbel exemplaar (eigen uid)", GameState.codex_pages.size() == 4 and not a.is_empty() and not b2.is_empty()
			and not c.is_empty() and a["uid"] != a2["uid"] and a["species"] == "steenluis" and int(a["level"]) == 3)
	check("pagina Stone Louse Lv 3: HP groeit, vaardigheid Stone Bite", int(a["max_hp"]) == int(CD.stats_at("steenluis", 3)["max_hp"])
			and int(a["max_hp"]) > 56 and (a["skills"] as Array) == ["steenbeet"] and str(a["name"]) == "Stone Louse"
			and str(a["element"]) == "steen")
	var s6 := CD.make_page("steenluis", 6, "x")
	check("Stone Louse leert Shield Up op Lv 6", (s6["skills"] as Array) == ["steenbeet", "schild_omhoog"])
	var path := "user://berggrotdex_codex.json"
	GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, path)
	GameState.codex_reset()
	GameState.load_game(path)
	GameState.has_return_point = false
	check("save/load: alle vier de pagina's terug (soort, level, vaardigheden)", GameState.codex_pages.size() == 4
			and GameState.codex_page(str(a["uid"])).get("species") == "steenluis" and int(GameState.codex_page(str(a["uid"]))["level"]) == 3
			and GameState.codex_page(str(b2["uid"])).get("species") == "druipslak" and GameState.codex_page(str(c["uid"])).get("species") == "adermot")
	check("kapotte pagina met onbekende soort wordt nog steeds geweigerd", CD.clean_page({"species": "bestaat_niet", "uid": "u"}).is_empty()
			and not CD.clean_page({"species": "adermot", "uid": "u", "level": 4}).is_empty())
	# fusie: geen tabelregel -> glitch-variant van A
	var pa := CD.make_page("steenluis", 4, "ua")
	var pb := CD.make_page("druipslak", 4, "ub")
	check("fusie Stone Louse + Drip Slug: geen tabelregel", CD.fusion_rule(pa, pb).is_empty() and CD.fusion_block_reason(pa, pb) == "")
	var fp := CD.make_fusion_page(pa, pb, "uf")
	check("fusie geeft de glitch-variant 'Glitch Louse' (Lv 5, generatie 1)", not fp.is_empty() and str(fp["species"]) == "steenluis"
			and str(fp["name"]) == "Glitch Louse" and int(fp["level"]) == 5 and CD.is_fused(fp))
	# bestaande fusie-uitkomsten veranderen niet door de nieuwe labels
	var mist := CD.make_page("mistuil", 3, "m1")
	var worm := CD.make_page("wortelkruiper", 3, "m2")
	check("bestaande fusieregels onveranderd (vleugel + woud blijft Mist Owl-recept)", CD.fusion_rule(CD.make_page("mistuil", 3, "q"), CD.make_page("sporenzwam", 3, "r"))
			.get("result", "") == "mistuil" and CD.fusion_rule(pa, mist).is_empty() and CD.fusion_rule(CD.make_page("adermot", 3, "z"), worm).is_empty())
	# eindstaat-Codex blijft zoals hij was: geen Berggrot-pagina's
	GameState.new_game("Dax")
	GameState._fill_eind_codex()
	check("eindstaat-Codex bevat geen Berggrot-soorten (%d pagina's)" % GameState.codex_pages.size(), GameState.codex_pages.size() > 0
			and GameState.codex_pages.all(func(p): return not IDS.has(str(p["species"]))))
	check("Berggrot-vangsten uit de Diepe Grot blijven niet standaard (GROT_BEHOUD ongewijzigd)", CD.GROT_BEHOUD == ["shard_codex", "scanline_wolf", "aureate_watcher", "ledger_scarab"])


# ================================================================ deel D: gevecht
func _battle_tests() -> void:
	setup()
	var room := await enter(BG.SCENE, BG.SPAWN_INGANG)
	check("Hollow Mountain geladen", room != null and room.scene_file_path == BG.SCENE)
	if room == null:
		return
	# 1) zien + vangen met een Blank Book (volle kans: 1 HP en vaste worp)
	var b := await start_battle(["steenluis"])
	check("gevecht met Stone Louse gestart (naam, stats uit BerggrotData)", b != null and b.enemies.size() == 1
			and str(b.enemies[0]["name"]) == "Stone Louse" and int(b.enemies[0]["s"]["max_hp"]) == 56)
	if b == null:
		return
	check("gevecht start: Stone Louse staat meteen als gezien in het bestiarium", GameState.is_seen("steenluis")
			and GameState.defeated_count("steenluis") == 0)
	await wait_battle_state(["command"])
	var e: Dictionary = b.enemies[0]
	await screenshot("berggrot_gevecht_steenluis")
	e["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	check("Blank Book op de Stone Louse", await use_book(b, e))
	check("vangen lukt: written into the Codex", await wait_until(func(): return seen_message("written into the Codex"), 8.0)
			and b.codex.last_capture.get("result") == "gelukt" and b.codex.last_capture.get("species") == "steenluis")
	await finish()
	check("pagina: Stone Louse Lv 1, Stone Bite, meteen bondgenoot", GameState.codex_pages.size() == 1
			and GameState.codex_pages[0]["species"] == "steenluis" and GameState.codex_pages[0]["level"] == 1
			and GameState.codex_pages[0]["skills"] == ["steenbeet"] and GameState.codex_active == GameState.codex_pages[0]["uid"])
	check("gevangen telt niet als verslagen (bestiarium: gezien, 0x verslagen), boek op (2 over)",
			GameState.is_seen("steenluis") and GameState.defeated_count("steenluis") == 0 and GameState.item_count(CD.BOOK_ITEM) == 2)
	# 2) de bondgenoot vecht mee, en een Vein Moth wordt verslagen (bestiarium telt)
	b = await start_battle(["adermot"])
	if b == null:
		check("gevecht met Vein Moth gestart", false)
		return
	await wait_battle_state(["command"])
	var al := ally_c(b)
	check("Stone Louse vecht mee als bondgenoot (rug-sprite, vaardigheid Stone Bite)", not al.is_empty()
			and str(al["name"]) == "Stone Louse" and str(al.get("species", al["s"].get("species", ""))) in ["steenluis", ""])
	check("Vein Moth gezien bij het begin van het gevecht", GameState.is_seen("adermot"))
	e = b.enemies[0]
	await screenshot("berggrot_gevecht_bondgenoot")
	await finish()
	check("Vein Moth verslagen: bestiarium telt 1x, gevecht gewonnen", GameState.defeated_count("adermot") == 1
			and GameState.last_battle_result == "win")
	# 3) baas-regel geldt niet; Diepe Grot (verdieping 60): gescaled monster, vangbaar
	setup()
	GameState.dungeon100_begin_run()
	GameState.inventory[CD.BOOK_ITEM] = 2
	b = await start_battle(["druipslak"], 60)
	if b == null:
		check("grotgevecht met Drip Slug gestart", false)
		return
	await wait_battle_state(["command"])
	e = b.enemies[0]
	check("Diepe Grot v60: Drip Slug heeft verdieping-60-stats (HP %d > 68)" % int(e["s"]["max_hp"]), int(e["s"]["max_hp"]) > 68
			and GameState.is_seen("druipslak"))
	e["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	check("Blank Book op de Drip Slug", await use_book(b, e))
	check("grot: vangen lukt als Drip Slug op het kamerniveau", await wait_until(func(): return seen_message("written into the Codex"), 8.0)
			and b.codex.last_capture.get("species") == "druipslak")
	var slug: Dictionary = {}
	for pg in GameState.codex_pages:
		if pg["species"] == "druipslak":
			slug = pg
	check("pagina Drip Slug op Lv %d (tier van verdieping 60)" % int(slug.get("level", -1)), not slug.is_empty()
			and int(slug["level"]) == Content.tier_for_floor(60) and (slug["skills"] as Array).has("koude_druppel"))
	await finish()
	GameState.dungeon100_floor = 0
