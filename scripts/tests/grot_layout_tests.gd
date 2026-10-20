extends Node
## --grotlayouttest: layout-types van de Diepe Grot (scripts/data/grot_layouts.gd) en hoe de generator
## ze bouwt (maat, monsters, kisten, blauw). TODO.md "Diepe Grot – map generatie (uitgebreid)".

const L := preload("res://scripts/data/grot_layouts.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const GK := preload("res://scripts/data/grot_kamers.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const S := preload("res://scripts/data/dungeon100_scaling.gd")
const GP := preload("res://scripts/data/grot_puzzels.gd")

var passes := 0
var failures := 0


func check(name: String, ok: bool) -> void:
	if ok:
		passes += 1
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name)


func _ready() -> void:
	await get_tree().process_frame
	_tegelvarianten()
	_vaste_kamers()
	_kansen()
	_balans()
	await _generator()
	await _val_flits()
	await _lege_kamers()
	_puzzel_logica()
	await _puzzel_kamers()
	print("GROTLAYOUTTEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


func _tegelvarianten() -> void:
	const DR := preload("res://scripts/data/dungeon_rooms.gd")
	var want := {1: 1, 15: 1, 16: 2, 30: 2, 31: 3, 46: 4, 61: 5, 76: 6, 90: 6, 91: 7, 99: 7, 100: 7}
	var ok := true
	for f in want:
		ok = ok and Gen.theme_variant(f) == int(want[f])
	check("tegelvariant = min((verdieping-1)/15, 6) + 1 (1-15 v1 ... 91-100 v7)", ok)
	var th_ok := true
	for i in range(1, 8):
		var th := "diepe_grot_v%d" % i
		th_ok = th_ok and DR.THEMES.has(th) and ResourceLoader.exists(str(DR.THEMES[th]["tiles"]))
	check("zeven thema's diepe_grot_v1..v7 met bestaande atlas", th_ok)
	check("generator zet het thema per verdieping", str(Gen.generate(4, 20)["room"]["theme"]) == "diepe_grot_v2"
			and str(Gen.generate(4, 95)["room"]["theme"]) == "diepe_grot_v7")


func _vaste_kamers() -> void:
	var ok := true
	for sd in [1, 7, 42]:
		ok = ok and GK.layout_soort(sd, 100) == L.VLOER100
		for f in S.boss_floors():
			ok = ok and GK.layout_soort(sd, f) == L.BAAS
		for f in range(1, 100):
			var is_k := GK.kamer_soort(sd, f) == GK.SOORT_KOOPMAN
			ok = ok and (is_k == (GK.layout_soort(sd, f) == L.KOOPMAN))
	check("vast: 100 = VLOER100, baasverdiepingen (25/50/75/99 en tientallen) = BAAS, koopman volgt GrotKamers", ok)
	check("deterministisch: zelfde seed + verdieping = zelfde type (save/load)", GK.layout_soort(5, 33) == GK.layout_soort(5, 33)
			and str(Gen.generate(5, 33)["layout_type"]) == GK.layout_soort(5, 33)
			and str(Gen.generate(5, 33)["room"]["dungeon100_layout"]) == GK.layout_soort(5, 33))


func _kansen() -> void:
	var tel := {}
	var n := 0
	for sd in 300:
		for f in range(6, 100):
			if L.is_vast(f):
				continue
			var s := L.gerold(sd * 13 + 1, f)
			tel[s] = int(tel.get(s, 0)) + 1
			n += 1
	var totaal := 0
	for s in L.VOLGORDE:
		if L.toegestaan(s, 50):
			totaal += int(L.KANSEN[s])
	var ok := true
	for s in L.VOLGORDE:
		var want := float(L.KANSEN[s]) / float(totaal) if L.toegestaan(s, 50) else 0.0
		var p := float(tel.get(s, 0)) / float(n)
		if absf(p - want) > 0.015:
			ok = false
			print("  %s: %.3f (verwacht %.3f)" % [s, p, want])
	check("worp volgt de CANON-verhouding 35/20/10/7/5/5/3 (genormaliseerd naar 100 procent)", ok)


func _balans() -> void:
	var puzzel_vroeg := false
	var val_vroeg := false
	var schat_naast_rust := false
	for sd in 400:
		for f in range(1, 100):
			var s := GK.layout_soort(sd, f)
			puzzel_vroeg = puzzel_vroeg or (s == L.PUZZEL and f <= 5)
			val_vroeg = val_vroeg or (s == L.VAL and f <= 3)
			if s == L.SCHAT:
				for nb in [f - 1, f + 1]:
					if nb >= 1 and nb < 100 and GK.kamer_soort(sd, nb) == GK.SOORT_RUST:
						schat_naast_rust = true
	check("PUZZLE ROOM nooit op 1-5", not puzzel_vroeg)
	check("TRAP ROOM nooit op 1-3", not val_vroeg)
	check("REST ROOM en TREASURE ROOM nooit op opeenvolgende verdiepingen", not schat_naast_rust)


func _find(soort: String, from := 4) -> Array:
	for sd in 200:
		for f in range(from, 100):
			if GK.layout_soort(sd, f) == soort:
				return [sd, f]
	return []


func _blauw(d: Dictionary) -> int:
	var nb := 0
	for c in d["room"]["chests"]:
		if str(c.get("kind", "")) == Blue.KIND_BLUE:
			nb += 1
	return nb


func _generator() -> void:
	for soort in [L.MEDIUM, L.GROOT, L.KIST, L.VAL, L.SCHAT, L.LEEG, L.RUST, L.BAAS]:
		var at := _find(soort)
		if at.is_empty():
			check("type %s gevonden" % soort, false)
			continue
		var d := Gen.generate(int(at[0]), int(at[1]))
		var f := int(at[1])
		var size: Vector2i = d["size"]
		var room: Dictionary = d["room"]
		var mons := (d["monster_slots"] as Array).size()
		var kisten := (d["chest_slots"] as Array).size()
		var nb := _blauw(d)
		var mb := L.monster_bereik(soort, f)
		var ok := size == L.maat(soort) and (room["layout"] as Array).size() == size.y and mons <= int(mb[1]) \
				and mons >= mini(int(mb[0]), 3 if int(mb[0]) > 0 else 0)
		match soort:
			L.KIST:
				ok = ok and kisten == 3
			L.SCHAT:
				ok = ok and mons == 0 and kisten >= 2 and kisten <= 3
			L.LEEG, L.RUST:
				ok = ok and mons == 0 and kisten == 0
			L.GROOT:
				ok = ok and kisten >= 6
			L.MEDIUM:
				ok = ok and kisten >= 2 and kisten <= 4
		if soort == L.RUST:
			ok = ok and room.has("rustpunt")
		check("%s op seed %d verdieping %d: %dx%d, %d monsters, %d kisten (%d blauw)" % [soort, int(at[0]), f, size.x, size.y, mons, kisten, nb], ok)
		await get_tree().process_frame
	var d100 := Gen.generate(3, 100)
	check("verdieping 100: geen monsters, geen kisten", (d100["monster_slots"] as Array).is_empty() and (d100["chest_slots"] as Array).is_empty())
	# medium-monsters per bracket
	var bracket_ok := true
	for sd in 30:
		for f in [5, 30, 60, 90]:
			if GK.layout_soort(sd, f) != L.MEDIUM:
				continue
			var d := Gen.generate(sd, f)
			var b := L.monster_bereik(L.MEDIUM, f)
			var m := (d["monster_slots"] as Array).size()
			bracket_ok = bracket_ok and m >= int(b[0]) and m <= int(b[1])
	check("MEDIUM MAP: monsters per floor-bracket (8-10 / 10-12 / 12-14 / 14-16)", bracket_ok)


## EMPTY ROOM: ~30% een lore-notitie (besluit Dennis 14 okt 2026), anders leeg; nooit een blokkade.
func _lege_kamers() -> void:
	var n := 0
	var met := 0
	var ok_plek := true
	var ok_pad := true
	var ok_tekst := true
	var voorbeeld: Array = []
	for sd in 60:
		for f in range(2, 100):
			if GK.layout_soort(sd, f) != L.LEEG:
				continue
			n += 1
			var d := Gen.generate(sd, f)
			var room: Dictionary = d["room"]
			if not room.has("notitie"):
				ok_plek = ok_plek and not GK.heeft_notitie(sd, f) or GK.notitie(sd, room, d).is_empty()
				continue
			met += 1
			if voorbeeld.is_empty():
				voorbeeld = [sd, f]
			var t := Vector2i(int(room["notitie"][0]), int(room["notitie"][1]))
			var props: Array = room.get("props", [])
			var signs: Array = room.get("signs", [])
			ok_plek = ok_plek and props.any(func(p): return p["type"] == GK.NOTITIE_PROP and Vector2i(int(p["tile"][0]), int(p["tile"][1])) == t) \
					and signs.any(func(sg): return Vector2i(int(sg["tile"][0]), int(sg["tile"][1])) == t)
			for sg in signs:
				for line in sg["lines"]:
					ok_tekst = ok_tekst and str(line) in GK.NOTITIES
			# de notitie blokkeert de trap niet (BFS met de notitie als muur)
			var bereik := Gen.reachable_tiles(room, d["spawn_up"])
			if d["has_stairs_down"]:
				ok_pad = ok_pad and bereik.has(d["stairs_down"])
		if n > 400:
			break
	var frac := float(met) / maxf(1.0, float(n))
	check("EMPTY ROOM: %d van %d lege kamers met een notitie (%.0f%%, doel ~30%%)" % [met, n, frac * 100.0],
			n >= 40 and frac > 0.18 and frac < 0.42)
	check("EMPTY ROOM: notitie = prop grot_notitie + leesplek op dezelfde tegel", ok_plek)
	check("EMPTY ROOM: tekst komt uit GK.NOTITIES (Engels)", ok_tekst)
	check("EMPTY ROOM: trap blijft bereikbaar", ok_pad)
	check("EMPTY ROOM: plaatje bestaat", ResourceLoader.exists("res://assets/sprites/dungeon/grot_notitie.png"))
	check("EMPTY ROOM: geen monsters en geen kisten ook met notitie", voorbeeld.size() == 2
			and (Gen.generate(voorbeeld[0], voorbeeld[1])["room"]["monsters"] as Array).is_empty()
			and (Gen.generate(voorbeeld[0], voorbeeld[1])["room"]["chests"] as Array).is_empty())
	await get_tree().process_frame


## PUZZLE ROOM: elke puzzel is met de bestaande stukken op te lossen (PuzzleLogic, zonder scène).
func _puzzel_logica() -> void:
	var o := Vector2i(2, 2)
	var sz := Vector2i(12, 10)
	var R := Vector2i.RIGHT
	var Lf := Vector2i.LEFT
	var U := Vector2i.UP
	var oplossing := {
		"kast_plaat": [["kast_a", R], ["kast_a", R]],
		"twee_kasten": [["kast_a", Lf], ["kast_a", U], ["kast_b", R], ["kast_b", U]],
		"kast_groei": [["kast_a", R], ["kast_a", R]],
		"hendel_groei": [],
	}
	for id in GP.VOLGORDE:
		var lg := PuzzleLogic.from_room(GP.logica_kamer(id, o, sz), "test_" + id)
		lg.set_player_tile(o + Vector2i(0, 5))
		var dicht := true
		for g in lg.gates:
			dicht = dicht and not lg.gate_open(g)
		for g in lg.grows:
			dicht = dicht and lg.try_grow(g) == "wacht"
		var ok := true
		for stap in oplossing[id]:
			ok = ok and lg.try_push(str(stap[0]), stap[1])
		for h in lg.levers:
			lg.toggle_lever(h)
		for g in lg.grows:
			for i in 3:
				lg.try_grow(g)
		var open := false
		for g in lg.gates:
			open = open or lg.gate_open(g)
		for g in lg.grows:
			open = open or lg.grow_open(g)
		var nis := o + GP.kist_lokaal(id) + Vector2i.DOWN
		check("PUZZLE %s: eerst dicht, opgelost open (nis %s), kast blijft in het vak" % [id, nis], dicht and ok and open
				and lg.walls.has(o + Vector2i(-1, 0)) and GP.puzzel(id).get("hint", "") != "")


## PUZZLE ROOM in de generator: vanaf 6, geen monsters, 1 blauwe kist in de nis, trap + vak bereikbaar.
func _puzzel_kamers() -> void:
	var n := 0
	var ok := true
	var soorten := {}
	for sd in 80:
		for f in range(6, 100):
			if GK.layout_soort(sd, f) != L.PUZZEL:
				continue
			n += 1
			var d := Gen.generate(sd, f)
			var room: Dictionary = d["room"]
			if not room.has("puzzel"):
				ok = false
				print("  geen puzzel op seed %d verdieping %d" % [sd, f])
				continue
			var pz: Dictionary = room["puzzel"]
			soorten[pz["id"]] = true
			var po := Vector2i(int(pz["origin"][0]), int(pz["origin"][1]))
			var kt := po + GP.kist_lokaal(str(pz["id"]))
			var blauw := 0
			var kist_ok := false
			for c in room["chests"]:
				if str(c.get("kind", "")) == Blue.KIND_BLUE:
					blauw += 1
				if Vector2i(int(c["tile"][0]), int(c["tile"][1])) == kt and str(c.get("kind", "")) == Blue.KIND_BLUE:
					kist_ok = true
			var bereik := Gen.reachable_tiles(room, d["spawn_up"])
			# Besluit Dennis (PR #102): plaatpuzzels (puzzel_duw) hebben precies 1 stilstaand monster naast de plaat,
			# de andere puzzels (kast_groei, hendel_groei) blijven monsterloos.
			var mons: Array = room["monsters"]
			var mon_ok: bool = mons.is_empty() if not room.has("puzzel_duw") \
					else (mons.size() == 1 and bool(mons[0].get("puzzel_duw", false)))
			var goed: bool = kist_ok and blauw == 1 and mon_ok \
					and (not d["has_stairs_down"] or bereik.has(d["stairs_down"])) and bereik.has(po + Vector2i(3, 3)) \
					and not bereik.has(kt)
			if not goed:
				print("  fout op seed %d verdieping %d: kist %s blauw %d" % [sd, f, kist_ok, blauw])
			ok = ok and goed
		if n >= 120:
			break
		if sd % 10 == 0:
			await get_tree().process_frame
	check("PUZZLE ROOM: %d kamers: puzzel, 0 monsters (plaatpuzzel: 1 monster naast de plaat), 1 blauwe kist in de nis, trap en vak bereikbaar" % n, n >= 30 and ok)
	check("PUZZLE ROOM: alle %d puzzels komen voor (%s)" % [GP.VOLGORDE.size(), soorten.keys()], soorten.size() == GP.VOLGORDE.size())


## TRAP ROOM: verborgen vallen flitsen binnen 2 tegels (besluit Dennis 14 okt 2026).
func _val_flits() -> void:
	var ValC := load("res://scripts/dungeon/dungeon100_val.gd")
	check("flitsbereik: 2 tegels (ook schuin), 3 niet", GK.in_flits_bereik(Vector2i(5, 5), Vector2i(7, 7))
			and GK.in_flits_bereik(Vector2i(5, 5), Vector2i(5, 3)) and not GK.in_flits_bereik(Vector2i(5, 5), Vector2i(8, 5)))
	var v: Node2D = ValC.create({"tile": Vector2i(5, 5), "soort": "rune", "verborgen": true})
	add_child(v)
	await get_tree().process_frame
	v.speler_bij(Vector2i(8, 5))
	var a: int = v.flitsen
	v.speler_bij(Vector2i(7, 5))
	var b: int = v.flitsen
	var bezig: bool = v.flitsend
	v.speler_bij(Vector2i(6, 5))
	var c: int = v.flitsen
	await get_tree().create_timer(0.8).timeout
	var terug: bool = str(v.anim.animation) == "verborgen" and not v.flitsend
	v.speler_bij(Vector2i(10, 5))
	v.speler_bij(Vector2i(7, 4))
	check("verborgen val: geen flits op 3, flits op 2, één keer per nadering, daarna weer verborgen (%d %d %d %d)" % [a, b, c, v.flitsen],
			a == 0 and b == 1 and bezig and c == 1 and terug and v.flitsen == 2)
	var z: Node2D = ValC.create({"tile": Vector2i(5, 5), "soort": "spijker", "verborgen": false})
	add_child(z)
	await get_tree().process_frame
	z.speler_bij(Vector2i(6, 5))
	check("zichtbare val flitst niet", z.flitsen == 0)
	v.trigger()
	v.speler_bij(Vector2i(20, 20))
	v.speler_bij(Vector2i(6, 5))
	check("afgegane val flitst niet meer", v.flitsen == 2)
	v.queue_free()
	z.queue_free()
