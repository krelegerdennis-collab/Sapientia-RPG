class_name NetCodec
extends RefCounted
## Binair inpakken voor Action-co-op (docs/fase_b/ARCHITECTUUR.md, net_protocol.gd).

const Protocol := preload("res://scripts/net/net_protocol.gd")
const INPUT_SIZE := Protocol.INPUT_BYTES
const PLAYER_SIZE := Protocol.SNAPSHOT_PLAYER_BYTES
const ENEMY_SIZE := Protocol.SNAPSHOT_ENEMY_BYTES_V1
const HEADER_SIZE := Protocol.SNAPSHOT_HEADER_BYTES
const CODEC_VERSION := Protocol.SNAPSHOT_CODEC_VERSION

const BTN_ATTACK := 1
const BTN_RING := 2
const BTN_LOCK_TAP := 4


static func pack_wire_input(slot: int, stick: Vector2, buttons: int, lock_idx: int) -> PackedByteArray:
	var body := pack_input(slot, stick, buttons, lock_idx)
	var wire := PackedByteArray()
	wire.append(Protocol.BinKind.INPUT)
	wire.append_array(body)
	return wire


static func unpack_wire_input(raw: PackedByteArray) -> Dictionary:
	if raw.size() < 1 + INPUT_SIZE or int(raw[0]) != Protocol.BinKind.INPUT:
		return {}
	return unpack_input(raw.slice(1))


static func pack_input(slot: int, stick: Vector2, buttons: int, lock_idx: int) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(INPUT_SIZE)
	buf[0] = clampi(slot, 0, Protocol.MAX_PLAYERS - 1)
	buf[1] = _clamp_stick(stick.x)
	buf[2] = _clamp_stick(stick.y)
	buf[3] = buttons & 0xFF
	buf[4] = clampi(lock_idx, -1, Protocol.SNAPSHOT_ENEMY_BUDGET - 1) & 0xFF
	buf[5] = 0
	return buf


static func unpack_input(raw: PackedByteArray) -> Dictionary:
	if raw.size() < INPUT_SIZE:
		return {}
	return {
		"slot": int(raw[0]),
		"stick": Vector2(_unpack_stick(raw[1]), _unpack_stick(raw[2])),
		"buttons": int(raw[3]),
		"lock_idx": int(raw[4]) if int(raw[4]) < 128 else int(raw[4]) - 256,
	}


static func pack_snapshot(tick: int, players: Array, enemies: Array) -> PackedByteArray:
	return _pack_snapshot_version(tick, players, enemies, CODEC_VERSION)


static func pack_snapshot_v0(tick: int, players: Array, enemies: Array) -> PackedByteArray:
	return _pack_snapshot_version(tick, players, enemies, 0)


static func _pack_snapshot_version(tick: int, players: Array, enemies: Array, codec_version: int) -> PackedByteArray:
	var buf := PackedByteArray()
	var pc := mini(players.size(), Protocol.MAX_PLAYERS)
	var ec := mini(enemies.size(), Protocol.SNAPSHOT_ENEMY_BUDGET)
	var enemy_sz := _enemy_wire_bytes(codec_version)
	buf.resize(HEADER_SIZE + pc * PLAYER_SIZE + ec * enemy_sz)
	buf[0] = Protocol.BinKind.SNAPSHOT
	buf[1] = tick & 0xFF
	buf[2] = (tick >> 8) & 0xFF
	buf[3] = (pc & 0x0F) | ((codec_version & 0x0F) << 4)
	buf[4] = ec
	var off := HEADER_SIZE
	for i in pc:
		off = _pack_player(buf, off, players[i])
	for i in ec:
		off = _pack_enemy(buf, off, enemies[i], codec_version)
	return buf


static func unpack_snapshot(raw: PackedByteArray) -> Dictionary:
	if raw.size() < HEADER_SIZE or int(raw[0]) != Protocol.BinKind.SNAPSHOT:
		return {}
	var tick := int(raw[1]) | (int(raw[2]) << 8)
	var codec_version := (int(raw[3]) >> 4) & 0x0F
	var pc := int(raw[3]) & 0x0F
	var ec := int(raw[4])
	if codec_version > CODEC_VERSION:
		return {}
	var enemy_sz := _enemy_wire_bytes(codec_version)
	var need := HEADER_SIZE + pc * PLAYER_SIZE + ec * enemy_sz
	if raw.size() < need:
		return {}
	var off := HEADER_SIZE
	var players: Array = []
	for i in pc:
		var row: Dictionary = {}
		off = _unpack_player(raw, off, row)
		players.append(row)
	var enemies: Array = []
	for i in ec:
		var row: Dictionary = {}
		off = _unpack_enemy(raw, off, row, codec_version)
		enemies.append(row)
	return {"tick": tick, "codec_version": codec_version, "players": players, "enemies": enemies}


static func _enemy_wire_bytes(codec_version: int) -> int:
	return Protocol.SNAPSHOT_ENEMY_BYTES_V0 if codec_version <= 0 else Protocol.SNAPSHOT_ENEMY_BYTES_V1


