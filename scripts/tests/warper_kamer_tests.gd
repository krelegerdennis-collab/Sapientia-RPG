extends Node
## Extra kamers van de World Warper.
## Start: godot --path . -- --warperkamertest [--shots=/pad/map]

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Dialoog := preload("res://world_warper/guide/dialoog.gd")
const Destinations := preload("res://world_warper/warp/destinations.gd")
const DestTest := preload("res://world_warper/warp/destinations_test.gd")
const NaGenezer := preload("res://world_warper/flow/na_genezer.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const Enter := preload("res://world_warper/flow/enter.gd")
const A2Warpers := preload("res://scripts/dungeon/archief2_warpers.gd")
const A1Warpers := preload("res://scripts/dungeon/archief_warpers.gd")
const ExitWarper := preload("res://scripts/dungeon/dungeon_exit_warper.gd")
const Kisten := preload("res://world_warper/kamers/echo_kisten.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const Gear := preload("res://scripts/equipment.gd")
const SD := preload("res://scripts/data/story_data.gd")
const QL := preload("res://world_warper/data/echo_questlog.gd")
const QLScherm := preload("res://scripts/ui/questlog_screen.gd")
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const DUNGEON := "res://scenes/maps/dungeon100.tscn"
const HUBHAL := "res://world_warper/maps/hal.tscn"

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
	# De wereldkaart laadt op de achtergrond (GameState._start_preload). Een
	# synchrone load() tussendoor wacht op die thread, en die thread wacht op
	# de hoofdthread. Eerst laten eindigen.
	await _wacht_voorgeladen()
	_vlag_en_act()
	_echo_hint()
	_buit_en_tekst()
	_update2_regels()
	_scènes()
	await _hal_in_beeld()
	await _echo_grot()
	await _genezer_warp()
	await _hal_simulatie()
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
	var na_genezer := {Unlock.UNLOCK_VLAG: true}
	check("na The Mender is ECHO's Chamber open", Kamers.hub_open(na_genezer)
			and Kamers.is_open("echo_kamer", na_genezer, act1))
	var alleen_bewaker := {Unlock.BEWAKER_VLAG: true}
	check("Genezer-vlag opent ECHO's Chamber", Kamers.is_open("echo_kamer", alleen_bewaker, act1))
	for id in ["hal", "rustkamer", "echo_kamer", "beeldkamer", "trainingshal", "kern"]:
		check("dicht zonder vlag: " + id, not Kamers.is_open(id, leeg, act2))
	check("met vlag is The Atrium open", Kamers.is_open("hal", open, act1) and Kamers.naam("hal") == "The Atrium")
	check("met vlag is de Rustkamer open", Kamers.is_open("rustkamer", open, act1))
	check("met vlag is ECHO's Chamber open", Kamers.is_open("echo_kamer", open, act1))
	check("Beeldkamer dicht in act 1", not Kamers.is_open("beeldkamer", open, act1))
	check("Beeldkamer dicht op level 13", not Kamers.is_open("beeldkamer", open, act1_laat))
	check("Beeldkamer open in act 2", Kamers.is_open("beeldkamer", open, act2) and GameData.act_for_level(14) == 2)
	check("Trainingshal dicht in act 2", not Kamers.is_open("trainingshal", open, act2))
	check("Trainingshal open in act 3", Kamers.is_open("trainingshal", open, _party(20)) and GameData.act_for_level(20) == 3)
	check("Werkplaats open vanaf act 4", Kamers.is_open("werkplaats", open, _party(26)))
	check("Handelskamer open vanaf act 5", Kamers.is_open("handelskamer", open, _party(32)))
	check("Kern dicht vóór act 6", not Kamers.is_open("kern", open, _party(36)))
	check("Kern open in act 6", Kamers.is_open("kern", open, _party(37)) and Kamers.naam("kern") == "The Core")
	check("onbekende kamer blijft dicht", not Kamers.is_open("hanger_nis", open, _party(40)))


func _wacht_voorgeladen() -> void:
	var t0 := Time.get_ticks_msec()
	while GameState._preloading.size() > 0 and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	check("voorgeladen kaarten zijn binnen", GameState._preloading.is_empty())


func _echo_hint() -> void:
	var test: GDScript = load("res://world_warper/guide/dialoog_test.gd") as GDScript
	if test == null:
		check("ECHO-hint en gidsdialoog", false)
		return
	var fouten: Array = test.fouten()
	check("ECHO-hint en gidsdialoog", fouten.is_empty())
	for regel in fouten:
		print("INFO  ", regel)


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
	check("handelstekst", Kamers.HANDEL_DICHT == "The shop is still closed.")
	var doelen := Kamers.warp_doelen()
	var ids: Array[String] = []
	for d in doelen:
		ids.append(str(d.get("id", "")))
	check("warp naar Willowdale", doelen.size() == 1 and str(doelen[0]["spawn"]) == "van_wilgendal"
			and str(doelen[0]["path"]) == "res://scenes/maps/wereldkaart.tscn")
	check("geen WM2/WM3", not ids.has("WM2") and not ids.has("WM3"))
	var wereld: Node = load("res://scenes/maps/wereldkaart.tscn").instantiate()
	check("spawn van_wilgendal bestaat", wereld.get_node_or_null("Spawns/van_wilgendal") != null)
	wereld.free()
	check("ECHO bedient alleen de hub", Kamers.ECHO_REGELS == ["I operate this hub."])
	check("ECHO noemt geen onderzoeker", not " ".join(Kamers.ECHO_REGELS).to_lower().contains("onderzoeker"))
	check("kernzin zonder onthulling", Kamers.KERN_ZIN == "The story of H-6 ends here.")
	var schoon := true
	for regel in Kamers.speler_teksten():
		if regel.to_lower().contains("proefpersoon"):
			schoon = false
			print("INFO  Proefpersoon in: ", regel)
	check("geen Proefpersoon in de kamertekst", schoon)
	var groep: Array = [{"name": "Dax", "hp": 1, "max_hp": 10, "mp": 0, "max_mp": 4},
			{"name": "Vesper", "hp": 2, "max_hp": 8, "mp": 1, "max_mp": 6}]
	Kamers.helen(groep)
	check("helen vult HP en MP", int(groep[0]["hp"]) == 10 and int(groep[1]["mp"]) == 6)
	check("wissel zet Vesper vooraan", Kamers.naar_voren(groep, 1) and str(groep[0]["name"]) == "Vesper")
	check("vooraan wisselt niet met zichzelf", not Kamers.naar_voren(groep, 0))
	var regels := Kamers.voortgang_regels(0, {}, "")
	check("voortgang noemt de stap", regels.size() == 3 and regels[0].begins_with("Story step:"))
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
			check("ECHO staat in ECHO's Chamber", echo != null and str(echo.get("bron")) == "echo_grot")
			var grot := node.get_node_or_null("Objects/Grot")
			check("ingang Deep Learning Simulation staat in ECHO's Chamber", grot != null
					and str(grot.get("bron")) == "grot_ingang"
					and Kamers.label("grot_ingang") == "Deep Learning Simulation")
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
	check("The Atrium laadt", sc != null and str(sc.get("map_name")) == "The Atrium")
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
	var eerste_letterlijk := "The Deep Learning Simulation. An AI training program — a hundred floors, different every time. I run it. Sapientia... Sapientia helps with the data. That's just how it works."
	var twijfel_letterlijk := "Why I do it? Because it is my task. The Old Humanity built me to measure, to count, to preserve."
	var h6_letterlijk := "I have let hundreds of candidates through. You are the sixth who stayed standing. The others... I don't know what happened to them."
	var data_letterlijk := "I don't know. I deliver, she takes. It has always been that way."
	check("grotzinnen letterlijk", EchoGrot.ZIN_EERSTE == eerste_letterlijk and EchoGrot.ZIN_TWIJFEL == twijfel_letterlijk
			and EchoGrot.ZIN_H6 == h6_letterlijk and EchoGrot.ZIN_DATA == data_letterlijk)
	check("ECHO legt de onderzoeker-twist niet uit", not " ".join(EchoGrot.speler_teksten()).to_lower().contains("onderzoeker"))
	check("voor H-6 alleen de eerste zin", EchoGrot.regels_vooraf({}) == [EchoGrot.ZIN_EERSTE])
	check("later bezoek herhaalt de zin niet", EchoGrot.regels_vooraf({EchoGrot.FLAG_EERSTE: true}).is_empty())
	var gezien := {}
	EchoGrot.markeer(gezien, [EchoGrot.ZIN_EERSTE])
	check("vlag echo_grot_gezien na de eerste zin", gezien.get(EchoGrot.FLAG_EERSTE, false) == true
			and EchoGrot.regels_vooraf(gezien).is_empty() and not gezien.has(EchoGrot.FLAG_H6))
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
	check("ECHO's Chamber laadt", kamer_ok)
	if not kamer_ok:
		return
	check("ECHO in de geladen kamer", _echo_node() != null and _player() != null)
	var kisten := _kisten()
	check("eerste bezoek: kisten leeg en donker", kisten != null and kisten.gevuld_aantal() == 0 and kisten.licht_aantal() == 0)
	if not _praat():
		return
	var eerste := await _naar_tekst(EchoGrot.ZIN_EERSTE)
	var live_naam := Dialog.name_label.text == "ECHO" and Dialog.name_label.text != "IVA"
	check("eerste-bezoekzin", eerste and EchoGrot.ZIN_EERSTE == eerste_letterlijk and live_naam)
	if eerste and Dialog._is_typing():
		Dialog.advance()
	if eerste:
		await _screenshot("echo_eerste_bezoek")
	check("naam ECHO en niet IVA", str(Dialoog.NAAM) == "ECHO" and str(Dialoog.NAAM) != "IVA"
			and welkom.contains("ECHO") and not welkom.contains("IVA") and live_naam)
	check("menu Deep Learning Simulation", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE)
			and EchoGrot.OPTIE_SIMULATIE == "Deep Learning Simulation")
	await _screenshot("dls_naam_echo_menu")
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
	check("vlag na het eerste gesprek", GameState.story_flags.get(EchoGrot.FLAG_EERSTE, false) == true)
	if not _praat():
		check("tweede bezoek slaat de zin over", false)
		return
	var tweede_open := await _wacht(func() -> bool: return Dialog.is_open, 3.0)
	var tweede_tekst := str(Dialog.text_label.text) if Dialog.is_open else ""
	check("tweede bezoek slaat de zin over", tweede_open and Dialog.has_choices()
			and tweede_tekst == EchoGrot.VRAAG_MENU
			and tweede_tekst != EchoGrot.ZIN_EERSTE
			and tweede_tekst != EchoGrot.ZIN_H6)
	_kies(EchoGrot.KEUZE_TERUG)
	check("tweede gesprek sluit", await _wacht_gesprek_weg())

	await _questlog_tests()

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
	var terug := GameState.dungeon100_warp("ring")
	var kamer2 := await _wacht_pad(EchoGrot.KAMER)
	await _wacht_fade()
	check("terugkeer na floor 100", terug and kamer2 and scene().scene_file_path == EchoGrot.KAMER
			and not GameState.dungeon100_run_active() and GameState.dungeon100_floor == 0
			and int(GameState.party[0]["level"]) == 8
			and str(GameState.party[0].get("equip", {}).get("wapen", "")) == "kort_zwaard"
			and GameState.story_flags.get(EchoGrot.FLAG_RESULTAAT, false) == true)
	var na_run := _kisten()
	check("na één run licht één kist, act 1 blijft leeg", na_run != null and GameState.echo_grot_voltooid == 1
			and na_run.licht_aantal() == 1 and na_run.gevuld_aantal() == 0)
	if na_run != null:
		na_run.pas_toe(3, 1)
		check("act 3 vult de eerste kist", na_run.gevuld_aantal() == 1 and na_run.licht_aantal() == 1)
		na_run.pas_toe(4, 2)
		check("act 4 vult twee kisten", na_run.gevuld_aantal() == 2)
		na_run.pas_toe(5, 3)
		check("act 5 vult alle drie", na_run.gevuld_aantal() == 3 and na_run.licht_aantal() == 3)
		na_run.pas_toe(6, 3)
		var echo := _echo_node()
		var spr := echo.get_node_or_null("Sprite2D") as CanvasItem if echo != null else null
		check("act 6 pulse en ECHO feller", na_run._pulse and spr != null and spr.modulate == Kisten.ECHO_FELLER)
		na_run.pas_toe(1, 1)
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


func _update2_regels() -> void:
	var fouten := DestTest.bezoek_filter()
	check("warp alleen bezochte plekken op WM1", fouten.is_empty())
	for regel in fouten:
		print("INFO  ", regel)
	var begin := ExitWarper.new()
	begin.role = "begin"
	var midden := ExitWarper.new()
	midden.role = "midden"
	check("begin-warper zonder waarschuwing, midden met", not begin.waarschuwt() and midden.waarschuwt()
			and ExitWarper.WARNING == "Are you sure you want to leave the dungeon?"
			and ExitWarper.YES == "Yes, warp to the world map"
			and ExitWarper.NO == "No, stay in the dungeon")
	begin.free()
	midden.free()
	var plekken: Array = A2Warpers.placements()
	var rollen := {}
	for plek in plekken:
		rollen[str(plek["role"])] = plek
	var kamers: Dictionary = DR.archief2().rooms()
	var a1_alleen := true
	for plek in A1Warpers.placements():
		if not DR.ROOMS.has(str(plek["room"])):
			a1_alleen = false
	check("Archief 2 heeft begin, midden en eind", plekken.size() == 3 and rollen.has("begin")
			and rollen.has("midden") and rollen.has("eind")
			and str(rollen["midden"]["room"]) == "archief_2_v3_wurger"
			and str(rollen["eind"]["room"]) == "archief_2_v4_genezer"
			and str(rollen["begin"]["world_spawn"]) == "van_kas"
			and A1Warpers.walkable(kamers["archief_2_v1_entree"], rollen["begin"]["tile"])
			and A1Warpers.walkable(kamers["archief_2_v3_wurger"], rollen["midden"]["tile"])
			and A1Warpers.walkable(kamers["archief_2_v4_genezer"], rollen["eind"]["tile"])
			and a1_alleen and A1Warpers.placements().size() == 3)
	check("kisten per act", Kisten.gevulde(1) == 0 and Kisten.gevulde(2) == 0 and Kisten.gevulde(3) == 1
			and Kisten.gevulde(4) == 2 and Kisten.gevulde(5) == 3 and Kisten.gevulde(6) == 3
			and not Kisten.pulseren(5) and Kisten.pulseren(6) and Kisten.echo_feller(6)
			and not Kisten.echo_feller(5))
	var vlaggen := {}
	check("run telt één keer", Kisten.tel_resultaat(vlaggen, 0) == 0)
	vlaggen[EchoGrot.FLAG_RESULTAAT] = true
	var een := Kisten.tel_resultaat(vlaggen, 0)
	var nog := Kisten.tel_resultaat(vlaggen, een)
	check("resultaat licht één extra kist", een == 1 and nog == 1 and vlaggen.get(Kisten.FLAG_GETELD, false) == true
			and vlaggen.get(EchoGrot.FLAG_RESULTAAT, false) == true)
	vlaggen.erase(EchoGrot.FLAG_RESULTAAT)
	check("geteld gaat weg als het resultaat weg is", Kisten.tel_resultaat(vlaggen, een) == een
			and not vlaggen.has(Kisten.FLAG_GETELD))
	var molen := FileAccess.get_file_as_string("res://scripts/village/molen.gd")
	var prop := FileAccess.get_file_as_string("res://world_warper/kamers/prop.gd")
	check("de molen zet nog iemand vooraan", molen.contains("move_member_to_front") and molen.contains("Who leads the way?"))
	check("de Rustkamer wisselt via de bank", prop.contains("PartyWissel") and prop.contains("ALLEEN_HIER"))
	GameState.new_game("Dax")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	var goud := GameState.gold
	check("buiten de Rustkamer geen wissel", PartyBench.naar_bank(1, "res://scenes/maps/dorp_wilgendal.tscn") == PartyBench.ALLEEN_HIER
			and GameState.party.size() == 3)
	check("Dax blijft in de groep", PartyBench.naar_bank(0, PartyBench.RUSTKAMER) == PartyBench.DENNIS_BLIJFT
			and str(GameState.party[0]["id"]) == "dennis")
	var naar := PartyBench.naar_bank(2, PartyBench.RUSTKAMER)
	check("Seren gratis op de bank", naar == PartyBench.OP_BANK % "Seren" and GameState.gold == goud
			and GameState.party.size() == 2 and GameState.party_bench.size() == 1
			and str(GameState.party_bench[0]["id"]) == "lotte")
	var terug := PartyBench.naar_groep(0, PartyBench.RUSTKAMER)
	check("Seren terug, nog steeds gratis", terug == PartyBench.IN_GROEP % "Seren" and GameState.gold == goud
			and GameState.party_bench.is_empty() and GameState.party.size() == 3)
	var gast := {"id": "gast", "name": "Gast", "species": "mosslijm", "uid": "tijdelijk-1", "tijdelijk": true}
	GameState.party.append(gast)
	check("Codex-gast niet op de bank", PartyBench.naar_bank(GameState.party.size() - 1, PartyBench.RUSTKAMER) == PartyBench.GAST_BLIJFT)
	GameState.party.pop_back()
	GameState.party.append(GameState.hero_template("lotte"))   # v0.22: max 4 actief, dus 5 nodig
	GameState.party.append(GameState.hero_template("noor"))
	PartyBench.normaliseer()
	check("maximaal %d actief" % PartyBench.MAX_ACTIEF, GameState.party.size() == PartyBench.MAX_ACTIEF and GameState.party_bench.size() == 1)
	var pad := "user://warper_bank_test.json"
	var weg := GameState.save_game(Vector2i(4, 5), Vector2i.LEFT, pad)
	var ruw := GameState.read_save(pad)
	GameState.party_bench = []
	var geladen := GameState.load_game(pad)
	var bank_id := str(GameState.party_bench[0]["id"]) if GameState.party_bench.size() == 1 else ""
	var tegel := GameState._vec2i_from(ruw.get("tile"), Vector2i(-9, -9))
	var kijk := GameState._vec2i_from(ruw.get("facing"), Vector2i(9, 9))
	check("bank en tegel in de save", weg and geladen and bank_id == "noor"
			and str(GameState.party[0].get("id", "")) == "dennis"
			and tegel == Vector2i(4, 5) and kijk == Vector2i.LEFT)


func _genezer_warp() -> void:
	NaGenezer.pending = false
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_kern_absorb = ""
	NaGenezer.on_guard_flag("bewaker:archief_v2_trapzaal/m2", true)
	check("andere bewaker start de warp niet", not NaGenezer.pending)
	GameState.story_flags[Unlock.BEWAKER_VLAG] = true
	NaGenezer.on_guard_flag(Unlock.BEWAKER_VLAG, false)
	check("een oude Genezer-vlag warpt niet opnieuw", not NaGenezer.pending)
	GameState.pending_kern_absorb = "levenskern"
	NaGenezer.on_guard_flag(Unlock.BEWAKER_VLAG, true)
	check("de warp wacht op de kern", NaGenezer.pending and not NaGenezer.probeer())
	GameState.pending_kern_absorb = ""
	var ging := NaGenezer.probeer()
	var buiten := await _wacht_pad(Enter.HUB_SCENE, 20.0)
	await _wacht_fade()
	check("na The Mender staat de party in het exterieur", ging and buiten
			and GameState.world_warper_is_unlocked() and not NaGenezer.pending)
	NaGenezer.pending = false


func _kisten() -> EchoKisten:
	var sc := scene()
	if sc == null:
		return null
	return sc.get_node_or_null("Objects/Kisten") as EchoKisten


func _wereld_weigert() -> bool:
	GameState.new_game("Dax")
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


## v0.24 ECHO-questlog: data (statussen per act) + live in ECHO's Kamer (lijst, act 1, act 3, terug).
func _questlog_tests() -> void:
	var leeg := {}
	check("questlog: 6 acts, Nederlandse ids", QL.ids() == ["akte_1", "akte_2", "akte_3", "akte_4", "akte_5", "akte_6"])
	check("questlog: nieuw spel -> Act 1 Active, Act 2 Locked, Act 3-6 Upcoming",
			QL.status("akte_1", leeg, 0) == QL.OPEN and QL.status("akte_2", leeg, 0) == QL.DICHT
			and ["akte_3", "akte_4", "akte_5", "akte_6"].all(func(i): return QL.status(i, leeg, 0) == QL.LATER))
	var a1 := {SD.GOLEM_FLAG: true, "noor_gered": true}
	check("questlog: Golem zonder Vesper -> Act 1 nog Active, Act 2 Locked",
			QL.status("akte_1", {SD.GOLEM_FLAG: true}, SD.NACHT) == QL.OPEN
			and QL.status("akte_2", {SD.GOLEM_FLAG: true}, SD.NACHT) == QL.DICHT)
	check("questlog: Golem + Vesper + Archieven in -> Act 1 Done, Act 2 Active",
			QL.status("akte_1", a1, SD.NACHT) == QL.KLAAR and QL.status("akte_2", a1, SD.NACHT) == QL.OPEN)
	check("questlog: Golem zonder verhaalstap -> Act 1 nog Active", QL.status("akte_1", a1, SD.START) == QL.OPEN)
	var a2 := {SD.GOLEM_FLAG: true, "noor_gered": true, "archief2_lotte_lid": true, Unlock.BEWAKER_VLAG: true, Unlock.UNLOCK_VLAG: true}
	check("questlog: na De Genezer -> Act 2 Done, Act 3 Upcoming (geen inhoud)",
			QL.status("akte_2", a2, SD.NACHT) == QL.KLAAR and QL.status("akte_3", a2, SD.NACHT) == QL.LATER)
	check("questlog: keuzes = 6 acts + Go back", QL.keuzes(a1, SD.NACHT) == ["Act 1 - Done", "Act 2 - Active",
			"Act 3 - Upcoming", "Act 4 - Upcoming", "Act 5 - Upcoming", "Act 6 - Upcoming", "Go back"])
	var r1 := QL.regels("akte_1", a1, SD.NACHT)
	check("questlog: Act 1 = ECHO-zin + opdrachten afgevinkt", r1.size() == 2 and r1[0] == QL.akte("akte_1")["echo_klaar"]
			and r1[1].contains("[x] Defeat the Golem") and r1[1].contains("[x] The Archives of Sapientia")
			and r1[1].contains("[x] Save Vesper from the Dark Wood"))
	var r2 := QL.regels("akte_2", {SD.GOLEM_FLAG: true, "noor_gered": true}, SD.NACHT)
	check("questlog: Act 2 zonder Vesper, Seren [ ]", not r2[1].contains("Vesper") and r2[1].contains("[ ] Seren joins"))
	check("questlog: Act 2 klaar = canonzin ECHO", QL.regels("akte_2", a2, SD.NACHT)[0] == "Two Archives active. World Warper online.")
	var rd := QL.regels("akte_2", leeg, 0)
	var rl := QL.regels("akte_4", a2, SD.NACHT)
	check("questlog: dichte act toont geen opdrachten (%s | %s)" % [rd, rl], rd.size() == 1 and rd[0] == QL.ZIN_DICHT
			and rl.size() == 1 and rl[0] == QL.ZIN_LATER)
	var eng := true
	for t in QL.speler_teksten():
		for nl in ["opdracht", "klaar", "akte", "archief", "verslaan", "proefpersoon", "onderzoeker"]:
			if t.to_lower().contains(nl):
				eng = false
				print("INFO  niet-Engels/onthulling in: ", t)
	check("questlog: spelertekst Engels, geen onthulling", eng)
	check("questlog: in het ECHO-menu", EchoGrot.menu_opties().has(EchoGrot.OPTIE_QUESTLOG))

	# zijopdrachten (Side-tab): eerst alleen de NPC-naam, na het gesprek de opdracht
	var zg: Dictionary = QL.ZIJ[0]
	check("side: Het Zingende Graan hoort bij Gerrit", str(zg["id"]) == "zingend_graan" and str(zg["npc"]) == SD.GERRIT
			and str(zg["start"]) == SD.FLAG_GRAAN and str(zg["klaar"]) == SD.FLAG_GRAAN_KLAAR)
	check("side: niet gesproken -> alleen de naam", QL.zij_regels({}) == ["Gerrit the Miller"])
	check("side: gesproken -> [ ] The Singing Grain", QL.zij_regels({"gesproken_gerrit": true}) == ["[ ] The Singing Grain"])
	check("side: oude save met startvlag telt als gesproken", QL.zij_regels({SD.FLAG_GRAAN: true}) == ["[ ] The Singing Grain"])
	check("side: klaar -> [x]", QL.zij_regels({"gesproken_gerrit": true, SD.FLAG_GRAAN_KLAAR: true}) == ["[x] The Singing Grain"])
	var fixture := [{"id": "test_npc", "npc": "Test Keeper", "titel": "A Test Errand", "gesproken": "gesproken_test"}]
	check("side: fixture zonder start/klaar", QL.zij_regels({}, fixture) == ["Test Keeper"]
			and QL.zij_regels({"gesproken_test": true}, fixture) == ["[ ] A Test Errand"])
	var gesprek_zet := true
	for rij in SD.EVENTS["gerrit"]:
		var doe: Array = rij["do"]
		if not doe.is_empty():
			gesprek_zet = gesprek_zet and doe.any(func(x): return x == ["flag", "gesproken_gerrit"])
	check("side: elk gesprek met Gerrit zet gesproken_gerrit", gesprek_zet)
	await _questlog_scherm_tests()

	# live
	var bewaar := GameState.story_flags.duplicate()
	var stap_voor := GameState.story_step
	GameState.story_flags[SD.GOLEM_FLAG] = true
	GameState.story_flags["noor_gered"] = true
	GameState.story_flags.erase("archief2_lotte_lid")
	GameState.story_step = maxi(stap_voor, SD.NACHT)
	if not _praat():
		check("questlog live: gesprek", false)
		return
	check("questlog live: optie in het menu", await _naar_keuze(EchoGrot.OPTIE_QUESTLOG))
	_kies(EchoGrot.OPTIE_QUESTLOG)
	var lijst := await _naar_keuze(QL.TERUG)
	check("questlog live: lijst met acts", lijst and Dialog.choices.size() == 7 and str(Dialog.choices[0]) == "Act 1 - Done"
			and str(Dialog.choices[2]) == "Act 3 - Upcoming"
			and str(Dialog.choices[1]) == ("Act 2 - Done" if bewaar.has(Unlock.UNLOCK_VLAG) and bewaar.has("archief2_lotte_lid") else "Act 2 - Active"))
	await _pframes(10)
	check("questlog live: lijst binnen beeld", _vak_in_beeld())
	await _screenshot("echo_questlog_lijst")
	Dialog.choose(0)
	check("questlog live: Act 1 -> ECHO-zin", await _naar_tekst(str(QL.akte("akte_1")["echo_klaar"])))
	Dialog.advance()
	var blok := QL.regels("akte_1", GameState.story_flags, GameState.story_step)[1]
	check("questlog live: Act 1 opdrachten afgevinkt", await _naar_tekst(blok) and blok.contains("[x] Defeat the Golem")
			and blok.contains("[x] Save Vesper"))
	Dialog.advance()
	await _pframes(10)
	check("questlog live: opdrachtenvak binnen beeld", _vak_in_beeld())
	await _screenshot("echo_questlog_act1")
	Dialog.advance()
	check("questlog live: terug in de lijst", await _naar_keuze(QL.TERUG))
	Dialog.choose(1)
	var b2 := QL.regels("akte_2", GameState.story_flags, GameState.story_step)
	check("questlog live: Act 2 met [ ] Seren", await _naar_tekst(b2[0]) and b2[1].contains("[ ] Seren joins")
			and not b2[1].contains("Vesper"))
	Dialog.advance()
	if await _naar_tekst(b2[1]):
		Dialog.advance()
		await _pframes(10)
		await _screenshot("echo_questlog_act2")
	check("questlog live: lijst na Act 2", await _naar_keuze(QL.TERUG))
	Dialog.choose(2)
	check("questlog live: Act 3 = nog leeg", await _naar_tekst(QL.ZIN_LATER))
	await _pframes(10)
	await _screenshot("echo_questlog_act3")
	check("questlog live: weer de lijst", await _naar_keuze(QL.TERUG))
	_kies(QL.TERUG)
	check("questlog live: Go back -> ECHO-menu", await _naar_keuze(EchoGrot.OPTIE_SIMULATIE))
	_kies(EchoGrot.KEUZE_TERUG)
	check("questlog live: gesprek sluit", await _wacht_gesprek_weg())
	GameState.story_flags = bewaar
	GameState.story_step = stap_voor


## v0.24 Veldmenu > Quest Log: tabs Main/Side, screenshots (main, side op slot, side open).
func _questlog_scherm_tests() -> void:
	var bewaar := GameState.story_flags.duplicate()
	var stap_voor := GameState.story_step
	GameState.story_flags = {SD.GOLEM_FLAG: true, "noor_gered": true, "noor_lid": true}
	GameState.story_step = maxi(stap_voor, SD.NACHT)
	var scherm: CanvasLayer = QLScherm.new()
	scherm.layer = 120
	get_tree().root.add_child(scherm)
	await _pframes(5)
	check("veldmenu-questlog: Main met 6 acts", scherm.tab == "hoofd"
			and scherm.regel_teksten() == QL.keuzes(GameState.story_flags, GameState.story_step).slice(0, 6))
	scherm.toon_akte("akte_1")
	check("veldmenu-questlog: Act 1 = zelfde regels als ECHO",
			scherm.detail.text == "\n".join(QL.regels("akte_1", GameState.story_flags, GameState.story_step)))
	await _pframes(5)
	await _screenshot("questlog_menu_act1")
	scherm.back()
	await _pframes(3)
	check("veldmenu-questlog: B uit een act = terug naar de lijst", scherm.is_inside_tree() and scherm.list.visible
			and scherm.open_akte == "")
	await _screenshot("questlog_menu_main")
	scherm.kies_tab("zij")
	await _pframes(5)
	check("veldmenu-questlog: Side op slot = Gerrit the Miller", scherm.regel_teksten() == ["Gerrit the Miller"]
			and scherm.is_button_greyed(scherm.rows[0]))
	await _screenshot("questlog_menu_side_locked")
	GameState.story_flags["gesproken_gerrit"] = true
	scherm.kies_tab("hoofd")
	scherm.kies_tab("zij")
	await _pframes(5)
	check("veldmenu-questlog: Side na gesprek = opdracht", scherm.regel_teksten() == ["[ ] The Singing Grain"]
			and not scherm.is_button_greyed(scherm.rows[0]))
	await _screenshot("questlog_menu_side_unlocked")
	scherm.close()
	await _pframes(2)
	GameState.story_flags = bewaar
	GameState.story_step = stap_voor


func _vak_in_beeld() -> bool:
	var vp := Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)
	var r: Rect2 = Dialog.panel.get_global_rect()
	var ok := vp.encloses(r)
	if Dialog._choice_box != null and Dialog._choice_box.visible:
		ok = ok and vp.encloses(Dialog._choice_box.get_global_rect())
	if not ok:
		print("INFO  vak %s keuzes %s scherm %s" % [r, Dialog._choice_box.get_global_rect() if Dialog._choice_box else null, vp])
	return ok


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


