# HANDOFF — bevindingen professionele review (nov 2026) → AI-team

Bron: `docs/rapporten/REVIEW_PROFESSIONEEL_2026-11.md` (basis `main` = `db0aa04`, v0.20). Dit document vertaalt dat
rapport naar **uitvoerbare tickets** per rol. Lees eerst `AGENTS.md`; de harde regels gelden onverkort:
één taak per branch (`cursor/<taak>`), kleine PR naar `main` met het template, **elk ticket krijgt een test** in de
headless runner, geen versienummers bumpen, geen art tekenen behalve placeholders, niet zelf mergen (RPG Forge).

Wie doet wat:
- **RPG Forge** — alles wat `main`, CI, export-presets, engineversie en release raakt (F-tickets). Merget alles.
- **RPG CODE** — gameplay, combat, save, netwerk (C-tickets).
- **RPG ART** — definitieve art/audio (A-tickets, alleen de "Nodig van RPG ART"-lijst).
- **Cursor agents** — de S-tickets met een scherpe scope (gemarkeerd ✦). Eén ticket per branch.
- **Dennis** — de beslissingen in §5. Zonder die beslissingen blijven F-4, F-5 en C-9 liggen.

Prioriteit: **P0** = dataverlies/beveiliging/blokkeert release · **P1** = speler merkt het · **P2** = gezondheid codebase.
Inspanning: S < 2 uur, M = 1-2 dagen, L = week+.

---

## 1. Sprint 1 — alles S, nul risico, kan parallel

### F-1 ✦ Ontbrekende suites in de CI-matrix · P0 · S
- **Waar:** `.github/workflows/tests.yml:24-38` (`strategy.matrix.suite`), `scripts/game_state.gd` dispatcher (109 flags, matrix 80).
- **Wat:** voeg toe: `savehardeningtest`, `coopguestsavetest`, `combatrngtest`, `combatsimtest`, `aabtest`, `demofixtest`,
  `kasdeurtest`, `zonetest`, `telegraphcooptest`, `uxtest`, `uipolishtest`, `uxpolishtest`, `berggrotdextest`, `sessiefixtest`,
  `wm1releasetest`. **Niet** toevoegen: `lifecycletest` (intermitterende hang, zie §6), perf/bench/`wm1*`-meetsuites
  (die horen in een aparte nightly), `relaytest` (Node nodig → F-2).
- **Acceptatie:** elke toegevoegde suite groen in CI; `AGENTS.md`-suitetabel bijgewerkt met de PASS-aantallen.
- **Test:** geen nieuwe; de suites zelf.

### F-2 ✦ Relay-unittests en `--relaytest` in CI · P0 · S
- **Waar:** `relay/package.json` (`npm test`), `scripts/tests/relay_tests.gd` (start zelf `node relay/server.js`, Node ≥ 20).
- **Wat:** aparte job `relay` in `tests.yml`: `actions/setup-node@v4` (20), `cd relay && npm ci && npm test`, daarna
  `.github/scripts/run_suite.sh relaytest` met Godot.
- **Acceptatie:** job groen; `AGENTS.md:103` ("zit nog niet in de CI-matrix") aangepast.

### C-1 ✦ Dev-knoppen op het titelscherm gaten · P0 · S
- **Waar:** `scripts/ui/title_screen.gd:188` (`som_button`), `:204-214` (`BetaCard`, "Beta Test", "End State"); alleen
  PvP/Co-op zijn gegate (`:354-357`, `ReleaseFlags.online_buttons_visible()`).
- **Wat:** nieuwe vlag `ReleaseFlags.dev_title_buttons_visible()` → `is_debug_build()` **of** een expliciete
  `static var beta_buttons := true` die Dennis per build kiest (bètatesters hebben ze nu nodig). Knoppen alleen bouwen als true.
- **Acceptatie/test:** in `scripts/tests/testmodus_tests.gd` of een nieuwe `titlegate`-sectie: met
  `ReleaseFlags.debug_build_override = 0` en vlag uit → geen `BetaCard`/`SoM`-node; met override 1 → wel.

