# Play Store-release (fase 8)

Voorbereiding om SAPIENTIA als **Android App Bundle (AAB)** in Google Play te zetten. Alleen voorbereiding:
niets hier publiceert iets, bumpt een versie of raakt signing-gegevens aan. Eigenaar van de keuzes is **Dennis**;
**RPG Forge** bumpt de versie, bouwt en uploadt. Alle speler-tekst en alle store-teksten zijn Engels, deze docs blijven Nederlands.

## 1. Wat er nu ligt

| Onderdeel | Bestand |
|---|---|
| Release-preset (AAB, arm64, targetSdk 36) | `export_presets.cfg`, preset **Android AAB** |
| Versiebron (naam + code) | `tools/release/version.json` |
| Versiescript | `tools/release/bump_version` (python3) |
| Lokale build (keystore uit omgeving) | `tools/release/build_aab.sh` |
| Changelog vanaf v0.18 | `CHANGELOG.md` |
| Headless test | `-- --aabtest` (`scripts/tests/aab_tests.gd`), nog niet in de CI-matrix (zie §8) |

De bestaande presets **Android** en **Android arm64** (APK) en de workflow `build-apk` blijven ongewijzigd werken.

## 2. Versies uit één bron

`tools/release/version.json` is de enige plek waar je een versie invult:

```json
{ "version_name": "0.20", "version_code": 22 }
```

`tools/release/bump_version` schrijft die waarden naar de rest, zodat ze nooit uit elkaar lopen:

| Doel | Veld |
|---|---|
| `project.godot` | `config/version` (titelscherm `v0.20`, saves, sessielog) |
| `export_presets.cfg` | `version/name` en `version/code` in **elke** Android-preset (APK en AAB) |
| `CHANGELOG.md` | kopje `## [<naam>] - <datum>` onder `[Unreleased]` |

```bash
tools/release/bump_version                 # toon de bron + afwijkingen
tools/release/bump_version --check         # exit 1 bij afwijking (ook als het changelog-kopje ontbreekt)
tools/release/bump_version minor           # 0.20 -> 0.21, versionCode 22 -> 23
tools/release/bump_version patch           # 0.20 -> 0.20.1
tools/release/bump_version set 0.25 --code 40
tools/release/bump_version --sync          # bron -> alle doelen, zonder de bron te wijzigen
tools/release/bump_version minor --dry-run # niets schrijven
```

Regels: `version_code` moet bij elke bump **stijgen** (Play weigert een gelijke of lagere code) en blijft <= 2.100.000.000;
`version_name` is `X.Y` of `X.Y.Z`. De bump zelf blijft werk van RPG Forge (zie AGENTS.md); deze PR bumpt niets: de bron is
gelijkgetrokken op de bestaande waarden **0.20 / code 22** (de APK-presets stonden nog op naam `0.19`, `project.godot` al op `0.20`).

Aanbevolen release-flow: `bump_version minor` > changelog invullen onder het nieuwe kopje > PR > merge > `build_aab.sh` > upload.

## 3. Doel-API en Android-eisen

- **targetSdk 36 (Android 16)**: sinds **31 augustus 2026** moeten nieuwe apps en updates op Google Play targetSdk 36 of hoger hebben
  (bestaande apps minimaal 35 om beschikbaar te blijven voor nieuwe gebruikers; uitstel kon tot 1 november 2026 worden aangevraagd).
  Bron: [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878).
  De preset zet `gradle_build/target_sdk="36"`, `min_sdk="24"` (Godot-standaard, Android 7.0).
