extends Node
class_name PvpSession
## Eén zetel (host of gast). De lobbyscène bezit de sessie.
## Er is geen opslag: niets gaat naar een savebestand.
##
## Fasen: menu, wait_peer, mode_select, team_select, battle, result.

signal code_ready(code: String)
signal peer_joined
signal mode_chosen(mode_id: String)
signal teams_ready
signal battle_started
signal battle_finished(result: Dictionary)
signal action_resolved(info: Dictionary)
signal disconnected(message: String)
signal phase_changed(phase: String)
signal error_message(text: String)
signal stopped
signal resumed(phase: String)
signal guest_dropped(message: String)

var role: String = ""
var code: String = ""
var mode_id: String = ""
var host_team: String = ""
var guest_team: String = ""
var phase: String = "menu"
var transport: PvpTransport = null
var battle: PvpBattleState = null
var last_result: Dictionary = {}
var reconnect_code: String = ""
var reconnect_kind: String = ""
var guest_online: bool = false
var _kind: String = ""
var _closing: bool = false
var _reject_reason: String = ""


func begin_host(kind: String) -> bool:
	_shutdown_transport()
	_clear_match()
	reconnect_code = ""
	reconnect_kind = ""
	role = "host"
	_kind = kind
	guest_online = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	code = PvpConnectCode.generate(rng)
	if not _open_transport(kind):
		return false
	phase = "wait_peer"
	transport.host(code)
	if phase != "wait_peer":
		return false
	code_ready.emit(code)
	phase_changed.emit(phase)
	return true


func begin_join(kind: String, raw_code: String, direct_ip: String = "") -> bool:
	var parsed := PvpConnectCode.parse(raw_code)
	if parsed == "":
		error_message.emit("That code is wrong. Six characters, for example K7NP2Q.")
		return false
	_shutdown_transport()
	_clear_match()
	reconnect_code = ""
	reconnect_kind = ""
	role = "guest"
	_kind = kind
	code = parsed
	if not _open_transport(kind):
		return false
	phase = "wait_peer"
	var started := false
	if kind == "lan" and direct_ip != "":
		var lan := transport as PvpLanTransport
		started = lan != null and lan.join_ip(parsed, direct_ip)
	else:
		started = transport.join(parsed)
	if not started or phase == "menu":
		return false
	if kind == "local" and not _phase_is_live():
		_shutdown_transport()
		_clear_match()
		phase = "menu"
		error_message.emit(PvpDisconnect.match_gone_message())
		return false
	phase_changed.emit(phase)
	return true


func choose_mode(picked: String) -> bool:
	if role != "host":
		error_message.emit("Only the host chooses the mode.")
		return false
	if phase != "mode_select":
		return false
	if not PvpModes.has_mode(picked):
		return false
	mode_id = picked
	_send({"t": "mode", "from": "host", "mode": picked})
	phase = "team_select"
	mode_chosen.emit(picked)
	phase_changed.emit(phase)
	return true


func choose_team(picked: String) -> bool:
	if phase != "team_select":
		return false
	if not PvpTeams.has_team(picked):
		return false
	if role == "host":
		if host_team != "":
			return false
		host_team = picked
	elif role == "guest":
		if guest_team != "":
			return false
		guest_team = picked
	else:
		return false
	_send({"t": "team", "from": role, "team": picked})
	if role == "host":
		_try_start()
	return true


func submit_action(actor_uid: String, action: String, target_uid: String, extra: Dictionary = {}) -> bool:
	if phase != "battle" or battle == null:
		return false
	var actor := battle.fighter(actor_uid)
	if actor.is_empty() or str(actor.get("seat", "")) != role:
		return false
	var spell_id := str(extra.get("spell", ""))
	var item_id := str(extra.get("item", ""))
	if role == "guest":
		_reject_reason = ""
		_send({
			"t": "action",
			"from": "guest",
			"actor": actor_uid,
			"action": action,
			"target": target_uid,
			"spell": spell_id,
			"item": item_id,
		})
		return _reject_reason == ""
	return _resolve(actor_uid, action, target_uid, spell_id, item_id, "host")