### C-2 ✦ Stun-lock dichten · P1 · S
- **Waar:** `scripts/data/spells.gd:45` (Chain Lightning: 8 MP, alle vijanden, 30% stun), `scripts/data/spell_rules.gd:95`
  (`STUN_BOSS_IMMUNE = false`), `scripts/battle/battle.gd:1661` (stun-worp).
- **Wat:** (a) één beurt stun-immuniteit na een stun (statusvlag op de combatant), (b) AoE-spreuken stun-kans 15%,
  (c) bazen halve kans. Getallen als constanten in `spell_rules.gd`, niet in logica.
- **Acceptatie/test:** `scripts/tests/combat_bugs_tests.gd` of nieuwe `stuntest`: stun → volgende beurt kan niet opnieuw;
  AoE-kans gelezen uit constante; baas-kans = helft. Daarna `--battlesim --seed=1` herdraaien en
  `docs/BATTLE_BALANCE_REPORT.md` opnieuw committen (Tweede Archief vd. 2 en Diepe Grot 95 als ijkpunt).

### C-3 ✦ Veldmenu via preload (geen runtime `load()`) · P1 · S
- **Waar:** `scripts/map.gd:204` `load("res://scripts/ui/field_menu.gd").new()`; prewarm alleen op titel/naam
  (`game_state.gd:927`); hang gereproduceerd in `--lifecycletest` op `main` (threaddump: hoofdthread in futex, één worker draait).
- **Wat:** `const FieldMenu := preload("res://scripts/ui/field_menu.gd")` in `map.gd` **mits** dat geen preload-cyclus geeft
  (field_menu preloadt 10 schermen; check dat geen daarvan `map.gd` preloadt). Anders `field_menu.gd` in
  `GameState.MAIN_THREAD_SCRIPTS` en ophalen via `GameState.get_resource()`.
- **Acceptatie:** `--lifecycletest` 10x achter elkaar zonder hang (script: `for i in $(seq 10); do .github/scripts/run_suite.sh lifecycletest || break; done`);
  `--menutest`, `--autotest` groen. Als de hang weg is: `lifecycletest` alsnog in de matrix (F-1 noteert dat).

### C-4 ✦ Opslaan uitleggen aan de speler · P1 · S
- **Waar:** `scripts/ui/field_menu.gd:59-71` (menu-items, geen Save), `:488` (`open_save()` "Geen knop meer"); save-boeken
  (`book_point`/`BookPoint`), enige hint `story_data.gd:599`.
- **Wat:** (a) eerste interactie met een save-boek → eenmalige regel (story-vlag `save_uitleg_gezien`):
  "Glowing books save and heal. There is no saving from the menu." (b) In het veldmenu een grijze regel "Save" met
  reden "Find a glowing book" (zelfde grijs-met-reden-patroon als Codex-submenu in battle).
- **Acceptatie/test:** `scripts/tests/tutorial_tests.gd`: nieuw spel → eerste boek toont de regel, tweede keer niet;
  `--menutest`: grijze Save-regel aanwezig, niet klikbaar. Alle tekst Engels.

### C-5 ✦ Save-version guard + `save_game`-guard · P0 · S
- **Waar:** `game_state.gd:216` (`SAVE_VERSION := 1`), `:1811` (schrijft), `apply_state` leest hem nooit;
  `save_game` heeft geen eigen `scene_busy()`-guard (`docs/qa/SAVE_HARDENING.md:41`).
- **Wat:** bij `version > SAVE_VERSION`: `push_warning`, laden toestaan maar **niet terugschrijven** (vlag `save_readonly`
  tot de speler een nieuw spel start) + melding in de slotlijst "(newer version)". `save_game`: early return als
  `scene_busy()`, met `return false`.
- **Acceptatie/test:** `save_hardening_tests.gd:468` (het `version=999`-geval) uitbreiden: na laden mag `save_game` het
  bestand niet veranderen; nieuwe check `save_game` tijdens `in_battle = true` → false en bestand onaangeroerd.

