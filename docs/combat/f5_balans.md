# F5 Balans: combat, realtime Action-modus (keten, zware slag, Golem)

**Status: VOORSTEL. Er is niets gecommit naar main, niets gepusht en geen PR geopend.** Dennis beslist.
Basis: `main` @ `354e7cd` (31-10-2026 00:11 CET). Gemeten op de lokale scratch-branch `scratch/f5-balans` in `/workspace/combat/f5`.
Ruwe uitvoer: `/workspace/combat/f5_sim/` (JSON + logs per run, `variant.sh`, `scratch_branch.diff`).

## Kort
1. **De keten loont nu niet voor de speler.** Snel doortikken (hit1→hit2→finisher) levert Dax **5,9 DPS** op, tegen **17,9** als je gewoon op een volle meter wacht. Oorzaak: elke slag zet de wapenmeter op 0, en het ketenvenster (20 ticks) sluit lang voordat de meter (1,0 s) weer vol is. hit2 en de finisher slaan daardoor altijd op de bodem van 10%.
2. **De zware slag is strikt beter dan alles.** Een L1-loop haalt **42,9 DPS** (2,4× wachten) en een L2-loop **48,2 DPS** (2,7×). De zware slag negeert de wapenmeter (basis 1,0). Van risk/reward is dus geen sprake: L2 is gewoon de beste knop.
3. **Rammen (8 tikken/s) verslaat geduldig spelen**: 28,9 tegen 17,9 DPS. Een tik tijdens de eigen slaganimatie wordt niet geblokkeerd.
4. **AI-bondgenoten doen meer schade dan de speler met dezelfde held.** Dax als AI haalt gemiddeld 49,3 DPS, Dax als speler 17,9 (wachten) of 5,9 (keten). De AI-keten slaat op basis 1,0 zonder meter, en na elke finisher volgt een L1.
5. **Golem**: bazen zijn in Action **altijd turn-based**. Keten en zware slag hebben dus **geen invloed** op de Golem. De Golem is te makkelijk voor de SoM-party (99,6% winst op Lv 3, doel 60-80%). Dat is een aparte taak buiten deze twee databestanden.

**Voorstel** (gemeten): (a) hit2/finisher binnen het venster slaan op volle meter, (b) tikken tijdens de eigen slaganimatie negeren, (c) zware slag L1 = 45 ticks ×1,4, L2 = 100 ticks ×2,4. Gevolg voor Dax: keten 39,3 DPS (beste stijl), L1-loop 28,8 (73% van de keten, maar staggert altijd), L2-loop 40,4 (103% van de keten, wel 1,67 s vasthouden op halve loopsnelheid). TTK van het Kennisbeest (t3) daalt met de keten van 8,7 s naar 1,35 s.

## Hoe gemeten
- **Nieuw meetinstrument** `tools/battlesim/f5_sim.gd` (`-- --f5sim`, alleen op de scratch-branch). Het draait de **echte `SomArena`** headless (Godot 4.3, `step_ticks`, 60 Hz), laadt `archief_v1_gang` met de echte party (`GameState._build_som_state`, Lv 3, startuitrusting) en geeft per tick gescripte input (`_pending.attack/hold`), net als `charge_tests.gd`. De keten, het opladen, de animatieduur, de meter en de schadeformule komen dus allemaal uit de spelcode.
- Het doelwit is één echte vijand met oneindig HP en **ATK 0**. De speler blijft er elke tick naast staan, met de kijkrichting erop. 1800 ticks (30 s) per meting, na 30 ticks opwarmen.
- **TTK per vijand** = echte max-HP van die vijand (archief-tier + `apply_action_area`) gedeeld door de gemeten DPS bij **zijn eigen DEF**.
- **Bondgenoot-AI**: bestuurde held doet niets (`idle`), `allies_enabled = true`, 5 herhalingen met verschillende seed (de AI-beweging is niet helemaal seed-vast: de Orion-groep varieert, zie min-max).
- **Determinisme**: alle speler- en TTK-metingen zijn bit-gelijk bij een herhaalde run (gecontroleerd). Alleen de bondgenoot-runs variëren.
- **Wipe-kans en Golem**: met de bestaande simulators. `--actionsim` (alle 9 iteraties, 300 gevechten per kamer, `actionsim_alle_iteraties.md`) en `--battlesim --only=golem --fights=2000` (`battlesim_golem_baseline.*`). De Golem-runs uit `--actionsim --only-final --boss-fights=500` staan in `actionsim_baseline.*`.

