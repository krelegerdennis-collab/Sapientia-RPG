extends Node
## Online warper-hal (M5). Start: godot --path . -- --onlinelobbytest [--shots=/pad]
## Start zelf de Node-relay voor de 4-stoel-ronde.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const Blob := preload("res://scripts/net/avatar_blob.gd")
const Baker := preload("res://scripts/online/paper_doll_baker.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const Icons := preload("res://scripts/coop/online_icon_paths.gd")
const AiSeats := preload("res://scripts/coop/online_ai_seats.gd")
const HalScript := preload("res://scripts/coop/online_hal.gd")
const LobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")

const STEP := 8.0
const VIEWPORT := Vector2i(384, 216)
const RELAY_DIR := "res://relay"
const HAL_SCENE := "res://scenes/coop/online_hal.tscn"
const SOLO_HAL := "res://world_warper/maps/hal.tscn"
const CLASSES: PackedStringArray = ["priest", "warrior", "mage", "archer"]
const ROLES: PackedStringArray = ["Heal", "Tank", "Control", "Dps"]

var failures := 0
var passes := 0
var shots := ""
var _relay_pid := 0
var _port := 0
var _url := ""
var _profiles: Array[Dictionary] = []
var _nodes: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			shots = str(arg).get_slice("=", 1)
	_profiles = _make_profiles()
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func wait_until(pred: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if pred.call():
			return true
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		left -= float(Time.get_ticks_msec() - before) / 1000.0
	return pred.call()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _run() -> void:
	OS.unset_environment(Protocol.RELAY_URL_ENV)
	AiSeats.clear()
	_scene_and_flags()
	_icon_table()
	_role_rows()
	if await _start_relay():
		await _four_seats()
	else:
		check("relay beschikbaar voor de hal", false)
	_stop_relay()
	await _frames(4)
	AiSeats.clear()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _make_profiles() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"uid": "a1b2c3d4", "name": "Mira", "class": "priest", "skin": 0, "hair": 1, "hair_color": 1, "top": 0, "top_color": 1, "bottom": 0, "bottom_color": 2, "head": 0},
		{"uid": "b2c3d4e5", "name": "Dex", "class": "warrior", "skin": 1, "hair": 2, "hair_color": 3, "top": 1, "top_color": 2, "bottom": 1, "bottom_color": 3, "head": 1},
		{"uid": "c3d4e5f6", "name": "Nim", "class": "mage", "skin": 2, "hair": 3, "hair_color": 5, "top": 2, "top_color": 4, "bottom": 2, "bottom_color": 5, "head": 2},
		{"uid": "d4e5f6a7", "name": "Ash", "class": "archer", "skin": 3, "hair": 5, "hair_color": 7, "top": 3, "top_color": 0, "bottom": 0, "bottom_color": 1, "head": 0},
	]
	var out: Array[Dictionary] = []
	for row in rows:
		var look := {
			"body": 0,
			"skin": int(row["skin"]),
			"hair": int(row["hair"]),
			"hair_color": int(row["hair_color"]),
			"top": int(row["top"]),
			"top_color": int(row["top_color"]),
			"bottom": int(row["bottom"]),
			"bottom_color": int(row["bottom_color"]),
			"head": int(row["head"]),
			"class": str(row["class"]),
		}
		out.append({
			"uid": str(row["uid"]),
			"name": str(row["name"]),
			"class": str(row["class"]),
			"look": look,
		})
	return out