### C-6 ✦ Geneste typechecks in `apply_state` · P1 · S
- **Waar:** `game_state.gd:2042` `int(a2["platen"][k])`, `:1974` `int(best[k].get("defeated", 0))`.
- **Wat:** zelfde guard-stijl als `_inventory_from` (type checken vóór `int()`), of een helper `_int_of(v, default)`.
- **Acceptatie/test:** `save_fuzz`-suite: fuzz nu ook één niveau dieper (`archief2.platen`, `bestiarium.*.defeated` met
  null/Array/String) → geen SCRIPT ERROR, defaults.

### C-7 ✦ Molen-marker in de save · P1 · S
- **Waar:** `scripts/village/molen.gd` ("al gegeven" als scene-meta, `SAVE_HARDENING.md:38`).
- **Wat:** story-vlag `molen_meel_gegeven` (of teller) in `story_flags`; meta weg.
- **Acceptatie/test:** `wilgendal_tests.gd`: meel krijgen → save → load → molen geeft niet nogmaals.

### C-8 ✦ Relay: id-overflow en crash-vangnet · P0 · S
- **Waar:** `relay/src/relay.js:116` (`nextId: HOST_PEER_ID + 1`), `:158` (`room.nextId++`, nooit hergebruikt),
  `:210` (`framed.writeUInt16BE(conn.peerId, 0)` gooit boven 65535).
- **Wat:** ids hergebruiken uit een vrije lijst per kamer (max spelers is 4, dus 1..255 volstaat) of join weigeren als
  `nextId > 65535`; alle ws-handlers in try/catch met log; `process.on('uncaughtException'/'unhandledRejection')` → log + door.
- **Acceptatie/test:** `relay/test/*.test.js`: 70k join/leave-cycli in een kamer → geen throw, ids blijven < 65536;
  een handler die gooit haalt het proces niet neer.

### F-3 ✦ Export-presets gelijktrekken + `export/` uit git · P0 · S
- **Waar:** `export_presets.cfg:11` (APK `exclude_filter` met `wacht/*, export/*, pvp/tests/*, world_warper/tests/*`) vs
  `:153` (Web) en `:195` (AAB) zonder die uitsluitingen; `export/web/index.wasm` (38,6 MB) + verouderde `.pck` getrackt;
  `art/battle_bg/boss.png` (654 KB) dubbel in de export; arm64-preset schrijft nog `rpg_prototype_v0.19_arm64.apk` (`:83`).
- **Wat:** zelfde `exclude_filter` in alle presets; `export/.gdignore`; `git rm --cached export/web/*` + `.gitignore`
  (`build-web.yml` deployt al via een Pages-artifact); controleren of `art/` of `assets/battle` de bron is en de ander
  uitsluiten. **Signing-velden niet aanraken.**
- **Acceptatie/test:** `--aabtest` (scripts/tests/aab_tests.gd) uitbreiden: alle presets hebben dezelfde `exclude_filter`-set;
  `.gdignore` bestaat in `export/`.

### C-9 ✦ Intro-video's her-encoderen · P1 · S (tooling; **beslissing Dennis §5**)
- **Waar:** `assets/video/genezer_warper.ogv` (20 MB), `worldmap_intro.ogv` (9,4 MB): 720x1280 Theora 24 fps;
  `scripts/worldmap_cutscene.gd:5` verwacht 360x640.
- **Wat:** `ffmpeg -i in.ogv -vf scale=360:640 -c:v libtheora -q:v 5 -an out.ogv` (of met audio als die erin zit); doel ≤ 25%
  van de huidige bytes. Bronbestanden horen in `art/` of extern, niet in git (zie F-6).
- **Acceptatie:** `--cutscenetest` groen; APK-grootte in `docs/APK_SIZE.md` bijgewerkt.

