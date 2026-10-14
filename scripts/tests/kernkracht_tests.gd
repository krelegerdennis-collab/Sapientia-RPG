extends Node
## ALLEEN VOOR TESTEN - v0.16 (RPG CODE) KERNKRACHT: de paarse vuurbal (zie HANDOFF_KERNKRACHT.md).
## Start:  godot --path . -- --kernkrachttest [--shots=/pad/map]
##   Deel A: data + art (naam Kernkracht, id kernslag, wereldvaardigheid kernvuur, PNG's van RPG ART).
##   Deel B: gevecht: Magie > Kernkracht = vuurbal van de hand naar de vijand + inslag (echte art),
##           schade volgens de formule, daarna 3 rondes opladen.
##   Deel C: veld zonder Golemkern: dicht (geen knop, geen schot).
##   Deel D: veld met Golemkern: precies 3 tegels, KERN-knop (touch) en toets/actie, geen spam.
##   Deel E: geblokkeerd door ELK soort object (muur, duwkast, kist, NPC, poort, hendel, deur, ...).
##   Deel F: monster 10 stappen verlamd (ook na een ander gevecht), daarna loopt hij weer en
##           start aanraken weer een gevecht. Deel G: baas (Golem) krijgt niets.
##   Deel H: save/load: vaardigheid blijft, geen verlamming blijft hangen.
##   Deel I: v0.19 haak on_kernkracht_hit() (geheime Inktwurm-kast van Forge): 1x bij een treffer, vóór de
##           inslag; ook via de parent; niet buiten bereik (> 3 tegels) en niet door een ander object heen.
##   Deel J: de echte kast in de Golemhal gaat open door Kernkracht, de Inktwurm komt eruit, en blijft
##           open na opnieuw binnenkomen. Zonder Golemkern blijft hij dicht.
## Met --shots=map: kk_gevecht_vlucht, kk_gevecht_inslag, kk_veld_vlucht, kk_veld_geblokkeerd,
## kk_veld_monster_verlamd, kk_veld_knop (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const KernVuurbal := preload("res://scripts/kern/kern_vuurbal.gd")
const KernVeld := preload("res://scripts/kern/kern_kracht_veld.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const INGANG := "res://scenes/maps/archief_ingang.tscn"
const GANG := "res://scenes/maps/archief_v1_gang.tscn"
const PUZZEL_TEST := "res://scenes/maps/archief_test.tscn"
const PUZZEL := "res://scenes/maps/archief_puzzel.tscn"
const KERN_DEMO := "res://scenes/maps/kern_demo.tscn"
const DORP := "res://scenes/maps/wilgendal.tscn"
const BIBLIOTHEEK := "res://scenes/maps/archief_bibliotheek.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const ACTIONS := {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
const MAGIE := 1

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
var enemy_hits: Array = []
var kinds_hit := {}        # soort -> kaart (deel E)
var only := ""             # --alleen=BCD: alleen deze delen (sneller bij het debuggen)


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
		print("=== Deel B: gevecht ===")
		await _battle_tests()
	if part("C"):
		print("=== Deel C: veld zonder Golemkern ===")
		await _locked_tests()
	if part("D"):
		print("=== Deel D: veld: bereik, knop, geen spam ===")
		await _range_tests()
	if part("E"):
		print("=== Deel E: geblokkeerd door elk object ===")
		await _blocker_tests()
	if part("F"):
		print("=== Deel F: monster verlamd ===")
		await _stun_tests()
	if part("G"):
		print("=== Deel G: baas ===")
		await _boss_tests()
	if part("H"):
		print("=== Deel H: save/load ===")
		await _save_tests()
	if part("I"):
		print("=== Deel I: haak on_kernkracht_hit (v0.19) ===")
		await _hook_tests()
	if part("J"):
		print("=== Deel J: Ink Worm-kast in de Golem Hall ===")
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


## Mag de speler (voor een test) op tile t staan? Vrij, geen uitgang, geen puzzelobject, geen monster ernaast.
func standable(t: Vector2i) -> bool:
	var s := scene()
	var v := veld()
	if s.ground.get_cell_source_id(t) == -1 or not v.blocker_at(t).is_empty():
		return false
	for n in s.find_children("*", "Node2D", true, false):
		if n is MapExit and n.contains(t):
			return false
	if "logic" in s and s.logic != null and s.logic.object_at(t) != "":
		return false
	# geen Area2D (leesplek, triggers) op de tile
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(t) * 16 + Vector2(8, 8)
	q.collide_with_bodies = false
	q.collide_with_areas = true
	if not s.player.get_world_2d().direct_space_state.intersect_point(q, 4).is_empty():
		return false
	if "monsters" in s:
		for m in s.monsters:
			if is_instance_valid(m):
				for d in DIRS + [Vector2i.ZERO]:
					if m.covers(t + d):
						return false
	return true


## Zoek een plek + richting waarvoor 'pred(trace)' klopt; liefst zo ver mogelijk weg (mooie vlucht).
func find_shot(pred: Callable, allow_near_monster := false) -> Dictionary:
	var s := scene()
	var v := veld()
	var best := {}
	for t in s.ground.get_used_cells():
		var ok := standable(t)
		if not ok and allow_near_monster:
			ok = s.ground.get_cell_source_id(t) != -1 and v.blocker_at(t).is_empty()
		if not ok:
			continue
		for d in DIRS:
			var r: Dictionary = v.trace(t, d)
			if pred.call(r) and (best.is_empty() or r["tiles"].size() > best["r"]["tiles"].size()):
				best = {"start": t, "dir": d, "r": r}
				if r["tiles"].size() >= 2:
					return best
	return best


## Echt schieten (actie "kern", zoals toets K / de knop) vanaf 'start' in richting 'dir'.
## Wacht tot het schot helemaal klaar is. Met 'flight_shot' / 'impact_shot': screenshot onderweg.
func shoot(start: Vector2i, dir: Vector2i, flight_shot := "", impact_shot := "") -> Dictionary:
	var p := player()
	var v := veld()
	p.place_at(start, dir)
	await frames(2)
	await wait_until(func(): return v.can_fire() == "", 3.0)
	var before: int = v.shots_fired
	Input.action_press("kern")
	await wait_until(func(): return v.shots_fired > before, 1.0)
	Input.action_release("kern")
	if v.shots_fired == before:
		return {}
	var res: Dictionary = {"result": v.last_result, "start_px": p.position + KernVeld.CHEST + Vector2(dir) * 6.0}
	await wait_until(func(): return is_instance_valid(v.last_fireball) and v.last_fireball.flying, 1.0)
	var vb: Node2D = v.last_fireball
	var vbw: WeakRef = weakref(vb)        # lambda's houden geen vrijgegeven node vast
	if is_instance_valid(vb):
		res["rotation"] = vb.rotation
		res["placeholder"] = vb.placeholder
		res["ball_tex"] = str(vb.ball.texture.resource_path)
		res["locked"] = p.input_locked
		res["can_fire_busy"] = v.can_fire()
		if flight_shot != "":
			await wait_until(func():
				var o: Node2D = vbw.get_ref()
				return o == null or o.position.distance_to(res["start_px"]) >= 14.0, 1.0)
			if is_instance_valid(vb) and vb.flying:
				await screenshot(flight_shot)
	var trail := [0]
	await wait_until(func():
		var o: Node2D = vbw.get_ref()
		if o != null:
			trail[0] = o.trail_spawned
		return v.last_impact != null and is_instance_valid(v.last_impact) and v.last_impact.get_parent() != null, 2.0)
	if is_instance_valid(v.last_impact):
		res["impact_pos"] = v.last_impact.position
		var sp: Sprite2D = v.last_impact.get_node_or_null("Inslag")
		var spw: WeakRef = weakref(sp)
		res["impact_tex"] = str(sp.texture.resource_path) if sp else ""
		if impact_shot != "":
			await wait_until(func():
				var o: Sprite2D = spw.get_ref()
				return o == null or o.frame >= 1, 0.5)
			await screenshot(impact_shot)
	res["trail"] = trail[0]
	await wait_until(func(): return not v.busy, 3.0)
	res["unlocked_after"] = not p.input_locked
	res["can_fire_after"] = v.can_fire()
	return res


func px(t: Vector2i) -> Vector2:
	return Vector2(t) * 16 + Vector2(8, 8) + KernVeld.CHEST


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
	check("Golemkern geeft 'zware_blokken' + 'kernvuur' %s" % [KernData.abilities_of(f)],
			KernData.abilities_of(f) == ["zware_blokken", "kernvuur"] and KernData.WORLD_ABILITIES.has("kernvuur"))
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


func seen_message(part: String) -> bool:
	return messages.any(func(m): return part in m)


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


func hero_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c["s"].get("id", "") == GameState.MAIN_HERO:
			return c
	return {}


## Vluchten (kan mislukken: dan de volgende ronde opnieuw).
func flee(b: Node) -> void:
	for i in 8:
		if not is_instance_valid(b) or battle() == null:
			break
		if await wait_battle_state(["command"], 30) != "command":
			break
		b.can_flee = true
		b.cross.enabled[4] = true
		await cross_to(b, 4)
		await tap("interact")
		await pframes(8)
		await wait_until(func(): return battle() == null or not is_instance_valid(b) or b.state == "command", 15.0)
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)


