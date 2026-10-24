extends Node
## Autoload "Settings" (v0.11 veldmenu): spelerinstellingen, LOS van de save.
## Staat in user://settings.cfg (ConfigFile), wordt bij de start geladen en na elke
## wijziging meteen weggeschreven. De autotests gebruiken een eigen bestand.
##
## Wat er met een instelling gebeurt (apply_all / _apply):
##   music_volume / sfx_volume  -> volume van de audiobussen "Music" en "SFX" (worden hier
##                                 aangemaakt als ze nog niet bestaan; zet later bij een
##                                 AudioStreamPlayer gewoon bus = "Music" of "SFX")
##   text_speed                 -> Dialog.chars_per_second (typemachine van het tekstvak)
##   battle_speed               -> tempo van de berichten/wachttijden in gevechten (battle.gd _wait)
##   touch_opacity / touch_size -> doorzichtigheid en grootte van de joystick, A/B en de knoppenrij (touch_controls.gd)
##   crt                        -> scanline-filter aan/uit (autoload Crt)
##   screen_shake               -> schudden bij treffers in gevechten (battle.gd _shake)
##   autosave                   -> automatisch opslaan (GameState.autosave)
##   battle_style               -> SoM-proef: 0 Classic (turn-based) / 1 Action (realtime, scripts/som/)
##   sessie_log                 -> autoload SessieLog (scripts/core/sessie_log.gd) luistert zelf naar 'changed'
## Andere scripts kunnen luisteren naar het signaal 'changed(key)'.

signal changed(key: String)

