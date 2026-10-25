extends Node
## Geheugen-maatregelen voor WM1 (headless): AtlasZuinig, BGM-cache van AudioManager, party-only sheets in SomArena,
## en de aannames waar het pixel-perfecte beeld op rust (Nearest, 1:1 gesnapte viewport, geen camerazoom).
## Start:  godot --rendering-driver opengl3 --path . res://tools/geheugen/geheugen_tests.tscn
## (xvfb-run op Linux zonder scherm). Zelfde PASS/FAIL/RESULT-formaat als de suites in scripts/tests/.
## Staat bewust niet in de dispatch van game_state.gd (die wordt door meer branches aangepast): zie PR.

const WM1Meting := preload("res://tools/geheugen/wm1_meting.gd")
const GANG := "res://scenes/maps/archief_v1_gang.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: klaar binnen 300 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await get_tree().process_frame
	print("=== Deel A: AtlasZuinig ===")
	_atlas_tests()
	print("=== Deel B: aannames pixel-perfect ===")
	_aannames_tests()
	print("=== Deel C: alle WM1-kaarten zonder opgevulde atlas, geen zoom ===")
	await _kaarten_tests()
	print("=== Deel D: BGM-cache AudioManager ===")
	_audio_tests()
	print("=== Deel E: SomArena laadt alleen party-sheets ===")
	await _som_tests()
	print("GEHEUGENTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _atlas_tests() -> void:
	var tex := ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	for id in 2:
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)
		ts.add_source(src, id)
	var ts2 := TileSet.new()
	var s3 := TileSetAtlasSource.new()
	s3.texture = tex
	ts2.add_source(s3, 0)
	check("Godot-standaard: padding staat aan (reden van het extra geheugen)",
			(ts.get_source(0) as TileSetAtlasSource).use_texture_padding)
	var wortel := Node2D.new()
	var l1 := TileMapLayer.new()
	l1.tile_set = ts
	var l2 := TileMapLayer.new()
	l2.tile_set = ts          # zelfde TileSet: telt een keer
	var l3 := TileMapLayer.new()
	l3.tile_set = ts2
	var kind := Node2D.new()
	kind.add_child(l3)
	wortel.add_child(l1)
	wortel.add_child(l2)
	wortel.add_child(kind)
	var n := AtlasZuinig.toepassen(wortel)
	check("toepassen: 3 atlasbronnen veranderd (gedeeld TileSet telt een keer), kreeg %d" % n, n == 3)
	check("padding uit op bron 0 en 1", not (ts.get_source(0) as TileSetAtlasSource).use_texture_padding
			and not (ts.get_source(1) as TileSetAtlasSource).use_texture_padding)
	check("padding uit op de bron van het diepe kind", not (ts2.get_source(0) as TileSetAtlasSource).use_texture_padding)
	check("tweede keer: niets meer te doen", AtlasZuinig.toepassen(wortel) == 0)
	check("tileset_zuinig op een leeg TileSet: 0", AtlasZuinig.tileset_zuinig(TileSet.new()) == 0)
	check("toepassen op een boom zonder tegels: 0", AtlasZuinig.toepassen(Node.new()) == 0)
	wortel.free()


