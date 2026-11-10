class_name SomArena
extends Node
## SoM-PROEF: realtime gevecht (Secret of Mana-stijl) in één DungeonRoom. Wordt door
## dungeon_room.gd aangemaakt als SomData.room_enabled(...) waar is; anders bestaat hij niet en
## loopt alles turn-based zoals altijd. Bazen zonder BossScript starten turn-based; met BossScript (D3)
## kunnen ze in Action via register().
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
## Online co-op: de run eindigt pas als elke stoel down is. "wipe" gaat later naar het resultaatscherm.
signal coop_run_result(kind: String)

const SomData := preload("res://scripts/data/som_data.gd")
const OnlineDlsFloor := preload("res://scripts/online/online_dls_floor.gd")
const BossScript := preload("res://scripts/som/boss_script.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const GolemStoryWin := preload("res://scripts/som/golem_story_win.gd")
const GolemBossView := preload("res://scripts/som/golem_boss_view.gd")
const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const PageWardenView := preload("res://scripts/som/page_warden_view.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")
const ThreatTable := preload("res://scripts/som/threat_table.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const DungeonRooms := preload("res://scripts/data/dungeon_rooms.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const DamageCalc := preload("res://scripts/battle/damage_calc.gd")
const SomHud := preload("res://scripts/som/som_hud.gd")
const SomRing := preload("res://scripts/som/som_ring.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const SomMove := preload("res://scripts/som/som_move.gd")
const SomSlide := preload("res://scripts/som/som_slide.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")
const SomCodex := preload("res://scripts/som/som_codex.gd")
const SomTargetLock := preload("res://scripts/som/som_target_lock.gd")
const SomActionAttacks := preload("res://scripts/data/som_action_attacks.gd")
const TelegraphAttack := preload("res://scripts/som/telegraph_attack.gd")
const SomChainData := preload("res://scripts/data/som_chain_data.gd")
const SomHeavyData := preload("res://scripts/data/som_heavy_data.gd")
const SomFeelData := preload("res://scripts/data/som_feel_data.gd")
const SomShakeScript := preload("res://scripts/som/som_shake.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphLayer := preload("res://scripts/som/telegraph_layer.gd")
const MapSprite := preload("res://scripts/map_sprite.gd")
const CombatZones := preload("res://scripts/som/combat_zones.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const RING_ACTION := "som_ring"
const SWITCH_ACTION := "som_switch"
const DODGE_ACTION := "som_dodge"

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
## Client-only screenshake (F4).
var shake: Node
var telegraph_layer: TelegraphLayer
var combat_zones := CombatZones.new()
var combat_roots := CombatRoots.new()
var combat_stamina := CombatStamina.new()
var _dodge_roll_ticks: Dictionary = {}
var _dodge_cd_ticks: Dictionary = {}
var _dodge_dir: Dictionary = {}
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
## Wipe alleen als elke meewerkende stoel down is. Solo blijft arena.down + _party_down.
var coop_wiped := false
var coop_wipe_tick := -1
var _coop_tick := 0
var _coop_down: Dictionary = {}
var coop_ring: CoopReviveRing
var _coop_slots: Dictionary = {}
var _coop_avatars: Dictionary = {}
## Online stoelen (M6). Null = LAN/solo; dan blijft allies_enabled zoals het was.
var seat_controller = null
var _ai_bodies: Dictionary = {}
var _coop_lock_idx: Dictionary = {}
var _enemy_order: Array = []
var _coop_attack_cd: Dictionary = {}
## T29: per co-op-slot swing-lock (s), host-autoritatief; zelfde gate als swing_lock in single-player.
var _coop_swing_lock: Dictionary = {}
const COOP_MIN_SWING_LOCK := 0.35
var _coop_snap: Dictionary = {}
## Kaartsprites en aanvalsanimaties per held-id (geladen in setup; ontbreekt = placeholder).
var sheets := {}
var attack_texs := {}
## T26: eigen hit2/finisher-sheets per held: id -> {"hit2": Texture2D, "finisher": Texture2D}.
var step_texs := {}
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
## 3-slag aanvalsketen (SomChainData, alleen Action), per actor (held-id: speler, bondgenoot-AI, co-op-peer):
## {"next": 0 hit1 / 1 hit2 / 2 finisher, "window": venster-ticks (0 = dicht), "state": laatste staat, "last": laatste stap}.
## Elke actor heeft een eigen keten; host-autoritatief (alleen sim_step / coop_host_step tellen).
var chains: Dictionary = {}
## Opgeladen zware slag (SomHeavyData, alleen Action), per actor: held-id -> vastgehouden ticks sinds het indrukken.
var heavy_hold: Dictionary = {}
## Bondgenoot-AI die nu oplaadt: held-id -> doelniveau.
var _ai_heavy: Dictionary = {}
## Tests: aantal zware slagen en het niveau/de staat van de laatste.
var heavy_releases := 0
var last_heavy_level := 0
## Snelkoppelingen naar de keten van de bestuurde held (tests/HUD).
var chain_next: int:
	get:
		return chain_of(active_id)["next"]
var chain_window_ticks: int:
	get:
		return chain_of(active_id)["window"]
var chain_state: String:
	get:
		return chain_of(active_id)["state"]
var chain_last_step: int:
	get:
		return chain_of(active_id)["last"]
## Held waarvan de keten loopt (bestuurde held), "" = geen open keten.
var chain_owner: String:
	get:
		var c: Dictionary = chain_of(active_id)
		return active_id if int(c["next"]) != 0 or int(c["window"]) != 0 else ""
## Tests: aantal resets (venster verlopen / dodge / held gewisseld) en de laatste hitstop/knockback.
var chain_resets := 0
var last_hitstop_ticks := 0
var last_knockback_tiles := 0
var b_casts := 0
## Alleen voor tests/vergelijk-shots: held-ids waarvoor de kaart-cast uit staat (dan cast6 of direct).
var map_cast_uit: Array = []

## Eén seeded RNG voor alle toeval in dit gevecht (schade-spreiding, drops, achtervolg-start, bondgenoot-keuze,
## Codex-vangkans). Standaard willekeurig (randomize, zelfde gedrag als de globale randf); seed_rng(n) maakt een
## gevecht reproduceerbaar (--combatrngtest, COMBAT_DESIGN.md §16).
var rng := RandomNumberGenerator.new()
var rng_seed := 0

## D3 PR C: arena-hook voor de realtime Golem (kennis_beest, WM1). Standaard AAN (Dennis): in GOLEM_RT_ROOMS
## vecht de Golem realtime; zet false om turn-based te forceren (tests). Alleen GOLEM_RT_ROOMS.
static var golem_rt_enabled := true
const GOLEM_RT_ROOMS := ["archief_golemhal"]
## Wij registreerden GolemBoss in BossScript.REGISTRY (ensure_registered) -> bij _exit_tree weer weg.
var _golem_registered_here := false
## Event-log van de Golem-hook (tests/HUD): {tick, type, ...} uit GolemFight.take_events().
var golem_events: Array = []
## Tests: zette de laatste Golem-winst in deze arena de verhaal-beat (true) of was hij al gedaan (false)?
var golem_story_fired := false
## Tests: aantal keer dat _golem_strike draaide (één per attack_hit).
var golem_strike_count := 0
## Tests: aantal hit_member-aanroepen vanuit _golem_strike (schade alleen daar).
var golem_strike_hit_member_count := 0
## M9a: Page Warden alleen in online co-op (coop_mode + baas-sleutel 10). Solo blijft turn-based.
var _page_registered_here := false
var page_events: Array = []
## Log voor tests. Oudere entries vallen weg; de verwerking zelf blijft voor elke event.
const PAGE_EVENT_CAP := 64
var page_threat: ThreatTable = null
var page_strike_count := 0
var page_strike_hits := 0
var _page_range_scratch: Array = []


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
		_laad_step_sheets(id)
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
		shake = SomShakeScript.new()
		shake.name = "SomShake"
		shake.setup(cam)
		add_child(shake)
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
	for h in GameState.party:
		combat_stamina.init_member(str(h.get("id", "")))


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
	for pair in [[RING_ACTION, KEY_TAB], [SWITCH_ACTION, KEY_C], [DODGE_ACTION, KEY_X]]:
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
	# Online DLS: schaal op het "floor"-veld (eff). Solo en de WM1-sandbox gaan hier niet langs.
	# room is een Node: Object.get heeft één argument. null == true is false, zonder bool(null).
	if coop_mode and room != null and room.get("online_dls") == true:
		return OnlineDlsFloor.action_stats(m, self)
	var id: String = m.enemy_id
	var base: Dictionary = GameData.ENEMIES.get(id, {})
	if base.is_empty():
		base = BerggrotData.enemy(id)
	var d := base.duplicate(true)
	var t: int = room.tier()
	if t > 0 and not bool(d.get("unique", false)) and d.has("max_hp"):
		var in_archief: bool = DungeonRooms.ROOMS.has(room.room_id)
		d = GameData.apply_archief_tier(d, t) if in_archief else GameData.apply_tier(d, t)
	if m.boss and BossScript.has_script(id):
		var n: int = GameState.party.size() if GameState.party.size() > 0 else 1
		return SomData.action_boss_stats(d, n)
	return SomData.apply_action_area(d, room.room_id, t)      # alleen Action; bazen/uniek ongewijzigd


## D3 PR C: geldt de realtime Golem-hook voor dit monster in deze kamer?
func golem_rt_applies(m: Node) -> bool:
	return golem_rt_enabled and m != null and bool(m.boss) and str(m.enemy_id) == GolemBoss.ENEMY_ID \
			and room != null and "room_id" in room and GOLEM_RT_ROOMS.has(str(room.room_id))


## M9a: Page Warden realtime alleen in online co-op, baas-sleutel 10 (niet The Voice op 99).
## Zonder coop_mode blijft de Classic-baas turn-based (geen script op "papiergeest").
func page_warden_rt_applies(m: Node) -> bool:
	if not coop_mode or m == null or not is_instance_valid(m):
		return false
	if not bool(m.get("boss")):
		return false
	if str(m.get("enemy_id")) != PageWardenBoss.ENEMY_ID:
		return false
	return int(m.get("floor_nr")) == PageWardenBoss.BOSS_KEY


## GolemFight van een geregistreerde Golem (of null).
func golem_fight_of(m: Node) -> GolemFight:
	if not enemies.has(m):
		return null
	return enemies[m].get("golem", null)


func _exit_tree() -> void:
	for m in enemies.keys():
		if enemies[m].get("golem", null) != null:
			_golem_clear_visuals(m, enemies[m])
		if enemies[m].get("page_warden", null) != null or enemies[m].get("page_view", null) != null:
			_page_clear_visuals(m, enemies[m])
	if _golem_registered_here:
		GolemBoss.unregister()
		_golem_registered_here = false
	if _page_registered_here:
		PageWardenBoss.unregister()
		_page_registered_here = false
		page_threat = null


func register(m: Node) -> void:
	if m == null or enemies.has(m):
		return
	var eid := str(m.enemy_id)
	var golem_rt := golem_rt_applies(m)
	if golem_rt and not BossScript.has_script(eid):
		GolemBoss.ensure_registered()
		_golem_registered_here = true
	# Page Warden: alleen co-op + sleutel 10. Zonder die tak blijft de voorwaarde hieronder
	# byte-gelijk aan de oude baas-check (geen script → niet in Action).
	var page_rt := page_warden_rt_applies(m)
	if page_rt and not BossScript.has_script(PageWardenBoss.SCRIPT_ID):
		PageWardenBoss.ensure_registered()
		_page_registered_here = true
	if m.boss and not page_rt and not BossScript.has_script(eid):
		return
	var d := enemy_stats(m)
	if d.is_empty():
		return
	m.moves = false      # zijn eigen willekeurige wandeling uit; de AI hieronder stuurt
	var entry := {"hp": int(d.get("max_hp", 1)), "max_hp": int(d.get("max_hp", 1)), "atk": int(d.get("atk", 1)),
			"def": int(d.get("def", 0)), "exp": int(d.get("exp", 0)), "gold": int(d.get("gold", 0)),
			"drops": d.get("drops", []), "data": d, "cd": 0.6, "tele": 0.0, "chase": rng.randf() * SomData.CHASE_INTERVAL,
			"flash": 0.0, "target": ""}
	if golem_rt:
		# Fases, kern-venster, schadeplafond per fasedrempel en 90 ticks fasewissel: GolemFight (PR B).
		var fseed := rng_seed if rng_seed != 0 else hash(str(room.room_id))
		var fight := GolemFight.new(int(entry["max_hp"]), fseed)
		entry["golem"] = fight
		entry["hp"] = fight.hp()
		# Visuele telegraaf alleen (TelegraphLayer). Schade blijft uitsluitend in _golem_strike.
		entry["tg"] = TelegraphAttack.new()
		enemies[m] = entry
		_ensure_golem_view(m, entry)
		return
	if page_rt:
		# Stats uit baas-sleutel 10, niet uit de kamertier of de effectieve verdieping.
		var st := PageWardenBoss.stats_for_seats(_page_seat_count())
		entry["hp"] = int(st["max_hp"])
		entry["max_hp"] = int(st["max_hp"])
		entry["atk"] = int(st["atk"])
		entry["def"] = int(st["def"])
		entry["exp"] = int(st.get("exp", entry["exp"]))
		entry["gold"] = int(st.get("gold", entry["gold"]))
		entry["data"] = st
		entry["tg"] = TelegraphAttack.new()
		enemies[m] = entry
		# Beeld op host én gast. Alleen de host maakt het gevecht (en verbruikt daar rng.randi).
		_ensure_page_view(m, entry)
		if coop_sim_host:
			if page_threat == null:
				page_threat = ThreatTable.new()
			# Seed uit de arena-RNG (geen globale randi). Zelfde arena-seed → zelfde baas.
			var fight := PageWardenFight.new(int(entry["max_hp"]), rng.randi())
			entry["page_warden"] = fight
			entry["hp"] = fight.hp()
		return
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
	if shake != null:
		shake.stop()
	var nxt := to if to != "" else next_alive(active_id)
	if nxt == "" or nxt == active_id or not is_alive(nxt):
		return ""
	var a := ally_of(nxt)
	if a == null:
		return ""
	if a.in_wall():
		a._teleport()      # anders belandt de bestuurde held in de muur en kan hij niet meer lopen
	combat_roots.clear_member(active_id)
	combat_stamina.clear_member(active_id)
	chain_reset(active_id)       # wissel: venster en keten van beide helden meteen dicht
	chain_reset(nxt)
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
	if _dodge_roll_ticks.get(active_id, 0) > 0:
		return _dodge_dir.get(active_id, Vector2.ZERO)
	var base := Vector2.ZERO
	if forced_joy != Vector2.ZERO:
		base = SomMove.joy_to_dir(forced_joy)
	elif touch and "joy_raw" in touch and touch.joy_raw != Vector2.ZERO:
		base = SomMove.joy_to_dir(touch.joy_raw)
	else:
		base = SomMove.keys_to_dir()
	if combat_roots.blocks_movement(active_id):
		return Vector2.ZERO
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
var _pending := {"switch": false, "attack": false, "cast": false, "dodge": false}


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
		_pending = {"switch": false, "attack": false, "cast": false, "dodge": false}
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
	_pending["hold"] = Input.is_action_pressed("interact")      # vasthouden = opladen (SomHeavyData)
	if Input.is_action_just_pressed(DODGE_ACTION):
		_pending["dodge"] = true
	if Input.is_action_just_pressed("cancel") and Engine.get_process_frames() != ring.closed_frame:
		_pending["cast"] = true
	if player:
		player.analog_speed = _analog_speed()
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
	_tick_chain()
	if _pending["switch"]:
		_pending["switch"] = false
		switch_hero()
	if _pending["dodge"]:
		_pending["dodge"] = false
		try_active_dodge(active_id, _dodge_facing_dir(active_id))
	b_cast_cd = maxf(0.0, b_cast_cd - dt)
	if _pending["attack"] and SomChainData.TAP_GATE and swing_lock > 0.0:
		_pending["attack"] = false      # F5: tik tijdens eigen slag-animatie telt niet
	if _pending["attack"]:
		_pending["attack"] = false
		attack()
		if Settings.action_battles() and is_alive(active_id):
			heavy_hold[active_id] = 0          # indrukken start de vasthoud-teller
	heavy_tick(active_id, bool(_pending.get("hold", false)), player, 1.0)
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
			_tick_ally_dodge_ai(a)
		_tick_ally_heavy()
	_tick_stamina_and_dodge()
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, dt)
		else:
			enemies.erase(m)
	_tick_zones()
	_tick_roots()
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
	var step := _chain_begin_hit(active_id)
	var mult := charge_mult(charge)
	if step > 0:
		mult = maxf(mult, SomChainData.FOLLOWUP_MIN_METER)   # F5: vervolgslag binnen venster
	if step >= 0:
		mult *= SomChainData.damage_mult(step)
	_full_swing = charge >= 1.0
	charge = 0.0
	swing_lock = _anim_seconds_def(active_id, _attack_def(active_id, step))
	return _swing(active_id, player, mult, step)


## Slag van elke actor via de keten (bondgenoot-AI, co-op-peer). base_mult = meter/vaste multiplier.
func chain_swing(id: String, n: Node2D, base_mult: float, extra_window := 0) -> int:
	var step := _chain_begin_hit(id, extra_window)
	var mult := base_mult * (SomChainData.damage_mult(step) if step >= 0 else 1.0)
	return _swing(id, n, mult, step)


# ---------------------------------------------------------------- aanvalsketen (SomChainData)
## Keten-stap voor de slag die nu begint (-1 = geen keten: Classic-stijl).
## Ketenstaat van één actor (alleen-lezen kopie als hij nog geen keten heeft).
func chain_of(id: String) -> Dictionary:
	return chains.get(id, {"next": 0, "window": 0, "state": "", "last": -1})


func _chain_begin_hit(id: String, extra_window := 0) -> int:
	if not Settings.action_battles():
		chains.erase(id)
		return -1
	var c: Dictionary = chain_of(id)
	var step := SomChainData.clamp_step(int(c["next"]))
	c["last"] = step
	c["state"] = SomChainData.state_for(step)
	c["next"] = 0 if SomChainData.is_finisher(step) else step + 1
	# venster telt na het einde van de slag-animatie; na de finisher begint de keten opnieuw
	c["window"] = 0 if SomChainData.is_finisher(step) \
			else ceili(_anim_seconds_def(id, _attack_def(id, step)) / TICK_DT - 0.0001) + SomChainData.CHAIN_WINDOW_TICKS + extra_window
	chains[id] = c
	return step


## Venster van elke actor aftellen op de vaste stap (vaste volgorde: gesorteerde ids); verlopen = hit1.
func _tick_chain() -> void:
	var ids: Array = chains.keys()
	ids.sort()
	for id in ids:
		var c: Dictionary = chains[id]
		if int(c["window"]) <= 0:
			continue
		c["window"] = int(c["window"]) - 1
		if int(c["window"]) == 0:
			chain_reset(str(id))


# ---------------------------------------------------------------- zware slag (SomHeavyData)
## Eén tick vasthouden/loslaten voor actor 'id' (alleen als het indrukken een teller startte).
## Loslaten op niveau >= 1 = zware slag. Geeft het niveau van een losgelaten zware slag (0 = geen).
func heavy_tick(id: String, held: bool, n: Node2D, base_mult: float) -> int:
	if not heavy_hold.has(id):
		return 0
	if not Settings.action_battles() or not is_alive(id) or n == null:
		heavy_hold.erase(id)
		return 0
	if held:
		heavy_hold[id] = mini(int(heavy_hold[id]) + 1, SomHeavyData.LEVEL_TICKS[SomHeavyData.MAX_LEVEL - 1])
		return 0
	var lv := SomHeavyData.level_for(int(heavy_hold[id]))
	heavy_hold.erase(id)
	if lv < 1:
		return 0
	_heavy_release(id, n, base_mult, lv)
	return lv


func _heavy_release(id: String, n: Node2D, base_mult: float, lv: int) -> void:
	chain_reset(id)              # na een zware slag begint de keten weer bij hit1
	heavy_releases += 1
	last_heavy_level = lv
	var mult := base_mult * SomHeavyData.damage_mult(lv)
	if id == active_id:
		swing_lock = _anim_seconds_def(id, _attack_def(id, SomChainData.STEP_FINISHER))
	_swing(id, n, mult, -1, lv)


## Laadt actor 'id' nu op (vastgehouden voorbij HOLD_START_TICKS)?
func heavy_charging(id: String) -> bool:
	return heavy_hold.has(id) and SomHeavyData.charging(int(heavy_hold[id]))


func heavy_level(id: String) -> int:
	return SomHeavyData.level_for(int(heavy_hold.get(id, 0))) if heavy_hold.has(id) else 0


## Loopsnelheid-factor (1.0, of SomHeavyData.MOVE_MULT tijdens het opladen).
func heavy_move_mult(id: String) -> float:
	return SomHeavyData.MOVE_MULT if heavy_charging(id) else 1.0


func heavy_cancel(id: String) -> void:
	heavy_hold.erase(id)
	_ai_heavy.erase(id)


## Bondgenoot-AI: houdt vast tot het doelniveau en laat dan los (vaste volgorde: gesorteerde ids).
func _tick_ally_heavy() -> void:
	var ids: Array = _ai_heavy.keys()
	ids.sort()
	for id in ids:
		var a: Node2D = ally_of(str(id))
		if a == null or not heavy_hold.has(id):
			_ai_heavy.erase(id)
			heavy_hold.erase(id)
			continue
		var held := SomHeavyData.level_for(int(heavy_hold[id])) < int(_ai_heavy[id])
		if not held:
			_ai_heavy.erase(id)
		heavy_tick(str(id), held, a, 1.0)


## Bondgenoot-AI: tijd voor de volgende ketenslag? Venster open, eigen animatie klaar en
## SomChainData.ALLY_FOLLOWUP_TICKS in het venster gewacht (deterministisch, geen toeval).
func chain_wants_followup(id: String) -> bool:
	var c: Dictionary = chain_of(id)
	var w := int(c["window"])
	return int(c["next"]) > 0 and w > 0 and w <= SomChainData.CHAIN_WINDOW_TICKS - SomChainData.ALLY_FOLLOWUP_TICKS


## Keten terug naar hit1 (venster verlopen, dodge, held gewisseld, gevecht klaar).
## id "" = de bestuurde held; "*" = alle actors.
func chain_reset(id := "") -> void:
	if id == "*":
		var ids: Array = chains.keys()
		for k in ids:
			chain_reset(str(k))
		return
	var hid := active_id if id == "" else id
	var c: Dictionary = chain_of(hid)
	if int(c["next"]) != 0 or int(c["window"]) != 0:
		chain_resets += 1
	chains.erase(hid)


## Animatie-definitie van een slag (step -1 = de gewone slag, ongewijzigd).
func _attack_def(id: String, step: int) -> Dictionary:
	var base: Dictionary = SomData.ATTACK_ANIMS.get(id, {})
	if step < 0 or base.is_empty():
		return base
	return SomChainData.anim_def(base, step, id)


## T26: laad de eigen hit2/finisher-sheets van held 'id' (SomChainData.STEP_SHEETS); ontbreekt er een: terugval.
func _laad_step_sheets(id: String) -> void:
	for step in [SomChainData.STEP_HIT2, SomChainData.STEP_FINISHER]:
		var path := SomChainData.step_sheet(id, step)
		if path != "":
			if not step_texs.has(id):
				step_texs[id] = {}
			step_texs[id][SomChainData.state_for(step)] = load(path)


## Textuur voor de slag van held 'id' met animatie-definitie 'def' (eigen stap-sheet of <held>_attack.png).
func attack_tex_for(id: String, def: Dictionary) -> Texture2D:
	var st := str(def.get("chain_state", ""))
	if def.has("sheet") and step_texs.get(id, {}).has(st):
		return step_texs[id][st]
	return attack_texs.get(id)


func _anim_seconds_def(id: String, def: Dictionary) -> float:
	# T29: zonder attack-sheet niet 0 teruggeven (dan valt de gate weg): def["ms"], anders SomData.ATTACK_MS.
	var ms: Array = def.get("ms", [])
	if ms.is_empty() and not attack_texs.has(id):
		ms = SomData.ATTACK_MS
	var tot := 0.0
	for v in ms:
		tot += float(v)
	return tot / 1000.0


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
func _swing(id: String, n: Node2D, mult: float, step := -1, heavy := 0) -> int:
	if attack_texs.has(id):
		# zware slag: placeholder = de finisher-placeholder (TODO RPG ART: <held>_heavy.png)
		var def := _attack_def(id, SomChainData.STEP_FINISHER if heavy > 0 else step)
		var anim: Node = _drive(SomFx.attack_anim(n, attack_tex_for(id, def), def))
		if heavy > 0:
			anim.set_meta("chain_state", SomHeavyData.state_for(heavy))
		elif step >= 0:
			anim.set_meta("chain_state", SomChainData.state_for(step))
		# bondgenoot: de slag gaat de kant op waar hij begon (zijn AI kan tijdens de animatie al draaien)
		var face0: Vector2i = n.facing
		anim.hit.connect(func() -> void:
			if id != active_id and is_instance_valid(n):
				n.facing = face0
			_land(id, n, mult, step, heavy), CONNECT_ONE_SHOT)
		return -1
	return _land(id, n, mult, step, heavy)


func _land(id: String, n: Node2D, mult: float, step := -1, heavy := 0) -> int:
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
			var stagger := mult >= 1.0
			var tiles := 1
			var stop := 0
			if step >= 0:
				stagger = stagger or (SomChainData.is_finisher(step) and SomChainData.FINISHER_ALWAYS_STAGGERS)
				tiles = SomChainData.knockback_tiles(step)
				stop = SomChainData.hitstop_ticks(step)
			if heavy > 0:
				stagger = stagger or SomHeavyData.ALWAYS_STAGGERS
				tiles = SomHeavyData.knockback_tiles(heavy)
				stop = SomHeavyData.hitstop_ticks(heavy)
			var num_color := SomFeelData.COL_NORMAL
			var num_scale := 1.0
			var shake_kind := ""
			if SomFeelData.ENABLED:
				if heavy > 0:
					num_color = SomFeelData.COL_HEAVY
					num_scale = SomFeelData.SCALE_HEAVY2 if heavy >= 2 else 1.0
					shake_kind = "heavy2" if heavy >= 2 else "heavy1"
				elif step >= 0 and SomChainData.is_finisher(step):
					num_color = SomFeelData.COL_FINISHER
					shake_kind = "finisher"
			damage_enemy(m, physical_damage(atk, float(e["def"]), mult, rng), Vector2i(roundi(f.x), roundi(f.y)), stagger, tiles, stop,
					num_color, num_scale)
			if shake_kind != "" and _feel_local_hero(id) and shake != null:
				shake.kick(shake_kind)
			hits += 1
	swing_landed.emit(id, hits)
	SessieLog.actie_slag(id, hits)
	return hits


## Bondgenoot slaat (volle meter; som_ally.gd heeft hem al naar de vijand gedraaid).
func ally_attack(a: Node2D, _enemy: Node) -> int:
	var hid: String = a.hero_id
	if Settings.action_battles() and int(chain_of(hid)["last"]) == SomChainData.STEP_FINISHER \
			and int(chain_of(hid)["next"]) == 0 and not _ai_heavy.has(hid):
		# na de finisher laadt de AI de volgende slag op (SomHeavyData.ALLY_LEVEL); keten markeren als gebruikt
		chains.erase(hid)
		_ai_heavy[hid] = SomHeavyData.ALLY_LEVEL
		heavy_hold[hid] = 0
		return 0
	return chain_swing(hid, a, 1.0)


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
## knock_tiles / hitstop: aanvalsketen (SomChainData); standaard 1 tegel en geen hitstop (zoals voorheen).
func damage_enemy(m: Node, dmg: int, dir: Vector2i, stagger := true, knock_tiles := 1, hitstop := 0,
		num_color := Color(1, 1, 1), num_scale := 1.0) -> void:
	if not enemies.has(m):
		return
	var e: Dictionary = enemies[m]
	var golem: GolemFight = e.get("golem", null)
	var page: PageWardenFight = e.get("page_warden", null)
	if golem:
		# kern-factor, schadeplafond op de fasedrempel en onkwetsbare fasewissel zitten in GolemFight.damage()
		dmg = golem.damage(dmg)
		_golem_events(m, e, golem.take_events())
		e["hp"] = golem.hp()
		if dmg <= 0:
			last_enemy_damage = 0
			return
	elif page:
		dmg = page.damage(dmg)
		_page_events(m, e, page.take_events())
		e["hp"] = page.hp()
		if dmg <= 0:
			last_enemy_damage = 0
			return
		_page_note_damage(last_attacker, dmg)
	else:
		e["hp"] = int(e["hp"]) - dmg
	e["flash"] = SomData.HIT_FLASH
	last_enemy_damage = dmg
	if not SomFeelData.ENABLED:
		num_color = Color(1, 1, 1)
		num_scale = 1.0
	SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -10), str(dmg), num_color, 0.6, num_scale)
	SomFx.spark(room.get_node("Objects"), center_of(m))
	enemy_hit.emit(m, dmg)
	if int(e["hp"]) <= 0:
		_defeat_enemy(m)
		return
	last_hitstop_ticks = hitstop
	if hitstop > 0:
		e["hitstop"] = maxi(int(e.get("hitstop", 0)), hitstop)
	if not stagger or golem or page:
		return       # Golem / Page Warden: geen knockback/afgebroken telegraaf door gewone slagen (alleen kern-break)
	if e.has("tg"):
		(e["tg"] as TelegraphAttack).interrupt()
	e["tele"] = 0.0          # volle treffer = telegraaf afgebroken
	_monster_pose(m, e, "hurt", 0, _hurt_seconds())
	last_knockback_tiles = knock_tiles
	_knockback(m, dir, knock_tiles)


func _knockback(m: Node, dir: Vector2i, tiles := 1) -> void:
	if dir == Vector2i.ZERO or m.is_moving:
		return
	var from: Vector2 = m.position
	var dest: Vector2i = m.tile
	for i in maxi(1, tiles):
		if room.monster_can_enter(m, dest + dir) != "free":
			break
		dest += dir
	if dest != m.tile:
		m.place_at(dest, m.facing)
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
	if e.has("golem"):
		_golem_clear_visuals(m, e)
	elif e.has("page_warden"):
		_page_clear_visuals(m, e)
	elif e.has("tg"):
		(e["tg"] as TelegraphAttack).cancel()
	enemies.erase(m)
	if enemies.is_empty():
		_clear_transient_combat()
	if target_lock:
		target_lock.on_target_gone(m)
	GameState.mark_defeated(m.enemy_id)
	var gained_exp := int(e["exp"])
	var gained_gold := int(e["gold"])
	GameState.add_gold(gained_gold)
	var lines: Array[String] = [SomData.TXT_EXP % [gained_exp, gained_gold]]
	for h in GameState.alive_heroes():
		var msgs := GameState.give_exp(h, gained_exp)
		lines.append_array(msgs)
	var got: Array = []
	for d in e["drops"]:
		if typeof(d) == TYPE_DICTIONARY and GameData.ITEMS.has(str(d.get("item", ""))) and rng.randf() < float(d.get("chance", 0.0)):
			var id := str(d["item"])
			GameState.add_item(id, 1)
			got.append(id)
			lines.append(SomData.TXT_GOT % PartyActions.item_name(id))
	if not GameState.defeated_map_monsters.has(room.room_id):
		GameState.defeated_map_monsters[room.room_id] = {}
	GameState.defeated_map_monsters[room.room_id][m.monster_id] = true
	room.monsters.erase(m)
	_say("\n".join(lines))
	if e.has("golem") and _story_authority():
		# realtime Golem verslagen: dezelfde verhaal-beat als de turn-based winst (eenmalig, host)
		golem_story_fired = GolemStoryWin.apply(str(room.room_id), str(m.monster_id), str(m.enemy_id), room)
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
	if int(e.get("hitstop", 0)) > 0:       # hitstop (finisher): vijand bevriest een paar ticks
		e["hitstop"] = int(e["hitstop"]) - 1
		return
	if e.has("golem"):
		_golem_ai(m, e, delta)
		return
	if e.has("page_warden"):
		_page_ai(m, e, delta)
		return
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


## D3 PR C: realtime Golem. Host-authoritatief: GolemFight.tick() kiest aanvallen (seeded), de arena zet
## de events om in treffers op de party (dodge-iframes gelden via hit_member), adds en beeld.
## Telegraaf/GolemBossView = alleen zichtbaar; schade uitsluitend via _golem_strike (geen tweede pad).
func _golem_ai(m: Node, e: Dictionary, delta: float) -> void:
	var fight: GolemFight = e["golem"]
	if float(e["flash"]) > 0.0:
		e["flash"] = float(e["flash"]) - delta
	_pose_tick(m, e, delta)
	fight.tick()
	_golem_events(m, e, fight.take_events())
	_golem_sync_visual(m, e, fight)
	_tint(m, e)


func _golem_events(m: Node, e: Dictionary, evs: Array) -> void:
	for ev in evs:
		var d: Dictionary = (ev as Dictionary).duplicate()
		d["tick"] = sim_tick
		golem_events.append(d)
		match str(d.get("type", "")):
			"telegraph_start":
				var a := GolemBoss.attack(str(d["id"]))
				var tid := _target_for(m)
				e["target"] = tid
				e["golem_attack"] = str(d["id"])
				var origin := center_of(m)
				if str(a.get("aim", "")) == "target" and tid != "":
					origin = body_of(tid)
				e["golem_origin"] = origin
				var to := (body_of(tid) if tid != "" else origin) - center_of(m)
				var dir: Vector2i = TelegraphShape.dir_from_vector(to)
				if tid != "":
					m.facing = Vector2i(signi(roundi(to.x)), 0) if absf(to.x) >= absf(to.y) else Vector2i(0, signi(roundi(to.y)))
				_golem_start_visual_telegraph(m, e, str(d["id"]), a, origin, dir, int(d["windup"]))
				_monster_pose(m, e, "attack", 0, float(d["windup"]) / float(TICK_HZ) + 0.05)
				if room and room.has_node("Objects"):
					SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -14), "!", Color(1, 0.3, 0.3), float(d["windup"]) / float(TICK_HZ))
			"attack_hit":
				_golem_clear_telegraph(e)
				_golem_temp_hit_flash(m)
				_monster_pose(m, e, "attack", 1, SomData.MONSTER_STRIKE_MS / 1000.0)
				_golem_strike(m, e, str(d["id"]), float(d["power"]))
			"telegraphs_cancelled":
				_golem_clear_telegraph(e)
			"phase":
				e["golem_phase"] = int(d["index"])
			"adds":
				_golem_spawn_adds(m, d.get("ids", []))


