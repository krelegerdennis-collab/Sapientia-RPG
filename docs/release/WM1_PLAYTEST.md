# WM1 playtest: speelscript voor Dennis

Doel: één keer van het begin tot het einde van Worldmap 1 (WM1) spelen en per gebied kijken of het klopt.
Alleen WM1: Wachtershuis-erf, Wilgendal, wereldkaart, Archief 1, Esdoorn, Donker Woud, berggrot, Archief 2 (Het Levende
Archief), de World Warper-hub met ECHO en (optioneel) de Diepe Grot. WM2 en WM3 staan on hold en horen hier niet bij.

Spelteksten zijn Engels, dit document is Nederlands. De route en vlaggen komen uit de code (`scripts/data/story_data.gd`,
`data/quests.json`, `scripts/data/dungeon_rooms.gd`, `woud_rooms.gd`, `berggrot_data.gd`, `archief2.gd`); waar de code
niets zegt staat "onduidelijk".

## 1. Voorbereiding

| Wat | Hoe |
|---|---|
| Build | een **debug-build** (APK met debug-export, of de editor). De sessielog bestaat alleen in debug-builds; een release-APK schrijft niets. |
| Versie noteren | `project.godot` `config/version` of de titel; staat ook in de log (`sessie_start`). |
| Nieuw spel | titelscherm > **New Game**. Niet "Beta Test" of "End State": die slaan verhaal over en tellen niet als WM1-run. |
| Telefoon | touch-besturing, liggend. Test op de telefoon waarop de game echt gespeeld wordt. |
| Log aan | **Settings > Session Log** staat op `Auto` (= aan in debug). Laat zo staan. |
| Saves | gebruik gerust meerdere slots: sla op bij elk lezenswaardig punt (gloeiende boeken). |
| Pc (optioneel) | F2 = gevecht forceren, F3 = baasgevecht, F4 = puzzelkamer. Alleen debug-build, alleen op kaarten met monsters. |

Tijdens het spelen: noteer bij elk probleem de **kaartnaam of plek**, wat je deed en wat je verwachtte. De log vult de
rest aan (kaart, tijd, gevechten, doden).

### Wat de log vastlegt (alleen debug-builds)

Eén bestand per sessie: `user://logs/sessie_<datum>_<tijd>.jsonl` (JSON Lines, max 2 MB, de laatste 5 sessies blijven).
Geen spelernaam, geen apparaat-id, geen locatie.

- **Kaarten:** `kaart` (met `gebied_wm1`), `kaart_tijd` (seconden op die kaart), `warp`, `pos` (elke ~0,5 s bij beweging).
- **Gevechten:** `gevecht_start`, `ronde`, `gevecht_eind` (uitkomst, duur, HP-verlies, gebruikte acties).
- **Doden:** `dood` (kaart, gebied, reden), `game_over`, `respawn`.
- **Tijd per gebied:** `kaart_tijd` + de totalen in de laatste regel `sessie_stop` (veld `samenvatting`).
- **Crashes:** begint een sessie terwijl de vorige geen `sessie_stop` had (crash, kill of app weggeveegd), dan staat er
  direct na `sessie_start` een regel `crash_vorige` met bestand, laatste kaart en laatste regel. Vastlopers van 3 s of
  langer staan als `gat`. Let op: Godot 4.3 geeft geen hook voor script-fouten; die staan alleen in logcat/de editor.
- **Rest:** quest-voortgang (`quest_update`), save/load (alleen bestandsnaam), menu's, stilstand (>= 20 s zonder invoer).

### Log ophalen en samenvatten

1. Op de telefoon: **Settings > Export Log**. Het bestand komt in Downloads of Documenten (`sapientia_sessielog_<id>.jsonl`,
   de laatste 3 sessies). Lukt dat niet, dan wordt het laatste deel naar het klembord gekopieerd.
2. Op de pc, in de repo:

```bash
python3 tools/sessielog/playtest_rapport.py sapientia_sessielog_<id>.jsonl        # tekst
python3 tools/sessielog/playtest_rapport.py <map met sessie_*.jsonl> --json       # machineleesbaar
python3 tools/sessielog/playtest_rapport.py <bestand> --strict                    # exit 3 bij crash, dood of vastloper
python3 tools/sessielog/samenvat.py <bestand>                                     # het oudere, algemene overzicht
```

