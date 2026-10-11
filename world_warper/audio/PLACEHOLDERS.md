# World Warper — audio-placeholders

Er is nog geen audio. Deze map bevat geen geluidsbestanden (geen `.ogg`, `.wav` of andere clips). Ontbrekende cues blijven stil.

RPG ART / audio levert later de bestanden. De cues horen dan in het audiomanifest; tot die tijd wijzigt deze taak dat manifest niet.

| Cue | Soort | Aanroep |
|---|---|---|
| `ww_ambient` | muziek | `WorldWarperAmbience.play_hub()` |
| `ww_hum` | effect | `WorldWarperAmbience.play_hum()` |
| `ww_warp` | effect | `WorldWarperAmbience.play_warp()` |
| `ww_sapientia_glitch` | effect | `WorldWarperAmbience.play_glitch()` |

Script: `res://world_warper/audio/ambience.gd` (`class_name WorldWarperAmbience`).
