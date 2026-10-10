extends Node
## ALLEEN VOOR TESTEN - DUNGEON100 INTEGRATIE: generator + schaal/buit/bazen + regels (rustpunt, HUD, nederlaag).
## Start:  godot --path . -- --dungeon100integratietest [--shots=/pad/map]
##   Deel A: generator-data: de inhoud komt uit Dungeon100Scaling (monsters, kisten, baas op boss_slot van elke
##           10e verdieping) en Dungeon100Rules (rustpunt op rest_slot van elke 10e verdieping, spawn 'rustpunt').
##   Deel B: save/load: één blok "dungeon100" met verdieping, seed, checkpoint en best.
##   Deel C: echte scène op verdieping 10: baas + rustpunt + HUD-tekst + geschaalde monsters; echt baasgevecht.
##   Deel D: nederlaag in de grot: dood is dungeon uit (wereldkaart bij de ingang), daarna een nieuwe run op verdieping 1.
## Zit niet in de export (scripts/tests/*).

const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const S := preload("res://scripts/data/dungeon100_scaling.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const TOWN := "res://scenes/maps/wilgendal.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const U := Vector2i.UP
const D := Vector2i.DOWN
const L := Vector2i.LEFT
const R := Vector2i.RIGHT

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(1100)
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 400 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: generator-data ===")
	_data_tests()
	print("=== Deel B: save/load ===")
	_save_tests()
	print("=== Deel C: verdieping 10 in een echte scène ===")
	await _floor10_tests()
	print("=== Deel D: nederlaag in de grot ===")
	await _defeat_tests()
	print("DUNGEON100INTEGRATIETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


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


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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


func wait_floor(n: int, timeout := 15.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.name == "Dungeon100" and s.is_node_ready() and not GameState.changing_map \
				and int(s.get("floor_no")) == n and GameState.dungeon100_floor == n, timeout)
	await wait_fade()
	return ok


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map, timeout)
	await wait_fade()
	return ok


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))


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


## Expres verliezen zoals een speler (iedereen op 1 HP, alleen Verdedigen) tot de nederlaag is afgehandeld.
## Geeft de GAME OVER-tekst terug ("" = niet gezien).
func lose_battle() -> String:
	var over := ""
	Engine.time_scale = 3.0
	for guard in 200:
		var st := await wait_battle_state(["command", "message_wait"], 40)
		if st == "" or battle() == null:
			break
		var b := battle()
		if st == "command":
			for h in GameState.party:
				h["hp"] = mini(int(h["hp"]), 1)
			await cross_to(b, 3)
			await tap("interact")
		else:
			if "GAME OVER" in b.message_label.text:
				over = b.message_label.text
			await tap("interact")
	Engine.time_scale = 1.0
	return over


func fresh(run_seed: int, f: int) -> Dictionary:
	Gen._cache.clear()
	return Gen.generate(run_seed, f)


