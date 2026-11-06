extends Node
## Golem zichtbare telegraaf = exacte strike-cirkel + hit-flash. Start:
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --golemzichtbaartest --shots=/workspace/golem_fix
## Of headless (geen echte viewport-shots). Schade alleen via _golem_strike.

const SomArena := preload("res://scripts/som/som_arena.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const StoryData := preload("res://scripts/data/story_data.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const ROOM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const OTHER_SCENE := "res://scenes/maps/archief_v1_gang.tscn"

## Alle schadelijke Golem-aanval-ids (GolemBoss.ATTACKS).
const ALL_ATTACK_IDS := [
	"golem_sweep", "golem_sweep_p2", "golem_book_hammer", "golem_book_hammer_x2",
	"golem_shockwave", "golem_hammer_blow", "golem_hammer_blow_p3",
]

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
	print("=== Golem zichtbare aanval v2 (cirkel-hitzone) ===")
	_wm1_first_boss_evidence()
	var saved_rt := SomArena.golem_rt_enabled
	SomArena.golem_rt_enabled = true
	await _suite()
	SomArena.golem_rt_enabled = saved_rt
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _wm1_first_boss_evidence() -> void:
	# Route: DungeonRooms.ORDER eindigt met archief_golemhal als enige baaskamer van Archief 1.
	var order_ids: Array = []
	for e in DungeonRooms.ORDER:
		order_ids.append(str(e[0]))
	check("WM1 ORDER bevat archief_golemhal (dungeon_rooms.gd:775)", order_ids.has("archief_golemhal"))
	var idx := order_ids.find("archief_golemhal")
	var earlier_boss := false
	for i in idx:
		var rid := str(order_ids[i])
		if rid == "":
			continue
		var room: Dictionary = DungeonRooms.ROOMS.get(rid, {})
		for m in room.get("monsters", []):
			if bool(m.get("boss", false)):
				earlier_boss = true
	check("WM1: geen baas vóór archief_golemhal in ORDER", not earlier_boss and idx >= 0)
	check("WM1: enige Action-RT baaskamer = archief_golemhal (som_arena GOLEM_RT_ROOMS)",
			SomArena.GOLEM_RT_ROOMS == ["archief_golemhal"])
	check("WM1 story: GOLEM_FLAG = bewaker:archief_golemhal/golem (story_data.gd:70)",
			StoryData.GOLEM_FLAG == "bewaker:archief_golemhal/golem")
	var monsters: Array = DungeonRooms.ROOMS["archief_golemhal"].get("monsters", [])
	check("WM1: golemhal spawnt kennis_beest boss",
			monsters.any(func(m): return str(m.get("enemy", "")) == "kennis_beest" and bool(m.get("boss", false))))


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


func _wait_idle(a: Node, f: GolemFight, max_ticks := 1200) -> bool:
	var g := 0
	while g < max_ticks:
		if f.is_invulnerable():
			a.step_ticks(1)
			g += 1
			continue
		if f.step == GolemFight.Step.IDLE and not f.core.open:
			return true
		# forced mag ook bij core.open; voor idle wachten we tot recovery klaar is
		if f.step == GolemFight.Step.IDLE:
			return true
		a.step_ticks(1)
		g += 1
	return f.step == GolemFight.Step.IDLE


func _force_windup(a: Node, f: GolemFight, attack_id: String, max_ticks := 180) -> bool:
	f.queue_forced_attack(attack_id)
	var g := 0
	while g < max_ticks:
		a.step_ticks(1)
		g += 1
		if f.step == GolemFight.Step.WINDUP and str(f.attack_id) == attack_id:
			return true
	return false


func _strike_hits(origin: Vector2, reach: float, point: Vector2) -> bool:
	return origin.distance_to(point) <= reach


func _tg_hits(tg: TelegraphAttack, point: Vector2) -> bool:
	return tg.hits_point_i(TelegraphShape.to_px(point))


func _assert_circle_matches_strike(a: Node, m: Node, e: Dictionary, label: String) -> void:
	var tg: TelegraphAttack = e["tg"]
	var origin: Vector2 = e.get("golem_origin", a.center_of(m)) as Vector2
	var reach: float = float(e.get("golem_tg_reach", a._golem_strike_reach_px(m, GolemBoss.attack(str(e.get("golem_attack", ""))))))
	check("%s: tg shape=circle" % label, tg.shape() != null and tg.shape().kind == TelegraphShape.Kind.CIRCLE)
	check("%s: tg.reach == strike-reach (%s)" % [label, str(int(reach))], tg.shape().reach == int(reach))
	# Sample: binnen/grens/buiten — strike en telegraaf moeten overeenstemmen (geen OR-mask).
	# Duidelijk binnen / duidelijk buiten (1.5 px band rond de rand overgeslagen i.v.m. float↔int).
	var samples: Array = [
		origin,
		origin + Vector2(maxi(0.0, reach - 2.0), 0),
		origin + Vector2(0, -maxi(0.0, reach - 2.0)),
		origin + Vector2(reach + 2.0, 0),
		origin + Vector2(0, reach + 2.0),
		origin + Vector2(-(reach + 2.0), 0),
		origin + Vector2(reach * 0.5, reach * 0.5),
	]
	var ok := true
	var checked := 0
	for p in samples:
		var dist := origin.distance_to(p)
		if absf(dist - reach) <= 1.5:
			continue
		checked += 1
		var sh: bool = _strike_hits(origin, reach, p)
		var th: bool = _tg_hits(tg, p)
		if sh != th:
			ok = false
			print("  MISMATCH point=%s dist=%s strike=%s tg=%s reach=%s" % [str(p), str(dist), str(sh), str(th), str(reach)])
	check("%s: samplepunten strike↔telegraaf identiek (n=%d)" % [label, checked], ok and checked >= 4)


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
	check("tg + GolemBossView aanwezig", e.has("tg") and e.has("golem_view"))

	# --- Per aanval-id: cirkel + exact 1 player_hit + HP-verlies in bereik ---
	var shot_windup_done := false
	var shot_strike_done := false
	var b: Node2D = a.player
	var cb_hits := [0]
	var cb := func(_dmg: int) -> void:
		cb_hits[0] = int(cb_hits[0]) + 1

	for attack_id in ALL_ATTACK_IDS:
		check("attack-id bestaat in GolemBoss.ATTACKS: %s" % attack_id, GolemBoss.ATTACKS.has(attack_id))
		if not _wait_idle(a, f):
			check("idle vóór %s" % attack_id, false)
			continue

		# IN BEREIK: speler op golem-centrum vóór windup (aim=target locked origin bij start)
		if b:
			b.position = a.center_of(m)
		for id in a.party_ids():
			a.iframes[id] = 0.0
		if not _force_windup(a, f, attack_id):
			check("windup %s geforceerd" % attack_id, false)
			continue
		# Voor aim=target: blijf op de gelockte origin
		var origin: Vector2 = e.get("golem_origin", a.center_of(m)) as Vector2
		if b:
			b.position = origin
		check("windup %s actief" % attack_id, f.step == GolemFight.Step.WINDUP and e["tg"].in_windup())
		a._sync_telegraph_draw()
		check("TelegraphLayer ≥1 tijdens %s" % attack_id, a.telegraph_layer.entry_count() >= 1)
		_assert_circle_matches_strike(a, m, e, attack_id)

		if shots != "" and not shot_windup_done:
			await _shot_real("windup")
			shot_windup_done = true

		var hp0 := int(GameState.party[0]["hp"])
		var strikes0: int = a.golem_strike_count
		cb_hits[0] = 0
		a.player_hit.connect(cb)
		var g := 0
		while a.golem_strike_count == strikes0 and g < 90:
			if b:
				b.position = e.get("golem_origin", origin)
			for id in a.party_ids():
				a.iframes[id] = 0.0
			a.step_ticks(1)
			g += 1
		var flash: Node = m.get_node_or_null("GolemHitFlashTemp")
		check("hit-flash node tijdens/na strike %s" % attack_id, flash != null and is_instance_valid(flash) and flash.visible)
		if shots != "" and not shot_strike_done:
			await _shot_real("strike")
			shot_strike_done = true
		a.player_hit.disconnect(cb)
		var hp1 := int(GameState.party[0]["hp"])
		check("in bereik %s: precies 1 _golem_strike" % attack_id, a.golem_strike_count == strikes0 + 1)
		check("in bereik %s: EXACT 1 player_hit" % attack_id, int(cb_hits[0]) == 1)
		check("in bereik %s: HP-verlies" % attack_id, hp1 < hp0)
		check("telegraaf weg na strike %s" % attack_id, not e["tg"].is_busy())

		# x2 tweede slag
		if attack_id == "golem_book_hammer_x2" and f.step == GolemFight.Step.WINDUP:
			if b:
				b.position = e.get("golem_origin", origin)
			for id in a.party_ids():
				a.iframes[id] = 0.0
			hp0 = int(GameState.party[0]["hp"])
			strikes0 = a.golem_strike_count
			cb_hits[0] = 0
			a.player_hit.connect(cb)
			g = 0
			while a.golem_strike_count == strikes0 and g < 90:
				a.step_ticks(1)
				g += 1
			a.player_hit.disconnect(cb)
			check("x2 tweede strike: EXACT 1 player_hit + HP-verlies", int(cb_hits[0]) == 1 and int(GameState.party[0]["hp"]) < hp0)

		_wait_idle(a, f)

		# BUITEN BEREIK:
		# - niet-target: speler ver vóór windup (origin = golem)
		# - aim=target: windup lockt origin op speler, daarna weglopen vóór de strike
		var aim_target := str(GolemBoss.attack(attack_id).get("aim", "")) == "target"
		for id in a.party_ids():
			a.iframes[id] = 0.0
		if aim_target:
			if b:
				b.position = a.center_of(m)
			if not _force_windup(a, f, attack_id):
				check("windup (oor) %s" % attack_id, false)
				continue
			var lock_o: Vector2 = e.get("golem_origin", a.center_of(m)) as Vector2
			if b:
				b.position = lock_o + Vector2(500, 500)
		else:
			if b:
				b.position = a.center_of(m) + Vector2(500, 500)
			if not _force_windup(a, f, attack_id):
				check("windup (oor) %s" % attack_id, false)
				continue
			if b:
				b.position = a.center_of(m) + Vector2(500, 500)
		hp0 = int(GameState.party[0]["hp"])
		strikes0 = a.golem_strike_count
		cb_hits[0] = 0
		a.player_hit.connect(cb)
		g = 0
		while a.golem_strike_count < strikes0 + 1 and g < 120:
			if b and aim_target:
				b.position = (e.get("golem_origin", a.center_of(m)) as Vector2) + Vector2(500, 500)
			elif b:
				b.position = a.center_of(m) + Vector2(500, 500)
			a.step_ticks(1)
			g += 1
		g = 0
		while f.step != GolemFight.Step.IDLE and g < 120:
			if b:
				b.position = a.center_of(m) + Vector2(500, 500)
			a.step_ticks(1)
			g += 1
		a.player_hit.disconnect(cb)
		check("buiten bereik %s: 0 player_hit, geen HP-verlies" % attack_id,
				int(cb_hits[0]) == 0 and int(GameState.party[0]["hp"]) == hp0)
		_wait_idle(a, f)

		# DODGE: dichtbij vóór windup, i-frames tijdens hele windup→hit
		if b:
			b.position = a.center_of(m)
		if not _force_windup(a, f, attack_id):
			check("windup (dodge) %s" % attack_id, false)
			continue
		if b:
			b.position = e.get("golem_origin", a.center_of(m))
		hp0 = int(GameState.party[0]["hp"])
		strikes0 = a.golem_strike_count
		cb_hits[0] = 0
		a.player_hit.connect(cb)
		g = 0
		while a.golem_strike_count < strikes0 + 1 and g < 120:
			for id in a.party_ids():
				a.iframes[id] = 5.0
			a.step_ticks(1)
			g += 1
		g = 0
		while f.step != GolemFight.Step.IDLE and g < 120:
			for id in a.party_ids():
				a.iframes[id] = 5.0
			a.step_ticks(1)
			g += 1
		a.player_hit.disconnect(cb)
		check("dodge/i-frames %s: 0 player_hit, geen HP-verlies" % attack_id,
				int(cb_hits[0]) == 0 and int(GameState.party[0]["hp"]) == hp0)
		_wait_idle(a, f)

	# --- Echte interrupt via GolemFight fasewissel (telegraphs_cancelled) ---
	if not _wait_idle(a, f):
		check("idle vóór interrupt", false)
	else:
		# Herstel HP baas genoeg onder fase-0 drempel-ruimte
		# Forceer windup, daarna overkill → fase → cancel
		if _force_windup(a, f, "golem_sweep"):
			check("interrupt: windup + tg actief", e["tg"].in_windup())
			var strikes_before: int = a.golem_strike_count
			var cancels_before := _events_of(a, "telegraphs_cancelled").size()
			# Schade tot fasedrempel → _enter_phase → _cancel_attack
			a.damage_enemy(m, 50000, Vector2i.ZERO)
			a._sync_telegraph_draw()
			var cancels_after := _events_of(a, "telegraphs_cancelled").size()
			check("interrupt: telegraphs_cancelled via GolemFight", cancels_after > cancels_before)
			check("interrupt: telegraaf gewist", not e["tg"].is_busy() and a.telegraph_layer.entry_count() == 0)
			# Geen strike van de geannuleerde windup
			a.step_ticks(5)
			check("interrupt: geen strike van geannuleerde aanval", a.golem_strike_count == strikes_before)
			# Wacht invuln af
			a.step_ticks(BossPhaseMachine.INVULN_TICKS + 2)

	# --- Death wist telegraaf ---
	_reset_golem_presence()
	s = await _laad(ROOM_SCENE)
	a = s.get("som") if s else null
	m = _golem(s) if s else null
	check("herlaad voor death/exit", a != null and m != null)
	if a == null or m == null:
		return
	a.allies_enabled = false
	for h in GameState.party:
		h["hp"] = 99999
		h["max_hp"] = 99999
	e = a.enemies[m]
	f = a.golem_fight_of(m)
	_force_windup(a, f, "golem_sweep")
	check("death-setup: tg actief", e["tg"].in_windup())
	# Versla door fases heen
	var safety := 0
	while a.enemies.has(m) and safety < 200:
		safety += 1
		if f.is_invulnerable():
			a.step_ticks(BossPhaseMachine.INVULN_TICKS)
		a.damage_enemy(m, 50000, Vector2i.ZERO)
	check("death: Golem weg uit arena", not a.enemies.has(m))
	# View/tg op monster: monster wordt gefreed; check dat layer leeg is
	a._sync_telegraph_draw()
	check("death: TelegraphLayer leeg", a.telegraph_layer.entry_count() == 0)

	# --- Arena exit wist telegraaf ---
	_reset_golem_presence()
	s = await _laad(ROOM_SCENE)
	a = s.get("som") if s else null
	m = _golem(s) if s else null
	if a == null or m == null:
		# één retry
		await get_tree().create_timer(0.2).timeout
		s = await _laad(ROOM_SCENE)
		a = s.get("som") if s else null
		m = _golem(s) if s else null
	check("herlaad voor exit", a != null and m != null)
	if a == null or m == null:
		return
	a.allies_enabled = false
	e = a.enemies[m]
	f = a.golem_fight_of(m)
	_force_windup(a, f, "golem_book_hammer")
	check("exit-setup: tg actief", e.has("tg") and e["tg"].in_windup())
	var view_before: Node = e.get("golem_view", null)
	# Verlaat kamer → _exit_tree cleared visuals + unregister
	await _laad(OTHER_SCENE)
	await get_tree().process_frame
	const BossScript := preload("res://scripts/som/boss_script.gd")
	check("exit: BossScript kennis_beest unregistered", not BossScript.has_script(GolemBoss.ENEMY_ID))
	check("exit: oude GolemBossView vrijgegeven of ongeldig",
			view_before == null or not is_instance_valid(view_before))


func _reset_golem_presence() -> void:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.encounter_multiplier = 0.0
	GameState.story_flags.erase(StoryData.GOLEM_FLAG)
	if GameState.defeated_map_monsters.has("archief_golemhal"):
		GameState.defeated_map_monsters["archief_golemhal"].erase("golem")
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)


func _shot_real(name: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	# Laat een paar frames renderen (opengl3/xvfb)
	for i in 4:
		await get_tree().process_frame
	var path := shots.path_join(name + ".png")
	var img: Image = null
	var tex := get_viewport().get_texture()
	if tex != null:
		img = tex.get_image()
	if img == null:
		print("SHOT FAIL (geen viewport-image, draai met xvfb-run --rendering-driver opengl3): ", name)
		return
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
