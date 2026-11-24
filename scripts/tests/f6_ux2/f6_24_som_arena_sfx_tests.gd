extends RefCounted
## Post-RC sfx in SomArena: dodge, zwaard, spreuk, geraakt, KO, level-up; plus
## enemy_hurt (per hit) en status_stun (alleen co-op-host). Registratie via de
## bestaande map-scan in f6_ux2_tests.gd (geen wijziging van die runner).

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")
const SomSfx := preload("res://scripts/audio/som_sfx.gd")
const SomArenaScript := preload("res://scripts/som/som_arena.gd")
const SomHitReact := preload("res://scripts/som/som_hitreact.gd")
const CombatRoots := preload("res://scripts/som/combat_roots.gd")
const CombatStamina := preload("res://scripts/som/combat_stamina.gd")
const Spells := preload("res://scripts/data/spells.gd")
const PlayerScript := preload("res://scripts/player.gd")
const MockRoom := preload("res://scripts/tests/perfect_dodge_mock_room.gd")


func needs_game() -> bool:
	return true


static func _mark() -> int:
	WorldSfx.recent.clear()
	return 0


static func _since(_n: int) -> Array:
	return WorldSfx.recent.duplicate()


func run(t: Node) -> void:
	# 1. sleutels in het manifest + wavs laden
	var missing: Array = SomSfx.ALL.filter(func(k): return not AudioManager.has_sfx(str(k)))
	t.check("som-arena-sfx: alle gebruikte sleutels in het manifest %s" % [missing], missing.is_empty())
	t.check("som-arena-sfx: geen perfect_dodge-sleutel (verwacht, valt terug op dodge)",
			not AudioManager.has_sfx("perfect_dodge"))
	var bad: Array = []
	var n_files := 0
	for k in SomSfx.ALL:
		if not AudioManager.has_sfx(str(k)):
			continue
		for f in AudioManager._sfx[str(k)].get("bestanden", []):
			n_files += 1
			var path: String = AudioManager._sfx_dir + str(f)
			if not ResourceLoader.exists(path) or not (load(path) is AudioStream):
				bad.append(path)
	t.check("som-arena-sfx: %d wav-bestanden laden als AudioStream %s" % [n_files, bad], n_files > 0 and bad.is_empty())

	# 2. spreuk-mapping
	var none: Array = []
	for id in Spells.SPELLS:
		if SomSfx.spell_key(str(id)) == "":
			none.append(id)
	t.check("som-arena-sfx: elke spreuk heeft een geluid %s" % [none], none.is_empty())
	t.check("som-arena-sfx: onbekende spreuk = stil", SomSfx.spell_key("bestaat_niet") == "")
	t.check("som-arena-sfx: vuur -> spell_fire", SomSfx.spell_key("vuur") == "spell_fire")

	# 3. helpers schrijven naar WorldSfx.recent
	var n0 := _mark()
	SomSfx.play_dodge()
	SomSfx.play_perfect_dodge()
	SomSfx.play_sword_swing()
	SomSfx.play_sword_hit()
	SomSfx.play_spell("vuur")
	SomSfx.play_player_hurt()
	SomSfx.play_player_death()
	SomSfx.play_level_up()
	var got := _since(n0)
	t.check("som-arena-sfx: helpers sturen de verwachte sleutels %s" % [got],
			got == [SomSfx.DODGE, SomSfx.DODGE, SomSfx.SWORD_SWING, SomSfx.SWORD_HIT,
			"spell_fire", SomSfx.PLAYER_HURT, SomSfx.PLAYER_DEATH, WorldSfx.LEVEL_UP])

	# 4. arena-hooks: dodge start, zwaard-swing, KO
	var a: Node = _arena()
	t.add_child(a)
	n0 = _mark()
	var dodged: bool = a.try_active_dodge("dennis", Vector2.RIGHT)
	t.check("som-arena-sfx: try_active_dodge slaagt", dodged)
	t.check("som-arena-sfx: actieve dodge speelt dodge %s" % [_since(n0)], _since(n0).has(SomSfx.DODGE))
	n0 = _mark()
	a._apply_perfect_dodge("dennis", null)
	t.check("som-arena-sfx: perfect dodge speelt dodge (geen eigen sleutel) %s" % [_since(n0)],
			_since(n0).count(SomSfx.DODGE) >= 1)
	n0 = _mark()
	a._swing("dennis", a.player, 1.0, -1, 0)
	t.check("som-arena-sfx: _swing speelt sword_swing %s" % [_since(n0)], _since(n0).has(SomSfx.SWORD_SWING))
	if not GameState.has_member("lotte"):
		GameState.add_member("lotte")
	for m in GameState.party:
		if str(m.get("id", "")) == "lotte":
			m["hp"] = maxi(1, int(m.get("max_hp", 1)))
	a.combat_stamina.init_member("lotte")
	n0 = _mark()
	a._member_ko("lotte")
	t.check("som-arena-sfx: KO speelt player_death %s" % [_since(n0)], _since(n0).has(SomSfx.PLAYER_DEATH))
	a.queue_free()
	await t.pframes(1)

	# 5. status_stun alleen op de host (of solo)
	var roots := CombatRoots.new()
	var role0 := str(GameState.coop_role)
	GameState.coop_role = ""
	n0 = _mark()
	roots.try_apply_root("dennis", 30)
	t.check("som-arena-sfx: solo root = status_stun %s" % [_since(n0)], _since(n0).has(WorldSfx.STATUS_STUN))
	GameState.coop_role = "guest"
	n0 = _mark()
	roots.try_apply_root("lotte", 30)
	t.check("som-arena-sfx: gast-root = stil %s" % [_since(n0)], not _since(n0).has(WorldSfx.STATUS_STUN))
	GameState.coop_role = "host"
	n0 = _mark()
	roots.try_apply_root("noor", 30)
	t.check("som-arena-sfx: host-root = status_stun %s" % [_since(n0)], _since(n0).has(WorldSfx.STATUS_STUN))
	n0 = _mark()
	roots.try_apply_root("noor", 40)  # verlenging, geen nieuw geluid
	t.check("som-arena-sfx: root-verlenging = stil %s" % [_since(n0)], not _since(n0).has(WorldSfx.STATUS_STUN))
	GameState.coop_role = role0

	# 6. enemy_hurt één keer per trigger (niet per frame)
	var dummy := _hurt_dummy()
	t.add_child(dummy)
	n0 = _mark()
	SomHitReact.trigger(null, dummy, {}, Vector2i.RIGHT, "light", false, false)
	SomHitReact.trigger(null, dummy, {}, Vector2i.RIGHT, "light", false, false)
	t.check("som-arena-sfx: enemy_hurt één verzoek per hit (2 hits = 2 verzoeken) %s" % [_since(n0)],
			_since(n0).count(WorldSfx.ENEMY_HURT) == 2)
	dummy.queue_free()
	await t.pframes(1)


