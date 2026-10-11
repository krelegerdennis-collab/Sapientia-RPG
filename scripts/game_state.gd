extends Node
## Autoload "GameState": alles wat moet blijven bestaan tussen scènes:
## party (HP/MP/level/EXP), inventaris, goud, op welke map de speler is,
## en waar hij stond voordat een gevecht begon. Data komt uit scripts/data/game_data.gd.

const GameData := preload("res://scripts/data/game_data.gd")
## v0.14 (menu L2): uitrusting en effectieve stats (basis + uitrusting).
const Equipment := preload("res://scripts/equipment.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")   # Kernfragment stap 2: de Codex
const Dungeon100RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")   # 100-verdiepingen-kerker
## Hier begint een nieuw spel (v0.11: wakker worden in bed, in het huis).
const START_MAP := "res://scenes/maps/huis_wilgendal.tscn"
const START_SPAWN := "bed"
## Terugval bij GAME OVER als er (nog) geen kamer-checkpoint is (v0.19: zie 'checkpoint'): voor het huis.
const RESPAWN_MAP := "res://scenes/maps/wilgendal.tscn"
const RESPAWN_SPAWN := "start"
const TOWN_MAP := "res://scenes/maps/wilgendal.tscn"
const WORLD_MAP := "res://scenes/maps/wereldkaart.tscn"
const StoryData := preload("res://scripts/data/story_data.gd")
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const NAME_SCENE := "res://scenes/ui/name_entry.tscn"
const HOUSE_MAP := "res://scenes/maps/huis_wilgendal.tscn"
## v0.10: naam van de hoofdpersoon (uit het naamscherm); leeg = DEFAULT_NAME.
const DEFAULT_NAME := "Dennis"
const NAME_MAX := 10
## Held-id van de hoofdpersoon (v0.11: id 'dennis', sprites assets/sprites/battle/dennis*.png).
const MAIN_HERO := "dennis"
## v0.11 veldmenu (oude id -> dennis): HERO_ID = de enige plek met de id-tekst voor nieuwe
## code; HERO_ID_LEGACY = oude id in saves van voor v0.11. Laden zet die om (resolve_hero_id).
const HERO_ID := MAIN_HERO
const HERO_ID_LEGACY := "ruben"
const HERO_ID_ALIASES := {HERO_ID_LEGACY: HERO_ID, HERO_ID: HERO_ID_LEGACY}
## Opslag: één slot. De autotest gebruikt een eigen bestand (raakt je echte save niet).
const SAVE_VERSION := 1
var save_path := "user://save_1.json"
## v0.11 Automatisch opslaan: een EIGEN bestand (overschrijft de handmatige save nooit).
## Wordt geschreven na een mapwissel, na een gewonnen gevecht en als de app naar de
## achtergrond gaat (Android). Nooit tijdens een gevecht, een mapwissel of een tekstvak.
## Uit te zetten in Opties ('Autom. opslaan', autoload Settings).
const AUTOSAVE_PATH := "user://autosave.json"
var autosave_path := AUTOSAVE_PATH
## Betatest: een eigen voortgang, los van Nieuw spel en Doorgaan. Zo kun je nieuwe
## content proberen zonder telkens in bed te beginnen, en zonder je echte spel te wissen.
## De paden worden gezet in _ready (tests krijgen een eigen voorvoegsel).
var _story_save_path := ""
var _story_autosave_path := ""
var playing_beta := false
## Start van een nieuw betatest-account: wereldkaart bij Wilgendal (spawn van_dorp).
const BETA_SPAWN := "van_dorp"
const BETA_TILE := Vector2i(14, 31)
const BETA_FACING := Vector2i(0, 1)
const BETA_LEVEL := 10
const BETA_FLAGS: Array[String] = ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien",
		"noor_ontmoet", "quest_noor", "marit_boeken"]
## Waarom de volgende map moet autosaven ("map", "battle" of "" = niet). map.gd vraagt
## dit op (take_autosave_request) en slaat op zodra de map in beeld is.
var _autosave_request := ""
## Voor de autotest/info: laatste reden en aantal keer automatisch opgeslagen.
var last_autosave_reason := ""
var autosave_count := 0

var player_name := DEFAULT_NAME
## Speeltijd in seconden: opgeteld bij laden + tijd sinds _clock_start.
var _play_time_base := 0.0
var _clock_start_ms := 0
## Bestiarium: vijand-id -> {"seen": bool, "defeated": int}
var bestiary := {}
## Puzzels: kamer-id -> Array van poort-ids die voor altijd open zijn (latch). Gaat mee in de save.
var puzzle_latched := {}
## v0.15 KERNFRAGMENTEN (scripts/data/kern_data.gd): id -> {"bron": baas-id, "stap": 1}. Gaat mee
## in de save ("kernen"). Eenmalig per fragment (grant_kern). Latere stappen (archiveren, fusie)
## kunnen per fragment eigen velden toevoegen.
var kernfragmenten := {}
## v0.15: net geabsorbeerde kern; map.gd speelt dan het absorptie-moment af (niet in de save).
var pending_kern_absorb := ""
## Codex (Kernfragment stap 2): ingeschreven monsters (pagina's, zie codex_data.gd), de uid van
## de actieve bondgenoot ("" = geen) en de teller voor unieke ids (nooit hergebruikt).
## codex_changed: de actieve bondgenoot (of de lijst) is veranderd. De volger op de kaart luistert.
signal codex_changed
var codex_pages: Array = []
var codex_active := ""
var codex_next_id := 1
## v0.19 UNIEKE monsters (GameData.ENEMIES "unique": true, bv. de Inktwurm; beslissing Dennis): id ->
## "verslagen" / "gevangen". Staat erin = komt nooit meer terug. In de save als "uniek".
var unique_done := {}

## 100-verdiepingen-kerker (de Diepe Grot): alles gaat mee in de save, blok "dungeon100"
## (Dungeon100Rules.save_data/load_data). Zie HANDOFF_DUNGEON100*.md.
## huidige verdieping 1..100, 0 = niet in de kerker
var dungeon100_floor: int = 0
## run-seed van de generator (0 = nog niet gekozen; de eerste keer binnenkomen kiest hem)
var dungeon100_seed: int = 0
## laatst geactiveerd rustpunt (0, 10, ... 100) en hoogste bereikte verdieping
var dungeon100_checkpoint := 0
var dungeon100_best := 0
## HET GESIMULEERDE ARCHIEF (Blauwe Kisten, zie HANDOFF_DUNGEON100_BLUECHEST.md):
## PERMANENTE items uit Blauwe Kisten (id -> aantal): overleven de dood en elke nieuwe run.
var dungeon100_permanent := {}
## hoeveel van elk permanent item al in de echte tas is gelegd (door een geslaagde Warp)
var dungeon100_delivered := {}
## Momentopname van de echte party/tas/goud/Codex tijdens een run ({} = geen run bezig). Tijdens een run
## zijn party/inventory/gold/codex_pages die van de SIMULATIE (level 1, geen uitrusting).
var dungeon100_snapshot := {}
## v0.11 verhaal: stap (zie scripts/data/story_data.gd) en flags (naam -> true)
var story_step := 0
var story_flags := {}
## v0.11: opties voor het volgende gevecht als het een oefengevecht is ({} = gewoon)
var pending_tutorial := {}

var party: Array = []          # Array van Dictionaries (kopie van GameData.HEROES)
var inventory := {}            # item-id -> aantal
var gold := 0

## Vermenigvuldiger voor alle encounter-kansen (1.0 = normaal, 0 = uit).
## Handig om te testen; de kansen zelf staan per terrein in game_data.gd.
var encounter_multiplier := 1.0
var steps_until_encounter_possible: int = GameData.SAFE_STEPS

## Huidige map (pad naar de .tscn) en het spawnpunt voor de volgende map.
var current_map := ""
var pending_spawn := ""
var changing_map := false

## Positie op de map waar het gevecht begon (om daarna terug te keren).
var has_return_point := false
var return_map := ""
var return_tile := Vector2i.ZERO
var return_facing := Vector2i.DOWN
## Gevechtsachtergrond voor het volgende gevecht (pad naar een plaatje).
var pending_backdrop := ""
## v0.10: id van die achtergrond ("grass", "sand", "boss", "library") en of het een baas is.
var pending_backdrop_id := ""
var pending_boss := false
## v0.14: monsterniveau (tier) voor het volgende gevecht: 0 = gewoon (wereldkaart), 1-4 = de
## verdieping van het Eerste Archief (game_data.gd TIERS). Alleen gezet door een dungeonkamer.
var pending_tier := 0

## De vijandgroep voor het volgende gevecht (Array van vijand-id's).
var pending_enemies: Array = []
## Alleen voor testen: als dit niet leeg is, wordt deze groep altijd gekozen.
var debug_force_group: Array = []
## Laatste gevechtsuitslag: "win", "flee" of "lose".
var last_battle_result := ""

var in_battle := false

