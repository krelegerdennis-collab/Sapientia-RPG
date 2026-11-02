# D3 — Golem als realtime Action-baas (ontwerp, besluiten genomen)

Status: **gebouwd (PR B)**; besluiten van Dennis vastgelegd (31 okt 2026 20:38, "go" op alle 5 aanbevelingen, zie §7). Basis: verse clone `origin/main` @ `571a93e` (31 okt 2026). Alleen WM1; `wacht/wm2/` niet gelezen.
Legenda: **[V]** = geverifieerd in code (bestand:regel), **[NV]** = niet geverifieerd / voorstel.

## 1. Huidige stand (geverifieerd)

- **Bazen uitgesloten van Action** [V]: `scripts/som/som_arena.gd:366` — `if m == null or m.boss or enemies.has(m): return` in `register()`. COMBAT_DESIGN §12 noemt nog `:228` (verouderd regelnummer).
- **Besluit** [V]: commit `213c3d3` (21 okt 2026, "bazen altijd turn-based (geen Action-vermenigvuldiger)"); `scripts/data/som_data.gd:4-5`: bazen blijven ALTIJD turn-based, `ACTION_BOSS_MULT` wordt niet meer gebruikt.
- **Bestaande action_boss-code** [V]:
  - `som_data.gd:362-363` `ACTION_BOSS_MULT = {max_hp: 2.3, atk: 1.6}`, `ACTION_BOSS_PER_LEVEL = {atk: 0.35}`; `:365` `action_boss_override`; `:369` `action_boss(data, on, party_level)`; `:381` `action_boss_mult()`.
  - `scripts/battle/battle.gd:389` `action_boss_on()` (som_mode of Settings.action_battles, niet in dungeon100).
  - `action_boss(` wordt alleen aangeroepen in `scripts/tests/som_autotest.gd:1046,1077` (geen productie-aanroeper gevonden met rg).
  - `tools/battlesim/action_sim.gd:23` `TARGET_BOSS := [0.60, 0.80]`; `:310-363` `BOSS_ITERATIONS`/`_bosses()` = turn-based Golem met vermenigvuldiger via BattleSim (geen realtime baas).
  - `--actionsim` geregistreerd in `scripts/game_state.gd:509,658`.
- **BossCore** [V]: `scripts/battle/boss_core.gd` (rondegebaseerd: elke `cycle`-de ronde kern open, `closed_mult` 0.4, `open_mult` 2.0, `break_damage`, Hamerslag `slam_power` 2.2; `apply_boss()` :72). Beeld: `boss_core_view.gd`. Gebruikt in `battle.gd:113,118,414`.
- **Golem-stats (blijven ONGEWIJZIGD)** [V] `scripts/data/game_data.gd:176-221`, id `kennis_beest`:
  - basis: HP 46, ATK 14, DEF 7, AGI 6;
  - `boss` (:206): HP 360, ATK 27, DEF 15, AGI 6, MAG 11, MDEF 13, EXP 210, GOLD 84; skill Book Hammer (0.2, power 1.5);
  - `core`: cycle 3, closed 0.4, open 2.0, break_damage 45, slam_power 2.2, rect [82,52,30,30].
  - Let op: commentaar zegt doel-level Eerste Archief = 7 (`EERSTE_ARCHIEF_DOEL`); besluit: doel 60-80% win op Lv 7, Lv 3 alleen als rapport → zie §7 Besluit 1.
- **Dodge** [V] `som_data.gd:88-95`: `DODGE_DURATION_TICKS` 13, `DODGE_IFRAME_TICKS` 15, `DODGE_COOLDOWN_TICKS` 9, `DODGE_DISTANCE_PX` 28, `STAMINA_DODGE_COST` 30; `PLAYER_IFRAMES` 0.8 s (:299). Toepassing `som_arena.gd:1604-1619`.
- **Ticks** [V] `scripts/som/combat_sim.gd:9-10`: `TICK_HZ = 60`, vaste stap.
- **Telegrafen** [V]: `telegraph_attack.gd` (`TelegraphAttack`), `telegraph_layer.gd:29` `Style {RED_DODGE, YELLOW_INTERRUPT}`, `enemy_attacks.gd` (`EnemyAttacks`), `SomActionAttacks` in `register()`.
- **COMBAT_DESIGN D3** [V] `docs/combat/COMBAT_DESIGN.md:40` (bazen realtime in Action/co-op, Classic turn-based) en §12 (:176): `BossScript` met `phases: [{hp_until, attacks, adds, on_enter}]`, 1.5 s onkwetsbare fasewissel, optionele enrage, hook `boss_party_scale(n)`, Codex blijft bazen weigeren. §11: windup ≥0.4 s, ≥0.6 s voor AoE >3 tegels; rood=ontwijken, geel=onderbreekbaar. `BossScript`/`boss_party_scale` bestaan nog **niet** in code [V].

