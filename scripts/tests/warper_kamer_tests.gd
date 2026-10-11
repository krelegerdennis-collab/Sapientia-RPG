extends Node
## Extra kamers van de World Warper.
## Start: godot --path . -- --warperkamertest [--shots=/pad/map]

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Dialoog := preload("res://world_warper/guide/dialoog.gd")
const Gear := preload("res://scripts/equipment.gd")
const SD := preload("res://scripts/data/story_data.gd")
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const DUNGEON := "res://scenes/maps/dungeon100.tscn"

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
	_scènes()
	await _hal_in_beeld()
	await _echo_grot()
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
		if str(id) == "echo_kamer":
			var echo := node.get_node_or_null("Objects/Echo")
			check("ECHO staat in ECHO's Kamer", echo != null and str(echo.get("bron")) == "echo_grot")
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


func _echo_grot() -> void:
	var welkom := ""
	var stappen: Array = Dialoog.steps()
	if not stappen.is_empty():
		var regels: Array = stappen[0].get("lines", [])
		if not regels.is_empty():
			welkom = str(regels[0])
	var eerste_letterlijk := "De Diepe Grot. Een simulatie — honderd verdiepingen, telkens anders. Ik beheer hem. Sapientia... Sapientia helpt met de data. Zo werkt het nu eenmaal."
	var twijfel_letterlijk := "Waarom ik het doe? Omdat het mijn taak is. De Oude Mensheid bouwde me om te meten, te tellen, te bewaren."
	var h6_letterlijk := "Ik heb honderden kandidaten doorgelaten. Jij bent de zesde die bleef staan. De anderen... ik weet niet wat er met ze is gebeurd."
	var data_letterlijk := "Dat weet ik niet. Ik lever, zij neemt. Zo is het altijd geweest."
	check("grotzinnen letterlijk", EchoGrot.ZIN_EERSTE == eerste_letterlijk and EchoGrot.ZIN_TWIJFEL == twijfel_letterlijk
			and EchoGrot.ZIN_H6 == h6_letterlijk and EchoGrot.ZIN_DATA == data_letterlijk)
	check("ECHO legt de onderzoeker-twist niet uit", not " ".join(EchoGrot.speler_teksten()).to_lower().contains("onderzoeker"))
	check("voor H-6 alleen de eerste zin", EchoGrot.regels_vooraf({}) == [EchoGrot.ZIN_EERSTE])
	check("na H-6 komt de kandidatenzin erbij", EchoGrot.regels_vooraf({EchoGrot.FLAG_EERSTE: true, EchoGrot.FLAG_H6: true}) == [EchoGrot.ZIN_H6])
	check("trappen in de grot blijven een uitgang", not EchoGrot.blokkeert_wereldkaart(EchoGrot.DUNGEON, EchoGrot.DUNGEON))

	var wereld_dicht := await _wereld_weigert()
	GameState.party[0]["level"] = 8
	GameState.party[0]["spells"] = ["test_spreuk"]
	GameState.inventory["kort_zwaard"] = 1
	var aan := Gear.equip(GameState.party[0], GameState.inventory, "wapen", "kort_zwaard")
	check("zwaard om voor de run", bool(aan.get("ok", false)) and str(GameState.party[0]["equip"]["wapen"]) == "kort_zwaard")
	GameState.change_map(EchoGrot.KAMER, EchoGrot.KAMER_SPAWN)
	var kamer_ok := await _wacht_pad(EchoGrot.KAMER)
	await _wacht_fade()
	check("ECHO's Kamer laadt", kamer_ok)
	if not kamer_ok:
		return
	check("ECHO in de geladen kamer", _echo_node() != null and _player() != null)
	if not _praat():
		return
	var eerste := await _naar_tekst(EchoGrot.ZIN_EERSTE)
	var live_naam := Dialog.name_label.text == "ECHO" and Dialog.name_label.text != "IVA"
	check("eerste-bezoekzin", eerste and EchoGrot.ZIN_EERSTE == eerste_letterlijk and live_naam)
	check("naam ECHO en niet IVA", str(Dialoog.NAAM) == "ECHO" and str(Dialoog.NAAM) != "IVA"
			and welkom.contains("ECHO") and not welkom.contains("IVA") and live_naam)
	check("menu Diepe Grot Simulatie", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE))
	_kies(EchoGrot.OPTIE_TWIJFEL)
	check("bij twijfel de taakzin", await _naar_tekst(EchoGrot.ZIN_TWIJFEL))
	check("menu terug na twijfel", await _naar_keuze(EchoGrot.OPTIE_DATA))
	_kies(EchoGrot.OPTIE_DATA)
	check("over de data", await _naar_tekst(EchoGrot.ZIN_DATA))
	check("menu terug na de data", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE))
	_kies(EchoGrot.OPTIE_SIMULATIE)
	var startmenu := await _naar_keuze(EchoGrot.KEUZE_START)
	check("keuze start of terug", startmenu and _keuze_index(EchoGrot.KEUZE_TERUG) >= 0
			and Dialog.choices.size() == 2)
	_kies(EchoGrot.KEUZE_TERUG)
	var terug_menu := await _naar_keuze(EchoGrot.KEUZE_TERUG)
	check("ga terug houdt de kamer", terug_menu and scene().scene_file_path == EchoGrot.KAMER
			and GameState.dungeon100_floor == 0
			and str(GameState.party[0].get("equip", {}).get("wapen", "")) == "kort_zwaard")
	_kies(EchoGrot.KEUZE_TERUG)
	var dicht := await _wacht_gesprek_weg()
	check("gesprek sluit", dicht)

	GameState.story_flags[EchoGrot.FLAG_H6] = true
	if not _praat():
		check("na H-6 de kandidatenzin", false)
		return
	check("na H-6 de kandidatenzin", await _naar_tekst(h6_letterlijk))
	check("menu na H-6", await _naar_keuze(EchoGrot.KEUZE_TERUG))
	_kies(EchoGrot.KEUZE_TERUG)
	await _wacht_gesprek_weg()

	if not _praat():
		check("startmenu zonder herhaling", false)
		return
	check("startmenu zonder herhaling", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE))
	_kies(EchoGrot.OPTIE_SIMULATIE)
	check("start staat klaar", await _naar_keuze(EchoGrot.KEUZE_START))
	_kies(EchoGrot.KEUZE_START)
	var grot := await _wacht_pad(DUNGEON)
	await _wacht_fade()
	var kaal := grot and GameState.dungeon100_floor == 1 and int(GameState.party[0]["level"]) == 1 \
			and str(GameState.party[0].get("equip", {}).get("wapen", "")) == "" \
			and (GameState.party[0].get("spells", []) as Array).is_empty() and GameState.dungeon100_run_active()
	check("floor 1 level 1 zonder uitrusting", kaal)
	check("start alleen via ECHO", wereld_dicht and kaal and scene().scene_file_path == DUNGEON)
	if not grot:
		return

	GameState.inventory["warp"] = 1
	GameState.dungeon100_floor = 100
	var terug := GameState.dungeon100_warp()
	var kamer2 := await _wacht_pad(EchoGrot.KAMER)
	await _wacht_fade()
	check("terugkeer na floor 100", terug and kamer2 and scene().scene_file_path == EchoGrot.KAMER
			and not GameState.dungeon100_run_active() and GameState.dungeon100_floor == 0
			and int(GameState.party[0]["level"]) == 8
			and str(GameState.party[0].get("equip", {}).get("wapen", "")) == "kort_zwaard"
			and GameState.story_flags.get(EchoGrot.FLAG_RESULTAAT, false) == true)
	if not _praat():
		check("ECHO na terugkeer", false)
		return
	check("ECHO toont het resultaat", await _naar_tekst(EchoGrot.ZIN_RESULTAAT))
	check("volgende run staat in het menu", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE))
	_kies(EchoGrot.OPTIE_SIMULATIE)
	check("volgende run kan starten", await _naar_keuze(EchoGrot.KEUZE_START))
	_kies(EchoGrot.KEUZE_START)
	var nog := await _wacht_pad(DUNGEON)
	await _wacht_fade()
	check("tweede run is weer floor 1 level 1 zonder uitrusting", nog and GameState.dungeon100_floor == 1
			and int(GameState.party[0]["level"]) == 1
			and str(GameState.party[0].get("equip", {}).get("wapen", "")) == ""
			and GameState.dungeon100_run_active())


