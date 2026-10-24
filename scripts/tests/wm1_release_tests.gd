extends Node
## WM1-releasecuts (--wm1releasetest): content-lock-besluiten van Dennis (24 okt 2026).
##   H3   Training Hall, Workshop, Exchange en Core: deur dicht in WM1 (vlag ReleaseFlags.hub_cut), content blijft.
##   H2   hub-nissen codex_nis en sapientia_schot: deur dicht, ook als de act-vlag gezet is.
##   H1   dev-testkamers archief_test en kern_demo: geen route in een release-build (niet-debug).
##   H11  PvP- en Co-op-knop op het titelscherm: verborgen tot er een relay-URL is (vlag online_cut).
##   H13  De Koopman: geen Archive 4-lore meer in de bezoekregels.
## Start: godot --path . -- --wm1releasetest [--shots=/pad/map]

const Flags := preload("res://scripts/data/release_flags.gd")
const Kamers := preload("res://world_warper/kamers/kamers.gd")
const Rooms := preload("res://world_warper/data/rooms.gd")
const Koopman := preload("res://scripts/data/koopman_data.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const ATRIUM := "res://world_warper/kamers/hal.tscn"
const HUBHAL := "res://world_warper/maps/hal.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const DEV_ARCHIEF := "res://scenes/maps/archief_test.tscn"
const DEV_KERN := "res://scenes/maps/kern_demo.tscn"
const RELAY := "wss://relay.example.test/sapientia"

var failures := 0
var passes := 0
var shots := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	_run.call_deferred()


func check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if ok:
		passes += 1
	else:
		failures += 1


func _run() -> void:
	await _wacht(func() -> bool: return GameState._preloading.is_empty(), 15.0)
	_vlaggen_tests()
	_koopman_tests()
	_hub_data_tests()
	_dev_route_tests()
	await _hub_deuren_tests()
	await _nissen_tests()
	await _titel_tests()
	_herstel()
	print("WM1RELEASETEST %d PASS, %d FAIL" % [passes, failures])
	print("RESULT %s (%d goed, %d fouten)" % ["OK" if failures == 0 else "FOUT", passes, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)


## Zet alles terug op de WM1-standaard (de suite draait in één proces).
func _herstel() -> void:
	Flags.hub_cut = true
	Flags.online_cut = true
	Flags.debug_build_override = -1
	Flags.relay_url_override = null


func _wacht(cond: Callable, timeout := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout * 1000.0:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


func _screenshot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png(shots.path_join(name + ".png"))
	print("INFO  screenshot: ", shots.path_join(name + ".png"), " ", img.get_size())


func _pframes(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _scene_is(pad: String) -> bool:
	var nu := get_tree().current_scene
	return nu != null and nu.scene_file_path == pad and not GameState.changing_map


func _party(level: int) -> Array:
	return [{"name": "Dax", "level": level}]


func _sluit_dialoog() -> void:
	var n := 0
	while Dialog.is_open and n < 40:
		Dialog.cancel()
		n += 1


# ================================================================ vlaggen
func _vlaggen_tests() -> void:
	_herstel()
	check("standaard: hub_cut aan", Flags.hub_cut)
	check("standaard: online_cut aan", Flags.online_cut)
	check("de vier hubkamers staan in de lijst", Array(Flags.HUB_ROOMS_CUT) == ["trainingshal", "werkplaats", "handelskamer", "kern"])
	check("de twee nissen staan in de lijst", Array(Flags.HUB_NICHES_CUT) == ["codex_nis", "sapientia_schot"])
	check("de twee dev-kamers staan in de lijst", Array(Flags.DEV_SCENES) == [DEV_ARCHIEF, DEV_KERN])
	check("relay-URL leeg zonder instelling", Flags.relay_url() == "" or OS.get_environment(Flags.RELAY_ENV) != "")
	Flags.relay_url_override = "  " + RELAY + " "
	check("relay-override wordt getrimd", Flags.relay_url() == RELAY)
	Flags.relay_url_override = null
	_relay_instelling_tests()
	Flags.debug_build_override = 0
	check("override 0 = release-build", not Flags.is_debug_build())
	Flags.debug_build_override = 1
	check("override 1 = debug-build", Flags.is_debug_build())
	Flags.debug_build_override = -1
	check("zonder override = echte OS.is_debug_build()", Flags.is_debug_build() == OS.is_debug_build())


## Zelfde sleutel als de relay-PR (#204): [sapientia] net/relay_url + SAPIENTIA_RELAY_URL.
func _relay_instelling_tests() -> void:
	check("H11: relay-instelling heet sapientia/net/relay_url", Flags.RELAY_SETTING == "sapientia/net/relay_url")
	check("H11: relay-omgevingsvariabele heet SAPIENTIA_RELAY_URL", Flags.RELAY_ENV == "SAPIENTIA_RELAY_URL")
	var had_nieuw := ProjectSettings.has_setting(Flags.RELAY_SETTING)
	var oud_nieuw: Variant = ProjectSettings.get_setting(Flags.RELAY_SETTING, "")
	var had_oud := ProjectSettings.has_setting("sapientia/online/relay_url")
	ProjectSettings.set_setting(Flags.RELAY_SETTING, "")
	if OS.get_environment(Flags.RELAY_ENV).strip_edges() == "":
		check("H11: lege instelling en geen env -> geen relay, knoppen verborgen", Flags.relay_url() == ""
				and not Flags.online_buttons_visible())
	ProjectSettings.set_setting(Flags.RELAY_SETTING, " " + RELAY + " ")
	check("H11: sapientia/net/relay_url wordt gelezen (getrimd)", Flags.relay_url() == RELAY)
	check("H11: ingestelde relay-URL maakt de online-knoppen zichtbaar", Flags.online_buttons_visible())
	ProjectSettings.set_setting(Flags.RELAY_SETTING, "")
	if not had_oud and OS.get_environment(Flags.RELAY_ENV).strip_edges() == "":
		ProjectSettings.set_setting("sapientia/online/relay_url", RELAY)
		check("H11: de oude sleutel sapientia/online/relay_url telt niet meer", Flags.relay_url() == "")
		ProjectSettings.set_setting("sapientia/online/relay_url", null)
	if had_nieuw:
		ProjectSettings.set_setting(Flags.RELAY_SETTING, oud_nieuw)
	else:
		ProjectSettings.set_setting(Flags.RELAY_SETTING, null)


# ================================================================ H13
func _koopman_tests() -> void:
	var alle := ""
	for fase in Koopman.REGELS:
		alle += "\n".join(Koopman.REGELS[fase]) + "\n"
	check("H13: nergens 'Archive 4' in de Koopman-regels", not alle.contains("Archive 4") and not alle.contains("Archief 4"))
	check("H13: de regel 'I came out of there too' is weg", not alle.contains("came out of there"))
	for bezoek in [4, 5, 7]:
		var tekst := "\n".join(Koopman.gesprek(bezoek, false))
		check("H13: bezoek %d (fragmenten) zonder Archive 4" % bezoek, not tekst.contains("Archive"))
		check("H13: bezoek %d noemt wel nog de Cave" % bezoek, tekst.contains("The Cave is not a dungeon"))
	check("H13: bezoek 4 begint nog steeds bij de hanger", Koopman.gesprek(4, false)[0].begins_with("You again. No... wait. That pendant."))
	check("H13: fase 2 heeft 3 regels + vertrek", Koopman.gesprek(4, false).size() == 3 + 1)
	check("H13: fase 1 onveranderd (3 regels + vertrek)", Koopman.gesprek(1, false).size() == 3 + 1)
	check("H13: fase 3 geeft nog de token", "\n".join(Koopman.gesprek(8, false)).contains("Received H-5's Token"))
	check("H13: fragment- en waarheiddrempels onveranderd", Koopman.FRAGMENT_VANAF == 4 and Koopman.WAARHEID_VANAF == 8)
	var teksten := PackedStringArray()
	for fase in Koopman.REGELS:
		for r in Koopman.REGELS[fase]:
			teksten.append(str(r))
	check("H13: 3 + 3 + 4 regels over de drie fases", teksten.size() == 3 + 3 + 4)


# ================================================================ H3 data
func _hub_data_tests() -> void:
	_herstel()
	var open := {Kamers.FLAG_HUB: true}
	for id in ["trainingshal", "werkplaats", "handelskamer", "kern"]:
		check("H3: %s dicht (release_open) op level 40" % id, not Kamers.release_open(id, open, _party(40)))
		check("H3: %s blijft op level wel 'is_open' (data intact)" % id, Kamers.is_open(id, open, _party(40)))
		check("H3: %s scene en naam bestaan nog" % id, ResourceLoader.exists(Kamers.scene_path(id)) and Kamers.naam(id) != "")
	for id in ["hal", "rustkamer", "echo_kamer"]:
		check("H3: %s blijft open in act 1" % id, Kamers.release_open(id, open, _party(1)))
	check("H3: Screening Room blijft open op Lv 14", Kamers.release_open("beeldkamer", open, _party(14)))
	check("H3: Screening Room nog dicht op Lv 13", not Kamers.release_open("beeldkamer", open, _party(13)))
	check("H3: hub dicht zonder vlag blijft dicht", not Kamers.release_open("rustkamer", {}, _party(40)))
	Flags.hub_cut = false
	for id in ["trainingshal", "werkplaats", "handelskamer", "kern"]:
		check("H3: vlag uit -> %s weer open op level" % id, Kamers.release_open(id, open, _party(40)))
	check("H3: vlag uit -> level-grens geldt weer (Training Hall dicht op Lv 19)", not Kamers.release_open("trainingshal", open, _party(19)))
	_herstel()
	check("H3: Workshop-recepten en Exchange-winkel bestaan nog", Kamers.RECEPTEN.size() >= 3 and Kamers.handel_open())
	# H2 data
	for id in ["codex_nis", "sapientia_schot"]:
		check("H2: %s in de data nog aanwezig" % id, Rooms.ROOMS.has(id) and ResourceLoader.exists(Rooms.scene_path(id)))
		check("H2: %s is gesneden" % id, Flags.hub_niche_cut(id))
	check("H2: andere hubkaarten niet gesneden", not Flags.hub_niche_cut("hal") and not Flags.hub_niche_cut("hanger_nis")
			and not Flags.hub_niche_cut("exterieur") and not Flags.hub_niche_cut("warp_ring"))
	Flags.hub_cut = false
	check("H2: vlag uit -> nissen niet meer gesneden", not Flags.hub_niche_cut("codex_nis") and not Flags.hub_niche_cut("sapientia_schot"))
	_herstel()


# ================================================================ H1
func _dev_route_tests() -> void:
	_herstel()
	Flags.debug_build_override = 0
	check("H1: release: archief_test geblokkeerd", Flags.dev_scene_blocked(DEV_ARCHIEF))
	check("H1: release: kern_demo geblokkeerd", Flags.dev_scene_blocked(DEV_KERN))
	check("H1: release: gewone kaarten niet geblokkeerd", not Flags.dev_scene_blocked(WERELD) and not Flags.dev_scene_blocked(HUBHAL)
			and not Flags.dev_scene_blocked("res://scenes/maps/archief_ingang.tscn"))
	check("H1: release: F4-route niet toegestaan", not Flags.dev_rooms_allowed())
	Flags.debug_build_override = 1
	check("H1: debug: archief_test en kern_demo bereikbaar", not Flags.dev_scene_blocked(DEV_ARCHIEF) and not Flags.dev_scene_blocked(DEV_KERN))
	check("H1: debug: F4-route toegestaan", Flags.dev_rooms_allowed())
	_herstel()
	check("H1: de kamers zelf blijven in de repo (tests gebruiken ze)", ResourceLoader.exists(DEV_ARCHIEF) and ResourceLoader.exists(DEV_KERN))
	check("H1: geen scène in de speelroute verwijst naar een dev-kamer", _geen_deur_naar_dev())


## Alle map-scènes (behalve de dev-kamers zelf): staat er een dev-pad als doel in? Tekstscan van de .tscn.
func _geen_deur_naar_dev() -> bool:
	var gevonden: Array[String] = []
	for map in ["res://scenes/maps", "res://world_warper/maps", "res://world_warper/kamers"]:
		var dir := DirAccess.open(map)
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".tscn") or Flags.DEV_SCENES.has(map + "/" + f):
				continue
			var tekst := FileAccess.get_file_as_string(map + "/" + f)
			for dev in Flags.DEV_SCENES:
				if tekst.contains(dev):
					gevonden.append(map + "/" + f)
	if not gevonden.is_empty():
		print("INFO  scènes met dev-doel: %s" % [gevonden])
	return gevonden.is_empty()


# ================================================================ H3 deuren (echte scène)
func _laad_kaart(pad: String, spawn: String) -> Node:
	GameState.change_map(pad, spawn)
	if not await _wacht(func() -> bool: return _scene_is(pad), 8.0):
		return null
	await _pframes(4)
	return get_tree().current_scene


func _deur(sc: Node, room_id: String) -> Node:
	for d in sc.get_node("Exits").get_children():
		if str(d.get("room_id")) == room_id:
			return d
	return null


func _stap(deur: Node) -> void:
	deur._on_player_stepped(Vector2i((deur.position / 16.0).floor()))
	await _pframes(2)


func _hub_deuren_tests() -> void:
	_herstel()
	GameState.new_game("Dax")
	GameState.party[0]["level"] = 40
	GameState.story_flags[Kamers.FLAG_HUB] = true
	for f in ["ww_canon_genezer_gezien", "ww_canon_hanger_gezien", "ww_canon_dreiging_gezien"]:
		GameState.story_flags[f] = true
	var sc := await _laad_kaart(ATRIUM, "ingang")
	check("H3: The Atrium laadt", sc != null)
	if sc == null:
		return
	for id in ["trainingshal", "werkplaats", "handelskamer", "kern"]:
		var d := _deur(sc, id)
		check("H3: deur naar %s bestaat in de Hal" % id, d != null)
		if d == null:
			continue
		_sluit_dialoog()
		await _stap(d)
		check("H3: %s dicht op Lv 40: melding 'still closed', geen kaartwissel" % id,
				Dialog.is_open and not GameState.changing_map and _scene_is(ATRIUM))
		_sluit_dialoog()
		await _pframes(2)
	# Vlag uit: de Training Hall gaat weer open (de content is niet weg).
	GameState.party[0]["level"] = 40
	Flags.hub_cut = false
	var tr := _deur(sc, "trainingshal")
	await _stap(tr)
	var kwam := await _wacht(func() -> bool: return _scene_is(Kamers.scene_path("trainingshal")), 8.0)
	check("H3: vlag uit -> Training Hall opent weer en laadt", kwam)
	_herstel()
	await _sluit_en_terug()


func _sluit_en_terug() -> void:
	_sluit_dialoog()
	var sc := await _laad_kaart(ATRIUM, "ingang")
	if sc == null:
		return
	GameState.party[0]["level"] = 1
	var rust := _deur(sc, "rustkamer")
	check("H3: deur naar de Rest Room bestaat", rust != null)
	if rust == null:
		return
	_sluit_dialoog()
	await _stap(rust)
	var kwam := await _wacht(func() -> bool: return _scene_is(Kamers.scene_path("rustkamer")), 8.0)
	check("H3: Rest Room opent nog gewoon op Lv 1 (niet gesneden)", kwam)


# ================================================================ H2 nissen (echte scène)
func _nissen_tests() -> void:
	_herstel()
	GameState.story_flags[Kamers.FLAG_HUB] = true
	GameState.story_flags[Rooms.FLAG_ACT2] = true
	GameState.story_flags[Rooms.FLAG_ACT3] = true
	var sc := await _laad_kaart(HUBHAL, "ingang")
	check("H2: hub-hal laadt", sc != null)
	if sc == null:
		return
	for id in ["codex_nis", "sapientia_schot"]:
		var d := _deur(sc, id)
		check("H2: deur naar %s bestaat" % id, d != null)
		if d == null:
			continue
		check("H2: %s zou zonder cut open zijn (vlag gezet)" % id, Rooms.is_open(id, GameState.story_flags))
		_sluit_dialoog()
		await _stap(d)
		check("H2: %s blijft dicht ondanks act-vlag: melding, geen kaartwissel" % id,
				Dialog.is_open and not GameState.changing_map and _scene_is(HUBHAL))
		_sluit_dialoog()
		await _pframes(2)
	Flags.hub_cut = false
	var codex := _deur(sc, "codex_nis")
	await _stap(codex)
	var kwam := await _wacht(func() -> bool: return _scene_is(Rooms.scene_path("codex_nis")), 8.0)
	check("H2: vlag uit + act-vlag -> nis opent weer", kwam)
	_herstel()
	GameState.story_flags.erase(Rooms.FLAG_ACT2)
	GameState.story_flags.erase(Rooms.FLAG_ACT3)
	# Release-build + change_map: dev-kamer wordt niet geladen, de huidige kaart blijft staan.
	var huidig := get_tree().current_scene.scene_file_path
	Flags.debug_build_override = 0
	GameState.change_map(DEV_ARCHIEF, "ingang")
	await _pframes(10)
	check("H1: release: change_map naar archief_test wordt genegeerd", not GameState.changing_map
			and get_tree().current_scene.scene_file_path == huidig)
	GameState.change_map(DEV_KERN, "ingang")
	await _pframes(10)
	check("H1: release: change_map naar kern_demo wordt genegeerd", not GameState.changing_map
			and get_tree().current_scene.scene_file_path == huidig)
	_herstel()


# ================================================================ H11 titelscherm
func _titel() -> Node:
	var nu := get_tree().current_scene
	return nu if nu != null and nu.get("pvp_button") != null else null


func _titel_tests() -> void:
	_herstel()
	GameState.go_to_title()
	await _wacht(func() -> bool: return _titel() != null and not GameState.changing_map, 10.0)
	await _pframes(10)
	var t := _titel()
	check("H11: titelscherm geladen", t != null)
	if t == null:
		return
	Flags.relay_url_override = ""
	t.apply_online_visibility()
	await _pframes(3)
	await _screenshot("titel_zonder_online")
	check("H11: geen relay-URL -> PvP verborgen", not t.pvp_button.visible and t.pvp_button.disabled)
	check("H11: geen relay-URL -> Co-op verborgen", not t.coop_button.visible and t.coop_button.disabled)
	check("H11: verborgen knoppen nemen geen focus", t.pvp_button.focus_mode == Control.FOCUS_NONE
			and t.coop_button.focus_mode == Control.FOCUS_NONE)
	check("H11: de andere knoppen blijven zichtbaar", t.continue_button.visible and t.new_button.visible
			and t.som_button.visible and t.beta_button.visible and t.eind_button.visible)
	check("H11: knoppen blijven als node bestaan (terugzetten kan)", t.get_node_or_null("PvpButton") != null
			and t.get_node_or_null("CoopButton") != null)
	check("H11: focus van New Game wijst niet naar een verborgen knop", not str(t.new_button.focus_neighbor_top).ends_with("PvpButton"))
	Flags.relay_url_override = RELAY
	t.apply_online_visibility()
	await _pframes(3)
	await _screenshot("titel_met_relay")
	check("H11: relay-URL ingesteld -> PvP zichtbaar en bruikbaar", t.pvp_button.visible and not t.pvp_button.disabled
			and t.pvp_button.focus_mode == Control.FOCUS_ALL)
	check("H11: relay-URL ingesteld -> Co-op zichtbaar en bruikbaar", t.coop_button.visible and not t.coop_button.disabled
			and t.coop_button.focus_mode == Control.FOCUS_ALL)
	check("H11: focus van New Game wijst weer naar PvP", str(t.new_button.focus_neighbor_top).ends_with("PvpButton"))
	Flags.relay_url_override = ""
	Flags.online_cut = false
	t.apply_online_visibility()
	check("H11: vlag uit -> knoppen weer zichtbaar zonder relay", t.pvp_button.visible and t.coop_button.visible)
	Flags.online_cut = true
	t.apply_online_visibility()
	check("H11: vlag weer aan -> verborgen", not t.pvp_button.visible and not t.coop_button.visible)
	_herstel()
	await _pframes(2)
