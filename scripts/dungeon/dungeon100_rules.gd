class_name Dungeon100Rules
extends RefCounted
## Regels van de 100-verdiepingen-kerker (taak 'dungeon100-regels'). Alleen pure, statische
## functies + constanten: geen scènes, geen beeld, dus los testbaar (scripts/tests/dungeon100_tests.gd).
##
## Het contract met de rest van het spel:
##   GameState.dungeon100_floor      huidige verdieping 1..100 (0 = niet in de kerker). De generator
##                                   zet dit; HUD en regels doen de rest.
##   GameState.dungeon100_checkpoint laatst geactiveerde rustpunt-verdieping (0, 10, 20, ... 100).
##   GameState.dungeon100_best       hoogste verdieping die ooit bereikt is (0..100).
##
## HET GESIMULEERDE ARCHIEF (Blauwe Kisten, zie HANDOFF_DUNGEON100_BLUECHEST.md): de kerker is een
## simulatie. Een RUN begint bij het binnenkomen vanaf de wereldkaart: de party wordt level 1 zonder
## uitrusting (de echte party + tas + goud + Codex liggen in een momentopname) en je tas bevat alleen de
## PERMANENTE items van eerdere runs (GameState.dungeon100_permanent, uit Blauwe Kisten).
##   - VERLIES (party KO) BINNEN de kerker = de run is voorbij: levels, tas, goud, Codex en het
##     rustpunt van deze run zijn weg, de groep begint opnieuw op verdieping 1 (nieuwe seed). Permanente
##     items en de momentopname blijven. Dit vervangt het 'ontwaken bij het rustpunt' van de eerste
##     regels-versie.
##   - RUSTPUNTEN (elke 10e verdieping: 10, 20, ... 100): aanraken (A) = HP/MP van de hele party (en de
##     Codex-bondgenoot) vol + opslaan ('Voortgang opslaan?'). Het rustpunt wordt ook onthouden als
##     'laatste rustpunt van deze run' (GameState.dungeon100_checkpoint, gaat alleen omhoog; alleen voor
##     de HUD/tekst, het is geen terugkeerpunt meer).
##   - de kerker verlaten: de ladder op verdieping 1 (run opgegeven) of het Warp-kristal van de eindbaas op
##     verdieping 100 (run voltooid; permanente items worden dan ook in je echte tas gelegd).
##   - game over BUITEN de kerker (verdieping 0) werkt zoals altijd.

const Blue := preload("res://scripts/data/dungeon100_blue.gd")

const FLOORS := 100
const REST_INTERVAL := 10

## De scène van de kerker (door de generator-branch geleverd) en het spawnpunt voor 'ontwaken bij
## het rustpunt'. Bestaat de scène niet (nog niet gemerged), dan valt een nederlaag terug op Wilgendal.
## (static var i.p.v. const: de generator past de standaardwaarde aan, en de tests wijzen naar een testscène.)
static var dungeon_scene := "res://scenes/maps/dungeon100.tscn"
const REST_SPAWN := "rustpunt"
## Spawnpunt boven aan de trap van een verdieping (= Dungeon100Generator.SPAWN_FROM_ABOVE): daar begint elke run.
const START_SPAWN := "omhoog"
## Waar je uitkomt als je de kerker verlaat (= Dungeon100Generator.WORLD_SCENE / WORLD_SPAWN).
const WORLD_SCENE := "res://scenes/maps/wereldkaart.tscn"
const WORLD_SPAWN := "van_dungeon100"
## Vlaggen in GameState.story_flags die bij één run horen (kist geopend, bewaker/baas verslagen) en bij het
## einde van de run weggaan. Kist- en kamer-id's bevatten de seed, dus een nieuwe run begint altijd schoon.
const RUN_FLAG_PREFIXES := ["kist:d100_", "bewaker:dungeon100_", "dungeon100_boss:"]

## Hoeveel goud je houdt na een nederlaag: in de kerker niets (het goud van de run was van de simulatie),
## erbuiten de helft (bestaande regel).
const GOLD_KEEP_RUN_LOST := 0.0
const GOLD_KEEP_GAME_OVER := 0.5

const HUD_FORMAT := "Verdieping %d/%d"


## Geldige verdieping van de kerker (1..100)?
static func is_valid_floor(floor_nr: int) -> bool:
	return floor_nr >= 1 and floor_nr <= FLOORS


## Heeft deze verdieping een rustpunt? (10, 20, ... 100)
static func is_rest_floor(floor_nr: int) -> bool:
	return is_valid_floor(floor_nr) and floor_nr % REST_INTERVAL == 0


## Het hoogste rustpunt op of onder deze verdieping (0 = nog geen: verdieping 1-9 of buiten de kerker).
static func checkpoint_for(floor_nr: int) -> int:
	if floor_nr < REST_INTERVAL:
		return 0
	var f := mini(floor_nr, FLOORS)
	return f - f % REST_INTERVAL


## Eerstvolgende rustpunt op of boven deze verdieping (0 = er komt er geen meer: buiten de kerker of na 100).
static func next_rest_floor(floor_nr: int) -> int:
	if floor_nr < 1 or floor_nr > FLOORS:
		return 0
	return floor_nr + (REST_INTERVAL - floor_nr % REST_INTERVAL) % REST_INTERVAL