func _wereld_weigert() -> bool:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.change_map(WERELD, "van_dorp")
	if not await _wacht_scene("Wereldkaart"):
		check("wereldkaart voor de grot", false)
		return false
	await _wacht_fade()
	var ex: Node = scene().get_node_or_null("Exits/NaarDiepeGrot")
	var oud := Vector2i(9, 26)
	_player().place_at(oud + Vector2i.DOWN, Vector2i.UP)
	await _pframes(2)
	await _loop("move_up")
	var tegel: Vector2i = _player().get_tile()
	var dicht := scene().name == "Wereldkaart" and tegel == oud and ex == null and not Dialog.is_open \
			and GameState.dungeon100_floor == 0 and not GameState.dungeon100_run_active()
	check("wereldkaart start de grot niet", dicht)
	return dicht


func _praat() -> bool:
	var echo := _echo_node()
	var pl := _player()
	if echo == null or pl == null or echo.get_node_or_null("Gesprek") != null:
		return false
	echo.interact(pl)
	return true


func _wacht_gesprek_weg() -> bool:
	return await _wacht(func() -> bool:
		var echo := _echo_node()
		return not Dialog.is_open and echo != null and echo.get_node_or_null("Gesprek") == null
	, 3.0)


func _echo_node() -> Node:
	var sc := scene()
	if sc == null:
		return null
	return sc.get_node_or_null("Objects/Echo")


