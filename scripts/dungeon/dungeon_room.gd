class_name DungeonRoom
extends "res://scripts/map.gd"
## v0.13 DUNGEONKAMER (De Vergeten Archieven), helemaal gebouwd uit DATA: room_id = sleutel in
## scripts/data/dungeon_rooms.gd. In _ready, VOOR map.gd zijn werk doet, bouwt deze node:
##   - Ground (TileMapLayer) met de dungeon-tegels van RPG ART (assets/tiles/dungeon/), botsing
##     op de massieve tegels, terrein "archief" (gevechtsachtergrond: de bibliotheek);
##   - het opslagboek (cyaan, book_point.tscn type "save") op de sokkel;
##   - spawnpunt 'ingang', de uitgang (MapExit) en onzichtbare blokkades achter de uitgang;
##   - de zichtbare MAP-MONSTERS (scripts/dungeon/map_monster.gd) in Objects (y-sort).
## v0.14 (Eerste Archief, 4 verdiepingen): MEERDERE uitgangen ("exits": teken -> map + spawn) en
##   benoemde spawnpunten ("spawns"), kisten (dungeon_chest.gd), HP-boeken, losse meubels
##   (dungeon_prop.gd), leesplekken, een tweede atlas (bibliotheek), monsterNIVEAU per kamer
##   ("tier": gaat mee naar GameState.start_battle; niet voor een baas) en BEWAKERS ("guard": true)
##   die na winst voor altijd weg blijven (vlag "bewaker:<kamer>/<id>" in GameState.story_flags).
## GEEN random encounters (encounters = false). Een monster aanraken = gevecht met zijn groep:
##   winst  -> dat monster is weg (GameState.defeated_map_monsters; terug als je de kamer
##             opnieuw binnenkomt), de anderen staan waar ze stonden;
##   vlucht -> monster blijft, de speler knippert INVULN seconden en kan niet geraakt worden.
## De monsters staan stil zolang er een tekstvak, het veldmenu, een cutscene of een overgang is.

const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const MapMonsterScript := preload("res://scripts/dungeon/map_monster.gd")
const BOOK_SCENE := "res://scenes/book_point.tscn"
const ChestScript := preload("res://scripts/dungeon/dungeon_chest.gd")
const Dungeon100Blue := preload("res://scripts/data/dungeon100_blue.gd")
const PropScript := preload("res://scripts/dungeon/dungeon_prop.gd")
const SignScript := preload("res://scripts/dungeon/dungeon_sign.gd")
const STORY_OBJECT_SCENE := "res://scenes/story_object.tscn"
const NPC_SCENE := "res://scenes/npc.tscn"
## Onkwetsbaar (knipperen) na vluchten, in seconden.
const INVULN := 1.5
## Na binnenkomen staan de monsters even stil (anders kan er meteen eentje op je springen).
const ENTRY_GRACE := 0.8
const BLINK := 0.1

## v0.15: TileSets per thema (sleutel "<thema>|botsing" of "<thema>|beeld").
static var _tilesets := {}

## Sleutel in DungeonRooms.ROOMS.
@export var room_id := "archief_ingang"

var room: Dictionary
var monsters: Array = []       # MapMonster-nodes (levend)
var save_book: Node2D
var invuln_left := 0.0
var _grace_left := ENTRY_GRACE
var _touch_lock := false
var _blink_t := 0.0
## Voor de autotest: monster-id van het laatst gestarte gevecht ("" = nog geen).
var last_touch_id := ""
var _cells := {}               # tile -> tegelnummer
var chests: Array = []         # DungeonChest-nodes
var books: Array = []          # boekpunten (HP/MP) uit "books"
var props: Array = []          # DungeonProp-nodes
var _blocked := {}             # tile -> true: kist/boek/meubel (map-monsters lopen er niet heen)
## v0.17 laag met boomkruinen/mist boven Objects (null = deze kamer heeft er geen)
var overlay: TileMapLayer
const OVERLAY_Z := 10


