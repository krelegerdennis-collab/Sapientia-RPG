extends RefCounted
## F6-T11: menu-hints zonder A:/B: in touch-modus; toetsenbordstrings ongewijzigd.
## Registratie: map-scan in scripts/tests/f6_ux2_tests.gd (--f6uxtest2).

const TC := preload("res://scripts/touch_controls.gd")
const TouchHints := preload("res://scripts/ui/touch_hints.gd")
const MenuScreen := preload("res://scripts/ui/menu_screen.gd")
const EquipmentS := preload("res://scripts/ui/equipment_screen.gd")
const MagicS := preload("res://scripts/ui/magic_screen.gd")
const PartyS := preload("res://scripts/ui/party_screen.gd")
const CodexS := preload("res://scripts/ui/codex_screen.gd")
const QuestlogS := preload("res://scripts/ui/questlog_screen.gd")
const ScenesS := preload("res://scripts/ui/scenes_screen.gd")
const OptionsS := preload("res://scripts/ui/options_screen.gd")
const StatusS := preload("res://scripts/ui/status_screen.gd")
const ShopS := preload("res://scripts/ui/shop_screen.gd")
const KoopmanS := preload("res://scripts/ui/koopman_winkel_scherm.gd")
const WerkplaatsS := preload("res://scripts/ui/werkplaats_scherm.gd")
const ItemsS := preload("res://scripts/ui/items_screen.gd")


func needs_game() -> bool:
	return true


static func _no_ab(hint: String) -> bool:
	return not hint.contains("A:") and not hint.contains("B:")


func _assert_map(t: Node) -> void:
	for old in TouchHints.TOUCH.keys():
		TC.touch_mode = true
		var shown: String = TouchHints.display(old)
		t.check("F6-T11 touch map '%s' geen A:/B:" % old.left(28), _no_ab(shown))
		TC.touch_mode = false
		t.check("F6-T11 keyboard map '%s' ongewijzigd" % old.left(28), TouchHints.display(old) == old)


func _hint_of(node: Node) -> String:
	if node == null:
		return ""
	if node.has_method("message_text"):
		return str(node.message_text())
	var h = node.get("hint")
	if h is Label:
		return (h as Label).text
	return ""


func _spawn_on_map(t: Node, scr: GDScript, prep: Callable = Callable()) -> Node:
	var scn: Node = t.sc.scene()
	if scn == null:
		return null
	var o: Node = scr.new()
	if prep.is_valid():
		prep.call(o)
	scn.add_child(o)
	await t.pframes(4)
	return o


func _open_menu(t: Node, name: String) -> Node:
	if not await t.sc.open(name):
		return null
	await t.pframes(4)
	var fm: Node = t.sc.field_menu()
	return fm.sub if fm != null else null


