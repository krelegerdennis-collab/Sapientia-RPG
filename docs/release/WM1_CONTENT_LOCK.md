# WM1 Content Lock (release-roadmap, fase 1: feature freeze en content lock)

Basis: `main` op `61986e9` (merge van PR #208), 24 okt 2026. Alleen documentatie: geen code, geen scènes, geen data,
geen tests, geen workflows aangepast.

**Status: voorstel tot akkoord.** De lock is bindend vanaf de merge van deze PR (Dennis en RPG Forge reviewen en
mergen; agents mergen niet). Tot dan is alles in dit document een voorstel, ook de ship/cut-aanbevelingen in sectie 3.

Dit document hoort bij `docs/release/WM1_RELEASE_CHECKLIST.md` (de acht fases; dit is fase 1).

## 0. Hoe te lezen

- **Scope = Worldmap 1 (WM1) en niets anders.** WM2 en WM3 staan on hold. `wacht/wm2/` is voor dit document niet
  gelezen en niet aangeraakt. `wacht/.gdignore` bestaat, dus Godot importeert en exporteert die map niet.
- Elke regel in sectie 2 is een belofte: dit **levert** de WM1-release, niet meer en niet minder. Wat hier niet staat
  en niet bestaat, komt er niet bij (sectie 4).
- Elke inventarisregel noemt het bestand dat de waarheid bevat. De inventaris is gelezen uit `main` en waar mogelijk
  met een headless Godot-script uit de echte data gehaald (`GameData.ENEMIES`, `DungeonRooms`, `PuzzleRooms`,
  `BerggrotData`, `Archief2Rooms`, `WoudRooms`, `QuestData`). Als code en dit document verschillen, wint de code en
  moet dit document in een "lock-wijziging" worden gecorrigeerd (sectie 5).
- Spelertekst is Engels. Hier staan voor leesbaarheid de Engelse spelernamen tussen aanhalingstekens, met de interne
  id (Nederlands, nooit hernoemen) erachter. Namen volgens `docs/lore/CANON.md`: Dennis = **Dax**, Noor = **Vesper**,
  Lotte = **Seren** (`GameData.HEROES`, `GameState.migrate_name`).
- Eerdere triage: `docs/BACKLOG_WM1.md` (stand `c55b77b`). Waar `main` sindsdien is veranderd (CI-matrix aangevuld,
  vang-tutorial, power scaling v2, sessiefix) is dit document leidend.

### Lock-cijfers (om drift te zien)

Gemeten op `61986e9`. Een afwijking na de freeze zonder lock-wijziging is een regel-overtreding.

| Tabel | Aantal | Bron |
|---|---:|---|
| Kaartscènes in `scenes/maps/` | 48 (46 in de speelroute, 2 dev-only: H1) | `scenes/maps/*.tscn` |
| Vijanden in `GameData.ENEMIES` | 26 | `scripts/data/game_data.gd` |
| Berggrot-monsters (apart van ENEMIES) | 3 | `scripts/data/berggrot_data.gd` (`MONSTERS`) |
| Diepe Grot-bazen (verdiepingen) | 12 (10, 20, 25, 30, 40, 50, 60, 70, 75, 80, 90, 99) | `scripts/data/dungeon100_scaling.gd` (`BOSSES`) |
| Helden | 5 (Dax, Vesper, Seren, Kael Voss, Orion) | `GameData.HEROES` |
| Items (`ITEMS`) / sleutelvoorwerpen / uitrusting | 50 / 4 / 85 | `game_data.gd` |
| Blauwe-kist-uitrusting (Diepe Grot) | 36 | `scripts/data/grade_gear.gd` |
| Spreuken | 81 (21 / 20 / 20 / 20 per grade 1-4) | `scripts/data/spells.gd` |
| Codex-soorten / Codex-vaardigheden | 18 / 29 | `scripts/data/codex_data.gd` |
| Kernfragmenten / kerngevechtsvaardigheden / wereldvaardigheden | 2 / 1 / 2 | `scripts/data/kern_data.gd` |
| Opdrachten (6 hoofd, 1 zij) / acts in de questlog | 7 / 6 (act 3-6 "later") | `data/quests.json` |
| Story-events | 58 | `scripts/data/story_data.gd` (`EVENTS`) |
| BGM-tracks in het manifest / met bestand | 24 / 13 | `assets/audio/audio_manifest.json`, `assets/audio/bgm/` |
| SFX in het manifest / ontbrekende bestanden | 99 / 0 (allemaal placeholders) | `assets/audio/audio_manifest.json` |
| `TODO(design)` en `TODO(verhaal)` in WM1-code (zonder tests) | 56 | `rg "TODO\((design\|verhaal)" scripts world_warper pvp` |

## 1. Wat WM1 is

WM1 is het speelbare eerste eiland met alles wat eraan hangt, in speelvolgorde:

1. Proloog bij het Wachtershuis (Dax, Opa, de mantel, de zwaardles, de nacht).
2. Wereldkaart en Willowdale (winkels), Het Eerste Archief (4 verdiepingen, baas de Golem).
3. Na de Golem: Mapleton, het Donker Woud (baas de Root King, Vesper komt in de groep) en de bouwplaats met de berggrot.
4. Het Levende Archief (Archief 2, via de kas of via de berggrot): Seren komt in de groep, bazen De Wurger en De Genezer.
5. De World Warper-hub (opent na De Genezer): ECHO, rustkamer, rekruten (Kael Voss, Orion), de Diepe Grot als simulatie.

Routes naar Archief 2 (beide blijven):

- **Route A (kas):** wereldkaart > `leven_ingang` > `leven_v1_plaat` > `archief_2_v2_gang` (open na de Golem; event `naar_leven`).
- **Route B (berggrot):** wereldkaart > `berggrot_bouwplaats` (open zodra Vesper in de groep zit, vlag `noor_lid`) >
  `berggrot_mond` > `berggrot_grendel` > `berggrot_nerf` > `berggrot_geheim` > `berggrot_uitmond` >
  `archief_2_v1_entree` > `archief_2_v1_plaat` > `archief_2_v2_gang`.

Daarna is de volgorde in Archief 2 voor beide routes gelijk: Seren > Ketting-, Tegen- en Licht-platen > De Wurger >
Hal van De Genezer > De Genezer > World Warper-hub.

Buiten WM1 (niet bouwen, niet lezen, niet testen als releasevoorwaarde): Worldmap 2 en 3, Archief 3 tot en met 6, de
dorpen Stoomwijk, Hoge Toren en Sterrenhaven, Grade 4-wapens en -sets voor nieuwe karakters, ECHO's twist (H-1 tot en
met H-5), De Spiegel-onthulling, alle verhaal na Act 2. Zie `docs/BACKLOG_WM1.md` sectie D en `TODO.md`.

## 2. Inventaris: dit levert WM1

### 2.1 Gebieden en kaarten

Alle paden relatief aan de projectmap. "Kaartdata" is waar de kamer in staat (layout, uitgangen, monsters, kisten).

**Wereldkaart en proloog**