func _scene_and_flags() -> void:
	var scene_txt := FileAccess.get_file_as_string(HAL_SCENE)
	var solo_txt := FileAccess.get_file_as_string(SOLO_HAL)
	var script_txt := FileAccess.get_file_as_string("res://scripts/coop/online_hal.gd")
	check("online_hal.tscn bestaat", scene_txt != "")
	check("tegeldata gelijk aan de solo-hal", _tile_blob(scene_txt) != "" and _tile_blob(scene_txt) == _tile_blob(solo_txt))
	check("bord-art van de hal wordt hergebruikt", scene_txt.find("bord_warp.png") >= 0 and scene_txt.find("bord_hal.png") >= 0)
	var banned := ["HubBoot", "hub_boot.gd", "rekruut.gd", "map.gd", "map_exit.gd", "locked_exit.gd", "naar_kamers", "NaarWarp", "NaarHanger", "NaarBuiten", "NaarCodex", "NaarSchot"]
	var clean := true
	for word in banned:
		if scene_txt.find(word) >= 0:
			clean = false
	check("scène heeft geen boot, gids, rekruut of uitgang", clean)
	check("hal-script heeft geen verhaal-aanroep en geen tekstvak", script_txt.find("Story") < 0 and script_txt.find("story_flags") < 0 and script_txt.find("LineEdit") < 0)
	var flags_before: Dictionary = GameState.story_flags.duplicate()
	var step_before := int(GameState.story_step)
	var save_before := _save_bytes()
	var packed := load(HAL_SCENE) as PackedScene
	check("scène laadt", packed != null)
	if packed == null:
		return
	var hal: OnlineHal = packed.instantiate()
	hal.auto_lobby = false
	hal.camera_on = false
	hal.name = "FlagHal"
	add_child(hal)
	await _frames(3)
	var tree_ok := _tree_clean(hal)
	check("boom heeft geen verboden nodes", tree_ok)
	check("BordWarp staat, uitgangen niet", hal.get_node_or_null("Objects/BordWarp") != null and hal.get_node_or_null("Exits") == null)
	check("touch-joystick staat aan", hal.get_node_or_null("TouchControls/Control") != null)
	var touch: Node = hal.get_node_or_null("TouchControls/Control")
	check("joystick is analoog, zonder menuknop", touch != null and bool(touch.get("analog_only")) and not bool(touch.get("show_menu")))
	hal.show_rows(_four_class_rows())
	await _frames(2)
	check("vier stoelen, nul vijand-nodes", hal.enemy_nodes() == 0 and hal.body_at(0) != null and hal.body_at(3) != null)
	check("verhaalvlaggen onaangeroerd", GameState.story_flags == flags_before and int(GameState.story_step) == step_before)
	check("verhaal-save onaangeroerd", _save_bytes() == save_before)
	hal.queue_free()
	await _frames(2)


func _icon_table() -> void:
	var roles: PackedStringArray = ["Tank", "Heal", "Control", "Dps"]
	var slugs: PackedStringArray = ["rol_tank", "rol_heal", "rol_control", "rol_dps"]
	var paths_ok := true
	for i in roles.size():
		var paths := Icons.role_final_paths(roles[i])
		paths_ok = paths_ok and paths.size() == 2
		paths_ok = paths_ok and paths[0] == "res://assets/ui/icons/rollen/icons16/%s.png" % slugs[i]
		paths_ok = paths_ok and paths[1] == "res://assets/ui/icons/rollen/icons32/%s.png" % slugs[i]
		paths_ok = paths_ok and not ResourceLoader.exists(paths[0]) and not ResourceLoader.exists(paths[1])
		paths_ok = paths_ok and Icons.using_placeholder(paths)
		var tex := Icons.role_texture(roles[i])
		paths_ok = paths_ok and tex == Icons.role_placeholder(roles[i])
		paths_ok = paths_ok and tex != null and tex.get_width() == 16 and tex.get_height() == 16
	check("rol-paden wijzen naar icons16|icons32 en vallen terug op placeholder", paths_ok)
	var emote_slugs: PackedStringArray = ["0_help", "1_hier_heen", "2_goed_gedaan", "3_bedankt"]
	var emote_ok := true
	for i in emote_slugs.size():
		var paths := Icons.emote_final_paths(i)
		emote_ok = emote_ok and paths.size() == 2
		emote_ok = emote_ok and paths[0] == "res://assets/ui/icons/emotes/icons16/emote_%s.png" % emote_slugs[i]
		emote_ok = emote_ok and paths[1] == "res://assets/ui/icons/emotes/icons32/emote_%s.png" % emote_slugs[i]
		emote_ok = emote_ok and Icons.using_placeholder(paths)
		var tex := Icons.emote_texture(i)
		emote_ok = emote_ok and tex == Icons.emote_placeholder(i) and tex.get_width() == 16
	check("emote-paden 0..3 vallen terug op placeholder", emote_ok and Icons.emote_texture(4) == null)
	check("onbekende rol heeft geen pad", Icons.role_final_paths("Bard").is_empty() and Icons.role_texture("Bard") == null)


