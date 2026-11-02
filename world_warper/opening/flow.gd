class_name WorldWarperOpeningFlow
extends RefCounted
## Nieuw spel (WM1): drift-cutscene, story-only Hal, daarna proloog in het Wachtershuis.
## Canon-scènes 1–3 spelen nog steeds na De Genezer (CANON.md punt 17).

const Drift := preload("res://world_warper/opening/drift.gd")
const StoryMode := preload("res://world_warper/opening/story_mode.gd")
const EchoMission := preload("res://world_warper/opening/echo_mission.gd")
const Canon := preload("res://world_warper/cutscene/canon_scenes.gd")
const Unlock := preload("res://world_warper/flow/unlock.gd")
const StoryData := preload("res://scripts/data/story_data.gd")

const FLAG_DRIFT_DONE := "warper_drift_done"
const FLAG_OPENING_HAL := "warper_opening_hal"

## Suites die de volledige opening meespelen (anders overslaan in tests).
const TESTS_MET_OPENING: Array[String] = ["--openingtest", "--wm1playthroughtest"]


static func should_play(flags: Dictionary) -> bool:
	if flags.has(FLAG_DRIFT_DONE):
		return false
	if not _mag_in_tests():
		return false
	return true


static func _mag_in_tests() -> bool:
	for a in OS.get_cmdline_user_args():
		if a in TESTS_MET_OPENING:
			return true
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--") and str(a).ends_with("test"):
			return false
	return true


## Oude saves: geen opening opnieuw; behoud warper-toegang.
static func migrate(flags: Dictionary, story_step: int) -> void:
	if flags.has(FLAG_DRIFT_DONE):
		return
	if flags.has(Unlock.UNLOCK_VLAG):
		flags[FLAG_DRIFT_DONE] = true
		return
	if flags.has(Unlock.BEWAKER_VLAG) or flags.has(Canon.FLAG_GENEZER):
		flags[FLAG_DRIFT_DONE] = true
		return
	if story_step != StoryData.START:
		flags[FLAG_DRIFT_DONE] = true
		return
	if flags.has("schilderij_weg") or flags.has(StoryData.TUTORIAL_CODEX_FLAG):
		flags[FLAG_DRIFT_DONE] = true


static func start() -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if boom == null:
		GameState.change_map(GameState.START_MAP, GameState.START_SPAWN)
		return
	var runner := _Runner.new()
	boom.root.add_child(runner)


class _Runner extends Node:
	func _ready() -> void:
		call_deferred("_run")


	func _run() -> void:
		await Drift.play(self)
		if not is_inside_tree():
			return
		GameState.story_flags[WorldWarperOpeningFlow.FLAG_OPENING_HAL] = true
		GameState.change_map(Canon.HAL_SCENE, Canon.HAL_SPAWN)
		await _wacht_hal()
		if not is_inside_tree():
			return
		for _i in 8:
			await get_tree().process_frame
		await EchoMission.speel(self)
		if not is_inside_tree():
			return
		await _warp_naar_wachter()
		queue_free()


	func _wacht_hal() -> void:
		while is_inside_tree() and not GameState.changing_map:
			if str(GameState.current_map).ends_with("world_warper/maps/hal.tscn"):
				return
			await get_tree().process_frame


	func _warp_naar_wachter() -> void:
		var flash := ColorRect.new()
		flash.color = Color(0.55, 0.35, 0.95, 0.0)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layer := CanvasLayer.new()
		layer.layer = 130
		layer.add_child(flash)
		get_tree().root.add_child(layer)
		var t := create_tween()
		t.tween_property(flash, "color:a", 1.0, 0.35)
		await t.finished
		GameState.story_flags.erase(WorldWarperOpeningFlow.FLAG_OPENING_HAL)
		GameState.story_flags[WorldWarperOpeningFlow.FLAG_DRIFT_DONE] = true
		GameState.change_map(GameState.START_MAP, GameState.START_SPAWN)
		await get_tree().process_frame
		t = create_tween()
		t.tween_property(flash, "color:a", 0.0, 0.45)
		await t.finished
		layer.queue_free()
