extends Node
## ALLEEN VOOR TESTEN - v0.13 eerste dungeon (De Vergeten Archieven, ingangskamer) en de
## zichtbare MAP-MONSTERS (Lufia 2-stijl), plus de titel-art.
## Start:  godot --path . -- --dungeontest [--shots=/pad/map]
##   Deel A: data (dungeon_rooms.gd: elke vijand een monster, de Golem stil, geldige tiles,
##           art-bestanden, handwerk.txt).
##   Deel B: echte scènes met gesimuleerde toetsen: wereldkaart -> trap -> kamer, tegels en
##           botsing, savepunt (HP/MP vol + opslaan), geen random encounters, monsters lopen
##           (en staan stil bij een tekstvak), blokkeren, aanraken -> gevecht (speler loopt ertegen
##           / monster loopt tegen speler), winst = weg, vluchten = blijft + knipperen 1,5 s,
##           de Golem (stil, aanraken of A = baasgevecht), opnieuw binnen = alles terug.
## Deel W (v0.13): wereldkaart met Wachtershuis + Wilgendal (RPG ART), buiten-art bij het Wachtershuis.
## Met --shots=map: v13_title.png, v13_worldmap.png, v13_worldmap_wilgendal.png, v13_buiten.png,
## v13_buiten_nacht.png, v13_dungeon_entrance.png, v13_symbol_battle.png, v13_golem_battle.png,
## v13_mech_wachter_battle.png
## (384x216 x3; het gevecht 768x432 x1,5 + een _2x-versie). Zit niet in de export.

const DR := preload("res://scripts/data/dungeon_rooms.gd")
const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const Winkels := preload("res://scripts/data/wilgendal_winkels.gd")
const Shop := preload("res://scripts/data/shop_data.gd")
const Follower := preload("res://scripts/field_follower.gd")
const ROOM_SCENE := "res://scenes/maps/archief_ingang.tscn"
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const U := Vector2i.UP
const D := Vector2i.DOWN
const L := Vector2i.LEFT
const R := Vector2i.RIGHT
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}

