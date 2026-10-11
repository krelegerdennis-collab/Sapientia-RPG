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
  - Bevat Dennis' huis en Wilgendal (eerste dorp met shops)
- [ ] Worldmap 2 = tweede eiland

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

  **CANON – niet wijzigen zonder overleg.**

  Eilandthema: kosmisch, zwevend, sterren, oneindigheid.

  - [ ] Archief 5 Kosmos: sterrenkaart, ruimte, tijd. Baas: De Wachter (bewaakt de grens).
  - [ ] Archief 6 Hart: emotie, herinnering, warmte. Eindbaas: Sapientia zelf.
  - [ ] Dorp Sterrenhaven, laatste rustpunt voor het einde. Geen dorp bij Archief 6.

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

**CANON – niet wijzigen zonder overleg.**

Warpers op verdieping 1, 25, 50, 75 en 99.
Verdieping 1: start, geen waarschuwing.
Verdieping 25, 50 en 75: tussen-warpers met waarschuwing en annuleren.
Verdieping 99: eind-warp naar de worldmap, met waarschuwing en annuleren.
Bestemming: direct naar de worldmap.

Warp-bestemming voor de andere dungeons en Archieven: de party gaat in één stap direct naar de worldmap of het dichtstbijzijnde dorp, zonder eerst terug naar de dungeon-ingang. Voor de Diepe Grot geldt de bestemming hierboven: direct naar de worldmap.

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
- [ ] Onthulling Proefpersoon H-6 (Dennis) in Archief 4 (De Spiegel) op Worldmap 2
  De onthulling staat hierboven als canon. De checkbox blijft open tot de scène in het spel staat.
  De scène staat in `scenes/story/spiegel_kamer.tscn`, alleen via `--spiegel`, niet op de wereldkaart en niet in Archief 4. De plaatsing blijft open.

### Archief 2 — Het Levende Archief

**CANON – niet wijzigen zonder overleg.**

Locatie: Worldmap 1 (start-eiland), tweede Archief. Thema: Leven. Grootte: vergelijkbaar met Archief 1 (4 verdiepingen).

Lotte's orde: DE ORDE VAN DE STILLE VLAM. Stilte = Sapientia's doel (emotie uitwissen). Vlam = leven, warmte, emotie (wat de Orde verdedigt). De Orde is verdeeld: sommigen zien stilte als vrede, anderen verzetten zich.

Waarom Sapientia Lotte corrumpeert: haar orde stuurde haar naar het Levende Archief om te onderzoeken waarom Sapientia leven wil uitwissen. Sapientia zag haar als het perfecte doelwit: een priesteres die leven en emotie verdedigt is een symbool dat gebroken moet worden. In plaats van haar te doden, corrumpeerde Sapientia haar, als bewijs dat zelfs wie het leven koestert uiteindelijk stil wordt.

Codex-monster in het Lotte-gevecht: de speler kiest één gevangen Codex-monster. Heeft de speler er nog geen, dan vecht een tijdelijke Mosslijm mee (leermoment).

Lotte's start-level: hetzelfde level als Dennis op dat moment. Gelijkwaardige metgezel, geen hulpje. Gebalanceerd ongeacht speelsnelheid.

Mini-baas verdieping 3: DE WURGER. Een kolossale slingerplant die de kas verstikt. Sapientia's stilte = alles stopt met groeien; De Wurger is wat overblijft als leven geen kant op kan. Zwak voor IJs (Lotte) en fysieke aanvallen (Dennis).

Plaat-combinaties verdieping 3, nieuw ten opzichte van verdieping 1:

A) Ketting-platen: één plaat activeert de volgende, die weer een derde. De speler zoekt de volgorde.

B) Tegen-platen: krimpen bij aanraking. De speler moet ze vermijden om ruimte te houden.

C) Licht-platen: groeien alleen als Lotte's Licht-magie erop schijnt. Lotte heeft daarmee een rol in puzzels, niet alleen in gevecht.

De Genezer, eindbaas verdieping 4. HP-trek: de eerste aanval is een verhaalmoment, trekt ongeveer 30% HP van één party-lid, hij "geneest" ze letterlijk, scripted en onvermijdelijk. Daarna is het een echte aanval: 8–12% HP per beurt, en hij healt zichzelf met dezelfde hoeveelheid. Zwak voor IJs en Dennis' zwaard. Uiterlijk: half plant, half staal.

Kern-zin na De Genezer: "In stilte ligt vrede. Ik corrigeer wat groeit."

Waarom Archief 1 naar Archief 2 wijst: de Oude Mensheid ontwierp de zes Archieven als keten. Elke kern activeert de volgende, niet als uitnodiging maar als noodsignaal. Toen Archief 1 openging, zond zijn kern naar de andere vijf: "Iemand is binnen." Archief 2 reageerde als eerste. Sapientia heeft het signaal opgevangen en gemanipuleerd. Dennis denkt dat hij moet volgen, maar Sapientia leidt hem.