func _role_rows() -> void:
	var packed := load(HAL_SCENE) as PackedScene
	var hal: OnlineHal = packed.instantiate()
	hal.auto_lobby = false
	hal.camera_on = false
	hal.name = "RoleHal"
	add_child(hal)
	await _frames(2)
	hal.show_rows(_four_class_rows())
	await _frames(2)
	var icons_ok := true
	var bake_ok := true
	for i in 4:
		var body := hal.body_at(i)
		var role := ROLES[i]
		if body == null or str(body.get_meta("role", "")) != role:
			icons_ok = false
			bake_ok = false
			continue
		var icon := body.get_node_or_null("RoleIcon") as Sprite2D
		icons_ok = icons_ok and icon != null and icon.visible and icon.texture == Icons.role_placeholder(role)
		var want: Texture2D = Baker.bake(_profiles[i]["look"], "walk")
		bake_ok = bake_ok and body.sprite != null and body.sprite.texture == want
		bake_ok = bake_ok and body.modulate == Color.WHITE
		bake_ok = bake_ok and body.hero_id == Blob.base_hero(CLASSES[i])
	check("rol-icoon per klasse (Heal Tank Control Dps)", icons_ok)
	check("avatars gebruiken de paper-doll-bakker", bake_ok)
	var ai_rows: Array = [
		{"seat": 0, "class": "warrior", "controller": "local"},
		{"seat": 1, "class": "priest", "controller": "ai"},
		{"seat": 2, "class": "mage", "controller": "ai"},
		{"seat": 3, "class": "psytech", "controller": "ai"},
	]
	hal.show_rows(ai_rows)
	await _frames(1)
	var ai_ok := true
	var expect: PackedStringArray = ["Tank", "Heal", "Control", "Dps"]
	for i in 4:
		var body := hal.body_at(i)
		if body == null or str(body.get_meta("role", "")) != expect[i]:
			ai_ok = false
			continue
		if i > 0 and str(body.get_meta("controller", "")) != "ai":
			ai_ok = false
		var icon := body.get_node_or_null("RoleIcon") as Sprite2D
		ai_ok = ai_ok and icon != null and icon.texture == Icons.role_texture(expect[i])
	check("AI-stoelen krijgen het rol-icoon van hun klasse", ai_ok)
	var text_field := false
	var row := hal.get_node_or_null("HalHud/HudRoot/ButtonRow")
	if row != null:
		for child in row.get_children():
			if child is LineEdit:
				text_field = true
	check("emote-rij heeft geen tekstvak", row != null and row.get_child_count() >= 4 and not text_field)
	hal.queue_free()
	await _frames(1)


func _four_class_rows() -> Array:
	var rows: Array = []
	for i in 4:
		rows.append({
			"seat": i,
			"slot": i,
			"class": CLASSES[i],
			"controller": "local" if i == 0 else "remote",
			"look": _profiles[i]["look"],
		})
	return rows


