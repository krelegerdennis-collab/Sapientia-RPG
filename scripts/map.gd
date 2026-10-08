extends Node2D
## Eén map (dorp, wereldkaart, later dungeons...). Elke map-scène heeft dezelfde opbouw:
##   Ground   (TileMapLayer)  de grond. Elke tile heeft custom data "terrain"
##                            (gras, bos, zand, kassei, ...). Daarmee bepaalt
##                            game_data.gd de kans op een gevecht.
##   Gebouwen (TileMapLayer)  optioneel: huizen e.d. boven op de grond
##   Objects  (Node2D)        Player, NPC's, bordjes, deuren (y-sort aan)
##   Spawns   (Node2D)        MapSpawn-punten: waar je binnenkomt (met kijkrichting)
##   Exits    (Node2D)        MapExit-zones: stap erop = naar een andere map,
##                            of alleen een bericht (bv. de trap naar de dungeon)
##   TouchControls
## Deze code regelt: camera-grenzen, de speler op de juiste plek zetten
## (na een gevecht of na een overgang), uitgangen en random encounters.

const TILE := 16
## v0.11 Automatisch opslaan na binnenkomst: net na de fade-in (Transition, 0,3 sec).
const AUTOSAVE_DELAY := 0.35

## Naam van de map (alleen informatief).
@export var map_name := ""
## Kunnen hier monsters verschijnen? In dorpen staat dit UIT.
@export var encounters := true
## TIJDELIJK (puzzels): F4 in debug-builds gaat hierheen.
const DEBUG_PUZZLE_ROOM := "res://scenes/maps/archief_test.tscn"

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Objects/Player


func _ready() -> void:
	GameState.enter_map(scene_file_path)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	if GameState.has_return_point and GameState.return_map == scene_file_path:
		# Terug uit een gevecht: zelfde tile en kijkrichting.
		player.place_at(GameState.return_tile, GameState.return_facing)
		GameState.has_return_point = false
	elif GameState.pending_spawn != "":
		# Binnengekomen via een uitgang: naar het spawnpunt met die naam.
		var spawn := get_spawn(GameState.pending_spawn)
		if spawn:
			player.place_at(spawn.get_tile(), spawn.facing)
		else:
			push_warning("Spawnpunt '%s' bestaat niet in %s" % [GameState.pending_spawn, scene_file_path])
		GameState.pending_spawn = ""

	player.stepped.connect(_on_player_stepped)
	# v0.10: MENU-knop op het touchscherm (veldmenu met o.a. het bestiarium)
	var touch := get_node_or_null("TouchControls/Control")
	if touch and "show_menu" in touch:
		touch.show_menu = true
	# v0.11 automatisch opslaan na een mapwissel of een gewonnen gevecht (GameState zet
	# het verzoek klaar); pas als het beeld er weer is, nooit tijdens de overgang zelf.
	# (timer i.p.v. await: wordt de map intussen weer verlaten, dan vervalt hij vanzelf)
	var autosave_reason := GameState.take_autosave_request()
	Transition.fade_in()
	if autosave_reason != "":
		get_tree().create_timer(AUTOSAVE_DELAY).timeout.connect(try_autosave.bind(autosave_reason))
	# v0.16 KERNKRACHT: vuurbal in het veld (knop KERN / toets K), zie scripts/kern/kern_kracht_veld.gd
	add_child(load("res://scripts/kern/kern_kracht_veld.gd").new())
	# v0.11: verhaal (tint, wie er staat, cutscenes bij binnenkomst / na een gevecht)
	Story.map_ready(self)
	# v0.15 net een baaskern geabsorbeerd? Dan nu het absorptie-moment (scripts/kern/).
	if GameState.pending_kern_absorb != "":
		var ka: Node2D = load("res://scripts/kern/kern_absorption.gd").new()
		add_child(ka)
		ka.start(self, GameState.pending_kern_absorb)
	# (de autotest wordt sinds v0.10 door GameState gestart, zie game_state.gd)


## Camera-grenzen = de map. Is de map kleiner dan het scherm (een kamer), dan staat
## hij in het midden en is de rest zwart (node 'Void' in de kamer-scène).
func _fit_camera() -> void:
	var used := ground.get_used_rect()
	var r := Rect2i(used.position * TILE, used.size * TILE)
	var vs := Vector2i(get_viewport_rect().size)
	if r.size.x < vs.x:
		r.position.x -= (vs.x - r.size.x) / 2
		r.size.x = vs.x
	if r.size.y < vs.y:
		r.position.y -= (vs.y - r.size.y) / 2
		r.size.y = vs.y
	player.set_camera_limits(r)


## Is het veldmenu (of het bestiarium) open?
func menu_open() -> bool:
	return get_node_or_null("FieldMenu") != null


