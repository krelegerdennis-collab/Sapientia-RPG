class_name SomArena
extends Node
## SoM-PROEF: realtime gevecht (Secret of Mana-stijl) in één DungeonRoom. Wordt door
## dungeon_room.gd aangemaakt als SomData.room_enabled(...) waar is; anders bestaat hij niet en
## loopt alles turn-based zoals altijd. Bazen ("boss": true) doen hier NIET aan mee: die starten
## gewoon het bestaande turn-based gevecht (DungeonRoom.start_monster_battle).
##
## Party: de held die je bestuurt zit in de speler-node (camera, deuren, praten); de anderen zijn
## AI-bondgenoten (som_ally.gd). SWITCH (knop/toets C) wisselt: het lichaam van de speler en dat van de
## bondgenoot ruilen van held (sprite + plek), de camera glijdt mee. KO -> automatisch naar de volgende;
## game over pas als iedereen KO is.
## Speler: analoge joystick/toetsen, A = slag met wapenmeter (SomData.CHARGE_TIME), Ring (Tab) = pauze.
## Schade: dezelfde formule als battle.gd _physical_damage (atk*mult - def/2, +/-15%, min 1).
## Buit: EXP/goud/drops gaan in GameState.party/inventory/gold (zoals een gewonnen gevecht).
## Visuals (slag-boog, "!", balkjes, cijfers) zijn PLACEHOLDERS (in code getekend).

signal enemy_hit(monster: Node, damage: int)
signal enemy_defeated(monster: Node, exp_gain: int, gold_gain: int, drops: Array)
signal player_hit(damage: int)
signal member_down(hero_id: String)
signal player_defeated
signal hero_switched(hero_id: String)
## Slag geland (bij art: aan het begin van frame SomData.ATTACK_HIT_FRAME), met het aantal treffers.
signal swing_landed(hero_id: String, hits: int)
## Spreuk komt vrij (cast6 frame 4, of meteen zonder sheet): schade/genezing is toegepast.
signal spell_released(spell_id: String, caster_id: String)
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
const SomMove := preload("res://scripts/som/som_move.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const RING_ACTION := "som_ring"
const SWITCH_ACTION := "som_switch"

var room: Node
var player: CharacterBody2D
## Held die nu bestuurd wordt (in de speler-node).
var active_id := "dennis"
## Wapenmeter van de bestuurde held 0..1 (1 = 100%).
var charge := 1.0
## MapMonster -> {"hp", "max_hp", "atk", "def", "exp", "gold", "drops", "data", "cd", "tele", "chase", "flash", "target"}
var enemies := {}
var allies: Array = []
## Onkwetsbaar-tijd per held-id.
var iframes := {}
var down := false
var hud: Node
var ring: Node
var gauge: Node2D
## Keuze uit het ringmenu die na het sluiten "landt": {"kind": "item"/"spell", "id", "caster"}.
var queued := {}
var _queue_t := 0.0
var touch: Control
## Autotest: vaste joystick-stand (ZERO = echte input).
var forced_joy := Vector2.ZERO
## Kaartsprites en aanvalsanimaties per held-id (geladen in setup; ontbreekt = placeholder).
var sheets := {}
var attack_texs := {}
## Voor de autotest: laatste schade, laatste melding, tellers.
var last_enemy_damage := 0
var last_player_damage := 0
var last_hit_id := ""
var last_attacker := ""
var last_text := ""
var attacks := 0
var switches := 0
## Autotest: bondgenoten even stilzetten (false = geen AI-tick).
var allies_enabled := true
## Resterende tijd tot de volgende B-spreuk (SomData.B_CAST_COOLDOWN).
var b_cast_cd := 0.0
## Zolang de slag-animatie loopt vult de meter niet (SomData.CHARGE_AFTER_ANIM).
var swing_lock := 0.0
## Laatste slag was vol (stagger: telegraaf afbreken + knockback alleen bij 100%).
var _full_swing := true
var b_casts := 0


func setup(p_room: Node) -> void:
	room = p_room
	player = room.player
	name = "SomArena"
	_ensure_actions()
	for id in SomData.SHEETS:
		var path := str(SomData.SHEETS[id])
		if ResourceLoader.exists(path):
			sheets[id] = load(path)
	for id in SomData.ATTACK_ANIMS:
		var sheet := str(SomData.ATTACK_ANIMS[id].get("sheet", ""))
		if sheet != "" and ResourceLoader.exists(sheet):
			attack_texs[id] = load(sheet)
	active_id = str(GameState.party[0].get("id", "dennis")) if not GameState.party.is_empty() else "dennis"
	for m in room.monsters:
		register(m)
	# Action: analoge beweging + joystick, 24x32-kaartsprite, soepele camera
	touch = room.get_node_or_null("TouchControls/Control") as Control
	if touch and "joystick_mode" in touch:
		touch.joystick_mode = true
	if touch and "analog_only" in touch:
		touch.analog_only = true      # alleen joy_raw; geen move_*-stappen (anders dubbele beweging)
	player.set_analog(analog_dir, SomData.MOVE_SPEED)
	_apply_player_sheet()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = SomData.CAMERA_SMOOTH
	var objects := room.get_node("Objects")
	var slot := 0
	for h in GameState.party:
		var id := str(h.get("id", ""))
		if id == active_id:
			continue
		var a: CharacterBody2D = SomAlly.new()
		objects.add_child(a)
		a.setup(self, id, slot)
		allies.append(a)
		slot += 1
	hud = SomHud.new()
	hud.arena = self
	add_child(hud)
	ring = SomRing.new()
	ring.arena = self
	add_child(ring)
	gauge = SomFx.Gauge.new()
	gauge.arena = self
	objects.add_child(gauge)


static func _ensure_actions() -> void:
	for pair in [[RING_ACTION, KEY_TAB], [SWITCH_ACTION, KEY_C]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], ev)


