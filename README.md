# SAPIENTIA – mobiele JRPG (Godot 4)

**SAPIENTIA** is een top-down JRPG voor **Android** (arm64), gebouwd in **Godot 4.3-stable**
(`gl_compatibility`), basisresolutie **384×216** (pixel-art). Alle spelertekst in de game is **Engels**;
dit bestand en de overige docs zijn Nederlands.

- Agent-regels en testsuites: [`AGENTS.md`](AGENTS.md) en [`docs/WORKFLOW.md`](docs/WORKFLOW.md).
- **Versiegeschiedenis en release-notities** staan in [`CHANGELOG.md`](CHANGELOG.md) (niet meer hieronder).
- Overdrachten van RPG CODE / RPG ART (patches, screenshots, besluiten): [`docs/handoff/`](docs/handoff/).

Getest met Godot **4.3** (CI) en soms **4.7.2** lokaal; gebruik de standaard engine, *niet* de .NET/C#-build.

Onderstaande hoofdstukken beschrijven nog het oorspronkelijke prototype en de map van de repo
(historische README-tekst); voor actuele features en WM1-werk, zie `CHANGELOG.md`, `docs/` en `AGENTS.md`.

---

## 1. Openen en starten

1. Download Godot 4.3 of nieuwer (standaard "Godot Engine", niet ".NET") van <https://godotengine.org/download>.
   Het is één bestand; uitpakken en starten, installeren is niet nodig.
2. Pak `lufia_prototype.zip` uit naar een map naar keuze.
3. Start Godot → in de **Project Manager** klik op **Import** (of *Importeren*) →
   kies het bestand `project.godot` in de uitgepakte map → **Import & Edit**.
4. De eerste keer importeert Godot de plaatjes (paar seconden).
   *Gebruik je Godot 4.4 of nieuwer, dan maakt hij er ook `.uid`-bestandjes bij. Dat is normaal.*
5. Druk op **F5** (of de ▶-knop rechtsboven) om te spelen.

### Besturing

