extends RefCounted
## Vang-tutorial (Codex) + Golemhal-uitgang op slot tot de Inktwurm in de Codex staat, binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-codex-tutorial [--codex-tutorial-shots=/pad/map]
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.
## t = de autotest-node (check/pframes/wait_battle_state/choose_command/...).
## Delen: A data, B tutorial 1x (trigger-once), C uitgang op slot en weer open, D save/load van de vlag,
## E migratie van oude saves, F marker (een nieuwe save is nooit 'oud').

const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const GD := preload("res://scripts/data/game_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const GOLEM := SD.GOLEMHAL
const BIBLIOTHEEK := "res://scenes/maps/archief_bibliotheek.tscn"
const INGANG := "res://scenes/maps/archief_ingang.tscn"
const EV := SD.TUTORIAL_CODEX
const F_TUT1 := SD.TUTORIAL_INKTWURM_FLAG
const F_TUT2 := SD.TUTORIAL_CODEX_FLAG
const F_CODEX := SD.CODEX_INKTWURM_FLAG

var t: Node
var shots := ""


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--codex-tutorial-shots="):
			shots = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(shots)


func shot(naam: String) -> void:
	if shots != "":
		await t.screenshot(shots.path_join(naam + ".png"))


func run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	_data_checks()
	await _trigger_tests()
	await _lock_tests()
	await _save_tests()
	await _migration_tests()
	await _marker_tests()
	Settings.set_value("battle_style", oude_stijl)
	GameState.new_game("Dax")


# ================================================================ deel A: data
func _data_checks() -> void:
	var pages: Array = SD.TUT_CODEX_PAGES
	t.check("codex-tutorial: 3-5 pagina's (%d), elk max. 2 regels" % pages.size(), pages.size() >= 3 and pages.size() <= 5
			and pages.all(func(p): return str(p).split("\n").size() <= 2))
	var tekst := " ".join(pages)
	t.check("codex-tutorial: Engels, noemt Blank Book, Classic, Action, Codex en Ring",
			tekst.contains("Blank Book") and tekst.contains("Classic") and tekst.contains("Action")
			and tekst.contains("Codex") and tekst.contains("Ring"))
	t.check("codex-tutorial: Next/Skip op pagina 1-3, pagina 4 gewone tekst",
			SD.EVENTS[EV][0]["do"][1][2] == [SD.TUT_NEXT, SD.TUT_SKIP] and SD.EVENTS[EV + "_4"][0]["do"][0][0] == "say")
	t.check("codex-tutorial: vlag is het eerste commando, tweede variant doet niets",
			SD.EVENTS[EV][0]["do"][0] == ["flag", F_TUT2] and (SD.EVENTS[EV][1]["do"] as Array).is_empty())
	t.check("codex-tutorial: start vrij op de Golemhal, na de Inktwurm-tutorial",
			SD.FREE_EVENTS.size() == 1 and SD.FREE_EVENTS[0]["map"] == GOLEM and SD.FREE_EVENTS[0]["event"] == EV
			and SD.FREE_EVENTS[0]["if"] == {"flags": [F_TUT1], "not_flags": [F_TUT2]})
	t.check("oude Inktwurm-tutorial ongewijzigd (vlag en 4 pagina's)", SD.TUTORIAL_INKTWURM_FLAG == "tutorial_na_inktwurm_gezien"
			and SD.TUT_INKT_PAGES.size() == 4)
	t.check("Golemhal-uitgang heeft het slot-event, vlag per Codex-soort",
			DR.ROOMS["archief_golemhal"]["exits"]["U"]["event"] == SD.GOLEMHAL_EXIT
			and SD.CODEX_SPECIES_FLAGS.get("inktwurm") == F_CODEX and SD.EVENTS.has(SD.GOLEMHAL_EXIT))


# ================================================================ deel B: tutorial 1x
func _trigger_tests() -> void:
	# Hele keten: Inktwurm weg -> tutorial 1 -> (Next x3 + sluiten) -> vang-tutorial, elke pagina 1x.
	setup()
	var room := await enter(GOLEM, "zuid")
	t.check("Golemhal geladen", room != null)
	if room == null:
		return
	await t.pframes(70)
	t.check("nog geen Inktwurm-tutorial: de vang-tutorial wacht", not Story.history.has(EV) and not Story.running)
	var hist := Story.history.size()
	GameState.mark_defeated("inktwurm")
	t.check("tutorial 1 start in de Golemhal", await wait_until(func(): return Story.current_event == SD.TUTORIAL_INKTWURM, 5.0))
	for i in 3:
		await wait_page()
		await press()
	await wait_page()
	await press()
	t.check("na tutorial 1 start de vang-tutorial vanzelf op de kaart",
			await wait_until(func(): return Story.current_event == EV, 5.0) and scene() == room)
	t.check("vang-tutorial: vlag meteen gezet", GameState.story_flags.has(F_TUT2))
	t.check("pagina 1 als systeemvak met Next/Skip, past op 384x216", await wait_page() and Dialog.choices == [SD.TUT_NEXT, SD.TUT_SKIP]
			and Dialog.text_label.text == SD.TUT_CODEX_PAGES[0] and page_fits())
	await shot("codex_tutorial_1")
	await press()
	t.check("A = Next: pagina 2 (Classic)", await wait_page() and Story.current_event == EV + "_2"
			and Dialog.text_label.text == SD.TUT_CODEX_PAGES[1] and page_fits())
	await press()
	t.check("pagina 3 (Action: Codex-knop/Ring, zelfde regels)", await wait_page() and Story.current_event == EV + "_3"
			and Dialog.text_label.text == SD.TUT_CODEX_PAGES[2] and page_fits())
	await shot("codex_tutorial_3")
	await press()
	t.check("pagina 4: gewone tekst", await wait_page() and Dialog.choices.is_empty() and Story.current_event == EV + "_4"
			and Dialog.text_label.text == SD.TUT_CODEX_PAGES[3] and page_fits())
	await press()
	t.check("vang-tutorial klaar, speler weer vrij", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
			and await wait_until(func(): return not player().input_locked, 2.0))
	await t.pframes(120)
	var seen := Story.history.slice(hist)
	t.check("keten: elke pagina precies 1x %s" % [seen], seen.count(SD.TUTORIAL_INKTWURM) == 1 and seen.count(EV) == 1
			and seen.count(EV + "_2") == 1 and seen.count(EV + "_3") == 1 and seen.count(EV + "_4") == 1)
	t.check("daarna niets meer: geen herstart na 2 s vrij op de kaart", not Story.running and not Dialog.is_open)

	# Kaart opnieuw in: nooit twee keer.
	hist = Story.history.size()
	room = await enter(INGANG, "ingang")
	room = await enter(GOLEM, "zuid")
	await t.pframes(100)
	t.check("kaart opnieuw in: geen tutorial meer", room != null and not Story.history.slice(hist).has(EV) and not Story.running)

	# Skip op pagina 1 (tutorial 1 overgeslagen telt als gezien: de vang-tutorial komt toch).
	setup()
	GameState.story_flags[F_TUT1] = true
	room = await enter(INGANG, "ingang")
	await t.pframes(100)
	t.check("andere kaart (Archief-ingang): de vang-tutorial start daar niet", room != null and not Story.history.has(EV))
	hist = Story.history.size()
	room = await enter(GOLEM, "zuid")
	t.check("alleen vlag 1 (tutorial 1 overgeslagen): vang-tutorial start toch",
			await wait_until(func(): return Story.current_event == EV, 5.0))
	await wait_page()
	await press_cancel()
	t.check("B = Skip op pagina 1: meteen klaar, vlag gezet, geen pagina 2",
			await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
			and GameState.story_flags.has(F_TUT2) and not Story.history.slice(hist).has(EV + "_2"))
	await t.pframes(100)
	t.check("na Skip: 1x, niet opnieuw", Story.history.slice(hist).count(EV) == 1 and not Story.running)

	# Pagina 2 'Skip' met tik.
	setup()
	GameState.story_flags[F_TUT1] = true
	hist = Story.history.size()
	room = await enter(GOLEM, "zuid")
	await wait_until(func(): return Story.current_event == EV, 5.0)
	await wait_page()
	await press()
	await wait_page()
	await tap_choice(1)
	t.check("tik op Skip (pagina 2): klaar, pagina 3/4 niet", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
			and not Story.history.slice(hist).has(EV + "_3") and not Story.history.slice(hist).has(EV + "_4"))

	# Vlag 2 al gezet: speelt nooit.
	setup()
	GameState.story_flags[F_TUT1] = true
	GameState.story_flags[F_TUT2] = true
	hist = Story.history.size()
	room = await enter(GOLEM, "zuid")
	await t.pframes(100)
	t.check("vlag 2 al gezet: geen tutorial", not Story.history.slice(hist).has(EV) and not Story.running)


# ================================================================ deel C: uitgang op slot
func _lock_tests() -> void:
	# a) Golem nog niet verslagen: de uitgang is gewoon open.
	setup(false)
	var room := await enter(GOLEM, "zuid")
	if room == null:
		t.check("Golemhal geladen (lock)", false)
		return
	t.check("zonder verslagen Golem: geen slot", Story.pick(SD.GOLEMHAL_EXIT).get("do") is String)
	use_exit(room)
	t.check("zonder verslagen Golem: uitgang werkt (Bibliotheek)", await wait_scene_path(BIBLIOTHEEK))

	# b) Golem weg, geen Inktwurm in de Codex, geen Leeg Boek: op slot, je krijgt een boek.
	setup()
	room = await enter(GOLEM, "zuid")
	t.check("Golem verslagen: de Golem staat er niet meer", room != null and not GameState.story_flags.has(F_CODEX))
	t.check("uniek beschikbaar, Codex heeft ruimte, geen Leeg Boek", GameState.unique_available("inktwurm")
			and not GameState.codex_full() and GameState.item_count(CD.BOOK_ITEM) == 0)
	use_exit(room)
	t.check("uitgang op slot: slot-event loopt", await wait_until(func(): return Story.running and Story.current_event == SD.GOLEMHAL_EXIT, 3.0))
	await wait_page()
	await shot("golemhal_uitgang_op_slot")
	var tekst := await drain()
	t.check("tekst: pagina's blokkeren de uitgang, nog geen kast open %s" % [tekst], tekst.size() == 3 and tekst[0].contains("Loose pages"))
	t.check("slot: nog in de Golemhal, niet van kaart gewisseld", scene() == room and not GameState.changing_map)
	t.check("zonder boek: er komt 1 Leeg Boek bij (geen soft-lock)", GameState.item_count(CD.BOOK_ITEM) == 1)
	t.check("speler weer vrij, geen 'locked:'-vlag nodig", await wait_until(func(): return not player().input_locked, 2.0)
			and not GameState.story_flags.keys().any(func(k): return str(k).begins_with("locked:")))

	# c) Met boek, kast open: andere tekst, geen extra boek.
	GameState.story_flags["inktwurm_kast_open"] = true
	use_exit(room)
	await wait_until(func(): return Story.running, 3.0)
	var teksten := await drain()
	t.check("kast open: tekst noemt de Ink Worm %s" % [teksten], teksten.size() == 2 and " ".join(teksten).contains("Ink Worm")
			and not " ".join(teksten).contains("cabinet"))
	t.check("met boek: geen extra boek, nog steeds op slot", GameState.item_count(CD.BOOK_ITEM) == 1 and scene() == room)

	# d) Echt vangen in een Classic-gevecht: vlag gezet, tutorials, daarna werkt de uitgang.
	var b := await start_battle(["inktwurm"])
	t.check("gevecht met de Ink Worm gestart", b != null)
	if b == null:
		return
	await use_book(b)
	await finish_battle()
	t.check("gevangen: Ink Worm staat in de Codex", GameState.codex_pages.any(func(p): return p["species"] == "inktwurm")
			and GameState.unique_state("inktwurm") == "gevangen")
	t.check("gevangen: vlag '%s' gezet" % F_CODEX, GameState.story_flags.has(F_CODEX))
	t.check("terug in de Golemhal", await wait_scene_path(GOLEM))
	t.check("tutorial 1 volgt op de kaart", await wait_until(func(): return Story.current_event == SD.TUTORIAL_INKTWURM, 5.0))
	await wait_page()
	await press_cancel()
	t.check("daarna de vang-tutorial", await wait_until(func(): return Story.current_event == EV, 5.0))
	await wait_page()
	await press_cancel()
	await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
	await wait_until(func(): return not player().input_locked, 2.0)
	t.check("na vangen: slot-event geeft 'default' (uitgang open)", Story.pick(SD.GOLEMHAL_EXIT).get("do") is String)
	room = scene()
	use_exit(room)
	t.check("na vangen: uitgang werkt (Bibliotheek)", await wait_scene_path(BIBLIOTHEEK))

	# e) Pagina later weg (gefuseerd/verwijderd): vlag blijft, uitgang blijft open.
	GameState.codex_reset()
	t.check("Codex leeg: vlag blijft gezet", GameState.story_flags.has(F_CODEX) and GameState.codex_pages.is_empty()
			and Story.pick(SD.GOLEMHAL_EXIT).get("do") is String)

	# f) Inktwurm verslagen (niet gevangen): geen soft-lock, uitgang gaat open.
	setup()
	GameState.story_flags[F_TUT1] = true
	GameState.story_flags[F_TUT2] = true
	room = await enter(GOLEM, "zuid")
	t.check("voor het verslaan: op slot", Story.pick(SD.GOLEMHAL_EXIT).get("do") is Array)
	GameState.mark_defeated("inktwurm")
	t.check("Ink Worm verslagen (weg voor altijd): uitgang open, geen vlag", Story.pick(SD.GOLEMHAL_EXIT).get("do") is String
			and not GameState.story_flags.has(F_CODEX))
	use_exit(room)
	t.check("verslagen: uitgang werkt (Bibliotheek)", await wait_scene_path(BIBLIOTHEEK))

	# g) Codex vol: ook geen soft-lock.
	setup()
	GameState.story_flags[F_TUT1] = true
	GameState.story_flags[F_TUT2] = true
	for i in CD.MAX_PAGES:
		GameState.codex_add("mosslijm", 1)
	t.check("Codex vol (%d): uitgang open" % CD.MAX_PAGES, GameState.codex_full()
			and Story.pick(SD.GOLEMHAL_EXIT).get("do") is String and not GameState.story_flags.has(F_CODEX))


# ================================================================ deel D: save/load
func _save_tests() -> void:
	setup()
	GameState.codex_add("inktwurm", 5, {})
	t.check("codex_add(inktwurm) zet de vlag", GameState.story_flags.has(F_CODEX))
	GameState.story_flags[F_TUT2] = true
	t.check("opslaan", GameState.save_game(Vector2i(9, 9), Vector2i.UP))
	var raw := GameState.read_save(GameState.save_path)
	var flags: Array = raw.get("story", {}).get("flags", [])
	t.check("save bevat beide vlaggen", flags.has(F_CODEX) and flags.has(F_TUT2))
	GameState.new_game("Dax")
	t.check("nieuw spel: vlaggen weg", not GameState.story_flags.has(F_CODEX) and not GameState.story_flags.has(F_TUT2))
	t.check("laden: vlaggen terug, pagina ook", GameState.load_game() and GameState.story_flags.has(F_CODEX)
			and GameState.story_flags.has(F_TUT2) and GameState.codex_pages.size() == 1)
	t.check("laden voegt geen tweede Ink Worm toe", GameState.codex_pages.size() == 1)

	# Een gefuseerde (weg) pagina: de vlag in de save houdt de uitgang open.
	GameState.codex_reset()
	t.check("opslaan zonder pagina, met vlag", GameState.save_game(Vector2i(9, 9), Vector2i.UP))
	GameState.new_game("Dax")
	t.check("laden zonder pagina: vlag blijft, geen nieuwe pagina", GameState.load_game() and GameState.story_flags.has(F_CODEX)
			and GameState.codex_pages.is_empty())

	# Na laden speelt er geen tutorial.
	var hist := Story.history.size()
	var room := await enter(GOLEM, "zuid")
	await t.pframes(100)
	t.check("na laden in de Golemhal: geen tutorial opnieuw", room != null and not Story.history.slice(hist).has(EV)
			and not Story.history.slice(hist).has(SD.TUTORIAL_INKTWURM) and not Story.running)

	# Game over met checkpoint: de 'gezien'-vlag rolt niet terug, de Codex-vlag rolt mee met de Codex.
	setup()
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.story_flags[F_TUT2] = true
	GameState.codex_add("inktwurm", 5, {})
	GameState.respawn_at_checkpoint(false)
	t.check("game over: vang-tutorial blijft gezien, Codex-vlag rolt terug met de Codex",
			GameState.story_flags.has(F_TUT2) and not GameState.story_flags.has(F_CODEX) and GameState.codex_pages.is_empty())
	GameState.take_autosave_request()


# ================================================================ deel E: migratie oude saves
func _migration_tests() -> void:
	setup()
	var raw := GameState.state_data(Vector2i(9, 9), Vector2i.UP)
	var basis := _oud(raw, {})
	t.check("basis-save: nog niets, geen Ink Worm-pagina", _load(basis) and not GameState.story_flags.has(F_CODEX)
			and not GameState.story_flags.has(F_TUT2) and GameState.codex_pages.is_empty())

	var old := _oud(raw, {"uniek": {"inktwurm": "verslagen"}, "flags_erbij": [F_TUT1]})
	t.check("oude save (Ink Worm verslagen, tutorial 1 gezien, geen Codex): hij staat nu in de Codex", _load(old)
			and GameState.codex_pages.size() == 1 and GameState.codex_pages[0]["species"] == "inktwurm"
			and GameState.codex_pages[0]["level"] == 5 and GameState.story_flags.has(F_CODEX))
	t.check("oude save: vang-tutorial telt als gezien, niets gedwongen", GameState.story_flags.has(F_TUT2)
			and Story.pending_unique_event == "" and GameState.codex_active == str(GameState.codex_pages[0]["uid"]))
	t.check("oude save: de Ink Worm is geregistreerd in de bestiary", GameState.is_seen("inktwurm"))
	t.check("oude save: uitgang open (slot-event = default)", Story.pick(SD.GOLEMHAL_EXIT).get("do") is String)
	t.check("tweede keer laden: geen dubbele pagina", _load(old) and GameState.codex_pages.size() == 1)
	t.check("migratie zit in de volgende save", GameState.save_game(Vector2i(9, 9), Vector2i.UP)
			and (GameState.read_save(GameState.save_path).get("codex", {}).get("pages", []) as Array).size() == 1)

	var zonder_vlag := _oud(raw, {"uniek": {"inktwurm": "verslagen"}})
	t.check("oude save (verslagen, zonder tutorial-vlag): ook Ink Worm erbij en vlaggen gezet", _load(zonder_vlag)
			and GameState.codex_pages.size() == 1 and GameState.story_flags.has(F_CODEX) and GameState.story_flags.has(F_TUT2)
			and GameState.story_flags.has(F_TUT1))

	var gevangen := _oud(raw, {"uniek": {"inktwurm": "gevangen"}, "codex": {"pages": [], "active": "", "next": 1}})
	t.check("oude save (gevangen, daarna gefuseerd): wel de vlag, geen nieuwe pagina", _load(gevangen)
			and GameState.codex_pages.is_empty() and GameState.story_flags.has(F_CODEX))

	GameState.new_game("Dax")
	GameState.codex_add("inktwurm", 5, {})
	var met_codex := GameState.state_data(Vector2i(9, 9), Vector2i.UP)
	var met_pagina := _oud(met_codex, {"uniek": {"inktwurm": "gevangen"}, "codex": met_codex["codex"]})
	t.check("oude save (gevangen, pagina nog in de Codex): 1 pagina, vlag gezet", _load(met_pagina)
			and GameState.codex_pages.size() == 1 and GameState.story_flags.has(F_CODEX))

	var vol := _oud(raw, {"uniek": {"inktwurm": "verslagen"}})
	var pages: Array = []
	for i in CD.MAX_PAGES:
		pages.append(CD.make_page("mosslijm", 1, "codex_%04d" % (i + 1)))
	vol["codex"] = {"pages": pages, "active": "codex_0001", "next": CD.MAX_PAGES + 1}
	t.check("oude save, Codex vol: geen nieuwe pagina (past niet), tutorial gezien, uitgang open via 'Codex vol'", _load(vol)
			and GameState.codex_pages.size() == CD.MAX_PAGES and not GameState.story_flags.has(F_CODEX)
			and GameState.story_flags.has(F_TUT2) and Story.pick(SD.GOLEMHAL_EXIT).get("do") is String)

	var nog_niet := _oud(raw, {"flags_erbij": [F_TUT1]})
	t.check("save met alleen tutorial 1 (Ink Worm nog niet weg): niets uitgedeeld", _load(nog_niet)
			and GameState.codex_pages.is_empty() and not GameState.story_flags.has(F_CODEX)
			and not GameState.story_flags.has(F_TUT2) and GameState.unique_available("inktwurm"))

	# Oude save echt op de kaart laden: geen tutorial, uitgang werkt.
	var op_kaart := _oud(raw, {"uniek": {"inktwurm": "verslagen"}, "flags_erbij": [F_TUT1, SD.GOLEM_FLAG],
			"map": GOLEM, "tile": [9, 9]})
	t.check("oude save (op de Golemhal) laden", _load(op_kaart))
	var hist := Story.history.size()
	GameState.change_map(GOLEM, "zuid")
	await wait_scene_path(GOLEM)
	await t.pframes(100)
	var room := scene()
	t.check("oude save in de Golemhal: geen tutorial", not Story.history.slice(hist).has(EV) and not Story.running)
	use_exit(room)
	t.check("oude save: de uitgang werkt direct (Bibliotheek)", await wait_scene_path(BIBLIOTHEEK))
	GameState.take_autosave_request()


# ================================================================ deel F: marker (nieuwe save is nooit 'oud')
## Een nieuwe save tussen tutorial 1 en de vang-tutorial (tutorial 1 gezien, Inktwurm weg, vlag 2 nog niet)
## mag niet als oude save gemigreerd worden; een echte oude save (zonder marker) wel.
func _marker_tests() -> void:
	setup()
	GameState.story_flags[F_TUT1] = true
	GameState.unique_done["inktwurm"] = "verslagen"
	t.check("nieuwe save schrijven", GameState.save_game(Vector2i(9, 9), Vector2i.UP))
	var raw := GameState.read_save(GameState.save_path)
	t.check("nieuwe save bevat de marker '%s'" % GameState.CODEX_SYNC_KEY, raw.get(GameState.CODEX_SYNC_KEY, false) == true)
	t.check("nieuwe save: tutorial 1 gezien, vang-tutorial nog niet", (raw["story"]["flags"] as Array).has(F_TUT1)
			and not (raw["story"]["flags"] as Array).has(F_TUT2))
	GameState.new_game("Dax")
	t.check("laden van die nieuwe save: niet gemigreerd (geen vlag 2, geen pagina, geen vlag Codex)", GameState.load_game()
			and not GameState.story_flags.has(F_TUT2) and GameState.codex_pages.is_empty() and not GameState.story_flags.has(F_CODEX))
	var hist := Story.history.size()
	var room := await enter(GOLEM, "zuid")
	t.check("na laden speelt de vang-tutorial gewoon (1x)", room != null
			and await wait_until(func(): return Story.current_event == EV, 5.0))
	await wait_page()
	await press_cancel()
	await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
	await t.pframes(80)
	t.check("en daarna niet opnieuw", Story.history.slice(hist).count(EV) == 1 and GameState.story_flags.has(F_TUT2))

	# Dezelfde save zonder marker = echt oud: wel gemigreerd.
	raw.erase(GameState.CODEX_SYNC_KEY)
	t.check("zelfde save zonder marker (oud): gemigreerd (vlag 2, pagina, vlag Codex)", _load(raw)
			and GameState.story_flags.has(F_TUT2) and GameState.codex_pages.size() == 1 and GameState.story_flags.has(F_CODEX))
	t.check("oude save na migratie opnieuw opgeslagen: krijgt de marker", GameState.save_game(Vector2i(9, 9), Vector2i.UP)
			and GameState.read_save(GameState.save_path).get(GameState.CODEX_SYNC_KEY, false) == true)

	# Checkpoint: nieuw checkpoint heeft de marker en migreert niet; een checkpoint zonder marker wel.
	setup()
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	t.check("nieuw checkpoint bevat de marker", GameState.checkpoint["state"].get(GameState.CODEX_SYNC_KEY, false) == true)
	GameState.story_flags[F_TUT1] = true
	GameState.unique_done["inktwurm"] = "verslagen"
	GameState.respawn_at_checkpoint(false)
	t.check("game over met nieuw checkpoint: vang-tutorial nog niet 'gezien', geen gratis pagina",
			not GameState.story_flags.has(F_TUT2) and GameState.codex_pages.is_empty() and GameState.story_flags.has(F_TUT1))
	GameState.take_autosave_request()
	setup()
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.checkpoint["state"].erase(GameState.CODEX_SYNC_KEY)
	GameState.unique_done["inktwurm"] = "verslagen"
	GameState.respawn_at_checkpoint(false)
	t.check("game over met oud checkpoint (zonder marker): gemigreerd",
			GameState.story_flags.has(F_TUT2) and GameState.codex_pages.size() == 1 and GameState.story_flags.has(F_CODEX))
	GameState.take_autosave_request()


# ================================================================ helpers
func setup(golem_weg := true) -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""
	GameState.inventory.erase(CD.BOOK_ITEM)
	if golem_weg:
		GameState.story_flags[SD.GOLEM_FLAG] = true


## Een save-dictionary zoals een oude versie hem schreef: 'raw' met 'extra' erbij ("flags_erbij" = vlaggen).
func _oud(raw: Dictionary, extra: Dictionary) -> Dictionary:
	var d := raw.duplicate(true)
	var flags: Array = (d["story"]["flags"] as Array).filter(func(f): return not [F_CODEX, F_TUT1, F_TUT2].has(str(f)))
	d["codex"] = {"pages": [], "active": "", "next": 1}
	d.erase("uniek")
	for k in extra:
		if k == "flags_erbij":
			flags.append_array(extra[k])
		else:
			d[k] = extra[k]
	d["story"]["flags"] = flags
	return d


func _load(d: Dictionary) -> bool:
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	GameState.new_game("Dax")
	return GameState.load_game()


func scene() -> Node:
	return t.scene()


func player() -> CharacterBody2D:
	return t.player()


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await t.get_tree().process_frame
	return cond.call()


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			await t.pframes(2)
			return true
		await t.get_tree().process_frame
	return false


func enter(path: String, spawn: String) -> Node:
	GameState.has_return_point = false
	GameState.map_monster_battle = {}
	GameState.change_map(path, spawn)
	if not await wait_scene_path(path):
		return null
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await wait_until(func(): return not Story.running, 5.0)
	await t.pframes(6)
	var s := scene()
	if s != null and "monsters" in s:
		for m in s.monsters:
			if is_instance_valid(m):
				m.moves = false
	return s


## Zoals lopen op de uitgang-tegel: map.gd _on_player_stepped.
func use_exit(room: Node) -> void:
	var ex: Node = room.get_node("Exits/Uitgang_U")
	room._on_player_stepped(ex.tile_rect().position)


## Tekstvak open en uitgetypt (bij een vraag: keuzes zichtbaar).
func wait_page() -> bool:
	var ok := await wait_until(page_ready, 5.0)
	await t.pframes(2)
	return ok


func page_ready() -> bool:
	if not Dialog.is_open or Dialog._is_typing():
		return false
	return Dialog.choices.is_empty() or (Dialog._choice_box != null and Dialog._choice_box.visible)


## Per beeld (niet per physics-stap): dialoog en speler lezen 'just pressed' in _process.
func press() -> void:
	await t.get_tree().process_frame
	Input.action_press("interact")
	await t.pframes(2)
	Input.action_release("interact")
	await t.pframes(2)


func press_cancel() -> void:
	await t.get_tree().process_frame
	Input.action_press("cancel")
	await t.pframes(2)
	Input.action_release("cancel")
	await t.pframes(2)


func tap_choice(i: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	Dialog._on_choice_input(ev, i)
	await t.pframes(2)


## Alle tekstvakken van het lopende event wegklikken tot het klaar is. Geeft de teksten terug.
func drain() -> Array[String]:
	var texts: Array[String] = []
	var t0 := Time.get_ticks_msec()
	while (Story.running or Dialog.is_open) and Time.get_ticks_msec() - t0 < 15000:
		if Dialog.is_open and page_ready():
			texts.append(Dialog.text_label.text)
			await press()
		else:
			await t.get_tree().process_frame
	await t.pframes(4)
	return texts


## Pagina binnen 384x216, elke regel naast de Next/Skip-keuzes, max. 2 regels.
func page_fits() -> bool:
	var vs: Vector2 = t.get_viewport().get_visible_rect().size
	var r: Rect2 = Dialog.box_rect()
	if r.position.x < 0 or r.position.y < 0 or r.end.x > vs.x or r.end.y > vs.y:
		return false
	var font: Font = Dialog.text_label.get_theme_font("font")
	var fs: int = Dialog.text_label.get_theme_font_size("font_size")
	var room_w := r.size.x - Dialog.PAD_L - Dialog.PAD_R
	if Dialog._choice_box != null and not Dialog.choices.is_empty():
		room_w = Dialog._choice_box.position.x - Dialog.PAD_L - 4.0
	var lines := Dialog.text_label.text.split("\n")
	if lines.size() > 2:
		return false
	for l in lines:
		if font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room_w:
			print("INFO  te breed (%d > %d): %s" % [font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, room_w, l])
			return false
	return true


func start_battle(enemies: Array) -> Node:
	var p := player()
	GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", false, 0)
	if await t.wait_battle_state(["command"], 15.0) != "command":
		return null
	return t.battle()


## Leeg Boek op de enige vijand, zoals een speler: Item > Blank Book > doel.
func use_book(b: Node) -> void:
	await t.pframes(4)
	await t.choose_command(2)
	await wait_until(func(): return b.menu.visible, 3.0)
	b.menu.select(b._available_items().find(CD.BOOK_ITEM))
	await t.pframes(2)
	await t.tap("interact")
	await t.wait_battle_state(["target_enemy"], 5.0)
	await t.tap("interact")


## Berichten wegklikken tot het gevecht voorbij is.
func finish_battle() -> void:
	for guard in 80:
		var st: String = await t.wait_battle_state(["command", "message_wait"], 30.0)
		if st == "":
			break
		if st == "message_wait":
			await t.tap("interact")
		else:
			break
	await wait_until(func(): return t.battle() == null and not GameState.in_battle, 15.0)
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
