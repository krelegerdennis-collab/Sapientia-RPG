extends Node
## Autoload "SessieLog": lokale, offline sessielog voor playtests (JSON Lines). Geen netwerk,
## geen persoonsgegevens (geen spelernaam, geen apparaat-id, geen locatie, alleen bestandsnamen van saves).
##
## - Eén bestand per sessie: user://logs/sessie_<datum>_<tijd>.jsonl (zelfde seconde: _02, _03, ...).
##   Elke regel: {"t": seconden sinds de start, "type": soort, "scene": huidige scène, "data": {...}}.
## - Gebufferd in het geheugen; naar schijf elke FLUSH_SECS, bij app-pauze, focus kwijt en afsluiten.
## - Max MAX_BESTANDEN bestanden (oudste weg bij een nieuwe sessie), max MAX_BYTES per bestand
##   (daarna één "log_vol"-regel; "sessie_stop" past altijd nog in de reserve).
## - Aan/uit: Settings "sessie_log" (-1 = automatisch: aan in debug-builds, uit in release; 0 uit; 1 aan).
##   In testsuites (--...test) en simulaties (--...sim, --...balans) staat hij uit tot een test hem zelf start.
##
## Gebeurtenissen: sessie_start, sessie_stop, scene_wissel, gevecht_start, gevecht_einde, game_over,
## save, load, quest_update, menu_open, app_pauze, app_hervat, stilstand (geen invoer >= STILSTAND_MIN), log_vol.
## Bronnen: signals van GameState (battle_started/battle_ended/game_over/game_saved/game_loaded/menu_opened),
## Story.event_finished (quests), Settings.changed; de scènewissel wordt per frame vergeleken (geen signal in 4.3).
## Let op: Action-gevechten (scripts/som/) lopen niet via GameState.start_battle; alleen hun game-over komt erin.
## Samenvatten: python3 tools/sessielog/samenvat.py <bestand of map>.

const MAP := "user://logs"
const PREFIX := "sessie_"
const EXT := ".jsonl"
const FLUSH_SECS := 10.0
const MAX_BESTANDEN := 5
const MAX_BYTES := 2 * 1024 * 1024
## Ruimte die na "log_vol" overblijft voor de slotregels.
const RESERVE_BYTES := 4096
const RESERVE_TYPES := ["log_vol", "sessie_stop"]
## Zo lang (s) zonder invoer telt als stilstand.
const STILSTAND_MIN := 20.0
const SETTING := "sessie_log"

var actief := false
var pad := ""
## Map voor de logbestanden (tests gebruiken een eigen map).
var map_pad := MAP
## false = start/stop niet automatisch met de instelling (testsuites).
var volgt_instelling := true
var buffer := PackedStringArray()
var bytes := 0
var schrijf_aantal := 0
var vol := false

var _bestand: FileAccess
var _t0_ms := 0
var _volgende_flush_ms := 0
var _scene_id := 0
var _scene_naam := ""
var _scene_sinds := 0.0
var _gevecht := {}
var _quests := {}
var _laatste_activiteit := 0.0
var _pauze_sinds := -1.0


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


## Start of stop volgens de instelling.
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
func start() -> bool:
	if actief:
		return true
	DirAccess.make_dir_recursive_absolute(map_pad)
	_opruimen()
	pad = _nieuw_pad()
	_bestand = FileAccess.open(pad, FileAccess.WRITE)
	if _bestand == null:
		push_warning("SessieLog: bestand openen mislukt (%s)" % pad)
		return false
	actief = true
	buffer = PackedStringArray()
	bytes = 0
	schrijf_aantal = 0
	vol = false
	_gevecht = {}
	_pauze_sinds = -1.0
	_t0_ms = Time.get_ticks_msec()
	_volgende_flush_ms = _t0_ms + int(FLUSH_SECS * 1000.0)
	_laatste_activiteit = 0.0
	_quests = _quest_stand()
	_volg_scene(false)
	noteer("sessie_start", _sessie_info())
	flush()
	set_process(true)
	set_process_input(true)
	return true


func stop() -> void:
	if not actief:
		return
	_sluit_stilstand(_nu())
	var info := _sessie_info()
	info["duur"] = snappedf(_nu(), 0.1)
	noteer("sessie_stop", info)
	flush()
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
			noteer("app_pauze")
			flush()
		NOTIFICATION_APPLICATION_RESUMED:
			var secs := _nu() - _pauze_sinds if _pauze_sinds >= 0.0 else 0.0
			_pauze_sinds = -1.0
			_laatste_activiteit = _nu()
			noteer("app_hervat", {"pauze": snappedf(secs, 0.1)})
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			flush()
		NOTIFICATION_WM_CLOSE_REQUEST:
			stop()


func _sessie_info() -> Dictionary:
	return {
		"versie": str(ProjectSettings.get_setting("application/config/version", "")),
		"build": "debug" if OS.is_debug_build() else "release",
		"modus": _modus(),
		"os": OS.get_name(),
	}


func _modus() -> String:
	var i := int(Settings.get_value("battle_style"))
	return str(Settings.BATTLE_STYLE_NAMES[clampi(i, 0, Settings.BATTLE_STYLE_NAMES.size() - 1)])