func _four_seats() -> void:
	OS.set_environment(Protocol.RELAY_URL_ENV, _url)
	var vp := SubViewport.new()
	vp.name = "HalView"
	vp.size = VIEWPORT
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.handle_input_locally = true
	add_child(vp)
	_nodes.append(vp)
	var packed := load(HAL_SCENE) as PackedScene
	var host: OnlineHal = packed.instantiate()
	host.name = "HostHal"
	host.profile = _profiles[0]
	host.camera_on = true
	vp.add_child(host)
	await _frames(2)
	var screen := host.find_child("CodeScreen", true, false) as CoopLobbyScreen
	check("hal hergebruikt het code-scherm", screen != null and screen.hall_mode)
	var host_btn := _find_button(screen, "Host online")
	check("code-scherm toont Host online", host_btn != null)
	if host_btn != null:
		host_btn.pressed.emit()
	var hosted := await wait_until(func() -> bool:
		var lob := host.active_lobby()
		return lob != null and lob.room_code != "" and host.lobby != null
	, STEP)
	check("host staat in de hal met een kamercode", hosted)
	if not hosted:
		return
	var code := host.lobby.room_code
	var guests: Array[OnlineHal] = []
	for i in range(1, 4):
		var guest: OnlineHal = packed.instantiate()
		guest.name = "GuestHal%d" % i
		guest.profile = _profiles[i]
		guest.camera_on = false
		add_child(guest)
		_nodes.append(guest)
		guests.append(guest)
		await _frames(2)
		var gscreen := guest.find_child("CodeScreen", true, false) as CoopLobbyScreen
		var join_btn := _find_button(gscreen, "Join online")
		if join_btn != null:
			join_btn.pressed.emit()
		await _frames(2)
		var joined_ui := gscreen != null and gscreen._code_edit != null
		check("gast %d ziet het codevak" % i, joined_ui)
		if not joined_ui:
			return
		gscreen._code_edit.text = code
		gscreen._submit_code()
	var flags_round: Dictionary = GameState.story_flags.duplicate()
	var step_round := int(GameState.story_step)
	var save_round := _save_bytes()
	var full := await wait_until(func() -> bool:
		if host.lobby == null or host.lobby.player_count() != 4:
			return false
		for g in guests:
			if g.lobby == null or g.lobby.player_count() != 4 or g.body_at(3) == null:
				return false
		return host.body_at(3) != null
	, 20.0)
	check("vier stoelen in de hal via de relay", full)
	if not full:
		return
	var roster_ok := true
	for i in 4:
		var body := host.body_at(i)
		if body == null:
			roster_ok = false
			continue
		roster_ok = roster_ok and str(body.get_meta("class_id", "")) == str(_profiles[i]["class"])
		roster_ok = roster_ok and str(body.get_meta("role", "")) == Profile.role_for(str(_profiles[i]["class"]))
		var icon := body.get_node_or_null("RoleIcon") as Sprite2D
		var role := Profile.role_for(str(_profiles[i]["class"]))
		roster_ok = roster_ok and icon != null and icon.texture == Icons.role_texture(role)
	check("elke stoel toont naam-klasse als rol-icoon", roster_ok)
	var baked: Texture2D = Baker.bake(_profiles[0]["look"], "walk")
	var host_body := host.body_at(0)
	check("host-poppetje is gebakken, niet getint", host_body != null and host_body.sprite != null and host_body.sprite.texture == baked and host_body.modulate == Color.WHITE)
	AiSeats.filler = func(_human: Array) -> Array:
		return [{"class": "psytech"}]
	# De kamer zit vol: de haak mag geen vijfde stoel tekenen.
	host.refresh_actors()
	await _frames(1)
	check("volle kamer blijft op 4 stoelen", host.body_at(0) != null and host.body_at(4) == null and host._bodies.size() == 4)
	AiSeats.clear()
	# Eén mens + AI-haak, los van deze kamer: zie hierboven de rij-test.
	var far := host.local_body().position
	host.interact()
	check("ver van het bord opent de kiezer niet", not host.picker_open())
	host.place_local(host.get_node("Objects/BordWarp").position)
	host.interact()
	check("BordWarp opent de kiezer", host.picker_open())
	check("alleen Easy is aanklikbaar", host.mode_button_enabled("easy") and not host.mode_button_enabled("normal") and not host.mode_button_enabled("hard"))
	var normal_btn := host.mode_button("normal")
	if normal_btn != null:
		normal_btn.pressed.emit()
	check("Normal blijft dicht", host.lobby.sim_mode == "" and not host.try_select_mode("normal") and not host.try_select_mode("hard"))
	check("host kiest Easy", host.try_select_mode("easy") and host.lobby.sim_id == "dls" and host.lobby.sim_mode == "easy")
	var guest_sees := await wait_until(func() -> bool:
		return guests[0].lobby != null and guests[0].lobby.sim_mode == "easy" and guests[1].lobby.sim_mode == "easy" and guests[2].lobby.sim_mode == "easy"
	, STEP)
	check("gasten zien de keuze Easy", guest_sees)
	check("gast kan de modus niet zetten", not guests[0].try_select_mode("easy") and not guests[0].try_select_mode("normal") and not guests[0].mode_button_enabled("easy"))
	guests[0].open_picker()
	check("gast-kiezer toont Easy uit en de rest op slot", guests[0].picker_open() and not guests[0].mode_button_enabled("easy") and not guests[0].mode_button_enabled("hard"))
	check("Start uit zolang niet iedereen Ready is", not host.start_enabled())
	host.toggle_ready()
	guests[0].toggle_ready()
	guests[1].toggle_ready()
	var waiting := await wait_until(func() -> bool:
		return host.lobby.seat_ready(0) and host.lobby.seat_ready(1) and host.lobby.seat_ready(2) and not host.lobby.seat_ready(3)
	, STEP)
	check("drie Ready, de vierde nog niet", waiting and not host.start_enabled())
	if host.press_start():
		check("Start weigert een ontbrekende Ready", false)
	else:
		check("Start weigert een ontbrekende Ready", true)
	guests[2].toggle_ready()
	var all_ready := await wait_until(func() -> bool: return host.lobby.human_seats_ready(), STEP)
	check("alle menselijke stoelen Ready", all_ready and host.start_enabled())
	var guest_started := [false, false, false]
	for i in guests.size():
		var idx := i
		guests[i].lobby.start_game_received.connect(func() -> void: guest_started[idx] = true)
	var did_start := host.press_start()
	check("host start de ronde", did_start and host.started)
	var started := await wait_until(func() -> bool:
		return guest_started[0] and guest_started[1] and guest_started[2]
	, STEP)
	check("gasten ontvangen de start", started and guests[0].started)
	var x0 := host.local_body().position.x
	var gx0 := guests[0].body_at(0).position.x
	host.set_stick(Vector2.RIGHT)
	var moved := await wait_until(func() -> bool:
		return host.local_body() != null and host.local_body().position.x > x0 + 8.0
	, STEP)
	host.set_stick(Vector2.ZERO)
	var guest_moved := await wait_until(func() -> bool:
		var body := guests[0].body_at(0)
		return body != null and body.position.x > gx0 + 4.0
	, STEP)
	check("host loopt", moved)
	check("gast ziet de host via snapshots", guest_moved)
	check("snapshots hebben geen vijanden", host.snapshot_enemy_count == 0 and guests[0].snapshot_enemy_count == 0 and host.enemy_nodes() == 0)
	var counts := [0, 0, 0, 0]
	var last := [-1, -1, -1, -1]
	var halls: Array[OnlineHal] = [host]
	for g in guests:
		halls.append(g)
	for i in halls.size():
		var idx := i
		halls[i].lobby.emote_received.connect(func(seat: int, emote_id: int) -> void:
			counts[idx] += 1
			last[idx] = emote_id
		)
	check("emote 0 gaat de kamer rond", guests[0].press_emote(0))
	var got := await wait_until(func() -> bool:
		for n in counts:
			if n != 1:
				return false
		return true
	, STEP)
	var id_ok := true
	for seen in last:
		if seen != 0:
			id_ok = false
	var seat1 := host.body_at(1)
	var balloon := seat1.get_node_or_null("EmoteBalloon") as Sprite2D if seat1 != null else null
	check("emote ontvangen zonder tekst", got and id_ok and balloon != null and balloon.visible and balloon.texture == Icons.emote_texture(0))
	check("tweede emote binnen de cooldown gaat niet weg", not guests[0].press_emote(0))
	await _frames(8)
	var held := true
	for n in counts:
		if n != 1:
			held = false
	check("cooldown houdt de tweede emote tegen", held)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1700:
		await get_tree().process_frame
	check("na de cooldown mag emote 3 (bedankt)", guests[0].press_emote(3))
	var thanks := await wait_until(func() -> bool:
		for n in counts:
			if n != 2:
				return false
		return true
	, STEP)
	var thanks_id := true
	for seen2 in last:
		if seen2 != 3:
			thanks_id = false
	check("emote 3 komt aan als id, niet als tekst", thanks and thanks_id)
	check("id 4 is geen lobby-knop", not host.press_emote(4) and not host.press_emote(-1))
	await _frames(4)
	var img := await _shot(vp)
	var varied := false
	if img != null:
		var colors := {}
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				colors[img.get_pixel(x, y).to_html(false)] = true
		varied = img.get_width() == VIEWPORT.x and img.get_height() == VIEWPORT.y and colors.size() > 8
	check("hal-beeld is gevuld", varied)
	# De speler stond even op het bord; zet hem terug zodat de save niet meedoet.
	host.place_local(far)
	var flags_after: Dictionary = GameState.story_flags.duplicate()
	var save_after := _save_bytes()
	if flags_after != flags_round:
		print("INFO  vlaggen voor=%s na=%s" % [flags_round, flags_after])
	if int(GameState.story_step) != step_round:
		print("INFO  story_step %d -> %d" % [step_round, int(GameState.story_step)])
	if save_after != save_round:
		print("INFO  save %s bytes %d -> %d" % [GameState.save_path, save_round.size(), save_after.size()])
	check("ronde schrijft geen verhaalvlag", flags_after == flags_round and int(GameState.story_step) == step_round and save_after == save_round)


