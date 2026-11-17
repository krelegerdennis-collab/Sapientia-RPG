extends Node
## Klus 6: buit per stoel via het echte lobby-pad (relay, protocol v2).
## 1 host + 2 gasten. Gast: apply_bundle -> opslaan -> pas daarna REWARD_ACK.
## Start: godot --path . -- --liveseatloottest   (start zelf de Node-relay, zoals --protocolv2test)

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Lobby := preload("res://scripts/net/lan_lobby.gd")
const AckScript := preload("res://scripts/net/reward_ack.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const Reward := preload("res://scripts/net/online_reward.gd")

const STEP := 8.0
const RELAY_DIR := "res://relay"
const HOST_PROFILE := {"uid": "a1b2c3d4", "name": "Mira", "class": "priest", "look": {
	"body": 0, "skin": 0, "hair": 1, "hair_color": 1, "top": 0, "top_color": 1,
	"bottom": 0, "bottom_color": 2, "head": 0, "class": "priest"}}

var failures := 0
var passes := 0
var _relay_pid := 0
var _port := 0
var _url := ""
var _nodes: Array[Node] = []
var _events: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - before) / 1000.0
	return pred.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	_wis_online()
	if await _start_relay():
		await _flow()
	else:
		check("relay beschikbaar", false)
	_stop_relay()
	_wis_online()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ de flow


