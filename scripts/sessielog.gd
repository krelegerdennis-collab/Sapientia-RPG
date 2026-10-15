extends Node
## Autoload "Sessielog" (playtest, Dennis 15 okt 2026): licht sessielogboek als JSON-lines.
## Doel: Dennis speelt op zijn Android-telefoon (of in de webbuild) en we krijgen echte data:
## waar loopt iemand, waar blijft hij hangen, hoe gaan de gevechten, wat is er gebeurd.
##
## - Eén bestand per sessie: user://sessielogs/sessie_<id>.jsonl, één JSON-object per regel.
##   Elke regel heeft "t" (seconden sinds de start) en "e" (soort gebeurtenis). De startregel heeft
##   de wandklok (utc/unix), zodat het logboek bij een schermopname past.
## - Goedkoop: regels worden in het geheugen gebufferd en hooguit elke FLUSH_SECS seconden of na
##   FLUSH_LINES regels in één keer weggeschreven (nooit per frame). Positie wordt elke POS_SECS
##   gemeten, maar alleen weggeschreven bij een andere tegel (of elke IDLE_SECS als hij stilstaat).
## - Privacy: willekeurige sessie-id; geen naam van de speler, geen apparaat-id, geen locatie.
##   Spelnamen komen niet in het logboek (alleen held-ids). Uit te zetten: Opties > Session Log.
## - Export: Opties > Export Log (web = download, anders Downloads/Documenten, anders het pad).
##
## Andere scripts melden alleen kort: Sessielog.noteer("soort", {...}); uit/zonder start = no-op.
## Gebeurtenissen: start, kaart, kaart_tijd, warp, pos, dir, knop, bump, menu, dialoog_start,
## dialoog_eind, cutscene_start, cutscene_eind, gevecht_start, ronde, gevecht_eind, dood,
## respawn, scherm, pauze, hervat, einde. Samenvatten: tools/sessie_samenvatting.py.

const MAP := "user://sessielogs"
const FORMAAT := 1
const POS_SECS := 0.5
const IDLE_SECS := 5.0
const FLUSH_SECS := 2.0
const FLUSH_LINES := 48
## Maximale grootte van één sessiebestand (daarna alleen nog belangrijke gebeurtenissen, geen pos/dir).
const MAX_BYTES := 3_000_000
const MAX_BESTANDEN := 8
const EXPORT_SESSIES := 3
const KLEMBORD_MAX := 30000
const ACTIES := ["interact", "cancel", "run", "kern"]
const RICHTING := {"move_up": "up", "move_down": "down", "move_left": "left", "move_right": "right"}

## Aan in het spel; in autotests (--...test) uit tot een test hem zelf start.
var actief := false
var sessie_id := ""
var pad := ""
## Alleen voor tests: ander exportdoel dan Downloads/Documenten.
var export_map := ""
var buffer: PackedStringArray = PackedStringArray()
var regels := 0
var bytes := 0
var schrijf_aantal := 0          # hoe vaak er naar schijf is geschreven (test: geen IO per frame)
var afgekapt := false

var _bestand: FileAccess
var _t0_ms := 0
var _flush_in := 0.0
var _pos_in := 0.0
var _idle_in := 0.0
var _laatste_tegel := Vector2i(-99999, -99999)
var _laatste_kaart := ""
var _kaart_sinds_ms := 0
var _dir := "none"
var _acties_aan := {}
var _bron := "toets"
var _dialoog := false
var _cutscene := false
var _scherm := Vector2i.ZERO
var _speler: Node
var _gevecht := {}
var _pauze_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var in_test := false
	for a in args:
		if str(a).ends_with("test") or str(a).ends_with("tests"):
			in_test = true
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("changed"):
		settings.changed.connect(_on_setting)
	if not in_test and (settings == null or bool(settings.get_value("sessielog"))):
		start()
	else:
		set_process(false)


func _on_setting(key: String) -> void:
	if key != "sessielog":
		return
	var aan := bool(get_node("/root/Settings").get_value("sessielog"))
	if aan and not actief:
		start()
	elif not aan and actief:
		stop()


