# TODO — toekomstige updates

Afvinken alleen als het echt af is. Open punten zijn nog ontwerp of nog niet gebouwd.

## Wereld & Levels

Uniek superwapen per karakter (alleen Grade 4, drop vanaf verdieping 80):

- [ ] Aan te vullen zodra nieuwe karakters of classes in het verhaal komen

Grade 4 armour sets, class-gebonden (4 stukken per set: helm, borst, benen, laarzen; alleen de eigen set, geen mix):

- [ ] Aan te vullen voor toekomstige karakters

### Wereldkaart opbouw

- [ ] 3 grote hoofdeilanden opzetten, elk met 2 Archieven (totaal 6 Archieven)
- [ ] Worldmap 1 = start-eiland
  - [ ] Archief 1: Eerste Archief (bij Opa), startpunt van het verhaal
  - [ ] Archief 2: Archief van Leven
  - Bevat Dennis' huis en Wilgendal (eerste dorp met shops)
- [ ] Worldmap 2 = tweede eiland
  - [ ] Archief 3: Archief van Industrie
  - [ ] Archief 4: Archief van Magie
  - Dorpen en locaties nog te bepalen
- [ ] Worldmap 3 = derde eiland
  - [ ] Archief 5: Archief van Kosmos
  - [ ] Archief 6: Archief van Hart
  - Dorpen en locaties nog te bepalen

### Warp-systeem

- [ ] Warp-punten plaatsen op elk eiland
- [ ] Vrij heen en weer reizen tussen ontgrendelde eilanden
- [ ] Warp ontgrendelen na een bepaald verhaalpunt of act
- [ ] Worldmap 2 ontgrendelt na afronden van Worldmap 1
- [ ] Worldmap 3 ontgrendelt na afronden van Worldmap 2
- [ ] Visuele feedback (poort, portaal of magisch effect)

### Dungeon Warpers (begin, midden en eind)

In elke normale dungeon en in elk Archief (Archief 1 tot en met 6) staan warpers op vaste plekken: begin, midden en eind. Niet alleen in de Diepe Grot (de 100-verdiepingen-dungeon).

- [ ] Begin: warper bij de ingang / start van de dungeon of het Archief
- [ ] Midden van de dungeon: warper na de mini-baas
- [ ] Eind van de dungeon: warper na de eindbaas
- [ ] Geldt voor elke normale dungeon, niet alleen de Diepe Grot
- [ ] Geldt voor alle Archieven (Archief 1 tot en met 6), inclusief Archief 1 (het Eerste Archief)
- [ ] Geldt ook voor de Diepe Grot: begin, midden en eind
  - [ ] Frequentie in de Diepe Grot nog open (elke 20 verdiepingen een warper?)

Warp-bestemming: de party gaat in één stap direct naar de worldmap of het dichtstbijzijnde dorp, zonder eerst terug naar de dungeon-ingang.

- [ ] Warper brengt de party direct naar de worldmap of het dichtstbijzijnde dorp
- [ ] De speler hoeft niet eerst terug naar de ingang
- [ ] Eén stap: warper naar worldmap

Bij activeren verschijnt een waarschuwing, in dezelfde stijl als de save- en quit-prompts. Die geldt voor de midden- en de eindwarper.

- [ ] Waarschuwingsscherm: "Weet je zeker dat je de dungeon wilt verlaten?"
  - [ ] Optie: "Ja, warpen naar worldmap"
  - [ ] Optie: "Nee, blijf in de dungeon" (annuleren, de party blijft staan)
- [ ] Voorkomt dat een speler per ongeluk de dungeon uitwarpt
- [ ] Waarschuwingsstijl passend bij de game-UI (vergelijkbaar met save- en quit-prompts)
- [ ] Werkt op zowel de midden- als de eindwarper

- [ ] Universele warper-stijl, of een variant per Archief-thema
  - [ ] Die keuze is nog open

### Act-koppeling

- [ ] Act 1 = Worldmap 1 (start-eiland, Eerste Archief en Leven)
- [ ] Act 2 en verder = Worldmap 2 (Industrie en Magie)
- [ ] Act 3 en verder = Worldmap 3 (Kosmos en Hart)
- [ ] Onthulling Proefpersoon H-6 (Dennis) koppelen aan Archief 4 (Magie) op Worldmap 2

### Archief 2 — Het Levende Archief

