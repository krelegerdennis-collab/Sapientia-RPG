# M9b-3 — Easy met revive (voorstel)

Dennis koos op 11-11-2026 revive aan, samen met schade 1.2 en herstel 50, alleen voor online co-op Easy. Zie `docs/combat/m9b_easy_gekozen.md`. De tabellen hier blijven de sim-meting.

Alleen in de sim. `--revive=off` is de default en geeft de #430-baseline terug. `SomData.ENEMY_DAMAGE_MULT` blijft 2.2. `mode_exp_factor` blijft 10. Geen speldata gewijzigd.

Factor 10, 24 runs, seed `20261110`, vloeren 1–10, stoelen 1–4. `--no-hypo --no-classic`. Zelfde kaarten en dezelfde `combat_seed` als `docs/combat/m9b_easy_dmg_heal.md`.

Page Warden bereikt = troep op vloer 10 gehaald én de baas gestart. Winst alle = baaswinst / 24 (een gemiste baas telt als verlies). Level = gemiddelde bij de baas, alleen over wie hem start. Revives = som van geslaagde kanalen over 24 runs. Wipes = vloer × aantal runs dat daar door een wipe valt (`cause_wipe`).

Herhalen:

```
xvfb-run -a godot --rendering-driver opengl3 --path . -- --d100modesim --mode=easy --factors=10 --seats=1,2,3,4 --runs=24 --floors=10 --seed=20261110 --no-hypo --no-classic --easy_enemy_dmg=2.2 --floor_heal=0 --revive=off
```

`--revive=on` op dezelfde regel. `--easy_enemy_dmg` en `--floor_heal` zoals in de tabel.

## Regels uit de code

Overgenomen uit `scripts/coop/coop_revive.gd`. De sim roept de publieke functies aan (`begin_run`, `query_revive`, `begin_channel`, `enter_down`, `step`, `apply_rest`). Geen gekopieerde seconden of procenten.

- Eén geslaagde revive per stoel per run. `REVIVES_PER_RUN` is 1 (`coop_revive.gd` regel 57). `can_be_revived` (82–83) weigert daarna. `begin_run` (86–91) is de enige reset (commentaar 20–26). Een nieuwe klim-run roept `begin_run` aan. `apply_rest` wist de teller niet.
- Kanaal: `channel_ticks_for` (70–71). Heal-held `lotte` (`HEAL_HERO`, regel 41) is `CHANNEL_HEAL_TICKS` 72 (1,2 s). Elke andere held is `CHANNEL_TICKS` 120 (2,0 s). Constanten op 46–49. De sim tikt één `step` per gevechtstick (60 Hz, zelfde als `SIM_HZ`).
- HP na een kanaal: `revive_hp` (74–75) is `HP_PERCENT` 30 van `max_hp`, minstens 1 (regel 50). Daarna `IFRAME_TICKS` 60 (regel 55), gezet in `_finish_channel` (349–356). De sim kopieert die iframes en slaat de klap over zolang ze boven 0 staan, net als `action_sandbox_sim._damage_row` (255–257) de schade overslaat.
- Wie mag: een levende mens altijd (`_may_channel`, 321–324). `step` start zijn kanaal zelf (`_channel`, 296–303). AI alleen als `ai_should_revive` (141–148): `lotte` wel zodra iemand ligt; andere AI alleen als er geen levende Heal is (`AI_OTHERS_ONLY_WITHOUT_HEAL`, 61–62). Een stoel revivet zichzelf niet: `_nearest_in_range` (327–333) slaat de eigen slot over. Daarom is 1 stoel met revive gelijk aan zonder.
- Wipe: `everyone_down` (271–279) is waar zodra elke meewerkende stoel down is. `step` geeft dat terug (268). `already_wiped` stopt het kanaal (266–267). De sim breekt dan het gevecht en de klim.
- Bleed: 15 s, `BLEED_TICKS` 900 (52–53). `BLEED_END_STAY_DOWN` (59–60) laat ze liggen. Geen permadeath in de run (`step`, 257–265).
- Rustvloer 5: de bestaande sim vult levenden bij. Daarnaast `apply_rest` (380–386): wie ligt staat op volle HP, levenden blijven zoals ze zijn, de revive-teller blijft. Alleen bij `--revive=on`.

Niet gebruikt: `phoenix` (359–377). De Feniksveer is meteen en leest `GameData.ITEMS.feniksveer.revive`. De bondgenoot-AI gebruikt geen ring-item. De sim ook niet. Dat stond al in de #428-sim.

