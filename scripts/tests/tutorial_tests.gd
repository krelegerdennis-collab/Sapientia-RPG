extends Node
## ALLEEN VOOR TESTEN - tutorial na de Inktwurm (Classic/Action-schakelaar + Quest Log).
## Start:  godot --path . -- --tutorialtest [--shots=/pad/map]
##   Deel A: data (3-5 pagina's, max. 2 regels, Next/Skip, vlagnaam) + pagina's passen op 384x216.
##   Deel B: Classic: na de eerste overwinning op de Inktwurm speelt de tutorial 1x op de kaart,
##           doorklikken met A (en tikken op Next), daarna is de speler vrij, geen uitgang op slot.
##   Deel C: nooit twee keer (nog een uniek-signaal, een ander gevecht, de kamer opnieuw in).
##   Deel D: Skip: B op pagina 1, tik op 'Skip' halverwege; de vlag staat er toch op.
##   Deel E: save/load: de vlag gaat mee, en na laden speelt er niets.
##   Deel F: oude save die de Inktwurm al had (verslagen of gevangen): vlag gezet, niets gedwongen.
##   Deel G: Action-modus: Inktwurm realtime verslagen in de kamer -> tutorial in de kamer.
##   Deel H: game over na de tutorial: de vlag rolt niet terug met het checkpoint.
## Met --shots=map: tutorial_inktwurm_1, tutorial_inktwurm_2 (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const INGANG := "res://scenes/maps/archief_ingang.tscn"
const FLAG := "tutorial_na_inktwurm_gezien"
const EV := "tutorial_na_inktwurm"
const UNIQUE_ROOM_MONSTER := {"id": "inktwurm", "enemy": "inktwurm", "group": ["inktwurm"], "tile": [13, 4], "moves": false}

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	seed(2026)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await wait_until(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: Classic, na de overwinning ===")
	await _classic_tests()
	print("=== Deel C: nooit twee keer ===")
	await _once_tests()
	print("=== Deel D: Skip ===")
	await _skip_tests()
	print("=== Deel E: save/load ===")
	await _save_tests()
	print("=== Deel F: oude save ===")
	await _old_save_tests()
	print("=== Deel G: Action-modus ===")
	await _action_tests()
	print("=== Deel H: checkpoint ===")
	_checkpoint_tests()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	print("TUTORIALTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A: data
func _data_tests() -> void:
	check("vlagnaam exact '%s'" % FLAG, SD.TUTORIAL_INKTWURM_FLAG == FLAG and SD.TUTORIAL_INKTWURM == EV)
	check("Inktwurm -> tutorial (AFTER_UNIQUE) en oude-save-vlag (UNIQUE_SEEN_FLAGS)",
			SD.AFTER_UNIQUE.get("inktwurm") == EV and SD.UNIQUE_SEEN_FLAGS.get("inktwurm") == FLAG)
	var pages: Array = SD.TUT_INKT_PAGES
	check("3-5 pagina's (%d)" % pages.size(), pages.size() >= 3 and pages.size() <= 5)
	check("elke pagina max. 2 regels", pages.all(func(p): return str(p).split("\n").size() <= 2))
	check("Engels: Classic/Action en Quest Log komen voor", " ".join(pages).contains("Classic")
			and " ".join(pages).contains("Action") and " ".join(pages).contains("Quest Log"))
	check("geen uitleg over vangen (Codex/Blank Book)", not " ".join(pages).to_lower().contains("capture")
			and not " ".join(pages).contains("Codex") and not " ".join(pages).contains("Book"))
	var first: Array = SD.EVENTS[EV][0]["do"]
	check("event zet de vlag als eerste commando", first[0] == ["flag", FLAG])
	check("pagina 1: keuze Next/Skip, Skip = stoppen", first[1][0] == "choice" and first[1][2] == ["Next", "Skip"]
			and first[1][3][1] == "")
	check("tweede variant (vlag gezet) doet niets", (SD.EVENTS[EV][1]["do"] as Array).is_empty()
			and SD.EVENTS[EV][0]["if"] == {"not_flags": [FLAG]})


# ================================================================ deel B: Classic
func _classic_tests() -> void:
	setup()
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("Archief-ingang geladen", false)
		return
	check("nieuw spel: vlag niet gezet, niets wacht", not GameState.story_flags.has(FLAG) and Story.pending_unique_event == "")
	check("kamer met de Ink Worm: hij verschijnt", await respawn_with_unique(room) == 1)
	var hist := Story.history.size()
	var b := await start_battle(["inktwurm"])
	if b == null:
		check("gevecht gestart", false)
		return
	check("tijdens het gevecht: tutorial nog niet gestart", not Story.running and not Story.history.slice(hist).has(EV))
	await finish()
	check("verslagen -> uniek 'verslagen'", GameState.unique_state("inktwurm") == "verslagen")
	check("terug op de kaart", await wait_scene_path(INGANG))
	check("tutorial start vanzelf op de kaart", await wait_until(func(): return Story.running and Story.current_event == EV, 5.0))
	check("vlag meteen gezet", GameState.story_flags.has(FLAG))
	check("pagina 1 als systeemvak met Next/Skip", await wait_page() and Dialog.choices == ["Next", "Skip"]
			and Dialog.style_kind == "vak" and Dialog.text_label.text == SD.TUT_INKT_PAGES[0])
	check("pagina 1 past: tekst + keuzes binnen 384x216, niet over elkaar", page_fits())
	await screenshot("tutorial_inktwurm_1")
	check("speler staat stil tijdens de tutorial", player().input_locked)
	await press_interact()
	check("A = Next: pagina 2 (Battle Style)", await wait_page() and Dialog.text_label.text == SD.TUT_INKT_PAGES[1]
			and Story.current_event == EV + "_2")
	check("pagina 2 past", page_fits())
	await screenshot("tutorial_inktwurm_2")
	await tap_choice(0)
	check("tik op Next: pagina 3", await wait_page() and Dialog.text_label.text == SD.TUT_INKT_PAGES[2] and page_fits())
	await press_interact()
	check("pagina 4 (Quest Log): gewone tekst, tik = sluiten", await wait_page() and Dialog.choices.is_empty()
			and Dialog.text_label.text == SD.TUT_INKT_PAGES[3] and page_fits())
	await press_interact()
	check("tutorial klaar", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0))
	var seen := Story.history.slice(hist)
	check("alle 4 pagina's 1x gespeeld %s" % [seen], seen.count(EV) == 1 and seen.count(EV + "_2") == 1
			and seen.count(EV + "_3") == 1 and seen.count(EV + "_4") == 1)
	check("speler weer vrij, geen uitgang op slot", await wait_until(func(): return not player().input_locked, 2.0)
			and not GameState.story_flags.keys().any(func(k): return str(k).begins_with("locked:")))


# ================================================================ deel C: nooit twee keer
func _once_tests() -> void:
	var hist := Story.history.size()
	GameState.unique_mark("inktwurm", "verslagen")
	Story._on_unique_marked("inktwurm", "verslagen")
	check("nog een uniek-signaal: niets klaargezet", Story.pending_unique_event == "")
	var b := await start_battle(["mosslijm"])
	if b == null:
		check("gevecht gestart", false)
		return
	await finish()
	await wait_scene_path(INGANG)
	await pframes(60)
	var room := await enter(INGANG, "ingang")
	await pframes(60)
	check("ander gevecht + kamer opnieuw in: geen tutorial %s" % [Story.history.slice(hist)],
			room != null and not Story.history.slice(hist).has(EV) and not Story.running)
	check("Ink Worm komt niet terug in de kamer", room != null and await respawn_with_unique(room) == 0)
	var before := Story.history.size()
	Story.run(EV)
	await pframes(4)
	check("event met de hand starten met vlag gezet: geen pagina's", (Story.pick(EV)["do"] as Array).is_empty()
			and not Dialog.is_open and not Story.running and not Story.history.slice(before).has(EV + "_2"))


# ================================================================ deel D: Skip
func _skip_tests() -> void:
	# B op pagina 1
	setup()
	var room := await enter(INGANG, "ingang")
	var hist := Story.history.size()
	await win_inktwurm(room)
	check("tutorial loopt (2e spel)", await wait_until(func(): return Story.current_event == EV, 5.0) and await wait_page())
	await press_cancel()
	check("B = Skip op pagina 1: meteen klaar", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0))
	var seen := Story.history.slice(hist)
	check("na Skip geen volgende pagina's %s" % [seen], seen.count(EV) == 1 and not seen.has(EV + "_2"))
	check("na Skip: vlag toch gezet, speler vrij", GameState.story_flags.has(FLAG)
			and await wait_until(func(): return not player().input_locked, 2.0))
	# tik op 'Skip' halverwege (pagina 2)
	setup()
	room = await enter(INGANG, "ingang")
	hist = Story.history.size()
	await win_inktwurm(room)
	await wait_until(func(): return Story.current_event == EV, 5.0)
	await wait_page()
	await press_interact()
	check("pagina 2 bereikt", await wait_page() and Story.current_event == EV + "_2")
	await tap_choice(1)
	check("tik op Skip (pagina 2): klaar", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0))
	seen = Story.history.slice(hist)
	check("na Skip op pagina 2: pagina 3/4 niet %s" % [seen], seen.has(EV + "_2") and not seen.has(EV + "_3") and not seen.has(EV + "_4"))


