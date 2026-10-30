extends Node
## 3-slag aanvalsketen (Combat T15, plan T18). Start: godot --headless --path . -- --chaintest
## Dax (dennis) en Seren (lotte): ketenvolgorde, venster-reset, finisher hitstop/knockback, dodge cancelt,
## geen keten in Classic.

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const HEROES: Array[String] = ["dennis", "lotte"]

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
	_data_tests()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	for id in HEROES:
		_progression_tests(id)
		_window_tests(id)
		_dodge_cancel_tests(id)
		_anim_def_tests(id)
	_classic_tests()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await _room_tests()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("data: keten van 3", SomChainData.CHAIN_LENGTH == 3 and SomChainData.STEP_STATES.size() == 3)
	check("data: venster ~20 ticks", SomChainData.CHAIN_WINDOW_TICKS == 20)
	check("data: finisher meer schade", SomChainData.damage_mult(2) > SomChainData.damage_mult(1) and SomChainData.damage_mult(1) >= SomChainData.damage_mult(0))
	check("data: finisher meer hitstop", SomChainData.hitstop_ticks(2) > SomChainData.hitstop_ticks(0) and SomChainData.hitstop_ticks(2) > SomChainData.hitstop_ticks(1))
	check("data: finisher meer knockback", SomChainData.knockback_tiles(2) > SomChainData.knockback_tiles(0) and SomChainData.knockback_tiles(2) > SomChainData.knockback_tiles(1))
	check("data: hit1 = gewone slag (1 tegel, geen hitstop)", SomChainData.knockback_tiles(0) == 1 and SomChainData.hitstop_ticks(0) == 0)


func _arena(id: String) -> SomArena:
	GameState.new_game("Dax")
	if id != "dennis":
		GameState.add_member(id)
	var a := SomArena.new()
	a.down = false
	a.combat_stamina = CombatStamina.new()
	a.combat_roots = CombatRoots.new()
	a.active_id = id
	a.combat_stamina.init_member(id)
	return a


func _progression_tests(id: String) -> void:
	var a := _arena(id)
	check("%s: start hit1" % id, a.chain_next == 0 and a.chain_state == "")
	a.attack()
	check("%s: tap 1 = hit1" % id, a.chain_last_step == 0 and a.chain_state == "hit1" and a.chain_next == 1)
	check("%s: venster open na hit1" % id, a.chain_window_ticks > 0)
	a.step_ticks(5)
	a.attack()
	check("%s: tap 2 = hit2" % id, a.chain_last_step == 1 and a.chain_state == "hit2" and a.chain_next == 2)
	a.step_ticks(5)
	a.attack()
	check("%s: tap 3 = finisher" % id, a.chain_last_step == 2 and a.chain_state == "finisher")
	check("%s: na finisher weer hit1" % id, a.chain_next == 0)
	a.attack()
	check("%s: tap 4 = hit1 opnieuw" % id, a.chain_last_step == 0 and a.chain_state == "hit1")
	a.free()


func _window_tests(id: String) -> void:
	var a := _arena(id)
	a.attack()
	var w := a.chain_window_ticks
	check("%s: venster = anim + CHAIN_WINDOW_TICKS" % id, w == ceili(a.swing_lock / CombatSim.TICK_DT - 0.0001) + SomChainData.CHAIN_WINDOW_TICKS)
	a.step_ticks(w - 1)
	check("%s: laatste venster-tick nog open" % id, a.chain_next == 1 and a.chain_window_ticks == 1)
	a.attack()
	check("%s: tap op de valreep = hit2" % id, a.chain_last_step == 1)
	a.step_ticks(a.chain_window_ticks)
	check("%s: venster verlopen -> reset" % id, a.chain_next == 0 and a.chain_window_ticks == 0 and a.chain_resets >= 1)
	a.attack()
	check("%s: na timeout = hit1 (geen finisher)" % id, a.chain_last_step == 0)
	a.free()


func _dodge_cancel_tests(id: String) -> void:
	var a := _arena(id)
	a.attack()
	a.attack()
	check("%s: keten op hit2" % id, a.chain_next == 2)
	var ok := a.try_active_dodge(id, Vector2.RIGHT)
	check("%s: dodge gestart" % id, ok)
	check("%s: dodge cancelt keten" % id, a.chain_next == 0 and a.chain_window_ticks == 0 and a.chain_state == "")
	a.attack()
	check("%s: na dodge = hit1" % id, a.chain_last_step == 0)
	a.free()