func _flow() -> void:
	# Eén apparaat-profiel met twee slots: beide gasten delen het bestand.
	# Zo bewijst de stoelcheck dat een bundle niet op het ándere lokale slot landt.
	var store: OnlineProfile = Profile.new()
	store.load_profile()
	check("slot 0 aangemaakt", bool(store.create_slot(0, "Dex", "warrior").get("ok", false)))
	check("slot 1 aangemaakt", bool(store.create_slot(1, "Nim", "mage").get("ok", false)))
	var u1 := str(store.get_slot(0).get("uid", ""))
	var u2 := str(store.get_slot(1).get("uid", ""))
	check("twee verschillende stoel-uids", u1 != "" and u2 != "" and u1 != u2)

	var host: LanLobby = _lobby("LootHost")
	check("host v2 start", host.host_relay_v2(_url, HOST_PROFILE) == OK)
	var code_ok := await wait_until(func() -> bool: return host.room_code != "", STEP)
	check("kamercode", code_ok)
	if not code_ok:
		return
	var g1: LanLobby = _guest("LootG1", store)
	var g2: LanLobby = _guest("LootG2", store)
	check("gast 1 join", g1.join_relay_v2(_url, host.room_code, _packet(store.get_slot(0))) == OK)
	check("gast 2 join", g2.join_relay_v2(_url, host.room_code, _packet(store.get_slot(1))) == OK)
	var full := await wait_until(func() -> bool:
		return host.player_count() == 3 and g1.phase == LanLobby.Phase.IN and g2.phase == LanLobby.Phase.IN
	, STEP)
	check("drie spelers via de relay", full)
	if not full:
		return

	# 1) Elke stoel krijgt exact zijn eigen buit.
	var k1 := host.send_reward(_peer_of(host, u1), _fields(1, 10, ["cos_ph_easy"]))
	var body1: Dictionary = _first_pending(host, u1)
	var k2 := host.send_reward(_peer_of(host, u2), _fields(1, 3, []))
	var body2: Dictionary = _first_pending(host, u2)
	check("host verstuurt twee bundles", k1 != "" and k2 != "" and not body1.is_empty() and not body2.is_empty())
	var acked := await wait_until(func() -> bool:
		return _pending(host, u1) == 0 and _pending(host, u2) == 0
	, STEP)
	check("beide ACK's binnen bij de host", acked)
	check("gast 1 status applied", _has_event("LootG1", Reward.STATUS_APPLIED, k1))
	check("gast 2 status applied", _has_event("LootG2", Reward.STATUS_APPLIED, k2))
	var disk := _disk()
	check("stoel 1 op schijf: exp 10 + unlock", _exp(disk, 0) == 10 and _unlocks(disk, 0) == ["cos_ph_easy"])
	check("stoel 2 op schijf: exp 3, geen unlock", _exp(disk, 1) == 3 and _unlocks(disk, 1).is_empty())
	check("stoel 1 heeft één grant", _grants(disk, 0).size() == 1)
	check("stoel 2 heeft één grant", _grants(disk, 1).size() == 1)
	check("best_floor blijft staan (niet op de lijn)", _best(disk, 0) == 0 and _best(disk, 1) == 0)

	# 2) Opnieuw versturen (zelfde body) geeft geen dubbele buit, wel een ACK.
	_events.clear()
	host._send_to(_peer_of(host, u1), Protocol.Kind.REWARD_BUNDLE, body1, Protocol.VERSION_ONLINE)
	var dup := await wait_until(func() -> bool: return _has_event("LootG1", Reward.STATUS_DUPLICATE, k1), STEP)
	check("resend: gast 1 duplicate", dup)
	disk = _disk()
	check("resend: stoel 1 nog steeds exp 10, unlock één keer", _exp(disk, 0) == 10 and _unlocks(disk, 0) == ["cos_ph_easy"])
	check("resend: stoel 2 onaangeroerd", _exp(disk, 1) == 3)

	# 3) ACK verloren: de host heeft de bundle nog pending. Gast 2 valt weg,
	#    komt terug (nieuw proces-object, profiel vers van schijf) en krijgt de resend.
	host._rewards._push(u2, body2)
	check("ack-verloren: host heeft de bundle weer pending", _pending(host, u2) == 1)
	g2.close()
	var left := await wait_until(func() -> bool: return host.player_count() == 2, STEP)
	check("ack-verloren: gast 2 weg bij de host", left)
	_events.clear()
	var g2b: LanLobby = _guest("LootG2b", null)
	check("ack-verloren: gast 2 rejoin", g2b.join_relay_v2(_url, host.room_code, _packet(_disk().get_slot(1))) == OK)
	var redone := await wait_until(func() -> bool: return _pending(host, u2) == 0 and g2b.phase == LanLobby.Phase.IN, STEP)
	check("ack-verloren: resend bevestigd, pending leeg", redone)
	check("ack-verloren: status duplicate", _has_event("LootG2b", Reward.STATUS_DUPLICATE, k2))
	disk = _disk()
	check("ack-verloren: stoel 2 nog steeds exp 3", _exp(disk, 1) == 3 and _grants(disk, 1).size() == 1)

	# 4) Bundle voor een andere stoel: geweigerd, geen ACK, niets op schijf.
	_events.clear()
	var foreign: Dictionary = AckScript.new().offer(u2, _fields(2, 50, ["cos_ph_hard"]))
	check("vreemde bundle gebouwd", bool(foreign.get("ok", false)))
	host._send_to(_peer_of(host, u1), Protocol.Kind.REWARD_BUNDLE, foreign.get("body", {}), Protocol.VERSION_ONLINE)
	var rej := await wait_until(func() -> bool: return _has_event("LootG1", Reward.STATUS_REJECTED, ""), STEP)
	check("vreemde stoel: gast 1 rejected", rej)
	check("vreemde stoel: geen ACK", not _has_event("LootG1", Reward.STATUS_APPLIED, "") and not _has_event("LootG1", Reward.STATUS_DUPLICATE, ""))
	disk = _disk()
	check("vreemde stoel: beide stoelen onaangeroerd", _exp(disk, 0) == 10 and _exp(disk, 1) == 3
			and not _unlocks(disk, 1).has("cos_ph_hard") and not _unlocks(disk, 0).has("cos_ph_hard"))

	# 5) Opslaan mislukt in hetzelfde proces: geen ACK. Een resend telt alsnog één keer.
	_events.clear()
	store.load_profile()
	store._beschermd = true
	var k3 := host.send_reward(_peer_of(host, u1), _fields(3, 4, []))
	var failed := await wait_until(func() -> bool: return _has_event("LootG1", "save_failed", k3), STEP)
	check("opslaan mislukt: status save_failed", failed)
	await _frames(20)
	check("opslaan mislukt: host houdt de bundle pending (geen ACK)", _pending(host, u1) == 1)
	check("opslaan mislukt: schijf onaangeroerd", _exp(_disk(), 0) == 10)
	store._beschermd = false
	_events.clear()
	host._send_to(_peer_of(host, u1), Protocol.Kind.REWARD_BUNDLE, _first_pending(host, u1), Protocol.VERSION_ONLINE)
	var later := await wait_until(func() -> bool: return _pending(host, u1) == 0, STEP)
	check("opslaan mislukt: resend daarna applied + ACK", later and _has_event("LootG1", Reward.STATUS_APPLIED, k3))
	check("opslaan mislukt: exp precies één keer erbij (14)", _exp(_disk(), 0) == 14)

	# 6) App gekilld vóór opslaan: apply gebeurde, schrijven niet, geen ACK.
	#    Herstart = nieuw lobby-object + profiel vers van schijf. Precies één keer buit.
	_events.clear()
	store.load_profile()
	store._beschermd = true
	var k4 := host.send_reward(_peer_of(host, u1), _fields(4, 7, ["cos_ph_normal"]))
	var died := await wait_until(func() -> bool: return _has_event("LootG1", "save_failed", k4), STEP)
	check("kill: bundle kwam aan, niet opgeslagen", died)
	g1.close()
	_nodes.erase(g1)
	g1.queue_free()
	store = null
	var gone := await wait_until(func() -> bool: return host.player_count() == 2, STEP)
	check("kill: gast 1 weg bij de host", gone)
	check("kill: host houdt de bundle pending", _pending(host, u1) == 1)
	check("kill: schijf nog exp 14", _exp(_disk(), 0) == 14)
	_events.clear()
	var fresh: OnlineProfile = Profile.new()
	fresh.load_profile()
	var g1b: LanLobby = _guest("LootG1b", fresh)
	check("kill: herstart + rejoin", g1b.join_relay_v2(_url, host.room_code, _packet(fresh.get_slot(0))) == OK)
	var back := await wait_until(func() -> bool: return _pending(host, u1) == 0 and g1b.phase == LanLobby.Phase.IN, STEP)
	check("kill: resend bij rejoin bevestigd", back and _has_event("LootG1b", Reward.STATUS_APPLIED, k4))
	disk = _disk()
	check("kill: exp precies één keer erbij (21)", _exp(disk, 0) == 21)
	check("kill: unlock precies één keer", _unlocks(disk, 0).count("cos_ph_normal") == 1)
	check("kill: stoel 2 onaangeroerd", _exp(disk, 1) == 3)
	var again: Dictionary = AckScript.new().offer(u1, _fields(4, 7, ["cos_ph_normal"])).get("body", {})
	_events.clear()
	host._send_to(_peer_of(host, u1), Protocol.Kind.REWARD_BUNDLE, again, Protocol.VERSION_ONLINE)
	var dup2 := await wait_until(func() -> bool: return _has_event("LootG1b", Reward.STATUS_DUPLICATE, ""), STEP)
	check("kill: nog een resend (andere draad-sleutel) is duplicate", dup2 and _exp(_disk(), 0) == 21)
	g1b.close()
	g2b.close()
	host.close()