# ================================================================ deel E: save/load
func _save_tests() -> void:
	var p := player()
	check("opslaan na de tutorial", p != null and GameState.save_game(p.get_tile(), p.facing))
	var raw := GameState.read_save(GameState.save_path)
	check("save bevat de vlag", (raw.get("story", {}).get("flags", []) as Array).has(FLAG))
	GameState.new_game("Dax")
	check("nieuw spel: vlag weg", not GameState.story_flags.has(FLAG))
	check("laden: vlag terug", GameState.load_game() and GameState.story_flags.has(FLAG))
	var hist := Story.history.size()
	GameState.change_map(GameState.return_map, "")
	await wait_scene_path(INGANG)
	await wait_fade()
	await pframes(90)
	check("na laden speelt de tutorial niet opnieuw", not Story.history.slice(hist).has(EV) and not Story.running
			and Story.pending_unique_event == "")

	# App dicht vlak na het gevecht: het eenmalige event wacht nog op de kaart.
	setup()
	GameState.in_battle = true
	GameState.unique_mark("inktwurm", "verslagen")
	check("tutorial wacht vlak na het gevecht", Story.pending_unique_event == EV)
	check("opslaan bewaart wachtende tutorial", GameState.save_game(Vector2i(2, 2), Vector2i.DOWN)
			and GameState.read_save(GameState.save_path).get("pending_unique_event", "") == EV)
	GameState.in_battle = false
	GameState.new_game("Dax")
	check("laden herstelt wachtende tutorial", GameState.load_game()
			and Story.pending_unique_event == EV)

	var old := GameState.read_save(GameState.save_path)
	old.erase("pending_unique_event")
	_write(GameState.save_path, old)
	Story.pending_unique_event = "oud_wordt_gewist"
	check("oude save zonder pending_unique_event krijgt lege standaard",
			GameState.load_game() and Story.pending_unique_event == "")


