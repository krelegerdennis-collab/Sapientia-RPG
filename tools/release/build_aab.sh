#!/usr/bin/env bash
# Lokale release-AAB voor de Play Store (preset "Android AAB" in export_presets.cfg).
#
# Keystore-gegevens komen UITSLUITEND uit omgevingsvariabelen; er wordt niets van geprint of opgeslagen
# (alleen de NAMEN van ontbrekende variabelen). Geen `set -x` gebruiken; de uitvoer van Godot gaat naar een
# logbestand en wordt bij een fout pas na redactie getoond.
#
# Verplicht:
#   ANDROID_KEYSTORE_PATH       pad naar het .keystore/.jks-bestand (upload-sleutel, buiten de repo bewaren)
#   ANDROID_KEY_ALIAS           alias van de sleutel
#   ANDROID_KEYSTORE_PASSWORD   wachtwoord van de keystore
# Optioneel:
#   ANDROID_KEY_PASSWORD        wachtwoord van de sleutel (standaard = ANDROID_KEYSTORE_PASSWORD)
#   GODOT                       Godot-binary (standaard `godot` in PATH)
#   JAVA_HOME, ANDROID_HOME     alleen nodig als de Godot-editorinstellingen nog geen SDK-paden hebben;
#                               het script maakt dan een minimaal editor_settings-bestand (zonder geheimen)
#   OUT_DIR                     uitvoermap (standaard build/release; wordt door .gitignore (*.aab) niet meegenomen)
#
# Gebruik (vanuit de projectmap, of waar dan ook):
#   tools/release/build_aab.sh              bouw build/release/sapientia-v<naam>-<code>.aab
#   tools/release/build_aab.sh --check-env  controleer alleen de omgeving (geen build, geen netwerk)
#
# Voorwaarden: Godot-exporttemplates van dezelfde versie als de binary, JDK 17+ en de Android SDK
# (platform-tools, build-tools, platform voor targetSdk). Zie docs/release/PLAY_STORE.md.
set -euo pipefail

cd "$(dirname "$0")/../.."
PRESET="Android AAB"
GODOT="${GODOT:-godot}"
OUT_DIR="${OUT_DIR:-build/release}"
CHECK_ONLY=0
case "${1:-}" in
	--check-env) CHECK_ONLY=1 ;;
	"") ;;
	*) echo "Gebruik: $0 [--check-env]" >&2; exit 2 ;;
esac

fouten=0
ok() { echo "OK         $1"; }
mist() { echo "ONTBREEKT  $1"; fouten=$((fouten + 1)); }
waarschuw() { echo "LET OP     $1"; }

# --- Versie (één bron: tools/release/version.json) -------------------------------------------------
if ! command -v python3 > /dev/null 2>&1; then
	mist "python3 (nodig voor tools/release/bump_version)"
	VERSION_NAME=""; VERSION_CODE=""
elif python3 tools/release/bump_version --check > /dev/null; then
	VERSION_NAME="$(python3 -c 'import json;print(json.load(open("tools/release/version.json"))["version_name"])')"
	VERSION_CODE="$(python3 -c 'import json;print(json.load(open("tools/release/version.json"))["version_code"])')"
	ok "versie $VERSION_NAME (code $VERSION_CODE) gelijk in bron, project.godot, presets en changelog"
else
	mist "versie niet gelijk aan de bron: draai 'tools/release/bump_version --check' voor details (of --sync)"
	VERSION_NAME=""; VERSION_CODE=""
fi

# --- Keystore uit de omgeving (waarden worden nooit getoond) ----------------------------------------
[ -n "${ANDROID_KEYSTORE_PATH:-}" ] && ok "ANDROID_KEYSTORE_PATH gezet" || mist "ANDROID_KEYSTORE_PATH"
if [ -n "${ANDROID_KEYSTORE_PATH:-}" ]; then
	[ -f "$ANDROID_KEYSTORE_PATH" ] && ok "keystore-bestand bestaat" || mist "keystore-bestand (ANDROID_KEYSTORE_PATH wijst niet naar een bestand)"
