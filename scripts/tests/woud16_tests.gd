extends Node
## WM1 T2 Woud 16px + STAM_VAR (--woud16test): JSON-paden, stripbreedte, stamvarianten.
## Start: godot --path . -- --woud16test [--shots=/pad/map]
## Zit niet in de export (scripts/tests/*).

const Beek := preload("res://scripts/data/woud_beek.gd")
const WOUD16 := "res://assets/tiles/woud16/"
const VERWACHT_STAM: Array[int] = [2, 0, 1, 0, 2, 1, 1, 2, 2, 2, 1, 1, 1, 1, 0, 1, 2, 1, 1, 2, 1, 0, 1, 2, 2, 1]

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_bestanden()
	_stroken()
	_stam_var()
	_kolom_gelijk()
	_kaart_shot()
	print("WOUD16TEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _bestanden() -> void:
	var fout: Array[String] = []
	for r in WoudTegelsData.tegels():
		var pad := str(r.get("file", ""))
		if pad == "" or not ResourceLoader.exists(pad) or not FileAccess.file_exists(pad):
			fout.append("%s: %s" % [r.get("naam", "?"), pad])
	check("elke JSON-file bestaat (%d tegels, %d fout)" % [WoudTegelsData.tegels().size(), fout.size()],
			fout.is_empty() and WoudTegelsData.tegels().size() >= 96)
	var niet_woud16: Array = WoudTegelsData.tegels().filter(func(r): return not str(r.get("file", "")).begins_with(WOUD16))
	check("mapping wijst naar %s (niet-woud16: %s)" % [WOUD16, niet_woud16.map(func(r): return r["naam"])],
			niet_woud16.is_empty())


func _stroken() -> void:
	var fout: Array[String] = []
	var strips := 0
	for r in WoudTegelsData.tegels():
		var pad := str(r.get("file", ""))
		var tex: Texture2D = load(pad) if ResourceLoader.exists(pad) else null
		var frames := maxi(1, int(r.get("frames", 1)))
		if tex == null:
			fout.append("%s: geen texture" % r.get("naam", "?"))
			continue
		if tex.get_width() != frames * 16 or tex.get_height() != 16:
			fout.append("%s: %dx%d (verwacht %dx16)" % [r.get("naam", "?"), tex.get_width(), tex.get_height(), frames * 16])
		if frames > 1:
			strips += 1
	check("stripbreedte = frames x 16 (%d stroken, fout: %s)" % [strips, fout], fout.is_empty() and strips == 15)
	var ts := WoudTegelsData.tileset()
	var anim_ok := true
	for r in WoudTegelsData.tegels():
		var frames := maxi(1, int(r.get("frames", 1)))
		var src := ts.get_source(int(r["id"])) as TileSetAtlasSource
		if src == null:
			anim_ok = false
			continue
		if frames > 1 and src.get_tile_animation_frames_count(Vector2i.ZERO) != frames:
			anim_ok = false
	check("stroken zijn geanimeerde atlas-tegels (15x frames>1)", anim_ok)


func _stam_index(x: int) -> int:
	var hv := absi(((x * 73856093) ^ 19349663) * 83492791)
	return hv % Beek.STAM_VAR.size()


func _stam_var() -> void:
	var reeks: Array[int] = []
	for x in VERWACHT_STAM.size():
		reeks.append(_stam_index(x))
	check("STAM_VAR x=0..25 = %s" % [VERWACHT_STAM], reeks == VERWACHT_STAM)
	check("STAM_VAR heeft 3 suffixen (basis, _b, _c)", Beek.STAM_VAR == ["", "_b", "_c"])
	var namen_ok := true
	for x in range(2, 24):
		var boven := Beek.grond_naam(Vector2i(x, 1))
		var idx := _stam_index(x)
		var suffix := str(Beek.STAM_VAR[idx])
		if not boven.begins_with("rand_stam_") or not boven.ends_with(suffix):
			namen_ok = false
	check("grond_naam hangt STAM_VAR-suffix aan rand_stam_*", namen_ok)


func _kolom_gelijk() -> void:
	var ongelijk: Array[int] = []
	for x in str(Beek.LAYOUT[0]).length():
		var boven := Beek.grond_naam(Vector2i(x, 1))
		var onder := Beek.grond_naam(Vector2i(x, 2))
		if not boven.begins_with("rand_stam_") or not onder.begins_with("rand_stam_"):
			continue
		var sb := "" if not (boven.ends_with("_b") or boven.ends_with("_c")) else boven.substr(boven.length() - 2, 2)
		var so := "" if not (onder.ends_with("_b") or onder.ends_with("_c")) else onder.substr(onder.length() - 2, 2)
		if sb != so:
			ongelijk.append(x)
	check("boven- en onderrij dezelfde variant per kolom %s" % [ongelijk], ongelijk.is_empty())


func _kaart_shot() -> void:
	if shots == "":
		return
	var lagen: Dictionary = Beek.lagen()
	var w := str(Beek.LAYOUT[0]).length()
	var h: int = Beek.LAYOUT.size()
	var img := Image.create(w * 16, h * 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.02, 0.025, 1))
	for laag in ["grond", "overlay"]:
		for t in lagen[laag]:
			var r: Dictionary = WoudTegelsData.tegel(str(lagen[laag][t]))
			var pad := str(r.get("file", ""))
			var tex: Texture2D = load(pad) if ResourceLoader.exists(pad) else null
			if tex == null:
				continue
			var src: Image = tex.get_image()
			if src == null:
				continue
			if src.get_format() != Image.FORMAT_RGBA8:
				src.convert(Image.FORMAT_RGBA8)
			img.blend_rect(src, Rect2i(0, 0, 16, 16), Vector2i(t) * 16)
	DirAccess.make_dir_recursive_absolute(shots)
	var big := img.duplicate()
	big.resize(w * 64, h * 64, Image.INTERPOLATE_NEAREST)
	var pad_out := shots.path_join("woud_beek_4x.png")
	big.save_png(pad_out)
	print("INFO  screenshot: ", pad_out, " ", big.get_size())


func _wacht(cond: Callable, sec: float) -> void:
	var eind := Time.get_ticks_msec() + int(sec * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < eind:
		await get_tree().process_frame