# ================================================================ deel F: oude save
func _old_save_tests() -> void:
	var raw := GameState.read_save(GameState.save_path)
	for how in ["verslagen", "gevangen"]:
		var old := raw.duplicate(true)
		var flags: Array = old["story"]["flags"]
		flags.erase(FLAG)
		old["uniek"] = {"inktwurm": how}
		_write(GameState.save_path, old)
		GameState.new_game("Dax")
		check("oude save (Ink Worm %s, zonder vlag): vlag gezet bij laden" % how, GameState.load_game()
				and GameState.story_flags.has(FLAG))
	var hist := Story.history.size()
	GameState.change_map(GameState.return_map, "")
	await wait_scene_path(INGANG)
	await wait_fade()
	await pframes(90)
	check("oude save: niets gedwongen op de kaart", not Story.history.slice(hist).has(EV) and not Story.running)
	var fresh := raw.duplicate(true)
	(fresh["story"]["flags"] as Array).erase(FLAG)
	fresh.erase("uniek")
	_write(GameState.save_path, fresh)
	check("oude save zonder Ink Worm: vlag niet gezet (tutorial komt later gewoon)", GameState.load_game()
			and not GameState.story_flags.has(FLAG) and GameState.unique_available("inktwurm"))


# ================================================================ deel G: Action
func _action_tests() -> void:
	setup()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("Archief-ingang geladen (Action)", false)
		return
	check("Action-modus aan in de kamer", Settings.action_battles() and room.get("som") != null)
	var hist := Story.history.size()
	# zoals som_arena._defeat_enemy: realtime verslagen, geen gevechtsscène
	GameState.mark_defeated("inktwurm")
	check("Action: tutorial start in de kamer", await wait_until(func(): return Story.current_event == EV, 5.0)
			and scene() == room and not GameState.in_battle)
	await wait_page()
	await press_cancel()
	check("Action: Skip werkt, speler vrij", await wait_until(func(): return not Story.running and not Dialog.is_open, 3.0)
			and GameState.story_flags.has(FLAG) and await wait_until(func(): return not player().input_locked, 2.0))
	check("Action: 1x", Story.history.slice(hist).count(EV) == 1)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)


