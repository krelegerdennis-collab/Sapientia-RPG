# CI-builds (APK en Web)

GitHub Actions-workflows om exporten te maken zonder de Godot-editor. **APK** draait alleen via **Run workflow** (workflow_dispatch). **Web** exporteert en publiceert naar GitHub Pages bij **push naar `main`** of handmatig via **Run workflow**.

## Workflows

| Workflow-bestand | Naam in Actions | Artifact | Inhoud |
|---|---|---|---|
| `.github/workflows/build-apk.yml` | `build-apk` | `sapientia-apk` | Eén `.apk` (`build/sapientia.apk` op de runner) |
| `.github/workflows/build-web.yml` | `build-web` | `sapientia-web` | Map `export/web/` (Godot Web-export, o.a. `index.html`) |

Artifact-retentie: **14 dagen**.

### APK (`build-apk`)

1. GitHub → **Actions** → workflow **build-apk** → **Run workflow**.
2. Optioneel **build_type**:
   - **release** (standaard): release-APK, ondertekend met de release-keystore uit repository secrets.
   - **debug**: debug-APK met een op de runner gegenereerde debug-keystore (geen release-secrets nodig).
3. Na afloop: onder **Artifacts** → **sapientia-apk** downloaden.

Export gebruikt de bestaande preset **Android** uit `export_presets.cfg` (platform Android, arm64-v8a + armeabi-v7a). Het uitvoerpad in de preset (`../rpg_prototype.apk`) wordt in CI **niet** gebruikt; de workflow exporteert naar `build/sapientia.apk` via de Godot CLI.

Preset **Android arm64** (alleen arm64) blijft beschikbaar in de editor; deze workflow is niet op die preset gezet.

### Web (`build-web`)

1. GitHub → **Actions** → workflow **build-web** → **Run workflow** (of automatisch na merge op `main`).
2. Artifact **sapientia-web** bevat de map `export/web/` (preset **Web**, `export_path` in `export_presets.cfg`).
3. **GitHub Pages** (bron: GitHub Actions): na een geslaagde run staat de build op  
   https://krelegerdennis-collab.github.io/Sapientia-RPG/  
   Preset **Web** heeft `variant/thread_support=false` (geen COOP/COEP op Pages nodig).

De workflow maakt `export/web/` aan als die map nog niet bestaat (vereiste van Godot vóór export).

## Secrets (alleen release-APK)

Zet onder **Settings → Secrets and variables → Actions** (repository secrets, niet in de code):

| Secret | Gebruik |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Release-keystore als base64 (één regel, geen PEM-headers) |
| `ANDROID_KEYSTORE_PASSWORD` | Wachtwoord van de keystore |
| `ANDROID_KEY_ALIAS` | Key-alias |
| `ANDROID_KEY_PASSWORD` | Wachtwoord van de key |

De workflow decodeert de keystore naar een tijdelijk bestand op de runner en zet Godot-omgevingsvariabelen (`GODOT_ANDROID_KEYSTORE_RELEASE_*`). Waarden worden niet gelogd.

Ontbreken een of meer secrets bij **build_type = release**, dan faalt de run met een duidelijke foutmelding. **debug** heeft deze secrets niet nodig.

### Keystore als base64 encoderen (lokaal, eenmalig)

```bash
base64 -w0 /pad/naar/release.keystore
```

Plak de output in `ANDROID_KEYSTORE_BASE64`. Commit **nooit** het `.keystore`-bestand zelf.

## Wat de runners installeren

- **Godot 4.3-stable** (headless Linux-binary) + **export templates** 4.3.stable (gecachet).
- **APK extra:** OpenJDK **17**, Android SDK (platform-tools, platform android-34, build-tools 34.0.0), Godot-editorinstellingen in `~/.config/godot/editor_settings-4.3.tres` (alleen op de runner).

`export_presets.cfg` en projectversies worden door deze workflows **niet** gewijzigd.

## Lokaal hetzelfde doen (kort)

Zie ook `README.md` § Android-export. Voor release zonder wachtwoord in het project:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/pad/naar/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<store-wachtwoord>
export GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD=<key-wachtwoord>
godot --headless --path . --export-release "Android" build/sapientia.apk
```

Web:

```bash
mkdir -p export/web
godot --headless --path . --export-release "Web"
```
