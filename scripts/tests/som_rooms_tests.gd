extends Node
## Action in alle WM1-dungeons (Forge/Dennis 21 okt 2026):
##  - elke WM1-dungeonkamer (Archief 1, Donker Woud, Archief 2/Leven, Berggrot) krijgt bij Battle Style = Action de
##    realtime arena; in Classic niet;
##  - ALLE bazen starten het turn-based gevecht, ook in Action, zonder Action-baasvermenigvuldiger;
##  - Action is de standaard voor een vers spel; oude instellingen/saves zonder sleutel blijven Classic;
##    de keuze reist mee met save/load;
##  - kaart- en gevechtssprites van elke vijand in de WM1-kamers bestaan (audit).
## Start: godot --path . -- --somroomstest [--shots=/pad/map]

const MAPS := "res://scenes/maps/"
const SomData := preload("res://scripts/data/som_data.gd")
const DR := preload("res://scripts/data/dungeon_rooms.gd")
const BossCore := preload("res://scripts/battle/boss_core.gd")
const SAVE := "user://somrooms_test.json"
const GameData := preload("res://scripts/data/game_data.gd")

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = ""
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _shot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))


func _nieuw() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for id in ["noor", "lotte"]:
		if not GameState.has_member(id):
			GameState.add_member(id)


## Alle dungeonkamer-scènes: [pad, room_id].
func _kamer_scenes() -> Array:
	var out := []
	var dir := DirAccess.open(MAPS)
	var namen := Array(dir.get_files()).filter(func(f): return str(f).ends_with(".tscn"))
	namen.sort()
	for f in namen:
		var pad: String = MAPS + str(f)
		var st: PackedScene = load(pad)
		var s := st.get_state()
		for i in s.get_node_property_count(0):
			if s.get_node_property_name(0, i) == "room_id":
				out.append([pad, str(s.get_node_property_value(0, i))])
	return out