func _ready() -> void:
	_build()
	var returning: bool = GameState.has_return_point and GameState.return_map == scene_file_path
	var ctx: Dictionary = GameState.map_monster_battle
	var from_battle: bool = returning and not ctx.is_empty() and ctx.get("map", "") == scene_file_path
	if not from_battle:
		# vers binnen (of geladen): alle monsters zijn er weer
		GameState.defeated_map_monsters.erase(room_id)
	_spawn_monsters()
	if from_battle:
		_restore_after_battle(ctx)
	GameState.map_monster_battle = {}
	# v0.16 Kernkracht-stun telt af per stap van de speler
	player.stepped.connect(_stun_step)
	if GameState.pending_spawn == "" and not returning:
		var sp := get_spawn(default_spawn())
		if sp:
			player.place_at(sp.get_tile(), sp.facing)
	if music_track == "" and room_id.begins_with("archief"):
		music_track = "vergeten_archieven"
	super._ready()


## v0.19: een BAASKAMER zet het kamer-checkpoint niet (wie bij de baas sneuvelt, ontwaakt in de
## kamer ervoor). Data: "checkpoint": true/false per kamer; zonder die sleutel = geen checkpoint als
## er een monster met "boss": true in de kamer staat (ook als hij al verslagen is).
func allows_checkpoint() -> bool:
	if not sets_checkpoint:
		return false
	if room.has("checkpoint"):
		return bool(room["checkpoint"])
	return not is_boss_room(room)


static func is_boss_room(r: Dictionary) -> bool:
	return r.get("monsters", []).any(func(m): return m.get("boss", false))


