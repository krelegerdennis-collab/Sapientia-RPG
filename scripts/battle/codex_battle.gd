extends RefCounted
## Codex in het gevecht (Kernfragment stap 2). Houdt battle.gd klein: daar staan alleen
## haakjes die hierheen doorverwijzen.
##   - add_allies(): de actieve Codex-bondgenoot komt naast Dennis te staan (combatant met
##     "ally": true; telt als held voor doelwitten, genezen en KO, maar kiest zelf zijn actie)
##   - ally_actions(): elke ronde een automatische actie (niet als de party vlucht)
##   - ally_turn(): de AI (genezen / vaardigheid / gewone aanval, zie CodexData.DEFAULT_AI)
##   - capture(): het Leeg Boek (vangkans, baas weigert, inschrijf-effect, nieuwe pagina)
##   - victory_exp(): EXP en level-ups van de bondgenoot na de winst
## Regels staan in HANDOFF_CODEX.md.

const CodexData := preload("res://scripts/data/codex_data.gd")
const KamerData := preload("res://world_warper/kamers/kamers.gd")
const ActorSfx := preload("res://scripts/data/actor_sfx.gd")
const AllyScript := preload("res://scripts/battle/codex_ally.gd")
const StatusBoxScript := preload("res://scripts/battle/hero_status_box.gd")

var battle: Control
## Voor de codextest: >= 0 = vaste worp voor de vangkans (0.0 = altijd raak, 0.999 = mis).
var force_roll := -1.0
## Voor de codextest: vaste keuze van de AI ("" = normaal, "attack" of een vaardigheid-id).
var force_skill := ""
## Laatste vangpoging (voor de test en de HANDOFF): {"chance", "roll", "result", "species", "page"}
var last_capture := {}
## Laatste actie van de bondgenoot: {"kind": "attack"/"skill", "skill", "target"}
var last_ally_action := {}
var fx_node: Control = null


func _init(b: Control) -> void:
	battle = b


# ---------------------------------------------------------------- bondgenoot erbij
func add_allies() -> void:
	if not battle.tutorial.is_empty():
		return                                  # oefengevecht: alleen de helden
	var page: Dictionary = GameState.codex_active_page()
	if page.is_empty() or int(page["hp"]) <= 0:
		return
	var row: int = battle.heroes.size()
	var c: Dictionary = battle._make_combatant(str(page["name"]), page, true, row)
	c["ally"] = true
	c["page"] = str(page["uid"])
	battle.heroes.append(c)
	var node: Control = AllyScript.new()
	node.name = "Codex_" + str(page["uid"])
	battle.party_layer.add_child(node)
	node.setup_species(str(page["species"]), Vector2.ZERO)
	node.set_glitched(CodexData.is_fused(page))     # v0.19 glitch-fusie: paarse tint
	node.tapped.connect(battle._on_hero_tapped.bind(row))
	c["node"] = node
	battle.hero_nodes.append(node)
	var box: Control = StatusBoxScript.new()
	box.name = "Status_Codex"
	battle.status_bar.add_child(box)
	box.setup(page)
	box.tapped.connect(battle._on_hero_tapped.bind(row))
	battle.status_boxes.append(box)


static func is_ally(c) -> bool:
	return c is Dictionary and bool(c.get("ally", false))


func allies() -> Array:
	return battle.heroes.filter(func(c): return is_ally(c))


## Echte helden (zonder bondgenoot): zijn die allemaal KO, dan is het game over.
func party_down() -> bool:
	for c in battle.heroes:
		if not is_ally(c) and int(c["s"]["hp"]) > 0:
			return false
	return true


func ally_actions() -> Array:
	var out: Array = []
	for c in allies():
		if int(c["s"]["hp"]) > 0:
			out.append({"type": "codex_ally", "actor": c, "target": null})
	return out


