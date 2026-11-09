# HANDOFF – Het Gesimuleerde Archief (Blauwe Kisten in Dungeon100)

Branch: `cursor/blue-chests-hoofdgame-29ec`.
Basis: `main` na de samenvoeging van PR #8 (generator), #9 (schaal/buit) en #7 (regels/HUD).

## Lore

De Diepe Grot is **Het Gesimuleerde Archief**: een trainingsomgeving van de **Oude Mensheid**, een simulatie
in een Archief. **Sapientia** heeft haar aangetast via de **Zwarte Stroom** (glitch; `docs/lore/CANON.md` punt 9).

| Spelregel | Verhaal |
|---|---|
| Elke run begint op level 1, zonder uitrusting | Een Deelnemer krijgt een kaal profiel. De echte party blijft buiten de simulatie bewaard. |
| Dood wist levels en tijdelijke spullen en zet je **buiten** de grot | De Zwarte Stroom wist het trainingsprofiel. Je staat weer voor de ingang. |
| Blauwe Kisten blijven | Databanken buiten de simulatie (`docs/lore/Lore_basis.md`: archieven zijn databanken versmolten met magie). |
| Warp-kristal op verdieping 100 | Nooduitgang van de Oude Mensheid. |

CANON: de grot noemt de speler niet ineens 'Proefpersoon H-6' (dat is een latere twist, CANON 3).
Bestaande itemnamen blijven (CANON 11). Roze = de Stroom, zwart/glitch = de Zwarte Stroom.
Dit is een voorstel tot Dennis het in de canon zet; het botst niet met `docs/lore/CANON.md`.

## Dood is dungeon uit

Verplicht. Een nederlaag **in** de grot (party KO):

- de run is voorbij;
- je komt op de **wereldkaart bij de ingang** (`van_dungeon100`), niet op verdieping 1 en niet bij een rustpunt;
- tijdelijke levels, goud, tas en uitrusting van de run zijn weg;
- de momentopname van de echte party/tas/goud/Codex (genomen bij het binnenkomen) komt terug;
- daarna komen de permanente Blauwe-Kist-items in de echte tas (eenmalig, via `dungeon100_delivered`);
- een **nieuwe** run begint pas als je opnieuw naar binnen loopt: verdieping 1, level 1, nieuwe seed.

Het rustpunt van PR #7 **geneest** nog (HP/MP vol + 'Voortgang opslaan?') en onthoudt het verdiepingsnummer,
maar het is **geen** respawn. `Dungeon100Rules.defeat_plan` geeft `leave: true`, `to_dungeon: false`,
`respawn_floor: 0`.

De ladder op verdieping 1 (na bevestiging) en het Warp-kristal doen hetzelfde met de momentopname en de
permanente items. Het kristal werkt alleen op verdieping 100 (`Items` in het veldmenu).

## Blauwe Kisten en Mimics

- Ongeveer **5%** Blauwe Kist, **10%** Mimic, de rest gewoon. Deterministisch uit run-seed + verdieping + kist-id
  (`scripts/data/dungeon100_blue.gd`). Een baaskist is nooit blauw of een Mimic.
- Blauwe buit = één uitrustingsstuk, een niveau boven de gewone kist (bestaande `d100_*`-stukken). Geen goud.
  Het stuk gaat in `GameState.dungeon100_permanent` (save, blok `dungeon100`) én is in deze run bruikbaar.
- Een Mimic lijkt een gewone kist. Openen start `GameState.start_battle(["mimic"], ...)` met
  `Dungeon100Scaling` op de huidige verdieping. Winnen opent de kist; vluchten laat hem dicht.
- Het Warp-kristal zit in de baasbuit van verdieping 100.

## Momentopname

`GameState.dungeon100_begin_run` (bij het laden van `dungeon100.tscn`, eenmalig per run) bewaart party, tas,
goud en Codex. De simulatie krijgt dezelfde groepsleden op level 1, zonder uitrusting, tas = de permanente
items, goud 0. Verhaalvlaggen, kernen en bestiarium blijven van het hoofdspel; kist- en baasvlaggen van
deze run (`kist:d100_`, `bewaker:dungeon100_`, `dungeon100_boss:`) gaan weg aan het eind.

Oordeel: de **hele** party gaat de simulatie in (niet alleen Dennis), allemaal op level 1. Zo raak je Noor
niet kwijt en klopt 'reset party'. Alleen Dennis zou de balans van het hoofdspel minder raken, maar de
opdracht zegt de party terugzetten.

Oordeel: elke run krijgt een **nieuwe seed** (de grot ligt anders). Permanente items zitten in de databank,
niet aan een kist-id vast. Daardoor kun je opnieuw blauwe stukken vinden; afleveren telt niet dubbel.

## Tests

`--dungeon100blauwtest` (`scripts/tests/dungeon100_blauw_tests.gd`), geregistreerd in `game_state.gd`,
`AGENTS.md` en `.github/ci/tests.yml`.

Bestaande suites die de oude respawn op het rustpunt verwachtten (`dungeon100regelstest`,
`dungeon100integratietest`) zijn bijgewerkt. Het rustpunt geneest nog; verdieping 10 heeft nog baas,
rustpunt, HUD en geschaalde monsters.

## Nodig van RPG ART

- `assets/sprites/enemies/mimic.png` — nu een placeholder (80×64, kist met tanden, magenta hoekjes).
  Echt gevechtsplaatje, zelfde maat. Generator: `tools/art_mimic_placeholder.py`.
- `assets/map_monsters/mimic.png` — placeholder 32×64 (2×4 frames van 16×16, magenta hoekjes),
  zodat elke vijand een kaartplaatje heeft. Generator: `tools/art_map_monsters.py`.
- Blauwe kist: geen eigen bestand. De gewone kist (`assets/sprites/buiten/kist.png`, 2×16×16) krijgt
  een blauwe tint in code. Een eigen blauwe variant mag later, zelfde maat als de gewone kist.
