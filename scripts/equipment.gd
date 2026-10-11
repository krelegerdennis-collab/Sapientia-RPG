extends RefCounted
## v0.14 (RPG CODE, menu L2) UITRUSTING: alle regels, geen UI. Gebruikt door GameState
## (opslaan/laden, level-up, wapen uit het verhaal), het Uitrusting-scherm en de menutest.
## Data (vakken, stats, de beginnersset) staat in scripts/data/game_data.gd (EQUIP_*,
## EQUIPMENT) en is een VOORSTEL uit story/ITEMS_ELEMENTEN.md.
##
## Opbouw van een held (Dictionary in GameState.party):
##   h["base"]  = {"atk", "def", "mag", "mdef", "agi"}  basiswaarden (level + groei, ZONDER uitrusting)
##   h["equip"] = {"wapen": id, "schild": id, "helm": id, "harnas": id, "accessoire": id}  ("" = leeg)
##   h["atk"], h["def"], h["mag"], h["mdef"], h["agi"] = EFFECTIEVE waarde = basis + uitrusting.
##       Die worden ALLEEN door refresh() geschreven (de ene functie: effective_stats()).
##       Het gevecht (battle.gd, van Forge) leest h["atk"]/h["def"]/h["agi"] al zo, dus de
##       uitrusting telt daar meteen mee zonder dat battle.gd verandert.
##   h["weapon"] = kopie van h["equip"]["wapen"] (oud veld van v0.11, blijft voor oude code/saves).
## Basiswaarden aanpassen (level-up, boost)? Via grow() of h["base"] + refresh(), NOOIT
## rechtstreeks h["atk"] += ..., want refresh() rekent dat opnieuw uit.
##
## Spullen: een uitrustingsstuk zit OF in GameState.inventory (id -> aantal) OF in één vak
## van één held. Uitrusten haalt er 1 uit de tas, afdoen legt hem terug: er gaat nooit iets
## verloren of dubbel (alleen Weggooien haalt iets echt weg).
## (preload i.p.v. class_name, zoals party_actions.gd)

const GameData := preload("res://scripts/data/game_data.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")

const MSG_NOT_OWNED := "You don't have that."
const MSG_WRONG_SLOT := "That doesn't fit this slot."
const MSG_CANT_WEAR := "%s can't wear this."
const MSG_EMPTY_SLOT := "This slot is already empty."
const MSG_EQUIPPED := "%s now wears %s."
const MSG_REMOVED := "%s goes back in the bag."
const MSG_ALL_REMOVED := "Everything goes back in the bag."
const MSG_NOTHING_ON := "%s isn't wearing anything."
const MSG_DROPPED := "%s dropped."
const MSG_STRONGEST := "Best equipment chosen."
const MSG_STRONGEST_SAME := "This is already the best equipment."


static func slots() -> Array:
	return GameData.EQUIP_SLOTS


static func stats() -> Array:
	return GameData.EQUIP_STATS


static func slot_name(slot: String) -> String:
	return str(GameData.EQUIP_SLOT_NAMES.get(slot, slot))


static func stat_label(stat: String) -> String:
	return str(GameData.STAT_LABELS.get(stat, stat.to_upper()))


static func item(id: String) -> Dictionary:
	if GameData.EQUIPMENT.has(id):
		var it = GameData.EQUIPMENT[id]
		return it if it is Dictionary else {}
	return GradeGear.item(id)


static func is_equipment(id: String) -> bool:
	return GameData.EQUIPMENT.has(id) or GradeGear.has_item(id)


static func item_name(id: String) -> String:
	return str(item(id).get("name", id)) if id != "" else "-"


static func slot_of(id: String) -> String:
	return str(item(id).get("slot", ""))


## Bonus van één stuk op één stat (0 als het stuk of de stat er niet is).
static func item_bonus(id: String, stat: String) -> int:
	var it := item(id)
	var v = it.get(stat, 0)
	var total := int(v) if (v is int or v is float) else 0
	var ax = it.get("affixen", [])
	if ax is Array:
		for a in ax:
			if a is Dictionary and str(a.get("stat", "")) == stat:
				var n = a.get("n", 0)
				if n is int or n is float:
					total += int(n)
	return total


