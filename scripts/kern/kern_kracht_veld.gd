extends Node
## v0.16 KERNKRACHT IN HET VELD (RPG CODE, zie HANDOFF_KERNKRACHT.md).
## map.gd hangt deze node in elke kaart ("KernKracht"). Werkt pas als de party de
## wereldvaardigheid "kernvuur" heeft (Golemkern, scripts/data/kern_data.gd).
##   Knop: KERN op het touchscherm (verschijnt alleen als hij vrijgespeeld is, boven de A-knop)
##         of toets K (actie "kern", wordt hier aangemaakt als project.godot hem niet kent).
##   Vuurbal: vanaf de borst van de held, RANGE (3) tegels recht vooruit in de kijkrichting.
##   Botsing: ALLES wat massief is houdt hem tegen (muur/massieve tegel, kast, duwkast, kist, deur,
##            poort, NPC, hendel, savepunt, meubel, leesplek, monster, rand van de kaart); hij stopt
##            bij het EERSTE obstakel met een inslag en gaat nooit ergens doorheen.
##   Monster: een zichtbaar map-monster (dungeonkamer) staat STUN_STEPS (10) stappen van de speler
##            stil en start geen gevecht; een BAAS krijgt niets (alleen de inslag).
##   Spammen kan niet: tijdens het schot staat de speler op slot (~0,5 s) en daarna COOLDOWN s.