## Win snel: vijanden op 1 HP, aanvallen, berichten wegklikken.
func win(b: Node) -> bool:
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
		await cross_to(b, 0)
		await tap("interact")
		await wait_battle_state(["target_enemy", "busy", "message_wait"], 5)
	return won


func _battle_tests() -> void:
	setup(SD.NACHT, true)
	var room := await enter(GOLEM_SCENE, "zuid")
	check("Golem Hall geladen (met Golemkern)", room != null)
	if room == null:
		return
	var b := await start_battle(["papiergeest"])
	if b == null:
		check("gevecht gestart", false)
		return
	var e: Dictionary = b.enemies[0]
	e["s"]["hp"] = 9999
	e["s"]["max_hp"] = 9999
	await wait_battle_state(["command"])
	await pframes(4)
	await cross_to(b, MAGIE)
	await tap("interact")
	await wait_until(func(): return b.menu.visible, 3.0)
	var entries: Array = b.menu._entries
	check("menu: 'Kernkracht KERN' %s" % [entries], entries.size() == 1 and str(entries[0]["text"]).begins_with("Core Power")
			and str(entries[0]["text"]).ends_with("CORE") and entries[0]["enabled"])
	var hero: Dictionary = GameState.party[0]
	var sk: Dictionary = KernData.KERN_SKILLS["kernslag"]
	var dfn: float = b._defense_of(e) if b.has_method("_defense_of") else float(e["s"]["def"])
	var base := float(hero["atk"]) * float(sk["atk_mult"]) - dfn * float(sk["def_factor"])
	var lo := maxi(1, floori(base * 0.85) - 1)
	var hi := ceili(base * 1.15) + 1
	await tap("interact")
	await wait_battle_state(["target_enemy"], 5)
	b.last_kern_fireball = null
	b.last_kern_impact = null
	await tap("interact")
	check("bericht '%s: Core Power!'" % hero["name"], await wait_until(func(): return seen_message("%s: Core Power!" % hero["name"]), 5.0))
	# de hand: held in spreuk-pose, de bal vertrekt bij de hand
	var hn: Control = hero_c(b)["node"]
	check("vuurbal verschijnt in het gevecht", await wait_until(func(): return is_instance_valid(b.last_kern_fireball) and b.last_kern_fireball.flying, 3.0))
	var vb: Node2D = b.last_kern_fireball
	if not is_instance_valid(vb):
		return
	var from: Vector2 = hn.head_position() + b.KERN_HAND
	print("INFO  held kop %s pos %s stap %s | vijand %s maat %s | van %s naar %s" % [hn.head_position(), hn.position, hn.stepped_forward, e["node"].position, e["node"].size, vb.position, b.last_kern_impact])
	var to: Vector2 = e["node"].position + e["node"].size * Vector2(0.5, 0.35)
	check("geen zwaardzwaai: held in spreuk-pose (hand vooruit), pose '%s'" % hn.pose, str(hn.pose).begins_with("spreuk"))
	check("bal: echte art (geen placeholder), 4 frames, schaal %s" % vb.scale, not vb.placeholder and vb.ball.texture.resource_path == KernVuurbal.BALL
			and vb.ball.hframes == 4 and vb.scale == Vector2.ONE * b.KERN_FX_SCALE)
	var p0: Vector2 = vb.position
	await pframes(2)
	check("bal draait mee met de baan (art wijst naar rechts): %.2f rad, beweging %s" % [vb.rotation, vb.position - p0],
			is_instance_valid(vb) and (vb.position - p0).length() > 0.1 and absf(angle_difference(vb.rotation, (vb.position - p0).angle())) < 0.35)
	check("bal vertrekt bij de hand (%s, start %s)" % [from, p0], p0.distance_to(from) < 12.0)
	var vbw: WeakRef = weakref(vb)
	await wait_until(func():
		var o: Node2D = vbw.get_ref()
		return o == null or o.position.distance_to(from) > from.distance_to(to) * 0.45, 2.0)
	if is_instance_valid(vb) and vb.flying:
		check("onderweg: spoor (trail) achter de bal (%d)" % vb.trail_spawned, vb.trail_spawned >= 3)
		await screenshot("kk_gevecht_vlucht")
	check("inslag op de vijand", await wait_until(func(): return is_instance_valid(b.last_kern_impact), 3.0))
	var imp: Node2D = b.last_kern_impact
	if is_instance_valid(imp):
		var sp: Sprite2D = imp.get_node_or_null("Inslag")
		check("inslag: art 24x24 x4, midden op de vijand", sp != null and sp.texture.resource_path == KernVuurbal.IMPACT
				and sp.hframes == 4 and sp.centered and imp.position.distance_to(to) < 1.0)
		var spw: WeakRef = weakref(sp)
		await wait_until(func():
			var o: Sprite2D = spw.get_ref()
			return o == null or o.frame >= 1, 0.5)
		await screenshot("kk_gevecht_inslag")
		var frames_seen := []
		while is_instance_valid(sp):
			if frames_seen.is_empty() or frames_seen[-1] != sp.frame:
				frames_seen.append(sp.frame)
			await get_tree().process_frame
		check("inslag loopt niet (frames oplopend, daarna weg) %s" % [frames_seen], frames_seen.size() >= 2 and _ascending(frames_seen))
	await wait_until(func(): return not enemy_hits.is_empty(), 5.0)
	check("schade %s binnen %d..%d (ATK %d x1,5 - DEF %.0f x0,25, +/-15%%)" % [enemy_hits, lo, hi, hero["atk"], dfn],
			enemy_hits.size() >= 1 and enemy_hits[0] >= lo and enemy_hits[0] <= hi)
	for want in [2, 1]:
		await wait_battle_state(["command"], 40)
		await pframes(4)
		var h := hero_c(b)
		check("ronde %d: laadt op (%d), '%s'" % [b.round_no, want, b.kern_entry_text(h, "kernslag")],
				b.kern_charge(h, "kernslag") == want and not b.kern_ready(h, "kernslag"))
		await cross_to(b, 3)
		await tap("interact")
		await wait_battle_state(["busy", "message_wait"], 5)
	await wait_battle_state(["command"], 40)
	await pframes(4)
	check("ronde %d: Kernkracht weer klaar" % b.round_no, b.kern_ready(hero_c(b), "kernslag"))
	await flee(b)
	var back := await wait_scene_path(GOLEM_SCENE)
	if not back:
		print("INFO  scene=%s in_battle=%s changing=%s state=%s" % [scene().name if scene() else "-", GameState.in_battle, GameState.changing_map, b.state if is_instance_valid(b) else "-"])
	check("terug op de kaart na het gevecht", back)