fi
[ -n "${ANDROID_KEY_ALIAS:-}" ] && ok "ANDROID_KEY_ALIAS gezet" || mist "ANDROID_KEY_ALIAS"
[ -n "${ANDROID_KEYSTORE_PASSWORD:-}" ] && ok "ANDROID_KEYSTORE_PASSWORD gezet" || mist "ANDROID_KEYSTORE_PASSWORD"
if [ -n "${ANDROID_KEY_PASSWORD:-}" ]; then
	ok "ANDROID_KEY_PASSWORD gezet"
else
	echo "INFO       ANDROID_KEY_PASSWORD niet gezet: ANDROID_KEYSTORE_PASSWORD wordt ook als sleutelwachtwoord gebruikt"
fi

# --- Godot en templates -----------------------------------------------------------------------------
GODOT_VERSION_FULL=""
if command -v "$GODOT" > /dev/null 2>&1; then
	GODOT_VERSION_FULL="$("$GODOT" --version 2> /dev/null | head -n 1 || true)"
	ok "Godot gevonden ($GODOT_VERSION_FULL)"
else
	mist "Godot-binary (zet GODOT=/pad/naar/godot)"
fi
TEMPLATE_VERSION="$(echo "$GODOT_VERSION_FULL" | sed -E 's/\.(official|custom_build|mono)(\..*)?$//')"
MAJOR_MINOR="$(echo "$TEMPLATE_VERSION" | cut -d. -f1-2)"
if [ -n "$MAJOR_MINOR" ]; then
	major="${MAJOR_MINOR%%.*}"; minor="${MAJOR_MINOR#*.}"
	if [ "$major" -lt 4 ] || { [ "$major" -eq 4 ] && [ "$minor" -lt 5 ]; }; then
		waarschuw "Godot $MAJOR_MINOR heeft geen 16 KB-pagina-ondersteuning in de templates; Google Play eist dat voor apps met targetSdk 35+ (zie docs/release/PLAY_STORE.md)"
	fi
fi
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_VERSION"
if [ -n "$TEMPLATE_VERSION" ]; then
	[ -f "$TEMPLATE_DIR/android_source.zip" ] && ok "export-templates $TEMPLATE_VERSION (android_source.zip)" \
		|| mist "export-templates $TEMPLATE_VERSION (verwacht $TEMPLATE_DIR/android_source.zip)"
fi

# --- Java en Android SDK -----------------------------------------------------------------------------
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-$MAJOR_MINOR.tres"
SDK_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -f "$SETTINGS" ] && grep -q 'export/android/android_sdk_path' "$SETTINGS" && grep -q 'export/android/java_sdk_path' "$SETTINGS"; then
	ok "Godot-editorinstellingen hebben SDK-paden"
elif [ -n "${JAVA_HOME:-}" ] && [ -n "$SDK_DIR" ]; then
	ok "JAVA_HOME en ANDROID_HOME gezet (editorinstellingen worden zo nodig aangemaakt)"
else
	mist "Java/Android SDK: zet JAVA_HOME en ANDROID_HOME, of stel de paden in via Godot Editor > Editor Settings > Export > Android"
fi

if [ "$fouten" -gt 0 ]; then
	echo "Omgeving niet in orde ($fouten punt(en)); geen build gestart." >&2
	exit 1
fi
if [ "$CHECK_ONLY" -eq 1 ]; then
	echo "Omgeving in orde."
	exit 0
fi

# --- Voorbereiding ------------------------------------------------------------------------------------
if [ ! -f "$SETTINGS" ] || ! grep -q 'export/android/android_sdk_path' "$SETTINGS"; then
	mkdir -p "$(dirname "$SETTINGS")"
	if [ ! -f "$SETTINGS" ]; then
		printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"
	fi
	{
		echo "export/android/java_sdk_path = \"$JAVA_HOME\""
		echo "export/android/android_sdk_path = \"$SDK_DIR\""
	} >> "$SETTINGS"
	echo "INFO       SDK-paden toegevoegd aan de Godot-editorinstellingen (geen geheimen)"
