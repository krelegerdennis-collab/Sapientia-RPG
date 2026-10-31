# Galaxy S25 — on-device performance-check (WM1)

Kort checklist voor Dennis/RPG Forge (Fase 4). Doel: **60 fps** (`run/max_fps=60` in `project.godot`) ⇒ budget **16,667 ms** per frame. Headless-baseline: `docs/perf/wm1_baseline.md` (flag **RISK** / **WATCH**).

## Voorbereiding

| Stap | Actie |
|---|---|
| Build | Release-APK (primair) + optioneel debug voor `logcat`. |
| Telefoon | Galaxy S25, arm64, helderheid 100 %, batterij > 50 %. |
| Package | `com.dennis.rpgprototype` (controleer in export als dit verschilt). |
| Baseline | Noteer versie uit titel of `project.godot` `config/version`. |

## ADB verbinden

```bash
adb devices
adb shell am force-stop com.dennis.rpgprototype
adb install -r pad/naar/Sapientia-….apk
adb shell am start -n com.dennis.rpgprototype/com.godot.game.GodotApp
```

## Per scène meten (minstens 60 s lopen of vechten)

Prioriteit: alle rijen met **RISK** in `wm1_baseline.md`, plus wereldkaart, `dorp_wilgendal`, Donker Woud (mist/overlay), `woud_beek`, Archief 1-puzzel, berggrot, Archief 2-kas, `warper_hal`, één Action-gevecht.

1. Reset gfxinfo-statistiek, speel 60+ s op de kaart, dump:

```bash
adb shell dumpsys gfxinfo com.dennis.rpgprototype reset
# … spelen …
adb shell dumpsys gfxinfo com.dennis.rpgprototype framestats
```

2. Noteer uit de summary: **50th / 90th / 99th percentile** frame tijd (ms). **99th > 16,667 ms** ⇒ risico voor 60 fps; **> 100 ms** ⇒ hapering (behalve laad/video).

3. Geheugenpiek na 2 min op dezelfde kaart:

```bash
adb shell dumpsys meminfo com.dennis.rpgprototype | head -30
```

Let op `TOTAL` PSS; geen stijgende trend over 30 min spelen.

4. Godot-log (optioneel, debug-build):

```bash
adb logcat -c
adb logcat -s godot
```

## Gevechten

- Action-stijl: dodge, keten (3 slagen), opgeladen zware slag — minstens één gevecht op wereldkaart + één baas (Golem of Mender).
- Classic-stijl: kort check dat framerate vergelijkbaar blijft.

## Acceptatie (voorstel WM1_RELEASE_CHECKLIST)

| Metriek | Doel |
|---|---|
| Gemiddeld | ≥ 58 fps (~17,2 ms/frame) in normale kaarten |
| 1 % low | ≥ 45 fps (~22 ms) |
| Enkele frame | Geen > 100 ms buiten laden/video |
| Warmte | 30 min achter elkaar: geen duidelijke throttling |

Als headless **RISK** maar S25 groen blijft: noteer in issue/PR als geaccepteerd. Anders: performance-fix zonder gedragswijziging.

## Rapportage

Vul een korte tabel (scène | 99th ms | mem PSS | opmerking) en plak in het release-issue of `docs/release/WM1_RELEASE_CHECKLIST.md` Fase 4.
