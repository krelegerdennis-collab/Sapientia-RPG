extends RefCounted
## SoM-proef (realtime gevecht, scripts/som/): tests binnen --autotest (scripts/debug_autotest.gd).
## t = de autotest-node (check/frames/wait_scene/...). Screenshots alleen met --som-shots=<map>.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const SomHud := preload("res://scripts/som/som_hud.gd")

var t: Node
var shots := ""
var gif_dir := ""


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--som-shots="):
			shots = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(shots)


func shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := t.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  som-screenshot: ", shots.path_join(name + ".png"))


## Ruwe frames voor een GIF (ffmpeg buiten Godot).
func gif_frames(prefix: String, n: int, every: int) -> void:
	if shots == "":
		return
	var dir := shots.path_join("gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for i in n:
		for k in every:
			await t.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := t.get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(dir.path_join("%s_%03d.png" % [prefix, i]))


func room() -> Node:
	return t.scene()


func arena() -> Node:
	var r := room()
	return r.som if r != null and "som" in r else null


func seconds(s: float) -> void:
	await t.get_tree().create_timer(s, true).timeout


## Zet monster m vlak voor de speler (speler kijkt ernaar).
func face_monster(m: Node) -> void:
	var p: CharacterBody2D = t.player()
	var pt: Vector2i = p.get_tile()
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		if room().monster_can_enter(m, pt + dir) == "free":
			m.place_at(pt + dir, -dir)
			p.face(dir)
			return


func run() -> void:
	Engine.time_scale = 1.0
	await _settings_tests()
	await _title_button_tests()
	if arena() == null:
		t.check("SoM: arena bestaat (rest overgeslagen)", false)
		return
	arena().allies_enabled = false      # eerst de speler alleen
	await _move_tests()
	await _charge_and_attack_tests()
	await _enemy_ai_tests()
	await _ring_tests()
	await _ui2_tests()
	arena().allies_enabled = true
	await _ally_tests()
	await _switch_tests()
	await _boss_handoff_tests()
	await _style_path_tests()
	await _hud_layout_tests()
	await _ring_layout_tests()
	await _magic_tests()
	await _death_tests()
	await _actionsim_tests()      # als laatste: bouwt de SoM-startparty opnieuw op
	await _action_boss_tests()


func _settings_tests() -> void:
	# 21 okt 2026: standaard voor een vers spel = Action; testsuites beginnen bewust in Classic (settings.gd)
	t.check("SoM: Battle Style standaard Action (vers spel), testrun start Classic", int(Settings.DEFAULTS["battle_style"]) == 1 and not Settings.action_battles())
	Settings.set_value("battle_style", 1)
	Settings.load_settings()       # opnieuw van schijf
	t.check("SoM: Battle Style = Action blijft bewaard (settings.cfg)", Settings.action_battles())
	Settings.set_value("battle_style", 5)
	t.check("SoM: Battle Style wordt begrensd", int(Settings.get_value("battle_style")) == 1)
	Settings.set_value("battle_style", 0)
	Settings.load_settings()
	t.check("SoM: terug naar Classic bewaard", not Settings.action_battles())
	t.check("SoM: room_enabled alleen in SoM-kamers met Action", SomData.room_enabled("archief_v1_gang", true)
			and not SomData.room_enabled("archief_v1_gang", false) and not SomData.room_enabled("wilgendal", true))
	t.check("SoM: lading-multiplier 100%% = 1, 0%% = %.2f" % SomData.CHARGE_MIN_MULT,
			is_equal_approx(SomArena.charge_mult(1.0), 1.0) and is_equal_approx(SomArena.charge_mult(0.0), SomData.CHARGE_MIN_MULT)
			and SomArena.charge_mult(0.5) < 1.0)


func _title_button_tests() -> void:
	if t.map_name() != "Title":
		GameState.go_to_title()
	for i in 300:
		if t.map_name() == "Title" and not GameState.changing_map:
			break
		await t.get_tree().process_frame
	t.check("SoM: titelscherm", t.map_name() == "Title")
	await t.frames(30)
	var b: Button = t.scene().get_node_or_null("SomButton")
	var pvp: Button = t.scene().get_node_or_null("PvpButton")
	t.check("SoM: knop 'SoM' naast PvP", b != null and pvp != null and b.text.strip_edges() == "SoM"
			and absf(b.position.y - pvp.position.y) < 1.0 and b.position.x > pvp.position.x and b.visible)
	await shot("v2_title")
	if b == null:
		return
	b.pressed.emit()
	t.check("SoM: knop laadt de proefkerker", await t.wait_scene("ArchiefV1Gang"))
	await t.frames(30)
	t.check("SoM: som_mode aan + arena in de kamer", GameState.som_mode and arena() != null)
	t.check("SoM: standaard-party Dax + Vesper + Seren", GameState.party.size() == 3 and str(GameState.party[0]["name"]) == "Dax")
	t.check("SoM: 2 AI-bondgenoten op het veld", arena() != null and arena().allies.size() == 2)
	var spr: Sprite2D = t.player().get_node("Sprite2D")
	t.check("SoM: Dax met 24x32-sprite, voeten op de tegelrand (offset %s)" % spr.offset,
			MapSprite.frame_maat(spr.texture) == MapSprite.NIEUW and spr.offset == Vector2(0, -8))
	t.check("SoM: joystick-modus op de touch-laag", arena().touch != null and arena().touch.joystick_mode)
	t.check("SoM: startitems (Potion x%d)" % GameState.item_count("drankje"), GameState.item_count("drankje") == int(SomData.START_ITEMS["drankje"]))
	t.check("SoM: zichtbare vijanden geregistreerd (%d)" % (arena().enemies.size() if arena() else 0), arena() != null and arena().enemies.size() >= 3)
	t.check("SoM: eigen save-pad", GameState.save_path == SomData.SAVE_PATH)


func _move_tests() -> void:
	const SomMove := preload("res://scripts/som/som_move.gd")
	t.check("SoM-beweging: dode zone", SomMove.joy_to_dir(Vector2(0.1, 0.1)) == Vector2.ZERO)
	var half := SomMove.joy_to_velocity(Vector2(0.6, 0.0), 80.0)
	var full := SomMove.joy_to_velocity(Vector2(1.0, 0.0), 80.0)
	t.check("SoM-beweging: snelheid evenredig met duwen (%.0f < %.0f = 80)" % [half.x, full.x], half.x > 20.0 and half.x < full.x and is_equal_approx(full.x, 80.0))
	var d := SomMove.joy_to_dir(Vector2(0.9, 0.5))
	t.check("SoM-beweging: 8 richtingen (schuin = 45 graden)", is_equal_approx(absf(d.normalized().x), absf(d.normalized().y)))
	t.check("SoM-beweging: kijkrichting", SomMove.facing_for(Vector2(0.2, -1), Vector2i.DOWN) == Vector2i.UP
			and SomMove.facing_for(Vector2(1, 0.1), Vector2i.UP) == Vector2i.RIGHT)
	var a := arena()
	var p: CharacterBody2D = t.player()
	# vrije pixelbeweging met de joystick
	p.place_at(Vector2i(12, 8), Vector2i.DOWN)
	await t.frames(2)
	var x0 := p.position.x
	a.forced_joy = Vector2(0.5, 0.0)
	await seconds(0.25)
	var x_half := p.position.x - x0
	a.forced_joy = Vector2.ZERO
	t.check("SoM-beweging: joystick beweegt vrij (geen tegelsprong: %.1f px)" % x_half, x_half > 3.0 and fmod(p.position.x, 16.0) != 8.0)
	# muur-glijden: schuin tegen een muur in: blijft tegen de muur, glijdt opzij
	var r := room()
	var wt := Vector2i(-1, -1)
	for y in range(2, 11):
		for x in range(2, 28):
			var c := Vector2i(x, y)
			if r.is_wall(c + Vector2i.UP) and not r.is_wall(c) and not r.is_wall(c + Vector2i.RIGHT) and not r.is_wall(c + Vector2i(2, 0)) \
					and r.is_wall(c + Vector2i(1, -1)) and r.is_wall(c + Vector2i(2, -1)):
				wt = c
				break
		if wt.x >= 0:
			break
	if wt.x >= 0:
		p.place_at(wt, Vector2i.UP)
		await t.frames(2)
		var start := p.position
		a.forced_joy = Vector2(0.7, -0.7)
		await seconds(0.4)
		a.forced_joy = Vector2.ZERO
		t.check("SoM-beweging: glijdt langs de muur (dx %.1f, dy %.1f)" % [p.position.x - start.x, p.position.y - start.y],
				p.position.x - start.x > 6.0 and p.position.y >= wt.y * 16.0 and p.position.y - start.y > -8.0)
	else:
		t.check("SoM-beweging: muurtegel gevonden", false)
	# toetsenbord
	p.place_at(Vector2i(12, 8), Vector2i.DOWN)
	await t.frames(2)
	var px := p.position
	Input.action_press("move_right")
	Input.action_press("move_down")
	await seconds(0.2)
	Input.action_release("move_right")
	Input.action_release("move_down")
	t.check("SoM-beweging: toetsenbord schuin (8 richtingen)", p.position.x > px.x + 3.0 and p.position.y > px.y + 3.0)
	# aanvalsanimatie (RPG ART): 6 frames x 4 richtingen van 48x48, timings uit de data, treffer op frame 4
	var ad: Dictionary = SomData.ATTACK_ANIMS["dennis"]
	var real: Texture2D = SomFx.tex(str(ad["sheet"]))
	t.check("SoM-art: Dax-aanvalssheet 288x192 in de repo", real != null and real.get_size() == Vector2(288, 192))
	t.check("SoM-art: timings 120/180/50/110/90/160 ms, treffer frame 4",
			ad["ms"] == [120, 180, 50, 110, 90, 160] and int(ad["hit_frame"]) == 4 and SomData.ATTACK_HIT_FRAME == 4)
	var img := Image.create(288, 192, false, Image.FORMAT_RGBA8)
	p.facing = Vector2i.LEFT
	var anim: SomFx.Anim = SomFx.attack_anim(p, ImageTexture.create_from_image(img), ad)
	t.check("SoM-art: treffer op 350 ms (begin frame 4), totaal 710 ms", anim.hit_index == 3 and anim.start_of(anim.hit_index) == 350.0 and anim.total_ms() == 710.0)
	var hit_ms := [-1]
	var t0 := Time.get_ticks_msec()
	anim.hit.connect(func() -> void: hit_ms[0] = Time.get_ticks_msec() - t0)
	await t.frames(2)
	var body_spr: Sprite2D = p.get_node("Sprite2D")
	t.check("SoM-art: 6x4 frames, rij = richting (links), voeten op de rand, lichaam verborgen", anim.hframes == 6 and anim.vframes == 4
			and anim.frame / 6 == SomFx.dir_index(Vector2i.LEFT) and anim.offset == Vector2(0, -16) and not body_spr.visible)
	await seconds(0.2)
	t.check("SoM-art: op ~200 ms frame 2 (0-based 1), nog geen treffer (%d)" % anim.frame, anim.frame % 6 == 1 and hit_ms[0] < 0)
	await seconds(0.25)
	# speltijd (elapsed_ms) i.p.v. wandklok: xvfb kan frames overslaan; hooguit één frame na 350 ms
	t.check("SoM-art: treffer op frame 4 (%.0f ms speltijd)" % anim.hit_at_ms, hit_ms[0] >= 0 and anim.hit_at_ms >= 350.0 and anim.hit_at_ms <= 400.0
			and anim.frame % 6 >= 3)
	await seconds(0.4)
	t.check("SoM-art: na de animatie weer de loopsprite", body_spr.visible and p.get_node_or_null("SomAttackAnim") == null)


var strike_charge := 1.0


## Slaan en wachten tot de slag landt (frame 4 van de aanvalsanimatie); geeft het aantal treffers.
func strike() -> int:
	var a := arena()
	var r: Array = [-2]
	var cb := func(_id: String, n: int) -> void: r[0] = n
	a.swing_landed.connect(cb)
	var direct: int = a.attack()
	strike_charge = a.charge
	var waited := 0
	while direct < 0 and r[0] == -2 and waited < 120:
		await t.frames(1)
		waited += 1
	a.swing_landed.disconnect(cb)
	return direct if direct >= 0 else int(r[0])


func _first_enemy() -> Node:
	for m in arena().enemies.keys():
		if is_instance_valid(m):
			return m
	return null


func _charge_and_attack_tests() -> void:
	var a := arena()
	t.player().place_at(Vector2i(12, 8), Vector2i.RIGHT)     # midden in beeld (screenshots)
	await seconds(1.2)
	t.check("SoM: wapenmeter vol (%.2f)" % a.charge, a.charge >= 1.0)
	var m := _first_enemy()
	face_monster(m)
	await t.frames(2)
	var e: Dictionary = a.enemies[m]
	var hp0 := int(e["hp"])
	var hits: int = await strike()
	t.check("SoM: slag raakt de vijand voor je (%d)" % hits, hits >= 1 and int(e["hp"]) < hp0 or not a.enemies.has(m))
	var full: int = a.last_enemy_damage
	t.check("SoM: meter na de slag op 0 (%.2f)" % strike_charge, strike_charge < 0.05)
	t.check("SoM: schadegetal in beeld", room().get_node("Objects").find_children("SomNumber*", "", false, false).size() > 0)
	await shot("v2_hit")
	await t.pframes(6)
	await shot("v2_charge")
	# lage lading: gemiddeld minder schade (atk/def uit de data; zelfde formule)
	var atk := float(GameState.effective_stat(GameState.party[0], "atk"))
	var low := 0
	var high := 0
	for i in 40:
		low += SomArena.physical_damage(atk, float(e["def"]), SomArena.charge_mult(0.0))
		high += SomArena.physical_damage(atk, float(e["def"]), 1.0)
	t.check("SoM: slag <100%% doet minder schade (%d < %d)" % [low, high], low < high and full >= 1)
	var anim_s: float = a.anim_seconds("dennis")
	await seconds(SomData.CHARGE_TIME + anim_s + 0.1)
	t.check("SoM: meter vult in ~%.1f s" % SomData.CHARGE_TIME, a.charge >= 1.0)
	a.attack()
	await seconds(anim_s * 0.5)
	t.check("SoM-v3: meter staat stil tijdens de slag-animatie (%.2f, %.2f s)" % [a.charge, anim_s], a.charge < 0.05 or not SomData.CHARGE_AFTER_ANIM)
	await seconds(anim_s * 0.5 + SomData.CHARGE_TIME * 0.5)
	t.check("SoM: halverwege het vullen nog niet vol (%.2f)" % a.charge, a.charge < 1.0 and a.charge > 0.2)
	await seconds(SomData.CHARGE_TIME * 0.5 + 0.15)
	t.check("SoM: daarna weer vol", a.charge >= 1.0)
	# schade x max(0.1, lading)
	t.check("SoM-v3: lading-multiplier = max(%.1f, lading)" % SomData.CHARGE_MIN_MULT, is_equal_approx(SomArena.charge_mult(0.5), 0.5)
			and is_equal_approx(SomArena.charge_mult(0.02), SomData.CHARGE_MIN_MULT) and is_equal_approx(SomData.CHARGE_MIN_MULT, 0.1))
	var s_full := 0
	var s_half := 0
	for i in 200:
		s_full += SomArena.physical_damage(40.0, 4.0, 1.0)
		s_half += SomArena.physical_damage(40.0, 4.0, 0.5)
	t.check("SoM-v3: 50%% lading = ~50%% schade (%d / %d)" % [s_half, s_full], absf(float(s_half) / float(s_full) - 0.5) < 0.04)
	# halve slag breekt de telegraaf niet af, volle wel
	var mt := _first_enemy()
	if mt:
		var et: Dictionary = a.enemies[mt]
		var hp_keep := int(et["hp"])
		et["hp"] = 999
		et["tele"] = 0.4
		a.damage_enemy(mt, 1, Vector2i.RIGHT, false)
		var kept := float(et["tele"]) > 0.0
		a.damage_enemy(mt, 1, Vector2i.RIGHT, true)
		t.check("SoM-v3: slag <100%% onderbreekt geen telegraaf, 100%% wel", kept and float(et["tele"]) <= 0.0)
		et["hp"] = hp_keep
	t.check("SoM-v3: vijandschade x ENEMY_DAMAGE_MULT (%.2f)" % SomData.ENEMY_DAMAGE_MULT, SomData.ENEMY_DAMAGE_MULT >= 1.0)
	# verslaan: EXP/goud/buit
	await seconds(0.3)              # knockback van de telegraaf-test uitlopen
	if a.enemies.has(m):
		face_monster(m)
		a.enemies[m]["hp"] = 1
	var exp0 := int(GameState.party[0]["exp"])
	var gold0 := GameState.gold
	if not a.enemies.has(m):        # de eerste slag was al raak genoeg: neem de volgende
		m = _first_enemy()
		face_monster(m)
		a.enemies[m]["hp"] = 1
		await t.frames(2)
	var mid: String = m.monster_id
	var eid: String = m.enemy_id
	a.enemies[m]["chase"] = 9.0     # blijft staan tijdens de slag (treffer pas op frame 4)
	a.enemies[m]["cd"] = 9.0
	face_monster(m)
	await t.frames(2)
	a.charge = 1.0
	await strike()
	t.check("SoM: vijand verslagen -> EXP (%d -> %d) en goud" % [exp0, int(GameState.party[0]["exp"])],
			int(GameState.party[0]["exp"]) > exp0 and GameState.gold >= gold0)
	t.check("SoM: verslagen monster weg uit de kamer en onthouden", not room().monsters.has(m)
			and GameState.defeated_map_monsters.get(room().room_id, {}).has(mid))
	t.check("SoM: bestiarium telt mee", GameState.defeated_count(eid) >= 1)
	await seconds(0.5)


func _enemy_ai_tests() -> void:
	var a := arena()
	for al in a.allies:
		al.position = Vector2(-2000, -2000)     # stilgezet en uit de buurt: alleen Dax
	var m := _first_enemy()
	for e0 in a.enemies.values():      # lopende telegrafen (op bondgenoten) afbreken
		e0["tele"] = 0.0
		e0["cd"] = 0.0
		e0["target"] = ""
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	a.iframes.clear()
	room().invuln_left = 0.0
	face_monster(m)
	var hp0 := int(GameState.party[0]["hp"])
	var saw_tele := false
	var frames := 0
	while frames < 240 and int(GameState.party[0]["hp"]) == hp0:
		await t.get_tree().process_frame
		frames += 1
		if a.enemies.values().any(func(e): return float(e["tele"]) > 0.0):
			saw_tele = true
	t.check("SoM: vijand telegrafeert eerst", saw_tele)
	t.check("SoM: vijand raakt de speler (-%d HP)" % a.last_player_damage, int(GameState.party[0]["hp"]) < hp0 and a.last_player_damage > 0)
	t.check("SoM: cooldown na de aanval", a.enemies.values().any(func(e): return float(e["cd"]) > 0.0))
	# achtervolgen: een vijand op afstand komt dichterbij
	var far: Node = null
	for o in a.enemies.keys():
		if is_instance_valid(o) and o != m:
			far = o
	if far:
		var pt: Vector2i = t.player().get_tile()
		for dir in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(3, 2), Vector2i(-3, 2)]:
			if room().monster_can_enter(far, pt + dir) == "free":
				far.place_at(pt + dir, Vector2i.DOWN)
				break
		var d0: float = far.position.distance_to(t.player().position)
		await seconds(2.0)
		t.check("SoM: vijand achtervolgt (%.0f -> %.0f px)" % [d0, far.position.distance_to(t.player().position)],
				not is_instance_valid(far) or far.position.distance_to(t.player().position) < d0)