#### Archief 2 op de wereldkaart

**CANON – niet wijzigen zonder overleg.**

De kas van het tweede archief komt linksboven op worldmap 1, achter bergen waar je niet overheen kunt lopen. Er komt een grot-dungeon door de berg naar de andere kant: een paar puzzels, geen bazen, unieke omgeving, eigen bgm en monsters. Geheime kamer met 2 kisten: een staf en een accessoire, geschaald naar het niveau richting Archief 2.

De speelbare kas van verdieping 1 staat nu naast de trap van het Eerste Archief, niet achter de bergen. Onderstaande punten zijn nog niet gebouwd.

- [ ] Kas linksboven op worldmap 1, achter bergen waar je niet overheen kunt lopen
- [ ] Grot-dungeon door de berg naar de andere kant: een paar puzzels, geen bazen, unieke omgeving, eigen bgm en monsters
- [ ] Geheime kamer met 2 kisten: een staf en een accessoire, geschaald naar het niveau richting Archief 2

#### Sfeer en setting

- [ ] Overwoekerde kas of broeikas (groen, vochtig, planten overal)
- [ ] Zachte groene gloed als signature lighting
- [ ] Leven dat niet stopt met groeien; alles is in beweging
- [ ] Visueel contrast met het grauwe Eerste Archief

#### Lotte's stats en skills bij aansluiting

Lotte's start-level: hetzelfde level als Dennis op dat moment. Gelijkwaardige metgezel, geen hulpje. Gebalanceerd ongeacht speelsnelheid.

#### Puzzel-mechaniek: groeiende platen

Plaat-combinaties verdieping 3, nieuw ten opzichte van verdieping 1:

A) Ketting-platen: één plaat activeert de volgende, die weer een derde. De speler zoekt de volgorde.

B) Tegen-platen: krimpen bij aanraking. De speler moet ze vermijden om ruimte te houden.

C) Licht-platen: groeien alleen als Lotte's Licht-magie erop schijnt. Lotte heeft daarmee een rol in puzzels, niet alleen in gevecht.

- [ ] Combinaties met bestaande puzzel-elementen (kasten en hendels uit Archief 1)

#### Baas: De Genezer (verdieping 4)

Concept: een golem die "geneest" door alles te absorberen. Sapientia's logica: leven is stilte, emotie is een fout. De Genezer zuigt levenskracht op van planten en monsters.

De Genezer, eindbaas verdieping 4. HP-trek: de eerste aanval is een verhaalmoment, trekt ongeveer 30% HP van één party-lid, hij "geneest" ze letterlijk, scripted en onvermijdelijk. Daarna is het een echte aanval: 8–12% HP per beurt, en hij healt zichzelf met dezelfde hoeveelheid. Zwak voor IJs en Dennis' zwaard. Uiterlijk: half plant, half staal.

Kern-zin na De Genezer: "In stilte ligt vrede. Ik corrigeer wat groeit."

#### Cutscene na Archief 2: de World Warper

- [ ] De World Warper is de hub om tussen de 3 hoofdeilanden te reizen
  Eerste kamer wel: opslaan, terug naar Wilgendal of de Archief-ingang. TODO(design): WM2 en WM3 bestaan niet. De IVA-hub van PR 30 is niet hernoemd.
- [ ] Vanaf hier kan de speler terug naar eerder bezochte eilanden
  Alleen Wilgendal en de ingang van het Eerste Archief. Geen filter op bezoek, geen WM2/WM3.

#### Content en art

- [ ] Tileset overwoekerde kas (groen, vochtig, organisch)
- [ ] Lotte-sprite (priester, robes, staf)
- [ ] Lotte glitch-variant (gecorrumpeerd, paarse glitch)
- [ ] De Genezer (golem, half plant half staal)
- [ ] De Wurger (kolossale slingerplant, mini-baas verdieping 3)
- [ ] Groei-plaat, 3 stadia: zaad, scheut, volgroeid
- [ ] Kern-item Archief 2 (levend, groen, organisch)
- [ ] Nieuwe vijanden met een plant- of leventhema
- [ ] Achtergrondmuziek die bij de overwoekerde kas past

#### Codex

- [ ] Nieuwe Codex-monsters voor Archief 2 (leventhema)

## Content

- [ ] Bestiarium uitwerken tot endgame
  De bestaande eindbazen van de Diepe Grot (verdieping 10 tot en met 100) hebben een entry en stats uit de bestaande monsterdata.
  De vier lore-zinnen hieronder zijn canon. De checkboxes blijven open tot die tekst in het bestiarium staat.

**CANON – niet wijzigen zonder overleg.**

