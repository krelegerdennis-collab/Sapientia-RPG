extends Node
## Codex vangen in Action (SoM-arena). ZELFDE regels als Classic (scripts/battle/codex_battle.gd capture()):
##   oefengevecht -> geen poging; baas -> "too strong" (boek blijft); geen Codex-soort -> "doesn't fit";
##   Codex vol -> melding; anders kost het één Leeg Boek en wordt er gegooid tegen
##   CodexData.capture_chance(soort, hp, max_hp). Gelukt = GameState.codex_add(...) precies als Classic
##   (zelfde niveau, zelfde 'caught'-gegevens, unique_mark) en het monster verdwijnt zonder EXP/goud/buit.
## Doel: het gekozen monster (ring > doel) of anders het dichtstbijzijnde binnen SPELL_RANGE. Is het gekozen
## doel weg (verslagen, in zijn doodsanimatie of vrijgegeven) als het boek zou landen: boek blijft, geen ander doel.
## Tijdens het vang-effect kan er niet nog eens gevangen worden (geen dubbele vangst).

const SomData := preload("res://scripts/data/som_data.gd")
const SomFx := preload("res://scripts/som/som_fx.gd")
const GameData := preload("res://scripts/data/game_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")
const KamerData := preload("res://world_warper/kamers/kamers.gd")

signal capture_done(result: String)

var arena: Node
## Voor de hudtest: >= 0 = vaste worp (0.0 = altijd raak, 0.999 = mis); zoals codex_battle.force_roll.
var force_roll := -1.0
## Laatste poging: {"result", "chance", "roll", "species", "page"} (resultaten als Classic:
## "baas", "geen_soort", "vol", "mislukt", "gelukt"; plus "geen_boek", "geen_doel", "bezig").
var last_capture := {}
var busy := false
var fx_node: Node2D = null


## Mag de Codex-knop/ring-ingang er zijn? Zelfde als Classic: pagina's of een Leeg Boek.
static func shown() -> bool:
	if GameState.practice_battle:
		return false
	return not GameState.codex_pages.is_empty() or GameState.item_count(CodexData.BOOK_ITEM) > 0


func is_boss(m: Node) -> bool:
	return GameState.pending_boss or bool(m.get("boss"))


## Doel-hint zoals Classic: "too strong" / "won't fit" / "Codex full" / "35%".
func hint(m: Node) -> String:
	var sid := CodexData.species_for_enemy(str(m.enemy_id))
	if is_boss(m):
		return "too strong"
	if sid == "" or not bool(CodexData.species(sid)["capturable"]):
		return "won't fit"
	if GameState.codex_full():
		return "Codex full"
	return "%d%%" % roundi(chance_for(m) * 100.0)


func chance_for(m: Node) -> float:
	var e: Dictionary = arena.enemies.get(m, {})
	if e.is_empty():
		return 0.0
	return CodexData.capture_chance(CodexData.species_for_enemy(str(m.enemy_id)), int(e["hp"]), int(e["max_hp"]), is_boss(m))


func target_or_nearest(target = null) -> Node:
	if typeof(target) == TYPE_OBJECT and is_instance_valid(target) and (arena.enemies.has(target) or bool(target.get("boss"))):
		return target
	return arena.nearest_enemy(arena.body(), SomData.SPELL_RANGE)


func _name(m: Node) -> String:
	var e: Dictionary = arena.enemies.get(m, {})
	if not e.is_empty():
		return str(e["data"].get("name", m.enemy_id))
	return str(GameData.ENEMIES.get(str(m.enemy_id), {}).get("name", m.enemy_id))


## Eén vangpoging. Geeft de melding terug (ook in last_capture["text"]); het effect speelt daarna.
func capture(target = null) -> String:
	var text := _capture(target)
	last_capture["text"] = text
	arena._say(text)
	return text


