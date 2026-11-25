extends SceneTree
## RC-meting F5.6 (klus 17): Classic (turn-based) op DEZELFDE kamers en met DEZELFDE party als
## --actionsim (SomData.ROOMS, SoM-startparty Lv 3, startuitrusting en starttas). Alleen meten:
## gebruikt battlesim.gd run_scenario (echte battle.tscn), verandert geen speldata.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/battlesim/rc_classic_som.gd -- [--seed=N] [--fights=N]
##
## Per kamer één scenario; elke map-monster-groep van de kamer is een los gevecht met volle HP.
## Uitvoer: regels "RCCLASSIC <kamer> ..." op stdout (win, HP-verlies, p90, rondes, items).
## Scripts worden pas bij het draaien geladen: in -s-modus kent de compiler de autoloads nog niet.

const BATTLESIM_PATH := "res://tools/battlesim/battlesim.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var som_data: GDScript = load("res://scripts/data/som_data.gd")
	var rooms_data: GDScript = load("res://scripts/data/dungeon_rooms.gd")
	var fights := 300
	var base_seed := 20261020
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fights="):
			fights = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--seed="):
			base_seed = int(a.get_slice("=", 1))
	var bs: Node = load(BATTLESIM_PATH).new()
	bs.standalone = false
	bs.fights = fights
	bs.base_seed = base_seed
	root.add_child(bs)
	bs.SimBattle = load(bs.SIM_BATTLE_PATH)
	bs.BATTLE_SCENE = load(bs.BATTLE_SCENE_PATH)
	bs.holder = Node.new()
	bs.add_child(bs.holder)
	var lv: int = som_data.START_LEVEL
	var gear: Array = som_data.START_GEAR
	var inv: Dictionary = (som_data.START_ITEMS as Dictionary).duplicate()
	print("RCCLASSIC start: seed %d, %d fights per room, party Lv %d" % [base_seed, fights, lv])
	for rid in som_data.ROOMS:
		var one := {str(rid): rooms_data.ROOMS[rid]}
		var sc := {"id": "rc_classic_%s" % rid, "name": "Classic %s" % rid,
			"party": [["dennis", lv, gear], ["noor", lv, []], ["lotte", lv, []]], "inv": inv, "som": false,
			"encounters": bs._room_groups(one, -1, true, false)}
		var r: Dictionary = await bs.run_scenario(sc)
		print("RCCLASSIC %s: groups %d, win %.1f%%, loss %.1f%%, p90 %.1f%%, rounds %.2f, items %.2f" % [rid,
			(sc["encounters"] as Array).size(), float(r.get("win_rate", 0.0)) * 100.0,
			float(r.get("avg_hp_loss", 0.0)) * 100.0, float(r.get("p90_hp_loss", 0.0)) * 100.0,
			float(r.get("avg_rounds", 0.0)), float(r.get("avg_items", 0.0))])
	bs.queue_free()
	quit(0)
