extends Node
## Held 24x32 (Forge, 21 okt 2026): op elke map behalve wereldkaart en berggrot_bouwplaats toont de speler
## de 24x32-sheet van de partijleider (slanke WM1-sheet, voeten op +8 = offset (0,-8), botsing 14x14).
## Leiderwissel (molen) ververst de sheet; ontbreekt een _wm1_slim-sheet (Kael/Orion), dan netjes terugvallen.
## Start: godot --path . -- --held24test [--shots=/pad/map]

const MAPS := "res://scenes/maps/"
const OUD := "res://assets/sprites/player.png"
const SomData := preload("res://scripts/data/som_data.gd")

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	get_tree().change_scene_to_file(pad)
	for i in 120:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and i > 4:
			return s
	return null


func _speler(s: Node) -> Node:
	return s.get_node_or_null("Objects/Player") if s else null


func _shot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))


func _run() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	# 1) elke scène
	var fout := ""
	var n := 0
	for f in DirAccess.get_files_at(MAPS):
		if not f.ends_with(".tscn"):
			continue
		var pad := MAPS + f
		var s: Node = await _laad(pad)
		var p := _speler(s)
		if p == null:
			print("INFO  %s: geen Objects/Player, overgeslagen" % f)
			continue
		n += 1
		var sp: Sprite2D = p.sprite
		var col := p.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var col_ok := col == null or not (col.shape is RectangleShape2D) or (col.shape as RectangleShape2D).size == Vector2(14, 14)
		if KaartStijl.held_nieuw_op(pad):
			if not (sp.texture.resource_path.ends_with("dax_wm1_slim.png") and sp.hframes == 3 and sp.vframes == 4
					and sp.offset == Vector2(0, -8) and col_ok):
				fout += "%s (%s, %dx%d, %s); " % [f, sp.texture.resource_path.get_file(), sp.hframes, sp.vframes, sp.offset]
		elif not (sp.texture.resource_path == OUD and sp.offset == Vector2(0, -4) and col_ok):
			fout += "%s oud verwacht (%s); " % [f, sp.texture.resource_path.get_file()]
		await get_tree().process_frame
	check("held 24x32 op alle %d maps met speler, 16x24 alleen op wereldkaart/bouwplaats, botsing 14x14 (%s)" % [n, fout if fout != "" else "ok"],
			fout == "" and n >= 40)
	# 2) screenshots: huis-interieur en een dungeondeur
	var huis: Node = await _laad(MAPS + "huis_wilgendal.tscn")
	await get_tree().create_timer(0.3).timeout
	await _shot("huis_wilgendal_interieur")
	var gang: Node = await _laad(MAPS + "archief_ingang.tscn")
	await get_tree().create_timer(0.3).timeout
	await _shot("archief_ingang_deur")
	check("screenshots geladen (huis + dungeondeur)", huis != null and gang != null)
	# 3) leiderwissel: Dax/Seren/Vesper/Kael/Orion
	var s3: Node = await _laad(MAPS + "huis_wilgendal.tscn")
	var p3 := _speler(s3)
	GameState.party = []
	for naam in ["Dax", "Seren", "Vesper", "Kael", "Orion"]:
		GameState.party.append({"id": naam.to_lower(), "name": naam, "level": 1})
	var wissel_fout := ""
	for i in range(GameState.party.size() - 1, -1, -1):
		var naam := str(GameState.party[i]["name"])
		GameState.move_member_to_front(i)
		var verwacht := KaartStijl.held_sheet(naam)
		var slank := "res://assets/sprites/som/kaart/%s_wm1_slim.png" % naam.to_lower()
		if not ResourceLoader.exists(slank):
			print("INFO  %s: %s ontbreekt nog (RPG ART), terugval = %s" % [naam, slank.get_file(), verwacht if verwacht != "" else "oude sheet"])
		var tex: String = p3.sprite.texture.resource_path
		var ok := tex == slank and verwacht == slank and p3.sprite.offset == Vector2(0, -8) and p3.sprite.hframes == 3 and p3.sprite.vframes == 4
		if not ok:
			wissel_fout += "%s -> %s (verwacht %s); " % [naam, tex.get_file(), verwacht.get_file()]
	check("leiderwissel: alle 5 helden (Dax/Seren/Vesper/Kael/Orion) krijgen hun _wm1_slim-sheet (%s)" % (wissel_fout if wissel_fout != "" else "ok"), wissel_fout == "")
	check("alle 5 helden hebben een slanke WM1-sheet (72x128)", ["dax", "seren", "vesper", "kael", "orion"].all(func(h):
			var t: Texture2D = load("res://assets/sprites/som/kaart/%s_wm1_slim.png" % h)
			return t != null and t.get_size() == Vector2(72, 128)))
	# terugval zonder sheet: onbekende held -> "" (speler houdt zijn huidige sheet)
	check("terugval: held zonder sheet geeft geen pad", KaartStijl.held_sheet("Onbekend") == "")
	check("SomData.SHEETS wijst naar de _wm1_slim-sheets", SomData.SHEETS.values().all(func(v): return str(v).ends_with("_wm1_slim.png")))
	GameState.new_game("Dax")
	print("HELD24TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
