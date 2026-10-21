# Balans Archief 1 in Action (PR7, branch rpgcode/balans-archief1)

Scope (Forge, 21 okt 2026): alleen Action, kamers archief_v1..v4. Classic en bazen blijven ongemoeid.
Doelen: verse Dax 3-3.5 volle slagen per gewone vijand (HP NIET meer aangepast na review); Dax solo lv1 in
archief_v1_gang 80-90% winst en 30-50% HP-verlies; v2-v4 op hun verwachte level geleidelijk naar 60-75% winst.

## Wat er veranderd is (alleen data in `SomData.ACTION_AREAS.archief1`, alleen in de realtime arena)

| sleutel | waarde | betekenis |
|---|---|---|
| rooms | archief_v1_ .. archief_v4_ | 8 kamers |
| tier_level | tier 1->lv1, 2->lv2, 3->lv3, 4->lv4 | verwacht Dax-level per kamer-tier |
| hp_hits | [2.5, 3.0] (ongewijzigd t.o.v. de eerste versie) | vijand-HP tussen 2.5x en 3.0x de gemiddelde volle slag van een verse Dax op dat level |
| tiers.1 | schade x1.10, cooldown x3.0 | tier 1: harder per klap, maar veel minder vaak |
| tiers.2 | schade x1.00, cooldown x2.8 | |
| tiers.3 | schade x0.70, cooldown x2.8 | |
| tiers.4 | schade x0.70, cooldown x2.8 | |
| targets | per tier winst; tier 1 ook gemiddeld verlies <= 80% | bewaakt door --balansarchief1test |

- "atk" werkt nu op de realtime vijandschade (`SomData.enemy_damage_mult(room, tier)` = ENEMY_DAMAGE_MULT x factor), niet
  op de atk-stat: tier-1-vijanden hebben atk 5-6, dus een factor op de stat springt in hele stappen (0.90 -> 100% winst,
  0.95 -> 45%). Op de schade is hij fijn instelbaar. Cooldown: `SomData.attack_cooldown(room, tier)`.
- Classic (battle.gd) leest niets hiervan (test: turn-based gevecht in archief_v1_gang heeft exact de oude HP/ATK/DEF).
  Bazen komen niet in de arena en openen turn-based met Classic-stats (--somroomstest). Unieke vijanden ongewijzigd.

## Meting (tools/battlesim/archief1_balans.gd, `-- --archief1balans --fights=150`)

Model: verse Dax = nieuw spel, alleen Dax, geen uitrusting. Slagen = echte formule (2000 trekkingen). Kamer =
action_sim.fight_room (Dax solo, vol HP aan het begin, alle gewone vijanden van de kamer, max 2 tegelijk), 150 gevechten.
Afstemmen: `-- --archief1balans --tune [--fijn] [--tiers=1]` (rooster schade x cooldown per tier).

### Meting, 150 gevechten per kamer per level

Regels nu (SomData.ACTION_AREAS.archief1): HP geklemd op [2.5, 3] x volle slag van verse Dax op tier-level { 0: 1, 1: 1, 2: 2, 3: 3, 4: 4 }; per tier schade (atk) / cooldown: { 1: { "atk": 1.1, "cooldown": 3 }, 2: { "atk": 1, "cooldown": 2.8 }, 3: { "atk": 0.7, "cooldown": 2.8 }, 4: { "atk": 0.7, "cooldown": 2.8 } }.

### Volle slagen per gewone vijand (gemiddeld; min-max over de vijanden)

| Dax lv | Dax HP/ATK/DEF | voor | na |
|---|---|---|---|
| 1 | 42 / 14 / 8 | 3.25 (1.00-8.74) | 4.22 (3.00-6.38) |
| 2 | 51 / 17 / 10 | 2.64 (1.00-6.72) | 3.41 (2.58-5.00) |
| 3 | 60 / 20 / 12 | 2.22 (1.00-5.30) | 2.84 (2.00-4.00) |
| 4 | 69 / 23 / 14 | 1.96 (1.00-4.67) | 2.52 (2.00-3.45) |
| 5 | 78 / 26 / 16 | 1.74 (1.00-4.00) | 2.28 (2.00-3.00) |

### Per vijand: volle slagen bij Dax lv 1 en op het verwachte level van de tier

