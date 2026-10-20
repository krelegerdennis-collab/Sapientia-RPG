extends "res://scripts/battle/battle.gd"
## Headless gevechtssimulator (tools/battlesim). GEEN gameplay: dit script hangt alleen in de
## simulator aan een kopie van scenes/battle/battle.tscn.
##
## Wat ECHT is (ongewijzigd uit battle.gd): _ready (combatanten, vijand-schaal: tier/archief/
## dungeon100/baas), _execute (aanval, skills, spreuken, items, kern, Golem-kern, archief2),
## _physical_damage, _spell_amount, buffs/hots/dots, _tick_ailments, _guard_tick, _kern_tick,
## Archief2Vijanden.tick, de beurtvolgorde (agi + randf()*3) en de win/verlies-check.
## Wat hier vervangen is: alleen wachten, animaties, muziek, het keuzemenu (-> eenvoudige AI)
## en het einde (geen EXP, geen scènewissel; alleen het resultaat bewaren).

signal sim_done

const AI_HEAL_BELOW := 0.40     # heal-drempel (fractie van max HP)
const AI_MP_BELOW := 0.25       # Toverwater als MP onder deze fractie (alleen casters)
const MAX_ROUNDS := 60          # vangnet: daarboven telt het als verlies ("timeout")

var sim_trace := false          # true = elk bericht printen (--trace)
var sim_ban_elements: Array = []  # AI gebruikt geen schade-spreuken van deze elementen (gevoeligheid)
var sim_started := false
var sim_result := ""            # "win" | "lose" | "timeout"
var sim_rounds := 0
var sim_items_used := {}        # item-id -> aantal
var sim_mp_used := 0
var sim_actions := {}           # type -> aantal (heldenacties)


# ------------------------------------------------------------- stil: geen tijd, geen beeld/geluid
func _enter_detail_mode() -> void:
	pass

func _exit_tree() -> void:
	pass

func _start_battle_music() -> void:
	pass

func _wait(_seconds: float) -> void:
	pass

func show_message(text: String) -> void:
	if sim_trace and text != "":
		print("  [r%d] %s" % [round_no, text])


func say(text: String, _wait_for_input := false) -> void:
	show_message(text)

func _hero_wind_up(_actor: Dictionary, _is_attack: bool) -> void:
	pass

func _enemy_lunge(_actor: Dictionary, _target: Dictionary) -> void:
	pass

func _kern_fireball(_actor: Dictionary, _t: Dictionary) -> void:
	pass

func _popup_number(_t: Dictionary, _text: String, _color: Color) -> void:
	pass

func _shake(_node: Control, _strength: float) -> void:
	pass

func _blink(_node: CanvasItem) -> void:
	pass

func _show_hit_frame(_node: Control) -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _layout() -> void:
	pass


# ------------------------------------------------------------- einde: alleen het resultaat
func _victory() -> void:
	_finish("win")

func _defeat() -> void:
	_finish("lose")

func _finish(result: String) -> void:
	if sim_result != "":
		return
	sim_result = result
	sim_rounds = round_no
	sim_done.emit()


# ------------------------------------------------------------- de rondelus (zoals battle.gd _run)
## Zelfde volgorde als battle.gd _run, zonder fade/wachten. Alle effecten via de echte functies.
func _run() -> void:
	if sim_started:
		return
	sim_started = true
	await _core_hint()
	if await _archief2_opening():
		return
	while sim_result == "":
		round_no += 1
		if round_no > MAX_ROUNDS:
			sim_result = "timeout"
			sim_rounds = MAX_ROUNDS
			sim_done.emit()
			return
		await _core_round_start()
		var plan: Array = _choose_commands()
		plan.append_array(codex.ally_actions())
		for e in _alive(enemies):
			if e.has("core") and e["core"].open:
				plan.append({"type": "core_charge", "actor": e, "target": null})
			elif bool(e["s"].get("archief2_leech", false)):
				plan.append({"type": "archief2_leech", "actor": e, "target": null})
			else:
				plan.append({"type": "attack", "actor": e, "target": null})
		for a in plan:
			a["speed"] = float(a["actor"]["s"]["agi"]) * _buff_mult(a["actor"], "agi") + randf() * 3.0
			if a["type"] == "core_charge":
				a["speed"] = -1000.0
			if a["type"] == "defend":
				a["actor"]["defending"] = true
		plan.sort_custom(func(a, b): return a["speed"] > b["speed"])
		last_plan = plan.duplicate()
		for a in plan:
			if a["actor"]["s"]["hp"] <= 0:
				continue
			_count_action(a)
			await _execute(a)
			if _alive(enemies).is_empty():
				await _victory()
				return
			if codex.party_down():
				await _defeat()
				return
		for c in heroes + enemies:
			c["defending"] = false
			_guard_tick(c)
			Archief2Vijanden.tick(c)
			_kern_tick(c)
			_tick_ailments(c)
		if _alive(enemies).is_empty():
			await _victory()
			return
		if codex.party_down():
			await _defeat()
			return
		_reserved.clear()


