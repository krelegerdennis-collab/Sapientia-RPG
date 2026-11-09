extends Node
## ALLEEN VOOR TESTEN - WM1: Golemkern zonder veld/gevechts-Core Power (rest van oude Kernkracht-suite verwijderd).
## Start:  godot --path . -- --kernkrachttest [--shots=/pad/map] [--alleen=ABCJ]
##   Deel A: data + art (KernData/KernVeld constanten).
##   Deel B: met Golemkern geen Magie in gevecht.
##   Deel C: veld KERN blijft dicht (ook met fragment in save).
##   Deel J: Inktwurm-kast opent via interact na Golem-vlag.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const KernVuurbal := preload("res://scripts/kern/kern_vuurbal.gd")
const KernVeld := preload("res://scripts/kern/kern_kracht_veld.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const INGANG := "res://scenes/maps/archief_ingang.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const MAGIE := 1

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
var enemy_hits: Array = []
var only := ""             # --alleen=ABCJ: alleen deze delen (sneller bij het debuggen)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		if arg.begins_with("--alleen="):
			only = arg.get_slice("=", 1)
	seed(1616)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	if part("A"):
		print("=== Deel A: data + art ===")
		_data_tests()
	if part("B"):
		print("=== Deel B: geen Core Power (veld/gevecht) ===")
		await _no_core_power_tests()
	if part("C"):
		print("=== Deel C: veld zonder / met Golemkern (blijft dicht) ===")
		await _locked_tests()
	if part("J"):
		print("=== Deel J: Ink Worm-kast (interact na Golem) ===")
		await _kast_tests()
	print("KERNKRACHTTEST %d PASS, %d FAIL" % [passes, failures])
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


func veld() -> Node:
	var s := scene()
	return s.get_node_or_null("KernKracht") if s != null else null


func touch() -> Control:
	var s := scene()
	return s.get_node_or_null("TouchControls/Control") as Control if s != null else null


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


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


## Naar een kaart (spawnpunt), wachten tot alles stil is. Geeft de kaart of null.
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
	return scene()


func setup(step: int, with_kern: bool) -> void:
	GameState.new_game("Dax")
	GameState.story_step = step
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(10))
	GameState.equip_weapon(GameState.MAIN_HERO, "vonkzwaard")
	h["hp"] = h["max_hp"]
	if with_kern:
		GameState.grant_kern("golemkern", "kennis_beest")
	GameState.pending_kern_absorb = ""


## Alle map-monsters stil (anders lopen ze tijdens een test tegen je aan).
func freeze_monsters(except: Node = null) -> void:
	var s := scene()
	if s == null or not ("monsters" in s):
		return
	for m in s.monsters:
		if is_instance_valid(m) and m != except:
			m.moves = false
	await wait_until(func():
		for m in s.monsters:
			if is_instance_valid(m) and m.is_moving:
				return false
		return true, 3.0)


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


# ================================================================ deel A
func _data_tests() -> void:
	var s: Dictionary = KernData.KERN_SKILLS["kernslag"]
	check("vaardigheid heet 'Kernkracht' (id blijft 'kernslag'), fx vuurbal", s["name"] == "Core Power" and s.get("fx") == "vuurbal")
	check("formule ongewijzigd: 1,5x ATK, DEF x0,25, 3 rondes opladen", is_equal_approx(s["atk_mult"], 1.5)
			and is_equal_approx(s["def_factor"], 0.25) and int(s["cooldown"]) == 3)
	var f := KernData.fragment("golemkern")
	check("Golemkern: geen wereldvaardigheden meer %s" % [KernData.abilities_of(f)],
			KernData.abilities_of(f).is_empty())
	check("abilities_of: id, lijst en leeg", KernData.abilities_of({"world_ability": "x"}) == ["x"]
			and KernData.abilities_of({"world_ability": ""}).is_empty() and KernData.abilities_of({}).is_empty())
	check("KernData.validate zonder fouten %s" % [KernData.validate(GD.ENEMIES)], KernData.validate(GD.ENEMIES).is_empty())
	var sizes := {KernVuurbal.BALL: Vector2(64, 16), KernVuurbal.TRAIL: Vector2(48, 16), KernVuurbal.IMPACT: Vector2(96, 24)}
	for path in sizes:
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		check("art %s aanwezig, %s" % [path, sizes[path]], tex != null and tex.get_size() == sizes[path])
	check("textures komen uit de art (geen placeholder)", KernVuurbal.ball_texture().resource_path == KernVuurbal.BALL
			and KernVuurbal.trail_texture().resource_path == KernVuurbal.TRAIL and KernVuurbal.impact_texture().resource_path == KernVuurbal.IMPACT)
	var ph: Image = KernVuurbal._placeholder_image("inslag")
	check("placeholder (terugval) heeft dezelfde maten als de art", ph.get_size() == Vector2i(96, 24)
			and KernVuurbal._placeholder_image("bal").get_size() == Vector2i(64, 16) and KernVuurbal._placeholder_image("spoor").get_size() == Vector2i(48, 16))
	check("veld: bereik 3, stun 10, cooldown > 0", KernVeld.RANGE == 3 and KernVeld.STUN_STEPS == 10 and KernVeld.COOLDOWN > 0.0)


