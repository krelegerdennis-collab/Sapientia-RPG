extends Node
## ALLEEN VOOR TESTEN - je hebt dit niet nodig om het spel te spelen.
## Start:  godot --path . -- --autotest [--screenshot=/pad/map.png] [--battle-shots=/pad/prefix]
## Dorp Wilgendal: start, deur op slot, botsing, bordje, NPC, touch, en veel stappen
## met 100x encounter-kans zonder gevecht. Dan de uitgang naar de wereldkaart:
## spawnpunt, zee/bergen blokkeren, bos is begaanbaar, encounter + volledig gevecht
## (aanval/spreuk/item, winst + level-up), terug op dezelfde tile, vluchten,
## 4 helden, de trap (bericht), terug het dorp in en weer uit, en game over
## (v0.19: respawn waar je de wereldkaart binnenkwam).
## Gevechtsscherm: heldensprites, statusvakken (balken = echte HP/MP), aantikken van
## sprite/statusvak, overwinningsvenster, niets onder de D-pad/A/B, en 4 helden.
## v0.11: eerst de proloog (scène 1 en 2) helemaal doorgespeeld, met opslaan/laden
## halverwege; daarna (proloog op 'klaar') alle oude tests.
## Print PASS/FAIL en sluit het spel daarna af (exit code 0 = alles goed).
## Deze node hangt aan de root, zodat hij blijft bestaan als de scène wisselt.

const GameData := preload("res://scripts/data/game_data.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")

var failures := 0
var shot_path := ""
var battle_shots := ""
var overview_path := ""
## v0.16: map voor de opleverings-screenshots v16_<naam>.png (1024x576)
var v16_dir := ""
var _damage_shot_done := false
var _hero_hit_shot_done := false
var _bar_animating_seen := false


## v0.12: eerste regel van het opslagboek (vult HP en MP).
const NEW_SAVE_LINE := "A warm glow restores your strength and your mind."

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--battle-shots="):
			battle_shots = arg.get_slice("=", 1)
		elif arg.begins_with("--overview="):
			overview_path = arg.get_slice("=", 1)
		elif arg.begins_with("--v16-shots="):
			v16_dir = arg.get_slice("=", 1)
	seed(4242)
	GameState.encounter_multiplier = 0.0   # geen toevallige gevechten, tenzij een test ze aanzet
	_run.call_deferred()


# ---------------------------------------------------------------- hulpjes
func scene() -> Node:
	return get_tree().current_scene


## De speler op de huidige map (null tijdens een gevecht of scènewissel).
func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func map_name() -> String:
	var s := scene()
	return String(s.name) if s != null else ""


func terrain(t: Vector2i) -> String:
	var s := scene()
	return s.terrain_at(t) if s != null and s.has_method("terrain_at") else ""


func battle() -> Node:
	var s := scene()
	if s != null and s.name == "Battle":
		return s
	return null


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Loop precies n tiles (of minder als iets in de weg staat, een gevecht begint
## of de speler naar een andere map gaat).
func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 6:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.in_battle or GameState.changing_map:
			return


func close_dialog() -> void:
	var guard := 0
	while Dialog.is_open and guard < 20:
		await press_interact()
		guard += 1


func tap(action: String) -> void:
	# Druk tijdens de physics-stap: die komt in elk frame vóór _process en vóór
	# 'process_frame', dus menu's en doelkeuze zien 'just_pressed' gegarandeerd.
	# (Echte toetsen/touch komen ook binnen vóór het frame, die hebben dit probleem niet.)
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready():
			return true
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	return false


## Wacht tot het gevecht in een van de gegeven toestanden is ("" = timeout of geen gevecht meer).
func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t := 0.0
	while t < timeout:
		var b := battle()
		if b == null and t > 0.5 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	return ""


func wait_hero(index: int) -> bool:
	for i in 600:
		var b := battle()
		if b != null and b.state == "command" and b.current_hero == index:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


## v0.13: kies commando 'index' in het KRUIS (met de D-pad + A, zoals een speler).
## 0 Aanval = midden, 1 Magie = boven, 2 Item = links, 3 Verdedig = rechts, 4 Vluchten = onder.
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}


func choose_command(index: int) -> void:
	await wait_battle_state(["command"])
	var b := battle()
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	await cross_select(b, index)
	await tap("interact")


## Zet de selectie in het kruis op 'index' (eerst terug naar het midden, dan de arm in).
func cross_select(b: Node, index: int) -> void:
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


## Frame dat knop i nu laat zien (0 normaal, 1 gekozen, 2 uit; -1 = geen art).
func cross_frame(b: Node, i: int) -> int:
	var tex = b.cross.buttons[i].texture
	if tex is AtlasTexture:
		return int((tex as AtlasTexture).region.position.x / 24.0)
	return -1


## Rechthoeken van alle helden (op hun plek en naar voren gestapt).
func _hero_rects(b: Node) -> Dictionary:
	var out := {}
	for node in b.hero_nodes:
		out[node.name] = Rect2((node.home - node.FEET).round(), node.SIZE)
		out[node.name + "_stap"] = Rect2((node.home + node.STEP - node.FEET).round(), node.SIZE)
	return out


## v0.13: het kruis valt NIET over een heldensprite (v0.15: staat LINKS naast de helden),
## een statusvak, de bericht-strook of de D-pad/A/B; het naam-tabje toont wie er kiest.
func _check_cross(b: Node, who: String) -> void:
	var c: Rect2 = b.cross.cross_rect()
	var tab: Rect2 = lrect(b, b.cross.name_tab)
	var bad := []
	var solid := _hero_rects(b)
	for box in b.status_boxes:
		solid[box.name] = lrect(b, box)
	if b.caption.visible:
		solid["bericht-strook"] = lrect(b, b.caption)
	if b.tip_panel and b.tip_panel.visible:
		solid["tip"] = lrect(b, b.tip_panel)
	for key in solid:
		if c.intersects(solid[key]):
			bad.append("kruis over " + key)
		if tab.intersects(solid[key]):
			bad.append("naam-tabje over " + key)
	var tc: Control = b.touch
	for circ in [[tc.dpad_center(), tc.dpad_radius * 1.2], [tc.a_center(), tc.button_radius * 1.25],
			[tc.b_center(), tc.button_radius * 1.25]]:
		if _rect_hits_circle(c, circ[0], circ[1]):
			bad.append("kruis onder een knop")
	if not Rect2(Vector2.ZERO, b.size).encloses(c) or not Rect2(Vector2.ZERO, b.size).encloses(tab):
		bad.append("buiten beeld")
	# v0.15: het kruis staat LINKS naast de helden (wens van Dennis), op de hoogte van de heldenrij
	var hero_l: float = b.size.x
	var hero_top: float = b.size.y
	var hero_bottom := 0.0
	for node in b.hero_nodes:
		var ar: Rect2 = node.art_rect(node.home)
		hero_l = minf(hero_l, ar.position.x)
		hero_top = minf(hero_top, ar.position.y)
		hero_bottom = maxf(hero_bottom, ar.end.y)
		if c.intersects(ar) or tab.intersects(ar):
			bad.append("kruis/tabje over de art van " + str(node.name))
	if c.end.x > hero_l or c.get_center().x > b.size.x * 0.5:
		bad.append("niet links van de helden (%s, held vanaf x %.0f)" % [c, hero_l])
	if c.end.y < hero_top or c.position.y > hero_bottom:
		bad.append("niet op de hoogte van de heldenrij (%s, helden y %.0f..%.0f)" % [c, hero_top, hero_bottom])
	if b.hero_nodes.size() == 1 and hero_l - c.end.x > 8.0:
		bad.append("niet dicht bij de held (%.0f px)" % (hero_l - c.end.x))
	for i in 5:
		if b.cross.button_rect(i).size.x < 24.0:
			bad.append("knop te klein")
	check("kruis links naast de held voor %s, vrij van helden/vakken/knoppen (kruis %s, tab %s) %s" % [who, c, tab, bad],
			b.cross.visible and b.cross.active and bad.is_empty()
			and str(b.cross.name_label.text).begins_with(who))


## v0.13: spreuken-/itemlijstje rechtsboven, nooit over helden of statusvakken.
func _check_submenu(b: Node, title: String) -> void:
	var m: Rect2 = lrect(b, b.menu)
	var bad := []
	var solid := _hero_rects(b)
	for box in b.status_boxes:
		solid[box.name] = lrect(b, box)
	for key in solid:
		if m.intersects(solid[key]):
			bad.append(key)
	check("lijstje '%s' rechtsboven, niet over helden/vakken (%s) %s" % [title, m, bad],
			b.menu.visible and b.menu.title_label.text == title and bad.is_empty()
			and m.end.x <= b.size.x and m.position.y < b.size.y * 0.5)


## v0.13: doel-label en -pijltje vallen niet over statusvakken/helden (bij een vijand als doel)
## of buiten beeld.
func _check_target_ui(b: Node, label: String, ally: bool) -> void:
	var n: Rect2 = lrect(b, b.target_name)
	var a: Rect2 = lrect(b, b.target_cursor)
	var bad := []
	var solid := {}
	for box in b.status_boxes:
		solid[box.name] = lrect(b, box)
	if not ally:
		solid.merge(_hero_rects(b))
	for key in solid:
		if n.intersects(solid[key]):
			bad.append("label over " + key)
		if a.intersects(solid[key]):
			bad.append("pijltje over " + key)
	if not Rect2(Vector2.ZERO, b.size).encloses(n):
		bad.append("label buiten beeld")
	check("%s: doel-label '%s' + pijltje vrij %s" % [label, b.target_name_label.text, bad],
			b.target_name.visible and b.target_cursor.visible and bad.is_empty())


## Simuleer een tik/klik op een punt (in 384x216-coördinaten).
func click_at(pos: Vector2) -> void:
	await get_tree().physics_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = get_tree().root.get_final_transform() * pos
	ev.global_position = ev.position
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(3)


