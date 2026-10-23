extends Node
## Headless suite voor de fase-B-lobby. Geen gameplay, geen scène-koppeling.
## Start: godot --path . -- --nettest
## Eén proces: host + gasten op de loopback, elk met een eigen ENet-peer.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const Discovery := preload("res://scripts/net/lan_discovery.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const STEP_SEC := 2.0
const SESSION_SEC := 6.0

var failures := 0
var passes := 0
var _found: Dictionary = {}
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
	_protocol_tests()
	await _session_tests()
	await _discovery_tests()
	await _lifecycle_tests()
	_coop_save_tests()
	await _coop_ui_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func wait_until(pred: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if pred.call():
			return true
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - before) / 1000.0
	return pred.call()


func _protocol_tests() -> void:
	check("klok: sim deelt door snapshots", Protocol.SIM_HZ % Protocol.SNAPSHOT_HZ == 0)
	check("uplink blijft onder 16 KiB/s", Protocol.host_uplink_bytes_per_sec() < 16 * 1024)
	check("input naar de host blijft onder 16 KiB/s", Protocol.host_input_bytes_per_sec() < 16 * 1024)
	var taken: Array = [Protocol.HOST_CHARACTER, "lotte"]
	check("vrije Seren wordt Seren", Protocol.assign_character(taken, "lotte") == "noor")
	check("gevraagde Vesper blijft Vesper", Protocol.assign_character([Protocol.HOST_CHARACTER], "noor") == "noor")
	check("Dax blijft van de host", Protocol.assign_character([Protocol.HOST_CHARACTER], Protocol.HOST_CHARACTER) == "lotte")
	check("volle roster geeft geen held", Protocol.assign_character(Protocol.ROSTER, "kael") == "")
	var used: Array = [Protocol.HOST_SLOT]
	used.append(Protocol.HOST_SLOT + 1)
	used.append(Protocol.HOST_SLOT + 3)
	check("laagste vrije stoel", Protocol.free_slot(used) == Protocol.HOST_SLOT + 2)
	var all_slots: Array = []
	for s in Protocol.MAX_PLAYERS:
		all_slots.append(s)
	check("geen stoel meer", Protocol.free_slot(all_slots) == Protocol.NO_SLOT)
	var hello := Protocol.encode(Protocol.Kind.HELLO, {"character_id": "lotte", "display_name": "Seren"})
	var msg := Protocol.decode(hello)
	check("hello rondt de versie", bool(msg["ok"]) and bool(msg["compatible"]) and int(msg["kind"]) == Protocol.Kind.HELLO)
	var stale := Protocol.encode(Protocol.Kind.HELLO, {"character_id": "lotte", "display_name": "Seren"}, Protocol.VERSION + 1)
	var old := Protocol.decode(stale)
	check("verkeerde versie is leesbaar maar niet compatible", bool(old["ok"]) and not bool(old["compatible"]) and int(old["reason"]) == Protocol.Refuse.VERSION)
	check("rommel is geen pakket", not bool(Protocol.decode("nope".to_utf8_buffer())["ok"]))
	var huge := PackedByteArray()
	huge.resize(Protocol.MAX_PACKET_BYTES + 1)
	check("te groot pakket wordt geweigerd", not bool(Protocol.decode(huge)["ok"]))
	var beacon := Protocol.encode_announce("Dax", 1)
	var info := Protocol.parse_announce(beacon)
	check("baken parst poort, naam en aantal", bool(info["ok"]) and bool(info["compatible"]) and int(info["port"]) == Protocol.ENET_PORT and str(info["name"]) == "Dax" and int(info["players"]) == 1 and int(info["max_players"]) == Protocol.MAX_PLAYERS)
	var other := JSON.stringify({"game": "other", "v": Protocol.VERSION, "kind": Protocol.Kind.ANNOUNCE, "body": {}}).to_utf8_buffer()
	check("ander spel wordt genegeerd", not bool(Protocol.parse_announce(other)["ok"]))
	var no_port := Protocol.encode(Protocol.Kind.ANNOUNCE, {"name": "Dax", "players": 1, "max": Protocol.MAX_PLAYERS})
	check("baken zonder poort is ongeldig", not bool(Protocol.parse_announce(no_port)["ok"]))
	var old_beacon := Protocol.encode(Protocol.Kind.ANNOUNCE, {
		"port": Protocol.ENET_PORT,
		"name": "Dax",
		"players": 1,
		"max": Protocol.MAX_PLAYERS,
	}, Protocol.VERSION + 1)
	var old_info := Protocol.parse_announce(old_beacon)
	check("oud baken parst maar is niet compatible", bool(old_info["ok"]) and not bool(old_info["compatible"]) and int(old_info["port"]) == Protocol.ENET_PORT)
	check("Orion niet in fase-B-roster", not Protocol.ROSTER.has("orion"))
	check("maximaal 3 gasten", Protocol.MAX_REMOTE == 3 and Protocol.MAX_PLAYERS == 4)