# ---------------------------------------------------------------- bouwen
func _build() -> void:
	# v0.17: ook de kamers van het Donker Woud (scripts/data/woud_rooms.gd)
	room = DungeonRooms.room(room_id)
	if room.is_empty():
		push_error("Dungeonkamer '%s' bestaat niet in dungeon_rooms.gd / woud_rooms.gd" % room_id)
		return
	if map_name == "":
		map_name = str(room.get("name", room_id))
	encounters = false
	# v0.15 thema van deze kamer (tegels + losse sprites), zie DungeonRooms.THEMES
	DungeonRooms.current_theme = DungeonRooms.theme_of(room)
	ground.tile_set = tileset(true, DungeonRooms.current_theme)
	ground.clear()
	_cells.clear()
	var legend := DungeonRooms.legend_of(room)
	var floor_tiles: Array = room.get("floor_tiles", DungeonRooms.FLOOR)
	var layout: Array = room["layout"]
	var exit_cells := {}           # sleutel in "exits" -> Array[Vector2i]
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var ch := row[x]
			if not legend.has(ch):
				push_error("Dungeonkamer '%s': onbekend teken '%s' op (%d,%d)" % [room_id, ch, x, y])
				continue
			var n: int = legend[ch]
			if ch == ".":
				n = floor_variant(x, y, floor_tiles)
			_cells[Vector2i(x, y)] = n
			set_tile(ground, Vector2i(x, y), n)
			if DungeonRooms.EXIT_CHARS.has(ch):
				var key: String = DungeonRooms.EXIT_CHARS[ch]
				if not exit_cells.has(key):
					exit_cells[key] = []
				exit_cells[key].append(Vector2i(x, y))
	_build_overlay()
	var objects: Node2D = $Objects
	# opslagboek op de sokkel (4 px hoger, zodat de lessenaar op de sokkel staat);
	# v0.14: of een ander soort/plaatje ("save_type") met een eigen verschuiving ("save_offset")
	if room.has("save"):
		var s: Array = room["save"]
		save_book = load(BOOK_SCENE).instantiate()
		save_book.name = "SaveBook"
		save_book.type = str(room.get("save_type", "save"))
		save_book.position = Vector2(int(s[0]), int(s[1])) * 16 + Vector2(8, 8)
		objects.add_child(save_book)
		var off: Array = room.get("save_offset", [0, -4])
		save_book.get_node("Sprite2D").offset = Vector2(float(off[0]), float(off[1]))
	# v0.14 HP/MP-boeken
	for b in room.get("books", []):
		var bp: Node2D = load(BOOK_SCENE).instantiate()
		var bt: Array = b["tile"]
		bp.name = "Boek_%s_%d_%d" % [b.get("type", "hp"), int(bt[0]), int(bt[1])]
		bp.type = str(b.get("type", "hp"))
		bp.position = Vector2(int(bt[0]), int(bt[1])) * 16 + Vector2(8, 8)
		objects.add_child(bp)
		books.append(bp)
		_blocked[Vector2i(int(bt[0]), int(bt[1]))] = true
	# v0.14 kisten (eenmalig, vlag in de save)
	for c in room.get("chests", []):
		var ch: DungeonChest = ChestScript.new()
		ch.setup(c)
		ch.mimic_woke.connect(start_mimic_battle)
		ch.blue_secured.connect(_on_blue_secured)
		objects.add_child(ch)
		chests.append(ch)
		_blocked[ch.tile()] = true
	# v0.14 losse meubels
	for d in room.get("props", []):
		var info: Dictionary = DungeonRooms.PROPS.get(str(d.get("type", "")), {})
		if info.is_empty():
			push_error("Dungeonkamer '%s': onbekend meubel '%s'" % [room_id, d.get("type", "")])
			continue
		var pr: DungeonProp = PropScript.new()
		pr.setup(d, info)
		objects.add_child(pr)
		props.append(pr)
		for t in pr.blocked_tiles(d):
			_blocked[t] = true
	# v0.14 leesplekken (zonder botsing)
	for d in room.get("signs", []):
		var sg: Area2D = SignScript.new()
		sg.setup(d)
		objects.add_child(sg)
	# v0.17 verhaal-objecten en NPC's uit de data (bv. Noor in de wortelcocon, woud_rooms.gd)
	for d in room.get("objects", []):
		var so: Node2D = load(STORY_OBJECT_SCENE).instantiate()
		_story_common(so, d)
		so.texture = load(str(d["texture"]))
		so.hframes = int(d.get("hframes", 1))
		var tl: Array = d.get("tiles", [1, 1])
		so.tiles = Vector2i(int(tl[0]), int(tl[1]))
		so.frame_rules = d.get("frame_rules", [])
		so.glow_if = d.get("glow_if", {})
		if d.has("loop_texture"):
			so.loop_texture = load(str(d["loop_texture"]))
			so.loop_frames = int(d.get("loop_frames", 2))
			so.loop_time = float(d.get("loop_time", 0.5))
			so.loop_if = d.get("loop_if", {})
		if d.has("glow_color"):
			so.glow_color = Color(str(d["glow_color"]))
		objects.add_child(so)
	for d in room.get("npcs", []):
		var npc: Node2D = load(NPC_SCENE).instantiate()
		_story_common(npc, d)
		npc.npc_name = str(d.get("npc_name", d.get("name", "")))
		var ls: Array[String] = []
		for l in d.get("lines", []):
			ls.append(str(l))
		npc.lines = ls
		npc.facing = Story.dir_of(str(d.get("facing", "down")))
		if d.has("sheet"):
			npc.sheet = load(str(d["sheet"]))
		objects.add_child(npc)
	# v0.17 sfeer van het thema: kleurtint + mist (donker_woud)
	var td: Dictionary = DungeonRooms.theme_data(DungeonRooms.current_theme)
	if td.has("tint"):
		var cm := CanvasModulate.new()
		cm.name = "ThemaTint"
		cm.color = td["tint"]
		add_child(cm)
	if bool(td.get("mist", false)):
		add_child(load("res://scripts/dungeon/woud_mist.gd").new())
	# spawnpunten: "spawns" (v0.14) of het oude "spawn" (= 'ingang')
	var spawns: Dictionary = room.get("spawns", {})
	if spawns.is_empty() and room.has("spawn"):
		var o: Array = room["spawn"]
		spawns = {"ingang": [o[0], o[1], room.get("spawn_facing", "up")]}
	for sp_name in spawns:
		var v: Array = spawns[sp_name]
		var spawn := MapSpawn.new()
		spawn.name = str(sp_name)
		spawn.position = Vector2(int(v[0]), int(v[1])) * 16 + Vector2(8, 8)
		spawn.facing = Story.dir_of(str(v[2]) if v.size() > 2 else "up")
		$Spawns.add_child(spawn)
	# uitgangen: per sleutel alle tiles samen; onderaan (E/U) blokkades eronder (buiten de kamer)
	var exits: Dictionary = room.get("exits", {})
	if exits.is_empty() and room.has("exit"):
		exits = {"E": room["exit"]}
	for key in exit_cells:
		var tiles: Array = exit_cells[key]
		var data: Dictionary = exits.get(key, {})
		if data.is_empty():
			push_error("Dungeonkamer '%s': uitgang '%s' heeft geen doel in \"exits\"" % [room_id, key])
			continue
		var r := Rect2i(tiles[0], Vector2i.ONE)
		for t in tiles:
			r = r.expand(t).expand(t + Vector2i.ONE)
		var ex := MapExit.new()
		ex.name = "Uitgang_" + str(key)
		ex.position = Vector2(r.position) * 16
		ex.size_tiles = r.size
		ex.target_map = str(data.get("map", ""))
		ex.target_spawn = str(data.get("spawn", ""))
		var lines: Array[String] = []
		for l in data.get("lines", []):
			lines.append(str(l))
		ex.lines = lines
		$Exits.add_child(ex)
		for t in tiles:
			if t.y != layout.size() - 1:
				continue
			var wall := StaticBody2D.new()
			wall.name = "Rand_%d_%d" % [t.x, t.y + 1]
			wall.position = Vector2(t + Vector2i.DOWN) * 16 + Vector2(8, 8)
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(14, 14)
			cs.shape = rect
			wall.add_child(cs)
			add_child(wall)