func open_field_menu() -> void:
	if menu_open():
		return
	player.input_locked = true
	# v0.11: touch-D-pad/A/B weg zolang het menu open is (je tikt direct op het menu;
	# anders zou een tik op een menuregel boven de D-pad als 'lopen' tellen)
	_set_touch_visible(false)
	var m: CanvasLayer = load("res://scripts/ui/field_menu.gd").new()
	m.name = "FieldMenu"
	m.player = player
	m.closed.connect(func():
		player.input_locked = false
		_set_touch_visible(true)
		# v0.16 uitrusting-tutorial: mantel aan? Dan gaat het verhaal verder (story_data MENU_CLOSED)
		Story.menu_closed())
	add_child(m)


func _set_touch_visible(on: bool) -> void:
	var touch := get_node_or_null("TouchControls/Control")
	if touch == null:
		return
	if not on and touch.has_method("release_all"):
		touch.release_all()
	touch.visible = on


## v0.11 Automatisch opslaan vanaf deze map (op de tile van de speler), alleen als het
## veilig kan: geen gevecht, geen mapwissel, geen tekstvak, speler niet halverwege een stap.
## Geeft true als er geschreven is. Ook gebruikt door GameState (app naar de achtergrond).
func try_autosave(reason: String) -> bool:
	if not is_inside_tree() or player == null or player.is_moving:
		return false
	return GameState.autosave(player.get_tile(), player.facing, reason)


func _process(_delta: float) -> void:
	# MENU-knop verbergen zolang er een tekstvak of menu open is (anders valt hij erover)
	var touch := get_node_or_null("TouchControls/Control")
	if touch and "show_menu" in touch:
		var want := not Dialog.is_open and not menu_open() and not Story.running
		if touch.show_menu != want:
			touch.show_menu = want
	# Veldmenu (Esc/M/Tab of de MENU-knop): alleen als de speler stil staat
	if Input.is_action_just_pressed("menu") and not menu_open() and not player.is_moving \
			and not player.input_locked and not Dialog.is_open and not GameState.changing_map and not Story.running \
			and not GameState.in_battle:
		open_field_menu()
	# F3 = baasgevecht (alleen debug-builds, alleen op maps met monsters)
	if OS.is_debug_build() and encounters and Input.is_action_just_pressed("debug_boss"):
		if not GameState.in_battle and not GameState.changing_map and not player.is_moving and not Dialog.is_open:
			start_boss_battle()
	# TIJDELIJK (puzzels): F4 = naar de puzzel-testkamer (alleen debug-builds). Weghalen
	# zodra De Vergeten Archieven een echte ingang heeft.
	if OS.is_debug_build() and InputMap.has_action("debug_puzzle") and Input.is_action_just_pressed("debug_puzzle"):
		if not GameState.in_battle and not GameState.changing_map and not player.is_moving \
				and not Dialog.is_open and not menu_open() and not Story.running:
			player.input_locked = true
			GameState.change_map(DEBUG_PUZZLE_ROOM, "ingang")
	# F2 = forceer een gevecht (alleen in debug-builds en alleen op maps met monsters).
	if OS.is_debug_build() and encounters and Input.is_action_just_pressed("debug_battle"):
		if not GameState.in_battle and not GameState.changing_map and not player.is_moving and not Dialog.is_open:
			start_battle(GameState.pick_encounter_group(terrain_at(player.get_tile())))


## Terrein-naam van een tile ("" als er niets ligt).
func terrain_at(tile: Vector2i) -> String:
	var data := ground.get_cell_tile_data(tile)
	if data == null:
		return ""
	return str(data.get_custom_data("terrain"))


func get_spawn(spawn_name: String) -> Node2D:
	return get_node_or_null("Spawns/" + spawn_name) as Node2D


func _on_player_stepped(tile: Vector2i) -> void:
	# 1) Uitgang? (gaat altijd voor op een gevecht)
	for exit in $Exits.get_children():
		if exit.contains(tile):
			_use_exit(exit)
			return
	# 2) Random encounter (alleen als deze map monsters heeft)
	if encounters and GameState.on_player_step(terrain_at(tile)):
		start_battle(GameState.pick_encounter_group(terrain_at(tile)))


func _use_exit(exit: Node) -> void:
	if "event" in exit and exit.event != "" and Story.trigger(exit.event, exit):
		return
	# v0.13: doel-scène bestaat (nog) niet maar er is tekst -> alleen het bericht
	# (bv. 'Wilgendal (komt later)' tot scenes/maps/dorp_wilgendal.tscn er is)
	if exit.target_map != "" and not exit.lines.is_empty() and not ResourceLoader.exists(exit.target_map):
		Dialog.show_lines(exit.lines, "")
	elif exit.target_map != "":
		player.input_locked = true
		GameState.change_map(exit.target_map, exit.target_spawn)
	elif not exit.lines.is_empty():
		Dialog.show_lines(exit.lines, "")


func start_battle(enemy_ids: Array, boss := false) -> void:
	player.input_locked = true
	var tile: Vector2i = player.get_tile()
	GameState.start_battle(enemy_ids, tile, player.facing, terrain_at(tile), boss)


## Baasgevecht (encounter-groep met "boss": true in game_data.gd).
func start_boss_battle() -> void:
	var g := GameState.boss_group()
	if not g.is_empty():
		start_battle(g["enemies"].duplicate(), true)