# ---------------------------------------------------------------- bestanden
## Logbestanden in map_pad, oudste eerst (de naam is datum + tijd + volgnummer).
func bestanden() -> Array[String]:
	var uit: Array[String] = []
	var d := DirAccess.open(map_pad)
	if d == null:
		return uit
	for f in d.get_files():
		if f.begins_with(PREFIX) and f.ends_with(EXT):
			uit.append(map_pad.path_join(f))
	uit.sort()
	return uit


## Houdt MAX_BESTANDEN - 1 over; de nieuwe sessie komt erbij.
func _opruimen() -> void:
	var lijst := bestanden()
	while lijst.size() > MAX_BESTANDEN - 1:
		DirAccess.remove_absolute(lijst[0])
		lijst.remove_at(0)


## sessie_<jjjj-mm-dd>_<uummss>.jsonl; bestaat die stam al, dan een volgnummer hoger dan het hoogste.
func _nieuw_pad() -> String:
	var n := Time.get_datetime_dict_from_system()
	var stam := "%s%04d-%02d-%02d_%02d%02d%02d" % [PREFIX, n["year"], n["month"], n["day"], n["hour"], n["minute"], n["second"]]
	var hoogste := 0
	for p in bestanden():
		var f := p.get_file()
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


## Eén regel in de buffer (geen schijf-IO). Uit = niets.
func noteer(type: String, data: Dictionary = {}) -> void:
	if not actief:
		return
	var regel := JSON.stringify({"t": snappedf(_nu(), 0.1), "type": type, "scene": _scene_nu(), "data": data}, "", false)
	var n := regel.to_utf8_buffer().size() + 1
	if not type in RESERVE_TYPES and bytes + n > MAX_BYTES - RESERVE_BYTES:
		if not vol:
			vol = true
			noteer("log_vol", {"bytes": bytes})
		return
	if bytes + n > MAX_BYTES:
		return
	buffer.append(regel)
	bytes += n


func flush() -> void:
	if buffer.is_empty() or _bestand == null:
		return
	_bestand.store_string("\n".join(buffer) + "\n")
	_bestand.flush()
	buffer = PackedStringArray()
	schrijf_aantal += 1


func _process(_delta: float) -> void:
	_volg_scene(true)
	if Input.is_anything_pressed():
		_activiteit()
	if Time.get_ticks_msec() >= _volgende_flush_ms:
		_volgende_flush_ms = Time.get_ticks_msec() + int(FLUSH_SECS * 1000.0)
		_check_quests()
		flush()


func _input(_event: InputEvent) -> void:
	_activiteit()


# ---------------------------------------------------------------- scène
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


# ---------------------------------------------------------------- stilstand
func _activiteit() -> void:
	_sluit_stilstand(_nu())


## Was het sinds de laatste invoer lang stil, dan één "stilstand"-regel; de klok begint opnieuw.
func _sluit_stilstand(nu: float) -> void:
	var stil := nu - _laatste_activiteit
	if stil >= STILSTAND_MIN and _pauze_sinds < 0.0:
		noteer("stilstand", {"secs": snappedf(stil, 0.1), "vanaf": snappedf(_laatste_activiteit, 0.1)})
	_laatste_activiteit = nu


# ---------------------------------------------------------------- gevechten
## Gezamenlijke HP van de party in procenten (0..100).
func _party_hp_pct() -> int:
	var hp := 0
	var mhp := 0
	for h in GameState.party:
		hp += maxi(0, int(h.get("hp", 0)))
		mhp += maxi(0, int(h.get("max_hp", 0)))
	return roundi(100.0 * hp / mhp) if mhp > 0 else 0


func _on_battle_started(enemies: Array, boss: bool) -> void:
	if not actief:
		return
	var ids: Array = []
	for e in enemies:
		ids.append(str(e))
	_gevecht = {"t0": _nu(), "vijanden": ids, "baas": boss, "hp": _party_hp_pct()}
	noteer("gevecht_start", {"vijanden": ids, "baas": boss, "modus": _modus(), "party_hp_pct": _gevecht["hp"]})


func _on_battle_ended(result: String) -> void:
	if not actief or _gevecht.is_empty():
		return
	var beurten := -1
	var s := get_tree().current_scene
	if s != null and "round_no" in s:
		beurten = int(s.get("round_no"))
	noteer("gevecht_einde", {"vijanden": _gevecht["vijanden"], "baas": _gevecht["baas"], "uitkomst": result,
			"duur": snappedf(_nu() - float(_gevecht["t0"]), 0.1), "beurten": beurten,
			"party_hp_pct_start": _gevecht["hp"], "party_hp_pct": _party_hp_pct()})
	_gevecht = {}


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
		_quests = _quest_stand()      # nieuwe voortgang uit de save is geen quest-update


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
		_check_quests.call_deferred()      # na GameState.quest_event (die is later gekoppeld)


## Meldt opdrachten met meer stappen of die net klaar zijn (een nieuw spel telt niet).
func _check_quests() -> void:
	if not actief:
		return
	var nu := _quest_stand()
	for q in nu:
		var oud: Dictionary = _quests.get(q, {"stappen": 0, "klaar": false})
		if int(nu[q]["stappen"]) > int(oud["stappen"]) or (bool(nu[q]["klaar"]) and not bool(oud["klaar"])):
			noteer("quest_update", {"quest": q, "stappen": nu[q]["stappen"], "klaar": nu[q]["klaar"]})
	_quests = nu
