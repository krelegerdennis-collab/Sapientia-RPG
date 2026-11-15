extends Node
## Colosseum-flow (--arenatest). Geen CI-matrix.
## Start: godot --path . -- --arenatest

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Rewards := preload("res://scripts/data/arena_rewards.gd")
const ShopData := preload("res://scripts/data/arena_shop_data.gd")
const Shop := preload("res://scripts/arena/arena_shop.gd")
const Art := preload("res://scripts/data/arena_art.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const HudScript := preload("res://scripts/arena/arena_hud.gd")
const ShopScreen := preload("res://scripts/arena/arena_shop_screen.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const Equipment := preload("res://scripts/equipment.gd")
const UiTouch := preload("res://scripts/ui/ui_touch.gd")

const WORLD := "res://scenes/maps/wereldkaart.tscn"
const LOBBY := "res://scenes/maps/arena_lobby.tscn"
const HALL := "res://scenes/maps/arena_hall.tscn"

var failures := 0
var passes := 0
var _run: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_all.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run_all() -> void:
	ReleaseFlags.arena_enabled_override = -1
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	_flag_off()
	await _world_map_untouched()
	GameState.new_game("Dax")
	_full_path()
	GameState.new_game("Dax")
	_leave_keeps_rewards()
	GameState.new_game("Dax")
	_wipe_keeps_rewards()
	GameState.new_game("Dax")
	_single_down()
	GameState.new_game("Dax")
	_no_double_rewards()
	GameState.new_game("Dax")
	_save_roundtrip()
	GameState.new_game("Dax")
	_shop()
	GameState.new_game("Dax")
	_touch_choice()
	ReleaseFlags.arena_enabled_override = -1
	GameState.new_game("Dax")
	await _rooms()
	ReleaseFlags.arena_enabled_override = -1
	_drop_run()
	print("ARENATEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _drop_run() -> void:
	if _run != null and is_instance_valid(_run):
		_run.free()
	_run = null


func _make_run() -> Node:
	_drop_run()
	_run = RunScript.new()
	_run.name = "TestArenaRun"
	add_child(_run)
	return _run


func _waves(run: Node) -> Node:
	return run.get_node("Waves")


func _flag_off() -> void:
	check("ARENA_ENABLED is false", ReleaseFlags.ARENA_ENABLED == false)
	check("arena_enabled() volgt de const", ReleaseFlags.arena_enabled() == false)
	check("vlag uit: geen wereldtegel geladen", Art.world_texture() == null)
	check("vlag uit: geen npc-sheet geladen", Art.npc_texture() == null)
	check("vlag uit: tokens beginnen op 0", GameState.arena_tokens == 0)
	check("vlag uit: geen ArenaRun op GameState", GameState.get_node_or_null("ArenaRun") == null)
	var proj := FileAccess.get_file_as_string("res://project.godot")
	var auto := ""
	if proj.contains("[autoload]"):
		auto = proj.split("[autoload]")[1].split("[")[0]
	check("geen arena-autoload", not auto.to_lower().contains("arena"))
	var map_src := FileAccess.get_file_as_string("res://scripts/map.gd")
	check("wereldkaart roept consider alleen via de vlag", map_src.contains("arena_entry.gd") and map_src.contains("consider(self)"))
	var dummy := _dummy_map()
	var exits_before := dummy.get_node("Exits").get_child_count()
	var gold_before := GameState.gold
	var inv_before := GameState.inventory.duplicate(true)
	Entry.consider(dummy)
	check("vlag uit: consider voegt geen uitgang toe", dummy.get_node("Exits").get_child_count() == exits_before)
	check("vlag uit: geen marker", dummy.get_node_or_null("Objects/ArenaMarker") == null)
	check("vlag uit: goud onaangeroerd", GameState.gold == gold_before)
	check("vlag uit: tas onaangeroerd", GameState.inventory == inv_before)
	check("vlag uit: kopen weigert", Shop.buy("potion").get("ok") == false and GameState.arena_tokens == 0)
	check("vlag uit: arena-zwaard is geen uitrusting", not Equipment.is_equipment("arena_blade"))
	dummy.queue_free()
	# De haak zelf werkt pas als een test de override aanzet, en zet hem daarna terug.
	ReleaseFlags.arena_enabled_override = 1
	var open_map := _dummy_map()
	Entry.consider(open_map)
	check("vlag aan: uitgang verschijnt", open_map.get_node_or_null("Exits/NaarArena") != null)
	check("vlag aan: marker verschijnt", open_map.get_node_or_null("Objects/ArenaMarker") != null)
	var gate: Node2D = open_map.get_node("Exits/NaarArena")
	check("vlag aan: doel is de lobby", str(gate.get("target_map")) == LOBBY)
	open_map.queue_free()
	ReleaseFlags.arena_enabled_override = -1
	check("override terug: vlag weer uit", ReleaseFlags.arena_enabled() == false)


func _dummy_map() -> Node2D:
	var map := Node2D.new()
	map.name = "DummyWorld"
	var exits := Node2D.new()
	exits.name = "Exits"
	var objects := Node2D.new()
	objects.name = "Objects"
	map.add_child(exits)
	map.add_child(objects)
	add_child(map)
	return map


func _world_map_untouched() -> void:
	ReleaseFlags.arena_enabled_override = -1
	var packed := load(WORLD) as PackedScene
	var cold: Node = packed.instantiate()
	var cold_names: Array[String] = []
	for c in cold.get_node("Exits").get_children():
		cold_names.append(str(c.name))
	cold.free()
	var gold_before := GameState.gold
	var tokens_before := GameState.arena_tokens
	var live: Node = packed.instantiate()
	add_child(live)
	await get_tree().process_frame
	var live_names: Array[String] = []
	for c in live.get_node("Exits").get_children():
		live_names.append(str(c.name))
	check("wereldkaart: zelfde uitgangen als het bestand", live_names == cold_names)
	check("wereldkaart: geen NaarArena", not live_names.has("NaarArena"))
	check("wereldkaart: geen ArenaMarker", live.get_node_or_null("Objects/ArenaMarker") == null)
	check("wereldkaart: tokens blijven 0", GameState.arena_tokens == tokens_before)
	check("wereldkaart: goud ongewijzigd", GameState.gold == gold_before)
	check("wereldkaart: geen run-node", GameState.get_node_or_null("ArenaRun") == null)
	live.queue_free()
	await get_tree().process_frame


func _full_path() -> void:
	var run := _make_run()
	var waves := _waves(run)
	var exp0 := int(GameState.party[0]["exp"])
	run.begin()
	check("start: wave 1", run.phase == RunScript.PHASE_WAVE and run.wave == 1 and run.last_started == 1)
	for n in range(1, Rewards.WAVE_COUNT):
		waves.wave_cleared.emit(n)
		check("wave %d: keuze" % n, run.phase == RunScript.PHASE_CHOICE and run.waves_cleared == n)
		run.choose_continue()
		check("wave %d: verder" % n, run.phase == RunScript.PHASE_WAVE and run.wave == n + 1)
	waves.wave_cleared.emit(Rewards.WAVE_COUNT)
	check("wave 5: meteen results", run.phase == RunScript.PHASE_RESULTS and run.waves_cleared == 5 and not run.wiped)
	var want_tokens := 0
	var want_xp := 0
	for n in range(1, 6):
		var row := Rewards.for_wave(n)
		want_tokens += int(row["tokens"])
		want_xp += int(row["xp"])
	check("vijf waves: tokens", GameState.arena_tokens == want_tokens and run.earned_tokens == want_tokens)
	check("vijf waves: xp per held", int(GameState.party[0]["exp"]) == exp0 + want_xp)
	run.acknowledge()
	check("results -> lobby", run.phase == RunScript.PHASE_LOBBY)
	check("lobby houdt de tokens", GameState.arena_tokens == want_tokens)


func _leave_keeps_rewards() -> void:
	var run := _make_run()
	var waves := _waves(run)
	run.begin()
	waves.wave_cleared.emit(1)
	run.choose_continue()
	waves.wave_cleared.emit(2)
	var held := GameState.arena_tokens
	run.choose_leave()
	check("leave na wave 2: results", run.phase == RunScript.PHASE_RESULTS and run.waves_cleared == 2 and not run.wiped)
	check("leave houdt wave 1+2", held == int(Rewards.for_wave(1)["tokens"]) + int(Rewards.for_wave(2)["tokens"]))
	run.acknowledge()
	check("leave -> lobby met tokens", run.phase == RunScript.PHASE_LOBBY and GameState.arena_tokens == held)


func _wipe_keeps_rewards() -> void:
	var run := _make_run()
	var waves := _waves(run)
	run.begin()
	waves.wave_cleared.emit(1)
	run.choose_continue()
	waves.wave_cleared.emit(2)
	run.choose_continue()
	check("wipe begint in wave 3", run.phase == RunScript.PHASE_WAVE and run.wave == 3)
	var held := GameState.arena_tokens
	waves.party_wiped.emit()
	check("party_wiped: results, rewards blijven", run.phase == RunScript.PHASE_RESULTS and run.wiped and run.waves_cleared == 2)
	check("party_wiped: geen extra tokens", GameState.arena_tokens == held)
	waves.party_wiped.emit()
	check("tweede party_wiped doet niets", run.phase == RunScript.PHASE_RESULTS and GameState.arena_tokens == held)
	run.acknowledge()
	check("wipe -> lobby", run.phase == RunScript.PHASE_LOBBY and GameState.arena_tokens == held)


func _single_down() -> void:
	check("noor erbij", GameState.add_member("noor"))
	var dax: Dictionary = GameState.party[0]
	var noor: Dictionary = GameState.party[1]
	var mx := int(dax["max_hp"])
	dax["hp"] = maxi(1, int(mx / 2.0))
	noor["hp"] = 0
	var run := _make_run()
	var waves := _waves(run)
	run.begin()
	var ping := MemberDown.new()
	var heard := {"on": false}
	ping.member_down.connect(func(_id: String) -> void: heard["on"] = true)
	ping.member_down.emit("dax")
	check("stub heeft geen member_down", not waves.has_signal("member_down"))
	check("één speler neer: signaal komt aan, run blijft", bool(heard["on"]) and run.phase == RunScript.PHASE_WAVE and run.wave == 1)
	check("neer blijft 0 voor de clear", int(noor["hp"]) == 0)
	var half := int(dax["hp"])
	waves.wave_cleared.emit(1)
	var gain := int(float(mx) * float(Rewards.hp_percent()) / 100.0)
	check("tussen waves: procent HP, niet boven max", int(dax["hp"]) == mini(mx, half + gain))
	check("één speler neer blijft neer", int(noor["hp"]) == 0)
	check("na clear: keuze, geen results", run.phase == RunScript.PHASE_CHOICE)


func _no_double_rewards() -> void:
	var run := _make_run()
	var waves := _waves(run)
	run.begin()
	waves.wave_cleared.emit(1)
	var tokens := GameState.arena_tokens
	var exp := int(GameState.party[0]["exp"])
	waves.wave_cleared.emit(1)
	waves.wave_started.emit(1)
	check("tweede wave_cleared: geen dubbele beloning", GameState.arena_tokens == tokens and int(GameState.party[0]["exp"]) == exp)
	check("tweede signaal blijft op de keuze", run.phase == RunScript.PHASE_CHOICE and run.waves_cleared == 1)


func _save_roundtrip() -> void:
	GameState.arena_tokens = 23
	var snap := GameState.state_data(Vector2i(2, 3), Vector2i.DOWN)
	check("state_data schrijft arena_tokens", int(snap.get("arena_tokens", -1)) == 23)
	var path := "user://arenatest_round.json"
	var saved: bool = GameState.save_game(Vector2i(2, 3), Vector2i.DOWN, path)
	check("save_game lukt", saved)
	GameState.arena_tokens = 0
	var loaded: bool = GameState.load_game(path)
	check("load_game lukt", loaded)
	check("roundtrip tokens 23", GameState.arena_tokens == 23)
	var old := snap.duplicate(true)
	old.erase("arena_tokens")
	GameState.arena_tokens = 77
	var applied: bool = GameState.apply_state(old)
	check("oude save zonder veld laadt", applied)
	check("ontbrekend veld wordt 0", GameState.arena_tokens == 0)
	var bad := snap.duplicate(true)
	bad["arena_tokens"] = "nope"
	GameState.arena_tokens = 9
	check("kapot type laadt", GameState.apply_state(bad))
	check("kapot type wordt 0", GameState.arena_tokens == 0)
	GameState.arena_tokens = Rewards.token_cap()
	GameState.add_arena_tokens(50)
	check("plafond houdt tokens tegen", GameState.arena_tokens == Rewards.token_cap())


func _shop() -> void:
	var before := GameState.item_count("drankje")
	GameState.arena_tokens = 40
	var closed: Dictionary = Shop.buy("potion")
	check("winkel dicht: weigert", closed.get("ok") == false and GameState.arena_tokens == 40)
	check("winkel dicht: tas gelijk", GameState.item_count("drankje") == before)
	var blade := ShopData.gear("arena_blade")
	var cap := ShopData.gear("arena_cap")
	var mail := ShopData.gear("arena_mail")
	var cave_atk := int(GradeGear.item("bg_g1_zwaard").get("atk", 0))
	var cave_def_helm := int(GradeGear.item("bg_g1_helm").get("def", 0))
	var cave_def_body := int(GradeGear.item("bg_g1_harnas").get("def", 0))
	check("blade niet sterker dan grot-zwaard", int(blade.get("atk", 99)) <= cave_atk and int(blade.get("atk", 0)) > 0)
	check("cap niet sterker dan grot-helm", int(cap.get("def", 99)) <= cave_def_helm)
	check("mail niet sterker dan grot-harnas", int(mail.get("def", 99)) <= cave_def_body)
	ReleaseFlags.arena_enabled_override = 1
	GameState.arena_tokens = ShopData.POTION_PRICE - 1
	var short: Dictionary = Shop.buy("potion")
	check("te weinig tokens: weigert", short.get("ok") == false and str(short.get("text", "")).contains("Arena Tokens"))
	check("te weinig: niets afgeschreven", GameState.arena_tokens == ShopData.POTION_PRICE - 1)
	check("te weinig: tas gelijk", GameState.item_count("drankje") == before)
	GameState.arena_tokens = ShopData.POTION_PRICE
	var bought: Dictionary = Shop.buy("potion")
	check("koop trekt tokens af", bought.get("ok") == true and GameState.arena_tokens == 0)
	check("koop legt het item in de tas", GameState.item_count("drankje") == before + 1)
	GameState.arena_tokens = ShopData.BLADE_PRICE
	var gear_buy: Dictionary = Shop.buy("blade")
	check("gear gekocht", gear_buy.get("ok") == true and GameState.item_count("arena_blade") == 1)
	check("gear telt als uitrusting zolang de vlag aan staat", Equipment.is_equipment("arena_blade"))
	check("gear-atk is de placeholder", int(Equipment.item("arena_blade").get("atk", 0)) == ShopData.BLADE_ATK)
	var screen := ShopScreen.new()
	screen.name = "TestShop"
	add_child(screen)
	var btn := screen.find_child("buy_potion", true, false) as Button
	check("winkelknop bestaat", btn != null)
	if btn != null:
		check("winkelknop is een tikdoel", btn.custom_minimum_size.y >= UiTouch.TOUCH_MIN)
	GameState.arena_tokens = ShopData.POTION_PRICE
	var count_now := GameState.item_count("drankje")
	if btn != null:
		btn.pressed.emit()
	check("tik op de knop koopt", GameState.arena_tokens == 0 and GameState.item_count("drankje") == count_now + 1)
	screen.queue_free()
	ReleaseFlags.arena_enabled_override = -1
	check("vlag weer uit: gear telt niet meer mee", not Equipment.is_equipment("arena_blade"))


func _touch_choice() -> void:
	var run := _make_run()
	var hud := HudScript.new()
	hud.name = "TestArenaHud"
	add_child(hud)
	hud.bind(run)
	run.begin()
	check("tijdens de wave nog geen Continue", hud.find_child("Continue", true, false) == null)
	_waves(run).wave_cleared.emit(1)
	var cont := hud.find_child("Continue", true, false) as Button
	var leave := hud.find_child("Leave", true, false) as Button
	check("Continue en Leave staan klaar", cont != null and leave != null)
	if cont != null and leave != null:
		check("Continue is een tikdoel", cont.custom_minimum_size.y >= UiTouch.TOUCH_MIN)
		check("Leave is een tikdoel", leave.custom_minimum_size.y >= UiTouch.TOUCH_MIN)
		cont.pressed.emit()
	check("Continue gaat naar wave 2", run.phase == RunScript.PHASE_WAVE and run.wave == 2)
	_waves(run).wave_cleared.emit(2)
	leave = hud.find_child("Leave", true, false) as Button
	if leave != null:
		leave.pressed.emit()
	var back := hud.find_child("Back to the lobby", true, false) as Button
	check("resultaatknop is een tikdoel", back != null and back.custom_minimum_size.y >= UiTouch.TOUCH_MIN)
	if back != null:
		back.pressed.emit()
	check("knop terug naar de lobby", run.phase == RunScript.PHASE_LOBBY)
	hud.queue_free()


func _rooms() -> void:
	ReleaseFlags.arena_enabled_override = -1
	var lobby: Node = (load(LOBBY) as PackedScene).instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var lg: TileMapLayer = lobby.get_node("Ground")
	check("lobby is 24x14", lg.get_used_rect().size == Vector2i(24, 14))
	var lgates: Array = lobby.gate_tiles()
	check("lobby-poort midden noord", lgates.size() == 2 and lgates[0] == Vector2i(11, 0) and lgates[1] == Vector2i(12, 0))
	check("lobby heeft de winkelier", lobby.get_node_or_null("Objects/ArenaShopkeeper") != null)
	check("lobby is 24 tegels van 16 px", lg.get_used_rect().size.x * 16 == 384)
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	add_child(hall)
	await get_tree().process_frame
	var hg: TileMapLayer = hall.get_node("Ground")
	var rect: Rect2i = hg.get_used_rect()
	check("hal is 30x20", rect.size == Vector2i(30, 20))
	var hgates: Array = hall.gate_tiles()
	check("hal-poort midden noord", hgates.size() == 2 and hgates[0] == Vector2i(14, 0) and hgates[1] == Vector2i(15, 0))
	check("hal heeft geen winkelier", hall.get_node_or_null("Objects/ArenaShopkeeper") == null)
	var map_px := Vector2i(rect.size.x * 16, rect.size.y * 16)
	check("hal groter dan het 384x216-beeld", map_px.x > 384 and map_px.y > 216)
	var cam: Camera2D = hall.get_node("Objects/Player/Camera2D")
	var span_x := cam.limit_right - cam.limit_left
	var span_y := cam.limit_bottom - cam.limit_top
	check("camera dekt de hal", span_x >= map_px.x and span_y >= map_px.y and span_x < 100000)
	check("vlag uit: kamers starten geen run", GameState.get_node_or_null("ArenaRun") == null)
	lobby.queue_free()
	hall.queue_free()
	await get_tree().process_frame


class MemberDown:
	signal member_down(hero_id: String)
