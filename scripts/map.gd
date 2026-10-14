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
const WarperAccent := preload("res://world_warper/art/accent.gd")
const FieldFollowerScript := preload("res://scripts/field_follower.gd")
const WorldmapCutsceneScript := preload("res://scripts/worldmap_cutscene.gd")
const GardenCreaturesScript := preload("res://scripts/village/garden_creatures.gd")
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
const BerggrotHaak := preload("res://scripts/data/berggrot_data.gd")
## v0.11 Automatisch opslaan na binnenkomst: net na de fade-in (Transition, 0,3 sec).
const AUTOSAVE_DELAY := 0.35

## Naam van de map (alleen informatief).
@export var map_name := ""
## BGM-sleutel uit res://assets/audio/audio_manifest.json, bijvoorbeeld "wereld".
## Leeg: deze map heeft geen eigen muziek en een nog spelende track stopt.
@export var music_track := ""
## Kunnen hier monsters verschijnen? In dorpen staat dit UIT.
@export var encounters := true
## v0.19: zet binnenkomen hier het kamer-checkpoint (respawn na game over)? Baaskamers: nee.
@export var sets_checkpoint := true
## v0.19: na een respawn het bericht 'Je ontwaakt...' pas na de autosave (die wacht niet op tekstvakken).
const RESPAWN_MSG_DELAY := 0.5
## TIJDELIJK (puzzels): F4 in debug-builds gaat hierheen.
const DEBUG_PUZZLE_ROOM := "res://scenes/maps/archief_test.tscn"

@onready var ground: TileMapLayer = $Ground
@onready var player: CharacterBody2D = $Objects/Player


func _ready() -> void:
	GameState.enter_map(scene_file_path)
	# SoM-stijl per gebied (scripts/data/kaart_stijl.gd); in de oude stijl verandert er niets.
	KaartStijl.toepassen(self)
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

	_spawn_follower()
	# v0.21 World Warper-art: accent per Archief (world_warper/art/accent.gd), na de opbouw van de kamer
	if scene_file_path.begins_with("res://world_warper/"):
		call_deferred("_warper_accent")
	# v0.19 kamer-checkpoint: waar je deze map binnenkwam (zie GameState.checkpoint)
	_update_checkpoint()
	player.stepped.connect(_on_player_stepped)
	player.bumped.connect(_on_player_bumped)
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
	# v0.19 net ontwaakt na een game over: kort bericht (verteller), NA de autosave
	if not GameState.pending_respawn_msg.is_empty():
		var lines: Array = GameState.pending_respawn_msg
		GameState.pending_respawn_msg = []
		get_tree().create_timer(RESPAWN_MSG_DELAY).timeout.connect(_show_respawn_msg.bind(lines))
	# v0.16 KERNKRACHT: vuurbal in het veld (knop KERN / toets K), zie scripts/kern/kern_kracht_veld.gd
	add_child(load("res://scripts/kern/kern_kracht_veld.gd").new())
	# v0.11: verhaal (tint, wie er staat, cutscenes bij binnenkomst / na een gevecht)
	Story.map_ready(self)
	# v0.15 net een baaskern geabsorbeerd? Dan nu het absorptie-moment (scripts/kern/).
	if GameState.pending_kern_absorb != "":
		var ka: Node2D = load("res://scripts/kern/kern_absorption.gd").new()
		add_child(ka)
		ka.start(self, GameState.pending_kern_absorb)
	_play_map_music()
	# Eenmalig filmpje bij de eerste keer op de wereldkaart (vlag in de save), zie worldmap_cutscene.gd
	if WorldmapCutsceneScript.should_play(scene_file_path):
		WorldmapCutsceneScript.start_on(self)
	_spawn_garden_creatures()
	# (de autotest wordt sinds v0.10 door GameState gestart, zie game_state.gd)


## Start de BGM van deze map. Zonder sleutel stopt een track die nog speelde
## (dorp en kerker blijven stil tot ze een eigen track krijgen), behalve het
## huis van de wachter en Wilgendal: die spelen "wachtershuis". Ontbreekt het
## ogg-bestand, dan blijft het stil: play_music geeft false en crasht niet.
func _play_map_music() -> void:
	var track := _resolved_music_track()
	if track == "":
		AudioManager.stop_music()
		return
	AudioManager.play_music(track)


func _resolved_music_track() -> String:
	if music_track != "":
		return music_track
	var path := scene_file_path
	if path.ends_with("/huis_wilgendal.tscn") or path.ends_with("/wilgendal.tscn"):
		return "wachtershuis"
	return ""


