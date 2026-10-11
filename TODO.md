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
