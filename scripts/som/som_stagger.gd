class_name SomStagger
extends RefCounted
## Host-tick logica voor F2 stagger-meter (pure functies, testbaar zonder nodes).

const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")

const WIRE_STATE_NORMAL := 0
const WIRE_STATE_WANKEL := 1
const WIRE_STATE_IMMUNE := 2
const WIRE_FRAC_MAX := 63


static func init_entry(e: Dictionary) -> void:
	e["stg"] = 0
	e["stg_idle"] = 0
	e["stg_wankel"] = 0
	e["stg_immune"] = 0


static func apply_hit(e: Dictionary, m: Node, data: Dictionary, kind: int) -> bool:
	## Geeft true als vijand net wankel is ingegaan (telegraaf onderbreken).
	if e.get("golem", null) != null:
		return false
	if kind == SomStaggerData.KIND_NONE:
		return false
	if SomStaggerData.in_wankel(e) or SomStaggerData.immune(e):
		return false
	var add := SomStaggerData.fill_for_kind(kind)
	if add <= 0:
		return false
	e["stg_idle"] = 0
	var max_v := SomStaggerData.max_meter(data, m)
	var before := int(e.get("stg", 0))
	e["stg"] = mini(max_v, before + add)
	return before < max_v and int(e["stg"]) >= max_v


static func enter_wankel(e: Dictionary) -> void:
	e["stg_wankel"] = SomStaggerData.WANKEL_TICKS
	e["stg"] = mini(int(e.get("stg", 0)), SomStaggerData.MAX_BOSS_UNIQUE)


static func tick_entry(e: Dictionary, has_golem: bool) -> void:
	if has_golem:
		return
	var w := int(e.get("stg_wankel", 0))
	if w > 0:
		e["stg_wankel"] = w - 1
		if int(e["stg_wankel"]) <= 0:
			e["stg"] = 0
			e["stg_immune"] = SomStaggerData.IMMUNE_TICKS
			e["stg_idle"] = 0
		return
	var imm := int(e.get("stg_immune", 0))
	if imm > 0:
		e["stg_immune"] = imm - 1
		return
	e["stg_idle"] = int(e.get("stg_idle", 0)) + 1
	var idle := int(e["stg_idle"])
	if idle <= SomStaggerData.DECAY_GRACE_TICKS:
		return
	if (idle - SomStaggerData.DECAY_GRACE_TICKS) % SomStaggerData.DECAY_EVERY_TICKS != 0:
		return
	if int(e.get("stg", 0)) > 0:
		e["stg"] = int(e["stg"]) - 1


static func damage_multiplier(e: Dictionary) -> float:
	if SomStaggerData.in_wankel(e):
		return SomStaggerData.WANKEL_DAMAGE_MULT
	return 1.0


static func _wire_frac(stg: int, max_v: int) -> int:
	if max_v <= 0:
		return 0
	return clampi(roundi(float(stg) / float(max_v) * float(WIRE_FRAC_MAX)), 0, WIRE_FRAC_MAX)


static func _stg_from_frac(frac: int, max_v: int) -> int:
	if max_v <= 0:
		return 0
	return clampi(roundi(float(frac) / float(WIRE_FRAC_MAX) * float(max_v)), 0, max_v)


static func encode_wire_byte(e: Dictionary, data: Dictionary, m: Node) -> int:
	var max_v := SomStaggerData.max_meter(data, m)
	var state := WIRE_STATE_NORMAL
	if int(e.get("stg_wankel", 0)) > 0:
		state = WIRE_STATE_WANKEL
	elif int(e.get("stg_immune", 0)) > 0:
		state = WIRE_STATE_IMMUNE
	var frac := _wire_frac(int(e.get("stg", 0)), max_v)
	return (state << 6) | (frac & WIRE_FRAC_MAX)


static func decode_wire_byte(e: Dictionary, wire_byte: int, data: Dictionary, m: Node) -> void:
	var max_v := SomStaggerData.max_meter(data, m)
	var state := (wire_byte >> 6) & 0x3
	var frac := wire_byte & WIRE_FRAC_MAX
	e["stg"] = _stg_from_frac(frac, max_v)
	match state:
		WIRE_STATE_WANKEL:
			e["stg_wankel"] = 1
			e["stg_immune"] = 0
		WIRE_STATE_IMMUNE:
			e["stg_wankel"] = 0
			e["stg_immune"] = 1
		_:
			e["stg_wankel"] = 0
			e["stg_immune"] = 0


static func wire_fields(e: Dictionary, data: Dictionary, m: Node) -> Dictionary:
	return {"stg": encode_wire_byte(e, data, m)}


static func apply_wire(e: Dictionary, row: Dictionary, m: Node = null) -> void:
	if not row.has("stg"):
		return
	var data: Dictionary = e.get("data", {})
	decode_wire_byte(e, int(row.get("stg", 0)), data, m)