### C-10 ✦ Localisatie-guard repareren · P2 · S
- **Waar:** `scripts/tests/ux_tests.gd:84-88` (`KNOWN_DUTCH_PINNED` slaagt voor 2 van 3 alleen via commentaar),
  `pvp/data/modes.gd:10-16` ("Vroeg", "Midden", "Hoog" zichtbaar via `pvp/scripts/ui/mode_panel.gd:45`).
- **Wat:** `KNOWN_DUTCH_PINNED` vervangen door een check op code-only (`_code_only` bestaat al, `:321`); `pvp/` toevoegen aan
  de scan; de drie PvP-namen naar "Early", "Mid", "High" (identifiers/keys niet hernoemen).
- **Acceptatie:** `--uxtest` groen met de nieuwe check; `--pvptest` groen.

### F-4 ✦ Docs opruimen · P2 · S
- **Waar:** 21 root-level `.md` (14x `HANDOFF_*`), `HANDOFF_ARCHIEF1.md` dubbel (root + `docs/`), README "Lufia Prototype"
  t/m v0.19, `AGENTS.md` "er is nog géén audio" (verouderd: 298 bestanden), verwijzingen naar oude scratch-mappen (bv. `v17_ART_SLOTS.md`).
- **Wat:** `git mv HANDOFF_*.md docs/handoff/`; README: korte projectintro + verwijzing naar CHANGELOG; AGENTS.md audio-alinea
  herschrijven (manifest-gedreven, 11 BGM ontbreken, zie A-2); oude scratch-paden schrappen of relatief maken.
- **Acceptatie:** geen link in `docs/` of README wijst naar een niet-bestaand pad (geen `scratch-map`-verwijzingen die als repo-pad gelezen worden);
  `docs/WORKFLOW.md` noemt de nieuwe plek van handoffs.

---

## 2. Sprint 2-3 — M-tickets, één per PR, in deze volgorde

### C-11 Eén autosave per slot · P0 · M · **eerst**
- **Waar:** `game_state.gd:1636-1639` (één `autosave_path` met `home_slot`), `:1353` (`slot_record` kiest de autosave als die
  nieuwer is), `:1031` (nieuw spel). Scenario: slot 1 alleen autosave → nieuw spel in slot 3 → eerste wereld↔kerker-overgang
  overschrijft `autosave.json` én `.bak` → slot 1 kwijt.
- **Wat:** `autosave_<slot>.json` per slot (+ `.bak`), migratie: bestaande `autosave.json` → `autosave_<home_slot>.json` bij
  eerste start. `slot_record(slot)` leest alleen zijn eigen autosave. Beta/eind-profielen houden hun eigen pad (`:1455-1473`).
- **Acceptatie/test:** nieuwe sectie in `save_hardening_tests.gd`: het scenario hierboven → slot 1 behoudt zijn autosave;
  migratie van een oude `autosave.json`; `checkpointtest`, `saverobusttest`, `coopguestsavetest` groen.
- **Afhankelijk van:** F-1 (anders draait de test niet in CI).

### C-12 MAG, MDEF, zwak/resist laten meetellen · P1 · M
- **Waar:** `scripts/battle/damage_calc.gd:32-34` (`spell_base = power_at × factor × token_mult`), `spell_rules.gd:51-80`
  (`factor` kent alleen element-vs-metaal), `game_data.gd:101` ("weak/resist = alleen informatie"), `som_arena.gd:1931-1989`
  (Action-spreuken). Geen enkele combat-regel leest `mag`/`mdef`/`weak`/`resist` (geverifieerd).
- **Wat:** in `DamageCalc.spell_base`: `power_at × (1 + mag/50) − mdef/2`, daarna `× 1.5` bij `weak`, `× 0.5` bij `resist`
  (constanten in `spell_rules.gd`). Dezelfde functie aanroepen vanuit `som_arena` (opmaat naar C-15). Heal-spreuken: alleen `mag`.
- **Acceptatie/test:** `formule_tests.gd`: tabel met vaste invoer → verwachte uitkomst; Life Staff (+40 mag) verandert de
  uitkomst; weak/resist ×1,5/×0,5; `--battlesim` herdraaien en rapport committen. **Balansrisico:** mages worden sterker; kijk
  naar Chain Lightning ná C-2.

