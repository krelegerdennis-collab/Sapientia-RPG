# DIAG: flaky `dungeon100gentest` ("speler blijft op de startplek (12,29)")

Symptoom op `main`: één keer `PASS=52 FAIL=1`, daarna weer groen. De FAIL is
`vlak voor de trap (naast (47, 42)): (12, 29)`: de speler is van de ingang niet weggelopen.

## Conclusie in één zin
Geen seed-probleem: het is **timing tussen physics-frames en beelden**. Dit is hetzelfde mechanisme als
O-4 bij `berggrottest` (`docs/qa/O4_BERGGROT_FLAKE.md`).

## Wat het níet is
- **Random seed**: de suite roept `seed(1100)` aan in `_ready`, dus `Dungeon100Room._ready` kiest elke run
  dezelfde run-seed (**1723561898**, gecontroleerd in alle logs). Verdieping 1 is daarmee altijd dezelfde kaart:
  `spawn_up` (12,29), trap omlaag (47,42), een route van 70 stappen, layout "groot" zonder puzzel.
  (12,29) is dus gewoon de vaste ingang en geen toevallige plek.
- **Puzzel-hint / val-dialoog**: verdieping 1 met deze seed is geen puzzel- of valkamer. Met een probe over
  3000 seeds: verdieping 1 is nooit `puzzel` (alleen medium/groot/schat/leeg/kist/rust).
- **Botsing/kaart**: dezelfde route slaagt in 21 van 21 rustige runs.

## Oorzaak
1. De speler loopt in `Player._process` (per beeld, sinds v7). Hij leest de richting met
   `Input.is_action_pressed`.
2. De testhelper `walk()` (`dungeon100_generator_tests.gd:138`) drukt de toets in en wacht dan
   **maximaal 6 `physics_frame`s** tot `is_moving` aan gaat. Daarna laat hij de toets weer los.
3. Na een traag beeld haalt Godot de physics-achterstand in, met tot `max_physics_steps_per_frame` (8)
   physics-stappen vóór de volgende `_process`. Physics draait op 60 Hz. Duurt één beeld ≥ ~100 ms (6/60 s)
   precies op het moment van de toetsdruk, dan zijn alle 6 physics-frames al voorbij voordat `_process`
   de ingedrukte toets één keer heeft gezien. De toets is dan al los en de speler loopt niet.
4. `_walk_route` stopt zodra de volgende routetegel niet naast de speler ligt (`d.length() != 1`). Eén
   verloren stap betekent dus dat de hele route stilvalt. Gaat de **eerste** stap verloren, dan blijft de
   speler op (12,29) staan. De eerste stap komt direct na het laden van de kamer en de fade, precies het
   moment waarop haperende beelden het waarschijnlijkst zijn (eerste render van nieuwe tegels/sprites,
   CI met xvfb en software-GL, CPU-load door parallelle suites).
5. Gevolg in de test: regel 607 zoekt `d["stairs_down"] - tile()` op in een richting-dictionary. Die
   afstand is geen eenheidsvector meer, dus volgt een `SCRIPT ERROR` en stopt deel C. Daarom staat er precies
   **52 PASS / 1 FAIL** in de log in plaats van 69.

## Metingen (Windows, Godot 4.3-stable console, `--rendering-driver opengl3`)

| run | code | resultaat |
|---|---|---|
| 21x gewoon, na elkaar | `main` (ongewijzigd) | 21/21 OK (69 PASS) |
| `--frame-delay 40` | `main` | OK (69 PASS) |
| `--frame-delay 90` | `main` | OK (69 PASS), ~5 physics-stappen per beeld, < 6 |
| `--frame-delay 130` | `main` | **FAIL: PASS=52 FAIL=1** + SCRIPT ERROR op regel 607 (zelfde handtekening als op main; hier ging de 2e stap verloren: speler op (12,30)) |
| `--frame-delay 90 / 130 / 200` | met fix | 3/3 OK (69 PASS, 0 SCRIPT ERROR) |
| 20x gewoon, na elkaar | met fix | 20/20 OK (69 PASS) |
| `--testmodustest` | met fix | OK (9 PASS) |

`--frame-delay N` laat elk beeld N ms slapen en geeft dus een vaste physics-achterstand per beeld. Zo
reproduceer je de hapering die op CI af en toe één keer gebeurt. Vanaf ~100 ms per beeld faalt de test.

## Fix (minimaal, spelcode)
`scripts/game_state.gd`: `dungeon100gentest` toegevoegd aan `PHYSICS_GELIJK_SUITES`:

```gdscript
const PHYSICS_GELIJK_SUITES: Array[String] = ["berggrottest", "dungeon100gentest"]
```

`_zet_testmodus` zet voor die suites `Engine.max_physics_steps_per_frame = 1`. Daarmee kan physics nooit
voorlopen op beelden: 6 physics-frames wachten zijn dan altijd ≥ 6 keer `_process`, dus de speler ziet de
toets altijd. Dit is precies het bestaande "extra net" van O-4. De test zelf en het spelgedrag buiten de
testmodus veranderen niet.

Waarom dit veilig is voor deze suite: `physics_frame` komt alleen voor in `frames()`/`walk()`. Alle andere
wachttijden (`wait_until`, `wait_scene`, `wait_floor`, `wait_fade`) draaien op `process_frame` en wandklok,
en hangen niet af van hoe snel physics loopt. De valkuil van `menutest`/`woudtest` (physics-gebonden
wachttijden op wandkloktijd) speelt hier dus niet. Kaartmonsters worden in de test direct weggehaald
(`clear_monsters`).

## Voor Forge / later (niet in deze wijziging, want de bestaande test mag niet aangepast worden)
- De echte oorzaak zit in de helper zelf: `walk()` hoort te wachten op `process_frame` in plaats van
  `physics_frame`, zoals bij de berggrot-fix. Dan kan de regel in `PHYSICS_GELIJK_SUITES` er weer uit.
- `_walk_route` stopt stil bij een gemiste stap, en regel 607 crasht daarna met een SCRIPT ERROR. Daardoor
  ontbreken in de log 16 checks. Een `if (d["stairs_down"] - tile()).length() == 1` vóór de stap geeft een
  nette FAIL in plaats van een afgebroken suite.
- Dezelfde korte `is_moving`-wacht (6 of 8 frames) staat nog in `checkpoint_tests.gd:154`,
  `dungeon_tests.gd:199`, `codex_tests.gd:956` en `warper_kamer_tests.gd:763`. Die kunnen onder load op
  dezelfde manier flakken, als ze op `physics_frame` wachten (niet per suite nagelopen).
  `archief`/`kern`/`puzzle` wachten 20 frames. Dat is meer dan de 8 inhaalstappen per beeld, dus daar zit
  altijd minstens één `_process` tussen (veilig). Bij een wacht van 8 moet één beeld ≥ ~133 ms duren, bij 6
  al ≥ ~100 ms.