## Held-pose van RPG ART ("hurt", "ko", "cast"); null = ontbreekt.
func pose_tex(id: String, kind: String) -> Texture2D:
	return SomFx.tex(str(SomData.HERO_POSES.get(id, {}).get(kind, "")))


func sheet_for(id: String) -> Texture2D:
	return sheets.get(id, null)


func _apply_player_sheet() -> void:
	var tex := sheet_for(active_id)
	if tex and player.has_method("zet_sheet"):
		player.zet_sheet(tex)


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
	return SomData.apply_action_area(d, room.room_id, t)      # alleen Action; bazen/uniek ongewijzigd


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
			"flash": 0.0, "target": ""}


# ---------------------------------------------------------------- party
func member(id: String) -> Dictionary:
	return GameState.member(id) if GameState.has_member(id) else {}


## De bestuurde held.
func hero() -> Dictionary:
	var h := member(active_id)
	if h.is_empty() and not GameState.party.is_empty():
		return GameState.party[0]
	return h


func is_alive(id: String) -> bool:
	return int(member(id).get("hp", 0)) > 0


func ally_of(id: String) -> Node:
	for a in allies:
		if a.hero_id == id:
			return a
	return null


## Node (speler of bondgenoot) van een held.
func node_of(id: String) -> Node2D:
	return player if id == active_id else ally_of(id)


## Lichaamsmidden van een held-node (24x32-sprite).
func body_of(id: String) -> Vector2:
	var n := node_of(id)
	return (n.position if n else player.position) + Vector2(0, SomData.BODY_Y)


func body() -> Vector2:
	return body_of(active_id)


func party_ids() -> Array[String]:
	var out: Array[String] = []
	for h in GameState.party:
		out.append(str(h.get("id", "")))
	return out


## Levend partylid met het laagste HP-deel onder 'below' ({} = niemand).
func lowest_member(below: float) -> Dictionary:
	var best := {}
	var best_r := below
	for h in GameState.alive_heroes():
		var r := float(h["hp"]) / maxf(1.0, float(h["max_hp"]))
		if r < best_r:
			best_r = r
			best = h
	return best


## Volgende levende held in SomData.SWITCH_ORDER na 'from' ("" = niemand).
func next_alive(from: String) -> String:
	var order: Array[String] = []
	for id in SomData.SWITCH_ORDER:
		if GameState.has_member(id):
			order.append(id)
	for id in party_ids():
		if not order.has(id):
			order.append(id)
	var i := order.find(from)
	for k in range(1, order.size() + 1):
		var id := order[(i + k) % order.size()]
		if is_alive(id) and id != from:
			return id
	return ""


## SWITCH: besturing naar de volgende levende held. Speler-lichaam en bondgenoot-lichaam ruilen van held
## (sprite + plek); de camera glijdt mee. Geeft de nieuwe held-id ("" = niets gewisseld).
func switch_hero(to := "") -> String:
	var nxt := to if to != "" else next_alive(active_id)
	if nxt == "" or nxt == active_id or not is_alive(nxt):
		return ""
	var a := ally_of(nxt)
	if a == null:
		return ""
	var old := active_id
	var p_pos: Vector2 = player.position
	var p_face: Vector2i = player.facing
	player.position = a.position
	player.set("_target", a.position)
	player.facing = a.facing
	a.position = p_pos
	a.facing = p_face
	active_id = nxt
	a.set_hero(old)
	_apply_player_sheet()
	var c := charge
	charge = a.charge
	a.charge = c
	switches += 1
	_say(SomData.TXT_NOW % str(hero().get("name", nxt)))
	hero_switched.emit(nxt)
	return nxt


