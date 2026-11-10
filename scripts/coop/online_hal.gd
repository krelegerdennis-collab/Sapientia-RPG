class_name OnlineHal
extends Node2D
## Online warper-hal (M5). Zelfde tegelkaart en borden als de solo-hal,
## zonder de solo-boot, gids, rekruten, uitgangen of verhaal.
## Host kiest op BordWarp alleen Easy. Ready-check, emotes, rol-iconen.
## Avatars: paper-doll-bakker + CoopAvatar, snapshots op 20 Hz, geen vijanden.

const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const SessionScript := preload("res://scripts/net/action_coop_session.gd")
const AvatarBlob := preload("res://scripts/net/avatar_blob.gd")
const EmoteGateScript := preload("res://scripts/net/emote_gate.gd")
const Profile := preload("res://scripts/online/online_profile.gd")
const Baker := preload("res://scripts/online/paper_doll_baker.gd")
const CoopAvatarScript := preload("res://scripts/coop/coop_avatar.gd")
const Icons := preload("res://scripts/coop/online_icon_paths.gd")
const AiSeats := preload("res://scripts/coop/online_ai_seats.gd")
const LobbyScreen := preload("res://scripts/ui/coop_lobby_screen.gd")
const UiMenu := preload("res://scripts/ui/ui_menu.gd")
const MenuColors := preload("res://scripts/ui/menu_colors.gd")
const THEME := preload("res://assets/theme.tres")

const TRIAL_SIM := "dls"
const TRIAL_MODE := "easy"
const LOCKED_MODES: PackedStringArray = ["normal", "hard"]
const WALK_SPEED := 64.0
const BOARD_REACH := 40.0
const BALLOON_SEC := 1.2
const SPAWNS: Array[Vector2] = [
	Vector2(136, 152), Vector2(168, 152), Vector2(136, 176), Vector2(168, 176),
]
const FACE_VEC: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN,
]

## Profiel voor Host/Join (uid, name, class, look). Leeg = slot 0 van het M1-bestand.
var profile: Dictionary = {}
## false in tests die zelf een lobby aankoppelen.
var auto_lobby := true
var camera_on := true
var lobby: LanLobby
var started := false
var snapshot_enemy_count := -1

var _code: CoopLobbyScreen
var _session: ActionCoopSession
var _touch: Node
var _ground: TileMapLayer
var _camera: Camera2D
var _avatars: Node2D
var _hud: CanvasLayer
var _row: HBoxContainer
var _picker: HBoxContainer
var _code_label: Label
var _mode_label: Label
var _ready_btn: Button
var _start_btn: Button
var _mode_btns: Dictionary = {}
var _bodies: Dictionary = {}
var _walk_rect := Rect2(16, 16, 352, 184)
var _blocks := false
var _entered := false
var _stick := Vector2.ZERO
var _emotes: EmoteGate
var _balloon_left: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_priority")
	_ground = get_node_or_null("Ground") as TileMapLayer
	_camera = get_node_or_null("Camera2D") as Camera2D
	_avatars = get_node_or_null("Objects/Avatars") as Node2D
	_touch = get_node_or_null("TouchControls/Control")
	if _touch != null:
		_touch.analog_only = true
		_touch.show_menu = false
	_emotes = EmoteGateScript.new()
	_fit_camera()
	_boot_bounds()
	_build_hud()
	if auto_lobby:
		_open_code_screen()


func _exit_tree() -> void:
	if _session != null and is_instance_valid(_session):
		_session.shutdown(true)
	_session = null


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		interact()
	if _balloon_left.is_empty():
		return
	var done: Array = []
	for seat in _balloon_left.keys():
		var left := float(_balloon_left[seat]) - delta
		if left <= 0.0:
			done.append(seat)
		else:
			_balloon_left[seat] = left
	for seat in done:
		_balloon_left.erase(seat)
		_set_balloon(int(seat), false)


func claims_touch(viewport_pos: Vector2) -> bool:
	if _row != null and _row.visible and _row.get_global_rect().has_point(viewport_pos):
		return true
	if _picker != null and _picker.visible and _picker.get_global_rect().has_point(viewport_pos):
		return true
	return false


