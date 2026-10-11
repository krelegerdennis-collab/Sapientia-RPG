extends Node
## ALLEEN VOOR TESTEN (v0.11) - test van het veldmenu, de opties en automatisch opslaan.
## Start:  godot --headless --path . -- --menutest
##         godot --path . -- --menutest --shots=/pad/naar/map   (met venster: screenshots)
## Wat hij doet (alles met gesimuleerde knoppen, zoals een speler):
##   - nieuw spel, Noor en Lotte erbij, menu openen (MENU-actie), speler op slot,
##     touch-knoppen weg, commando's, goud/tijd, vensters overlappen niet
##   - Items: Drankje op een gewonde held (HP + clamping + aantal), vol = geen effect,
##     Toverwater (MP), item op 0 verdwijnt, onbruikbaar item = grijs + melding
##   - Status: EXP/volgend level volgens GameData.exp_for_level, links/rechts = andere held
##   - Magie: Vuur grijs (alleen in gevecht), Genees van Lotte buiten gevecht (MP eraf)
##   - Bestiarium open/dicht, Opties: tekstsnelheid (Dialog), knoppen zicht (touch),
##     volume (bus), CRT, autosave; settings.cfg geschreven én opnieuw ingelezen
##   - Opslaan via het menu (Nee / Ja), menu dicht -> speler los
##   - menu gaat niet open tijdens een tekstvak of mapwissel
##   - autosave: na mapwissel, na gewonnen gevecht, bij app naar achtergrond; niet tijdens
##     gevecht/mapwissel/tekstvak, niet als het uit staat; handmatige save blijft heel;
##     titelscherm 'Doorgaan' laadt de nieuwste
##   - v0.14 (menu L2): Uitrusting (uitrusten/afdoen/sterkste/alles afdoen/weggooien, stat-
##     pijlen, tas <-> vakken zonder dubbel/kwijt, andere held, level-up), opslaan/laden van
##     de uitrusting + oude saves zonder uitrusting, het Lufia 2-opslagscherm met
##     'Overschrijven? Ja/Nee', en het portret (portrait_<id>.png of het vooraanzicht)
## Print PASS/FAIL en sluit af (exit code 0 = alles goed).

