extends Node
## REWARD_ACK (protocol v2): wachtrij tot ACK, geen dubbele telling, LAN v1 ongemoeid.
## Start: godot --path . -- --rewardacktest

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Ack := preload("res://scripts/net/reward_ack.gd")
const Profile := preload("res://scripts/online/online_profile.gd")

const UID := "a1b2c3d4"
const KEY_A := "g0123456789abcde"
const KEY_B := "gfedcba987654321"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("FAIL  waakhond")
		print("RESULT FAIL (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 20.0)
	var voor := _snap(_story_paths())
	_protocol()
	_queue()
	_client()
	_profile_hook()
	_wis_online()
	var na := _snap(_story_paths())
	check("verhaal- en solo-saves blijven byte-identiek", _zelfde(voor, na))
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _protocol() -> void:
	check("LAN VERSION blijft 1", Protocol.VERSION == 1)
	check("online VERSION blijft 2", Protocol.VERSION_ONLINE == 2)
	check("REWARD_ACK is kind 16", Protocol.Kind.REWARD_ACK == 16 and Codec.KIND_REWARD_ACK == 16)
	check("M1-cap en de wachtrij blijven 8", Profile.MAX_GRANTS == 8 and Ack.MAX_PENDING == 8)
	var plain := Codec.encode_reward_bundle(UID, 7, 120, 15, ["hair_3"])
	var plain_body := Codec.read_reward_bundle(Codec.decode_v2(plain).get("body", {}))
	check("bundle zonder sleutel blijft geldig", bool(plain_body.get("ok", false)) and str(plain_body.get("grant_key", "x")) == ""
			and plain.get_string_from_utf8().find("grant_key") < 0)
	var wired := Codec.encode_reward_bundle(UID, 7, 120, 15, ["hair_3"], KEY_A)
	var wired_msg := Codec.decode_v2(wired)
	var wired_body := Codec.read_reward_bundle(wired_msg.get("body", {}))
	check("bundle met sleutel rondt", wired.size() < 2048 and bool(wired_msg.get("compatible", false))
			and str(wired_body.get("grant_key", "")) == KEY_A and int(wired_body.get("profile_exp", -1)) == 15)
	var ack_raw := Codec.encode_reward_ack(KEY_A)
	var ack_msg := Codec.decode_v2(ack_raw)
	var ack_body := Codec.read_reward_ack(ack_msg.get("body", {}))
	check("REWARD_ACK rondt de sleutel", ack_raw.size() > 0 and ack_raw.size() < 2048
			and int(ack_msg.get("kind", -1)) == Protocol.Kind.REWARD_ACK
			and bool(ack_body.get("ok", false)) and str(ack_body.get("grant_key", "")) == KEY_A)
	check("slechte sleutel wordt niet verstuurd", Codec.encode_reward_ack("grant").is_empty()
			and Codec.encode_reward_ack("G0123456789abcde").is_empty()
			and not Codec.valid_grant_key("g0123456789ABCD"))
	var v1 := Protocol.encode(Protocol.Kind.REWARD_ACK, {"grant_key": KEY_A}, Protocol.VERSION)
	var seen_v1 := Codec.decode_v2(v1)
	check("verkeerde versie krijgt REFUSE VERSION", bool(seen_v1.get("ok", false))
			and not bool(seen_v1.get("compatible", false))
			and int(seen_v1.get("reason", -1)) == Protocol.Refuse.VERSION)
	var v3 := Protocol.encode(Protocol.Kind.REWARD_ACK, {"grant_key": KEY_A}, 3)
	var seen_v3 := Codec.decode_v2(v3)
	check("versie 3 krijgt ook REFUSE VERSION", bool(seen_v3.get("ok", false))
			and not bool(seen_v3.get("compatible", false))
			and int(seen_v3.get("reason", -1)) == Protocol.Refuse.VERSION)
	var hello := Protocol.encode(Protocol.Kind.HELLO, {"character_id": "lotte", "display_name": "Seren"})
	var hello_msg := Protocol.decode(hello)
	var start := Protocol.encode(Protocol.Kind.START_GAME, {})
	var start_msg := Protocol.decode(start)
	check("LAN v1 HELLO en START_GAME blijven compatible", bool(hello_msg.get("compatible", false))
			and int(hello_msg.get("kind", -1)) == Protocol.Kind.HELLO
			and bool(start_msg.get("compatible", false))
			and int(start_msg.get("kind", -1)) == Protocol.Kind.START_GAME)
	var lan_sees := Protocol.decode(ack_raw)
	check("LAN-decode weigert REWARD_ACK v2 met VERSION", bool(lan_sees.get("ok", false))
			and not bool(lan_sees.get("compatible", false))
			and int(lan_sees.get("reason", -1)) == Protocol.Refuse.VERSION)
	var as_v1 := Protocol.decode(v1)
	check("LAN v1 kent REWARD_ACK niet", not bool(as_v1.get("ok", false))
			and not bool(as_v1.get("compatible", false))
			and int(as_v1.get("reason", -1)) == Protocol.Refuse.BAD_PACKET)


func _queue() -> void:
	var host: RewardAck = Ack.new()
	var first: Dictionary = host.offer(UID, _fields(1, 4))
	var second: Dictionary = host.offer(UID, _fields(2, 6))
	check("twee bundles staan open", bool(first.get("ok", false)) and bool(second.get("ok", false))
			and host.unacked(UID).size() == 2)
	var key_1 := str(first.get("grant_key", ""))
	var key_2 := str(second.get("grant_key", ""))
	check("acksleutels hebben de M1-vorm", Codec.valid_grant_key(key_1) and Codec.valid_grant_key(key_2) and key_1 != key_2)
	check("ack haalt één bundle weg", host.ack(UID, key_1) and host.unacked(UID).size() == 1
			and str((host.unacked(UID)[0] as Dictionary).get("grant_key", "")) == key_2)
	check("dezelfde ack nog eens doet niets", not host.ack(UID, key_1) and host.unacked(UID).size() == 1)
	check("een andere uid blijft buiten deze wachtrij", not host.ack("b2c3d4e5", key_2) and host.unacked(UID).size() == 1)
	var again: RewardAck = Ack.new()
	var keys: Array[String] = []
	for i in 3:
		var got: Dictionary = again.offer(UID, _fields(10 + i, 1))
		keys.append(str(got.get("grant_key", "")))
	check("middelste ack laat de andere twee staan", again.ack(UID, keys[1]))
	var resent: Array = again.unacked(UID)
	var resent_keys: Array[String] = []
	for row in resent:
		resent_keys.append(str((row as Dictionary).get("grant_key", "")))
	check("na rejoin gaan alleen onbevestigde bundles opnieuw", resent_keys == [keys[0], keys[2]])
	check("opnieuw sturen wist de wachtrij niet", again.unacked(UID).size() == 2 and again.ack(UID, keys[0]))
	var drop_host: RewardAck = Ack.new()
	var order: Array[String] = []
	var dropped := ""
	for i in 9:
		var got: Dictionary = drop_host.offer(UID, _fields(i, 1))
		order.append(str(got.get("grant_key", "")))
		if str(got.get("dropped", "")) != "":
			dropped = str(got.get("dropped", ""))
	var left: Array[String] = []
	for row in drop_host.unacked(UID):
		left.append(str((row as Dictionary).get("grant_key", "")))
	check("negende onbevestigde laat de oudste vallen", dropped == order[0] and left.size() == 8
			and not left.has(order[0]) and left[0] == order[1] and left[7] == order[8])
	var other: Dictionary = drop_host.offer("b2c3d4e5", _fields(1, 1))
	check("het plafond geldt per uid", bool(other.get("ok", false)) and str(other.get("dropped", "x")) == ""
			and drop_host.unacked("b2c3d4e5").size() == 1 and drop_host.unacked(UID).size() == 8)


func _client() -> void:
	var client: RewardAck = Ack.new()
	client.is_grant_applied = func(_key: String) -> bool: return false
	var body := _wire(UID, 25, KEY_A)
	var first: Dictionary = client.receive(body)
	var second: Dictionary = client.receive(body)
	var ack_msg := Codec.decode_v2(second.get("ack", PackedByteArray()))
	var ack_body := Codec.read_reward_ack(ack_msg.get("body", {}))
	check("eerste bundle telt de exp", bool(first.get("ok", false)) and bool(first.get("applied", false)) and int(first.get("extra", -1)) == 25)
	check("dubbele bundle geeft 0 extra en ACK't nog", bool(second.get("ok", false)) and not bool(second.get("applied", true))
			and int(second.get("extra", -1)) == 0 and not (second.get("ack", PackedByteArray()) as PackedByteArray).is_empty()
			and bool(ack_msg.get("compatible", false)) and str(ack_body.get("grant_key", "")) == KEY_A)
	check("totaal blijft één keer de exp", client.gained_exp == 25)
	var known: RewardAck = Ack.new()
	known.is_grant_applied = func(key: String) -> bool: return key == KEY_B
	var had: Dictionary = known.receive(_wire(UID, 40, KEY_B))
	var had_ack := Codec.read_reward_ack(Codec.decode_v2(had.get("ack", PackedByteArray())).get("body", {}))
	check("hook zegt al toegepast: 0 extra en toch ACK", bool(had.get("ok", false)) and int(had.get("extra", -1)) == 0
			and known.gained_exp == 0 and str(had_ack.get("grant_key", "")) == KEY_B)
	var bare_msg := Codec.decode_v2(Codec.encode_reward_bundle(UID, 1, 1, 5, []))
	var bare: Dictionary = bare_msg.get("body", {})
	var skipped: Dictionary = client.receive(bare)
	check("bundle zonder sleutel telt niet en ACK't niet", not bool(skipped.get("ok", true))
			and int(skipped.get("extra", -1)) == 0 and (skipped.get("ack", PackedByteArray()) as PackedByteArray).is_empty()
			and client.gained_exp == 25)


func _profile_hook() -> void:
	_wis_online()
	var profile: OnlineProfile = Profile.new()
	check("leeg profiel laadt", bool(profile.load_profile().get("ok", false)) and not FileAccess.file_exists(Profile.PATH))
	check("slot voor de hook", bool(profile.create_slot(0, "Mira", "priest").get("ok", false)))
	var wrote: Dictionary = profile.set_progress(0, 4, 1, 2, ["hair_3"], [KEY_A])
	var grants: Array = profile.get_slot(0).get("applied_grants", [])
	check("M1 bewaart de grant-sleutel", bool(wrote.get("ok", false)) and grants.has(KEY_A) and grants.size() == 1)
	var voor := FileAccess.get_file_as_bytes(Profile.PATH)
	var box: RewardAck = Ack.new()
	var already: Dictionary = box.receive(_wire(UID, 9, KEY_A))
	var already_ack := Codec.read_reward_ack(Codec.decode_v2(already.get("ack", PackedByteArray())).get("body", {}))
	check("standaardhook leest applied_grants: 0 extra en ACK", bool(already.get("ok", false))
			and int(already.get("extra", -1)) == 0 and box.gained_exp == 0
			and str(already_ack.get("grant_key", "")) == KEY_A)
	var fresh: Dictionary = box.receive(_wire(UID, 8, KEY_B))
	check("standaardhook: onbekende sleutel telt één keer", bool(fresh.get("applied", false)) and int(fresh.get("extra", -1)) == 8
			and box.gained_exp == 8)
	check("de hook schrijft het profiel niet", FileAccess.get_file_as_bytes(Profile.PATH) == voor)
	var rot := "geen json".to_utf8_buffer()
	var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
	f.store_buffer(rot)
	f.close()
	var kapot: RewardAck = Ack.new()
	var from_rot: Dictionary = kapot.receive(_wire(UID, 3, KEY_A))
	check("kapot profiel telt niet als toegepast en blijft staan", bool(from_rot.get("applied", false))
			and int(from_rot.get("extra", -1)) == 3 and FileAccess.get_file_as_bytes(Profile.PATH) == rot)


func _fields(tick: int, exp: int) -> Dictionary:
	return {"session_id": 4, "host_tick": tick, "profile_exp": exp, "unlocks": []}


func _wire(uid: String, exp: int, key: String) -> Dictionary:
	var raw := Codec.encode_reward_bundle(uid, 4, 10, exp, ["hair_3"], key)
	return Codec.decode_v2(raw).get("body", {})


func _story_paths() -> Array[String]:
	return [
		"user://save_1.json", "user://save_2.json", "user://save_3.json", "user://save_4.json",
		"user://autosave.json", "user://autosave_1.json", "user://autosave_2.json",
		"user://autosave_3.json", "user://autosave_4.json",
		"user://som_save_1.json", "user://coop_guest_session.json", "user://coop_guest_autosave.json",
		GameState.save_path, GameState.autosave_path,
	]


func _snap(paden: Array[String]) -> Dictionary:
	var uit := {}
	for pad in paden:
		var bestaat := FileAccess.file_exists(pad)
		uit[pad] = {
			"exists": bestaat,
			"bytes": FileAccess.get_file_as_bytes(pad) if bestaat else PackedByteArray(),
		}
	return uit


func _zelfde(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for pad in a.keys():
		if not b.has(pad):
			return false
		var links: Dictionary = a[pad]
		var rechts: Dictionary = b[pad]
		if bool(links.get("exists", false)) != bool(rechts.get("exists", false)):
			return false
		if (links.get("bytes", PackedByteArray()) as PackedByteArray) != (rechts.get("bytes", PackedByteArray()) as PackedByteArray):
			return false
	return true


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
	for naam2 in namen:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://%s" % naam2))


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
