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
- Rust op Easy vloer 5 heelt levenden. Geen drankjes. M8a (down/revive in Action) zit niet in de code: revives niet gemeten, een held op 0 HP blijft liggen en de run stopt pas als iedereen ligt of de vloer niet valt.
- EXP per stoel, vol, `round_half_even(basis × factor)` per vijand. Klassieke DLS stript spreuken; deze sim houdt de klasse-spreuken (basis-kit), net als de Page Warden-sim.
- Duur is gevechtstijd (60 Hz), zonder looptijd. Tooltijd 26.7 s.

Herhalen:

```
xvfb-run -a godot --rendering-driver opengl3 --path . -- --d100modesim --mode=easy --factors=4,7,10,25 --seats=1,2,3,4 --runs=24 --seed=20261110 --floors=10 --out=res://docs/combat/m9b_easy_sim.md
```

## Per vloer

Level bij binnenkomst, vóór het gevecht. Winst = de vloer leeg (op vloer 10: troep én Page Warden). Een wipe telt ook als verlies. Niet bereikt = eerdere wipe of verlies.

HP in = partij-HP bij binnenkomst, vóór het rustpunt. Vijanden = gemiddelde op die vloer (zelfde kaarten voor elke factor).

| factor | stoelen | vloer | eff | level in | HP in | vijanden | bereikt | winst | verlies | wipes | duur s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 4.2% (1) | 95.8% (23) | 23 | 4.8 |
| 4 | 1 | 2 | 12 | 1.0 | 100% | 5.6 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 1.9 |
| 4 | 1 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 4 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 4 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 20.8% (5) | 79.2% (19) | 19 | 10.6 |
| 4 | 2 | 2 | 12 | 2.8 | 75% | 5.6 | 5/24 | 0.0% (0) | 100.0% (5) | 5 | 4.0 |
| 4 | 2 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 4 | 2 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 4 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 83.3% (20) | 16.7% (4) | 4 | 9.9 |
| 4 | 3 | 2 | 12 | 3.1 | 72% | 5.6 | 20/24 | 15.0% (3) | 85.0% (17) | 17 | 5.4 |
| 4 | 3 | 3 | 23 | 3.3 | 74% | 5.2 | 3/24 | 33.3% (1) | 66.7% (2) | 2 | 4.1 |
| 4 | 3 | 4 | 34 | 4.0 | 69% | 5.4 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 4.0 |
| 4 | 3 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 3 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 3 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 3 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 3 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 3 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 4 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.2 |
| 4 | 4 | 2 | 12 | 3.2 | 85% | 5.6 | 24/24 | 29.2% (7) | 70.8% (17) | 17 | 6.9 |
| 4 | 4 | 3 | 23 | 4.3 | 67% | 5.2 | 7/24 | 28.6% (2) | 71.4% (5) | 5 | 3.4 |
| 4 | 4 | 4 | 34 | 4.5 | 74% | 5.4 | 2/24 | 0.0% (0) | 100.0% (2) | 2 | 5.9 |
| 4 | 4 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 4 | 4 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 4 | 4 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 4 | 4 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 4 | 4 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 4 | 4 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 4.2% (1) | 95.8% (23) | 23 | 5.5 |
| 7 | 1 | 2 | 12 | 1.0 | 100% | 5.6 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 2.3 |
| 7 | 1 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 7 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 7 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 7 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 25.0% (6) | 75.0% (18) | 18 | 11.4 |
| 7 | 2 | 2 | 12 | 3.5 | 60% | 5.6 | 6/24 | 0.0% (0) | 100.0% (6) | 6 | 4.6 |
| 7 | 2 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 7 | 2 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 7 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 7 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 91.7% (22) | 8.3% (2) | 2 | 10.6 |
| 7 | 3 | 2 | 12 | 4.0 | 68% | 5.6 | 22/24 | 27.3% (6) | 72.7% (16) | 16 | 5.5 |
| 7 | 3 | 3 | 23 | 5.3 | 69% | 5.2 | 6/24 | 33.3% (2) | 66.7% (4) | 4 | 3.0 |
| 7 | 3 | 4 | 34 | 5.5 | 68% | 5.4 | 2/24 | 0.0% (0) | 100.0% (2) | 2 | 3.5 |
| 7 | 3 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 7 | 3 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 3 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 3 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 3 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 3 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 7 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 8.2 |
| 7 | 4 | 2 | 12 | 4.0 | 89% | 5.6 | 24/24 | 33.3% (8) | 66.7% (16) | 16 | 8.6 |
| 7 | 4 | 3 | 23 | 5.6 | 68% | 5.2 | 8/24 | 37.5% (3) | 62.5% (5) | 5 | 3.2 |
| 7 | 4 | 4 | 34 | 5.7 | 76% | 5.4 | 3/24 | 33.3% (1) | 66.7% (2) | 2 | 4.4 |
| 7 | 4 | 5 | 45 | 6.0 | 43% | 6.2 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 4.3 |
| 7 | 4 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 7 | 4 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 7 | 4 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 7 | 4 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 7 | 4 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 4.2% (1) | 95.8% (23) | 23 | 4.8 |
| 10 | 1 | 2 | 12 | 1.0 | 100% | 5.6 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 2.4 |
| 10 | 1 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 10 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 10 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 10 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 10 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 10 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 16.7% (4) | 83.3% (20) | 20 | 9.4 |
| 10 | 2 | 2 | 12 | 4.0 | 81% | 5.6 | 4/24 | 0.0% (0) | 100.0% (4) | 4 | 5.1 |
| 10 | 2 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 10 | 2 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 10 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 10 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 10 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 10 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 79.2% (19) | 20.8% (5) | 5 | 10.5 |
| 10 | 3 | 2 | 12 | 4.8 | 72% | 5.6 | 19/24 | 26.3% (5) | 73.7% (14) | 14 | 7.6 |
| 10 | 3 | 3 | 23 | 6.2 | 61% | 5.2 | 5/24 | 40.0% (2) | 60.0% (3) | 3 | 2.7 |
| 10 | 3 | 4 | 34 | 6.5 | 51% | 5.4 | 2/24 | 50.0% (1) | 50.0% (1) | 1 | 1.4 |
| 10 | 3 | 5 | 45 | 8.0 | 46% | 6.2 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 4.1 |
| 10 | 3 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 10 | 3 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 10 | 3 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 3 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 3 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 10 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 7.9 |
| 10 | 4 | 2 | 12 | 4.8 | 89% | 5.6 | 24/24 | 50.0% (12) | 50.0% (12) | 12 | 10.0 |
| 10 | 4 | 3 | 23 | 7.8 | 64% | 5.2 | 12/24 | 41.7% (5) | 58.3% (7) | 7 | 5.4 |
| 10 | 4 | 4 | 34 | 8.8 | 57% | 5.4 | 5/24 | 20.0% (1) | 80.0% (4) | 4 | 4.7 |
| 10 | 4 | 5 | 45 | 8.0 | 66% | 6.2 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 5.4 |
| 10 | 4 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 10 | 4 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 10 | 4 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 10 | 4 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 10 | 4 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 25 | 1 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 4.2% (1) | 95.8% (23) | 23 | 5.1 |
| 25 | 1 | 2 | 12 | 1.0 | 100% | 5.6 | 1/24 | 0.0% (0) | 100.0% (1) | 1 | 2.2 |
| 25 | 1 | 3 | 23 | — | — | 5.2 | 0/24 | — | — | 0 | — |
| 25 | 1 | 4 | 34 | — | — | 5.4 | 0/24 | — | — | 0 | — |
| 25 | 1 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 25 | 1 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 25 | 1 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 25 | 1 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 25 | 1 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 25 | 1 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 25 | 2 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 20.8% (5) | 79.2% (19) | 19 | 10.4 |
| 25 | 2 | 2 | 12 | 6.4 | 75% | 5.6 | 5/24 | 40.0% (2) | 60.0% (3) | 3 | 6.2 |
| 25 | 2 | 3 | 23 | 9.5 | 71% | 5.2 | 2/24 | 100.0% (2) | 0.0% (0) | 0 | 0.0 |
| 25 | 2 | 4 | 34 | 9.5 | 71% | 5.4 | 2/24 | 0.0% (0) | 100.0% (2) | 2 | 5.2 |
| 25 | 2 | 5 | 45 | — | — | 6.2 | 0/24 | — | — | 0 | — |
| 25 | 2 | 6 | 55 | — | — | 3.8 | 0/24 | — | — | 0 | — |
| 25 | 2 | 7 | 66 | — | — | 3.5 | 0/24 | — | — | 0 | — |
| 25 | 2 | 8 | 77 | — | — | 4.6 | 0/24 | — | — | 0 | — |
| 25 | 2 | 9 | 88 | — | — | 3.9 | 0/24 | — | — | 0 | — |
| 25 | 2 | 10 | 99 | — | — | 3.6 | 0/24 | — | — | 0 | — |
| 25 | 3 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 91.7% (22) | 8.3% (2) | 2 | 10.2 |
| 25 | 3 | 2 | 12 | 7.5 | 76% | 5.6 | 22/24 | 54.5% (12) | 45.5% (10) | 10 | 8.7 |
| 25 | 3 | 3 | 23 | 13.4 | 74% | 5.2 | 12/24 | 66.7% (8) | 33.3% (4) | 4 | 6.2 |
| 25 | 3 | 4 | 34 | 17.6 | 76% | 5.4 | 8/24 | 62.5% (5) | 37.5% (3) | 3 | 7.0 |
| 25 | 3 | 5 | 45 | 26.0 | 73% | 6.2 | 5/24 | 80.0% (4) | 20.0% (1) | 1 | 12.1 |
| 25 | 3 | 6 | 55 | 49.8 | 64% | 3.8 | 4/24 | 75.0% (3) | 25.0% (1) | 1 | 4.2 |
| 25 | 3 | 7 | 66 | 63.0 | 59% | 3.5 | 3/24 | 100.0% (3) | 0.0% (0) | 0 | 3.3 |
| 25 | 3 | 8 | 77 | 66.7 | 59% | 4.6 | 3/24 | 66.7% (2) | 33.3% (1) | 1 | 11.3 |
| 25 | 3 | 9 | 88 | 81.5 | 67% | 3.9 | 2/24 | 100.0% (2) | 0.0% (0) | 0 | 18.2 |
| 25 | 3 | 10 | 99 | 124.0 | 59% | 3.6 | 2/24 | 100.0% (2) | 0.0% (0) | 0 | 24.0 |
| 25 | 4 | 1 | 1 | 1.0 | 100% | 7.7 | 24/24 | 100.0% (24) | 0.0% (0) | 0 | 7.7 |
| 25 | 4 | 2 | 12 | 7.5 | 92% | 5.6 | 24/24 | 83.3% (20) | 16.7% (4) | 4 | 8.9 |
| 25 | 4 | 3 | 23 | 13.9 | 78% | 5.2 | 20/24 | 75.0% (15) | 25.0% (5) | 5 | 9.4 |
| 25 | 4 | 4 | 34 | 21.5 | 69% | 5.4 | 15/24 | 46.7% (7) | 53.3% (8) | 8 | 8.2 |
| 25 | 4 | 5 | 45 | 29.9 | 75% | 6.2 | 7/24 | 71.4% (5) | 28.6% (2) | 2 | 10.1 |
| 25 | 4 | 6 | 55 | 52.2 | 79% | 3.8 | 5/24 | 80.0% (4) | 20.0% (1) | 1 | 7.7 |
| 25 | 4 | 7 | 66 | 78.2 | 75% | 3.5 | 4/24 | 100.0% (4) | 0.0% (0) | 0 | 8.1 |
| 25 | 4 | 8 | 77 | 99.8 | 83% | 4.6 | 4/24 | 100.0% (4) | 0.0% (0) | 0 | 9.8 |
| 25 | 4 | 9 | 88 | 132.0 | 80% | 3.9 | 4/24 | 100.0% (4) | 0.0% (0) | 0 | 6.0 |
| 25 | 4 | 10 | 99 | 158.2 | 78% | 3.6 | 4/24 | 100.0% (4) | 0.0% (0) | 0 | 11.2 |

