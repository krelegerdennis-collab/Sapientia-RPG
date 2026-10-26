# WM1-namenaudit (spelertekst)

Bron: de goedgekeurde mapping (Dennis, Engels voor de speler; ids, bestandsnamen, node-namen en docs blijven Nederlands). Canon: `docs/lore/CANON.md`.

Alleen Worldmap 1. Niets uit `wacht/`, niets van WM2, niets van De Spiegel (Archief 4). Geen ids, bestanden of sprites hernoemd.

## Gewijzigd

| Bestand | Was (speler) | Is (speler) | Id / node blijft |
|---|---|---|---|
| `scripts/data/story_data.gd` `QUESTS` | Het Zingende Graan | The Singing Grain | `zingend_graan` |
| `scripts/data/story_data.gd` `QUOTE_GRAAN_OP` | In the Dark Forest | In the Dark Wood | — |
| `scripts/data/story_data.gd` keten-zin | Archief 1 … Archief 2 … | The First Archive … The Second Archive … | — |
| `data/quests.json` zijquest | Dark Forest | Dark Wood | titel was al The Singing Grain |
| `scripts/data/archief2.gd` `KETEN` | dezelfde Archief-zin | The First Archive / The Second Archive | — |
| `scripts/data/archief2.gd` `GEEN_CODEX` | Een Mosslijm vecht tijdelijk mee. | A Moss Slime fights alongside you for this battle. | soort `mosslijm` |
| `scripts/data/archief2.gd` tijdelijke pagina | Mosslijm | Moss Slime | `mosslijm` |
| `scripts/data/archief2_rooms.gd` bord | dezelfde Archief-zin | The First Archive / The Second Archive | — |
| `scripts/data/archief2_rooms.gd` bord | Een groei-plaat. Stap erop. | A growth plate. Step on it. | — |
| `scripts/data/archief2_rooms.gd` kamernaam | Groei-plaat | Growth Plate | scène-id `archief_2_v1_plaat` |
| `scripts/data/archief2_rooms.gd` kamernaam | Kasgang | Greenhouse Passage | `archief_2_v2_gang` |
| `scripts/data/archief2_rooms.gd` kamernaam | Seren | Seren's Room | heldnaam Seren ongewijzigd |
| `scripts/data/archief2_rooms.gd` kamernaam | Ketting-platen | Chain Plates | `archief_2_v3_ketting` |
| `scripts/data/archief2_rooms.gd` kamernaam | Tegen-platen | Counter Plates | `archief_2_v3_tegen` |
| `scripts/data/archief2_rooms.gd` kamernaam | Licht-platen | Light Plates | `archief_2_v3_licht` |
| `scripts/dungeon/groei_plaat.gd` | Alleen Seren's licht laat deze plaat groeien. | This plate only grows in Seren's light. | — |
| `scripts/dungeon/archief2_room.gd` | %s vecht mee. | %s fights alongside you. | — |
| `scripts/dungeon/archief2_room.gd` | Welk Codex-monster vecht mee? | Which Codex monster fights alongside you? | — |
| `scripts/dungeon/archief2_warp.gd` | ECHO: Waarheen? / Opslaan, Wilgendal, Archief-ingang, Andere eilanden | ECHO: Where to? / Save, Willowdale, Archive entrance, Other islands | keuze-index 0–3 |
| `scripts/data/kern_data.gd` | Levenskern | Life Core | `levenskern` |
| `scripts/data/game_data.gd` `EQUIP_SLOT_NAMES` | Benen / Laarzen | Legs / Boots | slot-ids `benen`, `laarzen` |
| `scripts/data/game_data.gd` `ELEMENT_NAMES` | (ontbrak: ruwe id) | ice / physical / sword | ids `ijs`, `fysiek`, `zwaard` |
| `data/music_tracks.json` `where` | Cave / tunnel | Hollow Mountain | track-id `berggrot` |
| `data/music_tracks.json` `where` | Archive 2 | The Living Archive | `levend_archief` |
| `data/music_tracks.json` `where` | Archive 2 boss | The Mender | `baas_archief2` |
| `data/music_tracks.json` `where` | DLS | Deep Learning Simulation | `diepe_grot` |
| `scripts/data/echo_grot.gd` `ZIN_WERELD` | ECHO's Room | ECHO's Chamber | — |
| `world_warper/guide/dialoog.gd` | ECHO's Room | ECHO's Chamber | — |
| `world_warper/services/party_select.gd` | Niemand in het gezelschap. | Nobody in the party. | — |
| `world_warper/services/party_select.gd` knop | Sluiten | Close | node `Sluiten` |
| `world_warper/services/party_view_test.gd` | Onbekend / Naam, niveau N | Unknown / Naam, Lv N | — |
| `world_warper/kamers/echo_kisten.gd` labels | Uitrusting / Accessoire | Equipment / Accessory | sleutels `uitrusting`, `accessoire` |
| `world_warper/kamers/party_wissel.gd` | Rustkamer — wisselen is gratis | The Rest Room — switching is free | — |
| `world_warper/kamers/party_wissel.gd` | Actief / Bank | Active / Bench | — |
| `world_warper/kamers/party_wissel.gd` knoppen | (blijft) / (gast) / → bank / → groep | (stays) / (guest) / → bench / → party | — |

