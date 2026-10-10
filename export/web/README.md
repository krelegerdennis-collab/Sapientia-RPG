# SAPIENTIA in de browser

Web-build van `main` (`7a5c7ee`), Godot 4.7.2, threads uit.
GitHub Pages zet geen COOP/COEP-headers, dus een build mét threads start niet op een telefoon.
De touch-knoppen zitten erin: stuurknop links, A en B rechts.
De zes muziekbestanden (`assets/audio/bgm/*.ogg`) zitten in `index.pck`.

## Spelen op je telefoon

Pages staat al op branch `cursor/web-build-29ec`, map `/ (root)`.
Je hoeft geen knop meer aan te zetten.

1. Wacht ongeveer een minuut na deze update.
2. Open https://krelegerdennis-collab.github.io/Sapientia-RPG/
3. Ververs hard als je nog de vorige build ziet (pagina verversen, of de site even uit de recente apps vegen).

De eerste tik op het scherm zet het geluid aan. Dat eist de telefoonbrowser.
Houd de telefoon liggend. Eerste keer ongeveer 65 MB download (`index.pck` 27 MB + `index.wasm` 38 MB).

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
