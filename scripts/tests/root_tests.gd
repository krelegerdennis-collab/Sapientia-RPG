extends Node
## Wortelgreep / root-status (Combat T6). Start: godot --headless --path . -- --roottest

const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const CombatSim := preload("res://scripts/som/combat_sim.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const Codec := preload("res://scripts/net/net_codec.gd")

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
	_root_test_data_tests()
	_max_and_stack_tests()
	_immunity_tests()
	_break_root_tests()
	_iframe_blocks_apply_tests()
	_clear_member_tests()
	_cancel_windup_no_root_tests()
	_determinism_frame_times_tests()
	_coop_root_wire_tests()
	_codec_v1_roots_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _root_test_data_tests() -> void:
	var def: Dictionary = EnemyAttacks.attack("root_test")
	check("root_test applies_root", bool(def.get("applies_root", false)))
	check("root_test root_ticks 60", int(def.get("root_ticks", 0)) == 60)
	check("snapshot atk_id root_test", TelegraphSnapshot.attack_index("root_test") == 3)


func _max_and_stack_tests() -> void:
	var r := CombatRoots.new()
	check("apply 60", r.try_apply_root("hero", 60) and r.ticks_rooted("hero") == 60)
	check("clamp >60", r.try_apply_root("hero", 999) and r.ticks_rooted("hero") == 60)
	r.try_apply_root("b", 30)
	r.try_apply_root("b", 50)
	check("stack = max niet som", r.ticks_rooted("b") == 50)
	r.try_apply_root("b", 40)
	check("lagere apply verhoogt niet", r.ticks_rooted("b") == 50)


func _immunity_tests() -> void:
	var r := CombatRoots.new()
	r.try_apply_root("h", 5)
	for _i in 5:
		r.tick()
	check("na root: immune 90", r.ticks_immune("h") == 90 and not r.is_rooted("h"))
	check("immune blokkeert root", not r.try_apply_root("h", 60))
	for _i in 90:
		r.tick()
	check("immune weg na 90 ticks", r.ticks_immune("h") == 0 and r.try_apply_root("h", 10))


func _break_root_tests() -> void:
	var r := CombatRoots.new()
	r.try_apply_root("d", 40)
	r.break_root("d")
	check("break_root: niet meer rooted", not r.is_rooted("d"))
	check("break_root start immune", r.ticks_immune("d") == CombatRoots.IMMUNITY_TICKS)


func _iframe_blocks_apply_tests() -> void:
	# Zelfde regel als SomArena.hit_member: root_ticks pas na landing, niet tijdens iframes.
	var r := CombatRoots.new()
	var iframes := {"hero": 0.5}
	var root_ticks := 60
	if float(iframes.get("hero", 0.0)) <= 0.0:
		r.try_apply_root("hero", root_ticks)
	check("iframes: geen root", not r.is_rooted("hero"))
	iframes["hero"] = 0.0
	if float(iframes.get("hero", 0.0)) <= 0.0:
		r.try_apply_root("hero", root_ticks)
	check("na iframes: root mag", r.is_rooted("hero"))


func _clear_member_tests() -> void:
	var r := CombatRoots.new()
	r.try_apply_root("a", 30)
	r.clear_member("a")
	check("clear_member KO/switch", not r.is_rooted("a") and r.ticks_immune("a") == 0)
	r.try_apply_root("z", 20)
	r.clear_all()
	check("clear_all arena exit", not r.is_rooted("z"))


func _cancel_windup_no_root_tests() -> void:
	var def: Dictionary = EnemyAttacks.attack("root_test")
	check("root_test data: applies_root + windup", bool(def.get("applies_root", false)) and int(def.get("windup_ms", 0)) > 0)
	var tg := TelegraphAttack.new()
	var roots := CombatRoots.new()
	tg.configure(def, 1200)
	tg.start(Vector2i(10, 10), Vector2i(256, 0), str(def.get("shape", "circle")))
	var half := maxi(1, tg.windup_duration_ticks() / 2)
	for _i in half:
		tg.tick()
	check("windup actief vóór cancel", tg.in_windup())
	tg.cancel()
	check("na cancel terug naar IDLE", tg.state() == TelegraphState.State.IDLE)
	var saw_active := false
	for _i in 120:
		if tg.entered_active_this_tick():
			saw_active = true
			var rt := int(def.get("root_ticks", CombatRoots.MAX_ROOT_TICKS))
			if bool(def.get("applies_root", false)) and rt > 0:
				roots.try_apply_root("victim", rt)
		tg.tick()
	check("cancel: ACTIVE nooit bereikt", not saw_active)
	check("cancel windup: geen root (SomArena-pad)", roots.rooted_ids().is_empty())
	var tg_ok := TelegraphAttack.new()
	tg_ok.configure(def, 1200)
	tg_ok.start(Vector2i(20, 20), Vector2i(256, 0), str(def.get("shape", "circle")))
	var reached_active := false
	for _i in tg_ok.windup_duration_ticks() + 4:
		if tg_ok.entered_active_this_tick():
			reached_active = true
			break
		tg_ok.tick()
	check("root_test bereikt ACTIVE zonder cancel", reached_active)


func _determinism_frame_times_tests() -> void:
	var patterns: Array = [
		[1.0 / 60.0],
		[1.0 / 30.0],
		[1.0 / 144.0],
		[0.25, 0.02, 0.11],
	]
	var ref := _root_event_log(patterns[0])
	for p in patterns:
		check("determinisme patroon %s" % str(p), _root_event_log(p) == ref)


func _root_event_log(chunk_deltas: Array) -> Array:
	var r := CombatRoots.new()
	r.try_apply_root("seed", 12)
	var clock := CombatSim.new()
	var log: Array = []
	var target_ticks := 110
	var produced := 0
	var ci := 0
	while produced < target_ticks:
		var d: float = chunk_deltas[ci % chunk_deltas.size()]
		ci += 1
		var n := clock.frames_to_ticks(d)
		for _i in n:
			if produced >= target_ticks:
				break
			produced += 1
			clock.tick += 1
			var rooted := r.is_rooted("seed")
			r.tick()
			log.append("t%d%s" % [clock.tick, "R" if rooted else ""])
			if not rooted and r.ticks_immune("seed") == CombatRoots.IMMUNITY_TICKS and clock.tick <= 20:
				log.append("IMM")
	return log


func _coop_root_wire_tests() -> void:
	var r := CombatRoots.new()
	var slots := {0: "dennis", 1: "lotte"}
	r.try_apply_root("lotte", 4)
	for _i in 4:
		r.tick()
	r.try_apply_root("dennis", 44)
	var wire := Codec.pack_snapshot(3, [], [], [], r.wire_rows(slots))
	var snap := Codec.unpack_snapshot(wire)
	var rows: Array = snap.get("roots", [])
	check("co-op roots roundtrip", rows.size() >= 1)
	var guest := CombatRoots.new()
	guest.apply_wire_rows(rows, slots)
	var got := guest.ticks_rooted("dennis")
	check("gast spiegelt host root", got == 44)


func _codec_v1_roots_tests() -> void:
	var roots_rows: Array = [
		{"slot": 0, "root_ticks": 55, "immune_ticks": 0},
		{"slot": 2, "root_ticks": 0, "immune_ticks": 77},
	]
	var wire := Codec.pack_snapshot(11, [], [], [], roots_rows)
	var snap := Codec.unpack_snapshot(wire)
	var unpacked: Array = snap.get("roots", [])
	check("codec v1 roots trailer count", unpacked.size() == 2)
	var r0: Dictionary = unpacked[0]
	check(
		"codec v1 root record velden",
		int(r0.get("slot", -1)) == 0
		and int(r0.get("root_ticks", 0)) == 55
		and int(r0.get("immune_ticks", 0)) == 0,
	)
	var r1: Dictionary = unpacked[1]
	check("codec v1 immune record", int(r1.get("slot", -1)) == 2 and int(r1.get("immune_ticks", 0)) == 77)
	var legacy := Codec.pack_snapshot(5, [], [], [])
	if legacy.size() > 0:
		legacy = legacy.slice(0, legacy.size() - 1)
	var leg := Codec.unpack_snapshot(legacy)
	check("legacy snapshot zonder root-trailer: tick", int(leg.get("tick", -1)) == 5)
	check("legacy snapshot zonder root-trailer: roots leeg", (leg.get("roots", []) as Array).is_empty())
