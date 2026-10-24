extends CharacterBody2D
## SoM-proef: AI-BONDGENOOT (Vesper/Seren) in Action. Volgt Dax in formatie, valt vijanden bij Dax aan
## met een eigen wapenmeter, houdt afstand bij weinig HP, gebruikt spreuken uit spells.gd met MP
## (eerst genezen: partylid < ALLY_HEAL_BELOW). KO = stil en grijs; opstaan via een item in de ring.
## Blokkeert Dax niet (eigen botsing alleen tegen muren/monsters). Teleporteert bij als hij vast zit of
## buiten beeld raakt. Alle getallen in som_data.gd. Wordt door SomArena aangestuurd (tick), dus de
## pauzering (ringmenu) bevriest hem vanzelf.

const SomData := preload("res://scripts/data/som_data.gd")
const SomMove := preload("res://scripts/som/som_move.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const DIR_ROW := {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}
const WALK_CYCLE := [1, 0, 2, 0]

var arena: Node
var hero_id := ""
var slot := 0
var facing := Vector2i.DOWN
var charge := 1.0
var sprite: Sprite2D
## "follow", "engage", "flee", "ko" (voor tests/debug)
var state := "follow"
var stuck_t := 0.0
var spell_cd := 1.0
var teleports := 0
var attacks := 0
var _walk := 0.0


func setup(p_arena: Node, id: String, p_slot: int) -> void:
	arena = p_arena
	slot = p_slot
	collision_layer = 0          # Dax (en monsters) lopen er gewoon langs
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 8)
	cs.shape = r
	cs.position = Vector2(0, 3)
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.name = "Sprite2D"
	add_child(sprite)
	set_hero(id)
	position = formation_point()


## Andere held in dit lichaam (bij wisselen van besturing).
func set_hero(id: String) -> void:
	SomFx.set_ko(self, arena.pose_tex(hero_id, "ko"), false)
	state = "follow"
	hero_id = id
	name = "Ally_" + id
	var tex: Texture2D = arena.sheet_for(id)
	if tex:
		sprite.texture = tex
		MapSprite.pas_toe(sprite, MapSprite.NIEUW)
	charge = 1.0
	stuck_t = 0.0
	_frame()


func member() -> Dictionary:
	return GameState.member(hero_id) if GameState.has_member(hero_id) else {}


func alive() -> bool:
	return int(member().get("hp", 0)) > 0


func body() -> Vector2:
	return position + Vector2(0, SomData.BODY_Y)


## Plek in de formatie achter Dax.
func formation_point() -> Vector2:
	var p: CharacterBody2D = arena.player
	var back := -Vector2(p.facing)
	var side := Vector2(-back.y, back.x)
	var f: Vector2 = SomData.FORMATION[slot % SomData.FORMATION.size()]
	return p.position + side * f.x + back * f.y


## Staat dit lichaam in een muur of buiten de kamer? Bij het binnenkomen starten de bondgenoten rond de
## standaardplek van de speler in de scène (nog vóór die op zijn spawnpunt staat): in sommige kamers
## (Mistpoel, Wortelpad, Wachtersgang, Bibliotheek) is dat massief.
func in_wall() -> bool:
	var room: Node = arena.room
	return room != null and room.has_method("is_wall") and room.is_wall(Vector2i((position / 16.0).floor()))


