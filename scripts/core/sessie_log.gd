extends Node
## Autoload "SessieLog": lokale, offline sessielog voor playtests (JSON Lines). Geen netwerk,
## geen persoonsgegevens (geen spelernaam, geen apparaat-id, geen locatie; van saves alleen de bestandsnaam).
##
## - Eén bestand per sessie: user://logs/sessie_<datum>_<tijd>.jsonl (zelfde seconde: _02, _03, ...).
##   Elke regel: {"t": seconden sinds start, "type": soort, "scene": huidige scène, "data": {...}}.
## - Gebufferd; flush elke FLUSH_SECS, na FLUSH_LINES regels, bij app-pauze/focus kwijt/afsluiten.
## - Max MAX_BESTANDEN bestanden; max MAX_BYTES (daarna afgekapt: geen pos/dir/knop meer).
## - Aan/uit: Settings "sessie_log" (-1 auto, 0 uit, 1 aan). Opties > Session Log.
## - Export: Opties > Export Log (web = download, anders Downloads/Documenten).
##
## Samenvatten: python3 tools/sessielog/samenvat.py <bestand of map>.

const MAP := "user://logs"
const PREFIX := "sessie_"
const EXT := ".jsonl"
const FORMAAT := 1
const FLUSH_SECS := 10.0
const FLUSH_LINES := 48
const MAX_BESTANDEN := 5
const MAX_BYTES := 2 * 1024 * 1024
const RESERVE_BYTES := 4096
const RESERVE_TYPES := ["log_vol", "sessie_stop", "afgekapt"]
const STILSTAND_MIN := 20.0
const POS_SECS := 0.5
const IDLE_SECS := 5.0
const EXPORT_SESSIES := 3
const KLEMBORD_MAX := 30000
const GAT_MS := 3000
const ACTIES := ["interact", "cancel", "run", "kern"]
const RICHTING := {"move_up": "up", "move_down": "down", "move_left": "left", "move_right": "right"}
const SETTING := "sessie_log"
const DETAIL_NA_VOL := ["pos", "dir", "knop"]

var actief := false
var pad := ""
var map_pad := MAP
var export_map := ""
var sessie_id := ""
var volgt_instelling := true
var buffer := PackedStringArray()
var bytes := 0
var regels := 0
var schrijf_aantal := 0
var vol := false
var afgekapt := false

var _bestand: FileAccess
var _t0_ms := 0
var _volgende_flush_ms := 0
var _flush_in := 0.0
var _vorige_frame_ms := 0
var _scene_id := 0
var _scene_naam := ""
var _scene_sinds := 0.0
var _gevecht := {}
var _quests := {}
var _laatste_activiteit := 0.0
var _pauze_sinds := -1.0
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
var _examine := false
var _scherm := Vector2i.ZERO
var _speler: Node
var _art_nu := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(false)
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--") and (s.ends_with("test") or s.ends_with("sim") or s.ends_with("balans")):
			volgt_instelling = false
	Settings.changed.connect(_on_setting)
	GameState.battle_started.connect(_on_battle_started)
	GameState.battle_ended.connect(_on_battle_ended)
	GameState.game_over.connect(_on_game_over)
	GameState.game_saved.connect(_on_saved)
	GameState.game_loaded.connect(_on_loaded)
	GameState.menu_opened.connect(_on_menu)
	Story.event_finished.connect(_on_story_event)
	if volgt_instelling:
		pas_toe()


func pas_toe() -> void:
	var aan: bool = Settings.sessie_log_enabled()
	if aan and not actief:
		start()
	elif not aan and actief:
		stop()


func _on_setting(key: String) -> void:
	if key == SETTING and volgt_instelling:
		pas_toe()