const GameData := preload("res://scripts/data/game_data.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const DEFAULT_PATH := "user://settings.cfg"
const TEST_PATH := "user://autotest_settings.cfg"
const SECTION := "instellingen"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
## Volume: 0 (uit) .. VOLUME_STEPS (vol).
const VOLUME_STEPS := 10
## Tekstsnelheid: index -> letters per seconde. 3 = 'Direct' (hele regel in één keer).
const TEXT_SPEED_CPS := [20.0, 40.0, 80.0, 100000.0]
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast", "Instant"]
## Gevechtstempo: index -> vermenigvuldiger voor wachttijden in het gevecht.
const BATTLE_SPEED_FACTOR := [0.7, 1.0, 1.6]
const BATTLE_SPEED_NAMES := ["Slow", "Normal", "Fast"]
## Touch-knoppen: zichtbaarheid in procenten (stappen van OPACITY_STEP).
const OPACITY_MIN := 30
const OPACITY_MAX := 100
const OPACITY_STEP := 10
## Touch-knoppen: grootte (index -> schaal van de joystick/A/B-straal).
const TOUCH_SIZE_SCALE := [0.85, 1.0, 1.15]
const TOUCH_SIZE_NAMES := ["Small", "Normal", "Large"]
## SoM-proef: gevechtsstijl. Bazen blijven in beide stijlen turn-based (scripts/data/som_data.gd).
const BATTLE_STYLE_NAMES := ["Classic", "Action"]
const BATTLE_STYLE_ACTION := 1
const BATTLE_STYLE_CLASSIC := 0

## Standaardwaarden (ook = 'nieuw bestand'). Volgorde = volgorde in het optiemenu.
const DEFAULTS := {
	"music_volume": 8,
	"sfx_volume": 8,
	"audio_mute": false,
	"text_speed": 1,
	"battle_speed": 1,
	"touch_opacity": 100,
	"touch_size": 1,
	"crt": true,
	"screen_shake": true,
	"autosave": true,
	"sessie_log": -1,    # SessieLog: -1 = aan in debug-builds, uit in release; 0 uit; 1 aan
	"run": false,      # TODO.md "run feature": RUN-toggle (blijft aan tot de speler hem uitzet)
	"battle_style": 1,   # 0 = Classic (turn-based), 1 = Action (realtime in de WM1-dungeons). Dennis 21 okt 2026: Action is de standaard
}

var path := DEFAULT_PATH
var values := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--menutest" in args:
		path = TEST_PATH
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_ensure_buses()
	load_settings()
	# Testsuites (--autotest, --woudtest, ...) beginnen zoals altijd in Classic; wie Action test, zet het zelf.
	# (Een vers spel begint in Action: DEFAULTS, zie som_rooms_tests.gd.)
	if Array(args).any(func(a): return str(a).begins_with("--") and str(a).ends_with("test")):
		values["battle_style"] = BATTLE_STYLE_CLASSIC
	# Dialog en Crt zijn eerder geladen autoloads; voor de zekerheid pas na _ready toepassen.
	apply_all.call_deferred()


## Bussen "Music" en "SFX" aanmaken (onder Master) als ze nog niet bestaan. Onschuldig als
## er (nog) geen geluid is.
func _ensure_buses() -> void:
	for bus in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


# ---------------------------------------------------------------- lezen / schrijven
func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	# Bestaand instellingenbestand zonder battle_style (van voor Action-als-standaard): houdt Classic.
	values["battle_style"] = BATTLE_STYLE_CLASSIC
	for key in DEFAULTS:
		if cfg.has_section_key(SECTION, key):
			values[key] = _sanitize(key, cfg.get_value(SECTION, key))
	# Oude sleutel sessielog (bool) -> sessie_log (1/0); sessie_log in het bestand wint.
	if cfg.has_section_key(SECTION, "sessielog") and not cfg.has_section_key(SECTION, "sessie_log"):
		values["sessie_log"] = 1 if bool(cfg.get_value(SECTION, "sessielog")) else 0


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value(SECTION, key, values[key])
	var err := cfg.save(path)
	if err != OK:
		push_warning("Instellingen opslaan mislukt: %s" % error_string(err))
	return err == OK


## Waarde in het geldige bereik (ook voor een met de hand aangepast/kapot bestand).
func _sanitize(key: String, v):
	var def = DEFAULTS[key]
	if def is bool:
		return _to_bool(v, def)
	var n := int(v) if (v is int or v is float or v is bool) else int(def)
	match key:
		"music_volume", "sfx_volume":
			return clampi(n, 0, VOLUME_STEPS)
		"audio_mute":
			return _to_bool(v, false)
		"text_speed":
			return clampi(n, 0, TEXT_SPEED_CPS.size() - 1)
		"battle_speed":
			return clampi(n, 0, BATTLE_SPEED_FACTOR.size() - 1)
		"touch_opacity":
			return clampi(snappedi(n, OPACITY_STEP), OPACITY_MIN, OPACITY_MAX)
		"touch_size":
			return clampi(n, 0, TOUCH_SIZE_SCALE.size() - 1)
		"battle_style":
			return clampi(n, 0, BATTLE_STYLE_NAMES.size() - 1)
		"sessie_log":
			return clampi(n, -1, 1)
	return n


## Een bool uit een bestand dat met de hand is aangepast of kapot is: bool("ja") is in GDScript een fout en
## liet het laden halverwege stoppen (latere instellingen vielen terug op de standaard).
static func _to_bool(v, fallback: bool) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		var t := (v as String).strip_edges().to_lower()
		if t in ["true", "1", "yes", "on", "aan", "ja"]:
			return true
		if t in ["false", "0", "no", "off", "uit", "nee"]:
			return false
	return fallback


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


## Zet een waarde, past hem toe, schrijft het bestand en meldt 'changed'.
func set_value(key: String, v) -> void:
	if not DEFAULTS.has(key):
		push_warning("Onbekende instelling: %s" % key)
		return
	var clean = _sanitize(key, v)
	if values.get(key) == clean:
		return
	values[key] = clean
	_apply(key)
	save_settings()
	changed.emit(key)


## Eén stap naar links (-1) of rechts (+1); aan/uit-instellingen wisselen gewoon.
func step(key: String, dir: int) -> void:
	var v = get_value(key)
	if v is bool:
		set_value(key, not v)
	elif key == "touch_opacity":
		set_value(key, int(v) + dir * OPACITY_STEP)
	elif key == "sessie_log":
		set_value(key, int(v) + dir)
	else:
		set_value(key, int(v) + dir)


## Alles terug naar de standaardwaarden.
func reset_to_defaults() -> void:
	for key in DEFAULTS:
		set_value(key, DEFAULTS[key])


# ---------------------------------------------------------------- afgeleide waarden
func text_cps() -> float:
	return TEXT_SPEED_CPS[int(get_value("text_speed"))]


func battle_speed() -> float:
	return BATTLE_SPEED_FACTOR[int(get_value("battle_speed"))]


func touch_scale() -> float:
	return TOUCH_SIZE_SCALE[int(get_value("touch_size"))]


func touch_alpha() -> float:
	return int(get_value("touch_opacity")) / 100.0


## SoM-proef: staat de gevechtsstijl op Action (realtime)?
func action_battles() -> bool:
	return int(get_value("battle_style")) == BATTLE_STYLE_ACTION


func shake_enabled() -> bool:
	return bool(get_value("screen_shake"))


func autosave_enabled() -> bool:
	return bool(get_value("autosave"))


## Sessielog (SessieLog): -1 volgt de build (debug aan, release uit). Release-builds loggen nooit,
## ook niet met de instelling op 1 (playtest-kit: alleen debug).
func sessie_log_enabled() -> bool:
	if not ReleaseFlags.is_debug_build():
		return false
	var v := int(get_value("sessie_log"))
	return true if v < 0 else v == 1


## Hoogste busvolume (lineair) bij de schuif op 100%. Het spel was veel te luid: wat vroeger
## 10% was (lineair 0.1, ca. -20 dB) is nu het maximum; de hele schaal schaalt mee.
## Opgeslagen stappen (0..VOLUME_STEPS) blijven geldig en klinken nu zachter.
const VOLUME_MAX_LINEAR := 0.1

## Volume 0..VOLUME_STEPS -> decibel voor de bus (0 = gedempt).
static func volume_db(steps: int) -> float:
	var lin := clampf(float(steps) / VOLUME_STEPS, 0.0, 1.0) * VOLUME_MAX_LINEAR
	return linear_to_db(maxf(lin, 0.00001))


# ---------------------------------------------------------------- toepassen
func apply_all() -> void:
	for key in DEFAULTS:
		_apply(key)


func _apply(key: String) -> void:
	match key:
		"music_volume":
			_apply_bus(BUS_MUSIC, int(get_value(key)))
		"sfx_volume":
			_apply_bus(BUS_SFX, int(get_value(key)))
		"audio_mute":
			_apply_bus(BUS_MUSIC, int(get_value("music_volume")))
			_apply_bus(BUS_SFX, int(get_value("sfx_volume")))
		"text_speed":
			var dialog := get_node_or_null("/root/Dialog")
			if dialog and "chars_per_second" in dialog:
				dialog.chars_per_second = text_cps()
		"crt":
			var crt := get_node_or_null("/root/Crt")
			# het filter kan in game_data.gd (CRT "enabled") helemaal uit staan: dan blijft het uit
			if crt and crt.has_method("set_enabled"):
				crt.set_enabled(bool(get_value(key)) and bool(GameData.CRT.get("enabled", true)))
		# touch_opacity / touch_size: touch_controls.gd luistert zelf naar 'changed'
		# battle_speed / screen_shake / autosave: worden opgevraagd wanneer ze nodig zijn


func _apply_bus(bus: String, steps: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, volume_db(steps))
	AudioServer.set_bus_mute(i, steps <= 0 or bool(get_value("audio_mute")))