# ---------------------------------------------------------------- AI
func ally_turn(a: Dictionary) -> void:
	var c: Dictionary = a["actor"]
	var page: Dictionary = c["s"]
	var sp := CodexData.species(str(page["species"]))
	var ai: Dictionary = sp["ai"]
	var foes: Array = battle._alive(battle.enemies)
	if foes.is_empty():
		return
	var heal_id := ""
	var attack_ids: Array = []
	for id in page["skills"]:
		var sk := CodexData.skill(str(id))
		if sk.is_empty() or int(page["mp"]) < int(sk.get("mp", 0)):
			continue
		if str(sk["type"]) == "heal":
			heal_id = str(id)
		elif str(sk["type"]) != "guard" or int(c.get("guard", 0)) <= 0:
			attack_ids.append(str(id))
	var choice := "attack"
	var heal_target = null
	if force_skill != "":
		choice = force_skill
	else:
		if heal_id != "" and float(ai["heal_below"]) > 0.0:
			var hurt: Array = battle._alive(battle.heroes).filter(func(h):
				return float(h["s"]["hp"]) < float(h["s"]["max_hp"]) * float(ai["heal_below"]))
			if not hurt.is_empty():
				hurt.sort_custom(func(x, y): return float(x["s"]["hp"]) / float(x["s"]["max_hp"]) < float(y["s"]["hp"]) / float(y["s"]["max_hp"]))
				heal_target = hurt[0]
				choice = heal_id
		if choice == "attack" and not attack_ids.is_empty() and randf() < float(ai["skill_chance"]):
			choice = str(attack_ids.pick_random())
	var target: Dictionary = _pick_foe(foes, str(ai["target"]))
	if choice == "attack" or not CodexData.SKILLS.has(choice):
		last_ally_action = {"kind": "attack", "skill": "", "target": target["name"]}
		battle.show_message("%s attacks!" % c["name"])
		ActorSfx.play(c, "aanval")
		await battle._hero_wind_up(c, true)
		await battle._damage(target, battle._physical_damage(c, target, 1.0))
		battle._hero_rest(c)
		return
	var sk := CodexData.skill(choice)
	page["mp"] = int(page["mp"]) - int(sk.get("mp", 0))
	var ally_t = null
	if str(sk["type"]) == "heal":
		ally_t = heal_target if heal_target != null else battle._valid_ally(null)
	last_ally_action = {"kind": "skill", "skill": choice, "target": (ally_t if ally_t != null else target)["name"]}
	battle.show_message("%s: %s!" % [c["name"], sk["name"]])
	if str(sk["type"]) != "guard":
		ActorSfx.play(c, "vaardigheid")
	match str(sk["type"]):
		"damage":
			await battle._hero_wind_up(c, true)
			await battle._damage(target, battle._physical_damage(c, target, float(sk["power"])))
		"all":
			await battle._hero_wind_up(c, false)
			for t in foes:
				battle._hit(t, battle._physical_damage(c, t, float(sk["power"])))
			await battle._wait(0.7)
			await battle._report_kos(foes)
		"heal":
			await battle._hero_wind_up(c, false)
			await battle._heal(ally_t, int(sk["power"]) + 2 * int(page["level"]), 0)
		"guard":
			await battle._guard_up(c, sk)
	battle._hero_rest(c)


func _pick_foe(foes: Array, how: String) -> Dictionary:
	var list := foes.duplicate()
	match how:
		"zwakste":
			list.sort_custom(func(x, y): return int(x["s"]["hp"]) < int(y["s"]["hp"]))
			return list[0]
		"sterkste":
			list.sort_custom(func(x, y): return int(x["s"]["hp"]) > int(y["s"]["hp"]))
			return list[0]
	return list.pick_random()


# ---------------------------------------------------------------- vangen
## Kans voor vijand-combatant 't' (0 bij een baas of een soort die niet in de Codex past).
func chance_for(t: Dictionary) -> float:
	return CodexData.capture_chance(CodexData.species_for_enemy(str(t.get("id", ""))),
			int(t["s"]["hp"]), int(t["s"]["max_hp"]), _is_boss(t))


func _is_boss(t: Dictionary) -> bool:
	return GameState.pending_boss or t.has("core")


## v0.19 Codex-knop: wat het doel-label bij 'Vangen' laat zien. Dezelfde volgorde als capture():
## baas -> "te machtig", geen Codex-soort -> "past niet", Codex vol -> "Codex vol", anders "35%".
func capture_hint(t: Dictionary) -> String:
	var sid := CodexData.species_for_enemy(str(t.get("id", "")))
	if _is_boss(t):
		return "too strong"
	if sid == "" or not bool(CodexData.species(sid)["capturable"]):
		return "won't fit"
	if GameState.codex_full():
		return "Codex full"
	return "%d%%" % roundi(chance_for(t) * 100.0)


# ---------------------------------------------------------------- v0.19 bondgenoot wisselen
## Laatste wissel (voor de test): {"from": uid of "", "to": uid of "", "result": ...}
var last_swap := {}


