extends Node
## ALLEEN VOOR TESTEN - Klus 13: WM1 QA-ronde op de RC. Regressie- en bugtests voor wat de sweep
## vond (softlocks, opslaan/laden, pauze, duplicatie, onmogelijke toestanden, warps, touch).
## Zie docs/release/QA_SWEEP_WM1.md.
## Start:  godot --path . -- --wm1qasweeptest [--shots=/pad/map]
## Zit niet in de export (scripts/tests/*).

const ShopData := preload("res://scripts/data/shop_data.gd")
const Molen := preload("res://scripts/village/molen.gd")
const GameDataC := preload("res://scripts/data/game_data.gd")

## Kaarten die niet in de WM1-route zitten (dev-kamers en de gegenereerde Diepe Grot).
const NIET_IN_ROUTE := ["archief_test.tscn", "kern_demo.tscn", "dungeon100.tscn"]
const MAPS_DIR := "res://scenes/maps/"
const PUZZEL := "res://scenes/maps/archief_puzzel.tscn"
const DORP := "res://scenes/maps/dorp_wilgendal.tscn"

var failures := 0
var passes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(2026)
	# waakhond: hangt er iets, dan stopt de test zelf (met een FAIL)
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		check("waakhond: test klaar binnen 900 s", false)
		print("RESULT FOUT (waakhond)")
		get_tree().quit(1))
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func info(label: String) -> void:
	print("INFO  " + label)


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func scene() -> Node:
	return get_tree().current_scene


