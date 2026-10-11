extends Node
## Extra kamers van de World Warper.
## Start: godot --path . -- --warperkamertest [--shots=/pad/map]

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const GameData := preload("res://scripts/data/game_data.gd")

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_vlag_en_act()
	_buit_en_tekst()
	_dorp_bezoek()
	_scènes()
	await _hal_in_beeld()
	print("WARPERKAMERTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _party(level: int) -> Array:
	return [{"level": level}]


func _vlag_en_act() -> void:
	var leeg := {}
	var open := {Kamers.FLAG_HUB: true}
	var act1 := _party(1)
	var act1_laat := _party(13)
	var act2 := _party(14)
	check("hub dicht zonder vlag", not Kamers.hub_open(leeg))
	for id in ["hal", "rustkamer", "echo_kamer", "beeldkamer", "trainingshal", "kern"]:
		check("dicht zonder vlag: " + id, not Kamers.is_open(id, leeg, act2))
	check("met vlag is De Hal open", Kamers.is_open("hal", open, act1) and Kamers.naam("hal") == "De Hal")
	check("met vlag is de Rustkamer open", Kamers.is_open("rustkamer", open, act1))
	check("met vlag is ECHO's Kamer open", Kamers.is_open("echo_kamer", open, act1))
	check("Beeldkamer dicht in act 1", not Kamers.is_open("beeldkamer", open, act1))
	check("Beeldkamer dicht op level 13", not Kamers.is_open("beeldkamer", open, act1_laat))
	check("Beeldkamer open in act 2", Kamers.is_open("beeldkamer", open, act2) and GameData.act_for_level(14) == 2)
	check("Trainingshal dicht in act 2", not Kamers.is_open("trainingshal", open, act2))
	check("Trainingshal open in act 3", Kamers.is_open("trainingshal", open, _party(20)) and GameData.act_for_level(20) == 3)
	check("Werkplaats open vanaf act 4", Kamers.is_open("werkplaats", open, _party(26)))
	check("Handelskamer open vanaf act 5", Kamers.is_open("handelskamer", open, _party(32)))
	check("Kern dicht vóór act 6", not Kamers.is_open("kern", open, _party(36)))
	check("Kern open in act 6", Kamers.is_open("kern", open, _party(37)) and Kamers.naam("kern") == "De Kern")
	check("onbekende kamer blijft dicht", not Kamers.is_open("hanger_nis", open, _party(40)))


func _dorp_bezoek() -> void:
	var DestTest: Script = load("res://world_warper/warp/destinations_test.gd")
	var fouten: PackedStringArray = DestTest.call("dorp_eerst_bezocht")
	check("dorp pas na bezoek (%s)" % [", ".join(fouten)], fouten.is_empty())


func _buit_en_tekst() -> void:
	var zak := {"drankje": 1}
	var na: Dictionary = Kamers.pas_buit_toe(true, 10, 5, zak, 2, 3, ["drankje"])
	check("Trainingshal geeft geen goud", int(na["gold"]) == 10)
	check("Trainingshal geeft geen EXP", int(na["exp"]) == 5)
	check("Trainingshal geeft geen items", int((na["items"] as Dictionary).get("drankje", 0)) == 1)
	check("Trainingshal geeft_buit is uit", not Kamers.geeft_buit())
	check("oefenvijand bestaat", GameData.ENEMIES.has(Kamers.OEFEN_VIJAND))
	check("geen recepten", Kamers.RECEPTEN.is_empty())
	check("geen endgame-winkel", Kamers.endgame_winkel() == "" and not Kamers.handel_open())
	check("handelstekst", Kamers.HANDEL_DICHT == "De handel is nog gesloten.")
	var doelen := Kamers.warp_doelen()
	var ids: Array[String] = []
	for d in doelen:
		ids.append(str(d.get("id", "")))
	check("warp naar Wilgendal", doelen.size() == 1 and str(doelen[0]["spawn"]) == "van_wilgendal"
			and str(doelen[0]["path"]) == "res://scenes/maps/wereldkaart.tscn")
	check("geen WM2/WM3", not ids.has("WM2") and not ids.has("WM3"))
	var wereld: Node = load("res://scenes/maps/wereldkaart.tscn").instantiate()
	check("spawn van_wilgendal bestaat", wereld.get_node_or_null("Spawns/van_wilgendal") != null)
	wereld.free()
	check("ECHO bedient alleen de hub", Kamers.ECHO_REGELS == ["Ik bedien deze hub."])
	check("ECHO noemt geen onderzoeker", not " ".join(Kamers.ECHO_REGELS).to_lower().contains("onderzoeker"))
	check("kernzin zonder onthulling", Kamers.KERN_ZIN == "Het verhaal van H-6 eindigt hier.")
	var schoon := true
	for regel in Kamers.speler_teksten():
		if regel.to_lower().contains("proefpersoon"):
			schoon = false
			print("INFO  Proefpersoon in: ", regel)
	check("geen Proefpersoon in de kamertekst", schoon)
	var groep: Array = [{"name": "Dennis", "hp": 1, "max_hp": 10, "mp": 0, "max_mp": 4},
			{"name": "Noor", "hp": 2, "max_hp": 8, "mp": 1, "max_mp": 6}]
	Kamers.helen(groep)
	check("helen vult HP en MP", int(groep[0]["hp"]) == 10 and int(groep[1]["mp"]) == 6)
	check("wissel zet Noor vooraan", Kamers.naar_voren(groep, 1) and str(groep[0]["name"]) == "Noor")
	check("vooraan wisselt niet met zichzelf", not Kamers.naar_voren(groep, 0))
	var regels := Kamers.voortgang_regels(0, {}, "")
	check("voortgang noemt de stap", regels.size() == 3 and regels[0].begins_with("Verhaalstap:"))
	check("bestiarium en codex bestaan", Kamers.scherm_beschikbaar("bestiarium") and Kamers.scherm_beschikbaar("codex"))


func _scènes() -> void:
	for id in Kamers.ROOMS.keys():
		var pad := Kamers.scene_path(str(id))
		check("scène bestaat: " + str(id), ResourceLoader.exists(pad))
		var node := (load(pad) as PackedScene).instantiate()
		var layout := node.get_node_or_null("Layout")
		var hier := str(layout.get("room_id")) if layout != null else ""
		check("layout " + str(id), hier == str(id))
		var gezien: Array[String] = []
		for deur in node.get_node("Exits").get_children():
			var doel := str(deur.get("room_id"))
			gezien.append(doel)
			check("deur %s -> %s" % [id, doel], str(deur.get("destination")) == Kamers.scene_path(doel))
			if str(id) == "hal":
				check("van de Hal naar " + doel, str(deur.get("destination_spawn")) == "ingang")
			else:
				check(str(id) + " terug naar de Hal", doel == "hal" and str(deur.get("destination_spawn")) == "van_" + str(id))
			check("blokkade " + doel, deur.get("blokkeer") != Vector2i.ZERO)
		gezien.sort()
		var verwacht := Kamers.deuren(str(id))
		verwacht.sort()
		check("deuren van " + str(id), gezien == verwacht)
		check("speler staat er", node.get_node_or_null("Objects/Player") != null)
		node.free()
	var hal: Node = load(Kamers.scene_path("hal")).instantiate()
	check("ECHO staat in de Hal", hal.get_node_or_null("Objects/Echo") != null and str(hal.get_node("Objects/Echo").get("bron")) == "echo")
	check("poort staat in de Hal", str(hal.get_node("Objects/Warp").get("bron")) == "warp")
	check("PC staat in de Hal", hal.get_node_or_null("Objects/Pc") != null)
	check("party kan er staan", hal.get_node_or_null("Objects/Party") != null)
	hal.free()
	var kern: Node = load(Kamers.scene_path("kern")).instantiate()
	check("De Kern toont de kernzin", str(kern.get_node("Objects/Kernbord").get("bron")) == "kern")
	kern.free()
	var training: Node = load(Kamers.scene_path("trainingshal")).instantiate()
	check("Trainingshal heeft een oefening", str(training.get_node("Objects/Oefening").get("bron")) == "oefening")
	training.free()


func _hal_in_beeld() -> void:
	GameState.story_flags[Kamers.FLAG_HUB] = true
	GameState.change_map(Kamers.scene_path("hal"), "ingang")
	var sc: Node = null
	for _i in 400:
		await get_tree().process_frame
		var nu := get_tree().current_scene
		if nu != null and nu.scene_file_path == Kamers.scene_path("hal") and not GameState.changing_map:
			sc = nu
			break
	check("De Hal laadt", sc != null and str(sc.get("map_name")) == "De Hal")
	if sc == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	check("ECHO-node in de geladen Hal", sc.get_node_or_null("Objects/Echo") != null)
	await _screenshot("warper_hal")


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size())