const GameData := preload("res://scripts/data/game_data.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const Equipment := preload("res://scripts/equipment.gd")
const HeroPortrait := preload("res://scripts/ui/hero_portrait.gd")
const StatArrow := preload("res://scripts/ui/stat_arrow.gd")
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const StatusScreenS := preload("res://scripts/ui/status_screen.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const TOWN := "res://scenes/maps/wilgendal.tscn"
## Wachttijd (sec) tot de autosave na binnenkomst geschreven is (map.gd AUTOSAVE_DELAY + marge).
const AUTOSAVE_WAIT := 0.8

var failures := 0
var passes := 0
var shots_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	seed(777)
	GameState.encounter_multiplier = 0.0
	_run.call_deferred()


# ---------------------------------------------------------------- hulpjes
func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func scene() -> Node:
	return get_tree().current_scene


func player() -> Node:
	var s := scene()
	return s.get_node_or_null("Objects/Player") if s != null and s.has_method("terrain_at") else null


func menu() -> Node:
	var s := scene()
	return s.get_node_or_null("FieldMenu") if s != null else null


func touch() -> Control:
	var s := scene()
	return s.get_node_or_null("TouchControls/Control") if s != null else null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## Druk een actie kort in (tijdens de physics-stap, zodat _process 'just_pressed' ziet).
func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func click_at(pos: Vector2) -> void:
	await get_tree().physics_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = get_tree().root.get_final_transform() * pos
	ev.global_position = ev.position
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(3)


func click(c: Control) -> void:
	await click_at(c.get_global_rect().get_center())


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func focused_label() -> String:
	var f := focused()
	return str(f.get_meta("label", "")) if f != null else ""


## Screenshot: native 384x216 én 3x vergroot (scherpe pixels).
func shot(file_name: String) -> void:
	if shots_dir == "":
		return
	await pframes(4)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	img.save_png(shots_dir.path_join(file_name + ".png"))
	var big := img.duplicate()
	big.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(shots_dir.path_join(file_name + "_3x.png"))
	print("INFO  screenshot: ", shots_dir.path_join(file_name + ".png"), " ", img.get_size())


func open_menu() -> Node:
	await tap("menu")
	await frames(2)
	return menu()


## Commando in het hoofdmenu kiezen met de D-pad (omlaag tot hij focus heeft) + A.
func pick_command(m: Node, id: String) -> void:
	var target: Button = m.buttons[id]
	for i in 10:
		if target.has_focus():
			break
		await tap("move_down")
	check("D-pad brengt de focus naar '%s'" % target.get_meta("label"), target.has_focus())
	await tap("interact")
	await frames(2)


func file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


# ---------------------------------------------------------------- testen
func _run() -> void:
	check("titelscherm", await wait_scene("Title"))
	await frames(10)
	_settings_basics()
	GameState.start_new_game("Kees")
	var story := _skip_story()
	if story:
		# v0.11 (Forge): start in het huis; proloog staat op 'klaar', dan naar het dorp
		await seconds(0.3)
		while GameState.changing_map:
			await get_tree().process_frame
		await seconds(0.6)
		check("geen autosave bij de start van een nieuw spel", not GameState.has_autosave())
		GameState.change_map(TOWN, "start")
	check("nieuw spel in Willowdale", await wait_scene("Wilgendal"))
	await seconds(0.6)
	if story:
		_remove(GameState.autosave_path)     # de autosave van de mapwissel hierboven
	else:
		check("geen autosave bij de start van een nieuw spel", not GameState.has_autosave())
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.gold = 123
	await _main_menu_tests()
	await _items_tests()
	_data_compat_tests()
	_equipment_logic_tests()
	_portrait_helper_tests()
	await _status_tests()
	await _equipment_screen_tests()
	_equipment_save_tests()
	await _magic_tests()
	await _bestiary_and_options_tests()
	await _menu_save_tests()
	await _close_tests()
	await _blocked_open_tests()
	await _autosave_tests()
	print("MENUTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d fouten)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


## Heeft deze versie een verhaal (v0.11 Forge: GameState.story_step + story_data.gd), zet
## het dan op 'klaar' zodat er geen cutscene loopt. Geeft true als dat zo is.
## (dynamisch: v9/v0.10 heeft geen verhaal en moet dit script ook kunnen laden)
func _skip_story() -> bool:
	if GameState.get("story_step") == null or not ResourceLoader.exists("res://scripts/data/story_data.gd"):
		return false
	var sd: Script = load("res://scripts/data/story_data.gd")
	GameState.set("story_step", int(sd.get_script_constant_map().get("KLAAR", 0)))
	return true


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _settings_basics() -> void:
	check("Settings: eigen testbestand (%s)" % Settings.path, Settings.path == Settings.TEST_PATH)
	check("Settings: standaardwaarden", Settings.values == Settings.DEFAULTS)
	check("audiobussen Music en SFX bestaan",
			AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1)
	check("tekstsnelheid 'Normaal' = 40 letters/sec in Dialog", is_equal_approx(Dialog.chars_per_second, 40.0))


func _main_menu_tests() -> void:
	var p := player()
	var start_tile: Vector2i = p.get_tile()
	var m := await open_menu()
	check("MENU opent het veldmenu", m != null)
	if m == null:
		return
	check("speler op slot zolang het menu open is", p.input_locked)
	check("touch-D-pad/A/B verborgen in het menu", not touch().is_visible_in_tree())
	var labels := []
	for c in m.COMMANDS:
		labels.append(str(m.buttons[c[0]].get_meta("label")))
	check("commando's %s" % [labels], labels == ["Items", "Magic", "Equipment", "Status", "Bestiary", "Options", "Save", "Close"])
	check("v0.14: 'Equipment' na Magie (Lufia 2-volgorde), geen 'Terug naar titel'", labels.find("Equipment") == 2 and not ("Terug naar titel" in labels))
	check("'Items' heeft de focus", m.buttons["items"].has_focus())
	check("goud en speeltijd (%s / %s)" % [m.gold_label.text, m.time_label.text],
			m.gold_label.text == "Gold 123" and m.time_label.text.begins_with("Time 0:00:"))
	# verwachte naam uit de map zelf (v9: 'Wilgendal'; v0.11: 'Huis aan de bosrand')
	var want_place := str(scene().map_name) if "map_name" in scene() else ""
	check("plek: %s (map_name van de map: %s)" % [m.place_label.text, want_place], m.place_label.text == want_place)
	check("3 heldenkaartjes", m.party_cards.size() == 3)
	await frames(3)
	var vp := Rect2(Vector2.ZERO, m.root.size)
	var boxes := [m.command_box, m.info_box, m.party_box]
	var inside := true
	for b in boxes:
		inside = inside and vp.encloses(b.get_global_rect())
	check("vensters binnen het scherm (%s)" % [boxes.map(func(b): return b.get_global_rect())], inside)
	check("vensters overlappen niet", not m.command_box.get_global_rect().intersects(m.info_box.get_global_rect())
			and not m.command_box.get_global_rect().intersects(m.party_box.get_global_rect())
			and not m.info_box.get_global_rect().intersects(m.party_box.get_global_rect()))
	check("info-vak (plaatsnaam ook lang) past op het scherm (%s)" % m.info_box.get_global_rect(),
			m.info_box.get_global_rect().end.y <= m.root.size.y and m.place_label.get_line_count() <= 2)
	var small := false
	for id in m.buttons:
		small = small or m.buttons[id].size.y < m.ROW_H
	check("tikvlak van elk commando >= %d px hoog" % m.ROW_H, not small)
	# D-pad loopt rond en de speler beweegt niet
	await tap("move_up")
	check("omhoog vanaf 'Items' = 'Sluiten' (rondlopen)", m.buttons["close"].has_focus())
	await tap("move_down")
	await tap("move_right")
	await frames(10)
	check("speler loopt niet tijdens het menu", p.get_tile() == start_tile and not p.is_moving)
	await shot("menu_main")


func _items_tests() -> void:
	var m := menu()
	GameState.party[0]["hp"] = 10
	await pick_command(m, "items")
	var s: Node = m.get_node_or_null("Items")
	check("'Items' opent het itemscherm", s != null)
	if s == null:
		return
	var texts := []
	for i in s.entries.size():
		texts.append(s.entry_text(i))
	check("lijst met aantallen %s" % [texts], texts == ["Potion        x3", "Magic Water  x1"])
	check("beschrijving van het gekozen item (%s)" % s.desc_label.text,
			s.name_label.text == "Potion" and s.desc_label.text == GameData.ITEMS["drankje"]["desc"]
			and s.effect_label.text == "Restores 30 HP.")
	await shot("menu_items")
	# v0.14: uitrusting in de tas staat grijs in Items, met vak + bonus en een eigen melding
	GameState.inventory["kort_zwaard"] = 1
	s.rebuild()
	await frames(2)
	var ki: int = s.ids.find("kort_zwaard")
	check("uitrusting in Items: achteraan, grijs (%s)" % [s.ids], ki == s.ids.size() - 1 and s.is_greyed(ki))
	if ki >= 0:
		s.entries[ki].grab_focus()
		await frames(2)
		check("uitrusting in Items: 'Wapen: ATK +3.' (%s)" % s.effect_label.text, s.effect_label.text == "Weapon: ATK +3.")
		await shot("menu_items_uitrusting")
		await tap("interact")
		check("A op uitrusting in Items: melding '%s'" % s.message_text(), not s.targeting and s.message_text() == PartyActions.MSG_EQUIP_ITEM)
	GameState.inventory.erase("kort_zwaard")
	s.rebuild()
	await frames(2)
	# Drankje op Kees (10/42 HP): +30
	await tap("interact")
	check("A op Potion -> doelkeuze met 3 helden", s.targeting and s.targets.buttons.size() == 3 and s.targets.buttons[0].has_focus())
	await shot("menu_items_target")
	await tap("interact")
	var hero: Dictionary = GameState.party[0]
	check("Potion: Kees 10 -> %d HP, nog %d" % [hero["hp"], GameState.item_count("drankje")],
			hero["hp"] == 40 and GameState.item_count("drankje") == 2)
	check("melding '%s'" % s.message_text(), s.message_text() == "Kees recovers 30 HP.")
	await tap("interact")
	check("tweede Potion: geclampt op max (%d/%d), nog %d" % [hero["hp"], hero["max_hp"], GameState.item_count("drankje")],
			hero["hp"] == hero["max_hp"] and GameState.item_count("drankje") == 1 and s.message_text() == "Kees recovers 2 HP.")
	await tap("interact")
	check("volle HP: geen effect, niets verbruikt (%s)" % s.message_text(),
			GameState.item_count("drankje") == 1 and s.message_text() == PartyActions.MSG_NO_EFFECT)
	await tap("cancel")
	check("B: terug naar de lijst (scherm blijft open)", not s.targeting and is_instance_valid(s) and not s.is_queued_for_deletion())
	# Toverwater op Noor (2/18 MP): +10, daarna is het op en verdwijnt het uit de lijst
	var noor: Dictionary = GameState.party[1]
	noor["mp"] = 2
	await tap("move_down")
	check("omlaag: Magic Water gekozen", s.selected_id == "toverwater")
	await tap("interact")
	await tap("move_down")
	check("omlaag in de doelkeuze: Noor", s.targets.focused_index() == 1)
	await tap("interact")
	await frames(2)
	check("Magic Water: Noor 2 -> %d MP, op = weg uit de lijst" % noor["mp"],
			noor["mp"] == 12 and not GameState.inventory.has("toverwater") and s.entries.size() == 1 and not s.targeting)
	# onbruikbaar item (onbekend / alleen in gevecht): grijs + melding, niets verbruikt
	GameState.inventory["oude_sleutel"] = 1
	s.rebuild()
	await frames(2)
	var k: int = s.ids.find("oude_sleutel")
	check("onbruikbaar item staat grijs in de lijst", k >= 0 and s.is_greyed(k) and not s.is_greyed(0))
	if k >= 0:
		await click(s.entries[k])
		check("tik op een grijs item: melding, geen doelkeuze (%s)" % s.message_text(),
				not s.targeting and s.message_text() == PartyActions.MSG_UNKNOWN and GameState.item_count("oude_sleutel") == 1)
	GameState.inventory.erase("oude_sleutel")
	check("Potion 'field': false zou grijs zijn (regel in party_actions)", PartyActions.item_usable_in_field("drankje")
			and not PartyActions.item_usable_in_field("bestaat_niet"))
	await tap("cancel")
	await frames(2)
	check("B sluit Items, terug in het hoofdmenu op 'Items'", m.get_node_or_null("Items") == null and m.buttons["items"].has_focus())


## v0.11: data van nieuwere versies (Forge v0.11: KEY_ITEMS, WEAPONS, "short") werkt ook.
func _data_compat_tests() -> void:
	var keys: Dictionary = PartyActions.data_const("KEY_ITEMS")
	if not keys.is_empty():
		var kid: String = str(keys.keys()[0])
		check("sleutel-voorwerp '%s': naam uit KEY_ITEMS, grijs, eigen melding" % kid,
				PartyActions.item_name(kid) == str(keys[kid].get("name", kid))
				and not PartyActions.item_usable_in_field(kid)
				and PartyActions.item_block_reason(kid) == PartyActions.MSG_KEY_ITEM)
	var cols: int = PartyActions.LIST_NAME_COLS
	var ok := true
	for id in GameData.ITEMS:
		ok = ok and PartyActions.item_list_name(id, cols).length() <= cols
	check("alle itemnamen passen in de lijst (max %d tekens, 'short' waar nodig)" % cols, ok)
	check("wapen: '-' zonder wapen", PartyActions.weapon_name({}) == "-")
	var weapons := PartyActions.weapons()
	if not weapons.is_empty():
		var wid: String = str(weapons.keys()[0])
		check("wapen '%s' -> naam" % wid, PartyActions.weapon_name({"weapon": wid}) == str(weapons[wid]["name"]))


func _status_tests() -> void:
	var m := menu()
	var hero: Dictionary = GameState.party[0]
	hero["exp"] = 9       # level 1: volgend level bij exp_for_level(2) = 15 -> nog 6
	await pick_command(m, "status")
	var s: Node = m.get_node_or_null("Status")
	check("'Status' opent het statusscherm", s != null)
	if s == null:
		return
	var need: int = GameData.exp_for_level(int(hero["level"]) + 1) - int(hero["exp"])
	check("Kees: Lv, EXP %d, nog %d tot volgend level (%s)" % [hero["exp"], need, s.next_label.text],
			s.index == 0 and s.card.hero == hero and s.exp_label.text == str(hero["exp"])
			and s.next_label.text == "%d EXP to go" % need)
	check("ATK/DEF/SPD/MAG/MDEF = effectief (%s/%s/%s/%s/%s)" % [s.atk_label.text, s.def_label.text, s.agi_label.text, s.mag_label.text, s.mdef_label.text],
			s.atk_label.text == str(hero["atk"]) and s.def_label.text == str(hero["def"]) and s.agi_label.text == str(hero["agi"])
			and s.mag_label.text == str(hero["mag"]) and s.mdef_label.text == str(hero["mdef"]))
	check("geen spreuken: Spreuken 'geen'", s.spells_label.text == "none")
	if not PartyActions.weapons().is_empty():
		check("rij 'Wapen' (%s)" % s.weapon_label.text, s.weapon_label != null and s.weapon_label.text == PartyActions.weapon_name(hero))
	else:
		check("geen wapens in de data: geen rij 'Wapen'", s.weapon_label == null)
	check("v0.14: portret van RPG ART (portrait_%s.png), precies 64x80, NEAREST (geen rug)" % GameState.MAIN_HERO,
			s.portrait.get_meta("source", "") == "portrait"
			and s.portrait.texture.resource_path.ends_with("assets/ui/portrait_%s.png" % GameState.MAIN_HERO)
			and s.portrait.texture.get_size() == Vector2(64, 80) and s.portrait.custom_minimum_size == Vector2(64, 80)
			and s.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and is_equal_approx(float(s.portrait.get_meta("scale", 0)), 1.0))
	check("klasse: %s" % s.class_label.text, s.class_label.text == "Warrior")
	await shot("menu_status")
	await tap("move_right")
	check("rechts: Noor (%s)" % s.spells_label.text, s.index == 1 and "Fire (4 MP)" in s.spells_label.text and "Lightning (7 MP)" in s.spells_label.text)
	check("Noor: eigen portret (portrait_noor.png, 64x80, NEAREST)", s.portrait.get_meta("source", "") == "portrait"
			and s.portrait.texture.resource_path.ends_with("portrait_noor.png") and s.portrait.custom_minimum_size == Vector2(64, 80)
			and s.portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	check("status: alles binnen het scherm (ook Noor met 2 spreuken)", _inside_screen(s.root, s.content)
			and s.spells_label.get_global_rect().end.y <= s.hint.get_global_rect().position.y)
	await shot("menu_status_noor")
	await tap("move_left")
	await tap("move_left")
	check("links vanaf Kees = Lotte (rondlopen)", s.index == 2 and s.page_label.text == "3/3")
	await click(s.next_button)
	check("tik op '>' = volgende held", s.index == 0)
	# echte level-up (GameState.give_exp): EXP-formule van het spel
	GameState.give_exp(hero, 10)
	s.show_member(0)
	var need2: int = GameData.exp_for_level(int(hero["level"]) + 1) - int(hero["exp"])
	check("na level-up: Lv %d, EXP %d, %s (verwacht nog %d)" % [hero["level"], hero["exp"], s.next_label.text, need2],
			hero["level"] == 2 and hero["exp"] == 19 and need2 == 41 and s.next_label.text == "nog 41 EXP")
	await tap("cancel")
	await frames(2)
	check("B sluit Status", m.get_node_or_null("Status") == null)


func _magic_tests() -> void:
	var m := menu()
	await tap("move_up")
	check("omhoog vanaf 'Equipment': 'Magie'", m.buttons["magic"].has_focus())
	await tap("interact")
	await frames(2)
	var s: Node = m.get_node_or_null("Magic")
	check("'Magie' opent het magiescherm", s != null)
	if s == null:
		return
	check("begint bij de eerste held met magie (Noor)", s.caster_index == 1 and s.entries.size() == 2)
	check("Fire/Lightning grijs (alleen in een gevecht)", s.is_greyed(0) and s.is_greyed(1))
	await tap("interact")
	check("A op Fire: melding '%s'" % s.message_text(), not s.targeting and s.message_text() == PartyActions.MSG_FIELD_ONLY)
	await tap("move_right")
	check("rechts: Lotte met Heal", s.caster_index == 2 and s.entry_text(0).begins_with("Heal") and not s.is_greyed(0))
	var kees: Dictionary = GameState.party[0]
	var lotte: Dictionary = GameState.party[2]
	kees["hp"] = 5
	var mp0 := int(lotte["mp"])
	await shot("menu_magic")
	await tap("interact")
	check("A op Heal -> doelkeuze", s.targeting)
	await tap("interact")
	var base := PartyActions.spell_base(lotte, "genees")
	var lo := 5 + roundi(base * 0.9)
	var hi := mini(int(kees["max_hp"]), 5 + roundi(base * 1.1))
	check("Heal op Kees: 5 -> %d HP (verwacht %d..%d), Lotte MP %d -> %d" % [kees["hp"], lo, hi, mp0, lotte["mp"]],
			kees["hp"] >= lo and kees["hp"] <= hi and lotte["mp"] == mp0 - 3)
	await tap("cancel")
	await tap("cancel")
	await frames(2)
	check("B, B: terug in het hoofdmenu", m.get_node_or_null("Magic") == null and m.sub == null)


func _bestiary_and_options_tests() -> void:
	var m := menu()
	await pick_command(m, "bestiary")
	check("'Bestiary' opent het bestiarium", m.get_node_or_null("Bestiary") != null)
	await tap("cancel")
	await frames(2)
	check("B sluit het bestiarium", m.get_node_or_null("Bestiary") == null)
	await pick_command(m, "options")
	var s: Node = m.get_node_or_null("Options")
	check("'Opties' opent het optiescherm", s != null)
	if s == null:
		return
	check("10 regels %s" % [s.keys], s.keys.size() == 10 and s.keys[0] == "music_volume" and s.keys[-1] == "_reset")
	check("alle regels in beeld", s.rows[-1].get_global_rect().end.y <= s.hint.get_global_rect().position.y)
	await shot("menu_options")
	# Muziek: links = 7
	await tap("move_left")
	var bus := AudioServer.get_bus_index("Music")
	check("Muziek 8 -> 7 (bus %.1f dB)" % AudioServer.get_bus_volume_db(bus),
			Settings.get_value("music_volume") == 7 and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.7)))
	# Tekstsnelheid: rechts = Snel
	await tap("move_down")
	await tap("move_down")
	check("focus op Tekstsnelheid", s.focused_key() == "text_speed")
	await tap("move_right")
	check("Tekstsnelheid -> Snel: Dialog %.0f letters/sec" % Dialog.chars_per_second,
			Settings.get_value("text_speed") == 2 and is_equal_approx(Dialog.chars_per_second, 80.0)
			and s.value_labels["text_speed"].text == "Fast")
	# Knoppen zicht: links = 90%
	await tap("move_down")
	await tap("move_down")
	await tap("move_left")
	check("Knoppen zicht 90%%: touch-alpha %.2f" % touch().modulate.a,
			Settings.get_value("touch_opacity") == 90 and is_equal_approx(touch().modulate.a, 0.9))
	# Knopgrootte: rechts = Groot
	await tap("move_down")
	var r0: float = touch().dpad_radius
	await tap("move_right")
	check("Knopgrootte Groot: D-pad straal %.1f -> %.1f" % [r0, touch().dpad_radius],
			touch().dpad_radius > r0 and is_equal_approx(touch().dpad_radius, touch()._base_dpad_radius * 1.15))
	await tap("move_left")
	# Scanlines uit en weer aan (A wisselt)
	await tap("move_down")
	check("focus op Scanlines", s.focused_key() == "crt")
	await tap("interact")
	check("Scanlines uit -> Crt onzichtbaar", Settings.get_value("crt") == false and not Crt.visible)
	await tap("interact")
	check("Scanlines weer aan", Settings.get_value("crt") == true and Crt.visible)
	# Autom. opslaan uit
	await tap("move_down")
	await tap("move_down")
	check("focus op Autom. opslaan", s.focused_key() == "autosave")
	await tap("interact")
	check("Autom. opslaan uit", Settings.autosave_enabled() == false and s.value_labels["autosave"].text == "Off")
	# Bestand geschreven en opnieuw in te lezen
	var cfg := ConfigFile.new()
	check("settings.cfg geschreven (%s)" % Settings.path, cfg.load(Settings.path) == OK
			and cfg.get_value("instellingen", "text_speed") == 2 and cfg.get_value("instellingen", "autosave") == false
			and cfg.get_value("instellingen", "music_volume") == 7 and cfg.get_value("instellingen", "touch_opacity") == 90)
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.load_settings()
	check("opnieuw ingelezen: Snel, 90%%, Muziek 7, autosave uit (%s)" % [Settings.values],
			Settings.get_value("text_speed") == 2 and Settings.get_value("touch_opacity") == 90
			and Settings.get_value("music_volume") == 7 and Settings.get_value("autosave") == false)
	# kapotte waarden worden netjes begrensd
	check("ongeldige waarde wordt begrensd", Settings._sanitize("text_speed", 99) == 3 and Settings._sanitize("touch_opacity", 5) == 30)
	# Tik op '>' bij Autom. opslaan = weer aan
	var row: Button = s.rows[s.keys.find("autosave")]
	var plus: Button = row.get_parent().get_child(row.get_parent().get_child_count() - 1)
	await click(plus)
	check("tik op '>' zet Autom. opslaan weer aan", Settings.autosave_enabled())
	# Standaard: alles terug (behalve wat we hierna willen houden)
	await tap("move_down")
	check("focus op Standaard", s.focused_key() == "_reset")
	await tap("interact")
	check("Standaard: alles terug", Settings.values == Settings.DEFAULTS and is_equal_approx(Dialog.chars_per_second, 40.0)
			and is_equal_approx(touch().modulate.a, 1.0))
	await tap("cancel")
	await frames(2)
	check("B sluit Opties", m.get_node_or_null("Options") == null)


func _menu_save_tests() -> void:
	var m := menu()
	var p := player()
	check("nog geen handmatige save", not GameState.has_save())
	await pick_command(m, "save")
	var sc: Node = m.get_node_or_null("SaveScreen")
	check("'Opslaan' opent het opslagscherm (leeg slot: 'Hier opslaan?')", sc != null and sc.question_label.text == sc.Q_NEW
			and not sc.overwrite and not sc.slot_label.visible)
	if sc == null:
		return
	check("opslagscherm: %d helden met klein plaatje (Kees = hoofd uit zijn portret, 44x44)" % sc.hero_views.size(),
			sc.hero_views.size() == GameState.party.size()
			and HeroPortrait.view_rect(sc.hero_views[0]).get_meta("source", "") == "portrait_crop"
			and HeroPortrait.view_rect(sc.hero_views[0]).texture.get_size() == HeroPortrait.MINI_CROP.size
			and HeroPortrait.view_rect(sc.hero_views[0]).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var nv: TextureRect = HeroPortrait.view_rect(sc.hero_views[1])
	check("opslagscherm: Noor = hoofd uit haar portret, 1:1 en NEAREST (%s)" % nv.get_meta("source", ""),
			nv.get_meta("source", "") == "portrait_crop" and nv.texture.get_size() == HeroPortrait.MINI_CROP.size
			and nv.custom_minimum_size == HeroPortrait.MINI_CROP.size and nv.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var want_place := str(scene().map_name) if "map_name" in scene() else ""
	check("opslagscherm: plek '%s', Tijd %s, Goud %s" % [sc.place_label.text, sc.time_label.text, sc.gold_label.text],
			sc.place_label.text == want_place and sc.gold_label.text == str(GameState.gold) and sc.time_label.text.begins_with("0:"))
	check("opslagscherm: alles binnen het scherm", _inside_screen(sc.root, sc.content))
	await shot("menu_save")
	await tap("cancel")
	await frames(2)
	check("B = Nee: niets opgeslagen", m.last_save_result == "declined" and not GameState.has_save() and m.get_node_or_null("SaveScreen") == null)
	await tap("interact")
	await frames(2)
	sc = m.get_node_or_null("SaveScreen")
	check("opnieuw: scherm open, 'Ja' gekozen", sc != null and sc.yes_button.has_focus())
	# v0.13 (Dennis): opslaan via het menu geneest NIET (alleen het cyaan boek vult HP/MP)
	var hurt: Dictionary = GameState.party[0]
	var keep_hp: int = hurt["hp"]
	hurt["hp"] = maxi(1, int(hurt["max_hp"]) - 5)
	await tap("interact")
	await frames(2)
	var d := GameState.read_save()
	check("menu-opslaan geneest niet (HP %d/%d blijft, ook in de save)" % [hurt["hp"], hurt["max_hp"]],
			not d.is_empty() and hurt["hp"] == maxi(1, int(hurt["max_hp"]) - 5) and int(d["party"][0]["hp"]) == hurt["hp"])
	hurt["hp"] = keep_hp
	check("Ja: handmatig opgeslagen (%s)" % m.message_label.text, m.last_save_result == "saved" and GameState.has_save()
			and m.message_label.text == "Saved." and m.message_label.visible)
	check("save: map, plek en kijkrichting van de speler, geen autosave-vlag",
			not d.is_empty() and str(d.get("map", "")).ends_with("wilgendal.tscn") and Vector2i(int(d["tile"][0]), int(d["tile"][1])) == p.get_tile()
			and d.get("autosave", true) == false and d["party"].size() == 3 and int(d["gold"]) == 123)
	check("autosave niet aangeraakt door handmatig opslaan", not GameState.has_autosave())
	# v0.14: slot heeft nu data -> 'Overschrijven? Ja/Nee'
	var before := file_text(GameState.save_path)
	GameState.gold = 124
	await tap("interact")
	await frames(2)
	sc = m.get_node_or_null("SaveScreen")
	check("slot met data: 'Overschrijven?' + wat er nu in het slot staat (%s)" % (sc.slot_label.text if sc else "-"),
			sc != null and sc.overwrite and sc.question_label.text == "Overwrite?" and sc.slot_label.visible
			and sc.slot_label.text.begins_with("In this slot: Kees Lv"))
	if sc == null:
		return
	check("overschrijven: knoppen 'Ja' en 'Nee', tikvlak >= %d px" % m.ROW_H, sc.yes_button.get_meta("label") == "Yes"
			and sc.no_button.get_meta("label") == "No" and sc.yes_button.size.y >= m.ROW_H and sc.no_button.size.y >= m.ROW_H)
	check("overschrijven: alles binnen het scherm", _inside_screen(sc.root, sc.content))
	await shot("menu_save_overwrite")
	await click(sc.no_button)
	await frames(2)
	check("tik op 'Nee': niet overschreven (bestand gelijk)", m.last_save_result == "declined"
			and file_text(GameState.save_path) == before and m.get_node_or_null("SaveScreen") == null)
	await tap("interact")
	await frames(2)
	sc = m.get_node_or_null("SaveScreen")
	if sc != null:
		await click(sc.yes_button)
		await frames(2)
	d = GameState.read_save()
	check("tik op 'Ja': overschreven (goud 124 in de save)", m.last_save_result == "saved" and int(d.get("gold", 0)) == 124)
	GameState.gold = 123
	m.save_now()
	check("autosave nog steeds niet aangeraakt", not GameState.has_autosave())


func _close_tests() -> void:
	var m := menu()
	var p := player()
	await click(m.back_button)
	await frames(3)
	check("tik op 'Sluiten': menu dicht", menu() == null)
	check("speler weer los en touch-knoppen terug", not p.input_locked and touch().is_visible_in_tree())
	var t0: Vector2i = p.get_tile()
	await tap("move_up")
	for i in 30:
		if not p.is_moving:
			break
		await frames(1)
	await frames(2)
	check("speler kan weer lopen (%s -> %s)" % [t0, p.get_tile()], p.get_tile() != t0 or p.facing == Vector2i.UP)
	# B sluit ook
	m = await open_menu()
	await tap("cancel")
	await frames(2)
	check("B sluit het menu", menu() == null and not p.input_locked)
	m = await open_menu()
	await tap("menu")
	await frames(2)
	check("MENU sluit het menu", menu() == null and not p.input_locked)


func _blocked_open_tests() -> void:
	Dialog.show_lines(["Test."])
	await frames(2)
	await tap("menu")
	await frames(2)
	check("menu gaat niet open tijdens een tekstvak", menu() == null)
	Dialog.close()
	await frames(2)
	GameState.changing_map = true
	await tap("menu")
	await frames(2)
	check("menu gaat niet open tijdens een mapwissel", menu() == null)
	GameState.changing_map = false
	await frames(2)


func _autosave_tests() -> void:
	var manual_before := file_text(GameState.save_path)
	# 1) mapwissel -> autosave op de nieuwe map
	GameState.change_map(WORLD, "van_dorp")
	await frames(2)
	check("tijdens de mapwissel: geen autosave mogelijk", not GameState.autosave(Vector2i.ZERO, Vector2i.DOWN, "test"))
	check("wereldkaart geladen", await wait_scene("Wereldkaart"))
	await seconds(AUTOSAVE_WAIT)
	var a := GameState.read_save(GameState.autosave_path)
	var p := player()
	check("autosave na mapwissel (%s, reden %s)" % [GameState.autosave_path, GameState.last_autosave_reason],
			GameState.has_autosave() and GameState.last_autosave_reason == "map"
			and str(a.get("map", "")).ends_with("wereldkaart.tscn") and a.get("autosave", false) == true
			and Vector2i(int(a["tile"][0]), int(a["tile"][1])) == p.get_tile())
	check("handmatige save onaangeroerd", file_text(GameState.save_path) == manual_before)
	check("nieuwste save = autosave", GameState.newest_save_path() == GameState.autosave_path)
	# 2) autosave uit -> niets bij een mapwissel
	Settings.set_value("autosave", false)
	var count := GameState.autosave_count
	var stamp := file_text(GameState.autosave_path)
	GameState.change_map(TOWN, "zuid_ingang")
	check("terug in Willowdale", await wait_scene("Wilgendal"))
	await seconds(AUTOSAVE_WAIT)
	check("autosave uit in Opties: niets geschreven", GameState.autosave_count == count and file_text(GameState.autosave_path) == stamp)
	Settings.set_value("autosave", true)
	# 3) app naar de achtergrond; niet met een tekstvak open
	Dialog.show_lines(["Even wachten."])
	await frames(2)
	GameState._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("app naar achtergrond met tekstvak open: geen autosave", GameState.autosave_count == count)
	Dialog.close()
	await frames(2)
	GameState._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	a = GameState.read_save(GameState.autosave_path)
	check("app naar achtergrond: autosave (reden %s)" % GameState.last_autosave_reason,
			GameState.autosave_count == count + 1 and GameState.last_autosave_reason == "achtergrond"
			and str(a.get("map", "")).ends_with("wilgendal.tscn"))
	# 4) gewonnen gevecht -> autosave (en niet tijdens het gevecht)
	GameState.change_map(WORLD, "van_dorp")
	check("wereldkaart (voor het gevecht)", await wait_scene("Wereldkaart"))
	await seconds(AUTOSAVE_WAIT)
	var battle_tile: Vector2i = player().get_tile()
	GameState.debug_force_group = ["mosslijm"]
	scene().start_battle(GameState.pick_encounter_group(""))
	check("gevecht geladen", await wait_scene("Battle"))
	count = GameState.autosave_count
	GameState._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check("tijdens het gevecht: geen autosave (ook niet bij achtergrond)",
			not GameState.autosave(Vector2i.ZERO, Vector2i.DOWN, "test") and GameState.autosave_count == count)
	await _win_battle()
	check("terug op de wereldkaart na winst", await wait_scene("Wereldkaart", 40.0))
	await seconds(AUTOSAVE_WAIT)
	a = GameState.read_save(GameState.autosave_path)
	check("autosave na gewonnen gevecht (reden %s, tile %s)" % [GameState.last_autosave_reason, battle_tile],
			GameState.last_battle_result == "win" and GameState.last_autosave_reason == "battle"
			and Vector2i(int(a["tile"][0]), int(a["tile"][1])) == battle_tile)
	GameState.debug_force_group = []
	# 5) titelscherm: 'Doorgaan' laadt de nieuwste (nu de autosave op de wereldkaart)
	var auto_hp := int(a["party"][0]["hp"])
	GameState.party[0]["hp"] = 1
	GameState.go_to_title()
	check("titelscherm", await wait_scene("Title"))
	await frames(10)
	var t := scene()
	check("'Doorgaan' aan, toont '(auto)' (%s)" % t.save_info.text, not t.continue_button.disabled and "(auto)" in t.save_info.text)
	await shot("title_autosave")
	await click(t.continue_button)
	check("'Doorgaan' -> wereldkaart (autosave is de nieuwste)", await wait_scene("Wereldkaart"))
	await frames(5)
	check("plek en HP uit de autosave (%s, HP %d)" % [player().get_tile(), GameState.party[0]["hp"]],
			player().get_tile() == battle_tile and GameState.party[0]["hp"] == auto_hp)
	# 6) zelfde formaat: autosave en handmatige save hebben dezelfde sleutels
	var man := GameState.read_save(GameState.save_path)
	var aut := GameState.read_save(GameState.autosave_path)
	var mk := man.keys()
	var ak := aut.keys()
	mk.sort()
	ak.sort()
	check("autosave = zelfde formaat als de handmatige save (%d sleutels)" % ak.size(), mk == ak and not ak.is_empty())
	_robust_load_tests()
	# 7) handmatig opslaan via het menu is daarna weer de nieuwste
	var m := await open_menu()
	if m != null:
		await seconds(1.1)       # saved_unix moet zichtbaar later zijn
		check("menu-save opnieuw", m.save_now())
		check("nieuwste save = handmatig", GameState.newest_save_path() == GameState.save_path)
		await tap("cancel")
		await frames(2)


## Saves met ontbrekende/onbekende/kapotte velden mogen nooit crashen (Forge voegt later
## o.a. 'story_step' toe). Schrijft tijdelijk in een eigen testbestand.
func _robust_load_tests() -> void:
	var path := "user://autotest_robust.json"
	var keep_party: Array = GameState.party.duplicate(true)
	var keep_inv: Dictionary = GameState.inventory.duplicate(true)
	var keep_gold := GameState.gold
	var keep_name := GameState.player_name
	var cases := [
		["minimaal (alleen map + party-id, oude id)", {"map": TOWN, "party": [{"id": GameState.HERO_ID_LEGACY}]}],
		["nieuwe id (oude id -> dennis) + onbekende sleutels (story_step, flags)",
			{"map": TOWN, "party": [{"id": GameState.HERO_ID}], "story_step": 3,
			"flags": {"intro": true}, "gold": 5}],
		["kapotte velden", {"map": TOWN, "party": [{"id": GameState.MAIN_HERO, "hp": "x"}, 7], "tile": "nee", "facing": [1],
			"inventory": [1, 2], "bestiary": {"mosslijm": 3}, "gold": "veel", "play_time": null}],
	]
	for c in cases:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(c[1]))
		f.close()
		var ok := GameState.load_game(path)
		check("laden %s: geen crash, standaardwaarden" % c[0], ok and GameState.party.size() == 1
				and GameState.party[0]["id"] == GameState.MAIN_HERO
				and GameState.party[0]["hp"] is int and GameState.return_tile is Vector2i)
	check("geen party = geen geldige save", (func():
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"map": TOWN}))
		f.close()
		return not GameState.load_game(path)).call())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.has_return_point = false
	GameState.party = keep_party
	GameState.inventory = keep_inv
	GameState.gold = keep_gold
	GameState.player_name = keep_name


