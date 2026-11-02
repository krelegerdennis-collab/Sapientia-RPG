extends Node
## T26: eigen hit2/finisher-sheets voor Dax (dennis) en Seren (lotte), met terugval op <held>_attack.png.
## Start: godot --headless --path . -- --t26sheettest

const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const HEROES: Array[String] = ["dennis", "lotte"]
const FALLBACK: Array[String] = ["noor", "kael", "orion"]
const STEPS: Array[int] = [SomChainData.STEP_HIT2, SomChainData.STEP_FINISHER]

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
	for id in HEROES:
		var base: Dictionary = SomData.ATTACK_ANIMS[id]
		for step in STEPS:
			var st := SomChainData.state_for(step)
			var path := SomChainData.step_sheet(id, step)
			check("%s %s: eigen sheet bestaat (%s)" % [id, st, path], path != "" and ResourceLoader.exists(path))
			var tex := load(path) as Texture2D if path != "" else null
			check("%s %s: sheet laadt als Texture2D" % [id, st], tex != null)
			if tex != null:
				check("%s %s: 288x192 (6x4 frames van 48x48)" % [id, st], tex.get_width() == 288 and tex.get_height() == 192)
			var d := SomChainData.anim_def(base, step, id)
			check("%s %s: def gebruikt eigen sheet, geen placeholder" % [id, st], str(d.get("sheet", "")) == path and not bool(d.get("placeholder", true)))
			check("%s %s: 6 frames, treffer op frame 4" % [id, st], int(d.get("frames", 0)) == 6 and int(d.get("hit_frame", 0)) == 4
					and SomData.ATTACK_HIT_FRAME == 4 and (d.get("ms", []) as Array).size() == 6)
		var h1 := SomChainData.anim_def(base, SomChainData.STEP_HIT1, id)
		check("%s hit1: blijft <held>_attack.png" % id, str(h1.get("sheet", "")) == str(base["sheet"]) and SomChainData.step_sheet(id, SomChainData.STEP_HIT1) == "")
	for id in FALLBACK:
		if not SomData.ATTACK_ANIMS.has(id):
			continue
		var base: Dictionary = SomData.ATTACK_ANIMS[id]
		for step in STEPS:
			var st := SomChainData.state_for(step)
			var d := SomChainData.anim_def(base, step, id)
			check("terugval %s %s: geen eigen sheet, placeholder van _attack.png" % [id, st],
					SomChainData.step_sheet(id, step) == "" and str(d.get("sheet", "")) == str(base["sheet"]) and bool(d.get("placeholder", false))
					and int(d.get("hit_frame", 0)) == 4)
	# zonder held-id (oude aanroep): ongewijzigd placeholder-gedrag
	var d0 := SomChainData.anim_def(SomData.ATTACK_ANIMS["dennis"], SomChainData.STEP_FINISHER)
	check("anim_def zonder id: placeholder (achterwaarts compatibel)", bool(d0.get("placeholder", false)) and str(d0["sheet"]) == str(SomData.ATTACK_ANIMS["dennis"]["sheet"]))
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)