func active_lobby() -> LanLobby:
	if lobby != null:
		return lobby
	if _code != null:
		return _code.lobby
	return null


func set_stick(stick: Vector2) -> void:
	_stick = stick


func local_body() -> CoopAvatar:
	if lobby == null:
		return null
	return _bodies.get(lobby.local_slot) as CoopAvatar


func body_at(seat: int) -> CoopAvatar:
	return _bodies.get(seat) as CoopAvatar


func enemy_nodes() -> int:
	return _count_named(self, "enemy") + _count_named(self, "vijand")


func near_board() -> bool:
	var body := local_body()
	var board := get_node_or_null("Objects/BordWarp") as Node2D
	if body == null or board == null:
		return false
	return body.position.distance_to(board.position) <= BOARD_REACH


func interact() -> void:
	if near_board():
		open_picker()


func open_picker() -> void:
	if _picker != null:
		_picker.visible = true
	_refresh_hud()


func close_picker() -> void:
	if _picker != null:
		_picker.visible = false


func picker_open() -> bool:
	return _picker != null and _picker.visible


func mode_button(mode: String) -> Button:
	return _mode_btns.get(mode) as Button


func mode_button_enabled(mode: String) -> bool:
	var btn := mode_button(mode)
	return btn != null and not btn.disabled


func try_select_mode(mode: String) -> bool:
	if lobby == null or not lobby.is_host:
		return false
	if mode != TRIAL_MODE:
		return false
	return lobby.select_sim(TRIAL_SIM, TRIAL_MODE)


func toggle_ready() -> void:
	if lobby == null:
		return
	lobby.set_ready(not lobby.seat_ready(lobby.local_slot))
	_refresh_hud()


func start_enabled() -> bool:
	return lobby != null and lobby.is_host and lobby.human_seats_ready() and not started


func press_start() -> bool:
	if not start_enabled():
		return false
	lobby.host_start_game()
	started = true
	_refresh_hud()
	return true


## Alleen ids 0..3 (help, hier heen, goed gedaan, bedankt). Geen tekstvak.
func press_emote(emote_id: int) -> bool:
	if emote_id < 0 or emote_id >= Icons.EMOTE_COUNT:
		return false
	if lobby == null or lobby.phase != LanLobby.Phase.IN or lobby.local_slot < 0:
		return false
	var now := float(Time.get_ticks_msec()) / 1000.0
	if not _emotes.allow(lobby.local_slot, now):
		return false
	lobby.send_emote(emote_id)
	return true


func button_named(node_name: String) -> BaseButton:
	if _hud == null:
		return null
	return _hud.find_child(node_name, true, false) as BaseButton


func show_rows(rows: Array) -> void:
	_spawn_all(rows)


func refresh_actors() -> void:
	var human: Array = []
	if lobby != null:
		for row in lobby.slots:
			human.append(row)
	var rows: Array = []
	var used := {}
	for row in human:
		var seat := _seat_of(row)
		if seat < 0 or seat >= Protocol.MAX_PLAYERS or used.has(seat):
			continue
		used[seat] = true
		rows.append(row)
	var next := 0
	for extra in AiSeats.fill(human):
		if not (extra is Dictionary):
			continue
		var row: Dictionary = extra
		var seat := int(row.get("seat", -1))
		if seat < 0 or used.has(seat):
			while next < Protocol.MAX_PLAYERS and used.has(next):
				next += 1
			seat = next
		if seat < 0 or seat >= Protocol.MAX_PLAYERS or used.has(seat):
			continue
		used[seat] = true
		next = seat + 1
		row["seat"] = seat
		row["slot"] = seat
		rows.append(row)
	_spawn_all(rows)


