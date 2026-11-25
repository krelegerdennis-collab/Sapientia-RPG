extends RefCounted
## Commando-keuze en submenu's (uit battle.gd gehaald, gedrag ongewijzigd).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests roepen die).

const GameData := preload("res://scripts/data/game_data.gd")
const CodexDataScript := preload("res://scripts/data/codex_data.gd")

var battle  # scripts/battle/battle.gd root (geen class_name)


func _init(b) -> void:
	battle = b


# ---------------------------------------------------------------- ronde: helden langs
func next_alive_hero(from: int) -> int:
	for j in range(from + 1, battle.heroes.size()):
		if battle.heroes[j]["s"]["hp"] > 0 and not battle.heroes[j].get("ally", false):
			return j
	return battle.heroes.size()


func prev_alive_hero(from: int) -> int:
	for j in range(from - 1, -1, -1):
		if battle.heroes[j]["s"]["hp"] > 0 and not battle.heroes[j].get("ally", false):
			return j
	return -1


## De held die kiest stapt naar voren, de rest staat op zijn plek.
func set_active_hero(i: int) -> void:
	battle.current_hero = i
	if i >= 0:
		battle._place_menu(i, true)
	for j in battle.hero_nodes.size():
		var node: Control = battle.hero_nodes[j]
		var forward: bool = j == i
		if node.stepped_forward != forward or (forward and node.pose != "klaar"):
			node.step(forward)
	battle._refresh_party()


func choose_for_hero(hero: Dictionary, can_go_back: bool):
	var last := 0          # na 'terug' uit een submenu/doelkeuze staat het kruis weer daar
	while true:
		battle._set_state(battle.ST_COMMAND)
		battle.show_message("What will %s do?" % hero["name"])
		battle._show_tip(hero)
		var allowed := [
			true,
			not hero["s"]["spells"].is_empty() or not battle._kern_skills(hero).is_empty(),   # v0.15: + kern
			not available_items().is_empty(),
			true,
			battle.tutorial.is_empty() and battle.can_flee,   # oefengevecht / baas (v0.15): niet vluchten
			items_left(CodexDataScript.BOOK_ITEM) > 0 or battle.codex.can_swap(),   # v0.19 Codex
		]
		battle.cross.open(hero["name"], allowed, last, can_go_back, [] if codex_command_shown() else [battle.COMMANDS.size() - 1])
		var cmd: int = await battle.cross.finished
		if cmd == 1 and not has_usable_magic(hero) and battle._kern_skills(hero).is_empty():
			# Demo-fix 1: spreuken maar geen MP / niets te kiezen — geen submenu (soft-lock voorkomen).
			# Met kernvaardigheden altijd choose_spell: laad-regels staan uitgegrijsd (kerntest).
			show_notice("No spells yet")
			last = 0
			continue
		battle.cross.deactivate()
		last = maxi(cmd, 0)
		match cmd:
			-1:
				return null
			0:
				var t = await select_enemy()
				if t != null:
					return {"type": "attack", "actor": hero, "target": t}
			1:
				var s = await choose_spell(hero)
				if s != null:
					return s
			2:
				var it = await choose_item(hero)
				if it != null:
					return it
			3:
				return {"type": "defend", "actor": hero}
			4:
				return {"type": "flee", "actor": hero}
			5:
				var c = await choose_codex(hero)
				if c != null:
					return c
	return null


## Demo-fix 1: heeft de held een spreuk met genoeg MP of een geladen kernvaardigheid?
func has_usable_magic(hero: Dictionary) -> bool:
	for id in hero["s"]["spells"]:
		if int(hero["s"]["mp"]) >= int(GameData.SPELLS[id]["mp"]):
			return true
	for id in battle._kern_skills(hero):
		if battle.kern_ready(hero, id):
			return true
	return false


## Bericht dat ook tijdens het kiezen in de strook verschijnt (show_message verbergt die dan).
func show_notice(text: String) -> void:
	battle.show_message(text)
	battle.message_label.text = text
	battle.message_label.modulate = Color.WHITE
	battle.caption.visible = true
	battle._fit_caption()