Locatie: Worldmap 1 (start-eiland), tweede Archief. Thema: Leven. Grootte: vergelijkbaar met Archief 1 (4 verdiepingen).

#### Sfeer en setting

- [ ] Overwoekerde kas of broeikas (groen, vochtig, planten overal)
- [ ] Zachte groene gloed als signature lighting
- [ ] Leven dat niet stopt met groeien; alles is in beweging
- [ ] Visueel contrast met het grauwe Eerste Archief

#### Verhaallijn

- [ ] Dennis gaat naar Archief 2 omdat de kern van Archief 1 reageert op een tweede signaal
- [ ] Lotte is een priesteres, gestuurd door haar orde (naam nog te bepalen) om het Archief te onderzoeken
- [ ] Lotte is gecorrumpeerd door Sapientia en verschijnt als mini-baas halverwege
- [ ] Lotte's backstory: gestuurd door een orde, verdeeld over Sapientia (later uitwerken)

#### Lotte's entree (midden van de dungeon, verdieping 2)

- [ ] Lotte verschijnt als mini-baas op verdieping 2 van 4
- [ ] Gecorrumpeerd door Sapientia, met visuele glitch-effecten
- [ ] Gevecht: Dennis en een Codex-monster (bondgenoot) tegen Lotte
  - [ ] Het Codex-monster vecht mee als tijdelijke bondgenoot
  - [ ] De speler kiest welk Codex-monster meegaat, als er meerdere zijn
- [ ] Bij verlies is het een story death, geen game over
  - [ ] Cutscene: Lotte breekt zelf de glitch van Sapientia
  - [ ] Ze beseft wat er gebeurd is en sluit zich aan bij de party
  - [ ] Of de speler wint of verliest: Lotte sluit aan
- [ ] Na het gevecht sluit Lotte aan als vast party-lid
- [ ] Daarna speel je verdieping 3 en 4 met Dennis, Lotte en het Codex-monster

#### Lotte's stats en skills bij aansluiting

- [ ] Klasse: Priester
- [ ] Elementen: Licht (heal en buffs) en IJs (aanval)
- [ ] Start-level passend bij de voortgang in Archief 2, afgestemd op Dennis
- [ ] Startuitrusting: priester-standaard (staf en robes)
- [ ] Startspreuken: Grade 1 Licht (heal) en Grade 1 IJs (aanval)

#### Puzzel-mechaniek: groeiende platen

- [ ] Kernmechaniek: planten of platen die groeien als je ze activeert
- [ ] Groeiende platen vormen bruggen, plateaus en paden
- [ ] De speler moet de juiste volgorde vinden om door te komen
- [ ] Combinaties met bestaande puzzel-elementen (kasten en hendels uit Archief 1)
- [ ] Moeilijkheid per verdieping opbouwen
- [ ] De nieuwe mechanic introduceren op verdieping 1, tutorial-achtig

#### Baas: De Genezer (verdieping 4)

