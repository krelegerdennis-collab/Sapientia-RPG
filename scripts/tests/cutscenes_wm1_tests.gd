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
const LOTTE_SCENE := "res://scenes/maps/archief_2_v2_lotte.tscn"
const ScenesScreen := preload("res://scripts/ui/scenes_screen.gd")
## In-engine Seren-regels die CS-10 vervangt (de kamer toont ze alleen zonder filmpje).
const CS10_FALLBACK_SNIPPETS: Array[String] = [
	"The glitch tears. Seren breaks it herself.",
	"I can hear the Order of the Silent Flame again.",
	"Silence is what Sapientia wants: to erase emotion.",
	"I'm Seren.",
	"I'm a healer. Let me come with you.",
]
const CS10_SLOTREGEL := "Seren joins. Priest, with Light and Ice, grade 1."

var t: Node
var _live_ids: Array[String] = []
var _live_paden := {}
var _hal_klaar := false
var _wacht_doel := ""
var _wacht_tekst := ""
## Per Hal-stap, niet één open wacht van de hele scène.
const HAL_STAP_SEC := 2.0
const HAL_FILM_SEC := 3.0


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
	await _cs10_filmpad()
	await _hal_filmpad()
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


## CS-10: Lotte-einde (archief2_verwerk_einde) -> kamer laadt -> filmpje -> vlag, Seren, menu, save.
func _cs10_filmpad() -> void:
	var saved_flags: Dictionary = GameState.story_flags.duplicate(true)
	var saved_step: int = GameState.story_step
	var saved_history: Array = Story.history.duplicate()
	if Dialog.is_open:
		Dialog.close()
	GameState.new_game("Dax")
	GameState.story_flags.erase("cutscene_cs10_gezien")
	GameState.scenes_seen = GameState.scenes_seen.filter(func(s): return str(s) != "cs10")
	t.check("CS-10 E2E: trigger nog niet, menu op slot", not GameState.story_flags.has("cutscene_cs10_gezien")
			and not GameState.scene_seen("cs10") and await _scenes_rij("cs10", "Corrupted Seren", false))
	GameState.pending_story_loss = true
	var einde := GameState.archief2_verwerk_einde("win")
	t.check("CS-10 E2E: winst zet archief2_lotte_join", einde == "win" and GameState.archief2_lotte_join
			and not GameState.pending_story_loss)
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	var geladen := await _enter_map(LOTTE_SCENE, "zuid")
	t.check("CS-10 E2E: Seren's Room geladen", geladen and t.scene() != null
			and str(t.scene().scene_file_path) == LOTTE_SCENE)
	if not geladen:
		_einde_filmpad(saved_flags, saved_step, saved_history)
		return
	var stuk: Dictionary = await _kamer_filmpje(12.0)
	var tekst := " ".join((stuk.get("lines", []) as Array).map(func(l): return str(l)))
	var pad := str(stuk.get("path", ""))
	t.check("CS-10 E2E: filmpje cs10 / cs10_corrupted_seren.ogv", str(stuk.get("id", "")) == "cs10"
			and pad == str(Videos.spec("cs10").get("path", "")) and pad.ends_with("cs10_corrupted_seren.ogv"))
	t.check("CS-10 E2E: vlag en Scenes-unlock", GameState.story_flags.has("cutscene_cs10_gezien")
			and GameState.scene_seen("cs10") and GameState.seen_scenes().has("cs10"))
	t.check("CS-10 E2E: Seren sluit aan, join-vlag verbruikt", GameState.has_member("lotte")
			and GameState.story_flags.has("archief2_lotte_lid") and not GameState.archief2_lotte_join
			and Archief2.sluit_lotte_aan())
	t.check("CS-10 E2E: geen in-engine Seren-regels uit de fallback", not CS10_FALLBACK_SNIPPETS.any(
			func(s: String) -> bool: return s in tekst))
	t.check("CS-10 E2E: wel de slotregel", CS10_SLOTREGEL in tekst)
	var kamer: Node = t.scene()
	t.check("CS-10 E2E: filmpje speelt niet opnieuw", not Videos.will_play("cs10") and Videos.play("cs10", kamer) == null)
	GameState.pending_story_loss = true
	var nog := GameState.archief2_verwerk_einde("win")
	var opnieuw := await _enter_map(LOTTE_SCENE, "zuid")
	var herhaling := await _geen_filmpje(2.5)
	t.check("CS-10 E2E: tweede trigger geen herhaling", nog == "win" and opnieuw and herhaling
			and GameState.story_flags.has("cutscene_cs10_gezien") and not Videos.will_play("cs10"))
	t.check("CS-10 E2E: Scenes-menu toont Corrupted Seren", await _scenes_rij("cs10", "Corrupted Seren", true))
	t.check("CS-10 E2E: solo-save houdt vlag, menu en Seren", await _solo_rondje("user://cs10_filmpad_solo.json", "cs10", "lotte"))
	_einde_filmpad(saved_flags, saved_step, saved_history)


