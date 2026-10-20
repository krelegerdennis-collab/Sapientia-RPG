extends RefCounted
## SoM-proef (realtime gevecht, scripts/som/): tests binnen --autotest (scripts/debug_autotest.gd).
## t = de autotest-node (check/frames/wait_scene/...). Screenshots alleen met --som-shots=<map>.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")

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
	arena().allies_enabled = true
	await _ally_tests()
	await _switch_tests()
	await _boss_handoff_tests()
	await _style_path_tests()
	await _death_tests()


func _settings_tests() -> void:
	t.check("SoM: Battle Style standaard Classic", int(Settings.DEFAULTS["battle_style"]) == 0 and not Settings.action_battles())
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
	await seconds(SomData.CHARGE_TIME + 0.1)
	t.check("SoM: meter vult in ~%.1f s" % SomData.CHARGE_TIME, a.charge >= 1.0 and is_equal_approx(SomData.CHARGE_TIME, 0.5))
	a.attack()
	await seconds(0.25)
	t.check("SoM: na 0,25 s nog niet vol (%.2f)" % a.charge, a.charge < 1.0 and a.charge > 0.2)
	await seconds(0.3)
	t.check("SoM: na 0,55 s vol", a.charge >= 1.0)
	# verslaan: EXP/goud/buit
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
	t.check("SoM: skills-ring = spreuken van de bestuurde held", a.ring.entries.size() == (a.hero().get("spells", []) as Array).size())
	await shot("v2_ring_skills")
	a.ring.close({})
	t.check("SoM: sluiten zonder keuze hervat", not t.get_tree().paused)
	await t.frames(5)


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
	await seconds(0.3)
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
	t.check("SoM-wissel: Dax wordt AI op de oude plek", _ally("dennis") != null and _ally("dennis").position.distance_to(dax_pos) < 8.0)
	var spr: Sprite2D = p.get_node("Sprite2D")
	t.check("SoM-wissel: speler-sprite = Seren", spr.texture == a.sheet_for("lotte"))
	t.check("SoM-wissel: ring toont Serens spreuken", a.ring_entries()["skills"].any(func(e): return e["caster"] == "lotte"))
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
