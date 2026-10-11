# TODO — toekomstige updates

Lijst met ideeën voor later. Nog niets hiervan is gebouwd; afvinken als het af is.

## Save System

- [ ] Meerdere laadstanden op het hoofdmenu
  Bij "Continue" zijn meerdere save slots zichtbaar, niet alleen de laatste save.

- [ ] Vier aparte save slots
  Het save-systeem ondersteunt 4 losse slots.

- [ ] Load-knop op het hoofdmenu
  Een eigen Load-knop, los van "Continue".

## Wereld & Levels

- [ ] Eerste Archief herschalen
  Moeilijkheidsgraad en level van het eerste Archief van 10 naar 7.

- [ ] Blauwe kist-items in de Diepe Grot schalen, plus een rarity-systeem
  De beloningen uit blauwe kisten in de grot van 100 verdiepingen schalen mee met de diepte. Sommige items droppen alleen uit een blauwe kist vanaf een vaste verdieping (floor-gated loot, niet puur willekeurig).

  Affixes zijn vast per item: geen random rolls. Elk Grade 3- en Grade 4-item heeft vooraf bepaalde affixes die bij dat item horen. Grade 1 en 2 krijgen geen affixes.

  - Grade 1 (early game): verdieping 1–20
  - Grade 2 (midgame): verdieping 20–50
  - Grade 3 (endgame): verdieping 50–80
  - Grade 4 (endgame++): verdieping 80–99

  - [ ] Grade 3 items: vast affix-systeem (basis affixes, per item voorgedefinieerd)
  - [ ] Grade 4 items: uitgebreid vast affix-systeem (sterkere en meerdere affixes per item)
  - [ ] Grade 1 en 2 items: geen affixes, blijven puur stat-gebaseerd
  - [ ] Eén uniek super wapen per karakter (alleen Grade 4, drop vanaf verdieping 80)
    - [ ] Dennis: super zwaard (fysiek)
    - [ ] Noor: super staf (natuur/magisch; zij is een mage)
    - [ ] Lotte: super staf (licht/magisch; priester)
    - [ ] Aan te vullen zodra nieuwe karakters of classes in het verhaal komen
  - [ ] Grade 4 armour sets, class-gebonden (4 stukken per set: helm, borst, benen, laarzen; alleen de eigen set, geen mix)
    - [ ] Plated Armour set — Dennis (zwaar/defensief, vaste affixes per stuk)
    - [ ] Robes set — Lotte (licht/magisch, vaste affixes per stuk)
    - [ ] Natuur/Robes set — Noor (natuur/magisch, vaste affixes per stuk)
    - [ ] Aan te vullen voor toekomstige karakters
  - [ ] Grade 4 accessoires (niet class-gebonden)
    - [ ] Accessoires toevoegen aan de Grade 4 loot table
    - [ ] Voor elk karakter bruikbaar, zonder class-restrictie
    - [ ] Vaste affixes per accessoire

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
  Alle monsters tot en met de eindgame opnemen, met een entry, stats en lore-tekst per monster.

## Dorpen & Shops

### Eerste dorp: Wilgendal

- [ ] Wilgendal activeren als eerste dorp
  Huidige status: nog niet actief, alleen een placeholder.

### Shops in Wilgendal

- [ ] Armour shop
- [ ] Wapen shop
- [ ] Accessoire shop
- [ ] Magic shop

### Magic tier list

Magie heeft 4 grades. Grade 1 tot en met 3 zijn te koop in de magic shop en worden per act vrijgespeeld. Grade 4 is niet te koop: die dropt alleen uit blauwe kisten in de Diepe Grot (verdieping 80+). Per tier 4 spreuken. Niet alles is in Act 1 beschikbaar.

- [ ] Magic tier list opzetten (4 grades × 4 spreuken = 16 spreuken per element)
- [ ] Grade 1 tot en met 3 in de magic shop (prijs loopt op per grade)
- [ ] Grade 4 alleen als drop uit blauwe kisten (Diepe Grot, verdieping 80–99)
- [ ] Tiers vrijspelen per act (Act 1 = alleen Grade 1)
- [ ] Per spreuk eigen data: damage, healing en effect schalen per grade

### Elements en karakters

- [ ] Dennis: geen magie
  Dennis krijgt alleen kernkrachten. Dat zijn geen shop-items.
- [ ] Noor (mage): Vuur, Natuur en Bliksem
  - [ ] Extra elementen per latere act bepalen
  - [ ] Ook Grade 1 Licht (healen), beperkt tot niveau 1
  - [ ] Grade 2 en hoger Licht niet voor Noor
- [ ] Lotte (priester): Licht als healing en buffs (hoofdrol)
  - [ ] IJs als aanvalsmagie (voorlopig het enige aanvals-element)
  - [ ] Geen Vuur, Natuur of Bliksem

### Beschikbaarheid shops

- [ ] Niet alle items direct beschikbaar in Wilgendal; selectie per act
- [ ] Shop-voorraad laten meeschalen met verhaalprogressie
- [ ] Magic grades per act vrijspelen (Act 1 = Grade 1, enzovoort)

### Algemeen

- [ ] Verkoop-systeem in shops
  Sluit aan op de eerdere TODO: items verkoopbaar.
