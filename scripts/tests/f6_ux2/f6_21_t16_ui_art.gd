extends RefCounted
## F6-T16 UI-art van RPG ART (akkoord Dennis 18-11): gevechtskruis 26x26 (strook 78x26, ook knop_codex.png),
## HUD-knoppen MENU/RUN/CORE als plaatjes (38x25 / 46x25 / 46x25, ingedrukt + RUN-lampje aan/uit) en het
## titelkader (9-slice, 6 px; 'gekozen' bij focus). Alles Nearest. Losse knopen: geen spel of gevecht nodig.

const CrossScript := preload("res://scripts/battle/command_cross.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const UiTouchC := preload("res://scripts/ui/ui_touch.gd")
const KADER := "res://assets/ui/title_knopkader.png"
const KADER_GEKOZEN := "res://assets/ui/title_knopkader_gekozen.png"


func run(t: Node) -> void:
	await _title_tests(t)
	await _cross_and_hud_tests(t)


func _title_tests(t: Node) -> void:
	if t.sc.scene() == null or t.sc.scene().name != "Title":
		t.get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
		if not await t.sc.wait_scene("Title"):
			t.check("T16 titel: titelscherm staat open", false)
			return
		await t.pframes(8)
	var titel: Node = t.sc.scene()
	t.check("T16 titel: title_buttons() bestaat", titel != null and titel.has_method("title_buttons"))
	if titel == null or not titel.has_method("title_buttons"):
		return
	var alle_ok := true
	var shown := 0
	var info := []
	for b: Button in titel.title_buttons():
		var n := b.get_theme_stylebox("normal") as StyleBoxTexture
		var f := b.get_theme_stylebox("focus") as StyleBoxTexture
		var ok := n != null and f != null and n.texture != null and f.texture != null \
				and n.texture.resource_path == KADER and f.texture.resource_path == KADER_GEKOZEN \
				and b.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			ok = ok and n != null and is_equal_approx(n.get_texture_margin(side), 6.0) \
					and f != null and is_equal_approx(f.get_texture_margin(side), 6.0)
		for st in ["hover", "pressed", "disabled"]:
			var s2 := b.get_theme_stylebox(st) as StyleBoxTexture
			ok = ok and s2 != null and s2.texture != null and s2.texture.resource_path == KADER
		if b.is_visible_in_tree():
			shown += 1
			ok = ok and b.size.y >= 25.0 - 0.01
		alle_ok = alle_ok and ok
		if not ok:
			info.append(b.name)
	t.check("T16 titel: elke knop het 9-slice-kader (patch 6), 'gekozen' als focus, Nearest, zichtbare >= 25 hoog (%d zichtbaar, fout: %s)"
			% [shown, info], alle_ok and shown > 0)
	var tex: Texture2D = load(KADER)
	t.check("T16 titel: title_knopkader.png 118x25", tex != null and tex.get_size() == Vector2(118, 25))
	var nb: Button = titel.new_button
	nb.grab_focus()
	await t.pframes(2)
	var fs := nb.get_theme_stylebox("focus") as StyleBoxTexture
	t.check("T16 titel: New Game met focus toont het gekozen-kader", nb.has_focus() and fs != null
			and fs.texture.resource_path == KADER_GEKOZEN)
	t.check("T16 titel: content-marges 0 (maat en tekstplek van de knoppen ongewijzigd)",
			is_zero_approx(fs.get_content_margin(SIDE_LEFT)) and is_zero_approx(fs.get_content_margin(SIDE_TOP)))
	await t.shot("f6_t16_title")


func _cross_and_hud_tests(t: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	t.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.14)
	bg.size = t.get_viewport().get_visible_rect().size
	layer.add_child(bg)
	# --- kruis
	var c: Control = CrossScript.new()
	layer.add_child(c)
	await t.pframes(1)
	t.check("T16 kruis: BUTTON 26, GAP 1 (afstand 27)", CrossScript.BUTTON == 26.0 and CrossScript.GAP == 1.0)
	var art_ok := true
	var detail := []
	for i in CrossScript.IDS.size():
		var id: String = CrossScript.IDS[i]
		var fr: Array = c._frames.get(id, [])
		var ok: bool = c.has_art(i) and fr.size() == 3
		for f in fr.size():
			var at := fr[f] as AtlasTexture
			ok = ok and at != null and at.atlas != null and at.atlas.get_size() == Vector2(78, 26) \
					and at.region == Rect2(f * 26, 0, 26, 26) \
					and at.atlas.resource_path == "res://assets/ui/knop_%s.png" % id
		ok = ok and c.buttons[i].size == Vector2(26, 26) and c.buttons[i].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		art_ok = art_ok and ok
		if not ok:
			detail.append(id)
	t.check("T16 kruis: 6 knoppen met art, frames 26x26 uit stroken van 78x26 (fout: %s)" % [detail], art_ok)
	t.check("T16 kruis: reserve-knop blijft bij een ontbrekend plaatje",
			CrossScript._load_frames("res://assets/ui/bestaat_niet.png").is_empty())
	c.open("Dax", [true, true, true, true, false, true], 0)
	c.place(Vector2(170, 110))
	await t.pframes(2)
	var cf: Array = c._frames["codex"]
	t.check("T16 kruis: Codex toont knop_codex.png (frame 'normaal'), geen reserve-tekening",
			c.has_art(CrossScript.CODEX) and c.buttons[CrossScript.CODEX].texture == cf[0])
	t.check("T16 kruis: frames volgen de staat (Aanval gekozen = 1, Vluchten uit = 2, Magie normaal = 0)",
			c.buttons[0].texture == c._frames["aanval"][1] and c.buttons[4].texture == c._frames["vluchten"][2]
			and c.buttons[1].texture == c._frames["magie"][0])
	var m: Vector2 = c.button_rect(0).get_center()
	var vorm: bool = c.button_rect(1).get_center().is_equal_approx(m + Vector2(0, -27)) \
			and c.button_rect(2).get_center().is_equal_approx(m + Vector2(-27, 0)) \
			and c.button_rect(3).get_center().is_equal_approx(m + Vector2(27, 0)) \
			and c.button_rect(4).get_center().is_equal_approx(m + Vector2(0, 27)) \
			and c.button_rect(CrossScript.CODEX).get_center().is_equal_approx(m + Vector2(27, 27))
	t.check("T16 kruis: kruisvorm met afstand 27 (Codex rechtsonder)", vorm)
	var overlap := false
	for i in 6:
		for j in range(i + 1, 6):
			overlap = overlap or c.button_rect(i).intersects(c.button_rect(j))
	t.check("T16 kruis: geen plaatjes over elkaar; tikvlak >= 25", not overlap
			and UiTouchC.big_enough(c.hit_rect(0)) and UiTouchC.big_enough(c.hit_rect(CrossScript.CODEX)))
	# --- HUD
	var tc: Control = TouchScript.new()
	layer.add_child(tc)
	await t.pframes(1)
	tc.show_menu = true
	tc.show_run = true
	tc.show_kern = true
	var settings := t.get_node_or_null("/root/Settings")
	var run_was = settings.get_value("run") if settings else null
	if settings:
		settings.set_value("run", false)
	await t.pframes(2)
	var maten := {"menu": Vector2(38, 25), "run": Vector2(46, 25), "run_on": Vector2(46, 25), "core": Vector2(46, 25)}
	var paden := {"menu": "hud_menu", "run": "hud_run", "run_on": "hud_run_aan", "core": "hud_core"}
	var hud_ok := true
	for k in maten:
		var pair: Array = tc.hud_art[k]
		hud_ok = hud_ok and pair.size() == 2 and pair[0] != null and pair[1] != null \
				and pair[0].get_size() == maten[k] and pair[1].get_size() == maten[k] \
				and pair[0].resource_path == "res://assets/ui/%s.png" % paden[k] \
				and pair[1].resource_path == "res://assets/ui/%s_ingedrukt.png" % paden[k]
	t.check("T16 HUD: MENU 38x25, RUN/RUN-aan/CORE 46x25, elk met ingedrukt-variant", hud_ok)
	t.check("T16 HUD: Nearest", tc.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	t.check("T16 HUD: ingedrukt wisselt het plaatje (MENU, CORE)",
			tc.hud_texture("menu", false) == tc.hud_art["menu"][0] and tc.hud_texture("menu", true) == tc.hud_art["menu"][1]
			and tc.hud_texture("core", false) == tc.hud_art["core"][0] and tc.hud_texture("core", true) == tc.hud_art["core"][1])
	var lamp_uit: bool = settings != null and tc.hud_texture("run", false) == tc.hud_art["run"][0] \
			and tc.hud_texture("run", true) == tc.hud_art["run"][1]
	if settings:
		settings.set_value("run", true)
	await t.pframes(2)
	await t.shot("f6_t16_kruis_hud_run_aan")
	var lamp_aan: bool = settings != null and tc.hud_texture("run", false) == tc.hud_art["run_on"][0] \
			and tc.hud_texture("run", true) == tc.hud_art["run_on"][1]
	t.check("T16 HUD: RUN-lampje volgt de stand (uit %s, aan %s), ook ingedrukt" % [lamp_uit, lamp_aan], lamp_uit and lamp_aan)
	# plaatje gecentreerd op de oude knoprechthoek en binnen het (ongewijzigde) tikvlak
	var plek_ok := true
	for pr in [[tc.menu_rect(), "menu", 4.0], [tc.run_rect(), "run", 2.0], [tc.kern_rect(), "core", 4.0]]:
		var r: Rect2 = pr[0]
		var tex: Texture2D = tc.hud_texture(pr[1], false)
		var ar: Rect2 = TouchScript.hud_art_rect(r, tex.get_size())
		plek_ok = plek_ok and ar.get_center().distance_to(r.get_center()) <= 0.51 \
				and UiTouchC.hit_rect(r, pr[2]).grow(0.5).encloses(ar)
	t.check("T16 HUD: plaatjes gecentreerd op MENU/RUN/CORE en binnen hun tikvlak", plek_ok)
	t.check("T16 HUD: tikvlakken ongewijzigd (MENU 38x14, RUN 46x14, CORE 46x17 + marge)",
			tc.menu_rect().size == Vector2(38, 14) and tc.run_rect().size == Vector2(46, 14) and tc.kern_rect().size == Vector2(46, 17))
	tc.hud_art["menu"] = [null, null]
	t.check("T16 HUD: zonder plaatje valt MENU terug op de tekening", tc.hud_texture("menu", false) == null)
	if settings:
		settings.set_value("run", run_was)
	layer.queue_free()
	await t.pframes(2)
