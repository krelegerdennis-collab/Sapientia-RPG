extends Node
## Co-op en solo: aanvalsheets + SomAttackAnim voor elke speelbare held (niet alleen Dax).
## Start: godot --headless --path . -- --heroattackanimtest

const Protocol := preload("res://scripts/net/net_protocol.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const Session := preload("res://scripts/net/action_coop_session.gd")

const STEPS: Array[int] = [SomChainData.STEP_HIT1, SomChainData.STEP_HIT2, SomChainData.STEP_FINISHER]

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


func _hero_ids() -> Array[String]:
	var ids: Array[String] = ["dennis", "noor", "lotte", "kael", "orion"]
	if SomData.ATTACK_ANIMS.has("seren"):
		ids.append("seren")
	return ids


func _run() -> void:
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	for id in _hero_ids():
		_coop_roster_tests(id)
		_solo_swap_tests(id)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _has_chain_textures(arena: SomArena, id: String) -> bool:
	if not arena.attack_texs.has(id):
		return false
	for step in STEPS:
		var def := arena._attack_def(id, step)
		var tex: Texture2D = arena.attack_tex_for(id, def)
		if tex == null:
			return false
	return true


func _swing_plays_anim(arena: SomArena, id: String, body: Node2D, step: int) -> bool:
	for c in body.get_children():
		if c.name == "SomAttackAnim":
			c.queue_free()
	var ret := arena._swing(id, body, 1.0, step)
	return ret == -1 and body.get_node_or_null("SomAttackAnim") != null


func _coop_roster_tests(id: String) -> void:
	if id == "dennis":
		return   # host-Dax staat al in setup; bug zit bij niet-party peers
	var boot := _coop_boot(id)
	var arena: SomArena = boot["arena"]
	check("coop %s: attack_texs hit1" % id, arena.attack_texs.has(id))
	check("coop %s: keten 3 sheets" % id, _has_chain_textures(arena, id))
	for step in STEPS:
		var st := SomChainData.state_for(step)
		check("coop %s %s: _swing SomAttackAnim" % [id, st], _swing_plays_anim(arena, id, boot["body"] as Node2D, step))
	boot["arena"].free()
	boot["room"].queue_free()


func _solo_swap_tests(id: String) -> void:
	if id == "dennis":
		return
	var boot := _solo_boot(id)
	var arena: SomArena = boot["arena"]
	var sw := arena.switch_hero(id)
	check("solo swap %s: switch_hero" % id, sw == id)
	# Lazy load op de eerste slag (niet in party bij setup)
	arena._swing(id, boot["player"] as Node2D, 1.0, SomChainData.STEP_HIT1)
	check("solo swap %s: attack_texs na swing" % id, arena.attack_texs.has(id))
	check("solo swap %s: keten 3 sheets" % id, _has_chain_textures(arena, id))
	for step in STEPS:
		var st := SomChainData.state_for(step)
		check("solo swap %s %s: _swing SomAttackAnim" % [id, st], _swing_plays_anim(arena, id, boot["player"] as Node2D, step))
	boot["arena"].free()
	boot["room"].queue_free()


func _coop_boot(hero_id: String) -> Dictionary:
	var room := _Room.new()
	room.name = "HeroAnimRoom"
	var objects := Node2D.new()
	objects.name = "Objects"
	room.add_child(objects)
	add_child(room)
	var player := _Body.new()
	player.position = Vector2(48, 80)
	player.facing = Vector2i.RIGHT
	room.add_child(player)
	room.player = player
	var arena := SomArena.new()
	arena.room = room
	arena.player = player
	arena.active_id = "dennis"
	add_child(arena)
	arena.set_process(false)
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.add_member(hero_id)
	_minimal_arena(arena)
	var sess := Session.new()
	sess.is_host = false
	sess.name = "HeroAnimCoopSess"
	add_child(sess)
	sess.set_process(false)
	var roster: Array = [
		{"slot": 0, "character_id": "dennis", "peer_id": 1},
		{"slot": 1, "character_id": hero_id, "peer_id": 2},
	]
	arena.setup_coop(sess, roster, 1)
	var body: Node2D = player
	if arena._coop_avatars.has(1):
		body = arena._coop_avatars[1] as Node2D
	return {"arena": arena, "room": room, "player": player, "body": body}


func _solo_boot(hero_id: String) -> Dictionary:
	var room := _Room.new()
	room.name = "HeroAnimSoloRoom"
	var objects := Node2D.new()
	objects.name = "Objects"
	room.add_child(objects)
	add_child(room)
	var player := _Body.new()
	player.position = Vector2(48, 80)
	player.facing = Vector2i.RIGHT
	room.add_child(player)
	room.player = player
	var arena := SomArena.new()
	arena.room = room
	arena.player = player
	add_child(arena)
	arena.set_process(false)
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	_minimal_arena(arena)
	GameState.add_member(hero_id)
	var ally: SomAlly = SomAlly.new()
	objects.add_child(ally)
	ally.setup(arena, hero_id, 0)
	arena.allies.append(ally)
	arena.allies_enabled = true
	return {"arena": arena, "room": room, "player": player}


func _minimal_arena(arena: SomArena) -> void:
	arena._ensure_actions()
	arena.active_id = GameState.active_leader()
	for id in arena._held_ids_nodig():
		arena._ensure_attack_sheets(id)


class _Room:
	extends Node2D
	var player: Node2D


class _Body:
	extends CharacterBody2D
	var facing := Vector2i.DOWN

	func set_analog(_fn: Callable, _speed: float) -> void:
		pass

	func zet_sheet(_tex: Texture2D) -> void:
		pass