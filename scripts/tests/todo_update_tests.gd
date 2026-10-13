extends Node
## Updates 1-4: slots, archief-doel 7, winkels, spreukregels, grade-buit, eindbazen.
## Start: godot -- --updatetest

const GD := preload("res://scripts/data/game_data.gd")
const Shop := preload("res://scripts/data/shop_data.gd")
const Rules := preload("res://scripts/data/spell_rules.gd")
const Gear := preload("res://scripts/data/grade_gear.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const Equipment := preload("res://scripts/equipment.gd")
const Bestiary := preload("res://scripts/data/endgame_bestiary.gd")
const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const PA := preload("res://scripts/party_actions.gd")

var failures := 0
var passes := 0


func _ready() -> void:
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	_spell_tests()
	_shop_tests()
	_gear_tests()
	_bestiary_tests()
	_slot_migration()
	print("UPDATETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	get_tree().quit(1 if failures else 0)


func _spell_tests() -> void:
	check("archief-doel is 7", GD.EERSTE_ARCHIEF_DOEL == 7)
	check("Dennis leert geen enkele spreuk", not Rules.can_learn("dennis", "vuur") and not Rules.can_learn("dennis", "genees")
			and not Rules.can_learn("dennis", "inferno"))
	check("Noor: vuur/natuur/bliksem t/m 4, licht alleen grade 1", Rules.can_learn("noor", "inferno")
			and Rules.can_learn("noor", "oerwoud") and Rules.can_learn("noor", "donderslag")
			and Rules.can_learn("noor", "genees") and Rules.can_learn("noor", "zegen")
			and not Rules.can_learn("noor", "grote_genezing") and not Rules.can_learn("noor", "rijp"))
	check("Lotte: licht en ijs, geen vuur/natuur/bliksem", Rules.can_learn("lotte", "aureool")
			and Rules.can_learn("lotte", "ijskern") and Rules.can_learn("lotte", "zegen")
			and not Rules.can_learn("lotte", "vuur") and not Rules.can_learn("lotte", "doorn")
			and not Rules.can_learn("lotte", "vonk"))
	check("winkel stopt bij grade 3", Rules.shop_max_grade(1) == 1 and Rules.shop_max_grade(4) == 3
			and Rules.in_shop("vuur", 1) and Rules.in_shop("vlam", 1) and not Rules.in_shop("vuurbal", 1)
			and Rules.in_shop("vuurzee", 3) and Rules.in_shop("inferno", 6) and not Rules.in_shop("zonneslag", 6)
			and not Rules.in_shop("donderslag", 6))
	var vuur: Dictionary = GD.SPELLS["vuur"]
	check("Vonk is grade 1 vuur, power 15, +2 per level", str(vuur["name"]) == "Vonk" and int(vuur["power"]) == 15
			and int(vuur["mp"]) == 4 and Rules.power_at(vuur, 1) == 15.0 and Rules.power_at(vuur, 2) == 17.0)
	var shop_g := 0
	var shop_g4 := 0
	var oude := false
	for sid in GD.SPELLS:
		var sp: Dictionary = GD.SPELLS[sid]
		if str(sp.get("name", "")) in ["Fire", "Heal", "Lightning"]:
			oude = true
		if int(sp.get("grade", 1)) >= 4:
			shop_g4 += 1
			if Rules.in_shop(str(sid), 6):
				shop_g += 1
		elif Rules.in_shop(str(sid), 6):
			shop_g += 1
	check("winkel toont de canon-lijst G1-G3, geen oude Engelse namen en geen grade 4", shop_g == 61
			and shop_g4 == 20 and not oude and str(GD.SPELLS["genees"]["name"]) == "Kleine Genezing"
			and str(GD.SPELLS["rijp"]["name"]) == "IJspegel" and str(GD.SPELLS["bliksem"]["name"]) == "Kettingbliksem")
	for sid in GD.SPELLS:
		var sp: Dictionary = GD.SPELLS[sid]
		check("spreuk %s heeft element en grade" % sid, str(sp.get("element", "")) != "" and int(sp.get("grade", 0)) >= 1)


func _shop_tests() -> void:
	GameState.new_game("Kees")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	GameState.gold = 0
	var act1 := Shop.stock("wilgendal_wapen")
	var ids: Array = []
	for row in act1:
		ids.append(str(row["id"]))
	check("act 1 verkoopt het korte zwaard", ids.has("kort_zwaard"))
	check("malienkolder niet in act 1", not _ids(Shop.stock("wilgendal_pantser")).has("malienkolder"))
	GameState.party[0]["level"] = 14
	check("malienkolder wel zodra de party in act 2 zit", _ids(Shop.stock("wilgendal_pantser")).has("malienkolder"))
	GameState.party[0]["level"] = 1
	var magic: Array = _ids(Shop.stock("wilgendal_magie"))
	check("magiewinkel act 1 is alleen grade 1", magic.has("vuur") and magic.has("genees") and magic.has("rijp")
			and magic.has("zegen") and not magic.has("inferno") and not magic.has("bliksem")
			and not magic.has("zonneslag"))
	check("magieprijs is 160 maal grade kwadraat", Shop.list_price("vuur") == 160 and Shop.list_price("vuurbal") == 640
			and Shop.list_price("vuurzee") == 1440)
	check("een grade-1-spreuk verkoopt voor 80", Shop.sell_price("vuur") == 80 and Shop.sell_price("doorn") == 80)
	var broke := Shop.buy_item("wilgendal_wapen", "kort_zwaard")
	check("te weinig goud koopt niets", not broke["ok"] and str(broke["text"]) == "Te weinig goud."
			and int(GameState.inventory.get("kort_zwaard", 0)) == 0)
	GameState.gold = 500
	var bought := Shop.buy_item("wilgendal_wapen", "kort_zwaard")
	check("kopen haalt goud en legt het in de tas", bought["ok"] and GameState.gold == 380
			and int(GameState.inventory.get("kort_zwaard", 0)) == 1)
	var sold := Shop.sell("kort_zwaard")
	check("verkopen geeft de helft terug", sold["ok"] and int(sold.get("gold", 0)) == 60 and GameState.gold == 440
			and int(GameState.inventory.get("kort_zwaard", 0)) == 0)
	var dennis: Dictionary = GameState.party[0]
	var no_magic := Shop.buy_spell("wilgendal_magie", "vuur", dennis)
	check("Dennis koopt geen magie", not no_magic["ok"] and str(no_magic["text"]) == "Dennis leert geen magie."
			and (dennis["spells"] as Array).is_empty() and GameState.gold == 440)
	var noor: Dictionary = GameState.party[1]
	(noor["spells"] as Array).clear()
	var yes := Shop.buy_spell("wilgendal_magie", "doorn", noor)
	check("Noor koopt Doorn", yes["ok"] and (noor["spells"] as Array).has("doorn") and GameState.gold == 280)
	var g4 := Shop.buy_spell("wilgendal_magie", "donderslag", noor)
	check("grade 4 ligt niet in de winkel", not g4["ok"] and not (noor["spells"] as Array).has("donderslag"))
	var scroll := {"spreuk_donderslag": 1}
	var learned := PA.use_item(scroll, "spreuk_donderslag", noor)
	check("grade 4 wel via een rol voor Noor", learned["ok"] and (noor["spells"] as Array).has("donderslag")
			and not scroll.has("spreuk_donderslag"))
	var lotte: Dictionary = GameState.party[2]
	var ice := {"spreuk_ijskern": 1}
	check("Lotte leert IJskern van een rol", PA.use_item(ice, "spreuk_ijskern", lotte)["ok"]
			and (lotte["spells"] as Array).has("ijskern"))
	var fire := {"spreuk_inferno": 1}
	var no_fire := PA.use_item(fire, "spreuk_inferno", lotte)
	check("Lotte leert geen vuur en de rol blijft", not no_fire["ok"] and fire.has("spreuk_inferno")
			and not (lotte["spells"] as Array).has("inferno"))


func _ids(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append(str(row["id"]))
	return out


func _gear_tests() -> void:
	check("banden 1-19 / 20-49 / 50-79 / 80-99", Gear.grade_for_floor(1) == 1 and Gear.grade_for_floor(19) == 1
			and Gear.grade_for_floor(20) == 2 and Gear.grade_for_floor(49) == 2
			and Gear.grade_for_floor(50) == 3 and Gear.grade_for_floor(79) == 3
			and Gear.grade_for_floor(80) == 4 and Gear.grade_for_floor(99) == 4)
	for id in Gear.ITEMS:
		var g := int(Gear.item(id).get("grade", 0))
		var n := Gear.affix_count(id)
		if g <= 2:
			check("%s grade %d zonder affix" % [id, g], n == 0)
		elif g == 3:
			check("%s één affix" % id, n == 1)
		else:
			check("%s grade 4 meerdere affixen" % id, n >= 2)
	check("G1-benen pas vanaf verdieping 10", int(Gear.item("bg_g1_benen").get("min_floor", 0)) == 10)
	var early := Gear.pick(3, 12, "k")
	check("ondiepe kist is grade 1 zonder affix", Gear.item(early).get("grade", 0) == 1 and Gear.affix_count(early) == 0)
	var deep := Gear.pick(3, 90, "k")
	check("diepe kist is grade 4", int(Gear.item(deep).get("grade", 0)) == 4 or Gear.is_scroll(deep))
	var seen_scroll := false
	var seen_weapon := false
	for seed in range(1, 200):
		var id := Gear.pick(seed, 85, "vloer")
		if Gear.is_scroll(id):
			seen_scroll = true
		if id in ["bg_g4_superzwaard", "bg_g4_staf_noor", "bg_g4_staf_lotte"]:
			seen_weapon = true
		check("verdieping 85 blijft in de G4-pool", Gear.is_scroll(id) or int(Gear.item(id).get("min_floor", 99)) <= 85)
	check("G4-rollen zitten in de diepe pool", seen_scroll)
	check("unieke wapens zitten in de diepe pool", seen_weapon)
	var loot := Blue.blue_loot(9, 12, "kist")
	var again := Blue.blue_loot(9, 12, "kist")
	check("blauwe buit is vast, één stuk, geen goud", loot["gold"] == 0 and (loot["items"] as Array).size() == 1
			and str(loot["items"][0]["item"]) == str(again["items"][0]["item"])
			and Blue.is_blue_item(str(loot["items"][0]["item"])))
	check("oude d100-stukken blijven blauw", Blue.is_blue_item(Scaling.gear_id("zwaard", 2)))
	GameState.new_game("Dennis")
	GameState.add_member("noor")
	GameState.add_member("lotte")
	var dennis: Dictionary = GameState.party[0]
	var noor: Dictionary = GameState.party[1]
	var lotte: Dictionary = GameState.party[2]
	check("Dennis draagt het superzwaard, Noor en Lotte niet", Equipment.can_wear(dennis, "bg_g4_superzwaard")
			and not Equipment.can_wear(noor, "bg_g4_superzwaard") and not Equipment.can_wear(lotte, "bg_g4_superzwaard"))
	check("staf van Noor alleen voor de magiër", Equipment.can_wear(noor, "bg_g4_staf_noor")
			and not Equipment.can_wear(dennis, "bg_g4_staf_noor") and not Equipment.can_wear(lotte, "bg_g4_staf_noor"))
	check("staf van Lotte alleen voor de priester", Equipment.can_wear(lotte, "bg_g4_staf_lotte")
			and not Equipment.can_wear(noor, "bg_g4_staf_lotte"))
	GameState.inventory["bg_g4_plated_helm"] = 1
	GameState.inventory["bg_g4_plated_harnas"] = 1
	var on := Equipment.equip(dennis, GameState.inventory, "helm", "bg_g4_plated_helm")
	check("platenhelm om", on["ok"] and Equipment.item_bonus("bg_g4_plated_helm", "def") == 16 + 6)
	dennis["equip"]["harnas"] = "bg_g4_natuur_harnas"
	check("sets niet mixen", not Equipment.can_wear(dennis, "bg_g4_plated_harnas"))
	dennis["equip"]["harnas"] = ""
	var chest := Equipment.equip(dennis, GameState.inventory, "harnas", "bg_g4_plated_harnas")
	check("tweede stuk van dezelfde set mag wel", chest["ok"])
	check("accessoire grade 4 heeft geen class", not Gear.item("bg_g4_ring_kracht").has("wie")
			and not Gear.item("bg_g4_ring_kracht").has("set_id")
			and Equipment.can_wear(dennis, "bg_g4_ring_kracht") and Equipment.can_wear(noor, "bg_g4_ring_kracht")
			and Equipment.can_wear(lotte, "bg_g4_ring_kracht"))


func _bestiary_tests() -> void:
	var ids: Array = Bestiary.ids()
	check("twaalf grotbazen, geen baas op 100", ids.size() == 12 and ids[0] == "d100_baas_10"
			and ids[ids.size() - 1] == "d100_baas_99" and not ids.has("d100_baas_100"))
	var order: Array = GD.bestiary_ids()
	check("bestaande bestiarium-volgorde blijft", order.size() >= 12 and str(order[11]) == "inktwurm")
	for id in ids:
		var e := Bestiary.entry(str(id))
		var desc := str(e.get("desc", ""))
		var canon_line := desc in [
				"A dark echo of Dennis himself. He moves as Dennis moves, fights as Dennis fights — but he is silent. Here Sapientia shows what happens when someone loses their name. The Shadow knows no past, no Noor, no Grandpa. Only the number: H-6.",
				"An endlessly turning machine, half organic, half steel. It knows no beginning and no end — it simply starts again. Sapientia's logic in one form: no rest, no release, only repetition. Whoever defeats it has won nothing. It keeps turning anyway.",
				"A giant eye with arms grasping in every direction. It weighs, it measures, it judges. What it weighs is not a deed, but a person. And people are always found too light — except one. De Rechter is Sapientia's doubt: she is looking for someone who weighs more than she expected.",
				"No body. No shape. Only a voice, and glitches that warp the world around you. De Stem speaks as if it knows you — and it does. Here Sapientia speaks herself. Not as an enemy, but as something that has been waiting for you.",
		]
		check("entry %s heeft stats en een regel" % id, int(e.get("no", 0)) >= 13
				and int(e.get("max_hp", 0)) > 0 and (desc.begins_with("Baas op verdieping") or canon_line)
				and str(e.get("name", "")) != "")
	check("verdieping 25 heet De Schaduw van H-6", Bestiary.entry("d100_baas_25")["name"] == "De Schaduw van H-6"
			and Bestiary.entry("d100_baas_25")["desc"] == "A dark echo of Dennis himself. He moves as Dennis moves, fights as Dennis fights — but he is silent. Here Sapientia shows what happens when someone loses their name. The Shadow knows no past, no Noor, no Grandpa. Only the number: H-6.")
	GameState.mark_seen("d100_baas_99")
	GameState.mark_defeated("d100_baas_99")
	check("De Stem telt in het bestiarium", GameState.is_seen("d100_baas_99") and GameState.defeated_count("d100_baas_99") == 1)


func _slot_migration() -> void:
	GameState.new_game("Oud")
	GameState.current_map = "res://scenes/maps/huis_wilgendal.tscn"
	GameState.active_slot = 1
	GameState.gold = 7
	GameState.save_game(Vector2i(2, 2), Vector2i.DOWN)
	var d := GameState.read_save()
	d.erase("slot")
	var f := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var rec := GameState.slot_record(1)
	check("oude save zonder slot-sleutel hoort bij slot 1", not rec.is_empty() and int(rec.get("slot", 0)) == 1
			and int(rec.get("data", {}).get("gold", 0)) == 7 and not rec.get("data", {}).has("slot"))
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
