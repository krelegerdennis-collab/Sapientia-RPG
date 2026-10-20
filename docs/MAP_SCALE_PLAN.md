# MAP_SCALE_PLAN — WM1-kaarten 1.4x (besluit Dennis, 20 okt 2026)

Doel: alle WM1-kaarten (eerste wereld) ~1.4x zo groot, loopbare paden 2-3 tegels breed, passend bij de
24x32-heldsheets (slanke definitieve sheets van RPG ART: `assets/sprites/som/kaart/*_wm1_slim.png`).
**Buiten scope:** de wereldkaart (`wereldkaart.tscn`, blijft klein met de oude 16x24-sprite) en alles in
`wacht/wm2/` (niet gelezen). Tegelmaat blijft 16 px; alleen het aantal tegels groeit.

## Wat vanzelf meegaat
- **Camera-grenzen**: `map.gd::_fit_camera()` leest de `used_rect` van de grondlaag → niets met de hand.
- **Encounter-zones**: geen. Alle WM1-kaarten hebben `encounters = false`; gevechten komen van zichtbare
  map-monsters (`map_monster.gd`), waarvan de posities in de kamerdata staan (moeten wel mee).
- **Cutscenes**: `story_data.gd` gebruikt relatieve `walk`-stappen (`["walk", wie, richting, tiles]`) plus
  enkele vaste tegels (bv. bed in `huis_wilgendal` (8,4) in autotest). Relatieve stappen opnieuw nalopen per kaart.
- **Warps tussen kaarten** gaan via spawn-*namen* (`target_spawn`), niet via coördinaten → alleen de
  spawnpunten zelf verplaatsen.

## Methode (bewezen op Wilgendal, zie PR)
Geen vrije herschaling (dan worden paden 3→4-5 breed en schuiven deuren van het pad af), maar een
**rij/kolom-verdubbeling**: ~40% van de rijen en kolommen wordt dubbel, *nooit* een padrij/-kolom, beek,
brug, hekrij of deurrij. Zo blijven paden 2-3 breed, groeien gras, plein en tussenruimte. Puntcoördinaten:
`x' = X(x)` (eerste kopie), deuren/props met de onderrand (`y' = Yl(y)`, laatste kopie) zodat de deur tegen
het pad blijft; NPC-lussen = oude offsets vanaf de nieuwe start. Grote sprites (molen, huizen) houden hun
maat en worden opnieuw verankerd op hun voet/deur.

## Inventaris (gemeten in Godot 4.3: used_rect van de grondlaag + nodes na `_ready`)
Kolom "moet mee" = nodes/data met een vaste tegel- of pixelpositie.