Speelstijlen (beleid van de bestuurde held):
| code | betekenis |
|---|---|
| wacht_vol | alleen slaan bij 100% meter (keten valt steeds terug naar hit1) |
| keten_snel | tikken zodra de eigen animatie klaar is |
| keten_ai | tempo van de bondgenoot-AI: hit1 bij volle meter, vervolgslag 6 ticks na de animatie |
| mash8 | elke 8 ticks een tik, ook tijdens de animatie (rammen) |
| zwaar1 / zwaar2 | indrukken + vasthouden tot L1/L2, loslaten, herhalen (het indrukken geeft ook een gewone tik) |
| keten_zwaar1/2 | hit1-hit2-finisher op AI-tempo, daarna een L1/L2 |

## Gemeten: huidige waarden
Keten 20 ticks, ×1,0/1,1/1,6, hitstop 0/0/6, knockback 1/1/2. Zwaar: start 12 ticks, L1 40 ticks ×2,0 (8/2), L2 90 ticks ×3,0 (12/3). Bondgenoot: vervolg na 6 ticks, L1 na elke finisher.

### DPS per held, als bestuurde held (vs eerste vijand archief_v1_gang, DEF 2)
| held | wacht_vol | keten_snel | keten_ai | mash8 | zwaar1 | zwaar2 | keten+L1 | keten+L2 |
|---|---|---|---|---|---|---|---|---|
| Dax | 17,9 | 5,9 | 12,5 | 28,9 | **42,9** | **48,2** | 21,1 | 28,0 |
| Seren | 7,0 | 2,1 | 4,9 | 10,3 | 16,5 | 18,6 | 8,2 | 10,9 |
| Vesper | 4,6 | 1,6 | 3,2 | 7,7 | 11,2 | 12,3 | 5,5 | 7,2 |
| Kael Voss | 7,5 | 2,4 | 5,3 | 11,2 | 17,8 | 20,1 | 8,9 | 11,8 |
| Orion | 9,9 | 3,4 | 6,9 | 16,8 | 23,6 | 26,5 | 11,8 | 15,5 |

Bij elke held: zwaar2 > zwaar1 > mash8 > wacht_vol > keten. **L2 domineert de keten** (Dax: 48,2 tegen 5,9 bij snel ketenen, 8,2×).

### DPS als AI-bondgenoot (gemiddelde van 5 runs, min-max)
| held | DPS AI |
|---|---|
| Dax | 49,3 (48,0-49,8) |
| Orion | 23,6 (17,8-28,0) |
| Kael Voss | 23,9 (23,4-24,5) |
| Seren | 19,3 (18,9-19,8) |
| Vesper | 16,7 (15,4-17,5) |

### TTK per vijand (seconden, Dax solo; laatste kolom = party Dax wacht_vol + Seren AI + Vesper AI)
| vijand@tier | HP | DEF | wacht_vol | keten_snel | keten_ai | mash8 | zwaar1 | zwaar2 | keten+L1 | party |
|---|---|---|---|---|---|---|---|---|---|---|
| mosslijm@t1 | 33 | 2 | 1,84 | 5,56 | 2,64 | 1,14 | 0,77 | 0,68 | 1,56 | 0,60 |
| papiergeest@t1 | 31 | 3 | 1,75 | 5,31 | 2,51 | 1,09 | 0,73 | 0,65 | 1,49 | 0,58 |
| moskonijn@t1 | 31 | 3 | 1,75 | 5,31 | 2,51 | 1,09 | 0,73 | 0,65 | 1,49 | 0,58 |
| glitchmot@t1 | 33 | 2 | 1,84 | 5,56 | 2,64 | 1,14 | 0,77 | 0,68 | 1,56 | 0,60 |
| papiergeest@t2 | 38 | 4 | 2,19 | 6,67 | 3,10 | 1,37 | 0,91 | 0,81 | 1,84 | 0,74 |
| glitchmot@t2 | 38 | 4 | 2,19 | 6,67 | 3,10 | 1,37 | 0,91 | 0,81 | 1,84 | 0,74 |
| mech_wachter@t2 | 33 | 8 | 2,03 | 6,00 | 2,89 | 1,25 | 0,85 | 0,76 | 1,73 | 0,76 |
| kennis_beest@t2 | 41 | 7 | 2,49 | 7,32 | 3,57 | 1,53 | 1,04 | 0,92 | 2,11 | 0,90 |
| mech_wachter@t3 | 40 | 9 | 2,52 | 7,27 | 3,57 | 1,52 | 1,05 | 0,93 | 2,12 | 0,96 |
| kennis_beest@t3 | 48 | 8 | 2,95 | 8,73 | 4,21 | 1,82 | 1,23 | 1,10 | 2,51 | 1,10 |
| glitchmot@t3 | 44 | 5 | 2,58 | 7,81 | 3,68 | 1,60 | 1,08 | 0,96 | 2,17 | 0,89 |
| papiergeest@t3 | 43 | 6 | 2,56 | 7,63 | 3,64 | 1,59 | 1,07 | 0,95 | 2,16 | 0,91 |

