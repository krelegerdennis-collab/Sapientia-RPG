# Review WM1-gevechtssysteem

Scope: `scripts/battle/battle.gd` (ronde-lus, commando's kiezen, `_execute`, schade/heal/status,
kernkrachten, overwinning), met de helpers die het aanroept (`party_actions.gd`,
`data/archief2_vijanden.gd`, `data/spell_rules.gd`, `codex_battle.gd`). Geen code gewijzigd,
geen tests gedraaid (alleen lezen). Regelnummers gelden voor commit `820521b`.

Ernst: **H** = speler merkt het / fout resultaat, **M** = inconsistent of verspilling, **L** = netheid/ontwerpvraag.

---

## H1 — Feniksveer laat de held in de KO-pose staan
`scripts/battle/battle.gd:1388-1390`

De item-revive zet alleen `hp` via `PartyActions.revive()` (`party_actions.gd:218`), maar roept
nooit `node.set_ko(false)` aan. De spreuk-revive `_revive()` doet dat wel (`battle.gd:1631-1632`).
Gevolg: de held heeft weer HP en kan handelen, maar ligt visueel nog neer (`is_ko == true`,
pose "ko") tot er toevallig een andere pose-wissel komt.

**Voorstel:** na `PartyActions.revive(...)` ook `dood["node"].set_ko(false)` (als de node bestaat),
of beter: beide revive-wegen via één helper laten lopen (zie ook H2).

## H2 — `reported_ko` wordt nooit teruggezet na een revive
`scripts/battle/battle.gd:1701-1703`, `1630-1632`, `1388`

`_report_kos()` zet `t["reported_ko"] = true` en slaat daarna iedereen met die vlag over. Geen van
de twee revive-wegen wist de vlag. Gaat een geredde held in hetzelfde gevecht opnieuw KO, dan
komt er geen "X is down!", geen `dood`-geluid en geen `MESSAGE_TIME`-pauze.

**Voorstel:** in een gedeelde `_revive_combatant(c, hp)` `c.erase("reported_ko")` + `set_ko(false)` +
`_refresh_party()` doen, en die vanuit spreuk én item aanroepen. Test: held KO → Feniksveer →
weer KO → bericht "is down!" verwacht.

## H3 — Feniksveer: doel kan niet gekozen worden, en het item gaat weg zonder effect
`scripts/battle/battle.gd:1088-1091`, `1371`, `1378-1393`

- `_choose_item()` gebruikt voor elk niet-vijand-item `_select_ally()`, en die toont alleen
  **levende** helden (`1146`). Een KO-held kun je dus niet aanwijzen; `_execute` valt terug op de
  eerste KO-held in de lijst (`1380-1384`). Met twee KO-helden kies je niet zelf wie opstaat.
- `GameState.inventory[id] -= 1` (`1371`) gebeurt **vóór** de controle of er iemand KO is. Is er
  niemand KO (bijv. al gered door een spreuk eerder in de ronde), dan krijg je "no effect" en is
  de veer toch op. Ook Tegengif (`1394-1403`) wordt verbruikt en meldt "is cured" als er niets te
  genezen viel.
- Teach-items (`1356-1370`) en `stun_room` (`1404-1409`) doen het wél goed (eerst checken, dan
  verbruiken / teruggeven).

**Voorstel:** in `_choose_item` voor items met `revive > 0` `_select_ko()` gebruiken (zoals spreuken
met `target == "ko"`, `1063-1064`). In `_execute` eerst het effect bepalen en pas bij effect
`inventory -= 1`, net als bij teach.

## H4 — Vijand die door een DoT (gif/brand) sterft blijft zichtbaar en wordt niet gemeld
`scripts/battle/battle.gd:1578-1591`, `865-871`

`_tick_ailments()` trekt HP af, maar roept `_report_kos()` niet aan. Voor vijanden betekent dat:
geen "is defeated!", geen fade-out/`hide` van de node, geen `dood`-geluid, en `mark_defeated`
pas in `_victory()` (`1907-1911`). Sterft er één van meerdere vijanden aan gif, dan staat zijn
sprite de rest van het gevecht op het veld (wel onaanklikbaar, omdat `_alive` hem filtert).
Vlucht de party daarna, dan wordt hij nooit als verslagen in het bestiarium gezet.
Voor helden: wel `set_ko(true)` (`1613`), maar geen "is down!"-bericht.

**Voorstel:** in de eindronde-lus na `_tick_ailments` de gestorvenen verzamelen en
`await _report_kos(gestorven)` doen (en de DoT-schade ook als popup tonen, zoals `_hit`).
De vangnet-lus in `_victory` kan dan blijven als extra zekerheid.

---

## M1 — Kernkracht negeert ATK-buffs, H-5-token en fysieke zwakte
`scripts/battle/battle.gd:2299-2308` vs `1489-1505`

`physical_base()` rekent met `atk * _buff_mult(attacker, "atk")` (dus incl. `_token_mult`) en
`_physical_damage()` past `Archief2.zwakte_fysiek()` toe. `kern_base()`/`kern_damage()` doen geen
van beide. Een held met een ATK-buff of de Token doet met zijn sterkste aanval relatief mínder
extra schade dan met een gewone klap, en zwakte (Archief 2) telt niet voor kernkrachten.

**Voorstel:** in `kern_base` `* _buff_mult(attacker, "atk")` toevoegen en in `kern_damage`
dezelfde `zwakte_fysiek`-stap. Eerst even checken met de battlesim of de balans dat aankan
(of bewust zo houden en dat in het commentaar zetten).

## M2 — Bevroren/verlamde held kiest toch een commando
`scripts/battle/battle.gd:886-903` vs `1255-1263`

