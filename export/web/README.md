# SAPIENTIA in de browser

Web-build van `main` (`404bce0`), Godot 4.7.2, threads uit.
GitHub Pages zet geen COOP/COEP-headers, dus een build mét threads start niet op een telefoon.
De touch-knoppen zitten erin: stuurknop links, A en B rechts.
De muziek, de acteur-wavs en de algemene sfx zitten in `index.pck`.

Nieuw in deze build, bovenop de vorige web-build (`2d393da`, export van `1f8f6b3`):
- Magie in Wilgendal kost 160×grade²: grade 1 = 160, grade 2 = 640, grade 3 = 1440. Grade 4 blijft uit de winkel. Verkoop is de helft, dus een grade-1-spreuk levert 80.
- Hard verversen, anders blijft de vorige `index.pck` in het geheugen.

Nog van de build van `1f8f6b3`:
- Vier save-slots. Continue en Load openen dezelfde lijst. Slot 1 blijft het oude bestand.
- Het Eerste Archief mikt op level 7. De Golem blijft een eigen gevecht.
- Wilgendal is het eerste dorp, met wapen, pantser, accessoire en magie. In Act 1 verkoopt de magiebalie alleen Grade 1.
- Blauwe kisten in de Diepe Grot hebben grades. Affixen staan vast per item. Grade 4 (vanaf verdieping 80) is niet te koop.

Nog van de build van `d81e339`:
- Alle tekst die je in het spel ziet is Engels. Menu's, verhaal, items en de titel (The Forgotten Archives). Namen blijven Dennis, Noor en Lotte.
- De levelschaal loopt door tot Act 6 (level 40). De 100-vloeren-grot mag daar voorbij.
- Nieuwe spullen: Ilse geeft Herbal Tea nadat Noor gered is. Noor geeft een Padded Jerkin. In de kast van de Ink Worm ligt Glowing Ink. De rest van de verhaalset staat in de data, nog niet in de wereld.

Nog van de vorige build:
- De 100-vloeren-grot neemt de hele party mee, ook elk Codex-monster. Iedereen start op level 1, zonder spullen en zonder spreuken.
- In gewone kisten vind je soms een Fire Scroll, Lightning Scroll of Heal Scroll. Die leert één held de spreuk, alleen tijdens de run.
- Als de run stopt (dood, de grot uit, of de Warp), komen je echte levels, spullen, spreuken en monsters terug.
- In de Golemhal staat rechts een boekenkast. Core Power (de veld-vuurbal, pas na de Golem) scheurt hem open. Dan kronkelt de Ink Worm eruit.
- **Beta Test** begint met een Ink Worm als buddy. Had je die al gestart, dan komt de Ink Worm er de volgende keer bij.
- Bij **New Game** typ je je eigen naam. Dennis staat er al in; de eerste letter vervangt die naam. Tik het vak aan, dan opent het toetsenbord op de telefoon. Leeg laten blijft Dennis. Maximaal 10 tekens.
- Titelscherm links: **Beta Test**. Eigen voortgang, los van New Game en Continue.
  De eerste keer sta je op de wereldkaart (niveau 10, Spark Sword, 6 Blank Books).
  De volgende keer ga je daar verder.

## Spelen op je telefoon

Pages staat op branch `cursor/web-build-29ec`, map `/ (root)`.

https://krelegerdennis-collab.github.io/Sapientia-RPG/

Na deze publicatie moet je hard verversen. De browser bewaart de oude `index.pck`.

- Chrome: menu, dan verversen.
- Safari: het tabblad sluiten en opnieuw openen.

De eerste tik ergens op het scherm (ook Continue of New Game) zet het geluid aan.
Tot die tik staat er **Tap for sound**. Houd de telefoon liggend.
Eerste keer ongeveer 75 MB (`index.pck` 37 MB + `index.wasm` 38 MB).

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
