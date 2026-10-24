extends Node
## Prestatiewerk WM1 (--perfwm1test): het gedrag blijft gelijk, alleen sneller.
##  1. Voorladen: fasen (wachten op eerste beeld, scripts één per frame, loads aanvragen) en prewarm in rustige schermen.
##  2. Saves: stempel en 'Doorgaan' lezen een save niet meer dubbel, uitkomsten identiek.
##  3. Dorp Wilgendal: snelle raster-/lazy-tegel-paden geven exact dezelfde grond als de oorspronkelijke functies.
## Start: godot --path . -- --perfwm1test [--shots=/pad/map]
## (De tijden zelf meet tools/perf/run_perf_wm1.sh; dit bestand test alleen dat niets van gedrag veranderd is.)

const Ground := preload("res://scripts/village/dorp_ground.gd")
const Data := preload("res://scripts/data/wilgendal_dorp.gd")
const Opbouw := preload("res://scripts/village/dorp_opbouw.gd")
const DORP := "res://scenes/maps/dorp_wilgendal.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"

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
	await get_tree().process_frame
	await _voorladen()
	_saves()
	await _titel()
	await _dorp()
	print("PERFWM1TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- 1. voorladen
func _voorladen() -> void:
	# testmodus: GameState heeft alles al afgemaakt (_finish_preload) en geen prewarm gepland
	check("testmodus: scripts-wachtrij leeg, fase 2", GameState._script_queue.is_empty() and GameState._preload_phase == 2)
	check("testmodus: geen prewarm in de tests", GameState._prewarm_queue.is_empty())
	var ok := true
	for sp in GameState.MAIN_THREAD_SCRIPTS:
		ok = ok and ResourceLoader.exists(sp)
	check("alle MAIN_THREAD_SCRIPTS bestaan", ok)
	ok = true
	var uniek := {}
	for sp in GameState.PREWARM_SCRIPTS:
		ok = ok and ResourceLoader.exists(sp) and not uniek.has(sp)
		uniek[sp] = true
	check("alle %d PREWARM_SCRIPTS bestaan, geen dubbelen" % GameState.PREWARM_SCRIPTS.size(), ok)
	check("PREWARM_SCENES = titel + naam invoeren", GameState.PREWARM_SCENES == [GameState.TITLE_SCENE, GameState.NAME_SCENE])

	# Fasen-machine: eerst FRAMES_BEFORE_PRELOAD frames niets, dan één script per frame, dan fase 2.
	var scripts := GameState.MAIN_THREAD_SCRIPTS.size()
	GameState._preload_phase = 0
	GameState._preload_frames = 0
	GameState._script_queue.assign(GameState.MAIN_THREAD_SCRIPTS)
	GameState._process(0.0)
	check("fase 0: eerste frame wacht (titelscherm eerst laten tekenen)", GameState._preload_phase == 0
			and GameState._script_queue.size() == scripts)
	GameState._process(0.0)
	check("fase 1 vanaf frame %d: één script gecompileerd" % GameState.FRAMES_BEFORE_PRELOAD,
			GameState._preload_phase == 1 and GameState._script_queue.size() == scripts - 1)
	GameState._process(0.0)
	check("fase 1: precies één script per frame", GameState._script_queue.size() == scripts - 2)
	var frames := 0
	while GameState._preload_phase < 2 and frames < scripts + 5:
		GameState._process(0.0)
		frames += 1
	check("fase 2 bereikt, wachtrij leeg", GameState._preload_phase == 2 and GameState._script_queue.is_empty())
	check("fase 2: geen openstaande threaded loads (alles stond al klaar)", GameState._preloading.is_empty())

	# Prewarm: alleen in titel / naam invoeren, nooit tijdens een wissel of gevecht.
	var pad: String = GameState.PREWARM_SCRIPTS[0]
	GameState._loaded.erase(pad)
	GameState._prewarm_queue.assign([pad])
	GameState._prewarm_wait = 0.0
	GameState._go_to_scene(WERELD)
	for i in 6:
		await get_tree().process_frame
	GameState._prewarm_step(1.0)
	check("prewarm: niet buiten het titelscherm", GameState._prewarm_queue.size() == 1 and not GameState._loaded.has(pad))
	GameState._go_to_scene(GameState.TITLE_SCENE)
	for i in 6:
		await get_tree().process_frame
	GameState.changing_map = true
	GameState._prewarm_step(1.0)
	check("prewarm: niet tijdens een kaartwissel", GameState._prewarm_queue.size() == 1)
	GameState.changing_map = false
	GameState.in_battle = true
	GameState._prewarm_step(1.0)
	check("prewarm: niet tijdens een gevecht", GameState._prewarm_queue.size() == 1)
	GameState.in_battle = false
	GameState._prewarm_wait = 0.5
	GameState._prewarm_step(0.1)
	check("prewarm: wacht PREWARM_GAP af", GameState._prewarm_queue.size() == 1)
	GameState._prewarm_wait = 0.0
	GameState._prewarm_step(0.1)
	check("prewarm: op het titelscherm wordt het script geladen en bewaard", GameState._prewarm_queue.is_empty()
			and GameState._loaded.get(pad) is GDScript)
	check("prewarm: wachttijd teruggezet op PREWARM_GAP", is_equal_approx(GameState._prewarm_wait, GameState.PREWARM_GAP))
	GameState._finish_preload()
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- 2. saves
func _saves() -> void:
	GameState.use_story_saves()
	GameState.new_game("Dax")
	GameState.current_map = WERELD
	GameState.gold = 321
	for slot in [1, 2]:
		GameState.active_slot = slot
		GameState.save_game(Vector2i(7, 8), Vector2i.UP)
	GameState.active_slot = 1
	var p1 := GameState.slot_path(1)
	var rec := GameState.slot_record(1)
	check("slot_record: stempel = _save_stamp (zelfde bestand, één parse)", float(rec["stamp"]) == GameState._save_stamp(p1))
	check("slot_record: data = read_save", JSON.stringify(rec["data"]) == JSON.stringify(GameState.read_save(p1)))
	var d := GameState.read_save(p1)
	d.erase("saved_unix")
	check("_stamp_of zonder saved_unix: bestandstijd", GameState._stamp_of(d, p1) == GameState._save_modified_time(p1))
	var nw := GameState.newest_slot_record()
	check("newest_slot_record: kiest een gevulde slot", not nw.is_empty() and int(nw["slot"]) in [1, 2])
	check("has_any_save blijft kloppen", GameState.has_any_save() == (GameState.newest_save_path() != ""))

	GameState.gold = 0
	check("load_game(pad) laadt", GameState.load_game(p1) and GameState.gold == 321)
	var na_pad := JSON.stringify(GameState.state_data(Vector2i(7, 8), Vector2i.UP))
	GameState.gold = 0
	check("load_game(pad, gelezen) laadt hetzelfde", GameState.load_game(p1, GameState.read_save(p1)) and GameState.gold == 321)
	var na_data := JSON.stringify(GameState.state_data(Vector2i(7, 8), Vector2i.UP))
	check("load_game met voorgelezen data = zelfde toestand", na_pad == na_data)
	check("load_game(pad, {}) valt terug op lezen", GameState.load_game(p1, {}) and GameState.gold == 321)
	check("load_game zonder bestand blijft false", not GameState.load_game("user://bestaat_niet_perfwm1.json", {}))


func _titel() -> void:
	# Titelscherm: Doorgaan aan met de nieuwste save, info uit hetzelfde record.
	GameState.use_story_saves()
	var titel: Control = (load(GameState.TITLE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(titel)
	await get_tree().process_frame
	var nw := GameState.newest_slot_record()
	var d: Dictionary = nw.get("data", {})
	check("titel: Doorgaan aan met een save", not titel.continue_button.disabled and not titel.load_button.disabled)
	check("titel: save-info toont de naam uit de nieuwste save",
			titel.save_info.visible and titel.save_info.text.contains(str(d.get("player_name", "?"))))
	titel.queue_free()
	await get_tree().process_frame
	# zonder saves
	var oud_pad := GameState.save_path
	var oud_auto := GameState.autosave_path
	GameState.save_path = "user://perfwm1_leeg_save_1.json"
	GameState.autosave_path = "user://perfwm1_leeg_autosave.json"
	var leeg: Control = (load(GameState.TITLE_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(leeg)
	await get_tree().process_frame
	check("titel zonder saves: Doorgaan en Laden uit, geen info", leeg.continue_button.disabled and leeg.load_button.disabled
			and not leeg.save_info.visible)
	leeg.queue_free()
	await get_tree().process_frame
	GameState.save_path = oud_pad
	GameState.autosave_path = oud_auto


# ---------------------------------------------------------------- 3. dorp
func _dorp() -> void:
	GameState.new_game("Dax")
	GameState.pending_spawn = "zuid_ingang"
	var a: Node = (load(DORP) as PackedScene).instantiate()
	get_tree().root.add_child(a)
	await get_tree().process_frame
	await get_tree().process_frame
	var g: TileMapLayer = a.get_node("Ground")
	var v8: TileMapLayer = g.get_node_or_null("SomV8")
	check("dorp: SoM-stijl actief, v8-laag aanwezig", v8 != null)
	if v8 == null:
		a.queue_free()
		return

	# 3a. raster == oorspronkelijke string-functies, voor alle cellen
	var r := Ground._grond_raster()
	var pad_set := Ground._set_van(Ground.PAD)
	var water_set := Ground._set_van(Ground.WATER)
	var fout_masker := 0
	var fout_zoom := 0
	var lay := Data.p10_layout()
	var blok := Rect2i(int(lay["ox"]), int(lay["oy"]), int(lay["w"]), int(lay["h"]))
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			if Ground._masker_r(r, x, y, pad_set) != Ground.masker(t, Ground.PAD):
				fout_masker += 1
			if Ground._masker_r(r, x, y, water_set) != Ground.masker(t, Ground.WATER):
				fout_masker += 1
			var snel: bool = not blok.has_point(t) and ".TFG=#B".contains(char(r[y * Data.W + x])) and Ground._buur_is_pad(r, x, y, pad_set)
			if snel != Ground.pad_zoom(t, blok):
				fout_zoom += 1
	check("raster: blob47-masker identiek aan masker() voor alle %d cellen" % (Data.W * Data.H), fout_masker == 0)
	check("raster: pad-zoom identiek aan pad_zoom() voor alle cellen", fout_zoom == 0)

	# 3b. de v8-laag: elke cel = wat de oorspronkelijke lus zou zetten, en de tegel bestaat in zijn bron
	var d = JSON.parse_string(FileAccess.get_file_as_string(Ground.V8_JSON))
	var cellen: Array = d["cellen"]
	var kol := int(d["kolommen"])
	var licht_kol := (load(Ground.GRAS_LICHT) as Texture2D).get_width() / 16
	var fout_cel := 0
	var fout_bestaat := 0
	var verwacht_aantal := 0
	for y in Data.H:
		for x in Data.W:
			var t := Vector2i(x, y)
			var bron := v8.get_cell_source_id(t)
			if Data.GROND[y][x] == "~":
				if bron != -1:
					fout_cel += 1
				continue
			verwacht_aantal += 1
			var want_bron := 0
			var want_atlas := Vector2i.ZERO
			var j := int(cellen[y * Data.W + x])
			if Ground.pad_zoom(t, blok):
				want_bron = 2
				want_atlas = Vector2i(j % kol, j / kol)
			elif Ground.gras_licht_hier(t, blok):
				want_bron = 1
				want_atlas = Vector2i(Data.p10_hash(t) % licht_kol, 0)
			else:
				want_atlas = Vector2i(j % kol, j / kol)
			if bron != want_bron or v8.get_cell_atlas_coords(t) != want_atlas:
				fout_cel += 1
			var src := v8.tile_set.get_source(bron) as TileSetAtlasSource if bron >= 0 else null
			if src == null or not src.has_tile(want_atlas):
				fout_bestaat += 1
	check("v8-laag: elke cel heeft dezelfde bron en tegel als de oorspronkelijke lus", fout_cel == 0)
	check("v8-laag: elke gebruikte tegel bestaat in zijn atlas (lazy aangemaakt)", fout_bestaat == 0)
	check("v8-laag: %d cellen (alles behalve water)" % verwacht_aantal, v8.get_used_cells().size() == verwacht_aantal)
	var bron0 := v8.tile_set.get_source(0) as TileSetAtlasSource
	check("v8-laag: lazy atlas heeft minder tegels dan 'uniek' (%d < %d)" % [bron0.get_tiles_count(), int(d["uniek"])],
			bron0.get_tiles_count() < int(d["uniek"]))
	check("v8-laag: bronnen 0, 1, 2 in vaste volgorde", v8.tile_set.get_source_count() == 3
			and v8.tile_set.get_source_id(0) == 0 and v8.tile_set.get_source_id(1) == 1 and v8.tile_set.get_source_id(2) == 2)

	# 3c. plein-tileset: tweede bezoek hergebruikt de gecachte set; v8-set wordt per bezoek vers opgebouwd
	var grond_a: TileMapLayer = a.get_node("Ground/Plein10/Grond/GrondTegels")
	var ts_a := grond_a.tile_set
	var cellen_a := grond_a.get_used_cells().size()
	var v8_ts_a := v8.tile_set
	a.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.changing_map = false
	GameState.pending_spawn = "zuid_ingang"
	var b2: Node = (load(DORP) as PackedScene).instantiate()
	get_tree().root.add_child(b2)
	await get_tree().process_frame
	var grond_b: TileMapLayer = b2.get_node("Ground/Plein10/Grond/GrondTegels")
	check("plein-tileset: tweede bezoek hergebruikt de gecachte TileSet", grond_b.tile_set == ts_a)
	check("plein-tileset: nog steeds alle tegels aanwezig (%d)" % (grond_b.tile_set.get_source(0) as TileSetAtlasSource).get_tiles_count(),
			(grond_b.tile_set.get_source(0) as TileSetAtlasSource).get_tiles_count() >= 1200)
	check("v8-tileset (grote textuur) wordt niet in een cache vastgehouden", b2.get_node("Ground/SomV8").tile_set != v8_ts_a)
	check("plein-grond: zelfde aantal cellen bij tweede bezoek (%d)" % cellen_a, grond_b.get_used_cells().size() == cellen_a)
	b2.queue_free()
	await get_tree().process_frame
