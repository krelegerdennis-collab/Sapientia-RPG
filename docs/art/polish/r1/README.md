# Art-polish ronde 1 — masterpalet (5 nov 2026)

Geen art gewijzigd in deze ronde: er is geen voor/na. Wel de nulmeting waar ronde 2-4 tegen meten.

- Paletkaart: `masterpalet.png` (één rij per ramp, 12 px per kleur). Gemaakt met
  `python3 tools/art_audit/maak_gpl.py --png docs/art/polish/r1/masterpalet.png`.
- Masterpalet: `docs/art/masterpalet.gpl`, 73 kleuren / 16 ramps, gegenereerd uit
  `tools/som/sapientia_palette.json` (enige bron, ook gebruikt door `tools/som/export_tilesets.py`).
- Volledige meting: `palet_meting.txt` (`python3 tools/art_audit/palet_check.py --top 0`).

## Nulmeting (`assets/`, 1175 PNG's)

| | |
|---|---|
| schoon (0 kleuren buiten palet) | 818 |
| met kleuren buiten het palet | 357 |
| pixels op palet | 95,6% |

Afwijkers per map (aantal bestanden):

| map | bestanden |
|---|---:|
| `assets/ui/icons` | 122 |
| `assets/placeholder/woud` | 84 (ronde 4) |
| `assets/sprites/archief2` | 21 |
| `assets/sprites/buiten` | 19 |
| `assets/sprites/som` | 15 (alle `som/monsters`) |
| `assets/sprites/enemies` | 11 |
| `assets/sprites/hub` | 10 |
| `assets/tiles/dungeon` | 8 |

Grootste afwijkers: `bg/spiegel_kamer*.png` (1500+, WM2), `tiles/dungeon/dungeon_tiles.png` (234),
`puzzle/geheime_deur_archief.png` (201), `tiles/dorp.png` (116), `sprites/archief2/genezer*.png` (~100).

FX-ramps zitten al in het palet (geen nieuwe kleuren): vuur = Red/Danger, bliksem = Gold + Blue,
heal = Mint + Teal, arcane = Glitch Purple, glitch = Glitch Magenta + cyaan `40e0e8`/`c8f4ff`.
Alle 12 FX-sheets in `assets/sprites/som/fx` zijn schoon.

## Uit `tools/handwerk.txt` gehaald (54 regels, bestand bestaat niet)

Alleen regels waarvan het pad niet bestaat; geen art-bestand aangeraakt.

```
world_warper/art/echo_placeholder.png
world_warper/art/echo_placeholder_blauw.png
world_warper/art/echo_placeholder_groen.png
world_warper/art/echo_placeholder_oranje.png
world_warper/art/echo_placeholder_rood.png
world_warper/art/echo_placeholder_roze.png
world_warper/art/party_placeholder.png
world_warper/art/party_placeholder_blauw.png
world_warper/art/party_placeholder_groen.png
world_warper/art/party_placeholder_oranje.png
world_warper/art/party_placeholder_rood.png
world_warper/art/party_placeholder_roze.png
world_warper/art/pc_placeholder.png
world_warper/art/pc_placeholder_blauw.png
world_warper/art/pc_placeholder_groen.png
world_warper/art/pc_placeholder_oranje.png
world_warper/art/pc_placeholder_rood.png
world_warper/art/pc_placeholder_roze.png
world_warper/art/tafel_placeholder.png
world_warper/art/tafel_placeholder_blauw.png
world_warper/art/tafel_placeholder_groen.png
world_warper/art/tafel_placeholder_oranje.png
world_warper/art/tafel_placeholder_rood.png
world_warper/art/tafel_placeholder_roze.png
world_warper/art/tiles_placeholder.png
world_warper/art/tiles_placeholder_blauw.png
world_warper/art/tiles_placeholder_groen.png
world_warper/art/tiles_placeholder_oranje.png
world_warper/art/tiles_placeholder_rood.png
world_warper/art/tiles_placeholder_roze.png
world_warper/art/toonbank_placeholder.png
world_warper/art/toonbank_placeholder_blauw.png
world_warper/art/toonbank_placeholder_groen.png
world_warper/art/toonbank_placeholder_oranje.png
world_warper/art/toonbank_placeholder_rood.png
world_warper/art/toonbank_placeholder_roze.png
assets/sprites/som/test/dax_24x32_v3.png
assets/sprites/som/kaart/dax.png
assets/sprites/som/kaart/seren.png
assets/sprites/som/kaart/dax_wm2.png
assets/sprites/som/kaart/seren_wm2.png
assets/sprites/buiten/wilgendal/plein10/kei_base.png
assets/sprites/buiten/wilgendal/plein10/kei_cracked.png
assets/sprites/buiten/wilgendal/plein10/kei_hoek_no.png
assets/sprites/buiten/wilgendal/plein10/kei_hoek_nw.png
assets/sprites/buiten/wilgendal/plein10/kei_hoek_zo.png
assets/sprites/buiten/wilgendal/plein10/kei_hoek_zw.png
assets/sprites/buiten/wilgendal/plein10/kei_mix.png
assets/sprites/buiten/wilgendal/plein10/kei_mossy.png
assets/sprites/buiten/wilgendal/plein10/kei_rand_n.png
assets/sprites/buiten/wilgendal/plein10/kei_rand_o.png
assets/sprites/buiten/wilgendal/plein10/kei_rand_w.png
assets/sprites/buiten/wilgendal/plein10/kei_rand_z.png
assets/sprites/buiten/wilgendal/plein10/kei_worn.png
```
