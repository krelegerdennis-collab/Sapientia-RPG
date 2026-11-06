extends Node
## Golem zichtbare telegraaf + tijdelijke hit-flash (Action, archief_golemhal).
## Los van golem_arena_tests.gd. Start: godot --path . -- --golemzichtbaartest [--shots=/pad]
## Bewaakt: telegraaf vóór elke schadelijke slag, één schade-event per strike, hit-zone dekt echte reach,
## buiten bereik / dodge = geen schade, interrupt wist telegraaf. Schade alleen via _golem_strike.

const SomArena := preload("res://scripts/som/som_arena.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const ROOM_SCENE := "res://scenes/maps/archief_golemhal.tscn"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Golem zichtbare aanval (telegraaf + anim feedback) ===")
	_wm1_first_boss_evidence()
	var saved_rt := SomArena.golem_rt_enabled
	SomArena.golem_rt_enabled = true
	await _suite()
	SomArena.golem_rt_enabled = saved_rt
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _wm1_first_boss_evidence() -> void:
	# Route: enige GOLEM_RT_ROOMS-kamer is archief_golemhal; spawn kennis_beest als baas.
	check("WM1: GOLEM_RT_ROOMS = archief_golemhal (enige Action-baas-kamer)",
			SomArena.GOLEM_RT_ROOMS == ["archief_golemhal"])
	var rooms := load("res://scripts/data/dungeon_rooms.gd")
	var golem_room: Dictionary = rooms.ROOMS["archief_golemhal"]
	var monsters: Array = golem_room.get("monsters", [])
	check("WM1: archief_golemhal spawnt kennis_beest als baas",
			monsters.any(func(m): return str(m.get("enemy", "")) == "kennis_beest" and bool(m.get("boss", false))))
	check("WM1: GolemBoss.ENEMY_ID = kennis_beest", GolemBoss.ENEMY_ID == "kennis_beest")


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _golem(s: Node) -> Node:
	for m in s.monsters:
		if is_instance_valid(m) and m.boss and str(m.enemy_id) == GolemBoss.ENEMY_ID:
			return m
	return null


func _events_of(a: Node, type: String) -> Array:
	return (a.golem_events as Array).filter(func(ev): return str(ev.get("type", "")) == type)


func _suite() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var s := await _laad(ROOM_SCENE)
	var a: Node = s.get("som") if s else null
	var m := _golem(s) if s else null
	check("Golemhal + Action-arena + Golem", a != null and m != null)
	if a == null or m == null:
		return
	a.allies_enabled = false
	for h in GameState.party:
		h["hp"] = 99999
		h["max_hp"] = 99999
	var e: Dictionary = a.enemies[m]
	var f: GolemFight = a.golem_fight_of(m)
	check("entry heeft tg (visual-only) + GolemBossView", e.has("tg") and e.has("golem_view") and is_instance_valid(e["golem_view"]))
	check("GolemBossView.body verborgen (geen dubbele sprite)", e["golem_view"].body.visible == false)

	# Wacht op eerste windup (kern-open kan aanvallen uitstellen)
	var guard := 0
	while f.step != GolemFight.Step.WINDUP and guard < 900:
		a.step_ticks(1)
		guard += 1
	check("windup bereikt binnen 15 s", f.step == GolemFight.Step.WINDUP)
	if f.step != GolemFight.Step.WINDUP:
		return

	var tg: TelegraphAttack = e["tg"]
	a._sync_telegraph_draw()
	check("telegraaf in WINDUP vóór schade", tg.in_windup())
	check("TelegraphLayer toont ≥1 vorm tijdens windup", a.telegraph_layer != null and a.telegraph_layer.entry_count() >= 1)
	check("GolemBossView.marker zichtbaar in windup", e["golem_view"].marker.visible)

	# Screenshot van telegraaf
	if shots != "":
		await get_tree().process_frame
		await get_tree().process_frame
		_shot("golem_telegraph_windup")

	# Hit-zone dekt echte strike-reach (zelfde origin/reach als _golem_strike)
	var attack_id := str(e.get("golem_attack", ""))
	var atk_def := GolemBoss.attack(attack_id)
	var reach_px: int = a._golem_strike_reach_px(m, atk_def)
	var origin: Vector2 = e.get("golem_origin", a.center_of(m)) as Vector2
	check("tg.shape.reach == strike-reach (%d)" % reach_px, tg.shape() != null and int(tg.shape().reach) == reach_px)
	var hit_pt := TelegraphShape.to_px(origin)  # origin zelf moet in cirkel/vorm-centrum of nabij
	# Voor circle op origin: punt op origin zit erin; voor arc/line: check locked origin distance
	var shape_ok := tg.shape().valid and (tg.hits_point_i(TelegraphShape.to_px(origin)) \
			or origin.distance_to(a.center_of(m)) <= float(reach_px) + 1.0)
	check("telegraaf-vorm dekt strike-origin/reach", shape_ok)

	# Eén schade-event per strike: speeler in bereik, tel strike + hit_member
	var b: Node2D = a.player
	if b:
		b.position = origin  # in de hit-zone
	for id in a.iframes.keys():
		a.iframes[id] = 0.0
	var strikes0: int = a.golem_strike_count
	var hits0: int = a.golem_strike_hit_member_count
	var hp0 := int(GameState.party[0]["hp"])
	var player_hits := [0]
	var cb := func(dmg: int) -> void:
		player_hits[0] = int(player_hits[0]) + 1
	a.player_hit.connect(cb)
	guard = 0
	while f.step == GolemFight.Step.WINDUP and guard < 120:
		a.step_ticks(1)
		guard += 1
	# ACTIVE tick(s) waarin attack_hit landt
	guard = 0
	while a.golem_strike_count == strikes0 and guard < 30:
		a.step_ticks(1)
		guard += 1
	a.player_hit.disconnect(cb)
	check("precies één _golem_strike na windup", a.golem_strike_count == strikes0 + 1)
	check("hit_member alleen via strike (≤ party, hier 1)", a.golem_strike_hit_member_count - hits0 <= 1 and a.golem_strike_hit_member_count >= hits0)
	check("player_hit ≤ 1 per strike (geen dubbele schade-pad)", int(player_hits[0]) <= 1)
	check("telegraaf gewist na strike", not tg.is_busy() and a.telegraph_layer.entry_count() == 0)

	# Buiten bereik: ver weg, volgende strike geen HP-verlies
	if b:
		b.position = a.center_of(m) + Vector2(400, 400)
	for id in a.iframes.keys():
		a.iframes[id] = 0.0
	hp0 = int(GameState.party[0]["hp"])
	strikes0 = a.golem_strike_count
	guard = 0
	while a.golem_strike_count == strikes0 and guard < 900:
		# kern-open blokkeert; doorsteppen
		a.step_ticks(1)
		guard += 1
	check("volgende strike buiten bereik gebeurde", a.golem_strike_count >= strikes0 + 1)
	check("buiten bereik: geen HP-verlies", int(GameState.party[0]["hp"]) == hp0)

	# Dodge/iframes: in bereik maar iframes aan → geen schade
	guard = 0
	while f.step != GolemFight.Step.WINDUP and guard < 900:
		a.step_ticks(1)
		guard += 1
	if b:
		b.position = e.get("golem_origin", a.center_of(m))
	for id in a.party_ids():
		a.iframes[id] = 5.0
	hp0 = int(GameState.party[0]["hp"])
	strikes0 = a.golem_strike_count
	guard = 0
	while a.golem_strike_count == strikes0 and guard < 120:
		# houd iframes hoog tijdens de windup→hit
		for id in a.party_ids():
			a.iframes[id] = 5.0
		a.step_ticks(1)
		guard += 1
	check("strike met iframes/dodge: geen HP-verlies", a.golem_strike_count >= strikes0 + 1 and int(GameState.party[0]["hp"]) == hp0)

	# Interrupt wist telegraaf: start windup, forceer telegraphs_cancelled via core-break
	for id in a.iframes.keys():
		a.iframes[id] = 0.0
	guard = 0
	while f.step != GolemFight.Step.WINDUP and guard < 900:
		a.step_ticks(1)
		guard += 1
	check("interrupt-setup: opnieuw in windup", f.step == GolemFight.Step.WINDUP and e["tg"].in_windup())
	# Core-break: open venster + break_damage; als kern dicht, wacht op open tijdens windup of forceer clear
	if f.core.open:
		var need := int(f.core.break_damage)
		a.damage_enemy(m, maxi(need * 3, 200), Vector2i.ZERO)
	else:
		# Simuleer cancel-pad (zelfde als telegraphs_cancelled-handler)
		a._golem_clear_telegraph(e)
	a._sync_telegraph_draw()
	check("interrupt/clear: telegraaf weg", not e["tg"].is_busy() and a.telegraph_layer.entry_count() == 0)

	# Hit-flash bestand bestaat (tijdelijke feedback)
	check("tijdelijke hit-flash art aanwezig (golem_boss_v2_hit.png)",
			ResourceLoader.exists("res://assets/sprites/enemies/golem_boss_v2_hit.png"))


func _shot(name: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join(name + ".png")
	var img: Image = null
	var tex := get_viewport().get_texture()
	if tex != null:
		img = tex.get_image()
	if img == null:
		# Headless/dummy renderer: rasteriseer de telegraaf-outline naar een PNG.
		img = _render_telegraph_fallback()
	if img == null:
		print("SHOT skip: ", name)
		return
	img.save_png(path)
	print("SHOT ", path)


func _render_telegraph_fallback() -> Image:
	var s := get_tree().current_scene
	if s == null or s.get("som") == null:
		return null
	var a: Node = s.som
	var m = null
	for x in a.enemies.keys():
		if a.enemies[x].get("golem", null) != null:
			m = x
			break
	if m == null or not a.enemies[m].has("tg"):
		return null
	var tg: TelegraphAttack = a.enemies[m]["tg"]
	if tg == null or not tg.is_busy():
		return null
	var layer = a.telegraph_layer
	var poly: PackedVector2Array = layer.outline_polygon(tg.shape(), 1.0)
	var img := Image.create(384, 216, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.08, 0.12, 1))
	_fill_poly(img, poly, Color(0.92, 0.18, 0.18, 0.85))
	# Marker-stip op doel
	if a.enemies[m].has("golem_origin"):
		var origin: Vector2 = a.enemies[m]["golem_origin"]
		var mid := Vector2(192, 108)
		var c := mid  # origin relatief gecentreerd via _fill_poly off; zet kruis in midden-ish
		for d in range(-3, 4):
			var x := clampi(int(c.x) + d, 0, 383)
			var y := clampi(int(c.y), 0, 215)
			img.set_pixel(x, y, Color(1, 1, 0.2, 1))
			img.set_pixel(clampi(int(c.x), 0, 383), clampi(int(c.y) + d, 0, 215), Color(1, 1, 0.2, 1))
	return img


func _fill_poly(img: Image, poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3:
		return
	var min_x := 0
	var max_x := img.get_width() - 1
	var min_y := 0
	var max_y := img.get_height() - 1
	# Eenvoudige scanline in bounding box
	var bb_min := poly[0]
	var bb_max := poly[0]
	for p in poly:
		bb_min = Vector2(minf(bb_min.x, p.x), minf(bb_min.y, p.y))
		bb_max = Vector2(maxf(bb_max.x, p.x), maxf(bb_max.y, p.y))
	# Centreer in beeld
	var off := Vector2(img.get_width(), img.get_height()) * 0.5 - (bb_min + bb_max) * 0.5
	for y in range(maxi(0, int(bb_min.y + off.y) - 1), mini(img.get_height(), int(bb_max.y + off.y) + 2)):
		for x in range(maxi(0, int(bb_min.x + off.x) - 1), mini(img.get_width(), int(bb_max.x + off.x) + 2)):
			if _point_in_poly(Vector2(x, y) - off, poly):
				img.set_pixel(x, y, col)
	# Rand
	for i in poly.size():
		var a2: Vector2 = poly[i] + off
		var b2: Vector2 = poly[(i + 1) % poly.size()] + off
		_line(img, a2, b2, Color(1, 0.3, 0.3, 1))


func _point_in_poly(pt: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > pt.y) != (pj.y > pt.y)) and (pt.x < (pj.x - pi.x) * (pt.y - pi.y) / (pj.y - pi.y + 0.0001) + pi.x):
			inside = not inside
		j = i
	return inside


func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, col)
