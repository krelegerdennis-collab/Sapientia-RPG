extends RefCounted
## F6-T12: hub Warp/Party/Simulatie — collision-tikvlak >= 25x25; hoek-tikken; geen A op diagonaal.
## Registratie: map-scan in scripts/tests/f6_ux2_tests.gd (--f6uxtest2).

const Kamers := preload("res://world_warper/kamers/kamers.gd")
const HubBootS := preload("res://world_warper/flow/hub_boot.gd")
const HAL := "res://world_warper/maps/hal.tscn"
const TILE := 16
const MIN_SHAPE := 25.0
const TAP_OFFS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2(12, 12),
	Vector2(-12, 12),
	Vector2(12, -12),
	Vector2(-12, -12),
]

const CANON_FLAGS: Array[String] = [
	"ww_canon_genezer_gezien",
	"ww_canon_hanger_gezien",
	"ww_canon_dreiging_gezien",
]


func needs_game() -> bool:
	return true


func _world_vp(t: Node, world: Vector2) -> Vector2:
	return t.get_viewport().get_canvas_transform() * world


func _tap_world(t: Node, world: Vector2) -> void:
	var gp := _world_vp(t, world)
	var win := t.get_tree().root.get_final_transform() * gp
	var st := InputEventScreenTouch.new()
	st.index = 20
	st.device = 0
	st.pressed = true
	st.position = win
	Input.parse_input_event(st)
	await t.pframes(3)
	st.pressed = false
	Input.parse_input_event(st)
	await t.pframes(4)


func _press_interact(t: Node) -> void:
	await t.pframes(1)
	Input.action_press("interact")
	for _i in 4:
		await t.get_tree().physics_frame
	Input.action_release("interact")
	await t.pframes(4)


func _vlak_shape(vlak: Area2D) -> Vector2:
	for c in vlak.get_children():
		if c is CollisionShape2D:
			var sh := (c as CollisionShape2D).shape
			if sh is RectangleShape2D:
				return (sh as RectangleShape2D).size
	return Vector2.ZERO


func _kies_nee_sim() -> void:
	if not Dialog.is_open:
		return
	if str(Dialog.text_label.text) != HubBootS.SIMULATIE_VRAAG:
		return
	if not Dialog.has_choices():
		return
	var i := 0
	for c in Dialog.choices:
		if str(c) == HubBootS.SIMULATIE_NEE:
			Dialog.choose(i)
			return
		i += 1


func _sluit_schermen(t: Node, hal: Node2D) -> void:
	if not is_instance_valid(hal):
		return
	var warp := hal.get_node_or_null("HubBoot/Scherm/WarpView") as Control
	var party := hal.get_node_or_null("HubBoot/Scherm/PartySelect") as Control
	if warp != null and warp.visible:
		warp.call("close")
	if party != null and bool(party.call("is_open")):
		party.call("close")
	var t0 := Time.get_ticks_msec()
	while Dialog.is_open and Time.get_ticks_msec() - t0 < 6000:
		_kies_nee_sim()
		if Dialog.is_open and not Dialog.has_choices():
			Dialog.advance()
		await t.pframes(2)
	await t.pframes(2)


func _laad_hal(t: Node) -> Node2D:
	GameState.story_flags[Kamers.FLAG_HUB] = true
	for f in CANON_FLAGS:
		GameState.story_flags[f] = true
	GameState.change_map(HAL, "ingang")
	var hal: Node2D = null
	for _i in 420:
		await t.pframes(1)
		var nu := t.get_tree().current_scene
		if nu != null and nu.scene_file_path == HAL and not GameState.changing_map and nu.is_node_ready():
			hal = nu as Node2D
			break
	t.check("F6-T12: hub-hal geladen", hal != null)
	if hal == null:
		return null
	await t.pframes(8)
	return hal


func _check_shapes(t: Node, hal: Node2D) -> void:
	for naam in ["VlakWarp", "VlakGezelschap", "VlakSimulatie"]:
		var vlak := hal.get_node_or_null("HubBoot/%s" % naam) as Area2D
		t.check("F6-T12: %s aanwezig" % naam, vlak != null)
		if vlak == null:
			continue
		var sz := _vlak_shape(vlak)
		t.check(
				"F6-T12: %s shape >= %.0fx%.0f (nu %.1fx%.1f)" % [naam, MIN_SHAPE, MIN_SHAPE, sz.x, sz.y],
				sz.x >= MIN_SHAPE and sz.y >= MIN_SHAPE)


