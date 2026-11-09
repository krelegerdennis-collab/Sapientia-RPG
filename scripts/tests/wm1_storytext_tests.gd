extends Node
## WM1 goedgekeurde storytext: gating, canon-scène 1 volgorde, Atrium-teksten (headless).
## CI: --wm1storytexttest (tests.yml).

const SD := preload("res://scripts/data/story_data.gd")
const WR := preload("res://scripts/data/woud_rooms.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const VideoSlot := preload("res://scripts/data/wm1_dormant_video_slot.gd")
const KernAbsorption := preload("res://scripts/kern/kern_absorption.gd")
const KernData := preload("res://scripts/data/kern_data.gd")

var passes := 0
var failures := 0


func _ready() -> void:
	_run()
	print("RESULT %s (%d PASS, %d FAIL)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_cocon_gating_data()
	_cocon_event()
	_na_esdoorn()
	_archief2_keten()
	_genezer_orion_volgorde()
	_atrium_exact()
	_save_cocon_flag()
	_dormant_video_slots()
	_golem_core_sapientia()
	_golem_drained_fragment()


func _cocon_gating_data() -> void:
	var room: Dictionary = WR.ROOMS["woud_open_plek"]
	var blok: Dictionary = room.get("blokkades", {})
	check("cocon: blokkades tot_vlag = cocon_gezien", str(blok.get("tot_vlag", "")) == "cocon_gezien")
	var tiles: Array = blok.get("tiles", [])
	check("cocon: minstens één blokkade-tegel", tiles.size() >= 1)


func _cocon_event() -> void:
	var ev: Array = SD.EVENTS["cocon"]
	var sprekers: Dictionary = {}
	var texts: Array[String] = []
	for branch in ev:
		for cmd in branch.get("do", []):
			if cmd is Array and cmd.size() >= 3 and str(cmd[0]) == "say":
				sprekers[str(cmd[1])] = true
				for ln in cmd[2]:
					texts.append(str(ln))
	var blob := " ".join(texts)
	check("cocon pre: Vesper! als Dax-gedachte", blob.contains("Vesper! She hangs unconscious in a cocoon of roots."))
	check("cocon pre: Vesper…", blob.contains("Vesper…"))
	check("cocon pre: Hang on", blob.contains("Hang on. I'll get you out."))
	check("cocon pre: Root King", blob.contains("The Root King has to go first."))
	check("cocon post: lege cocon", blob.contains("The empty cocoon. The roots are grey and withered."))
	check("cocon: spreker {naam}, geen verteller", sprekers.has("{naam}") and not sprekers.has(""))
	var has_flag := false
	for branch in ev:
		for cmd in branch.get("do", []):
			if cmd is Array and cmd.size() >= 2 and str(cmd[0]) == "flag" and str(cmd[1]) == "cocon_gezien":
				has_flag = true
	check("cocon: zet cocon_gezien", has_flag)


func _na_esdoorn() -> void:
	var ev: Array = SD.EVENTS["naar_esdoorn"]
	var found := false
	for branch in ev:
		if not branch.has("if"):
			continue
		var nf: Array = branch.get("if", {}).get("not_flags", [])
		if SD.GOLEM_FLAG in nf:
			for cmd in branch.get("do", []):
				if cmd is Array and cmd[0] == "say" and str(cmd[1]) == "{naam}":
					found = true
					var txt := " ".join((cmd[2] as Array).map(func(x): return str(x)))
					check("Mapleton-lead: Mapleton in tekst", txt.contains("Mapleton"))
	check("naar_esdoorn: Dax-gedachte (niet lege spreker)", found)


func _archief2_keten() -> void:
	var ev: Array = SD.EVENTS["archief2_keten"]
	var dax := 0
	var echo_lines := 0
	for cmd in ev[0].get("do", []):
		if cmd is Array and cmd[0] == "say":
			if str(cmd[1]) == "{naam}":
				dax += 1
			elif str(cmd[1]) == "ECHO":
				echo_lines = (cmd[2] as Array).size()
	check("keten: twee Dax-gedachten (V-D01)", dax == 2)
	check("keten: vijf ECHO-regels", echo_lines == 5)
	check("keten: Archief2.KETEN ongewijzigd", Archief2.KETEN.size() == 5
			and str(Archief2.KETEN[0]).begins_with("The Old Humanity"))


func _genezer_orion_volgorde() -> void:
	var teksten: Array = Canon.GENEZER.map(func(r): return str(r["text"]))
	var i_plants := teksten.find("The plants. They're fading.")
	var i_echo := teksten.find("Candidate detected. Two Archives active. World Warper online.")
	var i_orion := teksten.find("Hold. Bow first.")
	var i_seren := teksten.find("Dax—!")
	check("scène 1: Vesper plants-regel", i_plants >= 0)
	check("scène 1: Orion vóór ECHO", i_orion >= 0 and i_echo > i_orion)
	check("scène 1: Seren Dax—! na ECHO", i_seren > i_echo)
	check("Sprekers: Orion in SPREKERS", Canon.SPREKERS.has("Orion"))
	var idx := {}
	for r in Canon.GENEZER:
		var w := str(r.get("who", ""))
		idx[w] = int(idx.get(w, 0)) + 1
	check("scène 1: geen anonieme verteller", not idx.has("") or int(idx[""]) == 0)


func _atrium_exact() -> void:
	var hang := Canon.HANGER.map(func(r): return str(r["text"]))
	var drei := Canon.DREIGING.map(func(r): return str(r["text"]))
	check("HANGER: 17 regels", hang.size() == 17)
	check("HANGER: Pendant exact", hang[7] == "There it is. The Pendant. I had hoped I would never see it again.")
	check("DREIGING: 22 regels", drei.size() == 22)
	check("DREIGING: I have two exact", " ".join(drei).contains("I have two. You woke them."))


func _save_cocon_flag() -> void:
	GameState.new_game("Dax")
	GameState.story_flags.erase("cocon_gezien")
	check("save: cocon_gezien leeg", not GameState.story_flags.has("cocon_gezien"))
	GameState.story_flags["cocon_gezien"] = true
	GameState.save_game(Vector2i(2, 3), Vector2i.DOWN)
	GameState.new_game("Y")
	check("load: ander spel", not GameState.story_flags.has("cocon_gezien"))
	check("load: cocon_gezien terug", GameState.load_game() and GameState.story_flags.has("cocon_gezien"))


func _dormant_video_slots() -> void:
	for id in [VideoSlot.MAPLETON_VESPER, VideoSlot.ARCHIEF2_CORRUPTED_SEREN, VideoSlot.ATRIUM_PENDANT,
			VideoSlot.ATRIUM_THREAT]:
		check("dormant slot id '%s'" % id, id.begins_with("dialogue_"))
	VideoSlot.before_dialogue(VideoSlot.MAPLETON_VESPER)
	check("dormant poort crasht niet", true)
	check("dormant CS02 id", VideoSlot.CS02_GOLEM_CORE.begins_with("dialogue_"))


func _golem_core_sapientia() -> void:
	var lines: Array = KernAbsorption.lines_for("golemkern")
	check("CS-02: exacte Sapientia-regel", lines.size() == 1 and str(lines[0]) == "Sapientia drank the Golem Core dry.")
	check("CS-02: geen Dax absorbs-tekst", not " ".join(lines).contains("absorbs"))


func _golem_drained_fragment() -> void:
	var f := KernData.fragment("golemkern")
	check("golemkern: beschrijving power of matter", str(f.get("beschrijving", "")).contains("the power of matter"))
	check("golemkern: geen battle/world power", str(f.get("battle_skill", "x")) == "" and KernData.abilities_of(f).is_empty())
	GameState.new_game("Dax")
	GameState.grant_kern("golemkern", "kennis_beest")
	check("grant_kern: fragment in save, geen vaardigheden", GameState.has_kern("golemkern")
			and GameState.kern_skills_of(GameState.MAIN_HERO).is_empty()
			and not GameState.has_world_ability("zware_blokken"))
