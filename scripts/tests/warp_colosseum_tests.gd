extends Node
## WM1-warp naar Colosseum na lobby-bezoek (--warpcolosseumtest, runner only; niet in CI-matrix).
## Start: godot --path . -- --warpcolosseumtest

const Destinations := preload("res://world_warper/warp/destinations.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const LOBBY := Destinations.ARENA_LOBBY_PATH

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_all.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run_all() -> void:
	_zuivere_bestemmingen()
	await _warp_landing()
	print("WARPCOLOSSEUMTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _basis_plaatsen() -> Dictionary:
	var basis: Dictionary = {}
	for place in [
		{
			"id": Destinations.PLACE_WERELDKAART,
			"label": "World Map",
			"path": GameState.WORLD_MAP,
			"spawn": Destinations.WORLD_MAP_SPAWN,
		},
		{
			"id": Destinations.PLACE_WILGENDAL,
			"label": "Willowdale",
			"path": Destinations.WILGENDAL_PATH,
			"spawn": Destinations.WILGENDAL_SPAWN,
		},
		{
			"id": Destinations.PLACE_ESDOORN,
			"label": "Mapleton",
			"path": Destinations.ESDOORN_PATH,
			"spawn": Destinations.ESDOORN_SPAWN,
		},
	]:
		basis[str(place["id"])] = place
	return basis


func _plaats_voor_id(plaatsen: Array[Dictionary], place_id: String) -> Dictionary:
	for place in plaatsen:
		if str(place.get("id", "")) == place_id:
			return place
	return {}


func _zuivere_bestemmingen() -> void:
	var oud: Array[String] = []
	for pad in Destinations.huidige_bezocht():
		oud.append(str(pad))
	var basis := _basis_plaatsen()
	GameState.bezochte_kaarten = [GameState.WORLD_MAP]
	var zonder_lobby: Array[Dictionary] = Destinations.places(Destinations.WM1)
	check("zonder lobby: geen Colosseum in lijst", _plaats_voor_id(zonder_lobby, Destinations.PLACE_COLOSSEUM).is_empty())
	check("zonder lobby: resolve faalt", Destinations.resolve(Destinations.WM1, Destinations.PLACE_COLOSSEUM, {}).is_empty())
	for place_id in basis:
		var verwacht: Dictionary = basis[place_id]
		var actueel := _plaats_voor_id(zonder_lobby, place_id)
		check(
			"zonder lobby: %s ongewijzigd" % place_id,
			not actueel.is_empty()
			and str(actueel.get("label", "")) == str(verwacht.get("label", ""))
			and str(actueel.get("path", "")) == str(verwacht.get("path", ""))
			and str(actueel.get("spawn", "")) == str(verwacht.get("spawn", "")),
		)
	GameState.bezochte_kaarten = [GameState.WORLD_MAP, LOBBY]
	var met_lobby: Array[Dictionary] = Destinations.places(Destinations.WM1)
	var colo := _plaats_voor_id(met_lobby, Destinations.PLACE_COLOSSEUM)
	check("met lobby: Colosseum in lijst", not colo.is_empty())
	check("met lobby: label Colosseum", str(colo.get("label", "")) == "Colosseum")
	check("met lobby: pad wereldkaart", str(colo.get("path", "")) == GameState.WORLD_MAP)
	check("met lobby: spawn van_arena", str(colo.get("spawn", "")) == Destinations.COLOSSEUM_SPAWN)
	check("met lobby: is_place_open", Destinations.is_place_open(colo, Destinations.huidige_bezocht()))
	var gekozen := Destinations.resolve(Destinations.WM1, Destinations.PLACE_COLOSSEUM, {})
	check("met lobby: resolve spawn", str(gekozen.get("spawn", "")) == Entry.RETURN_SPAWN)
	check("met lobby: resolve pad", str(gekozen.get("path", "")) == WORLD)
	for place_id in basis:
		var verwacht: Dictionary = basis[place_id]
		var actueel := _plaats_voor_id(met_lobby, place_id)
		check(
			"met lobby: %s ongewijzigd" % place_id,
			not actueel.is_empty()
			and str(actueel.get("label", "")) == str(verwacht.get("label", ""))
			and str(actueel.get("path", "")) == str(verwacht.get("path", ""))
			and str(actueel.get("spawn", "")) == str(verwacht.get("spawn", "")),
		)
	GameState.bezochte_kaarten = oud


func _warp_landing() -> void:
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	GameState.bezochte_kaarten = [WORLD, LOBBY]
	var gekozen := Destinations.resolve(Destinations.WM1, Destinations.PLACE_COLOSSEUM, {})
	check("travel: resolve gevuld", not gekozen.is_empty())
	check("travel: change_map", GameState.change_map(str(gekozen.get("path", "")), str(gekozen.get("spawn", ""))))
	await _wait_path(WORLD, 14.0)
	var world: Node = get_tree().current_scene
	check("travel: wereldkaart geladen", world != null and world.scene_file_path == WORLD)
	var spawn := world.get_node_or_null("Spawns/" + Entry.RETURN_SPAWN)
	check("travel: spawn-node van_arena", spawn != null)
	var player: CharacterBody2D = world.get_node_or_null("Objects/Player") as CharacterBody2D
	check("travel: speler aanwezig", player != null)
	if player != null:
		check("travel: tile van_arena", player.get_tile() == Entry.RETURN_TILE)
		check("travel: facing", player.facing == Entry.RETURN_FACING)
		check("travel: niet input_locked", not player.input_locked)
		check("travel: veld vrij", GameState.field_free())
		if world.has_method("is_wall"):
			check("travel: spawn loopbaar", not world.is_wall(player.get_tile()))
			check("travel: stap zuid kan", not world.is_wall(player.get_tile() + Vector2i.DOWN))


func _wait_path(path: String, timeout: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := get_tree().current_scene
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			break
		await get_tree().process_frame
	if Transition._rect != null:
		var t1 := Time.get_ticks_msec()
		while Transition._rect != null and Time.get_ticks_msec() - t1 < timeout * 1000.0:
			await get_tree().process_frame