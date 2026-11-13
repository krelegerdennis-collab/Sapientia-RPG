# M9b — Easy-balans gekozen

Dennis koos op 11-11-2026 (kaart t755s4283) de online co-op Easy-balans: vijandschade ×1.2, vloerherstel 50, revive aan.

Alleen een online DLS-kamer met modus `easy` gebruikt dit. `SomData.ENEMY_DAMAGE_MULT` blijft 2.2. `SomData.enemy_damage_mult` blijft `ENEMY_DAMAGE_MULT` × de gebiedsregel. Solo, Classic, offline en Normal/Hard lezen die functie en krijgen geen vloerherstel.

## Schade

`SomData.COOP_EASY_ENEMY_DAMAGE_MULT` is 1.2. `SomData.coop_enemy_damage_mult` zet die factor alleen bij modus `easy` en `boss_hit == false`, daarna × dezelfde gebiedsregel.

`SomArena.enemy_hit_mult` kiest die lookup als de arena in online co-op Easy vecht en de klap geen baasklap is. Troep (`hit_member` zonder vlag) en Page Warden-adds vallen daar onder. `_page_strike` en `_golem_strike` geven `boss_hit` mee en houden de bestaande spel-factor 2.2. De sim telt de baasklap zonder multiplier; dat verschil blijft, de baas gaat niet naar 1.2.

## Vloerherstel

`SomData.COOP_EASY_FLOOR_HEAL_PCT` is 50. `OnlineDlsFloor.heal_living` telt `int(round(max * pct / 100))` op bij HP en MP, alleen bij `hp > 0`, en kapt op het maximum. Vloer 1 doet niets. Vanaf vloer 2 gebeurt dat bij het binnenkomen van de kamer, vóór het gevecht. Wie op 0 HP staat blijft liggen en houdt zijn MP.

Easy-rustvloer 5 (tabel in `data/online/sims/dls.json`) vult levenden daarna tot 100% en roept `CoopRevive.apply_rest`: liggende stoelen staan op volle HP, levenden blijven zoals ze zijn, de revive-teller gaat niet terug naar 0. `OnlineDlsFloor.build` zet alleen de rustpunt-prop. De aanroep zit in `OnlineDlsFloor.apply_easy_entry`, vanuit `OnlineDlsRoom._ready` en `SomArena.setup_coop` (`SomArena.apply_online_easy_entry`, één keer per arena). Het boek op het rustpunt blijft de bestaande interactie.

## Revive

Eén geslaagde revive per stoel per run (`CoopRevive.REVIVES_PER_RUN`). `OnlineDlsRun.revive_used` overleeft een nieuwe verdieping. `setup_coop` roept `begin_run` niet aan zolang die run actief is. Alleen `OnlineDlsRun.start` en `stop` wissen de teller.

Seren (`lotte`) start het kanaal meteen als iemand ligt. Andere AI alleen als er geen levende Heal-stoel is (`CoopRevive.ai_should_revive`). `SeatController.DRIVES_REVIVE` blijft uit en `try_revive` blijft `false`. `SomAlly._coop_revive_drive` blijft de CoopRevive-aanroepen doen.

## Sim

Factor 10, 24 runs, seed `20261110`, vloeren 1–10, `--no-hypo`, revive aan, schade 1.2, herstel 50. Winst alle (baas / 24): 0.0% (0), 70.8% (17), 87.5% (21), 95.8% (23) voor 1–4 stoelen. Bron: `docs/combat/m9b_easy_revive.md`. Suite: `--easycoopbalanstest`.
