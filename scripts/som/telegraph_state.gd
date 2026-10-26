class_name TelegraphState
extends RefCounted
## Pure telegraaf-klok (Combat T2). Geen nodes, geen RNG, geen float, geen tijd-bibliotheek.
## Fasevolgorde: IDLE -> WINDUP -> ACTIVE -> RECOVERY -> COOLDOWN -> IDLE.
## Duur per fase in hele ticks bij vaste 60 Hz (COMBAT_DESIGN.md §16). `tick()` schuift exact één tick op.
##
## Fasen met duur 0 worden bij het binnengaan overgeslagen (deterministisch, zonder tick te verbruiken).
## Ongeldige duur (< 0) maakt `valid == false` met `invalid_reason`; `start()`/`tick()` doen dan niets schadelijk.
##
## Treffers: alleen op ticks waar `state == ACTIVE` (en `ticks_left > 0` na de tick, of tijdens de tick —
## zie `phase_changed` + `entered_state == ACTIVE` voor de eerste ACTIVE-tick).
##
## **cancel()** — vrijwillig afbreken: alleen uit WINDUP of ACTIVE, springt direct naar IDLE zonder COOLDOWN.
## Retourneert `true` als er iets te annuleren was.
##
## **interrupt()** — onderbreking (stagger/control): alleen uit WINDUP, springt naar IDLE (geen COOLDOWN).
## Tijdens ACTIVE/RECOVERY/COOLDOWN/IDLE: `false` (de slag is al begonnen of afgelopen).

enum State { IDLE, WINDUP, ACTIVE, RECOVERY, COOLDOWN }

const TICK_HZ := 60

var _windup_ticks: int = 0
var _active_ticks: int = 0
var _recovery_ticks: int = 0
var _cooldown_ticks: int = 0

var _state: int = State.IDLE
var _ticks_left: int = 0
var _valid: bool = true
var _invalid_reason: String = ""

var _phase_changed: bool = false
var _entered_state: int = State.IDLE


var state: int:
	get:
		return _state

var ticks_left: int:
	get:
		return _ticks_left

var valid: bool:
	get:
		return _valid

var invalid_reason: String:
	get:
		return _invalid_reason

var can_start: bool:
	get:
		return _valid and _state == State.IDLE

## `true` op de tick waar een nieuwe fase begint (inclusief `start()` en terug naar IDLE).
var phase_changed: bool:
	get:
		return _phase_changed

## Nieuwe fase op deze tick; alleen betekenisvol als `phase_changed`.
var entered_state: int:
	get:
		return _entered_state

## Totale tickduur per fase (alleen lezen; voor presentatie zoals TelegraphLayer).
var windup_duration_ticks: int:
	get:
		return _windup_ticks

var active_duration_ticks: int:
	get:
		return _active_ticks


## Zet faseduren in ticks. Negatieve waarde => `valid = false` (bestaande reden blijft staan).
func set_phase_ticks(windup: int, active: int, recovery: int, cooldown: int) -> void:
	_windup_ticks = windup
	_active_ticks = active
	_recovery_ticks = recovery
	_cooldown_ticks = cooldown
	_revalidate()


## Zelfde als `set_phase_ticks`, maar milliseconden -> ticks (zie `ms_to_ticks`).
func set_phase_ms(windup_ms: int, active_ms: int, recovery_ms: int, cooldown_ms: int) -> void:
	set_phase_ticks(ms_to_ticks(windup_ms), ms_to_ticks(active_ms), ms_to_ticks(recovery_ms), ms_to_ticks(cooldown_ms))


## ms omzetten naar ticks bij 60 Hz, **naar boven** afgerond (minimaal 0 ms => 0 ticks).
## Voorbeeld: 450 ms => 27 ticks (0,45 s); 1 ms => 1 tick.
static func ms_to_ticks(ms: int) -> int:
	if ms <= 0:
		return 0
	return (ms * TICK_HZ + 999) / 1000


## Start alleen uit IDLE. Retourneert `false` als `not can_start`.
func start() -> bool:
	if not can_start:
		return false
	_clear_phase_flags()
	_enter_state(State.WINDUP)
	return true


## Eén simulatietick. In IDLE geen effect (geen `phase_changed`).
func tick() -> void:
	_clear_phase_flags()
	if _state == State.IDLE:
		return
	_ticks_left -= 1
	if _ticks_left > 0:
		return
	_advance_from(_state)


func cancel() -> bool:
	if _state != State.WINDUP and _state != State.ACTIVE:
		return false
	_go_idle()
	return true


func interrupt() -> bool:
	if _state != State.WINDUP:
		return false
	_go_idle()
	return true


## Gast-only: spiegel host-fase zonder sim (co-op snapshot T5).
func mirror(phase: int, ticks_left: int) -> void:
	_clear_phase_flags()
	if phase == State.IDLE:
		_go_idle()
		return
	_state = phase
	_ticks_left = maxi(0, ticks_left)


func _revalidate() -> void:
	_invalid_reason = ""
	for label in ["windup", "active", "recovery", "cooldown"]:
		var v: int = _ticks_for_label(label)
		if v < 0:
			_invalid_reason = "%s ticks must be >= 0" % label
			_valid = false
			return
	_valid = true
	_invalid_reason = ""


func _ticks_for_label(label: String) -> int:
	match label:
		"windup":
			return _windup_ticks
		"active":
			return _active_ticks
		"recovery":
			return _recovery_ticks
		"cooldown":
			return _cooldown_ticks
	return 0


func _clear_phase_flags() -> void:
	_phase_changed = false
	_entered_state = State.IDLE


func _go_idle() -> void:
	_state = State.IDLE
	_ticks_left = 0
	_phase_changed = true
	_entered_state = State.IDLE


func _enter_state(next: int) -> void:
	while true:
		var dur: int = _duration_for(next)
		if dur > 0:
			_state = next
			_ticks_left = dur
			_phase_changed = true
			_entered_state = next
			return
		next = _successor(next)
		if next == State.IDLE:
			_go_idle()
			return


func _advance_from(from: int) -> void:
	var next: int = _successor(from)
	if next == State.IDLE:
		_go_idle()
		return
	_enter_state(next)


func _successor(s: int) -> int:
	match s:
		State.WINDUP:
			return State.ACTIVE
		State.ACTIVE:
			return State.RECOVERY
		State.RECOVERY:
			return State.COOLDOWN
		State.COOLDOWN:
			return State.IDLE
	return State.IDLE


func _duration_for(s: int) -> int:
	match s:
		State.WINDUP:
			return _windup_ticks
		State.ACTIVE:
			return _active_ticks
		State.RECOVERY:
			return _recovery_ticks
		State.COOLDOWN:
			return _cooldown_ticks
	return 0
