extends Node
## Autoload "GameState": alles wat moet blijven bestaan tussen scènes:
## party (HP/MP/level/EXP), inventaris, goud, op welke map de speler is,
## en waar hij stond voordat een gevecht begon. Data komt uit scripts/data/game_data.gd.

const GameData := preload("res://scripts/data/game_data.gd")
const ReleaseFlags := preload("res://scripts/data/release_flags.gd")
const EndgameBestiary := preload("res://scripts/data/endgame_bestiary.gd")
## v0.14 (menu L2): uitrusting en effectieve stats (basis + uitrusting).
const Equipment := preload("res://scripts/equipment.gd")
const KernData := preload("res://scripts/data/kern_data.gd")
const CodexData := preload("res://scripts/data/codex_data.gd")   # Kernfragment stap 2: de Codex
const Dungeon100RulesC := preload("res://scripts/dungeon/dungeon100_rules.gd")   # 100-verdiepingen-kerker
const EchoGrot := preload("res://scripts/data/echo_grot.gd")
## Hier begint een nieuw spel (v0.11: wakker worden in bed, in het huis).
const START_MAP := "res://scenes/maps/huis_wilgendal.tscn"
const START_SPAWN := "bed"
## Terugval bij GAME OVER als er (nog) geen kamer-checkpoint is (v0.19: zie 'checkpoint'): voor het huis.
const RESPAWN_MAP := "res://scenes/maps/wilgendal.tscn"
const RESPAWN_SPAWN := "start"
const TOWN_MAP := "res://scenes/maps/wilgendal.tscn"
## #166: het dorp (plein 10) met de deur van Dax naar HOUSE_MAP.
const DORP_MAP := "res://scenes/maps/dorp_wilgendal.tscn"
## #166: spawn voor de deur van Dax in DORP_MAP.
const DORP_HUIS_SPAWN := "voor_dax"
const WORLD_MAP := "res://scenes/maps/wereldkaart.tscn"
const StoryData := preload("res://scripts/data/story_data.gd")
const SpiegelData := preload("res://scripts/data/spiegel_data.gd")
const BerggrotData := preload("res://scripts/data/berggrot_data.gd")
const WorldWarperUnlock := preload("res://world_warper/flow/unlock.gd")
const LevelScale := preload("res://scripts/data/level_scale.gd")
const SpellRules := preload("res://scripts/data/spell_rules.gd")
const Dungeon100Reward := preload("res://scripts/data/dungeon100_reward.gd")
const PartyBenchLib := preload("res://scripts/party_bench.gd")
const PartyActions := preload("res://scripts/party_actions.gd")
const PartyLimiet := preload("res://scripts/party_limiet.gd")   # v0.22 max 4 helden + 1 monster
const ScenesData := preload("res://scripts/data/scenes_data.gd")   # v0.22 veldmenu > Scenes
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const NAME_SCENE := "res://scenes/ui/name_entry.tscn"
const HOUSE_MAP := "res://scenes/maps/huis_wilgendal.tscn"
## v0.10: naam van de hoofdpersoon (uit het naamscherm); leeg = DEFAULT_NAME.
const DEFAULT_NAME := "Dax"
const NAME_MAX := 10
## Held-id van de hoofdpersoon (v0.11: id 'dennis', sprites assets/sprites/battle/dennis*.png).
const MAIN_HERO := "dennis"
## Action-modus: wie je bestuurt (SWAP in som_arena.gd). Blijft over warps/kamers, opslaan/laden en
## Classic<->Action. Opgeslagen als "leader"; oude saves zonder veld = MAIN_HERO (Dax).
var leader_id := MAIN_HERO
## Fase B co-op: "host", "guest", of leeg (solo). Gasten schrijven nooit som_save_1.json.
var coop_role := ""
const COOP_SANDBOX_SCENE := "res://scenes/coop/action_sandbox.tscn"
var _coop_lobby: Node = null
var _coop_discovery: Node = null
var _coop_session: Node = null
var _coop_pending_message := ""
## Fase B: solo-voortgang van een gast vóór co-op (geheugen); terug bij vertrek, geen duplicaat op eigen save.
const COOP_GUEST_SAVE_PATH := "user://coop_guest_session.json"
const COOP_GUEST_AUTOSAVE_PATH := "user://coop_guest_autosave.json"
var _coop_guest_solo_snapshot: Dictionary = {}
var _coop_guest_solo_paths: Dictionary = {}


func coop_is_host() -> bool:
	return coop_role == "host"


func coop_is_guest() -> bool:
	return coop_role == "guest"


func coop_in_session() -> bool:
	return coop_role != ""


func coop_lobby() -> LanLobby:
	return _coop_lobby as LanLobby


func coop_register_lobby(lobby: Node, discovery: Node = null) -> void:
	_coop_lobby = lobby
	_coop_discovery = discovery
	if _coop_lobby != null and _coop_lobby.has_signal("session_ended"):
		if not _coop_lobby.session_ended.is_connected(_on_coop_session_ended):
			_coop_lobby.session_ended.connect(_on_coop_session_ended)
	if _coop_lobby != null and _coop_lobby.has_signal("link_lost"):
		if not _coop_lobby.link_lost.is_connected(_on_coop_link_lost):
			_coop_lobby.link_lost.connect(_on_coop_link_lost)


func coop_clear_lobby_refs() -> void:
	_coop_lobby = null
	_coop_discovery = null


func coop_bind_session(session: Node) -> void:
	_coop_session = session
	if session != null and session.has_signal("link_lost"):
		if not session.link_lost.is_connected(_on_coop_link_lost):
			session.link_lost.connect(_on_coop_link_lost)


func coop_shutdown_session() -> void:
	if _coop_session != null and is_instance_valid(_coop_session) and _coop_session.has_method("shutdown"):
		_coop_session.shutdown(true)
	_coop_session = null


func coop_end_session(reason: String = "") -> void:
	var was_guest := coop_is_guest()
	coop_shutdown_session()
	if coop_is_host() and _coop_lobby != null and _coop_lobby.has_method("broadcast_session_end"):
		if reason != "":
			_coop_lobby.broadcast_session_end(reason)
		if _coop_lobby.has_method("close"):
			_coop_lobby.close()
	if _coop_discovery != null and _coop_discovery.has_method("stop"):
		_coop_discovery.stop()
	coop_role = ""
	coop_clear_lobby_refs()
	if was_guest:
		_coop_restore_guest_solo()


func _coop_snapshot_guest_solo() -> void:
	if not _coop_guest_solo_snapshot.is_empty():
		return
	var map := return_map if return_map != "" else current_map
	_coop_guest_solo_snapshot = state_data(return_tile, return_facing, map)
	_coop_guest_solo_snapshot[CODEX_SYNC_KEY] = true
	_coop_guest_solo_paths = {
		"save_path": save_path,
		"autosave_path": autosave_path,
		"active_slot": active_slot,
		"som_mode": som_mode,
	}


func _coop_restore_guest_solo() -> void:
	if _coop_guest_solo_snapshot.is_empty():
		_coop_purge_guest_save_files()
		return
	var snap := _coop_guest_solo_snapshot
	var paths := _coop_guest_solo_paths
	_coop_guest_solo_snapshot = {}
	_coop_guest_solo_paths = {}
	apply_state(snap)
	save_path = str(paths.get("save_path", "user://save_1.json"))
	autosave_path = str(paths.get("autosave_path", AUTOSAVE_PATH))
	active_slot = int(paths.get("active_slot", 1))
	som_mode = bool(paths.get("som_mode", false))
	in_battle = false
	changing_map = false
	_coop_purge_guest_save_files()


func _coop_purge_guest_save_files() -> void:
	for p in [COOP_GUEST_SAVE_PATH, COOP_GUEST_AUTOSAVE_PATH]:
		_remove_file(p)
		_remove_file(p + ".tmp")
		_remove_file(p + ".bak")


func _on_coop_link_lost() -> void:
	if not coop_in_session():
		return
	var msg := "Connection lost."
	coop_end_session("")
	go_to_title(true)
	Dialog.show_lines([msg])


func coop_session_end_message(reason: String) -> String:
	const Protocol := preload("res://scripts/net/net_protocol.gd")
	return str(Protocol.SESSION_END_TEXT.get(reason, Protocol.SESSION_END_TEXT["ended"]))


func _on_coop_session_ended(reason: String) -> void:
	if coop_role == "" and reason == "":
		return
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null and scene is CanvasItem:
		var path := str(scene.get_script().resource_path) if scene.get_script() != null else ""
		if path.ends_with("coop_lobby_screen.gd"):
			return
	var msg := coop_session_end_message(reason)
	coop_end_session("")
	go_to_title(true)
	Dialog.show_lines([msg])


## Geldige leider: leader_id als die held in de actieve party zit en niet KO is, anders Dax (MAIN_HERO).
## (Is Dax zelf KO, dan blijft het Dax: de arena regelt KO van de bestuurde held zelf.)
func active_leader() -> String:
	for h in party:
		if str(h.get("id", "")) == leader_id and int(h.get("hp", 0)) > 0:
			return leader_id
	return MAIN_HERO


func set_leader(id: String) -> void:
	leader_id = id if id != "" else MAIN_HERO
## v0.11 veldmenu (oude id -> dennis): HERO_ID = de enige plek met de id-tekst voor nieuwe
## code; HERO_ID_LEGACY = oude id in saves van voor v0.11. Laden zet die om (resolve_hero_id).
const HERO_ID := MAIN_HERO
const HERO_ID_LEGACY := "ruben"
const HERO_ID_ALIASES := {HERO_ID_LEGACY: HERO_ID, HERO_ID: HERO_ID_LEGACY}
## Opslag: vier slots. Slot 1 is het oude bestand user://save_1.json (oude saves blijven werken).
## Slots 2-4 bestaan alleen als save_path op save_1.json eindigt (tests en het echte spel).
## Een betatest-pad eindigt daar niet op: dan is er één bestand, zoals eerst.
const SAVE_VERSION := 1
## Marker in elke save en elk checkpoint van deze versie: wie hem mist komt van vóór de Codex-Inktwurm-regels
## en wordt in _codex_inktwurm_sync gemigreerd. Zo telt een nieuwe save tussen de twee tutorials niet als oud.
const CODEX_SYNC_KEY := "inktwurm_codex_sync"
const SLOT_COUNT := 4
## Grenzen voor getallen uit een save (kapotte of met de hand aangepaste bestanden).
const MAX_GOLD := 999999999
const MAX_ITEM_STACK := 9999
## Laatste melding van load_game ("" = alles goed). Engels, voor de speler.
var last_load_notice := ""
const NOTICE_RECOVERED := "Your save file was damaged. It was restored from the backup copy."
const NOTICE_UNREADABLE := "This save file can't be read."
const RECOVERED_LINES := ["Your save file was damaged.", "It was restored from the backup copy."]
var save_path := "user://save_1.json"
## Welk slot de volgende handmatige save schrijft. Laden van een slot zet dit.
var active_slot := 1
## Slot 0 = de aparte autosave (Laden: 'Autosave'). Die overschrijft nooit slot 1..4.
const AUTOSAVE_SLOT := 0
## Redenen waarvoor automatisch wordt opgeslagen (Dennis).
## "achtergrond" is de verplichte pauze-save en negeert alleen de instelling, niet de blokkades.
const AUTOSAVE_REASONS := ["map", "achtergrond"]
## Gekozen slot voor het volgende nieuwe spel (titelscherm > New Game > slot kiezen).
var pending_new_slot := 1
## Autosave alleen bij een overgang wereldkaart <-> kerker (niet bij elke kamer of een dorp).
const NON_DUNGEON_MAPS := ["wilgendal", "dorp_wilgendal", "esdoorn", "wilgendal_binnen",
		"huis_wilgendal", "esdoorn_herberg", "esdoorn_huis_noor"]
## v0.11 Automatisch opslaan: een EIGEN bestand (overschrijft de handmatige save nooit).
## Wordt geschreven bij een kerker-overgang en als de app naar de achtergrond gaat (Android).
## De optie schakelt alleen de gewone autosave uit; de pauze-save blijft verplicht.
## Nooit tijdens een gevecht, een mapwissel of een tekstvak.
const AUTOSAVE_PATH := "user://autosave.json"
var autosave_path := AUTOSAVE_PATH
## Betatest: een eigen voortgang, los van Nieuw spel en Doorgaan. Zo kun je nieuwe
## content proberen zonder telkens in bed te beginnen, en zonder je echte spel te wissen.
## De paden worden gezet in _ready (tests krijgen een eigen voorvoegsel).
var _story_save_path := ""
var _story_autosave_path := ""
var playing_beta := false
## Eindstaat: eigen voortgang, los van de gewone slots én los van de betatest.
var playing_eind := false
## Start van een nieuw betatest-account: wereldkaart bij Wilgendal (spawn van_dorp).
const BETA_SPAWN := "van_dorp"
const BETA_TILE := Vector2i(14, 31)
const BETA_FACING := Vector2i(0, 1)
const BETA_LEVEL := 10
const BETA_FLAGS: Array[String] = ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien",
		"noor_ontmoet", "quest_noor", "marit_boeken"]
## Eindstaat: genoeg goud om in de winkels van Wilgendal te kopen (grade-3-spreuk = 1440).
const EIND_GOLD := 8000
## Gebouwde verhaalvlaggen t/m Noor gered. Geen kistvlaggen (die blijven open) en geen H-6.
const EIND_FLAGS: Array[String] = ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien",
		"noor_ontmoet", "quest_noor", "marit_boeken", "noor_gered", "noor_lid", "ilse_thee"]
