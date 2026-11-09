# SAPIENTIA — professionele review (november 2026)

Basis: `main` op `db0aa04` (v0.20, versiecode 22). **Alleen een rapport, geen fixes.** Zes deelonderzoeken
(architectuur, prestaties op mobiel, save-systeem, combat & balans, UX/touch/tekst, content/netwerk/proces),
gevolgd door eigen verificatie van elke bevinding die hieronder als **hoog** staat. Regelnummers gelden voor `db0aa04`.

## 1. Oordeel in één alinea

Dit is een serieus, bovengemiddeld goed geëngineerd hobbyproject: 72k regels spelcode met 53k regels tests,
109 headless-suites, een atomisch save-systeem met backup en herstel, echte meetinstrumenten voor prestaties,
een gehard relay voor online co-op en strakke release-tooling (één versiebron, verplichte CHANGELOG). De zwakke
plekken zitten niet in slordigheid maar in **groei**: `game_state.gd` is een god object van 3340 regels, er zijn twee
gevechtssystemen met verschillende regels, 29 geregistreerde suites (waaronder de sterkste save-tests) draaien
niet in CI, en een paar ontwerpbeloftes op het scherm (MAG/MDEF, zwaktes) doen in het gevecht niets. Voor een
Play Store-release zijn vier dingen echt blokkerend (§3). De rest is onderhoud dat de codebase gezond houdt.

| Gebied | Cijfer | In één zin |
|---|:--:|---|
| Architectuur | 6,5 | Data netjes gescheiden, kamers delen een basis; GameState en battle/som_arena zijn te groot, geen inventaris-API. |
| Prestaties mobiel | 7 | Gefaseerd voorladen en budget-suite zijn sterk; twee kaarten boven budget, video 4x te groot, perf-docs spreken elkaar tegen. |
| Save & robuustheid | 7,5 | Atomisch schrijven + .bak + zichtbaar herstel is uitstekend; één gedeelde autosave over 4 slots is een echte dataverlies-bug. |
| Combat & balans | 6 | Pure regelmodules en een echte battlesim; MAG/MDEF/zwaktes doen niets, Classic vs Action rekenen anders, Chain Lightning domineert. |
| UX / touch / tekst | 7 | Tekst 100% Engels, telegraphs kleurenblind-veilig, veilig gebied centraal; opslaan wordt nergens uitgelegd, dev-knoppen op het titelscherm. |
| Content | 5 | WM1 compleet en gepolijst; acts 2-6 bestaan alleen als proza (±15-20% van het verhaalplan in het spel). |
| Netwerk / co-op | 7 | Relay is gehard (rate limits, codes, timeouts); host vertrouwt guest-input blind, relay kan crashen op id-overflow. |
| Proces / CI / release | 6,5 | Testcultuur en versiebeheer sterk; 29 suites buiten CI, 80 jobs per push, engineversie 4.3 vs 4.5+ voor Play. |

## 2. Top 12 acties, op volgorde

