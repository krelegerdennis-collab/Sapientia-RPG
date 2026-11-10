class_name NetCodec
extends RefCounted
## Binair inpakken voor Action-co-op (docs/fase_b/ARCHITECTUUR.md, net_protocol.gd).
## Protocol v2 (online): JSON-kinds naast de binaire INPUT/SNAPSHOT. LAN blijft v1.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const AvatarBlob := preload("res://scripts/net/avatar_blob.gd")
const EmoteTable := preload("res://scripts/net/emote_table.gd")

## Zelfde nummers als NetProtocol.Kind. Hier zodat encode/decode van v2 op één plek staat.
const KIND_READY := 9
const KIND_SIM_SELECT := 10
const KIND_RUN_RESULT := 11
const KIND_REWARD_BUNDLE := 12
const KIND_HOST_PAUSED := 13
const KIND_EMOTE := 14
const KIND_VOTE := 15
const KIND_REWARD_ACK := 16
## 'g' + 15 hex. Past in M1 applied_grants (max 16 tekens).
const GRANT_KEY_LEN := 16

const SIM_ID := "dls"
const MODES: Array[String] = ["easy", "normal", "hard"]
const VOTE_CHOICE_MAX := 7
const UNLOCK_MAX := 8
const UNLOCK_TOKEN_MAX := 16
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")
const ZONE_WIRE_BYTES := TelegraphSnapshot.ZONE_WIRE_BYTES
const ROOT_WIRE_BYTES := TelegraphSnapshot.ROOT_WIRE_BYTES
const MAX_ZONES_WIRE := 6
const MAX_ROOTS_WIRE := 4
const INPUT_SIZE := Protocol.INPUT_BYTES
const PLAYER_SIZE := Protocol.SNAPSHOT_PLAYER_BYTES
const ENEMY_SIZE := Protocol.SNAPSHOT_ENEMY_BYTES_V1
const HEADER_SIZE := Protocol.SNAPSHOT_HEADER_BYTES
const CODEC_VERSION := Protocol.SNAPSHOT_CODEC_VERSION

const BTN_ATTACK := 1
const BTN_RING := 2
const BTN_LOCK_TAP := 4
const BTN_DODGE := 8
## Aanvalsknop wordt vastgehouden (zware slag opladen, SomHeavyData).
const BTN_ATTACK_HELD := 16


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


static func pack_snapshot(tick: int, players: Array, enemies: Array, zones: Array = [], roots: Array = []) -> PackedByteArray:
	return _pack_snapshot_version(tick, players, enemies, CODEC_VERSION, zones, roots)


static func pack_snapshot_v0(tick: int, players: Array, enemies: Array) -> PackedByteArray:
	return _pack_snapshot_version(tick, players, enemies, 0, [], [])


static func _pack_snapshot_version(tick: int, players: Array, enemies: Array, codec_version: int, zones: Array, roots: Array) -> PackedByteArray:
	var buf := PackedByteArray()
	var pc := mini(players.size(), Protocol.MAX_PLAYERS)
	var ec := mini(enemies.size(), Protocol.SNAPSHOT_ENEMY_BUDGET)
	var enemy_sz := _enemy_wire_bytes(codec_version)
	var zc := mini(zones.size(), MAX_ZONES_WIRE) if codec_version > 0 else 0
	var rc := mini(roots.size(), MAX_ROOTS_WIRE) if codec_version > 0 else 0
	var zone_tail := (1 + zc * ZONE_WIRE_BYTES) if codec_version > 0 else 0
	var root_tail := (1 + rc * ROOT_WIRE_BYTES) if codec_version > 0 else 0
	buf.resize(HEADER_SIZE + pc * PLAYER_SIZE + ec * enemy_sz + zone_tail + root_tail)
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
	if codec_version > 0:
		buf[off] = zc
		off += 1
		for i in zc:
			off = _pack_zone(buf, off, zones[i])
		buf[off] = rc
		off += 1
		for i in rc:
			off = _pack_root(buf, off, roots[i])
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
	var zones: Array = []
	var roots: Array = []
	if codec_version > 0 and raw.size() > off:
		var zc := int(raw[off])
		off += 1
		for i in mini(zc, MAX_ZONES_WIRE):
			if raw.size() < off + ZONE_WIRE_BYTES:
				break
			var zrow: Dictionary = {}
			off = _unpack_zone(raw, off, zrow)
			zones.append(zrow)
	if codec_version > 0 and raw.size() > off:
		var rc := int(raw[off])
		off += 1
		for i in mini(rc, MAX_ROOTS_WIRE):
			if raw.size() < off + ROOT_WIRE_BYTES:
				break
			var rrow: Dictionary = {}
			off = _unpack_root(raw, off, rrow)
			roots.append(rrow)
	return {"tick": tick, "codec_version": codec_version, "players": players, "enemies": enemies, "zones": zones, "roots": roots}


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