## Bestaande G4-wapens uit grade_gear.gd, één per held die al in de data staat.
const EIND_WEAPONS := {
	"dennis": "bg_g4_superzwaard",
	"noor": "bg_g4_staf_noor",
	"lotte": "bg_g4_staf_lotte",
}
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
## Archief 2: plaat-stadia ("platen") gaan mee in de save. De rest is alleen dit gevecht.
var archief2 := {"platen": {}}
var archief2_temp_ally := {}
var archief2_party_filter := ""
var pending_story_loss := false
var archief2_lotte_join := false
var archief2_last_open := {}
var archief2_last_leech := {}
## Codex (Kernfragment stap 2): ingeschreven monsters (pagina's, zie codex_data.gd), de uid van
## de actieve bondgenoot ("" = geen) en de teller voor unieke ids (nooit hergebruikt).
## codex_changed: de actieve bondgenoot (of de lijst) is veranderd. De volger op de kaart luistert.
signal codex_changed
## Sessielog (scripts/core/sessie_log.gd) luistert hiernaar; ze sturen niets aan.
signal battle_started(enemies: Array, boss: bool)
signal battle_ended(result: String)
signal game_over(map_path: String)
signal game_saved(path: String, ok: bool)
signal game_loaded(path: String, ok: bool)
## De hoofd-save was kapot en load_game gebruikte de reservekopie (.bak).
signal save_recovered(path: String, backup_path: String)
signal menu_opened(which: String)
var codex_pages: Array = []
var codex_active := ""
var codex_next_id := 1
## v0.19 UNIEKE monsters (GameData.ENEMIES "unique": true, bv. de Inktwurm; beslissing Dennis): id ->
## "verslagen" / "gevangen". Staat erin = komt nooit meer terug. In de save als "uniek".
var unique_done := {}
## Uniek monster net voor het eerst weg (verslagen of gevangen). Story luistert (StoryData.AFTER_UNIQUE).
signal unique_marked(id: String, how: String)

## 100-verdiepingen-kerker (de Diepe Grot): alles gaat mee in de save, blok "dungeon100"
## (Dungeon100Rules.save_data/load_data). Zie HANDOFF_DUNGEON100*.md.
## huidige verdieping 1..100, 0 = niet in de kerker
var dungeon100_floor: int = 0
## run-seed van de generator (0 = nog niet gekozen; de eerste keer binnenkomen kiest hem)
var dungeon100_seed: int = 0
## laatst geactiveerd rustpunt (0, 10, ... 100) en hoogste bereikte verdieping
var dungeon100_checkpoint := 0
var dungeon100_best := 0
## Open warpers van deze run (verdiepingen 1, 25, 50, 75, 99). Mee in het dungeon100-blok van de save.
var dungeon100_warpers: Array[int] = []
## HET GESIMULEERDE ARCHIEF (Blauwe Kisten, zie HANDOFF_DUNGEON100_BLUECHEST.md):
## PERMANENTE items uit Blauwe Kisten (id -> aantal): overleven de dood en elke nieuwe run.
var dungeon100_permanent := {}
## hoeveel van elk permanent item al in de echte tas is gelegd (door een geslaagde Warp)
var dungeon100_delivered := {}
## Momentopname van de echte party/tas/goud/Codex tijdens een run ({} = geen run bezig). Tijdens een run
## zijn party/inventory/gold/codex_pages die van de SIMULATIE (level 1, geen uitrusting).
var dungeon100_snapshot := {}
## DE KOOPMAN (H-5, CANON §12, scripts/data/koopman_data.gd): aantal bezoeken (blijft over runs en
## nederlagen heen), sleutel van het laatst getelde bezoek ("<seed>_<verdieping>") en of de speler
## "H-5's Token" heeft. In de save als blok "koopman".
var koopman_bezoeken := 0
var koopman_laatste := ""
var koopman_token := false
## Unieke stukken (uitrusting, rotatie-item) die dit bezoek al gekocht zijn; leeg bij een nieuw bezoek/nieuwe run.
var koopman_gekocht: Array = []
## v0.11 verhaal: stap (zie scripts/data/story_data.gd) en flags (naam -> true)
var story_step := 0
var story_flags := {}
## v0.22 Veldmenu > Scenes: ids van bekeken cutscenes (scripts/data/scenes_data.gd). Gaat mee in de save
## als "scenes_seen"; oude saves worden gemigreerd via de vlaggen die de cutscenes zelf zetten.
var scenes_seen: Array = []
## Gehoorde Suno-tracks (scripts/data/music_tracks.gd ids) voor Menu > Scenes > Music. In de save.
var heard_music: Array = []
const MusicTracks := preload("res://scripts/data/music_tracks.gd")
## v0.25 Quest Log (scripts/data/quest_data.gd, res://data/quests.json): voortgang per opdracht
## ({quest_id: {"steps": [...], "done": bool}}). In de save als "quests"; oude saves zonder dat veld
## worden aangevuld uit de vlaggen en de verhaalstap. Stappen met een event worden klaar via
## Story.event_finished (quest_event).
var quest_progress := {}
const QuestData := preload("res://scripts/data/quest_data.gd")
## v0.11: opties voor het volgende gevecht als het een oefengevecht is ({} = gewoon)
var pending_tutorial := {}

var party: Array = []          # Array van Dictionaries (kopie van GameData.HEROES)
## Rustkamer: helden die niet meevechten. Gaat mee in de save als "party_bank".
var party_bench: Array = []
## Paden van kaarten waar de speler geweest is (warp-filter). "bezocht" in de save.
var bezochte_kaarten: Array[String] = []
## Voltooide Diepe-Grot-runs (ECHO's kisten lichten één voor één op).
var echo_grot_voltooid := 0
var inventory := {}            # item-id -> aantal
var gold := 0
## SoM-proef (scripts/data/som_data.gd): realtime gevecht in de SoM-kamers. Alleen aan via de knop
## "SoM" op het titelscherm; niet in de save, uit bij elk nieuw/geladen spel.
var som_mode := false

## Vermenigvuldiger voor alle encounter-kansen (1.0 = normaal, 0 = uit).
## Handig om te testen; de kansen zelf staan per terrein in game_data.gd.
var encounter_multiplier := 1.0
var steps_until_encounter_possible: int = GameData.SAFE_STEPS

