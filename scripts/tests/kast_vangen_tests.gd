extends Node
## ALLEEN VOOR TESTEN - Inktwurm uit de geheime kast (Golemhal) is in Action vangbaar met de CODEX-knop.
## Regressie: de kast spawnde de worm NA SomArena.setup() en registreerde hem niet bij de arena, dus
## arena.enemies kende hem niet -> CODEX gaf "No enemy in range." terwijl hij naast de speler stond.
## Start:  godot --path . -- --kastvangentest
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(1907)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	await _live_open_tests()
	await _reload_open_tests()
	Settings.set_value("battle_style", oude_stijl)
	print("KASTVANGENTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- helpers
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	for i in 30:
		if not Dialog.is_open:
			break
		await press_interact()
		await pframes(2)
	await pframes(2)


func enter(path: String, spawn: String) -> Node:
	GameState.has_return_point = false
	GameState.map_monster_battle = {}
	GameState.change_map(path, spawn)
	if not await wait_scene_path(path):
		return null
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)
	await wait_until(func(): return not Story.running, 5.0)
	await close_dialog()
	await pframes(6)
	return scene()


func setup() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(10))
	h["hp"] = h["max_hp"]
	GameState.story_flags[SD.GOLEM_FLAG] = true
	# beide tutorials gezien: geen dialoog tussendoor
	GameState.story_flags[SD.TUTORIAL_INKTWURM_FLAG] = true
	GameState.story_flags[SD.TUTORIAL_CODEX_FLAG] = true
	GameState.add_item(CD.BOOK_ITEM, 3)


func worm_of(room: Node) -> Node:
	for m in room.monsters:
		if is_instance_valid(m) and str(m.enemy_id) == "inktwurm":
			return m
	return null


func _try_capture(room: Node, tag: String) -> void:
	var som: Node = room.get("som")
	check(tag + ": Action-arena actief in de Golemhal", som != null)
	if som == null:
		return
	var worm := worm_of(room)
	check(tag + ": Inktwurm staat in de kamer", worm != null)
	if worm == null:
		return
	var d: float = som.center_of(worm).distance_to(som.body())
	print("  info: afstand speler->worm %.1f px (SPELL_RANGE %.0f)" % [d, SomData.SPELL_RANGE])
	check(tag + ": worm binnen SPELL_RANGE", d <= SomData.SPELL_RANGE)
	check(tag + ": worm geregistreerd bij de arena (arena.enemies)", som.enemies.has(worm))
	check(tag + ": worm in codex_targets()", som.codex_targets().any(func(e): return e["target"] == worm))
	som.codex.force_roll = 0.0
	var books := GameState.item_count(CD.BOOK_ITEM)
	var text: String = som.codex.capture()
	print("  info: melding = %s" % text.replace("\n", " | "))
	check(tag + ": CODEX zegt NIET 'No enemy in range.'", text != SomData.TXT_NO_TARGET)
	check(tag + ": vangst gelukt (boek -1, Inktwurm gevangen, vlag)", str(som.codex.last_capture.get("result", "")) == "gelukt"
			and GameState.item_count(CD.BOOK_ITEM) == books - 1 and GameState.unique_state("inktwurm") == "gevangen"
			and GameState.story_flags.has(SD.CODEX_INKTWURM_FLAG))
	await wait_until(func(): return not som.codex.busy, 3.0)


## Kast gaat open terwijl je in de kamer bent (de echte speelroute na de Golem).
func _live_open_tests() -> void:
	setup()
	GameState.story_flags.erase("inktwurm_kast_open")
	var room := await enter(GOLEM_SCENE, "zuid")
	check("A: Golemhal geladen", room != null and "monsters" in room)
	if room == null:
		return
	var kast: Node = room.get_node_or_null("Objects/InktwurmKast")
	check("A: kast dicht", kast != null and not kast.is_open)
	if kast == null:
		return
	player().place_at(Vector2i(16, 5), Vector2i.RIGHT)
	await pframes(4)
	kast.interact(player())
	var opened: bool = await wait_until(func(): return is_instance_valid(kast) and kast.is_open, 4.0)
	await pframes(12)
	await close_dialog()
	check("A: kast open", opened)
	# speler naast de worm (worm op 16,5): links ernaast, kijkt naar rechts
	player().place_at(Vector2i(15, 5), Vector2i.RIGHT)
	await pframes(4)
	await _try_capture(room, "A")


## Kast was al open bij binnenkomst (worm gespawnd in _build, vóór de arena).
func _reload_open_tests() -> void:
	setup()
	GameState.story_flags["inktwurm_kast_open"] = true
	GameState.story_flags["gloeiende_inktfles"] = true
	var room := await enter(GOLEM_SCENE, "zuid")
	check("B: Golemhal geladen", room != null and "monsters" in room)
	if room == null:
		return
	player().place_at(Vector2i(15, 5), Vector2i.RIGHT)
	await pframes(4)
	await _try_capture(room, "B")
