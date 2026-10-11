# SAPIENTIA in de browser

Web-build van `cursor/golem-boeken-volger-4396` (`07d3c51`, inclusief `main` `860ba75`), Godot 4.7.2, threads uit.
GitHub Pages zet geen COOP/COEP-headers, dus een build mét threads start niet op een telefoon.
De touch-knoppen zitten erin: stuurknop links, A en B rechts.
De muziek, de acteur-wavs en de algemene sfx zitten in `index.pck`.

Nieuw in deze build, bovenop de vorige web-build (`0c157f5`):
- De Golem in het Eerste Archief geeft 3 Lege Boeken.
- De actieve Codex-buddy loopt mee in kerkers en op de wereldkaart, niet in dorpen.
- Glitch-fusie, de Inktwurm en de Codex-knop in het gevecht.

## Spelen op je telefoon

Pages staat op branch `cursor/web-build-29ec`, map `/ (root)`.

https://krelegerdennis-collab.github.io/Sapientia-RPG/

Na deze publicatie moet je hard verversen. De browser bewaart de oude `index.pck`.

- Chrome: menu, dan verversen.
- Safari: het tabblad sluiten en opnieuw openen.

De eerste tik ergens op het scherm (ook Doorgaan of Nieuw spel) zet het geluid aan.
Tot die tik staat er **Tik voor geluid**. Houd de telefoon liggend.
Eerste keer ongeveer 87 MB (`index.pck` 48 MB + `index.wasm` 38 MB).

## Kortere link

Een GitHub Pages-adres is altijd `https://<account>.github.io/<repo>/`.
De accountnaam `krelegerdennis-collab` kan daar niet uit, tenzij je een eigen domein koppelt.
Deze build kan dat niet voor je instellen.

Op je telefoon, ingelogd op GitHub:

- **Repo hernoemen naar `sapientia`.** Settings → General → Repository name.
  De speellink wordt dan https://krelegerdennis-collab.github.io/sapientia/
  De accountnaam blijft in het adres.
- **Eigen domein.** Settings → Pages → Custom domain. Alleen als je zelf een domein hebt.
  Dan kan het adres zonder `github.io` en zonder de accountnaam.
