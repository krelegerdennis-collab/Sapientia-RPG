# HANDOFF – Eerste Archief: Golem-baas Lv 10, Mech. Wachter, geheime deur + runeplaat + schatkist, Vonkzwaard (RPG CODE)

Patch: `/workspace/code_archief1/code_archief1.patch` (op `/workspace/lufia_v14`, snapshot wo 7 okt 2026
19:05:53 CEST; eerste v14-kopie 18:46:52, daarna opnieuw gelijkgetrokken). Werkkopie: `/workspace/code_archief1/`
(= v14 + deze patch). `lufia_v9..v14` zijn NIET aangeraakt. Forge's eigen overdracht: `docs/HANDOFF_ARCHIEF1.md`.
Alle tekst en commentaar Nederlands; geen 'ruben' hardgecodeerd (held = `GameState.MAIN_HERO`); `hd_ui.gd` ongewijzigd.

## 1. Besluiten
| Onderwerp | Besluit |
|---|---|
| Zwaard | **Vonkzwaard** (`vonkzwaard`), vak Wapen, **ATK +12** (keuze Dennis, = 4x Kort zwaard +3), alleen `krijger` (Dennis), prijs 0, `"element": "vuur"` (alleen info). Icoon `res://assets/ui/icons/vonkzwaard.png` (roze-oranje versie van RPG ART, staat al in v14). Toegevoegd aan `GameData.EQUIPMENT` (stond in v14 alleen in de kistdata). |
| Golem-baas | Forge par. 8 als basis: **ATK 33, DEF 22, SPD 6, kern kapot bij >= 45 in het open venster, NIET vluchten**. Eén afwijking: **HP 340 -> 400**, omdat de balans nu uitgaat van het Vonkzwaard +12: met HP 340 won 'alleen aanvallen' op Lv 10 18% (alleen zwaard) tot 39% (met Kaftschild + Leren Kap) en Lv 8 slim 89% (te makkelijk). HP 400 (+18%) vangt de +17% schade van het sterkere zwaard precies op. MAG 16 / MDEF 18, EXP 300, Goud 120. |
| Mech. Wachter | Basis blijft 30/12/8 (SPD 5, EXP 10): Forge's monsterniveaus (`GameData.apply_tier`, kamer-`tier`) maken hem per verdieping sterker. Nieuw trucje **'Schild omhoog'** (20%): DEF x2 voor de rest van de ronde + de volgende ronde, aangekondigd met *'Mechanische Wachter heft zijn schild! (DEF x2)'*, blauwe tint en strook *'…: schild omhoog! (DEF x2)'*. |

