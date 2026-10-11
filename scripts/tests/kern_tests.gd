extends Node
## ALLEEN VOOR TESTEN - v0.15 (RPG CODE) KERNFRAGMENTEN stap 1: de Golemkern.
## Start:  godot --path . -- --kerntest [--shots=/pad/map]
##   Deel A: data (KERNFRAGMENTEN / KERN_SKILLS / WORLD_ABILITIES kloppen, art aanwezig).
##   Deel B: regels in GameState: eenmalig geven, nooit dubbel, save/load, oude save, alleen
##           de hoofdheld (MAIN_HERO) heeft de kernvaardigheden.
##   Deel C: echt Golem-baasgevecht winnen -> Golemkern + absorptie-moment op de kaart + autosave;
##           een tweede overwinning geeft niets dubbel.
##   Deel D: Kernkracht in het gevechtsmenu (Magie > Kernkracht): zichtbaar, schade volgens de formule,
##           daarna 3 rondes opladen.
##   Deel E: zware kast (kern_demo): zonder kern hint + blijft staan, met kern duwbaar.
##   Deel F: statusscherm toont 'Kernen' bij de hoofdheld (alleen als hij er een heeft).
## Met --shots=map: kern_absorptie, kern_absorptie_bericht, kernslag_menu, kernslag_raak,
## kernslag_opladen, zware_kast_hint, zware_kast_geduwd, status_kernen (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const KernAbsorption := preload("res://scripts/kern/kern_absorption.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const StatusScreenS := preload("res://scripts/ui/status_screen.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const DEMO_SCENE := "res://scenes/maps/kern_demo.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const AANVAL := 0
const MAGIE := 1

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
var enemy_hits: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(1515)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: regels (GameState) ===")
	_rule_tests()
	print("=== Deel C: Golem verslaan -> Golemkern ===")
	await _golem_tests()
	print("=== Deel D: Kernkracht in het gevecht ===")
	await _kernslag_tests()
	print("=== Deel E: zware kast ===")
	await _heavy_tests()
	print("=== Deel F: statusscherm 'Kernen' ===")
	await _status_tests()
	print("KERNTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _data_tests() -> void:
	var err := KernData.validate(GD.ENEMIES)
	check("KernData.validate: geen fouten %s" % [err], err.is_empty())
	check("Golem (kennis_beest, baas) -> golemkern; gewone monsters geven niets",
			KernData.fragment_for_boss("kennis_beest") == "golemkern" and KernData.fragment_for_boss("papiergeest") == ""
			and KernData.fragment_for_boss("") == "")
	var f := KernData.fragment("golemkern")
	check("golemkern: naam/beschrijving/icoon/baas/vaardigheden ingevuld", f.get("naam") == "Golem Core"
			and str(f.get("beschrijving", "")).length() > 10 and f.get("source_boss") == "kennis_beest"
			and f.get("battle_skill") == "kernslag" and KernData.abilities_of(f) == [KernData.HEAVY_BLOCK_ABILITY, KernData.FIELD_FIREBALL_ABILITY])   # v0.16: + kernvuur
	var icon: Texture2D = load(str(f["icon"]))
	check("icoon assets/ui/icons/golemkern.png 16x16", icon != null and icon.get_size() == Vector2(16, 16))
	var fx: Texture2D = load(KernAbsorption.FX)
	check("effect assets/fx/kern_absorptie.png 192x48 (4 frames van 48x48)", fx != null and fx.get_size() == Vector2(192, 48)
			and KernAbsorption.FRAMES == 4 and is_equal_approx(KernAbsorption.FRAME_TIME, 0.12))
	var s: Dictionary = KernData.KERN_SKILLS["kernslag"]
	check("Kernkracht (id kernslag): 1,5x ATK, DEF x0,25, 3 rondes opladen, fysiek op 1 vijand", s["name"] == "Core Power"
			and is_equal_approx(s["atk_mult"], 1.5) and is_equal_approx(s["def_factor"], 0.25) and int(s["cooldown"]) == 3
			and s["type"] == "physical" and s["target"] == "enemy")
	# validate vangt fouten echt op
	var bad := GD.ENEMIES.duplicate(true)
	bad.erase("kennis_beest")
	check("validate: baas die niet bestaat = fout", not KernData.validate(bad).is_empty())
	var bad2 := GD.ENEMIES.duplicate(true)
	(bad2["kennis_beest"] as Dictionary).erase("boss")
	check("validate: bron zonder baasgevecht = fout", not KernData.validate(bad2).is_empty())
	# de demo-kamer en alle zware kasten in de puzzels
	var e := PuzzleLogic.validate(PuzzleRooms.ROOMS["kern_demo"])
	check("puzzelkamer kern_demo geldig %s" % [e], e.is_empty() and ResourceLoader.exists(DEMO_SCENE))
	var unknown := []
	for rid in PuzzleRooms.ROOMS:
		var l := PuzzleLogic.from_room(PuzzleRooms.ROOMS[rid], rid)
		for b in l.heavy_blocks:
			if not KernData.WORLD_ABILITIES.has(l.heavy_blocks[b]):
				unknown.append("%s/%s" % [rid, b])
	check("elke zware kast vraagt een bestaande wereldvaardigheid %s" % [unknown], unknown.is_empty())


# ================================================================ deel B
func _rule_tests() -> void:
	GameState.new_game("Dennis")
	check("nieuw spel: geen kernen, geen vaardigheden", GameState.kernfragmenten.is_empty()
			and GameState.kern_skills_of(GameState.MAIN_HERO).is_empty() and not GameState.has_world_ability("zware_blokken"))
	check("grant_kern('golemkern') = true", GameState.grant_kern("golemkern", "kennis_beest"))
	check("tweede keer = false, nog steeds 1 kern", not GameState.grant_kern("golemkern") and GameState.kernfragmenten.size() == 1)
	check("onbekende kern = false", not GameState.grant_kern("bestaat_niet") and GameState.kernfragmenten.size() == 1)
	check("hoofdheld (%s) heeft Kernkracht + 'Zware blokken duwen'" % GameState.MAIN_HERO,
			GameState.kern_skills_of(GameState.MAIN_HERO) == ["kernslag"] and GameState.has_world_ability("zware_blokken")
			and GameState.world_abilities().has("zware_blokken"))
	check("Noor (en ieder ander) heeft geen kernvaardigheden", GameState.kern_skills_of("noor").is_empty()
			and GameState.kern_skills_of("") .is_empty())
	# save / load
	var path := "user://kerntest_save.json"
	check("opslaan", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, path))
	var raw := GameState.read_save(path)
	check("save bevat 'kernen' met golemkern", raw.get("kernen", {}).has("golemkern"))
	GameState.new_game("Dennis")
	check("nieuw spel wist de kern", not GameState.has_kern("golemkern"))
	check("laden: golemkern terug, nog steeds eenmalig", GameState.load_game(path) and GameState.has_kern("golemkern")
			and GameState.kernfragmenten.size() == 1 and not GameState.grant_kern("golemkern")
			and GameState.pending_kern_absorb == "")
	# oude save (zonder 'kernen') en een save met een onbekende kern
	raw.erase("kernen")
	_write_json(path, raw)
	check("oude save zonder 'kernen': laadt, geen kern", GameState.load_game(path) and GameState.kernfragmenten.is_empty())
	raw["kernen"] = {"golemkern": {"bron": "kennis_beest", "stap": 1}, "vreemd": {"bron": "x"}}
	_write_json(path, raw)
	check("save met onbekende kern: alleen golemkern blijft", GameState.load_game(path) and GameState.kernfragmenten.keys() == ["golemkern"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


# ================================================================ helpers
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 20:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open:
			return


## Eén duw tegen kast 'id': richting vasthouden tot de kast schuift of er tekst komt, dan meteen
## loslaten (anders loopt de speler door en duwt hij nog eens).
func push(action: String, room: Node, id: String) -> void:
	var p := player()
	var before: Vector2i = room.logic.blocks[id]
	Input.action_press(action)
	for i in 90:
		await get_tree().physics_frame
		if room.logic.blocks[id] != before or Dialog.is_open:
			break
	Input.action_release(action)
	await wait_until(func(): return is_instance_valid(p) and not p.is_moving, 3.0)
	await frames(6)


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


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


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
	var last := ""
	while is_instance_valid(b):
		var t: String = b.message_label.text
		if t != last:
			last = t
			messages.append(t)
		await get_tree().process_frame


func seen_message(part: String) -> bool:
	return messages.any(func(m): return part in m)


## Screenshot: native (veld 384x216, gevecht 768x432) + _3x (1152x648).
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


## Start een gevecht vanaf de huidige kaart; geeft de Battle-node (of null).
## Met 'monster_id': via het echte monster in de kamer (dan blijft een verslagen Golem weg).
func _start_battle(enemies: Array, boss: bool, monster_id := "") -> Node:
	var p := player()
	var mon: Node = null
	if monster_id != "" and "monsters" in scene():
		for m in scene().monsters:
			if is_instance_valid(m) and m.monster_id == monster_id:
				mon = m
	if mon != null:
		scene().start_monster_battle(mon)
	else:
		GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", boss)
	if not await wait_scene("Battle"):
		return null
	var b := battle()
	messages.clear()
	enemy_hits.clear()
	_watch(b)
	b.damage_shown.connect(func(who: String, amount: int):
		if who != GameState.party[0]["name"]:
			enemy_hits.append(amount))
	return b


## Win het gevecht snel: alle vijanden op 1 HP, dan aanvallen en de berichten wegklikken.
func _win(b: Node) -> bool:
	var won := false
	for guard in 60:
		var st := await wait_battle_state(["command", "message_wait", "target_enemy"], 30)
		if st == "":
			break
		if st == "message_wait":
			if b.victory_panel.visible:
				won = true
			await tap("interact")
			continue
		if st == "target_enemy":
			await tap("interact")
			continue
		for e in b.enemies:
			if int(e["s"]["hp"]) > 1:
				e["s"]["hp"] = 1
		await cross_to(b, AANVAL)
		await tap("interact")
		await wait_battle_state(["target_enemy", "busy", "message_wait"], 5)
	return won


func _golem_setup() -> bool:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(10))
	GameState.equip_weapon(GameState.MAIN_HERO, "vonkzwaard")
	h["hp"] = h["max_hp"]
	GameState.change_map(GOLEM_SCENE, "zuid")
	if not await wait_scene("ArchiefGolemhal"):
		return false
	await wait_fade()
	await pframes(10)
	return true


# ================================================================ deel C
func _golem_tests() -> void:
	Engine.time_scale = 1.0
	check("Golem Hall geladen", await _golem_setup())
	if player() == null:
		return
	check("voor de Golem: geen kern", GameState.kernfragmenten.is_empty())
	var b := await _start_battle(["kennis_beest"], true, "golem")
	check("baasgevecht tegen de Golem gestart (via het monster in de hal)", b != null and GameState.pending_boss
			and GameState.pending_enemies == ["kennis_beest"])
	if b == null:
		return
	Engine.time_scale = 2.0
	var won := await _win(b)
	check("Golem verslagen (overwinningsvenster)", won)
	check("GameState: golemkern gegeven (bron kennis_beest), absorptie klaargezet",
			GameState.has_kern("golemkern") and GameState.kernfragmenten["golemkern"].get("bron") == "kennis_beest"
			and GameState.kernfragmenten.size() == 1)
	Engine.time_scale = 1.0
	check("terug in de Golem Hall", await wait_scene("ArchiefGolemhal"))
	var ka: Node = null
	await wait_until(func(): return scene() != null and scene().get_node_or_null("KernAbsorptie") != null, 3.0)
	ka = scene().get_node_or_null("KernAbsorptie")
	check("absorptie-moment start op de kaart", ka != null)
	if ka == null:
		return
	check("speler staat stil tijdens het moment", await wait_until(func(): return player().input_locked, 2.0))
	await wait_until(func(): return ka.phase == "effect", 3.0)
	var fx: Sprite2D = ka.fx
	check("effect: kind van Dennis, op de borst (0,-4), 4 frames, midden (24,24), additieve gloed",
			fx != null and fx.get_parent() == player() and fx.position == Vector2(0, -4) and fx.hframes == 4
			and fx.centered and fx.texture.get_size() == Vector2(192, 48) and ka.glow != null
			and (ka.glow.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	var t0 := Time.get_ticks_msec()
	while ka.phase == "effect" and Time.get_ticks_msec() - t0 < 3000:
		if is_instance_valid(fx) and fx.frame == 2:
			await screenshot("kern_absorptie")
			break
		await get_tree().process_frame
	await wait_until(func(): return ka.phase != "effect", 3.0)
	check("effect speelt frames 0..3 eenmalig (niet loopen), %.2f s speltijd (4 x 0,12 s + 0,25 s vervagen) %s" % [ka.effect_time, ka.frames_shown],
			ka.frames_shown == [0, 1, 2, 3] and ka.effect_time >= 0.68 and ka.effect_time < 1.2 and fx.frame == 3)
	check("daarna het bericht", await wait_until(func(): return Dialog.is_open, 3.0) and ka.phase == "bericht")
	var lines: Array = Dialog._lines
	check("'Dennis absorbeert de Golemkern!' + Kernkracht + Zware blokken duwen + vuurbal in het veld %s" % [lines], lines.size() == 4
			and lines[0] == "Dennis absorbs the Golem Core!" and "Core Power" in str(lines[1]) and "Push Heavy Blocks" in str(lines[2])
			and "Core Power" in str(lines[3]))
	await get_tree().create_timer(1.6).timeout       # tekst helemaal uitgetypt
	await screenshot("kern_absorptie_bericht")
	var count_before := GameState.autosave_count
	await close_dialog()
	check("moment klaar: effect weg, speler vrij, pending leeg", await wait_until(func(): return not is_instance_valid(ka), 3.0)
			and not player().input_locked and GameState.pending_kern_absorb == "" and player().get_node_or_null("KernEffect") == null)
	check("autosave na de absorptie (reden 'kern')", GameState.autosave_count > count_before and GameState.last_autosave_reason == "kern")
	var auto := GameState.read_save(GameState.autosave_path)
	check("autosave bevat de golemkern", auto.get("kernen", {}).has("golemkern"))
	# laden van de autosave: kern blijft, geen nieuw moment
	GameState.new_game("Dennis")
	check("autosave laden: golemkern terug", GameState.load_game(GameState.autosave_path) and GameState.has_kern("golemkern")
			and GameState.pending_kern_absorb == "")
	# tweede overwinning op een baas met dezelfde kern: niets dubbel, geen nieuw moment
	check("weer in de Golem Hall", await _golem_setup())
	GameState.grant_kern("golemkern")
	var b2 := await _start_battle(["kennis_beest"], true)
	if b2 == null:
		check("tweede baasgevecht gestart", false)
		return
	Engine.time_scale = 2.0
	await _win(b2)
	Engine.time_scale = 1.0
	check("tweede overwinning: nog steeds 1 golemkern, geen nieuw absorptie-moment",
			GameState.kernfragmenten.size() == 1 and GameState.pending_kern_absorb == "")
	await wait_scene("ArchiefGolemhal")
	await pframes(40)
	check("geen KernAbsorptie op de kaart", scene().get_node_or_null("KernAbsorptie") == null)


# ================================================================ deel D
func _kernslag_tests() -> void:
	GameState.new_game("Dennis")
	check("Golem Hall (zonder kern) geladen", await _golem_setup())
	# zonder kern: Magie uit voor Dennis (hij heeft geen spreuken)
	var b := await _start_battle(["papiergeest"], false)
	if b == null:
		check("gevecht gestart", false)
		return
	await wait_battle_state(["command"])
	await pframes(4)
	check("zonder kern: 'Magie' staat uit voor Dennis", not b.cross.enabled[MAGIE])
	b.can_flee = true
	b.cross.enabled[4] = true
	await cross_to(b, 4)
	await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_scene("ArchiefGolemhal")
	await pframes(10)
	# met kern
	GameState.grant_kern("golemkern")
	b = await _start_battle(["papiergeest"], false)
	if b == null:
		check("gevecht met kern gestart", false)
		return
	var e: Dictionary = b.enemies[0]
	e["s"]["hp"] = 9999
	e["s"]["max_hp"] = 9999
	await wait_battle_state(["command"])
	await pframes(4)
	check("met kern: 'Magie' aan voor Dennis", b.cross.enabled[MAGIE])
	await cross_to(b, MAGIE)
	await tap("interact")
	check("menu open met titel 'Kern'", await wait_until(func(): return b.menu.visible, 3.0) and b.menu.title_label.text == "Core")
	var entries: Array = b.menu._entries
	check("menu: 'Kernkracht KERN' staat erin en is te kiezen %s" % [entries], entries.size() == 1
			and str(entries[0]["text"]).begins_with("Core Power") and "CORE" in str(entries[0]["text"]) and entries[0]["enabled"])
	await get_tree().create_timer(0.3).timeout
	await screenshot("kernslag_menu")
	var hero: Dictionary = GameState.party[0]
	var sk: Dictionary = KernData.KERN_SKILLS["kernslag"]
	var dfn: float = b._defense_of(e) if b.has_method("_defense_of") else float(e["s"]["def"])
	var base := float(hero["atk"]) * float(sk["atk_mult"]) - dfn * float(sk["def_factor"])
	var lo := maxi(1, floori(base * 0.85) - 1)
	var hi := ceili(base * 1.15) + 1
	await tap("interact")
	check("doel kiezen", await wait_battle_state(["target_enemy"], 5) == "target_enemy")
	await tap("interact")
	await wait_until(func(): return seen_message("Core Power"), 5.0)
	check("bericht '%s: Core Power!'" % hero["name"], seen_message("%s: Core Power!" % hero["name"]))
	await wait_until(func(): return not enemy_hits.is_empty(), 5.0)
	if shots != "":   # schadegetal in beeld, vijand niet net weg door het knipperen
		await wait_until(func(): return e["node"].visible, 1.0)
		await screenshot("kernslag_raak")
	check("Kernkracht-schade %s binnen %d..%d (ATK %d x1,5 - DEF %.0f x0,25, +/-15%%)" % [enemy_hits, lo, hi, hero["atk"], dfn],
			enemy_hits.size() >= 1 and enemy_hits[0] >= lo and enemy_hits[0] <= hi)
	var normal := float(hero["atk"]) - dfn / 2.0
	check("Kernkracht sterker dan een gewone aanval (gem. %.0f vs %.0f)" % [base, normal], base > normal * 1.4)
	# opladen: ronde 2 (2), ronde 3 (1), ronde 4 weer klaar
	for want in [2, 1]:
		await wait_battle_state(["command"], 40)
		await pframes(4)
		var h := _hero_c(b)
		check("ronde %d: Kernkracht laadt op (%d), menu-regel '%s', niet te kiezen" % [b.round_no, want, b.kern_entry_text(h, "kernslag")],
				b.kern_charge(h, "kernslag") == want and b.kern_entry_text(h, "kernslag").ends_with("(%d)" % want)
				and not b.kern_ready(h, "kernslag"))
		if want == 2:
			await cross_to(b, MAGIE)
			await tap("interact")
			await wait_until(func(): return b.menu.visible, 3.0)
			await get_tree().create_timer(0.25).timeout
			check("menu toont de regel uitgegrijsd", not b.menu._entries[0]["enabled"])
			await screenshot("kernslag_opladen")
			await tap("cancel")
			await wait_battle_state(["command"], 5)
		await cross_to(b, 3)   # verdedigen
		await tap("interact")
		await wait_battle_state(["busy", "message_wait"], 5)
	await wait_battle_state(["command"], 40)
	await pframes(4)
	check("ronde %d: Kernkracht weer klaar" % b.round_no, b.kern_ready(_hero_c(b), "kernslag")
			and b.kern_entry_text(_hero_c(b), "kernslag").ends_with("CORE"))
	b.can_flee = true
	b.cross.enabled[4] = true
	await cross_to(b, 4)
	await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_scene("ArchiefGolemhal")
	check("kernslag-gevecht: geen nieuwe kern of absorptie", GameState.kernfragmenten.size() == 1 and GameState.pending_kern_absorb == "")


func _hero_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c["s"].get("id", "") == GameState.MAIN_HERO:
			return c
	return {}


# ================================================================ deel E
func _enter_demo() -> Node:
	GameState.has_return_point = false
	GameState.change_map(DEMO_SCENE, "ingang")
	if not await wait_scene("KernDemo"):
		return null
	await wait_fade()
	await pframes(4)
	return scene()


func _heavy_tests() -> void:
	# pure logica
	var l := PuzzleLogic.from_room(PuzzleRooms.ROOMS["kern_demo"], "kern_demo")
	check("logica: kast_zwaar is zwaar (vraagt 'zware_blokken')", l.heavy_blocks.get("kast_zwaar", "") == "zware_blokken")
	l.set_player_tile(Vector2i(2, 3))
	check("logica: zonder vaardigheid 'te zwaar'", l.push_block_reason("kast_zwaar", Vector2i.RIGHT) == "te zwaar"
			and not l.try_push("kast_zwaar", Vector2i.RIGHT) and l.blocks["kast_zwaar"] == Vector2i(3, 3))
	l.abilities = {"zware_blokken": true}
	check("logica: met vaardigheid duwbaar", l.push_block_reason("kast_zwaar", Vector2i.RIGHT) == ""
			and l.try_push("kast_zwaar", Vector2i.RIGHT) and l.blocks["kast_zwaar"] == Vector2i(4, 3))
	var a := PuzzleLogic.from_room(PuzzleRooms.ROOMS["archief_test"], "archief_test")
	check("gewone kasten (archief_test) blijven gewoon: geen zware", a.heavy_blocks.is_empty())
	# echte scène zonder kern
	GameState.new_game("Dennis")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	var room := await _enter_demo()
	check("kern_demo geladen, speler bij de ingang (4,5): %s" % tile(), room != null and tile() == Vector2i(4, 5))
	if room == null:
		return
	var blk: Node = room.nodes.get("kast_zwaar")
	# v0.15 (Forge): RPG ART leverde assets/puzzle/kast_zwaar.png -> eigen plaatje, geen code-tint meer;
	# zonder dat bestand blijft de runen-tint de terugval
	var own_art := false
	if blk != null:
		for c in blk.visual.get_children():
			if c is Sprite2D and c.texture and str(c.texture.resource_path).ends_with("kast_zwaar.png"):
				own_art = true
	check("zware kast in beeld (kast_zwaar.png van RPG ART, of anders de runen-tint)", blk != null and blk.heavy
			and (own_art and blk.visual.modulate == Color.WHITE if ResourceLoader.exists("res://assets/puzzle/kast_zwaar.png")
			else blk.visual.modulate.r < 0.9))
	await walk("move_left", 2)
	await walk("move_up", 2)
	check("naast de kast (2,3): %s" % tile(), tile() == Vector2i(2, 3))
	await push("move_right", room, "kast_zwaar")
	check("zonder kern: hint '%s'" % [Dialog._lines], await wait_until(func(): return Dialog.is_open, 2.0)
			and room.last_heavy_hint == "kast_zwaar" and str(Dialog._lines[0]).begins_with("This cabinet is full of runes"))
	check("kast bleef staan (3,3), speler ook", room.logic.blocks["kast_zwaar"] == Vector2i(3, 3) and tile() == Vector2i(2, 3))
	await get_tree().create_timer(1.6).timeout       # tekst helemaal uitgetypt
	await screenshot("zware_kast_hint")
	await close_dialog()
	# nu met de Golemkern
	GameState.grant_kern("golemkern")
	room.last_heavy_hint = ""
	await push("move_right", room, "kast_zwaar")
	check("met kern: kast 1 tegel opgeschoven (4,3), geen hint", await wait_until(func(): return room.logic.blocks["kast_zwaar"] == Vector2i(4, 3), 2.0)
			and room.last_heavy_hint == "" and not Dialog.is_open)
	await wait_until(func(): return not blk.is_sliding(), 2.0)
	await push("move_right", room, "kast_zwaar")     # 1 stap lopen + duwen, zoals een speler
	var on_plate := func(): return room.logic.blocks["kast_zwaar"] == Vector2i(5, 3) and room.logic.gate_open("poort_1")
	var ok_plate: bool = await wait_until(on_plate, 2.0)
	check("kast op de zware plaat (5,3), poort open (kast %s, speler %s)" % [room.logic.blocks["kast_zwaar"], tile()], ok_plate)
	await wait_until(func(): return not blk.is_sliding(), 2.0)
	await get_tree().create_timer(0.4).timeout
	await screenshot("zware_kast_geduwd")


# ================================================================ deel F
func _status_tests() -> void:
	var dennis: Dictionary = GameState.party[0]
	check("kern_text: Dennis met Golemkern = 'Golemkern (Kernkracht)'", StatusScreenS.kern_text(dennis) == "Golem Core (Core Power)")
	check("kern_text: Noor = '' (alleen de hoofdheld)", StatusScreenS.kern_text({"id": "noor"}) == "")
	if player() == null or Dialog.is_open:
		await close_dialog()
	await tap("menu")
	await frames(4)
	var m: Node = scene().get_node_or_null("FieldMenu")
	check("veldmenu open", m != null)
	if m == null:
		return
	m.choose("status")
	await frames(4)
	var st: Node = m.get_node_or_null("Status")
	check("statusscherm open, regel 'Kernen: %s' zichtbaar" % (st.kern_label.text if st else "?"), st != null
			and st.kern_label.visible and st.kern_key.visible and st.kern_label.text == "Golem Core (Core Power)")
	if st != null:
		await get_tree().create_timer(0.3).timeout
		var r: Rect2 = st.kern_label.get_global_rect()
		var vp := get_viewport().get_visible_rect()
		check("regel 'Kernen' past in beeld (%s in %s)" % [r, vp.size], vp.encloses(r))
		await screenshot("status_kernen")
		GameState.kernfragmenten.clear()
		st.show_member(0)
		check("zonder kern: regel verborgen", not st.kern_label.visible and not st.kern_key.visible)
		GameState.grant_kern("golemkern")
