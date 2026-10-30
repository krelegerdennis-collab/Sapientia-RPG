# Actieve dodge + stamina (Combat D5)

Goedgekeurd door Dennis (2026-10-24). Tijdelijke tuning staat in `scripts/data/som_data.gd` (`STAMINA_*`, `DODGE_*`).

## Speler

- **B-knop** in Action = dodge (touch: bestaande B-linksonder-A; toets **X** via `som_dodge`).
- Richting = joystick, anders weg van lock-doel, anders kijkrichting.
- **I-frames:** 15 ticks (0,25 s) via dezelfde `iframes[id]`-map als hit-invuln; telegrafen, zones en root respecteren dat.
- **Roll:** 13 ticks (~0,22 s, `DODGE_TIME`), ~28 px.
- **Stamina:** max 100, dodge 30, regen 1 per 2 ticks na 30 ticks zonder verbruik; geen dodge onder kosten.
- **Sprint (RUN):** kost stamina op de host-tick; lege balk = normale loopsnelheid.
- Dodge roept `break_root(id)` aan (T6-hook).

## Co-op

- Host verwerkt dodge als input-event (`BTN_DODGE` in `net_codec.gd`).
- Stamina per held in snapshot **mp-byte** (0–100, geen spell-MP in Action-co-op).

## Tests

`godot --headless --path . -- --dodgetest` — CI-regel nog door Forge/Dennis in `.github/workflows/tests.yml`.