| kaart | bron van de layout | nu (tegels) | 1.4x | moet mee |
|---|---|---|---|---|
| `archief_2_v1_entree.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 boeken, 1 exit-warper, 1 bordjes, 2 exits, 2 map-monsters, 3 spawns |
| `archief_2_v1_plaat.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 bordjes, 1 groeiplaten, 2 exits, 3 spawns |
| `archief_2_v2_gang.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 2 exits, 2 map-monsters, 3 spawns |
| `archief_2_v2_lotte.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 2 exits, 1 map-monsters, 3 spawns |
| `archief_2_v3_ketting.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 bordjes, 3 groeiplaten, 2 exits, 1 map-monsters, 3 spawns |
| `archief_2_v3_licht.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 bordjes, 1 groeiplaten, 2 exits, 3 spawns |
| `archief_2_v3_tegen.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 bordjes, 1 groeiplaten, 2 exits, 3 spawns |
| `archief_2_v3_wurger.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 exit-warper, 1 bordjes, 2 exits, 1 map-monsters, 3 spawns |
| `archief_2_v4_genezer.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 exit-warper, 2 exits, 1 map-monsters, 3 spawns |
| `archief_2_v4_hal.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 bordjes, 2 exits, 1 map-monsters, 3 spawns |
| `archief_2_warper.tscn` | archief2_rooms.gd (archief2_room.gd) | 20x12 | **28x17 (gedaan)** | 1 boeken, 1 bordjes, 1 exits, 3 spawns |
| `archief_bibliotheek.tscn` | dungeon_rooms.gd | 12x9 | 17x13 | 1 boeken, 7 meubels, 3 bordjes, 2 exits, 2 spawns |
| `archief_golemhal.tscn` | dungeon_rooms.gd | 20x12 | 28x17 | 1 exit-warper, 1 exits, 1 map-monsters, 1 spawns |
| `archief_ingang.tscn` | dungeon_rooms.gd | 20x12 | 28x17 | 1 boeken, 1 exit-warper, 2 exits, 3 map-monsters, 2 spawns |
| `archief_puzzel.tscn` | puzzle_rooms.gd | 18x19 | 25x27 | 2 exits, 2 spawns |
| `archief_test.tscn` | puzzle_rooms.gd | 14x11 | 20x15 | 2 exits, 1 spawns |
| `archief_v1_gang.tscn` | dungeon_rooms.gd | 32x12 | 45x17 | 1 kisten, 2 exits, 6 map-monsters, 2 spawns |
| `archief_v2_kastenzaal.tscn` | dungeon_rooms.gd | 24x13 | 34x18 | 2 exits, 3 map-monsters, 2 spawns |
| `archief_v2_leeszaal.tscn` | dungeon_rooms.gd | 20x24 | 28x34 | 1 kisten, 2 exits, 4 map-monsters, 2 spawns |
| `archief_v2_trapzaal.tscn` | dungeon_rooms.gd | 20x12 | 28x17 | 1 boeken, 1 kisten, 2 exits, 2 map-monsters, 2 spawns |
| `archief_v3_gang.tscn` | dungeon_rooms.gd | 20x12 | 28x17 | 2 exits, 3 map-monsters, 2 spawns |
| `archief_v3_zuilenhal.tscn` | dungeon_rooms.gd | 32x13 | 45x18 | 1 boeken, 1 kisten, 1 exit-warper, 2 exits, 5 map-monsters, 2 spawns |
| `archief_v4_voorhal.tscn` | dungeon_rooms.gd | 20x12 | 28x17 | 1 kisten, 2 exits, 3 map-monsters, 2 spawns |
| `archief_v4_wachtersgang.tscn` | dungeon_rooms.gd | 32x12 | 45x17 | 1 boeken, 2 exits, 5 map-monsters, 2 spawns |
| `berggrot_bouwplaats.tscn` | scene | 24x13 | 34x18 | 2 exits, 2 spawns, 4 NPC, 5 story-obj |
| `berggrot_geheim.tscn` | berggrot_data.gd + puzzle_rooms.gd | 17x14 | 24x20 | 2 exits, 2 spawns |
| `berggrot_grendel.tscn` | berggrot_data.gd + puzzle_rooms.gd | 15x11 | 21x15 | 2 exits, 2 spawns |
| `berggrot_mond.tscn` | berggrot_data.gd | 20x12 | 28x17 | 1 boeken, 1 exit-warper, 1 bordjes, 2 exits, 2 map-monsters, 2 spawns |
| `berggrot_nerf.tscn` | berggrot_data.gd | 20x12 | 28x17 | 1 boeken, 1 exit-warper, 1 bordjes, 2 exits, 2 map-monsters, 2 spawns |
| `berggrot_uitmond.tscn` | berggrot_data.gd | 20x12 | 28x17 | 1 boeken, 1 exit-warper, 1 bordjes, 2 exits, 1 map-monsters, 2 spawns |
| `dorp_wilgendal.tscn` | wilgendal_dorp.gd (data) | 64x40 | **90x56 (gedaan)** | 8 deuren, 1 exits, 9 spawns, 6 NPC |
| `dungeon100.tscn` | dungeon100_generator.gd (procedureel) | 25x25 | 35x35 | 1 warper, 3 kisten, 2 exits, 10 map-monsters, 3 spawns |
| `esdoorn.tscn` | scene | 34x24 | **48x34 (gedaan)** | 3 deuren, 1 exits, 4 spawns, 5 NPC, 1 bordjes, 2 story-obj |
| `esdoorn_herberg.tscn` | scene | 12x9 | 17x13 | 1 boeken, 1 exits, 1 spawns, 1 NPC |
| `esdoorn_huis_noor.tscn` | scene | 10x8 | 14x11 | 1 exits, 1 spawns, 1 NPC |
| `huis_wilgendal.tscn` | scene | 12x9 | 17x13 | 1 boeken, 1 exits, 3 spawns, 1 NPC, 1 story-obj |
| `kern_demo.tscn` | puzzle_rooms.gd | 9x7 | 13x10 | 2 exits, 1 spawns |
| `leven_ingang.tscn` | archief2_rooms.gd | 16x11 | **22x15 (gedaan)** | 1 boeken, 1 bordjes, 2 exits, 2 map-monsters, 2 spawns |
| `leven_v1_plaat.tscn` | puzzle_rooms.gd | 15x11 | 21x15 | 2 exits, 2 spawns |
| `leven_v3_combi.tscn` | puzzle_rooms.gd | 11x8 | 15x11 | 2 exits, 1 spawns |
| `wilgendal.tscn` | scene (TileMap + nodes in px) | 32x22 | 45x31 | 2 boeken, 1 deuren, 1 exits, 3 spawns, 1 NPC, 9 story-obj |
| `wilgendal_binnen.tscn` | wilgendal_dorp.gd KAMERS (pand_binnen.gd) | 9x8 | 13x11 | 1 exits, 1 spawns, 1 NPC |
| `woud_mistpoel.tscn` | woud_rooms.gd | 20x16 | **28x22 (gedaan)** | 1 kisten, 1 exit-warper, 1 bordjes, 2 exits, 4 map-monsters, 2 spawns |
| `woud_open_plek.tscn` | woud_rooms.gd | 20x12 | **28x17 (gedaan)** | 1 exit-warper, 1 exits, 1 map-monsters, 1 spawns, 2 NPC, 2 story-obj |
| `woud_pad.tscn` | woud_rooms.gd | 32x12 | **45x17 (gedaan)** | 2 kisten, 2 exits, 5 map-monsters, 2 spawns |
| `woud_rand.tscn` | woud_rooms.gd | 20x12 | **28x17 (gedaan)** | 1 boeken, 1 kisten, 1 exit-warper, 2 exits, 3 map-monsters, 2 spawns |
| `woud_sporenkring.tscn` | woud_rooms.gd | 20x12 | **28x17 (gedaan)** | 1 boeken, 1 kisten, 1 bordjes, 2 exits, 3 map-monsters, 2 spawns |
Totaal: 46 WM1-kaarten (wereldkaart uitgezonderd). Groepen en aanpak:

1. **Dorp Wilgendal** (`dorp_wilgendal`, data in `wilgendal_dorp.gd`): **klaar in deze PR** — zie onder.
2. **Hand-gebouwde scènes** (`wilgendal.tscn` Wachtershuis-erf 32x22, `huis_wilgendal` 12x9, `esdoorn` 34x24,
   `esdoorn_herberg` 12x9, `esdoorn_huis_noor` 10x8, `berggrot_bouwplaats` 24x13): TileMap-data zit in de .tscn,
   NPC/deur/story-object/spawn/exit-posities in px. Aanpak: een klein Godot-tool-script dat de tegels met
   dezelfde rij/kolom-verdubbeling herschrijft en alle Node2D-posities omrekent. Let op: autotest en menutest
   hebben vaste tegels in `wilgendal.tscn`/`huis_wilgendal.tscn` (respawn, bed (8,4), opslagboek); `story_data.gd`
   proloog-cutscene loopt relatief.
3. **Dungeonkamers uit data** (`dungeon_room.gd`: `dungeon_rooms.gd`, `woud_rooms.gd`, `berggrot_data.gd`,
   `archief2_rooms.gd`; meestal 20x12, gangen 32x12): ASCII-layout + tekens voor exits/spawns/monsters/kisten/
   boeken/bordjes. Eén schaalfunctie op de layoutstrings in een tool-script; aparte coördinatenlijsten
   (monsterpaden, `guard`, `exit_warper`-plek, `archief_warpers.gd`/`woud_warpers.gd`/`berggrot_warpers.gd`)
   mee. Tests met vaste tegels: `dungeon_tests`, `woud_tests`, `berggrot_tests`, `archief2_tests`, `golem_tests`.
4. **Puzzelkamers** (`puzzle_room.gd`: `archief_puzzel`, `archief_test`, `kern_demo`, `leven_v1_plaat`,
   `leven_v3_combi`, `berggrot_geheim`, `berggrot_grendel`): **niet** het puzzelrooster schalen (blokken,
   platen en oplossingen hangen aan exacte tegels; `puzzletest`/`kerntest` controleren oplossingen). Voorstel:
   puzzelrooster gelijk laten, alleen de rand/aanloop 1.4x (gangen naar de puzzel breder, marge rond het
   rooster). Vraag aan Dennis of dat volstaat.
