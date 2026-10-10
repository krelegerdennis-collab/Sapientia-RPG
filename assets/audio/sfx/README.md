# assets/audio/sfx/

Geluidseffecten voor de AudioManager (`scripts/audio_manager.gd`).

Algemene geluiden (menu, zwaard, magie, deuren) staan met hun bestandsnaam in
`res://assets/audio/audio_manifest.json` (sectie `"sfx"`). Die bestanden horen
hier direct in deze map. Zolang een bestand ontbreekt, blijft dat geluid stil.

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

De AudioManager maakt daar sleutels van: `held_dennis_aanval`, `monster_mosslijm_raak`.
In het gevecht speelt `scripts/data/actor_sfx.gd` die af. Een Codex-bondgenoot
gebruikt de stem van zijn monster.

De wavs die er nu staan zijn **placeholders** (synthetisch, `tools/gen_actor_sfx.py`),
geregistreerd in `tools/placeholders_sfx.txt`. Vervang het bestand, houd de naam,
en haal de regel uit die lijst. Eigen synthese, geen externe licentie; echte
opnames (Suno/Freesound) eerst controleren voordat ze in de APK komen.
