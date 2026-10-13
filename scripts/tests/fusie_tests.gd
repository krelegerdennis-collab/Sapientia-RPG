extends Node
## ALLEEN VOOR TESTEN - v0.19 GLITCH-FUSIE (Kernfragment stap 3) + de Inktwurm: zie HANDOFF_FUSIE.md.
## Start:  godot --path . -- --fusietest [--shots=/pad/map] [--alleen=ABCDE]
##   Deel A: data (fusietabel geldig, Inktwurm als vijand + Codex-soort, plaatsvervanger-art, regels:
##           soort uit de tabel / glitch-variant, level, stats, vaardigheden, generatie).
##   Deel B: GameState: zelfde pagina 2x, maar 1 pagina, onbekende uid, Codex vol, ouders weg, nieuwe uid,
##           bondgenoot (A, B of geen), voorbeeld verandert niets, geen dubbele fusie, niet in een gevecht.
##   Deel C: save/load van een gefuseerde pagina (+ kapotte fusie-data).
##   Deel D: Codex-scherm: 'Fusie' (tik + D-pad rechts), kies 1, kies 2, voorbeeld, B terug, Fuseren!,
##           layout (tikhoogte >= 16, niets buiten beeld / over elkaar op 384x216).
##   Deel E: gevecht: gefuseerde bondgenoot is paars; de Inktwurm als vijand (art of plaatsvervanger).
##   Deel F: Inktwurm = BESLISSING DENNIS: uniek (1x, nooit terug, ook niet na save/load), vangkans 100%
##           (wel een Leeg Boek), Lv 5 met 2x de stats van een normaal Lv 5-monster, groei 1,5x het
##           gemiddelde, tot Lv 7 alleen aanvallen, Lv 8 Inktspuw, AI 45% vaardigheid.
##   Deel G: Codex-knop in het gevecht (v0.19): verborgen bij 0 pagina's + 0 boeken en in het
##           oefengevecht, D-pad/tik, submenu (regels >= 16), Vangen met kans per doel + aantal
##           boeken (weigeringen kosten geen boek), Wissel bondgenoot (alleen niet-KO + 'Geen', kost
##           de beurt, scrollen bij een volle Codex), Item > Leeg Boek werkt nog.
## Met --shots=map: fusie_codex, fusie_kies2, fusie_voorbeeld, fusie_resultaat, fusie_bondgenoot,
## inktwurm_gevecht, inktwurm_codex, codex_knop_menu, codex_knop_vangen, codex_knop_wissel
## (+ _3x = 1152x648).
## Zit niet in de export (scripts/tests/*).

const GD := preload("res://scripts/data/game_data.gd")
const SD := preload("res://scripts/data/story_data.gd")
const CD := preload("res://scripts/data/codex_data.gd")
const GOLEM_SCENE := "res://scenes/maps/archief_golemhal.tscn"
const CROSS_DIRS := {1: "move_up", 2: "move_left", 3: "move_right", 4: "move_down"}
const CROSS_BACK := {1: "move_down", 2: "move_right", 3: "move_left", 4: "move_up", 5: "move_left"}
const ITEM := 2
const CODEX := 5
const VERDEDIG := 3
const BASE := Vector2(384, 216)

