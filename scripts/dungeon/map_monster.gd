class_name MapMonster
extends StaticBody2D
## v0.13 ZICHTBAAR MAP-MONSTER (Lufia 2-stijl) in een dungeonkamer (scripts/dungeon/dungeon_room.gd).
## Gegevens komen uit scripts/data/dungeon_rooms.gd ("monsters"). Beweegt tile voor tile:
## korte pauze -> willekeurige richting -> 1 tile lopen als de kamer (DungeonRoom) dat goed vindt.
## Muren, de speler en andere monsters blokkeren. Loopt hij TEGEN de speler aan, of loopt de
## speler tegen hem aan / drukt A ervoor, dan meldt hij dat aan de kamer (gevecht).
## Plaatje: assets/map_monsters/<sprite of enemy>.png
##   - 4 rijen (onder, links, rechts, boven) x 2 kolommen (stap A, stap B), frames 16x16; of
##   - 1 rij frames (bv. de Golem: 2 frames 32x32, alleen de kern pulseert), loopt langzaam rond.
## Ontbreekt het bestand: het gevechtsplaatje verkleind + magenta hoekjes (= placeholder).

const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const SPRITE_DIR := "res://assets/map_monsters/"
## Loopsnelheid in pixels per seconde (de speler loopt 64).
const WALK_SPEED := 40.0
## Pauze tussen twee stappen (seconden, willekeurig ertussen).
const PAUSE := Vector2(0.35, 1.3)
## Stap-animatie (frames per seconde) voor rondlopende monsters.
const WALK_FPS := 4.0
const PLACEHOLDER_COLOR := Color("ff1ee6")
const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const Dungeon100Scaling := preload("res://scripts/data/dungeon100_scaling.gd")

var room: Node = null
var data := {}
var monster_id := ""
var enemy_id := ""
var moves := true
## v0.21: vermomd (Mimic als dichte kist): geen stun-tint, geen sterretjes, geen flits.
var disguised := false
var boss := false
## Task #4: verdieping van de dungeon van 100 verdiepingen (eigen "floor" in de data, anders
## GameState.dungeon100_floor; 0 = gewoon monster). Het gevecht zelf schaalt via GameState.dungeon100_floor
## (battle.gd); dit is alleen voor wie de sterkte van dit monster wil zien (bv. kleurtint of kamer-UI).
var floor_nr := 0
var group: Array = []
var size := Vector2i.ONE
## Linkerboven-tile waar hij staat (tijdens een stap: waar hij vandaan komt).
var tile := Vector2i.ZERO
## Tile waar hij heen loopt (= tile als hij stilstaat).
var target_tile := Vector2i.ZERO
var facing := Vector2i.DOWN
var is_moving := false
## true = er was geen plaatje in assets/map_monsters/ (verkleind gevechtsplaatje).
var placeholder := false
var directional := true
var sprite: Sprite2D
var shape: CollisionShape2D
var steps := 0                 # aantal gezette stappen (autotest)
var rng := RandomNumberGenerator.new()
var _pause := 0.0
var _anim_t := 0.0
var _anim_col := 0
var _fps := WALK_FPS
## v0.16 KERNKRACHT-STUN: zoveel stappen van de speler nog verlamd (0 = normaal). Verlamd = niet
## lopen, niet animeren en geen gevecht bij aanraken (de kamer telt af per stap van de speler).
## Niet in de save: na laden staan alle monsters weer gewoon (de kamer wordt opnieuw gebouwd).
var stun_steps := 0
const STUN_TINT := Color(0.72, 0.5, 1.0)
var _stun_t := 0.0
var _stun_fx: Node2D


func setup(p_room: Node, d: Dictionary, rng_seed: int) -> void:
	room = p_room
	data = d
	monster_id = str(d.get("id", d.get("enemy", "monster")))
	name = "Monster_" + monster_id
	enemy_id = str(d.get("enemy", ""))
	# v0.21: standaard uit game_data (Mimic: "moves": false, "disguised": true); de kamerdata wint.
	var ed: Dictionary = GameData.ENEMIES.get(enemy_id, {})
	moves = bool(d.get("moves", ed.get("moves", true)))
	disguised = bool(d.get("disguised", ed.get("disguised", false)))
	boss = bool(d.get("boss", false))
	floor_nr = int(d.get("floor", GameState.dungeon100_floor))
	group = (d.get("group", [enemy_id]) as Array).duplicate()
	var sz: Array = d.get("size", [1, 1])
	size = Vector2i(int(sz[0]), int(sz[1]))
	_fps = float(d.get("fps", WALK_FPS))
	rng.seed = rng_seed
	_pause = rng.randf_range(PAUSE.x, PAUSE.y)
	var t: Array = d.get("tile", [0, 0])
	place_at(Vector2i(int(t[0]), int(t[1])), Vector2i.DOWN)
	# botsing: hele blok (min 2 px, zoals speler/NPC's 14x14)
	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size * 16) - Vector2(2, 2)
	shape.shape = rect
	shape.position = Vector2(0, -(size.y - 1) * 8.0)
	add_child(shape)
	_make_sprite(d)


