extends RefCounted
## Titelscherm: Beta Test, End State en SoM achter ReleaseFlags.test_menu_override.
## Draait vooraan in --autotest. Zet de vlag terug zodat de rest van de suite de knoppen houdt.
## t = de autotest-node (check / pframes / scene).

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")

var t: Node
var shots := ""


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)


func run() -> void:
	_beslis_tests()
	var oud := ReleaseFlags.test_menu_override
	var titel: Node = t.scene()
	t.check("testmenu: titelscherm bij de start", titel != null and titel.get("som_button") != null)
	if titel == null or titel.get("som_button") == null:
		ReleaseFlags.test_menu_override = oud
		return
	var kaart := _kaart(titel)
	ReleaseFlags.test_menu_override = 0
	titel.apply_test_menu_visibility()
	await t.pframes(3)
	_check_verborgen(titel, kaart)
	await _shot("title_testmenu_uit")
	ReleaseFlags.test_menu_override = 1
	titel.apply_test_menu_visibility()
	await t.pframes(3)
	_check_zichtbaar(titel, kaart)
	await _shot("title_testmenu_aan")
	ReleaseFlags.test_menu_override = oud
	titel.apply_test_menu_visibility()
	titel.refresh()
	await t.pframes(2)
	t.check("testmenu: na afloop weer zichtbaar voor de suite",
			titel.som_button.visible and titel.beta_button.visible and titel.eind_button.visible
			and not titel.beta_button.disabled and not titel.eind_button.disabled)


func _beslis_tests() -> void:
	var leeg := PackedStringArray()
	var vlag := PackedStringArray(["--testmenu"])
	t.check("testmenu: normale run verbergt de knoppen", not ReleaseFlags.test_menu_from(-1, false, leeg, true))
	t.check("testmenu: release negeert --testmenu", not ReleaseFlags.test_menu_from(-1, false, vlag, false))
	t.check("testmenu: debug-build met --testmenu toont ze", ReleaseFlags.test_menu_from(-1, false, vlag, true))
	t.check("testmenu: testsuite toont ze zonder --testmenu", ReleaseFlags.test_menu_from(-1, true, leeg, false))
	t.check("testmenu: override 0 verbergt ook in een testsuite", not ReleaseFlags.test_menu_from(0, true, vlag, true))
	t.check("testmenu: override 1 toont ook buiten een testsuite", ReleaseFlags.test_menu_from(1, false, leeg, false))


func _check_verborgen(titel: Node, kaart: Rect2) -> void:
	var labels := _labels(titel)
	var som: Button = titel.som_button
	var beta: Button = titel.beta_button
	var eind: Button = titel.eind_button
	t.check("testmenu uit: SoM, Beta Test en End State niet in het menu %s" % [labels],
			not labels.has("SoM") and not labels.has("Beta Test") and not labels.has("End State")
			and labels.has("Continue") and labels.has("New Game") and labels.has("Load"))
	t.check("testmenu uit: knoppen onzichtbaar, uit en niet aantikbaar",
			_dicht(som) and _dicht(beta) and _dicht(eind) and not titel.beta_card.visible
			and not titel.beta_info.visible and titel.beta_card.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	t.check("testmenu uit: geen plek naast of onder het menu (kaart %s, som %s, beta %s)" % [kaart, som.get_global_rect(), titel.beta_card.get_global_rect()],
			som.custom_minimum_size == Vector2.ZERO and titel.beta_card.custom_minimum_size == Vector2.ZERO
			and not som.get_global_rect().intersects(kaart) and not titel.beta_card.get_global_rect().intersects(kaart)
			and not titel.beta_info.get_global_rect().intersects(kaart)
			and is_equal_approx(titel.pvp_button.custom_minimum_size.x, titel.CARD_RIGHT - titel.CARD_LEFT))
	_kaart_blijft(titel, kaart)
	t.check("testmenu uit: focus wijst niet naar een verborgen knop",
			titel.new_button.focus_neighbor_top != som.get_path()
			and titel.new_button.focus_neighbor_left != beta.get_path()
			and titel.continue_button.focus_neighbor_left != beta.get_path())


func _check_zichtbaar(titel: Node, kaart: Rect2) -> void:
	var labels := _labels(titel)
	var som: Button = titel.som_button
	var beta: Button = titel.beta_button
	var eind: Button = titel.eind_button
	var pvp: Button = titel.pvp_button
	t.check("testmenu aan: SoM, Beta Test en End State in het menu %s" % [labels],
			labels.has("SoM") and labels.has("Beta Test") and labels.has("End State"))
	t.check("testmenu aan: knoppen zichtbaar en bruikbaar",
			_open(som) and _open(beta) and _open(eind) and titel.beta_card.visible and titel.beta_info.visible)
	t.check("testmenu aan: SoM naast PvP, Beta links van het menu, tikhoogte 25",
			som.position.x > pvp.position.x and absf(som.position.y - pvp.position.y) < 1.0
			and som.size.y >= 25.0 and beta.size.y >= 25.0 and eind.size.y >= 25.0
			and titel.beta_card.get_global_rect().end.x <= kaart.position.x + 0.5
			and pvp.custom_minimum_size.x < titel.card.size.x - 1.0)
	_kaart_blijft(titel, kaart)
	t.check("testmenu aan: focusketen naar SoM en Beta Test",
			titel.new_button.focus_neighbor_top == som.get_path()
			and titel.new_button.focus_neighbor_left == beta.get_path())


func _kaart_blijft(titel: Node, kaart: Rect2) -> void:
	var nu := _kaart(titel)
	var stage_midden: Vector2 = ((titel.size - titel.STAGE_SIZE) / 2.0).floor()
	t.check("testmenu: menu blijft rechtsonder en de stage gecentreerd (%s)" % nu,
			nu.is_equal_approx(kaart) and titel.stage.position.is_equal_approx(stage_midden)
			and absf(nu.position.x - titel.stage.position.x - 240.0) <= 1.0
			and absf(nu.end.x - titel.stage.position.x - 372.0) <= 1.0
			and titel.new_button.size.y >= 25.0 and titel.continue_button.size.y >= 25.0)


func _kaart(titel: Node) -> Rect2:
	return titel.card.get_global_rect()


func _dicht(b: Button) -> bool:
	return not b.visible and not b.is_visible_in_tree() and b.disabled and b.focus_mode == Control.FOCUS_NONE \
			and b.mouse_filter == Control.MOUSE_FILTER_IGNORE


func _open(b: Button) -> bool:
	return b.visible and b.is_visible_in_tree() and not b.disabled and b.focus_mode == Control.FOCUS_ALL \
			and b.mouse_filter == Control.MOUSE_FILTER_STOP


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := t.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var pad := shots.path_join(name + ".png")
	img.save_png(pad)
	print("INFO  screenshot: ", pad, " ", img.get_size())


func _labels(root: Node) -> Array[String]:
	var out: Array[String] = []
	_labels_rec(root, out)
	return out


func _labels_rec(n: Node, out: Array[String]) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Button:
		out.append(str((n as Button).get_meta("label", "")))
	for c in n.get_children():
		_labels_rec(c, out)
