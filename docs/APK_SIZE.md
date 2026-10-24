# APK-grootte (Android arm64, WM1)

Doel: kleinere APK, **zonder content te schrappen** en zonder één art-pixel te veranderen.
Meting op 24 okt 2026, `main` `f7f438f`, preset **Android arm64** (release-export).

## Hoe gemeten

- Godot **4.3-stable** (editor + officiële export templates), Android SDK build-tools 34.0.0, JDK 21.
- `--export-release "Android arm64"` headless; getekend met een **wegwerp-keystore** in `/tmp` (via
  `GODOT_ANDROID_KEYSTORE_RELEASE_*` env-vars; niets in de repo, `export_presets.cfg` blijft zonder signing-velden).
- Per categorie: `python3 tools/apk_size/pck_rapport.py <apk|pck> --project <map>` (leest de zip/PCK en herleidt
  `.godot/imported/*` naar de bronmap via de `.import`-bestanden). In een APK telt de **gecomprimeerde** zip-grootte.
- Rooktest: de nieuwe `.pck` start headless (`--main-pack`) met dezelfde uitvoer als de oude.

## Resultaat (bytes, gecomprimeerd zoals in de APK)

| categorie | voor | na | verschil | % |
|---|---:|---:|---:|---:|
| muziek (bgm, 12 oggs) | 44.029.599 | 33.018.041 | -11.011.558 | -25,0% |
| video (2x .ogv) | 30.279.538 | 30.279.538 | 0 | 0% |
| engine (`libgodot_android.so` + libc++) | 20.816.454 | 20.816.454 | 0 | 0% |
| sfx (286 wav) | 3.185.113 | 785.038 | -2.400.075 | -75,4% |
| afbeeldingen (619 ctex) | 2.637.937 | 2.637.937 | 0 | 0% |
| APK overig (manifest, res/, dex) | 2.291.112 | 2.289.342 | -1.770 | -0,1% |
| scripts (.gdc) | 1.451.574 | 1.403.201 | -48.373 | -3,3% |
| scenes | 261.346 | 260.714 | -632 | -0,2% |
| overig (assets overig, data, resources, fonts) | 254.852 | 240.739 | -14.113 | -5,5% |
| **som zip-entries** | **105.207.525** | **91.731.004** | **-13.476.521** | **-12,8%** |
| **APK-bestand** | **105.773.127** | **92.291.288** | **-13.481.839** | **-12,7%** |
| `.pck` (`--export-pack`, ongecomprimeerd) | 84.091.728 | 70.356.000 | -13.735.728 | -16,3% |

(12,86 MiB kleiner; 100,87 MiB -> 88,01 MiB.)

## Wat er veranderd is