var failures := 0
var passes := 0
var shots := ""
var v16_dir := ""     # v0.16: --v16-shots=map -> v16_<naam>.png op 1024x576


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--v16-shots="):
			v16_dir = arg.get_slice("=", 1)
	seed(1313)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	print("=== Deel A: data ===")
	_data_tests()
	print("=== Deel B: titel ===")
	await _title_shot()
	print("=== Deel W: wereldkaart (Wachtershuis + Willowdale) en buiten bij het Wachtershuis ===")
	await _world_and_outdoor_tests()
	print("=== Deel C: wereldkaart + dungeon ===")
	await _dungeon_tests()
	print("=== Deel G: v0.16 glitch alleen in de Archives, sterker bij de baas ===")
	await _glitch_tests()
	print("DUNGEONTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


# ================================================================ deel A
func _data_tests() -> void:
	# v0.13 (ACT1_LORE.md): de Wachter/Oude Man kent de namen van de andere twee helden NIET.
	# Geen enkele tekstregel in de spel-data (cutscenes + NPC-teksten in de kaarten) noemt Noor/Lotte.
	var named: Array = []
	var files: Array = ["res://scripts/data/story_data.gd"]
	# v0.17: Esdoorn en het Donker Woud (na de Wachter: daar stelt Noor zich zelf voor) tellen niet mee
	for f in DirAccess.get_files_at("res://scenes/maps"):
		if f.ends_with(".tscn") and not f.begins_with("esdoorn") and not f.begins_with("woud_"):
			files.append("res://scenes/maps/" + f)
	for path in files:
		var txt := FileAccess.get_file_as_string(path)
		var n := 0
		for line in txt.split("\n"):
			n += 1
			if path.ends_with("story_data.gd") and "v0.17 ESDOORN + DONKER WOUD" in line:
				break
			var code := line.get_slice("#", 0) if path.ends_with(".gd") else line
			if ("\"say\"" in code or "lines = " in code) and (code.contains("Noor") or code.contains("Lotte")):
				named.append("%s:%d" % [path.get_file(), n])
	check("Warden/Oude Man noemt Noor en Lotte nergens bij naam (%s)" % [named], named.is_empty())
	var mw: Dictionary = GD.ENEMIES.get("mech_wachter", {})
	var kb: Dictionary = GD.ENEMIES["kennis_beest"]
	var small := ["mosslijm", "moskonijn", "papiergeest", "glitchmot"]
	check("Mechanische Warden: nieuwe vijand, stats tussen de kleine Archief-vijanden en de Golem",
			not mw.is_empty() and small.all(func(e): return int(GD.ENEMIES[e]["max_hp"]) < int(mw["max_hp"]))
			and int(mw["max_hp"]) < int(kb["max_hp"]) and int(mw["atk"]) < int(kb["atk"])
			and ResourceLoader.exists(mw["sprite"]) and ResourceLoader.exists(mw["idle"]))
	check("Mechanische Warden in de Archief-groepen (terrein 'archief', niet op de wereldkaart)",
			GD.ENCOUNTER_GROUPS.any(func(g): return g["enemies"] == ["mech_wachter"] and g.get("terrains", []) == ["archief"]))
	for f in ["wachter_liggend.png", "wachter_knielend.png"]:
		check("verslagen Oude Man klaar voor later: assets/characters/" + f, ResourceLoader.exists("res://assets/characters/" + f))
	_archief_data_tests()
	# art
	var tiles: Texture2D = load(DR.TILES)
	check("dungeon_tiles_v14.png 256x80 (RPG ART, + tegel 64 onderrand-doorgang)", tiles != null and tiles.get_size() == Vector2(256, 80))
	var lt: Texture2D = load(DR.LIB_TILES)
	check("bibliotheek_tiles.png 256x64 (RPG ART)", lt != null and lt.get_size() == Vector2(256, 64))
	_theme_tests(hw_text())
	for id in ["mosslijm", "moskonijn"]:
		var tex: Texture2D = load("res://assets/map_monsters/%s.png" % id)
		check("map-sprite %s.png 32x64 (2 frames x 4 richtingen)" % id, tex != null and tex.get_size() == Vector2(32, 64))
	var gt: Texture2D = load("res://assets/map_monsters/golem.png")
	check("golem.png 64x32 (2 frames 32x32)", gt != null and gt.get_size() == Vector2(64, 32))
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	var new_art := ["assets/tiles/dungeon/dungeon_tiles_v14.png", "assets/tiles/dungeon/bibliotheek_tiles.png",
			"assets/sprites/savepunt_bibliotheek.png", "assets/puzzle/geheime_deur_archief.png", "assets/puzzle/drukplaat_rune.png",
			"assets/puzzle/kast_vast.png", "assets/sprites/dungeon/schatkist.png", "assets/sprites/dungeon/staande_kast.png",
			"assets/sprites/dungeon/kandelaar.png", "assets/sprites/dungeon/leestafel.png", "assets/sprites/dungeon/golemdeur.png",
			"assets/sprites/dungeon/onderrand_doorgang.png", "assets/ui/icons/vonkzwaard.png", "assets/ui/icons/zwaard_cyaan.png"]
	var miss_art := new_art.filter(func(f): return not (f in hw) or not ResourceLoader.exists("res://" + f))
	check("v0.14 art van RPG ART in het project en in handwerk.txt (mist: %s)" % [miss_art], miss_art.is_empty())
	check("dungeon-art staat in tools/handwerk.txt", "assets/tiles/dungeon/dungeon_tiles.png" in hw
			and "assets/map_monsters/mosslijm.png" in hw and "assets/map_monsters/moskonijn.png" in hw
			and "assets/map_monsters/golem.png" in hw)
	var ph := []
	for e in GD.ENEMIES:
		# v0.19: "art_pending" (Inktwurm) = map_monster.gd tekent tijdelijk zijn eigen plaatsvervanger
		if not ResourceLoader.exists("res://assets/map_monsters/%s.png" % e) and not bool(GD.ENEMIES[e].get("art_pending", false)):
			ph.append(e)
	check("elke vijand heeft een map-plaatje (echt of placeholder-PNG); zonder: %s" % [ph], ph.is_empty())


# ================================================================ helpers
func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func tile() -> Vector2i:
	var p := player()
	return p.get_tile() if p else Vector2i(-99, -99)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func walk(action: String, n: int) -> void:
	var start_scene := scene()
	for i in n:
		var p := player()
		if p == null or scene() != start_scene or GameState.changing_map or GameState.in_battle:
			return
		Input.action_press(action)
		var waited := 0
		while is_instance_valid(p) and not p.is_moving and waited < 6:
			await get_tree().physics_frame
			waited += 1
		Input.action_release(action)
		while is_instance_valid(p) and p.is_moving:
			await get_tree().physics_frame
		if GameState.changing_map or Dialog.is_open or GameState.in_battle:
			return


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func press_interact() -> void:
	# eerst op een beeld-begin wachten: na een timer-await zou 'just pressed' anders al
	# voorbij zijn voordat de speler (in _process) kijkt
	await get_tree().process_frame
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		if not Dialog.is_open:
			return
		if Dialog._is_typing():
			await frames(2)
			continue
		if Dialog.has_choices():
			return
		await press_interact()


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	var path := shots.path_join(name + ".png")
	var base := img.get_width()
	if base > 600:      # gevecht: fijn raster 768x432 -> 1152x648 + scherpe 2x-versie
		var crisp := img.duplicate()
		crisp.resize(base * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crisp.save_png(path.get_basename() + "_2x.png")
		img.resize(base * 3 / 2, img.get_height() * 3 / 2, Image.INTERPOLATE_NEAREST)
	else:
		img.resize(base * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("INFO  screenshot: ", path, " ", img.get_size())


## v0.16 Screenshot op 1024x576 (eerst heel-getal nearest, dan Lanczos) naar v16_dir/v16_<naam>.png.
func v16_shot(name: String) -> void:
	if v16_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var f := maxi(1, int(1024 / img.get_width()))
	if f > 1:
		img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	img.resize(1024, 576, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(v16_dir)
	var path := v16_dir.path_join("v16_%s.png" % name)
	img.save_png(path)
	print("INFO  v16-screenshot: ", path, " ", img.get_size())


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 3:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


## Winnen zoals een speler (Aanval op de eerste vijand), met de vijanden op 1 HP gezet.
func win_battle() -> void:
	Engine.time_scale = 3.0
	for guard in 60:
		var st := await wait_battle_state(["command", "target_enemy", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "command":
			for e in b.enemies:
				e["s"]["hp"] = mini(int(e["s"]["hp"]), 1)
			await cross_to(b, 0)
			await tap("interact")
		else:
			await tap("interact")
	Engine.time_scale = 1.0


## Vluchten zoals een speler (D-pad naar 'Vluchten' + A), berichten doorklikken.
func flee_battle() -> void:
	Engine.time_scale = 3.0
	for guard in 60:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "command":
			await cross_to(b, 4)
			await tap("interact")
		else:
			await tap("interact")
	Engine.time_scale = 1.0


func room() -> Node:
	var s := scene()
	return s if s != null and s.name == "ArchiefIngang" else null


## Monsters op vaste plekken en stil (voor de gecontroleerde tests).
func park(r: Node, spots: Dictionary) -> void:
	for m in r.monsters:
		m.moves = false
		if m.is_moving:
			m.place_at(m.target_tile, m.facing)
		if spots.has(m.monster_id):
			m.place_at(spots[m.monster_id], D)


func positions(r: Node) -> Dictionary:
	var out := {}
	for m in r.monsters:
		out[m.monster_id] = m.tile
	return out


# ================================================================ deel B: titel
func _title_shot() -> void:
	check("titelscherm bij de start", await wait_scene("Title"))
	# met een save, zodat 'Doorgaan' + de save-info in het menu staan
	GameState.new_game("Dennis")
	GameState.current_map = ROOM_SCENE
	GameState.save_game(Vector2i(9, 10), U)
	get_tree().change_scene_to_file(GameState.TITLE_SCENE)
	await pframes(3)
	check("titel opnieuw (met save)", await wait_scene("Title"))
	var t := scene()
	await wait_fade()
	check("Doorgaan aan met save-info (%s)" % t.save_info.text, not t.continue_button.disabled and t.save_info.visible
			and "Dennis" in t.save_info.text)
	var st: Rect2 = t.stage.get_global_rect()
	var cr: Rect2 = t.card.get_global_rect()
	cr.position -= st.position
	check("menu rechtsonder in de stage (x 240..372, y 150..200): %s" % cr,
			absf(cr.position.x - 240.0) <= 1.0 and absf(cr.end.x - 372.0) <= 1.0 and cr.end.y <= 201.0 and cr.position.y >= 148.0)
	var br: Rect2 = t.beta_card.get_global_rect()
	br.position -= st.position
	check("Betatest links onder, los van het menu (%s)" % br, t.beta_button != null and not t.beta_button.disabled
			and "Betatest" in str(t.beta_button.get_meta("label", "")) and br.end.x <= cr.position.x
			and br.position.x >= 0.0 and br.end.y <= 201.0 and br.position.y >= 140.0)
	if t.glitch == null:
		check("hoofdpagina title_main.png, menu onder de titel, Nearest",
				t.background.texture.resource_path.ends_with("title_main.png")
				and t.logo == null and t.kern == null and t.subtitle_art == null
				and t.background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				and cr.position.y >= 140.0)
		await pframes(30)
		await screenshot("v13_title")
	else:
		# menu niet over de held (links onder, x < 200) en niet over de Golem/kern (midden boven)
		var kern: Rect2 = Rect2(t.kern.position, t.kern.size)
		check("menu raakt logo, ondertitel en kern niet", not cr.intersects(Rect2(88, 10, 208, 36))
				and not cr.intersects(Rect2(t.subtitle_art.position, t.subtitle_art.size)) and not cr.intersects(kern))
		check("logo/ondertitel/kern/achtergrond: Nearest", t.background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				and t.logo.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and t.kern.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		check("kern-fps 6..8, glitch 12..15 fps elke 3..5 s", t.KERN_FPS >= 6.0 and t.KERN_FPS <= 8.0
				and t.glitch.STRIP_FPS >= 12.0 and t.glitch.STRIP_FPS <= 15.0 and t.glitch.STRIP_GAP_MIN >= 3.0 and t.glitch.STRIP_GAP_MAX <= 5.0)
		check("eerste logo-glitch ook pas na 3..5 s (%.2f)" % t.glitch._wait, t.glitch._wait >= 2.5 and t.glitch._wait <= 5.0)
		await pframes(30)
		# schoon logo (frame 0) op de foto
		await wait_until(func(): return not t.glitch.is_glitching() and t.glitch.strip_frame == 0, 3.0)
		await screenshot("v13_title")
	# lange naam + autosave: het menu blijft even breed en in beeld (tekst wordt afgekapt)
	var w0: float = t.card.size.x
	t.save_info.text = "  Maximiliaan  12:34:56 (auto)"
	t._place_card()
	await pframes(2)
	var cr2: Rect2 = t.card.get_global_rect()
	check("titel: lange save-info (autosave) maakt het menu niet breder, blijft in beeld (%s)" % cr2,
			is_equal_approx(t.card.size.x, w0) and cr2.end.x <= t.size.x and t.save_info.clip_text)
	t.refresh()
	for p in [GameState.save_path, GameState.autosave_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# ================================================================ deel W: wereldkaart + buiten
const TOWN_SCENE := "res://scenes/maps/wilgendal.tscn"
const VILLAGE_SCENE := "res://scenes/maps/dorp_wilgendal.tscn"


## Loopbaar op de wereldkaart (geen berg/zee) - voor de route-checks.
func _world_walkable(g: TileMapLayer, t: Vector2i) -> bool:
	var td := g.get_cell_tile_data(t)
	return td != null and not (str(td.get_custom_data("terrain")) in ["berg", "zee"])


func _world_reachable(g: TileMapLayer, from: Vector2i, to: Vector2i) -> int:
	var dist := {from: 0}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == to:
			return dist[t]
		for d in [U, D, L, R]:
			var n: Vector2i = t + d
			if not dist.has(n) and _world_walkable(g, n):
				dist[n] = dist[t] + 1
				todo.append(n)
	return -1


func _world_and_outdoor_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	GameState.change_map(WORLD_SCENE, "van_dorp")
	check("W: wereldkaart geladen (van_dorp)", await wait_scene("Wereldkaart"))
	await wait_fade()
	var g: TileMapLayer = scene().get_node("Ground")
	var atlas_ok: bool = str(g.tile_set.get_source(0).texture.resource_path).ends_with("wereld_v14.png")
	check("W: atlas = wereld_v14.png (wereld.png + nieuwe iconen van RPG ART), 138 tegels",
			atlas_ok and g.tile_set.get_source(0).get_tiles_count() == 138)
	check("W: Wachtershuis-icoon op (14,30)-(15,30) = tegels #132/#133 (4,8)/(5,8), terrein stad",
			g.get_cell_atlas_coords(Vector2i(14, 30)) == Vector2i(4, 8) and g.get_cell_atlas_coords(Vector2i(15, 30)) == Vector2i(5, 8)
			and str(g.get_cell_tile_data(Vector2i(14, 30)).get_custom_data("terrain")) == "stad")
	var vil_ok := true
	var want := {Vector2i(30, 23): Vector2i(6, 8), Vector2i(31, 23): Vector2i(7, 8), Vector2i(30, 24): Vector2i(8, 8), Vector2i(31, 24): Vector2i(9, 8)}
	for t in want:
		var td := g.get_cell_tile_data(t)
		vil_ok = vil_ok and g.get_cell_atlas_coords(t) == want[t] and td != null and str(td.get_custom_data("terrain")) == "stad" \
				and td.get_collision_polygons_count(0) == 0
	check("W: Willowdale-icoon 2x2 op (30,23)-(31,24) = #134-#137, stad, loopbaar", vil_ok)
	var ex_house: Node = scene().get_node_or_null("Exits/NaarWachtershuis")
	var ex_vil: Node = scene().get_node_or_null("Exits/NaarWilgendal")
	check("W: uitgang NaarWachtershuis (oude stad) -> wilgendal.tscn 'zuid_ingang'", ex_house != null
			and ex_house.tile_rect() == Rect2i(14, 30, 2, 1) and ex_house.target_map == TOWN_SCENE and ex_house.target_spawn == "zuid_ingang")
	check("W: uitgang NaarWilgendal (30,23) 2x2 -> dorp_wilgendal.tscn, zonder later-tekst", ex_vil != null
			and ex_vil.tile_rect() == Rect2i(30, 23, 2, 2) and ex_vil.target_map == VILLAGE_SCENE and ex_vil.lines.is_empty()
			and ResourceLoader.exists(VILLAGE_SCENE))
	var sp: Node = scene().get_node_or_null("Spawns/van_wilgendal")
	check("W: spawn van_wilgendal op (30,25), kijkt omlaag", sp != null and Vector2i((sp.position / 16.0).floor()) == Vector2i(30, 25))
	var to_vil := _world_reachable(g, Vector2i(14, 31), Vector2i(30, 25))
	var to_trap := _world_reachable(g, Vector2i(14, 31), Vector2i(20, 34))
	check("W: lopend bereikbaar: Wachtershuis -> Willowdale (%d stappen) en -> de trap/Archives (%d)" % [to_vil, to_trap],
			to_vil > 0 and to_trap > 0)
	# bij Wilgendal: 'komt later' (zolang de dorpsscène er niet is), blijft op de wereldkaart
	GameState.change_map(WORLD_SCENE, "van_wilgendal")
	await wait_scene("Wereldkaart")
	await wait_fade()
	await pframes(5)
	check("W: terug-spawn van_wilgendal (30,25): %s" % tile(), tile() == Vector2i(30, 25))
	await walk("move_up", 1)
	check("W: op Willowdale: dorp geladen (node DorpWilgendal)", await wait_scene("DorpWilgendal"))
	await wait_fade()
	await _wilgendal_winkel_tests()
	GameState.change_map(WORLD_SCENE, "van_wilgendal")
	check("W: terug op de wereldkaart na Wilgendal", await wait_scene("Wereldkaart"))
	await wait_fade()
	# overzicht met beide iconen in beeld
	player().place_at(Vector2i(23, 29), D)
	await pframes(20)
	await screenshot("v13_worldmap_wilgendal")
	# het Wachtershuis: oude stad-uitgang werkt nog
	player().place_at(Vector2i(14, 31), U)
	await pframes(3)
	await walk("move_up", 1)
	check("W: Wachtershuis-icoon -> 'Huis aan de bosrand' (Willowdale-scène)", await wait_scene("Wilgendal"))
	await wait_fade()
	await _outdoor_tests()


func _wilgendal_winkel_tests() -> void:
	var dorp := scene()
	check("W: vier shopkeepers niet meer los op het plein", dorp.get_node_or_null("Objects/JelleWapen") == null
			and dorp.get_node_or_null("Objects/JellePantser") == null
			and dorp.get_node_or_null("Objects/Magie") == null
			and dorp.get_node_or_null("Objects/Accessoire") == null)
	var mien: Node = dorp.get_node_or_null("Objects/TanteMien")
	var gerrit: Node = dorp.get_node_or_null("Objects/Gerrit")
	check("W: Tante Mien blijft kruiden verkopen, Gerrit en de molen blijven", mien != null
			and mien.event == "shop" and mien.event_arg == "wilgendal_kruiden"
			and gerrit != null and gerrit.event == "gerrit"
			and dorp.get_node_or_null("Objects/MolenWieken") != null)
	var grond: TileMapLayer = dorp.get_node("Ground")
	var gebouwen: TileMapLayer = dorp.get_node("Gebouwen")
	var huisjes := 0
	for cel in gebouwen.get_used_cells():
		if gebouwen.get_cell_source_id(cel) == 1:
			huisjes += 1
	check("W: plein is dorpsschaal, vier panden van 5x5", grond.get_used_rect().size == Vector2i(Winkels.W, Winkels.H)
			and huisjes == Winkels.HUIS * Winkels.HUIS * Winkels.WINKELS.size())
	var wereld: Node = dorp.get_node("Exits/NaarWereld")
	check("W: zuid uit Wilgendal terug naar de wereldkaart", wereld.target_map == WORLD_SCENE
			and wereld.target_spawn == "van_wilgendal" and wereld.tile_rect() == Rect2i(9, 15, 3, 1))
	var borden: Array = []
	for kind in dorp.get_node("Objects").get_children():
		var naam := str(kind.name).to_lower()
		if naam.contains("bord") or naam.contains("sign") or naam.contains("uithang"):
			borden.append(kind.name)
	check("W: geen uithangborden", borden.is_empty())
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	var ph := FileAccess.get_file_as_string("res://tools/placeholders_v17.txt")
	check("W: winkel-art is placeholder, niet in handwerk", not hw.contains("assets/sprites/wilgendal/")
			and ph.contains("assets/sprites/wilgendal/wapen_toonbank.png"))
	var kleuren: Dictionary = {}
	for id in Winkels.WINKELS:
		var info: Dictionary = Winkels.WINKELS[id]
		var deur: Node = dorp.get_node_or_null("Objects/" + str(info["deur_node"]))
		var voor: Vector2i = Winkels.voor_deur(id)
		var deur_ok: bool = deur != null and deur.lines.is_empty() and str(deur.event) == "" \
				and deur.target_map == str(info["scene"]) and deur.target_spawn == "binnen"
		check("W: deur %s altijd open naar het pand" % id, deur_ok)
		if deur != null:
			check("W: deur %s staat in de gevel" % id, Vector2i((deur.position / 16.0).floor()) == Winkels.deur_tegel(id))
		check("W: pad van de zuidingang naar %s" % id, _plein_bereik(dorp, Winkels.ZUID, voor)
				and _plein_vrij(dorp, voor) and not _plein_vrij(dorp, Winkels.deur_tegel(id)))
		var spawn: Node = dorp.get_node_or_null("Spawns/" + str(info["spawn_buiten"]))
		check("W: spawn voor %s" % id, spawn != null and spawn.get_tile() == voor and spawn.facing == U)
		for sleutel in ["keeper_art", "toonbank_art", "display_art"]:
			var pad := str(info[sleutel])
			var tex := load(pad) as Texture2D
			var plaat: Image = null
			if tex != null:
				plaat = tex.get_image()
			var hoek := Color.BLACK
			if plaat != null:
				hoek = plaat.get_pixel(0, 0)
			var maat := Vector2i(48, 96) if sleutel == "keeper_art" else (Vector2i(48, 16) if sleutel == "toonbank_art" else Vector2i(32, 32))
			check("W: placeholder %s" % pad.get_file(), tex != null and tex.get_width() == maat.x and tex.get_height() == maat.y
					and hoek.r > 0.95 and hoek.g < 0.05 and hoek.b > 0.95 and ph.contains(pad.trim_prefix("res://")))
		var toon: Image = (load(str(info["toonbank_art"])) as Texture2D).get_image()
		kleuren[id] = toon.get_pixel(24, 8)
		check("W: volger loopt de winkel %s niet in" % id, not Follower.allowed(str(info["scene"])))
	check("W: vier toonbanken zien er anders uit", kleuren["wapen"] != kleuren["pantser"]
			and kleuren["wapen"] != kleuren["accessoire"] and kleuren["wapen"] != kleuren["magie"]
			and kleuren["pantser"] != kleuren["accessoire"] and kleuren["pantser"] != kleuren["magie"]
			and kleuren["accessoire"] != kleuren["magie"])
	check("W: plein en Gerrit zijn te belopen", _plein_bereik(dorp, Winkels.ZUID, Winkels.GERRIT + Vector2i.DOWN)
			and _plein_bereik(dorp, Winkels.ZUID, Winkels.MIEN) and _plein_bereik(dorp, Winkels.ZUID, Winkels.ZUID + Vector2i.DOWN))
	player().place_at(Vector2i(10, 9), D)
	await pframes(8)
	await screenshot("wilgendal_plein")
	for id in Winkels.WINKELS:
		var info: Dictionary = Winkels.WINKELS[id]
		var winkel := await enter(str(info["scene"]), "binnen")
		if winkel == null:
			check("W: winkel %s laadt" % id, false)
			continue
		check("W: winkel %s heet Nederlands" % id, winkel.map_name == str(info["map_name"]) and winkel.encounters == false)
		var keeper: Node = winkel.get_node_or_null("Objects/" + str(info["keeper"]))
		var bar: Node = winkel.get_node_or_null("Objects/Toonbank")
		var vitrine: Node = winkel.get_node_or_null("Objects/Display")
		var kt := Vector2i((keeper.position / 16.0).floor()) if keeper != null else Vector2i(-1, -1)
		var bt := Vector2i((bar.position / 16.0).floor()) if bar != null else Vector2i(-1, -1)
		check("W: %s staat achter de toonbank" % str(info["keeper_name"]), keeper != null and bar != null and vitrine != null
				and keeper.npc_name == str(info["keeper_name"]) and keeper.event == "shop"
				and keeper.event_arg == str(info["shop_id"]) and keeper.lines.size() == 1 and keeper.lines[0] == str(info["line"])
				and keeper.facing == D and kt == Winkels.KEEPER_TEGEL and bt == Winkels.TOONBANK_TEGEL
				and kt == bt + Vector2i(1, -1)
				and Vector2i((vitrine.position / 16.0).floor()) == Winkels.DISPLAY_TEGEL
				and str(keeper.sheet.resource_path) == str(info["keeper_art"])
				and str(bar.texture.resource_path) == str(info["toonbank_art"])
				and str(vitrine.texture.resource_path) == str(info["display_art"]))
		check("W: binnenkomst %s voor de toonbank" % id, tile() == Winkels.SPAWN_BINNEN and player().facing == U)
		var uit: Node = winkel.get_node("Exits/NaarDorp")
		check("W: deur naar buiten vanuit %s" % id, uit.target_map == Winkels.DORP and uit.target_spawn == str(info["spawn_buiten"])
				and uit.lines.is_empty() and uit.tile_rect() == Rect2i(Winkels.UITGANG_TEGEL, Vector2i.ONE))
		await screenshot("wilgendal_" + id)
		if keeper != null:
			keeper.interact(player())
		await pframes(3)
		var scherm: Node = winkel.get_node_or_null("ShopScreen")
		var rows: Array = Shop.stock(str(info["shop_id"]))
		var knoppen: Dictionary = {}
		if scherm != null:
			for knop in scherm.content.get_children():
				if knop is Button:
					knoppen[str(knop.text)] = true
		var mist: Array = []
		for row in rows:
			var regel := "%s  %dg" % [str(row["name"]), int(row["price"])]
			if not knoppen.has(regel):
				mist.append(regel)
		check("W: %s verkoopt de bestaande voorraad (%s)" % [id, str(mist)], scherm != null
				and scherm.shop_id == str(info["shop_id"]) and scherm.header.text == Shop.shop_name(str(info["shop_id"]))
				and not rows.is_empty() and mist.is_empty())
		if scherm != null:
			scherm.close()
			await pframes(2)
		await walk("move_down", 1)
		check("W: %s terug op het plein voor de deur" % id, await wait_scene("DorpWilgendal") and tile() == Winkels.voor_deur(id))
		await wait_fade()
	player().place_at(Winkels.voor_deur("wapen"), U)
	await pframes(3)
	await walk("move_up", 1)
	check("W: tegen de deur lopen opent de wapenwinkel", await wait_scene("WinkelWapen"))
	await wait_fade()


func _plein_vrij(map: Node, t: Vector2i) -> bool:
	var grond: TileMapLayer = map.get_node("Ground")
	var td := grond.get_cell_tile_data(t)
	if td == null or td.get_collision_polygons_count(0) > 0:
		return false
	var gebouwen: TileMapLayer = map.get_node("Gebouwen")
	var bd := gebouwen.get_cell_tile_data(t)
	return bd == null or bd.get_collision_polygons_count(0) == 0


func _plein_bereik(map: Node, van: Vector2i, naar: Vector2i) -> bool:
	var gezien := {van: true}
	var todo: Array[Vector2i] = [van]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == naar:
			return true
		for d in [U, D, L, R]:
			var n: Vector2i = t + d
			if gezien.has(n) or not _plein_vrij(map, n):
				continue
			gezien[n] = true
			todo.append(n)
	return false


func _outdoor_tests() -> void:
	var sc := scene()
	var arch: Node = sc.get_node("Objects/Archief")
	var well: Node = sc.get_node("Objects/Put")
	var chest: Node = sc.get_node("Objects/Kist")
	check("B: ingang = RPG ART archief_ingang.png (2 frames 48x32), 3x2 tiles op (25,2)", arch.texture.resource_path.ends_with("buiten/archief_ingang.png")
			and arch.hframes == 2 and arch.texture.get_size() == Vector2(96, 32) and arch.tiles == Vector2i(3, 2)
			and Vector2i((arch.position / 16.0).floor()) == Vector2i(25, 2))
	var cs: CollisionShape2D = arch.get_node("CollisionShape2D")
	var sprite_rect := Rect2(arch.sprite.global_position + arch.sprite.offset - Vector2(24, 16), Vector2(48, 32))
	check("B: ingang-plaatje precies op het raster (x 400..448, y 32..64) en botsing = 3x2 (%s)" % sprite_rect,
			sprite_rect == Rect2(400, 32, 48, 32) and (cs.shape as RectangleShape2D).size == Vector2(46, 30)
			and cs.global_position == Vector2(424, 48))
	check("B: nacht -> ingang open + flakkerende gloed (open_flikker, 2 frames)", arch.looping
			and arch.sprite.texture.resource_path.ends_with("archief_ingang_open_flikker.png") and arch.glow.visible)
	check("B: waterput 32x32 = 2x2 tiles, plaatje op het raster", well.texture.resource_path.ends_with("buiten/put.png")
			and well.tiles == Vector2i(2, 2) and (well.get_node("CollisionShape2D").shape as RectangleShape2D).size == Vector2(30, 30)
			and well.sprite.global_position + well.sprite.offset == Vector2(160, 96))
	var seals: Array = sc.get_node("Objects").get_children().filter(func(n): return n.name.begins_with("Zegel") or str(n.get("event")) == "zegel")
	check("B: v0.16 geen zegelstenen meer bij het Wachtershuis (runen-tutorial weg) (%s)" % [seals], seals.is_empty())
	check("B: kist van RPG ART (2 frames 16x16)", chest.texture.resource_path.ends_with("buiten/kist.png") and chest.hframes == 2)
	var ruins: Array = sc.get_node("Objects").get_children().filter(func(n): return n.name.begins_with("Ruine_"))
	check("B: %d ruïne-stukken (ruine.png, 10 stukken) rond de ingang, blokkeren" % ruins.size(), ruins.size() >= 4
			and ruins.all(_ruin_ok))
	# de ingang blijft bereikbaar: van de voordeur naar de open ingang lopen (zoals de autotest)
	player().place_at(Vector2i(20, 6), D)
	await pframes(20)
	await screenshot("v13_buiten_nacht")
	# overdag (taken-stap, ingang nog dicht) voor de echte kleuren
	GameState.story_step = SD.TAKEN
	GameState.change_map(TOWN_SCENE, "voor_huis")
	await wait_scene("Wilgendal")
	await wait_fade()
	await _story_settle()
	sc = scene()
	check("B: overdag: ingang dicht (frame 0)", not sc.get_node("Objects/Archief").looping
			and sc.get_node("Objects/Archief").sprite.frame == 0)
	player().place_at(Vector2i(20, 6), D)
	await pframes(20)
	await screenshot("v13_buiten")
	GameState.story_step = SD.NACHT
	GameState.story_flags = {}


## Rechthoek van een Control in schermpixels (werkt ook voor HD-/CanvasLayer-UI).
func _srect(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


## Rechthoek van een Control in de eenheden van het gevechtsscherm (zoals de autotest).
func _lrect(b: Control, c: Control) -> Rect2:
	return b.get_global_transform().affine_inverse() * c.get_global_rect()


func _ruin_ok(n: Node) -> bool:
	return n.texture.resource_path.ends_with("buiten/ruine.png") and n.hframes == 10 and n.collision_layer == 1 \
			and absf(n.position.x - 424.0) <= 64.0 and n.position.y <= 96.0


func _story_settle() -> void:
	for i in 60:
		if not Story.running and not Dialog.is_open:
			return
		if Dialog.is_open:
			await close_dialog()
		await pframes(2)


# ================================================================ deel C: dungeon
# ================================================================ v0.14 Eerste Archief: data
const PR := preload("res://scripts/data/puzzle_rooms.gd")
const PUZZLE_SCENE := "res://scenes/maps/archief_puzzel.tscn"
const GOLEMHAL_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const LIB_SCENE := "res://scenes/maps/archief_bibliotheek.tscn"
## Vijandsoorten per verdieping (plan par. 6).
const FLOOR_SETS := {
	1: ["glitchmot", "moskonijn", "mosslijm", "papiergeest"],
	2: ["glitchmot", "kennis_beest", "mech_wachter", "papiergeest"],
	3: ["glitchmot", "kennis_beest", "mech_wachter", "papiergeest"],
	4: ["glitchmot", "kennis_beest", "mech_wachter", "papiergeest"],
}


static func node_name_of(path: String) -> String:
	var parts := path.get_file().get_basename().split("_")
	var out := ""
	for p in parts:
		out += p.capitalize().replace(" ", "")
	return out


## Spawnnamen van een kamer-scène.
static func spawns_of(path: String) -> Array:
	if path == PUZZLE_SCENE:
		return ["ingang"] + PR.ROOMS["archief_puzzel"].get("spawns", {}).keys()
	for e in DR.ORDER:
		if e[1] == path:
			return DR.ROOMS[e[0]].get("spawns", {}).keys()
	return []


## Uitgangen van een kamer-scène: [{"key", "map", "spawn", "from", "dir"}] (from = tile ervoor).
static func exits_of(path: String) -> Array:
	var out := []
	if path == PUZZLE_SCENE:
		var pr: Dictionary = PR.ROOMS["archief_puzzel"]
		out.append({"key": "E", "map": pr["entrance"]["map"], "spawn": pr["entrance"]["spawn"], "from": Vector2i(5, 17), "dir": D})
		out.append({"key": "X", "map": pr["exit"]["map"], "spawn": pr["exit"]["spawn"], "from": Vector2i(8, 9), "dir": U})
		return out
	var rid := ""
	for e in DR.ORDER:
		if e[1] == path:
			rid = e[0]
	var room: Dictionary = DR.ROOMS[rid]
	var layout: Array = room["layout"]
	var seen := {}
	for y in layout.size():
		for x in layout[y].length():
			var ch: String = layout[y][x]
			if not DR.EXIT_CHARS.has(ch) or ch == "H":
				continue
			var key: String = DR.EXIT_CHARS[ch]
			if seen.has(key):
				continue
			seen[key] = true
			var from := Vector2i(x, y - 1) if y == layout.size() - 1 else Vector2i(x, y + 1)
			var dir := D if y == layout.size() - 1 else U
			var data: Dictionary = room["exits"].get(key, {})
			out.append({"key": key, "map": data.get("map", ""), "spawn": data.get("spawn", ""), "from": from, "dir": dir})
	return out


func _archief_data_tests() -> void:
	# alle kamers
	check("Eerste Archief: 12 kamer-scènes (11 dungeonkamers + puzzelkamer met schatkamer)", DR.ORDER.size() == 12
			and DR.ORDER.all(func(e): return ResourceLoader.exists(e[1])))
	var bad := []
	for rid in DR.ROOMS:
		var room: Dictionary = DR.ROOMS[rid]
		var lg := DR.legend_of(room)
		var lay: Array = room["layout"]
		for y in lay.size():
			if lay[y].length() != lay[0].length():
				bad.append("%s rij %d" % [rid, y])
			for x in lay[y].length():
				if not lg.has(lay[y][x]):
					bad.append("%s (%d,%d)" % [rid, x, y])
	check("alle kamers: rijen even breed, alle tekens in de legenda (%s)" % [bad], bad.is_empty())
	# monsters op vrije vloer, niet op kist/boek/elkaar
	bad = []
	for rid in DR.ROOMS:
		var room: Dictionary = DR.ROOMS[rid]
		var lg := DR.legend_of(room)
		var lay: Array = room["layout"]
		var taken := {}
		for c in room.get("chests", []) + room.get("books", []):
			taken[Vector2i(int(c["tile"][0]), int(c["tile"][1]))] = true
		for m in room["monsters"]:
			var sz: Array = m.get("size", [1, 1])
			for dx in sz[0]:
				for dy in sz[1]:
					var t := Vector2i(int(m["tile"][0]) + dx, int(m["tile"][1]) + dy)
					var n: int = lg[lay[t.y][t.x]]
					if n in DR.SOLID or taken.has(t) or (m["moves"] and n in DR.NO_MONSTER):
						bad.append("%s/%s" % [rid, m["id"]])
					taken[t] = true
	check("monsters starten op vrije vloer, niet op elkaar/kist/boek (%s)" % [bad], bad.is_empty())
	# verdiepingen: niveau + vijandsoorten
	var fights := 0
	for rid in DR.ROOMS:
		var room: Dictionary = DR.ROOMS[rid]
		var set := {}
		for m in room["monsters"]:
			if m.get("boss", false):
				continue
			fights += 1
			for e in m.get("group", [m["enemy"]]):
				set[e] = true
		var allowed: Array = FLOOR_SETS[int(room["floor"])]
		check("%s: verdieping %d, niveau %d, vijanden %s passen bij de verdieping" % [rid, room["floor"], room["tier"], set.keys()],
				int(room["tier"]) == int(room["floor"]) and set.keys().all(func(e): return allowed.has(e)))
	check("34 gevechten (zonder de Golem): %d" % fights, fights == 34)
	var floor_seen := {1: {}, 2: {}, 3: {}, 4: {}}
	for rid in DR.ROOMS:
		for m in DR.ROOMS[rid]["monsters"]:
			if not m.get("boss", false):
				for e in m.get("group", [m["enemy"]]):
					floor_seen[int(DR.ROOMS[rid]["floor"])][e] = true
	check("elke verdieping heeft precies zijn vijandenset (%s)" % [floor_seen], floor_seen.keys().all(func(f):
			var k: Array = floor_seen[f].keys()
			k.sort()
			return k == FLOOR_SETS[f]))
	# niveau-formule (plan par. 6): mosslijm HP 18 ATK 5 DEF 1 EXP 6
	var ms: Dictionary = GD.ENEMIES["mech_wachter"]
	var t4 := GD.apply_tier(ms, 4)
	var t2 := GD.apply_tier(ms, 2)
	check("niveau 4: HP x2,3, ATK +10, DEF +7, EXP x3 (Mech. Warden %d/%d/%d/%d)" % [t4["max_hp"], t4["atk"], t4["def"], t4["exp"]],
			t4["max_hp"] == GD.round_half_even(ms["max_hp"] * 2.3) and t4["atk"] == ms["atk"] + 10 and t4["def"] == ms["def"] + 7
			and t4["exp"] == ms["exp"] * 3)
	check("niveau 2: HP x1,5, ATK +4, DEF +3, EXP x2,5", t2["max_hp"] == GD.round_half_even(ms["max_hp"] * 1.5)
			and t2["atk"] == ms["atk"] + 4 and t2["def"] == ms["def"] + 3 and t2["exp"] == GD.round_half_even(ms["exp"] * 2.5))
	check("niveau 0 = ongewijzigd; afronden half-even (12,5->12, 13,5->14)", GD.apply_tier(ms, 0) == ms
			and GD.round_half_even(12.5) == 12 and GD.round_half_even(13.5) == 14)
	check("wereldkaart-vijanden ongewijzigd (ENEMIES zelf niet aangepast)", int(GD.ENEMIES["mosslijm"]["max_hp"]) == int(GD.apply_tier(GD.ENEMIES["mosslijm"], 0)["max_hp"]))
	# uitgangen: doel-spawn bestaat, en het doel heeft een uitgang terug
	var paths: Array = DR.ORDER.map(func(e): return e[1])
	bad = []
	var pairs := 0
	for path in paths:
		for ex in exits_of(path):
			if ex["map"] == WORLD_SCENE:
				continue
			if not spawns_of(ex["map"]).has(ex["spawn"]):
				bad.append("%s %s -> %s:%s (spawn bestaat niet)" % [path.get_file(), ex["key"], ex["map"].get_file(), ex["spawn"]])
			if not exits_of(ex["map"]).any(func(b): return b["map"] == path):
				bad.append("%s -> %s (geen weg terug)" % [path.get_file(), ex["map"].get_file()])
			pairs += 1
	check("alle %d overgangen: spawn bestaat en er is een weg terug (%s)" % [pairs, bad], bad.is_empty() and pairs == 22)
	# Golemhal alleen via de bibliotheek
	var to_golem := []
	for path in paths:
		for ex in exits_of(path):
			if ex["map"] == GOLEMHAL_SCENE:
				to_golem.append(path.get_file())
	check("Golem Hall alleen bereikbaar via de bibliotheek (%s)" % [to_golem], to_golem == ["archief_bibliotheek.tscn"])
	# kisten + boeken (plan par. 7)
	var chest_items := {}
	var books := 0
	for rid in DR.ROOMS:
		for c in DR.ROOMS[rid].get("chests", []):
			chest_items[c["id"]] = [c["item"], c["n"]]
			check("kist %s: voorwerp '%s' bestaat" % [c["id"], c["item"]], GD.ITEMS.has(c["item"]) or GD.EQUIPMENT.has(c["item"]))
		books += DR.ROOMS[rid].get("books", []).size()
	check("5 kisten (1B 2 drankjes, 2B leren kap, 2C 3 drankjes, 3A kaftschild, 4B 2 drankjes): %s" % [chest_items],
			chest_items == {"kist_1b": ["drankje", 2], "kist_2b": ["leren_kap", 1], "kist_2c": ["drankje", 3],
			"kist_3a": ["kaftschild", 1], "kist_4b": ["drankje", 2]})
	check("3 HP-boeken (2C, 3A, 4A): %d" % books, books == 3)
	# bewakers
	var guards := []
	for rid in DR.ROOMS:
		for m in DR.ROOMS[rid]["monsters"]:
			if m.get("guard", false):
				guards.append("%s/%s" % [rid, m["id"]])
				check("bewaker %s/%s staat stil" % [rid, m["id"]], not m["moves"])
	check("bewakers: 2C trap, 4B boog, de Golem (%s)" % [guards], guards.size() == 3)
	# bibliotheek: savepunt + golemdeur
	var lib: Dictionary = DR.ROOMS["archief_bibliotheek"]
	var lg := DR.legend_of(lib)
	check("bibliotheek: geen monsters, opslagboek 'save_bibliotheek' op de runenring (157)", lib["monsters"].is_empty()
			and lib["save_type"] == "save_bibliotheek" and lg[lib["layout"][5][3]] == 157)
	check("golemdeur: boven muur (massief), alleen de onderste rij (5,2)/(6,2) is beloopbaar = uitgang naar de Golem Hall",
			lg[lib["layout"][1][5]] in DR.SOLID and lg[lib["layout"][1][6]] in DR.SOLID and lib["layout"][2].substr(5, 2) == "nn"
			and not (43 in DR.SOLID) and lib["exits"]["n"]["map"] == GOLEMHAL_SCENE
			and lib["props"].any(func(p): return p["type"] == "golemdeur" and p["tile"] == [5, 1] and p["frame"] == 1))
	check("Golem Hall: platform zoals v0.13, alleen de Golem, uitgang onderaan naar de bibliotheek",
			DR.ROOMS["archief_golemhal"]["layout"][5] == "<S.....[=oO=]......>" and DR.ROOMS["archief_golemhal"]["exits"]["U"]["map"] == LIB_SCENE)
	check("ingang (1A): savepunt op sokkel, geen Golem/testmonsters meer (3 monsters), E naar de wereldkaart",
			DR.ROOMS["archief_ingang"]["monsters"].size() == 3 and DR.ROOMS["archief_ingang"]["exits"]["E"]["map"] == WORLD_SCENE
			and not DR.ROOMS["archief_ingang"]["monsters"].any(func(m): return m.get("boss", false)))


# ================================================================ v0.14 helpers
func droom() -> Node:
	var s := scene()
	return s if s != null and s.has_method("terrain_at") and s.is_node_ready() else null


func clear_monsters(r: Node) -> void:
	if "monsters" in r and r.get("monsters") is Array and r.has_method("get_monster"):
		for m in r.monsters:
			m.queue_free()
		r.monsters.clear()


func enter(path: String, spawn: String, no_monsters := true) -> Node:
	GameState.change_map(path, spawn)
	if not await wait_scene(node_name_of(path)):
		return null
	await wait_fade()
	var r := droom()
	if r and no_monsters:
		clear_monsters(r)
	return r


func dir_action(d: Vector2i) -> String:
	return {U: "move_up", D: "move_down", L: "move_left", R: "move_right"}[d]


# ================================================================ v0.14 deel C: de dungeon
func _dungeon_tests() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT      # proloog-scènes klaar: Archieven + wereldkaart open
	GameState.encounter_multiplier = 0.0
	GameState.change_map(WORLD_SCENE, "van_archief")
	check("wereldkaart geladen", await wait_scene("Wereldkaart"))
	await wait_fade()
	var trap: Node = scene().get_node("Exits/Trap")
	check("trap (20,34) = ingang van de Archives -> archief_ingang.tscn 'ingang'",
			trap.contains(Vector2i(20, 34)) and trap.target_map == ROOM_SCENE and trap.target_spawn == "ingang")
	await walk("move_down", 1)
	check("over de trap -> The Forgotten Archives (1A)", await wait_scene("ArchiefIngang"))
	var r := room()
	if r == null:
		return
	await wait_fade()
	check("bij de ingang (9,10), kijkt omhoog: %s" % tile(), tile() == Vector2i(9, 10) and player().facing == U)
	var g: TileMapLayer = r.get_node("Ground")
	# v0.15: het beeld komt uit het thema "archief_grijs" (grijze bieb); nummers/indeling gelijk
	check("Ground: 20x12 met de grijze archief-tegels (v0.15 thema)", g.get_used_rect() == Rect2i(0, 0, 20, 12)
			and str(g.tile_set.get_source(0).texture.resource_path).ends_with("archief_grijs_tiles.png"))
	check("tegels: muurtop (5,0)=23, sokkel (3,8)=12, uitgang (9,11)=30, boog (9,2)=43",
			r.cell(Vector2i(5, 0)) == 23 and r.cell(Vector2i(3, 8)) == 12 and r.cell(Vector2i(9, 11)) == 30 and r.cell(Vector2i(9, 2)) == 43)
	check("savepunt (cyaan boek) op de sokkel (3,8), 4 px hoger", r.save_book != null and r.save_book.type == "save"
			and r.save_book.position == Vector2(56, 136) and r.save_book.get_node("Sprite2D").offset == Vector2(0, -4))
	check("1A: 3 map-monsters (mosslijm, moskonijn, papiergeest), geen Golem", r.monsters.size() == 3 and r.get_monster("golem") == null
			and r.monsters.map(func(m): return m.enemy_id) == ["mosslijm", "moskonijn", "papiergeest"])
	var ml: MapMonster = r.get_monster("m1")
	check("mosslijm: eigen art, 2 kolommen x 4 richtingen", ml != null and not ml.placeholder and ml.directional
			and ml.sprite.hframes == 2 and ml.sprite.vframes == 4 and ml.sprite.texture.resource_path.ends_with("map_monsters/mosslijm.png"))
	var fake: MapMonster = MapMonster.new()
	fake.setup(r, {"id": "x", "enemy": "papiergeest", "sprite": "bestaat_niet", "tile": [17, 10], "moves": false}, 1)
	check("geen bestand -> placeholder (verkleind gevechtsplaatje)", fake.placeholder and fake.sprite.texture != null)
	fake.free()
	# rondlopen
	var t0 := Time.get_ticks_msec()
	var all_ok := true
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
		for m in r.monsters:
			if r.is_wall(m.tile) or (m.moves and r.cell(m.tile) in DR.NO_MONSTER):
				all_ok = false
		if GameState.in_battle:
			break
	if GameState.in_battle:
		await flee_battle()
		await wait_scene("ArchiefIngang")
		r = room()
	check("monsters lopen rond (%d zetten stappen)" % r.monsters.filter(func(m): return m.steps > 0).size(),
			r.monsters.filter(func(m): return m.steps > 0).size() >= 2)
	check("monsters nooit in muren / op uitgang of boog", all_ok)
	# stil bij tekstvak
	park(r, {})
	for m in r.monsters:
		m.moves = true
	Dialog.show_lines(["Test."])
	await pframes(2)
	var before := positions(r)
	await get_tree().create_timer(1.2).timeout
	check("tekstvak open: monsters staan stil", positions(r) == before)
	await close_dialog()
	park(r, {"m1": Vector2i(12, 8), "m2": Vector2i(15, 8), "m3": Vector2i(5, 5)})
	await pframes(2)
	var ms: MapMonster = r.get_monster("m2")
	check("blokkeren: muur", r.monster_can_enter(ms, Vector2i(15, 0)) == "wall")
	check("blokkeren: boog/uitgang niet voor monsters", r.monster_can_enter(ms, Vector2i(9, 2)) == "wall"
			and r.monster_can_enter(ms, Vector2i(9, 11)) == "wall")
	check("blokkeren: ander monster", r.monster_can_enter(ms, Vector2i(12, 8)) == "blocked")
	check("speler op de tile = aanraken", r.monster_can_enter(ms, tile()) == "player")
	check("vrije vloer", r.monster_can_enter(ms, Vector2i(15, 9)) == "free")
	GameState.encounter_multiplier = 100.0
	# De begin-warper staat op (8, 10), direct links van de spawn (9, 10).
	await walk("move_right", 3)
	await walk("move_left", 3)
	check("geen random encounters in de dungeon (6 stappen, 100x kans)", not GameState.in_battle and tile() == Vector2i(9, 10))
	GameState.encounter_multiplier = 0.0
	# savepunt: via de rij erboven, om de warper heen. De sokkel is massief, dus omhoog kijken blijft op (3, 9).
	await walk("move_up", 1)
	await walk("move_left", 6)
	await walk("move_up", 1)
	check("voor het savepunt (3,9), kijkt omhoog: %s" % tile(), tile() == Vector2i(3, 9) and player().facing == U)
	GameState.party[0]["hp"] = 1
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("savepunt: HP vol", GameState.party[0]["hp"] == GameState.party[0]["max_hp"])
	await close_dialog()
	await wait_until(func(): return Dialog.has_choices() and not Dialog._is_typing(), 3.0)
	await pframes(4)
	await press_interact()
	await wait_until(func(): return r.save_book.last_result == "saved", 3.0)
	check("savepunt: opgeslagen in de dungeon", r.save_book.last_result == "saved" and GameState.read_save().get("map", "") == ROOM_SCENE)
	await close_dialog()
	await pframes(5)
	# speler loopt tegen monster -> gevecht met niveau 1; winst = weg
	r.get_monster("m1").place_at(Vector2i(4, 9), L)
	await pframes(2)
	await walk("move_right", 1)
	await pframes(2)
	check("tegen de mosslijm -> gevecht (groep %s, niveau %d)" % [GameState.pending_enemies, GameState.pending_tier],
			GameState.in_battle and GameState.pending_enemies == ["mosslijm"] and GameState.pending_tier == 1 and r.last_touch_id == "m1")
	check("gevechtsscherm", await wait_scene("Battle"))
	await wait_battle_state(["command"])
	var e0: Dictionary = battle().enemies[0]["s"]
	var want1 := GD.apply_archief_tier(GD.ENEMIES["mosslijm"], 1)
	check("niveau 1 in het gevecht: archiefschaal HP %d (=%d), EXP %d (=%d)" % [int(e0["max_hp"]), int(want1["max_hp"]), int(e0["exp"]), int(want1["exp"])],
			int(e0["max_hp"]) == int(want1["max_hp"]) and int(e0["exp"]) == int(want1["exp"]))
	await win_battle()
	check("na winst terug in 1A", await wait_scene("ArchiefIngang"))
	r = room()
	await wait_fade()
	check("verslagen mosslijm is weg", r.get_monster("m1") == null and r.monsters.size() == 2)
	# monster loopt tegen speler; vluchten
	park(r, {"m2": Vector2i(4, 9), "m3": Vector2i(5, 5)})
	await get_tree().create_timer(1.0).timeout
	ms = r.get_monster("m2")
	var res: String = ms.try_step(L)
	await pframes(2)
	check("moskonijn loopt tegen de speler -> gevecht (%s)" % res, res == "player" and GameState.in_battle)
	check("gevechtsscherm (moskonijn)", await wait_scene("Battle"))
	await flee_battle()
	check("na vluchten terug", await wait_scene("ArchiefIngang"))
	r = room()
	ms = r.get_monster("m2")
	check("vluchten: moskonijn blijft staan, speler ~1,5 s onkwetsbaar", ms != null and ms.tile == Vector2i(4, 9)
			and r.invuln_left > 1.0 and r.invuln_left <= 1.5)
	# v0.17 fix (flaky deel D-G): de kamer is na het gevecht opnieuw geladen, dus de monsters lopen weer.
	# Na de 1,5 s onkwetsbaarheid liep de moskonijn soms tegen de speler -> nieuw gevecht (in_battle),
	# en dan negeerde change_map ALLE volgende kamers. Monsters stil zetten; hangt er toch een gevecht, uitvluchten.
	if r:
		for m in r.monsters:
			if is_instance_valid(m):
				m.moves = false
	await get_tree().create_timer(1.8).timeout
	if GameState.in_battle:
		print("INFO  onverwacht gevecht na het vluchten: eerst weer vluchten")
		await wait_scene("Battle")
		await flee_battle()
		await wait_scene("ArchiefIngang")
		await wait_fade()
	await _transition_tests()
	await _guard_chest_book_tests()
	await _library_and_golem_tests()
	await _tier_battle_tests()


## Elke overgang (in elke kamer elke uitgang) echt lopen: 1 stap op de uitgang -> juiste kamer + spawn.
func _transition_tests() -> void:
	print("=== Deel D: alle overgangen (beide kanten) ===")
	var n := 0
	for e in DR.ORDER:
		var path: String = e[1]
		var sp: Array = spawns_of(path)
		for ex in exits_of(path):
			if path == PUZZLE_SCENE and ex["key"] == "X":
				continue      # puzzeluitgang X: met de oplossing in --puzzletest
			var r := await enter(path, sp[0])
			if r == null:
				check("kamer %s geladen" % path, false)
				continue
			player().place_at(ex["from"], ex["dir"])
			await frames(3)
			await walk(dir_action(ex["dir"]), 1)
			var want: String = "Wereldkaart" if ex["map"] == WORLD_SCENE else node_name_of(ex["map"])
			var ok := await wait_scene(want)
			await wait_fade()
			var spn: Node = scene().get_node_or_null("Spawns/" + ex["spawn"]) if ok else null
			check("%s '%s' -> %s '%s' (op %s)" % [path.get_file(), ex["key"], ex["map"].get_file(), ex["spawn"], tile()],
					ok and spn != null and tile() == spn.get_tile())
			n += 1
	check("overgangen gelopen: %d (22 min de puzzeluitgang X + wereldkaart)" % n, n == 22)


func _guard_chest_book_tests() -> void:
	print("=== Deel E: bewakers, kisten, HP-boeken ===")
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	# bewaker 2C (kennis_beest op (15,5), voor de trap)
	var r := await enter("res://scenes/maps/archief_v2_trapzaal.tscn", "zuid", false)
	var gm: MapMonster = r.get_monster("m2")
	check("2C: bewaker staat stil voor de trap (15,5)", gm != null and not gm.moves and gm.tile == Vector2i(15, 5))
	for m in r.monsters:
		m.moves = false
	await get_tree().create_timer(1.0).timeout
	player().place_at(Vector2i(15, 6), U)
	await frames(2)
	await press_interact()
	await pframes(2)
	check("A voor de bewaker -> gevecht met niveau 2 (%s)" % [GameState.pending_enemies], GameState.in_battle and GameState.pending_tier == 2)
	if await wait_scene("Battle"):
		await win_battle()
	check("terug in 2C", await wait_scene("ArchiefV2Trapzaal"))
	await wait_fade()
	check("bewaker verslagen: vlag in de game state", GameState.story_flags.has("bewaker:archief_v2_trapzaal/m2"))
	GameState.save_game(Vector2i(9, 10), U)
	GameState.story_flags.clear()
	GameState.load_game()
	check("bewaker-vlag gaat mee in de save", GameState.story_flags.has("bewaker:archief_v2_trapzaal/m2"))
	r = await enter("res://scenes/maps/archief_v1_gang.tscn", "zuid", false)
	r = await enter("res://scenes/maps/archief_v2_trapzaal.tscn", "zuid", false)
	check("opnieuw in 2C: bewaker blijft weg, het andere monster is terug", r.get_monster("m2") == null and r.get_monster("m1") != null)
	# HP-boek 2C (2,3)
	clear_monsters(r)
	player().place_at(Vector2i(2, 4), U)
	GameState.party[0]["hp"] = 1
	await frames(2)
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("HP-boek (2C): HP vol", GameState.party[0]["hp"] == GameState.party[0]["max_hp"])
	await close_dialog()
	await pframes(4)
	# kist 1B (23,8): 2 drankjes, eenmalig
	r = await enter("res://scenes/maps/archief_v1_gang.tscn", "zuid")
	var ch: Node = r.chests[0]
	check("1B: kist dicht (grijze kist.png frame 0, v0.15 thema) op (23,8)", ch.tile() == Vector2i(23, 8) and ch.sprite.frame == 0
			and ch.sprite.texture.resource_path.ends_with("dungeon/grijs/kist.png"))
	var before := GameState.item_count("drankje")
	player().place_at(Vector2i(23, 9), U)
	await frames(2)
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("kist open: +2 drankjes ('%s')" % [Dialog._lines], GameState.item_count("drankje") == before + 2 and ch.last_result == "gekregen"
			and ch.sprite.frame == 1)
	# v0.16: naar de regel "{naam} vindt: 2x Drankje!" en die in het blauwe vak
	var guard := 0
	while Dialog.is_open and not str(Dialog._lines[Dialog._index]).contains("finds") and guard < 10:
		await wait_until(func(): return not Dialog._is_typing(), 3.0)
		await press_interact()
		guard += 1
	await wait_until(func(): return not Dialog._is_typing(), 3.0)
	var line := str(Dialog._lines[Dialog._index]) if Dialog.is_open else ""
	var bx: Rect2 = Dialog.box_rect()
	var over := false
	for f in Dialog._focus_rects():
		for b in Dialog._rects_for(bx):
			over = over or b.intersects(f)
	var py: float = player().get_global_transform_with_canvas().origin.y
	check("v0.16: schat-tekst '%s' in het blauwe vak (geen ballon/staart/naam)" % line, line == "Dennis finds: 2x Potion!"
			and Dialog.style_kind == "vak" and UiStyle.is_blue_box(Dialog.box_style(), "vak") and not Dialog.tail.visible
			and not Dialog.name_tab.visible)
	check("v0.16: schat-tekst bedekt speler/kist niet; laag tenzij de speler zelf onderin staat (%s, plek %s, speler y %.0f)"
			% [bx, Dialog.placement, py], not over and (Dialog.at_bottom or py > 216.0 * 0.5))
	await pframes(10)
	await v16_shot("schat")
	await close_dialog()
	await pframes(4)
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("tweede keer: leeg, niets erbij", GameState.item_count("drankje") == before + 2 and ch.last_result == "leeg")
	await close_dialog()
	await pframes(4)
	r = await enter("res://scenes/maps/archief_ingang.tscn", "boog")
	r = await enter("res://scenes/maps/archief_v1_gang.tscn", "zuid")
	check("opnieuw in 1B: kist blijft open (vlag kist:kist_1b)", r.chests[0].is_open() and r.chests[0].sprite.frame == 1
			and GameState.story_flags.has("kist:kist_1b"))
	# 2B: Leren Kap (uitrusting) in de tas
	r = await enter("res://scenes/maps/archief_v2_leeszaal.tscn", "zuid")
	player().place_at(Vector2i(2, 13), U)
	await frames(2)
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("2B: kist geeft de Leather Hood", GameState.item_count("leren_kap") >= 1)
	await close_dialog()
	await pframes(4)


func hw_text() -> String:
	return FileAccess.get_file_as_string("res://tools/handwerk.txt")


## v0.15 ARCHIEF-THEMA 'grauwe grijze bieb': data-gedreven, standaard voor elk archief.
func _theme_tests(hw: String) -> void:
	check("thema: DEFAULT_THEME = archief_grijs", DR.DEFAULT_THEME == "archief_grijs" and DR.THEMES.has("archief_grijs")
			and DR.THEMES.has("archief_v14"))
	var t: Dictionary = DR.theme_data("archief_grijs")
	var a: Texture2D = load(str(t["tiles"]))
	var l: Texture2D = load(str(t["lib_tiles"]))
	check("grijze atlassen even groot als die van RPG ART (256x80 / 256x64)", a != null and l != null
			and a.get_size() == Vector2(256, 80) and l.get_size() == Vector2(256, 64))
	var no_theme := []
	for rid in DR.ROOMS:
		if DR.theme_of(DR.ROOMS[rid]) != "archief_grijs":
			no_theme.append(rid)
	check("alle archiefkamers krijgen standaard het grijze thema (anders: %s)" % [no_theme], no_theme.is_empty()
			and DR.theme_of({}) == "archief_grijs" and DR.theme_of({"theme": "bestaat_niet"}) == "archief_grijs")
	var missing := []
	for src in t["sprites"]:
		var alt := DR.themed(src, "archief_grijs")
		if alt == src or not ResourceLoader.exists(alt) or not ResourceLoader.exists(src):
			missing.append(src.get_file())
		elif (load(alt) as Texture2D).get_size() != (load(src) as Texture2D).get_size():
			missing.append(src.get_file() + " (maat)")
	check("grijze sprites bestaan, zelfde maat als het origineel (fout: %s)" % [missing], missing.is_empty())
	check("themed(): geen thema of archief_v14 -> origineel", DR.themed("res://assets/puzzle/hendel.png", "archief_v14") == "res://assets/puzzle/hendel.png"
			and DR.themed("res://assets/sprites/player.png", "archief_grijs") == "res://assets/sprites/player.png")
	check("gegenereerde grijze art staat NIET in handwerk.txt", not ("archief_grijs" in hw) and not ("dungeon/grijs/" in hw))
	var ts_old: TileSet = DungeonRoom.tileset(true, "archief_v14")
	var ts_new: TileSet = DungeonRoom.tileset(true, "archief_grijs")
	var same := true
	for si in 2:
		var so: TileSetAtlasSource = ts_old.get_source(si)
		var sn: TileSetAtlasSource = ts_new.get_source(si)
		for n in so.get_tiles_count():
			var c := so.get_tile_id(n)
			if not sn.has_tile(c) or so.get_tile_data(c, 0).get_collision_polygons_count(0) != sn.get_tile_data(c, 0).get_collision_polygons_count(0):
				same = false
	check("botsing per tegel identiek in beide thema's", same and str(ts_old.get_source(0).texture.resource_path).ends_with("dungeon_tiles_v14.png"))


func _library_and_golem_tests() -> void:
	print("=== Deel F: bibliotheek (save) en Golem Hall ===")
	var r := await enter(LIB_SCENE, "zuid")
	check("bibliotheek: twee atlassen, kastmuur (1,1)=100, loper (5,4)=151", r.cell(Vector2i(1, 1)) == 100 and r.cell(Vector2i(5, 4)) == 151
			and str(r.get_node("Ground").tile_set.get_source(1).texture.resource_path).ends_with("archief_grijs_bibliotheek.png"))
	check("bibliotheek: opslagboek savepunt_bibliotheek.png, offset 0", r.save_book.type == "save_bibliotheek"
			and r.save_book.get_node("Sprite2D").offset == Vector2.ZERO
			and r.save_book.get_node("Sprite2D").texture.resource_path.ends_with("savepunt_bibliotheek.png"))
	check("bibliotheek: 4 staande kasten, 2 kandelaars, golemdeur open (frame 1)", r.props.filter(func(p): return p.kind == "staande_kast").size() == 4
			and r.props.filter(func(p): return p.kind == "kandelaar").size() == 2
			and r.props.any(func(p): return p.kind == "golemdeur" and p.sprite.frame == 1))
	await walk("move_left", 2)
	await walk("move_up", 1)
	check("voor het opslagboek (3,6): %s" % tile(), tile() == Vector2i(3, 6) and player().facing == U)
	GameState.party[0]["hp"] = 1
	GameState.party[0]["mp"] = 0
	await press_interact()
	await wait_until(func(): return Dialog.is_open)
	check("bibliotheek-save: HP en MP vol", GameState.party[0]["hp"] == GameState.party[0]["max_hp"]
			and GameState.party[0]["mp"] == GameState.party[0]["max_mp"])
	await close_dialog()
	await wait_until(func(): return Dialog.has_choices() and not Dialog._is_typing(), 3.0)
	await pframes(4)
	await press_interact()
	await wait_until(func(): return r.save_book.last_result == "saved", 3.0)
	check("bibliotheek-save: opgeslagen (map = bibliotheek)", r.save_book.last_result == "saved"
			and GameState.read_save().get("map", "") == LIB_SCENE)
	await close_dialog()
	await pframes(4)
	await screenshot("v14_bibliotheek")
	# golemdeur: boven = muur, onderste rij = overgang
	player().place_at(Vector2i(5, 3), U)
	await frames(2)
	check("golemdeur: bovenste rij (5,1) is muur", r.is_wall(Vector2i(5, 1)) and not r.is_wall(Vector2i(5, 2)))
	await walk("move_up", 1)
	check("op de onderste rij van de golemdeur -> Golem Hall", await wait_scene("ArchiefGolemhal"))
	await wait_fade()
	r = droom()
	check("Golem Hall: binnen bij (9,10)", tile() == Vector2i(9, 10))
	var gm: MapMonster = r.get_monster("golem")
	check("Golem: 2x2 op (9,3), baas, stil", gm != null and gm.size == Vector2i(2, 2) and gm.tile == Vector2i(9, 3) and gm.boss and not gm.moves)
	await walk("move_up", 5)
	check("op de rune voor de Golem (9,5): %s" % tile(), tile() == Vector2i(9, 5))
	await walk("move_up", 1)
	await pframes(2)
	check("tegen de Golem -> BAASgevecht zonder niveau", GameState.in_battle and GameState.pending_boss and GameState.pending_tier == 0
			and GameState.pending_backdrop_id == "boss")
	if await wait_scene("Battle"):
		await wait_battle_state(["command"])
		await win_battle()
	check("terug in de Golem Hall", await wait_scene("ArchiefGolemhal"))
	await wait_fade()
	# v0.15 (KERN): na de Golem absorbeert Dennis de Golemkern (moment + tekst); wegklikken als een speler
	var absorbed: bool = await wait_until(func(): return Dialog.is_open and GameState.has_kern("golemkern"), 5.0)
	await close_dialog()
	check("Golemkern geabsorbeerd, tekst weggeklikt (zie --kerntest)", absorbed and await wait_until(
			func(): return GameState.pending_kern_absorb == "" and not scene().get_node("Objects/Player").input_locked, 3.0))
	await enter(LIB_SCENE, "deur")
	r = await enter(GOLEMHAL_SCENE, "zuid", false)
	check("verslagen Golem blijft weg (bewaker)", r.get_monster("golem") == null)


func _tier_battle_tests() -> void:
	print("=== Deel G: niveau-gevechten ===")
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	# 2A: Mechanische Wachter op niveau 2
	var r := await enter("res://scenes/maps/archief_v2_kastenzaal.tscn", "ladder", false)
	for m in r.monsters:
		m.moves = false
	await get_tree().create_timer(1.0).timeout
	var mw: MapMonster = r.get_monster("m3")
	check("2A: Mech. Warden met eigen map-art", mw != null and not mw.placeholder and mw.enemy_id == "mech_wachter")
	mw.place_at(Vector2i(3, 4), U)
	await pframes(2)
	await walk("move_down", 1)
	await pframes(2)
	check("tegen de Mech. Warden -> gevecht niveau 2", GameState.in_battle and GameState.pending_tier == 2)
	if await wait_scene("Battle"):
		await wait_battle_state(["command"])
		var s: Dictionary = battle().enemies[0]["s"]
		var want := GD.apply_archief_tier(GD.ENEMIES["mech_wachter"], 2)
		check("niveau 2 in het gevecht: HP %d (=%d), ATK %d (=%d)" % [s["max_hp"], want["max_hp"], s["atk"], want["atk"]],
				int(s["max_hp"]) == int(want["max_hp"]) and int(s["atk"]) == int(want["atk"]))
		await win_battle()
	await wait_scene("ArchiefV2Kastenzaal")
	await wait_fade()
	# 4A: niveau 4 (screenshot)
	GameState.party[0]["hp"] = GameState.party[0]["max_hp"]
	r = await enter("res://scenes/maps/archief_v4_wachtersgang.tscn", "ladder", false)
	for m in r.monsters:
		m.moves = false
	await get_tree().create_timer(1.0).timeout
	await screenshot("v14_v4_wachtersgang")
	var m3: MapMonster = r.get_monster("m3")
	m3.place_at(Vector2i(2, 4), U)
	await pframes(2)
	await walk("move_down", 1)
	await pframes(2)
	check("4A: gevecht op niveau 4 (groep %s)" % [GameState.pending_enemies], GameState.in_battle and GameState.pending_tier == 4
			and GameState.pending_enemies == ["mech_wachter", "glitchmot"])
	if await wait_scene("Battle"):
		await wait_battle_state(["command"])
		var s: Dictionary = battle().enemies[0]["s"]
		check("niveau 4: Mech. Warden HP %d" % s["max_hp"], int(s["max_hp"]) == int(GD.apply_archief_tier(GD.ENEMIES["mech_wachter"], 4)["max_hp"]))
		await pframes(20)
		await screenshot("v14_tier4_gevecht")
		await win_battle()
	await wait_scene("ArchiefV4Wachtersgang")
	await wait_fade()
	# kamer-shots per verdieping
	await enter("res://scenes/maps/archief_ingang.tscn", "boog", false)
	await get_tree().create_timer(0.6).timeout
	await screenshot("v14_v1_ingang")
	await enter("res://scenes/maps/archief_v2_trapzaal.tscn", "zuid", false)
	await get_tree().create_timer(0.6).timeout
	await screenshot("v14_v2_trapzaal")
	# v0.15 grijze bieb: extra kamer-shots (alleen met --shots; geen checks)
	if shots != "":
		for e in [["archief_ingang", "ingang", "v15_ingang"], ["archief_v1_gang", "zuid", "v15_v1_gang"],
				["archief_v2_kastenzaal", "", "v15_v2_kastenzaal"], ["archief_v3_zuilenhal", "", "v15_v3_zuilenhal"],
				["archief_golemhal", "zuid", "v15_golemhal"], ["archief_bibliotheek", "zuid", "v15_bibliotheek"]]:
			var sp: String = e[1]
			var gf := DungeonRoom.guard_flag("archief_golemhal", "golem")
			var had: bool = GameState.story_flags.has(gf)
			GameState.story_flags.erase(gf)     # de Golem in beeld (vlag daarna terug)
			await enter(DR.scene_of(e[0]), sp, false)
			await get_tree().create_timer(0.6).timeout
			await screenshot(e[2])
			if had:
				GameState.story_flags[gf] = true


# ================================================================ v0.16 deel G: glitch
## Glitch (flitsen + randruis) alleen in de Archieven; sterkte via de kamergraaf (dungeon_rooms.gd).
func _glitch_tests() -> void:
	var outside := ["res://scenes/maps/wilgendal.tscn", "res://scenes/maps/huis_wilgendal.tscn", WORLD_SCENE,
			"res://scenes/battle/battle.tscn", "res://scenes/ui/title.tscn", ""]
	var zeros := outside.filter(func(p2): return DR.glitch_intensity(p2) != 0.0)
	check("G: sterkte 0 buiten de Archives (dorp, huis, wereldkaart, gevecht, titel) %s" % [zeros], zeros.is_empty())
	var dist := DR.boss_distances()
	check("G: kamergraaf uit de uitgangen: alle %d archiefkamers bereikbaar vanaf de Golem Hall (%s)" % [DR.ORDER.size(), dist.size()],
			DR.ORDER.all(func(e): return dist.has(e[1])) and DR.boss_distance(DR.scene_of("archief_golemhal")) == 0)
	# de route van de ingang naar de baas: elke stap sterker (tot de max in de Voorhal)
	var route := ["archief_ingang", "archief_v1_gang", "archief_v2_kastenzaal", "archief_v2_leeszaal", "archief_v2_trapzaal",
			"archief_v3_zuilenhal", "", "archief_v3_gang", "archief_v4_wachtersgang", "archief_v4_voorhal"]
	var vals := []
	for id in route:
		var p2: String = PUZZLE_SCENE if id == "" else DR.scene_of(id)
		vals.append(snappedf(DR.glitch_intensity(p2), 0.01))
	var rising := true
	for i in range(1, vals.size()):
		rising = rising and vals[i] > vals[i - 1]
	check("G: sterkte stijgt richting de baas: ingang -> ... -> voorhal %s" % [vals], rising and vals[0] > 0.0)
	check("G: max (1.0) in de Golem Hall (baas), de Library en de Vestibule", DR.glitch_intensity(DR.scene_of("archief_golemhal")) == 1.0
			and DR.glitch_intensity(DR.scene_of("archief_v4_voorhal")) == 1.0 and DR.glitch_intensity(DR.scene_of("archief_bibliotheek")) == 1.0)
	check("G: verste kamer (ingang) zwakst maar > 0 (%.2f)" % vals[0], is_equal_approx(vals[0], DR.GLITCH_MIN))
	GameState.encounter_multiplier = 0.0
	# echte scènes: Crt pakt de sterkte zelf op bij een kamerwissel (bestaande overlay/ruis/scanlines)
	var gf := DungeonRoom.guard_flag("archief_golemhal", "golem")
	for e in [["archief_ingang", "boog"], ["archief_v3_gang", ""], ["archief_v4_voorhal", ""], ["archief_golemhal", "zuid"]]:
		var p2: String = DR.scene_of(e[0])
		var sp: String = e[1] if e[1] != "" else str(spawns_of(p2)[0])
		var had: bool = GameState.story_flags.has(gf)
		if e[0] == "archief_golemhal":
			GameState.story_flags.erase(gf)
		var r := await enter(p2, sp, false)
		await pframes(3)
		var want := DR.glitch_intensity(p2)
		check("G: in %s: Crt-sterkte %.2f = graaf %.2f, randruis aan (alpha %.2f)" % [e[0], Crt.glitch_intensity, want, Crt.noise.modulate.a],
				r != null and is_equal_approx(Crt.glitch_intensity, want) and Crt.noise.visible and Crt.noise.modulate.a > 0.0
				and Crt.noise.get_parent() == Crt and Crt.glitch.get_parent() == Crt)
		if e[0] == "archief_ingang" or e[0] == "archief_v4_voorhal":
			Crt.start_glitch(1.0)
			await pframes(2)
			await v16_shot("archief_ver" if e[0] == "archief_ingang" else "archief_dichtbij")
			Crt._glitch_left = 0.01
		if had:
			GameState.story_flags[gf] = true
	check("G: dichter bij de baas = vaker een flits (wachttijd ver %.1f s > dichtbij %.1f s)"
			% [_gap_at(DR.GLITCH_MIN), _gap_at(1.0)], _gap_at(DR.GLITCH_MIN) > _gap_at(1.0))
	# buiten: alles uit, ook als een flits "aan de beurt" is
	GameState.change_map(WORLD_SCENE, "van_archief")
	await wait_scene("Wereldkaart")
	await wait_fade()
	await pframes(3)
	Crt._next_glitch = Crt._t
	var seen := false
	for i in 30:
		seen = seen or Crt.glitch.visible
		await get_tree().process_frame
	check("G: wereldkaart: sterkte 0, geen ruis, geen automatische glitch (ook niet als hij 'aan de beurt' is)",
			Crt.glitch_intensity == 0.0 and not Crt.noise.visible and not seen)
	check("G: CRT-scanlines blijven (gewoon filter), maar zonder archief-extra (%.3f)" % Crt.current_intensity(),
			is_equal_approx(Crt.current_intensity(), float(Crt.settings.get("scanlines_overworld", 0.2))) or is_equal_approx(Crt.current_intensity(), float(Crt.settings.get("scanlines", 0.2))))


## Gemiddelde wachttijd tot de volgende flits bij sterkte i (zonder de echte stand te verstoren).
func _gap_at(i: float) -> float:
	var keep: float = Crt.glitch_intensity
	Crt.glitch_intensity = i
	var tot := 0.0
	for n in 40:
		tot += Crt.glitch_gap()
	Crt.glitch_intensity = keep
	return tot / 40.0