# ---------------------------------------------------------------- start / stop
func start(map_pad_arg := "") -> bool:
	if map_pad_arg != "":
		map_pad = map_pad_arg
	if actief:
		stop()
	DirAccess.make_dir_recursive_absolute(map_pad)
	_opruimen()
	sessie_id = _nieuw_id()
	pad = _nieuw_pad()
	_bestand = FileAccess.open(pad, FileAccess.WRITE)
	if _bestand == null:
		push_warning("SessieLog: bestand openen mislukt (%s)" % pad)
		return false
	actief = true
	buffer = PackedStringArray()
	bytes = 0
	regels = 0
	schrijf_aantal = 0
	vol = false
	afgekapt = false
	_gevecht = {}
	_pauze_sinds = -1.0
	_t0_ms = Time.get_ticks_msec()
	_volgende_flush_ms = _t0_ms + int(FLUSH_SECS * 1000.0)
	_flush_in = FLUSH_SECS
	_laatste_activiteit = 0.0
	_laatste_tegel = Vector2i(-99999, -99999)
	_laatste_kaart = ""
	_kaart_sinds_ms = _t0_ms
	_dir = "none"
	_acties_aan = {}
	_dialoog = false
	_cutscene = false
	_examine = false
	_speler = null
	_art_nu = {}
	_pos_in = 0.0
	_idle_in = 0.0
	_vorige_frame_ms = 0
	_quests = _quest_stand()
	_volg_scene(false)
	var start_data := _sessie_info()
	start_data.merge(_sessie_start_extra())
	noteer("sessie_start", start_data)
	flush()
	_meld_scherm(true)
	if GameState != null and GameState.current_map != "":
		kaart(GameState.current_map)
	set_process(true)
	set_process_input(true)
	return true


func stop() -> void:
	if not actief:
		return
	flush()
	_sluit_kaart()
	_sluit_stilstand(_nu())
	var info := _sessie_info()
	info["duur"] = snappedf(_nu(), 0.1)
	noteer("sessie_stop", info)
	flush()
	if _bestand != null:
		_bestand.close()
	_bestand = null
	actief = false
	set_process(false)
	set_process_input(false)


func _exit_tree() -> void:
	stop()


func _notification(what: int) -> void:
	if not actief:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_sluit_stilstand(_nu())
			_pauze_sinds = _nu()
			noteer("pauze")
			noteer("app_pauze")
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			var secs := _nu() - _pauze_sinds if _pauze_sinds >= 0.0 else 0.0
			_pauze_sinds = -1.0
			_laatste_activiteit = _nu()
			noteer("app_hervat", {"pauze": snappedf(secs, 0.1)})
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			noteer("focus", {"aan": false})
			flush()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			noteer("focus", {"aan": true})
		NOTIFICATION_WM_CLOSE_REQUEST:
			stop()


func _sessie_info() -> Dictionary:
	return {
		"versie": str(ProjectSettings.get_setting("application/config/version", "")),
		"build": "debug" if OS.is_debug_build() else "release",
		"modus": _modus(),
		"os": OS.get_name(),
	}


func _sessie_start_extra() -> Dictionary:
	var now := Time.get_datetime_dict_from_system(true)
	return {
		"v": FORMAAT,
		"spel": str(ProjectSettings.get_setting("application/config/version", "")),
		"build_id": _build_id(),
		"motor": Engine.get_version_info().get("string", ""),
		"web": OS.has_feature("web"),
		"android": OS.has_feature("android"),
		"sessie": sessie_id,
		"utc": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now["year"], now["month"], now["day"], now["hour"], now["minute"], now["second"]],
		"unix": int(Time.get_unix_time_from_system()),
	}


func _build_id() -> String:
	if not FileAccess.file_exists("res://build.json"):
		return "dev"
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://build.json"))
	return str(d.get("commit", "dev")) if d is Dictionary else "dev"


func _nieuw_id() -> String:
	var crypto := Crypto.new()
	var b := crypto.generate_random_bytes(4)
	if b.size() == 4:
		return b.hex_encode()
	return "%08x" % (randi() & 0x7fffffff)


func _modus() -> String:
	var i := int(Settings.get_value("battle_style"))
	return str(Settings.BATTLE_STYLE_NAMES[clampi(i, 0, Settings.BATTLE_STYLE_NAMES.size() - 1)])


# ---------------------------------------------------------------- bestanden
func bestanden(map_pad_arg := "") -> Array[String]:
	var m := map_pad if map_pad_arg == "" else map_pad_arg
	var uit: Array[String] = []
	var d := DirAccess.open(m)
	if d == null:
		return uit
	for f in d.get_files():
		if f.begins_with(PREFIX) and f.ends_with(EXT):
			uit.append(m.path_join(f))
	uit.sort()
	return uit


