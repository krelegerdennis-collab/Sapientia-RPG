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
## Spreuk komt vrij (kaart-cast frame 2 / cast6 frame 4, of meteen zonder sheet): schade/genezing is toegepast.
signal spell_released(spell_id: String, caster_id: String)
signal ring_opened
signal ring_closed
signal action_resolved(text: String)
## Begin van elke vaste stap (vóór input en AI). Voor bots/AI-stoelen en tests: input die hier wordt gezet,
## verbruikt dezelfde stap.
signal sim_ticked(tick: int)

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
const SomCodex := preload("res://scripts/som/som_codex.gd")
const SomTargetLock := preload("res://scripts/som/som_target_lock.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphLayer := preload("res://scripts/som/telegraph_layer.gd")
const CombatZones := preload("res://scripts/som/combat_zones.gd")
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
## Codex vangen in Action (scripts/som/som_codex.gd)
var codex: Node
## Doel-lock (tap + auto-lock in bereik)
var target_lock: Node2D
var gauge: Node2D
var telegraph_layer: TelegraphLayer
var combat_zones := CombatZones.new()
## Tests: geforceerde aanval-id voor de volgende telegraaf-windup ("" = RNG).
var forced_enemy_attack := ""
## Keuze uit het ringmenu die na het sluiten "landt": {"kind": "item"/"spell", "id", "caster"}.
var queued := {}
var _queue_t := 0.0
var touch: Control
## Autotest: vaste joystick-stand (ZERO = echte input).
var forced_joy := Vector2.ZERO
## Co-op: ring opent zonder get_tree().paused (ActionCoopSession zet dit aan).
var coop_ring_no_pause := false
var coop_mode := false
var coop_sim_host := false
var coop_local_slot := -1
var _coop_slots: Dictionary = {}
var _coop_avatars: Dictionary = {}
var _coop_lock_idx: Dictionary = {}
var _enemy_order: Array = []
var _coop_attack_cd: Dictionary = {}
var _coop_snap: Dictionary = {}
## Kaartsprites en aanvalsanimaties per held-id (geladen in setup; ontbreekt = placeholder).
var sheets := {}
var attack_texs := {}
## Kaart-cast sheets (SomData.MAP_CAST), één keer geladen in setup() — geen load() tijdens cast.
var map_cast_texs := {}
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
## Alleen voor tests/vergelijk-shots: held-ids waarvoor de kaart-cast uit staat (dan cast6 of direct).
var map_cast_uit: Array = []

## Eén seeded RNG voor alle toeval in dit gevecht (schade-spreiding, drops, achtervolg-start, bondgenoot-keuze,
## Codex-vangkans). Standaard willekeurig (randomize, zelfde gedrag als de globale randf); seed_rng(n) maakt een
## gevecht reproduceerbaar (--combatrngtest, COMBAT_DESIGN.md §16).
var rng := RandomNumberGenerator.new()
var rng_seed := 0


func _init() -> void:
	rng.randomize()


## Zet de seed van dit gevecht (0 = willekeurig, zoals voorheen).
func seed_rng(s: int) -> void:
	rng_seed = s
	if s == 0:
		rng.randomize()
	else:
		rng.seed = s


func setup(p_room: Node) -> void:
	room = p_room
	player = room.player
	name = "SomArena"
	_ensure_actions()
	# Geheugen: alleen de sheets van de party (en de reserve) vooraf; andere helden (bv. een co-op-peer) via sheet_for().
	for id in _held_ids_nodig():
		_laad_sheet(id)
		var sheet := str(SomData.ATTACK_ANIMS.get(id, {}).get("sheet", ""))
		if sheet != "" and ResourceLoader.exists(sheet):
			attack_texs[id] = load(sheet)
		_laad_held_cast(id)
	# leider-behoud: de held die je met SWAP koos (GameState.leader_id), terugval Dax bij KO / niet in de party
	active_id = GameState.active_leader()
	if member(active_id).is_empty():
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
	player.facing_provider = Callable(self, "_lock_facing")
	_apply_player_sheet()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = SomData.CAMERA_SMOOTH
	var objects := room.get_node("Objects")
	# Co-op: geen solo SomAlly-bondgenoten; alleen CoopAvatar per stoel.
	if not GameState.coop_in_session():
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
	codex = SomCodex.new()
	codex.name = "SomCodex"
	codex.arena = self
	add_child(codex)
	hud = SomHud.new()
	hud.arena = self
	add_child(hud)
	ring = SomRing.new()
	ring.arena = self
	add_child(ring)
	gauge = SomFx.Gauge.new()
	gauge.arena = self
	objects.add_child(gauge)
	target_lock = SomTargetLock.new()
	target_lock.name = "SomTargetLock"
	target_lock.setup(self)
	objects.add_child(target_lock)
	telegraph_layer = TelegraphLayer.new()
	objects.add_child(telegraph_layer)
	objects.move_child(telegraph_layer, 0)


## Kaartsheet van Dax via KaartStijl (#169): speler_sheet() van het gebied van deze kamer als Dax leidt
## (anders, of zonder gebied, held_sheet("Dax") = dezelfde vaste partijsheet HELD_VAST["dax"]).
## Pas als KaartStijl niets heeft: SomData.SHEETS["dennis"].
func dax_sheet_path() -> String:
	var p := ""
	if not GameState.party.is_empty() and str(GameState.party[0].get("id", "")) == "dennis":
		var gebied := KaartStijl.gebied_van_map(str(room.scene_file_path)) if room != null else ""
		p = KaartStijl.speler_sheet(gebied if gebied != "" else "wilgendal")
	if p == "" or not ResourceLoader.exists(p):
		p = KaartStijl.held_sheet("Dax")
	if p == "" or not ResourceLoader.exists(p):
		p = str(SomData.SHEETS["dennis"])
	return p


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
	if not sheets.has(id) and room != null and SomData.SHEETS.has(id):
		_laad_sheet(id)
	return sheets.get(id, null)


## Held-id's waarvan deze arena kaart- en aanvalssheets nodig heeft: party + reserve, altijd Dax.
func _held_ids_nodig() -> Array[String]:
	var ids: Array[String] = ["dennis"]
	for h in GameState.party + GameState.party_bench:
		var id := str(h.get("id", ""))
		if id != "" and SomData.SHEETS.has(id) and not ids.has(id):
			ids.append(id)
	return ids


func _laad_sheet(id: String) -> void:
	var path := str(SomData.SHEETS.get(id, ""))
	if id == "dennis":
		path = dax_sheet_path()
	if path != "" and ResourceLoader.exists(path):
		sheets[id] = load(path)


## Kaart-cast (+ fx) voor een held; setup() en join_party_hero() — geen load() tijdens cast.
func _laad_held_cast(id: String) -> void:
	if map_cast_texs.has(id) or not SomData.MAP_CAST.has(id):
		return
	var mc: Dictionary = SomData.MAP_CAST[id]
	var sheet_path := str(mc.get("sheet", ""))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path):
		return
	var fx_path := str(mc.get("fx", ""))
	map_cast_texs[id] = {
		"sheet": load(sheet_path),
		"fx": load(fx_path) if fx_path != "" and ResourceLoader.exists(fx_path) else null,
	}


