# WM1-playthrough-suite (`--wm1playthroughtest`)

Release-fase 3 (stabiliteit). Eén headless suite die World Map 1 van "Nieuw spel" tot het einde speelt en
daarbij crashes, scriptfouten, softlocks en voortgangsblokkades zoekt. Alleen WM1; `wacht/wm2/` komt er niet in voor.

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64 .github/scripts/run_suite.sh wm1playthroughtest
# alleen de statische audit (spelertekst + kamerdata, ~2 s):
GODOT=... .github/scripts/run_suite.sh wm1playthroughtest --static-only
```

Script: `scripts/tests/wm1_playthrough_tests.gd`. Registratie: één regel in `scripts/game_state.gd` (`_ready()`).
De suite draait standaard op `Engine.time_scale` 2 (`--speed=1` voor echte snelheid, bij fouten zoeken handig). Duur lokaal
ongeveer 6 tot 8 minuten (op snelheid 1 ongeveer 11). `run_suite.sh` geeft 20 minuten.

## Het pad

| # | Stap | Hoe |
|---|---|---|
| 0 | Statische audit | Nederlandse spelertekst in verhaal-, kamer- en Archief 2-data en in `Dialog.show_lines`/`ask`-literals; kamerdata die in `dungeon_room.gd` een `push_error` geeft (teken zonder legenda, uitgang zonder doel) |
| 1 | Proloog | `start_new_game`, echt lopen, Opa, mantel + menu sluiten, klusjes, zwaardles + oefengevecht, catastrofe, opgesloten, keuze, nacht |
| 2 | Archief 1 | poorten dicht voor de Golem, 12 kamers echt lopen (BFS-pad met toetsen), puzzelkamer oplossen, Golem eerst verliezen (checkpoint) en dan winnen, uitgang-warper |
| 3 | Esdoorn + Donker Woud | ontmoeting, herberg, opslagboek, Vesper-huis, 5 woudkamers, Wortelkoning, Vesper sluit aan, `menu_sweep` |
| 4 | Het Zingende Graan | opdracht, zaad (gevecht), molen met opslaan |
| 5 | Kas direct | wereldkaart -> kas -> Kasgang en terug |
| 6 | Berggrot | bouwplaats (dicht zonder Vesper, open met), 5 kamers waarvan 2 puzzelkamers |
| 7 | Archief 2 | platen, Seren (verlies = verhaal, ze sluit aan), Strangler, Mender, kern-absorptie, filmpje, canon-scène 1 |
| 8 | Hub = einde WM1 | Hal, canon-scènes 2 en 3, veldmenu-sweep, opslaan, app gedood en doorgaan |
| 9 | Action-stijl | de standaardstijl van een nieuw spel in een dungeon: pauze, opslaan/laden, lopen |
| 10 | Volgordebreuk | direct na de Golem de kas in (zonder Vesper en berggrot) tot en met de hub |

## Opslaan en pauze

* `save_roundtrip`: `save_game` -> `new_game` (wissen) -> `continue_slot` (de echte slotcode) -> `state_data` voor en na moet gelijk zijn, de speler staat op dezelfde tegel, niets blijft hangen. Punten: proloog (TAKEN, nacht in huis, nacht op het erf), Archief 1 (verdieping 3, na de Golem), Esdoorn, woud, met Vesper, Wilgendal, berggrot, Archief 2 met Seren en na de Strangler, hub, Action-stijl. Plus opslaan terwijl de huisdeur op slot zit.
* `pause_resume`: `NOTIFICATION_APPLICATION_PAUSED` en `RESUMED` rechtstreeks naar `GameState`. Vrij op een kaart = autosave "achtergrond" die gelijk is aan de staat op dat moment. Tekstvak, gevecht, cutscene, kaartwissel en halverwege een stap = geen autosave. Daarna moet de voortgang ongewijzigd zijn.
* Cutscenes met een eigen scène (Mender-filmpje, Hanger-scène) zijn bewust save-veilig; de suite doet daar pauze, "app gedood" en `continue_game` en eist dat de scène opnieuw speelt en afloopt.

## Foutsoorten in de uitvoer

Elke `FAIL` begint met een label: `[SOFTLOCK]` (wereld komt niet in rust of een scherm gaat niet dicht, met de toestand erbij),
`[BLOCKER]` (poort, uitgang, spawn, pad of kamer werkt niet), `[SAVE]`, `[PAUSE]`, `[STATE]` (verhaalstaat klopt niet) en
`[TEKST]` (spelertekst niet Engels). Scriptfouten en crashes pakt `run_suite.sh` zelf op (`SCRIPT ERROR`, exitcode).

## Wat de suite niet doet

* `push_error`-regels zijn in Godot 4.3 niet vanuit GDScript te vangen. De statische audit spiegelt de bekende `push_error`-voorwaarden van `dungeon_room.gd`; verder blijft het logbestand de bron.
* De Diepe Grot, PvP, co-op en WM2/WM3 zitten er niet in.
* De puzzelkamers worden opgelost via `PuzzleLogic` (de oplossingen staan in de eigen suites); het lopen erna is echt.
* Gewone map-monsters worden voor de wandeling uit de kamer gehaald (ze versperren gangen); bewakers en bazen worden echt gevochten.

## CI

De suite staat bewust nog niet in `.github/workflows/tests.yml` (agents raken die map niet aan). Nodig: `wm1playthroughtest` aan de
`suite:`-matrix toevoegen, bijvoorbeeld achter `coope2etest`.
