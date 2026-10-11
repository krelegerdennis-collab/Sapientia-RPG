extends Node
## v0.11 Autoload "Story": voert de verhaal-events uit scripts/data/story_data.gd uit.
## De voortgang zelf (story_step + story_flags) staat in GameState, zodat hij mee
## opgeslagen wordt. Zie story_data.gd voor de lijst met commando's.
##
## Gebruik vanuit objecten:  if Story.trigger("put", self): return
##   (true = er liep een event, false = doe het normale gedrag van het object)
## map.gd roept bij elke map Story.map_ready(self) aan: kleurtint, objecten tonen of
## verbergen, het event na een gevecht en de MAP_ENTER-triggers.

signal event_finished(event_id: String)

const SD := preload("res://scripts/data/story_data.gd")
const Molen := preload("res://scripts/village/molen.gd")
const UiStyleC := preload("res://scripts/ui/ui_style.gd")
const WINDOW_TILE := Vector2i(4, 0)      # raam-tile in binnen.png
const WALK_SPEED := 56.0

var running := false
var current_event := ""
## Alle events die gestart zijn (voor de autotest / debuggen).
var history: Array[String] = []
## Event dat moet lopen als de map na een gevecht weer geladen is.
var after_battle_event := ""
var last_choice := -1
## Getimed event: {"event": id, "left": sec, "map": pad}
var scheduled := {}
var _shake_left := 0.0
var _shake_total := 0.0
var _shake_strength := 0.0
var _card_layer: CanvasLayer
var card_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Bij een nieuw spel (keep_history = false) en bij laden (geschiedenis blijft, voor debuggen).
func reset(keep_history := false) -> void:
	running = false
	current_event = ""
	if not keep_history:
		history.clear()
	after_battle_event = ""
	scheduled = {}


# ---------------------------------------------------------------- voorwaarden
func step() -> int:
	return GameState.story_step


func has_flag(f: String) -> bool:
	return GameState.story_flags.has(f)


func check(c: Dictionary, arg := "") -> bool:
	var s := step()
	if c.has("step") and s != int(c["step"]):
		return false
	if c.has("step_lt") and s >= int(c["step_lt"]):
		return false
	if c.has("step_ge") and s < int(c["step_ge"]):
		return false
	for f in c.get("flags", []):
		if not has_flag(_sub(f, arg)):
			return false
	if c.has("not_flags"):
		# not_flags: waar als minstens één van deze flags NIET gezet is
		var any_missing := false
		for f in c["not_flags"]:
			if not has_flag(_sub(f, arg)):
				any_missing = true
		if not any_missing:
			return false
	if c.has("item") and GameState.item_count(str(c["item"])) <= 0:
		return false
	if c.has("not_item") and GameState.item_count(str(c["not_item"])) > 0:
		return false
	# v0.16 uitrusting-tutorial: draagt de hoofdheld dit stuk?
	if c.has("equipped") and not wears(str(c["equipped"])):
		return false
	if c.has("not_equipped") and wears(str(c["not_equipped"])):
		return false
	return true


## v0.16 Draagt de hoofdheld (Dennis) dit uitrustingsstuk (in welk vak dan ook)?
func wears(id: String) -> bool:
	for h in GameState.party:
		if str(h.get("id", "")) == GameState.MAIN_HERO and h.get("equip") is Dictionary:
			return (h["equip"] as Dictionary).values().has(id)
	return false


## v0.16 Het veldmenu is net dicht (map.gd): de 'gedwongen' uitrusting-check van de tutorial.
## Loopt de eerste regel uit SD.MENU_CLOSED waarvan de voorwaarde klopt. true = er loopt iets.
func menu_closed() -> bool:
	if running or GameState.in_battle or GameState.changing_map:
		return false
	for t in SD.MENU_CLOSED:
		if check(t.get("if", {})):
			run(str(t["event"]))
			return true
	return false


func _sub(v, arg: String):
	if v is String:
		return v.replace("{arg}", arg)
	return v


## De eerste variant van een event waarvan de voorwaarde klopt ({} = geen).
func pick(event_id: String, arg := "") -> Dictionary:
	for v in SD.EVENTS.get(event_id, []):
		if check(v.get("if", {}), arg):
			return v
	return {}


# ---------------------------------------------------------------- starten
## Object-trigger. true = er loopt nu een event (het object doet verder niets).
func trigger(event_id: String, _source: Node = null, arg := "") -> bool:
	if event_id == "":
		return false
	if running:
		return true
	var v := pick(event_id, arg)
	if v.is_empty() or v.get("do") is String:
		return false
	run(event_id, arg)
	return true