## v0.13 map-monsters (dungeons, scripts/dungeon/): het gevecht dat een map-monster startte
## ({} = geen; {"map", "room", "id", "positions"}) en per kamer de verslagen monsters
## ({room_id: {monster_id: true}}). Alleen deze sessie, niet in de save: kom je de kamer
## opnieuw binnen (of laad je), dan zijn ze er weer.
var map_monster_battle := {}
var defeated_map_monsters := {}

## v0.19 KAMER-CHECKPOINT (wens Dennis: 'spawnpoint moet altijd voor de laatste room zijn').
## Bij ELKE binnenkomst van een map/kamer (deur, uitgang, laden; niet terug uit een gevecht) legt
## map.gd hier vast WAAR je binnenkwam (tile + kijkrichting) plus een kopie van de voortgang op dat
## moment ("state" = zelfde velden als een save). GAME OVER (overal: kamer, dorp, wereldkaart, baas)
## = terug naar dat punt met die voortgang, iedereen vol HP/MP. Een BAASKAMER zet hem niet (map.gd
## allows_checkpoint; dungeon_room.gd: kamers met een "boss"-monster of "checkpoint": false), dus wie
## bij de baas sneuvelt, ontwaakt in de kamer ervoor. Gaat mee in de save ("checkpoint").
## {} = nog geen (dan de oude regel: Wilgendal, helft van het goud kwijt).
var checkpoint := {}
## Hoe de volgende map binnenkomt: "door" (uitgang/mapwissel), "battle" (terug na winst/vlucht),
## "respawn" (na game over), "load" (save geladen) of "" (onbekend, bv. direct een scène geladen).
## map.gd leest en wist dit in _ready.
var entry_kind := ""
## Na een respawn: dit bericht (verteller) toont de map zodra hij in beeld is ("" = niets).
var pending_respawn_msg: Array = []
## Voor de tests/info: de laatste respawn ({"map", "tile", "facing", "boss"}).
var last_respawn := {}
# TODO(verhaal): definitieve tekst van het ontwaken (nu placeholder).
const RESPAWN_LINES_BOSS := ["You wake before the door...", "You are fully rested again."]
const RESPAWN_LINES := ["You wake where you came in...", "You are fully rested again."]
## Het Gesimuleerde Archief: nederlaag in de kerker (gevechtsscherm) en het bericht na het opnieuw laden.
const DUNGEON100_DEFEAT_TEXT := "GAME OVER\nDeath means out of the Archive. You stand before the entrance again."
const DUNGEON100_RESET_LINES := ["The simulation lets you go.", "You stand before the Archive entrance again. Blue databanks remain."]

## v7 (prestaties): alles wat een gevecht of mapwissel nodig heeft wordt bij de start
## alvast op de achtergrond geladen (ResourceLoader.load_threaded_request) en daarna
## vastgehouden. Zo hoeft er bij een encounter niets meer van 'schijf' te komen: dat
## was een bron van korte haperingen op de telefoon.
var _preloading: Array[String] = []
var _loaded := {}              # pad -> Resource (blijft in het geheugen)


## v0.13: het gedeelde thema (assets/theme.tres) met het palet uit scripts/ui/ui_style.gd.
## We houden een verwijzing vast, zodat elke scène precies deze (aangepaste) versie krijgt.
var ui_theme: Theme


func _ready() -> void:
	ui_theme = load("res://assets/theme.tres")
	preload("res://scripts/ui/ui_style.gd").apply_to_theme(ui_theme)
	_ensure_input_actions()
	new_game()
	_start_preload()
	add_child.call_deferred(preload("res://scripts/ui/dungeon100_hud.gd").new())   # 'Verdieping X/100' (alleen in de kerker)
	# Alleen voor testen: start met  godot -- --autotest  (zie scripts/debug_autotest.gd).
	# De tester hangt aan de root, zodat hij blijft bestaan als de scène wisselt.
	# (In de Android-export zit de tester niet: daarom eerst kijken of hij bestaat.)
	# v0.11: of  godot -- --menutest  (alleen het veldmenu, scripts/debug_menutest.gd).
	# v0.12: of  godot -- --puzzletest [--shots=/pad/map]  (scripts/tests/puzzle_tests.gd).
	# v0.13: of  godot -- --dungeontest [--shots=/pad/map]  (scripts/tests/dungeon_tests.gd).
	# v0.14: of  godot -- --golemtest [--shots=/pad/map]  (scripts/tests/golem_tests.gd, Golem-baas).
	# v0.15: of  godot -- --archieftest [--shots=/pad/map]  (scripts/tests/archief_tests.gd, geheime deur + kist).
	# v0.15: of  godot -- --kerntest [--shots=/pad/map]  (scripts/tests/kern_tests.gd, kernfragmenten).
	# v0.16: of  godot -- --kernkrachttest [--shots=/pad/map]  (scripts/tests/kernkracht_tests.gd, vuurbal).
	# v0.17: of  godot -- --woudtest [--shots=/pad/map]  (scripts/tests/woud_tests.gd, Esdoorn + Donker Woud + Noor).
	# Dungeon100: of  godot -- --dungeon100gentest [--shots=/pad/map]  (scripts/tests/dungeon100_generator_tests.gd).
	# Dungeon100: of  godot -- --dungeon100schaaltest [--shots=/pad/map]  (scripts/tests/dungeon100_schaal_tests.gd).
	# Dungeon100: of  godot -- --dungeon100regelstest [--shots=/pad/map]  (scripts/tests/dungeon100_tests.gd).
	# Dungeon100: of  godot -- --dungeon100integratietest [--shots=/pad/map]  (scripts/tests/dungeon100_integratie_tests.gd).
	# Dungeon100: of  godot -- --dungeon100blauwtest [--shots=/pad/map]  (scripts/tests/dungeon100_blauw_tests.gd).
	# Codex: of  godot -- --codextest [--shots=/pad/map]  (scripts/tests/codex_tests.gd).
	# v0.19: of  godot -- --fusietest [--shots=/pad/map]  (scripts/tests/fusie_tests.gd, glitch-fusie + Inktwurm).
	# v0.19: of  godot -- --checkpointtest [--shots=/pad/map] [--v19=/workspace]  (kamer-checkpoint / respawn).
	# Sfx per held/monster: of  godot -- --actorsfxtest  (scripts/tests/actor_sfx_tests.gd).
	# Geen van de testers zit in de export, dus in de APK onbereikbaar.
	var args := OS.get_cmdline_user_args()
	for t in [["--autotest", "res://scripts/debug_autotest.gd", "AutoTest", "autotest"],
			["--menutest", "res://scripts/debug_menutest.gd", "MenuTest", "autotest"],
			["--puzzletest", "res://scripts/tests/puzzle_tests.gd", "PuzzleTest", "puzzletest"],
			["--dungeontest", "res://scripts/tests/dungeon_tests.gd", "DungeonTest", "dungeontest"],
			["--golemtest", "res://scripts/tests/golem_tests.gd", "GolemTest", "golemtest"],
			["--archieftest", "res://scripts/tests/archief_tests.gd", "GeheimTest", "archieftest"],
			["--kerntest", "res://scripts/tests/kern_tests.gd", "KernTest", "kerntest"],
			["--kernkrachttest", "res://scripts/tests/kernkracht_tests.gd", "KernkrachtTest", "kernkrachttest"],
			["--woudtest", "res://scripts/tests/woud_tests.gd", "WoudTest", "woudtest"],
			["--codextest", "res://scripts/tests/codex_tests.gd", "CodexTest", "codextest"],
			["--fusietest", "res://scripts/tests/fusie_tests.gd", "FusieTest", "fusietest"],
			["--checkpointtest", "res://scripts/tests/checkpoint_tests.gd", "CheckpointTest", "checkpointtest"],
			["--dungeon100gentest", "res://scripts/tests/dungeon100_generator_tests.gd", "Dungeon100GenTest", "dungeon100gentest"],
			["--dungeon100schaaltest", "res://scripts/tests/dungeon100_schaal_tests.gd", "Dungeon100SchaalTest", "dungeon100schaaltest"],
			["--dungeon100regelstest", "res://scripts/tests/dungeon100_tests.gd", "Dungeon100RegelsTest", "dungeon100regelstest"],
			["--dungeon100integratietest", "res://scripts/tests/dungeon100_integratie_tests.gd", "Dungeon100IntegratieTest", "dungeon100integratietest"],
			["--dungeon100blauwtest", "res://scripts/tests/dungeon100_blauw_tests.gd", "Dungeon100BlauwTest", "dungeon100blauwtest"],
			["--actorsfxtest", "res://scripts/tests/actor_sfx_tests.gd", "ActorSfxTest", "actorsfxtest"]]:
		if not (t[0] in args) or not ResourceLoader.exists(t[1]):
			continue
		# eigen bestanden: de tests raken je echte save/autosave niet
		save_path = "user://%s_save_1.json" % t[3]
		autosave_path = "user://%s_autosave.json" % t[3]
		for p in [save_path, autosave_path]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		var tester: Node = load(t[1]).new()
		tester.name = t[2]
		get_tree().root.add_child.call_deferred(tester)
		break
	_story_save_path = save_path
	_story_autosave_path = autosave_path


