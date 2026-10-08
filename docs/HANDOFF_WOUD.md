# Overdracht v0.17: Esdoorn, Noor en het Donker Woud

## Verloop voor de speler
1. Na de Golem (`bewaker:archief_golemhal/golem`) gaat Esdoorn open op de wereldkaart (exit `NaarEsdoorn`, event `naar_esdoorn`).
2. Bij binnenkomst draait één keer `noor_ontmoeting` (MAP_ENTER, flag `noor_ontmoet`). Wortels grijpen Noor (object `WortelGreep`), en Marit start de opdracht (`quest_noor`, stap `NOOR_KWIJT` = 110). Het veldmenu toont "Opdracht: Red Noor uit het Donker Woud".
3. Wereldkaart, exit `NaarWoud` (event `woud_ingang`; zonder `quest_noor` staat er alleen een hint). De volgorde is woud_rand → woud_pad → woud_mistpoel → woud_sporenkring (savepunt) → woud_open_plek.
4. Op de cocon staat de Wortelkoning als bewaker (2x2 tegels). Na winst draait `noor_bevrijd` (MAP_ENTER op `woud_open_plek` met de Wortelkoning-flag en zonder `noor_gered`). Noor komt erbij via `join` (niveau Dennis-1, eiken_staf + reisgewaad), daarna flags `noor_gered` en `noor_lid` en stap `NOOR_GERED` = 120.

## Waar staat wat
| Wat | Bestand |
|---|---|
| Woudkamers, layouts, kisten, monsters, bomen/mist/overlay, cocon + Noor-NPC | `scripts/data/woud_rooms.gd` (los van `dungeon_rooms.gd`, dus de archief-tests blijven gelijk) |
| Thema `donker_woud`, `is_solid`/`is_no_monster`/`single_atlas`/`terrain_of`, `room()`, glitch per dungeon (`GLITCH_DUNGEONS`) | `scripts/data/dungeon_rooms.gd` |
| Overlay-laag (z 10), tint, mist, `objects`/`npcs` in kamers | `scripts/dungeon/dungeon_room.gd`, `scripts/dungeon/woud_mist.gd` |
| Events, QUESTS, TODO_STORY, stappen 110/120 | `scripts/data/story_data.gd` (sectie "v0.17 ESDOORN + DONKER WOUD") |
| Story-commando's `join`/`glitch`/`heal`, `{naam}`, `active_quest()` | `scripts/story.gd` |
| `join_member`, `member_level` | `scripts/game_state.gd` |
| Opdracht in het veldmenu | `scripts/ui/field_menu.gd` (`quest_label`) |
| Vijanden (beschrijvingen uit LEESMIJ, zwak voor vuur, `sprite_back`, idle/hit) en backdrop `forest_dark` | `scripts/data/game_data.gd` |
| Esdoorn + interieurs + wereldkaart | `tools/build_maps.gd` (`--only=v17`) |
| Test | `scripts/tests/woud_tests.gd` (`--woudtest`, delen A-E) |

## Codex (v0.17 samengevoegd, patch RPG CODE, zie `HANDOFF_CODEX.md`)
- Lege Boeken: NIET in `START_INVENTORY`. Event `marit_boeken` (story_data.gd): 3 stuks aan het eind van
  `noor_ontmoeting`, of bij een gesprek met Marit als de ontmoeting al gezien is (oude save). Kisten
  `kist_w4` (Woudpad, 30,4) en `kist_w5` (Sporenkring, 17,4): elk 1.
- Bondgenoot doet ook mee in baasgevechten; MP-kosten zoals RPG CODE (0). Moskonijn/Mech. Wachter: geen
  rugaanzicht (plaatsvervanger in code).
- `--woudtest` deel F: woudmonster vangen, bondgenoot in het woud, Codex-scherm, wereldkaart-iconen.

## Open punten
- **Verhaaltekst**: alles in `SD.TODO_STORY` is placeholder met `TODO(verhaal)`.
- **Placeholders (art)**: geen meer in v0.17 (map-sprites en wereldkaart-iconen zijn van RPG ART).
  Nog zonder eigen art: rugaanzicht Moskonijn en Mech. Wachter.
- **Wortelkoning**: hartrect `[88,98,24,40]` is genoteerd, maar er is nog geen kern-mechaniek.
- **Wilgendal** blijft "komt later".
- Noor blijft brunette (bevestigd).