var failures := 0
var passes := 0
var shots := ""
var messages: Array = []
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
		if arg.begins_with("--alleen="):
			only = arg.get_slice("=", 1)
	seed(2026)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	if part("A"):
		print("=== Deel A: data + regels ===")
		_data_tests()
	if part("B"):
		print("=== Deel B: GameState (randgevallen) ===")
		_state_tests()
	if part("C"):
		print("=== Deel C: save/load ===")
		await _save_tests()
	if part("D"):
		print("=== Deel D: Codex-scherm ===")
		await _screen_tests()
	if part("E"):
		print("=== Deel E: gevecht ===")
		await _battle_tests()
	if part("F"):
		print("=== Deel F: Ink Worm (beslissing Dennis) ===")
		await _unique_tests()
	if part("G"):
		print("=== Deel G: Codex-knop in het gevecht ===")
		await _codex_button_tests()
	print("FUSIETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	Engine.time_scale = 1.0
	await pframes(30)
	get_tree().quit(1 if failures else 0)


## Pagina's zonder GameState (voor de regels).
func pg(species: String, level: int, uid: String) -> Dictionary:
	return CD.make_page(species, level, uid)


# ================================================================ deel A: data + regels
func _data_tests() -> void:
	var errs := CD.validate()
	check("CodexData.validate (met fusietabel) zonder fouten %s" % [errs], errs.is_empty())
	check("validate_fusion leeg", CD.validate_fusion().is_empty())
	# --- Inktwurm
	var iw: Dictionary = GD.ENEMIES.get("inktwurm", {})
	var mw: Dictionary = GD.ENEMIES["mech_wachter"]
	check("Ink Worm staat in ENEMIES (naam, Archief, bestiarium 12)", not iw.is_empty() and iw["name"] == "Ink Worm"
			and "archief" in iw["habitat"] and int(iw["no"]) == 12 and iw.has("desc") and iw.has("drops"))
	check("Ink Worm: art-paden volgens ART v19 (voor, _rug, _idle 2 frames)", iw.get("sprite") == "res://assets/sprites/enemies/inktwurm.png"
			and iw.get("sprite_back") == "res://assets/sprites/enemies/inktwurm_rug.png"
			and iw.get("idle") == "res://assets/sprites/enemies/inktwurm_idle.png" and int(iw.get("idle_frames", 0)) == 2)
	var normal := CD.normal_stats_at(5)
	var twice := true
	for k in ["max_hp", "atk", "def", "agi"]:
		if int(iw[k]) != GD.round_half_even(2.0 * float(normal[k])):
			twice = false
	check("Ink Worm = 2x normaal Lv 5 (normaal HP %.1f ATK %.1f DEF %.1f SPD %.1f -> %d/%d/%d/%d)" % [normal["max_hp"], normal["atk"],
			normal["def"], normal["agi"], iw["max_hp"], iw["atk"], iw["def"], iw["agi"]], twice and int(iw["max_hp"]) == 68)
	check("Ink Worm: uniek, gevechtsniveau 5, als vijand nog geen vaardigheid", bool(iw.get("unique", false))
			and int(iw.get("encounter_level", 0)) == 5 and (iw["skills"] as Array).is_empty() and iw["weak"] == ["vuur"])
	var sp_path := GD.enemy_sprite(iw)
	check("Ink Worm-plaatje: echte art of plaatsvervanger (%s), bestaat altijd" % sp_path, ResourceLoader.exists(sp_path)
			and (sp_path == iw["sprite"]) == ResourceLoader.exists(str(iw["sprite"])))
	check("enemy_sprite: bestaande art = gewoon 'sprite'", GD.enemy_sprite(GD.ENEMIES["papiergeest"]) == GD.ENEMIES["papiergeest"]["sprite"]
			and not GD.enemy_sprite_is_placeholder(GD.ENEMIES["papiergeest"]))
	check("enemy_sprite: ontbrekend bestand -> plaatsvervanger", GD.enemy_sprite({"sprite": "res://bestaat/niet.png"}) == GD.PLACEHOLDER_ENEMY_SPRITE
			and ResourceLoader.exists(GD.PLACEHOLDER_ENEMY_SPRITE))
	var s := CD.species("inktwurm")
	check("Codex-soort Ink Worm: inkt/worm, labels [inkt, worm], base_level 5, zwakste, vaardigheid 40-50%%",
			not s.is_empty() and s["element"] == "inkt" and s["type"] == "worm" and s["fusion_tags"] == ["inkt", "worm"]
			and int(s["base_level"]) == 5 and s["ai"]["target"] == "zwakste"
			and float(s["ai"]["skill_chance"]) >= 0.4 and float(s["ai"]["skill_chance"]) <= 0.5)
	check("Ink Spit: element inkt, schade", CD.skill("inktspuw").get("element") == "inkt" and CD.skill("inktspuw")["type"] == "damage")
	check("Codex Lv 5 = de stats van het gevecht; vangen = Lv 5; kans 100%% ook bij volle HP",
			CD.stats_at("inktwurm", 5) == {"max_hp": iw["max_hp"], "max_mp": 0, "atk": iw["atk"], "def": iw["def"], "agi": iw["agi"]}
			and CD.capture_level(0, "inktwurm") == 5 and CD.capture_level(3, "inktwurm") == 5
			and CD.capture_chance("inktwurm", 68, 68) == 1.0 and CD.species_for_enemy("inktwurm") == "inktwurm")
	check("andere soorten: vangniveau = tier zoals altijd", CD.capture_level(3, "mosslijm") == 3 and CD.capture_level(0) == 1)
	check("Ink Worm zit in de fusietabel", CD.FUSION_TABLE.any(func(r): return (r["tags"] as Array).has("inkt")))
	# --- regels
	var mwp := pg("mech_wachter", 4, "t1")
	var iwp := pg("inktwurm", 8, "t2")
	var r := CD.make_fusion_page(mwp, iwp, "t3")
	check("tabel: Mech. Warden + Ink Worm = Lore Beast (archief + inkt)", r["species"] == "kennis_beest" and not r["fusion"]["glitch"]
			and r["fusion"]["rule"] == ["archief", "inkt"] and r["name"] == CD.species("kennis_beest")["name"])
	var r2 := CD.make_fusion_page(iwp, mwp, "t3")
	check("volgorde A/B maakt voor de soort niet uit", r2["species"] == r["species"] and r2["level"] == r["level"])
	check("level = (4 + 8) / 2 + 1 = 7", r["level"] == 7)
	var base := CD.stats_at("kennis_beest", 7)
	var ok_bonus := true
	for k in CD.PAGE_STATS:
		var v := int(base[k])
		var want := v + (maxi(1, ceili(v * 0.1)) if v > 0 else 0)
		if int(r[k]) != want:
			ok_bonus = false
	check("stats = soort op Lv 7 + 10%% (min +1) (HP %d -> %d)" % [base["max_hp"], r["max_hp"]], ok_bonus and r["hp"] == r["max_hp"])
	check("vaardigheden: Book Hammer, Lore Wave + erft de laatst geleerde van A (Shield Up) en B (Ink Spit) %s" % [r["skills"]],
			r["skills"] == ["boekenhamer", "kennisgolf", "schild_omhoog", "inktspuw"] and r["fusion"]["inherited"] == ["schild_omhoog", "inktspuw"])
	check("fusie-velden: generatie 1, ouders, soorten", r["fusion"]["generation"] == 1 and r["fusion"]["parents"] == ["t1", "t2"]
			and r["fusion"]["parent_species"] == ["mech_wachter", "inktwurm"] and CD.is_fused(r) and not CD.is_fused(mwp))
	var a := pg("inktwurm", 8, "g1")
	var b := pg("inktwurm", 10, "g2")
	var g := CD.make_fusion_page(a, b, "g3")
	check("geen tabelregel (2x Ink Worm): glitch-variant van A 'Glitch Worm', label glitch %s" % [g["fusion_tags"]],
			g["species"] == "inktwurm" and g["name"] == "Glitch Worm" and g["fusion"]["glitch"] and g["fusion_tags"].has("glitch")
			and g["element"] == "inkt" and g["level"] == 10)
	check("glitch-variant sterker dan een gewone van hetzelfde level (ATK %d > %d)" % [g["atk"], CD.stats_at("inktwurm", 10)["atk"]],
			int(g["atk"]) > int(CD.stats_at("inktwurm", 10)["atk"]) and int(g["max_hp"]) > int(CD.stats_at("inktwurm", 10)["max_hp"]))
	check("ouders met dezelfde vaardigheden: niets dubbel %s" % [g["skills"]], g["skills"] == ["inktspuw"])
	var g2 := CD.make_fusion_page(g, pg("glitchmot", 5, "g4"), "g5")
	check("inkt + ruis = Glitch Moth; generatie 2 (bonus 20%%)", g2["species"] == "glitchmot" and g2["fusion"]["generation"] == 2
			and int(g2["atk"]) == int(CD.stats_at("glitchmot", g2["level"])["atk"]) + maxi(1, ceili(CD.stats_at("glitchmot", g2["level"])["atk"] * 0.2)))
	var lv := CD.make_fusion_page(pg("mosslijm", 99, "x1"), pg("mosslijm", 99, "x2"), "x3")
	check("level nooit boven 99", lv["level"] == 99)
	check("zelfde pagina 2x: geen resultaat", CD.make_fusion_page(a, a, "z").is_empty() and CD.fusion_block_reason(a, a) != "")
	check("mos + wortel = Root Crawler (Moss Slime + Root Crawler)", CD.make_fusion_page(pg("mosslijm", 2, "m1"), pg("wortelkruiper", 2, "m2"), "m3")["species"] == "wortelkruiper")
	check("alle glitch-namen <= 13 tekens", CD.SPECIES.keys().all(func(id): return CD.glitch_name(id).length() <= CD.FUSION_NAME_MAX))


# ================================================================ deel B: GameState
func _state_tests() -> void:
	GameState.new_game("Kees")
	var p1 := GameState.codex_add("mech_wachter", 4)
	check("maar 1 pagina: kan niet ('%s')" % GameState.codex_fusion_reason(p1["uid"], p1["uid"]),
			GameState.codex_fusion_reason(p1["uid"], p1["uid"]) != "" and GameState.codex_fuse(p1["uid"], p1["uid"]).is_empty()
			and GameState.codex_pages.size() == 1)
	var p2 := GameState.codex_add("inktwurm", 8)
	check("zelfde pagina 2x: kan niet, niets veranderd", GameState.codex_fuse(p1["uid"], p1["uid"]).is_empty() and GameState.codex_pages.size() == 2)
	check("onbekende uid: kan niet", GameState.codex_fuse(p1["uid"], "codex_9999").is_empty() and GameState.codex_fuse("", p2["uid"]).is_empty()
			and GameState.codex_pages.size() == 2)
	var before := GameState.codex_save_data()
	var pv := GameState.codex_fusion_preview(p1["uid"], p2["uid"])
	check("voorbeeld: Lore Beast, geen uid, Codex onveranderd", pv["species"] == "kennis_beest" and pv["uid"] == ""
			and GameState.codex_save_data() == before)
	GameState.in_battle = true
	check("tijdens een gevecht: kan niet", GameState.codex_fuse(p1["uid"], p2["uid"]).is_empty() and GameState.codex_pages.size() == 2)
	GameState.in_battle = false
	check("bondgenoot = eerste pagina (A)", GameState.codex_active == p1["uid"])
	var r := GameState.codex_fuse(p1["uid"], p2["uid"])
	check("fusie: 1 pagina (nieuw, uid codex_0003), ouders weg", not r.is_empty() and GameState.codex_pages.size() == 1
			and r["uid"] == "codex_0003" and GameState.codex_page(p1["uid"]).is_empty() and GameState.codex_page(p2["uid"]).is_empty())
	check("A was bondgenoot -> de nieuwe is het", GameState.codex_active == r["uid"])
	check("resultaat = voorbeeld (behalve uid/caught)", r["species"] == pv["species"] and r["level"] == pv["level"] and r["atk"] == pv["atk"]
			and r["skills"] == pv["skills"] and r["caught"].get("fusie", false))
	check("nog een keer met dezelfde (verdwenen) ouders: niets (geen duplicaat)", GameState.codex_fuse(p1["uid"], p2["uid"]).is_empty()
			and GameState.codex_pages.size() == 1)
	# B is bondgenoot
	var q1 := GameState.codex_add("mosslijm", 3)
	var q2 := GameState.codex_add("moskonijn", 3)
	GameState.codex_set_active(q2["uid"])
	var r2 := GameState.codex_fuse(q1["uid"], q2["uid"])
	check("B was bondgenoot -> de nieuwe is het; komt op de plek van A", GameState.codex_active == r2["uid"]
			and str(GameState.codex_pages[1]["uid"]) == str(r2["uid"]))
	# geen van beide
	var q3 := GameState.codex_add("papiergeest", 2)
	var q4 := GameState.codex_add("glitchmot", 2)
	GameState.codex_set_active(r["uid"])
	var r3 := GameState.codex_fuse(q3["uid"], q4["uid"])
	check("geen ouder bondgenoot -> bondgenoot blijft (%s)" % GameState.codex_active, GameState.codex_active == r["uid"] and not r3.is_empty())
	var q5 := GameState.codex_add("mosslijm", 1)
	var q6 := GameState.codex_add("mosslijm", 1)
	GameState.codex_set_active("")
	GameState.codex_fuse(q5["uid"], q6["uid"])
	check("'Geen bondgenoot' blijft 'geen'", GameState.codex_active == "")
	# vol
	GameState.new_game("Kees")
	for i in CD.MAX_PAGES:
		GameState.codex_add("mosslijm", 1 + i)
	check("Codex vol (12): nog een vangen kan niet", GameState.codex_full() and GameState.codex_add("mosslijm").is_empty())
	var f := GameState.codex_fuse(GameState.codex_pages[0]["uid"], GameState.codex_pages[11]["uid"])
	check("Codex vol: fuseren kan wel -> 11 pagina's, daarna weer ruimte", not f.is_empty() and GameState.codex_pages.size() == 11
			and not GameState.codex_full() and not GameState.codex_add("mosslijm").is_empty())
	var ids := {}
	for p in GameState.codex_pages:
		ids[p["uid"]] = true
	check("alle uids uniek, nieuwe uid na de hoogste (%s)" % f["uid"], ids.size() == GameState.codex_pages.size() and f["uid"] == "codex_0013")


# ================================================================ deel C: save/load
func _save_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	var a := GameState.codex_add("inktwurm", 8)
	var b := GameState.codex_add("inktwurm", 9)
	GameState.codex_add("mosslijm", 2)
	var g := GameState.codex_fuse(a["uid"], b["uid"])
	g["hp"] = 7
	var p := player()
	check("opslaan", GameState.save_game(p.get_tile(), p.facing))
	GameState.new_game("Dennis")
	check("laden", GameState.load_game())
	var q := GameState.codex_page(g["uid"])
	check("na laden: Glitch Worm, generatie 1, label glitch, stats, HP 7, actief", not q.is_empty() and q["name"] == "Glitch Worm"
			and q["fusion"]["generation"] == 1 and q["fusion"]["glitch"] and (q["fusion_tags"] as Array).has("glitch")
			and q["atk"] == g["atk"] and q["max_hp"] == g["max_hp"] and q["hp"] == 7 and q["skills"] == g["skills"]
			and GameState.codex_active == g["uid"] and GameState.codex_pages.size() == 2)
	check("na laden: ouders blijven weg, nieuwe vangst krijgt een nieuwe uid", GameState.codex_page(a["uid"]).is_empty()
			and GameState.codex_add("glitchmot")["uid"] == "codex_0005")
	# geërfde vaardigheid blijft na laden (Mech. Wachter + Inktwurm)
	GameState.new_game("Dennis")
	var m := GameState.codex_add("mech_wachter", 3)
	var i := GameState.codex_add("inktwurm", 8)
	var kb := GameState.codex_fuse(m["uid"], i["uid"])
	GameState.save_game(p.get_tile(), p.facing)
	GameState.new_game("Dennis")
	GameState.load_game()
	var k2 := GameState.codex_page(kb["uid"])
	check("na laden: Lore Beast houdt geërfde Shield Up + Ink Spit %s" % [k2.get("skills")], not k2.is_empty()
			and (k2["skills"] as Array).has("schild_omhoog") and (k2["skills"] as Array).has("inktspuw") and k2["element"] == "kennis")
	# kapotte fusie-data
	var raw := GameState.read_save(GameState.save_path)
	raw["codex"]["pages"][0]["fusion"] = {"generation": "x", "parents": "kapot"}
	_write(GameState.save_path, raw)
	check("kapotte fusie-data: laadt, generatie 0, ouders []", GameState.load_game() and GameState.codex_pages[0]["fusion"]["generation"] == 0
			and GameState.codex_pages[0]["fusion"]["parents"] == [])
	raw["codex"]["pages"][0]["fusion"] = {"generation": 2, "parents": ["codex_0001", "codex_0002"]}
	raw["codex"]["pages"][0]["fusion_tags"] = ["boek", "glitch"]
	_write(GameState.save_path, raw)
	check("fusie-labels uit de save blijven bij een gefuseerde pagina", GameState.load_game()
			and GameState.codex_pages[0]["fusion_tags"] == ["boek", "glitch"])


# ================================================================ deel D: Codex-scherm
func _screen_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	var p1 := GameState.codex_add("mech_wachter", 4)
	var p2 := GameState.codex_add("inktwurm", 8)
	var p3 := GameState.codex_add("wortelkruiper", 12)
	GameState.codex_set_active(p2["uid"])
	await tap("menu")
	await frames(3)
	var m := field_menu()
	if m == null:
		check("veldmenu open", false)
		return
	m.choose("codex")
	await frames(3)
	var s: Node = m.get_node_or_null("Codex")
	check("Codex-scherm open, knop 'Fusie' zichtbaar, >= 16 hoog", s != null and s.fuse_button.visible and s.fuse_button.size.y >= 16)
	if s == null:
		return
	check("'Fusie'-knop past naast 'Terug' en de titel (geen overlap)", not s.fuse_button.get_global_rect().intersects(s.back_button.get_global_rect())
			and s.fuse_button.get_global_rect().end.x <= s.root.size.x and not s.header.get_global_rect().intersects(s.fuse_button.get_global_rect()))
	check("gewone lijst ongewijzigd: 3 pagina's + 'Geen'", s.entries.size() == 4 and s.entry_text(3).ends_with("No ally"))
	s.entries[1].grab_focus()
	await frames(2)
	await screenshot("inktwurm_codex")
	check("Ink Worm-pagina: plaatje (art of plaatsvervanger), Ink Spit", s.picture.texture != null and "Ink Spit" in s.skills_label.text)
	await tap("move_right")
	await frames(3)
	check("D-pad rechts: fusie stap 1 ('kies pagina 1'), geen 'Geen'-regel", s.mode == s.MODE_A and s.entries.size() == 3
			and "page 1" in s.header.text and not s.fuse_button.visible)
	await tap("cancel")
	await frames(3)
	check("B in stap 1: terug naar de Codex (scherm blijft open)", s.mode == "" and m.get_node_or_null("Codex") == s and s.entries.size() == 4)
	await click(s.fuse_button)
	await frames(2)
	check("tik op 'Fusie': stap 1", s.mode == s.MODE_A)
	await click(s.entries[0])
	check("pagina 1 = Mech. Warden -> stap 2", s.mode == s.MODE_B and s.pick_a == p1["uid"] and "page 2" in s.header.text)
	await click(s.entries[0])
	check("zelfde pagina nog eens: melding, blijft stap 2", s.mode == s.MODE_B and "different" in s.message_text())
	s.entries[1].grab_focus()
	await frames(2)
	await screenshot("fusie_kies2")
	await tap("interact")
	await frames(3)
	check("pagina 2 = Ink Worm -> voorbeeld", s.mode == s.MODE_PREVIEW and s.pick_b == p2["uid"])
	check("voorbeeld: Lore Beast Lv 7, paars, erft Shield Up + Ink Spit, Codex nog onveranderd",
			"Lore Beast" in s.name_label.text and "Lv 7" in s.name_label.text and s.picture.material != null
			and "Shield Up" in s.skills_label.text and "Ink Spit" in s.skills_label.text and GameState.codex_pages.size() == 3)
	check("voorbeeld: 'Fuseren!' + 'Annuleren', >= 16 hoog, focus op Fuseren", s.entries.size() == 2 and s.entries.all(func(e): return e.size.y >= 16)
			and s.entries[0].has_focus() and s.parents_label.visible)
	_layout_checks(s, "voorbeeld")
	await screenshot("fusie_voorbeeld")
	await tap("cancel")
	await frames(3)
	check("B in het voorbeeld: terug naar stap 2 (pagina 1 nog gekozen)", s.mode == s.MODE_B and s.pick_a == p1["uid"])
	await tap("interact")   # focus staat op pagina 2 (Inktwurm)
	await frames(3)
	check("weer voorbeeld", s.mode == s.MODE_PREVIEW)
	await tap("interact")
	await frames(4)
	var newp: Dictionary = GameState.codex_pages[0]
	check("Fuseren!: 2 pagina's, Lore Beast op plek 1, ouders weg, melding", s.mode == "" and GameState.codex_pages.size() == 2
			and newp["species"] == "kennis_beest" and GameState.codex_page(p1["uid"]).is_empty() and GameState.codex_page(p2["uid"]).is_empty()
			and "Fusion succeeded" in s.message_text())
	check("Ink Worm was bondgenoot -> Lore Beast is het; lijst '*' + focus op de nieuwe", GameState.codex_active == newp["uid"]
			and s.entry_text(0).begins_with("* Lore Beast") and s.entries[0].has_focus() and s.picture.material != null)
	s.confirm_fusion()      # nog eens bevestigen (dubbel tikken) mag niets doen
	await frames(2)
	check("nog eens 'Fuseren!' na de fusie: niets (Codex nog 2 pagina's, geen duplicaat)", GameState.codex_pages.size() == 2)
	_layout_checks(s, "resultaat")
	await get_tree().create_timer(0.4).timeout    # korte Crt-glitch van de fusie voorbij
	await screenshot("fusie_resultaat")
	# glitch-variant + lange naam in de lijst
	var w2 := GameState.codex_add("wortelkruiper", 12)
	var gz := GameState.codex_fuse(p3["uid"], w2["uid"])
	s.rebuild(gz["uid"])
	await frames(2)
	check("glitch-variant 'Root Glitch' (13 tekens) past in de lijst: '%s'" % s.entry_text(1), "Root Glitch" in s.entry_text(1) and "Lv13" in s.entry_text(1))
	var past := true
	for e in s.entries:
		var f: Font = e.get_theme_font("font")
		var w: float = f.get_string_size(e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, e.get_theme_font_size("font_size")).x
		if w > e.size.x or e.get_global_rect().end.x > s.name_label.get_global_rect().position.x:
			past = false
	check("alle regels passen in de lijst", past)
	await screenshot("fusie_codex")
	# maar 1 pagina: melding
	GameState.codex_reset()
	GameState.codex_add("mosslijm", 1)
	s.rebuild()
	await frames(2)
	await click(s.fuse_button)
	check("maar 1 pagina: 'Fusie' geeft een melding, geen stap 1", s.mode == "" and "two pages" in s.message_text())
	await tap("cancel")
	await frames(3)
	m.close()
	await pframes(4)


## Niets buiten 384x216; tekst niet over de hint; lijst niet over de details.
func _layout_checks(s: Node, what: String) -> void:
	# venster van het scherm (= 384x216 in het spel; headless kan het venster anders zijn)
	var screen := Rect2(Vector2.ZERO, s.root.size)
	print("INFO  schermmaat Codex: ", s.root.size)
	var bad := []
	for c in [s.name_label, s.stats_label, s.skills_label, s.state_label, s.picture, s.hint, s.fuse_button, s.back_button] + s.entries:
		if c.visible and not screen.encloses(c.get_global_rect()):
			bad.append("%s %s" % [c.name, c.get_global_rect()])
	check("%s: alles binnen het scherm (%s) %s" % [what, s.root.size, bad], bad.is_empty())
	var hint_top: float = s.hint.get_global_rect().position.y
	var lowest := 0.0
	for c in [s.state_label, s.skills_label, s.stats_label]:
		if c.visible and c.text != "":
			lowest = maxf(lowest, c.get_global_rect().end.y)
	check("%s: details eindigen boven de hint (%.0f <= %.0f)" % [what, lowest, hint_top], lowest <= hint_top + 0.5)
	var list_end := 0.0
	for e in s.entries:
		list_end = maxf(list_end, e.get_global_rect().end.x)
	check("%s: lijst niet over de details" % what, list_end <= s.name_label.get_global_rect().position.x)
	# tekst afgekapt? (labels zonder autowrap: tekst breder dan het label)
	var clip := []
	for l in [s.name_label, s.stats_label]:
		var f: Font = l.get_theme_font("font")
		for line in str(l.text).split("\n"):
			if f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x > l.size.x + 0.5:
				clip.append(line)
	if s.parents_label.visible:
		var f2: Font = s.parents_label.get_theme_font("font")
		for line in str(s.parents_label.text).split("\n"):
			if f2.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s.parents_label.get_theme_font_size("font_size")).x > s.parents_label.size.x + 0.5:
				clip.append(line)
	check("%s: geen tekst afgekapt %s" % [what, clip], clip.is_empty())