# ================================================================ deel B: gevecht
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


func start_battle(enemies: Array) -> Node:
	var p := player()
	GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", false)
	if not await wait_scene_named("Battle"):
		return null
	var b := battle()
	messages.clear()
	enemy_hits.clear()
	_watch(b)
	b.damage_shown.connect(func(who: String, amount: int):
		if who != GameState.party[0]["name"]:
			enemy_hits.append(amount))
	return b


func wait_scene_named(n: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == n and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


# ================================================================ deel C: dicht
func _locked_tests() -> void:
	setup(SD.KLAAR, false)
	var room := await enter(INGANG, "ingang")
	check("archief_ingang geladen (zonder kern)", room != null and veld() != null)
	if room == null or veld() == null:
		return
	await freeze_monsters()
	var v := veld()
	check("zonder Golemkern: can_fire = 'dicht'", v.can_fire() == "dicht" and not KernVeld.unlocked())
	await pframes(3)
	check("zonder Golemkern: geen KERN-knop", touch() != null and not touch().show_kern)
	await tap("kern")
	await pframes(10)
	check("zonder Golemkern: actie 'kern' doet niets (geen schot, geen bal)", v.shots_fired == 0
			and room.get_node("Objects").get_node_or_null("KernVuurbal") == null and not player().input_locked)
	GameState.grant_kern("golemkern")
	GameState.pending_kern_absorb = ""
	await pframes(3)
	check("met Golemkern (geen kernvuur): veld nog dicht, geen KERN-knop", v.can_fire() == "dicht" and not KernVeld.unlocked()
			and not touch().show_kern)


# ================================================================ deel B: WM1 zonder veld/gevechts-Core Power
func _no_core_power_tests() -> void:
	setup(SD.KLAAR, true)
	check("golemkern: geen kernvuur in GameState", not GameState.has_world_ability("kernvuur")
			and GameState.kern_skills_of(GameState.MAIN_HERO).is_empty())
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall voor gevecht-test", false)
		return
	var b := await start_battle(["papiergeest"])
	if b == null:
		check("gevecht gestart", false)
		return
	await wait_battle_state(["command"])
	await pframes(4)
	check("met Golemkern: Magie uit (geen Core Power)", not b.cross.enabled[MAGIE])
	b.can_flee = true
	b.cross.enabled[4] = true
	await cross_to(b, 4)
	await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)


# ================================================================ deel J: Inktwurm-kast
func _is_map_room(n: Node) -> bool:
	return n != null and n.has_method("get_monster") and "monsters" in n


func _kast_tests() -> void:
	setup(SD.KLAAR, true)
	GameState.story_flags[SD.GOLEM_FLAG] = true
	GameState.story_flags.erase("inktwurm_kast_open")
	var room := await enter(GOLEM_SCENE, "zuid")
	if not _is_map_room(room):
		check("J: Golem Hall geladen", false)
		return
	await freeze_monsters()
	var kast: Node = room.get_node_or_null("Objects/InktwurmKast")
	check("J: kast staat dicht rechts in de hal", kast != null and not kast.is_open and kast.tile == Vector2i(17, 5))
	if kast == null:
		return
	player().place_at(Vector2i(16, 5), Vector2i.RIGHT)
	await pframes(4)
	await press_interact()
	var opened: bool = await wait_until(func(): return is_instance_valid(kast) and kast.is_open, 4.0)
	await pframes(12)
	if Dialog.is_open:
		check("J: geen Core Power-tekst in dialoog", not "Core Power" in str(Dialog._lines))
		await close_dialog()
	var worm: Node = null
	for m in room.monsters:
		if is_instance_valid(m) and str(m.enemy_id) == "inktwurm":
			worm = m
	check("J: interact na Golem: kast open + vlag", opened and GameState.story_flags.has("inktwurm_kast_open")
			and kast.sprite.frame == 1 and not kast.scheur.visible and kast.shape.disabled)
	check("J: Ink Worm in de kast", worm != null and worm.tile == Vector2i(16, 5) and GameState.unique_available("inktwurm"))