## Held sluit aan terwijl deze arena al draait (rekruut, story join): cast-sheets + bondgenoot-body.
func join_party_hero(id: String) -> void:
	if room == null or id == "" or not GameState.has_member(id):
		return
	_laad_held_cast(id)
	if coop_mode or not allies_enabled or id == active_id or ally_of(id) != null:
		return
	if not GameState.party.any(func(h): return str(h.get("id", "")) == id):
		return
	var objects: Node = room.get_node_or_null("Objects")
	if objects == null:
		return
	var a: CharacterBody2D = SomAlly.new()
	objects.add_child(a)
	a.setup(self, id, allies.size())
	allies.append(a)


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
	var entry := {"hp": int(d.get("max_hp", 1)), "max_hp": int(d.get("max_hp", 1)), "atk": int(d.get("atk", 1)),
			"def": int(d.get("def", 0)), "exp": int(d.get("exp", 0)), "gold": int(d.get("gold", 0)),
			"drops": d.get("drops", []), "data": d, "cd": 0.6, "tele": 0.0, "chase": rng.randf() * SomData.CHASE_INTERVAL,
			"flash": 0.0, "target": ""}
	var eid := str(m.enemy_id)
	if SomActionAttacks.has_telegraph_attack(eid):
		var aid := SomActionAttacks.default_attack_for_enemy(eid)
		var tg := TelegraphAttack.new()
		tg.configure(SomActionAttacks.attack(aid), SomActionAttacks.cooldown_ms(room.room_id, room.tier()))
		entry["tg"] = tg
	enemies[m] = entry


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
	if a.in_wall():
		a._teleport()      # anders belandt de bestuurde held in de muur en kan hij niet meer lopen
	var old := active_id
	var p_pos: Vector2 = player.position
	var p_face: Vector2i = player.facing
	player.position = a.position
	player.set("_target", a.position)
	player.facing = a.facing
	a.position = p_pos
	a.facing = p_face
	active_id = nxt
	GameState.set_leader(nxt)
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
	var base := Vector2.ZERO
	if forced_joy != Vector2.ZERO:
		base = SomMove.joy_to_dir(forced_joy)
	elif touch and "joy_raw" in touch and touch.joy_raw != Vector2.ZERO:
		base = SomMove.joy_to_dir(touch.joy_raw)
	else:
		base = SomMove.keys_to_dir()
	return base * _zone_slow_mult_for_id(active_id)


func _lock_facing() -> Vector2i:
	return target_lock.facing_for_player() if target_lock else Vector2i.ZERO


func _attack_suppressed() -> bool:
	return target_lock != null and int(target_lock.suppress_attack_frame) == Engine.get_process_frames()


## Schermtik op een monster (touch_controls); true = lock verwerkt, geen A/joy.
func try_lock_tap(viewport_pos: Vector2) -> bool:
	return target_lock.try_tap_viewport(viewport_pos) if target_lock else false


func active() -> bool:
	return not down and room != null and room.monsters_active() and not ring.is_open


## --- vaste simulatiestap (roadmap stap 3, COMBAT_DESIGN.md §16) ---
## De gevechtslogica (meters, iframes, wachtrij, bondgenoten, vijand-AI) loopt in vaste stappen van 1/60 s,
## los van de framerate. _process leest alleen input (per frame, zoals voorheen) en tekent; advance() zet
## frametijd om in stappen. Bij 60 fps is dat precies één stap per frame, dus gelijk aan het oude gedrag.
const CombatSim := preload("res://scripts/som/combat_sim.gd")
const TICK_HZ := CombatSim.TICK_HZ
const TICK_DT := CombatSim.TICK_DT
## Plafond per frame (geen "spiral of death" na een hapering); de rest van de achterstand vervalt.
const MAX_TICKS_PER_FRAME := CombatSim.MAX_TICKS_PER_FRAME
## Pure klok (stap 3b). sim_tick/_tick_acc blijven als namen voor tests en HUD.
var clock := CombatSim.new()
var sim_tick: int:
	get:
		return clock.tick
var _tick_acc: float:
	get:
		return clock.acc
## Animaties waarvan de arena de tijd stuurt (treffer/vrijgave op de vaste stap, niet op frametijd).
var _sim_anims: Array = []
## Input van dit frame, verbruikt door de eerstvolgende stap (zelfde volgorde als voorheen).
var _pending := {"switch": false, "attack": false, "cast": false}