## v0.17 OVERLAY-laag (boomkruinen, mist, glitch-pixels) BOVEN de speler en de objecten, zonder
## botsing. Uit de kamerdata:
##   "trees":   [[x, y, soort]]  (x, y) = linker stamvoet; voet op de grondlaag (massief), de kruin
##              (2x2) op de overlay erboven. Soorten: THEMES[thema]["trees"] (Donker Woud: A, B).
##   "mist":    [[x, y, lengte]] mistband (THEMES[thema]["mist_band"]: begin, midden..., eind)
##   "overlay": [[x, y, tegel]]  losse overlay-tegels (bv. 84 mistwolk, 108 glitch-pixels)
func _build_overlay() -> void:
	var td: Dictionary = DungeonRooms.theme_data(DungeonRooms.current_theme)
	if not (room.has("trees") or room.has("mist") or room.has("overlay")):
		return
	overlay = TileMapLayer.new()
	overlay.name = "Overlay"
	overlay.tile_set = tileset(false, DungeonRooms.current_theme)
	overlay.z_index = OVERLAY_Z
	add_child(overlay)
	move_child(overlay, $Objects.get_index() + 1)
	var kinds: Dictionary = td.get("trees", {})
	for tr in room.get("trees", []):
		var k: Dictionary = kinds.get(str(tr[2]), {})
		if k.is_empty():
			push_error("Dungeonkamer '%s': onbekende boom '%s'" % [room_id, tr[2]])
			continue
		var foot := Vector2i(int(tr[0]), int(tr[1]))
		for i in 2:
			var t := foot + Vector2i(i, 0)
			_cells[t] = int(k["feet"][i])
			set_tile(ground, t, int(k["feet"][i]))
			set_tile(overlay, t + Vector2i(0, -2), int(k["crown"][0][i]))
			set_tile(overlay, t + Vector2i(0, -1), int(k["crown"][1][i]))
	var band: Array = td.get("mist_band", [])
	for m in room.get("mist", []):
		var n := int(m[2])
		for i in n:
			var tile: int
			if band.size() < 3:
				tile = int(band[0]) if not band.is_empty() else 82
			elif i == 0:
				tile = int(band[0])
			elif i == n - 1:
				tile = int(band[band.size() - 1])
			else:
				tile = int(band[1 + (i - 1) % (band.size() - 2)])
			set_tile(overlay, Vector2i(int(m[0]) + i, int(m[1])), tile)
	for o in room.get("overlay", []):
		set_tile(overlay, Vector2i(int(o[0]), int(o[1])), int(o[2]))


