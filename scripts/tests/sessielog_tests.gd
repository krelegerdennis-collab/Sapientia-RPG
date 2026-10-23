extends Node
## SessieLog (scripts/core/sessie_log.gd): buffer, JSON-lines, kaart/positie, gevecht,
## privacy, uitzetten, afkappen en export.
## Start: godot --headless --path . -- --sessielogtest

const MAP := "user://sessielog_test"
const EXPORT := "user://sessielog_test_export"
const WilgendalDorpData := preload("res://scripts/data/wilgendal_dorp.gd")

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
			uit.append(str(d.get("type", "")))
	return uit


func _data(d: Dictionary) -> Dictionary:
	return d.get("data", {}) if d is Dictionary else {}


func _leeg(map_pad: String) -> void:
	DirAccess.make_dir_recursive_absolute(map_pad)
	for f in DirAccess.get_files_at(map_pad):
		DirAccess.remove_absolute(map_pad.path_join(f))


func _wacht_story() -> void:
	for _i in 10:
		await get_tree().process_frame
	var n := 0
	while (Story.running or Dialog.is_open) and n < 600:
		if Dialog.is_open:
			Dialog.advance()
		await get_tree().create_timer(0.1).timeout
		n += 1
	for _i in 5:
		await get_tree().process_frame