| Kaart | Scène | Kaartdata | Inhoud |
|---|---|---|---|
| "World Map" | `scenes/maps/wereldkaart.tscn` | scène zelf | willekeurige gevechten (`encounters = true`), uitgangen naar alle WM1-plaatsen, `WorldWarperFlyover` (zwevend gebouw, `world_warper/art/flyover.gd`) |
| "House at the Wood's Edge" (Wachtershuis-erf) | `scenes/maps/wilgendal.tscn` | scène zelf | Opa, put, kist, ruïnes, Archief-ingang, HP- en MP-boek, deur naar het huis |
| "The House" (interieur) | `scenes/maps/huis_wilgendal.tscn` | scène zelf | opslagboek, schilderij, Opa 's avonds |

**Willowdale (dorp met winkels)**

| Kaart | Scène | Kaartdata | Inhoud |
|---|---|---|---|
| "Willowdale" | `scenes/maps/dorp_wilgendal.tscn` | `scripts/data/wilgendal_dorp.gd`, `scripts/village/` | 4 winkelpanden, 4 woonhuizen, Dax' huis, plein, beek met brug, molen, 5 sfeer-NPC's, 3 vaste dorpelingen, Garrett |
| "Shop" (alle interieurs) | `scenes/maps/wilgendal_binnen.tscn` | `wilgendal_dorp.gd` (`KAMERS`), `scripts/village/pand_binnen.gd` | binnenkant van de 5 winkels/huizen met toonbank |

**Het Eerste Archief (Archief 1, "Forgotten Archives")**: route in volgorde van `DungeonRooms.ORDER`.

| Verd. | Kaart | Scène | Bijzonder |
|---:|---|---|---|
| 1 | "Forgotten Archives" | `scenes/maps/archief_ingang.tscn` | uitgang naar de wereldkaart, opslagboek, 3 monsters |
| 1 | "Dusty Corridor" | `scenes/maps/archief_v1_gang.tscn` | kist `kist_1b` (2x Potion) |
| 2 | "Cabinet Hall" | `scenes/maps/archief_v2_kastenzaal.tscn` | trap |
| 2 | "Reading Room" | `scenes/maps/archief_v2_leeszaal.tscn` | kist `kist_2b` (Leather Hood) |
| 2 | "Stair Hall" | `scenes/maps/archief_v2_trapzaal.tscn` | bewaker Knowledge Beast, kist `kist_2c` (3x Potion), HP-boek |
| 3 | "Pillar Hall" | `scenes/maps/archief_v3_zuilenhal.tscn` | kist `kist_3a` (Cover Shield), HP-boek |
| 3 | "Puzzle Room" | `scenes/maps/archief_puzzel.tscn` (puzzel `archief_puzzel`) | drukplaten, hendel, geheime deur, kist `kist_vonkzwaard` (Spark Sword) |
| 3 | "Corridor" | `scenes/maps/archief_v3_gang.tscn` | 3 monsters |
| 4 | "Warden's Corridor" | `scenes/maps/archief_v4_wachtersgang.tscn` | HP-boek |
| 4 | "Vestibule" | `scenes/maps/archief_v4_voorhal.tscn` | bewaker Knowledge Beast, kist `kist_4b` (2x Potion) |
| 4 | "Library" | `scenes/maps/archief_bibliotheek.tscn` | opslagboek, 3 borden |
| 4 | "Golem Hall" | `scenes/maps/archief_golemhal.tscn` | baas de Golem (`kennis_beest`, boss), Inktwurm-kast (`scripts/dungeon/inktwurm_kast.gd`) |

Kaartdata: `scripts/data/dungeon_rooms.gd` (`ROOMS`, `ORDER`), `scripts/data/puzzle_rooms.gd` (`archief_puzzel`).

**Mapleton ("Mapleton")**: pas open na de Golem.

| Kaart | Scène | Inhoud |
|---|---|---|
| "Mapleton" | `scenes/maps/esdoorn.tscn` | 5 NPC's, put, bord naar het Donker Woud, 3 deuren |
| "Mapleton - Vesper's House" | `scenes/maps/esdoorn_huis_noor.tscn` | Elise |
| "Mapleton - The Maple Inn" | `scenes/maps/esdoorn_herberg.tscn` | Innkeeper Walt, opslagboek |

**Het Donker Woud ("Dark Wood")**: kaartdata `scripts/data/woud_rooms.gd`, route in volgorde.

| Verd. | Kaart | Scène | Bijzonder |
|---:|---|---|---|
| 1 | "Wood's Edge" | `scenes/maps/woud_rand.tscn` | uitgang naar de wereldkaart, kist `kist_w1` (2x Potion), HP-boek |
| 1 | "Root Path" | `scenes/maps/woud_pad.tscn` | kisten `kist_w2` (2x Magic Water), `kist_w4` (Blank Book) |
| 2 | "Mist Pool" | `scenes/maps/woud_mistpoel.tscn` | kist `kist_w3` (Iron Helm), bord |
| 2 | "Spore Ring" | `scenes/maps/woud_sporenkring.tscn` | opslagboek, kist `kist_w5` (Blank Book), bewaker Root Crawler-groep |
| 3 | "Clearing" | `scenes/maps/woud_open_plek.tscn` | baas de Root King, Vesper in de cocon, Wood Wraith (Zingend Graan) |

**Bouwplaats en berggrot ("Hollow Mountain")**: kaartdata `scripts/data/berggrot_data.gd`.

| Kaart | Scène | Bijzonder |
|---|---|---|
| "Tunnel Worksite" | `scenes/maps/berggrot_bouwplaats.tscn` | 4 bouwvakkers, hek tot `noor_lid`, checkpoint |
| "Hollow Mountain" | `scenes/maps/berggrot_mond.tscn` | opslagboek, 2 monsters |
| "Hollow Mountain - Bolt Gate" | `scenes/maps/berggrot_grendel.tscn` (puzzel `berggrot_grendel`) | puzzelkamer |
| "Hollow Mountain - Vein" | `scenes/maps/berggrot_nerf.tscn` | opslagboek, 2 monsters |
| "Hollow Mountain - Secret Chamber" | `scenes/maps/berggrot_geheim.tscn` (puzzel `berggrot_geheim`) | kisten `kist_bergnerfstaf` (Mountain Vein Staff), `kist_adersteen` (Veinstone) |
| "Hollow Mountain - Outlet" | `scenes/maps/berggrot_uitmond.tscn` | opslagboek, uitgang naar Archief 2 |

**Het Levende Archief (Archief 2, "The Living Archive")**: kaartdata `scripts/data/archief2_rooms.gd`
(`ROOMS`, `rooms()`), puzzels in `scripts/data/puzzle_rooms.gd`.