## v0.17 naam, tile, event en show_if van een verhaal-object/NPC uit de kamerdata.
func _story_common(n: Node2D, d: Dictionary) -> void:
	n.name = str(d.get("name", "Object"))
	var t: Array = d.get("tile", [0, 0])
	n.position = Vector2(int(t[0]), int(t[1])) * 16 + Vector2(8, 8)
	n.event = str(d.get("event", ""))
	n.event_arg = str(d.get("event_arg", ""))
	n.show_if = d.get("show_if", {})
	_blocked[Vector2i(int(t[0]), int(t[1]))] = true


## Naam van het spawnpunt als je zonder spawn binnenkomt ('ingang', anders het eerste).
func default_spawn() -> String:
	if get_node_or_null("Spawns/ingang"):
		return "ingang"
	var sp := $Spawns.get_children()
	return sp[0].name if not sp.is_empty() else ""


## Zet tegelnummer n (0-79 dungeon, vanaf 100 bibliotheek) op een TileMapLayer met tileset().
static func set_tile(layer: TileMapLayer, t: Vector2i, n: int) -> void:
	var src := 0
	# v0.17: thema met één atlas (Donker Woud: 0-111 in woud_tiles.png) -> nooit de bibliotheek
	if n >= DungeonRooms.LIB_BASE and not DungeonRooms.single_atlas():
		src = 1
		n -= DungeonRooms.LIB_BASE
	layer.set_cell(t, src, Vector2i(n % DungeonRooms.COLS, n / DungeonRooms.COLS))


## Monsterniveau van deze kamer (0 = geen).
func tier() -> int:
	return int(room.get("tier", 0))


## Vlag van een verslagen bewaker in GameState.story_flags.
static func guard_flag(rid: String, monster_id: String) -> String:
	return "bewaker:%s/%s" % [rid, monster_id]


## Vloer A/B/C voor '.' (vast patroon, zodat de kamer er altijd hetzelfde uitziet).
## v0.14: 'tiles' = de vloernummers van de kamer ("floor_tiles", bv. houten vloer 132/133).
static func floor_variant(x: int, y: int, tiles: Array = DungeonRooms.FLOOR) -> int:
	var h := absi((x * 73856093) ^ (y * 19349663)) % 7
	if tiles.size() < 3:
		return int(tiles[h % tiles.size()])
	return int(tiles[0 if h < 4 else (1 if h < 6 else 2)])


## TileSet voor de dungeon-atlas (bron 0) + bibliotheek-atlas (bron 1), één keer per thema gemaakt:
## botsing op SOLID, terrein "archief". v0.14: collide = false -> zonder botsing (alleen beeld,
## voor de puzzelkamer: daar komt de botsing uit PuzzleLogic).
## v0.15: theme = sleutel in DungeonRooms.THEMES ("" = het huidige thema, anders DEFAULT_THEME).
static func tileset(collide := true, theme := "") -> TileSet:
	if theme == "":
		theme = DungeonRooms.current_theme if DungeonRooms.current_theme != "" else DungeonRooms.DEFAULT_THEME
	var key := "%s|%s" % [theme, "botsing" if collide else "beeld"]
	if _tilesets.has(key):
		return _tilesets[key]
	var td_theme: Dictionary = DungeonRooms.theme_data(theme)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 1)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "terrain")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	for si in 2:
		var src := TileSetAtlasSource.new()
		src.texture = load(str(td_theme.get("tiles", DungeonRooms.TILES)) if si == 0
				else str(td_theme.get("lib_tiles", DungeonRooms.LIB_TILES)))
		src.texture_region_size = Vector2i(16, 16)
		ts.add_source(src, si)
		var count := int(src.texture.get_width() / 16) * int(src.texture.get_height() / 16)
		for n in count:
			var c := Vector2i(n % DungeonRooms.COLS, n / DungeonRooms.COLS)
			src.create_tile(c)
			var td := src.get_tile_data(c, 0)
			td.set_custom_data("terrain", DungeonRooms.terrain_of(theme))     # v0.17: per thema
			var num := n if (si == 0 and DungeonRooms.single_atlas(theme)) else n + si * DungeonRooms.LIB_BASE
			if collide and DungeonRooms.is_solid(num, theme):
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	_tilesets[key] = ts
	return ts