## 2. Golem-gevecht in Action (voorstel [NV])

Stats ongewijzigd (HP 360 etc.). Moeilijkheid komt uit patronen en de kern, niet uit nieuwe getallen. De kern wordt realtime: tijd i.p.v. rondes.
Alle tijden in ticks @60 Hz. Windup ≥ 24 ticks (0.4 s); AoE > 3 tegels ≥ 36 ticks. Dodge-iframes (15 ticks) moeten de actieve hitframe (≤ 6 ticks) ruim afdekken.

### Fase 1 — "Bewaker" (HP 100% → 60%)
| Aanval | Telegraaf | Windup | Actief | Herstel | Ontwijken |
|---|---|---|---|---|---|
| `golem_sweep` (melee_arc 120°, 2 tegels) | rood boog | 30 | 4 | 30 | dodge uit de boog of erachter |
| `golem_book_hammer` (cirkel r=1.5 tegel op doel) | rood cirkel | 36 | 4 | 40 | dodge zijwaarts |
| `golem_core_charge` (kern open, zie onder) | roze gloed + gele ring | 120 | — | — | onderbreekbaar met schade |
Kern open (`core_charge`): 2 s venster, schade ×`open_mult`; daarbuiten ×`closed_mult`. ≥ `break_damage` (45) in het venster → stagger 60 ticks; anders `golem_hammer_blow` (AoE r=3, 42 ticks windup, ATK×`slam_power`). Vaste cyclus van 8 s met 2 s open in **elke** fase (realtime-vertaling van `cycle` 3), break 45 (§7 Besluit 2).

### Fase 2 — "Ontwaakt" (60% → 25%)
- Overgang: 90 ticks (1.5 s) onkwetsbaar + knielanimatie; lopende telegrafen vervallen; spelers krijgen niets.
- Aanvallen: `golem_sweep` (windup 26), `golem_shockwave` (lijn 5 tegels, 3 parallel, windup 36), `golem_core_charge` (zelfde vaste cyclus: 8 s, 2 s open), plus 2 `papiergeest`-adds bij binnenkomst (bestaande vijand, encounter-groep `game_data.gd:1293`).

### Fase 3 — "Overbelast" (25% → 0)
- Overgang: 90 ticks onkwetsbaar; vloer krijgt 2 vaste rune-vlakken (rood, permanent zichtbaar).
- Aanvallen: `golem_sweep`, `golem_book_hammer` ×2 achter elkaar (36 + 24), `golem_hammer_blow` zonder kernvenster bij hp<10% één keer (rood, 48 ticks windup), `golem_core_charge` (zelfde vaste cyclus: 8 s, 2 s open). Geen nieuwe adds.
- Geen enrage in v1 (§7 Besluit 5).

Mobiel leesbaar: telegraaf-vormen ≥ 1 tegel, contrast-rand, geen fijne tekst; maximaal 2 gelijktijdige telegrafen van de baas.

## 3. Migratie en PR-split

**PR A — RPG CODE (basis):**
1. `som_arena.gd:366`: `m.boss` alleen uitsluiten als geen `BossScript` voor `m.enemy_id` bestaat (Classic onveranderd: daar komt `register` niet).
2. Nieuw `scripts/som/boss_script.gd` (data-loader) + `scripts/som/boss_phase_machine.gd` (pure RefCounted, tick-gedreven: `tick()`, `on_damage()`, fase-index, invuln-ticks, events).
3. Baas-stats in Action = `BossCore.apply_boss(data)` zonder vermenigvuldiger; `boss_party_scale(n)` hook (return 1.0).
4. `som_data.gd:4-5`-commentaar + `ACTION_BOSS_MULT` markeren als vervallen (niet verwijderen in PR A; verwijderen pas in PR B, §7 Besluit 4).
5. Headless test, met een dummy-baas met 2 fases.

**PR B — COMBAT (Golem):**
1. `BossScript` data voor `kennis_beest` (fases hierboven), nieuwe aanval-ids in `enemy_attacks.gd`/`SomActionAttacks`.
2. Realtime kern (`boss_core.gd` uitbreiden met tick-variant óf aparte `boss_core_rt.gd`; ronde-API blijft voor Classic).
3. `action_sim.gd`: realtime baasmodus (`--actionsim --boss-rt`), vervangt `_bosses()` niet maar staat ernaast.
4. `ACTION_BOSS_MULT` verwijderen (zie §7 Besluit 4).
5. Golem-tests + simrapport in `docs/ACTION_BALANCE_REPORT.md`.

## 4. Battle-sim (`--actionsim`)