## Aannames

Dit staat niet als gedrag in de draaiende build, of de gevechtssim heeft het gegeven niet.

- AI start. `SomAlly._coop_revive_drive` (`scripts/som/som_ally.gd` 239–244) roept `begin_channel` aan en keert terug vóór de aanval. Die functie stopt zodra `seat_controller_present()` waar is (231–232). `scripts/coop/seat_controller.gd` bestaat. `try_revive` (430–431) geeft `false`. De prioriteit van Heal noemt `revive` wel (450–452), maar het staat in `STUB_ACTIONS` (27–29) en de haak voert het niet uit. In deze build start geen AI dus een kanaal. Deze sim roept `begin_channel` wél aan voor een AI-stoel waarvan `query_revive` `ok` is. Zonder die aanname revivet alleen de menselijke host, en een gevallen host blijft liggen zolang Seren AI is.
- Plek. De sim heeft geen tegels. Elke stoel staat op (0, 0), dus `in_range` (200–203, `RANGE_PX` 16) is waar. Er is geen looptijd naar de liggende stoel. `SomData.FORMATION` ligt verder dan 16 px; die afstand simuleert deze run niet.
- Tick-orde. Eerst de helden, dan de vijanden, dan `step`. Een AI slaat niet op een tick waarop `query_revive` al `ok` is. De tick waarop iemand nét valt, heeft de held-fase al gehad. De host (stoel 0, `Seat.CONTROLLER_HUMAN`) blijft slaan tijdens zijn kanaal: `som_arena.gd` blokkeert input alleen als de stoel zelf down is.
- Treffer breekt het kanaal via `hit_seq` (commentaar 14–16, `_channel` 304–307). `action_sandbox_sim.gd` `_damage_row` (255–261) telt `hit_seq` op bij HP-verlies. `som_arena.gd` schrijft `hit_seq` nergens. De sim volgt de sandbox: elke `_hurt` telt mee, en `step` zet de voortgang terug naar 0.
- Rustpunt in de kerker. `online_dls_floor.gd` (70–73) zet alleen de prop `rustpunt`. Niets in de arena roept `apply_rest` aan. De sim doet dat wel op Easy-vloer 5 als `--revive=on`, omdat dat de functie is die de test `revive_tests.gd` voor het rustpunt gebruikt.

## Tabel