func _touch_screens(t: Node) -> void:
	TC.touch_mode = true
	await t.pframes(2)

	var shop: Node = null
	var koop: Node = null
	if await t.sc.open("shop_buy"):
		shop = t.sc.scene().get_node_or_null("ShopScreen")
	t.check("F6-T11 shop touch hint", shop != null and _no_ab(_hint_of(shop)))
	await t.sc.close_all()

	if await t.sc.open("shop_merchant"):
		koop = t.sc.scene().get_node_or_null("ShopScreen")
	t.check("F6-T11 koopman touch hint", koop != null and _no_ab(_hint_of(koop)))
	await t.sc.close_all()

	var werk: Node = await _spawn_on_map(t, WerkplaatsS)
	t.check("F6-T11 werkplaats touch hint", werk != null and _no_ab(_hint_of(werk)))
	if werk != null:
		werk.queue_free()
	await t.pframes(2)
	var eq: Node = await _open_menu(t, "menu_equipment")
	t.check("F6-T11 equipment touch hint", eq != null and _no_ab(_hint_of(eq)))

	var mag: Node = await _open_menu(t, "menu_magic")
	t.check("F6-T11 magic touch hint", mag != null and _no_ab(_hint_of(mag)))

	var party: Node = await _open_menu(t, "menu_party")
	t.check("F6-T11 party touch hint", party != null and _no_ab(_hint_of(party)))

	var codex: Node = await _open_menu(t, "menu_codex")
	if codex != null:
		t.check("F6-T11 codex browse touch", _no_ab(_hint_of(codex)))
		if codex.has_method("start_fusion") and GameState.codex_pages.size() >= 2:
			codex.start_fusion()
			await t.pframes(3)
			t.check("F6-T11 codex fusion-A touch", _no_ab(_hint_of(codex)))

	var quests: Node = await _open_menu(t, "menu_quests")
	t.check("F6-T11 questlog touch hint", quests != null and _no_ab(_hint_of(quests)))

	var scenes: Node = await _spawn_on_map(t, ScenesS)
	t.check("F6-T11 scenes touch hint", scenes != null and _no_ab(_hint_of(scenes)))
	if scenes != null and scenes.has_method("kies_tab"):
		scenes.kies_tab("music")
		await t.pframes(3)
		t.check("F6-T11 scenes music tab touch", _no_ab(_hint_of(scenes)))
		scenes.queue_free()
		await t.pframes(2)

	var opts: Node = await _open_menu(t, "menu_options")
	t.check("F6-T11 options general touch", opts != null and _no_ab(_hint_of(opts)))
	if opts != null and opts.has_method("kies_tab"):
		opts.kies_tab("music")
		await t.pframes(3)
		t.check("F6-T11 options music touch", _no_ab(_hint_of(opts)))

	var st: Node = await _open_menu(t, "menu_status")
	t.check("F6-T11 status touch hint", st != null and _no_ab(_hint_of(st)))

	var items: Node = await _open_menu(t, "menu_items")
	t.check("F6-T11 items touch hint", items != null and _no_ab(_hint_of(items)))

	await t.sc.close_all()


func _keyboard_screens(t: Node) -> void:
	TC.touch_mode = false
	await t.pframes(2)

	var checks: Array = [
		[ShopS, "A: choose   B: back", "shop"],
		[KoopmanS, "A: choose   B: back", "koopman"],
		[WerkplaatsS, "A: craft   B: back", "werkplaats"],
		[EquipmentS, EquipmentS.HINT_CMD, "equipment"],
		[MagicS, MagicS.HINT_LIST if GameState.party.size() > 1 else MagicS.HINT_LIST_SOLO, "magic"],
		[PartyS, PartyS.HINT, "party"],
		[CodexS, CodexS.HINT, "codex"],
		[QuestlogS, QuestlogS.HINT, "questlog"],
		[ScenesS, ScenesS.HINT, "scenes"],
		[OptionsS, str(OptionsS.ROWS[0][2]), "options"],
		[StatusS, "<  >: other hero   B: back" if GameState.party.size() > 1 else "B: back", "status"],
		[ItemsS, ItemsS.HINT_LIST, "items"],
	]
	for row in checks:
		var scr: Script = row[0]
		var want: String = row[1]
		var tag: String = row[2]
		var o: Node = null
		if scr == ShopS:
			o = await _spawn_on_map(t, scr, func(n): n.shop_id = "wilgendal_pantser")
		elif scr == KoopmanS:
			o = await _spawn_on_map(t, scr, func(n): n.run_seed = 3; n.bezoek = 1)
		else:
			o = await _spawn_on_map(t, scr)
		var got: String = _hint_of(o) if o != null else ""
		t.check("F6-T11 %s keyboard hint" % tag, o != null and got == want)
		if o != null:
			o.queue_free()
			await t.pframes(1)

	await t.sc.close_all()


func run(t: Node) -> void:
	_assert_map(t)
	await _touch_screens(t)
	await _keyboard_screens(t)
	TC.touch_mode = DisplayServer.is_touchscreen_available()