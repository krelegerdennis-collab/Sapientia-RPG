extends Node
## Klus 9: F1 perfect dodge vervolgpunten. Start: godot --path . -- --pdfollowuptest
## a) hit_player geeft een optionele bron door aan hit_member (counter-doel / hitstop);
## b) _clear_transient_combat wist ook perfect_count en perfect_event_ticks;
## c) met perfect dodge uit verandert er niets.

const CombatSim := preload("res://scripts/som/combat_sim.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const SomArena := preload("res://scripts/som/som_arena.gd")
const SomData := preload("res://scripts/data/som_data.gd")
const SomStagger := preload("res://scripts/som/som_stagger.gd")
const SomPerfectDodgeData := preload("res://scripts/data/som_perfect_dodge_data.gd")
const MapMonster := preload("res://scripts/dungeon/map_monster.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")
const PlayerScript := preload("res://scripts/player.gd")

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
	# ENABLED blijft false in de code; alleen tijdelijk aan via force_active (zoals perfect_dodge_tests.gd).
	check("data: ENABLED staat uit in de code", not SomPerfectDodgeData.ENABLED)
	SomPerfectDodgeData.force_active = true
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	_hit_player_src_tests()
	_hit_player_no_src_tests()
	_hit_player_damage_same_tests()
	_clear_transient_tests()
	_disabled_tests()
	SomPerfectDodgeData.force_active = null
	check("force_active teruggezet: perfect dodge weer uit", not SomPerfectDodgeData.is_active())
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	get_tree().quit(1 if failures else 0)


func _arena() -> SomArena:
	var a := SomArena.new()
	a.down = false
	a.combat_stamina = CombatStamina.new()
	a.combat_roots = CombatRoots.new()
	GameState.new_game("Dax")
	GameState.add_member("lotte")
	a.active_id = "dennis"
	a.combat_stamina.init_member("dennis")
	a.combat_stamina.init_member("lotte")
	var r := MockRoom.new()
	var objs := Node2D.new()
	objs.name = "Objects"
	r.add_child(objs)
	a.room = r
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.facing = Vector2i.DOWN
	a.player = p
	a._coop_slots = {0: "dennis", 1: "lotte"}
	return a


func _mock_enemy(a: SomArena) -> MapMonster:
	var m := MapMonster.new()
	m.size = Vector2i.ONE
	m.position = Vector2(160, 160)
	var e := {
		"hp": 40, "max_hp": 40, "atk": 8, "def": 2, "flash": 0.0, "tele": 0.0, "cd": 0.0, "chase": 0.0,
		"hitstop": 0, "target": "dennis", "data": {"max_hp": 40, "def": 2, "unique": false},
	}
	SomStagger.init_entry(e)
	a.enemies[m] = e
	return m


## Start een dodge en laat hem 2 ticks oud worden (binnen het perfect-venster van 6).
func _dodge_in_window(a: SomArena, id := "dennis") -> void:
	a.iframes.clear()
	a._dodge_cd_ticks.erase(id)
	a._pd_icd.erase(id)
	a.combat_stamina.set_current(id, SomData.STAMINA_MAX)
	a._dodge_roll_ticks.erase(id)
	a.try_active_dodge(id, Vector2.RIGHT)
	a.iframes[id] = float(SomData.DODGE_IFRAME_TICKS) * CombatSim.TICK_DT
	for _i in 2:
		a._tick_perfect_dodge_pre()
		a.iframes[id] = float(SomData.DODGE_IFRAME_TICKS) * CombatSim.TICK_DT
		a._dodge_roll_ticks[id] = maxi(1, int(a._dodge_roll_ticks.get(id, 1)))


func _free(a: SomArena, nodes: Array) -> void:
	for n in nodes:
		(n as Node).free()
	a.player.free()
	a.room.free()
	a.free()


func _hit_player_src_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	_dodge_in_window(a)
	var hp0 := int(GameState.member("dennis")["hp"])
	a.hit_player(10, Vector2.ZERO, m)
	check("hit_player+src: perfect geteld", a.perfect_count == 1)
	check("hit_player+src: geen schade", int(GameState.member("dennis")["hp"]) == hp0)
	check("hit_player+src: counter-venster open", int(a._pd_counter.get("dennis", 0)) == SomPerfectDodgeData.COUNTER_WINDOW_TICKS)
	check("hit_player+src: bron krijgt hitstop %d" % SomPerfectDodgeData.HITSTOP_TICKS,
			int(a.enemies[m].get("hitstop", 0)) == SomPerfectDodgeData.HITSTOP_TICKS)
	check("hit_player+src: bron pd_freeze", bool(a.enemies[m].get("pd_freeze", false)))
	check("hit_player+src: last_perfect_hitstop gezet", a.last_perfect_hitstop == SomPerfectDodgeData.HITSTOP_TICKS)
	_free(a, [m])


func _hit_player_no_src_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	_dodge_in_window(a)
	a.hit_player(10, Vector2.ZERO)
	check("hit_player zonder src: perfect geteld (als voorheen)", a.perfect_count == 1)
	check("hit_player zonder src: geen hitstop op vijand", int(a.enemies[m].get("hitstop", 0)) == 0)
	check("hit_player zonder src: geen pd_freeze", not a.enemies[m].has("pd_freeze"))
	check("hit_player zonder src: last_perfect_hitstop ongemoeid", a.last_perfect_hitstop == -1)
	_free(a, [m])
	# Oude aanroep met één argument blijft werken.
	var a2 := _arena()
	_dodge_in_window(a2)
	a2.hit_player(10)
	check("hit_player(atk): perfect geteld", a2.perfect_count == 1)
	_free(a2, [])


## Normale treffer (geen dodge): src verandert de schade niet.
func _hit_player_damage_same_tests() -> void:
	var dmg: Array = []
	for with_src in [false, true]:
		var a := _arena()
		var m := _mock_enemy(a)
		a.seed_rng(777)
		var hp0 := int(GameState.member("dennis")["hp"])
		if with_src:
			a.hit_player(12, Vector2.ZERO, m)
		else:
			a.hit_player(12, Vector2.ZERO)
		dmg.append(hp0 - int(GameState.member("dennis")["hp"]))
		check("normale treffer (src=%s): geen perfect" % with_src, a.perfect_count == 0)
		_free(a, [m])
	check("normale treffer: schade gelijk met/zonder src (%d/%d)" % [dmg[0], dmg[1]], dmg[0] == dmg[1] and dmg[0] > 0)


func _clear_transient_tests() -> void:
	var a := _arena()
	var m := _mock_enemy(a)
	_dodge_in_window(a)
	a.hit_member("dennis", 10, 1.0, 0, m)
	check("clear: vooraf perfect_count 1", a.perfect_count == 1)
	check("clear: vooraf perfect_event_ticks 1", a.perfect_event_ticks.size() == 1)
	a._clear_transient_combat()
	check("clear: perfect_count == 0", a.perfect_count == 0)
	check("clear: perfect_event_ticks leeg", a.perfect_event_ticks.is_empty())
	check("clear: pd-dicts leeg", a._pd_age.is_empty() and a._pd_icd.is_empty() and a._pd_counter.is_empty() and a._pd_flash.is_empty())
	# Na de reset telt een nieuw gevecht weer vanaf 0.
	_dodge_in_window(a)
	a.hit_member("dennis", 10, 1.0, 0, m)
	check("clear: volgend gevecht telt vanaf 0", a.perfect_count == 1 and a.perfect_event_ticks.size() == 1)
	_free(a, [m])


func _disabled_tests() -> void:
	SomPerfectDodgeData.force_active = false
	var a := _arena()
	var m := _mock_enemy(a)
	_dodge_in_window(a)
	var hp0 := int(GameState.member("dennis")["hp"])
	a.hit_player(10, Vector2.ZERO, m)
	check("uit: hit_player+src geen perfect", a.perfect_count == 0)
	check("uit: geen counter", a._pd_counter.is_empty())
	check("uit: geen pd-dicts", a._pd_age.is_empty() and a._pd_icd.is_empty() and a._pd_flash.is_empty())
	check("uit: bron geen hitstop/freeze", int(a.enemies[m].get("hitstop", 0)) == 0 and not a.enemies[m].has("pd_freeze"))
	check("uit: dodge-iframes blokkeren nog steeds schade", int(GameState.member("dennis")["hp"]) == hp0)
	a._clear_transient_combat()
	check("uit: clear laat tellers op 0", a.perfect_count == 0 and a.perfect_event_ticks.is_empty())
	_free(a, [m])
	SomPerfectDodgeData.force_active = true