| optie | dmg | heal | stoelen | revive | PW bereikt | winst alle | level | revives | wipes |
|---|---|---|---|---|---|---|---|---|---|
| base | 2.2 | 0 | 1 | uit | 0/24 | 0.0% (0) | — | 0 | 2×21, 3×2, 4×1 |
| base | 2.2 | 0 | 1 | aan | 0/24 | 0.0% (0) | — | 0 | 2×21, 3×2, 4×1 |
| base | 2.2 | 0 | 2 | uit | 0/24 | 0.0% (0) | — | 0 | 2×7, 3×11, 4×3, 5×1, 6×1, 7×1 |
| base | 2.2 | 0 | 2 | aan | 0/24 | 0.0% (0) | — | 19 | 2×3, 3×9, 4×5, 5×3, 6×1, 7×1, 8×1, 9×1 |
| base | 2.2 | 0 | 3 | uit | 4/24 | 16.7% (4) | 106.2 | 0 | 3×3, 4×10, 5×4, 6×2, 10×1 |
| base | 2.2 | 0 | 3 | aan | 12/24 | 50.0% (12) | 110.1 | 27 | 3×2, 4×6, 5×2, 6×1, 8×1 |
| base | 2.2 | 0 | 4 | uit | 14/24 | 58.3% (14) | 109.4 | 0 | 3×2, 4×4, 5×2, 6×1, 8×1 |
| base | 2.2 | 0 | 4 | aan | 21/24 | 87.5% (21) | 104.7 | 25 | 4×1, 5×1, 6×1 |
| dmg 1.2 | 1.2 | 0 | 1 | uit | 0/24 | 0.0% (0) | — | 0 | 2×16, 3×5, 4×2, 5×1 |
| dmg 1.2 | 1.2 | 0 | 1 | aan | 0/24 | 0.0% (0) | — | 0 | 2×16, 3×5, 4×2, 5×1 |
| dmg 1.2 | 1.2 | 0 | 2 | uit | 8/24 | 33.3% (8) | 102.1 | 0 | 2×1, 3×6, 4×4, 5×2, 6×1, 8×1, 9×1 |
| dmg 1.2 | 1.2 | 0 | 2 | aan | 13/24 | 54.2% (13) | 105.3 | 13 | 3×2, 4×5, 5×1, 6×2, 8×1 |
| dmg 1.2 | 1.2 | 0 | 3 | uit | 19/24 | 75.0% (18) | 109.7 | 0 | 4×2, 5×2, 6×1, 10×1 |
| dmg 1.2 | 1.2 | 0 | 3 | aan | 21/24 | 87.5% (21) | 109.5 | 7 | 4×1, 5×1, 6×1 |
| dmg 1.2 | 1.2 | 0 | 4 | uit | 21/24 | 87.5% (21) | 105.0 | 0 | 4×1, 5×1, 6×1 |
| dmg 1.2 | 1.2 | 0 | 4 | aan | 23/24 | 95.8% (23) | 108.9 | 8 | 5×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 1 | uit | 0/24 | 0.0% (0) | — | 0 | 2×14, 3×7, 4×2, 5×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 1 | aan | 0/24 | 0.0% (0) | — | 0 | 2×14, 3×7, 4×2, 5×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 2 | uit | 10/24 | 41.7% (10) | 109.8 | 0 | 2×1, 3×3, 4×5, 5×2, 6×1, 7×1, 8×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 2 | aan | 17/24 | 70.8% (17) | 108.8 | 14 | 3×1, 4×4, 5×1, 6×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 3 | uit | 19/24 | 79.2% (19) | 109.7 | 0 | 4×2, 5×2, 6×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 3 | aan | 21/24 | 87.5% (21) | 109.5 | 7 | 4×1, 5×1, 6×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 4 | uit | 21/24 | 87.5% (21) | 105.0 | 0 | 4×1, 5×1, 6×1 |
| dmg 1.2 + heal 50 | 1.2 | 50 | 4 | aan | 23/24 | 95.8% (23) | 108.9 | 8 | 5×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 1 | uit | 0/24 | 0.0% (0) | — | 0 | 2×16, 3×5, 4×2, 5×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 1 | aan | 0/24 | 0.0% (0) | — | 0 | 2×16, 3×5, 4×2, 5×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 2 | uit | 7/24 | 25.0% (6) | 109.1 | 0 | 2×1, 3×6, 4×4, 5×4, 6×1, 8×1, 10×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 2 | aan | 11/24 | 45.8% (11) | 110.0 | 12 | 2×1, 3×5, 4×2, 5×3, 6×1, 8×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 3 | uit | 15/24 | 62.5% (15) | 110.3 | 0 | 3×3, 4×2, 5×3, 6×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 3 | aan | 18/24 | 75.0% (18) | 109.6 | 14 | 3×1, 4×2, 5×2, 6×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 4 | uit | 20/24 | 83.3% (20) | 109.5 | 0 | 3×1, 4×1, 5×1, 6×1 |
| dmg 1.5 + heal 100 | 1.5 | 100 | 4 | aan | 22/24 | 91.7% (22) | 109.4 | 9 | 5×1, 6×1 |

De rijen `uit` komen overeen met #430 (`docs/combat/m9b_easy_dmg_heal.md`): zelfde PW, dezelfde winst-alle, hetzelfde level, dezelfde verste wipe. In elke cel met revives was het maximum per stoel in één run 1.

## Lezen

Niet doorvoeren. Geen van deze vier opties legt de winst over alle runs in 60–90% bij élk stoelaantal.

1 stoel verandert niet. Er is niemand anders om het kanaal te starten. De wipes blijven op vloer 2–5, ook op schade 1.2 met vol herstel én revive.

2 stoelen op schade 2.2 halen de Page Warden nog steeds 0/24. Revive (19 keer) schuift wipes door tot vloer 9, maar de baas komt niet in zicht. Op schade 1.2 gaat 2 stoelen van 33.3% naar 54.2%, en met herstel 50 naar 70.8% (17/24). Dat is de enige 2-stoel-cel in de band 60–90.

3 stoelen komen met revive in of tegen die band: 50.0% op 2.2, 87.5% op 1.2 (met en zonder herstel 50), 75.0% op 1.5 met herstel 100.

4 stoelen zitten op 2.2 mét revive op 87.5%. Op 1.2 mét revive worden het 23/24 (95.8%), boven 90%. Op 1.5 met herstel 100 en revive: 91.7%.

Revive helpt zodra een tweede stoel het kanaal kan doen. Het haalt een solo niet door vloer 2. Wie 60–90% ook voor 1 stoel wil, heeft een andere knop nodig dan schade, herstel tussen vloeren, en deze revive.