## v0.19: staat de Codex-knop in het kruis? Niet in het oefengevecht, en niet zolang er nog
## niets te doen is (0 pagina's en 0 Lege Boeken).
func codex_command_shown() -> bool:
	if not battle.tutorial.is_empty() or GameState.practice_battle:
		return false
	return not GameState.codex_pages.is_empty() or GameState.item_count(CodexDataScript.BOOK_ITEM) > 0


## v0.19 Codex-submenu: 0 = Vangen, 1 = Wissel bondgenoot. Uitgeschakeld = grijs met de reden.
func choose_codex(hero: Dictionary):
	var book: String = CodexDataScript.BOOK_ITEM
	var last := 0
	while true:
		battle._set_state(battle.ST_COMMAND)
		var books := items_left(book)
		var vangen := "Capture  Book x%d" % books if books > 0 else "Capture: no Blank Book"
		var wissel := "Swap ally"
		if not battle.codex.can_swap():
			wissel = "Swap: Codex empty" if GameState.codex_pages.is_empty() else "Swap: all down"
			if not battle.codex.wissel_in_gevecht and not GameState.codex_pages.is_empty():
				wissel = "Swap: outside battle"   # v0.22 partylimiet: wisselen via het menu
		battle.show_message("Codex: capture or swap?")
		battle.menu.open("Codex", [{"text": vangen, "enabled": books > 0},
				{"text": wissel, "enabled": battle.codex.can_swap()}], last, true, battle._list_row_h(2))
		var k: int = await battle.menu.finished
		battle.menu.close()
		if k == -1:
			return null
		last = k
		if k == 0:
			var bk := "1 book" if books == 1 else "%d books" % books
			var t = await select_enemy(func(c): return "%s %s (%s)" % [c["name"], battle.codex.capture_hint(c), bk], "Capture: ")
			if t != null:
				battle._reserved[book] = battle._reserved.get(book, 0) + 1
				return {"type": "item", "actor": hero, "item": book, "target": t}   # zelfde weg als Item
		else:
			var sw = await choose_swap(hero)
			if sw != null:
				return sw
	return null


## v0.19 Wissel-lijst: niet-KO pagina's ('Lv' + naam) en onderaan 'Geen'. De bondgenoot die nu
## meevecht staat erin maar is grijs ('nu'); 'Geen' is grijs als er geen bondgenoot is.
func choose_swap(hero: Dictionary):
	var cur: String = battle.codex.current_ally_uid()
	var pages: Array = battle.codex.swap_choices()
	var entries := []
	var start := 0
	for i in pages.size():
		var p: Dictionary = pages[i]
		var here: bool = str(p["uid"]) == cur
		entries.append({"text": "%s Lv%d%s" % [p["name"], int(p["level"]), " now" if here else ""], "enabled": not here})
	entries.append({"text": "None", "enabled": cur != ""})
	battle.show_message("Who fights alongside you?")
	battle.menu.open("Swap", entries, start, true, battle._list_row_h(mini(entries.size(), battle.CODEX_ROWS_MAX)), battle.CODEX_ROWS_MAX)
	var k: int = await battle.menu.finished
	battle.menu.close()
	if k == -1:
		return null
	var uid := "" if k >= pages.size() else str(pages[k]["uid"])
	return {"type": "codex_swap", "actor": hero, "page": uid}


func choose_spell(hero: Dictionary):
	while true:
		battle._set_state(battle.ST_COMMAND)
		var ids: Array = hero["s"]["spells"]
		var entries := []
		for id in ids:
			var sp: Dictionary = GameData.SPELLS[id]
			entries.append({"text": "%-7s %dMP" % [sp["name"], sp["mp"]], "enabled": hero["s"]["mp"] >= sp["mp"]})
		# v0.15: kernvaardigheden onder de spreuken (geen MP, wel opladen)
		var kern: Array = battle._kern_skills(hero)
		for id in kern:
			entries.append({"text": battle.kern_entry_text(hero, id), "enabled": battle.kern_ready(hero, id)})
		battle.show_message("Which spell?" if kern.is_empty() else ("Which skill?" if ids.is_empty() else "Which spell or skill?"))
		battle.menu.open("Magic" if kern.is_empty() else ("Core" if ids.is_empty() else "Magic/Core"), entries,
				0, true, battle._list_row_h(mini(entries.size(), battle.LIST_ROWS_MAX)), battle.LIST_ROWS_MAX)
		var k: int = await battle.menu.finished
		battle.menu.close()        # v0.13: lijstje weg, dan is het doel goed te zien
		if k == -1:
			return null
		if k >= ids.size():
			var kid: String = kern[k - ids.size()]
			if not battle.kern_ready(hero, kid):
				continue
			var kt = await select_enemy()
			if kt != null:
				return {"type": "kern_skill", "actor": hero, "skill": kid, "target": kt}
			continue
		var spell: Dictionary = GameData.SPELLS[ids[k]]
		var t = null
		match spell["target"]:
			"enemy":
				t = await select_enemy()
			"ally":
				t = await select_ally()
			"ko":
				t = await select_ko()
			"all_enemies", "all_allies":
				return {"type": "spell", "actor": hero, "spell": ids[k], "target": null}
		if t != null:
			return {"type": "spell", "actor": hero, "spell": ids[k], "target": t}
	return null


