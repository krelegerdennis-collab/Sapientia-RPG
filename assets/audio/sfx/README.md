# assets/audio/sfx/

Geluidseffecten voor de AudioManager (`scripts/audio_manager.gd`).

## Algemene geluiden

Menu, zwaard, magie, deuren en de rest van de manifest-set staan met hun bestandsnaam in `res://assets/audio/audio_manifest.json` (sectie `"sfx"`, veld `"bestanden"`). Die bestanden horen hier direct in deze map.

De wavs die er nu staan zijn synthetische placeholders uit `tools/gen_algemene_sfx.py`: mono, 16-bit, 22050 Hz, kort. Geen definitief geluid. Een sounddesigner vervangt elk bestand en houdt de bestandsnaam. Daarna de bijbehorende regel in `tools/placeholders_algemene_sfx.txt` weghalen.

Ontbreekt een bestand uit het manifest, dan blijft dat geluid stil (geen errors). Bij echte vervanging eerst de licentie controleren voordat het in de APK komt.

## Per held en per monster

Elk wezen heeft een eigen map. De catalogus is `res://assets/audio/actor_sfx.json`.

| map | voorbeeld |
|---|---|
| `helden/<id>/` | `helden/dennis/aanval.wav` |
| `monsters/<id>/` | `monsters/mosslijm/raak.wav` |

Vier bestanden, altijd dezelfde naam:

- `aanval.wav` — gewone aanval
- `raak.wav` — geraakt
- `dood.wav` — verslagen
- `vaardigheid.wav` — spreuk, kernkracht of speciale aanval

De AudioManager maakt daar sleutels van: `held_dennis_aanval`, `monster_mosslijm_raak`. In het gevecht speelt `scripts/data/actor_sfx.gd` die af. Een Codex-bondgenoot gebruikt de stem van zijn monster.

De wavs in die mappen zijn placeholders (synthetisch, `tools/gen_actor_sfx.py`), geregistreerd in `tools/placeholders_sfx.txt`. Vervang het bestand, houd de naam, en haal de regel uit die lijst. Eigen synthese, geen externe licentie; echte opnames (Suno/Freesound) eerst controleren voordat ze in de APK komen.
