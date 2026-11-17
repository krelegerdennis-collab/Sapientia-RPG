extends RefCounted
## UX-polish 4.3: World Warper warp-view binnen UiTouch.safe_rect.
## 16:9, 19,5:9 en een notch (insets_override). Insets 0 blijft het volle vlak met 6 px marge.
## Knoppen (wereld + Back/Travel) blijven binnen de veilige zone en houden 96x32.
##
## Registratie: dit bestand hoort in scripts/tests/f6_ux2/. De bestaande runner
## scripts/tests/f6_ux2_tests.gd laadt elk *.gd in die map (geen wijziging aan de runner,
## game_state.gd of tests.yml). Draaien: godot --path . -- --f6uxtest2
## (--f6uxtest2 zit al in de CI-matrix.)

const WarpScene := preload("res://world_warper/warp/warp_view.tscn")
## [profiel, insets (links, boven, rechts, onder)]
const CASES := [
	["16x9", Vector4(30, 0, 30, 0)],
	["19_5x9", Vector4(30, 0, 30, 0)],
	["19_5x9_notch", Vector4(22, 4, 10, 6)],
]
const MARGE := 6.0
const KNOP := Vector2(96, 32)


func needs_game() -> bool:
	return false


static func _dicht(a: float, b: float, tol := 0.5) -> bool:
	return absf(a - b) <= tol


