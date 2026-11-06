# Overdracht aan het agent-team — 6 nov 2026, 05:40

Van: Claude (sessie 5 nov, met push/merge-uitzondering van Dennis voor `Sapientia-RPG` en de site-repo).
Voor: de agents die het werk oppakken. Lees eerst `docs/release/LAUNCH_PLAN.md` en `docs/release/FINISH_LOG.md`.

## 1. Waar alles staat

| Wat | Waar | Stand |
|---|---|---|
| Werkbranch | `finish/wm1` | `b2b1dbb`; 10 commits vóór op `main` (`0b30e5f`). `main` NIET aanraken tot Dennis zegt mergen. |
| Open PR | #366 "Art R1: masterpalet.gpl, palet_check + CI-waarschuwing" → `finish/wm1` | Van het team zelf. CI 104/104 groen, `mergeable_state: clean`. Ik heb hem niet gemerged: hij is van jullie. |
| Testbuild web | https://eazydstudio.com/play/ | `finish/wm1` @ `7fce674` (zonder #367/#368). Site-repo `krelegerdennis-collab/eazydstudio`, map `play/sapientia-24cbe520/`. Homepage-iframe staat nog op de oude demo (`sapientia-f0ad89c0`); alleen wisselen als Dennis het zegt. |
| Testbuild APK | Actions-run 41947511666 (`build-apk`, debug) | `finish/wm1` @ `5cb270c`. |
| Privacy policy | https://eazydstudio.com/privacy/#sapientia | Live. Dit is de URL voor de Play Console. |
| Scorekaart | `docs/release/FINISH_LOG.md` | Cijfers van Dennis staan er nog NIET in; hij heeft nog niet gespeeld. |

Lokaal bij Dennis: `Desktop\SAPIENTIA\Game\Sapientia-RPG` stond op `cd156d77` (ver achter); eerst `git pull` voordat daar iets wordt gecommit. `Desktop\SAPIENTIA\Tools\SFX genereren.bat` draait `tools/sfx/gen_sfx.py` in WSL.

## 2. Wat er gedaan is op `finish/wm1` (5 nov)

Alle PR's squash-gemerged na volledige groene CI. Geen gameplay-wijzigingen, geen scènes, geen art.

| PR | Inhoud |
|---|---|
| #359 (op `main`) | `LAUNCH_PLAN.md`, checklist fase 1, `tools/sfx/` (gen_sfx.py, cues_wm1_batch1.json: 67 cues / 112 wavs). |
| #360 R1 | 24 unieke beschrijvingen Diepe Grot-uitrusting; bestiarium-tekst bazen 10-90 (canon 25/50/75/99 ongewijzigd); 20 grot-briefjes; respawn-tekst "The Current pulls you back..."; ECHO-hubregels in stem; tests aangepast (checkpoint, autotest, updatetest). |
| #361 R4 | KO door gif/brand gemeld (`_report_kos` na ticks); CI-matrix 79 → 102 suites; `savehardeningtest` (drift-vlag), `sessiefixtest` (RESULT-regel). |
| #362 R1b | Wilgendal: Mara Hammond (pantser), Pell (accessoires), Ysolde (magie); tweede zin per NPC. |
| #363 R4b | Zingend Meel per bezoek overleeft save/load (`molen_meel_bezoek` in story_flags, gewist in `map.gd` bij niet-load entry). Test deel F. |
| #364 R1c | Koopman: variatie bezoek 2/3/5/6/7, nabespreking na token; fase 2 houdt de filter-regel (H13-eis `wm1releasetest`). |
| #365 | CHANGELOG Unreleased + "Bekend (WM1-release)". `bump_version --check` OK; GEEN bump gedaan. |
| #367 | Battle Style-uitleg en Inktwurm-tutorial: "bazen blijven turn-based" weg (Golem is realtime in Action). |
| #368 R5 | `wm1_perf_budget.gd` opnieuw afgeleid uit `--wm1frametest` op `7fce674`; `archief_2_v1_entree` en `archief_2_warper` schommelen per run → draw_avg-grens = draw_max. |
| docs | `FINISH_LOG.md`, `STORE_LISTING.md` (store-teksten EN, spoilervrij, benodigde graphics, data-safety). |

Site-repo: PR #1 (webbuild), #2 (privacy), #3 (webbuild 7fce674) gemerged.

## 3. Beslissingen van Dennis (5 nov) — niet opnieuw vragen

