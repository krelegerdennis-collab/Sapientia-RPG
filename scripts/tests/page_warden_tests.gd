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
	check("placeholder-art gemarkeerd (magenta hoek)", PageWardenView.textures_ok())
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


## Genoeg velden voor page_warden_rt_applies. Geen MapMonster: die class_name botst met een preload.
class FloorMonster:
	extends Node
	var boss := false
	var enemy_id := ""
	var floor_nr := 0