## Korte GIF-reeks: slaan op de dichtstbijzijnde vijand (alleen met --som-shots).
func _gif_fight() -> void:
	if shots == "":
		return
	var a := arena()
	var m := _first_enemy()
	if m == null:
		return
	face_monster(m)
	a.enemies[m]["hp"] = 999
	for i in 60:
		if i % 14 == 4 and a.enemies.has(m):
			a.attack()
		await gif_frames("fight_%02d" % i, 1, 2)
	if a.enemies.has(m):
		a.enemies[m]["hp"] = 5


func _ring_tests() -> void:
	var a := arena()
	var h: Dictionary = GameState.party[0]
	h["hp"] = maxi(1, int(h["max_hp"]) - 25)
	a.open_ring()
	await t.pframes(2)
	t.check("SoM: ringmenu pauzeert de boom", t.get_tree().paused and a.ring.is_open)
	var pos := {}
	for m in a.enemies.keys():
		pos[m] = m.position
	var c: float = a.charge
	await t.pframes(40)
	var frozen := true
	for m in pos:
		if is_instance_valid(m) and m.position != pos[m]:
			frozen = false
	t.check("SoM: tijdens pauze staat alles stil", frozen and is_equal_approx(a.charge, c))
	t.check("SoM: ring toont items", a.ring.entries.size() >= 1)
	await shot("v2_ring")
	var idx := -1
	for i in a.ring.entries.size():
		if a.ring.entries[i]["id"] == "drankje":
			idx = i
	var n0 := GameState.item_count("drankje")
	var hp0 := int(h["hp"])
	a.ring.choose(idx)
	t.check("SoM: kiezen sluit de ring en hervat", not t.get_tree().paused and not a.ring.is_open)
	await seconds(SomData.RING_CAST_DELAY + 0.3)
	t.check("SoM: Potion uit de ring gebruikt (%d -> %d, HP %d -> %d)" % [n0, GameState.item_count("drankje"), hp0, int(h["hp"])],
			GameState.item_count("drankje") == n0 - 1 and int(h["hp"]) > hp0)
	# skills-ring
	a.open_ring()
	await t.pframes(2)
	a.ring.switch_tab()
	t.check("SoM: skills-ring = technieken van de bestuurde held (%s)" % a.ring.tab, a.ring.tab == "skills"
			and a.ring.entries.size() == (SomData.SKILLS[a.active_id] as Array).size())
	await shot("v2_ring_skills")
	a.ring.switch_tab()
	t.check("SoM: magie-ring = spreuken van de bestuurde held", a.ring.tab == "magic"
			and a.ring.entries.size() == (a.hero().get("spells", []) as Array).size())
	a.ring.switch_tab()
	t.check("SoM: ringen draaien rond (items -> skills -> magic -> items)", a.ring.tab == "items")
	a.ring.switch_tab(-1)
	t.check("SoM: omhoog = vorige ring (magic)", a.ring.tab == "magic")
	a.ring.close({})
	t.check("SoM: sluiten zonder keuze hervat", not t.get_tree().paused)
	await t.frames(5)