### C-13 Guest-input binden aan de afzender · P0 · M
- **Waar:** `scripts/net/net_codec.gd:55` (`slot` uit `raw[0]`, ongeclampt), `scripts/net/action_coop_session.gd:218-221`
  (alles in `_inputs` zonder check; `_peer_to_slot` bestaat op `:34, :264, :276`), `som_arena.gd:2469-2505` (past elke input
  toe met volle `dt`); relay staat 120 msg/s toe vs 30 Hz input (`net_protocol.gd:39`).
- **Wat:** in `_handle_raw_packet` de afzender-peer meegeven; `slot := _peer_to_slot[peer]`, packet-slot negeren; per slot
  alleen de **laatste** input per tick bewaren; `lock_idx` clampen op het aantal doelen; onbekende peer → packet weg + teller.
- **Acceptatie/test:** `net_sync_tests.gd`/`coop_e2e_tests.gd`: guest stuurt slot van de host → genegeerd; 4 inputs in één tick →
  één toegepast; `lock_idx = 200` → geclampt. `--relaytest` groen.

### C-14 Inventaris- en goud-API · P2 · S-M
- **Waar:** 18 directe schrijfacties op `GameState.inventory`, 9 op `gold`, 14 op `story_flags[...]` buiten GameState:
  o.a. `battle.gd:1457, 1484`, `som_arena.gd:1176, 1185`, `puzzle_room.gd:541`, `som_codex.gd:113`,
  `data/koopman_winkel.gd:202-218`, `data/shop_data.gd:168`.
- **Wat:** `GameState.add_item(id, n)`, `remove_item(id, n) -> bool`, `add_gold(n)`, `spend_gold(n) -> bool`, signaal
  `inventory_changed(id, count)`; clamps (`MAX_ITEM_STACK`, `MAX_GOLD`) en codex-sync daarbinnen. Migreer per bestand (één PR per gebied is oké).
- **Acceptatie/test:** nieuwe `inventorytest`: clamps, signaal, `remove_item` bij 0 → false; grep-check in de suite dat
  `GameState.inventory[` buiten `game_state.gd` niet meer voorkomt (zelfde broncontrole-stijl als `state_machine_tests.gd`).

### C-15 Classic op een eigen `rng` + RNG-lint over `scripts/battle/` · P2 · M
- **Waar:** `battle.gd:887` (snelheid), `:1361` (vijand-skills), `:1661` (stun), `:1783` (`pick_random`), `:1870` (vluchten),
  `:1915` (leech), `:2118` (`rng.randomize()` baas-loot), `damage_calc.gd:14, 23, 65`, `codex_battle.gd:123, 179, 318`;
  `combat_rng_tests.gd:37-54` scant alleen `scripts/som/`.
- **Wat:** `var rng := RandomNumberGenerator.new()` in battle met `seed_rng(seed)`; `DamageCalc`/`CodexBattle` krijgen de rng
  als parameter; baas-loot-seed afgeleid van `dungeon100_seed`/`floor_seed`; lint uitbreiden naar `scripts/battle/`.
- **Acceptatie/test:** `combat_rng_tests.gd`: zelfde seed → zelfde gevecht (Classic), lint groen over beide mappen; `--battlesim` ongewijzigde winrates ±1%.

### F-5 Perf: `dorp_wilgendal`, `woud_beek`, perf-docs, boot-preload · P1 · M
- **Waar:** `docs/perf/WM1_PERF.md`, `docs/perf/wm1_baseline.md:67` (woud_beek 491 draw calls, RISK, niet in
  `scripts/data/wm1_perf_budget.gd`), `docs/perf/voorstel_wm1_boot_preload.patch` (28,9 → 10,6 MB), `audio_manager.gd:649`
  (synchrone BGM-`load()` bij kaartwissel), `som_hud.gd:131` (`queue_redraw` elk frame).
