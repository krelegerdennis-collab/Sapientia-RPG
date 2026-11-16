extends RefCounted
## ALLEEN VOOR TESTEN - vaste toestanden voor --savestresstest (scripts/tests/save_stress_tests.gd).
##   moments(): een paar representatieve momenten in WM1 (bed -> taken -> proloog klaar -> Noor kwijt -> Noor gered).
##   old_save_v0(): een save van vóór het versienummer (geen "version", oude held-id en oude namen).
## Zit niet in de export (scripts/tests/*).

const StoryData := preload("res://scripts/data/story_data.gd")

const HUIS := "res://scenes/maps/huis_wilgendal.tscn"
const DORP := "res://scenes/maps/wilgendal.tscn"
const WERELD := "res://scenes/maps/wereldkaart.tscn"
const WOUD := "res://scenes/maps/woud_pad.tscn"
const ESDOORN := "res://scenes/maps/esdoorn.tscn"


## Elk moment: naam, kaart, tegel, kijkrichting, verhaalstap, vlaggen, extra helden [id, level],
## goud en tas. Alleen bestaande kaarten, vlaggen en item-ids.
static func moments() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"name": "start (bed, nieuw spel)", "map": HUIS, "tile": Vector2i(3, 4), "facing": Vector2i.DOWN,
				"step": StoryData.START, "flags": [], "members": [], "gold": -1, "inv": {}},
		{"name": "taken (water klaar, kist dicht)", "map": DORP, "tile": Vector2i(12, 9), "facing": Vector2i.LEFT,
				"step": StoryData.TAKEN, "flags": ["water_klaar"], "members": [], "gold": 35,
				"inv": {"drankje": 2}},
		{"name": "proloog klaar (wereldkaart)", "map": WERELD, "tile": Vector2i(14, 31), "facing": Vector2i.DOWN,
				"step": StoryData.KLAAR, "flags": ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien"],
				"members": [], "gold": 410, "inv": {"drankje": 4, "toverwater": 1}},
		{"name": "Noor kwijt (Woudpad)", "map": WOUD, "tile": Vector2i(6, 11), "facing": Vector2i.UP,
				"step": StoryData.NOOR_KWIJT,
				"flags": ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien", "noor_ontmoet", "quest_noor"],
				"members": [], "gold": 980, "inv": {"drankje": 6, "toverwater": 3}},
		{"name": "Noor gered (einde WM1, Esdoorn)", "map": ESDOORN, "tile": Vector2i(9, 7), "facing": Vector2i.RIGHT,
				"step": StoryData.NOOR_GERED,
				"flags": ["water_klaar", "kist_open", "schilderij_weg", "archief_gezien", "noor_ontmoet", "quest_noor",
						"marit_boeken", "noor_gered", "noor_lid", "ilse_thee"],
				"members": [["noor", 5]], "gold": 4321, "inv": {"drankje": 9, "toverwater": 5}},
	]
	return out


## Zet GameState in de toestand van moment 'm' (na new_game).
static func apply_moment(m: Dictionary) -> void:
	GameState.new_game("Dax")
	GameState.current_map = str(m["map"])
	GameState.story_step = int(m["step"])
	var flags: Dictionary = {}
	for f in (m["flags"] as Array):
		flags[str(f)] = true
	GameState.story_flags = flags
	for mem in (m["members"] as Array):
		var pair: Array = mem
		GameState.join_member(str(pair[0]), int(pair[1]))
	if int(m["gold"]) >= 0:
		GameState.gold = int(m["gold"])
	var inv: Dictionary = m["inv"]
	for id in inv:
		GameState.set_item_count(str(id), int(inv[id]))
	# een beetje schade, zodat HP/MP echt mee moeten
	var lead: Dictionary = GameState.party[0]
	lead["hp"] = maxi(1, int(lead["max_hp"]) - 2)


## Een save zoals de vroegste builds hem schreven: geen "version", geen names_v23, geen checkpoint,
## geen battle_style, geen Codex; held-id "ruben" en weergavenaam "Dennis"; getallen als float.
static func old_save_v0() -> Dictionary:
	return {
		"map": DORP,
		"tile": [5.0, 6.0],
		"facing": [0.0, 1.0],
		"player_name": "Dennis",
		"party": [{"id": "ruben", "name": "Dennis", "level": 3.0, "exp": 40.0, "hp": 30.0, "mp": 0.0,
				"max_hp": 60.0, "max_mp": 0.0, "atk": 20.0, "def": 12.0, "agi": 10.0, "spells": [], "weapon": ""}],
		"inventory": {"drankje": 3.0, "toverwater": 1.0},
		"gold": 250.0,
		"play_time": 1234.5,
		"bestiary": {},
		"story": {"step": float(StoryData.TAKEN), "flags": ["water_klaar"]},
	}
