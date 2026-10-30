extends Node
## Opgeladen zware slag (charge attack, Action). Start: godot --headless --path . -- --chargetest
## Ontwerp: docs/combat/charge_attack.md. Dax (dennis) en Seren (lotte): niveaus, vertraging, zware slag,
## dodge annuleert, tap ongewijzigd, geen opladen in Classic, co-op-peer, bondgenoot-AI, determinisme.

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomHeavyData := preload("res://scripts/data/som_heavy_data.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
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
		await _hero_tests(id)
	await _classic_tests()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await _coop_tests()
	await _ally_tests()
	var a := await _determinism_log()
	var b := await _determinism_log()
	if a != b:
		var la := a.split("|")
		var lb := b.split("|")
		for i in mini(la.size(), lb.size()):
			if la[i] != lb[i]:
				print("  verschil op %d: %s vs %s" % [i, la[i], lb[i]])
				break
	check("determinisme: zelfde seed + inputs => zelfde log", a == b and a != "")
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _data_tests() -> void:
	check("data: 2 niveaus", SomHeavyData.MAX_LEVEL == 2 and SomHeavyData.LEVEL_TICKS.size() == 2)
	check("data: opladen pas na tap-drempel", SomHeavyData.HOLD_START_TICKS < SomHeavyData.LEVEL_TICKS[0])
	check("data: niveau per tick", SomHeavyData.level_for(0) == 0 and SomHeavyData.level_for(SomHeavyData.LEVEL_TICKS[0] - 1) == 0
			and SomHeavyData.level_for(SomHeavyData.LEVEL_TICKS[0]) == 1 and SomHeavyData.level_for(SomHeavyData.LEVEL_TICKS[1]) == 2
			and SomHeavyData.level_for(9999) == 2)
	check("data: niveau 2 > niveau 1 > finisher (schade)", SomHeavyData.damage_mult(2) > SomHeavyData.damage_mult(1)
			and SomHeavyData.damage_mult(1) > SomChainData.damage_mult(SomChainData.STEP_FINISHER))
	check("data: hitstop/knockback groter dan finisher", SomHeavyData.hitstop_ticks(1) > SomChainData.hitstop_ticks(2)
			and SomHeavyData.knockback_tiles(1) >= SomChainData.knockback_tiles(2) and SomHeavyData.knockback_tiles(2) > SomChainData.knockback_tiles(2))
	check("data: langzamer tijdens opladen", SomHeavyData.MOVE_MULT > 0.0 and SomHeavyData.MOVE_MULT < 1.0)
	check("data: geen MP-kosten", SomHeavyData.MP_COST == 0)


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


## [room, arena, vijand] met Dax + Seren in de party; [] = mislukt.
func _setup(active: String, seed := 4242) -> Array:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.add_member("lotte")
	var room := await _load_room()
	if room == null:
		return []
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.seed_rng(seed)
	if active != arena.active_id:
		arena.switch_hero(active)
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	if m == null or arena.active_id != active:
		return []
	arena.enemies[m]["hp"] = 999999
	_line_up(room, arena, m)
	return [room, arena, m]


func _line_up(room: Node, arena: SomArena, m: Node) -> void:
	for y in range(2, 24):
		for x in range(2, 44):
			var c := Vector2i(x, y)
			var ok := true
			for dx in 6:
				if room.is_wall(c + Vector2i(dx, 0)):
					ok = false
					break
			if ok:
				arena.player.place_at(c, Vector2i.RIGHT)
				m.place_at(c + Vector2i.RIGHT, m.facing)
				return


## Speler-input: indrukken (+ vasthouden) en n ticks vasthouden.
func _press_hold(arena: SomArena, ticks: int) -> void:
	arena._pending["attack"] = true
	arena._pending["hold"] = true
	arena.step_ticks(ticks)


func _release(arena: SomArena) -> void:
	arena._pending["hold"] = false
	arena.step_ticks(1)


## Doorstappen tot de (zware) slag geland is.
func _until_landed(arena: SomArena, hp_before: int, m: Node) -> void:
	for _t in 120:
		if int(arena.enemies[m]["hp"]) != hp_before:
			return
		arena.step_ticks(1)


func _settle(arena: SomArena, ticks := 100) -> void:
	arena._pending["hold"] = false
	arena.step_ticks(ticks)
	arena.chain_reset("*")


func _hero_tests(id: String) -> void:
	var r := await _setup(id)
	if r.is_empty():
		check("%s: kamer" % id, false)
		return
	var room: Node = r[0]
	var arena: SomArena = r[1]
	var m: Node = r[2]
	# tap = gewone ketenslag, geen zware slag
	arena.charge = 1.0
	var hp0 := int(arena.enemies[m]["hp"])
	arena._pending["attack"] = true
	arena._pending["hold"] = false
	arena.step_ticks(1)
	_until_landed(arena, hp0, m)
	var tap_dmg := hp0 - int(arena.enemies[m]["hp"])
	check("%s: tap = hit1 (keten), geen zware slag" % id, arena.chain_last_step == 0 and arena.heavy_releases == 0 and not arena.heavy_hold.has(id))
	check("%s: tap raakt" % id, tap_dmg > 0)
	_settle(arena)
	_line_up(room, arena, m)
	# vasthouden: drempel, vertraging, niveaus
	var mp0 := int(GameState.member(id)["mp"])
	_press_hold(arena, SomHeavyData.HOLD_START_TICKS - 2)
	check("%s: kort vasthouden = nog geen opladen" % id, not arena.heavy_charging(id) and is_equal_approx(arena._analog_speed(), SomData.MOVE_SPEED))
	arena.step_ticks(3)
	check("%s: opladen na HOLD_START_TICKS" % id, arena.heavy_charging(id))
	check("%s: langzamer tijdens opladen" % id, is_equal_approx(arena.heavy_move_mult(id), SomHeavyData.MOVE_MULT)
			and is_equal_approx(arena._analog_speed(), SomData.MOVE_SPEED * SomHeavyData.MOVE_MULT))
	arena.step_ticks(SomHeavyData.LEVEL_TICKS[0] - SomHeavyData.HOLD_START_TICKS)
	check("%s: niveau 1" % id, arena.heavy_level(id) == 1)
	arena.step_ticks(SomHeavyData.LEVEL_TICKS[1] - SomHeavyData.LEVEL_TICKS[0])
	check("%s: niveau 2" % id, arena.heavy_level(id) == 2)
	arena.step_ticks(60)
	check("%s: niveau blijft 2 (max)" % id, arena.heavy_level(id) == 2)
	_line_up(room, arena, m)
	var hp1 := int(arena.enemies[m]["hp"])
	var before: Vector2i = m.tile
	_release(arena)
	check("%s: loslaten = zware slag niveau 2" % id, arena.heavy_releases == 1 and arena.last_heavy_level == 2)
	check("%s: na loslaten normale snelheid" % id, not arena.heavy_charging(id) and is_equal_approx(arena._analog_speed(), SomData.MOVE_SPEED))
	_until_landed(arena, hp1, m)
	var heavy_dmg := hp1 - int(arena.enemies[m]["hp"])
	var stop := int(arena.enemies[m].get("hitstop", 0))
	check("%s: zware slag meer schade dan tap (%d > %d)" % [id, heavy_dmg, tap_dmg], heavy_dmg > tap_dmg)
	check("%s: hitstop niveau 2 (> finisher)" % id, arena.last_hitstop_ticks == SomHeavyData.hitstop_ticks(2) and stop > SomChainData.hitstop_ticks(2))
	check("%s: knockback niveau 2 (> finisher)" % id, arena.last_knockback_tiles == SomHeavyData.knockback_tiles(2))
	for _t in 30:
		if not m.is_moving:
			break
		arena.step_ticks(1)
	var moved := absi(m.tile.x - before.x) + absi(m.tile.y - before.y)
	check("%s: vijand verder geduwd (%d tegels)" % [id, moved], moved >= 2)
	check("%s: geen MP verbruikt" % id, int(GameState.member(id)["mp"]) == mp0)
	check("%s: keten terug op hit1 na zware slag" % id, int(arena.chain_of(id)["next"]) == 0 or arena.chain_last_step == 0)
	_settle(arena)
	_line_up(room, arena, m)
	# niveau 1
	_press_hold(arena, SomHeavyData.LEVEL_TICKS[0] + 2)
	_release(arena)
	check("%s: loslaten op niveau 1" % id, arena.heavy_releases == 2 and arena.last_heavy_level == 1)
	_settle(arena)
	# te vroeg losgelaten: niets extra
	_press_hold(arena, SomHeavyData.LEVEL_TICKS[0] - 5)
	_release(arena)
	check("%s: loslaten voor niveau 1 = geen zware slag" % id, arena.heavy_releases == 2)
	_settle(arena)
	# dodge annuleert
	arena.combat_stamina.init_member(id)
	_press_hold(arena, SomHeavyData.LEVEL_TICKS[0] + 10)
	check("%s: oplaad voor dodge" % id, arena.heavy_level(id) == 1)
	var ok := arena.try_active_dodge(id, Vector2.UP)
	check("%s: dodge gestart" % id, ok)
	check("%s: dodge annuleert opladen" % id, not arena.heavy_hold.has(id) and not arena.heavy_charging(id))
	_release(arena)
	check("%s: na dodge geen zware slag bij loslaten" % id, arena.heavy_releases == 2)


func _classic_tests() -> void:
	var r := await _setup("dennis")
	if r.is_empty():
		check("classic: kamer", false)
		return
	var arena: SomArena = r[1]
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	_press_hold(arena, SomHeavyData.LEVEL_TICKS[1] + 5)
	check("classic: geen opladen", not arena.heavy_hold.has("dennis") and not arena.heavy_charging("dennis"))
	_release(arena)
	check("classic: geen zware slag", arena.heavy_releases == 0)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)


