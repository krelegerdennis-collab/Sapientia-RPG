# TODO — toekomstige updates

Afvinken alleen als het echt af is. Open punten zijn nog ontwerp of nog niet gebouwd.

## Save System

- [x] Meerdere laadstanden op het hoofdmenu
  Bij "Continue" zijn meerdere save slots zichtbaar, niet alleen de laatste save.

- [x] Vier aparte save slots
  Het save-systeem ondersteunt 4 losse slots. Slot 1 blijft het oude save-bestand (oude saves zonder sleutel "slot" laden als slot 1).

- [x] Load-knop op het hoofdmenu
  Een eigen Load-knop, naast "Continue". Beide openen de slotlijst.

## Wereld & Levels

- [x] Eerste Archief herschalen
  Moeilijkheidsgraad en level van het eerste Archief van 10 naar 7.
  De archiefgevechten gebruiken `apply_archief_tier` (doel-level 7). De Golem-baas is apart bijgesteld zodat level 7 een echt gevecht blijft.

- [x] Blauwe kist-items in de Diepe Grot schalen, plus een rarity-systeem
  De beloningen uit blauwe kisten in de grot van 100 verdiepingen schalen mee met de diepte. Sommige items droppen alleen uit een blauwe kist vanaf een vaste verdieping (floor-gated loot, niet puur willekeurig).

  Affixes zijn vast per item: geen random rolls. Elk Grade 3- en Grade 4-item heeft vooraf bepaalde affixes die bij dat item horen. Grade 1 en 2 krijgen geen affixes.

  - Grade 1 (early game): verdieping 1–20
  - Grade 2 (midgame): verdieping 20–50
  - Grade 3 (endgame): verdieping 50–80
  - Grade 4 (endgame++): verdieping 80–99
  - Grensverdieping hoort bij de hogere grade (bevestigd): 20 = Grade 2, 50 = Grade 3, 80 = Grade 4.

  - [x] Grade 3 items: vast affix-systeem (basis affixes, per item voorgedefinieerd)
  - [x] Grade 4 items: uitgebreid vast affix-systeem (sterkere en meerdere affixes per item)
  - [x] Grade 1 en 2 items: geen affixes, blijven puur stat-gebaseerd
  - [x] Eén uniek super wapen per karakter (alleen Grade 4, drop vanaf verdieping 80)
    - [x] Dennis: super zwaard (fysiek)
    - [x] Noor: super staf (natuur/magisch; zij is een mage)
    - [x] Lotte: super staf (licht/magisch; priester)
    - [ ] Aan te vullen zodra nieuwe karakters of classes in het verhaal komen
  - [x] Grade 4 armour sets, class-gebonden (4 stukken per set: helm, borst, benen, laarzen; alleen de eigen set, geen mix)
    - [x] Plated Armour set — Dennis (zwaar/defensief, vaste affixes per stuk)
    - [x] Robes set — Lotte (licht/magisch, vaste affixes per stuk)
    - [x] Natuur/Robes set — Noor (natuur/magisch, vaste affixes per stuk)
    - [ ] Aan te vullen voor toekomstige karakters
  - [x] Grade 4 accessoires (niet class-gebonden)
    - [x] Accessoires toevoegen aan de Grade 4 loot table
    - [x] Voor elk karakter bruikbaar, zonder class-restrictie
    - [x] Vaste affixes per accessoire

  Bevestigd: de statcijfers van grade-wapens, sets, accessoires en affixen in `scripts/data/grade_gear.gd`. Toekomstige helden hebben nog geen eigen G4-wapen of set.

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
  De bestaande eindbazen van de Diepe Grot (verdieping 10 tot en met 100) hebben een entry en stats uit de bestaande monsterdata.
  Lore-tekst nog van Dennis: de regels zijn nu kort en feitelijk, geen canon-lore.

## Dorpen & Shops

### Eerste dorp: Wilgendal

- [x] Wilgendal activeren als eerste dorp
  Bereikbaar vanaf de wereldkaart (`scenes/maps/dorp_wilgendal.tscn`). Het oude `wilgendal.tscn` blijft het huis van de Wachter.
  NPC's alleen uit de bestaande canon: Tante Mien (kruiden), Jelle Hamer (smederij), Gerrit Molenaar (alleen "Goedendag.").
  Gerrits quest is niet gebouwd.

