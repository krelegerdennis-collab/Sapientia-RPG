# QA-ronde WM1 op de RC (klus 13)

Doel: de WM1-release (0.21 RC, interne RC uiterlijk 20 nov 2026) actief proberen te breken en elke echte bug klein en getest
repareren. Basis: `finish/wm1` op `6253592` (#486). Branch: `qa/wm1-rc-sweep`.

Nieuwe suite: `--wm1qasweeptest` (`scripts/tests/wm1_qa_sweep_tests.gd`), geregistreerd in `scripts/game_state.gd`.
Nog **niet** in `.github/workflows/tests.yml`: die regel voegt Forge later toe (met akkoord van Dennis).

## Werkwijze

1. Baseline: de gevraagde suites los gedraaid op een schone `finish/wm1` (Godot 4.3-stable, xvfb, `run_suite.sh`).
   Plus `--wm1playthroughtest` (golden path, niet in CI) als basis voor het WM1-pad.
2. Code gelezen langs het pad: nieuw spel → proloog → Wilgendal → wereldkaart → Eerste Archief → Golem → absorptie/CS-02.
   Gericht gezocht op de zeven categorieën uit de opdracht.
3. Per vermoeden eerst een test in de nieuwe suite. Faalde die op de schone code, dan de kleinste fix. Bleek het goed, dan
   bleef de test staan als regressiebewaking.

Baseline (schone `finish/wm1`): alle suites groen, behalve `--rcchecktest` (1 FAIL, al aanwezig vóór deze klus; zie open punten).
`--wm1playthroughtest` 591 PASS, 0 FAIL.

## Wat de suite test

| Deel | Wat | Soort |
|---|---|---|
| A | Winkels: geen goud-lus (verkoop > koop), kopen bij volle stapel, verkopen zonder item, negatieve bedragen, MAX_GOLD, sleutel-voorwerpen niet verkoopbaar | bug A2 + regressie |
| B | Zingend Meel: één per bezoek, niet opnieuw na opslaan + laden, wel weer bij een nieuw bezoek | regressie |
| C | Kapotte save: negatief goud, HP < 0 of > max, stapel > max, lege party, leider niet in de party, hele party KO, uitrusting terug in de tas | bug C4 + regressie |
| D | Opslaan → laden: alle velden gelijk (party, tas, goud, vlaggen, kaart, tegel, richting). Opslaan tijdens gevecht of mapwissel geweigerd | regressie |
| E | Puzzelkist (Eerste Archief): twee keer openen = één buit; na opslaan + laden blijft de kist leeg | regressie |
| F | Gevecht-einde: KO-held na winst op 1 HP; verlies zonder checkpoint: goud 0..voor, iedereen vol, flow weer vrij | regressie |
| G | Touch: vinger op de joystick + app naar de achtergrond (PAUSED) → na hervatten geen richting meer ingedrukt | bug G1 + regressie |
| J | Pauze tijdens tekstvak, gevecht, mapwissel, cutscene: geen save. In het veld: precies één save, hervatten verandert niets | regressie |
| I | Na de baas: openstaand absorptie-moment (Golemkern, CS-02) overleeft opslaan + laden en speelt daarna af | bug I1/I4 + regressie |
| H | Warps: alle 47 WM1-kaarten, alle 86 uitgangen echt genomen: doel en spawnpunt bestaan, spawn niet in een muur, speler kan bewegen, spawn niet op een uitgang (pingpong). Uitgang-warpers (8) landen op een bestaand punt op de wereldkaart | regressie |

Resultaat met de fixes: **66 PASS, 0 FAIL**.

## Gevonden en gefixt

| # | Bug | Fix (bestand) | Test | Ernst |
|---|---|---|---|---|
| 1 | **Absorptie-moment na een baas kwijt na laden.** `pending_kern_absorb` stond niet in de save. Een pauze-save in de 0,45 s vóór het moment (of tijdens het effect van een andere kern) bewaarde de kern wel, het moment niet. Werd de app daarna door Android gesloten, dan speelde CS-02 / de Sapientia-zin (Golem) of de 'absorbs … / New skill'-tekst nooit meer. | Sleutel `pending_kern_absorb` in `state_data`; `apply_state` zet hem alleen terug als je die kern echt hebt. Oude saves: geen sleutel = geen moment. (`scripts/game_state.gd`) | `I1`, `I2`, `I3`, `I4` | middel |
| 2 | **Touch-invoer kan blijven hangen na pauze.** De touch-laag liet knoppen alleen los bij FOCUS_OUT. Kreeg ze alleen PAUSED (scherm uit, split-screen; volgorde verschilt per toestel), dan bleef een vinger op de joystick 'ingedrukt' en liep de held na hervatten door. | Ook `NOTIFICATION_APPLICATION_PAUSED` → `release_all()` (`scripts/touch_controls.gd`) | `G1` (+ regressie `G2`) | middel, trigger ONVERIFIED op toestel |
| 3 | **Kopen met een volle stapel kost goud zonder item.** `add_item` begrenst op 9999; het goud was al betaald. | Weigeren met "You can't carry any more." vóór het betalen (`scripts/data/shop_data.gd`) | `A2` | laag (9999 stuks nodig) |
| 4 | **Tas boven MAX_ITEM_STACK na laden.** Uitrusting die bij laden niet meer past gaat terug in de tas, zonder begrenzing (10006 gemeten). | `mini(MAX_ITEM_STACK, …)` (`scripts/game_state.gd`) | `C4` | laag |

Elke test hierboven faalde op de schone code en is groen met de fix. Geen balansgetallen, content of art aangeraakt.

## Gecontroleerd en in orde (regressiebewaking in de suite)

- Geen goud-lus in de winkels; sleutel-voorwerpen niet verkoopbaar; goud nooit < 0 of > MAX_GOLD.
- Kisten (vlag vóór het item) en Zingend Meel (per bezoek, vlag in de save) zijn niet te dupliceren via opslaan/laden.
- Laden begrenst goud, HP/MP en stapels; lege party krijgt Dax terug; een ongeldige leider valt terug op Dax.
- Pauze-save weigert tijdens tekstvak, gevecht, mapwissel en cutscene; hervatten verandert de voortgang niet.
- Alle uitgangen van alle WM1-kaarten: doel, spawnpunt, geen muur, niet ingeklemd, geen pingpong. Eén schijnbare klem
  (bouwplaats `van_tunnel`) is alleen bereikbaar met `noor_lid` en dan vrij (zoals `archieftest` deel H2 ook aanneemt).
- 10 uitgangen zonder directe terugweg zijn bedoeld: deuren via een event of story-object (herberg, huizen, struik
  `woud_beek`) of eenrichting (ketting → tegen). Staan als `INFO` in de log.

## Open (niet gerepareerd)

| # | Punt | Waarom niet gefixt | Wie |
|---|---|---|---|
| O1 | `--rcchecktest` faalt al op `finish/wm1`: `scripts/data/som_gamefeel_data.gd:DEATH_GLITCH_ENABLED` staat aan maar niet op de lijst met features die meegaan (sinds #482). | Bestaande test en feature-vlag; besluit over scope. | Dennis (scope) / Forge |
| O2 | Dubbele pauze-save op Android: FOCUS_OUT en PAUSED schrijven allebei een autosave (2x dezelfde stand; `.bak` = dezelfde stand). Geen verlies, wel dubbel schrijven. | Een vergrendeling per pauze breekt bestaande tests (`savehardeningtest`, `menutest`) die PAUSED meerdere keren zonder RESUMED sturen. | Forge (besluit + testaanpassing) |
| O3 | Golemhal-uitgang geeft een gratis Blank Book (verkoop 30 g) als je er geen hebt. Verkopen en terugkomen = kleine goud-lus zolang de Inktwurm niet in de Codex staat (ONVERIFIED in echt spel: alleen uit de code gelezen). | Ontwerp/balans; lange looproute, lage opbrengst. | Dennis (balans) |
| O4 | Uitrusting afdoen (`Equipment._give`) begrenst de stapel niet. Alleen bij 9999 stuks van hetzelfde stuk. | Praktisch onbereikbaar; buiten de max. aantal fixes gehouden. | - |
| O5 | Een (kapotte) save met de hele party op 0 HP laadt met 0 HP; een save zonder Dax maar met andere helden krijgt Dax niet terug. | Komt in normaal spel niet voor (opslaan kan niet met een dode party); alleen kapotte bestanden. | - |

## Niet headless te testen

- **Echte telefoon (S25):** de echte volgorde van FOCUS_OUT / PAUSED / RESUMED per Android-versie, scherm uit, split-screen,
  app die door Android in de achtergrond wordt gesloten. Fix 2 en O2 hangen hiervan af.
- **Touch-gevoel:** multitouch, duimbereik, notch/punch-hole. `uipolishtest` (763 PASS) meet tikvlakken en veilige zone in
  vijf viewportprofielen; echt tikken kan alleen op het toestel.
- **Video's** (CS-02 e.a.) afspelen op het toestel, en pauze midden in een video.
- **Performance** (fps, RAM, laadtijd): zie `docs/release/RC_AUDIT_WM1.md` F4.

## Testresultaten

Zie de PR-beschrijving voor PASS/FAIL per suite (suites los gedraaid, nooit 3 tegelijk).