func _inp(slot: int, buttons: int, stick := Vector2.ZERO) -> Dictionary:
	return {"slot": slot, "stick": stick, "buttons": buttons, "lock_idx": -1}


## Co-op-peer (slot 1 = Seren) laadt op via BTN_ATTACK_HELD; de host telt.
func _coop_tests() -> void:
	var r := await _setup("dennis")
	if r.is_empty():
		check("co-op: kamer", false)
		return
	var room: Node = r[0]
	var arena: SomArena = r[1]
	var m: Node = r[2]
	var peer: Node2D = arena.ally_of("lotte")
	arena.coop_sim_host = true
	arena.coop_local_slot = 0
	arena._coop_slots = {0: "dennis", 1: "lotte"}
	arena._coop_avatars = {1: peer}
	peer.position = arena.player.position
	peer.facing = Vector2i.RIGHT
	var dt := CombatSim.TICK_DT
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK | Codec.BTN_ATTACK_HELD)], dt)
	check("co-op: indrukken = hit1 + teller", int(arena.chain_of("lotte")["last"]) == 0 and arena.heavy_hold.has("lotte"))
	for _t in SomHeavyData.HOLD_START_TICKS + 2:
		arena.coop_host_step([_inp(1, Codec.BTN_ATTACK_HELD)], dt)
	check("co-op: peer laadt op", arena.heavy_charging("lotte") and not arena.heavy_charging("dennis"))
	var p0: Vector2 = peer.position
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK_HELD, Vector2.DOWN)], dt)
	var slow_step := peer.position.distance_to(p0)
	check("co-op: peer langzamer tijdens opladen", is_equal_approx(slow_step, SomData.MOVE_SPEED * SomHeavyData.MOVE_MULT * dt))
	peer.position = p0
	for _t in SomHeavyData.LEVEL_TICKS[0]:
		arena.coop_host_step([_inp(1, Codec.BTN_ATTACK_HELD)], dt)
	check("co-op: peer niveau 1", arena.heavy_level("lotte") >= 1)
	arena.coop_host_step([_inp(1, 0)], dt)
	check("co-op: loslaten = zware slag", arena.heavy_releases == 1 and arena.last_heavy_level >= 1 and not arena.heavy_hold.has("lotte"))
	# dodge annuleert ook bij een peer
	arena.combat_stamina.init_member("lotte")
	for _t in 40:
		arena.coop_host_step([_inp(1, 0)], dt)
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK | Codec.BTN_ATTACK_HELD)], dt)
	for _t in SomHeavyData.LEVEL_TICKS[0] + 2:
		arena.coop_host_step([_inp(1, Codec.BTN_ATTACK_HELD)], dt)
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK_HELD | Codec.BTN_DODGE, Vector2.UP)], dt)
	check("co-op: peer-dodge annuleert opladen", not arena.heavy_hold.has("lotte"))
	arena.coop_host_step([_inp(1, 0)], dt)
	check("co-op: geen zware slag na peer-dodge", arena.heavy_releases == 1)
	arena.coop_sim_host = false
	arena._coop_slots = {}
	arena._coop_avatars = {}