# ================================================================ deel E: gevecht
func _battle_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	var a := GameState.codex_add("inktwurm", 3)
	var b := GameState.codex_add("mosslijm", 3)
	var g := GameState.codex_fuse(a["uid"], b["uid"])
	check("Ink Worm + Moss Slime (geen regel) = Glitch Worm, bondgenoot", g["name"] == "Glitch Worm" and GameState.codex_active == g["uid"])
	var bt := await start_battle(["inktwurm", "papiergeest"])
	if bt == null:
		check("gevecht gestart", false)
		return
	await wait_battle_state(["command"])
	await pframes(10)
	var al := ally_c(bt)
	var node: Control = al.get("node")
	check("gefuseerde bondgenoot staat in het gevecht, paars (glitched)", not al.is_empty() and node != null and node.glitched
			and node._sprite.modulate != Color.WHITE)
	var e0: Dictionary = bt.enemies[0]
	var en: TextureButton = e0["node"]
	check("Ink Worm als vijand: naam, plaatje (%s), HP %d" % [GD.enemy_sprite(GD.ENEMIES["inktwurm"]), e0["s"]["max_hp"]],
			str(e0["name"]).begins_with("Ink Worm") and en.texture_normal != null and int(e0["s"]["max_hp"]) == int(GD.ENEMIES["inktwurm"]["max_hp"]))
	check("Ink Worm gezien in het bestiarium", GameState.is_seen("inktwurm"))
	await screenshot("inktwurm_gevecht")
	await screenshot("fusie_bondgenoot")
	await flee(bt)
	check("na het gevecht: pagina bestaat nog, nog steeds gefuseerd", CD.is_fused(GameState.codex_page(g["uid"])))
	check("gevlucht voor de Ink Worm: hij is er nog (uniek, niet verslagen)", GameState.unique_available("inktwurm"))


