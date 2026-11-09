# HANDOFF – Dungeon van 100 verdiepingen: monsterschaal en buit (Task #4)

Branch `cursor/dungeon100-schaal-loot`. Alle getallen zijn **VOORLOPIG** (nog niet gebalanceerd met een simulatie).
Zusterbranches (inmiddels samengevoegd): `dungeon100-generator` (vloeren, trappen, ingang) en `dungeon100-regels` (rustpunten, HUD "Verdieping X/100").

## Contract

- `GameState.dungeon100_floor: int` = huidige verdieping, `1..100`, `0` = niet in de dungeon. (Na de samenvoeging met de generator
  en de regels staat hij in de save, naast `dungeon100_seed`, `dungeon100_checkpoint` en `dungeon100_best`.)
- Bij `0` verandert er **niets** aan bestaand gedrag (getest: monsters, baasgevecht van de Golem, kisten, `TIERS`).
- Bij `> 0` gebruikt een gevecht de schaal van die verdieping i.p.v. het kamerniveau (`pending_tier`/`TIERS`).

## API – `scripts/data/dungeon100_scaling.gd`

Pure statische functies, geen scène/autoload nodig. `const S := preload("res://scripts/data/dungeon100_scaling.gd")`.

| Functie | Wat |
|---|---|
| `S.is_boss_floor(f)` | `true` voor 10, 20, ... 100 |
| `S.is_final_floor(f)` | `true` alleen voor 100 |
| `S.boss_floors()` / `S.boss_index(f)` | `[10..100]` / 1..10 (0 = geen baasverdieping) |
| `S.boss_for_floor(f)` | `{"floor","index","enemy","name","final"}` of `{}`; `enemy` = bestaande vijand-id (sprite + skills, **placeholder-art**) |
| `S.monster_stats(base, f)` | kopie van vijand-data met geschaalde `max_hp/atk/def/agi/(mag/mdef)/exp/gold`; `f <= 0` geeft `base` ongewijzigd terug; `f = 1` = basiswaarden |
| `S.boss_stats(base, f)` | baasversie (stats uit `BOSS_BASE` x curve x `BOSS_MULT`, eindbaas + `FINAL_MULT`, baasnaam, geen roze kern); `f <= 0` = `base` |
| `S.battle_enemy(data, f, boss)` | wat `battle.gd` aanroept (`boss` = `GameState.pending_boss`) |
| `S.tier_for_floor(f)` | buitniveau 1..5 (1-20 = 1, 21-40 = 2, ... 81-100 = 5; 0 buiten de dungeon) |
| `S.chest_loot(f, rng, boss := false)` | `{"tier","items":[{"item","n"}],"gold","boss"}`; altijd >= 1 genees-item + goud, uitrusting met kans `gear_chance(f)` (15% -> 40%), soms een Leeg Boek (vanaf niveau 2) |
| `S.boss_loot(f, rng)` | gegarandeerd: goud (6x kist), uitrusting een niveau BOVEN de kisten (max. 5), genees-items (+2). Verdieping 100: van elke soort niveau 5, 5 elixers, 5x zoveel goud |
| `S.grant_loot(loot, inventory)` | legt items in de tas, geeft het goud terug (aanroeper telt `GameState.gold` op) |
| `S.loot_lines(loot)` / `S.loot_text(loot)` | Nederlandse tekst ("2x Drankje", "Archiefzwaard", "120 goud") |
| `S.monster_entry(enemy, f, tile, id := "")` | monster-dict voor `MapMonster.setup` (met `"floor"`) |
| `S.boss_entry(f, tile)` | baas-dict (`"boss": true`, stil, `group = [enemy]`); `{}` op een gewone verdieping |
| `S.chest_entry(f, id, tile, rng, boss := false)` | kist-dict met vooraf gerolde `"loot"` (+ `"item"/"n"` van het eerste voorwerp) |
| `S.boss_flag(f)` / `S.boss_defeated(f, flags)` | story-vlag `dungeon100_boss:<f>` (gezet na een gewonnen baasgevecht in de dungeon) |

### Schaalformules (`n = verdieping - 1`)

