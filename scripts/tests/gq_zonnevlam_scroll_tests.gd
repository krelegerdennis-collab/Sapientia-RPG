extends Node
## ALLEEN VOOR TESTEN - Glitch Queen optie A: Solar Flare-scroll in V3-kistpool vanaf verdieping 20.
## Start:  godot --path . -- --gqzonnevlamscrolltest
## Niet in de CI-matrix (tests.yml onaangeroerd). Zie --blauwekisttest / PR #435-patroon.

const D100 := preload("res://scripts/data/dungeon100_scaling.gd")

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
	var p19 := D100.spell_scrolls_for_floor(19)
	var p20 := D100.spell_scrolls_for_floor(20)
	check("V3 floor 19: geen spreuk_zonnevlam in kist-pool", not p19.has("spreuk_zonnevlam"))
	check("V3 floor 20: spreuk_zonnevlam in kist-pool", p20.has("spreuk_zonnevlam"))
	print("GQZONNEVLAMSCROLLTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)