5. **Dungeon100** (25x25 per verdieping, procedureel): schaal via de generator (kamergrootte/gangbreedte in
   `dungeon100_generator.gd`), niet per kaart; `dungeon100*`-suites (o.a. `dungeon100schaaltest`) bewaken dit.
6. **Interieurs** (`wilgendal_binnen` 9x8 uit `KAMERS`, herberg, huizen): klein houden of hooguit +2 kolommen;
   het interieur vult nu al het scherm (384x216 = 24x13.5 tegels). Voorstel: interieurs niet schalen.

Volgorde-voorstel: (1) Wilgendal ✓ → (2) Wachtershuis-erf + Esdoorn (hand-scènes, één tool) →
(3) Donker Woud + Berggrot (dungeon-data, één tool) → (4) Archief 1/2 → (5) puzzels (alleen rand) →
(6) Dungeon100-generator.

## Atlas / mobiele texturelimieten
- RPG ART v8 (`maps_test`): `v8_town_ground_tileset.png` 256x624 (613 unieke tegels), cave 256x528 (526),
  dungeon 256x272 (257). Dit zijn **gebakken** sets per testkaart (unieke tegels van één render), geen
  autotile-sets met namen.
- Voor Wilgendal 90x56 is de v8-grond met RPG ART's eigen generator gebakken
  (`tools/som/wilgendal_v8_grond.py`): **1297 unieke tegels → atlas 1024x336** (64 tegels breed), ruim onder
  2048x2048 (max 16 384 tegels). Bestaande `terrain.png` 256x176, `hekken.png` 256x32. VRAM ≈ 1.4 MB (RGBA8).
- Schatting andere kaarten: unieke tegels groeien ongeveer met het oppervlak (Wilgendal: 5040 cellen → 1297); alle
  andere WM1-kaarten zijn kleiner, dus naar verwachting ruim binnen 1024x1024. Het script weigert (assert) een atlas > 2048 in een van beide richtingen.
- Advies RPG ART: op termijn een benoemde v8-autotile-set (blob47 pad/water/plein + N grasvarianten), dan
  hoeft er niet per kaart gebakken te worden en deelt WM1 één atlas.

## Wilgendal: wat er verschoven is (64x40 → 90x56)
Verdubbelde rijen: 1,2,3,4,5,7,12,14,23,24,26,27,33,35,36,37. Verdubbelde kolommen:
1,2,4,9,12,13,22-25,28,30,32,38,40,41,43,45,53-55,58-62.
- Winkelrij-deuren (y 8→14): pantser 26, wapen 37, accessoire 58, magie 67, tante Minna 78.
- Huizen zuid (deur y 30→42): dicht_west x26, echtpaar x78; burgemeester deur (49,25)→(67,35).
- Molen: oorsprong (1,1)→(1,9), voet blijft direct onder de beek (rij 25); molendeuren nu relatief aan de oorsprong.
- Beek rij 17→25, brug (34,16)→(47,24). Plein (26,11,19,5)→(36,17,26,7).
- Spawn zuid (35,37)→(48,52), uitgang (34,39)→(47,55), Garrett (10,22)→(14,30).
- 5 sfeer-NPC's + lussen, 27 props (lantaarns, kramen, banken, bloembakken, oude hekprops) omgerekend.
- Poorten/hekken/paden komen uit `GROND` en schalen dus vanzelf mee; padbreedtes bleven 2 en 3.

## Esdoorn (Mapleton): wat er verschoven is (34x24 → 48x34)
Tool: `tools/som/esdoorn_1p4.py` (eenmalig, op de .tscn). Verdubbelde rijen: 0,1,2,11,15,17-21. Verdubbelde
kolommen: 0-4,10,12,13,19,20,22,23,31,32. Nooit: huizen (5x5), deur-/padrijen 8-10, hekrij 16, vijver, zuidpad
kolom 15-17, uitgang (rij 22-23). De twee paden die 1 breed waren zijn nu 2 breed (hoofdweg rij 13-14,
zuidpad kolom 24-25); de uitgang blijft 3 breed. Padranden (dorp.png 10+masker) opnieuw gekozen.
- Deuren: Vesper (7,8)→(12,11), herberg (16,7)→(24,10), dicht (26,8)→(38,11); spawns 1 eronder.
- Spawn/uitgang zuid (16,21)/(15,23)→(24,30)/(23,33); put (16,12)→(24,16).
- NPC's: Marit (19,14)→(27,18), Bram (6,12)→(11,16), Jens (24,18)→(36,24), Tobias (26,14)→(38,18),
  Vesper (16,15)→(24,19), wortelgreep 1 onder Vesper (24,20); bord (5,11)→(10,15).
