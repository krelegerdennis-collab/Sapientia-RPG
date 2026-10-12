extends Node
## Extra kamers van de World Warper.
## Start: godot --path . -- --warperkamertest [--shots=/pad/map]

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const Dialoog := preload("res://world_warper/guide/dialoog.gd")
const Destinations := preload("res://world_warper/warp/destinations.gd")
const DestTest := preload("res://world_warper/warp/destinations_test.gd")
const SavePunt := preload("res://world_warper/services/save_point.gd")
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
	check("na De Genezer is ECHO's Kamer open", Kamers.hub_open(na_genezer)
			and Kamers.is_open("echo_kamer", na_genezer, act1))
	var alleen_bewaker := {Unlock.BEWAKER_VLAG: true}
	check("Genezer-vlag opent ECHO's Kamer", Kamers.is_open("echo_kamer", alleen_bewaker, act1))
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
			var grot := node.get_node_or_null("Objects/Grot")
			check("ingang Diepe Grot staat in ECHO's Kamer", grot != null
					and str(grot.get("bron")) == "grot_ingang"
					and Kamers.label("grot_ingang") == "Diepe Grot")
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
	var kisten := _kisten()
	var speler := _player()
	var pos: Dictionary = SavePunt.positie_van(speler)
	check("savepunt leest de spelertegel", speler != null and pos["tile"] == speler.get_tile() and pos["facing"] == speler.facing)
	check("eerste bezoek: kisten leeg en donker", kisten != null and kisten.gevuld_aantal() == 0 and kisten.licht_aantal() == 0)
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
			and ExitWarper.WARNING == "Weet je zeker dat je de dungeon wilt verlaten?"
			and ExitWarper.YES == "Ja, warpen naar worldmap"
			and ExitWarper.NO == "Nee, blijf in de dungeon")
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
	check("de molen zet nog iemand vooraan", molen.contains("move_member_to_front") and molen.contains("Wie gaat voorop?"))
	check("de Rustkamer wisselt via de bank", prop.contains("PartyWissel") and prop.contains("ALLEEN_HIER"))
	GameState.new_game("Dennis")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	var goud := GameState.gold
	check("buiten de Rustkamer geen wissel", PartyBench.naar_bank(1, "res://scenes/maps/dorp_wilgendal.tscn") == PartyBench.ALLEEN_HIER
			and GameState.party.size() == 3)
	check("Dennis blijft in de groep", PartyBench.naar_bank(0, PartyBench.RUSTKAMER) == PartyBench.DENNIS_BLIJFT
			and str(GameState.party[0]["id"]) == "dennis")
	var naar := PartyBench.naar_bank(2, PartyBench.RUSTKAMER)
	check("Lotte gratis op de bank", naar == PartyBench.OP_BANK % "Lotte" and GameState.gold == goud
			and GameState.party.size() == 2 and GameState.party_bench.size() == 1
			and str(GameState.party_bench[0]["id"]) == "lotte")
	var terug := PartyBench.naar_groep(0, PartyBench.RUSTKAMER)
	check("Lotte terug, nog steeds gratis", terug == PartyBench.IN_GROEP % "Lotte" and GameState.gold == goud
			and GameState.party_bench.is_empty() and GameState.party.size() == 3)
	var gast := {"id": "gast", "name": "Gast", "species": "mosslijm", "uid": "tijdelijk-1", "tijdelijk": true}
	GameState.party.append(gast)
	check("Codex-gast niet op de bank", PartyBench.naar_bank(GameState.party.size() - 1, PartyBench.RUSTKAMER) == PartyBench.GAST_BLIJFT)
	GameState.party.pop_back()
	GameState.party.append(GameState.hero_template("noor"))
	PartyBench.normaliseer()
	check("maximaal 3 actief", GameState.party.size() == PartyBench.MAX_ACTIEF and GameState.party_bench.size() == 1)
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
	var leeg := SavePunt.positie_van(null)
	check("zonder speler valt de tegel terug", leeg["tile"] == Vector2i.ZERO and leeg["facing"] == Vector2i.DOWN)


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
	check("na De Genezer staat de party in het exterieur", ging and buiten
			and GameState.world_warper_is_unlocked() and not NaGenezer.pending)
	NaGenezer.pending = false


func _kisten() -> EchoKisten:
	var sc := scene()
	if sc == null:
		return null
	return sc.get_node_or_null("Objects/Kisten") as EchoKisten


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
