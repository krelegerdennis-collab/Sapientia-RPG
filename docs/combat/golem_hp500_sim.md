# Golem (kennis_beest baas) HP/ATK: 360/27 -> 520/23

Goedgekeurd door Dennis (1:1, 02-11-2026 22:53): Golem-baas HP 360 -> ~500, ATK 27 -> ~24,
binnen ~480-520 HP / 23-25 ATK bijstellen mag. Vervolg op PR #353 (gevechtsduur-balans).
DEF 15 en alle andere waarden ongewijzigd. In de 4 Golem-tests (golemtest, golemactiontest,
golemactionsimtest, golemarenatest) zijn alleen de stat-asserties aangepast.

Sim: `-- --actionsim --boss-rt --boss-fights=200 --boss-levels=7 --seed=20261020`, Lv 7.
(Let op: de koptekst van het sim-rapport zegt hard-coded "Stats unchanged (HP 360, ATK 27)"; die klopt niet meer.)

## Voor / na (Lv 7, 200 gevechten)

| stats | profiel | win | HP-verlies gem. | HP-verlies p90 | duur s |
|---|---|---|---|---|---|
| 360/27 (voor) | default | 65.5% | 74.5% | 100.0% | 23.8 |
| 360/27 (voor) | good | 98.5% | 58.5% | 82.9% | 23.5 |
| **520/23 (na)** | default | 91.5% | 58.7% | 86.0% | 28.1 |
| **520/23 (na)** | good | 99.5% | 48.3% | 69.8% | 26.8 |

Per fase (520/23, default): F1 8.8 s / 47.0%, F2 11.8 s / 80.4%, F3 7.5 s / 49.2% (198/200 bereikt).

## Verkende varianten (default-profiel)

| HP/ATK | win | p90 HP-verlies | duur s |
|---|---|---|---|
| 500/24 | 88.0% | 100.0% | 27.9 |
| 520/24 | 88.0% | 100.0% | 28.8 |
| 480/23 | 95.5% | 85.1% | 26.6 |
| 500/23 | 96.0% | 85.1% | 27.4 |
| 510/23 | 94.0% | 85.6% | 27.6 |
| 520/23 | 91.5% | 86.0% | 28.1 |

Geen combinatie binnen de bandbreedte haalt tegelijk win 60-90% en p90 < 100%: ATK 24 houdt p90 op 100%,
ATK 23 duwt de winst net boven 90%. Gekozen: 520/23 (langste gevecht, p90 onder 100%, winst 1.5 pp boven doel).

## Akkoord

- 02-11-2026 22:53 (1:1 Dennis): richting HP ~500 / ATK ~24, 4 Golem-tests mogen alleen op stat-waarden.
- 02-11-2026 23:42 (1:1 Dennis): 520/23 behouden (winst 91,5% vs doel 60-90% geaccepteerd);
  dungeon100schaaltest mag alleen de Golem-HP 360 -> 520 (dungeon100_schaal_tests.gd:606-607).
