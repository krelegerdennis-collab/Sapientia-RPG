extends Node
## Hanger-gloed is paars. De zin over de Stroom blijft roze.
## Start: godot --path . -- --hangertest

const Dreiging := preload("res://world_warper/cutscene/dreiging.gd")
const HangerScene := preload("res://world_warper/cutscene/hanger_scene.tscn")

const Accent := preload("res://world_warper/art/accent.gd")
const ROZE := Color("e2789e")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	var regels: Array[String] = Dreiging.lines()
	var ah := regels.find("ECHO: ...Ah.")
	check("Hanger gloeit op ECHO's '...Ah' (beat 2)", ah > 0 and Dreiging.beat_at(ah) == 2)
	var scene := HangerScene.instantiate() as WorldWarperHangerScene
	add_child(scene)
	await get_tree().process_frame
	scene._beat_gloed()
	check("Hanger-gloed is paars", scene.hanger.color == WorldWarperHangerScene.PURPLE
			and scene.hanger.color != ROZE)
	check("gloed-modulate is niet roze", scene.hanger.modulate != Color(0.85, 0.45, 0.6, 1))
	check("gloed = hanger_gloed.png (64x16, 4 frames), paarse vlak verborgen", scene.gloed != null and scene.gloed.visible
			and (scene.gloed.texture as AtlasTexture).atlas.get_size() == Vector2(64, 16)
			and is_zero_approx(scene.hanger.self_modulate.a))
	var frames := {}
	for _i in 60:
		frames[scene.gloed_frame] = true
		await get_tree().process_frame
		await get_tree().create_timer(0.02).timeout
	check("gloed loopt door de 4 frames (%s)" % [frames.keys()], frames.size() == Accent.HANGER_FRAMES)
	scene._beat_restore()
	check("na de gloed weer het vlak, geen plaatje", not scene.gloed.visible and is_equal_approx(scene.hanger.self_modulate.a, 1.0))
	check("herstel blijft paars", scene.hanger.color == Color(0.72, 0.55, 0.95, 1)
			and scene.hanger.color != Color(0.95, 0.72, 0.8, 1))
	scene._beat_purple()
	check("stille hal houdt de Hanger metaal", scene.hanger.color == WorldWarperHangerScene.METAL)
	scene._beat_threat()
	check("Sapientia: roze glitch-silhouet (sapientia_glitch.png) in beat 3", scene.sapientia != null
			and scene.sapientia.visible and scene.sapientia.texture.get_size() == Vector2(48, 48)
			and scene.sapientia.modulate.r > 0.9 and scene.sapientia.modulate.g < 0.6
			and scene.flicker.color == WorldWarperHangerScene.FLITS_ROZE)
	scene._beat_restore()
	check("na herstel geen roze meer", not scene.sapientia.visible)
	scene.queue_free()
	await _canon_tests()
	_accent_tests()
	await _knop_tests()
	print("HANGERTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


## Canon-scènes 2+3 spelen één keer, zetten de vlaggen en zijn save-veilig.
func _canon_tests() -> void:
	var bron := Node.new()
	bron.set_script(_vlaggen_script())
	add_child(bron)
	var sc := HangerScene.instantiate() as WorldWarperHangerScene
	add_child(sc)
	await get_tree().process_frame
	sc.maybe_play(bron)
	await get_tree().process_frame
	var n := Dreiging.lines().size()
	check("Hal-scène start met de eerste canon-regel", sc._playing and sc.text_label.text == "Noor: We're... inside?")
	var hanger_vlag_tijdig := false
	for i in n:
		if i == Canon.HANGER.size():
			hanger_vlag_tijdig = bool(bron.story_flags.get(Canon.FLAG_HANGER, false))
			check("scène 3 begint met Sapientia", sc.text_label.text == "Sapientia: ECHO. You found him."
					and sc.sapientia.visible)
		sc._advance()
	check("vlag scène 2 na de laatste Hanger-regel", hanger_vlag_tijdig)
	check("na afloop: vlaggen gezet, scène dicht", not sc._playing and not sc.layer.visible
			and bool(bron.story_flags.get(Canon.FLAG_DREIGING, false))
			and bool(bron.story_flags.get(Dreiging.FLAG, false)))
	sc.queue_free()
	var nog := HangerScene.instantiate() as WorldWarperHangerScene
	add_child(nog)
	await get_tree().process_frame
	nog.maybe_play(bron)
	await get_tree().process_frame
	check("tweede bezoek: speelt niet opnieuw", not nog._playing and not nog.layer.visible)
	nog.queue_free()
	# Save-veilig: scène 2 gezien, afgesloten vóór scène 3 -> alleen scène 3.
	bron.story_flags = {Canon.FLAG_HANGER: true}
	var half := HangerScene.instantiate() as WorldWarperHangerScene
	add_child(half)
	await get_tree().process_frame
	half.maybe_play(bron)
	await get_tree().process_frame
	check("halve save: alleen scène 3", half._playing and half.text_label.text == "Sapientia: ECHO. You found him."
			and half._lines.size() == Canon.DREIGING.size())
	await _shot("canon_hal_dreiging")
	half.queue_free()
	bron.queue_free()


func _vlaggen_script() -> GDScript:
	var g := GDScript.new()
	g.source_code = "extends Node\nvar story_flags: Dictionary = {}\n"
	g.reload()
	return g


func _shot(naam: String) -> void:
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			dir = arg.get_slice("=", 1)
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(naam + ".png"))