| Actie                  | Toetsenbord          | Telefoon / muis              | Gamepad    |
|------------------------|----------------------|------------------------------|------------|
| Lopen / menu kiezen    | Pijltjes of WASD     | D-pad linksonder             | D-pad      |
| Praten / bevestigen    | Spatie of Enter      | **A**-knop, of tik op de knop| A / kruis  |
| Terug (in menu's)      | Escape of Backspace  | **B**-knop                   | B / rondje |
| Veldmenu (Items, Status, Opties, ...) | Esc, M of Tab | **MENU**-knop rechtsboven, daarna tikken | –  |
| Gevecht forceren (test)| **F2**               | –                            | –          |
| Baasgevecht (test)     | **F3**               | –                            | –          |

In gevechten kun je ook direct **tikken** op een menuregel, op een vijand (doel kiezen)
of op een held: op zijn sprite óf op zijn statusvak (genezen, items). Ook het
overwinningsvenster tik je weg. F2 werkt alleen in debug-builds (dus vanuit de editor).

Op de PC kun je de touch-knoppen met de **muis** aanklikken
(instelling *emulate touch from mouse* staat aan).

Probeer: loop naar het **bordje** of de **oude man**, kijk ernaar en druk op A/Spatie.
Loop daarna via het pad naar het zuiden het dorp uit. Op de wereldkaart begint er af en toe een
gevecht. F2 werkt alleen op maps met monsters, dus niet in het dorp.

---

## 2. Mappenstructuur

```
lufia_prototype/
├── project.godot            Projectinstellingen (resolutie, input, renderer)
├── icon.png                 App-icoon
├── README.md                Dit bestand
├── docs/                    Stijlgids (ARTSTYLE.md), paletkaart, referentie-uitsneden (alleen intern!)
├── assets/
│   ├── tiles/
│   │   ├── dorp.png         Dorp-tiles (16x16, één rij): 0-32 = gras, bloemen, zandpad, boom, muur,
│   │   │                    water, brug, rots + randjes. 33 = kassei, 34-48 = kassei met grasrand,
│   │   │                    49 heg, 50 hek, 51 lage muur, 52 bloemenperk, 53 ton
│   │   ├── huis.png         Het huis: 80x80 = 5x5 tiles (dak, vakwerk, ramen, deur)
│   │   ├── dorp.tres        TileSet van het dorp (dorp.png + huis.png): collision + "terrain"
│   │   ├── wereld.png       Wereldkaart-tiles (raster van 16 kolommen): gras, licht gras, zand,
│   │   │                    bos, bergen, zee met kust, stad-icoon, trap
│   │   └── wereld.tres      TileSet van de wereldkaart: collision (zee, berg) + "terrain"
│   ├── sprites/
│   │   ├── player.png       Speler, 48x96: frames van 16x24, 3 kolommen (stil, stap A, stap B) x 4 rijen (onder, links, rechts, boven)
│   │   ├── npc.png          NPC in dezelfde indeling
│   │   └── sign.png         Bordje
│   ├── sprites/enemies/     Vijanden (v8, handgetekend, 2x zo fijn): kennis_beest 214x194 (baas),
│   │                        papiergeest 74x94, glitchmot 106x96 (op het scherm de helft; max. 194 hoog)
│   ├── sprites/battle/      Gevechtssprites van de helden: dennis/noor/lotte.png, strook 2100x210 =
│   │                        10 frames van 210x210 (stil, klaar, aanval A/B, spreuk A/B, geraakt, KO,
│   │                        inademen, uitademen), voeten op (105,203)
│   ├── battle/bibliotheek.png              Gevechtsachtergrond (standaard), 1280x432
│   ├── battle/bibliotheek_overwoekerd.png  Gevechtsachtergrond in het bos, 1280x432
│   ├── shaders/             scanlines.gdshader (lijnen + vignet), glitch.gdshader (korte glitch)
│   ├── ui/                  window.png (tekstvenster, metalen hoekjes), panel_status.png (statusvak,
│   │                        tabjes) en window_glass.png (overwinningsvenster), als 9-slice.
│   │                        *_hd.png = dezelfde vensters 2x zo fijn voor het gevechtsscherm
│   ├── fonts/               Eigen dun pixel-lettertype "Dauwpixel" (gemaakt met tools/generate_font.py)
│   └── theme.tres           Thema: lettertype (10 px, monospace), v7-vensters, tekstschaduw, knoppen
├── scenes/
│   ├── maps/
│   │   ├── wilgendal.tscn   ★ Dorp 1 (startscène): Ground + Gebouwen (huis) + speler, NPC, bordje, deur
│   │   └── wereldkaart.tscn ★ De wereldkaart: Ground + speler, uitgangen (stad, trap)
│   ├── player.tscn          Speler (CharacterBody2D + Sprite2D + Camera2D)
│   ├── npc.tscn             NPC (StaticBody2D)
│   ├── sign.tscn            Bordje (StaticBody2D)
│   ├── door.tscn            Deur (StaticBody2D, "De deur is op slot.")
│   ├── battle/
│   │   └── battle.tscn      Gevechtsscène (bericht-strook bovenin, helden, vijanden, menu, statusvakken,
│   │                        overwinningsvenster)
│   └── ui/
│       ├── dialog_box.tscn  Tekstvak (staat als autoload "Dialog" in het project)
│       └── touch_controls.tscn  Virtuele D-pad + A- en B-knop
├── scripts/
│   ├── map.gd               ★ Script op elke map: camera, spawnpunten, uitgangen, encounters, F2
│   ├── map_exit.gd          MapExit: uitgang-zone -> andere map + spawnpunt (of alleen een bericht)
│   ├── map_spawn.gd         MapSpawn: spawnpunt (waar je binnenkomt) met kijkrichting
│   ├── door.gd              Deur: tekst als je ertegenaan loopt of op A drukt
│   ├── game_state.gd        Autoload "GameState": party, inventaris, goud, huidige map, posities, encounters
│   ├── transition.gd        Autoload "Transition": flits/fade tussen overworld en gevecht
│   ├── ui/crt_overlay.gd    Autoload "Crt": scanline-filter + glitch (instellingen: CRT in game_data.gd)
│   ├── settings.gd          Autoload "Settings": opties in user://settings.cfg (volume, tekst, touch, ...)
│   ├── party_actions.gd     Items/spreuken buiten gevechten (regels, geen UI)
│   ├── ui/field_menu.gd     Veldmenu: groep + commando's + goud/tijd; opent de schermen hieronder
│   ├── ui/menu_screen.gd    Basis voor een menuscherm (venster, Terug-knop, hulpregel)
│   ├── ui/items_screen.gd   Items · ui/status_screen.gd Status · ui/magic_screen.gd Magie
│   ├── ui/options_screen.gd Opties · ui/save_prompt.gd 'Voortgang opslaan?' · ui/bestiary_screen.gd
│   ├── ui/party_card.gd     Kaartje van een held (naam, Lv, HP/MP-balken)
│   ├── ui/target_list.gd    Doelkeuze (op wie?) voor items en spreuken
│   ├── ui/glitch_noise.gd   Pixel-ruis in tekstvakken (gecachet)
│   ├── ui/title_tab.gd      Titel-tabje boven een venster
│   ├── ui/ui_style.gd       UiStyle: kleuren van de v7-UI (magenta, cyaan, grijzen)
│   ├── ui/blink_arrow.gd    Knipperend neon-pijltje in tekstvakken
│   ├── data/
│   │   └── game_data.gd     ★ ALLE GETALLEN: helden, vijanden, spreuken, items, encounter-kans per terrein
│   ├── battle/
│   │   ├── battle.gd        Gevechtslogica (beurten, schade, winst/verlies) + opstelling op het scherm
│   │   ├── battle_menu.gd   Lijstmenu dat werkt met tikken én D-pad/toetsen
│   │   ├── battle_hero.gd   Eén held op het slagveld: poses, stapje naar voren, flits, KO
│   │   ├── hero_status_box.gd  Statusvak per held: naam, HP/MP-balken, getallen (tekent zichzelf)
│   │   ├── hd_ui.gd         HdUi: vensters met fijne (1-pixel) randen op het 2x-raster
│   │   └── target_cursor.gd Geel doel-pijltje boven vijand of held
│   ├── player.gd            Grid-beweging, loopanimatie, botsing, praten, "bump" (tegen iets aan lopen)
│   ├── npc.gd               NPC draait naar je toe en praat
│   ├── sign.gd              Bordje met tekst
│   ├── dialog_box.gd        Tekstvak met typemachine-effect:  Dialog.show_lines([...], "Naam")
│   ├── touch_controls.gd    Touch → zelfde input actions als het toetsenbord (multi-touch, A en B)
│   └── debug_autotest.gd    Alleen voor testen (zie onderaan)
└── tools/                   Hulpmiddelen, niet nodig om te spelen
    ├── generate_art.py      Python-script dat alle plaatjes tekent volgens docs/ARTSTYLE.md
    ├── art_maps.py          Deel daarvan: dorp-tiles, huis, wereldkaart-tiles
    ├── art_v8_heroes.py     v8: helden (10 frames van 210x210, incl. adem-frames)
    ├── art_v8_enemies.py    v8: Papiergeest (verfrommeld papier) en Kennis-Beest (meer boek-detail)
    ├── art_v8_maps.py       v8: dorp, huis, wereldkaart, speler/NPC en icoon in bibliotheek-stijl
    ├── handwerk.txt         Handgemaakte art die generate_art.py NIET overschrijft
    ├── make_tile_templates.py  Sjablonen (4x, met nummers en solid) voor de art director
    ├── art_battle.py        Deel daarvan: '16-bit plus' helden, vijanden en HD-vensters
    │                        (kleine 3D-belichting per vorm, afgerond naar ramps van 6 tinten)
    ├── art_battle_bg.py     Deel daarvan: '16-bit plus' bos- en vlakte-achtergrond (1280x432)
    ├── generate_font.py     Python-script dat het lettertype Dauwpixel maakt
    ├── build_maps.gd        Bouwt dorp.tres, wereld.tres, wilgendal.tscn en wereldkaart.tscn
    │                        opnieuw uit tekst-maps (met automatische randjes en kust)
    └── build_maps.tscn
```

### Belangrijke instellingen (Project → Project Settings)

- Resolutie **384x216** (16:9, ongeveer SNES-formaat) → 24 x 13,5 tiles op het scherm.
  Op de PC wordt het venster 1152x648 (3x zo groot).
- Stretch mode **viewport** + aspect **expand**: alles wordt pixel-perfect opgeschaald;
  op een brede telefoon zie je iets meer van de map in plaats van zwarte balken.
- **Gevechten** renderen op **768x432** (2x zo fijn, zie `DETAIL` in `scripts/battle/battle.gd`);
  de gevechtsscène staat op schaal 2, dus alle posities in het gevecht zijn nog steeds in 384x216.
  Bij het verlaten van het gevecht wordt het weer 384x216.
- Texture filter **Nearest** (scherpe pixels), renderer **Mobile**, oriëntatie **liggend** (landscape, draait mee).
- Input actions: `move_up`, `move_down`, `move_left`, `move_right`, `interact` (A), `cancel` (B),
  `debug_battle` (F2).
- Autoloads (altijd aanwezig, in elk script te gebruiken): `GameState`, `Transition`, `Dialog`,
  `Crt` en `Settings` (opties, `scripts/settings.gd`).

---

## 3. Hoe werkt het (kort)

- **Map**: elke map (bv. `scenes/maps/wilgendal.tscn`) heeft een node **Ground** (een `TileMapLayer`).
  Klik hem aan en kies onderaan het tabblad **TileMap** om zelf te schilderen. Boom/heg/water/berg/
  zee blokkeren automatisch, omdat in de TileSet (`dorp.tres`, `wereld.tres`) op die tiles een
  collision-vorm staat. Hoe maps aan elkaar vastzitten staat in hoofdstuk 4.
- **Speler** (`player.gd`): kijkt eerst met `test_move()` of de volgende tile vrij is. Zo ja,
  dan schuift hij in 0,25 sec precies 16 px op. Ingedrukt houden = doorlopen zonder haperen.
- **Praten**: de speler kijkt welk object op de tile vóór hem staat en roept daar `interact()` aan.
  Elk object met een `interact()`-functie kan dus praten (NPC, bordje, kist, deur...).
  Loopt de speler tegen een object aan, dan roept hij `bump()` aan (als dat bestaat). Zo werkt de deur.
- **Tekst aanpassen**: klik in `wilgendal.tscn` op **OldMan**, **Sign** of **Door** en wijzig *Lines* in de Inspector.
- **Touch**: `touch_controls.gd` roept `Input.action_press()` / `action_release()` aan,
  dus de rest van het spel weet niet of je een toets of het scherm gebruikt.

### Plaatjes vervangen
Teken je eigen tiles en sprites (bijv. in **Aseprite**, **LibreSprite** of **Piskel**) in precies
dezelfde indeling en overschrijf de PNG's. Godot laadt ze dan automatisch opnieuw. Volg daarbij de
regels en het palet uit **`docs/ARTSTYLE.md`** (zie de checklist onderaan), dan past alles bij elkaar.
De maten:
- tiles: 16x16
- speler en NPC: frames van 16x24 (sheet 48x96)
- vijanden: 48x48
- gevechtssprites van helden: strook van 256x32 (8 frames van 32x32, voeten op x=16, y=30).
  Welk plaatje bij welke held hoort staat in `game_data.gd` bij `"battle_sprite"`.

Alles opnieuw genereren kan met `python3 tools/generate_art.py` (vereist `pip install pillow`).
Het lettertype maak je opnieuw met `python3 tools/generate_font.py` (vereist `pip install fonttools`).

### Maps uit tekst opnieuw bouwen (optioneel)
In `tools/build_maps.gd` staan het dorp en de wereldkaart als tekst:
- dorp: `#` = kassei, `T` = boom, `o` = heg, `h` = huis, …
- wereldkaart: `~` = zee, `^` = berg, `T` = bos, `HH` = stad, `D` = trap, …

Open `tools/build_maps.tscn` en druk op **F6**. Dat **overschrijft** de twee maps en hun TileSets.
Het script kiest daarbij automatisch de **randjes**:
- kassei en pad krijgen een grasrand naar het gras toe
- onder bomen en heggen valt schaduw
- de zee krijgt een kust met schuim
- bergen en bos sluiten op elkaar aan

Handig om snel te schetsen. Daarna kun je verder schilderen in de editor, maar daar worden de
randjes niet automatisch gekozen.

---

## 4. Maps en overgangen (dorp ↔ wereldkaart)

### Hoe het werkt
Elke map is een eigen scène in `scenes/maps/`. Een map heeft altijd dezelfde opbouw, met het
script `scripts/map.gd` op de bovenste node:

| Node        | Wat                                                                    |
|-------------|------------------------------------------------------------------------|
| `Ground`    | `TileMapLayer` met de grond. Elke tile heeft een **terrain**-woord (zie hieronder) |
| `Gebouwen`  | (optioneel) `TileMapLayer` boven de grond, bv. het huis                 |
| `Objects`   | Speler (**moet `Player` heten**), NPC's, bordjes, deuren. *Y Sort* staat aan |
| `Spawns`    | **MapSpawn**-punten: hier kom je binnen. De **naam** van de node telt (bv. `zuid_ingang`), plus *Facing* (kijkrichting) |
| `Exits`     | **MapExit**-zones: stap je erop, dan ga je naar een andere map           |
| `TouchControls` | De touch-knoppen                                                    |

Op de root-node van de map staan twee instellingen in de Inspector:
- **Map Name**: alleen ter info
- **Encounters**: monsters aan of uit. In Wilgendal staat dit **uit**, op de wereldkaart **aan**.

Een **MapExit** (`scripts/map_exit.gd`) heeft in de Inspector:
- **Size Tiles**: hoe groot de zone is, in tiles. De positie van de node is de linkerbovenhoek
  (een veelvoud van 16). In de editor zie je de zone als een roze vlak.
- **Target Map**: naar welke `.tscn`
- **Target Spawn**: de naam van het spawnpunt in die map
- **Lines**: laat je Target Map leeg en vul je Lines in, dan verschijnt er alleen een tekst.
  Zo werkt de trap: "Een trap leidt naar beneden... (dungeon komt later)".

Wat er gebeurt als je op een uitgang stapt:
1. `map.gd` ziet bij elk `stepped`-signaal van de speler of die tile in een MapExit ligt.
   Uitgangen gaan altijd vóór een gevecht.
2. `GameState.change_map(map, spawn)` onthoudt het spawnpunt, fadet naar zwart (`Transition`)
   en laadt de nieuwe scène.
3. De nieuwe map (`map.gd` → `_ready`) zet de speler op het spawnpunt met die naam,
   in de goede kijkrichting, en fadet weer in.

Bij een **gevecht** onthoudt `GameState` de map (`return_map`), de tile en de kijkrichting.
Na het gevecht laadt hij die map weer en zet de speler terug op precies die tile.
Bij **GAME OVER** ga je naar `GameState.START_MAP` (Wilgendal), spawnpunt `start`.

De huidige verbindingen:
- Wilgendal, uitgang `NaarWereld`: het kasseienpad aan de zuidrand (3 tiles breed).
  Die gaat naar de wereldkaart, spawnpunt `van_dorp`, net onder het stad-icoon.
- Wereldkaart, uitgang `NaarWachtershuis` (v0.13, was `NaarWilgendal`): het Wachtershuis-icoon op
  (14,30)-(15,30). Die gaat naar `wilgendal.tscn` ('Huis aan de bosrand'), spawnpunt `zuid_ingang`.
- Wereldkaart, uitgang `NaarWilgendal` (v0.13): het nieuwe dorp Wilgendal (2x2 icoon op (30,23)-(31,24)).
  Doel `scenes/maps/dorp_wilgendal.tscn`; zolang die scène niet bestaat zegt hij 'Wilgendal (komt later)'.
  Terug uit het dorp: spawn `van_wilgendal` op (30,25).
- Wereldkaart, uitgang `Trap` (v0.13): de ingang van De Vergeten Archieven (eerste dungeonkamer);
  terug kom je op spawn `van_archief`, net boven de trap.

### Random encounters per terrein
Elke tile in de TileSets heeft custom data **`terrain`**:
- wereldkaart: `gras`, `hoog_gras`, `zand`, `bos`, `berg`, `zee`, `stad`, `trap`
- dorp: `gras`, `kassei`, `pad`, `heg`, …

Je ziet het in de editor: open de TileSet, kies een tile en kijk onder *Custom Data*.
De kansen staan in **`scripts/data/game_data.gd` → `ENCOUNTER_RATES`**:
```
const ENCOUNTER_RATES := {"gras": 0.06, "hoog_gras": 0.07, "zand": 0.06, "bos": 0.10}
```
- Een terrein dat daar niet in staat (kassei, stad, trap, …) geeft nooit een gevecht.
- Een map met *Encounters* uit (het dorp) geeft sowieso nooit een gevecht.
- Welke gevechtsachtergrond bij welk terrein hoort, staat in `BATTLE_BACKDROPS`.

### Zelf een nieuw dorp (of andere map) maken – stap voor stap
1. **Kopiëren**: klik in het FileSystem-paneel met rechts op `scenes/maps/wilgendal.tscn` →
   **Duplicate…** → bv. `scenes/maps/beekdorp.tscn`. Open hem en geef de bovenste node een eigen naam.
2. **Schilderen**: klik op **Ground** en schilder je dorp met de tiles uit `dorp.tres`.
   Huizen zet je op de laag **Gebouwen**: kies daar in de TileSet het huis (5x5) en schilder het blok.
   Verplaats ook de **Door** naar de deur van je huis.
3. **Monsters**: zet op de root-node *Encounters* uit (dorp) of aan (veld, dungeon).
4. **Spawnpunt**: geef de MapSpawn onder `Spawns` een naam (bv. `ingang`) en zet hem op de tile
   waar je binnenkomt. Stel *Facing* in.
5. **Uitgang terug**: zet een MapExit onder `Exits` op de rand van je dorp, met
   - *Target Map* = `res://scenes/maps/wereldkaart.tscn`
   - *Target Spawn* = een spawnpunt op de wereldkaart. Maak er daar een bij, bv. `van_beekdorp`.
6. **Op de wereldkaart**: schilder een stad-icoon (tiles 113 + 114 in `wereld.tres`). Zet er een
   MapExit op met *Target Map* = jouw dorp en *Target Spawn* = `ingang`. Zet naast het icoon een
   MapSpawn `van_beekdorp` op een tile waar je kunt staan.
7. Druk op **F5** en loop erheen. Tip: wil je meteen in je nieuwe dorp beginnen, verander dan
   tijdelijk `START_MAP` in `scripts/game_state.gd`. De startscène van het project staat in
   Project Settings → *Application → Run → Main Scene*.

Een **binnenkamer** (een huis in) werkt precies zo: een kleine map met *Encounters* uit, en
een MapExit op de deur in plaats van de Door. Die MapExit gaat naar de kamer, en een MapExit
in de kamer gaat terug naar een spawnpunt vóór de deur.

---

## 5. Gevechten (Lufia 2-stijl)

### Hoe het werkt
1. **Random encounter** – `map.gd` luistert naar het signaal `stepped` van de speler.
   Bij elke stap op de wereldkaart is er een kans op een gevecht, afhankelijk van het terrein
   (gras 6%, bos 10%, zie `ENCOUNTER_RATES`). In het dorp nooit.
   Na een gevecht (en bij de start) heb je eerst 6 **veilige stappen** op terrein met monsters.
2. **Overgang** – `GameState` onthoudt de map, jouw tile en kijkrichting, `Transition` laat het scherm
   twee keer flitsen en fadet naar zwart, daarna wordt `scenes/battle/battle.tscn` geladen.
3. **Commando's kiezen** – zoals in Lufia 2 kies je eerst voor **alle** helden een actie:
   - **Aanval** → kies een vijand
   - **Magie** → kies een spreuk (kost MP) en een doel (Dennis kan geen magie, die regel is grijs)
   - **Item** → kies een item (aantal staat erachter) en een held
   - **Verdedig** → deze ronde halve schade
   - **Vluchten** → de hele party probeert meteen te vluchten (kans hangt af van AGI)
   Met **B** ga je een stap terug (submenu → commandomenu → vorige held).
4. **Ronde** – de vijanden kiezen een willekeurige held. Daarna is iedereen aan de beurt
   in volgorde van **AGI** (snelheid, met een beetje geluk). Je ziet berichten bovenin.
   Helden stappen naar voren en halen uit, vijanden springen naar hun doel.
   Schadegetallen verschijnen boven het hoofd, geraakte helden flitsen en hun statusvak kleurt
   even rood. Daarna zakt de balk.
   Houd **A** ingedrukt om de berichten sneller te laten gaan.
5. **Einde**
   - **Winst**: alle levende helden krijgen alle EXP, de party krijgt het goud.
     Dit staat in het overwinningsvenster, samen met per held "VOLG. LEVEL" (de EXP die nog nodig is).
     Genoeg EXP = **level-up** (stats stijgen volgens `growth`), daarna een pagina per held. KO-helden staan op met 1 HP.
   - **Vluchten gelukt**: terug naar dezelfde plek.
   - **Alle helden KO**: GAME OVER → je ontwaakt waar je deze kamer of map binnenkwam, met de
     voortgang van dat moment en iedereen volledig genezen (HP/MP). In een baaskamer telt die
     binnenkomst niet: bij de Golem ontwaak je in de Bibliotheek, bij de Wortelkoning in de
     Sporenkring. Alleen zonder kamer-checkpoint (direct na een nieuw spel) geldt de oude regel:
     Wilgendal voor het huis, volledig genezen, de helft van je goud kwijt.

### Schadeformules (in `scripts/battle/battle.gd`)
- Aanval: `ATK - DEF/2`, ±15% geluk, minimaal 1. Verdedigen = halve schade.
- Spreuk: `power + 2 × level`, ±10%.
- Vluchten: kans `50% + (gem. AGI party − gem. AGI vijanden) × 4%`, tussen 10% en 95%.

### Zelf aanpassen – alles staat in `scripts/data/game_data.gd`
| Wat                         | Waar in `game_data.gd`                 |
|-----------------------------|----------------------------------------|
| Helden (stats, spreuken, groei per level) | `HEROES`                 |
| Benodigde EXP per level     | functie `exp_for_level()`              |
| Vijanden (stats, EXP, goud, plaatje, speciale aanval) | `ENEMIES`    |
| Spreuken (MP-kosten, kracht, doel)        | `SPELLS`                 |
| Items en startinventaris    | `ITEMS`, `START_INVENTORY`             |
| Kans op gevecht per stap, per terrein | `ENCOUNTER_RATES` (0.06 = 6%) |
| Veilige stappen na gevecht  | `SAFE_STEPS`                           |
| Gevechtsachtergrond per terrein | `BATTLE_BACKDROPS`, `DEFAULT_BACKDROP` |
| Welke groepen vijanden (en hoe vaak) | `ENCOUNTER_GROUPS`            |

Voorbeelden:
- Nieuwe vijand: teken een PNG van 48x48 in `assets/sprites/enemies/`, voeg een blok toe aan
  `ENEMIES` en zet de id in een groep in `ENCOUNTER_GROUPS`.
- Nieuwe spreuk: voeg toe aan `SPELLS` (`target` = `"enemy"`, `"all_enemies"` of `"ally"`,
  `type` = `"damage"` of `"heal"`) en zet de id in de `"spells"`-lijst van een held.
- Geen gevechten tijdens het testen: zet in `scripts/game_state.gd` `encounter_multiplier` op `0.0`
  (met F2 kun je er op de wereldkaart toch één starten). Op `2.0` krijg je twee keer zo vaak gevechten.
- Het gevecht los testen: open `scenes/battle/battle.tscn` en druk op **F6** (kiest een willekeurige groep).

Let op: houd heldennamen op maximaal 5 letters en itemnamen kort, anders past het niet in de
vensters op 384x216.

### Het gevechtsscherm aanpassen (in `scripts/battle/battle.gd`, bovenaan)
- `HERO_SLOTS`: waar de voeten van held 1-4 staan (schuin, twee rijen).
- `ENEMY_SLOTS`: waar de vijanden staan, per aantal (1-4).
- `DETAIL`: 2 = het gevecht rendert 2x zo fijn ('16-bit plus'). Zet je dit op 1, dan werkt alles
  nog, maar de fijne art wordt dan grover getoond.
- Eigen gevechts-art: teken helden in frames van 80x80 (voeten op 40,77) en vijanden 2x zo groot
  als je ze op het scherm wilt hebben: vijanden worden altijd op de helft getoond.
- De statusvakken worden automatisch verdeeld over de ruimte tussen de D-pad en de B-knop.
  Bij 3 helden zijn ze 71 px breed, bij 4 helden 52 px.
- Een 4e held toevoegen: zet een extra blok in `HEROES` (met een eigen `battle_sprite`). Zonder
  eigen plaatje gebruikt het spel dat van Dennis.

---

## 6. Volgende stappen (suggesties)

1. **Dialogen & NPC's uitbreiden**
   - NPC's die rondlopen (gebruik dezelfde grid-code als de speler, met een timer).
   - Keuzes ("Ja / Nee") in het tekstvak, en een autoload `GameState.gd` met vlaggen
     (bv. `GameState.flags["oude_man_gesproken"] = true`) zodat NPC's iets anders zeggen.
2. **Menu** (zoals Lufia's ring-menu of een simpel lijstmenu)
   - Een `CanvasLayer` met `Control`-nodes: Items, Uitrusting, Status, Opslaan.
   - Voeg een actie `menu` toe (bv. Esc/X en een B-knop op het scherm).
3. **Gevechten uitbreiden**
   - Een herberg (NPC die je party geneest voor goud), een winkel voor Drankjes.
   - Spreuken/items die KO-helden weer tot leven wekken, statuseffecten (gif, slaap).
   - Lufia 2 heeft in dungeons zichtbare vijanden die **alleen bewegen als jij een stap zet**:
     koppel dat ook aan het signaal `stepped` van de speler.
   - Opslaan van `GameState.party` / `inventory` / `gold` (zie punt 6).
4. **Lufia-achtige dungeonpuzzels**
   - De **trap** op de wereldkaart is de plek voor de eerste dungeon: maak een map met
     *Encounters* aan en geef de MapExit `Trap` een *Target Map* (hoofdstuk 4).
   - Duwbare rotsblokken: een `CharacterBody2D` die 1 tile opschuift als de speler ertegenaan loopt
     (check vooraf met `test_move`, gebruik `bump()` net als de deur).
   - Schakelaars op de grond, deuren die opengaan, kamers die resetten als je ze verlaat.
   - Gereedschap zoals Lufia 2: pijl & boog (schakelaar op afstand), hookshot, bommen.
5. **Meer maps**: een binnenkamer voor het huis, meer dorpen. Zie hoofdstuk 4 (MapExit + MapSpawn).
6. **Opslaan/laden** van `GameState` met `FileAccess` + `JSON` in `user://`.
7. **Geluid**: `AudioStreamPlayer` voor muziek en een "blip" per letter in het tekstvak.

---

## 7. Exporteren naar Android (kort)

1. Installeer **OpenJDK 17** en de **Android SDK** (makkelijkst via Android Studio).
2. Godot: **Editor → Editor Settings → Export → Android**: vul het pad naar de *Java SDK* en
   *Android SDK* in. (Een debug-keystore maakt Godot meestal zelf aan.)
3. **Editor → Manage Export Templates → Download and Install** (eenmalig, moet dezelfde versie zijn als je Godot).
4. **Project → Export… → Add… → Android**. Laat *Gradle Build* uit voor een simpele APK.
   ETC2/ASTC-textures staan al aan in dit project.
5. Zet op je telefoon **Ontwikkelaarsopties → USB-foutopsporing** aan, sluit hem aan en klik op
   het **Android-icoontje** rechtsboven in de editor (*Remote Deploy*) om direct op je telefoon te spelen.
   Of klik **Export Project** voor een `.apk`-bestand.
6. Voor de Google Play Store heb je later een *release*-keystore en een `.aab` (Gradle build) nodig.

**Klaar in dit project (v0.10):** `export_presets.cfg` bevat een preset **"Android"** en een preset
**"Android arm64"** (alleen arm64-v8a, kleiner; export naar `../rpg_prototype_arm64.apk`):
- pakket `com.dennis.rpgprototype`, app-naam *SAPIENTIA* (tot v0.12: *RPG Prototype*), versie 0.13 (code 15)
- arm64-v8a + armeabi-v7a, liggend (`window/handheld/orientation` = sensor landscape), immersive
- officiële sjabloon-APK (geen Gradle): min SDK 21, target SDK 34. Een eigen min SDK (bv. 24) kan
  alleen met *Gradle Build*
- niet in de APK: `tools/`, `docs/`, `*.md`, `scripts/debug_autotest.gd` en `scripts/debug_menutest.gd` (`map.gd` kijkt eerst
  of de tester bestaat)
- **Renderer op telefoons: `gl_compatibility`** (OpenGL ES 3.0), via de override
  `rendering/renderer/rendering_method.mobile`. Op de desktop blijft het "mobile". Godot 4.3 heeft
  nog geen automatische terugval van Vulkan naar OpenGL, en voor 2D-pixelart ziet het er hetzelfde
  uit. Zo werkt het op de meeste toestellen.
- F2 (gevecht forceren) werkt alleen in debug-builds (`OS.is_debug_build()`): in een release-APK
  staat hij uit.

Exporteren zonder editor (sleutel via omgevingsvariabelen, zodat er geen wachtwoord in het project staat):

```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/pad/naar/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<wachtwoord>
godot --headless --path . --export-release "Android" ../rpg_prototype.apk
```

Let op: een update kun je alleen over de oude versie heen installeren als hij met **dezelfde
sleutel** is ondertekend. Bewaar de keystore dus goed.

---

## 8. Automatische test (voor ontwikkelaars)

```
godot --headless --path . -- --autotest
```
Laat de speler zelf spelen:
- **In het dorp**: start voor het huis, deur op slot, botsing met de heg, bordje, NPC, touch.
  Daarna meer dan 50 stappen met 100x de encounter-kans, zonder gevecht. Dan de uitgang naar
  de wereldkaart.
- **Op de wereldkaart**:
  - het spawnpunt
  - zee en berg blokkeren, bos en zand zijn begaanbaar
  - een encounter op gras met een volledig gevecht: een ronde met Aanval + Vuur + Drankje,
    terug met B, winst met EXP/level-up, terug op dezelfde tile, veilige stappen
  - tikken op menuknoppen en vijanden, vluchten (F2)
  - de trap-tekst, de bos-achtergrond in het bos
  - het stad-icoon terug het dorp in en weer uit
  - game over + respawn waar je de wereldkaart binnenkwam (14,31), zonder goudverlies
Daarnaast test hij het gevechtsscherm:
- of de balken gelijk zijn aan de echte HP/MP
- tikken op een heldensprite en op een statusvak
- de inhoud van het overwinningsvenster
- dat niets onder de D-pad/A/B ligt
- een gevecht met 4 helden
- '16-bit plus': het gevecht rendert op 768x432, de scène staat op schaal 2, de heldenframes zijn
  80x80 op schaal 0.5, de vijanden zijn 2x zo fijn, de HD-vensters zijn actief (alleen met een echt
  venster) en de overworld staat na het gevecht weer op 384x216

Hij print `PASS`/`FAIL` per check.

**Kamer-checkpoint** (v0.19, respawn na game over):
```
godot --headless --path . -- --checkpointtest
```
Gewone dungeonkamer, wereldkaart, Golem (met opslaan/laden), Wortelkoning, oude en kapotte save, verslagen baas.

**Veldmenu-test** (los, sneller):
```
godot --headless --path . -- --menutest
godot --path . -- --menutest --shots=/pad/naar/map     (met venster: screenshots 384x216 + 3x)
```
Opent het menu en loopt alle schermen door met gesimuleerde knoppen en tikken: Drankje op een
gewonde held (HP, begrenzing, aantal), Toverwater, grijze items, Status (EXP-formule, wisselen
van held, level-up), Genees buiten het gevecht, Bestiarium, Opties (tekstsnelheid, touch,
volume, CRT, autosave; `settings.cfg` geschreven en opnieuw ingelezen), Opslaan via het menu,
menu dicht = speler los, niet openen tijdens tekstvak/mapwissel, en automatisch opslaan (na
mapwissel, na winst, app naar achtergrond; niet tijdens gevecht/mapwissel/tekstvak of als het
uit staat; 'Doorgaan' laadt de nieuwste; kapotte/onvolledige saves laden zonder crash).
Beide tests gebruiken eigen bestanden (`user://autotest_*`), je echte save en opties blijven heel.

Met een echt venster kun je ook screenshots maken:
`godot --path . -- --autotest --screenshot=/tmp/shot.png --battle-shots=/tmp/battle --overview=/tmp/wereld.png`
(`--overview` tekent de hele wereldkaart in één plaatje van 960x720.)
Gevechts-screenshots worden op 1152x648 opgeslagen. Het fijne raster van 768x432 wordt daarbij
1,5x vergroot, dus niet elke pixel is even breed. Daarom komt er ook een `*_2x.png` bij: 1536x864,
precies 2x, met elke fijne pixel als 2x2.

---

## 9. Sessielogboek (playtest)

Het spel houdt een licht logboek bij (`scripts/sessielog.gd`, autoload `Sessielog`): waar je loopt,
waar je tegenaan loopt, welke kaarten, dialogen en cutscenes, hoe gevechten gaan, doden en respawns.
Eén JSON-object per regel in `user://sessielogs/sessie_<id>.jsonl` (hooguit 8 sessies, 3 MB per sessie).
Gebufferd: hooguit elke 2 s of na 48 regels naar schijf. Geen spelersnaam, geen apparaat-id, geen locatie.

- Aan/uit: **Opties > Session Log**. In autotests staat hij uit.
- Versturen: **Opties > Export Log** (web: download; Android/pc: Downloads of Documenten, anders
  blijft het in de app-map en gaat het laatste stuk naar het klembord).
- Art: elke `kaart`- en `pos`-regel heeft `stijl` (`som`/`oud`, uit `assets/tilesets/som/gebieden.json`
  via `kaart_stijl.gd`) en `tileset`; `kaart` en `kaart_info` ook `gebied`, `palet` en (kaart_info) de
  grondrechthoek `rect`. Zo koppelt RPG ART feedback aan de art die op het scherm stond.
- Samenvatten: `python3 tools/sessie_samenvatting.py sapientia_sessielog_<id>.jsonl` (of `--json`).
- Heatmap: `... --heatmap` (of `--heatmap=map`) schrijft per kaart `heatmap_<kaart>.png`: bezoeken per
  tegel over de hele kaart, minstens 1080 px breed (leesbaar op een telefoon).
- Voorbeeldlogboek: `SESSIELOG_BEWAAR=/tmp/log.jsonl godot --headless --path . -- --sessielogtest`.
- Test: `godot --headless --path . -- --sessielogtest`.

## Licenties

- Alle plaatjes in `assets/` en `icon.png` zijn zelf gegenereerd met `tools/generate_art.py`
  (+ `tools/art_maps.py`, `tools/art_v7_*.py`, `tools/art_v8_*.py`; v6: `tools/art_battle.py`, `tools/art_battle_bg.py`) en vrij te gebruiken.
  De '16-bit plus' gevechts-art volgt alleen een stijlrichting (een AI-mockup die Dennis koos);
  er is niets van overgenomen. Het dorp en de wereldkaart volgen alleen de *stijl*
  van Lufia 2 (zie ARTSTYLE.md). Er is niets overgetekend.
- Het lettertype **Dauwpixel** is eigen werk (`tools/generate_font.py`) en ook vrij te gebruiken.
- **`docs/ref_*.png` zijn uitsneden uit een YouTube-video van Lufia 2.** Ze zijn alleen intern
  referentiemateriaal voor de stijlgids. **Niet meeleveren, niet publiceren en niet in het spel
  gebruiken.** De map `docs/` heeft een `.gdignore`, dus Godot importeert en exporteert hem niet.
  Haal die bestanden weg voordat je het project ooit openbaar deelt.
- Lufia is een merk van de respectievelijke eigenaren. Het spel zelf (`assets/`, `scenes/`,
  `scripts/`) bevat geen materiaal uit Lufia.
