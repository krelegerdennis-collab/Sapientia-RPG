# F8.6 Droge release-build (preset Android)

Meting op 17 november 2026, op commit `cd491d3a7bd8a5531852ba1165f0b70f8d70fd64` van `finish/wm1`.
Geëxporteerd is de preset **Android** uit `export_presets.cfg` (niet **Android arm64**, niet **Android AAB**).
Er is niets gepubliceerd of geüpload. Repository-secrets zijn niet gebruikt en niet opgevraagd.
APK's, de wegwerp-keystore en de logs staan alleen onder `/tmp` op de VM, niet in de repository.
`export_presets.cfg` is niet gewijzigd.

## Omgeving

| Onderdeel | Waarde |
|---|---|
| Godot | `4.3.stable.official.77dcf97d8` (`Godot_v4.3-stable_linux.x86_64 --version`) |
| Export-templates | `~/.local/share/godot/export_templates/4.3.stable/` (official 4.3-stable `.tpz`) |
| JDK | OpenJDK 17.0.21.0.3 (`/usr/lib/jvm/java-17-openjdk-amd64`) |
| Android cmdline-tools | `commandlinetools-linux-13114758_latest.zip`, `sdkmanager --version` = 19.0 |
| SDK-pakketten | `platform-tools`, `platforms;android-34`, `build-tools;34.0.0` |
| `aapt` | Android Asset Packaging Tool, v0.2-10229193 (build-tools 34.0.0) |
| `ANDROID_HOME` | `/home/ubuntu/.local/android-sdk` |
| Editor-instellingen | `~/.config/godot/editor_settings-4.3.tres` |

Godot-editorinstellingen, zelfde sleutels als `.github/workflows/build-apk.yml`:

- `export/android/java_sdk_path` = `/usr/lib/jvm/java-17-openjdk-amd64`
- `export/android/android_sdk_path` = `/home/ubuntu/.local/android-sdk`
- `export/android/debug_keystore` = `/tmp/f86-keystore/android-debug.keystore`
- `export/android/debug_keystore_user` = `androiddebugkey`
- `export/android/debug_keystore_pass` = `android`

De binary staat in `$HOME/.local/godot-4.3/`, buiten de repository. Een lokale, gitignorede `.godot/` die nog naar Godot 4.7.2 wees, is voor de import opzij gezet, zodat `--import` schoon liep zoals op een checkout zonder `.godot/`.

## Commando's

Wegwerp-keystore (buiten de repo; niet gecommit):

```bash
keytool -genkeypair -v \
  -keystore /tmp/f86-keystore/android-debug.keystore \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Android Debug,O=Android,C=US"
```

Import, één keer (`GODOT=$HOME/.local/godot-4.3/Godot_v4.3-stable_linux.x86_64`):

```bash
timeout 1800 "$GODOT" --headless --path /agent/repos/Sapientia-RPG --import
```

Release-export. De workflow zet ook `GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD`; die stond hier mee. `strings` op de 4.3-binary bevat `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER` en `_PASSWORD`, en niet `_KEY_PASSWORD`. Store- en key-wachtwoord van de wegwerp-keystore zijn gelijk.

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/tmp/f86-keystore/android-debug.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
export GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD=android
timeout 1800 "$GODOT" --headless --path /agent/repos/Sapientia-RPG \
  --export-release "Android" /tmp/f86-out/sapientia-release.apk
```

Debug-export, zonder die release-variabelen (debug-keystore uit de editor-instellingen; hetzelfde wegwerpbestand):

```bash
timeout 1800 "$GODOT" --headless --path /agent/repos/Sapientia-RPG \
  --export-debug "Android" /tmp/f86-out/sapientia-debug.apk
