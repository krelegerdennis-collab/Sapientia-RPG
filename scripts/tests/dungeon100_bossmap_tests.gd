extends Node
## Kaart-sprites van de Diepe Grot-bazen (assets/map_monsters/, 64x32).
## Start:  godot --path . -- --dungeon100bossmaptest
## Nog niet in de CI-matrix (tests.yml); zie de PR voor voorstel.

const Content := preload("res://scripts/dungeon/dungeon100_content.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")

var failures := 0
var passes := 0

const EXPECTED := {
	10: "page_warden",
	20: "glitch_queen",
	25: "schaduw_h6",
	30: "spore_lord",
	40: "root_mother",
	50: "de_cyclus",
	60: "mist_lord",
	70: "seal_warden",
	75: "de_rechter",
	80: "great_book_golem",
	90: "root_emperor",
	99: "de_stem",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(45.0, true, false, true).timeout.connect(func() -> void:
		check("waakhond: test klaar binnen 45 s", false)
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
	var floors: Array = Scaling.boss_floors()
	check("12 bazen in BOSSES", floors.size() == 12)
	for f in floors:
		var sprite := Content.boss_map_sprite(f)
		var verwacht: String = EXPECTED.get(f, "")
		check("verdieping %d: boss_map_sprite = %s" % [f, sprite], sprite == verwacht)
		var pad := "res://assets/map_monsters/%s.png" % sprite
		var tex: Texture2D = load(pad) if ResourceLoader.exists(pad) else null
		check("%s: bestaat en is 64x32" % sprite, tex != null and tex.get_size() == Vector2(64, 32))
		var data := {"floor": f, "floor_seed": 1, "boss_slot": Vector2i(4, 4)}
		var b: Dictionary = Content.boss(data)
		check("boss(floor %d): sprite/size/frame/fps" % f, b.get("sprite", "") == sprite
				and b.get("size", []) == [2, 2] and b.get("frame", []) == [32, 32]
				and is_equal_approx(float(b.get("fps", 0.0)), 1.2))
	check("fallback: onbekende verdieping -> golem", Content.boss_map_sprite(0) == "golem"
			and Content.boss_map_sprite(100) == "golem")
	var gt: Texture2D = load("res://assets/map_monsters/golem.png")
	check("golem-fallback: kaart-sprite 64x32", gt != null and gt.get_size() == Vector2(64, 32))
	print("DUNGEON100BOSSMAPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