func tick(delta: float) -> void:
	if not alive():
		if state != "ko":
			var ko: Texture2D = arena.pose_tex(hero_id, "ko")
			SomFx.set_ko(self, ko, true)
			if ko == null:
				sprite.modulate = Color(0.45, 0.45, 0.5, 0.8)
		state = "ko"
		return
	if state == "ko":
		state = "follow"
		SomFx.set_ko(self, arena.pose_tex(hero_id, "ko"), false)
	sprite.modulate = Color.WHITE
	if in_wall():
		_teleport()
	charge = minf(1.0, charge + delta / SomData.CHARGE_TIME)
	spell_cd -= delta
	var m: Dictionary = member()
	if spell_cd <= 0.0:
		spell_cd = SomData.ALLY_SPELL_CD
		_think_spell()
	var target := formation_point()
	var enemy: Node = arena.nearest_enemy(arena.player.position, SomData.ALLY_ENGAGE_RANGE)
	var low := float(m["hp"]) / maxf(1.0, float(m["max_hp"])) < SomData.ALLY_LOW_HP
	if low and enemy:
		state = "flee"
		var away: Vector2 = (position - arena.center_of(enemy)).normalized()
		target = arena.center_of(enemy) + away * SomData.ALLY_FLEE_DIST
	elif enemy:
		state = "engage"
		var c: Vector2 = arena.center_of(enemy)
		var side := Vector2(signf(position.x - c.x), 0)
		if side == Vector2.ZERO:
			side = Vector2(1, 0)
		# Kael/Orion (lang bereik) houden afstand; de rest gaat er vlak naast staan
		var stand := maxf(14.0, SomData.attack_offset(hero_id))
		target = c + side * stand - Vector2(0, SomData.BODY_Y)
		if body().distance_to(c) <= SomData.attack_offset(hero_id) + SomData.attack_reach(hero_id) - 2.0 and charge >= 1.0:
			facing = SomMove.facing_for(c - body(), facing)
			charge = 0.0
			attacks += 1
			arena.ally_attack(self, enemy)
	else:
		state = "follow"
	_move_to(target, delta)


func _move_to(target: Vector2, delta: float) -> void:
	var p: Vector2 = arena.player.position
	if position.distance_to(p) > SomData.ALLY_TELEPORT_DIST:
		_teleport()
		return
	var d := target - position
	if d.length() <= SomData.ALLY_ARRIVE:
		velocity = Vector2.ZERO
		stuck_t = 0.0
		_walk = 0.0
		_frame()
		return
	var speed := SomData.ALLY_SPEED * clampf(d.length() / 24.0, 0.4, 1.0)
	velocity = d.normalized() * speed
	var before := position
	move_and_slide()
	var moved := position.distance_to(before)
	_walk += moved
	facing = SomMove.facing_for(d, facing)
	if moved < speed * delta * 0.25:
		stuck_t += delta
		if stuck_t >= SomData.ALLY_STUCK_TIME:
			_teleport()
	else:
		stuck_t = 0.0
	_frame()


func _teleport() -> void:
	teleports += 1
	stuck_t = 0.0
	position = arena.player.position
	velocity = Vector2.ZERO


func _think_spell() -> void:
	# Staat de besturing op deze held (lichaam niet gewisseld), dan is node_of(hero_id) de speler: de AI mag
	# daar geen cast-animatie (SomCastAnim/-Circle/-Fx) naast het loopframe leggen.
	if hero_id == arena.active_id:
		return
	var m: Dictionary = member()
	var spells: Array = m.get("spells", [])
	# 1) genezen: partylid (levend) onder ALLY_HEAL_BELOW
	var low: Dictionary = arena.lowest_member(SomData.ALLY_HEAL_BELOW)
	if not low.is_empty():
		for s in spells:
			var sp: Dictionary = GameData.SPELLS.get(str(s), {})
			if str(sp.get("type", "")) == "heal" and int(m["mp"]) >= int(sp.get("mp", 0)):
				arena.cast_spell(str(s), hero_id, low)
				return
	# 2) aanvallen met een spreuk
	if arena.rng.randf() > SomData.ALLY_DAMAGE_SPELL_CHANCE or arena.nearest_enemy(arena.player.position, SomData.ALLY_ENGAGE_RANGE) == null:
		return
	for s in spells:
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if str(sp.get("type", "")) == "damage" and int(m["mp"]) >= int(sp.get("mp", 0)):
			arena.cast_spell(str(s), hero_id, {})
			return


func _frame() -> void:
	if sprite == null or sprite.texture == null:
		return
	var col := 0
	if velocity.length() > 1.0:
		col = WALK_CYCLE[int(_walk / 8.0) % WALK_CYCLE.size()]
	MapSprite.zet_frame(sprite, DIR_ROW[facing], col)