static func _pack_zone(buf: PackedByteArray, off: int, z: Dictionary) -> int:
	buf[off] = clampi(int(z.get("owner_idx", 0)), 0, 255)
	_write_i16(buf, off + 1, int(z.get("ox", 0)))
	_write_i16(buf, off + 3, int(z.get("oy", 0)))
	buf[off + 5] = clampi(int(z.get("r", 0)), 0, 255)
	buf[off + 6] = clampi(int(z.get("ticks_left", 0)), 0, 255)
	buf[off + 7] = clampi(int(z.get("shape", 1)), 0, 255)
	return off + ZONE_WIRE_BYTES


static func _unpack_zone(raw: PackedByteArray, off: int, out: Dictionary) -> int:
	out["owner_idx"] = int(raw[off])
	out["ox"] = _read_i16(raw, off + 1)
	out["oy"] = _read_i16(raw, off + 3)
	out["r"] = int(raw[off + 5])
	out["ticks_left"] = int(raw[off + 6])
	out["shape"] = int(raw[off + 7])
	return off + ZONE_WIRE_BYTES


static func _pack_root(buf: PackedByteArray, off: int, r: Dictionary) -> int:
	buf[off] = clampi(int(r.get("slot", 0)), 0, Protocol.MAX_PLAYERS - 1)
	buf[off + 1] = clampi(int(r.get("root_ticks", 0)), 0, 255)
	buf[off + 2] = clampi(int(r.get("immune_ticks", 0)), 0, 255)
	return off + ROOT_WIRE_BYTES


static func _unpack_root(raw: PackedByteArray, off: int, out: Dictionary) -> int:
	out["slot"] = int(raw[off])
	out["root_ticks"] = int(raw[off + 1])
	out["immune_ticks"] = int(raw[off + 2])
	return off + ROOT_WIRE_BYTES


# --- protocol v2 (online). LAN-decode in NetProtocol blijft versie 1. -----------------

static func encode_v2(kind: int, body: Dictionary) -> PackedByteArray:
	if kind < Protocol.Kind.HELLO or kind > Protocol.Kind.REWARD_ACK:
		return PackedByteArray()
	var raw := Protocol.encode(kind, body, Protocol.VERSION_ONLINE)
	if raw.is_empty() or raw.size() >= Protocol.MAX_ONLINE_PACKET_BYTES:
		return PackedByteArray()
	return raw


## Zelfde vorm als NetProtocol.decode. Alleen VERSION_ONLINE is compatible.
## Versie 1 (oude build) is leesbaar met reason VERSION, zodat de host REFUSE kan sturen.
static func decode_v2(raw: PackedByteArray) -> Dictionary:
	var fail := {
		"ok": false,
		"compatible": false,
		"version": 0,
		"kind": 0,
		"body": {},
		"reason": Protocol.Refuse.BAD_PACKET,
	}
	if raw.is_empty() or raw.size() >= Protocol.MAX_ONLINE_PACKET_BYTES:
		return fail
	var text := raw.get_string_from_utf8()
	if not text.begins_with("{"):
		return fail
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return fail
	var data: Dictionary = parsed
	if str(data.get("game", "")) != Protocol.GAME_ID:
		return fail
	var version := int(data.get("v", 0))
	var kind := int(data.get("kind", 0))
	var body_v: Variant = data.get("body", {})
	var body: Dictionary = body_v if body_v is Dictionary else {}
	if version != Protocol.VERSION_ONLINE:
		return {
			"ok": true,
			"compatible": false,
			"version": version,
			"kind": kind,
			"body": body,
			"reason": Protocol.Refuse.VERSION,
		}
	if kind < Protocol.Kind.HELLO or kind > Protocol.Kind.REWARD_ACK or not (body_v is Dictionary):
		return fail
	return {
		"ok": true,
		"compatible": true,
		"version": version,
		"kind": kind,
		"body": body,
		"reason": Protocol.Refuse.NONE,
	}


