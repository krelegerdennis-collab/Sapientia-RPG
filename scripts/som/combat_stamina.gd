class_name CombatStamina
extends RefCounted
## Stamina voor actieve dodge en sprint (Combat D5). Host-tick op 60 Hz; co-op spiegelt via snapshot mp-byte.

const SomData := preload("res://scripts/data/som_data.gd")

var _stamina: Dictionary = {}
var _regen_delay: Dictionary = {}
var _regen_phase: Dictionary = {}
var _sprint_phase: Dictionary = {}


func clear_all() -> void:
	_stamina.clear()
	_regen_delay.clear()
	_regen_phase.clear()
	_sprint_phase.clear()


func clear_member(id: String) -> void:
	if id == "":
		return
	_stamina.erase(id)
	_regen_delay.erase(id)
	_regen_phase.erase(id)
	_sprint_phase.erase(id)


func init_member(id: String, amount := -1) -> void:
	if id == "":
		return
	var maxv := SomData.STAMINA_MAX if amount < 0 else amount
	_stamina[id] = clampi(maxv, 0, SomData.STAMINA_MAX)
	_regen_delay[id] = 0
	_regen_phase[id] = 0
	_sprint_phase[id] = 0


func current(id: String) -> int:
	return int(_stamina.get(id, 0))


func can_pay(id: String, cost: int) -> bool:
	return current(id) >= cost


func can_sprint(id: String) -> bool:
	return current(id) > 0


func spend(id: String, cost: int) -> bool:
	if not can_pay(id, cost):
		return false
	_stamina[id] = current(id) - cost
	_regen_delay[id] = SomData.STAMINA_REGEN_DELAY_TICKS
	_regen_phase[id] = 0
	return true


## Eén sim-tick: regen na delay; return true als er sprint-kosten zijn betaald.
func tick_member(id: String, sprinting: bool) -> void:
	if id == "" or not _stamina.has(id):
		return
	if sprinting and current(id) > 0:
		var sp := int(_sprint_phase.get(id, 0)) + 1
		if sp >= SomData.STAMINA_SPRINT_EVERY_TICKS:
			sp = 0
			spend(id, SomData.STAMINA_SPRINT_COST)
		_sprint_phase[id] = sp
	else:
		_sprint_phase[id] = 0
	var delay := int(_regen_delay.get(id, 0))
	if delay > 0:
		_regen_delay[id] = delay - 1
		return
	var ph := int(_regen_phase.get(id, 0)) + 1
	if ph >= SomData.STAMINA_REGEN_EVERY_TICKS:
		ph = 0
		if current(id) < SomData.STAMINA_MAX:
			_stamina[id] = mini(SomData.STAMINA_MAX, current(id) + SomData.STAMINA_REGEN_AMOUNT)
	_regen_phase[id] = ph


func set_current(id: String, value: int) -> void:
	if id == "":
		return
	_stamina[id] = clampi(value, 0, SomData.STAMINA_MAX)


func wire_stamina(id: String) -> int:
	return clampi(current(id), 0, 255)