## Huidige map (pad naar de .tscn) en het spawnpunt voor de volgende map.
var current_map := ""
var pending_spawn := ""
## Laatste warp-bron (pad naar .tscn), gezet in change_map vóór de scènewissel.
var warp_from_map := ""
var changing_map := false
## true zolang een --...test-suite draait (zie _zet_testmodus).
var test_modus := false
## #166: waar kwam je het huis van Dax binnen? "dorp" = via DORP_MAP; "" = al het andere
## (intro, nieuw spel, wilgendal.tscn, oude save zonder sleutel) -> uitgang zoals vroeger.
var huis_herkomst := ""

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
## True als het gevecht uit een kamer van het Eerste Archief komt (niet het woud, niet de Diepe Grot).
var pending_archief := false
## Trainingshal: oefengevecht zonder buit. Verlies is geen game-over.
var practice_battle := false

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
	_koppel_muziek.call_deferred()
	_koppel_quests.call_deferred()
	ui_theme = load("res://assets/theme.tres")
	preload("res://scripts/ui/ui_style.gd").apply_to_theme(ui_theme)
	_ensure_input_actions()
	new_game()
	_plan_preload()
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
	# Catalogus t/m Act 6: of  godot -- --catalogustest  (scripts/tests/catalogus_tests.gd).
	# Updates 1-4: of  godot -- --updatetest  (scripts/tests/todo_update_tests.gd).
	# World Warper-kamers: of  godot -- --warperkamertest  (scripts/tests/warper_kamer_tests.gd).
	# Hanger-scène: of  godot -- --hangertest  (scripts/tests/hanger_tests.gd).
	# De Koopman (H-5) + grotkamers: of  godot -- --koopmantest [--shots=/pad/map]  (scripts/tests/koopman_tests.gd).
	# De Spiegel (Archief 4): of  godot -- --spiegeltest [--shots=/pad/map]
	# Vriendenmodus: of  godot -- --pvptest  (pvp/tests/pvp_tests.gd).
	# Debug-ingang (geen test, geen verhaalvlag): godot -- --spiegel
	# Berggrot: of  godot -- --berggrottest [--shots=/pad/map]
	# Kas-poort wereldkaart (Vesper + Golem): godot -- --kasdeurtest  (scripts/tests/kas_deur_tests.gd).
	# Actie-balans (SoM-proef): godot -- --actionsim [--fights=N] [--boss-fights=N] [--out=pad]  (tools/battlesim/action_sim.gd)
	# UI-polijst WM1 (touch, veilig gebied, leesbaarheid): of  godot -- --uipolishtest [--shots=/pad/map]  (scripts/tests/ui_polish_tests.gd).
	# Screenshots van alle WM1-schermen per aspectprofiel (geen test): godot -- --uishots --shots=/pad/map  (tools/ui_polish).
	# Balans: of  godot -- --battlesim [--seed=N] [--fights=N] [--only=a,b] [--out=pad]  (tools/battlesim, geen test)
	# Balans per run (CSV in user://sim/): godot -- --battlesim --party=dennis:5 --enemy=all --runs=N --seed=S --policy=simpel
	# WM1-bugjacht: of  godot -- --wm1bugtest [--shots=/pad/map]  (scripts/tests/wm1_bugjacht_tests.gd).
	# WM1-bugjacht open O-2/O-3 (standalone): of  godot -- --wm1openbugtest  (scripts/tests/wm1_bugjacht_open_tests.gd).
	# WM1-balansrapport (alle encounters/bazen, EXP/goud-curve): godot -- --wm1balans [--fights=N] [--out=pad]  (tools/battlesim/wm1_balans.gd);
	# de bijbehorende suite: godot -- --wm1balanstest  (scripts/tests/wm1_balans_tests.gd)
	# Battle simulator CSV-modus: of  godot -- --battlesimtest  (scripts/tests/battlesim_tests.gd).
	# WM1-playthrough (nieuw spel t/m de hub, save/load, pauze): of  godot -- --wm1playthroughtest [--speed=N] [--static-only]  (scripts/tests/wm1_playthrough_tests.gd).
	# Profiel WM1 (laadtijd, frametijd, draw calls, nodes, textuurgeheugen): of  godot -- --perftest  (scripts/tests/perf_wm1.gd).
	# WM1 frametime-log + budget: of  godot -- --wm1frametest / --wm1budgettest  (scripts/tests/wm1_frametime_tests.gd, wm1_budget_tests.gd).
	# Action doel-lock: of  godot -- --locktest [--shots=/pad/map]  (scripts/tests/lock_tests.gd).
	# SoM slag vs lock: of  godot -- --swinglocktest  (scripts/tests/swing_lock_tests.gd).
	# Action-HUD overal (joystick + rij, geen D-pad): of  godot -- --hudtest [--shots=/pad/map]
	# Wilgendal-panden: of  godot -- --wilgendaltest  (scripts/tests/wilgendal_tests.gd).
	# Quest Log + ECHO per act: of  godot -- --questtest [--shots=/pad/map]  (scripts/tests/quest_tests.gd).
	# ECHO questlog (smoke): of  godot -- --echotest [--shots=/pad/map]  (scripts/tests/echo_tests.gd).
	# SoM MAP_CAST na late join: of  godot -- --castjointest  (scripts/tests/cast_join_tests.gd).
	# Sessielog (SessieLog, scripts/core/sessie_log.gd): of  godot -- --sessielogcoretest  (scripts/tests/sessielog_core_tests.gd).
	# Tutorial na de Inktwurm: of  godot -- --tutorialtest [--shots=/pad/map]  (scripts/tests/tutorial_tests.gd).
	# UX-polish WM1 (tikdoelen 48dp, Engelse tekst, tutorials, 19,5:9/20:9 + notch, SFX, volume): of
	#   godot -- --uxtest [--shots=/pad/map]  (scripts/tests/ux_tests.gd).
	# Fase B-lobby (geen gameplay): of  godot -- --nettest  (scripts/tests/net_tests.gd).
	# Action-co-op sync: of  godot -- --netsynctest  (scripts/tests/net_sync_tests.gd).
	# Co-op integratie (lobby+sandbox): of  godot -- --coope2etest  (scripts/tests/coop_e2e_tests.gd).
	# Seeded gevecht-RNG (zelfde seed = zelfde gevecht): of  godot -- --combatrngtest  (scripts/tests/combat_rng_tests.gd).
	# Vaste 60 Hz-gevechtsstap (framerate-onafhankelijk): of  godot -- --combattick  (scripts/tests/combat_tick_tests.gd).
	# Pure gevechtskern + beweging/treffers/lock op de stap: of  godot -- --combatsimtest  (scripts/tests/combat_sim_tests.gd).
	# Telegraafvormen (pure klasse, Combat T1): of  godot -- --telegraphtest  (scripts/tests/telegraph_tests.gd).
	# Co-op telegraaf-snapshot (Combat T5): of  godot -- --telegraphcooptest  (scripts/tests/telegraph_coop_sync_tests.gd).
	# Grondzones / Inktplas (Combat T4b): of  godot -- --zonetest  (scripts/tests/zone_tests.gd).
	# Wortelgreep-status (Combat T6): of  godot -- --roottest  (scripts/tests/root_tests.gd).
	# Actieve dodge + stamina (Combat D5): of  godot -- --dodgetest  (scripts/tests/dodge_tests.gd).
	# 3-slag aanvalsketen (Combat T15): of  godot -- --chaintest  (scripts/tests/chain_tests.gd).
	# Opgeladen zware slag (Action): of  godot -- --chargetest  (scripts/tests/charge_tests.gd).
	# Online co-op via de relay (start de Node-relay lokaal, 4 spelers): of  godot -- --relaytest  (scripts/tests/relay_tests.gd).
	# Play Store-release (versiebron, AAB-preset, bump_version, build-script): of  godot -- --aabtest  (scripts/tests/aab_tests.gd).
	# Debug-ingang zonder wereldkaart: godot -- --berggrot  (roept BerggrotData.start() aan)
	# Geen van de testers zit in de export, dus in de APK onbereikbaar.
	# Laadtijden WM1 (voorladen, save laden, dorp-grond): of  godot -- --perfwm1test  (scripts/tests/perf_wm1_tests.gd).
	# De tijden zelf meet tools/perf/run_perf_wm1.sh (losse scène, geen dispatch hier).
	var args := OS.get_cmdline_user_args()
	for t in [["--autotest", "res://scripts/debug_autotest.gd", "AutoTest", "autotest"],
			["--menutest", "res://scripts/debug_menutest.gd", "MenuTest", "autotest"],
			["--hudtest", "res://scripts/tests/hud_tests.gd", "HudTest", "hudtest"],
			["--locktest", "res://scripts/tests/lock_tests.gd", "LockTest", "locktest"],
			["--swinglocktest", "res://scripts/tests/swing_lock_tests.gd", "SwingLockTest", "swinglocktest"],
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
			["--grotlayouttest", "res://scripts/tests/grot_layout_tests.gd", "GrotLayoutTest", "grotlayouttest"],
			["--actorsfxtest", "res://scripts/tests/actor_sfx_tests.gd", "ActorSfxTest", "actorsfxtest"],
			["--catalogustest", "res://scripts/tests/catalogus_tests.gd", "CatalogusTest", "catalogustest"],
			["--updatetest", "res://scripts/tests/todo_update_tests.gd", "UpdateTest", "updatetest"],
			["--archief2test", "res://scripts/tests/archief2_tests.gd", "Archief2Test", "archief2test"],
			["--warperkamertest", "res://scripts/tests/warper_kamer_tests.gd", "WarperKamerTest", "warperkamertest"],
			["--hangertest", "res://scripts/tests/hanger_tests.gd", "HangerTest", "hangertest"],
			["--koopmantest", "res://scripts/tests/koopman_tests.gd", "KoopmanTest", "koopmantest"],
			["--spiegeltest", "res://scripts/tests/spiegel_tests.gd", "SpiegelTest", "spiegeltest"],
			["--berggrottest", "res://scripts/tests/berggrot_tests.gd", "BerggrotTest", "berggrottest"],
			["--testmodustest", "res://scripts/tests/testmodus_tests.gd", "TestmodusTest", "testmodustest"],
			["--kasdeurtest", "res://scripts/tests/kas_deur_tests.gd", "KasDeurTest", "kasdeurtest"],
			["--berggrotdextest", "res://scripts/tests/berggrot_dex_tests.gd", "BerggrotDexTest", "berggrotdextest"],
			["--wilgendaltest", "res://scripts/tests/wilgendal_tests.gd", "WilgendalTest", "wilgendaltest"],
			["--cutscenetest", "res://scripts/tests/worldmap_cutscene_tests.gd", "CutsceneTest", "cutscenetest"],
			["--pvptest", "res://pvp/tests/pvp_tests.gd", "PvpTest", "pvptest"],
			["--partytest", "res://scripts/tests/party_tests.gd", "PartyTest", "partytest"],
			["--savetest", "res://scripts/tests/save_tests.gd", "SaveTest", "savetest"],
			["--savehardeningtest", "res://scripts/tests/save_hardening_tests.gd", "SaveHardeningTest", "savehardeningtest"],
			["--saveroundtriptest", "res://scripts/tests/save_roundtrip_tests.gd", "SaveRoundtripTest", "saveroundtriptest"],
			["--sessielogtest", "res://scripts/tests/sessielog_tests.gd", "SessielogTest", "sessielogtest"],
			["--sessielogcoretest", "res://scripts/tests/sessielog_core_tests.gd", "SessielogCoreTest", "sessielogcoretest"],
			["--somroomstest", "res://scripts/tests/som_rooms_tests.gd", "SomRoomsTest", "somroomstest"],
			["--musictest", "res://scripts/tests/music_tests.gd", "MusicTest", "musictest"],
			["--muziektest", "res://scripts/tests/muziek_tests.gd", "MuziekTest", "muziektest"],
			["--held24test", "res://scripts/tests/held24_tests.gd", "Held24Test", "held24test"],
			["--sessiefixtest", "res://scripts/tests/sessiefix_tests.gd", "SessiefixTest", "sessiefixtest"],
			["--rekruuttest", "res://scripts/tests/rekruut_tests.gd", "RekruutTest", "rekruuttest"],
			["--balansarchief1test", "res://scripts/tests/balans_archief1_tests.gd", "BalansArchief1Test", "balansarchief1test"],
			["--questtest", "res://scripts/tests/quest_tests.gd", "QuestTest", "questtest"],
			["--echotest", "res://scripts/tests/echo_tests.gd", "EchoTest", "echotest"],
			["--castjointest", "res://scripts/tests/cast_join_tests.gd", "CastJoinTest", "castjointest"],
			["--tutorialtest", "res://scripts/tests/tutorial_tests.gd", "TutorialTest", "tutorialtest"],
			["--uxtest", "res://scripts/tests/ux_tests.gd", "UxTest", "uxtest"],
			["--nettest", "res://scripts/tests/net_tests.gd", "NetTest", "nettest"],
			["--netsynctest", "res://scripts/tests/net_sync_tests.gd", "NetSyncTest", "netsynctest"],
			["--coope2etest", "res://scripts/tests/coop_e2e_tests.gd", "CoopE2eTest", "coope2etest"],
			["--coophosttest", "res://scripts/tests/coop_host_tests.gd", "CoopHostTest", "coophosttest"],
			["--coopguestsavetest", "res://scripts/tests/coop_guest_save_tests.gd", "CoopGuestSaveTest", "coopguestsavetest"],
			["--combatrngtest", "res://scripts/tests/combat_rng_tests.gd", "CombatRngTest", "combatrngtest"],
			["--combattick", "res://scripts/tests/combat_tick_tests.gd", "CombatTickTest", "combattick"],
			["--combatsimtest", "res://scripts/tests/combat_sim_tests.gd", "CombatSimTest", "combatsimtest"],
			["--telegraphtest", "res://scripts/tests/telegraph_tests.gd", "TelegraphTest", "telegraphtest"],
			["--telegraphcooptest", "res://scripts/tests/telegraph_coop_sync_tests.gd", "TelegraphCoopSyncTest", "telegraphcooptest"],
			["--zonetest", "res://scripts/tests/zone_tests.gd", "ZoneTest", "zonetest"],
			["--roottest", "res://scripts/tests/root_tests.gd", "RootTest", "roottest"],
			["--dodgetest", "res://scripts/tests/dodge_tests.gd", "DodgeTest", "dodgetest"],
			["--chaintest", "res://scripts/tests/chain_tests.gd", "ChainTest", "chaintest"],
			["--chargetest", "res://scripts/tests/charge_tests.gd", "ChargeTest", "chargetest"],
			["--relaytest", "res://scripts/tests/relay_tests.gd", "RelayTest", "relaytest"],
			["--battlesimtest", "res://scripts/tests/battlesim_tests.gd", "BattlesimTest", "battlesimtest"],
			["--wm1balanstest", "res://scripts/tests/wm1_balans_tests.gd", "Wm1BalansTest", "wm1balanstest"],
			["--wm1playthroughtest", "res://scripts/tests/wm1_playthrough_tests.gd", "Wm1PlaythroughTest", "wm1playthroughtest"],
			["--perftest", "res://scripts/tests/perf_wm1.gd", "PerfWm1", "perftest"],
			["--wm1frametest", "res://scripts/tests/wm1_frametime_tests.gd", "Wm1FrametimeTest", "wm1frametest"],
			["--wm1budgettest", "res://scripts/tests/wm1_budget_tests.gd", "Wm1BudgetTest", "wm1budgettest"],
			["--huisdrawtest", "res://scripts/tests/huis_draw_calls_tests.gd", "HuisDrawCallsTest", "huisdrawtest"],
			["--huispixeltest", "res://scripts/tests/huis_pixel_tests.gd", "HuisPixelTest", "huispixeltest"],
			["--uipolishtest", "res://scripts/tests/ui_polish_tests.gd", "UiPolishTest", "uipolishtest"],
			["--uishots", "res://tools/ui_polish/ui_shots.gd", "UiShots", "uishots"],
			["--wm1bugtest", "res://scripts/tests/wm1_bugjacht_tests.gd", "Wm1BugTest", "wm1bugtest"],
			["--wm1openbugtest", "res://scripts/tests/wm1_bugjacht_open_tests.gd", "Wm1OpenBugTest", "wm1openbugtest"],
			["--wm1releasetest", "res://scripts/tests/wm1_release_tests.gd", "Wm1ReleaseTest", "wm1releasetest"],
			["--aabtest", "res://scripts/tests/aab_tests.gd", "AabTest", "aabtest"],
			["--playtestkittest", "res://scripts/tests/playtest_kit_tests.gd", "PlaytestKitTest", "playtestkittest"],
			["--lifecycletest", "res://scripts/tests/lifecycle_tests.gd", "LifecycleTest", "lifecycletest"],
			["--battlesim", "res://tools/battlesim/battlesim.gd", "BattleSim", "battlesim"],
			["--actionsim", "res://tools/battlesim/action_sim.gd", "ActionSim", "actionsim"],
			["--archief1balans", "res://tools/battlesim/archief1_balans.gd", "Archief1Balans", "archief1balans"],
			["--perfwm1test", "res://scripts/tests/perf_wm1_tests.gd", "PerfWm1Test", "perfwm1test"],
			["--wm1balans", "res://tools/battlesim/wm1_balans.gd", "Wm1Balans", "wm1balans"]]:
		if not (t[0] in args) or not ResourceLoader.exists(t[1]):
			continue
		if str(t[3]).ends_with("test"):
			_zet_testmodus(str(t[3]))
		# eigen bestanden: de tests raken je echte save/autosave niet
		save_path = "user://%s_save_1.json" % t[3]
		autosave_path = "user://%s_autosave.json" % t[3]
		for s in range(1, SLOT_COUNT + 1):
			var sp := slot_path(s)
			if sp != "" and FileAccess.file_exists(sp):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))
		if FileAccess.file_exists(autosave_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(autosave_path))
		_finish_preload()   # tests: achtergrond-laden eerst afmaken (geen race/deadlock met load() in de suite)
		var tester: Node = load(t[1]).new()
		tester.name = t[2]
		get_tree().root.add_child.call_deferred(tester)
		break
	# De Spiegel (Archief 4): debug-ingang. Start alleen de kamer.
	# Geen story_step en geen story_flags: het echte verhaal wordt niet overgeslagen.
	if SpiegelData.DEBUG_ARG in args and not ("--spiegeltest" in args):
		call_deferred("_go_to_scene", SpiegelData.SCENE)
	# Berggrot, zonder wereldkaart. Zelfde haakje als de mond op de kaart.
	if BerggrotData.DEBUG_ARG in args and not ("--berggrottest" in args):
		call_deferred("_start_berggrot")
	_story_save_path = save_path
	_story_autosave_path = autosave_path


## Testmodus (alleen bij een --...test-suite; O-4, flaky berggrottest onder load):
## - test_modus laat toevalsbronnen die alleen beeld sturen (World Warper-flyover) een vaste seed
##   gebruiken, zodat een suite niet van de klok afhangt.
## - PHYSICS_GELIJK_SUITES: extra net naast walk() die op process_frame wacht. Physics mag nooit
##   sneller lopen dan beelden. Niet voor alle suites: menutest en woudtest hangen af van physics
##   op wandkloktijd en gaan juist stuk als physics onder load langzamer loopt.
##   dungeon100gentest: walk() wacht max. 6 physics_frames (zie docs/qa/DIAG_dungeon100.md).
const PHYSICS_GELIJK_SUITES: Array[String] = ["berggrottest", "dungeon100gentest"]


func _zet_testmodus(suite: String) -> void:
	test_modus = true
	if suite in PHYSICS_GELIJK_SUITES:
		Engine.max_physics_steps_per_frame = 1


## Debug-ingang van de berggrot. Zelfde haakje als de mond op de kaart.
func _start_berggrot() -> void:
	BerggrotData.start()


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
	for id in GameData.BACKDROPS_BOOT:
		out.append(GameData.backdrop_path(str(id)))
	# alleen de gevechtssprites (2100x210, 1,7 MB per stuk) van de party; rekruten laden bij hun eerste gevecht
	for h in party + party_bench:
		if str(h.get("battle_sprite", "")) != "":
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
	"res://scripts/battle/battle.gd", "res://scripts/story_object.gd",
	"res://world_warper/art/flyover.gd"]   # preload()t een textuur: nooit in de laad-thread compileren


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


## Vraagt een resource op de achtergrond te laden zonder te wachten (get_resource() levert hem later).
func _vraag_voor(path: String) -> void:
	if path == "" or _loaded.has(path) or _preloading.has(path) or not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_preloading.append(path)
		set_process(true)