| # | Actie | Waarom | Inspanning |
|---|---|---|---|
| 1 | **Eén autosave per slot** (`autosave_<slot>.json`) of een waarschuwing als `home_slot != active_slot` | Nieuw spel in slot 3 overschrijft de autosave van slot 1; progressie sinds de laatste handmatige save is weg. `game_state.gd:1353, 1636` | M |
| 2 | **Save-suites in CI**: `savehardeningtest`, `coopguestsavetest`, `combatrngtest` + relay `npm test` | De sterkste save-tests (127 checks: .bak-fallback, byte-voor-byte round-trip, guards) beschermen nu niets. `docs/qa/SAVE_HARDENING.md:47` | S |
| 3 | **MAG, MDEF en zwak/resist laten meetellen** in `DamageCalc.spell_base` | Staven, gewaden, mage-groei en het bestiarium beloven iets dat het gevecht niet doet. `damage_calc.gd:32-34` | M |
| 4 | **Guest-input binden aan de afzender** in `action_coop_session.gd:218` (slot uit `_peer_to_slot`, één input per slot per tick, `lock_idx` clampen) | Een guest kan elke slot sturen, ook die van de host, en 4x zo snel bewegen (120 msg/s relay vs 30 Hz input). | M |
| 5 | **Dev-knoppen gaten** voor release: Beta Test / End State / SoM op het titelscherm via `ReleaseFlags` | Een nieuwe speler kan in een eindstaat landen. `title_screen.gd:188-214` (alleen PvP/Co-op zijn gegate, :357) | S |
| 6 | **Opslaan uitleggen**: eerste boek = korte uitleg; in het veldmenu "Save" grijs met reden "Find a glowing book" | Er is geen Save in het menu, autosave alleen bij wereld↔kerker; na een baas-winst kan alles weg zijn. `field_menu.gd:59-71, 488` | S |
| 7 | **Stun-lock dichten**: 1 beurt immuniteit na stun, AoE-stun ~15%, bazen halve kans | Chain Lightning (8 MP, alle vijanden, 30% stun, bazen niet immuun) maakt de rest van het spreukenboek irrelevant. `spells.gd:45`, `spell_rules.gd:95` | S |
| 8 | **Intro-video's her-encoderen** naar 360x640 | Nu 720x1280 Theora, 29,4 MB, CPU-decode op ARM; de code gaat zelf al uit van 360x640 (`worldmap_cutscene.gd:5`). | S |
| 9 | **`field_menu.gd` via preload/`MAIN_THREAD_SCRIPTS`** i.p.v. runtime `load()` in `map.gd:204` | 210 ms hapering bij het eerste menu wie snel Doorgaan tikt; waarschijnlijke oorzaak van de intermitterende hang in `--lifecycletest`. | S |
| 10 | **Inventaris/goud-API** (`add_item`, `remove_item`, `add_gold` + signaal) | 18 directe schrijfacties op `GameState.inventory`, 9 op `gold` buiten GameState; clamps en sync worden omzeild. | S-M |
| 11 | **Engineversie beslissen**: 4.5+ voor de AAB (16 KB pages, targetSdk 35+), CI daarop laten draaien | Nu 4.3 (project/CI), 4.5+ (AAB-eis) en 4.7.2 (web) tegelijk. `docs/release/PLAY_STORE.md:59-67` | L |
| 12 | **Relay-crash dichten**: `nextId` hergebruiken/cappen, handlers in try/catch, top-level crash-logger | `writeUInt16BE(peerId)` gooit boven 65535; join/leave-lus over 4 uur kamerleven haalt dat. `relay/src/relay.js:158, 210` | S |

## 3. Blokkerend voor een Play Store-release

1. Engineversie (actie 11) en de preset-verschillen: de Web- en AAB-presets missen de uitsluitingen van de APK-presets
   (`export_presets.cfg:153, 195` vs `:11`), dus testcode en web-export-plaatjes gaan mee in de AAB.
2. `package/unique_name="com.dennis.rpgprototype"` staat na de eerste upload voor altijd vast: nu kiezen.
3. Privacybeleid open (`PLAY_STORE.md:124`); INTERNET/WIFI-permissies moeten onder Data safety.
4. Licentie van de titelmuziek: `main_menu` is een Suno-track (`audio_manifest.json`); gratis Suno staat geen commercieel gebruik toe.

Verder: `net/relay_url=""` (`project.godot:108`), dus online co-op doet in builds niets; `ws://` wordt geaccepteerd
(`net_protocol.gd:188`), een release hoort `wss://` af te dwingen. Dev-knoppen (actie 5).

## 4. Bevindingen per gebied

### 4.1 Architectuur
- **GameState (3340 regels, 101 vars, 205 funcs) draagt ≥12 verantwoordelijkheden**: co-op (56-196), testdispatch (491-748),
  voorladen (772-952), party (984-1316), saves (1317-1940), `apply_state` (1941-2093), bootstraps (2140-2390), scènewissel,
  encounters, checkpoint, koopman/dungeon100, kern/codex. Splits in deze volgorde (laagste risico eerst): preloader →
  coop → testdispatch (`scripts/tests/test_registry.gd`, S) → save-store. Houd de GameState-API als dunne facade.
- **Impliciet contract GameState→Battle**: `battle.gd:215-471` leest negen losse `pending_*`-velden. Eén `battle_request`
  uit `prepare_battle()` maakt het expliciet (M).