## Page Warden (klim)

Alleen wie de troep op de baasvloer overleeft, vecht de baas. Level is dán (na de EXP van die troep). Winst-alle-runs telt een run die de baas niet haalt als verlies.

| factor | stoelen | level bij baas | baas bereikt | winst van aankomst | winst van alle runs | wipes | duur s |
|---|---|---|---|---|---|---|---|
| 4 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 3 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 4 | 4 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 3 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 7 | 4 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 3 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 10 | 4 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 25 | 1 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 25 | 2 | — | 0/24 | — | 0.0% (0) | 0 | — |
| 25 | 3 | 161.0 | 2/24 | 100.0% (2) | 8.3% (2) | 0 | 14.4 |
| 25 | 4 | 186.5 | 4/24 | 100.0% (4) | 16.7% (4) | 0 | 3.8 |

## Page Warden bij vol HP (hypothese)

Elke run krijgt de EXP van de vloeren vóór de baas (niet de troep op de baasvloer) en vecht de Page Warden op vol HP, zonder slijtage. Dit is de vergelijking met #420, dat de baas op één vast level zette. Orion-partij = Dax, Seren, Vesper, Orion (de 4-stoel-partij van die sim). De klim hierboven gebruikt bij 4 stoelen Kael Voss in plaats van Orion.

