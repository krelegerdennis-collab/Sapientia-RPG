# WM1 laadtijden en scènewissels (perf)

Scope: alleen Worldmap 1 (Wilgendal, wereldkaart, Esdoorn, Donker Woud, Eerste Archief, berggrot) en de dingen die er
doorheen lopen: opstarten, titel naar WM1, kaartwissels, gevecht in en uit, save laden. "Dieper, niet groter": geen nieuwe
content, geen gedragswijziging. Gemeten met een herhaalbaar harnas (`tools/perf/`), voor en na op dezelfde machine.

Naast dit werk bestaat `docs/perf/WM1_PERF.md` (branch `agent/cursor/perf-wm1`, FPS/draw calls/geheugen). Dat is een andere
invalshoek: daar gaat het om frametijd, draw calls en textuurgeheugen per scène; hier om wat je *wacht* bij een wissel. De twee
harnassen hebben geen bestanden gemeen (`scripts/tests/perf_wm1.gd` daar, `tools/perf/perf_wm1.gd` hier); een proefmerge van
beide branches gaf geen conflicten.

## Draaien

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --import                       # eenmalig
tools/perf/run_perf_wm1.sh /tmp/perf.json                 # alles, ~35 s; JSON + PERF-regels op stdout
tools/perf/run_perf_wm1.sh /tmp/perf.json --only=title,route --runs=15   # een deel
python3 tools/perf/compare_perf.py --before voor_*.json --after na_*.json   # markdown-tabel (mediaan over de bestanden)
GODOT=$GODOT .github/scripts/run_suite.sh perfwm1test     # gedrag-gelijk-test voor de wijzigingen (41 PASS)
```

Opties na `--`: `--runs=N` (herhalingen per stap, standaard 5), `--frames=N` (meetframes per kaart, 300), `--dwell=MS` (echte
tijd op het titelscherm, 4000), `--boot-wait=MS` (wacht vóór de eerste titel, 0), `--only=startup,title,route,battle,save,frames`,
`--noprobe`. Het harnas is een losse scène (`res://tools/perf/perf_wm1.tscn`), geen dispatch in `game_state.gd`: zo draait
exact dezelfde meting op de oude en de nieuwe code.

## Hoe er gemeten wordt

- Godot 4.3-stable (CI en APK), `gl_compatibility`, xvfb met software-GL (Mesa llvmpipe), 4 vCPU's. Dit is **geen S25 Ultra**: de
  absolute getallen zijn alleen onderling vergelijkbaar. Voor/na is steeds afwisselend gedraaid (5 paren, B A B A ...) en de
  tabel toont de mediaan over die 5 runs (elke run is zelf een mediaan over 5 herhalingen per stap).
- `Engine.time_scale = 1000` tijdens wissels: de vaste fades en timers (0,3 s, 0,06 s, 0,35 s autosave) kosten dan ~1 frame en
  wat overblijft is het echte werk (laden, instantiëren, `_ready`, save lezen en schrijven). `max_fps = 0`, vsync uit.
- `klaar` = van de aanroep (`change_map`, `start_battle`, `continue`) tot het frame waarin de nieuwe scène in de boom staat.
  `settled` = vier frames later (autosave, deferred werk). `langste frame` = de stotter die je voelt. Cold = eerste keer
  na de start, warm = herhaling.
- Script-tijd per frame = van `process_frame` tot vlak voor het tekenen (`RenderingServer.frame_pre_draw`), dus alle
  `_process`-callbacks, signalen, timers en tweens, zonder renderen. `Performance.TIME_PROCESS` is onder xvfb onbruikbaar (blijft
  op de eerste waarde staan) en wordt niet gebruikt. De probe roept `_process(0.016)` 200x aan per node met een script.
- De harnasroute: Wilgendal, wereldkaart, dorp, Esdoorn, wereldkaart, woud_rand, woud_pad, wereldkaart, archief_ingang,
  archief_v1_gang, wereldkaart, bouwplaats, wereldkaart (13 wissels, twee keer; eerste doorloop = cold).
