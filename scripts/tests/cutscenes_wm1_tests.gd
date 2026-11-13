extends RefCounted
## WM1-filmpjes (scripts/data/cutscene_videos.gd). Hangt aan --autotest.
## Lokaal alleen deze: godot -- --autotest --test-cutscenes-wm1

const Videos := preload("res://scripts/data/cutscene_videos.gd")
const Cutscene := preload("res://scripts/worldmap_cutscene.gd")
const SD := preload("res://scripts/data/story_data.gd")
const ScenesData := preload("res://scripts/data/scenes_data.gd")
const Kern := preload("res://scripts/kern/kern_absorption.gd")
const Rekruut := preload("res://world_warper/services/rekruut.gd")
const Genezer := preload("res://world_warper/cutscene/genezer_scene.gd")

const IDS: Array[String] = ["cs01", "cs02", "cs03", "cs04", "cs05", "cs06", "cs07", "cs08", "cs10", "worldmap"]
const VideoSlot := preload("res://scripts/data/wm1_dormant_video_slot.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	_bestanden()
	_poort()
	await _skip_en_eenmalig()
	await _corrupted_seren_slot()
	await _ontbrekend()
	_kernzin()
	_orion()
	await _cs01_voor_tcp()
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _bestanden() -> void:
	for id in IDS:
		var s := Videos.spec(id)
		var pad := str(s.get("path", ""))
		t.check("tabel %s: bestand %s" % [id, pad.get_file()], pad != "" and FileAccess.file_exists(pad))
		var stream = load(pad) if pad != "" and FileAccess.file_exists(pad) else null
		t.check("tabel %s laadt als VideoStream" % id, stream is VideoStream)
		t.check("tabel %s is 16:9" % id, is_equal_approx(float(s.get("aspect", 0.0)), Videos.WIDE))
		var vlag := str(s.get("flag", ""))
		var verwacht := "cutscene_%s_gezien" % id if id.begins_with("cs") and id != "cs05" else ""
		if id == "cs05":
			verwacht = "cutscene_genezer_video_gezien"
		elif id == "worldmap":
			verwacht = "cutscene_wereldkaart_gezien"
		t.check("tabel %s vlag %s" % [id, vlag], vlag == verwacht)
	t.check("oude wereldkaart-intro is weg", not FileAccess.file_exists("res://assets/video/worldmap_intro.ogv"))
	t.check("oude genezer_warper.ogv is weg", not FileAccess.file_exists("res://assets/video/genezer_warper.ogv"))
	t.check("CS-05 speelt genezer_warper_v3", FileAccess.file_exists("res://assets/video/genezer_warper_v3.ogv")
			and str(Videos.spec("cs05").get("path", "")).ends_with("genezer_warper_v3.ogv"))
	var ids: Array = ScenesData.ids()
	t.check("scenes-lijst houdt wereldkaart + warper en voegt CS-01..08 + CS-10 toe (CS-05 = ww_warper)",
			ids == ["wereldkaart", "ww_warper", "cs01", "cs02", "cs03", "cs04", "cs06", "cs07", "cs08", "cs10"])
	var cmds: Array = SD.EVENTS["catastrofe"][0]["do"]
	t.check("CS-01 staat direct na de leesregel", cmds.size() >= 2 and cmds[0][0] == "say" and cmds[1][0] == "video" and cmds[1][1] == "cs01")


func _poort() -> void:
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false
	GameState.story_flags.erase("cutscene_cs01_gezien")
	t.check("poort dicht in een --*test", Videos.blocked_by_tests() and not Videos.will_play("cs01") and not Videos.will_play("cs07"))
	var host := Node.new()
	host.name = "PoortHost"
	t.get_tree().root.add_child(host)
	var c := Videos.play("cs01", host)
	t.check("poort start geen speler en zet geen vlag", c == null and not GameState.story_flags.has("cutscene_cs01_gezien")
			and host.get_node_or_null("CutsceneVideo") == null)
	host.queue_free()


func _skip_en_eenmalig() -> void:
	Videos.allow_in_tests = true
	GameState.story_flags.erase("cutscene_cs08_gezien")
	var map := _dummy_map()
	var speler: Node = map.get_node("Objects/Player")
	speler.set("input_locked", false)
	var c: Node = Videos.play("cs08", map, {"map": map})
	t.check("filmpje start en zet de vlag meteen", c != null and GameState.story_flags.has("cutscene_cs08_gezien"))
	t.check("tweede keer niet (eenmalig)", Videos.play("cs08", map) == null)
	await t.get_tree().create_timer(0.5).timeout
	_klik()
	var t0 := Time.get_ticks_msec()
	while c != null and is_instance_valid(c) and c.has_method("is_done") and not bool(c.call("is_done")) and Time.get_ticks_msec() - t0 < 3000:
		await t.get_tree().process_frame
	await t.frames(3)
	t.check("skip maakt het filmpje klaar", c == null or not is_instance_valid(c) or bool(c.call("is_done")))
	t.check("na skip is de speler vrij (geen verhaal/dialoog/gevecht)", not bool(speler.get("input_locked"))
			and Story.idle() and not Dialog.is_open and not GameState.scene_busy())
	map.queue_free()
	Videos.allow_in_tests = false


func _corrupted_seren_slot() -> void:
	t.check("CS-10 dormant id", VideoSlot.ARCHIEF2_CORRUPTED_SEREN == "dialogue_archief2_corrupted_seren")
	GameState.story_flags.erase("cutscene_cs10_gezien")
	GameState.new_game("Dax")
	GameState.give_exp(GameState.party[0], preload("res://scripts/data/game_data.gd").exp_for_level(7))
	var map := _dummy_map()
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	await VideoSlot.before_dialogue(VideoSlot.ARCHIEF2_CORRUPTED_SEREN, map)
	t.check("CS-10 start via Archief2-slot en zet vlag", GameState.story_flags.has("cutscene_cs10_gezien"))
	t.check("CS-10 speelt maar één keer", not Videos.will_play("cs10") and Videos.play("cs10", map) == null)
	t.check("CS-10: Seren kan nog aansluiten na filmpje", Archief2.sluit_lotte_aan() and GameState.has_member("lotte"))
	map.queue_free()
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _ontbrekend() -> void:
	var map := _dummy_map()
	var speler: Node = map.get_node("Objects/Player")
	speler.set("input_locked", true)
	var c := Cutscene.new()
	c.video_path = "res://assets/video/bestaat_niet.ogv"
	c.max_seconds = 5.0
	map.add_child(c)
	c.begin(map)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(c) and not c.is_done() and Time.get_ticks_msec() - t0 < 2000:
		await t.get_tree().process_frame
	await t.frames(2)
	t.check("ontbrekend bestand is meteen klaar", not is_instance_valid(c) or c.is_done())
	t.check("ontbrekend bestand geeft input terug", not bool(speler.get("input_locked")))
	map.queue_free()


func _kernzin() -> void:
	GameState.story_flags.erase("cutscene_cs02_gezien")
	var oud: Array = Kern.lines_for("golemkern")
	t.check("zonder filmpje: één Sapientia-regel (geen Dax absorbs)", oud.size() == 1
			and str(oud[0]) == "Sapientia drank the Golem Core dry." and not "absorbs" in " ".join(oud))
	GameState.story_flags["cutscene_cs02_gezien"] = true
	var nieuw: Array = Kern.lines_for("golemkern")
	t.check("na CS-02-filmpje: geen dubbele dialoogregel", nieuw.is_empty())
	GameState.story_flags.erase("cutscene_cs02_gezien")


func _orion() -> void:
	GameState.new_game("Dax")
	var g: Node = Genezer.new()
	g._orion_erbij()
	t.check("CS-07: Orion sluit aan via de rekruut", not GameState.member("orion").is_empty()
			and GameState.party.any(func(h): return str(h.get("id", "")) == "orion"))
	var n: Node = Rekruut.new()
	n.set("hero_id", "orion")
	n.call("_ververs")
	t.check("atrium biedt Orion niet nog eens aan", not n.visible)
	var grootte := GameState.party.size() + GameState.party_bench.size()
	g._orion_erbij()
	t.check("geen tweede Orion", GameState.party.size() + GameState.party_bench.size() == grootte
			and str(n.call("sluit_aan")) == "")
	n.free()
	g.free()


func _cs01_voor_tcp() -> void:
	Videos.allow_in_tests = true
	if Dialog.is_open:
		Dialog.close()
	GameState.new_game("Dax")
	GameState.story_flags.erase(SD.TC_P_SHOWN)
	GameState.story_flags.erase("cutscene_cs01_gezien")
	GameState.change_map(SD.HOUSE, "lezen")
	var huis: bool = await t.wait_scene("Huis", 15.0)
	t.check("CS-01: huis geladen", huis)
	if not huis:
		Videos.allow_in_tests = false
		return
	await t.frames(5)
	var video_gezien := false
	var video_klaar_voor_kaart := false
	var vast_tijdens_kaart := false
	Story.run("catastrofe")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000 and not Story.tc_p_card_active:
		var kaart: Node = t.scene()
		var vid: Node = kaart.get_node_or_null("CutsceneVideo") if kaart != null else null
		if vid != null:
			video_gezien = true
			if vid.has_method("is_done") and bool(vid.call("is_done")):
				video_klaar_voor_kaart = true
		elif video_gezien:
			video_klaar_voor_kaart = true
		if Dialog.is_open and not Dialog._is_typing():
			await t.press_interact()
		elif video_gezien and vid != null and not bool(vid.call("is_done")):
			await t.get_tree().create_timer(0.5).timeout
			_klik()
			await t.frames(3)
		else:
			await t.frames(1)
	var na: Node = t.scene()
	var vid_na: Node = na.get_node_or_null("CutsceneVideo") if na != null else null
	if video_gezien and (vid_na == null or (vid_na.has_method("is_done") and bool(vid_na.call("is_done")))):
		video_klaar_voor_kaart = true
	if Story.tc_p_card_active:
		var p: Node = t.player()
		vast_tijdens_kaart = p != null and bool(p.get("input_locked"))
		_klik()
		await t.frames(3)
	var t1 := Time.get_ticks_msec()
	while Story.running and Time.get_ticks_msec() - t1 < 8000:
		if Dialog.is_open and not Dialog._is_typing():
			await t.press_interact()
		else:
			await t.frames(1)
	var p2: Node = t.player()
	t.check("CS-01 filmpje speelde", video_gezien and GameState.story_flags.has("cutscene_cs01_gezien"))
	t.check("CS-01 klaar vóór TC-P", video_klaar_voor_kaart and GameState.story_flags.has(SD.TC_P_SHOWN))
	t.check("input vast zolang TC-P zichtbaar is", vast_tijdens_kaart)
	t.check("input terug na TC-P", p2 != null and not bool(p2.get("input_locked")) and Story.idle() and not Dialog.is_open)
	# De schreeuw-timer (2 s) gaat daarna naar achterna, niet naar de keuze.
	var t2 := Time.get_ticks_msec()
	while not Story.history.has("achterna") and Time.get_ticks_msec() - t2 < 6000:
		if Dialog.is_open and not Dialog._is_typing():
			await t.press_interact()
		else:
			await t.frames(1)
	t.check("CS-01 slaat Blijven/Volgen over en neemt het volg-pad", Story.history.has("achterna")
			and not Story.history.has("keuze") and not Story.history.has("blijven"))
	var t3 := Time.get_ticks_msec()
	while GameState.story_step != SD.NACHT and Time.get_ticks_msec() - t3 < 4000:
		if Dialog.is_open and not Dialog._is_typing():
			await t.press_interact()
		else:
			await t.frames(1)
	t.check("volg-pad zet nacht en haalt het slot van de deur", GameState.story_step == SD.NACHT
			and not Story.has_flag("locked:HuisDeur") and Story.has_flag("schilderij_weg"))
	Videos.allow_in_tests = false


func _dummy_map() -> Node2D:
	var map := Node2D.new()
	map.name = "FilmMap"
	var objects := Node2D.new()
	objects.name = "Objects"
	map.add_child(objects)
	var speler := Pop.new()
	speler.name = "Player"
	objects.add_child(speler)
	t.get_tree().root.add_child(map)
	return map


func _klik() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)


class Pop extends Node2D:
	var input_locked := false