| factor | stoelen | level | n | winst | duur s | Orion-winst |
|---|---|---|---|---|---|---|
| 4 | 1 | 57.6 | 24 | 8.3% (2) | 17.3 | — |
| 4 | 2 | 57.6 | 24 | 29.2% (7) | 29.7 | — |
| 4 | 3 | 57.6 | 24 | 25.0% (6) | 27.7 | — |
| 4 | 4 | 57.6 | 24 | 25.0% (6) | 16.3 | 12.5% (3) |
| 7 | 1 | 76.3 | 24 | 66.7% (16) | 21.0 | — |
| 7 | 2 | 76.3 | 24 | 83.3% (20) | 37.0 | — |
| 7 | 3 | 76.3 | 24 | 75.0% (18) | 20.8 | — |
| 7 | 4 | 76.3 | 24 | 83.3% (20) | 14.9 | 62.5% (15) |
| 10 | 1 | 91.0 | 24 | 95.8% (23) | 19.5 | — |
| 10 | 2 | 91.0 | 24 | 87.5% (21) | 32.9 | — |
| 10 | 3 | 91.0 | 24 | 95.8% (23) | 12.4 | — |
| 10 | 4 | 91.0 | 24 | 100.0% (24) | 9.9 | 95.8% (23) |
| 25 | 1 | 143.5 | 24 | 100.0% (24) | 13.0 | — |
| 25 | 2 | 143.5 | 24 | 100.0% (24) | 20.3 | — |
| 25 | 3 | 143.5 | 24 | 100.0% (24) | 6.1 | — |
| 25 | 4 | 143.5 | 24 | 100.0% (24) | 4.5 | 100.0% (24) |

