extends RefCounted
## Post-RC sfx (vervolg op f6_22): het Action-gevecht (SomArena) klinkt via scripts/audio/som_sfx.gd,
## die ALLEEN de bestaande SomArena-signalen gebruikt (geen wijziging in som_arena.gd/battle.gd).
## Controleert: sleutels in het manifest, elk wav-bestand laadt als AudioStream, de luisteraar
## hangt aan een echte SomArena en reageert op de signalen. Registratie: f6_ux2_tests.gd (map-scan).

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")
const SomSfx := preload("res://scripts/audio/som_sfx.gd")
const SomArenaScript := preload("res://scripts/som/som_arena.gd")
const Spells := preload("res://scripts/data/spells.gd")
const SIGNALS := ["swing_landed", "spell_released", "player_hit", "member_down", "enemy_defeated"]


func needs_game() -> bool:
	return true


## WorldSfx.recent is begrensd (64): eerst leegmaken, dan is de index stabiel.
static func _since(n: int) -> Array:
	return WorldSfx.recent.slice(n)


static func _mark() -> int:
	WorldSfx.recent.clear()
	return 0


## Nep-arena met dezelfde signalen (geen setup/kamer nodig).
static func _fake_arena() -> Node:
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar arena_mode := false\n" \
		+ "signal swing_landed(hero_id: String, hits: int)\n" \
		+ "signal spell_released(spell_id: String, caster_id: String)\n" \
		+ "signal player_hit(damage: int)\n" \
		+ "signal member_down(hero_id: String)\n" \
		+ "signal enemy_defeated(monster: Node, exp_gain: int, gold_gain: int, drops: Array)\n"
	gs.reload()
	var n: Node = Node.new()
	n.set_script(gs)
	return n


func run(t: Node) -> void:
	# 1. sleutels in het manifest + elk bestand laadt als AudioStream
	var keys: Array = SomSfx.ALL.duplicate()
	keys.append(WorldSfx.LEVEL_UP)
	var missing: Array = keys.filter(func(k): return not AudioManager.has_sfx(str(k)))
	t.check("som-sfx: alle sleutels in het manifest %s" % [missing], missing.is_empty())
	var bad: Array = []
	var n_files := 0
	for k in keys:
		if not AudioManager.has_sfx(str(k)):
			continue
		for f in AudioManager._sfx[str(k)].get("bestanden", []):
			n_files += 1
			var path: String = AudioManager._sfx_dir + str(f)
			if not ResourceLoader.exists(path) or not (load(path) is AudioStream):
				bad.append(path)
	t.check("som-sfx: %d wav-bestanden laden als AudioStream %s" % [n_files, bad], n_files > 0 and bad.is_empty())

	# 2. spreuk -> sleutel (per type en element, uit spells.gd)
	var none: Array = []
	for id in Spells.SPELLS:
		if SomSfx.spell_key(str(id)) == "":
			none.append(id)
	t.check("som-sfx: elke spreuk heeft een geluid %s" % [none], none.is_empty())
	t.check("som-sfx: onbekende spreuk = stil", SomSfx.spell_key("bestaat_niet") == "")
	t.check("som-sfx: vuur -> spell_fire", SomSfx.spell_key("vuur") == "spell_fire")

	# 3. echte SomArena heeft de signalen; attach koppelt ze (zonder setup/kamer)
	var real: Node = SomArenaScript.new()
	var lacks: Array = SIGNALS.filter(func(s): return not real.has_signal(str(s)))
	t.check("som-sfx: SomArena heeft de signalen %s" % [lacks], lacks.is_empty())
	var l: Node = SomSfx.attach(real)
	var unc: Array = SIGNALS.filter(func(s): return real.get_signal_connection_list(str(s)).is_empty())
	t.check("som-sfx: luisteraar hangt aan een echte SomArena %s" % [unc], l != null and unc.is_empty())
	t.check("som-sfx: twee keer attach = één luisteraar", SomSfx.attach(real) == l)
	real.free()

	# 4. signalen -> geluid (nep-arena)
	var a := _fake_arena()
	t.add_child(a)
	SomSfx.attach(a)
	var n0 := _mark()
	a.swing_landed.emit("held", 0)
	a.swing_landed.emit("held", 2)
	a.spell_released.emit("vuur", "held")
	a.player_hit.emit(5)
	a.player_hit.emit(0)
	a.member_down.emit("held")
	var got := _since(n0)
	t.check("som-sfx: mis = sword_swing, raak = sword_hit_flesh %s" % [got],
			got.size() >= 2 and got[0] == SomSfx.SWORD_SWING and got[1] == SomSfx.SWORD_HIT)
	t.check("som-sfx: spreuk vuur klinkt", got.has("spell_fire"))
	t.check("som-sfx: geraakt (schade > 0) = één player_hurt", got.count(SomSfx.PLAYER_HURT) == 1)
	t.check("som-sfx: KO = player_death", got.has(SomSfx.PLAYER_DEATH))

	# 5. level-up alleen als een held echt een level stijgt, en niet in de arena-modus
	var hero: Dictionary = GameState.party[0] if not GameState.party.is_empty() else {}
	if hero.is_empty():
		t.check("som-sfx: party aanwezig voor level-up-check", false)
	else:
		var lvl0 := int(hero.get("level", 1))
		var l2: Node = a.get_node("SomSfx")
		l2._levels = l2._party_levels()
		n0 = _mark()
		a.enemy_defeated.emit(null, 0, 0, [])
		t.check("som-sfx: geen level-stijging = geen level_up", not _since(n0).has(WorldSfx.LEVEL_UP))
		hero["level"] = lvl0 + 1
		a.enemy_defeated.emit(null, 0, 0, [])
		t.check("som-sfx: level-stijging = level_up", _since(n0).has(WorldSfx.LEVEL_UP))
		a.arena_mode = true
		hero["level"] = lvl0 + 2
		n0 = _mark()
		a.enemy_defeated.emit(null, 0, 0, [])
		t.check("som-sfx: arena-modus = geen dubbele level_up (arena_run.gd speelt hem al)",
				not _since(n0).has(WorldSfx.LEVEL_UP))
		hero["level"] = lvl0
	a.queue_free()
	await t.pframes(1)