func rematch() -> void:
	if phase != "result":
		return
	if role != "host":
		_send({"t": "rematch", "from": role})
		return
	_do_rematch()


func rechoose() -> void:
	if phase != "result":
		return
	if role != "host":
		_send({"t": "rechoose", "from": role})
		return
	_do_rechoose()


func stop_match() -> void:
	if phase == "menu":
		return
	if role != "host":
		_send({"t": "stop", "from": role})
		return
	_end_to_menu()


func force_disconnect() -> void:
	var msg := PvpDisconnect.drop_message()
	var remember := role == "guest" and code != "" and _kind != ""
	var saved_code := code
	var saved_kind := _kind
	_closing = true
	_shutdown_transport()
	_clear_match()
	if remember:
		reconnect_code = saved_code
		reconnect_kind = saved_kind
	else:
		reconnect_code = ""
		reconnect_kind = ""
	phase = "menu"
	_closing = false
	phase_changed.emit(phase)
	disconnected.emit(msg)


func abandon() -> void:
	_closing = true
	if transport != null:
		transport.close_silent()
	_shutdown_transport()
	_clear_match()
	reconnect_code = ""
	reconnect_kind = ""
	phase = "menu"
	_closing = false
	phase_changed.emit(phase)


func request_reconnect() -> bool:
	# TODO(design): geen relay. Alleen dezelfde nog levende hostsessie.
	if reconnect_code == "" or reconnect_kind == "":
		phase = "menu"
		phase_changed.emit(phase)
		disconnected.emit(PvpDisconnect.match_gone_message())
		return false
	var saved_code := reconnect_code
	var saved_kind := reconnect_kind
	var ok := begin_join(saved_kind, saved_code)
	if ok:
		reconnect_code = ""
		reconnect_kind = ""
		return true
	reconnect_code = ""
	reconnect_kind = ""
	if phase != "menu":
		phase = "menu"
		phase_changed.emit(phase)
	disconnected.emit(PvpDisconnect.match_gone_message())
	return false


func _open_transport(kind: String) -> bool:
	transport = _make_transport(kind)
	if transport == null:
		error_message.emit("Unknown connection.")
		_clear_match()
		phase = "menu"
		return false
	add_child(transport)
	transport.connected.connect(_on_connected)
	transport.disconnected.connect(_on_disconnected)
	transport.peer_left.connect(_on_peer_left)
	transport.message.connect(_on_message)
	transport.failed.connect(_on_failed)
	return true


func _make_transport(kind: String) -> PvpTransport:
	if kind == "local":
		return PvpLocalTransport.new()
	if kind == "lan":
		return PvpLanTransport.new()
	return null


func _send(payload: Dictionary) -> void:
	if transport == null:
		return
	transport.send(payload)


func _on_connected() -> void:
	guest_online = true
	if role == "host" and phase != "wait_peer" and phase != "menu":
		# Lokaal is het bericht meteen binnen. Op LAN pas na deze frame,
		# zodat de vriend de ENet-handshake al af heeft.
		if _kind == "local":
			_push_resume()
		else:
			_push_resume.call_deferred()
		peer_joined.emit()
		return
	if phase != "wait_peer":
		return
	phase = "mode_select"
	peer_joined.emit()
	phase_changed.emit(phase)


func _on_peer_left() -> void:
	if role != "host" or _closing:
		return
	guest_online = false
	guest_dropped.emit(PvpDisconnect.guest_left_message())


func _on_disconnected(reason: String) -> void:
	if _closing:
		return
	_closing = true
	_shutdown_transport()
	_clear_match()
	reconnect_code = ""
	reconnect_kind = ""
	phase = "menu"
	_closing = false
	phase_changed.emit(phase)
	var text := reason if reason != "" else PvpDisconnect.match_gone_message()
	disconnected.emit(text)


