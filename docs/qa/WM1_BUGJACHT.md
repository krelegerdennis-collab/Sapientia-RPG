# WM1-bugjacht

Koers: alleen Worldmap 1 (WM2 ligt stil en is niet gelezen), dieper en niet groter: geen nieuwe content.
Doel: bugs vinden op de WM1-routes (Wilgendal, wereldkaart, Eerste Archief, Donker Woud, Esdoorn, Berggrot en
Kas, gevechten, menu's, winkels, Codex), elke echte bug minimaal fixen met een NIEUWE regressietest, de rest
eerlijk open laten staan.

Alles draaide op Godot 4.3-stable (zoals CI), headless met `xvfb-run`. Bestaande tests zijn niet aangepast.
De nieuwe regressietests staan in de nieuwe suite `--wm1bugtest` (`scripts/tests/wm1_bugjacht_tests.gd`).

## Samenvatting

| | |
|---|---|
| Gevonden en gefixt | 2 echte bugs (WM1-01, WM1-02), elk met regressietest |
| Open | 4 punten (zie "Open"), geen daarvan blokkeert de voortgang |
| Basislijn voor de fixes | 21 bestaande suites groen (1 timing-flake onder load, zie O-4) |
| Na de fixes | alle 39 CI-suites + `wm1bugtest` groen, `warper-runner` groen, `algemene-sfx` groen |

## Wat is geprobeerd

### 1. Bestaande suites als basislijn
`autotest` (700 PASS, volledige proloog en WM1-route), `menutest`, `woudtest`, `wilgendaltest`, `archieftest`,
`codextest`, `questtest`, `tutorialtest`, `cutscenetest`, `partytest`, `savetest`, `checkpointtest`, `kerntest`,
`kernkrachttest`, `golemtest`, `puzzletest`, `dungeontest`, `archief2test`, `berggrottest`, `hangertest`,
`balansarchief1test`. De logs zijn daarna op `ERROR:`, `WARNING:`, `SCRIPT ERROR` en nulfouten doorzocht. Wat daar
uitkwam waren alleen testartefacten (lambda die een vrijgegeven `ka` vangt in `kern_tests.gd`, een `%s` met een
array in `party_tests.gd`) en twee echte logregels (O-2, O-3).

### 2. Statische schouw (geen speler nodig)
- Alle `res://`-paden in scènes, scripts, `.tres` en `project.godot` bestaan (op `build.json`, dat bewust niet in
  git staat, na).
- Alle `MapExit`/`Door`-doelen in `scenes/maps/` verwijzen naar bestaande scènes; de spawns die niet statisch in de
  scène staan komen uit de kamerdata en zijn daartegen gecontroleerd.
- Data-audit over alle WM1-kamers (Archief 1, Archief 2, Donker Woud, `berggrot_*`): bestaan alle items in kisten,
  vijanden en groepen, monster-sprites in `assets/map_monsters/`, uniekheid van kist- en monster-id's, gelijke
  rijbreedte van `layout`, kist en monster binnen de kaart, uitgang-spawns in de doelkamer.
- Verhaal-data: elk `give`/`take`/`weapon`/`battle`/`join`/`map`/`jump`/`run`/`after`/`choice` in `story_data.gd` wijst
  naar iets dat bestaat; alle `event = "..."` in scènes en objecten bestaan in `EVENTS`.
- Economie: voor elke winkel en elke act is de verkoopprijs lager dan de koopprijs (geen goud uit kopen en
  verkopen), geen gratis winkelitems, geen onbekende winkel-id's.
- Bereikbaarheid: op alle 51 kaartscènes een BFS met de echte botsingen van de speler (`test_move`): zijn spawns,
  uitgangen en NPC's/kisten/borden/deuren bereikbaar? De punten die niet bereikbaar waren zijn puzzel- of
  verhaalpoorten (hendels en kisten in puzzelkamers, trapzaal, de rij voor De Genezer, de kas achter de bergen,
  de berggrottunnel tot Vesper in de party zit, de Archief-ruïne in het erf) die de bestaande puzzel-, archief- en
  berggrottests expliciet vastleggen.

Uitkomst: geen fouten. Dit is dus geen bron van bugs; de data is netjes.

### 3. Apen-test (willekeurige invoer, de belangrijkste vindplaats)
Een wegwerp-tester (niet in de repo) speelt een kaart met willekeurige invoer: lopen, A, B, MENU, ring, wissel,
rennen en Kernkracht, in stukken van 3 tot 14 beeldjes. Elke 6 s springt hij naast een willekeurig zichtbaar
object (NPC, kist, bord, boek, winkel, monster) en kijkt ernaar, zodat winkels, kisten, opslagboeken en menu's
echt aan bod komen. Elke seconde controleert hij invarianten: goud en voorwerp-aantallen niet negatief, HP en MP
binnen bereik, party hooguit 4, `in_battle` klopt met de scène, en of de toestand 40 s niet verandert zonder dat
een menu open staat (softlock-detector). De logs zijn op `SCRIPT ERROR` en `ERROR:` doorzocht.

Gedraaid met versnelde tijd, `encounter_multiplier` 3 en een starterparty (Dax, Vesper, Seren op minstens level 5,
goud en items):

| run | kaarten | stijl | aantal runs |
|---|---|---|---|
| veld | 33 WM1-kaarten (Wilgendal, wereldkaart, Esdoorn, Archief 1, Donker Woud, Berggrot, Kas) | Action (standaard) | 2 seeds x 33, plus gerichte herhalingen op Mistpoel, Sporenkring, Wortelpad en de zes Action-kamers (ruim 90) |
| Classic | 22 kaarten | Classic | 1 seed x 22 |
| zwak | 22 kaarten, party alleen Dax level 1 met 1 drankje (veel game overs, respawn en checkpoint) | Action | 1 seed x 22 |
| menu | 24 kaarten, met MENU-toets (Uitrusting 155x, Magie, Bestiarium, Party, Codex, Scènes, winkel) | Action en Classic | 2 x 24 |
| verhaal | nieuw spel vanaf het bed | Action | 6 seeds (komt het huis niet uit, zie "Beperkingen") |

Samen ruim 230 runs van 1 tot 8 minuten speeltijd. Dit vond WM1-01 en WM1-02 en het eenmalige O-1.

### 4. Logica-fuzz op economie en uitrusting
Willekeurige reeksen van kopen (items en spreuken), verkopen, uitrusten, afdoen, items gebruiken, EXP geven, HP
verlagen, party herschikken en opslaan en laden (JSON-rondgang met `apply_state`), 6 x 4000 stappen over vier
helden. Invarianten: voorwerpen blijven behouden (tas plus gedragen uitrusting verandert alleen door kopen,
verkopen en verbruiken), geen negatieve of nul-aantallen, geen onwettige uitrusting, HP/MP binnen bereik, de
koop- en verkoopprijs kloppen, en de save is na een rondgang identiek. Uitkomst: 0 schendingen. Geen
goud- of voorwerp-duplicatie gevonden.

## Gevonden en gefixt

### WM1-01 Winkel: de lijst brak af na elke aankoop of verkoop
- Waar: `scripts/ui/shop_screen.gd` (alle winkels van Wilgendal, de Handelskamer en de Koopman, want die erven het).
- Wat: kopen of verkopen met A of een tik herbouwt de lijst. `_clear()` deed `c.free()` op de knop die net zijn
  `pressed`-signaal uitzond: `Attempted to free a locked object` (SCRIPT ERROR). Die fout brak `_show_koop()` en
  `_show_verkoop()` halverwege af. Gevolg voor de speler: na een aankoop of verkoop bleef de lijst half leeg
  (de "Sell"/"Buy"-knop en de rijen erboven weg) en bleef de ingedrukte knop als wees achter. Het gaf in een run van 150 s
  ongeveer zestig foutmeldingen. De bestaande tests roepen `_on_buy`/`_on_sell` rechtstreeks aan en raakten dit pad niet.
- Fix: `queue_free()` in plaats van `free()` (een regel).
- Regressietest: `wm1bugtest` deel A drukt de echte knoppen in (`pressed.emit()`): lijst herbouwd, geen wees-knoppen,
  gekocht en verkocht klopt. Zonder de fix 6 FAIL en 3 SCRIPT ERROR, met de fix groen.

### WM1-02 Action: bondgenoten starten in een muur; SWAP zette de held voorgoed in de Mistpoel-poel
- Waar: `scripts/som/som_ally.gd`, `scripts/som/som_arena.gd` (`switch_hero`).
- Wat: bij het binnenkomen van een kamer in Action maakt de arena de bondgenoten rond de standaardplek van de speler
  in de scène (152,168), nog voor de speler op zijn spawnpunt staat. In vier WM1-kamers is die plek massief:
  `woud_mistpoel` (de donkere poel), `woud_pad`, `archief_v4_wachtersgang` en `archief_bibliotheek`. De bondgenoten
  blijven dan in de muur zitten (in de Mistpoel zelfs seconden tot de speler 170 px weg is). Wisselen ruilt de plekken
  van de bestuurde held en de bondgenoot. Gebeurt dat in dat venster (SWAP-knop, of automatisch als de bestuurde held KO gaat)
  dan staat de bestuurde held in de poel, ingeklemd en zonder uitweg: de apen-test bleef 100 s op één tegel hangen.
  Alleen laden of een nieuw gevecht helpt dan nog.
- Fix: `SomAlly.in_wall()`; een bondgenoot in een muur gaat meteen naar de speler (eerste `tick`) en `switch_hero`
  doet dat eerst, zodat de swap nooit in de muur eindigt. Geen wijziging aan de kamers of de art.
- Regressietest: `wm1bugtest` deel B laadt `woud_mistpoel` in Action met drie helden, controleert de oorzaak (twee
  bondgenoten in een muur), wisselt direct (de bestuurde held staat niet in een muur en kan bewegen) en wacht tot de
  bondgenoten zonder wisselen uit de muur zijn. Zonder de fix 3 FAIL, met de fix groen.

## Open

| id | wat | waarom open |
|---|---|---|
| O-1 | `SomArena._enemy_ai` (`som_arena.gd:752`): `Invalid access to property or key 'Monster_m3...' on a base object of type 'Dictionary'`, dus een vijand in de lus is intussen uit `enemies` gehaald. | Eenmalig gezien (`archief_v2_trapzaal`, Action, onder zware load), daarna niet meer te reproduceren in ruim 90 gerichte runs op alle zes Action-kamers. De oorzaak is niet gevonden en een blind vangnet zou het mechanisme verbergen. Gevolg als het gebeurt: één frame zonder vijand-AI, geen blijvende schade. Als het terugkomt: `enemies.has(m)` loggen met `get_stack()` in `_enemy_ai`. |
| O-2 | Elke keer dat `archief_2_warper` (World Warper-kamer) gebouwd wordt, logt `dungeon_room.gd` `ERROR: uitgang 'n' heeft geen doel in "exits"`. | De boog `n` in de noordmuur is een decoratie zonder doel (de kamer heeft alleen een uitgang `E`). Wegnemen verandert het beeld van die muur (art/design), een leeg doel is een datakeuze. Spelers merken niets. Keuze aan Forge of ART. |
| O-3 | `ERROR: Condition "!is_inside_tree()" ... get_viewport_rect` bij het wisselen Classic naar Action in een kamer (zichtbaar in `autotest.log`). | `map._fit_camera` hangt permanent aan `size_changed` en draait nog voor een kaart die net uit de boom is maar nog niet vrij. Alleen een logregel, geen effect. Een `is_inside_tree()`-regel is genoeg, maar er is geen speler-effect om tegen te testen. |
| O-4 | `berggrottest` "warper beweegt op de kaart en blijft erbinnen" faalde één keer toen drie suites tegelijk draaiden. | Bestaande test (1,5 s wachttijd, beweging > 20 px), geslaagd bij elke losse run en in de eindrun. Een flake onder CPU-load, geen spelfout. Niet aangepast, want bestaande tests blijven staan. |
| O-5 | `wm1bugtest` staat nog niet in de matrix van `.github/workflows/tests.yml`. | Opdracht: niet aan `.github/workflows` komen. RPG Forge moet `wm1bugtest` aan de matrix toevoegen. Tot dan draait de suite niet in CI, maar wel lokaal met `.github/scripts/run_suite.sh wm1bugtest` (14 PASS). |

## Bewust zo ontworpen (geen bug)

- De kas-uitgang op de wereldkaart (14,8) is niet lopend vanuit het dorp bereikbaar: je komt er via de berggrot
  (`van_berggrot`), de tests leggen dat vast.
- Het Archief-ruïnehek in `wilgendal` en de Kas-/Bouwplaats-uitgangen zijn tot het verhaal ze opent geblokkeerd.
- Het Zingende Meel is eenmalig per bezoek aan de molen (nieuw bezoek = nieuwe scène), prijs 0 en niet verkoopbaar.
  Geen goudwinst, wel herhaalbaar genezen; dat is zo bedoeld.
- Een Feniksveer in een gevecht wordt ook verbruikt als niemand KO is (net als genezen op volle HP).
  Het veldmenu weigert dat wel. Buiten WM1 (Koopman, Diepe Grot), dus niet aangepast.

## Beperkingen

- De apen-test kwam in 6 x 500 s vanaf een nieuw spel het Wachtershuis niet uit (de teleport hield hem bij de
  objecten); de proloog is wel volledig gedekt door `autotest` en `tutorialtest`.
- Willekeurige invoer vindt geen fouten die een specifieke volgorde van keuzes in een dialoog vragen; dat blijft
  het werk van de verhaaltests.
- Geluid is er niet (dummy-driver); `ALSA`-meldingen in de logs zijn geen bevinding.
