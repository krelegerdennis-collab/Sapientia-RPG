class_name ActionSandboxSim
extends RefCounted
## Host-autoritaire Action-sandbox (puur; geen nodes). Vaste 60 Hz-tick.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")

const TICK_DT := 1.0 / float(Protocol.SIM_HZ)
const MOVE_SPEED := 48.0
const ATTACK_RANGE := 28.0
const ATTACK_DMG := 12
const ENEMY_SPEED := 32.0
const ENEMY_DMG := 8
const ENEMY_HP := 40
const PLAYER_HP := 100
const LOCK_TILES := 6.0
const LOCK_RADIUS := LOCK_TILES * 16.0

var tick: int = 0
var players: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func reset(seats: Array, seed: int = 0) -> void:
	tick = 0
	players.clear()
	enemies.clear()
	_rng.seed = seed if seed != 0 else 1337
	for slot in Protocol.MAX_PLAYERS:
		var row := _empty_player(slot)
		for s in seats:
			if int(s.get("slot", Protocol.NO_SLOT)) == slot:
				row["active"] = true
				row["character_id"] = str(s.get("character_id", ""))
				row["x"] = 80 + slot * 24
				row["y"] = 96
				break
		players.append(row)
	# Eén oefen-vijand voor sync-tests.
	enemies.append({
		"idx": 0,
		"x": 200,
		"y": 96,
		"hp": ENEMY_HP,
		"max_hp": ENEMY_HP,
		"pose": 0,
		"target_slot": Protocol.HOST_SLOT,
		"cd": 0.0,
	})


func _empty_player(slot: int) -> Dictionary:
	return {
		"active": false,
		"slot": slot,
		"character_id": "",
		"x": 80,
		"y": 96,
		"face": 0,
		"frame": 0,
		"hp": PLAYER_HP,
		"mp": 30,
		"flags": 0,
		"lock_idx": -1,
		"attack_cd": 0.0,
	}


func deactivate_slot(slot: int) -> void:
	if slot < 0 or slot >= players.size():
		return
	var p: Dictionary = players[slot]
	p["active"] = false
	p["flags"] = 0
	p["lock_idx"] = -1


func host_tick(inputs: Array) -> void:
	tick += 1
	for inp in inputs:
		_apply_input(inp)
	for p in players:
		if bool(p["active"]):
			p["attack_cd"] = maxf(0.0, float(p["attack_cd"]) - TICK_DT)
			_auto_lock(p)
	_enemy_step()
	_pack_flags()


func _apply_input(inp: Dictionary) -> void:
	var slot := int(inp.get("slot", Protocol.NO_SLOT))
	if slot < 0 or slot >= players.size():
		return
	var p: Dictionary = players[slot]
	if not bool(p["active"]):
		return
	var stick: Vector2 = inp.get("stick", Vector2.ZERO)
	if stick.length_squared() > 0.01:
		var dir := stick.normalized()
		p["x"] = int(p["x"]) + int(round(dir.x * MOVE_SPEED * TICK_DT))
		p["y"] = int(p["y"]) + int(round(dir.y * MOVE_SPEED * TICK_DT))
		p["face"] = _face_from_dir(dir)
	var buttons := int(inp.get("buttons", 0))
	if buttons & Codec.BTN_LOCK_TAP:
		var li := int(inp.get("lock_idx", -1))
		if li >= 0 and _enemy_alive(li):
			p["lock_idx"] = li
		else:
			p["lock_idx"] = _nearest_enemy_idx(Vector2(float(p["x"]), float(p["y"])))
	if buttons & Codec.BTN_ATTACK and float(p["attack_cd"]) <= 0.0:
		_try_attack(p)
		p["attack_cd"] = 0.35
	if buttons & Codec.BTN_RING:
		p["flags"] = int(p["flags"]) | Protocol.FLAG_RING_OPEN
	else:
		p["flags"] = int(p["flags"]) & ~Protocol.FLAG_RING_OPEN


func _auto_lock(p: Dictionary) -> void:
	var li := int(p["lock_idx"])
	if li >= 0 and _enemy_alive(li):
		return
	p["lock_idx"] = _nearest_enemy_idx(Vector2(float(p["x"]), float(p["y"])), LOCK_RADIUS)


func _try_attack(p: Dictionary) -> void:
	var origin := Vector2(float(p["x"]), float(p["y"]))
	var target_idx := int(p["lock_idx"])
	if target_idx < 0 or not _enemy_alive(target_idx):
		return
	var e: Dictionary = enemies[target_idx]
	var dist := origin.distance_to(Vector2(float(e["x"]), float(e["y"])))
	if dist > ATTACK_RANGE:
		return
	e["hp"] = maxi(0, int(e["hp"]) - ATTACK_DMG)
	p["flags"] = int(p["flags"]) | Protocol.FLAG_ATTACK
	if int(e["hp"]) <= 0:
		_remove_enemy(target_idx)


