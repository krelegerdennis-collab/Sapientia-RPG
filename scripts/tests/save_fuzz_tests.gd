extends Node
## ALLEEN VOOR TESTEN - save-fuzz: laden van kapotte/rare savebestanden mag nooit crashen.
## Start:  godot --path . -- --savefuzztest
##   Deel A: ontbrekend bestand, leeg bestand, rommel-bytes, kapotte JSON, geen object
##   Deel B: afgekapt bestand (halverwege en op meerdere plekken)
##   Deel C: oude/verouderde saves: ontbrekende velden, verkeerde types per veld
## Werkt alleen op tijdelijke paden (user://savefuzz_*); echte saves worden niet aangeraakt.
## Zit niet in de export (scripts/tests/*).

const SAVE := "user://savefuzz_main.json"
const TOWN := "res://scenes/maps/wilgendal.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(777)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _remove_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _write(path: String, text: String) -> void:
	_write_bytes(path, text.to_utf8_buffer())


## Een kapotte save: niets geladen, load_game geeft netjes false + melding, spel blijft speelbaar.
func _expect_reject(label: String) -> void:
	var before_party := GameState.party.size()
	var before_gold: int = GameState.gold
	var data = GameState.read_save(SAVE)
	check(label + ": read_save geeft lege Dictionary", data is Dictionary and (data as Dictionary).is_empty())
	var r = GameState.load_game(SAVE)
	check(label + ": load_game geeft false (geen crash)", r is bool and r == false)
	check(label + ": duidelijke melding", GameState.last_load_notice == GameState.NOTICE_UNREADABLE)
	check(label + ": party/goud onaangetast", GameState.party.size() == before_party and GameState.gold == before_gold)
	check(label + ": has_save crasht niet", GameState.has_save() is bool)


## Een (deels) geldige save: load_game geeft true en de toestand is bruikbaar.
func _expect_load(label: String) -> void:
	var r = GameState.load_game(SAVE)
	check(label + ": load_game geeft true (geen crash)", r is bool and r == true)
	check(label + ": party niet leeg", GameState.party.size() > 0)
	check(label + ": goud is int >= 0", GameState.gold is int and GameState.gold >= 0)
	check(label + ": inventaris is Dictionary", GameState.inventory is Dictionary)
	# opnieuw opslaan na zo'n load mag ook niet crashen
	var d := GameState.state_data(Vector2i(3, 3), Vector2i.DOWN, TOWN)
	check(label + ": state_data daarna bruikbaar", d.get("party") is Array and d.get("map") is String)


func _run() -> void:
	var orig_path: String = GameState.save_path
	var orig_style = Settings.get_value("battle_style")
	GameState.save_path = SAVE
	_remove_save(SAVE)
	GameState.new_game("Fuzz")
	var good := GameState.state_data(Vector2i(5, 6), Vector2i.UP, TOWN)
	var good_text := JSON.stringify(good)

	# ---- Deel A
	print("--- Deel A: ontbrekend / leeg / rommel")
	_remove_save(SAVE)
	check("ontbrekend: has_save false", not GameState.has_save())
	_expect_reject("ontbrekend bestand")
	_write(SAVE, "")
	_expect_reject("leeg bestand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 3:
		var junk := PackedByteArray()
		junk.resize(64 + i * 200)
		for j in junk.size():
			junk[j] = rng.randi_range(0, 255)
		_write_bytes(SAVE, junk)
		_expect_reject("rommel-bytes #%d" % i)
	for t in ["{", "{\"map\": ", "null", "42", "\"save\"", "[1,2,3]", "{}", "{\"map\": 1, \"party\": {}}",
			"{\"party\": []}", "\u0000\u0000\u0000", "{\"map\": \"x\", \"party\": [}"]:
		_write(SAVE, t)
		_expect_reject("kapotte JSON '%s'" % t.c_escape())

	# ---- Deel B
	print("--- Deel B: afgekapt")
	for frac in [0.5, 0.1, 0.9, 0.99]:
		_write(SAVE, good_text.substr(0, int(good_text.length() * frac)))
		_expect_reject("afgekapt op %d%%" % int(frac * 100))
	# afgekapt maar met een geldige .bak: reservekopie wordt geladen
	_write(SAVE + ".bak", good_text)
	_write(SAVE, good_text.substr(0, good_text.length() / 2))
	var r_bak = GameState.load_game(SAVE)
	check("afgekapt + .bak: geladen uit reservekopie", r_bak is bool and r_bak == true \
			and GameState.last_load_notice == GameState.NOTICE_RECOVERED)
	_remove_save(SAVE)

	# ---- Deel C
	print("--- Deel C: oude saves / verkeerde types")
	_write(SAVE, JSON.stringify({"map": TOWN, "party": []}))
	_expect_load("minimale save (alleen map+party)")
	_write(SAVE, JSON.stringify({"map": TOWN, "party": [1, "x", null, [], {"id": 5}, {"id": "dennis", "hp": "veel"}]}))
	_expect_load("party vol rommel")
	var legacy := good.duplicate(true)
	legacy.erase("version")
	legacy.erase("battle_style")
	legacy.erase("checkpoint")
	legacy.erase("inventory")
	legacy.erase("gold")
	_write(SAVE, JSON.stringify(legacy))
	_expect_load("oude save zonder version/inventory/gold/checkpoint")
	# elk veld (behalve map/party) los vervangen door elk verkeerd type
	var wrong: Array = [null, "x", -7, 3.5, true, [], [1, "a"], {}, {"a": [1]}]
	var keys: Array = good.keys()
	var crashed := 0
	var total := 0
	for k in keys:
		if k == "map" or k == "party":
			continue
		for w in wrong:
			var d := good.duplicate(true)
			d[k] = w
			_write(SAVE, JSON.stringify(d))
			total += 1
			var r = GameState.load_game(SAVE)
			if not (r is bool and r == true) or GameState.party.is_empty() or not (GameState.gold is int):
				crashed += 1
				print("  mislukt: veld '%s' = %s" % [k, JSON.stringify(w)])
	check("verkeerde types: %d varianten over %d velden, allemaal netjes geladen" % [total, keys.size() - 2], crashed == 0)
	# heldvelden met verkeerde types
	var hero_wrong := good.duplicate(true)
	if hero_wrong["party"] is Array and not (hero_wrong["party"] as Array).is_empty() and hero_wrong["party"][0] is Dictionary:
		var h: Dictionary = hero_wrong["party"][0]
		for hk in h.keys():
			if hk != "id":
				h[hk] = "fout"
	_write(SAVE, JSON.stringify(hero_wrong))
	_expect_load("heldvelden allemaal String")
	# na al die rommel: een goede save laadt nog gewoon
	_write(SAVE, good_text)
	_expect_load("goede save na fuzz")
	check("goede save: naam terug", GameState.player_name == "Fuzz")

	_remove_save(SAVE)
	GameState.save_path = orig_path
	Settings.set_value("battle_style", orig_style)
	print("RESULT %s (%d passed, %d failed)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures else 0)
