extends RefCounted
## F6 titel: de stage van 384x216 staat in UiTouch.safe_rect (gecentreerd, daarna geklemd),
## niet in het volle kijkvenster. Het kaartje blijft t.o.v. de stage op x 240..372, y 148..201
## (ux_tests). Met insets 0 is de plek pixel-gelijk aan centreren in het volle venster.
## Profielen: 16:9, 19,5:9 en een notch via insets_override.

const Scenarios := preload("res://tools/ui_polish/ui_scenarios.gd")
const STAGE := Vector2(384, 216)
## [profiel, insets (links, boven, rechts, onder), verwacht stage.position, past de stage in de safe rect?]
const CASES := [
	["16x9", Vector4(0, 0, 0, 0), Vector2(0, 0), true],
	["19_5x9", Vector4(0, 0, 0, 0), Vector2(42, 0), true],
	["16x9", Vector4(30, 0, 30, 0), Vector2(30, 0), false],
	["19_5x9", Vector4(30, 0, 30, 0), Vector2(42, 0), true],
	["19_5x9_notch", Vector4(22, 4, 10, 6), Vector2(48, 4), false],
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
		var past: bool = cs[3]
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
		t.check("%s stage 384x216 op %s (verwacht %s, volle-venster-midden %s)" % [tag, st.position, verwacht, oud],
				st.size.is_equal_approx(STAGE) and (titel.stage as Control).position.is_equal_approx(verwacht))
		if ins == Vector4.ZERO:
			t.check("%s insets 0: pixel-gelijk aan het midden van het volle venster" % tag,
					(titel.stage as Control).position.is_equal_approx(oud))
		var safe := Rect2(Vector2(ins.x, ins.y), vp - Vector2(ins.x + ins.z, ins.y + ins.w))
		if past:
			t.check("%s stage binnen safe %s (stage %s)" % [tag, safe, st], t.within(st, safe))
		else:
			t.check("%s stage past niet in safe %s en is geklemd op %s (niet het volle midden %s)" % [tag, safe, verwacht, oud],
					not verwacht.is_equal_approx(oud) and (titel.stage as Control).position.is_equal_approx(verwacht))
		var cr: Rect2 = (titel.card as Control).get_global_rect()
		cr.position -= st.position
		t.check("%s kaartje blijft rechtsonder t.o.v. de stage (x 240..372, y 148..201): %s" % [tag, cr],
				absf(cr.position.x - 240.0) <= 1.0 and absf(cr.end.x - 372.0) <= 1.0
				and cr.end.y <= 201.0 and cr.position.y >= 148.0)
		await t.shot("f6_title_%s_%d_%d_%d_%d" % [profiel, int(ins.x), int(ins.y), int(ins.z), int(ins.w)])
	UiTouch.insets_override = null
	await t.pframes(2)
