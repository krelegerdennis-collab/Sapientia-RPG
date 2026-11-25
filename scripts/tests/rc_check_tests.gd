extends Node
## RC-checklist WM1 (--rcchecktest): de automatisch toetsbare punten uit
## docs/release/WM1_RELEASE_CHECKLIST.md, voor de interne RC (F8). Rapport: docs/release/RC_AUDIT_WM1.md.
## Start: godot --path . -- --rcchecktest [--shots=/pad/map]
##
## Alleen lezen: projectinstellingen, export_presets.cfg, versiebron, releasevlaggen en een paar bronbestanden.
## Er wordt niets geschreven of gebouwd. Vlaggen die de suite tijdelijk omzet, gaan aan het eind terug.
##
## Twee soorten regels:
##   PASS/FAIL    harde eis voor de RC; een FAIL maakt de suite rood.
##   OPEN         een bekend OPEN-punt uit RC_AUDIT_WM1.md (id tussen haken). Telt niet als FAIL, zodat de
##                suite groen kan blijven terwijl de bevinding in de uitvoer staat. Is het punt opgelost, dan
##                wordt het een PASS met de opmerking dat het rapport bijgewerkt moet worden.

const Flags := preload("res://scripts/data/release_flags.gd")
const SettingsScript := preload("res://scripts/settings.gd")
const Videos := preload("res://scripts/data/cutscene_videos.gd")
const PerfectDodge := preload("res://scripts/data/som_perfect_dodge_data.gd")
const Ambience := preload("res://world_warper/audio/ambience.gd")

const VERSION_SRC := "res://tools/release/version.json"
const PRESETS := "res://export_presets.cfg"
## Laatst uitgebrachte build: tag v0.20 = version/code 22. De RC moet hoger zijn (checklist F8.2).
const LAATSTE_CODE := 22
## Besluit Dennis 15 nov 2026 (Job 11): RC-versie en netwerkrechten (F8.1, F8.2, F8.8).
const RC_VERSIE := "0.21"
const RC_CODE := 23
## Deze Android-rechten moeten in elke Android-preset UIT staan zolang online dicht is (H11).
const RC_NET_RECHTEN: Array[String] = ["permissions/internet", "permissions/access_network_state",
		"permissions/access_wifi_state", "permissions/change_wifi_multicast_state",
		"permissions/change_wifi_state", "permissions/change_network_state"]
## Moet in de exclude_filter van elke preset staan (checklist F3.15).
const EXCLUDE_EIS: Array[String] = ["tools/*", "docs/*", "scripts/tests/*", "scripts/debug_autotest.gd",
		"scripts/debug_menutest.gd", "wacht/*", "export/*", "pvp/tests/*", "world_warper/tests/*"]
## Moet in .gitignore staan (checklist F3.16 / F8.11).
const GITIGNORE_EIS: Array[String] = ["*.apk", "*.aab", "*.keystore", "*.jks", ".env", "*.uid"]
const SCENES_EIS: Array[String] = ["res://scenes/ui/title.tscn", "res://scenes/maps/wereldkaart.tscn",
		"res://world_warper/maps/hal.tscn", "res://world_warper/kamers/hal.tscn"]
## ENABLED-vlaggen die bewust aan staan omdat de feature in WM1 meegaat (bestand:CONST).
## Elke andere *ENABLED-constante die true is, is een onafgemaakte feature die aan staat: FAIL.
const ENABLED_TOEGESTAAN := {
	"scripts/data/som_data.gd:ENABLED": "Action-modus (SoM), shipt in WM1 (CHANGELOG Unreleased)",
	"scripts/data/som_feel_data.gd:ENABLED": "F4 game feel (#404, #444)",
	"scripts/data/som_gamefeel_data.gd:DEATH_GLITCH_ENABLED": "Game-feel fase 2 glitch-dood (#482), gaat mee in WM1 (akkoord Dennis 15-11)",
	"scripts/data/som_signature_data.gd:ENABLED": "F3 heldtechnieken (#578), gaan mee in WM1 (akkoord Dennis 25-11)",
	"scripts/data/release_flags.gd:ARENA_ENABLED": "Colosseum live (akkoord Dennis 25-11)",
}
const SCAN_MAPPEN: Array[String] = ["scripts", "world_warper", "pvp"]

