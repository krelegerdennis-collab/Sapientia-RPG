# docs/lore: VOORSTELMATERIAAL, geen canon

> **v0.18: zie eerst `CANON.md`** (beslissingen van Dennis; gaan boven alles in deze map).
> `BOTSINGEN.md` = de lijst met botsingen waar die beslissingen op antwoorden.

> **v0.17 is canon.** Alles in deze map is voorstel/inspiratie. Bij twijfel geldt wat er in
> de game staat (`scripts/data/*.gd`, `README.md`, `docs/HANDOFF_*.md`) en in
> `/workspace/story/PROLOOG.md` + `ACT1_LORE.md`. Zie `/workspace/merge_staging/BOTSINGEN.md`
> voor de lijst met botsingen.

Bron: `Sapientia-worldbuilder` (main, commit e69b273), AI-gegenereerd (Cursor Agent, 4 okt 2026).

| Bestand | Inhoud |
|---|---|
| `WORLDBUILDER_README.md` | originele README van de repo (hernoemd om botsing met deze README te voorkomen): conventies, balans, canon-register |
| `Lore_basis.md` | Act 1 + de Zes Archieven (bijna gelijk aan ACT1_LORE.md, MAAR: hier kent de Oude Man Noor en Lotte wel) |
| `Wereld_Geografie.md`, `Locaties_Dorpen.md` | wereld Mnemora, regio's, dorpen (Hazelbrug, Ruigveen, Slakkenburg...) |
| `Personages_Dossiers.md` | Dennis, Ewout Valk, Noor/Lotte Zeldenrust, Wachters, NPC's |
| `Verhaal_Act2_tot_6.md`, `Dialoog_Samples.md` | verhaal Act 2-6, voorbeelddialogen |
| `data/items.json`, `data/npcs.json`, `data/enemies.json` | 30 items, 32 NPC's, 20 vijanden + 6 bazen |

**De JSON is niet laadbaar in de game:** andere statnamen (`aanval/verdediging/magie/
magische_verdediging/snelheid` vs `atk/def/mag/mdef/agi`), andere levelschaal (1-40, Archief 1 =
L1-5) en een eigen schadeformule. Overnemen = met de hand of via een converter naar
`scripts/data/game_data.gd`, daarna herbalanceren.
`docs/*` en `*.md` staan in `exclude_filter`, dus niets hiervan komt in de APK.