func _session_tests() -> void:
	var host: Node = Lobby.new()
	host.name = "NetHost"
	add_child(host)
	var nodes: Array[Node] = [host]
	var err: Error = host.host_session("Dax")
	check("host start", err == OK and host.local_slot == Protocol.HOST_SLOT and host.local_character == Protocol.HOST_CHARACTER)
	if err != OK:
		_shutdown(nodes)
		return
	var bad: Node = _client(nodes, "NetBad")
	err = bad.join_session(Protocol.LOOPBACK, "lotte", "Old", Protocol.VERSION + 1)
	check("verkeerde versie mag verbinden om geweigerd te worden", err == OK)
	var version_refused := await wait_until(func() -> bool:
		return bad.refuse_reason == Protocol.Refuse.VERSION and host.remote_link_count() == 0 and host.player_count() == 1
	, SESSION_SEC)
	check("verkeerde versie krijgt geen stoel", version_refused and bad.local_slot == Protocol.NO_SLOT)
	bad.close()
	var seren: Node = _client(nodes, "NetSeren")
	var vesper: Node = _client(nodes, "NetVesper")
	var kael: Node = _client(nodes, "NetKael")
	check("Seren join", seren.join_session(Protocol.LOOPBACK, "lotte", "Seren") == OK)
	var seren_in := await wait_until(func() -> bool:
		return seren.local_character == "lotte" and seren.local_slot == Protocol.HOST_SLOT + 1
	, STEP_SEC)
	check("Seren krijgt stoel 1 (lotte)", seren_in and seren.local_character == "lotte")
	check("lege stoelen na Seren", host.character_at(Protocol.HOST_SLOT + 2) == "" and host.character_at(Protocol.HOST_SLOT + 3) == "")
	check("Vesper join", vesper.join_session(Protocol.LOOPBACK, "lotte", "Vesper") == OK)
	var vesper_in := await wait_until(func() -> bool:
		return vesper.local_character == "noor" and vesper.local_slot == Protocol.HOST_SLOT + 2
	, STEP_SEC)
	check("Vesper krijgt stoel 2 (noor)", vesper_in and vesper.local_character == "noor")
	check("Kael join", kael.join_session(Protocol.LOOPBACK, "", "Kael") == OK)
	var kael_in := await wait_until(func() -> bool:
		return kael.local_character == "kael" and kael.local_slot == Protocol.HOST_SLOT + 3 and host.player_count() == Protocol.MAX_PLAYERS
	, STEP_SEC)
	check("Kael krijgt stoel 3 (kael)", kael_in and kael.local_character == "kael")
	var roster_seen := await wait_until(func() -> bool:
		return seren.player_count() == Protocol.MAX_PLAYERS and seren.character_at(Protocol.HOST_SLOT) == Protocol.HOST_CHARACTER
	, STEP_SEC)
	check("gast ziet de hele roster", roster_seen and host.character_at(Protocol.HOST_SLOT + 1) == "lotte" and host.character_at(Protocol.HOST_SLOT + 2) == "noor" and host.character_at(Protocol.HOST_SLOT + 3) == "kael")
	var fifth: Node = _client(nodes, "NetFifth")
	check("vijfde probeert", fifth.join_session(Protocol.LOOPBACK, "orion", "Fifth") == OK)
	var fifth_refused := await wait_until(func() -> bool:
		return fifth.refuse_reason == Protocol.Refuse.FULL
	, SESSION_SEC)
	check("4e join geweigerd met party full", fifth_refused and fifth.refuse_reason == Protocol.Refuse.FULL
			and fifth.local_slot == Protocol.NO_SLOT and host.player_count() == Protocol.MAX_PLAYERS
			and str(Protocol.REFUSE_TEXT.get(fifth.refuse_reason, "")) == "The party is full.")
	check("Orion krijgt geen stoel", not host.character_ids().has("orion"))
	fifth.close()
	vesper.close()
	var left := await wait_until(func() -> bool:
		return host.player_count() == Protocol.MAX_PLAYERS - 1 and host.character_at(Protocol.HOST_SLOT + 2) == ""
	, STEP_SEC)
	check("drop: Vesper-stoel meteen vrij", left and host.character_at(Protocol.HOST_SLOT + 3) == "kael")
	check("Vesper opnieuw", vesper.join_session(Protocol.LOOPBACK, "noor", "Vesper") == OK)
	var back := await wait_until(func() -> bool:
		return vesper.local_character == "noor" and vesper.local_slot == Protocol.HOST_SLOT + 2 and host.player_count() == Protocol.MAX_PLAYERS
	, STEP_SEC)
	check("rejoin: laagste vrije stoel + Vesper terug", back and vesper.local_slot == Protocol.HOST_SLOT + 2
			and host.character_at(Protocol.HOST_SLOT + 1) == "lotte" and host.character_at(Protocol.HOST_SLOT + 3) == "kael")
	_shutdown(nodes)


