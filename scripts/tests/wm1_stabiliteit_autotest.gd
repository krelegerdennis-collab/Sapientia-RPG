extends RefCounted
## WM1-stabiliteit (docs/qa/WM1_BUGJACHT.md): regressietests voor O-2 en O-3 binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-wm1-stabiliteit
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.
## t = de autotest-node (check/frames/...).
##
## O-2  archief_2_warper: de boog 'n' in de noordmuur is alleen beeld (geen uitgang). dungeon_room.gd
##      kon dat niet onderscheiden van een vergeten doel en gaf bij elke bouw
##      push_error('uitgang n heeft geen doel'). push_error is in 4.3 niet af te vangen, dus testen we de
##      oorzaak in de data: elk uitgangsteken in elke kamerlayout heeft een doel of staat expliciet in
##      "decor_uitgangen"; en de gebouwde warper heeft precies één MapExit en houdt zijn boog.
## O-3  map._fit_camera: hangt aan viewport.size_changed en draaide ook voor een kaart die al uit de boom
##      was (get_viewport_rect -> ERROR !is_inside_tree). Zonder de guard overschrijft zo'n aanroep de
##      cameragrenzen met rommel; dat is te meten.

const DR := preload("res://scripts/data/dungeon_rooms.gd")
const SD := preload("res://scripts/data/story_data.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const MAPS := "res://scenes/maps/"
const WARPER_MAP := MAPS + "archief_2_warper.tscn"
const HAL_MAP := MAPS + "archief_2_v4_hal.tscn"
const KLEIN_MAP := MAPS + "wilgendal.tscn"
const SENTINEL := Rect2i(-12345, -23456, 34567, 45678)

var t: Node


func _init(p_t: Node) -> void:
	t = p_t


func run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	var oude_mult: float = GameState.encounter_multiplier
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	_o2_data()
	await _o2_scene()
	await _o3_camera()
	await _o3_commandokruis()
	Settings.set_value("battle_style", oude_stijl)
	GameState.encounter_multiplier = oude_mult


# ---------------------------------------------------------------- hulpjes
func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = ""
	GameState.has_return_point = false
	t.get_tree().change_scene_to_file(pad)
	for i in 180:
		await t.get_tree().process_frame
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4 \
				and s.get_node_or_null("Objects/Player") != null:
			return s
	return null


## Alle kamer-id's met een layout, uit elke databron.
func _alle_kamers() -> Dictionary:
	var uit := {}
	for bron in [DR.ROOMS, DR.archief2().ROOMS, DR.archief2().rooms(), DR.berggrot().ROOMS, DR.woud().ROOMS]:
		for id in bron:
			uit[str(id)] = bron[id]
	return uit


# ---------------------------------------------------------------- O-2
func _o2_data() -> void:
	var kamers := _alle_kamers()
	t.check("O-2: kamerdata gevonden (%d kamers)" % kamers.size(), kamers.size() > 25 and kamers.has("archief_2_warper"))
	var zonder_doel: Array[String] = []
	for id in kamers:
		var room: Dictionary = kamers[id]
		var exits: Dictionary = room.get("exits", {})
		if exits.is_empty() and room.has("exit"):
			exits = {"E": room["exit"]}
		var decor: Array = room.get("decor_uitgangen", [])
		for rij in room.get("layout", []):
			for ch in str(rij):
				if DR.EXIT_CHARS.has(ch):
					var sleutel: String = DR.EXIT_CHARS[ch]
					if not exits.has(sleutel) and not decor.has(sleutel) and not zonder_doel.has("%s:%s" % [id, sleutel]):
						zonder_doel.append("%s:%s" % [id, sleutel])
	t.check("O-2: elk uitgangsteken in elke kamerlayout heeft een doel of is expliciet decor %s" % [zonder_doel], zonder_doel.is_empty())

	var warper: Dictionary = kamers["archief_2_warper"]
	t.check("O-2: warper declareert de boog n als decor", warper.get("decor_uitgangen", []) == ["n"])
	t.check("O-2: de boog zit nog in de warper-layout (de 1.4x-regel wil n op rij 2)", str(warper["layout"][2]).count("n") == 1)
	t.check("O-2: warper houdt zijn ene echte uitgang E (naar de Genezer)", warper["exits"].keys() == ["E"]
			and str(warper["exits"]["E"]["map"]).ends_with("archief_2_v4_genezer.tscn"))
	var grond: Array = load("res://scripts/data/archief2_ground.gd").GROUND["archief_2_warper"]
	t.check("O-2: beeld van de noordmuur ongewijzigd (grondlaag houdt de boog, tegel 43)", int(grond[2][13]) == 43)
	var decor_overal := 0
	for id in kamers:
		decor_overal += (kamers[id] as Dictionary).get("decor_uitgangen", []).size()
	t.check("O-2: decor is de uitzondering (alleen de warper, %d)" % decor_overal, decor_overal == 1)
	# Het uitgangsmechanisme zelf blijft werken in kamers die de boog wel als uitgang hebben.
	var hal: Dictionary = kamers["archief_2_v4_hal"]
	t.check("O-2: kamers met een echte boog-uitgang houden die (v4_hal: E + n)", hal["exits"].has("n") and hal["exits"].has("E")
			and str(hal["layout"][2]).contains("n") and not hal.has("decor_uitgangen"))


func _o2_scene() -> void:
	var s: Node = await _laad(WARPER_MAP)
	t.check("O-2: warper-kamer gebouwd", s != null)
	if s == null:
		return
	var exits := s.get_node("Exits")
	var doelen: Array[String] = []
	for e in exits.get_children():
		if "target_map" in e:
			doelen.append(str(e.target_map))
	t.check("O-2: gebouwde warper heeft precies 1 uitgang (%d)" % exits.get_child_count(), exits.get_child_count() == 1)
	t.check("O-2: die uitgang gaat naar de Genezer %s" % [doelen], doelen.size() == 1 and doelen[0].ends_with("archief_2_v4_genezer.tscn"))
	t.check("O-2: de noordmuur-boog (13,2) is tegel 43 in de gebouwde kamer", int(s._cells.get(Vector2i(13, 2), -1)) == 43)
	var h: Node = await _laad(HAL_MAP)
	t.check("O-2: kamer met boog-uitgang bouwt nog twee uitgangen (v4_hal: %d)" % (h.get_node("Exits").get_child_count() if h else -1),
			h != null and h.get_node("Exits").get_child_count() == 2)


# ---------------------------------------------------------------- O-3
func _o3_camera() -> void:
	var m: Node = await _laad(KLEIN_MAP)
	t.check("O-3: kaart geladen (wilgendal)", m != null and m.has_method("_fit_camera"))
	if m == null:
		return
	var cam: Camera2D = m.player.camera
	_zet_grenzen(cam, SENTINEL)
	m._fit_camera()
	t.check("O-3: in de boom past _fit_camera de grenzen nog gewoon aan", _grenzen(cam) != SENTINEL and _grenzen(cam).size.x > 0)
	var vp: Viewport = m.get_viewport()
	_zet_grenzen(cam, SENTINEL)
	vp.size_changed.emit()
	t.check("O-3: size_changed in de boom past de grenzen aan (koppeling intact)", _grenzen(cam) != SENTINEL)

	# Kaart uit de boom maar nog niet vrij (de tussentijd van een kamerwissel / Classic -> Action).
	var ouder: Node = m.get_parent()
	ouder.remove_child(m)
	t.check("O-3: kaart staat buiten de boom", not m.is_inside_tree())
	_zet_grenzen(cam, SENTINEL)
	m._fit_camera()
	t.check("O-3: _fit_camera buiten de boom laat de cameragrenzen met rust", _grenzen(cam) == SENTINEL)
	vp.size_changed.emit()
	t.check("O-3: size_changed voor een kaart buiten de boom laat de grenzen met rust", _grenzen(cam) == SENTINEL)
	m.free()

	# Echte Classic -> Action-wissel in een Action-kamer; geen kaart blijft aan size_changed hangen.
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	var room: Node = await _laad(SomData.START_MAP)
	t.check("O-3: Classic-kamer geladen (%s)" % SomData.START_MAP, room != null and room.som == null)
	if room == null:
		return
	var oude_cam: Camera2D = room.player.camera
	_zet_grenzen(oude_cam, SENTINEL)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	GameState.reload_room(room.player.get_tile(), room.player.facing)
	var vp2: Viewport = room.get_viewport()
	var lek := false
	for i in 120:
		await t.get_tree().process_frame
		if is_instance_valid(room) and not room.is_inside_tree():
			vp2.size_changed.emit()
			lek = lek or _grenzen(oude_cam) != SENTINEL
		var s: Node = t.get_tree().current_scene
		if s != null and s != room and s.is_node_ready() and not GameState.changing_map and s.get_node_or_null("Objects/Player") != null:
			break
	var nieuw: Node = t.get_tree().current_scene
	t.check("O-3: na Classic -> Action is de kamer opnieuw gebouwd met arena", nieuw != null and nieuw != room and nieuw.som != null)
	t.check("O-3: de weggehaalde Classic-kamer kreeg geen camerabewerking meer", not lek)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)


## Zelfde fout aan de gevechtskant: het commandokruis (battle) plaatst zijn naamtabje via
## get_viewport_rect, ook als het gevecht net uit de boom is.
func _o3_commandokruis() -> void:
	var kruis: Control = preload("res://scripts/battle/command_cross.gd").new()
	t.get_tree().root.add_child(kruis)
	var tab: Control = kruis.name_tab
	var sentinel := Vector2(-999.0, -999.0)
	tab.position = sentinel
	kruis._place_name()
	t.check("O-3: commandokruis in de boom plaatst zijn naamtabje", tab.position != sentinel)
	t.get_tree().root.remove_child(kruis)
	tab.position = sentinel
	kruis._place_name()
	t.check("O-3: commandokruis buiten de boom laat zijn naamtabje met rust", tab.position == sentinel)
	kruis.free()


func _grenzen(cam: Camera2D) -> Rect2i:
	return Rect2i(cam.limit_left, cam.limit_top, cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)


func _zet_grenzen(cam: Camera2D, r: Rect2i) -> void:
	cam.limit_left = r.position.x
	cam.limit_top = r.position.y
	cam.limit_right = r.end.x
	cam.limit_bottom = r.end.y
