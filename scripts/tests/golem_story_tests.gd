extends Node
## Verhaal-beat na een gewonnen REALTIME Golem (arena-hook, SomArena.golem_rt_enabled): dezelfde beat als de
## turn-based winst (StoryData.GOLEM_FLAG + Golemkern + absorptie-moment), host-authoritatief en eenmalig
## (geen dubbele trigger bij opnieuw aanroepen, her-binnenkomst of een geladen save). Coop-client: niets.
## Start: godot --path . -- --golemstorytest

const SomArena := preload("res://scripts/som/som_arena.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const GolemStoryWin := preload("res://scripts/som/golem_story_win.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const SD := preload("res://scripts/data/story_data.gd")
const ROOM_SCENE := "res://scenes/maps/archief_golemhal.tscn"

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
	print("=== Golem story-events (realtime arena-winst) ===")
	var saved_rt := SomArena.golem_rt_enabled
	SomArena.golem_rt_enabled = true
	check("vlag-id = bewaker-vlag van de Golemhal", DungeonRoom.guard_flag("archief_golemhal", "golem") == SD.GOLEM_FLAG)
	var state := await _solo_win()
	await _reenter()
	await _after_load(state)
	await _coop(false)
	await _coop(true)
	SomArena.golem_rt_enabled = saved_rt
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _start() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)


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


func _kill(a: Node, m: Node) -> void:
	var f: GolemFight = a.golem_fight_of(m)
	var safety := 0
	while a.enemies.has(m) and safety < 200:
		safety += 1
		if f.is_invulnerable():
			a.step_ticks(BossPhaseMachine.INVULN_TICKS)
		a.damage_enemy(m, 5000, Vector2i.ZERO)


func _absorptions(s: Node) -> int:
	var n := 0
	for c in s.get_children():
		if c.get_script() == GolemStoryWin.KernAbsorption:
			n += 1
	return n


func _prep(s: Node) -> Array:
	var a: Node = s.get("som") if s else null
	var m := _golem(s) if s else null
	if a:
		a.allies_enabled = false
	for h in GameState.party:
		h["hp"] = 99999
	return [a, m]


## Solo: winst -> vlag + kern + absorptie-moment, één keer.
func _solo_win() -> Dictionary:
	_start()
	var s := await _laad(ROOM_SCENE)
	var am := _prep(s)
	var a: Node = am[0]
	var m: Node = am[1]
	check("solo: Golemhal + realtime Golem", a != null and m != null and a.enemies.has(m))
	if a == null or m == null:
		return {}
	check("solo: voor de winst geen vlag/kern", not GameState.story_flags.has(SD.GOLEM_FLAG) and not GameState.has_kern("golemkern"))
	_kill(a, m)
	check("solo: Golem verslagen, geen turn-based gevecht", not a.enemies.has(m) and not GameState.in_battle)
	check("solo: beat gevuurd", a.golem_story_fired)
	check("solo: GOLEM_FLAG gezet", GameState.story_flags.has(SD.GOLEM_FLAG))
	check("solo: Golemkern gegeven (bron kennis_beest)", GameState.has_kern("golemkern")
			and str(GameState.kernfragmenten["golemkern"]["bron"]) == "kennis_beest")
	check("solo: absorptie-moment gestart (1x)", GameState.pending_kern_absorb == "golemkern" and _absorptions(s) == 1)
	check("solo: tweede aanroep doet niets", not GolemStoryWin.apply("archief_golemhal", "golem", "kennis_beest", s) and _absorptions(s) == 1)
	# absorptie laten aflopen
	for i in 600:
		if GameState.pending_kern_absorb == "":
			break
		if Dialog.is_open and i % 10 == 0:
			Dialog.advance()
		await get_tree().process_frame
	check("solo: absorptie-moment klaar", GameState.pending_kern_absorb == "")
	for i in 60:
		await get_tree().process_frame
	var p: Node = s.get_node("Objects/Player")
	return GameState.state_data(p.get_tile(), Vector2i.UP, ROOM_SCENE)


## Her-binnenkomst: Golem weg, niets opnieuw.
func _reenter() -> void:
	var kern_before: Dictionary = GameState.kernfragmenten.duplicate(true)
	var s := await _laad(ROOM_SCENE)
	check("terug: Golem staat er niet meer", s != null and _golem(s) == null)
	check("terug: geen nieuw absorptie-moment", s != null and _absorptions(s) == 0 and GameState.pending_kern_absorb == "")
	check("terug: kernen ongewijzigd", GameState.kernfragmenten == kern_before)


## Geladen save: vlag + kern blijven, geen tweede trigger.
func _after_load(state: Dictionary) -> void:
	_start()
	check("save: state_data niet leeg", not state.is_empty())
	GameState.apply_state(state)
	check("save: vlag + kern na laden", GameState.story_flags.has(SD.GOLEM_FLAG) and GameState.has_kern("golemkern"))
	var s := await _laad(ROOM_SCENE)
	check("save: Golem weg na laden", s != null and _golem(s) == null)
	check("save: geen absorptie na laden", s != null and _absorptions(s) == 0 and GameState.pending_kern_absorb == "")
	check("save: apply opnieuw doet niets", not GolemStoryWin.apply("archief_golemhal", "golem", "kennis_beest", s))


## Coop: alleen de host zet de beat.
func _coop(host: bool) -> void:
	var tag := "host" if host else "client"
	_start()
	var s := await _laad(ROOM_SCENE)
	var am := _prep(s)
	var a: Node = am[0]
	var m: Node = am[1]
	if a == null or m == null:
		check("coop %s: arena" % tag, false)
		return
	a.coop_mode = true
	a.coop_sim_host = host
	_kill(a, m)
	check("coop %s: Golem verslagen" % tag, not a.enemies.has(m))
	check("coop %s: beat %s" % [tag, "gezet" if host else "niet gezet"],
			GameState.story_flags.has(SD.GOLEM_FLAG) == host and GameState.has_kern("golemkern") == host and a.golem_story_fired == host)
	a.coop_mode = false
	GameState.pending_kern_absorb = ""
