extends Node
## WM1 F3 stabiliteit (lokaal): huis-interieur wand-fysiek na add_source-volgorde.
## Start: godot --path . -- --wm1f3stabilitytest
## Niet in CI-matrix; wel geregistreerd in game_state.

const Build := preload("res://scripts/data/huis_interieur_build.gd")
const Atlas := preload("res://scripts/data/huis_interieur_atlas.gd")

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
	var b := Build.new()
	var ts: TileSet = b._maak_grond_tileset(true)
	for sleutel in Atlas.WALL_SLEUTELS:
		var sid: int = b._source_id(sleutel)
		var td: TileData = ts.get_source(sid).get_tile_data(Vector2i.ZERO, 0)
		check("huis tileset: %s heeft fysiek-polygonen" % sleutel, td.get_collision_polygons_count(0) > 0)
	print("WM1F3STABILITYTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
