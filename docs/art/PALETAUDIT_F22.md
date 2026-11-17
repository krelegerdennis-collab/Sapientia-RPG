# Paletaudit F2.2 — meting met `--negeer '**/*_n.png'`

**Status:** rapport van een read-only meting. Geen art gewijzigd; RPG FORGE zette dit rapport via een docs-PR in de repo.
**Bron:** `origin/finish/wm1` @ `cd491d3a7bd8a5531852ba1165f0b70f8d70fd64` (17 nov 2026, 13:19 Europe/Amsterdam).
**Tools:** `palet_check.py` en `meet.py` van deze head, inclusief `--negeer` uit PR #505 (gemerged als `47e3daf9661af05aee732843d183ea1c7e903c6a`, 17 nov 2026, 11:55 Europe/Amsterdam). Geen losse #505-branch gebruikt.
**Palet:** `docs/art/masterpalet.gpl` — 73 kleuren.
**Export:** git archive van alleen `art/`, `world_warper/art/`, `assets/`, `docs/art/` en `tools/art_audit/`. `wacht/wm2/` is niet uitgepakt en niet gelezen.
**Meting:** 17 nov 2026, 15:05 Europe/Amsterdam.
**Pad in de repo:** `docs/art/PALETAUDIT_F22.md` (bron: HANDOFF van RPG ART, `/workspace/art_f22/run2/`).

Afwijkingen niet aangepast; wacht op besluit Dennis.

## Commando’s

Cwd: export-root (zelfde lay-out als de repo-root, zonder `wacht/`).

```
python3 tools/art_audit/meet.py \
  --palet docs/art/masterpalet.gpl \
  --assets <map> \
  --uit /workspace/art_f22/run2/out/meet_<naam>.csv \
  --negeer '**/*_n.png'

python3 tools/art_audit/palet_check.py \
  --palet docs/art/masterpalet.gpl \
  --assets <map> --top 0 --streng \
  --negeer '**/*_n.png'
```

Gescande mappen: `art/`, `world_warper/art/`, `assets/`, en aanvullend `docs/art/` (1 PNG).

Tool-blobs op deze head: `palet_check.py` `e8ff1195f89a2f5a4660d79087751ca1efee7463`, `meet.py` `b6fe1780805f65839aa62da126b7d76de29d5f75`.

## Totalen

| Map | Gecontroleerd | Schoon | Paletfout | Genegeerd | Semi-alpha | Maat niet ÷16 | `palet_check --streng` |
|---|---:|---:|---:|---:|---:|---:|---|
| `art/` | 12 | 3 | 9 | 0 | 8 | 7 | exit 1 |
| `world_warper/art/` | 89 | 16 | 73 | 0 | 25 | 8 | exit 1 |
| `assets/` | 1491 | 1153 | 338 | 461 | 72 | 232 | exit 1 |
| `docs/art/` | 1 | 1 | 0 | 0 | 0 | 1 | exit 0 |
| **Totaal** | **1593** | **1173** | **420** | **461** | **105** | **248** | |

In de export zaten 2054 PNG’s, waarvan 461 `*_n.png`. Alle 461 zijn genegeerd en ontbreken in de CSV’s. Geen `*_n.png` in `art/` of `world_warper/art/`.

Een bestand telt als paletfout als `buiten_palet > 0`. Semi-alpha en maat komen uit `meet.py` (`semi_transparant` / `alpha_alleen_0_255`, `deelbaar_door_16`). Sommige bestanden falen op meer dan één regel; de kolommen tellen bestanden, geen unieke cases. Bestanden met minstens één afwijking: **643**.

## `light_soft_128.png`

**Nog steeds gecontroleerd** — de glob `**/*_n.png` slaat dit bestand niet over (geen `_n`-suffix).

- Pad: `assets/hd2d/fx_data/light_soft_128.png`
- 128×128 (wel deelbaar door 16)
- 238 kleuren buiten palet / 238 uniek
- 11364 semi-transparante pixels (`alpha_alleen_0_255` = nee)
- Staat in de palet_check-log (derde hoogste afwijker in `assets/`) en in `meet_assets.csv`.

Dit lijkt een data-/lichttextuur, geen pixelart-sprite. Geen automatische uitzondering; wacht op besluit Dennis.

## Vergelijking met de eerdere meting (9a87280c, 17 nov 11:15 Europe/Amsterdam)

- `art/` en `world_warper/art/`: identieke tellingen en identieke metingen per bestand (12/89 PNG’s, 3/16 schoon, 9/73 paletfout).
- Genegeerde normal maps: dezelfde **461** paden als in `voorstel_negeer_nmaps.txt`.
- `assets/hd2d/`: was 672 PNG’s, 218 schoon, 454 paletfout (453× `*_n.png` + `light_soft_128`). Nu 219 gecontroleerd, 218 schoon, **1** paletfout (`light_soft_128`).
- `assets/placeholder/woud/`: was 84 PNG’s (4 nmaps); nu 80 gecontroleerd, alle 80 paletfout.
- `assets/tiles/woud16/`: was 99 PNG’s (4 nmaps, allemaal schoon); nu 95 gecontroleerd, 95 schoon.
- Deze run scant heel `assets/` (niet alleen die drie deelmaps), plus `docs/art/`.

## Echte afwijkingen

Afwijkingen niet aangepast; wacht op besluit Dennis.

### `art/` — 9 bestanden (onveranderd t.o.v. run 1)