- **Duck-typing**: 86x `has_method(` buiten tests; `map.gd` heeft geen `class_name`. `class_name FieldMap` + `is` (S).
- **Data-scripts die staat muteren**: 17 van 51 bestanden in `scripts/data/` raken GameState (shop_data 14x, archief2 11x,
  koopman_winkel 10x). Logica hoort niet in `data/` (M).
- **Testhelpers 103x gekopieerd** (`check`, `wait_until`, `tap`, `frames`): één `test_base.gd`, migreren bij aanraken (M).
- **Debug-ingangen zonder gate**: `--spiegel`, `--berggrot` (`game_state.gd:723-728`); `OS.is_debug_build()` naast
  `ReleaseFlags.is_debug_build()` in audio_manager/sessie_log/perf_probe omzeilt de testhaak (S).
- Positief: 0x `get_node("../`, content zit in data (hero-ids in logica: "dennis" 18x, vooral net/som), kamers delen
  `map.gd → DungeonRoom → Dungeon100Room`, release-vlaggen centraal, FlowState/`--statemachinetest` sinds #384.

### 4.2 Prestaties op mobiel
- **`dorp_wilgendal`**: 1679 nodes, 207 draw calls, S25-schatting 28,5 ms (>16,7). De v8-grondlaag wisselt 3 atlasbronnen
  per cel (−111 draw calls als hij uit staat); 268 `StaticBody2D`-bomen kosten 30-50 ms in de eerste physics-stap.
  Eén gebakken atlas + bomen als één physics-laag (M). `docs/perf/WM1_PERF.md`, `wm1_baseline.md`.
- **`woud_beek`**: 491 draw calls, 37,5 ms, RISK, maar niet in `wm1_perf_budget.gd` → regressie valt niet op (M).
- **Twee perf-documenten spreken elkaar tegen** (archief_ingang 145,5 vs 34,5 draw calls; wereldkaart 122,8 vs 23,6).
  Eén meetmethode vastleggen, budget-suite in CI (S).
- **Textures**: 22,3 MB voorgeladen bij opstarten; `docs/perf/voorstel_wm1_boot_preload.patch` brengt dat naar 10,6 MB
  en ligt klaar (S). Geen textures ≥2048 behalve `dennis_rug.png` 2100x210. Alle 1293 imports lossless, nearest, geen mipmaps: goed.
- **Audio**: 37 MB (25 ogg à 2,4-3,4 MB, 162 wav). BGM wordt synchroon geladen bij kaartwissel (`audio_manager.gd:649`):
  10-40 ms hapering op trage flash → `load_threaded_request` tijdens de fade; BGM naar ~96 kbps (M). SFX-cache onbegrensd.
- **Per-frame werk is verwaarloosbaar** (4-25 µs totaal). Kleine punten: `som_hud.gd:131` elk frame `queue_redraw`,
  `map.gd:288-307` loopt kinderen langs in `screen_open()`.
- **Accu**: geen 30 fps-stand; `AppLifecycle` regelt menu's en achtergrond goed (S).
- **APK**: arm64 92 MB, AAB ±118 MB; `art/battle_bg/boss.png` (654 KB) zit dubbel in de export (S).
- **N.B.** AGENTS.md zegt "er is nog géén audio": verouderd, er zijn 298 audiobestanden; 11 BGM-tracks uit het manifest ontbreken nog.

### 4.3 Save-systeem en robuustheid
- **Gedeelde autosave over 4 slots** (actie 1) is de enige echte dataverlies-bug. Geen test dekt dit.
- **`version` wordt geschreven, nooit gelezen** (`SAVE_VERSION := 1`, gs:216/1811): een save uit een nieuwere build laadt,
  onbekende sleutels vallen weg en worden teruggeschreven. Bij `version > SAVE_VERSION` waarschuwen en niet overschrijven (S).
- **Autosave-gaten**: alleen wereld↔kerker en pauze/sluiten; expliciet uit na winst, respawn en nieuw spel. Een crash
  op desktop verliest alles sinds de laatste overgang, inclusief kernen. Extra autosave bij story-step/kern terwijl `field_free()` (S/M).