## Classic-referentie

Solo Classic, seed 20261110, vloeren 1–98, factor 1, volledige monstergroepen inclusief bazen: EXP 561348 → level 194 (1177 gevechten). Het ontwerp wil dat Easy-vloer 10 ongeveer dit level haalt (eff 99). Dat getal is een referentie, geen doel dat deze PR afdwingt.

## Kandidaat-factoren

Huidige spelwaarde: **10** (= 100/10). Gesimuleerd: 4 7 10 25. Voor Easy is 100/N hetzelfde getal als 10; de andere waarden zijn extra kandidaten, geen nieuwe standaard.

## Aanbeveling (voorstel)

Laat `OnlineDlsModes.mode_exp_factor("easy")` op **10** (100/N). Deze sim hardcodeert geen nieuwe waarde. De getallen hieronder zijn een voorstel voor Dennis.

De factor brengt een Easy-run in dit model niet naar de Page Warden. Bij 4, 7 en 10 is de baas 0/24 bereikt, op elk stoel-aantal. Bij 25 halen 3 stoelen hem 2/24 (level bij binnenkomst van vloer 10: 124; level bij de baas, na de troep daar: 161) en 4 stoelen 4/24 (level 158, baas-level 187). Die aankomsten winnen allemaal, in 14 s en 4 s. Eén en twee stoelen halen vloer 10 bij geen van de vier waarden.