func _warp_open(hal: Node2D) -> bool:
	var warp := hal.get_node_or_null("HubBoot/Scherm/WarpView") as Control
	return warp != null and warp.visible


func _party_open(hal: Node2D) -> bool:
	var party := hal.get_node_or_null("HubBoot/Scherm/PartySelect") as Control
	return party != null and bool(party.call("is_open"))


func _sim_vraag_open() -> bool:
	return Dialog.is_open and str(Dialog.text_label.text) == HubBootS.SIMULATIE_VRAAG


func _vlak_via_a(speler: Node, vlak: Area2D) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = speler.global_position + Vector2(speler.facing) * TILE
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [speler.get_rid()]
	for hit in speler.get_world_2d().direct_space_state.intersect_point(query):
		if hit.get("collider") == vlak:
			return true
	return false


func _test_taps(t: Node, hal: Node2D) -> void:
	var cases: Array[Dictionary] = [
		{"naam": "VlakWarp", "open": _warp_open.bind(hal), "tag": "warp"},
		{"naam": "VlakGezelschap", "open": _party_open.bind(hal), "tag": "party"},
		{"naam": "VlakSimulatie", "open": _sim_vraag_open, "tag": "sim"},
	]
	for c in cases:
		var vlak := hal.get_node_or_null("HubBoot/%s" % c["naam"]) as Area2D
		if vlak == null:
			continue
		for off in TAP_OFFS:
			await _sluit_schermen(t, hal)
			var p := vlak.global_position + off
			await _tap_world(t, p)
			var wacht := 12 if c["tag"] == "sim" else 6
			for _w in wacht:
				if c["open"].call():
					break
				await t.pframes(1)
			var ok: bool = c["open"].call()
			t.check("F6-T12: tik %s op %s%s opent %s" % [c["tag"], c["naam"], off, c["tag"]], ok)
			await _sluit_schermen(t, hal)


func _test_diagonaal_geen_a(t: Node, hal: Node2D) -> void:
	var vlak := hal.get_node_or_null("HubBoot/VlakWarp") as Area2D
	var speler := hal.get_node_or_null("Objects/Player")
	t.check("F6-T12: speler in hal", speler != null and vlak != null)
	if speler == null or vlak == null:
		return
	var warp_tile := Vector2i((vlak.global_position / float(TILE)).floor())
	# Dichtstbijzijnde diagonaal (noordoost): geen van de vier A-ray hits bij 26x26 met facing LINKS.
	speler.place_at(warp_tile + Vector2i(1, -1), Vector2i.LEFT)
	await t.pframes(4)
	await _sluit_schermen(t, hal)
	await _press_interact(t)
	await t.pframes(4)
	t.check("F6-T12: diagonaal naast Warp + A opent geen warp", not _warp_open(hal))
	t.check("F6-T12: diagonaal naast Warp + A opent geen party", not _party_open(hal))
	t.check("F6-T12: diagonaal naast Warp + A opent geen sim-dialoog", not _sim_vraag_open())


func _test_kaart_ad_kolom(t: Node, hal: Node2D) -> void:
	if not is_instance_valid(hal):
		t.check("F6-T12: hal nog geladen voor A-test", false)
		return
	## Recht vóór het vlak: point-query op 16 px moet nog wél raken (nearest-tile).
	var vlak := hal.get_node_or_null("HubBoot/VlakWarp") as Area2D
	var speler := hal.get_node_or_null("Objects/Player")
	if speler == null or vlak == null:
		return
	var warp_tile := Vector2i((vlak.global_position / float(TILE)).floor())
	speler.place_at(warp_tile + Vector2i.DOWN, Vector2i.UP)
	await t.pframes(4)
	t.check("F6-T12: point-query vóór Warp raakt vlak", _vlak_via_a(speler, vlak))
	await _sluit_schermen(t, hal)
	if speler.input_locked:
		speler.input_locked = false
	await _press_interact(t)
	await t.pframes(6)
	t.check("F6-T12: kaartveld vóór Warp + A opent warp", _warp_open(hal))
	await _sluit_schermen(t, hal)


func run(t: Node) -> void:
	var hal := await _laad_hal(t)
	if hal == null:
		return
	_check_shapes(t, hal)
	await _test_taps(t, hal)
	await _test_kaart_ad_kolom(t, hal)
	await _test_diagonaal_geen_a(t, hal)