const KernVuurbal := preload("res://scripts/kern/kern_vuurbal.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const ACTION := "kern"
const ACTION_KEY := KEY_K
const RANGE := 3                     # tegels
const STUN_STEPS := 10               # stappen van de speler
const SPEED := 200.0                 # px/s (3 tegels in ~0,24 s)
const WIND_UP := 0.1                 # s: held licht paars op, dan de bal
const COOLDOWN := 0.6                # s na afloop (bovenop de animatie-lock)
const CHEST := Vector2(0, -4)        # borst van de held t.o.v. zijn node (tile-midden)
const FX_SCALE := 1.0

var map: Node = null
var cooldown_left := 0.0
var busy := false
## voor de tests: uitkomst van het laatste schot
## {"tiles": [pad], "end": Vector2i, "hit": Vector2i of null, "kind": "", "node": Node, "effect": "stun"/"baas"/"geen"}
var last_result := {}
var shots_fired := 0
var last_fireball: Node2D
var last_impact: Node2D


func _ready() -> void:
	name = "KernKracht"
	process_mode = Node.PROCESS_MODE_INHERIT
	map = get_parent()
	ensure_action()


## Actie "kern" (toets K) als hij nog niet bestaat; de touch-knop drukt dezelfde actie in.
static func ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = ACTION_KEY
	InputMap.action_add_event(ACTION, ev)


static func unlocked() -> bool:
	return GameState.has_world_ability(KernData.FIELD_FIREBALL_ABILITY)


func _process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	_update_button()
	if Input.is_action_just_pressed(ACTION) and can_fire() == "":
		fire()


## "" = schieten mag; anders de reden ("dicht" = geen Golemkern, "bezig", "afkoelen", "niet nu").
func can_fire() -> String:
	if not unlocked():
		return "dicht"
	if busy:
		return "bezig"
	if cooldown_left > 0.0:
		return "afkoelen"
	var p = map.get("player") if map else null
	if p == null or not is_instance_valid(p) or p.is_moving or p.input_locked or Dialog.is_open \
			or GameState.in_battle or GameState.changing_map or Story.running \
			or (map.has_method("menu_open") and map.menu_open()):
		return "niet nu"
	return ""


## KERN-knop alleen tonen als hij vrijgespeeld is en er geen tekst/menu/cutscene is.
func _update_button() -> void:
	var touch: Node = map.get_node_or_null("TouchControls/Control") if map else null
	if touch == null or not ("show_kern" in touch):
		return
	var want: bool = unlocked() and not Dialog.is_open and not Story.running \
			and not (map.has_method("menu_open") and map.menu_open())
	if touch.show_kern != want:
		touch.show_kern = want


# ---------------------------------------------------------------- baan (zonder beeld)
## Volg de baan vanaf 'from' in richting 'dir': max RANGE tegels, stopt bij het eerste obstakel.
func trace(from: Vector2i, dir: Vector2i) -> Dictionary:
	var out := {"tiles": [], "end": from + dir * RANGE, "hit": null, "kind": "", "node": null}
	for i in range(1, RANGE + 1):
		var t := from + dir * i
		var b: Dictionary = blocker_at(t)
		if not b.is_empty():
			out["hit"] = t
			out["end"] = t
			out["kind"] = b["kind"]
			out["node"] = b.get("node")
			return out
		out["tiles"].append(t)
	return out


## Wat staat er op tile t dat de vuurbal tegenhoudt? {} = niets; anders {"kind", "node"}.
func blocker_at(t: Vector2i) -> Dictionary:
	var p: Node2D = map.player
	# 1) zichtbare map-monsters (ook halverwege een stap)
	if "monsters" in map:
		for m in map.monsters:
			if is_instance_valid(m) and m.covers(t):
				return {"kind": "monster", "node": m}
	# 2) alles met een botsing (tegels, muren, NPC's, kisten, kasten, deuren, poorten, hendels, ...)
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(t) * 16 + Vector2(8, 8)
	q.collide_with_bodies = true
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var area_hit: Node = null
	for hit in p.get_world_2d().direct_space_state.intersect_point(q, 16):
		var c: Object = hit["collider"]
		if c == null or c == p:
			continue
		if c is Area2D:
			# leesplekken e.d. (iets om mee te praten): ook een object, de bal gaat er niet door
			if c.has_method("interact") or c.has_method("bump"):
				area_hit = c
			continue
		return {"kind": kind_of(c), "node": c}
	# 3) puzzelkamer: het model weet ook wat massief is (muur, kast, hendel, steen, dichte poort)
	if "logic" in map and map.logic != null and map.logic.is_solid(t):
		var o: String = map.logic.block_at(t)
		if o == "":
			o = map.logic.object_at(t)
		return {"kind": ("muur" if o == "" else str(map.logic.types.get(o, "object"))), "node": map.nodes.get(o)}
	if area_hit != null:
		return {"kind": kind_of(area_hit), "node": area_hit}
	# 4) buiten de kaart
	var g: TileMapLayer = map.get("ground")
	if g != null and g.get_cell_source_id(t) == -1:
		return {"kind": "rand", "node": null}
	return {}


## Soort obstakel (voor de tests en de handoff): bestandsnaam van het script, of "muur".
static func kind_of(n: Object) -> String:
	if n is TileMapLayer:
		return "muur"
	var sc: Script = n.get_script() if n else null
	if sc == null or sc.resource_path == "":
		return "muur"         # losse botsing (Rand_, Muren, ...)
	var f := sc.resource_path.get_file().get_basename()
	match f:
		"map_monster":
			return "monster"
		"push_block":
			return "block"
		"treasure_chest", "dungeon_chest":
			return "chest"
		"secret_door":
			return "secret"
		"book_point":
			return "boek"
		"dungeon_prop":
			return "meubel"
		"dungeon_sign":
			return "leesplek"
		"reset_stone":
			return "reset"
		"book_switch":
			return "book"
	return f            # npc, door, gate, lever, sign, story_object, ...


# ---------------------------------------------------------------- schieten
func fire() -> void:
	if can_fire() != "":
		return
	busy = true
	shots_fired += 1
	var p: CharacterBody2D = map.player
	var dir: Vector2i = p.facing
	var from_tile: Vector2i = p.get_tile()
	var r: Dictionary = trace(from_tile, dir)
	r["effect"] = "geen"
	last_result = r
	p.input_locked = true
	# held licht paars op (hand vooruit = gewoon zijn kijkrichting)
	var tw := p.create_tween()
	tw.tween_property(p.sprite, "modulate", Color(1.35, 0.9, 1.9), WIND_UP)
	tw.tween_property(p.sprite, "modulate", Color.WHITE, 0.3)
	await get_tree().create_timer(WIND_UP).timeout
	if not _alive(p):
		return
	var start: Vector2 = p.position + CHEST + Vector2(dir) * 6.0
	var end: Vector2
	if r["hit"] == null:
		end = Vector2(r["end"]) * 16 + Vector2(8, 8) + CHEST            # 3 tegels: uitdoven in het midden
	elif r["kind"] == "monster" and is_instance_valid(r["node"]) and not r["node"].boss:
		# midden op het monster (monsters staan stil zolang de speler op slot staat, ook halverwege een stap)
		var m: Node2D = r["node"]
		end = m.position + Vector2(0, -(m.size.y - 1) * 8.0) + CHEST
	else:
		end = Vector2(r["hit"]) * 16 + Vector2(8, 8) + CHEST - Vector2(dir) * 7.0   # tegen de voorkant
	var vb: Node2D = KernVuurbal.new()
	vb.scale = Vector2.ONE * FX_SCALE
	map.get_node("Objects").add_child(vb)
	vb.z_index = 30
	last_fireball = vb
	await vb.fly(start, end, SPEED)
	if not _alive(p):
		return
	vb.queue_free()
	last_impact = KernVuurbal.impact(map.get_node("Objects"), end, FX_SCALE * (0.7 if r["hit"] == null else 1.0))
	last_impact.z_index = 31
	if r["kind"] == "monster" and is_instance_valid(r["node"]):
		var m: Node = r["node"]
		if m.boss:
			r["effect"] = "baas"          # baas: geen stun, geen effect
		elif m.has_method("stun"):
			m.stun(STUN_STEPS)
			r["effect"] = "stun"
	await get_tree().create_timer(KernVuurbal.impact_time()).timeout
	if not _alive(p):
		return
	if p.input_locked and not GameState.in_battle and not GameState.changing_map and not Story.running \
			and not Dialog.is_open:
		p.input_locked = false
	busy = false
	cooldown_left = COOLDOWN


func _alive(p: Node) -> bool:
	if is_inside_tree() and is_instance_valid(p) and p.is_inside_tree():
		return true
	busy = false
	return false
