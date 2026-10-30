# Opgeladen zware slag (charge attack), alleen Action

Status: **voorstel** (alle waarden wachten op Dennis). Bouwt voort op de 3-slag-keten (#287).
Classic (turn-based) verandert niet.

## Gedrag
- **Tap** = de gewone slag, net als nu: de keten hit1 → hit2 → finisher, op het indrukken. Er komt dus geen input-vertraging bij een tap.
- **Vasthouden:** na `HOLD_START_TICKS` (12 ticks) begint het opladen en loopt de held langzamer (`MOVE_MULT`).
  - na 40 ticks (vanaf het indrukken): **niveau 1**;
  - na 90 ticks: **niveau 2** (het maximum; langer vasthouden doet niets meer).
- **Loslaten** op niveau 1 of 2 = een **zware slag**: meer schade, hitstop en knockback, en hij staggert altijd. Loslaten vóór niveau 1 doet niets extra (de tap-slag is al gevallen).
- De zware slag zet de keten terug op hit1.
- **Geen MP-kosten** en geen stamina-kosten.
- **Dodge annuleert het opladen**: er valt geen zware slag, en de keten wordt ook gereset.
- **Wie:** elke actor:
  - de bestuurde held: de knop wordt elke frame gelezen en per tick verwerkt;
  - co-op-peers: een nieuwe input-bit `BTN_ATTACK_HELD` (16) in de bestaande buttons-byte; de host telt de ticks;
  - de bondgenoot-AI: laadt na elke finisher de volgende slag op tot `ALLY_LEVEL` (1) en laat dan los. Dat is deterministisch: alleen tellen, geen toeval.
- **Host-autoritatief en deterministisch:** alle vasthoud-tellers lopen op de vaste sim-tick (`sim_step` / `coop_host_step`) in de arena van de host. Er is geen toeval.

## Voorgestelde waarden (`scripts/data/som_heavy_data.gd`)
| | niveau 1 | niveau 2 |
|---|---|---|
| vastgehouden ticks (vanaf het indrukken) | 40 (~0.67 s) | 90 (1.5 s) |
| schade-multiplier | 2.0 | 3.0 |
| hitstop in ticks | 8 | 12 |
| knockback in tegels | 2 | 3 |

- Opladen begint na 12 ticks (0.2 s).
- Loopsnelheid tijdens het opladen: x0.5.
- Ter vergelijking, de keten: hit1/hit2/finisher = x1.0/1.1/1.6, hitstop 0/0/6, knockback 1/1/2.
  Niveau 1 ligt daar net boven, niveau 2 duidelijk.

## Art (RPG ART)
Placeholder: de finisher-placeholder (bestaande `<held>_attack.png`, langzaam tempo). Nodig per held:
- `<held>_charge.png` (laad-pose, in een lus);
- `<held>_heavy.png` (zware slag), 288x192, 6x4 frames van 48x48.

Prioriteit Dax + Seren.

## Tests
`--chargetest` (`scripts/tests/charge_tests.gd`) test voor Dax en Seren:
- de niveaus per tick;
- de vertraging tijdens het opladen;
- de zware slag bij het loslaten (meer schade, hitstop en knockback dan de finisher);
- dodge annuleert het opladen;
- een tap verandert niets;
- geen opladen in Classic;
- een co-op-peer laadt op via `BTN_ATTACK_HELD`;
- de bondgenoot-AI laadt op na de finisher;
- determinisme.
