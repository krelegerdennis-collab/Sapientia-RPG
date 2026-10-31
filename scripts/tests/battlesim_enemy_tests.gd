extends Node
## ALLEEN VOOR TESTEN - battle simulator: --total=N en de winrate per vijand (CSV + MD)
## (tools/battlesim/battlesim_runs.gd). Start:  godot --path . -- --battlesimenemytest
##   Deel A: per_enemy() op vaste regels (telling, dubbele vijanden 1x, sortering).
##   Deel B: --total verdeelt precies N gevechten over de groepen; zonder --total/--summary geen extra bestanden.
##   Deel C: samenvattingsbestanden: zelfde seed = byte-voor-byte gelijk, andere seed = anders.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const Runs := preload("res://tools/battlesim/battlesim_runs.gd")

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
	var t0 := Time.get_ticks_msec()
	while not GameState._preloading.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("=== Deel A: per_enemy ===")
	_per_enemy_tests()
	print("=== Deel B: --total ===")
	await _total_tests()
	print("=== Deel C: samenvatting deterministisch ===")
	await _summary_tests()
	print("BATTLESIMENEMYTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _runner(args: Array) -> Node:
	var r: Node = Runs.new()
	r.standalone = false
	add_child(r)
	r.configure(PackedStringArray(args))
	return r


# ================================================================ deel A
func _per_enemy_tests() -> void:
	var rows := [
		{"group_id": "g1", "enemies": "a+a", "win": 1, "turns": 2, "hp_left_pct": 80.0},
		{"group_id": "g1", "enemies": "a+a", "win": 0, "turns": 4, "hp_left_pct": 0.0},
		{"group_id": "g2", "enemies": "a+b", "win": 1, "turns": 3, "hp_left_pct": 40.0},
	]
	var s: Array[Dictionary] = Runs.per_enemy(rows)
	check("2 vijanden", s.size() == 2)
	var a: Dictionary = s[0] if str(s[0]["enemy"]) == "a" else s[1]
	var b: Dictionary = s[1] if str(s[0]["enemy"]) == "a" else s[0]
	check("a: dubbele vijand telt 1x per gevecht (3 gevechten, 2 winst)", a["fights"] == 3 and a["wins"] == 2 and a["losses"] == 1)
	check("a: winrate 66.7%, gem. 3.0 beurten, 40.0% HP", is_equal_approx(a["winrate_pct"], 66.7)
			and is_equal_approx(a["avg_turns"], 3.0) and is_equal_approx(a["avg_hp_left_pct"], 40.0))
	check("a: groepen g1;g2", a["groups"] == "g1;g2")
	check("b: 1 gevecht, 100%", b["fights"] == 1 and is_equal_approx(b["winrate_pct"], 100.0))
	check("gesorteerd: laagste winrate eerst", str(s[0]["enemy"]) == "a")
	var csv := Runs.to_csv(s, Runs.ENEMY_HEADER)
	check("per-vijand-CSV: kop + 2 regels", csv.split("\n", false).size() == 3
			and csv.begins_with(",".join(Runs.ENEMY_HEADER)))


# ================================================================ deel B
func _total_tests() -> void:
	var r := _runner(["--party=dennis:5,noor:5", "--enemy=enc0,enc4,enc6", "--total=10", "--runs=99", "--seed=5"])
	await r.run()
	check("geen fouten", r.errors.is_empty())
	check("--total=10: precies 10 gevechten (gaat boven --runs)", r.rows.size() == 10)
	var per := {}
	for row in r.rows:
		per[row["group_id"]] = int(per.get(row["group_id"], 0)) + 1
	check("verdeeld 4/3/3", per.get("enc0", 0) == 4 and per.get("enc4", 0) == 3 and per.get("enc6", 0) == 3)
	check("--total in RUN_ARGS", Runs.wants_runs(PackedStringArray(["--battlesim", "--total=1000"])))
	var bad := _runner(["--enemy=enc0", "--total=-1"])
	await bad.run()
	check("--total negatief = fout", not bad.errors.is_empty())
	var zero := _runner(["--enemy=enc0", "--total=0"])
	await zero.run()
	check("--total=0 = fout (--total must be >= 1)", zero.errors.has("--total must be >= 1"))
	if FileAccess.file_exists("user://sim/enemytest_plain_per_enemy.md"):
		DirAccess.remove_absolute("user://sim/enemytest_plain_per_enemy.md")
	var plain := _runner(["--party=dennis:5,noor:5", "--enemy=enc0", "--runs=1", "--seed=5", "--out=user://sim/enemytest_plain.csv"])
	await plain.run()
	check("zonder --total/--summary: geen per-vijand-bestanden", plain.errors.is_empty() and plain.written_summary == ""
			and not FileAccess.file_exists("user://sim/enemytest_plain_per_enemy.md"))
	zero.queue_free()
	plain.queue_free()
	r.queue_free()
	bad.queue_free()


# ================================================================ deel C
func _summary_tests() -> void:
	var base := ["--party=dennis:5,noor:5", "--enemy=all", "--total=%d" % (GD.ENCOUNTER_GROUPS.size() * 2)]
	var r1 := _runner(base + ["--seed=11", "--out=user://sim/enemytest_a.csv"])
	await r1.run()
	var r2 := _runner(base + ["--seed=11", "--out=user://sim/enemytest_b.csv"])
	await r2.run()
	var r3 := _runner(base + ["--seed=12", "--out=user://sim/enemytest_c.csv", "--summary=user://sim/enemytest_eigen"])
	await r3.run()
	check("standaardnaam <csv>_per_enemy", r1.written_summary == "user://sim/enemytest_a_per_enemy")
	check("--summary kiest de naam", r3.written_summary == "user://sim/enemytest_eigen")
	var md1 := FileAccess.get_file_as_string(r1.written_summary + ".md")
	var md2 := FileAccess.get_file_as_string(r2.written_summary + ".md")
	var md3 := FileAccess.get_file_as_string(r3.written_summary + ".md")
	var c1 := FileAccess.get_file_as_string(r1.written_summary + ".csv")
	var c2 := FileAccess.get_file_as_string(r2.written_summary + ".csv")
	check("MD en CSV geschreven", md1 != "" and c1 != "")
	check("zelfde seed: MD byte-voor-byte gelijk", md1 == md2)
	check("zelfde seed: per-vijand-CSV gelijk", c1 == c2)
	check("andere seed: MD anders", md3 != "" and md3 != md1)
	check("elke vijand uit de groepen staat erin", _all_enemies_listed(r1.enemy_stats))
	check("MD noemt seed en aantal gevechten", md1.contains("seed: `11`") and md1.contains("fights: %d" % r1.rows.size()))
	for r in [r1, r2, r3]:
		r.queue_free()


func _all_enemies_listed(stats: Array) -> bool:
	var ids := {}
	for s in stats:
		ids[str(s["enemy"])] = true
	for g in GD.ENCOUNTER_GROUPS:
		for e in g["enemies"]:
			if not ids.has(str(e)):
				return false
	return true
