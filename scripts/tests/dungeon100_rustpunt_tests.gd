extends Node
## ALLEEN VOOR TESTEN - rustpunt-sheet (assets/sprites/dungeon100_rustpunt.png).
## Start:  godot --path . -- --dungeon100rustpunttest [--shots=/pad/map]
##   De sheet laadt als 64x16, de zichtbare animatie heeft 4 frames (Nearest, lus 6-8 fps)
##   en het boek is niet meer getint. `vuur` blijft de grot-kampvuur-node voor de koopmantest.
## Niet in de CI-matrix (tests.yml blijft onaangeroerd). Zit niet in de export (scripts/tests/*).

const Rust := preload("res://scripts/dungeon/dungeon100_rustpunt.gd")

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 60 s", false)
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
	_sheet()
	await _node()
	print("DUNGEON100RUSTPUNTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _sheet() -> void:
	var tex: Texture2D = Rust.SHEET
	check("sheet laadt (dungeon100_rustpunt.png)", tex != null
			and tex.resource_path.ends_with("dungeon100_rustpunt.png"))
	check("sheet is 64x16 (4 frames van 16x16)", tex != null and tex.get_size() == Vector2(64, 16))
	check("TINT-constante blijft bestaan en is niet wit", Rust.TINT == Color(1.0, 0.86, 0.62)
			and Rust.TINT != Color.WHITE)
	var ph := FileAccess.get_file_as_string("res://tools/placeholders_v17.txt")
	check("geen dungeon100_rustpunt-regel in placeholders_v17.txt", not ph.contains("dungeon100_rustpunt"))


func _node() -> void:
	var rp: Node2D = Rust.create(Vector2i(4, 5))
	add_child(rp)
	await get_tree().process_frame
	await get_tree().process_frame
	check("rustpunt is Dungeon100Rustpunt op het midden van de tile", rp is Dungeon100Rustpunt
			and rp.position == Vector2(4, 5) * 16.0 + Vector2(8, 8))
	var book: Sprite2D = rp.get("sprite")
	check("boek blijft save_book.png, wit, niet getekend", book != null
			and book.texture != null and book.texture.resource_path.ends_with("save_book.png")
			and book.modulate == Color.WHITE and book.modulate != Rust.TINT and not book.visible)
	var anim: AnimatedSprite2D = rp.get("art")
	var frames: SpriteFrames = anim.sprite_frames if anim != null else null
	var fps := frames.get_animation_speed("default") if frames != null else 0.0
	check("zichtbare animatie: 4 frames, lus, 6-8 fps, speelt", anim != null and anim.visible
			and frames != null and frames.get_frame_count("default") == Rust.FRAME_COUNT
			and frames.get_animation_loop("default") and fps >= 6.0 and fps <= 8.0
			and is_equal_approx(fps, Rust.ANIM_FPS) and anim.is_playing())
	check("Nearest-filter op de animatie", anim != null
			and anim.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var slices_ok := frames != null
	if frames != null:
		for i in Rust.FRAME_COUNT:
			var atlas := frames.get_frame_texture("default", i) as AtlasTexture
			var verwacht := Rect2(i * Rust.FRAME_PX, 0, Rust.FRAME_PX, Rust.FRAME_PX)
			slices_ok = slices_ok and atlas != null and atlas.region == verwacht \
					and atlas.atlas != null and atlas.atlas.resource_path.ends_with("dungeon100_rustpunt.png")
	check("frames 0-3 zijn 16x16-slices van de sheet", slices_ok)
	var vuur: AnimatedSprite2D = rp.get("vuur")
	var vuur_tex: AtlasTexture = null
	if vuur != null:
		vuur_tex = vuur.sprite_frames.get_frame_texture("default", 0) as AtlasTexture
	check("vuur-API blijft: 4 grot-frames, speelt, niet getekend", vuur != null
			and vuur.sprite_frames.get_frame_count("default") == 4 and vuur.is_playing()
			and not vuur.visible and vuur_tex != null and vuur_tex.region == Rect2(0, 16, 16, 16))
	if shots != "":
		await _shot(rp)


func _shot(rp: Node2D) -> void:
	rp.position = Vector2(192, 108)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join("d100_rustpunt_art.png"))
	print("INFO  screenshot: ", shots.path_join("d100_rustpunt_art.png"))