var failures := 0
var passes := 0
var opens := 0
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


## Bekend OPEN-punt: geen FAIL, wel zichtbaar. Opgelost = PASS met een seintje voor het rapport.
func open_punt(id: String, label: String, nog_open: bool, melding: String) -> void:
	if nog_open:
		print("OPEN  [%s] %s: %s" % [id, label, melding])
		opens += 1
	else:
		check("[%s] %s (OPEN-punt lijkt opgelost: werk RC_AUDIT_WM1.md bij)" % [id, label], true)


func _run() -> void:
	var presets := ConfigFile.new()
	var err := presets.load(PRESETS)
	check("export_presets.cfg leesbaar (err %d)" % err, err == OK)
	var android := _android_secties(presets)
	check("Android-presets gevonden (%d)" % android.size(), android.size() >= 1)
	_versie(presets, android)
	_export(presets, android)
	_project()
	_releasevlaggen()
	_debugtoetsen()
	_test_dispatch()
	_enabled_vlaggen()
	_bekende_open_punten(presets, android)
	_rc_besluit(presets, android)
	print("RCCHECKTEST %d PASS, %d FAIL, %d OPEN" % [passes, failures, opens])
	print("RESULT %s (%d goed, %d fouten, %d bekende OPEN-punten)" % ["OK" if failures == 0 else "FOUT", passes, failures, opens])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


## [preset.N]-secties met platform Android.
func _android_secties(cfg: ConfigFile) -> Array[String]:
	var uit: Array[String] = []
	for s in cfg.get_sections():
		if s.begins_with("preset.") and not s.ends_with(".options") and str(cfg.get_value(s, "platform", "")) == "Android":
			uit.append(s)
	return uit


# ---------------------------------------------------------------- versie (F8.1)
func _versie(cfg: ConfigFile, android: Array[String]) -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_SRC))
	check("versiebron %s is een object" % VERSION_SRC, src is Dictionary)
	if not (src is Dictionary):
		return
	var naam := str(src.get("version_name", ""))
	var code := int(src.get("version_code", -1))
	check("project.godot config/version == versiebron (%s)" % naam,
			str(ProjectSettings.get_setting("application/config/version", "")) == naam)
	for s in android:
		var o := s + ".options"
		var pn := str(cfg.get_value(s, "name", s))
		check("preset '%s' version/name == %s" % [pn, naam], str(cfg.get_value(o, "version/name", "")) == naam)
		check("preset '%s' version/code == %d" % [pn, code], int(cfg.get_value(o, "version/code", -1)) == code)


# ---------------------------------------------------------------- export en hygiëne (F3.15, F3.16, F8.11)
func _export(cfg: ConfigFile, android: Array[String]) -> void:
	var pakket := ""
	for s in cfg.get_sections():
		if not s.begins_with("preset.") or s.ends_with(".options"):
			continue
		var pn := str(cfg.get_value(s, "name", s))
		var filt := str(cfg.get_value(s, "exclude_filter", "")).split(",")
		var delen: Array[String] = []
		for f in filt:
			delen.append(f.strip_edges())
		var mist: Array[String] = []
		for eis in EXCLUDE_EIS:
			if not delen.has(eis):
				mist.append(eis)
		check("preset '%s' sluit tests, tools, docs en wacht uit (mist: %s)" % [pn, mist], mist.is_empty())
	for s in android:
		var o := s + ".options"
		var pn := str(cfg.get_value(s, "name", s))
		var gevuld: Array[String] = []
		for k in cfg.get_section_keys(o):
			if k.begins_with("keystore/") and str(cfg.get_value(o, k, "")) != "":
				gevuld.append(k)
		check("preset '%s' heeft geen signing-velden ingevuld (%s)" % [pn, gevuld], gevuld.is_empty())
		check("preset '%s' bouwt arm64-v8a" % pn, bool(cfg.get_value(o, "architectures/arm64-v8a", false)))
		var p := str(cfg.get_value(o, "package/unique_name", ""))
		if pakket == "":
			pakket = p
		check("preset '%s' pakketnaam gelijk aan de andere presets (%s)" % [pn, p], p != "" and p == pakket)
	check("wacht/.gdignore bestaat (wacht/ niet in import of export)", FileAccess.file_exists("res://wacht/.gdignore"))
	var gi := FileAccess.get_file_as_string("res://.gitignore").split("\n")
	var regels: Array[String] = []
	for r in gi:
		regels.append(r.strip_edges())
	for eis in GITIGNORE_EIS:
		check(".gitignore bevat %s" % eis, regels.has(eis))