static func _pack_player(buf: PackedByteArray, off: int, p: Dictionary) -> int:
	buf[off] = int(p.get("slot", 0)) & 0xFF
	_write_i16(buf, off + 1, int(p.get("x", 0)))
	_write_i16(buf, off + 3, int(p.get("y", 0)))
	var face := clampi(int(p.get("face", 0)), 0, 15)
	var frame := clampi(int(p.get("frame", 0)), 0, 15)
	buf[off + 5] = (face & 0x0F) | ((frame & 0x0F) << 4)
	_write_u16(buf, off + 6, int(p.get("hp", 0)))
	buf[off + 8] = clampi(int(p.get("mp", 0)), 0, 255)
	_write_u16(buf, off + 9, int(p.get("flags", 0)))
	return off + PLAYER_SIZE


static func _unpack_player(raw: PackedByteArray, off: int, out: Dictionary) -> int:
	out["slot"] = int(raw[off])
	out["x"] = _read_i16(raw, off + 1)
	out["y"] = _read_i16(raw, off + 3)
	var fb := int(raw[off + 5])
	out["face"] = fb & 0x0F
	out["frame"] = (fb >> 4) & 0x0F
	out["hp"] = _read_u16(raw, off + 6)
	out["mp"] = int(raw[off + 8])
	out["flags"] = _read_u16(raw, off + 9)
	return off + PLAYER_SIZE


static func _pack_enemy(buf: PackedByteArray, off: int, e: Dictionary, codec_version: int) -> int:
	buf[off] = int(e.get("idx", 0)) & 0xFF
	_write_i16(buf, off + 1, int(e.get("x", 0)))
	_write_i16(buf, off + 3, int(e.get("y", 0)))
	_write_u16(buf, off + 5, int(e.get("hp", 0)))
	buf[off + 7] = clampi(int(e.get("pose", 0)), 0, 255)
	buf[off + 8] = clampi(int(e.get("target_slot", 0)), 0, Protocol.MAX_PLAYERS - 1)
	var end := off + Protocol.SNAPSHOT_ENEMY_BYTES_V0
	if codec_version <= 0:
		return end
	buf[off + 9] = clampi(int(e.get("atk_id", 0)), 0, 255)
	buf[off + 10] = clampi(int(e.get("phase", 0)), 0, 255)
	buf[off + 11] = clampi(int(e.get("t", 0)), 0, 255)
	_write_i16(buf, off + 12, int(e.get("ox", 0)))
	_write_i16(buf, off + 14, int(e.get("oy", 0)))
	_write_i16(buf, off + 16, int(e.get("dir_x", 0)))
	_write_i16(buf, off + 18, int(e.get("dir_y", 0)))
	return off + Protocol.SNAPSHOT_ENEMY_BYTES_V1


static func _unpack_enemy(raw: PackedByteArray, off: int, out: Dictionary, codec_version: int) -> int:
	out["idx"] = int(raw[off])
	out["x"] = _read_i16(raw, off + 1)
	out["y"] = _read_i16(raw, off + 3)
	out["hp"] = _read_u16(raw, off + 5)
	out["pose"] = int(raw[off + 7])
	out["target_slot"] = int(raw[off + 8])
	var end := off + Protocol.SNAPSHOT_ENEMY_BYTES_V0
	if codec_version <= 0:
		out["atk_id"] = 0
		out["phase"] = 0
		out["t"] = 0
		out["zones"] = []
		return end
	out["atk_id"] = int(raw[off + 9])
	out["phase"] = int(raw[off + 10])
	out["t"] = int(raw[off + 11])
	out["ox"] = _read_i16(raw, off + 12)
	out["oy"] = _read_i16(raw, off + 14)
	out["dir_x"] = _read_i16(raw, off + 16)
	out["dir_y"] = _read_i16(raw, off + 18)
	out["zones"] = []
	end = off + Protocol.SNAPSHOT_ENEMY_BYTES_V1
	return end


static func _clamp_stick(v: float) -> int:
	return clampi(roundi(v * 127.0), -127, 127)


static func _unpack_stick(b: int) -> float:
	var s := b if b < 128 else b - 256
	return float(s) / 127.0


static func _write_i16(buf: PackedByteArray, off: int, v: int) -> void:
	var u := v if v >= 0 else 65536 + v
	buf[off] = u & 0xFF
	buf[off + 1] = (u >> 8) & 0xFF


static func _read_i16(buf: PackedByteArray, off: int) -> int:
	var u := int(buf[off]) | (int(buf[off + 1]) << 8)
	return u if u < 32768 else u - 65536


static func _write_u16(buf: PackedByteArray, off: int, v: int) -> void:
	var u := clampi(v, 0, 65535)
	buf[off] = u & 0xFF
	buf[off + 1] = (u >> 8) & 0xFF


static func _read_u16(buf: PackedByteArray, off: int) -> int:
	return int(buf[off]) | (int(buf[off + 1]) << 8)