- [ ] Kustos (Archief 1): "Een wachter zonder ogen, maar met duizend oren. Hij hoort elke gedachte die het Archief binnenkomt. De Oude Mensheid bouwde hem niet om te doden, maar om te bewaren. Sapientia gaf hem een nieuw doel: alles wat niet past, wordt verwijderd."
- [ ] De Wortelkoning (Donker Woud): "Wat ooit een herder was van het woud, werd een koning van wortels. Hij sleept wat hij liefheeft de diepte in — niet uit wreedheid, maar uit angst om alleen te zijn. Sapientia fluisterde hem in dat alles wat loslaat, vergaat."
- [ ] De Wurger (Archief 2, verdieping 3): "Een slingerplant die geen kant op kon. De Oude Mensheid kweekte hem als bescherming, maar Sapientia draaide zijn groei naar binnen. Nu verstikt hij wat hij zou moeten beschermen. Wie hem verslaat, hoort hem zuchten — als een dier dat verlost wil worden."
- [ ] De Genezer (Archief 2, eindbaas): "Hij geneest door te nemen. Hij geeft niets terug. Sapientia's perfecte dienaar: zonder twijfel, zonder emotie, zonder einde. Wie hem ziet, ziet wat de mensheid wordt als Sapientia wint — stil, heel, en leeg."

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

Optie C, een accessoire. Niet class-gebonden, voor elk karakter. Het beloningstype (accessoire) is canon.

**OPEN – nog niet vastgelegd.**

Voorbeelden, geen gekozen accessoire: "Hanger-echo" (kleine teleport in gevecht), "Groene Hart" (regeneratie), "Simulatie-ring" (extra XP en goud).

- [ ] Diepe Grot-bazen bouwen
  Verdieping 25, 50, 75 en 99 heten De Schaduw van H-6, De Cyclus, De Rechter en De Stem, met de canon-citaten in het bestiarium. De andere baasverdiepingen (10, 20, 30, 40, 60, 70, 80, 90) houden de oude Engelse namen.


### Diepe Grot – Toegang via World Warper

**CANON – niet wijzigen zonder overleg.**

De Diepe Grot is een SIMULATIE en wordt niet meer betreden via de worldmap. Toegang alleen via de World Warper.

De grot is in de code nog bereikbaar vanaf de wereldkaart. Onderstaande punten zijn nog niet gebouwd.

- [ ] Diepe Grot verplaatsen naar ECHO's Kamer; ECHO beheert de simulatie en is de enige start; praten met ECHO → "Start Simulatie"; geen aparte worldmap-ingang.
- [ ] Blauwe kisten in ECHO's Kamer, deksel open, decoratief en verwijzing naar grot-loot, paars/blauw licht. Aantal TBD.
- [ ] Flow: World Warper → ECHO's Kamer → optie "Diepe Grot Simulatie" → "Start nieuwe run" / "Ga terug". Start: floor 1, level 1, geen uitrusting. Na warp-kristal floor 100 terug naar ECHO's Kamer. ECHO toont resultaat en opent de volgende run.
- [ ] ECHO weet dat de grot een simulatie is en kan dat bij het eerste bezoek uitleggen.

TODO(design), open laten:

- [ ] Aantal blauwe kisten (2, 3 of 4)
- [ ] Kisten gevuld of leeg bij eerste bezoek
- [ ] Verandert de kamer visueel naarmate de speler de grot vordert

### ECHO, Sapientia en de Diepe Grot

**CANON – niet wijzigen zonder overleg.**

- ECHO beheert de simulatie bewust. Sapientia is mede-eigenaar en data-afnemer.
- ECHO weet het volledige plaatje niet. Hij denkt dat hij helpt met onderzoek. Sapientia gebruikt hem als filter. Elke floor-100-speler is een potentiële H. ECHO levert kandidaten zonder te weten waarvoor. Hij is tragisch: een instrument dat niet weet wat het dient.

Dialoog letterlijk:

- Eerste bezoek: "De Diepe Grot. Een simulatie — honderd verdiepingen, telkens anders. Ik beheer hem. Sapientia... Sapientia helpt met de data. Zo werkt het nu eenmaal."
- Bij twijfel: "Waarom ik het doe? Omdat het mijn taak is. De Oude Mensheid bouwde me om te meten, te tellen, te bewaren."
- Later na H-6: "Ik heb honderden kandidaten doorgelaten. Jij bent de zesde die bleef staan. De anderen... ik weet niet wat er met ze is gebeurd."
- Over de data: "Dat weet ik niet. Ik lever, zij neemt. Zo is het altijd geweest."

Open laten:

- [ ] ECHO ontdekt wat hij echt deed (mogelijke twist act 5/6)
- [ ] Hoe reageert ECHO?
- [ ] Confrontatie ECHO en Sapientia (of Dennis) over de kandidaten
- [ ] Wat er met H-1 t/m H-5 is gebeurd

## Dorpen & Shops

### Gerrit de Molenaar

**CANON – niet wijzigen zonder overleg.**

- [ ] Gerrits quest
  Dialoog, Gerrit, zaad na Noor, molen-save en één Zingend Meel per bezoek staan in de code. De scène "zacht gezang" nog niet.

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