# ---------------------------------------------------------------- project (basis RC)
func _project() -> void:
	check("hoofdscène bestaat", ResourceLoader.exists(str(ProjectSettings.get_setting("application/run/main_scene", ""))))
	check("features bevatten 4.3", (ProjectSettings.get_setting("application/config/features", PackedStringArray()) as PackedStringArray).has("4.3"))
	check("viewport 384x216", int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 384
			and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 216)
	check("mobiel op gl_compatibility",
			str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")) == "gl_compatibility")
	check("run/max_fps = 60", int(ProjectSettings.get_setting("application/run/max_fps", 0)) == 60)
	check("oriëntatie liggend met sensor (4)", int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 4)
	for p in ProjectSettings.get_property_list():
		var key := str(p["name"])
		if key.begins_with("autoload/"):
			var pad := str(ProjectSettings.get_setting(key, "")).trim_prefix("*")
			check("autoload %s bestaat (%s)" % [key.get_slice("/", 1), pad], ResourceLoader.exists(pad))
	for sc in SCENES_EIS:
		check("verplichte scène %s bestaat" % sc, ResourceLoader.exists(sc))
	for id in Videos.ids():
		var vp := str(Videos.spec(str(id)).get("path", ""))
		check("filmpje %s heeft een bestand (%s)" % [id, vp.get_file()], vp != "" and FileAccess.file_exists(vp))


# ---------------------------------------------------------------- releasevlaggen (F3.14, H1/H2/H3/H11)
func _releasevlaggen() -> void:
	check("hub_cut staat aan (H2/H3)", Flags.hub_cut)
	if Flags.online_cut:
		check("online_cut staat aan (H11)", true)
	else:
		check("co-op release: online_cut uit", not Flags.online_cut)
	check("geen debug_build_override", Flags.debug_build_override == -1)
	check("geen relay_url_override", Flags.relay_url_override == null)
	check("geen test_menu_override", Flags.test_menu_override == -1)
	check("relay-URL in project.godot leeg", str(ProjectSettings.get_setting(Flags.RELAY_SETTING, "")).strip_edges() == "")
	check("release: Beta Test/End State/SoM verborgen", not Flags.test_menu_from(-1, false, PackedStringArray(), false))
	check("release: --testmenu werkt niet", not Flags.test_menu_from(-1, false, PackedStringArray(["--testmenu"]), false))
	check("sessielog standaard -1 (aan in debug, uit in release)", int(SettingsScript.DEFAULTS.get("sessie_log", 99)) == -1)
	Flags.debug_build_override = 0
	for sc in Flags.DEV_SCENES:
		check("release: dev-kamer %s geblokkeerd (H1)" % sc.get_file(), Flags.dev_scene_blocked(sc))
	check("release: F4 naar dev-kamer uit", not Flags.dev_rooms_allowed())
	check("release: sessielog schrijft niet", not SessieLog.debug_build())
	Flags.debug_build_override = -1


## F3/F4/F5-debugtoetsen in map.gd alleen achter een debug-check (F3.14).
func _debugtoetsen() -> void:
	var tekst := FileAccess.get_file_as_string("res://scripts/map.gd")
	var n := 0
	for regel in tekst.split("\n"):
		if regel.contains("is_action_just_pressed(\"debug_"):
			n += 1
			check("map.gd debugtoets achter debug-check: %s" % regel.strip_edges().left(70),
					regel.contains("is_debug_build()") or regel.contains("dev_rooms_allowed()"))
	check("map.gd: debugtoetsen gevonden (%d)" % n, n >= 1)


## Elke --suite in game_state.gd wijst naar code die niet in de export zit.
func _test_dispatch() -> void:
	var re := RegEx.create_from_string("\\[\"(--[a-z0-9_]+)\",\\s*\"res://([^\"]+)\"")
	var los: Array[String] = []
	var n := 0
	for m in re.search_all(FileAccess.get_file_as_string("res://scripts/game_state.gd")):
		n += 1
		var pad := m.get_string(2)
		var uit := pad.begins_with("scripts/tests/") or pad.begins_with("tools/") or pad.begins_with("world_warper/tests/") \
				or pad.begins_with("pvp/tests/") or pad in ["scripts/debug_autotest.gd", "scripts/debug_menutest.gd"]
		if not uit:
			los.append(m.get_string(1) + " -> " + pad)
	check("test-dispatch gevonden (%d)" % n, n > 0)
	check("alle test-/simscripts vallen buiten de export (%s)" % [los], los.is_empty())


# ---------------------------------------------------------------- ENABLED-vlaggen
func _enabled_vlaggen() -> void:
	check("F1 perfect dodge uit (SomPerfectDodgeData.ENABLED)", not PerfectDodge.ENABLED)
	check("F1 perfect dodge zonder force_active", PerfectDodge.force_active == null)
	var re := RegEx.create_from_string("(?m)^\\s*(?:static\\s+)?(?:const|var)\\s+([A-Z0-9_]*ENABLED)\\s*(?::\\s*bool\\s*)?:?=\\s*(true|false)\\b")
	var gevonden := 0
	for pad in _gd_bestanden():
		for m in re.search_all(FileAccess.get_file_as_string("res://" + pad)):
			gevonden += 1
			var sleutel := pad + ":" + m.get_string(1)
			if m.get_string(2) == "true":
				check("ENABLED aan alleen voor features die meegaan: %s" % sleutel, ENABLED_TOEGESTAAN.has(sleutel))
	check("ENABLED-vlaggen gescand (%d)" % gevonden, gevonden >= 3)


func _gd_bestanden() -> Array[String]:
	var uit: Array[String] = []
	var rij: Array[String] = []
	rij.append_array(SCAN_MAPPEN)
	while not rij.is_empty():
		var map: String = rij.pop_back()
		if map.ends_with("/tests") or map == "scripts/tests":
			continue
		for f in DirAccess.get_files_at("res://" + map):
			if f.ends_with(".gd") and not f.ends_with("_test.gd"):
				uit.append(map + "/" + f)
		for d in DirAccess.get_directories_at("res://" + map):
			rij.append(map + "/" + d)
	return uit


# ---------------------------------------------------------------- bekende OPEN-punten (RC_AUDIT_WM1.md)
func _bekende_open_punten(cfg: ConfigFile, android: Array[String]) -> void:
	var code := 0
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_SRC))
	if src is Dictionary:
		code = int(src.get("version_code", 0))
	open_punt("F8.2", "version_code hoger dan de laatst uitgebrachte build", code <= LAATSTE_CODE,
			"version_code %d, laatste build %d (v0.20). Bump doet RPG Forge (bump_version minor)." % [code, LAATSTE_CODE])
	var naam := str(ProjectSettings.get_setting("application/config/version", ""))
	open_punt("F8.4", "README.md noemt de actuele versie", not FileAccess.get_file_as_string("res://README.md").contains(naam),
			"README noemt %s nergens (wel nog 'versie 0.13 (code 15)'). Bijwerken doet RPG Forge." % naam)
	var netwerk: Array[String] = []
	for s in android:
		for k: String in ["permissions/internet", "permissions/access_wifi_state", "permissions/change_wifi_multicast_state"]:
			if bool(cfg.get_value(s + ".options", k, false)) and not netwerk.has(k.get_slice("/", 1)):
				netwerk.append(k.get_slice("/", 1))
	open_punt("F8.8", "netwerkrechten passen bij H11", Flags.online_cut and Flags.relay_url() == "" and not netwerk.is_empty(),
			"online staat dicht (online_cut, geen relay-URL) maar de presets vragen %s. Besluit Dennis, aanpassen RPG Forge." % [netwerk])
	var sfx := _open_regels("res://tools/placeholders_algemene_sfx.txt", false)
	open_punt("F6.23", "geen placeholder-sfx meer", sfx > 0,
			"%d regels in tools/placeholders_algemene_sfx.txt (LAUNCH_PLAN B2: blocker tot tools/sfx/ draait)." % sfx)
	var acteur := _open_regels("res://tools/placeholders_sfx.txt", false)
	open_punt("F6.23b", "geen placeholder-acteur-sfx meer", acteur > 0,
			"%d regels in tools/placeholders_sfx.txt." % acteur)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/audio_manifest.json"))
	var ww_mist: Array[String] = []
	if manifest is Dictionary:
		if not (manifest.get("bgm", {}) as Dictionary).has(Ambience.MUSIC_AMBIENT):
			ww_mist.append(Ambience.MUSIC_AMBIENT)
		for cue: String in [Ambience.SFX_HUM, Ambience.SFX_WARP, Ambience.SFX_GLITCH]:
			if not (manifest.get("sfx", {}) as Dictionary).has(cue):
				ww_mist.append(cue)
	open_punt("F6.24", "World Warper-cues zwijgen zonder fout", not ww_mist.is_empty(),
			"%s staan niet in het manifest: geen crash, wel één push_error per cue (AudioManager._report) in de hub." % [ww_mist])
	var art := _open_regels("res://tools/placeholders_v17.txt", true)
	open_punt("F2.5", "placeholderlijst art bijgewerkt", art > 0,
			"%d regels in tools/placeholders_v17.txt zonder KLAAR/VERVANGEN (o.a. dubbele Wilgendal-regels). Werk voor RPG Forge/ART." % art)


