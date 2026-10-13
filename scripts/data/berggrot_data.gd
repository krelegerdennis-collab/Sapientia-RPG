extends RefCounted
class_name Berggrot
## Berggrot door de bergen naar de kas van het Levende Archief.
## Een paar puzzels, geen bazen, eigen monsters en een eigen track.
## De wereldkaart start de grot via Berggrot.start(). De zuiduitgang komt terug
## op spawn van_berggrot. De noordkant wijst al naar de kas-scène.

const GradeGear := preload("res://scripts/data/grade_gear.gd")
const LevelScale := preload("res://scripts/data/level_scale.gd")
const GameData := preload("res://scripts/data/game_data.gd")

const SCENE := "res://scenes/maps/berggrot_mond.tscn"
const SPAWN_INGANG := "ingang"
const DEBUG_ARG := "--berggrot"
const BGM := "berggrot"
const BGM_BESTAND := "bgm_berggrot.ogg"
## Spawn op de wereldkaart, aan de voet van de bergen, ten zuiden van de mond.
const WERELD_MAP := "res://scenes/maps/wereldkaart.tscn"
const WERELD_SPAWN := "van_berggrot"
## Bouwplaats voor de tunnel (Dennis 2026-10-13). De grotmond komt daar uit, niet op de kaart.
const BOUWPLAATS := "res://scenes/maps/berggrot_bouwplaats.tscn"
const BOUWPLAATS_SPAWN := "van_tunnel"
## Tunnel open zodra Noor in de party zit.
const TUNNEL_VLAG := "noor_lid"
## Bestaande kas-scène. De kaart legt haar achter de bergen. Deze uitgang blijft.
const KAS_SCENE := "res://scenes/maps/archief_2_v1_entree.tscn"
const KAS_SPAWN := "ingang"
const THEME := "berggrot"
const STAF_ID := "bergnerfstaf"
const ACCESSOIRE_ID := "adersteen"
const M := "res://scenes/maps/"

const MONSTERS := {
	"steenluis": {
		"name": "Steenluis",
		"sprite": "res://assets/sprites/enemies/steenluis.png",
		"sprite_back": "res://assets/sprites/enemies/steenluis_rug.png",
		"max_hp": 56, "atk": 15, "def": 11, "agi": 5, "mag": 0, "mdef": 6,
		"exp": 16, "gold": 10, "y_offset": 0,
		"skills": [{"name": "Steenbeet", "chance": 0.2, "power": 1.3}],
		"mp": 0, "weak": ["bliksem"], "resist": [],
		"drops": [{"item": "drankje", "chance": 0.15}],
		"desc": "A louse of living stone. It crawls through the grain of the mountain.",
		"habitat": ["berggrot"],
	},
	"druipslak": {
		"name": "Druipslak",
		"sprite": "res://assets/sprites/enemies/druipslak.png",
		"sprite_back": "res://assets/sprites/enemies/druipslak_rug.png",
		"max_hp": 68, "atk": 13, "def": 13, "agi": 3, "mag": 0, "mdef": 8,
		"exp": 18, "gold": 12, "y_offset": 0,
		"skills": [{"name": "Koude drup", "chance": 0.22, "power": 1.25}],
		"mp": 0, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "kruid", "chance": 0.18}],
		"desc": "A slug of cold dripstone. Slow, and it leaves the rock wet behind it.",
		"habitat": ["berggrot"],
	},
	"adermot": {
		"name": "Adermot",
		"sprite": "res://assets/sprites/enemies/adermot.png",
		"sprite_back": "res://assets/sprites/enemies/adermot_rug.png",
		"max_hp": 40, "atk": 17, "def": 6, "agi": 16, "mag": 4, "mdef": 8,
		"exp": 16, "gold": 8, "y_offset": 0,
		"skills": [{"name": "Adervonk", "chance": 0.2, "power": 1.3}],
		"mp": 4, "weak": ["vuur"], "resist": [],
		"drops": [{"item": "toverwater", "chance": 0.12}],
		"desc": "A moth that follows the ore vein. Fast, and it flickers like a spark in the dark.",
		"habitat": ["berggrot"],
	},
}