# ------------------------------------------------------------------ hulp


func _guest(node_name: String, store: OnlineProfile) -> LanLobby:
	var lobby := _lobby(node_name)
	lobby.profile_store = store
	lobby.reward_handled.connect(func(status: String, key: String) -> void:
		_events.append([node_name, status, key]))
	return lobby


func _has_event(who: String, status: String, key: String) -> bool:
	for e in _events:
		if e[0] == who and e[1] == status and (key == "" or e[2] == key):
			return true
	return false


func _fields(tick: int, exp: int, unlocks: Array) -> Dictionary:
	return {"session_id": 77, "host_tick": tick, "profile_exp": exp, "unlocks": unlocks}


func _peer_of(host: LanLobby, uid: String) -> int:
	for row in host.slots:
		if str(row.get("uid", "")) == uid:
			return int(row.get("peer_id", 0))
	return 0


func _pending(host: LanLobby, uid: String) -> int:
	return host._rewards.unacked(uid).size() if host._rewards != null else -1


func _first_pending(host: LanLobby, uid: String) -> Dictionary:
	var rows := host._rewards.unacked(uid) if host._rewards != null else []
	return rows[0] if not rows.is_empty() else {}


## Zelfde vorm als OnlineHal._profile_packet.
func _packet(slot: Dictionary) -> Dictionary:
	var class_id := str(slot.get("class", ""))
	var look: Dictionary = (slot.get("look", {}) as Dictionary).duplicate() if slot.get("look", {}) is Dictionary else {}
	look["class"] = class_id
	return {"uid": str(slot.get("uid", "")), "name": str(slot.get("name", "")), "class": class_id, "look": look}


