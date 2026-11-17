extends RefCounted
## F6 titel: de stage van 384x216 staat gecentreerd in UiTouch.safe_rect. Past de stage op een
## as niet in die rect, dan blijft het midden geklemd op [0, venster - stage] (16:9 met
## zij-insets 30 blijft op x 0; de stage en het kaartje blijven in het kijkvenster).
## Het kaartje blijft t.o.v. de stage op x 240..372, y 148..201 (ux_tests) en ligt in de
## safe rect zodra dat kan zonder de stage uit beeld te duwen. Met insets 0 is de plek
## pixel-gelijk aan centreren in het volle venster.

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const STAGE := Vector2(384, 216)
## [profiel, insets, verwacht stage.position, stage past in safe, kaartje kan in safe]
const CASES := [
	["16x9", Vector4(0, 0, 0, 0), Vector2(0, 0), true, true],
	["19_5x9", Vector4(0, 0, 0, 0), Vector2(42, 0), true, true],
	["16x9", Vector4(30, 0, 30, 0), Vector2(0, 0), false, false],
	["19_5x9", Vector4(30, 0, 30, 0), Vector2(42, 0), true, true],
	["19_5x9_notch", Vector4(22, 4, 10, 6), Vector2(48, 0), false, true],
]


func run(t: Node) -> void:
	if t.sc.scene() == null or t.sc.scene().name != "Title":
		t.get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
		if not await t.sc.wait_scene("Title"):
			t.check("F6 titel: titelscherm staat open", false)
			UiTouch.insets_override = null
			return
		await t.pframes(8)
	var titel: Node = t.sc.scene()
	t.check("F6 titel: titelscherm met stage en kaartje", titel != null and titel.get("stage") != null and titel.get("card") != null)
	if titel == null or titel.get("stage") == null:
		UiTouch.insets_override = null
		return
	for cs in CASES:
		var profiel: String = cs[0]
		var ins: Vector4 = cs[1]
		var verwacht: Vector2 = cs[2]
		var stage_past: bool = cs[3]
		var kaart_past: bool = cs[4]
		await t.sc.set_profile(profiel)
		UiTouch.insets_override = ins
		await t.pframes(6)
		var vp: Vector2 = titel.size
		var venster: Vector2 = t.get_viewport().get_visible_rect().size
		var prof: Vector2 = Vector2(Scenarios.PROFILES[profiel])
		var tag := "F6 titel [%s insets %s]" % [profiel, ins]
		t.check("%s viewport %s (profiel %s, venster %s)" % [tag, vp, prof, venster],
				vp.is_equal_approx(prof) and venster.is_equal_approx(prof))
		var st: Rect2 = (titel.stage as Control).get_global_rect()
		var oud := ((vp - STAGE) / 2.0).floor()
		var beeld := Rect2(Vector2.ZERO, vp)
		t.check("%s stage 384x216 op %s (verwacht %s, volle-venster-midden %s)" % [tag, st.position, verwacht, oud],
				st.size.is_equal_approx(STAGE) and (titel.stage as Control).position.is_equal_approx(verwacht))
		if ins == Vector4.ZERO:
			t.check("%s insets 0: pixel-gelijk aan het midden van het volle venster" % tag,
					(titel.stage as Control).position.is_equal_approx(oud))
		var safe := Rect2(Vector2(ins.x, ins.y), vp - Vector2(ins.x + ins.z, ins.y + ins.w))
		var kaart: Rect2 = (titel.card as Control).get_global_rect()
		t.check("%s stage en kaartje volledig in het venster (stage %s, kaart %s)" % [tag, st, kaart],
				t.within(st, beeld) and t.within(kaart, beeld))
		if stage_past:
			t.check("%s stage binnen safe %s (stage %s)" % [tag, safe, st], t.within(st, safe))
		var lokaal := kaart
		lokaal.position -= st.position
		var kan: bool = _kaart_past(vp, safe, lokaal)
		t.check("%s kaartje kan in safe: %s (verwacht %s, safe %s, lokaal %s)" % [tag, kan, kaart_past, safe, lokaal],
				kan == kaart_past)
		if kan:
			t.check("%s kaartje binnen safe %s (kaart %s)" % [tag, safe, kaart], t.within(kaart, safe))
		t.check("%s kaartje blijft rechtsonder t.o.v. de stage (x 240..372, y 148..201): %s" % [tag, lokaal],
				absf(lokaal.position.x - 240.0) <= 1.0 and absf(lokaal.end.x - 372.0) <= 1.0
				and lokaal.end.y <= 201.0 and lokaal.position.y >= 148.0)
		await t.shot("f6_title_%s_%d_%d_%d_%d" % [profiel, int(ins.x), int(ins.y), int(ins.z), int(ins.w)])
	UiTouch.insets_override = null
	await t.pframes(2)


## Er is een stage-plek waarbij de stage volledig in het venster blijft en het kaartje
## volledig in de safe rect ligt. Past de stage in de safe rect, dan telt alleen die klem.
static func _kaart_past(vp: Vector2, safe: Rect2, lokaal: Rect2) -> bool:
	var lo := Vector2.ZERO
	var hi := Vector2(maxf(0.0, vp.x - STAGE.x), maxf(0.0, vp.y - STAGE.y))
	if safe.size.x >= STAGE.x:
		lo.x = maxf(lo.x, safe.position.x)
		hi.x = minf(hi.x, maxf(safe.position.x, safe.end.x - STAGE.x))
	if safe.size.y >= STAGE.y:
		lo.y = maxf(lo.y, safe.position.y)
		hi.y = minf(hi.y, maxf(safe.position.y, safe.end.y - STAGE.y))
	var clo := safe.position - lokaal.position
	var chi := safe.end - (lokaal.position + lokaal.size)
	return maxf(lo.x, clo.x) <= minf(hi.x, chi.x) + 0.01 and maxf(lo.y, clo.y) <= minf(hi.y, chi.y) + 0.01