func _ascending(a: Array) -> bool:
	for i in range(1, a.size()):
		if int(a[i]) <= int(a[i - 1]):
			return false
	return true


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
	# Golemkern zonder 'kernvuur' bestaat niet; met de kern direct open
	GameState.grant_kern("golemkern")
	GameState.pending_kern_absorb = ""
	await pframes(3)
	check("met Golemkern: open, KERN-knop zichtbaar", v.can_fire() == "" and touch().show_kern)


# ================================================================ deel D: bereik, knop, spam
func _range_tests() -> void:
	setup(SD.KLAAR, true)
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("archief_ingang geladen", false)
		return
	await freeze_monsters()
	var v := veld()
	# 1) precies 3 tegels: tegel 4 is een muur, de bal haalt hem niet
	var s := find_shot(func(r): return r["hit"] == null and not v.blocker_at(r["tiles"][2] + (r["tiles"][2] - r["tiles"][1])).is_empty())
	check("plek gevonden: 3 vrije tegels, daarna een muur", not s.is_empty())
	if not s.is_empty():
		var res := await shoot(s["start"], s["dir"], "kk_veld_vlucht")
		var r: Dictionary = res.get("result", {})
		var t3: Vector2i = s["start"] + s["dir"] * 3
		check("bereik precies 3 tegels: pad %s, geen treffer, eind %s" % [r.get("tiles"), r.get("end")],
				r.get("tiles", []).size() == 3 and r.get("hit") == null and r.get("end") == t3)
		check("bal dooft uit midden op tegel 3 (niet tegel 4): %s" % res.get("impact_pos"), res.get("impact_pos", Vector2.ZERO).distance_to(px(t3)) < 0.5)
		check("bal wijst in de vliegrichting (%.2f rad)" % res.get("rotation", 99.0), absf(angle_difference(res.get("rotation", 99.0), Vector2(s["dir"]).angle())) < 0.01)
		check("veld: echte art (geen placeholder) %s / %s" % [res.get("ball_tex"), res.get("impact_tex")],
				res.get("placeholder", true) == false and res.get("ball_tex") == KernVuurbal.BALL and res.get("impact_tex") == KernVuurbal.IMPACT)
		check("spoor achter de bal (%d)" % res.get("trail", -1), res.get("trail", -1) >= 5)
		check("tijdens het schot: speler op slot, can_fire 'bezig'", res.get("locked", false) and res.get("can_fire_busy") == "bezig")
		check("daarna: speler weer vrij, eerst 'afkoelen'", res.get("unlocked_after", false) and res.get("can_fire_after") == "afkoelen")
		check("na de cooldown weer schieten", await wait_until(func(): return v.can_fire() == "", 2.0))
	# 2) open vloer in alle 4 richtingen: nooit meer dan 3
	var all3 := true
	for t in room.ground.get_used_cells():
		if not standable(t):
			continue
		for d in DIRS:
			var r: Dictionary = v.trace(t, d)
			if r["tiles"].size() > 3 or (r["hit"] != null and r["hit"] != t + d * (r["tiles"].size() + 1)):
				all3 = false
	check("baan (alle tegels, 4 richtingen): max 3 tegels, treffer altijd direct na het vrije stuk", all3)
	# 3) spammen: tijdens het schot doet de knop niets
	s = find_shot(func(r): return r["tiles"].size() >= 2)
	if not s.is_empty():
		var p := player()
		p.place_at(s["start"], s["dir"])
		await frames(2)
		await wait_until(func(): return v.can_fire() == "", 2.0)
		var before: int = v.shots_fired
		for i in 6:
			await tap("kern")
		check("6x snel drukken = 1 schot (%d)" % (v.shots_fired - before), v.shots_fired - before == 1)
		await wait_until(func(): return not v.busy, 3.0)
		var t_cool := Time.get_ticks_msec()
		await tap("kern")
		check("tijdens de cooldown: geen schot", v.shots_fired - before == 1)
		await wait_until(func(): return v.can_fire() == "", 2.0)
		check("cooldown ~%.1f s" % KernVeld.COOLDOWN, (Time.get_ticks_msec() - t_cool) / 1000.0 <= KernVeld.COOLDOWN + 0.3)
		Input.action_press("move_up")
		await frames(4)
		Input.action_release("move_up")
		check("geen softlock: speler kan weer lopen", await wait_until(func(): return not p.input_locked, 1.0))
		await wait_until(func(): return not p.is_moving, 2.0)
	# 4) de KERN-knop op het touchscherm
	var tc := touch()
	check("KERN-knop zichtbaar (vrijgespeeld), boven de A-knop", tc != null and tc.show_kern and tc.kern_center().y < tc.a_center().y
			and Rect2(Vector2.ZERO, tc.size).has_point(tc.kern_center()))
	s = find_shot(func(r): return r["tiles"].size() >= 2)
	if tc != null and not s.is_empty():
		var p := player()
		p.place_at(s["start"], s["dir"])
		await frames(2)
		await wait_until(func(): return v.can_fire() == "", 2.0)
		await screenshot("kk_veld_knop")
		var before: int = v.shots_fired
		var ev := InputEventScreenTouch.new()
		ev.index = 6
		ev.position = get_tree().root.get_final_transform() * tc.kern_center()
		ev.pressed = true
		Input.parse_input_event(ev)
		await pframes(3)
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		check("tik op KERN = schot", await wait_until(func(): return v.shots_fired == before + 1, 1.0))
		await pframes(3)
		check("knop laat 'kern' los", not Input.is_action_pressed("kern"))
		await wait_until(func(): return not v.busy, 3.0)
	# 5) niet tijdens tekst of menu
	Dialog.show_lines(["Test."], "")
	await pframes(3)
	check("tijdens een tekstvak: niet schieten, knop weg", v.can_fire() != "" and not tc.show_kern)
	await close_dialog()
	await wait_until(func(): return v.can_fire() == "", 2.0)