func run(event_id: String, arg := "") -> void:
	if running:
		return
	running = true
	_lock(true)
	var next := event_id
	while next != "" and next != "__stop":
		var v := pick(next, arg)
		if v.is_empty() or v.get("do") is String:
			break
		current_event = next
		history.append(next)
		next = await _exec(v["do"], arg)
	var done := current_event
	running = false
	current_event = ""
	if next != "__stop":
		_lock(false)
	event_finished.emit(done)


## Wacht tot er geen event meer loopt (voor de autotest).
func idle() -> bool:
	return not running


func _map() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.has_method("terrain_at") else null


func _player() -> Node:
	var m := _map()
	return m.get_node_or_null("Objects/Player") if m else null


func _lock(on: bool) -> void:
	var p := _player()
	if p == null:
		return
	if on:
		p.input_locked = true
	elif not GameState.changing_map and not GameState.in_battle:
		p.input_locked = false


func actor(who: String) -> Node:
	if who == "player":
		return _player()
	var m := _map()
	return m.get_node_or_null("Objects/" + who) if m else null


static func dir_of(d) -> Vector2i:
	match str(d):
		"up": return Vector2i.UP
		"left": return Vector2i.LEFT
		"right": return Vector2i.RIGHT
	return Vector2i.DOWN


# ---------------------------------------------------------------- commando's
## Voert een lijst commando's uit. Geeft "" terug, of het event waar naartoe
## gesprongen wordt ("__stop" = helemaal stoppen, bv. bij een gevecht/mapwissel).
func _exec(cmds: Array, arg: String) -> String:
	for raw in cmds:
		var c: Array = []
		for x in raw:
			c.append(_sub(x, arg))
		var op: String = c[0]
		match op:
			"say":
				var lines: Array = []
				for l in c[2]:
					lines.append(_sub(l, arg))
				# v0.17: "{naam}" als spreker = de held (ballon wijst naar de speler)
				Dialog.show_lines(lines, str(c[1]).replace("{naam}", GameState.player_name))
				await Dialog.finished
			"choice":
				var speaker: String = str(c[4]) if c.size() > 4 else ""
				last_choice = await Dialog.ask(str(c[1]), c[2], speaker)
				var targets: Array = c[3]
				if last_choice >= 0 and last_choice < targets.size():
					return str(targets[last_choice])
				return ""
			"walk":
				var a := actor(str(c[1]))
				if a and a.has_method("script_walk"):
					await a.script_walk(dir_of(c[2]), int(c[3]), WALK_SPEED)
			"face":
				var a := actor(str(c[1]))
				if a and a.has_method("face"):
					a.face(dir_of(c[2]))
			"place":
				var a := actor(str(c[1]))
				if a and a.has_method("place_at"):
					a.place_at(Vector2i(int(c[2][0]), int(c[2][1])), dir_of(c[3]))
			"show", "hide":
				var a := actor(str(c[1]))
				if a and a.has_method("set_story_visible"):
					a.set_story_visible(op == "show")
			"frame":
				var a := actor(str(c[1]))
				if a and "sprite" in a:
					a.sprite.frame = int(c[2])
			"shake":
				shake(float(c[1]), float(c[2]))
			"flash":
				await Transition.flash(Color(str(c[1])), float(c[2]))
			"window_glow":
				window_glow(float(c[1]))
			"fade_out":
				await Transition.fade_out(float(c[1]))
			"fade_in":
				await Transition.fade_in(float(c[1]))
			"tint":
				tint_to(str(c[1]), float(c[2]))
			"wait":
				await get_tree().create_timer(float(c[1])).timeout
			"after":
				var m := _map()
				scheduled = {"event": str(c[2]), "left": float(c[1]), "map": m.scene_file_path if m else ""}
			"lock":
				GameState.story_flags["locked:" + str(c[1])] = true
			"unlock":
				GameState.story_flags.erase("locked:" + str(c[1]))
			"flag":
				GameState.story_flags[str(c[1])] = true
			"unflag":
				GameState.story_flags.erase(str(c[1]))
			"step":
				GameState.story_step = int(c[1])
			"give":
				GameState.inventory[str(c[1])] = GameState.item_count(str(c[1])) + int(c[2])
			"take":
				GameState.inventory[str(c[1])] = maxi(0, GameState.item_count(str(c[1])) - int(c[2]))
				if GameState.inventory[str(c[1])] == 0:
					GameState.inventory.erase(str(c[1]))
			"weapon":
				GameState.equip_weapon(GameState.MAIN_HERO, str(c[1]))
			"refresh":
				refresh(_map())
			"if":
				var branch: Array = c[2] if check(c[1], arg) else (c[3] if c.size() > 3 else [])
				var j := await _exec(branch, arg)
				if j != "":
					return j
			"run":
				var v := pick(str(c[1]), arg)
				if not v.is_empty() and v.get("do") is Array:
					history.append(str(c[1]))
					var j := await _exec(v["do"], arg)
					if j != "":
						return j
			"jump":
				return str(c[1])
			"battle":
				var opts: Dictionary = c[2] if c.size() > 2 else {}
				after_battle_event = str(opts.get("after", ""))
				GameState.pending_tutorial = opts.duplicate(true) if opts.get("tutorial", false) else {}
				var m := _map()
				if m:
					m.start_battle(c[1].duplicate())
				return "__stop"
			"map":
				var path: String = SD.MAPS.get(str(c[1]), str(c[1]))
				GameState.change_map(path, str(c[2]))
				return "__stop"
			"card":
				await show_card(str(c[1]), float(c[2]))
			"join":
				# v0.17 ["join", held, {"level_from": "dennis", "level_delta": -1, "gear": [...]}]
				var o: Dictionary = c[2] if c.size() > 2 else {}
				var lvl := int(o.get("level", 1))
				if o.has("level_from"):
					lvl = maxi(1, GameState.member_level(str(o["level_from"])) + int(o.get("level_delta", 0)))
				GameState.join_member(str(c[1]), lvl, o.get("gear", []))
			"heal":
				for h in GameState.party:
					h["hp"] = h["max_hp"]
					h["mp"] = h["max_mp"]
			"molen_zang":
				# Na de herkenning: wieken draaien, zacht gezang. Geen tekst.
				var wieken := actor(SD.MOLEN_NODE)
				if wieken != null and wieken.has_method("zing"):
					await wieken.zing()
			"molen":
				await Molen.bezoek()
			"glitch":
				# v0.17 ["glitch", sec]: één glitch-flits van de CRT-laag (ook buiten de dungeons)
				if Crt.has_method("start_glitch"):
					Crt.start_glitch(float(c[1]))
			_:
				push_warning("Story: onbekend commando '%s'" % op)
	return ""


