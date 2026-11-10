# tools/sfx — SFX uit de offline AI-stack

- `gen_sfx.py`: genereert via ComfyUI + Stable Audio Open 1.0 (WSL op de laptop), knipt stilte voor en na weg, trimt,
  zet de piek op -1 dBFS, converteert naar mono 22050 Hz 16-bit, legt per kandidaat de herkomst vast (prompt, seed, model,
  sha1 in `out/<cuebestand>/herkomst.json`), installeert gekozen wavs in het spel (`--install`) en bouwt een verkooppack
  (`--pack-export`: wav/, ogg/, README.txt, SOURCES.csv, optioneel `--crush 12` voor de 16-bit-klank). Zie de docstring.
- `cues_wm1_batch1.json`: 67 spel-cues (WM1-rookroute); sleutel = sfx-id uit `audio_manifest.json`.
- `cues_retroquest_vol2.json`: 62 pack-cues / 131 bestanden voor **Retro Quest Vol. 2 — Combat & Magic** (itch.io):
  melee, ranged, raak/mis, 8 elementen × cast + hit, healing/buffs, charge/release, statussen. 19 cues zijn gekoppeld aan
  manifest-id's (`"manifest"`), dus dezelfde keuze vult ticket A-3 (`docs/HANDOFF_REVIEW_2026-11.md`) voor 35 placeholder-bestanden.
- `out/` (niet committen, staat in .gitignore van deze map): kandidaten per cue; `out/<cuebestand>/kies/` = jouw keuze.

## Vol. 2 maken (laptop, WSL, ComfyUI aan)

```bash
python3 tools/sfx/gen_sfx.py --check-cues --cues tools/sfx/cues_retroquest_vol2.json      # 0 fouten
python3 tools/sfx/gen_sfx.py --cues tools/sfx/cues_retroquest_vol2.json --seeds 5          # 131 x 5 kandidaten (~1,5 s per stuk)
#   -> luister in tools/sfx/out/cues_retroquest_vol2/<cue>/, kopieer per bestand de beste naar
#      tools/sfx/out/cues_retroquest_vol2/kies/sfx_<cue>_NN.wav   (naam zonder _s<seed>)
python3 tools/sfx/gen_sfx.py --cues tools/sfx/cues_retroquest_vol2.json --pack-export dist/retroquest_vol2 --crush 12
#   -> dist/retroquest_vol2/{wav,ogg}/ + README.txt + SOURCES.csv  => zip en als update op de Retro Quest-pagina
python3 tools/sfx/gen_sfx.py --cues tools/sfx/cues_retroquest_vol2.json --install          # 19 gekoppelde cues -> assets/audio/sfx/
python3 tools/check_algemene_sfx.py && godot --headless --path . --import                   # daarna PR (label wm1-polish)
```

`--pack-export` meldt welke cues nog geen keuze hebben en welke bestanden geen herkomst hebben (dan is de seed onbekend en komt
hij leeg in SOURCES.csv; kies altijd uit `out/`, niet uit losse downloads). Zonder ComfyUI is de nabewerking te testen met
synthetische wavs (de audio-eigenschappen zijn op 9 nov 2026 zo geverifieerd: 22050 Hz mono 16-bit, ≤ max_s, piek -1 dBFS, ogg aanwezig).

## Prijs en pagina (besluit Dennis)
Vol. 2 als update op de bestaande Retro Quest-pagina ("Vol. 1 + 2"), prijs naar $4; changelog-regel met datum in de beschrijving.

Let op: `check_algemene_sfx.py` eist `MAX_DUR = 0.60`; `--install` trimt gekoppelde pack-cues daarop (de pack zelf houdt de langere
`max_s`). Voor stingers (level_up, golem_death, battle_start) blijft het voorstel voor RPG Forge: per categorie een maximum
(ui 0.6 s, gevecht 1.0 s, bazen/sapientia 3.0 s) en `audio_manager.gd` controleren op polyfonie-limiet.

Licentie: Stable Audio Open 1.0 = Stability AI Community License (commercieel gratis tot 1M USD omzet/jaar). Controleer vóór
verkoop de actuele voorwaarden (mag gegenereerde audio als los product worden verkocht, is naamsvermelding verplicht) en lever
`SOURCES.csv` mee. ACE-Step is een alternatief; lees ook daar de licentie van model én trainingsdata.