## Visuele telegraaf = exact de _golem_strike-cirkel (distance_to <= reach_px rond strike-origin).
## Geen arc/line: de schade is radiaal; de tekening volgt die zone. Geen extra windup.
func _golem_start_visual_telegraph(m: Node, e: Dictionary, attack_id: String, a: Dictionary, origin: Vector2, dir: Vector2i, windup_ticks: int) -> void:
	var reach_px := _golem_strike_reach_px(m, a)
	# Minimale def voor TelegraphAttack/Layer: altijd cirkel met strike-reach.
	var def := {
		"id": attack_id,
		"shape": "circle",
		"reach": reach_px,
		"windup_ms": GolemBoss.ticks_to_ms(windup_ticks),
		"active_ms": GolemBoss.ticks_to_ms(int(a.get("active", 1))),
		"recovery_ms": 0,
		"power": float(a.get("power", 1.0)),
		"boss": true,
	}
	var tg: TelegraphAttack = e.get("tg", null)
	if tg == null:
		tg = TelegraphAttack.new()
		e["tg"] = tg
	else:
		tg.cancel()
	var origin_i := TelegraphShape.to_px(origin)
	const SHAPE_ID := "circle"
	e["golem_tg_def"] = def
	e["golem_tg_origin"] = origin_i
	e["golem_tg_dir"] = dir
	e["golem_tg_shape"] = SHAPE_ID
	e["golem_tg_reach"] = reach_px
	tg.mirror_from_network(def, 0, TelegraphState.State.WINDUP, windup_ticks, origin_i, dir, SHAPE_ID)
	e["tele"] = float(windup_ticks) * TICK_DT