func _run() -> void:
	print("=== A: economie en duplicatie ===")
	_economie_tests()
	print("=== B: Zingend Meel (per bezoek) ===")
	_molen_tests()
	print("=== C: onmogelijke toestanden uit een save ===")
	_save_grens_tests()
	print("=== D: opslaan/laden: velden en ronde reis ===")
	_save_ronde_tests()
	print("=== E: kist opnieuw openen na laden ===")
	await _kist_tests()
	print("=== F: gevecht-einde zonder onmogelijke toestanden ===")
	await _gevecht_einde_tests()
	print("=== G: touch: geen hangende invoer na pauze ===")
	await _touch_pauze_tests()
	print("=== J: pauze/hervatten: geen save op een verkeerd moment ===")
	await _pauze_tests()
	print("=== I: na de baas: absorptie-moment overleeft een pauze-save ===")
	await _absorptie_tests()
	print("=== H: warps: elke uitgang, elk spawnpunt ===")
	await _warp_tests()
	print("WM1QASWEEPTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await pframes(10)
	get_tree().quit(1 if failures else 0)


func _schoon(naam := "Dax") -> void:
	GameState.new_game(naam)
	GameState.encounter_multiplier = 0.0
	GameState.changing_map = false
	GameState.in_battle = false


# ---------------------------------------------------------------- A: economie
func _economie_tests() -> void:
	_schoon()
	# A1 geen goud-lus: wat een winkel verkoopt, koopt geen winkel duurder terug
	var lussen: Array = []
	for shop_id in ShopData.SHOPS:
		for offer in ShopData.SHOPS[shop_id].get("offers", []):
			var id := str(offer.get("id", ""))
			if GameDataC.SPELLS.has(id):
				continue
			var koop := ShopData._offer_price(offer)
			var verkoop := ShopData.sell_price(id)
			if koop > 0 and verkoop > koop:
				lussen.append("%s/%s koop %d < verkoop %d" % [shop_id, id, koop, verkoop])
	check("A1 winkels: geen item met verkoopprijs > koopprijs (%s)" % [lussen], lussen.is_empty())

	# A2 kopen met een volle stapel: goud blijft, geen item boven de max
	var rij := _eerste_item_rij()
	check("A2 er is een winkel met een gewoon item", not rij.is_empty())
	if not rij.is_empty():
		var id := str(rij["id"])
		GameState.gold = 100000
		GameState.set_item_count(id, GameState.MAX_ITEM_STACK)
		var goud := GameState.gold
		var r: Dictionary = ShopData.buy_item(str(rij["shop"]), id)
		check("A2 kopen bij volle stapel (%s x%d): geweigerd, goud niet kwijt (%d -> %d)"
				% [id, GameState.MAX_ITEM_STACK, goud, GameState.gold],
				not bool(r["ok"]) and GameState.gold == goud and GameState.item_count(id) == GameState.MAX_ITEM_STACK)
		GameState.set_item_count(id, 0)
		goud = GameState.gold
		var r2: Dictionary = ShopData.buy_item(str(rij["shop"]), id)
		check("A2 regressie: gewoon kopen werkt nog", bool(r2["ok"]) and GameState.item_count(id) == 1
				and GameState.gold == goud - int(rij["price"]))

	# A3 verkopen van iets dat je niet hebt: geen goud
	GameState.gold = 50
	GameState.inventory = {}
	var r3: Dictionary = ShopData.sell("drankje")
	check("A3 verkopen zonder item: geweigerd, goud gelijk", not bool(r3["ok"]) and GameState.gold == 50)

	# A4 negatieve bedragen veranderen niets
	GameState.gold = 50
	GameState.add_gold(-30)
	var ok_spend := GameState.spend_gold(-30)
	check("A4 add_gold/spend_gold met negatief bedrag: goud blijft 50", GameState.gold == 50 and ok_spend)
	check("A4 spend_gold meer dan je hebt: false, goud >= 0", not GameState.spend_gold(51) and GameState.gold == 50)
	GameState.gold = GameState.MAX_GOLD - 1
	GameState.add_gold(10)
	check("A4 goud loopt niet over MAX_GOLD", GameState.gold == GameState.MAX_GOLD)

	# A5 sleutel-voorwerpen staan niet in de verkooplijst
	GameState.inventory = {}
	for k in GameDataC.KEY_ITEMS:
		GameState.set_item_count(str(k), 1)
	var sleutels := ShopData.sellable().filter(func(row): return GameDataC.KEY_ITEMS.has(str(row["id"])))
	check("A5 sleutel-voorwerpen niet verkoopbaar (%d in de lijst)" % sleutels.size(), sleutels.is_empty())
	GameState.inventory = {}


func _eerste_item_rij() -> Dictionary:
	for shop_id in ShopData.SHOPS:
		if ShopData.is_magic(str(shop_id)):
			continue
		for row in ShopData.stock(str(shop_id)):
			if str(row.get("kind", "item")) == "item" and int(row["price"]) > 0:
				var out: Dictionary = row.duplicate()
				out["shop"] = str(shop_id)
				return out
	return {}


# ---------------------------------------------------------------- B: molen
func _molen_tests() -> void:
	_schoon()
	Molen.nieuw_bezoek("door")
	var eerste := Molen._meel()
	var tweede := Molen._meel()
	check("B1 één Zingend Meel per bezoek", eerste and not tweede and GameState.item_count("zingend_meel") == 1)
	var data := GameState.state_data(Vector2i(3, 3), Vector2i.DOWN, DORP)
	GameState.apply_state(JSON.parse_string(JSON.stringify(data)))
	Molen.nieuw_bezoek("load")
	check("B2 opslaan + laden in hetzelfde bezoek: geen tweede meel", not Molen._meel()
			and GameState.item_count("zingend_meel") == 1)
	Molen.nieuw_bezoek("door")
	check("B4 nieuw bezoek (via een deur): het meel mag weer", Molen._meel() and GameState.item_count("zingend_meel") == 2)


# ---------------------------------------------------------------- C: grenzen bij laden
func _basis_save() -> Dictionary:
	_schoon()
	GameState.add_member("noor")
	return JSON.parse_string(JSON.stringify(GameState.state_data(Vector2i(5, 5), Vector2i.DOWN, DORP)))


func _save_grens_tests() -> void:
	var d := _basis_save()
	d["gold"] = -500
	(d["party"] as Array)[0]["hp"] = 99999
	(d["party"] as Array)[1]["hp"] = -40
	(d["party"] as Array)[1]["mp"] = -3
	d["inventory"] = {"drankje": 123456, "kruid": -4, "": 2}
	check("C1 kapotte save laadt", GameState.apply_state(d))
	check("C1 goud nooit negatief (%d)" % GameState.gold, GameState.gold == 0)
	var hp_ok := true
	for h in GameState.party:
		hp_ok = hp_ok and int(h["hp"]) >= 0 and int(h["hp"]) <= int(h["max_hp"]) and int(h["mp"]) >= 0
	check("C1 HP/MP binnen 0..max voor elke held", hp_ok)
	check("C1 stapel begrensd, negatief/leeg weg", GameState.item_count("drankje") == GameState.MAX_ITEM_STACK
			and not GameState.inventory.has("kruid") and not GameState.inventory.has(""))

	d = _basis_save()
	d["party"] = []
	d["leader"] = "lotte"
	check("C2 lege party: laadt", GameState.apply_state(d))
	check("C2 lege party: Dax staat er weer", GameState.party.size() >= 1 and GameState.has_member(GameState.MAIN_HERO))
	check("C2 leider niet in de party: actieve leider = Dax", GameState.active_leader() == GameState.MAIN_HERO)

	d = _basis_save()
	(d["party"] as Array)[0]["hp"] = 0
	(d["party"] as Array)[1]["hp"] = 0
	GameState.apply_state(d)
	check("C3 save met hele party KO: laadt, helden hebben HP >= 0", GameState.party.all(func(h): return int(h["hp"]) >= 0))
	info("C3 hele party KO in een save: laadt met 0 HP (geen herstel bij laden); zie QA_SWEEP_WM1.md")

	# C4 uitrusting die bij laden terug in de tas valt, mag de stapel niet over de max duwen
	d = _basis_save()
	var wapen := _een_wapen()
	check("C4 er is een wapen-id om mee te testen", wapen != "")
	if wapen != "":
		d["inventory"] = {wapen: GameState.MAX_ITEM_STACK}
		var held: Dictionary = (d["party"] as Array)[1]
		# een ongeldig stuk in de uitrusting van Vesper -> gaat terug in de tas
		var eq := {}
		for slot in GameDataC.EQUIP_SLOTS:
			eq[slot] = wapen
		held["equip"] = eq
		GameState.apply_state(d)
		var n := GameState.item_count(wapen)
		check("C4 tas na laden niet boven MAX_ITEM_STACK (%s x%d)" % [wapen, n], n <= GameState.MAX_ITEM_STACK)


func _een_wapen() -> String:
	for id in GameDataC.EQUIPMENT:
		if str(GameDataC.EQUIPMENT[id].get("slot", "")) == "wapen":
			return str(id)
	return ""


# ---------------------------------------------------------------- D: ronde reis
func _save_ronde_tests() -> void:
	_schoon()
	GameState.add_member("noor")
	GameState.gold = 1234
	GameState.set_item_count("drankje", 7)
	GameState.story_flags["golem_verslagen"] = true
	GameState.story_step = 50
	GameState.party[1]["hp"] = 3
	# realistische stand: na de proloog staat de drift-vlag er al (laden zou hem anders toevoegen)
	GameState._call_opening_flow("migrate", GameState.story_flags, GameState.story_step)
	var voor := GameState.state_data(Vector2i(9, 4), Vector2i.LEFT, DORP)
	var pad := "user://qa_sweep_ronde.json"
	GameState.current_map = DORP
	check("D1 opslaan lukt", GameState.save_game(Vector2i(9, 4), Vector2i.LEFT, pad))
	_schoon("Wis")
	check("D1 laden lukt", GameState.load_game(pad))
	var na := GameState.state_data(GameState.return_tile, GameState.return_facing, GameState.return_map)
	var verschil: Array = []
	for k in voor:
		if k in ["play_time"]:
			continue
		if JSON.stringify(voor[k]) != JSON.stringify(na.get(k)):
			verschil.append(k)
	check("D1 alles gelijk na laden (verschil: %s)" % [verschil], verschil.is_empty())
	check("D1 positie en kaart gelijk", GameState.return_map == DORP and GameState.return_tile == Vector2i(9, 4)
			and GameState.return_facing == Vector2i.LEFT)
	# D2 opslaan midden in een gevecht of tijdens een mapwissel: geweigerd
	GameState.in_battle = true
	check("D2 opslaan tijdens gevecht geweigerd", not GameState.save_game(Vector2i.ZERO, Vector2i.DOWN, pad))
	GameState.in_battle = false
	GameState.changing_map = true
	check("D2 opslaan tijdens mapwissel geweigerd", not GameState.save_game(Vector2i.ZERO, Vector2i.DOWN, pad))
	GameState.changing_map = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad + ".bak"))


