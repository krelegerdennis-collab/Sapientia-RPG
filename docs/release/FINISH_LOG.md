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

## R2 — audio
Wacht op de eerste run van `tools/sfx/gen_sfx.py` op de laptop (ComfyUI). Daarna: bgm-manifest snoeien.

## R3 — art-polish (binnen regels)
## R4 — UX en bugs
## R5 — balans en perf
