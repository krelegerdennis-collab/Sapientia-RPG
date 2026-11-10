extends RefCounted
class_name PageWardenFight
## Host-autoritatieve Page Warden @ 60 Hz. Zelfde patroon als GolemFight:
## BossPhaseMachine (90 ticks onkwetsbaar, schadeplafond op de fasedrempel) +
## BossCoreRt als stagger-venster (hier schade ×1, geen hamerslag).
## Aanvallen via de seeded fase-RNG. Doelkeuze zit niet hier: de arena/sim roept
## ThreatTable.choose() alleen bij telegraph_start aan.
##
## Events: telegraph_start {id, windup, large, tick} / attack_hit {id, power, large}
##         stagger_open / stagger_close / stagger_break
##         phase {index} / adds {ids} / invuln_end / telegraphs_cancelled

const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
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
var _events: Array = []
var _script: Dictionary
var _stagger_ticks := 60


func _init(max_hp: int, seed: int = 0, script: Dictionary = {}) -> void:
	_script = script if not script.is_empty() else PageWardenBoss.SCRIPT
	pm = BossPhaseMachine.new(_script, max_hp, seed)
	var cfg: Dictionary = _script.get("stagger", PageWardenBoss.STAGGER)
	core = BossCoreRt.new(cfg)
	_stagger_ticks = int(cfg.get("stagger_ticks", 60))


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


## Baas-telegrafen die nu zichtbaar zijn (stagger-venster + aanval-windup). Max 2.
func telegraph_count() -> int:
	return (1 if core.open else 0) + (1 if step == Step.WINDUP else 0)


func tick() -> void:
	if is_dead():
		return
	tick_no += 1
	var was_invuln := pm.is_invulnerable()
	pm.tick()
	var ce := core.tick()
	if ce == "open":
		_events.append({"type": "stagger_open", "windup": core.open_ticks, "tick": tick_no})
	elif ce == "slam":
		_events.append({"type": "stagger_close", "tick": tick_no})
	if was_invuln:
		if not pm.is_invulnerable():
			_events.append({"type": "invuln_end", "tick": tick_no})
		return
	_step_attack()


func _step_attack() -> void:
	if step != Step.IDLE:
		step_left -= 1
		if step_left > 0:
			return
		match step:
			Step.WINDUP:
				var a := PageWardenBoss.attack(attack_id)
				step = Step.ACTIVE
				step_left = int(a["active"])
				_events.append({"type": "attack_hit", "id": attack_id, "power": float(a["power"]),
					"large": bool(a["large_aoe"]), "tick": tick_no})
				return
			Step.ACTIVE:
				if _repeat_left > 0:
					_repeat_left -= 1
					var again := PageWardenBoss.attack(attack_id)
					_start(attack_id, int(again.get("windup2", again["windup"])), true)
					return
				step = Step.RECOVERY
				step_left = int(PageWardenBoss.attack(attack_id)["recovery"])
				return
			_:
				step = Step.IDLE
	if step == Step.STAGGER:
		return
	if core.open:
		return
	var id := pm.pick_attack()
	if id == "":
		return
	_repeat_left = int(PageWardenBoss.attack(id).get("repeat", 1)) - 1
	_start(id, int(PageWardenBoss.attack(id)["windup"]), false)


func _start(id: String, windup: int, is_repeat: bool) -> void:
	attack_id = id
	step = Step.WINDUP
	step_left = windup
	var a := PageWardenBoss.attack(id)
	_events.append({"type": "telegraph_start", "id": id, "windup": windup, "large": bool(a["large_aoe"]),
		"repeat": is_repeat, "ranged": bool(a.get("ranged", false)), "tick": tick_no})


## Ruwe schade (al ATK/DEF). Venster schaalt ×1. Afgekapt op de fasedrempel, zoals de Golem.
func damage(raw: int) -> int:
	if is_dead() or pm.is_invulnerable() or raw <= 0:
		return 0
	var scaled := core.scale_damage(raw)
	var phases: Array = _script.get("phases", [])
	if pm.phase_index() < phases.size() - 1:
		scaled = mini(scaled, pm.current_hp() - pm.threshold_hp(pm.phase_index()))
		if scaled <= 0:
			return 0
	var was_open := core.open
	var before_phase := pm.phase_index()
	var dealt := pm.on_damage(scaled)
	if pm.phase_index() != before_phase:
		_enter_phase(pm.phase_index())
		return dealt
	if was_open and core.add_dealt(dealt):
		_events.append({"type": "stagger_break", "tick": tick_no})
		_cancel_attack()
		step = Step.STAGGER
		step_left = _stagger_ticks
	return dealt


func _cancel_attack() -> void:
	if step == Step.WINDUP or step == Step.ACTIVE:
		_events.append({"type": "telegraphs_cancelled", "tick": tick_no})
	step = Step.IDLE
	step_left = 0
	_repeat_left = 0


func _enter_phase(idx: int) -> void:
	_cancel_attack()
	_events.append({"type": "phase", "index": idx, "tick": tick_no})
	var phases: Array = _script.get("phases", [])
	if idx < phases.size():
		var adds: Array = (phases[idx] as Dictionary).get("adds", [])
		if not adds.is_empty():
			_events.append({"type": "adds", "ids": adds.duplicate(), "tick": tick_no})