Het rapport toont per sessie: speeltijd per gebied en kaart, gevechten per gebied, baasgevechten, zwaarste gevechten,
doden en game-overs, crashes en vastlopers, quest-voortgang. Een geëxporteerd bestand bevat soms meerdere sessies:
het rapport behandelt ze apart en geeft onderaan een totaal.

## 2. Route in één oogopslag

| # | Gebied | Kaarten | Uitkomst / poort |
|---|---|---|---|
| 1 | Wachtershuis-erf | `huis_wilgendal`, `wilgendal` | proloog; Opa; Equipment; put en kist; eerste gevecht (Moss Slime); aardbeving |
| 2 | Wereldkaart + Archief 1-ingang | `wereldkaart`, `archief_ingang` | pad naar de wereld open na de nacht (`NACHT`) |
| 3 | Archief 1 (De Vergeten Archieven) | `archief_*` | puzzelkamer, Vonkzwaard, baas **Golem** (Kustos), Inktwurm in de Codex |
| 4 | Esdoorn | `esdoorn*` | opent na de Golem; Vesper wordt ontvoerd (`quest_noor`) |
| 5 | Donker Woud | `woud_*` | baas **Root King**; Vesper sluit aan (`noor_lid`) |
| 6 | Wilgendal (dorp) | `dorp_wilgendal`, `wilgendal_binnen` | vijf winkels; molenaar Garrett (zijquest) |
| 7 | Berggrot | `berggrot_*` | puzzels, geen baas; leidt naar de kas |
| 8 | Archief 2 (Het Levende Archief) | `leven_*`, `archief_2_*` | Seren (Lotte) sluit aan; bazen **Strangler** en **Mender** |
| 9 | World Warper-hub + ECHO | `exterieur`, `hal`, `rustkamer`, `echo_kamer`, ... | hub open na de Mender; warp-menu |
| 10 | Diepe Grot (optioneel) | `dungeon100` | alleen via ECHO |

Het einde van WM1 in de code: de **Mender** verslaan, de World Warper-scène en de hub (vlag `world_warper_unlocked`,
quest "Reach the World Warper"). Er is geen aparte "WM1 klaar"-vlag. Of de Diepe Grot erbij hoort is onduidelijk;
speel hem alleen aan het eind kort aan.

## 3. Het script

Vink af wat klopt. Bij twijfel: noteer het bij **Gevonden** onderaan.

### Stap 1. Wachtershuis-erf (proloog)

Start: New Game. Je begint in het huis (`huis_wilgendal`, bed) als Dax, level 1, 3 Potion en 1 Magic Water, 0 gold.

1. Praat met Opa; kies in de keuze één van de twee toontjes (groet of archief).
2. Opa geeft de mantel. Open **Menu > Equipment** en trek de mantel aan.
3. Haal water bij de put en open de kist (3 herbs).
4. Praat met Opa voor de les: je krijgt een Short Sword en vecht tegen een Moss Slime.
5. 's Avonds: aardbeving, Opa verdwijnt, de huisdeur gaat op slot. Kies "Follow Grandpa" en loop naar het archief.

Controleer:
- [ ] De volgorde dwingt zichzelf af: zonder mantel aan, water en kist komt de les niet.
- [ ] Het eerste gevecht is begrijpelijk (Action-stijl is de standaard van New Game); de uitleg staat in beeld.
- [ ] Veldmenu (Esc/M/Tab of MENU-knop): Equipment, Items, Settings, Quest Log werken; het mantel-evenement vuurt maar één keer.
- [ ] Voor de nacht: het pad naar de wereldkaart blokkeert met een duidelijke melding (geen vastzitten zonder hint).
- [ ] Opslaan bij het boek op het erf, afsluiten, **Continue**: zelfde plek, zelfde story-stand.
- [ ] Geen tekst in het Nederlands, geen afgekapte regels in het dialoogvenster.

### Stap 2. Wereldkaart

1. Loop het archief in en weer uit; loop over de wereldkaart (gras, hoog gras, zand, bos).
2. Laat een paar random gevechten gebeuren (na een gevecht 6 veilige stappen).