## CS-11 aan het begin van de Hal, CS-12 bij beat 3. Geen poort op CS-10.
func _hal_filmpad() -> void:
	var saved_flags: Dictionary = GameState.story_flags.duplicate(true)
	var saved_step: int = GameState.story_step
	var saved_history: Array = Story.history.duplicate()
	if Dialog.is_open:
		Dialog.close()
	GameState.new_game("Dax")
	for vlag in ["cutscene_cs10_gezien", "cutscene_cs11_gezien", "cutscene_cs12_gezien", "cutscene_cs06_gezien",
			Canon.FLAG_HANGER, Canon.FLAG_DREIGING, Dreiging.FLAG]:
		GameState.story_flags.erase(vlag)
	GameState.scenes_seen = []
	t.check("CS-11 E2E: menu op slot", not GameState.scene_seen("cs11") and await _scenes_rij("cs11", "The Pendant", false))
	t.check("CS-12 E2E: menu op slot", not GameState.scene_seen("cs12") and await _scenes_rij("cs12", "Sapientia Threat", false))
	Videos.allow_in_tests = true
	Cutscene.allow_in_tests = true
	var geladen := await _enter_map(Canon.HAL_SCENE, Canon.HAL_SPAWN)
	var hs := _hanger()
	t.check("CS-11 E2E: Hal geladen, Hanger-scène aanwezig", geladen and hs != null)
	if hs == null:
		_einde_filmpad(saved_flags, saved_step, saved_history)
		return
	var stuk: Dictionary = await _hal_afspelen()
	var hal_fout := str(stuk.get("fout", ""))
	t.check("CS-11 E2E: elke Hal-stap binnen 3s" if hal_fout == "" else "CS-11 E2E: timeout — " + hal_fout, hal_fout == "")
	var ids: Array = stuk.get("ids", [])
	var paden: Dictionary = stuk.get("paden", {})
	var regels: Array = stuk.get("lines", [])
	var tekst := " ".join(regels.map(func(l): return str(l)))
	var pad11 := str(paden.get("cs11", ""))
	var pad12 := str(paden.get("cs12", ""))
	t.check("CS-11 E2E: filmpje cs11 / cs11_pendant.ogv zonder CS-10-poort", ids.size() > 0 and str(ids[0]) == "cs11"
			and pad11 == str(Videos.spec("cs11").get("path", "")) and pad11.ends_with("cs11_pendant.ogv")
			and not GameState.story_flags.has("cutscene_cs10_gezien"))
	t.check("CS-11 E2E: vlag en Scenes-unlock", GameState.story_flags.has("cutscene_cs11_gezien")
			and GameState.scene_seen("cs11") and GameState.seen_scenes().has("cs11"))
	t.check("CS-11 E2E: Welcome en pendant-regels weg", not Dreiging.CS11_ECHO_SKIP.any(
			func(s: String) -> bool: return s in tekst))
	t.check("CS-11 E2E: resterende Hanger-regel (...Ah.)", tekst.contains("ECHO: ...Ah."))
	t.check("CS-12 E2E: filmpje cs12 / cs12_sapientia_threat.ogv na CS-11", ids.find("cs11") >= 0
			and ids.find("cs12") > ids.find("cs11") and pad12 == str(Videos.spec("cs12").get("path", ""))
			and pad12.ends_with("cs12_sapientia_threat.ogv") and not ids.has("cs10"))
	t.check("CS-12 E2E: vlag en Scenes-unlock", GameState.story_flags.has("cutscene_cs12_gezien")
			and GameState.scene_seen("cs12") and GameState.seen_scenes().has("cs12"))
	t.check("CS-12 E2E: filmzinnen niet getoond", not _CS12_FILM_REGELS.any(func(s: String) -> bool: return s in tekst)
			and not tekst.contains("ECHO. You found him."))
	t.check("CS-12 E2E: ECHO's comeback en Hal-vlaggen", tekst.contains("ECHO: Sapientia. I thought you no longer... spoke directly.")
			and GameState.story_flags.has(Canon.FLAG_HANGER) and GameState.story_flags.has(Canon.FLAG_DREIGING)
			and GameState.story_flags.has(Dreiging.FLAG))
	t.check("CS-11 E2E: filmpje speelt niet opnieuw", not Videos.will_play("cs11") and Videos.play("cs11", hs) == null)
	t.check("CS-12 E2E: filmpje speelt niet opnieuw", not Videos.will_play("cs12") and Videos.play("cs12", hs) == null)
	var opnieuw := await _herlaad_map(Canon.HAL_SCENE, Canon.HAL_SPAWN)
	var hs2 := _hanger()
	var stil := await _geen_filmpje(2.0)
	t.check("CS-11 E2E: tweede Hal-bezoek geen herhaling", opnieuw and stil and hs2 != null and not hs2.is_playing()
			and not Dreiging.should_play(GameState.story_flags))
	t.check("CS-12 E2E: tweede Hal-bezoek geen dreiging-filmpje", stil and GameState.story_flags.has("cutscene_cs12_gezien")
			and not Videos.will_play("cs12"))
	t.check("CS-11 E2E: Scenes-menu toont The Pendant", await _scenes_rij("cs11", "The Pendant", true))
	t.check("CS-12 E2E: Scenes-menu toont Sapientia Threat", await _scenes_rij("cs12", "Sapientia Threat", true))
	t.check("CS-11 E2E: solo-save houdt vlag en menu", await _solo_rondje("user://cs11_filmpad_solo.json", "cs11", ""))
	t.check("CS-12 E2E: solo-save houdt vlag en menu", await _solo_rondje("user://cs12_filmpad_solo.json", "cs12", ""))
	_einde_filmpad(saved_flags, saved_step, saved_history)