Vloer 1 is level 1, vóór enige EXP. Eén stoel wint die vloer 1/24 bij elke factor. Twee stoelen winnen hem rond een vijfde van de seeds en vallen daarna op vloer 2 (eff 12). Drie en vier stoelen maken vloer 1 meestal af en sneuvelen op vloer 2–5 (eff 12–45), terwijl de partij nog rond level 4–9 zit. De HP bij binnenkomst van die vloeren ligt vaak nog op 60–90%. Het rustpunt op vloer 5 komt dus te laat om dit te verklaren: de eff-sprong is steil, de actie-vijand doet ×2.2 schade, er zijn geen drankjes, en M8a (down/revive in Action) zit niet in de code. Revives zijn daarom niet gemeten; een held op 0 HP blijft liggen. Een hogere factor telt pas na een gewonnen vloer.

Vol-HP-hypothese: elke run krijgt de EXP van vloer 1–9 en vecht de Page Warden op vol HP. Dat is het level op vloer 10 als de klim zou lukken, en de vergelijking met de tune uit #420 (Easy-level 74, winst 60–90%).

| factor | level | winst 4 stoelen | duur 4 stoelen | Orion-partij (#420) |
|---|---|---|---|---|
| 4 | 57.6 | 25.0% (6/24) | 16.3 s | 12.5% (3/24) |
| 7 | 76.3 | 83.3% (20/24) | 14.9 s | 62.5% (15/24) |
| 10 | 91.0 | 100% (24/24) | 9.9 s | 95.8% (23/24) |
| 25 | 143.5 | 100% (24/24) | 4.5 s | 100% (24/24) |

Factor 7 landt op level 76, vlak bij het level 74 waar #420 `ACTION_HP_MULT` 3.8, `ACTION_ATK_MULT` 2.6 en de seat-tabel op zette. De winst zit dan in de band 60–90%, ook voor de Orion-partij (Dax, Seren, Vesper, Orion). Bij de huidige spelwaarde 10 is dat level 91, en 4 stoelen winnen de baas in 10 s (100%). Die voorstellen kloppen in dit gevechtsmodel dus rond level 76. Op het level dat factor 10 geeft zodra vloer 1–9 uitgespeeld is, valt de baas te snel. Die 91 wijkt af van de 74 uit `tools/battlesim/page_warden_rt_sim.gd`: die sim deed `generate(seed, modusvloer 1–9)` met volle groepen en daarna ×10. Deze sim volgt `OnlineDlsFloor.build`: `generate(seed, eff)`, cap 8, één vijand per slot.

Classic, dezelfde basis-seed, vloeren 1–98, factor 1, volle groepen: level 194. Geen kandidaat haalt dat op Easy-vloer 10. "Ongeveer het solo-level op eff 99" en "de baas tunen op level 74" wijzen een andere kant op. Deze PR laat beide getallen staan als referentie.

Voorstel, niet doorgevoerd: houd de factor op 10 tot een playtest. 25 is de enige kandidaat waarbij de baas soms bereikt wordt, en dan is dat gevecht afgelopen in een paar seconden. De #420-mults kunnen blijven zolang het doel-level rond 74–76 ligt. Het punt waarop de run stukloopt is de klim (eff-curve, geen drankjes, geen M8a).

Verschillen op vloer 1 tussen factoren komen uit de combat-seed: de factor zit in `mix_seed`, en iedereen is daar level 1. Duur 0.0 is een lege kamer. Gedraaid met Godot 4.3-stable (tooltijd 26.7 s).