`skip` wordt pas in `_execute` bekeken. In `_choose_commands` moet de speler voor een bevroren
held gewoon een actie kiezen (en eventueel een item reserveren), die daarna verloren gaat.
Op mobiel is dat een extra rij tikken voor niets.

**Voorstel:** in `_choose_commands` helden met `skip > 0` overslaan (of een automatische
`{"type": "skip"}`-actie invoegen) en een korte regel "X is frozen" tonen. `_next_alive_hero` /
`_prev_alive_hero` dan ook laten overslaan, anders loopt "terug" vast op die held.

## M3 — Kern-cooldown telt in dezelfde ronde al één af
`scripts/battle/battle.gd:2322`, `869`, `2360-2364`

`kern_cd` wordt bij uitvoeren op `cooldown` (default 3) gezet en aan het eind van diezelfde ronde
door `_kern_tick` al met 1 verlaagd. Effectief is de vaardigheid na 2 tussenrondes weer klaar,
en het menu toont direct "(2)". Kan bedoeld zijn, maar komt niet overeen met de naam `cooldown: 3`.

**Voorstel:** ontwerpkeuze vastleggen. Óf `cooldown + 1` zetten, óf in `KernData` documenteren dat
`cooldown` inclusief de eigen ronde telt.

## M4 — DoT omzeilt de oefengevecht-bescherming en het Golem-pantser
`scripts/battle/battle.gd:1586-1587` vs `1674-1679`

`_hit` voorkomt KO in het oefengevecht en schaalt schade via `core.scale_damage`. De DoT-tick
past direct `hp` aan en slaat beide over: een % van max-HP gaat dwars door het pantser van de
Golem-baas, en een vergiftigde held kan in een tutorial-gevecht toch KO gaan.

**Voorstel:** de DoT-schade via een kleine helper laten lopen die dezelfde clamp/scale doet als
`_hit` (zonder de animaties), of DoT expliciet uitsluiten op `core`-vijanden.

## M5 — Buffs stapelen onbeperkt (multiplicatief)
`scripts/battle/battle.gd:1538-1545`, `1513-1520`

Elke cast voegt een nieuwe rij toe aan `buffs`; `_buff_mult` vermenigvuldigt ze allemaal. Drie
keer dezelfde +30% DEF-spreuk = x2,197. Daarnaast telt `_defense_of` het oude `buff_def` er
nog los bij (`1853`).

**Voorstel:** per `stat` + spreuk-id hoogstens één rij (bij opnieuw casten alleen `turns`
verversen), of een maximum op het totaal.

## M6 — Leech herstelt ook wat niet als schade is aangekomen
`scripts/battle/battle.gd:1787-1793`

De Genezer herstelt altijd `n`, ook als `_hit` de schade heeft afgekapt (oefengevecht, held met
minder HP dan `n`). Ook negeert de leech verdedigen/schild (geen `_physical_damage`). En het doel
is altijd `pool[0]` (eerste held), dus nooit de codex-bondgenoot of een andere held.

**Voorstel:** werkelijke schade meten (`hp_voor - hp_na`) en die herstellen; de vaste doelkeuze
in het commentaar als bewuste keuze markeren als dat zo is.

---

## L1 — Dode code: `buff_stat`/`buff_n`
`scripts/battle/battle.gd:1532-1534`, `1853`

Geen enkele spreuk in `scripts/data/` gebruikt `buff_stat` (grep vindt alleen `battle.gd`). Deze
oude weg loopt nooit af (geen tick) en stapelt. **Voorstel:** verwijderen, of minstens laten
aflopen via `buffs`.

## L2 — Kernkracht die niet klaar is verdwijnt stil
`scripts/battle/battle.gd:2315-2316`

Komt een `kern_skill`-actie toch bij `_execute` terwijl de cooldown loopt, dan wordt de beurt
zonder bericht overgeslagen. Het menu blokkeert dit nu (`1040`, `1050`), dus geen bug vandaag,
maar een korte melding ("not charged yet") maakt het robuust.

## L3 — Snelheids-jitter is een vaste +0..3
`scripts/battle/battle.gd:847`

Bij lage AGI (vroege game) bepaalt `randf() * 3.0` de volgorde grotendeels; bij hoge AGI
nauwelijks. **Voorstel:** procentueel maken (bv. `agi * randf_range(0.9, 1.1)`), na een
battlesim-check.

## L4 — `_execute` is één `match` van ~175 regels
`scripts/battle/battle.gd:1253-1428`

Vooral de `"item"`-tak heeft vijf vroege `return`s met elk eigen verbruik-logica (de oorzaak van
H3). **Voorstel:** per item-soort een functie (`_use_revive_item`, `_use_cure_item`, ...) met één
plek waar verbruikt wordt. Past ook bij de data-gedreven richtlijn uit AGENTS.md.

## L5 — `_hit` bevat UI én regels
`scripts/battle/battle.gd:1673-1696`

Tutorial-clamp en core-schaal (regels) zitten tussen popup/shake (beeld). Daardoor is die logica
niet herbruikbaar voor DoT (M4). **Voorstel:** `_apply_damage(t, amount) -> int` (puur) +
`_show_hit(t, amount)` (beeld).

---

## Voorgestelde tests (nieuwe suite, bestaande niet aanraken)
1. Held KO → Feniksveer → `node.is_ko == false`, en tweede KO geeft "is down!" (H1, H2).
2. Feniksveer zonder KO-held → `item_count` ongewijzigd (H3).
3. Twee KO-helden → Feniksveer op de tweede → de tweede staat op (H3).
4. Vijand sterft door DoT terwijl een andere leeft → node verborgen, `mark_defeated` direct (H4).
5. Kernkracht met ATK-buff doet meer schade dan zonder (M1).
6. Oefengevecht + gif → held blijft op >= 1 HP (M4).
