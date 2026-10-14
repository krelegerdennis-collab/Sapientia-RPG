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


const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")


func _run() -> void:
	# Canon-scènes 2+3 (CANON.md punt 17): eenmalig, save-veilig via vlaggen.
	check("should_play true zonder vlag", Dreiging.should_play({}))
	check("should_play true bij andere vlag", Dreiging.should_play({"andere_vlag": true}))
	check("oude intro-vlag speelt de canon alsnog", Dreiging.should_play({"world_warper_intro_seen": true}))
	check("should_play false na scène 3", not Dreiging.should_play({Canon.FLAG_DREIGING: true}))
	var lines: Array[String] = Dreiging.lines()
	check("scène 2 + 3 compleet", lines.size() == Canon.HANGER.size() + Canon.DREIGING.size())
	var alleen3: Array[String] = Dreiging.lines({Canon.FLAG_HANGER: true})
	check("scène 2 gezien: alleen scène 3", alleen3.size() == Canon.DREIGING.size()
			and alleen3[0] == "Sapientia: ECHO. You found him." and Dreiging.einde_hanger({Canon.FLAG_HANGER: true}) == -1)
	check("einde scène 2 = laatste Hanger-regel", Dreiging.einde_hanger({}) == Canon.HANGER.size() - 1
			and lines[Dreiging.einde_hanger({})].ends_with("And there is little time."))
	var nonempty := true
	var sprekers := true
	for r in Canon.HANGER + Canon.DREIGING + Canon.GENEZER:
		if str(r.get("text", "")).strip_edges() == "":
			nonempty = false
		if not Canon.SPREKERS.has(str(r.get("who", "?"))):
			sprekers = false
	check("geen lege regel", nonempty)
	check("alleen bekende sprekers", sprekers)
	var alles := " ".join(lines) + " " + " ".join(Canon.GENEZER.map(func(r): return str(r["text"])))
	var nl := false
	for woord in [" het ", " een ", " niet ", " wat ", " jij ", "Hanger. Ik", "Archieven"]:
		if alles.contains(woord):
			nl = true
	check("tekst is Engels (geen Nederlandse woorden)", not nl)
	check("H-6 staat in de dreiging (canon)", " ".join(lines).contains("H-6. Your name is no accident."))
	check("ECHO in scène 1", alles.contains("Candidate detected. Two Archives active. World Warper online."))
	check("beat 1 op de eerste regel", Dreiging.beat_at(0) == 1)
	var ah := lines.find("ECHO: ...Ah.")
	check("Hanger-gloed (beat 2) vanaf '...Ah'", ah > 0 and Dreiging.beat_at(ah) == 2 and Dreiging.beat_at(ah - 1) == 1)
	var sap := lines.find("Sapientia: ECHO. You found him.")
	check("Sapientia-glitch (beat 3) vanaf haar eerste zin", sap > 0 and Dreiging.beat_at(sap) == 3
			and Dreiging.beat_at(sap - 1) == 2)
	check("herstel (beat 4) op de laatste regel", Dreiging.beat_at(lines.size() - 1) == 4
			and lines[lines.size() - 1] == "ECHO: But that is a story for later.")
	var volgorde := true
	for i in range(1, lines.size()):
		if Dreiging.beat_at(i) < Dreiging.beat_at(i - 1):
			volgorde = false
	check("beats lopen op", volgorde)
	# Scène 1
	check("scène 1 speelt zonder vlag", Canon.genezer_speelt({}) and not Canon.genezer_speelt({Canon.FLAG_GENEZER: true}))
	var cues: Array = Canon.GENEZER.map(func(r): return str(r["cue"]))
	check("scène 1: kern, glitch, straal, warper, ECHO-puls, cirkel, flits in volgorde",
			cues.find("kern") < cues.find("glitch") and cues.find("glitch") < cues.find("straal")
			and cues.find("straal") < cues.find("warper") and cues.find("warper") < cues.find("puls")
			and cues.find("puls") < cues.find("cirkel") and cues.find("cirkel") < cues.find("flits")
			and cues[cues.size() - 1] == "flits")
	check("scène 1 eindigt in de Hal", Canon.HAL_SCENE.ends_with("world_warper/maps/hal.tscn") and Canon.HAL_SPAWN == "ingang")
	check("als_tekst: verteller zonder naam", Canon.als_tekst({"who": "", "text": "x"}) == "x"
			and Canon.als_tekst({"who": "Vesper", "text": "y"}) == "Vesper: y")
