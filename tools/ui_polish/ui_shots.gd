extends Node
## Screenshot-tool voor de UI-polijstronde (geen test, geen verhaalvlag).
## Start:  godot --path . -- --uishots --shots=/pad/map [--profiles=16x9,19_5x9] [--only=menu_main,hud]
## Maakt per profiel (aspect) en scherm een PNG (2x vergroot): <scherm>_<profiel>.png.
## Profielen en scenario's staan in ui_scenarios.gd.

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")

var sc: Node
var only: Array = []
var profiles: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sc = Scenarios.new()
	add_child(sc)
	profiles = Scenarios.PROFILES.keys()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			sc.shots_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--profiles="):
			profiles = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",")
	_run.call_deferred()


func _wanted(name: String) -> bool:
	return only.is_empty() or only.has(name)


func _run() -> void:
	await sc.wait_scene("Title")
	await sc.pframes(30)
	if _wanted("title"):
		for p in profiles:
			await sc.set_profile(p)
			await sc.pframes(20)
			await sc.shot("title")
	await sc.set_profile(profiles[0])
	if not await sc.start_game():
		print("FAIL  kon het spel niet starten")
		get_tree().quit(1)
		return
	for p in profiles:
		await sc.set_profile(p)
		for name in Scenarios.FIELD_SCENARIOS:
			if not _wanted(name):
				continue
			if await sc.open(name):
				await sc.shot(name)
			else:
				print("FAIL  scenario ", name)
			await sc.close_all()
		var battle_wanted := false
		for name in Scenarios.BATTLE_SCENARIOS:
			battle_wanted = battle_wanted or _wanted(name)
		if not battle_wanted:
			continue
		if not await sc.start_battle():
			print("FAIL  gevecht startte niet (", p, ")")
			continue
		for name in Scenarios.BATTLE_SCENARIOS:
			if not _wanted(name):
				continue
			if await sc.open_battle(name):
				await sc.shot(name)
			await sc.battle_back_to_cross()
		await sc.end_battle()
	print("RESULT OK (screenshots klaar)")
	get_tree().quit(0)
