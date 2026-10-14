extends RefCounted
## WINKEL VAN DE KOOPMAN (H-5), Diepe Grot. Volgt TODO.md "Merchant Room: welke items verkoopt hij?" (canon):
##   1. Consumables, altijd op voorraad, 2x de normale winkelprijs: Elixir, Feniksveer (revive), Tegengif (anti-status).
##   2. Grot-exclusief, altijd op voorraad, vaste hoge prijs: Stun-bom (verlamt alle monsters in de kamer).
##      NIET de Simulatie-token (run herstarten): besluit Dennis 13 okt 2026, botst met H-5's Token (+10%).
##   3. Grade 3-4 uitrusting, wisselt per bezoek: 1 willekeurig Grade 3-stuk; elk 3e bezoek ook 1 Grade 4-stuk.
##      Prijs 2x (Grade 3) / 3x (Grade 4) de winkelprijs.
##   4. Rotatie-item: 1 uniek per bezoek (lore-item, zeldzame consumable of novelty), variabele prijs.
##   Inkoop: consumables 50%, uitrusting/accessoires 40% (TODO: 30-50%), Grade 4 60% van de winkelprijs.
##   Restock: elke nieuwe run (voorraad hangt aan run-seed + bezoek; gekochte unieke stukken zijn dit bezoek weg).
## BESLUIT DENNIS 14 okt 2026 (vervangt punt 3 als de verdieping bekend is, voorraad(..., floor_no)):
##   uitrusting en accessoires GESCHAALD op de huidige verdieping (grade = GradeGear.grade_for_floor):
##   2 uitrustingsstukken van die grade (min_floor <= verdieping) + 1 accessoire (G4: de G4-accessoires,
##   daaronder de ring-lijn een tier boven de gewone kisten), plus een paar basis-consumables
##   (Potion, Magic Water). Prijs = winkelprijs x GRADE_FACTOR. Engelse UI. Zonder verdieping: de oude G3/G4-regel.
## Geen node, geen UI: scripts/ui/koopman_winkel_scherm.gd gebruikt dit.

const GameData := preload("res://scripts/data/game_data.gd")
const GradeGear := preload("res://scripts/data/grade_gear.gd")
const ShopData := preload("res://scripts/data/shop_data.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")

## TIJDELIJKE AANNAME: "normale winkelprijs" van items die in geen enkele winkel liggen.
const BASIS_PRIJS := {"elixer": 300, "feniksveer": 200, "tegengif": 40, "sterrenelixer": 220, "harttraan": 400,
		"herinnering": 350, "gloeiende_inktfles": 80, "h5_notitie": 150, "drankje": 30, "toverwater": 50}
const CONSUMABLES: Array[String] = ["elixer", "feniksveer", "tegengif"]
const CONSUMABLE_FACTOR := 2.0
const STUNBOM := "stunbom"
const STUNBOM_PRIJS := 900
const G3_FACTOR := 2.0
const G4_FACTOR := 3.0
const G4_ELK := 3
const ROTATIE: Array[String] = ["h5_notitie", "harttraan", "herinnering", "sterrenelixer", "gloeiende_inktfles"]
## Basis-consumables (gewone winkelprijs x BASIS_FACTOR), naast de canon-consumables hierboven.
const BASIS_CONSUMABLES: Array[String] = ["drankje", "toverwater"]
const BASIS_FACTOR := 1.5
## Prijsfactor per grade (index = grade 1..4) voor geschaalde uitrusting/accessoires.
const GRADE_FACTOR := [1.0, 1.5, 1.5, 2.0, 3.0]
const UITRUSTING_AANTAL := 2
const INKOOP_CONSUMABLE := 0.5
const INKOOP_UITRUSTING := 0.4
const INKOOP_G4 := 0.6

## TODO.md, Merchant Room "Dialoog" (canon), vertaald.
const REGEL_KOOP := "Good choice. I left this behind myself... long ago."
const REGEL_VERKOOP := "Everything has value down here. Even things you no longer need."
const VRAAG := "Care to trade?"
const KEUZES: Array[String] = ["Trade", "Leave"]
const ACCESSOIRE_BODEM := 100


static func basis_prijs(id: String) -> int:
	if BASIS_PRIJS.has(id):
		return int(BASIS_PRIJS[id])
	return ShopData.list_price(id)