# ================================================================ deel F: Inktwurm (beslissing Dennis)
const INGANG := "res://scenes/maps/archief_ingang.tscn"
const UNIQUE_ROOM_MONSTER := {"id": "inktwurm", "enemy": "inktwurm", "group": ["inktwurm"], "tile": [13, 4], "moves": false}


## De kamer opnieuw laten spawnen met (alleen) een Inktwurm erin, zoals Forge hem in een kamer zet.
func respawn_with_unique(r: Node) -> int:
	for m in r.monsters:
		if is_instance_valid(m):
			m.queue_free()
	r.monsters.clear()
	r.room = r.room.duplicate(true)
	r.room["monsters"] = [UNIQUE_ROOM_MONSTER.duplicate(true)]
	r._spawn_monsters()
	await pframes(2)
	return r.monsters.filter(func(m): return is_instance_valid(m) and m.enemy_id == "inktwurm").size()


func _unique_tests() -> void:
	# --- groei 1,5x en vaardigheid pas op Lv 8 (data + EXP)
	var avg := CD.average_growth()
	var g: Dictionary = CD.species("inktwurm")["growth"]
	var ok_g := true
	for k in CD.PAGE_STATS:
		if not is_equal_approx(float(g.get(k, 0)), CD.UNIQUE_GROWTH_MULT * float(avg[k])):
			ok_g = false
	check("groei = 1,5 x gemiddelde Archief 1-groei %s -> %s" % [avg, g], ok_g)
	var lo := CD.stats_at("inktwurm", 5)
	var hi := CD.stats_at("inktwurm", 15)
	var ok_10 := true
	for k in CD.PAGE_STATS:
		if int(hi[k]) - int(lo[k]) != roundi(1.5 * float(avg[k]) * 10.0):
			ok_10 = false
	check("10 levels: groei 1,5x het gemiddelde (HP +%d i.p.v. +%d)" % [hi["max_hp"] - lo["max_hp"], roundi(avg["max_hp"] * 10.0)], ok_10)
	check("Lv 5-7: geen vaardigheid (alleen aanvallen); Lv 8: Ink Spit", CD.skills_at("inktwurm", 5).is_empty()
			and CD.skills_at("inktwurm", 7).is_empty() and CD.skills_at("inktwurm", 8) == ["inktspuw"])
	var page := CD.make_page("inktwurm", 5, "u1")
	var m7 := CD.give_exp(page, GD.exp_for_level(7) - int(page["exp"]))
	check("EXP tot Lv 7: nog geen vaardigheid %s" % [page["skills"]], page["level"] == 7 and (page["skills"] as Array).is_empty()
			and not m7.any(func(x): return "Ink Spit" in x))
	var m8 := CD.give_exp(page, GD.exp_for_level(8) - int(page["exp"]))
	check("Lv 8: 'leert Ink Spit!' en stats = stats_at(8) %s" % [m8], page["level"] == 8 and page["skills"] == ["inktspuw"]
			and m8.any(func(x): return "learns Ink Spit" in x) and page["atk"] == CD.stats_at("inktwurm", 8)["atk"]
			and page["max_hp"] == CD.stats_at("inktwurm", 8)["max_hp"])
	# --- uniek: API
	GameState.new_game("Dennis")
	check("nieuw spel: Ink Worm beschikbaar, gewone monsters altijd", GameState.unique_available("inktwurm") and GameState.is_unique("inktwurm")
			and GameState.unique_available("mosslijm") and not GameState.is_unique("mosslijm"))
	# --- vangen in het gevecht (in een kamer met tier: telt niet)
	setup()
	var room := await enter(INGANG, "ingang")
	if room == null:
		check("Archief-ingang geladen", false)
		return
	check("kamer met de Ink Worm (zoals Forge hem neerzet): hij verschijnt", await respawn_with_unique(room) == 1)
	var books := GameState.item_count(CD.BOOK_ITEM)
	var b := await start_battle(["inktwurm"], false, 3)
	if b == null:
		check("gevecht gestart", false)
		return
	var e: Dictionary = b.enemies[0]
	await wait_battle_state(["command"])
	var iw: Dictionary = GD.ENEMIES["inktwurm"]
	check("in een kamer met niveau 3: geen tier op de Ink Worm (HP %d, ATK %d), level 5" % [e["s"]["max_hp"], e["s"]["atk"]],
			int(e["s"]["max_hp"]) == int(iw["max_hp"]) and int(e["s"]["atk"]) == int(iw["atk"]) and int(e["s"]["level"]) == 5)
	b.codex.force_roll = 0.999        # 'slechtste' worp: met 100% toch raak
	check("Blank Book op de Ink Worm (volle HP)", int(e["s"]["hp"]) == int(e["s"]["max_hp"]) and await use_book(b, e))
	await wait_until(func(): return b.codex.last_capture.get("result", "") in ["gelukt", "mislukt"], 8.0)
	check("vangkans 100%% bij volle HP: gelukt (kans %.2f)" % float(b.codex.last_capture.get("chance", 0.0)),
			b.codex.last_capture.get("result") == "gelukt" and float(b.codex.last_capture["chance"]) == 1.0)
	check("boek wel gebruikt (%d -> %d)" % [books, GameState.item_count(CD.BOOK_ITEM)], GameState.item_count(CD.BOOK_ITEM) == books - 1)
	var pg5 := GameState.codex_page(str(b.codex.last_capture.get("page", "")))
	check("pagina: Ink Worm Lv 5, 2x-stats (HP %d ATK %d), nog geen vaardigheid" % [pg5.get("max_hp", 0), pg5.get("atk", 0)],
			not pg5.is_empty() and pg5["level"] == 5 and pg5["max_hp"] == iw["max_hp"] and pg5["atk"] == iw["atk"]
			and pg5["def"] == iw["def"] and pg5["agi"] == iw["agi"] and (pg5["skills"] as Array).is_empty())
	check("gevangen -> uniek weg ('gevangen')", GameState.unique_state("inktwurm") == "gevangen" and not GameState.unique_available("inktwurm"))
	await finish()
	await wait_scene_path(INGANG)
	room = scene()
	check("terug in de kamer: de Ink Worm verschijnt niet meer", room != null and await respawn_with_unique(room) == 0)
	var p := player()
	check("opslaan", GameState.save_game(p.get_tile(), p.facing))
	check("save bevat 'uniek': {inktwurm: gevangen}", GameState.read_save(GameState.save_path).get("uniek", {}) == {"inktwurm": "gevangen"})
	GameState.new_game("Dennis")
	check("nieuw spel: weer beschikbaar", GameState.unique_available("inktwurm"))
	check("laden: nooit meer (gevangen)", GameState.load_game() and not GameState.unique_available("inktwurm")
			and GameState.unique_state("inktwurm") == "gevangen")
	room = await enter(INGANG, "ingang")
	check("na laden: kamer zonder Ink Worm", room != null and await respawn_with_unique(room) == 0)
	# --- verslaan
	setup()
	room = await enter(INGANG, "ingang")
	b = await start_battle(["inktwurm"])
	await finish()
	check("verslagen -> uniek weg ('verslagen'), bestiarium 1x verslagen", GameState.unique_state("inktwurm") == "verslagen"
			and GameState.defeated_count("inktwurm") == 1 and not GameState.unique_available("inktwurm"))
	await wait_scene_path(INGANG)
	p = player()
	GameState.save_game(p.get_tile(), p.facing)
	var raw := GameState.read_save(GameState.save_path)
	GameState.new_game("Dennis")
	check("laden: verslagen blijft verslagen", GameState.load_game() and GameState.unique_state("inktwurm") == "verslagen")
	# oude save zonder 'uniek' / kapot
	raw.erase("uniek")
	_write(GameState.save_path, raw)
	check("oude save zonder 'uniek': Ink Worm beschikbaar", GameState.load_game() and GameState.unique_available("inktwurm"))
	raw["uniek"] = {"inktwurm": "gevangen", "mosslijm": "verslagen", "bestaat_niet": 1}
	_write(GameState.save_path, raw)
	check("save met onzin in 'uniek': alleen echte unieke monsters", GameState.load_game() and GameState.unique_done == {"inktwurm": "gevangen"}
			and GameState.unique_available("mosslijm"))
	GameState.unique_mark("inktwurm", "verslagen")
	check("eerste uitkomst telt (gevangen blijft gevangen)", GameState.unique_state("inktwurm") == "gevangen")
	# Checkpoint: verslagen overleeft game over; gevangen rolt mee met de Codex.
	GameState.new_game("Dennis")
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.unique_mark("inktwurm", "verslagen")
	GameState.respawn_at_checkpoint(false)
	check("game over: verslagen Ink Worm blijft weg", GameState.unique_state("inktwurm") == "verslagen"
			and not GameState.unique_available("inktwurm"))
	GameState.new_game("Dennis")
	GameState.set_checkpoint(INGANG, Vector2i(2, 2), Vector2i.DOWN)
	GameState.unique_mark("inktwurm", "gevangen")
	GameState.respawn_at_checkpoint(false)
	check("game over: gevangen rolt terug met het checkpoint", GameState.unique_available("inktwurm"))
	GameState.take_autosave_request()