```

De workflow gebruikt `timeout 600`. Beide exports en de import zaten daar ruim onder.

## Import

| | |
|---|---|
| Exitcode | 0 |
| Duur | 22 s |
| `SCRIPT ERROR` | geen |

Regels in `import.log` naast de versiekop:

- `Could not find version of build tools that matches Target SDK, using 34.0.0`
- `Unicode parsing error, some characters were replaced with � (U+FFFD): NUL character` (9 keer, geen bestandsnaam in de regel)

Geïnstalleerd is alleen build-tools 34.0.0. De niet-geëxporteerde preset **Android AAB** heeft `gradle_build/target_sdk="36"`.

## Export

Geen regel met `ERROR` of `WARNING` in de release- of debug-log. In beide logs staat wel:

`Could not find version of build tools that matches Target SDK, using 34.0.0`

Daarna `export: begin` … `Aligning APK` … `Signing` … `Verifying APK` … `export: end`.
De aanroep van `apksigner` in de log heeft `--ks`, `--ks-pass` en `--ks-key-alias` als `<REDACTED>`. Er is geen apart `--key-pass`.

| | Release | Debug |
|---|---|---|
| Commando | `--export-release "Android"` | `--export-debug "Android"` |
| Uitvoer | `/tmp/f86-out/sapientia-release.apk` | `/tmp/f86-out/sapientia-debug.apk` |
| Exitcode | 0 | 0 |
| Duur | 22 s | 16 s |
| Grootte | 126959649 bytes (`ls -lh`: 122M) | 129585138 bytes (`ls -lh`: 124M) |
| `aapt dump badging` | exit 0 | exit 0 |
| `apksigner verify --print-certs` | exit 0 | exit 0 |
| `zipalign -c 4` | exit 0 | exit 0 |
| `zipalign -c -p 4` | exit 0 | niet gedraaid |
| `application-debuggable` | afwezig | aanwezig (`android:debuggable=true`) |

`zipalign` uit build-tools 34.0.0 heeft geen vlag `-P` (`invalid option -- 'P'`, exit 2). Die vlag is niet gebruikt als resultaat.

## Preset Android (ongewijzigd) tegenover de APK

Uit `export_presets.cfg`, preset naam `Android`:

| Veld | Preset | Gemeten in de release-APK |
|---|---|---|
| `version/code` | 23 | `versionCode='23'` (manifest `0x17`) |
| `version/name` | `0.21` | `versionName='0.21'` |
| `package/unique_name` | `com.dennis.rpgprototype` | `package: name='com.dennis.rpgprototype'` |
| `package/name` | `SAPIENTIA` | `application-label:'SAPIENTIA'` |
| `gradle_build/use_gradle_build` | false | APK uit de 4.3-template, geen Gradle-build |
| `gradle_build/export_format` | 0 | APK, geen AAB |
| `gradle_build/min_sdk` | leeg | `sdkVersion:'21'` (manifest `0x15`) |
| `gradle_build/target_sdk` | leeg | `targetSdkVersion:'34'` (manifest `0x22`) |
| `architectures/arm64-v8a` | true | aanwezig |
| `architectures/armeabi-v7a` | true | aanwezig |
| `architectures/x86` | false | afwezig |
| `architectures/x86_64` | false | afwezig |
| `permissions/internet` en de drie wifi/netwerk-vlaggen | false | geen `uses-permission` |
| `permissions/custom_permissions` | leeg | geen `uses-permission` |
| `keystore/release`, `release_user`, `release_password` | leeg | ingevuld via de omgevingsvariabelen hierboven |
| `keystore/debug`, `debug_user`, `debug_password` | leeg | debug-export via de editor-instellingen |

`tools/release/version.json` is `version_name` `0.21`, `version_code` 23. `project.godot` heeft `config/version="0.21"`. Die drie komen overeen; deze run heeft geen versie gebumpt.

De stock template `android_release.apk` uit 4.3.stable meldt zelf `sdkVersion:'21'`, `targetSdkVersion:'34'`, `compileSdkVersion='34'`, en bevat `lib/` voor `arm64-v8a`, `armeabi-v7a`, `x86` en `x86_64`. In de geëxporteerde APK zijn x86 en x86_64 er niet meer.

`aapt dump badging` (release), naast de tabel: `launchable-activity: name='com.godot.game.GodotApp'`, `uses-feature: name='android.hardware.faketouch'` met `uses-implied-feature` (standaard voor alle apps), `supports-screens: 'small' 'normal' 'large' 'xlarge'`, `native-code: 'arm64-v8a' 'armeabi-v7a'`. `aapt dump permissions` drukt alleen `package: com.dennis.rpgprototype` af. In `aapt dump xmltree` van `AndroidManifest.xml` staat `android:extractNativeLibs=true` en geen `uses-permission`.

## Native bibliotheken (`unzip -l`)

Release:

```
  6933952  lib/arm64-v8a/libc++_shared.so
 60050568  lib/arm64-v8a/libgodot_android.so
  4359916  lib/armeabi-v7a/libc++_shared.so
 65004956  lib/armeabi-v7a/libgodot_android.so
