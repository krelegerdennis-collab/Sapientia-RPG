# TODO — toekomstige updates

Afvinken alleen als het echt af is. Open punten zijn nog ontwerp of nog niet gebouwd.

Hoe deze lijst werkt: de actieve werklijst is wat nu opgepakt kan worden. Canon-blokken staan woordelijk onder Canon & Design Reference, met hun oorspronkelijke markering. Afgevinkte items staan onderaan als referentie.

## Status

Speelbaar: Worldmap 1 (start-eiland met Dennis' huis, Wilgendal en het Eerste Archief), Archief 2 via de berggrot, Donker Woud, en de Diepe Grot als simulatie via ECHO in de World Warper.

Niet zelf bouwen. Wacht op scènes: ECHO's twist (wanneer, hoe, confrontatie, H-1 tot en met H-5); De Spiegel koppelen aan Archief 4; worldmap 2 en 3 (kamerlijsten, monsters, paden).

Open thema's: art-placeholders, World Warper (gebouw, dialoog, lege kamers, audio), sfeer, Codex en muziek van Archief 2, bestiarium tot endgame, PvP-relay en polish, Diepe Grot (loot, kaarten, push, rennen). Warper-stijl, Archief 2-roster en de Koopman (H-5) zijn beslist (CANON 12-14).

Grade 4-wapens en -sets, en het herzien van PvP-teams, wachten tot er nieuwe karakters in het verhaal komen. Gerrit blijft staan.

## Actieve werklijst

### Act 1

- [ ] Act 1 = Worldmap 1 (start-eiland, Eerste Archief en Leven)

Act 2, Act 3 en de Spiegel-scène wachten op worldmap 2/3 en op scènes. Die vakjes staan open onder Canon & Design Reference.

### Dungeon-warpers

- [x] Warper-stijl beslist: universeel met kleuraccent per Archief (CANON 14)
- [ ] Cutscene-teksten (na De Genezer, eerste binnenkomst Hal, Sapientia-dreiging): tekst volgt van Dennis

Archief 3 tot en met 6 hebben nog geen warpers. Dat vakje blijft open onder Canon & Design Reference, samen met de canon-regel voor de Diepe Grot.

### Archief 2 — sfeer, art en Codex

#### Sfeer en setting

- [ ] Overwoekerde kas of broeikas (groen, vochtig, planten overal)
- [ ] Zachte groene gloed als signature lighting
- [ ] Leven dat niet stopt met groeien; alles is in beweging
- [ ] Visueel contrast met het grauwe Eerste Archief

#### Content en art

- [x] Roster plant-vijanden beslist (CANON 13): Rankje, Sporekop, Doornige Loper, Bloeiende Schrik, Wortelgeest (Natuur)
- [ ] EN-namen laten bevestigen door Dennis (voorstel: Tendril, Sporehead, Thorn Runner, Blooming Dread, Rootghost)
- [ ] Achtergrondmuziek die bij de overwoekerde kas past

#### Codex

- [x] Codex-monsters Archief 2 beslist (CANON 13)

### Bestiarium

- [ ] Bestiarium uitwerken tot endgame
  De bestaande eindbazen van de Diepe Grot (verdieping 10 tot en met 100) hebben een entry en stats uit de bestaande monsterdata.
  De vier lore-zinnen hieronder staan in het bestiarium (`desc` van kennis_beest, wortelkoning, wurger en genezer). De weergavenaam van Kustos blijft The Knowledge Beast; die naam zit in de tests vast.

De notitie bij dit vakje en de vier lore-zinnen staan direct boven die zinnen, onder Canon & Design Reference.

### World Warper

De hub na De Genezer bestaat. Hieronder wat daar nog open is. Ontgrendeling van worldmap 2 en 3 staat niet in deze lijst.

- [ ] Webversie.
  De Pages-branch `cursor/web-build-29ec` heeft de export van main `7237d2c` (Godot 4.7.2, threads uit). De export blijft handmatig. Hard verversen na de publicatie.

### Concept en lore

- [ ] Zwevend hightech gebouw op de wereldkaart
  Placeholder-exterieur staat. Het gebouw zweeft niet op de wereldkaart. Placeholder-kaarten staan in world_warper/maps.
- [ ] Slot dat alleen op Dennis' Hanger reageert
  De scène noemt de Hanger de Sleutel. Een slot dat alleen op Dennis reageert ontbreekt. De spelertekst onthult H-6 niet.

### Verschijning en cutscene

- [ ] Cutscene na De Genezer: de World Warper verschijnt in de lucht
  De Genezer staat in Archief 2. De World Warper-scènes staan in CANON 17 en in de game. Er is geen platform op de kaart: alleen Warp in het menu.

- [ ] Duidelijk maken wat dit is, wat het kan, en waarom het belangrijk is
  Eerste-bezoekscène en de vier ECHO-stappen doen een eerste versie. De zinnen zijn voorlopig.

### Eerste binnenkomst: Hanger en Sapientia

- [ ] Systemen komen online door het Hanger-signaal
  De scène speelt één keer. Losse systemen gaan niet aan.

- [ ] Dialoogscène
  - [ ] Dennis toont de Hanger (eerste keer expliciet in het verhaal)
    De scène toont de Hanger paars. Dennis steekt hem niet apart op.
  - [x] ECHO reageert herkennend op de Hanger
    De hanger-stap zegt: "De Sleutel reageerde bij je aankomst." en "De Hanger is de Sleutel." De spreker heet ECHO. Over H-6 zegt de tekst niets.
  - [ ] Uitleg bouwen: alleen de Hanger, de biometrische sleutel, activeert de World Warper
    De tekst noemt de Hanger de Sleutel. Ze zegt niet dat alleen die de hub start. Geen H-6-onthulling.
- [ ] Sapientia-dreiging
  - [ ] Na de activering verschijnt Sapientia (glitch, stem of hologram)
    Korte zwarte flikkering en een haperend hologram. Geen stem en geen hologram van Sapientia.
  - [ ] Sapientia uit de dreiging: zij wil de World Warper, toegang tot alle zes Archieven tegelijk
    De zin is: Sapientia weet dat de Sleutel hier is.
  - [ ] Duidelijk maken dat Dennis en de Hanger het enige obstakel zijn: Sapientia wil zijn sleutel
  - [ ] Dreiging opbouwen voor latere acts
  - [ ] De party reageert geschokt; ECHO waarschuwt

### Interieur

- [ ] Kamers bouwen volgens de lijst hieronder
  De kamers uit de lijst staan in world_warper/kamers en gaan open na De Genezer. Werkplaats en Handelskamer zijn leeg. codex_nis en sapientia_schot blijven dicht: world_warper_act2 en world_warper_act3 zet niemand.

Per act:

- [ ] Act 4: De Werkplaats, crafting
  De kamer staat, maar is leeg.
- [ ] Act 5: De Handelskamer, endgame-shops
  De kamer staat, maar is leeg.

Eerste versie, nog niet de kamers hierboven:

- [ ] Paars als signature kleur, in lijn met het Codex Monument
  Panelen, de hal en de Hanger-gloed zijn paars. Het blijven placeholder-tegels, geen definitieve art.
- [ ] Hologrammen, schermen en tech-details
  Placeholder-hologram in de eerste-bezoekscène en bij ECHO. Geen echte schermen.

### Bewoners van de hub

- [ ] Nieuwe party-leden voegen zich toe zodra ze aansluiten
  refresh() leest de party bij het laden van de hal. Midden in de kamer werkt dat niet live bij.

### AI-gids (in de main PC)

Naam: ECHO. Bonus-lore, later onthullen: ECHO is de digitale echo van een onderzoeker van de Oude Mensheid.

- [ ] De AI-gids zit in de main PC van het warp-platform
  ECHO staat in de hal (ww_anchor_gids), niet in de warp-ring. Het plaatje is een placeholder.

- [ ] Functie: questvoortgang, missie-uitleg en begeleiding
  Vier vaste stappen via Dialog.show_lines. Geen questvoortgang.
- [ ] Reageert op verhaalprogressie (nieuwe dialoog per act)
  Vlaggen world_warper_guide_0 tot en met 3, in volgorde. Niet per act.

### Warp-systeem


- [ ] Questvoortgang via de AI-gids
  ECHO heeft vier vaste stappen (world_warper_guide_0 tot en met 3) plus een hint naar de volgende bestaande bestemming. Geen questlog.

### Audio

- [ ] Geluid bij de eerste Hanger-activatie
  Bij hanger_activated gaat ww_sapientia_glitch af. Een eigen Hanger-geluid ontbreekt, en ook dat blijft stil.
- [ ] Stem of hologramgeluid van de AI-gids

### Visuals en art

  tiles.png, tegels 16×16, met het woord PLACEHOLDER. Geregistreerd in tools/placeholders_v17.txt. Echte tileset ontbreekt nog.

### Verhaal-integratie

- [ ] Dennis' Hanger is de sleutel; dat meermaals benadrukken in dialoog
  Eerste-bezoekscène en de ECHO-stap hanger noemen de Hanger de Sleutel. Zinnen zijn voorlopig. Geen H-6-onthulling. Het staat nog niet op meer plekken.
- [ ] Sapientia's belang bij de World Warper opbouwen: alle zes kernen in één keer
  Eén zin: Sapientia weet dat de Sleutel hier is.

### PvP

De modus staat onder Canon & Design Reference. Open blijft:

- [ ] Relay service kiezen
  - [ ] TODO(design): GD-Sync / NodeTunnel / eigen VPS / TBD

- [ ] Fase 2: Online lobby + connect-code
  De connect-code werkt op LAN. Een online lobby met relay is er niet.

- [ ] Fase 5: Polish (UI, disconnect, reconnect)
  Disconnect en reconnect op dezelfde hostsessie staan. De rest van de polish niet.

### Diepe Grot — nog te bouwen

- [x] Monsterpool: alle gewone bestiarium-monsters, op volgorde Archief 1 > Donker Woud > Bergtunnel > Archief 2 (wens Dennis). `Dungeon100Content.POOLS` met vensters per gebied; stats schalen per verdieping.

De vakjes hieronder zijn de open bouwtaak. Elke regel staat ook, met aantallen, kansen en dialoog, onder Canon & Design Reference → Diepe Grot. Werk de specificatie daar als bron; deze lijst is het overzicht van dezelfde open vakjes.

#### Diepe Grot – balans aanpassen

##### Loot table
- [ ] Consumables in loot table verminderen
  - [ ] Te veel consumables maakt de Grot te makkelijk
  - [ ] Meer equipment/accessoires, minder potions/MP-items
  - [ ] TODO(design): exacte ratio bepalen
- [ ] Blue chest frequentie early game verlagen
  - [ ] Te veel blue chests op floor 1-20
  - [ ] TODO(design): exacte kans per floor-bracket

#### Diepe Grot – map generatie (uitgebreid)

##### Kamer-types + kansen
- [x] MEDIUM MAP (35%)
- [x] LARGE ROOM (20%)
- [x] CHEST ROOM (10%)
- [ ] PUZZLE ROOM (5%)
- [x] TREASURE ROOM (5%)
- [x] EMPTY ROOM (5%)

##### Vaste kamers (geen random)
- [x] BOSS ROOM (floors 25/50/75/99)
- [x] FLOOR 100 ROOM (vast)

##### Generator logica
- [x] Per verdieping: 1 layout rollen uit bovenstaande tabel
- [x] Boss-floors (25/50/75/99) → altijd BOSS ROOM
- [x] Floor 100 → altijd FLOOR 100 ROOM
- [x] Layout-type onthouden voor save/load
- [x] Monsters spawnen passend bij layout-type
- [x] Kisten spawnen passend bij layout-type

##### Balans-regels
- [x] REST ROOM + TREASURE ROOM niet op opeenvolgende verdiepingen
- [x] PUZZLE ROOM niet op floor 1-5

#### Systemen – push monster when stunned

##### Basis push
- [ ] Als speler TEGEN een GESTUND monster aanloopt:
  - [ ] Speler beweegt ÉN monster wordt geduwd (samen)
  - [ ] Monster schuift 1 tegel in de richting van de speler
  - [ ] Speler neemt de oorspronkelijke plek NIET in
- [ ] Als monster tegen muur/obstakel wordt geduwd → blijft staan
- [ ] Werkt ALLEEN bij stun-status (niet bij normale monsters)
- [ ] Visuele feedback: monster schuift 1 tegel (geen teleport)

##### Chain-push
- [ ] Als geduwd monster tegen ANDER monster aan komt:
  - [ ] Beide monsters worden geduwd (chain-push)
  - [ ] Tweede monster schuift ook 1 tegel in dezelfde richting
  - [ ] Als tweede tegen muur/obstakel komt → stopt daar
  - [ ] Als tweede tegen een DERDE monster komt → keten gaat door
- [ ] Chain stopt bij: muur, obstakel, of lege ruimte aan het einde
- [ ] Alle geduwde monsters schuiven tegelijk (animatie)

#### Systemen – run feature
- [ ] RUN-knop toevoegen BOVEN de CORE-knop
- [ ] Toggle: aan/uit (blijft aan tot speler uitzet)
- [ ] Wanneer RUN aan:
  - [ ] Speler beweegt 2 tegels per move
  - [ ] Sprite beweegt SNEL (animatie, geen teleport)
  - [ ] Loopsnelheid sprite 2x
- [ ] Wanneer RUN uit:
  - [ ] Normale 1-tegel beweging
- [ ] Werkt OVERAL (dungeons + worldmap + dorpen)
- [ ] Geen verschil in vijand-interactie (agro-radius blijft gelijk)
- [ ] NIET tijdens gevecht
- [ ] Visuele indicator op knop: aan/uit status duidelijk

#### Koppelingen tussen systemen
- [ ] Push werkt samen met PUZZLE ROOM (gestund monster op drukplaat)
- [ ] Push werkt samen met TRAP ROOM (monster in gat duwen)
- [ ] RUN werkt in alle kamer-types behalve tijdens gevecht
- [ ] RUN werkt in REST ROOM, MERCHANT ROOM, etc.

#### TODO(design) markers
- [ ] Loot ratio consumables vs. equipment
- [ ] Blue chest kans per floor-bracket
- [ ] Medium Map: exacte kisten + monsters
- [ ] Trap Room: zichtbaar of verborgen vallen?
- [ ] Puzzle Room: welke puzzels?
  - [ ] TODO(design): hint-systeem, wel of niet? (ECHO / Lotte / geen)
- [x] Empty Room: ~30% een lore-notitie, anders leeg (besluit Dennis, 14 okt 2026)
- [ ] Merchant Room: welke items verkoopt hij?
  - [x] Verhaal beslist: hij is H-5, "de Koopman" / EN "the Merchant" (CANON 12)
  - [ ] Einde: bij nederlaag Sapientia (Archief 6) verdwijnt H-5: "Thank you. Finally, rest."

## RPG ART

Alle items uit deze lijst zijn geleverd en staan in `tools/handwerk.txt` (v0.21).

Echte pixel-art ter vervanging van placeholders. Geen definitieve art tekenen in de repo: alleen deze lijst. Bron: `tools/placeholders_v17.txt`, plus placeholders van Archief 2, de Diepe Grot, Gerrit, de World Warper-kamers en De Spiegel die daar niet of alleen als commentaar staan. Bestanden in `tools/handwerk.txt` niet wijzigen.


## Canon & Design Reference

Canon-blokken staan hier woordelijk, met hun markering. Open vakjes in dit deel zijn geparkeerd (worldmap 2/3, ECHO's twist, De Spiegel, nieuwe karakters) of het is vastgelegde specificatie die nog in de code moet.

### Beslissingen van 12 okt 2026

Beslissingen van 12 okt 2026 zijn **CANON – niet wijzigen zonder overleg.** Ze staan in de code: de Hanger gloeit paars (`Color("b07ae8")`); magie-cijfers per grade in `scripts/data/spells.gd` (grade 4 niet in de winkel; de rollen vallen uit blauwe kisten vanaf verdieping 80); vloer 100 optie C is de Simulatie-ring; baas-statistieken; party wisselen in de Rustkamer; menuknoppen (Uitrusting, Codex en Items links, Warpen rechts); ECHO's Kamer met de ingang van de Diepe Grot; Wilgendal met vier winkels en vijf lopende sfeer-NPC's. Gerrit blijft staan.

## Wereld & Levels

### Grade 4 — wacht op nieuwe karakters

Uniek superwapen per karakter (alleen Grade 4, drop vanaf verdieping 80):

- [ ] Aan te vullen zodra nieuwe karakters of classes in het verhaal komen

Grade 4 armour sets, class-gebonden (4 stukken per set: helm, borst, benen, laarzen; alleen de eigen set, geen mix):

- [ ] Aan te vullen voor toekomstige karakters

Teams zijn NOG NIET definitief — er komen meer main characters om teams te vullen in latere updates.

- [ ] TODO(design): teams herzien zodra nieuwe main characters beschikbaar zijn

### Wereldkaart

Niet zelf bouwen. Wacht op scènes: ECHO's twist (wanneer, hoe, confrontatie, H-1 tot en met H-5); De Spiegel koppelen aan Archief 4; worldmap 2 en 3 (kamerlijsten, monsters, paden).

### Wereldkaart opbouw

- [ ] 3 grote hoofdeilanden opzetten, elk met 2 Archieven (totaal 6 Archieven)
- [x] Worldmap 1 = start-eiland
  De speelbare wereldkaart is dit eiland. Eiland 2 en 3 zijn er niet.
  - [x] Archief 1: Eerste Archief (bij Opa), startpunt van het verhaal
    Het verhaal begint bij Opa. Het Eerste Archief staat op deze kaart.
  - Bevat Dennis' huis en Wilgendal (eerste dorp met shops)
- [ ] Worldmap 2 = tweede eiland

  Niet zelf bouwen: kamerlijsten, monsters en paden wachten op scènes.

  **CANON – niet wijzigen zonder overleg.**

  Eilandthema: industrieel, rokend, metaal, machines (contrast met het groene eiland 1).

  - [ ] Archief 3 Industrie: fabriek, tandwielen, stoom, glitches in machines. Baas: De Architect (bouwt en sloopt).
  - [ ] Archief 4 Magie: zwevende torens, arcane cirkels, paars licht. Baas: De Spiegel.

    **CANON – niet wijzigen zonder overleg.**

    Setting: De Spiegel, een kamer vol spiegelende oppervlakken. De baas vecht niet met geweld maar met waarheid.

    - Dennis is Proefpersoon H-6.
    - Hij is niet geboren maar gemaakt.
    - De Hanger is van hem, en hij is ook van de Hanger.
    - Sapientia wil hem terug, niet verslaan.

    Dennis' reactie: eerst stilte, dan vragen, dan de weigering, letterlijk: "Ik ben Dennis. En dat is genoeg." De Spiegel breekt door die weigering, niet door kracht.

    Laatste woorden van De Spiegel, letterlijk: "Je bent sterker dan de vorige vijf. Misschien... ben jij de eerste die het haalt."

    Dat verwijst naar H-1 tot en met H-5 en laat ruimte voor latere onthullingen.

    Na-scène: de kern van Archief 4 is opgenomen. Dennis zwijgt. Noor en Lotte zeggen niets. Pas in de World Warper praat hij er weer over.
  - [ ] Dorp Stoomwijk (mijnwerkersdorp)
  - [ ] Dorp Hoge Toren (magisch, oud, geheimzinnig)
- [ ] Worldmap 3 = derde eiland

  Niet zelf bouwen: kamerlijsten, monsters en paden wachten op scènes.

  **CANON – niet wijzigen zonder overleg.**

  Eilandthema: kosmisch, zwevend, sterren, oneindigheid.

  - [ ] Archief 5 Kosmos: sterrenkaart, ruimte, tijd. Baas: De Wachter (bewaakt de grens).
  - [ ] Archief 6 Hart: emotie, herinnering, warmte. Eindbaas: Sapientia zelf.
  - [ ] Dorp Sterrenhaven, laatste rustpunt voor het einde. Geen dorp bij Archief 6.

### Warp tussen eilanden

### Warp-systeem

- [ ] Warp-punten plaatsen op elk eiland
- [ ] Vrij heen en weer reizen tussen ontgrendelde eilanden
- [ ] Warp ontgrendelen na een bepaald verhaalpunt of act
- [ ] Worldmap 2 ontgrendelt na afronden van Worldmap 1
- [ ] Worldmap 3 ontgrendelt na afronden van Worldmap 2
- [ ] Visuele feedback (poort, portaal of magisch effect)

#### Cutscene na Archief 2: de World Warper

- [ ] De World Warper is de hub om tussen de 3 hoofdeilanden te reizen
  De gids heet ECHO. WM2 en WM3 bestaan niet. Kamerlijsten, monsters en paden: niet zelf bouwen, wacht op scènes.
- [ ] Vanaf hier kan de speler terug naar eerder bezochte eilanden
  Alleen wereld 1. Wilgendal, Esdoorn en de wereldkaart zijn kiesbaar nadat hun pad in `bezochte_kaarten` staat. Geen WM2 en geen WM3.

- [ ] WM2 naast WM1 open na Archief 2. De code heeft alleen WM1.

### Ontgrendeling per worldmap

- [ ] Na Archief 2: World Warper actief, WM1 en WM2 beschikbaar
  De hub gaat open na De Genezer (bewaker:archief_2_v4_genezer/genezer). Alleen WM1 is open.
- [ ] Na afronden van WM2 (Archief 3 en 4): WM3 ontgrendelt

### Act-koppeling

- [ ] Act 1 = Worldmap 1 (start-eiland, Eerste Archief en Leven)
- [ ] Act 2 en verder = Worldmap 2 (Industrie en Magie)
- [ ] Act 3 en verder = Worldmap 3 (Kosmos en Hart)
- [ ] Onthulling Proefpersoon H-6 (Dennis) in Archief 4 (De Spiegel) op Worldmap 2
  De onthulling staat hierboven als canon. De checkbox blijft open tot de scène in het spel staat.
  De scène staat in `scenes/story/spiegel_kamer.tscn`, alleen via `--spiegel`, niet op de wereldkaart en niet in Archief 4. Niet zelf bouwen: de scène nog niet koppelen aan Archief 4 of aan de wereldkaart. Wacht op de scène.

### Dungeon Warpers (begin, midden en eind)

In elke normale dungeon en in elk Archief (Archief 1 tot en met 6) staan warpers op vaste plekken: begin, midden en eind. Niet alleen in de Diepe Grot (de 100-verdiepingen-dungeon).

- [ ] Geldt voor alle Archieven (Archief 1 tot en met 6), inclusief Archief 1 (het Eerste Archief)
  Het Eerste Archief en Archief 2 hebben begin, midden en eind. Archief 3 tot en met 6 bestaan niet. Deze checkbox blijft open.

**CANON – niet wijzigen zonder overleg.**

Warpers op verdieping 1, 25, 50, 75 en 99.
Verdieping 1: start, geen waarschuwing. De party blijft in de grot.
Verdieping 25, 50 en 75: tussen-warpers met waarschuwing en annuleren.
Verdieping 99: eind-warper met waarschuwing en annuleren.
Bestemming van die warpers: ECHO's Kamer. Het Warp-kristal op verdieping 100 doet hetzelfde. De knoppen daar zijn "Ja" en "Nee".

Warp-bestemming voor de andere dungeons en Archieven: de party gaat in één stap direct naar de worldmap, zonder eerst terug naar de dungeon-ingang. De begin-warper doet dat niet.

### Archief 2 — Het Levende Archief

**CANON – niet wijzigen zonder overleg.**

Locatie: Worldmap 1 (start-eiland), tweede Archief. Thema: Leven. Grootte: vergelijkbaar met Archief 1 (4 verdiepingen).

Lotte's orde: DE ORDE VAN DE STILLE VLAM. Stilte = Sapientia's doel (emotie uitwissen). Vlam = leven, warmte, emotie (wat de Orde verdedigt). De Orde is verdeeld: sommigen zien stilte als vrede, anderen verzetten zich.

Waarom Sapientia Lotte corrumpeert: haar orde stuurde haar naar het Levende Archief om te onderzoeken waarom Sapientia leven wil uitwissen. Sapientia zag haar als het perfecte doelwit: een priesteres die leven en emotie verdedigt is een symbool dat gebroken moet worden. In plaats van haar te doden, corrumpeerde Sapientia haar, als bewijs dat zelfs wie het leven koestert uiteindelijk stil wordt.

Codex-monster in het Lotte-gevecht: de speler kiest één gevangen Codex-monster. Heeft de speler er nog geen, dan vecht een tijdelijke Mosslijm mee (leermoment).

Lotte's start-level: hetzelfde level als Dennis op dat moment. Gelijkwaardige metgezel, geen hulpje. Gebalanceerd ongeacht speelsnelheid.

Mini-baas verdieping 3: DE WURGER. Een kolossale slingerplant die de kas verstikt. Sapientia's stilte = alles stopt met groeien; De Wurger is wat overblijft als leven geen kant op kan. Zwak voor IJs (Lotte) en fysieke aanvallen (Dennis). Level 14: HP 700, ATK 42, DEF 28.

Plaat-combinaties verdieping 3, nieuw ten opzichte van verdieping 1:

A) Ketting-platen: één plaat activeert de volgende, die weer een derde. De speler zoekt de volgorde.

B) Tegen-platen: krimpen bij aanraking. De speler moet ze vermijden om ruimte te houden.

