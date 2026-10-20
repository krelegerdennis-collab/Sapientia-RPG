extends Node
## Sessielog (playtest-logboek, scripts/sessielog.gd): buffer, JSON-lines, kaart/positie, gevecht,
## privacy, uitzetten, afkappen en export.
## Start: godot --headless --path . -- --sessielogtest

const MAP := "user://sessielog_test"
const EXPORT := "user://sessielog_test_export"

var failures := 0
var passes := 0


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _regels(p: String) -> Array:
	var uit: Array = []
	for r in FileAccess.get_file_as_string(p).split("\n", false):
		uit.append(JSON.parse_string(r))
	return uit


func _soorten(regels: Array) -> Array:
	var uit: Array = []
	for d in regels:
		if d is Dictionary:
			uit.append(str(d.get("e", "")))
	return uit


func _leeg(map_pad: String) -> void:
	DirAccess.make_dir_recursive_absolute(map_pad)
	for f in DirAccess.get_files_at(map_pad):
		DirAccess.remove_absolute(map_pad.path_join(f))


func _run() -> void:
	var log: Node = get_node("/root/Sessielog")
	check("in een test staat het logboek uit tot de test hem start", not log.actief)
	_leeg(MAP)
	_leeg(EXPORT)
	GameState.player_name = "Testnaam Geheim"
	log.start(MAP)
	check("start: bestand in de testmap, 8 hex-tekens sessie-id", log.actief and log.pad.begins_with(MAP)
			and log.sessie_id.length() == 8 and log.sessie_id.is_valid_hex_number())
	log.flush()
	var schrijf0: int = log.schrijf_aantal
	for i in 20:
		log.noteer("knop", {"a": "interact", "bron": "toets"})
	check("gebufferd: 20 regels zonder schijf-IO", log.schrijf_aantal == schrijf0 and log.buffer.size() == 20)
	for i in log.FLUSH_LINES:
		log.noteer("knop", {"a": "cancel", "bron": "toets"})
	check("na FLUSH_LINES regels één schrijfactie", log.schrijf_aantal == schrijf0 + 1)
	for _i in 30:
		await get_tree().process_frame
	check("geen schrijfactie per frame (%d)" % (log.schrijf_aantal - schrijf0), log.schrijf_aantal - schrijf0 <= 2)

	get_tree().change_scene_to_file("res://scenes/maps/dorp_wilgendal.tscn")
	await get_tree().create_timer(1.5).timeout
	var p: Node = get_tree().current_scene.get_node_or_null("Objects/Player")
	if p != null and p.has_method("place_at"):
		p.place_at(Vector2i(35, 30), Vector2i.UP)
	await get_tree().create_timer(1.2).timeout
	log.gevecht_start(["moskonijn"], false, "gras", Vector2i(35, 30))
	log.ronde(1, [{"actor": {"is_hero": true}, "type": "attack"}])
	log.gevecht_eind("win")
	log.dood("battle")
	log.respawn("res://scenes/maps/dorp_wilgendal.tscn", "checkpoint")
	log.flush()
	var regels := _regels(log.pad)
	var soorten := _soorten(regels)
	var geldig := true
	for d in regels:
		geldig = geldig and d is Dictionary and d.has("t") and d.has("e")
	check("elke regel is JSON met t en e (%d regels)" % regels.size(), geldig and regels.size() > 60)
	check("startregel: formaat, utc, os, geen naam", soorten[0] == "start" and regels[0]["v"] == log.FORMAAT
			and str(regels[0]["utc"]).ends_with("Z") and regels[0].has("os"))
	var kaart_ok := false
	var pos_ok := false
	var art_pos := true
	var art_kaart := false
	var n_pos := 0
	var info := {}
	for d in regels:
		if d["e"] == "kaart" and d["kaart"] == "dorp_wilgendal" and d["stijl"] == "som":
			kaart_ok = true
		if d["e"] == "pos" and d["kaart"] == "dorp_wilgendal" and d.has("x") and d.has("y") and d.has("f"):
			pos_ok = true
		if d["e"] == "pos":
			art_pos = art_pos and d.get("stijl", "") in ["som", "oud"] and str(d.get("tileset", "")) != ""
			n_pos += 1
		if d["e"] == "kaart" and d["kaart"] == "dorp_wilgendal":
			art_kaart = d.get("gebied") == "wilgendal" and d.get("palet") == "wilgendal" \
					and str(d.get("tileset", "")).ends_with("som/wilgendal/terrain.tres")
		if d["e"] == "kaart_info" and d["kaart"] == "dorp_wilgendal":
			info = d
	check("kaart-regel (dorp_wilgendal, stijl som)", kaart_ok)
	var niet_knop := soorten.filter(func(x): return x != "knop")
	check("positie-regel met kaart, tegel en kijkrichting (%s)" % [niet_knop], pos_ok)
	check("elke pos-regel draagt stijl en tileset (%d)" % n_pos, art_pos and n_pos > 0)
	check("kaart-regel: gebied, palet en SoM-tileset (RPG ART)", art_kaart)
	var rect: Array = info.get("rect", [])
	check("kaart_info: stijl som, grondrechthoek van de kaart (%s)" % [rect], info.get("stijl") == "som"
			and rect.size() == 4 and int(rect[2]) == 64 and int(rect[3]) == 40)
	check("gevecht_start, gevecht_eind, dood en respawn gelogd", "gevecht_start" in soorten and "gevecht_eind" in soorten
			and "dood" in soorten and "respawn" in soorten)
	var tekst := FileAccess.get_file_as_string(log.pad)
	check("privacy: de spelersnaam staat niet in het logboek", not tekst.contains("Testnaam Geheim"))

	log.export_map = EXPORT
	var uit: Dictionary = log.exporteer()
	check("export naar een map (%s)" % str(uit.get("pad", "")), bool(uit["ok"]) and FileAccess.file_exists(str(uit["pad"]))
			and FileAccess.get_file_as_string(str(uit["pad"])).contains("\"e\":\"start\""))
	log.export_map = ""

	Settings.set_value("sessielog", false)
	await get_tree().process_frame
	check("Opties > Session Log uit: logboek stopt, laatste regel 'einde'", not log.actief
			and _soorten(_regels(log.pad))[-1] == "einde")
	var n: int = log.regels
	log.noteer("knop", {"a": "interact"})
	check("uit = noteer doet niets", log.regels == n)
	Settings.set_value("sessielog", true)
	await get_tree().process_frame
	check("weer aan: nieuwe sessie", log.actief)
	log.stop()
	log.start(MAP)
	log.bytes = log.MAX_BYTES
	log.noteer("pos", {"x": 1})
	var voor: int = log.regels
	log.noteer("pos", {"x": 2})
	log.noteer("dood", {"reden": "test"})
	check("na MAX_BYTES: 'afgekapt', geen pos meer, wel belangrijke regels", log.afgekapt and log.regels == voor + 1)
	log.stop()
	check("bestanden() vindt de sessies; opruimen houdt er hooguit MAX_BESTANDEN", log.bestanden(MAP).size() >= 2
			and log.bestanden(MAP).size() <= log.MAX_BESTANDEN)
	_leeg(MAP)
	_leeg(EXPORT)
	print("SESSIELOGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
