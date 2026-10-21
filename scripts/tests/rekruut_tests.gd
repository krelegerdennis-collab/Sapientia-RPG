extends Node
## Rekruten Kael Voss en Orion in de World Warper-hal (world_warper/services/rekruut.gd).
## Aansluiten, NPC weg, save/load, volle groep, en een Action-gevecht met elk (aanval, cooldown, AI, ring).
## Start: godot --path . -- --rekruuttest [--shots=/pad/map]

const HAL := "res://world_warper/maps/hal.tscn"
const GANG := "res://scenes/maps/archief_v1_gang.tscn"
const SAVE := "user://rekruut_test.json"
const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Kamers := preload("res://world_warper/kamers/kamers.gd")
const Rekruut := preload("res://world_warper/services/rekruut.gd")

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


func _laad(pad: String, spawn := "") -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	GameState.pending_spawn = spawn
	get_tree().change_scene_to_file(pad)
	for i in 180:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 6:
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


func _sec(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


## Vraag beantwoorden: keuze 'i', daarna de melding wegklikken. Geeft de uitkomst.
func _praat(npc: Node, i: int) -> Array:
	var regels := []
	var klaar := [false, ""]
	var f := func() -> void:
		klaar[1] = await npc.vraag()
		klaar[0] = true
	f.call()
	for k in 60:
		await get_tree().process_frame
		if Dialog.has_choices():
			break
	Dialog.choose(i)
	for k in 120:
		await get_tree().process_frame
		if klaar[0]:
			break
	await get_tree().process_frame
	if Dialog.is_open:
		regels.append(str(Dialog.get("lines")))
		for k in 10:
			if not Dialog.is_open:
				break
			Dialog.advance()
			Dialog.advance()
			await get_tree().process_frame
	return [klaar[1], regels]


func _start_party() -> void:
	GameState.new_game("Dax")
	GameState.encounter_multiplier = 0.0
	GameState.story_flags[Kamers.FLAG_HUB] = true
	for f in ["ww_canon_genezer_gezien", "ww_canon_hanger_gezien", "ww_canon_dreiging_gezien"]:
		GameState.story_flags[f] = true      # geen canon-scène over de hal
	for id in ["noor", "lotte"]:
		if not GameState.has_member(id):
			GameState.add_member(id)


func _run() -> void:
	Settings.set_value("battle_style", 0)
	_start_party()
	var hal := await _laad(HAL, "ingang")
	check("hal geladen", hal != null)
	if hal == null:
		_eind()
		return
	var kael: Node = hal.get_node_or_null("Objects/Kael")
	var orion: Node = hal.get_node_or_null("Objects/Orion")
	check("Kael en Orion staan in de hal (rekruut.gd)", kael != null and orion != null and kael.get_script() == Rekruut and orion.get_script() == Rekruut)
	if kael != null and orion != null:
		check("naambordjes boven Kael en Orion (Kael Voss / Orion)", kael.naam_label != null and kael.naam_label.text == "Kael Voss" and orion.naam_label != null and orion.naam_label.text == "Orion" and kael.naam_label.is_visible_in_tree())
		check("hal: naambordjes raken elkaar niet", preload("res://scripts/tests/koopman_tests.gd").hub_label_overlap(hal) == 0)
		await _shot("hub_naambordjes")
		# Orions (en Kaels) bordje raakt de RUN-knop niet (schermcoördinaten, camera op de spawn)
		await get_tree().create_timer(0.6).timeout
		var tc: Control = hal.get_node_or_null("TouchControls/Control")
		var raakt := ""
		if tc and tc.has_method("run_rect"):
			var run: Rect2 = tc.run_rect()
			run.position += tc.get_global_rect().position
			for n in [kael, orion]:
				var l: Label = n.naam_label
				var xf := l.get_global_transform_with_canvas()
				var r := Rect2(xf.origin, l.size * xf.get_scale())
				if r.intersects(run, true):
					raakt += "%s %s x RUN %s; " % [l.text, r, run]
		check("hal: naambordjes raken de RUN-knop niet (%s)" % (raakt if raakt != "" else "ok"), tc != null and raakt == "")
	if kael == null or orion == null:
		_eind()
		return
	var sp_ok: bool = true
	for n in [kael, orion]:
		var s: Sprite2D = n.get_node("Sprite2D")
		sp_ok = sp_ok and n.visible and s.texture.resource_path.ends_with("%s_wm1_slim.png" % n.hero_id) \
				and s.texture.get_size() == Vector2(72, 128) and s.hframes == 3 and s.vframes == 4
	check("Kael/Orion: <id>_wm1_slim.png 72x128, 3x4 frames van 24x32, zichtbaar", sp_ok)
	await _sec(0.3)
	await _shot("hal_rekruten_voor")
	# Nee -> blijft staan
	var r: Array = await _praat(kael, 1)
	check("Nee: Kael blijft staan, niet in de groep (%s)" % r[0], r[0] == "nee" and kael.visible and GameState.member("kael").is_empty())
	# Ja -> sluit aan
	var lvl := Rekruut.gemiddeld_level()
	r = await _praat(kael, 0)
	var h: Dictionary = GameState.member("kael")
	check("Ja: Kael Voss sluit aan op het partylevel (%s, Lv %d)" % [r[0], int(h.get("level", 0))],
			r[0] == "joined" and GameState.party.size() == 4 and int(h.get("level", 0)) == lvl and str(h.get("name", "")) == "Kael Voss")
	check("Kael verdwijnt (onzichtbaar, geen botsing)", not kael.visible and kael.collision_layer == 0)
	# Groep vol -> melding, Orion blijft
	r = await _praat(orion, 0)
	check("groep vol (4): Orion geeft een melding en blijft staan (%s)" % r[0], r[0] == "vol" and orion.visible and GameState.member("orion").is_empty())
	check("melding is duidelijk Engels", Rekruut.VOL.contains("full") and Rekruut.VOL.contains("Party"))
	await _shot("hal_rekruten_na_kael")
	# save/load
	check("opslaan", GameState.save_game(Vector2i(8, 9), Vector2i.UP, SAVE))
	_start_party()
	check("nieuw spel: Kael weg uit de groep", GameState.member("kael").is_empty())
	check("laden", GameState.load_game(SAVE))
	check("na laden: Kael in de groep, Orion niet", not GameState.member("kael").is_empty() and GameState.member("orion").is_empty())
	hal = await _laad(HAL, "ingang")
	kael = hal.get_node("Objects/Kael")
	orion = hal.get_node("Objects/Orion")
	check("na laden: Kael-NPC weg, Orion-NPC staat er", not kael.visible and orion.visible)
	# ruimte maken (Seren naar de reserve) -> Orion kan aansluiten
	var seren: Dictionary = GameState.member("lotte")
	GameState.party.erase(seren)
	GameState.party_bench.append(seren)
	r = await _praat(orion, 0)
	check("na ruimte maken: Orion sluit aan (%s)" % r[0], r[0] == "joined" and not orion.visible and GameState.party.any(func(x): return x["id"] == "orion"))
	var wf: Node = hal.find_child("Wanderers", true, false)
	var wok := true
	if wf:
		var sfk := preload("res://world_warper/wander/wanderers.gd").frames_uit(load("res://assets/sprites/som/kaart/kael_wm1_slim.png"))
		var at: AtlasTexture = sfk.get_frame_texture("stil_" + str(preload("res://world_warper/wander/wanderers.gd").RICHTINGEN[0]), 0)
		wok = at.region.size == Vector2(24, 32)
	check("hal-wandelaars: Kael/Orion-sheet in frames van 24x32 (niet 16x24)", wok)
	check("Kael/Orion zitten nergens dubbel", GameState.party.filter(func(x): return x["id"] in ["kael", "orion"]).size() == 2)
	await _shot("hal_rekruten_beide")
	await _action("kael")
	await _action("orion")
	_geen_reserve()
	await _classic()
	_eind()


## Geen enkele held valt terug op het reserve-plaatje dennis.png (battle.gd), ook Kael en Orion niet.
func _geen_reserve() -> void:
	for h in GameData.HEROES:
		var pad := str(h.get("battle_sprite", ""))
		check("%s: eigen gevechtssprite (%s), geen dennis.png-reserve" % [h["id"], pad.get_file()],
				pad != "" and not pad.ends_with("/dennis.png") and ResourceLoader.exists(pad))
	for id in ["kael", "orion"]:
		var t: Texture2D = load("res://assets/sprites/battle/%s.png" % id)
		check("%s.png 2100x210 (10 frames van 210)" % id, t != null and t.get_size() == Vector2(2100, 210))
		var d: Texture2D = load("res://assets/sprites/som/combat/%s_dodge.png" % id)
		check("%s_dodge.png 192x48 en in HERO_POSES" % id, d != null and d.get_size() == Vector2(192, 48)
				and str(SomData.HERO_POSES[id].get("dodge", "")).ends_with("%s_dodge.png" % id))


## Classic (turn-based) gevecht met Dax, Kael, Orion en Vesper: elke held tekent zijn eigen sheet.
func _classic() -> void:
	Settings.set_value("battle_style", 0)
	GameState.party.clear()
	GameState.party_bench.clear()
	for id in ["dennis", "kael", "orion", "noor"]:
		GameState.add_member(id)
	var g := await _laad(GANG, "zuid")
	if g == null:
		check("classic: gang geladen", false)
		return
	var p: Node = g.get_node("Objects/Player")
	GameState.start_battle(["papiergeest"], p.get_tile(), p.facing, "archief")
	var ok := await _wacht(func(): return get_tree().current_scene != null and get_tree().current_scene.name == "Battle" and get_tree().current_scene.is_node_ready(), 15.0)
	check("classic: turn-based gevecht open", ok)
	if not ok:
		return
	await _sec(1.2)
	var b: Node = get_tree().current_scene
	var paden := {}
	for c in b.heroes:
		var n: Node = c.get("node")
		var spr: Sprite2D = n.get("_sprite") if n else null
		paden[str(c["s"].get("id", c.get("name")))] = spr.texture.resource_path if spr and spr.texture else ""
	var goed := paden.size() == 4
	for k in paden:
		goed = goed and not str(paden[k]).ends_with("/dennis.png") and str(paden[k]) != ""
	check("classic: alle 4 helden met eigen sheet, geen dennis.png (%s)" % str(paden), goed)
	check("classic: Kael en Orion tekenen kael.png / orion.png", str(paden).contains("battle/kael.png") and str(paden).contains("battle/orion.png"))
	await _shot("classic_kael_orion")


## Action-gevecht met held 'id' (bondgenoot-AI + zelf besturen + ring).
func _action(id: String) -> void:
	Settings.set_value("battle_style", 1)
	GameState.party.clear()
	GameState.party_bench.clear()
	GameState.add_member("dennis")
	GameState.add_member(id)
	for hh in GameState.party:
		hh["level"] = 5
		hh["hp"] = 999
		hh["max_hp"] = 999
		hh["mp"] = hh["max_mp"]
	var g := await _laad(GANG, "zuid")
	var a: Node = g.som if g != null and "som" in g else null
	check("%s: Action-arena actief in %s" % [id, GANG.get_file()], a != null)
	if a == null:
		return
	check("%s: kaartsheet + aanvalssheet geladen (RPG ART wm1_combat)" % id, a.sheet_for(id) != null and a.attack_texs.has(id)
			and a.pose_tex(id, "hurt") != null and a.pose_tex(id, "ko") != null)
	var al: Node = a.ally_of(id)
	check("%s: bondgenoot in de arena" % id, al != null)
	if al == null:
		return
	var p: CharacterBody2D = g.get_node("Objects/Player")
	var pt: Vector2i = p.get_tile()
	# 1) bondgenoot-aanval (direct): naast de vijand op zijn eigen bereik
	var m: Node = g.add_monster({"id": "rek_%s" % id, "enemy": "papiergeest", "tile": [pt.x + 3, pt.y], "moves": false})
	await get_tree().process_frame
	var e: Dictionary = a.enemies.get(m, {})
	e["hp"] = 9999
	var c: Vector2 = a.center_of(m)
	al.position = c - Vector2(SomData.attack_offset(id) + 4.0, SomData.BODY_Y)
	al.facing = Vector2i.RIGHT
	var res := [-1]
	var cb := func(hid: String, hits: int) -> void:
		if hid == id:
			res[0] = hits
	a.swing_landed.connect(cb)
	var hp0 := int(e["hp"])
	al.charge = 0.0      # zoals de AI zelf doet: anders start de AI meteen een tweede slag over deze heen
	a.ally_attack(al, m)
	var t0 := Time.get_ticks_msec()
	while res[0] < 0 and Time.get_ticks_msec() - t0 < 2500:      # op tijd wachten (frames kunnen heel kort zijn)
		await get_tree().process_frame
	check("%s: aanval raakt op eigen bereik (%.0f px, %d treffer, HP %d -> %d)" % [id, SomData.attack_offset(id) + 4.0, res[0], hp0, int(e["hp"])],
			res[0] >= 1 and int(e["hp"]) < hp0)
	# 2) AI: valt vanzelf aan, met cooldown (wapenmeter vult in CHARGE_TIME)
	al.charge = 1.0
	var n0: int = al.attacks
	var t_eerst := -1.0
	var t_tweede := -1.0
	var start := Time.get_ticks_msec()
	var cd_ok := true
	for k in 600:
		await get_tree().physics_frame
		if al.attacks > n0 and t_eerst < 0.0:
			t_eerst = (Time.get_ticks_msec() - start) / 1000.0
			cd_ok = al.charge < 1.0
		if al.attacks > n0 + 1:
			t_tweede = (Time.get_ticks_msec() - start) / 1000.0
			break
	check("%s: AI valt zelf aan (staat %s, %d aanvallen)" % [id, al.state, al.attacks - n0], t_eerst >= 0.0)
	check("%s: cooldown: meter leeg na de slag, volgende pas na >= %.1f s (%.2f s)" % [id, SomData.CHARGE_TIME, t_tweede - t_eerst],
			cd_ok and t_tweede > 0.0 and t_tweede - t_eerst >= SomData.CHARGE_TIME * 0.9)
	await _shot("action_%s_ai" % id)
	a.swing_landed.disconnect(cb)
	# 3) zelf besturen (SWITCH) en slaan
	check("%s: wisselen naar %s" % [id, id], a.switch_hero(id) == id and a.active_id == id)
	await _sec(0.3)
	m.place_at(Vector2i(pt.x + 3, pt.y), Vector2i.LEFT)      # terug na knockback
	await get_tree().process_frame
	c = a.center_of(m)
	var bond: Node = a.ally_of("dennis")
	if bond:
		bond.charge = 0.0
	p.position = c - Vector2(SomData.attack_offset(id) + 4.0, SomData.BODY_Y)
	p.set("_target", p.position)
	p.facing = Vector2i.RIGHT
	a.charge = 1.0
	res[0] = -1
	var cb2 := func(hid: String, hits: int) -> void:
		if hid == id:
			res[0] = hits
	a.swing_landed.connect(cb2)
	# tot 2 pogingen: een rondlopende kamervijand kan de speler net raken/verplaatsen (zelden, flaky)
	for poging in 2:
		if poging > 0:
			m.place_at(Vector2i(pt.x + 3, pt.y), Vector2i.LEFT)
			await get_tree().process_frame
			p.position = a.center_of(m) - Vector2(SomData.attack_offset(id) + 4.0, SomData.BODY_Y)
			p.set("_target", p.position)
			p.facing = Vector2i.RIGHT
			a.swing_lock = 0.0
			a.charge = 1.0
		a.attack()
		var t1 := Time.get_ticks_msec()
		while res[0] < 0 and Time.get_ticks_msec() - t1 < 2500:      # op tijd wachten (frames kunnen heel kort zijn)
			await get_tree().process_frame
		if res[0] >= 1:
			break
	a.swing_landed.disconnect(cb2)
	check("%s: bestuurde slag raakt (%d)" % [id, res[0]], res[0] >= 1)
	# 3b) ontwijken: een klap tijdens de iframes -> <held>_dodge.png-pose, geen schade
	var dn: Node = a.node_of(id)
	for nm in ["SomHurtAnim", "SomDodgeAnim"]:       # een lopende pose (van een echte klap) eerst weg
		var oud: Node = dn.get_node_or_null(nm) if dn else null
		if oud:
			oud.free()
	var hp_d := int(a.member(id)["hp"])
	var d0: int = a.dodges
	a.iframes[id] = 0.5
	a.hit_member(id, 50)
	var da: Node = dn.get_node_or_null("SomDodgeAnim") if dn else null
	check("%s: ontwijkt tijdens iframes met %s_dodge.png (geen schade)" % [id, id], da != null and a.dodges >= d0 + 1
			and int(a.member(id)["hp"]) == hp_d and da.texture.resource_path.ends_with("%s_dodge.png" % id))
	await _shot("action_%s_dodge" % id)
	await _sec(0.3)
	# 4) ring: skill (+ Kael magie), opmaak zonder overlap
	var ent: Dictionary = a.ring_entries()
	var sk: Array = ent["skills"].map(func(x): return x["id"])
	var mg: Array = ent["magic"].map(func(x): return x["id"])
	check("%s: ring-skill %s, magie %s" % [id, sk, mg], sk.size() == 1 and (mg == ["vonk"] if id == "kael" else mg.is_empty()))
	a.open_ring()
	await get_tree().process_frame
	var lay_ok := true
	for tb in ["skills", "magic"]:
		a.ring.set_tab(tb)
		await get_tree().process_frame
		lay_ok = lay_ok and not a.ring._any_overlap()
	a.ring.set_tab("skills")
	await get_tree().process_frame
	await _shot("action_%s_ring" % id)
	a.ring.close({})
	await get_tree().process_frame
	check("%s: ringmenu opent en heeft geen overlap" % id, lay_ok)
	a.charge = 1.0
	var msg: String = a.use_skill(str(sk[0]), id)
	check("%s: skill werkt (%s)" % [id, msg], msg.contains("uses"))


func _eind() -> void:
	Settings.set_value("battle_style", 0)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("REKRUUTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAILED", passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _wacht(f: Callable, max_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		if f.call():
			return true
		await get_tree().process_frame
	return f.call()
