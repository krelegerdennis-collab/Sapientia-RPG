extends Node
## Quest Log + ECHO per act (v0.25): data uit res://data/quests.json, stappen via events,
## het scherm (Active/Done per act), ECHO's zinnen per act en de save (ook een oude save).
## Start: godot --path . -- --questtest [--shots=/pad/map]

const QD := preload("res://scripts/data/quest_data.gd")
const QL := preload("res://world_warper/data/echo_questlog.gd")
const QLScherm := preload("res://scripts/ui/questlog_screen.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const SD := preload("res://scripts/data/story_data.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const MenuScreen := preload("res://scripts/ui/menu_screen.gd")

const AKTE1_KLAAR := {"bewaker:archief_golemhal/golem": true}
const AKTE2_KLAAR := {"bewaker:archief_golemhal/golem": true, "noor_gered": true, "archief2_lotte_lid": true,
		"bewaker:archief_2_v4_genezer/genezer": true, "world_warper_unlocked": true}

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
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_data_tests()
	_regel_tests()
	await _event_tests()
	await _scherm_tests()
	_echo_data_tests()
	await _echo_live_tests()
	_save_tests()
	print("QUESTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- data
func _data_tests() -> void:
	check("quests.json laadt: 6 acts", QD.act_ids() == ["akte_1", "akte_2", "akte_3", "akte_4", "akte_5", "akte_6"])
	check("quests.json laadt: 7 opdrachten (6 hoofd, 1 zij)", QD.quests().size() == 7
			and QD.quests().filter(func(q): return QD.is_zij(q)).size() == 1)
	var velden := true
	var ids: Array = []
	for q in QD.quests():
		for k in ["id", "title", "description", "act", "steps"]:
			if not q.has(k):
				velden = false
				print("INFO  %s mist %s" % [q.get("id", "?"), k])
		if not (q.has("done_flag") or q.has("done_step")):
			velden = false
			print("INFO  %s heeft geen done_flag/done_step" % q.get("id", "?"))
		if not QD.act_ids().has(str(q.get("act", ""))) or ids.has(str(q.get("id", ""))):
			velden = false
		ids.append(str(q.get("id", "")))
		var stappen: Array = []
		for s in q.get("steps", []):
			if not (s.has("id") and s.has("text")) or stappen.has(str(s.get("id", ""))):
				velden = false
			if not (s.has("event") or s.has("flag") or s.has("step")):
				velden = false
				print("INFO  stap zonder trigger: %s/%s" % [q["id"], s.get("id", "?")])
			stappen.append(str(s.get("id", "")))
	check("elke opdracht: id, titel, omschrijving, act, stappen, klaar-voorwaarde", velden)
	var events_ok := true
	for q in QD.quests():
		for s in q["steps"]:
			if s.has("event") and not SD.EVENTS.has(str(s["event"])):
				events_ok = false
				print("INFO  onbekend event: ", s["event"])
	check("elk stap-event bestaat in story_data.gd", events_ok)
	var golem := QD.quest("golem")
	var vesper := QD.quest("vesper")
	var graan := QD.quest("zingend_graan")
	check("vlaggen = de echte verhaalvlaggen", str(golem["done_flag"]) == SD.GOLEM_FLAG
			and str(vesper["steps"][1]["flag"]) == SD.WORTELKONING_FLAG
			and str(QD.quest("genezer")["done_flag"]) == Unlock.BEWAKER_VLAG
			and str(QD.quest("warper")["done_flag"]) == Unlock.UNLOCK_VLAG
			and str(graan["start_flag"]) == SD.FLAG_GRAAN and str(graan["done_flag"]) == SD.FLAG_GRAAN_KLAAR
			and str(graan["npc"]) == SD.GERRIT and int(QD.quest("archieven_in")["done_step"]) == SD.NACHT)
	var eng := true
	for t in QD.speler_teksten():
		for nl in ["opdracht", "klaar", "akte", "archief", "verslaan", "stap ", "proefpersoon", "onderzoeker"]:
			if t.to_lower().contains(nl):
				eng = false
				print("INFO  niet-Engels/onthulling: ", t)
	check("spelertekst Engels", eng and not QD.speler_teksten().has(""))
	check("ECHO-questlog gebruikt dezelfde data", QL.AKTES.size() == 6 and QL.ZIJ.size() == 1
			and (QL.akte("akte_2")["opdrachten"] as Array).size() == 4)


func _regel_tests() -> void:
	var leeg := {}
	check("nieuw spel: Act 1 open, Act 2 dicht, Act 3-6 later", QD.akte_status("akte_1", leeg, 0) == QD.OPEN
			and QD.akte_status("akte_2", leeg, 0) == QD.DICHT and QD.akte_status("akte_3", leeg, 0) == QD.LATER)
	check("nieuw spel: actief = alleen Act 1 (%s)" % [_titels("akte_1", "actief", leeg, 0, {})],
			_titels("akte_1", "actief", leeg, 0, {}) == ["The Archives of Sapientia", "Defeat the Golem"]
			and QD.voor_tab("akte_2", "actief", leeg, 0).is_empty() and QD.voor_tab("akte_1", "klaar", leeg, 0).is_empty())
	var a := QD.quest("archieven_in")
	check("stap via vlag: water", QD.stap_klaar(a, a["steps"][1], {"water_klaar": true}, SD.TAKEN)
			and not QD.stap_klaar(a, a["steps"][1], {}, SD.TAKEN))
	check("stap via verhaalstap: les klaar na AVOND", QD.stap_klaar(a, a["steps"][3], {}, SD.AVOND)
			and not QD.stap_klaar(a, a["steps"][3], {}, SD.LES))
	var v := QD.quest("vesper")
	check("Vesper pas actief met quest_noor", not QD.quest_gestart(v, AKTE1_KLAAR, SD.NACHT)
			and QD.quest_gestart(v, {"quest_noor": true}, SD.NACHT)
			and not _titels("akte_2", "actief", AKTE1_KLAAR, SD.NACHT, {}).has(str(v["title"])))
	check("done-vlag maakt alle stappen klaar", QD.stap_klaar(v, v["steps"][0], {"noor_gered": true}, 0))
	check("huidige act: nieuw spel = 1, na Golem = 2, alles klaar = 2 (3 heeft nog geen inhoud)",
			QD.huidige_akte(leeg, 0) == "akte_1" and QD.huidige_akte(AKTE1_KLAAR, SD.NACHT) == "akte_2"
			and QD.huidige_akte(AKTE2_KLAAR, SD.NACHT) == "akte_2")
	check("Act 2 klaar met de World Warper", QD.akte_status("akte_2", AKTE2_KLAAR, SD.NACHT) == QD.KLAAR
			and QD.voor_tab("akte_2", "klaar", AKTE2_KLAAR, SD.NACHT).size() == 4)
	var g := QD.quest("zingend_graan")
	check("zij: niet gesproken = naam van de NPC", QD.regel(g, AKTE1_KLAAR, SD.NACHT) == SD.GERRIT
			and QD.regel(g, {"gesproken_gerrit": true}, SD.NACHT) == "The Singing Grain"
			and QD.regel(g, {SD.FLAG_GRAAN: true}, SD.NACHT) == "The Singing Grain")
	check("zij: detail zonder gesprek verklapt niets", QD.detail_regels(g, {}, 0) == ["Side quest - Garrett the Miller", QD.NIET_GESTART])


func _titels(act_id: String, tab: String, flags: Dictionary, stap: int, vg: Dictionary) -> Array:
	return QD.voor_tab(act_id, tab, flags, stap, vg).map(func(q): return str(q["title"]))


# ---------------------------------------------------------------- events
func _event_tests() -> void:
	GameState.new_game("Dax")
	check("nieuw spel: lege voortgang", GameState.quest_progress.is_empty())
	# puur: een stap met alleen zijn event (vlag/stap zeggen nog niets)
	var vg := {}
	var nieuw := QD.on_event(vg, "na_les", {}, SD.START)
	check("on_event: na_les vinkt 'Sword lesson' af", nieuw == ["archieven_in/les"]
			and (vg["archieven_in"]["steps"] as Array) == ["les"] and not bool(vg["archieven_in"]["done"]))
	check("on_event: onbekend event doet niets", QD.on_event(vg, "bestaat_niet", {}, SD.START).is_empty()
			and (vg["archieven_in"]["steps"] as Array) == ["les"])
	# via Story: het signaal event_finished komt bij GameState aan
	Story.event_finished.emit("achterna")
	check("Story.event_finished -> GameState: 'Follow Grandpa' klaar",
			(GameState.quest_progress.get("archieven_in", {}).get("steps", []) as Array).has("achterna")
			and GameState.story_step == SD.START)
	# een echt event: Garrett's opdracht aannemen (zet de vlag en praat)
	GameState.story_flags["noor_lid"] = true
	GameState.story_flags["gesproken_gerrit"] = true
	Story.run("gerrit_ja")
	var klaar := await _wacht(func() -> bool:
		if Dialog.is_open:
			Dialog.advance()
		return not Story.running
	, 8.0)
	await _pframes(2)
	check("Story.run(gerrit_ja): stap 'Help Garrett' klaar", klaar and GameState.story_flags.has(SD.FLAG_GRAAN)
			and (GameState.quest_progress.get("zingend_graan", {}).get("steps", []) as Array).has("aannemen")
			and not bool(GameState.quest_progress["zingend_graan"].get("done", true)))
	GameState.story_flags[SD.FLAG_ZAAD] = true
	GameState.story_flags[SD.FLAG_GRAAN_KLAAR] = true
	GameState.quest_event("gerrit")
	check("na het zaad: Singing Grain klaar", bool(GameState.quest_progress["zingend_graan"]["done"]))
	# eenmaal klaar blijft klaar (ook als een vlag later weg is)
	GameState.story_flags.erase(SD.FLAG_GRAAN_KLAAR)
	GameState.quest_sync()
	check("klaar blijft klaar", QD.quest_klaar(QD.quest("zingend_graan"), GameState.story_flags, GameState.story_step,
			GameState.quest_progress))


# ---------------------------------------------------------------- scherm
func _scherm_tests() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.story_flags = {SD.GOLEM_FLAG: true, "archief_gezien": true, "noor_ontmoet": true, "quest_noor": true,
			"noor_lid": true, "gesproken_gerrit": true, SD.FLAG_GRAAN: true}
	var scherm: CanvasLayer = QLScherm.new()
	scherm.layer = 120
	get_tree().root.add_child(scherm)
	await _pframes(5)
	check("scherm: opent op Active", scherm.tab == "actief" and scherm.header.text == QD.TITEL)
	check("scherm Active: alleen Act 2 (%s | %s)" % [scherm.kop_teksten(), scherm.regel_teksten()],
			scherm.kop_teksten() == ["Act 2: The Second Archive"]
			and scherm.regel_teksten() == ["Save Vesper from the Dark Wood", "Seren joins the party",
				"Defeat the guardian of the second Archive", "Reach the World Warper", "The Singing Grain"])
	check("scherm: eerste opdracht staat rechts", scherm.gekozen == "vesper"
			and scherm.detail_titel.text == "Save Vesper from the Dark Wood"
			and scherm.detail.text.contains("[x] Meet Vesper in Mapleton")
			and scherm.detail.text.contains("[ ] Defeat the Root King")
			and scherm.detail.text.contains("[x] Free Vesper from the cocoon"))
	var groot: bool = scherm.rows.all(func(b): return b.custom_minimum_size.y >= MenuScreen.ROW_H and b.size.y >= MenuScreen.ROW_H)
	for t in scherm.tab_buttons.values():
		groot = groot and (t as Button).size.y >= MenuScreen.ROW_H and (t as Button).size.x >= 60
	check("scherm: grote tikvlakken (regels en tabs >= %d px)" % MenuScreen.ROW_H, groot)
	check("scherm: past in 384x216", _in_beeld(scherm))
	await _screenshot("quest_scherm_actief")
	scherm.toon("zingend_graan")
	await _pframes(3)
	check("scherm: zijopdracht met NPC en stappen", scherm.detail.text.begins_with("Side quest - Garrett the Miller")
			and scherm.detail.text.contains("[x] Help Garrett the Miller") and scherm.detail.text.contains("[ ] Find the Singing Seed"))
	await _screenshot("quest_scherm_zij")
	await get_tree().physics_frame
	Input.action_press("move_right")
	await _pframes(2)
	Input.action_release("move_right")
	await _pframes(3)
	check("scherm: rechts = tab Done", scherm.tab == "klaar")
	check("scherm Done: per act (%s | %s)" % [scherm.kop_teksten(), scherm.regel_teksten()],
			scherm.kop_teksten() == ["Act 1: The First Archive"]
			and scherm.regel_teksten() == ["The Archives of Sapientia", "Defeat the Golem"])
	check("scherm Done: Archives-stappen afgevinkt", scherm.detail.text.contains("[x] Follow Grandpa")
			and not scherm.detail.text.contains("[ ]"))
	await _screenshot("quest_scherm_klaar")
	# een stap komt binnen: Root King verslagen + Vesper gered -> naar Done
	GameState.story_flags[SD.WORTELKONING_FLAG] = true
	GameState.story_flags["noor_gered"] = true
	scherm.kies_tab("actief")
	await _pframes(3)
	check("scherm: Vesper weg uit Active", not scherm.regel_teksten().has("Save Vesper from the Dark Wood"))
	scherm.kies_tab("klaar")
	await _pframes(3)
	check("scherm: Vesper in Done onder Act 2", scherm.kop_teksten() == ["Act 1: The First Archive", "Act 2: The Second Archive"]
			and scherm.regel_teksten().back() == "Save Vesper from the Dark Wood")
	scherm.close()
	await _pframes(2)
	# leeg
	GameState.new_game("Dax")
	var leeg: CanvasLayer = QLScherm.new()
	leeg.layer = 120
	get_tree().root.add_child(leeg)
	await _pframes(3)
	leeg.kies_tab("klaar")
	await _pframes(3)
	check("scherm: Done leeg = melding", leeg.rows.is_empty() and leeg.leeg != null and leeg.leeg.text == QD.LEEG_KLAAR)
	leeg.close()
	await _pframes(2)


func _in_beeld(scherm: CanvasLayer) -> bool:
	var vp := Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)
	check("basisresolutie 384x216", vp.size == Vector2(384, 216))
	var ok := true
	for c in [scherm.back_button, scherm.detail, scherm.scroll] + scherm.tab_buttons.values():
		var r: Rect2 = (c as Control).get_global_rect()
		if not vp.encloses(r):
			ok = false
			print("INFO  buiten beeld: %s %s" % [c.name, r])
	return ok


# ---------------------------------------------------------------- ECHO
func _echo_data_tests() -> void:
	var z1 := QL.echo_dialoog("akte_1")
	var z2 := QL.echo_dialoog("akte_2")
	var z3 := QL.echo_dialoog("akte_3")
	check("ECHO: één zinnenset per act", QD.act_ids().all(func(i): return not QL.echo_dialoog(str(i)).is_empty()))
	check("ECHO: Act 1 en Act 2 zeggen iets anders", z1 != z2 and z2 != z3)
	check("ECHO: Act 2 = canon-zinnen", z2[0] == "Candidate detected. Two Archives active. World Warper online.")
	check("ECHO: menu-optie Current act", EchoGrot.menu_opties().has(EchoGrot.OPTIE_AKTE)
			and EchoGrot.speler_teksten().has(EchoGrot.OPTIE_AKTE))


func _echo_live_tests() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.story_flags = {EchoGrot.FLAG_EERSTE: true}
	GameState.change_map(EchoGrot.KAMER, EchoGrot.KAMER_SPAWN)
	var ok := await _wacht(func() -> bool:
		var sc := get_tree().current_scene
		return sc != null and sc.scene_file_path == EchoGrot.KAMER and sc.is_node_ready() and not GameState.changing_map
	, 15.0)
	await _wacht(func() -> bool: return Transition._rect.color.a <= 0.01, 3.0)
	await _pframes(2)
	check("ECHO's Chamber laadt", ok)
	if not ok:
		return
	# Act 1
	var z1 := QL.echo_dialoog("akte_1")
	check("ECHO in Act 1 zegt de Act 1-zin", _praat() and await _naar_tekst(z1[0]) and Dialog.name_label.text == "ECHO")
	check("daarna het menu", await _naar_keuze(EchoGrot.OPTIE_AKTE))
	_kies(EchoGrot.KEUZE_TERUG)
	await _gesprek_weg()
	check("Act 1-zin is gezegd (vlag)", GameState.story_flags.has(EchoGrot.FLAG_AKTE + "akte_1"))
	# Act 2: andere zinnen
	for f in AKTE2_KLAAR:
		GameState.story_flags[f] = true
	var z2 := QL.echo_dialoog("akte_2")
	check("ECHO in Act 2 zegt de Act 2-zinnen", _praat() and await _naar_tekst(z2[0]) and z2[0] != z1[0])
	await _tekst_af()
	await _screenshot("echo_akte2")
	check("Act 2: tweede zin", await _naar_tekst(z2[1]))
	await _tekst_af()
	await _screenshot("echo_akte2_zin2")
	check("Act 2: daarna het menu", await _naar_keuze(EchoGrot.OPTIE_AKTE))
	await _tekst_af()
	await _screenshot("echo_menu")
	_kies(EchoGrot.KEUZE_TERUG)
	await _gesprek_weg()
	check("tweede gesprek in dezelfde act: meteen het menu", _praat() and await _wacht(func() -> bool: return Dialog.is_open, 3.0)
			and Dialog.has_choices() and str(Dialog.text_label.text) == EchoGrot.VRAAG_MENU)
	await _naar_keuze(EchoGrot.OPTIE_AKTE)
	_kies(EchoGrot.OPTIE_AKTE)
	check("Current act herhaalt de Act 2-zin", await _naar_tekst(z2[0]))
	check("terug in het menu", await _naar_keuze(EchoGrot.KEUZE_TERUG))
	_kies(EchoGrot.OPTIE_QUESTLOG)
	check("Quest Log bij ECHO: Act 2 Done", await _naar_keuze(QL.TERUG) and str(Dialog.choices[1]) == "Act 2 - Done")
	_kies(QL.TERUG)
	await _naar_keuze(EchoGrot.OPTIE_SIMULATIE)
	_kies(EchoGrot.KEUZE_TERUG)
	check("gesprek sluit", await _gesprek_weg())
	check("voortgang bijgewerkt bij ECHO", bool(GameState.quest_progress.get("warper", {}).get("done", false)))


## Typemachine-tekst laten uitlopen zoals in het spel (voor een leesbare screenshot).
func _tekst_af() -> void:
	await _wacht(func() -> bool: return not Dialog._is_typing(), 6.0)
	await _pframes(4)


func _echo_node() -> Node:
	var sc := get_tree().current_scene
	return sc.get_node_or_null("Objects/Echo") if sc != null else null


func _praat() -> bool:
	var echo := _echo_node()
	var sc := get_tree().current_scene
	var pl: Node = sc.get_node_or_null("Objects/Player") if sc != null else null
	if echo == null or pl == null or echo.get_node_or_null("Gesprek") != null:
		return false
	echo.interact(pl)
	return true


func _gesprek_weg() -> bool:
	return await _wacht(func() -> bool:
		var echo := _echo_node()
		return not Dialog.is_open and echo != null and echo.get_node_or_null("Gesprek") == null
	, 3.0)


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


# ---------------------------------------------------------------- save
func _save_tests() -> void:
	var pad := "user://questtest_quests.json"
	GameState.new_game("Dax")
	GameState.story_step = SD.TAKEN
	GameState.story_flags = {"water_klaar": true}
	GameState.quest_event("na_les")    # alleen via het event, de vlaggen/stap zeggen het niet
	var voor: Dictionary = GameState.quest_progress.duplicate(true)
	check("voor het opslaan: water + les", (voor["archieven_in"]["steps"] as Array).has("water")
			and (voor["archieven_in"]["steps"] as Array).has("les"))
	var opgeslagen := GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, pad)
	var ruw := GameState.read_save(pad)
	check("save heeft het veld quests", opgeslagen and ruw.get("quests") is Dictionary
			and (ruw["quests"]["archieven_in"]["steps"] as Array).has("les"))
	GameState.new_game("Dax")
	check("nieuw spel wist de voortgang", GameState.quest_progress.is_empty())
	var geladen := GameState.load_game(pad)
	check("laden: voortgang terug (ook de stap die alleen via het event kwam)", geladen
			and GameState.quest_progress == voor
			and QD.stap_klaar(QD.quest("archieven_in"), QD.quest("archieven_in")["steps"][3], GameState.story_flags,
				GameState.story_step, GameState.quest_progress))

	# oude save: geen "quests"
	var oud := ruw.duplicate(true)
	oud.erase("quests")
	oud["story"] = {"step": SD.NOOR_KWIJT, "flags": [SD.GOLEM_FLAG, "archief_gezien", "noor_ontmoet", "quest_noor"]}
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify(oud))
	f.close()
	GameState.new_game("Dax")
	var oud_ok := GameState.load_game(pad)
	check("oude save zonder quests laadt", oud_ok and GameState.story_step == SD.NOOR_KWIJT)
	check("oude save: voortgang uit de vlaggen (Golem klaar, Vesper actief)", oud_ok
			and bool(GameState.quest_progress.get("golem", {}).get("done", false))
			and bool(GameState.quest_progress.get("archieven_in", {}).get("done", false))
			and (GameState.quest_progress.get("vesper", {}).get("steps", []) as Array) == ["ontmoeten"]
			and not bool(GameState.quest_progress["vesper"].get("done", true)))
	check("oude save: Act 2 is de huidige act", QL.huidige_akte(GameState.story_flags, GameState.story_step,
			GameState.quest_progress) == "akte_2")

	# kapotte of onbekende data
	oud["quests"] = {"bestaat_niet": {"steps": ["x"], "done": true}, "golem": {"steps": ["golem", "nep"], "done": "ja"},
			"vesper": "kapot"}
	f = FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify(oud))
	f.close()
	var kapot_ok := GameState.load_game(pad)
	check("kapotte quests-data: laadt, onbekend valt weg", kapot_ok and not GameState.quest_progress.has("bestaat_niet")
			and not (GameState.quest_progress["golem"]["steps"] as Array).has("nep")
			and bool(GameState.quest_progress["golem"]["done"]))
	oud["quests"] = "geen dictionary"
	f = FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify(oud))
	f.close()
	check("quests is geen dictionary: laadt toch", GameState.load_game(pad)
			and bool(GameState.quest_progress.get("golem", {}).get("done", false)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))


# ---------------------------------------------------------------- hulp
func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


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