## Bondgenoot-AI (Seren): keten hit1 -> hit2 -> finisher, daarna laadt hij op en laat los (zware slag).
func _ally_tests() -> void:
	var r := await _setup("dennis")
	if r.is_empty():
		check("ally-AI: kamer", false)
		return
	var arena: SomArena = r[1]
	var m: Node = r[2]
	arena.allies_enabled = true
	var ally: Node = arena.ally_of("lotte")
	ally.position = m.position + Vector2(-14, 0)
	ally.charge = 1.0
	var saw_charging := false
	var saw_slow := false
	var seq: Array = []
	var last := ""
	for _t in 1200:
		arena.player.position = m.position + Vector2(-20, 6)
		arena.step_ticks(1)
		var c: Dictionary = arena.chain_of("lotte")
		var key := "%s@%d" % [c["state"], int(c["last"])]
		if str(c["state"]) != "" and key != last:
			seq.append(int(c["last"]))
			last = key
		if arena.heavy_charging("lotte"):
			saw_charging = true
			saw_slow = saw_slow or is_equal_approx(arena.heavy_move_mult("lotte"), SomHeavyData.MOVE_MULT)
		if arena.heavy_releases > 0:
			break
	print("  ally-AI: keten %s, zware slagen %d (niveau %d)" % [str(seq), arena.heavy_releases, arena.last_heavy_level])
	check("ally-AI: eerst de keten", seq.size() >= 3 and seq.slice(0, 3) == [0, 1, 2])
	check("ally-AI: laadt op na de finisher", saw_charging and saw_slow)
	check("ally-AI: zware slag op ALLY_LEVEL", arena.heavy_releases == 1 and arena.last_heavy_level == SomHeavyData.ALLY_LEVEL)
	check("ally-AI: Dax laadt niet op", not arena.heavy_hold.has("dennis"))
	arena.allies_enabled = false


func _determinism_log() -> String:
	var r := await _setup("dennis", 9001)
	if r.is_empty():
		return ""
	var arena: SomArena = r[1]
	var m: Node = r[2]
	# Bondgenoten uit en geen vijand-hp in de log: de knockback-tween (bestaande code) loopt op frametijd,
	# dus een volgende slag kan de vijand net wel/niet raken. Hier gaat het om de oplaad-logica zelf.
	arena.allies_enabled = false
	var log: Array = []
	for t in 240:
		var phase := t % 120
		arena._pending["attack"] = phase == 0 or phase == 100
		arena._pending["hold"] = phase < 60 or phase >= 100
		arena.step_ticks(1)
		log.append("%d:%d:%d:%d:%d:%s" % [arena.sim_tick, arena.heavy_releases, arena.last_heavy_level,
				int(arena.heavy_hold.get("dennis", -1)), int(arena.chain_of("dennis")["window"]), str(arena.heavy_charging("dennis"))])
	return "|".join(log)