func _process(delta: float) -> void:
	if room == null or GameState.party.is_empty():
		return
	if coop_mode and not coop_sim_host:
		if target_lock:
			target_lock.tick(delta)
		if Input.is_action_just_pressed(RING_ACTION) and active():
			open_ring()
		return
	if Input.is_action_just_pressed(RING_ACTION) and active():
		open_ring()
		return
	if not active():
		_pending = {"switch": false, "attack": false, "cast": false}
		if target_lock:
			target_lock.tick(delta)      # wist alleen de markers (arena niet actief)
		# Alleen lopende slag/cast-animaties (geen stick/A/B-input, geen vijand-AI).
		if _combat_sim_busy():
			advance_busy_anims(delta)
		return
	if Input.is_action_just_pressed(SWITCH_ACTION) and not coop_mode:
		_pending["switch"] = true
	if Input.is_action_just_pressed("interact") and Engine.get_process_frames() != ring.closed_frame \
			and not _attack_suppressed():
		_pending["attack"] = true
	if Input.is_action_just_pressed("cancel") and Engine.get_process_frames() != ring.closed_frame:
		_pending["cast"] = true
	advance(delta)


## Frametijd -> vaste stappen. Geeft het aantal gedraaide stappen (tests: --combattick).
func advance(delta: float) -> int:
	var n := clock.frames_to_ticks(delta)
	for i in n:
		sim_step()
	return n


## Arena niet actief (menu/dialog): alleen animaties en wachtrij-spreuken afronden, geen input/AI.
func advance_busy_anims(delta: float) -> int:
	var n := clock.frames_to_ticks(delta)
	for i in n:
		_busy_anim_step()
	return n


func _busy_anim_step() -> void:
	var dt := TICK_DT
	clock.tick += 1
	sim_ticked.emit(clock.tick)
	swing_lock = maxf(0.0, swing_lock - dt)
	charge = CombatSim.charge_after(charge, swing_lock, SomData.CHARGE_AFTER_ANIM, SomData.CHARGE_TIME, dt)
	CombatSim.tick_down(iframes, dt)
	if not queued.is_empty():
		_queue_t -= dt
		if _queue_t <= 0.0:
			var q := queued
			queued = {}
			resolve(q)
	_sim_world(dt)


## Eén stap van 1/60 s. Zelfde volgorde als het oude _process.
func sim_step() -> void:
	var dt := TICK_DT
	clock.tick += 1
	sim_ticked.emit(clock.tick)
	if target_lock:
		target_lock.tick(dt)
	swing_lock = maxf(0.0, swing_lock - dt)
	charge = CombatSim.charge_after(charge, swing_lock, SomData.CHARGE_AFTER_ANIM, SomData.CHARGE_TIME, dt)
	CombatSim.tick_down(iframes, dt)
	if _pending["switch"]:
		_pending["switch"] = false
		switch_hero()
	b_cast_cd = maxf(0.0, b_cast_cd - dt)
	if _pending["attack"]:
		_pending["attack"] = false
		attack()
	if _pending["cast"]:
		_pending["cast"] = false
		quick_cast()
	if not queued.is_empty():
		_queue_t -= dt
		if _queue_t <= 0.0:
			var q := queued
			queued = {}
			resolve(q)
	if allies_enabled:
		for a in allies:
			a.tick(dt)
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, dt)
		else:
			enemies.erase(m)
	_tick_zones()
	_sim_world(dt)


## Wereld op de vaste stap: tegelbeweging van de vijanden (MapMonster.sim_move) en de arena-animaties
## (SomFx.Anim.step: treffer- en vrijgaveframe). Ook voor de co-op-host (coop_host_step).
func _sim_world(dt: float) -> void:
	for m in enemies.keys():
		if is_instance_valid(m) and m.has_method("sim_move"):
			m.sim_driven = true
			if m.is_processing():        # pose/defeat zet set_process(false) = staat stil (zoals voorheen)
				m.sim_move(dt)
	var keep: Array = []
	for a in _sim_anims:
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			a.step(dt)
			if is_instance_valid(a) and not a.is_queued_for_deletion():
				keep.append(a)
	_sim_anims = keep
	_sync_telegraph_draw()


## Animatie op de vaste stap zetten (geen eigen _process-tijd meer).
func _drive(anim: Node) -> Node:
	if anim != null and "sim_driven" in anim:
		anim.sim_driven = true
		_sim_anims.append(anim)
	return anim


## Tests/sim: n stappen zonder frametijd.
func step_ticks(n: int) -> void:
	for i in n:
		sim_step()


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
## r = de RNG van het gevecht; null = globale randf_range (tools/battlesim, ongewijzigd).
static func physical_damage(atk: float, def: float, mult: float, r: RandomNumberGenerator = null) -> int:
	var base := (atk - def / 2.0) * mult
	var spread := r.randf_range(0.85, 1.15) if r != null else randf_range(0.85, 1.15)
	return maxi(1, roundi(base * spread))


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
		var anim: Node = _drive(SomFx.attack_anim(n, attack_texs[id], SomData.ATTACK_ANIMS[id]))
		# bondgenoot: de slag gaat de kant op waar hij begon (zijn AI kan tijdens de animatie al draaien)
		var face0: Vector2i = n.facing
		anim.hit.connect(func() -> void:
			if id != active_id and is_instance_valid(n):
				n.facing = face0
			_land(id, n, mult), CONNECT_ONE_SHOT)
		return -1
	return _land(id, n, mult)


func _land(id: String, n: Node2D, mult: float) -> int:
	if not is_instance_valid(n) or not is_alive(id):
		swing_landed.emit(id, 0)
		return 0
	var f := Vector2(_swing_facing(id, n))
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
			damage_enemy(m, physical_damage(atk, float(e["def"]), mult, rng), Vector2i(roundi(f.x), roundi(f.y)), mult >= 1.0)
			hits += 1
	swing_landed.emit(id, hits)
	SessieLog.actie_slag(id, hits)
	return hits


## Bondgenoot slaat (volle meter; som_ally.gd heeft hem al naar de vijand gedraaid).
func ally_attack(a: Node2D, _enemy: Node) -> int:
	return _swing(a.hero_id, a, 1.0)


func center_of(m: Node) -> Vector2:
	return m.position + Vector2(0, -(m.size.y - 1) * 8.0)


