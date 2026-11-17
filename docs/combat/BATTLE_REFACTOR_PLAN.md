# Plan: refactor-blok battle.gd (fase 1, vanaf ma 24-11-2026)

Auteur: RPG COMBAT · stand: finish/wm1 @ `39204468` (16-11-2026), bijgewerkt op `9a87280` (17-11-2026) · alleen een plan, geen code.

Labels: **FEIT** = nagekeken in de repo op `39204468` en opnieuw op `9a87280` (zie §1a). **VOORSTEL** = mijn plan, FORGE beslist.

## 0. Opdracht en spelregels (FEIT, bron: gedeelde planning `/workspace/sapientia-plan/plan.md` op de box, refactorblok; staat niet in de repo)

Dennis (14-11): *"Ja, start 24-11 met battle.gd en daarna game_state.gd en som_arena.gd zodra coop/easy en finish/wm1 gelijk zijn"*.

- battle.gd opsplitsen in kleine PR's **zonder gedragswijziging**. battle.gd zit op slot voor ander werk tijdens het blok.
- Per PR: CI groen, sim voor/na gelijk, FORGE-review 9+, CLEAN.
- Verboden: balanswijzigingen, bestaande tests aanpassen, tests.yml/workflows wijzigen, force-push/rebase, .uid/.import-bestanden.
- Een nieuw testbestand mag. De CI-regel ervoor in tests.yml komt er pas na een ja van Dennis.
- Solo/Classic blijft byte-identiek. Host-authoritative en tick-deterministisch blijven gelden.
- Schatting FORGE: ~12 PR's, 2 tot 2,5 week, het hele blok uiterlijk ~11-12.

## 1. Analyse van battle.gd (FEIT)

`scripts/battle/battle.gd`: **2531 regels**, `extends Control`, geen `class_name`. Het script hangt aan de rootnode `Battle` van `scenes/battle/battle.tscn`.
- 2 signals: `state_changed(new_state)` en `damage_shown(target_name, amount)`. `damage_shown` wordt van buiten gebruikt door debug_autotest, kern-, kernkracht-, golem- en archief-tests. `state_changed` door state_machine_tests.
- ~45 member vars (r.146-208) en 12 `@onready` nodepaden (`$Caption`, `$CommandMenu`, `$Enemies`, `$Effects`, `$TargetCursor`, `$Party`, `$StatusBar`, `$VictoryWindow`, `$TouchControls/Control`, ...).
- battle.tscn heeft **0 `[connection]`-regels**. Alle ~10 `.connect()` staan in de code.
- **Geen net/co-op-code** in battle.gd (geen rpc/multiplayer). Co-op en Action lopen via scripts/som/ en scripts/net/. Classic = dit bestand.
- Al eerder uitgesplitst (precedent): `damage_calc.gd` (static, battle.gd houdt dunne wrappers) en `codex_battle.gd` (`CodexBattle.new(self)`, RefCounted-delegate). Verder `boss_core.gd`, `battle_menu.gd`, `command_cross.gd`, `hero_status_box.gd` en `battle_hero.gd`.
- RNG: globale `randf()` en `pick_random()` op r.890 (beurtsnelheid), 1368 (vijandskill), 1670 (status-roll), 1795 (willekeurig doelwit), 1882 (vluchten) en 1929 (leech), plus `randf_range` in DamageCalc. **De volgorde van deze aanroepen is het gedrag.** Verplaatsen mag die volgorde nooit veranderen.

### Functies per verantwoordelijkheid

