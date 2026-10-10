# HANDOFF – Dungeon 100: regels, rustpunten en HUD (branch `cursor/dungeon100-regels`)

Taak #5 van de 100-verdiepingen-kerker. Parallel met `dungeon100-generator` (verdiepingen, trappen,
ingang) en `dungeon100-schaal-loot` (monsterschaal, kisten, baas op elke 10e verdieping).
Alles hier werkt zodra de generator `GameState.dungeon100_floor` zet.

## 1. Contract

| Wat | Waar |
|---|---|
| Huidige verdieping `1..100`, `0` = niet in de kerker | `GameState.dungeon100_floor` (`var dungeon100_floor: int = 0`; de generator zet dit, ook bij het verlaten van de kerker weer op 0) |
| Laatst geactiveerd rustpunt (0, 10, ... 100) | `GameState.dungeon100_checkpoint` |
| Hoogste bereikte verdieping | `GameState.dungeon100_best` |
| Regels (pure statische functies) | `scripts/dungeon/dungeon100_rules.gd` (`class_name Dungeon100Rules`) |
| Rustpunt (script + scène) | `scripts/dungeon/dungeon100_rustpunt.gd` + `scenes/dungeon100_rustpunt.tscn` |
| HUD | `scripts/ui/dungeon100_hud.gd` (hangt GameState zelf aan de root; niets te doen voor de generator) |
| Tests | `scripts/tests/dungeon100_tests.gd` (`--dungeon100regelstest`) |

Alle drie de waarden gaan mee in de save (blok `"dungeon100": {floor, checkpoint, best}`); oude of
kapotte saves laden met 0. `new_game()` en `go_to_title()` zetten de verdieping terug op 0.

## 2. Regels

- **Rustpunt elke 10 verdiepingen**: 10, 20, ... 100 (`Dungeon100Rules.is_rest_floor(f)`).
- **Aanraken (A)**: HP en MP van de hele party (en de Codex-bondgenoot) vol, ook KO; het verdiepingsnummer
  wordt het **checkpoint** (gaat alleen omhoog); daarna de vraag *Voortgang opslaan?* (Ja/Nee, zoals een boekpunt).
- **Verlies (hele party KO) in de kerker** is sinds de Blauwe Kisten niet meer een respawn op het rustpunt.
  **Dood is dungeon uit**: wereldkaart bij de ingang (`van_dungeon100`), tijdelijke run weg, echte party terug,
  Blauwe Kist-items blijven. Het rustpunt geneest alleen. Zie `HANDOFF_DUNGEON100_BLUECHEST.md`.
  Buiten de kerker (verdieping 0) werkt game over zoals altijd.
- Winnen of vluchten verandert de verdieping niet.
- Een rustpunt wordt pas een checkpoint als je het **aanraakt**, niet als je de verdieping alleen binnenloopt.
  Staat het rustpunt achter de baas van de 10e verdieping (aanrader), dan verlies je de baas niet "gratis".

### API `Dungeon100Rules` (allemaal `static`)
`is_valid_floor(f)`, `is_rest_floor(f)`, `checkpoint_for(f)` (hoogste rustpunt <= f, 0 onder 10),
`next_rest_floor(f)`, `floors_until_rest(f)`, `shows_hud(f)`, `hud_text(f)` ("Verdieping 12/100"),
`checkpoint_after_rest(cp, f)`, `defeat_plan(f, cp, scene_ok := true)` -> `{respawn_floor: 0, to_dungeon: false, leave, gold_keep}` (in de kerker: leave, niet verdieping 1),
`best_after(best, f)`, `heal_party(party, codex_pages)`, `save_data(...)`, `load_data(raw)`, `scene_available()`.
Constanten: `FLOORS`, `REST_INTERVAL`, `REST_SPAWN = "rustpunt"`, `WORLD_SPAWN = "van_dungeon100"`, `GOLD_KEEP_RUN_LOST` (1.0, echte goud terug), `GOLD_KEEP_GAME_OVER`.

## 3. Wat de generator moet doen

