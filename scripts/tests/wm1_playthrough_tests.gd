extends Node
## WM1-playthrough (release-fase 3, stabiliteit): een volledig World Map 1-pad, van "Nieuw spel" tot
## het einde van WM1 (De Mender verslagen, World Warper-hub open, scènes 1 t/m 3 gezien).
## Start: godot --path . -- --wm1playthroughtest [--shots=/pad/map]
##
## Wat de suite doet (alles met de echte scènes, het echte verhaal en de echte save-code):
##   * speelt de proloog, Archief 1 (Golem), Esdoorn + Donker Woud (Vesper), het Zingende Graan, de
##     berggrot, Archief 2 (Seren, Strangler, Mender) en de hub; kamers worden echt gelopen (BFS-pad
##     met toetsen) en uitgangen gaan via de echte MapExit-code
##   * slaat op en laadt op meerdere punten (state_data voor en na moet gelijk zijn) en stuurt
##     NOTIFICATION_APPLICATION_PAUSED / RESUMED in alle soorten toestand (vrij, tekstvak, cutscene,
##     gevecht, scènewissel, halverwege een stap), plus 'app gedood' en verdergaan met de autosave
##   * meldt softlocks (settle() haalt de wereld niet meer in rust), voortgangsblokkades (poort,
##     uitgang of spawn die niet werkt, kamer waar je niet uit kunt) en spelertekst die niet Engels is
##   * crashes en SCRIPT ERROR-regels pakt .github/scripts/run_suite.sh op (grep op het logbestand)
## Gevechten: vijanden op 1 HP, daarna gewoon via het gevechtsscherm winnen (zoals woud_tests).
## Elke FAIL-regel draagt een label [SOFTLOCK], [BLOCKER], [SAVE], [PAUSE], [TEKST] of [STATE].