## "ATK +3, SPD -1" (voor de hulpregel en het Items-scherm).
static func bonus_text(id: String) -> String:
	var parts: Array[String] = []
	for s in stats():
		var b := item_bonus(id, s)
		if b != 0:
			parts.append("%s %s%d" % [stat_label(s), "+" if b > 0 else "", b])
	return ", ".join(parts) if not parts.is_empty() else "no bonus"


## Mag deze held dit stuk dragen? ("wie" = lijst van equip_type's; geen "wie" = iedereen)
static func can_wear(hero: Dictionary, id: String) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	if it.has("wie") and not (str(hero.get("equip_type", "")) in it["wie"]):
		return false
	var set_id := str(it.get("set_id", ""))
	if set_id == "":
		return true
	var worn := equip_of(hero)
	for s in slots():
		var other := str(worn.get(s, ""))
		if other == "" or other == id:
			continue
		var other_set := str(item(other).get("set_id", ""))
		if other_set != "" and other_set != set_id:
			return false
	return true


static func empty_equip() -> Dictionary:
	var e := {}
	for s in slots():
		e[s] = ""
	return e


## De vakken van een held (maakt ze aan als ze ontbreken, bv. een held van een oude save).
static func equip_of(hero: Dictionary) -> Dictionary:
	if not (hero.get("equip") is Dictionary):
		hero["equip"] = empty_equip()
	var e: Dictionary = hero["equip"]
	for s in slots():
		if not e.has(s) or not (e[s] is String):
			e[s] = ""
	return e


static func equipped(hero: Dictionary, slot: String) -> String:
	return str(equip_of(hero).get(slot, ""))


## Som van de bonussen van alle gedragen stukken op één stat.
static func equip_bonus(hero: Dictionary, stat: String) -> int:
	var total := 0
	for s in slots():
		total += item_bonus(equipped(hero, s), stat)
	return total


## Basiswaarden (zonder uitrusting). Ontbreken ze (held van vóór v0.14 of een losse
## test-Dictionary), dan worden ze afgeleid: huidige waarde min de gedragen bonus.
static func base_of(hero: Dictionary) -> Dictionary:
	if not (hero.get("base") is Dictionary):
		var b := {}
		for s in stats():
			b[s] = int(hero.get(s, 0)) - equip_bonus(hero, s)
		hero["base"] = b
	var base: Dictionary = hero["base"]
	for s in stats():
		if not (base.get(s) is int or base.get(s) is float):
			base[s] = int(hero.get(s, 0)) - equip_bonus(hero, s)
		base[s] = int(base[s])
	return base


## ===== DE functie voor effectieve stats =====
## Effectief = basis + alle uitrusting, minimaal 0. Alleen de uitrustingsstats (atk, def,
## mag, mdef, agi); max_hp/max_mp veranderen (nog) niet door uitrusting.
static func effective_stats(hero: Dictionary) -> Dictionary:
	var base := base_of(hero)
	var out := {}
	for s in stats():
		out[s] = maxi(0, int(base[s]) + equip_bonus(hero, s))
	return out


static func effective_stat(hero: Dictionary, stat: String) -> int:
	if stat in stats():
		return int(effective_stats(hero)[stat])
	return int(hero.get(stat, 0))


## Schrijft de effectieve waarden in h["atk"] e.d. (zodat het gevecht ze ziet) en houdt
## h["weapon"] gelijk aan het wapenvak.
static func refresh(hero: Dictionary) -> void:
	equip_of(hero)
	var eff := effective_stats(hero)
	for s in eff:
		hero[s] = eff[s]
	hero["weapon"] = equipped(hero, "wapen")


## Nieuwe held (uit GameData.HEROES): basis = de waarden uit de data, lege vakken.
static func init_hero(hero: Dictionary) -> void:
	hero["equip"] = empty_equip()
	var b := {}
	for s in stats():
		b[s] = int(hero.get(s, 0))
	hero["base"] = b
	refresh(hero)


## Level-up: groei op de basis (atk/def/mag/mdef/agi), daarna opnieuw uitrekenen.
static func grow(hero: Dictionary, growth: Dictionary) -> void:
	var base := base_of(hero)
	for s in stats():
		var g = growth.get(s, 0)
		base[s] = int(base[s]) + (int(g) if (g is int or g is float) else 0)
	refresh(hero)


