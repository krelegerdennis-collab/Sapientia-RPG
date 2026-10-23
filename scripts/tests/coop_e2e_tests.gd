extends Node
## End-to-end co-op: lobby, SomArena, bewegen, aanval, drop + rejoin.
## Start: godot --path . -- --coope2etest [--shots=/pad]

const Protocol := preload("res://scripts/net/net_protocol.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")

const STEP := 3.0
const RUN := 25.0

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func wait_until(pred: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if pred.call():
			return true
		var t0 := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - t0) / 1000.0
	return pred.call()


func _run() -> void:
	await _full_flow()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _full_flow() -> void:
	var host: LanLobby = Lobby.new()
	host.name = "E2EHost"
	add_child(host)
	var nodes: Array[Node] = [host]
	check("host lobby", host.host_session("Dax") == OK)
	var g1: LanLobby = _client(nodes, "E2EG1")
	var g2: LanLobby = _client(nodes, "E2EG2")
	check("g1 join", g1.join_session(Protocol.LOOPBACK, "lotte", "Seren") == OK)
	await wait_until(func() -> bool: return g1.local_slot == 1, STEP)
	check("g2 join", g2.join_session(Protocol.LOOPBACK, "noor", "Vesper") == OK)
	await wait_until(func() -> bool: return g2.local_slot == 2 and host.player_count() == 3, STEP)
	check("START_GAME signaal", true)
	host.host_start_game()
	GameState.coop_register_lobby(host, null)
	GameState.coop_role = "host"
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.call("_build_som_state")
	var room: DungeonRoom = (load(SomData.START_MAP) as PackedScene).instantiate()
	add_child(room)
	var som: Node = null
	for i in 240:
		if room.som != null:
			som = room.som
			break
		await get_tree().process_frame
	check("host arena geladen", som != null)
	if som == null:
		_shutdown(nodes)
		return
	var host_sess: ActionCoopSession = Session.start_session(get_tree(), host.enet_peer(), host.slots, 0, false, host)
	host_sess.arena_drive = true
	som.setup_coop(host_sess, host.slots, 0)
	som.attack_texs.clear()
	host_sess.attach_arena(som)
	var g1_sess: ActionCoopSession = Session.start_session(get_tree(), g1.enet_peer(), host.slots, 1, false, g1)
	g1_sess.arena_drive = true
	var g2_sess: ActionCoopSession = Session.start_session(get_tree(), g2.enet_peer(), host.slots, 2, false, g2)
	g2_sess.arena_drive = true
	await _frames(15)
	await _frames(45)
	g1_sess.set_local_input(Vector2(1, 0), false, false, false)
	var moved := await wait_until(func() -> bool:
		return som._coop_avatars.has(1) and (som._coop_avatars[1] as Node2D).position.x > 12.0
	, RUN)
	check("gast beweging op host", moved)
	var enemy_count: int = som.enemies.size()
	check("arena heeft vijanden", enemy_count > 0)
	if enemy_count > 0:
		var m: Node = som.enemies.keys()[0]
		var c: Vector2 = som.center_of(m)
		som.player.position = c + Vector2(0, 40)
		som.player.facing = Vector2i(0, -1)
		som.charge = 1.0
	var killed := false
	for i in 180:
		host_sess.set_local_input(Vector2.ZERO, true, false, false, 0)
		await get_tree().process_frame
		if som.enemies.size() < enemy_count:
			killed = true
			break
	check("vijand verslagen", killed)
	var rid := 0
	for row in host.slots:
		if int(row.get("slot", -1)) == 2:
			rid = int(row.get("peer_id", 0))
	g2_sess.shutdown(true)
	await _frames(5)
	if rid != 0:
		host.enet_peer().disconnect_peer(rid)
		host_sess.simulate_peer_drop(rid)
		await _frames(10)
	check("stoel 2 vrij na drop", host.character_at(2) == "")
	g2.close()
	await _frames(12)
	check("g2 rejoin", g2.join_session(Protocol.LOOPBACK, "noor", "Vesper") == OK)
	var back := await wait_until(func() -> bool: return g2.local_slot == 2, STEP)
	check("rejoin Vesper stoel", back)
	if back:
		host_sess.sync_roster(host.slots)
		som.coop_sync_roster(host.slots)
	if shots != "":
		await _save_shot()
	host_sess.shutdown(true)
	g1_sess.shutdown(true)
	_shutdown(nodes)
	room.queue_free()


func _client(nodes: Array[Node], n: String) -> LanLobby:
	var c: LanLobby = Lobby.new()
	c.name = n
	add_child(c)
	nodes.append(c)
	return c


func _shutdown(nodes: Array[Node]) -> void:
	for n in nodes:
		if is_instance_valid(n) and n.has_method("close"):
			n.close()
			n.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save_shot() -> void:
	await _frames(10)
	var vp := get_viewport()
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	DirAccess.make_dir_recursive_absolute(shots)
	tex.get_image().save_png(shots.path_join("coop_e2e_arena.png"))
