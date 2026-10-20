extends RefCounted
## SoM-proef (realtime gevecht, scripts/som/): tests binnen --autotest (scripts/debug_autotest.gd).
## t = de autotest-node (check/frames/wait_scene/...). Screenshots alleen met --som-shots=<map>.

const SomData := preload("res://scripts/data/som_data.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")

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
	await _charge_and_attack_tests()
	await _enemy_ai_tests()
	await _ring_tests()
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
	await shot("som_0_title")
	if b == null:
		return
	b.pressed.emit()
	t.check("SoM: knop laadt de proefkerker", await t.wait_scene("ArchiefV1Gang"))
	await t.frames(30)
	t.check("SoM: som_mode aan + arena in de kamer", GameState.som_mode and arena() != null)
	t.check("SoM: standaard-party Dax + Vesper + Seren", GameState.party.size() == 3 and str(GameState.party[0]["name"]) == "Dax")
	t.check("SoM: startitems (Potion x%d)" % GameState.item_count("drankje"), GameState.item_count("drankje") == int(SomData.START_ITEMS["drankje"]))
	t.check("SoM: zichtbare vijanden geregistreerd (%d)" % (arena().enemies.size() if arena() else 0), arena() != null and arena().enemies.size() >= 3)
	t.check("SoM: eigen save-pad", GameState.save_path == SomData.SAVE_PATH)


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
	var hits: int = a.attack()
	t.check("SoM: slag raakt de vijand voor je (%d)" % hits, hits >= 1 and int(e["hp"]) < hp0 or not a.enemies.has(m))
	var full: int = a.last_enemy_damage
	t.check("SoM: meter na de slag op 0", a.charge < 0.05)
	t.check("SoM: schadegetal in beeld", room().get_node("Objects").find_children("SomNumber*", "Label", false, false).size() > 0)
	await shot("som_1_hit")
	await t.pframes(6)
	await shot("som_2_charge")
	# lage lading: gemiddeld minder schade (atk/def uit de data; zelfde formule)
	var atk := float(GameState.effective_stat(GameState.party[0], "atk"))
	var low := 0
	var high := 0
	for i in 40:
		low += SomArena.physical_damage(atk, float(e["def"]), SomArena.charge_mult(0.0))
		high += SomArena.physical_damage(atk, float(e["def"]), 1.0)
	t.check("SoM: slag <100%% doet minder schade (%d < %d)" % [low, high], low < high and full >= 1)
	await seconds(SomData.CHARGE_TIME + 0.1)
	t.check("SoM: meter vult in ~1 s", a.charge >= 1.0)
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
	a.attack()
	t.check("SoM: vijand verslagen -> EXP (%d -> %d) en goud" % [exp0, int(GameState.party[0]["exp"])],
			int(GameState.party[0]["exp"]) > exp0 and GameState.gold >= gold0)
	t.check("SoM: verslagen monster weg uit de kamer en onthouden", not room().monsters.has(m)
			and GameState.defeated_map_monsters.get(room().room_id, {}).has(mid))
	t.check("SoM: bestiarium telt mee", GameState.defeated_count(eid) >= 1)
	await seconds(0.5)


func _enemy_ai_tests() -> void:
	var a := arena()
	var m := _first_enemy()
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	a.iframes = 0.0
	room().invuln_left = 0.0
	face_monster(m)
	var hp0 := int(GameState.party[0]["hp"])
	var saw_tele := false
	var frames := 0
	while frames < 240 and int(GameState.party[0]["hp"]) == hp0:
		await t.get_tree().process_frame
		frames += 1
		if a.enemies.has(m) and float(a.enemies[m]["tele"]) > 0.0:
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
	await gif_frames("fight", 1, 1)


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
	await shot("som_3_ring")
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
	t.check("SoM: skills-ring met spreuken van de party", a.ring.entries.size() >= 1)
	await shot("som_4_ring_skills")
	a.ring.close({})
	t.check("SoM: sluiten zonder keuze hervat", not t.get_tree().paused)
	await t.frames(5)


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
	# Action via Opties (zonder SoM-knop): realtime in een SoM-kamer
	Settings.set_value("battle_style", 1)
	t.check("SoM: Action (Opties) -> arena", await goto(SomData.START_MAP, SomData.START_SPAWN) and arena() != null)
	await t.frames(10)


func _death_tests() -> void:
	var a := arena()
	if a == null:
		return
	var h: Dictionary = GameState.party[0]
	var old_room: Node = room()
	h["hp"] = 1
	a.iframes = 0.0
	a.hit_player(999, Vector2.ZERO)
	t.check("SoM: Dax valt bij 0 HP", a.down and int(h["hp"]) == 0)
	var ok := false
	for i in 600:
		await t.get_tree().process_frame
		if t.player() != null and room() != old_room and int(GameState.party[0]["hp"]) > 0:
			ok = true
			break
	t.check("SoM: game over -> respawn met HP (%s)" % t.map_name(), ok and not GameState.in_battle)
	Settings.set_value("battle_style", 0)
	GameState.som_mode = false