| Verd. | Kaart | Scène | Bijzonder |
|---:|---|---|---|
| 1 | "The Living Archive" (route A) | `scenes/maps/leven_ingang.tscn` | story-event `archief2_keten`, opslagboek |
| 1 | "The Living Archive - Growth Plate" | `scenes/maps/leven_v1_plaat.tscn` (puzzel `leven_v1_plaat`) | groei-plaat, route A |
| 1 | "The Living Archive" (route B) | `scenes/maps/archief_2_v1_entree.tscn` | opslagboek |
| 1 | "Growth Plate" (route B) | `scenes/maps/archief_2_v1_plaat.tscn` | groei-plaat, route B |
| 2 | "Greenhouse Passage" | `scenes/maps/archief_2_v2_gang.tscn` | beide routes komen hier samen |
| 2 | "Seren's Room" | `scenes/maps/archief_2_v2_lotte.tscn` | bewaker Seren (glitch), Seren sluit aan |
| 3 | "Chain Plates" | `scenes/maps/archief_2_v3_ketting.tscn` | ketting-platen |
| 3 | "Cabinet and Lever" | `scenes/maps/leven_v3_combi.tscn` (puzzel `leven_v3_combi`) | kast en hendel |
| 3 | "Counter Plates" | `scenes/maps/archief_2_v3_tegen.tscn` | tegen-platen |
| 3 | "Light Plates" | `scenes/maps/archief_2_v3_licht.tscn` | licht-platen (vereist Seren met Licht grade 1) |
| 3 | "The Strangler" | `scenes/maps/archief_2_v3_wurger.tscn` | baas De Wurger |
| 4 | "Hall of the Mender" | `scenes/maps/archief_2_v4_hal.tscn` | 1 monstergroep |
| 4 | "The Mender" | `scenes/maps/archief_2_v4_genezer.tscn` | baas De Genezer, zet de hub open |
| 4 | "World Warper" | `scenes/maps/archief_2_warper.tscn` | opslagboek, uitgang van Archief 2 (`archief2_warp.gd`) |

**World Warper-hub**: kaarten in `world_warper/maps/`, kamers in `world_warper/kamers/`.

| Onderdeel | Scène | Data | Open |
|---|---|---|---|
| Buitenkant | `world_warper/maps/exterieur.tscn` | `world_warper/data/rooms.gd` | na De Genezer (`world_warper_unlocked`) |
| Hal met warp-ring | `world_warper/maps/hal.tscn`, `world_warper/maps/warp_ring.tscn` | `rooms.gd` | altijd (na unlock) |
| Hanger-nis | `world_warper/maps/hanger_nis.tscn` | `rooms.gd` | altijd (na unlock) |
| "The Atrium" | `world_warper/kamers/hal.tscn` | `world_warper/kamers/kamers.gd` | act 1 |
| "The Rest Room" (genezen, party wisselen, opslaan) | `world_warper/kamers/rustkamer.tscn` | `kamers.gd` | act 1 |
| "ECHO's Chamber" (ingang Diepe Grot, questlog) | `world_warper/kamers/echo_kamer.tscn` | `kamers.gd`, `scripts/data/echo_grot.gd` | act 1 |
| "The Screening Room" (Bestiary- en Codex-terminals) | `world_warper/kamers/beeldkamer.tscn` | `kamers.gd` | act 2 (party Lv 14+) |
| "The Training Hall" (oefengevecht zonder buit) | `world_warper/kamers/trainingshal.tscn` | `kamers.gd` | act 3 (Lv 20+) |
| "The Workshop" (3 recepten) | `world_warper/kamers/werkplaats.tscn` | `scripts/data/werkplaats_recepten.gd` | act 4 (Lv 26+) |
| "The Exchange" (winkel) | `world_warper/kamers/handelskamer.tscn` | `ShopData.SHOPS["handelskamer"]` | act 5 (Lv 32+) |
| "The Core" | `world_warper/kamers/kern.tscn` | `kamers.gd` | act 6 (Lv 37+): zie H3 |
| Warp-keuze ("Choose a world") | `world_warper/warp/warp_view.tscn` | `world_warper/warp/destinations.gd` | World 1 open; World 2 en 3 tonen "Locked" |

Act is hier het hoogste level in de party (`LevelScale.act_for_level`; act 2 begint op Lv 14).

**De Diepe Grot ("Deep Learning Simulation", Dungeon100)**: alleen via ECHO in ECHO's Chamber.

| Onderdeel | Bestand |
|---|---|
| Kamer en generator (100 verdiepingen, 16x16, seed per run en verdieping) | `scenes/maps/dungeon100.tscn`, `scripts/dungeon/dungeon100_generator.gd`, `scripts/dungeon/dungeon100_room.gd` |
| Regels: rustverdieping elke 10, warpers op 1, 25, 50, 75, 99, checkpoint, game over | `scripts/dungeon/dungeon100_rules.gd`, `scenes/dungeon100_rustpunt.tscn`, `scenes/dungeon100_warper.tscn`, `scenes/dungeon_exit_warper.tscn` |
| Monsterpools per gebied (Archief 1 > Woud > Bergtunnel > Archief 2 > grot-eigen) | `scripts/dungeon/dungeon100_content.gd` (`POOLS`) |
| Schaal, bazen, buit | `scripts/data/dungeon100_scaling.gd`, `scripts/data/dungeon100_reward.gd`, `scripts/data/endgame_bestiary.gd` |
| Blauwe Kisten, Mimic, Warp-kristal | `scripts/data/dungeon100_blue.gd`, `scripts/data/grade_gear.gd` |
| Puzzelverdiepingen | `scripts/dungeon/dungeon100_puzzel.gd`, `scripts/data/grot_puzzels.gd`, `scripts/data/grot_layouts.gd`, `scripts/data/grot_kamers.gd` |
| De Koopman (H-5) | `scripts/dungeon/dungeon100_koopman.gd`, `scripts/data/koopman_data.gd`, `scripts/data/koopman_winkel.gd` |

### 2.2 NPC's

Een NPC met `event` praat via `scripts/data/story_data.gd`; zonder event staat de tekst in de scène of kamerdata.

