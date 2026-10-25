extends Node
## Co-op telegraaf-snapshot (Combat T5). Start: godot --headless --path . -- --telegraphcooptest

const Codec := preload("res://scripts/net/net_codec.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")

const PIN_COOLDOWN_MS := 1200
const SIM_TICKS := 120

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
	_codec_roundtrip_tests()
	_version_safety_tests()
	_host_guest_event_parity_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _codec_roundtrip_tests() -> void:
	var tg := _make_tg()
	tg.start(Vector2i(40, 50), Vector2i(256, 0), "line")
	tg.tick()
	var row := TelegraphSnapshot.merge_enemy_row(
		{"idx": 0, "x": 40, "y": 50, "hp": 30, "pose": 0, "target_slot": 1},
		tg,
		1,
	)
	var wire := Codec.pack_snapshot(7, [], [row])
	var snap := Codec.unpack_snapshot(wire)
	check("codec v1 tick", int(snap.get("tick", -1)) == 7)
	check("codec v1 version", int(snap.get("codec_version", -1)) == Protocol.SNAPSHOT_CODEC_VERSION)
	var erow: Dictionary = (snap.get("enemies", []) as Array)[0]
	check("codec atk_id", int(erow.get("atk_id", 0)) == TelegraphSnapshot.attack_index("inktspuw"))
	check("codec phase windup", int(erow.get("phase", 0)) == TelegraphState.State.WINDUP)
	check("codec origin", int(erow.get("ox", 0)) == 40 and int(erow.get("oy", 0)) == 50)
	check("codec payload <= budget", wire.size() <= Protocol.snapshot_payload_bytes() + 1)
	var legacy := Codec.pack_snapshot_v0(3, [{"slot": 0, "x": 1, "y": 2, "face": 0, "frame": 0, "hp": 10, "mp": 0, "flags": 0}], [])
	var leg := Codec.unpack_snapshot(legacy)
	check("legacy codec version 0", int(leg.get("codec_version", -1)) == 0)
	check("legacy enemy size", int((leg.get("enemies", []) as Array).size()) == 0 or int((leg.get("enemies", []) as Array)[0].get("atk_id", -1)) == 0)


func _version_safety_tests() -> void:
	var bad := PackedByteArray()
	bad.append(Protocol.BinKind.SNAPSHOT)
	bad.append(0)
	bad.append(0)
	bad.append(0xF0) # codec version 15
	bad.append(0)
	check("onbekende codec => leeg", Codec.unpack_snapshot(bad).is_empty())


func _host_guest_event_parity_tests() -> void:
	var host_events: Array = []
	var guest_events: Array = []
	var prev_rows: Dictionary = {}
	var target_px := Vector2i(62, 50)
	var players := [{"slot": 0, "x": target_px.x, "y": target_px.y, "face": 0, "frame": 0, "hp": 50, "mp": 0, "flags": 0}]
	var tg := _make_tg()
	tg.start(Vector2i(40, 50), Vector2i(256, 0), "line")
	for tick in SIM_TICKS:
		if tg.is_busy():
			tg.tick()
			var ev_h := TelegraphSnapshot.host_active_event(tick, 0, tg, 0, target_px)
			if not ev_h.is_empty():
				host_events.append(TelegraphSnapshot.event_key(ev_h))
		var row := TelegraphSnapshot.merge_enemy_row(
			{"idx": 0, "x": 40, "y": 50, "hp": 30, "pose": 0, "target_slot": 0},
			tg,
			0,
		)
		var wire := Codec.pack_snapshot(tick, players, [row])
		var snap := Codec.unpack_snapshot(wire)
		var erow: Dictionary = (snap.get("enemies", []) as Array)[0]
		var prev: Dictionary = prev_rows.get(0, {})
		var ev_g := TelegraphSnapshot.active_edge_event(
			tick,
			0,
			erow,
			prev,
			TelegraphSnapshot.player_pixel_map(snap),
		)
		if not ev_g.is_empty():
			guest_events.append(TelegraphSnapshot.event_key(ev_g))
		prev_rows[0] = erow.duplicate(true)
	check("host/guest zelfde aantal telegraaf-events", host_events.size() == guest_events.size())
	check("host/guest identieke event-reeks", host_events == guest_events)
	check("minstens één ACTIVE-event", host_events.size() > 0)


func _make_tg() -> TelegraphAttack:
	var def: Dictionary = SomActionAttacks.attack("inktspuw")
	var tg := TelegraphAttack.new()
	tg.configure(def, PIN_COOLDOWN_MS)
	return tg