## uid van de bondgenoot die nu meevecht ("" = geen).
func current_ally_uid() -> String:
	var al := allies()
	return str(al[0].get("page", "")) if not al.is_empty() else ""


## Pagina's waarmee je kunt wisselen: alleen niet-KO pagina's (volgorde van de Codex).
func swap_choices() -> Array:
	return GameState.codex_pages.filter(func(p): return int(p["hp"]) > 0)


## Kan er überhaupt gewisseld worden? (iets anders dan de huidige keuze)
func can_swap() -> bool:
	if not battle.tutorial.is_empty():
		return false
	var cur := current_ally_uid()
	if cur != "":
		return true                              # 'Geen' kan altijd
	return not swap_choices().is_empty()


## De wissel zelf (actie van de held, kost zijn beurt). a["page"] = uid of "" (= 'Geen').
## De oude bondgenoot gaat terug in de Codex (zijn HP/MP blijven op zijn pagina staan), de
## nieuwe komt op dezelfde plek (rij) naast de helden en handelt vanaf de VOLGENDE ronde.
func swap_ally(a: Dictionary) -> void:
	var uid := str(a.get("page", ""))
	var cur := current_ally_uid()
	last_swap = {"from": cur, "to": uid, "result": "bezig"}
	if uid == cur:
		last_swap["result"] = "zelfde"
		return
	if uid != "":
		var page := GameState.codex_page(uid)
		if page.is_empty() or int(page["hp"]) <= 0:
			last_swap["result"] = "ko"
			await battle.say("%s can't fight anymore." % str(page.get("name", "That page")))
			return
	var old_name := ""
	for c in allies():
		old_name = str(c["name"])
		_remove_ally(c)
	GameState.codex_set_active(uid)
	if uid != "":
		add_allies()
	battle._layout()
	battle._refresh_party()
	last_swap["result"] = "gewisseld"
	var text := ""
	if old_name != "":
		text = "%s returns to the Codex." % old_name
	if uid != "":
		text = (text + "\n" if text != "" else "") + "%s leaps out of the Codex!" % str(GameState.codex_page(uid)["name"])
	await battle.say(text)


func _remove_ally(c: Dictionary) -> void:
	var idx := -1
	for i in battle.heroes.size():
		if battle.heroes[i]["uid"] == c["uid"]:      # op uid (niet op inhoud vergelijken)
			idx = i
	if idx < 0:
		return
	battle.heroes.remove_at(idx)
	var node = c.get("node")
	var ni: int = battle.hero_nodes.find(node)
	if ni >= 0:
		battle.hero_nodes.remove_at(ni)
	if node != null and is_instance_valid(node):
		node.get_parent().remove_child(node)
		node.queue_free()
	if idx < battle.status_boxes.size():
		var box: Control = battle.status_boxes[idx]
		battle.status_boxes.remove_at(idx)
		box.get_parent().remove_child(box)
		box.queue_free()


## Het Leeg Boek is al van de stapel gehaald (battle.gd); bij een weigering komt het terug.
func capture(actor: Dictionary, target) -> void:
	var item := CodexData.BOOK_ITEM
	if GameState.practice_battle:
		_refund(item)
		await battle.say(KamerData.OEFEN_VANGEN)
		return
	var t = battle._valid_target(target, false)
	if t == null:
		_refund(item)
		return
	var sid := CodexData.species_for_enemy(str(t.get("id", "")))
	if _is_boss(t):
		_refund(item)
		last_capture = {"result": "baas", "chance": 0.0, "species": sid}
		await battle.say("%s is too strong! A boss won't be written in. (The book stays whole.)" % t["name"])
		return
	if sid == "" or not bool(CodexData.species(sid)["capturable"]):
		_refund(item)
		last_capture = {"result": "geen_soort", "chance": 0.0, "species": sid}
		await battle.say("%s doesn't fit in the Codex. (The book stays whole.)" % t["name"])
		return
	if GameState.codex_full():
		_refund(item)
		last_capture = {"result": "vol", "chance": 0.0, "species": sid}
		await battle.say("The Codex is full (%d pages). (The book stays whole.)" % CodexData.MAX_PAGES)
		return
	var chance := chance_for(t)
	var roll := force_roll if force_roll >= 0.0 else randf()
	var ok := roll < chance
	last_capture = {"result": "bezig", "chance": chance, "roll": roll, "species": sid}
	await _play_inscribe(actor, t, ok)
	if not ok:
		last_capture["result"] = "mislukt"
		battle._blink(t["node"])
		await battle.say("The book stays blank... %s slips out! (chance %d%%)" % [t["name"], roundi(chance * 100.0)])
		return
	# gelukt: weg uit het gevecht (telt niet als verslagen: geen EXP/goud/buit voor dit monster)
	t["s"]["hp"] = 0
	t["captured"] = true
	t["reported_ko"] = true
	var caught := {"tier": GameState.pending_tier, "play_time": int(GameState.play_time())}
	var page: Dictionary = GameState.codex_add(sid, CodexData.capture_level(GameState.pending_tier, sid), caught)
	GameState.unique_mark(str(t.get("id", "")), "gevangen")     # v0.19: uniek monster komt nooit terug
	last_capture["result"] = "gelukt"
	last_capture["page"] = str(page.get("uid", ""))
	var skills: Array = (page["skills"] as Array).map(func(x): return str(CodexData.skill(x)["name"]))
	await battle.say("%s is written into the Codex!\nPage %d: Lv %d, %s." % [t["name"], GameState.codex_pages.size(),
			int(page["level"]), ", ".join(skills)], false)
	await battle._wait(0.6)