### Shops in Wilgendal

- [x] Armour shop
- [x] Wapen shop
- [x] Accessoire shop
- [x] Magic shop

Jelle Hamer heeft zowel de wapen- als de pantserstal (bevestigd, één smid). Accessoire en magie zijn balies zonder nieuwe persoon.

### Magic tier list

Magie heeft 4 grades. Grade 1 tot en met 3 zijn te koop in de magic shop en worden per act vrijgespeeld. Grade 4 is niet te koop: die dropt alleen uit blauwe kisten in de Diepe Grot (verdieping 80+). Per tier 4 spreuken. Niet alles is in Act 1 beschikbaar.

- [ ] Magic tier list opzetten (4 grades × 4 spreuken = 16 spreuken per element)
  De volledige 4×16-lijst is nog ontwerp. De kleine lijst van 20 spreuken (één per grade per element: vuur, natuur, bliksem, licht, ijs) is bevestigd en geldt tot nader order. Fire, Lightning en Heal blijven zo heten.
- [x] Grade 1 tot en met 3 in de magic shop (prijs 160×grade²)
  Grade 1 = 160, grade 2 = 640, grade 3 = 1440. Bevestigd. Grade 4 blijft uit de winkel.
- [x] Grade 4 alleen als drop uit blauwe kisten (Diepe Grot, verdieping 80–99)
- [x] Tiers vrijspelen per act (Act 1 = alleen Grade 1)
- [ ] Per spreuk eigen data: damage, healing en effect schalen per grade
  Geldt voor de volledige 16 per element, die er nog niet is. De kleine lijst van 20 heeft bevestigde mp en power per grade.

### Elements en karakters

- [x] Dennis: geen magie
  Dennis krijgt alleen kernkrachten. Dat zijn geen shop-items. Een rol of de winkel leert hem niets.
- [x] Noor (mage): Vuur, Natuur en Bliksem
  - [ ] Extra elementen per latere act bepalen
  - [x] Ook Grade 1 Licht (healen), beperkt tot niveau 1
  - [x] Grade 2 en hoger Licht niet voor Noor
- [x] Lotte (priester): Licht als healing en buffs (hoofdrol)
  - [x] IJs als aanvalsmagie (voorlopig het enige aanvals-element)
  - [x] Geen Vuur, Natuur of Bliksem

### Beschikbaarheid shops

- [x] Niet alle items direct beschikbaar in Wilgendal; selectie per act
  Act 1 toont alleen de laagste schappen. IJzeren helm, maliënkolder en groenring pas vanaf act 2. Bevestigd.
- [x] Winkel-act volgt het hoogste party-level
  Act 1 = level 1–13. Geen aparte verhaalvlag. Bevestigd.
- [x] Magic grades per act vrijspelen (Act 1 = Grade 1, enzovoort)
  Nooit hoger dan Grade 3 in de winkel.

### Algemeen

- [x] Verkoop-systeem in shops
  Verkoop is de helft van de genoteerde prijs. Een grade-1-spreuk verkoopt dus voor 80. Bevestigd.

### Nog te bevestigen

- Volledige 4×16-spreukenlijst. De kleine lijst van 20 is bevestigd en geldt tot nader order.
- Toekomstige helden (eigen G4-wapen en set).
- Gerrits quest.
- Echte lore van de eindbazen in het bestiarium.
- Extra elementen voor Noor in latere acts.
- Wereldkaart, warps en de act-koppeling aan de eilanden.

Bevestigd en dus geen open ontwerp meer: winkelprijzen en voorraad, magieprijs 160×grade², verkoop op de helft, grade-statcijfers en grenzen, winkel-act via party-level, archiefschaal 0,7 / EXP 0,50, Golem HP 360 / ATK 27 / DEF 15, Jelle als één smid met twee balies, kort zwaard ATK +3.

Techniek: de headless testsuites draaien via `.github/workflows/tests.yml` (Godot 4.3-stable). De web-export naar Pages (`cursor/web-build-29ec`) blijft handmatig: Godot 4.7.2, threads uit. Er is geen script en geen bot-token die die branch vanuit Actions pusht.
