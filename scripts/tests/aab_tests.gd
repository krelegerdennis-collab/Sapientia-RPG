extends Node
## Play Store-release (--aabtest): versiebron, AAB-preset, bump_version, build-script (zonder geheimen) en docs.
## Start: godot --path . -- --aabtest [--shots=/pad/map]
##
## De tests lezen alleen bestanden en draaien `tools/release/bump_version` (python3) en
## `tools/release/build_aab.sh --check-env` (bash). Er wordt niets gebouwd en er is geen Android SDK nodig.

## Google Play (sinds 31 aug 2026): nieuwe apps en updates moeten targetSdk 36 (Android 16) of hoger hebben.
const MIN_TARGET_SDK := 36
const AAB_PRESET := "Android AAB"
const SOURCE := "res://tools/release/version.json"
const SECRET_CANARIES := ["CANARY_storepw_9f3a", "CANARY_alias_1c7e", "CANARY_keypw_77b2"]

var failures := 0
var passes := 0
var shots := ""
var root := ""
var can_run_scripts := false


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


func _run() -> void:
	root = ProjectSettings.globalize_path("res://").trim_suffix("/")
	var probe: Dictionary = _cmd("python3", ["--version"])
	can_run_scripts = OS.get_name() == "Linux" and int(probe["code"]) == 0 and FileAccess.file_exists(root + "/tools/release/bump_version")
	if not can_run_scripts:
		print("INFO  python3/Linux niet beschikbaar: script-tests worden overgeslagen")
	_bron_tests()
	_preset_tests()
	_geheimen_tests()
	_docs_tests()
	if can_run_scripts:
		_bump_tests()
		_build_script_tests()
	print("AABTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _cmd(program: String, args: Array) -> Dictionary:
	var out: Array = []
	var code := OS.execute(program, PackedStringArray(args), out, true)
	return {"code": code, "out": "".join(out)}


func _bron() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return parsed if parsed is Dictionary else {}


func _android_presets(cfg: ConfigFile) -> Array[String]:
	var found: Array[String] = []
	for sec in cfg.get_sections():
		var name := str(sec)
		if not name.ends_with(".options") and str(cfg.get_value(name, "platform", "")) == "Android":
			found.append(name)
	return found


func _bron_tests() -> void:
	var src := _bron()
	check("versiebron %s laadt als JSON" % SOURCE, not src.is_empty())
	var naam := str(src.get("version_name", ""))
	var code: Variant = src.get("version_code")
	var re := RegEx.create_from_string("^\\d+\\.\\d+(\\.\\d+)?$")
	check("version_name '%s' is X.Y of X.Y.Z" % naam, re.search(naam) != null)
	check("version_code is een geheel getal 1..2100000000 (%s)" % str(code),
			(code is int or code is float) and int(code) >= 1 and int(code) <= 2100000000 and float(code) == int(code))
	check("project.godot config/version == bron (%s)" % ProjectSettings.get_setting("application/config/version"),
			str(ProjectSettings.get_setting("application/config/version")) == naam)


func _preset_tests() -> void:
	var src := _bron()
	var cfg := ConfigFile.new()
	check("export_presets.cfg laadt", cfg.load("res://export_presets.cfg") == OK)
	var presets := _android_presets(cfg)
	check("minstens drie Android-presets (nu %d)" % presets.size(), presets.size() >= 3)
	for sec in presets:
		var opt := sec + ".options"
		var label := "%s (%s)" % [sec, str(cfg.get_value(sec, "name", ""))]
		check("%s: version/name en version/code == bron" % label,
				str(cfg.get_value(opt, "version/name", "")) == str(src.get("version_name", "?"))
				and int(cfg.get_value(opt, "version/code", -1)) == int(src.get("version_code", -2)))
		check("%s: pakketnaam opgebouwd als reverse-domain" % label,
				RegEx.create_from_string("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$").search(str(cfg.get_value(opt, "package/unique_name", ""))) != null)

	var aab := ""
	for sec in presets:
		if str(cfg.get_value(sec, "name", "")) == AAB_PRESET:
			aab = sec
	check("preset '%s' bestaat" % AAB_PRESET, aab != "")
	if aab == "":
		return
	var o := aab + ".options"
	check("AAB: Gradle-build aan", bool(cfg.get_value(o, "gradle_build/use_gradle_build", false)))
	check("AAB: export_format = 1 (Android App Bundle)", int(cfg.get_value(o, "gradle_build/export_format", 0)) == 1)
	var target := str(cfg.get_value(o, "gradle_build/target_sdk", ""))
	check("AAB: target_sdk '%s' >= %d (Play-eis)" % [target, MIN_TARGET_SDK], target.is_valid_int() and int(target) >= MIN_TARGET_SDK)
	var min_sdk := str(cfg.get_value(o, "gradle_build/min_sdk", ""))
	check("AAB: min_sdk '%s' is geldig en <= target_sdk" % min_sdk,
			min_sdk.is_valid_int() and int(min_sdk) >= 21 and target.is_valid_int() and int(min_sdk) <= int(target))
	check("AAB: alleen arm64-v8a",
			bool(cfg.get_value(o, "architectures/arm64-v8a", false))
			and not bool(cfg.get_value(o, "architectures/armeabi-v7a", true))
			and not bool(cfg.get_value(o, "architectures/x86", true))
			and not bool(cfg.get_value(o, "architectures/x86_64", true)))
	check("AAB: package/signed = true (sleutel via omgeving)", bool(cfg.get_value(o, "package/signed", false)))
	check("AAB: INTERNET-permissie (co-op/relay)", bool(cfg.get_value(o, "permissions/internet", false)))
	check("AAB: tests/docs/tools niet in de export",
			str(cfg.get_value(aab, "exclude_filter", "")).contains("scripts/tests/*")
			and str(cfg.get_value(aab, "exclude_filter", "")).contains("tools/*"))
	check("AAB: *.json-filter voor het audio-manifest", str(cfg.get_value(aab, "include_filter", "")).contains("*.json"))
	check("AAB: package/name SAPIENTIA", str(cfg.get_value(o, "package/name", "")) == "SAPIENTIA")


func _geheimen_tests() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var leeg := true
	for sec in _android_presets(cfg):
		var opt := sec + ".options"
		for key in cfg.get_section_keys(opt):
			if str(key).begins_with("keystore/") and str(cfg.get_value(opt, str(key), "")) != "":
				leeg = false
	check("export_presets.cfg: alle keystore/*-velden leeg of afwezig", leeg)

	var ignore := FileAccess.get_file_as_string("res://.gitignore")
	for pattern in ["*.keystore", "*.jks", "*.aab", "*.apk", "android/", "*.uid"]:
		check(".gitignore bevat %s" % pattern, ignore.split("\n").has(pattern))

	var sh := FileAccess.get_file_as_string("res://tools/release/build_aab.sh")
	check("build_aab.sh bestaat", sh != "")
	var code_regels := PackedStringArray()
	for line in sh.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_regels.append(line)
	var code := "\n".join(code_regels)
	check("build_aab.sh: geen 'set -x' (zou geheimen tonen)", not code.contains("set -x") and not code.contains("set -o xtrace"))
	check("build_aab.sh: geen wachtwoord als argument (-storepass/--password)",
			not code.contains("-storepass") and not code.contains("-keypass") and not code.contains("--password"))
	var lek := ""
	for line in sh.split("\n"):
		var l := line.strip_edges()
		var toont := l.begins_with("echo") or l.begins_with("printf") or l.begins_with("print(") or l.contains("| tee")
		if toont and (l.contains("$ANDROID_KEYSTORE_PASSWORD") or l.contains("${ANDROID_KEYSTORE_PASSWORD")
				or l.contains("$ANDROID_KEY_PASSWORD") or l.contains("${ANDROID_KEY_PASSWORD")
				or l.contains("$ANDROID_KEY_ALIAS") or l.contains("${ANDROID_KEY_ALIAS")):
			lek = l
	check("build_aab.sh: echo/printf toont nooit keystore-waarden (%s)" % lek, lek == "")
	check("build_aab.sh: Godot-uitvoer wordt geredigeerd getoond", sh.contains("redact()") and sh.contains("| redact"))
	check("build_aab.sh leest alle vier de keystore-variabelen uit de omgeving",
			sh.contains("ANDROID_KEYSTORE_PATH") and sh.contains("ANDROID_KEY_ALIAS")
			and sh.contains("ANDROID_KEYSTORE_PASSWORD") and sh.contains("ANDROID_KEY_PASSWORD")
			and sh.contains("GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"))


func _docs_tests() -> void:
	var cl := FileAccess.get_file_as_string("res://CHANGELOG.md")
	check("CHANGELOG.md bestaat met [Unreleased]", cl.contains("## [Unreleased]"))
	for v in ["0.18", "0.19", "0.20"]:
		check("CHANGELOG.md heeft een kopje voor [%s]" % v, cl.contains("## [%s]" % v))
	var naam := str(_bron().get("version_name", "?"))
	check("CHANGELOG.md heeft een kopje voor de huidige versie [%s]" % naam, cl.contains("## [%s]" % naam))
	check("CHANGELOG.md begint niet eerder dan v0.18", not cl.contains("## [0.17]") and not cl.contains("## [0.16]"))

	var doc := FileAccess.get_file_as_string("res://docs/release/PLAY_STORE.md")
	check("docs/release/PLAY_STORE.md bestaat", doc != "")
	check("PLAY_STORE.md: pakketnaamvoorstel (huidig com.dennis.rpgprototype, Dennis kiest)",
			doc.contains("com.dennis.rpgprototype") and doc.contains("Dennis kiest"))
	check("PLAY_STORE.md: persoonlijk account, 12 testers, 14 dagen",
			doc.contains("12 testers") and doc.contains("14 dagen") and doc.to_lower().contains("persoonlijk"))
	check("PLAY_STORE.md: store-listing-checklist", doc.contains("- [ ]") and doc.to_lower().contains("checklist"))
	check("PLAY_STORE.md: targetSdk 36 en 16 KB", doc.contains("targetSdk") and doc.contains("36") and doc.contains("16 KB"))
	check("PLAY_STORE.md: CI-job alleen als voorstel", doc.to_lower().contains("voorstel") and doc.contains("workflow_dispatch"))
	check("PLAY_STORE.md: verwijst naar bump_version en build_aab.sh", doc.contains("bump_version") and doc.contains("build_aab.sh"))


func _bump_tests() -> void:
	var proj := root
	var r: Dictionary = _cmd("python3", [proj + "/tools/release/bump_version", "--check", "--root", proj])
	check("bump_version --check op de echte repo: exit 0 (%s)" % str(r["out"]).strip_edges().get_slice("\n", 0), int(r["code"]) == 0)

	var tmp := ProjectSettings.globalize_path("user://aab_tmp")
	DirAccess.make_dir_recursive_absolute(tmp + "/tools/release")
	for f in ["project.godot", "export_presets.cfg", "CHANGELOG.md", "tools/release/version.json"]:
		var src := FileAccess.get_file_as_string("res://" + f)
		var w := FileAccess.open(tmp + "/" + f, FileAccess.WRITE)
		w.store_string(src)
		w.close()
	var bump := proj + "/tools/release/bump_version"
	var vorige := _bron()
	var oude_code := int(vorige["version_code"])
	var web_voor := _web_sectie(tmp + "/export_presets.cfg")

	r = _cmd("python3", [bump, "--root", tmp, "--dry-run", "minor", "--date", "2030-01-01"])
	check("dry-run: exit 0 en meldt dry-run", int(r["code"]) == 0 and str(r["out"]).contains("[dry-run]"))
	check("dry-run: bron ongewijzigd", FileAccess.get_file_as_string(tmp + "/tools/release/version.json") == FileAccess.get_file_as_string("res://" + "tools/release/version.json"))

	r = _cmd("python3", [bump, "--root", tmp, "minor", "--date", "2030-01-01"])
	check("minor: exit 0", int(r["code"]) == 0)
	var parts := str(vorige["version_name"]).split(".")
	var verwacht := "%s.%d" % [parts[0], int(parts[1]) + 1]
	var nieuw: Variant = JSON.parse_string(FileAccess.get_file_as_string(tmp + "/tools/release/version.json"))
	check("minor: bron %s (%d) -> %s (%d)" % [vorige["version_name"], oude_code, verwacht, oude_code + 1],
			nieuw is Dictionary and str(nieuw["version_name"]) == verwacht and int(nieuw["version_code"]) == oude_code + 1)
	var cfg := ConfigFile.new()
	cfg.load(tmp + "/export_presets.cfg")
	var alle := true
	for sec in _android_presets(cfg):
		alle = alle and str(cfg.get_value(sec + ".options", "version/name", "")) == verwacht \
				and int(cfg.get_value(sec + ".options", "version/code", 0)) == oude_code + 1
	check("minor: alle %d Android-presets bijgewerkt" % _android_presets(cfg).size(), alle and _android_presets(cfg).size() >= 3)
	check("minor: Web-preset byte-voor-byte ongewijzigd", web_voor != "" and _web_sectie(tmp + "/export_presets.cfg") == web_voor)
	check("minor: project.godot config/version bijgewerkt",
			FileAccess.get_file_as_string(tmp + "/project.godot").contains('config/version="%s"' % verwacht))
	var cl := FileAccess.get_file_as_string(tmp + "/CHANGELOG.md")
	check("minor: changelog-kopje '## [%s] - 2030-01-01' onder [Unreleased]" % verwacht,
			cl.find("## [Unreleased]") >= 0 and cl.find("## [%s] - 2030-01-01" % verwacht) > cl.find("## [Unreleased]"))
	r = _cmd("python3", [bump, "--root", tmp, "--check"])
	check("na minor: --check slaagt", int(r["code"]) == 0)

	r = _cmd("python3", [bump, "--root", tmp, "set", "9.9", "--code", str(oude_code)])
	check("set met niet-stijgende versionCode wordt geweigerd", int(r["code"]) != 0)
	r = _cmd("python3", [bump, "--root", tmp, "set", "abc"])
	check("set met ongeldige naam wordt geweigerd", int(r["code"]) != 0)
	r = _cmd("python3", [bump, "--root", tmp, "set", "1.0", "--code", "2100000001"])
	check("versionCode boven 2.100.000.000 wordt geweigerd", int(r["code"]) != 0)

	var tekst := FileAccess.get_file_as_string(tmp + "/export_presets.cfg")
	var kapot := tekst.replace('version/code=%d' % (oude_code + 1), "version/code=1")
	var w2 := FileAccess.open(tmp + "/export_presets.cfg", FileAccess.WRITE)
	w2.store_string(kapot)
	w2.close()
	r = _cmd("python3", [bump, "--root", tmp, "--check"])
	check("--check ziet een afwijkende versionCode in een preset (exit 1)", int(r["code"]) == 1 and str(r["out"]).contains("export_presets.cfg"))
	r = _cmd("python3", [bump, "--root", tmp, "--sync"])
	check("--sync herstelt de presets", int(r["code"]) == 0 and int(_cmd("python3", [bump, "--root", tmp, "--check"])["code"]) == 0)
	_verwijder_map(tmp)


func _web_sectie(pad: String) -> String:
	var t := FileAccess.get_file_as_string(pad)
	var a := t.find("[preset.2]")
	var b := t.find("[preset.3]")
	if a < 0 or b < 0:
		return ""
	return t.substr(a, b - a)


func _build_script_tests() -> void:
	var env := "ANDROID_KEYSTORE_PASSWORD=%s ANDROID_KEY_ALIAS=%s ANDROID_KEY_PASSWORD=%s ANDROID_KEYSTORE_PATH=/nonexistent/keystore" % SECRET_CANARIES
	var r: Dictionary = _cmd("bash", ["-c", "cd '%s' && %s GODOT=/nonexistent/godot tools/release/build_aab.sh --check-env 2>&1" % [root, env]])
	var out := str(r["out"])
	check("build_aab.sh --check-env met onvolledige omgeving: exit 1, geen build", int(r["code"]) == 1 and out.contains("geen build gestart"))
	var lek := false
	for canary in SECRET_CANARIES:
		lek = lek or out.contains(canary)
	check("build_aab.sh --check-env toont geen enkele keystore-waarde", not lek)
	check("build_aab.sh meldt wat ontbreekt bij naam", out.contains("ONTBREEKT") and out.contains("Godot-binary"))
	check("build_aab.sh: variabelen gezet = 'gezet' zonder waarde", out.contains("ANDROID_KEY_ALIAS gezet") and out.contains("ANDROID_KEYSTORE_PASSWORD gezet"))

	r = _cmd("bash", ["-c", "cd '%s' && env -u ANDROID_KEYSTORE_PATH -u ANDROID_KEY_ALIAS -u ANDROID_KEYSTORE_PASSWORD -u ANDROID_KEY_PASSWORD GODOT=/nonexistent/godot tools/release/build_aab.sh --check-env 2>&1" % root])
	out = str(r["out"])
	check("zonder keystore-variabelen: exit 1 met de namen van alle drie de verplichte variabelen",
			int(r["code"]) == 1 and out.contains("ONTBREEKT  ANDROID_KEYSTORE_PATH") and out.contains("ONTBREEKT  ANDROID_KEY_ALIAS")
			and out.contains("ONTBREEKT  ANDROID_KEYSTORE_PASSWORD"))
	r = _cmd("bash", ["-c", "cd '%s' && tools/release/build_aab.sh --onzin 2>&1" % root])
	check("build_aab.sh: onbekende optie geeft exit 2", int(r["code"]) == 2)


func _verwijder_map(pad: String) -> void:
	var d := DirAccess.open(pad)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(pad + "/" + f)
	for sub in d.get_directories():
		_verwijder_map(pad + "/" + sub)
	DirAccess.remove_absolute(pad)