func _opruimen() -> void:
	var lijst := bestanden()
	while lijst.size() > MAX_BESTANDEN - 1:
		DirAccess.remove_absolute(lijst[0])
		lijst.remove_at(0)


func _nieuw_pad() -> String:
	var n := Time.get_datetime_dict_from_system()
	var stam := "%s%04d-%02d-%02d_%02d%02d%02d" % [PREFIX, n["year"], n["month"], n["day"], n["hour"], n["minute"], n["second"]]
	var hoogste := 0
	for p in bestanden():
		var f: String = str(p).get_file()
		if f == stam + EXT:
			hoogste = maxi(hoogste, 1)
		elif f.begins_with(stam + "_"):
			hoogste = maxi(hoogste, f.trim_prefix(stam + "_").trim_suffix(EXT).to_int())
	if hoogste == 0:
		return map_pad.path_join(stam + EXT)
	return map_pad.path_join("%s_%02d%s" % [stam, hoogste + 1, EXT])


# ---------------------------------------------------------------- schrijven
func _nu() -> float:
	return (Time.get_ticks_msec() - _t0_ms) / 1000.0


func noteer(type: String, data: Dictionary = {}) -> void:
	if not actief:
		return
	if afgekapt and type in DETAIL_NA_VOL:
		return
	var regel := JSON.stringify({"t": snappedf(_nu(), 0.1), "type": type, "scene": _scene_nu(), "data": data}, "", false)
	var n := regel.to_utf8_buffer().size() + 1
	if not type in RESERVE_TYPES and bytes + n > MAX_BYTES - RESERVE_BYTES:
		if not vol:
			vol = true
			afgekapt = true
			noteer("log_vol", {"bytes": bytes})
		if type in DETAIL_NA_VOL:
			return
	if bytes + n > MAX_BYTES and not _zorg_ruimte(n):
		return
	buffer.append(regel)
	bytes += n
	regels += 1
	if buffer.size() >= FLUSH_LINES:
		flush()


## Verwijder oudste regels tot er minstens n bytes vrije ruimte is (bestand blijft geldige JSONL).
func _zorg_ruimte(n: int) -> bool:
	while bytes + n > MAX_BYTES:
		if not _verwijder_oudste_regel():
			return false
	return true


func _regel_bewaard(json_regel: String) -> bool:
	var parsed: Variant = JSON.parse_string(json_regel)
	if parsed is Dictionary:
		var t := str(parsed.get("type", ""))
		return t in RESERVE_TYPES or t == "sessie_start"
	return false