## v0.17 Titel van de lopende opdracht (SD.QUESTS: start_flag gezet, done_flag niet), "" = geen.
func active_quest() -> String:
	for q in SD.QUESTS:
		if has_flag(str(q["start_flag"])) and not has_flag(str(q["done_flag"])):
			return str(q["title"])
	return ""


# ---------------------------------------------------------------- map
func map_key(path: String) -> String:
	for k in SD.MAPS:
		if SD.MAPS[k] == path:
			return k
	return ""


## Wordt door map.gd aangeroepen zodra een map klaar is.
func map_ready(map: Node) -> void:
	scheduled = {}
	_shake_left = 0.0
	var key := map_key(map.scene_file_path)
	if key != "":
		var t := _tint_node(map)
		t.color = SD.TINTS[tint_name()]
	refresh(map)
	if after_battle_event != "" and not GameState.in_battle:
		var ev := after_battle_event
		after_battle_event = ""
		GameState.pending_tutorial = {}
		_run_later(ev)
		return
	# v0.17: "map" = sleutel uit SD.MAPS of een volledig scènepad (Esdoorn, Donker Woud)
	for t in SD.MAP_ENTER:
		if (t["map"] == map.scene_file_path or (key != "" and t["map"] == key)) and check(t.get("if", {})):
			_run_later(str(t["event"]))
			return


func _run_later(ev: String) -> void:
	# eerst de map laten infaden. Alleen op díe map: een test of een uitgang
	# kan binnen 0,35 s al verder zijn, en dan hoort het event niet mee te reizen.
	_lock(true)
	var path := ""
	var hier := _map()
	if hier != null:
		path = str(hier.scene_file_path)
	await get_tree().create_timer(0.35).timeout
	var nu := _map()
	if nu == null or str(nu.scene_file_path) != path:
		return
	if not running:
		run(ev)


func tint_name() -> String:
	var out := "day"
	for r in SD.TINT_RULES:
		if check(r["if"]):
			out = r["tint"]
	return out


func _tint_node(map: Node) -> CanvasModulate:
	var t := map.get_node_or_null("StoryTint") as CanvasModulate
	if t == null:
		t = CanvasModulate.new()
		t.name = "StoryTint"
		map.add_child(t)
	return t


func tint_to(tint: String, sec: float) -> void:
	var m := _map()
	if m == null:
		return
	var t := _tint_node(m)
	var col: Color = SD.TINTS.get(tint, Color(tint) if tint.begins_with("#") else Color.WHITE)
	if sec <= 0.0:
		t.color = col
	else:
		create_tween().tween_property(t, "color", col, sec)


## Objecten met show_if/frame-regels opnieuw instellen (groep "story").
func refresh(map: Node) -> void:
	if map == null:
		return
	for n in get_tree().get_nodes_in_group("story"):
		if map.is_ancestor_of(n) and n.has_method("story_refresh"):
			n.story_refresh()