1. `GameState.dungeon100_floor = n` zetten bij elke verdiepingswissel (en `= 0` bij het verlaten van de kerker).
2. Op `Dungeon100Rules.is_rest_floor(n)` een rustpunt neerzetten:
   `objects.add_child(Dungeon100Rustpunt.create(Vector2i(x, y)))` (of de scène `scenes/dungeon100_rustpunt.tscn`).
   Het is een gewoon blokkerend object met `interact(player)`, 1 tile.
3. **Pad van de kerker-scène**: `Dungeon100Rules.dungeon_scene` (standaard `res://scenes/maps/dungeon100.tscn`).
   Bij verlies doet `GameState.end_battle("lose")` een scènewissel naar de **wereldkaart** (`WORLD_SCENE`),
   spawn `van_dungeon100`, verdieping 0. Niet naar het rustpunt.
4. Opslaan in de kerker bewaart de verdieping. Na laden is `dungeon100_floor` weer die waarde en `return_map` /
   `tile` de plek in de scène: de generator moet een verdieping dus deterministisch kunnen herbouwen
   (bv. seed uit het verdiepingsnummer) of bij `has_return_point` een veilige tile kiezen.

## 4. HUD

Pilletje linksboven, **"Verdieping X/100"**, zelfde stijl en hoogte als de MENU-knop van de touch-besturing
(rechtsboven; `scripts/touch_controls.gd`), palet `UiStyle` (inkt, perkamentrand, crème tekst, getal in goud).
Op rustverdiepingen heeft het pilletje een gouden rand en een klein cyaan puntje.
Zichtbaar bij `dungeon100_floor` 1..100 en niet in een gevecht; anders verborgen. Laag 4: onder het tekstvak (5),
de touch-knoppen (10) en het veldmenu (20); vangt geen tikken. Kost per frame alleen twee vergelijkingen.
Het links-boven-hoekje is vrij op alle kaarten (D-pad linksonder, MENU rechtsboven, KERN/A/B rechtsonder);
alleen een tekstvak dat in de uitzonderlijke "bovenin"-stand staat dekt het af.

## 5. Bestanden en haakjes in bestaande code

Nieuw: `dungeon100_rules.gd`, `dungeon100_rustpunt.gd`, `dungeon100_rustpunt.tscn`, `dungeon100_hud.gd`,
`dungeon100_tests.gd`, dit bestand.
Aangepast (klein): `scripts/game_state.gd` (vars; HUD aanhangen in `_ready`; testregel; `new_game`/`save_game`/
`load_game`/`go_to_title`; `respawn()` en `end_battle("lose")` voor het nederlaag-plan; `dungeon100_load()`),
`scripts/data/book_data.gd` (type `rustpunt`), `.github/ci/tests.yml` (suite `dungeon100regelstest` in de matrix).
`AGENTS.md` (suite-tabel) bevat de suite (`--dungeon100regelstest`).

## 6. Nodig van RPG ART (placeholder)

Het rustpunt hergebruikt het opslagboek (`assets/sprites/save_book.png`), warm getint in code, met een gouden
aura: **PLACEHOLDER**, er is geen nieuw bestand toegevoegd (dus niets te registreren in `tools/placeholders_*.txt`).
Gewenst: eigen rustpunt-sprite, 64x16 (4 frames van 16x16, zoals `save_book.png`), in het palet van de Archieven.
De HUD heeft geen art nodig (alles in code, UiStyle-kleuren).

## 7. Tests

`godot -- --dungeon100regelstest [--shots=map]`: 74 PASS.
Deel A regels (rustverdiepingen, checkpoint_for voor alle 100, nederlaag-plan, load_data met rommel),
B GameState (nieuw spel, save/load incl. oude/kapotte saves, `respawn()`), C HUD (verborgen/zichtbaar, gevecht,
tekst, plek, geen botsing met de touch-knoppen), D rustpunt-scène (genezen, checkpoint alleen omhoog, opslaan Ja/Nee),
E echte scènewissel bij verlies (met en zonder checkpoint) via `end_battle("lose")` met een stand-in scène.
Screenshots (`d100_hud_floor12`, `d100_hud_floor10_rust`, `d100_hud_floor100`, `d100_rustpunt_floor30`).
