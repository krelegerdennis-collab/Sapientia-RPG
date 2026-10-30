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
const GameData := preload("res://scripts/data/game_data.gd")
const Archief2Vijanden := preload("res://scripts/data/archief2_vijanden.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
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
	print("=== E1: Faded Note / items zonder gevechtseffect ===")
	await _e1_tests()
	print("=== E2: genees-item op volle HP/MP niet verbruiken ===")
	await _e2_tests()
	print("=== E3: KO + revive wist binden/gif/buffs ===")
	await _e3_tests()
	print("=== E4: buffs en gif verversen i.p.v. stapelen ===")
	await _e4_tests()
	print("=== E5: revive-spreuk zonder KO-doel kost geen MP ===")
	await _e5_tests()
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


# ================================================================ E1 (edge-case #1/#12)
func _e1_tests() -> void:
	var b := _battle({"h5_notitie": 1, "stunbom": 1, "drankje": 1})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	var lijst: Array = b._available_items()
	check("Faded Note staat niet in het gevechtsmenu", not lijst.has("h5_notitie"))
	check("Stun Bomb staat niet in het gevechtsmenu", not lijst.has("stunbom"))
	check("Potion staat wel in het gevechtsmenu", lijst.has("drankje"))
	# ook als de actie toch binnenkomt (oude reservering): niet verbruiken
	dax["s"]["mp"] = 0
	b.log_lines.clear()
	await _item(b, noor, "h5_notitie", dax)
	check("Faded Note in gevecht: niet verbruikt", GameState.item_count("h5_notitie") == 1)
	check("Faded Note in gevecht: 'no effect', geen 'uses'",
			b.log_lines.has(PartyActions.MSG_NO_EFFECT) and not b.log_lines.has("%s uses Faded Note!" % noor["name"]))
	await _item(b, noor, "stunbom", dax)
	check("Stun Bomb in gevecht: niet verbruikt", GameState.item_count("stunbom") == 1)
	b.queue_free()


# ================================================================ E2 (edge-case #2)
func _e2_tests() -> void:
	var b := _battle({"drankje": 1, "toverwater": 1})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	for h in b.heroes:
		h["s"]["hp"] = int(h["s"]["max_hp"])
		h["s"]["mp"] = int(h["s"]["max_mp"])
	b.log_lines.clear()
	await _item(b, noor, "drankje", dax)
	check("Potion op volle HP: niet verbruikt", GameState.item_count("drankje") == 1)
	check("Potion op volle HP: 'no effect'", b.log_lines.has(PartyActions.MSG_NO_EFFECT))
	await _item(b, noor, "toverwater", dax)
	check("Magic Water op volle MP: niet verbruikt", GameState.item_count("toverwater") == 1)
	dax["s"]["hp"] = int(dax["s"]["max_hp"]) - 5
	await _item(b, noor, "drankje", dax)
	check("Potion met HP-tekort: geneest en wordt verbruikt",
			int(dax["s"]["hp"]) == int(dax["s"]["max_hp"]) and GameState.item_count("drankje") == 0)
	b.queue_free()


# ================================================================ E3 (edge-case #3/#4)
func _e3_tests() -> void:
	var b := _battle({"feniksveer": 2})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	dax["skip"] = 1
	dax["skip_reden"] = Archief2Vijanden.SKIP_REDEN_BIND
	dax["dots"] = [{"pct": 0.08, "turns": 3, "gif": true}]
	dax["buffs"] = [{"stat": "atk", "pct": 0.2, "turns": 3}]
	dax["hots"] = [{"amount": 5, "turns": 2}]
	await _knock_out(b, dax)
	await _item(b, noor, "feniksveer", dax)
	check("Feniksveer: binden (skip) weg na revive", int(dax.get("skip", 0)) == 0 and not dax.has("skip_reden"))
	check("Feniksveer: gif/buffs/HoT weg na revive", (dax["dots"] as Array).is_empty()
			and (dax["buffs"] as Array).is_empty() and (dax["hots"] as Array).is_empty())
	b.log_lines.clear()
	await b._execute({"type": "defend", "actor": dax, "target": null})
	check("eerste actie na revive wordt niet overgeslagen", not b.log_lines.has("%s is bound and skips a turn." % dax["name"]))
	# zelfde regel voor de revive-spreuk (bevriezing)
	dax["skip"] = 2
	dax["skip_reden"] = "bevriezing"
	await _knock_out(b, dax)
	await b._revive(dax, 10)
	check("revive-spreuk: bevriezing weg na revive", int(dax.get("skip", 0)) == 0)
	b.queue_free()


# ================================================================ E4 (edge-case #5/#6)
func _e4_tests() -> void:
	var b := _battle({})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	var zegen: Dictionary = GameData.SPELLS["zegen"]
	for i in 5:
		b._apply_buffs(dax, zegen, noor)
	var atk_rijen := (dax["buffs"] as Array).filter(func(r): return str(r.get("stat", "")) == "atk")
	check("5x Blessing: 1 ATK-buffrij (verversen)", atk_rijen.size() == 1)
	var basis: float = b._token_mult(dax)
	var verwacht: float = basis * (1.0 + 0.2 * SpellRules.buff_factor(zegen, str(noor["s"].get("id", ""))))
	check("5x Blessing: ATK-factor = 1 cast (niet x2,49)", absf(b._buff_mult(dax, "atk") - verwacht) < 0.001)
	dax["buffs"][0]["turns"] = 1
	b._apply_buffs(dax, zegen, noor)
	check("Blessing opnieuw: beurten weer op 3", int(dax["buffs"][0]["turns"]) == 3)
	b._apply_buffs(dax, GameData.SPELLS["bescherming"], noor)
	check("andere stat (DEF) krijgt wel een eigen rij", (dax["buffs"] as Array).size() == 2)
	# gif (Sporekop): drie treffers = één rij van 8%, niet 24%/ronde
	var gif_skill := {"type": "poison"}
	dax["dots"] = [{"pct": 0.05, "turns": 2}]          # brand (geen gif) blijft apart
	for i in 3:
		Archief2Vijanden.apply(b.enemies[0], dax, gif_skill, 0)
	var gif_rijen := (dax["dots"] as Array).filter(func(d): return bool(d.get("gif", false)))
	check("3x gif: 1 gifrij", gif_rijen.size() == 1 and absf(float(gif_rijen[0]["pct"]) - Archief2Vijanden.POISON_PCT) < 0.0001)
	check("3x gif: brand-rij blijft los staan", (dax["dots"] as Array).size() == 2)
	b.queue_free()


# ================================================================ E5 (edge-case #7)
func _e5_tests() -> void:
	var b := _battle({})
	var dax: Dictionary = b.heroes[0]
	var noor: Dictionary = b.heroes[1]
	var sp: Dictionary = GameData.SPELLS["wederopstanding"]
	noor["s"]["mp"] = int(sp["mp"]) * 2
	noor["s"]["max_mp"] = maxi(int(noor["s"]["max_mp"]), int(sp["mp"]) * 2)
	b.log_lines.clear()
	await b._execute({"type": "spell", "actor": noor, "spell": "wederopstanding", "target": dax})
	check("revive-spreuk zonder KO-held: geen MP kwijt", int(noor["s"]["mp"]) == int(sp["mp"]) * 2)
	check("revive-spreuk zonder KO-held: 'no effect'", b.log_lines.has(PartyActions.MSG_NO_EFFECT))
	await _knock_out(b, dax)
	await b._execute({"type": "spell", "actor": noor, "spell": "wederopstanding", "target": dax})
	check("revive-spreuk met KO-held: wel MP kwijt en held staat op",
			int(noor["s"]["mp"]) == int(sp["mp"]) and int(dax["s"]["hp"]) > 0)
	b.queue_free()