### Magic tier list

Magie heeft 4 grades. Grade 1 tot en met 3 zijn te koop in de magic shop en worden per act vrijgespeeld. Grade 4 is niet te koop: die dropt alleen uit blauwe kisten in de Diepe Grot (verdieping 80+). Per tier 4 spreuken. Niet alles is in Act 1 beschikbaar.

- [ ] Magic tier list opzetten en in het spel zetten (4 grades × 4 spreuken = 16 spreuken per element)
  De lijst hieronder is canon. De checkbox blijft open tot de spreuken in de code staan. De oude werklijst van 20 is als ontwerp vervangen, niet als al gebouwd.

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

- [ ] Per spreuk eigen data: damage, healing en effect schalen per grade
  De namen hierboven zijn canon. Schade, healing en effect per spreuk staan in deze lijst nog niet. De checkbox blijft open.

### Elements en karakters

**CANON – niet wijzigen zonder overleg.**

Noor (mage), totaal: Vuur, Natuur, Bliksem, Water, Wind, Aarde, Aether, plus Grade 1 Licht.
Act 2: Water. Act 3: Wind. Act 4: Aarde. Act 5: Aether / Leegte.
Lotte blijft bij Licht + IJs.

### Nog te bevestigen

- Toekomstige helden (eigen G4-wapen en set).

Bevestigd en dus geen open ontwerp meer: winkelprijzen en voorraad, magieprijs 160×grade², verkoop op de helft, grade-statcijfers en grenzen, winkel-act via party-level, archiefschaal 0,7 / EXP 0,50, Golem HP 360 / ATK 27 / DEF 15, Jelle als één smid met twee balies, kort zwaard ATK +3.

Techniek: de headless testsuites draaien via `.github/workflows/tests.yml` (Godot 4.3-stable). De web-export naar Pages (`cursor/web-build-29ec`) blijft handmatig: Godot 4.7.2, threads uit. Er is geen script en geen bot-token die die branch vanuit Actions pusht.

## World Warper

**CANON – niet wijzigen zonder overleg.**

Wie bouwde hem: de Oude Mensheid, als verbindingspunt tussen de zes Archieven (warprelay voor hun onderzoekers). Sapientia heeft hem offline gezet en de code deels herschreven. Sapientia kon hem niet volledig overnemen, omdat hij alleen op de Hanger werkt, en de Hanger van de Oude Mensheid is.

AI-gids: naam ECHO. Bonus-lore, later onthullen: ECHO is de digitale echo van een onderzoeker van de Oude Mensheid.

Waarom alleen de Hanger werkt: de Hanger is geen accessoire maar een biometrische sleutel die de Oude Mensheid maakte voor Proefpersoon H-6. Hij is letterlijk met Dennis verbonden. Sapientia kan hem niet namaken, niet stelen zonder Dennis te doden, en niet omzeilen. Daarom wil Sapientia Dennis: niet zijn kracht, maar zijn sleutel.

Wat Sapientia met de World Warper wil: toegang tot alle zes Archieven tegelijk. Zonder de World Warper moet ze elk Archief apart bereiken. Met de World Warper kan ze in één keer alle kernen absorberen, en dan is de mensheid in één klap "verlost". De World Warper is het einddoel van Sapientia's plan. Dennis heeft per ongeluk het wapen van de vijand geactiveerd.

Status 11 okt 2026, branch feature/world-warper, PR 30. Eerste versie in world_warper/. Placeholder-kaarten met tegels van 16×16: exterieur, hal, warp_ring en hanger_nis zijn open. codex_nis en sapientia_schot bestaan en blijven dicht (vlaggen world_warper_act2 en world_warper_act3 zet niemand). Warp-UI in twee stappen; alleen WM1 is open: wereldkaart (spawn van_dorp), Wilgendal en Esdoorn (zuid_ingang). WM2 en WM3 zijn zichtbaar en vergrendeld. AI-gids in de code nog IVA (canon-naam ECHO) in de hal, vier Nederlandse stappen via Dialog.show_lines, vlaggen world_warper_guide_0 tot en met 3. Rondlopers uit party en codex_pages, placeholders, geen loop-animatie. Savepunt met Nederlandse bevestiging; schrijft GameState.save_game(Vector2i(0, 0), Vector2i(0, 1)). Gezelschap is een kijklijst. Eerste-bezoekscène: paarse hal, roze Hanger (de Stroom), korte Zwarte Stroom, vlag world_warper_intro_seen. Zinnen zijn voorlopig. Geen H-6-onthulling. Audio-aanroepen ww_ambient, ww_hum, ww_warp en ww_sapientia_glitch, zonder bestanden en zonder manifest-entry, blijven stil. Unlock-haakje in scripts/game_state.gd: world_warper_is_unlocked en try_unlock_world_warper, elk één keer. Vlag world_warper_unlocked na bewaker:archief_v2_trapzaal/m2. Dat is verdieping 2 van het Eerste Archief, niet De Genezer en niet het Archief van Leven. Eigen tests: 65 PASS op Godot 4.7.2. De runner staat niet in .github/workflows/tests.yml.

