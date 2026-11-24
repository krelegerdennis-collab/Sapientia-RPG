extends RefCounted
## Schermindeling van het gevecht (uit battle.gd gehaald, gedrag ongewijzigd).
## battle.gd roept dit aan via dunne wrappers met de oude namen (sim en tests overschrijven die).

const GameData := preload("res://scripts/data/game_data.gd")
const CommandCrossScript := preload("res://scripts/battle/command_cross.gd")
const StatusBoxScript := preload("res://scripts/battle/hero_status_box.gd")
const BossHpBarScript := preload("res://scripts/battle/boss_hp_bar.gd")

const HIT_SHOW := 0.3
const MIN_BOX_W := 56.0

static var _top_cache := {}

var battle  # scenes/battle/battle.gd root (geen class_name; niet als Control typen)


func _init(b) -> void:
	battle = b


# ---------------------------------------------------------------- bazenbalk
func make_boss_bar() -> void:
	if not GameState.pending_boss or battle.enemies.is_empty():
		return
	var t: Dictionary = battle.enemies[0]
	for e in battle.enemies:
		if e.has("core"):
			t = e
			break
	battle.boss_bar = BossHpBarScript.new()
	battle.boss_bar.name = "BossHpBar"
	battle.add_child(battle.boss_bar)
	battle.move_child(battle.boss_bar, battle.get_node("TouchControls").get_index())
	battle.boss_bar.setup(t)


func place_boss_bar(w: float) -> void:
	if battle.boss_bar:
		var max_w := w - 8.0 - 6.0 - safe().z
		if battle.boss_bar.has_method("relayout"):
			battle.boss_bar.relayout(max_w)
		battle.boss_bar.position = Vector2(roundf(w - battle.boss_bar.size.x - 6.0 - safe().z), 18.0 + safe().y)


# ---------------------------------------------------------------- fijn raster (768x432)
func enter_detail_mode() -> void:
	var win: Window = battle.get_window()
	battle._previous_scale_size = win.content_scale_size
	if battle._previous_scale_size == Vector2i.ZERO:
		battle._previous_scale_size = Vector2i(384, 216)
	win.content_scale_size = battle._previous_scale_size * battle.DETAIL
	battle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	battle.scale = Vector2(battle.DETAIL, battle.DETAIL)
	battle.get_node("TouchControls").scale = Vector2(battle.DETAIL, battle.DETAIL)
	battle._fit_to_screen()
	battle.get_viewport().size_changed.connect(battle._fit_to_screen)


func leave_detail_mode() -> void:
	if battle.get_viewport().size_changed.is_connected(battle._fit_to_screen):
		battle.get_viewport().size_changed.disconnect(battle._fit_to_screen)
	if battle.touch and battle.get_viewport().size_changed.is_connected(battle.touch.refit):
		battle.get_viewport().size_changed.disconnect(battle.touch.refit)
	if battle._previous_scale_size != Vector2i.ZERO:
		battle.get_window().content_scale_size = battle._previous_scale_size


func apply_hd_ui() -> void:
	if battle.theme:
		var t: Theme = battle.theme.duplicate()
		for type_name in ["Panel", "PanelContainer"]:
			if t.has_stylebox("panel", type_name):
				t.set_stylebox("panel", type_name,
						HdUi.hd_style(t.get_stylebox("panel", type_name), "res://assets/ui/window_hd.png"))
		battle.theme = t
	battle.victory_panel.add_theme_stylebox_override("panel", UiStyle.blue_box("vak", Vector4(9, 7, 9, 6)))
	battle.victory_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	battle.victory_label.add_theme_color_override("font_color", UiStyle.BOX_TEXT)
	battle.victory_label.add_theme_color_override("font_shadow_color", UiStyle.BOX_SHADOW)
	battle.caption.add_theme_stylebox_override("panel", UiStyle.panel("soft"))


