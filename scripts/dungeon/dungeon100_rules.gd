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
## RUSTPUNTEN: elke 10e verdieping (10, 20, ... 100) heeft een rustpunt (scenes/dungeon100_rustpunt.tscn).
##   - aanraken (A) = HP en MP van de hele party (en de Codex-bondgenoot) vol + het rustpunt wordt
##     het CHECKPOINT + de vraag 'Voortgang opslaan?' (zoals een boekpunt);
##   - het checkpoint gaat alleen omhoog (een lager rustpunt opnieuw aanraken verlaagt het niet);
##   - VERLIES (party KO) BINNEN de kerker: heb je een checkpoint, dan ontwaakt de groep op die
##     verdieping bij het rustpunt (HP/MP vol, 25% van het goud kwijt, voortgang blijft). Zonder
##     checkpoint (verdieping 1-9, nog geen rustpunt gehaald) is het de gewone game over: terug naar
##     Wilgendal, helft van het goud kwijt, en de kerker begint weer bij verdieping 1.
##   - game over BUITEN de kerker (verdieping 0) werkt zoals altijd.

const FLOORS := 100
const REST_INTERVAL := 10

## De scène van de kerker (door de generator-branch geleverd) en het spawnpunt voor 'ontwaken bij
## het rustpunt'. Bestaat de scène niet (nog niet gemerged), dan valt een nederlaag terug op Wilgendal.
## (static var i.p.v. const: de generator past de standaardwaarde aan, en de tests wijzen naar een testscène.)
static var dungeon_scene := "res://scenes/maps/dungeon100.tscn"
const REST_SPAWN := "rustpunt"

## Hoeveel goud je houdt na een nederlaag: bij een rustpunt in de kerker 75%, anders 50% (bestaande regel).
const GOLD_KEEP_AT_REST_POINT := 0.75
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


## Plan bij een nederlaag (party KO) op verdieping 'floor_nr' met 'checkpoint':
##   {"respawn_floor": int (0 = naar het dorp), "to_dungeon": bool, "gold_keep": float}
## 'scene_ok' = bestaat de kerker-scène (zie scene_available()).
static func defeat_plan(floor_nr: int, checkpoint: int, scene_ok := true) -> Dictionary:
	var cp := checkpoint if is_rest_floor(checkpoint) else 0
	if is_valid_floor(floor_nr) and cp > 0 and scene_ok:
		return {"respawn_floor": cp, "to_dungeon": true, "gold_keep": GOLD_KEEP_AT_REST_POINT}
	return {"respawn_floor": 0, "to_dungeon": false, "gold_keep": GOLD_KEEP_GAME_OVER}


static func scene_available() -> bool:
	return ResourceLoader.exists(dungeon_scene)


## Opslaan/laden: veilige waarden (kapotte of oude saves geven overal 0).
static func save_data(floor_nr: int, checkpoint: int, best: int) -> Dictionary:
	return {"floor": floor_nr, "checkpoint": checkpoint, "best": best}


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
	return {"floor": floor_nr, "checkpoint": cp, "best": best}


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