## Mosslijm verslaan: steeds Aanval + doel bevestigen en berichten wegklikken.
func _win_battle() -> void:
	Engine.time_scale = 3.0
	for guard in 400:
		var b := scene()
		if b == null or b.name != "Battle":
			break
		match str(b.get("state")):
			"command", "target_enemy", "message_wait":
				await tap("interact")
			_:
				await frames(2)
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- v0.14 menu L2
## Alle zichtbare vensters/teksten onder 'node' binnen het scherm, en geen afgekapte tekst
## (labels/knoppen met clip_text: de tekst moet in de breedte passen).
func _inside_screen(root: Control, node: Control) -> bool:
	var vp := Rect2(Vector2.ZERO, root.size).grow(0.5)
	var ok := true
	for c in _controls(node):
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		if not vp.encloses(c.get_global_rect()):
			print("INFO  buiten het scherm: %s %s" % [c.get_path(), c.get_global_rect()])
			ok = false
		if (c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF) or c is Button:
			var font: Font = c.get_theme_font("font")
			var fs: int = c.get_theme_font_size("font_size")
			var txt: String = c.text
			if txt != "" and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > c.size.x + 0.5:
				print("INFO  tekst past niet: %s '%s' (%.0f > %.0f)" % [c.get_path(), txt,
						font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, c.size.x])
				ok = false
	return ok


