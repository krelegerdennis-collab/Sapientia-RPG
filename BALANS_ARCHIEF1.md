# Balans Archief 1 in Action (PR7, branch rpgcode/balans-archief1)

Scope (Forge, 21 okt 2026): alleen Action, kamers archief_v1..v4. Classic en bazen blijven ongemoeid.
Doel: een verse Dax heeft 3-4 volle slagen nodig per gewone vijand; vijanden slaan iets harder, zodat ontwijken loont.

## Wat er veranderd is (data-gedreven, geen losse getallen in code)

`SomData.ACTION_AREAS.archief1` (scripts/data/som_data.gd), toegepast in `som_arena.gd enemy_stats()` en de
vijand-cooldown (`SomData.attack_cooldown(room_id)`), alleen in de realtime arena (Action):

| sleutel | waarde | betekenis |
|---|---|---|
| rooms | archief_v1_ .. archief_v4_ | 8 kamers |
| tier_level | tier 1->lv1, 2->lv2, 3->lv3, 4->lv4 | verwacht Dax-level per kamer-tier |
| hp_hits | [2.5, 3.0] | vijand-HP geklemd tussen 2.5x en 3.0x de gemiddelde volle slag van een verse Dax op dat level |
| hits | [3, 4] | doel, bewaakt door --balansarchief1test |
| atk | x1.15 | vijanden slaan 15% harder |
| cooldown | x1.6 | maar minder vaak (1.2 s -> 1.92 s): minder, zwaardere getelegrafeerde klappen |

- Classic (battle.gd) leest niets hiervan: test start een turn-based gevecht in archief_v1_gang en vergelijkt HP/ATK/DEF met de oude waarden.
- Bazen: komen nooit in de arena (register slaat map-bazen over) en openen altijd turn-based met Classic-stats (--somroomstest). Unieke vijanden: ongewijzigd.
- Kennis-Beest telt als gewone vijand in deze kamers (zijn "boss"-sleutel is alleen de config van het Golem-baasgevecht).

## Meting (tools/battlesim/archief1_balans.gd, `-- --archief1balans --fights=150`)

Model: verse Dax = nieuw spel, alleen Dax, geen uitrusting, level 1-5. Slagen = echte formule
(SomArena.physical_damage incl. 0.85-1.15 spreiding), 2000 trekkingen. Kamer-HP = action_sim.fight_room (Dax alleen,
vol HP aan het begin van de kamer, alle gewone vijanden van de kamer, max 2 tegelijk), 150 gevechten.

### Meting, 150 gevechten per kamer per level

Regels nu (SomData.ACTION_AREAS.archief1): HP geklemd op [2.5, 3] x volle slag van verse Dax op tier-level { 0: 1, 1: 1, 2: 2, 3: 3, 4: 4 }, atk x1.15, cooldown x1.60.

### Volle slagen per gewone vijand (gemiddeld; min-max over de vijanden)

| Dax lv | Dax HP/ATK/DEF | voor | na |
|---|---|---|---|
| 1 | 42 / 14 / 8 | 3.25 (1.00-8.74) | 4.22 (3.00-6.38) |
| 2 | 51 / 17 / 10 | 2.64 (1.00-6.70) | 3.41 (2.58-5.00) |
| 3 | 60 / 20 / 12 | 2.22 (1.00-5.30) | 2.84 (2.00-4.01) |
| 4 | 69 / 23 / 14 | 1.96 (1.00-4.65) | 2.52 (2.00-3.42) |
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
| kennis_beest@2 | 5.01 | 4.22 | 2 | 4.00 | 3.49 |
| glitchmot@3 | 2.00 | 4.11 | 3 | 1.13 | 3.00 |
| mech_wachter@3 | 4.79 | 4.80 | 3 | 3.00 | 3.00 |
| kennis_beest@3 | 6.59 | 5.08 | 3 | 4.10 | 3.42 |
| papiergeest@3 | 2.14 | 4.22 | 3 | 2.00 | 3.00 |
| mech_wachter@4 | 5.93 | 5.92 | 4 | 3.00 | 3.00 |
| glitchmot@4 | 2.02 | 5.00 | 4 | 1.42 | 3.00 |
| kennis_beest@4 | 8.74 | 6.38 | 4 | 4.65 | 3.42 |

### HP die Dax (alleen, vol HP per kamer) per kamer verliest: gemiddeld (winst%)

ontwijkt = kans dat de speler een getelegrafeerde klap ontwijkt (sim-model action_sim: 35%; geoefend: dodge_skill).