func _enemy_step() -> void:
	var host := players[Protocol.HOST_SLOT]
	if not bool(host.get("active", false)):
		return
	var target := Vector2(float(host["x"]), float(host["y"]))
	for e in enemies:
		if int(e["hp"]) <= 0:
			continue
		e["target_slot"] = Protocol.HOST_SLOT
		var pos := Vector2(float(e["x"]), float(e["y"]))
		var d := pos.distance_to(target)
		if d > 4.0:
			var step := (target - pos).normalized() * ENEMY_SPEED * TICK_DT
			e["x"] = int(round(float(e["x"]) + step.x))
			e["y"] = int(round(float(e["y"]) + step.y))
		e["cd"] = maxf(0.0, float(e.get("cd", 0.0)) - TICK_DT)
		if d <= ATTACK_RANGE and float(e["cd"]) <= 0.0:
			host["hp"] = maxi(0, int(host["hp"]) - ENEMY_DMG)
			e["cd"] = 0.8


func _remove_enemy(idx: int) -> void:
	for i in enemies.size():
		if int(enemies[i]["idx"]) == idx:
			enemies.remove_at(i)
			break
	for p in players:
		if int(p["lock_idx"]) == idx:
			p["lock_idx"] = -1


func _enemy_alive(idx: int) -> bool:
	for e in enemies:
		if int(e["idx"]) == idx and int(e["hp"]) > 0:
			return true
	return false


func _nearest_enemy_idx(from: Vector2, within: float = 1e9) -> int:
	var best := -1
	var bd := within
	for e in enemies:
		if int(e["hp"]) <= 0:
			continue
		var d := from.distance_to(Vector2(float(e["x"]), float(e["y"])))
		if d <= bd:
			bd = d
			best = int(e["idx"])
	return best


func _face_from_dir(dir: Vector2) -> int:
	if absf(dir.x) >= absf(dir.y):
		return 2 if dir.x > 0.0 else 0
	return 3 if dir.y > 0.0 else 1


func _pack_flags() -> void:
	for p in players:
		if int(p["hp"]) <= 0:
			p["flags"] = int(p["flags"]) | Protocol.FLAG_DOWN


func snapshot_rows() -> Dictionary:
	var plist: Array = []
	for p in players:
		if not bool(p["active"]):
			continue
		plist.append({
			"slot": int(p["slot"]),
			"x": int(p["x"]),
			"y": int(p["y"]),
			"face": int(p["face"]),
			"frame": int(p["frame"]),
			"hp": int(p["hp"]),
			"mp": int(p["mp"]),
			"flags": int(p["flags"]),
		})
	var elist: Array = []
	for e in enemies:
		if int(e["hp"]) <= 0:
			continue
		elist.append({
			"idx": int(e["idx"]),
			"x": int(e["x"]),
			"y": int(e["y"]),
			"hp": int(e["hp"]),
			"pose": int(e.get("pose", 0)),
			"target_slot": int(e.get("target_slot", Protocol.HOST_SLOT)),
		})
	return {"tick": tick, "players": plist, "enemies": elist}


func encode_snapshot() -> PackedByteArray:
	var snap := snapshot_rows()
	return Codec.pack_snapshot(int(snap["tick"]), snap["players"], snap["enemies"])


func apply_snapshot(snap: Dictionary) -> void:
	tick = int(snap.get("tick", tick))
	for row in snap.get("players", []):
		var slot := int(row.get("slot", Protocol.NO_SLOT))
		if slot < 0 or slot >= players.size():
			continue
		var p: Dictionary = players[slot]
		p["active"] = true
		p["x"] = int(row.get("x", p["x"]))
		p["y"] = int(row.get("y", p["y"]))
		p["face"] = int(row.get("face", 0))
		p["frame"] = int(row.get("frame", 0))
		p["hp"] = int(row.get("hp", p["hp"]))
		p["mp"] = int(row.get("mp", p["mp"]))
		p["flags"] = int(row.get("flags", 0))
	for row in snap.get("enemies", []):
		var idx := int(row.get("idx", -1))
		for e in enemies:
			if int(e["idx"]) == idx:
				e["x"] = int(row.get("x", e["x"]))
				e["y"] = int(row.get("y", e["y"]))
				e["hp"] = int(row.get("hp", e["hp"]))
				e["pose"] = int(row.get("pose", 0))
				e["target_slot"] = int(row.get("target_slot", Protocol.HOST_SLOT))
				break