# ================================================================ deel E: blokkades
## Schiet op het eerste object van soort 'kind' op de huidige kaart; true als het klopt.
func blocked_by(kind: String, shot_name := "") -> bool:
	var v := veld()
	var s := find_shot(func(r): return r["kind"] == kind)
	if s.is_empty():
		print("INFO  geen '%s' te raken op %s" % [kind, scene().name])
		return false
	var res := await shoot(s["start"], s["dir"], "", shot_name)
	var r: Dictionary = res.get("result", {})
	var hit: Vector2i = s["start"] + s["dir"] * (s["r"]["tiles"].size() + 1)
	var face := px(hit) - Vector2(s["dir"]) * 7.0
	var free_ok := true
	for t in r.get("tiles", []):
		if not v.blocker_at(t).is_empty():
			free_ok = false
	var ok: bool = r.get("kind") == kind and r.get("hit") == hit and free_ok \
			and res.get("impact_pos", Vector2(-999, -999)).distance_to(face) < 0.5
	check("geblokkeerd door '%s' (%s) op %s: stopt na %d tegel(s), inslag tegen de voorkant" % [kind, scene().name, hit, r.get("tiles", []).size()], ok)
	if ok:
		kinds_hit[kind] = scene().name
	return ok


func _blocker_tests() -> void:
	setup(SD.KLAAR, true)
	# puzzelkamer: muur, duwkast, hendel, poort (dicht), herstelsteen
	var room := await enter(PUZZEL_TEST, "ingang")
	if room != null:
		for k in ["muur", "block", "lever", "gate", "reset"]:
			await blocked_by(k, "kk_veld_geblokkeerd" if k == "block" else "")
		# een open poort houdt hem NIET tegen (shape uit + logica open)
	room = await enter(PUZZEL, "ingang")
	if room != null:
		for k in ["chest", "secret", "book"]:
			if not await blocked_by(k):
				print("INFO  (%s niet in archief_puzzel)" % k)
	room = await enter(GANG, "zuid")
	if room != null:
		await freeze_monsters()
		for k in ["chest", "muur"]:
			await blocked_by(k)
	room = await enter(INGANG, "ingang")
	if room != null:
		await freeze_monsters()
		await blocked_by("boek")     # opslagboek op de sokkel
	room = await enter(BIBLIOTHEEK, "zuid")
	if room != null:
		await freeze_monsters()
		for k in ["leesplek", "meubel"]:
			await blocked_by(k)
	# dorp: de Oude Man (NPC) staat er alleen voor de avond (show_if step_lt 40)
	setup(SD.TAKEN, true)
	room = await enter(DORP, "start")
	if room != null:
		for k in ["npc", "door", "sign", "story_object"]:
			await blocked_by(k)
	print("INFO  geraakte soorten: %s" % [kinds_hit])
	for k in ["muur", "block", "chest", "npc", "gate", "lever", "door"]:
		check("verplichte soort '%s' getest" % k, kinds_hit.has(k))
	# open poort: botsing uit + logica open -> de bal gaat erdoor
	room = await enter(KERN_DEMO, "ingang")
	if room != null and room.logic.gates.has("poort_1"):
		var v := veld()
		var gt: Vector2i = room.logic.gates["poort_1"]["tile"]
		check("kern_demo: dichte poort_1 houdt hem tegen", v.blocker_at(gt).get("kind", "") == "gate")
		room.logic.gates["poort_1"]["open"] = true
		room._sync_all()
		await frames(4)
		check("open poort_1: geen blokkade meer (%s)" % [v.blocker_at(gt)], v.blocker_at(gt).is_empty())