# ---------------------------------------------------------------- effecten
func shake(sec: float, strength: float) -> void:
	_shake_left = sec
	_shake_total = maxf(sec, 0.01)
	_shake_strength = strength


func shaking() -> bool:
	return _shake_left > 0.0


static var _beam_tex: Texture2D
static var _glow_tex: Texture2D


## Magisch licht door de ramen: een lichtbundel per raam-tile (additief) + de hele
## kamer even feller/rozer. Wacht niet.
func window_glow(sec: float) -> void:
	var m := _map()
	if m == null:
		return
	var ground: TileMapLayer = m.get_node("Ground")
	var holder := Node2D.new()
	holder.name = "WindowGlow"
	m.add_child(holder)
	var n := 0
	for cell in ground.get_used_cells():
		if ground.get_cell_atlas_coords(cell) != WINDOW_TILE or ground.get_cell_source_id(cell) != 0:
			continue
		if not str(ground.tile_set.get_source(0).texture.resource_path).ends_with("binnen.png"):
			continue
		var col := UiStyleC.MAGENTA if n % 2 == 0 else UiStyleC.CYAN
		n += 1
		var beam := Sprite2D.new()
		beam.texture = _beam()
		beam.centered = false
		beam.position = Vector2(cell * 16) + Vector2(-6, 6)
		beam.modulate = Color(col, 0.0)
		beam.material = _add_mat()
		holder.add_child(beam)
		var glow := Sprite2D.new()
		glow.texture = _glow()
		glow.position = Vector2(cell * 16) + Vector2(8, 10)
		glow.modulate = Color(col, 0.0)
		glow.material = _add_mat()
		holder.add_child(glow)
		for spr: Sprite2D in [beam, glow]:
			var tw := spr.create_tween()
			tw.tween_property(spr, "modulate:a", 0.95, 0.12)
			for i in 4:
				tw.tween_property(spr, "modulate:a", 0.55, 0.18)
				tw.tween_property(spr, "modulate:a", 0.9, 0.14)
			tw.tween_property(spr, "modulate:a", 0.0, maxf(0.5, sec - 1.4))
	var tint := _tint_node(m)
	var back := tint.color
	var tw2 := tint.create_tween()
	tw2.tween_property(tint, "color", Color(1.0, 0.82, 1.0), 0.15)
	tw2.tween_property(tint, "color", back, maxf(0.5, sec))
	get_tree().create_timer(sec + 0.6).timeout.connect(holder.queue_free)


func _add_mat() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _beam() -> Texture2D:
	if _beam_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 28
		t.height = 72
		_beam_tex = t
	return _beam_tex


func _glow() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 56
		t.height = 56
		_glow_tex = t
	return _glow_tex


## Zwart scherm met grote tekst (bv. "Wordt vervolgd"), daarna weer terug naar de map.
func show_card(text: String, sec: float) -> void:
	if _card_layer == null:
		_card_layer = CanvasLayer.new()
		_card_layer.layer = 105
		add_child(_card_layer)
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.color = Color(0.02, 0.02, 0.03)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.theme = load("res://assets/theme.tres")
		_card_layer.add_child(bg)
		card_label = Label.new()
		card_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card_label.add_theme_color_override("font_color", UiStyleC.MAGENTA)
		bg.add_child(card_label)
	card_label.text = text
	var bg: ColorRect = _card_layer.get_node("Bg")
	bg.modulate.a = 0.0
	_card_layer.show()
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.6)
	await tw.finished
	await get_tree().create_timer(sec).timeout
	tw = create_tween()
	tw.tween_property(bg, "modulate:a", 0.0, 0.6)
	await tw.finished
	_card_layer.hide()


func card_visible() -> bool:
	return _card_layer != null and _card_layer.visible


func _process(delta: float) -> void:
	# schudden: camera-offset
	if _shake_left > 0.0:
		_shake_left -= delta
		var p := _player()
		if p and "camera" in p:
			if _shake_left <= 0.0:
				p.camera.offset = Vector2.ZERO
			else:
				var k := _shake_strength * (_shake_left / _shake_total)
				p.camera.offset = Vector2(randf_range(-k, k), randf_range(-k, k)).round()
	# getimed event: telt alleen af als de speler vrij rondloopt
	if scheduled.is_empty() or running or Dialog.is_open or GameState.changing_map or GameState.in_battle:
		return
	var m := _map()
	if m == null or m.scene_file_path != scheduled.get("map", ""):
		scheduled = {}
		return
	var p := _player()
	if p == null or p.is_moving or (m.has_method("menu_open") and m.menu_open()):
		return
	scheduled["left"] = float(scheduled["left"]) - delta
	if scheduled["left"] <= 0.0:
		var ev: String = scheduled["event"]
		scheduled = {}
		run(ev)
