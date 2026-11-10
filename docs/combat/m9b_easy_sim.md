# M9b — Easy-sim (voorstel)

VOORSTEL voor Dennis. Geen balanswijziging: `OnlineDlsModes.mode_exp_factor` blijft 10 (`PROPOSAL_MODE_EXP_NUMERATOR` 100 / 10 vloeren). De factor hier is alleen een parameter van deze sim.

Host-autoritatief, één RNG per gevecht. Zelfde seed = zelfde uitkomst.

- Modus: `easy`. Runs: 24. Vloeren: 10 (Page Warden, boss_key 10, op de laatste baasvloer).
- Basis-seed: `20261110`. `run_seed = (base + index * 10007) & 0x7FFFFFFF` (0 wordt 1).
- `combat_seed = mix(run_seed, vloer * 1000 + stoelen * 10 + soort, factor)` met soort 1=troep, 2=baas, 3=hypo vol HP, 4=hypo Orion-partij. `mix_seed` staat in `tools/battlesim/d100_mode_sim.gd`.
- Run-seeds: 20261110 20271117 20281124 20291131 20301138 20311145 20321152 20331159 20341166 20351173 20361180 20371187 20381194 20391201 20401208 20411215 20421222 20431229 20441236 20451243 20461250 20471257 20481264 20491271
- Page Warden VOORSTEL (ongewijzigd, #420): ACTION_HP_MULT 3.80, ACTION_ATK_MULT 2.60, SEAT_HP [0, 1, 2.6, 2.95, 3.35], SEAT_ATK [0, 1, 1.42, 1.43, 1.45].
- Partij: Dax, Seren, Vesper, Kael Voss, Orion. Stoel 0 is de host (ontwijk 0.35), de rest is AI (ontwijk 0.15). Bij 4 stoelen zit Orion er niet bij.
- Kaart: `OnlineDlsFloor.build` (eff, cap 8, groep = één vijand). Troep max 120 s, baas max 180 s, golf 2.
- Rust op Easy vloer 5 heelt levenden. Geen drankjes en geen feniksveer (handmatig in het spel, de AI gebruikt ze niet). M8a zit niet in de code: een held op 0 HP blijft liggen. Eén down is geen verlies.
- EXP per stoel, vol, meteen per vijand (`round_half_even(basis × factor)`). Keten: hit1/hit2/finisher, vervolg 6 ticks na de animatie. Klassieke DLS stript spreuken; deze sim houdt de klasse-spreuken.
- Duur is gevechtstijd (60 Hz), zonder looptijd. Tooltijd 40.2 s.

Herhalen:

```
xvfb-run -a godot --rendering-driver opengl3 --path . -- --d100modesim --mode=easy --factors=4,7,10,25 --seats=1,2,3,4 --runs=24 --seed=20261110 --floors=10 --out=res://docs/combat/m9b_easy_sim.md
```

## Per vloer

Level bij binnenkomst, vóór het gevecht. Winst = de vloer leeg (op vloer 10: troep én Page Warden). Een wipe telt ook als verlies. Niet bereikt = eerdere wipe of verlies.

HP in = partij-HP bij binnenkomst, vóór het rustpunt. Vijanden = gemiddelde op die vloer (zelfde kaarten voor elke factor).

| factor | stoelen | vloer | eff | level in | HP in | vijanden | bereikt | winst | verlies | wipes | duur s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 37.5% (9) | 62.5% (15) | 15 | 9.5 |
| 4 | 1 | 2 | 12 | 3.0 | 22% | 5.6 | 9/24 | 0.0% (0) | 100.0% (9) | 9 | 2.1 |
| 4 | 1 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 4 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 4 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.6 |
| 4 | 2 | 2 | 12 | 3.1 | 80% | 5.6 | 24/24 | 33.3% (8) | 66.7% (16) | 16 | 6.5 |
| 4 | 2 | 3 | 23 | 4.8 | 75% | 5.2 | 8/24 | 12.5% (1) | 87.5% (7) | 7 | 4.9 |
| 4 | 2 | 4 | 34 | 4.0 | 83% | 5.4 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 6.3 |
| 4 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.9 |
| 4 | 3 | 2 | 12 | 3.2 | 99% | 5.6 | 24/24 | 75.0% (18) | 25.0% (6) | 6 | 9.4 |
| 4 | 3 | 3 | 23 | 5.7 | 74% | 5.2 | 18/24 | 44.4% (8) | 55.6% (10) | 10 | 6.9 |
| 4 | 3 | 4 | 34 | 7.2 | 63% | 5.4 | 8/24 | 25.0% (2) | 75.0% (6) | 6 | 5.2 |
| 4 | 3 | 5 | 45 | 8.5 | 65% | 6.2 | 2/24 | 0.0% (0) | 100.0% (2) | 2 | 4.6 |
| 4 | 3 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 3 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 3 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 3 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 3 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 4.9 |
| 4 | 4 | 2 | 12 | 3.2 | 100% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 7.4 |
| 4 | 4 | 3 | 23 | 5.9 | 88% | 5.2 | 24/24 | 70.8% (17) | 29.2% (7) | 7 | 7.8 |
| 4 | 4 | 4 | 34 | 8.9 | 83% | 5.4 | 17/24 | 35.3% (6) | 64.7% (11) | 11 | 6.4 |
| 4 | 4 | 5 | 45 | 11.2 | 86% | 6.2 | 6/24 | 33.3% (2) | 66.7% (4) | 4 | 7.5 |
| 4 | 4 | 6 | 55 | 18.5 | 81% | 3.8 | 2/24 | 50.0% (1) | 50.0% (1) | 1 | 7.0 |
| 4 | 4 | 7 | 66 | 34.0 | 86% | 3.5 | 1/24 | 100.0% (1) | 0.0% (0) | 0 | 8.0 |
| 4 | 4 | 8 | 77 | 42.0 | 89% | 4.6 | 1/24 | 100.0% (1) | 0.0% (0) | 0 | 9.8 |
| 4 | 4 | 9 | 88 | 51.0 | 89% | 3.9 | 1/24 | 100.0% (1) | 0.0% (0) | 0 | 0.0 |
| 4 | 4 | 10 | 99 | 51.0 | 89% | 3.6 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 38.6 |
| 7 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 66.7% (16) | 33.3% (8) | 8 | 9.7 |
| 7 | 1 | 2 | 12 | 3.9 | 31% | 5.6 | 16/24 | 6.2% (1) | 93.8% (15) | 15 | 3.3 |
| 7 | 1 | 3 | 23 | 4.0 | 12% | 5.2 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 3.6 |
| 7 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 7 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 7 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.1 |
| 7 | 2 | 2 | 12 | 4.0 | 91% | 5.6 | 24/24 | 50.0% (12) | 50.0% (12) | 12 | 8.7 |
| 7 | 2 | 3 | 23 | 6.9 | 71% | 5.2 | 12/24 | 16.7% (2) | 83.3% (10) | 10 | 5.7 |
| 7 | 2 | 4 | 34 | 5.5 | 86% | 5.4 | 2/24 | 0.0% (0) | 100.0% (2) | 2 | 3.6 |
| 7 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 7 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.8 |
| 7 | 3 | 2 | 12 | 4.0 | 99% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.6 |
| 7 | 3 | 3 | 23 | 7.5 | 83% | 5.2 | 24/24 | 70.8% (17) | 29.2% (7) | 7 | 7.7 |
| 7 | 3 | 4 | 34 | 11.5 | 77% | 5.4 | 17/24 | 29.4% (5) | 70.6% (12) | 12 | 6.9 |
| 7 | 3 | 5 | 45 | 11.8 | 80% | 6.2 | 5/24 | 20.0% (1) | 80.0% (4) | 4 | 7.2 |
| 7 | 3 | 6 | 55 | 10.0 | 100% | 3.8 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 5.3 |
| 7 | 3 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 3 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 3 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 3 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 4.8 |
| 7 | 4 | 2 | 12 | 4.0 | 100% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 6.6 |
| 7 | 4 | 3 | 23 | 7.7 | 94% | 5.2 | 24/24 | 87.5% (21) | 12.5% (3) | 3 | 7.7 |
| 7 | 4 | 4 | 34 | 12.0 | 87% | 5.4 | 21/24 | 66.7% (14) | 33.3% (7) | 7 | 8.3 |
| 7 | 4 | 5 | 45 | 18.2 | 85% | 6.2 | 14/24 | 85.7% (12) | 14.3% (2) | 2 | 10.8 |
| 7 | 4 | 6 | 55 | 29.2 | 80% | 3.8 | 12/24 | 91.7% (11) | 8.3% (1) | 1 | 7.1 |
| 7 | 4 | 7 | 66 | 36.8 | 75% | 3.5 | 11/24 | 81.8% (9) | 18.2% (2) | 2 | 5.7 |
| 7 | 4 | 8 | 77 | 42.1 | 77% | 4.6 | 9/24 | 88.9% (8) | 11.1% (1) | 1 | 5.6 |
| 7 | 4 | 9 | 88 | 54.2 | 82% | 3.9 | 8/24 | 87.5% (7) | 12.5% (1) | 1 | 9.7 |
| 7 | 4 | 10 | 99 | 75.1 | 84% | 3.6 | 7/24 | 100.0% (7) | 0.0% (0) | 0 | 18.7 |
| 10 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 9.9 |
| 10 | 1 | 2 | 12 | 4.8 | 39% | 5.6 | 24/24 | 12.5% (3) | 87.5% (21) | 21 | 3.7 |
| 10 | 1 | 3 | 23 | 5.0 | 21% | 5.2 | 3/24 | 33.3% (1) | 66.7% (2) | 2 | 1.8 |
| 10 | 1 | 4 | 34 | 5.0 | 22% | 5.4 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 3.6 |
| 10 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 10 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 10 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 10 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 7.6 |
| 10 | 2 | 2 | 12 | 4.8 | 90% | 5.6 | 24/24 | 70.8% (17) | 29.2% (7) | 7 | 9.3 |
| 10 | 2 | 3 | 23 | 9.1 | 73% | 5.2 | 17/24 | 35.3% (6) | 64.7% (11) | 11 | 6.7 |
| 10 | 2 | 4 | 34 | 9.8 | 70% | 5.4 | 6/24 | 50.0% (3) | 50.0% (3) | 3 | 4.2 |
| 10 | 2 | 5 | 45 | 13.0 | 75% | 6.2 | 3/24 | 66.7% (2) | 33.3% (1) | 1 | 9.2 |
| 10 | 2 | 6 | 55 | 23.0 | 91% | 3.8 | 2/24 | 50.0% (1) | 50.0% (1) | 1 | 4.0 |
| 10 | 2 | 7 | 66 | 36.0 | 88% | 3.5 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 11.3 |
| 10 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.5 |
| 10 | 3 | 2 | 12 | 4.8 | 100% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.0 |
| 10 | 3 | 3 | 23 | 9.1 | 83% | 5.2 | 24/24 | 87.5% (21) | 12.5% (3) | 3 | 8.6 |
| 10 | 3 | 4 | 34 | 14.0 | 76% | 5.4 | 21/24 | 52.4% (11) | 47.6% (10) | 10 | 7.0 |
| 10 | 3 | 5 | 45 | 21.5 | 80% | 6.2 | 11/24 | 63.6% (7) | 36.4% (4) | 4 | 9.4 |
| 10 | 3 | 6 | 55 | 35.7 | 78% | 3.8 | 7/24 | 71.4% (5) | 28.6% (2) | 2 | 7.4 |
| 10 | 3 | 7 | 66 | 49.6 | 74% | 3.5 | 5/24 | 100.0% (5) | 0.0% (0) | 0 | 6.5 |
| 10 | 3 | 8 | 77 | 60.0 | 83% | 4.6 | 5/24 | 100.0% (5) | 0.0% (0) | 0 | 7.6 |
| 10 | 3 | 9 | 88 | 72.4 | 80% | 3.9 | 5/24 | 100.0% (5) | 0.0% (0) | 0 | 8.1 |
| 10 | 3 | 10 | 99 | 89.8 | 69% | 3.6 | 5/24 | 80.0% (4) | 20.0% (1) | 1 | 15.3 |
| 10 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 4.8 |
| 10 | 4 | 2 | 12 | 4.8 | 100% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 6.0 |
| 10 | 4 | 3 | 23 | 9.1 | 96% | 5.2 | 24/24 | 91.7% (22) | 8.3% (2) | 2 | 6.2 |
| 10 | 4 | 4 | 34 | 14.2 | 89% | 5.4 | 22/24 | 81.8% (18) | 18.2% (4) | 4 | 8.2 |
| 10 | 4 | 5 | 45 | 22.8 | 86% | 6.2 | 18/24 | 88.9% (16) | 11.1% (2) | 2 | 9.2 |
| 10 | 4 | 6 | 55 | 36.8 | 84% | 3.8 | 16/24 | 93.8% (15) | 6.2% (1) | 1 | 5.4 |
| 10 | 4 | 7 | 66 | 46.8 | 83% | 3.5 | 15/24 | 100.0% (15) | 0.0% (0) | 0 | 5.4 |
| 10 | 4 | 8 | 77 | 55.8 | 81% | 4.6 | 15/24 | 93.3% (14) | 6.7% (1) | 1 | 5.3 |
| 10 | 4 | 9 | 88 | 70.4 | 85% | 3.9 | 14/24 | 100.0% (14) | 0.0% (0) | 0 | 7.5 |
| 10 | 4 | 10 | 99 | 91.9 | 82% | 3.6 | 14/24 | 100.0% (14) | 0.0% (0) | 0 | 14.4 |
| 25 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 9.3 |
| 25 | 1 | 2 | 12 | 7.5 | 69% | 5.6 | 24/24 | 41.7% (10) | 58.3% (14) | 14 | 7.8 |
| 25 | 1 | 3 | 23 | 11.9 | 44% | 5.2 | 10/24 | 30.0% (3) | 70.0% (7) | 7 | 3.7 |
| 25 | 1 | 4 | 34 | 14.3 | 38% | 5.4 | 3/24 | 0.0% (0) | 100.0% (3) | 3 | 6.2 |
| 25 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 25 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 25 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 25 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 25 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 25 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 25 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 7.4 |
| 25 | 2 | 2 | 12 | 7.5 | 96% | 5.6 | 24/24 | 95.8% (23) | 4.2% (1) | 1 | 8.4 |
| 25 | 2 | 3 | 23 | 14.4 | 82% | 5.2 | 23/24 | 95.7% (22) | 4.3% (1) | 1 | 8.7 |
| 25 | 2 | 4 | 34 | 22.0 | 71% | 5.4 | 22/24 | 90.9% (20) | 9.1% (2) | 2 | 9.3 |
| 25 | 2 | 5 | 45 | 36.5 | 72% | 6.2 | 20/24 | 90.0% (18) | 10.0% (2) | 2 | 11.4 |
| 25 | 2 | 6 | 55 | 59.0 | 79% | 3.8 | 18/24 | 94.4% (17) | 5.6% (1) | 1 | 7.1 |
| 25 | 2 | 7 | 66 | 74.9 | 75% | 3.5 | 17/24 | 100.0% (17) | 0.0% (0) | 0 | 6.1 |
| 25 | 2 | 8 | 77 | 88.8 | 77% | 4.6 | 17/24 | 94.1% (16) | 5.9% (1) | 1 | 7.7 |
| 25 | 2 | 9 | 88 | 111.6 | 77% | 3.9 | 16/24 | 100.0% (16) | 0.0% (0) | 0 | 11.1 |
| 25 | 2 | 10 | 99 | 148.4 | 74% | 3.6 | 16/24 | 100.0% (16) | 0.0% (0) | 0 | 19.0 |
| 25 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.3 |
| 25 | 3 | 2 | 12 | 7.5 | 100% | 5.6 | 24/24 | 95.8% (23) | 4.2% (1) | 1 | 6.1 |
| 25 | 3 | 3 | 23 | 14.4 | 94% | 5.2 | 23/24 | 100.0% (23) | 0.0% (0) | 0 | 6.1 |
| 25 | 3 | 4 | 34 | 22.0 | 92% | 5.4 | 23/24 | 95.7% (22) | 4.3% (1) | 1 | 6.7 |
| 25 | 3 | 5 | 45 | 37.0 | 88% | 6.2 | 22/24 | 95.5% (21) | 4.5% (1) | 1 | 7.1 |
| 25 | 3 | 6 | 55 | 57.3 | 94% | 3.8 | 21/24 | 100.0% (21) | 0.0% (0) | 0 | 5.3 |
| 25 | 3 | 7 | 66 | 72.0 | 91% | 3.5 | 21/24 | 100.0% (21) | 0.0% (0) | 0 | 4.5 |
| 25 | 3 | 8 | 77 | 86.8 | 92% | 4.6 | 21/24 | 100.0% (21) | 0.0% (0) | 0 | 6.2 |
| 25 | 3 | 9 | 88 | 112.2 | 88% | 3.9 | 21/24 | 100.0% (21) | 0.0% (0) | 0 | 6.1 |
| 25 | 3 | 10 | 99 | 144.6 | 87% | 3.6 | 21/24 | 100.0% (21) | 0.0% (0) | 0 | 11.2 |
| 25 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 4.6 |
| 25 | 4 | 2 | 12 | 7.5 | 100% | 5.6 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.0 |
| 25 | 4 | 3 | 23 | 14.1 | 100% | 5.2 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 5.4 |
| 25 | 4 | 4 | 34 | 22.0 | 97% | 5.4 | 24/24 | 91.7% (22) | 8.3% (2) | 2 | 6.5 |
| 25 | 4 | 5 | 45 | 36.8 | 96% | 6.2 | 22/24 | 95.5% (21) | 4.5% (1) | 1 | 6.5 |
| 25 | 4 | 6 | 55 | 58.5 | 97% | 3.8 | 21/24 | 95.2% (20) | 4.8% (1) | 1 | 3.7 |
| 25 | 4 | 7 | 66 | 72.5 | 97% | 3.5 | 20/24 | 100.0% (20) | 0.0% (0) | 0 | 3.7 |
| 25 | 4 | 8 | 77 | 88.3 | 97% | 4.6 | 20/24 | 100.0% (20) | 0.0% (0) | 0 | 4.2 |
| 25 | 4 | 9 | 88 | 113.7 | 97% | 3.9 | 20/24 | 100.0% (20) | 0.0% (0) | 0 | 4.9 |
| 25 | 4 | 10 | 99 | 145.2 | 96% | 3.6 | 20/24 | 100.0% (20) | 0.0% (0) | 0 | 8.4 |

## Oorzaak van een verlies

HP in (tabel hierboven) is de partij-HP bij binnenkomst. HP uit is de partij-HP op het moment dat de vloer verloren gaat. Wipe = iedereen op 0. Time-out = tick-cap (troep 120 s, baas 180 s) terwijl er nog iemand leeft en er nog geslagen wordt. Softlock = tick-cap zonder een enkele slag, of de laatste 5 s geen slag en geen treffer.

| factor | stoelen | vloer | verliezen | wipe | time-out | softlock | anders | HP uit |
|---|---|---|---|---|---|---|---|---|
| 4 | 1 | 1 | 15 | 15 | 0 | 0 | 0 | 0% |
| 4 | 1 | 2 | 9 | 9 | 0 | 0 | 0 | 0% |
| 4 | 2 | 2 | 16 | 16 | 0 | 0 | 0 | 0% |
| 4 | 2 | 3 | 7 | 7 | 0 | 0 | 0 | 0% |
| 4 | 2 | 4 | 1 | 1 | 0 | 0 | 0 | 0% |
| 4 | 3 | 2 | 6 | 6 | 0 | 0 | 0 | 0% |
| 4 | 3 | 3 | 10 | 10 | 0 | 0 | 0 | 0% |
| 4 | 3 | 4 | 6 | 6 | 0 | 0 | 0 | 0% |
| 4 | 3 | 5 | 2 | 2 | 0 | 0 | 0 | 0% |
| 4 | 4 | 3 | 7 | 7 | 0 | 0 | 0 | 0% |
| 4 | 4 | 4 | 11 | 11 | 0 | 0 | 0 | 0% |
| 4 | 4 | 5 | 4 | 4 | 0 | 0 | 0 | 0% |
| 4 | 4 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 4 | 4 | 10 | 1 | 1 | 0 | 0 | 0 | 0% |
| 7 | 1 | 1 | 8 | 8 | 0 | 0 | 0 | 0% |
| 7 | 1 | 2 | 15 | 15 | 0 | 0 | 0 | 0% |
| 7 | 1 | 3 | 1 | 1 | 0 | 0 | 0 | 0% |
| 7 | 2 | 2 | 12 | 12 | 0 | 0 | 0 | 0% |
| 7 | 2 | 3 | 10 | 10 | 0 | 0 | 0 | 0% |
| 7 | 2 | 4 | 2 | 2 | 0 | 0 | 0 | 0% |
| 7 | 3 | 3 | 7 | 7 | 0 | 0 | 0 | 0% |
| 7 | 3 | 4 | 12 | 12 | 0 | 0 | 0 | 0% |
| 7 | 3 | 5 | 4 | 4 | 0 | 0 | 0 | 0% |
| 7 | 3 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 7 | 4 | 3 | 3 | 3 | 0 | 0 | 0 | 0% |
| 7 | 4 | 4 | 7 | 7 | 0 | 0 | 0 | 0% |
| 7 | 4 | 5 | 2 | 2 | 0 | 0 | 0 | 0% |
| 7 | 4 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 7 | 4 | 7 | 2 | 2 | 0 | 0 | 0 | 0% |
| 7 | 4 | 8 | 1 | 1 | 0 | 0 | 0 | 0% |
| 7 | 4 | 9 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 1 | 2 | 21 | 21 | 0 | 0 | 0 | 0% |
| 10 | 1 | 3 | 2 | 2 | 0 | 0 | 0 | 0% |
| 10 | 1 | 4 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 2 | 2 | 7 | 7 | 0 | 0 | 0 | 0% |
| 10 | 2 | 3 | 11 | 11 | 0 | 0 | 0 | 0% |
| 10 | 2 | 4 | 3 | 3 | 0 | 0 | 0 | 0% |
| 10 | 2 | 5 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 2 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 2 | 7 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 3 | 3 | 3 | 3 | 0 | 0 | 0 | 0% |
| 10 | 3 | 4 | 10 | 10 | 0 | 0 | 0 | 0% |
| 10 | 3 | 5 | 4 | 4 | 0 | 0 | 0 | 0% |
| 10 | 3 | 6 | 2 | 2 | 0 | 0 | 0 | 0% |
| 10 | 3 | 10 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 4 | 3 | 2 | 2 | 0 | 0 | 0 | 0% |
| 10 | 4 | 4 | 4 | 4 | 0 | 0 | 0 | 0% |
| 10 | 4 | 5 | 2 | 2 | 0 | 0 | 0 | 0% |
| 10 | 4 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 10 | 4 | 8 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 1 | 2 | 14 | 14 | 0 | 0 | 0 | 0% |
| 25 | 1 | 3 | 7 | 7 | 0 | 0 | 0 | 0% |
| 25 | 1 | 4 | 3 | 3 | 0 | 0 | 0 | 0% |
| 25 | 2 | 2 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 2 | 3 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 2 | 4 | 2 | 2 | 0 | 0 | 0 | 0% |
| 25 | 2 | 5 | 2 | 2 | 0 | 0 | 0 | 0% |
| 25 | 2 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 2 | 8 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 3 | 2 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 3 | 4 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 3 | 5 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 4 | 4 | 2 | 2 | 0 | 0 | 0 | 0% |
| 25 | 4 | 5 | 1 | 1 | 0 | 0 | 0 | 0% |
| 25 | 4 | 6 | 1 | 1 | 0 | 0 | 0 | 0% |

## Wat de sim gelijk doet aan de online Easy-run

- Tussen vloeren blijven HP en MP staan. Alleen rustvloer 5 (BookPoint.restore) vult levenden bij. Wie op 0 staat, blijft liggen.
- Eén down is geen verlies. De vloer eindigt als de vijanden dood zijn, als iedereen op 0 ligt, of op de tick-cap.
- Feniksveer en drankjes zijn een handmatige ring-actie (`PartyActions.use_item`). De bondgenoot-AI gebruikt ze niet. Deze sim ook niet. M8a ontbreekt, dus geen automatische revive.
- EXP valt per verslagen vijand, vol, aan elke levende held, meteen (`give_exp`). Een level-up vult HP bij met de groei.
- Aanvalsketen zoals `som_ally.gd`: hit1 ×1.0, hit2 ×1.1, finisher ×1.6, vervolg 6 ticks na de animatie (venster 20). De host ketent hetzelfde. Na de finisher laadt een AI-bondgenoot een zware slag niveau 1 (45 ticks, ×1.7).
- Page Warden: doelkeuze, klapvorm, bondgenoot-spreuk en adds komen uit `page_warden_rt_sim.gd`. De slag zelf blijft de keten; die sim laadt nog een volle meter.
- Doel is een vijand die al aangekomen is. Een nog lopende vijand verspilt de slag niet.
- Vijandschade × `ENEMY_DAMAGE_MULT` 2.2, dezelfde factor als `enemy_damage_mult` op een kamer zonder gebiedsregel.

## Logs van een verlies (laatste 300 ticks)

Alleen als de partij bij het verlies nog 60–90% HP heeft, of — als dat niet voorkomt — één wipe waarbij de HP naar 0 loopt. HP in is de binnenkomst van die vloer.

### wipe, factor 4, 1 stoelen, vloer 1, seed 20261110

Oorzaak `wipe`. HP in 100%. HP uit 0%.

```
t=73 slag Dax x1.00 14 naar 7/21
t=123 slag Dax x1.10 15 naar 0/21
t=123 neer Paper Wraith
t=140 raak Dax 18 → 33/51
t=162 slag Dax x1.60 27 naar 0/21
t=162 neer Paper Wraith
t=243 raak Dax 20 → 13/51
t=276 slag Dax x1.00 15 naar 3/18
t=301 raak Dax 18 → 0/51
```


## Page Warden (klim)

Alleen wie de troep op de baasvloer overleeft, vecht de baas. Level is dán (na de EXP van die troep). Winst-alle-runs telt een run die de baas niet haalt als verlies.

| factor | stoelen | level bij baas | baas bereikt | winst van aankomst | winst van alle runs | wipes | duur s |
|---|---|---|---|---|---|---|---|
| 4 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 3 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 4 | 66.0 | 1/24 | 0.0% (0) | 0.0% (0) | 1 | 19.6 |
| 7 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 3 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 4 | 91.0 | 7/24 | 100.0% (7) | 29.2% (7) | 0 | 11.1 |
| 10 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 3 | 106.2 | 4/24 | 100.0% (4) | 16.7% (4) | 0 | 11.7 |
| 10 | 4 | 109.4 | 14/24 | 100.0% (14) | 58.3% (14) | 0 | 8.5 |
| 25 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 25 | 2 | 174.9 | 16/24 | 100.0% (16) | 66.7% (16) | 0 | 11.0 |
| 25 | 3 | 171.9 | 21/24 | 100.0% (21) | 87.5% (21) | 0 | 5.9 |
| 25 | 4 | 172.8 | 20/24 | 100.0% (20) | 83.3% (20) | 0 | 4.4 |

## Page Warden bij vol HP (hypothese)

Elke run krijgt de EXP van de vloeren vóór de baas (niet de troep op de baasvloer) en vecht de Page Warden op vol HP, zonder slijtage. Dit is de vergelijking met #420, dat de baas op één vast level zette. Orion-partij = Dax, Seren, Vesper, Orion (de 4-stoel-partij van die sim). De klim hierboven gebruikt bij 4 stoelen Kael Voss in plaats van Orion.

| factor | stoelen | level | n | winst | duur s | Orion-winst |
|---|---|---|---|---|---|---|
| 4 | 1 | 57.6 | 24 | 37.5% (9) | 13.9 | — |
| 4 | 2 | 57.6 | 24 | 41.7% (10) | 20.9 | — |
| 4 | 3 | 57.6 | 24 | 33.3% (8) | 17.0 | — |
| 4 | 4 | 57.6 | 24 | 45.8% (11) | 14.8 | 33.3% (8) |
| 7 | 1 | 76.3 | 24 | 91.7% (22) | 12.7 | — |
| 7 | 2 | 76.3 | 24 | 87.5% (21) | 21.4 | — |
| 7 | 3 | 76.3 | 24 | 91.7% (22) | 14.5 | — |
| 7 | 4 | 76.3 | 24 | 87.5% (21) | 12.0 | 87.5% (21) |
| 10 | 1 | 91.0 | 24 | 100.0% (24) | 11.3 | — |
| 10 | 2 | 91.0 | 24 | 95.8% (23) | 19.4 | — |
| 10 | 3 | 91.0 | 24 | 95.8% (23) | 10.5 | — |
| 10 | 4 | 91.0 | 24 | 95.8% (23) | 8.6 | 95.8% (23) |
| 25 | 1 | 143.5 | 24 | 100.0% (24) | 7.1 | — |
| 25 | 2 | 143.5 | 24 | 100.0% (24) | 12.0 | — |
| 25 | 3 | 143.5 | 24 | 100.0% (24) | 5.9 | — |
| 25 | 4 | 143.5 | 24 | 100.0% (24) | 5.0 | 100.0% (24) |

## Classic-referentie

Solo Classic, seed 20261110, vloeren 1–98, factor 1, volledige monstergroepen inclusief bazen: EXP 561348 → level 194 (1177 gevechten). Het ontwerp wil dat Easy-vloer 10 ongeveer dit level haalt (eff 99). Dat getal is een referentie, geen doel dat deze PR afdwingt.

## Kandidaat-factoren

Huidige spelwaarde: **10** (= 100/10). Gesimuleerd: 4 7 10 25. Voor Easy is 100/N hetzelfde getal als 10; de andere waarden zijn extra kandidaten, geen nieuwe standaard.

## Aanbeveling (voorstel)

De eerste tabel (0/24 tot de baas, HP nog op 60–90%) was een sim-fout, geen balans. Drie dingen weken af van het spel: de helden wachtten elke slag op een volle meter van 1 s in plaats van de keten (hit1/hit2/finisher, vervolg 6 ticks na de animatie, AI daarna een zware slag); EXP viel pas na een gewonnen vloer, dus een level-up heelde niet midden in het gevecht; een slag op een vijand die nog aanliep werd weggegooid. Die drie zitten nu in deze sim. Geen speldata aangepast. `mode_exp_factor` blijft 10.

Na die correctie is elk verlies een wipe: HP uit is 0%, time-out 0, softlock 0. De 60–90% was de HP bij binnenkomst van de volgende vloer, niet de HP op het moment van verlies. De log hierboven (factor 4, 1 stoel, vloer 1, seed 20261110) laat de keten zien (×1.00, ×1.10, ×1.60) en daarna treffers tot 0 HP.

Wat er daarna overblijft is een mechaniek van het spel. Eén stoel wint vloer 1 en komt vloer 2 binnen rond 30–40% HP. De vijand doet ×2.2 schade, het rustpunt is pas vloer 5, en niemand gebruikt automatisch een drankje of feniksveer (de AI doet dat in het spel ook niet; M8a ontbreekt). Eén treffer maakt de wipe af. Een hogere factor heelt die al verloren HP niet.

Met 4 stoelen haalt factor 10 vloer 10 wel: level 91.9 bij binnenkomst, 14/24 halen de Page Warden (level 109 na de troep daar) en die 14 winnen allemaal, in 8.5 s. Drie stoelen: 4/24, level 106, ook allemaal winst. Eén en twee stoelen halen de baas bij factor 10 niet.

Vol-HP-hypothese (EXP van vloer 1–9, baas op vol HP), nu mét de keten:

| factor | level | winst 4 stoelen | duur | Orion-partij |
|---|---|---|---|---|
| 4 | 57.6 | 45.8% (11/24) | 14.8 s | 33.3% |
| 7 | 76.3 | 87.5% (21/24) | 12.0 s | 87.5% |
| 10 | 91.0 | 95.8% (23/24) | 8.6 s | 95.8% |
| 25 | 143.5 | 100% (24/24) | 5.0 s | 100% |

Factor 7 landt op level 76, vlak bij het level 74 van #420. Met de keten is de winst daar 87–92% (Orion 87.5%): bovenin of net boven de band 60–90%. Die band kwam uit een sim die óók elke slag vol laadde. Op het level waar factor 10 in de klim echt aankomt (109 bij de baas) winnen alle aankomsten in 8.5 s. De #420-mults (HP ×3.8, ATK ×2.6, de seat-tabel) zijn daar te licht.

Voorstel, niet doorgevoerd: houd de factor op 10. De klim met 4 stoelen komt aan, de baas valt te snel voor een band van 60–90% op dat level. Of de mults omhoog moeten, is een aparte balansvraag. Eén stoel blijft op vloer 2 sneuvelen door meegenomen schade en ×2.2, niet door de factor. Classic-referentie blijft level 194. Geen kandidaat haalt dat.