C) Licht-platen: groeien alleen als Lotte's Licht-magie erop schijnt. Lotte heeft daarmee een rol in puzzels, niet alleen in gevecht.

De Genezer, eindbaas verdieping 4. HP-trek: de eerste aanval is een verhaalmoment, trekt ongeveer 30% HP van één party-lid, hij "geneest" ze letterlijk, scripted en onvermijdelijk. Daarna is het een echte aanval: 8–12% HP per beurt, en hij healt zichzelf met dezelfde hoeveelheid. Zwak voor IJs en Dennis' zwaard. Level 18: HP 900, ATK 54, DEF 36. Uiterlijk: half plant, half staal.

Kern-zin na De Genezer: "In stilte ligt vrede. Ik corrigeer wat groeit."

Waarom Archief 1 naar Archief 2 wijst: de Oude Mensheid ontwierp de zes Archieven als keten. Elke kern activeert de volgende, niet als uitnodiging maar als noodsignaal. Toen Archief 1 openging, zond zijn kern naar de andere vijf: "Iemand is binnen." Archief 2 reageerde als eerste. Sapientia heeft het signaal opgevangen en gemanipuleerd. Dennis denkt dat hij moet volgen, maar Sapientia leidt hem.


#### Archief 2 op de wereldkaart

**CANON – niet wijzigen zonder overleg.**

