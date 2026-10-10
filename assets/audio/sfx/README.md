# assets/audio/sfx/

Geluidseffecten voor de AudioManager (`scripts/audio_manager.gd`).
Bestandsnamen staan in `res://assets/audio/audio_manifest.json` (sectie `"sfx"`, veld `"bestanden"`).

De wav-bestanden in deze map zijn synthetische placeholders uit `tools/gen_algemene_sfx.py`: mono, 16-bit, 22050 Hz, kort. Geen definitief geluid.
Een sounddesigner vervangt elk bestand en houdt de bestandsnaam. Daarna de bijbehorende regel in `tools/placeholders_algemene_sfx.txt` weghalen.

Ontbreekt een bestand uit het manifest, dan blijft dat geluid stil (geen errors).
Bij echte vervanging eerst de licentie controleren voordat het in de APK komt.