## v0.21 World Warper-accent per Archief (world_warper/art/accent.gd).
func _accent_tests() -> void:
	var want := {1: "", 2: "groen", 3: "oranje", 4: "roze", 5: "blauw", 6: "rood"}
	check("zes accenten", Accent.ACCENTS == want)
	var ok := true
	for base in Accent.MET_ACCENT:
		var grijs: Texture2D = load(base)
		for n in want:
			var p := Accent.path(base, n)
			var t: Texture2D = load(p)
			ok = ok and t != null and grijs != null and t.get_size() == grijs.get_size()
			ok = ok and (p == base) == (n == 1) and Accent.base_of(p) == base
	check("elk Warper-bestand heeft 5 varianten met dezelfde maat", ok)
	check("geen varianten voor sapientia_glitch en hanger_gloed",
			Accent.path("res://assets/sprites/archief2/sapientia_glitch.png", 2) == "res://assets/sprites/archief2/sapientia_glitch.png"
			and Accent.path(Accent.HANGER_GLOED, 3) == Accent.HANGER_GLOED)
	check("Archief 1 grijs, na De Genezer groen, vlag wint", Accent.archief_for({}) == 1
			and Accent.archief_for({Accent.BEWAKERS[2]: true}) == 2 and Accent.archief_for({Accent.FLAG: 5}) == 5)
	var root := Node2D.new()
	var spr := Sprite2D.new()
	spr.texture = load("res://world_warper/art/pc.png")
	root.add_child(spr)
	var tm := TileMapLayer.new()
	tm.tile_set = load("res://world_warper/art/tiles.tres")
	root.add_child(tm)
	var andere := Sprite2D.new()
	andere.texture = load("res://assets/sprites/archief2/sapientia_glitch.png")
	root.add_child(andere)
	var n := Accent.apply_to(root, 4)
	var src := tm.tile_set.get_source(tm.tile_set.get_source_id(0)) as TileSetAtlasSource
	check("apply_to: sprite + tegels naar roze, de rest blijft (%d)" % n, n == 2
			and spr.texture.resource_path.ends_with("pc_roze.png")
			and src.texture.resource_path.ends_with("tiles_roze.png")
			and andere.texture.resource_path.ends_with("sapientia_glitch.png"))
	var gedeeld := load("res://world_warper/art/tiles.tres") as TileSet
	var gsrc := gedeeld.get_source(gedeeld.get_source_id(0)) as TileSetAtlasSource
	check("de gedeelde tileset blijft grijs", gsrc.texture.resource_path.ends_with("tiles.png"))
	Accent.apply_to(root, 1)
	check("terug naar grijs", spr.texture.resource_path.ends_with("pc.png"))
	root.free()


## v0.21 wereldkaart-knoppen (art_batch8_v21) in warp_view.gd.
func _knop_tests() -> void:
	var view := (load("res://world_warper/warp/warp_view.tscn") as PackedScene).instantiate()
	add_child(view)
	await get_tree().process_frame
	view.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true
	for id in ["WM1", "WM2", "WM3"]:
		var k := view.find_child("Rij_%s" % id, true, false) as TextureButton
		ok = ok and k != null and k.texture_normal != null and k.texture_pressed != null
		ok = ok and k.texture_normal.resource_path.ends_with("knop_%s.png" % id.to_lower())
		ok = ok and k.texture_pressed.resource_path.ends_with("knop_%s_ingedrukt.png" % id.to_lower())
		ok = ok and k.custom_minimum_size == Vector2(96, 32)
	check("werelden zijn TextureButtons met knop_wmN / _ingedrukt (2x)", ok)
	var wm1 := view.find_child("Rij_WM1", true, false) as TextureButton
	if wm1 != null and not wm1.disabled:
		wm1.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var dorp := view.find_child("Rij_wilgendal", true, false) as TextureButton
		check("Wilgendal = knop_village", dorp != null and dorp.texture_normal.resource_path.ends_with("knop_village.png")
				and dorp.texture_pressed.resource_path.ends_with("knop_village_ingedrukt.png"))
	view.queue_free()