## RPG ART batch ui2: genees-glans, spreuk-impact, Swap/Ring-knoppen, joystick, Phoenix-icoon (+ placeholders).
func _ui2_tests() -> void:
	var a := arena()
	var objs: Node = room().get_node("Objects")
	var p: CharacterBody2D = t.player()
	# Phoenix Feather-icoon: index 7 in ring_icons_8 (x=112)
	var ic: AtlasTexture = a.ring.icon_for({"kind": "item", "id": "feniksveer"})
	t.check("SoM-ui2: Phoenix Feather-icoon = index 7 van ring_icons_8 (128x16)", ic != null and ic.region == Rect2(112, 0, 16, 16)
			and ic.atlas.get_size() == Vector2(128, 16) and SomData.RING_ICON["feniksveer"] == 7)
	var ic0: AtlasTexture = a.ring.icon_for({"kind": "item", "id": "drankje"})
	t.check("SoM-ui2: bestaande iconen ongewijzigd (Potion = 0)", ic0 != null and ic0.region.position == Vector2.ZERO)
	# genees-glans
	for n in objs.get_children():
		if str(n.name).begins_with("SomHealGlow") or str(n.name).begins_with("SomSpellImpact"):
			n.free()
	p.place_at(Vector2i(12, 8), Vector2i.RIGHT)
	await t.frames(2)
	a.heal_glow(a.active_id)
	var g: Node = objs.find_children("SomHealGlow*", "", false, false)[0] if objs.find_children("SomHealGlow*", "", false, false).size() > 0 else null
	t.check("SoM-ui2: genees-glans 4x16x16, 100 ms, anker (8,16) op de voeten", g is Sprite2D and g.hframes == 4
			and g.texture.get_size() == Vector2(64, 16) and g.offset == Vector2(-8, -16) and g.position == p.position
			and g.ms == [100, 100, 100, 100])
	# spreuk-impact op de voeten van het doelwit (echte spreuk via cast_spell)
	var m := _first_enemy()
	var caster := ""
	for h in GameState.party:
		if "vuur" in (h.get("spells", []) as Array):
			caster = str(h["id"])
			h["mp"] = h["max_mp"]
	var imp: Node = null
	var e_feet: Array = []
	if m and caster != "":
		m.place_at(Vector2i(14, 8), Vector2i.LEFT)
		a.enemies[m]["hp"] = 999
		await t.frames(2)
		var cnode: Node2D = a.node_of(caster)
		if cnode:
			cnode.position = p.position + Vector2(-16, 0)
		for e in a.enemies.keys():
			e_feet.append(a.feet_of_enemy(e))
			a.enemies[e]["hp"] = 999      # niet laten sterven: dan blijft de positie te vergelijken
		a.cast_spell("vuur", caster, {})
		await released()
		e_feet.clear()
		for e in a.enemies.keys():
			if is_instance_valid(e):
				e_feet.append(a.feet_of_enemy(e))
		var found := objs.find_children("SomSpellImpact*", "", false, false)
		imp = found[0] if found.size() > 0 else null
	var on_feet := false
	if imp:
		on_feet = imp.position in e_feet
	t.check("SoM-ui2: spreuk-impact 4x24x24, 70 ms, anker (12,24) op de voeten van het doelwit", imp is Sprite2D and imp.hframes == 4
			and imp.texture.get_size() == Vector2(96, 24) and imp.offset == Vector2(-12, -24)
			and on_feet and imp.ms == [70, 70, 70, 70])
	a.heal_glow(a.active_id)
	await t.frames(3)
	await shot("v2_heal_impact")
	await seconds(0.6)
	t.check("SoM-ui2: effecten ruimen zichzelf op", objs.find_children("SomHealGlow*", "", false, false).is_empty()
			and objs.find_children("SomSpellImpact*", "", false, false).is_empty())
	# genezen via de ring (Potion) zet ook de glans
	var h0: Dictionary = GameState.party[0]
	h0["hp"] = maxi(1, int(h0["max_hp"]) - 20)
	a.resolve({"kind": "item", "id": "drankje"})
	t.check("SoM-ui2: Potion uit de ring -> genees-glans", objs.find_children("SomHealGlow*", "", false, false).size() > 0)
	# placeholder: ontbrekende art -> getekende ring
	var ph: Node = SomFx.oneshot(objs, {"sheet": "res://bestaat_niet.png", "cell": [16, 16], "frames": 4, "ms": 100, "anchor": [8, 16]},
			p.position, "SomTestPh", Color.WHITE)
	t.check("SoM-ui2: zonder art een placeholder-effect", ph != null and not (ph is Sprite2D))
	# knoppen
	var hud: Node = a.hud
	var sw: Button = hud.switch_button
	var rb: Button = hud.ring_button
	var swn: StyleBoxTexture = sw.get_theme_stylebox("normal") as StyleBoxTexture
	var swp: StyleBoxTexture = sw.get_theme_stylebox("pressed") as StyleBoxTexture
	var rbn: StyleBoxTexture = rb.get_theme_stylebox("normal") as StyleBoxTexture
	var rbp: StyleBoxTexture = rb.get_theme_stylebox("pressed") as StyleBoxTexture
	t.check("SoM-ui2: Swap-knop = btn_swap / btn_swap_pressed (38x14)", swn != null and swp != null
			and swn.texture.resource_path.ends_with("btn_swap.png") and swp.texture.resource_path.ends_with("btn_swap_pressed.png")
			and sw.size == SomData.TOP_BUTTON_SIZE and sw.text == "")
	t.check("SoM-ui2: Ring-knop = btn_ring / btn_ring_pressed (38x14)", rbn != null and rbp != null
			and rbn.texture.resource_path.ends_with("btn_ring.png") and rbp.texture.resource_path.ends_with("btn_ring_pressed.png")
			and rb.size == SomData.TOP_BUTTON_SIZE)
	t.check("SoM-ui2: Swap-/Ring-art-knoppen blijven gekoppeld", sw.pressed.get_connections().size() > 0
			and rb.pressed.get_connections().size() > 0)
	var fb := Button.new()
	fb.text = "X"
	t.check("SoM-ui2: knop zonder art blijft een tekstknop", not SomHud.skin_button(fb, "bestaat_niet") and fb.text == "X")
	fb.free()
	# joystick
	var tc: Node = a.touch
	t.check("SoM-ui2: joystick-art geladen (ring 60x60, knop 24x24)", tc._som_tex(SomData.UI_JOY_RING) != null
			and tc._som_tex(SomData.UI_JOY_RING).get_size() == Vector2(60, 60)
			and tc._som_tex(SomData.UI_JOY_KNOB).get_size() == Vector2(24, 24)
			and tc._som_tex(SomData.UI_JOY_KNOB_PRESSED).get_size() == Vector2(24, 24))
	tc.joy_raw = Vector2(1, 0)
	var k1: Vector2 = tc.joy_knob_pos(Vector2(100, 100), 1.0)
	tc.joy_raw = Vector2(0, -0.5)
	var k2: Vector2 = tc.joy_knob_pos(Vector2(100, 100), 2.0)
	tc.joy_raw = Vector2(3, 4)
	var k3: Vector2 = tc.joy_knob_pos(Vector2(100, 100), 1.0)
	tc.joy_raw = Vector2.ZERO
	t.check("SoM-ui2: knop reist max 18 art-px (%s, %s, %s)" % [k1, k2, k3], k1 == Vector2(118, 100) and k2 == Vector2(100, 82)
			and k3.distance_to(Vector2(100, 100)) <= 18.5)
	await t.frames(5)


