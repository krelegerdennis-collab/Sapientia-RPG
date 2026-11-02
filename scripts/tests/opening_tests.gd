extends Node
## Headless tests voor de WM1-opening (Drift + story-Hal + migratie).
## Start: godot --path . -- --openingtest

const Art := preload("res://world_warper/opening/art.gd")
const Flow := preload("res://world_warper/opening/flow.gd")
const StoryMode := preload("res://world_warper/opening/story_mode.gd")
const Drift := preload("res://world_warper/opening/drift.gd")
const EchoMission := preload("res://world_warper/opening/echo_mission.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const StoryData := preload("res://scripts/data/story_data.gd")

const HUIS := "res://scenes/maps/huis_wilgendal.tscn"
const HAL := Canon.HAL_SCENE
const HANGER := "res://world_warper/maps/hanger_nis.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_statisch()
	await _nieuw_spel_opening()
	await _geblokkeerde_uitgangen()
	_unlock_regels()
	_migratie()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _statisch() -> void:
	check("opening art bestanden", ResourceLoader.exists(Art.BG_FAR) and ResourceLoader.exists(Art.WORMHOLE)
			and ResourceLoader.exists(Art.WARPER) and ResourceLoader.exists(Art.ECHO_GLITCH))
	check("drift: 3-4 regels", Drift.REGELS.size() >= 3 and Drift.REGELS.size() <= 4)
	check("echo: max ~10 regels", EchoMission.REGELS.size() <= 10)
	check("echo: geen H-6", not EchoMission.REGELS.any(func(s): return "H-6" in s or "test subject" in s.to_lower()))
	check("story mode melding", StoryMode.MSG == "Not yet.")
	check("canon memory restore bij drift_done", Canon.MEMORY_RESTORE.size() >= 2)
	var flags := {Unlock.BEWAKER_VLAG: true}
	check("bewaker alleen unlockt", Unlock.should_unlock(flags))


func _nieuw_spel_opening() -> void:
	GameState.start_new_game("Dax")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		if GameState.story_flags.has(Flow.FLAG_DRIFT_DONE) and str(GameState.current_map) == HUIS:
			break
		if Dialog.is_open:
			if Dialog.has_method("_is_typing") and Dialog._is_typing():
				Dialog.advance()
			else:
				Dialog.advance()
		await get_tree().process_frame
	check("nieuw spel: opening eindigt in het Wachtershuis", GameState.story_flags.has(Flow.FLAG_DRIFT_DONE)
			and str(GameState.current_map) == HUIS and not GameState.story_flags.has(Flow.FLAG_OPENING_HAL))
	check("proloog stap START", GameState.story_step == StoryData.START)


func _geblokkeerde_uitgangen() -> void:
	GameState.story_flags[Flow.FLAG_OPENING_HAL] = true
	GameState.change_map(HAL, Canon.HAL_SPAWN)
	await _wacht_map(HAL)
	var hal := get_tree().current_scene
	check("hal geladen in story mode", hal != null and StoryMode.actief())
	var player := hal.get_node_or_null("Objects/Player")
	if player != null:
		player.position = hal.get_node("Exits/NaarWarp").position + Vector2(8, 8)
		await get_tree().process_frame
		hal.call("_on_player_stepped", Vector2i((player.position / 16.0).floor()))
		await get_tree().process_frame
		check("warp-ring geblokkeerd", Dialog.is_open or StoryMode.blocks_map_exit(HAL, "NaarWarp"))
	if Dialog.is_open:
		Dialog.advance()
		await get_tree().process_frame
	GameState.story_flags.erase(Flow.FLAG_OPENING_HAL)


func _unlock_regels() -> void:
	GameState.new_game("Dax")
	check("vers warper dicht", not GameState.world_warper_is_unlocked())
	GameState.story_flags[Unlock.BEWAKER_VLAG] = true
	check("genezer: warper open", GameState.try_unlock_world_warper() and GameState.world_warper_is_unlocked())


func _migratie() -> void:
	var flags := {}
	Flow.migrate(flags, StoryData.START)
	check("migrate leeg: geen drift_done", not flags.has(Flow.FLAG_DRIFT_DONE))
	flags = {Unlock.UNLOCK_VLAG: true}
	Flow.migrate(flags, StoryData.START)
	check("migrate unlocked warper", flags.has(Flow.FLAG_DRIFT_DONE))
	flags = {}
	Flow.migrate(flags, StoryData.TAKEN)
	check("migrate proloog voortgang", flags.has(Flow.FLAG_DRIFT_DONE))


func _wacht_map(pad: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		if str(GameState.current_map) == pad and not GameState.changing_map:
			await get_tree().process_frame
			return
		await get_tree().process_frame
