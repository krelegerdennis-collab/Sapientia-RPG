class_name TelegraphSnapshot
extends RefCounted
## Co-op telegraaf-velden in vijand-snapshots (Combat T5). Gast tekent alleen; host autoriteit.

const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")

## Vaste volgorde; index 0 in wire = geen telegraaf (IDLE).
const ATTACK_IDS: Array[String] = ["inktspuw", "inktplas"]

## Bytes per zone-record in snapshots (T4b).
const ZONE_WIRE_BYTES := 8


static func attack_index(attack_id: String) -> int:
	var i := ATTACK_IDS.find(attack_id)
	return i + 1 if i >= 0 else 0


static func attack_id_from_index(idx: int) -> String:
	if idx <= 0 or idx > ATTACK_IDS.size():
		return ""
	return ATTACK_IDS[idx - 1]


static func telegraph_fields_from_attack(tg: TelegraphAttack, target_slot: int) -> Dictionary:
	var out := {
		"target_slot": clampi(target_slot, 0, Protocol.MAX_PLAYERS - 1),
		"atk_id": 0,
		"phase": TelegraphState.State.IDLE,
		"t": 0,
		"ox": 0,
		"oy": 0,
		"dir_x": 0,
		"dir_y": 0,
	}
	if tg == null or not tg.is_busy():
		return out
	out["atk_id"] = attack_index(tg.attack_id())
	out["phase"] = tg.state()
	out["t"] = tg.ticks_left_in_phase()
	var o: Vector2i = tg.locked_origin()
	out["ox"] = o.x
	out["oy"] = o.y
	var d: Vector2i = tg.locked_dir()
	out["dir_x"] = d.x
	out["dir_y"] = d.y
	return out


static func merge_enemy_row(base: Dictionary, tg: TelegraphAttack, target_slot: int) -> Dictionary:
	var row: Dictionary = base.duplicate(true)
	var tg_row := telegraph_fields_from_attack(tg, target_slot)
	for k in tg_row.keys():
		row[k] = tg_row[k]
	return row


static func attach_zones(snap_row: Dictionary, zones: Array) -> Dictionary:
	var row: Dictionary = snap_row.duplicate(true)
	row["zones"] = zones
	return row


static func apply_row_to_enemy(e: Dictionary, row: Dictionary, room_id: String, tier: int) -> void:
	if not e.has("tg"):
		return
	var tg: TelegraphAttack = e["tg"]
	var idx := int(row.get("atk_id", 0))
	if idx <= 0:
		tg.mirror_idle()
		return
	var aid := attack_id_from_index(idx)
	if aid == "":
		tg.mirror_idle()
		return
	var def: Dictionary = SomActionAttacks.attack(aid)
	tg.mirror_from_network(
		def,
		SomActionAttacks.cooldown_ms(room_id, tier),
		int(row.get("phase", TelegraphState.State.IDLE)),
		int(row.get("t", 0)),
		Vector2i(int(row.get("ox", 0)), int(row.get("oy", 0))),
		Vector2i(int(row.get("dir_x", 0)), int(row.get("dir_y", 0))),
		str(def.get("shape", "line")),
	)


static func player_pixel_map(snap: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for prow in snap.get("players", []):
		var slot := int(prow.get("slot", Protocol.NO_SLOT))
		if slot < 0:
			continue
		out[slot] = Vector2i(int(prow.get("x", 0)), int(prow.get("y", 0)))
	return out


## Event alleen op de overgang naar ACTIVE (zelfde moment als `entered_active_this_tick` op de host).
static func active_edge_event(
	tick: int,
	enemy_idx: int,
	row: Dictionary,
	prev_row: Dictionary,
	players_px: Dictionary,
) -> Dictionary:
	var phase := int(row.get("phase", TelegraphState.State.IDLE))
	var prev_phase := int(prev_row.get("phase", TelegraphState.State.IDLE))
	if phase != TelegraphState.State.ACTIVE or prev_phase == TelegraphState.State.ACTIVE:
		return {}
	var idx := int(row.get("atk_id", 0))
	var aid := attack_id_from_index(idx)
	if aid == "":
		return {}
	var def: Dictionary = SomActionAttacks.attack(aid)
	var tg := TelegraphAttack.new()
	tg.mirror_from_network(
		def,
		0,
		phase,
		int(row.get("t", 0)),
		Vector2i(int(row.get("ox", 0)), int(row.get("oy", 0))),
		Vector2i(int(row.get("dir_x", 0)), int(row.get("dir_y", 0))),
		str(def.get("shape", "line")),
	)
	var slot := int(row.get("target_slot", Protocol.HOST_SLOT))
	var target_px: Vector2i = players_px.get(slot, Vector2i.ZERO)
	var hit := tg.hits_point_i(target_px)
	return {
		"tick": tick,
		"enemy_idx": enemy_idx,
		"atk_id": aid,
		"phase": phase,
		"hit": hit,
		"target_slot": slot,
	}


static func host_active_event(
	tick: int,
	enemy_idx: int,
	tg: TelegraphAttack,
	target_slot: int,
	target_px: Vector2i,
) -> Dictionary:
	if tg == null or not tg.entered_active_this_tick():
		return {}
	return {
		"tick": tick,
		"enemy_idx": enemy_idx,
		"atk_id": tg.attack_id(),
		"phase": tg.state(),
		"hit": tg.hits_point_i(target_px),
		"target_slot": target_slot,
	}


static func event_key(ev: Dictionary) -> String:
	return "%d|%d|%s|%d|%s|%d" % [
		int(ev.get("tick", -1)),
		int(ev.get("enemy_idx", -1)),
		str(ev.get("atk_id", "")),
		int(ev.get("phase", -1)),
		"HIT" if bool(ev.get("hit", false)) else "MISS",
		int(ev.get("target_slot", -1)),
	]
