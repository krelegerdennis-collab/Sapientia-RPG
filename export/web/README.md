# SAPIENTIA in de browser

Bronnotitie bij de web-export. De live build komt uit workflow **build-web** (Godot 4.3-stable,
preset **Web**, threads uit). GitHub Pages kan geen COOP/COEP-headers zetten; daarom
`variant/thread_support=false` in `export_presets.cfg`. Oud: branch `cursor/web-build-29ec`
(Godot 4.7.2, legacy Pages uit branch).

## Spelen op je telefoon

https://krelegerdennis-collab.github.io/Sapientia-RPG/

Na een nieuwe publicatie: hard verversen (Safari: het tabblad sluiten en opnieuw
openen; Chrome: het menu, dan verversen). De browser bewaart de oude `index.pck`.

De eerste tik ergens op het scherm (ook Doorgaan of Nieuw spel) zet het geluid aan.
Tot die tik staat er **Tik voor geluid**. Houd de telefoon liggend.

Grote binaries (`index.pck`, `index.wasm`) worden niet in git gecommit; CI exporteert ze per run.
