extends RefCounted
## F6-2: kiesbare lijstregels in de menu's hebben een tikvlak van minstens UiTouch.TOUCH_MIN (25).
## Gemeten op het echte tikvlak (get_global_rect van de knop na de layout, UiTouch.big_enough), niet op
## custom_minimum_size. De knoppen hebben geen zichtbare achtergrond: de extra hoogte is padding.
## Bewust NIET hier: de vaste panelen van Equipment (7 vakken + submenu, geen scroll) en de linkerkolom
## van het veldmenu (--uipolishtest eist daar ROW_H). Zie de PR (open punten).

const MenuScreen := preload("res://scripts/ui/menu_screen.gd")
## [scenario of veldmenu-commando, eigenschap met de regels, minimaal aantal regels]
const SCREENS := [
	["menu_items", "entries", 1],
	["menu_magic", "entries", 1],
	["menu_party", "", 5],
	["menu_codex", "entries", 1],
	["menu_bestiary", "entries", 1],
	["menu_quests", "rows", 0],
	["scenes", "buttons", 1],
	["menu_equipment", "list_buttons", 1],
]


func run(t: Node) -> void:
	t.check("F6-2 LIST_ROW_H = %d >= TOUCH_MIN" % MenuScreen.LIST_ROW_H, MenuScreen.LIST_ROW_H >= UiTouch.TOUCH_MIN)
	GameState.set_item_count("drankje", 2)
	GameState.set_item_count("kort_zwaard", 1)
	for p in ["16x9", "19_5x9_notch"]:
		await t.sc.set_profile(p)
		for spec in SCREENS:
			await _screen(t, p, spec)
	GameState.inventory.erase("kort_zwaard")


func _screen(t: Node, p: String, spec: Array) -> void:
	var naam := str(spec[0])
	var tag := "F6-2 [%s] %s" % [p, naam]
	var s: Node = await _open(t, naam)
	t.check(tag + ": scherm opent", s != null and is_instance_valid(s))
	if s == null:
		await t.sc.close_all()
		return
	if naam == "menu_equipment":
		for slot in s.slot_buttons.keys():
			s.open_list(str(slot))
			if not s.list_buttons.is_empty():
				break
	await t.sc.pframes(3)
	var regels: Array = _rows(s, str(spec[1]))
	var klein: Array[String] = []
	for b in regels:
		var r: Rect2 = (b as Control).get_global_rect()
		if not UiTouch.big_enough(r):
			klein.append("%s %s" % [str((b as Control).get_meta("label", (b as Control).name)), r.size])
	t.check(tag + ": %d regels (min %d), elk tikvlak >= %.0f %s" % [regels.size(), int(spec[2]), UiTouch.TOUCH_MIN, klein.slice(0, 3)],
			regels.size() >= int(spec[2]) and klein.is_empty())
	if naam == "menu_codex":
		t.check(tag + ": Fusion-knop tikvlak >= 25", UiTouch.big_enough((s.fuse_button as Control).get_global_rect()))
	await t.sc.close_all()


func _open(t: Node, naam: String) -> Node:
	if naam == "scenes":
		var m: Node = await t.sc.open_field_menu()
		if m == null:
			return null
		m.choose("scenes")
		await t.sc.pframes(6)
		return m.sub
	await t.sc.open(naam)
	var fm: Node = t.sc.field_menu()
	return fm.sub if fm != null else null


func _rows(s: Node, veld: String) -> Array:
	if veld == "":
		# Party: actieve plekken + monsterplek + reserve
		return s.actief_knoppen + [s.monster_knop] + s.reserve_held_knoppen + s.reserve_monster_knoppen
	return (s.get(veld) as Array).filter(func(b): return b is Button and (b as Button).is_visible_in_tree())
