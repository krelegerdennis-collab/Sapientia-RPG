# M9b — schade en herstel (voorstel)

Alleen in de sim. `SomData.ENEMY_DAMAGE_MULT` blijft 2.2. `mode_exp_factor` blijft 10. Geen speldata.

Factor 10, 24 runs, seed `20261110`, vloeren 1–10, stoelen 1–4. `--no-hypo --no-classic`.

`--easy_enemy_dmg` vervangt 2.2 op troep en Page Warden-adds. De klap van de baas zelf blijft zonder die factor. `--floor_heal` telt procent van max HP en max MP op bij levenden, ná de meting van HP-in en vóór het gevecht, vanaf vloer 2. Neergegane helden blijven liggen. Rustvloer 5 vult daarna alsnog bij. 100 vult een levende dus vol vóór het gevecht. De kolom HP-in in de sim-uitvoer is van vóór dat herstel.

Winst-alle telt een gemiste baas als verlies. Verste wipe is de hoogste vloer met een wipe. Duur is de baas, alleen over wie hem haalt.

## (a) schade, herstel 0

| dmg | stoelen | PW bereikt | winst aankomst | winst alle | level | duur s | verste wipe |
|---|---|---|---|---|---|---|---|
| 2.2 | 1 | 0/24 | — | 0.0% (0) | — | — | 4 |
| 2.2 | 2 | 0/24 | — | 0.0% (0) | — | — | 7 |
| 2.2 | 3 | 4/24 | 100.0% (4) | 16.7% (4) | 106.2 | 11.7 | 10 |
| 2.2 | 4 | 14/24 | 100.0% (14) | 58.3% (14) | 109.4 | 8.5 | 8 |
| 1.8 | 1 | 0/24 | — | 0.0% (0) | — | — | 4 |
| 1.8 | 2 | 2/24 | 50.0% (1) | 4.2% (1) | 111.0 | 8.9 | 10 |
| 1.8 | 3 | 9/24 | 100.0% (9) | 37.5% (9) | 112.6 | 10.4 | 6 |
| 1.8 | 4 | 17/24 | 100.0% (17) | 70.8% (17) | 109.8 | 7.0 | 8 |
| 1.5 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 1.5 | 2 | 3/24 | 66.7% (2) | 8.3% (2) | 117.7 | 10.8 | 10 |
| 1.5 | 3 | 11/24 | 100.0% (11) | 45.8% (11) | 108.5 | 11.7 | 6 |
| 1.5 | 4 | 20/24 | 95.0% (19) | 79.2% (19) | 109.5 | 6.9 | 10 |
| 1.2 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 1.2 | 2 | 8/24 | 100.0% (8) | 33.3% (8) | 102.1 | 17.1 | 9 |
| 1.2 | 3 | 19/24 | 94.7% (18) | 75.0% (18) | 109.7 | 9.1 | 10 |
| 1.2 | 4 | 21/24 | 100.0% (21) | 87.5% (21) | 105.0 | 6.4 | 6 |

2.2 komt overeen met de klim van head `3287c39b`. Lagere schade haalt 1 stoel niet bij de baas.

## (b) herstel, schade 2.2

| dmg | heal | stoelen | PW bereikt | winst aankomst | winst alle | level | duur s | verste wipe |
|---|---|---|---|---|---|---|---|---|
| 2.2 | 25 | 1 | 0/24 | — | 0.0% (0) | — | — | 4 |
| 2.2 | 25 | 2 | 0/24 | — | 0.0% (0) | — | — | 6 |
| 2.2 | 25 | 3 | 6/24 | 83.3% (5) | 20.8% (5) | 111.8 | 10.4 | 10 |
| 2.2 | 25 | 4 | 15/24 | 100.0% (15) | 62.5% (15) | 108.9 | 8.2 | 7 |
| 2.2 | 50 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 2.2 | 50 | 2 | 0/24 | — | 0.0% (0) | — | — | 6 |
| 2.2 | 50 | 3 | 7/24 | 85.7% (6) | 25.0% (6) | 112.4 | 9.7 | 10 |
| 2.2 | 50 | 4 | 15/24 | 93.3% (14) | 58.3% (14) | 108.9 | 7.4 | 10 |
| 2.2 | 100 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 2.2 | 100 | 2 | 0/24 | — | 0.0% (0) | — | — | 6 |
| 2.2 | 100 | 3 | 8/24 | 87.5% (7) | 29.2% (7) | 111.4 | 9.5 | 10 |
| 2.2 | 100 | 4 | 15/24 | 100.0% (15) | 62.5% (15) | 108.9 | 7.6 | 8 |

