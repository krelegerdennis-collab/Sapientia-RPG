extends RefCounted
## F6.3: exacte ENGELS-spelerteksten voor RUN, Party-scherm, molen en Rustkamer-wissel.
## Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const SD := preload("res://scripts/data/story_data.gd")
const PartyScreenS := preload("res://scripts/ui/party_screen.gd")
const Molen := preload("res://scripts/village/molen.gd")
const PartyWisselS := preload("res://world_warper/kamers/party_wissel.gd")
const RunUitleg := preload("res://scripts/run_uitleg.gd")
const PartySelectScene := preload("res://world_warper/services/party_select.tscn")
const PartySelectGd := preload("res://world_warper/services/party_select.gd")
const ShopScreenS := preload("res://scripts/ui/shop_screen.gd")
const KoopmanSchermS := preload("res://scripts/ui/koopman_winkel_scherm.gd")
const WarpViewS := preload("res://world_warper/warp/warp_view.gd")
const Dorp := preload("res://scripts/data/wilgendal_dorp.gd")
const NpcScene := preload("res://scenes/npc.tscn")
const PARTY_HINT := "Tap someone in Active, then someone in Reserve to swap. Back to close."
const WISSEL_UITLEG := "Tap a name to move them between Active and Bench. Dax stays in the party."
const HUB_PARTY_UITLEG := "This is your current party. To change who fights, go to the Rest Room, or open MENU, then Party."
const SHOP_HINT := "Tap an item to buy it. Tap Sell to sell what you carry. Back to leave."
const SPELL_LEARN := "Tap who should learn this spell."
const WARP_UITLEG := "Pick a world, then a place you have visited, then Travel. Locked places stay closed until you reach them on foot."
const MOLEN_FOLLOW := "To change who fights with you, open MENU, then Party."
const BINNEN := "res://scenes/maps/wilgendal_binnen.tscn"
const PHONE_CASES := [
	["landscape_19_5x9", Vector2i(468, 216), Vector4(30, 0, 30, 0)],
	["portrait_19_5x9", Vector2i(100, 216), Vector4(22, 4, 10, 6)],
]


func needs_game() -> bool:
	return true


static func _rect_overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b) and not (a.end.y <= b.position.y + 0.5 or b.end.y <= a.position.y + 0.5)


static func _set_viewport(t: Node, size: Vector2i, ins: Vector4) -> void:
	var win := t.get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = size
	win.size = size * 3
	UiTouch.insets_override = ins
	await t.pframes(4)