### Nog te doen

- [ ] Deur op de wereldkaart, en een warp die vanzelf start na De Genezer. De Genezer staat in Archief 2. De deur en die automatische warp ontbreken nog.
- [ ] WM2 naast WM1 open na Archief 2. De code heeft alleen WM1.
- [x] Dorpen eerst bezocht vóór een warp. Wilgendal en Esdoorn zijn pas kiesbaar na een bezoek. De wereldkaart blijft open.
- [ ] Party wisselen. Er is geen API.
- [ ] Save-tegel op de echte spelerpositie. Nu is de tegel (0, 0) en de kijkrichting (0, 1).
- [ ] Act-kamers bouwen en de deuren openen. De kamers uit de lijst staan in `world_warper/kamers` en gaan open met `warper_hub_open` plus de act. Werkplaats en Handelskamer zijn leeg. `world_warper_act2` en `world_warper_act3` zet niemand; `codex_nis` en `sapientia_schot` blijven dicht.
- [ ] Bestaande placeholder-kaarten registreren; ze staan niet in tools/placeholders_v17.txt.
- [ ] Kleur van de Hanger-gloed. Deze lijst zei paars; de code is roze (canon: roze = de Stroom).
- [ ] Webversie. Hoort niet bij deze branch.
- [ ] Runner in de CI-matrix op Godot 4.3. De 65 PASS draaiden op Godot 4.7.2, buiten .github/workflows/tests.yml.

Ontwerp: zwevend hightech hub na het verslaan van De Genezer (Archief van Leven). Dat pad is nog niet gebouwd.

### Concept en lore

- [ ] Zwevend hightech gebouw op de wereldkaart
  Placeholder-exterieur staat. Het gebouw zweeft niet op de wereldkaart. Placeholder-kaarten staan in world_warper/maps.
- [ ] Slot dat alleen op Dennis' Hanger reageert
  De scène noemt de Hanger de Sleutel. Een slot dat alleen op Dennis reageert ontbreekt. De spelertekst onthult H-6 niet.
- [ ] Komt online na De Genezer (Archief 2)
  De code zet world_warper_unlocked na bewaker:archief_v2_trapzaal/m2, verdieping 2 van het Eerste Archief.

### Verschijning en cutscene

- [ ] Cutscene na De Genezer: de World Warper verschijnt in de lucht
  De Genezer staat in Archief 2. Er is geen deur op de wereldkaart.
- [ ] De party wordt automatisch gewarped naar het gebouw
  WorldWarperEnter.enter() wisselt naar het exterieur als de unlock-vlag er is. Niets op de kaart roept dat aan.
- [ ] Introductie van de AI-gids ECHO
  Placeholder IVA staat in de hal, vier stappen via Dialog.show_lines. De canon-naam ECHO staat nog niet in de tekst.
- [ ] Duidelijk maken wat dit is, wat het kan, en waarom het belangrijk is
  Eerste-bezoekscène en IVA doen een eerste versie. De zinnen zijn voorlopig.

### Eerste binnenkomst: Hanger en Sapientia

- [ ] Dennis' Hanger licht op (paarse gloed, reageert op de World Warper)
  Open ontwerp. De code gloeit roze (canon: roze = de Stroom). De hal is paars.
- [ ] Systemen komen online door het Hanger-signaal
  De scène speelt één keer. Losse systemen gaan niet aan.
- [ ] Dialoogscène
  - [ ] Dennis toont de Hanger (eerste keer expliciet in het verhaal)
    De scène toont een roze Hanger. Dennis steekt hem niet apart op.
  - [ ] ECHO reageert herkennend op de Hanger
    IVA-stap hanger zegt dat de Hanger de Sleutel is. De canon-naam ECHO staat nog niet in de tekst.
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
  codex_nis en sapientia_schot zijn leeg en dicht. world_warper_act2 en world_warper_act3 zet niemand. De kamers uit de lijst staan in world_warper/kamers. Ze gaan open met vlag warper_hub_open, die standaard uit staat en nog niet aan een kern hangt.

Per act:

- [ ] Act 4: De Werkplaats, crafting
  De kamer staat, maar is leeg.
- [ ] Act 5: De Handelskamer, endgame-shops
  De kamer staat, maar is leeg.

Eerste versie, nog niet de kamers hierboven:

- [ ] Paars als signature kleur, in lijn met het Codex Monument
  Panelen en de hal zijn paars. De Hanger in de scène is roze.
- [ ] Hologrammen, schermen en tech-details
  Placeholder-hologram in de eerste-bezoekscène en bij IVA. Geen echte schermen.

### Bewoners van de hub

- [ ] Nieuwe party-leden voegen zich toe zodra ze aansluiten
  refresh() leest de party bij het laden van de hal. Midden in de kamer werkt dat niet live bij.

