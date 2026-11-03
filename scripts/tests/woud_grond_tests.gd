extends Node
## WM1 T2: woud_beek bosvloer-varianten (--woudgrondtest): GROND-pool, bestanden, hash-keuze.
## Start: godot --path . -- --woudgrondtest

const Beek := preload("res://scripts/data/woud_beek.gd")
const VERWACHT := ["grond_a", "grond_b", "grond_c", "grond_d", "grond_e", "grond_f", "grond_g"]

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
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_grond_pool()
	_bestanden()
	_dekking()
	print("WOUDGRONDTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _grond_pool() -> void:
	check("GROND heeft 7 entries", Beek.GROND.size() == 7)
	check("GROND volgorde a..g", Beek.GROND == VERWACHT)


func _bestanden() -> void:
	var fout: Array[String] = []
	for naam in Beek.GROND:
		var r: Dictionary = WoudTegelsData.tegel(naam)
		if r.is_empty():
			fout.append("%s: ontbreekt in JSON" % naam)
			continue
		var pad := str(r.get("file", ""))
		if pad == "" or not ResourceLoader.exists(pad) or not FileAccess.file_exists(pad):
			fout.append("%s: %s" % [naam, pad])
		elif int(r.get("varianten", 0)) != Beek.GROND.size():
			fout.append("%s: varianten=%s (verwacht %d)" % [naam, r.get("varianten"), Beek.GROND.size()])
	check("elke GROND-tegel bestaat en varianten=%d (%s)" % [Beek.GROND.size(), fout], fout.is_empty())


func _dekking() -> void:
	var gezien := {}
	for y in Beek.LAYOUT.size():
		for x in str(Beek.LAYOUT[y]).length():
			if Beek.teken(Vector2i(x, y)) != ".":
				continue
			gezien[Beek.grond_naam(Vector2i(x, y))] = true
	var mist: Array[String] = []
	for naam in Beek.GROND:
		if not gezien.has(naam):
			mist.append(naam)
	check("hash-keuze op '.' kan elke GROND-tegel opleveren (mist: %s)" % [mist], mist.is_empty())


func _wacht(cond: Callable, sec: float) -> void:
	var eind := Time.get_ticks_msec() + int(sec * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < eind:
		await get_tree().process_frame
