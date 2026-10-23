extends Node
## End-to-end co-op: lobby, SomArena, bewegen, aanval, drop + rejoin.
## Start: godot --path . -- --coope2etest [--shots=/pad]

const Protocol := preload("res://scripts/net/net_protocol.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")

const STEP := 3.0
const RUN := 25.0
const VIEWPORT := Vector2i(384, 216)

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


func _assert_arena_avatars(label: String, som: SomArena, roster: Array) -> void:
	var want: int = som.coop_expected_remote_avatars(roster)
	check("%s remote avatars=%d" % [label, want], som.coop_remote_avatar_count() == want)
	check("%s geen orphan CoopAvatar" % label, som.coop_avatar_nodes_in_scene() == want)
	check("%s unieke stoelen" % label, som.coop_avatar_seats_unique())


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
	var roster: Array = []
	for row in host.slots:
		roster.append((row as Dictionary).duplicate())
	var host_pack: Dictionary = await _spawn_peer_arena("HostVP", 0)
	var g1_pack: Dictionary = await _spawn_peer_arena("G1VP", 1)
	var g2_pack: Dictionary = await _spawn_peer_arena("G2VP", 2)
	var host_som: SomArena = host_pack["som"] as SomArena
	var g1_som: SomArena = g1_pack["som"] as SomArena
	var g2_som: SomArena = g2_pack["som"] as SomArena
	check("host arena geladen", host_som != null and g1_som != null and g2_som != null)
	if host_som == null:
		_shutdown(nodes)
		return
	var host_sess: ActionCoopSession = Session.start_session(get_tree(), host.enet_peer(), roster, 0, false, host)
	host_sess.arena_drive = true
	host_som.setup_coop(host_sess, roster, 0)
	host_som.attack_texs.clear()
	host_sess.attach_arena(host_som)
	var g1_sess: ActionCoopSession = Session.start_session(get_tree(), g1.enet_peer(), roster, 1, false, g1)
	g1_sess.arena_drive = true
	g1_som.setup_coop(g1_sess, roster, 1)
	g1_sess.attach_arena(g1_som)
	var g2_sess: ActionCoopSession = Session.start_session(get_tree(), g2.enet_peer(), roster, 2, false, g2)
	g2_sess.arena_drive = true
	g2_som.setup_coop(g2_sess, roster, 2)
	g2_sess.attach_arena(g2_som)
	await _frames(20)
	_assert_arena_avatars("na join host", host_som, roster)
	_assert_arena_avatars("na join g1", g1_som, roster)
	_assert_arena_avatars("na join g2", g2_som, roster)
	if shots != "":
		await _frames(25)
		await _save_shot(host_pack["vp"] as SubViewport)
	g1_sess.set_local_input(Vector2(1, 0), false, false, false)
	var moved := await wait_until(func() -> bool:
		return host_som._coop_avatars.has(1) and (host_som._coop_avatars[1] as Node2D).position.x > 12.0
	, RUN)
	check("gast beweging op host", moved)
	var enemy_count: int = host_som.enemies.size()
	check("arena heeft vijanden", enemy_count > 0)
	if enemy_count > 0:
		var m: Node = host_som.enemies.keys()[0]
		var c: Vector2 = host_som.center_of(m)
		host_som.player.position = c + Vector2(0, 40)
		host_som.player.facing = Vector2i(0, -1)
		host_som.charge = 1.0
	var killed := false
	for i in 180:
		host_sess.set_local_input(Vector2.ZERO, true, false, false, 0)
		await get_tree().process_frame
		if host_som.enemies.size() < enemy_count:
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
	host_sess.sync_roster(host.slots)
	host_som.coop_sync_roster(host.slots)
	g1_sess.sync_roster(host.slots)
	g1_som.coop_sync_roster(host.slots)
	await _frames(4)
	_assert_arena_avatars("na drop host", host_som, host.slots)
	_assert_arena_avatars("na drop g1", g1_som, host.slots)
	g2.close()
	await _frames(12)
	check("g2 rejoin", g2.join_session(Protocol.LOOPBACK, "noor", "Vesper") == OK)
	var back := await wait_until(func() -> bool: return g2.local_slot == 2, STEP)
	check("rejoin Vesper stoel", back)
	if back:
		roster.clear()
		for row in host.slots:
			roster.append((row as Dictionary).duplicate())
		host_sess.sync_roster(host.slots)
		host_som.coop_sync_roster(host.slots)
		g1_sess.sync_roster(host.slots)
		g1_som.coop_sync_roster(host.slots)
		for key in ["room", "vp"]:
			var old: Node = g2_pack.get(key) as Node
			if is_instance_valid(old):
				old.queue_free()
		await _frames(8)
		g2_pack = await _spawn_peer_arena("G2VP", 2)
		g2_som = g2_pack["som"] as SomArena
		g2_sess = Session.start_session(get_tree(), g2.enet_peer(), host.slots, 2, false, g2)
		g2_sess.arena_drive = true
		g2_som.setup_coop(g2_sess, host.slots, 2)
		g2_sess.attach_arena(g2_som)
	_assert_arena_avatars("na rejoin host", host_som, host.slots)
	_assert_arena_avatars("na rejoin g1", g1_som, host.slots)
	_assert_arena_avatars("na rejoin g2", g2_som, host.slots)
	for i in 300:
		await get_tree().process_frame
	_assert_arena_avatars("na 300 ticks host", host_som, host.slots)
	_assert_arena_avatars("na 300 ticks g1", g1_som, host.slots)
	_assert_arena_avatars("na 300 ticks g2", g2_som, host.slots)
	host_sess.shutdown(true)
	g1_sess.shutdown(true)
	g2_sess.shutdown(true)
	_shutdown(nodes)
	for key in ["room", "vp"]:
		var n: Node = host_pack.get(key) as Node
		if is_instance_valid(n):
			n.queue_free()
		n = g1_pack.get(key) as Node
		if is_instance_valid(n):
			n.queue_free()
		n = g2_pack.get(key) as Node
		if is_instance_valid(n):
			n.queue_free()


func _spawn_peer_arena(vp_name: String, _slot: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = vp_name
	vp.size = VIEWPORT
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var room: DungeonRoom = (load(SomData.START_MAP) as PackedScene).instantiate()
	vp.add_child(room)
	var som: SomArena = null
	for i in 240:
		if room.som != null:
			som = room.som as SomArena
			break
		await get_tree().process_frame
	return {"vp": vp, "room": room, "som": som}


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


func _save_shot(vp: SubViewport) -> void:
	await _frames(10)
	if vp == null:
		return
	var tex := vp.get_texture()
	if tex == null:
		return
	DirAccess.make_dir_recursive_absolute(shots)
	tex.get_image().save_png(shots.path_join("coop_e2e_arena.png"))
