extends RefCounted
## Regressie voor analoge muur-glijding (scripts/som/som_slide.gd + player._process_analog).
## De bestaande check in som_autotest.gd:190 blijft ongewijzigd; deze sectie hangt
## aan --autotest (debug_autotest.gd) en dekt de flake: >8 px omhoog bij een hapering.

const SomSlide := preload("res://scripts/som/som_slide.gd")
const SomMove := preload("res://scripts/som/som_move.gd")
const SomData := preload("res://scripts/data/som_data.gd")

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	_logica()
	_live_hapering()


## Plafond op tegelrij y<=2: zelfde patroon als som_autotest (muur boven, vrij opzij).
func _muur_boven(cel: Vector2i) -> bool:
	return cel.y <= 2


func _logica() -> void:
	var start := Vector2(40, 56)
	var vel: Vector2 = SomMove.joy_to_velocity(Vector2(0.7, -0.7), SomData.MOVE_SPEED)
	var muur := Callable(self, "_muur_boven")
	var p := start
	for i in 24:
		p = SomSlide.glijd(p, vel, 1.0 / 60.0, muur)
	t.check("muur-glijden 60 Hz: glijdt opzij, blijft onder de muur (dx %.1f, dy %.1f)" % [p.x - start.x, p.y - start.y],
			p.x - start.x > 6.0 and p.y >= 3 * 16.0 and p.y - start.y > -8.0)
	p = start
	p = SomSlide.glijd(p, vel, 0.20, muur)
	t.check("muur-glijden hapering 200 ms: geen tunnel omhoog (dx %.1f, dy %.1f)" % [p.x - start.x, p.y - start.y],
			p.x > start.x and p.y >= 3 * 16.0 and p.y - start.y > -8.0)
	var diep := Vector2(start.x + 16.6, start.y - 8.6)
	var vast: Vector2 = SomSlide.corrigeer(start, diep, muur)
	t.check("muur-glijden: corrigeer 8.6 px-penetratie (dy %.1f)" % (vast.y - start.y),
			vast.y - start.y > -8.0 and vast.y >= 3 * 16.0 and vast.x > start.x)
	t.check("muur-glijden: hitbox 10x8 op (0,3)",
			SomSlide.HIT_SIZE == Vector2(10, 8) and SomSlide.HIT_OFF == Vector2(0, 3))


## Live: analoge speler + één 200 ms-stap (zoals een CI-hapering), zonder som_autotest aan te passen.
func _live_hapering() -> void:
	var p: CharacterBody2D = t.player() if t.has_method("player") else null
	var kamer: Node = t.scene() if t.has_method("scene") else null
	if p == null or kamer == null or not kamer.has_method("is_wall") or not p.analog_input.is_valid():
		t.check("muur-glijden live: analoge kamer (overgeslagen)", true)
		return
	var wt := Vector2i(-1, -1)
	for y in range(2, 11):
		for x in range(2, 28):
			var c := Vector2i(x, y)
			if kamer.is_wall(c + Vector2i.UP) and not kamer.is_wall(c) and not kamer.is_wall(c + Vector2i.RIGHT) \
					and not kamer.is_wall(c + Vector2i(2, 0)) and kamer.is_wall(c + Vector2i(1, -1)) \
					and kamer.is_wall(c + Vector2i(2, -1)):
				wt = c
				break
		if wt.x >= 0:
			break
	if wt.x < 0:
		t.check("muur-glijden live: muurtegel gevonden", false)
		return
	p.place_at(wt, Vector2i.UP)
	var old: Callable = p.analog_input
	p.analog_input = func() -> Vector2: return SomMove.joy_to_dir(Vector2(0.7, -0.7))
	var start: Vector2 = p.position
	p._process_analog(0.20)
	p.analog_input = old
	t.check("muur-glijden live 200 ms: geen 8.5 px omhoog (dx %.1f, dy %.1f)" % [p.position.x - start.x, p.position.y - start.y],
			p.position.x - start.x > 6.0 and p.position.y >= wt.y * 16.0 and p.position.y - start.y > -8.0)