# ---------------------------------------------------------------- start / stop
## Nieuwe sessie. map_pad = ander doel dan user://sessielogs (alleen tests).
func start(map_pad := MAP) -> void:
	if actief:
		stop()
	sessie_id = _nieuw_id()
	_t0_ms = Time.get_ticks_msec()
	buffer = PackedStringArray()
	regels = 0
	bytes = 0
	schrijf_aantal = 0
	afgekapt = false
	_laatste_tegel = Vector2i(-99999, -99999)
	_laatste_kaart = ""
	_kaart_sinds_ms = _t0_ms
	_dir = "none"
	_acties_aan = {}
	_dialoog = false
	_cutscene = false
	_gevecht = {}
	_scherm = Vector2i.ZERO
	_speler = null
	_pos_in = 0.0
	_idle_in = 0.0
	_flush_in = FLUSH_SECS
	DirAccess.make_dir_recursive_absolute(map_pad)
	_opruimen(map_pad)
	pad = map_pad.path_join("sessie_%s.jsonl" % sessie_id)
	_bestand = FileAccess.open(pad, FileAccess.WRITE)
	actief = _bestand != null
	if not actief:
		push_warning("Sessielog: bestand openen mislukt (%s)" % pad)
		set_process(false)
		return
	set_process(true)
	var now := Time.get_datetime_dict_from_system(true)
	noteer("start", {
		"v": FORMAAT,
		"spel": str(ProjectSettings.get_setting("application/config/version", "")),
		"motor": Engine.get_version_info().get("string", ""),
		"os": OS.get_name(),
		"web": OS.has_feature("web"),
		"android": OS.has_feature("android"),
		"sessie": sessie_id,
		"utc": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]],
		"unix": int(Time.get_unix_time_from_system()),
	})
	_meld_scherm(true)
	if GameState != null and GameState.current_map != "":
		kaart(GameState.current_map)


func stop() -> void:
	if not actief:
		return
	_sluit_kaart()
	noteer("einde", {"duur": snappedf(_nu(), 0.1)})
	flush()
	_bestand = null
	actief = false
	set_process(false)


func _exit_tree() -> void:
	if actief:
		stop()


func _notification(what: int) -> void:
	if not actief:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			noteer("pauze", {})
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			noteer("hervat", {})
		NOTIFICATION_WM_CLOSE_REQUEST:
			stop()


## Willekeurige sessie-id (8 hex-tekens), niet te herleiden tot iemand.
func _nieuw_id() -> String:
	var crypto := Crypto.new()
	var b := crypto.generate_random_bytes(4)
	if b.size() == 4:
		return b.hex_encode()
	return "%08x" % (randi() & 0x7fffffff)


## Oudste sessiebestanden weg (houdt MAX_BESTANDEN - 1 over, de nieuwe komt erbij).
func _opruimen(map_pad: String) -> void:
	var lijst := bestanden(map_pad)
	while lijst.size() > MAX_BESTANDEN - 1:
		DirAccess.remove_absolute(lijst[0])
		lijst.remove_at(0)


## Sessiebestanden, oudste eerst.
func bestanden(map_pad := MAP) -> Array:
	var uit: Array = []
	var d := DirAccess.open(map_pad)
	if d == null:
		return uit
	for f in d.get_files():
		if f.begins_with("sessie_") and f.ends_with(".jsonl"):
			uit.append(map_pad.path_join(f))
	uit.sort_custom(func(a, b): return FileAccess.get_modified_time(a) < FileAccess.get_modified_time(b) \
			or (FileAccess.get_modified_time(a) == FileAccess.get_modified_time(b) and a < b))
	return uit


# ---------------------------------------------------------------- schrijven
func _nu() -> float:
	return (Time.get_ticks_msec() - _t0_ms) / 1000.0


