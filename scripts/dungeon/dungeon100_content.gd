extends RefCounted
## DUNGEON100 INHOUD per verdieping: welke monsters, kisten, baas en rustpunt op de slots van de
## generator komen. Dit is de ENIGE plek waar de generator iets van spelbalans weet; alle getallen
## komen uit de zusterbestanden:
##   - monsters/kisten/bazen: scripts/data/dungeon100_scaling.gd (Dungeon100Scaling: stats per
##     verdieping, buit, de baas van elke 10e verdieping),
##   - rustpunt: scripts/dungeon/dungeon100_rules.gd (Dungeon100Rules.is_rest_floor) + het object
##     Dungeon100Rustpunt, dat Dungeon100Room op room["rustpunt"] zet.
##   tier_for_floor(f)      kamerniveau 1-4 voor game_data.gd TIERS (room["tier"]; o.a. Codex-vangniveau;
##                          de stats van de vijanden komen in de dungeon uit Dungeon100Scaling)
##   monsters(data)         Array met "monsters"-regels (formaat: scripts/data/dungeon_rooms.gd)
##   chests(data)           Array met "chests"-regels (geschaalde buit, vooraf gerold)
##   boss(data)             baas op data["boss_slot"] (BOSSES; niet op verdieping 100), anders {}
##   fill_room(room, data)  zet alles in de kamerdata: "monsters" (incl. baas), "chests", "rustpunt"
## 'data' = het resultaat van Dungeon100Generator.generate() (zonder "room"): "floor", "floor_seed",
## "monster_slots", "chest_slots", "boss_slot", "rest_slot", "is_boss_floor", ...
## Alles is deterministisch: de willekeur komt uit data["floor_seed"], nooit uit randi().

const Scaling := preload("res://scripts/data/dungeon100_scaling.gd")
const Rules := preload("res://scripts/dungeon/dungeon100_rules.gd")
const Blue := preload("res://scripts/data/dungeon100_blue.gd")

## Vijanden van de Diepe Grot: ALLE gewone bestiarium-monsters, in de volgorde van het verhaal
## (Dennis): Archief 1 > Donker Woud > Bergtunnel > Archief 2. Elk blok heeft een venster
## [from, tot]: vroege gebieden op lage verdiepingen, latere dieper. De stats schalen per verdieping
## (Dungeon100Scaling.monster_stats). Bazen, unieke monsters, ECHO en de Mimic (kist) zitten er niet in.
const POOLS := [
	{"gebied": "archief1", "from": 1, "tot": 40, "enemies": ["mosslijm", "moskonijn", "papiergeest"]},
	{"gebied": "archief1", "from": 11, "tot": 55, "enemies": ["glitchmot", "mech_wachter"]},
	{"gebied": "woud", "from": 26, "tot": 80, "enemies": ["wortelkruiper", "mistuil", "sporenzwam", "woudgeest"]},
	{"gebied": "bergtunnel", "from": 51, "tot": 100, "enemies": ["steenluis", "druipslak", "adermot"]},
	{"gebied": "archief2", "from": 76, "tot": 100, "enemies": ["rankje", "sporekop", "doornige_loper", "bloeiende_schrik", "wortelgeest"]},
	# Grot-eigen monsters (alleen hier; vangbaar en je houdt ze, CodexData.GROT_BEHOUD). Venster = tegelvariant:
	# v6 = 76-90, v7 = 91-100 (Dungeon100Generator.theme_variant).
	{"gebied": "diepe_grot", "from": 76, "tot": 90, "enemies": ["shard_codex", "scanline_wolf"]},
	{"gebied": "diepe_grot", "from": 91, "tot": 100, "enemies": ["aureate_watcher", "ledger_scarab"]},
]
## Uitbreiden: een regel {"gebied", "from", "tot", "enemies"} toevoegen. Grot-eigen monsters met een
## smal venster (bv. 76-90) gaan zo ook; enemy_pool() kijkt alleen naar from/tot.
## Volgorde van de gebieden (voor tests en uitbreiding met nieuwe gebieden).
const GEBIEDEN := ["archief1", "woud", "bergtunnel", "archief2", "diepe_grot"]


## Alle monsters uit de pools, in volgorde.
static func all_pool_enemies() -> Array:
	var out: Array = []
	for p in POOLS:
		for e in p["enemies"]:
			if not out.has(e):
				out.append(e)
	return out


## Monsterniveau (TIERS 1-4): per 25 verdiepingen een stap.
static func tier_for_floor(floor_no: int) -> int:
	return clampi(1 + (floor_no - 1) / 25, 1, 4)


static func enemy_pool(floor_no: int) -> Array:
	var out: Array = []
	for p in POOLS:
		if floor_no >= int(p["from"]) and floor_no <= int(p["tot"]):
			out.append_array(p["enemies"])
	return out


static func monsters(data: Dictionary) -> Array:
	var f: int = data["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["floor_seed"]) + 101
	var pool := enemy_pool(f)
	var out: Array = []
	var i := 0
	for t in data["monster_slots"]:
		i += 1
		var size := 1 + (1 if rng.randf() < 0.25 + f / 200.0 else 0) + (1 if f > 40 and rng.randf() < 0.3 else 0)
		var group: Array = []
		for k in size:
			group.append(pool[rng.randi_range(0, pool.size() - 1)])
		var m := Scaling.monster_entry(group[0], f, t, "m%d" % i)
		m["group"] = group
		out.append(m)
	return out


## Kisten op de kist-slots; buit en goud schalen met de verdieping (Dungeon100Scaling.chest_entry).
## Per kist is deterministisch bepaald of hij gewoon, BLAUW (permanente buit) of een MIMIC is ("kind", zie
## dungeon100_blue.gd).
static func chests(data: Dictionary) -> Array:
	var f: int = data["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["floor_seed"]) + 202
	var out: Array = []
	var i := 0
	for t in data["chest_slots"]:
		i += 1
		out.append(Blue.chest_entry(int(data["run_seed"]), f, "d100_%d_%d_%d" % [int(data["run_seed"]), f, i], t, rng))
	return out


## De baas van een baasverdieping op boss_slot (2x2 tegels, past de Golem-sprite). Verdieping 100 niet.
## "guard": een verslagen baas blijft weg (vlag in de save, kamer-id bevat de run-seed).
static func boss(data: Dictionary) -> Dictionary:
	var f: int = data["floor"]
	var t: Vector2i = data["boss_slot"]
	if not Scaling.is_boss_floor(f) or t.x < 0:
		return {}
	var b := Scaling.boss_entry(f, t)
	b["guard"] = true
	b["sprite"] = "golem"
	b["size"] = [2, 2]
	b["frame"] = [32, 32]
	b["fps"] = 1.2
	return b


static func fill_room(room: Dictionary, data: Dictionary) -> void:
	var mons: Array = monsters(data)
	var b := boss(data)
	if not b.is_empty():
		mons.append(b)
	room["monsters"] = mons
	room["chests"] = chests(data)
	var rp: Vector2i = data["rest_slot"]
	var extra_rust := str(data.get("layout_type", "")) == "rust"      # gerolde RUST ROOM (3%)
	if (Rules.is_rest_floor(int(data["floor"])) or extra_rust) and rp.x >= 0:
		room["rustpunt"] = [rp.x, rp.y]