| Stat | Formule |
|---|---|
| HP | `basis x (1 + 0,10n + 0,0015n²) + 2n` |
| ATK | `basis x (1 + 0,03n) + 0,8n` (MAG idem met `+0,5n`) |
| DEF | `basis x (1 + 0,03n) + 0,5n` (MDEF idem) |
| SPD | `basis + 0,1n` |
| EXP | `basis x (1 + 0,10n + 0,006n²)` |
| Goud | `basis x (1 + 0,10n + 0,002n²)` |

Afronden half naar even (`GameData.round_half_even`). Mosslijm (HP 10, ATK 7, EXP 3) wordt op 100: HP ~450, ATK ~127, EXP ~210. Bazen:
`BOSS_BASE` (HP 120, ATK 24, DEF 14, ...) door dezelfde curves, daarna HP x2,5, ATK x1,25, DEF x1,2, EXP/goud x5;
eindbaas nog HP x1,3, ATK x1,15, DEF x1,1, EXP/goud x3 en de extra skill "Laatste Oordeel". De 10 bazen
(naam + sprite van een bestaande vijand) staan in `BOSSES`; de namen en sprite-keuze zijn placeholders (geen eigen art, geen lore).

## Hooks in bestaande code (minimaal)

- `scripts/battle/battle.gd` `_spawn_enemies`: `dungeon100_floor > 0` -> `battle_enemy(...)` (baas of gewoon); anders de oude
  `apply_tier`-weg. `_victory` -> `_dungeon100_boss_loot()`: na een baas (`pending_boss`) de baasbuit in de tas, goud erbij,
  baasvlag zetten en een extra overwinningspagina "Buit van de baas!". Niet vluchten voor een baas bleef zoals het was.
- `scripts/dungeon/dungeon_chest.gd`: op een verdieping > 0 (eigen `"floor"` in de data of `GameState.dungeon100_floor`)
  en zonder vast `"item"`: `"loot"` uit de data, of deterministisch gerold uit kist-id + verdieping (`"boss": true` = baaskist).
  Kist-ids moeten dus per verdieping uniek zijn (de vlag `kist:<id>` is eenmalig per spel). Kisten met `"item"` blijven vast.
- `scripts/dungeon/map_monster.gd`: `floor_nr` (data `"floor"` of `GameState.dungeon100_floor`) en `scaled_stats()` (voor UI/tests).
  Het gevecht zelf schaalt via `GameState.dungeon100_floor`.
- `scripts/data/game_data.gd`: 3 nieuwe items (`sterk_drankje`, `toverbrouwsel`, `elixer`) en 24 uitrustingsstukken
  `d100_<zwaard|staf|schild|helm|harnas|ring>_<2..5>` (niet te koop; niveau 1 = de bestaande stukken). Welk stuk waar valt: `GEAR`.

## Voor de generator (gebruik)

```gdscript
GameState.dungeon100_floor = 37                       # bij het betreden van een verdieping
var m := S.monster_entry("papiergeest", 37, Vector2i(5, 4))
var boss := S.boss_entry(40, Vector2i(8, 6))           # alleen op 10, 20, ... 100 (anders {})
var chest := S.chest_entry(37, "k37_a", Vector2i(2, 2), rng)
```

Een baas kan terugkomen na laden als de generator `S.boss_defeated(f, GameState.story_flags)` niet checkt.
Verlaat de speler de dungeon: zet `GameState.dungeon100_floor` weer op 0 (anders schalen gewone gevechten door).

## Tests

`godot --path . -- --dungeon100schaaltest` (of `.github/scripts/run_suite.sh dungeon100schaaltest`), `scripts/tests/dungeon100_schaal_tests.gd`:
verdiepingen/bazen/buitniveaus, monotone schaling (alle gewone vijanden, 1..100), bazen sterker dan monsters en per
baasverdieping sterker, verdieping 0 = ongewijzigd, buit (niveau stijgt, deterministisch, ids bestaan, baasbuit beter),
spawn-dicts, `DungeonChest`, `MapMonster` en echte `Battle`-scènes (monster, baas 30, eindbaas 100, verdieping 0 + Golem-baas).
De suite zit in de CI-matrix (`.github/ci/tests.yml`).

## Nodig van RPG ART

Niets verplicht. Optioneel: eigen art voor de 10 bazen (nu hergebruik van bestaande vijand-sprites) en iconen voor de
nieuwe items/uitrusting (`assets/ui/icons/`, 16x16: `sterk_drankje`, `toverbrouwsel`, `elixer`, `d100_*`).