const SD := preload("res://scripts/data/story_data.gd")
const GD := preload("res://scripts/data/game_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const PuzzleRooms := preload("res://scripts/data/puzzle_rooms.gd")
const WoudRooms := preload("res://scripts/data/woud_rooms.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const Archief2 := preload("res://scripts/data/archief2.gd")
const Archief2Rooms := preload("res://scripts/data/archief2_rooms.gd")
const Equipment := preload("res://scripts/equipment.gd")
const WarperUnlock := preload("res://world_warper/flow/unlock.gd")
const WarperCanon := preload("res://world_warper/cutscene/canon_scenes.gd")
const PuzzleLogic := preload("res://scripts/puzzle/puzzle_logic.gd")
const GenezerScene := preload("res://world_warper/cutscene/genezer_scene.gd")
const NaGenezer := preload("res://world_warper/flow/na_genezer.gd")

const M := "res://scenes/maps/"
const WORLD := M + "wereldkaart.tscn"
const HUIS := M + "huis_wilgendal.tscn"
const ERF := M + "wilgendal.tscn"
const DORP := M + "dorp_wilgendal.tscn"
const ESDOORN := M + "esdoorn.tscn"
const GOLEMHAL := M + "archief_golemhal.tscn"
const ARCHIEF_INGANG := M + "archief_ingang.tscn"
const WOUD_OPEN := M + "woud_open_plek.tscn"
const GENEZER := M + "archief_2_v4_genezer.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
## Action-stijl: bondgenoten vechten zelf, dus beloning en groep veranderen tussen twee momentopnames.
const VOLATILE := ["bestiary", "gold", "party", "inventory", "codex"]
const DIRS := {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
## Nederlandse functiewoorden: spelertekst is Engels (AGENTS.md regel 3).
const DUTCH_WORDS := "de|het|een|je|niet|geen|wordt|maar|voor|naar|nog|ook|deze|zijn|heeft|kunt|vecht|mee|alleen|stap|erop"

var failures := 0
var passes := 0
var shots := ""
var categories := {}
var choice_plan: Array = []
var texts_seen := {}
var milestones: Array = []
var _dutch: RegEx
var _walk_speed := 4.0
var _base_scale := 2.0
var _t_start := Time.get_ticks_msec()
var _snap_after_golem := PackedByteArray()
var _variant := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--speed="):
			_base_scale = clampf(float(arg.get_slice("=", 1)), 1.0, 4.0)
	_dutch = RegEx.new()
	_dutch.compile("(?i)\\b(%s)\\b" % DUTCH_WORDS)
	seed(1234)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1
		var tag := label.get_slice("]", 0).trim_prefix("[") if label.begins_with("[") else "ALGEMEEN"
		categories[tag] = int(categories.get(tag, 0)) + 1


func milestone(id: String) -> void:
	milestones.append(id)
	print("TIJD %s: %.0f s" % [id, (Time.get_ticks_msec() - _t_start) / 1000.0])
	print("MILESTONE %s (stap %d, kaart %s)" % [id, GameState.story_step, str(GameState.current_map).get_file()])


# ================================================================ hulpjes
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


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


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


func wait_path(path: String, timeout := 20.0) -> bool:
	var ok := await wait_until(func():
		var s := scene()
		return s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map, timeout)
	if ok:
		await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
		await pframes(2)
	return ok


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


func note_text(text: String, label := "") -> void:
	var t := text.strip_edges()
	if t == "" or texts_seen.has(t):
		return
	texts_seen[t] = label
	if _dutch.search(t) != null:
		check("[TEKST] spelertekst is Nederlands: \"%s\" (%s)" % [t.left(90), label], false)


func note_dialog() -> void:
	for l in Dialog._lines:
		note_text(str(l), "dialoog op %s" % str(GameState.current_map).get_file())
	for c in Dialog.choices:
		note_text(str(c), "keuze")


func state_line() -> String:
	return "dialoog=%s story=%s event=%s changing=%s battle=%s kern=%s sched=%s lock=%s scene=%s" % [
			Dialog.is_open, Story.running, Story.current_event, GameState.changing_map, GameState.in_battle,
			GameState.pending_kern_absorb, not Story.scheduled.is_empty(),
			player().input_locked if player() != null else "geen speler", str(scene().scene_file_path).get_file() if scene() else "geen"]


## Wacht tot de wereld in rust is (geen tekst, event, overgang, gevecht, kernabsorptie) en klikt
## intussen tekst door (keuzes via choice_plan). Een gevecht dat vanzelf start wordt gewonnen.
## Lukt dat binnen 'timeout' niet, dan is dat een softlock: label + toestand worden gemeld.
func settle(label: String, timeout := 45.0, auto_battle := true, grace := 0.0) -> bool:
	var t0 := Time.get_ticks_msec()
	var quiet := 0
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if battle() != null or GameState.in_battle:
			if auto_battle and battle() != null:
				await win_battle()
				quiet = 0
				continue
			await get_tree().process_frame
			continue
		if Dialog.is_open:
			quiet = 0
			note_dialog()
			if Dialog._is_typing():
				Dialog.advance()
				await frames(1)
			elif Dialog.has_choices():
				var i := int(choice_plan.pop_front()) if not choice_plan.is_empty() else 0
				Dialog.choose(clampi(i, 0, Dialog.choices.size() - 1))
				await pframes(2)
			else:
				await press_interact()
			continue
		var busy := Story.running or GameState.changing_map or not Story.scheduled.is_empty() \
				or str(GameState.pending_kern_absorb) != "" or Transition._rect.color.a > 0.01 \
				or scene() == null or not scene().is_node_ready()
		if not busy and scene() != null:
			for c in scene().get_children():
				var sc = c.get_script()
				if sc != null and str(sc.resource_path).ends_with("kern_absorption.gd"):
					busy = true
		if busy:
			quiet = 0
		else:
			quiet += 1
			if quiet > 20 and Time.get_ticks_msec() - t0 >= grace * 1000.0:
				var p := player()
				if p != null and p.input_locked and not p.is_moving:
					# sommige scènes geven de speler pas na een timer weer vrij
					await wait_until(func(): return not p.input_locked or Dialog.is_open or Story.running, 3.0)
					if p.input_locked and not Dialog.is_open and not Story.running:
						check("[SOFTLOCK] %s: speler blijft vergrendeld (%s)" % [label, state_line()], false)
						p.input_locked = false
						return false
				return true
		await get_tree().process_frame
	check("[SOFTLOCK] %s: wereld komt niet in rust (%s)" % [label, state_line()], false)
	return false


## Winnen zoals een speler (Aanval op de eerste vijand), de vijanden op 1 HP.
func win_battle() -> bool:
	var won := false
	var prev := Engine.time_scale
	Engine.time_scale = 3.0
	for guard in 120:
		var st := await wait_battle_state(["command", "target_enemy", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if b == null:
			break
		if st == "command":
			for e in b.enemies:
				e["s"]["hp"] = mini(int(e["s"]["hp"]), 1)
			# het gaat om de voortgang, niet om de balans (die heeft eigen suites): niemand valt om
			for h in GameState.party:
				h["hp"] = h["max_hp"]
			await cross_to(b, 0)
			await tap("interact")
		else:
			if b.victory_panel.visible:
				won = true
			await tap("interact")
	Engine.time_scale = prev
	if not won:
		await wait_until(func(): return battle() == null and not GameState.in_battle, 8.0)
		won = GameState.last_battle_result == "win"
		if not won:
			print("INFO  win_battle: resultaat '%s', groep %s, kaart %s" % [GameState.last_battle_result,
					GameState.party.map(func(h): return "%s %d/%d" % [h["id"], int(h["hp"]), int(h["max_hp"])]), str(scene().scene_file_path).get_file() if scene() else "?"])
	return won


## Verliezen zoals een speler: HP op 1 en verdedigen tot de baas de groep velt.
func lose_battle() -> bool:
	var prev := Engine.time_scale
	Engine.time_scale = 3.0
	for guard in 60:
		var st := await wait_battle_state(["command", "target_enemy", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if b == null:
			break
		if st == "command":
			for h in GameState.party:
				h["hp"] = 1
			for c in b.heroes:
				if c.has("hp") and not bool(c.get("ally", false)):
					c["hp"] = 1
			await cross_to(b, 3)
			await tap("interact")
		else:
			await tap("interact")
	Engine.time_scale = prev
	await wait_until(func(): return battle() == null and not GameState.in_battle, 10.0)
	return GameState.last_battle_result == "lose" or GameState.last_battle_result == "story"


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


## Gevecht starten via de kamer (zoals aanraken) en wachten tot de gevechtsscène er staat; een
## tekstvak vooraf (Seren-gevecht) wordt doorgeklikt.
func fight_monster(room: Node, monster_id: String) -> bool:
	var m: Node = room.get_monster(monster_id)
	if m == null:
		check("[BLOCKER] monster %s ontbreekt in %s" % [monster_id, room.room_id], false)
		return false
	room.start_monster_battle(m)
	await pframes(2)
	check("[STATE] gevecht met %s begint pas als er geen tekstvak meer open staat (%s)" % [monster_id, Dialog._lines if Dialog.is_open else ""],
			not (GameState.in_battle and Dialog.is_open))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		if battle() != null and battle().is_node_ready():
			await pframes(8)
			check("[STATE] geen tekstvak dat het gevecht met %s overlapt (%s)" % [monster_id, Dialog._lines if Dialog.is_open else ""], not Dialog.is_open)
			return true
		if Dialog.is_open and battle() == null:
			note_dialog()
			if Dialog._is_typing():
				Dialog.advance()
				await frames(1)
			elif Dialog.has_choices():
				Dialog.choose(0)
				await pframes(2)
			else:
				await press_interact()
			continue
		await get_tree().process_frame
	check("[SOFTLOCK] gevecht met %s start niet (%s)" % [monster_id, state_line()], false)
	return false


func heal_party() -> void:
	for h in GameState.party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]


# ---------------------------------------------------------------- kaarten en uitgangen
func goto(path: String, spawn: String) -> Node:
	GameState.changing_map = false
	GameState.change_map(path, spawn)
	if not await wait_path(path):
		check("[BLOCKER] kaart %s laadt niet (spawn %s)" % [path.get_file(), spawn], false)
		return null
	return scene()


## Stap op een uitgang van de huidige kaart met de echte code (player.stepped -> map._use_exit).
func use_exit(exit_name: String) -> bool:
	var s := scene()
	var e: Node = s.get_node_or_null("Exits/" + exit_name) if s != null else null
	if e == null:
		check("[BLOCKER] uitgang %s bestaat niet op %s" % [exit_name, s.scene_file_path.get_file() if s else "?"], false)
		return false
	var t: Vector2i = e.tile_rect().position
	var p := player()
	p.input_locked = false
	p.place_at(t, p.facing)
	p.stepped.emit(t)
	await pframes(2)
	return true


## Loop naar een uitgang van het type 'target_map' en wacht tot die kaart er staat. Controleert
## dat de speler op het genoemde spawnpunt staat.
func through(exit_name: String, expect_path: String) -> bool:
	var s := scene()
	var e: Node = s.get_node_or_null("Exits/" + exit_name) if s != null else null
	var spawn := str(e.target_spawn) if e != null and "target_spawn" in e else ""
	if not await use_exit(exit_name):
		return false
	var ok := await wait_path(expect_path)
	check("[BLOCKER] uitgang %s -> %s" % [exit_name, expect_path.get_file()], ok)
	if not ok:
		return false
	if spawn != "":
		var sp: Node2D = scene().get_spawn(spawn)
		check("[BLOCKER] spawn '%s' bestaat in %s" % [spawn, expect_path.get_file()], sp != null)
	await settle("aankomst %s" % expect_path.get_file(), 45.0, true, 0.6)
	if scene().has_method("start_invuln"):
		await quiet_room(scene())
	return true


func obj(node_name: String) -> Node:
	var s := scene()
	return s.get_node_or_null("Objects/" + node_name) if s != null else null


## Praat met een object: speler op 'stand', kijkend naar 'face', dan A (echte interactie).
func talk(node_name: String, stand: Vector2i, face: Vector2i) -> bool:
	var n := obj(node_name)
	var p := player()
	if n == null or p == null:
		check("[BLOCKER] %s niet te vinden op %s" % [node_name, str(GameState.current_map).get_file()], false)
		return false
	p.input_locked = false
	p.place_at(stand, face)
	await frames(3)
	await press_interact()
	return true


# ---------------------------------------------------------------- lopen
func blocked_tiles(s: Node) -> Dictionary:
	var out := {}
	var objects := s.get_node_or_null("Objects")
	if objects == null:
		return out
	for c in objects.get_children():
		if not (c is StaticBody2D) or not c.visible:
			continue
		if str(c.name).begins_with("Monster_") and c.has_method("get_state") and not bool(c.get("boss")):
			continue
		for cs in c.get_children():
			if cs is CollisionShape2D and not cs.disabled and cs.shape is RectangleShape2D:
				var half: Vector2 = (cs.shape as RectangleShape2D).size / 2.0
				var centre: Vector2 = c.position + cs.position
				var a := Vector2i(((centre - half + Vector2(1, 1)) / 16.0).floor())
				var b := Vector2i(((centre + half - Vector2(1, 1)) / 16.0).floor())
				for x in range(a.x, b.x + 1):
					for y in range(a.y, b.y + 1):
						out[Vector2i(x, y)] = true
	for n in get_tree().get_nodes_in_group("dungeon_blokkade"):
		out[Vector2i((n.position / 16.0).floor())] = true
	return out


func is_free_tile(s: Node, t: Vector2i, blocked: Dictionary) -> bool:
	if blocked.has(t):
		return false
	if s.get("logic") != null:
		var lg = s.logic
		return lg.inside(t) and (not lg.is_solid(t) or lg.exits.has(t))
	if s.has_method("is_wall"):
		return not s.is_wall(t)
	var data := (s.ground as TileMapLayer).get_cell_tile_data(t)
	if data == null or data.get_collision_polygons_count(0) > 0:
		return false
	var top := s.get_node_or_null("Gebouwen") as TileMapLayer
	if top != null:
		var td := top.get_cell_tile_data(t)
		if td != null and td.get_collision_polygons_count(0) > 0:
			return false
	return true


## Kortste pad (richtingen) van 'from' naar een tegel in 'goal'; leeg = geen pad, null = al daar.
func find_path(s: Node, from: Vector2i, goal: Rect2i) -> Variant:
	if goal.has_point(from):
		return []
	var blocked := blocked_tiles(s)
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = cur + d
			if prev.has(n):
				continue
			var inside_goal := goal.has_point(n)
			if not inside_goal and not is_free_tile(s, n, blocked):
				continue
			if inside_goal and blocked.has(n):
				continue
			prev[n] = cur
			if inside_goal:
				var path: Array[Vector2i] = []
				var t := n
				while t != from:
					path.push_front(t - prev[t])
					t = prev[t]
				return path
			queue.append(n)
	return null


## Action-stijl: vrije beweging; toets vasthouden tot het midden van de volgende tegel.
func step_dir_analog(p: CharacterBody2D, d: Vector2i) -> bool:
	var scene_before := scene()
	var target: Vector2i = p.get_tile() + d
	var center := Vector2(target) * 16.0 + Vector2(8, 8)
	var action: String = DIRS[d]
	Input.action_press(action)
	var n := 0
	while n < 90 and is_instance_valid(p) and scene() == scene_before and not GameState.changing_map and not GameState.in_battle:
		var diff := center - p.position
		var along := diff.x * d.x + diff.y * d.y
		if along <= 1.0:
			break
		await get_tree().physics_frame
		n += 1
	Input.action_release(action)
	await get_tree().physics_frame
	if GameState.changing_map or GameState.in_battle or scene() != scene_before or not is_instance_valid(p):
		return true
	return p.get_tile() == target


func step_dir(d: Vector2i) -> bool:
	var p := player()
	if p == null:
		return false
	if p.analog_input.is_valid():
		return await step_dir_analog(p, d)
	var scene_before := scene()
	var from: Vector2i = p.get_tile()
	var action: String = DIRS[d]
	Input.action_press(action)
	var waited := 0
	while is_instance_valid(p) and not p.is_moving and waited < 8:
		await get_tree().physics_frame
		waited += 1
	Input.action_release(action)
	while is_instance_valid(p) and p.is_moving:
		await get_tree().physics_frame
	if GameState.changing_map or GameState.in_battle or scene() != scene_before or not is_instance_valid(p):
		return true
	return p.get_tile() == from + d


## Echt lopen (toetsen) naar een uitgangszone. false = geen pad of vast komen te zitten.
func walk_to_exit(exit_name: String, label: String) -> bool:
	var s := scene()
	var e: Node = s.get_node_or_null("Exits/" + exit_name)
	var goal: Rect2i = e.tile_rect()
	var path = find_path(s, tile(), goal)
	if path == null:
		check("[BLOCKER] %s: geen pad naar uitgang %s vanaf %s" % [label, exit_name, tile()], false)
		return false
	var prev_scale := Engine.time_scale
	Engine.time_scale = _walk_speed
	player().input_locked = false
	var steps := 0
	for d in path:
		if player() == null or GameState.changing_map:
			break
		var ok := await step_dir(d)
		steps += 1
		if not ok:
			Engine.time_scale = prev_scale
			check("[BLOCKER] %s: vast op %s richting %s (uitgang %s)" % [label, tile(), d, exit_name], false)
			return false
	Engine.time_scale = prev_scale
	return true


## De kamer begaanbaar maken voor de wandeling: gewone monsters weg (ze versperren een gang),
## bewakers en bazen blijven staan. Het vechten zelf wordt apart getest (fight_monster).
func quiet_room(s: Node) -> void:
	if s.has_method("start_invuln"):
		s.start_invuln(900.0)
		s.player.sprite.modulate.a = 1.0
	var mons = s.get("monsters")
	if mons == null:
		return
	for m in (mons as Array).duplicate():
		if is_instance_valid(m) and not bool(m.data.get("guard", false)) and not bool(m.boss):
			(mons as Array).erase(m)
			m.queue_free()
	await pframes(2)


# ---------------------------------------------------------------- opslaan en laden
func norm(d: Dictionary) -> String:
	var c := d.duplicate(true)
	for k in ["play_time", "saved_at", "saved_unix", "game_version"]:
		c.erase(k)
	return JSON.stringify(JSON.parse_string(JSON.stringify(c)), "", true)


func diff_keys(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	var ja = JSON.parse_string(JSON.stringify(a))
	var jb = JSON.parse_string(JSON.stringify(b))
	for k in ja:
		if str(k) in ["play_time", "saved_at", "saved_unix", "game_version"]:
			continue
		if JSON.stringify(ja[k], "", true) != JSON.stringify(jb.get(k), "", true):
			out.append(k)
	for k in jb:
		if not ja.has(k) and not (str(k) in ["play_time", "saved_at", "saved_unix", "game_version"]):
			out.append(k)
	return out


## Opslaan in 'slot', alles wissen (nieuw spel) en 'Doorgaan' via de echte slotlijst-code: de staat
## na het laden moet gelijk zijn aan die ervoor, en de speler moet vrij kunnen bewegen.
func save_roundtrip(label: String, slot := 1, expect_path := "", volatile := false) -> bool:
	var p := player()
	if p == null:
		check("[SAVE] %s: geen speler om op te slaan" % label, false)
		return false
	var want_path := expect_path if expect_path != "" else str(scene().scene_file_path)
	GameState.active_slot = slot
	var t: Vector2i = p.get_tile()
	var f: Vector2i = p.facing
	var before := GameState.state_data(t, f)
	check("[SAVE] %s: opslaan lukt" % label, GameState.save_game(t, f))
	var file_data := GameState.read_save(GameState.slot_path(slot))
	check("[SAVE] %s: bestand leesbaar met versie %d" % [label, GameState.SAVE_VERSION],
			not file_data.is_empty() and int(file_data.get("version", -1)) == GameState.SAVE_VERSION)
	GameState.new_game("Wis")
	GameState.encounter_multiplier = 0.0
	check("[SAVE] %s: nieuw spel wist de voortgang" % label, GameState.story_flags.is_empty() and GameState.story_step == SD.START)
	GameState.changing_map = false
	GameState.in_battle = false
	var ok: bool = await GameState.continue_slot(slot)
	check("[SAVE] %s: Doorgaan laadt slot %d" % [label, slot], ok)
	if not ok:
		return false
	var arrived := await wait_path(want_path)
	check("[SAVE] %s: terug op %s" % [label, want_path.get_file()], arrived)
	if not arrived:
		return false
	await settle("na laden %s" % label, 45.0, true, 0.6)
	var p2 := player()
	var after := GameState.state_data(p2.get_tile() if p2 else Vector2i.ZERO, p2.facing if p2 else Vector2i.DOWN)
	var diff := diff_keys(before, after)
	diff.erase("checkpoint")
	if volatile:
		for k in VOLATILE:
			diff.erase(k)
	check("[SAVE] %s: state_data gelijk na laden (verschil: %s)" % [label, diff], diff.is_empty())
	check("[SAVE] %s: speler staat op dezelfde tegel %s -> %s" % [label, t, p2.get_tile() if p2 else "?"], p2 != null and p2.get_tile() == t)
	check("[SAVE] %s: verhaal niet blijven hangen na laden" % label, not Story.running and not Dialog.is_open and not GameState.in_battle)
	return true


## Pauze/hervat zoals Android doet. 'expect_save' = er hoort een autosave "achtergrond" te komen.
func pause_resume(label: String, expect_save: bool, volatile := false) -> void:
	var n0 := GameState.autosave_count
	var before := GameState.state_data(tile(), player().facing if player() else Vector2i.DOWN)
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await pframes(3)
	var n1 := GameState.autosave_count
	check("[PAUSE] %s: autosave bij pauze = %s (was %d, nu %d)" % [label, expect_save, n0, n1], (n1 == n0 + 1) == expect_save and n1 <= n0 + 1)
	if expect_save:
		check("[PAUSE] %s: reden = achtergrond" % label, GameState.last_autosave_reason == "achtergrond")
		var rec := GameState.autosave_record()
		check("[PAUSE] %s: autosave leesbaar en op deze kaart" % label,
				not rec.is_empty() and str(rec.get("data", {}).get("map", "")) == str(scene().scene_file_path))
		var saved: Dictionary = rec.get("data", {})
		var diff := diff_keys(before, saved)
		for k in ["checkpoint", "slot", "home_slot", "autosave"]:
			diff.erase(k)
		if volatile:
			for k in VOLATILE:
				diff.erase(k)
		check("[PAUSE] %s: autosave = staat op het moment van pauze (verschil: %s)" % [label, diff], diff.is_empty())
	GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await pframes(3)
	var after := GameState.state_data(tile(), player().facing if player() else Vector2i.DOWN)
	var d2 := diff_keys(before, after)
	if volatile:
		for k in VOLATILE:
			d2.erase(k)
	check("[PAUSE] %s: hervatten verandert de voortgang niet (verschil: %s)" % [label, d2], d2.is_empty())


## Pauze terwijl de speler halverwege een stap is: geen autosave (niet op een halve tegel), geen crash.
func pause_mid_step(label: String) -> void:
	var p := player()
	var s := scene()
	if p == null or s == null:
		return
	var blocked := blocked_tiles(s)
	var exits: Array = []
	for e in s.get_node("Exits").get_children():
		if e.has_method("tile_rect"):
			exits.append(e.tile_rect())
	for d in DIRS:
		var n: Vector2i = p.get_tile() + d
		if not is_free_tile(s, n, blocked) or exits.any(func(r): return (r as Rect2i).has_point(n)):
			continue
		var n0 := GameState.autosave_count
		Input.action_press(DIRS[d])
		var waited := 0
		while not p.is_moving and waited < 10:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(DIRS[d])
		if p.is_moving:
			GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			await get_tree().process_frame
			check("[PAUSE] %s: geen autosave halverwege een stap" % label, GameState.autosave_count == n0)
			GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		else:
			check("[PAUSE] %s: stap kon niet gestart worden" % label, false)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		await settle("na pauze halverwege een stap %s" % label)
		return


## Pauze tijdens een kaartwissel (fade): geen autosave op een kaart die net verdwijnt.
func pause_during_transition(exit_name: String, expect_path: String, label: String) -> void:
	var n0 := GameState.autosave_count
	await use_exit(exit_name)
	if GameState.changing_map:
		GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await get_tree().process_frame
		check("[PAUSE] %s: geen autosave tijdens de kaartwissel" % label, GameState.autosave_count == n0)
		GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var ok := await wait_path(expect_path)
	check("[PAUSE] %s: kaartwissel loopt door na pauze/hervatten" % label, ok)
	await settle("na pauze in de kaartwissel %s" % label, 45.0, true, 0.6)


## Veldmenu met elk onderdeel openen en weer sluiten (B/cancel): een scherm dat crasht of niet dicht
## wil is een softlock. Dit loopt op de staat van dat moment (kernen, Codex, groep, vlaggen).
func menu_sweep(label: String) -> void:
	var s := scene()
	var p := player()
	if s == null or p == null or not s.has_method("open_field_menu"):
		check("[SOFTLOCK] %s: geen kaart met veldmenu" % label, false)
		return
	p.input_locked = false
	s.open_field_menu()
	await pframes(4)
	var m := s.get_node_or_null("FieldMenu")
	check("[SOFTLOCK] %s: veldmenu opent" % label, m != null)
	if m == null:
		return
	var ids: Array = (m.commands() as Array).map(func(c): return str(c[0]))
	var opened := 0
	for id in ids:
		if id in ["save", "load", "close", "warp"] or not is_instance_valid(m):
			continue
		m.choose(id)
		await pframes(6)
		if m.sub == null:
			continue
		opened += 1
		var tries := 0
		while is_instance_valid(m) and m.sub != null and tries < 8:
			await tap("cancel")
			tries += 1
		check("[SOFTLOCK] %s: menu-onderdeel '%s' gaat met B weer dicht" % [label, id], not is_instance_valid(m) or m.sub == null)
	check("[SOFTLOCK] %s: %d menu-onderdelen geopend (%s)" % [label, opened, ids], opened >= 6)
	if is_instance_valid(m):
		m.close()
	await pframes(4)
	check("[SOFTLOCK] %s: veldmenu sluit en de speler is weer vrij" % label, s.get_node_or_null("FieldMenu") == null and not p.input_locked)


## Dev: alleen het veldmenu, op een late WM1-staat (--menu-only).
func menu_only() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NOOR_GERED
	for f in [SD.GOLEM_FLAG, "noor_gered", "noor_lid", "archief_gezien", "quest_noor", "noor_ontmoet"]:
		GameState.story_flags[f] = true
	GameState.join_member("noor", 8, ["eiken_staf", "reisgewaad"])
	GameState.join_member("lotte", 8, [])
	GameState.grant_kern(Archief2.KERN_ID, "genezer")
	GameState.codex_add("mosslijm", 3)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	var w := await goto(WORLD, "van_dorp")
	if w != null:
		await settle("menu-only", 45.0, true, 0.8)
		await menu_sweep("menu-only")


# ================================================================ statische audit
func collect_strings(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for x in v:
			collect_strings(x, out)
	elif v is Dictionary:
		for k in v:
			collect_strings(v[k], out)


func story_texts(cmds: Array, out: Array) -> void:
	for raw in cmds:
		if not (raw is Array) or raw.is_empty():
			continue
		match str(raw[0]):
			"say":
				collect_strings(raw[2], out)
			"choice":
				out.append(str(raw[1]))
				collect_strings(raw[2], out)
			"card":
				out.append(str(raw[1]))
			"if":
				for i in range(2, raw.size()):
					if raw[i] is Array:
						story_texts(raw[i], out)


func room_texts(rooms: Dictionary, out: Array) -> void:
	for id in rooms:
		_walk_lines(rooms[id], out)


func _walk_lines(v, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			var key := str(k)
			if (key.ends_with("lines") or key == "hint" or key == "text") and (v[k] is Array or v[k] is String):
				collect_strings(v[k], out)
			else:
				_walk_lines(v[k], out)
	elif v is Array:
		for x in v:
			_walk_lines(x, out)


func static_audit() -> void:
	print("=== statische audit: spelertekst en kamerdata ===")
	var texts: Array = []
	for ev in SD.EVENTS:
		for variant in SD.EVENTS[ev]:
			if variant.get("do") is Array:
				story_texts(variant["do"], texts)
	room_texts(DungeonRooms.ROOMS, texts)
	room_texts(Archief2Rooms.ROOMS, texts)
	room_texts(Archief2Rooms.rooms(), texts)
	room_texts(WoudRooms.ROOMS, texts)
	room_texts(BerggrotData.ROOMS, texts)
	room_texts(BerggrotData.PUZZLES, texts)
	room_texts(PuzzleRooms.ROOMS, texts)
	for script in [Archief2, SD, WarperCanon]:
		var consts: Dictionary = script.get_script_constant_map()
		for k in consts:
			if consts[k] is Array and not (consts[k] as Array).is_empty() and (consts[k] as Array)[0] is String:
				collect_strings(consts[k], texts)
	for t in texts:
		note_text(str(t), "data")
	# Dialog.show_lines/ask met een letterlijke tekst in WM1-code
	var rx := RegEx.new()
	rx.compile("Dialog\\.(?:show_lines|ask)\\(\\s*\\[?\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	var dirs := ["res://scripts/dungeon/", "res://scripts/puzzle/", "res://scripts/village/", "res://scripts/kern/",
			"res://scripts/data/", "res://world_warper/"]
	for dir in dirs:
		for f in _gd_files(dir):
			var src := FileAccess.get_file_as_string(f)
			for m in rx.search_all(src):
				note_text(m.get_string(1), f.get_file())
	check("statische audit: %d teksten gecontroleerd" % texts_seen.size(), texts_seen.size() > 50)
	room_data_audit()


## Kamerdata die in dungeon_room.gd _build() een push_error geeft (en dus in de CI-log verdwijnt):
## teken zonder legenda en een uitgangsteken zonder doel in "exits". Spiegelt die code.
func room_data_audit() -> void:
	var bad := []
	var sets := {"archief": DungeonRooms.ROOMS, "archief2": Archief2Rooms.ROOMS, "archief2+": Archief2Rooms.rooms(),
			"woud": WoudRooms.ROOMS, "berggrot": BerggrotData.ROOMS}
	var n_rooms := 0
	for set_name in sets:
		var rooms: Dictionary = sets[set_name]
		for id in rooms:
			var room: Dictionary = rooms[id]
			if not room.has("layout"):
				continue
			n_rooms += 1
			var legend := DungeonRooms.legend_of(room)
			var exits: Dictionary = room.get("exits", {})
			if exits.is_empty() and room.has("exit"):
				exits = {"E": room["exit"]}
			var keys := {}
			for y in (room["layout"] as Array).size():
				var row: String = room["layout"][y]
				for x in row.length():
					var ch := row[x]
					if not legend.has(ch):
						bad.append("%s: onbekend teken '%s' op (%d,%d)" % [id, ch, x, y])
					elif DungeonRooms.EXIT_CHARS.has(ch):
						keys[DungeonRooms.EXIT_CHARS[ch]] = true
			for k in keys:
				if exits.get(k, {}).is_empty() and (room.get("decor_exits", []) as Array).has(k):
					continue
				if exits.get(k, {}).is_empty():
					bad.append("%s: uitgang '%s' heeft geen doel in \"exits\"" % [id, k])
				else:
					var target := str(exits[k].get("map", ""))
					if target != "" and not ResourceLoader.exists(target):
						bad.append("%s: uitgang '%s' wijst naar een scène die niet bestaat (%s)" % [id, k, target])
	check("[BLOCKER] kamerdata: %d WM1-dungeonkamers zonder onbekend teken of uitgang zonder doel %s" % [n_rooms, bad], bad.is_empty() and n_rooms > 25)


func _gd_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + d + "/"))
	return out


# ================================================================ het spel
func _run() -> void:
	Engine.time_scale = _base_scale
	GameState.encounter_multiplier = 0.0
	static_audit()
	if "--static-only" in OS.get_cmdline_user_args():
		print("WM1PLAYTHROUGHTEST %d PASS, %d FAIL (alleen statische audit)" % [passes, failures])
		print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
		get_tree().quit(1 if failures else 0)
		return
	if "--menu-only" in OS.get_cmdline_user_args():
		await menu_only()
		print("WM1PLAYTHROUGHTEST %d PASS, %d FAIL (alleen veldmenu)" % [passes, failures])
		print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
		get_tree().quit(1 if failures else 0)
		return
	await stage_prologue()
	await stage_archief1()
	await stage_esdoorn_woud()
	await stage_graan()
	await stage_greenhouse_route()
	await stage_berggrot()
	await stage_archief2()
	await stage_hub()
	await stage_action_mode()
	await stage_sequence_break()
	print("WM1 mijlpalen: ", milestones)
	print("WM1 fouten per soort: ", categories)
	print("WM1PLAYTHROUGHTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- 1 proloog
func stage_prologue() -> void:
	print("=== 1 proloog: nieuw spel tot de nacht ===")
	GameState.start_new_game("Dax")
	check("nieuw spel: start in het huis", await wait_path(HUIS))
	await settle("start nieuw spel")
	check("[STATE] nieuw spel begint in Action-stijl (besluit 21 okt)", Settings.action_battles())
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	check("[STATE] stap START, speler vrij naast het bed", GameState.story_step == SD.START and tile() == Vector2i(2, 3) and not player().input_locked)
	milestone("nieuw_spel")
	await pause_resume("proloog: vrij in het huis", true)
	# naar buiten
	check("huis: naar buiten via de deur", await walk_to_exit("NaarDorp", "huis") and await wait_path(ERF))
	await settle("buiten bij het erf")
	# de wereldkaart is dicht
	await use_exit("NaarWereld")
	await settle("pad naar de wereldkaart is dicht")
	check("[BLOCKER] proloog: wereldkaart dicht tot de nacht, speler teruggestuurd", scene().scene_file_path == ERF and GameState.story_step < SD.NACHT)
	# Opa: vroege keuze, mantel
	choice_plan = [0]
	check("Opa aanspreken", await talk("OudeMan", Vector2i(28, 10), Vector2i.RIGHT))
	await settle("Opa: intro en mantel")
	check("[STATE] mantel gekregen, stap UITRUSTING", GameState.item_count(SD.TUTORIAL_ARMOR) == 1 and GameState.story_step == SD.UITRUSTING)
	# Opa weigert door te gaan zonder mantel aan
	await talk("OudeMan", Vector2i(28, 10), Vector2i.RIGHT)
	await settle("Opa wil de mantel aan zien")
	check("[BLOCKER] zonder de mantel aan gaat het verhaal niet door", GameState.story_step == SD.UITRUSTING)
	var hero: Dictionary = GameState.party[0]
	Equipment.equip(hero, GameState.inventory, Equipment.slot_of(SD.TUTORIAL_ARMOR), SD.TUTORIAL_ARMOR)
	check("menu sluiten met de mantel aan start het verhaal verder", Story.menu_closed())
	await settle("mantel aan")
	check("[STATE] stap TAKEN", GameState.story_step == SD.TAKEN)
	# opslaan halverwege en laden
	await save_roundtrip("proloog: stap TAKEN op het erf", 1)
	# klusjes
	await talk("Kist", Vector2i(27, 9), Vector2i.UP)
	await settle("kist")
	await talk("Put", Vector2i(16, 9), Vector2i.UP)
	await settle("put")
	check("[STATE] kruiden en water in de tas", GameState.item_count("kruid") == 3 and GameState.item_count("emmer_water") == 1)
	await pause_resume("proloog: klusjes klaar", true)
	# water naar Opa -> les -> oefengevecht -> avond, catastrofe, opgesloten
	choice_plan = [0, 1]
	await talk("OudeMan", Vector2i(28, 10), Vector2i.RIGHT)
	var t0 := Time.get_ticks_msec()
	var saw_battle := false
	var paused_in_scene := false
	while Time.get_ticks_msec() - t0 < 90000:
		if battle() != null and not saw_battle:
			saw_battle = true
			var n := GameState.autosave_count
			GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			await pframes(2)
			GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			check("[PAUSE] pauze midden in het oefengevecht schrijft geen autosave", GameState.autosave_count == n)
			await win_battle()
		if Story.running and GameState.story_step >= SD.AVOND and not paused_in_scene and Dialog.is_open:
			paused_in_scene = true
			var n2 := GameState.autosave_count
			GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			await pframes(2)
			GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
			check("[PAUSE] pauze midden in de catastrofe-cutscene schrijft geen autosave", GameState.autosave_count == n2)
		if GameState.story_step >= SD.NACHT:
			break
		if Dialog.is_open:
			note_dialog()
			if Dialog._is_typing():
				Dialog.advance()
				await frames(1)
			elif Dialog.has_choices():
				var i := int(choice_plan.pop_front()) if not choice_plan.is_empty() else 0
				if GameState.story_step == SD.OPGESLOTEN and i == 0:
					await save_while_locked_in()
				Dialog.choose(clampi(i, 0, Dialog.choices.size() - 1))
				await pframes(2)
			else:
				await press_interact()
		await get_tree().process_frame
	await settle("na de keuze: Opa achterna")
	check("[STATE] les gezien, gevecht gewonnen, nacht", saw_battle and GameState.story_step == SD.NACHT and Story.has_flag("schilderij_weg"))
	check("[STATE] Short Sword van Opa in de tas of aan", GameState.party[0]["equip"]["wapen"] == "kort_zwaard" or GameState.item_count("kort_zwaard") > 0)
	milestone("nacht")
	# het huis uit, naar de wereldkaart
	check("[BLOCKER] 's nachts: de huisdeur is weer open", not Story.has_flag("locked:HuisDeur"))
	await save_roundtrip("proloog: nacht in het huis", 2)
	check("huis -> erf", await through("NaarDorp", ERF))
	await save_roundtrip("proloog: nacht op het erf", 2)
	check("erf -> wereldkaart", await through("NaarWereld", WORLD))
	milestone("wereldkaart_open")
	await pause_resume("wereldkaart (vrij)", true)


## Opgesloten in het huis (stap OPGESLOTEN) met de keuzevraag open: opslaan en laden mag nooit vastlopen.
func save_while_locked_in() -> void:
	var p := player()
	var d := GameState.state_data(p.get_tile(), p.facing)
	check("[SAVE] opgesloten: staat bevat het slot op de huisdeur", (d["story"]["flags"] as Array).has("locked:HuisDeur"))
	GameState.save_game(p.get_tile(), p.facing, GameState.slot_path(3))
	GameState.story_flags.erase("locked:HuisDeur")
	Dialog.close()
	Story.reset()
	var ok: bool = await GameState.continue_slot(3)
	check("[SAVE] opgesloten: laden uit slot 3", ok)
	await wait_path(HUIS)
	await pframes(10)
	check("[SAVE] opgesloten: na laden zit de deur weer op slot en loopt de timer opnieuw",
			Story.has_flag("locked:HuisDeur") and GameState.story_step == SD.OPGESLOTEN)
	choice_plan.push_front(0)


# ---------------------------------------------------------------- 2 Archief 1
func stage_archief1() -> void:
	print("=== 2 Archief 1: poorten, kamers, Golem ===")
	# poorten die dicht horen te zijn zonder Golem
	await use_exit("NaarEsdoorn")
	await settle("Esdoorn dicht")
	check("[BLOCKER] Esdoorn dicht voor de Golem (blijft op de wereldkaart)", scene().scene_file_path == WORLD)
	await use_exit("NaarKas")
	await settle("kas dicht")
	check("[BLOCKER] de kas is dicht voor de Golem", scene().scene_file_path == WORLD)
	var n0 := GameState.autosave_count
	check("trap naar Archief 1", await through("Trap", ARCHIEF_INGANG))
	check("[PAUSE] binnenkomst in de dungeon schrijft een autosave (reden map)", await wait_until(func(): return GameState.autosave_count > n0, 3.0)
			and GameState.last_autosave_reason == "map")
	await pause_resume("Archief 1 ingang (vrij)", true)
	await pause_mid_step("Archief 1 ingang")
	var route := dungeon_route(ARCHIEF_INGANG, GOLEMHAL, "archief")
	check("[BLOCKER] route ingang -> Golem-hal bestaat (%d kamers)" % route.size(), route.size() > 10)
	var saved_mid := false
	for i in range(1, route.size()):
		var next: String = route[i]
		if not await traverse(next, "Archief 1"):
			return
		if next.ends_with("archief_puzzel.tscn") or false:
			pass
		if not saved_mid and next.ends_with("archief_v3_zuilenhal.tscn"):
			saved_mid = true
			await save_roundtrip("Archief 1: verdieping 3", 1)
			await pause_resume("Archief 1: zuilenhal", true)
	milestone("golemhal")
	await golem_fight()
	await save_roundtrip("Archief 1: Golem verslagen", 1)
	_snap_after_golem = FileAccess.get_file_as_bytes(GameState.slot_path(1))
	await pause_resume("Golem-hal na de baas", true)
	# uit de dungeon met de uitgang-warper (eind)
	await use_warper("Golem-hal")
	check("[BLOCKER] warper brengt je terug naar de wereldkaart", scene().scene_file_path == WORLD)
	milestone("archief1_klaar")


## Uitgang-warper in de huidige dungeonkamer: ja, naar de wereldkaart.
func use_warper(label: String) -> void:
	var w := obj("ExitWarper")
	var p := player()
	if w == null or p == null:
		check("[BLOCKER] %s: geen uitgang-warper in deze kamer" % label, false)
		return
	choice_plan = [0]
	p.input_locked = false
	w.interact(p)
	await wait_until(func(): return GameState.changing_map or scene().scene_file_path == WORLD, 6.0)
	await wait_path(WORLD)
	await settle("warper %s" % label, 45.0, true, 0.6)


func golem_fight() -> void:
	var r := scene()
	if r == null or str(r.scene_file_path) != GOLEMHAL:
		check("[BLOCKER] Golem-hal niet bereikt", false)
		return
	check("[BLOCKER] Golem staat er en is een bewaker", r.get_monster("golem") != null and bool(r.get_monster("golem").data.get("guard", false)))
	heal_party()
	var cp_room := str(GameState.checkpoint.get("map", ""))
	# eerst verliezen: je moet in de kamer ervoor opstaan, niet in een dode hoek
	if await fight_monster(r, "golem"):
		check("[STATE] Golem-gevecht is een baasgevecht", GameState.pending_boss)
		check("[STATE] nederlaag: de groep gaat echt neer in het gevecht", await lose_battle())
		await wait_until(func(): return battle() == null and not GameState.in_battle and not GameState.changing_map, 20.0)
		await settle("Golem: na de nederlaag", 45.0, true, 0.8)
		var here := str(scene().scene_file_path) if scene() else ""
		check("[STATE] nederlaag: opstaan in de kamer voor de baas (%s, checkpoint %s)" % [here.get_file(), cp_room.get_file()],
				here != GOLEMHAL and here == cp_room)
		check("[STATE] nederlaag: groep weer op volle HP", GameState.party.all(func(h): return int(h["hp"]) == int(h["max_hp"])))
		check("[STATE] nederlaag: Golem blijft onverslagen", not Story.has_flag(SD.GOLEM_FLAG))
		if not await traverse(GOLEMHAL, "Archief 1 (terug naar de baas)"):
			return
		r = scene()
	heal_party()
	if not await fight_monster(r, "golem"):
		return
	var won := await win_battle()
	check("[STATE] Golem verslagen", won)
	await wait_path(GOLEMHAL)
	await settle("Golem: na de overwinning", 60.0, true, 1.0)
	check("[STATE] Golem-vlag gezet, Golem weg uit de kamer", Story.has_flag(SD.GOLEM_FLAG) and scene().get_monster("golem") == null)
	check("[STATE] kernfragment ontvangen en geabsorbeerd", not GameState.kernfragmenten.is_empty() and str(GameState.pending_kern_absorb) == "")


## Gerichte kamergraaf van ALLE WM1-dungeons: scènepad -> doelscènes van zijn echte uitgangen.
## (room_graph() maakt alles tweezijdig; dat verbergt eenrichtingsdoorgangen zoals ketting -> tegen.)
var _edges := {}


func build_edges() -> void:
	if not _edges.is_empty():
		return
	var add := func(a: String, b: String):
		if b == "":
			return
		if not _edges.has(a):
			_edges[a] = []
		if not (_edges[a] as Array).has(b):
			(_edges[a] as Array).append(b)
	for rooms in [DungeonRooms.ROOMS, Archief2Rooms.ROOMS, Archief2Rooms.rooms(), WoudRooms.ROOMS, BerggrotData.ROOMS]:
		for id in rooms:
			var ex: Dictionary = rooms[id].get("exits", {})
			for k in ex:
				add.call(DungeonRooms.room_scene(id), str(ex[k].get("map", "")))
	for rooms in [PuzzleRooms.ROOMS, BerggrotData.PUZZLES]:
		for id in rooms:
			for k in ["entrance", "exit"]:
				if rooms[id].get(k) is Dictionary:
					add.call(DungeonRooms.room_scene(id), str(rooms[id][k].get("map", "")))


## Kortste route (scènepaden) langs echte uitgangen.
func exit_route(from: String, to: String) -> Array:
	build_edges()
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to:
			break
		for nb in _edges.get(cur, []):
			if not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(to):
		return []
	var out := []
	var t: String = to
	while t != "":
		out.push_front(t)
		t = str(prev[t])
	return out


func dungeon_route(from: String, to: String, _set := "") -> Array:
	return exit_route(from, to)


## Verlaat de huidige kamer richting 'next': platen/puzzel/bewakers afhandelen, daarna echt lopen.
func traverse(next: String, area: String) -> bool:
	var s := scene()
	if s == null:
		check("[BLOCKER] %s: geen kaart" % area, false)
		return false
	var here := str(s.scene_file_path)
	await quiet_room(s)
	if s.get("logic") != null:
		solve_puzzle(s)
		await pframes(5)
	if s.has_method("raak_plaat"):
		await prepare_plates(s)
	# bewakers: eerst verslaan (dat is de enige weg verder)
	var guards: Array = []
	for m in (s.get("monsters") if s.get("monsters") != null else []):
		if is_instance_valid(m) and bool(m.data.get("guard", false)):
			guards.append(str(m.monster_id))
	for gid in guards:
		if not await beat_guard(s.room_id if "room_id" in s else "", gid):
			return false
		s = scene()
		await quiet_room(s)
	var exit_name := ""
	for e in s.get_node("Exits").get_children():
		if "target_map" in e and str(e.target_map) == next:
			exit_name = str(e.name)
			break
	if exit_name == "":
		check("[BLOCKER] %s: %s heeft geen uitgang naar %s" % [area, here.get_file(), next.get_file()], false)
		return false
	var e: Node = s.get_node("Exits/" + exit_name)
	var spawn := str(e.target_spawn)
	var ok := await walk_to_exit(exit_name, here.get_file())
	if not ok:
		await use_exit(exit_name)
	var arrived := await wait_path(next)
	check("[BLOCKER] %s: %s -> %s" % [area, here.get_file(), next.get_file()], arrived)
	if not arrived:
		return false
	var sp: Node2D = scene().get_spawn(spawn)
	check("[BLOCKER] %s: spawn '%s' bestaat in %s" % [area, spawn, next.get_file()], sp != null)
	if sp != null:
		check("[BLOCKER] %s: speler staat op spawn '%s' (%s)" % [area, spawn, next.get_file()], tile().distance_to(Vector2(sp.get_tile())) <= 2.0)
	await settle("aankomst %s" % next.get_file(), 45.0, true, 0.6)
	if scene().has_method("start_invuln"):
		await quiet_room(scene())
	return true


## Een bewaker verslaan (echt gevecht); daarna staat de speler weer in dezelfde kamer.
func beat_guard(room_id: String, gid: String) -> bool:
	var r := scene()
	var path := str(r.scene_file_path)
	heal_party()
	if not await fight_monster(r, gid):
		return false
	var won := false
	if room_id == "archief_2_v2_lotte":
		# Seren: het verhaal laat je 'verliezen' en dan sluit ze aan (pending_story_loss)
		check("[STATE] Seren-gevecht: de groep gaat neer", await lose_battle())
		won = GameState.last_battle_result == "story"
		check("[STATE] Seren-gevecht telt als verhaal-verlies, geen game over (%s)" % GameState.last_battle_result, won)
	else:
		won = await win_battle()
	check("[STATE] bewaker %s/%s verslagen" % [room_id, gid], won)
	await wait_path(path)
	await settle("na bewaker %s" % gid, 60.0, true, 1.0)
	return won


## Platen van Het Levende Archief zoals een speler ze aanraakt (stap, of Seren's licht).
func prepare_plates(room: Node) -> void:
	for p in room.platen.duplicate():
		if not is_instance_valid(p):
			continue
		match str(p.soort):
			"groei":
				room.raak_plaat(str(p.plaat_id), "stap")
				room.raak_plaat(str(p.plaat_id), "stap")
			"ketting":
				pass
			"licht":
				if Archief2.lotte_heeft_licht():
					room.raak_plaat(str(p.plaat_id), "licht")
					room.raak_plaat(str(p.plaat_id), "licht")
				else:
					check("[BLOCKER] licht-plaat zonder Seren in de groep: pad onbereikbaar", false)
	var ketting: Array = room.platen.filter(func(p): return is_instance_valid(p) and str(p.soort) == "ketting")
	if not ketting.is_empty():
		room.raak_plaat("k0", "stap")
		room.raak_plaat("k1", "stap")
		room.raak_plaat("k1", "stap")
		check("[BLOCKER] ketting-platen: de laatste plaat is volgroeid na 3 stappen",
				Archief2.brug_open(int(room.plaat_van("k2").staat)))
	await pframes(2)


## Puzzelkamers van het WM1-pad. Oplossingen staan in de eigen suites; hier alleen om de uitgang
## open te krijgen. Daarna moet de uitgang bereikbaar zijn.
func solve_puzzle(room: Node) -> void:
	var lg = room.logic
	var id := str(room.room_id) if "room_id" in room else ""
	var ok := true
	match id:
		"archief_puzzel":
			ok = lg.try_push("kast_b", Vector2i.DOWN) and lg.try_push("kast_b", Vector2i.DOWN)
			lg.toggle_lever("hendel_h")
			for d in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP, Vector2i.UP, Vector2i.UP]:
				ok = ok and lg.try_push("kast_a", d)
		"berggrot_grendel":
			for _i in 4:
				ok = ok and lg.try_push("kast_grendel", Vector2i.RIGHT)
			for _i in 2:
				ok = ok and lg.try_push("kast_grendel", Vector2i.DOWN)
			lg.toggle_lever("hendel_grendel")
		"berggrot_geheim":
			lg.toggle_lever("hendel_uit")
		"leven_v1_plaat":
			lg.toggle_lever("hendel_kas")
			for _i in 3:
				lg.try_grow("groei_brug")
		"leven_v3_combi":
			ok = lg.try_push("kast_combi", Vector2i.RIGHT) and lg.try_push("kast_combi", Vector2i.RIGHT)
			lg.toggle_lever("hendel_combi")
			for _i in 3:
				lg.try_grow("groei_combi")
		_:
			check("[BLOCKER] onbekende puzzelkamer %s: geen oplossing in de suite" % id, false)
	check("[BLOCKER] puzzel %s: alle duwen lukken" % id, ok)
	room._sync_all()


# ---------------------------------------------------------------- 3 Esdoorn en het Donker Woud
func enter_door(door_name: String, expect_path: String) -> bool:
	var d := obj(door_name)
	var p := player()
	if d == null or p == null:
		check("[BLOCKER] deur %s ontbreekt op %s" % [door_name, str(GameState.current_map).get_file()], false)
		return false
	p.input_locked = false
	d.bump(p)
	var ok := await wait_path(expect_path)
	check("[BLOCKER] deur %s -> %s" % [door_name, expect_path.get_file()], ok)
	if ok:
		await settle("binnen %s" % expect_path.get_file(), 45.0, true, 0.5)
	return ok


func stage_esdoorn_woud() -> void:
	print("=== 3 Esdoorn en Donker Woud ===")
	# de poorten die nu nog dicht horen te zijn
	await use_exit("NaarWoud")
	await settle("woud nog dicht", 45.0, true, 0.5)
	check("[BLOCKER] Donker Woud dicht zonder opdracht (blijft op de wereldkaart)", scene().scene_file_path == WORLD)
	# bouwplaats: bereikbaar, tunnel dicht tot Vesper in de groep zit
	check("wereldkaart -> bouwplaats", await through("NaarBouwplaats", M + "berggrot_bouwplaats.tscn"))
	await talk("Voorman", Vector2i(10, 6), Vector2i.UP)
	await settle("voorman zonder Vesper")
	await use_exit("NaarBerggrot")
	await settle("tunnel dicht", 45.0, true, 0.5)
	check("[BLOCKER] tunnel dicht zonder Vesper (blijft op de bouwplaats)", scene().scene_file_path.ends_with("berggrot_bouwplaats.tscn"))
	check("bouwplaats -> wereldkaart", await through("NaarWereld", WORLD))
	# Esdoorn: de ontmoeting start vanzelf
	check("wereldkaart -> Esdoorn", await through("NaarEsdoorn", ESDOORN))
	check("[STATE] ontmoeting: vlaggen, opdracht en stap NOOR_KWIJT", Story.has_flag("noor_ontmoet") and Story.has_flag("quest_noor")
			and GameState.story_step == SD.NOOR_KWIJT and Story.active_quest() == "Save Vesper from the Dark Wood")
	check("[STATE] Marigold gaf de Lege Boeken (nu %d)" % GameState.item_count("leeg_boek"), GameState.item_count("leeg_boek") >= 3 and Story.has_flag("marit_boeken"))
	await pause_resume("Esdoorn (opdracht loopt)", true)
	await save_roundtrip("Esdoorn: opdracht Save Vesper", 1)
	# dorpelingen, herberg met opslagboek, huis van Vesper
	await talk("Marit", Vector2i(27, 19), Vector2i.UP)
	await settle("Marit")
	await talk("Bram", Vector2i(11, 17), Vector2i.UP)
	await settle("Bram")
	check("Esdoorn -> herberg", await enter_door("Deur_voor_herberg", M + "esdoorn_herberg.tscn"))
	GameState.party[0]["hp"] = 1
	choice_plan = [0]
	await talk("Waard", Vector2i(6, 4), Vector2i.UP)
	await settle("herbergier")
	check("[STATE] herberg: HP hersteld", int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"]))
	choice_plan = [0, 0]
	var slot_file := GameState.slot_path(GameState.active_slot)
	var mtime := FileAccess.get_modified_time(slot_file) if FileAccess.file_exists(slot_file) else 0
	await talk("SaveBook", Vector2i(8, 4), Vector2i.UP)
	await settle("opslagboek in de herberg")
	check("[SAVE] opslagboek in de herberg schrijft het slotbestand", FileAccess.file_exists(slot_file) and not GameState.read_save(slot_file).is_empty())
	check("herberg -> buiten", await through("NaarBuiten", ESDOORN))
	check("Esdoorn -> huis van Vesper", await enter_door("Deur_voor_noor", M + "esdoorn_huis_noor.tscn"))
	await talk("Ilse", Vector2i(6, 4), Vector2i.UP)
	await settle("Ilse (nog zonder Vesper)")
	check("huis van Vesper -> buiten", await through("NaarBuiten", ESDOORN))
	await pause_mid_step("Esdoorn")
	await pause_during_transition("NaarWereld", WORLD, "Esdoorn -> wereldkaart")
	# het woud in
	check("wereldkaart -> Donker Woud", await through("NaarWoud", M + "woud_rand.tscn"))
	await pause_resume("Donker Woud (rand)", true)
	var route := dungeon_route(M + "woud_rand.tscn", WOUD_OPEN, "woud")
	check("[BLOCKER] route woudrand -> open plek bestaat (%d kamers)" % route.size(), route.size() == 5)
	for i in range(1, route.size()):
		if not await traverse(route[i], "Donker Woud"):
			return
		if route[i].ends_with("woud_sporenkring.tscn"):
			await save_roundtrip("Donker Woud: sporenkring", 1)
	await pause_resume("open plek voor de baas", true)
	var r := scene()
	check("[BLOCKER] Root King staat op de open plek", r.get_monster("baas") != null)
	heal_party()
	var lv0 := GameState.member_level("dennis")
	if await fight_monster(r, "baas"):
		var won := await win_battle()
		check("[STATE] Root King verslagen", won)
		await wait_path(WOUD_OPEN)
		await wait_until(func(): return Story.running, 4.0)
		if Story.running:
			await pause_resume("Vesper bevrijd (cutscene)", false)
		await settle("Vesper sluit aan", 60.0, true, 1.0)
	check("[STATE] Vesper in de groep, opdracht klaar, stap NOOR_GERED", GameState.has_member("noor") and Story.has_flag("noor_gered")
			and Story.has_flag("noor_lid") and GameState.story_step == SD.NOOR_GERED and Story.active_quest() == "")
	check("[STATE] Vesper op niveau Dax-1 (Dax was %d)" % lv0, GameState.member_level("noor") >= 1)
	milestone("noor_gered")
	await menu_sweep("woud met Vesper")
	await save_roundtrip("Woud: Vesper in de groep", 2)
	await pause_resume("open plek met Vesper", true)
	await use_warper("open plek")
	check("[BLOCKER] woud-warper -> wereldkaart", scene().scene_file_path == WORLD)
	# nu mag de rest
	check("wereldkaart -> Esdoorn (na de redding)", await through("NaarEsdoorn", ESDOORN))
	check("Esdoorn -> huis van Vesper", await enter_door("Deur_voor_noor", M + "esdoorn_huis_noor.tscn"))
	await talk("Ilse", Vector2i(6, 4), Vector2i.UP)
	await settle("Ilse na de redding")
	check("[STATE] Ilse gaf 3x Herbal Tea", Story.has_flag("ilse_thee") and GameState.item_count("kruidenthee") >= 3)
	check("huis van Vesper -> buiten", await through("NaarBuiten", ESDOORN))
	check("Esdoorn -> wereldkaart", await through("NaarWereld", WORLD))


# ---------------------------------------------------------------- 4 het Zingende Graan
func stage_graan() -> void:
	print("=== 4 Het Zingende Graan (zijopdracht) ===")
	check("wereldkaart -> Wilgendal", await through("NaarWilgendal", DORP))
	await pause_resume("Wilgendal (dorp)", true)
	choice_plan = [0]
	await talk("Gerrit", Vector2i(14, 31), Vector2i.UP)
	await settle("Gerrit: opdracht", 45.0, true, 0.3)
	check("[STATE] Gerrit: opdracht aangenomen", Story.has_flag(SD.FLAG_GRAAN) and not Story.has_flag(SD.FLAG_GRAAN_KLAAR))
	await save_roundtrip("Wilgendal: opdracht Zingend Graan", 3)
	# het zaad zit in de open plek van het woud (zelfde kaart als de baas)
	var w := await goto(WOUD_OPEN, "zuid")
	if w == null:
		return
	await settle("woud: open plek", 45.0, true, 0.8)
	var geest := obj("Woudgeesten")
	check("[BLOCKER] de Wood Wraith (zaad) staat er tijdens de opdracht", geest != null and geest.visible)
	await talk("Woudgeesten", Vector2i(6, 15), Vector2i.UP)
	await settle("zaad: gevecht", 60.0, true, 0.5)
	check("[STATE] Singing Seed gevonden", GameState.item_count(SD.ITEM_ZAAD) == 1 and Story.has_flag(SD.FLAG_ZAAD))
	await use_warper("open plek (zaad)")
	check("wereldkaart -> Wilgendal", await through("NaarWilgendal", DORP))
	choice_plan = [0, 0]
	await talk("Gerrit", Vector2i(14, 31), Vector2i.UP)
	await settle("Gerrit: zaad en molen", 60.0, true, 0.3)
	check("[STATE] opdracht klaar: molen draait weer, meel gekregen", Story.has_flag(SD.FLAG_GRAAN_KLAAR) and GameState.item_count(SD.ITEM_ZAAD) == 0
			and GameState.item_count(SD.ITEM_MEEL) + GameState.item_count("zingend_meel") >= 1)
	milestone("graan_klaar")
	check("Wilgendal -> wereldkaart", await through("NaarWereld", WORLD))


# ---------------------------------------------------------------- 5 de kas via de directe ingang
func stage_greenhouse_route() -> void:
	print("=== 5 kas: directe route (wereldkaart -> kas -> Kasgang) ===")
	check("wereldkaart -> kas", await through("NaarKas", M + "leven_ingang.tscn"))
	var route := dungeon_route(M + "leven_ingang.tscn", M + "archief_2_v2_gang.tscn", "leven")
	check("[BLOCKER] kas -> Kasgang bestaat (%s)" % [route.map(func(x): return str(x).get_file())], route.size() == 3)
	for i in range(1, route.size()):
		if not await traverse(route[i], "kas (direct)"):
			return
	# terug naar buiten
	for i in range(route.size() - 2, -1, -1):
		if not await traverse(route[i], "kas (terug)"):
			return
	check("kas -> wereldkaart", await traverse(WORLD, "kas (terug)"))
	milestone("kas_direct_ok")


# ---------------------------------------------------------------- 6 berggrot
func stage_berggrot() -> void:
	print("=== 6 berggrot: bouwplaats -> tunnel -> kas ===")
	check("wereldkaart -> bouwplaats", await through("NaarBouwplaats", M + "berggrot_bouwplaats.tscn"))
	await talk("Voorman", Vector2i(10, 6), Vector2i.UP)
	await settle("voorman met Vesper")
	# de tunnel is open: de bump-uitgang zelf
	await use_exit("NaarBerggrot")
	var ok := await wait_path(BerggrotData.SCENE)
	check("[BLOCKER] tunnel open met Vesper in de groep (bouwplaats -> berggrot_mond)", ok)
	if not ok:
		return
	await settle("berggrot: mond", 45.0, true, 0.6)
	await pause_resume("berggrot (mond)", true)
	var route := exit_route(BerggrotData.SCENE, BerggrotData.KAS_SCENE)
	check("[BLOCKER] route mond -> kas bestaat (%s)" % [route.map(func(x): return str(x).get_file())], route.size() >= 5)
	for i in range(1, route.size()):
		if not await traverse(route[i], "berggrot"):
			return
		if route[i].ends_with("berggrot_nerf.tscn"):
			await save_roundtrip("berggrot: nerf (grendel open)", 1)
	check("[STATE] berggrot: staf/accessoire-kisten zijn een bonus, geen verplichte stap", true)
	milestone("kas_via_berggrot")


# ---------------------------------------------------------------- 7 Archief 2
func stage_archief2() -> void:
	print("=== 7 Archief 2: Seren, Strangler, Mender ===")
	var route := dungeon_route(BerggrotData.KAS_SCENE, GENEZER, "leven")
	check("[BLOCKER] route kas -> Mender bestaat (%s)" % [route.map(func(x): return str(x).get_file())], route.size() >= 8)
	for i in range(1, route.size()):
		var next: String = route[i]
		if not await traverse(next, "Archief 2"):
			return
		if next.ends_with("archief_2_v3_ketting.tscn"):
			check("[STATE] Seren in de groep na haar kamer", GameState.has_member("lotte") and Archief2.lotte_heeft_licht())
			await save_roundtrip("Archief 2: Seren in de groep", 1)
			await pause_resume("Archief 2: ketting-platen", true)
		if next.ends_with("archief_2_v4_hal.tscn"):
			check("[STATE] Strangler verslagen (vlag)", Story.has_flag("bewaker:archief_2_v3_wurger/wurger"))
			await save_roundtrip("Archief 2: na de Strangler", 2)
	milestone("mender_kamer")
	await mender_fight()


func mender_fight() -> void:
	var r := scene()
	if r == null or str(r.scene_file_path) != GENEZER:
		check("[BLOCKER] Mender-kamer niet bereikt", false)
		return
	check("[BLOCKER] de noorduitgang zit dicht tot de Mender weg is (blokkade rij 5)", not get_tree().get_nodes_in_group("dungeon_blokkade").is_empty())
	heal_party()
	await pause_resume("Mender-kamer voor het gevecht", true)
	if not await fight_monster(r, "genezer"):
		return
	var won := await win_battle()
	check("[STATE] Mender verslagen", won)
	await finish_mender_scenes()


## Na De Mender: kern-absorptie, filmpje, canon-scène 1, warp naar de Hal, scène 2 en 3.
func finish_mender_scenes() -> void:
	var t0 := Time.get_ticks_msec()
	var in_hal := false
	var saw_video := false
	while Time.get_ticks_msec() - t0 < 120000:
		var s := scene()
		if s != null:
			var vid: Node = s.find_child("GenezerVideo", true, false)
			if vid != null:
				if not saw_video:
					saw_video = true
					await pause_resume("Mender: filmpje loopt (autosave toegestaan, scène is save-veilig)", true)
					await kill_and_continue(GENEZER, "Mender: filmpje")
					continue
				vid.skip_now()
			if s.scene_file_path.ends_with("world_warper/maps/hal.tscn") and s.is_node_ready() and not GameState.changing_map:
				in_hal = true
				break
		if Dialog.is_open:
			note_dialog()
			if Dialog._is_typing():
				Dialog.advance()
			else:
				Dialog.advance()
		await get_tree().process_frame
	check("[BLOCKER] na de Mender volgt de warp naar de Hal (hub)", in_hal)
	check("[STATE] World Warper ontgrendeld, vlag archief2_naar_warper", GameState.world_warper_is_unlocked() and Story.has_flag("archief2_naar_warper"))
	check("[STATE] Mender-vlag en levenskern", Story.has_flag(WarperUnlock.BEWAKER_VLAG) and GameState.kernfragmenten.has(Archief2.KERN_ID))
	check("[STATE] canon-scène 1 gezien", bool(GameState.story_flags.get(WarperCanon.FLAG_GENEZER, false)))


# ---------------------------------------------------------------- 8 hub = einde WM1
func stage_hub() -> void:
	print("=== 8 hub: einde van World Map 1 ===")
	var s := scene()
	if s == null or not str(s.scene_file_path).ends_with("world_warper/maps/hal.tscn"):
		check("[BLOCKER] hub niet bereikt, rest van de suite overgeslagen", false)
		return
	await get_tree().create_timer(0.5).timeout
	var hs := s.find_child("HangerScene", true, false)
	check("Hal: canon-scène 2 speelt bij binnenkomst", hs != null and bool(hs.get("_playing")))
	if hs != null:
		await pause_resume("Hal: Hanger-scène loopt (autosave toegestaan, scène is save-veilig)", true)
		await kill_and_continue(str(s.scene_file_path), "Hal: Hanger-scène")
		s = scene()
		hs = s.find_child("HangerScene", true, false) if s != null else null
		await wait_until(func(): return s.find_child("HangerScene", true, false) != null, 3.0)
		hs = s.find_child("HangerScene", true, false)
		check("[PAUSE] na app-kill midden in de Hanger-scène speelt de scène opnieuw (geen softlock)", hs != null and bool(hs.get("_playing")))
	if hs != null:
		for _i in 80:
			if not bool(hs.get("_playing")):
				break
			hs.call("_advance")
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
	await settle("Hal na de scènes", 45.0, true, 0.5)
	check("[STATE] canon-scènes 2 en 3 gezien", bool(GameState.story_flags.get(WarperCanon.FLAG_HANGER, false))
			and bool(GameState.story_flags.get(WarperCanon.FLAG_DREIGING, false)))
	var warp := s.find_child("WarpView", true, false)
	if warp != null and warp.visible and warp.has_method("close"):
		warp.call("close")
	await pframes(5)
	milestone("wm1_einde" + _variant)
	await menu_sweep("hub (einde WM1)")
	await pause_resume("hub (vrij)", true)
	await save_roundtrip("hub: einde WM1", 1)
	# 'app gedood' na een pauze: doorgaan met de autosave
	await kill_and_resume_from_autosave()


## App gedood terwijl een scène liep en direct weer gestart ('Doorgaan' = nieuwste save).
func kill_and_continue(path: String, label: String) -> void:
	# een echte app-kill wist ook de statics van de cutscenes
	GenezerScene.bezig = false
	NaGenezer.pending = false
	GameState.new_game("Gedood")
	GameState.encounter_multiplier = 0.0
	GameState.changing_map = false
	GameState.in_battle = false
	var ok: bool = await GameState.continue_game()
	check("[PAUSE] %s: na app-kill laadt Doorgaan de autosave" % label, ok)
	check("[PAUSE] %s: terug op %s" % [label, path.get_file()], await wait_path(path))
	await pframes(10)


## Pauze (autosave "achtergrond"), app gedood, opnieuw starten: 'Doorgaan' pakt de nieuwste save.
func kill_and_resume_from_autosave() -> void:
	var p := player()
	var path := str(scene().scene_file_path)
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await pframes(3)
	var before := GameState.state_data(p.get_tile(), p.facing)
	GameState.new_game("Gedood")
	GameState.changing_map = false
	GameState.in_battle = false
	var ok: bool = await GameState.continue_game()
	check("[PAUSE] app gedood na pauze: Doorgaan laadt een save", ok)
	check("[PAUSE] app gedood: terug in de hub", await wait_path(path))
	await settle("na gedood", 45.0, true, 0.6)
	var after := GameState.state_data(tile(), player().facing)
	var diff := diff_keys(before, after)
	diff.erase("checkpoint")
	check("[PAUSE] app gedood: voortgang gelijk aan het moment van pauze (verschil: %s)" % [diff], diff.is_empty())


# ---------------------------------------------------------------- 9 Action-stijl (standaard voor een nieuw spel)
func stage_action_mode() -> void:
	print("=== 9 Action-stijl in de dungeon ===")
	GameState.changing_map = false
	GameState.in_battle = false
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var s := await goto(ARCHIEF_INGANG, "ingang")
	if s == null:
		return
	await settle("Action: Archief 1 ingang", 45.0, true, 0.8)
	check("[STATE] Action-stijl: de dungeonkamer draait de Action-arena", s.get("som") != null)
	await pause_resume("Action-stijl: Archief 1 ingang", true, true)
	await save_roundtrip("Action-stijl: Archief 1 ingang", 4, "", true)
	check("[SAVE] Action-stijl blijft na laden Action", Settings.action_battles())
	s = scene()
	await quiet_room(s)
	check("Action-stijl: lopen naar de volgende kamer", await traverse(M + "archief_v1_gang.tscn", "Action"))
	# modus-direct: Classic aanzetten midden in de kamer bouwt de kamer opnieuw op
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	await settle("Action -> Classic", 45.0, true, 1.0)
	check("[STATE] Classic: kamer nog bruikbaar na de stijlwissel", scene() != null and player() != null and not player().input_locked)


# ---------------------------------------------------------------- 10 volgordebreuk
## De kas gaat open op de Golem-vlag alleen (naar_leven): wie direct na Archief 1 de kas in gaat, slaat
## Esdoorn, het Woud en de berggrot over. Dat moet tot en met de hub werken (ook zonder Vesper).
func stage_sequence_break() -> void:
	print("=== 10 volgordebreuk: direct na de Golem de kas in, zonder Vesper ===")
	if _snap_after_golem.is_empty():
		check("[BLOCKER] geen save van na de Golem om de volgordebreuk mee te spelen", false)
		return
	_variant = "_zonder_vesper"
	var f := FileAccess.open(GameState.slot_path(4), FileAccess.WRITE)
	f.store_buffer(_snap_after_golem)
	f.close()
	GenezerScene.bezig = false
	NaGenezer.pending = false
	GameState.new_game("Wis")
	GameState.encounter_multiplier = 0.0
	GameState.changing_map = false
	GameState.in_battle = false
	var ok: bool = await GameState.continue_slot(4)
	check("[SAVE] save van na de Golem laadt", ok and await wait_path(GOLEMHAL))
	await settle("volgordebreuk: start", 45.0, true, 0.8)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	check("[STATE] volgordebreuk: Vesper is er niet bij", not GameState.has_member("noor") and not Story.has_flag("noor_lid"))
	await use_warper("Golem-hal (volgordebreuk)")
	check("kas direct na de Golem", await through("NaarKas", M + "leven_ingang.tscn"))
	var route := exit_route(M + "leven_ingang.tscn", GENEZER)
	check("[BLOCKER] route kas -> Mender bestaat zonder berggrot (%d kamers)" % route.size(), route.size() >= 8)
	for i in range(1, route.size()):
		if not await traverse(route[i], "volgordebreuk"):
			return
	await mender_fight()
	await stage_hub()
