extends Node
## Headless suite voor Vriendenmodus. Niet gekoppeld aan het hoofdspel.
## Start: xvfb-run -a godot --rendering-driver opengl3 --path . res://pvp/tests/pvp_tests.tscn

var passes := 0
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_code_tests()
	_data_tests()
	_rule_tests()
	_battle_tests()
	_net_tests()
	_disconnect_tests()
	_action_tests()
	_reconnect_tests()
	await _lan_tests()
	_source_tests()
	await _ui_tests()
	print("PVPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _code_tests() -> void:
	var alphabet := PvpConnectCode.ALPHABET
	var clean := true
	for ch in ["0", "O", "1", "I", "L"]:
		if alphabet.find(ch) >= 0:
			clean = false
	check("alfabet zonder 0, O, 1, I en L", clean and alphabet.length() > 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var seen := {}
	var shape := true
	for _i in 400:
		var code := PvpConnectCode.generate(rng)
		if code.length() != PvpConnectCode.LENGTH:
			shape = false
		if seen.has(code):
			shape = false
		seen[code] = true
		for n in code.length():
			if alphabet.find(code[n]) < 0:
				shape = false
	check("code is 6 tekens, uit het alfabet, uniek over 400 worpen", shape and seen.size() == 400)
	var again := RandomNumberGenerator.new()
	again.seed = 7
	var twin := RandomNumberGenerator.new()
	twin.seed = 7
	check("zelfde zaad geeft dezelfde code", PvpConnectCode.generate(again) == PvpConnectCode.generate(twin))
	check("kleine letters worden een code", PvpConnectCode.parse("k7np2q") == "K7NP2Q")
	check("O wordt geweigerd", PvpConnectCode.parse("K7NP2O") == "")
	check("0 wordt geweigerd", PvpConnectCode.parse("K7NP20") == "")
	check("1 wordt geweigerd", PvpConnectCode.parse("K7NP21") == "")
	check("I wordt geweigerd", PvpConnectCode.parse("K7NPI2") == "")
	check("L wordt geweigerd", PvpConnectCode.parse("K7NPL2") == "")
	check("te kort wordt geweigerd", PvpConnectCode.parse("K7NP") == "")


func _data_tests() -> void:
	check("klassiek is Dennis, Noor, Lotte", PvpTeams.members("team_klassiek") == ["dennis", "noor", "lotte"])
	check("aanval is twee Dennis en Lotte", PvpTeams.members("team_aanval") == ["dennis", "dennis", "lotte"])
	check("verdediging is twee Lotte en Dennis", PvpTeams.members("team_verdediging") == ["lotte", "lotte", "dennis"])
	check("spiegelgevecht mag", PvpRules.mirror_allowed() and PvpRules.teams_ok("team_klassiek", "team_klassiek"))
	check("vroeg level 8 in band 5-10", PvpModes.level_of("early") == 8 and PvpModes.band_min("early") == 5 and PvpModes.band_max("early") == 10 and PvpModes.in_band("early"))
	check("midden level 18 in band 15-20", PvpModes.level_of("mid") == 18 and PvpModes.band_min("mid") == 15 and PvpModes.band_max("mid") == 20 and PvpModes.in_band("mid"))
	check("hoog level 25 vanaf 20", PvpModes.level_of("high") == 25 and PvpModes.band_min("high") == 20 and PvpModes.band_max("high") < 0 and PvpModes.in_band("high"))
	var dennis := PvpCharacters.scaled("dennis", 8)
	check("Dennis level 8 heeft 105 HP en 35 aanval voor uitrusting", int(dennis["max_hp"]) == 105 and int(dennis["atk"]) == 35 and int(dennis["max_mp"]) == 0)
	var early := PvpRoster.build_side("host", "team_klassiek", "early")
	check("startzwaard telt mee", int(early[0]["atk"]) == 38 and int(early[0]["hp"]) == 105)
	check("vuur, bliksem en genees houden mp en power", int(PvpSpells.SPELLS["vuur"]["mp"]) == 4 and int(PvpSpells.SPELLS["vuur"]["power"]) == 14 and int(PvpSpells.SPELLS["bliksem"]["mp"]) == 7 and int(PvpSpells.SPELLS["bliksem"]["power"]) == 9 and int(PvpSpells.SPELLS["genees"]["mp"]) == 3 and int(PvpSpells.SPELLS["genees"]["power"]) == 22)
	var built := true
	for mode_id in PvpModes.ORDER:
		for team_id in PvpTeams.ORDER:
			var side := PvpRoster.build_side("guest", team_id, mode_id)
			if side.size() != 3:
				built = false
			var uids := {}
			for raw in side:
				var row: Dictionary = raw
				if int(row["hp"]) <= 0 or uids.has(row["uid"]):
					built = false
				uids[row["uid"]] = true
	check("elke modus en elk team levert drie levende vechters", built)
	var attack := PvpRoster.build_side("host", "team_aanval", "early")
	check("twee Dennis zijn aparte vechters", str(attack[0]["uid"]) == "host:dennis" and str(attack[1]["uid"]) == "host:dennis_2")
	attack[0]["items"]["drankje"] = 0
	check("dubbele vechters delen geen tas", int(attack[1]["items"]["drankje"]) == 2)


func _rule_tests() -> void:
	check("schade 30 aanval tegen 10 verdediging is 25", PvpRules.physical_damage(30, 10, 1.0, 1.0, false) == 25)
	check("verdedigen halveert die 25 naar 12", PvpRules.physical_damage(30, 10, 1.0, 1.0, true) == 12)
	check("vermenigvuldiging telt mee", PvpRules.physical_damage(10, 0, 2.0, 1.0, false) == 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var rolled := PvpRules.roll_variance(rng)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99
	var rolled_b := PvpRules.roll_variance(rng_b)
	var open_dmg := PvpRules.physical_damage(40, 8, 1.0, rolled, false)
	var shut_dmg := PvpRules.physical_damage(40, 8, 1.0, rolled, true)
	check("vaste rng geeft dezelfde spreiding", is_equal_approx(rolled, rolled_b) and rolled >= 0.85 and rolled <= 1.15)
	check("verdedigen halveert de gerolde schade", shut_dmg == maxi(1, int(float(open_dmg) / 2.0)))
	check("spreukbedrag is power plus twee keer level", PvpRules.spell_amount(14, 8) == 30 and PvpRules.spell_damage(14, 8) == 30 and PvpRules.spell_heal(22, 8) == 38 and PvpRules.spell_amount(9, 8) == 25)
	var order := PvpRules.turn_order([
		{"uid": "slow", "agi": 5, "seat": "host", "index": 0, "hp": 10},
		{"uid": "guest_fast", "agi": 11, "seat": "guest", "index": 0, "hp": 10},
		{"uid": "host_second", "agi": 11, "seat": "host", "index": 1, "hp": 10},
		{"uid": "host_first", "agi": 11, "seat": "host", "index": 0, "hp": 10},
		{"uid": "dead", "agi": 99, "seat": "host", "index": 2, "hp": 0},
	])
	check("beurtvolgorde is AGI, dan host, dan index", order == ["host_first", "host_second", "guest_fast", "slow"])
	var down := [
		{"seat": "host", "hp": 4},
		{"seat": "guest", "hp": 0},
	]
	var up := [
		{"seat": "host", "hp": 0},
		{"seat": "guest", "hp": 3},
	]
	check("geen levende gast betekent winst voor de host", PvpRules.winner_seat(down) == "host")
	check("geen levende host betekent verlies", PvpRules.winner_seat(up) == "guest")


func _battle_tests() -> void:
	var power_genees := int(PvpSpells.SPELLS["genees"]["power"])
	var power_vuur := int(PvpSpells.SPELLS["vuur"]["power"])
	var heal_item := int(PvpItems.ITEMS["drankje"]["heal_hp"])
	var battle := PvpBattleState.new()
	battle.setup(PvpRoster.build_side("host", "team_verdediging", "early"), PvpRoster.build_side("guest", "team_aanval", "early"), 11)
	var lotte := ""
	var ally := ""
	for raw in battle.fighters:
		var row: Dictionary = raw
		if str(row["seat"]) != "host":
			continue
		if str(row["character_id"]) == "lotte" and str(row["display"]) == "Lotte":
			lotte = str(row["uid"])
		elif ally == "" and int(row["hp"]) > 0:
			ally = str(row["uid"])
			row["hp"] = 10
	battle.order = [lotte]
	battle.turn_i = 0
	var before_hp := int(battle.fighter(ally)["hp"])
	var healed := battle.apply_action(lotte, "spell", ally, "genees", "")
	check("genees werkt", bool(healed["ok"]) and int(battle.fighter(ally)["hp"]) > before_hp)
	var vuur_battle := PvpBattleState.new()
	vuur_battle.setup(PvpRoster.build_side("host", "team_klassiek", "early"), PvpRoster.build_side("guest", "team_klassiek", "early"), 12)
	var noor := ""
	for raw in vuur_battle.fighters:
		var caster: Dictionary = raw
		if str(caster["seat"]) == "host" and str(caster["character_id"]) == "noor":
			noor = str(caster["uid"])
	vuur_battle.order = [noor]
	vuur_battle.turn_i = 0
	var foe := vuur_battle.first_living_enemy(noor)
	var foe_before := int(vuur_battle.fighter(foe)["hp"])
	var burned := vuur_battle.apply_action(noor, "spell", foe, "vuur", "")
	check("vuur doet schade", bool(burned["ok"]) and int(vuur_battle.fighter(foe)["hp"]) == foe_before - PvpRules.spell_amount(14, 8))
	check("spreuken en drankjes blijven ongewijzigd", int(PvpSpells.SPELLS["genees"]["power"]) == power_genees and int(PvpSpells.SPELLS["vuur"]["power"]) == power_vuur and int(PvpItems.ITEMS["drankje"]["heal_hp"]) == heal_item)
	var finish := PvpBattleState.new()
	finish.setup(PvpRoster.build_side("host", "team_klassiek", "early"), PvpRoster.build_side("guest", "team_klassiek", "early"), 13)
	for raw in finish.fighters:
		var foe_row: Dictionary = raw
		if str(foe_row["seat"]) == "guest":
			foe_row["hp"] = 1
			foe_row["def"] = 0
	var guard := 0
	while not finish.over and guard < 30:
		var actor := finish.current_uid()
		var target := finish.first_living_enemy(actor)
		finish.fighter(actor)["atk"] = 400
		var step: Dictionary = finish.apply_action(actor, "attack", target, "", "")
		if not bool(step["ok"]):
			break
		guard += 1
	check("een kant op 0 HP beslist het gevecht", finish.over and finish.winner == "host")


func _net_tests() -> void:
	PvpLocalTransport.clear_hub()
	var host := PvpSession.new()
	var guest := PvpSession.new()
	add_child(host)
	add_child(guest)
	check("host krijgt een code", host.begin_host("local") and host.code.length() == 6)
	check("ongeldige code faalt", not guest.begin_join("local", "K7NP2O") and guest.phase == "menu")
	var wrong := "222222" if host.code != "222222" else "333333"
	check("verkeerde code verbindt niet", not guest.begin_join("local", wrong) and guest.phase == "menu")
	check("juiste code verbindt", guest.begin_join("local", host.code) and host.phase == "mode_select" and guest.phase == "mode_select")
	check("gast zet de modus niet", not guest.choose_mode("high") and guest.mode_id == "")
	guest.transport.send({"t": "mode", "from": "guest", "mode": "high"})
	check("vals modusbericht blijft liggen", host.mode_id == "")
	var starts := {"n": 0}
	host.battle_started.connect(func() -> void: starts["n"] = int(starts["n"]) + 1)
	check("host kiest vroeg", host.choose_mode("early") and guest.mode_id == "early")
	check("één team start nog niet", host.choose_team("team_klassiek") and int(starts["n"]) == 0 and host.phase == "team_select")
	check("beide teams starten het gevecht", guest.choose_team("team_klassiek") and int(starts["n"]) == 1 and host.phase == "battle" and guest.phase == "battle")
	var uid := host.battle.current_uid()
	var actor := host.battle.fighter(uid)
	var target := host.battle.first_living_enemy(uid)
	var target_before := int(host.battle.fighter(target)["hp"])
	var acted := false
	if str(actor["seat"]) == "host":
		acted = host.submit_action(uid, "attack", target, {})
	else:
		acted = guest.submit_action(uid, "attack", target, {})
	check("aanval haalt HP weg", acted and int(host.battle.fighter(target)["hp"]) < target_before)
	check("beide zetels zien dezelfde HP", _hp_sig(host) == _hp_sig(guest))
	var fought := _scripted_fight(host, guest)
	var result: Dictionary = host.last_result
	var hp: Array = result.get("hp", [])
	check("gespeeld gevecht heeft een winnaar en HP", fought and (str(result.get("winner", "")) == "host" or str(result.get("winner", "")) == "guest") and hp.size() == 6)
	check("gast ziet dezelfde uitslag", guest.phase == "result" and str(guest.last_result.get("winner", "")) == str(result.get("winner", "")) and _hp_sig(host) == _hp_sig(guest))
	host.rematch()
	var restored := host.phase == "battle" and guest.phase == "battle"
	for raw in host.battle.fighters:
		var row: Dictionary = raw
		if int(row["hp"]) != int(row["max_hp"]):
			restored = false
	for raw in guest.battle.fighters:
		var guest_row: Dictionary = raw
		if int(guest_row["hp"]) != int(guest_row["max_hp"]):
			restored = false
	check("rematch houdt modus en teams en vult HP", restored and host.mode_id == "early" and host.host_team == "team_klassiek" and guest.guest_team == "team_klassiek")
	check("tweede gevecht eindigt weer", _scripted_fight(host, guest))
	var kept_code := host.code
	host.rechoose()
	check("opnieuw kiezen gaat naar teamkeuze", host.phase == "team_select" and guest.phase == "team_select" and host.mode_id == "early" and host.host_team == "" and guest.guest_team == "" and host.code == kept_code and guest.code == kept_code)
	check("nieuwe teams starten opnieuw", host.choose_team("team_aanval") and guest.choose_team("team_verdediging") and host.phase == "battle" and guest.phase == "battle")
	host.stop_match()
	check("stoppen gaat naar het menu", host.phase == "menu" and guest.phase == "menu" and PvpLocalTransport.live_host == null)
	host.queue_free()
	guest.queue_free()


func _disconnect_tests() -> void:
	PvpLocalTransport.clear_hub()
	var host := PvpSession.new()
	var guest := PvpSession.new()
	add_child(host)
	add_child(guest)
	host.begin_host("local")
	guest.begin_join("local", host.code)
	host.choose_mode("early")
	host.choose_team("team_klassiek")
	guest.choose_team("team_aanval")
	var before := _user_saves()
	var guest_heard := {"text": ""}
	guest.disconnected.connect(func(text: String) -> void: guest_heard["text"] = text)
	host.force_disconnect()
	var after := _user_saves()
	check("verbreken zet de fase op menu", host.phase == "menu" and guest.phase == "menu")
	check("gast hoort dat het gevecht weg is", str(guest_heard["text"]) == PvpDisconnect.match_gone_message())
	check("verbreken schrijft geen save", before == after)
	check("sessie heeft geen save-methode", not host.has_method("save") and not host.has_method("save_game") and not guest.has_method("save"))
	var heard := {"text": ""}
	host.disconnected.connect(func(text: String) -> void: heard["text"] = text)
	host.request_reconnect()
	check("host zonder sessie zegt dat het gevecht weg is", str(heard["text"]) == PvpDisconnect.match_gone_message() and host.phase == "menu")
	host.queue_free()
	guest.queue_free()


func _action_tests() -> void:
	PvpLocalTransport.clear_hub()
	var host := PvpSession.new()
	var guest := PvpSession.new()
	add_child(host)
	add_child(guest)
	host.begin_host("local")
	var kept := host.code
	guest.begin_join("local", kept)
	host.choose_mode("early")
	host.choose_team("team_klassiek")
	guest.choose_team("team_klassiek")
	var uid := host.battle.current_uid()
	var guest_before := {}
	for raw in host.battle.fighters:
		var row: Dictionary = raw
		if str(row["seat"]) == "guest":
			guest_before[str(row["uid"])] = int(row["hp"])
	var bolt := host.submit_action(uid, "spell", "", {"spell": "bliksem"})
	var bolt_amt := PvpRules.spell_amount(9, 8)
	var bolt_ok := bolt and uid == "host:noor"
	for key in guest_before.keys():
		if int(host.battle.fighter(str(key))["hp"]) != int(guest_before[key]) - bolt_amt:
			bolt_ok = false
	check("bliksem raakt alle tegenstanders", bolt_ok and _hp_sig(host) == _hp_sig(guest))
	uid = host.battle.current_uid()
	var dennis_before := int(host.battle.fighter("host:dennis")["hp"])
	var noor_before := int(host.battle.fighter("host:noor")["hp"])
	var fire := guest.submit_action(uid, "spell", "host:dennis", {"spell": "vuur"})
	var fire_amt := PvpRules.spell_amount(14, 8)
	check("vuur raakt één doel", fire and uid == "guest:noor" and int(host.battle.fighter("host:dennis")["hp"]) == dennis_before - fire_amt and int(host.battle.fighter("host:noor")["hp"]) == noor_before and _hp_sig(host) == _hp_sig(guest))
	uid = host.battle.current_uid()
	var guarded := host.submit_action(uid, "defend", "", {})
	check("verdedigen staat aan", guarded and uid == "host:dennis" and bool(host.battle.fighter("host:dennis")["defending"]))
	uid = host.battle.current_uid()
	var atk := int(host.battle.fighter("guest:dennis")["atk"])
	var defense := int(host.battle.fighter("host:dennis")["def"])
	var hp_before := int(host.battle.fighter("host:dennis")["hp"])
	var hit := guest.submit_action(uid, "attack", "host:dennis", {})
	var variance := host.battle.last_variance
	var shut := PvpRules.physical_damage(atk, defense, 1.0, variance, true)
	var open_dmg := PvpRules.physical_damage(atk, defense, 1.0, variance, false)
	var dealt := hp_before - int(host.battle.fighter("host:dennis")["hp"])
	check("verdedigen halveert de volgende klap", hit and uid == "guest:dennis" and dealt == shut and shut == maxi(1, int(float(open_dmg) / 2.0)) and _hp_sig(host) == _hp_sig(guest))
	uid = host.battle.current_uid()
	var wounded := int(host.battle.fighter("host:dennis")["hp"])
	var bag_before := int(host.battle.fighter("host:lotte")["items"]["drankje"])
	var sipped := host.submit_action(uid, "item", "host:dennis", {"item": "drankje"})
	var healed_hp := int(host.battle.fighter("host:dennis")["hp"])
	var cap := int(host.battle.fighter("host:dennis")["max_hp"])
	var bag_after := int(host.battle.fighter("host:lotte")["items"]["drankje"])
	check("drankje heelt", sipped and uid == "host:lotte" and healed_hp == mini(cap, wounded + 30) and healed_hp > wounded and bag_after == bag_before - 1 and _hp_sig(host) == _hp_sig(guest))
	var fought := _scripted_fight(host, guest)
	var result: Dictionary = host.last_result
	var rows: Array = result.get("hp", [])
	var winner := str(result.get("winner", ""))
	check("gespeeld tot een kant valt", fought and (winner == "host" or winner == "guest") and rows.size() == 6)
	guest.force_disconnect()
	check("host blijft op de uitslag", host.phase == "result" and host.code == kept and str(host.last_result.get("winner", "")) == winner)
	check("gast komt terug op de uitslag", guest.request_reconnect() and guest.phase == "result" and str(guest.last_result.get("winner", "")) == winner and _hp_sig(host) == _hp_sig(guest))
	host.rematch()
	var fresh := host.phase == "battle" and guest.phase == "battle" and host.mode_id == "early" and host.host_team == "team_klassiek" and guest.guest_team == "team_klassiek"
	fresh = fresh and int(host.battle.fighter("host:dennis")["hp"]) == int(host.battle.fighter("host:dennis")["max_hp"])
	fresh = fresh and int(host.battle.fighter("host:lotte")["items"]["drankje"]) == 2
	check("rematch is een nieuw gevecht", fresh and host.code == kept)
	check("rematch eindigt weer", _scripted_fight(host, guest))
	host.rechoose()
	check("opnieuw kiezen houdt de code", host.phase == "team_select" and guest.phase == "team_select" and host.code == kept and guest.code == kept and host.mode_id == "early" and host.host_team == "" and guest.guest_team == "")
	host.stop_match()
	host.queue_free()
	guest.queue_free()


func _reconnect_tests() -> void:
	PvpLocalTransport.clear_hub()
	var host := PvpSession.new()
	var guest := PvpSession.new()
	add_child(host)
	add_child(guest)
	host.begin_host("local")
	var code := host.code
	var unknown := {"text": ""}
	var stranger := PvpSession.new()
	add_child(stranger)
	stranger.error_message.connect(func(text: String) -> void: unknown["text"] = text)
	var bad_code := "222222" if code != "222222" else "333333"
	check("onbekende code is weg", not stranger.begin_join("local", bad_code) and stranger.phase == "menu" and str(unknown["text"]) == PvpDisconnect.match_gone_message())
	check("juiste code blijft", host.phase == "wait_peer" and host.code == code)
	stranger.queue_free()
	guest.begin_join("local", code)
	var left := {"text": ""}
	host.guest_dropped.connect(func(text: String) -> void: left["text"] = text)
	guest.force_disconnect()
	check("gast weg, host blijft in de moduskeuze", host.phase == "mode_select" and host.code == code and PvpLocalTransport.live_host != null and str(left["text"]) == PvpDisconnect.guest_left_message())
	check("gast onthoudt de code", guest.reconnect_code == code and guest.phase == "menu")
	check("gast komt terug in de moduskeuze", guest.request_reconnect() and guest.phase == "mode_select" and host.phase == "mode_select" and guest.code == code)
	host.choose_mode("early")
	host.choose_team("team_klassiek")
	guest.force_disconnect()
	check("team van de host blijft staan", host.phase == "team_select" and host.host_team == "team_klassiek" and host.mode_id == "early" and host.code == code)
	check("gast komt terug bij de teamkeuze", guest.request_reconnect() and guest.phase == "team_select" and guest.mode_id == "early" and guest.host_team == "team_klassiek" and guest.guest_team == "")
	var extra := PvpSession.new()
	add_child(extra)
	var busy := {"text": ""}
	extra.error_message.connect(func(text: String) -> void: busy["text"] = text)
	check("tweede gast mag niet", not extra.begin_join("local", code) and str(busy["text"]) == PvpDisconnect.occupied_message() and guest.phase == "team_select")
	extra.queue_free()
	check("gast kiest alsnog een team", guest.choose_team("team_aanval") and host.phase == "battle" and guest.phase == "battle")
	var sig := _hp_sig(host)
	var turn := host.battle.current_uid()
	guest.force_disconnect()
	check("gevecht blijft bij de host", host.phase == "battle" and host.code == code and _hp_sig(host) == sig and host.battle.current_uid() == turn)
	check("gast krijgt het gevecht terug", guest.request_reconnect() and guest.phase == "battle" and guest.battle.current_uid() == turn and _hp_sig(guest) == sig)
	var actor := host.battle.fighter(turn)
	var target := host.battle.first_living_enemy(turn)
	var before_hp := int(host.battle.fighter(target)["hp"])
	var acted := false
	if str(actor["seat"]) == "host":
		acted = host.submit_action(turn, "attack", target, {})
	else:
		acted = guest.submit_action(turn, "attack", target, {})
	check("na terugkomst gaat het gevecht verder", acted and int(host.battle.fighter(target)["hp"]) < before_hp and _hp_sig(host) == _hp_sig(guest))
	guest.force_disconnect()
	host.abandon()
	var gone := {"text": ""}
	guest.disconnected.connect(func(text: String) -> void: gone["text"] = text)
	guest.error_message.connect(func(text: String) -> void: gone["text"] = text)
	check("dode host is weg", not guest.request_reconnect() and guest.phase == "menu" and str(gone["text"]) == PvpDisconnect.match_gone_message())
	check("oude zin wordt niet gebruikt", str(gone["text"]) != "Opnieuw verbinden is nog niet beschikbaar.")
	host.queue_free()
	guest.queue_free()


func _lan_tests() -> void:
	# Eén proces, geen tweede apparaat. Broadcast naar 255.255.255.255 komt op
	# dezelfde machine vaak niet terug, dus de live-check gebruikt join_ip
	# naar 127.0.0.1. De code-match van het baken blijft een pure parse.
	var good := JSON.stringify({"game": "sapientia-pvp", "code": "K7NP2Q", "port": 7777}).to_utf8_buffer()
	var other := JSON.stringify({"game": "sapientia-pvp", "code": "222222", "port": 7777}).to_utf8_buffer()
	check("baken met de code geeft poort 7777", PvpLanTransport.parse_beacon(good, "K7NP2Q") == 7777)
	check("baken met een andere code telt niet", PvpLanTransport.parse_beacon(good, "222222") == -1 and PvpLanTransport.parse_beacon(other, "K7NP2Q") == -1)
	check("rommel is geen baken", PvpLanTransport.parse_beacon("geen-json".to_utf8_buffer(), "K7NP2Q") == -1)
	var bare := PvpLanTransport.new()
	add_child(bare)
	await get_tree().process_frame
	check("lan-transport zonder gebruik crasht niet", is_instance_valid(bare) and not bare.is_failed())
	check("lan luistert op 7777 en bakent op 7778", PvpLanTransport.PORT == 7777 and PvpLanTransport.BEACON_PORT == 7778)
	bare.queue_free()
	await get_tree().process_frame
	var host := PvpSession.new()
	var guest := PvpSession.new()
	add_child(host)
	add_child(guest)
	var notes: Array = []
	host.error_message.connect(func(text: String) -> void: notes.append(text))
	var hosted := host.begin_host("lan")
	if not hosted:
		check("lan-host maakt een code zonder te crashen", false)
		check("lan-fout blijft in het menu", host.phase == "menu" and notes.size() > 0)
		host.queue_free()
		guest.queue_free()
		return
	check("lan-host maakt een code zonder te crashen", host.code.length() == 6 and host.phase == "wait_peer")
	var joined := guest.begin_join("lan", host.code, "127.0.0.1")
	var guest_in := await _wait_phase(guest, "mode_select", 120)
	var host_in := await _wait_phase(host, "mode_select", 30)
	check("lan op localhost verbindt in dit proces", joined and guest_in and host_in)
	if guest_in and host_in:
		host.choose_mode("mid")
		var mode_ok := await _wait_mode(guest, "mid", 60)
		check("lan stuurt de modus door", mode_ok and guest.mode_id == "mid")
		var lan_code := host.code
		guest.force_disconnect()
		var host_stays := await _wait_flag(host, 60)
		check("lan-host blijft na vertrek van de gast", host_stays and host.phase == "team_select" and host.code == lan_code and host.mode_id == "mid")
		var again := guest.begin_join("lan", lan_code, "127.0.0.1")
		var back := await _wait_phase(guest, "team_select", 120)
		check("lan-gast komt terug in de teamkeuze", again and back and guest.mode_id == "mid" and guest.code == lan_code)
	host.abandon()
	guest.abandon()
	await get_tree().process_frame
	check("lan-sessie staat daarna in het menu", host.phase == "menu" and guest.phase == "menu")
	host.queue_free()
	guest.queue_free()


func _source_tests() -> void:
	var files: Array = []
	_collect("res://pvp", files)
	var needle_a := "Game" + "State"
	var needle_b := "Game" + "Data"
	var needle_c := "pre" + "load(\"" + "res://scri" + "pts/"
	var needle_d := "pre" + "load(\"" + "res://sce" + "nes/"
	var bad: Array = []
	var save_bad: Array = []
	for path in files:
		var text := FileAccess.get_file_as_string(str(path))
		if text.find(needle_a) >= 0 or text.find(needle_b) >= 0 or text.find(needle_c) >= 0 or text.find(needle_d) >= 0:
			bad.append(path)
		if str(path).ends_with("pvp_tests.gd"):
			continue
		if text.find("user://") >= 0:
			save_bad.append(path)
		if text.find("Opnieuw verbinden is nog niet beschikbaar.") >= 0:
			save_bad.append(path)
	check("pvp-scripts noemen het hoofdspel niet", bad.is_empty())
	check("pvp-scripts schrijven geen user-pad", save_bad.is_empty())
	check("lobby is de ingang", ResourceLoader.exists("res://pvp/scenes/pvp_lobby.tscn"))


func _ui_tests() -> void:
	PvpLocalTransport.clear_hub()
	var lobby := (load("res://pvp/scenes/pvp_lobby.tscn") as PackedScene).instantiate() as PvpLobby
	add_child(lobby)
	await get_tree().process_frame
	var left := {"n": 0}
	lobby.leave_requested.connect(func() -> void: left["n"] = 1)
	var host_btn := _find_button(lobby, "Host", true)
	check("menu toont Host", host_btn != null)
	check("aanraakvlak is hoog genoeg", host_btn != null and host_btn.custom_minimum_size.y >= 22)
	check("Terug meldt sluiten zonder de titel aan te raken", _press(lobby, "Back", true) and int(left["n"]) == 1)
	check("host kiest het apparaat", _press(lobby, "Host", true) and _press(lobby, "Same device", true))
	var edit := _find_line(lobby)
	check("code staat op het scherm", edit != null and lobby.host_session.code.length() == 6)
	if edit != null:
		edit.text = lobby.host_session.code
	check("tweede speler verbindt", _press(lobby, "Connect", true))
	await get_tree().process_frame
	check("host kiest Vroeg", _press(lobby, "Vroeg", false))
	await get_tree().process_frame
	check("speler 1 kiest Klassiek", _press(lobby, "De Klassieke Drie", true))
	check("apparaat gaat naar speler 2", _label_has(lobby, "Pass the device on"))
	check("speler 2 kiest hetzelfde team", _press(lobby, "De Klassieke Drie", true))
	await get_tree().process_frame
	check("banner noemt de beurt", _label_has(lobby, "'s turn"))
	var attack := _find_button(lobby, "Attack", true)
	check("acties staan naast elkaar", attack != null and attack.get_parent() is HBoxContainer and attack.custom_minimum_size.y >= 22)
	check("alle acties zijn leesbaar", _find_button(lobby, "Magic", true) != null and _find_button(lobby, "Defend", true) != null and _find_button(lobby, "Item", true) != null)
	var before := _hp_sig(lobby.host_session)
	check("aanval opent doelen", _press(lobby, "Attack", true))
	var target := _find_target(lobby)
	var clicked := false
	if target != null:
		target.pressed.emit()
		clicked = true
	await get_tree().process_frame
	check("ui-aanval synchroniseert", clicked and _hp_sig(lobby.host_session) != before and _hp_sig(lobby.host_session) == _hp_sig(lobby.guest_session))
	lobby.host_session.abandon()
	lobby.guest_session.abandon()
	lobby.queue_free()


func _wait_phase(session: PvpSession, wanted: String, frames: int) -> bool:
	var i := 0
	while i < frames:
		if session.phase == wanted:
			return true
		await get_tree().process_frame
		i += 1
	return session.phase == wanted


func _wait_mode(session: PvpSession, mode_id: String, frames: int) -> bool:
	var i := 0
	while i < frames:
		if session.mode_id == mode_id:
			return true
		await get_tree().process_frame
		i += 1
	return session.mode_id == mode_id


func _wait_flag(host: PvpSession, frames: int) -> bool:
	var i := 0
	while i < frames:
		if not host.guest_online:
			return true
		await get_tree().process_frame
		i += 1
	return not host.guest_online


func _scripted_fight(host: PvpSession, guest: PvpSession) -> bool:
	var guard := 0
	while host.phase == "battle" and guard < 400:
		var battle := host.battle
		if battle == null or battle.over:
			break
		var uid := battle.current_uid()
		if uid == "":
			return false
		var actor := battle.fighter(uid)
		var target := battle.first_living_enemy(uid)
		if target == "":
			return false
		var ok := false
		if str(actor.get("seat", "")) == "host":
			ok = host.submit_action(uid, "attack", target, {})
		else:
			ok = guest.submit_action(uid, "attack", target, {})
		if not ok:
			return false
		guard += 1
	return host.phase == "result"


func _hp_sig(session: PvpSession) -> String:
	if session.battle == null:
		return ""
	var parts := PackedStringArray()
	for raw in session.battle.hp_list():
		var row: Dictionary = raw
		parts.append("%s:%d" % [str(row["uid"]), int(row["hp"])])
	return "|".join(parts)


func _user_saves() -> Array:
	var names: Array = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return names
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


func _collect(dir_path: String, into: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full := dir_path + "/" + file_name
			if dir.current_is_dir():
				_collect(full, into)
			elif file_name.ends_with(".gd"):
				into.append(full)
		file_name = dir.get_next()
	dir.list_dir_end()


func _press(root: Node, text: String, exact: bool) -> bool:
	var btn := _find_button(root, text, exact)
	if btn == null:
		return false
	btn.pressed.emit()
	return true


func _find_button(node: Node, text: String, exact: bool) -> Button:
	if node is Button:
		var btn := node as Button
		var hit := btn.text == text if exact else btn.text.find(text) >= 0
		if hit and _shown(btn):
			return btn
	for child in node.get_children():
		var found := _find_button(child, text, exact)
		if found != null:
			return found
	return null


func _find_line(node: Node) -> LineEdit:
	if node is LineEdit:
		var edit := node as LineEdit
		if _shown(edit):
			return edit
	for child in node.get_children():
		var found := _find_line(child)
		if found != null:
			return found
	return null


func _find_target(node: Node) -> Button:
	if node is Button:
		var btn := node as Button
		var skip := btn.text == "Attack" or btn.text == "Magic" or btn.text == "Defend" or btn.text == "Item" or btn.text == "Back"
		if not skip and _shown(btn) and _has_digit(btn.text):
			return btn
	for child in node.get_children():
		var found := _find_target(child)
		if found != null:
			return found
	return null


func _has_digit(text: String) -> bool:
	for ch in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		if text.find(ch) >= 0:
			return true
	return false


func _label_has(node: Node, text: String) -> bool:
	if node is Label:
		var row := node as Label
		if _shown(row) and row.text.find(text) >= 0:
			return true
	for child in node.get_children():
		if _label_has(child, text):
			return true
	return false


func _shown(ctrl: Control) -> bool:
	if ctrl.is_queued_for_deletion():
		return false
	var current: Node = ctrl
	while current is Control:
		if not (current as Control).visible:
			return false
		current = current.get_parent()
	return true