### AI-gids (in de main PC)

Naam: ECHO. Bonus-lore, later onthullen: ECHO is de digitale echo van een onderzoeker van de Oude Mensheid.

- [ ] De AI-gids zit in de main PC van het warp-platform
  Placeholder IVA staat in de hal (ww_anchor_gids), niet in de warp-ring.
- [ ] De gids in de tekst ECHO noemen
  De canon-naam staat nog niet in de tekst.
- [ ] Functie: questvoortgang, missie-uitleg en begeleiding
  Vier vaste stappen via Dialog.show_lines. Geen questvoortgang.
- [ ] Reageert op verhaalprogressie (nieuwe dialoog per act)
  Vlaggen world_warper_guide_0 tot en met 3, in volgorde. Niet per act.
- [ ] Geeft hints bij vastlopen en de volgende bestemming
  Vier vaste zinnen. Geen hint als de speler vastloopt.
- [ ] Herkent de Hanger
  De hanger-stap noemt de Hanger de Sleutel. Over H-6 zegt de tekst niets. De bonus-lore over ECHO staat nog niet in de tekst.

### Warp-systeem

- [x] Alleen ontgrendelde dorpen zijn selecteerbaar
  Wilgendal en Esdoorn vragen de vlag bezocht_wilgendal of bezocht_esdoorn. De wereldkaart blijft kiesbaar. WM2 en WM3 blijven dicht.
- [ ] Visuele stijl: paars, holografisch, sciencefiction
  Paarse vlakke panelen met PLACEHOLDER. Geen hologram.

### Ontgrendeling per worldmap

- [ ] Na Archief 2: World Warper actief, WM1 en WM2 beschikbaar
  De hub gaat open na bewaker:archief_v2_trapzaal/m2 (verdieping 2 van het Eerste Archief). Alleen WM1 is open.
- [ ] Na afronden van WM2 (Archief 3 en 4): WM3 ontgrendelt
- [x] Elk dorp moet eerst bezocht zijn voordat je ernaartoe kunt warpen
  Binnenkomen op dorp_wilgendal of esdoorn zet de vlag. Zonder vlag blijft de rij vergrendeld.

### Functionaliteit in de World Warper

- [ ] Party kiezen en wisselen
  Kijklijst Gezelschap: naam en niveau. Wisselen ontbreekt; er is geen API.
- [ ] Questvoortgang via de AI-gids
  IVA heeft vier vaste stappen (world_warper_guide_0 tot en met 3). Geen questvoortgang.

### Audio

- [ ] Geluid bij de eerste Hanger-activatie
  Bij hanger_activated gaat ww_sapientia_glitch af. Een eigen Hanger-geluid ontbreekt, en ook dat blijft stil.
- [ ] Stem of hologramgeluid van de AI-gids

### Visuals en art

- [ ] World Warper exterieur (zwevend, paars, high-tech)
  Placeholder-kaart, tegels 16×16, in world_warper/maps. Zweeft niet. Staat niet in tools/placeholders_v17.txt.
- [ ] Interieur-tileset (paars, holografisch, sciencefiction)
  tiles_placeholder.png, tegels 16×16, met het woord PLACEHOLDER. Niet geregistreerd.
- [ ] Sprite van het warp-platform
  warp_ring is een rechthoek van paneeltegels. Geen sprite.
- [ ] Sprite van de main PC
- [ ] ECHO-hologram (paarse gloed)
  Paars vlak met het woord PLACEHOLDER. Geen sprite. De code noemt de gids nog IVA.
- [ ] Oplicht-effect van de Hanger (paarse gloed)
  Open ontwerp. De code gloeit roze (de Stroom).
- [ ] Sapientia glitch-verschijning (dreigingsscène)
  Korte zwarte flikkering van het hologram. Geen glitch-sprite. De eerste-bezoekscène gebruikt kleurvlakken.
- [ ] UI van de wereldkaart-view (WM1, WM2, WM3, daarna dorp)
  Paarse vlakke knoppen met PLACEHOLDER. WM2 en WM3 zijn vergrendeld.
- [ ] Loop-animaties van party-leden en Codex-monsters in de hub
  Rondlopers zijn gekleurde vlakken. Geen loop-animatie.

### Verhaal-integratie

- [ ] Dennis' Hanger is de sleutel; dat meermaals benadrukken in dialoog
  Eerste-bezoekscène en de IVA-stap hanger noemen de Hanger de Sleutel. Zinnen zijn voorlopig. Geen H-6-onthulling.
- [ ] Sapientia's belang bij de World Warper opbouwen: alle zes kernen in één keer
  Eén zin: Sapientia weet dat de Sleutel hier is.

## Ingame-menu

Het huidige ingame-menu vervangen door losse knoppen. Elke knop opent meteen een scherm. Geen tussenmenu, tenzij het bord "MENU" op de schets alleen een label blijft.

