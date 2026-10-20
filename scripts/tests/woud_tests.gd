extends Node
## ALLEEN VOOR TESTEN - v0.17 ESDOORN + HET DONKER WOUD + NOOR.
## Start:  godot --path . -- --woudtest [--shots=/pad/map] [--v17=/workspace]
##   Deel A: data (opdracht, woudkamers + uitgangen, thema/overlay, glitch-schaal, vijanden + art).
##   Deel B: wereldkaart: Esdoorn pas na de Golem, het woud pas met de opdracht (echte uitgangen).
##   Deel C: Esdoorn: ontmoeting (eenmalig, ballonnen), opdracht + veldmenu, huizen, herberg.
##   Deel D: Donker Woud: kamers aan elkaar, Kernkracht-stun, baas (bos-achtergrond), Noor erbij.
##   Deel E: opslaan/laden houdt alles vast.
##   Deel F: Codex (patch RPG CODE) in v0.17: Lege Boeken van Marit/woudkisten, woudmonster vangen,
##           bondgenoot vecht mee (ook in het woud), Codex-scherm, wereldkaart-iconen (RPG ART).
##   Deel G: Het Zingende Graan (dicht vóór Noor, zaad op de mistrand, molen draait en zingt zacht, slaat op en geeft meel).
##   Deel H: uitgang-warpers begin/midden/eind. De ingang waarschuwt niet. Ja gaat naar de woud-ingang.
## --v17=map: screenshots 1024x576 als v17_dorp.png, v17_noor_ballon.png, v17_woud_kamer.png,
## v17_noor_cocon.png, v17_woud_baas.png, v17_noor_erbij.png (+ v17_woud_achtergrond.png, v17_veldmenu_opdracht.png),
## v17_wereld_esdoorn.png, v17_codex_vangen.png, v17_codex_bondgenoot.png, v17_codex_scherm.png.
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const WR := preload("res://scripts/data/woud_rooms.gd")
const KernVeld := preload("res://scripts/kern/kern_kracht_veld.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const Molen := preload("res://scripts/village/molen.gd")
const Wieken := preload("res://scripts/village/molen_wieken.gd")
const WORLD := "res://scenes/maps/wereldkaart.tscn"
const WW := preload("res://scripts/dungeon/woud_warpers.gd")
const ExitWarper := preload("res://scripts/dungeon/dungeon_exit_warper.gd")
const AW := preload("res://scripts/dungeon/archief_warpers.gd")
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up"}
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var failures := 0
var passes := 0
var shots := ""
var v17_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("--v17="):
			v17_dir = arg.get_slice("=", 1)
	seed(1717)
	# waakhond: hangt er iets, dan stopt de test zelf (met een FAIL)
	get_tree().create_timer(780.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 780 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
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
	print("=== Deel B: wereldkaart ===")
	await _world_tests()
	print("=== Deel C: Mapleton ===")
	await _village_tests()
	print("=== Deel D: Dark Wood ===")
	await _forest_tests()
	print("=== Deel E: opslaan/laden ===")
	await _save_tests()
	print("=== Deel F: Codex in het woud + wereldkaart-iconen ===")
	await _codex_forest_tests()
	print("=== Deel G: Het Zingende Graan ===")
	await _graan_tests()
	print("=== Deel H: uitgang-warpers Donker Woud ===")
	await _warper_tests()
	print("WOUDTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


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


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene(scene_name: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == scene_name and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


static func node_name_of(path: String) -> String:
	var out := ""
	for p in path.get_file().get_basename().split("_"):
		out += p.capitalize().replace(" ", "")
	return out


func enter(path: String, spawn: String) -> Node:
	GameState.change_map(path, spawn)
	if not await wait_scene(node_name_of(path)):
		return null
	await wait_fade()
	return scene()


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


## Laat een lopend verhaal-event uitlopen: tekst doorklikken (bij 'shot_when' in de tekst één
## screenshot), keuzes: de eerste optie. Geeft de getoonde regels terug.
func run_story(timeout := 40.0, shot_when := "", shot_name := "") -> Array:
	var seen: Array = []
	var shot_done := false
	var t0 := Time.get_ticks_msec()
	await pframes(2)
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if not Story.running and not Dialog.is_open:
			await pframes(6)
			if not Story.running and not Dialog.is_open:
				break
		if Dialog.is_open:
			var line := "%s: %s" % [Dialog.name_label.text, Dialog.text_label.text]
			if seen.is_empty() or seen[seen.size() - 1] != line:
				seen.append(line)
			if Dialog._is_typing():
				await frames(2)
				continue
			if not shot_done and shot_when != "" and shot_when in Dialog.text_label.text:
				shot_done = true
				await pframes(4)
				await v17_shot(shot_name)
			if Dialog.has_choices():
				Dialog.choose(0)
				await pframes(2)
				continue
			await press_interact()
			continue
		await get_tree().process_frame
	return seen


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
func win_battle() -> bool:
	var won := false
	Engine.time_scale = 3.0
	for guard in 80:
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
			if b.victory_panel.visible:
				won = true
			await tap("interact")
	Engine.time_scale = 1.0
	return won


## Screenshot op 1024x576 (heel-getal nearest, dan Lanczos) naar <v17_dir>/v17_<naam>.png.
func v17_shot(name: String) -> void:
	if v17_dir == "" and shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	var f := maxi(1, int(1024 / img.get_width()))
	if f > 1:
		img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	img.resize(1024, 576, Image.INTERPOLATE_LANCZOS)
	var dir := v17_dir if v17_dir != "" else shots
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("v17_%s.png" % name)
	img.save_png(path)
	print("INFO  v17-screenshot: ", path, " ", img.get_size())


func setup_game(level := 11) -> void:
	GameState.new_game("Dax")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(level))
	GameState.equip_weapon(GameState.MAIN_HERO, "vonkzwaard")
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""


func count_in_history(ev: String) -> int:
	return Story.history.filter(func(e): return e == ev).size()


func hw_lines() -> Array:
	var out := []
	for l in FileAccess.get_file_as_string("res://tools/handwerk.txt").split("\n"):
		l = l.strip_edges()
		if l != "" and not l.begins_with("#"):
			out.append(l)
	return out


func freeze_monsters(r: Node) -> void:
	for m in r.monsters:
		if is_instance_valid(m):
			m.moves = false
	await wait_until(func():
		for m in r.monsters:
			if is_instance_valid(m) and m.is_moving:
				return false
		return true, 3.0)


# ================================================================ A: data
func _data_tests() -> void:
	var q: Array = SD.QUESTS.filter(func(x): return x["id"] == "noor")
	check("opdracht 'Red Vesper uit het Dark Wood' (start quest_noor, klaar noor_gered)", q.size() == 1
			and q[0]["title"] == "Save Vesper from the Dark Wood" and q[0]["start_flag"] == "quest_noor" and q[0]["done_flag"] == "noor_gered")
	var missing := SD.TODO_STORY.filter(func(e): return not SD.EVENTS.has(e))
	check("TODO(verhaal): placeholder-events gemarkeerd en aanwezig (%d, mist %s)" % [SD.TODO_STORY.size(), missing],
			missing.is_empty() and SD.TODO_STORY.has("noor_ontmoeting") and SD.TODO_STORY.has("noor_bevrijd")
			and FileAccess.get_file_as_string("res://scripts/data/story_data.gd").contains("TODO(verhaal)"))
	# --- kamers
	check("Dark Wood: 4 kamers + open plek (baas), volgorde ingang -> baas", WR.ORDER.size() == 5
			and WR.ORDER[0][0] == "woud_rand" and WR.ORDER[4][0] == WR.BOSS_ROOM)
	var bad := []
	var chests := 0
	var legend_bad := []
	for e in WR.ORDER:
		var rid: String = e[0]
		var r: Dictionary = WR.ROOMS[rid]
		if not ResourceLoader.exists(e[1]):
			bad.append("scène %s" % e[1])
		if DR.room(rid) != r or DR.scene_of(rid) != e[1] or DR.theme_of(r) != "donker_woud":
			bad.append("opzoeken %s" % rid)
		var w: int = r["layout"][0].length()
		var lg := DR.legend_of(r)
		for row in r["layout"]:
			if row.length() != w:
				bad.append("rij %s" % rid)
			for ch in row:
				if not lg.has(ch):
					legend_bad.append("%s:%s" % [rid, ch])
		for k in r.get("exits", {}):
			var ex: Dictionary = r["exits"][k]
			var target: String = ex["map"]
			if target == WORLD:
				continue
			var tid := target.get_file().get_basename()
			if not WR.ROOMS.has(tid) or not WR.ROOMS[tid].get("spawns", {}).has(ex["spawn"]):
				bad.append("uitgang %s/%s -> %s:%s" % [rid, k, tid, ex["spawn"]])
		chests += r.get("chests", []).size()
		for m in r.get("monsters", []):
			if not GD.ENEMIES.has(m["enemy"]) or not ("woud" in GD.ENEMIES[m["enemy"]].get("habitat", [])):
				bad.append("monster %s/%s" % [rid, m["id"]])
	check("kamers kloppen: scènes, opzoeken, rijen even lang, uitgangen wederzijds (%s)" % [bad], bad.is_empty())
	check("alle tekens in de legenda (%s)" % [legend_bad], legend_bad.is_empty())
	check("een paar kisten (%d)" % chests, chests >= 2)
	var tiers := WR.ORDER.map(func(e): return int(WR.ROOMS[e[0]].get("tier", 0)))
	check("monsterniveau 3-4 (Lv ~10-13): %s" % [tiers], tiers.all(func(t): return t >= 3 and t <= 4))
	var boss: Array = WR.ROOMS[WR.BOSS_ROOM]["monsters"].filter(func(m): return m.get("boss", false))
	check("baas op de open plek: The Root King (2x2, bewaker)", boss.size() == 1 and boss[0]["enemy"] == "wortelkoning"
			and boss[0].get("guard", false) and boss[0]["size"] == [2, 2])
	check("de Archives ongemoeid (DR.ROOMS zonder woudkamers)", not DR.ROOMS.has("woud_rand") and DR.room("archief_ingang") == DR.ROOMS["archief_ingang"])
	# --- thema / tegels
	var th: Dictionary = DR.THEMES["donker_woud"]
	var tex: Texture2D = load(th["tiles"])
	check("thema donker_woud: woud_tiles.png 256x112 (RPG ART), terrein 'woud', één atlas",
			tex != null and tex.get_size() == Vector2(256, 112) and DR.terrain_of("donker_woud") == "woud" and DR.single_atlas("donker_woud"))
	var solid_ok := [87, 88, 89, 90, 96, 97, 98, 99, 104].all(func(n): return DR.is_solid(n, "donker_woud"))
	check("massief in het woud: 87-90, 96-99, 104 (archief-thema's: niet)", solid_ok and not DR.is_solid(96, "archief_grijs")
			and DR.is_no_monster(91, "donker_woud") and not DR.is_solid(91, "donker_woud") and not DR.is_solid(86, "donker_woud"))
	check("archief-SOLID ongewijzigd (12, 16, 59 massief; 0, 43 niet)", DR.is_solid(12, "archief_grijs") and DR.is_solid(16, "archief_grijs")
			and DR.is_solid(59, "archief_grijs") and not DR.is_solid(0, "archief_grijs") and not DR.is_solid(43, "archief_grijs"))
	# --- glitch
	var gi := WR.ORDER.map(func(e): return snappedf(DR.glitch_intensity(e[1]), 0.01))
	var rising := true
	for i in range(1, 4):
		rising = rising and gi[i] > gi[i - 1]
	check("glitch stijgt naar de baas: %s (ingang = min, open plek = 1)" % [gi], rising and is_equal_approx(gi[0], DR.GLITCH_MIN)
			and gi[4] == 1.0 and gi[3] == 1.0)
	check("glitch in de Archives zoals v0.16 (ingang min, Golem Hall 1)", is_equal_approx(DR.glitch_intensity(DR.scene_of("archief_ingang")), DR.GLITCH_MIN)
			and DR.glitch_intensity(DR.scene_of("archief_golemhal")) == 1.0)
	check("geen glitch in Mapleton en de huizen", DR.glitch_intensity(SD.ESDOORN) == 0.0 and DR.glitch_intensity(SD.ESDOORN_HERBERG) == 0.0)
	# --- vijanden + art
	var art_bad := []
	for id in ["wortelkruiper", "mistuil", "sporenzwam", "wortelkoning"]:
		var e: Dictionary = GD.ENEMIES[id]
		for k in ["sprite", "sprite_back"]:
			if not ResourceLoader.exists(str(e.get(k, ""))):
				art_bad.append("%s.%s" % [id, k])
		if not ("vuur" in e.get("weak", [])):
			art_bad.append("%s zwakte" % id)
		if not ResourceLoader.exists("res://assets/map_monsters/%s.png" % id):
			art_bad.append("%s map" % id)
	var wk: Dictionary = GD.ENEMIES["wortelkoning"]
	check("Woud-vijanden: voor + rug, zwak voor vuur, map-plaatje (%s)" % [art_bad], art_bad.is_empty())
	check("Wortelkoning: canon-zin in het bestiarium", str(wk["desc"]) == "What was once a shepherd of the wood became a king of roots. He drags what he loves into the depths — not out of cruelty, but out of fear of being alone. Sapientia whispered to him that everything that lets go, perishes.")
	check("The Root King: baas-blok, idle 4x 0,4 s + raak-plaatje, geen kern", wk.has("boss") and int(wk["idle_frames"]) == 4
			and is_equal_approx(float(wk["idle_time"]), 0.4) and ResourceLoader.exists(wk["idle"]) and ResourceLoader.exists(wk["hit"])
			and not wk["boss"].has("core"))
	check("bestiarium 007-010 = de Woud-vijanden", GD.bestiary_ids().slice(6, 10) == ["wortelkruiper", "mistuil", "sporenzwam", "wortelkoning"])
	check("bestiarium 011 = de Mimic (Het Gesimuleerde Archief)", GD.bestiary_ids()[10] == "mimic")
	check("bestiarium 012 = de Ink Worm", GD.bestiary_ids()[11] == "inktwurm")
	var bg: Texture2D = load(GD.backdrop_path("forest_dark"))
	check("bos-achtergrond 1280x432, ook voor de baas in het woud (archief-baas blijft 'boss')",
			bg != null and bg.get_size() == Vector2(1280, 432) and GD.backdrop_id_for("woud", false) == "forest_dark"
			and GD.backdrop_id_for("woud", true) == "forest_dark" and GD.backdrop_id_for("archief", true) == "boss")
	var codex_bad := []
	for id in ["mosslijm", "papiergeest", "glitchmot", "kennis_beest"]:
		var p := str(GD.ENEMIES[id].get("sprite_back", ""))
		if not ResourceLoader.exists(p) or load(p).get_size() != load(GD.ENEMIES[id]["sprite"]).get_size() and id != "kennis_beest":
			codex_bad.append(id)
	check("Codex-art: rugaanzichten van de 4 oude vijanden (zelfde maat), icoon + inschrijf-effect (%s)" % [codex_bad], codex_bad.is_empty()
			and ResourceLoader.exists("res://assets/ui/icons/leeg_boek.png") and ResourceLoader.exists("res://assets/fx/inschrijf.png"))
	var hw := hw_lines()
	var need := ["assets/sprites/noor_dorp.png", "assets/tiles/dungeon/woud_tiles.png", "assets/battle/donker_woud.png",
		"assets/sprites/woud/noor_cocon.png", "assets/sprites/woud/noor_cocon_open.png", "assets/sprites/woud/noor_cocon_puls.png",
		"assets/sprites/enemies/wortelkoning.png", "assets/sprites/enemies/wortelkoning_idle.png", "assets/sprites/enemies/wortelkoning_hit.png",
		"assets/sprites/enemies/mistuil_rug.png", "assets/ui/icons/leeg_boek.png", "assets/fx/inschrijf.png", "art/enemies/mosslijm_rug.png",
		"assets/sprites/enemies/kennis_beest_rug.png"]
	var miss := need.filter(func(f): return not (f in hw))
	check("alle nieuwe RPG ART-bestanden in tools/handwerk.txt (mist %s)" % [miss], miss.is_empty())
	var suno := {
		"main_menu": "bgm_main_menu.ogg",
		"wachtershuis": "bgm_wachtershuis.ogg",
		"vergeten_archieven": "bgm_vergeten_archieven.ogg",
		"gevecht_normaal": "bgm_gevecht_normaal.ogg",
		"gevecht_miniboss": "bgm_gevecht_miniboss.ogg",
		"wereld": "bgm_wereld.ogg",
		"dorp_wilgendal": "bgm_dorp_wilgendal.ogg",
		"donker_woud": "bgm_donker_woud.ogg",
	}
	var suno_bad: Array[String] = []
	for key in suno:
		var bestand := str(suno[key])
		var path := "res://assets/audio/bgm/" + bestand
		var stream: Resource = load(path)
		if not AudioManager.has_music(key) or not (stream is AudioStreamOggVorbis):
			suno_bad.append("%s -> %s" % [key, bestand])
	check("Suno-BGM is ogg-vorbis en staat in het manifest (%s)" % [suno_bad], suno_bad.is_empty())
	var menu_stream: Resource = load("res://assets/audio/bgm/bgm_main_menu.ogg")
	var menu_len := (menu_stream as AudioStream).get_length() if menu_stream is AudioStream else 0.0
	check("titel-ogg is echte muziek (langer dan een minuut)", menu_len > 60.0)
	var loop_bad: Array[String] = []
	for key in ["main_menu", "dorp_wilgendal", "donker_woud"]:
		var lst: Resource = load("res://assets/audio/bgm/" + str(suno[key]))
		if not (lst is AudioStream) or (lst as AudioStream).get_length() < 60.0 or not bool(AudioManager._bgm.get(key, {}).get("loop", false)):
			loop_bad.append(key)
	check("titel, Willowdale en Dark Wood: echte muziek die loopt (%s)" % [loop_bad], loop_bad.is_empty())
	var room_bad: Array[String] = []
	for rid in ["woud_rand", "woud_pad", "woud_mistpoel", "woud_sporenkring", "woud_open_plek"]:
		var ps: PackedScene = load("res://scenes/maps/%s.tscn" % rid)
		var inst := ps.instantiate()
		if str(inst.get("music_track")) != "donker_woud":
			room_bad.append(rid)
		inst.free()
	var dorp: Node = (load("res://scenes/maps/dorp_wilgendal.tscn") as PackedScene).instantiate()
	if str(dorp.get("music_track")) != "dorp_wilgendal":
		room_bad.append("dorp_wilgendal")
	dorp.free()
	check("woudkamers spelen 'donker_woud', het dorp 'dorp_wilgendal' (%s)" % [room_bad], room_bad.is_empty())
	var mp0 := AudioManager.get_node_or_null("MusicPlayer0") as AudioStreamPlayer
	check("muziek speelt op de Music-bus", AudioServer.get_bus_index(AudioManager.BUS_MUSIC) >= 0 and mp0 != null and mp0.bus == AudioManager.BUS_MUSIC)
	var music_player := AudioManager.get_node_or_null("MusicPlayer0") as AudioStreamPlayer
	check("muziekspeler gebruikt stream-playback (web Sample-bus blijft anders stil)",
			music_player != null and music_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)


# ================================================================ B: wereldkaart
func _world_walkable(g: TileMapLayer, t: Vector2i) -> bool:
	var td := g.get_cell_tile_data(t)
	return td != null and not (str(td.get_custom_data("terrain")) in ["berg", "zee"])


func _reachable(g: TileMapLayer, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var t: Vector2i = todo.pop_front()
		if t == to:
			return true
		for d in DIRS:
			var n: Vector2i = t + d
			if not seen.has(n) and _world_walkable(g, n):
				seen[n] = true
				todo.append(n)
	return false


func _world_tests() -> void:
	setup_game()
	var w := await enter(WORLD, "van_esdoorn")
	check("wereldkaart met Mapleton en het Dark Wood", w != null and w.get_node_or_null("Exits/NaarEsdoorn") != null
			and w.get_node_or_null("Exits/NaarWoud") != null)
	check("wereldkaart speelt track 'wereld' (bgm_wereld.ogg)", w != null and w.music_track == "wereld"
			and AudioManager.get_current_music() == "wereld")
	if w == null:
		return
	var ex_e: Node = w.get_node("Exits/NaarEsdoorn")
	var ex_w: Node = w.get_node("Exits/NaarWoud")
	var g: TileMapLayer = w.ground
	var e_tile := Vector2i((ex_e.position / 16.0).floor())
	var w_tile := Vector2i((ex_w.position / 16.0).floor())
	var stairs := Vector2i((w.get_node("Spawns/van_archief").position / 16.0).floor())
	check("Mapleton en het woud lopend bereikbaar vanaf de Archives", _reachable(g, stairs, e_tile) and _reachable(g, stairs, w_tile))
	check("iconen uit de 2e atlas (geen monsters: 'stad')", g.get_cell_source_id(e_tile) == 1 and g.get_cell_source_id(w_tile) == 1
			and w.terrain_at(e_tile) == "stad" and w.terrain_at(w_tile) == "stad")
	# zonder Golem: dicht
	await walk("move_up", 1)
	var blocked := await wait_until(func(): return Dialog.is_open, 2.0)
	check("VOOR de Golem: Mapleton dicht ('%s')" % Dialog.text_label.text, blocked and scene().name == "Wereldkaart"
			and Dialog.text_label.text.contains("Mapleton"))
	await close_dialog()
	await pframes(10)
	check("... en je blijft op de wereldkaart", scene().name == "Wereldkaart" and not GameState.changing_map)
	# het woud: zonder opdracht dicht
	player().place_at(w_tile + Vector2i.RIGHT, Vector2i.LEFT)
	await frames(3)
	await walk("move_left", 1)
	blocked = await wait_until(func(): return Dialog.is_open, 2.0)
	check("zonder opdracht: het Dark Wood dicht", blocked and scene().name == "Wereldkaart")
	await close_dialog()
	await pframes(10)
	# na de Golem: open (echt erheen lopen)
	GameState.story_flags[SD.GOLEM_FLAG] = true
	player().place_at(e_tile + Vector2i(0, 2), Vector2i.UP)
	await frames(3)
	await walk("move_up", 1)
	check("NA de Golem: Mapleton open (dorp geladen)", await wait_scene("Esdoorn"))


# ================================================================ C: Esdoorn
func _village_tests() -> void:
	if scene() == null or scene().name != "Esdoorn":
		await enter(SD.ESDOORN, "zuid_ingang")
	var v := scene()
	check("ontmoeting start vanzelf bij binnenkomst", await wait_until(func(): return Story.running, 3.0)
			and Story.current_event == "noor_ontmoeting")
	var noor: Node = v.get_node_or_null("Objects/Vesper")
	check("Vesper op het plein met haar loopsprite (noor_dorp.png, RPG ART)", noor != null and noor.visible
			and str(noor.sprite.texture.resource_path).ends_with("noor_dorp.png"))
	var balloon := [false]
	var lines := await run_story(60.0, "Jou ken ik niet", "noor_ballon")
	# ballon-check: de eerste Noor-regel had een spreker-node (Noor) en de ballonstijl
	check("blauwe ballonnen met namen (Vesper, %s, Marigold): %d regels" % [GameState.player_name, lines.size()],
			lines.any(func(l): return str(l).begins_with("Vesper: ")) and lines.any(func(l): return str(l).begins_with("Marigold: "))
			and lines.any(func(l): return str(l).begins_with(GameState.player_name + ": ")))
	check("eindigt met de opdracht (dorpeling vraagt Vesper te redden)", lines.any(func(l): return "save her" in str(l))
			and lines.any(func(l): return "New quest: Save Vesper from the Dark Wood" in str(l)))
	check("vlaggen: noor_ontmoet + quest_noor, stap NOOR_KWIJT", Story.has_flag("noor_ontmoet") and Story.has_flag("quest_noor")
			and GameState.story_step == SD.NOOR_KWIJT)
	check("Vesper is weg (meegesleurd), de wortelgreep ook", not noor.visible and not v.get_node("Objects/WortelGreep").visible)
	check("opdracht loopt: '%s'" % Story.active_quest(), Story.active_quest() == "Save Vesper from the Dark Wood")
	check("Codex: Marigold geeft 3 Blank Books na de ontmoeting (geen startvoorraad) (%d)" % GameState.item_count("leeg_boek"),
			GameState.item_count("leeg_boek") == 3 and Story.has_flag("marit_boeken") and not GD.START_INVENTORY.has("leeg_boek")
			and lines.any(func(l): return "3x Blank Book" in str(l)))
	# veldmenu: regel met de opdracht
	v.open_field_menu()
	await pframes(4)
	var fm: Node = v.get_node_or_null("FieldMenu")
	check("veldmenu: 'Opdracht' + 'Red Vesper uit het Dark Wood'", fm != null and fm.quest_label != null
			and fm.quest_label.text == "Save Vesper from the Dark Wood" and fm.quest_label.is_visible_in_tree())
	await v17_shot("veldmenu_opdracht")
	if fm:
		fm.close()
	await pframes(6)
	# eenmalig: opnieuw binnenkomen = geen cutscene
	var n_before := count_in_history("noor_ontmoeting")
	await enter(WORLD, "van_esdoorn")
	v = await enter(SD.ESDOORN, "zuid_ingang")
	await get_tree().create_timer(0.8).timeout
	check("ontmoeting maar één keer (geschiedenis %d -> %d, nu geen event)" % [n_before, count_in_history("noor_ontmoeting")],
			count_in_history("noor_ontmoeting") == n_before and n_before == 1 and not Story.running)
	# dorpelingen met hints over het woud
	var hints := 0
	for n in ["Marit", "Bram", "Jens", "Tobias"]:
		var npc: Node = v.get_node_or_null("Objects/" + n)
		if npc and npc.event != "" and Story.trigger(npc.event, npc):
			var ls := await run_story(10.0)
			if ls.any(_is_hint):
				hints += 1
	check("4 dorpelingen, korte hints over het donkere bos (%d/4)" % hints, hints == 4)
	# dorp-screenshot: op het plein
	player().place_at(Vector2i(22, 18), Vector2i.UP)
	await get_tree().create_timer(0.4).timeout
	await v17_shot("dorp")
	# huis van Noor: echt naar binnen
	player().place_at(Vector2i(12, 12), Vector2i.UP)
	await frames(3)
	await walk("move_up", 1)
	if not GameState.changing_map:
		await press_interact()
	check("huis van Vesper is te betreden", await wait_scene("EsdoornHuisNoor"))
	var ilse: Node = scene().get_node_or_null("Objects/Ilse")
	check("binnen: Elise (moeder van Vesper)", ilse != null and ilse.event == "ilse")
	await wait_fade()
	await walk("move_down", 2)
	check("deur uit = terug in Mapleton voor het huis", await wait_scene("Esdoorn") and tile() == Vector2i(12, 12))
	await get_tree().create_timer(0.5).timeout
	# herberg: rusten + opslagboek
	var h := await enter(SD.ESDOORN_HERBERG, "binnen")
	check("herberg met opslagboek en waard", h != null and h.get_node_or_null("Objects/SaveBook") != null
			and h.get_node("Objects/SaveBook").type == "save" and h.get_node_or_null("Objects/Waard") != null)
	GameState.party[0]["hp"] = 1
	Story.trigger("herbergier", h.get_node("Objects/Waard"))
	await run_story(15.0)
	check("herberg: uitrusten = HP/MP vol", int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"]))
	var locked: Node = (await enter(SD.ESDOORN, "voor_dicht")).get_node_or_null("Objects/Deur_voor_dicht")
	check("derde huis op slot (deur met tekst)", locked != null and locked.target_map == "" and locked.lines.size() >= 1)


func _is_hint(l) -> bool:
	var t := str(l).to_lower()
	for w in ["wood", "forest", "root", "mist", "mushroom"]:
		if w in t:
			return true
	return false


# ================================================================ D: Donker Woud
func _forest_tests() -> void:
	var w := await enter(WORLD, "van_woud")
	var wt := Vector2i((w.get_node("Exits/NaarWoud").position / 16.0).floor())
	player().place_at(wt + Vector2i.RIGHT, Vector2i.LEFT)
	await frames(3)
	await walk("move_left", 1)
	check("met de opdracht: het Dark Wood in (Wood's Edge)", await wait_scene("WoudRand"))
	await wait_fade()
	var r := scene()
	check("thema: woud-tegels, terrein 'woud', tint + mist", r.ground.tile_set.get_source(0).texture.resource_path.ends_with("woud_tiles.png")
			and r.terrain_at(Vector2i(5, 9)) == "woud" and r.get_node_or_null("ThemaTint") != null and r.get_node_or_null("WoudMist") != null)
	var ov: TileMapLayer = r.get_node_or_null("Overlay")
	check("overlay-laag (kruinen + mist) boven de speler, zonder botsing", ov != null and ov.z_index > player().z_index
			and ov.get_cell_atlas_coords(Vector2i(5, 3)) == Vector2i(76 % 16, 76 / 16)
			and ov.tile_set.get_source(0).get_tile_data(Vector2i(12, 4), 0).get_collision_polygons_count(0) == 0)
	check("boomvoet massief (96 op 5,5), wortels beloopbaar", r.cell(Vector2i(5, 5)) == 96 and r.is_wall(Vector2i(5, 5))
			and not r.is_wall(Vector2i(11, 9)))
	await pframes(3)
	check("glitch: zwakst bij de ingang (Crt %.2f)" % Crt.glitch_intensity, is_equal_approx(Crt.glitch_intensity, DR.GLITCH_MIN))
	# echt door de boog naar het Wortelpad
	await freeze_monsters(r)
	for m in r.monsters.duplicate():
		m.queue_free()
	r.monsters.clear()
	player().place_at(Vector2i(10, 3), Vector2i.UP)
	await frames(3)
	await walk("move_up", 1)
	check("Wood's Edge -> (boog) -> Root Path", await wait_scene("WoudPad"))
	await wait_fade()
	# alle kamers verbonden: per uitgang de scène in en op het juiste spawnpunt
	var conn_bad := []
	for e in WR.ORDER:
		var rd: Dictionary = WR.ROOMS[e[0]]
		for k in rd["exits"]:
			var ex: Dictionary = rd["exits"][k]
			var s := await enter(ex["map"], ex["spawn"])
			var sp: Node = s.get_node_or_null("Spawns/" + ex["spawn"]) if s else null
			if s == null or sp == null or tile() != Vector2i((sp.position / 16.0).floor()):
				conn_bad.append("%s/%s" % [e[0], k])
	check("alle uitgangen van de 5 woudkamers werken (%s)" % [conn_bad], conn_bad.is_empty())
	# Kernkracht: verlamt een woudmonster
	GameState.grant_kern("golemkern", "kennis_beest")
	GameState.pending_kern_absorb = ""
	r = await enter("res://scenes/maps/woud_pad.tscn", "zuid")
	await freeze_monsters(r)
	var stunned := false
	var v: Node = r.get_node("KernKracht")
	for m in r.monsters:
		for d in DIRS:
			var start: Vector2i = m.tile - d * 2
			if r.is_wall(start) or not v.blocker_at(start).is_empty() or start == m.tile:
				continue
			var tr: Dictionary = v.trace(start, d)
			if tr["kind"] != "monster" or tr["node"] != m:
				continue
			player().place_at(start, d)
			await frames(3)
			await wait_until(func(): return v.can_fire() == "", 3.0)
			Input.action_press("kern")
			await wait_until(func(): return v.busy, 1.0)
			Input.action_release("kern")
			await wait_until(func(): return not v.busy, 4.0)
			stunned = m.is_stunned()
			break
		if stunned:
			break
	check("Kernkracht-stun werkt op een woudmonster", stunned)
	# kamer-screenshot (overlay + mist) in de Mistpoel
	r = await enter("res://scenes/maps/woud_mistpoel.tscn", "zuid")
	await freeze_monsters(r)
	await pframes(3)
	check("glitch sterker dieper in het woud (Mist Pool %.2f > ingang)" % Crt.glitch_intensity, Crt.glitch_intensity > DR.GLITCH_MIN + 0.1)
	player().place_at(Vector2i(9, 11), Vector2i.UP)
	await get_tree().create_timer(0.5).timeout
	await v17_shot("woud_kamer")
	# de baas
	r = await enter(SD.WOUD_BAAS, "zuid")
	await pframes(3)
	var cocon: Node = r.get_node_or_null("Objects/Cocon")
	var boss: Node = r.get_monster("baas")
	check("open plek: Vesper in de cocon (puls) achter de Root King", cocon != null and cocon.visible and cocon.looping
			and str(cocon.sprite.texture.resource_path).ends_with("noor_cocon_puls.png") and boss != null and boss.boss
			and not r.get_node("Objects/Vesper").visible and not r.get_node("Objects/CoconOpen").visible)
	check("glitch maximaal bij de baas (%.2f)" % Crt.glitch_intensity, Crt.glitch_intensity == 1.0)
	# screenshot: Noor in de (pulserende) cocon achter de Wortelkoning
	await freeze_monsters(r)
	player().place_at(Vector2i(9, 7), Vector2i.UP)
	await get_tree().create_timer(0.6).timeout
	await v17_shot("noor_cocon")
	var lv := int(GameState.party[0]["level"])
	r.start_monster_battle(boss)
	check("baasgevecht gestart", await wait_scene("Battle"))
	var b := battle()
	check("bos-achtergrond (forest_dark) in het baasgevecht, niet vluchten", GameState.pending_backdrop_id == "forest_dark"
			and GameState.pending_boss and b != null and not b.can_flee)
	var g: Dictionary = b.enemies[0] if b and not b.enemies.is_empty() else {}
	check("The Root King: baas-stats en idle-animatie", not g.is_empty() and int(g["s"]["max_hp"]) == int(GD.ENEMIES["wortelkoning"]["boss"]["max_hp"])
			and g["node"].has_meta("idle_frames"))
	await wait_battle_state(["command"], 20)
	await get_tree().create_timer(0.6).timeout
	await v17_shot("woud_baas")
	if shots != "":
		await v17_shot("woud_achtergrond")
	check("baas verslagen", await win_battle())
	check("terug op de open plek", await wait_scene("WoudOpenPlek"))
	check("Vesper-bevrijding start vanzelf", await wait_until(func(): return Story.running, 3.0) and Story.current_event == "noor_bevrijd")
	var ls := await run_story(60.0, "Ik ga met je mee", "noor_erbij")
	check("tekst: Vesper joins the party + quest complete", ls.any(func(l): return "Vesper joins the party" in str(l))
			and ls.any(func(l): return "Quest complete" in str(l)))
	var noor := {}
	for h in GameState.party:
		if h["id"] == "noor":
			noor = h
	var lv_now := int(GameState.party[0]["level"])     # (de baas gaf EXP: Dennis kan gestegen zijn)
	check("Vesper in de groep (niveau Dax-1 = %d, Dax was Lv %d voor de baas, gevechtsplaatje noor.png)" % [lv_now - 1, lv], not noor.is_empty()
			and int(noor["level"]) == lv_now - 1 and str(noor["battle_sprite"]).ends_with("battle/noor.png"))
	check("Vesper draagt Oak Staff + Travel Robe, HP/MP vol", not noor.is_empty() and noor["equip"]["wapen"] == "eiken_staf"
			and noor["equip"]["harnas"] == "reisgewaad" and int(noor["hp"]) == int(noor["max_hp"]) and int(noor["mp"]) == int(noor["max_mp"]))
	check("opdracht klaar: noor_gered + noor_lid, stap NOOR_GERED, geen lopende opdracht", Story.has_flag("noor_gered")
			and Story.has_flag("noor_lid") and Story.has_flag(SD.WORTELKONING_FLAG) and GameState.story_step == SD.NOOR_GERED and Story.active_quest() == "")
	r = scene()
	check("open plek daarna: lege cocon, geen Vesper-NPC, geen baas", r.get_node("Objects/CoconOpen").visible and not r.get_node("Objects/Cocon").visible
			and not r.get_node("Objects/Vesper").visible and r.get_monster("baas") == null)
	var n_b := count_in_history("noor_bevrijd")
	await enter(SD.WOUD_BAAS, "zuid")
	await get_tree().create_timer(0.8).timeout
	check("bevrijding maar één keer", count_in_history("noor_bevrijd") == n_b and not Story.running and scene().get_monster("baas") == null)


# ================================================================ E: opslaan/laden
func _save_tests() -> void:
	var p := player()
	var flags_want := ["noor_ontmoet", "quest_noor", "noor_gered", "noor_lid", SD.GOLEM_FLAG, SD.WORTELKONING_FLAG]
	var lv_noor := GameState.member_level("noor")
	check("opslaan in het woud", GameState.save_game(p.get_tile(), p.facing))
	GameState.new_game("Iemand")
	check("(nieuw spel: alles weg)", not GameState.has_member("noor") and not Story.has_flag("noor_gered"))
	check("laden", GameState.load_game())
	var miss := flags_want.filter(func(f): return not Story.has_flag(f))
	check("vlaggen terug (mist %s), stap %d" % [miss, GameState.story_step], miss.is_empty() and GameState.story_step == SD.NOOR_GERED)
	var noor := {}
	for h in GameState.party:
		if h["id"] == "noor":
			noor = h
	check("Vesper terug in de groep (Lv %d, Oak Staff)" % lv_noor, not noor.is_empty() and int(noor["level"]) == lv_noor
			and noor["equip"]["wapen"] == "eiken_staf")
	GameState.continue_game()
	check("verder spelen: op de open plek, geen cutscene", await wait_scene("WoudOpenPlek") and not Story.running)
	await get_tree().create_timer(0.6).timeout
	check("ook na laden geen bevrijding/baas meer", not Story.running and scene().get_monster("baas") == null)
	# halverwege: opdracht loopt, Noor nog niet gered
	GameState.story_flags.erase("noor_gered")
	GameState.story_flags.erase("noor_lid")
	GameState.story_flags.erase(SD.WORTELKONING_FLAG)
	GameState.story_step = SD.NOOR_KWIJT
	check("opslaan halverwege", GameState.save_game(Vector2i(9, 10), Vector2i.UP))
	GameState.new_game("Iemand")
	GameState.load_game()
	check("halverwege geladen: opdracht loopt nog ('%s'), ontmoeting niet opnieuw" % Story.active_quest(),
			Story.active_quest() == "Save Vesper from the Dark Wood" and Story.has_flag("noor_ontmoet"))


# ================================================================ F: Codex + wereldkaart-iconen
func _codex_forest_tests() -> void:
	# --- data: Lege Boeken in woudkisten, vangbare woudmonsters, Wortelkoning niet
	var books := 0
	for e in DR.woud().ORDER:
		for c in DR.room(e[0]).get("chests", []):
			if c["item"] == CD.BOOK_ITEM:
				books += int(c.get("n", 1))
	check("Blank Books in kisten van het Dark Wood (%d)" % books, books >= 1 and books <= 2)
	check("Root Crawler, Mist Owl, Spore Cap vangbaar; The Root King niet",
			["wortelkruiper", "mistuil", "sporenzwam"].all(func(x): return CD.capture_chance(x, 1, 100) > 0.5)
			and not CD.has_species("wortelkoning") and CD.capture_chance("wortelkoning", 1, 100) == 0.0)
	# --- oude save: ontmoeting al gezien, nog geen boeken -> Marit geeft ze bij een gesprek (eenmalig)
	setup_game(11)
	for f in [SD.GOLEM_FLAG, "noor_ontmoet", "quest_noor"]:
		GameState.story_flags[f] = true
	GameState.story_step = SD.NOOR_KWIJT
	var v := await enter(SD.ESDOORN, "zuid_ingang")
	var marit: Node = v.get_node_or_null("Objects/Marit") if v else null
	var got := 0
	for i in 2:
		if marit and Story.trigger(marit.event, marit):
			await run_story(15.0)
		got = GameState.item_count(CD.BOOK_ITEM) if i == 0 else got
	check("oude save: Marigold geeft 3 Blank Books bij een gesprek, maar één keer (%d, daarna %d)" % [got, GameState.item_count(CD.BOOK_ITEM)],
			got == 3 and GameState.item_count(CD.BOOK_ITEM) == 3)
	# --- wereldkaart met de iconen van RPG ART
	var w := await enter(WORLD, "van_esdoorn")
	var g: TileMapLayer = w.get_node("Ground") if w else null
	check("wereldkaart: Mapleton (47-48, 24-25) en woudingang (42, 26) uit wereld_v17_iconen.png (RPG ART, handwerk)",
			g != null and g.get_cell_source_id(Vector2i(47, 24)) == 1 and g.get_cell_atlas_coords(Vector2i(48, 25)) == Vector2i(3, 0)
			and g.get_cell_source_id(Vector2i(42, 26)) == 1 and g.get_cell_atlas_coords(Vector2i(42, 26)) == Vector2i(4, 0)
			and "assets/tiles/wereld_v17_iconen.png" in hw_lines())
	player().place_at(Vector2i(45, 27), Vector2i.DOWN)
	await get_tree().create_timer(0.5).timeout
	await v17_shot("wereld_esdoorn")
	check("map-sprites woudmonsters/baas van RPG ART (handwerk)", ["wortelkruiper", "mistuil", "sporenzwam", "wortelkoning"].all(
			func(x): return ("assets/map_monsters/%s.png" % x) in hw_lines()))
	# --- vangen in het woud: Leeg Boek op een Wortelkruiper (bos-achtergrond)
	GameState.story_flags.erase(SD.WORTELKONING_FLAG)
	var r := await enter("res://scenes/maps/woud_pad.tscn", "zuid")
	if r == null:
		check("woud_pad geladen", false)
		return
	await freeze_monsters(r)
	r.start_monster_battle(r.get_monster("m1"))
	check("woudgevecht gestart", await wait_scene("Battle"))
	var b := battle()
	if b == null:
		return
	await wait_battle_state(["command"], 20)
	var e: Dictionary = b.enemies[0]
	e["s"]["hp"] = 1
	b.codex.force_roll = 0.0
	await pframes(4)
	await cross_to(b, 2)     # Item
	await tap("interact")
	var ok := await wait_until(func(): return b.menu.visible, 3.0)
	var k: int = b._available_items().find(CD.BOOK_ITEM)
	if ok and k >= 0:
		b.menu.select(k)
		await pframes(2)
		await tap("interact")
		if await wait_battle_state(["target_enemy"], 5) == "target_enemy":
			for i in 6:
				if b.target_list[b.target_index] == e:
					break
				await tap("move_right")
			await tap("interact")
	check("inschrijf-effect op de Root Crawler", await wait_until(func(): return b.codex.fx_node != null and is_instance_valid(b.codex.fx_node), 6.0))
	await wait_until(func(): return b.codex.fx_node == null or int(b.codex.fx_node.get("frame")) >= 2, 2.0)
	await v17_shot("codex_vangen")
	await wait_until(func(): return not (str(b.codex.last_capture.get("result", "")) in ["", "bezig"]), 8.0)
	check("Root Crawler ingeschreven (%s), boek op (2 over)" % [b.codex.last_capture.get("result")],
			b.codex.last_capture.get("result") == "gelukt" and GameState.item_count(CD.BOOK_ITEM) == 2)
	await win_battle()
	await wait_scene("WoudPad")
	await wait_fade()
	check("pagina Root Crawler = bondgenoot", GameState.codex_pages.size() == 1 and GameState.codex_pages[0]["species"] == "wortelkruiper"
			and GameState.codex_active == GameState.codex_pages[0]["uid"])
	# --- bondgenoot vecht mee in het woud (rugaanzicht van RPG ART)
	r = scene()
	await freeze_monsters(r)
	r.start_monster_battle(r.get_monster("m2"))
	check("2e woudgevecht", await wait_scene("Battle"))
	b = battle()
	if b == null:
		return
	await wait_battle_state(["command"], 20)
	var ally := {}
	for c in b.heroes:
		if c.get("ally", false):
			ally = c
	check("Root Crawler vecht mee naast Dax (bos-achtergrond %s)" % GameState.pending_backdrop_id, not ally.is_empty()
			and GameState.pending_backdrop_id == "forest_dark")
	b.codex.force_skill = "wortelgreep"
	b.codex.last_ally_action = {}
	for x in b.enemies:
		x["s"]["hp"] = 300
		x["s"]["max_hp"] = 300
		x["s"]["atk"] = 0
	await pframes(4)
	await cross_to(b, 3)     # Verdedig
	await tap("interact")
	var acted := await wait_until(func(): return not b.codex.last_ally_action.is_empty(), 15.0)
	await pframes(9)
	await v17_shot("codex_bondgenoot")
	check("bondgenoot gebruikt zelf Root Grip %s" % [b.codex.last_ally_action], acted and b.codex.last_ally_action.get("skill") == "wortelgreep")
	await win_battle()
	await wait_scene("WoudPad")
	await wait_fade()
	# --- veldmenu > Codex
	GameState.codex_add("mistuil", 4)
	scene().open_field_menu()
	await pframes(4)
	var fm: Node = scene().get_node_or_null("FieldMenu")
	if fm == null:
		check("veldmenu open", false)
		return
	fm.choose("codex")
	await pframes(6)
	var cs: Node = fm.get_node_or_null("Codex")
	check("Codex-scherm in het veldmenu (2 pagina's + Geen)", cs != null and cs.entries.size() == 3)
	await v17_shot("codex_scherm")
	fm.close()
	await pframes(6)


# ================================================================ G: Het Zingende Graan
func _gerrit_citaten() -> Array:
	var out: Array = []
	for ev in SD.EVENTS:
		for v in SD.EVENTS[ev]:
			var cmds = v.get("do", [])
			if not (cmds is Array):
				continue
			for cmd in cmds:
				if not (cmd is Array) or cmd.is_empty():
					continue
				if str(cmd[0]) == "say" and cmd.size() >= 3 and str(cmd[1]) == SD.GERRIT:
					for line in cmd[2]:
						out.append(str(line))
				elif str(cmd[0]) == "choice" and cmd.size() >= 5 and str(cmd[4]) == SD.GERRIT:
					out.append(str(cmd[1]))
	return out


func _magenta(c: Color) -> bool:
	return c.a > 0.9 and c.r > 0.9 and c.b > 0.8 and c.g < 0.2


func _mist_naast(room: Dictionary, t: Vector2i) -> bool:
	var mist := {}
	for m in room.get("mist", []):
		for i in int(m[2]):
			mist[Vector2i(int(m[0]) + i, int(m[1]))] = true
	if mist.has(t):
		return false
	for d in DIRS:
		if mist.has(t + d):
			return true
	return false


## Tekst doorklikken tot er een keuze staat. Geeft de geziene regels terug.
func lines_until_choice(timeout := 20.0) -> Array:
	var seen: Array = []
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if Dialog.is_open:
			var line := "%s: %s" % [Dialog.name_label.text, Dialog.text_label.text]
			if seen.is_empty() or seen[seen.size() - 1] != line:
				seen.append(line)
			if Dialog._is_typing():
				await frames(2)
				continue
			if Dialog.has_choices():
				return seen
			await press_interact()
			continue
		if not Story.running and not Dialog.is_open:
			await pframes(4)
			if not Story.running and not Dialog.is_open:
				return seen
		await get_tree().process_frame
	return seen


func _graan_data() -> void:
	var q: Array = SD.QUESTS.filter(func(x): return x["id"] == "zingend_graan")
	check("opdracht Het Zingende Graan (start na het gesprek, klaar als de molen maalt)", q.size() == 1
			and q[0]["title"] == "Het Zingende Graan" and q[0]["start_flag"] == SD.FLAG_GRAAN
			and q[0]["done_flag"] == SD.FLAG_GRAAN_KLAAR)
	var quotes := _gerrit_citaten()
	var canon := [SD.QUOTE_GRAAN_BEZOEK, SD.QUOTE_GRAAN_WIND, SD.QUOTE_GRAAN_OP, SD.QUOTE_GRAAN_OUD,
			SD.QUOTE_GRAAN_ZOEK, SD.QUOTE_GRAAN_VOORZICHTIG, SD.QUOTE_GRAAN_WACHT, SD.QUOTE_GRAAN_ZONDER,
			SD.QUOTE_GRAAN_ZAAD, SD.QUOTE_GRAAN_DANK]
	var mist: Array = []
	for l in canon:
		if not quotes.has(l):
			mist.append(l)
	var src := FileAccess.get_file_as_string("res://scripts/data/story_data.gd")
	var todo_op_zin := false
	for l in canon:
		var at := src.find(l)
		if at < 0:
			todo_op_zin = true
			break
		var einde := src.find("\n", at)
		if src.substr(at, einde - at).contains("TODO(verhaal)"):
			todo_op_zin = true
	var keuze: Array = []
	for v in SD.EVENTS["gerrit"]:
		for cmd in v.get("do", []):
			if cmd is Array and cmd.size() >= 3 and str(cmd[0]) == "choice":
				keuze = cmd[2]
	var speler_vraagt := false
	for v in SD.EVENTS["gerrit"]:
		for cmd in v.get("do", []):
			if cmd is Array and cmd.size() >= 3 and str(cmd[0]) == "say" and str(cmd[1]) == "{naam}":
				speler_vraagt = cmd[2].has(SD.QUOTE_GRAAN_VRAAG)
	check("Garrett zegt de canon-zinnen, zonder TODO(verhaal) en zonder de oude twee", mist.is_empty()
			and quotes.size() == canon.size()
			and not quotes.has("Het zaad zingt aan de rand van de mist.")
			and not quotes.has("De molen kan weer malen.")
			and not todo_op_zin and not SD.TODO_STORY.has("gerrit")
			and SD.QUOTE_GRAAN_VRAAG == "What happened?" and speler_vraagt
			and keuze == [SD.KEUZE_GRAAN_JA, SD.KEUZE_GRAAN_NEE]
			and SD.EVENTS["gerrit_ja"][0]["do"][0][0] == "flag"
			and SD.EVENTS["gerrit_weigert"][0]["do"][0][0] == "say")
	var namen: Array = []
	for v in SD.EVENTS["gerrit"]:
		var cond: Dictionary = v.get("if", {})
		if cond.get("flags", []).has(SD.FLAG_ZAAD) and cond.get("not_flags", []).has(SD.FLAG_GRAAN_KLAAR):
			for cmd in v.get("do", []):
				if cmd is Array and not cmd.is_empty():
					namen.append(str(cmd[0]))
	check("zangscène en zang tussen herkenning en de molen", namen == ["flag", "take", "flag", "say", "molen_zang", "zang", "molen"])   # v0.24: eerst gesproken_gerrit (Quest Log)
	# v3: reuzenmolen v2 (RPG ART): draaiende sheet 4 frames 224x224 (22.5 graden per frame, naadloos)
	# en stille, versleten wieken als losse 224x224.
	var art: Texture2D = load(Wieken.ART)
	var stil_art: Texture2D = load(Wieken.ART_STIL)
	var basis_art: Texture2D = load(Wieken.ART_BASIS)
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	check("reuzenmolen-art: basis 224x320, wieken 4 frames 224x224, stil 224x224, 5 fps", art != null and stil_art != null
			and basis_art != null and basis_art.get_width() == 224 and basis_art.get_height() == 320
			and art.get_width() == Wieken.FRAME_W * Wieken.FRAMES and art.get_height() == Wieken.FRAME_H
			and stil_art.get_width() == 224 and stil_art.get_height() == 224
			and hw.contains("assets/sprites/buiten/wilgendal/windmolen_wieken_v2.png")
			and hw.contains("assets/sprites/buiten/wilgendal/windmolen_wieken_stil_v2.png")
			and Wieken.STAPPEN == 4 and is_equal_approx(Wieken.STAP_GRADEN, 22.5)
			and is_equal_approx(Wieken.STAP_TIJD, 0.2))
	var toon := Wieken.maak_zang()
	var top := Wieken.piek(toon)
	check("zacht gezang uit de noten in de data", SD.MOLEN_ZANG.size() == 5 and SD.MOLEN_NODE == "MolenWieken"
			and Wieken.piek(Wieken.maak_toon([], 0.2)) == 0.0
			and top > 0.04 and top < 0.2
			and absf(toon.get_length() - SD.MOLEN_ZANG_SEC) < 0.02)
	var geesten: Dictionary = {}
	for n in WR.ROOMS["woud_open_plek"].get("npcs", []):
		if str(n.get("name", "")) == "Woudgeesten":
			geesten = n
	var t := Vector2i(int(geesten.get("tile", [0, 0])[0]), int(geesten.get("tile", [0, 0])[1]))
	check("zaad op de grens van mist en open plek", not geesten.is_empty() and geesten["event"] == "zingend_zaad"
			and _mist_naast(WR.ROOMS["woud_open_plek"], t)
			and geesten["show_if"]["flags"] == ["quest_zingend_graan"]
			and geesten["show_if"]["not_flags"] == ["zingend_zaad"])
	var gevecht: Array = SD.EVENTS["zingend_zaad"][0]["do"][0]
	check("mini-gevecht: twee woudgeesten, daarna het zaad", gevecht[0] == "battle" and gevecht[1] == ["woudgeest", "woudgeest"]
			and str(gevecht[2]["after"]) == "zingend_zaad_na")
	var wg: Dictionary = GD.ENEMIES["woudgeest"]
	# v0.21: eigen art van RPG ART (batch 7), niet meer de Mosslijm-plaatsvervanger.
	var wg_kaart: Texture2D = load("res://assets/map_monsters/woudgeest.png")
	check("Woudgeest is klein, hoort in het woud, eigen art (voor/rug 90x90, kaart 32x64)", wg["name"] == "Wood Wraith" and int(wg["max_hp"]) <= 16
			and "woud" in wg["habitat"] and not bool(wg.get("art_pending", false)) and not GD.enemy_sprite_is_placeholder(wg)
			and GD.enemy_sprite(wg) == "res://assets/sprites/enemies/woudgeest.png"
			and (load(GD.enemy_sprite(wg)) as Texture2D).get_size() == Vector2(90, 90)
			and ResourceLoader.exists(str(wg["sprite_back"])) and wg_kaart != null and wg_kaart.get_size() == Vector2(32, 64))
	check("bestiarium 007-012 blijft gelijk", GD.bestiary_ids().slice(6, 12) == ["wortelkruiper", "mistuil", "sporenzwam", "wortelkoning", "mimic", "inktwurm"])
	check("Zingend Zaad is een sleutel, Zingend Meel geneest", GD.KEY_ITEMS[SD.ITEM_ZAAD]["name"] == "Singing Seed"
			and GD.ITEMS[SD.ITEM_MEEL]["name"] == "Singing Flour" and int(GD.ITEMS[SD.ITEM_MEEL]["heal_hp"]) > 0
			and PartyActions.item_usable_in_field(SD.ITEM_MEEL) and not PartyActions.item_usable_in_field(SD.ITEM_ZAAD))


func _graan_tests() -> void:
	_graan_data()
	setup_game()
	var dorp := "res://scenes/maps/dorp_wilgendal.tscn"
	var d := await enter(dorp, "zuid_ingang")
	var g: Node = d.get_node("Objects/Gerrit")
	check("één Garrett de Molenaar, zonder Goedendag", g != null and g.npc_name == SD.GERRIT and g.lines.is_empty()
			and g.event == "gerrit" and d.get_node("Objects").get_children().filter(func(n): return n.name == "Gerrit").size() == 1)
	var wieken: Node = d.get_node_or_null("Objects/MolenWieken")
	check("molen staat stil tot het zaad binnen is", wieken != null and not wieken.draait() and wieken.frame_nu() == 0
			and not wieken.glow_aan() and not wieken.gezongen
			and wieken.sprite.texture == Wieken.wieken_stil() and wieken.stil() and wieken.sprite.hframes == 1)
	Story.trigger("gerrit", g)
	var dicht: Array = await run_story(6.0)
	check("quest dicht vóór Vesper", not Story.has_flag("noor_lid") and not Story.has_flag(SD.FLAG_GRAAN)
			and Story.active_quest() == "" and GameState.item_count(SD.ITEM_ZAAD) == 0
			and not dicht.any(func(l): return SD.QUOTE_GRAAN_BEZOEK in str(l) or SD.QUOTE_GRAAN_DANK in str(l) or SD.QUOTE_GRAAN_WACHT in str(l)))
	GameState.story_flags["noor_lid"] = true
	GameState.add_member("noor")
	Story.trigger("gerrit", g)
	var eerste: Array = await lines_until_choice(40.0)
	check("eerste keer: bezoek, wind, vraag en het zingende graan", eerste.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_BEZOEK))
			and eerste.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_WIND))
			and eerste.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_VRAAG))
			and eerste.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_OP))
			and Dialog.text_label.text == SD.QUOTE_GRAAN_OUD
			and Dialog.choices == [SD.KEUZE_GRAAN_JA, SD.KEUZE_GRAAN_NEE]
			and not Story.has_flag(SD.FLAG_GRAAN) and Story.active_quest() == "")
	Dialog.choose(1)
	var weg: Array = await run_story(8.0)
	check("weigeren: de molen wacht, quest nog uit", weg.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_WACHT))
			and not Story.has_flag(SD.FLAG_GRAAN) and Story.active_quest() == "" and GameState.item_count(SD.ITEM_ZAAD) == 0)
	Story.trigger("gerrit", g)
	await lines_until_choice(40.0)
	check("later nog dezelfde keuze", Dialog.choices == [SD.KEUZE_GRAAN_JA, SD.KEUZE_GRAAN_NEE] and not Story.has_flag(SD.FLAG_GRAAN))
	Dialog.choose(0)
	var ja: Array = await run_story(15.0)
	check("aannemen: zoek het Zingend Zaad", ja.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_ZOEK))
			and ja.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_VOORZICHTIG))
			and Story.has_flag(SD.FLAG_GRAAN) and Story.active_quest() == "Het Zingende Graan"
			and not Story.has_flag(SD.FLAG_ZAAD))
	Story.trigger("gerrit", g)
	var zonder: Array = await run_story(8.0)
	check("terug zonder zaad", zonder.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_ZONDER))
			and Story.has_flag(SD.FLAG_GRAAN) and not Story.has_flag(SD.FLAG_ZAAD)
			and Story.active_quest() == "Het Zingende Graan"
			and not zonder.any(func(l): return Molen.REGEL_RUST in str(l) or SD.QUOTE_GRAAN_ZAAD in str(l)))
	GameState.story_flags["noor_gered"] = true
	GameState.story_flags[SD.WORTELKONING_FLAG] = true
	GameState.story_flags.erase(SD.FLAG_GRAAN)
	var plek := await enter(SD.WOUD_BAAS, "zuid")
	await get_tree().create_timer(0.6).timeout
	var geest: Node = plek.get_node_or_null("Objects/Woudgeesten")
	check("zonder opdracht geen woudgeesten", geest != null and not geest.visible and not Story.running)
	GameState.story_flags[SD.FLAG_GRAAN] = true
	plek = await enter(SD.WOUD_BAAS, "zuid")
	await get_tree().create_timer(0.5).timeout
	geest = plek.get_node_or_null("Objects/Woudgeesten")
	check("woudgeesten staan op de afgesproken tegel", geest != null and geest.visible and geest.get_tile() == Vector2i(4, 9)
			and geest.event == "zingend_zaad")
	Story.trigger("zingend_zaad", geest)
	check("mini-gevecht begint", await wait_scene("Battle"))
	var b := battle()
	var ids: Array = b.enemies.map(func(e): return str(e.get("id", ""))) if b != null else []
	check("twee Wood Wraiths op basis-HP", ids == ["woudgeest", "woudgeest"]
			and b.enemies.all(func(e): return int(e["s"]["max_hp"]) == int(GD.ENEMIES["woudgeest"]["max_hp"])))
	check("mini-gevecht gewonnen", await win_battle())
	check("terug op de open plek", await wait_scene("WoudOpenPlek"))
	check("na het zaad bestaat het item", await wait_until(func(): return GameState.item_count(SD.ITEM_ZAAD) >= 1, 8.0)
			and Story.has_flag(SD.FLAG_ZAAD))
	var vondst: Array = await run_story(8.0)
	check("vondst is alleen de itemregel, geesten weg", vondst.any(func(l): return "You find Singing Seed." in str(l))
			and not scene().get_node("Objects/Woudgeesten").visible)
	d = await enter(dorp, "zuid_ingang")
	g = d.get_node("Objects/Gerrit")
	wieken = d.get_node("Objects/MolenWieken")
	var zong: Array = [false]
	wieken.begon_te_zingen.connect(func() -> void: zong[0] = true)
	GameState.party[0]["hp"] = 1
	Story.trigger("gerrit", g)
	var af: Array = await lines_until_choice()
	check("bij Garrett: zaad herkend, molen maalt, groep uitgerust, één meel", af.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_ZAAD))
			and af.any(func(l): return Molen.REGEL_ZANG in str(l))
			and af.any(func(l): return Molen.REGEL_GEZANG in str(l))
			and not af.any(func(l): return SD.QUOTE_GRAAN_DANK in str(l))
			and af.any(func(l): return Molen.REGEL_RUST in str(l)) and af.any(func(l): return Molen.REGEL_MEEL in str(l))
			and Story.has_flag(SD.FLAG_GRAAN_KLAAR) and Story.active_quest() == ""
			and GameState.item_count(SD.ITEM_ZAAD) == 0 and GameState.item_count(SD.ITEM_MEEL) == 1
			and int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"])
			and Dialog.choices == Molen.KEUZES)
	var wiek0: int = wieken.frame_nu()
	await get_tree().create_timer(0.55).timeout
	check("zangscène: de molen draait en zingt zacht", zong[0] and wieken.gezongen and wieken.draait()
			and not wieken.stil() and wieken.sprite.texture == Wieken.wieken_sheet() and wieken.sprite.hframes == 4
			and wieken.glow_aan() and wieken.noten >= 3 and wieken.frame_nu() != wiek0
			and wieken.get_node_or_null("Zang") != null
			and Wieken.piek(wieken.laatste_zang) > 0.04 and Wieken.piek(wieken.laatste_zang) < 0.2)
	await v17_shot("molen_zingt")
	Dialog.choose(1)
	await lines_until_choice()
	check("party wisselen noemt de groep", Dialog.choices.size() == 2 and str(Dialog.choices[1]) == "Vesper")
	Dialog.choose(1)
	await run_story(8.0)
	check("Vesper gaat voorop", str(GameState.party[0].get("id", "")) == "noor" and str(GameState.party[1].get("id", "")) == "dennis")
	var meel := GameState.item_count(SD.ITEM_MEEL)
	GameState.party[0]["hp"] = 1
	Story.trigger("gerrit", scene().get_node("Objects/Gerrit"))
	var dank: Array = await lines_until_choice()
	check("zelfde bezoek: dank, geen tweede meel, wel weer uitgerust", dank.any(func(l): return str(l).ends_with(SD.QUOTE_GRAAN_DANK))
			and GameState.item_count(SD.ITEM_MEEL) == meel
			and int(GameState.party[0]["hp"]) == int(GameState.party[0]["max_hp"]))
	Dialog.choose(0)
	await lines_until_choice()
	check("opslaan vraagt Yes/No", Dialog.choices == ["Yes", "No"])
	Dialog.choose(0)
	await run_story(8.0)
	var sav := GameState.read_save()
	var sav_party: Array = sav.get("party", [])
	check("de molen slaat op in Willowdale", str(sav.get("map", "")).ends_with("dorp_wilgendal.tscn")
			and not sav_party.is_empty() and str(sav_party[0].get("id", "")) == "noor")
	check("na het opslaan nog steeds één meel", GameState.item_count(SD.ITEM_MEEL) == 1)
	await enter(WORLD, "van_wilgendal")
	d = await enter(dorp, "zuid_ingang")
	wieken = d.get_node("Objects/MolenWieken")
	check("nieuw bezoek: de molen draait al, de zangscène niet opnieuw", wieken.draait() and wieken.glow_aan() and not wieken.gezongen
			and not wieken.stil())
	Story.trigger("gerrit", d.get_node("Objects/Gerrit"))
	await lines_until_choice()
	check("nieuw bezoek: nog één Zingend Meel", GameState.item_count(SD.ITEM_MEEL) == 2)
	Dialog.choose(2)
	await run_story(6.0)
	var held: Dictionary = {}
	for h in GameState.party:
		if str(h.get("id", "")) == "dennis":
			held = h
	var gat := int(GD.ITEMS[SD.ITEM_MEEL]["heal_hp"])
	held["hp"] = int(held["max_hp"]) - gat
	var voor := int(held["hp"])
	var gebruikt: Dictionary = PartyActions.use_item(GameState.inventory, SD.ITEM_MEEL, held)
	check("Zingend Meel herstelt %d HP" % gat, gebruikt["ok"] and int(gebruikt["hp"]) == gat
			and int(held["hp"]) == voor + gat)


