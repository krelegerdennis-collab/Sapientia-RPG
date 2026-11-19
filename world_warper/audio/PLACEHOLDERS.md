# World Warper — audio-placeholders

KLAAR (#554, merge `83000372`): de SFX `ww_hum`, `ww_warp` en `ww_sapientia_glitch` staan in `assets/audio/audio_manifest.json` met elk één `.wav` onder `assets/audio/sfx/`. Gekozen seeds (Dennis, Stable Audio Open 1.0, zie `assets/audio/sfx/HERKOMST.md`): hum s1002, warp s1002, glitch s1000.

Deze map bevat zelf geen geluidsbestanden. Hub-muziek `ww_ambient` stond al onder `bgm` (hergebruik Diepe Grot). Ontbrekende cues blijven stil via `ambience.gd`.

| Cue | Soort | Aanroep |
|---|---|---|
| `ww_ambient` | muziek | `WorldWarperAmbience.play_hub()` |
| `ww_hum` | effect | `WorldWarperAmbience.play_hum()` |
| `ww_warp` | effect | `WorldWarperAmbience.play_warp()` |
| `ww_sapientia_glitch` | effect | `WorldWarperAmbience.play_glitch()` |

Script: `res://world_warper/audio/ambience.gd` (`class_name WorldWarperAmbience`).