func attach(p_lobby: LanLobby) -> void:
	if _entered or p_lobby == null:
		return
	_entered = true
	lobby = p_lobby
	if _hud != null:
		_hud.visible = true
	if not lobby.roster_changed.is_connected(_on_roster):
		lobby.roster_changed.connect(_on_roster)
	if not lobby.ready_changed.is_connected(_on_ready):
		lobby.ready_changed.connect(_on_ready)
	if not lobby.sim_selected.is_connected(_on_sim):
		lobby.sim_selected.connect(_on_sim)
	if not lobby.emote_received.is_connected(_on_emote):
		lobby.emote_received.connect(_on_emote)
	if not lobby.start_game_received.is_connected(_on_start_game):
		lobby.start_game_received.connect(_on_start_game)
	refresh_actors()
	_start_sync()
	_refresh_hud()


func place_local(pos: Vector2) -> void:
	var body := local_body()
	if body != null:
		body.position = pos


# --- arena-koppeling voor ActionCoopSession (20 Hz snapshot, geen vijanden) ---

func coop_poll_local_input() -> Dictionary:
	var stick := _stick
	if stick.length_squared() < 0.0001 and _touch != null:
		stick = _touch.joy_raw
	if stick.length() < 0.2:
		stick = Vector2.ZERO
	else:
		stick = stick.limit_length(1.0)
	return {"stick": stick, "buttons": 0, "lock_idx": -1}


func coop_host_step(inputs: Array, dt: float) -> void:
	var step := dt if dt > 0.0 else (1.0 / 60.0)
	for inp in inputs:
		if not (inp is Dictionary):
			continue
		var row: Dictionary = inp
		var body := _bodies.get(int(row.get("slot", -1))) as CoopAvatar
		if body == null:
			continue
		var stick: Vector2 = row.get("stick", Vector2.ZERO)
		if stick.length_squared() <= 0.0001:
			continue
		var dir := stick.normalized()
		var nxt := body.position + dir * WALK_SPEED * step
		nxt = Vector2(roundf(nxt.x), roundf(nxt.y))
		if _blocked(nxt):
			var slide_x := Vector2(nxt.x, body.position.y)
			var slide_y := Vector2(body.position.x, nxt.y)
			if not _blocked(slide_x):
				nxt = slide_x
			elif not _blocked(slide_y):
				nxt = slide_y
			else:
				nxt = body.position
		body.place(nxt, FACE_VEC[_face_bits(dir)])


func coop_encode_snapshot(tick: int) -> PackedByteArray:
	var players: Array = []
	for seat in _bodies.keys():
		var body := _bodies[seat] as CoopAvatar
		if body == null:
			continue
		players.append({
			"slot": int(seat),
			"x": int(roundf(body.position.x)),
			"y": int(roundf(body.position.y)),
			"face": _face_bits_of(body.facing),
			"frame": 1,
			"hp": 1,
			"mp": 0,
			"flags": 0,
		})
	snapshot_enemy_count = 0
	return Codec.pack_snapshot(tick, players, [])


func apply_coop_snapshot(snap: Dictionary) -> void:
	var enemies: Array = snap.get("enemies", [])
	snapshot_enemy_count = enemies.size()
	if _session != null and _session.is_host:
		return
	for row in snap.get("players", []):
		if not (row is Dictionary):
			continue
		var seat_row: Dictionary = row
		var body := _bodies.get(int(seat_row.get("slot", -1))) as CoopAvatar
		if body == null:
			continue
		var face_i := clampi(int(seat_row.get("face", 0)), 0, FACE_VEC.size() - 1)
		body.place(Vector2(float(seat_row.get("x", 0)), float(seat_row.get("y", 0))), FACE_VEC[face_i])


func coop_sync_roster(slots: Array) -> void:
	refresh_actors()
	if slots.is_empty():
		return


# --- intern -----------------------------------------------------------------

func _open_code_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CodeLayer"
	layer.layer = 30
	add_child(layer)
	var screen := LobbyScreen.new()
	screen.name = "CodeScreen"
	screen.hall_mode = true
	screen.hall_profile = _profile_packet()
	layer.add_child(screen)
	_code = screen
	if not screen.lobby.room_ready.is_connected(_on_room_ready):
		screen.lobby.room_ready.connect(_on_room_ready)
	if not screen.lobby.assigned.is_connected(_on_assigned):
		screen.lobby.assigned.connect(_on_assigned)
	if not screen.lobby.roster_changed.is_connected(_maybe_enter):
		screen.lobby.roster_changed.connect(_maybe_enter)


