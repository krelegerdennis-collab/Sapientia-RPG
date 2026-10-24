# O-4: flaky `berggrottest` onder load

Bron: `docs/qa/WM1_BUGJACHT.md` (PR #211), punt O-4. Fase 3 (stabiliteit), alleen WM1.

## Reproductie

4 CPU's, Godot 4.3-stable, `xvfb-run`, `--rendering-driver opengl3`, één keer `--import`.
Alleen `berggrottest`, N kopieën tegelijk, elk met een eigen `LOGDIR` (dus eigen `XDG_DATA_HOME`, log en shots):

```bash
for p in $(seq 1 16); do
  ( LOGDIR=/tmp/rep/p$p .github/scripts/run_suite.sh berggrottest ) &
done; wait
```

| load (4 CPU's) | vóór (`main`) | na |
|---|---|---|
| 4 tegelijk (10 rondes) | 2 van 40 gefaald (warper) | 0 van 40 |
| 8 tegelijk (3 rondes) | 0 van 24 | n.v.t. |
| 16 tegelijk (5 rondes) | 29 van 80 gefaald (26 tunnel, 2 warper, 1 xvfb) | 0 van 80 |
| 20 tegelijk (3 rondes) | n.v.t. | 0 van 60 |
| gemengd: 7 tot 8x `berggrottest` + andere suites, 16 tegelijk | 14 van 27 berggrot gefaald | 0 van 24 |

`user://` is geen oorzaak: elke suite heeft een eigen `XDG_DATA_HOME` (`run_suite.sh`) en eigen savebestanden
(`user://berggrottest_save_1.json`). Poorten en tijdelijke paden spelen niet mee (de suite gebruikt geen netwerk).

## Oorzaken (twee, onafhankelijk)

### 1. Physics loopt voor op beelden (26 van de 29 fouten: "open: tunnel leidt de berggrot in")
De speler loopt in `Player._process` (v7, zie commentaar bij `_process`). De testhelper `walk()` in
`berggrot_tests.gd` houdt de toets in en wacht daarna **maximaal 8 `physics_frame`s** tot `is_moving` aan gaat.
Onder CPU-load haalt Godot de physics-achterstand in met tot `max_physics_steps_per_frame` (8) stappen per beeld:
gemeten ongeveer 3 physics-frames per beeld (pf=672 bij prf=241). Die 8 physics-frames zijn dan al voorbij na
2 tot 3 beelden, of zelfs vóór `_process` één keer met de ingedrukte toets draaide. De toets wordt losgelaten
zonder dat de speler is gaan lopen; de test faalt (de tunnel-stap naar `berggrot_mond`).

Fix: voor suites op `GameState.PHYSICS_GELIJK_SUITES` (alleen `berggrottest`) zet de testmodus
`Engine.max_physics_steps_per_frame = 1`. Dan is elk physics-frame ook minstens één beeld.

Bewust niet voor alle suites: gemeten op een gemengde load gingen `menutest` en `woudtest` dan juist stuk
(hun wachttijden in wandkloktijd hangen af van physics die dan langzamer loopt).

### 3. xvfb-run raceconditie (1 van de 29)
`xvfb-run -a` kiest het displaynummer zonder lock. Bij veel suites tegelijk pakken er twee hetzelfde nummer en
start Godot niet (`X11 Display is not available`, 0 testregels). Gezien in 2 van ongeveer 800 runs. Fix in
`.github/scripts/run_suite.sh`: bij precies die melding opnieuw proberen (max. 3x, eigen `XDG_DATA_HOME` schoon).

### 2. De World Warper-flyover gebruikt een klok-seed (2 van de 29: "warper beweegt op de kaart en blijft erbinnen")
`WorldWarperFlyover._ready` seedt zijn route met `Time.get_ticks_usec()`. De test eist dat het schip in 1,5 s
meer dan 20 px verplaatst. Gemeten per seed (zelfde load, zelfde uitkomst, dus geen load-effect):

| seed | afstand | noodduwen (`hard_pushes`) |
|---|---|---|
| 1, 3 tot 7, 9 tot 12 | 117 tot 267 px | 0 tot 4 |
| 2 | 19,9 / 20,9 px | 9 |
| 8 | 22,9 px | 8 tot 10 |

Bij seed 2 en 8 ligt het eerste waypoint achter de touch-D-pad (linksonder). Het schip hangt dan tegen de
knop-zone en wordt steeds teruggeduwd; de afstand zit net op de drempel, dus load beslist of het 19,9 of 20,9 is.
Dit is een toevalsbron die alleen beeld stuurt en geen reden heeft om in een test van de klok af te hangen.

Fix: `GameState.test_modus` (gezet in de testdispatch bij elke `--...test`-suite) laat de flyover seed
`WorldWarperFlyover.TEST_SEED` (3) gebruiken. `seed_override` wint nog steeds. Seed 3 vliegt 165 px met 0 noodduwen.
In het spel zelf (geen testmodus) verandert er niets.

## Nieuwe check
`--testmodustest` (`scripts/tests/testmodus_tests.gd`, 9 PASS): testmodus aan, physics-gelijk-lijst, geen
physics-voorsprong op beelden, vaste warper-seed, `seed_override` blijft winnen. Niet in de CI-matrix
(`tests.yml` is niet aangeraakt); RPG Forge kan hem toevoegen.

## Voor Dennis / Forge (niet gedaan)
- **Spelgedrag, niet in deze PR**: in het spel kan het schip door een waypoint achter de touch-knoppen een paar
  seconden tegen de D-pad blijven hangen en schokken (`hard_pushes` 8 tot 10 in 1,5 s bij seed 2 en 8; het
  veiligheidsnet is pas `t_state > 9`). Voorstel: waypoints weigeren waarvan de rechte lijn door een
  `avoid`-rechthoek gaat, of in CRUISE een nieuw waypoint kiezen na een noodduw. Raakt de vliegroute van een
  art-gerelateerd beeld, dus een keuze voor Forge.
- `warper_kamer_tests.gd:763` heeft dezelfde `gewacht < 8`-helper als `berggrot_tests.gd`. Geen flake gemeten;
  zet de suite op `PHYSICS_GELIJK_SUITES` als hij toch gaat flakken. Een aanpassing van de bestaande tests zelf
  (bijv. wachten op `process_frame` in plaats van `physics_frame` in `walk()`) is de nettere oplossing, maar
  bestaande tests zijn voor deze taak niet aangepast.
- Los van O-4: `menutest` faalt bij 16 tegelijk op 4 CPU's in ongeveer 28 procent van de runs, ook zonder deze
  wijziging (9 van 32 op `main`); bij 10 tegelijk 0 van 30. `codextest` faalde één keer in een gemengde load op `main`.
  Eén CPU-core per parallelle suite is de veilige verhouding.