func screenshot(path: String) -> void:
	if path == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	# Altijd 1152x648 (bij 384x216). Het gevecht rendert op 768x432 (fijn raster):
	# dat wordt 1.5x; daarnaast bewaren we dan een scherpe 2x-versie (*_2x.png).
	var base := img.get_width()
	if base > 600:
		var crisp := img.duplicate()
		crisp.resize(base * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crisp.save_png(path.get_basename() + "_2x.png")
		img.resize(base * 3 / 2, img.get_height() * 3 / 2, Image.INTERPOLATE_NEAREST)
	else:
		img.resize(base * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("INFO  screenshot opgeslagen: ", path)
	await get_tree().process_frame


## v0.16 Screenshot voor de oplevering: <v16_dir>/v16_<naam>.png, precies 1024x576.
func v16_shot(shot_name: String) -> void:
	if v16_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	var k := maxi(1, ceili(1024.0 / img.get_width()))
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	img.resize(1024, 576, Image.INTERPOLATE_LANCZOS)
	var path := v16_dir.path_join("v16_%s.png" % shot_name)
	img.save_png(path)
	print("INFO  v16-screenshot: ", path, " ", img.get_size())


func overworld_shot(suffix: String) -> void:
	if shot_path != "":
		await screenshot(shot_path if suffix == "" else shot_path.get_basename() + suffix + ".png")


## Overzicht van de HELE map (1 pixel = 1 pixel): de Ground-laag wordt in een
## aparte SubViewport getekend die zo groot is als de map.
func map_overview(path: String) -> void:
	if path == "" or scene() == null:
		return
	var ground: TileMapLayer = scene().get_node("Ground")
	var rect := ground.get_used_rect()
	var vp := SubViewport.new()
	vp.size = rect.size * 16
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var copy: TileMapLayer = ground.duplicate()
	copy.position = -Vector2(rect.position * 16)
	vp.add_child(copy)
	var sprite: Sprite2D = player().get_node("Sprite2D").duplicate()
	sprite.position = player().position - Vector2(rect.position * 16)
	vp.add_child(sprite)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(path)
		print("INFO  overzicht opgeslagen: ", path, " ", img.get_size())
	vp.queue_free()


func battle_shot(suffix: String) -> void:
	if battle_shots != "":
		await screenshot(battle_shots + suffix + ".png")


func _on_damage_shown(target_name: String, _amount: int) -> void:
	var is_hero := GameState.party.any(func(h): return h["name"] == target_name)
	var suffix := ""
	if not is_hero and not _damage_shot_done:
		_damage_shot_done = true
		suffix = "_3_damage"
	elif is_hero and not _hero_hit_shot_done:
		_hero_hit_shot_done = true
		suffix = "_3b_hero_hit"
	if is_hero and battle() != null and not _bar_animating_seen:
		# De balk moet nog 'vol' staan en daarna rustig zakken.
		for i in battle().heroes.size():
			if battle().heroes[i]["name"] == target_name:
				var box: Control = battle().status_boxes[i]
				_bar_animating_seen = box.shown_hp > float(box.hero["hp"])
	if suffix == "" or battle_shots == "":
		return
	# Even op normale snelheid, zodat het getal en de 'geraakt'-pose goed te zien zijn.
	var old_scale := Engine.time_scale
	Engine.time_scale = 1.0
	for i in (13 if is_hero else 16):
		await get_tree().process_frame
	await battle_shot(suffix)
	Engine.time_scale = old_scale


## Wacht tot alle HP/MP-balken klaar zijn met bewegen.
func wait_bars(b: Node) -> void:
	for i in 300:
		if b.status_boxes.all(func(x): return x.is_settled()):
			return
		await get_tree().process_frame


## Kloppen de balken (en getallen) met de echte HP/MP?
func check_bars(b: Node, label: String) -> void:
	await wait_bars(b)
	var ok := true
	var info := []
	for box in b.status_boxes:
		var h: Dictionary = box.hero
		info.append("%s %d/%d %d/%d" % [h["name"], roundi(box.shown_hp), h["hp"], roundi(box.shown_mp), h["mp"]])
		if roundi(box.shown_hp) != int(h["hp"]) or roundi(box.shown_mp) != int(h["mp"]):
			ok = false
	check("%s: balken = HP/MP %s" % [label, info], ok)


func _rect_hits_circle(r: Rect2, c: Vector2, radius: float) -> bool:
	var p := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return p.distance_to(c) < radius


## Rechthoek van een Control in de eenheden van het gevechtsscherm (384x216).
## (Het gevecht rendert op 768x432 en de scène is 2x geschaald, zie battle.gd.)
func lrect(b: Node, c: Control) -> Rect2:
	return b.get_global_transform().affine_inverse() * c.get_global_rect()


## v9.1 voor-achter: vijanden bovenin op een rij, midden op het scherm, achter de helden.
func _check_enemies_top(b: Node, label: String) -> void:
	var lo := INF
	var hi := -INF
	var ok := true
	var hero_head: float = b.hero_nodes[0].home.y - b.hero_nodes[0].HEAD_HEIGHT
	for e in b.enemies:
		var r: Rect2 = lrect(b, e["node"])
		lo = minf(lo, r.position.x)
		hi = maxf(hi, r.end.x)
		var feet_y: float = r.position.y + b.enemy_feet(e["node"]).y
		if feet_y > b.size.y / 2.0 or feet_y > hero_head + 12.0:
			ok = false
	var mid := (lo + hi) / 2.0
	check("%s: vijanden bovenin op een rij, midden (%.0f..%.0f), achter de helden" % [label, lo, hi],
			ok and absf(mid - b.size.x / 2.0) <= 6.0
			and b.get_node("Enemies").get_index() < b.get_node("Party").get_index())


## v9.1: elke held staat midden boven zijn eigen statusvak, voeten net boven de bovenrand.
func _check_heroes_on_boxes(b: Node, label: String) -> void:
	var bad := []
	for i in b.hero_nodes.size():
		var n: Control = b.hero_nodes[i]
		var box: Rect2 = lrect(b, b.status_boxes[i])
		var gap: float = box.position.y - n.home.y
		if absf(n.home.x - box.get_center().x) > 1.0 or gap < 1.0 or gap > 6.0:
			bad.append("%s: voeten %s, vak %s" % [n.name, n.home, box])
	check("%s: elke held midden boven zijn eigen statusvak %s" % [label, bad], bad.is_empty())


## v9: het commandomenu staat direct boven het statusvak van held i (linkerkanten gelijk,
## behalve als het aan de rand geklemd wordt).
func _check_menu_above(b: Node, i: int, who: String) -> void:
	var m: Rect2 = lrect(b, b.menu)
	var box: Rect2 = lrect(b, b.status_boxes[i])
	var want_x := clampf(box.position.x, b._menu_left, b._menu_right - m.size.x)
	check("menu boven het statusvak van %s (menu %s, vak %s)" % [who, m, box],
			b.menu.visible and m.end.y <= box.position.y and m.end.y >= box.position.y - 4.0
			and absf(m.position.x - roundf(want_x)) <= 1.0 and m.position.x >= b._menu_left - 0.5
			and m.end.x <= b._menu_right + 0.5)


## Niets van het gevechtsscherm mag onder de D-pad of A/B vallen; vakken niet over elkaar.
func check_layout(b: Node, label: String) -> void:
	var tc: Control = b.touch
	var vp: Vector2 = b.size
	var circles := [[tc.dpad_center(), tc.dpad_radius * 1.2], [tc.a_center(), tc.button_radius * 1.25],
			[tc.b_center(), tc.button_radius * 1.25]]
	var rects := {}
	for box in b.status_boxes:
		rects[box.name] = lrect(b, box)
	for node in b.hero_nodes:
		rects[node.name] = Rect2((node.home - node.FEET).round(), node.SIZE)
		rects[node.name + "_stap"] = Rect2((node.home + node.STEP - node.FEET).round(), node.SIZE)
	for e in b.enemies:
		rects[e["name"]] = lrect(b, e["node"])
	# v9: het menu is een pop-up boven het statusvak van wie er kiest; het mag over de
	# benen van de helden/vijanden vallen, maar niet over statusvakken, de bericht-strook,
	# de D-pad/A/B of buiten beeld.
	# v0.13: het kruis (en zijn naam-tabje) en het doel-label vallen ook niet over helden
	var ui := {}
	if b.menu.visible:
		ui["menu"] = lrect(b, b.menu)
	if b.cross.visible:
		ui["kruis"] = b.cross.cross_rect()
		ui["kruis-tab"] = lrect(b, b.cross.name_tab)
	if b.target_name.visible:
		ui["doel-label"] = lrect(b, b.target_name)
	for key in ui:
		rects[key] = ui[key]
	var boxes := {}
	for box in b.status_boxes:
		boxes[box.name] = lrect(b, box)
	var cap: Rect2 = lrect(b, b.caption) if b.caption.visible else Rect2()
	rects["bericht-strook"] = cap
	var bad := []
	var hr_all := _hero_rects(b)
	for key in ui:
		for bk in boxes:
			if ui[key].intersects(boxes[bk]):
				bad.append("%s/%s overlappen" % [key, bk])
		if key != "menu" and key != "doel-label":
			for hk in hr_all:
				if ui[key].intersects(hr_all[hk]):
					bad.append("%s over %s" % [key, hk])
		if b.caption.visible and ui[key].intersects(cap):
			bad.append("%s over de bericht-strook" % key)
	# helden en vijanden: niet over statusvakken of de bericht-strook bovenin
	var solid := boxes.duplicate()
	solid["bericht-strook"] = cap
	for node in b.hero_nodes:
		for st in ["", "_stap"]:
			var hr: Rect2 = rects[node.name + st]
			for key in solid:
				if solid[key].has_area() and hr.intersects(solid[key]):
					bad.append("%s%s over %s" % [node.name, st, key])
	for e in b.enemies:
		for key in solid:
			if solid[key].has_area() and rects[e["name"]].intersects(solid[key]):
				bad.append("%s over %s" % [e["name"], key])
		# v0.13: het kruis en zijn naam-tabje vallen niet over een vijand
		for key in ["kruis", "kruis-tab"]:
			if ui.has(key) and ui[key].has_area() and rects[e["name"]].intersects(ui[key]):
				bad.append("%s onder %s" % [e["name"], key])
	for key in rects:
		var r: Rect2 = rects[key]
		if not r.has_area():
			continue
		if not Rect2(Vector2.ZERO, vp).encloses(r):
			bad.append(key + " buiten beeld")
		for c in circles:
			if _rect_hits_circle(r, c[0], c[1]):
				bad.append(key + " onder knop")
	for i in b.status_boxes.size():
		for j in range(i + 1, b.status_boxes.size()):
			if lrect(b, b.status_boxes[i]).intersects(lrect(b, b.status_boxes[j])):
				bad.append("vakken %d/%d overlappen" % [i, j])
	check("%s: niets onder D-pad/A/B, alles in beeld %s" % [label, bad], bad.is_empty())


# ---------------------------------------------------------------- de test
func _run() -> void:
	await _title_and_name_tests()
	await _prologue_tests()
	await _end_prologue()
	check("na de proloog: voor het huis (Willowdale)", await wait_scene("Wilgendal"))
	await frames(20)
	await _town_tests()
	await _world_tests()
	await _solo_battle_test()
	await _encounter_and_battle_tests()
	await _bestiary_tests()
	await _backdrop_tests()
	await _flee_test()
	await _four_heroes_test()
	await _stairs_and_town_return_tests()
	await _game_over_test()
	Engine.time_scale = 1.0
	print("RESULT %s (%d fouten)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


## v0.11: na de proloog-test: save weg, proloog 'klaar' (wereldkaart open), naar buiten.
func _end_prologue() -> void:
	await _story_drain()
	# v0.11: oude save (v0.10) met held-id van vóór de hernoeming en zonder verhaal laadt nog
	var keep_party: Array = GameState.party.duplicate(true)
	var keep_inv: Dictionary = GameState.inventory.duplicate(true)
	var keep_best: Dictionary = GameState.bestiary.duplicate(true)
	var old := GameState.read_save()
	check("v0.12: save bevat puzzle_latched (leeg bij een nieuw spel)", old.get("puzzle_latched", null) is Dictionary
			and (old["puzzle_latched"] as Dictionary).is_empty())
	old["party"][0]["id"] = GameState.LEGACY_HERO_IDS.keys()[0]
	old.erase("story")
	old.erase("puzzle_latched")
	GameState.puzzle_latched = {"archief_test": ["poort_1"]}
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check("oude save (held-id '%s', geen verhaal) laadt als 'dennis', proloog klaar" % old["party"][0]["id"],
			GameState.load_game() and GameState.party.size() == 1 and GameState.party[0]["id"] == "dennis"
			and GameState.party[0]["name"] == "Kees" and GameState.story_step == SD.KLAAR)
	check("v0.12: oude save zonder puzzle_latched laadt met {}", GameState.puzzle_latched == {})
	check("v0.12: F4-puzzelsprong alleen in debug-builds (actie bestaat: %s)" % InputMap.has_action("debug_puzzle"),
			InputMap.has_action("debug_puzzle") == OS.is_debug_build())
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var n_filters := presets.count("exclude_filter=")
	check("scripts/tests/* niet in de export (elke preset, nu %d)" % n_filters,
			n_filters >= 2 and presets.count("scripts/tests/*") == n_filters)
	GameState.has_return_point = false
	GameState.party = keep_party
	GameState.inventory = keep_inv
	GameState.bestiary = keep_best
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	GameState.story_step = SD.KLAAR
	for h in GameState.party:
		h["hp"] = h["max_hp"]
	GameState.change_map(GameState.TOWN_MAP, "start")


func _town_tests() -> void:
	var town := scene()
	check("huidige map = wilgendal.tscn (%s)" % GameState.current_map, GameState.current_map.ends_with("wilgendal.tscn"))
	check("buiten: encounters UIT", town.encounters == false)
	var start := tile()
	print("INFO  start tile ", start)
	check("speler start voor het huis op (16,8): %s" % start, start == Vector2i(16, 8))
	check("kijkt omlaag bij de start", player().facing == Vector2i.DOWN)
	_dorpsprite_checks()
	check("na de proloog: dag-tint, Oude Man weg", scene().get_node("StoryTint").color.is_equal_approx(Color.WHITE)
			and not scene().get_node("Objects/OudeMan").visible)
	await frames(30)
	await overworld_shot("_town")
	await _book_tests()

	# 1) v0.10: het huis is open. Tegen de deur lopen -> korte fade naar binnen.
	await walk("move_up", 1)
	check("op de fundering voor de deur (16,7): %s" % tile(), tile() == Vector2i(16, 7))
	await overworld_shot("_door")
	await walk("move_up", 1)
	check("deur -> binnen in het huis (scène 'Huis')", await wait_scene("Huis"))
	await frames(5)
	await _house_tests()
	await _load_restore_test()

	# 2) Botsing: naar links over de fundering en het gras tot tegen de bosrand (x=1)
	await walk("move_left", 16)
	check("bos blokkeert, staat op (2,7): %s" % tile(), tile() == Vector2i(2, 7))
	check("kijkt naar links", player() != null and player().facing == Vector2i.LEFT)

	# 3) Touch D-pad + B-knop
	await _touch_test()

	# 4) Hier NOOIT een gevecht: kans x100, geen veilige stappen, veel stappen.
	GameState.encounter_multiplier = 100.0
	GameState.steps_until_encounter_possible = 0
	var count := {"steps": 0}   # (lambda's kunnen een gewone int niet aanpassen)
	var terrains := {}
	var p := player()
	var on_step := func(t: Vector2i):
		count["steps"] += 1
		terrains[terrain(t)] = true
	p.stepped.connect(on_step)
	await walk("move_right", 20)   # (3,7) -> (23,7): gras en kassei (fundering)
	await walk("move_left", 20)    # -> (3,7)
	await walk("move_right", 12)   # -> (15,7)
	p.stepped.disconnect(on_step)
	check("veel stappen buiten (%d) over %s" % [count["steps"], terrains.keys()],
			count["steps"] >= 50 and terrains.has("gras") and terrains.has("kassei"))
	check("GEEN gevecht bij het huis (kans x100)", not GameState.in_battle and map_name() == "Wilgendal")
	await tap("debug_battle")
	await frames(10)
	check("F2 start geen gevecht bij het huis", not GameState.in_battle)
	GameState.encounter_multiplier = 0.0
	check("terug op (15,7): %s" % tile(), tile() == Vector2i(15, 7))

	# 5) Over het pad naar het zuiden: de uitgang naar de wereldkaart (na de proloog open)
	await walk("move_down", 14)
	check("uitgang -> wereldkaart geladen", await wait_scene("Wereldkaart"))
	await frames(5)


func _touch_test() -> void:
	var touch: Control = scene().get_node("TouchControls/Control")
	var before := tile()
	var ev := InputEventScreenTouch.new()
	ev.index = 3
	# parse_input_event verwacht venster-coördinaten -> omrekenen vanuit 384x216
	ev.position = get_tree().root.get_final_transform() * (touch.dpad_center() + Vector2(touch.dpad_radius * 0.7, 0))
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	check("touch drukt move_right in", Input.is_action_pressed("move_right"))
	var waited := 0
	while not player().is_moving and waited < 10:
		await get_tree().physics_frame
		waited += 1
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(3)
	check("touch laat move_right los", not Input.is_action_pressed("move_right"))
	while player().is_moving:
		await get_tree().physics_frame
	check("speler liep 1 tile via touch: %s -> %s" % [before, tile()], tile() == before + Vector2i.RIGHT)
	var bev := InputEventScreenTouch.new()
	bev.index = 4
	bev.position = get_tree().root.get_final_transform() * touch.b_center()
	bev.pressed = true
	Input.parse_input_event(bev)
	await frames(3)
	check("touch B-knop drukt 'cancel' in", Input.is_action_pressed("cancel"))
	bev = bev.duplicate()
	bev.pressed = false
	Input.parse_input_event(bev)
	await frames(3)
	check("touch B-knop laat 'cancel' los", not Input.is_action_pressed("cancel"))


func _world_tests() -> void:
	check("huidige map = wereldkaart.tscn (%s)" % GameState.current_map, GameState.current_map.ends_with("wereldkaart.tscn"))
	check("wereldkaart heeft encounters AAN", scene().encounters == true)
	check("spawn naast de stad op (14,31): %s" % tile(), tile() == Vector2i(14, 31))
	check("kijkt omlaag na de overgang", player() != null and player().facing == Vector2i.DOWN)
	check("stad-tile boven de spawn (14,30) = %s" % terrain(Vector2i(14, 30)), terrain(Vector2i(14, 30)) == "stad")
	await frames(30)
	await overworld_shot("_world")
	await map_overview(overview_path)

	# Zee: naar links tot aan de kust (zee op x=7)
	await walk("move_left", 8)
	check("zee blokkeert, staat op (8,31): %s (links: %s)" % [tile(), terrain(Vector2i(7, 31))],
			tile() == Vector2i(8, 31) and terrain(Vector2i(7, 31)) == "zee")
	await overworld_shot("_coast")
	await walk("move_right", 6)
	# Bos: 2 omlaag, (14,33) is bos en begaanbaar
	await walk("move_down", 2)
	check("bos is begaanbaar, staat op (14,33) = %s: %s" % [terrain(tile()), tile()],
			tile() == Vector2i(14, 33) and terrain(tile()) == "bos")
	await walk("move_up", 2)
	# Bergen: naar rechts tot tegen de berg op x=24
	await walk("move_right", 12)
	check("berg blokkeert, staat op (23,31): %s (rechts: %s)" % [tile(), terrain(Vector2i(24, 31))],
			tile() == Vector2i(23, 31) and terrain(Vector2i(24, 31)) == "berg")
	check("kans per terrein uit game_data (bos %.2f > gras %.2f, kassei %.2f)" % [
			GameData.ENCOUNTER_RATES.get("bos", 0.0), GameData.ENCOUNTER_RATES.get("gras", 0.0),
			GameData.ENCOUNTER_RATES.get("kassei", 0.0)],
			GameData.ENCOUNTER_RATES.get("bos", 0.0) > GameData.ENCOUNTER_RATES.get("gras", 0.0)
			and GameData.ENCOUNTER_RATES.get("kassei", 0.0) == 0.0 and GameData.ENCOUNTER_RATES.get("zand", 0.0) > 0.0)


func _encounter_and_battle_tests() -> void:
	# Random encounter op de wereldkaart: kans x100, geen veilige stappen
	GameState.encounter_multiplier = 100.0
	GameState.steps_until_encounter_possible = 0
	GameState.debug_force_group = ["kennis_beest", "papiergeest"]
	await walk("move_left", 1)   # (22,31) = gras
	check("gevecht start bij stap op gras (wereldkaart)", GameState.in_battle)
	check("terugkeer-tile onthouden (22,31): %s" % GameState.return_tile, GameState.return_tile == Vector2i(22, 31))
	check("terugkeer-map = wereldkaart (%s)" % GameState.return_map, GameState.return_map.ends_with("wereldkaart.tscn"))
	check("gras-achtergrond voor gras (%s)" % GameState.pending_backdrop,
			GameState.pending_backdrop_id == "grass" and GameState.pending_backdrop.ends_with("battle_bg/gras.png"))
	check("gevechtsscène geladen", await wait_scene("Battle"))
	var b := battle()
	if b == null:
		return
	b.damage_shown.connect(_on_damage_shown)
	check("commandomenu verschijnt", await wait_battle_state(["command"]) == "command")
	check("Dennis is als eerste aan de beurt", b.current_hero == 0)
	check("2 vijanden: %s" % [b.enemies.map(func(e): return e["name"])], b.enemies.size() == 2)
	check("3 heldensprites en 3 statusvakken", b.hero_nodes.size() == 3 and b.status_boxes.size() == 3)
	var textures := {}
	for node in b.hero_nodes:
		textures[node._sprite.texture.resource_path] = true
	check("elke held eigen gevechtssprite %s" % [textures.keys()], textures.size() == 3)
	# '16-bit plus': het gevecht rendert op een 2x zo fijn raster, de art is 2x zo fijn
	check("gevecht op fijn raster 768x432, scène op schaal 2 (%s, scène %s, beeld %s)"
			% [get_window().content_scale_size, b.size, b.get_viewport_rect().size],
			get_window().content_scale_size == Vector2i(768, 432) and b.scale == Vector2(2, 2)
			and b.get_node("TouchControls").scale == Vector2(2, 2)
			and b.size.is_equal_approx(b.get_viewport_rect().size / 2.0))
	var frame_w: Array = b.hero_nodes.map(func(n): return n._sprite.texture.get_width() / 10)
	check("heldensprites 10 frames van 210x210 (v8, ±35%% schermhoogte), getoond op schaal 0.5 %s" % [frame_w],
			frame_w.all(func(w): return w == 210) and b.hero_nodes.all(func(n): return n._sprite.hframes == 10)
			and b.hero_nodes[0].HEAD_HEIGHT / 216.0 >= 0.33 and b.hero_nodes.all(func(n): return n._sprite.scale == Vector2(0.5, 0.5)))
	var enemies_hd := true
	for e in b.enemies:
		var tw: int = e["node"].texture_normal.get_width()
		var th: int = e["node"].texture_normal.get_height()
		var k: float = b.ENEMY_DEPTH_SCALE / 2.0
		if th <= b.MAX_ENEMY_ART_H:
			enemies_hd = enemies_hd and is_equal_approx(e["node"].size.x, tw * k)
		else:   # vangnet: te hoge (vervangen) art wordt passend verkleind
			enemies_hd = enemies_hd and is_equal_approx(e["node"].size.y, b.MAX_ENEMY_ART_H * k)
	check("vijanden 2x zo fijn x diepte-schaal %.2f (te hoge art passend verkleind)" % b.ENEMY_DEPTH_SCALE, enemies_hd)
	if DisplayServer.get_name() != "headless":
		check("v0.13: vensters en statusvakken in het palet (UiStyle, StyleBoxFlat)",
				b.theme.get_stylebox("panel", "PanelContainer") is StyleBoxFlat and b.status_boxes[0]._style is StyleBoxFlat
				and (b.status_boxes[0]._style as StyleBoxFlat).border_color == UiStyle.BORDER_DIM)
	else:
		print("INFO  headless: HD-vensters niet te lezen, de 12x12-reserve wordt gebruikt")
	_check_heroes_on_boxes(b, "3 helden")
	_check_enemies_top(b, "3 helden")
	check_layout(b, "3 helden")
	_v7_style_checks(b)
	await pframes(20)
	check("actieve held (Dennis) stapt naar voren", b.hero_nodes[0].stepped_forward and not b.hero_nodes[1].stepped_forward)
	check("statusvak van Dennis gemarkeerd", b.status_boxes[0].active and not b.status_boxes[1].active)
	check("Dennis heeft geen MP: lege grijze MP-balk", not b.status_boxes[0].has_mp() and b.status_boxes[1].has_mp())
	await check_bars(b, "start")
	# idle-animatie: Noor (niet aan de beurt) ademt (wisselt tussen frame 8/0/9)
	var seen_frames := {}
	for i in 70:
		seen_frames[b.hero_nodes[1]._sprite.frame] = true
		await get_tree().process_frame
	check("idle-animatie (ademen/cape/bol) bij Noor: frames %s" % [seen_frames.keys()],
			b.hero_nodes[1].has_idle_animation() and (seen_frames.has(8) or seen_frames.has(9)) and seen_frames.size() >= 2)
	await battle_shot("_1_menu")
	Engine.time_scale = 3.0

	var noor: Dictionary = GameState.party[1]
	var mp_before: int = noor["mp"]
	var potions_before := GameState.item_count("drankje")

	await _cross_nav_tests(b)
	# Dennis: Aanval -> eerste vijand
	await choose_command(0)
	check("doelkeuze vijand", await wait_battle_state(["target_enemy"]) == "target_enemy")
	await pframes(2)
	check("doelkeuze: kruis weg, pijltje = art van RPG ART (richtpijl.png)",
			not b.cross.visible and b.target_cursor.has_art() and b.target_cursor.size == Vector2(12, 12))
	for i in 30:
		if b.target_cursor.visible:
			break
		await get_tree().process_frame
	await battle_shot("_2_target")
	var cur_r := Rect2(b.target_cursor.position + Vector2(0, -2), b.target_cursor.size + Vector2(0, 2))
	var tgt_r: Rect2 = lrect(b, b.enemies[0]["node"])
	check("doel-pijltje op de vijand bovenin, niet over de bericht-strook (%s)" % b.target_cursor.tip(),
			b.target_cursor.visible and absf(b.target_cursor.tip().x - tgt_r.get_center().x) <= 2
			and tgt_r.grow(2).has_point(b.target_cursor.tip())
			and not (b.caption.visible and cur_r.intersects(lrect(b, b.caption))))
	await _target_cycle_tests(b)
	await tap("interact")

	# Noor: Magie -> B (terug) -> Magie -> Vuur -> tweede vijand
	check("Noor aan de beurt", await wait_hero(1))
	await pframes(4)
	_check_cross(b, "Noor")
	check("Noor kan Magie kiezen (knop niet grijs)", b.cross.is_enabled(1) and cross_frame(b, 1) == 0)
	await battle_shot("_1b_noor_menu")
	await choose_command(1)
	await pframes(3)
	check("spreukenmenu open", b.menu.title_label.text == "Magic")
	_check_submenu(b, "Magic")
	check("kruis blijft zichtbaar maar bedient niet tijdens het lijstje", b.cross.visible and not b.cross.active)
	await tap("cancel")
	check("B gaat terug naar het kruis van Noor, Magie nog gekozen",
			await wait_hero(1) and b.cross.active and b.cross.selected == 1 and not b.menu.visible)
	await choose_command(1)
	await pframes(3)
	await tap("interact")                    # Vuur
	await wait_battle_state(["target_enemy"])
	await tap("move_right")
	await tap("interact")

	# Lotte: Item -> Drankje -> Dennis
	check("Lotte aan de beurt", await wait_hero(2))
	for i in 60:
		if not b.menu.is_sliding():
			break
		await get_tree().process_frame
	await pframes(4)
	_check_cross(b, "Lotte")
	check_layout(b, "kruis voor Lotte")
	await choose_command(2)
	await pframes(3)
	check("itemmenu open (met tabje 'Item')", b.menu.title_label.text == "Item" and b.menu.tab.visible)
	_check_submenu(b, "Item")
	await tap("interact")                    # Drankje
	check("doelkeuze held", await wait_battle_state(["target_ally"]) == "target_ally")
	await pframes(3)
	check("doel-label bij een held: '%s'" % b.target_name_label.text,
			b.target_name.visible and b.target_name_label.text == GameState.party[0]["name"])
	_check_target_ui(b, "doel = Dennis", true)
	var head: Vector2 = b.hero_nodes[0].head_position()
	check("doel-pijltje boven Dennis' sprite (%s)" % b.target_cursor.tip(),
			b.target_cursor.visible and absf(b.target_cursor.tip().x - head.x) <= 2 and b.target_cursor.tip().y <= head.y)
	check("statusvak van het doel gemarkeerd", b.status_boxes[0].targeted)
	for i in 30:
		if b.target_cursor.visible:
			break
		await get_tree().process_frame
	await battle_shot("_2b_target_ally")
	await tap("move_right")                  # pijltje naar Noor...
	await pframes(2)
	check("pijltje naar Noor", b.status_boxes[1].targeted and not b.status_boxes[0].targeted
			and b.target_name_label.text == "Noor")
	await click_at(b.hero_nodes[0].get_global_rect().get_center())   # ...maar tik op Dennis' sprite
	await pframes(2)
	check("tik op heldensprite kiest Dennis", b.last_ally_target_row == 0 and b.state != "target_ally")

	var st := await wait_battle_state(["command", "message_wait"], 60)
	check("ronde 1 afgehandeld (%s)" % st, st != "")
	check("Fire kostte 4 MP: %d -> %d" % [mp_before, noor["mp"]], noor["mp"] == mp_before - 4)
	check("Potion verbruikt: %d -> %d" % [potions_before, GameState.item_count("drankje")],
			GameState.item_count("drankje") == potions_before - 1)
	var damaged: Array = b.enemies.filter(func(e): return e["s"]["hp"] < e["s"]["max_hp"])
	check("vijanden hebben schade", damaged.size() >= 1)
	check("schadegetal getoond", _damage_shot_done)
	check("HP-balk loopt rustig omlaag bij schade", _bar_animating_seen)
	await check_bars(b, "na ronde 1")

	# Ronde 2: Lotte spreekt Genees op Noor door op Noor's STATUSVAK te tikken.
	var genees_done := false

	# Verder vechten met Aanval tot de overwinning; berichten wegklikken.
	var levelup_seen := false
	var victory_seen := false
	for guard in 300:
		st = await wait_battle_state(["command", "message_wait"], 60)
		if st == "" or battle() == null:
			break
		if st == "command":
			if not genees_done and b.current_hero == 2 and GameState.party[2]["mp"] >= 3:
				genees_done = true
				await choose_command(1)          # Magie
				await pframes(3)
				await tap("interact")            # Genees
				await wait_battle_state(["target_ally"])
				await pframes(2)
				await click_at(b.status_boxes[1].get_global_rect().get_center())
				await pframes(2)
				check("tik op statusvak kiest Noor", b.last_ally_target_row == 1 and b.state != "target_ally")
				continue
			await choose_command(0)
			await wait_battle_state(["target_enemy"])
			await tap("interact")
		else:
			var vic: bool = b.victory_panel.visible
			var text: String = b.victory_label.text if vic else b.message_label.text
			if vic and not victory_seen:
				victory_seen = true
				_check_victory_window(b)
				Engine.time_scale = 1.0
				await pframes(10)
				await battle_shot("_4_victory")
				await v16_shot("buit")
				Engine.time_scale = 3.0
			elif vic and "is now level" in text and not levelup_seen:
				levelup_seen = true
				check("level-up in het overwinningsvenster: %s" % text.replace("\n", " | "), "HP+" in text)
				Engine.time_scale = 1.0
				await pframes(10)
				await battle_shot("_4b_levelup")
				Engine.time_scale = 3.0
			await tap("interact")
	check("tik op statusvak getest", genees_done)
	check("overwinningsvenster", victory_seen)
	check("level-up bericht", levelup_seen)
	check("terug op de wereldkaart", await wait_scene("Wereldkaart"))
	await frames(5)
	check("uitslag = win", GameState.last_battle_result == "win")
	check("overworld weer op 384x216 na het gevecht (%s)" % [get_window().content_scale_size],
			get_window().content_scale_size == Vector2i(384, 216))
	var max_level := 0
	for h in GameState.party:
		max_level = maxi(max_level, h["level"])
	check("minstens één held level 2: %s" % [GameState.party.map(func(h): return h["level"])], max_level >= 2)
	check("EXP en goud ontvangen (goud %d)" % GameState.gold, GameState.party[0]["exp"] > 0 and GameState.gold > 0)
	check("terug op dezelfde tile (22,31): %s" % tile(), tile() == Vector2i(22, 31))
	check("zelfde kijkrichting (links)", player() != null and player().facing == Vector2i.LEFT)
	check("veilige stappen na gevecht", GameState.steps_until_encounter_possible == GameData.SAFE_STEPS)
	await walk("move_left", 1)
	check("geen gevecht tijdens veilige stappen", not GameState.in_battle and tile() == Vector2i(21, 31))
	GameState.encounter_multiplier = 0.0


## v0.13: navigatie in het kruis (Dennis is aan de beurt; hij heeft geen spreuken).
func _cross_nav_tests(b: Node) -> void:
	var art := true
	for i in 5:
		art = art and b.cross.has_art(i)
	check("kruis: 5 knoppen met de art van RPG ART (knop_*.png, 24x24)", art
			and b.cross.buttons.all(func(k): return k.size == Vector2(24, 24)))
	check("kruis begint op Aanval (midden, frame 'gekozen')", b.cross.selected == 0 and cross_frame(b, 0) == 1
			and cross_frame(b, 3) == 0)
	var centre: Vector2 = b.cross.button_rect(0).get_center()
	var shape: bool = b.cross.button_rect(1).get_center().is_equal_approx(centre + Vector2(0, -25)) \
			and b.cross.button_rect(2).get_center().is_equal_approx(centre + Vector2(-25, 0)) \
			and b.cross.button_rect(3).get_center().is_equal_approx(centre + Vector2(25, 0)) \
			and b.cross.button_rect(4).get_center().is_equal_approx(centre + Vector2(0, 25))
	check("kruisvorm: Magie boven, Item links, Verdedig rechts, Vluchten onder", shape)
	var path := []
	for step in ["move_up", "move_down", "move_left", "move_right", "move_right", "move_down", "move_up"]:
		await tap(step)
		path.append(b.cross.selected)
	check("D-pad door het kruis: op/neer/links/rechts/rechts/neer/op -> %s" % [path],
			path == [1, 0, 2, 0, 3, 4, 0])
	check("naam-tabje volgt de keuze ('%s')" % b.cross.name_label.text, b.cross.name_label.text.ends_with("Attack"))
	# Magie is uit voor Dennis: grijs; A doet niets
	check("Magie grijs voor Dennis (geen spreuken)", not b.cross.is_enabled(1) and cross_frame(b, 1) == 2)
	await tap("move_up")
	check("ook naar een grijze knop kun je bewegen (frame blijft 'uit')", b.cross.selected == 1 and cross_frame(b, 1) == 2)
	await tap("interact")
	await pframes(2)
	check("A op grijze Magie doet niets (kruis blijft open)", b.state == "command" and b.cross.active and not b.menu.visible)
	await click_at(b.cross.buttons[1].get_global_rect().get_center())
	check("tik op grijze Magie doet ook niets", b.state == "command" and b.cross.active)
	await tap("cancel")
	await pframes(2)
	check("B bij de eerste held: kruis blijft (er is geen vorige held)", b.state == "command" and b.cross.active and b.current_hero == 0)
	await tap("move_down")
	check("terug naar Aanval", b.cross.selected == 0)


## v0.13: doelwit wisselen met links/rechts (en op/neer), B terug naar het kruis.
func _target_cycle_tests(b: Node) -> void:
	var names: Array = b.target_list.map(func(c): return c["name"])
	check("doel-label toont de naam van het doel ('%s')" % b.target_name_label.text,
			b.target_name.visible and b.target_name_label.text == names[0] and b.target_index == 0)
	_check_target_ui(b, "doel = %s" % names[0], false)
	check_layout(b, "doelkeuze")
	await tap("move_right")
	await pframes(3)
	var r1: Rect2 = lrect(b, b.target_list[1]["node"])
	check("rechts: pijltje + label naar %s (%s)" % [names[1], b.target_cursor.tip()],
			b.target_index == 1 and b.target_name_label.text == names[1] and r1.grow(2).has_point(b.target_cursor.tip()))
	_check_target_ui(b, "doel = %s" % names[1], false)
	await battle_shot("_2c_target_two")
	await tap("move_right")
	check("rechts op de laatste: rond naar de eerste", b.target_index == 0)
	await tap("move_up")
	check("omhoog = vorige (rond naar de laatste)", b.target_index == names.size() - 1)
	await tap("move_down")
	check("omlaag = volgende", b.target_index == 0)
	await tap("cancel")
	await pframes(2)
	check("B: terug naar het kruis (pijltje en label weg, Aanval nog gekozen)",
			b.state == "command" and b.cross.visible and b.cross.active and b.cross.selected == 0
			and not b.target_cursor.visible and not b.target_name.visible)
	await choose_command(0)
	check("opnieuw Aanval: doelkeuze", await wait_battle_state(["target_enemy"]) == "target_enemy")
	await pframes(2)
	check("doelkeuze start weer bij de eerste vijand", b.target_index == 0)


## v7 'De Vergeten Bibliotheek': namen, tabjes, scanline-filter, grote sprites.
func _v7_style_checks(b: Node) -> void:
	var names: Array = b.enemies.map(func(e): return e["name"])
	check("v7-vijanden: %s" % [names], names.has("The Knowledge Beast") and names.has("Paper Wraith"))
	for id in GameData.ENEMIES:
		# v0.19: een vijand met "art_pending" (Inktwurm) mag tijdelijk een plaatsvervanger hebben
		var spr_ok := ResourceLoader.exists(GameData.ENEMIES[id]["sprite"]) or (bool(GameData.ENEMIES[id].get("art_pending", false))
				and ResourceLoader.exists(GameData.enemy_sprite(GameData.ENEMIES[id])))
		check("vijand '%s' bestaat als plaatje" % id, spr_ok)
	for g in GameData.ENCOUNTER_GROUPS:
		for id in g["enemies"]:
			if not GameData.ENEMIES.has(id):
				check("encountergroep met onbekende vijand '%s'" % id, false)
	var boss: Control = b.enemies[0]["node"]
	var hero_h: float = b.hero_nodes[0].SIZE.y
	check("Lore Beast groter dan een held (%.0f > %.0f)" % [boss.size.y, hero_h], boss.size.y > hero_h)
	check("v9: berichtvenster en tabje 'De Vergeten Library' zijn weg",
			b.get_node_or_null("MessageWindow") == null and b.get_node_or_null("MessageTab") == null)
	var cap: Rect2 = lrect(b, b.caption)
	var cap_style: StyleBox = b.caption.get_theme_stylebox("panel")
	check("bericht-strook bovenin, smal, half doorzichtig, palet (%s)" % cap,
			cap.position.y <= 4.0 and cap.size.y <= 16.0 and cap_style is StyleBoxFlat
			and (cap_style as StyleBoxFlat).bg_color.a < 0.9)
	check("v0.13: geen 'Wat doet X?'-strook tijdens het kiezen; naam-tabje boven het kruis ('%s')" % b.cross.name_label.text,
			not b.caption.visible and b.message_label.text == "What will %s do?" % GameState.party[0]["name"]
			and b.cross.name_label.text == "%s: Attack" % GameState.party[0]["name"])
	_check_cross(b, GameState.party[0]["name"])
	check("actieve held: gouden kaart (HUD v2 kaart_actief), naam in inkt", b.status_boxes[0].card_kind() == "actief" and b.status_boxes[0].name_color() == b.status_boxes[0].INK)
	check("HP-balken in het palet: Noor '%s', Lotte '%s'" % [b.status_boxes[1].hp_bar_kind(), b.status_boxes[2].hp_bar_kind()],
			b.status_boxes[1].hp_bar_kind() == "hp" and b.status_boxes[2].hp_bar_kind() == "hp")
	check("scanline-filter aan, over alles, vangt geen tikken",
			Crt.visible and Crt.layer >= 100 and Crt.scanlines.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and Crt.glitch.mouse_filter == Control.MOUSE_FILTER_IGNORE and Crt.current_intensity() > 0.0)
	check("scanline-sterkte uit game_data.gd (%.2f)" % Crt.current_intensity(),
			is_equal_approx(Crt.current_intensity(), float(GameData.CRT["scanlines"])))
	Crt.set_enabled(false)
	var off := not Crt.visible and not Crt.is_processing()
	Crt.set_enabled(true)
	check("scanline-filter aan/uit te zetten", off and Crt.visible)
	Crt.start_glitch(0.05)
	check("glitch gaat aan", Crt.glitch.visible)
	check("battle-assets voorgeladen (geen laden bij een encounter)",
			GameState._loaded.has(GameState.BATTLE_SCENE) and GameState._loaded.has(GameData.backdrop_path("grass")))


## Inhoud van het overwinningsvenster controleren.
func _check_victory_window(b: Node) -> void:
	var exp_total := 0
	var gold_total := 0
	for e in b.enemies:
		exp_total += int(e["s"]["exp"])
		gold_total += int(e["s"]["gold"])
	var lines: PackedStringArray = b.victory_label.text.split("\n")
	print("INFO  overwinningsvenster:\n      " + "\n      ".join(lines))
	check("bericht-strook weg, overwinningsvenster in beeld", not b.caption.visible and b.victory_panel.visible)
	check("regel 'Krijgt %d EXP.'" % exp_total, lines.size() > 0 and lines[0] == "Gained %d EXP." % exp_total)
	check("regel 'Krijgt %d GOUD.'" % gold_total, lines.size() > 1 and lines[1] == "Gained %d GOLD." % gold_total)
	var ok := lines.size() == 3 + GameState.party.size()
	for i in GameState.party.size():
		var h: Dictionary = GameState.party[i]
		var need: int = GameData.exp_for_level(h["level"] + 1) - h["exp"]
		var line: String = lines[3 + i] if 3 + i < lines.size() else ""
		var parts := line.split(" ", false)
		if not (line.begins_with(h["name"]) and "NEXT LEVEL" in line and parts.size() > 0 and parts[parts.size() - 1] == str(need)):
			ok = false
	check("per held 'Naam NEXT LEVEL <nodig>' klopt", ok)
	var r: Rect2 = lrect(b, b.victory_panel)
	check("overwinningsvenster groot en bovenin (%s)" % r, r.size.x >= 280 and r.position.y < 20 and r.end.y < 140)
	# v0.16: buit/beloning in hetzelfde blauwe Lufia 2-vak als de tekstvakken (tekstvak_blauw.png)
	check("v0.16: buit-venster = blauw tekstvak van RPG ART (tekstvak_blauw.png, witte tekst)",
			UiStyle.is_blue_box(b.victory_panel.get_theme_stylebox("panel"), "vak")
			and b.victory_label.get_theme_color("font_color") == UiStyle.BOX_TEXT)


func _four_heroes_test() -> void:
	# 10) Vier helden: de layout moet meeschalen (tijdelijke testheld).
	var extra: Dictionary = GameState.party[2].duplicate(true)
	extra["name"] = "Test"
	extra["battle_sprite"] = "res://bestaat/niet.png"   # test ook het reserve-plaatje
	GameState.party.append(extra)
	GameState.debug_force_group = ["papiergeest", "glitchmot", "kennis_beest"]
	await tap("debug_battle")
	check("gevecht met 4 helden geladen", await wait_scene("Battle"))
	var b := battle()
	if b != null and await wait_hero(0):
		check("4 heldensprites en 4 statusvakken", b.hero_nodes.size() == 4 and b.status_boxes.size() == 4)
		check("statusvakken breed genoeg (%d px)" % b.status_boxes[3].size.x, b.status_boxes[3].size.x >= 50)
		check_layout(b, "4 helden + 3 vijanden")
		_check_heroes_on_boxes(b, "4 helden")
		_check_enemies_top(b, "4 helden + 3 vijanden")
		await check_bars(b, "4 helden")
		Engine.time_scale = 1.0
		await pframes(10)
		await battle_shot("_6_four_heroes")
		Engine.time_scale = 3.0
		for guard in 20:
			var st := await wait_battle_state(["command", "message_wait"], 30)
			if st == "":
				break
			if st == "command":
				await choose_command(4)   # Vluchten
			else:
				await tap("interact")
	check("terug na 4-heldengevecht", await wait_scene("Wereldkaart"))
	await frames(5)
	GameState.party.erase(extra)
	check("testheld weer weg", GameState.party.size() == 3)


func _flee_test() -> void:
	# 8) Vluchten (gevecht geforceerd met F2 / actie debug_battle)
	GameState.debug_force_group = ["papiergeest"]
	var before := tile()
	await tap("debug_battle")
	check("F2 forceert een gevecht", GameState.in_battle)
	check("vlucht-gevecht geladen", await wait_scene("Battle"))
	# Eerst met TIKKEN: Aanval-knop, dan de vijand aantikken.
	check("commandomenu (tik-test)", await wait_hero(0))
	var b := battle()
	await click_at(b.cross.buttons[0].get_global_rect().get_center())
	check("tik op 'Aanval' opent doelkeuze", await wait_battle_state(["target_enemy"], 5) == "target_enemy")
	await pframes(2)
	check("tik op 'Aanval': pijltje + label bij de vijand", b.target_cursor.visible and b.target_name.visible
			and b.target_name_label.text == b.enemies[0]["name"])
	await click_at(b.enemies[0]["node"].get_global_rect().get_center())
	check("tik op vijand kiest doel -> Noor aan de beurt", await wait_hero(1))
	# B bij Noor = terug naar Dennis
	await tap("cancel")
	check("B gaat terug naar de vorige held (Dennis)", await wait_hero(0))
	# Tik op 'Vluchten'
	await click_at(b.cross.buttons[4].get_global_rect().get_center())
	await pframes(2)
	check("tik op 'Vluchten' start de vluchtpoging",
			battle() != null and battle().message_label.text.begins_with("The party tries"))
	for guard in 20:
		var st := await wait_battle_state(["command"], 30)
		if st == "":
			break
		await choose_command(4)   # Vluchten
	check("terug op de wereldkaart na vluchten", await wait_scene("Wereldkaart"))
	await frames(5)
	check("uitslag = flee", GameState.last_battle_result == "flee")
	check("zelfde tile na vluchten: %s" % tile(), tile() == before)


func _game_over_test() -> void:
	# 9) Game over: iedereen 1 HP, 3 snelle glitchmotten, alleen verdedigen
	GameState.debug_force_group = ["glitchmot", "glitchmot", "glitchmot"]
	for h in GameState.party:
		h["hp"] = 1
	var gold_before := GameState.gold
	var cp_gold := int(GameState.checkpoint.get("state", {}).get("gold", -1))
	check("v0.19: kamer-checkpoint op de wereldkaart (14,31), goud %d (nu %d)" % [cp_gold, gold_before],
			str(GameState.checkpoint.get("map", "")).ends_with("wereldkaart.tscn")
			and GameState.checkpoint.get("tile") == [14, 31] and cp_gold >= 0)
	await tap("debug_battle")
	check("game-over-gevecht geladen", await wait_scene("Battle"))
	var game_over_seen := false
	for guard in 200:
		var st := await wait_battle_state(["command", "message_wait"], 60)
		if st == "" or battle() == null:
			break
		if st == "command":
			await choose_command(3)   # Verdedig
		else:
			if "GAME OVER" in battle().message_label.text and not game_over_seen:
				game_over_seen = true
				check("alle helden in KO-pose", battle().hero_nodes.all(func(n): return n.is_ko and n.pose == "ko"))
				Engine.time_scale = 1.0
				await pframes(10)
				await battle_shot("_5_gameover")
				Engine.time_scale = 3.0
			await tap("interact")
	Engine.time_scale = 1.0
	check("GAME OVER-bericht", game_over_seen)
	# v0.19: niet meer naar Wilgendal (helft goud kwijt), maar terug waar je de wereldkaart
	# binnenkwam (net buiten Wilgendal, (14,31)) met de voortgang van toen
	check("v0.19: na game over terug op de wereldkaart", await wait_scene("Wereldkaart"))
	await frames(5)
	check("uitslag = lose", GameState.last_battle_result == "lose")
	check("v0.19: respawn waar je de wereldkaart binnenkwam (14,31): %s" % tile(), tile() == Vector2i(14, 31)
			and GameState.last_respawn.get("map", "") == GameState.current_map)
	var all_full := GameState.party.all(func(h): return h["hp"] == h["max_hp"] and h["mp"] == h["max_mp"])
	check("party volledig genezen", all_full)
	check("v0.19: goud zoals bij binnenkomst (geen helft kwijt): %d -> %d" % [cp_gold, GameState.gold], GameState.gold == cp_gold)
	for i in 120:
		if Dialog.is_open:
			break
		await frames(1)
	check("v0.19: 'You wake...' (verteller)", Dialog.is_open and "wake" in str(Dialog._lines[0]))
	await close_dialog()


func _stairs_and_town_return_tests() -> void:
	GameState.encounter_multiplier = 0.0
	check("voor de trap-test op (21,31): %s" % tile(), tile() == Vector2i(21, 31))
	# Bos-achtergrond: F2 in het bos -> bibliotheek_overwoekerd (los van de trap, kort gevecht vluchten)
	# De trap op (20,34): over het zand (20,32), (20,33) naar beneden
	await walk("move_left", 1)
	await walk("move_down", 2)
	check("zand is begaanbaar (20,33) = %s" % terrain(tile()), tile() == Vector2i(20, 33) and terrain(tile()) == "zand")
	await walk("move_down", 1)
	check("op de trap (20,34) = %s" % terrain(tile()), tile() == Vector2i(20, 34) and terrain(tile()) == "trap")
	# v0.13: de trap is de ingang van De Vergeten Archieven (eerste dungeonkamer)
	check("v0.13: trap -> The Forgotten Archives (ArchiefIngang)", await wait_scene("ArchiefIngang"))
	await frames(5)
	check("v0.13: binnen bij de ingang (9,10): %s" % tile(), tile() == Vector2i(9, 10))
	check("v0.13: dungeon zonder random encounters", scene().encounters == false)
	await walk("move_down", 1)
	check("v0.13: uitgang van de dungeon -> wereldkaart", await wait_scene("Wereldkaart"))
	await frames(5)
	check("v0.13: terug net boven de trap (20,33), kijkt omhoog: %s" % tile(), tile() == Vector2i(20, 33)
			and player().facing == Vector2i.UP)
	await overworld_shot("_stairs")

	# Gevecht in het bos krijgt de bos-achtergrond
	await walk("move_up", 2)
	await walk("move_left", 6)
	await walk("move_down", 2)
	check("in het bos (14,33): %s" % tile(), tile() == Vector2i(14, 33))
	# (bij screenshots: Kennis-Beest + Papiergeest, zoals de mockup)
	GameState.debug_force_group = ["kennis_beest", "papiergeest"] if battle_shots != "" else ["papiergeest"]
	await tap("debug_battle")
	check("bos -> gras-achtergrond (%s)" % GameState.pending_backdrop, GameState.pending_backdrop.ends_with("battle_bg/gras.png"))
	if await wait_scene("Battle"):
		var b := battle()
		await wait_hero(0)
		check("gevechtsscherm toont de gras-achtergrond", b.get_node("Backdrop").texture.resource_path.ends_with("battle_bg/gras.png"))
		if battle_shots != "":
			await frames(20)
			await battle_shot("_7_forest_menu")
		Engine.time_scale = 3.0
		for guard in 20:
			var st := await wait_battle_state(["command", "message_wait"], 30)
			if st == "":
				break
			if st == "command":
				await choose_command(4)   # Vluchten
			else:
				await tap("interact")
		Engine.time_scale = 1.0
	check("terug in het bos na vluchten", await wait_scene("Wereldkaart") and tile() == Vector2i(14, 33))
	await frames(5)

	# Terug het dorp in via het stad-icoon (14,30)
	await walk("move_up", 2)
	check("terug op de spawn (14,31): %s" % tile(), tile() == Vector2i(14, 31))
	await walk("move_up", 1)
	check("stad-icoon -> dorp Willowdale geladen", await wait_scene("Wilgendal"))
	await frames(5)
	check("in het dorp bij de zuid-ingang (15,19): %s" % tile(), tile() == Vector2i(15, 19))
	check("kijkt omhoog (het dorp in)", player() != null and player().facing == Vector2i.UP)
	check("huidige map = wilgendal.tscn", GameState.current_map.ends_with("wilgendal.tscn"))
	await frames(20)
	await overworld_shot("_town_south")
	# En weer naar buiten
	await walk("move_down", 4)
	check("weer naar buiten -> wereldkaart", await wait_scene("Wereldkaart"))
	await frames(5)
	check("weer op de spawn (14,31): %s" % tile(), tile() == Vector2i(14, 31))



## v0.13: SAPIENTIA - De Vergeten Archieven, glitch, eigen art als die er is, app-naam.
## Met title_main.png is die plaat de hoofdpagina (titel zit erin); logo/kern/glitch blijven weg.
func _title_v13_checks(t: Node) -> void:
	var has_main := ResourceLoader.exists("res://assets/ui/title_main.png")
	var has_logo := ResourceLoader.exists("res://assets/ui/title_logo.png")
	var has_bg := ResourceLoader.exists("res://assets/ui/title_bg.png")
	check("titel 'SAPIENTIA', ondertitel 'The Forgotten Archives'",
			t.title_label.text == "SAPIENTIA" and t.subtitle_label.text == "The Forgotten Archives")
	if has_main:
		var main_path: String = t.background.texture.resource_path
		check("hoofdpagina title_main.png, geen logo/kern/glitch erover (%s)" % main_path.get_file(),
				main_path.ends_with("title_main.png") and t.backfill.texture.resource_path.ends_with("title_main.png")
				and t.logo == null and t.kern == null and t.subtitle_art == null and t.glitch == null
				and not t.title_label.visible and not t.subtitle_label.visible
				and t.background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	elif has_logo:
		check("logo van RPG ART (title_logo.png 208x36) op (88,10) i.p.v. de tekst (%s %s)" % [t.glitch.position, t.glitch.size],
				t.logo != null and t.glitch.content == t.logo and not t.title_label.visible
				and t.glitch.position == Vector2(88, 10) and t.glitch.size == Vector2(208, 36))
		if ResourceLoader.exists("res://assets/ui/title_ondertitel.png"):
			check("ondertitel-art 130x13 op (127,43) i.p.v. tekst, nearest", t.subtitle_art != null and t.subtitle_art.position == Vector2(127, 43) and t.subtitle_art.size == Vector2(130, 13) and t.subtitle_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
					and not t.subtitle_label.visible)
		if ResourceLoader.exists("res://assets/ui/title_kern.png"):
			var seen := {}
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 900:
				seen[t.kern_frame] = true
				await get_tree().process_frame
			check("kern van de Golem op (188,50), 4 frames 24x28, loopt (%s)" % [seen.keys()],
					t.kern.position == Vector2(188, 50) and t.kern.size == Vector2(24, 28) and t.kern_frames.size() == 4
					and seen.size() >= 4)
	else:
		check("nog geen title_logo.png: titel als tekst met het pixelfont", t.logo == null
				and t.glitch.content == t.title_label and t.title_label.is_visible_in_tree() and t.subtitle_label.is_visible_in_tree())
	if not has_main:
		var bg_path: String = t.background.texture.resource_path
		check("achtergrond: %s (%s)" % [bg_path.get_file(), "title_bg.png van RPG ART" if has_bg else "nog de bibliotheek"],
				bg_path.ends_with("title_bg.png") if has_bg else bg_path.ends_with("bibliotheek.png"))
	check("app-/projectnaam SAPIENTIA", ProjectSettings.get_setting("application/config/name") == "SAPIENTIA")
	if FileAccess.file_exists("res://export_presets.cfg"):
		var cfg := ConfigFile.new()
		cfg.load("res://export_presets.cfg")
		var ok := true
		var android := 0
		for sec in cfg.get_sections():
			if str(sec).ends_with(".options"):
				continue
			if str(cfg.get_value(sec, "platform", "")) != "Android":
				continue
			android += 1
			var opt := str(sec) + ".options"
			ok = ok and cfg.get_value(opt, "package/name", "") == "SAPIENTIA" \
					and cfg.get_value(opt, "package/unique_name", "") == "com.dennis.rpgprototype"
		check("Android-label SAPIENTIA, pakket blijft com.dennis.rpgprototype (update over de oude APK)", ok and android >= 1)
		var web_vk := false
		for sec in cfg.get_sections():
			if str(cfg.get_value(sec, "platform", "")) == "Web":
				web_vk = bool(cfg.get_value(str(sec) + ".options", "html/experimental_virtual_keyboard", false))
		check("web: schermtoetsenbord aan, zodat de naam op de telefoon te wijzigen is", web_vk)
	# v0.13: alle titel-art staat in een vaste stage van 384x216 midden in beeld (ook op een
	# breder/hoger scherm, zoals headless); het menu staat rechtsonder IN die stage.
	var st: Rect2 = t.stage.get_global_rect()
	var cr: Rect2 = t.card.get_global_rect()
	cr.position -= st.position
	check("titel-stage 384x216 in het midden van het scherm (%s in %s)" % [st, t.size],
			st.size == Vector2(384, 216) and absf(st.get_center().x - t.size.x / 2.0) <= 1.0
			and absf(st.get_center().y - t.size.y / 2.0) <= 1.0)
	check("menu rechtsonder (x 240..372, y ~150..200): %s" % cr,
			absf(cr.position.x - 240.0) <= 1.0 and absf(cr.end.x - 372.0) <= 1.0 and cr.end.y <= 201.0 and cr.position.y >= 148.0)
	check("versielabel v0.20 rechtsonder (%s)" % t.version_label.text, t.version_label.text == "v0.20"
			and t.version_label.get_global_rect().end.x <= t.size.x and t.version_label.get_global_rect().end.y <= t.size.y)
	if has_main:
		return
	var g: Control = t.glitch
	if not g.strip_frames.is_empty():
		var frames_seen := {}
		var back_to_0 := false
		var start_b: int = g.bursts
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 7000:
			await get_tree().process_frame
			frames_seen[g.strip_frame] = true
			if g.bursts > start_b and not g.is_glitching():
				back_to_0 = g.strip_frame == 0 and t.logo.visible and not g.strip_rect.visible
				break
		check("logo-glitch van RPG ART: 6 frames, speelt 1x (gezien %s), daarna frame 0" % [frames_seen.keys()],
				g.strip_frames.size() == 6 and frames_seen.size() >= 5 and back_to_0)
		check("logo-glitch: elke 3-5 s, 12-15 fps", g.STRIP_GAP_MIN >= 3.0 and g.STRIP_GAP_MAX <= 5.0
				and g.STRIP_FPS >= 12.0 and g.STRIP_FPS <= 15.0 and g._wait >= 2.9 and g._wait <= 5.0)
		check("lichte glitch op de achtergrond (smal plakje)", g._bg_slice != null)
		return
	# glitch: binnen een paar seconden minstens één burst, daarna weer rustig
	var seen_split := false
	var seen_slice := false
	var seen_bg := false
	var calm_after := false
	var t0 := Time.get_ticks_msec()
	var start_bursts: int = g.bursts
	while Time.get_ticks_msec() - t0 < 7000:
		await get_tree().process_frame
		if g.is_glitching():
			seen_split = seen_split or g._split.any(func(c): return c.visible)
			seen_slice = seen_slice or g._slices.any(func(c): return c.visible)
			seen_bg = seen_bg or g._bg_slice.visible
		elif g.bursts > start_bursts and seen_split:
			calm_after = not g._split.any(func(c): return c.visible) and not g._slices.any(func(c): return c.visible)
			if calm_after:
				break
	check("titel-glitch: burst met roze/teal RGB-split + verschoven plakjes, daarna rustig (bursts %d)" % g.bursts,
			g.bursts > start_bursts and seen_split and seen_slice and calm_after)
	check("lichte glitch op de achtergrond (smal plakje)", seen_bg or g._bg_slice != null)
	check("glitch-kleuren uit het palet (GLITCH roze, TEAL)", g._split.size() == 2 and t.title_label.get_theme_color("font_shadow_color") == UiStyle.GLITCH_DIM)


# ================================================================ v0.10
## Titelscherm -> Nieuw spel -> naam kiezen ('Kees') -> Wilgendal met een party van 1.
func _title_and_name_tests() -> void:
	check("titelscherm verschijnt bij de start", await wait_scene("Title"))
	await frames(20)
	var t := scene()
	await _title_v13_checks(t)
	check("autotest gebruikt een eigen save (%s)" % GameState.save_path, GameState.save_path != "user://save_1.json")
	check("geen save: 'Doorgaan' uitgeschakeld", not GameState.has_save() and t.continue_button.disabled)
	check("'Nieuw spel' heeft de focus", t.new_button.has_focus())
	await overworld_shot("_title_nosave")
	await click_at(t.continue_button.get_global_rect().get_center())
	await frames(5)
	check("tik op grijze 'Doorgaan' doet niets", map_name() == "Title")
	await click_at(t.new_button.get_global_rect().get_center())
	check("'Nieuw spel' -> naamscherm", await wait_scene("NameEntry"))
	await frames(10)
	var n := scene()
	check("'Hoe heet je?' voorgevuld met 'Dennis'", n.edit.text == "Dennis" and n.chosen_name() == "Dennis")
	check("LineEdit: te wijzigen, schermtoetsenbord aan, max. 10 tekens, focus",
			n.edit.editable and n.edit.virtual_keyboard_enabled and n.edit.select_all_on_focus
			and n.edit.max_length == 10 and n.edit.has_focus())
	check("lege naam -> 'Dennis', te lang -> 10 tekens",
			GameState.clean_name("   ") == "Dennis" and GameState.clean_name("Abcdefghijklmn") == "Abcdefghij")
	n.edit.text = ""
	check("leeg veld kiest 'Dennis'", n.chosen_name() == "Dennis")
	n.edit.text = "Dennis"
	await frames(10)
	await overworld_shot("_name_entry")
	n.edit.text = "Kees"
	await click_at(n.ok_button.get_global_rect().get_center())
	check("OK -> nieuw spel: wakker worden in het huis", await wait_scene("Huis"))
	check("naam = Kees", GameState.player_name == "Kees")
	check("nieuw spel: party van 1 (Dennis-sprites/stats, naam Kees)", GameState.party.size() == 1
			and GameState.party[0]["id"] == "dennis" and GameState.party[0]["name"] == "Kees"
			and GameState.party[0]["max_hp"] == GameData.HEROES[0]["max_hp"])
	check("Noor en Lotte nog niet in de party (wel in de data)",
			not GameState.has_member("noor") and not GameState.has_member("lotte")
			and not GameState.hero_template("noor").is_empty())


## Binnen in het huis: muren, kamer in beeld, opslagboek (Nee en Ja), weer naar buiten.
func _house_tests() -> void:
	var p := player()
	check("map = huis_wilgendal.tscn (%s)" % GameState.current_map, GameState.current_map.ends_with("huis_wilgendal.tscn"))
	check("binnen op het spawnpunt (4,7), kijkt omhoog: %s" % tile(), tile() == Vector2i(4, 7) and p.facing == Vector2i.UP)
	check("binnen: geen gevechten", scene().encounters == false)
	var used: Rect2i = scene().get_node("Ground").get_used_rect()
	check("kamer van 12x9 tiles (%s)" % used, used.size == Vector2i(12, 9))
	var cam: Camera2D = p.camera
	check("kleine kamer staat midden in beeld (camera %d..%d)" % [cam.limit_left, cam.limit_right],
			cam.limit_left + cam.limit_right == used.size.x * 16 and cam.limit_top + cam.limit_bottom == used.size.y * 16)
	check("opslagboek staat op (8,3)", scene().get_node("Objects/SaveBook").position == Vector2(8 * 16 + 8, 3 * 16 + 8))
	var book: Node = scene().get_node("Objects/SaveBook")
	var f0: int = book.sprite.frame
	var frames_seen := {f0: true}
	for i in 40:
		await frames(2)
		frames_seen[book.sprite.frame] = true
	check("boek gloeit (animatie, %d frames gezien)" % frames_seen.size(), frames_seen.size() >= 3 and book.sprite.hframes == 4)
	# cyaan aura: additieve zachte gloed, straal 2-3 tiles, pulseert (alpha 0,25..0,6)
	var aura: Sprite2D = book.get_node_or_null("Aura")
	check("opslagboek heeft een cyaan aura (additief, straal %.0f px)" % (aura.texture.get_width() / 2.0 if aura else 0.0),
			aura != null and aura.material is CanvasItemMaterial and aura.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
			and aura.texture.get_width() / 2.0 >= 32.0 and aura.texture.get_width() / 2.0 <= 48.0
			and book.aura_color.is_equal_approx(Color("3ff0ff")))
	if aura:
		var a_lo := 9.0
		var a_hi := -9.0
		var s_lo := 9.0
		var s_hi := -9.0
		for i in 70:
			await frames(2)
			a_lo = minf(a_lo, aura.modulate.a)
			a_hi = maxf(a_hi, aura.modulate.a)
			s_lo = minf(s_lo, aura.scale.x)
			s_hi = maxf(s_hi, aura.scale.x)
		check("aura pulseert (alpha %.2f..%.2f, schaal %.2f..%.2f, periode %.1f s)" % [a_lo, a_hi, s_lo, s_hi, book.AURA_PERIOD],
				a_lo >= 0.24 and a_hi <= 0.61 and a_hi - a_lo > 0.2 and s_hi - s_lo > 0.1
				and book.AURA_PERIOD >= 1.6 and book.AURA_PERIOD <= 2.0)
	check("na de proloog staat de Oude Man niet meer binnen", not scene().get_node("Objects/OudeMan").visible)
	await walk("move_left", 5)
	check("zijmuur blokkeert, staat op (1,7): %s" % tile(), tile() == Vector2i(1, 7))
	await walk("move_right", 3)
	await walk("move_up", 5)
	check("boekenkast/raam blokkeert, staat op (4,3): %s" % tile(), tile() == Vector2i(4, 3))
	await walk("move_down", 1)
	await walk("move_right", 4)
	await walk("move_up", 1)
	check("voor het boek (8,4), kijkt omhoog (boek blokkeert): %s" % tile(), tile() == Vector2i(8, 4) and player().facing == Vector2i.UP)
	await frames(20)
	await overworld_shot("_house")
	check("opslagboek = boekpunt type 'save' (cyaan)", book.type == "save" and book.aura_color.is_equal_approx(Color("3ff0ff")))
	# v0.12: het opslagboek vult eerst HP en MP van de hele party aan (even met Noor erbij, die MP heeft)
	var keep_party: Array = GameState.party.duplicate(true)
	GameState.party.append(GameState.hero_template("noor"))
	for h in GameState.party:
		h["hp"] = 1
		h["mp"] = 0
	# Eerst 'Nee'
	await press_interact()
	check("opslagboek: eerst '%s', HP en MP van de hele party vol" % NEW_SAVE_LINE,
			Dialog.is_open and Dialog._lines == [NEW_SAVE_LINE]
			and GameState.party.all(func(h): return h["hp"] == h["max_hp"] and h["mp"] == h["max_mp"])
			and GameState.party[1]["mp"] > 0)
	GameState.party = keep_party
	await _wait_typed()
	await press_interact()
	check("vraag: 'Het boek gloeit zacht. Voortgang opslaan?' met Ja/Nee",
			Dialog.has_choices() and Dialog._lines == ["The book glows softly. Save progress?"] and Dialog.choices == ["Yes", "No"])
	await _wait_typed()
	check("MENU-knop verborgen zolang het tekstvak open is", not scene().get_node("TouchControls/Control").show_menu)
	await tap("move_down")
	check("omlaag kiest 'Nee'", Dialog.choice_index == 1)
	await press_interact()
	check("'Nee': niets opgeslagen", not Dialog.is_open and book.last_result == "declined" and not GameState.has_save())
	# Dan 'Ja'
	await press_interact()
	await _wait_typed()
	check("opnieuw eerst de gloed-regel", Dialog._lines == [NEW_SAVE_LINE])
	await press_interact()
	await _wait_typed()
	check("'Ja' staat voorgeselecteerd", Dialog.choice_index == 0)
	await frames(30)
	await overworld_shot("_save_dialog")
	await press_interact()
	check("'Ja': 'Opgeslagen.'", Dialog.is_open and Dialog._lines == ["Saved."] and book.last_result == "saved")
	check("save geschreven (%s)" % GameState.save_path, GameState.has_save())
	var d := GameState.read_save()
	check("save: map, plek (8,4) en kijkrichting omhoog",
			str(d.get("map", "")).ends_with("huis_wilgendal.tscn") and _v2i(d.get("tile", [])) == Vector2i(8, 4)
			and _v2i(d.get("facing", [])) == Vector2i(0, -1))
	check("save: naam, party (1 held met HP/MP/level/exp), goud, items, speeltijd",
			d.get("player_name") == "Kees" and d["party"].size() == 1 and d["party"][0]["name"] == "Kees"
			and d["party"][0].has("hp") and d["party"][0].has("mp") and d["party"][0].has("level") and d["party"][0].has("exp")
			and d.has("gold") and d["inventory"].has("drankje") and float(d.get("play_time", -1)) >= 0.0 and d.has("bestiary"))
	await close_dialog()
	# Naar buiten: deur onderin op (4,8)
	await walk("move_left", 4)
	await walk("move_down", 4)
	check("deur onderin -> terug in Willowdale", await wait_scene("Wilgendal"))
	await frames(5)
	check("net onder de huisdeur (16,7), kijkt omlaag: %s" % tile(), tile() == Vector2i(16, 7) and player().facing == Vector2i.DOWN)


func _v2i(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1])) if a is Array and a.size() == 2 else Vector2i(-999, -999)


func _wait_typed() -> void:
	for i in 200:
		if not Dialog.is_open or not Dialog._is_typing():
			break
		await frames(1)
	await frames(3)


## Doorgaan opent de slotlijst; slot 1 is de bestaande save (of de autosave van dat slot).
func _click_continue_slot() -> void:
	var t := scene()
	await click_at(t.continue_button.get_global_rect().get_center())
	await frames(5)
	var slots := scene().get_node_or_null("SaveSlotList")
	var slot1: Node = slots.find_child("Slot1", true, false) if slots != null else null
	if slot1 != null:
		await click_at(slot1.get_global_rect().get_center())


## Laden: eerst alles veranderen, dan via het titelscherm 'Doorgaan'.
func _load_restore_test() -> void:
	var d := GameState.read_save()
	var saved_hp := int(d["party"][0]["hp"])
	var saved_gold := int(d["gold"])
	var saved_exp := int(d["party"][0]["exp"])
	GameState.party[0]["hp"] = 3
	GameState.party[0]["exp"] += 7
	GameState.gold += 77
	GameState.set_player_name("Anders")
	# v0.11: het huis verlaten gaf een (nieuwere) autosave; deze test gaat over de
	# handmatige save van het boek, dus die autosave eerst weg (zie ook --menutest).
	for i in 60:      # autosave komt net na de fade-in (map.gd AUTOSAVE_DELAY)
		if GameState.has_autosave() and GameState.last_autosave_reason == "map":
			break
		await frames(2)
	check("v0.11: autosave na het verlaten van het huis (%s)" % GameState.last_autosave_reason,
			GameState.has_autosave() and GameState.last_autosave_reason == "map")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.autosave_path))
	GameState.go_to_title()
	check("terug naar het titelscherm", await wait_scene("Title"))
	await frames(20)
	var t := scene()
	check("save gevonden: 'Doorgaan' aan en gekozen", not t.continue_button.disabled and t.continue_button.has_focus())
	check("titel toont de save (%s)" % t.save_info.text, "Kees" in t.save_info.text)
	var card_style = t.card.get_theme_stylebox("panel")
	check("Doorgaan-kaartje (naam, tijd) in een paletvenster",
			t.save_info.visible and ":" in t.save_info.text and card_style is StyleBoxFlat
			and (card_style as StyleBoxFlat).bg_color.is_equal_approx(Color(UiStyle.INK, UiStyle.PANEL_ALPHA))
			and (card_style as StyleBoxFlat).border_color == UiStyle.BORDER)
	if t.glitch:
		t.glitch._wait = 99.0          # rustig beeld voor de screenshot
		t.glitch._burst_left = 0.0
		t.glitch._hide_all()
		await frames(2)
		await overworld_shot("_title")
		t.glitch.force_glitch()
		for i in 30:
			await get_tree().process_frame
			if t.glitch.is_glitching() and (t.glitch._split[0].visible or t.glitch.strip_frame >= 2):
				break
		await overworld_shot("_title_glitch")
	else:
		await frames(2)
		await overworld_shot("_title")
	await _click_continue_slot()
	check("'Doorgaan' -> het huis (opgeslagen map)", await wait_scene("Huis"))
	await frames(5)
	check("plek (8,4) en kijkrichting omhoog hersteld: %s" % tile(), tile() == Vector2i(8, 4) and player().facing == Vector2i.UP)
	check("naam hersteld (Kees)", GameState.player_name == "Kees" and GameState.party[0]["name"] == "Kees")
	check("party hersteld: 1 held, HP %d, EXP %d" % [GameState.party[0]["hp"], GameState.party[0]["exp"]],
			GameState.party.size() == 1 and GameState.party[0]["hp"] == saved_hp and GameState.party[0]["exp"] == saved_exp
			and GameState.party[0]["max_hp"] == int(d["party"][0]["max_hp"]) and GameState.party[0]["level"] == int(d["party"][0]["level"]))
	check("goud hersteld (%d)" % GameState.gold, GameState.gold == saved_gold)
	check("speeltijd loopt door vanaf de save", GameState.play_time() >= float(d["play_time"]))
	await walk("move_left", 4)
	await walk("move_down", 4)
	check("weer naar buiten -> Willowdale", await wait_scene("Wilgendal"))
	await frames(5)
	check("weer op (16,7): %s" % tile(), tile() == Vector2i(16, 7))


