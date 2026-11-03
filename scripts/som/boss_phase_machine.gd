extends RefCounted
class_name BossPhaseMachine
## Pure fase-logica @ 60 Hz (D3). Geen nodes; host-only in co-op (COMBAT_DESIGN §12/§16).

const INVULN_TICKS := 90  ## 1.5 s @ 60 Hz

signal phase_changed(from_index: int, to_index: int)

var _phases: Array = []
var _phase_index := 0
var _hp := 0
var _max_hp := 1
var _invuln_ticks := 0
var _tick := 0
var _rng: RandomNumberGenerator
var _event_log: Array = []
var _scratch_event: Dictionary = {}


func _init(script: Dictionary, max_hp: int, seed: int = 0) -> void:
	_phases = script.get("phases", [])
	_max_hp = maxi(1, max_hp)
	_hp = _max_hp
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed
	_log("start", {"phase": 0, "hp": _hp})
	_apply_on_enter(0)


func tick() -> void:
	_tick += 1
	if _invuln_ticks > 0:
		_invuln_ticks -= 1
		if _invuln_ticks == 0:
			_log("invuln_end", {})


func is_invulnerable() -> bool:
	return _invuln_ticks > 0


func phase_index() -> int:
	return _phase_index


func current_hp() -> int:
	return _hp


func max_hp() -> int:
	return _max_hp


func sim_tick() -> int:
	return _tick


## Schade buiten fase-invuln; hoogstens één fasewissel per aanroep (overkill).
func on_damage(amount: int) -> int:
	if amount <= 0 or is_invulnerable():
		return 0
	var before := _hp
	_hp = maxi(0, _hp - amount)
	var dealt := before - _hp
	if dealt <= 0:
		return 0
	_log("damage", {"amount": dealt, "hp": _hp})
	_try_advance_phase()
	return dealt


func threshold_hp(phase_idx: int) -> int:
	if phase_idx < 0 or phase_idx >= _phases.size():
		return 0
	var until := float(_phases[phase_idx].get("hp_until", 0.0))
	return clampi(roundi(float(_max_hp) * until), 0, _max_hp)


func event_log() -> Array:
	return _event_log


## Gewogen aanval-id uit de huidige fase (deterministisch via seed).
func pick_attack() -> String:
	if _phase_index < 0 or _phase_index >= _phases.size():
		return ""
	var attacks: Array = _phases[_phase_index].get("attacks", [])
	if attacks.is_empty():
		return ""
	var total := 0.0
	for a in attacks:
		if a is Dictionary:
			total += float(a.get("weight", 1.0))
	if total <= 0.0:
		return str((attacks[0] as Dictionary).get("id", ""))
	var roll := _rng.randf() * total
	for a in attacks:
		if a is Dictionary:
			roll -= float(a.get("weight", 1.0))
			if roll <= 0.0:
				return str(a.get("id", ""))
	return str((attacks[0] as Dictionary).get("id", ""))


func _try_advance_phase() -> void:
	if _phase_index >= _phases.size() - 1:
		return
	var limit := threshold_hp(_phase_index)
	if _hp > limit:
		return
	var old := _phase_index
	_phase_index += 1
	_invuln_ticks = INVULN_TICKS
	_log("phase_transition", {"from": old, "to": _phase_index})
	_log("invuln_start", {"ticks": INVULN_TICKS})
	phase_changed.emit(old, _phase_index)
	_apply_on_enter(_phase_index)


func _apply_on_enter(idx: int) -> void:
	if idx < 0 or idx >= _phases.size():
		return
	var p: Dictionary = _phases[idx]
	var enter_id := str(p.get("on_enter", ""))
	if enter_id != "":
		_log("on_enter", {"phase": idx, "id": enter_id})
	var adds: Variant = p.get("adds", [])
	if adds is Array and not adds.is_empty():
		_log("spawns_adds", {"phase": idx, "adds": adds})


func _log(kind: String, fields: Dictionary) -> void:
	_scratch_event.clear()
	_scratch_event["type"] = kind
	_scratch_event["tick"] = _tick
	for k in fields:
		_scratch_event[k] = fields[k]
	_event_log.append(_scratch_event.duplicate())