200 runs per scenario (`--boss-fights=200`), seeded. Party = WM1-party op Lv 7 (doel); Lv 3 en Lv 5 alleen als rapport.
Meten: win% (doel 60-80% op Lv 7; Lv 3 alleen gerapporteerd), party-HP-verlies % (gemiddelde + p90), gevechtsduur (s; doel 90-180 s [NV]), doden per fase (F1/F2/F3), dodge-succes (= ontweken treffers / telegrafen gericht op held), kern-breaks per venster. Sim-beleid gebruikt bestaande `dodge_player` 0.35 / `dodge_ally` 0.15 (`action_sim.gd:86`) plus een "goede speler"-profiel (0.7).

## 5. Geplande tests (alleen nieuwe bestanden)

- `scripts/tests/boss_phase_tests.gd` (PR A): drempels, 90-ticks invuln, geen dubbele fasewissel bij overkill, determinisme (zelfde seed → zelfde event-log), Classic-pad ongewijzigd (`register` weigert baas zonder BossScript).
- `scripts/tests/golem_action_tests.gd` (PR B): windups ≥ 24/36 ticks, dodge-iframes (15) dekken elke actieve fase, kern-venster 8 s cyclus / 2 s open in alle fases en break 45, adds alleen bij fase 2, stats gelijk aan `game_data.gd:206`.
- `scripts/tests/golem_actionsim_tests.gd` (PR B): kleine sim (20 runs) binnen ruime band als rookproef.
- `tests.yml` en bestaande tests (`golem_tests.gd`, `som_autotest.gd`, `kern_tests.gd`) **onaangeroerd** tenzij Dennis akkoord geeft. Let op: `som_autotest.gd:1046,1077` testen `action_boss()`; die blijven geldig zolang de functie blijft.

## 6. Netcode en performance

- Host-authoritatief: alleen de host draait `boss_phase_machine` en kiest aanvallen met de seeded sim-RNG (COMBAT_DESIGN §16). Gasten krijgen events: `boss_phase(i)`, `telegraph_start(id, tick, shape)`, `core_open/close`, `boss_hit`.
- Telegraaf-events dragen de start-tick; gasten tekenen vanaf die tick zodat de windup ook met latency klopt (bij >windup/2 latency: verkort tonen, nooit later dan de hit).
- Treffer-bepaling bij de host op ticks, deterministisch; hitstop/shake alleen visueel (§13).
- 60 fps mobiel: geen allocaties per tick in de fase-machine, max 2 baas-telegrafen + 2 adds, telegraaf-vormen hergebruiken (`telegraph_layer.gd`). Meten met bestaande `PerfProbe` (`battle.gd:200`) [NV of die in som_arena werkt].

## 7. Besluiten

Besluit Dennis, 31 okt 2026 20:38: **"go" op alle 5 aanbevelingen.**

1. **Doel-level:** win% 60-80% op **Lv 7**; Lv 3 wordt alleen gerapporteerd (geen doel).
2. **Kern realtime:** tijdvenster van **8 s** cyclus, waarvan **2 s open**, break **45**.
3. **Adds in fase 2:** **2 `papiergeest`**.
4. **ACTION_BOSS_MULT:** blijft staan (ongebruikt) en wordt **pas in PR B** verwijderd, niet in PR A.
5. **Enrage:** **geen enrage** in v1.

Besluit Dennis, 31 okt 2026 22:16 (PR B, geen stat-wijzigingen):
6. **Schadeplafond per fase:** schade wordt afgekapt op de fasedrempel; overschot vervalt.
7. **Kern-cyclus reset niet** bij een fasewissel: de 8 s/2 s-klok loopt door de overgang heen.

## 8. PR B — status (gebouwd, balans = voorstel)

- Data: `scripts/som/golem_boss.gd` (fases, aanvallen in ticks, kern, sprites #341); registratie via `GolemBoss.ensure_registered()`.
- Logica: `scripts/som/golem_fight.gd` (host, deterministisch) + `scripts/som/boss_core_rt.gd` (8 s cyclus, 2 s open, break 45; vaste klok die ook tijdens de 90 onkwetsbare ticks doorloopt; een fasewissel reset de cyclus NIET).
- Schadeplafond: schade op de Golem wordt afgekapt op de drempel van de huidige fase (overschot vervalt), zodat één kernvenster-burst nooit voorbij een drempel gaat (Dennis, 31 okt 2026 22:16).
- Beeld: `scripts/som/golem_boss_view.gd`. Golem-aanvallen ook via `EnemyAttacks.attack()` (ms/px-vorm), zonder vijand-pool.
- `ACTION_BOSS_MULT`/`ACTION_BOSS_PER_LEVEL`/`action_boss_override` verwijderd; `action_boss()`/`action_boss_mult()` alleen nog als bevroren legacy voor bestaande tests (zie som_data.gd).
- Sim: `-- --actionsim --boss-rt [--boss-fights=200] [--boss-levels=7,3]` → `docs/combat/d3_golem_sim_report.md`.
- Tests: `--golemactiontest`, `--golemactionsimtest` (nieuw; `--golemtest` bestond al voor golem_tests.gd).