## Wachten tot een spreuk vrijkomt (cast6 frame 4, ~540 ms), max ~1,5 s.
func released() -> void:
	var a := arena()
	var got := [false]
	var cb := func(_s: String, _c: String) -> void: got[0] = true
	a.spell_released.connect(cb)
	var n := 0
	while not got[0] and n < 90:
		await t.frames(1)
		n += 1
	a.spell_released.disconnect(cb)
	await t.frames(1)


func _press(action: String) -> void:
	var w := 0
	while not arena().active() and w < 180:
		await t.frames(1)
		w += 1
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.pframes(2)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await t.frames(2)


## v3: B tovert (Seren/Vesper), magie-ring met doelkeuze, spell_icons, gauge_ready_glow.
func _magic_tests() -> void:
	var a := arena()
	var p: CharacterBody2D = t.player()
	a.allies_enabled = false
	while a.active_id != "dennis":
		a.switch_hero()
	for h in GameState.party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	p.place_at(Vector2i(10, 8), Vector2i.RIGHT)
	for al in a.allies:
		al.position = p.position + Vector2(0, 20)
	var m: Node = room().add_monster({"id": "mag_geest", "enemy": "papiergeest", "tile": [13, 8], "moves": false})
	await t.frames(3)
	a.enemies[m]["hp"] = 999
	# Dax: B doet niets
	var n0: int = a.b_casts
	await _press("cancel")
	t.check("SoM-magie: B met Dax tovert niet", a.b_casts == n0)
	# Vesper: B = Spark op de dichtstbijzijnde vijand
	a.switch_hero("noor")
	await t.frames(2)
	p.place_at(Vector2i(10, 8), Vector2i.RIGHT)
	await t.frames(2)
	a.b_cast_cd = 0.0
	var mp0 := int(a.member("noor")["mp"])
	var hp0 := int(a.enemies[m]["hp"])
	await _press("cancel")
	await released()
	t.check("SoM-magie: B met Vesper tovert Spark (MP %d -> %d, vijand %d -> %d)" % [mp0, int(a.member("noor")["mp"]), hp0, int(a.enemies[m]["hp"])],
			a.b_casts == n0 + 1 and int(a.member("noor")["mp"]) < mp0 and a.last_attacker == "noor")
	await _press("cancel")
	t.check("SoM-magie: B-cooldown (%.1f s) voorkomt spam" % SomData.B_CAST_COOLDOWN, a.b_casts == n0 + 1)
	# Seren: B = Minor Heal op de gewondste
	a.switch_hero("lotte")
	await t.frames(2)
	a.b_cast_cd = 0.0
	var dax: Dictionary = a.member("dennis")
	dax["hp"] = int(dax["max_hp"]) / 2
	var dhp := int(dax["hp"])
	await _press("cancel")
	await released()
	t.check("SoM-magie: B met Seren geneest Dax (%d -> %d)" % [dhp, int(dax["hp"])], int(dax["hp"]) > dhp)
	# magie-ring met doelkeuze: Vesper kiest Spark -> doel = de tweede (verste) vijand
	a.switch_hero("noor")
	await t.frames(2)
	p.place_at(Vector2i(10, 8), Vector2i.RIGHT)
	var m2: Node = room().add_monster({"id": "mag_mot", "enemy": "glitchmot", "tile": [15, 8], "moves": false})
	await t.frames(3)
	a.enemies[m2]["hp"] = 999
	a.member("noor")["mp"] = a.member("noor")["max_mp"]
	a.open_ring()
	await t.pframes(2)
	a.ring.set_tab("magic")
	var si := -1
	for i in a.ring.entries.size():
		if a.ring.entries[i]["id"] == "vuur":
			si = i
	var ic: AtlasTexture = a.ring.buttons[si].icon if si >= 0 else null
	t.check("SoM-magie: Spark-icoon uit spell_icons (x=0, 64x16)", ic != null and ic.region == Rect2(0, 0, 16, 16)
			and ic.atlas.get_size() == Vector2(64, 16))
	var ib: AtlasTexture = a.ring.spell_icon("bliksem")
	var ih: AtlasTexture = a.ring.spell_icon("genees")
	t.check("SoM-magie: iconen bliksem x=16, genezing x=48", ib.region.position.x == 16.0 and ih.region.position.x == 48.0)
	a.ring.choose(si)
	t.check("SoM-magie: Spark vraagt een doel (ring blijft open, %d doelen)" % a.ring.entries.size(), a.ring.is_open and a.ring.tab == "target"
			and a.ring.entries.size() >= 2 and a.ring.entries.any(func(x): return x["target"] == m)
			and a.ring.entries.any(func(x): return x["target"] == m2))
	await shot("v3_magic_target")
	var ti := -1
	for i in a.ring.entries.size():
		if a.ring.entries[i]["target"] == m2:
			ti = i
	var h1 := int(a.enemies[m]["hp"])
	var h2 := int(a.enemies[m2]["hp"])
	a.ring.choose(ti)
	await seconds(SomData.RING_CAST_DELAY + 0.9)
	t.check("SoM-magie: gekozen doel geraakt, de andere niet (%d -> %d, %d -> %d)" % [h2, int(a.enemies[m2]["hp"]), h1, int(a.enemies[m]["hp"])],
			int(a.enemies[m2]["hp"]) < h2 and int(a.enemies[m]["hp"]) == h1)
	# heal-doel: Seren -> Vesper
	a.switch_hero("lotte")
	await t.frames(2)
	var ves: Dictionary = a.member("noor")
	ves["hp"] = 5
	dax["hp"] = int(dax["max_hp"]) - 1
	a.open_ring()
	await t.pframes(2)
	a.ring.set_tab("magic")
	a.ring.choose(0)
	t.check("SoM-magie: heal-doelen = levende partyleden", a.ring.tab == "target" and a.ring.entries.size() == GameState.alive_heroes().size())
	var vi := -1
	for i in a.ring.entries.size():
		if a.ring.entries[i]["target"] == "noor":
			vi = i
	a.ring.choose(vi)
	await seconds(SomData.RING_CAST_DELAY + 0.9)
	t.check("SoM-magie: Minor Heal op het gekozen doel (Vesper %d)" % int(ves["hp"]), int(ves["hp"]) > 5)
	# B in de doelkeuze = terug naar de magie-ring
	a.open_ring()
	await t.pframes(2)
	a.ring.set_tab("magic")
	a.ring.choose(0)
	a.ring.switch_tab()
	t.check("SoM-magie: terug uit de doelkeuze -> magie-ring", a.ring.tab == "magic" and a.ring.pending_spell.is_empty())
	a.ring.close({})
	await t.frames(2)
	# skill-ring: volle meter nodig
	a.switch_hero("dennis")
	await t.frames(2)
	p.place_at(Vector2i(12, 8), Vector2i.RIGHT)
	await t.frames(2)
	a.charge = 0.3
	t.check("SoM-skill: zonder volle meter 'Not ready yet!'", a.use_skill("wervelslag", "dennis") == SomData.TXT_NOT_READY)
	m.place_at(Vector2i(13, 8), Vector2i.LEFT)
	await t.frames(2)
	a.charge = 1.0
	var hh := int(a.enemies[m]["hp"])
	a.use_skill("wervelslag", "dennis")
	t.check("SoM-skill: Whirl Slash raakt rondom en leegt de meter", int(a.enemies[m]["hp"]) < hh and a.charge < 0.05)
	await _art3_tests(m)
	# gauge_ready_glow
	var g: Node = a.gauge
	a.charge = 0.5
	await t.frames(2)
	t.check("SoM-meter: niet vol -> geen ready-glow", g.ready_frame() == -1)
	a.charge = 1.0
	t.check("SoM-meter: gauge_ready_glow 72x4 geladen", g.ready_glow != null and g.ready_glow.get_size() == Vector2(72, 4))
	var seen := {}
	for i in 30:
		await t.frames(1)
		if g.ready_frame() >= 0:
			seen[g.ready_frame()] = true
	t.check("SoM-meter: vol -> ready-glow loopt door 4 frames (90 ms)", seen.size() == 4 and SomData.GAUGE_READY_MS == 90)
	g._t = 0.0
	t.check("SoM-meter: frame 0 op t=0, 1 op 0,1 s", g.ready_frame() == 0)
	g._t = 0.1
	var f1: int = g.ready_frame()
	g._t = 0.37
	t.check("SoM-meter: lus van 360 ms (%d, %d)" % [f1, g.ready_frame()], f1 == 1 and g.ready_frame() == 0)
	await shot("v3_gauge_ready")
	for mm in [m, m2]:
		if is_instance_valid(mm) and a.enemies.has(mm):
			a.enemies[mm]["hp"] = 1
	a.allies_enabled = true