func analog_dir() -> Vector2:
	if forced_joy != Vector2.ZERO:
		return SomMove.joy_to_dir(forced_joy)
	if touch and "joy_raw" in touch and touch.joy_raw != Vector2.ZERO:
		return SomMove.joy_to_dir(touch.joy_raw)
	return SomMove.keys_to_dir()


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
	swing_lock = maxf(0.0, swing_lock - delta)
	if swing_lock <= 0.0 or not SomData.CHARGE_AFTER_ANIM:
		charge = minf(1.0, charge + delta / SomData.CHARGE_TIME)
	for k in iframes.keys():
		iframes[k] = maxf(0.0, float(iframes[k]) - delta)
	if Input.is_action_just_pressed(SWITCH_ACTION):
		switch_hero()
	b_cast_cd = maxf(0.0, b_cast_cd - delta)
	if Input.is_action_just_pressed("interact") and Engine.get_process_frames() != ring.closed_frame:
		attack()
	if Input.is_action_just_pressed("cancel") and Engine.get_process_frames() != ring.closed_frame:
		quick_cast()
	if not queued.is_empty():
		_queue_t -= delta
		if _queue_t <= 0.0:
			var q := queued
			queued = {}
			resolve(q)
	if allies_enabled:
		for a in allies:
			a.tick(delta)
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, delta)
		else:
			enemies.erase(m)


## B: de bestuurde held tovert zijn snelspreuk (SomData.B_MAGIC; alleen Seren/Vesper). Geeft de melding
## ("" = geen magiër of nog in cooldown).
func quick_cast() -> String:
	var spell := str(SomData.B_MAGIC.get(active_id, ""))
	if spell == "" or not is_alive(active_id) or b_cast_cd > 0.0:
		return ""
	var sp: Dictionary = GameData.SPELLS.get(spell, {})
	var text := ""
	if str(sp.get("type", "")) == "heal":
		var t := lowest_member(0.999)
		text = SomData.TXT_NO_WOUNDED if t.is_empty() else cast_spell(spell, active_id, t)
	else:
		text = cast_spell(spell, active_id, {})
	b_cast_cd = SomData.B_CAST_COOLDOWN
	b_casts += 1
	_say(text)
	action_resolved.emit(text)
	return text


# ---------------------------------------------------------------- aanvallen
## Schademultiplier van de wapenmeter (1.0 bij 100%).
static func charge_mult(c: float) -> float:
	return charge_mult_with(c, SomData.CHARGE_MIN_MULT)


## Schade x max(floor, lading); 1.0 bij een volle meter.
static func charge_mult_with(c: float, floor_mult: float) -> float:
	return 1.0 if c >= 1.0 else maxf(floor_mult, clampf(c, 0.0, 1.0))


## battle.gd _physical_damage zonder buffs/verdediging.
static func physical_damage(atk: float, def: float, mult: float) -> int:
	var base := (atk - def / 2.0) * mult
	return maxi(1, roundi(base * randf_range(0.85, 1.15)))


## Eén slag van de bestuurde held. Geeft het aantal geraakte vijanden.
func attack() -> int:
	if not is_alive(active_id):
		return 0
	attacks += 1
	var mult := charge_mult(charge)
	_full_swing = charge >= 1.0
	charge = 0.0
	swing_lock = anim_seconds(active_id)
	return _swing(active_id, player, mult)


## Duur (s) van de aanvalsanimatie van een held (0 zonder sheet).
func anim_seconds(id: String) -> float:
	if not attack_texs.has(id):
		return 0.0
	var tot := 0.0
	for v in SomData.ATTACK_ANIMS[id].get("ms", []):
		tot += float(v)
	return tot / 1000.0


## Slag van een held-node (speler of bondgenoot) in zijn kijkrichting. Met een aanvalssheet valt de treffer
## pas op het hit-frame (SomFx.Anim 'hit'); dan geeft dit -1 terug en volgt swing_landed. Zonder art: meteen.
func _swing(id: String, n: Node2D, mult: float) -> int:
	if attack_texs.has(id):
		var anim: Node = SomFx.attack_anim(n, attack_texs[id], SomData.ATTACK_ANIMS[id])
		anim.hit.connect(func() -> void: _land(id, n, mult), CONNECT_ONE_SHOT)
		return -1
	return _land(id, n, mult)


func _land(id: String, n: Node2D, mult: float) -> int:
	if not is_instance_valid(n) or not is_alive(id):
		swing_landed.emit(id, 0)
		return 0
	var f := Vector2(n.facing)
	var point: Vector2 = n.position + Vector2(0, SomData.BODY_Y) + f * SomData.attack_offset(id)
	SomFx.slash(room.get_node("Objects"), point, f)
	var hits := 0
	var atk := float(GameState.effective_stat(member(id), "atk"))
	for m in enemies.keys():
		if not is_instance_valid(m):
			continue
		if center_of(m).distance_to(point) <= SomData.attack_reach(id) + 8.0 * maxf(m.size.x, m.size.y):
			var e: Dictionary = enemies[m]
			last_attacker = id
			damage_enemy(m, physical_damage(atk, float(e["def"]), mult), n.facing, mult >= 1.0)
			hits += 1
	swing_landed.emit(id, hits)
	Sessielog.actie_slag(id, hits)
	return hits


