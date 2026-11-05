# FINISH_LOG — WM1 naar 9/10 (branch `finish/wm1`)

Opdracht Dennis, 5 nov 2026: "maak de game af tot een 9/10; lore en tekst mogen uitgebreid, art mag aangepast
binnen de regels, core gameplay blijft; werk in rondes op een aparte branch." Akkoord: `TODO(verhaal)`-stubs
in WM1 mag de agent zelf invullen zolang de canon-kern (CANON 1-18) staat. Geparkeerde scènes (ECHO's twist,
WM2/WM3, De Spiegel) blijven dicht.

Elke ronde: audit → fixes → alle suites groen (CI) → webbuild → Dennis speelt en geeft cijfers.
`main` blijft onaangeraakt tot Dennis zegt mergen.

## Scorekaart

Cijfers 0-10. "Nu" = inschatting van de agent op `main` 0b30e5f (5 nov). "Dennis" vult hij in na de webbuild.

| # | Onderdeel | Nu | Dennis | Wat het cijfer drukt |
|---:|---|---:|---:|---|
| 1 | Verhaal en dialoog WM1 | 7 | | Proloog en Esdoorn goed; ECHO-hub flat; vulzinnen bij NPC's; respawn-placeholder |
| 2 | Lore-consistentie (CANON) | 8 | | Namen en vlaggen kloppen; weinig lore buiten de hoofdroute (grot-briefjes 8, bazen zonder tekst) |
| 3 | Quest-flow en questlog | 8 | | Werkt; act 3-6 "later" is correct voor WM1 |
| 4 | Items, uitrusting, bestiarium (tekst) | 6 | | 24x "Loot from the depths", 8 bazen zonder beschrijving, Wood Wraith één zin |
| 5 | UI/UX op touch | 7 | | Edge-case-rapporten r7-3 open; onboarding Action-modus |
| 6 | Audio | 3 | | 99 sfx placeholders, 11 bgm-tracks ontbreken |
| 7 | Art-consistentie (palet) | 7 | | PLAN fase 1-2 placeholders in de route |
| 8 | Balans | 7 | | Sims bestaan; recente room_rules-wijzigingen nog niet opnieuw gemeten |
| 9 | Stabiliteit en saves | 8 | | savefuzz + saverobust groen; Android lifecycle-doc open punten |
| 10 | Performance S25 | 7 | | perf-rapport bestaat; geen meting op de freeze-commit |

## R1 — tekst en lore (5 nov 2026)

Gedaan (alleen data en tekst, geen scènes, geen gameplay):
- `scripts/data/game_data.gd`: 24 unieke beschrijvingen voor de Diepe Grot-uitrusting (Archive/Rune/Glitch/Seal, per slot
  een eigen beeld); Wood Wraith uitgeschreven.
- `scripts/data/dungeon100_scaling.gd` + `endgame_bestiary.gd`: bestiarium-tekst voor de 8 niet-canon bazen
  (10, 20, 30, 40, 60, 70, 80, 90) in dezelfde stem als de canon-citaten; canon-citaten ongewijzigd.
- `scripts/data/grot_kamers.gd`: lege-kamer-briefjes van 8 naar 20 (geen ECHO/H-6-onthulling, conform besluit 14 okt).
- `scripts/game_state.gd`: respawn-tekst definitief ("The Current pulls you back...", `TODO(verhaal)` weg).
- `world_warper/guide/dialoog.gd`: ECHO's hub-regels herschreven in zijn stem (droog, moe, beschadigd geheugen);
  sleutelwoorden die `dialoog_test.gd` eist blijven staan.
- `scripts/data/story_data.gd`: Marigold en Vesper vulzinnen uitgebreid; verouderde `TODO(verhaal)`-commentaren
  bijgewerkt (de tekst was al Engels en bruikbaar). `TODO_STORY` blijft staan (woud_tests leest hem).

Niet gedaan, bewust: de Core-zin "The story of H-6 ends here." (H3-stub, dicht), canon-scènes 1-3 en de
opening (canon 17/18), het Zingende Graan (canon-dialoog).

Verwacht effect: #1 7→8, #2 8→9, #4 6→8.

Open voor R1b (als Dennis meer tekst wil): Codex-vaardigheidsteksten, winkeliers-dialoog Wilgendal, ECHO-grot-hints per
puzzel, Koopman fase 1 (bezoek 1-3) variatie.

### R1b (5 nov, PR #362)
- `scripts/data/wilgendal_dorp.gd`: pantser-, accessoire- en magiewinkel kregen namen (Mara Hammond, Pell, Ysolde; de
  pantsersmid heette dubbel Jack Hammond) en elke winkelier en sfeer-NPC een tweede zin in dezelfde stem.

## R2 — audio
- BGM: de 11 ontbrekende tracks uit het manifest (industriestad, eindbaas, rustplek, overwinning, game_over, ...) worden
  nergens in WM1-code aangeroepen; geen stille kaart. Stap 4 van LAUNCH_PLAN is daarmee klaar zonder wijziging.
- SFX: wacht op de eerste run van `tools/sfx/gen_sfx.py` op de laptop (ComfyUI, Stable Audio Open).

## R3 — art-polish (binnen regels)
- Audit (5 nov, ONVERIFIED palet): met `Art/claude-trial/goblin_raider/sap75.gpl` van de laptop (75 kleuren) zijn 239 van
  1175 PNG's buiten palet, maar ook `assets/tiles/dorp.png` (RPG ART v8, 118 kleuren). Dat palet is dus waarschijnlijk
  niet het masterpalet. Blocker fase 2: het masterpalet-bestand in de repo zetten (`docs/release/WM1_RELEASE_CHECKLIST.md`).
- Grootste afwijkers (zonder placeholders): `bg/spiegel_kamer*.png` (1500+ kleuren, WM2-content, niet in de route),
  `tiles/dungeon/dungeon_tiles.png` (234), `puzzle/geheime_deur_archief.png` (201), `sprites/archief2/genezer*.png` (102).

## R4 — UX en bugs (5 nov, PR #361)
- `EDGECASES_ITEMS_STATUS.md`: 18 van 19 punten bleken al gefixt (r8-3); #8 (KO door gif/brand niet gemeld) gefixt in
  `battle.gd` (`_report_kos` na de status-ticks).
- `WM1_BUGJACHT.md` O-1 was al gefixt (`enemies.has(m)`); O-5 gedaan: 23 geregistreerde suites in de CI-matrix
  (79 → 102). Buiten de matrix gelaten: perf/benchmark-suites, relaytest (Node), wm1playthroughtest (lang).
- Tests bijgewerkt: `savehardeningtest` (drift-vlag van de opening), `sessiefixtest` (RESULT-regel), checkpoint/autotest/
  updatetest (R1-tekst).

## R5 — balans en perf
- `wm1balanstest` en `balansarchief1test` groen op de huidige room_rules.
- `wm1budgettest` (headless draw-calls, niet in de matrix): 7 kamers boven het budget van de vorige meting, vooral
  `archief_2_v1_entree` (draw_avg 83 vs 52.8) en `archief_bibliotheek` (164 vs 140). ONVERIFIED of dit de walk5-sheets of
  de 1.4x-kas is; meten op de S25 (fase 4) beslist. Geen actie in code.

## Launch-docs
- `docs/release/STORE_LISTING.md`: concept store-teksten (EN, spoilervrij), benodigde graphics, privacy/data-safety-regels,
  voorstel pakketnaam `com.eazydstudio.sapientia` (BESLIS Dennis).
