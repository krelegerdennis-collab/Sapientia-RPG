extends Node
## Online co-op Easy: schade 1.2, vloerherstel 50, revive zoals de sim.
## Solo/Classic houdt enemy_damage_mult (2.2 x gebied). Geen bestaande suite.
## Start: godot --path . -- --easycoopbalanstest

const SomData := preload("res://scripts/data/som_data.gd")
const Floor := preload("res://scripts/online/online_dls_floor.gd")
const Run := preload("res://scripts/online/online_dls_run.gd")
const Revive := preload("res://scripts/coop/coop_revive.gd")
const Seat := preload("res://scripts/coop/coop_seat.gd")
const SeatCtrl := preload("res://scripts/coop/seat_controller.gd")
const Sim := preload("res://tools/battlesim/d100_mode_sim.gd")
const SomAlly := preload("res://scripts/som/som_ally.gd")

const WINS := {1: 0, 2: 17, 3: 21, 4: 23}

var failures := 0
var passes := 0


class _Kamer extends Node:
	var online_dls := false
	var room_id := "classic_hal"
	var room: Dictionary = {}
	var mode_floor := 1

	func tier() -> int:
		return 0


class _Host extends Node:
	var is_host := true


class _Lichaam extends CharacterBody2D:
	var facing := Vector2i.DOWN


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_signature()
	_heal_rules()
	_hit_rules()
	_ai_revive()
	_revive_survives_floor()
	await _room_entry()
	_sim_choice()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _signature() -> void:
	check("ENEMY_DAMAGE_MULT blijft 2.2", is_equal_approx(SomData.ENEMY_DAMAGE_MULT, 2.2))
	check("co-op Easy-factor is 1.2", is_equal_approx(SomData.COOP_EASY_ENEMY_DAMAGE_MULT, 1.2))
	check("co-op Easy-herstel is 50", SomData.COOP_EASY_FLOOR_HEAL_PCT == 50)
	var ids: Array[String] = ["archief_v4_wachtersgang", "online_dls_easy_9_2", "classic_hal", ""]
	var same := true
	for rid in ids:
		for tier in [0, 1]:
			var expect := SomData.ENEMY_DAMAGE_MULT * SomData.area_rule(rid, tier, "atk")
			if not is_equal_approx(SomData.enemy_damage_mult(rid, tier), expect):
				same = false
	check("enemy_damage_mult blijft ENEMY_DAMAGE_MULT x gebiedsregel", same)
	check("easy-troep is 1.2", is_equal_approx(SomData.coop_enemy_damage_mult("easy", "online_dls_easy_9_2", 0, false), 1.2))
	check("easy-baasklap blijft 2.2", is_equal_approx(SomData.coop_enemy_damage_mult("easy", "online_dls_easy_9_10", 0, true), 2.2))
	check("classic-lookup blijft 2.2", is_equal_approx(SomData.coop_enemy_damage_mult("classic", "classic_hal", 0, false), 2.2))
	check("normal-lookup blijft 2.2", is_equal_approx(SomData.coop_enemy_damage_mult("normal", "online_dls_normal_1_3", 0, false), 2.2))


func _heal_rules() -> void:
	var living := {"id": "dennis", "hp": 10, "max_hp": 40, "mp": 2, "max_mp": 10}
	var down := {"id": "kael", "hp": 0, "max_hp": 30, "mp": 3, "max_mp": 8}
	var heroes: Array = [living, down]
	check("vloer 1 heelt niet", not Floor.apply_easy_entry("easy", 1, heroes, []) and int(living["hp"]) == 10 and int(down["hp"]) == 0)
	check("classic heelt niet", not Floor.apply_easy_entry("classic", 5, heroes, []) and int(living["hp"]) == 10 and int(living["mp"]) == 2)
	check("vloer 2 heelt 50% alleen levenden",
			Floor.apply_easy_entry("easy", 2, heroes, [])
			and int(living["hp"]) == 30 and int(living["mp"]) == 7
			and int(down["hp"]) == 0 and int(down["mp"]) == 3)
	living["hp"] = 10
	living["mp"] = 2
	var row := Seat.make(1, "kael", Seat.CONTROLLER_AI)
	row["hp"] = 0
	row["max_hp"] = 30
	row["down"] = true
	row["revives"] = 1
	var did := Floor.apply_easy_entry("easy", 5, heroes, [row])
	check("vloer 5 vult levenden en laat apply_rest de liggende stoel opstaan",
			did and int(living["hp"]) == 40 and int(living["mp"]) == 10
			and int(down["hp"]) == 30 and int(down["mp"]) == 3
			and not bool(row.get("down", true)) and int(row.get("hp", 0)) == 30
			and int(row.get("revives", 0)) == 1)