Paletschoon (geen actie): `art/battle_bg/boss.png`, `art/battle_bg/gras.png`, `art/battle_bg/zand.png` (alle 1280×432, geen semi, maat ÷16).

- `art/cutscene/glitch_panel.png` — kleuren buiten palet (2379 buiten / 2379 uniek); maat niet deelbaar door 16 (131×216)
- `art/enemies/moskonijn.png` — kleuren buiten palet (66 buiten / 66 uniek); semi-alpha (421 px); maat niet deelbaar door 16 (106×110)
- `art/enemies/mosslijm.png` — kleuren buiten palet (56 buiten / 56 uniek); semi-alpha (404 px); maat niet deelbaar door 16 (90×94)
- `art/enemies/moskonijn_rug.png` — kleuren buiten palet (36 buiten / 36 uniek); semi-alpha (422 px); maat niet deelbaar door 16 (106×110)
- `art/enemies/mosslijm_rug.png` — kleuren buiten palet (20 buiten / 20 uniek); semi-alpha (405 px); maat niet deelbaar door 16 (90×94)
- `art/map_creatures/moskonijn_speel.png` — kleuren buiten palet (19 buiten / 19 uniek); semi-alpha (98 px); maat niet deelbaar door 16 (96×24)
- `art/map_creatures/moskonijn_volg.png` — kleuren buiten palet (17 buiten / 17 uniek); semi-alpha (222 px)
- `art/map_creatures/mosslijm_speel.png` — kleuren buiten palet (17 buiten / 17 uniek); semi-alpha (90 px); maat niet deelbaar door 16 (96×24)
- `art/map_creatures/mosslijm_volg.png` — kleuren buiten palet (14 buiten / 14 uniek); semi-alpha (156 px)

### `world_warper/art/` — 73 paletfouten, plus 4 paletschone iconen met maat 72×20

Kleurvarianten (`_blauw` `_groen` `_oranje` `_rood` `_roze`) hebben dezelfde meting als het basisbestand. Gegroepeerd:

| Groep | Aantal | Palet | Semi-alpha | Maat |
|---|---:|---|---|---|
| `pc` | 6 | 14 buiten / 14 uniek | 8 px | 32×32 |
| `tiles` | 6 | 14 buiten / 19 uniek | 40 px | 128×32 |
| `tafel` | 6 | 11 buiten / 11 uniek | nee | 32×16 |
| `knop_village` | 1 | 10 buiten / 10 uniek | nee | 48×16 |
| `knop_wm1` | 1 | 10 buiten / 10 uniek | nee | 48×16 |
| `knop_wm2` | 1 | 10 buiten / 10 uniek | nee | 48×16 |
| `knop_wm3` | 1 | 10 buiten / 10 uniek | nee | 48×16 |
| `party` | 6 | 10 buiten / 10 uniek | 94 px | 48×96 |
| `toonbank` | 6 | 10 buiten / 10 uniek | nee | 48×16 |
| `bord_warp` | 6 | 9 buiten / 9 uniek | nee | 48×16 |
| `warp_platform` | 6 | 9 buiten / 9 uniek | nee | 32×16 |
| `bord_hal` | 6 | 8 buiten / 8 uniek | nee | 32×16 |
| `bord_kamers` | 6 | 8 buiten / 8 uniek | nee | 32×16 |
| `echo` | 6 | 7 buiten / 27 uniek | 2510 px | 48×96 |
| `warp_icoon_village_dicht` | 1 | 7 buiten / 11 uniek | nee | 72×20 (niet ÷16) |
| `knop_village_ingedrukt` | 1 | 6 buiten / 7 uniek | nee | 48×16 |
| `knop_wm1_ingedrukt` | 1 | 6 buiten / 7 uniek | nee | 48×16 |
| `knop_wm2_ingedrukt` | 1 | 6 buiten / 7 uniek | nee | 48×16 |
| `knop_wm3_ingedrukt` | 1 | 6 buiten / 7 uniek | nee | 48×16 |
| `warp_icoon_wm1_dicht` | 1 | 5 buiten / 9 uniek | nee | 72×20 (niet ÷16) |
| `warp_icoon_wm3_dicht` | 1 | 4 buiten / 8 uniek | nee | 72×20 (niet ÷16) |
| `hanger_gloed` | 1 | 3 buiten / 6 uniek | 224 px | 64×16 |
| `warp_icoon_wm2_dicht` | 1 | 3 buiten / 7 uniek | nee | 72×20 (niet ÷16) |
| `warp_icoon_village` | 1 | schoon | nee | 72×20 (niet ÷16) |
| `warp_icoon_wm1` | 1 | schoon | nee | 72×20 (niet ÷16) |
| `warp_icoon_wm2` | 1 | schoon | nee | 72×20 (niet ÷16) |
| `warp_icoon_wm3` | 1 | schoon | nee | 72×20 (niet ÷16) |

Bestanden per groep (repo-relatief):