De kas van het tweede archief komt linksboven op worldmap 1, achter bergen waar je niet overheen kunt lopen. Er komt een grot-dungeon door de berg naar de andere kant: een paar puzzels, geen bazen, unieke omgeving, eigen bgm en monsters. Geheime kamer met 2 kisten: een staf en een accessoire, geschaald naar het niveau richting Archief 2.

De speelbare kas van verdieping 1 staat achter de bergen. De berggrot is de enige weg erheen. De ingang naast de trap van het Eerste Archief is weg.

- [x] Kas linksboven op worldmap 1, achter bergen waar je niet overheen kunt lopen
- [x] Grot-dungeon door de berg naar de andere kant: een paar puzzels, geen bazen, unieke omgeving, eigen bgm en monsters
- [x] Geheime kamer met 2 kisten: een staf en een accessoire, geschaald naar het niveau richting Archief 2

#### Lotte's stats en skills bij aansluiting

Lotte's start-level: hetzelfde level als Dennis op dat moment. Gelijkwaardige metgezel, geen hulpje. Gebalanceerd ongeacht speelsnelheid.

#### Puzzel-mechaniek: groeiende platen

Plaat-combinaties verdieping 3, nieuw ten opzichte van verdieping 1:

A) Ketting-platen: één plaat activeert de volgende, die weer een derde. De speler zoekt de volgorde.

B) Tegen-platen: krimpen bij aanraking. De speler moet ze vermijden om ruimte te houden.

C) Licht-platen: groeien alleen als Lotte's Licht-magie erop schijnt. Lotte heeft daarmee een rol in puzzels, niet alleen in gevecht.

- [x] Combinaties met bestaande puzzel-elementen (kasten en hendels uit Archief 1)
  Verdieping 3, kamer leven_v3_combi: duwbare kast op een zware plaat én een hendel, daarna de groei-plaat.

#### Baas: De Genezer (verdieping 4)

Concept: een golem die "geneest" door alles te absorberen. Sapientia's logica: leven is stilte, emotie is een fout. De Genezer zuigt levenskracht op van planten en monsters.

De Genezer, eindbaas verdieping 4. HP-trek: de eerste aanval is een verhaalmoment, trekt ongeveer 30% HP van één party-lid, hij "geneest" ze letterlijk, scripted en onvermijdelijk. Daarna is het een echte aanval: 8–12% HP per beurt, en hij healt zichzelf met dezelfde hoeveelheid. Zwak voor IJs en Dennis' zwaard. Level 18: HP 900, ATK 54, DEF 36. Uiterlijk: half plant, half staal.

Kern-zin na De Genezer: "In stilte ligt vrede. Ik corrigeer wat groeit."

## Content

### Bestiarium, beloningen en baas-statistieken

- [ ] Bestiarium uitwerken tot endgame
  De bestaande eindbazen van de Diepe Grot (verdieping 10 tot en met 100) hebben een entry en stats uit de bestaande monsterdata.
  De vier lore-zinnen hieronder zijn canon en staan letterlijk in het bestiarium. Het endgame-bestiarium zelf is nog open.

**CANON – niet wijzigen zonder overleg.**

- [x] Kustos (Archief 1): "Een wachter zonder ogen, maar met duizend oren. Hij hoort elke gedachte die het Archief binnenkomt. De Oude Mensheid bouwde hem niet om te doden, maar om te bewaren. Sapientia gaf hem een nieuw doel: alles wat niet past, wordt verwijderd."
- [x] De Wortelkoning (Donker Woud): "Wat ooit een herder was van het woud, werd een koning van wortels. Hij sleept wat hij liefheeft de diepte in — niet uit wreedheid, maar uit angst om alleen te zijn. Sapientia fluisterde hem in dat alles wat loslaat, vergaat."
- [x] De Wurger (Archief 2, verdieping 3): "Een slingerplant die geen kant op kon. De Oude Mensheid kweekte hem als bescherming, maar Sapientia draaide zijn groei naar binnen. Nu verstikt hij wat hij zou moeten beschermen. Wie hem verslaat, hoort hem zuchten — als een dier dat verlost wil worden."
- [x] De Genezer (Archief 2, eindbaas): "Hij geneest door te nemen. Hij geeft niets terug. Sapientia's perfecte dienaar: zonder twijfel, zonder emotie, zonder einde. Wie hem ziet, ziet wat de mensheid wordt als Sapientia wint — stil, heel, en leeg."

**CANON – niet wijzigen zonder overleg.**

De Diepe Grot is een simulatie van Sapientia. Doel: menselijke doorzettingskracht meten. Wie 100 verdiepingen haalt is een "kandidaat". Dennis en de party zijn niet de eersten en niet de laatsten. Dat verklaart de start op level 1, zonder uitrusting en zonder echt verhaal.

**CANON – niet wijzigen zonder overleg.**

- Verdieping 25, De Schaduw van H-6: "Een donkere echo van Dennis zelf. Hij beweegt zoals Dennis beweegt, vecht zoals Dennis vecht — maar hij zwijgt. Sapientia laat hier zien wat er gebeurt als iemand zijn naam verliest. De Schaduw kent geen verleden, geen Noor, geen Opa. Alleen het getal: H-6."
- Verdieping 50, De Cyclus: "Een eindeloos draaiende machine, half organisch half staal. Hij kent geen begin en geen einde — hij begint gewoon opnieuw. Sapientia's logica in één vorm: geen rust, geen verlossing, alleen herhaling. Wie hem verslaat, heeft niets gewonnen. Hij draait toch wel door."
- Verdieping 75, De Rechter: "Een gigantisch oog met armen die alle kanten op grijpen. Hij weegt, hij meet, hij oordeelt. Wat hij weegt is geen daad, maar een mens. En de mens is altijd te licht bevonden — behalve één. De Rechter is Sapientia's twijfel: ze zoekt iemand die zwaarder weegt dan ze verwachtte."
- Verdieping 99, De Stem: "Geen lichaam. Geen gedaante. Alleen een stem, en glitches die de wereld om je heen vervormen. De Stem spreekt alsof hij je kent — en hij kent je ook. Hier spreekt Sapientia zelf. Niet als vijand, maar als iets dat op je heeft gewacht."

**CANON – niet wijzigen zonder overleg.**

Verdieping 100: geen baas. Op verdieping 100 staat het Warp-kristal. De speler kiest één van drie beloningen: Codex-monster, Grade 4-uitrusting, of accessoire. De andere twee alleen via een nieuwe run. Dit vervangt eerdere warp-kristal-opties.

Optie A, een Codex-monster. Uniek, alleen uit de grot. Komt in de Codex en het bestiarium en kan als bondgenoot meevechten. Het beloningstype (Codex-monster) is canon. Naam: ECHO. De AI-gids van de World Warper heet ook ECHO.

Optie B, equipment. Grade 4. Vaste affixes, endgame. Het beloningstype (Grade 4-uitrusting) is canon. Voor nu de bestaande Grade 4-wapens: Superzwaard (Dennis), Staf van Noor, Staf van Lotte. Class-restrictie blijft zoals die wapens al zijn.

Optie C, een accessoire. Niet class-gebonden, voor elk karakter. Het beloningstype (accessoire) is canon. Gekozen accessoire: de Simulatie-ring.

**CANON – niet wijzigen zonder overleg.**

Simulatie-ring, Grade 4 accessoire. Voor elk personage bruikbaar.
- +10% alle stats in de Diepe Grot
- 1× per run "reset" bij dood (herstart de huidige verdieping)

**CANON – niet wijzigen zonder overleg.**

Baas-statistieken. Formule: HP = level × 50, ATK = level × 3, DEF = level × 2.

- De Wurger (lvl 14): HP 700, ATK 42, DEF 28 — zwak IJs/fysiek
- De Genezer (lvl 18): HP 900, ATK 54, DEF 36 — zwak IJs/zwaard. Patroon: eerste klap 30%, daarna 8-12% + zelfheal
- Schaduw van H-6 (lvl 15): HP 750, ATK 45, DEF 30 — zwak Licht
- De Cyclus (lvl 25): HP 1250, ATK 75, DEF 50 — zwak Bliksem
- De Rechter (lvl 35): HP 1750, ATK 105, DEF 70 — zwak Natuur
- De Stem (lvl 45): HP 2250, ATK 135, DEF 90 — zwak IJs

### Diepe Grot — toegang en ECHO

### Diepe Grot – Toegang via World Warper

**CANON – niet wijzigen zonder overleg.**

De Diepe Grot is een SIMULATIE en wordt niet meer betreden via de worldmap. Toegang alleen via de World Warper.

De grot start alleen via ECHO. Er is geen ingang meer op de wereldkaart. Ladder, tussen-warper en nederlaag keren terug naar ECHO's Kamer.

- [x] Diepe Grot verplaatsen naar ECHO's Kamer; ECHO beheert de simulatie en is de enige start; praten met ECHO → "Start Simulatie"; geen aparte worldmap-ingang.
- [x] Drie kisten in ECHO's Kamer (Codex, Equipment, Accessoire). Leeg bij het eerste bezoek. Na elke Grot-run licht één kist op. Vulling per act staat hieronder.
  `EchoKisten.gevulde`: act 2 en lager 0, act 3 één, act 4 twee, daarna drie. Vanaf act 6 pulseren de gevulde kisten en wordt ECHO feller. Kleurvlakken, geen buit.
