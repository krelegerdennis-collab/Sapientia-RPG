# LAUNCH-PLAN — WM1 naar web en Google Play

Basis: `main` op `a70f19a`, 4 nov 2026. Beslissingen van Dennis, 5 nov 2026. Hoort bij
`docs/release/WM1_RELEASE_CHECKLIST.md` (de acht fases) en `docs/release/PLAY_STORE.md` (fase 8).
Dit plan voegt de volgorde, de scope en de SFX-pipeline toe; het vervangt de checklist niet.

## Beslissingen (5 nov 2026)

| # | Beslissing | Gevolg |
|---|---|---|
| B1 | Einddoel is Google Play. Eerst een webversie op eazydstudio.com. | Fase 8 blijft Play; stap 2 hieronder komt vóór fase 2-7. |
| B2 | SFX worden zelf gemaakt met de offline AI-stack (ComfyUI + Stable Audio Open 1.0 in WSL). | Placeholders in `tools/placeholders_algemene_sfx.txt` zijn een blocker tot de pipeline in `tools/sfx/` draait. |
| B3 | Geen deadline: klaar als het klaar is. | Gates uit de checklist gelden hard; geen fase overslaan om tijd te winnen. |
| B4 | Scope = WM1 (content-lock 24 okt). | Relay/online co-op, WM2, Kael v4, crafting, Handelskamer, grade 4: niet voor launch. |

## Stappen

| Stap | Checklist-fase | Wat | Klaar als |
|---:|---|---|---|
| 1 | 1 Freeze | Tag `wm1-freeze` op `main`; alleen nog `wm1-bugfix` / `wm1-polish` / `wm1-cut`-PR's. Realtime Golem en Action-bazen worden afgerond zoals ze nu liggen, daarna niets nieuws. | Tag staat, CI groen, voortgangstabel in de checklist ingevuld. |
| 2 | (eigen) Web | `build-web` draaien, `export/web/` naar eazydstudio.com (map `/sapientia/` of iframe naar GitHub Pages). | Speelbaar vanaf een telefoonbrowser via de site. |
| 3 | 6 UX (audio) | SFX-pipeline: `tools/sfx/` (cue-lijst batch 1 = WM1-route, generatie via ComfyUI-API, conversie naar mono 22050 Hz 16-bit, zelfde bestandsnaam). Regels uit `tools/placeholders_algemene_sfx.txt` halen per vervangen bestand. | `algemene-sfx`-suite groen, geen placeholder op de rookroute. |
| 4 | 6 UX (audio) | BGM-manifest snoeien: 24 tracks → de 13 die bestaan; ontbrekende WM1-kaarten op een bestaande track. Kas-track evt. via ACE-Step 1.5. | Geen stille kaart in WM1. |
| 5 | 2 Art | Alleen placeholders die in de WM1-route zichtbaar zijn (`docs/PLAN.md` fase 1 + 2). Rest bewust geaccepteerd. | Fase 2-gate. |
| 6 | 3 + 4 | Stabiliteit (`--savefuzztest`, exportcontrole) en S25-perf (`tools/perf`, `docs/perf_wm1.md`). | 0 crash/softlock in de testroutes, perf-rapport S25. |
| 7 | 5 + 7 | Headless balans-sim, daarna playtest Dennis via `WM1_PLAYTEST.md` + `playtest_rapport.py --strict`. Fixronde alleen P0/P1. | Dennis geeft akkoord voor RC. |
| 8 | 8 Release | `bump_version minor` (0.21 / code 23), changelog, keystore-secrets, `build_aab.sh`, `apksigner verify`. Play Console: listing, privacy policy op eazydstudio.com, data safety, content rating. Closed testing → productie. | Dennis zegt go. |

Stap 3, 4 en 5 lopen parallel. Stap 6 en 7 pas na de freeze-tag.

## Rollen voor dit plan

- **Dennis:** go per stap, ComfyUI starten en `tools/sfx/gen_sfx.py` draaien in WSL (de agents kunnen ComfyUI niet bereiken), keuze per geluid, playtest, Play Console.
- **RPG Forge:** tag, merge, CI, versie, AAB, web-upload.
- **Agents (Cursor/Claude):** scripts, docs, bugfixes, balans-sims. Pushen nooit zelf naar `Sapientia-RPG`.

## Play Store: wat Dennis apart moet regelen (ONVERIFIED, buiten de repo)

- Google Play Console-account (eenmalig 25 USD).
- Nieuwe persoonlijke accounts moeten eerst een closed test doen (bij schrijven: 12 testers, 14 dagen) voordat productie open mag. Controleer de actuele eis in de Console.
- Privacy policy-URL op eazydstudio.com (de game bewaart alleen lokale saves en een optionele sessielog in debug-builds).
- Grafisch: icoon 512×512, feature graphic 1024×500, 4-8 screenshots per formaat (telefoon liggend).
- Keystore: bewaren buiten de repo, back-up op twee plekken; verlies = nooit meer updaten.

## Niet in dit plan

Alles uit `TODO.md` onder "Wacht op scènes" en "Art en nieuwe content", de relay-service, PvP fase 2/5, bestiarium tot endgame.