func _refund(item: String) -> void:
	GameState.inventory[item] = GameState.item_count(item) + 1


## Boek vliegt naar het monster, dan het inschrijf-effect (RPG ART: 4 frames van 48x48, 0,1 s per
## frame, NIET loopen, midden (24,24) op het midden van het monster). Bij succes vervaagt en krimpt
## het monster tijdens frame 2-3 (t = 0,1..0,3 s); in frame 4 is hij weg.
func _play_inscribe(actor: Dictionary, t: Dictionary, success: bool) -> void:
	var enemy_node: Control = t["node"]
	var center: Vector2 = enemy_node.position + enemy_node.size * 0.5
	var start: Vector2 = actor["node"].head_position() if actor.get("node") != null else center + Vector2(-80, 60)
	var book := _book_icon()
	battle.add_child(book)
	book.position = (start - Vector2(8, 8)).round()
	var tw := battle.create_tween()
	tw.tween_property(book, "position", (center - Vector2(8, 8)).round(), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	book.queue_free()
	var fx_scale := float(CodexData.species(str(last_capture.get("species", ""))).get("fx_scale", 1.0))
	fx_node = _inscribe_fx()
	battle.add_child(fx_node)
	fx_node.scale = Vector2(fx_scale, fx_scale)
	fx_node.position = (center - Vector2(24, 24) * fx_scale).round()
	var ft := CodexData.INSCRIBE_FRAME_TIME
	if success:
		enemy_node.pivot_offset = enemy_node.size * 0.5
		var tw2 := battle.create_tween().set_parallel(true)
		tw2.tween_property(enemy_node, "modulate:a", 0.0, ft * 2.0).set_delay(ft)
		tw2.tween_property(enemy_node, "scale", Vector2.ZERO, ft * 2.0).set_delay(ft)
	for f in CodexData.INSCRIBE_FRAMES:
		fx_node.set("frame", f)
		await battle._wait(ft)
	if success:
		enemy_node.hide()
	await battle._wait(0.15)
	if is_instance_valid(fx_node):
		fx_node.queue_free()
	fx_node = null
	if not success and is_instance_valid(enemy_node):
		enemy_node.modulate.a = 1.0


func _book_icon() -> Control:
	if ResourceLoader.exists(CodexData.BOOK_ICON):
		var r := TextureRect.new()
		r.texture = load(CodexData.BOOK_ICON)
		r.size = Vector2(16, 16)
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_meta("placeholder", false)
		return r
	var p := BookPlaceholder.new()
	p.set_meta("placeholder", true)
	return p


func _inscribe_fx() -> Control:
	if ResourceLoader.exists(CodexData.INSCRIBE_EFFECT):
		var fx := InscribeSprite.new()
		fx.setup(load(CodexData.INSCRIBE_EFFECT))
		return fx
	return InscribePlaceholder.new()


## 16x16 boekje (plaatsvervanger tot RPG ART het icoon levert).
class BookPlaceholder extends Control:
	func _init() -> void:
		size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(2, 2, 12, 12), Color("5a3a24"))          # kaft
		draw_rect(Rect2(4, 3, 9, 10), Color("efe3c2"))           # lege bladzijden
		draw_rect(Rect2(2, 2, 2, 12), Color("8a5a32"))           # rug
		draw_rect(Rect2(8, 7, 3, 1), Color("e0b84a"))            # gouden glans