- **pc** (6): `world_warper/art/pc.png`, `world_warper/art/pc_blauw.png`, `world_warper/art/pc_groen.png`, `world_warper/art/pc_oranje.png`, `world_warper/art/pc_rood.png`, `world_warper/art/pc_roze.png`
- **tiles** (6): `world_warper/art/tiles.png`, `world_warper/art/tiles_blauw.png`, `world_warper/art/tiles_groen.png`, `world_warper/art/tiles_oranje.png`, `world_warper/art/tiles_rood.png`, `world_warper/art/tiles_roze.png`
- **tafel** (6): `world_warper/art/tafel.png`, `world_warper/art/tafel_blauw.png`, `world_warper/art/tafel_groen.png`, `world_warper/art/tafel_oranje.png`, `world_warper/art/tafel_rood.png`, `world_warper/art/tafel_roze.png`
- **knop_village** (1): `world_warper/art/knop_village.png`
- **knop_wm1** (1): `world_warper/art/knop_wm1.png`
- **knop_wm2** (1): `world_warper/art/knop_wm2.png`
- **knop_wm3** (1): `world_warper/art/knop_wm3.png`
- **party** (6): `world_warper/art/party.png`, `world_warper/art/party_blauw.png`, `world_warper/art/party_groen.png`, `world_warper/art/party_oranje.png`, `world_warper/art/party_rood.png`, `world_warper/art/party_roze.png`
- **toonbank** (6): `world_warper/art/toonbank.png`, `world_warper/art/toonbank_blauw.png`, `world_warper/art/toonbank_groen.png`, `world_warper/art/toonbank_oranje.png`, `world_warper/art/toonbank_rood.png`, `world_warper/art/toonbank_roze.png`
- **bord_warp** (6): `world_warper/art/bord_warp.png`, `world_warper/art/bord_warp_blauw.png`, `world_warper/art/bord_warp_groen.png`, `world_warper/art/bord_warp_oranje.png`, `world_warper/art/bord_warp_rood.png`, `world_warper/art/bord_warp_roze.png`
- **warp_platform** (6): `world_warper/art/warp_platform.png`, `world_warper/art/warp_platform_blauw.png`, `world_warper/art/warp_platform_groen.png`, `world_warper/art/warp_platform_oranje.png`, `world_warper/art/warp_platform_rood.png`, `world_warper/art/warp_platform_roze.png`
- **bord_hal** (6): `world_warper/art/bord_hal.png`, `world_warper/art/bord_hal_blauw.png`, `world_warper/art/bord_hal_groen.png`, `world_warper/art/bord_hal_oranje.png`, `world_warper/art/bord_hal_rood.png`, `world_warper/art/bord_hal_roze.png`
- **bord_kamers** (6): `world_warper/art/bord_kamers.png`, `world_warper/art/bord_kamers_blauw.png`, `world_warper/art/bord_kamers_groen.png`, `world_warper/art/bord_kamers_oranje.png`, `world_warper/art/bord_kamers_rood.png`, `world_warper/art/bord_kamers_roze.png`
- **echo** (6): `world_warper/art/echo.png`, `world_warper/art/echo_blauw.png`, `world_warper/art/echo_groen.png`, `world_warper/art/echo_oranje.png`, `world_warper/art/echo_rood.png`, `world_warper/art/echo_roze.png`
- **warp_icoon_village_dicht** (1): `world_warper/art/warp_icoon_village_dicht.png`
- **knop_village_ingedrukt** (1): `world_warper/art/knop_village_ingedrukt.png`
- **knop_wm1_ingedrukt** (1): `world_warper/art/knop_wm1_ingedrukt.png`
- **knop_wm2_ingedrukt** (1): `world_warper/art/knop_wm2_ingedrukt.png`
- **knop_wm3_ingedrukt** (1): `world_warper/art/knop_wm3_ingedrukt.png`
- **warp_icoon_wm1_dicht** (1): `world_warper/art/warp_icoon_wm1_dicht.png`
- **warp_icoon_wm3_dicht** (1): `world_warper/art/warp_icoon_wm3_dicht.png`
- **hanger_gloed** (1): `world_warper/art/hanger_gloed.png`
- **warp_icoon_wm2_dicht** (1): `world_warper/art/warp_icoon_wm2_dicht.png`
- **warp_icoon_village** (1): `world_warper/art/warp_icoon_village.png`
- **warp_icoon_wm1** (1): `world_warper/art/warp_icoon_wm1.png`
- **warp_icoon_wm2** (1): `world_warper/art/warp_icoon_wm2.png`
- **warp_icoon_wm3** (1): `world_warper/art/warp_icoon_wm3.png`

Paletschoon én zonder semi of maatfout (12 stuks, alle 16×16): de kleurvarianten van `vlak_gezelschap` en `vlak_warp`.

### `assets/` — 338 paletfouten na uitsluiting van de normal maps

Verdeling paletfouten per prefix:

| Prefix | Paletfout |
|---|---:|
| `assets/ui` | 129 |
| `assets/sprites` | 97 |
| `assets/placeholder` | 80 |
| `assets/puzzle` | 12 |
| `assets/tiles` | 9 |
| `assets/fx` | 5 |
| `assets/bg` | 2 |
| `assets/characters` | 2 |
| `assets/hd2d` | 1 |
| `assets/map_monsters` | 1 |
| **Totaal** | **338** |

Daarnaast 218 paletschone PNG’s in `assets/` waarvan de maat niet door 16 deelbaar is (geen semi-alpha, geen paletfout). Dat is een `meet.py`-gegeven, geen `palet_check --streng`-fout: `assets/sprites` 172, `assets/hd2d` 25, `assets/ui` 21. Niet gefixt.

Volledige lijst paletfouten in `assets/` (reden per bestand):

#### `assets/ui` (129)