func make_cross() -> void:
	battle.cross = CommandCrossScript.new()
	battle.cross.name = "CommandCross"
	battle.add_child(battle.cross)
	battle.move_child(battle.cross, battle.get_node("TouchControls").get_index())
	battle.cross.denied.connect(func(i: int): if i == 1: battle.show_notice("No spells yet"))
	battle.target_name = PanelContainer.new()
	battle.target_name.name = "TargetName"
	battle.target_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.target_name.add_theme_stylebox_override("panel", UiStyle.panel("tab", UiStyle.TEAL_DIM))
	battle.target_name_label = Label.new()
	battle.target_name_label.add_theme_color_override("font_color", UiStyle.TEXT)
	battle.target_name.add_child(battle.target_name_label)
	battle.add_child(battle.target_name)
	battle.move_child(battle.target_name, battle.get_node("TouchControls").get_index())
	battle.target_name.hide()


func list_row_h(n: int) -> int:
	if battle._hero_top_y <= 0.0 or n <= 0:
		return battle.LIST_ROW_H
	var free: float = battle._hero_top_y - (battle.SUBMENU_TOP + safe().y) - battle.LIST_CHROME
	return clampi(int(floorf(free / float(n))), battle.LIST_ROW_MIN, battle.LIST_ROW_H)


func safe() -> Vector4:
	if battle.touch != null and "safe_inset" in battle.touch:
		return battle.touch.safe_inset
	return Vector4.ZERO


func fit_to_screen() -> void:
	if not battle.is_inside_tree():
		return
	battle.position = Vector2.ZERO
	battle.size = battle.get_viewport_rect().size / battle.DETAIL
	if battle.touch and battle.touch.has_method("refit"):
		battle.touch.refit()