| Naam (speler) | id / event | Plek | Bestand |
|---|---|---|---|
| Old Man (Opa) | `opa` | Wachtershuis-erf, 's avonds in het huis | `scenes/maps/wilgendal.tscn`, `scenes/maps/huis_wilgendal.tscn` |
| Jack Hammond (smid, twee balies) | `wilgendal_wapen`, `wilgendal_pantser` | Willowdale | `wilgendal_dorp.gd` (`PANDEN`), `scripts/data/shop_data.gd` |
| "Accessories", "Magic Shop" (winkeliers) | `wilgendal_accessoire`, `wilgendal_magie` | Willowdale | idem (zie H12 voor de namen) |
| Aunt Minna | `wilgendal_kruiden` | Willowdale | idem |
| Bramwell, Elsie, Fern, Walt, Simon (sfeer, lopen een lus) | `SFEER` | Willowdale | `wilgendal_dorp.gd` |
| Merchant, Granny Wil, Farmer (staan, praten) | `P10_DORPELINGEN` | Willowdale | `wilgendal_dorp.gd` |
| Garrett the Miller | `gerrit`, `gerrit_ja`, `gerrit_weigert` | Willowdale (molen) | `scenes/maps/dorp_wilgendal.tscn`, `story_data.gd` |
| Marigold | `marit`, `marit_boeken` | Mapleton | `scenes/maps/esdoorn.tscn` |
| Old Bramwell, Jensen, Tobias | `bram`, `jens`, `tobias` | Mapleton | `scenes/maps/esdoorn.tscn` |
| Vesper | `noor_ontmoeting`, `cocon`, `noor_bevrijd`, `noor_woud` | Mapleton, Clearing | `esdoorn.tscn`, `woud_rooms.gd` |
| Elise | `ilse` | Vesper's House | `scenes/maps/esdoorn_huis_noor.tscn` |
| Innkeeper Walt | `herbergier`, `herberg_rust`, `herberg_nee` | The Maple Inn | `scenes/maps/esdoorn_herberg.tscn` |
| Foreman Henrik, Worker Sunny | `bouwplaats_voorman`, `bouwplaats_werker` | Tunnel Worksite | `scenes/maps/berggrot_bouwplaats.tscn` |
| Worker George, Worker Fay (alleen sfeer) | geen event | Tunnel Worksite | idem |
| Wood Wraith (Zingend Graan) | `zingend_zaad`, `zingend_zaad_na` | Clearing, alleen tijdens de opdracht | `woud_rooms.gd` |
| Seren | monster `lotte` (glitch), `archief2_lotte_lid` | Seren's Room | `archief2_rooms.gd`, `scripts/data/archief2.gd` |
| ECHO | gids, ECHO's Chamber, Diepe Grot-gesprek, questlog | hub | `world_warper/guide/gids.tscn`, `world_warper/guide/dialoog.gd`, `world_warper/kamers/echo_gesprek.gd`, `scripts/data/echo_grot.gd` |
| Kael Voss, Orion (rekruten, "Join the party?") | `hero_id` | hub-hal | `world_warper/services/rekruut.gd` |
| the Merchant (H-5) | bezoeken 1-3 vaag, 4-7 fragmenten, 8+ waarheid + token | Diepe Grot (koopmanverdieping) | `scripts/data/koopman_data.gd` |
| Rondlopers (party en gevangen Codex-wezens) | decoratie, geen dialoog | hub-hal | `world_warper/wander/wanderers.gd` |

Gesloten huizen met een vaste melding (geen NPC): Mayor's House, het rietgedekte huis, het huis met gesloten luiken,
Bramwell and Elsie's House (`wilgendal_dorp.gd`); drie deuren in Mapleton (`esdoorn.tscn`).

### 2.3 Opdrachten

Bron: `data/quests.json`, regels in `scripts/data/quest_data.gd`, ECHO-zinnen per act in dezelfde JSON.
Het veldmenu toont daarnaast de lopende opdracht uit `StoryData.QUESTS` (zie H7).

| id | Soort | Act | Titel (speler) | Klaar bij |
|---|---|---|---|---|
| `archieven_in` | hoofd | 1 | "The Archives of Sapientia" (mantel, water, kruiden, zwaardles, Opa achterna) | `story_step` 60 |
| `golem` | hoofd | 1 | "Defeat the Golem" | vlag `bewaker:archief_golemhal/golem` |
| `vesper` | hoofd | 2 | "Save Vesper from the Dark Wood" | vlag `noor_gered` |
| `seren` | hoofd | 2 | "Seren joins the party" | vlag `archief2_lotte_lid` |
| `genezer` | hoofd | 2 | "Defeat the guardian of the second Archive" | vlag `bewaker:archief_2_v4_genezer/genezer` |
| `warper` | hoofd | 2 | "Reach the World Warper" | vlag `world_warper_unlocked` |
| `zingend_graan` | zij | 2 | "The Singing Grain" (Garrett) | vlag `zingend_graan_klaar` |

Act 3 tot en met 6 staan in de JSON met tekst "That record is still empty. A story for later." en vallen buiten WM1.

### 2.4 Vijanden en bazen

**Gewone vijanden en bazen in `GameData.ENEMIES`** (bestiarium-nummer = `no`):

| id | Naam (speler) | Waar in WM1 |
|---|---|---|
| `mosslijm` | Moss Slime | wereldkaart, Archief 1 verd. 1, `leven_ingang`, Diepe Grot, zwaardles |
| `moskonijn` | Moss Rabbit | wereldkaart, Archief 1 verd. 1, `leven_ingang`, Diepe Grot |
| `papiergeest` | Paper Wraith | wereldkaart, Archief 1, Diepe Grot |
| `glitchmot` | Glitch Moth | wereldkaart, Archief 1, Diepe Grot |
| `mech_wachter` | Mech. Warden | Archief 1 verd. 2-4, Diepe Grot |
| `kennis_beest` | The Knowledge Beast | wereldkaart (zeldzaam), 2 bewakers in Archief 1, **baas de Golem** (boss-stats) |
| `inktwurm` | Ink Worm | uniek, Inktwurm-kast in de Golem Hall (Codex-tutorials) |
| `wortelkruiper` | Root Crawler | Donker Woud, `archief_2_v1_entree`, Diepe Grot |
| `mistuil` | Mist Owl | Donker Woud, Diepe Grot |
| `sporenzwam` | Spore Cap | Donker Woud, `archief_2_v2_gang`, Diepe Grot |
| `woudgeest` | Wood Wraith | opdracht Zingend Graan, Diepe Grot |
| `wortelkoning` | The Root King | **baas** Clearing |
| `lotte_glitch` | Seren | **bewaker** Seren's Room (geen kill: ze sluit aan) |
| `wurger` | The Strangler | **baas** Archief 2 verd. 3 |
| `genezer` | The Mender | **baas** Archief 2 verd. 4 |
| `rankje` | Tendril | Archief 2, Diepe Grot |
| `sporekop` | Sporehead | Archief 2, Diepe Grot |
| `doornige_loper` | Thorn Runner | Archief 2, Diepe Grot |
| `bloeiende_schrik` | Blooming Dread | Archief 2, Diepe Grot |
| `wortelgeest` | Rootghost | Archief 2, Diepe Grot |
| `mimic` | Mimic | alleen Blauwe Kisten in de Diepe Grot |
| `shard_codex`, `scanline_wolf` | Shard Codex, Scanline Wolf | alleen Diepe Grot verd. 76-90 |
| `aureate_watcher`, `ledger_scarab` | Aureate Watcher, Ledger Scarab | alleen Diepe Grot verd. 91-100 |
| `echo` | ECHO | Codex-soort (hub en Diepe Grot) |

**Berggrot-monsters** (niet in ENEMIES, zie H6): `steenluis` Stone Louse, `druipslak` Drip Slug, `adermot` Vein Moth,
in `scripts/data/berggrot_data.gd` (`MONSTERS`); ze komen ook in de Diepe Grot-pool "bergtunnel" (verd. 51-100).