# ================================================================ H: uitgang-warpers
func _warper_tests() -> void:
	var spots: Array = WW.placements()
	var roles := {}
	for p in spots:
		roles[str(p["role"])] = p
	var uit: Dictionary = WR.ROOMS["woud_rand"]["exits"]["E"]
	var boss: Dictionary = WR.ROOMS[WR.BOSS_ROOM]
	var stand: Vector2i = AW.victory_tile(boss)
	var eind: Vector2i = roles["eind"]["tile"] if roles.has("eind") else Vector2i(-1, -1)
	check("begin, midden en eind bestaan", spots.size() == 3 and roles.has("begin") and roles.has("midden") and roles.has("eind"))
	if not roles.has("begin") or not roles.has("midden") or not roles.has("eind"):
		return
	check("geen mini-baas: midden in de Mistpoel (verdieping %d)" % WW.middle_floor(),
			WW.mini_boss().is_empty() and WW.middle_floor() == 2 and WW.midden_room() == "woud_mistpoel"
			and str(roles["midden"]["room"]) == "woud_mistpoel")
	check("begin bij de ingang, niet op de wereld-uitgang", str(roles["begin"]["room"]) == "woud_rand"
			and roles["begin"]["tile"] == WW.BEGIN_TILE
			and _naast(roles["begin"]["tile"], _spawn_tile(WR.ROOMS["woud_rand"], "ingang"))
			and AW.walkable(WR.ROOMS["woud_rand"], roles["begin"]["tile"])
			and not WW.bezet(WR.ROOMS["woud_rand"], roles["begin"]["tile"]))
	check("midden-tegel vrij in de Mistpoel", AW.walkable(WR.ROOMS["woud_mistpoel"], roles["midden"]["tile"])
			and not WW.bezet(WR.ROOMS["woud_mistpoel"], roles["midden"]["tile"])
			and roles["midden"]["tile"] == WW.MIDDEN_TILE)
	check("eind naast de sta-tegel na de Wortelkoning %s (warper %s)" % [stand, eind],
			str(roles["eind"]["room"]) == WR.BOSS_ROOM and eind != stand
			and AW.walkable(boss, eind) and not WW.bezet(boss, eind)
			and not AW.boss_rect(boss).has_point(eind)
			and absi(eind.x - stand.x) + absi(eind.y - stand.y) == 1)
	var alleen_woud := true
	for p in spots:
		var rid := str(p["room"])
		if not WR.ROOMS.has(rid) or DR.ROOMS.has(rid) or rid.begins_with("archief") or rid.begins_with("dungeon100"):
			alleen_woud = false
		if str(p["world_scene"]) != str(uit["map"]) or str(p["world_spawn"]) != str(uit["spawn"]):
			alleen_woud = false
	check("alleen woudkamers, terug naar de woud-ingang op de wereldkaart", alleen_woud
			and str(uit["spawn"]) == "van_woud" and str(uit["map"]) == WORLD)
	if spots.size() != 3:
		return
	GameState.new_game("Dax")
	GameState.story_step = SD.KLAAR
	GameState.encounter_multiplier = 0.0
	if Dialog.is_open:
		Dialog.close()
	var ingang := await enter("res://scenes/maps/woud_rand.tscn", "ingang")
	await _weg_monsters(ingang)
	var wp: DungeonExitWarper = _warper_van(ingang)
	check("begin-warper in de Woudrand op %s" % [WW.BEGIN_TILE], wp != null and wp.role == "begin"
			and _warper_tile(wp) == WW.BEGIN_TILE and not wp.waarschuwt()
			and wp.sprite.texture.resource_path.ends_with("save_book.png")
			and wp.sprite.modulate == ExitWarper.TINT
			and wp.world_scene == WORLD and wp.world_spawn == "van_woud")
	if wp == null or player() == null:
		return
	var stay := tile()
	wp.interact(player())
	var ingang_zin: bool = await wait_until(func() -> bool:
		return wp.last_result == "start" and Dialog.is_open and Dialog.choices.is_empty() \
				and not Dialog._lines.is_empty() and str(Dialog._lines[0]) == ExitWarper.INGANG
	, 3.0)
	check("begin-warper waarschuwt niet", ingang_zin and not wp.waarschuwt())
	_klik_dicht()
	await wait_until(func() -> bool: return not Dialog.is_open and not wp.busy, 2.0)
	check("begin laat de party staan", wp.last_result == "start" and scene() == ingang and tile() == stay
			and player() != null and not player().input_locked
			and str(GameState.current_map).ends_with("woud_rand.tscn"))
	await _warper_kamer("res://scenes/maps/woud_mistpoel.tscn", "zuid", "midden", roles["midden"]["tile"], "van_woud")
	await _warper_kamer("res://scenes/maps/woud_open_plek.tscn", "zuid", "eind", eind, "van_woud")


