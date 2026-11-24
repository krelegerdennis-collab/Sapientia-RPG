extends RefCounted
## Post-RC: geluiden van de wereld (voetstappen, deuren, kisten, opdrachten, niveau, status, SoM-vijand).
## Geen eigen audiosysteem: alles gaat via UiSfx.play -> AudioManager.play_sfx (manifest:
## volume_db, pitch_variatie, min_interval_ms en een willekeurige variant _01.._04 komen daar
## vandaan). Zonder AudioManager of zonder sleutel in het manifest blijft het stil, zonder error.

const UiSfx := preload("res://scripts/ui/ui_sfx.gd")

const DOOR_OPEN := "door_open_wood"
const DOOR_CLOSE := "door_close_wood"
const DOOR_LOCKED := "door_locked"
const GATE_OPEN := "door_open_iron"
const SECRET := "secret_discovered"
const CHEST_OPEN := "chest_open"
const CHEST_LOCKED := "chest_locked"
const LEVER := "lever_pull"
const SWITCH := "switch_press"
const LEVEL_UP := "level_up"
const QUEST_ACCEPT := "quest_accept"
const QUEST_COMPLETE := "quest_complete"
const STATUS_STUN := "status_stun"
const ENEMY_HURT := "enemy_hurt"
const ENEMY_DEATH := "enemy_death_organic"
const ENEMY_DEATH_MECH := "enemy_death_mechanical"

const FOOT_STONE := "footstep_stone"
const FOOT_WOOD := "footstep_wood"
const FOOT_METAL := "footstep_metal"
const FOOT_MARBLE := "footstep_marble"
## Voetstap per zoveel afgelegde pixels (1 tegel), en nooit vaker dan FOOTSTEP_MIN_MS.
const FOOTSTEP_PX := 16.0
const FOOTSTEP_MIN_MS := 150
## Meer dan dit in één beeld = teleport/kaartwissel: geen stap, teller op 0.
const FOOTSTEP_JUMP_PX := 24.0

## puzzle_room.gd puzzle_sound -> manifest-sleutel ("" = (nog) geen passend geluid).
const PUZZLE := {
	"kist": CHEST_OPEN,
	"hendel": LEVER,
	"klik": SWITCH,
	"geheime_deur": SECRET,
	"poort_open": GATE_OPEN,
	"poort_dicht": DOOR_CLOSE,
}

const ALL := [DOOR_OPEN, DOOR_CLOSE, DOOR_LOCKED, GATE_OPEN, SECRET, CHEST_OPEN, CHEST_LOCKED, LEVER,
		SWITCH, LEVEL_UP, QUEST_ACCEPT, QUEST_COMPLETE, STATUS_STUN, ENEMY_HURT, ENEMY_DEATH,
		ENEMY_DEATH_MECH, FOOT_STONE, FOOT_WOOD, FOOT_METAL, FOOT_MARBLE]

## Voor de tests: laatst gevraagde sleutels (ook als het manifest/rate-limit ze stil hield).
static var recent: Array[String] = []


static func play(key: String) -> bool:
	if key == "":
		return false
	recent.append(key)
	if recent.size() > 64:
		recent.pop_front()
	return UiSfx.play(key)


static func puzzle(sound: String) -> bool:
	return play(str(PUZZLE.get(sound, "")))


## Ondergrond per kaart (scene-pad uit GameState.current_map). Standaard steen.
static func surface_for(map_path: String) -> String:
	var n := map_path.get_file().get_basename()
	if n.begins_with("archief") or n.begins_with("leven"):
		return FOOT_MARBLE
	if n.contains("huis") or n.contains("herberg") or n.contains("binnen"):
		return FOOT_WOOD
	if n.contains("werkplaats") or n.contains("bouwplaats"):
		return FOOT_METAL
	return FOOT_STONE