func _on_failed(reason: String) -> void:
	if _closing:
		return
	_closing = true
	_shutdown_transport()
	_clear_match()
	phase = "menu"
	_closing = false
	phase_changed.emit(phase)
	error_message.emit(reason)


func _on_message(payload: Dictionary) -> void:
	var kind := str(payload.get("t", ""))
	var from := str(payload.get("from", ""))
	match kind:
		"mode":
			if from != "host" or role != "guest":
				return
			if not PvpModes.has_mode(str(payload.get("mode", ""))):
				return
			mode_id = str(payload["mode"])
			phase = "team_select"
			mode_chosen.emit(mode_id)
			phase_changed.emit(phase)
		"team":
			if from != "host" and from != "guest":
				return
			var picked := str(payload.get("team", ""))
			if not PvpTeams.has_team(picked):
				return
			if from == "host":
				host_team = picked
			else:
				guest_team = picked
			if role == "host":
				_try_start()
		"battle":
			if from != "host" or role == "host":
				return
			_accept_battle(payload.get("state", {}))
			if payload.has("host_team"):
				host_team = str(payload["host_team"])
			if payload.has("guest_team"):
				guest_team = str(payload["guest_team"])
		"state":
			if from != "host" or role == "host" or battle == null:
				return
			battle.load_snapshot(payload.get("state", {}))
			action_resolved.emit({"ok": true, "log": str(payload.get("log", ""))})
		"finished":
			if from != "host" or role == "host":
				return
			if battle == null:
				battle = PvpBattleState.new()
			battle.load_snapshot(payload.get("state", {}))
			last_result = (payload.get("result", {}) as Dictionary).duplicate(true)
			phase = "result"
			phase_changed.emit(phase)
			battle_finished.emit(last_result)
		"action":
			if role != "host" or from != "guest":
				return
			_resolve(
				str(payload.get("actor", "")),
				str(payload.get("action", "")),
				str(payload.get("target", "")),
				str(payload.get("spell", "")),
				str(payload.get("item", "")),
				"guest"
			)
		"rematch":
			if role == "host" and from == "guest":
				_do_rematch()
		"rechoose":
			if role == "host" and from == "guest":
				_do_rechoose()
			elif role == "guest" and from == "host":
				_enter_team_select()
		"stop":
			if role == "host" and from == "guest":
				_end_to_menu()
			elif role == "guest" and from == "host":
				_finish_stop()
		"reject":
			_reject_reason = str(payload.get("reason", "You can't do that."))
			error_message.emit(_reject_reason)
		"resume":
			if from != "host" or role != "guest":
				return
			_apply_resume(payload)


func _try_start() -> void:
	if role != "host" or phase != "team_select":
		return
	if not PvpRules.teams_ok(host_team, guest_team):
		return
	_start_battle(false)
	teams_ready.emit()


func _start_battle(rematch_flag: bool) -> void:
	if battle == null or not rematch_flag:
		battle = PvpBattleState.new()
		var host_side := PvpRoster.build_side("host", host_team, mode_id)
		var guest_side := PvpRoster.build_side("guest", guest_team, mode_id)
		battle.setup(host_side, guest_side, code.hash())
	else:
		battle.reset_for_rematch()
	phase = "battle"
	var payload := {
		"t": "battle",
		"from": "host",
		"state": battle.serialize(),
		"host_team": host_team,
		"guest_team": guest_team,
		"rematch": rematch_flag,
	}
	_send(payload)
	phase_changed.emit(phase)
	battle_started.emit()


func _push_resume() -> void:
	var payload := {
		"t": "resume",
		"from": "host",
		"phase": phase,
		"mode": mode_id,
		"host_team": host_team,
		"guest_team": guest_team,
	}
	if battle != null and (phase == "battle" or phase == "result"):
		payload["state"] = battle.serialize()
		payload["result"] = last_result.duplicate(true)
	_send(payload)