## Extra input-acties uit code (zodat project.godot niet hoeft te veranderen):
## "menu" = veldmenu openen (Esc / M / Tab, of de MENU-knop op het touchscherm)
## "debug_boss" = F3: baasgevecht (alleen in debug-builds).
## "debug_puzzle" = F4: TIJDELIJK, naar de puzzel-testkamer. Alleen in debug-builds: in een
## release-build (APK) bestaat de actie niet en kijkt map.gd ook nog naar OS.is_debug_build().
func _ensure_input_actions() -> void:
	var keys := {"menu": [KEY_ESCAPE, KEY_M, KEY_TAB], "debug_boss": [KEY_F3]}
	if OS.is_debug_build():
		keys["debug_puzzle"] = [KEY_F4]
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in keys[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)


func _preload_paths() -> Array[String]:
	var out: Array[String] = [BATTLE_SCENE, START_MAP, TOWN_MAP, "res://scenes/maps/wereldkaart.tscn"]
	for p in GameData.BACKDROPS.values():
		out.append(str(p))
	for h in GameData.HEROES:
		out.append(str(h["battle_sprite"]))
	for e in GameData.ENEMIES.values():
		out.append(GameData.enemy_sprite(e))
	return out


## Scripts die de autoloads (Dialog, GameState, Transition) bij naam gebruiken: eerst
## gewoon (op de hoofdthread) laden. Anders compileert Godot ze in de laad-thread en
## klaagt hij "Caller thread can't call this function" (sinds v0.10 start het spel in
## het titelscherm, dus de maps worden pas in de achtergrond geladen).
const MAIN_THREAD_SCRIPTS := ["res://scripts/map.gd", "res://scripts/player.gd", "res://scripts/npc.gd",
	"res://scripts/sign.gd", "res://scripts/door.gd", "res://scripts/book_point.gd",
	"res://scripts/map_exit.gd", "res://scripts/map_spawn.gd", "res://scripts/touch_controls.gd",
	"res://scripts/battle/battle.gd", "res://scripts/story_object.gd"]


func _start_preload() -> void:
	for sp in MAIN_THREAD_SCRIPTS:
		if ResourceLoader.exists(sp):
			load(sp)
	for p in _preload_paths():
		if _preloading.has(p) or _loaded.has(p) or not ResourceLoader.exists(p):
			continue
		if ResourceLoader.load_threaded_request(p) == OK:
			_preloading.append(p)
	set_process(not _preloading.is_empty())


## Kijkt elk frame (alleen zolang er nog iets laadt) of er iets klaar is.
func _process(_delta: float) -> void:
	for i in range(_preloading.size() - 1, -1, -1):
		var p := _preloading[i]
		var status := ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[p] = ResourceLoader.load_threaded_get(p)
			_preloading.remove_at(i)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_preloading.remove_at(i)
	if _preloading.is_empty():
		set_process(false)


## Geeft een (voor)geladen resource; wacht zo nodig tot het laden klaar is.
func get_resource(path: String) -> Resource:
	if _loaded.has(path):
		return _loaded[path]
	var res: Resource = null
	if _preloading.has(path):
		res = ResourceLoader.load_threaded_get(path)   # wacht tot hij klaar is
		_preloading.erase(path)
	if res == null:
		res = load(path)
	if res != null:
		_loaded[path] = res
	return res


func _go_to_scene(path: String) -> void:
	var packed := get_resource(path) as PackedScene
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)


## Nieuw spel (v0.10): de party is alleen de hoofdpersoon (held 'dennis') met
## de gekozen naam. Noor en Lotte komen later via add_member("noor") / add_member("lotte").
func new_game(hero_name := DEFAULT_NAME) -> void:
	player_name = clean_name(hero_name)
	party.clear()
	add_member(MAIN_HERO)
	inventory = GameData.START_INVENTORY.duplicate(true)
	map_monster_battle = {}
	defeated_map_monsters = {}
	gold = GameData.START_GOLD
	steps_until_encounter_possible = GameData.SAFE_STEPS
	bestiary.clear()
	puzzle_latched.clear()
	kernfragmenten = {}
	pending_kern_absorb = ""
	codex_reset()
	unique_done = {}
	checkpoint = {}
	entry_kind = ""
	pending_respawn_msg = []
	last_respawn = {}
	story_step = StoryData.START
	story_flags = {}
	pending_tutorial = {}
	dungeon100_load({})
	if has_node("/root/Story"):
		get_node("/root/Story").reset()
	has_return_point = false
	pending_spawn = ""
	_play_time_base = 0.0
	_clock_start_ms = Time.get_ticks_msec()


## Naam opschonen: spaties eraf, max. NAME_MAX tekens, leeg = DEFAULT_NAME.
func clean_name(n: String) -> String:
	n = n.strip_edges().left(NAME_MAX)
	return n if n != "" else DEFAULT_NAME


static func hero_exists(id: String) -> bool:
	return GameData.HEROES.any(func(h): return h["id"] == id)


## v0.11: held-id uit een save -> id die in de huidige data bestaat (HERO_ID_LEGACY <-> HERO_ID).
static func resolve_hero_id(id: String) -> String:
	if hero_exists(id):
		return id
	var alias := str(HERO_ID_ALIASES.get(id, ""))
	return alias if alias != "" and hero_exists(alias) else id


## v0.14: de held zoals in GameData.HEROES (niet kopiëren/aanpassen), {} = bestaat niet.
static func _hero_data(id: String) -> Dictionary:
	for hero in GameData.HEROES:
		if hero["id"] == id:
			return hero
	return {}


## Kopie van een held uit GameData.HEROES (volle HP/MP); {} als het id niet bestaat.
func hero_template(id: String) -> Dictionary:
	for hero in GameData.HEROES:
		if hero["id"] == id:
			var h: Dictionary = hero.duplicate(true)
			h["hp"] = h["max_hp"]
			h["mp"] = h["max_mp"]
			if id == MAIN_HERO:
				h["name"] = player_name
			Equipment.init_hero(h)     # v0.14: basis-stats + lege uitrustingsvakken
			return h
	return {}


## Held bij de party voegen (bv. als Noor zich later aansluit). false = bestaat niet of
## zit er al in.
func add_member(id: String) -> bool:
	if has_member(id):
		return false
	var h := hero_template(id)
	if h.is_empty():
		return false
	party.append(h)
	return true


## v0.17 Held sluit zich aan (story-commando "join", bv. Noor na het Donker Woud): op niveau
## 'level' (EXP via give_exp, dus dezelfde groei als normaal), volle HP/MP, en de stukken in 'gear'
## gegeven en meteen gedragen. false = bestaat niet of zit er al in.
func join_member(id: String, level := 1, gear: Array = []) -> bool:
	if not add_member(id):
		return false
	var h: Dictionary = party[party.size() - 1]
	if level > int(h["level"]):
		give_exp(h, GameData.exp_for_level(level) - int(h["exp"]))
	for g in gear:
		var gid := str(g)
		var slot := Equipment.slot_of(gid)
		if slot == "":
			continue
		inventory[gid] = item_count(gid) + 1
		Equipment.equip(h, inventory, slot, gid)
	h["hp"] = h["max_hp"]
	h["mp"] = h["max_mp"]
	return true


## v0.17 Niveau van een held in de party (0 = zit er niet in).
func member_level(id: String) -> int:
	for h in party:
		if h.get("id", "") == id:
			return int(h.get("level", 1))
	return 0


func has_member(id: String) -> bool:
	return party.any(func(h): return h.get("id", "") == id)


## v0.11: wapen geven en meteen dragen (v0.14: via de uitrusting, game_data.gd EQUIPMENT);
## de bonus telt meteen mee. Een wapen dat hij al droeg gaat terug in de tas.
func equip_weapon(hero_id: String, weapon_id: String) -> bool:
	if Equipment.slot_of(weapon_id) != "wapen":
		return false
	for h in party:
		if h.get("id", "") == hero_id:
			return Equipment.give_and_equip(h, inventory, weapon_id)
	return false


func weapon_name(h: Dictionary) -> String:
	return Equipment.item_name(Equipment.equipped(h, "wapen"))


## ===== v0.14 EFFECTIEVE STATS (voor Forge / het gevecht) =====
## Effectieve waarde van een stat = basis + alle uitrusting (scripts/equipment.gd,
## effective_stats). Voor atk/def/mag/mdef/agi; andere sleutels (max_hp, ...) = de waarde
## in de held. h["atk"], h["def"], h["agi"], h["mag"], h["mdef"] zijn altijd al gelijk aan
## deze waarde (Equipment.refresh), dus battle.gd hoeft niets te veranderen; nieuwe code
## (bv. spreukschade met mag/mdef) kan het best deze getter gebruiken.
func effective_stat(hero: Dictionary, stat: String) -> int:
	return Equipment.effective_stat(hero, stat)


## Alle uitrustingsstats tegelijk: {"atk", "def", "mag", "mdef", "agi"}.
func effective_stats(hero: Dictionary) -> Dictionary:
	return Equipment.effective_stats(hero)