func _einde_filmpad(flags: Dictionary, step: int, history: Array) -> void:
	if Dialog.is_open:
		Dialog.close()
	_restore_noor_test_state(flags, step, history)
	GameState.archief2_lotte_join = false
	GameState.pending_story_loss = false
	Videos.allow_in_tests = false
	Cutscene.allow_in_tests = false


func _hanger() -> WorldWarperHangerScene:
	var map: Node = t.scene()
	if map == null:
		return null
	return map.find_child("HangerScene", true, false) as WorldWarperHangerScene


func _id_van_pad(pad: String) -> String:
	for id in ["cs06", "cs10", "cs11", "cs12"]:
		if str(Videos.spec(id).get("path", "")) == pad:
			return id
	return ""


## play() heet de node CutsceneVideo. queue_free is uitgesteld, dus het volgende
## filmpje heet CutsceneVideo2 zolang het vorige er nog staat. String.match zonder
## ster vindt die niet.
func _filmpje_nodes(host: Node) -> Array:
	var kids: Array = []
	if host == null:
		return kids
	var stack: Array[Node] = [host]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var pad := str(n.get("video_path"))
		if n != host and (str(n.name).begins_with("CutsceneVideo") or pad.ends_with(".ogv")):
			kids.append(n)
		for c in n.get_children():
			stack.append(c)
	return kids


func _noteer_filmpje(ids: Array[String], paden: Dictionary, vid: Node) -> void:
	if vid == null or not is_instance_valid(vid):
		return
	var pad := str(vid.get("video_path"))
	var id := _id_van_pad(pad)
	if id != "" and not ids.has(id):
		ids.append(id)
		paden[id] = pad


func _actief_filmpje(host: Node) -> Node:
	for k in _filmpje_nodes(host):
		var n := k as Node
		if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if n.has_method("is_done") and bool(n.call("is_done")):
			continue
		return n
	return null


## Zelfde kaart nog eens: wacht tot de oude instantie weg is. wait_scene keert
## meteen terug zolang de huidige scène die naam al heeft.
func _herlaad_map(path: String, spawn: String) -> bool:
	var vorige: Node = t.scene()
	var id := vorige.get_instance_id() if vorige != null else 0
	var t_wacht := Time.get_ticks_msec()
	while GameState.scene_busy() and Time.get_ticks_msec() - t_wacht < 5000:
		await t.frames(1)
	if GameState.scene_busy():
		return false
	GameState.change_map(path, spawn)
	var naam := _scene_node_name(path)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		var s: Node = t.scene()
		if s != null and s.name == naam and s.is_node_ready() and s.get_instance_id() != id:
			var f0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - f0 < 3000:
				if Transition.overlay_alpha() <= 0.01:
					break
				await t.frames(1)
			await t.frames(2)
			return true
		await t.frames(1)
	return false


