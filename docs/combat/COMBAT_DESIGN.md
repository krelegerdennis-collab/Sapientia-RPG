# COMBAT_DESIGN — Action-combat (solo + 4-speler co-op)

Status: ontwerp, docs only. Basis: `main` @ `61986e9` (na PR #208 power scaling v2).
Analyse vooraf: fase 0 (feiten met regelnummers, samengevat in §2 en §19).
Regelnummers verwijzen naar `main` @ `61986e9`.

**Balansgetallen** (monster-/baas-stats, HP-schaal, schade-multipliers per kamer/tier) zijn van het fase 5-balanswerk (PR #208). Dit document zet daar **geen** getallen voor neer. Waar het over balans gaat, verwijst het naar:
- `scripts/data/game_data.gd`
- `scripts/data/som_data.gd` (`enemy_damage_mult`, `attack_cooldown`, tier-tabellen)
- `scripts/data/dungeon100_scaling.gd`
- `docs/BATTLE_BALANCE_REPORT.md`
- `docs/ACTION_BALANCE_REPORT.md`

De getallen die hier wél staan (dodge, stamina, revive, threat) zijn nieuwe mechaniek-constanten. Ze zijn startwaarden die de battle-sim later bijstelt.

---

## 1. Visie en pijlers

Een realtime 16-bit gevecht in de stijl van Secret of Mana. Je speelt het op een telefoon, solo of met maximaal 4 spelers samen.

Pijlers:
1. **Leesbaar.** Elke vijandaanval is getelegrafeerd. Een klein scherm mag nooit oneerlijk voelen.
2. **Samen sterker.** Rollen, threat, combo's en revive belonen teamwork.
3. **Eén telefoon is de baas.** Host-autoritair, deterministisch en testbaar.
4. **Solo = co-op met AI.** Hetzelfde systeem; lege stoelen vult de AI.

## 2. Scope en fasering

- **Nu:** Action in de WM1-archiefkamers (`som_data.gd:12`), LAN-co-op (fase B, `docs/fase_b/ARCHITECTUUR.md`).
- **Dit ontwerp:** fase C/D, met online relay, AI-stoelen, rollen, realtime bazen en loot per speler.
- **Buiten scope:** Classic (turn-based, `scripts/battle/battle.gd`) blijft zoals het is. PvP (`pvp/`) blijft een aparte ingang (fase B DEC 10 blijft staan). World Map 2 staat in de wacht en valt erbuiten.

### Besluiten (DECISION, approved by Dennis 2026-10-24)

| # | Besluit | Vervangt |
|---|---|---|
| D1 | **Relay:** eigen kleine relay-server (VPS). Zie §3. | `pvp/scripts/net/lan_transport.gd:4` TODO "relay niet gekozen" |
| D2 | **Rollen:** Dax = tank, Seren = heal, Vesper = control, Kael en Orion = dps. Orion is kiesbaar in co-op. | **fase B DECISION 1** (Orion niet in co-op; vaste toewijzing host=Dax) |
| D3 | **Bazen realtime** in Action/co-op, met fases. Turn-based alleen in Classic. | **fase B DECISION 8** + **besluit 21 okt 2026** (`som_data.gd:4-5`: bazen altijd turn-based) |
| D4 | **AI op lege stoelen** vanaf de co-op MVP. Wie joint, neemt de held over. | **fase B DECISION 2** (lege stoel blijft leeg tot fase C) |
| D5 | **Actieve dodge** met i-frames, plus een stamina-balk voor dodge en sprint. De charge-meter blijft voor aanvallen. | — (nieuw) |
| D6 | **Down/revive:** down-state met bleed-timer, revive door een teamgenoot. Feniksveer blijft instant. | — (nieuw) |
| D7 | **Determinisme:** host-autoritair met een pure, seeded fixed tick. Geen rollback of lockstep. | — (concretiseert fase B stap 4) |
| D8 | **Loot/voortgang per speler:** instanced loot. EXP en Codex gaan mee naar de save van de gast, plus een teamwork-bonus. | **fase B DECISION 3** (alleen de save van de host telt) |

De overige fase B-besluiten (4 ring zonder pauze in co-op, 5 host op slot, 6 gast weg, 7 sandbox-save, 9 lock per speler, 10 twee ingangen) blijven gelden.
Bij DEC 6 komt erbij: als een gast weggaat, neemt de AI zijn held over (D4).

## 3. Netwerkmodel

- **Autoriteit:** de host-telefoon draait de sim (stoel 0). Gasten sturen alleen input en tekenen snapshots met interpolatie.
- **Klok:**
  - de sim draait op `SIM_HZ` 60, snapshots op 20 Hz, input op 30 Hz;
  - de interpolatievertraging is 100 ms (`scripts/net/net_protocol.gd`);
  - de pakketformaten van `net_codec.gd` blijven, met uitbreiding voor stamina, threat-doel, down-state en fase.
- **Transport:**
  - LAN: ENet zoals nu (38421-38423);
  - online: via de **relay van RPG Forge**. Die zit tussen host en gasten en stuurt pakketten opaak door, zonder spellogica en zonder state.
- **Relay-contract** (afgestemd op het relay-werk van RPG Forge):
  - de host vraagt een **kamercode van 6 tekens** aan (A-Z/2-9, zonder 0/O/1/I);
  - een kamer telt **maximaal 4 deelnemers** (host + 3). Een vijfde krijgt `REFUSE FULL`, net als `ENET_REFUSE_SLACK` nu;
  - de relay kent een `slot` per verbinding en zet dat in elk doorgestuurd frame, zodat de host de afzender weet. Gasten kunnen elkaar niet direct adresseren;
  - een kamer vervalt als de host wegvalt (fase B DEC 5 blijft: geen host-migratie);
  - in het binaire `INPUT`/`SNAPSHOT`-formaat verandert niets. De relay ziet alleen bytes.
- **Abstractie:** een `CoopTransport`-interface (`send(slot, bytes)`, `poll()`) met twee implementaties, `EnetLanTransport` en `RelayTransport`. `ActionCoopSession` kent alleen de interface.
- **Bandbreedte:** het plafond is 4 spelers + 8 vijanden per snapshot (`SNAPSHOT_ENEMY_BUDGET`). Bazen krijgen een eigen record (fase, telegraaf-id, timer).
- **Vertrouwen:** de host valideert input (stick ≤ 1, cooldowns, stamina). Gasten melden nooit schade of buit.

## 4. Stoelen en AI-invulling (D4)

- Elke stoel heeft een `controller`: `local`, `remote` of `ai`. Een lege stoel = `ai` met een `SomAlly`-brein (`scripts/som/som_ally.gd`), dat draait op de host.
- **Join:** de AI-held wordt op de volgende tick `remote`, zonder teleport en met dezelfde HP/MP.
- **Leave/linkverlies:** dezelfde tick terug naar `ai`.
- **Rolgedrag van de AI** (uitbreiding van `_think_spell`, `som_ally.gd:167`):

| Rol | Eerste prioriteit | Tweede | Derde |
|---|---|---|---|
| Tank | Taunt als een niet-tank het doel is | Guard bij een telegraaf | Slaan |
| Heal | Revive (§10) | Heal onder de drempel | Buff/slaan |
| Control | Onderbreken van een telegraaf (stun/slow) | Debuff | Slaan |
| Dps | Combo afmaken (§9) | Slaan op het tank-doel | Ontwijken |

- De AI gebruikt dezelfde inputs als een speler (virtuele stick + knoppen). Zo blijft hij binnen dezelfde regels en blijft hij deterministisch.

## 5. Helden en rollen (D2)

Kit = basisslag + 2 rolskills + passief + finisher-bijdrage. Skill-schade en kosten volgen de bestaande spreuk- en skilldata (`scripts/data/spells.gd`, `GameData.SPELLS`/skills). Getallen daarvoor zijn van het balanswerk (#208).

| Held (id) | Rol | Skill 1 | Skill 2 | Passief | Finisher-bijdrage |
|---|---|---|---|---|---|
| Dax (`dennis`) | Tank | **Uitdaging:** taunt in een straal, threat-boost | **Schildwal:** guard frontaal, −dmg, stamina-kosten | Hogere threat-gain | Opener (breekt guard/ruptuur) |
| Seren (`lotte`) | Heal | Bestaande heal-spreuk | **Herstelzegel:** AoE-regen op de grond | Revive 40% sneller | Bindt (verlengt het finisher-venster) |
| Vesper (`noor`) | Control | **Stilstand:** stun/slow (`SpellRules.STUN_CHANCE` blijft van balans) | **Breekpunt:** onderbreekt een telegraaf | Debuffs duren langer | Zet elementlabel |
| Kael (`kael`) | Dps (range, prisma) | **Prismastraal:** lijn-AoE | **Overlading:** volgende slag ×charge-bonus | Bonus op een gelabeld doel | Ontsteker (element-combo) |
| Orion (`orion`) | Dps (range, boog) | **Salvo:** 3 pijlen in een waaier | **Merkpijl:** doel krijgt +kwetsbaar | Bonus op afstand | Afmaker |

Rollen staan vast per held. Wisselen van held (Swap, `som_arena.gd:317`) is solo-only. In co-op heeft elke stoel één held.

## 6. Kernloop van een gevecht

1. Bewegen (analoge stick, `touch_controls.gd`), doel kiezen (lock per stoel, `som_target_lock.gd`).
2. Slaan wanneer de charge-meter vol is (`CHARGE_TIME`, `charge_mult`; bestaande regels in `som_arena.gd:437-462`).
3. Skills via het ringmenu. In co-op is de ring nooit een pauze (fase B DEC 4). Voor solo blijft pauzeren mogelijk.
4. Ontwijken (§7), threat beheren (§8), combo's bouwen (§9), elkaar oprapen (§10).

## 7. Verdediging: dodge, i-frames, stamina (D5)

Nieuwe constanten (`som_data.gd`, blok `DODGE_*`/`STAMINA_*`). Dit is mechaniek en raakt de #208-balans niet:

| Constante | Start | Toelichting |
|---|---|---|
| `DODGE_IFRAMES` | 0.25 s | Onkwetsbaar vanaf tick 2 van de roll |
| `DODGE_DURATION` | 0.35 s | Rolafstand ≈ 28 px (1.75 tegel) |
| `DODGE_COOLDOWN` | 0.15 s | Na het einde van de roll |
| `STAMINA_MAX` | 100 | Per held, rolbonus Tank +20 |
| `STAMINA_DODGE` | 35 | Kosten per roll |
| `STAMINA_SPRINT` | 25/s | De bestaande RUN-knop kost stamina in Action |
| `STAMINA_GUARD` | 15/s + 10 per geblokte klap | Alleen bij Dax' Schildwal |
| `STAMINA_REGEN` | 30/s na 0.6 s zonder verbruik | |
| `PERFECT_DODGE_WINDOW` | 0.1 s voor de impact | +25 charge, begin van een combo-label |

- De bestaande passieve iframes na een treffer (`PLAYER_IFRAMES`, `som_data.gd:284`) blijven als hit-invuln. De dodge-pose (`_dodge`, `som_arena.gd:849`) wordt de roll-animatie.
- Touch: een nieuwe **B = Dodge** (richting = stick, anders weg van het doel). Het input-bitveld krijgt `BTN_DODGE`.

## 8. Aggro en threat

Vervangt `_target_for` (`som_arena.gd:733`), die nu in co-op altijd stoel 0 kiest.

- Elke vijand houdt een `threat[slot]` bij.
- **Bronnen:**
  - schade × 1.0;
  - heal × 0.5 (verdeeld over vijanden in bereik);
  - taunt = zet op max + 50%, 4 s lang vastgezet;
  - Tank-passief × 1.5.
- **Verval:** −10%/s buiten het bereik van de vijand. KO of down = 0.
- **Doelwissel:** een nieuwe kandidaat moet ≥ 110% van het huidige doel halen (melee) of ≥ 130% (range). Er wordt alleen gekozen tussen telegrafen, nooit midden in een telegraaf.
- **Afstand:** binnen 2 tegels telt +20%. Zo blijft solo "dichtstbij" ongeveer zoals nu.
- Debug/HUD: een klein icoon boven de held die het doel is.

## 9. Combo's en teamfinishers

- **Labels:** een treffer kan een label zetten op een vijand (`brand`, `bevroren`, `gemerkt`, `wankel`) voor 3 s. Een ander element of een andere held die erop slaat, triggert een **combo** (extra effect, bonusschade volgens de #208-balans, plus team-meter).
- **Combo-tabel** (voorbeelden):
  - `brand` + bliksem = ontploffing (AoE);
  - `bevroren` + fysiek = verbrijzelen (stagger);
  - `gemerkt` + Orion = crit.
- **Team-meter:** gedeeld, 0-100. Stijgt bij combo's, perfect dodges en revives.
- **Teamfinisher:**
  - bij 100 kan elke speler starten, daarna is er een venster van 3 s waarin de anderen hun knop drukken;
  - hoe meer deelnemers, hoe groter het effect (1-4);
  - AI-stoelen doen automatisch mee;
  - tijdens de finisher is er korte hitstop en een camera-zoom (§13).

## 10. Down en revive (D6)

- Bij 0 HP gaat een held **down**, niet direct KO.
- **Bleed-timer:** 15 s, in die tijd kruipen op 25% snelheid. Daarna KO (zoals nu `_member_ko`, `som_arena.gd:860`).
- **Revive:** een teamgenoot staat 2.0 s binnen 1 tegel (Seren: 1.2 s). Een treffer op de reviver breekt de revive af. Je komt terug met 30% max HP en 1 s i-frames.
- De Feniksveer (`revive`-items, `som_arena.gd:904`) blijft een instant revive, ook op KO.
- **Party down:** iedereen down of KO = het bestaande `_party_down` (`:871`).
- Een AI-healer heeft revive als eerste prioriteit (§4).

## 11. Vijand-AI en telegrafen

Generaliseert de huidige telegraaf (`_enemy_ai`, `som_arena.gd:751-786`).

- **Aanval-data:** elke vijand krijgt een lijst `attacks: [{id, shape, windup, active, recovery, reach, weight}]`.
  - `shape` is één van `melee_arc`, `line`, `circle`, `cone`, `ground_ring`.
  - Windup en recovery zijn mechaniek-timing. Schade en cooldown blijven bij de balans (#208, `attack_cooldown`).
- **Telegraaf op de grond:** een vorm in een vaste kleur (rood = ontwijken, geel = onderbreekbaar, paars = alleen tank/guard). De windup is minimaal 0.4 s, en minimaal 0.6 s voor AoE die groter is dan 3 tegels.
- **Onderbreken:** een volle slag breekt de windup (nu al: `e["tele"]=0`, `:572`). Gele telegrafen kunnen ook door een control-skill gebroken worden.
- **Archetypes:** brute (melee_arc), schutter (line), caster (circle, onderbreekbaar), zwerm (laag HP, groep).
- **Keuze:** de aanval wordt gewogen-random gekozen via de seeded sim-RNG (§16), met het doel uit threat (§8).

## 12. Bazen: realtime met fases (D3)

- `register()` sluit bazen niet meer uit in Action (`som_arena.gd:228`). In Classic blijft een baas turn-based.
- **Raamwerk** `BossScript` (data): `phases: [{hp_until, attacks, adds, on_enter}]`.
- **Fasewissel:**
  - op een HP-drempel;
  - 1.5 s onkwetsbare overgang met een duidelijke animatie;
  - de arena kan veranderen (vlakken, adds);
  - de telegraaf-kleuren blijven gelijk.
- Een **enrage-timer** per baas is optioneel.
- **Schaling naar het aantal spelers:** baas-HP en adds schalen met het aantal *menselijke + AI*-stoelen via een factor die het balanswerk bepaalt. Hier staat alleen de hook `boss_party_scale(n)`. De basisstats komen uit #208 (`game_data.gd`).
- De Codex blijft bazen weigeren (`som_codex.gd:36-43`).

## 13. Game feel

- **Hitstop:**
  - 3 ticks (50 ms) op een volle slag;
  - 6 ticks bij combo, finisher en de laatste vijand;
  - alleen visueel (de render pauzeert de animatie lokaal), de sim loopt door. Dat houdt de sim deterministisch en eerlijk in co-op.
- **Screen shake:** klein (1-2 px) bij een treffer op jezelf of een baasklap, uit te zetten in Settings.
- **Haptics:** korte trilling op Android bij een perfect dodge, down of finisher (Settings).
- **Audio:** eigen cues voor telegraaf-start, dodge en revive (bestaande `actor_sfx.gd`).
- Effecten zijn alleen voor de presentatie en staan nooit in snapshots, behalve als event-id.

## 14. Besturing en touch-UI

- Links de analoge stick (zoals nu). Rechts **A = slaan**, **B = dodge**, en een skillknop (snelle skill 1) naast A.
- Bovenrij: [RUN][Swap (solo)][Ring][MENU] (`touch_controls.gd:150`). In co-op wordt Swap de knop "Finisher" als de team-meter vol is.
- Auto-lock op de dichtstbijzijnde vijand; tikken om te wisselen (bestaande lock).
- Toegankelijkheid: telegraaf-vormen ook met een patroon (niet alleen kleur), hitstop en shake uit te zetten.

## 15. Loot en progressie (D8)

- **Instanced loot:** elke drop-roll gebeurt per stoel op de host, met de seeded RNG en een eigen stroom per stoel. Elke speler ziet alleen zijn eigen buit.
- **EXP:** iedereen in de kamer krijgt de volle EXP (zoals nu, `_defeat_enemy` `:594`). Goud wordt per speler gerold.
- **Save:**
  - de host schrijft de wereld;
  - een gast krijgt bij vertrek of afsluiten een `reward_bundle` (EXP, items, goud, Codex-pagina's) en schrijft die in zijn eigen save. De story-voortgang telt niet;
  - de bundle is ondertekend met een sessie-id en host-tick, en de gast past hem één keer toe (geen duplicaat).
- **Teamwork-bonus:** +X% EXP voor finishers, revives en combo's (X komt van het balanswerk). Codex-vangsten tellen voor de vanger.
- Dit sluit aan op ARCHITECTUUR.md "Fase C requirements" (wie wat bezit, terugschrijven bij vertrek).

## 16. Determinisme en simulatie (D7)

- **Pure tick:** `CombatSim.step(inputs_per_slot)` op vaste 60 Hz, zonder nodes, tweens of `delta` uit `_process`.
  - Nodes lezen alleen state.
  - Basis is het `ActionSandboxSim`-patroon (`scripts/net/action_sandbox_sim.gd`, seeded RNG).
  - Dit is fase B stap 4 "Arena splitsen".
- **RNG:** één `RandomNumberGenerator` per sim met een seed per gevecht, plus afgeleide stromen (`combat`, `ai`, `loot[slot]`). Daarmee vervalt de globale `randf()` in:
  - `som_arena.gd:236`, `:450`, `:609`;
  - `som_ally.gd:179`;
  - `som_codex.gd:115`.
  Dit gebeurt achter een injecteerbare RNG, en de formules (`physical_damage`) blijven gelijk.
- **Beweging:** de sim rekent posities in fixed-point px (int, ×16) en lost botsingen op tegels zelf op. Tweens zijn alleen nog presentatie.
- **Replay:** seed + inputstroom = hetzelfde verloop. Een state-hash per seconde kan gelogd worden (`SessieLog`).
- **Netcode:** alleen de host simuleert. Determinisme dient de tests, de sim en debug-replays, niet lockstep.

## 17. Balans en metrics

- Doelen en getallen komen uit het fase 5-balanswerk (PR #208): `docs/BATTLE_BALANCE_REPORT.md`, `docs/ACTION_BALANCE_REPORT.md` (normaal gevecht 10-20% party-HP), `som_data.gd` tier-tabellen.
- Nieuw te meten per kamer en per aantal stoelen (1-4, mens/AI): HP-verlies, tijd, downs, revives, combo's, finishers, threat-verdeling (tank ≥ 60% van de doeltijd).
- De action-sim (`tools/battlesim/action_sim.gd`) wordt op `CombatSim` gezet zodra §16 klaar is.

## 18. Testplan en CI

`.github/workflows/` en de bestaande tests worden in deze PR's **niet** aangeraakt. Nieuwe suites voegen we toe via `GameState` (zoals `game_state.gd:459-515`). RPG Forge zet de matrixregels in CI (zie `docs/BACKLOG_WM1.md` rij 1).

| Suite (nieuw) | Wat |
|---|---|
| `--combatsimtest` | Determinisme: twee runs met dezelfde seed + inputs geven dezelfde hash. Andere seed geeft een andere hash |
| `--threattest` | Taunt, verval, drempelwissel, geen wissel midden in een telegraaf |
| `--dodgetest` | i-frame-venster op tick-niveau, stamina-kosten en regen, perfect dodge |
| `--revivetest` | Bleed-timer, revive afbreken, Seren-bonus, Feniksveer op KO |
| `--bosstest` | Fasewissel op drempel, onkwetsbare overgang, adds, schaal-hook |
| `--seatstest` | AI ↔ remote overname bij join/leave, zonder state-sprong |
| `--relaytest` | Mock-relay in één proces: code van 6 tekens, 5e speler REFUSE FULL, host weg = kamer weg |
| `--actionsim` uitbreiding | Rapport per aantal stoelen 1-4. Blijft een tool, geen CI-gate |

Bestaande suites (`battlesimtest`, `nettest`, `netsynctest`, `coope2etest`, `pvptest`, `autotest`) moeten groen blijven bij elke PR.

## 19. Roadmap (kleine PR's), open vragen en besluitlog

### Roadmap
1. **Docs:** dit document (geen code).
2. **RNG-injectie:** seeded RNG in arena, ally en codex. Gedrag gelijk, `--combatsimtest` basis.
3. **CombatSim-kern:** pure 60 Hz-tick voor beweging, slag en vijand-AI (fase B stap 4). De arena wordt presentatie.
4. **Threat:** vervangt `_target_for` + `--threattest`.
5. **Dodge + stamina:** knop B, constanten, input-bit + `--dodgetest`.
6. **Down/revive** + `--revivetest`.
7. **Stoelen met AI** (D4): controller per stoel, overname + `--seatstest`.
8. **Rollen en kits** (D2): skills per held, AI-prioriteiten, Orion in de co-op-roster.
9. **Telegraaf-raamwerk:** vormen, archetypes, grondmarkers.
10. **Combo's + team-meter + finisher.**
11. **Realtime bazen** (D3): `BossScript`, fases, schaal-hook + `--bosstest` (één baas als proef).
12. **Game feel:** hitstop, shake, haptics, Settings.
13. **Transport-interface + RelayTransport** (D1): aansluiten op de relay van RPG Forge + `--relaytest`.
14. **Loot per speler + reward_bundle** (D8), save van de gast.
15. **Balanspas:** door/met het fase 5-balanswerk, action-sim per stoelaantal.

### Open vragen
- Hostname en protocol van de RPG Forge-relay (UDP vs WebSocket voor web-builds).
- Rolbonus-getallen en de baas-schaalfactor: aan het balanswerk.
- Swap in co-op uit, of als "held kiezen tussen kamers"?

### Besluitlog
- 2026-10-24: D1-D8 goedgekeurd door Dennis (zie §2). Vervangt fase B DEC 1, 2, 3, 8 en het besluit van 21 okt 2026 (bazen altijd turn-based).