Controleer:
- [ ] De eerste keer op de wereldkaart start de korte cutscene één keer.
- [ ] Gevechtsfrequentie voelt redelijk (gras 6%, hoog gras 7%, zand 6%, bos 10% per stap).
- [ ] Vluchten werkt; winst geeft XP en buit; game-over zet je terug op een logische plek.
- [ ] Kaartrand, overgangen en de ingangen (Archief, dorp, woud, grot, kas) laden zonder zwart scherm of vastlopen.
- [ ] Touch: joystick links, A/B rechts, geen dode zones; de MENU-knop werkt.
- [ ] Framerate blijft soepel bij het scrollen (let op haperingen: de log markeert `gat` >= 3 s).

### Stap 3. Archief 1 en de Golem

Route (`dungeon_rooms.gd`): ingang (save) > gang > kastenzaal / leeszaal / trapzaal > zuilenhal > **puzzelkamer** (Vonkzwaard in
de kist achter de geheime deur) > gang > wachtersgang > voorhal > bibliotheek (save) > **golemhal** (baas).

Controleer:
- [ ] Alle kamers zijn te halen zonder vast te zitten; deuren en schakelaars geven duidelijk aan wat ze doen.
- [ ] Puzzelkamer: kasten, platen en geheime deur werken; na verlaten en terugkomen staat de puzzel in een logische stand
      (puzzelstand midden in een puzzel zit niet in de save: bekend).
- [ ] Er staan twee save-boeken (ingang, bibliotheek); opslaan en laden werkt in beide.
- [ ] Golem: het gevecht is te winnen, kost merkbaar HP, en de uitkomst staat in het rapport (Baasgevechten).
- [ ] Na de Golem: je krijgt de golemkern (kernslag in gevecht, kernvuur en zware blokken op de kaart).
- [ ] De uitgang van de golemhal blijft dicht tot de **Inktwurm** in de Codex staat. De Inktwurm komt uit de kast in de golemhal;
      de twee tutorials (vangen, Codex) verschijnen en zijn te volgen met een Blank Book.
- [ ] Menu > **Codex** en **Bestiary** tonen de Inktwurm en de vijanden die je tot nu toe zag.

### Stap 4. Esdoorn

Opent zodra de Golem verslagen is (wereldkaart-uitgang naar Esdoorn).

1. Bij binnenkomst: scène waarin Vesper (Noor) wordt ontvoerd; Marit geeft 3 Blank Books.
2. Loop het dorp, de herberg (gratis rust) en het huis van Noor in; praat met alle NPC's.

Controleer:
- [ ] De ontvoeringsscène speelt één keer en zet de quest "Save Vesper from the Dark Wood" in het Quest Log.
- [ ] Herberg: gratis genezen, en de tekst wijst naar het opslagboek.
- [ ] NPC's zeggen iets zinnigs (placeholder-teksten zijn bekend, zie punt 4), geen kapotte tekens of Nederlands.
- [ ] Geen kaart met ontbrekende of verkeerd uitgelijnde tegels (Esdoorn is al 1,4x geschaald).

### Stap 5. Donker Woud en de Root King

Route (`woud_rooms.gd`): woud_rand > woud_pad > woud_mistpoel > woud_sporenkring (save) > woud_open_plek (baas).

Controleer:
- [ ] Het woud-gebied heeft eigen vijanden (o.a. Wood Wraith) en eigen sfeer; geen random-gevechten op fout terrein.
- [ ] Kisten bevatten o.a. Blank Books; opslaan bij de sporenkring werkt.
- [ ] **Root King**: gevecht te winnen; geen kernmechaniek voor de Root King (bekend, niet in WM1 gebouwd).
- [ ] Na de baas: Vesper sluit aan (level = jouw level min 1, staf en reisgewaad), Quest Log toont "Save Vesper" als klaar.
- [ ] Zijquest "The Singing Grain": start bij Garrett de molenaar (heeft Vesper in de groep nodig), zaad-gevecht met Woudgeest
      op de open plek, molen geeft genezing en optioneel opslaan en party wisselen.
- [ ] Menu > **Party**: wisselen tussen actief en bank werkt; max 4 helden en 1 monster in gevecht.

### Stap 6. Wilgendal (dorp) en winkels

