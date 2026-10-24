extends RefCounted
## Party-kaartsprites 24x32 (Dax, Seren, Vesper WM1; RPG ART, assets/sprites/party_24x32/) binnen --autotest.
## Alleen dit blok: godot --path . -- --autotest --test-party-sprites [--party-shots=/pad/map]
## Zonder de vlag draait het blok aan het eind van de volledige --autotest mee.
## t = de autotest-node (check/frames/walk/close_dialog/...).
## Controleert: sheets 72x128 met frames van 24x32, anker onder-midden (voeten op de tegelrand, botsing
## 14x14 ongewijzigd), de juiste sheet per leider, de wereldkaart houdt de oude 16x24-sprite, elke
## deur/uitgang heeft een vrije aanlooptegel, en echt door een deur/uitgang lopen op 3 maps.

const SD := preload("res://scripts/data/story_data.gd")
const MAPS := "res://scenes/maps/"
const KAART := "res://assets/sprites/som/kaart/"
const BRON := "res://assets/sprites/party_24x32/"
const OUD := "res://assets/sprites/player.png"
const TEGEL := 16
## Naam -> [held-id, sheet in som/kaart, bronbestand in party_24x32]
const HELDEN := {
	"Dax": ["dennis", "dax_wm1.png", "dax_wm1.png"],
	"Seren": ["lotte", "seren_wm1.png", "seren_wm1.png"],
	"Vesper": ["noor", "vesper.png", "vesper_wm1.png"],
}
const RICHTING := {Vector2i.UP: "move_up", Vector2i.DOWN: "move_down", Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right"}
const WM1_MAP := MAPS + "wilgendal.tscn"
const RICHTING_NAAM := {Vector2i.DOWN: "down", Vector2i.UP: "up", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}
const DAX_OFFSET := Vector2(0, -8)

## Uitgangen in een muur/berg waar je van onderaf tegenaan loopt (map.gd _on_player_bumped).
const BUMP_UITGANGEN: Array[String] = ["NaarBouwplaats", "NaarBerggrot"]

var t: Node
var shots := ""
var _genegeerd: Array[RID] = []


func _init(p_t: Node) -> void:
	t = p_t
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--party-shots="):
			shots = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(shots)


func run() -> void:
	var oude_stijl: int = int(Settings.get_value("battle_style"))
	# Action-dungeons zetten hun eigen sheet (scripts/som/, vervolgtaak); hier de veldsprite in Classic.
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	GameState.encounter_multiplier = 0.0
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	GameState.join_member("noor")
	GameState.story_step = SD.KLAAR
	_sheet_checks()
	_anker_checks()
	_anker_gelijk_dax()
	await _leider_checks()
	await _deur_sweep()
	await _deur_wandelingen()
	await _wm1_direction_shots()
	Settings.set_value("battle_style", oude_stijl)


# ---------------------------------------------------------------- hulpjes
func _laad(pad: String) -> Node:
	GameState.in_battle = false
	GameState.changing_map = false
	t.get_tree().change_scene_to_file(pad)
	for i in 180:
		await t.get_tree().process_frame
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and i > 4:
			return s
	return null


func _wacht_op_map(pad: String, timeout := 8.0) -> Node:
	var tijd := 0.0
	while tijd < timeout:
		var s: Node = t.get_tree().current_scene
		if s != null and str(s.scene_file_path) == pad and s.is_node_ready() and not GameState.changing_map \
				and s.get_node_or_null("Objects/Player") != null:
			return s
		await t.get_tree().process_frame
		tijd += t.get_process_delta_time()
	return null


func _speler(s: Node) -> CharacterBody2D:
	return s.get_node_or_null("Objects/Player") as CharacterBody2D if s else null


func _zet_leider(naam: String) -> void:
	var id: String = HELDEN[naam][0]
	for i in GameState.party.size():
		if str(GameState.party[i].get("id", "")) == id:
			GameState.move_member_to_front(i)
			return


func _midden(tegel: Vector2i) -> Vector2:
	return Vector2(tegel) * TEGEL + Vector2.ONE * (TEGEL / 2.0)


## Wat houdt het 14x14-lijf van de speler op deze tegel tegen (muur, deur, NPC)? Leeg = past.
func _blokkers(p: CharacterBody2D, tegel: Vector2i) -> Array:
	var cs := p.get_node("CollisionShape2D") as CollisionShape2D
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = Transform2D(0.0, _midden(tegel) + cs.position)
	q.collision_mask = p.collision_mask
	q.exclude = [p.get_rid()] + _genegeerd
	return p.get_world_2d().direct_space_state.intersect_shape(q, 4).map(
			func(h): return str(h["collider"].name) if h["collider"] else "?")


func _vrij(p: CharacterBody2D, tegel: Vector2i) -> bool:
	return _blokkers(p, tegel).is_empty()


## Puzzelpoorten (scripts/puzzle/gate.gd) als open behandelen: een dichte poort voor de uitgang is
## puzzelstand, geen maatprobleem van de sprite.
func _poorten_open(s: Node, p: CharacterBody2D) -> void:
	_genegeerd = []
	var stapel: Array[Node] = [s]
	while not stapel.is_empty():
		var n: Node = stapel.pop_back()
		if n is StaticBody2D and "gate_id" in n:
			_genegeerd.append((n as StaticBody2D).get_rid())
			p.add_collision_exception_with(n)
		stapel.append_array(n.get_children())


## Kan de speler van 'van' één tegel in 'dir' stappen (zelfde test als player.gd _can_move)?
func _kan_stappen(p: CharacterBody2D, van: Vector2i, dir: Vector2i) -> bool:
	return not p.test_move(Transform2D(0.0, _midden(van)), Vector2(dir) * TEGEL)


## Deuren en uitgangen met een echte doelmap: [{node, soort ("deur"/"uitgang"), tegels, doel}]
func _doorgangen(s: Node) -> Array:
	var uit := []
	var exits := s.get_node_or_null("Exits")
	if exits:
		for e in exits.get_children():
			if e is MapExit and e.target_map != "" and ResourceLoader.exists(e.target_map):
				var tegels: Array[Vector2i] = []
				var r: Rect2i = e.tile_rect()
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						tegels.append(Vector2i(x, y))
				uit.append({"node": e, "soort": "uitgang", "tegels": tegels, "doel": e.target_map})
	var objs := s.get_node_or_null("Objects")
	if objs:
		for o in objs.get_children():
			if o is StaticBody2D and o.has_method("bump") and "target_map" in o and str(o.target_map) != "" \
					and ResourceLoader.exists(str(o.target_map)):
				var tegels: Array[Vector2i] = [Vector2i((o.position / TEGEL).floor())]
				uit.append({"node": o, "soort": "deur", "tegels": tegels, "doel": str(o.target_map)})
	return uit


## Aanlooptegels: [tegel, richting] van waaruit de speler de deur/uitgang in kan lopen, binnen de kaart,
## dichtstbijzijnde spawnpunt eerst (dus vanaf de kant waar de speler echt staat).
func _aanloop(p: CharacterBody2D, d: Dictionary) -> Array:
	var s: Node = t.get_tree().current_scene
	var ground := s.get_node_or_null("Ground") as TileMapLayer
	var kaart: Rect2i = ground.get_used_rect() if ground else Rect2i(-9999, -9999, 19999, 19999)
	var spawns: Array[Vector2i] = []
	var sp_node := s.get_node_or_null("Spawns")
	if sp_node:
		for n in sp_node.get_children():
			spawns.append(Vector2i(((n as Node2D).position / TEGEL).floor()))
	var uit := []
	for tegel in d["tegels"]:
		for dir in RICHTING:
			var van: Vector2i = tegel - dir
			if (d["tegels"] as Array).has(van) or not kaart.has_point(van) or not _vrij(p, van):
				continue
			# uitgang: de stap moet lukken; deur en bump-uitgang: tegenaan lopen (bump) opent hem
			var bump: bool = d["soort"] == "deur" or (BUMP_UITGANGEN.has(str(d["node"].name)) and dir == Vector2i.UP)
			if (d["soort"] == "uitgang" and _kan_stappen(p, van, dir)) or (bump and not _kan_stappen(p, van, dir)):
				uit.append([van, dir])
	var afstand := func(v: Vector2i) -> int:
		var m := 1 << 30
		for sp in spawns:
			m = mini(m, absi(sp.x - v.x) + absi(sp.y - v.y))
		return m
	uit.sort_custom(func(a, b): return afstand.call(a[0]) < afstand.call(b[0]))
	return uit


func _shot(naam: String, scale_3x := false) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img: Image = t.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	if scale_3x:
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(shots.path_join(naam + ".png"))
	print("INFO  party-screenshot (%dx%d): %s" % [img.get_width(), img.get_height(), shots.path_join(naam + ".png")])


# ---------------------------------------------------------------- 1) sheets
func _sheet_checks() -> void:
	for naam in HELDEN:
		var pad: String = KAART + HELDEN[naam][1]
		var bron: String = BRON + HELDEN[naam][2]
		var tex: Texture2D = load(pad) if ResourceLoader.exists(pad) else null
		t.check("party-sprites: %s = %s, 72x128, frames 24x32 (3x4)" % [naam, pad.get_file()],
				tex != null and tex.get_size() == Vector2(72, 128) and MapSprite.frame_maat(tex) == MapSprite.NIEUW
				and MapSprite.is_nieuw(tex))
		t.check("party-sprites: %s is de RPG ART-sheet uit party_24x32/%s (bytes gelijk), .import aanwezig" % [pad.get_file(), bron.get_file()],
				FileAccess.file_exists(bron) and FileAccess.get_file_as_bytes(pad) == FileAccess.get_file_as_bytes(bron)
				and FileAccess.file_exists(pad + ".import"))


# ---------------------------------------------------------------- 2) anker onder-midden
func _anker_checks() -> void:
	t.check("party-sprites: voet-offset 24x32 = (0,-8), 16x24 = (0,-4): onderrand allebei op +8 (tegelrand)",
			MapSprite.voet_offset(MapSprite.NIEUW) == Vector2(0, -8) and MapSprite.voet_offset(MapSprite.OUD) == Vector2(0, -4)
			and MapSprite.voet_offset(MapSprite.NIEUW).y + MapSprite.NIEUW.y / 2.0 == TEGEL / 2.0
			and MapSprite.voet_offset(MapSprite.OUD).y + MapSprite.OUD.y / 2.0 == TEGEL / 2.0)
	var speler: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	t.add_child(speler)
	var cs := speler.get_node("CollisionShape2D") as CollisionShape2D
	var vorm_oud: Vector2 = (cs.shape as RectangleShape2D).size
	var oud_rect: Rect2 = speler.sprite.get_rect()
	for naam in HELDEN:
		var pad: String = KAART + HELDEN[naam][1]
		speler.zet_sheet(load(pad))
		var sp: Sprite2D = speler.sprite
		var rect := sp.get_rect()
		t.check("party-sprites: %s in de speler: centered, rect (-12,-24) 24x32 -> voeten op +8, midden x=0, botsing %s op (0,0)" % [naam, vorm_oud],
				sp.centered and sp.hframes == 3 and sp.vframes == 4 and sp.offset == Vector2(0, -8)
				and rect == Rect2(-12, -24, 24, 32) and rect.end.y == oud_rect.end.y and rect.get_center().x == 0.0
				and (cs.shape as RectangleShape2D).size == vorm_oud and vorm_oud == Vector2(14, 14) and cs.position == Vector2.ZERO)
		# In de art zelf: elk frame staat met de voeten onderaan en ongeveer in het midden.
		var img := Image.load_from_file(ProjectSettings.globalize_path(pad))
		var fout := ""
		for rij in 4:
			for kol in 3:
				var used := img.get_region(Rect2i(kol * 24, rij * 32, 24, 32)).get_used_rect()
				if used.size == Vector2i.ZERO or used.end.y < 30 or absf(used.get_center().x - 12.0) > 4.0:
					fout += "r%dk%d %s; " % [rij, kol, used]
		t.check("party-sprites: %s alle 12 frames: voeten in de onderste 3 px, horizontaal gecentreerd (%s)" % [naam, fout if fout != "" else "ok"], fout == "")
	speler.queue_free()


func _anker_gelijk_dax() -> void:
	var dax_tex: Texture2D = load(KAART + "dax_wm1.png")
	var speler: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	t.add_child(speler)
	speler.zet_sheet(dax_tex)
	var dax_off: Vector2 = speler.sprite.offset
	var dax_rect: Rect2 = speler.sprite.get_rect()
	for naam in ["Seren", "Vesper"]:
		speler.zet_sheet(load(KAART + HELDEN[naam][1]))
		t.check("party-sprites: %s anker/offset gelijk aan Dax (offset %s, rect.end.y %s)" % [naam, speler.sprite.offset, speler.sprite.get_rect().end.y],
				speler.sprite.offset == dax_off and speler.sprite.offset == DAX_OFFSET
				and speler.sprite.get_rect().end.y == dax_rect.end.y)
	speler.queue_free()


# ---------------------------------------------------------------- WM1: vier richtingen (3x nearest) voor PR-artifacts
func _wm1_direction_shots() -> void:
	if shots == "":
		return
	var s := await _laad(WM1_MAP)
	var p := _speler(s)
	if p == null:
		t.check("party-sprites: WM1 %s geladen voor richting-screenshots" % WM1_MAP.get_file(), false)
		return
	await t.get_tree().create_timer(0.5).timeout
	for naam in ["Seren", "Vesper"]:
		_zet_leider(naam)
		KaartStijl.held_toepassen(s)
		var sheet_ok: bool = p.sprite.texture.resource_path == KAART + HELDEN[naam][1]
		t.check("party-sprites: WM1 leider %s sheet %s" % [naam, HELDEN[naam][1]], sheet_ok and p.sprite.offset == DAX_OFFSET)
		for dir in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			p.face(dir)
			await t.frames(2)
			var slug: String = naam.to_lower()
			await _shot("wm1_%s_%s" % [slug, RICHTING_NAAM[dir]], true)


# ---------------------------------------------------------------- 3) juiste sheet per leider
func _leider_checks() -> void:
	for naam in HELDEN:
		_zet_leider(naam)
		var pad: String = KAART + HELDEN[naam][1]
		t.check("party-sprites: leider %s -> held_sheet/leider_sheet/speler_sheet = %s" % [naam, pad.get_file()],
				KaartStijl.held_sheet(naam) == pad and KaartStijl.leider_sheet() == pad
				and KaartStijl.speler_sheet("wilgendal") == pad)
	_zet_leider("Dax")
	var oude_naam: String = str(GameState.party[0].get("name", ""))
	GameState.party[0]["name"] = "Kees"
	t.check("party-sprites: hernoemde Dax ('Kees') houdt dax_wm1.png (op id)", KaartStijl.leider_sheet() == KAART + "dax_wm1.png")
	GameState.party[0]["name"] = oude_naam
	# Op een stadsmap en in een dungeon: elke leider zijn eigen sheet; leiderwissel ververst meteen.
	for pad in [MAPS + "esdoorn.tscn", MAPS + "archief_ingang.tscn"]:
		var s := await _laad(pad)
		var p := _speler(s)
		var fout := ""
		for naam in HELDEN:
			_zet_leider(naam)
			var tex: Texture2D = p.sprite.texture if p else null
			if tex == null or tex.resource_path != KAART + HELDEN[naam][1] or p.sprite.offset != Vector2(0, -8):
				fout += "%s -> %s; " % [naam, tex.resource_path.get_file() if tex else "geen speler"]
		t.check("party-sprites: %s: Dax/Seren/Vesper als leider tonen hun 24x32-sheet (%s)" % [pad.get_file(), fout if fout != "" else "ok"],
				p != null and fout == "")
	_zet_leider("Dax")
	var wk := await _laad(MAPS + "wereldkaart.tscn")
	var wp := _speler(wk)
	t.check("party-sprites: wereldkaart houdt de oude 16x24 player.png (offset -4)",
			wp != null and wp.sprite.texture.resource_path == OUD and wp.sprite.offset == Vector2(0, -4)
			and not KaartStijl.held_nieuw_op(MAPS + "wereldkaart.tscn"))


# ---------------------------------------------------------------- 4) elke deur/uitgang
func _deur_sweep() -> void:
	_zet_leider("Dax")
	var fout := ""
	var n_maps := 0
	var n_door := 0
	for f in DirAccess.get_files_at(MAPS):
		if not f.ends_with(".tscn"):
			continue
		var s := await _laad(MAPS + f)
		var p := _speler(s)
		if p == null:
			continue
		n_maps += 1
		if KaartStijl.held_nieuw_op(MAPS + f) and not (p.sprite.texture.resource_path == KAART + "dax_wm1.png"
				and p.sprite.get_rect().end.y == TEGEL / 2.0):
			fout += "%s: sheet %s; " % [f, p.sprite.texture.resource_path.get_file()]
		_poorten_open(s, p)
		for d in _doorgangen(s):
			n_door += 1
			if _aanloop(p, d).is_empty():
				var buren := ""
				for tegel in d["tegels"]:
					for dir in RICHTING:
						var van: Vector2i = tegel - dir
						buren += "%s blok=%s stap=%s, " % [van, _blokkers(p, van), _kan_stappen(p, van, dir)]
				fout += "%s: %s %s (%s) zonder vrije aanlooptegel [%s]; " % [f, d["soort"], d["node"].name, d["tegels"], buren]
		_genegeerd = []
		await t.get_tree().process_frame
	t.check("party-sprites: alle %d deuren/uitgangen op %d maps: 14x14-lijf past ervoor en kan erin (%s)" % [n_door, n_maps, fout if fout != "" else "ok"],
			fout == "" and n_maps >= 40 and n_door >= 40)


# ---------------------------------------------------------------- 5) echt door een deur lopen
## Laad 'pad', zet 'naam' als leider, loop door de eerste deur/uitgang (naar 'doel' als opgegeven).
func _wandel(pad: String, naam: String, doel: String, shot: String) -> void:
	var s := await _laad(pad)
	_zet_leider(naam)
	var p := _speler(s)
	if p == null:
		t.check("party-sprites: %s geladen met speler" % pad.get_file(), false)
		return
	await t.close_dialog()
	var gekozen := {}
	var start := []
	for d in _doorgangen(s):
		if doel != "" and d["doel"] != doel:
			continue
		if str(d["node"].get("event")) != "":
			continue
		var a := _aanloop(p, d)
		if not a.is_empty():
			gekozen = d
			start = a[0]
			break
	if gekozen.is_empty():
		t.check("party-sprites: %s heeft een open deur/uitgang%s" % [pad.get_file(), " naar " + doel.get_file() if doel != "" else ""], false)
		return
	p.place_at(start[0], start[1])
	# fade-in van de vorige wissel laten aflopen (anders is de screenshot donker)
	await t.get_tree().create_timer(0.8).timeout
	var sheet_ok: bool = p.sprite.texture.resource_path == KAART + HELDEN[naam][1]
	var deur_naam := str(gekozen["node"].name)
	await _shot(shot)
	var actie: String = RICHTING[start[1]]
	await t.walk(actie, 1)
	if gekozen["soort"] == "deur" and not GameState.changing_map:
		# tegen de deur aan lopen = bump; nog even de richting vasthouden
		Input.action_press(actie)
		await t.frames(8)
		Input.action_release(actie)
	var doelpad: String = gekozen["doel"]
	var aankomst := await _wacht_op_map(doelpad)
	var ap := _speler(aankomst)
	if aankomst != null:
		await t.get_tree().create_timer(0.8).timeout
		await _shot(shot + "_aankomst")
	var aan_ok: bool = ap != null and (not KaartStijl.held_nieuw_op(doelpad)
			or ap.sprite.texture.resource_path == KAART + HELDEN[naam][1])
	t.check("party-sprites: %s met %s (%s): door %s %s van %s naar %s, sheet klopt voor en na" % [pad.get_file(), naam,
			HELDEN[naam][1], gekozen["soort"], deur_naam, start[0], doelpad.get_file()],
			sheet_ok and aankomst != null and aan_ok)


func _deur_wandelingen() -> void:
	await _wandel(MAPS + "esdoorn.tscn", "Dax", MAPS + "esdoorn_herberg.tscn", "party_stad_esdoorn_dax")
	await _wandel(MAPS + "esdoorn_herberg.tscn", "Seren", MAPS + "esdoorn.tscn", "party_herberg_seren")
	await _wandel(MAPS + "archief_ingang.tscn", "Vesper", "", "party_dungeon_archief_vesper")
	_zet_leider("Dax")
