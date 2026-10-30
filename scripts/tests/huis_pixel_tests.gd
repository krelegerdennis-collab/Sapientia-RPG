extends Node
## Pixel-regressie: PR-renderer vs vastgezette main-referentie. Start: godot --path . -- --huispixeltest

const Referentie := preload("res://scripts/tests/huis_wilgendal_referentie.gd")
const Shot := preload("res://scripts/tests/huis_render_shot.gd")
const BuildScript := preload("res://scripts/data/huis_interieur_build.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	var ref_root := Node2D.new()
	Referentie.bouw_statisch(ref_root)
	var ref_img: Image = await Shot.render_node(ref_root, get_tree())
	_check("main-referentie render 512x336", ref_img != null and ref_img.get_size() == BuildScript.ROOM_PX)
	var pr_root := Node2D.new()
	_bouw_pr(pr_root)
	var pr_img: Image = await Shot.render_node(pr_root, get_tree())
	_check("PR-renderer render 512x336", pr_img != null and pr_img.get_size() == BuildScript.ROOM_PX)
	if ref_img == null or pr_img == null:
		return
	if pr_img == null:
		return
	var diff: int = Shot.tel_pixels_verschil(ref_img, pr_img)
	_check("pixel-diff main vs PR = 0 (verschil %d)" % diff, diff == 0)
	print("HUISPIXEL diff=%d" % diff)
	var uit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--uit="):
			uit = a.get_slice("=", 1)
	if uit != "":
		DirAccess.make_dir_recursive_absolute(uit)
		ref_img.save_png(uit.path_join("huis_wilgendal_before.png"))
		pr_img.save_png(uit.path_join("huis_wilgendal_after.png"))


func _bouw_pr(wortel: Node2D) -> void:
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wortel.add_child(ground)
	var details := Node2D.new()
	details.name = "Details"
	wortel.add_child(details)
	wortel.move_child(details, ground.get_index())
	var objects := Node2D.new()
	objects.name = "Objects"
	objects.y_sort_enabled = true
	wortel.add_child(objects)
	var build := BuildScript.new()
	build.bouw(ground, details, objects)