# ================================================================ helpers
func part(k: String) -> bool:
	return only == "" or k in only


func scene() -> Node:
	return get_tree().current_scene


func player() -> CharacterBody2D:
	var s := scene()
	if s == null or not s.has_method("terrain_at") or not s.is_node_ready():
		return null
	return s.get_node_or_null("Objects/Player")


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func wait_until(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func wait_scene_path(path: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.scene_file_path == path and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_scene_named(n: String, timeout := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var s := scene()
		if s != null and s.name == n and s.is_node_ready() and not GameState.changing_map:
			await pframes(2)
			return true
		await get_tree().process_frame
	return false


func wait_fade() -> void:
	await wait_until(func(): return Transition._rect.color.a <= 0.01, 3.0)
	await pframes(2)


func tap(action: String) -> void:
	await get_tree().physics_frame
	Input.action_press(action)
	await pframes(2)
	Input.action_release(action)
	await pframes(2)


func press_interact() -> void:
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(2)


func close_dialog() -> void:
	for i in 30:
		if not Dialog.is_open:
			break
		await press_interact()
		await pframes(2)
	await pframes(2)


func enter(path: String, spawn: String) -> Node:
	GameState.has_return_point = false
	GameState.map_monster_battle = {}
	GameState.change_map(path, spawn)
	if not await wait_scene_path(path):
		return null
	await wait_fade()
	await wait_until(func(): return not Story.running, 5.0)
	await close_dialog()
	await pframes(6)
	var s := scene()
	if s != null and "monsters" in s:
		for m in s.monsters:
			if is_instance_valid(m):
				m.moves = false
	return s


func setup() -> void:
	GameState.new_game("Dennis")
	GameState.story_step = SD.NACHT
	GameState.encounter_multiplier = 0.0
	var h: Dictionary = GameState.party[0]
	GameState.give_exp(h, GD.exp_for_level(5))
	h["hp"] = h["max_hp"]
	GameState.pending_kern_absorb = ""
	GameState.inventory[CD.BOOK_ITEM] = 3      # v0.17: geen startvoorraad meer; zoals de 3 van Marit (Esdoorn)


func screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("INFO  geen screenshot mogelijk (headless?)")
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	var big := img.duplicate()
	big.resize(1152, 648, Image.INTERPOLATE_NEAREST)
	big.save_png(shots.path_join(name + "_3x.png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size(), " + _3x ", big.get_size())


func battle() -> Node:
	var s := scene()
	return s if s != null and s.name == "Battle" else null


func wait_battle_state(states: Array, timeout := 30.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		var b := battle()
		if b == null and Time.get_ticks_msec() - t0 > 500 and not GameState.in_battle:
			return ""
		if b != null and b.state in states:
			return b.state
		await get_tree().process_frame
	return ""


func cross_to(b: Node, index: int) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	for k in 4:
		if b.cross.selected == index:
			break
		if b.cross.selected != 0:
			await tap(CROSS_BACK[b.cross.selected])
		else:
			await tap(CROSS_DIRS[index])


func _watch(b: Node) -> void:
	var wb: WeakRef = weakref(b)
	var last := ""
	while wb.get_ref() != null:
		var bb: Node = wb.get_ref()
		var t: String = bb.message_label.text
		if t != last:
			last = t
			messages.append(t)
		await get_tree().process_frame


func seen_message(text_part: String) -> bool:
	return messages.any(func(m): return text_part in m)


func start_battle(enemies: Array, boss := false, tier := 0) -> Node:
	var p := player()
	GameState.start_battle(enemies, p.get_tile(), p.facing, "archief", boss, tier)
	if not await wait_scene_named("Battle"):
		return null
	var b := battle()
	messages.clear()
	_watch(b)
	return b


func ally_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c.get("ally", false):
			return c
	return {}


func hero_c(b: Node) -> Dictionary:
	for c in b.heroes:
		if c["s"].get("id", "") == GameState.MAIN_HERO:
			return c
	return {}


## Item > Leeg Boek > vijand 'e'.
func use_book(b: Node, e: Dictionary) -> bool:
	if await wait_battle_state(["command"]) != "command":
		return false
	await pframes(4)
	await cross_to(b, ITEM)
	await tap("interact")
	if not await wait_until(func(): return b.menu.visible, 3.0):
		return false
	var k: int = b._available_items().find(CD.BOOK_ITEM)
	if k < 0:
		return false
	b.menu.select(k)
	await pframes(2)
	await tap("interact")
	if await wait_battle_state(["target_enemy"], 5) != "target_enemy":
		return false
	for i in 6:
		if b.target_list[b.target_index] == e:
			break
		await tap("move_right")
	await tap("interact")
	return true


func defend(b: Node) -> void:
	if await wait_battle_state(["command"]) != "command":
		return
	await pframes(4)
	await cross_to(b, VERDEDIG)
	await tap("interact")


## Klik alle berichten weg tot het gevecht klaar is; 'on_page' wordt per overwinningspagina aangeroepen.
func finish(on_page := Callable()) -> void:
	for guard in 80:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "":
			break
		var b := battle()
		if st == "message_wait":
			if on_page.is_valid() and b.victory_panel.visible:
				await on_page.call(b)
			await tap("interact")
			continue
		for e in b.enemies:
			if int(e["s"]["hp"]) > 1:
				e["s"]["hp"] = 1
		await cross_to(b, 0)
		await tap("interact")
		if await wait_battle_state(["target_enemy", "busy", "message_wait"], 5) == "target_enemy":
			await tap("interact")
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


func flee(b: Node) -> void:
	var wb: WeakRef = weakref(b)
	for i in 8:
		if wb.get_ref() == null or battle() == null:
			break
		if await wait_battle_state(["command"], 30) != "command":
			break
		b.can_flee = true
		b.cross.enabled[4] = true
		await cross_to(b, 4)
		await tap("interact")
		await pframes(8)
		await wait_until(func(): return battle() == null or wb.get_ref() == null or (wb.get_ref() as Node).state == "command", 15.0)
	await wait_until(func(): return battle() == null and not GameState.in_battle, 15.0)
	await wait_fade()


func field_menu() -> Node:
	var s := scene()
	return s.get_node_or_null("FieldMenu") if s != null else null



func click(c: Control) -> void:
	await get_tree().physics_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = get_tree().root.get_final_transform() * c.get_global_rect().get_center()
	ev.global_position = ev.position
	ev.pressed = true
	Input.parse_input_event(ev)
	await pframes(2)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await pframes(3)



func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


# ================================================================ deel G: Codex-knop in het gevecht
## Naar de Codex-knop: via Vluchten (onder) en dan rechts.
func codex_to(b: Node) -> void:
	for i in 120:
		if b.cross.active:
			break
		await get_tree().process_frame
	await pframes(2)
	if b.cross.selected == CODEX:
		return
	await cross_to(b, 4)
	await tap("move_right")


## Codex-knop kiezen en wachten tot het submenu open is.
func open_codex(b: Node) -> bool:
	if await wait_battle_state(["command"], 30) != "command":
		return false
	await pframes(4)
	await codex_to(b)
	await tap("interact")
	return await wait_until(func(): return b.menu.visible and b.menu.title_label.text == "Codex", 3.0)


## Berichten wegklikken tot de held weer mag kiezen.
func next_turn(b: Node) -> bool:
	for guard in 40:
		var st := await wait_battle_state(["command", "message_wait"], 30)
		if st == "command":
			await pframes(4)
			if b.current_hero > 0 and b.cross.active:      # andere held: verdedigt
				await cross_to(b, VERDEDIG)
				await tap("interact")
				continue
			return true
		if st == "":
			return false
		await tap("interact")
	return false


func rows_ok(b: Node) -> bool:
	var n: int = b.menu._entries.size()
	for i in n:
		var rb: Button = b.menu.row_button(i)
		if rb.visible and rb.size.y < 16.0:
			return false
	return n > 0


## Binnen het gevechtsscherm (in gevechts-eenheden; in het spel 384x216) en boven de statusvakken.
func in_screen(b: Node, c: Control) -> bool:
	var inv: Transform2D = b.get_global_transform().affine_inverse()
	var r: Rect2 = inv * c.get_global_rect()
	var scr := Rect2(Vector2.ZERO, b.size)
	var ok := scr.grow(0.5).encloses(r)
	var boxes_top: float = b.size.y
	for box in b.status_boxes:
		boxes_top = minf(boxes_top, (inv * (box as Control).get_global_rect()).position.y)
	if c != b.cross.buttons[CODEX]:
		ok = ok and r.end.y <= boxes_top + 0.5
	if not ok:
		print("INFO  buiten beeld: %s %s (scherm %s, statusvakken vanaf y %.0f)" % [c.name, r, scr, boxes_top])
	return ok


func _codex_button_tests() -> void:
	setup()
	var room := await enter(GOLEM_SCENE, "zuid")
	if room == null:
		check("Golem Hall geladen", false)
		return
	# --- 1. geen pagina's en geen boeken: knop weg
	GameState.inventory[CD.BOOK_ITEM] = 0
	var bt := await start_battle(["mosslijm"])
	if bt == null or await wait_battle_state(["command"]) != "command":
		check("gevecht gestart", false)
		return
	await pframes(6)
	check("0 pagina's + 0 boeken: Codex-knop verborgen", not bt.cross.is_shown(CODEX) and not bt.cross.buttons[CODEX].visible)
	await cross_to(bt, 4)
	await tap("move_right")
	check("verborgen: rechts vanaf Vluchten gaat NIET naar Codex (sel %d)" % bt.cross.selected, bt.cross.selected != CODEX)
	await click(bt.cross.buttons[CODEX])
	check("verborgen: tik op die plek doet niets", bt.state == "command" and not bt.menu.visible)
	bt.tutorial = {"x": 1}
	GameState.inventory[CD.BOOK_ITEM] = 2
	check("oefengevecht: geen Codex-knop en niet wisselen (ook met boeken)", not bt.codex_command_shown() and not bt.codex.can_swap())
	bt.tutorial = {}
	check("met 1 Blank Book (0 pagina's) zou de knop er wel zijn", bt.codex_command_shown())
	GameState.inventory[CD.BOOK_ITEM] = 0
	await flee(bt)
	# --- 2. Codex met pagina's: knop, menu, vangen, wisselen
	var p1 := GameState.codex_add("mosslijm", 3)
	var p2 := GameState.codex_add("papiergeest", 3)
	var p3 := GameState.codex_add("moskonijn", 3)
	GameState.codex_page(p3["uid"])["hp"] = 0          # KO-pagina: niet in de wissel-lijst
	GameState.codex_set_active(p1["uid"])
	GameState.inventory[CD.BOOK_ITEM] = 2
	bt = await start_battle(["mosslijm", "papiergeest"])
	if bt == null or await wait_battle_state(["command"]) != "command":
		check("gevecht 2 gestart", false)
		return
	await pframes(6)
	for e in bt.enemies:
		e["s"]["atk"] = 0                              # niemand gaat KO tijdens de test
	bt.enemies[0]["s"]["hp"] = maxi(1, roundi(bt.enemies[0]["s"]["max_hp"] * 0.4))   # verschillende kansen
	bt.enemies[1]["s"]["hp"] = maxi(1, roundi(bt.enemies[1]["s"]["max_hp"] * 0.8))
	bt._refresh_party()
	var h := hero_c(bt)
	check("Codex-knop zichtbaar (pagina's + boeken), 24x24 (>= 16)", bt.cross.is_shown(CODEX) and bt.cross.buttons[CODEX].visible
			and bt.cross.buttons[CODEX].size == Vector2(24, 24))
	check("Codex-knop rechtsonder in het kruis, binnen 384x216", bt.cross.button_rect(CODEX).get_center().is_equal_approx(
			bt.cross.button_rect(0).get_center() + Vector2(25, 25)) and in_screen(bt, bt.cross.buttons[CODEX]))
	var overlap := false
	for i in 5:
		overlap = overlap or bt.cross.button_rect(i).intersects(bt.cross.button_rect(CODEX))
	check("Codex-knop overlapt geen andere knop", not overlap)
	await cross_to(bt, 4)
	await tap("move_right")
	var nav := [bt.cross.selected]
	await tap("move_up")
	nav.append(bt.cross.selected)
	await tap("move_down")
	nav.append(bt.cross.selected)
	await tap("move_right")
	await tap("move_left")
	nav.append(bt.cross.selected)
	check("D-pad: Vluchten >rechts> Codex, ^ Verdedig, Verdedig v Vluchten (oud pad), > Codex, < Vluchten: %s" % [nav],
			nav == [CODEX, 3, 4, 4])
	await tap("move_right")
	check("naam-tabje: '%s'" % bt.cross.name_label.text, bt.cross.name_label.text.ends_with("Codex"))
	await click(bt.cross.buttons[CODEX])
	var opened: bool = await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Codex", 3.0)
	check("tik op Codex opent het submenu 'Codex'", opened)
	var t0: String = bt.menu._entries[0]["text"]
	# v0.22 partylimiet: wisselen in het gevecht staat uit ('Swap: outside battle', grijs)
	check("submenu: Vangen (Boek x2) aan + Wissel grijs ('%s' / '%s')" % [t0, bt.menu._entries[1]["text"]], bt.menu._entries.size() == 2
			and "Book x2" in t0 and bt.menu._is_enabled(0) and not bt.menu._is_enabled(1)
			and str(bt.menu._entries[1]["text"]) == "Swap: outside battle")
	await pframes(4)
	check("submenu: regels >= 16 hoog (%.0f)" % bt.menu.row_button(0).size.y, rows_ok(bt))
	var cr: Rect2 = bt.cross.cross_rect()
	check("submenu binnen 384x216 en niet over het kruis", in_screen(bt, bt.menu)
			and not bt.menu.get_global_rect().intersects(Rect2(bt.cross.global_position + cr.position, cr.size)))
	await screenshot("codex_knop_menu")
	# Vangen: doel kiezen met kans per doel
	await tap("interact")
	check("Vangen -> doel kiezen", await wait_battle_state(["target_enemy"], 5) == "target_enemy")
	await pframes(3)
	var first: Dictionary = bt.target_list[bt.target_index]
	var hint: String = bt.codex.capture_hint(first)
	check("doel-label toont de vangkans ('%s')" % bt.target_name_label.text, bt.target_name_label.text == "%s %s (2 books)" % [first["name"], hint]
			and hint.ends_with("%"))
	check("doel-label toont ook het aantal Blank Books", "(2 books)" in bt.target_name_label.text)
	await screenshot("codex_knop_vangen")
	await tap("move_right")
	await pframes(2)
	var second: Dictionary = bt.target_list[bt.target_index]
	check("ander doel, eigen kans ('%s')" % bt.target_name_label.text, bt.target_name_label.text == "%s %s (2 books)" % [second["name"], bt.codex.capture_hint(second)]
			and bt.codex.capture_hint(second) != hint)
	await tap("cancel")
	check("B bij het doel: terug naar het Codex-submenu", await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Codex", 3.0))
	await tap("cancel")
	await pframes(3)
	check("B in het submenu: terug naar het kruis", bt.state == "command" and bt.cross.active and not bt.menu.visible)
	for e in bt.enemies:
		e["s"]["max_hp"] = 999                         # de bondgenoot verslaat ze niet tijdens de test
		e["s"]["hp"] = 999
	# echt vangen (vaste worp = raak), 1 boek weg
	bt.codex.force_roll = 0.0
	var pages_before := GameState.codex_pages.size()
	await codex_to(bt)
	await tap("interact")
	await wait_until(func(): return bt.menu.visible, 3.0)
	await tap("interact")
	await wait_battle_state(["target_enemy"], 5)
	var victim: Dictionary = bt.target_list[bt.target_index]
	await tap("interact")
	await next_turn(bt)
	check("Vangen via de Codex-knop: gelukt, 1 boek weg (%d), pagina erbij" % GameState.item_count(CD.BOOK_ITEM),
			bt.codex.last_capture.get("result", "") == "gelukt" and GameState.item_count(CD.BOOK_ITEM) == 1
			and GameState.codex_pages.size() == pages_before + 1 and bool(victim.get("captured", false)))
	bt.codex.force_roll = -1.0
	# v0.22 partylimiet: wisselen in het gevecht staat standaard uit (alleen via het menu)
	check("partylimiet: in het gevecht niet wisselen (standaard)", not bt.codex.can_swap())
	bt.codex.wissel_in_gevecht = true    # oud wissel-pad blijft gedekt
	# Wissel bondgenoot
	if not await open_codex(bt):
		check("Codex-submenu (beurt 2)", false)
		return
	await tap("move_down")
	await tap("interact")
	var wopen: bool = await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Swap", 3.0)
	var texts: Array = bt.menu._entries.map(func(e): return str(e["text"]))
	check("Wissel-lijst open: %s" % [texts], wopen)
	var names_ok: bool = texts.size() == 4 and texts[3] == "None" and not texts.any(func(t): return "Moss Rabbit" in t)
	check("alleen niet-KO pagina's + 'Geen' (Moss Rabbit KO ontbreekt)", names_ok)
	check("huidige bondgenoot staat grijs ('now'), 'None' aan", "now" in texts[0] and not bt.menu._is_enabled(0) and bt.menu._is_enabled(3))
	await pframes(3)
	check("wissel-lijst: regels >= 16, binnen beeld", rows_ok(bt) and in_screen(bt, bt.menu))
	check("wissel-lijst start op de eerste keuzemogelijkheid (Paper Wraith)", bt.menu.selected == 1)
	await screenshot("codex_knop_wissel")
	var enemy_hp: Array = bt.enemies.map(func(e): return int(e["s"]["hp"]))
	var old_ally := ally_c(bt)
	var old_node: Control = old_ally.get("node")
	old_ally["s"]["atk"] = 0
	messages.clear()
	await tap("interact")
	await next_turn(bt)
	var al := ally_c(bt)
	check("gewisseld: Paper Wraith vecht mee (%s), actief in de Codex" % str(al.get("name", "")), str(al.get("page", "")) == p2["uid"]
			and GameState.codex_active == p2["uid"] and bt.codex.last_swap.get("result", "") == "gewisseld")
	check("oude bondgenoot weg (node vrij), 1 bondgenoot, vakken = helden", not is_instance_valid(old_node)
			and bt.heroes.filter(func(c): return c.get("ally", false)).size() == 1 and bt.status_boxes.size() == bt.heroes.size()
			and bt.hero_nodes.size() == bt.heroes.size())
	check("wissel kost de beurt: %s viel niet aan (vijand-HP %s -> %s)" % [h["name"], enemy_hp, bt.enemies.map(func(e): return int(e["s"]["hp"]))],
			not seen_message("%s attacks" % h["name"]) and seen_message("leaps out of the Codex"))
	check("oude bondgenoot keert terug (bericht), pagina bewaard", seen_message("returns to the Codex") and not GameState.codex_page(p1["uid"]).is_empty())
	# 'Geen'
	if not await open_codex(bt):
		check("Codex-submenu (beurt 3)", false)
		return
	await tap("move_down")
	await tap("interact")
	await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Swap", 3.0)
	bt.menu.select(bt.menu._entries.size() - 1)
	await pframes(2)
	await tap("interact")
	await next_turn(bt)
	check("'Geen': geen bondgenoot meer, Codex zonder actieve pagina", ally_c(bt).is_empty() and GameState.codex_active == ""
			and bt.status_boxes.size() == bt.heroes.size())
	# volle Codex: scrollen + vangen geweigerd zonder boek te verliezen
	while not GameState.codex_full():
		GameState.codex_add("mosslijm", 2)
	if not await open_codex(bt):
		check("Codex-submenu (beurt 4)", false)
		return
	await tap("move_down")
	await tap("interact")
	await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Swap", 3.0)
	await pframes(3)
	var n: int = bt.menu._entries.size()
	var shown := 0
	for i in n:
		shown += 1 if bt.menu.row_button(i).visible else 0
	check("volle Codex: %d keuzes, %d tegelijk in beeld + scroll-pijlen, binnen beeld" % [n, shown],
			n == GameState.codex_pages.filter(func(p): return int(p["hp"]) > 0).size() + 1 and shown == bt.CODEX_ROWS_MAX and bt.menu._scroll_down != null and bt.menu._scroll_down.visible
			and bt.menu._scroll_up.disabled and in_screen(bt, bt.menu) and rows_ok(bt))
	for i in 7:
		await tap("move_down")
	check("D-pad omlaag scrolt mee (eerste regel %d, keuze %d zichtbaar)" % [bt.menu.first_row, bt.menu.selected],
			bt.menu.first_row > 0 and bt.menu.row_button(bt.menu.selected).visible)
	await click(bt.menu._scroll_up)
	check("tik op ▲ scrolt terug (eerste regel %d)" % bt.menu.first_row, bt.menu.first_row < 7 and bt.menu.row_button(bt.menu.selected).visible)
	await tap("cancel")
	await wait_until(func(): return bt.menu.visible and bt.menu.title_label.text == "Codex", 3.0)
	await tap("move_up")
	await tap("interact")
	await wait_battle_state(["target_enemy"], 5)
	await pframes(2)
	check("Codex vol: doel-label zegt het ('%s')" % bt.target_name_label.text, "Codex full (1 book)" in bt.target_name_label.text)
	await tap("interact")
	await next_turn(bt)
	check("Codex vol: geweigerd, boek blijft (%d)" % GameState.item_count(CD.BOOK_ITEM), bt.codex.last_capture.get("result", "") == "vol"
			and GameState.item_count(CD.BOOK_ITEM) == 1)
	# Item > Leeg Boek werkt nog (zelfde weigering, Codex vol)
	var ok := await use_book(bt, bt._alive(bt.enemies)[0])
	await next_turn(bt)
	check("Item > Blank Book werkt nog (zelfde regels: vol -> boek blijft)", ok and bt.codex.last_capture.get("result", "") == "vol"
			and GameState.item_count(CD.BOOK_ITEM) == 1)
	# 0 boeken: Vangen grijs met reden
	GameState.inventory[CD.BOOK_ITEM] = 0
	if not await open_codex(bt):
		check("Codex-submenu (0 boeken)", false)
		return
	var tv: String = bt.menu._entries[0]["text"]
	check("0 boeken: 'Capture' grijs met reden ('%s'), keuze staat op Swap" % tv, not bt.menu._is_enabled(0) and "no Blank Book" in tv
			and bt.menu.selected == 1)
	bt.menu.selected = 0
	await tap("interact")
	await pframes(3)
	check("A op grijs 'Vangen' doet niets", bt.menu.visible and bt.state == "command")
	await tap("cancel")
	await pframes(3)
	# weigeringen: baas / geen soort / Inktwurm 100%
	var fake := {"id": "mosslijm", "s": {"hp": 5, "max_hp": 10}, "core": true}
	check("label bij een baas: 'te machtig'", bt.codex.capture_hint(fake) == "too strong")
	GameState.codex_pages.pop_back()
	fake = {"id": "bestaat_niet", "s": {"hp": 5, "max_hp": 10}}
	check("label bij een niet-soort: 'past niet'", bt.codex.capture_hint(fake) == "won't fit")
	fake = {"id": "inktwurm", "s": {"hp": 136, "max_hp": 136}}
	check("label bij de Ink Worm (volle HP): 100%", bt.codex.capture_hint(fake) == "100%")
	var act_before := GameState.codex_active
	await flee(bt)
	check("na het gevecht: Codex-keuze blijft zoals in het gevecht ('%s')" % act_before, GameState.codex_active == act_before
			and not GameState.in_battle)