## Stats ALS dit vak 'new_id' zou hebben ("" = leeg). Verandert de held niet.
static func preview(hero: Dictionary, slot: String, new_id: String) -> Dictionary:
	var copy := {"base": base_of(hero).duplicate(), "equip": equip_of(hero).duplicate()}
	copy["equip"][slot] = new_id
	return effective_stats(copy)


## Per stat: 1 = beter (groen, omhoog), -1 = slechter (rood, omlaag), 0 = gelijk.
static func compare(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for s in stats():
		out[s] = signi(int(after.get(s, 0)) - int(before.get(s, 0)))
	return out


## Stukken uit de tas die in dit vak passen en die deze held mag dragen (volgorde = data).
static func candidates(hero: Dictionary, inventory: Dictionary, slot: String) -> Array:
	var out: Array = []
	var seen := {}
	for id in GameData.EQUIPMENT:
		if int(inventory.get(id, 0)) > 0 and slot_of(id) == slot and can_wear(hero, id):
			out.append(id)
			seen[id] = true
	for id in inventory:
		var sid := str(id)
		if seen.has(sid):
			continue
		if int(inventory.get(sid, 0)) > 0 and slot_of(sid) == slot and can_wear(hero, sid):
			out.append(sid)
	return out


static func _take(inventory: Dictionary, id: String) -> void:
	inventory[id] = int(inventory.get(id, 0)) - 1
	if int(inventory[id]) <= 0:
		inventory.erase(id)


static func _give(inventory: Dictionary, id: String) -> void:
	if id != "":
		inventory[id] = int(inventory.get(id, 0)) + 1


static func _who(hero: Dictionary) -> String:
	return str(hero.get("name", "?"))


## Uitrusten: 1 uit de tas, het oude stuk terug in de tas. {"ok": bool, "text": String}
static func equip(hero: Dictionary, inventory: Dictionary, slot: String, id: String) -> Dictionary:
	if not (slot in slots()) or slot_of(id) != slot:
		return {"ok": false, "text": MSG_WRONG_SLOT}
	if int(inventory.get(id, 0)) <= 0:
		return {"ok": false, "text": MSG_NOT_OWNED}
	if not can_wear(hero, id):
		return {"ok": false, "text": MSG_CANT_WEAR % _who(hero)}
	var e := equip_of(hero)
	var old := str(e[slot])
	_take(inventory, id)
	_give(inventory, old)
	e[slot] = id
	refresh(hero)
	return {"ok": true, "text": MSG_EQUIPPED % [_who(hero), item_name(id)]}


## Afdoen: het stuk gaat terug in de tas.
static func unequip(hero: Dictionary, inventory: Dictionary, slot: String) -> Dictionary:
	var e := equip_of(hero)
	var old := str(e.get(slot, ""))
	if old == "":
		return {"ok": false, "text": MSG_EMPTY_SLOT}
	e[slot] = ""
	_give(inventory, old)
	refresh(hero)
	return {"ok": true, "text": MSG_REMOVED % item_name(old)}


## Alles afdoen; geeft het aantal stukken dat terug in de tas ging.
static func unequip_all(hero: Dictionary, inventory: Dictionary) -> int:
	var n := 0
	for s in slots():
		if bool(unequip(hero, inventory, s)["ok"]):
			n += 1
	return n


## Weggooien: het gedragen stuk in dit vak is WEG (niet terug in de tas).
static func drop(hero: Dictionary, slot: String) -> Dictionary:
	var e := equip_of(hero)
	var old := str(e.get(slot, ""))
	if old == "":
		return {"ok": false, "text": MSG_EMPTY_SLOT}
	e[slot] = ""
	refresh(hero)
	return {"ok": true, "text": MSG_DROPPED % item_name(old)}


## Hoe 'sterk' is een stuk voor deze held (gewichten per equip_type, VOORLOPIG, zie
## GameData.STRONGEST_WEIGHTS). Leeg vak = 0.
static func score(hero: Dictionary, id: String) -> float:
	if id == "":
		return 0.0
	var w: Dictionary = GameData.STRONGEST_WEIGHTS.get(str(hero.get("equip_type", "")), GameData.STRONGEST_WEIGHTS["standaard"])
	var total := 0.0
	for s in stats():
		total += float(item_bonus(id, s)) * float(w.get(s, 1.0))
	return total


## Beste stuk voor één vak uit (tas + wat hij nu draagt); bij gelijke score blijft het
## huidige stuk. "" = leeg laten (niets met een positieve score).
static func best_for_slot(hero: Dictionary, inventory: Dictionary, slot: String) -> String:
	var best := equipped(hero, slot)
	var best_score := score(hero, best) if best != "" else 0.0
	for id in candidates(hero, inventory, slot):
		var sc := score(hero, id)
		if sc > best_score:
			best = id
			best_score = sc
	return best


## Sterkste: per vak het beste stuk. Geeft het aantal gewisselde vakken terug.
static func strongest(hero: Dictionary, inventory: Dictionary) -> int:
	var changed := 0
	for s in slots():
		var best := best_for_slot(hero, inventory, s)
		if best != "" and best != equipped(hero, s):
			if bool(equip(hero, inventory, s, best)["ok"]):
				changed += 1
	return changed


## Stuk krijgen en meteen dragen (wapen uit het verhaal). Het oude stuk gaat in de tas.
static func give_and_equip(hero: Dictionary, inventory: Dictionary, id: String) -> bool:
	if not is_equipment(id):
		return false
	_give(inventory, id)
	if bool(equip(hero, inventory, slot_of(id), id)["ok"]):
		return true
	_take(inventory, id)        # kon niet: niets bijgekomen
	return false


## Hoeveel van dit stuk bestaat er in totaal (tas + gedragen door de party)? Voor de test
## 'niets dubbel, niets kwijt'.
static func total_count(party: Array, inventory: Dictionary, id: String) -> int:
	var n := int(inventory.get(id, 0))
	for h in party:
		for s in slots():
			if equipped(h, s) == id:
				n += 1
	return n


# ---------------------------------------------------------------- opslaan / laden
## Wat er per held in de save komt (naast de oude velden atk/def/agi = effectief).
static func save_fields(hero: Dictionary) -> Dictionary:
	return {"base": base_of(hero).duplicate(), "equip": equip_of(hero).duplicate()}


## Held uit een save herstellen. 'h' = kopie van de held uit de data waar de gewone velden
## (level, hp, atk, ...) al op staan; 'e' = de held zoals in het bestand; 'template' = de
## held uit GameData.HEROES. Stukken die niet (meer) bestaan, niet in dat vak passen of
## niet door deze held gedragen mogen worden, komen in 'stray' (gaan terug in de tas).
## Oude saves (vóór v0.14):
##   - geen "equip": alleen het oude "weapon"-veld telt (wapenvak); atk bevatte die bonus al
##   - geen "base": basis = opgeslagen waarde min de bonus van wat hij draagt
##   - geen "mag"/"mdef": startwaarde + groei x (level - 1) uit game_data.gd
static func load_hero(h: Dictionary, e: Dictionary, template: Dictionary, stray: Array) -> void:
	var eq := empty_equip()
	var src = e.get("equip", null)
	if src is Dictionary:
		for s in slots():
			var id = src.get(s, "")
			if id is String and id != "":
				eq[s] = id
	elif e.get("weapon") is String and str(e["weapon"]) != "":
		eq["wapen"] = str(e["weapon"])
	# alleen geldige stukken in de vakken; de rest naar de tas
	var bad: Array = []
	for s in slots():
		var id := str(eq[s])
		if id != "" and (not is_equipment(id) or slot_of(id) != s or not can_wear(h, id)):
			bad.append(id)
			eq[s] = ""
	h["equip"] = eq
	var level := maxi(1, int(h.get("level", 1)))
	var growth: Dictionary = template.get("growth", {})
	var saved_base = e.get("base", null)
	var b := {}
	for s in stats():
		if saved_base is Dictionary and (saved_base.get(s) is int or saved_base.get(s) is float):
			b[s] = int(saved_base[s])
		elif e.get(s) is int or e.get(s) is float:
			# oude save: de opgeslagen waarde was effectief (met de oude wapenbonus erin)
			var legacy_bonus := 0
			for sl in slots():
				var id2 := str(eq[sl])
				legacy_bonus += item_bonus(id2, s)
			for id3 in bad:
				legacy_bonus += item_bonus(str(id3), s)
			b[s] = int(e[s]) - legacy_bonus
		else:
			b[s] = int(template.get(s, 0)) + int(growth.get(s, 0)) * (level - 1)
	h["base"] = b
	stray.append_array(bad)
	refresh(h)
