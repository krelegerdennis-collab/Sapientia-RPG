# Android-levenscyclus: pauze/hervatten, geluid, framerate, accu, schermranden

Branch `agent/cursor/android-lifecycle`. Code: `scripts/core/app_lifecycle.gd` (autoload `AppLifecycle`),
suite `--lifecycletest` (`scripts/tests/lifecycle_tests.gd`). Raakt bestaande bestanden maar op twee regels
(`project.godot`: autoload; `scripts/game_state.gd`: registratie van de suite).

## 1. Exportinstellingen: cutout en edge-to-edge

Gecontroleerd in `export_presets.cfg` (Godot 4.3, preset `Android` en `Android arm64`):

| instelling | waarde | betekenis |
|---|---|---|
| `screen/immersive_mode` | `true` (beide presets) | systeembalken verborgen, spel tekent over het hele scherm |
| `gradle_build/use_gradle_build` | `false` | prebuilt template; geen eigen manifest/thema |
| `gradle_build/target_sdk` | leeg | standaard van de 4.3-template |
| `display/window/handheld/orientation` (project) | `4` (sensor-landscape) | de cutout wisselt van kant als het toestel draait |
| `display/window/stretch` (project) | `viewport` + `expand` | 384x216; 19,5:9 / 20:9 krijgt extra breedte |

Bevindingen:
- Godot 4.3 heeft **geen** exportoptie voor display cutout of edge-to-edge (voor zover bekend horen die bij
  latere Godot-versies; hier niet te verifiëren zonder templates); de cutout-modus komt uit de Android-template. `immersive_mode = true` staat al aan, dus
  `export_presets.cfg` is **niet** aangepast. De test `--lifecycletest` bewaakt deze waarden (immersive in
  elke Android-preset, landscape, stretch, geen signing-velden gevuld).
