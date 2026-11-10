> **F1 perfect dodge:** bevriest alleen de aanvallende vijand (Dennis 02-11).

# SAPIENTIA — Combat "dieper, niet groter" (Action-modus, WM1)

Status: ONTWERP / voorstel. Niets gebouwd, niets gecommit. Basis: clone `/workspace/combat/review351` (HEAD `ddc4dee`).
Door Dennis goedgekeurd: 5 features. Alle getallen zijn startwaarden voor de balanspas.
Legenda: **[GEV]** = in de code gecontroleerd (pad:regel), **[NG]** = niet gecontroleerd / aanname.

## 0. Wat er nu echt is (basis voor dit ontwerp)

| Onderdeel | Feit | Bron |
|---|---|---|
| Klok | 60 Hz vaste stap, max 12 ticks/frame | [GEV] `scripts/som/combat_sim.gd:9-13` |
| Dodge | duur 13 ticks, i-frames 15 ticks, cooldown 9 ticks, 28 px, stamina 30/100 | [GEV] `scripts/data/som_data.gd:93-98` |
| Dodge-logica | `try_active_dodge()` annuleert keten, swing_lock, co-op slot-lock en heavy; zet `iframes[id]` | [GEV] `som_arena.gd:1720-1752` |
| Treffer in i-frames | `hit_member()` → `_dodge()` (pose, `dodges += 1`), geen schade | [GEV] `som_arena.gd:1636-1640, 1683` |
| Hit-invuln | `PLAYER_IFRAMES` 0,8 s (float, geen ticks) | [GEV] `som_data.gd:302` |
| Ally-dodge-AI | dodget als telegraaf in windup ≤ 8 ticks en het punt raakt; kans 0,55 via host-`rng` | [GEV] `som_arena.gd:1798-1826` |
| Keten | 3 slagen, venster 20 ticks, mult [1.0, 1.1, 1.6], hitstop [0,0,6], knockback [1,1,2], finisher staggert altijd; AI-vervolg na 6 ticks | [GEV] `scripts/data/som_chain_data.gd` |
| Zware slag (charge) | hold 12 ticks, levels 45/100 ticks, mult [1.7, 2.4], hitstop [8, 12], knockback [2, 3]; AI gebruikt level 1 | [GEV] `scripts/data/som_heavy_data.gd:11-29` |
| Treffer vijand | `_land()` → `damage_enemy(m, dmg, dir, stagger, tiles, hitstop)`; "stagger" = bool (telegraaf `interrupt()` + hurt-pose + knockback), **geen meter** | [GEV] `som_arena.gd:1003-1031, 1101-1134` |
| Hitstop | `e["hitstop"]` ticks; `_enemy_ai` returnt vroeg zolang > 0 (alleen vijand bevriest) | [GEV] `som_arena.gd:1333-1335` |
| Schadegetallen | `SomFx.number(..., str(dmg), Color(1,1,1))` — altijd wit | [GEV] `som_arena.gd:1119`, `som_fx.gd:313` |
| Screenshake | geen `shake` in `scripts/som/` | [GEV] (rg leeg) |
| Crits in Action | geen `crit` in `scripts/som/` | [GEV] (rg leeg) |
| Telegrafen | `TelegraphState` IDLE→WINDUP→ACTIVE→RECOVERY→COOLDOWN, integer ticks, `interrupt()` alleen uit WINDUP | [GEV] `scripts/som/telegraph_state.gd` |
| Vijand-aanvallen | `inktspuw` (line, windup 450 ms), `inktplas` (circle, 700 ms, zone), pool alleen `inktwurm` | [GEV] `scripts/som/enemy_attacks.gd:12-60` |
| Doelkeuze | `_target_for()` = dichtstbijzijnde levende held; co-op: altijd slot 0 | [GEV] `som_arena.gd:1311-1326` |
| Golem | `GolemFight` = fases (90 ticks onkwetsbaar) + kern (8 s cyclus, 2 s open, break 45 → `stagger_ticks` 60); gewone slagen geven geen knockback/interrupt | [GEV] `golem_fight.gd:4, 141-160`; `som_arena.gd:1131` |
| Golem-windup | min 24 ticks, AoE groot ≥ 36, active ≤ 6 | [GEV] `golem_boss.gd:15-17` |
| Helden-id's | dennis=Dax (Warrior), noor=Vesper (Mage), lotte=Seren (Priest), kael=Kael Voss (Psytech), orion=Orion (Archer) | [GEV] `scripts/data/game_data.gd:25-68` |
| Kael/Orion speelbaar in WM1 Action? | | **[NG]** |
| Sims | `tools/battlesim/action_sim.gd` (`--actionsim`, `--boss-rt`), `golem_rt_sim.gd`, `wm1_balans.gd`, `f5_sim.gd` | [GEV] |
| Tests | `scripts/tests/{dodge,chain,charge,telegraph_*,combat_tick,golem_action,golem_actionsim}_tests.gd` | [GEV] |

