# TILESET_SPEC – overworld-art voor Lufia Prototype v8

Voor: de art director. Van: engine/integratie. Versie 0.8 (code 9). Alle maten in pixels.

**Kort:** maak elk bestand **exact even groot**, zet elke tile **op exact dezelfde plek** als
in de sjablonen, en overschrijf het bestand in het project. Kaarten, botsingen, overgangen en
encounters zitten NIET in de plaatjes maar in `assets/tiles/*.tres` en `scenes/maps/*.tscn`;
die blijven gelijk. Je hoeft dus geen code of Godot-instellingen aan te raken.

Sjablonen (huidige placeholder-tiles, 4x vergroot, met nummer, positie en solid-markering) in
deze map: `template_dorp.png`, `template_huis.png`, `template_wereld.png`,
`template_player.png`, `template_npc.png`, `template_sign.png`. Opnieuw maken (na wijzigingen):
`python3 tools/make_tile_templates.py /workspace/art_specs_v8`.

## 0. Algemene regels

- **PNG, RGBA (32-bit), sRGB**, geen kleurprofiel-trucs, geen interlacing. Indexed PNG mag ook,
  zolang doorzichtig = alpha 0.
- **1 art-pixel = 1 game-pixel.** Spel-resolutie 384x216 (3x op de pc, ±5x op een telefoon).
  Geen schaling, geen subpixels, geen anti-aliasing tegen een achtergrond.
- Godot importeert met filter **nearest**, zonder mipmaps en zonder compressie (lossless).
- **Tiles 16x16, figuren 16x24.** Raster zonder marge en zonder tussenruimte (separation 0).
- **Grond-tiles volledig dekkend** (alpha 255 op elke pixel): er ligt niets onder.
  Uitzondering: niets. Ook bomen, heggen, hekken, lantaarns e.d. zijn grond-tiles met de
  grond (gras/kassei) erachter **in dezelfde tile** getekend.
- **Doorzichtig (alpha 0) alleen in:** `huis.png` (rond het dak/de schoorsteen; daaronder ligt
  gras), `player.png`, `npc.png`, `sign.png`. Halfdoorzichtig alleen voor grondschaduw onder
  figuren (huidige waarde: RGBA 16,20,8,110).
- **Naadloos:** varianten die naast elkaar liggen (gras, kassei, zee, bos, berg) moeten op
  alle vier de randen aansluiten. Patronen die zich elke tile herhalen (felle pixels!)
  vallen op een telefoon op als raster: neon (magenta/cyaan) alleen op unieke tiles
  (huis, stad-icoon, trap), niet op gras/zee/kassei.
- Licht van **linksboven**, slagschaduw naar rechtsonder.
- **Solid** = de speler kan er niet op/doorheen. Dat staat vast per tile-positie (zie de
  tabellen); je kunt het niet in het plaatje veranderen. Teken solid dingen dus duidelijk
  als obstakel en begaanbare dingen als vloer.
- Leesbaarheid op een telefoon: speler en NPC moeten loskomen van de grond (donkere
  omlijning of randlicht); begaanbaar vs. geblokkeerd moet in één oogopslag te zien zijn.

## 1. Drop-in paden (overschrijven, zelfde naam)

| Bestand in het project | Maat | Inhoud |
|---|---|---|
| `assets/tiles/dorp.png` | **864x16** | 54 tiles op één rij (dorp Wilgendal) |
| `assets/tiles/huis.png` | **80x80** | het gebouw in Wilgendal, 5x5 tiles |
| `assets/tiles/wereld.png` | **256x144** | wereldkaart, 16 kolommen x 9 rijen (132 gebruikt) |
| `assets/sprites/player.png` | **48x96** | speler (Dennis), 3x4 frames van 16x24 |
| `assets/sprites/npc.png` | **48x96** | Oude Wijze, zelfde indeling |
| `assets/sprites/sign.png` | **16x16** | bordje (staat op een gras-tile) |

(Project-map: `/workspace/lufia_v8/`.) Daarna: Godot-editor openen (importeert vanzelf) of
`godot --headless --path . --import`. Zet je bestand ook in `tools/handwerk.txt`, dan
overschrijft `tools/generate_art.py` het niet meer.