- `DisplayServer.get_display_safe_area()` en `get_display_cutouts()` (waar #219/#230 van uitgaan) geven op de
  CI/PC altijd het hele scherm en geen cutouts. **Echte waarden zijn alleen op een toestel te krijgen.** Er zijn
  hier geen export-templates en geen toestel, dus dit is niet op hardware geverifieerd.
- Als RPG Forge `target_sdk` naar 35 of hoger zet (Android 15+ dwingt edge-to-edge af), moet de safe-area-code
  opnieuw op een toestel bekeken worden; dat is nu niet aan de orde.

### Echte waarden uitlezen (voor #219/#230)
`AppLifecycle.display_info()` geeft venster, scherm, veilige rechthoek, cutouts, verversingssnelheid, dpi en
viewport. Op een telefoon wordt dat bij de start, na het draaien (venstergrootte verandert) en na hervatten
**één keer per wijziging** geprint en, als de SessieLog aan staat, als regel `scherm` weggeschreven:

```bash
adb logcat -s godot | grep "AppLifecycle\] display"
```

Verwacht op een toestel met camera-gat, in landscape: `cutouts` niet leeg, `safe_area` met x > 0 aan de kant van
het gat, `window` = `screen` (volledig scherm). Staat daar overal `[0,0,breedte,hoogte]` en `cutouts: []` op een
toestel dat wel een gat heeft, dan krijgt de app de cutout niet door en moet de template-instelling (gradle-build
met `layoutInDisplayCutoutMode = shortEdges`) bekeken worden; stuur dan de regel mee in het issue.

## 2. Pauze en hervatten

| gebeurtenis (Android) | effect |
|---|---|
| `FOCUS_OUT` (alleen telefoon: meldingenbalk, telefoontje) | achtergrond-modus aan |
| `PAUSED` | pauze-save door `GameState` (ongewijzigd), daarna achtergrond-modus aan |
| `RESUMED` | achtergrond-modus uit zodra ook de focus terug is |
| `FOCUS_IN` | idem, andere volgorde |

Achtergrond-modus: `Engine.max_fps` naar `BACKGROUND_FPS` (10; was de gewone cap, `run/max_fps = 60`, ook als
die 0 is), alle spelende `AudioStreamPlayer*` op `stream_paused` (de afspeelpositie blijft behouden). Bij
terugkeren gaat alles terug en wordt **alleen** hervat wat wij zelf pauzeerden. Twee redenen (focus en pauze)
tellen samen: de modus eindigt pas als beide weg zijn, in elke volgorde. Op desktop (`FOCUS_OUT` zonder mobiel
kenmerk) gebeurt niets, zodat alt-tab het spel niet dempt. Er is geen extra pauze van de speltijd of
`get_tree().paused`; Android stopt `_process` zelf tijdens `PAUSED`.

### Opslaan (besluit Dennis, ongewijzigd)
- De verplichte pauze-save (commit `0e9178b`, reden `"achtergrond"`) blijft zoals hij was: hij negeert alleen de
  optie *Autom. opslaan*, niet de blokkades (gevecht, mapwissel, dialoog, cutscene, halve stap).
- Er komt **geen** extra autosave bij suspend of hervatten. `AppLifecycle` schrijft nooit een save; de test
  controleert dat `RESUMED`/`FOCUS_IN`/focuswissel op desktop niets schrijven en dat `AUTOSAVE_REASONS` precies
  `["map", "achtergrond"]` blijft. De bestaande `--savehardeningtest` (deel D) en `--menutest` blijven de
  dekking voor de save zelf.

## 3. Accu: low-processor-modus in menu's

Zolang een menu open is (titelscherm, veldmenu, alle `menu_screen.gd`-afgeleiden, `save_prompt`, `load_screen`,
bestiarium; lijst `AppLifecycle.MENU_SCRIPTS`) staat `OS.low_processor_usage_mode` aan: de engine tekent alleen
nog als er iets verandert en slaapt tussen frames; `_process` blijft draaien. Zodra het laatste menu sluit gaat
het uit; in de achtergrond-modus staat het ook uit. Menu's worden herkend via `node_added` en de scriptketen
(`get_base_script`), dus een nieuw menu dat van `menu_screen.gd` erft werkt vanzelf.

- Uitzetten: project-instelling `sapientia/perf/low_processor_menus = false` (of `set_low_processor_enabled(false)`).
- In testruns (user-args na `--`) staat het standaard **uit**: screenshots wachten op `frame_post_draw`, en dat komt
  niet als de engine een ongewijzigd beeld overslaat.
- Afhankelijkheid voor menu-art: alles wat beweegt moet zelf een redraw vragen (`queue_redraw`, tween, `modulate`).
  De huidige shaders (`assets/shaders/`) gebruiken geen `TIME`; komt er ooit een menu-shader die op `TIME`
  animeert, dan bevriest die in deze modus en moet dat menu een eigen uitzondering krijgen.
- **Niet gemeten op een toestel.** De winst hangt af van hoeveel een menu stilstaat; meet bij een volgende
  toestelronde accu of CPU-tijd (bv. 5 min titelscherm met en zonder de project-instelling).

## 4. Framerate-cap

`run/max_fps = 60` blijft: op 90/120 Hz-toestellen is dat een bewuste halvering, ruim genoeg voor pixel-art op
384x216 en veel zuiniger. Er is niets aan de gewone cap veranderd (perf-werk in #216/#227 blijft ongemoeid).

## 5. Overlap met #219/#230 en #216/#227
Alleen nieuwe bestanden (`app_lifecycle.gd`, `lifecycle_tests.gd`, dit document) plus één autoload-regel in
`project.godot` en één registratie-regel in `game_state.gd` (`_ready`, bij de andere suites). Geen wijziging in
`audio_manager.gd`, `settings.gd`, `touch_controls.gd`, UI-schermen of `export_presets.cfg`. Safe-area-code uit #219/#230
kan `AppLifecycle.display_info()` of de logregel gebruiken zonder koppeling.

## 6. CI
Nieuwe suite: `lifecycletest` (83 PASS). Voorstel voor RPG Forge: voeg `lifecycletest` toe aan de matrix in
`.github/workflows/tests.yml` (niet aangepast in deze PR). Lokaal:
`GODOT=/pad/naar/godot .github/scripts/run_suite.sh lifecycletest`.
