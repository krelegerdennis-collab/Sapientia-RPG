# Testdekking WM1 — GDScript zonder tests

Methode: alle `scripts/**/*.gd` (zonder `scripts/tests/` en `debug_*`) waarvan het pad, de bestandsnaam
of de `class_name` in geen enkele testsuite (`scripts/tests/*.gd`, `scripts/debug_*.gd`) voorkomt.
Scripts die alleen *indirect* geraakt worden (via een scène die een test laadt) tellen hier als ongetest:
er is geen test die hun gedrag zelf controleert. (Aantal regels tussen haakjes.)

## Nu gedekt (nieuwe suite `--wm1dekkingtest`, `scripts/tests/wm1_dekking_tests.gd`, 35 PASS)
| script | waarom gekozen |
|---|---|
| `scripts/data/dungeon100_reward.gd` (57) | Beloning op verdieping 100: schrijft in tas, `dungeon100_permanent/delivered`, Codex en equipment. Een fout kost de speler zijn eindbeloning of geeft dubbele items. Pure logica. |
| `scripts/core/atlas_zuinig.gd` (44) | Geheugenwinst (~8 MB Wilgendal) op elke kaart; telling en "één keer per TileSet" zijn makkelijk stuk te maken. Pure logica, in-memory te testen. |
| `scripts/battle/hd_ui.gd` (53) | Elk gevecht gebruikt het; cache (haperen op telefoon) en terugval (geen GPU) moeten kloppen. Klein en puur. |

## Nog ongetest
**Logica (hoogste prioriteit voor een volgende ronde)**
- `scripts/dungeon/dungeon100_puzzel.gd` (274) — puzzelkamer in de Diepe Grot, latch na save/laden; testbaar via `create()` + `request_*`.
- `scripts/dungeon/dungeon100_koopman.gd` (129) — koopman in Dungeon100 (de koopmantest raakt de data, niet dit script).
- `scripts/som/som_codex.gd` (180) — vangkans/vangen in SOM-modus; `chance_for`/`hint` zijn goed los te testen.
- `scripts/som/som_ally.gd` (210) — bondgenoot-AI in SOM.
- `scripts/battle/codex_battle.gd` (500) — vangen in gevechten; groot, vooral indirect gedekt via codextest.
- `scripts/story.gd` (657) — verhaalvlaggen/dialoog-autoload; wel indirect overal gebruikt, geen eigen suite.
- `scripts/audio_manager.gd` (798) — moet werken zonder geluidsbestanden; een rooktest "geen crash zonder audio" is goedkoop.
- `scripts/puzzle/puzzle_room.gd` (637) — indirect gedekt door puzzletest (scènes), niet direct.
- `scripts/puzzle/push_block.gd`, `pressure_plate.gd`, `lever.gd`, `grow_plate.gd`, `reset_stone.gd`, `secret_door.gd`, `treasure_chest.gd`, `book_switch.gd` — puzzelstukken, indirect via puzzletest.
- `scripts/puzzle/hooks/ph_runeplaat.gd`, `ph_schatkist.gd`, `ph_geheime_deur.gd` — puzzel-hooks.
- `scripts/transition.gd` (59) — scènewissel-autoload; indirect overal.

**Kaart/wereld (scène-gebonden, lager)**
- `scripts/npc.gd` (137), `scripts/story_object.gd` (145), `scripts/door.gd` (38), `scripts/sign.gd` (8), `scripts/map_spawn.gd` (13)
- `scripts/huis_wilgendal.gd` (127), `scripts/village/hek_poort.gd`, `v8_grond.gd`, `uithangbord.gd`
- `scripts/dungeon/dungeon_prop.gd`, `dungeon_sign.gd`, `woud_beek_kamer.gd`, `woud_mist.gd`

**UI/visueel (lager; beter met screenshots/menutest)**
- `scripts/dialog_box.gd` (605) — veel logica (paginering, keuzes); kandidaat voor een eigen suite.
- `scripts/ui/name_entry.gd` (143) — naamvalidatie zit in `GameState.clean_name` (wel getest).
- `scripts/ui/magic_screen.gd`, `ui_menu.gd`, `target_list.gd`, `party_card.gd`, `title_tab.gd`, `werkplaats_scherm.gd`, `blink_arrow.gd`
- `scripts/battle/hero_status_box.gd`, `battle_hero.gd`, `boss_core_view.gd`, `target_cursor.gd`, `cross_button.gd`
- `scripts/ui/crt_overlay.gd`, `glitch_noise.gd`, `title_glitch.gd` — puur visueel.
