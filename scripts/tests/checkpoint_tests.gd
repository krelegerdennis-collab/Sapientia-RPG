extends Node
## ALLEEN VOOR TESTEN - v0.19 KAMER-CHECKPOINT ('spawnpoint moet altijd voor de laatste room zijn').
## Start:  godot --path . -- --checkpointtest [--shots=/pad/map] [--v19=/workspace]
##   Deel A: data (baaskamers zetten geen checkpoint, de kamers ervoor wel).
##   Deel B: gewone dungeonkamer: verliezen -> terug bij de ingang van de kamer, voortgang van toen, vol HP/MP.
##   Deel C: wereldkaart: verliezen -> terug waar je de wereldkaart binnenkwam (net buiten Wilgendal).
##   Deel D: Golem: opslaan + laden in de Golemhal, verliezen -> Bibliotheek (kamer ervoor), Golem staat er nog.
##   Deel E: De Wortelkoning: verliezen -> Sporenkring; Noor nog in de cocon, baas staat er nog.
##   Deel F: oude save zonder checkpoint, laden in de kamer met checkpoint, verslagen baas.
## --v19=map: screenshot van het ontwaken na de Golem (nearest, ~1152 breed) als <map>/v19_respawn.png.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const WR := preload("res://scripts/data/woud_rooms.gd")
const DungeonRoomScript := preload("res://scripts/dungeon/dungeon_room.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const GANG := "res://scenes/maps/archief_v1_gang.tscn"
const BIEB := "res://scenes/maps/archief_bibliotheek.tscn"
const GOLEMHAL := "res://scenes/maps/archief_golemhal.tscn"
const SPORENKRING := "res://scenes/maps/woud_sporenkring.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}

var failures := 0
var passes := 0
var shots := ""
var v19_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--v19="):
			v19_dir = arg.get_slice("=", 1)
	seed(1919)
	get_tree().create_timer(780.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 780 s", false)
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
	print("=== Deel S: vier save-slots ===")
	_slot_tests()
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: gewone dungeonkamer ===")
	await _room_tests()
	print("=== Deel C: wereldkaart ===")
	await _world_tests()
	print("=== Deel D: Golem (opslaan/laden ertussen) ===")
	await _golem_tests()
	print("=== Deel E: The Root King ===")
	await _woud_tests()
	print("=== Deel F: oude save, laden, verslagen baas ===")
	await _misc_tests()
	print("CHECKPOINTTEST %d PASS, %d FAIL" % [passes, failures])
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


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map or GameState.in_battle:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 6:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open or GameState.in_battle:
			return


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


## Expres verliezen zoals een speler: iedereen op 1 HP en alleen Verdedigen. Geeft de
## GAME OVER-tekst terug ("" = niet gezien).
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
			await cross_to(b, 3)      # Verdedig
			await tap("interact")
		else:
			if "GAME OVER" in b.message_label.text:
				over = b.message_label.text
			await tap("interact")
	Engine.time_scale = 1.0
	return over


func setup_game(level := 5) -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(level))
	h["hp"] = h["max_hp"]
	h["mp"] = h["max_mp"]
	GameState.pending_kern_absorb = ""


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


func cp_tile() -> Vector2i:
	var t = GameState.checkpoint.get("tile", [])
	return Vector2i(int(t[0]), int(t[1])) if t is Array and t.size() >= 2 else Vector2i(-1, -1)


func spawn_of(room_id: String, spawn: String) -> Array:
	var s: Array = DR.room(room_id)["spawns"][spawn]
	var dirs := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}
	return [Vector2i(int(s[0]), int(s[1])), dirs[str(s[2])]]


## Na de respawn: wacht op het bericht (verteller) en geef de eerste regel terug.
func respawn_line() -> String:
	if not await wait_until(func(): return Dialog.is_open, 3.0):
		return ""
	return str(Dialog._lines[0]) if not Dialog._lines.is_empty() else ""


func v19_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	var f := maxi(1, roundi(1152.0 / img.get_width()))
	img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("INFO  v19-screenshot: ", path, " ", img.get_size())


