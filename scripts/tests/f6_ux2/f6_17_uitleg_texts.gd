extends RefCounted
## F6.3: exacte ENGELS-spelerteksten voor RUN, Party-scherm, molen en Rustkamer-wissel.
## Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const SD := preload("res://scripts/data/story_data.gd")
const PartyScreenS := preload("res://scripts/ui/party_screen.gd")
const Molen := preload("res://scripts/village/molen.gd")
const PartyWisselS := preload("res://world_warper/kamers/party_wissel.gd")
const RunUitleg := preload("res://scripts/run_uitleg.gd")
const PARTY_HINT := "Tap someone in Active, then someone in Reserve to swap. Back to close."
const WISSEL_UITLEG := "Tap a name to move them between Active and Bench. Dax stays in the party."
const MOLEN_FOLLOW := "To change who fights with you, open MENU, then Party."
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
	await _run_line_once(t)
	await _run_blocked(t)
	await _molen_leader_flow(t)
	for cs in PHONE_CASES:
		await _set_viewport(t, cs[1], cs[2])
		await _check_party_wissel_layout(t, "F6-3 [%s]" % cs[0])
	UiTouch.insets_override = null
	await t.sc.set_profile("16x9")