Opmerking: "vijand-telegrafen" bestaan al (TelegraphState + telegraph_layer); feature 1 bouwt daarop en voegt **perfect dodge** toe — geen nieuw telegraafsysteem.

Algemene regels voor alle PR's
- Host-autoritatief: alle nieuwe staat in de host-tick (`_roots_authority()`-pad, zoals dodge). Clients krijgen alleen events/snapshot-velden.
- Deterministisch: alles in hele ticks (int), geen `randf` buiten de host-`rng`, geen `Engine.time_scale` in de sim (zie F1).
- AI-bondgenoten via precies dezelfde functies als de speler (`try_active_dodge`, `chain_swing`, `_land`).
- Data-tabellen in `scripts/data/` naast `som_chain_data.gd`/`som_heavy_data.gd`, schakelaar per feature (standaard uit tot balanspas, zoals F5).
- Alleen WM1; geen nieuwe vijanden, knoppen of menu's.

---

## F1 — Perfect dodge (op bestaande telegrafen)

**Doel**: belonen van timing i.p.v. dodge-spam; telegrafen leesbaar maken als kans.

**Mechaniek**
- Perfect = een vijandtreffer (`hit_member`) valt binnen de eerste **6 ticks** van `_dodge_roll_ticks` (dus ticks 13..8 resterend) én de bron is een telegraaf-aanval (`e["tg"]` of Golem). Generieke melee-tik telt ook mee (voorstel; Dennis kiest).
- Effect:
  - "Slow-mo" = **wereld-hitstop**, niet `Engine.time_scale`: vijanden + projectielen/zones bevriezen **18 ticks** (0,3 s) via hetzelfde `e["hitstop"]`-mechanisme; helden lopen door. Visueel: lichte desaturatie/vignet (client-only, telt niet mee in sim).
  - **Gratis counter**: volgende slag binnen **30 ticks** krijgt `mult ×1.5`, staggert altijd en kost geen keten-reset; stamina-refund **+15**.
  - Interne cooldown perfect-dodge: **90 ticks** per held (anti-farm in groepen).
- AI-bondgenoten: dezelfde check (hun dodge valt al op ≤ 8 ticks windup, `som_arena.gd:1816`) → ze halen het natuurlijk een deel van de tijd; geen extra AI-cheat.
- Co-op: host bepaalt perfect, stuurt event `perfect_dodge{slot, tick}`; slow-mo is per wereld (geldt voor alle spelers) — **[NG]** of dat in co-op prettig voelt; alternatief: alleen de aanvaller bevriest.

**Bestanden**: `scripts/som/som_arena.gd` (`hit_member`, `try_active_dodge`, `_tick_stamina_and_dodge`, `_enemy_ai` hitstop), `scripts/data/som_data.gd` (constanten) of nieuw `scripts/data/som_dodge_data.gd`, `scripts/som/som_fx.gd` (vignet), co-op snapshot/event (`coop_encode_snapshot` in som_arena; `action_coop_session.gd` — pad **[NG]**).

**Tests/metrics**: uitbreiding `scripts/tests/dodge_tests.gd`: treffer op roll-tick 1..6 = perfect, 7..13 = gewoon; counter verloopt na 30 ticks; cooldown 90; determinisme (zelfde seed → zelfde event-ticks). Sim (`action_sim.gd`): perfect-dodge-rate speler-policy vs ally-AI (doel ally 15-30 %), kamertijd −5..−10 %, verlies-HP niet > −15 % (anders te sterk).

**Risico's**: wereld-freeze in co-op; i-frames (15) > rolduur (13) maakt venster-definitie subtiel; groepen = veel kansen (cooldown dekt dat).

---

## F2 — Stagger-meter vijanden

**Doel**: ketens en zware slagen een doel geven buiten pure schade; bestaande bool "stagger" wordt een meter.

**Mechaniek** (per vijand `e["stg"]` int, max **100**)
- Vulling per treffer: hit1 **8**, hit2 **10**, finisher **22**, heavy L1 **30**, L2 **45**, perfect-counter **+20**, spreuk **5** **[NG: spreukpad niet bekeken]**.
- Verval: na **60 ticks** zonder treffer −1 per 2 ticks.
- Vol → **Wankel** **90 ticks**: telegraaf `interrupt()`, geen aanvallen, ontvangt **×1.3** schade; daarna meter 0 en **180 ticks** immuun voor vulling.
- Bestaande gedrag blijft: volle slag/finisher onderbreekt windup (dat is "kleine stagger"); de meter is de "grote stagger".
- Golem: niet via de meter; de kern-break (`break_damage` 45 → `stagger_ticks` 60) **is** zijn stagger. Optioneel: meter vult alleen tijdens kern-open (later, niet in deze PR).
- Boss/unique (Inktwurm): max **160**.