func _count_action(a: Dictionary) -> void:
	var actor: Dictionary = a["actor"]
	if not actor.get("is_hero", false) or actor.get("ally", false):
		return
	var t: String = a["type"]
	sim_actions[t] = int(sim_actions.get(t, 0)) + 1
	if t == "item":
		var id: String = a["item"]
		if GameState.item_count(id) > 0:
			sim_items_used[id] = int(sim_items_used.get(id, 0)) + 1
	elif t == "spell":
		var sp: Dictionary = GameData.SPELLS[a["spell"]]
		if int(actor["s"]["mp"]) >= int(sp["mp"]) and int(actor.get("skip", 0)) <= 0:
			sim_mp_used += int(sp["mp"])


# ------------------------------------------------------------- eenvoudige AI (vervangt het menu)
## Per held, in deze volgorde:
## 1. iemand (levend) onder AI_HEAL_BELOW: genees-spreuk (als MP genoeg), anders het kleinste
##    genees-item dat het gat dekt (Drankje/Kruid/...), anders verder;
## 2. KO-bondgenoot + Feniksveer/revive-spreuk: opwekken;
## 3. caster met weinig MP en Toverwater: drinken;
## 4. kernvaardigheid klaar: op de vijand met de meeste HP;
## 5. schade-spreuk: groepsspreuk als >= 2 vijanden leven, anders de sterkste enkele
##    spreuk, alleen als de spreuk naar verwachting meer doet dan een gewone aanval;
## 6. aanvallen: de vijand met de minste HP (afmaken).
func _choose_commands() -> Array:
	var actions: Array = []
	_reserved.clear()
	var planned_heal := {}   # uid -> true (niet twee keer dezelfde genezen)
	for h in heroes:
		if int(h["s"]["hp"]) <= 0 or h.get("ally", false):
			continue
		var a := _ai_action(h, planned_heal)
		if a.get("type", "") == "item":
			_reserved[a["item"]] = int(_reserved.get(a["item"], 0)) + 1
		actions.append(a)
	return actions


