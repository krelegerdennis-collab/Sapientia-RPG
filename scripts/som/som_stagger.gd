class_name SomStagger
extends RefCounted
## Host-tick logica voor F2 stagger-meter (pure functies, testbaar zonder nodes).

const SomStaggerData := preload("res://scripts/data/som_stagger_data.gd")


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


static func wire_fields(e: Dictionary) -> Dictionary:
	return {
		"stg": clampi(int(e.get("stg", 0)), 0, 255),
		"stg_wankel": clampi(int(e.get("stg_wankel", 0)), 0, 255),
		"stg_immune": clampi(int(e.get("stg_immune", 0)), 0, 255),
	}


static func apply_wire(e: Dictionary, row: Dictionary) -> void:
	if row.has("stg"):
		e["stg"] = int(row.get("stg", 0))
	if row.has("stg_wankel"):
		e["stg_wankel"] = int(row.get("stg_wankel", 0))
	if row.has("stg_immune"):
		e["stg_immune"] = int(row.get("stg_immune", 0))