func _hit_rules() -> void:
	GameState.new_game("Dax")
	var hero := GameState.member("dennis")
	hero["hp"] = int(hero["max_hp"])
	var easy := _arena(true)
	var classic := _arena(false)
	check("easy-treffer gebruikt 1.2", is_equal_approx(easy.enemy_hit_mult(false), 1.2))
	check("easy-baasklap gebruikt 2.2", is_equal_approx(easy.enemy_hit_mult(true), SomData.enemy_damage_mult(str(easy.room.room_id), 0)))
	check("classic-treffer blijft enemy_damage_mult",
			is_equal_approx(classic.enemy_hit_mult(false), SomData.enemy_damage_mult(str(classic.room.room_id), 0))
			and is_equal_approx(classic.enemy_hit_mult(true), classic.enemy_hit_mult(false)))
	var defv := float(GameState.effective_stat(hero, "def"))
	var easy_dmg := _one_hit(easy, false, defv)
	var boss_dmg := _one_hit(easy, true, defv)
	var classic_dmg := _one_hit(classic, false, defv)
	check("treffer in co-op Easy volgt de 1.2-factor", easy_dmg > 0 and easy_dmg == _expect(defv, easy.enemy_hit_mult(false)))
	check("baasklap in co-op Easy blijft gelijk aan classic", boss_dmg == classic_dmg and boss_dmg == _expect(defv, 2.2))
	var low := int(hero["hp"])
	easy.coop_mode = false
	check("solo-arena heelt niet", not easy.apply_online_easy_entry() and int(hero["hp"]) == low)
	easy.coop_mode = true
	GameState.coop_role = "guest"
	hero["hp"] = 4
	check("gast schrijft geen Easy-herstel", not easy.apply_online_easy_entry() and int(hero["hp"]) == 4)
	GameState.coop_role = ""
	easy.queue_free()
	classic.queue_free()


func _expect(defv: float, mult: float) -> int:
	var probe := RandomNumberGenerator.new()
	probe.seed = 99
	return maxi(1, roundi(float(SomArena.physical_damage(40.0, defv, 1.0, probe)) * mult))


func _one_hit(arena: SomArena, boss: bool, _defv: float) -> int:
	var hero := GameState.member("dennis")
	hero["hp"] = int(hero["max_hp"])
	arena.iframes.erase("dennis")
	arena.rng.seed = 99
	arena.hit_member("dennis", 40, 1.0, 0, boss)
	return int(arena.last_player_damage)


func _arena(easy: bool) -> SomArena:
	var kamer := _Kamer.new()
	kamer.online_dls = easy
	kamer.room_id = "online_dls_easy_9_2" if easy else "classic_hal"
	kamer.room = {"online_mode": "easy", "online_mode_floor": 2} if easy else {}
	kamer.mode_floor = 2 if easy else 1
	var objects := Node2D.new()
	objects.name = "Objects"
	kamer.add_child(objects)
	var arena := SomArena.new()
	arena.coop_mode = true
	arena.coop_sim_host = true
	arena.active_id = "other"
	arena.room = kamer
	var body := _Lichaam.new()
	arena.player = body
	add_child(arena)
	arena.add_child(kamer)
	arena.add_child(body)
	return arena


