extends RefCounted
class_name ThreatTable
## COMBAT_DESIGN §8: één threat-tabel per vijand. Eerste gebruiker is de Page Warden (co-op).
## Vervangt daar de co-op-tak van SomArena._target_for, die altijd stoel 0 koos.
## Geen tweede formule: schade ×1, heal ×0.5, tank ×1.5, taunt = max+50% voor 4 s,
## verval −10% per seconde buiten bereik, wissel alleen tussen telegrafen
## (de aanroeper roept choose() niet aan tijdens een windup).
## Host-autoritatief. Geen RNG: gelijke score houdt de dichtstbijzijnde (volgorde van de aanroeper).

const SLOTS := 4
const DAMAGE_GAIN := 1.0
const HEAL_GAIN := 0.5
const TANK_PASSIVE := 1.5
const TAUNT_BONUS := 1.5
const TAUNT_TICKS := 240          # 4 s @ 60 Hz
const DECAY_PER_SECOND := 0.9     # −10%
const SWITCH_MELEE := 1.10
const SWITCH_RANGED := 1.30
const NEAR_BONUS := 1.20          # binnen 2 tegels

var _threat: Array = [0.0, 0.0, 0.0, 0.0]
var _target := -1
var _taunt_slot := -1
var _taunt_until := -1


func target_slot() -> int:
	return _target


func threat_of(slot: int) -> float:
	if slot < 0 or slot >= SLOTS:
		return 0.0
	return float(_threat[slot])


func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	_threat[slot] = 0.0
	if _target == slot:
		_target = -1
	if _taunt_slot == slot:
		_taunt_slot = -1
		_taunt_until = -1


## Schade die deze stoel op déze vijand deed. tank = klasse Warrior (D2).
func note_damage(slot: int, amount: int, tank: bool) -> void:
	_add(slot, float(maxi(0, amount)) * DAMAGE_GAIN, tank)


## Heal door deze stoel. Bij één baas gaat de hele 0,5× hierheen (niets te verdelen).
func note_heal(slot: int, amount: int, tank: bool) -> void:
	_add(slot, float(maxi(0, amount)) * HEAL_GAIN, tank)


## Zet de stoel op max(threat) × 1,5 en legt het doel 4 s vast. Lege tafel: 1 punt.
func taunt(slot: int, tick: int) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	var peak := 0.0
	for i in SLOTS:
		peak = maxf(peak, float(_threat[i]))
	_threat[slot] = maxf(1.0, peak) * TAUNT_BONUS
	_taunt_slot = slot
	_taunt_until = tick + TAUNT_TICKS
	_target = slot


## Eén keer per seconde aanroepen. Stoelen in `in_range` vervallen niet.
func decay_out_of_range(in_range: Array) -> void:
	for i in SLOTS:
		if in_range.has(i):
			continue
		_threat[i] = float(_threat[i]) * DECAY_PER_SECOND


## living_nearest_first: levende stoelen, dichtstbij eerst.
## near_slots: binnen 2 tegels (+20% op de score).
## ranged: wisseldrempel 130%, anders 110%.
## Niet aanroepen midden in een telegraaf.
func choose(living_nearest_first: Array, near_slots: Array, ranged: bool, tick: int) -> int:
	if _taunt_slot >= 0 and tick <= _taunt_until and living_nearest_first.has(_taunt_slot):
		_target = _taunt_slot
		return _target
	if _taunt_slot >= 0 and tick > _taunt_until:
		_taunt_slot = -1
	var best := -1
	var best_score := -1.0
	for slot in living_nearest_first:
		var s := int(slot)
		if s < 0 or s >= SLOTS:
			continue
		var score := _score(s, near_slots.has(s))
		if score > best_score:
			best_score = score
			best = s
	if best < 0:
		_target = -1
		return -1
	if _target < 0 or not living_nearest_first.has(_target):
		_target = best
		return _target
	var cur := _score(_target, near_slots.has(_target))
	var need := (SWITCH_RANGED if ranged else SWITCH_MELEE) * cur
	if best != _target and best_score > cur and best_score + 0.0001 >= need:
		_target = best
	return _target


func _add(slot: int, amount: float, tank: bool) -> void:
	if slot < 0 or slot >= SLOTS or amount <= 0.0:
		return
	if tank:
		amount *= TANK_PASSIVE
	_threat[slot] = float(_threat[slot]) + amount


func _score(slot: int, near: bool) -> float:
	var s := float(_threat[slot])
	if near:
		s *= NEAR_BONUS
	return s