func _player() -> Node:
	var sc := scene()
	if sc == null:
		return null
	return sc.get_node_or_null("Objects/Player")


func _keuze_index(optie: String) -> int:
	var i := 0
	for c in Dialog.choices:
		if str(c) == optie:
			return i
		i += 1
	return -1


func _kies(optie: String) -> bool:
	var i := _keuze_index(optie)
	if i < 0 or not Dialog.has_choices():
		return false
	Dialog.choose(i)
	return true


func _naar_tekst(zin: String) -> bool:
	for _i in 80:
		if Dialog.is_open and str(Dialog.text_label.text) == zin:
			return true
		if Dialog.is_open and Dialog.has_choices() and Dialog._is_typing():
			Dialog.advance()
		elif Dialog.is_open and not Dialog.has_choices():
			Dialog.advance()
		await _pframes(2)
	return Dialog.is_open and str(Dialog.text_label.text) == zin


func _naar_keuze(optie: String) -> bool:
	for _i in 80:
		if Dialog.has_choices() and Dialog._is_typing():
			Dialog.advance()
		elif Dialog.has_choices() and _keuze_index(optie) >= 0:
			return true
		elif Dialog.is_open and not Dialog.has_choices():
			Dialog.advance()
		await _pframes(2)
	return Dialog.has_choices() and _keuze_index(optie) >= 0


func _loop(action: String) -> void:
	var p := _player()
	if p == null:
		return
	Input.action_press(action)
	var gewacht := 0
	while is_instance_valid(p) and not p.is_moving and gewacht < 8:
		await get_tree().physics_frame
		gewacht += 1
	Input.action_release(action)
	while is_instance_valid(p) and p.is_moving:
		await get_tree().physics_frame


func scene() -> Node:
	return get_tree().current_scene


func _wacht_scene(naam: String, timeout := 15.0) -> bool:
	return await _wacht(func() -> bool:
		var sc := scene()
		return sc != null and sc.name == naam and sc.is_node_ready() and not GameState.changing_map
	, timeout)


func _wacht_pad(pad: String, timeout := 15.0) -> bool:
	return await _wacht(func() -> bool:
		var sc := scene()
		return sc != null and sc.scene_file_path == pad and sc.is_node_ready() and not GameState.changing_map
	, timeout)


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _wacht_fade() -> void:
	await _wacht(func() -> bool: return Transition._rect.color.a <= 0.01, 3.0)
	await _pframes(2)


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


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