## Telt niet-lege, niet-commentaarregels. Met zonder_status: alleen regels zonder KLAAR/VERVANGEN.
func _open_regels(pad: String, zonder_status: bool) -> int:
	if not FileAccess.file_exists(pad):
		return 0
	var n := 0
	for r: String in FileAccess.get_file_as_string(pad).split("\n"):
		var t := r.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		if zonder_status and (t.contains("KLAAR") or t.contains("VERVANGEN")):
			continue
		n += 1
	return n


# ---------------------------------------------------------------- RC-besluit Dennis 15 nov (Job 11: F8.1/F8.2/F8.8)
## Afwijkingen van de RC-versie (0.21 / 23) in versiebron, project.godot en elke Android-preset. Leeg = goed.
static func rc_versie_fouten(src: Variant, project_versie: String, cfg: ConfigFile, android: Array[String]) -> Array[String]:
	var fout: Array[String] = []
	if not (src is Dictionary):
		fout.append("versiebron geen object")
	else:
		if str(src.get("version_name", "")) != RC_VERSIE:
			fout.append("versiebron name %s" % src.get("version_name", ""))
		if int(src.get("version_code", -1)) != RC_CODE:
			fout.append("versiebron code %s" % src.get("version_code", ""))
	if project_versie != RC_VERSIE:
		fout.append("project.godot %s" % project_versie)
	if android.is_empty():
		fout.append("geen Android-preset")
	for s in android:
		var o := s + ".options"
		if str(cfg.get_value(o, "version/name", "")) != RC_VERSIE:
			fout.append("%s name %s" % [s, cfg.get_value(o, "version/name", "")])
		if int(cfg.get_value(o, "version/code", -1)) != RC_CODE:
			fout.append("%s code %s" % [s, cfg.get_value(o, "version/code", "")])
	return fout


