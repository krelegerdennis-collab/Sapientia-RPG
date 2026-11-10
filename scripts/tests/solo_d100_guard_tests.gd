extends Node
## Bewijs dat solo-DLS (Classic) gelijk blijft aan de golden data van de start-commit.
## Start: godot --path . -- --solod100guardtest

const FP := preload("res://scripts/online/solo_d100_fingerprint.gd")
const GOLDEN := "res://data/online/sims/solo_d100_golden.json"

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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	if not (parsed is Dictionary):
		check("golden data geladen", false)
		_finish()
		return
	var gold: Dictionary = parsed
	check("golden versie 1", int(gold.get("version", 0)) == 1)
	var seeds: Array = gold.get("seeds", [])
	check("golden seeds 1 en 42", seeds.size() == 2 and int(seeds[0]) == 1 and int(seeds[1]) == 42)
	for f in range(1, 101):
		var key := str(f)
		check("monster_stats verdieping %d" % f, str(gold["monster"].get(key, "")) == FP.monster_hash(f))
		check("boss_stats verdieping %d" % f, str(gold["boss"].get(key, "")) == FP.boss_hash(f))
		check("chest_loot verdieping %d" % f, str(gold["chest"].get(key, "")) == FP.chest_hash(f))
		var per: Dictionary = gold["generate"].get(key, {})
		for seed in FP.SEEDS:
			check("generate(%d, %d)" % [seed, f], str(per.get(str(seed), "")) == FP.generate_hash(seed, f))
	_finish()


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)