func _on_room_ready(_code: String) -> void:
	_maybe_enter()


func _on_assigned(_slot: int, _character_id: String) -> void:
	_maybe_enter()


func _maybe_enter() -> void:
	if _entered or _code == null or _code.lobby == null:
		return
	var lob := _code.lobby
	if lob.phase != LanLobby.Phase.IN:
		return
	if lob.is_host and lob.room_code == "":
		return
	if not lob.is_host and lob.local_slot < 0:
		return
	_code.fold_for_hall()
	attach(lob)


func _profile_packet() -> Dictionary:
	var src := profile
	if src.is_empty():
		var store := Profile.new()
		if store.has_slot(0):
			src = store.get_slot(0)
	if src.is_empty():
		return {}
	var class_id := str(src.get("class", ""))
	var look_v: Variant = src.get("look", {})
	if look_v is PackedByteArray:
		return {
			"uid": str(src.get("uid", "")),
			"name": str(src.get("name", "")),
			"class": class_id,
			"look": look_v,
		}
	var look := {}
	if look_v is Dictionary:
		look = (look_v as Dictionary).duplicate()
	if class_id != "":
		look["class"] = class_id
	return {
		"uid": str(src.get("uid", "")),
		"name": str(src.get("name", "")),
		"class": class_id,
		"look": look,
	}


func _start_sync() -> void:
	if lobby == null or lobby.enet_peer() == null or _session != null:
		return
	if lobby.phase != LanLobby.Phase.IN:
		return
	var roster: Array = []
	for row in lobby.slots:
		roster.append(row)
	_session = SessionScript.start_session(get_tree(), lobby.enet_peer(), roster, lobby.local_slot, false, lobby)
	_session.arena_drive = true
	_session.own_peer = false
	_session.attach_arena(self)


func _on_roster() -> void:
	if _session != null and lobby != null:
		_session.sync_roster(lobby.slots)
	refresh_actors()
	_refresh_hud()


func _on_ready() -> void:
	_refresh_hud()


func _on_sim(_sim_name: String, _mode: String) -> void:
	_refresh_hud()


func _on_emote(seat: int, emote_id: int) -> void:
	var body := _bodies.get(seat) as Node2D
	if body == null:
		return
	var balloon := body.get_node_or_null("EmoteBalloon") as Sprite2D
	if balloon == null:
		return
	balloon.texture = Icons.emote_texture(emote_id)
	balloon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	balloon.visible = true
	_balloon_left[seat] = BALLOON_SEC


func _on_start_game() -> void:
	started = true
	_refresh_hud()


func _set_balloon(seat: int, on: bool) -> void:
	var body := _bodies.get(seat) as Node
	if body == null:
		return
	var balloon := body.get_node_or_null("EmoteBalloon") as CanvasItem
	if balloon != null:
		balloon.visible = on


func _fit_camera() -> void:
	if _camera == null or _ground == null:
		return
	var used := _ground.get_used_rect()
	var center := Vector2(used.position * 16) + Vector2(used.size * 16) * 0.5
	_camera.position = center.round()
	_camera.enabled = camera_on
	if camera_on and is_inside_tree():
		_camera.make_current()


func _boot_bounds() -> void:
	if _ground == null:
		return
	var used := _ground.get_used_rect()
	if used.size.x > 2 and used.size.y > 2:
		_walk_rect = Rect2(Vector2(used.position * 16) + Vector2(12, 12), Vector2(used.size * 16) - Vector2(24, 24))
	var sample := Vector2(140, 156)
	_blocks = not _tile_solid(sample)


func _blocked(at: Vector2) -> bool:
	if not _walk_rect.has_point(at):
		return true
	if not _blocks:
		return false
	return _tile_solid(at)