func _run() -> void:
	var log: Node = get_node("/root/SessieLog")
	check("in een test staat het logboek uit tot de test hem start", not log.actief)
	_leeg(MAP)
	_leeg(EXPORT)
	GameState.player_name = "Testnaam Geheim"
	log.volgt_instelling = false
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
	if p != null and p.has_method("place_at"):
		var route: Array[Vector2i] = []
		for y in range(30, 20, -1):
			route.append(Vector2i(35, y))
		for x in range(35, 20, -1):
			route.append(Vector2i(x, 21))
		for x in range(21, 36):
			route.append(Vector2i(x, 22))
		for y in range(16, 8, -1):
			route.append(Vector2i(35, y))
		for x in range(35, 50):
			route.append(Vector2i(x, 10))
		for i in route.size():
			p.place_at(route[i], Vector2i.UP)
			await get_tree().create_timer(log.POS_SECS + 0.05).timeout
		for _i in 3:
			p.place_at(Vector2i(35, 12), Vector2i.UP)
			await get_tree().create_timer(log.POS_SECS + 0.05).timeout
	var obj: Node = load("res://scenes/story_object.tscn").instantiate()
	obj.event = "cocon"
	get_tree().current_scene.add_child(obj)
	obj.interact(p)
	await _wacht_story()
	Story.run("cocon")
	await _wacht_story()
	obj.queue_free()
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
		geldig = geldig and d is Dictionary and d.has("t") and d.has("type") and d.has("data")
	check("elke regel is JSON met t, type en data (%d regels)" % regels.size(), geldig and regels.size() > 60)
	var start_d := _data(regels[0])
	check("startregel: formaat, utc, os, geen naam", soorten[0] == "sessie_start" and start_d.get("v") == log.FORMAAT
			and str(start_d.get("utc", "")).ends_with("Z") and start_d.has("os"))
	var kaart_ok := false
	var pos_ok := false
	var art_pos := true
	var art_kaart := false
	var n_pos := 0
	var info := {}
	for d in regels:
		var dd := _data(d)
		if d["type"] == "kaart" and dd.get("kaart") == "dorp_wilgendal" and dd.get("stijl") == "som":
			kaart_ok = true
		if d["type"] == "pos" and dd.get("kaart") == "dorp_wilgendal" and dd.has("x") and dd.has("y") and dd.has("f"):
			pos_ok = true
		if d["type"] == "pos":
			art_pos = art_pos and dd.get("stijl", "") in ["som", "oud"] and str(dd.get("tileset", "")) != ""
			n_pos += 1
		if d["type"] == "kaart" and dd.get("kaart") == "dorp_wilgendal":
			art_kaart = dd.get("gebied") == "wilgendal" and dd.get("palet") == "wilgendal" \
					and str(dd.get("tileset", "")).ends_with("som/wilgendal/terrain.tres")
		if d["type"] == "kaart_info" and dd.get("kaart") == "dorp_wilgendal":
			info = dd
	check("kaart-regel (dorp_wilgendal, stijl som)", kaart_ok)
	var niet_knop := soorten.filter(func(x): return x != "knop")
	check("positie-regel met kaart, tegel en kijkrichting (%s)" % [niet_knop], pos_ok)
	check("elke pos-regel draagt stijl en tileset (%d)" % n_pos, art_pos and n_pos > 0)
	check("kaart-regel: gebied, palet en SoM-tileset (RPG ART)", art_kaart)
	var rect: Array = info.get("rect", [])
	check("kaart_info: stijl som, grondrechthoek van de kaart (%s)" % [rect], info.get("stijl") == "som"
			and rect.size() == 4 and int(rect[2]) == WilgendalDorpData.W and int(rect[3]) == WilgendalDorpData.H)
	check("gevecht_start, gevecht_eind, dood en respawn gelogd", "gevecht_start" in soorten and "gevecht_eind" in soorten
			and "dood" in soorten and "respawn" in soorten)
	var ex := regels.filter(func(d): return d["type"] == "examine")
	var cs := regels.filter(func(d): return d["type"] == "cutscene_start")
	check("object bekijken: 'examine' met id en kaart (geen cutscene_start)", ex.size() == 1 and _data(ex[0]).get("id") == "cocon"
			and _data(ex[0]).get("kaart") == "dorp_wilgendal" and "examine_eind" in soorten)
	check("echte cutscene (Story.run): cutscene_start + cutscene_eind", cs.size() == 1 and _data(cs[0]).get("id") == "cocon"
			and "cutscene_eind" in soorten)
	var bewaar := OS.get_environment("SESSIELOG_BEWAAR")
	if bewaar != "":
		var f := FileAccess.open(bewaar, FileAccess.WRITE)
		if f != null:
			f.store_string(FileAccess.get_file_as_string(log.pad))
	var tekst := FileAccess.get_file_as_string(log.pad)
	check("privacy: de spelersnaam staat niet in het logboek", not tekst.contains("Testnaam Geheim"))

	log.export_map = EXPORT
	var uit: Dictionary = log.exporteer()
	check("export naar een map (%s)" % str(uit.get("pad", "")), bool(uit["ok"]) and FileAccess.file_exists(str(uit["pad"]))
			and FileAccess.get_file_as_string(str(uit["pad"])).contains("\"type\":\"sessie_start\""))
	log.export_map = ""

	Settings.set_value("sessie_log", 1)
	log.volgt_instelling = true
	await get_tree().process_frame
	Settings.set_value("sessie_log", 0)
	await get_tree().process_frame
	check("Opties > Session Log uit: logboek stopt, laatste regel sessie_stop", not log.actief
			and _soorten(_regels(log.pad))[-1] == "sessie_stop")
	var n: int = log.regels
	log.noteer("knop", {"a": "interact"})
	check("uit = noteer doet niets", log.regels == n)
	Settings.set_value("sessie_log", 1)
	await get_tree().process_frame
	check("weer aan: nieuwe sessie", log.actief)
	log.stop()
	log.start(MAP)
	var groot := "x".repeat(992)
	for i in 2600:
		log.noteer("menu_open", {"welk": groot, "i": i})
		if i % 200 == 0:
			log.flush()
	log.flush()
	var menu_voor: int = _regels(log.pad).filter(func(d): return d is Dictionary and d.get("type") == "menu_open").size()
	var eerste_menu_i := -1
	for d in _regels(log.pad):
		if d is Dictionary and d.get("type") == "menu_open":
			eerste_menu_i = int(_data(d).get("i", -1))
			break
	check("log vol en afgekapt bij echte MAX_BYTES", log.vol and log.afgekapt and log.bytes <= log.MAX_BYTES)
	var regels_voor: int = log.regels
	log.noteer("pos", {"x": 1})
	log.noteer("pos", {"x": 2})
	log.noteer("dood", {"reden": "test"})
	log.flush()
	var regels_na := _regels(log.pad)
	var menu_na: int = regels_na.filter(func(d): return d is Dictionary and d.get("type") == "menu_open").size()
	var eerste_menu_i_na := -1
	for d in regels_na:
		if d is Dictionary and d.get("type") == "menu_open":
			eerste_menu_i_na = int(_data(d).get("i", -1))
			break
	var pos_nieuw := regels_na.any(func(d): return d is Dictionary and d.get("type") == "pos" and int(_data(d).get("x", -1)) in [1, 2])
	var dood_ok := regels_na.any(func(d): return d is Dictionary and d.get("type") == "dood" and str(_data(d).get("reden", "")) == "test")
	var file_bytes: int = FileAccess.open(log.pad, FileAccess.READ).get_length()
	var trim := menu_na < menu_voor or eerste_menu_i_na > eerste_menu_i
	check("na MAX_BYTES: afgekapt, geen pos meer, dood behouden (_zorg_ruimte)", log.afgekapt and not pos_nieuw and dood_ok
			and file_bytes <= log.MAX_BYTES and log.bytes <= log.MAX_BYTES and log.regels <= regels_voor + 1
			and (trim or log.regels == regels_voor + 1))
	log.stop()
	check("bestanden() vindt de sessies; opruimen houdt er hooguit MAX_BESTANDEN", log.bestanden(MAP).size() >= 2
			and log.bestanden(MAP).size() <= log.MAX_BESTANDEN)
	_leeg(MAP)
	_leeg(EXPORT)
	print("SESSIELOGTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)