## Inschrijf-animatie van RPG ART: 4 frames van 48x48 naast elkaar.
class InscribeSprite extends Control:
	var frame := 0:
		set(v):
			frame = v
			if _s:
				_s.frame = clampi(v, 0, _s.hframes - 1)
	var _s: Sprite2D

	func setup(tex: Texture2D) -> void:
		size = Vector2(48, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_s = Sprite2D.new()
		_s.texture = tex
		_s.centered = false
		_s.hframes = maxi(1, roundi(float(tex.get_width()) / maxf(1.0, float(tex.get_height()))))
		_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_s)


## Plaatsvervanger (getekend): een open boek met gouden letters die naar het midden zuigen.
class InscribePlaceholder extends Control:
	var frame := 0:
		set(v):
			frame = v
			queue_redraw()

	func _init() -> void:
		size = Vector2(48, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(24, 24)
		var gold := Color("f2cf63")
		var teal := Color("6fe0d2")
		var r := 22.0 - frame * 5.0
		draw_circle(c, r + 1.0, Color(1.0, 0.85, 0.35, 0.18 + 0.08 * frame))      # zachte gouden gloed
		draw_arc(c, r + 1.0, 0.0, TAU, 32, Color(gold, 0.9), 1.0)
		for i in 10:                                                          # letters/runen zuigen naar binnen
			var ang := TAU * i / 10.0 + frame * 0.4
			var p := (c + Vector2(cos(ang), sin(ang)) * r).round()
			var col := gold if i % 2 == 0 else teal
			draw_rect(Rect2(p - Vector2(1, 2), Vector2(3, 4)), col)
			draw_rect(Rect2(p - Vector2(1, 2), Vector2(3, 1)), Color.WHITE)
		# open boek in het midden, groeit per frame
		var w := 7.0 + frame * 2.0
		draw_rect(Rect2(c.x - w - 1.0, c.y - 6.0, w * 2.0 + 2.0, 12.0), Color("5a3a24"))
		draw_rect(Rect2(c.x - w, c.y - 5.0, w, 10.0), Color("efe3c2"))
		draw_rect(Rect2(c.x, c.y - 5.0, w, 10.0), Color("e3d4ab"))
		draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color("5a3a24"), 1.0)
		for k in mini(frame + 1, 4):                                          # regels verschijnen
			draw_line(Vector2(c.x - w + 2.0, c.y - 3.0 + k * 2.0), Vector2(c.x - 2.0, c.y - 3.0 + k * 2.0), Color("8a6a44"), 1.0)
		if frame >= 3:                                                        # flits: ingeschreven
			for i in 8:
				var ang := TAU * i / 8.0
				draw_line(c + Vector2(cos(ang), sin(ang)) * 9.0, c + Vector2(cos(ang), sin(ang)) * 20.0, Color(1, 1, 0.8, 0.85), 1.0)


# ---------------------------------------------------------------- EXP na de winst
## Geeft de EXP aan de bondgenoot (alleen als hij nog staat) en geeft de level-up-pagina's terug.
func victory_exp(exp_total: int) -> Array[String]:
	var pages: Array[String] = []
	for c in allies():
		var s: Dictionary = c["s"]
		if int(s["hp"]) <= 0 or exp_total <= 0:
			continue
		var before: Dictionary = s.duplicate(true)
		var msgs := CodexData.give_exp(s, exp_total)
		if msgs.is_empty():
			continue
		var gains := "HP+%d" % (int(s["max_hp"]) - int(before["max_hp"]))
		if int(s["max_mp"]) > int(before["max_mp"]):
			gains += " MP+%d" % (int(s["max_mp"]) - int(before["max_mp"]))
		gains += " ATK+%d DEF+%d SPD+%d" % [int(s["atk"]) - int(before["atk"]), int(s["def"]) - int(before["def"]),
				int(s["agi"]) - int(before["agi"])]
		var lv_msgs := msgs.filter(func(m): return " level " in m)
		var learn := msgs.filter(func(m): return not (" level " in m))
		var text := "%s\n%s" % [lv_msgs[lv_msgs.size() - 1], gains]
		if not learn.is_empty():
			text += "\n" + "\n".join(learn)
		pages.append(text)
	return pages