- **Alleen arm64-v8a** in de AAB (`architectures/arm64-v8a=true`, de rest uit). Play eist 64-bit; v7a is niet meer nodig.
- **16 KB-pagina's**: apps met targetSdk 35+ moeten 16 KB-geheugenpagina's op 64-bit toestellen ondersteunen
  ([Android-documentatie](https://developer.android.com/guide/practices/page-sizes); updates zonder die ondersteuning worden vanaf 1 februari 2027 geweigerd).
  De 16 KB-uitlijning van `libgodot_android.so` zit in de **Godot-exporttemplates vanaf 4.5**; de officiële **4.3-stable**-templates hebben die niet
  (de NDK-wijziging, [godot#106358](https://github.com/godotengine/godot/pull/106358), kwam pas na 4.4.1). **Dit is het grootste risico voor een Play-upload**:
  de AAB bouwen met 4.3 lukt wel technisch (gecontroleerd tijdens deze voorbereiding met 4.3-stable, JDK 17, Android SDK 34/36 en een wegwerp-keystore:
  ondertekende AAB van ca. 118 MB, manifest `minSdkVersion=24` en `targetSdkVersion=36`, alleen `arm64-v8a`), maar `libgodot_android.so` heeft dan
  ELF-segmenten met 4 KB-uitlijning (`readelf -l`: `Align 0x1000`), dus Play kan de upload afwijzen of waarschuwen.
  Oplossing (beslissing RPG Forge): de release-AAB bouwen met Godot 4.5+ (de repo draait al op 4.7.2 voor de web-export) en `--aabtest` + de suites daarop draaien.
  `build_aab.sh` waarschuwt als `GODOT` ouder is dan 4.5.
- **Edge-to-edge** is vanaf targetSdk 35 verplicht in Android 15/16; het spel gebruikt `screen/immersive_mode=true` en een vaste 384x216-viewport. Test op een Android 15/16-toestel of de touch-knoppen en het titelmenu niet onder systeembalken vallen.
- **Gradle-build** is nodig voor AAB (en voor `target_sdk`): de preset heeft `use_gradle_build=true` en `export_format=1`.
  `build_aab.sh` installeert het buildtemplate in `android/build` (staat in `.gitignore`).
- Limieten: basis-AAB <= 200 MB (ruim voldoende); `versionCode` <= 2,1 miljard.

## 4. Lokaal bouwen (keystore uit omgevingsvariabelen)

Nodig: Godot-binary + exporttemplates van **dezelfde** versie, JDK 17+, Android SDK (platform-tools, build-tools, platform voor targetSdk), en je **upload-keystore** (buiten de repo bewaren; `*.keystore`, `*.jks` en `*.aab` staan in `.gitignore`).

```bash
export GODOT=/pad/naar/Godot_v4.5-stable_linux.x86_64     # 4.5+ zie §3
export JAVA_HOME=/pad/naar/jdk-17   ANDROID_HOME=/pad/naar/android-sdk
export ANDROID_KEYSTORE_PATH=/pad/naar/upload.keystore
export ANDROID_KEY_ALIAS=...        ANDROID_KEYSTORE_PASSWORD=...
export ANDROID_KEY_PASSWORD=...     # optioneel; standaard gelijk aan het keystore-wachtwoord
tools/release/build_aab.sh --check-env   # alleen de omgeving controleren
tools/release/build_aab.sh               # > build/release/sapientia-v<naam>-<code>.aab
```

Het script:
- controleert eerst `bump_version --check` (versie overal gelijk, changelog-kopje aanwezig) en de omgeving; bij een gat meldt het alleen de **naam** van wat ontbreekt;
- zet de waarden alleen voor het Godot-proces als `GODOT_ANDROID_KEYSTORE_RELEASE_*` (nooit als argument, nooit in `export_presets.cfg`);
- schrijft de Godot-uitvoer naar `build/release/export.log` en toont bij een fout alleen de laatste regels, met de geheimen vervangen door `***`;
- gebruikt geen `set -x`, print geen wachtwoord, alias of pad;
- controleert daarna de handtekening (`jarsigner -verify`), dat er alleen `arm64-v8a` in zit, en toont (als `bundletool` aanwezig is) de `targetSdkVersion`.

Handmatig nacontroleren: `bundletool dump manifest --bundle=build/release/sapientia-v0.20-22.aab | grep -i sdkversion`.

**Signing**: gebruik **Play App Signing** (standaard bij nieuwe apps). De keystore die je hier gebruikt is dan alleen de *upload-sleutel*; Google bewaart de echte app-sleutel.
Maak een back-up van de upload-keystore + wachtwoorden op een veilige plek (wachtwoordmanager); verlies je hem, dan moet je een reset bij Play Support aanvragen.
Commit nooit een keystore, wachtwoord of `.env`; `--aabtest` controleert dat de `keystore/*`-velden in de presets leeg zijn.

## 5. Pakketnaam (Dennis kiest)

De pakketnaam is na de eerste upload **permanent** (kan nooit meer wijzigen en moet uniek zijn op heel Google Play). Regels: minstens twee delen gescheiden door punten, elk deel begint met een letter, alleen letters/cijfers/underscores.

Huidig: `com.dennis.rpgprototype` (alle presets). Voorstel:

| Optie | Pakketnaam | Voor | Tegen |
|---|---|---|---|
| A (aanbevolen) | `com.dennis.sapientia` | zelfde prefix, geen domein nodig, "prototype" verdwijnt uit de Play-URL | nieuwe app-identiteit: sideload-APK's en hun saves worden niet overgenomen |
| B | `app.sapientia.rpg` (of een ander domein dat Dennis bezit) | netjes en merkgebonden | alleen verstandig met een eigen domein; anders kun je later geen eigendom aantonen |
| C | `com.dennis.rpgprototype` behouden | bestaande APK's worden bijgewerkt, saves blijven | "rpgprototype" blijft voor altijd in de store-URL en in Play-statistieken |

Gevolgen van wijzigen (A of B): (1) `package/unique_name` aanpassen in de drie Android-presets; (2) de bestaande tests `--autotest` en `--menutest` hebben het pakket vastgelegd (`com.dennis.rpgprototype`) en moeten dan **door RPG Forge** worden aangepast, dat valt buiten deze PR; (3) testers krijgen een tweede app naast de oude APK en beginnen met een leeg `user://` (de speelsaves staan in de app-private map van het oude pakket); (4) `user_data_backup/allow=false` staat uit, dus er is ook geen cloud-herstel.
Deze PR laat de pakketnaam **ongewijzigd** (`com.dennis.rpgprototype`) tot Dennis kiest.

## 6. Store-listing-checklist

Taal van de listing: **Engels** (hoofdtaal en spel zijn Engels); Nederlands optioneel erbij.

App-setup (Play Console > Dashboard > Set up your app):
- [ ] Ontwikkelaarsaccount aangemaakt en geverifieerd (identiteit, adres, telefoon, betaalprofiel); accounttype bepaald (zie §7).
- [ ] App aangemaakt: naam **SAPIENTIA** (max. 30 tekens), standaardtaal en categorie **Game > Role Playing**, gratis, geen advertenties.
- [ ] Pakketnaam gekozen (§5) en AAB geüpload met **Play App Signing**.
- [ ] Contact: e-mailadres (zichtbaar), optioneel website en telefoon.
- [ ] **Privacybeleid-URL** (verplicht zodra de app internet gebruikt; de AAB heeft `INTERNET` voor online co-op via de relay). Beschrijf wat de relay ziet (kamercode, spelersnaam, spelverkeer) en dat de sessielog alleen lokaal blijft.
- [ ] **Data safety**-formulier ingevuld (geen account, geen advertenties, geen verkoop van data; netwerkverkeer van co-op in transit versleuteld? controleer `relay/README.md` en gebruik `wss://`).
- [ ] **Content rating** (IARC-vragenlijst): fantasy-geweld in turn-based gevechten, geen gokken, geen user-generated content, online interactie met vaste speler-limiet (relay).
- [ ] **Target audience** (leeftijdsgroep, niet specifiek voor kinderen kiezen tenzij nodig) en **Ads**-verklaring (nee).
- [ ] **App access**: geen inlog nodig, alles speelbaar zonder instructies.
- [ ] Verklaringen: Advertising ID (nee), Financial features (nee), Health (nee), Government (nee), News (nee).
- [ ] Landen/regio's en prijs (gratis).

Store-listing (alle teksten Engels):
- [ ] Korte beschrijving (max. 80 tekens) en volledige beschrijving (max. 4000 tekens), consistent met `docs/lore/CANON.md` (geen spoilers van de twist).
- [ ] **App-icoon 512x512 PNG** (max. 1 MB, geen alpha-rand) - art van RPG ART.
- [ ] **Feature graphic 1024x500** - art van RPG ART.
- [ ] **Screenshots** telefoon: minimaal 2, liefst 4-8 (16:9 of 9:16, 320-3840 px per zijde); uit `--shots=` of echte toestellen, in 384x216-pixelstijl opgeschaald.
- [ ] Optioneel: promo-video (YouTube-URL), tablet-screenshots (7"/10").
- [ ] Release notes per upload (max. 500 tekens per taal), afgeleid van `CHANGELOG.md`.
- [ ] Adaptief launcher-icoon (foreground/background 432x432, optioneel `main_192x192`) in de presets; nu `""` = Godot-standaard `icon.png`. Art van RPG ART.

Technisch voor elke upload:
- [ ] `tools/release/bump_version --check` groen, changelog ingevuld, `versionCode` hoger dan alles wat al is geüpload.
- [ ] `--aabtest` en alle andere suites groen (CI).
- [ ] AAB gebouwd met `build_aab.sh`, `jarsigner`-controle OK, alleen arm64-v8a, targetSdk 36.
- [ ] Getest op een echt toestel (Android 15/16) en op een 16 KB-emulator of -toestel.
- [ ] Pre-launch report in Play Console bekeken (crashes, toegankelijkheid, veiligheid).

## 7. Persoonlijk account: 12 testers x 14 dagen gesloten test

Geldt voor **persoonlijke** ontwikkelaarsaccounts die na **13 november 2023** zijn aangemaakt (organisatie-accounts zijn vrijgesteld, maar vragen een D-U-N-S-nummer en bedrijfsverificatie).
Productie en pre-registratie in Play Console blijven uitgeschakeld tot aan de eis is voldaan
([bron](https://support.google.com/googleplay/android-developer/answer/14151465)):

- Voer een **gesloten test** (closed testing) uit met **minimaal 12 testers** die **14 dagen onafgebroken** zijn opt-in. (Het getal was 20; Google verlaagde het eind 2024 naar 12.)
- Een tester die zich tussentijds uitschrijft of de app verwijdert, kan de teller breken: zorg voor een buffer van **15-20 testers** en houd ze tot de goedkeuring opt-in.
- Daarna: **Apply for production** in het Dashboard, met vragen over de test, de app en de productie-gereedheid. Beoordeling duurt doorgaans zeven dagen of korter; Google kan om extra testen vragen bij te weinig testers of te weinig betrokkenheid.
- Bij elke nieuwe app geldt de eis opnieuw.

Stappen:
- [ ] Console: **Test and release > Testing > Closed testing** > track aanmaken (bv. "WM1 beta") en de AAB uploaden (met release notes).
- [ ] Testers toevoegen via een Google Group of een lijst e-mailadressen (Google-account, Android-toestel); opt-in-link delen.
- [ ] Elke tester opent de link, meldt zich aan en **installeert via Play**; controleer in de Console dat het aantal >= 12 blijft.
- [ ] Gedurende de 14 dagen: feedback verzamelen en bij een fix een nieuwe AAB met hogere `versionCode` in dezelfde track zetten (testers blijven opt-in).
- [ ] Houd bij wat er getest en verbeterd is (nodig voor de productie-aanvraag): bugs, versies, feedback.
- [ ] Na dag 14 en >= 12 testers: **Apply for production**; testers niet wegsturen tijdens de beoordeling.

Planning (afhankelijk van Dennis): de klok loopt pas vanaf het moment dat 12 testers zijn opt-in; Dennis moet dus de testers eerst werven. Dit is geen taak voor een agent.

## 8. CI-voorstel: AAB-job (alleen voorstel, niet toegevoegd)

Deze PR wijzigt `.github/workflows/` **niet**. Voorstel voor RPG Forge: een nieuwe, handmatige workflow `build-aab.yml`, naar het model van `build-apk.yml`
(zelfde secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; zie `docs/BUILDS.md`):

```yaml
name: build-aab

on:
  workflow_dispatch:

concurrency:
  group: build-aab-${{ github.ref }}
  cancel-in-progress: true

env:
  GODOT_VERSION: 4.5-stable          # 16 KB-pagina's: Godot 4.5+ (zie §3)
  GODOT_TEMPLATES_DIR: 4.5.stable
  GODOT: ${{ github.workspace }}/.godot-bin/Godot_v4.5-stable_linux.x86_64

jobs:
  aab:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      # Godot-binary en exporttemplates: dezelfde cache- en download-stappen als build-apk.yml
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 17 }
      - uses: android-actions/setup-android@v3
        with:
          packages: platform-tools platforms;android-36 build-tools;36.0.0
      - name: Versie-check
        run: python3 tools/release/bump_version --check
      - name: Bouw AAB
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          export ANDROID_KEYSTORE_PATH="$RUNNER_TEMP/upload.keystore"
          printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$ANDROID_KEYSTORE_PATH"
          tools/release/build_aab.sh
          rm -f "$ANDROID_KEYSTORE_PATH"
      - uses: actions/upload-artifact@v4
        with:
          name: sapientia-aab
          path: build/release/*.aab
          retention-days: 14
```

Uitgangspunten: alleen `workflow_dispatch` (nooit automatisch op `main`), het artifact is het enige resultaat (uploaden naar Play blijft handwerk, eerst naar de gesloten test), `build_aab.sh` is dezelfde route als lokaal, en secrets komen alleen als omgevingsvariabelen in die ene stap.
Bij een Godot-versie boven 4.3 hoort ook de matrix van `tests.yml` mee te gaan; dat is een aparte beslissing.

Tweede voorstel: voeg `aabtest` toe aan de matrix in `.github/workflows/tests.yml` (de suite heeft alleen `python3` en `bash` nodig en draait in een paar seconden).

## 9. Open punten voor RPG Forge / Dennis

- Godot-versie voor de release-AAB (4.5+ voor 16 KB; zie §3), met daarbij een nieuwe run van alle suites.
- Pakketnaam kiezen (§5) en de bijbehorende testwijziging (`--autotest`, `--menutest`).
- Privacybeleid hosten (bv. GitHub Pages) en Data safety invullen (relay).
- Upload-keystore aanmaken en veilig bewaren; secrets in GitHub zetten als de CI-job er komt.
- Echte art van RPG ART: store-icoon 512x512, feature graphic 1024x500, screenshots, adaptief icoon (foreground/background 432x432).
- 12 testers werven vóór de 14-daagse gesloten test.