```

Debug (andere template, grotere `libgodot_android.so`):

```
  6933952  lib/arm64-v8a/libc++_shared.so
 65494072  lib/arm64-v8a/libgodot_android.so
  4359916  lib/armeabi-v7a/libc++_shared.so
 71512764  lib/armeabi-v7a/libgodot_android.so
```

Alle vier de release-`.so`'s staan gecomprimeerd in de APK (zip method deflate, `compress_type=8`). `readelf -l` op de uitgepakte release-bestanden: elk `LOAD`-segment heeft `Align 0x1000` (4 KB), voor `libgodot_android.so` en `libc++_shared.so`, arm64 en armeabi-v7a. Geen `Align 0x4000`.

## Exclude-filter en PCK

De release-APK heeft geen zip-entry met extensie `.pck` (debug evenmin gecontroleerd op een aparte PCK; de release-listing is volledig nagelopen). Godot 4.3 schrijft de export-pack als losse bestanden onder `assets/` in de APK: 5726 zip-entries, waaronder 325 `.gdc`, 2050 `.ctex`, 2350 `.import`. De exclude-filter is op die paden gecontroleerd (prefix `assets/` eraf, `*` als willekeurige reeks).

Elk patroon uit `exclude_filter` van preset Android: 0 treffers.

Steekproef, ook op de gecompileerde naam (`.gdc` / `.remap`) en op de bronnaam:

| Pad | In de release-APK |
|---|---|
| `tools/` | afwezig |
| `docs/` | afwezig |
| `scripts/debug_autotest.gd` en `.gdc` | afwezig |
| `scripts/debug_menutest.gd` en `.gdc` | afwezig |
| `scripts/tests/` | afwezig |
| `*.md` | afwezig |
| `export_presets.cfg` | afwezig |
| `wacht/` | afwezig |
| `export/` | afwezig |
| `pvp/tests/` | afwezig |
| `world_warper/tests/` | afwezig |
| `world_warper/cutscene/dreiging_test.gd` | afwezig |
| `world_warper/flow/unlock_test.gd` | afwezig |
| `world_warper/guide/dialoog_test.gd` | afwezig |
| `world_warper/warp/destinations_test.gd` | afwezig |
| `assets/sprites/enemies/golem_boss.png` | afwezig |
| `assets/sprites/enemies/golem_boss_hit.png` | afwezig |
| `assets/sprites/enemies/golem_boss_idle.png` | afwezig |
| `assets/sprites/enemies/kennis_beest.png` | afwezig |
| `assets/tiles/wereld.png` | afwezig |
| `assets/sprites/story/archief.png`, `zegel.png`, `kist.png`, `put.png` | afwezig |

Wel aanwezig, en niet het uitgesloten pad: `assets/sprites/enemies/golem_boss_v2.png` (en `_hit` / `_idle` / `_damaged`), `assets/tiles/wereld_v14.png` en nieuwere `wereld_v*.png`, en `.godot/imported/kennis_beest.png-f7f5987ceb47f2230d9c25a384a6fbd1.ctex`. Die ctex-hash staat in `assets/map_monsters/kennis_beest.png.import`, niet in het uitgesloten `assets/sprites/enemies/kennis_beest.png`.

## Handtekening

`apksigner verify --verbose --print-certs` exit 0 voor beide APK's. Beide: v1, v2 en v3 waar; v3.1 en v4 onwaar; één signer; RSA 2048; DN `CN=Android Debug, O=Android, C=US`. Certificaat-SHA-256 van beide is `81dc05e4ba0287d330fda352cbdcba3e6e48a82919e9a3e05bbee9f1178d5c18`. Release en debug zijn dus met dezelfde wegwerp-sleutel getekend. Die sleutel is op deze VM gegenereerd en is niet de release-keystore uit de repository-secrets.

## Blokkers

Feiten die een ondertekende store-release van dit artefact tegenhouden. Geen voorstellen.

1. **Release-keystore ontbreekt in deze build.** De velden `keystore/release`, `keystore/release_user` en `keystore/release_password` in de preset zijn leeg. De secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` en `ANDROID_KEY_PASSWORD` zijn niet gebruikt. De CI-stap "Require release signing secrets" in `build-apk.yml` stopt een release-run als ze ontbreken. De APK hier is getekend met de wegwerp-keystore hierboven (DN `CN=Android Debug, O=Android, C=US`), niet met de upload-sleutel van het project. Release en debug delen dat certificaat.