## Vluchten tot het gevecht voorbij is (B/A-berichten doorklikken).
func _flee_battle() -> void:
	Engine.time_scale = 3.0
	for guard in 40:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		if st == "command":
			await choose_command(4)   # Vluchten
		else:
			await tap("interact")
	Engine.time_scale = 1.0


## Gevecht met alleen de hoofdpersoon; daarna sluiten Noor en Lotte aan (add_member).
func _solo_battle_test() -> void:
	check("party van 1 (alleen %s)" % GameState.player_name, GameState.party.size() == 1)
	var before := tile()
	GameState.debug_force_group = ["papiergeest"]
	await tap("debug_battle")
	check("solo-gevecht geladen", await wait_scene("Battle"))
	var b := battle()
	if b != null and await wait_hero(0):
		check("solo: 1 heldensprite en 1 statusvak", b.hero_nodes.size() == 1 and b.status_boxes.size() == 1)
		check("solo: naam 'Kees' in het statusvak", b.status_boxes[0].hero["name"] == "Kees" and b.status_boxes[0].fitted_name() == "Kees")
		check("solo: 'What will Kees do?' (%s)" % b.message_label.text, b.message_label.text == "What will Kees do?")
		var box: Rect2 = lrect(b, b.status_boxes[0])
		check("solo: statusvak in het midden (%.1f vs %.1f)" % [box.get_center().x, (b._menu_left + b._menu_right) / 2.0],
				absf(box.get_center().x - (b._menu_left + b._menu_right) / 2.0) <= 1.5)
		_check_heroes_on_boxes(b, "solo")
		_check_cross(b, "Kees")
		check_layout(b, "solo")
		check("solo: Magie grijs (Kees heeft geen spreuken), rest aan",
				not b.cross.is_enabled(1) and cross_frame(b, 1) == 2 and b.cross.is_enabled(0)
				and b.cross.is_enabled(2) and b.cross.is_enabled(3) and b.cross.is_enabled(4))
		check("solo: gras-achtergrond", GameState.pending_backdrop_id == "grass"
				and b.get_node("Backdrop").texture.resource_path.ends_with("battle_bg/gras.png"))
		check("bestiarium: Paper Wraith gezien, nog niet verslagen",
				GameState.is_seen("papiergeest") and GameState.defeated_count("papiergeest") == 0)
		# screenshot tijdens een actie (het menu dekt de enige held anders af)
		Engine.time_scale = 1.0
		await choose_command(0)
		await wait_battle_state(["target_enemy"])
		await tap("interact")
		for i in 120:
			if b.hero_nodes[0].stepped_forward and not b.cross.visible:
				break
			await pframes(1)
		await pframes(8)
		await battle_shot("_0_solo")
		await _flee_battle()
	check("terug na solo-gevecht op dezelfde tile", await wait_scene("Wereldkaart") and tile() == before)
	await frames(5)
	check("add_member: Noor en Lotte sluiten aan", GameState.add_member("noor") and GameState.add_member("lotte"))
	check("add_member: niet dubbel en geen onbekende held", not GameState.add_member("noor") and not GameState.add_member("niemand"))
	check("party nu 3: %s" % [GameState.party.map(func(h): return h["name"])], GameState.party.size() == 3
			and GameState.party[1]["name"] == "Noor" and GameState.party[2]["name"] == "Lotte")