func _enemy_in_attack_reach(id: String, n: Node2D, m: Node) -> bool:
	var f := Vector2(n.facing)
	var point: Vector2 = n.position + Vector2(0, SomData.BODY_Y) + f * SomData.attack_offset(id)
	return center_of(m).distance_to(point) <= SomData.attack_reach(id) + 8.0 * maxf(m.size.x, m.size.y)


func _swing_facing(id: String, n: Node2D) -> Vector2i:
	# Alleen een handmatige lock stuurt de slagrichting; auto-lock is alleen marker + strafe-facing.
	if id == active_id and target_lock and target_lock.manual:
		var m: Node = target_lock.locked_enemy()
		if m != null:
			var lf: Vector2i = target_lock.facing_for_player()
			if lf != Vector2i.ZERO:
				n.facing = lf
				return lf
	return n.facing


func _combat_sim_busy() -> bool:
	return swing_lock > 0.0 or not _sim_anims.is_empty() or not queued.is_empty()


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


func _aim_caster_at(caster_id: String, m: Node) -> void:
	if m == null or not is_instance_valid(m) or caster_id != active_id:
		return
	var to: Vector2 = center_of(m) - body_of(caster_id)
	if to.length() < 0.5:
		return
	player.facing = SomMove.facing_for(to.normalized(), player.facing)


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
	if e.has("tg"):
		(e["tg"] as TelegraphAttack).interrupt()
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
	if not enemies.has(m):
		return
	combat_zones.clear_owner(_enemy_index(m))
	var e: Dictionary = enemies[m]
	if e.has("tg"):
		(e["tg"] as TelegraphAttack).cancel()
	enemies.erase(m)
	if target_lock:
		target_lock.on_target_gone(m)
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
		if typeof(d) == TYPE_DICTIONARY and GameData.ITEMS.has(str(d.get("item", ""))) and rng.randf() < float(d.get("chance", 0.0)):
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
func _slot_for_hero(hero_id: String) -> int:
	for slot in _coop_slots.keys():
		if str(_coop_slots[slot]) == hero_id:
			return int(slot)
	return Protocol.NO_SLOT


func _target_for(m: Node) -> String:
	if coop_mode:
		var hid: String = str(_coop_slots.get(0, "dennis"))
		if is_alive(hid):
			return hid
		return ""
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
	if not enemies.has(m):
		return
	var e: Dictionary = enemies[m]
	if e.has("tg"):
		_enemy_ai_telegraph(m, e, delta)
		return
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


## Inktwurm / Inktspuw: TelegraphState + vaste shape (T4a). Zelfde cadans als de float-telegraaf.
func _enemy_ai_telegraph(m: Node, e: Dictionary, delta: float) -> void:
	var tg: TelegraphAttack = e["tg"]
	if float(e["flash"]) > 0.0:
		e["flash"] = float(e["flash"]) - delta
	_pose_tick(m, e, delta)
	if m.is_stunned():
		if tg.is_busy():
			tg.cancel()
			e.erase("tg_attack")
		_sync_telegraph_meters(e, tg)
		_tint(m, e)
		return
	if not tg.is_busy():
		e["target"] = _target_for(m)
		e.erase("tg_attack")
	var tid := str(e["target"])
	if tid == "":
		if tg.is_busy() and tg.in_windup():
			tg.cancel()
			e.erase("tg_attack")
		_sync_telegraph_meters(e, tg)
		_tint(m, e)
		return
	var dist: float = center_of(m).distance_to(body_of(tid))
	if tg.is_busy():
		if tg.in_windup() and not is_alive(tid):
			tg.cancel()
			e.erase("tg_attack")
		else:
			tg.tick()
			if tg.entered_active_this_tick():
				_monster_pose(m, e, "attack", 1, SomData.MONSTER_STRIKE_MS / 1000.0)
				var aid := str(e.get("tg_attack", SomActionAttacks.default_attack_for_enemy(m.enemy_id)))
				var def: Dictionary = SomActionAttacks.attack(aid)
				var power := float(def.get("power", 1.0))
				var hit_pt := TelegraphShape.to_px(body_of(tid))
				if tg.hits_point_i(hit_pt):
					hit_member(tid, int(e["atk"]), power)
				if bool(def.get("spawns_zone", false)) and _zones_authority():
					combat_zones.try_spawn(
							_enemy_index(m),
							tg.locked_origin(),
							int(def.get("reach", 16)),
							int(def.get("zone_ticks", 120)),
							int(e["atk"]),
							float(def.get("zone_dot_power", 0.3)),
							float(def.get("zone_slow_mult", 0.6)),
					)
		_sync_telegraph_meters(e, tg)
	elif tg.can_start() and dist <= SomData.ENEMY_REACH:
		var to: Vector2 = body_of(tid) - center_of(m)
		m.facing = Vector2i(signi(roundi(to.x)), 0) if absf(to.x) >= absf(to.y) else Vector2i(0, signi(roundi(to.y)))
		var aid := forced_enemy_attack if forced_enemy_attack != "" else SomActionAttacks.pick_attack(m.enemy_id, rng)
		if forced_enemy_attack != "":
			forced_enemy_attack = ""
		var def: Dictionary = SomActionAttacks.attack(aid)
		if str(e.get("tg_attack", "")) != aid:
			tg.configure(def, SomActionAttacks.cooldown_ms(room.room_id, room.tier()))
			e["tg_attack"] = aid
		var origin: Vector2i = TelegraphShape.to_px(body_of(tid)) if str(def.get("aim", "")) == "target" else TelegraphShape.to_px(center_of(m))
		var dir: Vector2i = TelegraphShape.dir_from_vector(to)
		tg.start(origin, dir, str(def.get("shape", "line")))
		_sync_telegraph_meters(e, tg)
		_monster_pose(m, e, "attack", 0, SomData.TELEGRAPH + 0.05)
		SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -14), "!", Color(1, 0.3, 0.3), SomData.TELEGRAPH)
	else:
		_sync_telegraph_meters(e, tg)
	if dist > SomData.ENEMY_REACH - 6.0 and float(e["tele"]) <= 0.0:
		e["chase"] = float(e["chase"]) - delta
		if float(e["chase"]) <= 0.0 and not m.is_moving and dist < SomData.CHASE_RANGE * 16.0:
			e["chase"] = SomData.CHASE_INTERVAL
			_step_toward(m, body_of(tid))
	_tint(m, e)