static func look_to_wire(look: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(look)


static func look_from_wire(text: String) -> PackedByteArray:
	return Marshalls.base64_to_raw(text.strip_edges())


static func clean_online_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var ch := raw.substr(i, 1)
		if ch.unicode_at(0) < 32:
			continue
		out += ch
		if out.length() >= Protocol.ONLINE_NAME_MAX:
			break
	return out.strip_edges()


## Profiel of HELLO-body. look mag een dictionary, een blob of base64 zijn.
## {ok, uid, name, class_id, look}.
static func normalize_profile(profile: Dictionary) -> Dictionary:
	var uid := str(profile.get("uid", "")).strip_edges().to_lower()
	var name := clean_online_name(str(profile.get("name", "")))
	var class_id := str(profile.get("class", ""))
	var look := _coerce_look(profile.get("look", PackedByteArray()), class_id)
	var decoded := AvatarBlob.decode(look)
	if not _valid_uid(uid) or name == "" or not AvatarBlob.known_class(class_id):
		return {"ok": false}
	if not bool(decoded.get("ok", false)) or str(decoded.get("class_id", "")) != class_id:
		return {"ok": false}
	return {
		"ok": true,
		"uid": uid,
		"name": name,
		"class_id": class_id,
		"look": look,
	}


static func hello_body(norm: Dictionary) -> Dictionary:
	var look: PackedByteArray = norm.get("look", PackedByteArray())
	return {
		"uid": str(norm.get("uid", "")),
		"name": str(norm.get("name", "")),
		"class": str(norm.get("class_id", "")),
		"look": look_to_wire(look),
	}


static func read_hello_v2(body: Dictionary) -> Dictionary:
	return normalize_profile(body)


static func roster_body_from_slots(slots: Array) -> Dictionary:
	var roster: Array = []
	for row in slots:
		if not (row is Dictionary):
			continue
		var d: Dictionary = row
		var look: PackedByteArray = d.get("look", PackedByteArray())
		roster.append({
			"seat": int(d.get("seat", d.get("slot", -1))),
			"uid": str(d.get("uid", "")),
			"name": str(d.get("name", "")),
			"class": str(d.get("class", "")),
			"controller": str(d.get("wire_controller", d.get("controller", ""))),
			"look": look_to_wire(look),
		})
	return {"roster": roster}


## {ok, seats: [{seat, uid, name, class_id, controller, look}]}.
static func read_roster_v2(body: Dictionary) -> Dictionary:
	var raw_v: Variant = body.get("roster", null)
	if not (raw_v is Array):
		return {"ok": false, "seats": []}
	var raw: Array = raw_v
	if raw.size() > Protocol.MAX_PLAYERS:
		return {"ok": false, "seats": []}
	var seats: Array = []
	var seen_seat := {}
	var seen_uid := {}
	for item in raw:
		if not (item is Dictionary):
			return {"ok": false, "seats": []}
		var row: Dictionary = item
		if not _is_number(row.get("seat", null)):
			return {"ok": false, "seats": []}
		var seat := int(row.get("seat", -1))
		if not _seat_ok(seat) or seen_seat.has(seat):
			return {"ok": false, "seats": []}
		var ctrl := str(row.get("controller", ""))
		if ctrl != Protocol.CTRL_LOCAL and ctrl != Protocol.CTRL_REMOTE and ctrl != Protocol.CTRL_AI:
			return {"ok": false, "seats": []}
		var norm := normalize_profile(row)
		if not bool(norm.get("ok", false)):
			return {"ok": false, "seats": []}
		var uid := str(norm.get("uid", ""))
		if seen_uid.has(uid):
			return {"ok": false, "seats": []}
		seen_seat[seat] = true
		seen_uid[uid] = true
		seats.append({
			"seat": seat,
			"uid": uid,
			"name": str(norm.get("name", "")),
			"class_id": str(norm.get("class_id", "")),
			"controller": ctrl,
			"look": norm.get("look", PackedByteArray()),
		})
	return {"ok": true, "seats": seats}


## Gast ziet de eigen stoel als local; ai blijft ai; de rest is remote.
static func view_controller(wire: String, seat: int, local_seat: int) -> String:
	if wire == Protocol.CTRL_AI:
		return Protocol.CTRL_AI
	if local_seat != Protocol.NO_SLOT and seat == local_seat:
		return Protocol.CTRL_LOCAL
	return Protocol.CTRL_REMOTE


static func encode_ready(seat: int, ready: bool) -> PackedByteArray:
	if not _seat_ok(seat):
		return PackedByteArray()
	return encode_v2(KIND_READY, {"seat": seat, "ready": ready})


static func read_ready(body: Dictionary) -> Dictionary:
	if not _seat_field(body) or not (body.get("ready", null) is bool):
		return {"ok": false}
	return {"ok": true, "seat": int(body["seat"]), "ready": bool(body["ready"])}


static func encode_sim_select(sim: String, mode: String) -> PackedByteArray:
	if sim != SIM_ID or not MODES.has(mode):
		return PackedByteArray()
	return encode_v2(KIND_SIM_SELECT, {"sim": sim, "mode": mode})


static func read_sim_select(body: Dictionary) -> Dictionary:
	var sim := str(body.get("sim", ""))
	var mode := str(body.get("mode", ""))
	if sim != SIM_ID or not MODES.has(mode):
		return {"ok": false}
	return {"ok": true, "sim": sim, "mode": mode}


static func encode_run_result(floors: int, kills: int, revives: int, mode: String) -> PackedByteArray:
	if floors < 0 or kills < 0 or revives < 0 or not MODES.has(mode):
		return PackedByteArray()
	return encode_v2(KIND_RUN_RESULT, {
		"floors": floors,
		"kills": kills,
		"revives": revives,
		"mode": mode,
	})


static func read_run_result(body: Dictionary) -> Dictionary:
	if not MODES.has(str(body.get("mode", ""))):
		return {"ok": false}
	if not _nonneg(body, "floors") or not _nonneg(body, "kills") or not _nonneg(body, "revives"):
		return {"ok": false}
	return {
		"ok": true,
		"floors": int(body["floors"]),
		"kills": int(body["kills"]),
		"revives": int(body["revives"]),
		"mode": str(body["mode"]),
	}


static func encode_reward_bundle(uid: String, session_id: int, host_tick: int, profile_exp: int, unlocks: Array, grant_key: String = "") -> PackedByteArray:
	if not _valid_uid(uid.to_lower()) or session_id < 0 or host_tick < 0 or profile_exp < 0:
		return PackedByteArray()
	if unlocks.size() > UNLOCK_MAX:
		return PackedByteArray()
	if grant_key != "" and not valid_grant_key(grant_key):
		return PackedByteArray()
	var clean: Array = []
	for item in unlocks:
		var token := str(item)
		if not _token(token):
			return PackedByteArray()
		clean.append(token)
	var body := {
		"uid": uid.to_lower(),
		"session_id": session_id,
		"host_tick": host_tick,
		"profile_exp": profile_exp,
		"unlocks": clean,
	}
	if grant_key != "":
		body["grant_key"] = grant_key
	return encode_v2(KIND_REWARD_BUNDLE, body)


static func read_reward_bundle(body: Dictionary) -> Dictionary:
	var uid := str(body.get("uid", "")).to_lower()
	if not _valid_uid(uid):
		return {"ok": false}
	if not _nonneg(body, "session_id") or not _nonneg(body, "host_tick") or not _nonneg(body, "profile_exp"):
		return {"ok": false}
	var unlocks_v: Variant = body.get("unlocks", null)
	if not (unlocks_v is Array):
		return {"ok": false}
	var unlocks: Array = unlocks_v
	if unlocks.size() > UNLOCK_MAX:
		return {"ok": false}
	var clean: Array[String] = []
	for item in unlocks:
		if not (item is String) or not _token(str(item)):
			return {"ok": false}
		clean.append(str(item))
	var grant_key := ""
	if body.has("grant_key"):
		grant_key = str(body.get("grant_key", ""))
		if not valid_grant_key(grant_key):
			return {"ok": false}
	return {
		"ok": true,
		"uid": uid,
		"session_id": int(body["session_id"]),
		"host_tick": int(body["host_tick"]),
		"profile_exp": int(body["profile_exp"]),
		"unlocks": clean,
		"grant_key": grant_key,
	}


static func valid_grant_key(key: String) -> bool:
	if key.length() != GRANT_KEY_LEN or not key.begins_with("g"):
		return false
	for i in range(1, GRANT_KEY_LEN):
		var c := key.unicode_at(i)
		var hex := (c >= 48 and c <= 57) or (c >= 97 and c <= 102)
		if not hex:
			return false
	return true


static func encode_reward_ack(grant_key: String) -> PackedByteArray:
	if not valid_grant_key(grant_key):
		return PackedByteArray()
	return encode_v2(KIND_REWARD_ACK, {"grant_key": grant_key})


static func read_reward_ack(body: Dictionary) -> Dictionary:
	var key := str(body.get("grant_key", ""))
	if not valid_grant_key(key):
		return {"ok": false}
	return {"ok": true, "grant_key": key}


static func encode_host_paused(paused: bool) -> PackedByteArray:
	return encode_v2(KIND_HOST_PAUSED, {"paused": paused})


static func read_host_paused(body: Dictionary) -> Dictionary:
	if not (body.get("paused", null) is bool):
		return {"ok": false}
	return {"ok": true, "paused": bool(body["paused"])}


static func emote_body(seat: int, emote_id: int) -> Dictionary:
	return {"seat": seat, "emote_id": emote_id}


static func encode_emote(seat: int, emote_id: int) -> PackedByteArray:
	if not _seat_ok(seat) or not EmoteTable.valid_id(emote_id):
		return PackedByteArray()
	return encode_v2(KIND_EMOTE, emote_body(seat, emote_id))


static func read_emote(body: Dictionary) -> Dictionary:
	if not _seat_field(body) or not _is_number(body.get("emote_id", null)):
		return {"ok": false}
	var emote_id := int(body.get("emote_id", -1))
	if not EmoteTable.valid_id(emote_id):
		return {"ok": false}
	return {"ok": true, "seat": int(body["seat"]), "emote_id": emote_id}


static func encode_vote(seat: int, choice: int) -> PackedByteArray:
	if not _seat_ok(seat) or choice < 0 or choice > VOTE_CHOICE_MAX:
		return PackedByteArray()
	return encode_v2(KIND_VOTE, {"seat": seat, "choice": choice})


static func read_vote(body: Dictionary) -> Dictionary:
	if not _seat_field(body) or not _is_number(body.get("choice", null)):
		return {"ok": false}
	var choice := int(body.get("choice", -1))
	if choice < 0 or choice > VOTE_CHOICE_MAX:
		return {"ok": false}
	return {"ok": true, "seat": int(body["seat"]), "choice": choice}


static func _coerce_look(v: Variant, class_id: String) -> PackedByteArray:
	if v is PackedByteArray:
		return v
	if v is String:
		return look_from_wire(str(v))
	if v is Dictionary:
		var d: Dictionary = (v as Dictionary).duplicate()
		if str(d.get("class", "")) == "":
			d["class"] = class_id
		return AvatarBlob.encode(d)
	return PackedByteArray()


static func _valid_uid(uid: String) -> bool:
	if uid.length() != Protocol.UID_HEX_LEN:
		return false
	for i in uid.length():
		var c := uid.unicode_at(i)
		var hex := (c >= 48 and c <= 57) or (c >= 97 and c <= 102)
		if not hex:
			return false
	return true


static func _token(text: String) -> bool:
	if text == "" or text.length() > UNLOCK_TOKEN_MAX:
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 97 and c <= 122) or c == 95
		if not ok:
			return false
	return true


static func _seat_ok(seat: int) -> bool:
	return seat >= 0 and seat < Protocol.MAX_PLAYERS


static func _seat_field(body: Dictionary) -> bool:
	return _is_number(body.get("seat", null)) and _seat_ok(int(body.get("seat", -1)))


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _nonneg(body: Dictionary, key: String) -> bool:
	var v: Variant = body.get(key, null)
	if not _is_number(v):
		return false
	var n := int(v)
	return n >= 0 and float(v) == float(n)