func _make_sprite(d: Dictionary) -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var fr: Array = d.get("frame", [16, 16])
	var fw := int(fr[0])
	var fh := int(fr[1])
	var path := SPRITE_DIR + str(d.get("sprite", enemy_id)) + ".png"
	var bottom := 8.0 + float(d.get("y_offset", 0))     # onderkant van het blok t.o.v. de node
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		sprite.texture = tex
		sprite.hframes = maxi(1, int(tex.get_width() / fw))
		sprite.vframes = maxi(1, int(tex.get_height() / fh))
		directional = sprite.vframes >= 4
		sprite.position = Vector2(0, bottom - fh / 2.0)
	else:
		# PLACEHOLDER: gevechtsplaatje verkleind tot ~14 px, magenta hoekjes (_draw)
		placeholder = true
		directional = false
		var GD := preload("res://scripts/data/game_data.gd")
		var bp := GD.enemy_sprite(_enemy_base())   # v0.19: ook als de gevechts-art nog ontbreekt
		if bp != "" and ResourceLoader.exists(bp):
			var tex: Texture2D = load(bp)
			sprite.texture = tex
			var k := 14.0 * float(maxi(size.x, size.y)) / maxf(tex.get_width(), tex.get_height())
			sprite.scale = Vector2(k, k)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.position = Vector2(0, bottom - tex.get_height() * k / 2.0)
		queue_redraw()
	_update_frame()


func _draw() -> void:
	if not placeholder:
		return
	var h := Vector2(size * 16) / 2.0
	var c := Vector2(0, -(size.y - 1) * 8.0)
	var r := Rect2(c - h, h * 2.0)
	for p in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 3), r.end - Vector2(3, 3)]:
		draw_rect(Rect2(p, Vector2(3, 3)), PLACEHOLDER_COLOR, false, 1.0)


## Pixelpositie van de node voor een tile (midden van het blok, onderste tilerij: voor y-sort).
func tile_to_px(t: Vector2i) -> Vector2:
	return Vector2(t.x * 16 + size.x * 8.0, t.y * 16 + (size.y - 1) * 16 + 8.0)


func place_at(t: Vector2i, dir: Vector2i) -> void:
	tile = t
	target_tile = t
	is_moving = false
	facing = dir
	position = tile_to_px(t)
	_update_frame()


## Staat (een deel van) dit monster op deze tile, nu of na zijn huidige stap?
func covers(t: Vector2i) -> bool:
	return Rect2i(tile, size).has_point(t) or Rect2i(target_tile, size).has_point(t)


## Raakt het monster de speler (pixelposities, voor als ze tegelijk naar dezelfde tile lopen)?
func touches(p: Vector2) -> bool:
	var c := position + Vector2(0, -(size.y - 1) * 8.0)
	var h := Vector2(size * 8) + Vector2(4, 4)
	return absf(p.x - c.x) < h.x and absf(p.y - c.y) < h.y


## true = SomArena stuurt de beweging via sim_move() op de vaste 60 Hz-stap (Action-gevecht, stap 3b).
## _process tekent dan alleen (loop-/verlamd-animatie).
var sim_driven := false


func _process(delta: float) -> void:
	if room == null or not room.monsters_active():
		return
	if stun_steps > 0:
		_stun_look(delta)
	else:
		_animate(delta)
	if not sim_driven:
		sim_move(delta)


## Beweging: naar de doeltegel schuiven en (zonder doel) rondzwerven. Per frame, of per vaste stap (sim_driven).
func sim_move(delta: float) -> void:
	if room == null or not room.monsters_active():
		return
	if is_moving:
		var to := tile_to_px(target_tile)
		position = position.move_toward(to, WALK_SPEED * delta)
		if position == to:
			tile = target_tile
			is_moving = false
			steps += 1
			_pause = rng.randf_range(PAUSE.x, PAUSE.y)
		return
	if not moves or stun_steps > 0:
		return
	_pause -= delta
	if _pause > 0.0:
		return
	try_step(DIRS[rng.randi() % DIRS.size()])