## Naam van de hoofdpersoon wijzigen (ook in de party).
func set_player_name(n: String) -> void:
	player_name = clean_name(n)
	for h in party:
		if h.get("id", "") == MAIN_HERO:
			h["name"] = player_name


func play_time() -> float:
	return _play_time_base + (Time.get_ticks_msec() - _clock_start_ms) / 1000.0


# ---------------------------------------------------------------- bestiarium
func _beast(id: String) -> Dictionary:
	if not bestiary.has(id):
		bestiary[id] = {"seen": false, "defeated": 0}
	return bestiary[id]


func mark_seen(id: String) -> void:
	if GameData.ENEMIES.has(id):
		_beast(id)["seen"] = true


func mark_defeated(id: String) -> void:
	unique_mark(id, "verslagen")      # v0.19: uniek monster verslagen = nooit meer
	if GameData.ENEMIES.has(id):
		var b := _beast(id)
		b["seen"] = true
		b["defeated"] = int(b["defeated"]) + 1


func is_seen(id: String) -> bool:
	return bool(bestiary.get(id, {}).get("seen", false))


func defeated_count(id: String) -> int:
	return int(bestiary.get(id, {}).get("defeated", 0))


# ---------------------------------------------------------------- opslaan / laden
## Is er een HANDMATIGE save (opslagboek of veldmenu)?
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## v0.11: is er een automatische save?
func has_autosave() -> bool:
	return FileAccess.file_exists(autosave_path)


## v0.11: handmatige save óf autosave aanwezig (titelscherm: 'Doorgaan' aan).
func has_any_save() -> bool:
	return has_save() or has_autosave()


## v0.11: pad van de NIEUWSTE save (handmatig of automatisch), "" = geen.
## Vergelijkt "saved_unix" in het bestand (oudere saves zonder dat veld: de
## wijzigingstijd van het bestand). Even oud = de handmatige save.
func newest_save_path() -> String:
	return _newest_of(save_path, autosave_path)


func _newest_of(manual: String, auto: String) -> String:
	var has_manual := FileAccess.file_exists(manual)
	var has_auto := FileAccess.file_exists(auto)
	if not has_auto:
		return manual if has_manual else ""
	if not has_manual:
		return auto
	return auto if _save_stamp(auto) > _save_stamp(manual) else manual


func beta_save_path() -> String:
	return _story_save_path.replace("save_1.json", "save_beta.json")


func beta_autosave_path() -> String:
	return _story_autosave_path.replace("autosave.json", "autosave_beta.json")


func use_story_saves() -> void:
	save_path = _story_save_path
	autosave_path = _story_autosave_path
	playing_beta = false


func use_beta_saves() -> void:
	save_path = beta_save_path()
	autosave_path = beta_autosave_path()
	playing_beta = true


func has_beta_save() -> bool:
	return FileAccess.file_exists(beta_save_path()) or FileAccess.file_exists(beta_autosave_path())


func newest_beta_path() -> String:
	return _newest_of(beta_save_path(), beta_autosave_path())


func read_beta_save() -> Dictionary:
	var p := newest_beta_path()
	return read_save(p) if p != "" else {}


func _save_stamp(path: String) -> float:
	var d := read_save(path)
	if d.has("saved_unix"):
		return float(d["saved_unix"])
	return float(FileAccess.get_modified_time(path))


## v0.11: inhoud van de nieuwste save ({} = geen), bv. voor het titelscherm.
func read_newest_save() -> Dictionary:
	var p := newest_save_path()
	return read_save(p) if p != "" else {}


## v0.11 Automatisch opslaan in autosave_path. Doet niets (false) als het uit staat in
## Opties of als het nu niet veilig kan (gevecht, mapwissel, tekstvak open).
func autosave(tile: Vector2i, facing: Vector2i, reason := "") -> bool:
	if not can_autosave():
		return false
	if not save_game(tile, facing, autosave_path):
		return false
	last_autosave_reason = reason
	autosave_count += 1
	return true


func can_autosave() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and not settings.autosave_enabled():
		return false
	var dialog := get_node_or_null("/root/Dialog")
	if dialog != null and dialog.is_open:
		return false
	# v0.11: ook niet midden in een cutscene (autoload Story, als die er is)
	var story := get_node_or_null("/root/Story")
	if story != null and story.get("running") == true:
		return false
	return not in_battle and not changing_map


## map.gd: moet deze map na binnenkomst automatisch opslaan? (en wis het verzoek)
func take_autosave_request() -> String:
	var r := _autosave_request
	_autosave_request = ""
	return r


## v0.11 App naar de achtergrond (Android: PAUSED; op telefoons ook FOCUS_OUT):
## automatisch opslaan via de huidige map (die weet waar de speler staat).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		autosave_on_background()


func autosave_on_background() -> bool:
	var s := get_tree().current_scene if is_inside_tree() else null
	if s != null and s.has_method("try_autosave"):
		return s.try_autosave("achtergrond")
	return false


## Schrijft de voortgang naar save_path (JSON), of naar 'path' (v0.11: de autosave).
## Geeft true als het gelukt is.
func save_game(tile: Vector2i, facing: Vector2i, path := "") -> bool:
	if path == "":
		path = save_path
	var data := state_data(tile, facing)
	data["game_version"] = str(ProjectSettings.get_setting("application/config/version", ""))
	data["saved_at"] = Time.get_datetime_string_from_system()
	data["saved_unix"] = Time.get_unix_time_from_system()
	data["autosave"] = path == autosave_path
	# v0.19 kamer-checkpoint (met zijn eigen voortgangs-kopie) gaat mee; altijd de sleutel
	# ({} = nog geen), zodat handmatige save en autosave hetzelfde formaat houden
	data["checkpoint"] = checkpoint.duplicate(true)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Opslaan mislukt: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


## De party als lijst van Dictionaries voor een save (en de Archief-momentopname).
func _party_save() -> Array:
	var out := []
	for h in party:
		var e := {}
		for k in ["id", "name", "level", "exp", "hp", "mp", "max_hp", "max_mp", "atk", "def", "agi", "spells", "weapon"]:
			e[k] = h.get(k)
		# v0.14: magie-stats (effectief), basis-stats en uitrusting (zie Equipment.save_fields)
		e["mag"] = h.get("mag")
		e["mdef"] = h.get("mdef")
		e.merge(Equipment.save_fields(h), true)
		out.append(e)
	return out


## Party uit save-data terug (kapotte velden krijgen de standaardwaarde); uitrusting die niet meer past
## komt in 'stray_equipment'.
func _party_from(raw: Array, stray_equipment: Array) -> Array:
	var out := []
	for e in raw:
		if not (e is Dictionary):
			continue
		var h := hero_template(resolve_hero_id(hero_id_compat(str(e.get("id", "")))))
		if h.is_empty():
			continue
		for k in e:
			if k in ["id", "spells", "base", "equip", "weapon"] or e[k] == null:
				continue
			var v = e[k]
			if h.has(k) and h[k] is int and not (v is float or v is int):
				continue      # kapot getal: standaardwaarde van de held houden
			h[k] = int(v) if v is float else v
		if e.has("spells") and e["spells"] is Array:
			h["spells"] = e["spells"].duplicate()
		# v0.14 uitrusting + basis-stats; oude saves zonder die sleutels krijgen
		# standaardwaarden (zie Equipment.load_hero). Ongeldige stukken -> terug in de tas.
		Equipment.load_hero(h, e, _hero_data(str(h["id"])), stray_equipment)
		out.append(h)
	return out


## Tas uit save-data: id -> aantal (kapotte waarden vallen weg).
static func _inventory_from(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if raw[k] is float or raw[k] is int:
				out[k] = int(raw[k])
	return out


## v0.19: de voortgang als Dictionary (zelfde velden als een save, zonder checkpoint/tijdstempels).
## Gebruikt door save_game en door het kamer-checkpoint (set_checkpoint).
func state_data(tile: Vector2i, facing: Vector2i, map := "") -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"map": map if map != "" else current_map,
		"tile": [tile.x, tile.y],
		"facing": [facing.x, facing.y],
		"player_name": player_name,
		"party": [],
		"inventory": inventory.duplicate(true),
		"gold": gold,
		"play_time": play_time(),
		"bestiary": bestiary.duplicate(true),
		"puzzle_latched": puzzle_latched.duplicate(true),
		"kernen": kernfragmenten.duplicate(true),
		"codex": codex_save_data(),
		"uniek": unique_done.duplicate(true),
		"dungeon100": Dungeon100RulesC.save_data(dungeon100_floor, dungeon100_checkpoint, dungeon100_best, dungeon100_seed,
				{"permanent": dungeon100_permanent, "delivered": dungeon100_delivered, "snapshot": dungeon100_snapshot}),
		"story": {"step": story_step, "flags": story_flags.keys()},
	}
	data["party"] = _party_save()
	return data