func _sync_telegraph_draw() -> void:
	if telegraph_layer == null:
		return
	telegraph_layer.sync_from_enemies(enemies, Callable(self, "_telegraph_interruptible"))
	telegraph_layer.sync_from_zones(combat_zones)


func _zones_authority() -> bool:
	return not coop_mode or coop_sim_host


func _zone_slow_mult_for_id(id: String) -> float:
	if id == "" or not is_alive(id):
		return 1.0
	return combat_zones.slow_mult_at(TelegraphShape.to_px(body_of(id)))


func _tick_zones() -> void:
	if not _zones_authority():
		return
	var dots: Array = combat_zones.tick()
	for z in dots:
		for hid in party_ids():
			if not is_alive(hid):
				continue
			var px := TelegraphShape.to_px(body_of(hid))
			if combat_zones.contains_point(px, z):
				hit_member_zone_dot(hid, int(z.get("atk", 1)), float(z.get("dot_power", 0.3)))


func _telegraph_interruptible(attack_id: String) -> bool:
	var def: Dictionary = SomActionAttacks.attack(attack_id)
	return bool(def.get("interruptible", false))


func _sync_telegraph_meters(e: Dictionary, tg: TelegraphAttack) -> void:
	if tg.in_windup():
		e["tele"] = float(tg.ticks_left_in_phase()) * TICK_DT
		e["cd"] = 0.0
	elif tg.in_cooldown():
		e["tele"] = 0.0
		e["cd"] = float(tg.ticks_left_in_phase()) * TICK_DT
	else:
		e["tele"] = 0.0
		e["cd"] = 0.0


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


func hit_member(id: String, atk: int, power: float = 1.0) -> void:
	if down or not is_alive(id):
		return
	if float(iframes.get(id, 0.0)) > 0.0:
		_dodge(id)
		return
	var h := member(id)
	var mult: float = SomData.enemy_damage_mult(room.room_id, room.tier()) * maxf(0.0, power)
	var dmg := maxi(1, roundi(physical_damage(float(atk), float(GameState.effective_stat(h, "def")), 1.0, rng) * mult))
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
	SessieLog.actie_treffer(id, dmg, int(h["hp"]))
	if int(h["hp"]) <= 0:
		_member_ko(id)


## Zone-DoT (T4b): respecteert iframes, zet geen nieuwe hit-invuln.
func hit_member_zone_dot(id: String, atk: int, power: float) -> void:
	if down or not is_alive(id):
		return
	if float(iframes.get(id, 0.0)) > 0.0:
		return
	var h := member(id)
	var mult: float = SomData.enemy_damage_mult(room.room_id, room.tier()) * maxf(0.0, power)
	var dmg := maxi(1, roundi(physical_damage(float(atk), float(GameState.effective_stat(h, "def")), 1.0, rng) * mult))
	h["hp"] = maxi(0, int(h["hp"]) - dmg)
	last_player_damage = dmg
	last_hit_id = id
	SomFx.number(room.get_node("Objects"), body_of(id) + Vector2(0, -22), str(dmg), Color(0.55, 0.45, 0.95))
	player_hit.emit(dmg)
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
	combat_zones.clear_all()
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
	elif str(q.get("kind", "")) == "codex":
		var ct: Variant = q.get("target", null)
		text = codex.capture(ct if typeof(ct) == TYPE_OBJECT else null)   # ook een intussen vrijgegeven doel (boek terug)
		action_resolved.emit(text)
		return text
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
		elif target_lock and target_lock.locked_enemy() != null:
			targets.append(target_lock.locked_enemy())
		else:
			var best := nearest_enemy(from, 10.0 * 16.0)
			if best:
				targets.append(best)
		if targets.is_empty():
			return SomData.TXT_NO_TARGET
		if targets[0] is Node:
			_aim_caster_at(caster_id, targets[0])
		caster["mp"] = int(caster["mp"]) - cost
		_cast_then(caster_id, spell_id, func() -> void:
			for m in targets:
				if not is_instance_valid(m) or not enemies.has(m):
					continue
				var amt := SpellRules.power_at(sp, lvl) * SpellRules.factor(sp, caster_id, {"s": enemies[m]["data"]})
				last_attacker = caster_id
				spell_effect(spell_id, feet_of_enemy(m))
				SomFx.oneshot(room.get_node("Objects"), SomData.FX_SPELL_IMPACT, feet_of_enemy(m), "SomSpellImpact", Color(1, 0.6, 0.2))
				damage_enemy(m, maxi(1, roundi(amt * rng.randf_range(0.9, 1.1))), Vector2i.ZERO))
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


## Cast-animatie van de caster; 'apply' draait op het vrijgavemoment, daarna spell_released.
## Eerst de kaart-cast (SomData.MAP_CAST, 24x32, loslaten op frame 2), anders cast6 (48x48, frame 4),
## zonder sheet of zonder node: meteen.
func _cast_then(caster_id: String, spell_id: String, apply: Callable) -> void:
	var n := node_of(caster_id)
	var done := func() -> void:
		apply.call()
		spell_released.emit(spell_id, caster_id)
	var circle := SomFx.tex(str(SomData.CAST_CIRCLE.get(caster_id, "")))
	match cast_kind(caster_id):
		"map":
			var mc_tex: Dictionary = map_cast_texs.get(caster_id, {})
			var sheet: Texture2D = mc_tex.get("sheet", null) as Texture2D
			var fx_tex: Texture2D = mc_tex.get("fx", null) as Texture2D
			var anim0: Node = _drive(SomFx.map_cast_anim(n, sheet, fx_tex, circle))
			anim0.hit.connect(done, CONNECT_ONE_SHOT)
		"cast6":
			var anim: Node = _drive(SomFx.cast6_anim(n, pose_tex(caster_id, "cast"), circle))
			anim.hit.connect(done, CONNECT_ONE_SHOT)
		_:
			done.call()