**Diepe Grot-bazen** (`dungeon100_scaling.gd` `BOSSES`, `scripts/data/endgame_bestiary.gd`): 10 Page Warden, 20 Glitch
Queen, 25 The Shadow of H-6, 30 Spore Lord, 40 Root Mother, 50 The Cycle, 60 Mist Lord, 70 Seal Warden, 75 The Judge,
80 Great Book Golem, 90 Root Emperor, 99 The Voice. Verdieping 100 heeft geen baas (Simulatie-ring, optie C).

**Willekeurige gevechten op de wereldkaart:** `GameData.ENCOUNTER_GROUPS` (groepen zonder `terrains` gelden overal,
dus ook Papiergeest-, Glitchmot- en Kennis-Beest-groepen); tempo in `GameData.ENCOUNTER_RATES`. Binnen kerkers zijn er
geen willekeurige gevechten (zichtbare map-monsters).

Mechanieken per vijand (skills, zwaktes, gif, binding, trekken): `scripts/data/archief2_vijanden.gd`,
`scripts/data/spell_rules.gd`, `GameData.ENEMIES[..]["skills"]`.

### 2.5 Items en uitrusting

Alle items staan in `scripts/data/game_data.gd` (`ITEMS`, `KEY_ITEMS`, `EQUIPMENT`); prijzen en winkels in
`scripts/data/shop_data.gd`; buit per kist in de kamerdata hierboven.

- **Verbruiksspullen:** Potion `drankje`, Magic Water `toverwater`, Healing Herb `kruid`, Herbal Tea `kruidenthee`
  (Elise, Aunt Minna), Singing Flour `zingend_meel` (beloning Garrett), Glowing Ink `gloeiende_inktfles`
  (Inktwurm-kast), Blank Book `leeg_boek` (Marigold, woudkisten, Golem Hall; vang-item van de Codex), Strong Potion,
  Magic Brew, Elixir, Phoenix Feather, Antidote, Stun Bomb (Diepe Grot, Exchange, Koopman, Workshop), Faded Note
  `h5_notitie` (Koopman).
- **Sleutelvoorwerpen:** Bucket of Water `emmer_water`, Pendant `hanger`, Singing Seed `zingend_zaad`, Warp Crystal `warp`.
- **Uitrusting die WM1 echt uitdeelt:** Short Sword, Apprentice Cloak, Padded Jerkin `wambuis` (proloog), Spark Sword
  (puzzelkist Archief 1), Leather Hood, Cover Shield, Iron Helm (kisten), Oak Staff en Travel Robe (Vesper en Seren
  bij het aansluiten), Mountain Vein Staff en Veinstone (berggrot), Dagger, Wooden Shield, Leather Armor, Chain Mail, Silver
  Bookmark, Green Ring (Willowdale), plus de Diepe Grot-set `d100_*` (4 niveaus x 6 soorten), Simulation Ring en de 36
  blauwe-kiststukken `bg_g*` (`grade_gear.gd`).
- **Winkels:** Willowdale Weapons, Armor, Accessories, Magic, Herbs (`wilgendal_*`); hub Exchange (`handelskamer`).
  Verkoopprijs is de helft; grade 4 ligt nooit in de winkel.
- **Workshop-recepten** (hub, act 4): Strong Potion, Magic Brew, Elixir (`werkplaats_recepten.gd`).
- Uitrustingsvakken: Weapon, Shield, Helm, Armor, Benen, Laarzen, Accessory (`EQUIP_SLOTS`). Let op: "Benen" en
  "Laarzen" zijn nog Nederlands (H7).

### 2.6 Skills

- **Helden en startspreuken** (`GameData.HEROES`, `scripts/data/archief2.gd`): Dax (Warrior, geen magie, Core Power uit
  de Golemkern), Vesper (Mage, Spark `vuur` en Chain Lightning `bliksem`), Seren (Priest, Minor Heal `genees`, Icicle
  `rijp`), Kael Voss (Psytech, Arc `vonk`), Orion (Archer, geen magie). Wie wat mag leren: `spell_rules.gd` (`CAP`).
- **Spreuken:** 81 canonspreuken in `scripts/data/spells.gd` in 5 elementen (vuur, natuur, bliksem, licht, ijs) en 4
  grades. Magic Shop in Willowdale verkoopt grade 1 (act 1), 2 (act 2) en 3 (act 3+); grade 4 alleen als buit in de
  Diepe Grot (rollen vanaf verdieping 80). Het veldmenu "Magic" en `scripts/ui/magic_screen.gd` tonen ze.
- **Kern en wereldvaardigheden:** Golem Core `golemkern` geeft Core Power `kernslag` (gevecht) en `zware_blokken` en
  `kernvuur` (veld); Living Core `levenskern` geeft alleen zijn zin (`scripts/data/kern_data.gd`,
  `scripts/kern/`).
- **Codex:** 18 vangbare soorten, 29 bondgenootvaardigheden, fusie (`scripts/data/codex_data.gd`,
  `scripts/battle/codex_battle.gd`, `scripts/battle/codex_ally.gd`). Max. 12 pagina's, 1 Codex-monster mee in het gevecht.
- **Vijandvaardigheden:** `bind`, `poison`, `charge`, `drain`, `pull` (Archief 2) en per vijand een eigen skill-tabel
  (`GameData.ENEMIES`).
- **Gevechtsstijlen:** Classic (beurtelings, `scripts/battle/`) en Action (realtime SoM, `scripts/som/`); bazen blijven
  beurtelings. Schakelaar in MENU > Settings > Battle Style.

### 2.7 Cutscenes en scripted scènes