static func _zelfde(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= 0.5 and a.size.distance_to(b.size) <= 0.5


static func _sized(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control and (n as Control).size.x > 0.0 and (n as Control).size.y > 0.0:
		out.append(n)
	for c in n.get_children():
		_sized(c, out)


func _profiel(t: Node, naam: String, ins: Vector4) -> void:
	await t.sc.set_profile(naam)
	UiTouch.insets_override = ins
	await t.pframes(2)


func _open(t: Node, anker_pos: Variant, anker_size: Vector2) -> Array:
	var layer := CanvasLayer.new()
	layer.layer = 45
	t.get_tree().root.add_child(layer)
	if anker_pos != null:
		var anker := Control.new()
		anker.name = "AnkerWarp"
		anker.add_to_group("ww_anchor_warp")
		layer.add_child(anker)
		anker.size = anker_size
		anker.global_position = anker_pos
	var view: Control = WarpScene.instantiate()
	layer.add_child(view)
	await t.pframes(2)
	view.open()
	await t.pframes(4)
	return [layer, view]


func _dicht_doen(t: Node, layer: Node) -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	await t.pframes(2)


func _check_binnen(t: Node, tag: String, top: Node) -> void:
	var safe: Rect2 = t.safe()
	var ctl: Array = []
	_sized(top, ctl)
	var out: Array = []
	for c in ctl:
		var r := (c as Control).get_global_rect()
		if not t.within(r, safe):
			out.append("%s %s" % [(c as Control).name, r])
	t.check("%s: %d Controls binnen safe %s (buiten: %s)" % [tag, ctl.size(), safe, out.slice(0, 6)],
			not ctl.is_empty() and out.is_empty())


func _check_marge_en_knoppen(t: Node, tag: String, view: Control, tegen_safe: bool) -> void:
	var marge := view.get_node_or_null("Marge") as MarginContainer
	var marge_ok := marge != null \
			and marge.get_theme_constant("margin_left") == 6 \
			and marge.get_theme_constant("margin_top") == 6 \
			and marge.get_theme_constant("margin_right") == 6 \
			and marge.get_theme_constant("margin_bottom") == 6
	t.check("%s: inhoudsmarge blijft 6 px" % tag, marge_ok)
	var safe: Rect2 = t.safe()
	var zone := safe if tegen_safe else view.get_global_rect()
	var titel := view.find_child("Titel", true, false) as Label
	var terug := view.find_child("Terug", true, false) as Button
	var reis := view.find_child("Reis", true, false) as Button
	var titel_r := titel.get_global_rect() if titel != null else Rect2()
	var terug_r := terug.get_global_rect() if terug != null else Rect2()
	var reis_r := reis.get_global_rect() if reis != null else Rect2()
	t.check("%s: titel en Back/Travel 6 px binnen %s (titel %s, terug %s, reis %s)" % [tag, zone, titel_r, terug_r, reis_r],
			titel != null and terug != null and reis != null
			and _dicht(titel_r.position.x, zone.position.x + MARGE)
			and _dicht(titel_r.position.y, zone.position.y + MARGE)
			and _dicht(terug_r.position.x, zone.position.x + MARGE)
			and _dicht(terug_r.end.y, zone.end.y - MARGE)
			and _dicht(reis_r.end.x, zone.end.x - MARGE)
			and _dicht(reis_r.end.y, zone.end.y - MARGE)
			and t.within(terug_r, zone) and t.within(reis_r, zone))
	var maat_ok := true
	var gezien := 0
	for id in ["WM1", "WM2", "WM3"]:
		var k := view.find_child("Rij_%s" % id, true, false) as TextureButton
		if k == null or k.custom_minimum_size != KNOP:
			maat_ok = false
		else:
			gezien += 1
			if not t.within(k.get_global_rect(), zone.grow(-MARGE + 0.5)):
				maat_ok = false
	t.check("%s: wereldknoppen 96x32 en binnen de 6 px-marge (%d)" % [tag, gezien], maat_ok and gezien == 3)


func _check_zonder_anker(t: Node, tag: String, shot: String) -> void:
	var geopend: Array = await _open(t, null, Vector2.ZERO)
	var layer: Node = geopend[0]
	var view := geopend[1] as Control
	var safe: Rect2 = t.safe()
	t.check("%s: view vult precies safe %s (view %s)" % [tag, safe, view.get_global_rect()],
			_zelfde(view.get_global_rect(), safe))
	_check_binnen(t, tag, view)
	_check_marge_en_knoppen(t, tag, view, true)
	await t.shot(shot)
	var wm1 := view.find_child("Rij_WM1", true, false) as TextureButton
	if wm1 != null and not wm1.disabled:
		wm1.pressed.emit()
		await t.pframes(4)
		_check_binnen(t, tag + " bestemmingen", view)
		var dorp := view.find_child("Rij_wilgendal", true, false) as TextureButton
		t.check("%s: Willowdale-knop 96x32 binnen safe" % tag,
				dorp != null and dorp.custom_minimum_size == KNOP and t.within(dorp.get_global_rect(), safe))
	await _dicht_doen(t, layer)


func _knopmaat(view: Control) -> bool:
	for id in ["WM1", "WM2", "WM3"]:
		var k := view.find_child("Rij_%s" % id, true, false) as TextureButton
		if k == null or k.custom_minimum_size != KNOP:
			return false
	return true


## Insets 0: geen clamp. Een anker kleiner dan VIEW_SIZE blijft op zijn plek;
## de maat wordt VIEW_SIZE omdat custom_minimum_size dat al afdwong.
func _check_anker_nul(t: Node, tag: String, pos: Vector2, sz: Vector2) -> void:
	var geopend: Array = await _open(t, pos, sz)
	var layer: Node = geopend[0]
	var view := geopend[1] as Control
	var verwacht := Rect2(pos, Vector2(maxf(sz.x, 384.0), maxf(sz.y, 216.0)))
	t.check("%s: insets 0 laat ankerplaats %s (view %s)" % [tag, verwacht, view.get_global_rect()],
			_zelfde(view.get_global_rect(), verwacht))
	t.check("%s: wereldknoppen blijven 96x32" % tag, _knopmaat(view))
	await _dicht_doen(t, layer)


func _check_anker(t: Node, tag: String, pos: Vector2, sz: Vector2, verwacht_gelijk: bool) -> void:
	var geopend: Array = await _open(t, pos, sz)
	var layer: Node = geopend[0]
	var view := geopend[1] as Control
	var safe: Rect2 = t.safe()
	_check_binnen(t, tag, view)
	if verwacht_gelijk:
		var doel := Rect2(pos, sz)
		t.check("%s: ankerplaats ongewijzigd %s (view %s)" % [tag, doel, view.get_global_rect()],
				_zelfde(view.get_global_rect(), doel))
	else:
		t.check("%s: view binnen safe %s (view %s)" % [tag, safe, view.get_global_rect()],
				t.within(view.get_global_rect(), safe))
	var terug := view.find_child("Terug", true, false) as Button
	var reis := view.find_child("Reis", true, false) as Button
	var knoppen_binnen := true
	for id in ["WM1", "WM2", "WM3"]:
		var k := view.find_child("Rij_%s" % id, true, false) as TextureButton
		if k == null or not t.within(k.get_global_rect(), safe):
			knoppen_binnen = false
	t.check("%s: knoppen 96x32 en Back/Travel binnen safe" % tag,
			_knopmaat(view) and knoppen_binnen and terug != null and reis != null
			and t.within(terug.get_global_rect(), safe) and t.within(reis.get_global_rect(), safe))
	await _dicht_doen(t, layer)


func run(t: Node) -> void:
	# Insets 0: pixel-gelijk aan het volle 384x216-vlak met harde 6 px-marge.
	await _profiel(t, "16x9", Vector4.ZERO)
	await _check_zonder_anker(t, "16x9 insets 0", "ux43_warp_16x9_zero")
	await _check_anker_nul(t, "16x9 insets 0 anker", Vector2(40, 24), Vector2(220, 160))
	await _profiel(t, "19_5x9", Vector4.ZERO)
	# Groter dan het scherm: insets 0 schuift het paneel niet terug de rand in.
	await _check_anker_nul(t, "19_5x9 insets 0 anker buiten", Vector2(80, 0), Vector2(400, 216))
	for cs in CASES:
		var naam := str(cs[0])
		await _profiel(t, naam, cs[1])
		var tag := "%s insets %s" % [naam, cs[1]]
		await _check_zonder_anker(t, tag, "ux43_warp_%s" % naam)
		await _check_anker(t, tag + " anker hoek", Vector2.ZERO, Vector2(20, 20), false)
		var vp: Vector2 = t.get_viewport().get_visible_rect().size
		await _check_anker(t, tag + " anker rand", vp - Vector2(60, 40), Vector2(20, 20), false)
		# Paneel >= VIEW_SIZE dat al in de safe rect past: niet verslepen.
		if naam == "19_5x9":
			await _check_anker(t, tag + " anker past", Vector2(40, 0), Vector2(384, 216), true)
	# Open op 16:9, daarna viewport én notch wisselen: opnieuw binnen safe.
	await _profiel(t, "16x9", Vector4(30, 0, 30, 0))
	var geopend: Array = await _open(t, null, Vector2.ZERO)
	var layer: Node = geopend[0]
	var view := geopend[1] as Control
	t.check("resize start: view == safe 16x9", _zelfde(view.get_global_rect(), t.safe()))
	await t.sc.set_profile("19_5x9_notch")
	UiTouch.insets_override = Vector4(22, 4, 10, 6)
	await t.pframes(4)
	var tag_rs := "resize 16x9 -> 19_5x9_notch"
	t.check("%s: view == safe %s (view %s)" % [tag_rs, t.safe(), view.get_global_rect()],
			_zelfde(view.get_global_rect(), t.safe()))
	_check_binnen(t, tag_rs, view)
	_check_marge_en_knoppen(t, tag_rs, view, true)
	await t.shot("ux43_warp_resize_notch")
	await _dicht_doen(t, layer)
	UiTouch.insets_override = null
	await t.sc.set_profile("16x9")
	await t.pframes(2)