## Aantal verdiepingen tot het eerstvolgende rustpunt (0 = je staat op een rustverdieping).
static func floors_until_rest(floor_nr: int) -> int:
	var n := next_rest_floor(floor_nr)
	return n - floor_nr if n > 0 else 0


## Moet de HUD getoond worden? (alleen in de kerker)
static func shows_hud(floor_nr: int) -> bool:
	return is_valid_floor(floor_nr)


## Tekst van de HUD: 'Verdieping 12/100'.
static func hud_text(floor_nr: int) -> String:
	return HUD_FORMAT % [clampi(floor_nr, 0, FLOORS), FLOORS]


## Een rustpunt activeren op verdieping 'floor_nr': geeft het nieuwe checkpoint. Gaat nooit omlaag
## en telt alleen op een rustverdieping.
static func checkpoint_after_rest(current_checkpoint: int, floor_nr: int) -> int:
	if not is_rest_floor(floor_nr):
		return current_checkpoint
	return maxi(current_checkpoint, floor_nr)


## Plan bij een nederlaag (party KO) op verdieping 'floor_nr':
##   {"respawn_floor": int (0 = naar het dorp), "to_dungeon": bool, "gold_keep": float, "new_run": bool}
## In de kerker (1..100) en met kerker-scène ('scene_ok'): "new_run" = de run is voorbij, nieuwe run op
## verdieping 1, goud weg. Zonder scène terug naar het dorp (de run wordt dan ook beëindigd).
## Buiten de kerker: de gewone game over (helft van het goud). 'checkpoint' (rustpunt van de run) doet
## niets meer voor het plan; de parameter blijft voor de bestaande aanroepers.
static func defeat_plan(floor_nr: int, _checkpoint: int, scene_ok := true) -> Dictionary:
	if is_valid_floor(floor_nr):
		if scene_ok:
			return {"respawn_floor": 1, "to_dungeon": true, "gold_keep": GOLD_KEEP_RUN_LOST, "new_run": true}
		return {"respawn_floor": 0, "to_dungeon": false, "gold_keep": GOLD_KEEP_RUN_LOST, "new_run": true}
	return {"respawn_floor": 0, "to_dungeon": false, "gold_keep": GOLD_KEEP_GAME_OVER, "new_run": false}


static func scene_available() -> bool:
	return ResourceLoader.exists(dungeon_scene)


## Opslaan/laden: veilige waarden (kapotte of oude saves geven overal 0).
## 'run_seed' = de seed van de generator (0 = nog niet gekozen). 'extra' (optioneel): "permanent"
## (id -> aantal, de Blauwe-Kist-items), "delivered" (id -> aantal al in de echte tas gelegd) en "snapshot"
## (de momentopname van de echte party/tas/goud/Codex tijdens een run, {} = geen run).
static func save_data(floor_nr: int, checkpoint: int, best: int, run_seed := 0, extra := {}) -> Dictionary:
	var d := {"floor": floor_nr, "checkpoint": checkpoint, "best": best, "seed": run_seed}
	d["permanent"] = (extra.get("permanent", {}) as Dictionary).duplicate(true)
	d["delivered"] = (extra.get("delivered", {}) as Dictionary).duplicate(true)
	d["snapshot"] = (extra.get("snapshot", {}) as Dictionary).duplicate(true)
	return d


static func load_data(raw) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var floor_nr := _int_of(d.get("floor", 0))
	if not is_valid_floor(floor_nr):
		floor_nr = 0
	var cp := _int_of(d.get("checkpoint", 0))
	if not is_rest_floor(cp):
		cp = checkpoint_for(cp) if cp > 0 else 0
	var best := clampi(_int_of(d.get("best", 0)), 0, FLOORS)
	best = maxi(best, maxi(floor_nr, cp))
	var snap = d.get("snapshot", {})
	if not (snap is Dictionary) or not (snap.get("party") is Array):
		snap = {}
	return {"floor": floor_nr, "checkpoint": cp, "best": best, "seed": _int_of(d.get("seed", 0)),
			"permanent": clean_counts(d.get("permanent", {})), "delivered": clean_counts(d.get("delivered", {})),
			"snapshot": (snap as Dictionary).duplicate(true)}


## id -> aantal (alleen echte uitrustingsstukken die een Blauwe Kist kan geven, aantal 1..99).
static func clean_counts(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for k in raw:
		var n := _int_of(raw[k])
		if n >= 1 and Blue.is_blue_item(str(k)):
			out[str(k)] = mini(n, 99)
	return out


## Hoort deze story-vlag bij één kerker-run? (zie RUN_FLAG_PREFIXES)
static func is_run_flag(flag: String) -> bool:
	for p in RUN_FLAG_PREFIXES:
		if flag.begins_with(p):
			return true
	return false


static func _int_of(v) -> int:
	return int(v) if (v is int or v is float) else 0


## Hoogste bereikte verdieping bijhouden (HUD en rustpunt roepen dit aan).
static func best_after(best: int, floor_nr: int) -> int:
	return maxi(best, clampi(floor_nr, 0, FLOORS))


## HP en MP van de hele party en de Codex-bondgenoten vol (ook KO = 0 HP komt terug).
static func heal_party(party: Array, codex_pages: Array) -> void:
	for h in party:
		if h is Dictionary:
			h["hp"] = h["max_hp"]
			h["mp"] = h["max_mp"]
	for p in codex_pages:
		if p is Dictionary:
			p["hp"] = p["max_hp"]
			p["mp"] = p["max_mp"]