func _spawn_monsters() -> void:
	var dead: Dictionary = GameState.defeated_map_monsters.get(room_id, {})
	var i := 0
	for d in room.get("monsters", []):
		i += 1
		var mid := str(d.get("id", d.get("enemy", "")))
		if dead.has(mid):
			continue
		if d.get("guard", false) and GameState.story_flags.has(guard_flag(room_id, mid)):
			continue      # bewaker: voor altijd verslagen
		var m: MapMonster = MapMonsterScript.new()
		m.setup(self, d, hash(room_id) + i * 7919 + randi() % 1000)
		$Objects.add_child(m)
		monsters.append(m)


func get_monster(id: String) -> MapMonster:
	for m in monsters:
		if is_instance_valid(m) and m.monster_id == id:
			return m
	return null


## Tegelnummer op een tile (-1 = buiten de kamer).
func cell(t: Vector2i) -> int:
	return int(_cells.get(t, -1))


func is_wall(t: Vector2i) -> bool:
	var n := cell(t)
	return n < 0 or DungeonRooms.is_solid(n)


# ---------------------------------------------------------------- monsters
## Mogen de monsters bewegen/aanraken? Niet tijdens tekst, menu, cutscene, overgang of gevecht.
func monsters_active() -> bool:
	return is_node_ready() and _grace_left <= 0.0 and not GameState.in_battle and not GameState.changing_map \
			and not Dialog.is_open and not menu_open() and not Story.running and not _touch_lock \
			and is_instance_valid(player) and not player.input_locked


## Tile van de speler en (tijdens een stap) waar hij heen loopt.
func player_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = [player.get_tile()]
	if player.is_moving:
		var tp: Vector2 = player.get("_target")
		var t := Vector2i((tp / 16.0).floor())
		if not out.has(t):
			out.append(t)
	return out


## Mag monster m naar tile 'to'? "free", "player" (daar staat de speler: gevecht),
## "blocked" (ander monster / speler onkwetsbaar) of "wall" (muur, platform, uitgang, savepunt).
func monster_can_enter(m: Node, to: Vector2i) -> String:
	for dx in m.size.x:
		for dy in m.size.y:
			var t: Vector2i = to + Vector2i(dx, dy)
			var n := cell(t)
			if n < 0 or DungeonRooms.is_solid(n) or DungeonRooms.is_no_monster(n):
				return "wall"
			if save_book and Vector2i((save_book.position / 16.0).floor()) == t:
				return "wall"
			if _blocked.has(t):
				return "wall"
			if t in player_tiles():
				return "blocked" if invuln_left > 0.0 else "player"
			for o in monsters:
				if o != m and is_instance_valid(o) and o.covers(t):
					return "blocked"
	return "free"


func can_touch() -> bool:
	return monsters_active() and invuln_left <= 0.0


## Monster aangeraakt (door de speler of andersom): gevecht met zijn groep.
func monster_touch(m: Node) -> void:
	if not can_touch() or not (m in monsters):
		return
	if m.is_stunned():
		return       # v0.16: verlamd door Kernkracht: geen gevecht
	start_monster_battle(m)


## Start het gevecht van dit monster (ook voor de autotest). Onthoudt waar alle monsters staan.
func start_monster_battle(m: Node) -> void:
	_touch_lock = true
	last_touch_id = m.monster_id
	var t := _prepare_battle(m.monster_id)
	# v0.14: monsterniveau van de kamer (een baas krijgt geen niveau: zijn stats staan in game_data.gd)
	GameState.start_battle(m.group.duplicate(), t, player.facing, terrain_at(t), m.boss, 0 if m.boss else tier())