| Groep | Regels (ca.) | Functies |
|---|---|---|
| Kop, consts, vars | 1-208 | STATES/ST_*, layout-consts, preloads |
| Opbouw/lifecycle | 211-282, 390-519 | `_ready`, `_exit_tree`, `battle_music_for`(static), `_start_battle_music`, `_make_combatant`, `_enemy_known`, `_enemy_base`, `_spawn_enemies` |
| Bazenbalk | 283-313 | `_make_boss_bar`, `_place_boss_bar` |
| Scherm/layout | 314-389, 520-856, 2522-2531 | `_enter_detail_mode`, `_apply_hd_ui`, `_make_cross`, `_list_row_h`, `_safe`, `_fit_to_screen`, `_add_enemy_idle/_under`, `_show_hit_frame`, `sprite_top`(static), `_layout`, `_place_cross`, `_box_left_for_cross`, `enemy_region`, `_place_menu`, `_layout_enemies`, `stage_x`, `enemy_feet`, `_sort_by_feet`, `art_fit`(static) |
| Rondeloop | 857-926 | `_run` |
| Commando's en doelkeuze (UI) | 927-1342 | `_choose_commands`, `_set_active_hero`, `_choose_for_hero`, `has_usable_magic`, `show_notice`, `codex_command_shown`, `_choose_codex/_swap/_spell/_item`, `_available_items`, `battle_usable`/`heal_would_help`(static), `_items_left`, `_unreserve`, `_next/_prev_alive_hero`, `_select_enemy/_ally/_ko`, `_pick_target`, `_place_target_name`, `_on_enemy_pressed`, `_on_hero_tapped`, `_on_message_gui_input` |
| Actie uitvoeren | 1343-1536 | `_execute` (194 regels, `match` op attack/spell/item/defend/core_charge/kern_skill/archief2_leech/codex_ally/codex_swap) |
| Animatie/FX | 1537-1593, 2034, 2289-2332 | `_hero_wind_up`, `_skill_effect`, `_counter`, `_hero_rest`, `_enemy_lunge`, `_flash_enemy`, `_popup_number`, `_blink`, `_shake` |
| Schade (wrappers) | 1594-1618 | `_physical_damage`, `_spell_amount`, `physical_base`, `spell_base`, `_buff_mult`, `_token_mult` → DamageCalc |
| Buffs/status | 1619-1722 | `_apply_buffs`, `_add_hot`, `_apply_spell_status`, `is_boss_target`, `_tick_ailments` |
| HP/KO/doelwit | 1723-1877 | `_revive`, `_ko_target`, `_revive_combatant`, `clear_ko_status`(static), `_has_curable`, `in_battle`, `_valid_target`, `_valid_ally`, `_damage`, `_hit`, `_report_kos`, `_heal` |
| Vluchten/Archief 2 | 1878-1950 | `_try_flee`, `_archief2_opening`, `_archief2_leech`, `_avg_agi` |
| Golem-kern/schild | 1951-2033 | `core_enemies`, `_core_banner`, `_guard_up`, `_guard_tick`, `_defense_of`, `_core_hint`, `_core_round_start`, `_core_resolve` |
| Beloning/einde | 2045-2193 | `_victory`, `grant_fixed_boss_drops`, `_dungeon100_boss_loot`, `victory_text`, `_victory_page`, `_defeat` |
| Berichten/frame/input | 2194-2288, 2333-2355 | `say`, `show_message`, `choosing`, `_fit_caption`, `_process`, `_unhandled_input`, `_wait`, `_refresh_party`, `_set_state`, `_alive` |
| Tips | 2356-2414 | `_make_tip`, `tip_text`, `_show_tip`, `tip_origin`, `_hide_tip` |
| Kernvaardigheden | 2415-2521 | `_kern_skills`, `kern_charge`, `kern_ready`, `kern_entry_text`, `kern_damage/base`, `_kern_strike`, `_kern_fireball`, `_kern_tick` |

Gedeelde staat: `heroes`, `enemies` en `tutorial` lezen bijna alle groepen. `state`/`_set_state` alleen flow en UI. `round_no` flow, kern en core. `_reserved` alleen commando/item. `stun_chance`/`stun_boss_immune`/`flee_roll_override` worden door de sim en tests gezet. `codex` door flow, UI en beloning. Nodes (`status_boxes`, `hero_nodes`, `effects`, `menu`, `cross`) door UI, FX en layout.

### Wie gebruikt battle.gd van buiten (FEIT)