## Bestiarium: gezien/verslagen bijhouden, het scherm (MENU-knop) en opslaan/laden.
func _bestiary_tests() -> void:
	check("bestiarium: Lore Beast en Paper Wraith verslagen (%s)" % [GameState.bestiary],
			GameState.defeated_count("kennis_beest") >= 1 and GameState.defeated_count("papiergeest") >= 1)
	check("bestiarium: Glitch Moth nog niet gezien", not GameState.is_seen("glitchmot") and GameState.defeated_count("glitchmot") == 0)
	for id in GameData.ENEMIES:
		var e: Dictionary = GameData.ENEMIES[id]
		check("bestiarium-data '%s' compleet" % id, e.has("no") and e.has("mp") and e.has("desc") and e.has("habitat")
				and e.has("drops") and e.has("weak") and e.has("resist") and e.has("exp") and e.has("gold"))
	var touch: Control = scene().get_node("TouchControls/Control")
	check("MENU-knop op het touchscherm (overworld)", touch.show_menu)
	var ev := InputEventScreenTouch.new()
	ev.index = 5
	ev.position = get_tree().root.get_final_transform() * touch.menu_rect().get_center()
	ev.pressed = true
	Input.parse_input_event(ev)
	await frames(3)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await frames(3)
	var fm: Node = scene().get_node_or_null("FieldMenu")
	check("MENU-knop opent het veldmenu (speler staat stil)", fm != null and player().input_locked)
	if fm == null:
		return
	fm.choose("bestiary")
	await frames(3)
	var bs: Node = fm.get_node_or_null("Bestiary")
	check("'Bestiary' opent het bestiarium", bs != null)
	if bs != null:
		var texts := []
		for i in bs.entries.size():
			texts.append(bs.entry_text(i))
		# v0.17: de lijst groeit mee met GameData.ENEMIES (Donker Woud: 007-010); de eerste 6 blijven gelijk.
		# Eindbazen van de Diepe Grot staan erachter (endgame_bestiary.gd), ongezien als ???.
		var n_all := GameData.ENEMIES.size() + EndgameBestiary.ids().size()
		check("lijst op nummer, ongezien = ??? %s" % [texts], texts.slice(0, 6) == ["001 Moss Slime", "002 ???", "003 Paper Wraith", "004 ???", "005 The Knowledge Beast", "006 ???"]
				and texts.size() == n_all and texts.slice(6).all(func(t): return str(t).ends_with("???")))
		check("kop telt gezien/verslagen (%s)" % bs.header.text, ("seen 3/%d" % n_all) in bs.header.text and ("defeated 3/%d" % n_all) in bs.header.text)
		bs.show_entry("glitchmot")
		check("ongezien: ??? en silhouet", bs.name_label.text == "004 ???" and bs.picture.modulate.v < 0.1 and not bs.stats_visible())
		bs.entries[4].grab_focus()
		await frames(2)
		check("gezien + verslagen: plaatje, naam, beschrijving en stats",
				bs.shown_id == "kennis_beest" and bs.picture.texture != null and bs.picture.modulate == Color.WHITE
				and bs.desc_label.text != "" and bs.stats_visible() and "HP 46" in bs.stats_label.text)
		await frames(10)
		await overworld_shot("_bestiary")
		await tap("cancel")
		await frames(3)
		check("B sluit het bestiarium (veldmenu blijft)", fm.get_node_or_null("Bestiary") == null and is_instance_valid(fm) and not fm.is_queued_for_deletion())
	await tap("cancel")
	await frames(3)
	check("B sluit het veldmenu, speler kan weer lopen", scene().get_node_or_null("FieldMenu") == null and not player().input_locked)
	# Opslaan en laden bewaart het bestiarium
	var before: Dictionary = GameState.bestiary.duplicate(true)
	check("opslaan met bestiarium", GameState.save_game(tile(), player().facing))
	GameState.bestiary.clear()
	GameState.mark_defeated("glitchmot")
	check("laden", GameState.load_game())
	GameState.has_return_point = false   # (niet van scène wisselen in deze test)
	var same := before.size() == GameState.bestiary.size()
	for id in before:
		same = same and GameState.is_seen(id) == bool(before[id]["seen"]) and GameState.defeated_count(id) == int(before[id]["defeated"])
	check("bestiarium na laden gelijk (%s)" % [GameState.bestiary], same and not GameState.is_seen("glitchmot"))
	check("party na laden nog steeds 3", GameState.party.size() == 3)


