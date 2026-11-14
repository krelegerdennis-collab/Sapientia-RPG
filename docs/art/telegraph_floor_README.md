# WM1 vloer-telegraphs — RPG ART → RPG FORGE

Spec: `/workspace/combat/telegraph_art/SPEC_TELEGRAPH_ART.md` (RPG COMBAT, finish/wm1 @ db9d44e2).
Pad in repo: `assets/sprites/telegraph/` (spec noemt geen pad). Alles PNG RGBA, alpha alleen 0/255,
alleen masterpalet (palet_check --streng: exit 0). Import: **Nearest, geen mipmaps, geen filter**.
Geen `.import`/`.uid` meegeleverd: die maakt Godot zelf.

## Sheets en frame-layout
Sheets 1-4: **2 rijen x 5 kolommen**. Rij 0 = ROOD (ontwijken), rij 1 = GEEL met arcering (onderbreekbaar).
Kolom 0..3 = windup-vulstap 25/50/75/100 % (van buiten naar binnen), kolom 4 = impact-flits.
In code: `frame = row * 5 + col`, met `col = fill_steps - 1` tijdens WINDUP (fill_steps 1..3 uit
`fill_steps_for_phase`) en `col = 3` bij ACTIVE; kolom 4 (flits) 1 frame (~100 ms) op het moment van de treffer.
(fill_steps 0 = niets tekenen, zoals nu.)

| Bestand | Sheet | Cel | Gebruik | Ankerpunt in de cel |
|---|---|---|---|---|
| telegraph_circle_48.png | 240x96 | 48x48 | inktplas-telegraph, golem_book_hammer (r 24) | midden (24,24) |
| telegraph_circle_96.png | 480x192 | 96x96 | golem_hammer_blow large_aoe (r 48) | midden (48,48) |
| telegraph_arc120_64.png | 320x128 | 64x64 | golem_sweep (+p2), 120°, reach 32, opent naar +x | top = midden (32,32) |
| telegraph_line_16.png | 160x32 | 32x16 = [middenstuk 16x16 \| eindkap 16x16] | inktspuw, golem_shockwave | as = rij 8, origin = linkerkant |
| telegraph_inkspit_22x44.png | 110x88 | 22x44 (22 lang langs x, 44 breed langs y) | inktspuw (Inktwurm), eigen sheet i.p.v. 9-slice | origin = midden linkerrand (0,22); tip rechts |
| telegraph_arc120_diag_64.png | 320x128 | 64x64 | golem_sweep diagonaal (rechtsonder, 45°) | top = midden (32,32) |
| telegraph_line_start_16.png | 80x32 | 16x16 | startkap (origin-kant) voor telegraph_line_16 | as = rij 8 |
| telegraph_line_diag_16.png | 360x48 | 72x24 = [startkap \| middenstuk \| eindkap], elk 24x24 | lijn diagonaal (rechtsonder) | zie "Diagonale lijn" |
| telegraph_inkspit_diag_22x44.png | 240x96 | 48x48 | inktspuw diagonaal (rechtsonder) | origin = pixelhoek (16,16) |
| telegraph_ink_zone_48.png | 192x48 | 48x48, **1 rij x 4 frames** loop, 100 ms/frame | blijvende inktplas-zone (120 ticks) | midden (24,24) |

Cirkels vullen de cel exact (doorsnede = celmaat), dus `Sprite2D.centered = true` op `shape.origin`, geen schaal.
Boog: `centered = true`, `position = origin`, `rotation = dir.angle()` (art kijkt naar +x). Draaien maakt de pixels
niet perfect (spec); 8 vaste richtingen kan ik later leveren als Forge dat beslist.

## Lijn: hoe snijden
- Middenstuk = x 0..15 van de cel, links/rechts naadloos tegelbaar (patroon-periode 2 en 4 passen in 16).
- Eindkap = x 16..31, afgeronde punt aan de rechterkant (tip, verst van de vijand).
- Opbouw van origin naar tip: middenstuk herhalen (laatste stuk mag worden afgekapt met region_rect) en de eindkap op
  `tip - 16`. Voor 80 lang (schokgolf): [startkap uit telegraph_line_start_16] + 3x midden + [eindkap] = 80 = 5 tegels.
  **Niet** de eindkap spiegelen: dan loopt de gele arcering in de kap de verkeerde kant op. De startkap is apart
  getekend met het patroon in fase met het middenstuk (gecontroleerd: start+midden+eind = één doorlopende tekening).
  Voor 22 lang (inktspuw): 6 px midden + kap.
- Breedte: tegel is 16 hoog (= schokgolf). Breder (inktspuw 44) via verticale 9-slice met **marge boven 6 / onder 6**,
  middenrijen 6..9 **tegelen** (niet rekken) — werkt pixel-schoon zolang (breedte − 12) een veelvoud van 4 is
  (16 ✓, 44 ✓). In vulstap 1..3 zijn rijen 6..9 leeg, dus de 9-slice klopt in elke stap.
- Vulling lijn: van beide lange randen (en de kap-punt) naar de as, diepte 1/2/3 px per kant, stap 4 = vol.

## Inktspuw (eigen sheet)
Zelfde 2x5-layout en frame-mapping. Vulling van alle kanten naar binnen met vaste diepte 2/4/6 px (stap 1/2/3),
stap 4 vol: duidelijk verschillende stappen. `centered = false`, `offset = Vector2(0, -22)`, `rotation = dir.angle()`.
Gebruik deze sheet voor de inktspuw; de 9-slice-route van de lijn hoeft dan niet. Een 45°-variant is niet getekend:
alleen nodig als Forge de inktspuw niet vrij wil roteren (diagonaal gedraaid wordt hij niet pixel-perfect).