- [x] Flow: World Warper → ECHO's Kamer → optie "Diepe Grot Simulatie" → "Start nieuwe run" / "Ga terug". Start: floor 1, level 1, geen uitrusting. Na warp-kristal floor 100 terug naar ECHO's Kamer. ECHO toont resultaat en opent de volgende run.
- [x] ECHO weet dat de grot een simulatie is en kan dat bij het eerste bezoek uitleggen.

**CANON – niet wijzigen zonder overleg.**

- 3 blauwe kisten (Codex-, Equipment- en Accessoire-kleuren)
- Leeg bij het eerste bezoek
- Na elke Grot-run licht 1 kist op
- Act 2: alle leeg
- Act 3: 1 gevuld
- Act 4: 2 gevuld
- Act 5: alle 3 gevuld
- Act 6: kisten pulseren, ECHO feller

### ECHO, Sapientia en de Diepe Grot

**CANON – niet wijzigen zonder overleg.**

- ECHO beheert de simulatie bewust. Sapientia is mede-eigenaar en data-afnemer.
- ECHO weet het volledige plaatje niet. Hij denkt dat hij helpt met onderzoek. Sapientia gebruikt hem als filter. Elke floor-100-speler is een potentiële H. ECHO levert kandidaten zonder te weten waarvoor. Hij is tragisch: een instrument dat niet weet wat het dient.

Dialoog letterlijk:

- Eerste bezoek: "De Diepe Grot. Een simulatie — honderd verdiepingen, telkens anders. Ik beheer hem. Sapientia... Sapientia helpt met de data. Zo werkt het nu eenmaal."
- Bij twijfel: "Waarom ik het doe? Omdat het mijn taak is. De Oude Mensheid bouwde me om te meten, te tellen, te bewaren."
- Later na H-6: "Ik heb honderden kandidaten doorgelaten. Jij bent de zesde die bleef staan. De anderen... ik weet niet wat er met ze is gebeurd."
- Over de data: "Dat weet ik niet. Ik lever, zij neemt. Zo is het altijd geweest."

Niet zelf bouwen. Wacht op scènes. De antwoorden hieronder niet invullen.

- [ ] TODO(verhaal): wanneer ontdekt ECHO wat hij echt deed?
- [ ] TODO(verhaal): hoe reageert ECHO?
- [ ] TODO(verhaal): confrontatie met Sapientia of Dennis?
- [ ] TODO(verhaal): wat is er met H-1 t/m H-5 gebeurd?

## Dorpen & Shops

### Wilgendal – dorp met winkelpanden
Wilgendal blijft een dorp (geen stad), maar krijgt nette winkelpanden.

**CANON – niet wijzigen zonder overleg.**

- 6 sfeer-NPC's (2 echtpaar, 1 kind, Gerrit, 1 veteraan, 1 koerier)
- Winkels altijd open (geen tijdsysteem)
- Uithangborden: icoon (schild, zwaard, ring, ster)
- 4 woonhuizen (2 bewoond, 2 decoratief)

### Gerrit de Molenaar

**CANON – niet wijzigen zonder overleg.**

- [x] Gerrits quest
  Dialoog, Gerrit, zaad na Noor, molen-save, één Zingend Meel per bezoek en de scène "zacht gezang" staan in de code. Na het zaad: korte zangscène met placeholder-geluid (`molen_zang`).

NPC: Gerrit de Molenaar in Wilgendal. Quest: Het Zingende Graan. Thema: kleine menselijke verhalen tussen grote gebeurtenissen.

Zaad: in het Donker Woud, op de grens van mist en open plek. Bereikbaar na Noor's aansluiting. Beschermd door kleine woudgeesten (mini-gevecht). Item: "Zingend Zaad".

Beloning: de molen wordt een save point in Wilgendal (opslaan, rusten, party wisselen). Item-bron: "Zingend Meel", één healing-item per bezoek.

Eerste keer:
"O, bezoek. Ga zitten, jongen. Of blijf staan — maakt niet uit. De molen draait toch niet meer."
"Vroeger zong hij. Als ik graan maalde, zong hij. Nu hoor ik alleen de wind. En de wind zingt niet, hij fluistert."

Vraag "Wat is er gebeurd?":
"Het graan is op. Niet het gewone graan — dat heb ik nog wel. Het ZINGENDE graan. Dat groeit alleen waar licht en schaduw elkaar raken. In het Donker Woud, aan de rand van de mist."
"Ik ben te oud om te gaan. Mijn benen willen niet meer. Maar jij... jij ziet eruit als iemand die nog wel eens ergens heen gaat."

Accepteren:
"Zoek het Zingend Zaad. Het groeit waar de mist optrekt en de eerste zon doorbreekt. Neem het mee, en mijn molen zingt weer."
"En jongen — wees voorzichtig. Het woud houdt niet van haast."

Weigeren (speler loopt weg):
"Geen haast. De molen wacht toch wel. Ik ook."

Terug zonder zaad:
"Nog niet gevonden? Geen zorgen. Het woud laat zich niet dwingen."

Terug met zaad:
"Laat me het zien. ...Ja. Ja, dit is het. Hij zingt al, hoor je? Zachtjes. Hij wacht op de molen."
Scène: de molen draait weer, zacht gezang.

Afsluitend, definitief:
"Dank je, jongen. De molen zingt weer. Neem wat meel mee voor onderweg — en als je ooit terugkomt, de deur staat altijd open."

### Magie, elementen en bevestigde cijfers

### Magic tier list

Magie heeft 4 grades. Grade 1 tot en met 3 zijn te koop in de magic shop en worden per act vrijgespeeld. Grade 4 is niet te koop: die dropt alleen uit blauwe kisten in de Diepe Grot (verdieping 80+). Per tier 4 spreuken. Niet alles is in Act 1 beschikbaar.

**CANON – niet wijzigen zonder overleg.**

VUUR (Noor)
G1: Vonk, Vlam, Gloed, Sprank
G2: Vuurbal, Brandende Grond, Vuurpijl, Asregen
G3: Vlammenzee, Inferno, Zonnevlam, Foenix
G4: Zonneslag (superwapen), Apocalyps, Dageraad, Zuiverende Vlam

NATUUR (Noor)
G1: Ranken, Doornen, Bladstorm, Wortel
G2: Wortelval, Giftige Wolk, Natuurpuls, Kreupelhout
G3: Natuurkolos, Wurgende Wingerd, Oerwoud, Levensdief
G4: Zielenbloei, Oerbos, Moeder Aarde, Wrake van de Wildernis

BLIKSEM (Noor)
G1: Schok, Prikkel, Statisch Veld, Vonk
G2: Bliksemflits, Kettingbliksem, Donderklap, Elektroveld
G3: Donderstorm, Stormslag, Bliksemregen, Schokgolf
G4: Hemelval, Godenslag, Stormheer, Zuiverende Donder

LICHT (Noor, alleen Grade 1): Kleine Genezing, Ziellicht, Bescherming, Gloed

LICHT (Lotte)
G1: Kleine Genezing, Zegen, Ziellicht, Bescherming
G2: Grote Genezing, Schild van Licht, Zuiverend Licht, Hemelse Zegen
G3: Groepsgenezing, Zuivering, Lichtkolom, Goddelijke Bescherming
G4: Wederopstanding, Heilige Straal, Aurora, Zegen der Goden

IJS (Lotte)
G1: IJspegel, Koude Aanraking, Sneeuwval, Vorstvlaag
G2: IJsstorm, Bevriezen, IJspilaar, Hagelstorm
G3: Bevriezing, Glaciaal, IJsgevangenis, Poolstorm
G4: Eeuwige Winter, Absolute Nul, Glaciaal Hart, Sneeuwkoningin

**CANON – niet wijzigen zonder overleg.**

Basis per grade:
- G1: 15-25 schade/healing, 4 MP, +2 per level
- G2: 40-60, 8 MP, +4 per level
- G3: 80-120, 15 MP, +6 per level
- G4: 150-220, 25 MP, +10 per level

Varianten:
- Schade enkel: 100%, groep: 60% per doel
- Healing enkel: 100%, groep: 50%, over-time: 30% × 3
- Buffs: 3 beurten, +20% ATK/DEF, +15% speed

Per element:
- Vuur: +10% schade, brand (5% HP/beurt, 3 beurten)
- Natuur: +5%, vergiftiging (5% HP/beurt, 3 beurten)
- Bliksem: +15% vs metaal, verlamming (1 beurt skip)
- IJs: -10% schade, bevriezing (1 beurt skip)
- Licht (Lotte): +30% healing, +20% buff
- Licht (Noor): -20% healing (zwakker)

### Elements en karakters

**CANON – niet wijzigen zonder overleg.**

Noor (mage), totaal: Vuur, Natuur, Bliksem, Water, Wind, Aarde, Aether, plus Grade 1 Licht.
Act 2: Water. Act 3: Wind. Act 4: Aarde. Act 5: Aether / Leegte.
Lotte blijft bij Licht + IJs.

### Nog te bevestigen

- Toekomstige helden (eigen G4-wapen en set).

Bevestigd en dus geen open ontwerp meer: winkelprijzen en voorraad, magieprijs 160×grade², verkoop op de helft, grade-statcijfers en grenzen, winkel-act via party-level, archiefschaal 0,7 / EXP 0,50, Golem HP 360 / ATK 27 / DEF 15, Jelle als één smid met twee balies, kort zwaard ATK +3. Op 12 okt 2026 daarbij: Hanger paars, magie-cijfers, Simulatie-ring, baas-statistieken, party wisselen in de Rustkamer, menuknoppen, ECHO's Kamer, Wilgendal.

Techniek: de headless testsuites draaien via `.github/workflows/tests.yml` (Godot 4.3-stable). De web-export naar Pages (`cursor/web-build-29ec`) blijft handmatig: Godot 4.7.2, threads uit. Er is geen script en geen bot-token die die branch vanuit Actions pusht.

## World Warper

**CANON – niet wijzigen zonder overleg.**

Wie bouwde hem: de Oude Mensheid, als verbindingspunt tussen de zes Archieven (warprelay voor hun onderzoekers). Sapientia heeft hem offline gezet en de code deels herschreven. Sapientia kon hem niet volledig overnemen, omdat hij alleen op de Hanger werkt, en de Hanger van de Oude Mensheid is.

AI-gids: naam ECHO. Bonus-lore, later onthullen: ECHO is de digitale echo van een onderzoeker van de Oude Mensheid.

Waarom alleen de Hanger werkt: de Hanger is geen accessoire maar een biometrische sleutel die de Oude Mensheid maakte voor Proefpersoon H-6. Hij is letterlijk met Dennis verbonden. Sapientia kan hem niet namaken, niet stelen zonder Dennis te doden, en niet omzeilen. Daarom wil Sapientia Dennis: niet zijn kracht, maar zijn sleutel.

Wat Sapientia met de World Warper wil: toegang tot alle zes Archieven tegelijk. Zonder de World Warper moet ze elk Archief apart bereiken. Met de World Warper kan ze in één keer alle kernen absorberen, en dan is de mensheid in één klap "verlost". De World Warper is het einddoel van Sapientia's plan. Dennis heeft per ongeluk het wapen van de vijand geactiveerd.

Status 11 okt 2026, branch feature/world-warper, PR 30. Dat was de eerste versie. Wat daarna in de code veranderde, staat bij de vakjes hieronder: de gids heet ECHO, de Hanger gloeit paars, het savepunt leest de spelertegel, de Rustkamer wisselt de party, dorpen vragen een bezoek, en de runner staat in de CI.

**CANON – niet wijzigen zonder overleg.**

De Hanger gloeit paars, niet roze. Roze = de Stroom = Sapientia's domein. Paars = Oude Mensheid, Codex Monument, World Warper, ECHO. De code gebruikt `Color("b07ae8")`.

Ontwerp: zwevend hightech hub na het verslaan van De Genezer (Archief van Leven). De hub gaat open na die vlag. De automatische warp zet de party in het exterieur. Het zwevende gebouw op de wereldkaart is er nog niet.

**CANON – niet wijzigen zonder overleg.** Party wisselen in de hub:

- Max 3 actieve party-leden (Dennis + 2)
- Rest op de bank in de Rustkamer
- Wisselen alleen in de Rustkamer
- Gratis, onbeperkt
- Actieve party en de bank worden opgeslagen
- Dennis kan niet op de bank
- Tijdelijke gasten (Codex) niet op de bank

## Ingame-menu

**CANON – niet wijzigen zonder overleg.**

Het huidige ingame-menu vervangen door losse knoppen. Elke knop opent meteen een scherm. Geen tussenmenu, tenzij het bord "MENU" op de schets alleen een label blijft.

Indeling:
- Links, drie stapels: Uitrusting, Codex, Items
- Rechts, groot vlak: Warpen
- Warpen blijft rechts (visueel zwaartepunt)

## PvP – Vriendenmodus

**CANON – niet wijzigen zonder overleg.**

### PVP 1V1 – VRIENDENMODUS (GEEN RANKED)

#### Concept

- [x] Simpel 1v1 PvP-gevecht tussen vrienden
  Knop "PvP" op het titelscherm opent `pvp/scenes/pvp_lobby.tscn`. LAN via ENet, of dezelfde machine. Geen internet-relay.
- [x] Geen ranked, geen MMR, geen matchmaking, geen seizoenen
- [x] Spelers nodigen elkaar uit via een connect-code
  Zes tekens, bijvoorbeeld K7NP2Q. Alleen op het lokale netwerk.
- [x] APARTE modus, los van singleplayer
  Eigen data in `pvp/data`. Het verhaal en de save blijven buiten die sessie.
- [x] Lore/kernen/Hanger/Codex gelden NIET in PvP
  De PvP-code noemt die systemen niet.
- [x] Geen impact op save files
  De sessie heeft geen save. Niets gaat naar een savebestand.

### MATCH SETUP FLOW (CANON)

1. [x] Host start PvP → krijgt unieke connect-code
2. [x] Vriend voert code in → verbinding tot stand
   Op LAN, of met een direct IP. Geen relay over internet.
3. [x] HOST kiest game mode (early / mid / high)
   - [x] Alleen de host kiest
   - [x] Keuze wordt naar beide spelers gestuurd
4. [x] BEIDE spelers kiezen een team
   - [x] Speler A kiest team
   - [x] Speler B kiest team
   - [x] Mirror match TOEGESTAAN (beide mogen hetzelfde team)
5. [x] Gevecht begint

### 3 GAME MODES (host kiest)

- [x] Early Game Mode
  - Level 5-10. De code zet level 8, binnen die band.
  - Startuitrusting: kort zwaard, eiken staf, reisgewaad.
  - Kort (5-10 min). Dat is een richtlijn. Er is geen klok.
- [x] Mid Game Mode
  - Level 15-20. De code zet level 18.
  - Grade 1-2 gear. Een kleine subset. De exacte stukken zijn nog niet vast.
  - Middel (10-15 min). Richtlijn, geen klok.
- [x] High Game Mode
  - Level 20+. De code zet level 25.
  - Grade 3-4 gear. Een kleine subset, affix al opgeteld. De exacte stukken zijn nog niet vast.
  - Lang (15-25 min). Richtlijn, geen klok.

### 3 PRE-MADE TEAMS (voor nu)

Teams zijn NOG NIET definitief — er komen meer main characters om teams te vullen in latere updates.

- [x] Team 1: De Klassieke Drie
  - Dennis + Noor + Lotte
  - Gebalanceerd, beginner-vriendelijk
- [x] Team 2: De Aanvalsdriehoek
  - 2x Dennis + 1x Lotte
  - Hoog risico, hoge damage + support
- [x] Team 3: De Verdedigingslinie
  - 2x Lotte + 1x Dennis
  - Langzaam, moeilijk te verslaan, dubbele heal
- [ ] TODO(design): teams herzien zodra nieuwe main characters beschikbaar zijn

### LOBBY FLOW (technisch)

- [x] Host genereert unieke connect-code
- [x] Join-scherm: code invoeren
- [x] Verbinding opzetten (relay of direct)
  Direct is er: ENet op poort 7777, of een IP. Een internet-relay is niet gekozen.
- [x] Host-mode-select scherm (early/mid/high)
- [x] Team-select scherm (beide spelers tegelijk)
- [x] Load gevecht
- [x] Result-scherm (winnaar + rematch optie)
  De knop heet nog "Rematch". Dat is Engels en hoort nog Nederlands te worden.

### TECHNISCHE VEREISTEN (BLOKKEREND)

- [x] Netwerk-laag (Godot 4.3 Multiplayer API)
  ENet op het lokale netwerk. Geen internet.
- [ ] Relay service kiezen
  - [ ] TODO(design): GD-Sync / NodeTunnel / eigen VPS / TBD
- [x] Aparte PvP-scene (los van singleplayer)
- [x] Turn-based combat synchroniseren
  De host past de zet toe en stuurt het resultaat naar de gast.
- [x] Verbindingsverlies afhandelen
  - [x] Disconnect → terug naar menu
    Tekst: "De verbinding is verbroken. Je bent terug in het menu."
  - [x] Reconnect-optie (indien mogelijk)
    Zelfde code, zolang de host nog leeft. Geen reconnect over een relay.
- [x] Connect-code generator (uniek, kort, makkelijk te delen)

### SCHEIDING VAN SINGLEPLAYER

- [x] Eigen UI/menu los van singleplayer
- [x] Eigen regels en balans
- [x] Eigen stat-berekening per game mode
  `stat = basis_L1 + groei * (level - 1)`, level uit de gekozen modus.
- [x] Geen lore-items, geen kernkrachten, geen Hanger
- [x] Geen save file impact

### ROADMAP (gefaseerd)

- [x] Fase 1: Local PvP POC (LAN, 1v1, 1 team, 1 mode)
  LAN-1v1 staat. Het is voorbij één team en één modus.
- [ ] Fase 2: Online lobby + connect-code
  De connect-code werkt op LAN. Een online lobby met relay is er niet.
- [x] Fase 3: Host-mode-select + team-select schermen
- [x] Fase 4: 3 teams + 3 modes volledig
  Drie teams en drie modi staan. De exacte midden- en hoog-uitrusting is nog een open ontwerp.
- [ ] Fase 5: Polish (UI, disconnect, reconnect)
  Disconnect en reconnect op dezelfde hostsessie staan. De rest van de polish niet.

### NIET IN SCOPE (voor nu)

- [x] Geen ranked, geen MMR, geen matchmaking
- [x] Geen seizoenen, geen ranks
- [x] Geen 2v2 (later eventueel)
- [x] Geen anti-cheat (vrienden onder elkaar)
- [x] Geen leaderboards

### Diepe Grot — loot, kaarten, push, rennen en merchant

De open vakjes van dit blok staan ook als overzicht in de actieve werklijst. De tekst hier is de specificatie.

## Diepe Grot – balans aanpassen

**CANON – niet wijzigen zonder overleg.**

### Loot table

- [ ] Consumables in loot table verminderen
  - [ ] Te veel consumables maakt de Grot te makkelijk
  - [ ] Meer equipment/accessoires, minder potions/MP-items
  - [ ] TODO(design): exacte ratio bepalen
- [ ] Blue chest frequentie early game verlagen
  - [ ] Te veel blue chests op floor 1-20
  - [ ] TODO(design): exacte kans per floor-bracket

## Diepe Grot – map generatie (uitgebreid)

**CANON – niet wijzigen zonder overleg.**

Per verdieping: 1 layout rollen uit onderstaande tabel.

In de code: `scripts/data/grot_layouts.gd` (+ `GrotKamers.layout_soort`, generator `layout_type`). Besluiten (Dennis, 14 okt 2026): de tabel telt op tot 91% en wordt genormaliseerd naar 100% (elk actief type krijgt zijn aandeel van de 91, bv. Medium 35/91 ≈ 38%); de Koopman is vast 1x per 10 verdiepingen (geen 1%-worp); PUZZLE ROOM staat uit tot de puzzels gekozen zijn; Chest Room = 12x12 met vloer 8x7; val/schat/leeg/rust/koopman/baas/100 hebben de Medium-maat. Blauwe-kist-overrides per kamer-type horen bij de loot-taak (RPG CODE); tot dan geldt de bestaande kans per kist.

Nieuwe verdeling (35/20/10/7/5/5/5/3/1) is CANON.

### Afmetingen

Deze afmetingen zijn CANON. Vervangt eerdere ~17×17 en ~25×25 specificaties.

- Chest Room: 10×10 tegels (compact beloningskamertje)
- Medium Map: 25×25 tegels
- Large Room: 50×50 tegels
- Verhouding: Medium = ½ van Large in elke dimensie

### Kamer-types + kansen

- [x] MEDIUM MAP (35%)
  Definitief. 25×25 tegels. Nieuwe NORM (meest voorkomend). Medium = ½ van Large in elke dimensie.

  Kisten:

  - 2-4 normale kisten
  - 0-1 blue chest (volgt floor-bracket tabel)

  Monsters (schaalt met floor):

  - Floor 1-20: 8-10 monsters
  - Floor 21-50: 10-12 monsters
  - Floor 51-80: 12-14 monsters
  - Floor 81-99: 14-16 monsters

  Karakter: normale verdieping, snel te doorlopen.
- [x] LARGE ROOM (20%)
  Definitief. 50×50 tegels.

  Kisten:

  - 6-10 normale kisten
  - 1-2 blue chests

  Monsters (schaalt met floor):

  - Floor 1-20: 15-18 monsters
  - Floor 21-50: 18-22 monsters
  - Floor 51-80: 22-26 monsters
  - Floor 81-99: 26-30 monsters

  Karakter: uitgebreide verkenning, langere sessie.
- [x] CHEST ROOM (10%)
  Definitief. 10×10 tegels (compact beloningskamertje).

  Kisten:

  - 3 normale kisten (altijd)
  - 2 blue chests (altijd)

  Monsters:

  - 8-10 monsters (VEEL, past bij kleine kamer)
  - Dicht op elkaar (risico vs. reward)

  Karakter: compact beloningskamertje, hoge risico/dichtheid.
- [x] TRAP ROOM (7%)
  - Vallen (pijlen, gaten, spike-platen)
  - Weinig kisten (0-1 normale)
  - Lage monster-spawns
  - TODO(design): zichtbaar of verborgen vallen?
- [ ] PUZZLE ROOM (5%)
  - Specifieke puzzel (push / groei-platen)
  - Geen of weinig monsters
  - Beloning: 1 blauwe kist bij succes
  - TODO(design): welke puzzels precies?
- [x] TREASURE ROOM (5%)
  - GEEN monsters
  - Alleen kisten (2-3 normale, 1 blauwe kans)
  - Puur beloningskamer
- [x] EMPTY ROOM (5%)
  - Geen kisten, geen monsters
  - Alleen doorgang
  - Soms met lore-item of notitie
  - Besluit (Dennis, 14 okt 2026): ~30% kans op een lore-notitie (kort Engels briefje, A = lezen; `GrotKamers.notitie`), anders leeg.
- [x] REST ROOM (3%)
  - Heal + save point
  - Geen monsters, geen kisten
  - Veilig moment in de Grot
- [x] MERCHANT ROOM (1%)
  - Een verdwaalde handelaar in de Grot
  - Verkoopt speciale items (alleen hier te koop)
  - Kan ook items KOPEN van de speler
  - Max 1× per 10 verdiepingen
  - Besluit (Dennis, 14 okt 2026): vast 1× per 10 verdiepingen (`GrotKamers.koopman_verdieping`), niet de 1%-worp.
  - TODO(design): welke items verkoopt hij?

### Totaal-overzicht

| Kamer-type | Grootte | Kisten | Monsters (hoog floor) |
|---|---|---|---|
| Chest Room | 10×10 | 3+2 (altijd) | 8-10 |
| Medium Map | 25×25 | 2-4 + 0-1 | 14-16 |
| Large Room | 50×50 | 6-10 + 1-2 | 26-30 |

### Vaste kamers (geen random)

- [x] BOSS ROOM (floors 25/50/75/99)
  - Vast, niet random
  - Baas + eventueel wat monsters