func _golem_strike_reach_px(m: Node, a: Dictionary) -> int:
	var reach := float(a.get("reach_tiles", 1.0)) * 16.0
	if str(a.get("aim", "")) != "target":
		reach += 8.0 * (maxf(m.size.x, m.size.y) - 1.0)
	return roundi(reach)


func _golem_clear_telegraph(e: Dictionary) -> void:
	if e.has("tg"):
		(e["tg"] as TelegraphAttack).cancel()
	e["tele"] = 0.0
	e.erase("golem_tg_def")
	e.erase("golem_tg_origin")
	e.erase("golem_tg_dir")
	e.erase("golem_tg_shape")
	e.erase("golem_tg_reach")


func _golem_clear_visuals(m: Node, e: Dictionary) -> void:
	_golem_clear_telegraph(e)
	var view: Node = e.get("golem_view", null)
	if view != null and is_instance_valid(view):
		view.queue_free()
	e.erase("golem_view")
	var flash: Node = m.get_node_or_null("GolemHitFlashTemp") if m != null else null
	if flash != null:
		flash.queue_free()


func _ensure_golem_view(m: Node, e: Dictionary) -> GolemBossView:
	var existing: Node = e.get("golem_view", null)
	if existing != null and is_instance_valid(existing):
		return existing as GolemBossView
	var view := GolemBossView.new()
	view.name = "GolemBossView"
	# Geen dubbele body: map-sprite blijft; battle-body van de view uit (marker/kern/flash wel).
	view.body.visible = false
	m.add_child(view)
	e["golem_view"] = view
	return view