- Einddoel Google Play; eerst web op eazydstudio.com/play (statische site, repo `eazydstudio`). Gedaan.
- SFX zelf maken met de offline stack (ComfyUI + Stable Audio Open 1.0, WSL). Placeholders zijn een blocker.
- Geen deadline. Scope = WM1 content-lock. Relay/online, WM2, Kael v4, crafting, Handelskamer: uit.
- Agents mogen `TODO(verhaal)`-stubs in WM1 invullen zolang de canon-kern staat. Core-zin "The story of H-6 ends here.", canon-scènes 1-3, opening, Zingend Graan: niet aanraken.
- Masterpalet moet in de repo (#366 doet dat).
- Pakketnaam: voorstel `com.eazydstudio.sapientia` — NOG NIET besloten (nu `com.dennis.rpgprototype`, permanent na eerste upload).

## 4. Wat nu open staat, op volgorde

1. **#366 mergen** (jullie PR, groen). Daarna palet-audit draaien met het echte masterpalet; mijn meting met `sap75.gpl` (239/1175 buiten palet) is daarmee achterhaald.
2. **Dennis laten spelen**: web of APK, cijfers in de scorekaart, grootste ergernis. Dat bepaalt de volgende ronde. Vraag het hem één keer, kort.
3. **SFX**: eerste run `tools/sfx/gen_sfx.py --cue menu_click --seeds 2` (of de .bat) is nog NOOIT gedraaid. ONVERIFIED: Stable Audio node-namen (`ConditioningStableAudio`, `EmptyLatentAudio`, `VAEDecodeAudio`, `SaveAudio`), WSL-distronaam `Ubuntu`, of de modellen van 3 nov compleet zijn. `check_algemene_sfx.py` eist max 0,60 s; voor stingers (level_up, golem_death, battle_start) te kort → voorstel per categorie een maximum (ui 0,6 / gevecht 1,0 / bazen 3,0 s), zie `tools/sfx/README.md`.
4. **Perf ONVERIFIED**: `--wm1budgettest` meet `dorp_wilgendal` op 1679 scene-nodes (budget 838 = exact 2×+3), `woud_beek` 474 draw calls (frametest: 124), `huis_wilgendal` 135 nodes (39). Lijkt een volgorde-lek in de suite (kamer dubbel geïnstantieerd), kan echt zijn. Niet in CI. Eerst `scripts/tests/wm1_budget_tests.gd` op dubbele instantiatie nalopen voordat iemand kamers gaat "optimaliseren".
5. **Webbuild bijwerken** na #366: export Web (Godot 4.3, preset "Web") → `play/sapientia-<sha8>/` in de site-repo, `play/index.html` omzetten, oude testmap weg. Pages-deploy vanuit het game-repo faalt op branches ≠ `main` (environment-regel), daarom via de site-repo. Build is 83 MB pck + 35 MB wasm (video 30 MB, bgm 32 MB); een "Web demo"-preset met exclude is voorgesteld, niet besloten.
6. **Fase 8 voorbereiding** (pas na cijfers ≥ 9 en SFX): pakketnaam-besluit, keystore-secrets, `bump_version minor` → 0.21/23, graphics (icoon 512, feature 1024×500, 4-8 screenshots liggend), content rating, data safety "No data collected".

## 5. Regels die ik heb gevolgd (en jullie ook)

- Alleen PR's naar `finish/wm1`; squash-merge; alleen na volledige groene CI (nu 102-104 checks, ±1 uur wachtrij).
- Nooit force-push. Commit `5cb270c` is GitHubs eigen squash-merge (committer `noreply@github.com`); de hook klaagt erover, laat hem staan.
- Godot's `.import`/`.translation`-bestanden na een lokale run NIET committen (`git checkout -- assets export && git clean -fd assets export`).
- `git config user.email noreply@anthropic.com`, `user.name Claude` in de clone (hook-eis).
- Nooit mergen naar `main`, nooit homepage-demo wisselen, nooit pakketnaam wijzigen zonder Dennis.
- Antwoorden aan Dennis: kort, FACT / BESLISSING / VOORSTEL / ONVERIFIED, eerst voorstel dan "go".

## 6. Lokaal testen (zoals ik het deed)

```
# Godot 4.3-stable linux x86_64 + export templates (web_*) in ~/.local/share/godot/export_templates/4.3.stable
export GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
xvfb-run -a $GODOT --headless --path . --import          # 1x, ±10 min
.github/scripts/run_suite.sh <suite>                       # logs in testlogs/<suite>.log
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --wm1frametest | grep ^WM1FRAME   # perf-meting
xvfb-run -a $GODOT --headless --path . --export-release Web export/web/index.html           # webbuild
```
Snelle rookset na tekstwijzigingen: `storytest woudtest koopmantest wilgendaltest checkpointtest updatetest autotest wm1releasetest`.