# ---------------------------------------------------------------- E: kist
func _naar(pad: String, spawn: String) -> Node:
	GameState.changing_map = false
	GameState.in_battle = false
	if not GameState.change_map(pad, spawn):
		return null
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		var s := scene()
		if s != null and s.scene_file_path == pad and s.is_node_ready() and not GameState.changing_map:
			break
	await pframes(4)
	var s2 := scene()
	return s2 if s2 != null and s2.scene_file_path == pad else null


func _sluit_tekst() -> void:
	for i in 60:
		if not Dialog.is_open:
			return
		Dialog.close()
		await pframes(2)


func _kist_tests() -> void:
	_schoon()
	GameState.story_step = 100
	var kamer := await _naar(PUZZEL, "ingang")
	check("E puzzelkamer geladen", kamer != null and "nodes" in kamer)
	if kamer == null:
		return
	var kist: Node = null
	for id in kamer.nodes:
		var n: Node = kamer.nodes[id]
		if n != null and "chest_id" in n:
			kist = n
	check("E kist gevonden", kist != null)
	if kist == null:
		return
	var c: Dictionary = kamer.logic.chests[kist.chest_id]
	var item := str(c["item"])
	kamer.request_chest(kist, kamer.player)
	await pframes(2)
	await _sluit_tekst()
	await pframes(3)
	kamer.request_chest(kist, kamer.player)
	await pframes(2)
	await _sluit_tekst()
	check("E1 kist twee keer: één keer de buit (%s x%d)" % [item, GameState.item_count(item)],
			GameState.item_count(item) == int(c["n"]))
	var pad := "user://qa_sweep_kist.json"
	check("E2 opslaan na de kist", GameState.save_game(kamer.player.get_tile(), kamer.player.facing, pad))
	check("E2 laden", GameState.load_game(pad))
	kamer = await _naar(PUZZEL, "ingang")
	if kamer == null:
		check("E2 kamer opnieuw geladen", false)
		return
	var kist2: Node = kamer.nodes.get(kist.chest_id) if is_instance_valid(kist) else null
	if kist2 == null:
		for id in kamer.nodes:
			var n: Node = kamer.nodes[id]
			if n != null and "chest_id" in n:
				kist2 = n
	kamer.request_chest(kist2, kamer.player)
	await pframes(2)
	await _sluit_tekst()
	check("E2 na laden: kist is leeg, geen tweede buit", kamer.chest_taken(kist2.chest_id)
			and GameState.item_count(item) == int(c["n"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad + ".bak"))


# ---------------------------------------------------------------- F: gevecht-einde
func _gevecht_einde_tests() -> void:
	_schoon()
	GameState.add_member("noor")
	GameState.gold = 101
	GameState.checkpoint = {}
	GameState.party[1]["hp"] = 0
	GameState.return_map = DORP
	GameState.in_battle = true
	GameState.pending_boss = false
	GameState.end_battle("win")
	await _wacht_kaart(DORP)
	check("F1 winst: KO-held staat op met 1 HP, niemand < 0", int(GameState.party[1]["hp"]) == 1
			and GameState.party.all(func(h): return int(h["hp"]) > 0 and int(h["hp"]) <= int(h["max_hp"])))
	check("F1 winst: niet meer in gevecht, geen mapwissel hangend", not GameState.in_battle and not GameState.changing_map)
	# F2 verlies zonder checkpoint: helft van het goud, nooit negatief, iedereen heel
	GameState.checkpoint = {}
	for h in GameState.party:
		h["hp"] = 0
	GameState.in_battle = true
	GameState.end_battle("lose")
	await _wacht_kaart(GameState.RESPAWN_MAP)
	await _sluit_tekst()
	check("F2 verlies zonder checkpoint: goud 0..voor (%d)" % GameState.gold, GameState.gold >= 0 and GameState.gold <= 101)
	check("F2 verlies: hele party weer vol HP (geen dode leider)",
			GameState.party.all(func(h): return int(h["hp"]) == int(h["max_hp"])) and GameState.active_leader() != "")
	check("F2 verlies: flow weer vrij", not GameState.in_battle and not GameState.changing_map)


func _wacht_kaart(pad: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
		var s := scene()
		if s != null and s.scene_file_path == pad and s.is_node_ready() and not GameState.changing_map:
			break
	await pframes(4)


# ---------------------------------------------------------------- G: touch na pauze
func _touch_pauze_tests() -> void:
	var kaart := scene()
	var touch: Node = kaart.get_node_or_null("TouchControls/Control") if kaart != null else null
	check("G touch-laag op de kaart", touch != null and touch.has_method("release_all"))
	if touch == null:
		return
	# een vinger op de joystick: move_right ingedrukt via de touch-laag
	touch._touch_owner[0] = "joy"
	Input.action_press("move_right")
	touch._press_count["move_right"] = 1
	check("G1 joystick vast: move_right ingedrukt", Input.is_action_pressed("move_right"))
	# Android kan PAUSED sturen zonder dat de laag eerst FOCUS_OUT krijgt (scherm uit, split-screen)
	touch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await pframes(2)
	check("G1 na PAUSED: geen richting meer ingedrukt (geen doorlopen na hervatten)",
			not Input.is_action_pressed("move_right") and touch._touch_owner.is_empty())
	Input.action_release("move_right")
	touch.release_all()
	# regressie: FOCUS_OUT laat ook los
	Input.action_press("move_left")
	touch._press_count["move_left"] = 1
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("G2 regressie: FOCUS_OUT laat alles los", not Input.is_action_pressed("move_left"))
	Input.action_release("move_left")


# ---------------------------------------------------------------- H: warps
func _route_kaarten() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(MAPS_DIR):
		var naam := str(f).trim_suffix(".remap")
		if naam.ends_with(".tscn") and not NIET_IN_ROUTE.has(naam):
			out.append(MAPS_DIR + naam)
	out.sort()
	return out


func _uitgangen(kaart: Node) -> Array:
	var out: Array = []
	var ex := kaart.get_node_or_null("Exits")
	if ex == null:
		return out
	for e in ex.get_children():
		if "target_map" in e and str(e.target_map) != "":
			out.append({"naam": str(e.name), "map": str(e.target_map), "spawn": str(e.target_spawn),
					"rect": e.tile_rect(), "event": str(e.event) if "event" in e else ""})
	return out


func _beweegt(p: Node) -> bool:
	for dvec in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if p._can_move(dvec):
			return true
	return false


## Speelstand waarin elk aankomstpunt te bereiken is (zoals archieftest deel H2): Vesper in de party
## (bouwplaats-tunnel open) en de Golem verslagen.
func _warp_stand() -> void:
	_schoon()
	GameState.story_step = 100
	GameState.story_flags["noor_lid"] = true
	GameState.story_flags["bewaker:archief_golemhal/golem"] = true


func _warp_tests() -> void:
	_warp_stand()
	var kaarten := _route_kaarten()
	check("H kaarten in de route gevonden (%d)" % kaarten.size(), kaarten.size() >= 20)
	# 1) uitgangen per kaart verzamelen
	var graaf := {}
	var spawns := {}
	var warpers: Array = []
	for k in kaarten:
		var s := await _naar(k, "")
		if s == null:
			check("H kaart laadt: %s" % k.get_file(), false)
			continue
		graaf[k] = _uitgangen(s)
		var namen: Array = []
		var sp_root := s.get_node_or_null("Spawns")
		if sp_root != null:
			for c in sp_root.get_children():
				namen.append(str(c.name))
		spawns[k] = namen
		var w := s.get_node_or_null("Objects/ExitWarper")
		if w != null and "world_spawn" in w and str(w.role) != "begin":
			warpers.append({"kamer": k, "map": str(w.world_scene), "spawn": str(w.world_spawn)})
		await _sluit_tekst()
	var totaal := 0
	for k in graaf:
		totaal += (graaf[k] as Array).size()
	info("H %d kaarten, %d uitgangen met een doel" % [graaf.size(), totaal])
	# 2) elke uitgang echt nemen (zonder verhaal-poort): spawn bestaat, niet in een muur, niet ingeklemd,
	# niet meteen weer op een uitgang
	var fout_doel: Array = []
	var fout_spawn: Array = []
	var fout_muur: Array = []
	var fout_klem: Array = []
	var fout_pingpong: Array = []
	for k in graaf:
		for e in graaf[k]:
			var doel := str(e["map"])
			var tag := "%s/%s -> %s:%s" % [k.get_file(), e["naam"], doel.get_file(), e["spawn"]]
			if not ResourceLoader.exists(doel):
				fout_doel.append(tag)
				continue
			_warp_stand()
			GameState.current_map = k
			var s := await _naar(doel, str(e["spawn"]))
			if s == null:
				fout_doel.append(tag + " (laadt niet)")
				continue
			var p: Node = s.get_node_or_null("Objects/Player")
			var sp: Node = s.get_spawn(str(e["spawn"])) if s.has_method("get_spawn") else null
			if sp == null:
				fout_spawn.append(tag)
				await _sluit_tekst()
				continue
			var t: Vector2i = sp.get_tile()
			if p != null and p.get_tile() != t:
				info("H %s: speler op %s, spawn %s (verhaal verplaatst hem?)" % [tag, p.get_tile(), t])
			if s.has_method("is_wall") and s.is_wall(t):
				fout_muur.append(tag + " " + str(t))
			if p != null and p.get_tile() == t and not _beweegt(p):
				fout_klem.append(tag + " " + str(t))
			for terug in _uitgangen(s):
				if (terug["rect"] as Rect2i).has_point(t):
					fout_pingpong.append("%s staat op uitgang %s" % [tag, terug["naam"]])
			await _sluit_tekst()
	check("H1 elk doel van een uitgang bestaat (%s)" % [fout_doel], fout_doel.is_empty())
	check("H2 elk doel-spawnpunt bestaat (%s)" % [fout_spawn], fout_spawn.is_empty())
	check("H3 geen spawn in een muur (%s)" % [fout_muur], fout_muur.is_empty())
	check("H4 speler kan na de warp bewegen (%s)" % [fout_klem], fout_klem.is_empty())
	check("H5 geen spawn op een uitgang (pingpong) (%s)" % [fout_pingpong], fout_pingpong.is_empty())
	# uitgang-warpers (dungeon -> wereldkaart): het spawnpunt op de wereldkaart bestaat
	var fout_warper: Array = []
	for w in warpers:
		if not (spawns.get(w["map"], []) as Array).has(w["spawn"]):
			fout_warper.append("%s -> %s:%s" % [str(w["kamer"]).get_file(), str(w["map"]).get_file(), w["spawn"]])
	info("H %d uitgang-warpers (midden/eind) gevonden" % warpers.size())
	check("H6 elke uitgang-warper landt op een bestaand spawnpunt op de wereldkaart (%s)" % [fout_warper],
			fout_warper.is_empty() and warpers.size() >= 3)
	# 3) terugweg: een deur heen heeft een deur terug naar dezelfde kaart (informatief: warpers zijn eenrichting)
	for k in graaf:
		for e in graaf[k]:
			var doel := str(e["map"])
			if not graaf.has(doel) or doel == k:
				continue
			var terug := (graaf[doel] as Array).any(func(x): return str(x["map"]) == k)
			if not terug:
				info("H geen directe terugweg: %s/%s -> %s" % [k.get_file(), e["naam"], doel.get_file()])


# ---------------------------------------------------------------- I: absorptie na de baas
## Na de Golem staat pending_kern_absorb klaar; het moment (CS-02 + Sapientia-zin, of 'absorbs ... / New skill')
## start pas 0,45 s na de fade-in. Een pauze-save in dat venster (of tijdens het effect van een andere kern)
## bewaarde de kern wel, maar niet het moment: na laden speelde het nooit meer.
func _absorptie_tests() -> void:
	_schoon()
	GameState.story_step = 100
	check("I kern geven lukt", GameState.grant_kern("golemkern", "golem"))
	GameState.pending_kern_absorb = "golemkern"
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.state_data(Vector2i(4, 4), Vector2i.DOWN, DORP)))
	GameState.pending_kern_absorb = ""
	GameState.apply_state(d)
	check("I1 save met openstaand absorptie-moment: na laden staat het weer klaar (%s)" % GameState.pending_kern_absorb,
			GameState.pending_kern_absorb == "golemkern")
	# geen spook-moment voor een kern die je niet hebt (kapotte of oude save)
	d["kernen"] = {}
	GameState.apply_state(d)
	check("I2 openstaand moment zonder de kern zelf: genegeerd", GameState.pending_kern_absorb == "")
	d.erase("pending_kern_absorb")
	GameState.apply_state(d)
	check("I3 oude save zonder sleutel: geen moment", GameState.pending_kern_absorb == "")
	# echt laden in een kaart: het moment speelt en sluit af (geen hangende invoer/flow)
	GameState.grant_kern("golemkern", "golem")
	GameState.pending_kern_absorb = "golemkern"
	var pad := "user://qa_sweep_kern.json"
	GameState.current_map = DORP
	check("I4 opslaan met openstaand moment", GameState.save_game(Vector2i(14, 30), Vector2i.UP, pad))
	_schoon("Wis")
	check("I4 laden", GameState.load_game(pad))
	GameState.changing_map = true
	await Transition.fade_out()
	GameState._go_to_scene(GameState.return_map)
	await _wacht_kaart(DORP)
	var s := scene()
	var bezig := s != null and s.get_node_or_null("KernAbsorptie") != null
	check("I4 na laden start het absorptie-moment op de kaart", bezig)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000 and GameState.pending_kern_absorb != "":
		if Dialog.is_open:
			Dialog.close()
		await pframes(2)
	await pframes(5)
	var p: Node = s.get_node_or_null("Objects/Player") if s != null else null
	check("I4 moment klaar: niets meer open, speler vrij", GameState.pending_kern_absorb == "" and not Dialog.is_open
			and p != null and not bool(p.input_locked))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pad + ".bak"))


