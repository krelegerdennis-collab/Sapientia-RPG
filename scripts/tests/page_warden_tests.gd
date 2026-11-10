extends Node
## M9a: Page Warden realtime (BossScript + ThreatTable + PageWardenFight).
## Start: godot --path . -- --pagewardentest
## Wijzigt geen bestaande suite. De Golem- en Classic-checks hier zijn alleen lezen.

const BossScript := preload("res://scripts/som/boss_script.gd")
const PageWardenBoss := preload("res://scripts/som/page_warden_boss.gd")
const PageWardenFight := preload("res://scripts/som/page_warden_fight.gd")
const PageWardenView := preload("res://scripts/som/page_warden_view.gd")
const ThreatTable := preload("res://scripts/som/threat_table.gd")
const GolemBoss := preload("res://scripts/som/golem_boss.gd")
const GolemFight := preload("res://scripts/som/golem_fight.gd")
const TelegraphShape := preload("res://scripts/som/telegraph_shape.gd")
const TelegraphSnapshot := preload("res://scripts/net/telegraph_snapshot.gd")
const TelegraphState := preload("res://scripts/som/telegraph_state.gd")
const EnemyAttacks := preload("res://scripts/som/enemy_attacks.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const BossPhaseMachine := preload("res://scripts/som/boss_phase_machine.gd")

var failures := 0
var passes := 0


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
	_registry()
	_attacks()
	_shapes()
	_phase()
	_stagger()
	_determinism()
	_scale()
	_adds_budget()
	_threat()
	_golem_unchanged()
	_classic_unchanged()
	_coop_gate()
	_snapshot_ids()
	_view_art()
	_no_placeholder_generator()
	_guest_view()
	_page_event_cap()
	PageWardenBoss.unregister()
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _registry() -> void:
	PageWardenBoss.ensure_registered()
	check("REGISTRY page_warden", BossScript.has_script("page_warden"))
	check("papiergeest heeft geen BossScript (Classic/Voice blijven turn-based)", not BossScript.has_script("papiergeest"))
	var phases: Array = BossScript.script_for("page_warden").get("phases", [])
	check("2 fases", phases.size() == 2)
	check("drempel 50% dan 0%", phases.size() == 2 and is_equal_approx(float(phases[0]["hp_until"]), 0.50)
			and is_equal_approx(float(phases[1]["hp_until"]), 0.0))
	check("fase 1 geen adds", phases.size() == 2 and (phases[0]["adds"] as Array).is_empty())
	check("fase 2 één papiergeest", phases.size() == 2 and phases[1]["adds"] == ["papiergeest"])
	check("geen enrage", not bool(PageWardenBoss.SCRIPT.get("enrage", true)))
	check("papiergeest zit niet in de gewone telegraaf-pool", not EnemyAttacks.has_telegraph_attack("papiergeest"))


func _attacks() -> void:
	check("DODGE_IFRAME_TICKS blijft 15", SomData.DODGE_IFRAME_TICKS == 15)
	var seen := {}
	for p in PageWardenBoss.SCRIPT["phases"]:
		for a in p["attacks"]:
			seen[str(a["id"])] = true
	check("3-4 aanvallen in de fases", seen.size() >= 3 and seen.size() <= 4)
	for id in seen:
		check("aanval %s bestaat" % id, PageWardenBoss.ATTACKS.has(id))
	for id in PageWardenBoss.ATTACKS:
		var a: Dictionary = PageWardenBoss.ATTACKS[id]
		var min_w := PageWardenBoss.MIN_WINDUP_LARGE_AOE_TICKS if bool(a["large_aoe"]) else PageWardenBoss.MIN_WINDUP_TICKS
		check("%s windup %d >= %d" % [id, int(a["windup"]), min_w], int(a["windup"]) >= min_w and int(a["windup"]) >= 24)
		if a.has("windup2"):
			check("%s windup2 %d >= 24" % [id, int(a["windup2"])], int(a["windup2"]) >= 24)
		check("%s active %d <= 6 en < iframes" % [id, int(a["active"])],
				int(a["active"]) <= PageWardenBoss.MAX_ACTIVE_TICKS and int(a["active"]) < SomData.DODGE_IFRAME_TICKS)
		check("%s stijl rood (ontwijken)" % id, str(a["style"]) == "red")


func _shapes() -> void:
	var origin := Vector2i.ZERO
	var right := TelegraphShape.dir_from_vector(Vector2.RIGHT)
	var line := TelegraphShape.from_data("line", origin, right, PageWardenBoss.attack_px("page_line"))
	check("lijn raakt vooruit", line.contains_i(Vector2i(40, 0)))
	check("lijn mist opzij", not line.contains_i(Vector2i(0, 40)))
	var circle := TelegraphShape.from_data("circle", origin, right, PageWardenBoss.attack_px("page_circle"))
	check("cirkel raakt dichtbij", circle.contains_i(Vector2i(16, 0)))
	check("cirkel mist ver weg", not circle.contains_i(Vector2i(80, 0)))
	var fan := TelegraphShape.from_data("cone", origin, right, PageWardenBoss.attack_px("page_fan"))
	check("waaier raakt in de kegel", fan.contains_i(Vector2i(40, 0)))
	check("waaier mist achter de baas", not fan.contains_i(Vector2i(-40, 0)))


func _phase() -> void:
	var f := PageWardenFight.new(1000, 7)
	check("start fase 0 vol HP", f.phase_index() == 0 and f.hp() == 1000)
	var dealt := f.damage(499)
	check("net boven 50% blijft fase 0", dealt == 499 and f.hp() == 501 and f.phase_index() == 0)
	f.take_events()
	var dealt2 := f.damage(50)
	var evs := f.take_events()
	var saw_phase := false
	var saw_add := false
	for ev in evs:
		if str(ev.get("type", "")) == "phase" and int(ev.get("index", -1)) == 1:
			saw_phase = true
		if str(ev.get("type", "")) == "adds" and ev.get("ids", []) == ["papiergeest"]:
			saw_add = true
	check("drempel 500 wisselt naar fase 1", dealt2 > 0 and f.hp() == 500 and f.phase_index() == 1 and saw_phase)
	check("fase 2 spawnt papiergeest", saw_add)
	check("onkwetsbaar na de wissel", f.is_invulnerable() and f.damage(80) == 0 and f.hp() == 500)
	var quiet := true
	for _i in BossPhaseMachine.INVULN_TICKS:
		f.tick()
		for ev in f.take_events():
			var k := str(ev.get("type", ""))
			if k == "telegraph_start" or k == "attack_hit":
				quiet = false
	check("90 ticks geen aanval tijdens de fasewissel", quiet and not f.is_invulnerable())
	var over := PageWardenFight.new(1000, 3)
	over.damage(99999)
	check("overkill slaat geen fase over", over.phase_index() == 1 and over.hp() == 500)


func _stagger() -> void:
	var f := PageWardenFight.new(2000, 11)
	var found := false
	for _i in 2400:
		f.tick()
		f.take_events()
		if f.core.open and f.step == PageWardenFight.Step.WINDUP:
			found = true
			break
	check("stagger-venster valt samen met een windup", found)
	if not found:
		return
	var dealt := f.damage(int(PageWardenBoss.STAGGER["break_damage"]))
	var evs := f.take_events()
	var broke := false
	var cancelled := false
	for ev in evs:
		if str(ev.get("type", "")) == "stagger_break":
			broke = true
		if str(ev.get("type", "")) == "telegraphs_cancelled":
			cancelled = true
	check("break tijdens windup staggert en cancelt de telegraaf", dealt > 0 and broke and cancelled and f.step == PageWardenFight.Step.STAGGER)
	check("open venster >= 24 ticks", int(PageWardenBoss.STAGGER["open_ticks"]) >= 24)


func _determinism() -> void:
	var a := _digest(42)
	var b := _digest(42)
	var c := _digest(99)
	check("zelfde seed = zelfde verloop", a == b and a != "")
	check("andere seed = ander verloop", a != c)


func _digest(seed_val: int) -> String:
	var f := PageWardenFight.new(1200, seed_val)
	var parts: PackedStringArray = PackedStringArray()
	for t in 360:
		f.tick()
		if t == 80 or t == 160 or t == 240:
			f.damage(40)
		for ev in f.take_events():
			parts.append("%s:%s:%s" % [str(ev.get("type", "")), str(ev.get("id", "")), str(ev.get("index", ""))])
		parts.append("s%d.%d.%d" % [f.hp(), f.phase_index(), f.step])
	return "|".join(parts)


func _scale() -> void:
	check("boss_party_scale(4) blijft 1.0", is_equal_approx(SomData.boss_party_scale(4), 1.0))
	var base := PageWardenBoss.base_stats()
	var prev := 0
	for n in range(1, 5):
		var st := PageWardenBoss.stats_for_seats(n)
		var hook := SomData.boss_party_scale(n)
		var hp := maxi(1, roundi(float(base["max_hp"]) * hook * float(PageWardenBoss.SEAT_HP[n]) * PageWardenBoss.ACTION_HP_MULT))
		var atk := maxi(1, roundi(float(base["atk"]) * hook * float(PageWardenBoss.SEAT_ATK[n]) * PageWardenBoss.ACTION_ATK_MULT))
		check("stoel %d HP/ATK = hook × tabel" % n, int(st["max_hp"]) == hp and int(st["atk"]) == atk)
		check("stoel %d DEF/EXP/goud ongeschaald" % n, int(st["def"]) == int(base["def"]) and int(st["exp"]) == int(base["exp"]) and int(st["gold"]) == int(base["gold"]))
		if n > 1:
			check("stoel %d meer HP dan de vorige" % n, int(st["max_hp"]) > prev)
		prev = int(st["max_hp"])


func _adds_budget() -> void:
	check("budget = protocol 8", PageWardenBoss.budget_matches_protocol())
	check("volle kamer: geen add", PageWardenBoss.clamp_adds(8, ["papiergeest"], 8).is_empty())
	check("één plek vrij: één add", PageWardenBoss.clamp_adds(7, ["papiergeest"], 8) == ["papiergeest"])


func _threat() -> void:
	var t := ThreatTable.new()
	var first := t.choose([1, 0], [], false, 0)
	check("dichtstbijzijnde niet-host is het eerste doel", first == 1 and t.target_slot() == 1)
	t.note_damage(2, 100, false)
	check("doel blijft plakken tot de volgende choose", t.target_slot() == 1)
	var second := t.choose([0, 1, 2], [], false, 30)
	check("hogere threat trekt het doel weg van de host", second == 2)
	var decay := ThreatTable.new()
	decay.note_damage(0, 100, false)
	decay.decay_out_of_range([])
	check("verval −10% buiten bereik", is_equal_approx(decay.threat_of(0), 90.0))
	var tank := ThreatTable.new()
	tank.note_damage(0, 100, true)
	check("tank ×1,5", is_equal_approx(tank.threat_of(0), 150.0))
	var heal := ThreatTable.new()
	heal.note_heal(1, 40, false)
	check("heal-threat op de caster, niet op het doel", is_equal_approx(heal.threat_of(1), 20.0) and is_equal_approx(heal.threat_of(0), 0.0))
	check("dennis is tank (Warrior)", PageWardenBoss.is_tank("dennis") and not PageWardenBoss.is_tank("noor"))


func _golem_unchanged() -> void:
	var phases: Array = GolemBoss.SCRIPT["phases"]
	check("Golem-drempels 60/25/0", phases.size() == 3 and is_equal_approx(float(phases[0]["hp_until"]), 0.60)
			and is_equal_approx(float(phases[1]["hp_until"]), 0.25) and is_equal_approx(float(phases[2]["hp_until"]), 0.0))
	check("Golem-adds alleen fase 2, twee papiergeesten", (phases[0]["adds"] as Array).is_empty()
			and phases[1]["adds"] == ["papiergeest", "papiergeest"] and (phases[2]["adds"] as Array).is_empty())
	GolemBoss.ensure_registered()
	check("kennis_beest blijft registreerbaar", BossScript.has_script("kennis_beest"))
	var d := SomData.action_boss_stats(GameData.ENEMIES["kennis_beest"].duplicate(true), 4)
	check("Golem-stats 520/23/15 ook bij 4 spelers", int(d["max_hp"]) == 520 and int(d["atk"]) == 23 and int(d["def"]) == 15)
	var ga := _golem_digest(5)
	var gb := _golem_digest(5)
	check("Golem zelfde seed = zelfde verloop", ga == gb and ga != "")
	GolemBoss.unregister()


func _golem_digest(seed_val: int) -> String:
	var f := GolemFight.new(520, seed_val)
	var parts: PackedStringArray = PackedStringArray()
	for _t in 180:
		f.tick()
		for ev in f.take_events():
			parts.append("%s:%s" % [str(ev.get("type", "")), str(ev.get("id", ""))])
	return "|".join(parts)


func _classic_unchanged() -> void:
	var a := PageWardenBoss.base_stats()
	var b := Scaling.boss_stats((GameData.ENEMIES["papiergeest"] as Dictionary).duplicate(true), 10)
	check("sleutel 10 = boss_stats (naam Page Warden)", str(a["name"]) == "Page Warden" and str(a["name"]) == str(b["name"]))
	check("sprite blijft page_warden.png", str(a.get("sprite", "")).ends_with("page_warden.png"))
	check("twee aanroepen gelijk", int(a["max_hp"]) == int(b["max_hp"]) and int(a["atk"]) == int(b["atk"]) and int(a["def"]) == int(b["def"]))
	print("classic sleutel 10 HP %d ATK %d DEF %d" % [int(a["max_hp"]), int(a["atk"]), int(a["def"])])
	var voice := Scaling.boss_stats((GameData.ENEMIES["papiergeest"] as Dictionary).duplicate(true), 99)
	check("The Voice sleutel 99 blijft HP 2250", str(voice["name"]) == "The Voice" and int(voice["max_hp"]) == 2250)


func _coop_gate() -> void:
	var arena := SomArena.new()
	var m := FloorMonster.new()
	m.boss = true
	m.enemy_id = "papiergeest"
	m.floor_nr = 10
	arena.coop_mode = false
	check("solo: Page Warden niet realtime", not arena.page_warden_rt_applies(m))
	arena.coop_mode = true
	check("co-op sleutel 10: wel realtime", arena.page_warden_rt_applies(m))
	m.floor_nr = 99
	check("co-op sleutel 99 (The Voice): niet dit script", not arena.page_warden_rt_applies(m))
	m.floor_nr = 10
	m.boss = false
	check("gewone papiergeest: niet de baas", not arena.page_warden_rt_applies(m))
	m.free()
	arena.free()


func _snapshot_ids() -> void:
	check("inktspuw blijft index 1", TelegraphSnapshot.attack_index("inktspuw") == 1)
	check("page_line staat in de snapshot-lijst", TelegraphSnapshot.attack_index("page_line") > 0)
	check("page_volley staat in de snapshot-lijst", TelegraphSnapshot.attack_index("page_volley") > 0)
	var px := EnemyAttacks.attack("page_line")
	check("page_line heeft px-vorm voor de gast", int(px.get("reach", 0)) > 0 and str(px.get("shape", "")) == "line")


func _view_art() -> void:
	check("boss-sprites laden met de juiste maten", PageWardenView.textures_ok())
	check("HIT en PHASE2 zijn 256×200",
			PageWardenView.TEX_HIT.get_width() == 256 and PageWardenView.TEX_HIT.get_height() == 200
			and PageWardenView.TEX_PHASE2.get_width() == 256 and PageWardenView.TEX_PHASE2.get_height() == 200)
	var view := PageWardenView.new()
	var fight := PageWardenFight.new(1000, 4)
	fight.attack_id = "page_line"
	fight.step = PageWardenFight.Step.WINDUP
	view.sync(fight)
	check("windup: slagframe 0, geen trefferflits", view.body.frame == 0 and not view.hit.visible)
	check("windup: voeten op (128, 194)", view.frame_feet_local(view.body).is_equal_approx(Vector2.ZERO))
	fight.step = PageWardenFight.Step.ACTIVE
	view.sync(fight)
	check("active: slagframe zichtbaar, flits uit", view.body.frame == 1 and view.body.texture == PageWardenView.TEX_ATTACK and not view.hit.visible)
	check("active: voeten blijven op het anker", view.frame_feet_local(view.body).is_equal_approx(Vector2.ZERO))
	fight.step = PageWardenFight.Step.RECOVERY
	view.sync(fight)
	check("recovery toont de trefferflits", view.hit.visible)
	fight.step = PageWardenFight.Step.STAGGER
	view.sync(fight)
	check("stagger toont de trefferflits", view.hit.visible)
	check("stagger: voeten van lijf en flits op hetzelfde anker",
			view.frame_feet_local(view.body).is_equal_approx(Vector2.ZERO)
			and view.frame_feet_local(view.hit).is_equal_approx(Vector2.ZERO))
	fight.damage(500)
	fight.step = PageWardenFight.Step.IDLE
	view.sync(fight)
	check("fase 2: phase2-plaat, voeten nog op het anker",
			view.body.texture == PageWardenView.TEX_PHASE2 and view.frame_feet_local(view.body).is_equal_approx(Vector2.ZERO))
	var page: Sprite2D = view._pages[0]
	var world_scale := view.scale * view.projectiles.scale * page.scale
	check("pagina is een eigen node op 16×16 (schaal 1)", page.get_parent() == view.projectiles
			and world_scale.is_equal_approx(Vector2.ONE)
			and page.texture.get_width() == 16 and page.texture.get_height() == 16)
	fight.attack_id = "page_fan"
	fight.step = PageWardenFight.Step.WINDUP
	fight.tick_no = 0
	view.sync(fight)
	check("waaier toont de pagina buiten de lichaamsschaal", page.visible
			and is_equal_approx(page.position.length(), PageWardenView.PAGE_RADIUS))
	view.free()


func _no_placeholder_generator() -> void:
	check("placeholder-generator is weg", not FileAccess.file_exists("res://tools/art_page_warden_placeholders.py"))
	var hw := FileAccess.get_file_as_string("res://tools/handwerk.txt")
	var protected := true
	for path in ["assets/sprites/bosses/page_warden_attack_ph.png", "assets/sprites/bosses/page_warden_hit_ph.png",
			"assets/sprites/bosses/page_warden_phase2_ph.png", "assets/sprites/bosses/page_warden_page_ph.png"]:
		if not hw.contains(path):
			protected = false
	check("definitieve *_ph.png-platen staan in handwerk", protected)


func _guest_view() -> void:
	var arena := SomArena.new()
	var room := StubRoom.new()
	arena.room = room
	arena.coop_mode = true
	arena.coop_sim_host = false
	arena.seed_rng(99)
	var probe := RandomNumberGenerator.new()
	probe.seed = 99
	probe.randf()
	var after_one: int = probe.state
	var m := FloorMonster.new()
	m.boss = true
	m.enemy_id = "papiergeest"
	m.floor_nr = 10
	arena.register(m)
	var e: Dictionary = arena.enemies[m]
	var view: PageWardenView = e.get("page_view", null)
	check("gast: view zonder gevecht of threat", view != null and not e.has("page_warden") and arena.page_threat == null)
	check("gast: register verbruikt geen fight-RNG", arena.rng.state == after_one)
	check("gast: idle op de lichaamplaat", view.body.texture == PageWardenView.TEX_BODY)
	arena._enemy_order = [m]
	var row := {
		"idx": 0, "x": 0, "y": 0, "hp": int(e["max_hp"]), "pose": 0, "target_slot": 0,
		"atk_id": TelegraphSnapshot.attack_index("page_fan"),
		"phase": TelegraphState.State.WINDUP, "t": 30,
		"ox": 0, "oy": 0, "dir_x": 0, "dir_y": 1,
	}
	arena.apply_coop_snapshot({"tick": 12, "players": [], "enemies": [row], "zones": [], "roots": []})
	var page: Sprite2D = view._pages[0]
	var tg: TelegraphAttack = e["tg"]
	check("gast: windup-plaat uit de snapshot, flits uit",
			view.body.texture == PageWardenView.TEX_ATTACK and view.body.frame == 0 and not view.hit.visible)
	check("gast: waaier-pagina uit de snapshot", page.visible and is_equal_approx(page.position.length(), PageWardenView.PAGE_RADIUS))
	check("gast: telegraaf is de snapshot, nog steeds geen fight",
			tg.state() == TelegraphState.State.WINDUP and tg.attack_id() == "page_fan"
			and not e.has("page_warden") and arena.page_threat == null)
	row["phase"] = TelegraphState.State.ACTIVE
	row["atk_id"] = TelegraphSnapshot.attack_index("page_line")
	arena.apply_coop_snapshot({"tick": 13, "players": [], "enemies": [row], "zones": [], "roots": []})
	check("gast: slagframe uit ACTIVE, flits uit", view.body.frame == 1 and not view.hit.visible)
	row["hp"] = int(floor(float(e["max_hp"]) * 0.5))
	row["atk_id"] = 0
	row["phase"] = TelegraphState.State.IDLE
	arena.apply_coop_snapshot({"tick": 14, "players": [], "enemies": [row], "zones": [], "roots": []})
	check("gast: fase 2 uit HP in de snapshot", view.body.texture == PageWardenView.TEX_PHASE2 and not page.visible)
	m.free()
	room.free()
	arena.free()


func _page_event_cap() -> void:
	var arena := SomArena.new()
	var m := FloorMonster.new()
	var e := {}
	var short: Array = []
	for i in 3:
		short.append({"type": "phase", "index": i})
	arena._page_events(m, e, short)
	var order_ok := arena.page_events.size() == 3
	for i in 3:
		if int(arena.page_events[i].get("index", -1)) != i:
			order_ok = false
	check("korte eventlog blijft in volgorde", order_ok and int(e.get("page_phase", -1)) == 2)
	arena.page_events.clear()
	var many: Array = []
	for i in SomArena.PAGE_EVENT_CAP + 6:
		many.append({"type": "phase", "index": i})
	arena._page_events(m, e, many)
	var cap: int = SomArena.PAGE_EVENT_CAP
	var capped := arena.page_events.size() == cap
	if capped:
		capped = int(arena.page_events[0].get("index", -1)) == 6
		capped = capped and int(arena.page_events[cap - 1].get("index", -1)) == cap + 5
	check("page_events blijft op 64 en verwerkt ook de weggevallen entries", capped and int(e.get("page_phase", -1)) == cap + 5)
	m.free()
	arena.free()


## Genoeg velden voor page_warden_rt_applies. Geen MapMonster: die class_name botst met een preload.
class FloorMonster:
	extends Node2D
	var boss := false
	var enemy_id := ""
	var floor_nr := 0
	var moves := true
	var size := Vector2i.ONE
	var sprite = null


class StubRoom:
	extends Node
	var room_id := "pw_guest"
	func tier() -> int:
		return 0