func _ai_action(h: Dictionary, planned_heal: Dictionary) -> Dictionary:
	var s: Dictionary = h["s"]
	var foes := _alive(enemies)
	# 1. genezen
	var hurt: Dictionary = {}
	for x in _alive(heroes):
		if x.get("ally", false) or planned_heal.has(x["uid"]):
			continue
		var frac := float(x["s"]["hp"]) / float(maxi(1, int(x["s"]["max_hp"])))
		if frac < AI_HEAL_BELOW and (hurt.is_empty() or frac < float(hurt["s"]["hp"]) / float(hurt["s"]["max_hp"])):
			hurt = x
	if not hurt.is_empty():
		var sp_id := _best_spell(h, "heal")
		if sp_id != "":
			planned_heal[hurt["uid"]] = true
			return {"type": "spell", "actor": h, "spell": sp_id, "target": hurt}
		var it := _best_heal_item(int(hurt["s"]["max_hp"]) - int(hurt["s"]["hp"]))
		if it != "":
			planned_heal[hurt["uid"]] = true
			return {"type": "item", "actor": h, "item": it, "target": hurt}
	# 2. opwekken
	var down: Dictionary = {}
	for x in heroes:
		if int(x["s"]["hp"]) <= 0 and not x.get("ally", false) and not planned_heal.has(x["uid"]):
			down = x
			break
	if not down.is_empty():
		var rv := _best_spell(h, "revive")
		if rv != "":
			planned_heal[down["uid"]] = true
			return {"type": "spell", "actor": h, "spell": rv, "target": down}
		if _items_left("feniksveer") > 0:
			planned_heal[down["uid"]] = true
			return {"type": "item", "actor": h, "item": "feniksveer", "target": down}
	# 3. MP bijvullen
	if int(s["max_mp"]) > 0 and float(s["mp"]) / float(s["max_mp"]) < AI_MP_BELOW and not (s["spells"] as Array).is_empty():
		var mp_it := _best_mp_item(int(s["max_mp"]) - int(s["mp"]))
		if mp_it != "":
			return {"type": "item", "actor": h, "item": mp_it, "target": h}
	if foes.is_empty():
		return {"type": "defend", "actor": h}
	var weakest: Dictionary = foes[0]
	var strongest: Dictionary = foes[0]
	for f in foes:
		if int(f["s"]["hp"]) < int(weakest["s"]["hp"]):
			weakest = f
		if int(f["s"]["hp"]) > int(strongest["s"]["hp"]):
			strongest = f
	# 4. kernvaardigheid
	for kid in _kern_skills(h):
		if kern_ready(h, kid):
			return {"type": "kern_skill", "actor": h, "skill": kid, "target": strongest}
	# 5. schade-spreuk (verwachte schade vergelijken met een gewone aanval)
	var atk_dmg := maxf(1.0, float(s["atk"]) * _buff_mult(h, "atk") - _defense_of(weakest) / 2.0)
	var best_id := ""
	var best_val := atk_dmg * 1.15   # spreuk moet duidelijk beter zijn dan slaan (MP sparen)
	for id in s["spells"]:
		var sp: Dictionary = GameData.SPELLS[id]
		if str(sp.get("type", "damage")) != "damage" or int(s["mp"]) < int(sp["mp"]):
			continue
		if sim_ban_elements.has(str(sp.get("element", ""))):
			continue
		var tgt: Dictionary = strongest if sp["target"] == "enemy" else weakest
		var one := SpellRules.power_at(sp, int(s.get("level", 1))) * SpellRules.factor(sp, str(s.get("id", "")), tgt)
		var val := one * (foes.size() if sp["target"] == "all_enemies" else 1)
		if val > best_val:
			best_val = val
			best_id = id
	if best_id != "":
		var spd: Dictionary = GameData.SPELLS[best_id]
		return {"type": "spell", "actor": h, "spell": best_id, "target": strongest if spd["target"] == "enemy" else null}
	# 6. aanvallen
	return {"type": "attack", "actor": h, "target": weakest}


func _best_spell(h: Dictionary, kind: String) -> String:
	var best := ""
	var best_pow := -1.0
	for id in h["s"]["spells"]:
		var sp: Dictionary = GameData.SPELLS[id]
		if str(sp.get("type", "")) != kind or int(h["s"]["mp"]) < int(sp["mp"]):
			continue
		if kind == "heal" and not (sp["target"] in ["ally", "all_allies"]):
			continue
		var p := SpellRules.power_at(sp, int(h["s"].get("level", 1)))
		if p > best_pow:
			best_pow = p
			best = id
	return best


func _best_heal_item(gap: int) -> String:
	# kleinste item dat het gat dekt, anders het grootste
	var best := ""
	var best_hp := 0
	for id in GameData.ITEMS:
		var it: Dictionary = GameData.ITEMS[id]
		var hp := int(it.get("heal_hp", 0))
		if hp <= 0 or _items_left(id) <= 0 or bool(it.get("capture", false)):
			continue
		if best == "" or (hp >= gap and (best_hp < gap or hp < best_hp)) or (best_hp < gap and hp > best_hp):
			best = id
			best_hp = hp
	return best


func _best_mp_item(gap: int) -> String:
	var best := ""
	var best_mp := 0
	for id in GameData.ITEMS:
		var it: Dictionary = GameData.ITEMS[id]
		var mp := int(it.get("heal_mp", 0))
		if mp <= 0 or int(it.get("heal_hp", 0)) > 0 or _items_left(id) <= 0:
			continue
		if best == "" or (mp >= gap and (best_mp < gap or mp < best_mp)) or (best_mp < gap and mp > best_mp):
			best = id
			best_mp = mp
	return best
