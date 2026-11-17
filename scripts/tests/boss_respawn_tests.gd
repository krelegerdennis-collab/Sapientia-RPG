extends Node
## F3.9 RC: game over + respawn bij baas De Wurger (Strangler) en De Genezer (Mender) in Archief 2.
## Start: godot --path . -- --bossrespawntest
## Deel A: data (baaskamers zetten geen checkpoint, kamer ervoor wel).
## Deel B: The Strangler — verliezen, checkpoint Light Plates, baas staat er nog.
## Deel C: The Mender — verliezen, checkpoint Hall of the Mender, hub niet open.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const DungeonRoomScript := preload("res://scripts/dungeon/dungeon_room.gd")
const FlowState := preload("res://scripts/core/flow_state.gd")
const LICHT := "res://scenes/maps/archief_2_v3_licht.tscn"
const WURGER := "res://scenes/maps/archief_2_v3_wurger.tscn"
const HAL := "res://scenes/maps/archief_2_v4_hal.tscn"
const GENEZER := "res://scenes/maps/archief_2_v4_genezer.tscn"
const WURGER_VLAG := "bewaker:archief_2_v3_wurger/wurger"
const GENEZER_VLAG := "bewaker:archief_2_v4_genezer/genezer"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(3919)
	get_tree().create_timer(420.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 420 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: The Strangler ===")
	await _strangler_tests()
	print("=== Deel C: The Mender ===")
	await _mender_tests()
	print("BOSSRESPAWNTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ helpers
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


static func node_name_of(path: String) -> String:
	var out := ""
	for p in path.get_file().get_basename().split("_"):
		out += p.capitalize().replace(" ", "")
	return out


func enter(path: String, spawn: String) -> Node:
	GameState.change_map(path, spawn)
	if not await wait_scene(node_name_of(path)):
		return null
	await wait_fade()
	return scene()


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func press_interact() -> void:
	await get_tree().process_frame
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		if not Dialog.is_open:
			return
		if Dialog._is_typing():
			await frames(2)
			continue
		await press_interact()


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


func lose_battle() -> String:
	var over := ""
	Engine.time_scale = 3.0
	for guard in 200:
		var st := await wait_battle_state(["command", "message_wait"], 40)
		if st == "" or battle() == null:
			break
		var b := battle()
		if st == "command":
			for h in GameState.party:
				h["hp"] = mini(int(h["hp"]), 1)
			await cross_to(b, 3)
			await tap("interact")
		else:
			if "GAME OVER" in b.message_label.text:
				over = b.message_label.text
			await tap("interact")
	Engine.time_scale = 1.0
	return over


func setup_game(level := 8) -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(level))
	h["hp"] = h["max_hp"]
	h["mp"] = h["max_mp"]
	GameState.pending_kern_absorb = ""
	GameState.story_flags.erase(WURGER_VLAG)
	GameState.story_flags.erase(GENEZER_VLAG)
	GameState.story_flags["mender_hal_moment"] = true


func freeze_monsters(r: Node) -> void:
	if not ("monsters" in r):
		return
	for m in r.monsters:
		if is_instance_valid(m):
			m.moves = false
	await wait_until(func():
		for m in r.monsters:
			if is_instance_valid(m) and m.is_moving:
				return false
		return true, 3.0)


func full_hp_mp() -> bool:
	return GameState.party.all(func(h): return int(h["hp"]) == int(h["max_hp"]) and int(h["mp"]) == int(h["max_mp"]))


func leader_hp_ok() -> bool:
	var h: Dictionary = GameState.party[0]
	var hp := int(h.get("hp", 0))
	var mx := int(h.get("max_hp", 1))
	return hp > 0 and hp <= mx


func cp_tile() -> Vector2i:
	var t = GameState.checkpoint.get("tile", [])
	return Vector2i(int(t[0]), int(t[1])) if t is Array and t.size() >= 2 else Vector2i(-1, -1)


func spawn_of(room_id: String, spawn: String) -> Vector2i:
	var s: Array = DR.room(room_id)["spawns"][spawn]
	return Vector2i(int(s[0]), int(s[1]))


func facing_of(room_id: String, spawn: String) -> Vector2i:
	var dirs := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
	var s: Array = DR.room(room_id)["spawns"][spawn]
	return dirs[str(s[2])]


func respawn_line() -> String:
	if not await wait_until(func(): return Dialog.is_open, 3.0):
		return ""
	return str(Dialog._lines[0]) if not Dialog._lines.is_empty() else ""


func field_unlocked() -> bool:
	var p := player()
	return GameState.flow_state() == FlowState.FIELD and GameState.field_free() \
			and not Dialog.is_open and not Story.running and not GameState.in_battle \
			and (p == null or not p.input_locked)


func on_walkable_tile() -> bool:
	var s := scene()
	var t := tile()
	if s == null or not s.has_method("is_wall"):
		return false
	return not s.is_wall(t)


# ================================================================ A: data
func _data_tests() -> void:
	var wurger := DR.room("archief_2_v3_wurger")
	var genezer := DR.room("archief_2_v4_genezer")
	var licht := DR.room("archief_2_v3_licht")
	var hal := DR.room("archief_2_v4_hal")
	check("Strangler-kamer: geen checkpoint, baas in data",
			wurger.get("checkpoint", true) == false and DungeonRoomScript.is_boss_room(wurger))
	check("Mender-kamer: geen checkpoint, baas in data",
			genezer.get("checkpoint", true) == false and DungeonRoomScript.is_boss_room(genezer))
	check("Light Plates (voor Strangler) laat checkpoint toe",
			not DungeonRoomScript.is_boss_room(licht) and licht.get("checkpoint", true))
	check("Hall of the Mender (voor De Mender) laat checkpoint toe",
			not DungeonRoomScript.is_boss_room(hal) and hal.get("checkpoint", true))


# ================================================================ B: Strangler
func _strangler_tests() -> void:
	setup_game(8)
	var r := await enter(LICHT, "zuid")
	check("in Light Plates (kamer voor de Strangler)", r != null)
	if r == null:
		return
	await freeze_monsters(r)
	var sp := spawn_of("archief_2_v3_licht", "zuid")
	var fc := facing_of("archief_2_v3_licht", "zuid")
	check("checkpoint = ingang Light Plates %s" % [sp],
			GameState.checkpoint.get("map") == LICHT and cp_tile() == sp)
	var gold0 := GameState.gold
	var drank0 := GameState.item_count("drankje")
	GameState.gold += 555
	GameState.set_item_count("drankje", drank0 + 3)
	r = await enter(WURGER, "zuid")
	check("in Strangler-kamer: nog steeds checkpoint Light Plates",
			r != null and GameState.checkpoint.get("map") == LICHT and cp_tile() == sp)
	var boss: Node = r.get_monster("wurger") if r else null
	check("The Strangler staat er", boss != null and boss.boss)
	if boss == null:
		return
	r.start_monster_battle(boss)
	check("baasgevecht tegen The Strangler", await wait_scene("Battle") and GameState.pending_boss)
	var over := await lose_battle()
	check("GAME OVER-tekst: '%s'" % over.replace("\n", " / "),
			over == "GAME OVER\nThe Current pulls you back before the door.")
	check("na game over: Light Plates", await wait_scene("Archief2V3Licht"))
	await pframes(3)
	check("uitslag = lose", GameState.last_battle_result == "lose")
	check("op ingang %s (nu %s), geen muur" % [sp, tile()], tile() == sp and on_walkable_tile())
	check("kijkt omhoog naar de baas", player().facing == fc)
	check("leider HP geldig", leader_hp_ok() and full_hp_mp())
	check("voortgang terug: goud %d, drankjes %d" % [GameState.gold, GameState.item_count("drankje")],
			GameState.gold == gold0 and GameState.item_count("drankje") == drank0)
	check("Strangler niet verslagen (%s)" % WURGER_VLAG, not GameState.story_flags.has(WURGER_VLAG))
	check("last_respawn: baas, Light Plates",
			GameState.last_respawn.get("boss") == true and GameState.last_respawn.get("map") == LICHT)
	var line := await respawn_line()
	check("bericht: '%s'" % line, line == "The Current pulls you back before the door.")
	await close_dialog()
	check("na ontwaken: veld vrij (flow, dialoog, input)", field_unlocked())
	check("opslaan na respawn", GameState.save_game(tile(), player().facing))
	if FileAccess.file_exists(GameState.autosave_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.autosave_path))
	GameState.gold += 99
	GameState.continue_game()
	check("laden na respawn: Light Plates", await wait_scene("Archief2V3Licht"))
	await wait_fade()
	await close_dialog()
	check("na laden: zelfde goud als save, checkpoint Light Plates",
			GameState.gold == gold0 and GameState.checkpoint.get("map") == LICHT)
	check("na laden: veld vrij", field_unlocked())
	r = await enter(WURGER, "zuid")
	var boss2: Node = r.get_monster("wurger") if r else null
	check("Strangler-kamer opnieuw: baas staat er, gevecht kan starten",
			boss2 != null and boss2.boss and not GameState.story_flags.has(WURGER_VLAG))


