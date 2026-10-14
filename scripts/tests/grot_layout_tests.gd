extends Node
## --grotlayouttest: layout-types van de Diepe Grot (scripts/data/grot_layouts.gd) en hoe de generator
## ze bouwt (maat, monsters, kisten, blauw). TODO.md "Diepe Grot – map generatie (uitgebreid)".

const L := preload("res://scripts/data/grot_layouts.gd")
const Gen := preload("res://scripts/dungeon/dungeon100_generator.gd")
const GK := preload("res://scripts/data/grot_kamers.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")
const S := preload("res://scripts/data/dungeon100_scaling.gd")

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
	check("worp volgt de CANON-verhouding 35/20/10/7/5/5/3 (genormaliseerd, puzzel uit)", ok)


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
