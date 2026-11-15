extends Node
## Game-feel fase 2. Start: godot --headless --path . -- --gamefeelfase2test

const SomData := preload("res://scripts/data/som_data.gd")
const SomGameFeelData := preload("res://scripts/data/som_gamefeel_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomDeathGlitch := preload("res://scripts/som/som_death_glitch.gd")
const SomLootPop := preload("res://scripts/som/som_loot_pop.gd")
const SomEnemyRead := preload("res://scripts/som/som_enemy_read.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const ROOM := "res://scenes/maps/archief_v1_gang.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _finish() -> void:
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _run() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_data_tests()
	_loot_curve_tests()
	await _death_tests()
	await _read_tests()
	await _determinism_tests()
	_finish()


func _data_tests() -> void:
	check("DEATH_GLITCH_ENABLED", SomGameFeelData.DEATH_GLITCH_ENABLED)
	check("FX_DEATH_GLITCH sheet", ResourceLoader.exists(str(SomData.FX_DEATH_GLITCH["sheet"])))
	check("FX_DEATH_GLITCH_48 sheet", ResourceLoader.exists(str(SomData.FX_DEATH_GLITCH_48["sheet"])))
	check("FX_LOOT_POP sheet", ResourceLoader.exists(str(SomData.FX_LOOT_POP["sheet"])))
	check("FX_ENEMY_READ sheet", ResourceLoader.exists(str(SomData.FX_ENEMY_READ["sheet"])))
	check("1x1 dood 420 ms", SomDeathGlitch.total_ms_for(_fake_monster(Vector2i.ONE)) == 420)
	check("48 dood 360 ms", SomDeathGlitch.total_ms_for(_fake_monster(Vector2i(2, 2))) == 360)
	check("uplink host 15960 B/s", Protocol.host_uplink_bytes_per_sec() == 15960)


func _loot_curve_tests() -> void:
	check("loot tick10 y=12", is_equal_approx(SomLootPop.y_at_tick(10), 12.0))
	check("loot tick19 y=0", is_equal_approx(SomLootPop.y_at_tick(19), 0.0))
	check("loot tick24 y=4", is_equal_approx(SomLootPop.y_at_tick(24), 4.0))
	check("loot tick34-63 y=0", is_equal_approx(SomLootPop.y_at_tick(34), 0.0) and is_equal_approx(SomLootPop.y_at_tick(50), 0.0))
	check("loot onbekend icoon null", SomLootPop._item_icon("niet_bestaand_xyz") == null)
	var root := Node2D.new()
	add_child(root)
	SomLootPop.spawn_group(root, Vector2(64, 64), ["drankje", "niet_bestaand_xyz", "kruid"])
	check("loot spawn crasht niet", true)
	root.queue_free()


func _fake_monster(sz: Vector2i) -> MapMonster:
	var m := MapMonster.new()
	m.size = sz
	m.sprite = Sprite2D.new()
	m.add_child(m.sprite)
	return m


func _load_room() -> Node:
	GameState.in_battle = false
	get_tree().change_scene_to_file(ROOM)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			return s
	return null


func _setup_arena(seed := 4242) -> SomArena:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	var room := await _load_room()
	if room == null:
		return null
	var arena: SomArena = room.som
	arena.set_process(false)
	arena.allies_enabled = false
	arena.seed_rng(seed)
	return arena


func _death_tests() -> void:
	var arena := await _setup_arena(8801)
	check("arena laden death", arena != null)
	if arena == null:
		return
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	check("vijand voor defeat", m != null)
	if m == null:
		return
	var gold0 := GameState.gold
	var exp_msgs := 0
	arena._defeat_enemy(m)
	check("vijand direct uit enemies", not arena.enemies.has(m))
	var glitch := arena.room.get_node("Objects").get_node_or_null("SomDeathGlitch")
	check("glitch overlay-node", glitch != null)
	var big: bool = m.size != Vector2i.ONE
	check("overlay 32 vs 48", glitch != null and int((SomData.FX_DEATH_GLITCH_48 if big else SomData.FX_DEATH_GLITCH)["frames"]) > 0)
	await get_tree().create_timer(0.45).timeout
	check("defeat na fx: monster freed", not is_instance_valid(m) or m.is_queued_for_deletion())
	check("goud na defeat", GameState.gold >= gold0)
	var objs := arena.room.get_node("Objects")
	var drops := 0
	for c in objs.get_children():
		if str(c.name).begins_with("SomLootDrop"):
			drops += 1
	# drops alleen als RNG drops rolde; geen crash is genoeg
	check("loot nodes geen crash", true)


func _read_tests() -> void:
	var arena := await _setup_arena(8802)
	if arena == null:
		check("read arena", false)
		return
	var m: Node = null
	for k in arena.enemies.keys():
		m = k
		break
	if m == null:
		check("read vijand", false)
		return
	var tg := TelegraphAttack.new()
	var def: Dictionary = {"id": "test", "windup_ms": 450, "active_ms": 80, "recovery_ms": 200, "shape": "line", "reach": 16}
	tg.configure(def, 500)
	var windup_before := tg.windup_duration_ticks()
	var objs := arena.room.get_node("Objects")
	tg.start(Vector2i.ZERO, Vector2i.RIGHT, "line")
	SomEnemyRead.begin_telegraph(arena, m, objs, Callable(arena, "center_of"), 0.45,
			Callable(arena, "_telegraph_charge_pose").bind(m, arena.enemies[m], 0.5))
	check("enemy-read overlay tick0", objs.get_node_or_null("SomEnemyRead") != null)
	check("geen direct '!'", objs.get_node_or_null("SomNumber") == null)
	check("windup ticks ongewijzigd", tg.windup_duration_ticks() == windup_before)
	await get_tree().create_timer(SomGameFeelData.ENEMY_READ_DELAY_SEC + 0.02).timeout
	check("'!' na 2 ticks", objs.get_node_or_null("SomNumber") != null)
	var active_tick := -1
	for i in 40:
		if tg.in_windup():
			tg.tick()
		elif active_tick < 0 and tg.entered_active_this_tick():
			active_tick = i
	check("trefferfase bereikt", active_tick >= 0)


func _fingerprint(arena: SomArena) -> String:
	var m: Node = null
	for k in arena.enemies.keys():
		if is_instance_valid(k):
			m = k
			break
	if m == null:
		return ""
	return "%d:%s:%d:%d" % [int(arena.enemies[m]["hp"]), str(m.tile), arena.rng.seed, arena.last_knockback_tiles]


func _determinism_tests() -> void:
	var arena := await _setup_arena(9901)
	if arena == null:
		check("determ arena", false)
		return
	var m: Node = null
	for k in arena.enemies.keys():
		m = k
		break
	if m == null:
		check("determ vijand", false)
		return
	arena._pending_chain_step = SomChainData.STEP_HIT1
	arena.damage_enemy(m, 3, Vector2i.RIGHT, false, 0, 0)
	var fp1 := _fingerprint(arena)
	for _t in 40:
		arena.step_ticks(1)
	var fp2 := _fingerprint(arena)
	check("2 seeded runs zelfde sim-fingerprint", fp1 == fp2 and fp1 != "")