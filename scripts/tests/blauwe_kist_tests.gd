extends Node
## ALLEEN VOOR TESTEN - Blauwe Kist-sprite (assets/sprites/buiten/kist_blauw.png).
## Start:  godot --path . -- --blauwekisttest [--shots=/pad/map]
##   De placeholder-sheet laadt als 32x16 met 2 frames (Nearest). Dicht = frame 0, open = frame 1.
##   De blauwe kist houdt BLUE_TINT (oude dungeon100blauwtest). Gewone kisten en Mimics niet.
## Niet in de CI-matrix (tests.yml blijft onaangeroerd). Zit niet in de export (scripts/tests/*).

const ChestScript := preload("res://scripts/dungeon/dungeon_chest.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const Rooms := preload("res://scripts/data/dungeon_rooms.gd")
const VERWACHT_SHA := "9d58c4cd79abafdec7e6eb959e9d712efef4359e6113480aea17864df76eece8"
const LOOT := {"items": [{"item": "kort_zwaard", "n": 1}], "gold": 0, "tier": 1}

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
	_kisten()
	if shots != "":
		await _shots()
	print("BLAUWEKISTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _sheet() -> void:
	var tex: Texture2D = ChestScript.BLUE_TEX
	check("sheet laadt (kist_blauw.png)", tex != null and tex.resource_path.ends_with("buiten/kist_blauw.png"))
	check("sheet is 32x16 (2 frames van 16x16)", tex != null and tex.get_size() == Vector2(32, 16))
	var sha := FileAccess.get_sha256(ProjectSettings.globalize_path("res://assets/sprites/buiten/kist_blauw.png"))
	check("sha256 van kist_blauw.png", sha == VERWACHT_SHA)
	var ph := FileAccess.get_file_as_string("res://tools/placeholders_v17.txt")
	var ph_regel := false
	for l in ph.split("\n"):
		if l.contains("assets/sprites/buiten/kist_blauw.png"):
			ph_regel = "PLACEHOLDER" in l
	check("kist_blauw.png staat als PLACEHOLDER in placeholders_v17.txt", ph_regel)
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	check("kist_blauw.png staat niet in handwerk.txt", not hw.contains("kist_blauw.png"))
	check("BLUE_TINT blijft de oude kleur", Blue.BLUE_TINT == Color(0.45, 0.7, 1.35))


func _maak(kind: String, id: String) -> DungeonChest:
	var ch := ChestScript.new() as DungeonChest
	var data := {"id": id, "tile": [3, 4], "floor": 12, "loot": LOOT.duplicate(true)}
	if kind != "":
		data["kind"] = kind
	ch.setup(data)
	add_child(ch)
	return ch


func _kisten() -> void:
	GameState.new_game("Dax")
	var prev := Rooms.current_theme
	Rooms.current_theme = "archief_grijs"
	var blauw := _maak(Blue.KIND_BLUE, "bk_dicht")
	check("blauwe kist: soort blauw", blauw.kind == Blue.KIND_BLUE)
	check("dicht: frame 0, hframes 2, Nearest, eigen sheet", _sheet_ok(blauw, 0))
	check("thema archief_grijs vervangt de blauwe sheet niet",
			blauw.sprite.texture == ChestScript.BLUE_TEX)
	blauw.open_chest()
	check("openen zet frame 1", blauw.is_open() and blauw.sprite.frame == 1 and blauw.last_result == "blauw")
	Dialog.close()
	GameState.story_flags["kist:bk_alopen"] = true
	var al := _maak(Blue.KIND_BLUE, "bk_alopen")
	check("al open bij setup: frame 1", al.is_open() and _sheet_ok(al, 1))
	var gewoon := _maak("", "bk_gewoon")
	check("gewone kist blijft kist.png (thema), frame 0, wit", gewoon.kind == Blue.KIND_NORMAL
			and gewoon.sprite.frame == 0 and gewoon.sprite.hframes == 2
			and gewoon.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and gewoon.sprite.modulate == Color.WHITE
			and gewoon.sprite.texture != null
			and str(gewoon.sprite.texture.resource_path).ends_with("dungeon/grijs/kist.png")
			and gewoon.sprite.texture != ChestScript.BLUE_TEX)
	Rooms.current_theme = "diepe_grot_v1"
	var mimic := _maak(Blue.KIND_MIMIC, "bk_mimic")
	check("Mimic blijft de gewone kist van het thema", mimic.kind == Blue.KIND_MIMIC
			and mimic.sprite.modulate == Color.WHITE
			and mimic.sprite.texture != ChestScript.BLUE_TEX
			and str(mimic.sprite.texture.resource_path).ends_with("buiten/kist.png"))
	Rooms.current_theme = prev
	for n in [blauw, al, gewoon, mimic]:
		n.queue_free()


func _sheet_ok(ch: DungeonChest, frame: int) -> bool:
	var spr := ch.sprite
	return spr != null and spr.texture == ChestScript.BLUE_TEX and spr.hframes == 2 \
			and spr.frame == frame and spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST \
			and spr.modulate == Blue.BLUE_TINT


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	var dicht := await _render(0)
	var open := await _render(1)
	if dicht == null or open == null or dicht.is_empty() or open.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	_bewaar(dicht, "kist_blauw_dicht.png")
	_bewaar(open, "kist_blauw_open.png")


func _render(frame: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var wereld := Node2D.new()
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.12, 0.18)
	bg.position = Vector2.ZERO
	bg.size = Vector2(16, 16)
	wereld.add_child(bg)
	var spr := Sprite2D.new()
	spr.texture = ChestScript.BLUE_TEX
	spr.hframes = 2
	spr.frame = frame
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.position = Vector2(8, 8)
	wereld.add_child(spr)
	vp.add_child(wereld)
	add_child(vp)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _bewaar(img: Image, naam: String) -> void:
	var groot := img.duplicate()
	groot.resize(128, 128, Image.INTERPOLATE_NEAREST)
	var pad := shots.path_join(naam)
	groot.save_png(pad)
	print("INFO  screenshot: ", pad)