fi

# Gradle-build: het Android-buildtemplate komt in android/ (staat in .gitignore) en moet bij de Godot-versie passen.
if [ "$(cat android/.build_version 2> /dev/null || true)" != "$TEMPLATE_VERSION" ]; then
	rm -rf android/build
	mkdir -p android/build
	unzip -q -o "$TEMPLATE_DIR/android_source.zip" -d android/build
	touch android/build/.gdignore
	echo "$TEMPLATE_VERSION" > android/.build_version
	echo "INFO       Android-buildtemplate $TEMPLATE_VERSION geïnstalleerd in android/build"
fi

mkdir -p "$OUT_DIR"
AAB="$OUT_DIR/sapientia-v${VERSION_NAME}-${VERSION_CODE}.aab"
LOG="$OUT_DIR/export.log"
rm -f "$AAB" "$LOG"

redact() {
	python3 -c '
import os, sys
geheim = [os.environ.get(k, "") for k in ("ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_PASSWORD", "ANDROID_KEY_ALIAS")]
geheim = [g for g in geheim if len(g) >= 4]
for regel in sys.stdin:
    for g in geheim:
        regel = regel.replace(g, "***")
    sys.stdout.write(regel)
'
}

echo "Importeren..."
if ! timeout 900 "$GODOT" --headless --path . --import > "$LOG" 2>&1 < /dev/null; then
	echo "FOUT: import mislukt (laatste regels, geredigeerd):" >&2
	tail -n 30 "$LOG" | redact >&2
	exit 1
fi

echo "Exporteren ($PRESET)..."
set +e
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ANDROID_KEYSTORE_PATH" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEY_ALIAS" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASSWORD" \
GODOT_ANDROID_KEYSTORE_RELEASE_KEY_PASSWORD="${ANDROID_KEY_PASSWORD:-$ANDROID_KEYSTORE_PASSWORD}" \
	timeout 3000 "$GODOT" --headless --path . --export-release "$PRESET" "$AAB" > "$LOG" 2>&1 < /dev/null
code=$?
set -e
if [ "$code" -ne 0 ] || [ ! -s "$AAB" ]; then
	echo "FOUT: export mislukt (exitcode $code). Laatste regels van $LOG (geredigeerd):" >&2
	tail -n 40 "$LOG" | redact >&2
	exit 1
fi

# --- Controle (zonder geheimen te tonen) ---------------------------------------------------------------
echo "Klaar: $AAB ($(du -h "$AAB" | cut -f1))"
echo "sha256: $(sha256sum "$AAB" | cut -d' ' -f1)"
if command -v jarsigner > /dev/null 2>&1; then
	jarsigner -verify "$AAB" > /dev/null 2>&1 && ok "handtekening geldig (jarsigner)" || waarschuw "jarsigner kon de handtekening niet verifiëren"
fi
if command -v unzip > /dev/null 2>&1; then
	# eerst in een variabele: `grep -q` direct achter `unzip` geeft onder pipefail een vals negatief (SIGPIPE)
	INHOUD="$(unzip -l "$AAB" 2> /dev/null || true)"
	if grep -q 'lib/armeabi-v7a/' <<< "$INHOUD"; then
		waarschuw "AAB bevat armeabi-v7a; verwacht alleen arm64-v8a"
	elif grep -q 'lib/arm64-v8a/' <<< "$INHOUD"; then
		ok "alleen arm64-v8a-bibliotheken"
	else
		waarschuw "geen native bibliotheken in de AAB gevonden"
	fi
fi
if command -v bundletool > /dev/null 2>&1; then
	echo "targetSdkVersion in het manifest: $(bundletool dump manifest --bundle="$AAB" 2> /dev/null | grep -o 'targetSdkVersion[^ ]*' | head -n 1 || true)"
fi
