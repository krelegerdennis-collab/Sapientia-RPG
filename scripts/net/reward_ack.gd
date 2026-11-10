class_name RewardAck
extends RefCounted
## REWARD_ACK (protocol v2). De host bewaart elke verstuurde bundle tot de ACK.
## De client telt een sleutel maar één keer en bevestigt ook een al toegepaste.
## Sleutel: 'g' + 15 hex, zodat hij in M1 applied_grants past (hoogstens 8, 16 tekens).
## Schrijft geen verhaal-save en geen online profiel.

const Codec := preload("res://scripts/net/net_codec.gd")
const Profile := preload("res://scripts/online/online_profile.gd")

## Zelfde plafond als OnlineProfile.MAX_GRANTS. De oudste valt daarna weg.
const MAX_PENDING := 8

## Injecteerbaar. Standaard leest applied_grants van het M1-profiel (alleen lezen).
var is_grant_applied: Callable = Callable()
var gained_exp: int = 0

var _pending: Dictionary = {}
var _seen: Dictionary = {}


func _init() -> void:
	is_grant_applied = Callable(RewardAck, "profile_has_grant")


## {ok, grant_key, body, dropped}. dropped is de sleutel die bij de 9e plaats maakte.
func offer(uid: String, bundle: Dictionary) -> Dictionary:
	var fail := {"ok": false, "grant_key": "", "body": {}, "dropped": ""}
	var clean := uid.strip_edges().to_lower()
	var key := _fresh_key(clean)
	if not Codec.valid_grant_key(key):
		return fail
	var unlocks: Variant = bundle.get("unlocks", [])
	if not (unlocks is Array):
		return fail
	var raw := Codec.encode_reward_bundle(
		clean,
		int(bundle.get("session_id", -1)),
		int(bundle.get("host_tick", -1)),
		int(bundle.get("profile_exp", -1)),
		unlocks,
		key,
	)
	if raw.is_empty():
		return fail
	var msg := Codec.decode_v2(raw)
	if not bool(msg.get("compatible", false)):
		return fail
	var parsed := Codec.read_reward_bundle(msg.get("body", {}))
	if not bool(parsed.get("ok", false)) or str(parsed.get("grant_key", "")) != key:
		return fail
	var body := {
		"uid": str(parsed.get("uid", "")),
		"session_id": int(parsed.get("session_id", 0)),
		"host_tick": int(parsed.get("host_tick", 0)),
		"profile_exp": int(parsed.get("profile_exp", 0)),
		"unlocks": (parsed.get("unlocks", []) as Array).duplicate(),
		"grant_key": key,
	}
	var dropped := _push(clean, body)
	return {"ok": true, "grant_key": key, "body": body, "dropped": dropped}


func ack(uid: String, grant_key: String) -> bool:
	var clean := uid.strip_edges().to_lower()
	if not Codec.valid_grant_key(grant_key):
		return false
	var found: Variant = _pending.get(clean, null)
	if not (found is Array):
		return false
	var rows: Array = found
	for i in rows.size():
		var row: Dictionary = rows[i]
		if str(row.get("grant_key", "")) == grant_key:
			rows.remove_at(i)
			return true
	return false


## Bundles die na een rejoin (zelfde uid) opnieuw de deur uit moeten. Wist niets.
func unacked(uid: String) -> Array:
	var clean := uid.strip_edges().to_lower()
	var found: Variant = _pending.get(clean, null)
	if not (found is Array):
		return []
	var out: Array = []
	for row in found:
		if row is Dictionary:
			out.append((row as Dictionary).duplicate(true))
	return out


## {ok, applied, extra, ack, grant_key}. extra is 0 als de sleutel al gold.
func receive(body: Dictionary) -> Dictionary:
	var fail := {
		"ok": false,
		"applied": false,
		"extra": 0,
		"ack": PackedByteArray(),
		"grant_key": "",
	}
	var parsed := Codec.read_reward_bundle(body)
	if not bool(parsed.get("ok", false)):
		return fail
	var key := str(parsed.get("grant_key", ""))
	if not Codec.valid_grant_key(key):
		return fail
	var already := _seen.has(key) or _hook(key)
	var extra := 0
	if not already:
		extra = int(parsed.get("profile_exp", 0))
		gained_exp += extra
		_seen[key] = true
	var ack_raw := Codec.encode_reward_ack(key)
	if ack_raw.is_empty():
		return fail
	return {
		"ok": true,
		"applied": not already,
		"extra": extra,
		"ack": ack_raw,
		"grant_key": key,
	}


## Alleen lezen. load_profile() herschrijft een kapot bestand; die kant slaan we over.
static func profile_has_grant(key: String) -> bool:
	if not Codec.valid_grant_key(key) or not FileAccess.file_exists(Profile.PATH):
		return false
	var raw := FileAccess.get_file_as_bytes(Profile.PATH)
	var oordeel: Dictionary = Profile._beoordeel_bytes(raw)
	if not bool(oordeel.get("ok", false)):
		return false
	var slots: Variant = oordeel.get("slots", [])
	if not (slots is Array):
		return false
	for slot in slots:
		if not (slot is Dictionary):
			continue
		var grants: Variant = (slot as Dictionary).get("applied_grants", [])
		if grants is Array and (grants as Array).has(key):
			return true
	return false


func _hook(key: String) -> bool:
	if not is_grant_applied.is_valid():
		return profile_has_grant(key)
	return bool(is_grant_applied.call(key))


func _push(uid: String, body: Dictionary) -> String:
	var rows := _rows(uid)
	var dropped := ""
	while rows.size() >= MAX_PENDING:
		var old: Dictionary = rows.pop_front()
		dropped = str(old.get("grant_key", ""))
		push_warning("RewardAck: oudste bundle voor %s valt weg (%s)" % [uid, dropped])
	rows.append(body)
	return dropped


func _rows(uid: String) -> Array:
	var found: Variant = _pending.get(uid, null)
	if found is Array:
		return found
	var fresh: Array = []
	_pending[uid] = fresh
	return fresh


func _fresh_key(uid: String) -> String:
	var used := {}
	var found: Variant = _pending.get(uid, null)
	if found is Array:
		for row in found:
			if row is Dictionary:
				used[str((row as Dictionary).get("grant_key", ""))] = true
	var crypto := Crypto.new()
	for _n in 6:
		var bytes := crypto.generate_random_bytes(8)
		if bytes.size() < 8:
			continue
		var key := "g" + bytes.hex_encode().to_lower().substr(0, 15)
		if Codec.valid_grant_key(key) and not used.has(key):
			return key
	return ""