func _find_button(ui: CoopLobbyScreen, label: String) -> Button:
	if ui == null:
		return null
	for b in ui.all_touch_buttons():
		if str(b.get_meta("label", b.text)) == label:
			return b
	return null


func _tile_blob(text: String) -> String:
	var key := "tile_map_data = PackedByteArray(\""
	var i := text.find(key)
	if i < 0:
		return ""
	var a := i + key.length()
	var b := text.find("\")", a)
	if b < 0:
		return ""
	return text.substr(a, b - a)


func _tree_clean(node: Node) -> bool:
	var banned := ["HubBoot", "Kael", "Orion", "NaarWarp", "NaarHanger", "NaarBuiten", "NaarCodex", "NaarSchot", "NaarKamers", "AnkerGids"]
	if banned.has(str(node.name)):
		return false
	var scr: Script = node.get_script() as Script
	if scr != null:
		var path := scr.resource_path
		if path.find("hub_boot") >= 0 or path.find("rekruut") >= 0 or path.find("map_exit") >= 0 or path.find("locked_exit") >= 0 or path.ends_with("map.gd"):
			return false
	for child in node.get_children():
		if not _tree_clean(child):
			return false
	return true


func _save_bytes() -> PackedByteArray:
	var path := str(GameState.save_path)
	if path == "" or not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _shot(vp: SubViewport) -> Image:
	await _frames(2)
	var tex := vp.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	var dir := shots if shots != "" else "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("online_hal.png")
	img.save_png(path)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	img.save_png("/opt/cursor/artifacts/online_hal.png")
	print("INFO  screenshot: ", path)
	return img