func _disk() -> OnlineProfile:
	var p: OnlineProfile = Profile.new()
	p.load_profile()
	return p


func _exp(p: OnlineProfile, i: int) -> int:
	return int(p.get_slot(i).get("profile_exp", -1))


func _best(p: OnlineProfile, i: int) -> int:
	var seen: Variant = p.get_slot(i).get("stats_seen", {})
	return int((seen as Dictionary).get("best_floor", -1)) if seen is Dictionary else -1


func _unlocks(p: OnlineProfile, i: int) -> Array:
	return (p.get_slot(i).get("unlocks", []) as Array).duplicate()


func _grants(p: OnlineProfile, i: int) -> Array:
	return (p.get_slot(i).get("applied_grants", []) as Array).duplicate()


func _wis_online() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var namen: Array[String] = []
	dir.list_dir_begin()
	var naam := dir.get_next()
	while naam != "":
		if naam.begins_with("online_profile"):
			namen.append(naam)
		naam = dir.get_next()
	dir.list_dir_end()
	for n in namen:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % n))


func _lobby(node_name: String) -> LanLobby:
	var lobby := Lobby.new()
	lobby.name = node_name
	add_child(lobby)
	_nodes.append(lobby)
	return lobby


func _start_relay() -> bool:
	var dir := ProjectSettings.globalize_path(RELAY_DIR)
	var out: Array = []
	var node_ok := OS.execute("node", ["--version"], out) == 0
	check("node gevonden", node_ok)
	if not node_ok:
		return false
	if not DirAccess.dir_exists_absolute(dir.path_join("node_modules/ws")):
		var npm_out: Array = []
		var code := OS.execute("npm", ["ci", "--prefix", dir, "--no-audit", "--no-fund", "--silent"], npm_out, true)
		check("npm ci in relay/", code == 0)
		if code != 0:
			return false
	_port = _free_port()
	check("vrije poort", _port > 0)
	if _port == 0:
		return false
	OS.set_environment("RELAY_QUIET", "1")
	_relay_pid = OS.create_process("node", [dir.path_join("server.js"), "--port=%d" % _port])
	check("relay-proces gestart", _relay_pid > 0)
	if _relay_pid <= 0:
		return false
	_url = "ws://127.0.0.1:%d" % _port
	var up := await wait_until(_relay_accepts_tcp, 10.0)
	check("relay luistert", up)
	return up


func _free_port() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6416
	for i in 40:
		var port := rng.randi_range(50000, 58000)
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return 0


func _relay_accepts_tcp() -> bool:
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host("127.0.0.1", _port) != OK:
		return false
	for i in 50:
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTING:
			break
		OS.delay_msec(10)
	var ok := tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED
	tcp.disconnect_from_host()
	return ok


func _stop_relay() -> void:
	for n in _nodes:
		if is_instance_valid(n) and n.has_method("close"):
			n.close()
			n.queue_free()
	_nodes.clear()
	if _relay_pid > 0:
		OS.kill(_relay_pid)
		_relay_pid = 0