# ================================================================ deel F: stun
func _stun_tests() -> void:
	setup(SD.KLAAR, true)
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("archief_ingang geladen", false)
		return
	await freeze_monsters()
	var v := veld()
	var target: Node = null
	var s := {}
	for m in room.monsters:
		s = find_shot(func(r): return r["kind"] == "monster" and r["node"] == m, true)
		if not s.is_empty():
			target = m
			break
	check("een monster in schootsafstand gevonden", target != null)
	if target == null:
		return
	var mid: String = target.monster_id
	var res := await shoot(s["start"], s["dir"])
	var r: Dictionary = res.get("result", {})
	check("treffer op monster '%s': effect 'stun', %d stappen" % [mid, target.stun_steps], r.get("kind") == "monster"
			and r.get("effect") == "stun" and target.is_stunned() and target.stun_steps == KernVeld.STUN_STEPS)
	check("inslag midden op het monster", res.get("impact_pos", Vector2.ZERO).distance_to(target.position + KernVeld.CHEST) < 1.0)
	target.moves = true            # zou nu gaan lopen, maar is verlamd
	var t0: Vector2i = target.tile
	await get_tree().create_timer(0.35).timeout
	await screenshot("kk_veld_monster_verlamd")
	await get_tree().create_timer(2.6).timeout
	check("verlamd: blijft staan (%s) en is paars" % target.tile, target.tile == t0 and not target.is_moving
			and target.get_node_or_null("Verlamd") != null and target.sprite.modulate != Color.WHITE)
	room.monster_touch(target)
	await pframes(10)
	check("verlamd: aanraken start GEEN gevecht", not GameState.in_battle and battle() == null)
	# gevecht met een ANDER monster: de verlamming blijft (terug in de kamer)
	var other: Node = null
	for m in room.monsters:
		if is_instance_valid(m) and m != target:
			other = m
	if other != null:
		room.start_monster_battle(other)
		var b: Node = null
		if await wait_scene_named("Battle"):
			b = battle()
		check("gevecht met een ander monster gestart", b != null)
		if b != null:
			Engine.time_scale = 2.0
			await win(b)
			Engine.time_scale = 1.0
		check("terug in de kamer", await wait_scene_path(INGANG))
		await wait_fade()
		room = scene()
		target = room.get_monster(mid)
		check("na het andere gevecht: '%s' nog verlamd (%d)" % [mid, target.stun_steps if target else -1],
				target != null and target.stun_steps == KernVeld.STUN_STEPS and target.is_stunned())
		await close_dialog()
		await freeze_monsters(target)
	if target == null:
		return
	# 10 stappen van de speler: heen en weer
	var p := player()
	var a: Vector2i = p.get_tile()
	var dir := Vector2i.ZERO
	for d in DIRS:
		if standable(a + d) and not target.covers(a + d) and not target.covers(a + 2 * d):
			dir = d
			break
	check("ruimte om heen en weer te lopen", dir != Vector2i.ZERO)
	if dir == Vector2i.ZERO:
		return
	var steps := 0
	var counted := [0]
	var cb := func(_t): counted[0] += 1
	p.stepped.connect(cb)
	for i in 10:
		var act: String = ACTIONS[dir if i % 2 == 0 else -dir]
		Input.action_press(act)
		await wait_until(func(): return p.is_moving, 1.0)
		Input.action_release(act)
		await wait_until(func(): return not p.is_moving, 2.0)
		await frames(2)
		steps += 1
		if steps == 9:
			check("na 9 stappen (%d geteld): nog 1 over, nog verlamd" % counted[0], target.stun_steps == 1 and target.is_stunned())
	p.stepped.disconnect(cb)
	check("na 10 stappen: niet meer verlamd, paars weg", counted[0] == 10 and not target.is_stunned()
			and target.get_node_or_null("Verlamd") == null and target.sprite.modulate == Color.WHITE)
	var steps0: int = target.steps
	target.moves = true
	check("hij loopt weer (stappen %d -> ...)" % steps0, await wait_until(func(): return target.steps > steps0, 8.0))
	target.moves = false
	await wait_until(func(): return not target.is_moving, 2.0)
	room.monster_touch(target)
	check("aanraken start weer een gevecht", await wait_scene_named("Battle"))
	var b2 := battle()
	if b2 != null:
		Engine.time_scale = 2.0
		await win(b2)
		Engine.time_scale = 1.0
		await wait_scene_path(INGANG)
		await wait_fade()
		await close_dialog()


