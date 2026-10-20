class_name SomArena
extends Node
## SoM-PROEF: realtime gevecht (Secret of Mana-stijl) in één DungeonRoom. Wordt door
## dungeon_room.gd aangemaakt als SomData.room_enabled(...) waar is; anders bestaat hij niet en
## loopt alles turn-based zoals altijd. Bazen ("boss": true) doen hier NIET aan mee: die starten
## gewoon het bestaande turn-based gevecht (DungeonRoom.start_monster_battle).
##
## Speler: A (interact) = slag. Wapenmeter vult in SomData.CHARGE_TIME; slaan onder 100% doet minder
## schade (SomData.CHARGE_MIN_MULT .. 1.0). Ring-knop (of Tab) = pauze-ringmenu (items/spreuken uit de
## bestaande data); de keuze wordt na het sluiten in realtime uitgevoerd.
## Schade: dezelfde formule als battle.gd _physical_damage (atk*mult - def/2, +/-15%, min 1).
## Buit: EXP/goud/drops gaan in GameState.party/inventory/gold (zoals een gewonnen gevecht).
## Visuals (slag-boog, "!", balkjes, cijfers) zijn PLACEHOLDERS (getekend in code, magenta = placeholder).

signal enemy_hit(monster: Node, damage: int)
signal enemy_defeated(monster: Node, exp_gain: int, gold_gain: int, drops: Array)
signal player_hit(damage: int)
signal player_defeated
signal ring_opened
signal ring_closed
signal action_resolved(text: String)