## v0.19 Kamer-checkpoint bijwerken bij binnenkomst: via een uitgang/mapwissel, na laden (tenzij
## de save al een checkpoint op DEZE map had: dan blijft dat, met de voortgang van toen) of als de
## scène zomaar geladen werd. NIET na een gevecht of een respawn, en niet in een baaskamer.
func _update_checkpoint() -> void:
	var kind := GameState.entry_kind
	GameState.entry_kind = ""
	if kind == "battle" or kind == "respawn":
		return
	if kind == "load" and str(GameState.checkpoint.get("map", "")) == scene_file_path:
		return
	if not allows_checkpoint():
		return
	GameState.set_checkpoint(scene_file_path, player.get_tile(), player.facing)


## v0.19: mag deze map het checkpoint zetten? (DungeonRoom: niet in een baaskamer)
func allows_checkpoint() -> bool:
	return sets_checkpoint


func _show_respawn_msg(lines: Array) -> void:
	if not is_inside_tree() or GameState.in_battle or GameState.changing_map:
		return
	Dialog.show_lines(lines, "")


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


## Actieve Codex-bondgenoot achter de speler (kerkers + wereldkaart, niet in dorpen).
func _spawn_follower() -> void:
	if player == null or not FieldFollowerScript.allowed(scene_file_path):
		return
	var objects := get_node_or_null("Objects")
	if objects == null:
		return
	var follower := FieldFollowerScript.new()
	follower.name = "CodexFollower"
	objects.add_child(follower)
	follower.setup(player)


## Moswezens in de tuin van opa (alleen wilgendal.tscn), zie scripts/village/garden_creatures.gd
func _spawn_garden_creatures() -> void:
	if not GardenCreaturesScript.applies_to(scene_file_path):
		return
	var objects := get_node_or_null("Objects")
	if objects == null or player == null:
		return
	var g := GardenCreaturesScript.new()
	g.name = "GardenCreatures"
	objects.add_child(g)
	g.setup(player, get_node_or_null("Exits/NaarWereld"))


var _run_drawn := false


func _process(_delta: float) -> void:
	# MENU-knop verbergen zolang er een tekstvak of menu open is (anders valt hij erover)
	var touch := get_node_or_null("TouchControls/Control")
	if touch and "show_menu" in touch:
		var want: bool = not Dialog.is_open and not menu_open() and not Story.running
		if touch.show_menu != want:
			touch.show_menu = want
		if "show_run" in touch:
			if touch.show_run != want:
				touch.show_run = want
			elif want and touch.run_on() != _run_drawn:
				touch.queue_redraw()
			_run_drawn = touch.run_on()
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


## Grotmond in de bergwand: de bergtegel blijft blokkeren, maar wie er van onderaf
## tegenaan loopt, gaat de berggrot in (Dennis 2026-10-13, tegel 21,17).
func _on_player_bumped(tile: Vector2i) -> void:
	if GameState.changing_map or GameState.in_battle or Dialog.is_open:
		return
	# Wereldkaart: NaarBouwplaats in de bergtegel. Bouwplaats: NaarBerggrot (de tunnel zelf).
	for naam in ["NaarBouwplaats", "NaarBerggrot"]:
		var grot := get_node_or_null("Exits/" + naam)
		if grot != null and grot.contains(tile) and player.facing == Vector2i.UP:
			_use_exit(grot)
			return


func _use_exit(exit: Node) -> void:
	if str(exit.name) == "NaarBerggrot":
		# Bouwplaats: de tunnel is dicht tot noor_lid (event bouwplaats_hek).
		if "event" in exit and exit.event != "" and Story.trigger(exit.event, exit):
			return
		player.input_locked = true
		BerggrotHaak.start()
		return
	if "event" in exit and exit.event != "" and Story.trigger(exit.event, exit):
		return
	# v0.13: doel-scène bestaat (nog) niet maar er is tekst -> alleen het bericht
	# (bv. 'Wilgendal (komt later)' tot scenes/maps/dorp_wilgendal.tscn er is)
	if exit.target_map != "" and not exit.lines.is_empty() and not ResourceLoader.exists(exit.target_map):
		Dialog.show_lines(exit.lines, "")
	elif exit.target_map != "":
		if EchoGrot.blokkeert_wereldkaart(scene_file_path, str(exit.target_map)):
			Dialog.show_lines([EchoGrot.ZIN_WERELD], "")
			return
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


## v0.21: Warper-art op het accent van het huidige Archief (grijs = Archief 1).
func _warper_accent() -> void:
	if is_inside_tree():
		WarperAccent.apply_to(self, WarperAccent.current())
