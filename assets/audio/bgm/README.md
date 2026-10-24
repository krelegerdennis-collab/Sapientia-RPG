# assets/audio/bgm/

Muziek (BGM) voor de AudioManager (`scripts/audio_manager.gd`, autoload sinds v0.18).
Bestandsnamen staan in `res://assets/audio/audio_manifest.json` (sectie `"bgm"`, veld `"bestand"`).

Deze zes nummers komen uit Suno (mp3 omgezet naar ogg Vorbis):

| bestand | sleutel | waar |
|---|---|---|
| `bgm_main_menu.ogg` | `main_menu` | Titelscherm |
| `bgm_wachtershuis.ogg` | `wachtershuis` | Het Wachtershuis |
| `bgm_vergeten_archieven.ogg` | `vergeten_archieven` | De Vergeten Archieven |
| `bgm_gevecht_normaal.ogg` | `gevecht_normaal` | Gewone gevechten |
| `bgm_gevecht_miniboss.ogg` | `gevecht_miniboss` | Golem en andere tussenbazen |
| `bgm_wereld.ogg` | `wereld` | Wereldkaart |

De wereldkaart speelt `wereld`. De andere sleutels staan klaar; die mappen en gevechten vragen hun track nog niet aan.
Ontbreekt een bestand uit het manifest, dan blijft dat stuk stil (geen errors).
Licenties (Suno/Freesound) eerst controleren voordat er iets in de APK komt.

**APK-grootte:** de oggs zijn herencoded naar Ogg Vorbis `-q:a 3` zonder coverbeeld
(zelfde aantal samples, dus dezelfde loop). Nieuwe muziek liefst direct zo aanleveren;
zie `docs/APK_SIZE.md` en `tools/apk_size/bgm_herencode.py`.