func _ai_revive() -> void:
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	GameState.join_member("kael")
	var arena := SomArena.new()
	arena.coop_mode = true
	arena.coop_sim_host = true
	arena.coop_local_slot = 0
	arena.allies_enabled = false
	var body := _Lichaam.new()
	body.position = Vector2(80, 80)
	arena.player = body
	add_child(arena)
	arena.add_child(body)
	var sc := SeatCtrl.new()
	sc.configure("KAMER", true, 0)
	sc.assign([
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local", "hp": 0, "mp": 0, "max_hp": 40},
		{"slot": 1, "uid": "seren", "hero_id": "lotte", "controller": "ai", "hp": 20, "mp": 8, "max_hp": 32, "max_mp": 14},
		{"slot": 2, "uid": "kael", "hero_id": "kael", "controller": "ai", "hp": 18, "mp": 4, "max_hp": 28, "max_mp": 8},
	])
	arena.seat_controller = sc
	arena._coop_slots[0] = "dennis"
	arena._coop_slots[1] = "lotte"
	arena._coop_slots[2] = "kael"
	GameState.member("dennis")["hp"] = 0
	GameState.member("lotte")["hp"] = 20
	GameState.member("kael")["hp"] = 18
	var lotte := _seat_ally(arena, "lotte", 1)
	var kael := _seat_ally(arena, "kael", 2)
	arena._coop_sync_down_rows()
	var down: Dictionary = arena._coop_down[0]
	down["down"] = true
	down["hp"] = 0
	down["max_hp"] = int(GameState.member("dennis")["max_hp"])
	down["revives"] = 0
	down["x"] = 80
	down["y"] = 80
	arena.coop_host_step([], 1.0 / 60.0)
	var seren: Dictionary = arena._coop_down[1]
	var other: Dictionary = arena._coop_down[2]
	check("Seren-AI kanaliseert terwijl try_revive false blijft",
			Revive.seat_controller_present() and not SeatCtrl.DRIVES_REVIVE and not SeatCtrl.try_revive(1)
			and lotte.seat_ai and int(seren.get("channel_target", -2)) == 0 and int(seren.get("channel_ticks", 0)) >= 1)
	check("andere AI revivet niet zolang Seren leeft",
			int(other.get("channel_ticks", 0)) == 0 and int(other.get("channel_target", -2)) <= 0 and bool(down.get("down", false)))
	GameState.member("lotte")["hp"] = 0
	seren["hp"] = 0
	seren["down"] = true
	Revive.end_channel(seren)
	arena.coop_host_step([], 1.0 / 60.0)
	check("andere AI revivet als de Heal-stoel ligt",
			int(other.get("channel_target", -2)) == 0 and int(other.get("channel_ticks", 0)) >= 1 and kael.seat_ai)
	arena.queue_free()


func _seat_ally(arena: SomArena, hero_id: String, slot: int) -> SomAlly:
	var ally := SomAlly.new()
	arena.add_child(ally)
	ally.setup(arena, hero_id, slot)
	ally.position = Vector2(80, 80)
	ally.seat_slot = slot
	ally.apply_ai_placeholder_look()
	arena._ai_bodies[slot] = ally
	return ally


func _revive_survives_floor() -> void:
	GameState.new_game("Dax")
	GameState.join_member("lotte")
	GameState.coop_role = "host"
	Run.start("easy", 4242)
	Run.note_revive(1, 1)
	var first := _host_arena()
	check("setup_coop wist de revive-teller niet tijdens een run",
			_revives_of(first, 1) == 1 and Run.revive_of(1) == 1)
	var second := _host_arena()
	check("een nieuwe verdieping houdt één revive per stoel",
			_revives_of(second, 1) == 1 and Run.revive_of(1) == 1)
	first.queue_free()
	second.queue_free()
	Run.stop()
	GameState.coop_role = ""