Controleer:
- [ ] Vijf winkels: wapens, pantsers, accessoires, magie en kruiden (huis van Tante Minna). Kopen, verkopen en equip werken en
      prijzen zijn verdedigbaar met je gold.
- [ ] Binnenkamers (`wilgendal_binnen`) laden en je komt op de goede plek terug.
- [ ] Er is in WM1 geen herberg in Wilgendal zelf (rust bij Esdoorn). Verwachting klopt met wat je ziet?
- [ ] Sfeer-NPC's lopen rond zonder vast te lopen op muren of elkaar.

### Stap 7. Berggrot

Entree via de grotmond op de wereldkaart (`berggrot_mond`, save). Keten: mond > grendel (puzzel) > nerf > geheim (puzzel) > uitmond >
Archief 2-entree. De bouwplaats-tunnel blijft dicht tot Vesper in de groep zit.

Controleer:
- [ ] Beide puzzels zijn op te lossen en geven feedback; niets blokkeert permanent.
- [ ] Geen baas hier (klopt met de code); gevechten zijn te doen met je huidige level.
- [ ] Bouwplaats-NPC's en de tunnelpoort zeggen waarom hij dicht is, en gaan open als Vesper erbij is.
- [ ] De uitmond brengt je bij de kas (Archief 2-entree) en terug lukt ook.

### Stap 8. Archief 2: Het Levende Archief

Poort: Golem verslagen (wereldkaart-uitgang naar de kas, `leven_ingang`, save). De eerste keer speelt een korte intro.

| Deel | Kamers | Let op |
|---|---|---|
| Kas v1 | `leven_ingang` > `leven_v1_plaat` > `archief_2_v1_entree` > `archief_2_v1_plaat` | groeiplaat-puzzel |
| v2 | `archief_2_v2_gang` > `archief_2_v2_lotte` | gevecht met Lotte (Seren) in glitch; ze sluit na afloop aan |
| v3 | `archief_2_v3_ketting` > `leven_v3_combi` > `archief_2_v3_tegen` / `licht` > `archief_2_v3_wurger` | ketting- en combipuzzel; baas **Strangler** |
| v4 | `archief_2_v4_hal` > `archief_2_v4_genezer` | baas **Mender** |

Controleer:
- [ ] Vijanden (Natuur-element: Tendril, Sporehead, Thorn Runner, Blooming Dread, Rootghost) hebben herkenbaar gedrag
      (binden, gif, charge, zelfheling, trekken) en zijn vangbaar waar de Codex dat belooft.
- [ ] Seren sluit aan na de Lotte-scène, ook als je dat gevecht verliest; ze staat dan in Party en Quest Log ("Seren joins the party").
- [ ] Strangler en Mender zijn te winnen; duur en HP-verlies staan in het rapport onder Baasgevechten.
- [ ] Muziek: kas-track en baas-track spelen (`bgm_levend_archief`, `bgm_baas_archief2`).
- [ ] Na de Mender begint de World Warper-scène zonder hapering; de hub opent.

### Stap 9. World Warper-hub en ECHO

Controleer:
- [ ] De scène na de Mender (kern opgenomen, hub-exterieur) speelt door tot de hub en laat je weer bewegen.
- [ ] Menu > **Warp** werkt nu (daarvoor: "The warp hub cannot be reached yet."); WM2 en WM3 blijven dicht (bedoeld).
- [ ] Hal, Rest Room en ECHO's Chamber openen. Training Hall, Workshop, Exchange, Core en twee nissen (Codex, Sapientia) blijven
      dicht in WM1 (release-besluit): de deur zegt dat hij dicht is en je loopt niet vast.
- [ ] Rest Room: party wisselen werkt (max 4 helden en 1 monster in gevecht).
- [ ] ECHO's zinnen zijn nog door de agent geschreven (definitieve tekst volgt van Dennis): leest het logisch?
- [ ] Quest Log: alle hoofdquests staan op klaar tot en met "Reach the World Warper".

### Stap 10. Diepe Grot (optioneel, kort)

Alleen via ECHO. Speel een paar verdiepingen.