## Achtergrond per terrein (Lufia-stijl): gras, zand, baas.
func _backdrop_tests() -> void:
	check("terrein -> achtergrond (gras/tall grass/bos = grass, zand = sand, baas = boss)",
			GameData.backdrop_id_for("gras") == "grass" and GameData.backdrop_id_for("hoog_gras") == "grass"
			and GameData.backdrop_id_for("bos") == "grass" and GameData.backdrop_id_for("zand") == "sand"
			and GameData.backdrop_id_for("gras", true) == "boss")
	var all_ok := true
	for id in GameData.BACKDROPS:
		all_ok = all_ok and ResourceLoader.exists(GameData.BACKDROPS[id])
	check("alle achtergronden bestaan, 'library' bewaard", all_ok and GameData.BACKDROPS.has("library"))
	var saved_force: Array = GameState.debug_force_group
	GameState.debug_force_group = []
	var on_grass := {}
	var on_sand := {}
	for i in 300:
		for id in GameState.pick_encounter_group("gras"):
			on_grass[id] = true
		for id in GameState.pick_encounter_group("zand"):
			on_sand[id] = true
	GameState.debug_force_group = saved_force
	check("Moss Slime/Moss Rabbit op het gras, niet op het zand (gras %s, zand %s)" % [on_grass.keys(), on_sand.keys()],
			on_grass.has("mosslijm") and on_grass.has("moskonijn") and not on_sand.has("mosslijm")
			and not on_sand.has("moskonijn"))
	check("baas-encounter in de data (boss-vlag, nooit willekeurig)", not GameState.boss_group().is_empty()
			and int(GameState.boss_group()["weight"]) == 0)
	for h in GameState.party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	check("start zand-test op (21,31): %s" % tile(), tile() == Vector2i(21, 31))
	await walk("move_left", 1)
	await walk("move_down", 2)
	check("op het zand (20,33) = %s" % terrain(tile()), terrain(tile()) == "zand")
	GameState.debug_force_group = ["glitchmot", "papiergeest"]
	await tap("debug_battle")
	check("zand -> zand-achtergrond (%s)" % GameState.pending_backdrop_id, GameState.pending_backdrop_id == "sand" and not GameState.pending_boss)
	if await wait_scene("Battle"):
		var b := battle()
		await wait_hero(0)
		check("gevechtsscherm toont sand.png", b.get_node("Backdrop").texture.resource_path.ends_with("battle_bg/zand.png"))
		await frames(20)
		await battle_shot("_8_sand")
		await _flee_battle()
	check("terug op het zand", await wait_scene("Wereldkaart") and tile() == Vector2i(20, 33))
	await frames(5)
	await tap("debug_boss")
	check("F3: baasgevecht met boss-achtergrond", GameState.pending_boss and GameState.pending_backdrop_id == "boss")
	if await wait_scene("Battle"):
		var b := battle()
		await wait_hero(0)
		check("baas: Lore Beast + boss.png", b.enemies.size() >= 1 and b.enemies[0]["id"] == "kennis_beest"
				and b.get_node("Backdrop").texture.resource_path.ends_with("battle_bg/boss.png"))
		var br: Rect2 = lrect(b, b.enemies[0]["node"])
		var sx: float = b.stage_x(b.size.x, b.size.y)
		# v0.15: het kruis staat links; de vijandenrij begint rechts ervan (enemy_region)
		var reg: Array = b.enemy_region(b.size.x)
		var want := clampf(sx, float(reg[0]) + br.size.x / 2.0, float(reg[1]) - br.size.x / 2.0)
		check("baas staat bij de magenta cirkel, rechts van het kruis (x %.0f, cirkel %.0f)" % [br.get_center().x, sx],
				not is_nan(sx) and absf(br.get_center().x - want) <= 1.5 and br.position.x >= b.cross.cross_rect().end.x)
		check_layout(b, "baas")
		await frames(20)
		await battle_shot("_9_boss")
		# v0.15: vluchten kan niet in een baasgevecht; voor deze test zetten we het weer aan
		check("baas: 'Vluchten' staat uit (v0.15)", not b.can_flee and not b.cross.enabled[4])
		b.can_flee = true
		b.cross.enabled[4] = true
		await _flee_battle()
	check("terug na baas-test", await wait_scene("Wereldkaart"))
	await frames(5)
	check("Glitch Moth nu gezien in het bestiarium", GameState.is_seen("glitchmot"))
	for h in GameState.party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	await walk("move_up", 2)
	await walk("move_right", 1)
	check("terug op (21,31): %s" % tile(), tile() == Vector2i(21, 31))