## Bondgenoot slaat (volle meter; som_ally.gd heeft hem al naar de vijand gedraaid).
func ally_attack(a: Node2D, _enemy: Node) -> int:
	return _swing(a.hero_id, a, 1.0)


func center_of(m: Node) -> Vector2:
	return m.position + Vector2(0, -(m.size.y - 1) * 8.0)


## Dichtstbijzijnde (levende) vijand binnen 'within' px van 'from' (null = geen).
func nearest_enemy(from: Vector2, within: float) -> Node:
	var best: Node = null
	var bd := within
	for m in enemies.keys():
		if not is_instance_valid(m):
			continue
		var d := center_of(m).distance_to(from)
		if d <= bd:
			bd = d
			best = m
	return best


## stagger = false (slag onder 100%): wel schade, maar geen afgebroken telegraaf en geen knockback.
func damage_enemy(m: Node, dmg: int, dir: Vector2i, stagger := true) -> void:
	if not enemies.has(m):
		return
	var e: Dictionary = enemies[m]
	e["hp"] = int(e["hp"]) - dmg
	e["flash"] = SomData.HIT_FLASH
	last_enemy_damage = dmg
	SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -10), str(dmg), Color(1, 1, 1))
	SomFx.spark(room.get_node("Objects"), center_of(m))
	enemy_hit.emit(m, dmg)
	if int(e["hp"]) <= 0:
		_defeat_enemy(m)
		return
	if not stagger:
		return
	e["tele"] = 0.0          # volle treffer = telegraaf afgebroken
	_monster_pose(m, e, "hurt", 0, _hurt_seconds())
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
	var dt := _monster_sheet(m, "death")
	if dt and m.sprite:
		# doodgaan-sheet: 4 frames x MONSTER_DEATH_MS
		_restore_monster(m, e)
		_apply_sheet(m, dt, "death")
		m.sprite.modulate = Color.WHITE
		var tw := m.create_tween()
		var dms: Array = SomData.MONSTER_SHEETS["death"]["ms"]
		for f in m.sprite.hframes:
			tw.tween_callback(func() -> void: m.sprite.frame = f)
			tw.tween_interval(float(dms[mini(f, dms.size() - 1)]) / 1000.0)
		tw.tween_callback(m.queue_free)
		return
	var tw := m.create_tween()
	tw.tween_property(m, "modulate:a", 0.0, 0.3)
	tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- vijanden
## Sheet van RPG ART voor dit monster ("attack", "hurt", "death"); null = geen (of geen 1x1-monster).
func _hurt_seconds() -> float:
	var t := 0.0
	for v in SomData.MONSTER_SHEETS["hurt"]["ms"]:
		t += float(v)
	return t / 1000.0


func _monster_sheet(m: Node, kind: String) -> Texture2D:
	if m.placeholder or m.size != Vector2i.ONE:
		return null
	return SomFx.tex(SomData.MONSTER_SHEET_DIR + str(m.enemy_id) + "_" + kind + ".png")


## Pose tonen voor 'sec' seconden. attack: kolom col (0 opladen, 1 uithaal, 2 terug) in de rij van de
## kijkrichting; hurt: kolom = richting. Het monster staat zolang stil (zijn eigen loopanimatie uit).
func _monster_pose(m: Node, e: Dictionary, kind: String, col: int, sec: float) -> void:
	var t := _monster_sheet(m, kind)
	if t == null or m.sprite == null:
		return
	if not e.has("orig"):
		e["orig"] = [m.sprite.texture, m.sprite.hframes, m.sprite.vframes, m.sprite.offset]
	m.set_process(false)
	_apply_sheet(m, t, kind)
	var spec: Dictionary = SomData.MONSTER_SHEETS[kind]
	var cols := int(spec["cols"])
	var row := mini(SomFx.dir_index(m.facing), m.sprite.vframes - 1)
	m.sprite.frame = row * m.sprite.hframes + clampi(col, 0, cols - 1)
	e["pose"] = kind
	e["pose_col"] = col
	e["pose_t"] = sec
	e["pose_el"] = 0.0