func _discovery_tests() -> void:
	_found = {}
	var listen: Node = Discovery.new()
	listen.name = "NetListen"
	var announce: Node = Discovery.new()
	announce.name = "NetAnnounce"
	add_child(listen)
	add_child(announce)
	listen.host_found.connect(_on_found)
	var err_l: Error = listen.start_listen()
	var err_a: Error = announce.start_announce("Dax", 1)
	check("discovery-sockets", err_l == OK and err_a == OK)
	if err_l == OK and err_a == OK:
		var sent: Error = announce.push_to(Protocol.LOOPBACK, Protocol.DISCOVERY_PORT)
		check("baken naar loopback", sent == OK)
		var heard := await wait_until(func() -> bool:
			return int(_found.get("port", 0)) == Protocol.ENET_PORT
		, STEP_SEC)
		check("luisteraar parst het live baken", heard and str(_found.get("name", "")) == "Dax" and int(_found.get("players", 0)) == 1)
	listen.stop()
	announce.stop()
	listen.queue_free()
	announce.queue_free()


func _client(nodes: Array[Node], node_name: String) -> Node:
	var client: Node = Lobby.new()
	client.name = node_name
	add_child(client)
	nodes.append(client)
	return client


func _on_found(info: Dictionary) -> void:
	_found = info


func _shutdown(nodes: Array[Node]) -> void:
	for n in nodes:
		if is_instance_valid(n) and n.has_method("close"):
			n.close()
			n.queue_free()


func _lifecycle_tests() -> void:
	var host: Node = Lobby.new()
	host.name = "LifeHost"
	add_child(host)
	var guest: Node = _client([host], "LifeGuest")
	check("host voor lifecycle", host.host_session("Dax") == OK)
	check("gast voor lifecycle", guest.join_session(Protocol.LOOPBACK, "lotte", "Seren") == OK)
	var joined := await wait_until(func() -> bool:
		return guest.phase == Lobby.Phase.IN
	, STEP_SEC)
	check("gast in lobby voor start", joined)
	var bag: Dictionary = {"started": false, "ended": false, "reason": ""}
	guest.start_game_received.connect(func() -> void: bag["started"] = true)
	host.host_start_game()
	var got_start := await wait_until(func() -> bool: return bool(bag["started"]), STEP_SEC)
	check("START_GAME bereikt gast", got_start)
	guest.session_ended.connect(func(reason: String) -> void:
		bag["ended"] = true
		bag["reason"] = reason)
	host.broadcast_session_end(Protocol.SESSION_END_HOST_PAUSED)
	var got_end := await wait_until(func() -> bool: return bool(bag["ended"]), STEP_SEC)
	var end_reason := str(bag["reason"])
	check("SESSION_END host pause tekst", got_end and end_reason == Protocol.SESSION_END_HOST_PAUSED
			and GameState.coop_session_end_message(end_reason) == Protocol.SESSION_END_TEXT[Protocol.SESSION_END_HOST_PAUSED])
	_shutdown([host, guest])


func _coop_save_tests() -> void:
	var som_path := SomData.SAVE_PATH
	var som_abs := ProjectSettings.globalize_path(som_path)
	if FileAccess.file_exists(som_path):
		DirAccess.remove_absolute(som_abs)
	GameState.coop_role = "guest"
	check("gast save_game faalt", not GameState.save_game(Vector2i.ZERO, Vector2i.ZERO, som_path))
	check("gast maakt som_save_1 niet", not FileAccess.file_exists(som_path))
	GameState.coop_role = "guest"
	GameState.save_path = som_path
	check("gast default save pad geblokkeerd", not GameState.save_game(Vector2i.ZERO, Vector2i.ZERO))
	check("gast schrijft som_save_1 niet weg", not FileAccess.file_exists(som_path))
	GameState.coop_role = "host"
	GameState.save_path = som_path
	check("host mag wel schrijven", GameState.save_game(Vector2i.ZERO, Vector2i.ZERO))
	if FileAccess.file_exists(som_path):
		DirAccess.remove_absolute(som_abs)
	GameState.coop_role = ""
	GameState.save_path = "user://save_1.json"


func _coop_ui_tests() -> void:  # async via await in body
	check("co-op scène bestaat", ResourceLoader.exists("res://scenes/ui/coop_lobby.tscn"))
	var ui: CoopLobbyScreen = CoopLobbyScreen.new()
	ui.name = "CoopUi"
	add_child(ui)
	await get_tree().process_frame
	check("co-op lobby nodes", ui.lobby != null and ui.discovery != null)
	var min_h := CoopLobbyScreen.touch_min_height_px()
	check("touch min hoogte 48dp (~%d px)" % min_h, min_h >= 16)
	var touch_ok := true
	for btn in ui.all_touch_buttons():
		if btn.custom_minimum_size.y < float(min_h):
			touch_ok = false
	check("co-op knoppen >= 48dp", touch_ok)
	if shots != "":
		await _coop_screenshots(ui)
	ui.queue_free()


func _coop_screenshots(ui: CoopLobbyScreen) -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	await get_tree().process_frame
	await _save_shot(ui, "coop_menu")
	ui._show_host()
	for _i in 3:
		await get_tree().process_frame
	await _save_shot(ui, "coop_host")
	ui._show_join_listen()
	for _i in 3:
		await get_tree().process_frame
	await _save_shot(ui, "coop_join")


func _save_shot(node: Node, name: String) -> void:
	var img: Image = node.get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"))
