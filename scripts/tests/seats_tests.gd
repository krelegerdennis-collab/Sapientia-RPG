extends Node
## M6 stoelen: rolvulling, AI alleen op de host, deterministische input, disconnect/rejoin, solo-guard.
## Start: godot --path . -- --seatstest

const SeatController := preload("res://scripts/coop/seat_controller.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const SomData := preload("res://scripts/data/som_data.gd")

const ROOM := "res://scenes/maps/archief_v1_gang.tscn"
const SEED := 424242
## 120 stappen: lang genoeg dat bondgenoten slaan, kort genoeg dat er geen vijand sneuvelt
## (een verslagen node is weg en maakt een tweede run oneerlijk).
const TICKS := 120
## Discrete solo-uitkomst van het ongewijzigde tick-pad (seat_ai uit) na de vaste reset.
const SOLO_DISCRETE := "php:42|lotte:engage:3:0|noor:engage:3:0|rng:-2003358753087401976|gold:0|hp:42,46,46,14,9,38"

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


func _run() -> void:
	_role_tests()
	_hud_tests()
	_hook_tests()
	_input_determinism_tests()
	_grace_tests()
	_host_lost_tests()
	_ai_host_only_and_follow_tests()
	_disconnect_arena_tests()
	await _solo_guard_tests()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _role_tests() -> void:
	check("grace start 180s", SeatController.GRACE_SEC == 180.0 and SeatController.GRACE_TICKS == 180 * 60)
	var cases := [
		[[], 4, ["dennis", "lotte", "noor", "orion"]],
		[["dennis"], 3, ["lotte", "noor", "orion"]],
		[["lotte"], 3, ["dennis", "noor", "orion"]],
		[["noor"], 3, ["dennis", "lotte", "orion"]],
		[["orion"], 3, ["dennis", "lotte", "noor"]],
		[["kael"], 3, ["dennis", "lotte", "noor"]],
		[["dennis", "lotte"], 2, ["noor", "orion"]],
		[["dennis", "noor"], 2, ["lotte", "orion"]],
		[["dennis", "orion"], 2, ["lotte", "noor"]],
		[["dennis", "kael"], 2, ["lotte", "noor"]],
		[["lotte", "noor"], 2, ["dennis", "orion"]],
		[["lotte", "kael"], 2, ["dennis", "noor"]],
		[["orion", "kael"], 2, ["dennis", "lotte"]],
		[["noor", "orion"], 2, ["dennis", "lotte"]],
		[["dennis", "lotte", "noor"], 1, ["orion"]],
		[["dennis", "lotte", "orion"], 1, ["noor"]],
		[["dennis", "lotte", "kael"], 1, ["noor"]],
		[["dennis", "noor", "kael"], 1, ["lotte"]],
		[["orion", "kael", "noor"], 1, ["dennis"]],
		[["dennis", "lotte", "noor", "orion"], 0, []],
		[["dennis", "lotte", "noor", "kael"], 0, []],
	]
	var bad := 0
	for c in cases:
		var got: Array = SeatController.fill_heroes(c[0], int(c[1]))
		if not _same(got, c[2]):
			bad += 1
			print("INFO  fill %s -> %s want %s" % [str(c[0]), str(got), str(c[2])])
	check("rolvulling %d samenstellingen" % cases.size(), bad == 0)
	var sc := _table([{
		"slot": 0, "uid": "h", "hero_id": "kael", "controller": "local",
	}], true)
	check("partij alleen Psytech: AI Warrior/Priest/Mage", _heroes(sc, "ai") == ["dennis", "lotte", "noor"])
	check("rollen tank/heal/control/dps", SeatController.role_of("dennis") == "tank"
			and SeatController.role_of("lotte") == "heal" and SeatController.role_of("noor") == "control"
			and SeatController.role_of("orion") == "dps" and SeatController.role_of("kael") == "dps")


func _hud_tests() -> void:
	var sc := _table([
		{"slot": 0, "uid": "h", "hero_id": "dennis", "controller": "local"},
		{"slot": 2, "uid": "g", "hero_id": "kael", "controller": "remote"},
	], true)
	check("HUD AI 1 op laagste AI-stoel", sc.hud_name(1) == "AI 1")
	check("HUD AI 2 op volgende AI-stoel", sc.hud_name(3) == "AI 2")
	check("menselijke stoel heeft geen AI-naam", sc.hud_name(0) == "" and sc.hud_name(2) == "")
	var rows: Array = sc.hud_rows()
	var names: Array = []
	for row in rows:
		names.append(str(row.get("name", "")))
	check("HUD-rijen Dax, AI 1, Kael Voss, AI 2", names == ["Dax", "AI 1", "Kael Voss", "AI 2"])
	check("AI-tint is gemarkeerde placeholder", SeatController.AI_TINT.r < SeatController.AI_TINT.g
			and SeatController.AI_TINT.b > 0.7 and SeatController.AI_TINT.g > 0.7)


func _hook_tests() -> void:
	check("stubs zonder uitvoering", SeatController.STUB_ACTIONS.has("revive") and SeatController.STUB_ACTIONS.has("taunt")
			and SeatController.STUB_ACTIONS.has("guard") and not SeatController.try_revive(0)
			and not SeatController.try_role_hook("revive") and not SeatController.try_role_hook("taunt"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var tank := _sense({"non_tank_targeted": true, "telegraph": true, "has_enemy": true, "in_reach": true, "charge_ready": true})
	var a := SeatController.plan_input("tank", tank, rng)
	check("tank: taunt-haak, daarna slaan", str(a.get("hook", "")) == "taunt" and str(a.get("intent", "")) == "attack"
			and (int(a.get("buttons", 0)) & Codec.BTN_ATTACK) != 0)
	var guard := SeatController.plan_input("tank", _sense({"telegraph": true, "has_enemy": true, "in_reach": true, "charge_ready": true}), rng)
	check("tank: guard-haak, daarna slaan", str(guard.get("hook", "")) == "guard" and str(guard.get("intent", "")) == "attack")
	var heal := SeatController.plan_input("heal", _sense({
		"downed_ally": true, "ally_low": true, "has_enemy": true, "heal_pos": Vector2(4, 0), "self_pos": Vector2.ZERO,
	}), rng)
	check("heal: revive-haak zonder revive, daarna genezen", str(heal.get("hook", "")) == "revive"
			and str(heal.get("intent", "")) == "heal" and not SeatController.try_revive(0))
	var ctrl := SeatController.plan_input("control", _sense({"telegraph": true, "has_enemy": true, "in_reach": true, "charge_ready": true}), rng)
	check("control: interrupt-haak, daarna slaan", str(ctrl.get("hook", "")) == "interrupt" and str(ctrl.get("intent", "")) == "attack")
	var dps := SeatController.plan_input("dps", _sense({"chain_ready": true, "has_enemy": true, "in_reach": true}), rng)
	check("dps: combo is een slag", str(dps.get("intent", "")) == "combo" and str(dps.get("hook", "")) == ""
			and (int(dps.get("buttons", 0)) & Codec.BTN_ATTACK) != 0)
	var dodge := SeatController.plan_input("dps", _sense({"telegraph": true, "has_enemy": false, "self_pos": Vector2(10, 10), "enemy_pos": Vector2(40, 10)}), rng)
	check("dps: ontwijken als er niets te slaan is", str(dodge.get("intent", "")) == "dodge"
			and (int(dodge.get("buttons", 0)) & Codec.BTN_DODGE) != 0)
	var stick: Vector2 = dodge.get("stick", Vector2.ZERO)
	check("stick lengte <= 1", stick.length() <= 1.001)


func _input_determinism_tests() -> void:
	var a := _roll_intents(7)
	var b := _roll_intents(7)
	var c := _roll_intents(8)
	check("zelfde seed -> dezelfde AI-inputs", a == b and a != "")
	check("andere seed -> andere AI-inputs", a != c)
	var ally_a := _ally_roll(3)
	var ally_b := _ally_roll(3)
	check("SomAlly op de host: zelfde seed -> zelfde input", ally_a == ally_b and ally_a != "")
	check("AI-input gebruikt geen globale rand", not ally_a.contains("nan"))


func _grace_tests() -> void:
	var sc := _remote_pair()
	var pos := sc.pos_of(1)
	var hp := sc.hp_of(1)
	var mp := sc.mp_of(1)
	var tick := sc.tick_i
	check("socket-drop wordt AI", sc.guest_lost(1, "socket"))
	check("zelfde tick bij socket-drop", sc.tick_i == tick and sc.controller_of(1) == "ai")
	check("socket-drop houdt HP/MP/positie", sc.hp_of(1) == hp and sc.mp_of(1) == mp and sc.pos_of(1) == pos)
	check("stoel gereserveerd onder uid", sc.reserved_uid(1) == "guest" and sc.grace_ticks_of(1) == SeatController.GRACE_TICKS)
	check("verkeerde kamer geen rejoin", sc.try_rejoin("guest", "andere") == -1 and sc.controller_of(1) == "ai")
	check("rejoin binnen grace: zelfde stoel", sc.try_rejoin("guest", "KAMER") == 1)
	check("rejoin zonder sprong", sc.controller_of(1) == "remote" and sc.pos_of(1) == pos and sc.hp_of(1) == hp and sc.mp_of(1) == mp)
	check("ping-timeout wordt ook AI", sc.guest_lost(1, "ping") and sc.drop_reason_of(1) == "ping" and sc.controller_of(1) == "ai" and sc.pos_of(1) == pos)
	sc.advance_ticks(SeatController.GRACE_TICKS - 1)
	check("één tick voor grace-einde nog dezelfde stoel", sc.try_rejoin("guest", "KAMER") == 1 and sc.pos_of(1) == pos)
	sc.guest_lost(1, "socket")
	sc.advance_ticks(SeatController.GRACE_TICKS)
	check("na grace blijft de stoel AI", sc.controller_of(1) == "ai" and sc.reserved_uid(1) == "" and sc.try_rejoin("guest", "KAMER") == -1)
	var open := _first_free_ai(sc)
	var open_hp := sc.hp_of(open)
	var open_mp := sc.mp_of(open)
	var open_pos := sc.pos_of(open)
	var open_hero := sc.hero_of(open)
	sc.request_claim("nieuw", "orion")
	check("join wacht op de volgende tick", open >= 0 and sc.controller_of(open) == "ai" and sc.uid_of(open) != "nieuw")
	sc.begin_tick_one()
	check("join pakt AI-stoel met dezelfde HP/MP/positie", open >= 0 and sc.controller_of(open) == "remote" and sc.uid_of(open) == "nieuw"
			and sc.hero_of(open) == open_hero and sc.hp_of(open) == open_hp and sc.mp_of(open) == open_mp and sc.pos_of(open) == open_pos)
	var held := _remote_pair()
	held.guest_lost(1, "socket")
	var reserved_hero := held.hero_of(1)
	held.request_claim("ander", "dennis")
	held.begin_tick_one()
	check("gereserveerde stoel gaat niet naar een andere uid", held.controller_of(1) == "ai" and held.hero_of(1) == reserved_hero and held.reserved_uid(1) == "guest")


func _host_lost_tests() -> void:
	var sc := _remote_pair()
	var before := "%s|%s" % [sc.controller_of(0), sc.controller_of(1)]
	check("host-wegval is sessie-einde", sc.note_host_lost() == SeatController.HOST_LOST)
	check("host-wegval maakt geen stoel AI", "%s|%s" % [sc.controller_of(0), sc.controller_of(1)] == before)
	check("host-stoel zelf wordt niet AI", not sc.guest_lost(0, "socket") and sc.controller_of(0) == "local")
	var sess := Session.new()
	add_child(sess)
	sess.set_process(false)
	sess.is_host = false
	var ended := [false]
	sess.link_lost.connect(func() -> void: ended[0] = true)
	sess.simulate_peer_drop(4)
	check("gast ziet host-drop als sessie-einde", ended[0])


func _ai_host_only_and_follow_tests() -> void:
	var host := _boot(true)
	var guest := _boot(false)
	if host.is_empty() or guest.is_empty():
		check("arena-rig", false)
		return
	var ha: SomArena = host["arena"]
	var ga: SomArena = guest["arena"]
	check("host draait AI-bondgenoten", _ally_count(ha) == 2 and ha.seat_controller != null and ha.seat_controller.runs_ai())
	check("gast draait geen AI", _ally_count(ga) == 0 and ga.seat_controller != null and not ga.seat_controller.runs_ai())
	check("gast toont AI als avatar", ga.coop_avatar_nodes_in_scene() >= 3)
	var tinted := 0
	for c in ha.room.get_node("Objects").get_children():
		if c is SomAlly and c.sprite != null and c.sprite.modulate == SeatController.AI_TINT and c.seat_ai:
			tinted += 1
	check("AI-look grijs-cyaan op de host", tinted == 2)
	check("solo-vlag staat uit in co-op", not ha.allies_enabled and ha.coop_mode)
	var bare := _boot_roster(true, [
		{"slot": 0, "character_id": "dennis", "peer_id": 1},
		{"slot": 1, "character_id": "lotte", "peer_id": 2},
	])
	var ba: SomArena = bare["arena"]
	check("LAN zonder uid: geen stoel-AI", ba.seat_controller == null and _ally_count(ba) == 0 and not ba.allies_enabled)
	ha.player.position = Vector2(0, 80)
	var remote := _avatar(ha, 1)
	check("remote avatar bestaat", remote != null)
	if remote != null:
		remote.position = Vector2(200, 80)
	var ally := _first_ally(ha)
	if ally != null:
		ally.position = Vector2(180, 80)
		var near: Vector2 = ha.nearest_living_player_pos(ally.position)
		check("AI volgt de dichtstbijzijnde levende speler", near.distance_to(Vector2(200, 80)) < 1.0
				and near.distance_to(ha.player.position) > 50.0)
		var far_hp: int = int(ha.seat_controller.hp_of(1))
		ha.seat_controller.set_hp_mp(1, 0, ha.seat_controller.mp_of(1))
		var back: Vector2 = ha.nearest_living_player_pos(ally.position)
		check("dode speler telt niet als anker", back.distance_to(ha.player.position) < 1.0)
		ha.seat_controller.set_hp_mp(1, far_hp, ha.seat_controller.mp_of(1))
	else:
		check("AI volgt de dichtstbijzijnde levende speler", false)
		check("dode speler telt niet als anker", false)
	var log_a := _ai_trace(ha)
	var log_b := _ai_trace(ha)
	check("arena: zelfde seed -> hetzelfde AI-spoor", log_a == log_b and log_a != "")


func _disconnect_arena_tests() -> void:
	var pack := _boot_roster(true, [
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local", "room_code": "KAMER", "x": 10, "y": 20},
		{"slot": 1, "uid": "guest", "hero_id": "kael", "controller": "remote", "room_code": "KAMER", "hp": 11, "mp": 7, "x": 64, "y": 48},
	])
	var arena: SomArena = pack["arena"]
	var sess: Session = pack["session"]
	if GameState.has_member("kael"):
		var m: Dictionary = GameState.member("kael")
		m["hp"] = 11
		m["mp"] = 7
	var body := arena._coop_body(1)
	check("gast heeft een lichaam", body != null)
	if body == null:
		check("disconnect in de arena houdt positie", false)
		return
	body.position = Vector2(64, 48)
	arena.seat_controller.remember_pos(1, body.position)
	arena.seat_controller.set_hp_mp(1, 11, 7)
	sess._peer_to_slot[8] = 1
	sess.note_ping_timeout(8)
	var after := arena._coop_body(1)
	check("ping-timeout: AI op dezelfde positie", arena.seat_controller.controller_of(1) == "ai"
			and arena.seat_controller.hp_of(1) == 11 and arena.seat_controller.mp_of(1) == 7
			and after != null and after.position == Vector2(64, 48))
	check("ping-timeout verwijdert de stoel niet", not sess._peer_to_slot.has(8) and arena.seat_controller.holds(1))
	var slot: int = int(arena.seat_controller.try_rejoin("guest", "KAMER"))
	var rejoined := arena._coop_body(1)
	check("rejoin in de arena: zelfde stoel, geen sprong", slot == 1 and arena.seat_controller.controller_of(1) == "remote"
			and rejoined != null and rejoined.position == Vector2(64, 48) and arena.seat_controller.hp_of(1) == 11)


func _solo_guard_tests() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	var battle := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	check("Classic noemt de stoel-controller niet", not battle.contains("SeatController") and not battle.contains("seat_controller"))
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for id in ["noor", "lotte"]:
		if not GameState.has_member(id):
			GameState.add_member(id)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = ""
	get_tree().change_scene_to_file(ROOM)
	var room: Node = null
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == ROOM and s.is_node_ready() and i > 4 and s.get("som") != null:
			room = s
			break
	check("WM1-kamer geladen", room != null)
	if room == null:
		return
	var arena: SomArena = room.som
	arena.set_process(false)
	for m in room.monsters:
		if is_instance_valid(m):
			m.set_process(false)
	check("WM1 Action: allies aan, geen stoelen", arena.allies_enabled and arena.seat_controller == null and not arena.coop_mode)
	var seat_off := true
	for a in arena.allies:
		if a.seat_ai:
			seat_off = false
	check("solo-bondgenoot is geen co-op-stoel", seat_off and arena.allies.size() >= 2)
	var anchor: Vector2 = arena.player.position
	var formed: bool = true
	for a in arena.allies:
		var moved: Vector2 = a.formation_point()
		arena.player.position += Vector2(16, 0)
		if a.formation_point().distance_to(moved) < 1.0:
			formed = false
		arena.player.position = anchor
	check("solo-formatie blijft aan arena.player hangen", formed)
	_reset_solo(arena)
	var first := _fingerprint(arena)
	_reset_solo(arena)
	var second := _fingerprint(arena)
	check("zelfde seed -> byte-gelijk solo-spoor", first == second and first != "")
	_reset_solo(arena)
	arena.step_ticks(TICKS)
	check("solo/WM1-Action discrete uitkomst vast", _discrete(arena) == SOLO_DISCRETE)


func _roll_intents(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bits := ""
	for i in 24:
		var inp: Dictionary = SeatController.plan_input("control", _sense({
			"has_enemy": true,
			"in_reach": i % 4 == 0,
			"charge_ready": true,
			"spell_ready": true,
			"self_pos": Vector2(i, 0),
			"enemy_pos": Vector2(80, 0),
			"anchor_pos": Vector2(10, 4),
		}), rng)
		var stick: Vector2 = inp.get("stick", Vector2.ZERO)
		bits += "%s:%d:%.3f:%.3f|" % [str(inp.get("intent", "")), int(inp.get("buttons", 0)), stick.x, stick.y]
	return bits


func _ally_roll(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ally := SomAlly.new()
	ally.seat_ai = true
	ally.hero_id = "noor"
	var bits := ""
	for i in 12:
		var inp: Dictionary = ally.coop_virtual_input(_sense({
			"has_enemy": true, "spell_ready": true, "charge_ready": true, "in_reach": true,
			"self_pos": Vector2(0, i), "enemy_pos": Vector2(30, i),
		}), rng)
		bits += str(inp.get("intent", "")) + ":" + str(int(inp.get("buttons", 0))) + "|"
	ally.free()
	return bits


func _sense(extra: Dictionary) -> Dictionary:
	var s := {
		"self_pos": Vector2.ZERO,
		"anchor_pos": Vector2(40, 0),
		"anchor_facing": Vector2(0, 1),
		"slot": 1,
		"has_enemy": false,
		"enemy_pos": Vector2(80, 0),
		"in_reach": false,
		"charge_ready": false,
		"spell_ready": false,
		"chain_ready": false,
		"ally_low": false,
		"downed_ally": false,
		"telegraph": false,
		"non_tank_targeted": false,
		"lock_idx": -1,
		"heal_pos": Vector2(8, 0),
	}
	for k in extra.keys():
		s[k] = extra[k]
	return s


func _table(rows: Array, host: bool) -> SeatController:
	var sc := SeatController.new()
	sc.configure("KAMER", host, 0)
	sc.assign(rows)
	return sc


func _remote_pair() -> SeatController:
	return _table([
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local", "hp": 40, "mp": 0, "x": 1, "y": 2},
		{"slot": 1, "uid": "guest", "hero_id": "kael", "controller": "remote", "hp": 11, "mp": 7, "x": 30, "y": 40},
	], true)


func _first_free_ai(sc: SeatController) -> int:
	for slot in sc.occupied_slots():
		if sc.controller_of(slot) == "ai" and sc.reserved_uid(slot) == "":
			return slot
	return -1


func _heroes(sc: SeatController, ctrl: String) -> Array:
	var out: Array = []
	for slot in sc.occupied_slots():
		if sc.controller_of(slot) == ctrl:
			out.append(sc.hero_of(slot))
	return out


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true


func _boot(host: bool) -> Dictionary:
	return _boot_roster(host, [
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local" if host else "remote", "room_code": "KAMER", "x": 0, "y": 80},
		{"slot": 1, "uid": "g", "hero_id": "kael", "controller": "remote", "room_code": "KAMER", "x": 200, "y": 80, "hp": 30, "mp": 16},
	])


func _boot_roster(host: bool, roster: Array) -> Dictionary:
	var room := Node2D.new()
	room.name = "SeatRoom"
	var objects := Node2D.new()
	objects.name = "Objects"
	room.add_child(objects)
	add_child(room)
	var player := _Body.new()
	player.position = Vector2(0, 80)
	player.facing = Vector2i.DOWN
	room.add_child(player)
	var arena := SomArena.new()
	arena.room = room
	arena.player = player
	add_child(arena)
	arena.set_process(false)
	var sess := Session.new()
	sess.is_host = host
	add_child(sess)
	sess.set_process(false)
	arena.setup_coop(sess, roster, 0 if host else 1)
	return {"arena": arena, "session": sess, "room": room, "player": player}


func _ally_count(arena: SomArena) -> int:
	var n := 0
	for c in arena.room.get_node("Objects").get_children():
		if c is SomAlly:
			n += 1
	return n


func _first_ally(arena: SomArena) -> SomAlly:
	for c in arena.room.get_node("Objects").get_children():
		if c is SomAlly:
			return c
	return null


func _avatar(arena: SomArena, slot: int) -> Node2D:
	if arena._coop_avatars.has(slot):
		return arena._coop_avatars[slot] as Node2D
	return null


func _ai_trace(arena: SomArena) -> String:
	arena.seed_rng(99)
	if arena.seat_controller != null:
		for slot in arena.seat_controller.ai_slots():
			var body = arena._ai_bodies.get(slot, null)
			if body == null:
				continue
			body.spell_cd = 1.0
			body.charge = 1.0
	var bits := ""
	for _i in 8:
		var inputs: Array = []
		arena._merge_ai_inputs(inputs, SomArena.TICK_DT)
		for inp in inputs:
			var stick: Vector2 = inp.get("stick", Vector2.ZERO)
			bits += "%d:%s:%.3f:%.3f|" % [int(inp.get("slot", -1)), str(inp.get("intent", "")), stick.x, stick.y]
	return bits


func _reset_solo(arena: SomArena) -> void:
	arena.allies_enabled = true
	arena.coop_mode = false
	arena.seed_rng(SEED)
	arena.player.position = Vector2(80, 140)
	arena.player.velocity = Vector2.ZERO
	arena.player.facing = Vector2i.DOWN
	var ms: Array = []
	for m in arena.enemies.keys():
		if is_instance_valid(m):
			ms.append(m)
	ms.sort_custom(func(a, b): return str(a.monster_id) < str(b.monster_id))
	var i := 0
	for m in ms:
		m.position = Vector2(64 + (i % 3) * 24, 64 + int(i / 3) * 24)
		if "velocity" in m:
			m.velocity = Vector2.ZERO
		var e: Dictionary = arena.enemies[m]
		e["hp"] = int(e["max_hp"])
		e["cd"] = 0.6
		e["tele"] = 0.0
		e["chase"] = 0.25
		e["flash"] = 0.0
		e["target"] = ""
		e["hitstop"] = 0
		var tg: Variant = e.get("tg", null)
		if tg != null and tg.has_method("cancel"):
			tg.cancel()
		i += 1
	for a in arena.allies:
		a.position = a.formation_point()
		a.velocity = Vector2.ZERO
		a.charge = 1.0
		a.spell_cd = 1.0
		a.attacks = 0
		a.teleports = 0
		a.stuck_t = 0.0
		a.state = a.ST_FOLLOW
		a.seat_ai = false
	for id in ["dennis", "noor", "lotte"]:
		var h: Dictionary = arena.member(id)
		if h.is_empty():
			continue
		h["hp"] = int(h["max_hp"])
		h["mp"] = int(h.get("max_mp", h.get("mp", 0)))
	arena.charge = 1.0
	arena.swing_lock = 0.0
	arena.iframes.clear()
	arena._pending = {"switch": false, "attack": false, "cast": false, "dodge": false, "hold": false}
	for anim in arena._sim_anims:
		if is_instance_valid(anim):
			anim.queue_free()
	arena._sim_anims.clear()
	arena._clear_transient_combat()
	arena.seed_rng(SEED)
	GameState.gold = 0


func _fingerprint(arena: SomArena) -> String:
	arena.step_ticks(TICKS)
	return _discrete(arena) + "|" + _places(arena)


func _discrete(arena: SomArena) -> String:
	var allies: Array = arena.allies.duplicate()
	allies.sort_custom(func(a, b): return str(a.hero_id) < str(b.hero_id))
	var aparts := ""
	for a in allies:
		aparts += "%s:%s:%d:%d|" % [str(a.hero_id), str(a.state), int(a.attacks), int(a.teleports)]
	var ms: Array = []
	for m in arena.enemies.keys():
		if is_instance_valid(m):
			ms.append(m)
	ms.sort_custom(func(a, b): return str(a.monster_id) < str(b.monster_id))
	var hp := ""
	for m in ms:
		hp += str(int(arena.enemies[m]["hp"])) + ","
	return "php:%d|%srng:%d|gold:%d|hp:%s" % [int(arena.member("dennis").get("hp", -1)), aparts, int(arena.rng.state), GameState.gold, hp.trim_suffix(",")]


func _places(arena: SomArena) -> String:
	var bits := "%.3f,%.3f" % [arena.player.position.x, arena.player.position.y]
	var allies: Array = arena.allies.duplicate()
	allies.sort_custom(func(a, b): return str(a.hero_id) < str(b.hero_id))
	for a in allies:
		bits += "|%.3f,%.3f" % [a.position.x, a.position.y]
	return bits


class _Body:
	extends CharacterBody2D
	var facing := Vector2i.DOWN

	func set_analog(_fn: Callable, _speed: float) -> void:
		pass