- **Sim:** `tools/battlesim/sim_battle.gd` doet `extends "res://scripts/battle/battle.gd"` en **overschrijft** `_enter_detail_mode`, `_exit_tree`, `_start_battle_music`, `_wait`, `show_message`, `say`, `_hero_wind_up`, `_enemy_lunge`, `_kern_fireball`, `_popup_number`, `_shake`, `_blink`, `_show_hit_frame`, `_process`, `_layout`, `_victory`, `_defeat`, `_run` en `_choose_commands`. `wm1_sim_battle.gd` overschrijft daarbovenop `_hit` en `_victory` (met `super`). Gebruikt door battlesim.gd, battlesim_runs.gd, wm1_balans.gd, combat_bugs_tests en battlesim_tests.
- **Script direct:** `game_state.gd:879` (MAIN_THREAD_SCRIPTS; was r.868 op `39204468`), ux_tests, formule_tests (`GDScript.new()` **zonder `_ready`**), archief2_tests (`BattleC.art_fit`, `BOSS_MAX_ART_*`, `MAX_ENEMY_ART_H`), state_machine_tests (`BattleScript.new()`, STATES, `_set_state`) en perf_probe_tests.
- **battle.tscn instantiëren:** game_state (`BATTLE_SCENE`), debug_autotest, som_autotest, perf_wm1, wm1_baseline_benchmark, dungeon_tests, battlesim*, combat_bugs_tests, codex-, dungeon100_*-, rekruut-, save_hardening-, save_stress- en ux_polish-tests.
- **Methoden die van buiten bij naam worden aangeroepen** (aantal treffers): `say` 20, `_apply_spell_status` 16, `spell_base` 13, `_physical_damage` 11, `_execute` 11, `physical_base` 9, `_available_items` 7, `art_fit` 6, `_run` 5, `_hero_wind_up` 5, `_alive` 5, `grant_fixed_boss_drops`/`_wait`/`_hit`/`_dungeon100_boss_loot`/`_damage`/`battle_music_for` 4, `_tick_ailments`/`_revive`/`_refresh_party`/`_apply_buffs` 3, en 1-2 keer: `tip_origin`, `show_message`, `in_battle`, `codex_command_shown`, `_set_state`, `_report_kos`, `_list_row_h`, `_hero_rest`, `_buff_mult`, `victory_text`, `stage_x`, `kern_damage/base`, `has_usable_magic`, `enemy_region`, `enemy_feet`, `choosing`, `_valid_target/_ally`, `_token_mult`, `_spell_amount`, `_skill_effect`, `_show_tip`, `_safe`, `_make_combatant`, `_layout`, `_heal`, `_guard_up`, `_defense_of`, `_blink`.

### Broncontroles in bestaande tests (FEIT, belangrijkste valkuil)

Deze tests lezen de **tekst** van `battle.gd`. Code die verhuist kan ze breken, terwijl we die tests niet mogen aanpassen:

| Test (flag) | Wat moet in battle.gd blijven staan |
|---|---|
| perf_probe_tests (`--perfprobetest`) | `battle_label`, `PerfProbe`, `s25_check`; `_pp_on = PerfProbe.enabled`; `func _process` leest `_pp_on` en niet `PerfProbe.enabled` |
| ux_tests (`--uxtest`) | de tekst `UiSfx.TARGET` (nu in `_pick_target`); de oude NL-zinnen in REMOVED_DUTCH mogen niet terugkomen |
| state_machine_tests (`--statemachinetest`) | alle `state =`/`_set_state(` met ST_*-constanten; STATES/CHOOSING_STATES als consts op het script |
| archief2_tests (`--archief2test`) | `art_fit` static + consts `BOSS_MAX_ART_W/H`, `MAX_ENEMY_ART_H` op battle.gd |
| formule_tests (`--formuletest`) | wrappers `physical_base`, `_physical_damage`, `spell_base` werken op een **niet-gereed** object |

### Tests die battle.gd raken (FEIT, flags uit game_state.gd)

