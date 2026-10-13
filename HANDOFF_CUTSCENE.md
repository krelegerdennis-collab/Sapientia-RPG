# HANDOFF — Wereldkaart-cutscene + moswezens in de tuin van opa (branch `rpgcode/worldmap-cutscene`)

## Wat
1. **Eenmalige cutscene** bij de eerste keer op de wereldkaart: Dennis in het woud bij de moswezens
   (bron-mp4 720x1280, 15 s) → `assets/video/worldmap_intro.ogv` (Theora+Vorbis, 360x640, 24 fps, ~2,8 MB).
   Portret gecentreerd in het liggende beeld, links/rechts donkere glitch-panelen (placeholder in code).
   Tik / klik / `interact` / `ui_accept` slaat over (0,4 s grace). Vangnet: na 20 s altijd klaar (geen soft-lock,
   ook als de browser niets afspeelt). Speler-input weer vrij (alleen als er geen verhaal/dialoog/mapwissel loopt),
   map-muziek start opnieuw via `map._play_map_music()`. Video-audio op bus `Music` als die bestaat.
2. **Tuin van opa** (`scenes/maps/wilgendal.tscn`, "House at the Wood's Edge"): moslijm + moskonijn spelen
   samen (rondje om elkaar met de speel-sprong) bij (312,184). Loopt Dennis zuidelijker dan y=232 (richting
   uitgang `Exits/NaarWereld`, y=336), dan volgen ze zijn spoor (16 px / 32 px achter hem) tot de uitgang.
   Geen botsing, puur decor. Spawnt via `map.gd::_spawn_garden_creatures()` (geen .tscn-wijziging).

## Bestanden
- nieuw `scripts/worldmap_cutscene.gd` (class_name WorldmapCutscene)
- nieuw `scripts/village/garden_creatures.gd`
- nieuw `scripts/tests/worldmap_cutscene_tests.gd` (suite `--cutscenetest`, 34 PASS)
- nieuw `assets/video/worldmap_intro.ogv`
- nieuw `art/map_creatures/{mosslijm,moskonijn}_{volg,speel}.png` (+ .import) — RPG ART batch 14 (v0.21)
- `scripts/map.gd` (preloads, cutscene-start na `_play_map_music()`, tuin-spawn)
- `scripts/game_state.gd` (suite-registratie) (`.github/workflows/tests.yml` NIET aangepast: token mist workflow-scope → RPG Forge: `cutscenetest` aan de matrix toevoegen)
- `tools/placeholders_v17.txt` (glitch-paneel placeholder), `tools/handwerk.txt` (4 batch-14 sheets)

## Vlaggen
- `cutscene_wereldkaart_gezien` in `GameState.story_flags` — gezet bij START van de cutscene (vóór de
  autosave van 0,35 s), gaat mee in save/load; daarna nooit meer afspelen.
- `WorldmapCutscene.allow_in_tests` (static): tijdens `--*test`-runs speelt de cutscene NIET, behalve als een
  tester dit aanzet (zo blijven de bestaande suites ongemoeid).

## Tijdelijke aannames
- Vlag gaat aan bij start, dus wie de app tijdens het filmpje sluit ziet hem niet opnieuw.
- Ook bestaande saves die al voorbij de wereldkaart zijn, krijgen het filmpje één keer bij hun volgende bezoek
  (geen migratie op story_step). Zeg het als dat anders moet.
- Moswezens staan altijd in de tuin (geen story-voorwaarde), en blijven achter bij de uitgang (gaan niet mee
  naar de wereldkaart). Speelplek/trigger-Y zijn constants bovenin garden_creatures.gd.
- Web: video-autoplay met geluid kan geblokkeerd zijn tot de eerste gebruikersactie; de speler heeft dan al
  gelopen, en anders vangt de 20 s-timer het op. `export_presets.cfg` niet aangeraakt: de 4.3 `--export-pack Web`
  bevat de .ogv al (all_resources). Niet live in een browser getest.

## Art drop-in (RPG ART)
- `art/map_creatures/<id>_volg.png` 64x96: 16x24 frames, rijen omlaag/links/rechts/omhoog, 4 frames per rij. **Geleverd (batch 14).**
- `art/map_creatures/<id>_speel.png` 96x24: 6 sprong-frames 16x24 horizontaal (code leest #frames = breedte/16). **Geleverd.**
  `<id>` = `mosslijm`, `moskonijn`. Voeten onderaan (sprite-offset y=-4). Ontbreekt een sheet → fallback
  `assets/map_monsters/<id>.png` (16x16, 2x4).
- **Nog nodig:** `art/cutscene/glitch_panel.png` ~96x216 (linkerpaneel; rechts = gespiegeld, uitgerekt tot de
  randbreedte). Neerzetten = klaar, geen code nodig (`WorldmapCutscene.PANEL_TEXTURE`).

## Tests
`--import` met 4.7.2, daarna alle 28 suites (27 bestaand + cutscenetest), 6 parallel; 4.3 in een aparte kopie
(`/workspace/code_cutscene/repo43`, eigen import), 4 parallel.
- 4.7.2: 25/28 groen in parallel; puzzletest, kernkrachttest, dungeon100gentest faalden onder parallelle
  belasting en zijn serieel opnieuw gedraaid: 156 / 116 / 59 PASS, 0 FAIL.
- 4.3: 26/28 groen in parallel; puzzletest, dungeon100gentest serieel opnieuw: 156 / 59 PASS, 0 FAIL.
- cutscenetest: 34 PASS op beide versies.
Logs: `/workspace/code_cutscene/logs/{t472,t472_rerun,t43,t43_rerun}`, samenvattingen `summary_472.txt`, `summary_43.txt`.
De .import/.uid-churn van de 4.7.2-import is teruggedraaid/verwijderd; alleen .import voor de nieuwe PNG's (4.3-formaat).

## Screenshots
`/workspace/code_cutscene/shots/cutscene_panels.png`, `garden_creatures.png`, `garden_following.png` (+ `ogv_frame_check.png`).
