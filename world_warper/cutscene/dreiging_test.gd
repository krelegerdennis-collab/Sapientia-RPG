extends Node
## Checks voor de eerste-bezoekscène. Nog niet in de suite-matrix
## (isolatie: alleen world_warper/cutscene/). Start als scène:
##   godot --path . res://world_warper/cutscene/dreiging_test.gd

const Dreiging := preload("res://world_warper/cutscene/dreiging.gd")

var passes := 0
var failures := 0


func _ready() -> void:
	_run()
	print("DREIGINGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	check("should_play true zonder vlag", Dreiging.should_play({}))
	check("should_play true bij andere vlag", Dreiging.should_play({"andere_vlag": true}))
	check("should_play false met vlag", not Dreiging.should_play({"world_warper_intro_seen": true}))
	var lines: Array[String] = Dreiging.lines()
	check("minstens 4 regels", lines.size() >= 4)
	var banned: Array[String] = ["H-6", "Dennis", "Proefpersoon"]
	for word in banned:
		var found := false
		for line in lines:
			if line.contains(word):
				found = true
		check("geen " + word, not found)
	var nonempty := true
	for line in lines:
		if line.strip_edges() == "":
			nonempty = false
	check("geen lege regel", nonempty)
	if lines.size() >= 4:
		check("beat 1 op de eerste regel", Dreiging.beat_at(0) == 1)
		check("beat 2 op de tweede regel", Dreiging.beat_at(1) == 2)
		check("beat 4 op de laatste regel", Dreiging.beat_at(lines.size() - 1) == 4)
		var mid := true
		for i in range(2, lines.size() - 1):
			if Dreiging.beat_at(i) != 3:
				mid = false
		check("beat 3 tussen gloed en herstel", mid)