| vijand@tier | lv1 voor | lv1 na | verwacht lv | voor | na |
|---|---|---|---|---|---|
| mosslijm@1 | 1.00 | 3.00 | 1 | 1.00 | 3.00 |
| papiergeest@1 | 1.00 | 3.00 | 1 | 1.00 | 3.00 |
| moskonijn@1 | 1.00 | 3.00 | 1 | 1.00 | 3.00 |
| glitchmot@1 | 1.00 | 3.00 | 1 | 1.00 | 3.00 |
| papiergeest@2 | 2.00 | 3.79 | 2 | 1.83 | 3.00 |
| glitchmot@2 | 1.65 | 3.78 | 2 | 1.00 | 3.00 |
| mech_wachter@2 | 3.86 | 3.96 | 2 | 3.00 | 3.00 |
| kennis_beest@2 | 5.01 | 4.22 | 2 | 4.00 | 3.48 |
| glitchmot@3 | 2.00 | 4.11 | 3 | 1.12 | 3.00 |
| mech_wachter@3 | 4.79 | 4.80 | 3 | 3.00 | 3.00 |
| kennis_beest@3 | 6.59 | 5.08 | 3 | 4.11 | 3.42 |
| papiergeest@3 | 2.14 | 4.22 | 3 | 2.00 | 3.00 |
| mech_wachter@4 | 5.93 | 5.92 | 4 | 3.01 | 3.01 |
| glitchmot@4 | 2.02 | 5.00 | 4 | 1.42 | 3.00 |
| kennis_beest@4 | 8.74 | 6.38 | 4 | 4.67 | 3.45 |

### HP die Dax (alleen, vol HP per kamer) per kamer verliest: gemiddeld (winst%)

ontwijkt = kans dat de speler een getelegrafeerde klap ontwijkt (sim-model action_sim: 35%; geoefend: dodge_skill).

| kamer | lv | voor (35%) | na (35%) | voor (geoefend) | na (geoefend) |
|---|---|---|---|---|---|
| archief_v1_gang | 1 | 14.4 (100%) | 32.5 (89%) | 9.4 (100%) | 21.2 (99%) |
| archief_v1_gang | 2 | 8.0 (100%) | 16.2 (100%) | 4.7 (100%) | 10.1 (100%) |
| archief_v1_gang | 3 | 6.5 (100%) | 11.3 (100%) | 4.0 (100%) | 7.5 (100%) |
| archief_v1_gang | 4 | 6.6 (100%) | 11.0 (100%) | 3.9 (100%) | 7.0 (100%) |
| archief_v1_gang | 5 | 6.4 (100%) | 11.1 (100%) | 4.3 (100%) | 7.1 (100%) |
| archief_v2_kastenzaal | 1 | 41.0 (13%) | 39.2 (25%) | 34.3 (49%) | 30.5 (65%) |
| archief_v2_kastenzaal | 2 | 39.2 (85%) | 31.8 (97%) | 24.4 (99%) | 20.1 (99%) |
| archief_v2_kastenzaal | 3 | 23.3 (100%) | 26.8 (100%) | 15.4 (100%) | 17.6 (100%) |
| archief_v2_kastenzaal | 4 | 15.6 (100%) | 19.9 (100%) | 10.6 (100%) | 13.1 (100%) |
| archief_v2_kastenzaal | 5 | 11.3 (100%) | 13.5 (100%) | 7.0 (100%) | 7.9 (100%) |
| archief_v2_leeszaal | 1 | 41.8 (3%) | 41.7 (5%) | 39.6 (25%) | 37.5 (35%) |
| archief_v2_leeszaal | 2 | 44.5 (51%) | 42.3 (67%) | 32.0 (89%) | 29.0 (94%) |
| archief_v2_leeszaal | 3 | 31.9 (99%) | 36.0 (99%) | 20.1 (100%) | 24.3 (100%) |
| archief_v2_leeszaal | 4 | 18.5 (100%) | 23.3 (100%) | 12.2 (100%) | 14.7 (100%) |
| archief_v2_leeszaal | 5 | 11.8 (100%) | 14.9 (100%) | 8.0 (100%) | 9.5 (100%) |
| archief_v2_trapzaal | 1 | 41.8 (3%) | 36.8 (49%) | 39.6 (21%) | 25.5 (77%) |
| archief_v2_trapzaal | 2 | 48.2 (21%) | 30.9 (88%) | 36.6 (71%) | 19.6 (98%) |
| archief_v2_trapzaal | 3 | 44.4 (82%) | 21.3 (100%) | 31.8 (91%) | 15.3 (100%) |
| archief_v2_trapzaal | 4 | 35.1 (100%) | 18.8 (100%) | 22.0 (100%) | 12.1 (100%) |
| archief_v2_trapzaal | 5 | 28.0 (100%) | 12.9 (100%) | 17.5 (100%) | 8.8 (100%) |
| archief_v3_zuilenhal | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 41.7 (4%) |
| archief_v3_zuilenhal | 2 | 51.0 (0%) | 50.7 (1%) | 51.0 (0%) | 44.7 (41%) |
| archief_v3_zuilenhal | 3 | 60.0 (0%) | 55.5 (48%) | 59.0 (8%) | 40.5 (87%) |
| archief_v3_zuilenhal | 4 | 69.0 (1%) | 47.0 (97%) | 63.0 (29%) | 33.0 (99%) |
| archief_v3_zuilenhal | 5 | 65.8 (70%) | 35.5 (100%) | 50.3 (93%) | 24.2 (100%) |
| archief_v3_gang | 1 | 42.0 (0%) | 41.6 (4%) | 42.0 (0%) | 37.8 (31%) |
| archief_v3_gang | 2 | 51.0 (0%) | 46.4 (32%) | 50.8 (3%) | 34.7 (79%) |
| archief_v3_gang | 3 | 59.9 (1%) | 34.1 (96%) | 55.2 (25%) | 24.5 (99%) |
| archief_v3_gang | 4 | 67.8 (13%) | 28.8 (100%) | 57.5 (59%) | 21.0 (100%) |
| archief_v3_gang | 5 | 61.9 (77%) | 23.7 (100%) | 40.9 (97%) | 15.8 (100%) |
| archief_v4_wachtersgang | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) |
| archief_v4_wachtersgang | 2 | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) | 50.0 (10%) |
| archief_v4_wachtersgang | 3 | 60.0 (0%) | 59.7 (2%) | 60.0 (0%) | 55.0 (38%) |
| archief_v4_wachtersgang | 4 | 69.0 (0%) | 64.6 (37%) | 68.9 (1%) | 44.7 (89%) |
| archief_v4_wachtersgang | 5 | 78.0 (0%) | 57.8 (91%) | 75.3 (16%) | 37.5 (98%) |
| archief_v4_voorhal | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 41.5 (5%) |
| archief_v4_voorhal | 2 | 51.0 (0%) | 50.4 (6%) | 51.0 (0%) | 46.2 (36%) |
| archief_v4_voorhal | 3 | 60.0 (0%) | 54.9 (39%) | 59.9 (1%) | 40.3 (81%) |
| archief_v4_voorhal | 4 | 69.0 (0%) | 44.8 (90%) | 67.4 (9%) | 30.7 (100%) |
| archief_v4_voorhal | 5 | 77.6 (4%) | 34.4 (100%) | 70.6 (39%) | 19.8 (100%) |