### Wipe-kans (bestaande `--actionsim`, abstract model)
| scenario | winst | wipe | HP-verlies | bron |
|---|---|---|---|---|
| alle SoM-kamers, huidige SomData (it7) | 99,9% | 0,1% | 15,8% (p90 38,7%) | actionsim_alle_iteraties.md |
| idem, speler "spam" | n.v.t. | n.v.t. | 17,2% | idem |

**Let op:** `action_sim.gd` modelleert de keten en de zware slag **niet** (één slag per volle meter). De wipe-kans hierboven verandert dus niet door dit voorstel en kan voor de nieuwe waarden **niet gemeten worden** zonder het model uit te breiden.

### Golem (bazen = altijd turn-based, ook in Action)
| scenario | winst | wipe | rondes | HP-verlies | bron |
|---|---|---|---|---|---|
| SoM-party Lv 3 (Dax/Vesper/Seren), 500 gevechten | 99,6% | 0,4% | 4,6 | 24,9% | actionsim_baseline.md |
| SoM-party Lv 5, 500 gevechten | 100,0% | 0,0% | 4,2 | 19,1% | idem |
| Dax solo Lv 8 (Classic-scenario), 2000 gevechten | 84% | 16% | 15,1 | 65% (p90 100%) | battlesim_golem_baseline.md |

De "Action-baasvermenigvuldiger" (HP ×2,3, ATK ×1,6) uit `ACTION_BALANCE_REPORT.md` wordt **niet meer gebruikt** (SomData: bazen blijven turn-based). De rijen "Classic" en "CHOSEN" geven daarom exact dezelfde uitkomst. Keten en zware slag kunnen de Golem niet beïnvloeden. **TTK van de Golem in realtime en DPS van de helden tegen de Golem zijn niet te meten**: er bestaat geen realtime Golem-gevecht.

## Problemen
1. **Keten = val voor de speler** (5,9 tegen 17,9 DPS). De meter op 10% bij hit2/finisher maakt de 1,1×/1,6× zinloos. Door het venster (20 ticks) kan de meter (60 ticks) nooit vol zijn.
2. **Zware slag strikt dominant.** L2 is de hoogste DPS van het spel en L1 de tweede, bij elke held. Er is geen risico-afweging, want 90 ticks vasthouden levert gewoon meer op. (De zware slag gebruikt `base_mult` 1,0 en negeert de wapenmeter.)
3. **Rammen > geduld** (28,9 tegen 17,9). `sim_step` voert elke tik uit, ook tijdens `swing_lock`.
4. **AI > speler.** Dax-AI 49,3 tegen Dax-speler max 17,9 (zonder zwaar). De AI-meter (`som_ally.gd`) laadt ook tijdens de animatie op, en `chain_swing` slaat op 1,0 zonder meter.
5. **Golem te makkelijk voor de SoM-party** (99,6% op Lv 3, doel 60-80%). Dit ligt buiten de keten en de zware slag.

## Voorstel (nieuwe waarden), plus gemeten resultaat
Twee kleine codeschakelaars (op de scratch-branch, **standaard uit** = huidig gedrag) plus waarden:

| waarde | nu | voorstel |
|---|---|---|
| `SomChainData.FOLLOWUP_MIN_METER` (nieuw; hit2/finisher binnen het venster slaan minstens op deze meter) | (geen = 0,1-bodem) | **1,0** |
| `SomChainData.TAP_GATE` (nieuw; tik tijdens eigen slaganimatie negeren) | (geen = false) | **true** |
| `SomChainData.CHAIN_WINDOW_TICKS` / `DAMAGE_MULT` / hitstop / knockback | 20 / 1,0-1,1-1,6 / 0-0-6 / 1-1-2 | **ongewijzigd** |
| `SomHeavyData.LEVEL_TICKS` | 40, 90 | **45, 100** |
| `SomHeavyData.DAMAGE_MULT` | 2,0, 3,0 | **1,4, 2,4** |
| `SomHeavyData` hitstop / knockback / MOVE_MULT / HOLD_START | 8-12 / 2-3 / 0,5 / 12 | ongewijzigd |

Code (scratch, 4 regels in `som_arena.gd`): in `attack()` geldt bij `step > 0` `mult = max(charge_mult(charge), FOLLOWUP_MIN_METER)`, en in `sim_step()` wordt een tik genegeerd zolang `TAP_GATE and swing_lock > 0`. Zie `f5_sim/scratch_branch.diff`.

### Gemeten DPS met het voorstel (bestuurde held)
| held | wacht_vol | keten_snel | keten_ai | mash8 | zwaar1 | zwaar2 | keten+L1 | keten+L2 |
|---|---|---|---|---|---|---|---|---|
| Dax | 17,9 | **39,3** | 34,5 | 38,2 | 28,8 | 40,4 | 31,9 | 38,5 |
| Seren | 7,0 | 15,1 | 13,4 | 14,7 | 11,1 | 15,6 | 12,4 | 14,9 |
| Vesper | 4,6 | 10,1 | 8,7 | 9,9 | 7,6 | 10,4 | 8,3 | 10,0 |
| Kael Voss | 7,5 | 16,3 | 14,5 | 15,8 | 11,9 | 17,0 | 13,3 | 16,1 |
| Orion | 9,9 | 21,7 | 18,9 | 21,2 | 15,9 | 22,2 | 17,6 | 21,2 |

- Keten (snel) is nu de beste stijl zonder te hoeven vasthouden: 2,2× wachten.
- L1 = 73% van de keten. Het is de "veilige" stagger-knop: hij staggert altijd, met 8 hitstop en 2 tegels knockback.
- L2 = 103% van de keten. Een klein voordeel in ruil voor 100 ticks (1,67 s) vasthouden op 50% loopsnelheid (dodge annuleert). Dat is risk/reward, niet meer strikt beter (was 820% van de keten).
- Rammen levert hetzelfde op als de keten (38,2 tegen 39,3) en geen bonus meer.

### Bondgenoot-AI met het voorstel (gemiddeld van 5 runs, min-max)
Dax 44,2 (42,4-45,3) · Orion 23,0 (18,9-24,4) · Kael Voss 21,8 (21,3-22,4) · Seren 17,2 (16,6-17,8) · Vesper 15,4 (13,6-16,2).
De lichte daling komt door de goedkopere L1. **AI-Dax (44,2) blijft boven speler-Dax (keten 39,3).** Met waarden alleen is dat niet op te lossen: de AI-meter laadt tijdens de animatie (`som_ally.gd` r. 110) en negeert `CHARGE_AFTER_ANIM`. Aanbevolen (niet gemeten, code): de AI dezelfde meter-regel geven als de speler.