- **Geneste waarden zonder typecheck**: `int(a2["platen"][k])` (gs:2042), `int(best[k].get("defeated",0))` (gs:1974):
  een gemanipuleerde save geeft SCRIPT ERROR halverwege `apply_state`. Fuzz-suites variëren alleen top-level (S).
- **Ontbrekende reparaties** (erkend in SAVE_HARDENING.md:39-40): dubbele hero-ids, item zowel in tas als uitgerust,
  `story_step` vs `story_flags`. **Molen** geeft onbeperkt Zingend Meel (marker als scene-meta, niet in de save) (S).
- **Determinisme**: `dungeon100_seed` wordt bewaard (goed); baas-loot gebruikt `rng.randomize()` (`battle.gd:2118`) en
  Classic draait op globale `randf()` → save-scummen van loot en uitkomsten mogelijk (S).
- **`save_game` heeft geen eigen guard**; alleen aanroepers blokkeren. Early return op `scene_busy()` (S).
- Positief: gelaagd atomisch schrijven (`.tmp` gevalideerd vóór rename, `.bak` nooit overschreven door een kapotte save,
  gs:1656-1686), zichtbaar herstel (`save_recovered`, "(backup)" in de slotlijst), defensieve `apply_state` met clamps en migraties.

### 4.4 Combat en balans
- **MAG/MDEF/zwak/resist doen niets** (actie 3; zelf geverifieerd: geen enkele lezing buiten UI/data/tests).
- **Twee regelstelsels**: Classic `atk·buff·mult − def/2` (`damage_calc.gd:28`) vs Action `(atk − def/2)·mult`
  (`som_arena.gd:785-788`); Action-spreuken slaan `token_mult` en `SpellRules.on_hit` over (geen DoT/stun), geen buffs,
  geen vluchten, aparte exp/loot (`som_arena.gd:1174` vs `battle.gd:2031`). Eén pure `CombatRules` met RNG als parameter (L).
- **Chain Lightning** domineert (actie 7). Rapportcijfers: Tweede Archief verdieping 2 gaat van 9% naar 23% HP-verlies
  zonder stun-spreuken; Diepe Grot 95 van 91% naar 78% winrate.
- **Classic niet deterministisch**: `randf()` voor snelheid (887), vijand-skills (1361), stun (1661), `pick_random` (1783),
  vluchten (1870), leech (1915), codex-AI; de statische RNG-lint scant alleen `scripts/som/`. Battle een `rng` geven zoals de arena (M).
- **Action-balanstools modelleren het gevecht** i.p.v. het te draaien (`action_sim.gd:289-316`); alleen `f5_sim.gd` gebruikt
  de echte arena met `seed_rng`. Ketens, zware slagen en telegraaftiming drijven weg van het model (M).
- **Uitschieters in BATTLE_BALANCE_REPORT.md** (31 okt, daarna 20 commits aan combat/data): Donker Woud normale groep
  (Root Crawler x2 + Spore Cap) 52% winrate en 90% HP-verlies, zwaarder dan de zonebaas (82%); Glitch Queen 58%, Root
  Emperor 65%; vijf eindbazen exact 100% in 4,0 beurten (script of cap?); verdiepingen 1, 5, 15 triviaal.
- **Tiers**: ATK +10 → +46 → +66 en HP x2,3 → x5,0 → x6,5 tussen tier 4-6 (`game_data.gd:1108-1116`); tier 7 exp x1,0 vs tier 1 x2,0.
- **Economie**: Herbal Tea 20g/40 HP slaat Potion 30g/30 HP strikt; trash drops 2-4 goud vs Short Sword 120 (40-60 gevechten).
- **Feel**: Action heeft hit-stop, telegraphs, damage numbers; Classic alleen shake. Geen input-buffer in beide (S).
- **Testgaten**: vluchtkansen (alleen geforceerd), stun-lock/immuniteit, DoT-stapeling, multi-target, buff-verloop, pariteit Classic/Action.
- Positief: battlesim op de echte `battle.tscn` (2000 gevechten per groep, HARD/TRIVIAL-vlaggen, A/B zonder stun); vaste
  60 Hz-klok met RNG-lint in Action; pure modules (SpellRules, DamageCalc, CombatSim) met roll-injectie.