Gevechts-art (al van jou, ter info): `assets/sprites/battle/{dennis,noor,lotte}.png`
2100x210 (10 frames van 210x210, voeten op (105,203)); `assets/sprites/enemies/*.png` losse
PNG's, naar links kijkend, grondschaduw midden-onder met het midden 6 px boven de onderrand,
max. 194 px hoog (hoger wordt verkleind).

## 2. dorp.png – 864x16, één rij van 54 tiles

Tile *i* staat op x = i*16, y = 0. Kolom "terrein" = naam voor encounters (in het dorp
staan gevechten uit). Gebruikt in Wilgendal: 0, 1, 3, 8-10, 33-53 (de rest staat klaar voor
latere maps; maak ze wel, in dezelfde stijl).

| # | x | wat | solid |
|---|---|---|---|
| 0 | 0 | gras (basis) | nee |
| 1 | 16 | gras met bloemetjes/papiersnippers (variant) | nee |
| 2 | 32 | zandpad (basis) | nee |
| 3 | 48 | boom (vult de hele tile; rij bomen = dicht bos, de rand van het dorp) | **ja** |
| 4 | 64 | muur (vol blok) | **ja** |
| 5 | 80 | water (basis) | **ja** |
| 6 | 96 | brug (over water, van boven) | nee |
| 7 | 112 | rots/kei | **ja** |
| 8 | 128 | gras met schaduw van een obstakel **erboven** | nee |
| 9 | 144 | gras met schaduw van een obstakel **links** | nee |
| 10 | 160 | gras met schaduw van boven **en** links | nee |
| 11 | 176 | zandpad met grasrand aan: N | nee |
| 12 | 192 | zandpad met grasrand aan: O | nee |
| 13 | 208 | zandpad met grasrand aan: N, O | nee |
| 14 | 224 | zandpad met grasrand aan: Z | nee |
| 15 | 240 | zandpad met grasrand aan: N, Z | nee |
| 16 | 256 | zandpad met grasrand aan: O, Z | nee |
| 17 | 272 | zandpad met grasrand aan: N, O, Z | nee |
| 18 | 288 | zandpad met grasrand aan: W | nee |
| 19 | 304 | zandpad met grasrand aan: N, W | nee |
| 20 | 320 | zandpad met grasrand aan: O, W | nee |
| 21 | 336 | zandpad met grasrand aan: N, O, W | nee |
| 22 | 352 | zandpad met grasrand aan: Z, W | nee |
| 23 | 368 | zandpad met grasrand aan: N, Z, W | nee |
| 24 | 384 | zandpad met grasrand aan: O, Z, W | nee |
| 25 | 400 | zandpad met grasrand aan: N, O, Z, W | nee |
| 26 | 416 | water met oever boven | **ja** |
| 27 | 432 | water met oever rechts | **ja** |
| 28 | 448 | water met boven + rechts | **ja** |
| 29 | 464 | water met oever LINKS | **ja** |
| 30 | 480 | water met boven + links | **ja** |
| 31 | 496 | water met rechts + links | **ja** |
| 32 | 512 | water met boven + rechts + links | **ja** |
| 33 | 528 | kassei/plavuizen (basis, het dorpsplein) | nee |
| 34 | 544 | kassei/plavuizen met grasrand aan: N | nee |
| 35 | 560 | kassei/plavuizen met grasrand aan: O | nee |
| 36 | 576 | kassei/plavuizen met grasrand aan: N, O | nee |
| 37 | 592 | kassei/plavuizen met grasrand aan: Z | nee |
| 38 | 608 | kassei/plavuizen met grasrand aan: N, Z | nee |
| 39 | 624 | kassei/plavuizen met grasrand aan: O, Z | nee |
| 40 | 640 | kassei/plavuizen met grasrand aan: N, O, Z | nee |
| 41 | 656 | kassei/plavuizen met grasrand aan: W | nee |
| 42 | 672 | kassei/plavuizen met grasrand aan: N, W | nee |
| 43 | 688 | kassei/plavuizen met grasrand aan: O, W | nee |
| 44 | 704 | kassei/plavuizen met grasrand aan: N, O, W | nee |
| 45 | 720 | kassei/plavuizen met grasrand aan: Z, W | nee |
| 46 | 736 | kassei/plavuizen met grasrand aan: N, Z, W | nee |
| 47 | 752 | kassei/plavuizen met grasrand aan: O, Z, W | nee |
| 48 | 768 | kassei/plavuizen met grasrand aan: N, O, Z, W | nee |
| 49 | 784 | heg/struik (rond, op gras) | **ja** |
| 50 | 800 | hek (horizontaal, op gras; nu smeedijzer) | **ja** |
| 51 | 816 | lage muur (van voren gezien, vult de tile) | **ja** |
| 52 | 832 | bloemenperk (op gras) | nee |
| 53 | 848 | object op kassei: nu **lantaarn op sokkel** (was ton), naast de deur | **ja** |