De keten-zin staat op drie plekken hetzelfde (dialoog, bord, `KETEN`).

`Life Core` staat niet in de mappingtabel. Het volgt het patroon van `Golem Core`: de id `levenskern` blijft, alleen de naam op het statusscherm en in de absorptieregel.

Elementnamen `ice` / `physical` / `sword` zijn alleen weergave. Het bestiarium toonde anders de ruwe ids bij The Strangler en The Mender.

## Verwachte spelertekst in bestaande suites

Geen nieuwe tests, geen suite-lijst, geen workflow. Alleen de letterlijke verwachting van de nieuwe spelertekst:

- `scripts/tests/woud_tests.gd`: questtitel The Singing Grain (drie asserts).
- `scripts/tests/archief2_tests.gd`: weergavenaam Moss Slime (drie asserts). De check-tekst blijft Nederlands.
- `world_warper/tests/run.gd`: "Mira, Lv 4", "Unknown, Lv 1", "Unknown, Lv 3", "Bo, Lv 2".
- `scripts/debug_menutest.gd`: vaknamen Legs en Boots.

## Gecontroleerd, al Engels (niet opnieuw gezet)

- `map_name` en `npc_name` op de WM1-scènes: Willowdale, Shop, Mapleton, Dark Wood-kamers, Forgotten Archives, Hollow Mountain, The Living Archive en subkamers, World Warper-kamers, Deep Learning Simulation.
- NPC's: Garrett the Miller, Bramwell, Elsie, Fern, Walt, Simon, Marigold, Jensen, Tobias, Elise, Foreman Henrik, Sunny, George, Fay, Aunt Minna, Jack Hammond, Old Man, the Merchant.
- Items, spreuken, baasnamen (The Mender, The Strangler, The Shadow of H-6, The Cycle, The Judge, The Voice), veldmenu (Equipment, Items, Party, Quest Log, Back), gevechtscommando's, opslaan (`Save here?` / `Overwrite?` in `scripts/ui/save_screen.gd`).
- Questlog-titels in `data/quests.json` behalve de Dark Forest-zin hierboven.
- Muziektitels (`name`) in `data/music_tracks.json`.

"the forest" in Garretts andere zinnen blijft: dat is het gewone woord, niet de plaatsnaam Dark Wood.

## Buiten scope, bewust laten staan

- PvP (`pvp/data/modes.gd`: Vroeg / Midden / Hoog; `pvp/data/teams.gd`: "Hoog risico, hoge schade."). Geen WM1. `pvp/tests/pvp_tests.gd` drukt op "Vroeg".
- De Spiegel / Archief 4 (`scripts/data/spiegel_data.gd`, `scripts/spiegel/`). Alleen via `--spiegel`, on hold.
- `wacht/` niet gelezen en niet gewijzigd.
- Node- en sleutelnamen: Cocon, CoconOpen, Woudgeesten, Gerrit, Gezelschap, Sluiten, Opslaan, Beeldkamer. Het hub-vlak toont al "Party" via een lookup op de id `Gezelschap`.
- `assets/audio/audio_manifest.json` (`titel`, `beschrijving`): niet op het scherm. De speler ziet `data/music_tracks.json`.
- Docs, commentaar, lore-JSON, `push_warning`-teksten.
- `tools/build_maps.gd` zet geen Nederlandse `npc_name` meer in de generator die de live scènes voedt (Old Man, Vesper).