## Leest een save (standaard de handmatige; v0.11: of 'path', bv. autosave_path).
func read_save(path := "") -> Dictionary:
	if path == "":
		path = save_path
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Laadt de save en zet alles terug (party, spullen, goud, speeltijd, bestiarium);
## geeft false als er geen (geldige) save is. Daarna: continue_game() gaat naar de map.
## v0.11: 'path' = welke save ("" = de handmatige).
func load_game(path := "") -> bool:
	var d := read_save(path)
	if not apply_state(d):
		return false
	# v0.19 kamer-checkpoint uit de save (oude saves: geen; dan zet de map hem bij binnenkomst)
	checkpoint = _checkpoint_from(d.get("checkpoint", {}))
	entry_kind = "load"
	pending_respawn_msg = []
	return true


## v0.19: geldig checkpoint uit een save ({} = ontbreekt of kapot).
static func _checkpoint_from(c) -> Dictionary:
	if not (c is Dictionary) or not (c.get("map") is String) or str(c["map"]) == "":
		return {}
	var st = c.get("state")
	if not (st is Dictionary) or not st.has("map") or not (st.get("party") is Array):
		return {}
	var t := _vec2i_from(c.get("tile"), Vector2i(-9999, -9999))
	if t == Vector2i(-9999, -9999):
		return {}
	var fc := _vec2i_from(c.get("facing"), Vector2i.DOWN)
	return {"map": str(c["map"]), "tile": [t.x, t.y], "facing": [fc.x, fc.y], "state": (st as Dictionary).duplicate(true)}


## Zet alle voortgang uit een save-Dictionary terug (load_game, en v0.19 de respawn op het
## checkpoint). false = geen geldige data.
func apply_state(d: Dictionary) -> bool:
	# v0.11: elke sleutel met een standaardwaarde; ontbrekende of verkeerde velden (oudere
	# of nieuwere saves) laten het spel nooit vastlopen.
	if d.is_empty() or not d.has("map") or not (d.get("party") is Array):
		return false
	player_name = clean_name(str(d.get("player_name", DEFAULT_NAME)))
	party.clear()
	var stray_equipment: Array = []
	party = _party_from(d["party"], stray_equipment)
	if party.is_empty():
		add_member(MAIN_HERO)
	inventory = _inventory_from(d.get("inventory", {}))
	for id in stray_equipment:
		inventory[id] = int(inventory.get(id, 0)) + 1
	gold = int(d.get("gold", 0)) if (d.get("gold", 0) is float or d.get("gold", 0) is int) else 0
	bestiary = {}
	var best = d.get("bestiary", {})
	if best is Dictionary:
		for k in best:
			if best[k] is Dictionary:
				bestiary[k] = {"seen": bool(best[k].get("seen", false)), "defeated": int(best[k].get("defeated", 0))}
	# v0.11 verhaal; een save van vóór v0.11 heeft geen proloog -> die is dan 'klaar'
	var st = d.get("story", {})
	if not (st is Dictionary):
		st = {}
	var step = st.get("step", StoryData.KLAAR)
	story_step = int(step) if d.has("story") and (step is float or step is int) else StoryData.KLAAR
	story_flags = {}
	var flags = st.get("flags", [])
	if flags is Array:
		for f in flags:
			story_flags[str(f)] = true
	pending_tutorial = {}
	if has_node("/root/Story"):
		get_node("/root/Story").reset(true)
	# v0.12: oude saves zonder dit veld laden gewoon (dan {}).
	# v0.15 kernfragmenten; oude saves zonder dit veld = geen kernen. Onbekende ids vallen weg.
	kernfragmenten = {}
	pending_kern_absorb = ""
	var kn = d.get("kernen", {})
	if kn is Dictionary:
		for k in kn:
			if KernData.KERNFRAGMENTEN.has(str(k)):
				var e: Dictionary = kn[k] if kn[k] is Dictionary else {}
				kernfragmenten[str(k)] = e.duplicate(true)
	# Codex: oude saves zonder "codex" = lege Codex; kapotte pagina's vallen weg.
	codex_load_data(d.get("codex", {}))
	dungeon100_load(d.get("dungeon100", {}))
	# v0.19 unieke monsters; oude saves zonder dit veld = nog niets verslagen. Onbekende ids vallen weg.
	unique_done = {}
	var un = d.get("uniek", {})
	if un is Dictionary:
		for k in un:
			if is_unique(str(k)):
				unique_done[str(k)] = "gevangen" if str(un[k]) == "gevangen" else "verslagen"
	puzzle_latched = {}
	var pl = d.get("puzzle_latched", {})
	if pl is Dictionary:
		for k in pl:
			if pl[k] is Array:
				puzzle_latched[str(k)] = (pl[k] as Array).map(func(g): return str(g))
	var pt = d.get("play_time", 0.0)
	_play_time_base = float(pt) if (pt is float or pt is int) else 0.0
	_clock_start_ms = Time.get_ticks_msec()
	return_map = str(d["map"])
	return_tile = _vec2i_from(d.get("tile"), Vector2i.ZERO)
	return_facing = _vec2i_from(d.get("facing"), Vector2i.DOWN)
	has_return_point = true
	pending_spawn = ""
	steps_until_encounter_possible = GameData.SAFE_STEPS
	map_monster_battle = {}
	defeated_map_monsters = {}
	return true


## v0.11: [x, y] uit een save -> Vector2i (fallback als het ontbreekt of niet klopt).
static func _vec2i_from(v, fallback: Vector2i) -> Vector2i:
	if v is Array and v.size() >= 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		return Vector2i(int(v[0]), int(v[1]))
	return fallback


## Oude held-id's uit saves van vóór v0.11 (de hoofdpersoon heette in de code eerst anders).
## v0.13: uit HERO_ID_LEGACY (de enige plek met de oude id-tekst).
const LEGACY_HERO_IDS := {HERO_ID_LEGACY: MAIN_HERO}


func hero_id_compat(id: String) -> String:
	return LEGACY_HERO_IDS.get(id, id)


## Titelscherm 'Doorgaan': laden en naar de opgeslagen map + plek.
## v0.11: de NIEUWSTE van handmatige save en autosave.
func continue_game() -> bool:
	use_story_saves()
	if changing_map or not load_game(newest_save_path()):
		return false
	changing_map = true
	in_battle = false
	await Transition.fade_out()
	_go_to_scene(return_map if ResourceLoader.exists(return_map) else START_MAP)
	return true


## Betatest-account: verdergaan in de aparte voortgang, of die de eerste keer aanmaken.
## Proloog is klaar, Dennis is niveau 10 met het Vonkzwaard, de Codex heeft al een buddy.
## De Golem staat er nog (3 Lege Boeken), het woud is open, Esdoorn pas na de Golem.
func start_beta_game() -> void:
	if changing_map or in_battle:
		return
	use_beta_saves()
	var p := newest_beta_path()
	if p != "" and load_game(p):
		if _grant_beta_inktwurm():
			save_game(return_tile, return_facing)
		changing_map = true
		in_battle = false
		await Transition.fade_out()
		_go_to_scene(return_map if ResourceLoader.exists(return_map) else WORLD_MAP)
		return
	_build_beta_state()
	current_map = WORLD_MAP
	save_game(BETA_TILE, BETA_FACING)
	changing_map = false
	change_map(WORLD_MAP, BETA_SPAWN)


## Eerste betatest-voortgang. Raakt de gewone save niet aan (die paden staan even opzij).
func _build_beta_state() -> void:
	new_game(DEFAULT_NAME)
	story_step = StoryData.KLAAR
	story_flags = {}
	for f in BETA_FLAGS:
		story_flags[f] = true
	var hero: Dictionary = party[0]
	give_exp(hero, GameData.exp_for_level(BETA_LEVEL) - int(hero["exp"]))
	for id in ["vonkzwaard", "houten_schild", "leren_kap", "leerling_mantel"]:
		inventory[id] = item_count(id) + 1
		Equipment.equip(hero, inventory, Equipment.slot_of(id), id)
	hero["hp"] = hero["max_hp"]
	hero["mp"] = hero["max_mp"]
	inventory["drankje"] = 5
	inventory["toverwater"] = 3
	inventory["leeg_boek"] = 6
	gold = 200
	codex_add("mosslijm", 5)
	codex_add("moskonijn", 5)
	_grant_beta_inktwurm()
	mark_seen("mosslijm")
	mark_seen("moskonijn")


## Oude betatest-save (van vóór de Inktwurm): de pagina erbij en meteen de buddy.
## true = er is een Inktwurm toegevoegd.
func _grant_beta_inktwurm() -> bool:
	for page in codex_pages:
		if str(page.get("species", "")) == "inktwurm":
			return false
	var iw := codex_add("inktwurm", 5)
	if iw.is_empty():
		return false
	codex_set_active(str(iw.get("uid", "")))
	mark_seen("inktwurm")
	return true


## Na de naamkeuze: nieuw spel en naar het startpunt in het dorp.
func start_new_game(hero_name: String) -> void:
	use_story_saves()
	new_game(hero_name)
	changing_map = false
	change_map(START_MAP, START_SPAWN)
	# v0.11: niet meteen automatisch opslaan bij een nieuw spel (anders is de autosave van
	# het vorige spel direct weg); dat gebeurt pas bij de eerste echte mapwissel.
	_autosave_request = ""