# ================================================================ v0.11 proloog
const SD := preload("res://scripts/data/story_data.gd")
## v0.16: na de mantel (de zegels zijn weg): water + kist
const OPA_LINE := "That suits you, {naam}. Fetch water from the well and herbs from the chest beside the house. Today feels different."
## Update 5: ochtendtekst ingekort (Nederlands). Vóór deze update: 1 verplicht event
## (wakker_worden) en 7 tekstvakken (wakker 1 + opa 4 + mantel_aan 2) vóór de klusjes.
const INTRO_FORCED_WAS := 1
const INTRO_SAYS_WAS := 7
const GREET_LINE := "Good morning, {naam}. It's cold in the Warden's House."
const MENU_LINE := "Put on this cloak: MENU > Equipment > Armor."
const ITEM_LINE := "{naam} receives an Apprentice Cloak! Then close the menu."
const REMIND_LINE := "Put that cloak on first, {naam}. MENU > Equipment > Armor."
const INTRO_CHOICES := ["Good morning, Grandpa.", "Why do the Archives stay closed?"]
const ARMOR := "leerling_mantel"
const LESSON_LINE := "Sometimes you have to defend yourself, boy, even if I hope you never need to."
const PANIC_LINE := "No... the seal! It's too soon! {naam}, stay here! Lock the doors behind me and don't follow, no matter what you hear!"
const LOCKED_LINE := "The door is locked. Grandpa said I had to stay here."

var _drain_shot_done := {}


## Klik alle tekst door tot het verhaal-event klaar is. stop_on_choice: stop bij een keuze.
## shot_when: maak één screenshot (suffix) zodra een regel met die tekst helemaal staat.
func _story_drain(stop_on_choice := true, shot_when := "", shot_suffix := "", timeout := 60.0) -> void:
	var t := 0.0
	var quiet := 0
	while t < timeout:
		if Dialog.is_open:
			quiet = 0
			if Dialog._is_typing():
				await frames(1)
			else:
				if stop_on_choice and Dialog.has_choices():
					await _wait_typed()
					return
				if shot_when != "" and shot_when in str(Dialog._lines[Dialog._index]) and not _drain_shot_done.has(shot_suffix):
					_drain_shot_done[shot_suffix] = true
					await frames(20)
					await overworld_shot(shot_suffix)
				await press_interact()
		else:
			if Story.running or GameState.changing_map or GameState.in_battle:
				quiet = 0
			else:
				quiet += 1
				if quiet > 45:     # 0,75 s niets meer (physics-frames = echte tijd)
					return
			await frames(1)
		t += 1.0 / 60.0
	print("INFO  _story_drain: timeout")


func _lines_text() -> String:
	return "\n".join(Dialog._lines)


func _named(line: String) -> String:
	return line.replace("{naam}", GameState.player_name)


## v0.13: nieuwe dorpssprites van RPG ART (art_tiles_v14: dennis_dorp.png -> player.png,
## wachter_dorp.png -> wachter.png). Herkend aan het aantal niet-doorzichtige pixels.
const DORP_SPRITES := {"res://assets/sprites/player.png": 3016, "res://assets/sprites/wachter.png": 3220}