func _golem_sync_visual(m: Node, e: Dictionary, fight: GolemFight) -> void:
	var view := _ensure_golem_view(m, e)
	var target_local := Vector2.ZERO
	if e.has("golem_origin"):
		target_local = (e["golem_origin"] as Vector2) - m.position
	view.sync(fight, target_local)
	# Windup-ticks exact uit GolemFight (geen eigen klok, geen extra waarschuwingstijd).
	if fight.step == GolemFight.Step.WINDUP and e.has("golem_tg_def") and e.has("tg"):
		var def: Dictionary = e["golem_tg_def"]
		(e["tg"] as TelegraphAttack).mirror_from_network(
				def, 0, TelegraphState.State.WINDUP, int(fight.step_left),
				e.get("golem_tg_origin", Vector2i.ZERO), e.get("golem_tg_dir", Vector2i.DOWN),
				str(e.get("golem_tg_shape", "circle")))
		e["tele"] = float(fight.step_left) * TICK_DT
	elif fight.step != GolemFight.Step.WINDUP and e.has("golem_tg_def"):
		# Strike/recovery/stagger: telegraaf weg (attack_hit/cancel doen dit al; vang netjes af).
		if fight.step != GolemFight.Step.ACTIVE:
			_golem_clear_telegraph(e)


## Tijdelijke feedback (geen permanente attack-sheet): golem_boss_v2_hit.png als korte flash.
func _golem_temp_hit_flash(m: Node) -> void:
	const HIT_PATH := "res://assets/sprites/enemies/golem_boss_v2_hit.png"
	if m == null or not ResourceLoader.exists(HIT_PATH):
		return
	var old := m.get_node_or_null("GolemHitFlashTemp")
	if old != null:
		old.queue_free()
	var tex := load(HIT_PATH) as Texture2D
	if tex == null:
		return
	var s := Sprite2D.new()
	s.name = "GolemHitFlashTemp"
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# ~2 tegels breed t.o.v. 196 px bron
	var sc := 32.0 / float(maxi(1, tex.get_width()))
	s.scale = Vector2(sc, sc)
	if m.sprite != null:
		s.position = m.sprite.position
	m.add_child(s)
	var tw := m.create_tween()
	tw.tween_interval(float(SomData.MONSTER_STRIKE_MS) / 1000.0)
	tw.tween_callback(s.queue_free)


## Aanval landt: elke levende held binnen het bereik (tegels uit GolemBoss.ATTACKS) wordt geraakt.
## Enige schade-pad voor Golem-aanvallen (telegraaf is visual-only).
func _golem_strike(m: Node, e: Dictionary, attack_id: String, power: float) -> void:
	golem_strike_count += 1
	var a := GolemBoss.attack(attack_id)
	var origin: Vector2 = e.get("golem_origin", center_of(m))
	var reach := float(_golem_strike_reach_px(m, a))
	var slam := attack_id in GolemBoss.SLAM_ATTACKS
	var shook := false
	for id in party_ids():
		if is_alive(id) and node_of(id) != null and origin.distance_to(body_of(id)) <= reach:
			golem_strike_hit_member_count += 1
			hit_member(id, int(e["atk"]), power)
			if slam and not shook and _feel_local_hero(id) and shake != null and SomFeelData.ENABLED:
				shake.kick("boss_slam")
				shook = true


func _golem_spawn_adds(m: Node, ids: Array) -> void:
	if room == null or not room.has_method("add_monster"):
		return
	var i := 0
	for id in ids:
		var off := Vector2i(-2 if i % 2 == 0 else 3, 2)
		room.add_monster({"id": "golem_add_%d_%d" % [sim_tick, i], "enemy": str(id), "tile": [m.tile.x + off.x, m.tile.y + off.y], "moves": true})
		i += 1


## Page Warden: host tikt het gevecht. Doelkeuze alleen bij telegraph_start (threat blijft plakken
## tijdens de windup). Hitstop hierboven bevriest de baas, net als de Golem.
func _page_ai(m: Node, e: Dictionary, delta: float) -> void:
	var fight: PageWardenFight = e["page_warden"]
	if float(e["flash"]) > 0.0:
		e["flash"] = float(e["flash"]) - delta
	_pose_tick(m, e, delta)
	fight.tick()
	_page_events(m, e, fight.take_events())
	if sim_tick % 60 == 0:
		_page_decay_range(m)
	_page_sync_visual(m, e, fight)
	_tint(m, e)


func _page_events(m: Node, e: Dictionary, evs: Array) -> void:
	for ev in evs:
		var d: Dictionary = (ev as Dictionary).duplicate()
		d["tick"] = sim_tick
		page_events.append(d)
		while page_events.size() > PAGE_EVENT_CAP:
			page_events.pop_front()
		match str(d.get("type", "")):
			"telegraph_start":
				var aid := str(d["id"])
				var def := PageWardenBoss.attack_px(aid)
				var ranged := bool(d.get("ranged", false))
				_page_choose_target(m, e, ranged)
				var origin := TelegraphShape.to_px(center_of(m))
				var dir := _page_aim_dir(e, origin)
				e["page_attack"] = aid
				e["page_def"] = def
				e["page_origin"] = origin
				e["page_dir"] = dir
				_page_show_telegraph(e, def, origin, dir, int(d["windup"]))
				_monster_pose(m, e, "attack", 0, float(d["windup"]) / float(TICK_HZ) + 0.05)
				if room and room.has_node("Objects"):
					SomFx.number(room.get_node("Objects"), center_of(m) + Vector2(0, -14), "!", Color(1, 0.3, 0.3), float(d["windup"]) / float(TICK_HZ))
			"attack_hit":
				# Schade op deze tick, zelfde oorsprong. De telegraaf blijft tot ACTIVE voorbij is,
				# anders ziet de gast in de snapshot alleen IDLE.
				_page_strike(e, str(d["id"]), float(d["power"]))
				_monster_pose(m, e, "attack", 1, SomData.MONSTER_STRIKE_MS / 1000.0)
			"telegraphs_cancelled", "stagger_break":
				_page_clear_telegraph(e)
			"phase":
				e["page_phase"] = int(d["index"])
			"adds":
				_page_spawn_adds(m, d.get("ids", []))


func _page_show_telegraph(e: Dictionary, def: Dictionary, origin: Vector2i, dir: Vector2i, windup_ticks: int) -> void:
	var tg: TelegraphAttack = e.get("tg", null)
	if tg == null:
		return
	tg.mirror_from_network(def, 0, TelegraphState.State.WINDUP, windup_ticks, origin, dir, str(def.get("shape", "line")))
	e["tele"] = float(windup_ticks) * TICK_DT


func _page_sync_visual(m: Node, e: Dictionary, fight: PageWardenFight) -> void:
	var view := _ensure_page_view(m, e)
	if view != null:
		view.sync(fight)
	if e.has("page_def") and e.has("tg"):
		var phase := -1
		if fight.step == PageWardenFight.Step.WINDUP:
			phase = TelegraphState.State.WINDUP
		elif fight.step == PageWardenFight.Step.ACTIVE:
			phase = TelegraphState.State.ACTIVE
		elif fight.step == PageWardenFight.Step.RECOVERY:
			phase = TelegraphState.State.RECOVERY
		if phase >= 0:
			var def: Dictionary = e["page_def"]
			(e["tg"] as TelegraphAttack).mirror_from_network(
					def, 0, phase, int(fight.step_left),
					e.get("page_origin", Vector2i.ZERO), e.get("page_dir", Vector2i.DOWN),
					str(def.get("shape", "line")))
			e["tele"] = float(fight.step_left) * TICK_DT
		else:
			_page_clear_telegraph(e)


## Treffer op de echte vorm (lijn / cirkel / kegel), niet op een vervangende cirkel.
## Iframes en perfect-dodge lopen via hit_member, net als bij de Golem.
func _page_strike(e: Dictionary, attack_id: String, power: float) -> void:
	page_strike_count += 1
	var def: Dictionary = e.get("page_def", PageWardenBoss.attack_px(attack_id))
	if def.is_empty():
		return
	var origin: Vector2i = e.get("page_origin", Vector2i.ZERO)
	var dir: Vector2i = e.get("page_dir", Vector2i.DOWN)
	var shape := TelegraphShape.from_data(str(def.get("shape", "line")), origin, dir, def)
	for slot in _coop_slots.keys():
		var id := str(_coop_slots[slot])
		var body := _page_body(int(slot))
		if body == Vector2.INF or not is_alive(id):
			continue
		if not shape.contains_i(TelegraphShape.to_px(body)):
			continue
		page_strike_hits += 1
		hit_member(id, int(e["atk"]), power)


func _page_spawn_adds(m: Node, ids: Array) -> void:
	if room == null or not room.has_method("add_monster"):
		return
	var kept: Array = PageWardenBoss.clamp_adds(enemies.size(), ids, Protocol.SNAPSHOT_ENEMY_BUDGET)
	var i := 0
	for id in kept:
		var off := Vector2i(2 if i % 2 == 0 else -2, 2)
		room.add_monster({
			"id": "page_add_%d_%d" % [sim_tick, i],
			"enemy": str(id),
			"tile": [m.tile.x + off.x, m.tile.y + off.y],
			"moves": true,
		})
		i += 1


func _page_clear_telegraph(e: Dictionary) -> void:
	if e.has("tg"):
		(e["tg"] as TelegraphAttack).cancel()
	e["tele"] = 0.0
	e.erase("page_def")


func _page_clear_visuals(m: Node, e: Dictionary) -> void:
	_page_clear_telegraph(e)
	var view: Node = e.get("page_view", null)
	if view != null and is_instance_valid(view):
		view.queue_free()
	e.erase("page_view")
	if m != null and m.sprite:
		m.sprite.visible = true


func _ensure_page_view(m: Node, e: Dictionary) -> PageWardenView:
	var existing: Node = e.get("page_view", null)
	if existing != null and is_instance_valid(existing):
		return existing as PageWardenView
	var view := PageWardenView.new()
	view.name = "PageWardenView"
	# Voetenanker (128, 194) ligt op de oorsprong van de view. Onderkant van het blok ≈ y=8.
	view.position = Vector2(0, 8)
	m.add_child(view)
	if m.sprite:
		m.sprite.visible = false
	e["page_view"] = view
	return view