Herstel 0 staat in tabel (a). Vol herstel tussen vloeren haalt 1 en 2 stoelen nog steeds niet bij de baas.

## Combinaties

Gekozen omdat 1 stoel bij (a) en (b) op 0/24 blijft, en 1.2 de enige schade is waarbij 3 en 4 stoelen samen in de band 60–90% komen.

| dmg | heal | stoelen | PW bereikt | winst aankomst | winst alle | level | duur s | verste wipe |
|---|---|---|---|---|---|---|---|---|
| 1.2 | 50 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 1.2 | 50 | 2 | 10/24 | 100.0% (10) | 41.7% (10) | 109.8 | 15.7 | 8 |
| 1.2 | 50 | 3 | 19/24 | 100.0% (19) | 79.2% (19) | 109.7 | 8.6 | 6 |
| 1.2 | 50 | 4 | 21/24 | 100.0% (21) | 87.5% (21) | 105.0 | 6.5 | 6 |
| 1.2 | 100 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 1.2 | 100 | 2 | 11/24 | 100.0% (11) | 45.8% (11) | 112.2 | 16.0 | 8 |
| 1.2 | 100 | 3 | 19/24 | 100.0% (19) | 79.2% (19) | 109.7 | 8.6 | 6 |
| 1.2 | 100 | 4 | 21/24 | 100.0% (21) | 87.5% (21) | 105.0 | 6.5 | 6 |
| 1.5 | 100 | 1 | 0/24 | — | 0.0% (0) | — | — | 5 |
| 1.5 | 100 | 2 | 7/24 | 85.7% (6) | 25.0% (6) | 109.1 | 16.0 | 10 |
| 1.5 | 100 | 3 | 15/24 | 100.0% (15) | 62.5% (15) | 110.3 | 10.0 | 6 |
| 1.5 | 100 | 4 | 20/24 | 100.0% (20) | 83.3% (20) | 109.5 | 6.3 | 6 |

Bij dmg 1.2 en herstel 100 start vloer 2 na een vol herstel. Toch wint 1 stoel die vloer maar 10/24, en vloer 5 (HP-in al 100%) 0/2. De wipe valt in het gevecht, niet door meegenomen schade.

## Voorstel

Niet doorvoeren. Geen kandidaat en geen van deze combinaties legt de Page Warden-winst over alle runs in 60–90% bij elk stoelaantal. 1 stoel blijft 0/24, ook op de lichtste stand (schade 1.2, herstel 100). 2 stoelen komt tot 45.8%.

Schade verplaatst 3 en 4 stoelen wel die band in. Op 1.2 zonder extra herstel: 3 stoelen 75.0%, 4 stoelen 87.5%, 2 stoelen 33.3%, 1 stoel 0. Herstel tot 100% tilt 2 stoelen van 33.3% naar 45.8% en laat 1, 3 en 4 stoelen staan. Tussen vloeren bijvullen heelt een gevecht niet dat een volle solo al verliest.

Wie 60–90% ook voor 1 stoel wil, heeft een andere knop nodig dan deze twee: minder vijanden op de vroege vloer, of herstel tijdens het gevecht. Drankjes blijven handmatig. Deze sim zet ze niet aan.
