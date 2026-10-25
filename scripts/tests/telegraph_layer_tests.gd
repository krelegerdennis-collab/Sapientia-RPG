extends RefCounted
## TelegraphLayer (Combat T3). Draait via telegraph_tests.gd (--telegraphtest).

const TelegraphLayer := preload("res://scripts/som/telegraph_layer.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")

const O := Vector2i(80, 60)


func run_all(host: Node) -> void:
	_shape_outline_tests(host)
	_fill_step_tests(host)
	_visibility_tests(host)
	_layer_sync_tests(host)


func _shape_outline_tests(host: Node) -> void:
	var circle := TelegraphShape.make_circle(O, 20)
	var cp: PackedVector2Array = TelegraphLayer.outline_polygon(circle)
	host.check("layer: circle outline >= 8 punten", cp.size() >= 8)
	host.check("layer: circle outline bevat randpunt", _poly_near(cp, Vector2(O.x + 20, O.y)))
	var line := TelegraphShape.make_line(O, Vector2i(256, 0), 40, 16)
	var lp: PackedVector2Array = TelegraphLayer.outline_polygon(line)
	host.check("layer: line outline 4 hoeken", lp.size() == 4)
	host.check("layer: line hoek op origin-as", _poly_near(lp, Vector2(O.x, O.y), 10.0))
	var cone := TelegraphShape.make_cone(O, Vector2i(256, 0), 30, 70)
	var kp: PackedVector2Array = TelegraphLayer.outline_polygon(cone)
	host.check("layer: cone outline >= 4 punten", kp.size() >= 4)
	host.check("layer: cone top op origin", _poly_near(kp, Vector2(O.x, O.y), 2.0))


func _fill_step_tests(host: Node) -> void:
	host.check("layer: ACTIVE => 4 fill steps", TelegraphLayer.fill_steps_for_phase(TelegraphState.State.ACTIVE, 1, 27) == 4)
	host.check("layer: WINDUP start => 0 fill steps", TelegraphLayer.fill_steps_for_phase(TelegraphState.State.WINDUP, 27, 27) == 0)
	var mid := TelegraphLayer.fill_steps_for_phase(TelegraphState.State.WINDUP, 14, 27)
	host.check("layer: WINDUP halverwege 1..3 steps", mid >= 1 and mid <= 3)


func _visibility_tests(host: Node) -> void:
	host.check("layer: WINDUP zichtbaar", TelegraphLayer.is_visible_phase(TelegraphState.State.WINDUP))
	host.check("layer: COOLDOWN niet zichtbaar", not TelegraphLayer.is_visible_phase(TelegraphState.State.COOLDOWN))
	var tg := _runner_inktspuw()
	host.check("layer: IDLE geen entry", TelegraphLayer.entry_from_attack(tg) == null)
	tg.start(O, Vector2i(256, 0), "line")
	var ent: TelegraphLayer.DrawEntry = TelegraphLayer.entry_from_attack(tg)
	host.check("layer: WINDUP heeft entry", ent != null and ent.fill_steps >= 0)
	while tg.state() == TelegraphState.State.WINDUP:
		tg.tick()
	host.check("layer: na windup ACTIVE entry fill=4", TelegraphLayer.entry_from_attack(tg).fill_steps == 4)
	while tg.is_busy():
		tg.tick()
	host.check("layer: na cyclus geen entry", TelegraphLayer.entry_from_attack(tg) == null)


func _layer_sync_tests(host: Node) -> void:
	var layer := TelegraphLayer.new()
	var tg := _runner_inktspuw()
	var dummy := Node.new()
	var enemies := {dummy: {"tg": tg}}
	tg.start(O, Vector2i(0, 256), "line")
	layer.sync_from_enemies(enemies)
	host.check("layer: sync met actieve tg geeft entries", layer.entry_count() == 1)
	tg.cancel()
	layer.sync_from_enemies(enemies)
	host.check("layer: sync na cancel leeg", layer.entry_count() == 0)
	dummy.free()


func _runner_inktspuw() -> TelegraphAttack:
	var def: Dictionary = SomActionAttacks.attack("inktspuw")
	var tg := TelegraphAttack.new()
	tg.configure(def, SomActionAttacks.cooldown_ms("test", 0))
	return tg


func _poly_near(poly: PackedVector2Array, p: Vector2, max_d: float = 3.0) -> bool:
	for v in poly:
		if v.distance_to(p) <= max_d:
			return true
	return false