func _warper_kamer(pad: String, spawn: String, role: String, tegel: Vector2i, wereld_spawn: String) -> void:
	var kamer := await enter(pad, spawn)
	await _weg_monsters(kamer)
	var wp: DungeonExitWarper = _warper_van(kamer)
	check("%s-warper op %s" % [role, tegel], wp != null and wp.role == role and wp.waarschuwt()
			and _warper_tile(wp) == tegel and wp.sprite.texture.resource_path.ends_with("save_book.png")
			and wp.sprite.modulate == ExitWarper.TINT)
	if wp == null or player() == null:
		return
	var stay := tile()
	wp.interact(player())
	var warned: bool = await wait_until(_exit_warning_open, 3.0)
	check("%s waarschuwt: '%s'" % [role, ExitWarper.WARNING], warned
			and ExitWarper.YES == "Yes, warp to the world map"
			and ExitWarper.NO == "No, stay in the dungeon")
	Dialog.choose(1)
	await wait_until(func() -> bool: return wp.last_result == "cancelled" and not wp.busy, 2.0)
	check("%s annuleren laat de party staan" % role, wp.last_result == "cancelled" and scene() == kamer
			and tile() == stay and player() != null and not player().input_locked)
	wp.interact(player())
	warned = await wait_until(_exit_warning_open, 3.0)
	check("%s vraagt opnieuw om bevestiging" % role, warned)
	Dialog.choose(0)
	var wereld_ok := await wait_scene("Wereldkaart", 20.0)
	await wait_fade()
	var sp: Node2D = null
	if wereld_ok:
		sp = scene().get_node_or_null("Spawns/" + wereld_spawn) as Node2D
	var verwacht := Vector2i((sp.position / 16.0).floor()) if sp != null else Vector2i(-99, -99)
	check("%s ja gaat naar de wereldkaart bij %s %s" % [role, wereld_spawn, tile()],
			wereld_ok and GameState.current_map == WORLD and sp != null and tile() == verwacht and tile() != stay)


func _warper_van(kamer: Node) -> DungeonExitWarper:
	if kamer == null:
		return null
	return kamer.get_node_or_null("Objects/ExitWarper") as DungeonExitWarper


func _warper_tile(node: Node2D) -> Vector2i:
	if node == null:
		return Vector2i(-99, -99)
	return Vector2i((node.position / 16.0).floor())


func _spawn_tile(room: Dictionary, spawn: String) -> Vector2i:
	var v: Array = room["spawns"][spawn]
	return Vector2i(int(v[0]), int(v[1]))


func _naast(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _exit_warning_open() -> bool:
	return Dialog.is_open and Dialog.choices.size() == 2 and not Dialog._lines.is_empty() \
			and str(Dialog._lines[0]) == ExitWarper.WARNING and str(Dialog.choices[0]) == ExitWarper.YES \
			and str(Dialog.choices[1]) == ExitWarper.NO


func _klik_dicht() -> void:
	if Dialog.is_open:
		Dialog.advance()
	if Dialog.is_open:
		Dialog.advance()


func _weg_monsters(kamer: Node) -> void:
	if kamer == null or not ("monsters" in kamer):
		return
	for m in kamer.monsters.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	kamer.monsters.clear()
	await pframes(2)