2. **targetSdk 34, minSdk 21.** `aapt` en het binaire manifest: `targetSdkVersion` 34, `sdkVersion` 21, `compileSdkVersion` 34. Preset Android laat `gradle_build/min_sdk` en `gradle_build/target_sdk` leeg en heeft `gradle_build/use_gradle_build=false`, dus dit zijn de waarden van de 4.3-template. `docs/release/PLAY_STORE.md` legt de Play-eis per 31 augustus 2026 op targetSdk 36 voor nieuwe apps en updates.

3. **Het artefact is een APK, geen AAB.** Preset Android heeft `gradle_build/export_format=0` en `gradle_build/use_gradle_build=false`. De uitvoer is `/tmp/f86-out/sapientia-release.apk`. Play eist voor nieuwe apps een Android App Bundle.

4. **Pakketnaam `com.dennis.rpgprototype`.** Zowel `package/unique_name` in de preset als `aapt` (`package: name='com.dennis.rpgprototype'`). `docs/release/PLAY_STORE.md` stelt dat de pakketnaam na de eerste upload permanent is en dat deze prototype-naam nog niet de gekozen store-naam is.

5. **`armeabi-v7a` zit in de APK.** Preset Android heeft `architectures/armeabi-v7a=true` en `architectures/arm64-v8a=true`. `aapt` meldt `native-code: 'arm64-v8a' 'armeabi-v7a'`. `lib/armeabi-v7a/libgodot_android.so` is 65004956 bytes. x86 en x86_64 zitten er niet in. arm64-v8a is wel aanwezig.

6. **Native libs zijn 4 KB uitgelijnd en gecomprimeerd.** `readelf -l`: `Align 0x1000` op alle `LOAD`-segmenten van `libgodot_android.so` en `libc++_shared.so` (arm64 en v7a). De `.so`-entries gebruiken deflate. Het manifest zet `android:extractNativeLibs=true`. `docs/release/PLAY_STORE.md`: de officiële 4.3-stable-templates hebben geen 16 KB-uitlijning, en een upload met targetSdk 35 of hoger kan daarop geweigerd worden. Deze APK meet targetSdk 34 én `Align 0x1000`.

Geen `uses-permission` in het manifest (ook `INTERNET` niet). Dat is de stand van de vier permissievlaggen in de preset, alle `false`, plus een lege `custom_permissions`.
