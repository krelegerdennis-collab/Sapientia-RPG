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