## Welke cast-animatie krijgt deze held? "map" (SomData.MAP_CAST, 24x32), anders "cast6" (48x48-sheet van
## 6 kolommen), anders "direct" (geen passende sheet of geen node: de spreuk komt meteen vrij).
func cast_kind(caster_id: String) -> String:
	if node_of(caster_id) == null:
		return "direct"
	if not map_cast_uit.has(caster_id) and map_cast_texs.has(caster_id):
		return "map"
	var t := pose_tex(caster_id, "cast")
	if t and t.get_width() == int(SomData.CAST6["frames"]) * int(SomData.CAST6["frame"][0]):
		return "cast6"
	return "direct"


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
	# Codex-boek (zoals de Codex-opdracht in Classic): vangen met een Leeg Boek, daarna een doel kiezen
	# Zoals andere verbruiksitems: bij 0 Lege Boeken geen ingang (geen 'x0' in de ring). De CODEX-knop blijft
	# zichtbaar zolang er pagina's zijn en meldt dan "No Blank Book left.".
	var books := GameState.item_count(SomCodex.CodexData.BOOK_ITEM)
	if SomCodex.shown() and books > 0:
		items.append({"kind": "codex", "id": "codex", "label": SomData.TXT_CODEX_ENTRY % books,
				"name": SomData.TXT_CODEX, "count": books})
	return {"items": items, "skills": skills, "magic": magic}


## Doelen voor het Codex-boek: vijanden (ook een baas, die dan weigert) binnen SPELL_RANGE, dichtstbij eerst,
## met de Classic-hint ("35%", "too strong", "won't fit", "Codex full").
func codex_targets() -> Array:
	var from := body()
	var list: Array = []
	for m in enemies.keys():
		if is_instance_valid(m) and center_of(m).distance_to(from) <= SomData.SPELL_RANGE:
			list.append(m)
	for m in room.monsters:
		if is_instance_valid(m) and bool(m.get("boss")) and not list.has(m) and center_of(m).distance_to(from) <= SomData.SPELL_RANGE:
			list.append(m)
	list.sort_custom(func(x, y): return center_of(x).distance_to(from) < center_of(y).distance_to(from))
	var out: Array = []
	for m in list:
		var nm: String = codex._name(m)
		out.append({"kind": "target", "id": str(m.monster_id), "target": m, "label": "%s %s" % [nm, codex.hint(m)], "name": nm})
	return out


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
				damage_enemy(m, physical_damage(atk, float(e["def"]), mult, rng),
						Vector2i(signi(roundi(away.x)), 0) if absf(away.x) >= absf(away.y) else Vector2i(0, signi(roundi(away.y))))
	return "%s uses %s!" % [member(hero_id).get("name", ""), sk["name"]]


func _say(text: String) -> void:
	last_text = text
	if hud:
		hud.toast(text)


const CoopAvatar := preload("res://scripts/coop/coop_avatar.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")


func setup_coop(session: Node, roster: Array, local_slot: int) -> void:
	coop_mode = true
	coop_local_slot = local_slot
	if session != null and "is_host" in session:
		coop_sim_host = bool(session.is_host)
	else:
		coop_sim_host = GameState.coop_is_host() and local_slot == Protocol.HOST_SLOT
	coop_ring_no_pause = true
	allies_enabled = false
	_remove_solo_party_bodies()
	_coop_slots.clear()
	_coop_lock_idx.clear()
	_coop_attack_cd.clear()
	_rebuild_enemy_order()
	_clear_coop_avatars()
	coop_sync_roster(roster)
	if not coop_sim_host:
		player.set_analog(func() -> Vector2: return Vector2.ZERO, SomData.MOVE_SPEED)


func coop_sync_roster(roster: Array) -> void:
	var seated: Dictionary = {}
	for row in roster:
		var slot := int(row.get("slot", Protocol.NO_SLOT))
		var cid := str(row.get("character_id", ""))
		if slot == Protocol.NO_SLOT or cid == "":
			continue
		seated[slot] = cid
	for slot in _coop_avatars.keys():
		if not seated.has(int(slot)):
			coop_deactivate_slot(int(slot))
	for slot in seated.keys():
		var cid: String = str(seated[slot])
		_coop_slots[int(slot)] = cid
		if int(slot) == coop_local_slot:
			active_id = cid
			_apply_player_sheet()
		else:
			_ensure_coop_avatar(int(slot), cid)
	_prune_coop_avatar_orphans(seated)


func _prune_coop_avatar_orphans(seated: Dictionary) -> void:
	var objects: Node = room.get_node("Objects")
	for c in objects.get_children():
		if not (c is CoopAvatar):
			continue
		var av: CoopAvatar = c as CoopAvatar
		if av.slot == coop_local_slot or not seated.has(av.slot):
			if _coop_avatars.get(av.slot) == av:
				_coop_avatars.erase(av.slot)
			av.queue_free()
			continue
		if not _coop_avatars.has(av.slot):
			_coop_avatars[av.slot] = av


func coop_deactivate_slot(slot: int) -> void:
	_coop_slots.erase(slot)
	if not _coop_avatars.has(slot):
		return
	var n: Node = _coop_avatars[slot]
	_coop_avatars.erase(slot)
	if is_instance_valid(n):
		n.queue_free()


func _remove_solo_party_bodies() -> void:
	for a in allies:
		if is_instance_valid(a):
			a.queue_free()
	allies.clear()
	if room == null:
		return
	var objects: Node = room.get_node_or_null("Objects")
	if objects == null:
		return
	for c in objects.get_children():
		if c is SomAlly:
			c.queue_free()
	var follower := objects.get_node_or_null("CodexFollower")
	if follower != null:
		follower.queue_free()