## De padding weglaten is alleen veilig als elke texel op precies een schermpixel valt.
func _aannames_tests() -> void:
	check("standaard textuurfilter = Nearest (0)", int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0)
	check("2D-transformaties snappen naar pixels", bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")))
	check("2D-vertices snappen naar pixels", bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel")))
	check("stretch mode = viewport (kaart wordt op 1:1 getekend, daarna opgeschaald)",
			str(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport")


func _laad_kaart(pad: String) -> Node:
	var packed := GameState.get_resource(pad) as PackedScene
	var kaart := packed.instantiate()
	var oud := get_tree().current_scene
	get_tree().root.add_child(kaart)
	get_tree().current_scene = kaart
	if oud != null and oud != self:
		oud.queue_free()
	for i in 6:
		await get_tree().process_frame
	return kaart


func _ruim_op(kaart: Node) -> void:
	get_tree().current_scene = null
	kaart.queue_free()


func _kaarten_tests() -> void:
	GameState.new_game("Dax")
	GameState.story_flags["cutscene_wereldkaart_gezien"] = true
	var kaarten := WM1Meting.kaarten()
	check("WM1-kaartlijst niet leeg (%d kaarten)" % kaarten.size(), kaarten.size() >= 40)
	var slecht_padding: Array[String] = []
	var slecht_zoom: Array[String] = []
	var bronnen := 0
	for pad in kaarten:
		var kaart := await _laad_kaart(pad)
		var meet := _telling(kaart)
		bronnen += meet["bronnen"]
		if meet["padded"] > 0:
			slecht_padding.append("%s (%d)" % [pad.get_file(), meet["padded"]])
		if meet["zoom"]:
			slecht_zoom.append(pad.get_file())
		_ruim_op(kaart)
		await get_tree().process_frame
	check("alle WM1-kaarten: geen atlasbron met opgevulde kopie %s" % [slecht_padding], slecht_padding.is_empty())
	check("alle WM1-kaarten: geen Camera2D met zoom ongelijk aan 1 %s" % [slecht_zoom], slecht_zoom.is_empty())
	check("er zijn atlasbronnen gecontroleerd (%d)" % bronnen, bronnen > 20)


func _telling(kaart: Node) -> Dictionary:
	var gezien := {}
	var bronnen := 0
	var padded := 0
	var zoom := false
	var stapel: Array[Node] = [kaart]
	while not stapel.is_empty():
		var n: Node = stapel.pop_back()
		stapel.append_array(n.get_children())
		if n is Camera2D and not (n as Camera2D).zoom.is_equal_approx(Vector2.ONE):
			zoom = true
		if not (n is TileMapLayer):
			continue
		var ts := (n as TileMapLayer).tile_set
		if ts == null or gezien.has(ts.get_instance_id()):
			continue
		gezien[ts.get_instance_id()] = true
		for i in ts.get_source_count():
			var src := ts.get_source(ts.get_source_id(i))
			if src is TileSetAtlasSource:
				bronnen += 1
				if (src as TileSetAtlasSource).use_texture_padding:
					padded += 1
	return {"bronnen": bronnen, "padded": padded, "zoom": zoom}


func _audio_tests() -> void:
	var am := AudioManager
	check("BGM_CACHE_MAX = 3", am.BGM_CACHE_MAX == 3)
	var tracks: Array[String] = []
	for naam in am._bgm.keys():
		var pad := str(am._bgm_dir) + str(am._bgm[naam].get("bestand", ""))
		if ResourceLoader.exists(pad):
			tracks.append(str(naam))
	check("er zijn minstens 5 BGM-bestanden om te testen (%d)" % tracks.size(), tracks.size() >= 5)
	var sfx_naam := ""
	for naam in am._sfx.keys():
		var files: Array = am._sfx[naam].get("bestanden", [])
		if not files.is_empty() and ResourceLoader.exists(str(am._sfx_dir) + str(files[0])):
			sfx_naam = str(naam)
			break
	if sfx_naam != "":
		am.preload_sfx([sfx_naam])
	var sfx_voor := _cache_aantal(am, str(am._sfx_dir))
	check("sfx staan in de cache (%d)" % sfx_voor, sfx_voor > 0)
	var laatste := ""
	var max_gezien := 0
	for naam in tracks.slice(0, 5):
		check("play_music('%s') start" % naam, am.play_music(naam, 0.0))
		laatste = naam
		max_gezien = maxi(max_gezien, _cache_aantal(am, str(am._bgm_dir)))
	check("nooit meer dan %d BGM-streams in de cache (max %d)" % [am.BGM_CACHE_MAX, max_gezien], max_gezien <= am.BGM_CACHE_MAX)
	var cur_pad := str(am._bgm_dir) + str(am._bgm[laatste].get("bestand", ""))
	check("de huidige track blijft in de cache", am._stream_cache.has(cur_pad))
	var eerste_pad := str(am._bgm_dir) + str(am._bgm[tracks[0]].get("bestand", ""))
	check("de oudste track is losgelaten", not am._stream_cache.has(eerste_pad))
	check("de sfx-cache is onaangeroerd", _cache_aantal(am, str(am._sfx_dir)) == sfx_voor)
	check("een losgelaten track speelt zo weer (opnieuw laden)", am.play_music(tracks[0], 0.0, true))
	check("... en staat dan weer in de cache", am._stream_cache.has(eerste_pad))
	am.stop_music(0.0)


func _cache_aantal(am: Node, prefix: String) -> int:
	var n := 0
	for k in am._stream_cache.keys():
		if str(k).begins_with(prefix):
			n += 1
	return n


func _som_tests() -> void:
	Settings.set_value("battle_style", 1)
	GameState.new_game("Dax")
	var g := await _laad_kaart(GANG)
	var som: Node = g.som if "som" in g else null
	check("Action-arena actief in %s" % GANG.get_file(), som != null)
	if som == null:
		_ruim_op(g)
		return
	check("alleen Dax' sheets vooraf: %s" % [som.sheets.keys()], som.sheets.keys() == ["dennis"])
	check("alleen Dax' aanvalssheet vooraf: %s" % [som.attack_texs.keys()], som.attack_texs.keys() == ["dennis"])
	var kael: Texture2D = som.sheet_for("kael")
	check("sheet_for('kael') laadt op aanvraag (co-op-peer/swap)", kael != null and som.sheets.has("kael"))
	check("sheet_for('dennis') geeft de vaste Dax-sheet", som.sheet_for("dennis") != null)
	check("onbekende held: null, geen fout", som.sheet_for("bestaat_niet") == null)
	_ruim_op(g)
	await get_tree().process_frame
	GameState.new_game("Dax")
	GameState.add_member("kael")
	var g2 := await _laad_kaart(GANG)
	var som2: Node = g2.som if "som" in g2 else null
	check("Action-arena met Kael in de party", som2 != null)
	if som2 != null:
		check("party-held Kael: kaart- en aanvalssheet vooraf", som2.sheets.has("kael") and som2.attack_texs.has("kael"))
		check("niet-party Orion: nog niet geladen", not som2.sheets.has("orion") and not som2.attack_texs.has("orion"))
	_ruim_op(g2)
	Settings.set_value("battle_style", 0)
