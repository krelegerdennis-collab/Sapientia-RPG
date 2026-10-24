extends RefCounted
## v0.11 Items en spreuken BUITEN gevechten (veldmenu). Alleen logica, geen UI, zodat de
## schermen (items_screen.gd, magic_screen.gd) en de autotest dezelfde regels gebruiken.
## Uitkomst van use_item / cast_spell is een Dictionary:
##   {"ok": bool, "hp": int, "mp": int, "text": String}
## ok = false -> er is niets veranderd (geen item/MP verbruikt), text zegt waarom.
## (preload i.p.v. class_name, zoals de andere UI-hulpjes)

const GameData := preload("res://scripts/data/game_data.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const Equipment := preload("res://scripts/equipment.gd")
## Spreuk-effect buiten gevechten: zelfde formule als in battle.gd (_spell_amount):
## power + SPELL_LEVEL_BONUS x level, +/- SPELL_SPREAD.
const SPELL_LEVEL_BONUS := 2.0
const SPELL_SPREAD := 0.1

## Tekens voor een itemnaam in de lijst van het Items-scherm (daarna "x3").
## v0.14: 13 (uitrusting heeft langere namen, bv. 'Maliënkolder').
const LIST_NAME_COLS := 13

const MSG_FIELD_ONLY := "This only works in battle."
const MSG_UNKNOWN := "You don't know what to do with this."
const MSG_NO_EFFECT := "That has no effect right now."
const MSG_KO := "%s is unconscious."
const MSG_NO_MP := "Not enough MP."
const MSG_KEY_ITEM := "Important item. Keep it safe."
const MSG_EQUIP_ITEM := "Equipment: choose Equipment in the menu."
const MSG_WARP_ONLY := "The Warp only works on floor 100."
const MSG_WARP_USED := "The crystal flares... the simulation lets go."


## Een Dictionary-constante uit game_data.gd die niet in elke versie bestaat (v0.11:
## KEY_ITEMS, WEAPONS); {} als hij er niet is. (dynamisch via get: de parser kent
## GameData.KEY_ITEMS niet in versies zonder die constante; géén load() hier, dat gaf in
## Godot 4.7 lekken bij afsluiten)
static func data_const(const_name: String) -> Dictionary:
	var gd: Object = GameData
	var v = gd.get(const_name)
	return v if v is Dictionary else {}


## Gegevens van een item; ook sleutel-voorwerpen (GameData.KEY_ITEMS, als die bestaat:
## v0.11) worden gevonden, die krijgen "key": true en zijn nooit bruikbaar in het veld.
static func item_data(id: String) -> Dictionary:
	if GameData.ITEMS.has(id):
		return GameData.ITEMS[id]
	# v0.14: uitrusting staat ook in de tas, maar gebruik je via 'Uitrusting'
	if Equipment.is_equipment(id):
		var q: Dictionary = Equipment.item(id).duplicate()
		q["equip"] = true
		q["field"] = false
		return q
	var keys: Dictionary = data_const("KEY_ITEMS")
	if keys.has(id) and keys[id] is Dictionary:
		var k: Dictionary = keys[id].duplicate()
		k["key"] = true
		k["field"] = false
		return k
	return {}


static func item_name(id: String) -> String:
	return str(item_data(id).get("name", id))


## v0.11: wapens. v0.14: alle stukken voor het vak 'wapen' uit GameData.EQUIPMENT.
static func weapons() -> Dictionary:
	var out := {}
	for id in GameData.EQUIPMENT:
		if Equipment.slot_of(id) == "wapen":
			out[id] = GameData.EQUIPMENT[id]
	return out


## Naam van het wapen van een held, "-" = geen. (v0.14: het wapenvak; oud veld 'weapon'
## als de held nog geen vakken heeft)
static func weapon_name(hero: Dictionary) -> String:
	var w := str(hero["equip"].get("wapen", "")) if hero.get("equip") is Dictionary else str(hero.get("weapon", ""))
	return Equipment.item_name(w) if Equipment.is_equipment(w) else "-"


## Naam voor een smalle lijst: "short" als de volle naam langer is dan 'cols' tekens.
static func item_list_name(id: String, cols: int) -> String:
	var it := item_data(id)
	var n := str(it.get("name", id))
	if n.length() > cols and it.has("short"):
		n = str(it["short"])
	return n.left(cols)


## Kan dit item hier (buiten een gevecht) gebruikt worden? Genees-items en spreukrollen, op een held.
## Een item kan dit uitzetten met "field": false in game_data.gd.
static func item_usable_in_field(id: String) -> bool:
	var it := item_data(id)
	if bool(it.get("warp", false)):
		return GameState.dungeon100_can_warp()
	if it.is_empty() or not bool(it.get("field", true)):
		return false
	if _teach_id(it) != "":
		return str(it.get("target", "")) == "ally"
	if float(it.get("revive", 0.0)) > 0.0:
		return true
	if bool(it.get("stun_room", false)):
		return _stun_targets().size() > 0
	return str(it.get("target", "")) == "ally" and (int(it.get("heal_hp", 0)) > 0 or int(it.get("heal_mp", 0)) > 0)


## Korte uitleg van het effect ("Herstelt 30 HP.").
static func item_effect_text(id: String) -> String:
	var it := item_data(id)
	if bool(it.get("warp", false)):
		return "Takes you back to the world."
	var parts: Array[String] = []
	if int(it.get("heal_hp", 0)) > 0:
		parts.append("%d HP" % int(it["heal_hp"]))
	if int(it.get("heal_mp", 0)) > 0:
		parts.append("%d MP" % int(it["heal_mp"]))
	if bool(it.get("equip", false)):
		return "%s: %s." % [Equipment.slot_name(str(it.get("slot", ""))), Equipment.bonus_text(id)]
	var spell_id := _teach_id(it)
	if spell_id != "":
		return "Teaches the spell %s." % str(spell_data(spell_id).get("name", spell_id))
	return ("Restores %s." % " and ".join(parts)) if not parts.is_empty() else ""


## Waarom kan dit item hier niet? ("" = het kan wel).
static func item_block_reason(id: String) -> String:
	var it := item_data(id)
	if it.is_empty():
		return MSG_UNKNOWN
	if bool(it.get("warp", false)):
		return "" if GameState.dungeon100_can_warp() else MSG_WARP_ONLY
	if bool(it.get("key", false)):
		return MSG_KEY_ITEM
	if bool(it.get("equip", false)):
		return MSG_EQUIP_ITEM
	return "" if item_usable_in_field(id) else MSG_FIELD_ONLY


## HP/MP herstellen met clamping op max_hp/max_mp. Geeft de echte toename terug.
static func restore(hero: Dictionary, hp: int, mp: int) -> Vector2i:
	var real_hp := clampi(hp, 0, maxi(0, int(hero["max_hp"]) - int(hero["hp"])))
	var real_mp := clampi(mp, 0, maxi(0, int(hero["max_mp"]) - int(hero["mp"])))
	hero["hp"] = int(hero["hp"]) + real_hp
	hero["mp"] = int(hero["mp"]) + real_mp
	return Vector2i(real_hp, real_mp)


static func _heal_text(hero: Dictionary, gained: Vector2i) -> String:
	if gained.x > 0 and gained.y > 0:
		return "%s recovers %d HP and %d MP." % [hero["name"], gained.x, gained.y]
	if gained.x > 0:
		return "%s recovers %d HP." % [hero["name"], gained.x]
	return "%s recovers %d MP." % [hero["name"], gained.y]


## Zou dit herstel iets doen? (volle HP bij een Drankje = nee; KO-helden niet, zoals in het
## gevecht: genezen werkt alleen op levende helden)
static func _would_help(hero: Dictionary, hp: int, mp: int) -> bool:
	return (hp > 0 and int(hero["hp"]) < int(hero["max_hp"])) or (mp > 0 and int(hero["mp"]) < int(hero["max_mp"]))


## Gebruik een item uit GameState.inventory op een held (aantal -1, op 0 = weg uit de lijst).
static func use_item(inventory: Dictionary, id: String, hero: Dictionary) -> Dictionary:
	var reason := item_block_reason(id)
	if reason != "":
		return {"ok": false, "hp": 0, "mp": 0, "text": reason}
	if int(inventory.get(id, 0)) <= 0:
		return {"ok": false, "hp": 0, "mp": 0, "text": "You have no %s left." % item_name(id)}
	var it := item_data(id)
	if float(it.get("revive", 0.0)) > 0.0:
		if int(hero["hp"]) > 0:
			return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
		var hp_back := revive(hero, float(it["revive"]))
		_take(inventory, id)
		return {"ok": true, "hp": hp_back, "mp": 0, "text": "%s gets back up! (%d HP)" % [hero["name"], hp_back]}
	if bool(it.get("stun_room", false)):
		var n := stun_room()
		if n <= 0:
			return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
		_take(inventory, id)
		return {"ok": true, "hp": 0, "mp": 0, "text": "The bomb bursts! %d monster(s) are stunned." % n}
	if int(hero["hp"]) <= 0:
		return {"ok": false, "hp": 0, "mp": 0, "text": MSG_KO % hero["name"]}
	var spell_id := _teach_id(it)
	if spell_id != "":
		if not (hero.get("spells") is Array):
			hero["spells"] = []
		if (hero["spells"] as Array).has(spell_id):
			return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
		var why := SpellRules.block_reason(hero, spell_id)
		if why != "":
			return {"ok": false, "hp": 0, "mp": 0, "text": why}
		if not teach_spell(hero, spell_id):
			return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
		inventory[id] = int(inventory[id]) - 1
		if int(inventory[id]) <= 0:
			inventory.erase(id)
		return {"ok": true, "hp": 0, "mp": 0, "text": "%s learns %s!" % [hero["name"], spell_data(spell_id)["name"]]}
	var hp := int(it.get("heal_hp", 0))
	var mp := int(it.get("heal_mp", 0))
	if not _would_help(hero, hp, mp):
		return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
	var gained := restore(hero, hp, mp)
	inventory[id] = int(inventory[id]) - 1
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	return {"ok": true, "hp": gained.x, "mp": gained.y, "text": _heal_text(hero, gained)}


static func _take(inventory: Dictionary, id: String) -> void:
	inventory[id] = int(inventory[id]) - 1
	if int(inventory[id]) <= 0:
		inventory.erase(id)


## Feniksveer: een gevallen held staat op met een deel van zijn max HP. Geeft de HP terug.
static func revive(hero: Dictionary, frac: float) -> int:
	var hp := maxi(1, roundi(float(hero.get("max_hp", 1)) * frac))
	hero["hp"] = hp
	return hp


## Stun Bomb: monsters (MapMonster) in de huidige kamer die verlamd kunnen worden.
const STUNBOM_STAPPEN := 6
static func _stun_targets() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = tree.current_scene if tree else null
	if s == null or not ("monsters" in s):
		return []
	var uit: Array = []
	for m in s.get("monsters"):
		if is_instance_valid(m) and m.has_method("stun") and not bool(m.get("boss")) and not bool(m.get("disguised")):
			uit.append(m)
	return uit


## Verlamt alle monsters in de kamer (STUNBOM_STAPPEN stappen). Geeft het aantal terug.
static func stun_room() -> int:
	var doelen := _stun_targets()
	for m in doelen:
		m.stun(STUNBOM_STAPPEN)
	return doelen.size()


# ---------------------------------------------------------------- spreukrollen
## Spreuk-id van een rol ("teach" in game_data.gd), of "" als dit geen rol is of de spreuk niet bestaat.
static func _teach_id(it: Dictionary) -> String:
	var spell_id := str(it.get("teach", ""))
	return spell_id if spell_id != "" and GameData.SPELLS.has(spell_id) else ""


## Leert 'spell_id' aan een levende held die hem nog niet kent. Kent hij hem al, dan verandert er niets
## (false). Heeft hij te weinig max MP voor de spreuk, dan gaat zijn MP-voorraad omhoog tot de kosten
## (nooit omlaag) en vult zijn huidige MP tot dat nieuwe maximum.
static func teach_spell(hero: Dictionary, spell_id: String) -> bool:
	if spell_data(spell_id).is_empty():
		return false
	if not SpellRules.can_learn(str(hero.get("id", "")), spell_id):
		return false
	if not (hero.get("spells") is Array):
		hero["spells"] = []
	if (hero["spells"] as Array).has(spell_id):
		return false
	(hero["spells"] as Array).append(spell_id)
	var cost := int(spell_data(spell_id)["mp"])
	if int(hero.get("max_mp", 0)) < cost:
		hero["pool_mp"] = maxi(int(hero.get("pool_mp", 0)), cost)
		hero["max_mp"] = cost
		hero["mp"] = maxi(int(hero.get("mp", 0)), cost)
	return true


# ---------------------------------------------------------------- spreuken
static func spell_data(id: String) -> Dictionary:
	return GameData.SPELLS.get(id, {})


## Alleen genees-spreuken op één held werken buiten gevechten.
static func spell_usable_in_field(id: String) -> bool:
	var sp := spell_data(id)
	return str(sp.get("type", "")) == "heal" and str(sp.get("target", "")) == "ally"


## Waarom kan deze held deze spreuk hier niet gebruiken? ("" = het kan wel)
static func spell_block_reason(caster: Dictionary, id: String) -> String:
	if spell_data(id).is_empty():
		return MSG_UNKNOWN
	if not spell_usable_in_field(id):
		return MSG_FIELD_ONLY
	if int(caster["hp"]) <= 0:
		return MSG_KO % caster["name"]
	if int(caster["mp"]) < int(spell_data(id)["mp"]):
		return MSG_NO_MP
	return ""


## Basis-effect (zonder geluk) en de spreiding, voor de uitleg en de autotest.
static func spell_base(caster: Dictionary, id: String) -> float:
	var sp := spell_data(id)
	var raw := SpellRules.power_at(sp, int(caster.get("level", 1)))
	return raw * SpellRules.factor(sp, str(caster.get("id", "")), {})


static func spell_effect_text(caster: Dictionary, id: String) -> String:
	var sp := spell_data(id)
	var what := "Heals one ally" if str(sp.get("type", "")) == "heal" else "Damage"
	match str(sp.get("type", "")):
		"hot":
			what = "Heals over time"
		"buff":
			what = "Boosts an ally"
		"revive":
			what = "Revives a fallen ally"
	match str(sp.get("target", "")):
		"enemy":
			what = "Damage to one enemy"
		"all_enemies":
			what = "Damage to all enemies"
		"all_allies":
			if str(sp.get("type", "")) == "heal":
				what = "Heals the party"
	return "%s (±%d)." % [what, roundi(spell_base(caster, id))]


## Spreuk buiten het gevecht: MP gaat eraf, doel geneest (geclampt op max_hp).
static func cast_spell(caster: Dictionary, id: String, target: Dictionary) -> Dictionary:
	var reason := spell_block_reason(caster, id)
	if reason != "":
		return {"ok": false, "hp": 0, "mp": 0, "text": reason}
	if int(target["hp"]) <= 0:
		return {"ok": false, "hp": 0, "mp": 0, "text": MSG_KO % target["name"]}
	if not _would_help(target, 1, 0):
		return {"ok": false, "hp": 0, "mp": 0, "text": MSG_NO_EFFECT}
	var amount := maxi(1, roundi(spell_base(caster, id) * randf_range(1.0 - SPELL_SPREAD, 1.0 + SPELL_SPREAD)))
	caster["mp"] = int(caster["mp"]) - int(spell_data(id)["mp"])
	var gained := restore(target, amount, 0)
	return {"ok": true, "hp": gained.x, "mp": 0, "text": _heal_text(target, gained)}


# ---------------------------------------------------------------- level / EXP
## EXP die nog nodig is voor het volgende level (formule uit game_data.gd: exp_for_level).
static func exp_to_next(hero: Dictionary) -> int:
	return maxi(0, GameData.exp_for_level(int(hero["level"]) + 1) - int(hero["exp"]))
