extends Node
## Hanger-gloed is paars. De zin over de Stroom blijft roze.
## Start: godot --path . -- --hangertest

const Dreiging := preload("res://world_warper/cutscene/dreiging.gd")
const HangerScene := preload("res://world_warper/cutscene/hanger_scene.tscn")

const ROZE := Color("e2789e")
const STROOM := "De Stroom gloeit roze."

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
	var stroom := false
	for regel in regels:
		if regel == "De Hanger wordt warm. " + STROOM:
			stroom = true
	check("de Stroom blijft roze in de zin", stroom and STROOM in " ".join(regels))
	check("beat 2 blijft de tweede regel", Dreiging.beat_at(1) == 2)
	var scene := HangerScene.instantiate() as WorldWarperHangerScene
	add_child(scene)
	await get_tree().process_frame
	scene._beat_gloed()
	check("Hanger-gloed is paars", scene.hanger.color == WorldWarperHangerScene.PURPLE
			and scene.hanger.color != ROZE)
	check("gloed-modulate is niet roze", scene.hanger.modulate != Color(0.85, 0.45, 0.6, 1))
	scene._beat_restore()
	check("herstel blijft paars", scene.hanger.color == Color(0.72, 0.55, 0.95, 1)
			and scene.hanger.color != Color(0.95, 0.72, 0.8, 1))
	scene._beat_purple()
	check("stille hal houdt de Hanger metaal", scene.hanger.color == WorldWarperHangerScene.METAL)
	print("HANGERTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