## Eén stap proberen (ook door de autotest gebruikt). Geeft "free", "player", "blocked" of "wall".
func try_step(dir: Vector2i) -> String:
	facing = dir
	_update_frame()
	var to := tile + dir
	var r: String = room.monster_can_enter(self, to)
	match r:
		"free":
			target_tile = to
			is_moving = true
		"player":
			room.monster_touch(self)      # hij loopt tegen de speler aan
		_:
			_pause = rng.randf_range(0.2, 0.6)
	return r


func _animate(delta: float) -> void:
	if _fps <= 0.0:
		return
	_anim_t += delta
	if _anim_t >= 1.0 / _fps:
		_anim_t -= 1.0 / _fps
		_anim_col = (_anim_col + 1) % maxi(1, sprite.hframes if sprite else 1)
		_update_frame()


func _update_frame() -> void:
	if sprite == null or sprite.texture == null or placeholder:
		if sprite and placeholder:
			sprite.flip_h = facing == Vector2i.RIGHT
		return
	var col := _anim_col % sprite.hframes
	var row := int(DIR_ROW.get(facing, 0)) if directional else 0
	row = mini(row, sprite.vframes - 1)
	sprite.frame = row * sprite.hframes + col


## De speler loopt ertegen (player.gd _try_bump) of drukt A ervoor (player.gd _try_interact).
## TODO.md "push monster when stunned": loopt de speler tegen een VERLAMD monster aan, dan duwt hij
## het (en een eventuele keten erachter) 1 tegel weg; zie DungeonRoom.push_monster().
func bump(_by: Node) -> void:
	if room == null:
		return
	if is_stunned() and room.has_method("push_monster") and _by != null and "facing" in _by:
		room.push_monster(self, _by.facing)
		return
	room.monster_touch(self)


func interact(_by: Node) -> void:
	if room:
		room.monster_touch(self)


## Task #4: de vijand-stats van dit monster op zijn verdieping (zonder verdieping: de gewone data).
func _enemy_base() -> Dictionary:
	var base: Dictionary = GameData.ENEMIES.get(enemy_id, {})
	if not base.is_empty():
		return base
	return BerggrotData.enemy(enemy_id)


func scaled_stats() -> Dictionary:
	var base := _enemy_base()
	if base.is_empty():
		return {}
	return Dungeon100Scaling.battle_enemy(base, floor_nr, boss)


## Voor de save/terugkeer na een gevecht. v0.16: + "stun" (blijft staan na een ander gevecht).
func get_state() -> Dictionary:
	return {"tile": [tile.x, tile.y], "facing": [facing.x, facing.y], "stun": stun_steps}


# ---------------------------------------------------------------- v0.16 Kernkracht-stun
func is_stunned() -> bool:
	return stun_steps > 0


## Verlam voor n stappen van de speler (een baas nooit: daar komt de vuurbal niet eens aan toe).
func stun(n: int) -> void:
	if boss or disguised:
		return
	stun_steps = maxi(stun_steps, n)
	if _stun_fx == null:
		_stun_fx = Node2D.new()
		_stun_fx.name = "Verlamd"
		_stun_fx.position = Vector2(0, -(size.y - 1) * 8.0 - 10.0)
		_stun_fx.z_index = 5
		_stun_fx.draw.connect(_draw_stun_fx)
		add_child(_stun_fx)
	_stun_t = 0.0


## Eén stap van de speler gezet (DungeonRoom). Bij 0: weer normaal.
func step_tick() -> void:
	if stun_steps <= 0:
		return
	stun_steps -= 1
	if stun_steps <= 0:
		_unstun()


func _unstun() -> void:
	stun_steps = 0
	if sprite:
		sprite.modulate = Color.WHITE
	if _stun_fx:
		_stun_fx.queue_free()
		_stun_fx = null
	_pause = rng.randf_range(PAUSE.x, PAUSE.y)


## Paars pulseren + drie paarse sterretjes die boven zijn kop rondjes draaien.
func _stun_look(delta: float) -> void:
	_stun_t += delta
	if sprite and not disguised:
		sprite.modulate = Color.WHITE.lerp(STUN_TINT, 0.55 + 0.25 * sin(_stun_t * 7.0))
	if _stun_fx:
		_stun_fx.queue_redraw()


func _draw_stun_fx() -> void:
	for i in 3:
		var a := _stun_t * 4.0 + TAU * i / 3.0
		var p := Vector2(cos(a) * 6.0, sin(a) * 2.0).round()
		_stun_fx.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 0.6, 1.0))
		_stun_fx.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 0.95, 1))
