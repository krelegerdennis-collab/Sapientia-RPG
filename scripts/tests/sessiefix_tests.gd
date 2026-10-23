extends Node
## Sessielog-review (21 okt 2026, Dennis' web-sessie e47c7e80 + video):
##  1) Action: na aanval / treffer / ontwijken is de held weer precies zijn 24x32-loopframe (alle 5 helden),
##     en nooit loopsprite + 48x48-pose tegelijk zichtbaar;
##  2) geen warp-pingpong: wie de richting vasthoudt vanaf het spawnpunt gaat niet meteen terug door de uitgang;
##  3) sessielog: kaartregel draagt gevechtsstijl + heldsheet, Action-slagen en -treffers worden gelogd.
## Start: godot --path . -- --sessiefixtest [--shots=/pad/map]

const MAPS := "res://scenes/maps/"
const SomFx := preload("res://scripts/som/som_fx.gd")
const HELDEN := ["dennis", "noor", "lotte", "kael", "orion"]
const LOG_MAP := "user://sessiefix_log"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _laad(pad: String, spawn := "") -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = spawn
	get_tree().change_scene_to_file(pad)
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _wacht(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(naam: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots)
	get_viewport().get_texture().get_image().save_png(shots.path_join(naam + ".png"))
	print("INFO  screenshot: ", shots.path_join(naam + ".png"))


## Zichtbare sprites op de speler: [naam, framemaat, schaal].
func _zichtbaar(p: Node) -> Array:
	var out := []
	for c in [p] + p.find_children("*", "Sprite2D", true, false):
		if c is Sprite2D and c.is_visible_in_tree() and c.texture != null:
			out.append([str(c.name), Vector2i(c.texture.get_size() / Vector2(c.hframes, c.vframes)), c.global_scale])
	return out


func _nieuw() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	for id in HELDEN:
		if not GameState.has_member(id):
			GameState.add_member(id)


func _run() -> void:
	GameState._finish_preload()
	await _poses()
	await _pingpong()
	await _log()
	print("SESSIEFIXTEST %d PASS, %d FAIL" % [passes, failures])
	get_tree().quit(1 if failures else 0)


# ---------------------------------------------------------------- 1) poses
func _poses() -> void:
	_nieuw()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var s := await _laad(MAPS + "archief_v1_gang.tscn")
	var a: Node = s.get("som") if s else null
	check("Action-arena in archief_v1_gang", a != null)
	if a == null:
		return
	var p: Node = s.player
	for id in HELDEN:
		a.active_id = id
		a._apply_player_sheet()
		await _wacht(0.1)
		var loop: Array = _zichtbaar(p)
		var ok_start: bool = loop.size() == 1 and loop[0][1] == Vector2i(24, 32) and p.sprite.offset == Vector2(0, -8)
		var dubbel := false
		var te_groot := false
		# aanval, treffer midden in de aanval, ontwijk-pose (zelfde 192x48-indeling als hurt)
		a.iframes.clear()
		a.attack()
		await _wacht(0.05)
		a.iframes.clear()
		a.member(id)["hp"] = 999
		a.hit_member(id, 1)
		for i in 30:
			await get_tree().process_frame
			var z := _zichtbaar(p)
			dubbel = dubbel or z.size() > 1
			for e in z:
				te_groot = te_groot or e[1].x > 48 or e[1].y > 48 or e[2] != Vector2.ONE
		if id == "dennis":
			await _shot("held_tijdens_aanval_treffer")
		var dodge: Texture2D = SomFx.tex("res://assets/sprites/som/combat/%s_dodge.png" % _sheetnaam(id))
		if dodge:
			SomFx._hero_anim(p, dodge, 4, 1, [0], [200], "SomDodgeAnim")
		await _wacht(1.6)
		var na: Array = _zichtbaar(p)
		check("%s: start = 24x32-loopframe, offset (0,-8) (%s)" % [id, loop], ok_start)
		check("%s: tijdens aanval+treffer nooit loopsprite en pose tegelijk" % id, not dubbel)
		check("%s: poses <= 48x48 en schaal 1" % id, not te_groot)
		check("%s: na aanval/treffer/ontwijken weer alleen het 24x32-loopframe (%s)" % [id, na],
				na.size() == 1 and str(na[0][0]) == "Sprite2D" and na[0][1] == Vector2i(24, 32) and na[0][2] == Vector2.ONE)
	await _shot("held_na_aanval_treffer")


func _sheetnaam(id: String) -> String:
	return {"dennis": "dax", "noor": "vesper", "lotte": "seren", "kael": "kael", "orion": "orion"}[id]


# ---------------------------------------------------------------- 2) warp-pingpong
func _pingpong() -> void:
	_nieuw()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	for geval in [["archief_v4_wachtersgang", "ladder", "move_up", "archief_v3_gang"],
			["archief_v3_gang", "trap", "move_right", "archief_v4_wachtersgang"]]:
		var s: Node = null
		# richting al vast bij binnenkomst (zoals Dennis: knop ingehouden door de deur heen)
		Input.action_press(geval[2])
		s = await _laad(MAPS + geval[0] + ".tscn", geval[1])
		check("%s: spawn_hold aan bij binnenkomst met ingehouden richting" % geval[0], s != null and s.player.spawn_hold)
		await _wacht(0.8)
		Input.action_release(geval[2])
		var cs := get_tree().current_scene
		check("%s (spawn %s): %s ingehouden -> geen terugwarp" % [geval[0], geval[1], geval[2]],
				cs != null and str(cs.scene_file_path).ends_with(geval[0] + ".tscn") and not GameState.changing_map)
		# losgelaten en opnieuw gedrukt: de uitgang werkt gewoon
		await _wacht(0.2)
		Input.action_press(geval[2])
		for i in 120:
			await get_tree().process_frame
			cs = get_tree().current_scene
			if cs != null and str(cs.scene_file_path).ends_with(geval[3] + ".tscn"):
				break
		Input.action_release(geval[2])
		check("%s: na loslaten werkt de uitgang naar %s" % [geval[0], geval[3]],
				cs != null and str(cs.scene_file_path).ends_with(geval[3] + ".tscn"))
		await _wacht(0.6)


# ---------------------------------------------------------------- 3) sessielog
func _log() -> void:
	_nieuw()
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	var sl := get_node("/root/SessieLog")
	sl.volgt_instelling = false
	sl.start(LOG_MAP)
	var s := await _laad(MAPS + "archief_v1_gang.tscn")
	var a: Node = s.get("som") if s else null
	if a:
		a.active_id = "dennis"
		a._apply_player_sheet()
		a.attack()
		await _wacht(0.8)
		a.iframes.clear()
		a.hit_member("dennis", 1)
	await _wacht(0.3)
	var pad: String = sl.pad
	sl.stop()
	var kaart := {}
	var start := {}
	var slag := false
	var treffer := false
	for regel in FileAccess.get_file_as_string(pad).split("\n"):
		var d = JSON.parse_string(regel) if regel != "" else null
		if not d is Dictionary:
			continue
		var dd: Dictionary = d.get("data", {})
		if d.get("type") == "sessie_start":
			start = dd
		if d.get("type") == "kaart" and dd.get("kaart") == "archief_v1_gang":
			kaart = dd
		slag = slag or d.get("type") == "actie_slag"
		treffer = treffer or d.get("type") == "actie_treffer"
	check("kaartregel: gevechtsstijl action + heldsheet dax_wm1.png 24x32 (%s)" % [kaart],
			kaart.get("gevechtsstijl") == "action" and kaart.get("held_sheet") == "dax_wm1.png" and str(kaart.get("held_frame")) in ["[24, 32]", "[24.0, 32.0]"])
	check("Action-slag en -treffer staan in het logboek", slag and treffer)
	check("startregel draagt een build-id (%s)" % start.get("build_id", "?"), str(start.get("build_id", "")) != "")