func _hurt_dummy() -> Node2D:
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nvar sprite: Sprite2D\nvar placeholder := true\nvar size := Vector2i.ONE\nvar enemy_id := \"\"\n"
	gs.reload()
	var n: Node2D = gs.new()
	var s := Sprite2D.new()
	n.add_child(s)
	n.sprite = s
	return n


func _arena() -> Node:
	var a: Node = SomArenaScript.new()
	a.process_mode = Node.PROCESS_MODE_DISABLED
	a.down = false
	a.combat_stamina = CombatStamina.new()
	a.combat_roots = CombatRoots.new()
	a.active_id = "dennis"
	if GameState.party.is_empty():
		GameState.new_game("Dax")
	for hid in ["dennis", "lotte", "noor"]:
		a.combat_stamina.init_member(hid)
	for m in GameState.party:
		m["hp"] = maxi(1, int(m.get("max_hp", 1)))
	var rm := GDScript.new()
	rm.source_code = "extends \"res://scripts/tests/perfect_dodge_mock_room.gd\"\nfunc monsters_active() -> bool:\n\treturn false\n"
	rm.reload()
	var r: Node = rm.new()
	var objs := Node2D.new()
	objs.name = "Objects"
	r.add_child(objs)
	a.room = r
	a.add_child(r)
	var p := CharacterBody2D.new()
	p.set_script(PlayerScript)
	p.facing = Vector2i.RIGHT
	p.position = Vector2(96, 120)
	a.player = p
	a.add_child(p)
	return a