func choose_item(hero: Dictionary):
	while true:
		battle._set_state(battle.ST_COMMAND)
		var ids := available_items()
		if ids.is_empty():
			return null
		var entries := []
		for id in ids:
			entries.append({"text": "%s x%d" % [GameData.ITEMS[id].get("short", GameData.ITEMS[id]["name"]), items_left(id)], "enabled": true})
		battle.show_message("Which item?")
		battle.menu.open("Item", entries, 0, true, battle._list_row_h(mini(entries.size(), battle.LIST_ROWS_MAX)), battle.LIST_ROWS_MAX)
		var k: int = await battle.menu.finished
		battle.menu.close()
		if k == -1:
			return null
		var t = null
		if str(GameData.ITEMS[ids[k]].get("target", "ally")) == "enemy":
			t = await select_enemy()      # Codex: Leeg Boek op een vijand
		elif float(GameData.ITEMS[ids[k]].get("revive", 0.0)) > 0.0:
			t = await select_ko()         # Feniksveer: een KO-held aanwijzen (H3)
		else:
			t = await select_ally()
		if t != null:
			battle._reserved[ids[k]] = battle._reserved.get(ids[k], 0) + 1
			return {"type": "item", "actor": hero, "item": ids[k], "target": t}
	return null


func available_items() -> Array:
	var ids := []
	for id in GameData.ITEMS:
		if items_left(id) > 0 and battle.battle_usable(GameData.ITEMS[id]):
			ids.append(id)
	return ids


func items_left(id: String) -> int:
	return GameState.item_count(id) - int(battle._reserved.get(id, 0))


func unreserve(action) -> void:
	if action != null and action["type"] == "item":
		battle._reserved[action["item"]] = maxi(0, battle._reserved.get(action["item"], 0) - 1)


# ---------------------------------------------------------------- doel kiezen (wrapper rond battle._pick_target)
## v0.19: label (optioneel) = tekst bij het pijltje (bv. 'Mosslijm 35%' bij Vangen); prefix komt
## ervoor in de berichtstrook.
func select_enemy(label := Callable(), prefix := ""):
	battle._set_state(battle.ST_TARGET_ENEMY)
	var living: Array = battle._alive(battle.enemies)
	# v9.1: vijanden staan bovenin; het pijltje blijft onder de bericht-strook (dan wijst het
	# iets in het plaatje, op het hoofd)
	var above := func(c): return Vector2(c["node"].position.x + roundf(c["node"].size.x / 2.0), maxf(c["node"].position.y + float(c.get("top", 0)) - 2.0, battle.CURSOR_MIN_Y))
	return await battle._pick_target(living, "Target", above, false, label, prefix)


func select_ally():
	battle._set_state(battle.ST_TARGET_ALLY)
	var living: Array = battle._alive(battle.heroes)
	var result = await battle._pick_target(living, "On whom?", func(c): return c["node"].head_position() + Vector2(0, -2), true)
	if result != null:
		battle.last_ally_target_row = result["row"]
	return result


func select_ko():
	var dead: Array = []
	for h in battle.heroes:
		if int(h["s"]["hp"]) <= 0:
			dead.append(h)
	if dead.is_empty():
		battle.show_message("Nobody is knocked out.")
		await battle._wait(battle.MESSAGE_TIME)
		return null
	battle._set_state(battle.ST_TARGET_ALLY)
	return await battle._pick_target(dead, "Who?", func(c): return c["node"].head_position() + Vector2(0, -2), true)