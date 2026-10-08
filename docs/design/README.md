# docs/design: referentie, GEEN runtime-data

Bron: `Sapientia-Design` (main, commit b6fe4d4), `data/pvp-colosseum.json`.
Hier opgeslagen als `rangkuil_arena.json` (inhoud ongewijzigd).

**Alleen referentie.** De stats in dit bestand gebruiken een **andere schaal** dan de game:
- schade = `max(1, aanval - verdediging)` met tegenstanders van aanval 16-42 en HP 48-...;
  v0.17 gebruikt `atk/def/mag/mdef/agi` uit `scripts/data/game_data.gd` en een eigen formule
  (Kort zwaard = atk 3, Vonkzwaard = atk 12, Golem-baas = atk 33 bij Dennis ~Lv 10).
- beloningen (`attack: 10`, `defense: 5`, `attack: 18`...) zijn niet 1-op-1 over te nemen.
- `stats`-namen: `attack/defense/hp` (hier) vs `atk/def/max_hp` (game).

Niet laden in de game. Bij inbouwen: herbalanceren tegen de heldencurve en de vijanden in
game_data.gd, en eerst kiezen waar *De Rangkuil* in de v0.17-route ligt (de JSON zet hem
"na Act 1, op weg naar Noor en Lotte"; in v0.17 zit daar Esdoorn + het Donker Woud).

Let op namen: de Brons-beloning **Vonkkling** lijkt sterk op het bestaande **Vonkzwaard**,
en tegenstander **Bram Holt** botst met **Oude Bram** in Esdoorn. Hernoemen bij inbouw.
`docs/*` staat al in `exclude_filter` van export_presets.cfg, dus dit komt niet in de APK.