## Het Gesimuleerde Archief: een Mimic-kist is wakker; gevecht met een Mimic (geschaald met de verdieping
## via GameState.dungeon100_floor, zoals elk monster in de kerker). Wint de groep, dan gaat de kist open
## (_restore_after_battle); vlucht ze, dan blijft hij dicht.
func start_mimic_battle(ch: DungeonChest) -> void:
	_touch_lock = true
	var t := _prepare_battle("mimic:" + ch.chest_id, ch.chest_id)
	GameState.start_battle([Dungeon100Blue.MIMIC_ENEMY], t, player.facing, terrain_at(t), false, 0)


## Gevechtscontext vastleggen (waar staan de monsters, wie vocht) en de speler stilzetten. Geeft de
## laatste hele tile van de speler terug (niet halverwege een stap). 'mimic' = kist-id bij een Mimic.
func _prepare_battle(id: String, mimic := "") -> Vector2i:
	var positions := {}
	for o in monsters:
		if is_instance_valid(o):
			positions[o.monster_id] = o.get_state()     # tijdens een stap: de tile waar hij vandaan kwam
	GameState.map_monster_battle = {"map": scene_file_path, "room": room_id, "id": id,
			"positions": positions, "mimic": mimic}
	player.input_locked = true
	var t: Vector2i = player.get_tile()
	if player.is_moving:
		var tp: Vector2 = player.get("_target")
		t = Vector2i((tp / 16.0).floor()) - player.facing
	return t


## Een Blauwe Kist is geopend: meteen automatisch opslaan, zodat de databank niet verloren gaat.
func _on_blue_secured(_chest: DungeonChest) -> void:
	try_autosave("blauw")


func _restore_after_battle(ctx: Dictionary) -> void:
	var pos: Dictionary = ctx.get("positions", {})
	for m in monsters:
		if pos.has(m.monster_id):
			var st: Dictionary = pos[m.monster_id]
			m.place_at(Vector2i(int(st["tile"][0]), int(st["tile"][1])), Vector2i(int(st["facing"][0]), int(st["facing"][1])))
			if int(st.get("stun", 0)) > 0:
				m.stun(int(st["stun"]))     # v0.16: verlamd gebleven tijdens een ander gevecht
	var id := str(ctx.get("id", ""))
	var mimic := str(ctx.get("mimic", ""))
	if mimic != "" and GameState.last_battle_result == "win":
		for ch in chests:
			if is_instance_valid(ch) and ch.chest_id == mimic:
				ch.open_after_mimic()
	match GameState.last_battle_result:
		"win":
			if not GameState.defeated_map_monsters.has(room_id):
				GameState.defeated_map_monsters[room_id] = {}
			GameState.defeated_map_monsters[room_id][id] = true
			var m := get_monster(id)
			if m and m.data.get("guard", false):
				GameState.story_flags[guard_flag(room_id, id)] = true
			if m:
				monsters.erase(m)
				m.queue_free()
		"flee":
			start_invuln()


## v0.16: de speler zette een stap -> verlamde monsters tellen af.
func _stun_step(_t: Vector2i) -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.step_tick()


## Knipperen + onkwetsbaar (na vluchten).
func start_invuln(sec := INVULN) -> void:
	invuln_left = sec
	_blink_t = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	if _grace_left > 0.0 and not GameState.changing_map and not Story.running:
		_grace_left -= delta
	if invuln_left > 0.0:
		invuln_left = maxf(0.0, invuln_left - delta)
		_blink_t += delta
		player.sprite.modulate.a = 1.0 if invuln_left <= 0.0 or int(_blink_t / BLINK) % 2 == 0 else 0.25
	# vangnet: lopen speler en monster tegelijk naar dezelfde tile, dan raken ze elkaar hier
	if can_touch():
		for m in monsters:
			if is_instance_valid(m) and not m.is_stunned() and m.touches(player.position):
				monster_touch(m)
				break