const ROOMS := {
	"berggrot_mond": {
		"name": "Berggrot",
		"floor": 1, "tier": 0, "theme": THEME, "music": BGM, "checkpoint": true,
		"layout": [
			"a------------------b",
			"<LFFMFGFFAFFFFFFFFR>",
			"<lffmfgffnffffffffr>",
			"<Zsssssssssssssssss>",
			"<S#...x.........#..>",
			"<S.................>",
			"<S.........#.......>",
			"<S.................>",
			"<S.@...............>",
			"<S..p.........N....>",
			"<S.................>",
			"c_______(EE)_______d",
		],
		"save": [3, 8],
		"spawns": {"ingang": [9, 10, "up"], "boog": [9, 3, "down"]},
		"exits": {
			"E": {"map": BOUWPLAATS, "spawn": BOUWPLAATS_SPAWN},
			"n": {"map": M + "berggrot_grendel.tscn", "spawn": "ingang"},
		},
		"signs": [{
			"tile": [16, 7],
			"lines": [
				"The mountains won't let you cross.",
				"The vein runs through the stone, to the greenhouse of the Living Archive.",
			],
		}],
		"monsters": [
			{"id": "m1", "enemy": "steenluis", "group": ["steenluis"], "tile": [6, 5], "moves": true},
			{"id": "m2", "enemy": "adermot", "group": ["adermot"], "tile": [13, 6], "moves": true},
		],
	},
	"berggrot_nerf": {
		"name": "Berggrot - Nerf",
		"floor": 1, "tier": 0, "theme": THEME, "music": BGM, "checkpoint": true,
		"layout": [
			"a------------------b",
			"<LFFMFGFFAFFFFFFFFR>",
			"<lffmfgffnffffffffr>",
			"<Zsssssssssssssssss>",
			"<S#...x.........#..>",
			"<S.................>",
			"<S.........#.......>",
			"<S.................>",
			"<S.@...............>",
			"<S..p.........N....>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"save": [3, 8],
		"spawns": {"zuid": [9, 10, "up"], "boog": [9, 3, "down"]},
		"exits": {
			"U": {"map": M + "berggrot_grendel.tscn", "spawn": "noord"},
			"n": {"map": M + "berggrot_geheim.tscn", "spawn": "ingang"},
		},
		"signs": [{
			"tile": [16, 7],
			"lines": ["A draft runs along the stone. There is a crack somewhere."],
		}],
		"monsters": [
			{"id": "m1", "enemy": "druipslak", "group": ["druipslak"], "tile": [5, 5], "moves": true},
			{"id": "m2", "enemy": "steenluis", "group": ["steenluis"], "tile": [15, 7], "moves": true},
		],
	},
	"berggrot_uitmond": {
		"name": "Berggrot - Uitmond",
		"floor": 1, "tier": 0, "theme": THEME, "music": BGM, "checkpoint": true,
		"layout": [
			"a------------------b",
			"<LFFMFGFFAFFFFFFFFR>",
			"<lffmfgffnffffffffr>",
			"<Zsssssssssssssssss>",
			"<S#...x.........#..>",
			"<S.................>",
			"<S.........#.......>",
			"<S.................>",
			"<S.@...............>",
			"<S..p.........N....>",
			"<S.................>",
			"c_______(UU)_______d",
		],
		"save": [3, 8],
		"spawns": {"zuid": [9, 10, "up"], "boog": [9, 3, "down"]},
		"exits": {
			"U": {"map": M + "berggrot_geheim.tscn", "spawn": "noord"},
			"n": {"map": KAS_SCENE, "spawn": KAS_SPAWN},
		},
		"signs": [{
			"tile": [4, 5],
			"lines": [
				"On the other side, the greenhouse grows.",
				"You think you are following. Sapientia is leading you.",
			],
		}],
		"monsters": [
			{"id": "m1", "enemy": "adermot", "group": ["adermot"], "tile": [8, 6], "moves": true},
		],
	},
}

## Puzzelkamers, zelfde velden als puzzle_rooms.gd. dungeon_set blijft buiten de
## glitch-graaf van het Eerste Archief (die graaf hoort bij een baas; hier is er geen).
const PUZZLES := {
	"berggrot_grendel": {
		"name": "Berggrot - Grendel",
		"style": "dungeon",
		"theme": THEME,
		"music": BGM,
		"dungeon_set": "berggrot",
		"layout": [
			"#######X#######",
			"#######1#######",
			"#.............#",
			"#..k..........#",
			"#.............#",
			"#......p......#",
			"#.............#",
			"#h............#",
			"#.............#",
			"#r............#",
			"#######E#######",
		],
		"look": [
			"a------n------b",
			"<lfffffnfffffr>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"<S............>",
			"c_____(E)_____d",
		],
		"objects": {
			"k": {"type": "block", "id": "kast_grendel"},
			"p": {"type": "plate", "id": "plaat_grendel", "heavy": true},
			"h": {"type": "lever", "id": "hendel_grendel", "on": false},
			"1": {"type": "gate", "id": "poort_uit", "needs": ["plaat_grendel", "hendel_grendel"],
					"mode": "all", "latch": true},
			"r": {"type": "reset", "id": "herstel_grendel"},
		},
		"spawns": {"noord": [7, 2, "down"]},
		"entrance": {"map": M + "berggrot_mond.tscn", "spawn": "boog"},
		"exit": {"map": M + "berggrot_nerf.tscn", "spawn": "zuid"},
	},
	"berggrot_geheim": {
		"name": "Berggrot - Geheime kamer",
		"style": "dungeon",
		"theme": THEME,
		"music": BGM,
		"dungeon_set": "berggrot",
		"layout": [
			"#################",
			"##T...........U##",
			"##.............##",
			"##.............##",
			"#######,#########",
			"#######G#########",
			"##.............##",
			"##..k......p...##",
			"##.............##",
			"##h............##",
			"##r............##",
			"##.............##",
			"##.............1X",
			"#########E#######",
		],
		"look": [
			"a---------------b",
			"<S..............>",
			"<S..............>",
			"<S..............>",
			"<######n########>",
			"<S.....n........>",
			"<S..............>",
			"<S..............>",
			"<S..............>",
			"<S..............>",
			"<S..............>",
			"<S..............>",
			"<S..............n",
			"c_______(E)_____d",
		],
		"objects": {
			"k": {"type": "block", "id": "kast_ader"},
			"p": {"type": "plate", "id": "plaat_ader", "heavy": true},
			"h": {"type": "lever", "id": "hendel_uit", "on": false},
			"1": {"type": "gate", "id": "poort_uit", "needs": ["hendel_uit"], "mode": "all", "latch": true},
			"r": {"type": "reset", "id": "herstel_geheim"},
			"G": {"type": "secret", "id": "geheime_deur", "needs": ["plaat_ader"], "mode": "all",
					"hint": ["A crack in the stone. Cold air blows through it."],
					"open_lines": ["De steen schuift opzij."]},
			"T": {"type": "chest", "id": "kist_bergnerfstaf", "item": STAF_ID, "n": 1,
					"flag": "kist_bergnerfstaf",
					"lines": ["{naam} opens the chest...", "{naam} finds the Bergnerfstaf!"]},
			"U": {"type": "chest", "id": "kist_adersteen", "item": ACCESSOIRE_ID, "n": 1,
					"flag": "kist_adersteen",
					"lines": ["{naam} opens the chest...", "{naam} finds the Adersteen!"]},
		},
		"spawns": {"noord": [14, 12, "left"]},
		"dek": {"rect": [0, 0, 17, 5], "tiles": []},
		"entrance": {"map": M + "berggrot_nerf.tscn", "spawn": "boog"},
		"exit": {"map": M + "berggrot_uitmond.tscn", "spawn": "zuid"},
	},
}


## De wereldkaart roept Berggrot.start() aan op de grotmond, linksboven op
## worldmap 1 aan de voet van de bergen. Deze functie wisselt naar SCENE met
## spawn SPAWN_INGANG. Spawn WERELD_SPAWN ligt ten zuiden van die mond. De
## andere kant van de grot wijst naar KAS_SCENE (spawn KAS_SPAWN).
static func start() -> void:
	GameState.change_map(SCENE, SPAWN_INGANG)


static func has_enemy(id: String) -> bool:
	return MONSTERS.has(id)


static func enemy(id: String) -> Dictionary:
	var raw = MONSTERS.get(id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func has_gear(id: String) -> bool:
	return id == STAF_ID or id == ACCESSOIRE_ID


## Act 2 begint op level 14 (LevelScale). De staf neemt de mag van de grade-2-staf
## (GradeGear, zelfde band als de rookstaf van Archief 2). De accessoire neemt de
## mdef van de koperring, de Act 2-ring. mag van de steen is die staf-mag / 6.
static func gear(id: String) -> Dictionary:
	var all := _gear()
	var raw = all.get(id, {})
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


static func doel_level() -> int:
	return int(LevelScale.band(2).get("min", 0))


static func staf_mag() -> int:
	return int(GradeGear.item("bg_g2_staf").get("mag", 0))


static func accessoire_mdef() -> int:
	return int(GameData.EQUIPMENT.get("koperring", {}).get("mdef", 0))


static func puzzle(id: String) -> Dictionary:
	var raw = PUZZLES.get(id, {})
	return raw if raw is Dictionary else {}


static func _gear() -> Dictionary:
	var mag := staf_mag()
	var mdef := accessoire_mdef()
	return {
		STAF_ID: {
			"name": "Bergnerfstaf",
			"slot": "wapen",
			"atk": 3,
			"mag": mag,
			"mdef": 3,
			"grade": 2,
			"wie": ["magier", "priester"],
			"price": 0,
			"desc": "A staff from the mountain's vein. It hums softly, as if something grows behind the stone.",
		},
		ACCESSOIRE_ID: {
			"name": "Adersteen",
			"slot": "accessoire",
			"mdef": mdef,
			"mag": maxi(1, int(mag / 6.0)),
			"grade": 2,
			"price": 0,
			"desc": "A cold stone from the mountain vein. It blocks spells and makes them a little sharper.",
		},
	}