Controleer:
- [ ] Ingang via ECHO werkt; de grot is niet bereikbaar vanaf de wereldkaart.
- [ ] Verdieping-HUD (X/100), rustpunt, Blue Chests en game-over ("dood is dungeon uit") gedragen zich zoals beschreven.
- [ ] Na vertrek of dood kom je weer op een logische plek uit (hub of eerder punt); noteer waar.

## 4. Dwarsdoorsnede-checks (doe ze onderweg)

- [ ] **Save/load:** opslaan in minstens 3 verschillende gebieden, afsluiten, **Continue** en **Load**: plek, party, items en quests kloppen.
      Een bewust kapot gemaakt bestand geeft een melding en valt terug op het back-upbestand, geen crash.
- [ ] **Autosave:** gebeurt bij het wisselen tussen wereldkaart en kerker.
- [ ] **Gevechten:** Action en Classic (Settings > Battle Style) werken allebei; Run, Items, Magic, kernkrachten, Blank Book vangen.
- [ ] **Menu's:** Equipment, Codex, Items, Magic, Bestiary, Warp, Party, Quest Log, Scenes & Music, Settings, Load.
- [ ] **Settings:** volume, tekstsnelheid, touch-grootte en -dekking, CRT, screen shake; instellingen blijven na herstart.
- [ ] **App-pauze:** app naar de achtergrond (home-knop) en terug midden in een gevecht en op de kaart: geen crash, geen dubbele input.
- [ ] **Geluid:** veel BGM/SFX zijn placeholders of ontbreken (bekend); meld alleen als de game daardoor hapert.
- [ ] **Tekst:** alles Engels; namen kloppen (Dax, Seren, Vesper, Kael en Orion zitten niet in de WM1-route).
- [ ] **Batterij en warmte:** noteer het percentage vóór en na de sessie.

## 5. Bekend, niet melden

Uit `docs/BACKLOG_WM1.md`, `docs/qa/SAVE_HARDENING.md` en de handoffs:

- Balans is te makkelijk in WM1 en de Diepe Grot (wereldkaart-gevechten bijna altijd winst). Meld wel als het te *moeilijk* of een baas oneerlijk is.
- Veel kaarten (Archief 1, berggrot, puzzelkamers) zijn nog niet 1,4x geschaald; dat is een bekend punt.
- Veel BGM- en alle SFX-bestanden zijn placeholder of ontbreken; World Warper-geluiden zijn grotendeels stil.
- Een deel van de NPC-teksten in Esdoorn en ECHO's zinnen is voorlopig (`TODO_STORY`).
- De Root King heeft geen kernmechaniek; stun-betekenis op de wereldkaart is nog niet besloten.
- Puzzelstand midden in een puzzel zit niet in de save.
- PvP en Co-op horen niet bij WM1 (knoppen verborgen zonder relay).

## 6. Afronden

1. **Settings > Export Log**, haal het bestand op en draai `playtest_rapport.py` (zie sectie 1).
2. Controleer in het rapport: elk gebied heeft speeltijd, de bazen (Golem, Root King, Lotte/Seren, Strangler, Mender) staan als
   gevecht, en bij **Crashes en vastlopers** staat "geen". Zo niet: noteer bij welk gebied en welke tijd.
3. Vul **Gevonden** hieronder in (of maak per punt een issue met label `bug`).

### Eindchecklist WM1

- [ ] Proloog van begin tot nacht zonder vastlopen
- [ ] Archief 1 doorgespeeld, Golem verslagen, Inktwurm in de Codex
- [ ] Esdoorn bezocht, Vesper-quest gestart
- [ ] Donker Woud doorgespeeld, Root King verslagen, Vesper in de groep
- [ ] Wilgendal-winkels getest
- [ ] Berggrot doorgespeeld
- [ ] Archief 2 doorgespeeld, Seren in de groep, Strangler en Mender verslagen
- [ ] World Warper-hub bereikt, Warp-menu werkt
- [ ] Opslaan en laden in minstens 3 gebieden
- [ ] Geen crash in de log (`Crashes en vastlopers: geen`)
- [ ] Log geëxporteerd en samengevat

### Gevonden

| Gebied / kaart | Tijd of stap | Wat gebeurde er | Wat had je verwacht | Ernst (blokkeert / hinderlijk / klein) |
|---|---|---|---|---|
| | | | | |
