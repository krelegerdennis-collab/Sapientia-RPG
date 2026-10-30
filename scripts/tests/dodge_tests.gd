extends Node
## Actieve dodge + stamina (Combat D5). Start: godot --headless --path . -- --dodgetest

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const SomSlide := preload("res://scripts/som/som_slide.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"

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
	_constants_tests()
	_stamina_tests()
	_iframe_tests()
	_dodge_break_root_tests()
	_arena_hit_root_tests()
	_codec_stamina_tests()
	await _dodge_wall_tests()
	await _determinism_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _constants_tests() -> void:
	check("DODGE_IFRAME_TICKS = 15", SomData.DODGE_IFRAME_TICKS == 15)
	check("DODGE_DURATION_TICKS ~ DODGE_TIME", SomData.DODGE_DURATION_TICKS == 13)
	check("STAMINA_DODGE_COST = 30", SomData.STAMINA_DODGE_COST == 30)
	check("STAMINA_MAX = 100", SomData.STAMINA_MAX == 100)


func _stamina_tests() -> void:
	var s := CombatStamina.new()
	s.init_member("d")
	check("start vol", s.current("d") == SomData.STAMINA_MAX)
	check("dodge kost 30", s.spend("d", SomData.STAMINA_DODGE_COST) and s.current("d") == 70)
	check("geen dodge zonder stamina", not s.spend("d", 999))
	for _i in SomData.STAMINA_REGEN_DELAY_TICKS:
		s.tick_member("d", false)
	check("regen delay: nog 70", s.current("d") == 70)
	for _i in SomData.STAMINA_REGEN_EVERY_TICKS * 5:
		s.tick_member("d", false)
	check("regen na delay", s.current("d") > 70)


func _iframe_tests() -> void:
	var arena := SomArena.new()
	arena.down = false
	GameState.new_game("Dax")
	arena.combat_stamina.init_member("dennis")
	var hp0 := int(GameState.member("dennis")["hp"])
	arena.iframes["dennis"] = float(SomData.DODGE_IFRAME_TICKS) * CombatSim.TICK_DT
	arena.hit_member("dennis", 50, 1.0, 0)
	check("telegraaf/hit: geen schade tijdens dodge-iframes", int(GameState.member("dennis")["hp"]) == hp0)


func _dodge_break_root_tests() -> void:
	var roots := CombatRoots.new()
	roots.try_apply_root("dennis", 40)
	var arena := SomArena.new()
	arena.combat_roots = roots
	arena._dodge("dennis")
	check("_dodge roept break_root aan", not roots.is_rooted("dennis"))
	check("break_root immune", roots.ticks_immune("dennis") == CombatRoots.IMMUNITY_TICKS)


func _arena_hit_root_tests() -> void:
	var arena := SomArena.new()
	arena.down = false
	arena.combat_roots = CombatRoots.new()
	arena.combat_stamina = CombatStamina.new()
	GameState.new_game("Dax")
	arena.combat_stamina.init_member("dennis")
	arena.iframes.clear()
	arena.combat_roots.try_apply_root("dennis", 60)
	check("arena: root na echte klap-pad", arena.combat_roots.is_rooted("dennis"))
	arena.try_active_dodge("dennis", Vector2.RIGHT)
	check("active dodge breekt root", not arena.combat_roots.is_rooted("dennis"))


func _codec_stamina_tests() -> void:
	var s := CombatStamina.new()
	s.init_member("dennis", 88)
	var wire := Codec.pack_snapshot(1, [{"slot": 0, "x": 0, "y": 0, "face": 0, "frame": 0, "hp": 10, "mp": s.wire_stamina("dennis"), "flags": 0}], [])
	var snap := Codec.unpack_snapshot(wire)
	check("snapshot mp = stamina wire", int(snap["players"][0]["mp"]) == 88)


func _dodge_wall_tests() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.new_game("Dax")
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	var room: Node = null
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			room = s
			break
	if room == null:
		check("dodge muur: kamer geladen", false)
		return
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.combat_stamina.init_member("dennis")
	var wt := Vector2i(-1, -1)
	for y in range(2, 24):
		for x in range(2, 48):
			var c := Vector2i(x, y)
			if not room.is_wall(c) and room.is_wall(c + Vector2i.RIGHT):
				wt = c
				break
		if wt.x >= 0:
			break
	if wt.x < 0:
		check("dodge muur: tegel naast muur gevonden", false)
		return
	var p: CharacterBody2D = arena.player
	p.place_at(wt, Vector2i.RIGHT)
	var wall_cb := func(t: Vector2i) -> bool: return room.is_wall(t)
	check("dodge muur: start begaanbaar", not room.is_wall(p.get_tile()))
	check("dodge muur: dodge gestart", arena.try_active_dodge("dennis", Vector2.RIGHT))
	for _i in SomData.DODGE_DURATION_TICKS + 4:
		arena.step_ticks(1)
	check("dodge muur: tegel nog begaanbaar", not room.is_wall(p.get_tile()))
	check("dodge muur: hitbox niet in muur", not SomSlide.in_muur(p.position, wall_cb))
	check("dodge muur: niet op muurtegel", p.get_tile() != wt + Vector2i.RIGHT)


func _determinism_tests() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var arena := SomArena.new()
	arena.seed_rng(9001)
	var a := arena.rng.randi()
	arena.seed_rng(9001)
	check("rng: zelfde seed zelfde stream", arena.rng.randi() == a)
	arena.seed_rng(9002)
	check("rng: andere seed andere stream", arena.rng.randi() != a)
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	var log_a := await _fight_log(4242)
	var log_b := await _fight_log(4242)
	check("zelfde seed + dodge-inputs => zelfde log", log_a == log_b)


func _fight_log(seed: int) -> String:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	var room: Node = null
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			room = s
			break
	if room == null:
		return "NO_ROOM"
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.seed_rng(seed)
	for _i in 600:
		if room.monsters_active():
			break
		await get_tree().process_frame
	var log: Array = []
	for t in 80:
		arena.try_active_dodge("dennis", Vector2(1, 0) if t % 3 == 0 else Vector2(-1, 0))
		arena.step_ticks(1)
		log.append("%d:%d:%d" % [arena.sim_tick, arena.combat_stamina.current("dennis"), int(arena.iframes.get("dennis", 0.0) * 1000.0)])
	return "|".join(log)