# ================================================================ deel G: baas
func _boss_tests() -> void:
	setup(SD.NACHT, true)
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	var golem: Node = room.get_monster("golem")
	check("de Golem staat er (baas)", golem != null and golem.boss)
	if golem == null:
		return
	var s := find_shot(func(r): return r["kind"] == "monster" and r["node"] == golem, true)
	check("Golem in schootsafstand", not s.is_empty())
	if s.is_empty():
		return
	var t0: Vector2i = golem.tile
	var res := await shoot(s["start"], s["dir"])
	var r: Dictionary = res.get("result", {})
	var hit: Vector2i = s["start"] + s["dir"] * (s["r"]["tiles"].size() + 1)
	check("baas: bal stopt op de Golem (inslag tegen de voorkant), effect 'baas'", r.get("kind") == "monster" and r.get("effect") == "baas"
			and res.get("impact_pos", Vector2.ZERO).distance_to(px(hit) - Vector2(s["dir"]) * 7.0) < 0.5)
	check("baas: geen stun, geen paars, staat waar hij stond", golem.stun_steps == 0 and not golem.is_stunned()
			and golem.get_node_or_null("Verlamd") == null and golem.tile == t0)
	golem.stun(10)
	check("ook direct stun(10) doet niets bij een baas", golem.stun_steps == 0)
	check("geen gevecht gestart door het schot", not GameState.in_battle)


