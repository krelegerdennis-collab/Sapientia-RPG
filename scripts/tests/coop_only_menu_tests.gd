extends Node
## Runner-suite: co-op-only titelmenu (export feature tag coop_only).
## Start: godot --path . -- --cooponlymenutest

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const OnlineHalScript := preload("res://scripts/coop/online_hal.gd")
const ONLINE_HALL := "res://scenes/coop/online_hal.tscn"
const STORY_SAVE := "user://save_1.json"

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


func _titel() -> Node:
	var nu := get_tree().current_scene
	return nu if nu != null and nu.get("mp_slots") != null else null


func _story_hidden(t: Node) -> bool:
	return not t.card.visible and not t.save_info.visible and not t.continue_button.visible \
			and not t.load_button.visible and not t.new_button.visible and not t.pvp_button.visible \
			and not t.som_button.visible and not t.beta_button.visible and not t.eind_button.visible \
			and not t.coop_button.visible


func _wait_titel() -> Node:
	GameState.go_to_title(true)
	for _i in 180:
		var t := _titel()
		if t != null and not GameState.changing_map:
			await get_tree().process_frame
			return t
		await get_tree().process_frame
	return _titel()


func _wipe_profile() -> void:
	if FileAccess.file_exists(Profile.PATH):
		DirAccess.remove_absolute(Profile.PATH)
	for suf in [".tmp", ".bak"]:
		var pad: String = Profile.PATH + suf
		if FileAccess.file_exists(pad):
			DirAccess.remove_absolute(pad)


func _export_preset_tests() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	check("export_presets.cfg laadt", err == OK)
	var found := false
	for sec in cfg.get_sections():
		if not str(sec).begins_with("preset."):
			continue
		if str(sec).contains(".options"):
			continue
		if str(cfg.get_value(sec, "name", "")) == "Web Co-op":
			found = true
			check("Web Co-op: platform Web", str(cfg.get_value(sec, "platform", "")) == "Web")
			check("Web Co-op: custom_features coop_only", str(cfg.get_value(sec, "custom_features", "")) == "coop_only")
			check("Web Co-op: thread_support uit", not bool(cfg.get_value(sec + ".options", "variant/thread_support", true)))
	check("export preset 'Web Co-op' bestaat", found)


func _profile_slot_tests() -> void:
	_wipe_profile()
	var profiel: OnlineProfile = Profile.new()
	profiel.load_profile()
	check("profiel leeg: 3 slots mogelijk", not profiel.has_slot(0) and not profiel.has_slot(1) and not profiel.has_slot(2))
	check("slot 0", bool(profiel.create_slot(0, "Aaa", "warrior").get("ok", false)))
	check("slot 1", bool(profiel.create_slot(1, "Bbb", "mage").get("ok", false)))
	check("slot 2", bool(profiel.create_slot(2, "Ccc", "priest").get("ok", false)))
	check("vierde slot geweigerd", not bool(profiel.create_slot(3, "Ddd", "archer").get("ok", true)))
	var herladen: OnlineProfile = Profile.new()
	herladen.load_profile()
	check("persistentie slot 0", herladen.has_slot(0) and str(herladen.get_slot(0).get("name", "")) == "Aaa")
	check("persistentie slot 2", herladen.has_slot(2) and str(herladen.get_slot(2).get("class", "")) == "priest")
	var packet := CoopLobbyScreen.online_packet(herladen.get_slot(0))
	check("selectie naar lobby-pakket", packet.get("name", "") == "Aaa" and packet.get("class", "") == "warrior")


func _run() -> void:
	await _suite()


