extends Node
## T29: aanval-gate-gaten. Start: godot --headless --path . -- --gategaptest
## 1) co-op-slot dat elke 6 ticks tapt krijgt niet meer slagen dan de per-slot swing-lock toelaat;
## 2) held zonder attack-sheet krijgt toch swing_lock > 0 (terugval op def "ms" / SomData.ATTACK_MS).

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const TAP_EVERY := 6
const TICKS := 300

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
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var r := await _setup_duo()
	if r.is_empty():
		check("kamer + Seren", false)
	else:
		_coop_spam_tests(r[1])
		_no_sheet_tests(r[1])
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


func _setup_duo() -> Array:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.add_member("lotte")
	var room := await _load_room()
	if room == null:
		return []
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.seed_rng(4242)
	if arena.ally_of("lotte") == null:
		return []
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			arena.enemies[k]["hp"] = 999999
	arena.allies_enabled = false
	return [room, arena]


func _inp(slot: int, buttons: int) -> Dictionary:
	return {"slot": slot, "stick": Vector2.ZERO, "buttons": buttons, "lock_idx": -1}


## Spam elke TAP_EVERY ticks; telt slagen (lock springt van 0 naar > 0) en controleert dat taps
## tijdens de lock genegeerd worden.
func _spam(arena: SomArena, slot: int) -> Dictionary:
	var swings := 0
	var taps := 0
	var ignored_ok := true
	var min_lock := INF
	for t in TICKS:
		var tap := t % TAP_EVERY == 0
		var before := float(arena._coop_swing_lock.get(slot, 0.0))
		var last_before := int(arena.chain_of(str(arena._coop_slots[slot])).get("last", -1))
		arena.coop_host_step([_inp(slot, Codec.BTN_ATTACK if tap else 0)], CombatSim.TICK_DT)
		var after := float(arena._coop_swing_lock.get(slot, 0.0))
		if tap:
			taps += 1
			if after > before:
				swings += 1
				min_lock = minf(min_lock, after + CombatSim.TICK_DT)   # al één tick afgeteld
			elif before > 0.0 and int(arena.chain_of(str(arena._coop_slots[slot])).get("last", -1)) != last_before:
				ignored_ok = false
	return {"swings": swings, "taps": taps, "ignored_ok": ignored_ok, "min_lock": min_lock}


func _coop_spam_tests(arena: SomArena) -> void:
	var peer: Node2D = arena.ally_of("lotte")
	arena.coop_sim_host = true
	arena.coop_local_slot = 0
	arena._coop_slots = {0: "dennis", 1: "lotte"}
	arena._coop_avatars = {1: peer}
	arena._coop_swing_lock.clear()
	arena._coop_attack_cd.clear()
	var res := _spam(arena, 1)
	var allowed := ceili(TICKS * CombatSim.TICK_DT / SomArena.COOP_MIN_SWING_LOCK) + 1
	var tap_ticks := ceili(SomArena.COOP_MIN_SWING_LOCK / CombatSim.TICK_DT / TAP_EVERY) * TAP_EVERY
	var allowed_tap := ceili(float(TICKS) / tap_ticks)
	print("  co-op spam: %d taps -> %d slagen (max lock-grens %d, tap-grid %d), min lock %.3f s" % [res.taps, res.swings, allowed, allowed_tap, res.min_lock])
	check("co-op: spam-taps leveren slagen op", res.swings > 0)
	check("co-op: minder slagen dan taps (lock werkt)", res.swings < res.taps)
	check("co-op: niet meer slagen dan de lock toelaat", res.swings <= allowed and res.swings <= allowed_tap)
	check("co-op: geen keten-stap tijdens lock", res.ignored_ok)
	check("co-op: lock per slag >= 0.35 s", res.min_lock >= SomArena.COOP_MIN_SWING_LOCK - 0.0001)
	# tap terwijl de lock loopt wordt genegeerd
	arena._coop_swing_lock.clear()
	arena._coop_attack_cd.clear()
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK)], CombatSim.TICK_DT)
	var c1: Dictionary = arena.chain_of("lotte").duplicate()
	arena._coop_attack_cd[1] = 0.0                 # alleen de swing-lock mag nu nog blokkeren
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK)], CombatSim.TICK_DT)
	var c2: Dictionary = arena.chain_of("lotte")
	check("co-op: tap tijdens swing-lock genegeerd (lock > 0, keten-stap gelijk)", float(arena._coop_swing_lock.get(1, 0.0)) > 0.0 and int(c2.get("last", -1)) == int(c1.get("last", -1)) and int(c2.get("next", -1)) == int(c1.get("next", -1)))
	# deterministisch: zelfde invoer -> zelfde aantal slagen
	arena._coop_swing_lock.clear()
	arena._coop_attack_cd.clear()
	arena.chains.erase("lotte")
	var a := _spam(arena, 1)
	arena._coop_swing_lock.clear()
	arena._coop_attack_cd.clear()
	arena.chains.erase("lotte")
	var b := _spam(arena, 1)
	check("co-op: deterministisch (zelfde invoer -> zelfde slagen)", a.swings == b.swings)


func _no_sheet_tests(arena: SomArena) -> void:
	check("geen sheet: _anim_seconds_def(lege def) > 0 (ATTACK_MS)", arena._anim_seconds_def("__geen_held__", {}) > 0.0)
	check("geen sheet: def ms gebruikt", is_equal_approx(arena._anim_seconds_def("__geen_held__", {"ms": [100, 200]}), 0.3))
	var saved = arena.attack_texs.get("lotte")
	arena.attack_texs.erase("lotte")
	arena._coop_swing_lock.clear()
	arena._coop_attack_cd.clear()
	arena.chains.erase("lotte")
	arena.coop_host_step([_inp(1, Codec.BTN_ATTACK)], CombatSim.TICK_DT)
	check("geen sheet: co-op-slot krijgt swing-lock > 0", float(arena._coop_swing_lock.get(1, 0.0)) > 0.0)
	var saved_d = arena.attack_texs.get("dennis")
	arena.attack_texs.erase("dennis")
	arena.swing_lock = 0.0
	arena.attack()
	check("geen sheet: single-player swing_lock > 0", arena.swing_lock > 0.0)
	if saved_d != null:
		arena.attack_texs["dennis"] = saved_d
	if saved != null:
		arena.attack_texs["lotte"] = saved
	arena.coop_sim_host = false
	arena._coop_slots = {}
	arena._coop_avatars = {}
