extends Node
## Eenmalige wereldkaart-cutscene + moswezens in de tuin van opa.
## Start: godot --path . -- --cutscenetest [--shots=/pad/map]

const Cutscene := preload("res://scripts/worldmap_cutscene.gd")
const Garden := preload("res://scripts/village/garden_creatures.gd")
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const TUIN := "res://scenes/maps/wilgendal.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	GameState.new_game()
	_statisch()
	await _cutscene()
	await _tuin()
	Cutscene.allow_in_tests = false
	print("CUTSCENETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _statisch() -> void:
	check("video bestaat", ResourceLoader.exists(Cutscene.VIDEO_PATH))
	check("video laadt als VideoStream (Theora)", load(Cutscene.VIDEO_PATH) is VideoStream)
	check("panel-texture (art of placeholder) bestaat", Cutscene.panel_texture() != null)
	check("in tests standaard uit", not Cutscene.should_play(WERELD))
	Cutscene.allow_in_tests = true
	check("nieuwe game: speelt op de wereldkaart", Cutscene.should_play(WERELD))
	check("niet op andere maps", not Cutscene.should_play(TUIN))
	for id in Garden.IDS:
		check("volg-sheet %s 64x96" % id, _maat(Garden.follow_sheet_path(id)) == Vector2i(64, 96))
		check("speel-sheet %s 96x24" % id, _maat(Garden.play_sheet_path(id)) == Vector2i(96, 24))
		check("fallback map-sprite %s" % id, ResourceLoader.exists(Garden.FALLBACK_DIR + id + ".png"))


func _maat(pad: String) -> Vector2i:
	if not ResourceLoader.exists(pad):
		return Vector2i.ZERO
	var t: Texture2D = load(pad)
	return Vector2i(t.get_width(), t.get_height())


func _cutscene() -> void:
	var w := await enter(WERELD, "van_dorp")
	check("wereldkaart geladen", w != null)
	if w == null:
		return
	var c: Node = w.get_node_or_null("WorldmapCutscene")
	check("cutscene gestart bij eerste bezoek", c != null)
	check("vlag gezet", GameState.story_flags.has(Cutscene.FLAG))
	var p: Node = w.get_node_or_null("Objects/Player")
	check("speler op slot tijdens filmpje", p != null and p.input_locked)
	if c != null:
		await get_tree().create_timer(1.5).timeout
		check("panelen links/rechts naast de video", c.left_panel.size.x > 0 and c.right_panel.position.x >= c.video.position.x + c.video.size.x - 0.5)
		check("video portret gecentreerd", absf(c.video.size.x / c.video.size.y - 9.0 / 16.0) < 0.01)
		check("video lineair gefilterd", c.video.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
		check("root op schermresolutie tijdens filmpje", get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
		await screenshot("cutscene_panels")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		check("klik slaat over", not is_instance_valid(c) or c.is_done())
		check("pixel-art-schaal terug na filmpje", get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
	check("speler weer vrij", p != null and not p.input_locked)
	# opslaan, leegmaken, laden: vlag blijft, geen herhaling
	check("opslaan", GameState.save_game(p.get_tile(), p.facing))
	GameState.story_flags.erase(Cutscene.FLAG)
	check("laden", GameState.load_game())
	check("vlag overleeft save/load", GameState.story_flags.has(Cutscene.FLAG))
	check("speelt niet nog eens", not Cutscene.should_play(WERELD))
	var w2 := await enter(TUIN, "zuid_ingang")
	w2 = await enter(WERELD, "van_dorp")
	check("tweede bezoek: geen cutscene", w2 != null and w2.get_node_or_null("WorldmapCutscene") == null)


func _tuin() -> void:
	var t := await enter(TUIN, "start")
	check("tuin geladen", t != null)
	if t == null:
		return
	var g: Node = t.get_node_or_null("Objects/GardenCreatures")
	check("moswezens in de tuin", g != null)
	if g == null:
		return
	check("twee wezens (moslijm + moskonijn)", g.creatures.size() == 2)
	check("echte art (batch 14) geladen", g._uses_art["mosslijm"] and g._uses_art["moskonijn"])
	check("ze spelen", g.mode == Garden.Mode.PLAY)
	var a: Vector2 = g.creatures[0].position
	await get_tree().create_timer(0.6).timeout
	check("ze bewegen om elkaar heen", g.creatures[0].position.distance_to(a) > 1.0)
	await screenshot("garden_creatures")
	var p: Node2D = t.get_node("Objects/Player")
	# loop (gesimuleerd) over het tuinpad naar de uitgang NaarWereld. Erf 1.4x (tools/som/wachtershuis_1p4.py, 45x31):
	# oude route (264,160)->(264,240)->(248,300) omgerekend met X()/Y() uit tools/som/wachtershuis_1p4.py
	# (tuinpad kolom 16->24, rij 10->12, 15->20, 18->26, kolom 15->23). De oude route kwam pas op y=300 net
	# over FOLLOW_TRIGGER_Y (296) en stopte daar, waardoor de wezens vanaf de speelplek (440,232) te laat aankwamen.
	var pad: Array[Vector2] = [Vector2(392, 192), Vector2(392, 320), Vector2(376, 428)]
	check("route kruist de volg-grens ruim (y %d > %d)" % [int(pad[2].y), int(Garden.FOLLOW_TRIGGER_Y)],
			pad[1].y > Garden.FOLLOW_TRIGGER_Y + 16.0 and pad[0].y < Garden.FOLLOW_TRIGGER_Y)
	for doel in pad:
		while p.position.distance_to(doel) > 0.5:
			# loopsnelheid in px/s (zoals player.gd), niet 1 px per frame: onder xvfb zonder vsync liep de speler
			# anders 3-5x te snel en haalden de wezens (CATCH_UP_SPEED 96 px/s) hem niet in (flaky)
			p.position = p.position.move_toward(doel, float(p.walk_speed) * get_process_delta_time())
			await get_tree().process_frame
	check("volgen gestart richting uitgang", g.mode == Garden.Mode.FOLLOW)
	await get_tree().create_timer(1.2).timeout
	var pos: Array[Vector2] = g.creature_positions()
	check("moslijm vlak achter Dax", pos[0].distance_to(p.global_position) < 28.0)
	check("moskonijn daarachter", pos[1].distance_to(p.global_position) < 44.0)
	await screenshot("garden_following")


func enter(pad: String, spawn: String) -> Node:
	if Dialog.is_open:
		Dialog.close()
	GameState.change_map(pad, spawn)
	var naam := ""
	for deel in pad.get_file().get_basename().split("_"):
		naam += deel.capitalize().replace(" ", "")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000.0:
		var s := get_tree().current_scene
		if s != null and s.name == naam and s.is_node_ready() and not GameState.changing_map:
			await get_tree().process_frame
			await get_tree().process_frame
			var f0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - f0 < 3000.0 and Transition._rect.color.a > 0.01:
				await get_tree().process_frame
			return s
		await get_tree().process_frame
	return null


func screenshot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))