| Scène | Bron | Herhaalbaar |
|---|---|---|
| Proloog: ochtend, toonkeuze, mantel, taken, zwaardles (`opa`, `intro_keuze`, `opa_mantel`, `mantel_aan`, `les`, `na_les`) | `scripts/data/story_data.gd` | nee |
| Proloog: avond, de flits, opgesloten, Opa achterna (`catastrofe`, `opgesloten_timer`, `huis_uit`, `schreeuw`, `keuze`, `blijven`, `achterna`) | `story_data.gd` | nee |
| "Into the Wide World" (video bij de eerste keer op de wereldkaart) | `scripts/worldmap_cutscene.gd`, `assets/video/worldmap_intro.ogv` | ja, Scenes |
| Eerste Archief binnen (`archief_ingang`, `archief_binnen`) | `story_data.gd` | nee |
| Inktwurm-tutorial en Codex-vang-tutorial (4 pagina's elk) | `story_data.gd` (`TUT_INKT_PAGES`, `TUT_CODEX_PAGES`, `FREE_EVENTS`) | nee |
| Golem Hall-uitgang op slot tot de Inktwurm in de Codex staat (`golemhal_uitgang`) | `story_data.gd` | n.v.t. |
| Mapleton: ontmoeting Vesper, Marigold geeft 3 Blank Books (`noor_ontmoeting`, `marit_boeken`) | `story_data.gd` | nee |
| Dark Wood: cocon, bevrijding, Vesper sluit aan (`cocon`, `noor_bevrijd`, `noor_woud`) | `story_data.gd`, `woud_rooms.gd` | nee |
| Bouwplaats-poort (`bouwplaats_*`), poorten naar kas en Mapleton (`naar_leven`, `naar_esdoorn`, `woud_ingang`) | `story_data.gd` | n.v.t. |
| Zingend Graan: Garrett, zaad, molen zingt (`gerrit*`, `zingend_zaad*`, `MOLEN_ZANG`) | `story_data.gd`, `scripts/village/molen.gd` | nee |
| Archief 2 binnen: de keten (`archief2_keten`) en Seren sluit aan (`LOTTE_AANSLUIT`) | `story_data.gd`, `scripts/data/archief2.gd` | nee |
| Na De Genezer: video, canonscène 1 "The World Warper" | `world_warper/cutscene/genezer_scene.gd`, `assets/video/genezer_warper.ogv`, `canon_scenes.gd` | ja, Scenes |
| Hal: canonscène 2 (De Hanger) en 3 (Sapientia's dreiging) | `world_warper/cutscene/hanger_scene.gd`, `hanger_scene.tscn`, `dreiging.gd`, `canon_scenes.gd` | nee (bewust niet in `scenes_data.gd`) |
| ECHO eerste Diepe Grot-gesprek en Koopman-fases | `scripts/data/echo_grot.gd`, `koopman_data.gd` | nee |

De lijst "Scenes & Music" in het veldmenu bevat bewust maar twee scènes (`scripts/data/scenes_data.gd`: "Into the
Wide World", "The World Warper") en 12 muziektracks (`data/music_tracks.json`).

### 2.8 Systemen en schermen

Titel (`scripts/ui/title_screen.gd`): Continue, Load, New Game, Co-op (LAN), PvP (zie H11). Veldmenu
(`scripts/ui/field_menu.gd`): Equipment, Codex, Items, Magic, Bestiary, Warp, Party, Quest Log, Scenes & Music,
Settings, Load. Verder: opslaan (3 boeken-soorten HP/MP/save, autosave, kamer-checkpoint), game over,
touchbediening (`scripts/touch_controls.gd`, 384x216, RUN-knop), partywissel in de Rustkamer (max. 4 helden + 1
Codex-monster, `scripts/party_limiet.gd`), puzzels (`scripts/puzzle/`), sessielog (`scripts/core/sessie_log.gd`,
standaard uit in release), instellingen (General en Music, `scripts/ui/options_screen.gd`).

### 2.9 Audio en art: wat levert WM1

- **BGM met bestand (13 van 24 manifest-sleutels):** `main_menu`, `wachtershuis`, `wereld`, `dorp_wilgendal`,
  `donker_woud`, `vergeten_archieven`, `gevecht_normaal`, `gevecht_miniboss`, `berggrot`, `levend_archief`,
  `baas_archief2`, `diepe_grot` (`bgm_*.ogg` in `assets/audio/bgm/`) en `ww_ambient` (hergebruikt de Diepe Grot-track).
  Het manifest heeft nog 11 sleutels zonder bestand (H9). De code blijft stil werken zonder bestand (`AudioManager`).
- **SFX:** alle 99 manifestregels en de acteur-sfx (`assets/audio/actor_sfx.json`, `assets/audio/sfx/`) zijn
  synthetische placeholders (`tools/placeholders_algemene_sfx.txt`, `tools/placeholders_sfx.txt`).
- **Art:** definitieve art van RPG ART staat in `tools/handwerk.txt` (610 paden; niet aanraken). Open placeholders:
  zie H10.
- **Video:** `assets/video/worldmap_intro.ogv` en `assets/video/genezer_warper.ogv` (samen ca. 30 MB).

### 2.10 Testdekking per onderdeel (CI, `.github/workflows/tests.yml`)

| Onderdeel | Suites (`.github/scripts/run_suite.sh <suite>`) |
|---|---|
| Algemeen, menu's, HUD, save, party | `autotest`, `menutest`, `hudtest`, `locktest`, `savetest`, `partytest`, `held24test`, `rekruuttest` |
| Archief 1, Golem, puzzels, checkpoints | `dungeontest`, `golemtest`, `archieftest`, `puzzletest`, `checkpointtest`, `balansarchief1test` |
| Kern, Codex, tutorial | `kerntest`, `kernkrachttest`, `codextest`, `fusietest`, `tutorialtest` |
| Donker Woud, berggrot, Archief 2 | `woudtest`, `berggrottest`, `archief2test`, `somroomstest` |
| Willowdale, quests, cutscenes, muziek | `wilgendaltest`, `questtest`, `cutscenetest`, `musictest`, `muziektest`, `actorsfxtest` |
| World Warper en ECHO | `warperkamertest`, `hangertest`, `echotest`, `catalogustest`, `updatetest`, job `warper-runner` |
| Diepe Grot | `dungeon100gentest`, `dungeon100schaaltest`, `dungeon100regelstest`, `dungeon100integratietest`, `dungeon100blauwtest`, `grotlayouttest`, `koopmantest` |
| Balans | `battlesimtest` |
| Niet WM1 maar wel in CI | `pvptest`, `nettest`, `netsynctest`, `coope2etest`, `coophosttest`, `sessielogtest`, `sessielogcoretest`, `spiegeltest` |

`sessiefixtest` staat in `scripts/game_state.gd` maar niet in de CI-matrix; lokaal gedraaid op deze basis (Godot
4.7.2): 30 PASS, 0 FAIL. Toevoegen aan de matrix kan alleen RPG Forge (zie fase 3).

## 3. Half-af: ship of cut

Aanbeveling per punt. **SHIP** = zo meeleveren, geen werk. **CUT** = uit de speelroute houden of uitzetten; dat is
de enige toegestane wijziging (verwijderen of dicht laten, nooit uitbouwen). **BESLIS** = Dennis kiest; de voorkeur van deze inventaris
staat erbij. Eigenaar van de beslissing: Dennis, tenzij anders vermeld.

| # | Wat | Bewijs | Aanbeveling |
|---|---|---|---|
| H1 | Test- en demokamers `archief_test` ("Forgotten Archives - Test Room") en `kern_demo` ("Core Room (demo heavy cabinet)") | `scripts/data/puzzle_rooms.gd` ("niet in de verhaalroute, alleen voor --kerntest"); `scripts/map.gd` `DEBUG_PUZZLE_ROOM` alleen met `OS.is_debug_build()` (toets F4); `scenes/maps/archief_test.tscn`, `scenes/maps/kern_demo.tscn` | **CUT** uit de route. Bestanden blijven (tests gebruiken ze). In fase 3 controleren dat geen deur ernaartoe leidt in een release-build. |
| H2 | Hub-nissen `codex_nis` (vlag `world_warper_act2`) en `sapientia_schot` (vlag `world_warper_act3`): niemand zet die vlaggen | `world_warper/data/rooms.gd` (`TODO(design)`), `world_warper/maps/codex_nis.tscn`, `world_warper/maps/sapientia_schot.tscn` | **CUT**: blijven dicht, geen inhoud toevoegen. |
| H3 | Hubkamers achter een level-grens: Screening Room (Lv 14), Training Hall (Lv 20), Workshop (Lv 26), Exchange (Lv 32), Core (Lv 37). The Core toont alleen "The story of H-6 ends here." | `world_warper/kamers/kamers.gd` (`ROOMS`, `KERN_ZIN`), `scripts/data/level_scale.gd` | **SHIP** Rest Room, ECHO's Chamber en Screening Room. **BESLIS** voor Training Hall tot en met Core. Voorkeur: meeleveren als endgame achter de Diepe Grot-levels (data en tests bestaan), met The Core als enige twijfel (stub-tekst). Alternatief **CUT**: kamer dicht laten via de bestaande `min_act`-regel. Fase 5 meet of Lv 20+ haalbaar is. |
| H4 | 40 uitrustingsstukken van act 2 tot en met 6 (Kettle Blade tot Heart Ring) zonder bron in WM1 | alleen in `game_data.gd` en `level_scale.gd`; geen winkel, kist of recept verwijst ernaar (gecontroleerd met `rg`) | **SHIP als inerte data**: niets toevoegen, geen bron bedenken. Pas wanneer WM2 loopt krijgen ze een bron. |
| H5 | Magie: 81 spreuken, grade 3 koopbaar vanaf party Lv 20, grade 4 alleen als Diepe Grot-buit; Dax leert geen magie | `scripts/data/spells.gd`, `scripts/data/spell_rules.gd`, `scripts/data/shop_data.gd` | **SHIP**. Balans in fase 5. |
| H6 | Berggrot-monsters ontbreken in Bestiary en Codex (staan niet in `ENEMIES`), terwijl ze in de Diepe Grot-pool zitten | `scripts/data/berggrot_data.gd` (`MONSTERS`), `scripts/dungeon/dungeon100_content.gd` (`POOLS`), `scripts/ui/bestiary_screen.gd` | **SHIP** met bekende lacune. Alleen aanpassen als Dennis dit als bug classificeert (dan een bugfix-PR met test). |
| H7 | Nederlandse spelertekst die nog in het spel kan verschijnen: opdrachttitel "Het Zingende Graan" in het veldmenu (`StoryData.QUESTS`); "Een Mosslijm vecht tijdelijk mee." (`Archief2.GEEN_CODEX`); "Welk Codex-monster vecht mee?" (`scripts/dungeon/archief2_room.gd`); keuzemenu "ECHO: Waarheen?" met Opslaan, Wilgendal, Archief-ingang, Andere eilanden (`scripts/dungeon/archief2_warp.gd`); "Niemand in het gezelschap." (`world_warper/services/party_select.gd`); "Dax leert geen magie." en "Deze held" (`scripts/data/spell_rules.gd`); bord "Een groei-plaat. Stap erop." (`scripts/data/archief2_rooms.gd`); vakken "Benen" en "Laarzen" (`GameData.EQUIP_SLOT_NAMES`) | steekproef met `rg` op `scripts/` en `world_warper/`; niet uitputtend | **SHIP na tekstfix.** Dit is een bugfix (AGENTS.md regel 3: alle spelertekst Engels) en valt onder de freeze-uitzondering "Engelse tekst". Volledige sweep in fase 6. |
| H8 | Verhaaltekst met `TODO(verhaal)`: 13 events (`StoryData.TODO_STORY`: o.a. `noor_ontmoeting`, `noor_bevrijd`, `marit`, `bram`, `jens`, `tobias`, `ilse`, `herbergier`, `naar_esdoorn`, `woud_ingang`) en ECHO's zinnen (`world_warper/guide/dialoog.gd`, `TODO(design)`) | `scripts/data/story_data.gd`, `world_warper/guide/dialoog.gd`, `data/quests.json` (`todo`-velden) | **SHIP** de huidige tekst. Een door Dennis goedgekeurde tekstvervanging is toegestaan tot de release candidate (sectie 4, klasse "tekst door Dennis"). |
| H9 | 11 BGM-sleutels zonder bestand: voor WM1 relevant zijn `rustplek`, `overwinning`, `game_over`, `sapientia_thema`. De rest (`industriestad`, `zwevende_tempel`, `ondergronds_lab`, `sterrenobservatorium`, `eindbaas_fase1`, `eindbaas_fase2`, `aftiteling`) is WM2/WM3 | `assets/audio/audio_manifest.json`, `assets/audio/bgm/` | **SHIP stil** (de code zwijgt zonder bestand). Geen nieuwe muziek in WM1; Dennis kan bestaande tracks laten hergebruiken via een manifest-bugfix. |
| H10 | Open art-placeholders in WM1: realtime Action-gevecht (slagboog, meters, cijfers, ringmenu in code getekend, magenta), Diepe Grot-rustpunt, Blauwe Kist en uitgang-warpers (tint op bestaande art) | `tools/placeholders_v17.txt`, `scripts/som/`, `scripts/dungeon/dungeon100_rustpunt.gd`, `scripts/dungeon/dungeon_chest.gd`, `docs/BACKLOG_WM1.md` (A12) | **SHIP** zolang RPG ART niet levert. Elke echte vervanging gebruikt dezelfde bestandsnaam en maat. Geen nieuwe placeholders. |
| H11 | PvP en Co-op (LAN) staan als knoppen op het titelscherm; ze zijn geen WM1-content (relay en online lobby open) | `scripts/ui/title_screen.gd`, `pvp/`, `scripts/net/`, `scripts/coop/`; CI: `pvptest`, `nettest`, `netsynctest`, `coope2etest`, `coophosttest`; export vraagt `internet` en wifi-rechten in `export_presets.cfg` | **BESLIS.** Voorkeur: **SHIP bevroren** als "experimenteel" in de changelog; knoppen verbergen is de **CUT**-optie (een kleine wijziging in `title_screen.gd`). Eén keuze voor de hele release, geen halve. |
| H12 | Generieke winkelnamen "Accessories" en "Magic Shop" als winkelier-naam; Jack Hammond staat voor twee balies (bewust: één smid) | `scripts/data/wilgendal_dorp.gd` (`keeper_naam`) | **SHIP** (tekstkeuze van Dennis; geen werk). |
| H13 | De Koopman toont vanaf bezoek 4 (fragmenten, noemt Archive 4) en bezoek 8 (waarheid, geeft H-5's Token) al lore die bij Archief 4 en 5 hoort | `scripts/data/koopman_data.gd` (`FRAGMENT_VANAF`, `WAARHEID_VANAF`); CANON 12 | **BESLIS.** Voorkeur: **SHIP** zoals CANON 12 het beschrijft. Alternatief is de drempel verhogen (data-wijziging, valt onder CUT als Dennis het wil). |
| H14 | Archief 2 heeft twee ingangsketens (route A en B) met eigen platenkamers; vanuit `archief_2_v2_gang` wijst de terugweg altijd naar `leven_v1_plaat`, ook als je via de berggrot kwam | `scripts/data/archief2_rooms.gd` (`archief_2_v2_gang`, uitgang `E`), `scripts/data/puzzle_rooms.gd` | **SHIP** beide routes. Fase 3 test de terugweg en dwarsdoorsneden. Een fout daar is een bugfix. |
| H15 | World Warper "Locked" voor World 2 en 3, `Locked`-melding "The other islands are silent." in Archief 2 | `world_warper/warp/destinations.gd`, `scripts/data/archief2.gd` (`EILANDEN_DICHT`) | **SHIP** als teaser; geen WM2-haak toevoegen. |
| H16 | Balans: Strangler en Mender zijn triviaal (100% winst, 8% en 22% HP-verlies); Diepe Grot-bazen op verdieping 20, 30, 80 en 90 zijn HARD en gewone verdiepingen 1, 5 en 15 zijn TRIVIAL; CANON legt boss-stats vast | `docs/BATTLE_BALANCE_REPORT.md` (power scaling v2, PR #208) | **SHIP**; afstellen alleen in fase 5 met de daar beschreven regels. Boss-stats uit CANON-blokken niet aanraken zonder Dennis. |
| H17 | Spoilers en dwarsdoorsnede: route A (kas) hangt alleen aan de Golem, niet aan Vesper | `StoryData.MAP_ENTER`, `naar_leven`; `docs/BATTLE_BALANCE_REPORT.md` (rij "STORY Seren/Lotte, Dax alone") | **SHIP**; fase 3 test dat Archief 2 zonder Vesper af te maken is (of netjes dicht blijft). |
| H18 | Buiten WM1 maar in de repo: De Spiegel (`scenes/story/spiegel_kamer.tscn`, `scripts/spiegel/`, `scripts/data/spiegel_data.gd`, alleen via `--spiegel`), SoM-sandbox `scenes/coop/action_sandbox.tscn`, `wacht/wm2/` | `scripts/game_state.gd` (`SpiegelData.DEBUG_ARG`), `wacht/.gdignore` | **CUT** uit de release: niet bereikbaar zonder commandoregel-argument, niet uitbreiden. `wacht/` zit niet in de export. |

## 4. Freeze-regels

De freeze gaat in zodra deze PR op `main` staat en blijft tot de release (fase 8). Alles hieronder geldt voor elke
bijdrager: Dennis, RPG Forge, RPG ART, RPG CODE en Cursor-agents.

### 4.1 Verboden

- Nieuwe features, nieuwe systemen, nieuwe schermen of nieuwe spelmodi.
- Nieuwe content: kaarten of kamers, NPC's, opdrachten, vijanden of bazen, items of uitrusting, spreuken of
  vaardigheden, cutscenes, muziek of geluiden, Codex-soorten, recepten, winkelvoorraad.
- Alles dat WM2 of WM3 raakt of er een haak voor legt. `wacht/wm2/` blijft dicht.
- Refactors zonder reproduceerbare bug. Geen hernoemen van ids, vlaggen of bestanden (saves en tests hangen eraan).
- Wijzigen van het savebestand-formaat, behalve als bugfix met migratie en een test in `savetest`.
- Wijzigen van CANON-blokken, `docs/lore/CANON.md` of CANON-boss-stats zonder Dennis.
- Aanraken van `tools/handwerk.txt` of de bestanden erin, behalve door RPG ART met akkoord van Dennis (zie fase 2). Cursor-agents raken die bestanden nooit aan.
- Versienummers bumpen, signing-velden in `export_presets.cfg`, workflows in `.github/workflows/` (alleen RPG Forge).
- Secrets, keystores, APK/AAB of `.uid`-bestanden committen. Force-push.

### 4.2 Toegestaan (de enige vier klassen)

1. **Bugfix.** Er is een reproduceerbaar probleem (crash, softlock, verkeerde logica, test die faalt, tekst die
   niet Engels is). De PR beschrijft de repro, bevat een test of een uitgebreide bestaande suite, en verandert
   zo weinig mogelijk.
2. **Polish.** Zichtbare of voelbare verbetering zonder nieuw gedrag: uitlijning, tikdoelen, tekstfouten,
   performance zonder gedragsverandering, geluidsvolume. Geen nieuwe regels, geen nieuwe assets.
3. **Cut.** Iets half-afs uitzetten of dicht laten (sectie 3). Alleen verwijderen of uitschakelen.
4. **Goedgekeurde vervanging.** (a) Tekst door Dennis, op bestaande tekstplekken. (b) Art door RPG ART op dezelfde
   bestandsnaam en maat, met akkoord van Dennis, en een regel in `tools/handwerk.txt` zoals bij batch 1 (24 okt
   2026). (c) Data-afstelling van getallen in fase 5 (balans), binnen bestaande tabellen.

Grensgevallen: een nieuwe regel tekst op een plek waar nu niets staat is nieuwe content (verboden). Een nieuw
bestand dat een bestaand bestand vervangt is toegestaan als het dezelfde naam en maat heeft. Een nieuwe testsuite
mag alleen bij een bugfix of een gat in de CI en mag geen bestaande suite wijzigen of verzwakken.

### 4.3 Proces

- Eén taak per branch `cursor/<korte-taak>`, kleine PR naar `main`, PR-template volledig ingevuld. Niet zelf mergen.
- Label elke PR `wm1-bugfix`, `wm1-polish`, `wm1-cut` of `wm1-vervanging`. Zonder label geen review.
- Alle suites groen in CI voor elke merge. Een bugfix-PR noemt de suite die de fout nu vangt.
- Na release candidate 1 (fase 8) alleen nog blokkerende bugs (crash, softlock, dataverlies, signing).
- Een idee voor nieuwe content gaat naar `docs/BACKLOG_WM1.md`-achtige lijst voor na de release, niet in een PR.

### 4.4 Uitzonderingen en lock-wijziging

Een uitzondering op de lock is alleen geldig als Dennis dat schriftelijk zegt in de PR of het issue. Zo'n PR
past ook dit document aan (sectie 2 en de lock-cijfers), zodat de inventaris klopt met `main`. Een PR die iets
toevoegt dat hier niet staat en dit document niet aanpast, wordt geweigerd.

### 4.5 Hoe een reviewer de lock controleert

- Diff raakt een tabel uit de lock-cijfers? Tel opnieuw (`GameData.ENEMIES`, `ITEMS`, `EQUIPMENT`, `SPELLS`,
  `data/quests.json`, `scenes/maps/`). Elke toename zonder lock-wijziging is een afwijzing.
- `git diff --stat` toont nieuwe `.tscn`, `.ogg`, `.wav`, `.png` of `.ogv`? Alleen toegestaan als vervanging (4.2).
- Nieuwe `TODO(design)` of `TODO(verhaal)` in een PR? Niet toegestaan; los het op of laat het weg.
- Zit er `.uid`, `.apk`, `.aab`, `.keystore`, `.jks` of `.env` in de diff? Afwijzen (`.gitignore` blokkeert ze al).

## 5. Bijhouden

Dit document is de enige bron voor "wat zit er in WM1". Wijzigingen lopen via een PR met label `wm1-lock` en
akkoord van Dennis; RPG Forge mergt. Bij de release candidate wordt sectie 3 de "Known issues" van de changelog.
