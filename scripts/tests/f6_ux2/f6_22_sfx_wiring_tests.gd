extends RefCounted
## Post-RC: manifest-sfx aangesloten via WorldSfx -> UiSfx.play -> AudioManager.play_sfx.
## Spioneert op WorldSfx.recent (elke gevraagde sleutel). Registratie: scripts/tests/f6_ux2_tests.gd (map-scan).

const WorldSfx := preload("res://scripts/audio/world_sfx.gd")
const PlayerScene := preload("res://scenes/player.tscn")
const DoorS := preload("res://scripts/door.gd")
const DungeonChestS := preload("res://scripts/dungeon/dungeon_chest.gd")
const HekPoortS := preload("res://scripts/village/hek_poort.gd")
const QuestData := preload("res://scripts/data/quest_data.gd")


func needs_game() -> bool:
	return true


static func _since(n: int) -> Array:
	return WorldSfx.recent.slice(n)


func run(t: Node) -> void:
	# 1. alle sleutels staan in het manifest (anders blijft het stil)
	var missing: Array = WorldSfx.ALL.filter(func(k): return not AudioManager.has_sfx(str(k)))
	t.check("sfx-wiring: alle WorldSfx-sleutels in het manifest %s" % [missing], missing.is_empty())
	for v in WorldSfx.PUZZLE.values():
		t.check("sfx-wiring: puzzel-sleutel %s in het manifest" % v, AudioManager.has_sfx(str(v)))

	# 2. ondergrond per kaart
	t.check("sfx-wiring: ondergrond archief = marmer", WorldSfx.surface_for("res://scenes/maps/archief_ingang.tscn") == WorldSfx.FOOT_MARBLE)
	t.check("sfx-wiring: ondergrond herberg = hout", WorldSfx.surface_for("res://scenes/maps/esdoorn_herberg.tscn") == WorldSfx.FOOT_WOOD)
	t.check("sfx-wiring: ondergrond dorp = steen", WorldSfx.surface_for("res://scenes/maps/dorp_wilgendal.tscn") == WorldSfx.FOOT_STONE)

	# 3. voetstappen: per afstand (1 tegel), niet per beeld; plus een minimale tijd ertussen
	var was_battle: bool = GameState.in_battle
	var was_changing: bool = GameState.changing_map
	GameState.in_battle = false
	GameState.changing_map = false
	var p: Node2D = PlayerScene.instantiate()
	p.set_process(false)
	t.add_child(p)
	p.position = Vector2(100, 100)
	p._fs_last_pos = p.position
	p._fs_acc = 0.0
	p._fs_last_ms = -100000
	p.is_moving = true
	var n0 := WorldSfx.recent.size()
	for i in 15:
		p.position.x += 1.0
		p._footstep_tick()
	var feet := _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: 15 beelden x 1 px = geen voetstap (niet per beeld)", feet.is_empty())
	p.position.x += 1.0
	p._footstep_tick()
	feet = _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: na 16 px precies één voetstap (%s)" % [feet], feet.size() == 1
			and str(feet[0]) == WorldSfx.surface_for(GameState.current_map))
	for i in 8:
		p.position.x += 2.0
		p._footstep_tick()
	feet = _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: nog een tegel binnen %d ms = geen extra stap" % WorldSfx.FOOTSTEP_MIN_MS, feet.size() == 1)
	p._fs_last_ms = -100000
	for i in 8:
		p.position.x += 2.0
		p._footstep_tick()
	feet = _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: na de wachttijd weer een stap", feet.size() == 2)
	p._fs_last_ms = -100000
	p.position.x += 200.0
	p._footstep_tick()
	feet = _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: teleport = geen stap, teller op 0", feet.size() == 2 and p._fs_acc == 0.0)
	GameState.in_battle = true
	for i in 20:
		p.position.x += 2.0
		p._footstep_tick()
	feet = _since(n0).filter(func(k): return str(k).begins_with("footstep_"))
	t.check("sfx-wiring: geen voetstappen tijdens een gevecht", feet.size() == 2)
	GameState.in_battle = was_battle
	GameState.changing_map = was_changing
	p.queue_free()

	# 4. deur op slot
	var door := StaticBody2D.new()
	door.set_script(DoorS)
	t.add_child(door)
	n0 = WorldSfx.recent.size()
	if Dialog.is_open:
		Dialog.close()
	door.bump(null)
	t.check("sfx-wiring: deur op slot -> door_locked", _since(n0).has(WorldSfx.DOOR_LOCKED))
	await t.pframes(2)
	if Dialog.is_open:
		Dialog.close()
	door.queue_free()

	# 5. dungeonkist
	var chest: Node = DungeonChestS.new()
	chest.setup({"id": "sfx_wiring_test", "item": "drankje", "n": 1, "floor": 0})
	t.add_child(chest)
	var had := GameState.item_count("drankje")
	n0 = WorldSfx.recent.size()
	chest.open_chest()
	t.check("sfx-wiring: kist open -> chest_open", _since(n0).has(WorldSfx.CHEST_OPEN))
	await t.pframes(2)
	if Dialog.is_open:
		Dialog.close()
	GameState.story_flags.erase(DungeonChestS.flag_of("sfx_wiring_test"))
	GameState.remove_item("drankje", GameState.item_count("drankje") - had)
	chest.queue_free()

	# 6. puzzel-haakje
	n0 = WorldSfx.recent.size()
	WorldSfx.puzzle("hendel")
	WorldSfx.puzzle("duw")
	t.check("sfx-wiring: puzzel 'hendel' -> lever_pull, 'duw' stil", _since(n0) == [WorldSfx.LEVER])
	var src := FileAccess.get_file_as_string("res://scripts/puzzle/puzzle_room.gd")
	t.check("sfx-wiring: puzzle_room verbindt puzzle_sound", src.contains("puzzle_sound.connect(Callable(WorldSfx, \"puzzle\"))"))

	# 7. wortelgreep (status)
	var roots := CombatRoots.new()
	n0 = WorldSfx.recent.size()
	roots.try_apply_root("sfx_held", 10)
	roots.try_apply_root("sfx_held", 30)
	t.check("sfx-wiring: nieuwe wortelgreep -> één status_stun (verlengen stil)",
			_since(n0).filter(func(k): return k == WorldSfx.STATUS_STUN).size() == 1)

	# 8. opdrachten: van niets naar de huidige stand -> een quest-geluid; nog eens -> stil
	var saved_stand: Dictionary = GameState._quest_klank_stand.duplicate()
	var nul := {}
	for q in QuestData.quests():
		nul[str(q["id"])] = 0
	GameState._quest_klank_stand = nul
	n0 = WorldSfx.recent.size()
	GameState.quest_sync()
	var qs := _since(n0).filter(func(k): return k == WorldSfx.QUEST_ACCEPT or k == WorldSfx.QUEST_COMPLETE)
	t.check("sfx-wiring: nieuwe opdrachtstand -> één quest-geluid (%s)" % [qs], qs.size() == 1)
	n0 = WorldSfx.recent.size()
	GameState.quest_sync()
	t.check("sfx-wiring: zelfde stand -> geen quest-geluid", _since(n0).is_empty())
	n0 = WorldSfx.recent.size()
	GameState.quest_sync(false)
	t.check("sfx-wiring: quest_sync(false) (laden) -> stil", _since(n0).is_empty())
	if not saved_stand.is_empty():
		GameState._quest_klank_stand = saved_stand