# ================================================================ A: data
func _slot_tests() -> void:
	GameState.new_game("Kees")
	GameState.current_map = "res://scenes/maps/huis_wilgendal.tscn"
	GameState.active_slot = 1
	check("vier save-slots", GameState.SLOT_COUNT == 4)
	check("slot 1 is het oude save-bestand", GameState.slot_path(1) == GameState.save_path)
	check("slot 4 ligt naast slot 1", GameState.slot_path(4).ends_with("save_4.json") and GameState.slot_path(2) != "")
	GameState.gold = 11
	check("opslaan in slot 1", GameState.save_game(Vector2i(1, 2), Vector2i.DOWN))
	GameState.active_slot = 2
	GameState.gold = 22
	check("opslaan in slot 2", GameState.save_game(Vector2i(3, 4), Vector2i.UP))
	var raw := GameState.read_save(GameState.slot_path(2))
	raw["saved_unix"] = float(raw.get("saved_unix", 0)) + 30.0
	var f := FileAccess.open(GameState.slot_path(2), FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	var s1 := GameState.read_save(GameState.slot_path(1))
	var s2 := GameState.read_save(GameState.slot_path(2))
	check("slots blijven apart (goud 11 en 22)", int(s1.get("gold", 0)) == 11 and int(s2.get("gold", 0)) == 22
			and int(s1.get("slot", 0)) == 1 and int(s2.get("slot", 0)) == 2)
	check("nieuwste save is slot 2", GameState.newest_save_path() == GameState.slot_path(2))
	var rec1 := GameState.slot_record(1)
	check("lijst van slot 1 toont Kees", str(rec1.get("data", {}).get("player_name", "")) == "Kees" and not rec1.is_empty())
	for s in [1, 2, 3, 4]:
		var p := GameState.slot_path(s)
		if p != "" and FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameState.active_slot = 1
	GameState.new_game("Dennis")


func _data_tests() -> void:
	var gh := DR.room("archief_golemhal")
	var op := DR.room(WR.BOSS_ROOM)
	check("baaskamers (Golem Hall, Clearing) zetten geen checkpoint (\"checkpoint\": false + baas-monster)",
			gh.get("checkpoint", true) == false and op.get("checkpoint", true) == false
			and DungeonRoomScript.is_boss_room(gh) and DungeonRoomScript.is_boss_room(op))
	check("kamers voor de baas (Library, Spore Ring) wel: geen baas, geen \"checkpoint\": false",
			not DungeonRoomScript.is_boss_room(DR.room("archief_bibliotheek")) and DR.room("archief_bibliotheek").get("checkpoint", true)
			and not DungeonRoomScript.is_boss_room(DR.room("woud_sporenkring")) and DR.room("woud_sporenkring").get("checkpoint", true))
	var bosses := []
	for e in DR.ORDER + WR.ORDER:
		if e[0] != "" and DungeonRoomScript.is_boss_room(DR.room(e[0])):
			bosses.append(e[0])
	check("alle baaskamers in de data: %s (alleen deze twee)" % [bosses], bosses == ["archief_golemhal", WR.BOSS_ROOM])
	check("tekst Nederlands: 'Je ontwaakt voor de deur...' / 'Je ontwaakt waar je binnenkwam...'",
			GameState.RESPAWN_LINES_BOSS[0] == "You wake before the door..." and GameState.RESPAWN_LINES[0] == "You wake where you came in...")
	GameState.new_game("Dennis")
	check("nieuw spel: geen checkpoint; game over-tekst = de oude ('wakker bij het begin')",
			GameState.checkpoint.is_empty() and not GameState.has_checkpoint()
			and GameState.defeat_text(false) == "GAME OVER\nYou wake up back at the start.")


# ================================================================ B: gewone kamer
func _room_tests() -> void:
	setup_game(5)
	var r := await enter(GANG, "zuid")
	check("binnen in de Gang (v1)", r != null)
	if r == null:
		return
	await freeze_monsters(r)
	var sp := spawn_of("archief_v1_gang", "zuid")
	check("checkpoint = ingang van de Gang %s, kijkt omhoog" % [sp[0]], GameState.checkpoint.get("map") == GANG
			and cp_tile() == sp[0] and GameState.checkpoint.get("facing") == [0, -1])
	var gold0 := GameState.gold
	var exp0 := int(GameState.party[0]["exp"])
	var drank0 := GameState.item_count("drankje")
	var n_mon: int = r.monsters.size()
	# na de checkpoint verandert er van alles
	GameState.gold += 777
	GameState.inventory["drankje"] = drank0 + 5
	GameState.party[0]["exp"] = exp0 + 3
	GameState.story_flags["test_na_checkpoint"] = true
	player().place_at(sp[0] + Vector2i(1, -2), Vector2i.RIGHT)
	await frames(2)
	r.start_monster_battle(r.monsters[0])
	check("gevecht in de Gang gestart (geen baas)", await wait_scene("Battle") and not GameState.pending_boss)
	var over := await lose_battle()
	check("GAME OVER-tekst: '%s'" % over.replace("\n", " / "), over == "GAME OVER\nYou wake where you came in...")
	check("na game over terug in de Gang (niet Willowdale)", await wait_scene("ArchiefV1Gang"))
	await pframes(3)
	check("uitslag = lose", GameState.last_battle_result == "lose")
	check("op de ingang van de kamer %s (nu %s), kijkt omhoog" % [sp[0], tile()], tile() == sp[0]
			and player().facing == Vector2i.UP)
	check("vol HP/MP", full_hp_mp())
	check("voortgang van bij binnenkomst: goud %d, drankjes %d, EXP %d, geen nieuwe vlag" % [GameState.gold,
			GameState.item_count("drankje"), int(GameState.party[0]["exp"])],
			GameState.gold == gold0 and GameState.item_count("drankje") == drank0
			and int(GameState.party[0]["exp"]) == exp0 and not GameState.story_flags.has("test_na_checkpoint"))
	check("alle monsters van de kamer staan er weer (%d)" % scene().monsters.size(), scene().monsters.size() == n_mon)
	var line := await respawn_line()
	check("bericht: '%s'" % line, line == "You wake where you came in...")
	check("automatisch opgeslagen na het ontwaken (reden respawn)", GameState.last_autosave_reason == "respawn"
			and GameState.read_save(GameState.autosave_path).get("map") == GANG)
	check("checkpoint blijft dezelfde (Gang, ingang)", GameState.checkpoint.get("map") == GANG and cp_tile() == sp[0])
	await close_dialog()
	# een gewonnen gevecht verschuift het checkpoint niet
	await freeze_monsters(scene())
	GameState.gold += 50
	var gold1 := GameState.gold
	scene().start_monster_battle(scene().monsters[0])
	await wait_scene("Battle")
	for e in battle().enemies:
		e["s"]["hp"] = 1
	await _win()
	check("terug in de Gang na winst", await wait_scene("ArchiefV1Gang"))
	check("winst/vlucht zet geen nieuw checkpoint (goud in checkpoint %d, nu %d)" % [int(GameState.checkpoint["state"]["gold"]), GameState.gold],
			int(GameState.checkpoint["state"]["gold"]) == gold0 and GameState.gold >= gold1 and cp_tile() == sp[0])
	await close_dialog()


func _win() -> void:
	Engine.time_scale = 3.0
	for guard in 80:
		var st := await wait_battle_state(["command", "target_enemy", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "command":
			for e in b.enemies:
				e["s"]["hp"] = mini(int(e["s"]["hp"]), 1)
			await cross_to(b, 0)
			await tap("interact")
		else:
			await tap("interact")
	Engine.time_scale = 1.0


# ================================================================ C: wereldkaart
func _world_tests() -> void:
	setup_game(3)
	GameState.story_step = SD.KLAAR
	var r := await enter(WORLD, "van_dorp")
	check("op de wereldkaart (net buiten Willowdale)", r != null)
	if r == null:
		return
	var start := tile()
	check("checkpoint = waar je de wereldkaart binnenkwam %s" % [start], GameState.checkpoint.get("map") == WORLD
			and cp_tile() == start and start == Vector2i(14, 31))
	var gold0 := GameState.gold
	await walk("move_left", 2)
	check("een stukje gelopen (%s)" % tile(), tile() != start)
	GameState.gold += 100
	GameState.debug_force_group = ["glitchmot", "glitchmot", "glitchmot"]
	await tap("debug_battle")
	check("gevecht op de wereldkaart", await wait_scene("Battle"))
	var over := await lose_battle()
	GameState.debug_force_group = []
	check("GAME OVER gezien", over.begins_with("GAME OVER"))
	check("terug op de wereldkaart (niet in Willowdale)", await wait_scene("Wereldkaart"))
	await pframes(3)
	check("op de plek waar je de kaart binnenkwam %s (nu %s)" % [start, tile()], tile() == start)
	check("vol HP/MP, goud van toen (%d, geen helft kwijt)" % GameState.gold, full_hp_mp() and GameState.gold == gold0)
	var line := await respawn_line()
	check("bericht: '%s'" % line, line.begins_with("You wake"))
	await close_dialog()


# ================================================================ D: Golem
func _golem_tests() -> void:
	setup_game(5)
	var r := await enter("res://scenes/maps/archief_v4_voorhal.tscn", "boog")
	await freeze_monsters(r)
	# naar de Bibliotheek (ingang zuid, zoals vanuit de Voorhal)
	r = await enter(BIEB, "zuid")
	check("in de Library (kamer voor de Golem)", r != null)
	var sp := spawn_of("archief_bibliotheek", "zuid")
	check("checkpoint = ingang van de Library %s, kijkt naar de golemdeur (omhoog)" % [sp[0]],
			GameState.checkpoint.get("map") == BIEB and cp_tile() == sp[0] and GameState.checkpoint.get("facing") == [0, -1])
	var gold0 := GameState.gold
	var lv0 := int(GameState.party[0]["level"])
	# naar de golemdeur lopen en erdoor (echte uitgang)
	player().place_at(Vector2i(5, 3), Vector2i.UP)
	await frames(2)
	await walk("move_up", 1)
	check("door de golemdeur -> Golem Hall", await wait_scene("ArchiefGolemhal"))
	await wait_fade()
	check("de Golem Hall (baaskamer) zet GEEN checkpoint: nog steeds de Library", GameState.checkpoint.get("map") == BIEB
			and cp_tile() == sp[0])
	# opslaan in de Golemhal, iets veranderen, en weer laden (Doorgaan)
	GameState.gold += 300
	var saved_gold := GameState.gold
	check("opgeslagen in de Golem Hall (met checkpoint in de save)", GameState.save_game(tile(), player().facing)
			and GameState.read_save().get("checkpoint", {}).get("map") == BIEB)
	if FileAccess.file_exists(GameState.autosave_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.autosave_path))
	GameState.checkpoint = {}
	GameState.gold = 1
	GameState.continue_game()
	check("geladen: weer in de Golem Hall", await wait_scene("ArchiefGolemhal"))
	await wait_fade()
	check("na laden: checkpoint uit de save (Library %s), goud van de save (%d)" % [cp_tile(), GameState.gold],
			GameState.checkpoint.get("map") == BIEB and cp_tile() == sp[0] and GameState.gold == saved_gold
			and int(GameState.checkpoint["state"]["gold"]) == gold0)
	var golem: Node = scene().get_monster("golem")
	check("de Golem staat er", golem != null and golem.boss)
	if golem == null:
		return
	scene().start_monster_battle(golem)
	check("baasgevecht tegen de Golem", await wait_scene("Battle") and GameState.pending_boss)
	var over := await lose_battle()
	check("GAME OVER-tekst: '%s'" % over.replace("\n", " / "), over == "GAME OVER\nYou wake before the door...")
	check("na game over: in de Library (kamer voor de baas)", await wait_scene("ArchiefBibliotheek"))
	await pframes(3)
	check("op de ingang van de Library %s (nu %s), kijkt naar de deur" % [sp[0], tile()], tile() == sp[0]
			and player().facing == Vector2i.UP)
	check("vol HP/MP, voortgang van bij binnenkomst (goud %d = %d, Lv %d)" % [GameState.gold, gold0, lv0],
			full_hp_mp() and GameState.gold == gold0 and int(GameState.party[0]["level"]) == lv0)
	check("Golem niet als verslagen gemarkeerd", not GameState.story_flags.has(SD.GOLEM_FLAG) and not GameState.has_kern("golemkern"))
	check("last_respawn: baas = true, Library", GameState.last_respawn.get("boss") == true and GameState.last_respawn.get("map") == BIEB)
	var line := await respawn_line()
	check("bericht: '%s'" % line, line == "You wake before the door...")
	await wait_until(func(): return not Dialog._is_typing(), 4.0)
	await pframes(4)
	var shot_path := v19_dir.path_join("v19_respawn.png") if v19_dir != "" else (shots.path_join("v19_respawn.png") if shots != "" else "")
	if shot_path != "":
		await v19_shot(shot_path)
	await close_dialog()
	# opnieuw naar binnen: de Golem staat er nog
	r = await enter(GOLEMHAL, "zuid")
	check("Golem Hall opnieuw: de Golem staat er nog", r != null and r.get_monster("golem") != null)
	check("checkpoint nog steeds de Library", GameState.checkpoint.get("map") == BIEB)


# ================================================================ E: Wortelkoning
func _woud_tests() -> void:
	setup_game(8)
	GameState.story_flags["quest_noor"] = true
	var r := await enter(SPORENKRING, "zuid")
	check("in de Spore Ring (kamer voor de Root King)", r != null)
	if r == null:
		return
	await freeze_monsters(r)
	var sp := spawn_of("woud_sporenkring", "zuid")
	check("checkpoint = ingang Spore Ring %s" % [sp[0]], GameState.checkpoint.get("map") == SPORENKRING and cp_tile() == sp[0])
	r = await enter("res://scenes/maps/woud_open_plek.tscn", "zuid")
	check("Clearing: geen nieuw checkpoint (baaskamer)", r != null and GameState.checkpoint.get("map") == SPORENKRING)
	var boss: Node = r.get_monster("baas") if r else null
	check("The Root King staat er", boss != null and boss.boss)
	if boss == null:
		return
	r.start_monster_battle(boss)
	check("baasgevecht tegen The Root King", await wait_scene("Battle") and GameState.pending_boss)
	var over := await lose_battle()
	check("GAME OVER-tekst: '%s'" % over.replace("\n", " / "), over == "GAME OVER\nYou wake before the door...")
	check("na game over: in de Spore Ring", await wait_scene("WoudSporenkring"))
	await pframes(3)
	check("op de ingang %s (nu %s), vol HP/MP" % [sp[0], tile()], tile() == sp[0] and full_hp_mp())
	check("Root King niet verslagen, Noor niet gered", not GameState.story_flags.has(SD.WORTELKONING_FLAG)
			and not GameState.story_flags.has("noor_gered") and not GameState.has_member("noor"))
	await respawn_line()
	await close_dialog()
	r = await enter("res://scenes/maps/woud_open_plek.tscn", "zuid")
	check("Clearing opnieuw: baas + Noor in de cocon", r != null and r.get_monster("baas") != null
			and r.get_node("Objects/Cocon").visible and not Story.running)


# ================================================================ F: overig
func _misc_tests() -> void:
	# opslaan IN de kamer voor de baas en laden: het checkpoint (van binnenkomst) blijft
	setup_game(5)
	var r := await enter(BIEB, "zuid")
	await freeze_monsters(r)
	var gold0 := GameState.gold
	player().place_at(Vector2i(8, 6), Vector2i.LEFT)
	await frames(2)
	GameState.gold += 40
	GameState.save_game(tile(), player().facing)
	if FileAccess.file_exists(GameState.autosave_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.autosave_path))
	GameState.continue_game()
	check("geladen in de Library op (8,6)", await wait_scene("ArchiefBibliotheek") and tile() == Vector2i(8, 6))
	check("checkpoint na laden in dezelfde kamer: nog de ingang %s met het goud van toen" % [cp_tile()],
			cp_tile() == Vector2i(5, 7) and int(GameState.checkpoint["state"]["gold"]) == gold0)
	# oude save (v0.18, zonder checkpoint) -> de kamer waar je laadt wordt het checkpoint
	var d := GameState.read_save()
	d.erase("checkpoint")
	d["tile"] = [8, 6]
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("oude save zonder checkpoint laadt", GameState.load_game() and GameState.checkpoint.is_empty())
	GameState.continue_game()
	check("geladen (oude save)", await wait_scene("ArchiefBibliotheek"))
	check("oude save: checkpoint = waar je laadt (8,6) in de Library", GameState.checkpoint.get("map") == BIEB and cp_tile() == Vector2i(8, 6))
	# kapot checkpoint in de save: genegeerd
	d["checkpoint"] = {"map": BIEB, "tile": "x", "state": 5}
	f = FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check("kapot checkpoint in de save: laadt, checkpoint leeg", GameState.load_game() and GameState.checkpoint.is_empty())
	# verslagen baas: Golemhal leeg, geen problemen
	setup_game(5)
	GameState.story_flags[SD.GOLEM_FLAG] = true
	r = await enter(BIEB, "zuid")
	r = await enter(GOLEMHAL, "zuid")
	check("verslagen Golem: Golem Hall zonder baas, checkpoint blijft de Library", r != null and r.get_monster("golem") == null
			and GameState.checkpoint.get("map") == BIEB)
	r = await enter(BIEB, "deur")
	check("terug in de Library (via de deur): checkpoint = daar (5,3)", r != null and GameState.checkpoint.get("map") == BIEB
			and cp_tile() == Vector2i(5, 3))