## Sheet + celindeling (uit de textuur en SomData.MONSTER_SHEETS) + offset t.o.v. de 16x16-mapsprite.
func _apply_sheet(m: Node, t: Texture2D, kind: String) -> void:
	var spec: Dictionary = SomData.MONSTER_SHEETS[kind]
	var cell: Array = spec["cell"]
	m.sprite.texture = t
	m.sprite.hframes = maxi(1, t.get_width() / int(cell[0]))
	m.sprite.vframes = maxi(1, t.get_height() / int(cell[1]))
	var o: Vector2 = (e_orig_offset(m))
	var off := Vector2(float(spec["offset"][0]), float(spec["offset"][1]))
	# gecentreerde sprite: het 16x16-midden blijft staan; de cel schuift met 'offset'
	m.sprite.offset = o + (off + Vector2(float(cell[0]), float(cell[1])) / 2.0 - Vector2(8, 8)) if m.sprite.centered else o + off


func e_orig_offset(m: Node) -> Vector2:
	var e: Dictionary = enemies.get(m, {})
	return (e["orig"][3] as Vector2) if e.has("orig") and (e["orig"] as Array).size() > 3 else m.sprite.offset


func _hurt_frame(m: Node, e: Dictionary, delta: float) -> void:
	# 2 frames: wit (70 ms), dan rode terugslag (220 ms)
	e["pose_el"] = float(e.get("pose_el", 0.0)) + delta
	var hms: Array = SomData.MONSTER_SHEETS["hurt"]["ms"]
	var f := 1 if float(e["pose_el"]) * 1000.0 >= float(hms[0]) else 0
	m.sprite.frame = mini(SomFx.dir_index(m.facing), m.sprite.vframes - 1) * m.sprite.hframes + mini(f, m.sprite.hframes - 1)


func _restore_monster(m: Node, e: Dictionary) -> void:
	if e.has("orig") and m.sprite:
		var o: Array = e["orig"]
		m.sprite.texture = o[0]
		m.sprite.hframes = o[1]
		m.sprite.vframes = o[2]
		if o.size() > 3:
			m.sprite.offset = o[3]
		e.erase("orig")
		m._update_frame()
	e["pose"] = ""
	e["pose_t"] = 0.0
	if m.room != null:
		m.set_process(true)


func _pose_tick(m: Node, e: Dictionary, delta: float) -> void:
	if str(e.get("pose", "")) == "" or float(e.get("pose_t", 0.0)) <= 0.0:
		return
	e["pose_t"] = float(e["pose_t"]) - delta
	if float(e["pose_t"]) > 0.0 and str(e["pose"]) != "hurt":
		return
	if float(e["pose_t"]) > 0.0:
		_hurt_frame(m, e, delta)
		return
	if str(e["pose"]) == "attack" and int(e["pose_col"]) == 1:
		_monster_pose(m, e, "attack", 2, SomData.MONSTER_RETURN_MS / 1000.0)
	else:
		_restore_monster(m, e)


## Dichtstbijzijnde levende held (id) voor een vijand.
func _target_for(m: Node) -> String:
	var best := ""
	var bd := 1e9
	for id in party_ids():
		if not is_alive(id) or node_of(id) == null:
			continue
		var d := center_of(m).distance_to(body_of(id))
		if d < bd:
			bd = d
			best = id
	return best


func _enemy_ai(m: Node, delta: float) -> void:
	var e: Dictionary = enemies[m]
	if float(e["flash"]) > 0.0:
		e["flash"] = float(e["flash"]) - delta
	_pose_tick(m, e, delta)
	if m.is_stunned():
		_tint(m, e)
		return
	if float(e["tele"]) <= 0.0:
		e["target"] = _target_for(m)
	var tid := str(e["target"])
	if tid == "":
		_tint(m, e)
		return
	var dist: float = center_of(m).distance_to(body_of(tid))
	if float(e["tele"]) > 0.0:
		e["tele"] = float(e["tele"]) - delta
		if float(e["tele"]) <= 0.0:
			e["cd"] = SomData.attack_cooldown(room.room_id, room.tier())
			_monster_pose(m, e, "attack", 1, SomData.MONSTER_STRIKE_MS / 1000.0)
			if dist <= SomData.ENEMY_REACH + 8.0 * (maxf(m.size.x, m.size.y) - 1.0):
				hit_member(tid, int(e["atk"]))
	elif float(e["cd"]) > 0.0:
		e["cd"] = float(e["cd"]) - delta
	elif dist <= SomData.ENEMY_REACH:
		e["tele"] = SomData.TELEGRAPH
		var to := body_of(tid) - center_of(m)
		m.facing = Vector2i(signi(roundi(to.x)), 0) if absf(to.x) >= absf(to.y) else Vector2i(0, signi(roundi(to.y)))
		_monster_pose(m, e, "attack", 0, SomData.TELEGRAPH + 0.05)
		SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -14), "!", Color(1, 0.3, 0.3), SomData.TELEGRAPH)
	if dist > SomData.ENEMY_REACH - 6.0 and float(e["tele"]) <= 0.0:
		e["chase"] = float(e["chase"]) - delta
		if float(e["chase"]) <= 0.0 and not m.is_moving and dist < SomData.CHASE_RANGE * 16.0:
			e["chase"] = SomData.CHASE_INTERVAL
			_step_toward(m, body_of(tid))
	_tint(m, e)