func _capture(target) -> String:
	if busy:
		last_capture = {"result": "bezig"}
		return SomData.TXT_CODEX_BUSY
	if GameState.practice_battle:
		last_capture = {"result": "oefen"}
		return KamerData.OEFEN_VANGEN
	if GameState.item_count(CodexData.BOOK_ITEM) <= 0:
		last_capture = {"result": "geen_boek"}
		return SomData.TXT_CODEX_NO_BOOK
	if arena.down:
		last_capture = {"result": "ko"}
		return SomData.TXT_CODEX_DOWN
	# Gekozen doel (ring) intussen verslagen/stervend of weg: boek terug, NIET naar een ander monster.
	if typeof(target) == TYPE_OBJECT and not (is_instance_valid(target) and (arena.enemies.has(target) or bool(target.get("boss")))):
		last_capture = {"result": "doel_weg"}
		return SomData.TXT_CODEX_GONE
	var m := target_or_nearest(target)
	if m == null:
		last_capture = {"result": "geen_doel"}
		return SomData.TXT_NO_TARGET
	var sid := CodexData.species_for_enemy(str(m.enemy_id))
	var nm := _name(m)
	if is_boss(m):
		last_capture = {"result": "baas", "chance": 0.0, "species": sid}
		return "%s is too strong! A boss won't be written in. (The book stays whole.)" % nm
	if sid == "" or not bool(CodexData.species(sid)["capturable"]):
		last_capture = {"result": "geen_soort", "chance": 0.0, "species": sid}
		return "%s doesn't fit in the Codex. (The book stays whole.)" % nm
	if GameState.codex_full():
		last_capture = {"result": "vol", "chance": 0.0, "species": sid}
		return "The Codex is full (%d pages). (The book stays whole.)" % CodexData.MAX_PAGES
	# het boek wordt gebruikt (zoals Classic: Leeg Boek -1)
	GameState.inventory[CodexData.BOOK_ITEM] = GameState.item_count(CodexData.BOOK_ITEM) - 1
	var chance := chance_for(m)
	var roll: float = force_roll if force_roll >= 0.0 else arena.rng.randf()
	var ok := roll < chance
	last_capture = {"result": "mislukt", "chance": chance, "roll": roll, "species": sid}
	var center: Vector2 = arena.center_of(m)
	busy = true
	if not ok:
		_play_fx(center, null)
		return "The book stays blank... %s slips out! (chance %d%%)" % [nm, roundi(chance * 100.0)]
	# gelukt: weg uit de arena (telt niet als verslagen: geen EXP/goud/buit), komt niet terug in deze kamer
	var tier: int = arena.room.tier() if arena.room.has_method("tier") else 0
	var caught := {"tier": tier, "play_time": int(GameState.play_time())}
	var page: Dictionary = GameState.codex_add(sid, CodexData.capture_level(tier, sid), caught)
	GameState.unique_mark(str(m.enemy_id), "gevangen")
	arena.enemies.erase(m)
	if arena.target_lock:
		arena.target_lock.on_target_gone(m)
	var rid := str(arena.room.room_id)
	if not GameState.defeated_map_monsters.has(rid):
		GameState.defeated_map_monsters[rid] = {}
	GameState.defeated_map_monsters[rid][m.monster_id] = true
	arena.room.monsters.erase(m)
	m.set_process(false)
	m.collision_layer = 0
	last_capture["result"] = "gelukt"
	last_capture["page"] = str(page.get("uid", ""))
	_play_fx(center, m)
	var skills: Array = (page["skills"] as Array).map(func(x): return str(CodexData.skill(x)["name"]))
	return "%s is written into the Codex!\nPage %d: Lv %d, %s." % [nm, GameState.codex_pages.size(),
			int(page["level"]), ", ".join(skills)]


## Vang-effect (SomData.FX_CODEX_CAPTURE) op het midden van het monster. Bij succes vervaagt en
## krimpt het monster tijdens frame 2-4 en verdwijnt het daarna.
func _play_fx(center: Vector2, caught: Node) -> void:
	var d: Dictionary = SomData.FX_CODEX_CAPTURE
	var objs: Node = arena.room.get_node("Objects")
	var t := SomFx.tex(str(d["sheet"]))
	var ms: Array = d["ms"]
	var spr := Sprite2D.new()
	spr.name = "SomCodexCapture"
	spr.z_index = 20
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	var anchor := Vector2(float(d["anchor"][0]), float(d["anchor"][1]))
	spr.position = (center - anchor).round()
	if t:
		spr.texture = t
		spr.hframes = int(d["frames"])
	objs.add_child(spr)
	fx_node = spr
	var tw := spr.create_tween()
	for f in int(d["frames"]):
		tw.tween_callback(func() -> void: spr.frame = f if t else 0)
		tw.tween_interval(float(ms[mini(f, ms.size() - 1)]) / 1000.0)
	if caught != null and is_instance_valid(caught):
		var fade := float(ms[1] + ms[2] + ms[3]) / 1000.0
		var mt := caught.create_tween().set_parallel(true)
		mt.tween_property(caught, "modulate:a", 0.0, fade).set_delay(float(ms[0]) / 1000.0)
		mt.tween_property(caught, "scale", Vector2(0.2, 0.2), fade).set_delay(float(ms[0]) / 1000.0)
	tw.tween_callback(func() -> void:
		if caught != null and is_instance_valid(caught):
			caught.queue_free()
		spr.queue_free()
		fx_node = null
		busy = false
		capture_done.emit(str(last_capture.get("result", ""))))