func _clear_coop_avatars() -> void:
	for slot in _coop_avatars.keys():
		coop_deactivate_slot(int(slot))
	var objects: Node = room.get_node("Objects")
	for c in objects.get_children():
		if c is CoopAvatar:
			c.queue_free()
	_coop_avatars.clear()


func _ensure_coop_avatar(slot: int, hero_id: String) -> void:
	_laad_held_cast(hero_id)
	if _coop_avatars.has(slot):
		var existing: CoopAvatar = _coop_avatars[slot] as CoopAvatar
		if is_instance_valid(existing):
			if existing.hero_id != hero_id:
				var tex := sheet_for(hero_id)
				existing.setup(slot, hero_id, tex)
			return
		_coop_avatars.erase(slot)
	var objects: Node = room.get_node("Objects")
	var named := objects.get_node_or_null("CoopAvatar_%d" % slot)
	if named is CoopAvatar:
		var reuse: CoopAvatar = named as CoopAvatar
		var tex := sheet_for(hero_id)
		reuse.setup(slot, hero_id, tex)
		_coop_avatars[slot] = reuse
		return
	_spawn_coop_avatar(slot, hero_id)


func _spawn_coop_avatar(slot: int, hero_id: String) -> void:
	var av: CoopAvatar = CoopAvatar.new()
	av.name = "CoopAvatar_%d" % slot
	var tex := sheet_for(hero_id)
	av.setup(slot, hero_id, tex)
	room.get_node("Objects").add_child(av)
	av.position = player.position + Vector2(slot * 12, 0)
	_coop_avatars[slot] = av


## Headless/tests: remote CoopAvatar-nodes (niet de lokale speler-body).
func coop_remote_avatar_count() -> int:
	_purge_invalid_coop_avatars()
	var n := 0
	for slot in _coop_avatars.keys():
		var av: Variant = _coop_avatars[slot]
		if is_instance_valid(av):
			n += 1
	return n


func coop_avatar_nodes_in_scene() -> int:
	var n := 0
	for c in room.get_node("Objects").get_children():
		if c is CoopAvatar:
			n += 1
	return n


func coop_seated_player_count(roster: Array) -> int:
	var n := 0
	for row in roster:
		if str(row.get("character_id", "")) != "" and int(row.get("slot", Protocol.NO_SLOT)) != Protocol.NO_SLOT:
			n += 1
	return n


func _party_sprite_path_set() -> Dictionary:
	var out := {}
	for p in sheets.values():
		if p is Texture2D:
			var path: String = (p as Texture2D).resource_path
			if path != "":
				out[path] = true
	for id in SomData.SHEETS.keys():
		out[str(SomData.SHEETS[id])] = true
	if sheets.has("dennis"):
		var dax: Texture2D = sheets["dennis"] as Texture2D
		if dax != null and dax.resource_path != "":
			out[dax.resource_path] = true
	return out


func _sprite_uses_party_texture(spr: Node, paths: Dictionary) -> bool:
	var tex: Texture2D = null
	if spr is Sprite2D:
		tex = (spr as Sprite2D).texture
	elif spr is AnimatedSprite2D:
		var fr := (spr as AnimatedSprite2D).sprite_frames
		if fr != null and fr.get_animation_names().size() > 0:
			tex = fr.get_frame_texture(fr.get_animation_names()[0], 0)
	if tex == null:
		return false
	var path: String = tex.resource_path
	if path != "" and paths.has(path):
		return true
	for t in sheets.values():
		if tex == t:
			return true
	return false


func _count_party_texture_sprites(node: Node, paths: Dictionary, under_canvas: bool) -> int:
	if node is CanvasLayer:
		under_canvas = true
	if node is SomArena:
		# HUD/ring/codex hangen onder SomArena, niet meetellen.
		under_canvas = true
	var n := 0
	if not under_canvas and (node is Sprite2D or node is AnimatedSprite2D):
		if _sprite_uses_party_texture(node, paths):
			n += 1
	for ch in node.get_children():
		n += _count_party_texture_sprites(ch, paths, under_canvas)
	return n


## Wereld-sprites met party-kaarttexturen (speler + CoopAvatar; geen HUD/FX).
func coop_party_texture_sprite_count() -> int:
	if room == null:
		return 0
	return _count_party_texture_sprites(room, _party_sprite_path_set(), false)


func coop_expected_remote_avatars(roster: Array) -> int:
	var n := 0
	for row in roster:
		var slot := int(row.get("slot", Protocol.NO_SLOT))
		var cid := str(row.get("character_id", ""))
		if slot == Protocol.NO_SLOT or cid == "" or slot == coop_local_slot:
			continue
		n += 1
	return n


func _purge_invalid_coop_avatars() -> void:
	for slot in _coop_avatars.keys():
		if not is_instance_valid(_coop_avatars[slot]):
			_coop_avatars.erase(slot)


func coop_avatar_seats_unique() -> bool:
	_purge_invalid_coop_avatars()
	var seats := {}
	for slot in _coop_avatars.keys():
		if seats.has(slot):
			return false
		var av: CoopAvatar = _coop_avatars[slot] as CoopAvatar
		if not is_instance_valid(av) or av.slot != int(slot):
			return false
		seats[slot] = true
	for c in room.get_node("Objects").get_children():
		if c is CoopAvatar and not _coop_avatar_tracked(c):
			return false
	return true


func _coop_avatar_tracked(node: Node) -> bool:
	for av in _coop_avatars.values():
		if av == node:
			return true
	return false


func _rebuild_enemy_order() -> void:
	_enemy_order.clear()
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_order.append(m)


func _coop_body(slot: int) -> Node2D:
	if slot == coop_local_slot:
		return player
	if _coop_avatars.has(slot):
		var av: Node2D = _coop_avatars[slot] as Node2D
		if not is_instance_valid(av):
			_coop_avatars.erase(slot)
			return null
		return av
	return null