func _tile_solid(at: Vector2) -> bool:
	if _ground == null:
		return false
	var data := _ground.get_cell_tile_data(_ground.local_to_map(at))
	if data == null:
		return true
	return data.get_collision_polygons_count(0) > 0


func _spawn_all(rows: Array) -> void:
	if _avatars == null:
		return
	var keep := {}
	for row in rows:
		if not (row is Dictionary):
			continue
		var seat := _seat_of(row)
		if seat < 0 or seat >= Protocol.MAX_PLAYERS:
			continue
		keep[seat] = true
		_ensure_body(seat, row)
	var drop: Array = []
	for seat in _bodies.keys():
		if not keep.has(int(seat)):
			drop.append(seat)
	for seat in drop:
		var node: Node = _bodies[seat]
		_bodies.erase(seat)
		if is_instance_valid(node):
			node.queue_free()


func _ensure_body(seat: int, row: Dictionary) -> void:
	var class_id := str(row.get("class", row.get("class_id", "")))
	var hero := AvatarBlob.base_hero(class_id)
	var look := _look_dict(row, class_id)
	var baked: Variant = Baker.bake(look, "walk")
	var tex := baked as Texture2D
	var body := _bodies.get(seat) as CoopAvatar
	if body == null:
		body = CoopAvatarScript.new()
		body.name = "Seat%d" % seat
		_avatars.add_child(body)
		var spot: Vector2 = SPAWNS[seat] if seat < SPAWNS.size() else SPAWNS[0]
		if not _walk_rect.has_point(spot):
			spot = _walk_rect.position + Vector2(16 + seat * 20, 16)
		body.position = spot
		_bodies[seat] = body
	body.setup(seat, hero, tex)
	body.look_blob = _look_blob(row, class_id)
	body.modulate = Color.WHITE
	if body.sprite != null:
		body.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.set_meta("role", Profile.role_for(class_id))
	body.set_meta("class_id", class_id)
	body.set_meta("controller", str(row.get("controller", row.get("wire_controller", ""))))
	_ensure_icon(body, Profile.role_for(class_id))
	_ensure_balloon(body)


