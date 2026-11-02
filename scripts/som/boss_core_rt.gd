extends RefCounted
class_name BossCoreRt
## D3 PR B: realtime-variant van BossCore (scripts/battle/boss_core.gd blijft de ronde-API voor Classic).
## Vaste cyclus in ticks @ 60 Hz: (cycle - open) dicht, dan open. Open venster = golem_core_charge.
## >= break_damage schade in het venster -> meteen "break" (stagger). Venster voorbij zonder break -> "slam".
## Pure logica, geen nodes, geen RNG: host-authoritatief en deterministisch.

var cycle_ticks := 480
var open_ticks := 120
var break_damage := 45
var closed_mult := 0.4
var open_mult := 2.0

var _t := 0          # ticks in de huidige cyclus
var open := false
var dealt := 0
var opened_count := 0
var broken_count := 0
var slam_count := 0


func _init(cfg: Dictionary = {}) -> void:
	cycle_ticks = maxi(2, int(cfg.get("cycle_ticks", cycle_ticks)))
	open_ticks = clampi(int(cfg.get("open_ticks", open_ticks)), 1, cycle_ticks - 1)
	break_damage = maxi(1, int(cfg.get("break_damage", break_damage)))
	closed_mult = float(cfg.get("closed_mult", closed_mult))
	open_mult = float(cfg.get("open_mult", open_mult))


func closed_ticks() -> int:
	return cycle_ticks - open_ticks


func cycle_pos() -> int:
	return _t


## Eén tick. Geeft "" of een gebeurtenis: "open", "slam" (venster voorbij, geen break).
func tick() -> String:
	_t += 1
	if not open and _t == closed_ticks():
		open = true
		dealt = 0
		opened_count += 1
		return "open"
	if _t >= cycle_ticks:
		_t = 0
		if open:
			open = false
			dealt = 0
			slam_count += 1
			return "slam"
	return ""


func damage_mult() -> float:
	return open_mult if open else closed_mult


## Schaal ruwe schade (min. 1). Telt in het open venster.
func scale_damage(amount: int) -> int:
	return maxi(1, roundi(float(amount) * damage_mult()))


## Registreer echt toegebrachte schade. true = break (venster dicht, cyclus opnieuw).
func add_dealt(amount: int) -> bool:
	if not open or amount <= 0:
		return false
	dealt += amount
	if dealt >= break_damage:
		open = false
		dealt = 0
		broken_count += 1
		return true   # vaste cyclus: _t loopt door, volgende opening na 8 s
	return false


## Fasewissel: venster vervalt zonder slam, cyclus begint opnieuw.
func reset() -> void:
	open = false
	dealt = 0
	_t = 0