`--formuletest`, `--battlesimtest`, `--battlesimenemytest`, `--combatbugstest`, `--statemachinetest`, `--archief2test`, `--uxtest`, `--uxpolishtest`, `--perfprobetest`, `--autotest`, `--codextest`, `--kerntest`, `--kernkrachttest`, `--golemtest`, `--archieftest`, `--dungeontest`, `--dungeon100integratietest`, `--dungeon100blauwtest`, `--dungeon100schaaltest`, `--savehardeningtest`, `--wm1balanstest`, plus perf (`--perftest`, `--wm1baselinebenchtest`, niet in CI). `--combatrngtest` en `--combatsimtest` gaan over het **Action**-gevecht (scripts/som/) en raken battle.gd niet.

### Sim-baseline (FEIT, lokaal gedraaid 16-11 20:11, Europe/Amsterdam)

`xvfb-run -a godot --rendering-driver opengl3 --path . -- --battlesim --seed=20261020 --fights=100 --out=/tmp/r.md --json=/tmp/r.json` op `39204468`: 57 gebieden, `RESULT OK`, 0 SCRIPT ERROR. JSON-sha256 = `d61b2d1128e55f2ef363862b691d351bdf2716afa943af1e95b99c107aeee1f2`. Twee runs gaven dezelfde hash. Het .md-rapport verschilt alleen in de regel "Runtime". **Altijd `--out` meegeven**, anders overschrijft de sim `docs/BATTLE_BALANCE_REPORT.md`.

## 1a. Stand na #450, #472 en #501 (FEIT, nagekeken 17-11 op `9a87280`)

