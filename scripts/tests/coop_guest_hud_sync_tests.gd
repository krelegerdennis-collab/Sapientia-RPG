extends Node
## Gast-HUD vitals na co-op snapshot. Start: godot --path . -- --coopguesthudsynctest

const Codec := preload("res://scripts/net/net_codec.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const SeatCtrl := preload("res://scripts/coop/seat_controller.gd")
const CoopRevive := preload("res://scripts/coop/coop_revive.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const CoopAvatar := preload("res://scripts/coop/coop_avatar.gd")

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
	_snapshot_max_hp_wire()
	_guest_apply_syncs_seat_rows()
	_host_pull_updates_max_hp()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _snapshot_max_hp_wire() -> void:
	var flags := Protocol.FLAG_RING_OPEN | (47 << 8)
	var snap := Codec.pack_snapshot(
		2,
		[{"slot": 0, "x": 10, "y": 20, "face": 0, "frame": 0, "hp": 36, "mp": 4, "flags": flags}],
		[],
	)
	var row: Dictionary = (Codec.unpack_snapshot(snap).get("players", []) as Array)[0]
	check("snapshot bewaart HP", int(row.get("hp", 0)) == 36)
	check("snapshot high byte = max_hp (niet down)", (int(row.get("flags", 0)) >> 8) & 0xFF == 47)
	var down_flags := Protocol.FLAG_DOWN | (55 << 8)
	check("down: high byte blijft revive-voortgang", CoopRevive.flag_is_down(down_flags) and CoopRevive.flag_progress(down_flags) == 55)


func _guest_apply_syncs_seat_rows() -> void:
	var arena := SomArena.new()
	add_child(arena)
	GameState.new_game()
	arena.coop_mode = true
	arena.coop_sim_host = false
	var sc := SeatCtrl.new()
	sc.configure("ROOM", false, 0)
	var dmax := int(GameState.member("dennis")["max_hp"])
	sc.assign([{"slot": 0, "uid": "g", "hero_id": "dennis", "controller": "remote", "hp": dmax, "max_hp": dmax}])
	arena.seat_controller = sc
	arena._coop_slots[0] = "dennis"
	var body := CoopAvatar.new()
	body.position = Vector2(8, 8)
	arena.add_child(body)
	arena._coop_avatars[0] = body
	var flags := (56 << 8)
	var snap := {
		"tick": 1,
		"players": [{"slot": 0, "x": 0, "y": 0, "face": 0, "hp": 36, "mp": 3, "flags": flags}],
		"enemies": [],
		"zones": [],
		"roots": [],
	}
	arena.apply_coop_snapshot(snap)
	var rows: Array = sc.hud_rows()
	var hud_hp := -1
	var hud_max := -1
	for r in rows:
		if int(r.get("slot", -1)) == 0:
			hud_hp = int(r.get("hp", -1))
			hud_max = int(r.get("max_hp", -1))
			break
	check("gast: seat-HP volgt snapshot", sc.hp_of(0) == 36 and hud_hp == 36)
	check("gast: seat max_hp volgt snapshot-flag", hud_max == 56)
	check("gast: member max_hp gezet", int(GameState.party[0]["max_hp"]) == 56 and int(GameState.party[0]["hp"]) == 36)
	arena.queue_free()


func _host_pull_updates_max_hp() -> void:
	var arena := SomArena.new()
	add_child(arena)
	GameState.new_game()
	arena.coop_mode = true
	arena.coop_sim_host = true
	var sc := SeatCtrl.new()
	sc.configure("ROOM", true, 0)
	var dmax := int(GameState.member("dennis")["max_hp"])
	sc.assign([{"slot": 0, "uid": "h", "hero_id": "dennis", "controller": "local", "hp": dmax, "max_hp": dmax}])
	arena.seat_controller = sc
	arena._coop_slots[0] = "dennis"
	GameState.member("dennis")["hp"] = 36
	GameState.member("dennis")["max_hp"] = 48
	arena._refresh_tracked_vitals()
	var rows: Array = sc.hud_rows()
	check("host: seat max_hp volgt member", int(rows[0].get("max_hp", 0)) == 48 and int(rows[0].get("hp", 0)) == 36)
	arena.queue_free()