- **Wat:** (1) patch toepassen; (2) `woud_beek` in het budget; (3) één meetmethode vastleggen en beide docs daarop herzien
  (nu 145,5 vs 34,5 draw calls voor dezelfde kamer); (4) v8-grondlaag van het dorp als één gebakken atlas, bomen als één
  physics-laag; (5) BGM via `load_threaded_request` tijdens de fade; (6) `som_hud` alleen redraw bij wijziging.
- **Acceptatie/test:** `--wm1budgettest` groen met `woud_beek` erin; `--perfprobetest`; draw calls dorp < 120 in de baseline-run.

### C-16 UX-pakket touch/tekst · P1 · M
- **Waar:** `scripts/ui/ui_touch.gd:5-9` (`TOUCH_MIN = 25` ≈ 48 dp alleen op 411 dp), `menu_screen.gd:24`/`field_menu.gd:51`
  (`ROW_H 16` ≈ 4,8 mm), `options_screen.gd:13`; `assets/theme.tres:21` (10), `som_hud.gd:63`/`som_fx.gd:336` (8);
  `settings.gd:58` (`"crt": true`); `ui_style.gd:15, 24` (`TEXT_OFF` ≈ 3,2:1); `transition.gd:36-41` (geen laadindicator).
- **Wat:** `TOUCH_MIN` uit `DisplayServer.screen_get_dpi()`; rijen ≥ 22; optie "Large text" (10→12, min 10); CRT splitsen in
  "Scanlines" / "Glitch effects", glitch standaard **uit** (fotosensitiviteit); `TEXT_OFF` → ≈ `#857c6b`; laadindicator na 400 ms;
  eenmalige overlay op de eerste kaart ("Drag to move · A = talk · MENU"). **Beslissing CRT-default: §5.**
- **Acceptatie/test:** `ui_polish_tests.gd` (5 viewport-profielen) + `ux_tests.gd`: rijhoogte ≥ 22, contrast TEXT_OFF ≥ 4,5:1
  (bereken in de test), settings-sleutels `scanlines`/`glitch` met migratie van `crt`.

### F-6 Grote binaries naar LFS · P2 · S-M
- **Waar:** `.git` 93 MB; `.ogv` 20 + 9,6 MB, 25 `.ogg` à 2,5-3,3 MB.
- **Wat:** `git lfs track "*.ogv" "*.ogg"`; **geen history-rewrite** (alleen vanaf nu). Beslissing Dennis of LFS-quota oké is.

---

## 3. Later — L-tickets (plan eerst, dan één PR per stap)

### F-7 Engineversie 4.5+ · P0 voor Play Store · L
- **Waar:** `AGENTS.md:4`, `tests.yml GODOT_VERSION` (4.3), `docs/release/PLAY_STORE.md:59-67` (AAB vereist 4.5+ voor 16 KB
  pages / targetSdk 35+), README:10 (web op 4.7.2).
- **Stappen:** (1) CI-job `godot45` die de volledige matrix op 4.5.x draait naast 4.3; (2) alle SCRIPT ERROR/renames fixen
  (typed arrays, `@export`-wijzigingen, `TileMap` → `TileMapLayer`-deprecations); (3) `.import`-bestanden opnieuw genereren in
  één PR; (4) 4.3 uit de matrix; (5) AGENTS.md/README/docs bijwerken. **Beslissing Dennis: welke 4.5+/4.6/4.7-versie.**

### C-17 `CombatRules` als gedeelde kern Classic/Action · P1 · L
- **Waar:** Classic `atk·buff·mult − def/2` (`damage_calc.gd:28`) vs Action `(atk − def/2)·mult` (`som_arena.gd:785-788`);
  Action-spreuken zonder `token_mult`/`SpellRules.on_hit` (geen DoT/stun), geen buffs, geen vluchten; exp/loot dubbel
  (`som_arena.gd:1174-1196` vs `battle.gd:2031`).
