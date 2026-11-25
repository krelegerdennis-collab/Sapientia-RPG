extends Node
## WM1-warp naar Colosseum na lobby-bezoek (--warpcolosseumtest, runner only; niet in CI-matrix).
## Start: godot --path . -- --warpcolosseumtest

const Destinations := preload("res://world_warper/warp/destinations.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const SD := preload("res://scripts/data/story_data.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const WarpScene := preload("res://world_warper/warp/warp_view.tscn")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const LOBBY := Destinations.ARENA_LOBBY_PATH
const VIEW := Vector2(384, 216)

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
	_save_roundtrip()
	await _warpview_layout()
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


func _zet_basis_viewport() -> void:
	var win := get_window()
	if win != null:
		win.size = Vector2i(384, 216)
	UiTouchC.insets_override = Vector4.ZERO
	GameState.story_flags[SD.WARP_UITLEG_FLAG] = true


func _rij_knoppen(rows: VBoxContainer) -> Array[Control]:
	var uit: Array[Control] = []
	for kind in rows.get_children():
		if kind is BaseButton:
			var knop := kind as BaseButton
			if knop.focus_mode != Control.FOCUS_NONE:
				uit.append(knop)
		elif kind is HBoxContainer:
			for c in kind.get_children():
				if c is BaseButton and (c as BaseButton).focus_mode != Control.FOCUS_NONE:
					uit.append(c)
					break
	return uit


func _binnen_scroll(scroll: ScrollContainer, knop: Control) -> bool:
	return scroll.is_ancestor_of(knop)


func _scroll_inhoud_overflow(scroll: ScrollContainer, rows: VBoxContainer) -> bool:
	await get_tree().process_frame
	var inhoud := rows.get_combined_minimum_size().y
	return inhoud > scroll.size.y + 0.5


func _rij_zichtbaar_in_scroll(scroll: ScrollContainer, knop: Control) -> bool:
	var zone := scroll.get_global_rect()
	var knop_r := knop.get_global_rect()
	return zone.intersects(knop_r) and knop_r.size.y > 0.0


func _volledig_in_scroll(scroll: ScrollContainer, knop: Control) -> bool:
	var zone := scroll.get_global_rect()
	var knop_r := knop.get_global_rect()
	return zone.position.y <= knop_r.position.y + 0.5 and zone.end.y >= knop_r.end.y - 0.5


func _parse_ui_down() -> void:
	var aan := InputEventAction.new()
	aan.action = "ui_down"
	aan.pressed = true
	Input.parse_input_event(aan)
	var uit := InputEventAction.new()
	uit.action = "ui_down"
	uit.pressed = false
	Input.parse_input_event(uit)


func _open_wm1_plaatsen(bezocht: Array) -> Array:
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	var pads: Array[String] = []
	for p in bezocht:
		pads.append(str(p))
	GameState.bezochte_kaarten = pads
	var view: Control = WarpScene.instantiate()
	layer.add_child(view)
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.position = Vector2.ZERO
	view.size = VIEW
	view.custom_minimum_size = VIEW
	return [layer, view]


func _naar_plaatsen_step(view: Control) -> void:
	view.open()
	for _i in 6:
		await get_tree().process_frame
	var wm1 := view.find_child("Rij_WM1", true, false) as BaseButton
	check("layout: WM1-knop", wm1 != null)
	if wm1 != null and not wm1.disabled:
		wm1.pressed.emit()
	for _i in 6:
		await get_tree().process_frame


func _warpview_layout() -> void:
	_zet_basis_viewport()
	var basis: Array[String] = []
	basis.append(GameState.WORLD_MAP)
	basis.append(Destinations.WILGENDAL_PATH)
	basis.append(Destinations.ESDOORN_PATH)
	var open_3: Array = _open_wm1_plaatsen(basis)
	var layer3: Node = open_3[0]
	var view3: Control = open_3[1]
	await _naar_plaatsen_step(view3)
	var scroll3 := view3.find_child("RijenScroll", true, false) as ScrollContainer
	var rows3 := view3.find_child("Rijen", true, false) as VBoxContainer
	check("layout 3: ScrollContainer", scroll3 != null and rows3 != null)
	if scroll3 != null and rows3 != null:
		var kn3 := _rij_knoppen(rows3)
		check("layout 3: drie rijen", kn3.size() == 3)
		var overflow3 := await _scroll_inhoud_overflow(scroll3, rows3)
		check("layout 3: geen scroll nodig", not overflow3)
		check("layout 3: scroll offset 0", scroll3.scroll_vertical <= 0.5)
	layer3.queue_free()
	await get_tree().process_frame

	var vier: Array[String] = basis.duplicate()
	vier.append(LOBBY)
	var open_4: Array = _open_wm1_plaatsen(vier)
	var layer4: Node = open_4[0]
	var view4: Control = open_4[1]
	await _naar_plaatsen_step(view4)
	var scroll4 := view4.find_child("RijenScroll", true, false) as ScrollContainer
	var rows4 := view4.find_child("Rijen", true, false) as VBoxContainer
	check("layout 4: ScrollContainer", scroll4 != null and rows4 != null)
	if scroll4 == null or rows4 == null:
		layer4.queue_free()
		return
	var kn4 := _rij_knoppen(rows4)
	check("layout 4: vier rijen", kn4.size() == 4)
	var overflow4 := await _scroll_inhoud_overflow(scroll4, rows4)
	check("layout 4: scroll nodig", overflow4)
	for kn in kn4:
		check("layout 4: %s binnen scroll-tree" % kn.name, _binnen_scroll(scroll4, kn))
		check(
			"layout 4: %s mouse_filter stop" % kn.name,
			kn.mouse_filter == Control.MOUSE_FILTER_STOP,
		)
	var laatste := kn4[kn4.size() - 1]
	scroll4.scroll_vertical = 0
	await get_tree().process_frame
	check("layout 4: rij 4 niet volledig zichtbaar bij scroll 0", not _volledig_in_scroll(scroll4, laatste))
	scroll4.ensure_control_visible(laatste)
	for _i in 4:
		await get_tree().process_frame
	check("layout 4: rij 4 bereikbaar na ensure_control_visible", _rij_zichtbaar_in_scroll(scroll4, laatste))
	var bar4 := scroll4.get_v_scroll_bar()
	check("layout 4: verticale scroll actief", bar4 != null and bar4.max_value > 0.5)
	kn4[0].grab_focus()
	await get_tree().process_frame
	check("layout 4: focus start rij 1", get_viewport().gui_get_focus_owner() == kn4[0])
	for i in range(1, kn4.size()):
		_parse_ui_down()
		await get_tree().process_frame
		check("layout 4: focus rij %d" % (i + 1), get_viewport().gui_get_focus_owner() == kn4[i])
	layer4.queue_free()
	UiTouchC.insets_override = null


func _save_roundtrip() -> void:
	GameState.new_game("Dax")
	GameState.bezochte_kaarten = [WORLD, LOBBY]
	var snap := GameState.state_data(Vector2i(1, 1), Vector2i.DOWN, WORLD)
	GameState.bezochte_kaarten = []
	check("roundtrip: serialize niet leeg", snap.has("bezocht") and (snap["bezocht"] as Array).has(LOBBY))
	var ok := GameState.apply_state(snap)
	check("roundtrip: apply_state", ok)
	check("roundtrip: lobby in bezochte_kaarten", GameState.bezochte_kaarten.has(LOBBY))
	var na_laden: Array[Dictionary] = Destinations.places(Destinations.WM1)
	check(
		"roundtrip: Colosseum in WM1 places",
		not _plaats_voor_id(na_laden, Destinations.PLACE_COLOSSEUM).is_empty(),
	)


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