## Dennis (14 okt 2026): warp-vlak naar de Deep Learning Simulation in de hal.
func _hal_simulatie() -> void:
	if GameState.dungeon100_run_active():
		GameState.dungeon100_end_run(false)
	GameState.story_flags[Kamers.FLAG_HUB] = true
	for f in ["ww_canon_genezer_gezien", "ww_canon_hanger_gezien", "ww_canon_dreiging_gezien"]:
		GameState.story_flags[f] = true      # geen canon-scène over het screenshot
	GameState.change_map(HUBHAL, "ingang")
	var ok := await _wacht_pad(HUBHAL)
	await _wacht_fade()
	await _pframes(6)
	var vlak: Node = scene().get_node_or_null("HubBoot/VlakSimulatie") if ok else null
	var label_ok := false
	if vlak != null:
		for c in vlak.get_children():
			if c is Label and c.text == "Deep Learning Simulation":
				label_ok = true
	check("hal: warp-vlak 'Deep Learning Simulation'", vlak != null and label_ok)
	var wl: Label = null
	var wv: Node = scene().get_node_or_null("HubBoot/VlakWarp") if ok else null
	if wv != null:
		for c in wv.get_children():
			if c is Label:
				wl = c
	check("hal: label 'Warp' op Dauwpixel 10 (1:1, de W blijft een W)", wl != null and wl.text == "Warp"
			and wl.get_theme_font_size("font_size") == 10)
	if vlak == null:
		return
	var p := _player()
	if p != null:
		p.place_at(Vector2i((vlak.global_position / 16.0).floor()) + Vector2i.DOWN, Vector2i.UP)
	await _pframes(4)
	await _screenshot("dls_warp_hal")
	var boot: Node = scene().get_node("HubBoot")
	vlak.interact(p)
	var vraag := await _naar_keuze(boot.SIMULATIE_NEE)
	check("vlak vraagt: Enter the Deep Learning Simulation?", vraag and str(Dialog.text_label.text) == boot.SIMULATIE_VRAAG)
	await _screenshot("dls_warp_vraag")
	_kies(boot.SIMULATIE_NEE)
	await _wacht_gesprek_weg()
	await _pframes(4)
	check("nee: blijft in de hal, speler vrij", boot.simulatie_uitkomst == "nee"
			and scene().scene_file_path == HUBHAL and not p.input_locked)
	vlak.interact(p)
	if await _naar_keuze(boot.SIMULATIE_JA):
		_kies(boot.SIMULATIE_JA)
	var binnen := await _wacht_pad(DUNGEON, 20.0)
	await _wacht_fade()
	await _pframes(10)
	check("ja: verdieping 1 van de simulatie, run actief", binnen
			and GameState.dungeon100_floor == 1 and GameState.dungeon100_run_active())
	await _screenshot("dls_hud_verdieping1")
	if GameState.dungeon100_run_active():
		GameState.dungeon100_end_run(false)