- **Stappen:** pure `scripts/battle/combat_rules.gd` (damage, spell, on_hit, rewards; rng als parameter) → eerst Classic erop,
  dan Action; pariteitstest: zelfde invoer, zelfde uitkomst in beide modi. Daarna `action_sim.gd` op een headless `SomArena`
  met `seed_rng` (nu modelleert hij het gevecht i.p.v. het te draaien).

### F-8 GameState splitsen · P2 · L (volgorde = laagste risico eerst)
- `_preload*`/`_prewarm*` (772-952) → `scripts/core/preloader.gd`; `coop_*` (56-196) → `scripts/coop/coop_state.gd`;
  testdispatch (491-748) → `scripts/tests/test_registry.gd` (`_ready`: `if ResourceLoader.exists(REG): load(REG).dispatch(self, args)`);
  save-I/O (1317-1940) → `scripts/core/save_store.gd`. GameState blijft de dunne facade; geen publieke naam verandert.
- Daarna: `battle_request` i.p.v. negen `pending_*`-velden (`battle.gd:215-471`); `class_name FieldMap` voor `map.gd`.
- **Acceptatie per stap:** alle suites groen; `--statemachinetest` bewaakt de flow-API.

### F-9 CI-kosten · P2 · M
- 80 jobs × (`apt-get` + volledige `--import` tot 600 s). Doel: ±8 shards van ±10 suites met één import en een gecachte `.godot/`
  (`actions/cache` op `.godot/imported` + `global_script_class_cache.cfg`). Perf/bench-suites naar een nightly workflow.

---

## 4. Nodig van RPG ART / audio (A-tickets)
- **A-1** 123 open placeholder-entries in `tools/placeholders_v17.txt` (54 KLAAR). Prioriteit op wat WM1-spelers zien: dorp,
  woud, archief-ingang. Per entry: naam + maat staan in het bestand.
- **A-2** 11 ontbrekende BGM-tracks uit `assets/audio/audio_manifest.json`: `eindbaas_fase1`, `eindbaas_fase2`, `game_over`,
  `overwinning`, `aftiteling`, `sapientia_thema`, `rustplek`, `industriestad`, `zwevende_tempel`, `ondergronds_lab`,
  `sterrenobservatorium`. Formaat: ogg, ~96 kbps (zie F-5), loop-punten in het manifest.
- **A-3** 120 synthetische actor-SFX + 162 placeholder-SFX vervangen (lijst: `tools/sfx`, `assets/audio/sfx/README`).
- **A-4** Titelmuziek `main_menu` is een Suno-track: vervangen **of** licentie vastleggen (§5).

## 5. Beslissingen voor Dennis (blokkeren tickets)
1. **Package-naam** `com.dennis.rpgprototype` (AAB-preset): na de eerste Play-upload permanent. Houden of `com.<studio>.sapientia`? → F-3/F-7.
2. **Engineversie** voor de AAB (4.5 / 4.6 / 4.7.x) → F-7.
3. **Suno-licentie** titelmuziek (gratis tier = geen commercieel gebruik) → A-4.
4. **Privacybeleid** + Data safety (INTERNET, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST) → `docs/release/PLAY_STORE.md:124`.
5. **Dev-knoppen**: bètatesters houden Beta Test/End State? Dan vlag per build (C-1).
6. **CRT-default**: scanlines aan/uit standaard; glitch standaard uit wegens flitsen? (C-16).
7. **Autosave-beleid**: extra autosave bij story-step/kern terwijl `field_free()`? (nu bewust uit na winst; `game_state.gd:2620`).
8. **Relay-URL** (`project.godot:108` leeg) en `wss://` afdwingen in release (`net_protocol.gd:188`).
9. **LFS** voor `.ogv`/`.ogg` (F-6).

## 6. Valkuilen voor wie hieraan werkt
- **`--lifecycletest` hangt intermitterend** op `main` bij het openen van het veldmenu (hoofdthread wacht, één worker spint, tijdens
  de runtime-`load()` van `field_menu.gd`). Niet door een recente PR. Niet in CI zetten vóór C-3; lokaal met `timeout 300` draaien.
