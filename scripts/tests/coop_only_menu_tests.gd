extends Node
## Runner-suite: co-op-only titelmenu (export feature tag coop_only).
## Start: godot --path . -- --cooponlymenutest

const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const CoopLobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const OnlineHalScript := preload("res://scripts/coop/online_hal.gd")
const MpCharacterCreate := preload("res://scripts/ui/mp_character_create.gd")
const SavePrompt := preload("res://scripts/ui/save_prompt.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const LanLobby := preload("res://scripts/net/lan_lobby.gd")
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
	return nu if nu != null and nu.has_method("apply_coop_only_menu") else null


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


func _empty_name_create_test() -> void:
	_wipe_profile()
	var profiel: OnlineProfile = Profile.new()
	profiel.load_profile()
	var ui: MpCharacterCreate = MpCharacterCreate.new()
	ui.setup(profiel, 0)
	add_child(ui)
	await get_tree().process_frame
	ui._edit.text = "   "
	ui._on_create()
	await get_tree().process_frame
	check("lege naam: geen slot geschreven", not profiel.has_slot(0))
	check("lege naam: foutmelding", ui._error.text != "")
	ui.queue_free()


func _delete_confirm_test(t: Node) -> void:
	_wipe_profile()
	var profiel: OnlineProfile = Profile.new()
	profiel.load_profile()
	check("delete-test: slot aanmaken", bool(profiel.create_slot(0, "Zed", "warrior").get("ok", false)))
	t._mp_profile.load_profile()
	t.mp_slots.refresh()
	t._on_mp_delete(0)
	await get_tree().process_frame
	var prompt: SavePrompt = t._mp_delete_prompt
	check("delete: confirm dialoog", prompt != null)
	check("delete: default No", prompt.default_no)
	prompt.answer(false)
	await get_tree().process_frame
	check("delete: No behoudt slot", t._mp_profile.has_slot(0))
	t._on_mp_delete(0)
	await get_tree().process_frame
	prompt = t._mp_delete_prompt
	check("delete: tweede confirm", prompt != null)
	prompt.answer(true)
	await get_tree().process_frame
	t.mp_slots.refresh()
	check("delete: Yes wist slot", not t._mp_profile.has_slot(0))
	check("delete: laatste poppetje weg, geen crash", not t._mp_profile.has_slot(0) and not t._mp_profile.has_slot(1))
	check("delete: slot leeg in UI", t.mp_slots._slot_buttons[0].text == "New character")


func _focus_neighbor_test(t: Node) -> void:
	t.mp_slots.refresh()
	var first: Button = t.mp_slots._slot_buttons[0]
	check("focus: start op eerste slot", get_viewport().gui_get_focus_owner() == first)
	var top_path: NodePath = first.focus_neighbor_top
	check("focus: bovenbuur bestaat", top_path != NodePath())
	var bottom_path: NodePath = first.focus_neighbor_bottom
	check("focus: onderbuur bestaat", bottom_path != NodePath())
	check("focus: Del rechts van slot 0", first.focus_neighbor_right == t.mp_slots._delete_buttons[0].get_path())


func _wait_hal() -> OnlineHal:
	get_tree().change_scene_to_file(ONLINE_HALL)
	for _i in 240:
		var sc := get_tree().current_scene
		if sc != null and String(sc.scene_file_path) == ONLINE_HALL:
			return sc as OnlineHal
		await get_tree().process_frame
	return null


func _relay_unreachable_test(t: Node) -> void:
	if t == null:
		check("relay-test: titel", false)
		return
	_wipe_profile()
	var profiel: OnlineProfile = Profile.new()
	profiel.load_profile()
	check("relay-test: profiel", bool(profiel.create_slot(0, "Rex", "mage").get("ok", false)))
	ProjectSettings.set_setting(Protocol.RELAY_URL_SETTING, "wss://127.0.0.1:9")
	var row: Dictionary = profiel.get_slot(0)
	OnlineHalScript.entry_profile = CoopLobbyScreen.online_packet(row)
	var hal := await _wait_hal()
	check("relay-test: hal geladen", hal != null)
	if hal == null:
		return
	for _i in 60:
		if hal._code != null:
			break
		await get_tree().process_frame
	var code: CoopLobbyScreen = hal._code
	check("relay-test: code-scherm", code != null)
	code._show_host_online()
	var bruikbaar := false
	for _i in 90:
		if code._screen == CoopLobbyScreen.Screen.MESSAGE \
				or code.lobby.phase == LanLobby.Phase.IDLE \
				or code.all_touch_buttons().size() > 0:
			bruikbaar = true
			break
		await get_tree().process_frame
	check("relay-test: geen crash (hal leeft)", is_instance_valid(hal) and hal.is_inside_tree())
	check("relay-test: host-poging geen softlock", bruikbaar)
	if code.is_inside_tree() and code._screen == CoopLobbyScreen.Screen.MESSAGE:
		for b in code.all_touch_buttons():
			if b.text == "Back":
				b.pressed.emit()
				break
		await get_tree().process_frame
	GameState.go_to_title(true)
	for _i in 120:
		if _titel() != null:
			break
		await get_tree().process_frame
	var terug: Node = _titel()
	check("relay-test: terug naar titel UI", terug != null and ReleaseFlags.coop_only_mode())
	ProjectSettings.set_setting(Protocol.RELAY_URL_SETTING, "")
	t = terug


func _hall_back_to_title_test() -> void:
	_wipe_profile()
	var profiel: OnlineProfile = Profile.new()
	profiel.load_profile()
	check("back-test: profiel", bool(profiel.create_slot(0, "Bee", "priest").get("ok", false)))
	ReleaseFlags.coop_only_override = 1
	OnlineHalScript.entry_profile = CoopLobbyScreen.online_packet(profiel.get_slot(0))
	var hal := await _wait_hal()
	check("back-test: hal", hal != null)
	if hal == null:
		return
	for _i in 60:
		if hal._code != null:
			break
		await get_tree().process_frame
	if hal._code != null and is_instance_valid(hal._code) and hal._code.is_inside_tree():
		hal._code.cancel()
	else:
		GameState.go_to_title(true)
	for _i in 120:
		if _titel() != null:
			break
		await get_tree().process_frame
	check("hall Back: coop-only titel", _titel() != null)


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
	await _empty_name_create_test()
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
	check("zonder co-op-only: geen mp_slots", t.mp_slots == null)
	check("zonder co-op-only: verhaalmenu zichtbaar", t.card.visible and t.new_button.visible)
	ReleaseFlags.coop_only_override = 1
	t.apply_coop_only_menu()
	t.refresh()
	await get_tree().process_frame
	check("co-op-only: verhaalmenu verborgen", _story_hidden(t))
	check("co-op-only: mp_slots zichtbaar", t.mp_slots != null and t.mp_slots.visible)
	check("co-op-only: versielabel blijft", t.version_label.visible and t.version_label.text.begins_with("v"))
	t._mp_profile.load_profile()
	t.mp_slots.refresh()
	check("co-op-only: titel toont slot 0", t._mp_profile.has_slot(0))
	_focus_neighbor_test(t)
	var row0: Dictionary = t._mp_profile.get_slot(0)
	check("co-op-only: selectie-pakket voor lobby", CoopLobbyScreen.online_packet(row0).get("name", "") == "Aaa")
	OnlineHalScript.entry_profile = CoopLobbyScreen.online_packet(row0)
	OnlineHalScript.entry_slot_index = 0
	var hal: OnlineHal = await _wait_hal()
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
	GameState.go_to_title(true)
	t = await _wait_titel()
	ReleaseFlags.coop_only_override = 1
	if t != null:
		t.apply_coop_only_menu()
	await _delete_confirm_test(t)
	await _relay_unreachable_test(t)
	await _hall_back_to_title_test()
	ReleaseFlags.coop_only_override = 0
	check("normale build: lobbytitel nog Co-op", ReleaseFlags.coop_lobby_menu_title(true) == "Co-op (LAN / Online)")
	check("verhaal-save onaangetast", FileAccess.get_file_as_bytes(STORY_SAVE) == story_bytes)
	_release(oude_override, had_story, story_bytes)
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _release(oude_override: int, had_story: bool, story_bytes: PackedByteArray) -> void:
	ReleaseFlags.coop_only_override = oude_override
	ProjectSettings.set_setting(Protocol.RELAY_URL_SETTING, "")
	_wipe_profile()
	if had_story:
		var f := FileAccess.open(STORY_SAVE, FileAccess.WRITE)
		if f != null:
			f.store_buffer(story_bytes)
			f.close()
	elif FileAccess.file_exists(STORY_SAVE):
		DirAccess.remove_absolute(STORY_SAVE)