extends Node
## ALLEEN VOOR TESTEN - WM1-bugjacht open punten O-2 en O-3 (al gefixt op main via #234).
## Standalone suite naast --autotest; dezelfde checks als wm1_stabiliteit_autotest zonder debug_autotest aan te raken.
## Start:  godot --path . -- --wm1openbugtest [--shots=/pad/map]
## Zie docs/qa/WM1_BUGJACHT.md. Zit niet in de export (scripts/tests/*).

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 300 s", false)
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
	print("=== WM1 openbugtest: O-2 (warper-boog) en O-3 (viewport buiten boom) ===")
	await preload("res://scripts/tests/wm1_stabiliteit_autotest.gd").new(self).run()
	print("WM1OPENBUGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