func _ensure_icon(body: CoopAvatar, role: String) -> void:
	var icon := body.get_node_or_null("RoleIcon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "RoleIcon"
		icon.position = Vector2(0, -22)
		icon.z_index = 2
		body.add_child(icon)
	icon.texture = Icons.role_texture(role)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.visible = icon.texture != null


func _ensure_balloon(body: CoopAvatar) -> void:
	if body.get_node_or_null("EmoteBalloon") != null:
		return
	var balloon := Sprite2D.new()
	balloon.name = "EmoteBalloon"
	balloon.position = Vector2(10, -30)
	balloon.z_index = 3
	balloon.visible = false
	balloon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(balloon)


func _look_dict(row: Dictionary, class_id: String) -> Dictionary:
	var look_v: Variant = row.get("look", PackedByteArray())
	if look_v is PackedByteArray:
		var decoded := AvatarBlob.decode(look_v)
		if bool(decoded.get("ok", false)):
			decoded["class"] = str(decoded.get("class_id", class_id))
			return decoded
	if look_v is Dictionary:
		var copy: Dictionary = (look_v as Dictionary).duplicate()
		if class_id != "":
			copy["class"] = class_id
		return copy
	return {
		"class": class_id,
		"body": 0, "skin": 0, "hair": 0, "hair_color": 0,
		"top": 0, "top_color": 0, "bottom": 0, "bottom_color": 0, "head": 0,
	}


func _look_blob(row: Dictionary, class_id: String) -> PackedByteArray:
	var look_v: Variant = row.get("look", PackedByteArray())
	if look_v is PackedByteArray and (look_v as PackedByteArray).size() == AvatarBlob.BYTE_COUNT:
		return look_v
	var look := _look_dict(row, class_id)
	if str(look.get("class", "")) == "":
		look["class"] = class_id
	return AvatarBlob.encode(look)


func _seat_of(row: Dictionary) -> int:
	if row.has("seat"):
		return int(row.get("seat", -1))
	return int(row.get("slot", -1))


func _face_bits(dir: Vector2) -> int:
	if absf(dir.x) >= absf(dir.y):
		return 2 if dir.x > 0.0 else 0
	return 3 if dir.y > 0.0 else 1


func _face_bits_of(face: Vector2i) -> int:
	for i in FACE_VEC.size():
		if FACE_VEC[i] == face:
			return i
	return 3


func _count_named(node: Node, needle: String) -> int:
	var n := 0
	if str(node.name).to_lower().find(needle) >= 0:
		n += 1
	for child in node.get_children():
		n += _count_named(child, needle)
	return n


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HalHud"
	_hud.layer = 12
	_hud.visible = not auto_lobby
	add_child(_hud)
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = THEME
	_hud.add_child(root)
	_code_label = UiMenu.label("", MenuColors.TEXT, 10)
	_code_label.name = "RoomCode"
	_code_label.position = Vector2(4, 2)
	root.add_child(_code_label)
	_mode_label = UiMenu.label("", MenuColors.TEXT, 10)
	_mode_label.name = "ModeLabel"
	_mode_label.position = Vector2(4, 14)
	root.add_child(_mode_label)
	_row = HBoxContainer.new()
	_row.name = "ButtonRow"
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.add_theme_constant_override("separation", 2)
	_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_row.offset_left = -220.0
	_row.offset_top = 2.0
	_row.offset_right = -2.0
	_row.offset_bottom = 22.0
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row)
	for i in Icons.EMOTE_COUNT:
		var btn := TextureButton.new()
		btn.name = "Emote%d" % i
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.texture_normal = Icons.emote_texture(i)
		btn.ignore_texture_size = true
		btn.custom_minimum_size = Vector2(18, 18)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(press_emote.bind(i))
		_row.add_child(btn)
	_ready_btn = _text_button("Ready", "ReadyButton")
	_ready_btn.pressed.connect(toggle_ready)
	_row.add_child(_ready_btn)
	_start_btn = _text_button("Start", "StartButton")
	_start_btn.pressed.connect(press_start)
	_row.add_child(_start_btn)
	_picker = HBoxContainer.new()
	_picker.name = "SimPicker"
	_picker.visible = false
	_picker.position = Vector2(8, 36)
	_picker.add_theme_constant_override("separation", 2)
	root.add_child(_picker)
	for mode in ["easy", "normal", "hard"]:
		var label := str(mode).capitalize()
		var btn := _text_button(label, "Mode%s" % label)
		btn.pressed.connect(_on_mode_pressed.bind(mode))
		_mode_btns[mode] = btn
		_picker.add_child(btn)
	_refresh_hud()


func _text_button(text: String, node_name: String) -> Button:
	var btn := UiMenu.button(text)
	btn.name = node_name
	btn.custom_minimum_size = Vector2(0, 18)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 10)
	return btn


func _on_mode_pressed(mode: String) -> void:
	try_select_mode(mode)
	_refresh_hud()


func _refresh_hud() -> void:
	if _code_label == null:
		return
	var code := ""
	if lobby != null:
		code = lobby.room_code
	_code_label.text = "Room code: %s" % code if code != "" else ""
	var mode := ""
	if lobby != null:
		mode = lobby.sim_mode
	_mode_label.text = mode.capitalize() if mode != "" else ""
	if _ready_btn != null and lobby != null:
		var on := lobby.seat_ready(lobby.local_slot)
		_ready_btn.modulate = Color(0.65, 1.0, 0.7) if on else Color.WHITE
	if _start_btn != null:
		_start_btn.disabled = not start_enabled()
		_start_btn.visible = lobby != null and lobby.is_host
	for mode_name in _mode_btns.keys():
		var btn := _mode_btns[mode_name] as Button
		if btn == null:
			continue
		var host := lobby != null and lobby.is_host
		btn.disabled = not host or str(mode_name) != TRIAL_MODE
		var chosen := lobby != null and lobby.sim_mode == str(mode_name)
		btn.modulate = Color(1.0, 0.95, 0.7) if chosen else Color.WHITE