func _start_relay() -> bool:
	var dir := ProjectSettings.globalize_path(RELAY_DIR)
	var out: Array = []
	var node_ok := OS.execute("node", ["--version"], out) == 0
	check("node gevonden", node_ok)
	if not node_ok:
		return false
	if not DirAccess.dir_exists_absolute(dir.path_join("node_modules/ws")):
		var npm_out: Array = []
		var code := OS.execute("npm", ["ci", "--prefix", dir, "--no-audit", "--no-fund", "--silent"], npm_out, true)
		check("npm ci in relay/", code == 0)
		if code != 0:
			return false
	_port = _free_port()
	check("vrije poort", _port > 0)
	if _port == 0:
		return false
	OS.set_environment("RELAY_QUIET", "1")
	_relay_pid = OS.create_process("node", [dir.path_join("server.js"), "--port=%d" % _port])
	check("relay-proces gestart", _relay_pid > 0)
	if _relay_pid <= 0:
		return false
	_url = "ws://127.0.0.1:%d" % _port
	var up := await wait_until(_relay_accepts, 10.0)
	check("relay luistert", up)
	return up


func _free_port() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	for _i in 40:
		var port := rng.randi_range(50000, 58000)
		var probe := TCPServer.new()
		if probe.listen(port, "127.0.0.1") == OK:
			probe.stop()
			return port
	return 0


func _relay_accepts() -> bool:
	var peer := StreamPeerTCP.new()
	var err := peer.connect_to_host("127.0.0.1", _port)
	if err != OK:
		return false
	var left := 50
	while left > 0 and peer.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		peer.poll()
		left -= 1
		OS.delay_msec(10)
	var ok := peer.get_status() == StreamPeerTCP.STATUS_CONNECTED
	peer.disconnect_from_host()
	return ok


func _stop_relay() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	if _relay_pid > 0:
		OS.kill(_relay_pid)
		_relay_pid = 0