## Terug naar het titelscherm (bv. vanuit het veldmenu, en in de autotest).
func go_to_title() -> void:
	if changing_map or in_battle:
		return
	use_story_saves()
	if dungeon100_run_active():
		dungeon100_end_run(true)
	changing_map = true
	dungeon100_floor = 0
	await Transition.fade_out()
	changing_map = false
	_go_to_scene(TITLE_SCENE)
	Transition.fade_in()


# ---------------------------------------------------------------- maps
## Wordt aangeroepen door map.gd zodra een map geladen is.
func enter_map(path: String) -> void:
	current_map = path
	if path != Dungeon100RulesC.dungeon_scene:
		# Veiligheidsnet, niet tijdens een gevecht: wie de grot verlaat krijgt de echte party terug
		# en de Blauwe Kist-items. Een gevecht laadt geen map en mag de run niet afbreken.
		if not in_battle and dungeon100_run_active():
			dungeon100_end_run(true)
		dungeon100_floor = 0      # buiten de Diepe Grot (ook na game over of een andere map)
	changing_map = false


## Ga naar een andere map: fade uit, wissel van scène, en zet de speler
## op het spawnpunt met de naam spawn_name (een node onder "Spawns").
func change_map(path: String, spawn_name: String) -> void:
	if changing_map or in_battle:
		return
	changing_map = true
	pending_spawn = spawn_name
	has_return_point = false
	entry_kind = "door"
	_autosave_request = "map"
	await Transition.fade_out()
	_go_to_scene(path)


# ---------------------------------------------------------------- encounters
## Kans op een gevecht per stap op dit terrein (0 = nooit).
func encounter_rate_for(terrain: String) -> float:
	return float(GameData.ENCOUNTER_RATES.get(terrain, 0.0)) * encounter_multiplier


## Wordt per stap aangeroepen door map.gd (alleen op maps met monsters).
## Geeft true als er een gevecht begint.
func on_player_step(terrain: String) -> bool:
	if in_battle or changing_map:
		return false
	var rate := encounter_rate_for(terrain)
	if rate <= 0.0:
		return false
	if steps_until_encounter_possible > 0:
		steps_until_encounter_possible -= 1
		return false
	return randf() < rate


## Kies een vijandgroep voor dit terrein (groepen met "terrains" alleen daar).
func pick_encounter_group(terrain := "") -> Array:
	if not debug_force_group.is_empty():
		return debug_force_group.duplicate()
	var groups: Array = []
	var total := 0
	for g in GameData.ENCOUNTER_GROUPS:
		if int(g["weight"]) <= 0:
			continue
		if g.has("terrains") and not (terrain in g["terrains"]):
			continue
		groups.append(g)
		total += int(g["weight"])
	if total <= 0:
		return GameData.ENCOUNTER_GROUPS[0]["enemies"].duplicate()
	var roll := randi() % total
	for g in groups:
		roll -= int(g["weight"])
		if roll < 0:
			return g["enemies"].duplicate()
	return groups[0]["enemies"].duplicate()


## Eerste groep met "boss": true (voor de debug-trigger F3), of [] als er geen is.
func boss_group() -> Dictionary:
	for g in GameData.ENCOUNTER_GROUPS:
		if g.get("boss", false):
			return g
	return {}


## Start een gevecht: onthoud map + positie, flits, en wissel naar de gevechtsscène.
## v0.14: tier = monsterniveau (0 = gewoon; dungeonkamers geven hun "tier" mee, nooit voor een baas).
func start_battle(enemies: Array, from_tile: Vector2i, facing: Vector2i, terrain := "", boss := false, tier := 0) -> void:
	if in_battle or changing_map:
		return
	in_battle = true
	pending_enemies = enemies
	pending_boss = boss
	pending_tier = 0 if boss else tier
	pending_backdrop_id = GameData.backdrop_id_for(terrain, boss)
	pending_backdrop = GameData.backdrop_path(pending_backdrop_id)
	has_return_point = true
	return_map = current_map
	return_tile = from_tile
	return_facing = facing
	await Transition.encounter_out()
	_go_to_scene(BATTLE_SCENE)


## Terug naar de map waar het gevecht begon (na winnen of vluchten),
## of naar het begin van het spel (game over).
func end_battle(result: String) -> void:
	last_battle_result = result
	pending_tier = 0
	steps_until_encounter_possible = GameData.SAFE_STEPS
	pending_tutorial = {}
	var target := return_map if return_map != "" else START_MAP
	if result == "lose":
		map_monster_battle = {}
		if dungeon100_floor > 0 or dungeon100_run_active():
			# 100-kerker: dood is dungeon uit. Terug naar de wereldkaart bij de ingang, niet verdieping 1.
			target = dungeon100_defeat()
		elif has_checkpoint():
			# v0.19: terug naar waar je deze kamer/map binnenkwam (baas: de kamer ervoor)
			target = respawn_at_checkpoint(pending_boss)
		else:
			respawn()
			target = RESPAWN_MAP
	else:
		entry_kind = "battle"
		# KO-helden staan na het gevecht weer op met 1 HP (houdt het simpel).
		for h in party:
			if h["hp"] <= 0:
				h["hp"] = 1
		# Codex: de bondgenoot ook (zelfde regel als de helden)
		for p in codex_pages:
			if int(p["hp"]) <= 0:
				p["hp"] = 1
		# v0.11: na winst automatisch opslaan (zodra de map weer in beeld is)
		if result == "win":
			_autosave_request = "battle"
			# v0.15: baas verslagen -> de hoofdheld absorbeert zijn kern (eenmalig). Meteen
			# vastleggen, dus de autosave hierna heeft hem al; het moment zelf speelt de map af.
			if pending_boss and dungeon100_floor == 0:      # de simulatie geeft geen echte kernen
				for e in pending_enemies:
					var kid := KernData.fragment_for_boss(str(e))
					if kid != "" and grant_kern(kid, str(e)):
						pending_kern_absorb = kid
	await Transition.fade_out()
	in_battle = false
	_go_to_scene(target)


## v0.19: is er een bruikbaar kamer-checkpoint?
func has_checkpoint() -> bool:
	return not checkpoint.is_empty() and ResourceLoader.exists(str(checkpoint.get("map", ""))) \
			and checkpoint.get("state") is Dictionary


## v0.19: leg het kamer-checkpoint vast (map.gd, bij binnenkomst): plek + kopie van de voortgang.
func set_checkpoint(map: String, tile: Vector2i, facing: Vector2i) -> void:
	checkpoint = {"map": map, "tile": [tile.x, tile.y], "facing": [facing.x, facing.y],
			"state": state_data(tile, facing, map)}


## v0.19 GAME OVER met checkpoint: voortgang terug zoals bij binnenkomst (party/EXP/spullen/goud/
## verhaal/kernen/Codex), iedereen vol HP/MP, en terug op die plek. Bestiarium en speeltijd lopen
## gewoon door. Geeft de map terug waar je naartoe gaat.
func respawn_at_checkpoint(boss := false) -> String:
	var keep_best := bestiary.duplicate(true)
	var keep_time := play_time()
	var keep_permanent := dungeon100_permanent.duplicate(true)      # de databank rolt niet mee terug
	var keep_floor_best := dungeon100_best
	# Uniek 'verslagen' blijft, ook als je daarna het gevecht verliest (HANDOFF_FUSIE aanname 6).
	# 'gevangen' rolt mee met de Codex, die bij het checkpoint hoort.
	var keep_unique := unique_done.duplicate(true)
	var cp := checkpoint.duplicate(true)
	apply_state(cp["state"])
	for id in keep_unique:
		if str(keep_unique[id]) == "verslagen" and not unique_done.has(str(id)):
			unique_done[str(id)] = "verslagen"
	dungeon100_permanent = keep_permanent
	dungeon100_best = maxi(dungeon100_best, keep_floor_best)
	bestiary = keep_best
	_play_time_base = keep_time
	_clock_start_ms = Time.get_ticks_msec()
	checkpoint = cp
	_full_heal()
	var t := _vec2i_from(cp.get("tile"), Vector2i.ZERO)
	var fc := _vec2i_from(cp.get("facing"), Vector2i.DOWN)
	return_map = str(cp["map"])
	return_tile = t
	return_facing = fc
	has_return_point = true
	pending_spawn = ""
	entry_kind = "respawn"
	pending_respawn_msg = (RESPAWN_LINES_BOSS if boss else RESPAWN_LINES).duplicate()
	last_respawn = {"map": return_map, "tile": t, "facing": fc, "boss": boss}
	# na het ontwaken automatisch opslaan (Doorgaan begint dan ook hier)
	_autosave_request = "respawn"
	return return_map


## v0.19: tekst in het gevecht bij GAME OVER (waar je wakker wordt).
func defeat_text(boss := false) -> String:
	if dungeon100_floor > 0 or dungeon100_run_active():
		return DUNGEON100_DEFEAT_TEXT
	if not has_checkpoint():
		return "GAME OVER\nYou wake up back at the start."
	return "GAME OVER\n" + str((RESPAWN_LINES_BOSS if boss else RESPAWN_LINES)[0])