1. **Muziek** (`assets/audio/bgm/*.ogg`, -10,5 MiB): herencode naar Ogg Vorbis libvorbis `-q:a 3` (~100-105 kbps
   gemiddeld, was 120 en 160 kbps nominaal). Vijf bestanden bevatten daarnaast een Theora-coverbeeld (1500x692,
   19 KB, door de game nooit gebruikt); dat valt weg. Gereproduceerd met `tools/apk_size/bgm_herencode.py`.
   - Het aantal gedecodeerde samples is per bestand **exact gelijk** (loop-punten en de "staart in de kop"-mix
     blijven naadloos); in Godot 4.3 geeft `AudioStream.get_length()` voor alle 12 bestanden hetzelfde resultaat
     als voor de oude (max verschil 0,0 s).
   - Bestandsnamen, `.import`-bestanden, manifest en `scripts/tests/*` zijn ongewijzigd.
   - Het script slaat bestanden over die al <= 115 kbps zijn en geen video hebben (geen dubbel generatieverlies).
   - Kwaliteitskeuze: `q3` is de libvorbis-standaard. Meer besparing kan: `q2.5` geeft nog ~-3,9 MiB, `q2` ~-5,2 MiB
     (t.o.v. `q3`, zelfde 12 bestanden, op de bron-ogg's gemeten); dat is een luisterbeslissing voor Dennis.
2. **SFX** (`assets/audio/sfx/**/*.wav.import`, -2,3 MiB): `compress/mode=2` (QOA) voor alle 286 wavs. Dat was al zo
   voor 20 wavs. De bron-`.wav` blijven staan (de tests lezen de RIFF-header). Acht heldengeluiden
   (`helden/kael`, `helden/orion`) hadden geen getrackt `.import`-bestand; die zijn toegevoegd. Alle sfx hebben
   dezelfde lengte en samplerate als voorheen; geen enkele sfx loopt (`audio_manifest.json`).
3. **Exportfilter** (`export_presets.cfg`, alleen `exclude_filter` van beide Android-presets, -65 KB):
   `wacht/*` (stond al achter `.gdignore`, nu dubbel), `export/*` (webbuild-`.import`'s), `pvp/tests/*`,
   `world_warper/tests/*` en de vier `*_test.gd` in `world_warper/` die geen enkel spelscript gebruikt
   (`dreiging_test`, `unlock_test`, `dialoog_test`, `destinations_test`). `spawn_test.gd` en `party_view_test.gd`
   blijven bewust erin: `wanderers.gd` en `party_select.gd` doen er een `preload` op.
   `game_state.gd` kijkt eerst of `pvp/tests/pvp_tests.gd` bestaat, dus de testdispatch breekt niet.
   De Web-preset is niet aangepast.

## Gemeten maar niet toegepast

| onderwerp | bevinding |
|---|---|
| Lossless PNG-optimalisatie | `tools/apk_size/png_optimeer.py` (oxipng, kleurtype/bitdiepte blijven gelijk, pixel-verificatie op RGBA, slaat `tools/handwerk.txt` over): 163 niet-handwerk-PNG's, 933.492 -> 579.479 bytes (-354 KB), 0 pixelverschillen. **Effect op de APK: 0.** Godot importeert elke PNG naar `.ctex`; alle 726 `.ctex`-bestanden zijn na optimalisatie byte-identiek, en de bron-PNG zit niet in de APK. Alleen repo-grootte, dus niet gecommit (550 van de 713 gecontroleerde PNG's staan in `handwerk.txt`). Met palet/RGB-reductie veranderde `icon.png` wel (launcher-icons ~-16 KB) maar ook de `.ctex`-header (RGBA8 -> RGB8): bewust niet gedaan. |
| Ongebruikte resources | Alle 619 `.ctex` zijn samen 2,5 MiB; een scan op pad/bestandsnaam vindt 199 niet-sfx-bestanden (~120 KB bron) zonder letterlijke verwijzing (hub-iconen, wilgendal-npc's, world_warper-kleurvarianten, UI-iconen). Veel worden dynamisch samengesteld (`"%s_hub.png"`, kleursuffixen), de winst is < 0,1% en dit raakt content. Niet uitgesloten. |
| Dubbele sfx | 40 wavs in `assets/audio/sfx/monsters` zijn byte-identiek aan een andere (placeholders delen geluid); ~0,13 MiB na QOA. Delen kan alleen door paden in `actor_sfx.json` te wijzigen en de tests (`actor_sfx_tests`) lezen per-id-bestand. Niet gedaan. |
| Video (30,3 MB, 28,9 MiB) | `genezer_warper.ogv` staat in `tools/handwerk.txt` (niet aanraken, 20,6 MB). `worldmap_intro.ogv` (9,8 MB, 720x1280): opnieuw coderen met Theora op dezelfde resolutie is geen goede ruil (`-q:v 5` = 7,6 MB met SSIM 0,95; `-q:v 6` is zelfs groter dan het origineel). Kleinere resolutie (HANDOFF_CUTSCENE noemde 360x640) is een keuze voor RPG Forge, want het filmpje rendert bewust op schermresolutie. |
| Engine (19,9 MiB in de APK) | `libgodot_android.so` is de standaard template (60 MB onuitgepakt). Een eigen template zonder 3D/ongebruikte modules kan enkele MiB schelen; vergt een eigen template-build, buiten deze PR. |
| Preset "Android" (v7a + arm64) | Zelfde inhoud maar met `armeabi-v7a`: 125,7 MB tegen 92,3 MB voor "Android arm64". Voor Play/APK-distributie op arm64-telefoons is alleen de arm64-preset nodig. |

## Voorstellen (niet gedaan: valt buiten de scope van deze PR)

- `.github/workflows/tests.yml`: stap die `--export-pack "Android arm64"` draait en `pck_rapport.py --md` in de
  job-summary zet, met een drempel (bv. fail bij > +5% t.o.v. `main`). Workflows zijn voor RPG Forge.
- `scripts/game_state.gd` `_ready()` bevat een tijdelijk blok "CI-DIAG (#141)" dat `res://.godot/imported`
  doorloopt en twee regels met een lange lijst print; in de APK is dat nutteloos. Verwijderen bij een volgende gameplay-PR.
- Nieuwe muziek: direct als Vorbis `-q:a 3` aanleveren (`bgm_herencode.py` doet dat achteraf), zonder coverbeeld.
- Nieuwe sfx: `compress/mode=2` in het `.import`-bestand meteen meecommitten (Godot 4.3 maakt standaard mode 0).

## Reproduceren

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
git archive HEAD | tar -x -C /tmp/proj && cd /tmp/proj
$GODOT --headless --path . --import
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/tmp/wegwerp.keystore GODOT_ANDROID_KEYSTORE_RELEASE_USER=k \
       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...        # wegwerp, nooit committen
$GODOT --headless --path . --export-release "Android arm64" /tmp/out.apk
python3 tools/apk_size/pck_rapport.py /tmp/out.apk --project . --md
```