func _apply_resume(payload: Dictionary) -> void:
	var next := str(payload.get("phase", ""))
	if next != "mode_select" and next != "team_select" and next != "battle" and next != "result":
		return
	mode_id = str(payload.get("mode", ""))
	host_team = str(payload.get("host_team", ""))
	guest_team = str(payload.get("guest_team", ""))
	if payload.get("state", null) is Dictionary:
		if battle == null:
			battle = PvpBattleState.new()
		battle.load_snapshot(payload["state"])
	if payload.get("result", null) is Dictionary:
		last_result = (payload["result"] as Dictionary).duplicate(true)
	phase = next
	phase_changed.emit(phase)
	resumed.emit(phase)
	if phase == "battle":
		battle_started.emit()
	elif phase == "result":
		battle_finished.emit(last_result)


func _phase_is_live() -> bool:
	return phase == "mode_select" or phase == "team_select" or phase == "battle" or phase == "result"


func _accept_battle(state: Variant) -> void:
	if not (state is Dictionary):
		return
	if battle == null:
		battle = PvpBattleState.new()
	battle.load_snapshot(state)
	phase = "battle"
	phase_changed.emit(phase)
	battle_started.emit()


func _resolve(actor_uid: String, action: String, target_uid: String, spell_id: String, item_id: String, from_seat: String) -> bool:
	if battle == null or phase != "battle":
		return false
	var actor := battle.fighter(actor_uid)
	if actor.is_empty() or str(actor.get("seat", "")) != from_seat:
		_send({"t": "reject", "from": "host", "reason": "Not your turn."})
		return false
	var applied := battle.apply_action(actor_uid, action, target_uid, spell_id, item_id)
	if not bool(applied["ok"]):
		var reason := str(applied["reason"])
		if from_seat == "guest":
			_send({"t": "reject", "from": "host", "reason": reason})
		else:
			error_message.emit(reason)
		return false
	var snapshot := battle.serialize()
	if bool(applied["finished"]):
		last_result = battle.result_dict()
		phase = "result"
		_send({
			"t": "finished",
			"from": "host",
			"result": last_result.duplicate(true),
			"state": snapshot,
		})
		phase_changed.emit(phase)
		battle_finished.emit(last_result)
		return true
	_send({"t": "state", "from": "host", "state": snapshot, "log": str(applied["log"])})
	action_resolved.emit(applied)
	return true


func _do_rematch() -> void:
	if phase != "result" or battle == null or role != "host":
		return
	if not PvpRules.teams_ok(host_team, guest_team):
		return
	_start_battle(true)


func _do_rechoose() -> void:
	if role != "host" or phase != "result":
		return
	_send({"t": "rechoose", "from": "host"})
	_enter_team_select()


func _enter_team_select() -> void:
	host_team = ""
	guest_team = ""
	battle = null
	last_result = {}
	phase = "team_select"
	phase_changed.emit(phase)


func _end_to_menu() -> void:
	if role != "host" or _closing:
		return
	_send({"t": "stop", "from": "host"})
	_finish_stop()


func _finish_stop() -> void:
	if _closing:
		return
	_closing = true
	if transport != null:
		transport.close_silent()
	_shutdown_transport()
	_clear_match()
	reconnect_code = ""
	reconnect_kind = ""
	phase = "menu"
	_closing = false
	phase_changed.emit(phase)
	stopped.emit()


func _shutdown_transport() -> void:
	var old := transport
	transport = null
	if old == null:
		return
	if old.connected.is_connected(_on_connected):
		old.connected.disconnect(_on_connected)
	if old.disconnected.is_connected(_on_disconnected):
		old.disconnected.disconnect(_on_disconnected)
	if old.peer_left.is_connected(_on_peer_left):
		old.peer_left.disconnect(_on_peer_left)
	if old.message.is_connected(_on_message):
		old.message.disconnect(_on_message)
	if old.failed.is_connected(_on_failed):
		old.failed.disconnect(_on_failed)
	old.close()
	old.queue_free()


func _clear_match() -> void:
	role = ""
	code = ""
	mode_id = ""
	host_team = ""
	guest_team = ""
	battle = null
	last_result = {}