## Gevechtsachtergrond die niet bij het opstarten is geladen: op de achtergrond laden terwijl de
## gevechtsflits loopt, en de vorige "late" achtergrond weer loslaten (er staat er hooguit één in het geheugen).
func _prefetch_backdrop(path: String) -> void:
	if path == "":
		return
	for id in GameData.BACKDROPS:
		var p := str(GameData.BACKDROPS[id])
		if p != path and not (id in GameData.BACKDROPS_BOOT):
			_loaded.erase(p)
	if _loaded.has(path) or _preloading.has(path) or not ResourceLoader.exists(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_preloading.append(path)
		set_process(true)


## Kijkt elk frame (alleen zolang er nog iets laadt) of er iets klaar is.
func _process(_delta: float) -> void:
	if _preload_phase < 2 and not _fase_voorladen():
		return
	for i in range(_preloading.size() - 1, -1, -1):
		var p := _preloading[i]
		var status := ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[p] = ResourceLoader.load_threaded_get(p)
			_preloading.remove_at(i)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_preloading.remove_at(i)
	_prewarm_step(get_process_delta_time())
	if _preloading.is_empty() and _prewarm_queue.is_empty():
		set_process(false)


## Wacht tot alle achtergrond-loads klaar zijn (alleen voor de testmodi).
func _finish_preload() -> void:
	_prewarm_queue.clear()      # geen prewarm in de tests
	_script_queue.clear()
	if _preload_phase < 2:
		_preload_phase = 2
		_start_preload()
	for p in _preloading.duplicate():
		var r := ResourceLoader.load_threaded_get(p)
		if r != null:
			_loaded[p] = r
	_preloading.clear()
	set_process(false)


## Opstart-voorladen in fasen (prestaties; _plan_preload() vanuit _ready, _fase_voorladen() vanuit _process):
##  fase 0: het eerste beeld (titelscherm) laten tekenen,
##  fase 1: de scripts uit MAIN_THREAD_SCRIPTS op de hoofdthread compileren, één per frame (samen ~0,4 s),
##  fase 2: _start_preload() (de achtergrond-loads aanvragen; de scripts staan dan in de cache) en afwachten.
## Daarna, alleen in rustige schermen (titel / naam invoeren): PREWARM_SCRIPTS compileren, zodat het eerste dorp /
## woud / archief / veldmenu niet 0,1-0,3 s stilstaat op het moment van gebruik. Wie eerder iets nodig heeft laadt
## gewoon synchroon (get_resource / load): zelfde resultaat, alleen later gecompileerd.
const FRAMES_BEFORE_PRELOAD := 2
const PREWARM_GAP := 0.05
const PREWARM_SCENES: Array[String] = [TITLE_SCENE, NAME_SCENE]
## Zware scripts die WM1 bij de eerste binnenkomst / het eerste gebruik compileert (gemeten onder xvfb, Godot 4.3:
## field_menu.gd ~210 ms, dungeon_room.gd ~260 ms, puzzle_room.gd ~140 ms, archief2_room.gd ~100 ms, dorp ~80 ms,
## pand_binnen.gd ~65 ms, kern_kracht_veld.gd ~40 ms, kern_absorption.gd ~35 ms). Volgorde = waarschijnlijke
## speelvolgorde; scripts die een ander script preloadt staan er vóór, zodat elke stap klein blijft
## (de titel hapert dan hooguit ~110 ms per stap i.p.v. ~270 ms in één keer).
const PREWARM_SCRIPTS: Array[String] = ["res://scripts/kern/kern_kracht_veld.gd",
	"res://scripts/village/pand_binnen.gd", "res://scripts/village/dorp_ground.gd",
	"res://scripts/village/dorp_opbouw.gd", "res://scripts/village/molen_wieken.gd",
	"res://scripts/ui/codex_screen.gd", "res://scripts/ui/equipment_screen.gd",
	"res://scripts/ui/status_screen.gd", "res://scripts/ui/items_screen.gd",
	"res://scripts/ui/magic_screen.gd", "res://scripts/ui/party_screen.gd",
	"res://scripts/ui/bestiary_screen.gd", "res://scripts/ui/field_menu.gd",
	"res://scripts/som/som_codex.gd", "res://scripts/som/som_ally.gd", "res://scripts/som/som_hud.gd",
	"res://scripts/som/som_ring.gd", "res://scripts/som/som_arena.gd", "res://scripts/dungeon/map_monster.gd",
	"res://scripts/dungeon/dungeon_chest.gd", "res://scripts/dungeon/dungeon_room.gd",
	"res://scripts/dungeon/archief2_room.gd", "res://scripts/puzzle/puzzle_room.gd",
	"res://scripts/kern/kern_absorption.gd"]
var _preload_phase := 0            # 0 = wacht op het eerste beeld, 1 = scripts, 2 = loads lopen / prewarm
var _preload_frames := 0
var _script_queue: Array[String] = []
var _prewarm_queue: Array[String] = []
var _prewarm_wait := 0.0


func _plan_preload() -> void:
	_script_queue.assign(MAIN_THREAD_SCRIPTS)
	_prewarm_queue.assign(PREWARM_SCRIPTS)
	set_process(true)


## Fase 0 en 1. true = fase 2 bereikt (en _process mag doorgaan met het poll-werk).
func _fase_voorladen() -> bool:
	if _preload_phase == 0:
		_preload_frames += 1
		if _preload_frames < FRAMES_BEFORE_PRELOAD:
			return false
		_preload_phase = 1
	if not _script_queue.is_empty():
		var sp: String = _script_queue.pop_front()
		if ResourceLoader.exists(sp):
			load(sp)
		return false
	_preload_phase = 2
	_start_preload()
	set_process(true)      # _start_preload zet het uit als er niets laadt; prewarm moet nog
	return true


## Eén zwaar script per PREWARM_GAP seconden, alleen als de speler niets aan het doen is (titelscherm).
func _prewarm_step(delta: float) -> void:
	if _prewarm_queue.is_empty() or not _preloading.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null or not (scene.scene_file_path in PREWARM_SCENES) or changing_map or in_battle:
		return
	_prewarm_wait -= delta
	if _prewarm_wait > 0.0:
		return
	_prewarm_wait = PREWARM_GAP
	var sp: String = _prewarm_queue.pop_front()
	if ResourceLoader.exists(sp) and not _loaded.has(sp):
		_loaded[sp] = load(sp)


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


## #166: kies de echte bestemming van een warp en onthoud de herkomst bij het binnengaan van het huis.
func huis_route(van: String, path: String, spawn_name: String) -> Array:
	if path == HOUSE_MAP and van != HOUSE_MAP:
		huis_herkomst = "dorp" if van == DORP_MAP else ""
	elif van == HOUSE_MAP and path == TOWN_MAP and spawn_name == "voor_huis" and huis_herkomst == "dorp":
		return [DORP_MAP, DORP_HUIS_SPAWN]
	return [path, spawn_name]


## Nieuw spel (v0.10): de party is alleen de hoofdpersoon (held 'dennis') met
## de gekozen naam. Noor en Lotte komen later via add_member("noor") / add_member("lotte").
func new_game(hero_name := DEFAULT_NAME) -> void:
	huis_herkomst = ""
	som_mode = false
	leader_id = MAIN_HERO
	player_name = clean_name(hero_name)
	party.clear()
	party_bench = []
	bezochte_kaarten = []
	echo_grot_voltooid = 0
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
	scenes_seen = []
	heard_music = []
	quest_progress = {}
	_hoor_huidige_muziek()     # bv. de titelmuziek die nu speelt
	archief2 = {"platen": {}}
	archief2_temp_ally = {}
	archief2_party_filter = ""
	pending_story_loss = false
	archief2_lotte_join = false
	archief2_last_open = {}
	archief2_last_leech = {}
	pending_tutorial = {}
	dungeon100_load({})
	koopman_load({})
	if has_node("/root/Story"):
		get_node("/root/Story").reset()
	has_return_point = false
	pending_spawn = ""
	_play_time_base = 0.0
	_clock_start_ms = Time.get_ticks_msec()
	active_slot = clampi(pending_new_slot, 1, SLOT_COUNT)


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
	# v0.22 partylimiet: is de groep vol, dan gaat de nieuwe held naar de reserve
	if party.size() > PartyLimiet.MAX_HELDEN and PartyLimiet.mag_naar_reserve(h):
		party.pop_back()
		party_bench.append(h)
	_som_party_hero_joined(id)
	return true


## Action-arena op de huidige map: cast-sheets (en bondgenoot) bij latere party-leden.
func _som_party_hero_joined(id: String) -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null or not ("som" in scene):
		return
	var som: Node = scene.som
	if som != null and som.has_method("join_party_hero"):
		som.join_party_hero(id)


## v0.22 Is cutscene 'id' al bekeken? (eigen lijst, of de vlag die de cutscene zelf zet)
## Muziek-tab: elke track die in het spel start (AudioManager.music_started) telt als gehoord.
func _koppel_muziek() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_signal("music_started") and not am.music_started.is_connected(hoor_muziek):
		am.music_started.connect(hoor_muziek)


func _koppel_quests() -> void:
	var st := get_node_or_null("/root/Story")
	if st != null and st.has_signal("event_finished") and not st.event_finished.is_connected(quest_event):
		st.event_finished.connect(quest_event)


## Story heeft een event afgerond: stappen met dat event worden klaar (en alles wat de vlaggen nu zeggen).
func quest_event(event_id: String) -> void:
	QuestData.on_event(quest_progress, event_id, story_flags, story_step)


## Legt vast wat volgens de vlaggen/verhaalstap klaar is (bv. een baas uit een gevecht).
func quest_sync() -> void:
	QuestData.sync(quest_progress, story_flags, story_step)


func hoor_muziek(manifest_id: String) -> void:
	var tid := MusicTracks.track_for(manifest_id)
	if tid != "" and not heard_music.has(tid):
		heard_music.append(tid)


func _hoor_huidige_muziek() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("get_current_music"):
		hoor_muziek(str(am.get_current_music()))


func scene_seen(id: String) -> bool:
	if scenes_seen.has(id):
		return true
	var sc: Dictionary = ScenesData.scene(id)
	return not sc.is_empty() and story_flags.has(str(sc.get("flag", "")))


func mark_scene_seen(id: String) -> void:
	if not ScenesData.scene(id).is_empty() and not scenes_seen.has(id):
		scenes_seen.append(id)


## Alle bekeken cutscenes, in de volgorde van ScenesData.SCENES (ook gemigreerd via vlaggen).
func seen_scenes() -> Array:
	return ScenesData.ids().filter(func(i): return scene_seen(str(i)))


## v0.22 Held uit de groep of de reserve ({} = zit er niet in).
func member(id: String) -> Dictionary:
	for h in party + party_bench:
		if str(h.get("id", "")) == id:
			return h
	return {}


## v0.17 Held sluit zich aan (story-commando "join", bv. Noor na het Donker Woud): op niveau
## 'level' (EXP via give_exp, dus dezelfde groei als normaal), volle HP/MP, en de stukken in 'gear'
## gegeven en meteen gedragen. false = bestaat niet of zit er al in.
func join_member(id: String, level := 1, gear: Array = []) -> bool:
	if not add_member(id):
		return false
	var h: Dictionary = member(id)
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


## Archief 2: winst of verlies tegen Lotte wordt een verhaaleinde, geen game over.
## Vluchten telt niet. Geeft het resultaat terug dat end_battle verder gebruikt.
func archief2_verwerk_einde(result: String) -> String:
	if not pending_story_loss:
		return result
	if result == "win" or result == "lose":
		archief2_lotte_join = true
		if result == "lose":
			result = "story"
	pending_story_loss = false
	archief2_temp_ally = {}
	archief2_party_filter = ""
	return result


func archief2_plaat(room_id: String, plaat_id: String, fallback: int) -> int:
	var sleutel := "%s:%s" % [room_id, plaat_id]
	var platen: Dictionary = archief2.get("platen", {})
	if platen.has(sleutel):
		return int(platen[sleutel])
	return fallback


func archief2_zet_plaat(room_id: String, plaat_id: String, staat: int) -> void:
	if not (archief2.get("platen") is Dictionary):
		archief2["platen"] = {}
	archief2["platen"]["%s:%s" % [room_id, plaat_id]] = staat


## v0.17 Niveau van een held in de party (0 = zit er niet in).
func member_level(id: String) -> int:
	for h in party:
		if h.get("id", "") == id:
			return int(h.get("level", 1))
	for h in party_bench:
		if h.get("id", "") == id:
			return int(h.get("level", 1))
	return 0


func has_member(id: String) -> bool:
	if party.any(func(h): return h.get("id", "") == id):
		return true
	return party_bench.any(func(h): return h.get("id", "") == id)


## Zet een groepslid vooraan (molen: party wisselen). index 0 blijft staan.
func move_member_to_front(index: int) -> bool:
	if index < 0 or index >= party.size():
		return false
	if index == 0:
		return true
	var h: Dictionary = party[index]
	party.remove_at(index)
	party.insert(0, h)
	KaartStijl.ververs_held()   # 24x32-kaartsprite van de nieuwe leider
	return true


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
	if GameData.ENEMIES.has(id) or EndgameBestiary.has(id) or BerggrotData.has_enemy(id):
		_beast(id)["seen"] = true


func mark_defeated(id: String) -> void:
	unique_mark(id, "verslagen")      # v0.19: uniek monster verslagen = nooit meer
	if GameData.ENEMIES.has(id) or EndgameBestiary.has(id) or BerggrotData.has_enemy(id):
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
	return _save_file_exists(save_path)


## v0.11: is er een automatische save?
func has_autosave() -> bool:
	return _save_file_exists(autosave_path)


## v0.11: handmatige save óf autosave aanwezig (titelscherm: 'Doorgaan' aan).
## Elk van de vier slots telt, niet alleen slot 1.
func has_any_save() -> bool:
	return newest_save_path() != ""


## Pad van slot n. Slot 1 = save_path (migratie). Leeg = dit pad kent geen extra slots.
func slot_path(slot: int) -> String:
	if slot < 1 or slot > SLOT_COUNT:
		return ""
	if slot == 1:
		return save_path
	if not save_path.ends_with("save_1.json"):
		return ""
	return save_path.trim_suffix("save_1.json") + "save_%d.json" % slot


## Oude saves zonder sleutel "slot" horen bij slot 1.
func _slot_of_data(d: Dictionary) -> int:
	if not d.has("slot"):
		return 1
	var s = d["slot"]
	if not (s is int or s is float):
		return 1
	return clampi(int(s), 1, SLOT_COUNT)


## Nieuwste bestand van één slot: handmatig, of de autosave als die bij dit slot hoort en nieuwer is.
## {} = leeg. Even oud = de handmatige save.
func slot_record(slot: int) -> Dictionary:
	if slot == AUTOSAVE_SLOT:
		return autosave_record()
	var manual := slot_path(slot)
	if manual == "" or not _save_file_exists(manual):
		return {}
	var src := _read_save_source(manual)
	var d: Dictionary = src["data"]
	if d.is_empty():
		return {"path": manual, "data": {}, "stamp": _save_modified_time(manual),
				"slot": slot, "corrupt": true}
	return {"path": manual, "data": d, "stamp": _save_stamp(manual), "slot": slot,
			"from_backup": src["from_backup"]}


## De aparte autosave ({} = geen). Ook een oude autosave (v0.22, gestempeld met slot 1..4)
## komt hier: die wordt niet meer in een handmatig slot gemengd, maar gaat niet verloren.
func autosave_record() -> Dictionary:
	if not _save_file_exists(autosave_path):
		return {}
	var src := _read_save_source(autosave_path)
	var d: Dictionary = src["data"]
	if d.is_empty():
		return {"path": autosave_path, "data": {}, "stamp": _save_modified_time(autosave_path),
				"slot": AUTOSAVE_SLOT, "corrupt": true}
	return {"path": autosave_path, "data": d, "stamp": _save_stamp(autosave_path), "slot": AUTOSAVE_SLOT,
			"from_backup": src["from_backup"]}


## Bij welk handmatig slot hoort een autosave (voor het volgende handmatige opslaan)?
func home_slot_of(d: Dictionary) -> int:
	var h = d.get("home_slot", d.get("slot", 1))
	if not (h is int or h is float):
		return 1
	return clampi(int(h), 1, SLOT_COUNT)


## Overgang wereldkaart <-> kerker? Dan (en alleen dan) autosaven bij een mapwissel.
func is_dungeon_transition(from_map: String, to_map: String) -> bool:
	var from_world := from_map == WORLD_MAP
	var to_world := to_map == WORLD_MAP
	if from_world == to_world:
		return false
	var other := to_map if from_world else from_map
	if other == "":
		return false
	return not NON_DUNGEON_MAPS.has(other.get_file().get_basename())


func newest_slot_record() -> Dictionary:
	var best := {}
	var stamp := -1.0
	# handmatige slots eerst: bij gelijke stempel wint de handmatige save, niet de autosave
	# een onleesbaar slot (geen goede .bak) mag 'Doorgaan' niet blokkeren zolang er een goed slot is
	for pass_corrupt in [false, true]:
		for i in [1, 2, 3, 4, AUTOSAVE_SLOT]:
			var rec := slot_record(i)
			if rec.is_empty() or bool(rec.get("corrupt", false)) != pass_corrupt:
				continue
			if float(rec["stamp"]) > stamp:
				stamp = float(rec["stamp"])
				best = rec
		if not best.is_empty():
			break
	return best


## v0.11: pad van de NIEUWSTE save (handmatig of automatisch), over alle slots. "" = geen.
## Vergelijkt "saved_unix" in het bestand (oudere saves zonder dat veld: de
## wijzigingstijd van het bestand). Even oud = de handmatige save van dat slot,
## en bij een gelijke stempel tussen slots wint het lagere slotnummer.
func newest_save_path() -> String:
	return str(newest_slot_record().get("path", ""))


func _newest_of(manual: String, auto: String) -> String:
	var has_manual := _save_file_exists(manual)
	var has_auto := _save_file_exists(auto)
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
	playing_eind = false


func use_beta_saves() -> void:
	save_path = beta_save_path()
	autosave_path = beta_autosave_path()
	playing_beta = true
	playing_eind = false


func eind_save_path() -> String:
	return _story_save_path.replace("save_1.json", "save_eindstaat.json")


func eind_autosave_path() -> String:
	return _story_autosave_path.replace("autosave.json", "autosave_eindstaat.json")


func use_eind_saves() -> void:
	save_path = eind_save_path()
	autosave_path = eind_autosave_path()
	playing_beta = false
	playing_eind = true


func has_eind_save() -> bool:
	return _save_file_exists(eind_save_path()) or _save_file_exists(eind_autosave_path())


func newest_eind_path() -> String:
	return _newest_of(eind_save_path(), eind_autosave_path())


func read_eind_save() -> Dictionary:
	var p := newest_eind_path()
	return read_save(p) if p != "" else {}


func has_beta_save() -> bool:
	return _save_file_exists(beta_save_path()) or _save_file_exists(beta_autosave_path())


func newest_beta_path() -> String:
	return _newest_of(beta_save_path(), beta_autosave_path())


func read_beta_save() -> Dictionary:
	var p := newest_beta_path()
	return read_save(p) if p != "" else {}


func _save_stamp(path: String) -> float:
	return _stamp_of(read_save(path), path)


## Stempel van een al gelezen save (voorkomt een tweede JSON-parse van hetzelfde bestand).
func _stamp_of(d: Dictionary, path: String) -> float:
	if d.has("saved_unix"):
		return float(d["saved_unix"])
	return _save_modified_time(path)


func _save_modified_time(path: String) -> float:
	var actual := path if FileAccess.file_exists(path) else path + ".bak"
	return float(FileAccess.get_modified_time(actual)) if FileAccess.file_exists(actual) else 0.0


func _save_file_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## v0.11: inhoud van de nieuwste save ({} = geen), bv. voor het titelscherm.
func read_newest_save() -> Dictionary:
	var p := newest_save_path()
	return read_save(p) if p != "" else {}


## v0.11 Automatisch opslaan in autosave_path. De pauze-save ("achtergrond") gaat ook door
## als autosave uit staat; alle veiligheidsblokkades blijven gelden.
func autosave(tile: Vector2i, facing: Vector2i, reason := "") -> bool:
	if not AUTOSAVE_REASONS.has(reason):
		return false
	if not can_autosave(reason == "achtergrond"):
		return false
	if not save_game(tile, facing, autosave_path):
		return false
	last_autosave_reason = reason
	autosave_count += 1
	return true


func can_autosave(ignore_setting: bool = false) -> bool:
	if coop_is_guest():
		return false
	var settings := get_node_or_null("/root/Settings")
	if not ignore_setting and settings != null and not settings.autosave_enabled():
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
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if coop_is_host() and _coop_lobby != null:
			const Protocol := preload("res://scripts/net/net_protocol.gd")
			_coop_pending_message = coop_session_end_message(Protocol.SESSION_END_HOST_PAUSED)
			coop_end_session(Protocol.SESSION_END_HOST_PAUSED)
	if what == NOTIFICATION_APPLICATION_RESUMED:
		if _coop_pending_message != "":
			var pending := _coop_pending_message
			_coop_pending_message = ""
			go_to_title(true)
			Dialog.show_lines([pending])
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
	if coop_is_guest():
		return false
	if path == "":
		var slot_file := slot_path(active_slot)
		path = slot_file if slot_file != "" else save_path
	var data := state_data(tile, facing)
	data[CODEX_SYNC_KEY] = true
	data["game_version"] = str(ProjectSettings.get_setting("application/config/version", ""))
	data["saved_at"] = Time.get_datetime_string_from_system()
	data["saved_unix"] = Time.get_unix_time_from_system()
	data["autosave"] = path == autosave_path
	if path == autosave_path:
		data["slot"] = AUTOSAVE_SLOT
		data["home_slot"] = active_slot
	else:
		data["slot"] = _slot_for_path(path)
	# v0.19 kamer-checkpoint (met zijn eigen voortgangs-kopie) gaat mee; altijd de sleutel
	# ({} = nog geen), zodat handmatige save en autosave hetzelfde formaat houden
	data["checkpoint"] = checkpoint.duplicate(true)
	var text := JSON.stringify(data, "  ")
	var tmp := path + ".tmp"
	var saved := _write_save_atomic(path, tmp, text)
	game_saved.emit(path, saved)
	return saved


## Schrijft eerst een volledig .tmp-bestand (flush + close), controleert het en vervangt
## pas dan het doel via rename. De goede oude save blijft als .bak bewaard.
func _write_save_atomic(path: String, tmp: String, text: String) -> bool:
	_remove_file(tmp)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Opslaan mislukt: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		push_warning("Opslaan mislukt bij schrijven: %s" % error_string(write_error))
		_remove_file(tmp)
		return false
	if not _valid_save_data(_read_save_file(tmp)):
		push_warning("Opslaan mislukt: tijdelijk bestand is niet geldig")
		_remove_file(tmp)
		return false
	# Alleen een aantoonbaar goede hoofd-save wordt de reservekopie. Een corrupte
	# hoofd-save mag een bestaande goede .bak nooit verdringen.
	var old := _read_save_file(path)
	if _valid_save_data(old) and not _write_backup(path, path + ".bak"):
		_remove_file(tmp)
		return false
	var rename_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		push_warning("Opslaan mislukt bij vervangen: %s" % error_string(rename_error))
		_remove_file(tmp)
		return false
	return true


func _write_backup(source: String, backup: String) -> bool:
	var backup_tmp := backup + ".tmp"
	_remove_file(backup_tmp)
	var f := FileAccess.open(backup_tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Reservekopie mislukt: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(FileAccess.get_file_as_string(source))
	f.flush()
	var backup_error := f.get_error()
	f.close()
	if backup_error != OK:
		push_warning("Reservekopie mislukt bij schrijven: %s" % error_string(backup_error))
		_remove_file(backup_tmp)
		return false
	if not _valid_save_data(_read_save_file(backup_tmp)):
		push_warning("Reservekopie mislukt: tijdelijk bestand is niet geldig")
		_remove_file(backup_tmp)
		return false
	var rename_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_tmp), ProjectSettings.globalize_path(backup))
	if rename_error != OK:
		push_warning("Reservekopie mislukt bij vervangen: %s" % error_string(rename_error))
		_remove_file(backup_tmp)
		return false
	return true


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## De party als lijst van Dictionaries voor een save (en de Archief-momentopname).
func _party_save() -> Array:
	return _party_save_from(party)


