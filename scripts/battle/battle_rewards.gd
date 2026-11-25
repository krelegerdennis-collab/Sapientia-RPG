extends RefCounted
## EXP, goud, buit en overwinningspagina's (uit battle.gd gehaald, gedrag ongewijzigd).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const GameData := preload("res://scripts/data/game_data.gd")
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Dungeon100Blue := preload("res://scripts/data/dungeon100_blue.gd")
const KamerData := preload("res://world_warper/kamers/kamers.gd")

var battle: Control


func _init(b: Control) -> void:
	battle = b


## Overwinning: groot doorzichtig venster over het slagveld (zoals Lufia 2).
## Pagina 1: EXP, goud en per held hoeveel EXP er nog nodig is voor het
## volgende level. Daarna één pagina per held die een level omhoog gaat.
func victory() -> void:
	# Vijanden die buiten _report_kos vielen (bv. door een status-tick) tellen ook als verslagen.
	for e in battle.enemies:
		if int(e["s"]["hp"]) <= 0 and not e.get("reported_ko", false):
			e["reported_ko"] = true
			GameState.mark_defeated(str(e.get("id", "")))
	var practice := GameState.practice_battle
	var exp_total := 0
	var gold_total := 0
	var book_lines: Array = []
	var loot_page := ""
	if practice:
		var buit := KamerData.toegepaste_buit(true, 0, 0)
		exp_total = buit.x
		gold_total = buit.y
	else:
		for e in battle.enemies:
			if e.get("captured", false):
				continue   # Codex: ingeschreven monsters geven geen EXP/goud
			exp_total += int(e["s"]["exp"])
			gold_total += int(e["s"]["gold"])
		GameState.add_gold(gold_total)
		book_lines = grant_fixed_boss_drops()
		loot_page = dungeon100_boss_loot()
	await battle._wait(0.3)
	# EXP uitdelen (alleen helden die nog staan), level-ups onthouden
	var level_pages: Array[String] = []
	if not practice:
		for h in battle._alive(battle.heroes):
			if h.get("ally", false):
				continue   # Codex: de bondgenoot krijgt zijn EXP hieronder (codex.victory_exp)
			var s: Dictionary = h["s"]
			var before: Dictionary = s.duplicate()
			var msgs := GameState.give_exp(s, exp_total)
			if msgs.is_empty():
				continue
			var gains := "HP+%d" % (s["max_hp"] - before["max_hp"])
			if s["max_mp"] > before["max_mp"]:
				gains += " MP+%d" % (s["max_mp"] - before["max_mp"])
			gains += " ATK+%d DEF+%d AGI+%d" % [s["atk"] - before["atk"], s["def"] - before["def"], s["agi"] - before["agi"]]
			level_pages.append("%s\n%s" % [msgs[msgs.size() - 1], gains])
		level_pages.append_array(battle.codex.victory_exp(exp_total))
		if loot_page != "":
			level_pages.append(loot_page)
	battle._refresh_party()
	battle.caption.hide()
	if practice:
		battle.victory_label.text = KamerData.OEFEN_KLAAR
	else:
		battle.victory_label.text = battle.victory_text(exp_total, gold_total, book_lines)
	# Venster precies zo hoog als de tekst, zodat de helden eronder zichtbaar blijven.
	battle.victory_panel.offset_bottom = battle.victory_panel.offset_top + battle.victory_panel.get_combined_minimum_size().y
	battle.victory_panel.show()
	await victory_page(battle.victory_label.text)
	for page in level_pages:
		await victory_page(page)
	await GameState.end_battle("win")


## Vaste baasbuit ("n" in drops) van het Eerste Archief. Niet in de 100-verdiepingen-kerker
## (die heeft een eigen buit) en niet voor een gevangen of nog levend monster.
## Geeft de regels voor het overwinningsvenster (leeg = niets).
func grant_fixed_boss_drops() -> Array:
	if not GameState.pending_boss or GameState.dungeon100_floor > 0:
		return []
	var totals := {}
	var names := {}
	for e in battle.enemies:
		if e.get("captured", false) or int(e["s"].get("hp", 0)) > 0:
			continue
		for d in GameData.fixed_drops(e["s"].get("drops", [])):
			var id := str(d["item"])
			totals[id] = int(totals.get(id, 0)) + int(d["n"])
			names[id] = str(d["name"])
	var lines: Array = []
	for id in totals:
		GameState.add_item(id, int(totals[id]))
		lines.append("Got %dx %s." % [int(totals[id]), names[id]])
	return lines


## Task #4: na een baas in de dungeon van 100 verdiepingen: de gegarandeerde buit in de tas (en het
## goud erbij), de baasvlag zetten. Geeft de tekst van de buitpagina ("" = geen baasbuit).
func dungeon100_boss_loot() -> String:
	var floor_nr: int = GameState.dungeon100_floor
	if floor_nr <= 0 or not GameState.pending_boss:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var loot := Dungeon100Blue.with_warp(Dungeon100Scaling.boss_loot(floor_nr, rng), floor_nr)    # eindbaas: + Warp-kristal
	GameState.add_gold(GameState.grant_loot_items(loot))
	GameState.story_flags[Dungeon100Scaling.boss_flag(floor_nr)] = true
	return "Boss loot!\n" + "\n".join(Dungeon100Scaling.loot_lines(loot))


func victory_page(text: String) -> void:
	battle.victory_label.text = text
	battle._set_state(battle.ST_MESSAGE_WAIT)
	battle._message_tapped = false
	await battle.get_tree().process_frame      # de tik die het vorige venster sloot telt niet mee
	battle._message_tapped = false
	var arrow: Control = battle.victory_panel.get_node("VictoryArrow")
	var t := 0.0
	while true:
		await battle.get_tree().process_frame
		t += battle.get_process_delta_time()
		arrow.visible = fmod(t, 0.8) < 0.5     # knipperend pijltje = tik of druk op A
		if Input.is_action_just_pressed("interact") or battle._message_tapped:
			break
	arrow.hide()
	battle._set_state(battle.ST_BUSY)