## Netwerkrechten die nog AAN staan in een Android-preset ("preset.N:recht"). Leeg = goed.
static func rc_netwerk_aan(cfg: ConfigFile, android: Array[String]) -> Array[String]:
	var aan: Array[String] = []
	for s in android:
		for k in RC_NET_RECHTEN:
			if bool(cfg.get_value(s + ".options", k, false)):
				aan.append("%s:%s" % [s, k.get_slice("/", 1)])
	return aan


func _rc_besluit(cfg: ConfigFile, android: Array[String]) -> void:
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_SRC))
	var pv := str(ProjectSettings.get_setting("application/config/version", ""))
	var vf := rc_versie_fouten(src, pv, cfg, android)
	check("[F8.1/F8.2] RC-versie %s / code %d overal (afwijkend: %s)" % [RC_VERSIE, RC_CODE, vf], vf.is_empty())
	check("[F8.2] RC-code %d hoger dan laatste build %d" % [RC_CODE, LAATSTE_CODE], RC_CODE > LAATSTE_CODE)
	if Flags.online_cut:
		var na := rc_netwerk_aan(cfg, android)
		check("[F8.8] netwerkrechten uit in alle Android-presets (nog aan: %s)" % [na], na.is_empty())
		# Solo zonder netwerk: PvP/Co-op-knoppen verborgen in een release (online_cut, geen relay-URL).
		check("[F8.8] online dicht: online_cut aan", true)
		check("[F8.8] online dicht: PvP/Co-op-knoppen verborgen", not Flags.online_buttons_visible())
	else:
		# Zelfde vier als coophosttest (coop/easy-presets; geen change_wifi/state op LAN/relay).
		var verplicht: Array[String] = [
			"permissions/internet", "permissions/access_network_state",
			"permissions/access_wifi_state", "permissions/change_wifi_multicast_state",
		]
		var uit: Array[String] = []
		for s in android:
			for k in verplicht:
				if not bool(cfg.get_value(s + ".options", k, false)):
					uit.append("%s:%s" % [s, k.get_slice("/", 1)])
		check("[F8.8] co-op release: kern-netwerkrechten aan (nog uit: %s)" % [uit], uit.is_empty())
		check("[F8.8] co-op release: online_cut uit", not Flags.online_cut)
		check("[F8.8] co-op release: online-knoppen zichtbaar", Flags.online_buttons_visible())
	# Zelftest van de regels: een preset met de oude stand moet FAIL opleveren.
	var nep := ConfigFile.new()
	nep.set_value("preset.0", "platform", "Android")
	nep.set_value("preset.0.options", "version/name", "0.20")
	nep.set_value("preset.0.options", "version/code", 22)
	nep.set_value("preset.0.options", "permissions/internet", true)
	nep.set_value("preset.0.options", "permissions/change_wifi_multicast_state", true)
	var nep_android: Array[String] = ["preset.0"]
	var oud := rc_versie_fouten({"version_name": "0.20", "version_code": 22}, "0.20", nep, nep_android)
	check("zelftest: versie 0.20/22 wordt afgekeurd (%d afwijkingen)" % oud.size(), oud.size() == 5)
	check("zelftest: alleen code fout (0.21/22) wordt afgekeurd",
			rc_versie_fouten({"version_name": "0.21", "version_code": 22}, "0.21", ConfigFile.new(), [] as Array[String]).size() == 2)
	check("zelftest: netwerkrecht aan wordt afgekeurd (%s)" % [rc_netwerk_aan(nep, nep_android)],
			rc_netwerk_aan(nep, nep_android).size() == 2)
	nep.set_value("preset.0.options", "version/name", RC_VERSIE)
	nep.set_value("preset.0.options", "version/code", RC_CODE)
	nep.set_value("preset.0.options", "permissions/internet", false)
	nep.set_value("preset.0.options", "permissions/change_wifi_multicast_state", false)
	check("zelftest: 0.21/23 zonder netwerk wordt goedgekeurd",
			rc_versie_fouten({"version_name": RC_VERSIE, "version_code": RC_CODE}, RC_VERSIE, nep, nep_android).is_empty()
			and rc_netwerk_aan(nep, nep_android).is_empty())