## skip_now wacht niet op de klik-grace. false = het filmpje bleef langer dan de stap open.
func _sla_filmpje_over(vid: Node) -> bool:
	await t.frames(2)
	if is_instance_valid(vid) and vid.has_method("is_done") and not bool(vid.call("is_done")) and vid.has_method("skip_now"):
		vid.call("skip_now")
	var t0 := Time.get_ticks_msec()
	var lim := int(HAL_STAP_SEC * 1000.0)
	while Time.get_ticks_msec() - t0 < lim:
		if not is_instance_valid(vid) or vid.is_queued_for_deletion():
			return true
		if vid.has_method("is_done") and bool(vid.call("is_done")):
			return true
		await t.frames(1)
	if not is_instance_valid(vid):
		return true
	return vid.has_method("is_done") and bool(vid.call("is_done"))


func _kamer_filmpje(timeout: float) -> Dictionary:
	var lines: Array[String] = []
	var vid_id := ""
	var vid_pad := ""
	var video_gezien := false
	var t0 := Time.get_ticks_msec()
	var na := -1
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var map: Node = t.scene()
		var vid := _actief_filmpje(map)
		if vid != null:
			video_gezien = true
			na = -1
			if vid_id == "":
				vid_pad = str(vid.get("video_path"))
				vid_id = _id_van_pad(vid_pad)
			await _sla_filmpje_over(vid)
			continue
		if Dialog.is_open:
			na = -1
			var line := "%s: %s" % [Dialog.name_label.text, Dialog.text_label.text]
			if lines.is_empty() or lines[lines.size() - 1] != line:
				lines.append(line)
			if Dialog.phase() == Dialog.PHASE_TYPING:
				await t.frames(2)
			else:
				await t.press_interact()
			continue
		if video_gezien:
			if na < 0:
				na = Time.get_ticks_msec()
			if Time.get_ticks_msec() - na > 1500:
				break
		await t.frames(2)
	return {"lines": lines, "id": vid_id, "path": vid_pad, "video": video_gezien}


func _on_filmpje_node(n: Node) -> void:
	var pad := str(n.get("video_path"))
	if str(n.name).begins_with("CutsceneVideo") or pad.ends_with(".ogv"):
		_noteer_filmpje(_live_ids, _live_paden, n)


func _on_hal_klaar() -> void:
	_hal_klaar = true


func _sync_films(ids: Array[String], paden: Dictionary) -> void:
	var hosts: Array[Node] = []
	var hs := _hanger()
	if hs != null:
		hosts.append(hs)
	var map: Node = t.scene()
	if map != null:
		hosts.append(map)
	for host in hosts:
		for gezien in _filmpje_nodes(host):
			_noteer_filmpje(ids, paden, gezien as Node)
	for live_id in _live_ids:
		if not ids.has(live_id):
			ids.append(live_id)
			paden[live_id] = str(_live_paden.get(live_id, ""))


func _wacht_klaar() -> bool:
	var hs := _hanger()
	var host: Node = hs if hs != null else t.scene()
	var vid := _actief_filmpje(host)
	if vid == null and t.scene() != null:
		vid = _actief_filmpje(t.scene())
	match _wacht_doel:
		"starten":
			if _hal_klaar or hs == null:
				return true
			return vid != null or hs.is_playing() or hs.is_line_step_busy()
		"bezig":
			if _hal_klaar or hs == null or vid != null:
				return true
			return not hs.is_line_step_busy()
		"regel":
			if _hal_klaar or hs == null or not hs.is_playing() or vid != null or hs.is_line_step_busy():
				return true
			return hs.text_label.text != _wacht_tekst
		_:
			return false


func _wacht_sec(seconden: float) -> bool:
	var t0 := Time.get_ticks_msec()
	var lim := int(seconden * 1000.0)
	while Time.get_ticks_msec() - t0 < lim:
		if _wacht_klaar():
			return true
		await t.frames(1)
	return _wacht_klaar()