## Eén gebeurtenis in de buffer (geen schijf-IO). Onbekende/uit = niets.
func noteer(soort: String, data: Dictionary = {}) -> void:
	if not actief:
		return
	if afgekapt and soort in ["pos", "dir", "knop"]:
		return
	var d := {"t": snappedf(_nu(), 0.1), "e": soort}
	d.merge(data)
	var regel := JSON.stringify(d)
	buffer.append(regel)
	regels += 1
	bytes += regel.length() + 1
	if bytes > MAX_BYTES and not afgekapt:
		afgekapt = true
		buffer.append(JSON.stringify({"t": snappedf(_nu(), 0.1), "e": "afgekapt", "bytes": bytes}))
	if buffer.size() >= FLUSH_LINES:
		flush()


## Buffer naar schijf (één schrijfactie).
func flush() -> void:
	if buffer.is_empty() or _bestand == null:
		return
	_bestand.store_string("\n".join(buffer) + "\n")
	_bestand.flush()
	buffer = PackedStringArray()
	schrijf_aantal += 1


func _process(delta: float) -> void:
	if not actief:
		return
	_flush_in -= delta
	if _flush_in <= 0.0:
		_flush_in = FLUSH_SECS
		flush()
	_poll_invoer()
	_poll_toestand()
	_pos_in -= delta
	if _pos_in <= 0.0:
		_pos_in = POS_SECS
		_meet_positie()
	var vp := get_viewport()
	if vp != null:
		var g := Vector2i(vp.get_visible_rect().size)
		if g != _scherm:
			_meld_scherm(false)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		_bron = "touch"
	elif event is InputEventKey:
		_bron = "toets"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_bron = "pad"


# ---------------------------------------------------------------- invoer
func _poll_invoer() -> void:
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	var d := "none"
	if dy != 0 and (dx == 0 or absi(dy) >= absi(dx)):
		d = "down" if dy > 0 else "up"
	elif dx != 0:
		d = "right" if dx > 0 else "left"
	if d != _dir:
		_dir = d
		noteer("dir", {"d": d, "bron": _bron})
	for a in ACTIES:
		if not InputMap.has_action(a):
			continue
		var aan := Input.is_action_pressed(a)
		if aan and not _acties_aan.get(a, false):
			noteer("knop", {"a": a, "bron": _bron})
		_acties_aan[a] = aan


# ---------------------------------------------------------------- toestand (dialoog, cutscene)
func _poll_toestand() -> void:
	var dlg := get_node_or_null("/root/Dialog")
	var open: bool = dlg != null and bool(dlg.is_open)
	if open != _dialoog:
		_dialoog = open
		if open:
			var wie := ""
			var n := 0
			if dlg.get("name_label") != null:
				wie = str(dlg.name_label.text)
			var l = dlg.get("_lines")
			if l is Array:
				n = l.size()
			noteer("dialoog_start", {"wie": wie, "regels": n, "kaart": _kaart_id()})
		else:
			noteer("dialoog_eind", {})
	var story := get_node_or_null("/root/Story")
	var loopt: bool = story != null and bool(story.running)
	if loopt != _cutscene:
		_cutscene = loopt
		if loopt:
			noteer("cutscene_start", {"id": str(story.current_event), "kaart": _kaart_id()})
		else:
			noteer("cutscene_eind", {})


## Losse cutscene (bv. de wereldkaart-film) die niet via Story loopt.
func cutscene(id: String, start: bool) -> void:
	noteer("cutscene_start" if start else "cutscene_eind", {"id": id, "kaart": _kaart_id()} if start else {"id": id})


# ---------------------------------------------------------------- positie, kaart, scherm
func _kaart_id(p := "") -> String:
	if p == "":
		p = GameState.current_map if GameState != null else ""
	return p.get_file().trim_suffix(".tscn")


func _stijl(p: String) -> String:
	return "som" if KaartStijl.is_som(p) else "oud"


func _meld_scherm(eerste: bool) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_scherm = Vector2i(vp.get_visible_rect().size)
	var w := Vector2i(DisplayServer.window_get_size())
	noteer("scherm", {"vp": [_scherm.x, _scherm.y], "venster": [w.x, w.y], "dpi": DisplayServer.screen_get_dpi(),
			"eerste": eerste})