| kamer | lv | voor (35%) | na (35%) | voor (geoefend) | na (geoefend) |
|---|---|---|---|---|---|
| archief_v1_gang | 1 | 14.8 (100%) | 41.9 (3%) | 8.5 (100%) | 37.4 (45%) |
| archief_v1_gang | 2 | 7.9 (100%) | 35.8 (99%) | 5.2 (100%) | 23.8 (100%) |
| archief_v1_gang | 3 | 6.1 (100%) | 14.7 (100%) | 4.0 (100%) | 9.4 (100%) |
| archief_v1_gang | 4 | 6.3 (100%) | 12.4 (100%) | 3.7 (100%) | 8.1 (100%) |
| archief_v1_gang | 5 | 6.2 (100%) | 11.9 (100%) | 4.1 (100%) | 8.4 (100%) |
| archief_v2_kastenzaal | 1 | 40.9 (13%) | 41.9 (1%) | 34.1 (52%) | 39.8 (19%) |
| archief_v2_kastenzaal | 2 | 38.6 (85%) | 47.9 (27%) | 25.2 (95%) | 36.4 (71%) |
| archief_v2_kastenzaal | 3 | 24.1 (100%) | 46.0 (76%) | 15.8 (100%) | 32.2 (99%) |
| archief_v2_kastenzaal | 4 | 15.8 (100%) | 28.3 (100%) | 11.4 (100%) | 20.4 (100%) |
| archief_v2_kastenzaal | 5 | 11.0 (100%) | 23.7 (100%) | 7.2 (100%) | 16.8 (100%) |
| archief_v2_leeszaal | 1 | 42.0 (1%) | 42.0 (0%) | 38.9 (30%) | 41.6 (3%) |
| archief_v2_leeszaal | 2 | 44.0 (52%) | 50.6 (5%) | 31.8 (91%) | 43.0 (49%) |
| archief_v2_leeszaal | 3 | 29.0 (100%) | 54.6 (42%) | 18.6 (100%) | 42.9 (79%) |
| archief_v2_leeszaal | 4 | 19.2 (100%) | 39.1 (99%) | 11.8 (100%) | 26.5 (100%) |
| archief_v2_leeszaal | 5 | 12.6 (100%) | 29.8 (100%) | 8.2 (100%) | 19.5 (100%) |
| archief_v2_trapzaal | 1 | 42.0 (1%) | 41.6 (2%) | 39.6 (19%) | 36.1 (28%) |
| archief_v2_trapzaal | 2 | 49.1 (19%) | 44.6 (49%) | 39.1 (65%) | 32.8 (77%) |
| archief_v2_trapzaal | 3 | 45.3 (79%) | 40.2 (88%) | 29.9 (98%) | 26.5 (96%) |
| archief_v2_trapzaal | 4 | 35.4 (100%) | 30.7 (100%) | 22.5 (100%) | 20.8 (100%) |
| archief_v2_trapzaal | 5 | 27.1 (100%) | 21.5 (100%) | 17.3 (100%) | 14.7 (100%) |
| archief_v3_zuilenhal | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) |
| archief_v3_zuilenhal | 2 | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) |
| archief_v3_zuilenhal | 3 | 60.0 (0%) | 60.0 (0%) | 59.5 (7%) | 59.7 (6%) |
| archief_v3_zuilenhal | 4 | 68.9 (3%) | 68.8 (3%) | 65.2 (30%) | 64.5 (25%) |
| archief_v3_zuilenhal | 5 | 68.6 (58%) | 74.8 (29%) | 49.2 (95%) | 56.9 (84%) |
| archief_v3_gang | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 41.9 (1%) |
| archief_v3_gang | 2 | 51.0 (0%) | 51.0 (1%) | 50.5 (4%) | 49.5 (11%) |
| archief_v3_gang | 3 | 59.9 (1%) | 59.1 (5%) | 55.9 (31%) | 49.2 (47%) |
| archief_v3_gang | 4 | 68.2 (7%) | 64.0 (33%) | 57.7 (56%) | 46.3 (79%) |
| archief_v3_gang | 5 | 61.8 (79%) | 57.2 (91%) | 38.2 (97%) | 37.9 (98%) |
| archief_v4_wachtersgang | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) |
| archief_v4_wachtersgang | 2 | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) |
| archief_v4_wachtersgang | 3 | 60.0 (0%) | 60.0 (0%) | 60.0 (0%) | 59.9 (1%) |
| archief_v4_wachtersgang | 4 | 69.0 (0%) | 69.0 (0%) | 68.8 (1%) | 67.6 (9%) |
| archief_v4_wachtersgang | 5 | 78.0 (0%) | 77.8 (1%) | 76.0 (13%) | 73.3 (23%) |
| archief_v4_voorhal | 1 | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) | 42.0 (0%) |
| archief_v4_voorhal | 2 | 51.0 (0%) | 51.0 (0%) | 51.0 (0%) | 50.6 (2%) |
| archief_v4_voorhal | 3 | 60.0 (0%) | 60.0 (0%) | 60.0 (0%) | 59.2 (6%) |
| archief_v4_voorhal | 4 | 69.0 (0%) | 68.0 (5%) | 67.5 (12%) | 59.4 (33%) |
| archief_v4_voorhal | 5 | 77.7 (2%) | 71.7 (33%) | 71.9 (33%) | 56.3 (74%) |


## Conclusie en eerlijke kanttekening

- Doel slagen gehaald: elke gewone vijand kost op het verwachte level 3.0-3.5 volle slagen (was 1-4.7; tier-1
  vijanden gingen in 1 slag dood). Bij een hoger level dan verwacht zakt het naar 2-3 (beloning voor grinden).
- Vijanden slaan harder per klap (x1.15), maar minder vaak (cooldown x1.6).
- Keerzijde: omdat gewone vijanden nu 3x zo lang leven, verliest een SOLO Dax op level 1 de hele archief_v1_gang
  in de sim (was 15 HP verlies, 100% winst). Met geoefend ontwijken (60%) ~45-50% winst; vanaf level 2 100%.
  Archief_v2+ was solo al grotendeels dodelijk (ook voor deze PR). In het echte spel speelt de party (Vesper/Seren)
  mee en geneest Seren; de sim meet bewust alleen Dax. Als v1 voor solo lv1 milder moet: tier-1 atk/cooldown als
  aparte regel toevoegen (data, geen code) of hp_hits ondergrens voor tier 1 naar 2.0 (dan 2-3 slagen).