func _step_toward(m: Node, to: Vector2) -> void:
	var d: Vector2 = to - center_of(m)
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


## Vijand raakt een held. Bestuurde held = de oude naam hit_player (ook voor tests).
func hit_player(atk: int, _from := Vector2.ZERO) -> void:
	hit_member(active_id, atk)


func hit_member(id: String, atk: int) -> void:
	if down or not is_alive(id):
		return
	if float(iframes.get(id, 0.0)) > 0.0:
		_dodge(id)
		return
	var h := member(id)
	var dmg := maxi(1, roundi(physical_damage(float(atk), float(GameState.effective_stat(h, "def")), 1.0) * SomData.enemy_damage_mult(room.room_id, room.tier())))
	h["hp"] = maxi(0, int(h["hp"]) - dmg)
	last_player_damage = dmg
	last_hit_id = id
	iframes[id] = SomData.PLAYER_IFRAMES
	if id == active_id:
		room.start_invuln(SomData.PLAYER_IFRAMES)
	var hurt := pose_tex(id, "hurt")
	if hurt and node_of(id) and int(h["hp"]) > 0:
		SomFx.hurt_pose(node_of(id), hurt, SomData.HURT_TIME)
	SomFx.number(room.get_node("Objects"), body_of(id) + Vector2(0, -22), str(dmg), Color(1, 0.4, 0.4))
	player_hit.emit(dmg)
	Sessielog.actie_treffer(id, dmg, int(h["hp"]))
	if int(h["hp"]) <= 0:
		_member_ko(id)


## Klap tijdens iframes: ontwijk-pose (geen schade). Telt mee in dodges (tests).
var dodges := 0
func _dodge(id: String) -> void:
	var t := pose_tex(id, "dodge")
	var n := node_of(id)
	if t == null or n == null or n.get_node_or_null("SomHurtAnim") != null or n.get_node_or_null("SomDodgeAnim") != null:
		return
	dodges += 1
	SomFx.dodge_pose(n, t, SomData.DODGE_TIME)


## Held KO: bondgenoot blijft liggen (som_ally.gd); bestuurde held -> wissel naar de volgende levende.
## Niemand meer over = game over.
func _member_ko(id: String) -> void:
	_say(SomData.TXT_KO % str(member(id).get("name", id)))
	member_down.emit(id)
	if GameState.alive_heroes().is_empty():
		_party_down()
		return
	if id == active_id:
		switch_hero()


## Iedereen KO: zelfde afloop als een verloren gevecht (checkpoint/respawn via GameState.end_battle).
func _party_down() -> void:
	down = true
	player.input_locked = true
	SomFx.set_ko(player, pose_tex(active_id, "ko"), true)
	_say(SomData.TXT_FALLEN % "The party")
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


## Doel van een item: opstaan-item -> eerste KO-held; anders de bestuurde held als die gewond is,
## anders het levende partylid met het laagste HP-deel.
func item_target(id: String) -> Dictionary:
	if float(GameData.ITEMS.get(id, {}).get("revive", 0.0)) > 0.0:
		for h in GameState.party:
			if int(h["hp"]) <= 0:
				return h
		return hero()
	var h := hero()
	if int(h["hp"]) < int(h["max_hp"]) and int(h["hp"]) > 0:
		return h
	var low := lowest_member(1.0)
	return low if not low.is_empty() else h


## Voert een keuze uit het ringmenu uit. Geeft de melding terug.
func resolve(q: Dictionary) -> String:
	var text := ""
	if str(q.get("kind", "")) == "item":
		var target := item_target(str(q["id"]))
		var r: Dictionary = PartyActions.use_item(GameState.inventory, str(q["id"]), target)
		text = str(r.get("text", ""))
		if int(r.get("hp", 0)) > 0:
			SomFx.number(room.get_node("Objects"), body_of(str(target.get("id", ""))) + Vector2(0, -22), "+%d" % int(r["hp"]), Color(0.4, 1, 0.5))
			heal_glow(str(target.get("id", "")))
	elif str(q.get("kind", "")) == "skill":
		text = use_skill(str(q.get("id", "")), str(q.get("caster", "")))
	else:
		var tgt: Variant = q.get("target", null)
		var heal_t: Dictionary = member(str(tgt)) if tgt is String else {}
		var en: Node = tgt if tgt is Node else null
		text = cast_spell(str(q.get("id", "")), str(q.get("caster", "")), heal_t, en)
	_say(text)
	action_resolved.emit(text)
	return text