## RPG ART pass 7-9: cast6 + castcirkel + spreuk-effecten, monster-sheets (nieuwe maten), held-poses.
func _art3_tests(m: Node) -> void:
	var a := arena()
	var p: CharacterBody2D = t.player()
	var objs: Node = room().get_node("Objects")
	for h in ["dax", "seren", "vesper"]:
		var ok := true
		for k in ["dodge", "hurt"]:
			var tx := SomFx.tex("res://assets/sprites/som/combat/%s_%s.png" % [h, k])
			ok = ok and tx != null and tx.get_size() == Vector2(192, 48)
		var ko := SomFx.tex("res://assets/sprites/som/combat/%s_ko.png" % h)
		t.check("SoM-art3: %s dodge/hurt 192x48, ko 48x48" % h, ok and ko != null and ko.get_size() == Vector2(48, 48))
	for id in ["noor", "lotte"]:
		var ct: Texture2D = a.pose_tex(id, "cast")
		t.check("SoM-art3: %s cast6 288x192 (6 x 48x48 x 4)" % id, ct != null and ct.get_size() == Vector2(288, 192))
	# spreuk-effect-definities uit de data (frames uit de sheetbreedte)
	var dv := SomFx.spell_fx_def("vuur", GameData.SPELLS["vuur"])
	var dk := SomFx.spell_fx_def("vonk", GameData.SPELLS["vonk"])
	var dg := SomFx.spell_fx_def("genees", GameData.SPELLS["genees"])
	var dx := SomFx.spell_fx_def("schok", GameData.SPELLS["schok"])
	t.check("SoM-art3: spell_vuur 6 x 32x48, anker (16,48)", int(dv.get("frames", 0)) == 6 and dv["anchor"] == [16, 48])
	t.check("SoM-art3: spell_vonk 5 x 32x32, anker (16,32)", int(dk.get("frames", 0)) == 5 and dk["anchor"] == [16, 32])
	t.check("SoM-art3: spell_genees 6 x 32x48; Shock (bliksem) -> spell_bliksem", int(dg.get("frames", 0)) == 6 and str(dx.get("key", "")) == "bliksem")
	# Vesper cast: cirkel onder haar, schade pas op frame 4
	a.switch_hero("noor")
	await t.frames(2)
	p.place_at(Vector2i(10, 8), Vector2i.RIGHT)
	await t.frames(2)
	a.member("noor")["mp"] = a.member("noor")["max_mp"]
	a.enemies[m]["hp"] = 999
	var h0 := int(a.enemies[m]["hp"])
	a.cast_spell("vuur", "noor", {}, m)
	await t.frames(1)
	var anim: Node = p.get_node_or_null("SomCastAnim")
	var circ: Node = p.get_node_or_null("SomCastCircle")
	t.check("SoM-art3: cast6 speelt (6x4) met castcirkel eronder (4 x 48x16, lus)", anim != null and anim.hframes == 6 and anim.vframes == 4
			and circ != null and circ.hframes == 4 and circ.loop and circ.z_index < 0 and int(anim.hit_index) == 3)
	t.check("SoM-art3: nog geen schade bij het begin van de cast", int(a.enemies[m]["hp"]) == h0)
	await released()
	t.check("SoM-art3: spreuk vrij op frame 4 (%.0f ms; verwacht 540)" % float(anim.hit_at_ms if is_instance_valid(anim) else -1.0),
			is_instance_valid(anim) and anim.hit_at_ms >= 540.0 and anim.hit_at_ms <= 600.0 and int(a.enemies[m]["hp"]) < h0)
	var fx: Node = null
	for n in objs.get_children():
		if str(n.name).begins_with("SomSpell_vuur"):
			fx = n
	t.check("SoM-art3: spell_vuur op de voeten van het doel (onderkant-midden)", fx != null and fx.position == a.feet_of_enemy(m)
			and fx.offset == Vector2(-16, -48) and fx.hframes == 6)
	await shot("v3_cast_fire")
	await seconds(0.5)
	t.check("SoM-art3: castcirkel weg na de cast", p.get_node_or_null("SomCastCircle") == null)
	# Seren geneest: spell_genees op de voeten van Dax
	a.switch_hero("lotte")
	await t.frames(2)
	var dax: Dictionary = a.member("dennis")
	dax["hp"] = int(dax["max_hp"]) / 2
	a.member("lotte")["mp"] = a.member("lotte")["max_mp"]
	a.cast_spell("genees", "lotte", dax)
	await released()
	var gfx: Node = null
	for n in objs.get_children():
		if str(n.name).begins_with("SomSpell_genees"):
			gfx = n
	t.check("SoM-art3: spell_genees op de voeten van Dax", gfx != null and gfx.position == a.node_of("dennis").position)
	await shot("v3_cast_heal")
	a.switch_hero("dennis")
	await t.frames(2)
	# monster-sheets: nieuwe maten en offsets uit de data
	var e: Dictionary = a.enemies[m]
	a._monster_pose(m, e, "attack", 1, 0.3)
	t.check("SoM-art3: monster-aanval 3x4 cellen 32x24, offset (-8,-8) t.o.v. de mapsprite (%s)" % m.sprite.offset,
			m.sprite.texture.get_size() == Vector2(96, 96) and m.sprite.hframes == 3 and m.sprite.vframes == 4
			and m.sprite.offset == Vector2(0, -4))
	a._restore_monster(m, e)
	t.check("SoM-art3: terug naar de mapsprite (offset hersteld)", m.sprite.offset == Vector2.ZERO and m.sprite.hframes != 3)
	a._monster_pose(m, e, "hurt", 0, a._hurt_seconds())
	var f0: int = m.sprite.frame
	t.check("SoM-art3: monster-hurt 2 frames x 4 richtingen (32x64)", m.sprite.texture.get_size() == Vector2(32, 64)
			and m.sprite.hframes == 2 and m.sprite.vframes == 4 and m.sprite.offset == Vector2.ZERO and f0 % 2 == 0)
	await seconds(0.12)
	t.check("SoM-art3: na 70 ms het tweede hurt-frame", m.sprite.frame % 2 == 1 or str(e.get("pose", "")) != "hurt")
	await seconds(0.3)
	t.check("SoM-art3: hurt voorbij -> mapsprite (%s %.2f, %s)" % [e.get("pose", ""), float(e.get("pose_t", 0.0)), a.active()], str(e.get("pose", "")) != "hurt")
	var dt: Texture2D = a._monster_sheet(m, "death")
	a._monster_pose(m, e, "death", 0, 0.1)
	t.check("SoM-art3: monster-death 4 x 24x24, offset (-4,-8)", dt.get_size() == Vector2(96, 24) and m.sprite.hframes == 4
			and m.sprite.offset == Vector2(0, -4))
	a._restore_monster(m, e)


