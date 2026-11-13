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

const IDS: Array[String] = ["cs01", "cs02", "cs03", "cs04", "cs05", "cs06", "cs07", "cs08", "cs09", "cs10", "cs11", "cs12", "worldmap"]
const Dreiging := preload("res://world_warper/cutscene/dreiging.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const HangerScene := preload("res://world_warper/cutscene/hanger_scene.tscn")
const VideoSlot := preload("res://scripts/data/wm1_dormant_video_slot.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const GD := preload("res://scripts/data/game_data.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"

## Alleen in de fallback-tak van noor_ontmoeting (zonder CS-09-filmpje).
const CS09_FALLBACK_VESPER_SNIPPETS: Array[String] = [
	"You came over the hills?",
	"I'm Vesper. You look like you're looking for someone.",
	"People here call me the girl with the sparks.",
	"Pink sparks dance between her fingers",
	"They're... they're pulling me!",
]

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	_bestanden()
	_poort()
	await _skip_en_eenmalig()
	await _mapleton_slot()
	await _noor_ontmoeting_filmpad()
	await _corrupted_seren_slot()
	await _pendant_slot()
	await _threat_slot()
	await _threat_hal_integratie()
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
	t.check("scenes-lijst houdt wereldkaart + warper en voegt CS-01..12 toe (CS-05 = ww_warper)",
			ids == ["wereldkaart", "ww_warper", "cs01", "cs02", "cs03", "cs04", "cs06", "cs07", "cs08", "cs09", "cs10", "cs11", "cs12"])
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


func _mapleton_slot() -> void:
	t.check("CS-09 dormant id", VideoSlot.MAPLETON_VESPER == "dialogue_mapleton_vesper")
	GameState.story_flags.erase("cutscene_cs09_gezien")
	var map := _dummy_map()
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	await VideoSlot.before_dialogue(VideoSlot.MAPLETON_VESPER, map)
	t.check("CS-09 start via Mapleton-slot en zet vlag", GameState.story_flags.has("cutscene_cs09_gezien"))
	t.check("CS-09 speelt maar één keer", not Videos.will_play("cs09") and Videos.play("cs09", map) == null)
	map.queue_free()
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _noor_ontmoeting_filmpad() -> void:
	var saved_flags: Dictionary = GameState.story_flags.duplicate(true)
	var saved_step: int = GameState.story_step
	var saved_history: Array = Story.history.duplicate()
	if Dialog.is_open:
		Dialog.close()
	GameState.new_game("Dax")
	GameState.story_flags.erase("cutscene_cs09_gezien")
	GameState.story_flags.erase("noor_ontmoet")
	GameState.story_flags.erase("quest_noor")
	GameState.story_flags.erase("marit_boeken")
	GameState.story_flags[SD.GOLEM_FLAG] = true
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	var geladen := await _enter_map(SD.ESDOORN, "zuid_ingang")
	t.check("CS-09 E2E: Esdoorn geladen", geladen)
	if not geladen:
		_restore_noor_test_state(saved_flags, saved_step, saved_history)
		Videos.allow_in_tests = false
		Cutscene.allow_in_tests = false
		return
	var t0 := Time.get_ticks_msec()
	while not Story.running and Time.get_ticks_msec() - t0 < 8000:
		var map_wait: Node = t.scene()
		var vid_wait: Node = map_wait.get_node_or_null("CutsceneVideo") if map_wait != null else null
		if vid_wait != null or Story.running:
			break
		await t.frames(1)
	var story_out: Dictionary = await _advance_story_with_video(90.0)
	var lines: Array = story_out.get("lines", [])
	var video_gezien: bool = bool(story_out.get("video", false))
	var v: Node = t.scene()
	var vesper: Node = v.get_node_or_null("Objects/Vesper") if v != null else null
	var wortel: Node = v.get_node_or_null("Objects/WortelGreep") if v != null else null
	var tekst := " ".join(lines.map(func(l): return str(l)))
	t.check("CS-09 E2E: filmpje speelde en zette cutscene_cs09_gezien", video_gezien and GameState.story_flags.has("cutscene_cs09_gezien"))
	t.check("CS-09 E2E: progressie vlaggen + NOOR_KWIJT", Story.has_flag("noor_ontmoet") and Story.has_flag("quest_noor")
			and GameState.story_step == SD.NOOR_KWIJT)
	t.check("CS-09 E2E: marit_boeken (3 lege boeken)", Story.has_flag("marit_boeken")
			and GameState.item_count("leeg_boek") == 3 and not GD.START_INVENTORY.has("leeg_boek"))
	t.check("CS-09 E2E: Vesper en WortelGreep verborgen", vesper != null and not vesper.visible
			and wortel != null and not wortel.visible)
	t.check("CS-09 E2E: geen lange Vesper-regels uit fallback-tak", not CS09_FALLBACK_VESPER_SNIPPETS.any(func(s: String) -> bool: return s in tekst))
	t.check("CS-09 E2E: wel Marigold-opdrachtregel", tekst.contains("save her") or tekst.contains("Save Vesper"))
	t.check("CS-09 E2E: filmpje speelt niet opnieuw", not Videos.will_play("cs09") and Videos.play("cs09", v) == null)
	var hist_n := Story.history.count("noor_ontmoeting")
	await _enter_map(WORLD, "van_esdoorn")
	await _enter_map(SD.ESDOORN, "zuid_ingang")
	await t.get_tree().create_timer(0.8).timeout
	t.check("CS-09 E2E: tweede binnenkomst geen herhaalde ontmoeting", Story.history.count("noor_ontmoeting") == hist_n
			and hist_n == 1 and not Story.running)
	_restore_noor_test_state(saved_flags, saved_step, saved_history)
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _restore_noor_test_state(flags: Dictionary, step: int, history: Array) -> void:
	GameState.story_flags = flags.duplicate(true)
	GameState.story_step = step
	Story.history.clear()
	for ev in history:
		Story.history.append(str(ev))


func _scene_node_name(path: String) -> String:
	var out := ""
	for p in path.get_file().get_basename().split("_"):
		out += p.capitalize().replace(" ", "")
	return out


func _enter_map(path: String, spawn: String) -> bool:
	GameState.change_map(path, spawn)
	var ok: bool = await t.wait_scene(_scene_node_name(path), 20.0)
	if ok:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			if Transition._rect.color.a <= 0.01:
				break
			await t.frames(1)
		await t.frames(2)
	return ok


func _advance_story_with_video(timeout: float) -> Dictionary:
	var seen: Array = []
	var video_gezien := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var map: Node = t.scene()
		var vid: Node = map.get_node_or_null("CutsceneVideo") if map != null else null
		if vid != null:
			video_gezien = true
			if vid.has_method("is_done") and not bool(vid.call("is_done")):
				await t.get_tree().create_timer(0.35).timeout
				_klik()
				await t.frames(3)
				continue
		if Dialog.is_open:
			var line := "%s: %s" % [Dialog.name_label.text, Dialog.text_label.text]
			if seen.is_empty() or seen[seen.size() - 1] != line:
				seen.append(line)
			if Dialog._is_typing():
				await t.frames(2)
			else:
				await t.press_interact()
		elif not Story.running:
			await t.frames(6)
			if not Story.running and vid == null:
				break
		else:
			await t.frames(1)
	return {"lines": seen, "video": video_gezien}


func _pendant_slot() -> void:
	t.check("CS-11 dormant id", VideoSlot.ATRIUM_PENDANT == "dialogue_atrium_pendant")
	GameState.story_flags.erase("cutscene_cs11_gezien")
	var map := _dummy_map()
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	await VideoSlot.before_dialogue(VideoSlot.ATRIUM_PENDANT, map)
	t.check("CS-11 start via Atrium-slot en zet vlag", GameState.story_flags.has("cutscene_cs11_gezien"))
	t.check("CS-11 speelt maar één keer", not Videos.will_play("cs11") and Videos.play("cs11", map) == null)
	var hang: Array[String] = Dreiging.lines({})
	t.check("CS-11: filmpje vervangt Welcome-regel", not " ".join(hang).contains("Welcome to the World Warper, Dax."))
	t.check("CS-11: pendant-key-regel weg", not hang.any(func(l): return "Only to that Pendant." in l))
	t.check("CS-11: einde_hanger nog geldig", Dreiging.einde_hanger({}) == 12)
	var ah_i := hang.find("ECHO: ...Ah.")
	t.check("CS-11: beat_at ...Ah. blijft cue 2", ah_i >= 0 and Dreiging.beat_at(ah_i, {}) == 2)
	map.queue_free()
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _threat_slot() -> void:
	t.check("CS-12 dormant id", VideoSlot.ATRIUM_THREAT == "dialogue_atrium_threat")
	GameState.story_flags.erase("cutscene_cs12_gezien")
	var map := _dummy_map()
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	await VideoSlot.before_dialogue(VideoSlot.ATRIUM_THREAT, map)
	t.check("CS-12 start via Atrium-threat-slot en zet vlag", GameState.story_flags.has("cutscene_cs12_gezien"))
	t.check("CS-12 speelt maar één keer", not Videos.will_play("cs12") and Videos.play("cs12", map) == null)
	t.check("CS-12: scene cs12 vrij", GameState.scene_seen("cs12"))
	var hang: Array[String] = Dreiging.lines({})
	t.check("CS-12: opening Sapientia weg", not hang.any(func(l): return l == "Sapientia: ECHO. You found him."))
	t.check("CS-12: identity-regel weg", not hang.any(func(l): return "I am Sapientia." in l and l.begins_with("Sapientia:")))
	t.check("CS-12: zes archieven weg", not hang.any(func(l): return "Now I want all six." in l))
	t.check("CS-12: story for later weg", not hang.any(func(l): return l.ends_with("But that is a story for later.")))
	var dri_start := Dreiging.einde_hanger({}) + 1
	t.check("CS-12: eerste dreiging-regel is ECHO's comeback", dri_start >= 0 and dri_start < hang.size()
			and hang[dri_start] == "ECHO: Sapientia. I thought you no longer... spoke directly."
			and Dreiging.beat_at(dri_start, {}) == 3)
	var last_echo3 := -1
	for j in hang.size():
		if Dreiging.beat_at(j, {}) == 3 and hang[j].begins_with("ECHO:"):
			last_echo3 = j
	t.check("CS-12: laatste ECHO in beat 3", last_echo3 >= 0
			and hang[last_echo3] == "ECHO: Sapientia, you know this can't be done. The World Warper cannot be forced—")
	var cue4 := last_echo3 + 1
	while cue4 < hang.size() and Dreiging.beat_at(cue4, {}) != 4:
		cue4 += 1
	t.check("CS-12: cue 4 begint met Vesper", cue4 < hang.size() and hang[cue4].begins_with("Vesper:"))
	GameState.story_flags.erase("cutscene_cs12_gezien")
	var zonder: Array[String] = Dreiging.lines({})
	t.check("CS-12 uit: dreiging compleet", zonder.any(func(l): return l == "Sapientia: ECHO. You found him.")
			and zonder.any(func(l): return l == "ECHO: But that is a story for later."))
	GameState.story_flags["cutscene_cs11_gezien"] = true
	GameState.story_flags["cutscene_cs12_gezien"] = true
	var combo: Array[String] = Dreiging.lines({})
	t.check("CS-11+CS-12: Welcome en dreiging-opening weg", not combo.any(func(l): return "Welcome to the World Warper" in l)
			and not combo.any(func(l): return l == "Sapientia: ECHO. You found him."))
	t.check("CS-11+CS-12: einde_hanger", Dreiging.einde_hanger({}) == 12)
	GameState.story_flags.erase("cutscene_cs11_gezien")
	GameState.story_flags.erase("cutscene_cs12_gezien")
	map.queue_free()
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


const _CS12_FILM_REGELS: Array[String] = [
	"Sapientia: ECHO. You found him.",
	"Sapientia: I am what humanity needed. I am the end of pain. I am Sapientia.",
	"Sapientia: Six Archives. Six cores. Each a piece of what humanity once was. I have two. You woke them. Now I want all six.",
	"ECHO: But that is a story for later.",
]


func _threat_hal_integratie() -> void:
	await _threat_hal_eerste_bezoek(false)
	await _threat_hal_eerste_bezoek(true)


func _threat_hal_eerste_bezoek(drift: bool) -> void:
	var label := " drift" if drift else " zonder drift"
	GameState.story_flags.erase("cutscene_cs12_gezien")
	GameState.story_flags.erase("cutscene_cs06_gezien")
	GameState.story_flags.erase("cutscene_cs11_gezien")
	GameState.story_flags["cutscene_cs06_gezien"] = true
	GameState.story_flags["cutscene_cs11_gezien"] = true
	var bron: ScenesData.FlagBron = ScenesData.FlagBron.new()
	bron.story_flags = {}
	if drift:
		bron.story_flags[Canon.FLAG_DRIFT_DONE] = true
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	var sc := HangerScene.instantiate() as WorldWarperHangerScene
	t.get_tree().root.add_child(sc)
	sc.maybe_play(bron)
	var t0 := Time.get_ticks_msec()
	while not sc._playing and Time.get_ticks_msec() - t0 < 8000:
		await t.frames(3)
	if not sc._playing:
		t.check("CS-12 Hal start" + label, false)
		sc.queue_free()
		return
	while sc._line_step_busy and Time.get_ticks_msec() - t0 < 8000:
		await t.frames(2)
	var dreiging_i := sc._lines.find("Sapientia: ECHO. You found him.")
	if dreiging_i < 0:
		t.check("CS-12 Hal: dreiging-slot in lijst" + label, false)
		sc.queue_free()
		return
	while sc._playing and sc._line_i < dreiging_i:
		await _hal_advance(sc)
	var verwacht := "ECHO: Sapientia. I thought you no longer... spoke directly."
	t0 = Time.get_ticks_msec()
	while sc._playing and Time.get_ticks_msec() - t0 < 40000:
		if GameState.story_flags.has("cutscene_cs12_gezien") and sc.text_label.text == verwacht:
			break
		await t.frames(5)
	t.check("CS-12 Hal: filmpje gezien" + label, GameState.story_flags.has("cutscene_cs12_gezien"))
	t.check("CS-12 Hal: eerste dreiging na filmpje" + label, sc.text_label.text == verwacht)
	var gezien: Array[String] = []
	while sc._playing:
		var txt := sc.text_label.text
		if txt != "":
			gezien.append(txt)
		t.check("CS-12 Hal: geen vervangen filmzin" + label, not _CS12_FILM_REGELS.has(txt))
		await _hal_advance(sc)
	t.check("CS-12 Hal: hal flags" + label, bool(bron.story_flags.get(Canon.FLAG_HANGER, false))
			and bool(bron.story_flags.get(Canon.FLAG_DREIGING, false))
			and bool(bron.story_flags.get(Dreiging.FLAG, false)))
	t.check("CS-12 Hal: geen filmzin in hele loop" + label,
			not gezien.any(func(l): return _CS12_FILM_REGELS.has(l)))
	sc.queue_free()
	bron.queue_free()
	GameState.story_flags.erase("cutscene_cs12_gezien")
	GameState.story_flags.erase("cutscene_cs06_gezien")
	GameState.story_flags.erase("cutscene_cs11_gezien")


func _hal_advance(sc: WorldWarperHangerScene) -> void:
	sc._advance()
	while sc._line_step_busy:
		await t.frames(2)


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