func _host_arena() -> SomArena:
	var kamer := _Kamer.new()
	var objects := Node2D.new()
	objects.name = "Objects"
	kamer.add_child(objects)
	var arena := SomArena.new()
	var body := _Lichaam.new()
	arena.player = body
	add_child(arena)
	arena.add_child(kamer)
	arena.add_child(body)
	arena.room = kamer
	var session := _Host.new()
	arena.add_child(session)
	arena.setup_coop(session, [
		{"slot": 0, "uid": "host", "hero_id": "dennis", "controller": "local", "hp": 20, "mp": 0, "max_hp": 40, "room_code": "KAMER"},
		{"slot": 1, "uid": "ai", "hero_id": "lotte", "controller": "ai", "hp": 16, "mp": 4, "max_hp": 32, "max_mp": 14, "room_code": "KAMER"},
	], 0)
	return arena


func _revives_of(arena: SomArena, slot: int) -> int:
	for row in arena.coop_down_rows():
		if int(row.get("slot", -1)) == slot:
			return int(row.get("revives", -1))
	return -1


func _room_entry() -> void:
	GameState.coop_role = ""
	GameState.new_game("Dax")
	GameState.join_member("kael")
	var dennis := GameState.member("dennis")
	var kael := GameState.member("kael")
	var dmax := int(dennis["max_hp"])
	var dmmax := int(dennis["max_mp"])
	var kmax := int(kael["max_hp"])
	dennis["hp"] = 4
	dennis["mp"] = 1
	kael["hp"] = 0
	kael["mp"] = 3
	Run.start("easy", 77002)
	Run.floor_no = 2
	var floor2 := _load_room()
	var want_hp := mini(dmax, 4 + int(round(float(dmax) * 50.0 / 100.0)))
	var want_mp := mini(dmmax, 1 + int(round(float(dmmax) * 50.0 / 100.0)))
	check("kamer vloer 2 geeft levenden 50%",
			floor2.som != null and floor2.som._easy_entry_done
			and int(dennis["hp"]) == want_hp and int(dennis["mp"]) == want_mp)
	check("kamer vloer 2 laat een neergegane held liggen", int(kael["hp"]) == 0 and int(kael["mp"]) == 3)
	floor2.queue_free()
	dennis["hp"] = 4
	dennis["mp"] = 1
	kael["hp"] = 0
	kael["mp"] = 3
	Run.floor_no = 5
	var floor5 := _load_room()
	check("kamer vloer 5 roept apply_rest: liggende held staat vol, MP blijft",
			floor5.som != null and int(kael["hp"]) == kmax and int(kael["mp"]) == 3
			and int(dennis["hp"]) == dmax and int(dennis["mp"]) == dmmax)
	var rp := floor5.get_node_or_null("Objects/Rustpunt")
	check("kamer vloer 5 heeft nog het rustpunt", rp != null)
	floor5.queue_free()
	Run.stop()
	await get_tree().process_frame


func _load_room() -> OnlineDlsRoom:
	var packed := load(Run.SCENE) as PackedScene
	var node := packed.instantiate() as OnlineDlsRoom
	add_child(node)
	if node.som != null:
		node.som.set_process(false)
	node.set_process(false)
	return node


func _sim_choice() -> void:
	var result: Dictionary = Sim.run_cfg({
		"mode": "easy",
		"factors": [10],
		"seats": [1, 2, 3, 4],
		"runs": 24,
		"floors": 10,
		"base_seed": 20261110,
		"hypothetical": false,
		"enemy_dmg": 1.2,
		"floor_heal": 50,
		"revive": true,
	})
	print(Sim.format_revive_table(result))
	var got := {}
	for row in result.get("rows", []):
		var seats := int(row.get("seats", 0))
		var wins := -1
		for fl in row.get("floors", []):
			if int(fl.get("floor", 0)) == 10:
				wins = int(fl.get("boss_wins", -1))
		got[seats] = wins
	var ok := true
	for n in [1, 2, 3, 4]:
		if int(got.get(n, -1)) != int(WINS[n]):
			ok = false
	check("sim 1.2/50/revive seed 20261110: 0/17/21/23 baaswinsten", ok and is_equal_approx(float(result.get("enemy_dmg", 0.0)), 1.2) and int(result.get("floor_heal", -1)) == 50 and bool(result.get("revive", false)))