func tile_of(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


# ================================================================ deel A
func _data_tests() -> void:
	check("Dungeon100Rules.dungeon_scene wijst naar de scène van de generator", Rules.dungeon_scene == Gen.SCENE
			and Gen.SCENE == DUNGEON and Rules.scene_available())
	check("spawnnaam van het rustpunt is gelijk in generator en regels", Gen.SPAWN_REST == Rules.REST_SPAWN)
	var seeds := [1, 42, 987654321]
	var boss_ok := true
	var rest_ok := true
	var scale_ok := true
	var chest_ok := true
	var spawn_ok := true
	var no_boss_other := true
	var details := []
	for sd in seeds:
		for f in range(1, 101):
			var d := fresh(sd, f)
			var room: Dictionary = d["room"]
			var bosses: Array = room["monsters"].filter(func(m): return m.get("boss", false))
			if f % 10 == 0:
				var want := S.boss_for_floor(f)
				if bosses.size() != 1 or tile_of(bosses[0]["tile"]) != d["boss_slot"] or bosses[0]["enemy"] != want["enemy"] \
						or int(bosses[0]["floor"]) != f or not bosses[0].get("guard", false) or bosses[0].get("size", []) != [2, 2]:
					boss_ok = false
					details.append("baas sd%d vd%d" % [sd, f])
				if not room.has("rustpunt") or tile_of(room["rustpunt"]) != d["rest_slot"]:
					rest_ok = false
					details.append("rust sd%d vd%d" % [sd, f])
				else:
					var sp: Array = room["spawns"].get(Gen.SPAWN_REST, [])
					var rt: Vector2i = d["rest_slot"]
					if sp.size() < 3 or (tile_of(sp) - rt).length() != 1 or not Gen.reachable_tiles(room, d["spawn_up"]).has(tile_of(sp)):
						spawn_ok = false
						details.append("spawn sd%d vd%d" % [sd, f])
			else:
				if not bosses.is_empty():
					no_boss_other = false
				if room.has("rustpunt") or room["spawns"].has(Gen.SPAWN_REST):
					rest_ok = false
					details.append("rust-te-veel sd%d vd%d" % [sd, f])
			for m in room["monsters"]:
				if int(m["floor"]) != f:
					scale_ok = false
			for c in room["chests"]:
				var tier: int = int(c["loot"]["tier"])
				var expect := S.tier_for_floor(f)
				var kind := str(c.get("kind", "normaal"))
				var tier_ok := tier == expect or tier == expect - 1
				if kind == "blauw":
					tier_ok = tier == mini(S.MAX_TIER, expect + 1)
				if int(c["floor"]) != f or not tier_ok:
					chest_ok = false
					details.append("kist sd%d vd%d %s tier%d" % [sd, f, kind, tier])
	check("baas op boss_slot (2x2, bewaker, juiste vijand) op elke 10e verdieping en nergens anders %s" % [details.slice(0, 3)],
			boss_ok and no_boss_other)
	check("rustpunt op rest_slot op elke 10e verdieping en nergens anders", rest_ok)
	check("spawn 'rustpunt': vrije bereikbare buurtegel naast het rustpunt (10, 20 ... 100)", spawn_ok)
	check("elk monster draagt zijn verdieping (schaal via Dungeon100Scaling)", scale_ok)
	check("elke kist heeft vooraf gerolde schaalbuit van de juiste verdieping (niveau)", chest_ok)
	var d10 := fresh(7, 10)
	var d1 := fresh(7, 1)
	var m10: Dictionary = d10["room"]["monsters"][0]
	var m1: Dictionary = d1["room"]["monsters"][0]
	var s10 := S.battle_enemy(GD.ENEMIES[m10["enemy"]], 10, false)
	var s1 := S.battle_enemy(GD.ENEMIES[m1["enemy"]], 1, false)
	check("monsters op verdieping 10 zijn sterker dan op 1 (zelfde vijand: HP %d >= %d)" % [S.monster_stats(GD.ENEMIES["mosslijm"], 10)["max_hp"], S.monster_stats(GD.ENEMIES["mosslijm"], 1)["max_hp"]],
			int(S.monster_stats(GD.ENEMIES["mosslijm"], 10)["max_hp"]) > int(S.monster_stats(GD.ENEMIES["mosslijm"], 1)["max_hp"])
			and s10.has("max_hp") and s1.has("max_hp"))
	check("determinisme: dezelfde seed + verdieping geeft dezelfde baas/kisten/rustpunt",
			JSON.stringify(_plain(fresh(7, 30)["room"])) == JSON.stringify(_plain(fresh(7, 30)["room"])))
	check("alle uitzonderingen: verdieping 100 heeft de eindbaas en een rustpunt, geen trap omlaag",
			fresh(7, 100)["room"]["monsters"].any(func(m): return m.get("boss", false) and m["enemy"] == "kennis_beest")
			and fresh(7, 100)["room"].has("rustpunt") and not fresh(7, 100)["has_stairs_down"])


func _is_scaled_to_10(m: MapMonster) -> bool:
	var st: Dictionary = m.scaled_stats()
	var base: Dictionary = GD.ENEMIES[m.enemy_id]
	return m.floor_nr == 10 and int(st["max_hp"]) > int(base["max_hp"]) and int(st["exp"]) > int(base["exp"])


func _plain(v) -> Variant:
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _plain(v[k])
		return o
	if v is Array:
		return v.map(func(x): return _plain(x))
	if v is Vector2i or v is Rect2i:
		return str(v)
	return v


# ================================================================ deel B
func _save_tests() -> void:
	GameState.new_game("Dennis")
	check("nieuw spel: verdieping, seed, checkpoint en best zijn 0", GameState.dungeon100_floor == 0 and GameState.dungeon100_seed == 0
			and GameState.dungeon100_checkpoint == 0 and GameState.dungeon100_best == 0)
	GameState.dungeon100_floor = 37
	GameState.dungeon100_seed = 123456789
	GameState.dungeon100_checkpoint = 30
	GameState.dungeon100_best = 38
	var path := "user://dungeon100_integratie.json"
	check("opslaan", GameState.save_game(Vector2i(3, 3), Vector2i.DOWN, path))
	var raw := GameState.read_save(path)
	check("één blok 'dungeon100' met floor, seed, checkpoint en best", raw["dungeon100"] is Dictionary
			and int(raw["dungeon100"]["floor"]) == 37 and int(raw["dungeon100"]["seed"]) == 123456789
			and int(raw["dungeon100"]["checkpoint"]) == 30 and int(raw["dungeon100"]["best"]) == 38)
	GameState.new_game("Dennis")
	check("laden", GameState.load_game(path))
	check("na laden: alle vier terug", GameState.dungeon100_floor == 37 and GameState.dungeon100_seed == 123456789
			and GameState.dungeon100_checkpoint == 30 and GameState.dungeon100_best == 38)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.new_game("Dennis")


# ================================================================ deel C
func _floor10_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.dungeon100_seed = 4242
	GameState.dungeon100_floor = 10
	GameState.change_map(DUNGEON, "omhoog")
	check("verdieping 10 geladen", await wait_floor(10))
	var r := scene()
	var d: Dictionary = Gen.generate(4242, 10)
	var hud := GameState.get_node_or_null("Dungeon100Hud")
	await pframes(3)
	check("HUD-tekst: 'Verdieping 10/100' (rustverdieping)", hud != null and hud.visible and hud.shown_floor == 10
			and Rules.hud_text(GameState.dungeon100_floor) == "Verdieping 10/100")
	var rp: Node = r.get_node_or_null("Objects/Rustpunt")
	check("rustpunt staat op rest_slot %s" % [d["rest_slot"]], rp != null and rp is Dungeon100Rustpunt
			and Vector2i((rp.position / 16.0).floor()) == d["rest_slot"])
	var boss: MapMonster = null
	var normals: Array = []
	for m in r.monsters:
		if m.boss:
			boss = m
		else:
			normals.append(m)
	var bw := S.boss_for_floor(10)
	check("baas op boss_slot %s: %s (%s), 2x2, bewaker" % [d["boss_slot"], bw["name"], bw["enemy"]], boss != null
			and boss.tile == d["boss_slot"] and boss.enemy_id == bw["enemy"] and boss.size == Vector2i(2, 2) and not boss.moves
			and boss.floor_nr == 10)
	var bs: Dictionary = boss.scaled_stats() if boss else {}
	check("baas heeft baasstats van verdieping 10 (naam %s, HP %s)" % [bs.get("name"), bs.get("max_hp")],
			bs.get("name") == bw["name"] and int(bs.get("max_hp", 0)) == int(S.boss_stats(GD.ENEMIES[bw["enemy"]], 10)["max_hp"])
			and int(bs.get("max_hp", 0)) > 2 * int(S.monster_stats(GD.ENEMIES[bw["enemy"]], 10)["max_hp"]))
	check("gewone monsters (%d) zijn geschaald naar verdieping 10 (HP/EXP > basis)" % normals.size(), not normals.is_empty()
			and normals.all(_is_scaled_to_10))
	check("kisten (%d) hebben schaalbuit" % r.chests.size(), r.chests.all(func(c): return c.floor_nr == 10 and not c.loot.is_empty()))
	await screenshot("d100_integratie_verdieping10")

	# rustpunt echt activeren: checkpoint 10 + opslaan weigeren
	var pl := player()
	var start_best := GameState.dungeon100_best
	rp.interact(pl)
	for i in 40:
		if not rp.busy and not Dialog.is_open:
			break
		if Dialog.choices.size() == 2:
			await tap("cancel")
		else:
			await tap("interact")
	check("rustpunt aangeraakt: checkpoint 10, best >= 10", GameState.dungeon100_checkpoint == 10 and GameState.dungeon100_best >= 10
			and GameState.dungeon100_best >= start_best)

	# een echt baasgevecht vanuit de kamer
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	r.start_monster_battle(boss)
	var in_battle := await wait_until(func(): return scene() != null and scene().scene_file_path == GameState.BATTLE_SCENE and scene().is_node_ready(), 20.0)
	await pframes(3)
	var b := scene()
	check("baasgevecht gestart vanuit de kamer (baas, niet vluchten)", in_battle and GameState.pending_boss and not b.can_flee)
	var es: Dictionary = b.enemies[0]["s"]
	check("baasgevecht gebruikt de schaal van verdieping 10: %s, HP %s" % [es["name"], es["max_hp"]],
			es["name"] == bw["name"] and int(es["max_hp"]) == int(bs["max_hp"]))
	# vluchten: de run en het rustpunt blijven (het rustpunt is geen respawn)
	GameState.end_battle("flee")
	check("vluchten uit het baasgevecht: nog verdieping 10, checkpoint 10, baas staat er nog", await wait_floor(10)
			and GameState.dungeon100_checkpoint == 10 and GameState.dungeon100_run_active()
			and scene().monsters.any(func(m): return m.boss) and scene().get_node_or_null("Objects/Rustpunt") != null)

	# winst op de baas (kamerlogica): baas weg voor altijd (bewaker-vlag), rustpunt en verdieping blijven
	var r2 := scene()
	var boss2: MapMonster = r2.monsters.filter(func(m): return m.boss)[0]
	var bid: String = boss2.monster_id
	GameState.last_battle_result = "win"
	r2._restore_after_battle({"id": bid, "positions": {}})
	check("verslagen baas is weg en blijft weg (bewaker-vlag)", r2.monsters.all(func(m): return not m.boss)
			and GameState.story_flags.has(r2.guard_flag(r2.room_id, bid)))
	GameState.last_battle_result = ""
	check("verdieping, checkpoint en rustpunt blijven na de winst", GameState.dungeon100_floor == 10
			and GameState.dungeon100_checkpoint == 10 and r2.get_node_or_null("Objects/Rustpunt") != null)

	# verdieping zonder baas of rustpunt
	GameState.dungeon100_floor = 9
	GameState.change_map(DUNGEON, "omhoog")
	await wait_floor(9)
	check("verdieping 9: geen baas, geen rustpunt, HUD 'Verdieping 9/100'", scene().get_node_or_null("Objects/Rustpunt") == null
			and not scene().monsters.any(func(m): return m.boss) and hud.shown_floor == 9)


# ================================================================ deel D
func _defeat_tests() -> void:
	# nederlaag op verdieping 15, ook mét rustpunt 10: terug naar de wereldkaart bij de ingang
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.gold = 200
	GameState.inventory["kruid"] = 2
	GameState.party[0]["level"] = 5
	GameState.dungeon100_seed = 4242
	GameState.dungeon100_floor = 15
	GameState.dungeon100_checkpoint = 10
	GameState.dungeon100_best = 15
	GameState.change_map(DUNGEON, "omhoog")
	await wait_floor(15)
	check("binnenkomst start een run: level 1, geen goud, momentopname bewaart level 5 en 200 goud",
			GameState.dungeon100_run_active() and GameState.party[0]["level"] == 1 and GameState.gold == 0
			and int(GameState.dungeon100_snapshot["gold"]) == 200 and int(GameState.dungeon100_snapshot["party"][0]["level"]) == 5)
	var r := scene()
	var victim: MapMonster = r.monsters[0] if not r.monsters.is_empty() else null
	check("verdieping 15 met monsters", victim != null)
	var victim_enemy: String = victim.enemy_id
	r.start_monster_battle(victim)
	check("gevecht gestart", await wait_until(func(): return battle() != null and battle().is_node_ready(), 20.0))
	check("het monster is geschaald naar verdieping 15", int(battle().enemies[0]["s"]["max_hp"]) > int(GD.ENEMIES[victim_enemy]["max_hp"]))
	check("game-over-tekst: dood is het Archief uit (niet het rustpunt)", GameState.defeat_text(false).contains("Archief uit")
			and not GameState.defeat_text(false).contains("rustpunt"))
	await lose_battle()
	check("na de nederlaag: wereldkaart, niet de grot", await wait_scene_path(Rules.WORLD_SCENE))
	var wsp: Node2D = scene().get_node_or_null("Spawns/van_dungeon100")
	check("speler staat bij de ingang (spawn van_dungeon100)", wsp != null and tile() == Vector2i((wsp.position / 16.0).floor()))
	check("echte party terug: level 5, 200 goud, kruid 2, verdieping 0, run voorbij, best 15",
			GameState.party[0]["level"] == 5 and GameState.party[0]["hp"] == GameState.party[0]["max_hp"]
			and GameState.gold == 200 and GameState.item_count("kruid") == 2 and GameState.dungeon100_floor == 0
			and not GameState.dungeon100_run_active() and GameState.dungeon100_checkpoint == 0 and GameState.dungeon100_best == 15)
	var hud := GameState.get_node_or_null("Dungeon100Hud")
	check("HUD verborgen buiten de grot", hud != null and not hud.visible)
	await screenshot("d100_integratie_dood_uit")

	# opnieuw naar binnen: nieuwe run op verdieping 1, level 1; de echte voortgang blijft in de momentopname
	GameState.change_map(DUNGEON, "omhoog")
	check("nieuwe run na herintrede: verdieping 1, level 1", await wait_floor(1) and GameState.party[0]["level"] == 1
			and GameState.dungeon100_run_active() and GameState.dungeon100_seed != 0 and GameState.dungeon100_seed != 4242)
	check("de momentopname van de nieuwe run bewaart nog steeds level 5 en 200 goud",
			int(GameState.dungeon100_snapshot["party"][0]["level"]) == 5 and int(GameState.dungeon100_snapshot["gold"]) == 200)
	GameState.dungeon100_leave()
	check("verlaten zet de echte party terug", GameState.party[0]["level"] == 5 and GameState.gold == 200
			and not GameState.dungeon100_run_active())
	GameState.encounter_multiplier = 1.0
