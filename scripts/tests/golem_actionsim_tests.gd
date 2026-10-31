extends Node
## D3 PR B: rookproef realtime Golem-sim (tools/battlesim/golem_rt_sim.gd, --actionsim --boss-rt).
## Kleine sim (20 gevechten), ruime band. Start: godot --path . -- --golemactionsimtest

const GolemRtSim := preload("res://tools/battlesim/golem_rt_sim.gd")
const ACTION_SIM := "res://tools/battlesim/action_sim.gd"

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
	var party := GolemRtSim.party_at_level(7)
	check("party Lv 7: %d helden, allemaal Lv 7" % party.size(), party.size() >= 3 and party.all(func(h): return int(h["level"]) == 7))
	var sim := GolemRtSim.new()
	check("sim-baas = ongewijzigde stats (360/27/15)", int(sim.boss_data["max_hp"]) == 360 and int(sim.boss_data["atk"]) == 27 and int(sim.boss_data["def"]) == 15)
	var a: Dictionary = sim.run(7, 20, "default", 777)
	var b: Dictionary = sim.run(7, 20, "default", 777)
	check("vaste seed = zelfde uitkomst", JSON.stringify(a) == JSON.stringify(b))
	check("Lv 7: getallen in bereik (win %.0f%%, verlies %.1f%%, %.1f s)" % [a["win"] * 100.0, a["loss"] * 100.0, a["time"]],
		a["win"] >= 0.0 and a["win"] <= 1.0 and a["loss"] >= 0.0 and a["loss"] <= 1.0 and a["time"] > 0.0 and a["time"] <= 300.0)
	check("Lv 7: fase 1 altijd bereikt (%d/20)" % a["phases"][0]["reached"], int(a["phases"][0]["reached"]) == 20)
	check("Lv 7: fase-bereik daalt (F1 >= F2 >= F3)", int(a["phases"][0]["reached"]) >= int(a["phases"][1]["reached"])
		and int(a["phases"][1]["reached"]) >= int(a["phases"][2]["reached"]))
	check("Lv 7: kern-vensters per gevecht > 0 (%.1f)" % a["windows_per_fight"], float(a["windows_per_fight"]) > 0.0)
	check("ontwijkkans in de buurt van het model (%.0f%%)" % (a["dodge_rate"] * 100.0), a["dodge_rate"] > 0.05 and a["dodge_rate"] < 0.6)
	var good: Dictionary = sim.run(7, 20, "good", 777)
	check("goede speler verliest niet meer HP dan default (%.1f%% vs %.1f%%)" % [good["loss"] * 100.0, a["loss"] * 100.0], good["loss"] <= a["loss"] + 0.05)
	var lv3: Dictionary = sim.run(3, 20, "default", 777)
	check("Lv 3 wint niet vaker dan Lv 7 (%.0f%% vs %.0f%%)" % [lv3["win"] * 100.0, a["win"] * 100.0], lv3["win"] <= a["win"])
	# action_sim --boss-rt rapport
	var as_node: Node = load(ACTION_SIM).new()
	as_node.standalone = false
	as_node.boss_fights = 4
	as_node.boss_levels = [7]
	add_child(as_node)
	as_node.run_boss_rt()
	var md: String = as_node.boss_rt_markdown(0)
	check("action_sim boss-rt: 2 profielen, tabel met fases", as_node.boss_rt_results.size() == 2 and md.contains("| 7 | default |") and md.contains("F3"))
	as_node.queue_free()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)