func _party_save_from(groep: Array) -> Array:
	var out := []
	for h in groep:
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
		if h.get("name") is String:
			h["name"] = migrate_name(str(h["name"]))
		if e.has("spells") and e["spells"] is Array:
			h["spells"] = e["spells"].duplicate()
		# v0.14 uitrusting + basis-stats; oude saves zonder die sleutels krijgen
		# standaardwaarden (zie Equipment.load_hero). Ongeldige stukken -> terug in de tas.
		h["level"] = maxi(1, int(h.get("level", 1)))
		h["exp"] = maxi(0, int(h.get("exp", 0)))
		Equipment.load_hero(h, e, _hero_data(str(h["id"])), stray_equipment)
		h["max_hp"] = maxi(1, int(h["max_hp"]))
		h["max_mp"] = maxi(0, int(h["max_mp"]))
		h["hp"] = clampi(int(h["hp"]), 0, int(h["max_hp"]))
		h["mp"] = clampi(int(h["mp"]), 0, int(h["max_mp"]))
		out.append(h)
	return out


## v0.23 namen-migratie (besluit Dennis 13 okt 2026): oude saves bewaren de weergavenamen.
## Dennis -> Dax, Lotte -> Seren, Noor -> Vesper. Ids (dennis/lotte/noor) blijven gelijk.
const OUDE_NAMEN := {"Dennis": "Dax", "Lotte": "Seren", "Noor": "Vesper"}

static func migrate_name(n: String) -> String:
	return str(OUDE_NAMEN.get(n, n))


## Goud uit save-data: 0..MAX_GOLD (geen negatief of absurd getal).
static func _gold_from(v) -> int:
	if v is float or v is int:
		return int(clampf(float(v), 0.0, float(MAX_GOLD)))
	return 0


