# WM1 party-moeilijkheid (Action/realtime) — sim voor en na

Besluiten Dennis: 2026-11-02 22:53 (WM1-kerkers zwaarder: lv-3-party 60-90% winst onder de echte Action-regels) en
2026-11-03 00:50 (Dax-solo-doelen tier 3-4 verlagen zodat ze de nieuwe meting bevatten).

## Wat is er veranderd (alleen data, `scripts/data/som_data.gd`, `ACTION_AREAS.archief1`)

- Nieuw `room_rules`: per kamer een factor bovenop de tierregel, `area_rule` vermenigvuldigt ermee
  (dus ook `SomData.enemy_damage_mult` in de arena): wachtersgang atk x2.7, voorhal x2.8, zuilenhal x3.2.
  Overige kamers, cooldowns, HP (`hp_hits`), Classic, bazen en unieke vijanden: ongewijzigd.
- `targets` (Dax solo, bewaakt door `balansarchief1test`, dat de doelen uit de data leest — test ongewijzigd):
  tier 3 win 65-80% -> **40-60%**, tier 4 win 60-75% -> **0-15%**. Tier 1-2 ongewijzigd.

Waarom: de party (Dax + Seren + Vesper, lv 3) won elke WM1-kamer 100% met p90 HP-verlies ~37%. Alleen meer
monsters (groepen van 3-4, tot 20 vijanden) gaf nog 98.5-100% winst bij 37-66 s per kamer; dat is geen optie.
Hogere vijandschade in deze drie kamers wel, maar een verse Dax solo kan die kamers dan niet meer aan. Dax solo
is in WM1 niet de bedoelde situatie (party vanaf de start), dus de solo-doelen voor tier 3-4 zijn verlaagd naar
banden rond de nieuwe meting (50% / 3%) met marge.

## Methode

`action_sim.gd` `fight_room`, party = SoM-start op **level 3**, hele kamer achter elkaar zonder heal (alle gewone
monsters incl. groepen, geen baas), 200 runs per kamer, seed `hash([20261020, kamer, run])`, vijanden met
`apply_archief_tier` + `SomData.apply_action_area`, schade `SomData.enemy_damage_mult(kamer, tier)`, cooldown
`SomData.attack_cooldown(kamer, tier)`. (Tijdelijke wrapper, niet gecommit.)

## Party lv 3 (200 runs)

| kamer | tier | factor | winst voor | na | p90 HP-verlies voor | na | gem. duur voor | na |
|---|---|---|---|---|---|---|---|---|
| archief_v4_wachtersgang | 4 | x2.7 | 100% | 76% | 37% | 100% | 19.6 s | 21.5 s |
| archief_v4_voorhal | 4 | x2.8 | 100% | 77.5% | 37% | 100% | 17.0 s | 18.5 s |
| archief_v3_zuilenhal | 3 | x3.2 | 100% | 86.5% | 39% | 100% | 21.8 s | 23.3 s |

p90 100% = de slechtste 10% van de runs eindigt in een wipe. Winst is gevoelig: zuilenhal x3.4 gaf 68%.

## Dax solo (balansarchief1test, 500 gevechten per kamer)

| tier | doel voor | doel na | winst voor | na | per kamer na |
|---|---|---|---|---|---|
| 1 | 80-90% | 80-90% | 88% | 88% | ongewijzigd |
| 2 | 70-85% | 70-85% | 75% | 75% | ongewijzigd |
| 3 | 65-80% | 40-60% | 73% | 50% | zuilenhal 0%, gang 100% |
| 4 | 60-75% | 0-15% | 66% | 3% | wachtersgang 0%, voorhal 5% |