static func naam(id: String) -> String:
	if GameData.ITEMS.has(id):
		return str(GameData.ITEMS[id].get("name", id))
	if GameData.EQUIPMENT.has(id):
		return str(GameData.EQUIPMENT[id].get("name", id))
	if GradeGear.has_item(id):
		return str(GradeGear.item(id).get("name", id))
	return id


static func _grade(id: String) -> int:
	return int(GradeGear.item(id).get("grade", 0)) if GradeGear.has_item(id) else 0


static func _pool(grade: int) -> Array[String]:
	var uit: Array[String] = []
	for id in GradeGear.ITEMS:
		if int(GradeGear.ITEMS[id].get("grade", 0)) == grade:
			uit.append(str(id))
	uit.sort()
	return uit


static func _rng(run_seed: int, bezoek: int, zout: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = absi(run_seed * 1000003 + bezoek * 7919 + zout * 104729) + 1
	return r


## Voorraad voor dit bezoek: [{id, name, price, kind ("item"), soort ("consumable"|"exclusief"|"g3"|"g4"|"rotatie"), uniek}].
## 'gekocht' = unieke ids die dit bezoek al gekocht zijn (die vallen weg).
## floor_no > 0: uitrusting/accessoire geschaald op die verdieping (besluit Dennis 14 okt 2026).
static func voorraad(run_seed: int, bezoek: int, gekocht: Array = [], floor_no := 0) -> Array:
	var uit: Array = []
	for id in CONSUMABLES:
		uit.append(_rij(id, roundi(basis_prijs(id) * CONSUMABLE_FACTOR), "consumable", false))
	if floor_no > 0:
		for id in BASIS_CONSUMABLES:
			uit.append(_rij(id, roundi(basis_prijs(id) * BASIS_FACTOR), "consumable", false))
	uit.append(_rij(STUNBOM, STUNBOM_PRIJS, "exclusief", false))
	if floor_no > 0:
		uit.append_array(_geschaald(run_seed, bezoek, floor_no))
		return _rotatie(uit, run_seed, bezoek, gekocht)
	var g3 := _pool(3)
	if not g3.is_empty():
		var id3: String = g3[_rng(run_seed, bezoek, 3).randi_range(0, g3.size() - 1)]
		uit.append(_rij(id3, roundi(basis_prijs(id3) * G3_FACTOR), "g3", true))
	if bezoek > 0 and bezoek % G4_ELK == 0:
		var g4 := _pool(4)
		if not g4.is_empty():
			var id4: String = g4[_rng(run_seed, bezoek, 4).randi_range(0, g4.size() - 1)]
			uit.append(_rij(id4, roundi(basis_prijs(id4) * G4_FACTOR), "g4", true))
	return _rotatie(uit, run_seed, bezoek, gekocht)


static func _rotatie(uit: Array, run_seed: int, bezoek: int, gekocht: Array) -> Array:
	var rot: String = ROTATIE[posmod(bezoek - 1 + _rng(run_seed, 0, 9).randi_range(0, ROTATIE.size() - 1), ROTATIE.size())]
	var r := _rng(run_seed, bezoek, 5)
	uit.append(_rij(rot, roundi(basis_prijs(rot) * r.randf_range(1.5, 2.5)), "rotatie", true))
	return uit.filter(func(row): return not (bool(row["uniek"]) and gekocht.has(row["id"])))


## Grade van de verdieping (99 voor 100, zoals de blauwe kisten).
static func grade_voor(floor_no: int) -> int:
	return GradeGear.grade_for_floor(mini(maxi(floor_no, 1), 99))


## 2 uitrustingsstukken + 1 accessoire, geschaald op de verdieping. Uniek per bezoek.
static func _geschaald(run_seed: int, bezoek: int, floor_no: int) -> Array:
	var g := grade_voor(floor_no)
	var factor: float = GRADE_FACTOR[clampi(g, 1, 4)]
	var pool: Array[String] = []
	for id in _pool(g):
		var it: Dictionary = GradeGear.item(id)
		if str(it.get("slot", "")) != "accessoire" and int(it.get("min_floor", 1)) <= maxi(floor_no, 1):
			pool.append(id)
	if pool.is_empty():
		pool = _pool(g).filter(func(i): return str(GradeGear.item(i).get("slot", "")) != "accessoire")
	var uit: Array = []
	var rng := _rng(run_seed, bezoek * 101 + floor_no, 6)
	for i in mini(UITRUSTING_AANTAL, pool.size()):
		var j := rng.randi_range(0, pool.size() - 1)
		var id: String = pool[j]
		pool.remove_at(j)
		uit.append(_rij(id, maxi(1, roundi(basis_prijs(id) * factor)), "uitrusting", true))
	var acc := accessoire_voor(run_seed, bezoek, floor_no)
	if acc != "":
		uit.append(_rij(acc, roundi(accessoire_prijs(acc, floor_no) * factor), "accessoire", true))
	return uit


## Basisprijs van een accessoire in de winkel. De d100-ringen zijn kistbuit met prijs 0; dan geldt de
## grade-regel van de grot-uitrusting (grade x grade x 60) met de bladwijzer als bodem (100g).
static func accessoire_prijs(id: String, floor_no: int) -> int:
	var p := basis_prijs(id)
	if p > 0:
		return p
	var g := grade_voor(floor_no)
	return maxi(ACCESSOIRE_BODEM, g * g * 60)


static func accessoire_voor(run_seed: int, bezoek: int, floor_no: int) -> String:
	if grade_voor(floor_no) >= 4:
		var acc: Array[String] = []
		for id in _pool(4):
			if str(GradeGear.item(id).get("slot", "")) == "accessoire":
				acc.append(id)
		if not acc.is_empty():
			return acc[_rng(run_seed, bezoek * 101 + floor_no, 7).randi_range(0, acc.size() - 1)]
	return Scaling.gear_id("ring", mini(Scaling.MAX_TIER, Scaling.tier_for_floor(floor_no) + 1))


static func _rij(id: String, prijs: int, soort: String, uniek: bool) -> Dictionary:
	return {"id": id, "name": naam(id), "price": prijs, "kind": "item", "soort": soort, "uniek": uniek, "grade": _grade(id)}


## Wat hij betaalt voor één stuk (0 = koopt hij niet).
static func inkoop_prijs(id: String) -> int:
	if GameData.KEY_ITEMS.has(id):
		return 0
	var it: Dictionary = GameData.ITEMS.get(id, {})
	if bool(it.get("key", false)) or bool(it.get("warp", false)):
		return 0
	var basis := basis_prijs(id)
	if basis <= 0:
		return 0
	var f := INKOOP_CONSUMABLE
	if _grade(id) >= 4:
		f = INKOOP_G4
	elif GameData.EQUIPMENT.has(id) or GradeGear.has_item(id) or bool(it.get("equip", false)):
		f = INKOOP_UITRUSTING
	return maxi(1, int(basis * f))


## Kopen voor dit bezoek. Geeft {ok, text}.
static func koop(run_seed: int, bezoek: int, gekocht: Array, id: String, floor_no := 0) -> Dictionary:
	var rij := {}
	for r in voorraad(run_seed, bezoek, gekocht, floor_no):
		if r["id"] == id:
			rij = r
	if rij.is_empty():
		return {"ok": false, "text": "That's not for sale."}
	if GameState.gold < int(rij["price"]):
		return {"ok": false, "text": "Not enough gold."}
	GameState.gold -= int(rij["price"])
	GameState.inventory[id] = int(GameState.inventory.get(id, 0)) + 1
	if bool(rij["uniek"]):
		gekocht.append(id)
	return {"ok": true, "text": REGEL_KOOP}


static func verkoop(id: String) -> Dictionary:
	if int(GameState.inventory.get(id, 0)) <= 0:
		return {"ok": false, "text": "You don't have that."}
	var p := inkoop_prijs(id)
	if p <= 0:
		return {"ok": false, "text": "I can't use that."}
	GameState.inventory[id] = int(GameState.inventory[id]) - 1
	if int(GameState.inventory[id]) <= 0:
		GameState.inventory.erase(id)
	GameState.gold += p
	return {"ok": true, "text": REGEL_VERKOOP, "gold": p}


## Verkoopbare stukken uit de tas: [{id, name, price, n}].
static func verkoopbaar() -> Array:
	var uit: Array = []
	for id in GameState.inventory:
		var n := int(GameState.inventory[id])
		var p := inkoop_prijs(str(id))
		if n > 0 and p > 0:
			uit.append({"id": str(id), "name": naam(str(id)), "price": p, "n": n})
	return uit