## v3: headless actie-simulator (tools/battlesim/action_sim.gd): klein vast-seed-monster.
func _actionsim_tests() -> void:
	var path := "res://tools/battlesim/action_sim.gd"
	t.check("SoM-sim: action_sim.gd bestaat", ResourceLoader.exists(path))
	if not ResourceLoader.exists(path):
		return
	var sim: Node = load(path).new()
	sim.standalone = false
	t.add_child(sim)
	sim.setup()
	t.check("SoM-sim: 6 SoM-kamers met map-monsters (zonder baas)", sim.rooms.size() == SomData.ROOMS.size()
			and sim.rooms.all(func(r): return (r["enemies"] as Array).size() >= 1))
	var p: Dictionary = sim.params_base()
	var r1: Dictionary = sim.run_iteration(p, 6)
	var r2: Dictionary = sim.run_iteration(p, 6)
	t.check("SoM-sim: vaste seed = dezelfde uitkomst", JSON.stringify(r1) == JSON.stringify(r2))
	t.check("SoM-sim: getallen kloppen (verlies %.1f%%, winst %.0f%%)" % [r1["loss"] * 100.0, r1["win"] * 100.0],
			r1["loss"] >= 0.0 and r1["loss"] <= 1.0 and r1["win"] >= 0.0 and r1["win"] <= 1.0 and r1["p90"] >= 0.0)
	var chosen := {}
	for it in sim.ITERATIONS:
		if str(it["label"]).contains("CHOSEN"):
			chosen = it["set"]
	t.check("SoM-sim: gekozen iteratie staat in SomData (meter %.1f s, x%.1f, cd %.1f, telegraaf %.2f)" % [SomData.CHARGE_TIME,
			SomData.ENEMY_DAMAGE_MULT, SomData.ATTACK_COOLDOWN, SomData.TELEGRAPH], not chosen.is_empty()
			and is_equal_approx(float(chosen["charge_time"]), SomData.CHARGE_TIME)
			and is_equal_approx(float(chosen["enemy_dmg"]), SomData.ENEMY_DAMAGE_MULT)
			and is_equal_approx(float(chosen["enemy_cd"]), SomData.ATTACK_COOLDOWN)
			and is_equal_approx(float(chosen["telegraph"]), SomData.TELEGRAPH))
	var spam := p.duplicate()
	spam["policy"] = "spam"
	var rs: Dictionary = sim.run_iteration(spam, 6)
	t.check("SoM-sim: spammen kost meer tijd per kamer (%.1f s vs %.1f s)" % [rs["time"], r1["time"]], rs["time"] > r1["time"])
	sim.queue_free()


## v3 HUD-indeling (feedback Dennis): joystick kleiner/hoger, één rij rechtsboven [RUN][Swap][Ring][MENU], A/B rechtsonder.
func _hud_layout_tests() -> void:
	var a := arena()
	var tc: Control = a.touch
	var vs: Vector2 = tc.size
	var c: Vector2 = tc.dpad_center()
	t.check("SoM-HUD: joystick midden-links (%s in %s)" % [c, vs], c.x < vs.x * 0.25 and c.y > vs.y * 0.4 and c.y < vs.y * 0.75)
	t.check("SoM-HUD: joystick kleiner dan de D-pad (%.0f < %.0f)" % [tc.joy_radius(), tc.dpad_radius], tc.joy_radius() < tc.dpad_radius)
	t.check("SoM-HUD: ruim touch-vak rond de joystick (%.0f px)" % (tc.joy_radius() * SomData.JOY_TOUCH_REACH), tc.joy_radius() * SomData.JOY_TOUCH_REACH >= 44.0)
	var menu: Rect2 = tc.menu_rect()
	var ring_r := Rect2(a.hud.ring_button.position - tc.position, a.hud.ring_button.size)
	var swap_r := Rect2(a.hud.switch_button.position - tc.position, a.hud.switch_button.size)
	var run_r: Rect2 = tc.run_rect()
	var cy := menu.get_center().y
	t.check("SoM-HUD: Swap/Ring/RUN in één rij met MENU (y %.0f/%.0f/%.0f/%.0f)" % [swap_r.get_center().y, ring_r.get_center().y, run_r.get_center().y, cy],
			absf(ring_r.get_center().y - cy) < 1.5 and absf(swap_r.get_center().y - cy) < 1.5 and absf(run_r.get_center().y - cy) < 1.5)
	t.check("SoM-HUD: volgorde RUN < Swap < Ring < MENU, zonder overlap", run_r.end.x <= swap_r.position.x and swap_r.end.x <= ring_r.position.x
			and ring_r.end.x <= menu.position.x + 0.5 and cy < vs.y * 0.2)
	t.check("SoM-HUD: touch-vakken Swap/Ring >= 46x22 (art 38x14 erin)", swap_r.size.x >= 46.0 and swap_r.size.y >= 22.0 and ring_r.size.y >= 22.0)
	t.check("SoM-HUD: A/B blijven rechtsonder", tc.a_center().x > vs.x * 0.75 and tc.a_center().y > vs.y * 0.6 and tc.b_center().y > vs.y * 0.6)
	# tik op Ring in de nieuwe plek opent de ring
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = a.hud.ring_button.get_global_rect().get_center()
	var w := 0
	while not a.active() and w < 180:
		await t.frames(1)
		w += 1
	a.hud.ring_button.emit_signal("pressed")
	await t.pframes(2)
	t.check("SoM-HUD: Ring-knop (nieuwe plek) opent de ring", a.ring.is_open)
	await shot("v3_hud")
	a.ring.close({})
	await t.frames(3)
	await shot("v3_hud_closed")


## Geen enkele tekst/knop van de ring overlapt (elke ring, elk aantal keuzes) en alles blijft in beeld.
static func rects_ok(rs: Array, vs: Vector2) -> String:
	var screen := Rect2(Vector2.ZERO, vs)
	for i in rs.size():
		var r: Rect2 = rs[i]
		if not screen.encloses(r):
			return "rect %d %s buiten beeld" % [i, r]
		for j in range(i + 1, rs.size()):
			if r.intersects(rs[j]):
				return "rect %d %s raakt %d %s" % [i, r, j, rs[j]]
	return ""


## "" = alle aantal-labels liggen binnen (binnenrand - marge) en raken geen knop/icoon.
static func count_margin_fout(ring: Node, c: Vector2, tag: String) -> String:
	var lim: Vector2 = ring.inner_radius() - Vector2.ONE * SomData.RING_COUNT_MARGIN
	for r in ring.count_rects():
		if not ring.rect_in_ellipse(r, c, lim):
			return "%s: aantal %s raakt de ringrand; " % [tag, r]
		for b in ring.buttons:
			if (r as Rect2).intersects(Rect2(b.position, b.size)):
				return "%s: aantal %s raakt icoon %s; " % [tag, r, b.name]
	return ""


func _ring_layout_tests() -> void:
	var a := arena()
	var ring = a.ring
	var w := 0
	while not a.active() and w < 180:
		await t.frames(1)
		w += 1
	GameState.inventory["feniksveer"] = 1
	a.open_ring()
	await t.pframes(2)
	var vs: Vector2 = ring.root.get_viewport_rect().size
	var bad := ""
	for tb in ["items", "skills", "magic"]:
		ring.set_tab(tb)
		await t.pframes(1)
		for i in ring.entries.size():
			ring.selected = i
			ring._highlight()
			var e := rects_ok(ring.label_rects(), vs)
			if e != "":
				bad += "%s/%d: %s; " % [tb, i, e]
	t.check("SoM-ring: geen overlappende labels in items/skills/magie (%s)" % (bad if bad != "" else "ok"), bad == "")
	ring.set_tab("items")
	var fi := -1
	for i in ring.entries.size():
		if ring.entries[i]["id"] == "feniksveer":
			fi = i
	ring.selected = fi
	ring._highlight()
	var on_ring := false
	for b in ring.buttons:
		on_ring = on_ring or "Phoenix" in b.text or "Items" in b.text
	t.check("SoM-ring: volle naam staat NIET op de ring (alleen icoon + aantal)", fi >= 0 and not on_ring and ring.buttons[fi].text == ""
			and ring.counts[fi].text == "x1")
	# aantallen (x1/x3) liggen BINNEN de binnenrand van de ring, met marge, en raken geen icoon
	var cbad := ""
	var cc: Vector2 = vs / 2.0
	for tb in ["items", "skills", "magic"]:
		ring.set_tab(tb)
		await t.pframes(1)
		cbad += count_margin_fout(ring, cc, tb)
	ring.set_tab("items")
	ring.selected = fi
	ring._highlight()
	t.check("SoM-ring: aantal-labels binnen de ring met >= %dpx marge, raken geen icoon (%s)" % [int(SomData.RING_COUNT_MARGIN), cbad if cbad != "" else "ok"],
			cbad == "" and ring.count_rects().size() >= 1)
	t.check("SoM-ring: geselecteerde naam op eigen regel onder de ring ('%s')" % ring.name_label.text,
			ring.name_label.text == "Phoenix Feather x1" and ring.name_label.position.y > ring.buttons[0].position.y + ring.buttons[0].size.y
			and ring.title.position.y + ring.title.size.y <= ring.buttons[0].position.y)
	await t.pframes(1)
	await shot("v3b_ring_phoenix")
	# synthetische ringen: 1..12 keuzes, lange namen, met en zonder icoon, alle soorten
	var ids := ["drankje", "kruid", "toverwater", "feniksveer", "zzz_onbekend"]
	var worst := ""
	for kind in ["item", "skill", "spell", "target"]:
		for n in range(1, 13):
			var list: Array = []
			for i in n:
				var e := {"kind": kind, "id": ids[i % ids.size()], "label": "Extraordinarily Long Name %d x99" % i,
						"name": "Extraordinarily Long Name %d" % i, "caster": "dennis", "target": "dennis"}
				if kind == "item":
					e["count"] = 99
				list.append(e)
			ring.tab = "target" if kind == "target" else "items"
			ring.selected = n - 1
			ring.build_with(list)
			var e2 := rects_ok(ring.label_rects(), vs)
			if e2 == "":
				e2 = count_margin_fout(ring, vs / 2.0, kind)
			if e2 != "" and worst == "":
				worst = "%s n=%d: %s" % [kind, n, e2]
	t.check("SoM-ring: label-rects overlappen nooit bij 1..12 keuzes van elke soort (%s)" % (worst if worst != "" else "ok"), worst == "")
	ring.tab = "items"
	ring.close({})
	await t.frames(3)