func coop_poll_local_input() -> Dictionary:
	if not coop_mode or coop_local_slot < 0:
		return {}
	var stick := analog_dir()
	var buttons := 0
	if Input.is_action_just_pressed("interact") and not _attack_suppressed():
		buttons |= Codec.BTN_ATTACK
	if Input.is_action_just_pressed(RING_ACTION):
		buttons |= Codec.BTN_RING
	var lock_idx := -1
	if target_lock and target_lock.locked_enemy() != null:
		lock_idx = _enemy_index(target_lock.locked_enemy())
	return {"stick": stick, "buttons": buttons, "lock_idx": lock_idx}


func coop_host_step(inputs: Array, dt: float) -> void:
	if not coop_sim_host:
		return
	if target_lock:
		target_lock.tick(dt)
	for inp in inputs:
		_apply_coop_input(inp, dt)
	swing_lock = maxf(0.0, swing_lock - dt)
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, dt)
		else:
			enemies.erase(m)
	_tick_zones()
	_sim_world(dt)
	_rebuild_enemy_order()


func _apply_coop_input(inp: Dictionary, dt: float) -> void:
	var slot := int(inp.get("slot", Protocol.NO_SLOT))
	if not _coop_slots.has(slot):
		return
	var body: Node2D = _coop_body(slot)
	if body == null:
		return
	var stick: Vector2 = inp.get("stick", Vector2.ZERO)
	if stick.length_squared() > 0.01:
		var dir := stick.normalized()
		var hid := str(_coop_slots.get(slot, ""))
		var slow := _zone_slow_mult_for_id(hid) if hid != "" else 1.0
		body.position += dir * SomData.MOVE_SPEED * slow * dt
		if body == player:
			body.facing = SomMove.facing_for(dir, body.facing)
	var lock_i := int(inp.get("lock_idx", -1))
	if lock_i >= 0:
		_coop_lock_idx[slot] = lock_i
	var buttons := int(inp.get("buttons", 0))
	if buttons & Codec.BTN_RING and slot == coop_local_slot:
		open_ring()
	var cd := float(_coop_attack_cd.get(slot, 0.0))
	cd = maxf(0.0, cd - dt)
	_coop_attack_cd[slot] = cd
	if buttons & Codec.BTN_ATTACK and cd <= 0.0:
		var hid := str(_coop_slots[slot])
		if is_alive(hid):
			_swing(hid, body, charge_mult(charge if slot == coop_local_slot else 1.0))
			_coop_attack_cd[slot] = 0.35


func _enemy_index(m: Node) -> int:
	if not _enemy_order.has(m):
		_rebuild_enemy_order()
	return _enemy_order.find(m)


func coop_encode_snapshot(tick: int) -> PackedByteArray:
	var players: Array = []
	for slot in _coop_slots.keys():
		var body: Node2D = _coop_body(int(slot))
		if body == null:
			continue
		var hid := str(_coop_slots[slot])
		var h := member(hid)
		players.append({
			"slot": int(slot),
			"x": int(body.position.x),
			"y": int(body.position.y),
			"face": _coop_face_bits(body.facing),
			"frame": 0,
			"hp": int(h.get("hp", 0)),
			"mp": int(h.get("mp", 0)),
			"flags": Protocol.FLAG_RING_OPEN if ring.is_open and int(slot) == coop_local_slot else 0,
		})
	var elist: Array = []
	_rebuild_enemy_order()
	for i in _enemy_order.size():
		var m: Node = _enemy_order[i]
		if not is_instance_valid(m) or not enemies.has(m):
			continue
		var e: Dictionary = enemies[m]
		var tid := str(e.get("target", ""))
		var tslot := _slot_for_hero(tid)
		if tslot == Protocol.NO_SLOT:
			tslot = Protocol.HOST_SLOT
		var base := {
			"idx": i,
			"x": int(center_of(m).x),
			"y": int(center_of(m).y),
			"hp": int(e.get("hp", 0)),
			"pose": 0,
			"target_slot": tslot,
		}
		var tg: TelegraphAttack = e.get("tg", null)
		elist.append(TelegraphSnapshot.merge_enemy_row(base, tg, tslot))
	return Codec.pack_snapshot(tick, players, elist, combat_zones.wire_rows())


func apply_coop_snapshot(snap: Dictionary) -> void:
	_coop_snap = snap
	if coop_sim_host:
		return
	for row in snap.get("players", []):
		var slot := int(row.get("slot", Protocol.NO_SLOT))
		var body: Node2D = _coop_body(slot)
		if body == null:
			continue
		var pos := Vector2(float(row.get("x", 0)), float(row.get("y", 0)))
		var face_i := int(row.get("face", 0))
		var face := Vector2i(1, 0) if face_i == 2 else Vector2i(-1, 0) if face_i == 0 else Vector2i(0, 1)
		if body is CoopAvatar:
			(body as CoopAvatar).place(pos, face)
		else:
			body.position = pos
			body.facing = face
		var hid := str(_coop_slots.get(slot, ""))
		if not hid.is_empty():
			var h := member(hid)
			if not h.is_empty():
				h["hp"] = int(row.get("hp", h["hp"]))
				h["mp"] = int(row.get("mp", h["mp"]))
	for row in snap.get("enemies", []):
		var idx := int(row.get("idx", -1))
		if idx < 0 or idx >= _enemy_order.size():
			continue
		var m: Node = _enemy_order[idx]
		if not is_instance_valid(m) or not enemies.has(m):
			continue
		var e: Dictionary = enemies[m]
		e["hp"] = int(row.get("hp", e["hp"]))
		var cx := float(row.get("x", 0))
		var cy := float(row.get("y", 0))
		m.position = Vector2(cx, cy) - Vector2(0, center_of(m).y - m.position.y)
		if not coop_sim_host and room != null:
			TelegraphSnapshot.apply_row_to_enemy(e, row, room.room_id, room.tier())
	if not coop_sim_host:
		combat_zones.apply_wire_rows(snap.get("zones", []))
		_sync_telegraph_draw()


func coop_snapshot() -> Dictionary:
	return _coop_snap


static func _coop_face_bits(f: Vector2i) -> int:
	if f.x > 0:
		return 2
	if f.x < 0:
		return 0
	if f.y > 0:
		return 3
	return 1