- Cutscene `noor_ontmoeting`: speler start (24,30) en loopt 8 omhoog (was 3); Marit-stappen ongewijzigd.
- v8-grond: `tools/som/esdoorn_v8_grond.py` → `assets/tilesets/som/esdoorn/grond_v8.*` (567 unieke tegels,
  atlas 1024x144), getoond door `scripts/village/v8_grond.gd` (laag GrondV8) op gras/pad/plein; bomen,
  vijver, hek, heg, tonnen en bloembakken blijven de oude dorp.png-tegels. Interieurs niet geschaald.

## Donker Woud (5 kamers): wat er verschoven is
Tool: `tools/som/woud_1p4.py` (eenmalig, op de ASCII-layouts in `scripts/data/woud_rooms.gd`). Nooit verdubbeld:
rand (rij 0-3, onderrij, kolom 0-1 en de laatste 2), boog-/uitgangkolommen (de doorgang boog -> zuiduitgang blijft
in lijn), pilaar-toprijen (`13`), kuilrand `Y`, de wortelheuvel-onderkant (`{~^^~}`/`oO`) en het opslagstuk `@`.
Wel: vloer, wortels `j` (in de breedte), de mistpoel `V` en de bovenste heuvelrij `[====]`. In een kopie worden losse
decortegels vloer. De rij vlak boven de zuiduitgang krijgt zijn kopie erboven, zodat spawn/mist tegen de uitgang blijven.
- woud_rand: 20x12 -> 28x17; rijen [4, 6, 7, 8, 10]; kolommen [2, 4, 5, 7, 12, 14, 15, 17]
- woud_pad: 32x12 -> 45x17; rijen [4, 5, 7, 8, 10]; kolommen [6, 11, 12, 13, 15, 16, 17, 19, 20, 23, 24, 25, 28]
- woud_mistpoel: 20x16 -> 28x22; rijen [5, 8, 10, 11, 13, 14]; kolommen [2, 3, 6, 7, 12, 14, 16, 17]
- woud_sporenkring: 20x12 -> 28x17; rijen [4, 6, 8, 9, 10]; kolommen [2, 5, 6, 7, 13, 14, 15, 17]
- woud_open_plek: 20x12 -> 28x17; rijen [4, 7, 8, 9, 10]; kolommen [2, 3, 5, 6, 13, 14, 16, 17]
- Spawns/kisten/boeken/borden/monsters/NPC's/objecten/bomen/mist/overlay omgerekend (x' = eerste kopie).
- Warpers: begin (8,10)->(12,15), midden Mistpoel (4,6)->(6,7); eind volgt uit de baas (13,4).
- Open plek: baas/Vesper (9,4)->(13,4), cocon (9,3)->(13,3), Woudgeesten (4,9)->(6,14) boven de mistband y=15.
- Cutscene `noor_bevrijd`: speler naar (13,6) (overwinningstegel onder de baas; was (9,6)). Vesper loopt 1 omlaag.
- Uitgangen: zuid `(UU)`/`(EE)` 2 breed, boog `n` 1 breed (deur, niet verbreed).
- Grond: geen v8-bos-generator/-tegels in `art_mapsprites_v4/out` (alleen town/cave/dungeon + Mapleton-props),
  dus de bestaande `woud_tiles.png` (art_woud_v17) blijft. Nodig van RPG ART voor v8: zie PR.

## Wachtershuis-erf (proloog, `wilgendal.tscn`): wat er verschoven is (32x22 → 45x31)
Tool: `tools/som/wachtershuis_1p4.py` (eenmalig, op de .tscn). Verdubbelde rijen: 0,1,10,11,14-18. Verdubbelde
kolommen: 0-6,11,21,22,29-31. Nooit: huis (kolom 14-18, rij 2-6), deurrij 6, keienplein (rij 7-8), tuinpad
(kolom 15), uitgang (rij 21, kolom 14-16), ruines/Archief-ingang (kolom 23-28, rij 2-5), put (kolom 9-10),
vijver (rij 12-13). Het tuinpad was 1 breed en is nu 2 breed (kolom 23-24); de uitgang blijft 3 breed (22-24).
Interieur `huis_wilgendal.tscn` niet geschaald (bed (8,4), opslagboek ongewijzigd).
- Deur (16,6)→(24,8); spawns voor_huis (16,7)→(24,9), start (16,8)→(24,10), zuid_ingang (15,19)→(23,28);
  uitgang NaarWereld (14,21)→(22,30).