- Het titelscherm krijgt `--dwell` (4 s) voordat Doorgaan wordt gekozen: de achtergrond-prewarm (zie onder) mag dan lopen. Een
  speler die binnen 2,5 s doorklikt krijgt een deel van de winst op de cold-rijen niet.

## Resultaat (Godot 4.3, xvfb, mediaan van 5 afwisselende runs)

| Meting | Voor | Na | Delta |
|---|---:|---:|---:|
| **Startup** | | | |
| Engine start tot autoloads klaar (ms) | 1999 | 1445 | -28% |
| Langste frame op het titelscherm, 4 s dwell (ms) | 8 | 191 | +2237% (prijs, zie onder) |
| **Titel naar WM1** | | | |
| Titelscherm klaar, 4 saves aanwezig (ms) | 22.7 | 20.8 | -9% |
| Slotlijst openen (ms) | 10.6 | 9.7 | -9% |
| Doorgaan naar wereldkaart klaar (ms) | 40.9 | 41.5 | +2% (ruis) |
| Doorgaan naar wereldkaart, eerste keer (cold, max) (ms) | 102 | 66 | -36% |
| **Kaartwissels WM1 (13 stappen)** | | | |
| Cold, zwaarste kaart klaar (ms) | 339 | 166 | -51% |
| Cold, totaal 13 wissels (ms) | 886 | 495 | -44% |
| Warm, zwaarste kaart klaar (ms) | 203 | 122 | -40% |
| Warm, totaal 13 wissels (ms) | 452 | 368 | -19% |
| **Per kaart** | | | |
| dorp_wilgendal cold (ms) | 288 | 166 | -42% |
| dorp_wilgendal warm (ms) | 203 | 122 | -40% |
| woud_rand cold, eerste kerker/woud-kamer (ms) | 339 | 61.6 | -82% |
| archief_ingang, esdoorn, wilgendal cold (ms) | 48 / 54 / 45 | 47 / 56 / 48 | ruis |
| **Gevecht** | | | |
| Gevecht in, cold / warm (ms) | 48.1 / 32.1 | 47.1 / 32.2 | geen verschil |
| Gevecht uit, cold / warm (ms) | 16.5 / 16.5 | 18.7 / 16.7 | geen verschil (ruis) |
| **Save laden** | | | |
| `read_save` (1 slot) (ms) | 0.59 | 0.53 | -10% |
| `slot_record` x5 (slotlijst) (ms) | 2.79 | 1.37 | -51% |
| `newest_slot_record` (ms) | 2.90 | 1.44 | -50% |
| `apply_state`, `save_game`, `set_checkpoint` (ms) | 1.31 / 2.66 / 0.22 | 1.30 / 2.67 / 0.22 | gelijk |
| **Script-tijd per frame, stilstaand (ms)** | | | |
| wereldkaart / wilgendal / esdoorn | 0.16 / 0.18 / 0.16 | 0.16 / 0.19 / 0.16 | gelijk |
| dorp_wilgendal | 0.24 | 0.22 | -8% |
| woud_pad / archief_v1_gang | 0.48 / 0.48 | 0.48 / 0.51 | gelijk |

Volledige tabel (alle rijen, rechtstreeks uit `compare_perf.py`): zie de bijlage onderaan.

Leesvoorbehouden:
- "Titelscherm, eerste keer opbouwen" in de volledige tabel staat +30 ms hoger na de wijziging. Dat is een meetartefact: het
  harnas bouwt de titel meteen op, dus tijdens de opstart-compile. In het spel staat de titel er vóór die compile begint.
  Met `--boot-wait=2500` (compile eerst laten afronden): voor 79 / 86 / 75 ms, na 83 / 92 / 85 ms (3 runs); binnen de ruis.
- Het "langste frame op het titelscherm" is de prijs van het verplaatsen van werk: `battle.gd` (180 ms) compileert nu na het
  eerste beeld i.p.v. ervoor, en de prewarm compileert zwaar werk in stappen van hooguit ~110 ms. Dat gebeurt alleen op het
  titelscherm / bij naam invoeren, nooit tijdens spelen of een wissel.
