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

In elke dungeon (Archief 1 tot en met 6) staan warpers op vaste plekken.

- [ ] Midden van de dungeon: warper na de mini-baas
- [ ] Eind van de dungeon: warper na de eindbaas
- [ ] Geldt voor alle Archieven, inclusief Archief 1 (het Eerste Archief)
- [ ] Geldt ook voor de Diepe Grot (na de mini-baas en na verdieping 100)
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
- [ ] Een zwevend hightech gebouw verschijnt: de World Warper
- [ ] De party wordt automatisch gewarped naar de World Warper
- [ ] De World Warper is de hub om tussen de 3 hoofdeilanden te reizen
- [ ] Eerste introductie van het warp-systeem in het verhaal
- [ ] Vanaf hier kan de speler terug naar eerder bezochte eilanden
- [ ] De cutscene maakt duidelijk wat de World Warper is en doet

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
- [ ] Art voor de World Warper-cutscene

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

Zwevend hightech hub. Verschijnt na het verslaan van De Genezer (Archief 2).

### Concept en lore

- [ ] Zwevend hightech gebouw, mix van technologie van de Oude Mensheid en Sapientia
- [ ] Oorspronkelijk gebouwd door de Oude Mensheid als verbinding tussen de Archieven
- [ ] Sapientia heeft het offline gehouden en wil het zelf in handen krijgen
- [ ] Het werkt alleen op Dennis' Hanger; de Hanger is de enige sleutel
- [ ] Dat maakt Dennis (Proefpersoon H-6) onmisbaar voor Sapientia's plannen
- [ ] Komt online zodra twee Archieven (1 en 2) geactiveerd zijn

### Verschijning en cutscene

- [ ] Cutscene na De Genezer: de World Warper verschijnt in de lucht
- [ ] De party wordt automatisch gewarped naar het gebouw
- [ ] Introductie van de AI-gids
- [ ] Duidelijk maken wat dit is, wat het kan, en waarom het belangrijk is

### Eerste binnenkomst: Hanger en Sapientia

- [ ] Bij de eerste keer binnen: visueel effect
  - [ ] Dennis' Hanger licht op (paarse gloed, reageert op de World Warper)
  - [ ] Systemen komen online door het Hanger-signaal
- [ ] Dialoogscène
  - [ ] Dennis toont de Hanger (eerste keer expliciet in het verhaal)
  - [ ] De AI-gids reageert herkennend op de Hanger
  - [ ] Uitleg: alleen de Hanger kan de World Warper activeren
- [ ] Sapientia-dreiging
  - [ ] Na de activering verschijnt Sapientia (glitch, stem of hologram)
  - [ ] Sapientia uit de dreiging: zij wil de World Warper
  - [ ] Duidelijk maken dat Dennis en de Hanger het enige obstakel zijn
  - [ ] Dreiging opbouwen voor latere acts
  - [ ] De party reageert geschokt; de AI-gids waarschuwt

### Interieur

- [ ] Half functioneel: centrale hal en meerdere kamers
- [ ] Sommige kamers zijn leeg bij de introductie en unlocken later per act
- [ ] Centrale hal met warp-platform (hoofdfunctie)
- [ ] Paars als signature kleur, in lijn met het Codex Monument
- [ ] Hologrammen, schermen en tech-details
- [ ] Alle party-leden en Codex-monsters lopen vrij rond in het gebouw

### Bewoners van de hub

- [ ] Huidige party-leden lopen rond (Dennis, Noor, Lotte, en latere leden)
- [ ] Gevangen Codex-monsters lopen rond
- [ ] Nieuwe party-leden voegen zich toe zodra ze aansluiten
- [ ] Reageren party-leden op locatie en verhaalprogressie? (design nog open)

### AI-gids (in de main PC)

- [ ] De AI-gids zit in de main PC van het warp-platform
- [ ] Functie: questvoortgang, missie-uitleg en begeleiding
- [ ] Naam nog te bepalen
- [ ] Uiterlijk: hologram met paarse gloed
- [ ] Reageert op verhaalprogressie (nieuwe dialoog per act)
- [ ] Geeft hints bij vastlopen en de volgende bestemming
- [ ] Herkent de Hanger en weet mogelijk meer over Dennis en H-6 dan hijzelf

### Warp-systeem

- [ ] Wereldkaart-view opent bij gebruik van het warp-platform
- [ ] Eerste keuze: welke worldmap (WM1, WM2 of WM3)
- [ ] Tweede keuze: welk dorp op die worldmap
- [ ] Alleen ontgrendelde worldmaps zijn selecteerbaar
- [ ] Alleen ontgrendelde dorpen zijn selecteerbaar
- [ ] Visuele stijl: paars, holografisch, sciencefiction

### Ontgrendeling per worldmap

- [ ] Na Archief 2: World Warper actief, WM1 en WM2 beschikbaar
- [ ] Na afronden van WM2 (Archief 3 en 4): WM3 ontgrendelt
- [ ] Elk dorp moet eerst bezocht zijn voordat je ernaartoe kunt warpen

### Functionaliteit in de World Warper

- [ ] Opslaan (save point)
- [ ] Party kiezen en wisselen
- [ ] Questvoortgang via de AI-gids
- [ ] Party-leden en Codex-monsters lopen vrij rond
- [ ] Latere kamers unlocken per act (invulling nog te bepalen)
  - [ ] Welke kamers? (crafting, training, shops, Codex — design nog open)
- [ ] Bestiarium of Codex beheren, indien van toepassing

### Audio

- [ ] Ambient tech-muziek (rustig, mysterieus, sciencefiction)
- [ ] Hum als achtergrondgeluid (constante lage toon)
- [ ] Warp-geluid bij het activeren van het platform
- [ ] Geluid bij de eerste Hanger-activatie
- [ ] Sapientia-stem of glitch-geluid voor de dreigingsscène
- [ ] Stem of hologramgeluid van de AI-gids

### Visuals en art

- [ ] Exterieur van de World Warper (zwevend, paars, hightech)
- [ ] Interieur-tileset (paars, holografisch, sciencefiction)
- [ ] Sprite van het warp-platform
- [ ] Sprite van de main PC
- [ ] Hologram-sprite of animatie van de AI-gids
- [ ] Oplicht-effect van de Hanger (paarse gloed)
- [ ] Verschijning van Sapientia (glitch of hologram)
- [ ] UI van de wereldkaart-view (WM1, WM2, WM3, daarna dorp)
- [ ] Loop-animaties van party-leden en Codex-monsters in de hub

### Verhaal-integratie

- [ ] Dennis' Hanger is de sleutel; dat meermaals benadrukken in dialoog
- [ ] Sapientia's interesse in de World Warper opbouwen als dreiging
- [ ] De AI-gids kent de Oude Mensheid, of doet alsof
- [ ] De AI-gids weet mogelijk meer over Dennis en H-6 dan hijzelf

### Verhaal nog open

- [ ] Naam van de AI-gids bepalen
- [ ] Exacte relatie tussen de World Warper en Archief 4 (oorsprong van H-6)
- [ ] Waarom werkt het alleen op de Hanger?
- [ ] Wat Sapientia precies met de World Warper wil
- [ ] Latere kamers: welke, wanneer, en wat ze doen
- [ ] Reageren party-leden op locatie en verhaalprogressie?