# ---------------------------------------------------------------- vijand-sprites (idle/under/hit)
func add_enemy_idle(node: TextureButton, data: Dictionary) -> void:
	node.set_meta("still", node.texture_normal)
	var hit_path := str(data.get("hit", ""))
	if hit_path != "" and ResourceLoader.exists(hit_path):
		node.set_meta("hit_tex", GameState.get_resource(hit_path))
	add_enemy_under(node, data)
	var path := str(data.get("idle", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var strip: Texture2D = GameState.get_resource(path)
	var n := maxi(1, int(data.get("idle_frames", 2)))
	var fw := strip.get_width() / n
	var frames: Array[Texture2D] = []
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0, fw, strip.get_height())
		frames.append(at)
	node.texture_normal = frames[0]
	node.set_meta("idle_frames", frames)
	var timer := Timer.new()
	timer.name = "Idle"
	timer.wait_time = float(data.get("idle_time", 0.5))
	timer.autostart = true
	var k := [0]
	timer.timeout.connect(func():
		k[0] = (k[0] + 1) % frames.size()
		if not node.has_meta("hit_until"):
			node.texture_normal = frames[k[0]])
	node.add_child(timer)


func add_enemy_under(node: TextureButton, data: Dictionary) -> void:
	var path := str(data.get("under", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var strip: Texture2D = GameState.get_resource(path)
	var n := maxi(1, int(data.get("under_frames", 1)))
	var fw := strip.get_width() / n
	var frames: Array[Texture2D] = []
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = strip
		at.region = Rect2(i * fw, 0, fw, strip.get_height())
		frames.append(at)
	var still: Texture2D = node.texture_normal
	var k := node.size.x / float(still.get_width())
	var up: Array = data.get("under_pos", [0, 0])
	var under := TextureRect.new()
	under.name = "Under"
	under.texture = frames[0]
	under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	under.stretch_mode = TextureRect.STRETCH_SCALE
	under.position = Vector2(float(up[0]), float(up[1])) * k
	under.size = Vector2(fw, strip.get_height()) * k
	under.show_behind_parent = true
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.set_meta("frames", frames)
	node.add_child(under)
	if n > 1:
		var timer := Timer.new()
		timer.name = "UnderTimer"
		timer.wait_time = float(data.get("under_time", 0.8))
		timer.autostart = true
		var j := [0]
		timer.timeout.connect(func():
			j[0] = (j[0] + 1) % frames.size()
			under.texture = frames[j[0]])
		node.add_child(timer)


func show_hit_frame(node: Control) -> void:
	if not (node is TextureButton) or not node.has_meta("hit_tex"):
		return
	var btn := node as TextureButton
	var token := Time.get_ticks_usec()
	btn.set_meta("hit_until", token)
	btn.texture_normal = btn.get_meta("hit_tex")
	await battle.get_tree().create_timer(HIT_SHOW).timeout
	if not is_instance_valid(btn) or btn.get_meta("hit_until", 0) != token:
		return
	btn.remove_meta("hit_until")
	var idle_t: Timer = btn.get_node_or_null("Idle")
	if btn.has_meta("idle_frames") and idle_t:
		btn.texture_normal = btn.get_meta("idle_frames")[0]
	else:
		btn.texture_normal = btn.get_meta("still")


static func sprite_top(path: String, tex: Texture2D) -> float:
	if not _top_cache.has(path):
		var img := tex.get_image()
		_top_cache[path] = float(img.get_used_rect().position.y) if img and not img.is_empty() else 0.0
	return _top_cache[path]


static func art_fit(size: Vector2, is_boss: bool, max_enemy_h: int, boss_w: int, boss_h: int) -> float:
	var f := 1.0
	if is_boss:
		if size.y > boss_h:
			f = minf(f, float(boss_h) / size.y)
		if size.x > boss_w:
			f = minf(f, float(boss_w) / size.x)
	elif size.y > max_enemy_h:
		f = float(max_enemy_h) / size.y
	return f


# ---------------------------------------------------------------- indeling
func layout() -> void:
	var w: float = battle.size.x if battle.size.x > 0 else 384.0
	var h: float = battle.size.y if battle.size.y > 0 else 216.0
	var dx: float = roundf((w - 384.0) / 2.0)
	var left: float = 78.0
	var right: float = 300.0
	var menu_right: float = w - 49.0
	if battle.touch and battle.touch.has_method("dpad_center"):
		left = battle.touch.dpad_center().x + battle.touch.joy_radius() * 1.2 + 4.0
		right = battle.touch.b_center().x - battle.touch.button_radius * 1.25 - 4.0
		menu_right = floorf(battle.touch.a_center().x - battle.touch.button_radius * 1.25 - 1.0)
	battle.menu.right_edge = w - battle.CROSS_MARGIN - safe().z
	battle.menu.top_edge = battle.SUBMENU_TOP + safe().y
	battle.menu.bottom_edge = -1.0
	battle._menu_left = left
	battle._menu_right = right
	battle._fit_caption()
	place_boss_bar(w)
	var row_boxes: Array = battle.status_boxes.filter(func(bx): return not bool(bx.get("monster")))
	var count := row_boxes.size()
	if count > 0:
		var box_left := box_left_for_cross(left, right, count)
		var bw := floorf((right - box_left - battle.BOX_GAP * (count - 1)) / count)
		bw = minf(bw, 88.0)
		var total: float = bw * count + battle.BOX_GAP * (count - 1)
		var x0 := roundf(box_left + (right - box_left - total) / 2.0)
		for i in count:
			var box: Control = row_boxes[i]
			box.position = Vector2(x0 + i * (bw + battle.BOX_GAP), h - StatusBoxScript.HEIGHT - 3)
			box.size = Vector2(bw, StatusBoxScript.HEIGHT)
			box.queue_redraw()
	var b_mid := Vector2(w - 54.0, h - 34.0)
	var b_r := 15.0
	if battle.touch and battle.touch.has_method("b_center"):
		b_mid = battle.touch.b_center()
		b_r = battle.touch.button_radius * 1.25
	for bx in battle.status_boxes:
		if bool(bx.get("monster")):
			var sz: Vector2 = StatusBoxScript.SIDE_SIZE
			var px := clampf(roundf(b_mid.x - sz.x / 2.0), 2.0, w - sz.x - 2.0)
			bx.position = Vector2(px, roundf(b_mid.y - b_r - battle.SIDE_GAP - sz.y))
			bx.size = sz
			bx.queue_redraw()
	for i in battle.hero_nodes.size():
		var slot: Vector2
		if i < battle.status_boxes.size():
			var box: Control = battle.status_boxes[i]
			var gap: float = 0.0 if bool(box.get("monster")) else battle.HERO_BOX_GAP
			slot = Vector2(roundf(box.position.x + box.size.x / 2.0), box.position.y - gap)
		elif i < battle.HERO_SLOTS.size():
			slot = battle.HERO_SLOTS[i] + Vector2(dx, 0)
		else:
			slot = battle.HERO_SLOTS[battle.HERO_SLOTS.size() - 1] + Vector2(dx + 26 * (i - battle.HERO_SLOTS.size() + 1), 0)
		battle.hero_nodes[i].set_home(slot)
	sort_by_feet(battle.party_layer)
	place_cross(w, h)
	layout_enemies(w, dx)
	place_menu(maxi(battle._menu_hero, 0), false)


func place_cross(w: float, h: float) -> void:
	if battle.cross == null:
		return
	var span: float = CommandCrossScript.BUTTON * 3.0 + CommandCrossScript.GAP * 2.0
	var half := span / 2.0
	var hero_l := w
	var hero_top := h
	var hero_bottom := 0.0
	battle._hero_top_y = 0.0
	for node in battle.hero_nodes:
		var rects: Array = [Rect2(node.home - node.FEET, node.SIZE),
				Rect2(node.home + node.STEP - node.FEET, node.SIZE)]
		if node.has_method("art_rect"):
			rects.append(node.art_rect(node.home))
		for r in rects:
			hero_l = minf(hero_l, r.position.x)
			hero_top = minf(hero_top, r.position.y)
			hero_bottom = maxf(hero_bottom, r.end.y)
	if battle.hero_nodes.is_empty():
		hero_l = w * 0.45
		hero_top = h * 0.45
		hero_bottom = h - StatusBoxScript.HEIGHT - 6.0
	else:
		battle._hero_top_y = hero_top
	var right := floorf(hero_l - battle.CROSS_HERO_GAP)
	var x0 := maxf(battle.CROSS_EDGE + safe().x, right - span)
	var beside := x0 + span <= right + 0.5
	var r_x := Rect2(x0, 0, span, h)
	var bottom_limit: float = h - battle.CROSS_EDGE
	for box in battle.status_boxes:
		var br := Rect2(box.position, box.size)
		if br.position.x < r_x.end.x and br.end.x > r_x.position.x:
			bottom_limit = minf(bottom_limit, br.position.y - 2.0)
	if battle.touch and battle.touch.has_method("dpad_center"):
		var dc: Vector2 = battle.touch.dpad_center()
		var dr: float = battle.touch.joy_radius() * 1.2
		if x0 < dc.x + dr:
			bottom_limit = minf(bottom_limit, dc.y - dr - 2.0)
	var cy: float
	if beside:
		cy = (hero_top + hero_bottom) / 2.0 - 4.0
	else:
		cy = hero_top - 2.0 - half
	cy = minf(cy, bottom_limit - half)
	cy = maxf(cy, battle.CAPTION_TOP + 1.0 + battle.CROSS_TAB_ROOM + half)
	battle.cross.place(Vector2(roundf(x0 + half), floorf(cy)))
	var cr: Rect2 = battle.cross.cross_rect()
	battle._enemy_left_reserve = cr.end.x + 3.0 if cr.position.y - battle.CROSS_TAB_ROOM < battle.ENEMY_FEET_Y + 6.0 else 0.0


func box_left_for_cross(left: float, right: float, count: int) -> float:
	if battle.hero_nodes.is_empty() or not battle.hero_nodes[0].has_method("art_rect"):
		return left
	var span: float = CommandCrossScript.BUTTON * 3.0 + CommandCrossScript.GAP * 2.0
	var art_off: float = -battle.hero_nodes[0].art_rect(Vector2.ZERO).position.x
	var tap_off: float = battle.hero_nodes[0].FEET.x
	var need: float = battle.CROSS_EDGE + span + battle.CROSS_HERO_GAP + maxf(art_off, tap_off)
	var l := left
	while l < right:
		var bw := minf(floorf((right - l - battle.BOX_GAP * (count - 1)) / count), 88.0)
		if bw < MIN_BOX_W:
			return left
		var total: float = bw * count + battle.BOX_GAP * (count - 1)
		var x0 := roundf(l + (right - l - total) / 2.0)
		if x0 + roundf(bw / 2.0) >= need:
			return l
		l += 1.0
	return left


func enemy_region(w: float) -> Array:
	return [maxf(battle.ENEMY_LEFT, battle._enemy_left_reserve), w - battle.ENEMY_LEFT]


func place_menu(i: int, _animate: bool) -> void:
	battle._menu_hero = i
	battle.menu.bottom_edge = -1.0
	battle.menu.place()


func layout_enemies(w: float, dx: float) -> void:
	var n: int = battle.enemies.size()
	if n == 0:
		return
	var reg := enemy_region(w)
	var region_l: float = reg[0]
	var region_r: float = reg[1]
	var gap: float = 4.0
	var total: float = 0.0
	for e in battle.enemies:
		total += e["node"].size.x
	total += gap * (n - 1)
	var avail := region_r - region_l
	var x := maxf(region_l, battle.ENEMY_LEFT + maxf(0.0, (region_r - battle.ENEMY_LEFT - total) / 2.0))
	if total > avail and n > 1:
		gap -= (total - avail) / (n - 1)
		x = region_l
	elif total < avail:
		var sx := stage_x(w, battle.size.y if battle.size.y > 0 else 216.0)
		if not is_nan(sx):
			var cap := maxf(region_l + total, region_r - battle.STAGE_RIGHT_RESERVE)
			x = clampf(roundf(sx - total / 2.0), region_l, cap - total)
	for i in n:
		var node: Control = battle.enemies[i]["node"]
		var feet := Vector2(x + node.size.x / 2.0, battle.ENEMY_FEET_Y + (2.0 if i % 2 == 1 else 0.0))
		feet.y += float(battle.enemies[i]["s"].get("y_offset", 0))
		feet.y = maxf(feet.y, minf(enemy_feet(node).y, battle.ENEMY_FEET_Y_MAX))
		node.position = (feet - enemy_feet(node)).round()
		x += node.size.x + gap
	sort_by_feet(battle.enemy_layer)


func stage_x(w: float, h: float) -> float:
	var stage = GameData.BACKDROP_STAGE.get(GameState.pending_backdrop_id)
	var tex: Texture2D = battle.get_node("Backdrop").texture
	if stage == null or tex == null:
		return NAN
	var ts := tex.get_size()
	var sc := maxf(w / ts.x, h / ts.y)
	return (w - ts.x * sc) / 2.0 + float(stage.x) * sc


func enemy_feet(node: Control) -> Vector2:
	return Vector2(roundf(node.size.x / 2.0), node.size.y - 3.0 * battle.ENEMY_DEPTH_SCALE)


func sort_by_feet(layer: Control) -> void:
	var kids := layer.get_children()
	kids.sort_custom(func(a, b): return a.position.y + a.size.y < b.position.y + b.size.y)
	for k in kids.size():
		layer.move_child(kids[k], k)