func _check_party_screen_hint(t: Node, tag: String) -> void:
	var ps: Node = PartyScreenS.new()
	t.get_tree().root.add_child(ps)
	await t.pframes(4)
	ps.call("_apply_safe_area")
	ps.call("_layout_party_hint")
	await t.pframes(8)
	var hint: Label = ps.get("hint")
	var safe: Rect2 = t.safe()
	t.check("%s: Party-hint exact", hint != null and hint.text == PARTY_HINT)
	if hint == null:
		ps.queue_free()
		await t.pframes(2)
		return
	t.check("%s: Party-hint niet afgeknipt (clip uit)", not hint.clip_text)
	var band: Control = ps.get("_hint_band")
	var hr := band.get_global_rect() if band != null else hint.get_global_rect()
	t.check("%s: Party-hint binnen safe %s (%s)" % [tag, safe, hr], t.within(hr, safe))
	var outer: Control = ps.get("_outer")
	var breedte := hr.size.x
	if outer != null and outer.size.x > 1.0:
		breedte = minf(breedte, outer.size.x)
	var font: Font = hint.get_theme_font("font")
	var fs: int = hint.get_theme_font_size("font_size")
	var regels: PackedStringArray = PartyScreenS._hint_regels(PARTY_HINT, breedte, fs, font)
	var rij_h := float(fs + 3)
	var need_h := rij_h * float(regels.size())
	t.check("%s: Party-hint hoogte voor volledige tekst (%.0f <= %.0f)" % [tag, need_h, hr.size.y], need_h <= hr.size.y + 1.0)
	var max_w := 0.0
	for regel in regels:
		max_w = maxf(max_w, font.get_string_size(regel, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	t.check("%s: Party-hint geen horizontale overflow (%.0f <= %.0f)" % [tag, max_w, hr.size.x], max_w <= hr.size.x + 1.0)
	ps.queue_free()
	await t.pframes(2)


static func _uitleg_uit_box(box: Control) -> String:
	if box == null:
		return ""
	var parts: PackedStringArray = []
	for ch in box.get_children():
		if ch is Label:
			parts.append(str((ch as Label).text))
	return " ".join(parts)


func _check_party_wissel_layout(t: Node, tag: String) -> void:
	var pw: CanvasLayer = PartyWisselS.new()
	t.get_tree().root.add_child(pw)
	await t.pframes(4)
	pw.call("_layout_uitleg")
	await t.pframes(8)
	var root := pw.get_child(0) if pw.get_child_count() > 0 else null
	var kolom: Node = root.get_child(0) if root != null and root.get_child_count() > 0 else null
	var band := kolom.get_child(1) as Control if kolom != null and kolom.get_child_count() > 1 else null
	var tekst := _uitleg_uit_box(band)
	var safe: Rect2 = t.safe()
	t.check("%s: Rustkamer-uitleg exact", tekst == WISSEL_UITLEG)
	if band == null:
		pw.queue_free()
		await t.pframes(2)
		return
	var lr := band.get_global_rect()
	t.check("%s: uitleg binnen safe %s (vlak %s)" % [tag, safe, lr], t.within(lr, safe))
	var rijen: Node = null
	if kolom != null and kolom.get_child_count() > 2:
		rijen = kolom.get_child(2)
	var list_r := Rect2()
	if rijen is Control:
		list_r = (rijen as Control).get_global_rect()
		t.check("%s: lijst onder uitleg (uitleg eind %.0f <= lijst %.0f)" % [tag, lr.end.y, list_r.position.y],
				lr.end.y <= list_r.position.y + 0.5)
		t.check("%s: geen overlap uitleg/lijst", not _rect_overlap(lr, list_r))
	pw.queue_free()
	await t.pframes(2)


func _check_party_select_hub(t: Node, tag: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	t.get_tree().root.add_child(layer)
	var ps: Control = PartySelectScene.instantiate()
	layer.add_child(ps)
	await t.pframes(2)
	ps.open()
	await t.pframes(6)
	var uitleg := ps.find_child("Uitleg", true, false) as Label
	var band := ps.find_child("UitlegBand", true, false) as Control
	var scroll := ps.find_child("Lijst", true, false) as Control
	var safe: Rect2 = t.safe()
	t.check("%s: hub Party-uitleg exact", uitleg != null and uitleg.text == HUB_PARTY_UITLEG)
	t.check("%s: hub Party-uitleg autowrap", uitleg != null and uitleg.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART)
	if band == null or uitleg == null:
		ps.close()
		layer.queue_free()
		await t.pframes(2)
		return
	var ur := band.get_global_rect()
	t.check("%s: hub Party-uitleg binnen safe %s (%s)" % [tag, safe, ur], t.within(ur, safe))
	if scroll != null:
		var sr := scroll.get_global_rect()
		t.check("%s: hub Party-lijst onder uitleg (eind %.0f <= %.0f)" % [tag, ur.end.y, sr.position.y],
				ur.end.y <= sr.position.y + 0.5)
		t.check("%s: hub Party geen overlap uitleg/lijst", not _rect_overlap(ur, sr))
	ps.close()
	layer.queue_free()
	await t.pframes(2)


func _check_shop_hint(t: Node, shop: Node, tag: String) -> void:
	await t.pframes(6)
	shop.call("_apply_safe_area")
	shop.call("_layout_shop_hint")
	await t.pframes(4)
	var hint: Label = shop.get("hint")
	var band: Control = shop.get("_hint_band")
	var scroll := shop.find_child("ShopScroll", true, false) as Control
	var safe: Rect2 = t.safe()
	t.check("%s: winkel-hint exact" % tag, hint != null and str(shop.get("hint_text")) == SHOP_HINT)
	if hint == null or band == null:
		return
	var hr := band.get_global_rect()
	var marge_onder := 12.0 if "portrait" in tag else 2.0
	t.check("%s: winkel-hint binnen safe %s (%s)" % [tag, safe, hr],
			hr.position.x >= safe.position.x - 0.5 and hr.end.x <= safe.end.x + 0.5
			and hr.position.y >= safe.position.y - 0.5 and hr.end.y <= safe.end.y + marge_onder)
	if scroll != null:
		var sr := scroll.get_global_rect()
		t.check("%s: winkel-hint onder lijst (lijst eind %.0f <= hint %.0f)" % [tag, sr.end.y, hr.position.y],
				sr.end.y <= hr.position.y + 0.5)
		t.check("%s: geen overlap hint/lijst" % tag, not _rect_overlap(hr, sr))


func _check_shops(t: Node, tag: String) -> void:
	var shop: Node = ShopScreenS.new()
	shop.shop_id = "wilgendal_magie"
	t.get_tree().root.add_child(shop)
	await _check_shop_hint(t, shop, tag + " Wilgendal")
	shop.call("_show_held", "heal")
	await t.pframes(4)
	t.check("%s: magie-leer exact" % tag, shop.get("hint_text") == SPELL_LEARN)
	shop.queue_free()
	await t.pframes(2)
	var koop: Node = KoopmanSchermS.new()
	t.get_tree().root.add_child(koop)
	await _check_shop_hint(t, koop, tag + " Koopman")
	koop.queue_free()
	await t.pframes(2)


func _keeper_flow(t: Node) -> void:
	var rij: Dictionary = Dorp.pand("pantser")
	var verwacht: Array = rij.get("keeper_lines", [])
	if Dialog.is_open:
		Dialog.close()
		await t.pframes(4)
	if not GameState.change_map(BINNEN, "pantser"):
		t.check("F6.3: pantser binnen laden", false)
		return
	var kamer: Node = null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		await t.pframes(2)
		var n := t.get_tree().current_scene
		if n != null and "map_name" in n and str(n.get("map_name")) == str(rij.get("map_naam", "")):
			kamer = n
			break
	t.check("F6.3: pantser binnen scene", kamer != null)
	if kamer == null:
		return
	await t.pframes(6)
	var bank: Node = kamer.get_node_or_null("Objects/Toonbank")
	var speler: Node = kamer.get_node("Objects/Player")
	t.check("F6.3: toonbank aanwezig", bank != null)
	if bank == null:
		return
	bank.call("interact", speler)
	await t.pframes(4)
	t.check("F6.3: keeper-regels vóór winkel (dialoog open)", Dialog.is_open)
	t.check("F6.3: geen winkel tijdens regels", kamer.get_node_or_null("ShopScreen") == null)
	if Dialog.is_open and verwacht.size() > 0:
		t.check("F6.3: eerste keeper-regel exact", str(Dialog._lines[0]) == str(verwacht[0]))
	while Dialog.is_open:
		if Dialog.has_choices():
			Dialog.choose(0)
		else:
			Dialog.advance()
		await t.pframes(2)
	await t.pframes(4)
	var scherm := kamer.get_node_or_null("ShopScreen")
	t.check("F6.3: winkel na keeper-regels", scherm != null and scherm.shop_id == str(rij["shop_id"]))
	if scherm != null:
		scherm.close()
		await t.pframes(2)
	var npc: Node = NpcScene.instantiate()
	npc.event = "shop"
	npc.event_arg = "wilgendal_wapen"
	var geen_regels: Array[String] = []
	npc.lines = geen_regels
	t.get_tree().root.add_child(npc)
	var dummy := Node2D.new()
	t.get_tree().root.add_child(dummy)
	dummy.set("facing", Vector2i.DOWN)
	npc.call("interact", dummy)
	await t.pframes(6)
	t.check("F6.3: winkel direct zonder keeper-regels", not Dialog.is_open
			and t.get_tree().current_scene.get_node_or_null("ShopScreen") != null)
	var direct := t.get_tree().current_scene.get_node_or_null("ShopScreen")
	if direct != null:
		direct.queue_free()
	npc.queue_free()
	dummy.queue_free()
	await t.pframes(2)


func _check_warp_uitleg(t: Node, tag: String) -> void:
	GameState.story_flags.erase(SD.WARP_UITLEG_FLAG)
	var layer := CanvasLayer.new()
	layer.layer = 40
	t.get_tree().root.add_child(layer)
	var wv: Control = WarpViewS.new()
	layer.add_child(wv)
	await t.pframes(2)
	wv.open()
	await t.pframes(8)
	wv.call("_place_at_anchor")
	wv.call("_layout_uitleg")
	await t.pframes(4)
	var band := wv.find_child("UitlegBand", true, false) as Control
	var lab := wv.find_child("Uitleg", true, false) as Label
	var travel := wv.find_child("Reis", true, false) as Button
	var safe: Rect2 = t.safe()
	t.check("%s: Warp Travel-knop bestaat" % tag, travel != null and travel.text == "Travel")
	t.check("%s: Warp-uitleg exact" % tag, lab != null and lab.text == WARP_UITLEG)
	t.check("%s: Warp-uitleg eerste open" % tag, band != null and band.visible)
	var paneel := wv.get_global_rect()
	t.check("%s: Warp-paneel binnen safe" % tag, t.within(paneel, safe))
	if band != null:
		var br := band.get_global_rect()
		var marge_onder := 12.0 if "portrait" in tag else 2.0
		t.check("%s: Warp-uitleg binnen safe (%s)" % [tag, br],
				br.position.x >= safe.position.x - 0.5 and br.end.x <= safe.end.x + 0.5
				and br.position.y >= safe.position.y - 0.5 and br.end.y <= safe.end.y + marge_onder)
	var rijen := wv.find_child("Rijen", true, false) as Control
	if band != null and rijen != null:
		var br := band.get_global_rect()
		var rr := rijen.get_global_rect()
		t.check("%s: Warp-lijst onder uitleg" % tag, br.end.y <= rr.position.y + 0.5)
	wv.close()
	wv.open()
	await t.pframes(6)
	t.check("%s: Warp-uitleg niet opnieuw" % tag, band != null and not band.visible)
	t.check("%s: Warp-vlag gezet" % tag, GameState.story_flags.has(SD.WARP_UITLEG_FLAG))
	var path := "user://f6_17_warp_uitleg.json"
	var tile := Vector2i.ZERO
	if GameState.party.size() > 0:
		tile = Vector2i(4, 4)
	t.check("%s: Warp save met vlag" % tag, GameState.save_game(tile, Vector2i.DOWN, path))
	GameState.story_flags.erase(SD.WARP_UITLEG_FLAG)
	t.check("%s: Warp load herstelt vlag" % tag, GameState.load_game(path) and GameState.story_flags.has(SD.WARP_UITLEG_FLAG))
	wv.open()
	await t.pframes(6)
	t.check("%s: na load geen tweede Warp-uitleg" % tag, band != null and not band.visible)
	wv.close()
	layer.queue_free()
	await t.pframes(2)


func _run_line_once(t: Node) -> void:
	GameState.story_flags.erase(SD.RUN_UITLEG_FLAG)
	if not GameState.change_map("res://scenes/maps/huis_wilgendal.tscn", "bed"):
		t.check("F6.3: kaart huis laden", false)
		return
	var ok: bool = await t.sc.wait_scene("Huis", 12.0)
	t.check("F6.3: huis geladen", ok)
	if not ok:
		return
	await t.pframes(8)
	var m: Node = t.sc.scene()
	var p: Node = m.get_node_or_null("Objects/Player")
	t.check("F6.3: speler aanwezig", p != null)
	if p == null:
		return
	var tile: Vector2i = p.get_tile()
	m.call("_on_player_stepped", tile)
	await t.pframes(2)
	var zag := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		if Dialog.is_open:
			zag = true
			break
		await t.pframes(2)
	t.check("F6.3: RUN-uitleg na eerste vrije stap", zag and str(Dialog._lines[0]) == SD.RUN_UITLEG_LINE)
	t.check("F6.3: vlag gezet", GameState.story_flags.has(SD.RUN_UITLEG_FLAG))
	while Dialog.is_open:
		if Dialog.has_choices():
			Dialog.choose(0)
		else:
			Dialog.advance()
		await t.pframes(2)
	await t.pframes(2)
	var vlag := GameState.story_flags.has(SD.RUN_UITLEG_FLAG)
	m.call("_on_player_stepped", tile)
	await t.pframes(4)
	t.check("F6.3: tweede stap geen RUN-uitleg", vlag and not Dialog.is_open)
	var path := "user://f6_17_run_uitleg.json"
	t.check("F6.3: save met vlag", GameState.save_game(p.get_tile(), Vector2i.DOWN, path))
	GameState.story_flags.erase(SD.RUN_UITLEG_FLAG)
	t.check("F6.3: load herstelt vlag", GameState.load_game(path) and GameState.story_flags.has(SD.RUN_UITLEG_FLAG))
	m.call("_on_player_stepped", tile)
	await t.pframes(4)
	t.check("F6.3: na load nog steeds geen tweede RUN-uitleg", not Dialog.is_open)


func _run_blocked(t: Node) -> void:
	GameState.story_flags.erase(SD.RUN_UITLEG_FLAG)
	if not GameState.change_map("res://scenes/maps/huis_wilgendal.tscn", "bed"):
		return
	await t.sc.wait_scene("Huis", 12.0)
	await t.pframes(4)
	var p: Node = t.sc.scene().get_node("Objects/Player")
	GameState.in_battle = true
	RunUitleg.op_stap(p)
	await t.pframes(4)
	t.check("F6.3: geen RUN-uitleg tijdens gevecht", not Dialog.is_open and not GameState.story_flags.has(SD.RUN_UITLEG_FLAG))
	GameState.in_battle = false
	Story.running = true
	RunUitleg.op_stap(p)
	await t.pframes(4)
	t.check("F6.3: geen RUN-uitleg tijdens cutscene", not Dialog.is_open and not GameState.story_flags.has(SD.RUN_UITLEG_FLAG))
	Story.running = false


func _molen_leader_flow(t: Node) -> void:
	t.check("F6.3: molen keuze Change leader", Molen.KEUZES[1] == "Change leader")
	t.check("F6.3: molen follow-up exact", Molen.REGEL_PARTY_MENU == MOLEN_FOLLOW)
	if GameState.party.size() < 2:
		while GameState.party.size() < 2:
			GameState.party.append({"name": "Vesper", "id": "noor", "level": 1, "hp": 10, "max_hp": 10, "mp": 5, "max_mp": 5})
	var state := {"follow": false, "klaar": false}
	var worker := func() -> void:
		await Molen._wissel()
		state["klaar"] = true
	worker.call()
	await t.pframes(4)
	var t0 := Time.get_ticks_msec()
	while not state["klaar"] and Time.get_ticks_msec() - t0 < 8000:
		if Dialog.is_open:
			for ln in Dialog._lines:
				if str(ln) == MOLEN_FOLLOW:
					state["follow"] = true
			if Dialog.has_choices() and str(Dialog.choices[0]) in ["Yes", "Save", "Done"]:
				Dialog.choose(1)
			elif Dialog.has_choices() and Dialog.choices.size() >= 2:
				Dialog.choose(1)
			elif not Dialog._is_typing():
				Dialog.advance()
		await t.pframes(2)
	var front := str(GameState.party[0].get("id", "")) if GameState.party.size() > 0 else ""
	t.check("F6.3: na leiderwissel follow-up getoond", state["follow"])
	t.check("F6.3: leiderwissel gedrag ongewijzigd", front == "noor")
	while Dialog.is_open:
		Dialog.advance()
		await t.pframes(2)


func run(t: Node) -> void:
	t.check("F6.3: RUN-uitlegregel exact", SD.RUN_UITLEG_LINE
			== "Tap RUN at the top right to move faster. Tap it again to walk. It stays on until you turn it off.")
	t.check("F6.3: RUN-vlag key", SD.RUN_UITLEG_FLAG == "run_uitleg_gezien")
	t.check("F6.3: Party-scherm hint exact", PartyScreenS.HINT == PARTY_HINT)
	t.check("F6.3: Rustkamer-uitlegtekst constant", PartyWisselS.UITLEG == WISSEL_UITLEG)
	t.check("F6.3: hub Party-uitleg constant", PartySelectGd.UITLEG == HUB_PARTY_UITLEG)
	t.check("F6.3: winkel-hint constant", ShopScreenS.HINT == SHOP_HINT)
	t.check("F6.3: magie-leer constant", ShopScreenS.SPELL_LEARN == SPELL_LEARN)
	t.check("F6.3: Warp-uitleg constant", SD.WARP_UITLEG_LINE == WARP_UITLEG)
	await _run_line_once(t)
	await _run_blocked(t)
	await _molen_leader_flow(t)
	await _keeper_flow(t)
	for cs in PHONE_CASES:
		await _set_viewport(t, cs[1], cs[2])
		await _check_party_screen_hint(t, "F6-3 Party [%s]" % cs[0])
		await _check_party_wissel_layout(t, "F6-3 Wissel [%s]" % cs[0])
		await _check_party_select_hub(t, "F6-3 HubParty [%s]" % cs[0])
		await _check_shops(t, "F6-3 [%s]" % cs[0])
		await _check_warp_uitleg(t, "F6-3 Warp [%s]" % cs[0])
	UiTouch.insets_override = null
	await t.sc.set_profile("16x9")