- **battle.gd is niet veranderd** sinds `39204468`: nog steeds 2531 regels, laatste wijziging `4e96b78` (#410). Alle analyse in §1 blijft geldig.
- **#450** (stagger-meter, `f19ff387`) en **#472** (perfect dodge, `8d614deb`) zaten al in `39204468`. Ze raken alleen Action-bestanden (`scripts/som/*`, `scripts/net/*`, eigen data en tests) en niet `scripts/battle/`.
- **#501** (finishers Dax en Vesper, `9dc0976a`) kwam erna, maar wijzigt alleen twee PNG's in `assets/sprites/som/fx/`. Geen invloed op battle.gd.
- Andere wijzigingen sinds `39204468` (14 commits) in `scripts/data/` (`som_chain_data`, `som_feel_data`, `shop_data`) en `game_state.gd` worden niet door `scripts/battle/` gebruikt.
- **Tekstankers** staan er nog allemaal in battle.gd: `battle_label`, `s25_check`, `_pp_on = PerfProbe.enabled`, `UiSfx.TARGET`, `_set_state(`, `art_fit`, `BOSS_MAX_ART_*`.
- **Sim-baseline** opnieuw gedraaid op `9a87280` (seed 20261020, 100 gevechten, twee keer): `RESULT OK`, JSON-sha256 **ongewijzigd** `d61b2d1128e55f2ef363862b691d351bdf2716afa943af1e95b99c107aeee1f2`.
- **Regelnummers in game_state.gd zijn verschoven** (dispatcher nu vanaf r.636, MAIN_THREAD_SCRIPTS r.879). Stap 0 kijkt ze op 24-11 opnieuw na.
- **Werkafspraak (review #495):** elke stap begint met een verse branch vanaf de actuele finish/wm1-head. Vóór stap 0 draait de sim-baseline nog één keer op die head; wijkt de hash af, dan eerst uitzoeken waarom en de golden-waarden pas daarna vastzetten.

## 2. Doelopbouw (VOORSTEL)

Regels:
- battle.gd wordt de **orchestrator** (rondeloop, toestand, nodes, signals) en houdt **elke** naam uit de lijsten hierboven als dunne wrapper. De sim, de tests en de broncontroles blijven dan ongewijzigd groen.
- Helpers zijn `RefCounted`. Ze zijn óf **static** met expliciete invoer (de combatant-Dictionary, spell, parameters), óf een **delegate** zoals CodexBattle (`X.new(self)`), die alleen via een smalle set battle-methoden terugroept.
- Methoden die de sim overschrijft (`_wait`, `say`, `show_message`, `_popup_number`, `_shake`, `_blink`, `_show_hit_frame`, `_hero_wind_up`, `_enemy_lunge`, `_kern_fireball`, `_hit`, `_layout`, `_victory`, `_defeat`, `_run`, `_choose_commands`) blijven op battle.gd. Een helper roept ze aan **via de battle-referentie** (`_b.say(...)`) en nooit op een eigen kopie. Anders vallen de sim-overrides weg en verandert de sim.
- Geen helper preloadt battle.gd (geen cyclus). Helpers preloaden alleen data-scripts. Geen nieuwe autoloads. Geen `class_name` (zoals bijna alle battle-helpers; alleen hd_ui.gd heeft er een), om globale naamconflicten te vermijden.
- Elke helper die op een niet-gereed object nodig is (formule-wrappers) is static of wordt lui gemaakt (`if _x == null: _x = X.new(self)`).

| Nieuw bestand | Soort | Verantwoordelijkheid | ~regels weg uit battle.gd |
|---|---|---|---|
| `scripts/battle/battle_rules.gd` | static | pure regels: `battle_usable`, `heal_would_help`, `clear_ko_status`, `is_boss_target`, `_avg_agi`, `_has_curable`, `victory_text`, `battle_music_for` | ~90 |
| `scripts/battle/battle_status.gd` | static | buffs, HoT, status-roll, ailments-tick (roll-volgorde 1-op-1) | ~110 |
| `scripts/battle/battle_kern.gd` | delegate | kernvaardigheden behalve `_kern_fireball` (FX, sim-override) | ~90 |
| `scripts/battle/battle_boss.gd` | delegate | Golem-kern, schild, Archief 2-opening en -leech | ~140 |
| `scripts/battle/battle_rewards.gd` | delegate | EXP/goud/buit/level-pagina's; `_victory` blijft een wrapper | ~130 |
| `scripts/battle/battle_targets.gd` | delegate | in_battle, geldige doelwitten, KO/revive/heal, KO-melding | ~140 |
| `scripts/battle/battle_tips.gd` | delegate | tip-paneel | ~60 |
| `scripts/battle/battle_layout.gd` | delegate | schermindeling, kruis, vijandenrij, bazenbalk | ~330 |
| `scripts/battle/battle_setup.gd` | delegate | combatants maken, vijanden spawnen, idle/under-FX | ~220 |
| `scripts/battle/battle_commands.gd` | delegate | commandokeuze en submenu's; `_pick_target` blijft (UiSfx.TARGET) | ~330 |
| `scripts/battle/battle_actions.gd` | delegate | `_execute` per actietype | ~190 |

Eindbeeld: battle.gd **~800-900 regels** (consts, vars, `_ready`, `_run`, `_execute`-dispatch, berichten, FX-haakjes en ~60 wrappers).

## 3. PR-volgorde (VOORSTEL, ~1 per werkdag, laagste risico eerst)

Elke PR: pure move/extract, 1 helper per PR, branch vanaf finish/wm1, geen rebase. Werk dat battle.gd in dezelfde periode raakt wacht.

**Acceptatie per PR (A):**
1. CI groen, alle bestaande suites;
2. `--battlerefactortest` lokaal groen, of in CI zodra Dennis ja zegt;
3. battlesim-JSON (seed 20261020, `--fights=100`) **dezelfde sha256 als de baseline** (zie §1);
4. 0 SCRIPT ERROR in import en suites;
5. Classic/solo gelijk: golden-log van stap 0 byte-gelijk;
6. diff bevat alleen battle.gd en het nieuwe helperbestand, geen .uid/.import;
7. FORGE 9+, CLEAN.

| # | PR | Wat verhuist | Risico | Bestaande dekking | Extra golden in stap 0 |
|---|---|---|---|---|---|
| 0 | **Karakterisatietest** (nieuw `scripts/tests/battle_refactor_tests.gd`, flag `--battlerefactortest`) | niets; vastleggen | laag | – | alles hieronder |
| 1 | battle_rules.gd | pure statics (zie tabel) | laag | ux, codex, archief2 | tabel van in/uit per functie |
| 2 | battle_status.gd | `_apply_buffs`, `_add_hot`, `_apply_spell_status`, `_tick_ailments` | middel (randf-volgorde r.1670) | formule, combatbugs, battlesim | geseede statustabel + RNG-volgnummer na elke aanroep |
| 3 | battle_kern.gd | `_kern_skills`, `kern_charge/ready/entry_text`, `_kern_strike`, `_kern_tick` | laag-middel | kern, kernkracht | kern-cooldownreeks over 5 rondes |
| 4 | battle_boss.gd | core-/guard-functies, `_archief2_opening/_leech` | middel | golem, bossphase, archief2 | golem- en genezer-gevecht: berichtlog + HP-reeks |
| 5 | battle_rewards.gd | `_victory`-kern, `grant_fixed_boss_drops`, `_dungeon100_boss_loot`, `_victory_page` | middel (GameState-schrijfacties, buit-RNG via eigen RNG r.2132) | dungeon100_*, codex, wm1balans | EXP/goud/buit/level-pagina's van 6 vaste gevechten |
| 6 | battle_targets.gd | `in_battle`, `_valid_target/_ally`, `_ko_target`, `_revive*`, `_heal`, `_report_kos`, `_damage` (`_hit` blijft) | middel-hoog (pick_random r.1795) | combatbugs, battlesim, autotest | doelwitreeks van 200 geseede vijandbeurten |
| 7 | battle_tips.gd | tip-functies | laag | autotest, ux | `tip_text`/`tip_origin` per held |
| 8 | battle_layout.gd | layoutfuncties en bazenbalk (`_layout` blijft een wrapper) | middel (alleen beeld) | archief2 (art_fit), autotest-shots, ux_polish | posities van kruis/vijanden/menu bij 3 schermmaten en 1-5 vijanden |
| 9 | battle_setup.gd | `_make_combatant`, `_enemy_known/_base`, `_spawn_enemies`, `_add_enemy_idle/_under` | middel-hoog (uid-volgorde, schaal D100/blauw) | dungeon100_*, archief2, golem | dump van gespawnde combatants (stats, uid, flags) voor 10 groepen |
| 10 | battle_commands.gd | `_choose_for_hero`, `_choose_codex/_swap/_spell/_item`, `_available_items`, `_items_left`, `_unreserve`, hero-navigatie, `_select_*` | hoog (await-ketens, connects, B-terug) | autotest, ux, statemachine, codex | gescripte invoer → gekozen plan + toestandsreeks |
| 11 | battle_actions.gd: eerst **in hetzelfde bestand** `_execute` opdelen in `_exec_attack/_spell/_item/...`, dan verplaatsen | `_execute`-takken | hoogst (RNG r.1368, hele gevechtsflow) | battlesim, combatbugs, alle baas-tests | volledige geseede berichtlog + HP-reeks van 30 gevechten |
| 12 | Opruimen | kopcommentaar, docs/STATE_MACHINES.md-verwijzingen, deze plan-doc → "gedaan" | laag | – | – |

(13 PR's met stap 0 erbij. Dat komt overeen met de schatting van FORGE, ~12.)

### Stap 0 in detail (VOORSTEL)

Nieuw bestand `scripts/tests/battle_refactor_tests.gd`, gebaseerd op `sim_battle.gd`, zodat wachten en animaties wegvallen. Het draait op de finish/wm1-head waarop stap 0 start en zet de uitkomsten als **vaste golden-waarden** in de test:
1. **Schade- en formuletabel:** `seed(1234)`, daarna 50x `_physical_damage`, `_spell_amount` en `kern_damage` op vaste vechters. Hash van de reeks.
2. **Gevecht-golden:** 30 geseede gevechten (WM1, Archief 2, Golem, D100 blauw/baas). Per gevecht een hash van winst/rondes/HP per held/items/MP/EXP/goud/buit en van de **berichtlog** (`say`/`show_message` in volgorde).
3. **RNG-vingerafdruk:** na elk gevecht `randi()` = vaste waarde. Dat vangt elke verschoven randf-aanroep.
4. **Oppervlak:** `has_method` op elke naam uit §1 (extern gebruikt + sim-overrides), plus de consts en signals.
5. **Broncontrole:** de ankers uit de tabel "Broncontroles" staan nog in battle.gd.
6. **Layout-golden:** posities bij 384x216, 480x216 en 512x216 voor 1 t/m 5 vijanden en een baas.

Koppelen: 1 regel in de dispatcher van `scripts/game_state.gd` (de lijst `for t in [["--autotest", ...` vanaf r.636 op `9a87280`; regelnummer op de dag zelf opnieuw nakijken) voor `--battlerefactortest`. **Let op:** dat is een kleine toevoeging in game_state.gd (fase 2-bestand). De CI-regel `battlerefactortest` in tests.yml **wacht op een ja van Dennis**. Tot die tijd draaien FORGE/COMBAT de test lokaal en zetten ze de uitvoer in de PR.

## 4. Gaten en risico's

**Nu zonder (directe) dekking (FEIT, via rg in scripts/tests):** de volgorde van berichten in een hele ronde, de exacte RNG-volgorde (alleen indirect via de sim-JSON), layoutposities bij andere schermverhoudingen, de uid-/spawnvolgorde, `_unhandled_input` en B-terug in submenu's, en `_victory_page` en level-pagina's als tekst. Stap 0, punten 2, 3, 6 en de commando-golden in stap 10 dichten die gaten.

**Risico's:**
- **Sim-overrides omzeild:** de helper roept een eigen kopie aan in plaats van `_b.say()`/`_b._wait()`. De sim krijgt dan wachttijden en de hash verandert. Tegenmaatregel: punt 4 en de sim-hash.
- **Broncontroles:** perfprobe, ux en statemachine lezen de tekst van battle.gd (zie §1). Die ankers niet verplaatsen.
- **Niet-gereed object:** formule_tests en state_machine_tests maken battle.gd zonder `_ready`. Wrappers mogen dan niet op een delegate leunen die pas in `_ready` ontstaat (static of lui maken).
- **get_node-paden en `@onready`:** helpers krijgen nodes via de battle-referentie en gebruiken geen eigen `$`-paden. battle.tscn blijft ongewijzigd.
- **Connects bij naam:** er zijn geen `[connection]`-regels in de .tscn. `.connect(_on_enemy_pressed)` en dergelijke blijven naar battle.gd wijzen, of de Callable verhuist samen met de functie in één PR.
- **Preload-cycli:** helpers preloaden battle.gd niet. MAIN_THREAD_SCRIPTS in game_state.gd noemt alleen battle.gd. Helpers die autoloads bij naam gebruiken (GameState) moeten daar ook in, anders volgt "Caller thread can't call this function". Dat vraagt een extra regel in game_state.gd, dus beter: helpers krijgen GameState-waarden via battle mee of worden via battle.gd's preload al op de hoofdthread geladen (controleren in stap 1).
- **Net-handlers bij stringnaam:** komen niet voor in battle.gd (FEIT). Geen risico in fase 1.
- **Await-semantiek:** een helperfunctie met `await` moet bij de aanroeper ook `await` krijgen, anders loopt de ronde door. Tegenmaatregel: berichtlog-golden.

## 5. Buiten scope (later)

- **Fase 2:** `scripts/game_state.gd` en `som_arena.gd`, pas nadat coop/easy en finish/wm1 gelijk zijn. Daarvoor komt een eigen plan.
- Geen gedrags-, balans- of UX-wijzigingen in dit blok. Verbeteringen die we onderweg zien gaan naar BACKLOG en komen na het blok.