## Gast tekent de platen uit de al gemirrorde snapshot-telegraaf. Geen tick, geen threat, geen RNG.
func _page_sync_guest_visual(e: Dictionary, orbit_tick: int, pose: int) -> void:
	if e.get("page_warden", null) != null:
		return
	var view: PageWardenView = e.get("page_view", null)
	if view == null or not is_instance_valid(view):
		return
	var tg: TelegraphAttack = e.get("tg", null)
	var tele_phase := TelegraphState.State.IDLE
	var aid := ""
	if tg != null and tg.is_busy():
		tele_phase = tg.state()
		aid = tg.attack_id()
	view.sync_guest(_page_guest_phase(e), tele_phase, aid, orbit_tick, pose)


## Zichtbare staat voor de gast, in het bestaande pose-byte. Geen extra snapshot-velden.
func _page_wire_pose(e: Dictionary) -> int:
	var fight: PageWardenFight = e.get("page_warden", null)
	if fight == null:
		return 0
	var pose := 0
	if fight.step == PageWardenFight.Step.STAGGER or fight.step == PageWardenFight.Step.RECOVERY:
		pose |= PageWardenView.POSE_HIT
	if fight.core.open:
		pose |= PageWardenView.POSE_ORBIT
	if fight.is_invulnerable():
		pose |= PageWardenView.POSE_FLASH
		var left := int(fight.pm._invuln_ticks)
		var t := 1.0 - float(left) / float(BossPhaseMachine.INVULN_TICKS)
		var frame := clampi(int(t * PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES), 0, PageWardenBoss.SPRITE_PHASE_FLASH_FRAMES - 1)
		pose |= frame << PageWardenView.POSE_FRAME_SHIFT
	return pose


## Zelfde drempel als fase 0 van het script (hp_until 0,50). Volle HP blijft fase 1-plaat.
func _page_guest_phase(e: Dictionary) -> int:
	var max_hp := maxi(1, int(e.get("max_hp", 1)))
	var hp := int(e.get("hp", max_hp))
	if hp >= max_hp:
		return 0
	var limit := clampi(roundi(float(max_hp) * 0.50), 0, max_hp)
	return 1 if hp <= limit else 0


func _page_seat_count() -> int:
	return clampi(_coop_slots.size(), 1, 4)


func _page_body(slot: int) -> Vector2:
	var n := _coop_body(slot)
	if n == null:
		return Vector2.INF
	return n.position + Vector2(0, SomData.BODY_Y)


func _page_aim_dir(e: Dictionary, origin: Vector2i) -> Vector2i:
	var slot := int(e.get("page_slot", Protocol.NO_SLOT))
	if slot < 0:
		return Vector2i.DOWN
	var body := _page_body(slot)
	if body == Vector2.INF:
		return Vector2i.DOWN
	var aim := TelegraphShape.to_px(body)
	var dir := TelegraphShape.dir_from_vector(Vector2(aim - origin))
	if dir == Vector2i.ZERO:
		return Vector2i.DOWN
	return dir


func _page_choose_target(m: Node, e: Dictionary, ranged: bool) -> void:
	if page_threat == null:
		page_threat = ThreatTable.new()
	var ranked := _page_living_nearest(m)
	var ids: Array = []
	var near: Array = []
	for row in ranked:
		var slot := int(row["slot"])
		ids.append(slot)
		if float(row["dist"]) <= 32.0:
			near.append(slot)
	var slot := page_threat.choose(ids, near, ranged, sim_tick)
	e["page_slot"] = slot
	e["target"] = str(_coop_slots.get(slot, "")) if slot >= 0 else ""


func _page_living_nearest(m: Node) -> Array:
	var rows: Array = []
	for slot in _coop_slots.keys():
		var hid := str(_coop_slots[slot])
		if not is_alive(hid):
			continue
		var body := _page_body(int(slot))
		if body == Vector2.INF:
			continue
		rows.append({"slot": int(slot), "dist": center_of(m).distance_to(body)})
	rows.sort_custom(func(a, b):
		if is_equal_approx(float(a["dist"]), float(b["dist"])):
			return int(a["slot"]) < int(b["slot"])
		return float(a["dist"]) < float(b["dist"]))
	return rows


func _page_decay_range(m: Node) -> void:
	if page_threat == null:
		return
	_page_range_scratch.clear()
	var limit := float(SomData.CHASE_RANGE) * 16.0
	for slot in _coop_slots.keys():
		var hid := str(_coop_slots[slot])
		if not is_alive(hid):
			continue
		var body := _page_body(int(slot))
		if body == Vector2.INF:
			continue
		if center_of(m).distance_to(body) <= limit:
			_page_range_scratch.append(int(slot))
	page_threat.decay_out_of_range(_page_range_scratch)


func _page_note_damage(hero_id: String, amount: int) -> void:
	if page_threat == null or amount <= 0 or hero_id == "":
		return
	page_threat.note_damage(_slot_for_hero(hero_id), amount, PageWardenBoss.is_tank(hero_id))


func _page_note_heal(hero_id: String, amount: int) -> void:
	if page_threat == null or amount <= 0 or hero_id == "":
		return
	page_threat.note_heal(_slot_for_hero(hero_id), amount, PageWardenBoss.is_tank(hero_id))


## TODO(M6): taunt-hook. Uitdaging (Dax) roept hier later
## page_threat.taunt(_slot_for_hero(hero_id), sim_tick) aan.
## Nu niet aankoppelen: geen aanroep vanuit schade, heal of de AI.


func _page_clear_hero(hero_id: String) -> void:
	if page_threat == null or hero_id == "":
		return
	page_threat.clear_slot(_slot_for_hero(hero_id))


## Bazen die bij het laden van de kamer nog geen co-op zagen (register liep vóór setup_coop).
func _page_adopt_bosses() -> void:
	if room == null:
		return
	var pending: Array = []
	for m in room.monsters:
		if is_instance_valid(m) and page_warden_rt_applies(m) and not enemies.has(m):
			pending.append(m)
	for m in pending:
		register(m)


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
					var root_ticks := int(def.get("root_ticks", CombatRoots.MAX_ROOT_TICKS)) if bool(def.get("applies_root", false)) else 0
					hit_member(tid, int(e["atk"]), power, root_ticks)
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
	telegraph_layer.sync_from_roots(combat_roots, _root_icon_positions())


## Verhaal-beats (vlaggen, kern) alleen op de host / solo: clients krijgen ze niet zelf.
func _story_authority() -> bool:
	return not coop_mode or coop_sim_host


func _zones_authority() -> bool:
	return not coop_mode or coop_sim_host


func _zone_slow_mult_for_id(id: String) -> float:
	if id == "" or not is_alive(id):
		return 1.0
	return combat_zones.slow_mult_at(TelegraphShape.to_px(body_of(id)))


func _tick_roots() -> void:
	if not _roots_authority():
		return
	combat_roots.tick()


func _roots_authority() -> bool:
	return not coop_mode or coop_sim_host


## Visueel: FX_ROOT-onderkant op MapSprite-voetlijn (node.y + 8): body (BODY_Y -6) + 14 = +8.
const ROOT_FOOT_OFFSET_PX := 14.0


func _root_icon_positions() -> Dictionary:
	var out: Dictionary = {}
	for hid in party_ids():
		if not is_alive(hid):
			continue
		out[hid] = body_of(hid) + Vector2(0, ROOT_FOOT_OFFSET_PX)
	return out


## Dodge-hook (Combat T6): breekt root onmiddellijk en start immuniteit.
func break_root(id: String) -> void:
	if not _roots_authority():
		return
	combat_roots.break_root(id)


func _clear_transient_combat() -> void:
	if shake != null:
		shake.stop()
	combat_zones.clear_all()
	combat_roots.clear_all()
	combat_stamina.clear_all()
	_dodge_roll_ticks.clear()
	_dodge_cd_ticks.clear()
	_dodge_dir.clear()
	chain_reset("*")
	heavy_hold.clear()
	_ai_heavy.clear()


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


func hit_member(id: String, atk: int, power: float = 1.0, root_ticks: int = 0) -> void:
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
	if root_ticks > 0 and _roots_authority():
		combat_roots.try_apply_root(id, root_ticks)
	if int(h["hp"]) <= 0:
		on_member_hp_zero(id)


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
		on_member_hp_zero(id)


## Klap tijdens iframes: ontwijk-pose (geen schade). Telt mee in dodges (tests).
var dodges := 0
func _dodge(id: String) -> void:
	break_root(id)
	var t := pose_tex(id, "dodge")
	var n := node_of(id)
	if t == null or n == null or n.get_node_or_null("SomHurtAnim") != null or n.get_node_or_null("SomDodgeAnim") != null:
		return
	dodges += 1
	SomFx.dodge_pose(n, t, SomData.DODGE_TIME)


func _analog_speed() -> float:
	var s := SomData.MOVE_SPEED * heavy_move_mult(active_id)
	if touch and touch.run_on() and combat_stamina.can_sprint(active_id) and not heavy_charging(active_id):
		return s * 1.5
	return s


func _dodge_facing_dir(id: String) -> Vector2:
	var raw := Vector2.ZERO
	if id == active_id:
		raw = analog_dir() if _dodge_roll_ticks.get(id, 0) <= 0 else _dodge_dir.get(id, Vector2.ZERO)
		if raw.length_squared() <= 0.01 and touch and "joy_raw" in touch:
			raw = SomMove.joy_to_dir(touch.joy_raw)
		if raw.length_squared() <= 0.01:
			raw = SomMove.keys_to_dir()
	var n := node_of(id)
	if raw.length_squared() > 0.01:
		return raw.normalized()
	if target_lock and target_lock.locked_enemy() != null:
		var away: Vector2 = body_of(id) - center_of(target_lock.locked_enemy())
		if away.length_squared() > 1.0:
			return away.normalized()
	if n != null:
		return Vector2(n.facing)
	return Vector2.DOWN


func try_active_dodge(id: String, dir: Vector2) -> bool:
	if not _roots_authority() or down or not is_alive(id):
		return false
	if int(_dodge_roll_ticks.get(id, 0)) > 0 or int(_dodge_cd_ticks.get(id, 0)) > 0:
		return false
	# T29 (Dennis 13:09): een actieve dodge mag een lopende slag annuleren (swing_lock blokkeert niet meer).
	if not combat_stamina.spend(id, SomData.STAMINA_DODGE_COST):
		return false
	var d := dir.normalized() if dir.length_squared() > 0.01 else _dodge_facing_dir(id)
	if d.length_squared() <= 0.01:
		d = Vector2.DOWN
	_dodge_dir[id] = d
	_dodge_roll_ticks[id] = SomData.DODGE_DURATION_TICKS
	_dodge_cd_ticks[id] = SomData.DODGE_COOLDOWN_TICKS
	chain_reset(id)            # dodge annuleert de aanvalsketen van deze actor
	if id == active_id:
		swing_lock = 0.0       # T29: dodge annuleert de lopende slag
	for sl in _coop_slots.keys():
		if str(_coop_slots[sl]) == id:
			_coop_swing_lock[sl] = 0.0
	heavy_cancel(id)           # en het opladen (geen zware slag)
	iframes[id] = float(SomData.DODGE_IFRAME_TICKS) * TICK_DT
	if id == active_id and room != null and room.has_method("start_invuln"):
		room.start_invuln(float(SomData.DODGE_IFRAME_TICKS) * TICK_DT)
	_dodge(id)
	return true


func _room_is_wall(t: Vector2i) -> bool:
	if room != null and room.has_method("is_wall"):
		return bool(room.is_wall(t))
	return false