## 2. Bestanden (patch)
| Bestand | Wat |
|---|---|
| `scripts/data/game_data.gd` | `vonkzwaard` in EQUIPMENT (+12); Golem `boss`: HP 400 / ATK 33 / DEF 22 / SPD 6 / MAG 16 / MDEF 18, `core.break_damage` 45; `mech_wachter.skills` + 'Schild omhoog' (`type: guard`, `def_mult` 2.0). |
| `scripts/battle/battle.gd` | kleine haken: `can_flee` (uit bij `pending_boss`), `_guard_up` / `_guard_tick` / `_defense_of`, strook via `_core_banner`. |
| `scripts/puzzle/puzzle_logic.gd` | types `secret` (ook `gate` + `style: geheim`), `chest`, `book`, `,`-vloer; 2-tegel-deur (`door_tops`), `chest_flag()` (eigen `flag` of `kist:<id>` zoals DungeonChest), validatie. Forge's `hook` blijft werken. |
| `scripts/puzzle/puzzle_room.gd` | bouwt deur/kist/boek, hint/teksten, kist geven + autosave, deur open -> `reveal_hidden_area()` (Forge's `dek`) en/of `,`-afdekking. |
| `scripts/puzzle/secret_door.gd`, `treasure_chest.gd`, `book_switch.gd` (nieuw), `pressure_plate.gd` (rune-art) | de componenten. |
| `scripts/data/puzzle_rooms.gd` | `archief_puzzel`: G/s/T van `"type": "hook"` naar `secret` / `plate` / `chest` (verder Forge's data), kisttekst 'ATK +12', uitleg in de kop. |
| `assets/puzzle/los_boek.png` | placeholder van mij (alleen voor `book`; niet gebruikt in het Archief). |
| tests | nieuw `scripts/tests/archief_tests.gd` (`--archieftest`, in `game_state.gd` geregistreerd); `golem_tests.gd` (data, balans-sim, Wachter-sim, Lv-10-gevecht); `puzzle_tests.gd` deel C (echte componenten i.p.v. placeholders); `debug_menutest.gd` (13 uitrustingsstukken); `debug_autotest.gd` (baas: 'Vluchten' uit). |

## 3. Plaatsing (zoals Forge's hooks, `archief_puzzel`)
1. In `scripts/data/puzzle_rooms.gd`, kamer `archief_puzzel.objects`: alleen `"type"` aanpassen (zit in de patch):
   `G` -> `"secret"` (16,8)+(16,7), `s` -> `"plate"` (15,9, `heavy` + `hidden` = runeplaat-art), `T` -> `"chest"` (13,3,
   `item: vonkzwaard`, `flag: kist_vonkzwaard`). `hook`/`solid` mogen blijven staan (worden genegeerd).
2. Art: deur `assets/puzzle/geheime_deur_archief.png` (64x32, 4 frames dicht/rune/glitch/open), runeplaat
   `assets/puzzle/drukplaat_rune.png` (32x16), kist `assets/sprites/dungeon/schatkist.png` (48x16: 0 dicht, 1 open,
   2 open+gloed), icoon `assets/ui/icons/vonkzwaard.png`. Bytes gelijk aan `/workspace/art_archief1_v14/out/`.
3. Gedrag in het spel: na poort 1 kast c 1x rechts + 6x omhoog op de runeplaat -> geluid `geheime_deur`, animatie 0->3,
   *'Er klinkt een zwaar schrapen achter de muur...'*, `dek` vervaagt (0,4 s), beide deurtegels beloopbaar, deur
   vergrendeld (`GameState.puzzle_latched`). Dicht + A = Forge's hint. Kist + A: eerst vlag, dan 1x Vonkzwaard,
   frame 2 + icoon, *'{naam} vindt het Vonkzwaard!' / 'ATK +12. Uitrusten: Menu > Uitrusting > Wapen.'*, daarna autosave
   (`"kist"`); daarna *'De kist is leeg.'*.
4. Nieuwe kist/deur elders: teken in de layout + `objects`-regel; `PuzzleLogic.validate` controleert (deur 2 hoog,
   item bestaat, vlag uniek, `needs` alleen naar signalen).

## 4. Stats
| | HP | ATK | DEF | SPD | MAG | MDEF | EXP | Goud | Bijzonder |
|---|---|---|---|---|---|---|---|---|---|
| Golem-baas (v0.15) | 400 | 33 | 22 | 6 | 16 | 18 | 300 | 120 | kern elke 3e ronde open (x2), dicht x0,4, Hamerslag x2,2 tenzij >= 45 schade in het open venster; niet vluchten |
| Mech. Wachter niveau 1 (basis) | 30 | 12 | 8 | 5 | 0 | 4 | 20 (x2) | 8 | Schild omhoog 20%, Zegelslag 15% (x1,4) |
| niveau 2 | 45 | 16 | 11 | 5 | 0 | 4 | 25 | 12 | |
| niveau 3 | 57 | 19 | 13 | 5 | 0 | 4 | 30 | 16 | |
| niveau 4 | 69 | 22 | 15 | 5 | 0 | 4 | 30 | 20 | |
| Vonkzwaard | | +12 | | | | | | | Wapen, alleen krijger |
| Dennis Lv 10 + Vonkzwaard | 123 | 53 | 26 | 18 | | | 1215 | | |

## 5. Simulatie (Golem, Dennis solo, 3 drankjes + 3 kruiden)
Twee onafhankelijke simulaties met dezelfde regels als battle.gd (`ATK x mult - DEF/2`, ±15%, verdedigen = /2):
`golem_tests.gd` (GDScript, 1500 per rij, seed 2026) en `/workspace/.scratch/a1/sim.py` (3000 per rij). Tabel = sim.py,
Vonkzwaard +12. 'slim' = aanvallen, in het open venster altijd raak, genezen bij gevaar; 'domweg' = altijd aanvallen,
nooit genezen; 'nooit_kern' = in het open venster verdedigen.

| Level | slim (alleen zwaard) | items | rondes | domweg | nooit_kern | slim + Kaftschild + Leren Kap | domweg + uitrusting |
|---|---|---|---|---|---|---|---|
| Lv 8 | 74,4% | 5,9 | 14,5 | 0,0% | 0% | 90,5% | 0,0% |
| Lv 10 | 98,7% | 3,8 | 12,6 | 0,3% | 0% | 99,8% | 1,0% |
| Lv 12 | 100% | 2,3 | 11,3 | 74,2% | 0% | 100% | 89,5% |

Ter vergelijking, Forge's HP 340 met +12: Lv 8 slim 89,0%, Lv 10 slim 99,4% / domweg 17,9% (met uitrusting 38,9%).
Klappen Lv 10: open kern 71-97 (altijd >= 45), dicht 17; Golem 20, Hamerslag 60 (Dennis 123 HP). Een zwakke klap
(ATK 25) op de open kern haalt max. 32 -> breekt de lading niet.

## 6. EXP-curve (advies voor Forge)
`exp_for_level(L) = 15 x (L-1)^2`: Lv 8 = 735, Lv 9 = 960, Lv 10 = 1215, Lv 11 = 1500. Forge's 34 gevechten + oefengevecht
= 1311 EXP -> **Lv 10 bij de Golem** (golemtest controleert Lv 9-11). Advies: **curve zo laten**. Wie gevechten
overslaat komt op Lv 8-9 aan: dan zwaar maar te doen (74-90%). De Golem geeft 300 EXP -> Lv 11 erna. Alleen als
spelers structureel onder Lv 9 aankomen: tier-EXP van verdieping 4 x3 -> x3,5 (niet de curve aanpassen).

## 7. Tests (Godot 4.3 en 4.7.2, `/workspace/run_tests_iso.sh`, eigen user://-map)
Gedraaid wo 7 okt 2026 19:07-20:05 CEST op de werkkopie (= v14 + patch), elke suite met eigen user://-map.
`archieftest` daarna opnieuw (20:10, beide versies) na een kleine test-aanpassing (A-druk opnieuw als het tekstvak
niet opengaat; nodig met beeld onder xvfb).

| Suite | Godot 4.3 | Godot 4.7.2 |
|---|---|---|
| `--menutest` | 225 goed / 0 fout | 225 / 0 |
| `--autotest` | 408 / 0 | 408 / 0 |
| `--puzzletest` | 150 / 0 | 150 / 0 |
| `--dungeontest` | 164 / 0 | 164 / 0 |
| `--golemtest` | 62 / 0 | 62 / 0 |
| `--archieftest` (nieuw) | 89 / 0 | 89 / 0 |

Geen SCRIPT ERRORs. Met beeld (xvfb, OpenGL, Godot 4.3) ook groen: archieftest 89/0, golemtest 62/0.
De patch is getest op een verse kopie van `/workspace/lufia_v14` (`git apply --check`, daarna identiek aan de werkkopie).
`archieftest` dekt: logica (2-tegel-deur, vergrendeling, herstelsteen, set_state, validatie), de echte route in de
kamer (hint, kast c op de runeplaat, deur open, door beide deurtegels, kist), zwaard precies 1x, vlag in save +
autosave, opnieuw binnenkomen, laden, oude save (save-scum) -> nooit 2 zwaarden, Sterkste, uitrustingsscherm
(pijl ATK +9 t.o.v. Kort zwaard, uitgerust basis +12), 'Schild omhoog' in een echt gevecht.

## 8. Screenshots (`/workspace/code_archief1_shots/`, elk + `_3x` 1152x648)
Gemaakt onder xvfb (OpenGL, Godot 4.3) met `--archieftest` / `--golemtest` `--shots=/workspace/code_archief1_shots`,
op een verse v14-kopie + patch. Alle bekeken.

| Bestand | Wat je ziet |
|---|---|
| `archief_geheim_dicht.png` | Dennis onder de dichte geheime deur (16,8)+(16,7), runeplaat naast hem, schatkamer nog afgedekt |
| `archief_geheim_open.png` | kast c op de runeplaat, deur open (frame 3), schatkamer zichtbaar met de dichte kist |
| `archief_kist_zwaard.png` | tekstvak 'Dennis vindt het Vonkzwaard!' (de kist zelf zit onder het tekstvak, zie open vragen) |
| `archief_kist_open.png` | direct daarna: open kist, Dennis ervoor |
| `archief_uitrusting_zwaard.png` | Uitrusting > Wapen: Vonkzwaard x1, ATK 17 -> 26 (groene pijl), onderregel 'Vonkzwaard: ATK +12' |
| `archief_wachter_schild.png` | Mech. Wachter met blauwe tint, strook 'Mech. Wachter: schild omhoog! (DEF x2)' |
| `golem_kern_dicht.png`, `golem_kern_open.png`, `golem_kern_raak.png`, `golem_hamerslag.png` | Golem-baas, Dennis Lv 10 (123 HP) met Vonkzwaard: open kern ('Roze kern open! Val nu aan!'), klap 94 op de kern, Hamerslag verdedigd (26); knop Vluchten grijs |

Elk bestand ook als `*_3x.png` (1152x648).

## 9. Open vragen
- **HP 400 i.p.v. 340** (door het +12-zwaard): akkoord Forge/Dennis? Alternatief met HP 340: ATK 35 + DEF 25 (Lv 10 slim 97,8%, domweg 0,6% maar met uitrusting 16,8%; Lv 8 slechts 53,8%). HP 400 houdt Forge's ATK/DEF en de klapgroottes gelijk.
- Mech. Wachter staat in v14 al op tier 1-4; zijn trucje werkt op elk niveau. Vindt Forge 20% kans goed?
- `kort_zwaard` (+3) blijft voorlopig; ontwerp had Kort Zwaard +7 (winkel). Met +12 voor het Vonkzwaard is het gat groot.
- `"element": "vuur"` op het Vonkzwaard doet nog niets (Golem is zwak voor vuur: bewust niet meegerekend in de sim).
- Drankje geneest 30 (Dennis Lv 10 heeft 123 HP): items voelen zwak; de sim gaat hiervan uit.
- `los_boek.png` is mijn placeholder (alleen voor het herbruikbare `book`, niet in het Archief).
- Forge's placeholderscripts `scripts/puzzle/hooks/ph_*.gd` worden niet meer gebruikt in `archief_puzzel`; laten staan of weghalen (Forge).
- Het tekstvak staat altijd bovenin; in de schatkamer (bovenaan de kaart) valt de kist eronder, dus het Vonkzwaard-icoon boven de kist is tijdens het bericht nauwelijks te zien. Tekstvak onderin als de speler bovenin staat? (Forge/ART)
- Item-iconen van RPG ART (`assets/ui/icons/<id>.png`) zijn nog niet in de menu's gekoppeld (Forge, optioneel).