func _verwijder_oudste_regel() -> bool:
	if not buffer.is_empty():
		var bi := 0
		while bi < buffer.size() and _regel_bewaard(buffer[bi]):
			bi += 1
		if bi >= buffer.size():
			return false
		var oud := buffer[bi]
		buffer.remove_at(bi)
		bytes -= oud.to_utf8_buffer().size() + 1
		regels = maxi(0, regels - 1)
		return true
	flush()
	if pad == "" or not FileAccess.file_exists(pad):
		return false
	var tekst := FileAccess.get_file_as_string(pad)
	if tekst.is_empty():
		return false
	var lijnen := tekst.split("\n", false)
	if lijnen.is_empty():
		return false
	var idx := 0
	while idx < lijnen.size() and _regel_bewaard(lijnen[idx]):
		idx += 1
	if idx >= lijnen.size():
		return false
	var weg := lijnen[idx] + "\n"
	lijnen.remove_at(idx)
	var nieuw := ""
	if not lijnen.is_empty():
		nieuw = "\n".join(lijnen) + "\n"
	if _bestand != null:
		_bestand.close()
		_bestand = null
	var f := FileAccess.open(pad, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(nieuw)
	f.close()
	_bestand = FileAccess.open(pad, FileAccess.READ_WRITE)
	if _bestand != null:
		_bestand.seek_end()
	bytes -= weg.to_utf8_buffer().size()
	regels = maxi(0, regels - 1)
	return true


func flush() -> void:
	if buffer.is_empty() or _bestand == null:
		return
	_bestand.store_string("\n".join(buffer) + "\n")
	_bestand.flush()
	buffer = PackedStringArray()
	schrijf_aantal += 1


func _process(delta: float) -> void:
	var nu_ms := Time.get_ticks_msec()
	if _vorige_frame_ms > 0 and nu_ms - _vorige_frame_ms >= GAT_MS:
		noteer("gat", {"secs": snappedf((nu_ms - _vorige_frame_ms) / 1000.0, 0.1)})
	_vorige_frame_ms = nu_ms
	_volg_scene(true)
	_flush_in -= delta
	if Time.get_ticks_msec() >= _volgende_flush_ms:
		_volgende_flush_ms = Time.get_ticks_msec() + int(FLUSH_SECS * 1000.0)
		_check_quests()
		flush()
	elif _flush_in <= 0.0:
		_flush_in = FLUSH_SECS
		flush()
	if Input.is_anything_pressed():
		_activiteit()
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
	_activiteit()
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		_bron = "touch"
	elif event is InputEventKey:
		_bron = "toets"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_bron = "pad"


# ---------------------------------------------------------------- scène / kaart
func _scene_naam_van(n: Node) -> String:
	if n == null:
		return ""
	var p := str(n.scene_file_path)
	return str(n.name) if p == "" else p.get_file().get_basename()


func _scene_nu() -> String:
	return _scene_naam_van(get_tree().current_scene) if is_inside_tree() else ""


func _volg_scene(meld: bool) -> void:
	var s := get_tree().current_scene
	var id := s.get_instance_id() if s != null else 0
	if id == _scene_id:
		return
	var naam := _scene_naam_van(s)
	if meld:
		noteer("scene_wissel", {"van": _scene_naam, "naar": naam, "secs": snappedf(_nu() - _scene_sinds, 0.1)})
	_scene_id = id
	_scene_naam = naam
	_scene_sinds = _nu()


func _kaart_id(p := "") -> String:
	if p == "":
		p = GameState.current_map if GameState != null else ""
	return p.get_file().trim_suffix(".tscn")


func _stijl(p: String) -> String:
	return "som" if KaartStijl.is_som(p) else "oud"


func _art(p: String) -> Dictionary:
	var gebied := KaartStijl.gebied_van_map(p)
	var st := _stijl(p)
	var palet := ""
	if gebied != "":
		palet = str(KaartStijl.gebieden().get(gebied, {}).get("palet", ""))
	var ts := ""
	var scene := get_tree().current_scene
	if scene != null and str(scene.scene_file_path) == p:
		var g := scene.get_node_or_null("Ground") as TileMapLayer
		if g != null and g.tile_set != null:
			ts = g.tile_set.resource_path.trim_prefix("res://")
	if ts == "" and st == "som" and gebied != "":
		ts = KaartStijl.tileset_pad(gebied, "terrain").trim_prefix("res://")
	return {"stijl": st, "gebied": gebied, "palet": palet, "tileset": ts}


func _kaart_rect(p: String) -> Array:
	var scene := get_tree().current_scene
	if scene == null or str(scene.scene_file_path) != p:
		return []
	var g := scene.get_node_or_null("Ground") as TileMapLayer
	if g == null:
		return []
	var r := g.get_used_rect()
	return [r.position.x, r.position.y, r.size.x, r.size.y]


func kaart(p: String) -> void:
	if not actief:
		return
	_sluit_kaart()
	_laatste_kaart = p
	_kaart_sinds_ms = Time.get_ticks_msec()
	_laatste_tegel = Vector2i(-99999, -99999)
	_speler = null
	_art_nu = {}
	var w := Vector2i(DisplayServer.window_get_size())
	var vp := get_viewport()
	var v := Vector2i(vp.get_visible_rect().size) if vp != null else Vector2i.ZERO
	var info := {"kaart": _kaart_id(p), "hoe": GameState.entry_kind,
			"spawn": GameState.pending_spawn, "vp": [v.x, v.y], "venster": [w.x, w.y]}
	info.merge(_art(p))
	info.merge(_held_info())
	noteer("kaart", info)


func _held_info() -> Dictionary:
	var st := "action" if Settings.action_battles() else "classic"
	var sheet := KaartStijl.leider_sheet() if KaartStijl.held_nieuw_op(_laatste_kaart) else "res://assets/sprites/player.png"
	var leider := str(GameState.party[0].get("id", "")) if not GameState.party.is_empty() else ""
	return {"gevechtsstijl": st, "leider": leider, "held_sheet": sheet.get_file(),
			"held_frame": [24, 32] if KaartStijl.held_nieuw_op(_laatste_kaart) else [16, 24]}


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


func cutscene(id: String, start: bool) -> void:
	noteer("cutscene_start" if start else "cutscene_eind", {"id": id, "kaart": _kaart_id()} if start else {"id": id})


# ---------------------------------------------------------------- positie / scherm
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
	var kp: String = GameState.current_map
	if _art_nu.is_empty():
		_art_nu = _art(kp)
		var ki := {"kaart": _kaart_id(kp), "rect": _kaart_rect(kp)}
		ki.merge(_art_nu)
		noteer("kaart_info", ki)
	noteer("pos", {"kaart": _kaart_id(), "x": t.x, "y": t.y, "f": f,
			"stijl": _art_nu["stijl"], "tileset": _art_nu["tileset"]})


func _richting_naam(v: Vector2i) -> String:
	if v == Vector2i.UP:
		return "up"
	if v == Vector2i.LEFT:
		return "left"
	if v == Vector2i.RIGHT:
		return "right"
	return "down"


# ---------------------------------------------------------------- invoer / dialoog
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
			if wie != "" and wie == GameState.player_name:
				wie = "player"
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
			_examine = str(story.current_origin) == "examine"
			noteer("examine" if _examine else "cutscene_start", {"id": str(story.current_event), "kaart": _kaart_id()})
		else:
			noteer("examine_eind" if _examine else "cutscene_eind", {})
			_examine = false


func _activiteit() -> void:
	_sluit_stilstand(_nu())


func _sluit_stilstand(nu: float) -> void:
	var stil := nu - _laatste_activiteit
	if stil >= STILSTAND_MIN and _pauze_sinds < 0.0:
		noteer("stilstand", {"secs": snappedf(stil, 0.1), "vanaf": snappedf(_laatste_activiteit, 0.1)})
	_laatste_activiteit = nu


# ---------------------------------------------------------------- gevechten
func _party_stand() -> Array:
	var uit: Array = []
	for h in GameState.party:
		uit.append({"id": str(h.get("id", "")), "hp": int(h.get("hp", 0)), "mhp": int(h.get("max_hp", 0)),
				"mp": int(h.get("mp", 0)), "mmp": int(h.get("max_mp", 0)), "lv": int(h.get("level", 1))})
	return uit


func _party_hp_pct() -> int:
	var hp := 0
	var mhp := 0
	for h in GameState.party:
		hp += maxi(0, int(h.get("hp", 0)))
		mhp += maxi(0, int(h.get("max_hp", 0)))
	return roundi(100.0 * hp / mhp) if mhp > 0 else 0


func gevecht_start(vijanden: Array, baas: bool, terrein: String, tegel: Vector2i) -> void:
	if not actief:
		return
	var ids: Array = []
	for v in vijanden:
		ids.append(str(v))
	var hp_start := _party_hp_pct()
	_gevecht = {"t0": _nu(), "t0_ms": Time.get_ticks_msec(), "ronden": 0, "acties": {}, "party": _party_stand(),
			"kaart": _kaart_id(), "vijanden": ids, "baas": baas, "hp_start": hp_start}
	noteer("gevecht_start", {"kaart": _kaart_id(), "x": tegel.x, "y": tegel.y, "vijanden": ids, "baas": baas,
			"terrein": terrein, "party": _gevecht["party"], "modus": _modus(), "party_hp_pct": hp_start})


func _on_battle_started(enemies: Array, boss: bool) -> void:
	if not actief or not _gevecht.is_empty():
		return
	gevecht_start(enemies, boss, "", Vector2i.ZERO)


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
	var duur := snappedf(_nu() - float(_gevecht["t0"]), 0.1)
	var beurten := -1
	var s := get_tree().current_scene
	if s != null and "round_no" in s:
		beurten = int(s.get("round_no"))
	noteer("gevecht_eind", {"kaart": _gevecht["kaart"], "resultaat": resultaat, "ronden": _gevecht["ronden"],
			"secs": snappedf((Time.get_ticks_msec() - int(_gevecht["t0_ms"])) / 1000.0, 0.1),
			"hp_verlies": verlies, "acties": _gevecht["acties"], "party": eind})
	noteer("gevecht_einde", {"vijanden": _gevecht["vijanden"], "baas": _gevecht["baas"], "uitkomst": resultaat,
			"duur": duur, "beurten": beurten, "party_hp_pct_start": int(_gevecht.get("hp_start", 0)),
			"party_hp_pct": _party_hp_pct_from(eind)})
	_gevecht = {}
	flush()


func _party_hp_pct_from(stand: Array) -> int:
	var hp := 0
	var mhp := 0
	for h in stand:
		hp += maxi(0, int(h.get("hp", 0)))
		mhp += maxi(0, int(h.get("max_hp", 0)))
	return roundi(100.0 * hp / mhp) if mhp > 0 else 0


func _on_battle_ended(result: String) -> void:
	if not actief or _gevecht.is_empty():
		return
	gevecht_eind(result)


func actie_slag(held: String, raak: int) -> void:
	noteer("actie_slag", {"kaart": _kaart_id(), "held": held, "raak": raak})


func actie_treffer(held: String, schade: int, hp: int) -> void:
	noteer("actie_treffer", {"kaart": _kaart_id(), "held": held, "schade": schade, "hp": hp})


func dood(reden: String) -> void:
	noteer("dood", {"kaart": _kaart_id(), "reden": reden})
	flush()


func respawn(naar: String, soort: String) -> void:
	noteer("respawn", {"naar": _kaart_id(naar), "soort": soort})


func _on_game_over(map_path: String) -> void:
	if not actief:
		return
	noteer("game_over", {"plek": map_path.get_file().get_basename()})
	flush()


# ---------------------------------------------------------------- save / load / menu
func _on_saved(path: String, ok: bool) -> void:
	noteer("save", {"bestand": path.get_file(), "ok": ok})


func _on_loaded(path: String, ok: bool) -> void:
	if not actief:
		return
	noteer("load", {"bestand": path.get_file(), "ok": ok})
	if ok:
		_quests = _quest_stand()


func _on_menu(which: String) -> void:
	noteer("menu_open", {"welk": which})


# ---------------------------------------------------------------- quests
func _quest_stand() -> Dictionary:
	var uit := {}
	for q in GameState.quest_progress:
		var v = GameState.quest_progress[q]
		if v is Dictionary:
			var st = v.get("steps", [])
			uit[str(q)] = {"stappen": st.size() if st is Array else 0, "klaar": bool(v.get("done", false))}
	return uit


func _on_story_event(_event_id: String) -> void:
	if actief:
		_check_quests.call_deferred()


func _check_quests() -> void:
	if not actief:
		return
	var nu := _quest_stand()
	for q in nu:
		var oud: Dictionary = _quests.get(q, {"stappen": 0, "klaar": false})
		if int(nu[q]["stappen"]) > int(oud["stappen"]) or (bool(nu[q]["klaar"]) and not bool(oud["klaar"])):
			noteer("quest_update", {"quest": q, "stappen": nu[q]["stappen"], "klaar": nu[q]["klaar"]})
	_quests = nu


# ---------------------------------------------------------------- export
func export_tekst(max_sessies := EXPORT_SESSIES) -> String:
	flush()
	var lijst := bestanden(pad.get_base_dir() if pad != "" else map_pad)
	var uit := ""
	var vanaf := maxi(0, lijst.size() - max_sessies)
	for i in range(vanaf, lijst.size()):
		uit += FileAccess.get_file_as_string(lijst[i])
	return uit


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
	var eigen := ProjectSettings.globalize_path(pad if pad != "" else map_pad)
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
