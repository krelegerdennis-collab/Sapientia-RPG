# SAPIENTIA in de browser

Web-build van `main` (`d625f96`, v0.21, Wilgendal SoM grote huizen + brede paden #117), Godot 4.7.2, threads uit.
GitHub Pages zet geen COOP/COEP-headers, dus een build mét threads start niet op een telefoon.
Hard verversen, anders blijft de vorige `index.pck` in het geheugen.

Nieuw in deze build, bovenop `2782887`:
- Willowdale v3: reuzenmolen over de beek (achter de molen langs lopen; stille wieken tot Garretts quest klaar is, daarna draaiend) en een groot burgemeestershuis (#113).

Eerder, bovenop `b605403`:
- Willowdale (Wilgendal) ~3x groter: hoofdstraat, beek van 1 tegel met brug, marktplein met nieuwe put, max 2 NPC's op het plein (#107).
- Engelse spelersnamen overal; Spark/Arc en Ember/Glow uniek (#110).
- Deep Learning Simulation-naam en warp-vlak, Warp-label op Dauwpixel 10 (#105); scenes-kijker hangt niet meer (#109).

Eerder, bovenop `f25da72`:
- Save-slots: bij New Game kies je slot 1-4; het opslagboek schrijft naar dat slot (of een ander slot). De autosave heeft een eigen rij 'Autosave' en overschrijft nooit meer een handmatig slot. Autosave alleen bij kerker in/uit (#103).
- Diepe Grot: een verlamd monster op een drukplaat duwen drukt hem in; een plaatpuzzel heeft 1 monster naast de plaat; een monster in een val duwen verslaat het (#102).

Eerder, bovenop `43cdbcd`:
- Koopman-winkel: alle grot-uitrusting, rollen en items hebben Engelse namen; accessoires (o.a. Archive Ring) kosten een prijs naar verdieping, geen 1g meer (#101).
- Diepe Grot: verlamd monster duwen, ook ketting-duw (#94).
- RUN-knop boven de CORE-knop (toets R): 2 tegels per zet, 2x zo snel (#95).

Eerder, bovenop `01f6ab8`:
- Bouwplaats bij de berggrot met echte art en vier werkers (#80).
- Diepe Grot: eigen tegels in zeven kleurvarianten (per 15 verdiepingen) en bijpassende gevechtsachtergronden (#81, #83, #85).
- Diepe Grot: kamer-types per verdieping (Medium 25x25, Large 50x50, kistkamertje, schatkamer, lege kamer, extra rustkamers) (#82).
- Diepe Grot: alle gewone monsters uit het bestiarium, op volgorde Archief 1 > Woud > Bergtunnel > Archief 2 (#84).

Eerder, bovenop `28d75ce`:
- Het monster vecht als zijspeler boven de B-knop. In het veldmenu staan nu Magic, Bestiary, Settings, Load en Scenes (cutscenes opnieuw bekijken, ook de drie World Warper-scènes), met gecentreerde knoppen.
- Archief 2 in de nieuwe kas-stijl: nieuwe tegels en versierde kamers. De Genezer staat op een podium en je kunt pas langs hem na het gevecht.
- Het baasgevecht in de kas heeft een eigen achtergrond.
- Nieuw filmpje na De Genezer (de kern, de Hanger, de World Warper in de lucht), daarna de scène.
- Let op: de download is groter (ongeveer 63 MB) door de twee filmpjes.

Eerder, bovenop `ff4ecdd`:
- Gevechts-HUD v2: perkamentkaarten met alleen balken (geen getallen), gouden kaart = aan de beurt, teal = doelwit, grijs = KO. Het monstervak blijft groen.
- World Warper-canonscènes (PR #73).

Eerder, bovenop `7237d2c`:
- De wereldkaart-cutscene is scherp: tijdens het filmpje rendert het spel op schermresolutie (daarna weer pixel-art), de video wordt lineair gefilterd en is opnieuw gecodeerd op 720x1280.

Eerder, bovenop `bb484ea`:
- Eenmalige wereldkaart-cutscene (video `worldmap_intro.ogv` + glitch-paneel) en moswezens in de tuin van opa.
- Alle spelerstekst is nu Engels (ECHO-gids, PvP, winkels, kamers, Archief 2). Eigennamen blijven Nederlands.
- De Koopman in de Diepe Grot, met winkel en drie dialoogfases. Val-, rust- en koopmankamers.
- Prijs van graad-uitrusting is nu graad x graad x 60 goud (G1 60, G2 240, G3 540, G4 960).
- Party-limiet: 4 helden + 1 monster in gevecht, de rest in reserve. Nieuw Party-menu en monstervak-icoon.
- World Warper-hub: het opslagmenu (PLACEHOLDER/Opslaan) is weg, de warp- en gezelschapsvlakken en warp-iconen hebben echte art, de rondlopers zijn echte sprites en er staat nergens meer PLACEHOLDER.

Nieuw in deze build (v0.21), bovenop `577ccaa`:
- Nieuwe vijand-art van RPG ART (batch 1), de Mimic ziet eruit als een dichte blauwe kist en loopt niet.
- De berggrot is lichter van kleur, heeft eigen tegels, een gevechtsachtergrond en een eigen terrein. De Diepe Grot ook.
- De molen in Wilgendal draait met echte wieken. 12 nieuwe voorwerpen in Wilgendal, de borden staan een tegel lager.
- Lotte, De Wurger, De Genezer (baas, 240x194), ECHO, Woudgeest en de bazen van verdieping 10 tot 99 van de Diepe Grot hebben echte art. De Stem heeft een idle-animatie.
- Spiegelkamer (heel en gebroken), kas-tegels, platen, levenskern en kas-ingang.
- World Warper-art: accent per Archief, gloeiende Hanger, knoppen op de wereldkaart.
- De speltekst is Engels, ook het warp-scherm (Choose a world, Travel, Back).

Nog van de build van `577ccaa`:
- Engelse ondertitel op het titelscherm (art van RPG ART).
- De Ink Worm heeft weer RPG ART's tekeningen (gevecht, rug, idle, kaart).
- De geheime kast in de Golemhal is één kast breed. Core Power laat roze kernscheuren oplichten, daarna breekt hij open.
- Het bestiarium telt een Paper Wraith die door een status-effect valt ook als verslagen.

Nog van de build van `d3de708`:
- In het Donker Woud en de berggrot staan warpers bij begin, midden en eind. Het begin laat je in de dungeon. Midden en eind vragen of je wilt vertrekken en zetten je dan op de wereldkaart.
- Op het plein van Wilgendal lopen Bram, Els, Fien, Wout en Siem een korte lus. Gerrit blijft bij de molen.
- ECHO noemt de volgende plek: Noor in het Donker Woud, daarna de Golem, daarna De Genezer via de berggrot, anders een plek die je al bezocht hebt.
- Op verdieping 3 van Archief 2 is een kamer waar een kast en een hendel samen de groeiplaat openen.
- Blauwe kisten vanaf verdieping 80 kunnen elke grade-4-spreuk als rol geven. Grade 4 blijft uit de winkel.
- Hard verversen, anders blijft de vorige `index.pck` in het geheugen.

Nog van de build van `c0df241`:
- De Diepe Grot staat in ECHO's Kamer. Na De Genezer, in de hub: het bord ECHO. In die kamer: de paarse poort met het opschrift Diepe Grot. Praat ermee (A). Kies Diepe Grot Simulatie, daarna Start nieuwe run. ECHO zelf doet hetzelfde.

Nog van de build van `66f0b80`:
- De Wurger heeft HP 700, ATK 42, DEF 28. De Genezer heeft HP 900, ATK 54, DEF 36. Op verdieping 25, 50, 75 en 99 hebben De Schaduw van H-6, De Cyclus, De Rechter en De Stem vaste stats.
- De magielijst gebruikt de canon-namen. Grade 1 tot en met 3 staan in de winkel. Grade 4 niet.
- Op verdieping 100 kies je één beloning: het Codex-monster ECHO, een Grade 4-wapen, of de Simulatie-ring. De ring geeft +10% stats in de Diepe Grot en herstart één keer per run de huidige verdieping als je valt.
- De Hanger gloeit paars. Na De Genezer ga je vanzelf naar de World Warper. In de Rustkamer wissel je de groep (maximaal 3, Dennis blijft). ECHO's Kamer heeft drie kisten.
- Midden- en eindwarpers van Archief 1 en Archief 2 vragen of je de dungeon wilt verlaten.
- Wilgendal heeft vier winkelpanden. De verkoper staat achter de toonbank. De borden zijn iconen: schild, zwaard, ring en ster. Op het plein staan zes dorpelingen. Gerrit en de molen blijven.
- Hard verversen, anders blijft de vorige `index.pck` in het geheugen.

Nog van de build van `794e9ba`:
- De kas van Archief 2 staat linksboven op de wereldkaart, achter de bergen. De berggrot is de enige weg erheen. De ingang naast de trap van het Eerste Archief is weg.
- De Diepe Grot start niet meer vanaf de wereldkaart. Je begint in ECHO's Kamer. Ladder, tussen-warper en nederlaag zetten je terug in die kamer.
- In Wilgendal zingt de molen zacht na het zaad.
- Op de wereldkaart staat een platform voor de World Warper. Dat gaat open na De Genezer. Worldmap 2 en 3 blijven dicht.
- Hard verversen, anders blijft de vorige `index.pck` in het geheugen.

Nog van de build van `bb69c9b`:
- Het Levende Archief heeft vier verdiepingen, na de Golem. De kas stond toen nog naast de trap van het Eerste Archief. Groei-platen, Lotte, De Wurger en De Genezer. Na De Genezer een korte hub-scène: ECHO, de Hanger, en de andere eilanden die nog dicht blijven.
- In de Diepe Grot heten de bazen op verdieping 25, 50, 75 en 99 De Schaduw van H-6, De Cyclus, De Rechter en De Stem. Uitgang-warpers staan op verdieping 1, 25, 50, 75 en 99. Verdieping 1 legt het uit.
- In Wilgendal, na Noor: Gerrit en Het Zingende Graan. Het zaad, de molen-save en één Zingend Meel per bezoek zitten erin.

Nog van de build van `7a18856`:
- Het veldmenu is vier knoppen. Links, onder elkaar: Uitrusting, Codex en Items. Die openen meteen het bestaande scherm. Rechts een groter vlak Warpen, met het label MENU erboven. Warpen zegt "De warp-hub is nog niet bereikbaar." zolang de hub-vlag niet gezet is. Die vlag gaat open na De Genezer. De kaart en de save-slots blijven met rust.

Nog van de build van `4a145c6`:
- In het Eerste Archief staan drie uitgang-warpers: bij de ingang, in de Zuilenhal (verdieping 3) en in de Golemhal, naast de tegel na de overwinning. Met A vraagt het spel: "Weet je zeker dat je de dungeon wilt verlaten?" Ja zet je op de wereldkaart bij het Eerste Archief. Nee laat je staan. De warpers van de Diepe Grot (verdieping 1, 50 en 99) blijven zoals ze waren.

Nog van de build van `ad7cbd4`:
- Verdieping 1 van Het Levende Archief. Op de wereldkaart, direct links van de trap naar het Eerste Archief, staat een kas. Die blijft dicht tot je de Golem van het Eerste Archief verslagen hebt. Daarna: een bord, een opslagpunt, een Mosslijm en een Moskonijn, en één groei-plaat. Zet eerst de hendel om. Daarna groeit de plaat: zaad, scheut, volgroeid. Alleen volgroeid is een pad. Verder de kas in is nog dicht.

Nog van de build van `71c7bdc`:
- Kortere intro. Geen wakker-cutscene: je staat meteen naast het bed. Opa vraagt eerst wat je zegt: "Goedemorgen, Opa." of "Waarom blijven de Archieven dicht?". Daarna hetzelfde vervolg: de mantel, MENU > Uitrusting > Harnas, en daarna water en kruiden.

Nog van de build van `538e906`:
- In de Diepe Grot staan warpers op verdieping 1, 50 en 99. Een warper gaat open zodra je die verdieping in deze run bereikt. Met A kies je een andere open warper. Vóór de sprong vraagt het spel of je door wilt. Annuleren laat je staan. Een warper die je nog niet bereikt hebt, staat niet in de lijst. De open warpers gaan mee in de save van de run.

Nog van de build van `4ae7a4a`:
- Titelscherm links, onder Betatest: **Eindstaat**. Eigen bestand (`save_eindstaat.json`), niet slot 1–4.
  De party staat op level 40. Noor en Lotte doen mee, met spreuken t/m grade 3, G4-wapens en 8000 goud.
  Je start op de wereldkaart bij Wilgendal. De winkels en de Diepe Grot zijn bereikbaar.
  Opslaan daarna blijft in dat eindstaat-bestand.

Nog van de build van `5cd0522`:
- Geen nieuwe gameplay t.o.v. `404bce0`. `index.pck` zonder lokale testscreenshots.

Nog van de build van `404bce0`:
- Magie in Wilgendal kost 160×grade²: grade 1 = 160, grade 2 = 640, grade 3 = 1440. Grade 4 blijft uit de winkel. Verkoop is de helft, dus een grade-1-spreuk levert 80.

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
- Titelscherm links: **Betatest** en **Eindstaat**. Elk een eigen voortgang, los van Nieuw spel en Doorgaan.
  Betatest: de eerste keer op de wereldkaart (niveau 10, Vonkzwaard, 6 Lege Boeken). Daarna ga je daar verder.
  Eindstaat: level 40, Noor en Lotte, eigen bestand. Slot 1–4 blijft heel.

## Spelen op je telefoon

Pages staat op branch `cursor/web-build-29ec`, map `/ (root)`.

https://krelegerdennis-collab.github.io/Sapientia-RPG/

Na deze publicatie moet je hard verversen. De browser bewaart de oude `index.pck`.

- Chrome: menu, dan verversen.
- Safari: het tabblad sluiten en opnieuw openen.

De eerste tik ergens op het scherm (ook Continue of New Game) zet het geluid aan.
Tot die tik staat er **Tap for sound**. Houd de telefoon liggend.
Eerste keer ongeveer 68 MB (`index.pck` 30 MB + `index.wasm` 38 MB).

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