# ================================================================ deel H: save/load
func _save_tests() -> void:
	setup(SD.KLAAR, true)
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("archief_ingang geladen", false)
		return
	await freeze_monsters()
	var target: Node = null
	var s := {}
	for m in room.monsters:
		s = find_shot(func(r): return r["kind"] == "monster" and r["node"] == m, true)
		if not s.is_empty():
			target = m
			break
	if target == null:
		check("monster voor de save-test", false)
		return
	await shoot(s["start"], s["dir"])
	check("monster verlamd voor het opslaan", target.is_stunned())
	var p := player()
	check("opslaan", GameState.save_game(p.get_tile(), p.facing))
	var raw := GameState.read_save(GameState.save_path)
	check("save bevat geen verlamming", not ("stun" in JSON.stringify(raw)) and raw.get("kernen", {}).has("golemkern"))
	GameState.new_game("Dax")
	check("nieuw spel: kernvuur weg", not KernVeld.unlocked())
	GameState.continue_game()
	check("laden: terug in de kamer", await wait_scene_path(INGANG))
	await wait_fade()
	await close_dialog()
	room = scene()
	var any_stun := false
	for m in room.monsters:
		if is_instance_valid(m) and (m.is_stunned() or m.get_node_or_null("Verlamd") != null):
			any_stun = true
	check("na laden: geen enkel monster verlamd (%d monsters)" % room.monsters.size(), not any_stun and room.monsters.size() > 0)
	check("na laden: Kernkracht nog vrijgespeeld, veld vrij", KernVeld.unlocked() and await wait_until(func(): return veld().can_fire() == "", 3.0)
			and not veld().busy and not player().input_locked)
	await pframes(3)
	check("na laden: KERN-knop zichtbaar", touch().show_kern)


# ================================================================ deel I: haak on_kernkracht_hit (v0.19)
const HOOK_SRC := "extends Node2D\nvar hits := 0\nvar veld: Node = null\nvar impact_before := false\n" \
		+ "func on_kernkracht_hit() -> void:\n\thits += 1\n\timpact_before = veld != null and veld.last_impact == null\n"


## Massief blokje (16x16) op tile t; met 'hook' = het blokje zelf heeft on_kernkracht_hit(),
## 'parent_hook' = alleen de parent heeft hem (het blokje zelf niet).
func dummy(t: Vector2i, hook: bool, parent_hook := false) -> Node2D:
	var body := StaticBody2D.new()
	body.name = "HaakTest"
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(14, 14)
	cs.shape = sh
	body.add_child(cs)
	var holder: Node2D = body
	if hook or parent_hook:
		var sc := GDScript.new()
		sc.source_code = HOOK_SRC.replace("extends Node2D", "extends StaticBody2D") if hook else HOOK_SRC
		sc.reload()
		if hook:
			body.set_script(sc)
			body.set("veld", veld())
		else:
			holder = Node2D.new()
			holder.set_script(sc)
			holder.set("veld", veld())
			holder.name = "HaakOuder"
			holder.add_child(body)
	var at := Vector2(t) * 16 + Vector2(8, 8)
	if holder == body:
		body.position = at
	else:
		body.position = at
	scene().get_node("Objects").add_child(holder)
	return holder