func _suite() -> void:
	var oude_override := ReleaseFlags.coop_only_override
	var had_story := FileAccess.file_exists(STORY_SAVE)
	var story_bytes := PackedByteArray()
	if had_story:
		story_bytes = FileAccess.get_file_as_bytes(STORY_SAVE)
	else:
		var sentinel := '{"player_name":"StorySentinel","play_time":1.0}'
		var f := FileAccess.open(STORY_SAVE, FileAccess.WRITE)
		if f != null:
			f.store_string(sentinel)
			f.close()
		story_bytes = FileAccess.get_file_as_bytes(STORY_SAVE)
	_export_preset_tests()
	_profile_slot_tests()
	check("multiplayer data: OnlineProfile pad", Profile.PATH == "user://online_profile.json")
	check("standaard: geen co-op-only zonder feature", not ReleaseFlags.coop_only_mode())
	var t: Node = await _wait_titel()
	check("titelscherm geladen", t != null)
	if t == null:
		_release(oude_override, had_story, story_bytes)
		return
	ReleaseFlags.coop_only_override = 0
	t.apply_online_visibility()
	t.apply_test_menu_visibility()
	t.refresh()
	await get_tree().process_frame
	check("zonder co-op-only: mp_slots verborgen", not t.mp_slots.visible)
	check("zonder co-op-only: verhaalmenu zichtbaar", t.card.visible and t.new_button.visible)
	ReleaseFlags.coop_only_override = 1
	t.apply_coop_only_menu()
	t.refresh()
	await get_tree().process_frame
	check("co-op-only: verhaalmenu verborgen", _story_hidden(t))
	check("co-op-only: mp_slots zichtbaar", t.mp_slots.visible)
	check("co-op-only: versielabel blijft", t.version_label.visible and t.version_label.text.begins_with("v"))
	t._mp_profile.load_profile()
	t.mp_slots.refresh()
	check("co-op-only: titel toont slot 0", t._mp_profile.has_slot(0))
	var focus_owner := get_viewport().gui_get_focus_owner()
	check("co-op-only: focus op een slot-knop", focus_owner is Button)
	var row0: Dictionary = t._mp_profile.get_slot(0)
	check("co-op-only: selectie-pakket voor lobby", CoopLobbyScreen.online_packet(row0).get("name", "") == "Aaa")
	OnlineHalScript.entry_profile = CoopLobbyScreen.online_packet(row0)
	OnlineHalScript.entry_slot_index = 0
	get_tree().change_scene_to_file(ONLINE_HALL)
	var hal: OnlineHal = null
	for _i in 240:
		var sc := get_tree().current_scene
		if sc != null and String(sc.scene_file_path) == ONLINE_HALL:
			hal = sc as OnlineHal
			break
		await get_tree().process_frame
	check("co-op-only: online hal geladen", hal != null)
	check("co-op-only: profiel op hal", hal != null and not hal.profile.is_empty())
	check("co-op-only: hal profielnaam uit slot 0", hal != null and str(hal.profile.get("name", "")) == "Aaa")
	var lobby: CoopLobbyScreen = CoopLobbyScreen.new()
	lobby.hall_mode = true
	add_child(lobby)
	await get_tree().process_frame
	var lobby_title := ""
	for c in lobby._box.get_children():
		if c is Label:
			lobby_title = (c as Label).text
			break
	check("co-op-only: lobbytitel Multiplayer", lobby_title == ReleaseFlags.COOP_ONLY_PLAYER_LABEL)
	lobby.queue_free()
	ReleaseFlags.coop_only_override = 0
	check("normale build: lobbytitel nog Co-op", ReleaseFlags.coop_lobby_menu_title(true) == "Co-op (LAN / Online)")
	check("verhaal-save onaangetast", FileAccess.get_file_as_bytes(STORY_SAVE) == story_bytes)
	_release(oude_override, had_story, story_bytes)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _release(oude_override: int, had_story: bool, story_bytes: PackedByteArray) -> void:
	ReleaseFlags.coop_only_override = oude_override
	_wipe_profile()
	if had_story:
		var f := FileAccess.open(STORY_SAVE, FileAccess.WRITE)
		if f != null:
			f.store_buffer(story_bytes)
			f.close()
	elif FileAccess.file_exists(STORY_SAVE):
		DirAccess.remove_absolute(STORY_SAVE)