### TTK met het voorstel (seconden, Dax solo; party = Dax wacht_vol + Seren/Vesper AI)
| vijand@tier | wacht_vol | keten_snel | keten_ai | mash8 | zwaar1 | zwaar2 | keten+L1 | party |
|---|---|---|---|---|---|---|---|---|
| mosslijm@t1 | 1,84 | 0,84 | 0,96 | 0,86 | 1,15 | 0,82 | 1,04 | 0,64 |
| papiergeest@t1 | 1,75 | 0,80 | 0,91 | 0,82 | 1,09 | 0,78 | 0,99 | 0,62 |
| moskonijn@t1 | 1,75 | 0,80 | 0,91 | 0,82 | 1,09 | 0,78 | 0,99 | 0,62 |
| glitchmot@t1 | 1,84 | 0,84 | 0,96 | 0,86 | 1,15 | 0,82 | 1,04 | 0,64 |
| papiergeest@t2 | 2,19 | 1,00 | 1,14 | 1,03 | 1,36 | 0,97 | 1,23 | 0,79 |
| glitchmot@t2 | 2,19 | 1,00 | 1,14 | 1,03 | 1,36 | 0,97 | 1,23 | 0,79 |
| mech_wachter@t2 | 2,03 | 0,93 | 1,06 | 0,96 | 1,27 | 0,90 | 1,15 | 0,80 |
| kennis_beest@t2 | 2,49 | 1,13 | 1,29 | 1,16 | 1,54 | 1,10 | 1,40 | 0,95 |
| mech_wachter@t3 | 2,52 | 1,14 | 1,31 | 1,17 | 1,57 | 1,12 | 1,41 | 1,01 |
| kennis_beest@t3 | 2,95 | 1,35 | 1,54 | 1,39 | 1,85 | 1,32 | 1,67 | 1,16 |
| glitchmot@t3 | 2,58 | 1,18 | 1,34 | 1,21 | 1,60 | 1,14 | 1,45 | 0,94 |
| papiergeest@t3 | 2,56 | 1,17 | 1,33 | 1,20 | 1,59 | 1,14 | 1,44 | 0,96 |

### Alleen de waarden, zonder de twee codeschakelaars (ter vergelijking, Dax)
Zwaar 45/100 ticks ×1,4/2,4 zonder schakelaars: wacht 17,9 · keten_snel 5,9 · keten_ai 12,5 · mash 28,9 · L1 28,8 · L2 **40,4**. L2 blijft dan 6,8× de keten. **Alleen waarden in `som_heavy_data.gd` lossen het niet op.** De ketenfix (`FOLLOWUP_MIN_METER`) is de kern van het voorstel. (`f5_sim_alleen_waarden.*`)

Tussenvarianten die ik heb geprobeerd (Dax, met beide schakelaars aan, `f5_sim_v1..v4`):
| variant | zwaar ticks | zwaar mult | L1 | L2 | keten_snel |
|---|---|---|---|---|---|
| v1 | 40, 90 | 2,0, 3,0 | 42,9 | 48,2 | 39,3 |
| v2 | 40, 90 | 1,5, 2,5 | 32,9 | 42,0 | 39,3 |
| v3 | 40, 100 | 1,5, 2,4 | 32,9 | 40,4 | 39,3 |
| **v4 = voorstel** | 45, 100 | 1,4, 2,4 | 28,8 | 40,4 | 39,3 |
Wil je L2 exact gelijk aan de keten, dan is ×2,3 het logische volgende punt. **Dat heb ik niet gemeten.**

## Wat de simulator NIET meet (eerlijk)
- **Knockback-kosten en hitstop-veiligheid**: de speler "teleporteert" elke tick terug naast de vijand en de vijand heeft ATK 0. Het voordeel van knockback (afstand) en hitstop (vijand bevriest) en de kosten (teruglopen) zitten niet in de DPS. Hitstop/knockback heb ik daarom **niet veranderd**.
- **Risico van L2** (1,67 s halve snelheid, geraakt worden): niet gemeten, omdat de vijand niet terugslaat in deze meting.
- **Wipe-kans met het voorstel**: niet meetbaar, `action_sim.gd` kent geen keten of zware slag.
- **Golem in realtime**: bestaat niet (bazen zijn turn-based). Geen held-DPS tegen de Golem.
- Kamergevechten met meerdere vijanden tegelijk: de DPS is gemeten tegen één doel.

## Reproduceren
```
cd /workspace/combat/f5            # branch scratch/f5-balans (lokaal, commit 1f8d5bc, niet gepusht)
/workspace/combat/f5_sim/variant.sh voorstel 1.0 true "1.0, 1.1, 1.6" "45, 100" "1.4, 2.4"
/workspace/combat/f5_sim/variant.sh baseline 0.0 false "1.0, 1.1, 1.6" "40, 90" "2.0, 3.0"
```
Grafieken: `f5_sim/f5_dps_dax.png`, `f5_sim/f5_ttk_kennisbeest.png`.