## Tas uit save-data: id -> aantal (kapotte waarden vallen weg).
static func _inventory_from(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if (raw[k] is float or raw[k] is int) and str(k) != "":
				# eerst als float begrenzen: int() van een absurd getal wordt anders negatief
				var n := int(clampf(float(raw[k]), 0.0, float(MAX_ITEM_STACK)))
				if n >= 1:
					out[k] = n
	return out


## v0.19: de voortgang als Dictionary (zelfde velden als een save, zonder checkpoint/tijdstempels).
## Gebruikt door save_game en door het kamer-checkpoint (set_checkpoint).
func state_data(tile: Vector2i, facing: Vector2i, map := "") -> Dictionary:
	var data := {
		"battle_style": int(Settings.get_value("battle_style")),   # 21 okt 2026: gevechtsstijl reist mee met de save
		"version": SAVE_VERSION,
		"map": map if map != "" else current_map,
		"tile": [tile.x, tile.y],
		"facing": [facing.x, facing.y],
		"player_name": player_name,
		"party": [],
		"party_bank": [],
		"bezocht": bezochte_kaarten.duplicate(),
		"echo_grot_voltooid": echo_grot_voltooid,
		"huis_herkomst": huis_herkomst,
		"inventory": inventory.duplicate(true),
		"gold": gold,
		"play_time": play_time(),
		"bestiary": bestiary.duplicate(true),
		"puzzle_latched": puzzle_latched.duplicate(true),
		"kernen": kernfragmenten.duplicate(true),
		"codex": codex_save_data(),
		"uniek": unique_done.duplicate(true),
		"dungeon100": Dungeon100RulesC.save_data(dungeon100_floor, dungeon100_checkpoint, dungeon100_best, dungeon100_seed,
				{"permanent": dungeon100_permanent, "delivered": dungeon100_delivered, "snapshot": dungeon100_snapshot,
				"warpers": dungeon100_warpers}),
		"story": {"step": story_step, "flags": story_flags.keys()},
		"pending_unique_event": Story.pending_unique_event if has_node("/root/Story") else "",
		"scenes_seen": seen_scenes(),
		"heard_music": heard_music.duplicate(),
		"quests": _quests_save(),
		"archief2": archief2.duplicate(true),
		"koopman": koopman_save_data(),
	}
	data["party"] = _party_save()
	data["party_bank"] = _party_save_from(party_bench)
	data["leader"] = leader_id
	return data


func _quests_save() -> Dictionary:
	quest_sync()
	return quest_progress.duplicate(true)


## Leest een save (standaard de handmatige; v0.11: of 'path', bv. autosave_path).
func read_save(path := "") -> Dictionary:
	return _read_save_source(path)["data"]


## Zoals read_save, maar ook waar de data vandaan kwam: {"data": {}, "from_backup": bool}.
func _read_save_source(path := "") -> Dictionary:
	if path == "":
		path = save_path
	var parsed := _read_save_file(path)
	if _valid_save_data(parsed):
		return {"data": parsed, "from_backup": false}
	var backup := _read_save_file(path + ".bak")
	if _valid_save_data(backup):
		push_warning("Save ontbreekt of is corrupt; reservekopie geladen: %s" % (path + ".bak"))
		return {"data": backup, "from_backup": true}
	return {"data": {}, "from_backup": false}


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.new().parse i.p.v. parse_string: een kapot bestand geeft hier een foutcode, geen ERROR-regel in het log
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _valid_save_data(data: Dictionary) -> bool:
	return not data.is_empty() and data.get("map") is String \
			and data.get("party") is Array


## Laadt de save en zet alles terug (party, spullen, goud, speeltijd, bestiarium);
## geeft false als er geen (geldige) save is. Daarna: continue_game() gaat naar de map.
## v0.11: 'path' = welke save ("" = de handmatige).
## 'gelezen' = de save die de aanroeper net al gelezen heeft (slotlijst/Doorgaan): dan geen derde parse.
func load_game(path := "", gelezen: Dictionary = {}) -> bool:
	som_mode = false      # SoM-proef: een geladen spel is altijd het gewone (turn-based) spel
	var d: Dictionary
	var src: Dictionary = {}
	last_load_notice = ""
	if not gelezen.is_empty():
		d = gelezen
	else:
		src = _read_save_source(path)
		d = src["data"]
	if not apply_state(d):
		last_load_notice = NOTICE_UNREADABLE
		game_loaded.emit(path if path != "" else save_path, false)
		return false
	# Gevechtsstijl van deze save; oude saves zonder sleutel houden hun vroegere effectieve waarde: Classic.
	var style = d.get("battle_style", Settings.BATTLE_STYLE_CLASSIC)
	Settings.set_value("battle_style", int(style) if (style is int or style is float) else Settings.BATTLE_STYLE_CLASSIC)
	# v0.19 kamer-checkpoint uit de save (oude saves: geen; dan zet de map hem bij binnenkomst)
	checkpoint = _checkpoint_from(d.get("checkpoint", {}))
	entry_kind = "load"
	pending_respawn_msg = []
	if bool(src.get("from_backup", false)):
		var main_path := path if path != "" else save_path
		last_load_notice = NOTICE_RECOVERED
		pending_respawn_msg = RECOVERED_LINES.duplicate()
		save_recovered.emit(main_path, main_path + ".bak")
	game_loaded.emit(path if path != "" else save_path, true)
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
	player_name = migrate_name(clean_name(str(d.get("player_name", DEFAULT_NAME))))
	# #166: ontbrekende sleutel (oude save) = "" = uitgang naar wilgendal.tscn zoals vroeger
	huis_herkomst = "dorp" if str(d.get("huis_herkomst", "")) == "dorp" else ""
	party.clear()
	var stray_equipment: Array = []
	party = _party_from(d["party"], stray_equipment)
	party_bench = []
	if d.get("party_bank") is Array:
		party_bench = _party_from(d["party_bank"], stray_equipment)
	if party.is_empty():
		add_member(MAIN_HERO)
	leader_id = str(d.get("leader", MAIN_HERO)) if d.get("leader", MAIN_HERO) is String else MAIN_HERO
	# v0.22 migratie: oude saves met meer dan 4 actieve helden -> de rest naar de reserve
	PartyLimiet.normaliseer()
	inventory = _inventory_from(d.get("inventory", {}))
	for id in stray_equipment:
		# alleen echte uitrusting terug in de tas; een onbekend id uit een kapotte save valt weg
		if Equipment.is_equipment(str(id)):
			inventory[id] = int(inventory.get(id, 0)) + 1
	gold = _gold_from(d.get("gold", 0))
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
	# v0.22 bekeken cutscenes (oude saves: geen veld -> afgeleid van de vlaggen)
	scenes_seen = []
	var seen_raw = d.get("scenes_seen", [])
	if seen_raw is Array:
		for sid in seen_raw:
			if ScenesData.ids().has(str(sid)) and not scenes_seen.has(str(sid)):
				scenes_seen.append(str(sid))
	scenes_seen = seen_scenes()
	heard_music = []
	var heard_raw = d.get("heard_music", [])
	if heard_raw is Array:
		for tid in heard_raw:
			if MusicTracks.ids().has(str(tid)) and not heard_music.has(str(tid)):
				heard_music.append(str(tid))
	_hoor_huidige_muziek()
	# v0.25 Quest Log; oude saves zonder "quests" -> afgeleid van de vlaggen en de verhaalstap
	quest_progress = QuestData.van_save(d.get("quests", {}))
	quest_sync()
	pending_tutorial = {}
	if has_node("/root/Story"):
		var story: Node = get_node("/root/Story")
		story.reset(true)
		# Oude saves hebben deze sleutel niet en krijgen dus geen uitgesteld event.
		story.pending_unique_event = str(d.get("pending_unique_event", "")) \
				if d.get("pending_unique_event", "") is String else ""
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
	koopman_load(d.get("koopman", {}))
	# v0.19 unieke monsters; oude saves zonder dit veld = nog niets verslagen. Onbekende ids vallen weg.
	unique_done = {}
	var un = d.get("uniek", {})
	if un is Dictionary:
		for k in un:
			if is_unique(str(k)):
				unique_done[str(k)] = "gevangen" if str(un[k]) == "gevangen" else "verslagen"
	_unique_seen_flags()
	_codex_inktwurm_sync(not d.has(CODEX_SYNC_KEY))
	puzzle_latched = {}
	archief2 = {"platen": {}}
	var a2 = d.get("archief2", {})
	if a2 is Dictionary and a2.get("platen") is Dictionary:
		var platen := {}
		for k in a2["platen"]:
			platen[str(k)] = int(a2["platen"][k])
		archief2 = {"platen": platen}
	bezochte_kaarten = []
	if d.has("bezocht") and d["bezocht"] is Array:
		for pad in d["bezocht"]:
			var sleutel := str(pad)
			if sleutel != "" and not bezochte_kaarten.has(sleutel):
				bezochte_kaarten.append(sleutel)
	else:
		for pad in WorldWarperDestinations.legacy_bezocht():
			bezochte_kaarten.append(pad)
	var voltooid = d.get("echo_grot_voltooid", 0)
	echo_grot_voltooid = int(voltooid) if (voltooid is int or voltooid is float) else 0
	archief2_temp_ally = {}
	archief2_party_filter = ""
	pending_story_loss = false
	archief2_lotte_join = false
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
	if bool(d.get("autosave", false)):
		active_slot = home_slot_of(d)
	elif d.has("slot") and (d["slot"] is int or d["slot"] is float):
		active_slot = clampi(int(d["slot"]), 1, SLOT_COUNT)
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


func _slot_for_path(path: String) -> int:
	for i in range(1, SLOT_COUNT + 1):
		if slot_path(i) == path:
			return i
	return active_slot


## Titelscherm 'Doorgaan' laadt nog steeds de nieuwste save (tests en oude knop).
## Het titelscherm zelf opent eerst de slotlijst en roept continue_slot aan.
func continue_game() -> bool:
	use_story_saves()
	var rec := newest_slot_record()
	if rec.is_empty():
		return false
	return await _continue_record(rec)


## Laad één van de vier slots (de nieuwste van dat slot: handmatig of bijbehorende autosave).
func continue_slot(slot: int) -> bool:
	use_story_saves()
	var rec := slot_record(slot)
	if rec.is_empty():
		return false
	return await _continue_record(rec)


func _continue_record(rec: Dictionary) -> bool:
	var rs := int(rec.get("slot", 1))
	active_slot = home_slot_of(rec.get("data", {})) if rs == AUTOSAVE_SLOT else clampi(rs, 1, SLOT_COUNT)
	if changing_map or not load_game(str(rec.get("path", "")), rec.get("data", {})):
		return false
	changing_map = true
	in_battle = false
	await Transition.fade_out()
	_go_to_scene(return_map if ResourceLoader.exists(return_map) else START_MAP)
	return true


## Betatest-account: verdergaan in de aparte voortgang, of die de eerste keer aanmaken.
## Proloog is klaar, Dennis is niveau 10 met het Vonkzwaard, de Codex heeft al een buddy.
## De Golem staat er nog (3 Lege Boeken), het woud is open, Esdoorn pas na de Golem.
## SoM-proef: verse standaard-party (data: som_data.gd), eigen save-bestand, meteen de proefkerker in.
func start_som_prototype() -> void:
	const SomData := preload("res://scripts/data/som_data.gd")
	if changing_map or in_battle or not SomData.ENABLED:
		return
	_build_som_state()
	save_path = SomData.SAVE_PATH
	autosave_path = SomData.AUTOSAVE_PATH
	current_map = SomData.START_MAP
	changing_map = false
	change_map(SomData.START_MAP, SomData.START_SPAWN)


## Co-op host: Action-sandbox; alleen deze save telt (som_save_1.json).
func start_som_coop_host() -> void:
	const SomData := preload("res://scripts/data/som_data.gd")
	if changing_map or in_battle or not SomData.ENABLED:
		return
	coop_role = "host"
	_build_som_state()
	save_path = SomData.SAVE_PATH
	autosave_path = SomData.AUTOSAVE_PATH
	current_map = SomData.START_MAP
	changing_map = false
	await Transition.fade_out()
	_go_to_scene(COOP_SANDBOX_SCENE)


## Co-op gast: zelfde sandbox om te spelen, maar nooit som_save_1.json schrijven.
func start_som_coop_guest(character_id: String) -> void:
	const SomData := preload("res://scripts/data/som_data.gd")
	if changing_map or in_battle or not SomData.ENABLED or character_id == "":
		return
	_coop_snapshot_guest_solo()
	coop_role = "guest"
	_build_som_state()
	leader_id = character_id if character_id != "" else MAIN_HERO
	save_path = COOP_GUEST_SAVE_PATH
	autosave_path = COOP_GUEST_AUTOSAVE_PATH
	current_map = SomData.START_MAP
	changing_map = false
	await Transition.fade_out()
	_go_to_scene(COOP_SANDBOX_SCENE)


func _build_som_state() -> void:
	const SomData := preload("res://scripts/data/som_data.gd")
	new_game(DEFAULT_NAME)
	story_step = StoryData.KLAAR
	story_flags = {}
	for f in BETA_FLAGS:
		story_flags[f] = true
	for id in SomData.START_MEMBERS:
		add_member(id)
	for hero in party:
		give_exp(hero, GameData.exp_for_level(SomData.START_LEVEL) - int(hero["exp"]))
	var dax: Dictionary = party[0]
	for id in SomData.START_GEAR:
		inventory[id] = item_count(id) + 1
		Equipment.equip(dax, inventory, Equipment.slot_of(id), id)
	for hero in party:
		hero["hp"] = hero["max_hp"]
		hero["mp"] = hero["max_mp"]
	for id in SomData.START_ITEMS:
		inventory[id] = int(SomData.START_ITEMS[id])
	gold = SomData.START_GOLD
	som_mode = true


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


## Eindstaat-account: verdergaan in de aparte voortgang, of die de eerste keer aanmaken.
## Het bestand is save_eindstaat.json. Slot 1-4 en de betatest blijven onaangeroerd,
## ook als de speler daarna zelf opslaat (die save gaat naar het eindstaat-bestand).
func start_eind_game() -> void:
	if changing_map or in_battle:
		return
	use_eind_saves()
	var p := newest_eind_path()
	if p != "" and load_game(p):
		changing_map = true
		in_battle = false
		await Transition.fade_out()
		_go_to_scene(return_map if ResourceLoader.exists(return_map) else WORLD_MAP)
		return
	_build_eind_state()
	current_map = WORLD_MAP
	save_game(BETA_TILE, BETA_FACING)
	changing_map = false
	change_map(WORLD_MAP, BETA_SPAWN)


## TODO(design): level 40 (VERHAAL_MAX, act 6), stap noor_gered met vlaggen water_klaar t/m ilse_thee plus golem en wortelkoning, party Dennis/Noor/Lotte zonder nieuwe dialoog, G4-wapens superzwaard en de staven van Noor en Lotte, 8000 goud, drankje, toverwater, leeg boek en kruidenthee, spreuken t/m grade 3 die SpellRules toestaat, en de vangbare Codex-soorten; geen hanger en geen H-6.
func _build_eind_state() -> void:
	new_game(DEFAULT_NAME)
	story_step = StoryData.NOOR_GERED
	story_flags = {}
	for f in EIND_FLAGS:
		story_flags[f] = true
	story_flags[StoryData.GOLEM_FLAG] = true
	story_flags[StoryData.WORTELKONING_FLAG] = true
	var lv := eind_level()
	var hero: Dictionary = party[0]
	_raise_to_level(hero, lv)
	_equip_eind_weapon(hero)
	join_member("noor", lv, [str(EIND_WEAPONS["noor"])])
	join_member("lotte", lv, [str(EIND_WEAPONS["lotte"])])
	for h in party:
		_grant_eind_spells(h)
		h["hp"] = h["max_hp"]
		h["mp"] = h["max_mp"]
	inventory["drankje"] = 5
	inventory["toverwater"] = 3
	inventory["leeg_boek"] = 3
	inventory["kruidenthee"] = 3
	gold = EIND_GOLD
	_fill_eind_codex()


## Hoogste verhaallevel dat act 6 is. Nu VERHAAL_MAX (40); anders de hoogste band van act 6.
func eind_level() -> int:
	var cap := LevelScale.VERHAAL_MAX
	if LevelScale.act_for_level(cap) == 6:
		return cap
	var best := 0
	for lv in range(1, cap + 1):
		if LevelScale.act_for_level(lv) == 6:
			best = lv
	return best if best > 0 else cap


func _raise_to_level(hero: Dictionary, level: int) -> void:
	var need := GameData.exp_for_level(level) - int(hero["exp"])
	if need > 0:
		give_exp(hero, need)


func _equip_eind_weapon(hero: Dictionary) -> void:
	var id := str(EIND_WEAPONS.get(str(hero.get("id", "")), ""))
	if id != "":
		Equipment.give_and_equip(hero, inventory, id)


## Alleen spreuken die deze held mag, tot de grade die de winkel op dit level verkoopt (max 3).
func _grant_eind_spells(hero: Dictionary) -> void:
	var id := str(hero.get("id", ""))
	var cap := SpellRules.shop_max_grade(GameData.act_for_level(eind_level()))
	for sid in GameData.SPELLS:
		var sp: Dictionary = GameData.SPELLS[sid]
		if int(sp.get("grade", 1)) > cap:
			continue
		if SpellRules.can_learn(id, str(sid)):
			PartyActions.teach_spell(hero, str(sid))


## Codex en bestiarium: alleen soorten en vijanden die de data al kent.
func _fill_eind_codex() -> void:
	var ids: Array = CodexData.SPECIES.keys()
	ids.sort()
	# v0.21: de Archief 2-soorten achteraan; de Codex heeft maar MAX_PAGES pagina's.
	for a2 in ["sporekop", "rankje", "wortelgeest"]:
		if ids.has(a2):
			ids.erase(a2)
			ids.append(a2)
	# Diepe Grot-soorten (alleen in de grot te vangen) niet in de eind-Codex.
	for dg in CodexData.GROT_BEHOUD:
		ids.erase(dg)
	# Berggrot-soorten (Hollow Mountain) ook niet: de eindstaat houdt zijn vaste Codex-samenstelling.
	for bg in BerggrotData.MONSTERS:
		ids.erase(bg)
	for raw_id in ids:
		if codex_full():
			break
		var sid := str(raw_id)
		if not CodexData.has_species(sid):
			continue
		var spec := CodexData.species(sid)
		if not bool(spec.get("capturable", false)):
			continue
		var lv := int(spec.get("base_level", 1))
		if lv < 1:
			lv = 1
		codex_add(sid, lv)
	for enemy_id in GameData.ENEMIES:
		mark_seen(str(enemy_id))
	for boss_id in EndgameBestiary.ids():
		mark_seen(str(boss_id))
	for page in codex_pages:
		if str(page.get("species", "")) == "inktwurm":
			codex_set_active(str(page.get("uid", "")))
			break


## Na de naamkeuze: nieuw spel en naar het startpunt in het dorp.
func start_new_game(hero_name: String) -> void:
	use_story_saves()
	new_game(hero_name)
	# Forge/Dennis 21 okt 2026: een NIEUW spel begint altijd in Action (Classic blijft kiesbaar in Settings).
	# Geladen saves houden hun eigen keuze (load_game; zonder sleutel = Classic).
	Settings.set_value("battle_style", Settings.BATTLE_STYLE_ACTION)
	changing_map = false
	change_map(START_MAP, START_SPAWN)
	# v0.11: niet meteen automatisch opslaan bij een nieuw spel (anders is de autosave van
	# het vorige spel direct weg); dat gebeurt pas bij de eerste echte mapwissel.
	_autosave_request = ""


## Terug naar het titelscherm (bv. vanuit het veldmenu, en in de autotest).
func go_to_title(force := false) -> void:
	if not force and (changing_map or in_battle):
		return
	if force:
		in_battle = false
		changing_map = false
	if coop_in_session():
		coop_end_session("")
	use_story_saves()
	som_mode = false
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
	if path != "" and not bezochte_kaarten.has(path):
		bezochte_kaarten.append(path)
	if path != Dungeon100RulesC.dungeon_scene:
		# Veiligheidsnet, niet tijdens een gevecht: wie de grot verlaat krijgt de echte party terug
		# en de Blauwe Kist-items. Een gevecht laadt geen map en mag de run niet afbreken.
		if not in_battle and dungeon100_run_active():
			dungeon100_end_run(true)
		dungeon100_floor = 0      # buiten de Diepe Grot (ook na game over of een andere map)
	changing_map = false
	SessieLog.kaart(path)
	if path.ends_with("/rustkamer.tscn"):
		PartyBenchLib.normaliseer()


## Ga naar een andere map: fade uit, wissel van scène, en zet de speler
## op het spawnpunt met de naam spawn_name (een node onder "Spawns").
func change_map(path: String, spawn_name: String) -> void:
	if changing_map or in_battle:
		return
	if ReleaseFlags.dev_scene_blocked(path):
		return
	changing_map = true
	warp_from_map = current_map
	var route := huis_route(current_map, path, spawn_name)
	path = route[0]
	spawn_name = route[1]
	SessieLog.warp(current_map, path, spawn_name)
	pending_spawn = spawn_name
	has_return_point = false
	entry_kind = "door"
	_autosave_request = "map" if is_dungeon_transition(current_map, path) else ""
	await Transition.fade_out()
	_go_to_scene(path)


## Modus-direct: dezelfde kamer opnieuw opbouwen op de plek van de speler (Classic<->Action meteen toepassen).
## Verslagen monsters, kisten enz. blijven zoals ze waren (reload_in_place); de leider blijft (leader_id, #161).
var reload_in_place := false


func reload_room(tile: Vector2i, facing: Vector2i) -> void:
	if changing_map or in_battle or current_map == "":
		return
	changing_map = true
	return_map = current_map
	return_tile = tile
	return_facing = facing
	has_return_point = true
	pending_spawn = ""
	entry_kind = "reload"
	reload_in_place = true
	_autosave_request = ""
	await Transition.fade_out()
	_go_to_scene(current_map)


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
func start_battle(enemies: Array, from_tile: Vector2i, facing: Vector2i, terrain := "", boss := false, tier := 0, archief := false, practice := false) -> void:
	if in_battle or changing_map:
		return
	in_battle = true
	SessieLog.gevecht_start(enemies, boss, terrain, from_tile)
	battle_started.emit(enemies, boss)
	prepare_battle(enemies, terrain, boss, tier, archief, practice)
	has_return_point = true
	return_map = current_map
	return_tile = from_tile
	return_facing = facing
	await Transition.encounter_out()
	_go_to_scene(BATTLE_SCENE)


## Alles wat battle.gd bij _ready uit GameState leest (vijanden, baas, tier, archief, achtergrond).
## Gedeeld door start_battle en de headless simulator (tools/battlesim/battlesim_runs.gd), die geen
## kaart, terugkeerpunt, sessielog of scènewissel wil.
func prepare_battle(enemies: Array, terrain := "", boss := false, tier := 0, archief := false, practice := false) -> void:
	practice_battle = practice
	pending_enemies = enemies
	pending_boss = boss
	pending_tier = 0 if boss else tier
	pending_archief = archief and not boss
	pending_backdrop_id = GameData.backdrop_id_for(terrain, boss, dungeon100_floor if terrain == "dungeon100" else 0)
	pending_backdrop = GameData.backdrop_path(pending_backdrop_id)
	_prefetch_backdrop(pending_backdrop)
	for h in party:
		_vraag_voor(str(h.get("battle_sprite", "")))


## Terug naar de map waar het gevecht begon (na winnen of vluchten),
## of naar het begin van het spel (game over).
func end_battle(result: String) -> void:
	result = archief2_verwerk_einde(result)
	SessieLog.gevecht_eind(result)
	battle_ended.emit(result)
	var oefening := practice_battle
	practice_battle = false
	last_battle_result = result
	pending_tier = 0
	pending_archief = false
	steps_until_encounter_possible = GameData.SAFE_STEPS
	pending_tutorial = {}
	var target := return_map if return_map != "" else START_MAP
	var respawn_soort := ""      # playtest-logboek: hoe je na verliezen weer opstaat
	if result == "lose":
		map_monster_battle = {}
		respawn_soort = "oefening" if oefening else "dungeon100" if (dungeon100_floor > 0 or dungeon100_run_active()) \
				else "checkpoint" if has_checkpoint() else "start"
		if oefening:
			# Terug in de kamer, genezen. Geen checkpoint-rollback en geen game-over.
			_full_heal()
			entry_kind = "battle"
			has_return_point = true
			pending_respawn_msg = []
		elif dungeon100_floor > 0 or dungeon100_run_active():
			# 100-kerker: dood is dungeon uit. Terug naar ECHO's Kamer, niet verdieping 1.
			target = dungeon100_defeat()
		elif has_checkpoint():
			# v0.19: terug naar waar je deze kamer/map binnenkwam (baas: de kamer ervoor)
			target = respawn_at_checkpoint(pending_boss)
		else:
			respawn()
			target = RESPAWN_MAP
	else:
		entry_kind = "battle"
		if oefening:
			_full_heal()
		else:
			# KO-helden staan na het gevecht weer op met 1 HP (houdt het simpel).
			for h in party:
				if h["hp"] <= 0:
					h["hp"] = 1
			# Codex: de bondgenoot ook (zelfde regel als de helden)
			for p in codex_pages:
				if int(p["hp"]) <= 0:
					p["hp"] = 1
		# v0.11: na winst automatisch opslaan (zodra de map weer in beeld is)
		if result == "win" and not oefening:
			pass      # save-slots (Dennis): geen autosave meer na een gewonnen gevecht
			# v0.15: baas verslagen -> de hoofdheld absorbeert zijn kern (eenmalig). Meteen
			# vastleggen, dus de autosave hierna heeft hem al; het moment zelf speelt de map af.
			if pending_boss and dungeon100_floor == 0:      # de simulatie geeft geen echte kernen
				for e in pending_enemies:
					var kid := KernData.fragment_for_boss(str(e))
					if kid != "" and grant_kern(kid, str(e)):
						pending_kern_absorb = kid
	if result == "lose":
		SessieLog.dood("practice" if oefening else "boss" if pending_boss else "battle")
		SessieLog.respawn(target, respawn_soort)
		if not oefening and not pending_story_loss:
			var plek := return_map if return_map != "" else current_map
			game_over.emit(plek)
	await Transition.fade_out()
	in_battle = false
	_go_to_scene(target)


## v0.19: is er een bruikbaar kamer-checkpoint?
func has_checkpoint() -> bool:
	return not checkpoint.is_empty() and ResourceLoader.exists(str(checkpoint.get("map", ""))) \
			and checkpoint.get("state") is Dictionary


## v0.19: leg het kamer-checkpoint vast (map.gd, bij binnenkomst): plek + kopie van de voortgang.
func set_checkpoint(map: String, tile: Vector2i, facing: Vector2i) -> void:
	var state := state_data(tile, facing, map)
	state[CODEX_SYNC_KEY] = true
	checkpoint = {"map": map, "tile": [tile.x, tile.y], "facing": [facing.x, facing.y], "state": state}


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
	var keep_koopman := koopman_save_data()      # bezoeken aan H-5 rollen niet terug
	# Een al gezien eenmalige tutorial (na een uniek monster) rolt niet terug: nooit twee keer.
	var keep_seen: Array = StoryData.UNIQUE_SEEN_FLAGS.values().filter(func(f): return story_flags.has(str(f)))
	if story_flags.has(StoryData.TUTORIAL_CODEX_FLAG):
		keep_seen.append(StoryData.TUTORIAL_CODEX_FLAG)
	var cp := checkpoint.duplicate(true)
	apply_state(cp["state"])
	koopman_load(keep_koopman)
	for id in keep_unique:
		if str(keep_unique[id]) == "verslagen" and not unique_done.has(str(id)):
			unique_done[str(id)] = "verslagen"
	_unique_seen_flags()
	for f in keep_seen:
		story_flags[str(f)] = true
	_codex_inktwurm_sync(not cp["state"].has(CODEX_SYNC_KEY))
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
	_autosave_request = ""      # save-slots: geen autosave na respawn
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
## Koopman-blok voor de save.
func koopman_save_data() -> Dictionary:
	return {"bezoeken": koopman_bezoeken, "laatste": koopman_laatste, "token": koopman_token,
			"gekocht": koopman_gekocht.duplicate()}


## Koopman-blok uit een save; oude saves zonder blok = nog nooit bezocht.
func koopman_load(d) -> void:
	var k: Dictionary = d if d is Dictionary else {}
	koopman_bezoeken = maxi(0, int(k.get("bezoeken", 0)))
	koopman_laatste = str(k.get("laatste", ""))
	koopman_token = bool(k.get("token", false))
	koopman_gekocht = []
	var g = k.get("gekocht", [])
	if g is Array:
		for id in g:
			koopman_gekocht.append(str(id))


## Eén bezoek aan de Koopman tellen (zelfde run + verdieping telt één keer). Geeft de teller terug.
func koopman_bezoek(sleutel: String) -> int:
	if sleutel != koopman_laatste:
		koopman_laatste = sleutel
		koopman_bezoeken += 1
		koopman_gekocht = []     # restock: nieuw bezoek (en dus elke nieuwe run)
	return koopman_bezoeken


func dungeon100_run_active() -> bool:
	return not dungeon100_snapshot.is_empty()


## Is dit item permanent (zit het in de Blauwe-Kist-databank)? Alleen tijdens een run, daarbuiten is
## het gewoon een item van je tas.
func is_permanent_item(id: String) -> bool:
	return dungeon100_run_active() and dungeon100_permanent.has(id)


## Een run begint (ECHO, of Dungeon100Room bij een directe binnenkomst): de echte party/tas/goud/
## Codex gaan in de momentopname. De simulatie neemt iedereen mee die dan in de party zit (ook wie zich
## later aansloot) plus elke Codex-pagina, allemaal op level 1, zonder uitrusting en zonder spreuken.
## De tas heeft alleen de permanente items, en er is geen goud. Dubbel aanroepen doet niets (false).
## De wereldkaart start de grot niet meer; dat doet dungeon100_echo_start.
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


## Uitzondering Dennis: Diepe Grot-soorten (CodexData.GROT_BEHOUD) die TIJDENS de run gevangen zijn
## (uid niet in de momentopname) gaan mee terug. Op hun vangniveau (zoals bij binnenkomst: geen run-levels),
## met uid, naam en vangst. Was er een de actieve bondgenoot, dan blijft hij dat (alleen als de echte
## Codex geen bondgenoot had). Geeft [pagina's, actieve uid] terug; aanroepen VOOR codex_load_data.
func _dungeon100_kept_pages(snap_codex) -> Array:
	var oud := {}
	if snap_codex is Dictionary and snap_codex.get("pages") is Array:
		for p in snap_codex["pages"]:
			if p is Dictionary:
				oud[str(p.get("uid", ""))] = true
	var out: Array = []
	var actief := ""
	for page in codex_pages:
		var sid := str(page.get("species", ""))
		var uid := str(page.get("uid", ""))
		if uid == "" or oud.has(uid) or not CodexData.GROT_BEHOUD.has(sid) or not CodexData.has_species(sid):
			continue
		var caught: Dictionary = page.get("caught", {}) if page.get("caught") is Dictionary else {}
		var fresh := CodexData.make_page(sid, CodexData.capture_level(int(caught.get("tier", 1)), sid), uid)
		if page.get("name") is String and str(page["name"]) != "":
			fresh["name"] = str(page["name"])
		fresh["caught"] = caught.duplicate(true)
		out.append(fresh)
		if uid == codex_active:
			actief = uid
	return [out, actief]


func _dungeon100_restore_kept(behouden: Array) -> void:
	var pages: Array = behouden[0]
	for p in pages:
		if codex_full():
			break
		codex_pages.append(p)
		var n := str(p["uid"]).trim_prefix("codex_")
		if n.is_valid_int():
			codex_next_id = maxi(codex_next_id, int(n) + 1)
	var actief := str(behouden[1])
	if codex_active == "" and actief != "" and not codex_page(actief).is_empty():
		codex_active = actief
	elif codex_active == "" and not pages.is_empty() and not codex_page(str(pages[0]["uid"])).is_empty():
		codex_active = str(pages[0]["uid"])
	if not pages.is_empty():
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
	# Vloer eerst op 0, anders schaalt de Simulatie-ring de echte party bij het terugzetten.
	dungeon100_floor = 0
	party = _party_from(snap["party"], stray)
	if party.is_empty():
		add_member(MAIN_HERO)
	inventory = _inventory_from(snap.get("inventory", {}))
	for id in stray:
		inventory[id] = int(inventory.get(id, 0)) + 1
	gold = _gold_from(snap.get("gold", 0))
	var behouden := _dungeon100_kept_pages(snap.get("codex", {}))
	codex_load_data(snap.get("codex", {}))
	_dungeon100_restore_kept(behouden)
	dungeon100_snapshot = {}
	_dungeon100_clear_run_flags()
	defeated_map_monsters = {}
	map_monster_battle = {}
	dungeon100_checkpoint = 0
	dungeon100_seed = 0
	dungeon100_warpers = []
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


## Deze verdieping is bereikt: best gaat omhoog, en een warper-verdieping gaat open.
## Op 100 ligt het Warp-kristal klaar. Er is geen baas die het dropt.
## De beloning kiest de speler pas als het kristal gebruikt wordt.
func dungeon100_reach_floor(floor_nr: int) -> void:
	if not Dungeon100RulesC.is_valid_floor(floor_nr):
		return
	dungeon100_best = Dungeon100RulesC.best_after(dungeon100_best, floor_nr)
	dungeon100_warpers = Dungeon100RulesC.unlock_warper(dungeon100_warpers, floor_nr)
	if floor_nr == Dungeon100RulesC.FLOORS and dungeon100_run_active() \
			and item_count(Dungeon100RulesC.Blue.WARP_ITEM) < 1:
		inventory[Dungeon100RulesC.Blue.WARP_ITEM] = 1


## Warper (niet op verdieping 1): de run stopt en je staat in ECHO's Kamer.
## false = geen run, of de kaart wisselt al. Annuleren roept dit niet aan.
## Zet echo_grot_resultaat niet: dat doet alleen het Warp-kristal op verdieping 100.
func dungeon100_warper_exit() -> bool:
	if not dungeon100_run_active() or changing_map or in_battle:
		return false
	dungeon100_leave()
	change_map(Dungeon100RulesC.WORLD_SCENE, Dungeon100RulesC.WORLD_SPAWN)
	return true


## Het Warp-kristal werkt alleen op de laatste verdieping, tijdens een run, met het kristal in de tas.
func dungeon100_can_warp() -> bool:
	return dungeon100_run_active() and dungeon100_floor == Dungeon100RulesC.FLOORS and item_count(Dungeon100RulesC.Blue.WARP_ITEM) > 0


## Warp: één beloning (codex, wapens of ring), daarna de run voorbij en terug naar ECHO's Kamer.
## false = kan niet, of de keuze ontbreekt of is ongeldig. Zonder keuze rondt de run niet af.
func dungeon100_warp(keuze := "") -> bool:
	if not dungeon100_can_warp() or not Dungeon100Reward.geldig(keuze):
		return false
	dungeon100_best = Dungeon100RulesC.FLOORS
	if not dungeon100_end_run(true):
		return false
	Dungeon100Reward.geef(keuze)
	story_flags[EchoGrot.FLAG_RESULTAAT] = true
	change_map(EchoGrot.KAMER, EchoGrot.KAMER_SPAWN)
	return true


## ECHO start een nieuwe run: verdieping 1, level 1, zonder uitrusting. De kamer kiest de seed.
func dungeon100_echo_start() -> bool:
	if changing_map or in_battle or dungeon100_run_active():
		return false
	if not dungeon100_begin_run():
		return false
	dungeon100_floor = 1
	dungeon100_seed = 0
	change_map(EchoGrot.DUNGEON, EchoGrot.DUNGEON_SPAWN)
	return true


## Nederlaag in de kerker: de run is voorbij ("dood is dungeon uit"). Tijdelijke levels, tas en goud van
## de run zijn weg. De echte party/tas/goud/Codex komen terug uit de momentopname, daarna de permanente
## Blauwe-Kist-items. Terug naar ECHO's Kamer, niet naar verdieping 1 en niet naar de wereldkaart.
## Zet echo_grot_resultaat niet. Een nieuwe run begint pas als ECHO hem start. Geeft de kamer terug.
func dungeon100_defeat() -> String:
	dungeon100_best = Dungeon100RulesC.best_after(dungeon100_best, dungeon100_floor)
	has_return_point = false
	if dungeon100_run_active() and dungeon100_floor > 0 \
			and not bool(story_flags.get(Dungeon100Reward.FLAG_RESET, false)) \
			and Dungeon100Reward.draagt_ring(party):
		story_flags[Dungeon100Reward.FLAG_RESET] = true
		_full_heal()
		pending_spawn = Dungeon100RulesC.START_SPAWN
		pending_respawn_msg = [Dungeon100Reward.RESET_LINE]
		entry_kind = "respawn"
		_autosave_request = ""      # save-slots: geen autosave na respawn
		return Dungeon100RulesC.dungeon_scene
	if dungeon100_run_active():
		dungeon100_end_run(true)
	else:
		_dungeon100_clear_run_flags()
		dungeon100_checkpoint = 0
		dungeon100_floor = 0
		dungeon100_seed = 0
		dungeon100_warpers = []
	_full_heal()
	pending_spawn = Dungeon100RulesC.WORLD_SPAWN
	pending_respawn_msg = DUNGEON100_RESET_LINES.duplicate()
	entry_kind = "respawn"
	_autosave_request = ""      # save-slots: geen autosave na respawn
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
	dungeon100_warpers = v["warpers"]
	for h in party:
		Equipment.refresh(h)


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
	var flag := str(StoryData.CODEX_SPECIES_FLAGS.get(species_id, ""))
	if flag != "":
		story_flags[flag] = true
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
		unique_marked.emit(id, how)


## Oude saves (of een checkpoint van vóór het gevecht): is het unieke monster al weg, dan geldt zijn
## eenmalige tutorial als gezien (StoryData.UNIQUE_SEEN_FLAGS). Nooit achteraf afspelen.
func _unique_seen_flags() -> void:
	for id in StoryData.UNIQUE_SEEN_FLAGS:
		if unique_done.has(str(id)):
			story_flags[str(StoryData.UNIQUE_SEEN_FLAGS[id])] = true


## Vlag 'Inktwurm in de Codex' bijhouden bij laden en bij een checkpoint: staat er een Inktwurm-pagina, dan
## is de vlag gezet. 'oude_save' (de save of het checkpoint mist CODEX_SYNC_KEY) en de Inktwurm is al weg
## (verslagen of gevangen): de Golemhal gaat pas open als hij in de Codex staat, dus die krijgt hem alsnog en
## de vang-tutorial telt als gezien. 'Gevangen' en daarna gefuseerd: wel de vlag, geen nieuwe pagina. Codex
## vol: geen pagina (de uitgang gaat dan al open, zie StoryData.GOLEMHAL_EXIT); volgende load probeert het weer.
## Default oude_save=true: een directe aanroep (na unique_done) zet de pagina/vlag, zodat uid-volgorde
## (codex_0001..) en codex_next_id kloppen bij save/load. apply_state / respawn geven de marker expliciet
## door: een nieuwe save (mét marker) wordt nooit gemigreerd, tussen tutorial 1 en 2 speelt de vang-tutorial.
func _codex_inktwurm_sync(oude_save := true) -> void:
	var flag := StoryData.CODEX_INKTWURM_FLAG
	for page in codex_pages:
		if str(page.get("species", "")) == "inktwurm":
			story_flags[flag] = true
	if not oude_save or not unique_done.has("inktwurm"):
		return
	story_flags[StoryData.TUTORIAL_CODEX_FLAG] = true
	if story_flags.has(flag):
		return
	if unique_state("inktwurm") == "gevangen":
		story_flags[flag] = true
	elif not codex_full():
		codex_add("inktwurm", CodexData.capture_level(0, "inktwurm"), {"play_time": int(play_time())})
		mark_seen("inktwurm")


# ---------------------------------------------------------------- world warper
## De hub gaat open na De Genezer (einde Archief 2). Zelfde vlag als
## WorldWarperUnlock.BEWAKER_VLAG. De bewaker van verdieping 2 van het Eerste
## Archief opent de hub niet. Geen Worldmap 2 of 3.
func world_warper_is_unlocked() -> bool:
	return story_flags.has(WorldWarperUnlock.UNLOCK_VLAG)


func try_unlock_world_warper() -> bool:
	if not WorldWarperUnlock.should_unlock(story_flags):
		return false
	if not story_flags.has(WorldWarperUnlock.UNLOCK_VLAG):
		story_flags[WorldWarperUnlock.UNLOCK_VLAG] = true
	return true