func _vind_speler() -> Node:
	if _speler != null and is_instance_valid(_speler) and _speler.is_inside_tree():
		return _speler
	var scene := get_tree().current_scene
	_speler = scene.get_node_or_null("Objects/Player") if scene != null else null
	return _speler


func _meet_positie() -> void:
	if GameState.in_battle or GameState.changing_map:
		return
	var p := _vind_speler()
	if p == null or not p.has_method("get_tile"):
		return
	var t: Vector2i = p.get_tile()
	if t != _laatste_tegel:
		_laatste_tegel = t
		_idle_in = IDLE_SECS
	else:
		_idle_in -= POS_SECS
		if _idle_in > 0.0:
			return
		_idle_in = IDLE_SECS
	var f := "down"
	if "facing" in p:
		f = _richting_naam(p.facing)
	noteer("pos", {"kaart": _kaart_id(), "x": t.x, "y": t.y, "f": f})


func _richting_naam(v: Vector2i) -> String:
	if v == Vector2i.UP:
		return "up"
	if v == Vector2i.LEFT:
		return "left"
	if v == Vector2i.RIGHT:
		return "right"
	return "down"


## GameState.enter_map: een kaart is geladen (na een deur, gevecht, load of respawn).
func kaart(p: String) -> void:
	if not actief:
		return
	_sluit_kaart()
	_laatste_kaart = p
	_kaart_sinds_ms = Time.get_ticks_msec()
	_laatste_tegel = Vector2i(-99999, -99999)
	_speler = null
	var w := Vector2i(DisplayServer.window_get_size())
	var vp := get_viewport()
	var v := Vector2i(vp.get_visible_rect().size) if vp != null else Vector2i.ZERO
	noteer("kaart", {"kaart": _kaart_id(p), "stijl": _stijl(p), "hoe": GameState.entry_kind,
			"spawn": GameState.pending_spawn, "vp": [v.x, v.y], "venster": [w.x, w.y]})


## Tijd op de kaart die we verlaten.
func _sluit_kaart() -> void:
	if _laatste_kaart == "":
		return
	var secs := (Time.get_ticks_msec() - _kaart_sinds_ms) / 1000.0
	noteer("kaart_tijd", {"kaart": _kaart_id(_laatste_kaart), "secs": snappedf(secs, 0.1)})
	_laatste_kaart = ""


func warp(van: String, naar: String, spawn: String) -> void:
	noteer("warp", {"van": _kaart_id(van), "naar": _kaart_id(naar), "spawn": spawn})


func bump(tegel: Vector2i) -> void:
	noteer("bump", {"kaart": _kaart_id(), "x": tegel.x, "y": tegel.y})


func menu(scherm: String) -> void:
	noteer("menu", {"scherm": scherm, "kaart": _kaart_id()})


# ---------------------------------------------------------------- gevechten
func _party_stand() -> Array:
	var uit: Array = []
	for h in GameState.party:
		uit.append({"id": str(h.get("id", "")), "hp": int(h.get("hp", 0)), "mhp": int(h.get("max_hp", 0)),
				"mp": int(h.get("mp", 0)), "mmp": int(h.get("max_mp", 0)), "lv": int(h.get("level", 1))})
	return uit


func gevecht_start(vijanden: Array, baas: bool, terrein: String, tegel: Vector2i) -> void:
	if not actief:
		return
	var ids: Array = []
	for v in vijanden:
		ids.append(str(v))
	_gevecht = {"t0": Time.get_ticks_msec(), "ronden": 0, "acties": {}, "party": _party_stand(), "kaart": _kaart_id()}
	noteer("gevecht_start", {"kaart": _kaart_id(), "x": tegel.x, "y": tegel.y, "vijanden": ids, "baas": baas,
			"terrein": terrein, "party": _gevecht["party"]})