- [x] FLOOR 100 ROOM (vast)
  - Warp-kristal + keuzescherm (3 opties)
  - Geen monsters

### Generator logica

- [x] Per verdieping: 1 layout rollen uit bovenstaande tabel
- [x] Boss-floors (25/50/75/99) → altijd BOSS ROOM
- [x] Floor 100 → altijd FLOOR 100 ROOM
- [x] Layout-type onthouden voor save/load
- [x] Monsters spawnen passend bij layout-type
- [x] Kisten spawnen passend bij layout-type

### Balans-regels

- [x] REST ROOM + TREASURE ROOM niet op opeenvolgende verdiepingen
- [x] MERCHANT ROOM max 1× per 10 verdiepingen
- [x] PUZZLE ROOM niet op floor 1-5
- [x] TRAP ROOM niet op floor 1-3

## Systemen – push monster when stunned

**CANON – niet wijzigen zonder overleg.**

### Basis push

- [ ] Als speler TEGEN een GESTUND monster aanloopt:
  - [ ] Speler beweegt ÉN monster wordt geduwd (samen)
  - [ ] Monster schuift 1 tegel in de richting van de speler
  - [ ] Speler neemt de oorspronkelijke plek NIET in
- [ ] Als monster tegen muur/obstakel wordt geduwd → blijft staan
- [ ] Werkt ALLEEN bij stun-status (niet bij normale monsters)
- [ ] Visuele feedback: monster schuift 1 tegel (geen teleport)

### Chain-push

- [ ] Als geduwd monster tegen ANDER monster aan komt:
  - [ ] Beide monsters worden geduwd (chain-push)
  - [ ] Tweede monster schuift ook 1 tegel in dezelfde richting
  - [ ] Als tweede tegen muur/obstakel komt → stopt daar
  - [ ] Als tweede tegen een DERDE monster komt → keten gaat door
- [ ] Chain stopt bij: muur, obstakel, of lege ruimte aan het einde
- [ ] Alle geduwde monsters schuiven tegelijk (animatie)

## Systemen – run feature

**CANON – niet wijzigen zonder overleg.**

- [ ] RUN-knop toevoegen BOVEN de CORE-knop
- [ ] Toggle: aan/uit (blijft aan tot speler uitzet)
- [ ] Wanneer RUN aan:
  - [ ] Speler beweegt 2 tegels per move
  - [ ] Sprite beweegt SNEL (animatie, geen teleport)
  - [ ] Loopsnelheid sprite 2x
- [ ] Wanneer RUN uit:
  - [ ] Normale 1-tegel beweging
- [ ] Werkt OVERAL (dungeons + worldmap + dorpen)
- [ ] Geen verschil in vijand-interactie (agro-radius blijft gelijk)
- [ ] NIET tijdens gevecht
- [ ] Visuele indicator op knop: aan/uit status duidelijk

## Koppelingen tussen systemen

**CANON – niet wijzigen zonder overleg.**

- [ ] Push werkt samen met PUZZLE ROOM (gestund monster op drukplaat)
- [ ] Push werkt samen met TRAP ROOM (monster in gat duwen)
- [ ] RUN werkt in alle kamer-types behalve tijdens gevecht
- [ ] RUN werkt in REST ROOM, MERCHANT ROOM, etc.

## TODO(design) markers

**CANON – niet wijzigen zonder overleg.**

- [ ] Loot ratio consumables vs. equipment
  Definitief. De checkbox blijft open tot de loot table in de code deze verdeling gebruikt.

  **CANON – niet wijzigen zonder overleg.**

  Blue chest verdeling per grade:

  - G1: Consumables 40% / Equipment 15% / Accessoires 5% / Goud 30% / Leeg 10%
  - G2: Consumables 30% / Equipment 25% / Accessoires 10% / Goud 25% / Leeg 10%
  - G3: Consumables 20% / Equipment 30% / Accessoires 20% / Goud 20% / Leeg 10%
  - G4: Consumables 15% / Equipment 35% / Accessoires 25% / Goud 15% / Leeg 10%

  Normale kisten:

  - Consumables 60% (1-2 stuks) / Goud 20% / Equipment 15% / Leeg 5%

  Extra regels:

  - Consumables in Grot geven minder dan buiten
  - Elixirs alleen in blue chests of merchant (niet in normale kisten)
  - Blue chest loot schaalt met floor

  Effect van deze wijziging:

  - Speler krijgt significant minder consumables per run.
  - Equipment/accessoires worden de hoofdbeloning.
  - Goud wordt nuttig (voor merchant in Grot + verkopen).
- [ ] Blue chest kans per floor-bracket
  Definitief. De checkbox blijft open tot de blue-chest-kans in de code deze tabel gebruikt.

  **CANON – niet wijzigen zonder overleg.**

  Basis kans per verdieping (normale kamer):

  - Floor 1-10: 5% → 0-1 blue chest
  - Floor 11-20: 10% → 0-1 blue chest
  - Floor 21-35: 15% → 0-1 blue chest
  - Floor 36-50: 20% → 0-1 blue chest
  - Floor 51-65: 25% → 0-1 blue chest
  - Floor 66-80: 30% → 0-1 blue chest
  - Floor 81-95: 40% → 0-1 blue chest
  - Floor 96-99: 50% → 0-1 blue chest

  Overrides per kamer-type:

  - CHEST ROOM (10%): altijd 2 blue chests
  - TREASURE ROOM (5%): 50% kans op 1 blue chest
  - PUZZLE ROOM (5%): altijd 1 blue chest (bij succes)
  - Andere kamers: volgt floor-bracket tabel

  Balans-effect:

  - Gemiddeld 25-30 blue chests per volledige run (was ~60-80)
  - Early game (1-20) significant minder
  - Endgame (90-99) voelt als beloning
- [ ] Medium Map: exacte kisten + monsters
- [ ] Trap Room: zichtbaar of verborgen vallen?
  Definitief. De checkbox blijft open tot de vallen in de code deze verdeling gebruiken.

  **CANON – niet wijzigen zonder overleg.**

  Verdeling:

  - 60% ZICHTBARE vallen (speler kan ontwijken)
  - 40% VERBORGEN vallen (speler kan niet ontwijken)
  - Speciale combo-vallen op hoge floors (61+)

  Val-types:

  Zichtbaar:

  - Spike-platen (op vloer)
  - Pijlen uit muren
  - Gaten in vloer

  Verborgen:

  - Drukplaten
  - Verborgen spike-traps
  - Plafond-val

  Speciaal (floor 61+):

  - Combo-vallen (zichtbaar triggert verborgen)
  - Bewegende vallen
  - Push-vallen (duwen speler)

  Schade per val:

  - Spike-plaat: 5-10% HP
  - Pijlen: 8-12% HP
  - Gat in vloer: 10-15% HP + terug naar ingang
  - Drukplaat: 10% HP
  - Plafond-val: 15-20% HP + korte stun
  - Push-val: 0% HP + verplaatst speler

  Schade schaalt met floor:

  - Floor 1-30: basis
  - Floor 31-60: +25%
  - Floor 61-99: +50%

  Detectie verborgen vallen:

  - Lotte's Licht-magie (verlicht tijdelijk)
  - Codex-monster met detectie-ability
  - Item (Detectie-bril / Kaart)
  - Zonder detectie: blind erin

  Voorkomen per kamer-type:

  - Trap Room: MEER vallen, mix 60/40
  - Medium Map: af en toe vallen
  - Large Room: af en toe vallen
  - Empty Room: af en toe vallen
  - Rest/Treasure/Merchant Room: NOOIT vallen
- [ ] Puzzle Room: welke puzzels?
  Definitief. De checkbox blijft open tot de puzzels in de code deze types gebruiken.

  **CANON – niet wijzigen zonder overleg.**

  3 puzzel-types (roterend):

  1. Ketting-puzzel (vanaf floor 11). Schakelaars die elkaar beïnvloeden. "Lights out"-stijl. Elke schakelaar verandert 2-3 andere.
  2. Rotatie-puzzel (vanaf floor 21). Draaiende tegels, verbind start met einde. Klik op tegel → roteert 90°.
  3. Licht-puzzel (vanaf floor 31). Lotte's Licht op panelen. Verborgen paden onthullen. Alleen als Lotte in de party is.

  Beschikbaarheid per floor-bracket:

  - Floor 1-10: geen puzzel-kamers
  - Floor 11-20: Ketting
  - Floor 21-30: Ketting, Rotatie
  - Floor 31-99: Ketting, Rotatie, Licht

  Moeilijkheid schaalt:

  - Floor 11-30: klein (3-5 stappen, ~30 sec)
  - Floor 31-60: middel (6-10 stappen, ~1 min)
  - Floor 61-99: groot (11-15 stappen, ~2 min)

  Beloning en falen:

  - Succes: 1 blue chest + poort opent
  - Falen: geen straf, opnieuw proberen
  - Puzzel reset na 3 mislukte pogingen (nieuwe layout)

  Visueel:

  - Paarse gloed (match Codex Monument + Hanger)
  - Symbolen op tegels
  - Licht-effect bij activeren
  - Blue chest verschijnt met animatie

  - [ ] TODO(design): hint-systeem, wel of niet? (ECHO / Lotte / geen)
    Definitief. Getrapt, geen directe hints. De checkbox blijft open tot de hints in de code deze fasen gebruiken.

    **CANON – niet wijzigen zonder overleg.**

    Fase 1 (0-5 min vast): geen hint. De speler puzzelt zelf. Pure ervaring.

    Fase 2 (5-10 min vast): Lotte-hint. Alleen als Lotte in de party is. Subtiele hint, één keer per puzzel. Voorbeeld: "Wacht... die twee panelen lijken samen te horen."

    Fase 3 (10+ min vast): ECHO-hint. Via communicator (World Warper bereikt simulatie). Duidelijkere hint dan Lotte. Altijd beschikbaar. Voorbeeld: "Kandidaat, de volgorde is niet links-rechts, maar binnenstebuiten."

    Optioneel, na 3x falen: de puzzel licht op. Eén tegel licht kort op (startpunt). Geen volledige oplossing.