func _full_heal() -> void:
	for h in party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	for p in codex_pages:          # Codex: de monsters ook
		p["hp"] = p["max_hp"]
		p["mp"] = p["max_mp"]


## GAME OVER ZONDER checkpoint (terugval, v0.19; zo werkte het tot v0.18 altijd): iedereen
## volledig genezen, helft van het goud kwijt, terug naar het startpunt in het eerste dorp.
func respawn() -> void:
	if dungeon100_floor > 0:
		dungeon100_defeat()
		return
	for h in party:
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	for p in codex_pages:          # Codex: de monsters ook
		p["hp"] = p["max_hp"]
		p["mp"] = p["max_mp"]
	gold = int(gold * Dungeon100RulesC.GOLD_KEEP_GAME_OVER)      # helft van het goud (was int(gold / 2.0))
	has_return_point = false
	pending_spawn = RESPAWN_SPAWN


# ---------------------------------------------------------------- 100-verdiepingen-kerker: Het Gesimuleerde Archief (runs)
## Is er een run bezig? (de echte party/tas liggen dan in de momentopname)
func dungeon100_run_active() -> bool:
	return not dungeon100_snapshot.is_empty()


## Is dit item permanent (zit het in de Blauwe-Kist-databank)? Alleen tijdens een run, daarbuiten is
## het gewoon een item van je tas.
func is_permanent_item(id: String) -> bool:
	return dungeon100_run_active() and dungeon100_permanent.has(id)


## Een run begint (Dungeon100Room, bij het binnenkomen vanaf de wereldkaart): de echte party/tas/goud/
## Codex gaan in de momentopname. De simulatie neemt iedereen mee die dan in de party zit (ook wie zich
## later aansloot) plus elke Codex-pagina, allemaal op level 1, zonder uitrusting en zonder spreuken.
## De tas heeft alleen de permanente items, en er is geen goud. Dubbel aanroepen doet niets (false).
func dungeon100_begin_run() -> bool:
	if dungeon100_run_active():
		return false
	dungeon100_snapshot = {"party": _party_save(), "inventory": inventory.duplicate(true), "gold": gold,
			"codex": codex_save_data()}
	_dungeon100_fresh_run()
	dungeon100_floor = maxi(1, dungeon100_floor)      # vanaf de wereldkaart 1; een geladen oude save houdt zijn verdieping
	return true


## Zet de simulatie op 'nieuw': dezelfde party-leden op level 1 (geen uitrusting, geen spreuken), elke
## Codex-pagina op level 1 (zelfde uid, alleen vaardigheden van level 1), tas = permanente items, goud 0,
## schone run-vlaggen. Verdieping, seed en rustpunt laat dit aan de aanroeper.
func _dungeon100_fresh_run() -> void:
	var ids: Array = party.map(func(h): return str(h.get("id", "")))
	party = []
	for id in ids:
		var h := hero_template(str(id))
		if h.is_empty():
			continue
		h["spells"] = []
		party.append(h)
	if party.is_empty():
		add_member(MAIN_HERO)
		if not party.is_empty():
			party[0]["spells"] = []
	inventory = dungeon100_permanent.duplicate(true)
	gold = 0
	_dungeon100_strip_codex()
	_dungeon100_clear_run_flags()
	defeated_map_monsters = {}
	map_monster_battle = {}


## Codex mee de grot in: elke pagina opnieuw op level 1. Uid, naam, vangst en (bij een fusie) element,
## type en fusie-gegevens blijven. Vaardigheden zijn alleen wat de soort op level 1 kent. De teller voor
## nieuwe pagina's blijft, zodat een vangst tijdens de run geen uid hergebruikt.
func _dungeon100_strip_codex() -> void:
	var kept: Array = []
	for page in codex_pages:
		var species := str(page.get("species", ""))
		var uid := str(page.get("uid", ""))
		if uid == "" or not CodexData.has_species(species):
			continue
		var fresh := CodexData.make_page(species, 1, uid)
		if page.get("name") is String and str(page["name"]) != "":
			fresh["name"] = str(page["name"])
		if page.get("caught") is Dictionary:
			fresh["caught"] = (page["caught"] as Dictionary).duplicate(true)
		if CodexData.is_fused(page):
			for k in ["element", "type"]:
				if page.get(k) is String and str(page[k]) != "":
					fresh[k] = str(page[k])
			if page.get("fusion_tags") is Array:
				fresh["fusion_tags"] = (page["fusion_tags"] as Array).duplicate()
			if page.get("fusion") is Dictionary:
				fresh["fusion"] = (page["fusion"] as Dictionary).duplicate(true)
		kept.append(fresh)
	codex_pages = kept
	if codex_page(codex_active).is_empty():
		codex_active = ""
	codex_changed.emit()


func _dungeon100_clear_run_flags() -> void:
	for f in story_flags.keys():
		if Dungeon100RulesC.is_run_flag(str(f)):
			story_flags.erase(f)


## De run is voorbij (verlaten, dood of Warp): de echte party/tas/goud/Codex terug uit de momentopname,
## run-vlaggen weg, verdieping 0 en een nieuwe seed bij de volgende binnenkomst. 'deliver' (standaard):
## permanente Blauwe-Kist-items die nog niet in de echte tas lagen komen er nu in. Geen run = false.
func dungeon100_end_run(deliver := true) -> bool:
	if not dungeon100_run_active():
		return false
	var snap := dungeon100_snapshot
	var stray: Array = []
	party = _party_from(snap["party"], stray)
	if party.is_empty():
		add_member(MAIN_HERO)
	inventory = _inventory_from(snap.get("inventory", {}))
	for id in stray:
		inventory[id] = int(inventory.get(id, 0)) + 1
	var g = snap.get("gold", 0)
	gold = int(g) if (g is int or g is float) else 0
	codex_load_data(snap.get("codex", {}))
	dungeon100_snapshot = {}
	_dungeon100_clear_run_flags()
	defeated_map_monsters = {}
	map_monster_battle = {}
	dungeon100_checkpoint = 0
	dungeon100_floor = 0
	dungeon100_seed = 0
	if deliver:
		dungeon100_deliver()
	return true


## Permanente items die nog niet in de echte tas zijn gelegd erin leggen (na een geslaagde Warp).
## Geeft het aantal stukken terug. Alleen buiten een run (de echte tas is dan 'inventory').
func dungeon100_deliver() -> int:
	var n := 0
	for id in dungeon100_permanent:
		var delta := int(dungeon100_permanent[id]) - int(dungeon100_delivered.get(id, 0))
		if delta > 0:
			inventory[id] = item_count(str(id)) + delta
			dungeon100_delivered[id] = int(dungeon100_permanent[id])
			n += delta
	return n


## Je verlaat de kerker via de ladder op verdieping 1: run opgegeven. De momentopname komt terug en
## Blauwe Kist-items die nog niet in de echte tas zaten komen er nu in.
func dungeon100_leave() -> bool:
	return dungeon100_end_run(true)


## Het Warp-kristal werkt alleen op de laatste verdieping, tijdens een run, met het kristal in de tas.
func dungeon100_can_warp() -> bool:
	return dungeon100_run_active() and dungeon100_floor == Dungeon100RulesC.FLOORS and item_count(Dungeon100RulesC.Blue.WARP_ITEM) > 0


## Warp: run voltooid, permanente items mee naar je echte tas, terug naar de wereldkaart (het kristal is
## op). false = kan niet (verkeerde verdieping, geen kristal of geen run).
func dungeon100_warp() -> bool:
	if not dungeon100_can_warp():
		return false
	dungeon100_best = Dungeon100RulesC.FLOORS
	dungeon100_end_run(true)
	change_map(Dungeon100RulesC.WORLD_SCENE, Dungeon100RulesC.WORLD_SPAWN)
	return true


## Nederlaag in de kerker: de run is voorbij ("dood is dungeon uit"). Tijdelijke levels, tas en goud van
## de run zijn weg. De echte party/tas/goud/Codex komen terug uit de momentopname, daarna de permanente
## Blauwe-Kist-items. Terug naar de wereldkaart bij de ingang, niet naar verdieping 1. Een nieuwe run
## begint pas als je opnieuw naar binnen gaat. Geeft de wereldkaart terug.
func dungeon100_defeat() -> String:
	dungeon100_best = Dungeon100RulesC.best_after(dungeon100_best, dungeon100_floor)
	has_return_point = false
	if dungeon100_run_active():
		dungeon100_end_run(true)
	else:
		_dungeon100_clear_run_flags()
		dungeon100_checkpoint = 0
		dungeon100_floor = 0
		dungeon100_seed = 0
	_full_heal()
	pending_spawn = Dungeon100RulesC.WORLD_SPAWN
	pending_respawn_msg = DUNGEON100_RESET_LINES.duplicate()
	entry_kind = "respawn"
	_autosave_request = "respawn"
	return Dungeon100RulesC.WORLD_SCENE


