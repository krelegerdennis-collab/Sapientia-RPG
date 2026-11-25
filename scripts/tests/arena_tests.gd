extends Node
## Colosseum-flow (--arenatest). In CI-matrix.
## Start: godot --path . -- --arenatest

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Rewards := preload("res://scripts/data/arena_rewards.gd")
const ShopData := preload("res://scripts/data/arena_shop_data.gd")
const Shop := preload("res://scripts/arena/arena_shop.gd")
const Art := preload("res://scripts/data/arena_art.gd")
const Entry := preload("res://scripts/arena/arena_entry.gd")
const GateLock := preload("res://scripts/arena/arena_gate_lock.gd")
const RunScript := preload("res://scripts/arena/arena_run.gd")
const HudScript := preload("res://scripts/arena/arena_hud.gd")
const ShopScreen := preload("res://scripts/arena/arena_shop_screen.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const Equipment := preload("res://scripts/equipment.gd")
const UiTouch := preload("res://scripts/ui/ui_touch.gd")
const Berggrot := preload("res://scripts/data/berggrot_data.gd")
const MapLightingC := preload("res://scripts/map_lighting.gd")

const WORLD := "res://scenes/maps/wereldkaart.tscn"
const LOBBY := "res://scenes/arena/arena_lobby.tscn"
const HALL := "res://scenes/arena/arena_hall.tscn"

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
	ReleaseFlags.arena_enabled_override = 1
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
	ReleaseFlags.arena_enabled_override = -1
	GameState.new_game("Dax")
	_shop()
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	_touch_choice()
	ReleaseFlags.arena_enabled_override = -1
	GameState.new_game("Dax")
	await _rooms()
	await _art()
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
	var tok_off := GameState.arena_tokens
	GameState.add_arena_tokens(40)
	check("vlag uit: add_arena_tokens doet niets", GameState.arena_tokens == tok_off)
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
	check("vlag uit: geen overlay", dummy.get_node_or_null("ArenaOverlay") == null)
	check("vlag uit: goud onaangeroerd", GameState.gold == gold_before)
	check("vlag uit: tas onaangeroerd", GameState.inventory == inv_before)
	check("vlag uit: kopen weigert", Shop.buy("potion").get("ok") == false and GameState.arena_tokens == 0)
	check("vlag uit: arena-zwaard is geen uitrusting", not Equipment.is_equipment("arena_blade"))
	dummy.queue_free()
	# De haak zelf werkt pas als een test de override aanzet, en zet hem daarna terug.
	ReleaseFlags.arena_enabled_override = 1
	var tok_on := GameState.arena_tokens
	GameState.add_arena_tokens(7)
	check("vlag aan: add_arena_tokens telt op", GameState.arena_tokens == tok_on + 7)
	GameState.story_flags.erase("noor_lid")
	var open_map := _dummy_map()
	Entry.consider(open_map)
	check("vlag aan: uitgang verschijnt", open_map.get_node_or_null("Exits/NaarArena") != null)
	check("vlag aan: overlay verschijnt", open_map.get_node_or_null("ArenaOverlay") != null)
	check("vlag aan: geen magenta marker", open_map.get_node_or_null("Objects/ArenaMarker") == null)
	var gate: MapExit = open_map.get_node("Exits/NaarArena")
	check("vlag aan: uitgang altijd naar de lobby", gate.target_map == LOBBY and gate.target_spawn == "ingang" and gate.lines.is_empty())
	var origin := Art.WORLD_TILE
	check("vlag aan: uitgang is 2x2 op de tegel", gate.position == Vector2(origin) * 16.0 and gate.size_tiles == Vector2i(2, 2))
	var layer: TileMapLayer = open_map.get_node("ArenaOverlay")
	check("vlag aan: open atlas (0,0)", layer.get_cell_atlas_coords(origin) == Vector2i(0, 0))
	check("vlag aan: open atlas (1,1)", layer.get_cell_atlas_coords(origin + Vector2i(1, 1)) == Vector2i(1, 1))
	check("vlag aan: spawntegel blijft leeg", layer.get_cell_source_id(Vector2i(30, 25)) == -1)
	GameState.story_flags["noor_lid"] = true
	Entry.refresh(open_map)
	check("vlag aan: noor_lid laat de werelduitgang open", gate.target_map == LOBBY and gate.target_spawn == "ingang" and gate.lines.is_empty())
	var parked := MapExit.new()
	GateLock.apply(parked, LOBBY, "ingang")
	check("slot-helper open met noor_lid", parked.target_map == LOBBY and parked.lines.is_empty())
	GameState.story_flags.erase("noor_lid")
	GateLock.apply(parked, LOBBY, "ingang")
	check("slot-helper dicht zonder noor_lid", parked.target_map == "" and parked.lines.size() == 1 and parked.lines[0] == "The gate is closed.")
	parked.free()
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
	check("wereldkaart: geen ArenaOverlay", live.get_node_or_null("ArenaOverlay") == null)
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
	check("lobby-poort in de nis", lgates.size() == 2 and lgates[0] == Vector2i(11, 2) and lgates[1] == Vector2i(12, 2))
	check("lobby heeft de winkelier", lobby.get_node_or_null("Objects/ArenaShopkeeper") != null)
	var layouts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/arena/layouts.json"))
	var lidx := int(layouts["lobby"][0][0])
	check("lobby schildert layouts.json", lg.get_cell_atlas_coords(Vector2i(0, 0)) == Vector2i(lidx % 16, int(lidx / 16.0)))
	var keeper: Node2D = lobby.get_node("Objects/ArenaShopkeeper")
	var kspr := keeper.get_node("Sprite2D") as Sprite2D
	var ksheet := keeper.get("sheet") as Texture2D
	check("winkelier laadt de idle-sheet", kspr.texture != null and str(kspr.texture.resource_path).ends_with("arena_koopman_wm1_slim_idle.png"))
	check("winkelier-sheet is het loopblad", ksheet != null and str(ksheet.resource_path).ends_with("arena_koopman_wm1_slim.png"))
	check("winkelier staat achter de toonbank", keeper.position == Vector2(88, 90))
	var kshape := (keeper.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check("winkelier-botsing 12x6", kshape != null and kshape.size == Vector2(12, 6))
	var lgate := _sprite_named(lobby, "arena_gate.png")
	var lbody := lgate.get_parent() as Node2D if lgate != null else null
	check("lobbypoort gecentreerd op x=192", lbody != null and lbody.position.x == 192.0 and lgate.frame == 2 and lgate.hframes == 3)
	check("lobbypoort dicht: opening 48 px solid", lbody != null and _opening_solid(lbody))
	var lsrc := lg.tile_set.get_source(0) as TileSetAtlasSource
	var glitch := Vector2i(12, 8)
	check("tegel 140/141 animeert 250 ms", lsrc != null and lsrc.get_tile_animation_frames_count(glitch) == 2 and is_equal_approx(lsrc.get_tile_animation_frame_duration(glitch, 0), 0.25) and is_equal_approx(lsrc.get_tile_animation_frame_duration(glitch, 1), 0.25))
	check("lobby: 3 banken", _sprites_named(lobby, "arena_bench.png").size() == 3)
	check("lobby: 2 kisten", _sprites_named(lobby, "arena_crates.png").size() == 2)
	check("lobbypoort-offset", lgate != null and lgate.centered == false and lgate.offset == Vector2(-24, -48))
	check("lobby is 24 tegels van 16 px", lg.get_used_rect().size.x * 16 == 384)
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	add_child(hall)
	await get_tree().process_frame
	var hg: TileMapLayer = hall.get_node("Ground")
	var rect: Rect2i = hg.get_used_rect()
	check("hal is 30x20", rect.size == Vector2i(30, 20))
	var hgates: Array = hall.gate_tiles()
	check("hal-poort noord", hgates.size() == 2 and hgates[0] == Vector2i(14, 2) and hgates[1] == Vector2i(15, 2))
	check("hal heeft geen winkelier", hall.get_node_or_null("Objects/ArenaShopkeeper") == null)
	var hidx := int(layouts["hall"][0][0])
	check("hal schildert layouts.json", hg.get_cell_atlas_coords(Vector2i(0, 0)) == Vector2i(hidx % 16, int(hidx / 16.0)))
	var torches := _sprites_named(hall, "arena_torch.png")
	check("hal: zes fakkels", torches.size() == 6)
	check("fakkel: 4 frames", torches.size() == 6 and torches[0].hframes == 4 and torches[0].offset == Vector2(-8, -32))
	var torch_frame := torches[0].frame if torches.size() > 0 else -1
	var braziers := _sprites_named(hall, "arena_brazier.png")
	var brazier_frame := braziers[0].frame if braziers.size() > 0 else -1
	await get_tree().create_timer(0.2).timeout
	check("fakkel loopt", torches.size() == 6 and is_instance_valid(torches[0]) and torches[0].frame != torch_frame)
	check("hal: 4 vuurschalen", braziers.size() == 4 and braziers[0].hframes == 4 and braziers[0].offset == Vector2(-16, -32))
	check("vuurschaal loopt", braziers.size() == 4 and is_instance_valid(braziers[0]) and braziers[0].frame != brazier_frame)
	var hgate := _sprite_named(hall, "arena_gate.png")
	check("hal-poort dicht buiten een golf", hgate != null and hgate.frame == 0 and hgate.hframes == 3)
	check("hal: vip-loge", _sprites_named(hall, "arena_vip_loge.png").size() == 1)
	var ring := hall.get_node_or_null("ArenaSandRing") as CanvasItem
	var hobjects := hall.get_node("Objects")
	check("zandring tussen vloer en objecten", ring != null and hg.get_index() < ring.get_index() and ring.get_index() < hobjects.get_index())
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


func _art() -> void:
	ReleaseFlags.arena_enabled_override = 1
	GameState.new_game("Dax")
	GameState.story_flags.erase("noor_lid")
	check("noor_lid is de Vesper-vlag", Berggrot.TUNNEL_VLAG == "noor_lid")
	var world := Art.world_texture()
	check("wereld-atlas 64x32", world != null and world.get_width() == 64 and world.get_height() == 32)
	var tiles := Art.tiles_texture()
	check("arena-tegels 256x144", tiles != null and tiles.get_width() == 256 and tiles.get_height() == 144)
	var gate_tex := load("res://assets/sprites/arena/arena_gate.png") as Texture2D
	check("poort 144x48", gate_tex != null and gate_tex.get_width() == 144 and gate_tex.get_height() == 48)
	check("bank 32x16", _tex_size("res://assets/sprites/arena/arena_bench.png") == Vector2i(32, 16))
	check("kisten 32x32", _tex_size("res://assets/sprites/arena/arena_crates.png") == Vector2i(32, 32))
	check("vuurschaal 128x32", _tex_size("res://assets/sprites/arena/arena_brazier.png") == Vector2i(128, 32))
	check("vip-loge 48x64", _tex_size("res://assets/sprites/arena/arena_vip_loge.png") == Vector2i(48, 64))
	check("zandring 64x64", _tex_size("res://assets/sprites/arena/arena_sand_ring.png") == Vector2i(64, 64))
	var walk := Art.npc_texture()
	check("koopman-loopblad 72x128", walk != null and walk.get_width() == 72 and walk.get_height() == 128)
	var idle := Art.npc_idle_texture()
	check("koopman-idle 48x128", idle != null and idle.get_width() == 48 and idle.get_height() == 128)
	var icon := Art.arena_icon()
	check("icoon arena 16x16", icon != null and icon.get_width() == 16 and icon.get_height() == 16)
	var token := Art.token_icon()
	check("icoon token 16x16", token != null and token.get_width() == 16 and token.get_height() == 16)
	check("fakkel-emissive", MapLightingC.hd_texture("res://assets/sprites/arena/arena_torch.png", "_e.png") != null)
	check("fakkel-normal", MapLightingC.hd_texture("res://assets/sprites/arena/arena_torch.png", "_n.png") != null)
	check("tegel-normal", MapLightingC.hd_texture("res://assets/tiles/arena/arena_tiles.png", "_n.png") != null)
	var hd2d_was := bool(Settings.get_value("hd2d_light"))
	var tod_was := GameState.time_of_day
	var live: Node = (load(WORLD) as PackedScene).instantiate()
	add_child(live)
	await get_tree().process_frame
	var spawn := live.get_node_or_null("Spawns/van_wilgendal") as Node2D
	check("spawn van_wilgendal blijft vrij", spawn != null and spawn.position == Vector2(488, 408))
	var ground := live.get_node("Ground") as Node
	var ov := live.get_node_or_null("ArenaOverlay") as TileMapLayer
	check("wereldkaart: overlay boven Ground", ov != null and ground.get_index() < ov.get_index())
	var exit := live.get_node_or_null("Exits/NaarArena") as MapExit
	var origin := Art.WORLD_TILE
	check("wereldkaart: uitgang altijd naar de lobby", exit != null and exit.target_map == LOBBY and exit.target_spawn == "ingang" and exit.lines.is_empty() and exit.position == Vector2(origin) * 16.0 and exit.size_tiles == Vector2i(2, 2))
	check("wereldkaart: open atlas op het 2x2", ov != null and ov.get_cell_atlas_coords(origin) == Vector2i(0, 0) and ov.get_cell_atlas_coords(origin + Vector2i(1, 0)) == Vector2i(1, 0) and ov.get_cell_atlas_coords(origin + Vector2i(0, 1)) == Vector2i(0, 1) and ov.get_cell_atlas_coords(origin + Vector2i(1, 1)) == Vector2i(1, 1))
	check("wereldkaart: locked atlas 4-7 ongebruikt", ov != null and ov.get_cell_atlas_coords(origin) != Vector2i(2, 0) and ov.get_cell_atlas_coords(origin + Vector2i(1, 1)) != Vector2i(3, 1))
	var locked_lobby: Node = (load(LOBBY) as PackedScene).instantiate()
	add_child(locked_lobby)
	await get_tree().process_frame
	var locked_gate := _sprite_named(locked_lobby, "arena_gate.png")
	var lobby_exit := locked_lobby.get_node_or_null("Exits/ArenaPoort") as MapExit
	var lobby_body := locked_gate.get_parent() as Node2D if locked_gate != null else null
	check("lobbypoort op slot zonder noor_lid", locked_gate != null and locked_gate.frame == 2 and lobby_exit != null and lobby_exit.target_map == "" and lobby_exit.lines.size() == 1 and lobby_exit.lines[0] == "The gate is closed.")
	check("lobbypoort: opening x168-216 solid", lobby_body != null and lobby_body.position.x == 192.0 and _opening_solid(lobby_body))
	var map_was := GameState.current_map
	locked_lobby.call("_gate_used")
	check("interactie toont dat de poort dicht is", Dialog.is_open and Dialog.text_label.text == "The gate is closed." and GameState.current_map == map_was)
	Dialog.close()
	GameState.story_flags["noor_lid"] = true
	Entry.refresh(live)
	check("wereldkaart: noor_lid verandert de uitgang niet", exit.target_map == LOBBY and exit.target_spawn == "ingang" and exit.lines.is_empty())
	locked_lobby.call("refresh_gate")
	check("lobbypoort open na noor_lid", locked_gate != null and locked_gate.frame == 1 and lobby_exit.target_map == HALL and lobby_exit.target_spawn == "ingang" and lobby_exit.lines.is_empty() and not _opening_solid(lobby_body))
	locked_lobby.queue_free()
	await get_tree().process_frame
	live.queue_free()
	await get_tree().process_frame
	GameState.story_flags.erase("noor_lid")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.add_member("kael")
	check("hal-test: vier helden", GameState.party.size() == 4)
	Settings.set_value("hd2d_light", true)
	GameState.time_of_day = "night"
	var hall: Node = (load(HALL) as PackedScene).instantiate()
	add_child(hall)
	await get_tree().process_frame
	var rig := hall.get_node_or_null("MapLightingRig")
	check("hal heeft een licht-rig", rig != null)
	if rig != null:
		rig.set_phase("night", 0.0)
		var torch_lights := 0
		for c in rig._cands:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			if str((c as Dictionary).get("kind", "")) != "fire":
				continue
			torch_lights += 1
		check("hal: tien vuren worden vier lichten", torch_lights == 4)
		check("hal: hoogstens 8 puntlichten", rig.enabled_point_lights() <= 8)
	var lobby_lit: Node = (load(LOBBY) as PackedScene).instantiate()
	add_child(lobby_lit)
	await get_tree().process_frame
	var lrig := lobby_lit.get_node_or_null("MapLightingRig")
	check("lobby heeft een licht-rig", lrig != null)
	if lrig != null:
		lrig.set_phase("night", 0.0)
		var lobby_fire := 0
		var shaft := false
		for c in lrig._cands:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var kind := str((c as Dictionary).get("kind", ""))
			if kind == "fire":
				lobby_fire += 1
			elif kind == "tile":
				shaft = true
		check("lobby: twee fakkels blijven los", lobby_fire == 2)
		check("lobby: lichtschacht", shaft)
		check("lobby: hoogstens 8 puntlichten", lrig.enabled_point_lights() <= 8)
	lobby_lit.queue_free()
	await get_tree().process_frame
	hall.queue_free()
	await get_tree().process_frame
	Settings.set_value("hd2d_light", hd2d_was)
	GameState.time_of_day = tod_was
	ReleaseFlags.arena_enabled_override = -1


func _sprites_named(root: Node, file_name: String) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for n in root.find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if s.texture != null and str(s.texture.resource_path).ends_with("/" + file_name):
			out.append(s)
	return out


func _tex_size(path: String) -> Vector2i:
	var tex := load(path) as Texture2D
	if tex == null:
		return Vector2i.ZERO
	return Vector2i(tex.get_width(), tex.get_height())


func _opening_solid(body: Node2D) -> bool:
	for c in body.get_children():
		if not (c is CollisionShape2D):
			continue
		var shape := (c as CollisionShape2D).shape as RectangleShape2D
		if shape != null and shape.size == Vector2(48, 8):
			return true
	return false


func _sprite_named(root: Node, file_name: String) -> Sprite2D:
	var all := _sprites_named(root, file_name)
	if all.is_empty():
		return null
	return all[0]


class MemberDown:
	signal member_down(hero_id: String)