func _controls(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Control:
			out.append(c)
		out.append_array(_controls(c))
	return out


## Snapshot: per uitrustingsstuk hoeveel er in totaal is (tas + gedragen).
func _equip_totals() -> Dictionary:
	var out := {}
	for id in GameData.EQUIPMENT:
		out[id] = Equipment.total_count(GameState.party, GameState.inventory, id)
	return out


## Pure regels (geen scherm): uitrusten/afdoen/sterkste/weggooien op een losse held + tas.
func _equipment_logic_tests() -> void:
	var data_ok := true
	for id in GameData.EQUIPMENT:
		var it: Dictionary = GameData.EQUIPMENT[id]
		data_ok = data_ok and str(it.get("slot", "")) in GameData.EQUIP_SLOTS and str(it.get("name", "")) != ""
		for k in it:
			if k in ["atk", "def", "agi"] or k in ["mag", "mdef"]:
				data_ok = data_ok and (it[k] is int)
	check("uitrustingsdata: %d stukken, elk een geldig vak" % GameData.EQUIPMENT.size(), data_ok and GameData.EQUIPMENT.size() == 38)   # v0.15: + Vonkzwaard, v0.16: + Leerling-mantel, Task #4: + 24 d100_*-stukken (14 + 24)
	check("vakken Wapen/Schild/Helm/Harnas/Accessoire", GameData.EQUIP_SLOTS.map(func(x): return Equipment.slot_name(x))
			== ["Weapon", "Shield", "Helm", "Armor", "Accessory"])
	check("stats ATK/DEF/MAG/MDEF/SPD (SPD = agi)", GameData.EQUIP_STATS.map(func(x): return Equipment.stat_label(x))
			== ["ATK", "DEF", "MAG", "MDEF", "SPD"] and GameData.EQUIP_STATS[4] == "agi")
	var mag_ok := true
	for hd in GameData.HEROES:
		mag_ok = mag_ok and hd.has("mag") and hd.has("mdef") and hd["growth"].has("mag") and hd["growth"].has("mdef")
	check("MAG/MDEF bij elke held + groei (Dennis 2/4, Noor 10/8, Lotte 7/9)", mag_ok
			and GameData.HEROES[0]["mag"] == 2 and GameData.HEROES[0]["mdef"] == 4 and GameData.HEROES[1]["mag"] == 10)
	var h := GameState.hero_template(GameState.MAIN_HERO)
	check("nieuwe held: basis = data, lege vakken, effectief = basis", h["base"]["atk"] == 14 and h["atk"] == 14
			and h["equip"] == Equipment.empty_equip() and h["mag"] == 2 and h["mdef"] == 4)
	var inv := {"kort_zwaard": 1, "dolk": 1, "eiken_staf": 1, "malienkolder": 1, "leren_harnas": 1, "bladwijzer": 2}
	var party := [h]
	var total := func(id): return Equipment.total_count(party, inv, id)
	var r := Equipment.equip(h, inv, "wapen", "eiken_staf")
	check("Krijger kan geen Oak Staff dragen (%s)" % r["text"], not r["ok"] and h["equip"]["wapen"] == "" and inv["eiken_staf"] == 1)
	r = Equipment.equip(h, inv, "schild", "dolk")
	check("Dagger past niet in het vak Schild", not r["ok"] and inv["dolk"] == 1)
	r = Equipment.equip(h, inv, "wapen", "kort_zwaard")
	check("Short Sword uitrusten: ATK 14 -> %d, weg uit de tas, weapon-veld mee" % h["atk"], r["ok"] and h["atk"] == 17
			and not inv.has("kort_zwaard") and h["weapon"] == "kort_zwaard" and h["base"]["atk"] == 14)
	r = Equipment.equip(h, inv, "wapen", "dolk")
	check("Dagger over het Short Sword: ATK %d, SPD %d, zwaard terug in de tas" % [h["atk"], h["agi"]], r["ok"] and h["atk"] == 18
			and h["agi"] == 10 and inv.get("kort_zwaard", 0) == 1 and not inv.has("dolk")
			and total.call("dolk") == 1 and total.call("kort_zwaard") == 1)
	r = Equipment.equip(h, inv, "wapen", "dolk")
	check("Dagger nog eens: niet in de tas -> niets gebeurt", not r["ok"] and total.call("dolk") == 1)
	var pv := Equipment.preview(h, "harnas", "malienkolder")
	var cmp := Equipment.compare(Equipment.effective_stats(h), pv)
	check("voorbeeld Chain Mail: DEF +6 (pijl omhoog), SPD -1 (pijl omlaag), ATK gelijk; held onveranderd",
			pv["def"] == h["def"] + 6 and cmp["def"] == 1 and cmp["agi"] == -1 and cmp["atk"] == 0 and h["equip"]["harnas"] == "")
	var n := Equipment.strongest(h, inv)
	check("Sterkste (Krijger): %d vakken -> %s" % [n, h["equip"]], h["equip"]["wapen"] == "dolk" and h["equip"]["harnas"] == "malienkolder"
			and h["equip"]["accessoire"] == "bladwijzer" and h["equip"]["schild"] == "" and n == 2)
	check("Sterkste: effectief = basis + bonussen (DEF %d, SPD %d)" % [h["def"], h["agi"]], h["def"] == 8 + 6 and h["agi"] == 9 + 1 - 1 + 2
			and GameState.effective_stat(h, "def") == h["def"] and GameState.effective_stats(h)["agi"] == h["agi"])
	check("Sterkste: niets dubbel/kwijt (bladwijzer 1 gedragen + 1 in de tas, leren harnas in de tas)",
			total.call("bladwijzer") == 2 and inv.get("bladwijzer", 0) == 1 and inv.get("leren_harnas", 0) == 1 and total.call("malienkolder") == 1)
	check("Sterkste nog eens: niets te wisselen", Equipment.strongest(h, inv) == 0)
	# level-up houdt de uitrusting en groeit op de basis
	GameState.give_exp(h, 15)
	check("level-up met uitrusting: Lv 2, basis ATK 17, effectief %d (dolk +4); MDEF basis 5" % h["atk"],
			h["level"] == 2 and h["base"]["atk"] == 17 and h["atk"] == 21 and h["base"]["mdef"] == 5 and h["mdef"] == 5)
	var cnt := Equipment.unequip_all(h, inv)
	check("Alles afdoen: %d stukken terug, effectief = basis" % cnt, cnt == 3 and h["atk"] == h["base"]["atk"]
			and inv.get("dolk", 0) == 1 and inv.get("malienkolder", 0) == 1 and inv.get("bladwijzer", 0) == 2 and h["weapon"] == "")
	check("Afdoen op een leeg vak: melding, niets erbij", not Equipment.unequip(h, inv, "helm")["ok"] and inv.get("leren_kap", 0) == 0)
	Equipment.equip(h, inv, "accessoire", "bladwijzer")
	r = Equipment.drop(h, "accessoire")
	check("Weggooien: gedragen stuk is echt weg (%s)" % r["text"], r["ok"] and total.call("bladwijzer") == 1 and h["equip"]["accessoire"] == "")
	var n2 := GameState.hero_template("noor")
	var inv2 := {"eiken_staf": 1, "dolk": 1, "reisgewaad": 1, "houten_schild": 1}
	Equipment.strongest(n2, inv2)
	check("Sterkste (Magiër Noor): Oak Staff (MAG %d), Travel Robe, geen schild" % n2["mag"], n2["equip"]["wapen"] == "eiken_staf"
			and n2["equip"]["harnas"] == "reisgewaad" and n2["equip"]["schild"] == "" and n2["mag"] == 14 and inv2.get("dolk", 0) == 1)
	# stat-pijlen (los getekend)
	var a := StatArrow.new()
	a.dir = 1
	var up := a.color()
	a.dir = -1
	var down := a.color()
	a.dir = 0
	check("stat-pijl: omhoog groen, omlaag rood, gelijk grijs", up == MenuColors.BETTER and down == MenuColors.WORSE and a.color() == MenuColors.SAME
			and MenuColors.BETTER.g > MenuColors.BETTER.r and MenuColors.WORSE.r > MenuColors.WORSE.g)
	a.free()


## Portret-hulpje: portrait_<id>.png als die er is, anders het vooraanzicht.
func _portrait_helper_tests() -> void:
	var keep_dir := HeroPortrait.portrait_dir
	var dir := "user://menutest_portraits"
	DirAccess.make_dir_recursive_absolute(dir)
	_remove(dir.path_join("portrait_%s.png" % GameState.MAIN_HERO))
	HeroPortrait.portrait_dir = dir
	HeroPortrait.clear_cache()
	var h: Dictionary = GameState.party[0]
	check("geen portret-bestand: vooraanzicht uit %s (rij 0, 16x24)" % h.get("field_sprite", "?"),
			HeroPortrait.source(h) == "front" and HeroPortrait.portrait(h) is AtlasTexture
			and HeroPortrait.portrait(h).get_size() == Vector2(16, 24) and HeroPortrait.portrait(h).region.position == Vector2.ZERO)
	check("held-id uit de data (MAIN_HERO '%s'): pad %s" % [GameState.MAIN_HERO, HeroPortrait.portrait_path(h)],
			HeroPortrait.portrait_path(h).ends_with("portrait_%s.png" % GameState.MAIN_HERO))
	check("gevechtsframe-reserve nooit het rugaanzicht (dennis_rug -> dennis.png)", HeroPortrait.battle_frame(h) != null
			and not HeroPortrait.battle_frame(h).atlas.resource_path.contains("_rug"))
	var img := Image.create(HeroPortrait.PORTRAIT_SIZE.x, HeroPortrait.PORTRAIT_SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color("8fba7c"))
	img.save_png(dir.path_join("portrait_%s.png" % GameState.MAIN_HERO))
	HeroPortrait.clear_cache()
	check("portrait_%s.png aanwezig: dat portret (64x80)" % GameState.MAIN_HERO, HeroPortrait.source(h) == "portrait"
			and HeroPortrait.portrait(h).get_size() == Vector2(64, 80))
	var view := HeroPortrait.make_view(Vector2(64, 80))
	var sc := HeroPortrait.show_portrait(view, h)
	check("portret 64x80 in een vak van 64x80: schaal 1, scherp", is_equal_approx(sc, 1.0)
			and HeroPortrait.view_rect(view).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	view.free()
	var big := HeroPortrait.make_view(Vector2(128, 160))
	var tex64: Texture2D = HeroPortrait.portrait(h)
	check("portret in een vak van 128x160: precies 2x (128x160), NEAREST",
			is_equal_approx(HeroPortrait.show_in(big, tex64, "portrait"), 2.0)
			and HeroPortrait.view_rect(big).custom_minimum_size == Vector2(128, 160)
			and HeroPortrait.view_rect(big).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var small := HeroPortrait.make_view(Vector2(40, 50))
	check("te groot voor het vak: hele deler (1/2 -> 32x40), toch NEAREST",
			is_equal_approx(HeroPortrait.show_in(small, tex64, "portrait"), 0.5)
			and HeroPortrait.view_rect(small).custom_minimum_size == Vector2(32, 40)
			and HeroPortrait.view_rect(small).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	big.free()
	small.free()
	check("mini (opslagscherm) met portret: hoofd-uitsnede 44x44", HeroPortrait.mini_source(h) == "portrait_crop"
			and HeroPortrait.mini_sprite(h).get_size() == HeroPortrait.MINI_CROP.size)
	_remove(dir.path_join("portrait_%s.png" % GameState.MAIN_HERO))
	HeroPortrait.clear_cache()
	check("portret weer weg: terug naar het vooraanzicht (ook de mini = loopframe 16x24)", HeroPortrait.source(h) == "front"
			and HeroPortrait.mini_source(h) == "front" and HeroPortrait.mini_sprite(h).get_size() == Vector2(16, 24))
	HeroPortrait.portrait_dir = keep_dir
	HeroPortrait.clear_cache()
	var all_ok := true
	for hid in ["dennis", "noor", "lotte"]:
		var hh := {"id": hid}
		all_ok = all_ok and HeroPortrait.source(hh) == "portrait" and HeroPortrait.portrait(hh).get_size() == Vector2(64, 80)
	check("portretten van RPG ART in assets/ui/ (dennis, noor, lotte: 64x80)", all_ok)


## Het scherm Uitrusting, zoals een speler (D-pad, A, B en tikken).
func _equipment_screen_tests() -> void:
	var m := menu()
	var kees: Dictionary = GameState.party[0]
	for id in ["kort_zwaard", "dolk", "houten_schild", "kaftschild", "leren_kap", "ijzeren_helm",
			"leren_harnas", "malienkolder", "bladwijzer", "eiken_staf", "reisgewaad"]:
		GameState.inventory[id] = 1
	var start := _equip_totals()
	await pick_command(m, "equip")
	var s: Node = m.get_node_or_null("Equipment")
	check("'Equipment' opent het uitrustingsscherm", s != null)
	if s == null:
		return
	var slot_texts: Array = Equipment.slots().map(func(x): return str(s.slot_buttons[x].get_meta("label")))
	check("vakken %s" % [slot_texts], slot_texts[0].begins_with("Weapon") and slot_texts[1].begins_with("Shield")
			and slot_texts[2].begins_with("Helm") and slot_texts[3].begins_with("Armor") and slot_texts[4].begins_with("Accessory")
			and slot_texts.all(func(t): return t.ends_with("-")))
	var cmds: Array = s.COMMANDS.map(func(c): return str(s.cmd_buttons[c[0]].get_meta("label")))
	check("submenu %s" % [cmds], cmds == ["Equip", "Best", "Remove", "Remove All", "Drop"])
	check("links: naam, Lv, HP, MP (%s / %s / %s / %s)" % [s.name_label.text, s.level_label.text, s.hp_label.text, s.mp_label.text],
			s.name_label.text == "Kees" and s.level_label.text.ends_with("Lv %d" % kees["level"])
			and s.hp_label.text == "HP %d/%d" % [kees["hp"], kees["max_hp"]] and s.mp_label.text == "MP --")
	var st_ok := true
	for st in Equipment.stats():
		st_ok = st_ok and s.old_value_text(st) == str(kees[st]) and s.arrow_dir(st) == null
	check("stats ATK/DEF/MAG/MDEF/SPD = effectief, nog geen pijlen", st_ok)
	var pr: TextureRect = HeroPortrait.view_rect(s.portrait_view)
	check("portret: portrait_%s.png op precies 64x80, NEAREST (bron %s)" % [GameState.MAIN_HERO, pr.get_meta("source", "")],
			pr.get_meta("source", "") == "portrait" and pr.custom_minimum_size == Vector2(64, 80)
			and pr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	check("'Uitrusten' heeft de focus", s.cmd_buttons["equip"].has_focus() and s.mode == "command")
	await frames(2)
	check("uitrusting: alles binnen het scherm, geen afgekapte tekst", _inside_screen(s.root, s.content))
	var tap_ok := true
	for b in s.slot_buttons.values() + s.cmd_buttons.values():
		tap_ok = tap_ok and b.size.y >= s.ROW_H
	check("tikvlakken vakken/submenu >= %d px" % s.ROW_H, tap_ok)
	await shot("menu_equip")
	# Uitrusten > Wapen > lijst
	await tap("interact")
	check("A op Uitrusten: vak kiezen, Wapen heeft focus", s.mode == "slot" and s.action == "equip" and s.slot_buttons["wapen"].has_focus())
	await tap("interact")
	check("A op Wapen: lijst met passende wapens %s (geen staf)" % [s.list_ids], s.mode == "item" and s.list_ids == ["kort_zwaard", "dolk"]
			and s.list_panel.visible and not s.cmd_panel.visible and s.list_buttons[0].has_focus())
	check("pijl bij Short Sword: ATK %s -> %s omhoog (groen), SPD gelijk" % [s.old_value_text("atk"), s.new_value_text("atk")],
			s.arrow_dir("atk") == 1 and s.new_value_text("atk") == str(kees["atk"] + 3) and s.arrow_dir("agi") == 0
			and s.new_value_color("atk") == MenuColors.BETTER)
	await tap("move_down")
	check("omlaag: Dagger - ATK +4 en SPD +1 omhoog", s.arrow_dir("atk") == 1 and s.arrow_dir("agi") == 1
			and s.new_value_text("atk") == str(kees["atk"] + 4) and s.new_value_text("agi") == str(kees["agi"] + 1))
	check("lijst: alles binnen het scherm", _inside_screen(s.root, s.content))
	await shot("menu_equip_list")
	var atk0: int = kees["atk"]
	await tap("interact")
	check("A op Dagger: gedragen, weg uit de tas, terug naar de vakken (%s)" % s.message_text(), kees["equip"]["wapen"] == "dolk"
			and kees["atk"] == atk0 + 4 and GameState.item_count("dolk") == 0 and s.mode == "slot" and s.slot_buttons["wapen"].has_focus()
			and str(s.slot_buttons["wapen"].get_meta("label")).ends_with("Dagger"))
	check("na uitrusten: niets dubbel of kwijt", _equip_totals() == start)
	# nu het Kort zwaard bekijken: slechter dan de Dolk -> rood omlaag
	await tap("interact")
	check("lijst opnieuw: alleen het Short Sword (Dagger wordt gedragen)", s.list_ids == ["kort_zwaard"])
	check("pijl bij Short Sword nu: ATK %s -> %s omlaag (rood), SPD omlaag" % [s.old_value_text("atk"), s.new_value_text("atk")],
			s.arrow_dir("atk") == -1 and s.arrow_dir("agi") == -1 and s.new_value_color("atk") == MenuColors.WORSE)
	await shot("menu_equip_list_worse")
	await tap("cancel")
	check("B in de lijst: terug naar de vakken, niets veranderd", s.mode == "slot" and kees["equip"]["wapen"] == "dolk" and s.arrow_dir("atk") == null)
	await tap("cancel")
	check("B bij de vakken: terug naar het submenu ('Uitrusten')", s.mode == "command" and s.cmd_buttons["equip"].has_focus())
	# Sterkste
	await tap("move_down")
	check("omlaag: 'Sterkste'", s.cmd_buttons["strongest"].has_focus())
	await tap("interact")
	await frames(2)
	check("Sterkste: %s" % [kees["equip"]], kees["equip"] == {"wapen": "dolk", "schild": "kaftschild", "helm": "ijzeren_helm",
			"harnas": "malienkolder", "accessoire": "bladwijzer"})
	check("Sterkste: pijlen tonen het verschil (DEF omhoog, melding '%s')" % s.message_text(), s.arrow_dir("def") == 1
			and s.new_value_text("def") == str(kees["def"]) and s.message_text() == Equipment.MSG_STRONGEST)
	check("Sterkste: effectief = basis + uitrusting (DEF %d = %d + 3 + 3 + 6)" % [kees["def"], kees["base"]["def"]],
			kees["def"] == int(kees["base"]["def"]) + 12 and GameState.effective_stat(kees, "def") == kees["def"])
	check("Sterkste: niets dubbel of kwijt", _equip_totals() == start)
	check("Sterkste: alles binnen het scherm", _inside_screen(s.root, s.content))
	await shot("menu_equip_strongest")
	# status toont de bonus: '17 (+3)'
	check("status-tekst met bonus (%s)" % StatusScreenS.stat_text(kees, "def"), StatusScreenS.stat_text(kees, "def") == "%d (+12)" % kees["def"])
	# Afdoen (tik op het submenu), dan Wapen
	await click(s.cmd_buttons["unequip"])
	check("tik op 'Afdoen': vak kiezen", s.mode == "slot" and s.action == "unequip")
	await tap("interact")
	check("Afdoen Wapen: Dagger terug in de tas (%s)" % s.message_text(), kees["equip"]["wapen"] == "" and GameState.item_count("dolk") == 1
			and kees["atk"] == kees["base"]["atk"] and kees["weapon"] == "")
	await tap("interact")
	check("Afdoen op een leeg vak: melding '%s'" % s.message_text(), s.message_text() == Equipment.MSG_EMPTY_SLOT)
	check("na afdoen: niets dubbel of kwijt", _equip_totals() == start)
	await tap("cancel")
	# Weggooien: Schild (Kaftschild) - eerst Nee, dan Ja
	await click(s.cmd_buttons["drop"])
	await tap("move_down")
	check("Weggooien: focus op Schild", s.mode == "slot" and s.action == "drop" and s.slot_buttons["schild"].has_focus())
	await tap("interact")
	await frames(2)
	check("Weggooien vraagt eerst (Nee heeft focus)", s.mode == "confirm" and s.confirm != null and s.confirm.no_button.has_focus())
	await tap("interact")
	await frames(2)
	check("Nee: Cover Shield blijft", s.mode == "slot" and kees["equip"]["schild"] == "kaftschild" and _equip_totals() == start)
	await tap("interact")
	await frames(2)
	await tap("move_up")
	await tap("interact")
	await frames(2)
	var after_drop := start.duplicate()
	after_drop["kaftschild"] = 0
	check("Ja: Cover Shield weg (niet in de tas), de rest onveranderd", kees["equip"]["schild"] == "" and GameState.item_count("kaftschild") == 0
			and _equip_totals() == after_drop)
	await tap("cancel")
	# Alles afdoen
	await click(s.cmd_buttons["unequip_all"])
	check("Alles afdoen: alle vakken leeg, alles terug in de tas", Equipment.slots().all(func(x): return kees["equip"][x] == "")
			and GameState.item_count("malienkolder") == 1 and GameState.item_count("bladwijzer") == 1 and _equip_totals() == after_drop
			and kees["atk"] == kees["base"]["atk"] and kees["def"] == kees["base"]["def"])
	# andere held: Noor (rechts), tik op een vak = meteen Uitrusten
	await tap("move_right")
	check("rechts: Noor", s.index == 1 and s.name_label.text == "Noor")
	await click(s.slot_buttons["schild"])
	check("tik op Schild bij Noor: niets dat past (Magiër, geen schild)", s.mode == "slot" and s.message_text() == s.MSG_NOTHING_FITS)
	await click(s.slot_buttons["wapen"])
	check("tik op Wapen bij Noor: Oak Staff en Dagger %s" % [s.list_ids], s.mode == "item" and s.list_ids == ["eiken_staf", "dolk"])
	check("Oak Staff: MAG %s -> %s omhoog" % [s.old_value_text("mag"), s.new_value_text("mag")], s.arrow_dir("mag") == 1
			and s.new_value_text("mag") == str(int(GameState.party[1]["mag"]) + 4))
	await click(s.list_buttons[0])
	check("tik op Oak Staff: Noor draagt hem (MAG %d)" % GameState.party[1]["mag"], GameState.party[1]["equip"]["wapen"] == "eiken_staf"
			and GameState.item_count("eiken_staf") == 0 and _equip_totals() == after_drop)
	await tap("cancel")
	await tap("cancel")
	await frames(2)
	check("B, B: Equipment dicht, terug op 'Equipment' in het hoofdmenu", m.get_node_or_null("Equipment") == null
			and m.buttons["equip"].has_focus())
	# Kees krijgt de Dolk terug om (voor de save-test hieronder)
	Equipment.equip(kees, GameState.inventory, "wapen", "dolk")


## Opslaan/laden van de uitrusting + oude saves zonder uitrusting.
func _equipment_save_tests() -> void:
	var path := "user://menutest_equip.json"
	var keep_party: Array = GameState.party.duplicate(true)
	var keep_inv: Dictionary = GameState.inventory.duplicate(true)
	var keep_ret := [GameState.has_return_point, GameState.return_map, GameState.return_tile, GameState.return_facing]
	var keep_misc := [GameState.gold, GameState.player_name, GameState.bestiary.duplicate(true), GameState.story_step,
		GameState.story_flags.duplicate(true), GameState.puzzle_latched.duplicate(true), GameState._play_time_base, GameState._clock_start_ms]
	var kees: Dictionary = GameState.party[0]
	var want_eq: Dictionary = kees["equip"].duplicate()
	var want_stats := Equipment.effective_stats(kees)
	var want_base: Dictionary = kees["base"].duplicate()
	var totals := _equip_totals()
	check("save met uitrusting geschreven", GameState.save_game(Vector2i(3, 4), Vector2i.DOWN, path))
	var d := GameState.read_save(path)
	var e: Dictionary = d["party"][0]
	check("save-sleutels per held: equip, base, mag, mdef (+ oud 'weapon')", e.has("equip") and e.has("base") and e.has("mag")
			and e.has("mdef") and e["weapon"] == "dolk" and e["equip"]["wapen"] == "dolk")
	Equipment.unequip_all(kees, GameState.inventory)
	GameState.inventory.clear()
	check("laden: uitrusting, stats en tas terug", GameState.load_game(path) and GameState.party[0]["equip"] == want_eq
			and Equipment.effective_stats(GameState.party[0]) == want_stats and GameState.party[0]["base"] == want_base
			and GameState.party[0]["atk"] == want_stats["atk"] and _equip_totals() == totals)
	# oude save (v0.13): geen equip/base/mag/mdef; 'weapon' + atk met de bonus erin
	var old := {"map": TOWN, "party": [{"id": GameState.MAIN_HERO, "name": "Kees", "level": 3, "exp": 60, "hp": 50, "mp": 0,
		"max_hp": 60, "max_mp": 0, "atk": 23, "def": 12, "agi": 11, "spells": [], "weapon": "kort_zwaard"},
		{"id": "noor", "level": 1, "exp": 0, "hp": 28, "mp": 18, "max_hp": 28, "max_mp": 18, "atk": 7, "def": 5, "agi": 11,
		"spells": ["vuur", "bliksem"], "weapon": null}],
		"inventory": {"drankje": 2}, "gold": 9}
	_write_json(path, old)
	var ok := GameState.load_game(path)
	var k: Dictionary = GameState.party[0] if ok else {}
	check("oude save zonder uitrusting laadt: Short Sword in het wapenvak, ATK 23 = 20 + 3", ok and k["equip"]["wapen"] == "kort_zwaard"
			and k["atk"] == 23 and k["base"]["atk"] == 20 and k["equip"]["schild"] == "")
	check("oude save: MAG/MDEF standaard (Lv 3: MAG 2, MDEF 4 + 2x1 = 6; Noor 10/8)", ok and k["mag"] == 2 and k["mdef"] == 6
			and GameState.party[1]["mag"] == 10 and GameState.party[1]["mdef"] == 8 and GameState.party[1]["equip"] == Equipment.empty_equip())
	# kapotte/onbekende uitrusting: niets crasht, niets kwijt (gaat naar de tas)
	var bad := {"map": TOWN, "party": [{"id": GameState.MAIN_HERO, "equip": {"wapen": "eiken_staf", "helm": "bestaat_niet", "schild": 5,
		"harnas": "leren_kap"}, "base": {"atk": "x", "def": 9}}], "inventory": {}}
	_write_json(path, bad)
	ok = GameState.load_game(path)
	k = GameState.party[0] if ok else {}
	check("kapotte uitrusting in de save: lege vakken, ongeldige stukken in de tas, basis-standaard",
			ok and k["equip"] == Equipment.empty_equip() and GameState.item_count("eiken_staf") == 1
			and GameState.item_count("leren_kap") == 1 and GameState.item_count("bestaat_niet") == 1
			and k["base"]["def"] == 9 and k["base"]["atk"] == 14 and k["atk"] == 14)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameState.party = keep_party
	GameState.inventory = keep_inv
	GameState.has_return_point = keep_ret[0]
	GameState.return_map = keep_ret[1]
	GameState.return_tile = keep_ret[2]
	GameState.return_facing = keep_ret[3]
	GameState.gold = keep_misc[0]
	GameState.player_name = keep_misc[1]
	GameState.bestiary = keep_misc[2]
	GameState.story_step = keep_misc[3]
	GameState.story_flags = keep_misc[4]
	GameState.puzzle_latched = keep_misc[5]
	GameState._play_time_base = keep_misc[6]
	GameState._clock_start_ms = keep_misc[7]
	var m := menu()
	if m != null:
		for c in m.party_cards:
			c.hero = GameState.party[m.party_cards.find(c)]
		m.refresh_party()


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