### Doel per tier (Dax solo op het verwachte level, 35% ontwijken)

| tier | Dax lv | kamers (winst/verlies) | gem. winst | doel winst | gem. verlies | doel verlies |
|---|---|---|---|---|---|---|
| 1 | 1 | v1_gang 89%/77% | 89% | 80-90% | 77% | 30-80% |
| 2 | 2 | v2_kastenzaal 97%/62%, v2_leeszaal 67%/83%, v2_trapzaal 88%/61% | 84% | 70-85% | 69% | - |
| 3 | 3 | v3_zuilenhal 48%/93%, v3_gang 96%/57% | 72% | 65-80% | 75% | - |
| 4 | 4 | v4_wachtersgang 37%/94%, v4_voorhal 90%/65% | 64% | 60-75% | 79% | - |


## Eerlijke kanttekening: tier-1-verliesdoel (30-50%) is niet samen met 80-90% winst haalbaar in de sim

Fijn rooster tier 1 (schade 0.50-1.30 in stappen van 0.05, cooldown 1.0-4.0 in stappen van 0.2, 150 gevechten):
de uitkomst is bimodaal. Of Dax wint 100% met 26-55% verlies, of hij wint <=97% met >=66% verlies. Er is geen
instelling met 80-90% winst en <=76% verlies. Beste opties:

| tier 1 schade / cooldown | winst | gem. verlies |
|---|---|---|
| 0.60 / 3.4 | 100% | 38% |
| 0.50 / 2.8 | 100% | 35% |
| 0.80 / 2.8 | 97% | 66% |
| 1.10 / 3.0 (GEKOZEN) | 89% | 77% |
| 1.25 / 3.4 | 90% | 76% |

Gekozen: het winstdoel (de progressieblokkade) gaat voor; het verliesdoel staat in de data als [0.30, 0.80] met
deze uitleg. Alternatief voor Forge: 0.60 / 3.4 (100% winst, 38% verlies) als het verliesdoel belangrijker is.
Oorzaak: een solo-Dax zonder genezing tegen een hele kamer; wie het haalt, haalt het meestal net.
Binnen een tier verschillen kamers sterk (v3_zuilenhal 48% vs v3_gang 96%); per-tier data kan dat niet gelijk trekken
zonder per-kamer-regels.


## Besluit Forge (21 okt 2026) en herstelpunt

- Tier 1 blijft op schade x1.10 / cooldown x3.0 (89% winst, 77% gemiddeld verlies). Testgrens: winst 80-90%, gemiddeld verlies <= 80%.
- Geen soft-lock: archief_ingang (de kamer vlak voor archief_v1_gang, uitgang "n") heeft een opslagboek (type "save") dat de party
  vol geneest (getest: HP 1 -> vol). Verliezen in archief_v1_gang zet je terug op het checkpoint (respawn_at_checkpoint, volle HP).
