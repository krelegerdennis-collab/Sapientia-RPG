# F4 — Game feel (client-only)

Screenshake en gekleurde schadegetallen op vijanden. Geen wijziging aan hitstop, sim of netcode.

## Screenshake (`scripts/som/som_shake.gd`)

| soort | px | ticks |
|---|---|---|
| finisher (eigen held) | 1 | 4 |
| heavy L1 | 2 | 6 |
| heavy L2 | 3 | 8 |
| Golem hamerslag en grote AoE (eigen held geraakt) | 3 | 10 |

Alleen de **lokale** held triggert schudden (geen shake bij AI-bondgenoten of andere spelers). Co-op gast: shake `heavy1` als eigen HP in de snapshot met ≥ 10 % daalt.

Patroon: vaste tabel in `SomFeelData.PATTERN` (geen `randf`). Na elke shake: `Camera2D.offset = Vector2.ZERO`.

## Schadegetallen (`SomFx.number`)

| treffer | kleur | schaal |
|---|---|---|
| gewoon | wit | 1.0 |
| finisher | `#FF8A3D` | 1.0 |
| heavy L1 | `#FFD24A` | 1.0 |
| heavy L2 | `#FFD24A` | 1.25 |

Oranje/goud: witte rij in `dmg_digits.png` + `modulate`. Party-schade (rood) en heal (groen) blijven de bestaande rijen.

HD-2D zet elke frame de `modulate` van combat-nodes op de inverse kaart-tint. Finisher- en heavy-getallen bewaren hun kleur in meta `feel_rgb`; de compensatie vermenigvuldigt daarmee, zodat het getal op het scherm oranje of goud blijft. Alpha van de fade-tween blijft staan.

## Uitzetten

Zet in `scripts/data/som_feel_data.gd` constante `ENABLED` op `false` — dan witte getallen en geen camera-offset (oud gedrag).

## Fase 1 (impact + stof + hit-react, client-only)

- Element-impact `fx_impact_<element>` op schadetreffers; chain hit1/hit2 houdt `fx_hit_spark`.
- Stof: `fx_dust_dodge` (flip_h naar links), `fx_dust_land` (dodge-einde / verticaal), `fx_dust_finisher`.
- Hit-react: hurt kolom 0 (50 ms, `HIT_FLASH_CONTACT`); squash/nudge alleen op `sprite.offset`/`scale` (voeten-pivot).
- Gewichtsklassen in `scripts/data/som_gamefeel_data.gd` (licht/middel/zwaar per vijand-id).
- `HIT_FLASH` (0.12 s) blijft staan; de contact-flits gebruikt `HIT_FLASH_CONTACT` (0.05 s).

Tests: `godot -- --gamefeeltest`, `godot -- --gamefeelfase1test` (nog niet in CI-matrix).