## Dodge-stap: zelfde logische tegel-clamp als player._process_analog (SomSlide + move_and_collide).
func _apply_dodge_motion(n: Node2D, motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		return
	var wall := Callable(self, "_room_is_wall")
	var voor := n.position
	var want := SomSlide.corrigeer(voor, voor + motion, wall)
	var delta := want - n.position
	if n is CharacterBody2D and delta != Vector2.ZERO:
		(n as CharacterBody2D).move_and_collide(delta)
	n.position = SomSlide.corrigeer(voor, n.position, wall)


func _tick_stamina_and_dodge() -> void:
	if not _roots_authority():
		return
	for id in party_ids():
		if not is_alive(id):
			continue
		var sprint: bool = id == active_id and touch != null and touch.run_on() and analog_dir().length_squared() > 0.01
		combat_stamina.tick_member(id, sprint)
	for id in _dodge_cd_ticks.keys():
		var cd := int(_dodge_cd_ticks[id]) - 1
		if cd <= 0:
			_dodge_cd_ticks.erase(id)
		else:
			_dodge_cd_ticks[id] = cd
	for id in _dodge_roll_ticks.keys():
		var left := int(_dodge_roll_ticks[id])
		if left <= 0:
			continue
		var step := SomData.DODGE_DISTANCE_PX / float(SomData.DODGE_DURATION_TICKS)
		var n := node_of(id)
		if n != null:
			_apply_dodge_motion(n, _dodge_dir.get(id, Vector2.ZERO) * step)
			if n == player:
				player.set("_target", n.position)
		left -= 1
		if left <= 0:
			_dodge_roll_ticks.erase(id)
		else:
			_dodge_roll_ticks[id] = left


func _tick_ally_dodge_ai(ally: Node) -> void:
	if not _roots_authority() or ally == null:
		return
	var hid := str(ally.hero_id)
	if hid == "" or not is_alive(hid):
		return
	if int(_dodge_roll_ticks.get(hid, 0)) > 0:
		return
	if not combat_stamina.can_pay(hid, SomData.STAMINA_DODGE_COST):
		return
	for m in enemies.keys():
		if not is_instance_valid(m) or not enemies.has(m):
			continue
		var e: Dictionary = enemies[m]
		if not e.has("tg"):
			continue
		var tg: TelegraphAttack = e["tg"]
		if tg == null or not tg.in_windup() or tg.ticks_left_in_phase() > 8:
			continue
		var aid := str(e.get("tg_attack", ""))
		if aid == "":
			continue
		var px := TelegraphShape.to_px(ally.body())
		if not tg.hits_point_i(px):
			continue
		if rng.randf() > 0.55:
			continue
		var away: Vector2 = ally.body() - center_of(m)
		try_active_dodge(hid, away)
		return


func on_member_hp_zero(id: String) -> void:
	if coop_mode:
		_coop_sync_down_rows()
		var slot := _slot_for_hero(id)
		if slot == Protocol.NO_SLOT:
			return
		var row: Dictionary = _coop_down[slot]
		row["hp"] = 0
		if not bool(row.get("down", false)):
			CoopRevive.enter_down(row)
			_coop_show_ko(slot, id, true)
			member_down.emit(id)
		_coop_finish_wipe_check()
		return
	_member_ko(id)


func coop_down_rows() -> Array:
	var out: Array = []
	for slot in _coop_down.keys():
		out.append(_coop_down[slot])
	if allies_enabled:
		_coop_append_ally_rows(out)
	return out


func _coop_sync_down_rows() -> void:
	for slot in _coop_slots.keys():
		var s := int(slot)
		var hid := str(_coop_slots[slot])
		if not _coop_down.has(s):
			_coop_down[s] = CoopSeat.make(s, hid, CoopSeat.CONTROLLER_HUMAN)
		var row: Dictionary = _coop_down[s]
		row["active"] = true
		row["participate"] = true
		row["hero_id"] = hid
		row["character_id"] = hid
		if str(row.get("base_hero", "")) == "":
			row["base_hero"] = hid
		var body := _coop_body(s)
		if body != null:
			row["x"] = int(body.position.x)
			row["y"] = int(body.position.y)
		var h := member(hid)
		if h.is_empty():
			if not bool(row.get("hp_ready", false)):
				row["hp"] = 1
				row["max_hp"] = 1
				row["hp_ready"] = true
		else:
			row["max_hp"] = maxi(1, int(h.get("max_hp", 1)))
			row["hp_ready"] = true
			if bool(row.get("down", false)) and int(h.get("hp", 0)) > 0:
				row["hp"] = int(h["hp"])
			elif not bool(row.get("down", false)):
				row["hp"] = int(h.get("hp", 0))


func _coop_append_ally_rows(rows: Array) -> void:
	# M6: een AI-stoel hoort op slot 0..3 met controller "ai" (CoopSeat).
	# Deze tak is de bestaande SomAlly, testbaar met allies_enabled, tot M6 hem op een roster-slot zet.
	var n := 0
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		var hid := str(ally.hero_id)
		var stored: Dictionary = ally.coop_row if ally.get("coop_row") is Dictionary else {}
		if stored.is_empty():
			stored = CoopSeat.make(Protocol.MAX_PLAYERS + n, hid, CoopSeat.CONTROLLER_ALLY)
			ally.coop_row = stored
		stored["slot"] = Protocol.MAX_PLAYERS + n
		stored["active"] = true
		stored["participate"] = true
		stored["hero_id"] = hid
		stored["character_id"] = hid
		stored["base_hero"] = hid
		stored["x"] = int(ally.position.x)
		stored["y"] = int(ally.position.y)
		var h := member(hid)
		if not h.is_empty():
			stored["max_hp"] = maxi(1, int(h.get("max_hp", 1)))
			if bool(stored.get("down", false)) and int(h.get("hp", 0)) > 0:
				stored["hp"] = int(h["hp"])
			elif not bool(stored.get("down", false)):
				stored["hp"] = int(h.get("hp", 0))
		rows.append(stored)
		n += 1


func _coop_revive_host_tick() -> void:
	if not coop_mode or not coop_sim_host or coop_wiped:
		return
	_coop_tick += 1
	_coop_sync_down_rows()
	var rows := coop_down_rows()
	var all_down := CoopRevive.step(rows, coop_wiped)
	for row in rows:
		if int(row.get("slot", 99)) >= Protocol.MAX_PLAYERS:
			var h := member(str(row.get("hero_id", "")))
			if not h.is_empty():
				h["hp"] = int(row.get("hp", 0))
			continue
		var hid := str(row.get("hero_id", ""))
		var h2 := member(hid)
		if not h2.is_empty():
			h2["hp"] = int(row.get("hp", 0))
		_coop_show_ko(int(row.get("slot", -1)), hid, bool(row.get("down", false)))
	_coop_stamp_flags()
	_coop_update_ring(rows)
	if all_down:
		_coop_finish_wipe_check()


func _coop_stamp_flags() -> void:
	for slot in _coop_down.keys():
		var row: Dictionary = _coop_down[slot]
		var low := Protocol.FLAG_RING_OPEN if ring != null and ring.is_open and int(slot) == coop_local_slot else 0
		row["flags"] = low
	var rows := coop_down_rows()
	CoopRevive.write_flags(rows)


func _coop_update_ring(rows: Array) -> void:
	_ensure_coop_ring()
	if coop_ring == null:
		return
	var best := 0
	var pos := Vector2.ZERO
	for row in rows:
		if not bool(row.get("down", false)):
			continue
		var pct := CoopRevive.flag_progress(int(row.get("flags", 0)))
		if pct >= best:
			best = pct
			pos = Vector2(float(row.get("x", 0)), float(row.get("y", 0)))
	coop_ring.show_channel(pos, best)


func _coop_finish_wipe_check() -> void:
	if coop_wiped:
		return
	if not CoopRevive.everyone_down(coop_down_rows()):
		return
	coop_wiped = true
	coop_wipe_tick = _coop_tick
	coop_run_result.emit(CoopRevive.RESULT_WIPE)


func _coop_input_blocked(slot: int) -> bool:
	if not _coop_down.has(slot):
		return false
	var row: Dictionary = _coop_down[slot]
	if not bool(row.get("hp_ready", false)):
		return false
	return bool(row.get("down", false)) or int(row.get("hp", 1)) <= 0


func _coop_show_ko(slot: int, hero_id: String, on: bool) -> void:
	var body := _coop_body(slot)
	if body == null:
		return
	SomFx.set_ko(body, pose_tex(hero_id, "ko"), on)


func _coop_clear_down_hero(id: String) -> void:
	if not coop_mode:
		return
	_coop_sync_down_rows()
	var slot := _slot_for_hero(id)
	if slot == Protocol.NO_SLOT or not _coop_down.has(slot):
		return
	var row: Dictionary = _coop_down[slot]
	var h := member(id)
	if not h.is_empty():
		row["hp"] = int(h.get("hp", 0))
		row["max_hp"] = maxi(1, int(h.get("max_hp", 1)))
	if int(row.get("hp", 0)) <= 0:
		return
	CoopRevive.clear_down(row)
	_coop_show_ko(slot, id, false)
	if coop_ring != null:
		coop_ring.show_channel(Vector2.ZERO, 0)


func _coop_apply_guest_down(slot: int, hero_id: String, body: Node2D, flags: int) -> void:
	var is_down := CoopRevive.flag_is_down(flags)
	SomFx.set_ko(body, pose_tex(hero_id, "ko"), is_down)
	if not _coop_down.has(slot):
		_coop_down[slot] = CoopSeat.make(slot, hero_id, CoopSeat.CONTROLLER_HUMAN)
	var row: Dictionary = _coop_down[slot]
	row["down"] = is_down
	row["flags"] = flags
	row["x"] = int(body.position.x)
	row["y"] = int(body.position.y)


func _coop_guest_ring() -> void:
	_ensure_coop_ring()
	if coop_ring == null:
		return
	var best := 0
	var pos := Vector2.ZERO
	for slot in _coop_down.keys():
		var row: Dictionary = _coop_down[slot]
		if not bool(row.get("down", false)):
			continue
		var pct := CoopRevive.flag_progress(int(row.get("flags", 0)))
		if pct >= best:
			best = pct
			pos = Vector2(float(row.get("x", 0)), float(row.get("y", 0)))
	coop_ring.show_channel(pos, best)


func _ensure_coop_ring() -> void:
	if coop_ring != null and is_instance_valid(coop_ring):
		return
	coop_ring = CoopReviveRing.new()
	add_child(coop_ring)


## Held KO: bondgenoot blijft liggen (som_ally.gd); bestuurde held -> wissel naar de volgende levende.
## Niemand meer over = game over.
func _feel_local_hero(id: String) -> bool:
	if coop_mode and not coop_sim_host and coop_local_slot >= 0:
		return str(_coop_slots.get(coop_local_slot, "")) == id
	return id == active_id


func _member_ko(id: String) -> void:
	_page_clear_hero(id)
	if shake != null and _feel_local_hero(id):
		shake.stop()
	combat_roots.clear_member(id)
	combat_stamina.clear_member(id)
	_say(SomData.TXT_KO % str(member(id).get("name", id)))
	member_down.emit(id)
	if GameState.alive_heroes().is_empty():
		_party_down()
		return
	if id == active_id:
		switch_hero()


## Iedereen KO: zelfde afloop als een verloren gevecht (checkpoint/respawn via GameState.end_battle).
func _party_down() -> void:
	_clear_transient_combat()
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
			if coop_mode:
				_coop_clear_down_hero(str(target.get("id", "")))
			SomFx.number(room.get_node("Objects"), body_of(str(target.get("id", ""))) + Vector2(0, -22), "+%d" % int(r["hp"]), Color(0.4, 1, 0.5))
			heal_glow(str(target.get("id", "")))
			_page_note_heal(active_id, int(r["hp"]))
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
				var amt := DamageCalc.spell_base(
						{"s": caster, "is_hero": true, "buffs": []}, sp, {"s": enemies[m]["data"]})
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
		var amt := roundi(DamageCalc.spell_base({"s": caster, "is_hero": true, "buffs": []}, sp, {}))
		var expect := mini(amt, int(t["max_hp"]) - int(t["hp"]))
		var tid := str(t.get("id", ""))
		_cast_then(caster_id, spell_id, func() -> void:
			if int(t.get("hp", 0)) <= 0:
				return             # intussen KO: genezen wekt niet
			var got := PartyActions.restore(t, amt, 0)
			_page_note_heal(caster_id, int(got.x))
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
const SeatCtrl := preload("res://scripts/coop/seat_controller.gd")
const Protocol := preload("res://scripts/net/net_protocol.gd")
const Codec := preload("res://scripts/net/net_codec.gd")
const AvatarBlob := preload("res://scripts/net/avatar_blob.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")
const CoopRevive := preload("res://scripts/coop/coop_revive.gd")
const CoopReviveRing := preload("res://scripts/coop/coop_revive_ring.gd")
const CoopSeat := preload("res://scripts/coop/coop_seat.gd")


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
	_coop_swing_lock.clear()
	_free_ai_bodies()
	seat_controller = null
	_rebuild_enemy_order()
	_clear_coop_avatars()
	if _roster_opts_seats(roster):
		_install_seats(session, roster)
	coop_sync_roster(roster)
	_sync_seat_visuals()
	if session != null and seat_controller != null and session.has_method("bind_seats"):
		session.bind_seats(seat_controller)
	if room != null and "monsters" in room:
		_page_adopt_bosses()
	_ensure_coop_ring()
	_coop_sync_down_rows()
	if coop_sim_host:
		CoopRevive.begin_run(coop_down_rows())
	if not coop_sim_host:
		player.set_analog(func() -> Vector2: return Vector2.ZERO, SomData.MOVE_SPEED)


func _roster_opts_seats(roster: Array) -> bool:
	for row in roster:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if (row as Dictionary).has("uid") or (row as Dictionary).has("controller"):
			return true
	return false


func _roster_room(roster: Array) -> String:
	for row in roster:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var code := str((row as Dictionary).get("room_code", ""))
		if code != "":
			return code
	return ""


func _install_seats(session: Node, roster: Array) -> void:
	var sc := SeatCtrl.new()
	sc.configure(_roster_room(roster), coop_sim_host, coop_local_slot)
	if session != null and "room_code" in session and str(session.room_code) != "":
		sc.room_code = str(session.room_code)
	sc.assign(roster)
	if not sc.controller_changed.is_connected(_on_seat_controller_changed):
		sc.controller_changed.connect(_on_seat_controller_changed)
	if player != null:
		var face := Vector2(player.facing) if "facing" in player else Vector2(0, 1)
		for slot in sc.occupied_slots():
			if sc.controller_of(slot) == SeatCtrl.CTRL_LOCAL:
				sc.remember_pos(slot, player.position)
			elif not _row_has_pos(roster, slot):
				sc.remember_pos(slot, SeatCtrl.formation_around(player.position, face, slot))
	seat_controller = sc
	for slot in sc.occupied_slots():
		_coop_slots[slot] = sc.hero_of(slot)
		if sc.controller_of(slot) == SeatCtrl.CTRL_AI and coop_sim_host:
			_spawn_seat_ally(slot, sc.hero_of(slot), sc.pos_of(slot))
		elif slot == coop_local_slot:
			active_id = sc.hero_of(slot)
			_apply_player_sheet()


func _row_has_pos(roster: Array, slot: int) -> bool:
	for row in roster:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if int((row as Dictionary).get("slot", -2)) != slot:
			continue
		return (row as Dictionary).has("x") and (row as Dictionary).has("y")
	return false


func _seat_hold(slot: int) -> bool:
	return seat_controller != null and seat_controller.holds(slot)


func _seat_is_ai(slot: int) -> bool:
	return seat_controller != null and seat_controller.controller_of(slot) == SeatCtrl.CTRL_AI


func _ai_body_locked(slot: int) -> bool:
	return _ai_bodies.has(slot) and is_instance_valid(_ai_bodies[slot])


func _seat_spawn_pos(slot: int) -> Vector2:
	if seat_controller != null:
		return seat_controller.pos_of(slot)
	if player != null:
		return player.position
	return Vector2.ZERO


func _spawn_seat_ally(slot: int, hero_id: String, pos: Vector2) -> void:
	if room == null:
		return
	var objects: Node = room.get_node_or_null("Objects")
	if objects == null:
		return
	_laad_held_cast(hero_id)
	var ally: CharacterBody2D = SomAlly.new()
	ally.name = "SeatAlly_%d" % slot
	objects.add_child(ally)
	ally.setup(self, hero_id, slot)
	ally.position = pos
	ally.seat_slot = slot
	ally.apply_ai_placeholder_look()
	allies.append(ally)
	_ai_bodies[slot] = ally
	if seat_controller != null:
		seat_controller.remember_pos(slot, pos)


func _free_ai_body(slot: int) -> void:
	if not _ai_bodies.has(slot):
		return
	var n: Node = _ai_bodies[slot]
	_ai_bodies.erase(slot)
	allies.erase(n)
	if is_instance_valid(n):
		n.queue_free()


func _free_ai_bodies() -> void:
	for slot in _ai_bodies.keys():
		_free_ai_body(int(slot))
	_ai_bodies.clear()


func _sync_seat_visuals() -> void:
	if seat_controller == null:
		return
	for slot in seat_controller.occupied_slots():
		_coop_slots[slot] = seat_controller.hero_of(slot)
		if slot == coop_local_slot:
			continue
		if coop_sim_host and seat_controller.controller_of(slot) == SeatCtrl.CTRL_AI:
			if not _ai_body_locked(slot):
				_spawn_seat_ally(slot, seat_controller.hero_of(slot), seat_controller.pos_of(slot))
			continue
		if _ai_body_locked(slot):
			continue
		_ensure_coop_avatar(slot, seat_controller.hero_of(slot))
		_tint_ai_avatar(slot)


func _tint_ai_avatar(slot: int) -> void:
	if not _seat_is_ai(slot) or not _coop_avatars.has(slot):
		return
	var av: CoopAvatar = _coop_avatars[slot] as CoopAvatar
	if av != null and av.sprite != null:
		av.sprite.modulate = SeatCtrl.AI_TINT


## Gast valt weg: stoel wordt AI op deze tick, zelfde HP/MP/positie.
func coop_guest_lost(slot: int, reason: String) -> bool:
	if seat_controller == null or not seat_controller.can_take_over(slot):
		return false
	var body := _coop_body(slot)
	var pos: Vector2 = seat_controller.pos_of(slot)
	if body != null:
		pos = body.position
	_pull_seat_vitals(slot)
	seat_controller.remember_pos(slot, pos)
	if not seat_controller.guest_lost(slot, reason):
		return false
	if coop_sim_host:
		_ensure_ai_body_at(slot, pos)
	return true


func _pull_seat_vitals(slot: int) -> void:
	if seat_controller == null:
		return
	var hid: String = str(seat_controller.hero_of(slot))
	var h := member(hid)
	if h.is_empty():
		return
	seat_controller.set_hp_mp(slot, int(h.get("hp", seat_controller.hp_of(slot))), int(h.get("mp", seat_controller.mp_of(slot))))


## member() is de bron. Snapshot en AI lezen daarna dezelfde stoelkopie.
func _refresh_tracked_vitals() -> void:
	if seat_controller == null:
		return
	for slot in seat_controller.occupied_slots():
		_pull_seat_vitals(int(slot))


## Rejoin of claim: AI-lichaam weg, menselijke avatar terug op dezelfde plek.
func _on_seat_controller_changed(slot: int, controller: String) -> void:
	if seat_controller == null or not coop_sim_host:
		return
	if controller == SeatCtrl.CTRL_AI or not _ai_body_locked(slot):
		return
	var pos: Vector2 = (_ai_bodies[slot] as Node2D).position
	var hero := str(seat_controller.hero_of(slot))
	_free_ai_body(slot)
	if slot == coop_local_slot:
		if player != null:
			player.position = pos
		seat_controller.remember_pos(slot, pos)
		return
	_ensure_coop_avatar(slot, hero)
	var av: Node2D = _coop_avatars.get(slot) as Node2D
	if av != null and is_instance_valid(av):
		av.position = pos
	seat_controller.remember_pos(slot, pos)


func _ensure_ai_body_at(slot: int, pos: Vector2) -> void:
	if seat_controller == null:
		return
	if _ai_body_locked(slot):
		var ally: Node2D = _ai_bodies[slot] as Node2D
		ally.position = pos
		if ally.has_method("apply_ai_placeholder_look"):
			ally.apply_ai_placeholder_look()
		seat_controller.remember_pos(slot, pos)
	else:
		_spawn_seat_ally(slot, seat_controller.hero_of(slot), pos)
	if _coop_avatars.has(slot):
		var av: Node = _coop_avatars[slot]
		_coop_avatars.erase(slot)
		if is_instance_valid(av):
			av.queue_free()


func nearest_living_player_pos(from: Vector2) -> Vector2:
	var fallback := player.position if player != null else from
	if seat_controller == null:
		return fallback
	var best := fallback
	var best_d := INF
	var found := false
	for slot in seat_controller.human_slots():
		if seat_controller.hp_of(slot) <= 0:
			continue
		var body := _human_body(slot)
		if body == null:
			continue
		var d := from.distance_to(body.position)
		if d < best_d:
			best_d = d
			best = body.position
			found = true
	return best if found else fallback


func _human_body(slot: int) -> Node2D:
	if slot == coop_local_slot and player != null:
		return player
	if _coop_avatars.has(slot) and is_instance_valid(_coop_avatars[slot]):
		return _coop_avatars[slot] as Node2D
	if _ai_body_locked(slot) and seat_controller != null and seat_controller.controller_of(slot) != SeatCtrl.CTRL_AI:
		return _ai_bodies[slot] as Node2D
	return null


func coop_hud_name(hero_id: String) -> String:
	if seat_controller == null:
		return ""
	for slot in seat_controller.ai_slots():
		if seat_controller.hero_of(slot) == hero_id:
			return seat_controller.hud_name(slot)
	return ""


func coop_hud_rows() -> Array:
	if seat_controller == null:
		return []
	return seat_controller.hud_rows()


func _merge_ai_inputs(inputs: Array, dt: float) -> void:
	for extra in _ai_virtual_inputs(dt):
		var slot := int(extra.get("slot", -1))
		var replaced := false
		for i in inputs.size():
			if int(inputs[i].get("slot", -1)) == slot:
				inputs[i] = extra
				replaced = true
				break
		if not replaced:
			inputs.append(extra)


func _ai_virtual_inputs(dt: float) -> Array:
	var out: Array = []
	if seat_controller == null or not coop_sim_host or not seat_controller.runs_ai():
		return out
	for slot in seat_controller.ai_slots():
		if not _ai_body_locked(slot):
			continue
		var ally: SomAlly = _ai_bodies[slot]
		ally.spell_cd = float(ally.spell_cd) - dt
		ally.charge = minf(1.0, float(ally.charge) + dt / SomData.CHARGE_TIME)
		var senses := _ai_senses(ally, slot)
		var inp: Dictionary = ally.coop_virtual_input(senses, rng)
		if inp.is_empty():
			continue
		inp["slot"] = slot
		if int(inp.get("buttons", 0)) & Codec.BTN_ATTACK:
			ally.charge = 0.0
		var intent := str(inp.get("intent", ""))
		if intent == "heal":
			_ai_try_heal(ally)
			ally.spell_cd = SomData.ALLY_SPELL_CD
		elif intent == "damage_spell":
			ally.spell_cd = SomData.ALLY_SPELL_CD
		seat_controller.remember_pos(slot, ally.position)
		out.append(inp)
	return out


func _ai_senses(ally: CharacterBody2D, slot: int) -> Dictionary:
	_refresh_tracked_vitals()
	var anchor := nearest_living_player_pos(ally.position)
	var face := Vector2(player.facing) if player != null and "facing" in player else Vector2(0, 1)
	var enemy: Node = nearest_enemy(anchor, SomData.ALLY_ENGAGE_RANGE)
	var has_enemy := enemy != null
	var enemy_pos := center_of(enemy) if has_enemy else Vector2.ZERO
	var in_reach := false
	if has_enemy:
		in_reach = ally.body().distance_to(enemy_pos) <= SomData.attack_offset(ally.hero_id) + SomData.attack_reach(ally.hero_id) - 2.0
	var ratio := float(seat_controller.hp_of(slot)) / float(seat_controller.max_hp_of(slot))
	var low_pos := anchor
	var ally_low := false
	var downed := false
	for other in seat_controller.occupied_slots():
		if other == slot:
			continue
		var hp: int = int(seat_controller.hp_of(other))
		if hp <= 0:
			downed = true
			continue
		var part := float(hp) / float(seat_controller.max_hp_of(other))
		if part < SomData.ALLY_HEAL_BELOW:
			ally_low = true
			var b := _coop_body(other)
			if b != null:
				low_pos = b.position
	var chain := chain_wants_followup(ally.hero_id)
	return {
		"self_pos": ally.position,
		"anchor_pos": anchor,
		"anchor_facing": face,
		"slot": slot,
		"has_enemy": has_enemy,
		"enemy_pos": enemy_pos,
		"in_reach": in_reach,
		"charge_ready": ally.charge >= 1.0 or chain,
		"spell_ready": ally.spell_cd <= 0.0 and _hero_has_damage_spell(ally.hero_id),
		"chain_ready": chain,
		"hp_ratio": ratio,
		"ally_low": ally_low,
		"downed_ally": downed,
		"heal_pos": low_pos,
		"telegraph": has_enemy and _enemy_telegraphing(enemy),
		"non_tank_targeted": has_enemy and _enemy_target_is_non_tank(enemy),
		"lock_idx": _enemy_index(enemy) if has_enemy else -1,
	}


func _hero_has_damage_spell(hero_id: String) -> bool:
	var h := member(hero_id)
	var spells: Array = h.get("spells", [])
	if spells.is_empty():
		for row in GameData.HEROES:
			if str(row.get("id", "")) == hero_id:
				spells = row.get("spells", [])
				break
	for s in spells:
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if str(sp.get("type", "")) == "damage":
			return true
	return false


func _enemy_telegraphing(m: Node) -> bool:
	if m == null or not enemies.has(m):
		return false
	var e: Dictionary = enemies[m]
	if float(e.get("tele", 0.0)) > 0.0:
		return true
	var tg: Variant = e.get("tg", null)
	return tg != null and tg.has_method("in_windup") and bool(tg.in_windup())


func _enemy_target_is_non_tank(m: Node) -> bool:
	if m == null or not enemies.has(m):
		return false
	var tid := str(enemies[m].get("target", ""))
	if tid == "":
		return false
	return SeatCtrl.role_of(tid) != "tank"


## Bestaande genees-spreuk op de host. Geen revive: een liggende stoel blijft liggen (M8).
func _ai_try_heal(ally: CharacterBody2D) -> void:
	if ally == null:
		return
	var m := member(ally.hero_id)
	if m.is_empty():
		return
	var low := lowest_member(SomData.ALLY_HEAL_BELOW)
	if low.is_empty():
		return
	var spells: Array = m.get("spells", [])
	for s in spells:
		var sp: Dictionary = GameData.SPELLS.get(str(s), {})
		if str(sp.get("type", "")) == "heal" and int(m.get("mp", 0)) >= int(sp.get("mp", 0)):
			cast_spell(str(s), ally.hero_id, low)
			return


func coop_sync_roster(roster: Array) -> void:
	var seated: Dictionary = {}
	var looks: Dictionary = {}
	for row in roster:
		if not (row is Dictionary):
			continue
		var slot := int(row.get("slot", row.get("seat", Protocol.NO_SLOT)))
		var cid := str(row.get("character_id", ""))
		if cid == "" and str(row.get("class", "")) != "":
			cid = AvatarBlob.base_hero(str(row.get("class", "")))
		if slot == Protocol.NO_SLOT or cid == "":
			continue
		seated[slot] = cid
		var look_v: Variant = row.get("look", PackedByteArray())
		if look_v is PackedByteArray and (look_v as PackedByteArray).size() == AvatarBlob.BYTE_COUNT:
			looks[slot] = look_v
	for slot in _coop_avatars.keys():
		if not seated.has(int(slot)):
			if _seat_hold(int(slot)):
				continue
			coop_deactivate_slot(int(slot))
	for slot in seated.keys():
		var cid: String = str(seated[slot])
		_coop_slots[int(slot)] = cid
		var look: PackedByteArray = looks.get(int(slot), PackedByteArray())
		if int(slot) == coop_local_slot:
			active_id = cid
			_apply_player_sheet()
			_apply_online_look_player(look)
		elif _ai_body_locked(int(slot)):
			pass
		elif _seat_is_ai(int(slot)) and coop_sim_host:
			if not _ai_bodies.has(int(slot)):
				_spawn_seat_ally(int(slot), cid, _seat_spawn_pos(int(slot)))
		else:
			_ensure_coop_avatar(int(slot), cid)
			_apply_online_look_avatar(int(slot), look)
			_tint_ai_avatar(int(slot))
	_prune_coop_avatar_orphans(seated)


## Placeholder-tint tot paper-doll (M2). Zonder look blijft de sheet onaangeroerd.
func _apply_online_look_player(look: PackedByteArray) -> void:
	if look.size() != AvatarBlob.BYTE_COUNT or player == null:
		return
	var decoded := AvatarBlob.decode(look)
	if not bool(decoded.get("ok", false)):
		return
	if player.sprite != null:
		player.sprite.modulate = AvatarBlob.placeholder_tint(decoded)
	player.set_meta("online_look", look)


func _apply_online_look_avatar(slot: int, look: PackedByteArray) -> void:
	if look.size() != AvatarBlob.BYTE_COUNT or not _coop_avatars.has(slot):
		return
	var av: CoopAvatar = _coop_avatars[slot] as CoopAvatar
	if av != null and is_instance_valid(av):
		av.apply_look(look)


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
	if _seat_hold(slot):
		return
	var hid := str(_coop_slots.get(slot, ""))
	combat_roots.clear_member(hid)
	_free_ai_body(slot)
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
		if reuse.is_queued_for_deletion():
			reuse.name = "CoopAvatarFreed_%d" % slot
		else:
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
	if _ai_body_locked(slot):
		return _ai_bodies[slot] as Node2D
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
	if Input.is_action_pressed("interact"):
		buttons |= Codec.BTN_ATTACK_HELD
	if Input.is_action_just_pressed(RING_ACTION):
		buttons |= Codec.BTN_RING
	if Input.is_action_just_pressed(DODGE_ACTION):
		buttons |= Codec.BTN_DODGE
	var lock_idx := -1
	if target_lock and target_lock.locked_enemy() != null:
		lock_idx = _enemy_index(target_lock.locked_enemy())
	return {"stick": stick, "buttons": buttons, "lock_idx": lock_idx}


func coop_host_step(inputs: Array, dt: float) -> void:
	if not coop_sim_host:
		return
	if seat_controller != null:
		seat_controller.begin_tick(dt)
		if seat_controller.runs_ai():
			_merge_ai_inputs(inputs, dt)
	if target_lock:
		target_lock.tick(dt)
	for inp in inputs:
		_apply_coop_input(inp, dt)
	swing_lock = maxf(0.0, swing_lock - dt)
	for sl in _coop_swing_lock.keys():
		_coop_swing_lock[sl] = maxf(0.0, float(_coop_swing_lock[sl]) - dt)
	_tick_chain()
	for m in enemies.keys():
		if is_instance_valid(m):
			_enemy_ai(m, dt)
		else:
			enemies.erase(m)
	_tick_zones()
	_tick_roots()
	_tick_stamina_and_dodge()
	_sim_world(dt)
	_rebuild_enemy_order()
	_coop_revive_host_tick()


func _apply_coop_input(inp: Dictionary, dt: float) -> void:
	var slot := int(inp.get("slot", Protocol.NO_SLOT))
	if not _coop_slots.has(slot):
		return
	var body: Node2D = _coop_body(slot)
	if body == null:
		return
	if _coop_input_blocked(slot):
		return
	var stick: Vector2 = inp.get("stick", Vector2.ZERO)
	if stick.length_squared() > 0.01:
		var dir := stick.normalized()
		var hid := str(_coop_slots.get(slot, ""))
		if hid != "" and combat_roots.blocks_movement(hid):
			stick = Vector2.ZERO
		var slow := _zone_slow_mult_for_id(hid) if hid != "" else 1.0
		if stick.length_squared() > 0.01:
			body.position += dir * SomData.MOVE_SPEED * slow * heavy_move_mult(hid) * dt
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
	if buttons & Codec.BTN_ATTACK and cd <= 0.0 and float(_coop_swing_lock.get(slot, 0.0)) <= 0.0:
		var hid := str(_coop_slots[slot])
		if is_alive(hid):
			chain_swing(hid, body, charge_mult(charge if slot == coop_local_slot else 1.0))
			var step := int(chain_of(hid).get("last", -1)) if Settings.action_battles() else -1
			_coop_attack_cd[slot] = 0.35
			_coop_swing_lock[slot] = maxf(COOP_MIN_SWING_LOCK, _anim_seconds_def(hid, _attack_def(hid, step)))
			if Settings.action_battles():
				heavy_hold[hid] = 0          # indrukken start de vasthoud-teller (SomHeavyData)
	var hid_h := str(_coop_slots.get(slot, ""))
	if hid_h != "":
		heavy_tick(hid_h, bool(buttons & Codec.BTN_ATTACK_HELD), body, 1.0)
	if buttons & Codec.BTN_DODGE:
		var hid2 := str(_coop_slots.get(slot, ""))
		if hid2 != "":
			var d := stick if stick.length_squared() > 0.01 else _dodge_facing_dir(hid2)
			try_active_dodge(hid2, d)


func _enemy_index(m: Node) -> int:
	if not _enemy_order.has(m):
		_rebuild_enemy_order()
	return _enemy_order.find(m)


func coop_encode_snapshot(tick: int) -> PackedByteArray:
	_coop_sync_down_rows()
	_coop_stamp_flags()
	_refresh_tracked_vitals()
	var players: Array = []
	for slot in _coop_slots.keys():
		var body: Node2D = _coop_body(int(slot))
		if body == null:
			continue
		var hid := str(_coop_slots[slot])
		var h := member(hid)
		var flags := 0
		if _coop_down.has(int(slot)):
			flags = int((_coop_down[int(slot)] as Dictionary).get("flags", 0))
		elif ring.is_open and int(slot) == coop_local_slot:
			flags = Protocol.FLAG_RING_OPEN
		var hp := int(h.get("hp", 0))
		if seat_controller != null and seat_controller.tracks(int(slot)):
			hp = seat_controller.hp_of(int(slot))
		players.append({
			"slot": int(slot),
			"x": int(body.position.x),
			"y": int(body.position.y),
			"face": _coop_face_bits(body.facing),
			"frame": 0,
			"hp": hp,
			"mp": combat_stamina.wire_stamina(hid),
			"flags": flags,
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
			"pose": _page_wire_pose(e),
			"target_slot": tslot,
		}
		var tg: TelegraphAttack = e.get("tg", null)
		elist.append(TelegraphSnapshot.merge_enemy_row(base, tg, tslot))
	return Codec.pack_snapshot(tick, players, elist, combat_zones.wire_rows(), combat_roots.wire_rows(_coop_slots))


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
				var old_hp := int(h.get("hp", 0))
				var max_hp := int(h.get("max_hp", old_hp))
				var new_hp := int(row.get("hp", old_hp))
				if slot == coop_local_slot and shake != null and SomFeelData.ENABLED:
					var thresh := maxi(1, int(ceil(float(max_hp) * 0.1)))
					if old_hp - new_hp >= thresh:
						shake.kick("heavy1")
				h["hp"] = new_hp
				combat_stamina.set_current(hid, int(row.get("mp", combat_stamina.current(hid))))
			if not coop_sim_host:
				_coop_apply_guest_down(slot, hid, body, int(row.get("flags", 0)))
	if not coop_sim_host:
		_coop_guest_ring()
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
			_page_sync_guest_visual(e, int(snap.get("tick", 0)), int(row.get("pose", 0)))
	if not coop_sim_host:
		combat_zones.apply_wire_rows(snap.get("zones", []))
		combat_roots.apply_wire_rows(snap.get("roots", []), _coop_slots)
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