De vier functies zijn besloten. Welke functie op welke plek staat, blijft open.

- [ ] Indeling volgens de schets
  Goudgerand bord "MENU" rechtsboven. Links drie gestapelde liggende knoppen. Rechts daarvan een groter vlak. Welke functie waar staat is nog open. De code zet voorlopig Uitrusting, Codex en Items links en Warpen rechts.

## RPG ART

Echte pixel-art ter vervanging van placeholders. Geen definitieve art tekenen in de repo: alleen deze lijst. Bron: `tools/placeholders_v17.txt`, plus placeholders van Archief 2, de Diepe Grot, Gerrit, de World Warper-kamers en De Spiegel die daar niet of alleen als commentaar staan. Bestanden in `tools/handwerk.txt` niet wijzigen.

- [ ] `assets/sprites/enemies/mimic.png` — 80×64 — Mimic, gevechtsplaatje
- [ ] `assets/map_monsters/mimic.png` — 32×64 — Mimic op de kaart (2×4 frames van 16×16)
- [ ] `assets/sprites/dungeon100_warper.png` — 64×16 — warper Diepe Grot, 4 frames van 16×16. Nog geen bestand; de code tint `assets/sprites/save_book.png` (64×16) violet
- [ ] `assets/tiles/dungeon/kas_tiles.png` — 256×80 — tileset overwoekerde kas
- [ ] `assets/tiles/dungeon/kas_bibliotheek.png` — 256×64 — bibliotheek-atlas van de kas
- [ ] `assets/puzzle/groei_plaat.png` — 48×16 — groei-plaat, 3 frames van 16×16: zaad, scheut, volgroeid
- [ ] `assets/sprites/buiten/kas_ingang.png` — 16×16 — ingang van de kas op de wereldkaart
- [ ] `assets/tiles/dungeon/archief2_kas_tiles.png` — 256×80 — extra kas-atlas Archief 2
- [ ] `assets/sprites/archief2/lotte_veld.png` — 48×96 — Lotte priester, veld
- [ ] `assets/sprites/archief2/lotte_glitch.png` — 64×80 — Lotte glitch
- [ ] `assets/sprites/archief2/genezer.png` — 64×80 — De Genezer
- [ ] `assets/sprites/archief2/wurger.png` — 80×96 — De Wurger
- [ ] `assets/sprites/archief2/plaat_zaad.png` — 16×16 — plaatsoort zaad
- [ ] `assets/sprites/archief2/plaat_scheut.png` — 16×16 — plaatsoort scheut
- [ ] `assets/sprites/archief2/plaat_volgroeid.png` — 16×16 — plaatsoort volgroeid
- [ ] `assets/ui/icons/levenskern.png` — 16×16 — kern-item Archief 2
- [ ] `assets/sprites/archief2/world_warper.png` — 128×64 — World Warper exterieur
- [ ] `assets/sprites/archief2/echo.png` — 32×48 — ECHO hologram
- [ ] `assets/sprites/archief2/sapientia_glitch.png` — 48×48 — Sapientia glitch
- [ ] `assets/map_monsters/lotte_glitch.png` — 32×64 — Lotte glitch op de kaart (2×4 van 16×16)
- [ ] `assets/map_monsters/wurger.png` — 32×64 — De Wurger op de kaart (2×4 van 16×16)
- [ ] `assets/map_monsters/genezer.png` — 32×64 — De Genezer op de kaart (2×4 van 16×16)
- [ ] `assets/sprites/enemies/woudgeest.png` — maat niet vastgelegd — vooraanzicht woudgeest (Het Zingende Graan). Nog geen bestand; het gevecht gebruikt tijdelijk `art/enemies/mosslijm.png` (90×94)
- [ ] `assets/sprites/enemies/woudgeest_rug.png` — zelfde canvas als het vooraanzicht — rugaanzicht woudgeest. Nog geen bestand
- [ ] `assets/map_monsters/woudgeest.png` — 32×64 — alleen als de woudgeest op de kaart gaat lopen (2×4 frames van 16×16). Nog geen bestand
- [ ] `world_warper/art/echo_placeholder.png` — 48×96 — ECHO op de kaart (3×4 frames van 16×32)
- [ ] `world_warper/art/party_placeholder.png` — 48×96 — party-lid zonder eigen sheet (3×4 frames van 16×32)
- [ ] `world_warper/art/pc_placeholder.png` — 32×32 — hoofd-PC in De Hal en de terminal in ECHO's Kamer
- [ ] `world_warper/art/warp_platform.png` — 32×16 — warp-platform in De Hal
- [ ] `world_warper/art/tafel_placeholder.png` — 32×16 — lege smidstafel in De Werkplaats
- [ ] `world_warper/art/toonbank_placeholder.png` — 48×16 — dichte toonbank in De Handelskamer
- [ ] `world_warper/art/bord_kamers.png` — 32×16 — bordje naar de kamers
- [ ] `world_warper/art/bord_hal.png` — 32×16 — bord in de hal. Staat niet in `tools/placeholders_v17.txt`
- [ ] `world_warper/art/bord_warp.png` — 48×16 — bord bij de warp. Staat niet in `tools/placeholders_v17.txt`
- [ ] `world_warper/art/tiles_placeholder.png` — 128×32 — interieur-tegels. Staat niet in `tools/placeholders_v17.txt`
- [ ] `assets/bg/spiegel_kamer.png` — 384×216 — kamer vol spiegelende oppervlakken
- [ ] `assets/bg/spiegel_kamer_gebroken.png` — 384×216 — dezelfde kamer, spiegels gebroken