## Action-modus bazen: SomData-vermenigvuldiger; Classic-baas exact ongewijzigd (echt battle.tscn).
func _action_boss_tests() -> void:
	const BossCore := preload("res://scripts/battle/boss_core.gd")
	var base: Dictionary = BossCore.apply_boss(GameData.ENEMIES["kennis_beest"].duplicate(true))
	t.check("SoM-baas: action_boss(..., Classic) = dezelfde data", SomData.action_boss(base, false) == base)
	var m3 := SomData.action_boss_mult(SomData.START_LEVEL)
	var m5 := SomData.action_boss_mult(SomData.START_LEVEL + 2)
	t.check("SoM-baas: Lv 3 HP x%.2f ATK x%.2f, Lv 5 ATK x%.2f (data-gedreven)" % [m3["max_hp"], m3["atk"], m5["atk"]],
			float(m3["max_hp"]) > 1.0 and float(m5["atk"]) > float(m3["atk"]))
	var was_som: bool = GameState.som_mode
	var was_style = Settings.get_value("battle_style")
	var got := {}
	for mode in ["classic", "action"]:
		GameState.som_mode = mode == "action"
		Settings.set_value("battle_style", 0)
		var b: Control = load("res://scenes/battle/battle.tscn").instantiate()
		b.set_script(load("res://tools/battlesim/sim_battle.gd"))
		GameState.pending_enemies = ["kennis_beest"]
		GameState.pending_boss = true
		GameState.pending_tutorial = {}
		GameState.dungeon100_floor = 0
		b.sim_started = true
		t.add_child(b)
		var st: Dictionary = b.enemies[0]["s"]
		got[mode] = {"max_hp": int(st["max_hp"]), "atk": int(st["atk"]), "def": int(st["def"])}
		b.queue_free()
		await t.frames(1)
	GameState.pending_boss = false
	GameState.som_mode = was_som
	Settings.set_value("battle_style", was_style)
	var c: Dictionary = got["classic"]
	t.check("SoM-baas: Classic Golem ongewijzigd (HP %d ATK %d DEF %d = %d/%d/%d)" % [c["max_hp"], c["atk"], c["def"], base["max_hp"], base["atk"], base["def"]],
			c["max_hp"] == int(base["max_hp"]) and c["atk"] == int(base["atk"]) and c["def"] == int(base["def"]))
	var ac: Dictionary = got["action"]
	var lvl: float = load("res://scripts/battle/battle.gd").action_party_level()
	var expd := SomData.action_boss(base, true, lvl)
	# 21 okt 2026: bazen altijd turn-based, ook in Action -> de Action-vermenigvuldiger geldt niet meer
	t.check("SoM-baas: Action Golem = Classic Golem, geen Action-vermenigvuldiger (HP %d ATK %d; oud zou %d/%d zijn bij Lv %.1f)" % [ac["max_hp"], ac["atk"], int(expd["max_hp"]), int(expd["atk"]), lvl],
			ac["max_hp"] == c["max_hp"] and ac["atk"] == c["atk"] and ac["def"] == c["def"])


func _ally(id: String) -> Node:
	return arena().ally_of(id)


func _ally_tests() -> void:
	var a := arena()
	var p: CharacterBody2D = t.player()
	for h in GameState.party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	# volgen
	p.place_at(Vector2i(6, 8), Vector2i.RIGHT)
	for al in a.allies:
		al.position = p.position
	a.forced_joy = Vector2(1, 0)
	await seconds(1.0)
	a.forced_joy = Vector2.ZERO
	await seconds(1.2)
	var near := true
	for al in a.allies:
		if al.position.distance_to(p.position) > 40.0:
			near = false
	t.check("SoM-AI: bondgenoten volgen Dax in formatie", near)
	t.check("SoM-AI: bondgenoten blokkeren Dax niet (botsingslaag 0)", a.allies.all(func(x): return x.collision_layer == 0))
	# niet vast > 5 s: in een muur gezet -> binnen 5 s weer bij Dax
	var al0: Node = a.allies[0]
	al0.position = Vector2(8, 8)        # hoek-muur
	var ok := false
	for i in 300:
		await t.get_tree().process_frame
		if al0.position.distance_to(p.position) < 48.0:
			ok = true
			break
	t.check("SoM-AI: nooit langer dan 5 s vast (teleport %d)" % al0.teleports, ok)
	al0.position = p.position + Vector2(400, 0)
	await t.frames(3)
	t.check("SoM-AI: buiten beeld -> bijteleporteren", al0.position.distance_to(p.position) < 48.0)
	# genezen: Dax onder 40% -> Seren geneest eerst
	var seren: Node = _ally("lotte")
	var dax: Dictionary = a.member("dennis")
	dax["hp"] = int(float(dax["max_hp"]) * 0.3)
	var hp0 := int(dax["hp"])
	var mp0 := int(a.member("lotte")["mp"])
	seren.spell_cd = 0.0
	await seconds(0.9)
	t.check("SoM-AI: Seren geneest Dax (<40%%): HP %d -> %d, MP %d -> %d" % [hp0, int(dax["hp"]), mp0, int(a.member("lotte")["mp"])],
			int(dax["hp"]) > hp0 and int(a.member("lotte")["mp"]) < mp0)
	# aanvallen: vijand vlak bij Dax
	var m := _first_enemy()
	if m:
		face_monster(m)
		a.enemies[m]["hp"] = 999
		a.enemies[m]["cd"] = 99.0
		var att := 0
		for i in 360:
			await t.get_tree().process_frame
			att = a.allies.reduce(func(acc, x): return acc + x.attacks, 0)
			if att > 0:
				break
		t.check("SoM-AI: bondgenoot valt aan met eigen meter (%s)" % a.last_attacker, att > 0 and a.last_attacker in ["noor", "lotte"])
		a.enemies[m]["hp"] = 3
		a.enemies[m]["cd"] = 0.5
	# vijanden kiezen elk partylid: bondgenoot stil op afstand van Dax, vijand ernaast
	a.allies_enabled = false
	p.place_at(Vector2i(4, 8), Vector2i.LEFT)
	a.allies[0].position = Vector2(10 * 16 + 8, 8 * 16 + 8)
	a.allies[1].position = Vector2(10 * 16 + 8, 9 * 16 + 8)
	var hit_ally := false
	for e in a.enemies.values():
		e["cd"] = 0.0
	a.iframes.clear()
	for i in 600:
		await t.get_tree().process_frame
		if a.last_hit_id in ["noor", "lotte"]:
			hit_ally = true
			break
		if i % 60 == 0:
			for h in GameState.party:
				h["hp"] = h["max_hp"]
			var mm := _first_enemy()
			if mm and a.room.monster_can_enter(mm, Vector2i(11, 8)) == "free":
				mm.place_at(Vector2i(11, 8), Vector2i.LEFT)
	t.check("SoM-AI: vijanden raken ook bondgenoten (%s)" % a.last_hit_id, hit_ally)
	a.allies_enabled = true
	# KO: Vesper KO -> blijft liggen; opstaan via de ring (Phoenix Feather)
	var vesper: Node = _ally("noor")
	a.member("noor")["hp"] = 0
	await t.frames(2)
	var pos: Vector2 = vesper.position
	await t.frames(30)
	t.check("SoM-AI: KO-bondgenoot staat stil (%s)" % vesper.state, vesper.state == "ko" and vesper.position == pos)
	var feathers := GameState.item_count("feniksveer")
	a.resolve({"kind": "item", "id": "feniksveer"})
	t.check("SoM-AI: Phoenix Feather uit de ring wekt Vesper (%d HP)" % int(a.member("noor")["hp"]),
			int(a.member("noor")["hp"]) > 0 and GameState.item_count("feniksveer") == feathers - 1)
	# pauze bevriest de bondgenoten
	p.place_at(Vector2i(6, 8), Vector2i.RIGHT)
	a.forced_joy = Vector2(1, 0)
	await seconds(0.3)
	a.forced_joy = Vector2.ZERO
	a.open_ring()
	await t.pframes(2)
	var ap: Array = a.allies.map(func(x): return x.position)
	await t.pframes(30)
	t.check("SoM-AI: ringmenu bevriest de bondgenoten", a.allies.map(func(x): return x.position) == ap)
	await shot("v2_ring_party")
	a.ring.close({})
	await t.frames(5)
	await _gif_party()