const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const SomHud := preload("res://scripts/som/som_hud.gd")
const SomRing := preload("res://scripts/som/som_ring.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const RING_ACTION := "som_ring"
const PLACEHOLDER_COLOR := Color("ff1ee6")

var room: Node
var player: CharacterBody2D
## Wapenmeter 0..1 (1 = 100%).
var charge := 1.0
## MapMonster -> {"hp", "max_hp", "atk", "def", "exp", "gold", "drops", "data", "cd", "tele", "chase", "flash", "kb"}
var enemies := {}
var iframes := 0.0
var down := false
var hud: SomHud
var ring: SomRing
var gauge: Node2D
## Keuze uit het ringmenu die na het sluiten "landt": {"kind": "item"/"spell", "id", "caster"}.
var queued := {}
var _queue_t := 0.0
## Voor de autotest: laatste schade aan een vijand en aan de speler, en laatste melding.
var last_enemy_damage := 0
var last_player_damage := 0
var last_text := ""
var attacks := 0


func setup(p_room: Node) -> void:
	room = p_room
	player = room.player
	name = "SomArena"
	_ensure_action()
	for m in room.monsters:
		register(m)
	hud = SomHud.new()
	hud.arena = self
	add_child(hud)
	ring = SomRing.new()
	ring.arena = self
	add_child(ring)
	gauge = SomFx.Gauge.new()
	gauge.arena = self
	room.get_node("Objects").add_child(gauge)


static func _ensure_action() -> void:
	if InputMap.has_action(RING_ACTION):
		return
	InputMap.add_action(RING_ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	InputMap.action_add_event(RING_ACTION, ev)


## Bestaande vijand-data (game_data.gd / berggrot_data.gd) met hetzelfde kamerniveau als het gevecht.
func enemy_stats(m: Node) -> Dictionary:
	var id: String = m.enemy_id
	var base: Dictionary = GameData.ENEMIES.get(id, {})
	if base.is_empty():
		base = BerggrotData.enemy(id)
	var d := base.duplicate(true)
	var t: int = room.tier()
	if t > 0 and not bool(d.get("unique", false)) and d.has("max_hp"):
		var in_archief: bool = DungeonRooms.ROOMS.has(room.room_id)
		d = GameData.apply_archief_tier(d, t) if in_archief else GameData.apply_tier(d, t)
	return d


func register(m: Node) -> void:
	if m == null or m.boss or enemies.has(m):
		return
	var d := enemy_stats(m)
	if d.is_empty():
		return
	m.moves = false      # zijn eigen willekeurige wandeling uit; de AI hieronder stuurt
	enemies[m] = {"hp": int(d.get("max_hp", 1)), "max_hp": int(d.get("max_hp", 1)), "atk": int(d.get("atk", 1)),
			"def": int(d.get("def", 0)), "exp": int(d.get("exp", 0)), "gold": int(d.get("gold", 0)),
			"drops": d.get("drops", []), "data": d, "cd": 0.6, "tele": 0.0, "chase": randf() * SomData.CHASE_INTERVAL,
			"flash": 0.0}


func hero() -> Dictionary:
	return GameState.party[0] if not GameState.party.is_empty() else {}


func active() -> bool:
	return not down and room != null and room.monsters_active() and not ring.is_open


func _process(delta: float) -> void:
	if room == null or GameState.party.is_empty():
		return
	if Input.is_action_just_pressed(RING_ACTION) and active():
		open_ring()
		return
	if not active():
		return
	charge = minf(1.0, charge + delta / SomData.CHARGE_TIME)
	iframes = maxf(0.0, iframes - delta)
	if Input.is_action_just_pressed("interact") and Engine.get_process_frames() != ring.closed_frame:
		attack()
	if not queued.is_empty():
		_queue_t -= delta
		if _queue_t <= 0.0:
			var q := queued
			queued = {}
			resolve(q)
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, delta)
		else:
			enemies.erase(m)


# ---------------------------------------------------------------- speler
## Schademultiplier van de wapenmeter (1.0 bij 100%).
static func charge_mult(c: float) -> float:
	return 1.0 if c >= 1.0 else lerpf(SomData.CHARGE_MIN_MULT, 1.0, clampf(c, 0.0, 1.0))


## battle.gd _physical_damage zonder buffs/verdediging.
static func physical_damage(atk: float, def: float, mult: float) -> int:
	var base := atk * mult - def / 2.0
	return maxi(1, roundi(base * randf_range(0.85, 1.15)))


## Eén slag. Geeft het aantal geraakte vijanden.
func attack() -> int:
	attacks += 1
	var mult := charge_mult(charge)
	charge = 0.0
	var f: Vector2 = Vector2(player.facing)
	var point: Vector2 = player.position + f * SomData.ATTACK_OFFSET
	SomFx.slash(room.get_node("Objects"), point, f)
	var n := 0
	var atk := float(GameState.effective_stat(hero(), "atk"))
	for m in enemies.keys():
		if not is_instance_valid(m):
			continue
		if _center(m).distance_to(point) <= SomData.ATTACK_REACH + 8.0 * maxf(m.size.x, m.size.y):
			var e: Dictionary = enemies[m]
			damage_enemy(m, physical_damage(atk, float(e["def"]), mult), player.facing)
			n += 1
	return n


func _center(m: Node) -> Vector2:
	return m.position + Vector2(0, -(m.size.y - 1) * 8.0)


func damage_enemy(m: Node, dmg: int, dir: Vector2i) -> void:
	if not enemies.has(m):
		return
	var e: Dictionary = enemies[m]
	e["hp"] = int(e["hp"]) - dmg
	e["flash"] = SomData.HIT_FLASH
	e["tele"] = 0.0          # geraakt = telegraaf afgebroken
	last_enemy_damage = dmg
	SomFx.number(room.get_node("Objects"), _center(m) + Vector2(0, -10), str(dmg), Color(1, 1, 1))
	enemy_hit.emit(m, dmg)
	if int(e["hp"]) <= 0:
		_defeat_enemy(m)
		return
	_knockback(m, dir)


func _knockback(m: Node, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO or m.is_moving:
		return
	var from: Vector2 = m.position
	if room.monster_can_enter(m, m.tile + dir) == "free":
		m.place_at(m.tile + dir, m.facing)
	var to: Vector2 = m.position
	m.position = from
	var tw := m.create_tween()
	tw.tween_property(m, "position", to, SomData.KNOCKBACK_TIME)
	if to == from:       # tegen een muur: alleen een tikje
		m.position = from + Vector2(dir) * 3.0
		tw.kill()
		m.create_tween().tween_property(m, "position", from, SomData.KNOCKBACK_TIME)


func _defeat_enemy(m: Node) -> void:
	var e: Dictionary = enemies[m]
	enemies.erase(m)
	GameState.mark_defeated(m.enemy_id)
	var gained_exp := int(e["exp"])
	var gained_gold := int(e["gold"])
	GameState.gold += gained_gold
	var lines: Array[String] = [SomData.TXT_EXP % [gained_exp, gained_gold]]
	for h in GameState.alive_heroes():
		var msgs := GameState.give_exp(h, gained_exp)
		lines.append_array(msgs)
	var got: Array = []
	for d in e["drops"]:
		if typeof(d) == TYPE_DICTIONARY and GameData.ITEMS.has(str(d.get("item", ""))) and randf() < float(d.get("chance", 0.0)):
			var id := str(d["item"])
			GameState.inventory[id] = GameState.item_count(id) + 1
			got.append(id)
			lines.append(SomData.TXT_GOT % PartyActions.item_name(id))
	if not GameState.defeated_map_monsters.has(room.room_id):
		GameState.defeated_map_monsters[room.room_id] = {}
	GameState.defeated_map_monsters[room.room_id][m.monster_id] = true
	room.monsters.erase(m)
	_say("\n".join(lines))
	enemy_defeated.emit(m, gained_exp, gained_gold, got)
	m.set_process(false)
	m.collision_layer = 0
	var tw := m.create_tween()
	tw.tween_property(m, "modulate:a", 0.0, 0.3)
	tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- vijanden
func _enemy_ai(m: Node, delta: float) -> void:
	var e: Dictionary = enemies[m]
	if float(e["flash"]) > 0.0:
		e["flash"] = float(e["flash"]) - delta
	if m.is_stunned():
		_tint(m, e)
		return
	var dist: float = _center(m).distance_to(player.position)
	if float(e["tele"]) > 0.0:
		e["tele"] = float(e["tele"]) - delta
		if float(e["tele"]) <= 0.0:
			e["cd"] = SomData.ATTACK_COOLDOWN
			if dist <= SomData.ENEMY_REACH + 8.0 * (maxf(m.size.x, m.size.y) - 1.0):
				hit_player(int(e["atk"]), _center(m))
	elif float(e["cd"]) > 0.0:
		e["cd"] = float(e["cd"]) - delta
	elif dist <= SomData.ENEMY_REACH:
		e["tele"] = SomData.TELEGRAPH
		SomFx.number(room.get_node("Objects"), _center(m) + Vector2(0, -14), "!", Color(1, 0.3, 0.3), SomData.TELEGRAPH)
	if dist > SomData.ENEMY_REACH - 6.0 and float(e["tele"]) <= 0.0:
		e["chase"] = float(e["chase"]) - delta
		if float(e["chase"]) <= 0.0 and not m.is_moving and dist < SomData.CHASE_RANGE * 16.0:
			e["chase"] = SomData.CHASE_INTERVAL
			_step_toward(m)
	_tint(m, e)


func _step_toward(m: Node) -> void:
	var d: Vector2 = player.position - _center(m)
	var a := Vector2i(signi(roundi(d.x)), 0)
	var b := Vector2i(0, signi(roundi(d.y)))
	if absf(d.y) > absf(d.x):
		var t := a
		a = b
		b = t
	for dir in [a, b]:
		if dir != Vector2i.ZERO and room.monster_can_enter(m, m.tile + dir) == "free":
			m.try_step(dir)
			return
	if a != Vector2i.ZERO:
		m.facing = a
		m._update_frame()


func _tint(m: Node, e: Dictionary) -> void:
	if m.sprite == null or m.is_stunned():
		return
	if float(e["flash"]) > 0.0:
		m.sprite.modulate = Color(3, 3, 3)       # hit flash (wit)
	elif float(e["tele"]) > 0.0:
		var on := fmod(float(e["tele"]), 0.16) < 0.08
		m.sprite.modulate = Color(1.8, 0.5, 0.5) if on else Color.WHITE     # telegraaf: rood knipperen
	else:
		m.sprite.modulate = Color.WHITE


func hit_player(atk: int, from: Vector2) -> void:
	if iframes > 0.0 or down:
		return
	var h := hero()
	var dmg := physical_damage(float(atk), float(GameState.effective_stat(h, "def")), 1.0)
	h["hp"] = maxi(0, int(h["hp"]) - dmg)
	last_player_damage = dmg
	iframes = SomData.PLAYER_IFRAMES
	room.start_invuln(SomData.PLAYER_IFRAMES)
	SomFx.number(room.get_node("Objects"), player.position + Vector2(0, -14), str(dmg), Color(1, 0.4, 0.4))
	player_hit.emit(dmg)
	if int(h["hp"]) <= 0:
		_player_down()


## Dax valt: zelfde afloop als een verloren gevecht (checkpoint/respawn via GameState.end_battle).
func _player_down() -> void:
	down = true
	player.input_locked = true
	_say(SomData.TXT_FALLEN % str(hero().get("name", "Dax")))
	player_defeated.emit()
	await get_tree().create_timer(1.2).timeout
	GameState.in_battle = true
	GameState.pending_boss = false
	GameState.has_return_point = true
	GameState.return_map = GameState.current_map
	GameState.end_battle("lose")


# ---------------------------------------------------------------- ringmenu
func open_ring() -> void:
	if ring.is_open:
		return
	ring.open()
	ring_opened.emit()


## Door SomRing aangeroepen bij sluiten (keuze = {} als er niets gekozen is).
func on_ring_closed(choice: Dictionary) -> void:
	ring_closed.emit()
	if not choice.is_empty():
		queued = choice
		_queue_t = SomData.RING_CAST_DELAY


## Voert een keuze uit het ringmenu uit. Geeft de melding terug.
func resolve(q: Dictionary) -> String:
	var text := ""
	if str(q.get("kind", "")) == "item":
		var r: Dictionary = PartyActions.use_item(GameState.inventory, str(q["id"]), hero())
		text = str(r.get("text", ""))
		if int(r.get("hp", 0)) > 0:
			SomFx.number(room.get_node("Objects"), player.position + Vector2(0, -14), "+%d" % int(r["hp"]), Color(0.4, 1, 0.5))
	else:
		text = _cast(str(q.get("id", "")), str(q.get("caster", "")))
	_say(text)
	action_resolved.emit(text)
	return text


func _cast(spell_id: String, caster_id: String) -> String:
	var sp: Dictionary = GameData.SPELLS.get(spell_id, {})
	var caster: Dictionary = GameState.member(caster_id) if GameState.has_member(caster_id) else hero()
	if sp.is_empty():
		return ""
	var cost := int(sp.get("mp", 0))
	if int(caster.get("mp", 0)) < cost:
		return SomData.TXT_NO_MP
	var kind := str(sp.get("type", ""))
	var lvl := int(caster.get("level", 1))
	var cid := str(caster.get("id", ""))
	if kind == "damage":
		var targets: Array = []
		var best: Node = null
		var best_d := 1e9
		for m in enemies.keys():
			if not is_instance_valid(m):
				continue
			var dd: float = _center(m).distance_to(player.position)
			if dd > 10.0 * 16.0:
				continue
			if str(sp.get("target", "")) == "all_enemies":
				targets.append(m)
			elif dd < best_d:
				best_d = dd
				best = m
		if best:
			targets.append(best)
		if targets.is_empty():
			return SomData.TXT_NO_TARGET
		caster["mp"] = int(caster["mp"]) - cost
		for m in targets:
			var amt := SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, cid, {"s": enemies[m]["data"]})
			damage_enemy(m, maxi(1, roundi(amt * randf_range(0.9, 1.1))), Vector2i.ZERO)
		return "%s casts %s!" % [caster.get("name", ""), sp.get("name", spell_id)]
	if kind == "heal":
		caster["mp"] = int(caster["mp"]) - cost
		var amt := roundi(SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, cid, {}))
		var got := PartyActions.restore(hero(), amt, 0)
		SomFx.number(room.get_node("Objects"), player.position + Vector2(0, -14), "+%d" % got.x, Color(0.4, 1, 0.5))
		return "%s casts %s! %s recovers %d HP." % [caster.get("name", ""), sp.get("name", spell_id), hero().get("name", ""), got.x]
	return SomData.TXT_MISS_BUFF % str(sp.get("name", spell_id))


## Ringmenu-inhoud: items die in het veld werken, en spreuken van levende partyleden.
func ring_entries() -> Dictionary:
	var items: Array = []
	for id in GameState.inventory.keys():
		var sid := str(id)
		if GameState.item_count(sid) > 0 and GameData.ITEMS.has(sid) and PartyActions.item_block_reason(sid) == "" \
				and not bool(GameData.ITEMS[sid].get("warp", false)):
			items.append({"kind": "item", "id": sid, "label": "%s x%d" % [PartyActions.item_name(sid), GameState.item_count(sid)]})
	var skills: Array = []
	for h in GameState.alive_heroes():
		for s in h.get("spells", []):
			var sp: Dictionary = GameData.SPELLS.get(str(s), {})
			if sp.is_empty():
				continue
			skills.append({"kind": "spell", "id": str(s), "caster": str(h.get("id", "")),
					"label": "%s %d" % [str(sp.get("name", s)), int(sp.get("mp", 0))]})
	return {"items": items, "skills": skills}


func _say(text: String) -> void:
	last_text = text
	if hud:
		hud.toast(text)
