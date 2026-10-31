extends RefCounted
class_name GolemFight
## D3 PR B: host-authoritatieve, deterministische Golem-baas @ 60 Hz (docs/combat/d3_action_bosses.md §2, §6).
## Combineert BossPhaseMachine (fases, 90 ticks onkwetsbaar) + BossCoreRt (8 s cyclus, 2 s open, break 45)
## + aanvalsplanner (één baas-aanval tegelijk + kern-gloed = max 2 baas-telegrafen).
## Geen nodes, geen allocaties per tick behalve de event-lijst. Gasten krijgen alleen de events.
##
## Gebruik: fight.tick(); for ev in fight.take_events(): ...; fight.damage(ruw) -> echt toegebracht.
## Events: {type: "telegraph_start", id, windup, large} / {type: "attack_hit", id, power, large}
##         {type: "core_open"} / {type: "core_break"} / {type: "core_slam"} (start golem_hammer_blow)
##         {type: "phase", index} / {type: "adds", ids} / {type: "invuln_end"} / {type: "telegraphs_cancelled"}

const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const BossCoreRt := preload("res://scripts/som/boss_core_rt.gd")

enum Step { IDLE, WINDUP, ACTIVE, RECOVERY, STAGGER }

var pm: BossPhaseMachine
var core: BossCoreRt
var tick_no := 0
var step: int = Step.IDLE
var step_left := 0
var attack_id := ""
var _repeat_left := 0
var _forced: Array = []   # wachtrij geforceerde aanvallen (hammer_blow na slam, p3-klap)
var _p3_blow_done := false
var _events: Array = []
var _script: Dictionary


func _init(max_hp: int, seed: int = 0, script: Dictionary = GolemBoss.SCRIPT) -> void:
	_script = script
	pm = BossPhaseMachine.new(script, max_hp, seed)
	core = BossCoreRt.new(script.get("core", GolemBoss.CORE))


## Alle events sinds de vorige aanroep (tick() en damage()), daarna leeg.
func take_events() -> Array:
	var out := _events
	_events = []
	return out


func phase_index() -> int:
	return pm.phase_index()


func hp() -> int:
	return pm.current_hp()


func max_hp() -> int:
	return pm.max_hp()


func is_dead() -> bool:
	return pm.current_hp() <= 0


func is_invulnerable() -> bool:
	return pm.is_invulnerable()


## Aantal baas-telegrafen die nu zichtbaar zijn (kern-gloed + aanval-windup).
func telegraph_count() -> int:
	return (1 if core.open else 0) + (1 if step == Step.WINDUP else 0)


func tick() -> void:
	if is_dead():
		return
	tick_no += 1
	var was_invuln := pm.is_invulnerable()
	pm.tick()
	if was_invuln:
		if not pm.is_invulnerable():
			_events.append({"type": "invuln_end"})
		return        # fasewissel (precies INVULN_TICKS ticks): niets loopt, kern-klok staat stil
	var ce := core.tick()
	if ce == "open":
		_events.append({"type": "core_open", "windup": core.open_ticks})
	elif ce == "slam":
		_events.append({"type": "core_slam"})
		_forced.append("golem_hammer_blow")
	# fase 3: eenmalige klap onder 10% HP, zonder kernvenster
	if pm.phase_index() == 2 and not _p3_blow_done and float(pm.current_hp()) < float(pm.max_hp()) * float(_script.get("p3_low_hp_blow_below", 0.1)):
		_p3_blow_done = true
		_forced.append("golem_hammer_blow_p3")
	_step_attack()


func _step_attack() -> void:
	if step != Step.IDLE:
		step_left -= 1
		if step_left > 0:
			return
		match step:
			Step.WINDUP:
				var a := GolemBoss.attack(attack_id)
				step = Step.ACTIVE
				step_left = int(a["active"])
				_events.append({"type": "attack_hit", "id": attack_id, "power": float(a["power"]), "large": bool(a["large_aoe"])})
				return
			Step.ACTIVE:
				if _repeat_left > 0:
					_repeat_left -= 1
					_start(attack_id, int(GolemBoss.attack(attack_id).get("windup2", GolemBoss.attack(attack_id)["windup"])), true)
					return
				step = Step.RECOVERY
				step_left = int(GolemBoss.attack(attack_id)["recovery"])
				return
			_:
				step = Step.IDLE
	# IDLE: geforceerde klap mag altijd; gewone aanvallen niet terwijl de kern oplaadt (open venster)
	if not _forced.is_empty():
		var f := str(_forced.pop_front())
		_repeat_left = 0
		_start(f, int(GolemBoss.attack(f)["windup"]), false)
		return
	if core.open:
		return
	var id := pm.pick_attack()
	if id == "":
		return
	_repeat_left = int(GolemBoss.attack(id).get("repeat", 1)) - 1
	_start(id, int(GolemBoss.attack(id)["windup"]), false)


func _start(id: String, windup: int, is_repeat: bool) -> void:
	attack_id = id
	step = Step.WINDUP
	step_left = windup
	_events.append({"type": "telegraph_start", "id": id, "windup": windup, "large": bool(GolemBoss.attack(id)["large_aoe"]),
		"repeat": is_repeat, "tick": tick_no})


## Ruwe schade van een held (al met ATK/DEF-formule). Kern-factor erop; geeft echt toegebracht.
func damage(raw: int) -> int:
	if is_dead() or pm.is_invulnerable() or raw <= 0:
		return 0
	var scaled := core.scale_damage(raw)
	var was_open := core.open
	var before_phase := pm.phase_index()
	var dealt := pm.on_damage(scaled)
	if pm.phase_index() != before_phase:
		_enter_phase(pm.phase_index())
		return dealt
	if was_open and core.add_dealt(dealt):
		_events.append({"type": "core_break"})
		_cancel_attack()
		step = Step.STAGGER
		step_left = int((_script.get("core", GolemBoss.CORE) as Dictionary).get("stagger_ticks", 60))
	return dealt


func _cancel_attack() -> void:
	if step == Step.WINDUP or step == Step.ACTIVE:
		_events.append({"type": "telegraphs_cancelled"})
	step = Step.IDLE
	step_left = 0
	_repeat_left = 0


func _enter_phase(idx: int) -> void:
	_cancel_attack()
	_forced.clear()
	core.reset()
	_events.append({"type": "phase", "index": idx})
	var phases: Array = _script.get("phases", [])
	if idx < phases.size():
		var adds: Array = (phases[idx] as Dictionary).get("adds", [])
		if not adds.is_empty():
			_events.append({"type": "adds", "ids": adds.duplicate()})