**Bestanden**: nieuw `scripts/data/som_stagger_data.gd`; `som_arena.gd` (`damage_enemy`, `_enemy_ai`, `_enemy_ai_telegraph`); HUD-balkje boven vijand in `scripts/som/som_hud.gd` of `som_fx.gd` **[NG welke tekent vijand-hp]**; snapshot-veld `stg` voor co-op.

**Tests/metrics**: nieuw `scripts/tests/stagger_tests.gd` (vulling per staptype, verval, wankel-duur, immuniteit, determinisme); sim: wankels per kamer (doel 1-2 bij normale groep), aandeel schade in wankel (doel 20-30 %), kamertijd ≤ −10 %.

**Risico's**: dubbel tellen met bestaande ×1.6/×2.4 → schade-inflatie; hitstop + wankel stapelen tot "stunlock" (immuniteit 180 ticks voorkomt).

---

## F3 — Signature-eigenschap per held (keten/charge)

**Doel**: elke held voelt anders binnen hetzelfde 3-slag/charge-schema. Geen duo/team-combo's. AI gebruikt identieke regels (triggert dus ook voor bondgenoten).

| Held (id) | Trigger | Effect (voorstel) |
|---|---|---|
| Dax (`dennis`) | finisher + heavy | knockback **+1 tegel** (finisher 3, heavy L1 3, L2 4) en stagger-vulling ×1.25 |
| Seren (`lotte`) | volledige keten (finisher raakt ≥1 vijand) | heal **4 % max-HP** van de laagste held binnen 48 px; ICD **120 ticks** |
| Vesper (`noor`) | treffer van achter (vijand-facing · richting > 0,5) | crit **×1.5** (deterministisch: geen RNG) + gouden getal |
| Kael (`kael`) | finisher | **aggro lock**: geraakte vijand richt **150 ticks** op Kael (`_target_for` override); ICD 240 |
| Orion (`orion`) | finisher/heavy | **slow** 0,6× beweging **90 ticks**, windup +6 ticks als die nog loopt; niet op Golem-windup (min windup blijft) |

- Vesper "backstab": vijanden hebben `m.facing` (gebruikt in `_knockback`/`place_at`) **[NG of facing van vijanden betrouwbaar wordt bijgewerkt]**. Vesper is Mage — vaker spreuk dan melee; effect evt. ook op spreuk **[NG]**.
- Kael aggro lock in co-op: `_target_for` geeft nu altijd slot 0 terug (`som_arena.gd:1312-1316`) → lock moet vóór die tak gecontroleerd worden.
- Orion slow kan via bestaande zone-slow (`zone_slow_mult` 0,6) hergebruikt worden **[NG of monster-slow los van zones bestaat]**.

**Bestanden**: nieuw `scripts/data/som_signature_data.gd`; `som_arena.gd` (`_land`, `damage_enemy`, `_target_for`, `_knockback`); heal via bestaand heal-pad **[NG: functienaam]**.

**Tests/metrics**: `scripts/tests/signature_tests.gd` per held (trigger ja/nee, ICD, ally-AI triggert gelijk). Sim per partij-samenstelling: aandeel van elke trait in kamertijd/HP; doel: geen held > +15 % DPS t.o.v. gemiddeld; Seren-heal ≤ 10 % van totale heal.

**Risico's**: Kael/Orion niet in WM1-party → testbaar alleen via testpartij; Dax-knockback duwt vijanden buiten keten-reach (finisher is laatste slag, dus beperkt).

---

## F4 — Game feel (goedkoop, 60 fps Galaxy S25)

**Doel**: zwaarte voelbaar zonder sim-impact.

- **Hitstop zwaar**: finisher 6 → **8**, heavy [8,12] → **[10, 14]**. Optioneel *aanvaller*-hitstop 3/5 ticks (held-animatie pauze, client-visueel; sim-impact **[NG]** → standaard uit).
- **Screenshake**: alleen camera-offset, client-only, niet in sim: heavy L1 **2 px / 6 ticks**, L2 **3 px / 8 ticks**, Golem-slam **3 px / 10 ticks**; deterministisch patroon (geen randf: vaste tabel ±). Instelling "schudden uit" **[NG: bestaand settings-menu]** — liever geen nieuwe knop: schaal 0 in Settings-data.
- **Kleurgetallen** (`SomFx.number` heeft al `color`-param): normaal wit, crit (Vesper/perfect-counter) **goud #FFD24A** +1 schaal, wankel-treffer **oranje #FF8A3D**, heal **groen** (bestaat al? **[NG]**).
- Budget: geen shaders/particles extra; ≤ 1 extra node per treffer; perf-check met `scripts/perf/perf_probe.gd` + `perf_probe_tests.gd`.