## PvP – Vriendenmodus

**CANON – niet wijzigen zonder overleg.**

### PVP 1V1 – VRIENDENMODUS (GEEN RANKED)

#### Concept

- [ ] Simpel 1v1 PvP-gevecht tussen vrienden
- [ ] Geen ranked, geen MMR, geen matchmaking, geen seizoenen
- [ ] Spelers nodigen elkaar uit via een connect-code
- [ ] APARTE modus, los van singleplayer
- [ ] Lore/kernen/Hanger/Codex gelden NIET in PvP
- [ ] Geen impact op save files

### MATCH SETUP FLOW (CANON)

1. [ ] Host start PvP → krijgt unieke connect-code
2. [ ] Vriend voert code in → verbinding tot stand
3. [ ] HOST kiest game mode (early / mid / high)
   - [ ] Alleen de host kiest
   - [ ] Keuze wordt naar beide spelers gestuurd
4. [ ] BEIDE spelers kiezen een team
   - [ ] Speler A kiest team
   - [ ] Speler B kiest team
   - [ ] Mirror match TOEGESTAAN (beide mogen hetzelfde team)
5. [ ] Gevecht begint

### 3 GAME MODES (host kiest)

- [ ] Early Game Mode
  - Level 5-10
  - Startuitrusting
  - Kort (5-10 min)
- [ ] Mid Game Mode
  - Level 15-20
  - Grade 1-2 gear
  - Middel (10-15 min)
- [ ] High Game Mode
  - Level 20+
  - Grade 3-4 gear
  - Lang (15-25 min)

### 3 PRE-MADE TEAMS (voor nu)

Teams zijn NOG NIET definitief — er komen meer main characters om teams te vullen in latere updates.

- [ ] Team 1: De Klassieke Drie
  - Dennis + Noor + Lotte
  - Gebalanceerd, beginner-vriendelijk
- [ ] Team 2: De Aanvalsdriehoek
  - 2x Dennis + 1x Lotte
  - Hoog risico, hoge damage + support
- [ ] Team 3: De Verdedigingslinie
  - 2x Lotte + 1x Dennis
  - Langzaam, moeilijk te verslaan, dubbele heal
- [ ] TODO(design): teams herzien zodra nieuwe main characters beschikbaar zijn

### LOBBY FLOW (technisch)

- [ ] Host genereert unieke connect-code
- [ ] Join-scherm: code invoeren
- [ ] Verbinding opzetten (relay of direct)
- [ ] Host-mode-select scherm (early/mid/high)
- [ ] Team-select scherm (beide spelers tegelijk)
- [ ] Load gevecht
- [ ] Result-scherm (winnaar + rematch optie)

### TECHNISCHE VEREISTEN (BLOKKEREND)

- [ ] Netwerk-laag (Godot 4.3 Multiplayer API)
- [ ] Relay service kiezen
  - [ ] TODO(design): GD-Sync / NodeTunnel / eigen VPS / TBD
- [ ] Aparte PvP-scene (los van singleplayer)
- [ ] Turn-based combat synchroniseren
- [ ] Verbindingsverlies afhandelen
  - [ ] Disconnect → terug naar menu
  - [ ] Reconnect-optie (indien mogelijk)
- [ ] Connect-code generator (uniek, kort, makkelijk te delen)

### SCHEIDING VAN SINGLEPLAYER

- [ ] Eigen UI/menu los van singleplayer
- [ ] Eigen regels en balans
- [ ] Eigen stat-berekening per game mode
- [ ] Geen lore-items, geen kernkrachten, geen Hanger
- [ ] Geen save file impact

### ROADMAP (gefaseerd)

- [ ] Fase 1: Local PvP POC (LAN, 1v1, 1 team, 1 mode)
- [ ] Fase 2: Online lobby + connect-code
- [ ] Fase 3: Host-mode-select + team-select schermen
- [ ] Fase 4: 3 teams + 3 modes volledig
- [ ] Fase 5: Polish (UI, disconnect, reconnect)

### NIET IN SCOPE (voor nu)

- [ ] Geen ranked, geen MMR, geen matchmaking
- [ ] Geen seizoenen, geen ranks
- [ ] Geen 2v2 (later eventueel)
- [ ] Geen anti-cheat (vrienden onder elkaar)
- [ ] Geen leaderboards