# ================================================================ deel H: checkpoint
func _checkpoint_tests() -> void:
	GameState.new_game("Dax")
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.unique_mark("inktwurm", "gevangen")
	GameState.story_flags[FLAG] = true
	GameState.respawn_at_checkpoint(false)
	check("game over na de tutorial (gevangen rolt terug): vlag blijft", GameState.story_flags.has(FLAG)
			and GameState.unique_available("inktwurm"))
	GameState.new_game("Dax")
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.unique_mark("inktwurm", "verslagen")
	GameState.respawn_at_checkpoint(false)
	check("game over, Ink Worm verslagen: vlag gezet (nooit achteraf)", GameState.story_flags.has(FLAG)
			and Story.pending_unique_event == "")
	GameState.take_autosave_request()


# ================================================================ helpers
func setup() -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""


func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


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


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_scene_named(n: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == n and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


## Tekstvak open en uitgetypt (bij een vraag: keuzes zichtbaar).
func wait_page() -> bool:
	var ok := await wait_until(page_ready, 5.0)
	await pframes(2)
	return ok


func page_ready() -> bool:
	if not Dialog.is_open or Dialog._is_typing():
		return false
	return Dialog.choices.is_empty() or (Dialog._choice_box != null and Dialog._choice_box.visible)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


## Per beeld (niet per physics-stap): player.gd leest is_action_just_pressed in _process. Eerst
## op het begin van een beeld wachten (na een screenshot staat de teller anders al een beeld verder).
func press_interact() -> void:
	await get_tree().process_frame
	Input.action_press("interact")
	await pframes(2)
	Input.action_release("interact")
	await pframes(2)


func press_cancel() -> void:
	await get_tree().process_frame
	Input.action_press("cancel")
	await pframes(2)
	Input.action_release("cancel")
	await pframes(2)


## Tik (touch) op keuze i in het tekstvak.
func tap_choice(i: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	Dialog._on_choice_input(ev, i)
	await pframes(2)


## Pagina binnen 384x216, elke regel naast de Next/Skip-keuzes (niet erover), max. 2 regels.
func page_fits() -> bool:
	var vs := get_viewport().get_visible_rect().size
	var r: Rect2 = Dialog.box_rect()
	if r.position.x < 0 or r.position.y < 0 or r.end.x > vs.x or r.end.y > vs.y:
		return false
	var font: Font = Dialog.text_label.get_theme_font("font")
	var fs: int = Dialog.text_label.get_theme_font_size("font_size")
	var room_w := r.size.x - Dialog.PAD_L - Dialog.PAD_R
	if Dialog._choice_box != null and not Dialog.choices.is_empty():
		room_w = Dialog._choice_box.position.x - Dialog.PAD_L - 4.0
	var lines := Dialog.text_label.text.split("\n")
	if lines.size() > 2:
		return false
	for l in lines:
		if font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room_w:
			print("INFO  te breed (%d > %d): %s" % [font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, room_w, l])
			return false
	return true


func enter(path: String, spawn: String) -> Node:
	GameState.has_return_point = false
	GameState.map_monster_battle = {}
	GameState.change_map(path, spawn)
	if not await wait_scene_path(path):
		return null
	await wait_fade()
	await wait_until(func(): return not Story.running, 5.0)
	await pframes(6)
	var s := scene()
	if s != null and "monsters" in s:
		for m in s.monsters:
			if is_instance_valid(m):
				m.moves = false
	return s


## De kamer opnieuw laten spawnen met (alleen) een Inktwurm erin.
func respawn_with_unique(r: Node) -> int:
	for m in r.monsters:
		if is_instance_valid(m):
			m.queue_free()
	r.monsters.clear()
	r.room = r.room.duplicate(true)
	r.room["monsters"] = [UNIQUE_ROOM_MONSTER.duplicate(true)]
	r._spawn_monsters()
	await pframes(2)
	return r.monsters.filter(func(m): return is_instance_valid(m) and m.enemy_id == "inktwurm").size()


func win_inktwurm(room: Node) -> void:
	if room == null:
		return
	await respawn_with_unique(room)
	if await start_battle(["inktwurm"]) == null:
		return
	await finish()
	await wait_scene_path(INGANG)


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func start_battle(enemies: Array) -> Node:
	var p := player()
	if p == null:
		return null
	GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", false, 0)
	if not await wait_scene_named("Battle"):
		return null
	return battle()


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
	for k in 4:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])
	await pframes(2)


const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up", 5: "move_left"}


## Aanvallen tot alle vijanden weg zijn (HP op 1 gezet), berichten wegklikken.
func finish() -> void:
	for guard in 80:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "message_wait":
			await tap("interact")
			continue
		for e in b.enemies:
			if int(e["s"]["hp"]) > 1:
				e["s"]["hp"] = 1
		await cross_to(b, 0)
		await tap("interact")
		if await wait_battle_state(["target_enemy", "busy", "message_wait"], 5) == "target_enemy":
			await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size(), " + _3x ", big.get_size())


func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