**Bestanden**: `scripts/data/som_chain_data.gd`, `som_heavy_data.gd` (getallen), `scripts/som/som_fx.gd` (shake + kleuren), `som_arena.gd:1119` (kleur kiezen), camera **[NG pad]**.

**Tests/metrics**: chain/charge-tests bijwerken op nieuwe hitstop; test dat shake niets aan sim-staat verandert (sim-hash gelijk met shake aan/uit); perf_probe: frametijd p95 < 16,6 ms op 20 vijanden + getallen. Sim: kamertijd stijgt door extra hitstop met < 3 %.

**Risico's**: meer hitstop = vijand-freeze langer → indirect sterker (meten); shake misselijkheid.

---

## F5 — Samenwerkende vijandgroepen

**Doel**: groepen voelen als team zonder nieuwe vijandsoorten: één valt aan, één flankeert of schermt.

**Mechaniek**
- Host-groepscoördinator per kamer (elke **30 ticks** herberekend, deterministische volgorde op vijand-index):
  - **Aanvaller-token**: max **1** vijand (2 bij ≥ 4 vijanden) in WINDUP tegelijk per doelheld. Anderen wachten (`cd` min 20 ticks).
  - **Flanker**: tweede vijand loopt naar punt 90° van de aanvaller rond het doel (afstand 28 px) → zet backstab (F3) en perfect dodge (F1) in context.
  - **Schild**: als een vijand < 30 % HP heeft, gaat een buur ertussen staan (geen echt schild-effect, alleen positie) **of** krijgt **−30 %** schade op die vijand zolang hij binnen 20 px staat. Voorstel: eerst alleen positie.
- Rollen gelden alleen bij ≥ 2 vijanden; Golem en uniques doen niet mee.
- Wankel (F2) breekt rol; token gaat naar de volgende.

**Bestanden**: nieuw `scripts/som/enemy_group.gd` (pure RefCounted, testbaar zonder nodes); `som_arena.gd` (`_enemy_ai`, `_target_for`, `_enemy_ai_telegraph`); evt. `scripts/dungeon/map_monster.gd` (`sim_move`) voor flank-doelpunt.

**Tests/metrics**: `scripts/tests/enemy_group_tests.gd` (token-uniciteit, rolwissel bij dood/wankel, determinisme met seed). Sim `wm1_balans.gd`: verlies-HP per kamer (doel binnen bestaande 60-90 %-band uit commit `dcf2563`), gelijktijdige windups (moet dalen), backstab-aandeel.

**Risico's**: token maakt groepen *makkelijker* (minder gelijktijdige klappen) → compenseren met kortere wacht; padvinding tegel-gebonden → flankers blijven haken; co-op-snapshot moet rol meesturen (alleen visueel).

---

## PR-volgorde (één PR per feature, alles achter schakelaar)

1. **PR1 F4 game feel** — kleinste risico, geen sim-staat; meetlat voor de rest (hitstop finisher 8, heavy 10/14, shake 2-3 px, kleuren).
2. **PR2 F2 stagger-meter** — fundament voor F1-counter, F3 en F5 (max 100, wankel 90 ticks ×1.3, immuun 180).
3. **PR3 F1 perfect dodge** — venster 6 ticks, freeze 18, counter 30 ticks ×1.5, +15 stamina, ICD 90.
4. **PR4 F3 signatures** — per held één data-rij; gebruikt crit-kleur (F4) en meter (F2).
5. **PR5 F5 groepen** — laatst, omdat het balans van alles verschuift; daarna volledige `wm1_balans`-run.

Na elke PR: bestaande tests groen (`dodge/chain/charge/telegraph*/combat_tick/golem_action*`), `action_sim` + `golem_rt_sim` vóór/na in het PR-verslag, geen commit/push zonder akkoord Dennis.

## Open punten [NG]
- Kael/Orion beschikbaar in WM1 Action-party?
- Pad co-op-sessiebestand en camera-node.
- Vijand-`facing` betrouwbaar voor backstab?
- Bestaand heal-pad en heal-kleur in `SomFx`.
- Wereld-freeze vs. lokale freeze in co-op (F1).
