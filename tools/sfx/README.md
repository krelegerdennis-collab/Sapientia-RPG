# tools/sfx — SFX uit de offline AI-stack

- `gen_sfx.py`: genereert via ComfyUI + Stable Audio Open 1.0 (WSL op de laptop), converteert naar mono 22050 Hz 16-bit, installeert gekozen wavs en ruimt `tools/placeholders_algemene_sfx.txt` op. Zie de docstring.
- `cues_wm1_batch1.json`: 67 cues (WM1-rookroute) met Engelse prompts, lengte en trim.
- `out/` (niet committen, staat in .gitignore van deze map): kandidaten per cue; `out/kies/` = jouw keuze.

Stappen: ComfyUI starten → `python3 tools/sfx/gen_sfx.py --seeds 3` → kiezen → `--install` → `python3 tools/check_algemene_sfx.py` → `godot --headless --import` → PR met label `wm1-polish`.

Let op: `check_algemene_sfx.py` eist nu `MAX_DUR = 0.60`. Voor stingers (level_up, golem_death, battle_start) is dat te kort; voorstel voor RPG Forge: per categorie een maximum (ui 0.6 s, gevecht 1.0 s, bazen/sapientia 3.0 s) en `audio_manager.gd` controleren op polyfonie-limiet.
Licentie: Stable Audio Open 1.0 = Stability AI Community License (commercieel gratis tot 1M USD omzet/jaar). Noteer herkomst + seed per bestand (zoals Hoshimi `assets/HERKOMST.md`).
