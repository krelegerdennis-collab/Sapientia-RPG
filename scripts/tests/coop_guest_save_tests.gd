extends Node
## Co-op gast: geen EXP/items-duplicaat bij terugkeer naar eigen save; suspend/hervatten midden in gevecht.
## Start: godot --path . -- --coopguestsavetest

const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const TITLE := "res://scenes/ui/title.tscn"

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


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _remove(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _progress_sig() -> String:
	var d := GameState.state_data(Vector2i.ZERO, Vector2i.DOWN)
	d.erase("play_time")
	return JSON.stringify(d)


func _run() -> void:
	print("=== A: gast co-op -> eigen save: geen duplicaat ===")
	await _dupe_tests()
	print("=== B: sessie-einde midden in gevecht (suspend/hervatten-pad) ===")
	await _suspend_battle_tests()
	print("COOPGUESTSAVE %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(5)
	get_tree().quit(1 if failures else 0)


func _dupe_tests() -> void:
	if not SomData.ENABLED:
		check("SomData aan", false)
		return
	var solo := GameState.save_path
	_remove(solo)
	_remove(GameState.COOP_GUEST_SAVE_PATH)
	_remove(GameState.COOP_GUEST_AUTOSAVE_PATH)
	GameState.new_game("Dax")
	GameState.gold = 120
	GameState.inventory = {"drankje": 2}
	var hero: Dictionary = GameState.party[0]
	var need := GameData.exp_for_level(4) - int(hero["exp"])
	if need > 0:
		GameState.give_exp(hero, need)
	check("solo save schrijven", GameState.save_game(Vector2i(3, 4), Vector2i.UP, solo))
	var disk_before := GameState.read_save(solo)
	var mem_before := _progress_sig()
	GameState._coop_snapshot_guest_solo()
	GameState.coop_role = "guest"
	GameState._build_som_state()
	GameState.gold += 9000
	GameState.inventory["drankje"] = GameState.item_count("drankje") + 50
	GameState.give_exp(GameState.party[0], 500)
	check("gast mag niet naar som_save schrijven", not GameState.save_game(Vector2i.ZERO, Vector2i.ZERO, SomData.SAVE_PATH))
	GameState.coop_end_session("")
	check("na sessie: geen co-op rol", not GameState.coop_in_session())
	check("na sessie: geheugen = snapshot vóór co-op", _progress_sig() == mem_before)
	GameState.use_story_saves()
	check("load solo van schijf", GameState.load_game(solo))
	check("schijf ongewijzigd (goud)", int(GameState.gold) == int(disk_before.get("gold", -1)))
	check("schijf ongewijzigd (drankje)", int(GameState.inventory.get("drankje", 0)) == int((disk_before.get("inventory", {}) as Dictionary).get("drankje", 0)))
	check("geen gast-sessiebestand", not FileAccess.file_exists(GameState.COOP_GUEST_SAVE_PATH))
	_remove(solo)


func _suspend_battle_tests() -> void:
	GameState.new_game("Dax")
	var solo_gold := GameState.gold
	GameState._coop_snapshot_guest_solo()
	GameState.coop_role = "guest"
	GameState._build_som_state()
	GameState.in_battle = true
	GameState.changing_map = false
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await pframes(2)
	GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await pframes(2)
	check("pauze/hervatten: gast nog in sessie", GameState.coop_is_guest())
	check("pauze/hervatten: geen autosave naar solo", not FileAccess.file_exists(GameState.save_path))
	GameState._on_coop_session_ended("ended")
	await pframes(30)
	check("sessie-einde in gevecht: co-op uit", not GameState.coop_in_session())
	check("sessie-einde in gevecht: niet meer in_battle", not GameState.in_battle)
	check("sessie-einde in gevecht: titelscherm", str(get_tree().current_scene.scene_file_path) == TITLE)
	check("sessie-einde: solo goud terug", GameState.gold == solo_gold)