func _anim_def_tests(id: String) -> void:
	var base: Dictionary = SomData.ATTACK_ANIMS[id]
	var d1 := SomChainData.anim_def(base, 0)
	var d2 := SomChainData.anim_def(base, 1)
	var d3 := SomChainData.anim_def(base, 2)
	check("%s: elke stap eigen staat" % id, d1["chain_state"] == "hit1" and d2["chain_state"] == "hit2" and d3["chain_state"] == "finisher")
	check("%s: hit1 = bestaande anim" % id, d1["ms"] == base["ms"] and not d1["placeholder"])
	check("%s: hit2/finisher placeholder (TODO RPG ART)" % id, d2["placeholder"] and d3["placeholder"] and d2["sheet"] == base["sheet"])
	check("%s: hit2 en finisher ander tempo" % id, d2["ms"] != base["ms"] and d3["ms"] != base["ms"] and d2["ms"] != d3["ms"])


func _classic_tests() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	for id in HEROES:
		var a := _arena(id)
		a.attack()
		a.attack()
		a.attack()
		check("%s classic: geen keten" % id, a.chain_state == "" and a.chain_next == 0 and a.chain_window_ticks == 0 and a.chain_last_step == -1)
		a.free()


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


## Echte kamer: een vijand voor de held, drie taps -> finisher geeft meer hitstop en knockback.
func _room_tests() -> void:
	for id in HEROES:
		GameState.new_game("Dax")
		GameState.encounter_multiplier = 0.0
		if id != "dennis":
			GameState.add_member(id)
		var room := await _load_room()
		if room == null:
			check("%s kamer: geladen" % id, false)
			continue
		var arena: SomArena = room.som
		arena.set_process(false)
		arena.allies_enabled = false
		arena.seed_rng(777)
		if id != "dennis":
			arena.switch_hero(id)
		check("%s kamer: actieve held" % id, arena.active_id == id)
		var m: Node = null
		for k in arena.enemies.keys():
			if is_instance_valid(k):
				m = k
				break
		if m == null:
			check("%s kamer: vijand" % id, false)
			continue
		arena.enemies[m]["hp"] = 999999
		var res := []
		for step in 3:
			_line_up(room, arena, m)
			arena.charge = 1.0
			var before: Vector2i = m.tile
			var dmg0 := arena.last_enemy_damage
			arena.attack()
			# treffer valt op het hit-frame (met art): tot de slag landt doorstappen, binnen het venster
			for _t in 120:
				if arena.last_enemy_damage != dmg0 or arena.swing_lock <= 0.0:
					break
				arena.step_ticks(1)
			var stop := int(arena.enemies[m].get("hitstop", 0)) if arena.enemies.has(m) else 0
			res.append({"step": arena.chain_last_step, "hs": arena.last_hitstop_ticks, "kb": arena.last_knockback_tiles,
					"moved": absi(m.tile.x - before.x) + absi(m.tile.y - before.y), "stop": stop})
			for _t in 30:
				if not m.is_moving:
					break
				arena.step_ticks(1)
		print("  %s kamer: %s" % [id, str(res)])
		check("%s kamer: 3 stappen hit1/hit2/finisher" % id, res[0]["step"] == 0 and res[1]["step"] == 1 and res[2]["step"] == 2)
		check("%s kamer: finisher hitstop > hit1/hit2" % id, res[2]["hs"] > res[0]["hs"] and res[2]["hs"] > res[1]["hs"])
		check("%s kamer: vijand bevriest bij finisher" % id, res[2]["stop"] > 0)
		check("%s kamer: finisher knockback > hit1/hit2" % id, res[2]["kb"] > res[0]["kb"] and res[2]["kb"] > res[1]["kb"])
		check("%s kamer: finisher duwt verder" % id, res[2]["moved"] >= res[0]["moved"])
		var e: Dictionary = arena.enemies.get(m, {})
		var hs := int(e.get("hitstop", 0))
		arena.step_ticks(hs + 1)
		check("%s kamer: hitstop loopt af" % id, int(e.get("hitstop", 0)) == 0)


## Held en vijand op een rij met ruimte achter de vijand (zelfde kamer voor elke stap).
func _line_up(room: Node, arena: SomArena, m: Node) -> void:
	for y in range(2, 24):
		for x in range(2, 44):
			var c := Vector2i(x, y)
			var ok := true
			for dx in 5:
				if room.is_wall(c + Vector2i(dx, 0)):
					ok = false
					break
			if ok:
				arena.player.place_at(c, Vector2i.RIGHT)
				m.place_at(c + Vector2i.RIGHT, m.facing)
				return