## Zet verdieping/checkpoint/best/seed + permanente items/momentopname uit save-data
## (Dungeon100Rules.load_data); {} = alles 0 en leeg.
func dungeon100_load(raw) -> void:
	var v := Dungeon100RulesC.load_data(raw)
	dungeon100_floor = int(v["floor"])
	dungeon100_checkpoint = int(v["checkpoint"])
	dungeon100_best = int(v["best"])
	dungeon100_seed = int(v["seed"])
	dungeon100_permanent = v["permanent"]
	dungeon100_delivered = v["delivered"]
	dungeon100_snapshot = v["snapshot"]


# ---------------------------------------------------------------- kernfragmenten (v0.15)
## Geef kernfragment 'id' aan de hoofdheld. false = bestaat niet of had je al (nooit dubbel).
func grant_kern(id: String, from_boss := "") -> bool:
	if not KernData.KERNFRAGMENTEN.has(id) or kernfragmenten.has(id):
		return false
	kernfragmenten[id] = {"bron": from_boss if from_boss != "" else str(KernData.KERNFRAGMENTEN[id]["source_boss"]),
			"stap": 1}
	return true


func has_kern(id: String) -> bool:
	return kernfragmenten.has(id)


## Heeft de party deze wereldvaardigheid (uit een kern)?
func has_world_ability(ability: String) -> bool:
	return world_abilities().has(ability)


func world_abilities() -> Dictionary:
	var out := {}
	for id in kernfragmenten:
		for a in KernData.abilities_of(KernData.fragment(id)):   # v0.16: id of lijst
			out[a] = true
	return out


## Kernvaardigheden (ids in KernData.KERN_SKILLS) van een held: alleen de hoofdheld draagt kernen.
func kern_skills_of(hero_id: String) -> Array:
	var out: Array = []
	if hero_id != MAIN_HERO:
		return out
	for id in kernfragmenten:
		var sk := str(KernData.fragment(id).get("battle_skill", ""))
		if sk != "" and not out.has(sk):
			out.append(sk)
	return out


# ---------------------------------------------------------------- party / level-up
func alive_heroes() -> Array:
	return party.filter(func(h): return h["hp"] > 0)


## Geeft EXP aan één held en geeft een lijst van berichten terug (level-ups).
func give_exp(hero: Dictionary, amount: int) -> Array[String]:
	var messages: Array[String] = []
	hero["exp"] += amount
	while hero["exp"] >= GameData.exp_for_level(hero["level"] + 1):
		hero["level"] += 1
		var g: Dictionary = hero["growth"]
		hero["max_hp"] += g["max_hp"]
		hero["hp"] += g["max_hp"]
		hero["max_mp"] += g["max_mp"]
		hero["mp"] += g["max_mp"]
		# v0.14: atk/def/agi/mag/mdef groeien op de BASIS; de effectieve waarde (met
		# uitrusting) wordt opnieuw uitgerekend (Equipment.grow -> refresh).
		Equipment.grow(hero, g)
		messages.append("%s is now level %d!" % [hero["name"], hero["level"]])
	return messages


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


# ---------------------------------------------------------------- Codex (Kernfragment stap 2)
func codex_reset(notify := true) -> void:
	codex_pages = []
	codex_active = ""
	codex_next_id = 1
	if notify:
		codex_changed.emit()


func codex_full() -> bool:
	return codex_pages.size() >= CodexData.MAX_PAGES


## Nieuwe pagina in de Codex. Elk exemplaar krijgt een eigen uid (ook dubbele soorten: elk
## gevangen monster is een eigen pagina; handig voor fusie later). De eerste pagina wordt
## meteen de actieve bondgenoot. {} = Codex vol of onbekende soort.
func codex_add(species_id: String, level := 1, caught := {}) -> Dictionary:
	if codex_full() or not CodexData.has_species(species_id):
		return {}
	var uid := "codex_%04d" % codex_next_id
	codex_next_id += 1
	var page := CodexData.make_page(species_id, level, uid)
	page["caught"] = caught.duplicate(true)
	codex_pages.append(page)
	if codex_active == "":
		codex_active = uid
	codex_changed.emit()
	return page


func codex_page(uid: String) -> Dictionary:
	for p in codex_pages:
		if str(p["uid"]) == uid:
			return p
	return {}


## Actieve bondgenoot ("" of een onbekende uid = geen).
func codex_set_active(uid: String) -> bool:
	if uid != "" and codex_page(uid).is_empty():
		return false
	if uid == codex_active:
		return true
	codex_active = uid
	codex_changed.emit()
	return true


## De pagina van de actieve bondgenoot ({} = geen).
func codex_active_page() -> Dictionary:
	return codex_page(codex_active) if codex_active != "" else {}


func codex_save_data() -> Dictionary:
	return {"pages": codex_pages.duplicate(true), "active": codex_active, "next": codex_next_id}


func codex_load_data(raw) -> void:
	codex_reset(false)
	if not (raw is Dictionary):
		codex_changed.emit()
		return
	var seen := {}
	if raw.get("pages") is Array:
		for r in raw["pages"]:
			var p := CodexData.clean_page(r)
			if p.is_empty() or seen.has(p["uid"]) or codex_pages.size() >= CodexData.MAX_PAGES:
				continue
			seen[p["uid"]] = true
			codex_pages.append(p)
	var nx = raw.get("next", 1)
	codex_next_id = int(nx) if (nx is int or nx is float) else 1
	# nooit een uid hergebruiken, ook niet als "next" ontbreekt of te laag is
	for p in codex_pages:
		var n := str(p["uid"]).trim_prefix("codex_")
		if n.is_valid_int():
			codex_next_id = maxi(codex_next_id, int(n) + 1)
	codex_active = str(raw.get("active", ""))
	if codex_page(codex_active).is_empty():
		codex_active = ""
	codex_changed.emit()


# ---------------------------------------------------------------- glitch-fusie (Kernfragment stap 3, v0.19)
## Waarom kunnen pagina's 'uid_a' en 'uid_b' niet fuseren? "" = het kan. Regels: CodexData.FUSION_TABLE.
func codex_fusion_reason(uid_a: String, uid_b: String) -> String:
	if in_battle:
		return "You can't fuse during a battle."
	if codex_pages.size() < 2:
		return "A fusion needs two pages."
	var a := codex_page(uid_a)
	var b := codex_page(uid_b)
	if a.is_empty() or b.is_empty():
		return "Pick two pages."
	return CodexData.fusion_block_reason(a, b)


## Voorbeeld van de fusie (zelfde regels, maar er verandert niets; uid = ""). {} = kan niet.
func codex_fusion_preview(uid_a: String, uid_b: String) -> Dictionary:
	if codex_fusion_reason(uid_a, uid_b) != "":
		return {}
	return CodexData.make_fusion_page(codex_page(uid_a), codex_page(uid_b), "")


## Fuseer A + B: beide pagina's verdwijnen, de nieuwe komt op de plek van A en krijgt een nieuwe uid
## (nooit hergebruikt). Was A of B de bondgenoot, dan wordt de nieuwe het. {} = kan niet (er verandert
## dan niets). Alles in één keer: geen await, dus nooit half gefuseerd of dubbel.
func codex_fuse(uid_a: String, uid_b: String) -> Dictionary:
	if codex_fusion_reason(uid_a, uid_b) != "":
		return {}
	var uid := "codex_%04d" % codex_next_id
	var page := CodexData.make_fusion_page(codex_page(uid_a), codex_page(uid_b), uid)
	if page.is_empty():
		return {}
	codex_next_id += 1
	page["caught"] = {"fusie": true, "play_time": int(play_time())}
	var was_active := codex_active == uid_a or codex_active == uid_b
	var at := -1
	for i in codex_pages.size():
		if str(codex_pages[i]["uid"]) == uid_a:
			at = i
	codex_pages = codex_pages.filter(func(p): return str(p["uid"]) != uid_a and str(p["uid"]) != uid_b)
	codex_pages.insert(clampi(at, 0, codex_pages.size()), page)
	if was_active:
		codex_active = uid
	codex_changed.emit()
	return page


# ---------------------------------------------------------------- unieke monsters (v0.19)
## Is vijand 'id' uniek (maar 1x in het spel)? (GameData.ENEMIES "unique": true)
func is_unique(id: String) -> bool:
	return bool(GameData.ENEMIES.get(id, {}).get("unique", false))


## Mag dit monster (nog) verschijnen? Gewone monsters: altijd true. Unieke: false zodra hij verslagen of
## gevangen is. Voor Forge in de kaart: dungeon_room.gd slaat zo'n monster al vanzelf over; een eigen
## plaatsing (story/object) kan dit zelf vragen:  if GameState.unique_available("inktwurm"): ...
func unique_available(id: String) -> bool:
	return not (is_unique(id) and unique_done.has(id))


## "verslagen" of "gevangen" ("" = nog niet). Alleen voor unieke monsters.
func unique_state(id: String) -> String:
	return str(unique_done.get(id, ""))


## Uniek monster weg: 'how' = "verslagen" of "gevangen". De eerste keer telt (nooit overschrijven).
func unique_mark(id: String, how: String) -> void:
	if is_unique(id) and not unique_done.has(id):
		unique_done[id] = how