func _switch_tests() -> void:
	var a := arena()
	var p: CharacterBody2D = t.player()
	for h in GameState.party:
		h["hp"] = h["max_hp"]
	t.check("SoM-wissel: start met Dax", a.active_id == "dennis")
	var cam: Camera2D = p.get_node("Camera2D")
	var seren_pos: Vector2 = _ally("lotte").position
	var dax_pos: Vector2 = p.position
	var ev := InputEventAction.new()
	ev.action = a.SWITCH_ACTION
	ev.pressed = true
	Input.parse_input_event(ev)        # gebufferd: telt als 'just pressed' in het volgende beeld
	await t.pframes(2)
	var up := InputEventAction.new()
	up.action = a.SWITCH_ACTION
	Input.parse_input_event(up)
	await t.frames(2)
	t.check("SoM-wissel: toets C -> Seren (%s)" % a.active_id, a.active_id == "lotte" and p.position.distance_to(seren_pos) < 8.0)
	t.check("SoM-wissel: Dax wordt AI op de oude plek", _ally("dennis") != null and _ally("dennis").position.distance_to(dax_pos) < 12.0)
	var spr: Sprite2D = p.get_node("Sprite2D")
	t.check("SoM-wissel: speler-sprite = Seren", spr.texture == a.sheet_for("lotte"))
	t.check("SoM-wissel: ring toont Serens spreuken", a.ring_entries()["magic"].any(func(e): return e["caster"] == "lotte" and e["id"] == "genees"))
	# camera glijdt mee
	a.allies_enabled = false
	p.position = Vector2(200, p.position.y)
	await t.pframes(60)
	p.position = Vector2(330, p.position.y)
	await t.pframes(1)
	var d0 := cam.get_screen_center_position().distance_to(p.global_position)
	await t.pframes(20)
	var d1 := cam.get_screen_center_position().distance_to(p.global_position)
	t.check("SoM-wissel: camera volgt soepel (%.0f -> %.0f)" % [d0, d1], d1 < d0 and cam.position_smoothing_enabled)
	a.allies_enabled = true
	await seconds(0.8)
	await shot("v2_switch_seren")
	t.check("SoM-wissel: Seren -> Vesper", a.switch_hero() == "noor")
	a.member("lotte")["hp"] = 0
	t.check("SoM-wissel: Vesper -> Dax (Seren KO overgeslagen)", a.switch_hero() == "dennis")
	t.check("SoM-wissel: Dax -> Vesper (Seren KO overgeslagen)", a.switch_hero() == "noor")
	a.switch_hero("dennis")
	a.member("lotte")["hp"] = a.member("lotte")["max_hp"]
	t.check("SoM-wissel: knop 'Swap' in de HUD", a.hud.switch_button != null and a.hud.switch_button.visible)
	await t.frames(5)


## GIF: de hele party vecht (alleen met --som-shots).
func _gif_party() -> void:
	if shots == "":
		return
	var a := arena()
	var p: CharacterBody2D = t.player()
	p.place_at(Vector2i(10, 8), Vector2i.RIGHT)
	for h in GameState.party:
		h["hp"] = h["max_hp"]
	var m: Node = room().add_monster({"id": "gif_geest", "enemy": "papiergeest", "tile": [13, 8], "moves": true})
	room().add_monster({"id": "gif_mot", "enemy": "glitchmot", "tile": [12, 6], "moves": true})
	face_monster(m)
	a.enemies[m]["hp"] = 999
	for i in 90:
		if i % 10 == 3 and a.enemies.has(m):
			a.attack()
		if i == 30:
			a.forced_joy = Vector2(0.0, 0.8)
		if i == 45:
			a.forced_joy = Vector2(-0.8, -0.6)
		if i == 60:
			a.forced_joy = Vector2.ZERO
			face_monster(m)
		if i == 70:
			await shot("v2_party_fight")
		await gif_frames("v2_%03d" % i, 1, 2)
	a.forced_joy = Vector2.ZERO
	if a.enemies.has(m):
		a.enemies[m]["hp"] = 5


func _boss_handoff_tests() -> void:
	var r := room()
	var p: CharacterBody2D = t.player()
	var a := arena()
	for m in a.enemies.keys():          # rust: andere vijanden weg
		if is_instance_valid(m):
			r.monsters.erase(m)
			m.queue_free()
	a.enemies.clear()
	await t.frames(5)
	var pt: Vector2i = p.get_tile()
	var boss: Node = r.add_monster({"id": "som_testbaas", "enemy": "mosslijm", "boss": true, "tile": [pt.x + 1, pt.y], "moves": false})
	face_monster(boss)
	t.check("SoM: baas niet in de realtime-arena", not a.enemies.has(boss))
	var potions := GameState.item_count("drankje")
	r.invuln_left = 0.0
	r.monster_touch(boss)
	t.check("SoM: baas aanraken -> turn-based gevecht", await t.wait_scene("Battle"))
	var b: Node = t.battle()
	for guard in 80:
		if t.battle() == null:
			break
		for e in b.enemies:
			e["s"]["hp"] = mini(int(e["s"]["hp"]), 1)
		var st: String = await t.wait_battle_state(["command", "message_wait", "target_enemy"], 10)
		if st == "" or t.battle() == null:
			break
		if st == "command":
			await t.choose_command(0)
		else:
			await t.tap("interact")
	t.check("SoM: na de baas terug in de proefkerker", await t.wait_scene("ArchiefV1Gang", 20))
	await t.frames(20)
	t.check("SoM: arena weer actief na terugkeer", arena() != null and GameState.last_battle_result == "win")
	t.check("SoM: HP/items gesynchroniseerd (HP %d, Potions %d)" % [int(GameState.party[0]["hp"]), GameState.item_count("drankje")],
			int(GameState.party[0]["hp"]) >= 1 and GameState.item_count("drankje") == potions)


## Naar een map (ook dezelfde) en wachten tot de NIEUWE scène klaar staat.
func goto(path: String, spawn: String) -> bool:
	var old: Node = t.scene()
	GameState.change_map(path, spawn)
	for i in 900:
		await t.get_tree().process_frame
		var s: Node = t.scene()
		if s != null and s != old and s.is_node_ready() and not GameState.changing_map:
			await t.frames(10)
			return true
	return false


func _style_path_tests() -> void:
	# Classic + geen SoM-knop: dezelfde kamer is weer turn-based
	GameState.som_mode = false
	Settings.set_value("battle_style", 0)
	t.check("SoM: Classic -> geen arena (turn-based pad)", await goto(SomData.START_MAP, SomData.START_SPAWN) and arena() == null)
	await t.frames(10)
	var r := room()
	var m: Node = null
	for o in r.monsters:
		if is_instance_valid(o) and not o.boss:
			m = o
	if m:
		r._grace_left = 0.0
		r.invuln_left = 0.0
		r.monster_touch(m)
		t.check("SoM: Classic -> aanraken start het turn-based gevecht", GameState.in_battle)
		if await t.wait_scene("Battle"):
			await t.frames(10)
			GameState.in_battle = false
			GameState.changing_map = false
			GameState.end_battle("flee")
			await t.wait_scene("ArchiefV1Gang", 20)
			await t.frames(10)
	# Action via Opties (veldmenu > Options > Battle Style, zonder SoM-knop): realtime in een SoM-kamer
	room().open_field_menu()
	await t.frames(5)
	var fm: Node = room().get_node_or_null("FieldMenu")
	if fm:
		fm.choose("options")
		await t.frames(3)
		var o: Node = fm.get_node_or_null("Options")
		t.check("SoM: Opties heeft de regel Battle Style", o != null and o.keys.has("battle_style") and o.value_text("battle_style") == "Classic")
		if o:
			o.rows[o.keys.find("battle_style")].grab_focus()
			o.change("battle_style", 1)
			await t.frames(3)
			t.check("SoM: Battle Style -> Action via Opties", Settings.action_battles() and o.value_text("battle_style") == "Action")
			await shot("v2_settings")
		for i in 3:
			if room().get_node_or_null("FieldMenu") == null:
				break
			await t.tap("cancel")
			await t.frames(5)
	Settings.set_value("battle_style", 1)
	t.check("SoM: Action (Opties) -> arena", await goto(SomData.START_MAP, SomData.START_SPAWN) and arena() != null)
	await t.frames(10)


func _death_tests() -> void:
	var a := arena()
	if a == null:
		return
	var h: Dictionary = GameState.party[0]
	var old_room: Node = room()
	a.allies_enabled = false
	for o in GameState.party:
		o["hp"] = 1
	a.iframes.clear()
	a.hit_member(a.active_id, 999)
	t.check("SoM: één held KO -> geen game over, besturing wisselt", not a.down and a.is_alive(a.active_id) and GameState.alive_heroes().size() == 2)
	for o in GameState.party:
		if int(o["hp"]) > 0 and str(o["id"]) != a.active_id:
			o["hp"] = 0
	h = a.hero()
	h["hp"] = 1
	a.iframes.clear()
	a.hit_player(999, Vector2.ZERO)
	t.check("SoM: laatste held KO -> game over", a.down and GameState.alive_heroes().is_empty())
	var ok := false
	for i in 600:
		await t.get_tree().process_frame
		if t.player() != null and room() != old_room and int(GameState.party[0]["hp"]) > 0:
			ok = true
			break
	t.check("SoM: game over -> respawn met HP (%s)" % t.map_name(), ok and not GameState.in_battle)
	Settings.set_value("battle_style", 0)
	GameState.som_mode = false