# ================================================================ C: Mender
func _mender_tests() -> void:
	setup_game(8)
	var r := await enter(HAL, "zuid")
	check("in Hall of the Mender (kamer voor De Mender)", r != null)
	if r == null:
		return
	await freeze_monsters(r)
	var sp := spawn_of("archief_2_v4_hal", "zuid")
	var fc := facing_of("archief_2_v4_hal", "zuid")
	check("checkpoint = ingang Hal %s" % [sp], GameState.checkpoint.get("map") == HAL and cp_tile() == sp)
	var gold0 := GameState.gold
	r = await enter(GENEZER, "zuid")
	check("Mender-kamer: checkpoint blijft Hal", r != null and GameState.checkpoint.get("map") == HAL)
	await close_dialog()
	var boss: Node = r.get_monster("genezer") if r else null
	check("The Mender staat er", boss != null and boss.boss)
	if boss == null:
		return
	r.start_monster_battle(boss)
	check("baasgevecht tegen The Mender", await wait_scene("Battle") and GameState.pending_boss)
	var over := await lose_battle()
	check("GAME OVER-tekst: '%s'" % over.replace("\n", " / "),
			over == "GAME OVER\nThe Current pulls you back before the door.")
	check("na game over: Hall of the Mender", await wait_scene("Archief2V4Hal"))
	await pframes(3)
	check("op ingang %s (nu %s)" % [sp, tile()], tile() == sp and on_walkable_tile() and player().facing == fc)
	check("vol HP/MP, goud ongewijzigd (%d)" % GameState.gold, full_hp_mp() and GameState.gold == gold0 and leader_hp_ok())
	check("Mender niet verslagen, geen levenskern, hub dicht",
			not GameState.story_flags.has(GENEZER_VLAG) and not GameState.has_kern(Archief2.KERN_ID)
			and not GameState.world_warper_is_unlocked())
	await respawn_line()
	await close_dialog()
	check("na ontwaken: veld vrij", field_unlocked())
	check("opslaan/laden na Mender-respawn", await _save_roundtrip_hal(sp, gold0))
	r = await enter(GENEZER, "zuid")
	await close_dialog()
	var boss2: Node = r.get_monster("genezer") if r else null
	check("Mender-kamer opnieuw: baas staat er",
			boss2 != null and boss2.boss and not GameState.story_flags.has(GENEZER_VLAG))


func _save_roundtrip_hal(spawn_tile: Vector2i, gold0: int) -> bool:
	check("checkpoint Hal na respawn", GameState.checkpoint.get("map") == HAL and cp_tile() == spawn_tile)
	var pad := "user://boss_respawn_hal.json"
	var ok := GameState.save_game(tile(), player().facing, pad)
	if not ok:
		check("handmatige save na respawn", false)
		return false
	GameState.gold += 77
	GameState.story_flags["_boss_respawn_trap"] = true
	ok = GameState.load_game(pad)
	if not ok:
		check("laden save na respawn", false)
		return false
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.change_map(HAL, "zuid")
	if not await wait_scene("Archief2V4Hal"):
		check("map na laden", false)
		return false
	await wait_fade()
	var goed := GameState.gold == gold0 and not GameState.story_flags.has("_boss_respawn_trap") \
			and tile() == spawn_tile and full_hp_mp() and field_unlocked()
	check("save/load: zelfde tegel, goud, HP, veld vrij", goed)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))
	return goed