- [ ] Concept: een golem die "geneest" door alles te absorberen
- [ ] Sapientia's logica: leven is stilte, emotie is een fout
- [ ] De Genezer zuigt levenskracht op van planten en monsters
- [ ] Aanval: absorbeert HP van party-leden (heal-trade)
- [ ] Zwakte: IJs (Lotte's element) en Dennis' zwaardaanvallen
- [ ] Design: organisch/machine-hybride, half plant en half staal
- [ ] Na het verslaan de kern van Archief 2 opnemen

#### Cutscene na Archief 2: de World Warper

- [ ] Na het verslaan van De Genezer start een cutscene
  De Genezer bestaat niet. De hub-unlock kijkt naar bewaker:archief_v2_trapzaal/m2, verdieping 2 van het Eerste Archief.
- [ ] Een zwevend hightech gebouw verschijnt: de World Warper
  Er is een placeholder-exterieur (tegels 16×16). Het verschijnt niet in de lucht.
- [ ] De party wordt automatisch gewarped naar de World Warper
  Er is geen deur op de wereldkaart. WorldWarperEnter.enter() wisselt naar het exterieur zodra de unlock-vlag er is; de kaart roept dat niet aan.
- [ ] De World Warper is de hub om tussen de 3 hoofdeilanden te reizen
  Eerste versie van de hub staat. Alleen WM1 is open. WM2 en WM3 zijn zichtbaar en vergrendeld.
- [ ] Eerste introductie van het warp-systeem in het verhaal
  De warp-UI staat in de hal. Een cutscene op de wereldkaart ontbreekt.
- [ ] Vanaf hier kan de speler terug naar eerder bezochte eilanden
  WM1 warpt naar de wereldkaart (spawn van_dorp), Wilgendal en Esdoorn (zuid_ingang). Een filter op eerder bezoek ontbreekt.
- [ ] De cutscene maakt duidelijk wat de World Warper is en doet
  De eerste-bezoekscène in de hal heeft voorlopige zinnen (TODO(design)). Dat is deze cutscene niet.

#### Dungeon-opbouw (4 verdiepingen)

- [ ] Verdieping 1: entree, eerste groei-plaatpuzzel, zichtbare monsters
- [ ] Verdieping 2: Lotte als mini-baas (Dennis en Codex-monster), daarna sluit ze aan
- [ ] Verdieping 3: complexere groei-plaatpuzzels en een monster als mini-baas
- [ ] Verdieping 4: aanloop naar De Genezer, het baasgevecht en de World Warper-cutscene

#### Content en art

- [ ] Nieuwe tileset: overwoekerde kas (planten, water, groene gloed)
- [ ] Nieuwe vijanden met een plant- of leventhema (aantal en types nog te bepalen)
- [ ] Lotte-sprite (priester, robes)
- [ ] De Genezer-sprite (golem, organisch/machine)
- [ ] Groei-plaatsprite per stadium: zaad, scheut, volgroeid
- [ ] Kern-item van Archief 2
- [ ] Achtergrondmuziek die bij de overwoekerde kas past
- [ ] Gecorrumpeerde Lotte-variant (glitch-effecten) voor het mini-baasgevecht
- [ ] World Warper-gebouw (zwevend, hightech)
  Placeholder-kaarten staan in world_warper/maps. Ze zweven niet en staan niet in tools/placeholders_v17.txt.
- [ ] Art voor de World Warper-cutscene
  De eerste-bezoekscène gebruikt kleurvlakken. Cutscene-art ontbreekt.

#### Codex

- [ ] Nieuwe Codex-monsters voor Archief 2 (leventhema)
- [ ] Lotte's startmonster, indien van toepassing

#### Verhaal nog open

- [ ] Naam van Lotte's orde bepalen
- [ ] Lotte's familie en achtergrond uitwerken
- [ ] Waarom Lotte gecorrumpeerd raakte (invloed van Sapientia)
- [ ] Exacte reden dat de kern van Archief 1 reageert op Archief 2
- [ ] Welke rol De Genezer speelt in de bredere Sapientia-lore
- [ ] World Warper: wie heeft het gebouwd? (Oude Mensheid, Sapientia, of iemand anders?)

## Content

- [ ] Bestiarium uitwerken tot endgame
  De bestaande eindbazen van de Diepe Grot (verdieping 10 tot en met 100) hebben een entry en stats uit de bestaande monsterdata.
  Lore-tekst nog van Dennis: de regels zijn nu kort en feitelijk, geen canon-lore.

## Dorpen & Shops

### Magic tier list

Magie heeft 4 grades. Grade 1 tot en met 3 zijn te koop in de magic shop en worden per act vrijgespeeld. Grade 4 is niet te koop: die dropt alleen uit blauwe kisten in de Diepe Grot (verdieping 80+). Per tier 4 spreuken. Niet alles is in Act 1 beschikbaar.

- [ ] Magic tier list opzetten (4 grades × 4 spreuken = 16 spreuken per element)
  De volledige 4×16-lijst is nog ontwerp. De kleine lijst van 20 spreuken (één per grade per element: vuur, natuur, bliksem, licht, ijs) is bevestigd en geldt tot nader order. Fire, Lightning en Heal blijven zo heten.
- [ ] Per spreuk eigen data: damage, healing en effect schalen per grade
  Geldt voor de volledige 16 per element, die er nog niet is. De kleine lijst van 20 heeft bevestigde mp en power per grade.

### Elements en karakters

Noor (mage): Vuur, Natuur en Bliksem.

- [ ] Extra elementen per latere act bepalen

### Nog te bevestigen

- Volledige 4×16-spreukenlijst. De kleine lijst van 20 is bevestigd en geldt tot nader order.
- Toekomstige helden (eigen G4-wapen en set).
- Gerrits quest.
  Gerrits quest is niet gebouwd.
- Echte lore van de eindbazen in het bestiarium.
- Extra elementen voor Noor in latere acts.
- Wereldkaart, warps en de act-koppeling aan de eilanden.

Bevestigd en dus geen open ontwerp meer: winkelprijzen en voorraad, magieprijs 160×grade², verkoop op de helft, grade-statcijfers en grenzen, winkel-act via party-level, archiefschaal 0,7 / EXP 0,50, Golem HP 360 / ATK 27 / DEF 15, Jelle als één smid met twee balies, kort zwaard ATK +3.

Techniek: de headless testsuites draaien via `.github/workflows/tests.yml` (Godot 4.3-stable). De web-export naar Pages (`cursor/web-build-29ec`) blijft handmatig: Godot 4.7.2, threads uit. Er is geen script en geen bot-token die die branch vanuit Actions pusht.

## World Warper

Status 11 okt 2026, branch feature/world-warper, PR 30. Eerste versie in world_warper/. Placeholder-kaarten met tegels van 16×16: exterieur, hal, warp_ring en hanger_nis zijn open. codex_nis en sapientia_schot bestaan en blijven dicht (vlaggen world_warper_act2 en world_warper_act3 zet niemand). Warp-UI in twee stappen; alleen WM1 is open: wereldkaart (spawn van_dorp), Wilgendal en Esdoorn (zuid_ingang). WM2 en WM3 zijn zichtbaar en vergrendeld. AI-gids IVA in de hal, vier Nederlandse stappen via Dialog.show_lines, vlaggen world_warper_guide_0 tot en met 3. De naam is TODO(design), geen canon. Rondlopers uit party en codex_pages, placeholders, geen loop-animatie. Savepunt met Nederlandse bevestiging; schrijft GameState.save_game(Vector2i(0, 0), Vector2i(0, 1)). Gezelschap is een kijklijst. Eerste-bezoekscène: paarse hal, roze Hanger (de Stroom), korte Zwarte Stroom, vlag world_warper_intro_seen. Zinnen zijn TODO(design). Geen H-6-onthulling. Audio-aanroepen ww_ambient, ww_hum, ww_warp en ww_sapientia_glitch, zonder bestanden en zonder manifest-entry, blijven stil. Unlock-haakje in scripts/game_state.gd: world_warper_is_unlocked en try_unlock_world_warper, elk één keer. Vlag world_warper_unlocked na bewaker:archief_v2_trapzaal/m2. Dat is verdieping 2 van het Eerste Archief, niet De Genezer en niet het Archief van Leven. Eigen tests: 65 PASS op Godot 4.7.2. De runner staat niet in .github/workflows/tests.yml.

### Nog te doen

- [ ] Deur op de wereldkaart, en een warp die vanzelf start na De Genezer. De Genezer bestaat niet.
- [ ] WM2 naast WM1 open na Archief 2. De code heeft alleen WM1.
- [ ] Dorpen eerst bezocht vóór een warp. Dat filter ontbreekt.
- [ ] Party wisselen. Er is geen API.
- [ ] Save-tegel op de echte spelerpositie. Nu is de tegel (0, 0) en de kijkrichting (0, 1).
- [ ] Act-kamers invullen en de deuren openen. world_warper_act2 en world_warper_act3 zet niemand.
- [ ] Art. Wat er staat is placeholder en staat niet in tools/placeholders_v17.txt.
- [ ] Kleur van de Hanger-gloed. Deze lijst zei paars; de code is roze (canon: roze = de Stroom).
- [ ] Of de AI-gids meer weet over H-6. De tekst doet dat bewust niet.
- [ ] Webversie. Hoort niet bij deze branch.
- [ ] Runner in de CI-matrix op Godot 4.3. De 65 PASS draaiden op Godot 4.7.2, buiten .github/workflows/tests.yml.

Ontwerp: zwevend hightech hub na het verslaan van De Genezer (Archief van Leven). Dat pad is nog niet gebouwd.

### Concept en lore

- [ ] Zwevend hightech gebouw, mix van technologie van de Oude Mensheid en Sapientia
  Placeholder-exterieur staat. Het gebouw zweeft niet op de wereldkaart.
- [ ] Oorspronkelijk gebouwd door de Oude Mensheid als verbinding tussen de Archieven
- [ ] Sapientia heeft het offline gehouden en wil het zelf in handen krijgen
- [ ] Het werkt alleen op Dennis' Hanger; de Hanger is de enige sleutel
  De scène noemt de Hanger de Sleutel. Een slot dat alleen op Dennis reageert ontbreekt.
- [ ] Dat maakt Dennis (Proefpersoon H-6) onmisbaar voor Sapientia's plannen
  De spelertekst onthult H-6 niet.
- [ ] Komt online zodra twee Archieven (1 en 2) geactiveerd zijn
  De code zet world_warper_unlocked na bewaker:archief_v2_trapzaal/m2, verdieping 2 van het Eerste Archief.

### Verschijning en cutscene

- [ ] Cutscene na De Genezer: de World Warper verschijnt in de lucht
  De Genezer bestaat niet. Er is geen deur op de wereldkaart.
- [ ] De party wordt automatisch gewarped naar het gebouw
  WorldWarperEnter.enter() wisselt naar het exterieur als de unlock-vlag er is. Niets op de kaart roept dat aan.
- [ ] Introductie van de AI-gids
  Placeholder IVA staat in de hal, vier stappen via Dialog.show_lines. De naam is TODO(design), geen canon.
- [ ] Duidelijk maken wat dit is, wat het kan, en waarom het belangrijk is
  Eerste-bezoekscène en IVA doen een eerste versie. De zinnen zijn TODO(design).

### Eerste binnenkomst: Hanger en Sapientia

- [x] Bij de eerste keer binnen: visueel effect
  Eerste versie. Paarse hal, roze Hanger (de Stroom), korte Zwarte Stroom, vlag world_warper_intro_seen. Zinnen zijn TODO(design). Geen H-6-onthulling.
  - [ ] Dennis' Hanger licht op (paarse gloed, reageert op de World Warper)
    Open ontwerp. De code gloeit roze (canon: roze = de Stroom). De hal is paars.
  - [ ] Systemen komen online door het Hanger-signaal
    De scène speelt één keer. Losse systemen gaan niet aan.
- [ ] Dialoogscène
  - [ ] Dennis toont de Hanger (eerste keer expliciet in het verhaal)
    De scène toont een roze Hanger. Dennis steekt hem niet apart op.
  - [ ] De AI-gids reageert herkennend op de Hanger
    IVA-stap hanger zegt dat de Hanger de Sleutel is.
  - [ ] Uitleg: alleen de Hanger kan de World Warper activeren
    De tekst noemt de Hanger de Sleutel. Ze zegt niet dat alleen die de hub start.
- [ ] Sapientia-dreiging
  - [ ] Na de activering verschijnt Sapientia (glitch, stem of hologram)
    Korte zwarte flikkering en een haperend hologram. Geen stem en geen hologram van Sapientia.
  - [ ] Sapientia uit de dreiging: zij wil de World Warper
    De zin is: Sapientia weet dat de Sleutel hier is.
  - [ ] Duidelijk maken dat Dennis en de Hanger het enige obstakel zijn
  - [ ] Dreiging opbouwen voor latere acts
  - [ ] De party reageert geschokt; de AI-gids waarschuwt

### Interieur

- [x] Half functioneel: centrale hal en meerdere kamers
  Eerste versie. Placeholder-kaarten, tegels 16×16. Open: exterieur, hal, warp_ring, hanger_nis. codex_nis en sapientia_schot bestaan en blijven dicht.
- [ ] Sommige kamers zijn leeg bij de introductie en unlocken later per act
  codex_nis en sapientia_schot zijn leeg en dicht. world_warper_act2 en world_warper_act3 zet niemand.
- [x] Centrale hal met warp-platform (hoofdfunctie)
  Eerste versie. De hal opent de warp-UI. warp_ring is een aparte kamer: een rechthoek van paneeltegels, geen cirkel.
- [ ] Paars als signature kleur, in lijn met het Codex Monument
  Panelen en de hal zijn paars. De Hanger in de scène is roze.
- [ ] Hologrammen, schermen en tech-details
  Placeholder-hologram in de eerste-bezoekscène en bij IVA. Geen echte schermen.
- [x] Alle party-leden en Codex-monsters lopen vrij rond in het gebouw
  Eerste versie, in de hal. Placeholders uit party en codex_pages. Geen loop-animatie.

### Bewoners van de hub

- [x] Huidige party-leden lopen rond (Dennis, Noor, Lotte, en latere leden)
  Eerste versie. Placeholders uit GameState.party, bij het laden van de hal. Geen loop-animatie.
- [x] Gevangen Codex-monsters lopen rond
  Eerste versie. Placeholders uit codex_pages. Geen loop-animatie.
- [ ] Nieuwe party-leden voegen zich toe zodra ze aansluiten
  refresh() leest de party bij het laden van de hal. Midden in de kamer werkt dat niet live bij.
- [ ] Reageren party-leden op locatie en verhaalprogressie? (design nog open)

### AI-gids (in de main PC)

- [ ] De AI-gids zit in de main PC van het warp-platform
  Placeholder IVA staat in de hal (ww_anchor_gids), niet in de warp-ring.
- [ ] Functie: questvoortgang, missie-uitleg en begeleiding
  Vier vaste stappen via Dialog.show_lines. Geen questvoortgang.
- [ ] Naam nog te bepalen
  Placeholder IVA, TODO(design), geen canon.
- [ ] Uiterlijk: hologram met paarse gloed
  Paars vlak met het woord PLACEHOLDER.
- [ ] Reageert op verhaalprogressie (nieuwe dialoog per act)
  Vlaggen world_warper_guide_0 tot en met 3, in volgorde. Niet per act.
- [ ] Geeft hints bij vastlopen en de volgende bestemming
  Vier vaste zinnen. Geen hint als de speler vastloopt.
- [ ] Herkent de Hanger en weet mogelijk meer over Dennis en H-6 dan hijzelf
  De hanger-stap noemt de Hanger de Sleutel. Over H-6 zegt de tekst niets.

### Warp-systeem

- [x] Wereldkaart-view opent bij gebruik van het warp-platform
  Eerste versie, vanuit de hal, in twee stappen. Landing op de wereldkaart is de bestaande spawn van_dorp.
- [x] Eerste keuze: welke worldmap (WM1, WM2 of WM3)
  Eerste versie. WM2 en WM3 zijn zichtbaar en vergrendeld. Alleen WM1 is open.
- [x] Tweede keuze: welk dorp op die worldmap
  Eerste versie op WM1: wereldkaart (van_dorp), Wilgendal (zuid_ingang), Esdoorn (zuid_ingang).
- [x] Alleen ontgrendelde worldmaps zijn selecteerbaar
  Eerste versie. Alleen WM1. WM2 en WM3 tonen Vergrendeld.
- [ ] Alleen ontgrendelde dorpen zijn selecteerbaar
  Het bezoek-filter ontbreekt. De drie WM1-plaatsen zijn altijd kiesbaar.
- [ ] Visuele stijl: paars, holografisch, sciencefiction
  Paarse vlakke panelen met PLACEHOLDER. Geen hologram.

### Ontgrendeling per worldmap

- [ ] Na Archief 2: World Warper actief, WM1 en WM2 beschikbaar
  De hub gaat open na bewaker:archief_v2_trapzaal/m2 (verdieping 2 van het Eerste Archief). Alleen WM1 is open.
- [ ] Na afronden van WM2 (Archief 3 en 4): WM3 ontgrendelt
- [ ] Elk dorp moet eerst bezocht zijn voordat je ernaartoe kunt warpen
  Dat filter ontbreekt.

### Functionaliteit in de World Warper

- [x] Opslaan (save point)
  Eerste versie. Nederlandse bevestiging: Opslaan?, Ja, Nee, Opgeslagen. Schrijft GameState.save_game(Vector2i(0, 0), Vector2i(0, 1)).
- [ ] Party kiezen en wisselen
  Kijklijst Gezelschap: naam en niveau. Wisselen ontbreekt; er is geen API.
- [ ] Questvoortgang via de AI-gids
  IVA heeft vier vaste stappen (world_warper_guide_0 tot en met 3). Geen questvoortgang.
- [x] Party-leden en Codex-monsters lopen vrij rond
  Eerste versie. Placeholders uit party en codex_pages, in de hal. Geen loop-animatie.
- [ ] Latere kamers unlocken per act (invulling nog te bepalen)
  De deuren naar codex_nis en sapientia_schot blijven dicht.
  - [ ] Welke kamers? (crafting, training, shops, Codex — design nog open)
- [ ] Bestiarium of Codex beheren, indien van toepassing

### Audio

- [x] Ambient tech-muziek (rustig, mysterieus, sciencefiction)
  Eerste versie. Aanroep ww_ambient. Geen bestand, geen manifest-entry, blijft stil.
- [x] Hum als achtergrondgeluid (constante lage toon)
  Eerste versie. Aanroep ww_hum. Geen bestand, geen manifest-entry, blijft stil.
- [x] Warp-geluid bij het activeren van het platform
  Eerste versie. Aanroep ww_warp. Geen bestand, geen manifest-entry, blijft stil.
- [ ] Geluid bij de eerste Hanger-activatie
  Bij hanger_activated gaat ww_sapientia_glitch af. Een eigen Hanger-geluid ontbreekt, en ook dat blijft stil.
- [x] Sapientia-stem of glitch-geluid voor de dreigingsscène
  Eerste versie. Aanroep ww_sapientia_glitch. Geen bestand, geen manifest-entry, blijft stil.
- [ ] Stem of hologramgeluid van de AI-gids

### Visuals en art

- [ ] Exterieur van de World Warper (zwevend, paars, hightech)
  Placeholder-kaart, tegels 16×16. Zweeft niet. Staat niet in tools/placeholders_v17.txt.
- [ ] Interieur-tileset (paars, holografisch, sciencefiction)
  tiles_placeholder.png, tegels 16×16, met het woord PLACEHOLDER. Niet geregistreerd.
- [ ] Sprite van het warp-platform
  warp_ring is een rechthoek van paneeltegels. Geen sprite.
- [ ] Sprite van de main PC
- [ ] Hologram-sprite of animatie van de AI-gids
  Paars vlak met PLACEHOLDER. Geen sprite.
- [ ] Oplicht-effect van de Hanger (paarse gloed)
  Open ontwerp. De code gloeit roze (de Stroom).
- [ ] Verschijning van Sapientia (glitch of hologram)
  Korte zwarte flikkering van het hologram. Geen glitch-sprite.
- [ ] UI van de wereldkaart-view (WM1, WM2, WM3, daarna dorp)
  Paarse vlakke knoppen met PLACEHOLDER. WM2 en WM3 zijn vergrendeld.
- [ ] Loop-animaties van party-leden en Codex-monsters in de hub
  Rondlopers zijn gekleurde vlakken. Geen loop-animatie.

### Verhaal-integratie

- [ ] Dennis' Hanger is de sleutel; dat meermaals benadrukken in dialoog
  Eerste-bezoekscène en de IVA-stap hanger noemen de Hanger de Sleutel. Zinnen zijn TODO(design). Geen H-6.
- [ ] Sapientia's interesse in de World Warper opbouwen als dreiging
  Eén zin: Sapientia weet dat de Sleutel hier is.
- [ ] De AI-gids kent de Oude Mensheid, of doet alsof
- [ ] De AI-gids weet mogelijk meer over Dennis en H-6 dan hijzelf
  De tekst doet dat bewust niet.

### Verhaal nog open

- [ ] Naam van de AI-gids bepalen
- [ ] Exacte relatie tussen de World Warper en Archief 4 (oorsprong van H-6)
- [ ] Waarom werkt het alleen op de Hanger?
- [ ] Wat Sapientia precies met de World Warper wil
- [ ] Latere kamers: welke, wanneer, en wat ze doen
- [ ] Reageren party-leden op locatie en verhaalprogressie?

## Ingame-menu

Het huidige ingame-menu vervangen door losse knoppen. Elke knop opent meteen een scherm. Geen tussenmenu, tenzij het bord "MENU" op de schets alleen een label blijft.

De vier functies zijn besloten. Welke functie op welke plek staat, blijft open.

- [ ] Huidige ingame-menu vervangen door losse knoppen die direct een scherm openen
  Niet eerst een tussenmenu. Het goudgerande bord "MENU" mag als label blijven staan.
- [ ] Knop Uitrusting (equip)
- [ ] Knop Codex
- [ ] Knop Items
- [ ] Knop Warp naar de warp-hub (World Warper)
  De hub zelf is nog ontwerp. De knop is wel een requirement. Bestaat de hub nog niet, dan blijft de knop een open punt. Niet bouwen.
- [ ] Indeling volgens de schets
  Goudgerand bord "MENU" rechtsboven. Links drie gestapelde liggende knoppen. Rechts daarvan een groter vlak. Welke functie waar staat is nog open.
- [ ] Spelertekst later Nederlands: Uitrusting, Codex, Items, Warpen
  Nu alleen deze TODO. Nog geen schermtekst.
