extends Node
## Classic-muur in het Wachtershuis (--huiscollisiontest): is_wall + player._can_move.
## Start: godot --path . -- --huiscollisiontest
## Niet via debug_autotest.gd. CI-matrix: voorstel aan Dennis (niet in tests.yml).

const SD := preload("res://scripts/data/story_data.gd")
const Build := preload("res://scripts/data/huis_interieur_build.gd")
const HUIS := "res://scenes/maps/huis_wilgendal.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	Settings.set_value("run", false)
	GameState.encounter_multiplier = 0.0
	GameState.som_mode = false
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.pending_spawn = "binnen"
	var huis: Node = await _laad()
	check("huis_wilgendal.tscn laadt", huis != null and str(huis.name) == "Huis")
	if huis == null:
		_einde()
		return
	await _pframes(8)
	var p: CharacterBody2D = huis.get_node_or_null("Objects/Player")
	check("classic: speler aanwezig, geen analoge modus", p != null and not p.analog_input.is_valid())
	check("kaart heeft is_wall (tegel_vrij omgekeerd)", huis.has_method("is_wall") and huis.has_method("tegel_vrij"))
	if p == null or not huis.has_method("is_wall"):
		_einde()
		return
	_logica(huis)
	await _loop_muur(p, huis)
	await _loop_meubels(p, huis)
	await _loop_rand(p, huis)
	await _loop_vrij_en_deur(p, huis)
	print("HUISCOLLISIONTEST %d PASS, %d FAIL" % [passes, failures])
	_einde()


func _einde() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _laad() -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.has_return_point = false
	get_tree().change_scene_to_file(HUIS)
	for i in 180:
		await get_tree().process_frame
		var s: Node = get_tree().current_scene
		if s != null and str(s.scene_file_path) == HUIS and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null


func _logica(huis: Node) -> void:
	var muur := Vector2i(0, 18)
	var bed := Vector2i(1, 4)
	var tafel := Vector2i(14, 7)
	var vloer := Vector2i(8, 17)
	var deur := Vector2i(8, 19)
	check("is_wall muur (0,18)", huis.is_wall(muur) and not huis.tegel_vrij(muur))
	check("tegel_vrij bed (1,4) geblokkeerd (prop)", not huis.tegel_vrij(bed))
	check("tegel_vrij tafel (14,7) geblokkeerd (prop)", not huis.tegel_vrij(tafel))
	check("is_wall buiten de kamer", huis.is_wall(Vector2i(-1, 18)) and huis.is_wall(Vector2i(8, 21)))
	check("vloer (8,17) vrij", not huis.is_wall(vloer) and huis.tegel_vrij(vloer))
	check("deur/uitgang (8,19) vrij", not huis.is_wall(deur) and huis.tegel_vrij(deur))
	for tegel in huis.voordeur_tegels():
		check("voordeur-tegel %s beloopbaar" % tegel, huis.tegel_vrij(tegel) and not huis.is_wall(tegel))


func _zet(p: CharacterBody2D, tegel: Vector2i, richting: Vector2i) -> void:
	p.place_at(tegel, richting)
	p.input_locked = false
	p.spawn_hold = false
	p.hold_until_release = false
	p.set_analog(Callable())


func _loop_muur(p: CharacterBody2D, huis: Node) -> void:
	_zet(p, Vector2i(1, 18), Vector2i.LEFT)
	await _pframes(2)
	await get_tree().physics_frame
	check("classic op (1,18), analog uit", p.get_tile() == Vector2i(1, 18) and not p.analog_input.is_valid())
	check("_can_move links in de muur geblokkeerd", not p._can_move(Vector2i.LEFT) and huis.is_wall(Vector2i(0, 18)))
	await _loop("move_left", 1)
	check("lopen in de zijmuur: blijft op (1,18)", p.get_tile() == Vector2i(1, 18) and huis.name == "Huis")


func _loop_meubels(p: CharacterBody2D, huis: Node) -> void:
	_zet(p, Vector2i(1, 5), Vector2i.UP)
	await _pframes(2)
	await get_tree().physics_frame
	check("voor het bed (1,5), bed-tegel niet vrij", p.get_tile() == Vector2i(1, 5)
			and not huis.tegel_vrij(Vector2i(1, 4)))
	check("muur achter het bed blokkeert _can_move", huis.is_wall(Vector2i(1, 2))
			or huis.is_wall(Vector2i(1, 3)))
	_zet(p, Vector2i(1, 3), Vector2i.UP)
	await _pframes(2)
	await get_tree().physics_frame
	check("lopen het bed in: muur erboven geblokkeerd", not p._can_move(Vector2i.UP)
			and huis.is_wall(Vector2i(1, 2)))
	await _loop("move_up", 1)
	check("blijft in de slaapkamer na stap richting muur", p.get_tile() == Vector2i(1, 3)
			and huis.name == "Huis")
	_zet(p, Vector2i(14, 8), Vector2i.UP)
	await _pframes(2)
	await get_tree().physics_frame
	check("voor de tafel (14,8), tafel-tegel niet vrij", p.get_tile() == Vector2i(14, 8)
			and not huis.tegel_vrij(Vector2i(14, 7)))
	_zet(p, Vector2i(12, 7), Vector2i.LEFT)
	await _pframes(2)
	await get_tree().physics_frame
	check("naast de tafel: muur links blokkeert", huis.is_wall(Vector2i(11, 7))
			and not p._can_move(Vector2i.LEFT))
	await _loop("move_left", 1)
	check("lopen de keukenmuur in: blijft op (12,7)", p.get_tile() == Vector2i(12, 7))


func _loop_rand(p: CharacterBody2D, huis: Node) -> void:
	_zet(p, Vector2i(1, 18), Vector2i.LEFT)
	await _pframes(2)
	await get_tree().physics_frame
	check("rand: tegel buiten de kamer is muur", huis.is_wall(Vector2i(-1, 18)))
	await _loop("move_left", 2)
	check("lopen voorbij de kamerrand: blijft binnen (1,18)", p.get_tile() == Vector2i(1, 18) \
			and huis.name == "Huis")


func _loop_vrij_en_deur(p: CharacterBody2D, huis: Node) -> void:
	_zet(p, Build.SPAWN_TEGEL, Vector2i.UP)
	await _pframes(2)
	await get_tree().physics_frame
	check("spawn (8,18) vrij", p.get_tile() == Build.SPAWN_TEGEL and not huis.is_wall(Build.SPAWN_TEGEL))
	check("_can_move omhoog naar vrije vloer", p._can_move(Vector2i.UP) and not huis.is_wall(Vector2i(8, 17)))
	check("_can_move omlaag naar de deur/uitgang", p._can_move(Vector2i.DOWN) and not huis.is_wall(Vector2i(8, 19)))
	await _loop("move_up", 1)
	check("lopen naar vrije vloer (8,17)", p.get_tile() == Vector2i(8, 17) and huis.name == "Huis")
	await _loop("move_down", 1)
	check("terug op spawn, deur nog beloopbaar", p.get_tile() == Build.SPAWN_TEGEL and p._can_move(Vector2i.DOWN))


func _loop(action: String, n: int) -> void:
	for i in n:
		var p: CharacterBody2D = _speler()
		if p == null:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 20:
			await get_tree().process_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().process_frame
		await get_tree().process_frame


func _speler() -> CharacterBody2D:
	var s: Node = get_tree().current_scene
	if s == null:
		return null
	return s.get_node_or_null("Objects/Player") as CharacterBody2D


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