func _run() -> void:
	await _instellingen()
	_sprites()
	await _kamers()
	await _bazen()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("SOMROOMSTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- standaard + save/load
func _instellingen() -> void:
	check("standaard (vers spel): Battle Style = Action", int(Settings.DEFAULTS["battle_style"]) == Settings.BATTLE_STYLE_ACTION)
	var oud_pad: String = Settings.path
	var oude_waarden: Dictionary = Settings.values.duplicate()
	# vers: geen instellingenbestand -> Action
	Settings.path = "user://somrooms_geen_bestand.cfg"
	if FileAccess.file_exists(Settings.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.load_settings()
	check("geen instellingenbestand (nieuw spel) -> Action", Settings.action_battles())
	# oud bestand zonder battle_style -> Classic
	var cfg := ConfigFile.new()
	cfg.set_value(Settings.SECTION, "music_volume", 5)
	cfg.save("user://somrooms_oud.cfg")
	Settings.path = "user://somrooms_oud.cfg"
	Settings.load_settings()
	check("oud instellingenbestand zonder battle_style -> Classic (vorige effectieve waarde)", not Settings.action_battles()
			and int(Settings.get_value("music_volume")) == 5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://somrooms_oud.cfg"))
	Settings.path = oud_pad
	Settings.values = oude_waarden
	# save/load
	_nieuw()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	check("save met Action", GameState.save_game(Vector2i(5, 5), Vector2i.DOWN, SAVE))
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	check("laden zet Action terug (keuze reist mee)", GameState.load_game(SAVE) and Settings.action_battles())
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.save_game(Vector2i(5, 5), Vector2i.DOWN, SAVE)
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	check("toggle naar Classic blijft Classic na save/load", GameState.load_game(SAVE) and not Settings.action_battles())
	# oude save zonder sleutel -> Classic
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.erase("battle_style")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	check("oude save zonder battle_style laadt als Classic", GameState.load_game(SAVE) and not Settings.action_battles())
	# nieuw spel (titelscherm -> naam -> start_new_game) is ALTIJD Action, ook als Settings op Classic stond
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.start_new_game("Dax")
	for i in 60:
		await get_tree().process_frame
	check("nieuw spel (start_new_game) zet Battle Style op Action, ook vanuit Classic", Settings.action_battles())
	check("daarna oude save zonder sleutel: weer Classic", GameState.load_game(SAVE) and not Settings.action_battles())


# ---------------------------------------------------------------- sprites (audit)
func _sprites() -> void:
	var mis := []
	var kaart := []
	for rid in SomData.wm1_rooms():
		var r: Dictionary = DR.room(rid)
		for m in r.get("monsters", []):
			var eid := str(m.get("enemy", ""))
			var e: Dictionary = GameData.ENEMIES.get(eid, DR.berggrot().enemy(eid) if DR.berggrot().has_method("enemy") else {})
			if e.is_empty():
				mis.append("%s:%s (geen data)" % [rid, eid])
				continue
			var sp := str(e.get("sprite", ""))
			if sp == "" or not ResourceLoader.exists(sp):
				mis.append("%s:%s gevecht %s" % [rid, eid, sp])
			var mp: String = "res://assets/map_monsters/" + str(m.get("sprite", eid)) + ".png"
			if not ResourceLoader.exists(mp):
				kaart.append("%s:%s" % [rid, mp.get_file()])
	check("gevechtssprite van elke vijand in de WM1-kamers bestaat (%s)" % (str(mis) if not mis.is_empty() else "ok"), mis.is_empty())
	check("kaartsprite (assets/map_monsters/) van elke vijand in de WM1-kamers bestaat (%s)" % (str(kaart) if not kaart.is_empty() else "ok"), kaart.is_empty())


# ---------------------------------------------------------------- arena per kamer
func _kamers() -> void:
	var lijst := _kamer_scenes()
	var wm1 := SomData.wm1_rooms()
	var gedekt := {}
	var fout := []
	var classic_fout := []
	_nieuw()
	var shot_gebieden := {}
	for item in lijst:
		var pad: String = item[0]
		var rid: String = item[1]
		if not SomData.is_wm1_room(rid):
			continue
		Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
		var s := await _laad(pad)
		if s == null:
			fout.append("%s laadt niet" % pad.get_file())
			continue
		var a: Node = s.get("som")
		if a == null:
			fout.append("%s (%s): geen arena" % [pad.get_file(), rid])
			continue
		gedekt[rid] = true
		for m in s.monsters:
			if not is_instance_valid(m):
				continue
			if m.boss and a.enemies.has(m):
				fout.append("%s: baas %s in de realtime arena" % [rid, m.monster_id])
			elif not m.boss and not a.enemies.has(m):
				fout.append("%s: monster %s niet realtime" % [rid, m.monster_id])
		var gebied := rid.get_slice("_", 0) + ("_2" if rid.begins_with("archief_2") else "")
		if not shot_gebieden.has(gebied):
			shot_gebieden[gebied] = true
			await get_tree().create_timer(2.6).timeout     # kamernaam-banner eerst weg
			await _shot("action_" + rid)
		# Classic: geen arena
		Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
		s = await _laad(pad)
		if s != null and s.get("som") != null:
			classic_fout.append(rid)
	var zonder_scene := wm1.filter(func(r): return not gedekt.has(r))
	print("INFO  WM1-kamers: %d, met scène + arena: %d, zonder eigen scène (gedeeld/gegenereerd): %s" % [wm1.size(), gedekt.size(), zonder_scene])
	check("Action: elke WM1-kamerscène heeft de realtime arena, monsters realtime, bazen niet (%d kamers; %s)" % [gedekt.size(), fout if not fout.is_empty() else "ok"],
			fout.is_empty() and gedekt.size() >= 20)
	for want in ["archief_ingang", "archief_golemhal", "archief_v1_gang", "archief_v4_wachtersgang", "woud_rand", "woud_sporenkring",
			"archief_2_v1_entree", "archief_2_v4_genezer", "berggrot_mond", "berggrot_nerf"]:
		if not gedekt.has(want) and wm1.has(want):
			check("Action in %s" % want, false)
	check("elk gebied gedekt: Archief 1, Woud, Archief 2, Berggrot", gedekt.keys().any(func(r): return str(r).begins_with("archief_v") or str(r) == "archief_golemhal")
			and gedekt.keys().any(func(r): return str(r).begins_with("woud_"))
			and gedekt.keys().any(func(r): return str(r).begins_with("archief_2_"))
			and gedekt.keys().any(func(r): return str(r).begins_with("berggrot_")))
	check("Classic: nergens een realtime arena (%s)" % (classic_fout if not classic_fout.is_empty() else "ok"), classic_fout.is_empty())
	check("dungeon van 100 doet niet mee", not SomData.is_wm1_room("dungeon100_1") and not SomData.room_enabled("dungeon100_3", true))


# ---------------------------------------------------------------- bazen: altijd turn-based
func _bazen() -> void:
	var lijst := _kamer_scenes()
	var gevonden := []
	for item in lijst:
		var pad: String = item[0]
		var rid: String = item[1]
		var r: Dictionary = DR.room(rid)
		var bazen: Array = r.get("monsters", []).filter(func(m): return bool(m.get("boss", false)))
		if bazen.is_empty() or not SomData.is_wm1_room(rid):
			continue
		for bd in bazen:
			var stats := {}
			var geopend := {}
			for stijl in [Settings.BATTLE_STYLE_CLASSIC, Settings.BATTLE_STYLE_ACTION]:
				_nieuw()
				Settings.set_value("battle_style", stijl)
				var s := await _laad(pad)
				if s == null:
					continue
				var m: Node = null
				for x in s.monsters:
					if is_instance_valid(x) and x.boss and str(x.data.get("enemy", "")) == str(bd.get("enemy", "")):
						m = x
				if m == null:
					m = s.add_monster(bd.duplicate(true))     # verborgen tot een verhaalvlag: zelf neerzetten
					await get_tree().process_frame
				var a: Node = s.get("som")
				if stijl == Settings.BATTLE_STYLE_ACTION:
					check("baas %s (%s): Action-arena actief, baas NIET realtime" % [bd.get("enemy", ""), rid], a != null and not a.enemies.has(m))
				s.start_monster_battle(m)
				var bt: Node = null
				for i in 240:
					await get_tree().process_frame
					if Dialog.has_choices():
						Dialog.choose(0)
					var cs := get_tree().current_scene
					if cs != null and cs.name == "Battle" and "enemies" in cs and not (cs.enemies as Array).is_empty():
						bt = cs
						break
				geopend[stijl] = bt != null and GameState.pending_boss
				if bt != null:
					var st: Dictionary = bt.enemies[0].get("s", {})
					stats[stijl] = [int(st.get("max_hp", -1)), int(st.get("atk", -1)), int(st.get("def", -1))]
					if stijl == Settings.BATTLE_STYLE_ACTION and not gevonden.has(rid):
						await _shot("baas_turnbased_" + rid)
				GameState.pending_boss = false
				GameState.in_battle = false
				GameState.pending_story_loss = false
				GameState.archief2_party_filter = ""
			var ca: Array = stats.get(Settings.BATTLE_STYLE_ACTION, [])
			var cc: Array = stats.get(Settings.BATTLE_STYLE_CLASSIC, [])
			check("baas %s (%s): opent het TURN-BASED gevecht in Action, stats = Classic (HP/ATK/DEF %s = %s, geen Action-vermenigvuldiger)" % [bd.get("enemy", ""), rid, ca, cc],
					bool(geopend.get(Settings.BATTLE_STYLE_ACTION, false)) and not ca.is_empty() and ca == cc)
			gevonden.append(rid)
	print("INFO  baaskamers: ", gevonden)
	check("alle WM1-bazen gecontroleerd (Golem, Wortelkoning, Archief 2: Lotte/Wurger/Genezer)", gevonden.size() >= 5)


func _enemy(id: String) -> Dictionary:
	if GameData.ENEMIES.has(id):
		return GameData.ENEMIES[id]
	return DR.berggrot().enemy(id) if DR.berggrot().has_method("enemy") else {}