# ---------------------------------------------------------------- J: pauze/hervatten
func _pauze_tests() -> void:
	_schoon()
	GameState.story_step = 100
	var kaart := await _naar(DORP, "")
	check("J dorp geladen", kaart != null)
	if kaart == null:
		return
	await _sluit_tekst()
	var p: Node = kaart.get_node_or_null("Objects/Player")
	var blokkers := {
		"tekstvak": func(aan: bool) -> void:
			if aan:
				Dialog.show_lines(["Test."])
			else:
				Dialog.close(),
		"gevecht": func(aan: bool) -> void: GameState.in_battle = aan,
		"mapwissel": func(aan: bool) -> void: GameState.changing_map = aan,
		"cutscene": func(aan: bool) -> void: Story.running = aan,
	}
	for naam in blokkers:
		var n0 := GameState.autosave_count
		blokkers[naam].call(true)
		await pframes(2)
		GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		blokkers[naam].call(false)
		await pframes(2)
		check("J1 pauze tijdens %s: geen save" % naam, GameState.autosave_count == n0)
	await _sluit_tekst()
	var voor := GameState.state_data(p.get_tile(), p.facing)
	var n1 := GameState.autosave_count
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await pframes(2)
	check("J2 pauze in het veld: precies één save (reden achtergrond)", GameState.autosave_count == n1 + 1
			and GameState.last_autosave_reason == "achtergrond")
	GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await pframes(2)
	var na := GameState.state_data(p.get_tile(), p.facing)
	var verschil: Array = []
	for k in voor:
		if k != "play_time" and JSON.stringify(voor[k]) != JSON.stringify(na.get(k)):
			verschil.append(k)
	check("J3 hervatten verandert niets (verschil: %s)" % [verschil], verschil.is_empty())
	check("J3 na hervatten: flow weer vrij", GameState.field_free())
	var n2 := GameState.autosave_count
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	GameState.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	info("J4 twee keer PAUSED zonder RESUMED: %d saves (Android stuurt FOCUS_OUT + PAUSED; zie open punten)"
			% (GameState.autosave_count - n2))
	GameState.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