## Spreuk van een held (MP van de caster). damage: dichtstbijzijnde/alle vijanden bij de caster;
## heal: 'heal_target' of het levende partylid met het laagste HP-deel.
func cast_spell(spell_id: String, caster_id: String, heal_target: Dictionary, enemy_target: Node = null) -> String:
	var sp: Dictionary = GameData.SPELLS.get(spell_id, {})
	var caster := member(caster_id)
	if sp.is_empty() or caster.is_empty() or int(caster.get("hp", 0)) <= 0:
		return ""
	var cost := int(sp.get("mp", 0))
	if int(caster.get("mp", 0)) < cost:
		return SomData.TXT_NO_MP
	var kind := str(sp.get("type", ""))
	var lvl := int(caster.get("level", 1))
	var from := body_of(caster_id)
	if kind == "damage":
		var targets: Array = []
		if str(sp.get("target", "")) == "all_enemies":
			for m in enemies.keys():
				if is_instance_valid(m) and center_of(m).distance_to(from) <= 10.0 * 16.0:
					targets.append(m)
		elif enemy_target != null and is_instance_valid(enemy_target) and enemies.has(enemy_target):
			targets.append(enemy_target)
		else:
			var best := nearest_enemy(from, 10.0 * 16.0)
			if best:
				targets.append(best)
		if targets.is_empty():
			return SomData.TXT_NO_TARGET
		caster["mp"] = int(caster["mp"]) - cost
		_cast_then(caster_id, spell_id, func() -> void:
			for m in targets:
				if not is_instance_valid(m) or not enemies.has(m):
					continue
				var amt := SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, caster_id, {"s": enemies[m]["data"]})
				last_attacker = caster_id
				spell_effect(spell_id, feet_of_enemy(m))
				SomFx.oneshot(room.get_node("Objects"), SomData.FX_SPELL_IMPACT, feet_of_enemy(m), "SomSpellImpact", Color(1, 0.6, 0.2))
				damage_enemy(m, maxi(1, roundi(amt * randf_range(0.9, 1.1))), Vector2i.ZERO))
		return "%s casts %s!" % [caster.get("name", ""), sp.get("name", spell_id)]
	if kind == "heal":
		var t := heal_target
		if t.is_empty():
			t = lowest_member(1.0)
		if t.is_empty():
			t = caster
		caster["mp"] = int(caster["mp"]) - cost
		var amt := roundi(SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, caster_id, {}))
		var expect := mini(amt, int(t["max_hp"]) - int(t["hp"]))
		var tid := str(t.get("id", ""))
		_cast_then(caster_id, spell_id, func() -> void:
			if int(t.get("hp", 0)) <= 0:
				return             # intussen KO: genezen wekt niet
			var got := PartyActions.restore(t, amt, 0)
			var n := node_of(tid)
			spell_effect(spell_id, n.position if n else player.position)
			SomFx.number(room.get_node("Objects"), body_of(tid) + Vector2(0, -22), "+%d" % got.x, Color(0.4, 1, 0.5))
			heal_glow(tid))
		return "%s casts %s! %s recovers %d HP." % [caster.get("name", ""), sp.get("name", spell_id), t.get("name", ""), expect]
	return SomData.TXT_MISS_BUFF % str(sp.get("name", spell_id))


## Genees-glans (fx_heal_glow, anker (8,16)) op de voeten van een held.
func heal_glow(id: String) -> void:
	var n := node_of(id)
	var feet: Vector2 = n.position if n else player.position
	SomFx.oneshot(room.get_node("Objects"), SomData.FX_HEAL_GLOW, feet, "SomHealGlow", Color(0.4, 1, 0.5))


## Voeten (onderrand) van een vijand: onderkant van zijn onderste tegel.
func feet_of_enemy(m: Node) -> Vector2:
	return m.position + Vector2(0, 8)


func _cast_pose(id: String) -> void:
	var t := pose_tex(id, "cast")
	if t and node_of(id):
		SomFx.cast_anim(node_of(id), t)


## Cast-animatie (cast6) van de caster; 'apply' draait op het vrijgavemoment (frame 4), daarna
## spell_released. Zonder cast6-sheet of zonder node: meteen.
func _cast_then(caster_id: String, spell_id: String, apply: Callable) -> void:
	var t := pose_tex(caster_id, "cast")
	var n := node_of(caster_id)
	var done := func() -> void:
		apply.call()
		spell_released.emit(spell_id, caster_id)
	var cols := int(SomData.CAST6["frames"])
	if t and n and t.get_width() == cols * int(SomData.CAST6["frame"][0]):
		var circle := SomFx.tex(str(SomData.CAST_CIRCLE.get(caster_id, "")))
		var anim: Node = SomFx.cast6_anim(n, t, circle)
		anim.hit.connect(done, CONNECT_ONE_SHOT)
		return
	done.call()