func _opaque_pixels(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return -1
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


func _dorpsprite_checks() -> void:
	var tex: Texture2D = player().sprite.texture
	check("speler-sprite = player.png 48x96, 3x4 frames van 16x24 (%s)" % tex.resource_path,
			tex.resource_path.ends_with("assets/sprites/player.png") and tex.get_size() == Vector2(48, 96)
			and player().sprite.hframes == 3 and player().sprite.vframes == 4)
	for path in DORP_SPRITES:
		var n := _opaque_pixels(path)
		if n < 0:
			print("INFO  %s: bron-png niet leesbaar, pixeltelling overgeslagen" % path)
			continue
		check("v0.13: %s = nieuwe dorpssprite van RPG ART (%d pixels, verwacht %d)" % [path.get_file(), n, DORP_SPRITES[path]],
				n == DORP_SPRITES[path])


func _wachter_ok(npc: Node) -> bool:
	return npc != null and npc.sprite.texture != null and npc.sprite.texture.resource_path.ends_with("assets/sprites/wachter.png") \
			and npc.sprite.hframes == 3 and npc.sprite.vframes == 4 and npc.sprite.texture.get_size() == Vector2(48, 96)


func _obj(n: String) -> Node:
	return scene().get_node_or_null("Objects/" + n) if scene() else null


## Scène 1 en 2 van de proloog, helemaal doorgespeeld (met opslaan/laden halverwege).
func _prologue_tests() -> void:
	# ---------------- scène 1: meteen vrij, daarna een vroege keuze
	check("nieuw spel: start in het huis", map_name() == "Huis")
	check("proloog begint op stap START", GameState.story_step == SD.START)
	await frames(15)
	var forced: Array = SD.forced_before_free()
	check("intro korter: verplichte events vóór het eerste vrije moment %d < %d" % [forced.size(), INTRO_FORCED_WAS],
			forced.is_empty() and forced.size() < INTRO_FORCED_WAS)
	var says := SD.intro_says_before_tasks()
	check("intro korter: %d verplichte tekstvakken vóór de klusjes < %d" % [says, INTRO_SAYS_WAS],
			says < INTRO_SAYS_WAS and says == 4)
	var spec: Dictionary = SD.early_choice_spec()
	var opts: Array = spec.get("options", [])
	check("vroeg keuzemenu bestaat: %d opties, zelfde vervolg" % opts.size(),
			opts == INTRO_CHOICES and SD.early_choice_same_followup()
			and str(spec.get("question", "")) == "What do you say, {naam}?")
	check("speler staat vrij naast het bed (2,3), geen wakker-cutscene: %s" % tile(),
			tile() == Vector2i(2, 3) and not player().input_locked and not Story.running and not Dialog.is_open
			and not Story.history.has("wakker_worden") and GameState.story_step == SD.START)
	check("Oude Man 's ochtends niet binnen", _obj("OudeMan") != null and not _obj("OudeMan").visible)
	# naar buiten (spawn staat al op (2,3); de bed-tile zelf is niet beloopbaar)
	await walk("move_right", 2)
	await walk("move_down", 5)
	check("deur -> naar buiten (Willowdale = huis aan de bosrand)", await wait_scene("Wilgendal"))
	await frames(10)
	var opa := _obj("OudeMan")
	check("buiten: voor de deur (16,7): %s" % tile(), tile() == Vector2i(16, 7))
	check("geen dorp meer: geen bordje en geen dorpsbewoners", _obj("Sign") == null and _obj("OldMan") == null)
	check("Oude Man buiten op (21,8), staart naar de ruïnes (omhoog)",
			opa != null and opa.visible and opa.get_tile() == Vector2i(21, 8) and opa.facing == Vector2i.UP)
	check("v0.13: Oude Man buiten = Warden-sprite (wachter.png, 3x4 frames, kijkt omhoog = rij 3)",
			_wachter_ok(opa) and opa.sprite.frame / 3 == 3)
	check("put, kist en de ingang van de Archives staan er",
			_obj("Put") != null and _obj("Kist") != null and _obj("Archief") != null)
	# v0.16 (wens Dennis): de '3 runen aanraken' (zegelstenen) zijn helemaal weg
	var seal_nodes: Array = scene().get_node("Objects").get_children().filter(func(n):
			return n.name.begins_with("Zegel") or ("event" in n and str(n.get("event")) == "zegel"))
	check("v0.16: runen weg: geen zegelstenen op de map (%s)" % [seal_nodes], seal_nodes.is_empty())
	check("v0.16: runen weg: geen 'zegel'-event, geen zegel-taken in het verhaal",
			not SD.EVENTS.has("zegel") and not ("SEALS" in SD) and SD.TASK_FLAGS == ["water_klaar", "kist_open"]
			and not str(SD.EVENTS).contains("zegels bij de bosrand") and not str(SD.EVENTS).contains("zegel_"))
	check("ingang dicht (frame 0, geen gloed)", _obj("Archief").sprite.frame == 0 and not _obj("Archief").glow.visible
			and not _obj("Archief").looping)
	var tint: CanvasModulate = scene().get_node_or_null("StoryTint")
	check("overdag: geen tint", tint != null and tint.color.is_equal_approx(Color.WHITE))
	# wereldkaart-uitgang is dicht tijdens de proloog
	await walk("move_down", 1)
	await walk("move_left", 1)
	await walk("move_down", 13)
	await frames(5)
	check("pad naar de wereldkaart: 'Not today' (%s)" % _lines_text(), Dialog.is_open and "Not today" in _lines_text())
	await _story_drain()
	check("teruggestuurd, nog op de proloog-map (15,20): %s" % tile(), map_name() == "Wilgendal" and tile() == Vector2i(15, 20))
	# praten met de Oude Man (van links)
	await walk("move_up", 11)
	await walk("move_right", 5)
	await walk("move_up", 1)
	await walk("move_right", 1)
	check("naast de Oude Man (20,8), kijkt naar rechts: %s" % tile(), tile() == Vector2i(20, 8) and player().facing == Vector2i.RIGHT)
	var def_before := int(GameState.party[0]["def"])
	await press_interact()
	await _wait_typed()
	check("vroeg keuzemenu bij Opa (%s)" % [Dialog.choices],
			Dialog.has_choices() and Dialog.choices == INTRO_CHOICES
			and _named("What do you say, {naam}?") in _lines_text() and Dialog.name_label.text == "Old Man")
	check("Oude Man draait naar je toe", opa.facing == Vector2i.LEFT)
	_check_bubble("keuze Opa", opa)
	await frames(20)
	await overworld_shot("_v11_intro_keuze")
	await press_interact()
	var greet_wait := 0
	while greet_wait < 300 and (not Dialog.is_open or Dialog.has_choices() or Dialog._is_typing()):
		await frames(1)
		greet_wait += 1
	check("v0.16: Oude Man begroet je en geeft een mantel ('%s')" % (Dialog._lines[0] if Dialog.is_open else ""),
			Dialog.is_open and not Dialog.has_choices() and Dialog._lines == [_named(GREET_LINE)]
			and Dialog.name_label.text == "Old Man" and Story.has_flag("toon_groet")
			and "Warden's House" in _lines_text())
	_check_bubble("Old Man", opa)
	await frames(30)
	await overworld_shot("_v11_oude_man")
	# één ballon (groet + menu) en één verteller-vak (mantel). Geen tweede tutorialregel.
	var menu_seen := false
	var narr_seen := false
	var tutorial_repeat := false
	for i in 1200:
		if not Story.running and not Dialog.is_open:
			break
		if Dialog.is_open and not Dialog._is_typing():
			var cur := str(Dialog._lines[Dialog._index])
			if cur == _named(ITEM_LINE):
				narr_seen = true
				check("Update 5: 'krijgt een Leerling-mantel!' in het blauwe vertellervak (geen staart)",
						Dialog.style_kind == "vak" and UiStyle.is_blue_box(Dialog.box_style(), "vak") and not Dialog.tail.visible)
				_check_box_clear("manteltekst")
				await frames(20)
				await v16_shot("verteller")
			if cur == _named(MENU_LINE) and not menu_seen:
				menu_seen = true
				_check_bubble("Oude Man (uitleg)", opa)
				await frames(20)
				await v16_shot("spraakballon")
			if cur.begins_with("(Tutorial:"):
				tutorial_repeat = true
			await press_interact()
		await frames(1)
	check("Update 5: Opa legt het menu uit in één ballon", menu_seen)
	check("Update 5: manteltekst één keer, geen herhaalde tutorialregel", narr_seen and not tutorial_repeat)
	check("v0.16: Apprentice Cloak gekregen (in de tas, nog niet aan), stap UITRUSTING",
			GameState.item_count(ARMOR) == 1 and not Story.wears(ARMOR) and GameState.story_step == SD.UITRUSTING)
	check("v0.16: Apprentice Cloak = harnas, klein beetje DEF, bestaand icoon (reisgewaad.png)",
			GameData.EQUIPMENT[ARMOR]["slot"] == "harnas" and int(GameData.EQUIPMENT[ARMOR]["def"]) in [1, 2, 3]
			and str(GameData.EQUIPMENT[ARMOR].get("icon", "")).ends_with("icons/reisgewaad.png")
			and ResourceLoader.exists(str(GameData.EQUIPMENT[ARMOR]["icon"])))
	await _equip_tutorial_tests(opa, def_before)
	check("opdracht gekregen: stap TAKEN", GameState.story_step == SD.TAKEN)
	# ingang Archieven: dicht
	await walk("move_down", 1)
	await walk("move_right", 5)
	await walk("move_up", 5)
	await walk("move_up", 1)
	await frames(5)
	check("ingang Archives (25,4) is dicht ('%s')" % _lines_text(), tile() == Vector2i(25, 4) and "vines" in _lines_text())
	await _story_drain()
	# kist (19,6) (v0.16: geen zegel 2 meer onderweg)
	await walk("move_down", 5)
	await walk("move_left", 6)
	await walk("move_up", 2)
	check("voor de kist (19,7): %s" % tile(), tile() == Vector2i(19, 7))
	await press_interact()
	# v0.16: schat-tekst in het blauwe vak, laag boven de knoppen
	var kg := 0
	while kg < 6:
		await _wait_typed()
		if not Dialog.is_open or str(Dialog._lines[Dialog._index]).contains("receives 3x"):
			break
		await press_interact()
		kg += 1
	var kline := str(Dialog._lines[Dialog._index]) if Dialog.is_open else ""
	check("v0.16: schat ('%s') in het blauwe vak, laag en niet bovenin (%s, plek %s)" % [kline, Dialog.box_rect(), Dialog.placement],
			kline.contains("receives 3x") and Dialog.style_kind == "vak" and UiStyle.is_blue_box(Dialog.box_style(), "vak")
			and not Dialog.tail.visible and Dialog.at_bottom and Dialog.box_rect().position.y > 216.0 * 0.4)
	_check_box_clear("schat")
	await frames(20)
	await v16_shot("schat_dorp")
	await _story_drain()
	check("kist: 3x Healing Herb, kist open", GameState.item_count("kruid") == 3 and Story.has_flag("kist_open") and _obj("Kist").sprite.frame == 1)
	await press_interact()
	await _wait_typed()
	check("tweede keer: 'De kist is leeg.'", Dialog._lines == ["The chest is empty."])
	await _story_drain()
	# put (9,5); v0.13: RPG ART's put is 2x2 (9..10, 5..6), dus je staat op (9,7)
	await walk("move_left", 10)
	await walk("move_up", 1)
	check("voor de put (9,7), kijkt omhoog: %s" % tile(), tile() == Vector2i(9, 7) and player().facing == Vector2i.UP)
	await press_interact()
	await _story_drain()
	check("put: bucket of water gekregen", GameState.item_count("emmer_water") == 1)
	# ---------------- opslaan halverwege (het boek in het huis) en laden
	await walk("move_right", 7)
	await walk("move_up", 1)
	check("naar binnen om op te slaan", await wait_scene("Huis"))
	await frames(10)
	await walk("move_up", 3)
	await walk("move_right", 4)
	await walk("move_up", 1)
	await press_interact()
	await _wait_typed()
	await press_interact()   # 'Een warme gloed herstelt je krachten en je geest.'
	await _wait_typed()
	await press_interact()   # Ja
	await _wait_typed()
	check("halverwege opgeslagen", Dialog._lines == ["Saved."] and GameState.has_save())
	await close_dialog()
	var d := GameState.read_save()
	var st: Dictionary = d.get("story", {})
	check("save: story_step %s en flags %s" % [st.get("step"), st.get("flags")],
			int(st.get("step", -1)) == SD.TAKEN and "kist_open" in st.get("flags", [])
			and int(d["inventory"].get("emmer_water", 0)) == 1)
	GameState.story_step = SD.START
	GameState.story_flags = {}
	GameState.inventory.erase("emmer_water")
	GameState.go_to_title()
	check("titel (halverwege)", await wait_scene("Title"))
	await frames(10)
	await _click_continue_slot()
	check("Doorgaan -> het huis", await wait_scene("Huis"))
	await frames(30)
	check("verhaal hersteld: stap TAKEN, kist, emmer, mantel aan, plek (8,4)",
			GameState.story_step == SD.TAKEN and Story.has_flag("kist_open") and Story.wears(ARMOR)
			and GameState.item_count("emmer_water") == 1 and tile() == Vector2i(8, 4))
	check("na laden geen wakker-cutscene", not Story.running and not Dialog.is_open)
	await walk("move_left", 4)
	await walk("move_down", 4)
	check("weer naar buiten", await wait_scene("Wilgendal"))
	await frames(10)
	check("na laden: kist nog open, geen zegelstenen", _obj("Kist").sprite.frame == 1 and _obj("Zegel1") == null)
	check("nog stap TAKEN (water nog niet gebracht)", GameState.story_step == SD.TAKEN)
	# water naar de Oude Man -> zwaardles -> oefengevecht
	await walk("move_down", 2)
	await walk("move_right", 5)
	await walk("move_up", 1)
	check("weer voor de Oude Man (21,9): %s" % tile(), tile() == Vector2i(21, 9))
	var atk_before := int(GameState.party[0]["atk"])
	await press_interact()
	var lesson_seen := false
	for i in 2400:
		if GameState.in_battle:
			break
		if Dialog.is_open and not Dialog._is_typing():
			if LESSON_LINE in _lines_text():
				lesson_seen = true
			await press_interact()
		await frames(1)
	check("zwaardles: '%s'" % LESSON_LINE, lesson_seen)
	check("emmer afgegeven, stap LES", GameState.item_count("emmer_water") == 0 and Story.has_flag("water_klaar") and GameState.story_step == SD.LES)
	check("Short Sword gekregen (ATK %d -> %d)" % [atk_before, GameState.party[0]["atk"]],
			GameState.party[0].get("weapon", "") == "kort_zwaard" and int(GameState.party[0]["atk"]) == atk_before + 3)
	await _tutorial_battle_test()
	# ---------------- scène 2: de avond
	check("na het oefengevecht terug buiten", await wait_scene("Wilgendal"))
	var after_ok := false
	for i in 1200:
		if map_name() == "Huis" and scene().is_node_ready():
			break
		if Dialog.is_open and not Dialog._is_typing():
			if "already setting" in _lines_text():
				after_ok = true
			await press_interact()
		await frames(1)
	check("Oude Man na het gevecht: 'Kom, de zon gaat al onder'", after_ok)
	check("na de les: avond, binnen in het huis", await wait_scene("Huis"))
	await frames(5)
	check("stap AVOND, avond-tint", GameState.story_step == SD.AVOND
			and scene().get_node("StoryTint").color.is_equal_approx(SD.TINTS["evening"]))
	check("lezen op de stoel (9,5), Oude Man binnen op (9,3)",
			tile() == Vector2i(9, 5) and _obj("OudeMan").visible and _obj("OudeMan").get_tile() == Vector2i(9, 3))
	check("v0.13: Oude Man binnen = Warden-sprite (wachter.png, 3x4 frames)", _wachter_ok(_obj("OudeMan")))
	for i in 60:
		if Transition._rect.color.a < 0.01:
			break
		await frames(1)
	await overworld_shot("_v13_wachter")
	for i in 300:
		if Story.running:
			break
		await frames(1)
	check("avond-cutscene start vanzelf", Story.current_event == "catastrofe")
	var shake_seen := false
	var glow_seen := false
	var panic_ok := false
	for i in 4000:
		if Story.shaking():
			shake_seen = true
		if scene().get_node_or_null("WindowGlow") != null:
			glow_seen = true
		if Dialog.is_open and not Dialog._is_typing():
			if "flash" in _lines_text() and not _drain_shot_done.has("_v11_flash"):
				_drain_shot_done["_v11_flash"] = true
				await overworld_shot("_v11_flash")
			if _named(PANIC_LINE) in Dialog._lines and Dialog.name_label.text == "Old Man":
				panic_ok = true
			await press_interact()
		if not Story.running and not Dialog.is_open:
			break
		await frames(1)
	check("aardbeving (scherm schudt)", shake_seen)
	check("flits + magisch licht door de ramen", glow_seen)
	check("Oude Man in paniek: tekst precies uit het verhaal", panic_ok)
	check("Grandpa weg, schilderij scheef, deur op slot, stap OPGESLOTEN",
			not _obj("OudeMan").visible and _obj("Schilderij").sprite.frame == 1
			and Story.has_flag("locked:HuisDeur") and GameState.story_step == SD.OPGESLOTEN)
	check("schreeuw-timer loopt", Story.scheduled.get("event", "") == "schreeuw")
	# deur zit op slot
	await walk("move_down", 2)
	await walk("move_left", 5)
	await walk("move_down", 1)
	await frames(5)
	check("deur: '%s'" % LOCKED_LINE, Dialog.is_open and Dialog._lines == [LOCKED_LINE])
	await _story_drain()
	check("teruggestapt, nog binnen (4,7): %s" % tile(), map_name() == "Huis" and tile() == Vector2i(4, 7))
	# wachten op de schok + schreeuw
	for i in 900:
		if Dialog.is_open:
			break
		await frames(1)
	check("na een paar seconden: schok + schreeuw", Story.current_event == "schreeuw")
	await _story_drain(true)
	check("keuze 'Blijven' / 'Grandpa achterna'", Dialog.has_choices() and Dialog.choices == ["Stay", "Follow Grandpa"])
	await frames(20)
	await overworld_shot("_v11_choice")
	await press_interact()   # Blijven
	await _story_drain(true)
	check("'Blijven' -> wachten, nieuwe schok, weer de keuze",
			Story.history.has("blijven") and Dialog.has_choices() and Dialog.choices == ["Stay", "Follow Grandpa"])
	await tap("move_down")
	await press_interact()   # Opa achterna
	await _story_drain()
	check("'Grandpa achterna': deur open, nacht (stap NACHT)",
			not Story.has_flag("locked:HuisDeur") and GameState.story_step == SD.NACHT)
	await frames(80)
	check("nacht-tint binnen", scene().get_node("StoryTint").color.is_equal_approx(SD.TINTS["night"]))
	await walk("move_down", 1)
	check("deur open -> naar buiten", await wait_scene("Wilgendal"))
	await frames(10)
	check("buiten is het nacht, Oude Man weg, ingang open en gloeit",
			scene().get_node("StoryTint").color.is_equal_approx(SD.TINTS["night"]) and not _obj("OudeMan").visible
			and _obj("Archief").looping and _obj("Archief").sprite.texture.resource_path.ends_with("archief_ingang_open_flikker.png")
			and _obj("Archief").glow.visible)
	await walk("move_down", 2)
	await walk("move_right", 9)
	await walk("move_up", 5)
	await walk("move_up", 1)
	check("tegen de open ingang (25,4): %s" % tile(), tile() == Vector2i(25, 4))
	# v0.13: geen 'Wordt vervolgd' meer: na de proloog-scènes ga je echt De Vergeten Archieven in
	await _story_drain()
	check("v0.13: open ingang -> eerste dungeonkamer (ArchiefIngang)", await wait_scene("ArchiefIngang")
			and Story.has_flag("archief_gezien") and GameState.current_map == SD.ARCHIEF)
	await frames(10)
	check("v0.13: in de Archives bij de ingang (9,10), kijkt omhoog: %s" % tile(), tile() == Vector2i(9, 10)
			and player().facing == Vector2i.UP)
	check("event-geschiedenis compleet (%s)" % [Story.history],
			["opa", "intro_keuze", "intro_toon_groet", "opa_mantel", "mantel_aan", "kist", "put", "les", "na_les", "catastrofe", "schreeuw", "keuze", "blijven", "achterna", "archief_binnen"].all(func(e): return Story.history.has(e))
			and not Story.history.has("wakker_worden"))
	# terug naar buiten (uitgang -> wereldkaart, net boven de trap) en via het pad weer naar het huis
	GameState.change_map(SD.OUTSIDE, "voor_huis")
	await wait_scene("Wilgendal")
	await frames(10)
	await walk("move_down", 2)
	await walk("move_right", 9)
	await walk("move_up", 5)
	await walk("move_up", 1)
	await _story_drain()
	check("v0.13: ... ook de tweede keer de dungeon in (zonder de eerste-keer-tekst)", await wait_scene("ArchiefIngang")
			and Story.history.count("archief_binnen") == 1)
	GameState.change_map(SD.OUTSIDE, "voor_huis")
	await wait_scene("Wilgendal")
	await frames(10)


## v0.16 Spraakballon van een personage: blauwe ballon (RPG ART), staartje naar de spreker
## (omhoog als de ballon eronder staat, omlaag als erboven), niet bovenin, niets bedekt.
func _check_bubble(who: String, node: Node2D) -> void:
	var r: Rect2 = Dialog.box_rect()
	var sp: Vector2 = node.get_global_transform_with_canvas().origin
	var tip = Dialog.tail_tip()
	var dir_ok := false
	if tip != null:
		if Dialog.tail_dir == "up":
			dir_ok = r.position.y > sp.y and tip.y < r.position.y and tip.y >= sp.y - 4.0
		elif Dialog.tail_dir == "down":
			dir_ok = r.end.y < sp.y and tip.y > r.end.y and tip.y <= sp.y
	check("v0.16: %s praat in een blauwe spraakballon met staartje %s naar hem toe (ballon %s, spreker %s, punt %s)"
			% [who, Dialog.tail_dir, r, sp, tip],
			Dialog.style_kind == "ballon" and UiStyle.is_blue_box(Dialog.box_style(), "ballon") and Dialog.tail.visible
			and Dialog.speaker_node == node and tip != null and absf(tip.x - sp.x) <= 12.0 and dir_ok)
	check("v0.16: ballon niet bovenin maar laag, boven de knoppen (plek '%s', y %.0f)" % [Dialog.placement, r.position.y],
			Dialog.at_bottom and r.position.y > 216.0 * 0.4 and Dialog.placement != "boven")
	_check_box_clear(who)


## v0.16 Het tekstvak (+ naamtabje) valt niet over de speler, het ding waar hij naar kijkt of
## de spreker, en niet over de D-pad/A/B.
func _check_box_clear(label: String) -> void:
	var bad := []
	var boxes: Array[Rect2] = Dialog._rects_for(Dialog.box_rect())
	for f in Dialog._focus_rects():
		for b in boxes:
			if b.intersects(f):
				bad.append("over speler/doel %s" % f)
	var touch: Control = scene().get_node_or_null("TouchControls/Control")
	if touch and touch.visible:
		for c in [[touch.dpad_center(), touch.dpad_radius * 1.2], [touch.a_center(), touch.button_radius * 1.25],
				[touch.b_center(), touch.button_radius * 1.25]]:
			if _rect_hits_circle(Dialog.box_rect(), c[0], c[1]):
				bad.append("onder een knop")
	check("v0.16: %s: tekstvak vrij van speler, doel, spreker en knoppen %s" % [label, bad], bad.is_empty())


## v0.16 Uitrusting-tutorial: niet verder zolang de mantel niet aan is; MENU > Uitrusting;
## na het sluiten van het menu gaat Opa vanzelf verder.
func _equip_tutorial_tests(_opa: Node, def_before: int) -> void:
	# 1) nog niet aan: Opa herinnert je, put/kist zijn dicht, menu zonder uitrusten = niets
	await press_interact()
	await _wait_typed()
	check("v0.16: mantel nog niet aan -> Grandpa: '%s'" % (Dialog._lines[0] if Dialog.is_open else ""),
			Dialog.is_open and Dialog._lines == [_named(REMIND_LINE)])
	await _story_drain()
	check("v0.16: kan niet verder zonder mantel: nog stap UITRUSTING", GameState.story_step == SD.UITRUSTING
			and not Story.history.has("mantel_aan"))
	Story.trigger("put")
	await _wait_typed()
	check("v0.16: put geblokkeerd ('%s')" % _lines_text(), Dialog.is_open and "cloak first" in _lines_text())
	await _story_drain()
	Story.trigger("kist", _obj("Kist"))
	await _wait_typed()
	check("v0.16: kist geblokkeerd ('%s')" % _lines_text(), Dialog.is_open and "Grandpa's cloak first" in _lines_text())
	await _story_drain()
	check("v0.16: geen emmer, kist dicht", GameState.item_count("emmer_water") == 0 and not Story.has_flag("kist_open"))
	scene().open_field_menu()
	await pframes(4)
	var m: Node = scene().get_node_or_null("FieldMenu")
	check("veldmenu open", m != null)
	if m == null:
		return
	m.close()
	await frames(20)
	check("v0.16: menu dicht zonder uitrusten: nog steeds geblokkeerd", GameState.story_step == SD.UITRUSTING
			and not Story.running and not Dialog.is_open)
	# 2) MENU > Uitrusting > Uitrusten > Harnas > Leerling-mantel
	scene().open_field_menu()
	await pframes(4)
	m = scene().get_node_or_null("FieldMenu")
	m.choose("equip")
	await pframes(4)
	var es: Node = m.sub
	check("v0.16: MENU > Equipment open", es != null and es.name == "Equipment")
	if es == null:
		return
	es.do_command("equip")
	await pframes(2)
	es.choose_slot("harnas")
	await pframes(4)
	check("v0.16: vak Harnas: lijst met de Apprentice Cloak (%s)" % [es.list_ids], es.mode == "item" and es.list_ids.has(ARMOR))
	es.preview_item(ARMOR)
	await pframes(6)
	await v16_shot("tutorial_uitrusting")
	es.choose_item(ARMOR)
	await pframes(2)
	check("v0.16: mantel AAN: DEF %d -> %d, niet meer in de tas" % [def_before, GameState.party[0]["def"]],
			Story.wears(ARMOR) and GameState.item_count(ARMOR) == 0 and int(GameState.party[0]["def"]) == def_before + int(GameData.EQUIPMENT[ARMOR]["def"]))
	check("v0.16: zolang het menu open is wacht het verhaal", GameState.story_step == SD.UITRUSTING and not Story.running)
	es.back()
	es.back()
	await pframes(4)
	check("Equipment dicht, terug in het veldmenu", m.sub == null)
	m.close()
	# 3) menu dicht -> Opa gaat verder (gedwongen check geslaagd)
	var opa_line := false
	for i in 1800:
		if Dialog.is_open and not Dialog._is_typing():
			if _named(OPA_LINE) in Dialog._lines and Dialog.name_label.text == "Old Man":
				opa_line = true
			await press_interact()
		elif not Story.running and not Dialog.is_open and Story.history.has("mantel_aan"):
			break
		await frames(1)
	check("v0.16: na uitrusten + menu dicht gaat de tutorial verder: Grandpa '%s'" % _named(OPA_LINE),
			opa_line and Story.history.has("mantel_aan"))


## v0.11 boekpunten HP (rood) en MP (groen) op de test-plek naast de ingang van de Archieven.
## Even een tweede held (Noor, heeft MP) in de party, zodat MP echt iets te doen heeft.
func _book_tests() -> void:
	var p := player()
	var start := tile()
	var start_facing: Vector2i = p.facing
	var red: Node = _obj("BoekHP")
	var green: Node = _obj("BoekMP")
	check("rood + groen boek naast de Archives (24,4) en (27,4)", red != null and green != null
			and red.position == Vector2(24 * 16 + 8, 4 * 16 + 8) and green.position == Vector2(27 * 16 + 8, 4 * 16 + 8))
	if red == null or green == null:
		return
	check("rood boek: type hp, eigen art (4 frames), rode aura (additief)", red.type == "hp" and red.sprite.hframes == 4
			and red.sprite.texture.resource_path.ends_with("hp_book.png") and red.aura_color.is_equal_approx(Color("ff3f4f"))
			and red.aura.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and red.aura.texture.get_width() == 88)
	check("groen boek: type mp, eigen art (4 frames), groene aura (additief)", green.type == "mp" and green.sprite.hframes == 4
			and green.sprite.texture.resource_path.ends_with("mp_book.png") and green.aura_color.is_equal_approx(Color("3fff7a"))
			and green.aura.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
	var a_lo := 9.0
	var a_hi := -9.0
	for i in 60:
		await frames(2)
		a_lo = minf(a_lo, green.aura.modulate.a)
		a_hi = maxf(a_hi, green.aura.modulate.a)
	check("groene aura pulseert net als de cyaan (alpha %.2f..%.2f)" % [a_lo, a_hi], a_hi - a_lo > 0.2 and a_hi <= 0.61)
	var keep_party: Array = GameState.party.duplicate(true)
	GameState.party.append(GameState.hero_template("noor"))
	for h in GameState.party:
		h["hp"] = 1
		h["mp"] = 0
	var save_before := FileAccess.get_file_as_string(GameState.save_path) if GameState.has_save() else ""
	# rood: alleen HP
	p.place_at(Vector2i(24, 5), Vector2i.UP)
	await frames(10)
	await overworld_shot("_v11_books")
	await press_interact()
	check("rood boek: 'Je wonden sluiten zich. HP hersteld.'", Dialog.is_open and Dialog._lines == ["Your wounds close. HP restored."])
	check("rood boek: HP van de hele party vol, MP niet",
			GameState.party.all(func(h): return h["hp"] == h["max_hp"] and h["mp"] == 0))
	await _wait_typed()
	await press_interact()
	await frames(5)
	check("rood boek: geen opslaan-vraag, niets opgeslagen", not Dialog.is_open and red.last_result == "restored"
			and (FileAccess.get_file_as_string(GameState.save_path) if GameState.has_save() else "") == save_before)
	# groen: alleen MP
	for h in GameState.party:
		h["hp"] = 1
	p.place_at(Vector2i(27, 5), Vector2i.UP)
	await frames(5)
	await press_interact()
	check("groen boek: 'Je geest raakt helder. MP hersteld.'", Dialog.is_open and Dialog._lines == ["Your mind clears. MP restored."])
	check("groen boek: MP van de hele party vol, HP niet (Noor %d/%d MP)" % [GameState.party[1]["mp"], GameState.party[1]["max_mp"]],
			GameState.party.all(func(h): return h["mp"] == h["max_mp"] and h["hp"] == 1) and GameState.party[1]["mp"] > 0)
	await _wait_typed()
	await press_interact()
	await frames(5)
	check("groen boek: geen opslaan-vraag, niets opgeslagen", not Dialog.is_open and green.last_result == "restored"
			and (FileAccess.get_file_as_string(GameState.save_path) if GameState.has_save() else "") == save_before)
	GameState.party = keep_party
	p.place_at(start, start_facing)
	await frames(5)


## Oefengevecht tegen de Mosslijm: tips (Aanval, Item), niet vluchten, nooit KO.
func _tutorial_battle_test() -> void:
	check("oefengevecht start", await wait_scene("Battle"))
	var b := battle()
	if b == null or not await wait_hero(0):
		return
	check("oefengevecht: 1 Moss Slime (HP 30), gras-achtergrond", b.enemies.size() == 1 and b.enemies[0]["id"] == "mosslijm"
			and int(b.enemies[0]["s"]["max_hp"]) == 30 and GameState.pending_backdrop_id == "grass")
	check("tip 'Aanval' in beeld", b.tip_panel != null and b.tip_panel.visible and "Attack" in b.tip_label.text)
	check("vluchten kan niet in het oefengevecht (knop grijs)", not b.cross.is_enabled(4) and cross_frame(b, 4) == 2)
	var tip_r: Rect2 = lrect(b, b.tip_panel)
	var ok_tip := true
	for c in b.enemies:
		ok_tip = ok_tip and not tip_r.intersects(lrect(b, c["node"]))
	ok_tip = ok_tip and not tip_r.intersects(b.cross.cross_rect()) and not tip_r.intersects(lrect(b, b.cross.name_tab))
	ok_tip = ok_tip and not (b.caption.visible and tip_r.intersects(lrect(b, b.caption)))
	for box in b.status_boxes:
		ok_tip = ok_tip and not tip_r.intersects(lrect(b, box))
	for hk in _hero_rects(b).values():
		ok_tip = ok_tip and not tip_r.intersects(hk)
	var tc: Control = b.touch
	for c in [[tc.dpad_center(), tc.dpad_radius * 1.2], [tc.a_center(), tc.button_radius * 1.25], [tc.b_center(), tc.button_radius * 1.25]]:
		ok_tip = ok_tip and not _rect_hits_circle(tip_r, c[0], c[1])
	check("tip-venster valt nergens over (vijand, kruis, held, vak, strook, D-pad, A/B) %s" % tip_r, ok_tip)
	check("v0.16: tutorial-tip in het blauwe vertellervak (tekstvak_blauw.png)",
			UiStyle.is_blue_box(b.tip_panel.get_theme_stylebox("panel"), "vak"))
	check("held in het gevecht = rugaanzicht (dennis_rug.png)", GameState.party[0]["battle_sprite"].ends_with("dennis_rug.png"))
	await frames(20)
	await battle_shot("_v11_tutorial")
	var item_tip := false
	var used_item := false
	for guard in 60:
		var stt := await wait_battle_state(["command", "message_wait"], 30)
		if stt == "" or battle() == null:
			break
		if stt == "command":
			if b.tip_panel.visible and "Item" in b.tip_label.text:
				item_tip = true
			if item_tip and not used_item:
				used_item = true
				var before := GameState.item_count("kruid")
				await choose_command(2)
				await wait_battle_state(["command"])
				await pframes(2)
				for k in 4:
					if b.menu.selected == 2:
						break
					await tap("move_down")
				await tap("interact")
				await wait_battle_state(["target_ally"])
				await tap("interact")
				for i in 200:
					if GameState.item_count("kruid") < before:
						break
					await frames(1)
				check("Item > Herb gebruikt (%d -> %d)" % [before, GameState.item_count("kruid")], GameState.item_count("kruid") == before - 1)
			else:
				await choose_command(0)
				await wait_battle_state(["target_enemy"])
				await tap("interact")
		else:
			await tap("interact")
	check("tip 'Item' verscheen na schade", item_tip)
	check("held nooit KO in het oefengevecht", int(GameState.party[0]["hp"]) >= 1)
	check("Moss Slime verslagen (bestiarium)", GameState.defeated_count("mosslijm") >= 1)