- Gevecht in/uit en de meeste warme kaartwissels zijn al goedkoop (7 ms script in `battle.gd::_ready`, 2-8 ms `_ready` van een
  gewone kaart); wat daar gemeten wordt is vooral frame-rendering van llvmpipe. Daar is niets aan veranderd.

## Wat er veranderd is

1. **Opstart** (`scripts/game_state.gd`). `_start_preload()` compileerde in `_ready` van de eerste autoload 12 scripts op de
   hoofdthread (battle.gd 180 ms, map.gd 61, npc.gd 52, ...: ~420 ms, zwart scherm). Nu: eerste beeld eerst, daarna één script
   per frame, dan pas de threaded loads (die hebben de gecompileerde scripts nodig; de reden van `MAIN_THREAD_SCRIPTS` blijft
   dus gelden). De originele `_start_preload` / `_process` / `_finish_preload` zijn niet herschreven, alleen uitgebreid met
   haakjes (`_plan_preload`, `_fase_voorladen`, `_prewarm_step`). De tijdelijke `CIDIAG`-regels (`DirAccess.get_files_at` over
   2050 geïmporteerde bestanden, #141) zijn verwijderd. Testmodi roepen `_finish_preload()` aan en krijgen alles synchroon zoals
   voorheen (geen prewarm in tests).
2. **Prewarm** (`PREWARM_SCRIPTS`). In rustige schermen (titel, naam invoeren) compileert GameState 24 zware scripts die WM1 anders
   pas bij de eerste binnenkomst compileert: `dungeon_room.gd` (260 ms bij de eerste woud/archief-kamer), `field_menu.gd` (210 ms bij
   het eerste openen van het menu), `puzzle_room.gd` (140), `archief2_room.gd` (100), dorp-scripts (80), `pand_binnen.gd` (65),
   `kern_kracht_veld.gd` (40, eerste kaart). Eén stap per 50 ms, afhankelijkheden vóór het script dat ze preloadt, zodat elke
   stap klein blijft. Alleen scripts (geen textures) en ze blijven in `_loaded`. Scènes zelf laden daarna in 0,1-3 ms (gemeten),
   dus een prefetch van buurkaarten is niet nodig.
3. **Dorp Wilgendal** (`scripts/village/dorp_ground.gd`, `dorp_opbouw.gd`): 145 naar ~70 ms per bezoek (anatomie-meting).
   - v8-grond: `TileSetAtlasSource.create_tile` kost ~20 us; het atlas heeft 1297 tegels maar het dorp gebruikt er 381 (bron 0)
     en 138 (bron 2). Nu worden alleen de gebruikte aangemaakt (was 2x1297 + 4). Bronnen krijgen dezelfde id's en volgorde.
   - Buurcontroles (`masker`, `pad_zoom`) lezen een vlak byte-raster i.p.v. 9 string-indexeringen per cel; de oorspronkelijke
     statische functies blijven bestaan (tests) en `perfwm1test` bewijst dat de snelle paden voor alle 5040 cellen hetzelfde geven.
   - `grond_v8.json` wordt één keer per sessie geparsed.
   - De plein-tileset (1280 tegels, 26 ms) wordt één keer gebouwd en bewaard (statisch). Die atlas is klein (512x640, ~1,3 MB); de
     grote v8-atlassen (tot 2048x2048) worden bewust *niet* bewaard.
   - Alle vaste tegels van het plein delen één 16x16-botsvorm. (De botsvorm van de bomen heeft de perf-wm1-branch al; die is
     hier niet aangeraakt om een conflict te voorkomen.)
4. **Save laden** (`game_state.gd`, `title_screen.gd`). Eén bestand werd 2 tot 3 keer geparsed (slot_record deed `read_save` en
   `_save_stamp` = nog een `read_save`; het titelscherm zocht twee keer de nieuwste save; Doorgaan las hem nog eens). Nu: stempel
   uit de al gelezen data (`_stamp_of`), `title_screen.refresh()` gebruikt één `newest_slot_record()`, en
   `load_game(path, gelezen)` krijgt de data van de slotlijst/Doorgaan mee. Uitkomsten identiek (getest).

## Bewust niet gedaan, met voorstel

- **`SomArena._process` / `_target_for`** (`scripts/som/som_arena.gd`): in WM1-kerkerkamers met monsters (Action-modus is de
  standaard) kost de arena ~0,3 ms van de ~0,5 ms script per frame (probe: 110-140 us per aanroep), tegen ~0,16 ms op elke andere
  kaart. Per monster per frame bouwt `_target_for` een nieuwe array (`party_ids()`), en `is_alive(id)` doet `member(id)` =
  `has_member` + `member` (twee lineaire zoekacties), `node_of` + `body_of` (`ally_of` lineair). Voorstel: per frame één lijst
  (id, node, lichaamspositie, levend) opbouwen en per monster alleen de afstand uitrekenen; opnieuw opbouwen na elke
  `hit_member`/`_member_ko` zodat de volgorde-semantiek binnen een frame gelijk blijft. Niet gedaan: het bestand valt in het
  FPS-werk van de perf-wm1-branch.
- **Dorp: aantal nodes** (1719 nodes, 268 `StaticBody2D`-bomen). De eerste physics-stap na het binnenkomen kost ~30-50 ms
  extra (verschil tussen `instantiate` ~70 ms en `klaar` ~120 ms in de route). Tests verwachten `Boom_x_y`-bodies, dus niet
  samengevoegd. Voorstel (vraagt een test-aanpassing en RPG Forge): botsing per tegel in de grond-TileSet (physics layer) i.p.v. een body per boom.
- **TileSet vooraf bakken**: `create_tile` is de dominante kost van het dorp. Een door `tools/som/*.py` gebakken `.tres` per
  atlas zou het ~50 ms nog kosten wegnemen; dat is art-pijplijn (RPG ART / Forge), niet aangeraakt.
- **CI** (alleen voorstel, `.github/workflows/` is niet voor agents):
  - `perfwm1test` toevoegen aan de matrix van `tests.yml` (41 PASS, ~3 s).
  - Optioneel een niet-blokkerende job die `tools/perf/run_perf_wm1.sh` draait en de JSON als artifact bewaart (xvfb-ruis is ±5-10%,
    dus geen drempel; wel een trend).
  - `balansarchief1test` faalt op `origin/main` zonder mijn wijzigingen (46 PASS / 8 FAIL, tier-winstpercentages; rijen 51-58 van het
    log), maar staat wel in de matrix; los te onderzoeken door wie de balans beheert.
- `AGENTS.md`: `--perfwm1test` staat niet in de suite-tabel (bestand is voor RPG Forge).

## Risico's

- De prewarm houdt ~24 gecompileerde scripts vast (`_loaded`) en één TileSet-atlas van ~1,3 MB; terugdraaien kan door `PREWARM_SCRIPTS`
  leeg te maken en `_p10_tileset()` weer per bezoek te laten bouwen.
- Wie binnen ~2,5 s na de start doorklikt compileert de rest van de prewarm gewoon lazy, precies zoals voor deze wijziging.
- De harnasgetallen komen van llvmpipe; op een S25 Ultra is renderen goedkoper en compileren (bytecode in de APK) sneller, de
  *verhouding* (script-compile en tegels aanmaken zijn de grote posten) blijft naar verwachting gelijk maar is daar niet gemeten.

## Bijlage: volledige tabel

| Meting | Voor | Na | Delta |
|---|---:|---:|---:|
| **Startup** | | | |
| Engine start -> autoloads klaar (GameState._ready e.a.) (ms) | 1999 | 1445 | -28% |
| Titelscherm, eerste keer opbouwen (cold) (ms) | 76.17 | 106 | +40% |
| Titelscherm opbouwen (warm, mediaan) (ms) | 8.20 | 8.05 | -2% |
| Langste frame op het titelscherm (4 s dwell) (ms) | 8.19 | 191 | +2237% |
| **Titel -> WM1** | | | |
| Titelscherm klaar, 4 saves aanwezig (ms) | 22.70 | 20.75 | -9% |
| Slotlijst openen (ms) | 10.60 | 9.68 | -9% |
| Doorgaan -> wereldkaart klaar (ms) | 40.85 | 41.49 | +2% |
| Doorgaan -> wereldkaart settled (+4 frames) (ms) | 62.87 | 68.86 | +10% |
| Doorgaan -> wereldkaart, langste frame (ms) | 34.49 | 34.86 | +1% |
| **Kaartwissels WM1 (13 stappen)** | | | |
| Cold, mediaan klaar (ms) | 30.02 | 30.59 | +2% |
| Cold, mediaan langste frame (ms) | 20.29 | 20.38 | +0% |
| Cold, zwaarste kaart klaar (ms) | 339 | 166 | -51% |
| Cold, totaal 13 wissels (klaar) (ms) | 886 | 495 | -44% |
| Warm, mediaan klaar (ms) | 27.51 | 26.19 | -5% |
| Warm, mediaan langste frame (ms) | 17.55 | 16.46 | -6% |
| Warm, zwaarste kaart klaar (ms) | 203 | 122 | -40% |
| Warm, totaal 13 wissels (klaar) (ms) | 452 | 368 | -19% |
| **Per kaart** | | | |
| dorp_wilgendal cold (ms) | 288 | 166 | -42% |
| dorp_wilgendal warm (ms) | 203 | 122 | -40% |
| woud_rand cold (eerste kerker/woud-kamer) (ms) | 339 | 61.62 | -82% |
| archief_ingang cold (ms) | 48.40 | 47.34 | -2% |
| esdoorn cold (ms) | 54.26 | 55.55 | +2% |
| wilgendal cold (ms) | 45.37 | 47.94 | +6% |
| **Gevecht** | | | |
| Gevecht in, eerste keer (cold) (ms) | 48.10 | 47.13 | -2% |
| Gevecht in (warm) (ms) | 32.09 | 32.20 | +0% |
| Gevecht in (warm), langste frame (ms) | 12.74 | 12.91 | +1% |
| Gevecht uit, eerste keer (cold) (ms) | 16.50 | 18.69 | +13% |
| Gevecht uit (warm) (ms) | 16.45 | 16.72 | +2% |
| Gevecht uit (warm), langste frame (ms) | 11.33 | 11.32 | -0% |
| **Save laden / opslaan (CPU per aanroep)** | | | |
| read_save (1 slot) (ms) | 0.59 | 0.53 | -10% |
| apply_state (ms) | 1.31 | 1.30 | -1% |
| save_game (schrijven + verifieren) (ms) | 2.66 | 2.67 | +0% |
| slot_record x5 (slotlijst) (ms) | 2.79 | 1.37 | -51% |
| newest_slot_record (ms) | 2.90 | 1.44 | -50% |
| set_checkpoint (elke kaartwissel) (ms) | 0.22 | 0.22 | +0% |
| **Script-tijd per frame (stilstaand, zonder renderen)** | | | |
| wereldkaart (ms) | 0.16 | 0.16 | -0% |
| wilgendal (ms) | 0.18 | 0.19 | +1% |
| dorp_wilgendal (ms) | 0.24 | 0.22 | -8% |
| esdoorn (ms) | 0.16 | 0.16 | -2% |
| woud_pad (ms) | 0.48 | 0.48 | +2% |
| archief_v1_gang (ms) | 0.48 | 0.51 | +5% |
| wereldkaart lopend (ms) | 0.17 | 0.17 | -1% |
| **Som van alle _process-aanroepen (probe, us)** | | | |
| wereldkaart (us) | 13.12 | 13.27 | +1% |
| dorp (us) | 176 | 199 | +13% |
| woud_pad (us) | 158 | 157 | -0% |
| archief_gang (us) | 166 | 185 | +12% |