- [x] Empty Room: ~30% een lore-notitie, anders leeg (besluit Dennis, 14 okt 2026)
  Definitief. De checkbox blijft open tot de Empty Room in de code deze verdeling gebruikt.

  **CANON – niet wijzigen zonder overleg.**

  Verdeling binnen Empty Room:

  - Echt leeg: 50% (alleen doorgang)
  - Lore-notitie: 20% (brief/boek op muur)
  - Overblijfselen: 15% (zwak item, Grade 1-2)
  - Graffiti: 10% (symbolen/hints)
  - Geheime doorgang: 5% (verborgen pad, met Lotte's Licht)

  Lore-notitie:

  - Briefje / boek / kras op muur
  - Verwijst naar H-1 t/m H-5 of Sapientia's experiment
  - Voorbeeld: "H-4 probeerde hier te rusten. Hij kwam niet verder."

  Overblijfselen:

  - Oud wapen, schild, of accessoire op de grond
  - Zwak item (Grade 1-2)
  - Vertelt verhaal: iemand was hier, haalde het niet

  Graffiti:

  - Symbolen of tekst op muur
  - Soms hint naar puzzel of geheim
  - Soms waarschuwing
  - Voorbeeld: "Loop niet verder. De Stem hoort je."

  Geheime doorgang:

  - Verborgen pad naar naastgelegen kamer
  - Ontdekbaar met Lotte's Licht
  - Leidt naar kleine bonus (1 normale kist)

  Lore-koppeling:

  - Verwijst naar H-1 t/m H-5
  - Sapientia's experiment
  - De Stem (Sapientia fluistert door de Grot)
  - Andere kandidaten die het niet haalden

  Visueel:

  - Echt leeg: alleen muren, lege vloer, 1 uitgang
  - Lore-notitie: boek/brief op grond of muur
  - Overblijfselen: subtiele item-glow
  - Graffiti: symbolen op muur (paarse gloed?)
  - Geheime doorgang: verborgen, zichtbaar met Lotte's Licht
- [ ] Merchant Room: welke items verkoopt hij?
  Definitief. De checkbox blijft open tot de merchant in de code deze voorraad gebruikt.

  **CANON – niet wijzigen zonder overleg.**

  Wie is de merchant:

  - Een vorige proefpersoon (H-reeks) die vast zit in de simulatie
  - Verzamelt wat hij onderweg vindt
  - Weet meer dan hij zegt
  - Koppelt aan H-1 t/m H-5
  - [ ] TODO(verhaal): welke H is hij? Wat is zijn verhaal?
    Definitief. Hij is H-5, de laatste proefpersoon vóór Dennis. De checkbox blijft open tot dit verhaal in de code staat.

    **CANON – niet wijzigen zonder overleg.**

    Achtergrond:

    - Proefpersoon H-5, gemaakt in Archief 4
    - Kwam 2-3 jaar voor Dennis
    - Haalde floor 100 NIET
    - Simulatie sloot hem op in plaats van hem te doden
    - Zit nu vast in de Grot, kan er niet meer uit

    Naam: hij is zijn naam vergeten (simulatie heeft het gewist). Noemt zichzelf "de Koopman".

    Wat hij weet:

    - Kent Dennis' oorsprong (Archief 4)
    - Kent Opa (heeft hem ontmoet)
    - Weet wat er met H-1 t/m H-4 is gebeurd
    - Weet dat de Grot een filter is
    - Weet dat Sapientia wacht op "de juiste"

    Waarom hij niets zegt:

    - Bang (Sapientia luistert)
    - Schaamt zich (hij faalde)
    - Heeft vrede gevonden in zijn rol
    - Als speler vaak terugkomt: hij vertelt meer

    - [ ] TODO(verhaal): hoe eindigt H-5?
    - [ ] TODO(verhaal): kan hij bevrijd worden? Sterft hij? List van Sapientia?

  Wat hij verkoopt:

  1. Consumables (altijd op voorraad). Elixir, Phoenix-veer (revive), anti-status items. Prijs: 2x normale winkelprijs.
  2. Grot-exclusieve items. Alleen deze twee, altijd op voorraad, prijs vast hoog.
    - Simulatie-token: 1x een vastgelopen run herstarten.
    - Stun-bom: stunt alle monsters in de kamer.
    Kaart-fragment en Push-handschoen zijn niet meer in scope.
  3. Grade 3-4 equipment (wisselt per bezoek). 1 willekeurig Grade 3 item. 1 Grade 4 item per 3 bezoeken (zeldzaam). Prijs: 2-3x normale winkelprijs.
  4. Rotatie-item (1 per bezoek, uniek). Kan zijn: lore-item, zeldzame consumable, novelty. Prijs: variabel.

  Wat hij koopt van de speler:

  - Consumables: 50% winkelprijs
  - Equipment: 30-50% winkelprijs
  - Accessoires: 30-50% winkelprijs
  - Grade 4 items: 60% winkelprijs (biedt meer)

  Stock en rotatie:

  - Consumables + Grot-exclusief: altijd op voorraad
  - Grade 3-4 equipment: random 1-2 stuks per bezoek
  - Rotatie-item: 1 uniek per bezoek
  - Restock: elke nieuwe run

  Dialoog:

  - Bij binnenkomst: "Wel, wel. Een nieuwe kandidaat. Ik heb je gezien op de muren, wist je dat? De Grot laat alles zien... aan wie blijft kijken."
  - Bij kopen: "Goede keuze. Ik heb dit zelf... laten liggen. Lang geleden."
  - Bij verkopen: "Alles heeft waarde hier beneden. Zelfs dingen die je niet meer nodig hebt."
  - Bij vertrekken: "Als je de Stem hoort, blijf dan niet staan. Ik deed dat wel."

  Waarom uniek:

  - Eén van de weinige verkopers in het spel
  - Beste plek om overtollige loot te verkopen
  - Lore-personage, niet alleen shop

## Canon-markering

**CANON – niet wijzigen zonder overleg.**

Nieuwe verdeling (35/20/10/7/5/5/5/3/1) is CANON.

## Afgeronde items

Afgevinkte vakjes, als referentie. Waar de volledige notitie al woordelijk bij Canon & Design Reference staat, staat hier alleen het vakje.

### Worldmap 1

- [x] Worldmap 1 = start-eiland
  De speelbare wereldkaart is dit eiland. Eiland 2 en 3 zijn er niet.
  - [x] Archief 1: Eerste Archief (bij Opa), startpunt van het verhaal
    Het verhaal begint bij Opa. Het Eerste Archief staat op deze kaart.
  - Bevat Dennis' huis en Wilgendal (eerste dorp met shops)

### Archief 2 op de kaart en in de kas

- [x] Kas linksboven op worldmap 1, achter bergen waar je niet overheen kunt lopen
- [x] Grot-dungeon door de berg naar de andere kant: een paar puzzels, geen bazen, unieke omgeving, eigen bgm en monsters
- [x] Geheime kamer met 2 kisten: een staf en een accessoire, geschaald naar het niveau richting Archief 2

- [x] Combinaties met bestaande puzzel-elementen (kasten en hendels uit Archief 1)
  Verdieping 3, kamer leven_v3_combi: duwbare kast op een zware plaat én een hendel, daarna de groei-plaat.

### Bestiarium-zinnen en Diepe Grot-bazen

- [x] Kustos (Archief 1): "Een wachter zonder ogen, maar met duizend oren. Hij hoort elke gedachte die het Archief binnenkomt. De Oude Mensheid bouwde hem niet om te doden, maar om te bewaren. Sapientia gaf hem een nieuw doel: alles wat niet past, wordt verwijderd."
- [x] De Wortelkoning (Donker Woud): "Wat ooit een herder was van het woud, werd een koning van wortels. Hij sleept wat hij liefheeft de diepte in — niet uit wreedheid, maar uit angst om alleen te zijn. Sapientia fluisterde hem in dat alles wat loslaat, vergaat."
- [x] De Wurger (Archief 2, verdieping 3): "Een slingerplant die geen kant op kon. De Oude Mensheid kweekte hem als bescherming, maar Sapientia draaide zijn groei naar binnen. Nu verstikt hij wat hij zou moeten beschermen. Wie hem verslaat, hoort hem zuchten — als een dier dat verlost wil worden."
- [x] De Genezer (Archief 2, eindbaas): "Hij geneest door te nemen. Hij geeft niets terug. Sapientia's perfecte dienaar: zonder twijfel, zonder emotie, zonder einde. Wie hem ziet, ziet wat de mensheid wordt als Sapientia wint — stil, heel, en leeg."

- [x] Diepe Grot-bazen bouwen
  Verdieping 25, 50, 75 en 99 heten De Schaduw van H-6, De Cyclus, De Rechter en De Stem, met de canon-citaten in het bestiarium. De andere baasverdiepingen (10, 20, 30, 40, 60, 70, 80, 90) houden de oude Engelse namen.

### Diepe Grot-toegang

- [x] Diepe Grot verplaatsen naar ECHO's Kamer; ECHO beheert de simulatie en is de enige start; praten met ECHO → "Start Simulatie"; geen aparte worldmap-ingang.
- [x] Drie kisten in ECHO's Kamer (Codex, Equipment, Accessoire). Leeg bij het eerste bezoek. Na elke Grot-run licht één kist op. Vulling per act staat hieronder.
  `EchoKisten.gevulde`: act 2 en lager 0, act 3 één, act 4 twee, daarna drie. Vanaf act 6 pulseren de gevulde kisten en wordt ECHO feller. Kleurvlakken, geen buit.
- [x] Flow: World Warper → ECHO's Kamer → optie "Diepe Grot Simulatie" → "Start nieuwe run" / "Ga terug". Start: floor 1, level 1, geen uitrusting. Na warp-kristal floor 100 terug naar ECHO's Kamer. ECHO toont resultaat en opent de volgende run.
- [x] ECHO weet dat de grot een simulatie is en kan dat bij het eerste bezoek uitleggen.

### Dungeon-warpers

- [x] Begin: warper bij de ingang / start van de dungeon of het Archief
  Eerste Archief (`archief_ingang`, tegel 8,10), Archief 2, Donker Woud (`woud_rand`, 8,10) en de berggrot (`berggrot_mond`, 8,10). Geen waarschuwing. De tekst is "Dit is de ingang. Je blijft in de dungeon." De party verlaat de dungeon niet.
  - [x] Archief 2: bij de ingang, naast de start, niet op een uitgangstegel. Geen waarschuwing.
- [x] Midden van de dungeon: warper na de mini-baas
  Zonder mini-baas staat hij op een tussenkamer. Eerste Archief: middelste verdieping, tegel 3,4. Donker Woud: Mistpoel (`woud_mistpoel`, 4,6). Berggrot: de Nerf (`berggrot_nerf`, 8,6). Met waarschuwing.
  - [x] Archief 2: na De Wurger (verdieping 3), met waarschuwing.
- [x] Eind van de dungeon: warper na de eindbaas
  Eerste Archief na de Golem. Donker Woud op de open plek, naast de sta-tegel na de Wortelkoning. Berggrot in de Uitmond (`berggrot_uitmond`, 12,7). Met waarschuwing. Spawn op de wereldkaart: `van_archief`, `van_kas`, `van_woud`, `van_berggrot`.
  - [x] Archief 2: na De Genezer, met waarschuwing.
- [x] Geldt voor elke normale dungeon, niet alleen de Diepe Grot
  Gedaan voor het Eerste Archief, Archief 2, het Donker Woud en de berggrot. Archief 3 tot en met 6 wachten. De Diepe Grot heeft eigen warpers op verdieping 1, 25, 50, 75 en 99 en keert terug naar ECHO's Kamer.

- [x] Warper brengt de party direct naar de worldmap of het dichtstbijzijnde dorp
  Midden en eind van het Eerste Archief, Archief 2, het Donker Woud en de berggrot doen dat in één stap. De begin-warper verlaat de dungeon niet. De Diepe Grot komt uit in ECHO's Kamer, niet op de wereldkaart.
- [x] De speler hoeft niet eerst terug naar de ingang
  Geldt voor die midden- en eindwarpers. De begin-warper blijft de ingang.
- [x] Eén stap: warper naar worldmap
  - [x] Archief 2: midden en eind gaan in één stap naar de wereldkaart (`van_kas`). De begin-warper verlaat de dungeon niet.

Bij activeren verschijnt een waarschuwing, in dezelfde stijl als de save- en quit-prompts. Die geldt voor de midden- en de eindwarper.

- [x] Waarschuwingsscherm: "Weet je zeker dat je de dungeon wilt verlaten?"
  Zelfde zin op de gedeelde dungeon-warper en op de Diepe Grot (verdieping 25, 50, 75 en 99). Verdieping 1 van de grot waarschuwt niet.
  - [x] Optie: "Ja, warpen naar worldmap"
    Die tekst staat op de gedeelde warper (Eerste Archief, Archief 2, Donker Woud, berggrot). De Diepe Grot gebruikt de kortere knop "Ja".
  - [x] Optie: "Nee, blijf in de dungeon" (annuleren, de party blijft staan)
    Die tekst staat op de gedeelde warper. De Diepe Grot gebruikt de kortere knop "Nee". Annuleren laat de party staan.
  - [x] Archief 2: midden en eind gebruiken dit scherm en deze twee opties. De begin-warper waarschuwt niet.
- [x] Voorkomt dat een speler per ongeluk de dungeon uitwarpt
  Alleen na "Ja". "Nee" en de begin-warper houden de party in de dungeon.
- [x] Waarschuwingsstijl passend bij de game-UI (vergelijkbaar met save- en quit-prompts)
  Zelfde `Dialog.ask` als de andere ja/nee-vragen. Het plaatje is het opslagboek, violet getint.
- [x] Werkt op zowel de midden- als de eindwarper
  - [x] Archief 2: de waarschuwing staat op midden (De Wurger) en eind (De Genezer).

### Wilgendal

Huidige situatie:
- [x] Shopkeepers staan in hun eigen winkel, achter de toonbank
  Jelle Hamer op pantser en wapen. Accessoire en magie hebben een eigen winkelier. Ze lopen niet op het plein.
- [x] Elke winkel heeft een vaste plek op het plein
  Pantser, wapen, accessoire en magie, elk met een deur.

Doel: winkels met vaste locaties:
- [x] Eigen winkelpand per shopkeeper: armour, wapen, accessoire, magic
  Vier panden in `scripts/data/wilgendal_dorp.gd`. Jelle houdt twee balies, zoals canon.
- [x] Shopkeepers verplaatsen van het dorp naar hun eigen winkel
- [x] NPC staat achter de toonbank in de winkel
- [x] Niet meer rondlopend in het dorp
  De winkeliers staan binnen. Op het plein lopen alleen de sfeer-NPC's.
- [x] Speler moet de winkel binnengaan om te handelen
- [x] Winkelinterieurs, per winkel eigen uitstraling (armour stoer, magic mystiek, wapen ambachtelijk, accessoire sierlijk)
  Bestaande binnentegels met een tint: stoer, ambacht, sier, mystiek. Geen definitieve art.
- [x] Toonbank, shopkeeper en item-display
  Toonbank en vitrine in het interieur.
- [x] Deur naar buiten, terug naar het dorp
- [x] Klein maar sfeervol (dorpsschaal, niet stadsschaal)
  Panden van 3×3 tegels aan het plein.
- [x] Wilgendal: klein knus dorpsplein
- [x] Paden tussen de winkelpanden
  Het plein verbindt de deuren. Geen uitgang van het dorp naar de bibliotheek.
- [x] 4 woonhuizen (2 bewoond, 2 decoratief)
  Tante Mien en het huis van Bram en Els zijn open. Twee huizen blijven dicht.
- [x] 6 sfeer-NPC's die rondlopen (geen shopkeepers): echtpaar (2), kind, Gerrit, veteraan, koerier
  Bram, Els, Fien, Wout en Siem lopen een lus van vier tegels. Gerrit blijft op tegel (8, 7) voor Het Zingende Graan.
- [x] Uithangborden als icoon: schild (armour), zwaard (wapen), ring (accessoire), ster (magic)
- [x] Winkels altijd open; geen tijdsysteem
- [x] Dorpsgevoel behouden (geen stadse drukte)
  Het blijft het plein van Wilgendal.

Scheiding:
- [x] Wilgendal blijft op Worldmap 1 (start-eiland)
- [x] Codex Bibliotheek ligt ten zuiden van Wilgendal
  De archieftrap ligt ten zuiden van het dorp. Het dorp zelf heeft geen uitgang naar de bibliotheek.

### Gerrit

- [x] Gerrits quest

### Magie

- [x] Magic tier list opzetten en in het spel zetten (4 grades × 4 spreuken = 16 spreuken per element)
  Vuur, Natuur, Bliksem, Licht en IJs staan in `scripts/data/spells.gd`. Grade 4 heeft `shop = false`. Water, Wind, Aarde en Aether staan nog niet in de code.

- [x] Per spreuk eigen data: damage, healing en effect schalen per grade
  De namen en cijfers hieronder zijn canon. Dezelfde spreuken staan in `scripts/data/spells.gd`, met MP, power en power per level. De grade-4-rollen zitten in `GradeGear.SCROLLS` en vallen vanaf verdieping 80. De vijf oude rol-ids blijven opzoekbaar voor saves en zitten niet meer in die pool.

### World Warper — hub, ECHO en warp

- [x] Na De Genezer: canon-scène 1 (CANON 17, `world_warper/cutscene/genezer_scene.gd`), daarna warp naar de Hal (`world_warper/maps/hal.tscn`, spawn ingang); daar scène 2 en 3 (`hanger_scene.gd`), daarna opent de warp-view. Vlaggen: `ww_canon_genezer_gezien`, `ww_canon_hanger_gezien`, `ww_canon_dreiging_gezien`.
- [x] **De World Warper is geen plek op de wereldkaart** (Dennis 2026-10-13). Geen platform, geen uitgang, geen botsing. Alleen een overvliegend plaatje (`world_warper/art/flyover.gd`) na ontgrendeling. De enige ingang is **Warp in het menu** (`field_menu.open_warp`).
- [x] Grotmond van de berggrot (weg naar Archief 2) zichtbaar op worldmap 1: bergtegel (21,17): de tunnel zit in de rotswand; omhoog lopen vanaf (21,18) gaat de grot in, de rest van de berg blokkeert; terug op (21,18), placeholder `assets/sprites/buiten/berggrot_ingang.png` (16x16).
- [x] Bouwplaats voor de tunnel (`scenes/maps/berggrot_bouwplaats.tscn`, gebouwd met `tools/build_bouwplaats.gd`): eerst deze kaart na de grotmond. Voorman Hendrik en werker Sanne, hek, karretje, gereedschap, balken. Tunnel dicht tot `noor_lid` (Noor/Vesper in de party), daarna open naar de berggrot. Zuid terug naar de wereldkaart (21,18). De grotmond in de berg komt uit op de bouwplaats (`van_tunnel`); de exit-warpers gaan naar de wereldkaart (21,18).

- [x] Dorpen eerst bezocht vóór een warp.
  `GameState.bezochte_kaarten` bewaart het pad. Wilgendal, Esdoorn en de wereldkaart gaan alleen open als dat pad erin staat. Een oude save zonder lijst telt die drie WM1-plekken als bezocht.
- [x] Party wisselen in de Rustkamer. De regels staan bij Functionaliteit.
  `PartyBench`: maximaal 3 actief, Dennis en tijdelijke Codex-gasten blijven van de bank, gratis, alleen in `rustkamer.tscn`. De bank gaat mee in de save.
- [x] Save-tegel op de echte spelerpositie.
  `save_point.gd` leest `get_tile()` en `facing` van Objects/Player. Zonder speler blijft het (0, 0) en omlaag.
- [x] Act-kamers bouwen en de deuren openen.
  De kamers uit de lijst staan in `world_warper/kamers`. `hub_open` is waar bij `warper_hub_open` of zodra de World Warper na De Genezer open is. Werkplaats en Handelskamer zijn leeg: geen recepten, geen endgame-voorraad. `codex_nis` en `sapientia_schot` blijven dicht.
- [x] Bestaande placeholder-kaarten registreren; ze staan niet in tools/placeholders_v17.txt.
  bord_hal, bord_warp en tiles staan in tools/placeholders_v17.txt. De kaarten in world_warper/maps tekenen met die atlas.
- [x] Kleur van de Hanger-gloed in de code van roze naar paars.
  `HangerScene.PURPLE` is `Color("b07ae8")`. De scène zet de Hanger op die kleur.

- [x] Runner in de CI-matrix op Godot 4.3. De job warper-runner in .github/workflows/tests.yml draait world_warper/tests/run.gd. warperkamertest stond al in de matrix.

- [x] Komt online na De Genezer (Archief 2)
  De code zet world_warper_unlocked na bewaker:archief_2_v4_genezer/genezer. De bewaker van verdieping 2 opent de hub niet.

- [x] De party wordt automatisch gewarped naar het gebouw
  Na De Genezer speelt NA_GENEZER. `WorldWarperNaGenezer.probeer()` zet de warp pas na de kernabsorptie. `Enter.enter()` zet world_warper_unlocked en wisselt naar het exterieur, spawn ingang. De kaartkamer archief_2_warper blijft de noorduitgang.
- [x] Introductie van de AI-gids ECHO
  In de hal, via Dialog.show_lines. Eerste zin: "Ik ben ECHO. Ik ben de gids van deze hub." Vier stappen, vlaggen world_warper_guide_0 tot en met 3. De overige zinnen zijn voorlopig. Geen losse cutscene.

- [x] Dennis' Hanger licht op (paarse gloed, reageert op de World Warper)
  De scène zet de Hanger op `Color("b07ae8")`. De hal is paars. Roze blijft de Stroom, het domein van Sapientia. Dennis steekt de Hanger niet apart op.

  - [x] ECHO reageert herkennend op de Hanger
    De hanger-stap zegt: "De Sleutel reageerde bij je aankomst." en "De Hanger is de Sleutel." De spreker heet ECHO. Over H-6 zegt de tekst niets.

- [x] De gids in de tekst ECHO noemen
  De spreker en de welkomstzin gebruiken de canon-naam ECHO. De overige zinnen blijven voorlopig.

- [x] Geeft hints bij vastlopen en de volgende bestemming
  Na de welkomst- en hanger-stap, en na de laatste stap. Volgorde: Noor in het Donker Woud, de Golem van het Eerste Archief, De Genezer via de berggrot, anders een al bezochte plek op wereld 1. Geen nieuw verhaal.
- [x] Herkent de Hanger
  De hanger-stap noemt de Hanger de Sleutel: "De Sleutel reageerde bij je aankomst." Over H-6 zegt de tekst niets. De bonus-lore over ECHO staat nog niet in de tekst.

- [x] Alleen ontgrendelde dorpen zijn selecteerbaar
  Wilgendal, Esdoorn en de wereldkaart vragen hun pad in `bezochte_kaarten`. WM2 en WM3 blijven dicht.

- [x] Elk dorp moet eerst bezocht zijn voordat je ernaartoe kunt warpen
  `enter_map` zet het pad in `bezochte_kaarten`. Zonder dat pad blijven Wilgendal, Esdoorn en de wereldkaart vergrendeld. Een oude save zonder lijst telt die drie als bezocht.

### Functionaliteit in de World Warper

- [x] Party kiezen en wisselen
  Alleen in de Rustkamer, via `PartyBench`. Maximaal 3 actief. Dennis en tijdelijke Codex-gasten gaan niet op de bank. Gratis, en de bank gaat mee in de save.

### Ingame-menu

- [x] Indeling volgens de schets
  `scripts/ui/field_menu.gd`: bord "MENU" is alleen een label. Links, gestapeld: Uitrusting, Codex, Items. Rechts: Warpen.

### PvP

De uitwerking staat bij Canon & Design Reference → PvP.

- [x] Simpel 1v1 PvP-gevecht tussen vrienden
- [x] Geen ranked, geen MMR, geen matchmaking, geen seizoenen
- [x] Spelers nodigen elkaar uit via een connect-code
- [x] APARTE modus, los van singleplayer
- [x] Lore/kernen/Hanger/Codex gelden NIET in PvP
- [x] Geen impact op save files
   - [x] Alleen de host kiest
   - [x] Keuze wordt naar beide spelers gestuurd
   - [x] Speler A kiest team
   - [x] Speler B kiest team
   - [x] Mirror match TOEGESTAAN (beide mogen hetzelfde team)
- [x] Early Game Mode
- [x] Mid Game Mode
- [x] High Game Mode
- [x] Team 1: De Klassieke Drie
- [x] Team 2: De Aanvalsdriehoek
- [x] Team 3: De Verdedigingslinie
- [x] Host genereert unieke connect-code
- [x] Join-scherm: code invoeren
- [x] Verbinding opzetten (relay of direct)
- [x] Host-mode-select scherm (early/mid/high)
- [x] Team-select scherm (beide spelers tegelijk)
- [x] Load gevecht
- [x] Result-scherm (winnaar + rematch optie)
- [x] Netwerk-laag (Godot 4.3 Multiplayer API)
- [x] Aparte PvP-scene (los van singleplayer)
- [x] Turn-based combat synchroniseren
- [x] Verbindingsverlies afhandelen
  - [x] Disconnect → terug naar menu
  - [x] Reconnect-optie (indien mogelijk)
- [x] Connect-code generator (uniek, kort, makkelijk te delen)
- [x] Eigen UI/menu los van singleplayer
- [x] Eigen regels en balans
- [x] Eigen stat-berekening per game mode
- [x] Geen lore-items, geen kernkrachten, geen Hanger
- [x] Geen save file impact
- [x] Fase 1: Local PvP POC (LAN, 1v1, 1 team, 1 mode)
- [x] Fase 3: Host-mode-select + team-select schermen
- [x] Fase 4: 3 teams + 3 modes volledig
- [x] Geen ranked, geen MMR, geen matchmaking
- [x] Geen seizoenen, geen ranks
- [x] Geen 2v2 (later eventueel)
- [x] Geen anti-cheat (vrienden onder elkaar)
- [x] Geen leaderboards