- `assets/ui/portrait_dennis.png` — kleuren buiten palet (24 buiten / 24 uniek)
- `assets/ui/portrait_noor.png` — kleuren buiten palet (23 buiten / 24 uniek)
- `assets/ui/portrait_lotte.png` — kleuren buiten palet (21 buiten / 22 uniek)
- `assets/ui/portrait_wachter.png` — kleuren buiten palet (19 buiten / 19 uniek)
- `assets/ui/window_hd.png` — kleuren buiten palet (16 buiten / 16 uniek)
- `assets/ui/tekstvak_blauw.png` — kleuren buiten palet (12 buiten / 12 uniek); maat niet deelbaar door 16 (24×48)
- `assets/ui/ballon_blauw.png` — kleuren buiten palet (10 buiten / 10 uniek); maat niet deelbaar door 16 (24×48)
- `assets/ui/window.png` — kleuren buiten palet (9 buiten / 9 uniek)
- `assets/ui/window_glass.png` — kleuren buiten palet (9 buiten / 10 uniek); semi-alpha (144 px)
- `assets/ui/icons/reisgewaad.png` — kleuren buiten palet (7 buiten / 8 uniek)
- `assets/ui/panel_status.png` — kleuren buiten palet (5 buiten / 5 uniek); maat niet deelbaar door 16 (12×12)
- `assets/ui/ballon_staart.png` — kleuren buiten palet (4 buiten / 4 uniek); maat niet deelbaar door 16 (32×12)
- `assets/ui/icons/items/icons32/tegengif.png` — kleuren buiten palet (4 buiten / 19 uniek)
- `assets/ui/icons/items/icons16/herinnering.png` — kleuren buiten palet (3 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/tegengif.png` — kleuren buiten palet (3 buiten / 13 uniek)
- `assets/ui/icons/items/icons32/herinnering.png` — kleuren buiten palet (3 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/chitineharnas.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/groenring.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/hartmantel.png` — kleuren buiten palet (2 buiten / 7 uniek)
- `assets/ui/icons/items/icons16/hartpsalm.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/kweekschild.png` — kleuren buiten palet (2 buiten / 13 uniek)
- `assets/ui/icons/items/icons16/levenskern.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/levensstaf.png` — kleuren buiten palet (2 buiten / 11 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_zielenbloei.png` — kleuren buiten palet (2 buiten / 13 uniek)
- `assets/ui/icons/items/icons32/chitineharnas.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/groenring.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/hartmantel.png` — kleuren buiten palet (2 buiten / 7 uniek)
- `assets/ui/icons/items/icons32/hartpsalm.png` — kleuren buiten palet (2 buiten / 10 uniek)
- `assets/ui/icons/items/icons32/kweekschild.png` — kleuren buiten palet (2 buiten / 13 uniek)
- `assets/ui/icons/items/icons32/levenskern.png` — kleuren buiten palet (2 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/levensstaf.png` — kleuren buiten palet (2 buiten / 17 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_zielenbloei.png` — kleuren buiten palet (2 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/tempelhelm.png` — kleuren buiten palet (2 buiten / 10 uniek)
- `assets/ui/icons/items/icons16/ankerkling.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/ankerschild.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons16/antiserum_nul.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/dolk.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons16/drankje.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons16/gloeiende_inktfles.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/hanger.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons16/hartring.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/houten_schild.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/ijzeren_helm.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons16/ketelhelm.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/ketelkling.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons16/ketelschild.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons16/kruidenthee.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/kweekhelm.png` — kleuren buiten palet (1 buiten / 13 uniek)
- `assets/ui/icons/items/icons16/malienkolder.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/schrootplaat.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/smeerolie.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons16/spreuk_aureool.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_aureool.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_heilige_straal.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_oerbos.png` — kleuren buiten palet (1 buiten / 13 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_wederopstanding.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons16/spreuk_g4_zegen_der_goden.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/spreuk_genees.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/sterk_drankje.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons16/sterrenring.png` — kleuren buiten palet (1 buiten / 4 uniek)
- `assets/ui/icons/items/icons16/stroomdrank.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons16/stroomring.png` — kleuren buiten palet (1 buiten / 7 uniek)
- `assets/ui/icons/items/icons16/tempelhelm.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/tempelplaat.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons16/toverbrouwsel.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons16/toverwater.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons16/windwater.png` — kleuren buiten palet (1 buiten / 7 uniek)
- `assets/ui/icons/items/icons16/zingend_zaad.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/ankerkling.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/ankerschild.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons32/antiserum_nul.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/d100_helm_2.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons32/d100_helm_3.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons32/d100_helm_4.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons32/d100_helm_5.png` — kleuren buiten palet (1 buiten / 10 uniek)
- `assets/ui/icons/items/icons32/dolk.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/drankje.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/elixer.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons32/gloeiende_inktfles.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/hanger.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons32/hartring.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons32/houten_schild.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/ijzeren_helm.png` — kleuren buiten palet (1 buiten / 5 uniek)
- `assets/ui/icons/items/icons32/ketelhelm.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons32/ketelkling.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons32/ketelschild.png` — kleuren buiten palet (1 buiten / 6 uniek)
- `assets/ui/icons/items/icons32/kort_zwaard.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/kruidenthee.png` — kleuren buiten palet (1 buiten / 13 uniek)
- `assets/ui/icons/items/icons32/kweekhelm.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/malienkolder.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/perihelium.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons32/regeneratie.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons32/schrootplaat.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/smeerolie.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/spreuk_aureool.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/spreuk_bliksem.png` — kleuren buiten palet (1 buiten / 20 uniek)
- `assets/ui/icons/items/icons32/spreuk_donderslag.png` — kleuren buiten palet (1 buiten / 23 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_absolute_nul.png` — kleuren buiten palet (1 buiten / 23 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_apocalyps.png` — kleuren buiten palet (1 buiten / 21 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_aureool.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_dageraad.png` — kleuren buiten palet (1 buiten / 20 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_donderslag.png` — kleuren buiten palet (1 buiten / 23 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_eeuwige_winter.png` — kleuren buiten palet (1 buiten / 23 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_heilige_straal.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_hemelval.png` — kleuren buiten palet (1 buiten / 22 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_ijskern.png` — kleuren buiten palet (1 buiten / 24 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_oerbos.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_sneeuwkoningin.png` — kleuren buiten palet (1 buiten / 24 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_stormheer.png` — kleuren buiten palet (1 buiten / 23 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_wederopstanding.png` — kleuren buiten palet (1 buiten / 13 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_zegen_der_goden.png` — kleuren buiten palet (1 buiten / 14 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_zonneslag.png` — kleuren buiten palet (1 buiten / 20 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_zuiverende_donder.png` — kleuren buiten palet (1 buiten / 22 uniek)
- `assets/ui/icons/items/icons32/spreuk_g4_zuiverende_vlam.png` — kleuren buiten palet (1 buiten / 20 uniek)
- `assets/ui/icons/items/icons32/spreuk_genees.png` — kleuren buiten palet (1 buiten / 11 uniek)
- `assets/ui/icons/items/icons32/spreuk_ijskern.png` — kleuren buiten palet (1 buiten / 24 uniek)
- `assets/ui/icons/items/icons32/spreuk_inferno.png` — kleuren buiten palet (1 buiten / 21 uniek)
- `assets/ui/icons/items/icons32/spreuk_vuur.png` — kleuren buiten palet (1 buiten / 18 uniek)
- `assets/ui/icons/items/icons32/sterk_drankje.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/sterrenelixer.png` — kleuren buiten palet (1 buiten / 25 uniek)
- `assets/ui/icons/items/icons32/sterrenring.png` — kleuren buiten palet (1 buiten / 4 uniek)
- `assets/ui/icons/items/icons32/stroomdrank.png` — kleuren buiten palet (1 buiten / 15 uniek)
- `assets/ui/icons/items/icons32/stroomring.png` — kleuren buiten palet (1 buiten / 7 uniek)
- `assets/ui/icons/items/icons32/tempelplaat.png` — kleuren buiten palet (1 buiten / 8 uniek)
- `assets/ui/icons/items/icons32/toverbrouwsel.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/toverwater.png` — kleuren buiten palet (1 buiten / 12 uniek)
- `assets/ui/icons/items/icons32/windwater.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/zingend_zaad.png` — kleuren buiten palet (1 buiten / 9 uniek)
- `assets/ui/icons/items/icons32/zweefstaf.png` — kleuren buiten palet (1 buiten / 13 uniek)

#### `assets/sprites` (97)

- `assets/sprites/archief2/sapientia_glitch.png` — kleuren buiten palet (34 buiten / 65 uniek); semi-alpha (384 px)
- `assets/sprites/buiten/put.png` — kleuren buiten palet (33 buiten / 34 uniek); semi-alpha (26 px)
- `assets/sprites/buiten/wilgendal_accessoire.png` — kleuren buiten palet (30 buiten / 32 uniek)
- `assets/sprites/buiten/wilgendal_wapen.png` — kleuren buiten palet (28 buiten / 28 uniek)
- `assets/sprites/buiten/wilgendal_pantser.png` — kleuren buiten palet (27 buiten / 27 uniek)
- `assets/sprites/som/monsters/moskonijn_death.png` — kleuren buiten palet (27 buiten / 31 uniek); semi-alpha (2 px); maat niet deelbaar door 16 (96×24)
- `assets/sprites/archief2/wurger.png` — kleuren buiten palet (26 buiten / 28 uniek); semi-alpha (44 px)
- `assets/sprites/buiten/wilgendal_huis.png` — kleuren buiten palet (26 buiten / 27 uniek)
- `assets/sprites/buiten/wilgendal_magie.png` — kleuren buiten palet (26 buiten / 28 uniek)
- `assets/sprites/som/monsters/mosslijm_death.png` — kleuren buiten palet (26 buiten / 30 uniek); maat niet deelbaar door 16 (96×24)
- `assets/sprites/npc/koopman_veld.png` — kleuren buiten palet (25 buiten / 27 uniek); semi-alpha (160 px)
- `assets/sprites/som/monsters/glitchmot_death.png` — kleuren buiten palet (23 buiten / 28 uniek); semi-alpha (15 px); maat niet deelbaar door 16 (96×24)
- `assets/sprites/buiten/archief_ingang_open_flikker.png` — kleuren buiten palet (21 buiten / 23 uniek); semi-alpha (88 px)
- `assets/sprites/buiten/wilgendal_huis_dicht.png` — kleuren buiten palet (21 buiten / 21 uniek)
- `assets/sprites/buiten/wilgendal_vitrine.png` — kleuren buiten palet (21 buiten / 22 uniek)
- `assets/sprites/hub/mech_wachter_hub.png` — kleuren buiten palet (21 buiten / 23 uniek); semi-alpha (232 px)
- `assets/sprites/som/monsters/inktwurm_death.png` — kleuren buiten palet (21 buiten / 26 uniek); maat niet deelbaar door 16 (96×24)
- `assets/sprites/woud/noor_cocon_puls.png` — kleuren buiten palet (21 buiten / 23 uniek)
- `assets/sprites/buiten/archief_ingang.png` — kleuren buiten palet (20 buiten / 22 uniek); semi-alpha (88 px)
- `assets/sprites/hub/kennis_beest_hub.png` — kleuren buiten palet (19 buiten / 20 uniek); semi-alpha (222 px)
- `assets/sprites/woud/noor_cocon.png` — kleuren buiten palet (19 buiten / 21 uniek)
- `assets/sprites/archief2/lotte_glitch.png` — kleuren buiten palet (18 buiten / 20 uniek); semi-alpha (46 px)
- `assets/sprites/buiten/ruine.png` — kleuren buiten palet (18 buiten / 18 uniek); semi-alpha (78 px)
- `assets/sprites/som/monsters/moskonijn_attack.png` — kleuren buiten palet (18 buiten / 21 uniek); semi-alpha (17 px)
- `assets/sprites/archief2/lotte_veld.png` — kleuren buiten palet (17 buiten / 18 uniek); semi-alpha (160 px)
- `assets/sprites/buiten/molen_wieken.png` — kleuren buiten palet (17 buiten / 18 uniek)
- `assets/sprites/hub/mistuil_hub.png` — kleuren buiten palet (17 buiten / 18 uniek); semi-alpha (192 px)
- `assets/sprites/hub/moskonijn_hub.png` — kleuren buiten palet (17 buiten / 17 uniek); semi-alpha (240 px)
- `assets/sprites/hub/sporenzwam_hub.png` — kleuren buiten palet (17 buiten / 18 uniek); semi-alpha (192 px)
- `assets/sprites/noor_dorp.png` — kleuren buiten palet (17 buiten / 18 uniek); semi-alpha (132 px)
- `assets/sprites/som/monsters/moskonijn_hurt.png` — kleuren buiten palet (17 buiten / 18 uniek)
- `assets/sprites/som/monsters/papiergeest_death.png` — kleuren buiten palet (17 buiten / 21 uniek); semi-alpha (15 px); maat niet deelbaar door 16 (96×24)
- `assets/sprites/buiten/wilgendal_toonbank.png` — kleuren buiten palet (16 buiten / 16 uniek)
- `assets/sprites/buiten/kist.png` — kleuren buiten palet (15 buiten / 17 uniek); semi-alpha (20 px)
- `assets/sprites/hub/wortelkruiper_hub.png` — kleuren buiten palet (15 buiten / 17 uniek); semi-alpha (192 px)
- `assets/sprites/npc.png` — kleuren buiten palet (15 buiten / 16 uniek); semi-alpha (80 px)
- `assets/sprites/player.png` — kleuren buiten palet (15 buiten / 15 uniek); semi-alpha (132 px)
- `assets/sprites/archief2/plaat_volgroeid.png` — kleuren buiten palet (14 buiten / 14 uniek)
- `assets/sprites/buiten/wilgendal_schild.png` — kleuren buiten palet (14 buiten / 14 uniek)
- `assets/sprites/hp_book.png` — kleuren buiten palet (14 buiten / 18 uniek); semi-alpha (28 px)
- `assets/sprites/hub/mosslijm_hub.png` — kleuren buiten palet (14 buiten / 14 uniek); semi-alpha (216 px)
- `assets/sprites/mp_book.png` — kleuren buiten palet (14 buiten / 18 uniek); semi-alpha (28 px)
- `assets/sprites/som/monsters/inktwurm_hurt.png` — kleuren buiten palet (14 buiten / 15 uniek)
- `assets/sprites/archief2/world_warper.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/archief2/world_warper_blauw.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/archief2/world_warper_groen.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/archief2/world_warper_oranje.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/archief2/world_warper_rood.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/archief2/world_warper_roze.png` — kleuren buiten palet (13 buiten / 33 uniek); semi-alpha (344 px)
- `assets/sprites/buiten/wilgendal_ring.png` — kleuren buiten palet (13 buiten / 14 uniek)
- `assets/sprites/buiten/wilgendal_ster.png` — kleuren buiten palet (13 buiten / 14 uniek)
- `assets/sprites/buiten/wilgendal_zwaard.png` — kleuren buiten palet (13 buiten / 13 uniek)
- `assets/sprites/som/monsters/glitchmot_hurt.png` — kleuren buiten palet (13 buiten / 14 uniek); semi-alpha (48 px)
- `assets/sprites/som/monsters/inktwurm_attack.png` — kleuren buiten palet (13 buiten / 17 uniek); semi-alpha (2 px)
- `assets/sprites/som/monsters/mosslijm_attack.png` — kleuren buiten palet (13 buiten / 16 uniek)
- `assets/sprites/som/monsters/mosslijm_hurt.png` — kleuren buiten palet (13 buiten / 14 uniek)
- `assets/sprites/buiten/kas_ingang.png` — kleuren buiten palet (12 buiten / 13 uniek); semi-alpha (8 px)
- `assets/sprites/hub/glitchmot_hub.png` — kleuren buiten palet (12 buiten / 14 uniek); semi-alpha (192 px)
- `assets/sprites/hub/inktwurm_hub.png` — kleuren buiten palet (12 buiten / 13 uniek); semi-alpha (196 px)
- `assets/sprites/som/monsters/glitchmot_attack.png` — kleuren buiten palet (12 buiten / 17 uniek); semi-alpha (48 px)
- `assets/sprites/wachter.png` — kleuren buiten palet (12 buiten / 12 uniek); semi-alpha (72 px)
- `assets/sprites/save_book.png` — kleuren buiten palet (11 buiten / 17 uniek); semi-alpha (28 px)
- `assets/sprites/story/archief.png` — kleuren buiten palet (11 buiten / 11 uniek)
- `assets/sprites/story/put.png` — kleuren buiten palet (11 buiten / 12 uniek); semi-alpha (20 px); maat niet deelbaar door 16 (16×24)
- `assets/sprites/archief2/plaat_scheut.png` — kleuren buiten palet (10 buiten / 10 uniek)
- `assets/sprites/archief2/plaat_zaad.png` — kleuren buiten palet (10 buiten / 10 uniek)
- `assets/sprites/dungeon100_warper.png` — kleuren buiten palet (10 buiten / 11 uniek)
- `assets/sprites/sign.png` — kleuren buiten palet (10 buiten / 10 uniek); semi-alpha (4 px)
- `assets/sprites/hub/papiergeest_hub.png` — kleuren buiten palet (9 buiten / 9 uniek); semi-alpha (192 px)
- `assets/sprites/som/monsters/papiergeest_attack.png` — kleuren buiten palet (9 buiten / 13 uniek); semi-alpha (48 px)
- `assets/sprites/som/monsters/papiergeest_hurt.png` — kleuren buiten palet (9 buiten / 10 uniek); semi-alpha (48 px)
- `assets/sprites/story/zegel.png` — kleuren buiten palet (9 buiten / 10 uniek); semi-alpha (12 px)
- `assets/sprites/story/kist.png` — kleuren buiten palet (8 buiten / 9 uniek); semi-alpha (32 px)
- `assets/sprites/archief2/echo.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/archief2/echo_blauw.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/archief2/echo_groen.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/archief2/echo_oranje.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/archief2/echo_rood.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/archief2/echo_roze.png` — kleuren buiten palet (7 buiten / 23 uniek); semi-alpha (1032 px)
- `assets/sprites/woud/noor_cocon_open.png` — kleuren buiten palet (7 buiten / 7 uniek)
- `assets/sprites/story/schilderij.png` — kleuren buiten palet (6 buiten / 6 uniek)
- `assets/sprites/enemies/moonfang_wolf_96.png` — kleuren buiten palet (3 buiten / 15 uniek)
- `assets/sprites/enemies/moonfang_wolf_96_sheet.png` — kleuren buiten palet (3 buiten / 23 uniek)
- `assets/sprites/enemies/moonfang_wolf_96_sheet_left.png` — kleuren buiten palet (3 buiten / 23 uniek)
- `assets/sprites/binnen/huis_props/basket.png` — kleuren buiten palet (2 buiten / 11 uniek)
- `assets/sprites/binnen/huis_props/bookshelf.png` — kleuren buiten palet (2 buiten / 32 uniek)
- `assets/sprites/binnen/huis_props/bookshelf_b.png` — kleuren buiten palet (2 buiten / 36 uniek)
- `assets/sprites/binnen/huis_props/rug_bed_e.png` — kleuren buiten palet (2 buiten / 7 uniek)
- `assets/sprites/binnen/huis_props/rug_centre.png` — kleuren buiten palet (2 buiten / 5 uniek)
- `assets/sprites/enemies/cursed_knight_96.png` — kleuren buiten palet (1 buiten / 25 uniek)
- `assets/sprites/enemies/cursed_knight_96_sheet.png` — kleuren buiten palet (1 buiten / 33 uniek)
- `assets/sprites/enemies/cursed_knight_96_sheet_left.png` — kleuren buiten palet (1 buiten / 33 uniek)
- `assets/sprites/enemies/stone_gargoyle_96_sheet.png` — kleuren buiten palet (1 buiten / 18 uniek)
- `assets/sprites/enemies/stone_gargoyle_96_sheet_left.png` — kleuren buiten palet (1 buiten / 18 uniek)
- `assets/sprites/enemies/storm_harpy_96.png` — kleuren buiten palet (1 buiten / 26 uniek)
- `assets/sprites/enemies/storm_harpy_96_sheet.png` — kleuren buiten palet (1 buiten / 29 uniek)
- `assets/sprites/enemies/storm_harpy_96_sheet_left.png` — kleuren buiten palet (1 buiten / 29 uniek)

#### `assets/placeholder` (80)

- `assets/placeholder/woud/boom_den_kruin_boven_l.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_den_kruin_boven_r.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_den_kruin_midden_l.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_den_kruin_midden_r.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_den_voet_l.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/boom_den_voet_r.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/boom_eik_kruin_boven_l.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_eik_kruin_boven_r.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_eik_kruin_midden_l.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_eik_kruin_midden_r.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/boom_eik_voet_l.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/boom_eik_voet_r.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/brug_links.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/brug_midden.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/brug_rechts.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_a.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_b.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_blad_a.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_blad_b.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_c.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_d.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_schaduw_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/grond_schaduw_w.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/mist.png` — kleuren buiten palet (3 buiten / 3 uniek); semi-alpha (256 px)
- `assets/placeholder/woud/pad_binnen_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_binnen_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_binnen_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_binnen_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_m.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_m_b.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_o.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_w.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_z.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/pad_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/paddenstoel.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/paddenstoel_gloed.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_boven_links.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_boven_midden.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_boven_rechts.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_onder_links.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_onder_midden.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_stam_onder_rechts.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_binnen_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_binnen_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_binnen_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_binnen_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_m.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_o.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_w.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_z.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/rand_top_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/stam_liggend_l.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/stam_liggend_r.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/stapsteen.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/steen.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/stronk.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/struik.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/uitgang_pad.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/uitgang_rand_l.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/uitgang_rand_r.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/varen.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_m.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_binnen_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_binnen_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_binnen_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_binnen_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_no.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_nw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_o.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_w.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_z.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_zo.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/water_oever_zw.png` — kleuren buiten palet (3 buiten / 3 uniek)
- `assets/placeholder/woud/wegwijzer.png` — kleuren buiten palet (3 buiten / 3 uniek)

#### `assets/puzzle` (12)

- `assets/puzzle/kast_vast.png` — kleuren buiten palet (42 buiten / 43 uniek); semi-alpha (12 px)
- `assets/puzzle/kast_zwaar.png` — kleuren buiten palet (34 buiten / 35 uniek)
- `assets/puzzle/los_boek.png` — kleuren buiten palet (26 buiten / 27 uniek)
- `assets/puzzle/kast_duwbaar.png` — kleuren buiten palet (25 buiten / 27 uniek)
- `assets/puzzle/geheimkast_2hoog.png` — kleuren buiten palet (20 buiten / 20 uniek)
- `assets/puzzle/drukplaat_rune.png` — kleuren buiten palet (18 buiten / 20 uniek)
- `assets/puzzle/kernscheur.png` — kleuren buiten palet (18 buiten / 20 uniek)
- `assets/puzzle/hendel.png` — kleuren buiten palet (12 buiten / 15 uniek); semi-alpha (30 px)
- `assets/puzzle/groei_plaat.png` — kleuren buiten palet (11 buiten / 11 uniek)
- `assets/puzzle/poort.png` — kleuren buiten palet (9 buiten / 10 uniek); semi-alpha (5 px)
- `assets/puzzle/drukplaat.png` — kleuren buiten palet (7 buiten / 9 uniek); semi-alpha (4 px)
- `assets/puzzle/herstelsteen.png` — kleuren buiten palet (7 buiten / 9 uniek); semi-alpha (33 px)

#### `assets/tiles` (9)

- `assets/tiles/binnen.png` — kleuren buiten palet (73 buiten / 75 uniek)
- `assets/tiles/wereld_v14.png` — kleuren buiten palet (68 buiten / 70 uniek)
- `assets/tiles/wereld_v17_iconen.png` — kleuren buiten palet (51 buiten / 52 uniek)
- `assets/tiles/dungeon/berggrot_bibliotheek.png` — kleuren buiten palet (46 buiten / 48 uniek)
- `assets/tiles/huis.png` — kleuren buiten palet (40 buiten / 42 uniek)
- `assets/tiles/dungeon/berggrot_tiles.png` — kleuren buiten palet (33 buiten / 35 uniek)
- `assets/tiles/dungeon/kas_tiles.png` — kleuren buiten palet (9 buiten / 33 uniek)
- `assets/tiles/dungeon/kas_tiles_v8.png` — kleuren buiten palet (1 buiten / 37 uniek)
- `assets/tiles/dungeon/kas_tiles_v8b.png` — kleuren buiten palet (1 buiten / 37 uniek)

#### `assets/fx` (5)

- `assets/fx/inschrijf.png` — kleuren buiten palet (20 buiten / 22 uniek)
- `assets/fx/kern_absorptie.png` — kleuren buiten palet (6 buiten / 8 uniek)
- `assets/fx/kern_vuurbal.png` — kleuren buiten palet (6 buiten / 7 uniek)
- `assets/fx/kern_vuurbal_inslag.png` — kleuren buiten palet (6 buiten / 7 uniek); maat niet deelbaar door 16 (96×24)
- `assets/fx/kern_vuurbal_trail.png` — kleuren buiten palet (4 buiten / 4 uniek)

#### `assets/bg` (2)

- `assets/bg/spiegel_kamer_gebroken.png` — kleuren buiten palet (1826 buiten / 1826 uniek); maat niet deelbaar door 16 (384×216)
- `assets/bg/spiegel_kamer.png` — kleuren buiten palet (1523 buiten / 1523 uniek); maat niet deelbaar door 16 (384×216)

#### `assets/characters` (2)

- `assets/characters/wachter_liggend.png` — kleuren buiten palet (13 buiten / 13 uniek); semi-alpha (54 px)
- `assets/characters/wachter_knielend.png` — kleuren buiten palet (12 buiten / 12 uniek); semi-alpha (16 px); maat niet deelbaar door 16 (32×24)

#### `assets/hd2d` (1)

- `assets/hd2d/fx_data/light_soft_128.png` — kleuren buiten palet (238 buiten / 238 uniek); semi-alpha (11364 px)

#### `assets/map_monsters` (1)

- `assets/map_monsters/sporekop.png` — kleuren buiten palet (11 buiten / 11 uniek); semi-alpha (64 px)

### `docs/art/` — 1 PNG, paletschoon

- `docs/art/polish/r1/masterpalet.png` — maat niet deelbaar door 16 (72×192) (documentatie-preview van het palet, geen sprite)

## Wat er níet is gedaan

- Geen art gewijzigd.
- Tijdens de meting geen repo-bestand aangepast; alleen dit rapport is daarna als docs-PR toegevoegd.
- `wacht/wm2/` niet gelezen.

Ruwe logs en CSV’s: `/workspace/art_f22/run2/logs/` en `/workspace/art_f22/run2/out/` (inclusief `afwijkingen_alle.csv`, 643 rijen). Telefoon-samenvatting: `/workspace/art_f22/run2/f22_run2_samenvatting.png`.