### 4.5 UX, touch, tekst
- **Nederlands in spelertekst: 3 strings**, alle in PvP (`pvp/data/modes.gd:10-16`: "Vroeg", "Midden", "Hoog"), nu verborgen
  achter `online_cut`. De guard `KNOWN_DUTCH_PINNED` (`ux_tests.gd:84-88`) slaagt voor 2 van 3 alleen nog via commentaar: vervangen door `_code_only` (S).
- **Opslaan wordt niet uitgelegd** (actie 6). **Dev-knoppen op het titelscherm** (actie 5).
- **Touch-minimum ≈ 7,6 mm en toestelafhankelijk**: `UiTouch.TOUCH_MIN = 25` is 48 dp op een 411 dp-telefoon, 42 dp (6,7 mm)
  op 360 dp. Lijstrijen `ROW_H 16` ≈ 4,8 mm. Bereken uit `screen_get_dpi`, rijen ≥ 22 (M). A/B (11 mm) zijn goed.
- **Kleinste lettergrootte 8** (`som_hud.gd:63`, `som_fx.gd:336`, ≈2 mm regelhoogte); geen tekstgrootte-optie (M).
- **CRT/glitch standaard aan** (`settings.gd:58`): scanlines over een 10 px-font en flitsen zonder reduce-flash-optie.
  Standaard uit of splitsen in Scanlines / Glitch (S).
- **Geen bewegingstutorial** (joystick/A/B/MENU/RUN wordt nergens genoemd); **cutscenes niet te skippen**; **geen haptics,
  geen linkshandige lay-out**; **TEXT_OFF #6c6455 op #120f1a ≈ 3,2:1** (grijze items slecht zichtbaar in daglicht); **geen
  laadindicator** na de 0,3 s fade.
- Taps: genezen 4, uitrusten 5 (geen "Optimize"), opslaan 3-5. Bevestigingen in balans.
- Positief: telegraphs niet alleen op kleur (arcering + "!"), één centrale touch/safe-area-regel met matrixtest over 5
  aspectratio's, ~5600 strings gescand en 100% Engels met regressielijst, tutorialteksten gecheckt tegen echte menupaden.

### 4.6 Content
- **Verhaal**: story-steps eindigen bij `NOOR_GERED = 120`, ±106 `say`-regels; alle 50 kaarten horen bij WM1; WM2/WM3
  bestaan niet; acts 2-6 alleen als proza (`docs/lore/Verhaal_Act2_tot_6.md`). Schatting: 15-20% van het verhaalplan.
- **Placeholders**: 123 open art-entries (54 KLAAR) in `tools/placeholders_v17.txt`; 1103 definitieve bestanden in
  `handwerk.txt`; 120 synthetische actor-SFX + 162 placeholder-SFX; 11 BGM-tracks ontbreken.
- **Geen algemene referentiecheck** op story-data (`story.gd:358` alleen een warning bij een onbekend commando; `catalogus_tests.gd:232`
  checkt enkele `give`-events). Steekproef nu: geen kapotte verwijzingen. Een data-check-suite over alle EVENTS/quests/spawns (S-M).
- `archief_tests.gd:706` asserteert dat een `TODO(design)`-commentaar bestaat: een test die een placeholder vastzet.
- 17x `TODO(design)`, 55x TODO/FIXME in `scripts/` (excl. tests).

### 4.7 Netwerk en co-op
- **Host vertrouwt guest-input blind** (actie 4; zelf geverifieerd: `net_codec.gd:55` neemt `slot` uit `raw[0]`,
  `action_coop_session.gd:218-221` zet alles ongecontroleerd in de wachtrij terwijl `_peer_to_slot` bestaat).
- **Relay id-overflow** (actie 12; `room.nextId++` zonder hergebruik, `writeUInt16BE` op regel 210).
- Positief: per-verbinding limieten op berichten en bytes, per-IP limieten (create 10/min, join 30/min, 32 verbindingen),
  2 KiB frame-limiet, handshake-timeout, slow-consumer kick, kamer-opruiming, guests kunnen alleen naar de host sturen,
  6-tekencode uit een verwarringsvrij alfabet (31^6 ≈ 887M), geen IP-logging. Secrets: schoon (lege keystore-velden,
  `secrets.ANDROID_*`, geen tokens gevonden).

