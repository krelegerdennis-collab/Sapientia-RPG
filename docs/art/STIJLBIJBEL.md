# SAPIENTIA – Stijlbijbel (art)

> Status: **concept** – Dennis keurt eerst de referenties goed. Daarna is dit document bindend voor elke nieuwe art-opdracht.

**Kernstijl:** *glitched digital decay meets dark academia*. 16-bit pixelart, donkergrijze basis, accenten in **magenta** en **cyaan** neon, subtiele scanlines/datadruppels. Verval (gebarsten steen, rafelige pagina's, mos) + digitale corruptie (verschoven pixelrijen, losse neon-pixels, runecirkels).

Referentiesheets (telefoonvriendelijk): `docs/art/referenties/referentie_bosses.png`, `referentie_omgevingen.png`, `vergelijking_achteruitgang.png`.

## 1. Stijlregels

| Regel | Norm |
|---|---|
| Outline | Volledig gesloten 1px outline in **#100e14** (bijna-zwart, licht paars). Geen zwarte #000000, geen ontbrekende stukken. Binnen-lijnen mogen een tint lichter (bv. #1c1a26). |
| Shading | Max **3–4 tonen per materiaal** (schaduw / basis / licht / highlight), harde stappen. Geen gradients, geen anti-aliasing naar de achtergrond, geen airbrush/blur. Dithering spaarzaam en alleen op grote vlakken. |
| Palet | Bron van waarheid: `/workspace/art_palette/out/sapientia_palette.{png,gpl,hex,json}` (64 kleuren). Basis = donkergrijzen/koele steentinten; accent = magenta-ramp (`#c03098 #e040c0 #ffc8e8`) en cyaan (`#40e0e8 #c8f4ff`). Goud/oranje alleen als klein detail (kroon, gesp), nooit dominant. Sprite: ≤ ~60 kleuren; achtergrond: ≤ ~250 kleuren (geen 1500+ kleuren-gradients). |
| Glitch-accenten | Elke vijand/boss heeft minstens één neon-kern of -oog (magenta, of cyaan voor "koude"/water/spiegel), plus 2–6 losse "data-pixels" rond het silhouet. Bosses: daarnaast 1 glitch-element (verschoven rij, scheur met neon, runecirkel). Omgevingen: zwevende magenta/cyaan pixels, neon runen, optioneel scanlines. |
| Lichtrichting | Licht van **linksboven**; schaduw rechtsonder; zachte ovale grondschaduw onder de sprite. Neon-kern geeft eigen lokale rim-light. |
| Sfeer | Dark academia: boeken, steen, perkament, kaarsen, archiefkasten. Geen schattige pastel-"Pokémon"-stijl voor vijanden: ook kleine monsters zijn een beetje vervallen/onheilspellend. |
| Formaten | Veld/overworld-sprites: **16x24** frames. Battle-sprites (party & bosses): **210x210** canvas, voeten op **(105,203)**. Gewone vijanden: ≈90x90–110x110 met voeten onderin midden. Battle-achtergronden: **1280x432**. Tiles: 16x16 grid. |
| Schaal | Native pixels, geen gemengde pixelgroottes, geen downscaled hi-res art. Opschalen alleen nearest-neighbor. |

## 2. Referentie-assets (OG-stijl, v0.17 / 08-10-2026, commit 5f893dc)

**Bosses / vijanden**
- `assets/sprites/enemies/golem_boss.png` (+ `_idle`, `_hit`) – Golem met roze kern: hét ijkpunt.
- `assets/sprites/enemies/golem_boss_v2.png`
- `assets/sprites/enemies/kennis_beest.png`
- `assets/sprites/enemies/wortelkoning.png`
- `assets/sprites/enemies/mech_wachter.png`
- `assets/sprites/enemies/glitchmot.png`
- `assets/sprites/enemies/sporenzwam.png`
- `assets/sprites/enemies/wortelkruiper.png`
- `art/enemies/mosslijm.png`

**Party (battle, 210x210)**
- `assets/sprites/battle/dennis.png`, `noor.png`, `lotte.png` (+ `dennis_rug.png`)

**Omgevingen**
- `art/battle_bg/boss.png` – ruined library met magenta runecirkel (ijkpunt achtergronden)
- `assets/battle/bibliotheek.png`, `assets/battle/bibliotheek_overwoekerd.png`, `assets/battle/donker_woud.png`
- `assets/tiles/dungeon/dungeon_tiles_v14.png`, `bibliotheek_tiles.png`, `archief_grijs_tiles.png`, `assets/tiles/wereld_v14.png`

## 3. Verplichte checklist voor elke nieuwe art-opdracht

Neem deze lijst letterlijk op in de opdracht en vink af bij oplevering:

- [ ] Referentie genoemd: welk(e) asset(s) uit §2 is het voorbeeld?
- [ ] Formaat klopt (16x24 veld / 210x210 battle met voeten (105,203) / 1280x432 bg / 16x16 tiles).
- [ ] Alle kleuren uit `sapientia_palette` (of expliciet gemotiveerde uitzondering); kleurenaantal binnen limiet.
- [ ] Gesloten outline #100e14, geen gaten.
- [ ] Max 3–4 shading-stappen per materiaal, geen gradients/blur/AA, licht linksboven.
- [ ] Neon-accent aanwezig (magenta en/of cyaan) + data-pixels/glitch-element.
- [ ] Donkergrijze/koele basis; goud/oranje/pastel niet dominant.
- [ ] Naast referentie bekeken op 1x én 4x (nearest-neighbor); past in dezelfde scène als Golem + party.
- [ ] Rug-/idle-/hit-varianten in dezelfde stijl en hetzelfde canvas.
- [ ] Placeholder? Dan zo gemarkeerd in naam/commit en op de herzienlijst.

## 4. Assets die herzien moeten worden

Batch bepaald met `git log --diff-filter=A`.

**Bosses – batch 11/12 (13-10, 20dec9f / 3ee9243 / dbadf25)**
| Asset | Reden |
|---|---|
| `assets/sprites/enemies/great_book_golem.png` | Goud/oranje domineert, glanzende gladde shading, 150 kleuren, 256x200 i.p.v. 210x210; weinig verval. |
| `assets/sprites/enemies/seal_warden.png` | Goud-metaalglans, geen glitch, palet wijkt af, 256x200. |
| `assets/sprites/enemies/de_cyclus.png` | Groot goud/staal rad, gladde shading, 119 kleuren, 256x200. |
| `assets/sprites/enemies/de_rechter.png` | Goud/messing domineert, 121 kleuren, 256x200. |
| `assets/sprites/enemies/mist_lord.png` | Blauw-realistische veren, geen magenta, minder glitch, 256x200. |
| `assets/sprites/enemies/page_warden.png` | Beige vlak, 0% magenta/cyaan, geen neon-kern, 256x200. |
| `assets/sprites/enemies/root_emperor.png`, `root_mother.png` | Zachter, minder decay; formaat 256x200. (Neon wel aanwezig – lichte herziening.) |
| `assets/sprites/enemies/spore_lord.png` | Fel limoengroen buiten palet, gladde dop. |
| `assets/sprites/enemies/schaduw_h6.png` | Outline maar 61% gesloten, 256x200. |
| `assets/sprites/enemies/glitch_queen.png`, `de_stem.png` | Stijl redelijk; alleen formaat naar 210x210 / voeten (105,203). |

**Kleine vijanden – Archief 2 / berggrot (11–13-10, e195282 / 3814a9b / f90d63b / 20dec9f)**
| Asset | Reden |
|---|---|
| `rankje.png`, `sporekop.png`, `wortelgeest.png`, `woudgeest.png`, `bloeiende_schrik.png`, `doornige_loper.png` | Pastel/"cute", 15–20 kleuren vlak, geen neon of glitch (0% magenta/cyaan), outline onvolledig (rankje 51%, wortelgeest 65%). |
| `adermot.png`, `druipslak.png`, `steenluis.png`, `echo.png` | Vlak pastel/lila, weinig verval; neon minimaal. |

**Omgevingen**
| Asset | Reden |
|---|---|
| `assets/battle/berggrot.png` (batch 13) | ~1600 kleuren met zachte gradients (niet 16-bit), alleen cyaan, geen magenta, geen academia-elementen. |
| `assets/battle/diepe_grot.png` (batch 13) | Bruin/zacht, ~1600 kleuren, nauwelijks neon. |
| `assets/bg/spiegel_kamer.png`, `spiegel_kamer_gebroken.png` (11-10) | Afwijkend formaat 384x216, glossy blauw glas, 1500–1800 kleuren. |
| `art/battle_bg/gras.png`, `zand.png` (v0.17, maar off-style) | Bijna fotorealistisch/schilderachtig, geen neon of decay. |
| `assets/tiles/dungeon/kas_tiles.png`, `kas_bibliotheek.png`, `archief2_kas_tiles.png` | Gemarkeerd als placeholder; groene tint – herzien bij definitieve kas-art. |

## 5. Opmerking palet
Het palet in `/workspace/art_palette/out/` is nieuwer dan de bestaande art: ook de referenties gebruiken (vrijwel) geen exacte paletkleuren. Voor **nieuwe** art is het palet verplicht; bij herzieningen de referentie-look aanhouden en naar het palet kwantiseren.
