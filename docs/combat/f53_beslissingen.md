# F5.3 · Beslissingen (18-11-2026)

Dennis heeft F5.3 in eigen woorden afgerond. Doelen gelden op het **in-game level**: Golem Lv 7, Wortelkoning Lv 13.
Bron van de voorgestelde punten: `/workspace/combat/f53/F53_afwijkingen_voorstel.md` (v2).

## Doorgevoerd

- **A8** — "Ja, Seren wordt 405/36". `ENEMIES.lotte_glitch.boss` is HP 405 / ATK 36 (was 270/32). Classic-verhaalgevecht, alleen dit baas-blok.
- **A4** — "Ja, Golem Action-ATK 27 met de testaanpassingen". Aparte Action-ATK voor de Golem, Classic ongewijzigd. PR #544, gemerged als `63012138`. Zie `docs/combat/f53_golem_action_atk.md`.
- **A14** — al beslist (18-11, "echte ingame"): de in-game levels zijn het doel. Geen data-wijziging. Na de RC: battlesim-scenario's naar Lv 7/13 (alleen `tools/`).

## Nee

- **A1** — "Nee, Wortelkoning blijft ATK 38". Op Lv 13 gemeten 63% (doel 80-95%); ATK 36 zou 87% geven, maar blijft 38.
- **A2** — nee. Geen patch A op `wortelkruiper` ATK of `sporenzwam` HP/ATK (Mist Pool-groep blijft zoals hij is).
- **A9** — nee. Glitch Moth ×3 blijft in `ENCOUNTER_GROUPS[7]` op de wereldkaart (weight niet naar 0).
- **A10** — nee. Berggrot `TIERS[7]` exp/goud blijft 1,0 (geen versnelling van het leveltempo).

## Geaccepteerd of bewust zo gelaten (bundel A3/A5/A6/A7/A11/A12/A13, "zoals voorgesteld")

- **A3** — Classic Golem Lv 7 geaccepteerd op 76% (4 punten onder 80-95%). Classic is bijmodus; een spelersfout kost een herkansing, geen softlock.
- **A5** — Action-zuilenhal piek bewust gelaten (x3.2, besluit 2-11). De huidige `--actionsim` leest de gebiedsregels niet; **de sim-fix (gebiedsregels + stagger) komt na de RC**, alleen in `tools/`.
- **A6** — bewust: "Action = uitdaging". Action is in Archief 1 duidelijk zwaarder dan Classic; dat past bij het besluit van 2-11.
- **A7** — Wurger en Genezer (Tweede Archief verd. 3-4) bewust gelaten voor de RC als verhaalmoment. HP-verhoging maakt het gevecht langer, de winst blijft 100%; echte moeilijkheid hoort bij WM2.
- **A11** — Inktwurm geaccepteerd als watch-item. Stats verlagen breekt `--fusietest` ("2× normaal Lv 5").
- **A12** — eerste aankoop zonder goud bewust gelaten voor de RC (startgoud 0, pakket 70 g). RC merkt zelf ONVERIFIED of de winkel vóór verdieping 1 bereikbaar is.
- **A13** — spreuk grade 2 duur in Act 2 geaccepteerd (economie van WM2).

