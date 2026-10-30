extends Node
## ALLEEN VOOR TESTEN - gevechtsbugs H1-H3 uit REVIEW_COMBAT.md (r2-1).
## Start:  godot --path . -- --combatbugstest
##   H1: Feniksveer (item-revive) haalt de held ook visueel uit KO (set_ko(false)), net als de spreuk.
##   H2: reported_ko wordt bij een revive gewist, zodat een volgende KO weer "is down!" meldt.
##   H3: een item wordt pas afgeschreven als het effect heeft (Feniksveer zonder KO-held,
##       Tegengif zonder gif/binden = niet verbruiken).
## Echt battle.tscn met het sim-script (geen wachttijden, geen rondelus); berichten worden gelogd.
## Zit niet in de export (scripts/tests/*).

const Runs := preload("res://tools/battlesim/battlesim_runs.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const BATTLE := "res://scenes/battle/battle.tscn"


## Sim-gevecht dat elk bericht bewaart (om "is down!" / "no effect" te kunnen controleren).
class LogBattle extends "res://tools/battlesim/sim_battle.gd":
	var log_lines: Array = []

	func show_message(text: String) -> void:
		log_lines.append(text)


var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while not GameState._preloading.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("=== H1: Feniksveer haalt held uit KO-pose ===")
	await _h1_tests()
	print("=== H2: reported_ko na revive gewist ===")
	await _h2_tests()
	print("=== H3: item pas verbruiken bij effect ===")
	await _h3_tests()
	print("COMBATBUGSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	for i in 10:
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _battle(bag: Dictionary) -> Control:
	var r: Node = Runs.new()
	r.standalone = false
	add_child(r)
	r._build_party([["dennis", 5], ["noor", 5]], bag)
	r.queue_free()
	GameState.prepare_battle(["mosslijm"], "", false, 0)
	var b: Control = (load(BATTLE) as PackedScene).instantiate()
	b.set_script(LogBattle)
	b.sim_started = true          # rondelus niet starten: alleen _execute testen
	add_child(b)
	return b


## Held KO slaan via de echte schadeweg (_hit zet de pose, _report_kos meldt).
func _knock_out(b: Control, h: Dictionary) -> void:
	h["s"]["hp"] = 1
	await b._damage(h, 999)


func _count(lines: Array, text: String) -> int:
	var n := 0
	for l in lines:
		if str(l) == text:
			n += 1
	return n


func _item(b: Control, actor: Dictionary, id: String, target) -> void:
	await b._execute({"type": "item", "actor": actor, "item": id, "target": target})


# ================================================================ H1
func _h1_tests() -> void:
	var b := _battle({"feniksveer": 2})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	await _knock_out(b, dax)
	check("opzet: held is KO (hp 0, KO-pose)", int(dax["s"]["hp"]) == 0 and dax["node"].is_ko)
	await _item(b, noor, "feniksveer", dax)
	check("Feniksveer: held heeft weer HP", int(dax["s"]["hp"]) > 0)
	check("Feniksveer: held staat ook visueel op (is_ko == false)", not dax["node"].is_ko)
	check("Feniksveer: 1 veer verbruikt", GameState.item_count("feniksveer") == 1)
	# de revive-spreuk loopt via dezelfde helper
	await _knock_out(b, dax)
	await b._revive(dax, 10)
	check("revive-spreuk: HP 10 en KO-pose weg", int(dax["s"]["hp"]) == 10 and not dax["node"].is_ko)
	b.queue_free()


# ================================================================ H2
func _h2_tests() -> void:
	var b := _battle({"feniksveer": 2})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	var down := "%s is down!" % dax["name"]
	await _knock_out(b, dax)
	check("eerste KO gemeld", _count(b.log_lines, down) == 1 and bool(dax.get("reported_ko", false)))
	await _item(b, noor, "feniksveer", dax)
	check("Feniksveer wist reported_ko", not dax.has("reported_ko"))
	await _knock_out(b, dax)
	check("tweede KO na Feniksveer weer gemeld ('is down!' 2x)", _count(b.log_lines, down) == 2)
	await b._revive(dax, 5)
	check("revive-spreuk wist reported_ko", not dax.has("reported_ko"))
	await _knock_out(b, dax)
	check("derde KO na revive-spreuk weer gemeld ('is down!' 3x)", _count(b.log_lines, down) == 3)
	b.queue_free()


# ================================================================ H3
func _h3_tests() -> void:
	var b := _battle({"feniksveer": 1, "tegengif": 1})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	# Feniksveer zonder KO-held: geen effect, niet verbruikt
	b.log_lines.clear()
	await _item(b, noor, "feniksveer", dax)
	check("Feniksveer op levende held (niemand KO): niet verbruikt", GameState.item_count("feniksveer") == 1)
	check("Feniksveer zonder effect meldt 'no effect'", b.log_lines.has(PartyActions.MSG_NO_EFFECT))
	check("Feniksveer zonder effect: HP ongewijzigd", int(dax["s"]["hp"]) == int(dax["s"]["max_hp"]))
	# levend doel gekozen maar een ander is KO: die staat op en de veer gaat weg
	await _knock_out(b, dax)
	await _item(b, noor, "feniksveer", noor)
	check("Feniksveer op levend doel met KO-held erbij: KO-held staat op", int(dax["s"]["hp"]) > 0 and not dax["node"].is_ko)
	check("...en dan wel verbruikt", GameState.item_count("feniksveer") == 0)
	# Tegengif zonder gif of binden: niet verbruiken
	dax["dots"] = []
	dax["skip"] = 0
	b.log_lines.clear()
	await _item(b, noor, "tegengif", dax)
	check("Tegengif zonder gif/binden: niet verbruikt", GameState.item_count("tegengif") == 1)
	check("Tegengif zonder effect meldt geen 'is cured'", not b.log_lines.has("%s is cured." % dax["name"]))
	# Tegengif met gif: wel effect en verbruikt
	dax["dots"] = [{"gif": true, "amount": 3, "turns": 2}]
	await _item(b, noor, "tegengif", dax)
	check("Tegengif met gif: gif weg en verbruikt", (dax["dots"] as Array).is_empty() and GameState.item_count("tegengif") == 0)
	b.queue_free()