Randen-maskers (11-25 en 34-48): de grasrand ligt aan de genoemde kant(en) van de tile;
N = boven, O = rechts, Z = onder, W = links. Water-oevers (26-32): let op, waarde 4 = LINKS.

## 3. huis.png – 80x80 = 5x5 tiles

Eén gebouw, op de laag "Gebouwen" bovenop gras. **Alle 25 tiles zijn solid** (ook de lege
hoekjes van het dak). Tile (kolom, rij) staat op x = kolom*16, y = rij*16.
- **Deur = tile (2,4)**: x 32-47, y 64-79 (midden van de onderste rij). Daar staat een
  onzichtbaar deur-object ("De deur is op slot."). Teken de deur in die tile.
- Onderste rij (rij 4) = gevel met plint/traptree die op het plein (kassei) staat.
- Dak/schoorsteen mogen doorzichtig zijn (alpha 0) waar het gras erdoor moet komen.
- Links en rechts van het huis (op kassei) staan tile 53 (lantaarn).
Stijl nu: kleine bibliotheek (natuursteen, boogramen met boeken, roosvenster, leien dak).

## 4. wereld.png – 256x144, 16 kolommen x 9 rijen

Tile #n staat op kolom n % 16, rij n // 16 (x = kolom*16, y = rij*16). 132 tiles gebruikt
(#0-131); de laatste 12 vakjes van rij 8 blijven leeg/doorzichtig. Alle tiles dekkend.
Kans op een gevecht per stap: gras 6%, hoog gras 7%, zand 6%, bos 10% (zie `ENCOUNTER_RATES` in
`scripts/data/game_data.gd`).

### 4a. Vaste tiles

| # | (kol,rij) | wat | solid |
|---|---|---|---|
| 0 | (0,0) | gras/vlakte variant A (meest gebruikt) | nee |
| 1 | (1,0) | gras/vlakte variant B (±1 op 5 tiles, verspreid) | nee |
| 113 | (1,7) | stad Wilgendal, **linkerhelft** (stad = 2 tiles breed) | nee |
| 114 | (2,7) | stad Wilgendal, **rechterhelft** | nee |
| 115 | (3,7) | trap naar beneden (kerker-ingang, nu nog een melding) | nee |

Stad (113-114) en trap (115) zijn uitgangen: erop stappen = naar het dorp / melding.

### 4b. Terrein met 16 varianten (masker = welke buren HETZELFDE terrein zijn)

Masker-bits: N=1 (boven), O=2 (rechts), Z=4 (onder), W=8 (links). Tile = basis + masker.
Masker 15 = midden van een vlak (alle buren hetzelfde) – dat is de meest gebruikte.
Waar een buur NIET hetzelfde is, loopt het terrein daar af naar het gras (rand/afronding).

| # | (kol,rij) | terrein | solid | variant |
|---|---|---|---|---|
| 2 | (2,0) | hoog gras / nu: plavuizen-ruïne | nee | los (geen buren van hetzelfde terrein) |
| 3 | (3,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N |
| 4 | (4,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: O |
| 5 | (5,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, O |
| 6 | (6,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: Z |
| 7 | (7,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, Z |
| 8 | (8,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: O, Z |
| 9 | (9,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, O, Z |
| 10 | (10,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: W |
| 11 | (11,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, W |
| 12 | (12,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: O, W |
| 13 | (13,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, O, W |
| 14 | (14,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: Z, W |
| 15 | (15,0) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, Z, W |
| 16 | (0,1) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: O, Z, W |
| 17 | (1,1) | hoog gras / nu: plavuizen-ruïne | nee | buren ook hetzelfde: N, O, Z, W |
| 18 | (2,1) | zand / nu: as en grind | nee | los (geen buren van hetzelfde terrein) |
| 19 | (3,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N |
| 20 | (4,1) | zand / nu: as en grind | nee | buren ook hetzelfde: O |
| 21 | (5,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, O |
| 22 | (6,1) | zand / nu: as en grind | nee | buren ook hetzelfde: Z |
| 23 | (7,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, Z |
| 24 | (8,1) | zand / nu: as en grind | nee | buren ook hetzelfde: O, Z |
| 25 | (9,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, O, Z |
| 26 | (10,1) | zand / nu: as en grind | nee | buren ook hetzelfde: W |
| 27 | (11,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, W |
| 28 | (12,1) | zand / nu: as en grind | nee | buren ook hetzelfde: O, W |
| 29 | (13,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, O, W |
| 30 | (14,1) | zand / nu: as en grind | nee | buren ook hetzelfde: Z, W |
| 31 | (15,1) | zand / nu: as en grind | nee | buren ook hetzelfde: N, Z, W |
| 32 | (0,2) | zand / nu: as en grind | nee | buren ook hetzelfde: O, Z, W |
| 33 | (1,2) | zand / nu: as en grind | nee | buren ook hetzelfde: N, O, Z, W |
| 34 | (2,2) | bos (begaanbaar!) | nee | los (geen buren van hetzelfde terrein) |
| 35 | (3,2) | bos (begaanbaar!) | nee | buren ook bos: N |
| 36 | (4,2) | bos (begaanbaar!) | nee | buren ook bos: O |
| 37 | (5,2) | bos (begaanbaar!) | nee | buren ook bos: N, O |
| 38 | (6,2) | bos (begaanbaar!) | nee | buren ook bos: Z |
| 39 | (7,2) | bos (begaanbaar!) | nee | buren ook bos: N, Z |
| 40 | (8,2) | bos (begaanbaar!) | nee | buren ook bos: O, Z |
| 41 | (9,2) | bos (begaanbaar!) | nee | buren ook bos: N, O, Z |
| 42 | (10,2) | bos (begaanbaar!) | nee | buren ook bos: W |
| 43 | (11,2) | bos (begaanbaar!) | nee | buren ook bos: N, W |
| 44 | (12,2) | bos (begaanbaar!) | nee | buren ook bos: O, W |
| 45 | (13,2) | bos (begaanbaar!) | nee | buren ook bos: N, O, W |
| 46 | (14,2) | bos (begaanbaar!) | nee | buren ook bos: Z, W |
| 47 | (15,2) | bos (begaanbaar!) | nee | buren ook bos: N, Z, W |
| 48 | (0,3) | bos (begaanbaar!) | nee | buren ook bos: O, Z, W |
| 49 | (1,3) | bos (begaanbaar!) | nee | buren ook bos: N, O, Z, W |
| 50 | (2,3) | berg variant A | **ja** | los (geen buren van hetzelfde terrein) |
| 51 | (3,3) | berg variant A | **ja** | buren ook berg: N |
| 52 | (4,3) | berg variant A | **ja** | buren ook berg: O |
| 53 | (5,3) | berg variant A | **ja** | buren ook berg: N, O |
| 54 | (6,3) | berg variant A | **ja** | buren ook berg: Z |
| 55 | (7,3) | berg variant A | **ja** | buren ook berg: N, Z |
| 56 | (8,3) | berg variant A | **ja** | buren ook berg: O, Z |
| 57 | (9,3) | berg variant A | **ja** | buren ook berg: N, O, Z |
| 58 | (10,3) | berg variant A | **ja** | buren ook berg: W |
| 59 | (11,3) | berg variant A | **ja** | buren ook berg: N, W |
| 60 | (12,3) | berg variant A | **ja** | buren ook berg: O, W |
| 61 | (13,3) | berg variant A | **ja** | buren ook berg: N, O, W |
| 62 | (14,3) | berg variant A | **ja** | buren ook berg: Z, W |
| 63 | (15,3) | berg variant A | **ja** | buren ook berg: N, Z, W |
| 64 | (0,4) | berg variant A | **ja** | buren ook berg: O, Z, W |
| 65 | (1,4) | berg variant A | **ja** | buren ook berg: N, O, Z, W |
| 116 | (4,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | los (geen buren van hetzelfde terrein) |
| 117 | (5,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N |
| 118 | (6,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: O |
| 119 | (7,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, O |
| 120 | (8,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: Z |
| 121 | (9,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, Z |
| 122 | (10,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: O, Z |
| 123 | (11,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, O, Z |
| 124 | (12,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: W |
| 125 | (13,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, W |
| 126 | (14,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: O, W |
| 127 | (15,7) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, O, W |
| 128 | (0,8) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: Z, W |
| 129 | (1,8) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, Z, W |
| 130 | (2,8) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: O, Z, W |
| 131 | (3,8) | berg variant B (dambord met A: (x+y) even = A, oneven = B) | **ja** | buren ook berg: N, O, Z, W |

### 4c. Zee met kust – #66 t/m #112 (47 varianten), allemaal solid

Masker-bits = waar LAND is: N=1, O=2, Z=4, W=8 (zijkanten) en NO=16, ZO=32, ZW=64, NW=128
(hoeken; een hoek telt alleen als beide zijkanten ernaast water zijn). Masker 0 = open zee.
Kust (rots/schuim) aan de kant(en) met land.

| # | (kol,rij) | masker | wat |
|---|---|---|---|
| 66 | (2,4) | 0 | open zee (geen kust) |
| 67 | (3,4) | 1 | land: N |
| 68 | (4,4) | 2 | land: O |
| 69 | (5,4) | 3 | land: N, O |
| 70 | (6,4) | 4 | land: Z |
| 71 | (7,4) | 5 | land: N, Z |
| 72 | (8,4) | 6 | land: O, Z |
| 73 | (9,4) | 7 | land: N, O, Z |
| 74 | (10,4) | 8 | land: W |
| 75 | (11,4) | 9 | land: N, W |
| 76 | (12,4) | 10 | land: O, W |
| 77 | (13,4) | 11 | land: N, O, W |
| 78 | (14,4) | 12 | land: Z, W |
| 79 | (15,4) | 13 | land: N, Z, W |
| 80 | (0,5) | 14 | land: O, Z, W |
| 81 | (1,5) | 15 | land: N, O, Z, W |
| 82 | (2,5) | 16 | land: NO-hoek |
| 83 | (3,5) | 20 | land: Z, NO-hoek |
| 84 | (4,5) | 24 | land: W, NO-hoek |
| 85 | (5,5) | 28 | land: Z, W, NO-hoek |
| 86 | (6,5) | 32 | land: ZO-hoek |
| 87 | (7,5) | 33 | land: N, ZO-hoek |
| 88 | (8,5) | 40 | land: W, ZO-hoek |
| 89 | (9,5) | 41 | land: N, W, ZO-hoek |
| 90 | (10,5) | 48 | land: NO-hoek, ZO-hoek |
| 91 | (11,5) | 56 | land: W, NO-hoek, ZO-hoek |
| 92 | (12,5) | 64 | land: ZW-hoek |
| 93 | (13,5) | 65 | land: N, ZW-hoek |
| 94 | (14,5) | 66 | land: O, ZW-hoek |
| 95 | (15,5) | 67 | land: N, O, ZW-hoek |
| 96 | (0,6) | 80 | land: NO-hoek, ZW-hoek |
| 97 | (1,6) | 96 | land: ZO-hoek, ZW-hoek |
| 98 | (2,6) | 97 | land: N, ZO-hoek, ZW-hoek |
| 99 | (3,6) | 112 | land: NO-hoek, ZO-hoek, ZW-hoek |
| 100 | (4,6) | 128 | land: NW-hoek |
| 101 | (5,6) | 130 | land: O, NW-hoek |
| 102 | (6,6) | 132 | land: Z, NW-hoek |
| 103 | (7,6) | 134 | land: O, Z, NW-hoek |
| 104 | (8,6) | 144 | land: NO-hoek, NW-hoek |
| 105 | (9,6) | 148 | land: Z, NO-hoek, NW-hoek |
| 106 | (10,6) | 160 | land: ZO-hoek, NW-hoek |
| 107 | (11,6) | 176 | land: NO-hoek, ZO-hoek, NW-hoek |
| 108 | (12,6) | 192 | land: ZW-hoek, NW-hoek |
| 109 | (13,6) | 194 | land: O, ZW-hoek, NW-hoek |
| 110 | (14,6) | 208 | land: NO-hoek, ZW-hoek, NW-hoek |
| 111 | (15,6) | 224 | land: ZO-hoek, ZW-hoek, NW-hoek |
| 112 | (0,7) | 240 | land: NO-hoek, ZO-hoek, ZW-hoek, NW-hoek |

## 5. player.png en npc.png – 48x96, frames van 16x24

3 kolommen x 4 rijen, frame (kolom c, rij r) op x = c*16, y = r*24.

| rij | y | kijkrichting |
|---|---|---|
| 0 | 0 | onder (naar de camera) |
| 1 | 24 | links |
| 2 | 48 | rechts (mag het gespiegelde 'links' zijn, maar het hoeft niet) |
| 3 | 72 | boven (rug naar de camera) |

| kolom | x | frame |
|---|---|---|
| 0 | 0 | stil (staan) |
| 1 | 16 | stap A (bv. linkervoet voor) |
| 2 | 32 | stap B (andere voet voor) |

- Loopcyclus in het spel: **1, 0, 2, 0** (stap A, stil, stap B, stil), een nieuw frame elke
  8 px lopen (4 tiles/sec = ±8 frames/sec).
- **Plaatsing:** de onderste 16 rijen van het frame (y 8-23) vallen precies op de tile
  waar de figuur staat; de bovenste 8 rijen (hoofd) steken uit boven de tile erboven.
  Voeten dus onderaan het frame (rij ±21-23), horizontaal gecentreerd (x 7-8).
  Gele lijn in het sjabloon = bovenkant van die tile.
- Achtergrond doorzichtig; grondschaduw halfdoorzichtig onder de voeten mag.
- NPC: alleen kolom 0 wordt gebruikt (hij draait zich naar je toe, loopt niet), maar lever
  alle 12 frames voor later.
- Speler = Dennis (donkere cape, leer, grijze kraag). NPC = de Oude Wijze (geleerde).

## 6. sign.png – 16x16

Bordje, staat midden op een gras-tile (Sprite2D gecentreerd op de tile). Doorzichtige
achtergrond (het gras eronder is een eigen tile). Solid via het object (niet via het plaatje).

## 7. Wat NIET kan zonder engine-werk

- Andere tilemaat dan 16x16, ander framemaat dan 16x24, of meer/minder tiles per sheet.
- Een tile van solid naar begaanbaar zetten (of andersom): vraag het aan engine; dan pas ik
  `tools/build_maps.gd` + de .tres aan.
- Geanimeerde tiles (water, lantaarn) of extra objecten (bv. losse lantaarn-sprite,
  boekenkast als object): kan, maar dan als nieuw bestand + code; overleg eerst.
- Extra huizen of een groter dorp: kaartwerk door engine (tekst-maps in `tools/build_maps.gd`).

## 8. Controle na het inleveren

`python3` check (maat en modus):
```
from PIL import Image
for f, s in [("assets/tiles/dorp.png", (864, 16)), ("assets/tiles/huis.png", (80, 80)),
             ("assets/tiles/wereld.png", (256, 144)), ("assets/sprites/player.png", (48, 96)),
             ("assets/sprites/npc.png", (48, 96)), ("assets/sprites/sign.png", (16, 16))]:
    im = Image.open(f); assert im.size == s, (f, im.size); print(f, im.size, im.mode)
```
Daarna draait engine de autotest (`godot --headless --path . -- --autotest`): die controleert
o.a. dat zee/bergen blokkeren, bos begaanbaar is en alle overgangen werken.