## Spreuk-effect (SomData.SPELL_FX) onderkant-midden op 'feet'. Geeft false zonder art.
func spell_effect(spell_id: String, feet: Vector2) -> bool:
	var d := SomFx.spell_fx_def(spell_id, GameData.SPELLS.get(spell_id, {}))
	if d.is_empty():
		return false
	SomFx.oneshot(room.get_node("Objects"), d, feet, "SomSpell_" + str(d["key"]), Color.WHITE)
	return true


## Ringmenu-inhoud voor de bestuurde held: items die in het veld werken, en zijn eigen spreuken.
func ring_entries() -> Dictionary:
	var items: Array = []
	for id in GameState.inventory.keys():
		var sid := str(id)
		if GameState.item_count(sid) > 0 and GameData.ITEMS.has(sid) and PartyActions.item_block_reason(sid) == "" \
				and not bool(GameData.ITEMS[sid].get("warp", false)):
			items.append({"kind": "item", "id": sid, "label": "%s x%d" % [PartyActions.item_name(sid), GameState.item_count(sid)],
					"name": PartyActions.item_name(sid), "count": GameState.item_count(sid)})
	var skills: Array = []
	for sk in SomData.SKILLS.get(active_id, []):
		skills.append({"kind": "skill", "id": str(sk["id"]), "caster": active_id, "label": str(sk["name"]), "name": str(sk["name"])})
	var magic: Array = []
	var h := hero()
	for s in h.get("spells", []):
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if sp.is_empty():
			continue
		magic.append({"kind": "spell", "id": str(s), "caster": active_id,
				"label": "%s %d" % [str(sp.get("name", s)), int(sp.get("mp", 0))], "name": str(sp.get("name", s))})
	return {"items": items, "skills": skills, "magic": magic}


## Spreuk met één doel (vijand of partylid) -> in de ring eerst een doel kiezen.
func needs_target(spell_id: String) -> bool:
	return str(GameData.SPELLS.get(spell_id, {}).get("target", "")) in ["enemy", "ally"]


## Doelen voor de doelkeuze: vijanden binnen SPELL_RANGE van de caster (dichtstbij eerst) of levende partyleden.
func spell_targets(spell_id: String, caster_id: String) -> Array:
	var sp: Dictionary = GameData.SPELLS.get(spell_id, {})
	var out: Array = []
	if str(sp.get("target", "")) == "ally":
		for h in GameState.alive_heroes():
			out.append({"kind": "target", "id": str(h["id"]), "target": str(h["id"]),
					"label": "%s %d/%d" % [h["name"], int(h["hp"]), int(h["max_hp"])], "name": str(h["name"])})
		return out
	var from := body_of(caster_id)
	var list: Array = []
	for m in enemies.keys():
		if is_instance_valid(m) and center_of(m).distance_to(from) <= SomData.SPELL_RANGE:
			list.append(m)
	list.sort_custom(func(x, y): return center_of(x).distance_to(from) < center_of(y).distance_to(from))
	for m in list:
		var e: Dictionary = enemies[m]
		out.append({"kind": "target", "id": str(m.monster_id), "target": m,
				"label": "%s %d" % [str(e["data"].get("name", m.enemy_id)), int(e["hp"])], "name": str(e["data"].get("name", m.enemy_id))})
	return out


## Skill uit de skill-ring (SomData.SKILLS): vraagt een volle wapenmeter en zet hem op 0.
## radius > 0 = rondom (alle vijanden binnen radius), anders een slag recht vooruit met 'mult'.
func use_skill(skill_id: String, hero_id: String) -> String:
	var sk := {}
	for s in SomData.SKILLS.get(hero_id, []):
		if str(s["id"]) == skill_id:
			sk = s
	if sk.is_empty() or not is_alive(hero_id) or hero_id != active_id:
		return ""
	if charge < 1.0:
		return SomData.TXT_NOT_READY
	charge = 0.0
	var mult := float(sk.get("mult", 1.0))
	var radius := float(sk.get("radius", 0.0))
	if radius <= 0.0:
		_swing(hero_id, player, mult)
	else:
		SomFx.spark(room.get_node("Objects"), body_of(hero_id))
		var atk := float(GameState.effective_stat(member(hero_id), "atk"))
		for m in enemies.keys():
			if is_instance_valid(m) and center_of(m).distance_to(body_of(hero_id)) <= radius:
				last_attacker = hero_id
				var e: Dictionary = enemies[m]
				var away := center_of(m) - body_of(hero_id)
				damage_enemy(m, physical_damage(atk, float(e["def"]), mult),
						Vector2i(signi(roundi(away.x)), 0) if absf(away.x) >= absf(away.y) else Vector2i(0, signi(roundi(away.y))))
	return "%s uses %s!" % [member(hero_id).get("name", ""), sk["name"]]


func _say(text: String) -> void:
	last_text = text
	if hud:
		hud.toast(text)