## Eén tik of één filmpje per stap, elk met een eigen tijdslimiet.
func _hal_afspelen() -> Dictionary:
	var ids: Array[String] = []
	var paden := {}
	var lines: Array[String] = []
	var fout := ""
	var gezien_spelen := false
	_live_ids = []
	_live_paden = {}
	_hal_klaar = false
	var hs0 := _hanger()
	if hs0 != null and not hs0.threat_finished.is_connected(_on_hal_klaar):
		hs0.threat_finished.connect(_on_hal_klaar)
	if not t.get_tree().node_added.is_connected(_on_filmpje_node):
		t.get_tree().node_added.connect(_on_filmpje_node)
	var stappen := 0
	while fout == "" and stappen < 120:
		stappen += 1
		_sync_films(ids, paden)
		var hs := _hanger()
		if hs == null:
			fout = "Hanger weg op stap %d" % stappen
			break
		var vid := _actief_filmpje(hs)
		if vid == null:
			vid = _actief_filmpje(t.scene())
		if vid != null:
			var pad := str(vid.get("video_path")).get_file()
			if not await _sla_filmpje_over(vid):
				fout = "filmpje niet weg binnen %.0fs (%s)" % [HAL_STAP_SEC, pad]
			continue
		if hs.is_playing():
			gezien_spelen = true
		elif _hal_klaar or gezien_spelen:
			break
		else:
			_wacht_doel = "starten"
			if not await _wacht_sec(HAL_FILM_SEC):
				fout = "Hal-dialoog startte niet binnen %.0fs" % HAL_FILM_SEC
			continue
		if hs.is_line_step_busy():
			_wacht_doel = "bezig"
			if not await _wacht_sec(HAL_FILM_SEC):
				fout = "beat-stap hing langer dan %.0fs" % HAL_FILM_SEC
			continue
		var txt := hs.text_label.text
		if txt != "" and (lines.is_empty() or lines[lines.size() - 1] != txt):
			lines.append(txt)
		_wacht_tekst = txt
		_wacht_doel = "regel"
		_klik()
		if await _wacht_sec(HAL_STAP_SEC):
			continue
		await t.frames(2)
		var nog := _hanger()
		if nog != null and nog.is_playing() and not nog.is_line_step_busy() and nog.text_label.text == txt:
			_klik()
			if await _wacht_sec(HAL_STAP_SEC):
				continue
		fout = "regel hing langer dan %.0fs: %s" % [HAL_STAP_SEC, txt]
	if fout == "" and stappen >= 120 and not _hal_klaar:
		fout = "meer dan 120 Hal-stappen"
	if t.get_tree().node_added.is_connected(_on_filmpje_node):
		t.get_tree().node_added.disconnect(_on_filmpje_node)
	if hs0 != null and is_instance_valid(hs0) and hs0.threat_finished.is_connected(_on_hal_klaar):
		hs0.threat_finished.disconnect(_on_hal_klaar)
	_sync_films(ids, paden)
	return {"ids": ids, "paden": paden, "lines": lines, "fout": fout}


func _geen_filmpje(seconden: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconden * 1000.0:
		var map: Node = t.scene()
		if _actief_filmpje(map) != null or _actief_filmpje(_hanger()) != null:
			return false
		if Dialog.is_open and Dialog.phase() != Dialog.PHASE_TYPING:
			await t.press_interact()
		else:
			await t.frames(2)
	return _actief_filmpje(t.scene()) == null and _actief_filmpje(_hanger()) == null


func _scenes_rij(id: String, titel: String, open: bool) -> bool:
	var scherm := ScenesScreen.new()
	t.get_tree().root.add_child(scherm)
	await t.frames(3)
	var knop := scherm.find_child("Scene_" + id, true, false) as Button
	var label := str(knop.get_meta("label", "")) if knop != null else ""
	var gezien := knop != null and titel in label and not ("???" in label) and not scherm.is_button_greyed(knop)
	var dicht := knop != null and ("???" in label) and scherm.is_button_greyed(knop)
	scherm.queue_free()
	await t.frames(2)
	return gezien if open else dicht


func _solo_rondje(pad: String, scene_id: String, lid: String) -> bool:
	if GameState.coop_is_guest() or GameState.changing_map or GameState.in_battle:
		return false
	var vlag := "cutscene_%s_gezien" % scene_id
	if not GameState.save_game(Vector2i(13, 15), Vector2i.UP, pad):
		return false
	GameState.new_game("Dax")
	if GameState.story_flags.has(vlag) or GameState.scene_seen(scene_id):
		_wis_save(pad)
		return false
	if not GameState.load_game(pad):
		_wis_save(pad)
		return false
	var ok := GameState.story_flags.has(vlag) and GameState.scene_seen(scene_id) and GameState.seen_scenes().has(scene_id)
	if lid != "":
		ok = ok and GameState.has_member(lid) and GameState.story_flags.has("archief2_lotte_lid")
	ok = ok and await _scenes_rij(scene_id, str(ScenesData.scene(scene_id).get("title", "")), true)
	_wis_save(pad)
	return ok


func _wis_save(pad: String) -> void:
	var abs := ProjectSettings.globalize_path(pad)
	if FileAccess.file_exists(pad):
		DirAccess.remove_absolute(abs)
	if FileAccess.file_exists(pad + ".bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pad + ".bak"))


class Pop extends Node2D:
	var input_locked := false