- Oude Man (21,8)→(29,10); kist (19,6)→(27,8); put (9,5)→(16,7); Archief-ingang (25,2)→(35,4) (3x2);
  6 ruines + boeken HP (24,4)→(34,6), MP (27,4)→(37,6).
- Tuinwezens (`garden_creatures.gd`): speelplek (312,184)→(440,232), volg-grens y 232→296.
- Proloog-cutscenes (`story_data.gd`) lopen relatief (`walk … 1`) en blijven gelijk; autotest-looproutes en
  vaste tegels (autotest, dungeontest `_outdoor_tests`) omgerekend.
- v8-grond: `tools/som/wachtershuis_v8_grond.py` → `assets/tilesets/som/wachtershuis/grond_v8.*` (471 unieke
  tegels, atlas 1024x128), tileset `dorp_v8.tres` (bomen, rotsen, vijver uit dorp_v8.png).
- Ontbrekende v8-art: huis (huis.png, nog v0.x), put/kist/ruines/Archief-ingang (`assets/sprites/buiten/`), en een
  kleine-vijverset (de v8-wateranden in dorp_v8.png zijn voor de Mapleton-vijver; op een 3x2-vijver lezen ze hoekig).

## Archief 2 / Het Levende Archief (12 kamers): wat er verschoven is
Tool: `tools/som/archief2_1p4.py` (eenmalig, op `scripts/data/archief2_rooms.gd` + `archief2_ground.gd`), zelfde
rij/kolom-verdubbeling als Esdoorn (#133) / Donker Woud. 20x12 -> 28x17 (11 kamers), `leven_ingang` 16x11 -> 22x15.
- Kolommen (20 breed, gedeeld door alle kamers via de constanten `_F/_G/_B/_T/...`): 2,3,4,7,15,17 dubbel, 16 driedubbel.
  Nooit: rand, uitgang `(EE)` 8-11, boog `n`/`A` 9, brugkolommen 8-10 en 12-14, podium van De Genezer (5,6,8-10,12,13).
  Uitgang/spawns (9,10)->(13,15), noord (9,3)->(13,3); bruggen 8-10 -> 12-14, tegen-brug 12-14 -> 16-18.
- Rijen per kamer (zie toolrapport): nooit rij 0-3, de onderrij, een `#`-rij (groei-/ketting-/tegen-/licht-brugrij,
  baaspoort `_B`) en het podium (rij 4-7, Genezer: daar zijn rij 8-10 2-3x). De rij boven de uitgang krijgt zijn kopie erboven.
- Openingen in `#`-rijen blijven even breed: baaspoort 1 (baas staat erin), lange weg links in Tegen-platen 3, bruggen 3.
- Grond: muurvarianten -> gewone muur, losse props/plantenbakken in een kopie -> vloer 0-2 (vaste hash), 2 hoge
  pilaren (70/71) blijven heel. Alleen de layout is herschaald; de v8.1-blokken (80-87 op even 2x2-cellen) kunnen
  er daarna overheen (vloervlakken zijn groot genoeg).
- Blokkades Genezer: 16 -> 24 tegels op rij 5 (Mender 13-14). Begin-warper (8,10)->(12,15).
- leven_ingang: kolommen 2,3,5,11,12,13, rijen 4,6,7,9; ingang (7,9)->(10,13), boog (9,3)->(12,3), bord (12,5)->(16,6).
- **Niet** geschaald: `leven_v1_plaat` en `leven_v3_combi` (puzzelkamers uit `puzzle_rooms.gd`, zie punt 4: rooster
  hangt aan exacte tegels; `puzzletest`/`archieftest` controleren de oplossingen). Wacht op besluit Dennis (alleen rand?).
- Tests: `archief2test` `_schaal_1p4` (maat, grond = layout, brug-/deurrijen niet dubbel, doorgangen niet breder,
  alles bereikbaar vanaf de zuid-spawn met open bruggen); vaste tegels in archief2/archief-tests omgerekend.
- Voor/na: `tools/som/kaart_shots.gd` (hele kaart als PNG).