- **Verse import maakt ±740 untracked `.import`/`.translation`-bestanden** (assets zonder sidecar in git). Niet committen; `git add` met
  expliciete paden, of lokaal uitsluiten via `.git/info/exclude`.
- **`class_name` en de global class cache**: een nieuwe `class_name` is pas bekend na `--import`. Autoloads (GameState) gebruiken daarom
  `preload` (`FlowStateC`), tests mogen de klassenaam gebruiken.
- **Strings niet hernoemen**: `battle.state == "command"`, `vesper.state == "ko"`, save-sleutels, story-vlaggen. Nieuwe toestand =
  constante + in de set (`docs/STATE_MACHINES.md`), anders faalt `--statemachinetest`.
- **Balansrapporten zijn van 31 okt**; 20 commits aan combat/data daarna. Herdraai `--battlesim --seed=1` vóór en ná C-2/C-12 en
  commit het rapport mee.
- **Typed-array vergelijking in GDScript**: `a == [..] as Array[String]` bindt als `(a == [..]) as Array[String]`; vergelijk elementsgewijs.
- **Twee perf-docs met verschillende getallen**: gebruik `wm1_baseline.md` als bron tot F-5 ze gelijktrekt.

## 7. Definition of done (elk ticket)
1. Branch `cursor/<ticket-id>-<korte-naam>` (bv. `cursor/c-2-stunlock`), één ticket per PR, template volledig ingevuld.
2. Test erbij of uitgebreid in de headless runner; alle suites in de matrix groen (`.github/scripts/run_suite.sh <suite>` lokaal, exact wat CI doet).
3. Spelertekst Engels; docs/commentaar Nederlands; geen versiebump; geen signing-velden; geen art tenzij placeholder (+ registratie).
4. In de PR onder "Tests" de PASS-aantallen; onder "Nodig van RPG ART" wat echt moet komen (of "niets").
5. Dit document bijwerken: ticket afvinken met PR-nummer.

| Ticket | Rol | Prio | Inspanning | Status |
|---|---|---|---|---|
| F-1 suites in CI | Forge/Cursor | P0 | S | open |
| F-2 relay in CI | Forge/Cursor | P0 | S | open |
| F-3 presets + export/ | Forge | P0 | S | open |
| F-4 docs opruimen | Cursor | P2 | S | #397 |
| F-5 perf-pakket | Forge/CODE | P1 | M | open |
| F-6 LFS | Forge | P2 | S-M | wacht op §5.9 |
| F-7 engine 4.5+ | Forge | P0 (store) | L | wacht op §5.2 |
| F-8 GameState splitsen | CODE | P2 | L | open |
| F-9 CI-kosten | Forge | P2 | M | open |
| C-1 dev-knoppen gaten | Cursor | P0 | S | wacht op §5.5 |
| C-2 stun-lock | CODE/Cursor | P1 | S | open |
| C-3 veldmenu preload | Cursor | P1 | S | open |
| C-4 opslaan uitleggen | Cursor | P1 | S | open |
| C-5 save-version + save_game guard | Cursor | P0 | S | open |
| C-6 geneste typechecks | Cursor | P1 | S | open |
| C-7 molen-marker | Cursor | P1 | S | open |
| C-8 relay overflow | CODE | P0 | S | open |
| C-9 video her-encoderen | Forge | P1 | S | open |
| C-10 localisatie-guard | Cursor | P2 | S | open |
| C-11 autosave per slot | CODE | P0 | M | na F-1 |
| C-12 MAG/MDEF/zwak | CODE | P1 | M | na C-2 |
| C-13 guest-input binden | CODE | P0 | M | open |
| C-14 inventaris-API | CODE | P2 | S-M | open |
| C-15 Classic rng + lint | CODE | P2 | M | open |
| C-16 UX touch/tekst | CODE | P1 | M | wacht op §5.6 |
| C-17 CombatRules | CODE | P1 | L | na C-12, C-15 |
| A-1..A-4 art/audio | ART | P1 | — | A-4 wacht op §5.3 |