## Begin van een ronde (battle.gd): nummer + gekozen heldenacties (alleen ids, geen namen).
func ronde(nr: int, plan: Array) -> void:
	if not actief or _gevecht.is_empty():
		return
	_gevecht["ronden"] = nr
	var acties: Array = []
	for a in plan:
		var actor = a.get("actor")
		if not (actor is Dictionary) or not bool(actor.get("is_hero", false)):
			continue
		var soort := str(a.get("type", ""))
		var wat := ""
		match soort:
			"spell":
				wat = str(a.get("spell", ""))
			"item":
				wat = str(a.get("item", ""))
			"kern_skill":
				wat = str(a.get("skill", ""))
		var sleutel := soort if wat == "" else "%s:%s" % [soort, wat]
		var tel: Dictionary = _gevecht["acties"]
		tel[sleutel] = int(tel.get(sleutel, 0)) + 1
		var item := {"a": soort}
		if wat != "":
			item["wat"] = wat
		acties.append(item)
	noteer("ronde", {"n": nr, "acties": acties})


func gevecht_eind(resultaat: String) -> void:
	if not actief or _gevecht.is_empty():
		return
	var eind := _party_stand()
	var verlies := 0
	var voor: Array = _gevecht["party"]
	for i in mini(voor.size(), eind.size()):
		verlies += maxi(0, int(voor[i]["hp"]) - int(eind[i]["hp"]))
	noteer("gevecht_eind", {"kaart": _gevecht["kaart"], "resultaat": resultaat, "ronden": _gevecht["ronden"],
			"secs": snappedf((Time.get_ticks_msec() - int(_gevecht["t0"])) / 1000.0, 0.1),
			"hp_verlies": verlies, "acties": _gevecht["acties"], "party": eind})
	_gevecht = {}
	flush()


func dood(reden: String) -> void:
	noteer("dood", {"kaart": _kaart_id(), "reden": reden})
	flush()


func respawn(naar: String, soort: String) -> void:
	noteer("respawn", {"naar": _kaart_id(naar), "soort": soort})


# ---------------------------------------------------------------- export
## Samengevoegd logboek van de laatste sessies (nieuwste laatst), als tekst.
func export_tekst(max_sessies := EXPORT_SESSIES) -> String:
	flush()
	var lijst := bestanden()
	var uit := ""
	var vanaf := maxi(0, lijst.size() - max_sessies)
	for i in range(vanaf, lijst.size()):
		uit += FileAccess.get_file_as_string(lijst[i])
	return uit


## Logboek aanbieden. Geeft {"ok": bool, "bericht": String (Engels, voor het scherm), "pad": String}.
func exporteer() -> Dictionary:
	flush()
	var tekst := export_tekst()
	if tekst == "":
		return {"ok": false, "bericht": "No log yet. Play a bit first.", "pad": ""}
	var naam := "sapientia_sessielog_%s.jsonl" % (sessie_id if sessie_id != "" else "x")
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge") and export_map == "":
		JavaScriptBridge.download_buffer(tekst.to_utf8_buffer(), naam, "application/x-ndjson")
		return {"ok": true, "bericht": "Download started: %s" % naam, "pad": naam}
	var doelen: Array = []
	if export_map != "":
		doelen.append(export_map)
	else:
		doelen.append(OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS))
		doelen.append(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS))
	for dir in doelen:
		if str(dir) == "":
			continue
		var p := str(dir).path_join(naam)
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string(tekst)
			f.close()
			_klembord(tekst)
			return {"ok": true, "bericht": "Saved: %s" % p, "pad": p}
	# Geen toegang tot Downloads (Android 10+): het logboek blijft in de app-map, het einde gaat naar het klembord.
	var eigen := ProjectSettings.globalize_path(pad if pad != "" else MAP)
	_klembord(tekst)
	return {"ok": true, "bericht": "Log is in the app folder (%s). Last part copied to clipboard." % eigen.get_base_dir(), "pad": eigen}


func _klembord(tekst: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stuk := tekst
	if stuk.length() > KLEMBORD_MAX:
		stuk = stuk.substr(stuk.length() - KLEMBORD_MAX)
		stuk = stuk.substr(stuk.find("\n") + 1)
	DisplayServer.clipboard_set(stuk)