## 8 richtingen zonder vrij draaien (alleen 90°-stappen + spiegelen)
Alle vormen zijn symmetrisch om hun as, dus spiegelen verandert de vorm niet, alleen de richting.
Rechte sheets (basis = rechts), diagonale sheets (basis = rechtsonder):

| Richting | Sheet | Godot | Beeld-operatie | Arcering |
|---|---|---|---|---|
| rechts | recht | — | — | "/" |
| omlaag | recht | `rotation = PI/2`, `flip_v = true` | transponeren (spiegel over y=x) | "/" |
| links | recht | `rotation = PI` | 180° | "/" |
| omhoog | recht | `rotation = PI/2`, `flip_h = true` | spiegel over y=-x | "/" |
| rechtsonder | diag | — | — | "/" |
| linksboven | diag | `rotation = PI` | 180° | "/" |
| rechtsboven | diag | `rotation = -PI/2` | 90° tegen de klok | "\\" |
| linksonder | diag | `rotation = PI/2` | 90° met de klok | "\\" |

Met deze keuze houden 6 van de 8 richtingen de wereldvaste "/"-arcering. Rechtsboven en linksonder krijgen "\\":
met alleen 90°-stappen en spiegelen kan dat wiskundig niet anders (elke bewerking die "/" behoudt, beeldt rechtsonder
af op rechtsonder of linksboven). Geel blijft herkenbaar aan kleur + arcering; wil Forge overal "/", dan teken ik één
extra rechtsboven-sheet per diagonale vorm. Draai om het ankerpunt (pixelhoek), dan blijft alles pixel-perfect.
Rood schaakbord en flits-gaatjes zijn richting-onafhankelijk.
Pixel-check: alle 10 PNG's alpha 0/255, palet_check --streng exit 0. Previews: `preview_arc120_8richtingen_4x.png`,
`preview_inkspit_8richtingen_4x.png` (kolommen = frame 50 %, 100 %, flits; per vloer rood en geel; witte stip = origin).

## Diagonale lijn (rechtsonder, 45°)
- As door pixelhoek O (origin, bij de vijand), richting (1,1). Breedte ±7,9 px loodrecht (= 16 breed), rand 1+2+1.
- Stukken zijn plakken loodrecht op de as van 16 eenheden x+y = **11,31 px langs de as**.
- **Tegelstap: (+8, +8) px per stuk.** Stuk k (0 = startkap) staat met zijn 24x24-cel linksboven op `O + (8k - 6, 8k - 6)`.
  Stukken overlappen niet (elk pixel hoort bij precies één stuk); de lege hoeken van de cel zijn transparant.
- Opbouw: startkap + n middenstukken + eindkap. Lengte = (n + 2) x 11,31 px. 80 px (schokgolf) ⇒ n = 5 (79,2 px);
  22 px (inktspuw-lengte) ⇒ n = 0 (22,6 px). Gecontroleerd: uit de sheet samengesteld = direct getekende lijn, pixel voor pixel.
- Vulstappen: van beide randen en beide kappen naar de as, 2/4/6 diagonale niveaus (~1,4/2,8/4,2 px), stap 4 vol.
- Preview: `preview_line_diag_80px_4x.png`.

## Diagonale inktspuw
48x48-cel, origin O = pixelhoek (16,16) (midden van de achterrand, bij de Inktwurm); 22 px langs (1,1), 44 px breed,
tip-hoeken afgerond. Plaatsen: `centered = false`, `offset = -Vector2(16, 16)`. Vulstappen 3/6/9 diagonale niveaus
(~2,1/4,2/6,4 px), stap 4 vol. Preview: `preview_inkspit_diag_22x44_4x.png`.

## Kleur en doorzichtigheid
- Doorzichtigheid zit in het patroon (alpha 0/255): rood = 50 % schaakbord-dither, geel = diagonale arcering "/" (50 %).
  Rand 3 px: 1 px donkere contour (leest op lichte vloer) + 2 px licht (leest op donkere vloer).
  Voorrand van de vulling = 1 px lijn, zodat de voortgang leesbaar is.
- Flits: rood ~88 % dekking (R5/R4 + verspreide gaatjes), geel arcering 75 % (G5/G4/G3), rand bijna-wit.
- Extra zachter maken: `modulate.a` (bv. 0.85). **Niet** inkleuren met modulate-kleur: rood/geel zitten in de art.
- HD-2D: zet de telegraph-node op `Hd2dUnmodulated` zodat rood/geel niet door het kaartlicht verkleuren.

## Kleuren (masterpalet)
Rood: Red/Danger 1,2,3,4,5,6 + White/Paper 5 (flits). Geel: Gold 1..5 + White/Paper 5.
Inkt: Glitch Purple 1..5, glitch-glinster Glitch Magenta 3/4.

## Previews (4x)
`preview/preview_*_4x.png`: bovenaan de sheet op schaakbord, daaronder elke rij op 5 WM1-vloeren
(archief-steen donker, bieb-hout, bieb-tapijt rood, pleister licht, gras). Inktspuw-sheet als `preview_inkspit_22x44_4x.png`. Lijn ook als 80x16 (schokgolf) en
22x44 (inktspuw via 9-slice) getoond. Bron: `src/teken.py`, `src/teken_diag.py` (art), `src/preview.py`, `src/preview_diag.py` (previews).