### 4.8 Proces, CI, docs, release
- **29 suites buiten CI** (dispatcher 109 flags, matrix 80): aab, berggrotdex, combatrng, combatsim, coopguestsave, demofix,
  kasdeur, lifecycle, perf, perfwm1, playtestkit, relay, savehardening, sessiefix, telegraphcoop, uipolish, uxpolish, ux, zone
  en 10 `wm1*`. Plus `relay/npm test` in geen enkele workflow.
- **CI-kosten**: 80 jobs, elk `apt-get` + volledige `--import` (tot 600 s) vóór één suite; schatting 4-8 runner-uren per push,
  tegen `PLAN.md:9` ("geen GitHub Actions-minuten"). ±8 shards van ±10 suites met één import en een `.godot`-cache (M).
- **Build-output in git**: `export/web/index.wasm` (38,6 MB) en een verouderde `.pck`; `.git` is 93 MB. Uit git, video/ogg naar LFS (S).
- **Docs**: 21 root-level .md (14x HANDOFF_*), `HANDOFF_ARCHIEF1.md` dubbel (root én docs/), TODO.md 1169 regels, README heet
  "Lufia Prototype" en stopt bij v0.19, arm64-preset schrijft nog `rpg_prototype_v0.19_arm64.apk`, verwijzingen naar
  `/workspace/v17_ART_SLOTS.md` buiten de repo. CHANGELOG is wél op orde.
- **Git-geschiedenis is plat**: 51 commits sinds 31 okt 2026, één auteur. Snelheid of blame valt hieruit niet te lezen.
- **`--lifecycletest` hangt intermitterend** (niet in CI): hoofdthread wacht op een futex terwijl één worker draait, tijdens
  de runtime-`load()` van `field_menu.gd`. Reproduceerbaar op `main` (dus niet door #384). Zie actie 9.
- Positief: `version.json` als enige bron, `bump_version --check`, targetSdk 36 en arm64-only alvast; flakes krijgen een
  root-cause-document (`O4_BERGGROT_FLAKE.md`: 29/80 → 0).

## 5. Voorgestelde volgorde

**Week 1 (alles S, geen risico):** acties 2, 5, 6, 7, 8, 9, 12; presets gelijktrekken; `export/web` uit git; SAVE-version-guard;
`save_game`-guard; Molen-marker in de save; `KNOWN_DUTCH_PINNED` vervangen.
**Week 2-3 (M):** acties 1, 3, 4, 10; `dorp_wilgendal`-atlas; `woud_beek` in het budget; perf-docs één meetmethode; BGM threaded laden;
Classic op een eigen `rng` + RNG-lint over `scripts/battle/`; Play Store-beslissingen (package-naam, privacy, Suno-licentie).
**Daarna (L):** engineversie 4.5+ met CI; `CombatRules` als gedeelde kern; GameState splitsen (preloader → coop → testregistry → save-store);
content acts 2+.

## 6. Hoe geverifieerd

- Zes parallelle, alleen-lezen onderzoeken op `db0aa04`, elk met opdracht om alleen bevindingen met `bestand:regel` te melden.
- Zelf nagelopen vóór opname als **hoog**: geen lezing van `mag`/`mdef`/`weak`/`resist` in combat-code (grep over `scripts/`
  excl. UI/data/tests); `unpack_input` en `_handle_raw_packet` (guest-slot); `room.nextId++`/`writeUInt16BE` in de relay;
  de ongegate titelknoppen; de `lifecycletest`-hang gereproduceerd op een verse `main`-worktree met threaddump.
- Metingen (draw calls, ms, MB) komen uit de perf-documenten en `ffprobe`/`du` in de repo, niet van een echt toestel.
  De balansgetallen dateren van 31 oktober; daarna zijn er 20 commits aan combat/data geweest. Herdraai de battlesim vóór je op §4.4 tuned.
- Dit rapport raakt geen code. Elke actie hierboven past in een eigen kleine PR met een test, zoals AGENTS.md vraagt.