func _hook_tests() -> void:
	setup(SD.KLAAR, true)
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("archief_ingang geladen", false)
		return
	await freeze_monsters()
	var v := veld()
	# plek met 4 vrije tegels op een rij (dan kan er een blokje op tegel 2 en op tegel 4)
	var s := find_shot(func(r):
		if r["hit"] != null:
			return false
		var t4: Vector2i = r["tiles"][2] + (r["tiles"][2] - r["tiles"][1])
		return v.blocker_at(t4).is_empty() and room.ground.get_cell_source_id(t4) != -1)
	check("I: plek met 4 vrije tegels gevonden", not s.is_empty())
	if s.is_empty():
		return
	var st: Vector2i = s["start"]
	var d: Vector2i = s["dir"]
	# 1) treffer op tegel 2: precies 1x, vóór de inslag
	var a := dummy(st + d * 2, true)
	await frames(3)
	v.last_impact = null
	var res := await shoot(st, d)
	var r: Dictionary = res.get("result", {})
	check("I: blokje op tegel 2 met on_kernkracht_hit: 1x aangeroepen (%d), r.hook = blokje" % int(a.get("hits")),
			int(a.get("hits")) == 1 and r.get("hook") == a and r.get("hit") == st + d * 2)
	check("I: aangeroepen vóór de inslag", bool(a.get("impact_before")))
	a.queue_free()
	await frames(3)
	await wait_until(func(): return v.can_fire() == "", 2.0)
	# 2) buiten bereik (tegel 4): niets
	var far := dummy(st + d * 4, true)
	await frames(3)
	res = await shoot(st, d)
	r = res.get("result", {})
	check("I: blokje op tegel 4 (buiten bereik): niet aangeroepen, geen hook", int(far.get("hits")) == 0 and r.get("hook") == null and r.get("hit") == null)
	far.queue_free()
	await frames(3)
	await wait_until(func(): return v.can_fire() == "", 2.0)
	# 3) niet door een ander object heen
	var wall := dummy(st + d * 1, false)
	var behind := dummy(st + d * 2, true)
	await frames(3)
	res = await shoot(st, d)
	r = res.get("result", {})
	check("I: ander object ervoor (tegel 1): het blokje erachter krijgt niets", int(behind.get("hits")) == 0
			and r.get("hook") == null and r.get("hit") == st + d)
	wall.queue_free()
	behind.queue_free()
	await frames(3)
	await wait_until(func(): return v.can_fire() == "", 2.0)
	# 4) alleen de parent heeft de methode
	var par := dummy(st + d * 3, false, true)
	await frames(3)
	res = await shoot(st, d)
	r = res.get("result", {})
	check("I: methode op de parent: parent 1x aangeroepen", int(par.get("hits")) == 1 and r.get("hook") == par)
	par.queue_free()
	await frames(3)
	check("I: hook_target(null) / zonder methode = null", KernVeld.hook_target(null) == null and KernVeld.hook_target(room.ground) == null)


# ================================================================ deel J: Inktwurm-kast
func _kast_tests() -> void:
	setup(SD.KLAAR, true)
	GameState.story_flags.erase("inktwurm_kast_open")
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("J: Golem Hall geladen", false)
		return
	await freeze_monsters()
	var kast: Node = room.get_node_or_null("Objects/InktwurmKast")
	check("J: kast staat dicht rechts in de hal", kast != null and not kast.is_open and kast.tile == Vector2i(17, 5)
			and kast.sprite.hframes == 2 and kast.scheur.hframes == 4 and not kast.scheur.visible and kast.sprite.frame == 0)
	if kast == null:
		return
	var blocked: Dictionary = veld().blocker_at(Vector2i(17, 5))
	check("J: de vuurbal ziet de kast (soort inktwurm_kast)", blocked.get("kind") == "inktwurm_kast" and blocked.get("node") == kast)
	player().place_at(Vector2i(13, 6), Vector2i.RIGHT)
	await pframes(4)
	await screenshot("inktwurm_kast_dicht")
	var res := await shoot(Vector2i(15, 5), Vector2i.RIGHT)
	var r: Dictionary = res.get("result", {})
	check("J: schot vanaf (15,5) naar rechts raakt de kast", r.get("hook") == kast and r.get("hit") == Vector2i(17, 5)
			and r.get("kind") == "inktwurm_kast")
	var opened: bool = await wait_until(func(): return kast.is_open, 3.0)
	var said: bool = await wait_until(func(): return Dialog.is_open, 2.0)
	await close_dialog()
	var worm: Node = null
	for m in room.monsters:
		if is_instance_valid(m) and str(m.enemy_id) == "inktwurm":
			worm = m
	check("J: kast open, vlag gezet, botsing weg, tekst gezien", opened and said and GameState.story_flags.has("inktwurm_kast_open")
			and kast.shape.disabled and kast.sprite.frame == 1 and not kast.scheur.visible)
	check("J: Ink Worm staat in de kast en is nog te vangen", worm != null and worm.moves == false
			and worm.tile == Vector2i(16, 5) and GameState.unique_available("inktwurm"))
	player().place_at(Vector2i(13, 6), Vector2i.RIGHT)
	await pframes(4)
	await screenshot("inktwurm_kast_open")
	# zonder kern: de haak zelf weigert
	setup(SD.KLAAR, false)
	GameState.story_flags.erase("inktwurm_kast_open")
	room = await enter(GOLEM_SCENE, "zuid")
	kast = room.get_node_or_null("Objects/InktwurmKast") if room != null else null
	if kast == null:
		check("J: kast zonder kern geladen", false)
		return
	kast.on_kernkracht_hit()
	await pframes(8)
	check("J: zonder Golemkern blijft de kast dicht", not kast.is_open and not GameState.story_flags.has("inktwurm_kast_open")
			and kast.sprite.frame == 0)
	# opnieuw binnenkomen: open, worm er nog
	setup(SD.KLAAR, true)
	GameState.story_flags["inktwurm_kast_open"] = true
	room = await enter(GOLEM_SCENE, "zuid")
	kast = room.get_node_or_null("Objects/InktwurmKast") if room != null else null
	var worm2 := false
	if room != null:
		for m in room.monsters:
			if is_instance_valid(m) and str(m.enemy_id) == "inktwurm":
				worm2 = true
	check("J: na opnieuw binnenkomen staat de kast open en de Ink Worm er nog", kast != null and kast.is_open
			and kast.sprite.frame == 1 and not kast.scheur.visible and kast.shape.disabled and worm2)
