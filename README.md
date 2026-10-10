# Lufia Prototype – top-down JRPG voor mobiel (Godot 4)

Een klein, werkend startproject in de stijl van **Lufia 2 (SNES)**:
een speler die tile-voor-tile loopt, een **dorp** en een **wereldkaart** met overgangen ertussen,
botsingen met bomen/water/bergen, een camera die meeloopt, een tekstvak, een NPC, een bordje,
touch-knoppen voor je telefoon én **turn-based gevechten** met random encounters, een party van
3 helden, spreuken, items en level-ups.

Getest met **Godot 4.3** en **Godot 4.7.2** (standaardversie, *niet* de .NET/C#-versie).

**Nieuw in v0.19 (versie 0.19, code 21): kamer-checkpoint - na GAME OVER ontwaak je waar je de kamer/map binnenkwam.**
- Wens Dennis: 'Ik ging dood bij de baas, spawnpoint moet altijd voor de laatste room zijn.' Tot v0.18 ging je na
  ELKE game over terug naar Wilgendal (spawn `start`, (16,8)), volledig genezen maar met de **helft van je goud kwijt**,
  wat je ook in de dungeon had gedaan.
- Nu: bij elke binnenkomst van een map/kamer (uitgang/mapwissel, laden; niet terug uit een gevecht) legt `map.gd`
  het **kamer-checkpoint** vast (`GameState.checkpoint`): map + tile + kijkrichting waar je binnenkwam + een kopie
  van de voortgang (zelfde velden als een save, `GameState.state_data`). GAME OVER (overal: dungeonkamer, dorp,
  **wereldkaart**, baas) = terug op dat punt met die voortgang (party/EXP/spullen/goud/verhaal/kernen/Codex),
  iedereen vol HP/MP; bestiarium en speeltijd lopen door. Monsters in de kamer staan er weer. Daarna autosave
  (reden `respawn`) en een vertellerregel.
- **Baaskamers zetten geen checkpoint** (data: `"checkpoint": false` in `archief_golemhal` en `woud_open_plek`;
  zonder die sleutel automatisch voor elke kamer met een `"boss"`-monster), dus wie bij de Golem of De Wortelkoning
  sneuvelt, ontwaakt in de **Bibliotheek** / **Sporenkring** bij de ingang, kijkend naar de baasdeur:
  'Je ontwaakt voor de deur...' (anders 'Je ontwaakt waar je binnenkwam...'; `TODO(verhaal)`). Baas blijft staan.
- Gaat mee in de save (`"checkpoint"`). Laden in dezelfde kamer houdt het checkpoint van binnenkomst; een oude
  save zonder checkpoint zet het op de plek waar je laadt. Zonder checkpoint (alleen direct na een nieuw spel):
  de oude regel (Wilgendal, helft goud).
- Nieuwe test `--checkpointtest` (`scripts/tests/checkpoint_tests.gd`): gewone kamer, wereldkaart, Golem met
  opslaan/laden ertussen, Wortelkoning, oude/kapotte save, verslagen baas. `--autotest`: game over nu terug op de
  wereldkaart (14,31) zonder goudverlies; versielabel v0.19. Arm64-preset: `../rpg_prototype_v0.19_arm64.apk`.

**Nieuw in v0.18 (versie 0.18, code 20): rugaanzichten Moskonijn + Mech. Wachter, Codex-namen, audio-basis, design/lore + CANON.**
- Rug-sprites van RPG ART (`/workspace/art_rug_v18/out`): `res://art/enemies/moskonijn_rug.png` (106x110, voeten
  53,104) en `res://assets/sprites/enemies/mech_wachter_rug.png` (88x112, voeten 44,106); zelfde canvas, voetanker
  (b/2, h-6) en grondschaduw (alpha 90) als de voorkant. `sprite_back` staat nu in `GameData.ENEMIES` voor beide, dus
  een Codex-bondgenoot Moskonijn/Mech. Wachter gebruikt de echte rug i.p.v. de gespiegelde, donkere plaatsvervanger.
  Alle Codex-soorten hebben nu een eigen rug (de plaatsvervanger in `codex_ally.gd` blijft als terugval). Beide in
  `tools/handwerk.txt`.
- Codex-scherm (patch RPG CODE, `code_codexnaam`): lijst 12 px breder (`LIST_W` 132), namen tot 13 tekens volledig
  ('Wortelkruiper'), langer = 12 tekens + '.'.
- `--codextest`: checks voor beide ruggen (pad, 106x110 / 88x112, anker, niet gespiegeld) + screenshots
  `codex_bondgenoot_moskonijn` / `codex_bondgenoot_mech_wachter`. Versielabel v0.18.
- **Audio (basis, nog zonder geluid):** autoload `AudioManager` (`scripts/audio_manager.gd`, uit Sapientia-Audio,
  direct NA `Settings`; volume blijft van Settings: `music_volume`/`sfx_volume`). Manifest
  `assets/audio/audio_manifest.json`, bestanden straks in `assets/audio/bgm/` en `assets/audio/sfx/` (nu leeg, alleen
  een README). Zonder manifest of bestanden: stil, geen errors (`play_music`/`play_sfx` geven `false`). Nog niet
  ingehaakt in kaart/gevecht. Beide export-presets hebben nu `include_filter="*.json"` zodat het manifest in de APK
  zit (`docs/*` blijft uitgesloten). Arm64-preset: `export_path` = `../rpg_prototype_v0.18_arm64.apk`.
- **Design + lore (alleen referentie, niet in de APK; `docs/.gdignore`):** `docs/design/` (Rangkuil-arena, andere
  statschaal) en `docs/lore/` (worldbuilder: wereld, personages, Act 2-6, `data/*.json`) + `docs/lore/BOTSINGEN.md`.
  **`docs/lore/CANON.md`** = de beslissingen van Dennis (gaan boven de worldbuilder): o.a. Noor alleen uit Esdoorn,
  Opa blijft naamloos, Dennis = Hanger/Sleutel + Proefpersoon H-6 (twist), Golem = Het Kennis-Beest ('Kustos'),
  roze = de Stroom / glitch = Zwarte Stroom, onze stats/namen blijven (lore-data alleen via converter).

**Nieuw in v0.17 (versie 0.17, code 19): Esdoorn, Noor en het Donker Woud.**
- **Esdoorn** (`scenes/maps/esdoorn.tscn` + `esdoorn_huis_noor.tscn`, `esdoorn_herberg.tscn`), Noors dorp op de
  wereldkaart; pas open na de Golem (`bewaker:archief_golemhal/golem`). Gebouwd door
  `tools/build_maps.gd -- --only=v17` (raakt dorp/binnen/Wilgendal NIET aan). Herberg met slapen + opslagboek.
- **Ontmoeting** (eenmalig, `noor_ontmoeting` in `story_data.gd`): blauwe ballonnen, Noor wordt door wortels
  gegrepen, Marit vraagt Dennis haar te redden -> opdracht **"Red Noor uit het Donker Woud"** (`SD.QUESTS`;
  getoond in het veldmenu onder 'Opdracht'). Alle tekst = placeholder met `TODO(verhaal)` (`SD.TODO_STORY`).
- **Donker Woud** (`scripts/data/woud_rooms.gd`, thema `donker_woud`): Woudrand -> Woudpad -> Mistpoel ->
  Sporenkring (savepunt) -> Open Plek (baas). Kisten, monsters Lv ~10-13 (Wortelkruiper, Mistuil, Sporenzwam;
  zwak voor vuur), Kernkracht-stun werkt, gevechtsachtergrond `donker_woud.png`, glitch loopt op naar de baas.
  Nieuwe **Overlay**-laag (boomkruinen, mistbanden, glitch boven de speler) + driftende mist (`woud_mist.gd`).
- **De Wortelkoning** (baas, idle/hit-animatie) houdt Noor vast in een cocon; na winst cutscene `noor_bevrijd`:
  Noor komt in de groep (niveau Dennis-1, eiken staf + reisgewaad), opdracht klaar.
- Story-commando's erbij: `join`, `glitch`, `heal`; spreker `"{naam}"` = spelernaam. Kamers kennen nu ook
  `"objects"` en `"npcs"`. `sprite_back` (rugaanzicht) voor de 4 woudmonsters en mosslijm/papiergeest/glitchmot/
  kennis_beest (Codex-art; Codex-logica zelf = RPG CODE).
- **De Codex** (patch van RPG CODE, zie `HANDOFF_CODEX.md`): Leeg Boek op een verzwakt monster = pagina in de
  Codex; één Codex-monster vecht mee als AI-bondgenoot (ook in baasgevechten); veldmenu > Codex. Vangbaar in het
  woud: Wortelkruiper, Mistuil, Sporenzwam (De Wortelkoning niet: baas). **Lege Boeken**: niet in de startvoorraad;
  3 van Marit in Esdoorn (na de ontmoeting, of bij een gesprek met haar in een oude save; flag `marit_boeken`)
  + 1 in een kist op het Woudpad en 1 in de Sporenkring. MP-kosten van RPG CODE (nu 0). Moskonijn en Mech.
  Wachter hebben nog geen rugaanzicht (plaatsvervanger in code). Test: `--codextest`.
- Map-sprites van de woudmonsters/Wortelkoning en de wereldkaart-iconen (Esdoorn, woudingang) van RPG ART.
- Art: zie `/workspace/v17_ART_SLOTS.md` en `docs/HANDOFF_WOUD.md`. Test: `--woudtest`. Versielabel v0.17.

**Nieuw in v0.15 (versie 0.15, code 17): de archieven als 'grauwe grijze bieb' + commando-kruis links.**
- **Archief-thema** (data-gedreven): `scripts/data/dungeon_rooms.gd` `THEMES` / `DEFAULT_THEME = "archief_grijs"`.
  Elke dungeonkamer (en een puzzelkamer met `"style": "dungeon"`) kiest zijn beeld via `"theme"`; zonder
  `"theme"` krijgt hij het standaardthema, dus ALLE (ook toekomstige) archieven zien eruit als de
  gevechtsachtergrond `assets/battle/bibliotheek.png`: grijze steenvloer, hoge donkere boekenkasten als
  muurvoorkant, stenen pilaren, stof/bladzijden, spaarzaam magenta/cyaan. Tegelnummers, botsing en indeling
  zijn ongewijzigd. `"archief_v14"` = de oude bruine art (blijft bestaan).
- Nieuwe gegenereerde art (`tools/art_archief_grijs.py`, GEEN handwerk): `assets/tiles/dungeon/archief_grijs_tiles.png`,
  `archief_grijs_bibliotheek.png` en `assets/sprites/dungeon/grijs/*.png` (kist, kasten, kandelaar, golemdeur,
  puzzelobjecten). Losse objecten laden hun plaatje via `DungeonRooms.themed(pad)`.
- **Commando-kruis** in het gevecht staat nu LINKS naast de held (op de hoogte van de heldenrij, nooit over
  een held, statusvak of de D-pad); bij een grote party schuiven de statusvakken iets op om plek te maken
  (`battle.gd` `_place_cross`, `_box_left_for_cross`). De vijandenrij blijft gecentreerd en schuift alleen
  opzij als hij over het kruis zou vallen.
- **Kernfragmenten stap 1** (patch van RPG CODE, zie `HANDOFF_KERN.md`): na de echte Golem-winst absorbeert
  Dennis de Golemkern (`scripts/kern/kern_absorption.gd`, art `assets/fx/kern_absorptie.png`), vaardigheid
  **Kernslag** onder Magie (3 rondes opladen), zware kasten (`assets/puzzle/kast_zwaar.png`; in het archief-thema
  grijs) alleen te duwen met 'Zware blokken duwen'. Data: `scripts/data/kern_data.gd`. Test: `--kerntest`.
- Versielabel v0.15.

**Nieuw in v0.14 (versie 0.14, code 16; nog geen APK): het Eerste Archief, 4 verdiepingen.**
- 13 kamers volgens `story/ARCHIEF1_PLATTEGROND.md`: V1 Ingang (savepunt) + Stoffige Gang; V2 Kastenzaal,
  Leeszaal, Trapzaal; V3 Zuilenhal, Puzzelkamer (met de geheime schatkamer op dezelfde map) en Gang;
  V4 Wachtersgang, Voorhal, Bibliotheek (savekamer) en de Golemhal (alleen via de golemdeur van de bibliotheek).
- Data: `scripts/data/dungeon_rooms.gd` (layouts uit `tools/gen_archief1_rooms.py`), puzzelkamer
  `archief_puzzel` in `scripts/data/puzzle_rooms.gd`. Meerdere uitgangen per kamer met benoemde spawns,
  terug omhoog kan altijd.
- Monsterniveau (tier 1-4) per kamer (`GameData.TIERS`, `apply_tier`); alleen in de dungeon, nooit voor een baas.
  34 gevechten, ~Lv 10 bij de Golem. Bewakers (en de Golem) blijven na winst voor altijd weg.
- Kisten (eenmalig, `kist:<id>` in story_flags), HP-boeken, bibliotheek-opslagboek `save_bibliotheek`.
- Art van RPG ART (nieuwe namen, in `tools/handwerk.txt`). Geheime deur, runeplaat en schatkist zijn nog
  PLACEHOLDERS voor RPG CODE: zie `docs/HANDOFF_ARCHIEF1.md`.
- Versielabel v0.14.

**Nieuw (pakket 'menu L2' van RPG CODE, bovenop v0.13; nog geen versienummer/APK): veldmenu in Lufia 2-stijl.**
- **Uitrusting** (nieuw in het veldmenu, na Magie): links portret, Lv, HP/MP en ATK/DEF/MAG/MDEF/SPD
  met pijlen oud > nieuw (groen omhoog = beter, rood omlaag = slechter); rechts de vakken Wapen,
  Schild, Helm, Harnas, Accessoire en het submenu Uitrusten, Sterkste, Afdoen, Alles afdoen,
  Weggooien. Data = de beginnersset uit `story/ITEMS_ELEMENTEN.md` (**VOORSTEL**) in
  `game_data.gd` (`EQUIPMENT`), regels in `scripts/equipment.gd`. Nieuwe stats `mag`/`mdef`.
- **Opslaan** = eigen scherm: groep met kleine portretten (hoofd), plek, Tijd, Goud en
  'Overschrijven? Ja/Nee' (of 'Hier opslaan?' bij een leeg slot).
- **Portretten** van RPG ART (`assets/ui/portrait_<held-id>.png`, 64x80) op Status en Uitrusting,
  pixel-scherp (nearest, precies 64x80); zonder portret het vooraanzicht uit de loop-sheet.
  Status: MAG/MDEF erbij.
- Menukleuren in `scripts/ui/menu_colors.gd`, die naar het palet van `ui_style.gd` (UiStyle) wijzen. Overdracht: [`docs/HANDOFF_MENU_L2.md`](docs/HANDOFF_MENU_L2.md).

**Nieuw in v0.13 (versie 0.13, code 15; nog geen APK): veldmenu + autosave van RPG CODE, Wachter-sprite.**
- Veldmenu (Items, Magie, Status, Bestiarium, Opties, Opslaan, Sluiten) en autoload `Settings`
  (zie het veldmenu-pakket hieronder). Opslaan kan **overal via het menu** (geneest niet), bij het
  **cyaan boek** (vult eerst HP en MP) en er is een **autosave**-slot (na mapwissel, na winst,
  app naar de achtergrond). 'Doorgaan' laadt de nieuwste save. `puzzle_latched` en de boekpunten
  blijven zoals in v0.12.
- De Oude Man / Wachter in de proloog gebruikt nu `assets/sprites/wachter.png` van RPG ART
  (48x96, zelfde indeling als `player.png`; nieuw NPC-veld `sheet`).
- **Gevecht-UI (v0.13):** commando-**kruis** rechtsonder (midden Aanval, boven Magie, links Item,
  rechts Verdedig, onder Vluchten; art `assets/ui/knop_*.png` van RPG ART), D-pad + A/B of tikken;
  grijze knoppen voor wat niet kan. Doelkeuze met pijltje (`assets/ui/richtpijl.png`) + naamlabel,
  links/rechts wisselt, B terug naar het kruis. Spec: `art_specs_v13/BATTLE_UI_SPEC.md`.
- **Eén palet voor alle schermen:** `scripts/ui/ui_style.gd` ('Inkt & Perkament').
- **Titel:** *SAPIENTIA – De Vergeten Archieven* met een lichte roze glitch; gebruikt
  `assets/ui/title_logo.png` en `assets/ui/title_bg.png` zodra RPG ART die levert.
  App-naam (Android-label en projectnaam) is nu **SAPIENTIA**; pakket blijft `com.dennis.rpgprototype`.
- Nieuwe dorpssprites van RPG ART voor Dennis (`player.png`) en de Wachter (`wachter.png`).
- **Titelscherm af:** `title_bg/logo/ondertitel/logo_glitch/kern.png` op een vaste 384x216-'stage'
  (gecentreerd; bredere schermen krijgen de achtergrond als opvulling). Logo-glitch (6 frames,
  14 fps) elke 3-5 s, kern 4 frames op 7 fps, menu rechtsonder (x 240-372). Valt terug op tekst
  als de plaatjes ontbreken. Versielabel v0.13.
- **Wereldkaart + eerste dungeon in normaal spel:** na de proloog-scènes (stap NACHT) zijn het pad
  naar de vallei en de ingang van **De Vergeten Archieven** open (ook de trap op de wereldkaart).
  Eerste kamer `scenes/maps/archief_ingang.tscn`, gebouwd uit data (`scripts/data/dungeon_rooms.gd`)
  door `scripts/dungeon/dungeon_room.gd` met de tegels van RPG ART (`assets/tiles/dungeon/`,
  nummers in `docs/DUNGEON_TILES.txt`). Savepunt = het cyaan boek.
- **Zichtbare map-monsters (Lufia 2), geen random encounters in dungeons:** per kamer een lijst
  `monsters` (`enemy`, `tile`, `moves`, optioneel `group`/`boss`/`sprite`/`size`/`frame`/`fps`).
  Ze lopen tile voor tile rond (`scripts/dungeon/map_monster.gd`); aanraken = gevecht met hun groep,
  winst = weg (tot je de kamer opnieuw binnenkomt), vluchten = 1,5 s knipperen/onkwetsbaar.
  De Golem staat stil (aanraken of A = baasgevecht). Plaatje: `assets/map_monsters/<enemy_id>.png`
  (32x64: 2 kolommen x 4 richtingen onder/links/rechts/boven, frames 16x16); ontbreekt dat, dan
  een gemarkeerde placeholder (`tools/art_map_monsters.py`, magenta hoekjes).
- **Nieuwe vijand Mechanische Wachter** (`mech_wachter`, stats voorlopig) met gevechts-, idle- en
  map-art van RPG ART. Vijanden kunnen nu een idle-strook (`idle`, `idle_frames`, `idle_time`) en
  een raak-plaatje (`hit`) hebben. **Golem (Kennis-Beest) heeft nieuwe gevechts-art** (`golem_boss*.png`).
- **Buiten bij het Wachtershuis (RPG ART, `assets/sprites/buiten/`):** nieuwe ingang van de Archieven
  (3x2 tiles; dicht, vanaf de nacht open met flakkerende gloed), zegelstenen (16x32, gecontroleerd =
  rune flakkert), kist, waterput (2x2) en ruïne-stukken rond de ingang. `StoryObject` kan nu frames
  laten rondlopen (`loop_if`, `loop_time`, `loop_texture`).
- **Wereldkaart:** het oude stadsicoon is nu het **Wachtershuis**; nieuw eerste dorp **Wilgendal** op
  (30,23) (iconen van RPG ART in `assets/tiles/wereld_v14.png`, tegels #132-#137, terrein `stad`).
- De Wachter kent de namen van de andere twee helden niet (`/workspace/story/ACT1_LORE.md`).
- Tests: `-- --autotest`, `-- --menutest`, `-- --puzzletest` en nieuw `-- --dungeontest`
  (`scripts/tests/dungeon_tests.gd`; met venster en `--shots=/map` ook de v0.13-screenshots).

**Nieuw in v0.12 (versie 0.12, code 14): het puzzelsysteem van RPG CODE (De Vergeten Archieven).**
- Duwbare kasten, drukplaten, hendels, poorten (all/any/invert/latch) en een herstelsteen;
  alles in `scripts/puzzle/`, kamers als data in `scripts/data/puzzle_rooms.gd`. Uitleg voor
  level-ontwerp: [`docs/PUZZELS.md`](docs/PUZZELS.md); overdracht: `docs/HANDOFF_PUZZELS.md`.
- Testkamer `scenes/maps/archief_test.tscn` (14x11). **TIJDELIJK**: F4 = naar de testkamer,
  alleen in debug-builds (in de APK bestaat de actie niet). De echte ingang komt later.
- Vergrendelde poorten gaan mee in de save (`puzzle_latched`, oude saves = `{}`).
- Tests: `godot --headless --path . -- --puzzletest` (127 checks) naast `-- --autotest`.
  `scripts/tests/*` zit niet in de export.

**Nieuw in v0.11 (versie 0.11, code 13): de proloog "De Wacht van de Wachter" (scène 1 en 2).**
- Het verhaal staat in `story/PROLOOG.md` (van Dennis). Scène 3/4 (de Archieven en de Golem)
  komen later.
- **Het dorp is nu het eenzame huis** op een stenen fundering, met groen en een oud bos eromheen
  (zelfde bestand `scenes/maps/wilgendal.tscn`, zelfde plek van huis/deur/spawns). Geen andere
  huizen of NPC's. Rechtsboven, achter de bomen en een rotsheuvel: de overwoekerde **ingang van
  De Vergeten Archieven** (dicht tot na scène 2). Het pad naar de wereldkaart is er nog, maar is
  tijdens de proloog dicht ("Niet vandaag, Dennis").
- **Verhaal-systeem** (data-gedreven): `scripts/data/story_data.gd` = alle stappen, events,
  teksten en triggers; `scripts/story.gd` (autoload `Story`) voert ze uit. Commando's o.a.:
  tekst, keuze, NPC/speler laten lopen en draaien, scherm schudden, witte flits, licht door de
  ramen, fade, tint (dag/avond/nacht), wachten, getimede events, deuren op slot/open, flags,
  items/wapen geven, gevecht, mapwissel en een "Wordt vervolgd"-kaart. Voortgang =
  `story_step` + `story_flags` in de save. Objecten (`scenes/story_object.tscn`: put, zegels,
  kist, schilderij, ingang) en NPC's/deuren/uitgangen hebben een `event` en `show_if`.
- **Scène 1 (ochtend)**: nieuw spel = wakker worden in bed. De Oude Man staat buiten en staart
  naar de ruïnes; zijn tekst komt letterlijk uit het verhaal (met jouw naam). Taken: **water uit
  de put** (→ *Emmer water* → naar Opa), **3 zegelstenen** aan de bosrand ('Het zegel gloeit
  zwak...') en de **kist** naast het huis (*Geneeskrachtig kruid* x3). Daarna de **zwaardles**
  ("Soms moet je je verdedigen, jongen, ...") → je krijgt een **Kort zwaard** (ATK +3) en een
  **oefengevecht** tegen een Mosslijm met tips op het scherm (*Aanval*, daarna *Item > Kruid*);
  vluchten kan daar niet en je kunt niet KO gaan.
- **Scène 2 (avond)**: fade naar de avond (donkere tint), je leest binnen een boek van Opa. De
  grond schudt, een witte flits, roze/blauw licht door de ramen. De Oude Man (letterlijke tekst
  uit het verhaal) pakt een verroest zwaard achter het schilderij en rent naar buiten; de deur
  zit op slot ('De deur zit op slot. Opa zei dat ik hier moest blijven.'). Na een paar seconden
  weer een schok + een schreeuw in de verte → keuze **Blijven** (wachten, nieuwe schok, weer de
  keuze) of **Opa achterna** (deur open, nacht, de ingang van de Archieven staat open en gloeit →
  'Wordt vervolgd: De Vergeten Archieven').
- Het opslagboek werkt de hele proloog; `story_step`/flags gaan mee in de save. Een save van
  v0.10 (zonder verhaal) laadt als 'proloog klaar'.
- **Boekpunten** (één object `scripts/book_point.gd` + `scenes/book_point.tscn`, data in
  `scripts/data/book_data.gd`, veld `type`), elk met dezelfde pulserende aura in eigen kleur:
  - `save` (cyaan `#3ff0ff`, het opslagboek in het huis): eerst **HP en MP van de party vol**
    ('Een warme gloed herstelt je krachten en je geest.', v0.12), dan 'Voortgang opslaan?' Ja/Nee.
  - `mp` (groen `#3fff7a`, `assets/sprites/mp_book.png`): alleen MP vol, niet opslaan
    ('Je geest raakt helder. MP hersteld.').
  - `hp` (rood `#ff3f4f`, `assets/sprites/hp_book.png`): alleen HP vol, niet opslaan
    ('Je wonden sluiten zich. HP hersteld.').
  Rood en groen zijn bedoeld voor dungeons; nu staan ze op een TEST-PLEK naast de ingang van
  de Archieven (rood (24,4), groen (27,4); letters `R`/`M` in `TOWN_MAP`).
- De hoofdpersoon heet in de code nu **`dennis`** (was een oude werknaam): held-id, data,
  plaatjes `assets/sprites/battle/dennis.png` (zijaanzicht) en **`dennis_rug.png`** (nieuw:
  **rugaanzicht** van RPG ART voor het voor-achter-gevecht, 2100x210, 10 frames van 210x210,
  voeten op (105,203), zelfde frame-volgorde). Saves van v0.10 met het oude id laden gewoon
  (`GameState.LEGACY_HERO_IDS`). De naam in het spel komt nog steeds uit het naamscherm.
- Mosslijm en Moskonijn hebben nu de echte vooraanzichten van RPG ART. Nieuwe placeholders
  (put, zegel, kist, schilderij, ingang) worden gemaakt door `tools/art_v11.py` en staan in
  `tools/handwerk.txt`, zodat echte art er zo overheen kan.

**Nieuw (veldmenu-pakket 'code_menu', bovenop v0.10): volledig veldmenu, opties, autosave.**
- **Veldmenu** (MENU-knop rechtsboven, of Esc/M/Tab; niet tijdens een tekstvak, gevecht of
  mapwissel). Links de groep (naam, klasse, Lv, HP/MP-balken; tik op een held = zijn Status),
  rechts de commando's **Items, Magie, Status, Bestiarium, Opties, Opslaan, Sluiten**, daaronder
  goud, speeltijd en de plek. De speler staat zolang op slot en de touch-D-pad/A/B is weg: je
  tikt direct op de regels (16 px hoog). Met toetsen/gamepad: omhoog/omlaag (loopt rond), A
  kiest, B/MENU = terug. Elk scherm heeft rechtsboven een grote **Terug**-knop.
- **Items**: alles uit de tas met aantal, uitleg en effect. Genees-items (Drankje, Toverwater)
  werken ook buiten gevechten: kies een held, HP/MP worden begrensd op het maximum, het aantal
  gaat omlaag (op 0 = weg uit de lijst). Volle HP = 'Dat heeft nu geen effect.' (niets
  verbruikt). Items die hier niet kunnen (`"field": false` of onbekend) staan grijs met een melding.
- **Status**: per held portret (uit de gevechtssprite), klasse, Lv, HP/MP, EXP en 'nog X EXP'
  tot het volgende level (`GameData.exp_for_level`), Aanval/Verdediging/Snelheid en de
  spreuken. Links/rechts of de `<` `>` knoppen = andere held.
- **Magie**: spreuken per held met MP-kosten. **Genees** werkt buiten gevechten (zelfde formule
  als in het gevecht, MP eraf); Vuur/Bliksem staan grijs ('Dit kan alleen in een gevecht.').
- **Opties** (autoload `Settings`, bestand `user://settings.cfg`, los van de save): Muziek- en
  Effectenvolume (audiobussen `Music`/`SFX`, worden aangemaakt), Tekstsnelheid (tekstvak),
  Gevechtstempo, Knoppen zicht + Knopgrootte (touch-D-pad/A/B), Scanlines (CRT-filter),
  Schudden (treffers in gevechten), **Autom. opslaan**, en Standaard.
- **Opslaan** kan in het menu (overal, keuze van Dennis) én bij het opslagboek: zelfde
  handmatige save `user://save_1.json`.
- **Automatisch opslaan** in een eigen bestand `user://autosave.json` (overschrijft de
  handmatige save nooit; zelfde formaat): na elke mapwissel, na een gewonnen gevecht en als de
  app naar de achtergrond gaat (Android). Nooit tijdens een gevecht, mapwissel of tekstvak, en
  niet bij het begin van een nieuw spel. **Doorgaan** op het titelscherm laadt de nieuwste van
  de twee (met '(auto)' erachter als dat de autosave is).
- Test: `godot --headless --path . -- --menutest` (zie hoofdstuk 8). (Uitrusting: zie het
  pakket 'menu L2' hierboven.)

**Nieuw in v0.10 (versie 0.10, code 12): titelscherm, eigen naam, het huis, opslaan, bestiarium.**
- **Titelscherm** 'De Vergeten Bibliotheek' met *Doorgaan* (grijs als er geen save is) en
  *Nieuw spel* (`scenes/ui/title.tscn`, nu de hoofdscène).
- **Naam kiezen** ('Hoe heet je?', voorgevuld met *Dennis*, max. 10 tekens, leeg = Dennis). Op
  Android opent het schermtoetsenbord. Die naam staat overal (statusvak, 'Wat doet
  Dennis?', `{naam}` in teksten, zoals bij de Oude Wijze) en staat in de save.
- **Nieuw spel = party van 1**: de hoofdpersoon (held `dennis`). Noor en Lotte staan
  nog in `game_data.gd` en komen later met `GameState.add_member("noor")` / `("lotte")`.
  Gevecht met 1 held: statusvak in het midden, held erboven.
- **Het huis is open**: tegen de deur lopen = korte fade naar binnen
  (`scenes/maps/huis_wilgendal.tscn`, 12x9 tiles: boekenkasten, raam, bed, tafel, tapijt,
  kandelaar). De deur onderin brengt je terug, net onder de huisdeur.
- **Opslagpunt**: een gloeiend open boek op een lessenaar (v0.11: `scenes/book_point.tscn` type `save`, 4 frames).
  Kijk ernaar + A: 'Het boek gloeit zacht. Voortgang opslaan?' **Ja/Nee** (omhoog/omlaag + A,
  B = Nee, of tik). Ja schrijft `user://save_1.json`: map, plek + kijkrichting, naam, party
  (HP/MP/level/EXP/stats/spreuken), items, goud, speeltijd en het bestiarium.
- **Gevechtsachtergrond per terrein** (Lufia-stijl, één tabel `TERRAIN_BACKDROP` in
  `game_data.gd`): gras/hoog gras/bos = **gras**, zand = **zand**, baasgevecht = **boss**
  (de art van RPG ART in `art/battle_bg/`). De bibliotheek blijft als `"library"` voor een
  latere dungeon. Encountergroep met `"boss": true` (nu alleen via **F3**); de baas staat
  boven de magenta cirkel (`BACKDROP_STAGE`).
- **Bestiarium** (MENU-knop rechtsboven, of Esc/M/Tab → *Bestiarium*): alle monsters op
  nummer; nog niet gezien = '???' + silhouet, gezien = plaatje, naam en beschrijving, minstens
  1x verslagen = ook HP/MP/ATK/DEF/EXP/goud/zwak/sterk/buit/leefgebied. Gezien/verslagen gaat
  mee in de save. Nieuw op het gras: **Mosslijm** en **Moskonijn** (placeholder-art tot RPG
  ART de vooraanzichten levert in `art/enemies/`). Encountergroepen kunnen nu per terrein
  (`"terrains"`).
- Vijanden in de data hebben extra velden: `mp`, `weak`, `resist`, `drops`, `desc`, `habitat`
  (zwak/sterk en buit zijn nu alleen informatie in het bestiarium, nog niet in het gevecht).

**Nieuw in v9.1 (versie 0.9.1, code 11): voor-achter-gevecht (zoals Lufia 2 / Dragon Quest).**
- Elke held staat **midden boven zijn eigen statusvak** (voeten 3 px boven de bovenrand, de
  grondschaduw op het vak). Het commandomenu mag over de helden vallen.
- De vijanden staan **bovenin op een rij, midden op het scherm**, iets kleiner
  (`ENEMY_DEPTH_SCALE = 0.88` in `battle.gd`) zodat ze verder weg lijken; laag `Enemies` wordt
  vóór `Party` getekend. Aanval-stapje van een held gaat nu **omhoog** (naar de vijanden).
- De huidige art is nog zijwaarts (helden 3/4 op de rug naar rechts, vijanden naar links);
  voor deze opstelling zijn nieuwe sprites nodig (helden: rugaanzicht omhoog; vijanden:
  vooraanzicht naar de camera).

**Nieuw in v9 (versie 0.9, code 10): ruimer gevechtsscherm (wens van Dennis).**
- Het grote berichtvenster ('Wat doet Dennis?') en het tabje 'De Vergeten Bibliotheek' zijn
  **weg**. Berichten ('Dennis valt aan!', schade, 'Wat doet Dennis?') verschijnen kort in een
  **smalle, half doorzichtige strook bovenin** (`Caption`), die na ±1,8 sec vervaagt (blijft
  staan zolang je kiest of moet tikken). Tikken waar dan ook = verder. Het
  overwinningsvenster is hetzelfde gebleven.
- **Helden en vijanden staan lager** (voeten rond y 124 van 216, zelfde grondlijn), helden
  blijven groot.
- Het **commandomenu staat direct boven het statusvak van wie er aan de beurt is** en
  **schuift mee** (0,18 sec) naar de volgende held. Geen naam-tabje meer (het statusvak is al
  magenta); Magie/Item/Doel openen op dezelfde plek, met een klein tabje. Doel kiezen: de
  namen staan in het menu én een pijltje wijst het doel aan (tikken op de vijand/held of op
  een naam kan allebei). Het menu blijft tussen de D-pad en de A/B-knoppen.
- Menuknoppen reageren bij het **indrukken** (niet pas bij loslaten), ook tijdens het schuiven.
- Overworld: de **definitieve tiles en figuren van de art director** (dorp, huis, wereldkaart,
  speler, NPC, bordje) zitten erin en staan in `tools/handwerk.txt`.

**Nieuw in v8 (versie 0.8, code 9): grotere, levendigere helden en dorp + wereldkaart in de
nieuwe stijl.**
- **Helden en vijanden zijn nu handgetekend door de art director** (in `assets/sprites/battle/`
  en `assets/sprites/enemies/`); de gegenereerde versies uit `tools/art_v8_heroes.py` /
  `art_v8_enemies.py` zijn alleen nog placeholders.
- **Helden ±35% van de schermhoogte** (±155 fijne pixels, zoals de mockup), warmer en beter
  leesbaar: echte huidskleur, bruin leer, haarkleur (Dennis donkerbruin, Noor kastanje, Lotte
  blond), donkere capes (Dennis antraciet met rode voering en bronzen rune, Noor donker pruim),
  rood manteltje voor Lotte en glimmend metaal. Dynamische houding: leunen naar voren, wapen
  geheven, brede stand.
- **Idle-animatie**: wie niet aan de beurt is (pose 'stil') ademt rustig (op/neer), de cape
  zwaait mee en de bol/het kristal van de staf pulseert. Elke held loopt iets uit fase.
  Sprite-strook nu **10 frames van 210x210** (frame 8 = inademen, 9 = uitademen).
- (Ontwerpen in de placeholder-generator:) **Papiergeest** = prop verfrommelde bladzijden met binaire tekst, donkere ogen en een
  gescheurde grijns (zoals de mockup). **Het Kennis-Beest** heeft meer boek-detail: vergulde
  ruggen, leeslinten, losse vellen en met perkament omwikkelde armen.
- **Opstelling aangepast** (helden lager/breder, vijanden iets naar rechts, de baas mag iets
  lager staan, menu iets lager met rijen van 11): de autotest controleert dat helden en vijanden niet over vensters, tabjes,
  statusvakken of de D-pad/A/B vallen.
- **Dorp Wilgendal en de wereldkaart** in 'De Vergeten Bibliotheek'-stijl: ontkleurd grijs/steen
  met donkergroen. Het huis is een kleine **bibliotheek** (natuursteen, boogramen met
  boekenkasten, roosvenster, lantaarns naast een boogdeur, kapotte leien met glitch-pixels),
  tonnen werden **lantaarns**, hekken smeedijzer, bloemen grijs-wit met papiersnippers. Op de
  wereldkaart: leisteen-zee, grijze bergen, donker bos, plavuizen van een verdwenen academie
  en een **bibliotheek met zuilen** als stad-icoon. Magenta/cyaan alleen als losse pixels.
  Zelfde tiles (16x16), zelfde kaarten, botsingen en doorgang (zee/bergen dicht, bos begaanbaar).
- **Speler en NPC** in de party-look: Dennis met donkere cape (bronzen embleem op de rug), leer
  en grijze kraag; de Oude Wijze als geleerde in een grijsgroene mantel met perkamenten kraag.
- Alle prestatie-verbeteringen van v7 zijn behouden.
- Stijl: [`docs/ARTSTYLE.md`](docs/ARTSTYLE.md), hoofdstuk 10d en 13.

**Art vervangen (bv. handgetekende versies)** – zonder code aan te passen, gewoon het bestand
overschrijven (zelfde naam) en Godot laten importeren:
- helden: `assets/sprites/battle/dennis.png`, `noor.png`, `lotte.png` = strook **2100x210**, 10
  frames van 210x210, voeten op **(105,203)** in elk frame, figuur ±155 px hoog, kijkt naar
  rechts. Frames: 0 stil, 1 klaar, 2 aanval A, 3 aanval B, 4 spreuk A, 5 spreuk B, 6 geraakt,
  7 KO, 8 inademen, 9 uitademen. (Oudere stroken met 8 frames van 160x160 werken ook, zonder
  idle-animatie.)
- vijanden: `assets/sprites/enemies/kennis_beest.png`, `papiergeest.png`, `glitchmot.png` =
  losse PNG (doorzichtig), kijkt naar links, voeten midden-onderaan ±3 px boven de onderrand,
  op het scherm op halve grootte. Grondschaduw midden-onder, het midden **6 px boven de
  onderrand**. Maximaal **194 px hoog** (hoger wordt passend verkleind; een hoge baas staat
  vanzelf iets lager zodat zijn kop in beeld blijft).
- Bestanden die met de hand gemaakt zijn staan in `tools/handwerk.txt`:
  `python3 tools/generate_art.py` slaat die over (placeholder terug: `--ook-handwerk`).
- Overworld-tiles en figuren: zie de spec voor de art director
  (`docs/art_specs/TILESET_SPEC.md` + sjablonen; ook in `/workspace/art_specs_v8/`; opnieuw maken
  met `python3 tools/make_tile_templates.py <map>`).

**Nieuw in v7: nieuwe stijl 'De Vergeten Bibliotheek' (digitaal verval x dark academia).**
- **Alle vensters** (gevecht én tekstvak in de overworld): donker houtskool-grijs, dunne lichtgrijze
  rand, metalen hoekjes met klinknagels, pixel-ruis in het tekstvak, titel-tabjes. Neon **magenta**
  en **cyaan** alleen als accent (actieve held, selectie, D-pad, A/B-rand, MP-balk).
- **Scanline-filter** over het hele scherm (autoload `Crt`) met een licht vignet en af en toe een
  korte glitch. Alles instelbaar op één plek: `CRT` in `scripts/data/game_data.gd`
  (`"enabled": false` = uit; tijdens het spel `Crt.set_enabled(false)`).
- **Gevecht in een vergeten bibliotheek**: grijze zaal met kasten, bogen en zuilen, aangetast door
  zwarte pixelblokjes, binaire code en glitch-banden.
- **Grote helden** (±112 fijne pixels, 2x v6) op een rij links: Dennis (donkere cape met rune,
  zwaard dat in pixels uiteenvalt), Noor (paardenstaart, kapmantel, staf met magenta bol), Lotte
  (grijs-wit gewaad met cyaan).
- **Nieuwe vijanden**: *Papiergeest* (was slijm), *Glitchmot* (was vleermuis) en de baas
  *Het Kennis-Beest* (was goblin, iets sterker; zeldzaam).
- **Minder haperingen op de telefoon** (zie 'Prestaties (v7)' hieronder).
- Stijlregels en palet: [`docs/ARTSTYLE.md`](docs/ARTSTYLE.md), hoofdstuk 10c en 13.
  Losse sprites om te bewerken: zie `LEESMIJ_frames.txt` in de sprite-export.

**Prestaties (v7)** – oorzaken van haperen op Android die zijn aangepakt:
- Lopen + camera gebeurden in `_physics_process` (vast 60x/sec). Op 90/120 Hz-schermen
  (Samsung) gaf dat schokkerig scrollen. Nu in `_process` (per beeld, met delta).
- Gevechtsscène, achtergronden en alle helden-/vijandplaatjes worden bij de start **op de
  achtergrond voorgeladen** (`GameState`, `ResourceLoader.load_threaded_request`) en vastgehouden;
  bij een encounter of mapwissel wordt niets meer van schijf geladen.
- `Texture.get_image()` (trage GPU-terugleesactie) werd bij ELK gevecht gedaan voor de vensters
  en per vijand. Nu één keer per plaatje, daarna uit een cache.
- De ruis-textuur van het tekstvak wordt één keer gemaakt en gedeeld (en voor het tekstvak in de
  overworld al bij de start), niet per gevecht/gesprek.
- Shaders: het scanline-filter leest het scherm niet uit en draait op de lage spelresolutie; de
  glitch-shader (die wel het scherm leest) staat alleen ±0,1 sec aan. Beide worden bij de start
  onzichtbaar 'opgewarmd' zodat de eerste glitch niet hapert door shader-compilatie.
  Shader-waarden worden alleen gezet als ze veranderen.

**v6: het gevechtsscherm in '16-bit plus' (2x zo veel pixeldetail).**
- Tijdens een gevecht tekent het spel op een **2x zo fijn raster** (768x432 in plaats van 384x216).
  Alle gevechts-art is opnieuw en 2x zo fijn getekend, maar het blijft scherpe pixel-art (geen blur).
  Na het gevecht gaat alles terug naar normaal: **de overworld, het dorp en de wereldkaart zijn niet
  veranderd**.
- **Een dichtere camera met scherpe helden.** Ze staan op een rij naast het menu, ±55 fijne pixels hoog
  (Octopath Traveler-achtig), van achteren schuin gezien. Ze hebben schaduw, plooien en
  8 poses (stil, klaar, 2x aanval, 2x spreuk, geraakt, KO):
  - **Dennis**: krijger met bruin stekelhaar, groene tuniek, karmijnrode cape, stalen schouderstukken
    en zwaard
  - **Noor**: magiër met diepblauw gewaad, puntmuts met gouden band en een staf met blauwe bol
  - **Lotte**: genezer met blond haar en vlecht, wit gewaad, saliegroen manteltje met kap, rode band
    en een staf met gouden ring
- **Nieuwe vijanden.** De goblin is even groot als de helden, de slijm en de vleermuis zijn groot:
  - **goblin**: met stekelknots, ijzeren schouderstuk, riem met noppen, slagtanden en gele ogen
  - **slijm**: glanzend en doorschijnend, met belletjes
  - **vleermuis**: vliezige vleugels met vingerbotten
- **Nieuwe achtergronden met diepte.** Het **bos** heeft nevelige verre dennen, donkere dennen met
  stammen, grote bomen, varens, stenen en een open plek met grasplekken, kiezels en lichtvlekken.
  De **vlakte** heeft verre heuvels, rotsheuvels, struiken en een grasweide met bloemetjes.
  In de hoeken staan grote voorgrond-varens en struiken die het beeld omlijsten.
- **Scherpere vensters.** Het zijn dezelfde indigo vensters, maar met randen van 1 fijne pixel. Het
  statusvak van wie aan de beurt is, krijgt een fijne gouden rand. De balken hebben glans en het
  doel-pijltje is fijner. Het lettertype is even groot gebleven, want **leesbaarheid gaat voor**.
- De stijlregels staan in **[`docs/ARTSTYLE.md`](docs/ARTSTYLE.md), hoofdstuk 10b**.

**Nieuw in v5: een dorp en een wereldkaart.**
- Het spel begint in het dorp **Wilgendal**: kasseienplein, gras, bloemen, heggen, hekjes,
  een paar bomen en **één huis** (paars leien dak, vakwerk, ramen, deur). De deur zit op slot.
  De Oude Wijze en het bordje staan op het plein. **In het dorp verschijnen nooit monsters.**
- Loop over het kasseienpad naar het **zuiden** het dorp uit: je komt op de **wereldkaart**
  (60 x 45 tiles) naast het stad-icoon van Wilgendal.
- Op de wereldkaart zie je **zee met kust** en **bergen**. Daar kun je niet lopen. Verder is er
  **gras**, **licht gras**, **zand** en **bos**. Daar loop je wel, en overal kunnen
  **monsters** opduiken (in het bos iets vaker).
- Stap op het **stad-icoon** om terug het dorp in te gaan. De **trap** (zuidoost van het dorp) leidt
  naar een dungeon die later komt.
- Een gevecht brengt je terug naar **dezelfde map en dezelfde tile**. In het bos krijg je een
  bos-achtergrond, elders een vlakte-achtergrond. Bij GAME OVER begin je weer in Wilgendal.
- Uitleg over maps en overgangen, en hoe je zelf een nieuw dorp of een nieuwe map maakt, staat in
  **hoofdstuk 4** hieronder.

**Nieuw in v4: het gevechtsscherm lijkt nu op Lufia 2.**
- De helden staan zelf op het slagveld: schuin opgesteld linksonder, met de rug half naar je toe
  en het gezicht naar de vijanden rechts. Elke held heeft een eigen gevechtssprite van 32x32.
- Kleine animaties:
  - wie aan de beurt is, stapt naar voren
  - aanvallen en spreuken (2 frames)
  - een witte flits en schudden bij een treffer
  - liggen en grijs worden bij KO
  - vijanden springen naar de held die ze aanvallen
- Onderaan staat één **statusvak per held** met de naam en een **HP**- en **MP**-balk.
  De balken lopen rustig omlaag bij schade en de getallen staan er klein naast.
  Het vak van de held die kiest is geel omrand. Dennis heeft geen MP: zijn MP-balk is leeg en grijs.
- Na de winst verschijnt een groot doorzichtig **overwinningsvenster** met "Krijgt X EXP.",
  "Krijgt X GOUD." en per held "VOLG. LEVEL" (hoeveel EXP er nog nodig is). Level-ups komen daarna
  in hetzelfde venster.
- Niets van het gevecht ligt onder de D-pad of de A/B-knoppen. Er passen ook 4 helden in.

**Nieuw in v3:** alle art volgt nu een vaste stijlgids, afgeleid van een Lufia 2-walkthrough
op YouTube: zie **[`docs/ARTSTYLE.md`](docs/ARTSTYLE.md)**. Wat er verder veranderd is:
- personages van 16x24 (chibi)
- een eigen dun pixel-lettertype
- SNES-achtige vensters
- randjes tussen gras, pad en water
- een nieuwe gevechtsachtergrond

---

## 1. Openen en starten

1. Download Godot 4.3 of nieuwer (standaard "Godot Engine", niet ".NET") van <https://godotengine.org/download>.
   Het is één bestand; uitpakken en starten, installeren is niet nodig.
2. Pak `lufia_prototype.zip` uit naar een map naar keuze.
3. Start Godot → in de **Project Manager** klik op **Import** (of *Importeren*) →
   kies het bestand `project.godot` in de uitgepakte map → **Import & Edit**.
4. De eerste keer importeert Godot de plaatjes (paar seconden).
   *Gebruik je Godot 4.4 of nieuwer, dan maakt hij er ook `.uid`-bestandjes bij. Dat is normaal.*
5. Druk op **F5** (of de ▶-knop rechtsboven) om te spelen.

### Besturing

| Actie                  | Toetsenbord          | Telefoon / muis              | Gamepad    |
|------------------------|----------------------|------------------------------|------------|
| Lopen / menu kiezen    | Pijltjes of WASD     | D-pad linksonder             | D-pad      |
| Praten / bevestigen    | Spatie of Enter      | **A**-knop, of tik op de knop| A / kruis  |
| Terug (in menu's)      | Escape of Backspace  | **B**-knop                   | B / rondje |
| Veldmenu (Items, Status, Opties, ...) | Esc, M of Tab | **MENU**-knop rechtsboven, daarna tikken | –  |
| Gevecht forceren (test)| **F2**               | –                            | –          |
| Baasgevecht (test)     | **F3**               | –                            | –          |

In gevechten kun je ook direct **tikken** op een menuregel, op een vijand (doel kiezen)
of op een held: op zijn sprite óf op zijn statusvak (genezen, items). Ook het
overwinningsvenster tik je weg. F2 werkt alleen in debug-builds (dus vanuit de editor).

Op de PC kun je de touch-knoppen met de **muis** aanklikken
(instelling *emulate touch from mouse* staat aan).

Probeer: loop naar het **bordje** of de **oude man**, kijk ernaar en druk op A/Spatie.
Loop daarna via het pad naar het zuiden het dorp uit. Op de wereldkaart begint er af en toe een
gevecht. F2 werkt alleen op maps met monsters, dus niet in het dorp.

---

## 2. Mappenstructuur

```
lufia_prototype/
├── project.godot            Projectinstellingen (resolutie, input, renderer)
├── icon.png                 App-icoon
├── README.md                Dit bestand
├── docs/                    Stijlgids (ARTSTYLE.md), paletkaart, referentie-uitsneden (alleen intern!)
├── assets/
│   ├── tiles/
│   │   ├── dorp.png         Dorp-tiles (16x16, één rij): 0-32 = gras, bloemen, zandpad, boom, muur,
│   │   │                    water, brug, rots + randjes. 33 = kassei, 34-48 = kassei met grasrand,
│   │   │                    49 heg, 50 hek, 51 lage muur, 52 bloemenperk, 53 ton
│   │   ├── huis.png         Het huis: 80x80 = 5x5 tiles (dak, vakwerk, ramen, deur)
│   │   ├── dorp.tres        TileSet van het dorp (dorp.png + huis.png): collision + "terrain"
│   │   ├── wereld.png       Wereldkaart-tiles (raster van 16 kolommen): gras, licht gras, zand,
│   │   │                    bos, bergen, zee met kust, stad-icoon, trap
│   │   └── wereld.tres      TileSet van de wereldkaart: collision (zee, berg) + "terrain"
│   ├── sprites/
│   │   ├── player.png       Speler, 48x96: frames van 16x24, 3 kolommen (stil, stap A, stap B) x 4 rijen (onder, links, rechts, boven)
│   │   ├── npc.png          NPC in dezelfde indeling
│   │   └── sign.png         Bordje
│   ├── sprites/enemies/     Vijanden (v8, handgetekend, 2x zo fijn): kennis_beest 214x194 (baas),
│   │                        papiergeest 74x94, glitchmot 106x96 (op het scherm de helft; max. 194 hoog)
│   ├── sprites/battle/      Gevechtssprites van de helden: dennis/noor/lotte.png, strook 2100x210 =
│   │                        10 frames van 210x210 (stil, klaar, aanval A/B, spreuk A/B, geraakt, KO,
│   │                        inademen, uitademen), voeten op (105,203)
│   ├── battle/bibliotheek.png              Gevechtsachtergrond (standaard), 1280x432
│   ├── battle/bibliotheek_overwoekerd.png  Gevechtsachtergrond in het bos, 1280x432
│   ├── shaders/             scanlines.gdshader (lijnen + vignet), glitch.gdshader (korte glitch)
│   ├── ui/                  window.png (tekstvenster, metalen hoekjes), panel_status.png (statusvak,
│   │                        tabjes) en window_glass.png (overwinningsvenster), als 9-slice.
│   │                        *_hd.png = dezelfde vensters 2x zo fijn voor het gevechtsscherm
│   ├── fonts/               Eigen dun pixel-lettertype "Dauwpixel" (gemaakt met tools/generate_font.py)
│   └── theme.tres           Thema: lettertype (10 px, monospace), v7-vensters, tekstschaduw, knoppen
├── scenes/
│   ├── maps/
│   │   ├── wilgendal.tscn   ★ Dorp 1 (startscène): Ground + Gebouwen (huis) + speler, NPC, bordje, deur
│   │   └── wereldkaart.tscn ★ De wereldkaart: Ground + speler, uitgangen (stad, trap)
│   ├── player.tscn          Speler (CharacterBody2D + Sprite2D + Camera2D)
│   ├── npc.tscn             NPC (StaticBody2D)
│   ├── sign.tscn            Bordje (StaticBody2D)
│   ├── door.tscn            Deur (StaticBody2D, "De deur is op slot.")
│   ├── battle/
│   │   └── battle.tscn      Gevechtsscène (bericht-strook bovenin, helden, vijanden, menu, statusvakken,
│   │                        overwinningsvenster)
│   └── ui/
│       ├── dialog_box.tscn  Tekstvak (staat als autoload "Dialog" in het project)
│       └── touch_controls.tscn  Virtuele D-pad + A- en B-knop
├── scripts/
│   ├── map.gd               ★ Script op elke map: camera, spawnpunten, uitgangen, encounters, F2
│   ├── map_exit.gd          MapExit: uitgang-zone -> andere map + spawnpunt (of alleen een bericht)
│   ├── map_spawn.gd         MapSpawn: spawnpunt (waar je binnenkomt) met kijkrichting
│   ├── door.gd              Deur: tekst als je ertegenaan loopt of op A drukt
│   ├── game_state.gd        Autoload "GameState": party, inventaris, goud, huidige map, posities, encounters
│   ├── transition.gd        Autoload "Transition": flits/fade tussen overworld en gevecht
│   ├── ui/crt_overlay.gd    Autoload "Crt": scanline-filter + glitch (instellingen: CRT in game_data.gd)
│   ├── settings.gd          Autoload "Settings": opties in user://settings.cfg (volume, tekst, touch, ...)
│   ├── party_actions.gd     Items/spreuken buiten gevechten (regels, geen UI)
│   ├── ui/field_menu.gd     Veldmenu: groep + commando's + goud/tijd; opent de schermen hieronder
│   ├── ui/menu_screen.gd    Basis voor een menuscherm (venster, Terug-knop, hulpregel)
│   ├── ui/items_screen.gd   Items · ui/status_screen.gd Status · ui/magic_screen.gd Magie
│   ├── ui/options_screen.gd Opties · ui/save_prompt.gd 'Voortgang opslaan?' · ui/bestiary_screen.gd
│   ├── ui/party_card.gd     Kaartje van een held (naam, Lv, HP/MP-balken)
│   ├── ui/target_list.gd    Doelkeuze (op wie?) voor items en spreuken
│   ├── ui/glitch_noise.gd   Pixel-ruis in tekstvakken (gecachet)
│   ├── ui/title_tab.gd      Titel-tabje boven een venster
│   ├── ui/ui_style.gd       UiStyle: kleuren van de v7-UI (magenta, cyaan, grijzen)
│   ├── ui/blink_arrow.gd    Knipperend neon-pijltje in tekstvakken
│   ├── data/
│   │   └── game_data.gd     ★ ALLE GETALLEN: helden, vijanden, spreuken, items, encounter-kans per terrein
│   ├── battle/
│   │   ├── battle.gd        Gevechtslogica (beurten, schade, winst/verlies) + opstelling op het scherm
│   │   ├── battle_menu.gd   Lijstmenu dat werkt met tikken én D-pad/toetsen
│   │   ├── battle_hero.gd   Eén held op het slagveld: poses, stapje naar voren, flits, KO
│   │   ├── hero_status_box.gd  Statusvak per held: naam, HP/MP-balken, getallen (tekent zichzelf)
│   │   ├── hd_ui.gd         HdUi: vensters met fijne (1-pixel) randen op het 2x-raster
│   │   └── target_cursor.gd Geel doel-pijltje boven vijand of held
│   ├── player.gd            Grid-beweging, loopanimatie, botsing, praten, "bump" (tegen iets aan lopen)
│   ├── npc.gd               NPC draait naar je toe en praat
│   ├── sign.gd              Bordje met tekst
│   ├── dialog_box.gd        Tekstvak met typemachine-effect:  Dialog.show_lines([...], "Naam")
│   ├── touch_controls.gd    Touch → zelfde input actions als het toetsenbord (multi-touch, A en B)
│   └── debug_autotest.gd    Alleen voor testen (zie onderaan)
└── tools/                   Hulpmiddelen, niet nodig om te spelen
    ├── generate_art.py      Python-script dat alle plaatjes tekent volgens docs/ARTSTYLE.md
    ├── art_maps.py          Deel daarvan: dorp-tiles, huis, wereldkaart-tiles
    ├── art_v8_heroes.py     v8: helden (10 frames van 210x210, incl. adem-frames)
    ├── art_v8_enemies.py    v8: Papiergeest (verfrommeld papier) en Kennis-Beest (meer boek-detail)
    ├── art_v8_maps.py       v8: dorp, huis, wereldkaart, speler/NPC en icoon in bibliotheek-stijl
    ├── handwerk.txt         Handgemaakte art die generate_art.py NIET overschrijft
    ├── make_tile_templates.py  Sjablonen (4x, met nummers en solid) voor de art director
    ├── art_battle.py        Deel daarvan: '16-bit plus' helden, vijanden en HD-vensters
    │                        (kleine 3D-belichting per vorm, afgerond naar ramps van 6 tinten)
    ├── art_battle_bg.py     Deel daarvan: '16-bit plus' bos- en vlakte-achtergrond (1280x432)
    ├── generate_font.py     Python-script dat het lettertype Dauwpixel maakt
    ├── build_maps.gd        Bouwt dorp.tres, wereld.tres, wilgendal.tscn en wereldkaart.tscn
    │                        opnieuw uit tekst-maps (met automatische randjes en kust)
    └── build_maps.tscn
```

### Belangrijke instellingen (Project → Project Settings)

- Resolutie **384x216** (16:9, ongeveer SNES-formaat) → 24 x 13,5 tiles op het scherm.
  Op de PC wordt het venster 1152x648 (3x zo groot).
- Stretch mode **viewport** + aspect **expand**: alles wordt pixel-perfect opgeschaald;
  op een brede telefoon zie je iets meer van de map in plaats van zwarte balken.
- **Gevechten** renderen op **768x432** (2x zo fijn, zie `DETAIL` in `scripts/battle/battle.gd`);
  de gevechtsscène staat op schaal 2, dus alle posities in het gevecht zijn nog steeds in 384x216.
  Bij het verlaten van het gevecht wordt het weer 384x216.
- Texture filter **Nearest** (scherpe pixels), renderer **Mobile**, oriëntatie **liggend** (landscape, draait mee).
- Input actions: `move_up`, `move_down`, `move_left`, `move_right`, `interact` (A), `cancel` (B),
  `debug_battle` (F2).
- Autoloads (altijd aanwezig, in elk script te gebruiken): `GameState`, `Transition`, `Dialog`,
  `Crt` en `Settings` (opties, `scripts/settings.gd`).

---

## 3. Hoe werkt het (kort)

- **Map**: elke map (bv. `scenes/maps/wilgendal.tscn`) heeft een node **Ground** (een `TileMapLayer`).
  Klik hem aan en kies onderaan het tabblad **TileMap** om zelf te schilderen. Boom/heg/water/berg/
  zee blokkeren automatisch, omdat in de TileSet (`dorp.tres`, `wereld.tres`) op die tiles een
  collision-vorm staat. Hoe maps aan elkaar vastzitten staat in hoofdstuk 4.
- **Speler** (`player.gd`): kijkt eerst met `test_move()` of de volgende tile vrij is. Zo ja,
  dan schuift hij in 0,25 sec precies 16 px op. Ingedrukt houden = doorlopen zonder haperen.
- **Praten**: de speler kijkt welk object op de tile vóór hem staat en roept daar `interact()` aan.
  Elk object met een `interact()`-functie kan dus praten (NPC, bordje, kist, deur...).
  Loopt de speler tegen een object aan, dan roept hij `bump()` aan (als dat bestaat). Zo werkt de deur.
- **Tekst aanpassen**: klik in `wilgendal.tscn` op **OldMan**, **Sign** of **Door** en wijzig *Lines* in de Inspector.
- **Touch**: `touch_controls.gd` roept `Input.action_press()` / `action_release()` aan,
  dus de rest van het spel weet niet of je een toets of het scherm gebruikt.

### Plaatjes vervangen
Teken je eigen tiles en sprites (bijv. in **Aseprite**, **LibreSprite** of **Piskel**) in precies
dezelfde indeling en overschrijf de PNG's. Godot laadt ze dan automatisch opnieuw. Volg daarbij de
regels en het palet uit **`docs/ARTSTYLE.md`** (zie de checklist onderaan), dan past alles bij elkaar.
De maten:
- tiles: 16x16
- speler en NPC: frames van 16x24 (sheet 48x96)
- vijanden: 48x48
- gevechtssprites van helden: strook van 256x32 (8 frames van 32x32, voeten op x=16, y=30).
  Welk plaatje bij welke held hoort staat in `game_data.gd` bij `"battle_sprite"`.

Alles opnieuw genereren kan met `python3 tools/generate_art.py` (vereist `pip install pillow`).
Het lettertype maak je opnieuw met `python3 tools/generate_font.py` (vereist `pip install fonttools`).

### Maps uit tekst opnieuw bouwen (optioneel)
In `tools/build_maps.gd` staan het dorp en de wereldkaart als tekst:
- dorp: `#` = kassei, `T` = boom, `o` = heg, `h` = huis, …
- wereldkaart: `~` = zee, `^` = berg, `T` = bos, `HH` = stad, `D` = trap, …

Open `tools/build_maps.tscn` en druk op **F6**. Dat **overschrijft** de twee maps en hun TileSets.
Het script kiest daarbij automatisch de **randjes**:
- kassei en pad krijgen een grasrand naar het gras toe
- onder bomen en heggen valt schaduw
- de zee krijgt een kust met schuim
- bergen en bos sluiten op elkaar aan

Handig om snel te schetsen. Daarna kun je verder schilderen in de editor, maar daar worden de
randjes niet automatisch gekozen.

---

## 4. Maps en overgangen (dorp ↔ wereldkaart)

### Hoe het werkt
Elke map is een eigen scène in `scenes/maps/`. Een map heeft altijd dezelfde opbouw, met het
script `scripts/map.gd` op de bovenste node:

| Node        | Wat                                                                    |
|-------------|------------------------------------------------------------------------|
| `Ground`    | `TileMapLayer` met de grond. Elke tile heeft een **terrain**-woord (zie hieronder) |
| `Gebouwen`  | (optioneel) `TileMapLayer` boven de grond, bv. het huis                 |
| `Objects`   | Speler (**moet `Player` heten**), NPC's, bordjes, deuren. *Y Sort* staat aan |
| `Spawns`    | **MapSpawn**-punten: hier kom je binnen. De **naam** van de node telt (bv. `zuid_ingang`), plus *Facing* (kijkrichting) |
| `Exits`     | **MapExit**-zones: stap je erop, dan ga je naar een andere map           |
| `TouchControls` | De touch-knoppen                                                    |

Op de root-node van de map staan twee instellingen in de Inspector:
- **Map Name**: alleen ter info
- **Encounters**: monsters aan of uit. In Wilgendal staat dit **uit**, op de wereldkaart **aan**.

Een **MapExit** (`scripts/map_exit.gd`) heeft in de Inspector:
- **Size Tiles**: hoe groot de zone is, in tiles. De positie van de node is de linkerbovenhoek
  (een veelvoud van 16). In de editor zie je de zone als een roze vlak.
- **Target Map**: naar welke `.tscn`
- **Target Spawn**: de naam van het spawnpunt in die map
- **Lines**: laat je Target Map leeg en vul je Lines in, dan verschijnt er alleen een tekst.
  Zo werkt de trap: "Een trap leidt naar beneden... (dungeon komt later)".

Wat er gebeurt als je op een uitgang stapt:
1. `map.gd` ziet bij elk `stepped`-signaal van de speler of die tile in een MapExit ligt.
   Uitgangen gaan altijd vóór een gevecht.
2. `GameState.change_map(map, spawn)` onthoudt het spawnpunt, fadet naar zwart (`Transition`)
   en laadt de nieuwe scène.
3. De nieuwe map (`map.gd` → `_ready`) zet de speler op het spawnpunt met die naam,
   in de goede kijkrichting, en fadet weer in.

Bij een **gevecht** onthoudt `GameState` de map (`return_map`), de tile en de kijkrichting.
Na het gevecht laadt hij die map weer en zet de speler terug op precies die tile.
Bij **GAME OVER** ga je naar `GameState.START_MAP` (Wilgendal), spawnpunt `start`.

De huidige verbindingen:
- Wilgendal, uitgang `NaarWereld`: het kasseienpad aan de zuidrand (3 tiles breed).
  Die gaat naar de wereldkaart, spawnpunt `van_dorp`, net onder het stad-icoon.
- Wereldkaart, uitgang `NaarWachtershuis` (v0.13, was `NaarWilgendal`): het Wachtershuis-icoon op
  (14,30)-(15,30). Die gaat naar `wilgendal.tscn` ('Huis aan de bosrand'), spawnpunt `zuid_ingang`.
- Wereldkaart, uitgang `NaarWilgendal` (v0.13): het nieuwe dorp Wilgendal (2x2 icoon op (30,23)-(31,24)).
  Doel `scenes/maps/dorp_wilgendal.tscn`; zolang die scène niet bestaat zegt hij 'Wilgendal (komt later)'.
  Terug uit het dorp: spawn `van_wilgendal` op (30,25).
- Wereldkaart, uitgang `Trap` (v0.13): de ingang van De Vergeten Archieven (eerste dungeonkamer);
  terug kom je op spawn `van_archief`, net boven de trap.

### Random encounters per terrein
Elke tile in de TileSets heeft custom data **`terrain`**:
- wereldkaart: `gras`, `hoog_gras`, `zand`, `bos`, `berg`, `zee`, `stad`, `trap`
- dorp: `gras`, `kassei`, `pad`, `heg`, …

Je ziet het in de editor: open de TileSet, kies een tile en kijk onder *Custom Data*.
De kansen staan in **`scripts/data/game_data.gd` → `ENCOUNTER_RATES`**:
```
const ENCOUNTER_RATES := {"gras": 0.06, "hoog_gras": 0.07, "zand": 0.06, "bos": 0.10}
```
- Een terrein dat daar niet in staat (kassei, stad, trap, …) geeft nooit een gevecht.
- Een map met *Encounters* uit (het dorp) geeft sowieso nooit een gevecht.
- Welke gevechtsachtergrond bij welk terrein hoort, staat in `BATTLE_BACKDROPS`.

### Zelf een nieuw dorp (of andere map) maken – stap voor stap
1. **Kopiëren**: klik in het FileSystem-paneel met rechts op `scenes/maps/wilgendal.tscn` →
   **Duplicate…** → bv. `scenes/maps/beekdorp.tscn`. Open hem en geef de bovenste node een eigen naam.
2. **Schilderen**: klik op **Ground** en schilder je dorp met de tiles uit `dorp.tres`.
   Huizen zet je op de laag **Gebouwen**: kies daar in de TileSet het huis (5x5) en schilder het blok.
   Verplaats ook de **Door** naar de deur van je huis.
3. **Monsters**: zet op de root-node *Encounters* uit (dorp) of aan (veld, dungeon).
4. **Spawnpunt**: geef de MapSpawn onder `Spawns` een naam (bv. `ingang`) en zet hem op de tile
   waar je binnenkomt. Stel *Facing* in.
5. **Uitgang terug**: zet een MapExit onder `Exits` op de rand van je dorp, met
   - *Target Map* = `res://scenes/maps/wereldkaart.tscn`
   - *Target Spawn* = een spawnpunt op de wereldkaart. Maak er daar een bij, bv. `van_beekdorp`.
6. **Op de wereldkaart**: schilder een stad-icoon (tiles 113 + 114 in `wereld.tres`). Zet er een
   MapExit op met *Target Map* = jouw dorp en *Target Spawn* = `ingang`. Zet naast het icoon een
   MapSpawn `van_beekdorp` op een tile waar je kunt staan.
7. Druk op **F5** en loop erheen. Tip: wil je meteen in je nieuwe dorp beginnen, verander dan
   tijdelijk `START_MAP` in `scripts/game_state.gd`. De startscène van het project staat in
   Project Settings → *Application → Run → Main Scene*.

Een **binnenkamer** (een huis in) werkt precies zo: een kleine map met *Encounters* uit, en
een MapExit op de deur in plaats van de Door. Die MapExit gaat naar de kamer, en een MapExit
in de kamer gaat terug naar een spawnpunt vóór de deur.

---

## 5. Gevechten (Lufia 2-stijl)

### Hoe het werkt
1. **Random encounter** – `map.gd` luistert naar het signaal `stepped` van de speler.
   Bij elke stap op de wereldkaart is er een kans op een gevecht, afhankelijk van het terrein
   (gras 6%, bos 10%, zie `ENCOUNTER_RATES`). In het dorp nooit.
   Na een gevecht (en bij de start) heb je eerst 6 **veilige stappen** op terrein met monsters.
2. **Overgang** – `GameState` onthoudt de map, jouw tile en kijkrichting, `Transition` laat het scherm
   twee keer flitsen en fadet naar zwart, daarna wordt `scenes/battle/battle.tscn` geladen.
3. **Commando's kiezen** – zoals in Lufia 2 kies je eerst voor **alle** helden een actie:
   - **Aanval** → kies een vijand
   - **Magie** → kies een spreuk (kost MP) en een doel (Dennis kan geen magie, die regel is grijs)
   - **Item** → kies een item (aantal staat erachter) en een held
   - **Verdedig** → deze ronde halve schade
   - **Vluchten** → de hele party probeert meteen te vluchten (kans hangt af van AGI)
   Met **B** ga je een stap terug (submenu → commandomenu → vorige held).
4. **Ronde** – de vijanden kiezen een willekeurige held. Daarna is iedereen aan de beurt
   in volgorde van **AGI** (snelheid, met een beetje geluk). Je ziet berichten bovenin.
   Helden stappen naar voren en halen uit, vijanden springen naar hun doel.
   Schadegetallen verschijnen boven het hoofd, geraakte helden flitsen en hun statusvak kleurt
   even rood. Daarna zakt de balk.
   Houd **A** ingedrukt om de berichten sneller te laten gaan.
5. **Einde**
   - **Winst**: alle levende helden krijgen alle EXP, de party krijgt het goud.
     Dit staat in het overwinningsvenster, samen met per held "VOLG. LEVEL" (de EXP die nog nodig is).
     Genoeg EXP = **level-up** (stats stijgen volgens `growth`), daarna een pagina per held. KO-helden staan op met 1 HP.
   - **Vluchten gelukt**: terug naar dezelfde plek.
   - **Alle helden KO**: GAME OVER → je begint weer in Wilgendal voor het huis, volledig genezen,
     maar met de helft van je goud.

### Schadeformules (in `scripts/battle/battle.gd`)
- Aanval: `ATK - DEF/2`, ±15% geluk, minimaal 1. Verdedigen = halve schade.
- Spreuk: `power + 2 × level`, ±10%.
- Vluchten: kans `50% + (gem. AGI party − gem. AGI vijanden) × 4%`, tussen 10% en 95%.

### Zelf aanpassen – alles staat in `scripts/data/game_data.gd`
| Wat                         | Waar in `game_data.gd`                 |
|-----------------------------|----------------------------------------|
| Helden (stats, spreuken, groei per level) | `HEROES`                 |
| Benodigde EXP per level     | functie `exp_for_level()`              |
| Vijanden (stats, EXP, goud, plaatje, speciale aanval) | `ENEMIES`    |
| Spreuken (MP-kosten, kracht, doel)        | `SPELLS`                 |
| Items en startinventaris    | `ITEMS`, `START_INVENTORY`             |
| Kans op gevecht per stap, per terrein | `ENCOUNTER_RATES` (0.06 = 6%) |
| Veilige stappen na gevecht  | `SAFE_STEPS`                           |
| Gevechtsachtergrond per terrein | `BATTLE_BACKDROPS`, `DEFAULT_BACKDROP` |
| Welke groepen vijanden (en hoe vaak) | `ENCOUNTER_GROUPS`            |

Voorbeelden:
- Nieuwe vijand: teken een PNG van 48x48 in `assets/sprites/enemies/`, voeg een blok toe aan
  `ENEMIES` en zet de id in een groep in `ENCOUNTER_GROUPS`.
- Nieuwe spreuk: voeg toe aan `SPELLS` (`target` = `"enemy"`, `"all_enemies"` of `"ally"`,
  `type` = `"damage"` of `"heal"`) en zet de id in de `"spells"`-lijst van een held.
- Geen gevechten tijdens het testen: zet in `scripts/game_state.gd` `encounter_multiplier` op `0.0`
  (met F2 kun je er op de wereldkaart toch één starten). Op `2.0` krijg je twee keer zo vaak gevechten.
- Het gevecht los testen: open `scenes/battle/battle.tscn` en druk op **F6** (kiest een willekeurige groep).

Let op: houd heldennamen op maximaal 5 letters en itemnamen kort, anders past het niet in de
vensters op 384x216.

### Het gevechtsscherm aanpassen (in `scripts/battle/battle.gd`, bovenaan)
- `HERO_SLOTS`: waar de voeten van held 1-4 staan (schuin, twee rijen).
- `ENEMY_SLOTS`: waar de vijanden staan, per aantal (1-4).
- `DETAIL`: 2 = het gevecht rendert 2x zo fijn ('16-bit plus'). Zet je dit op 1, dan werkt alles
  nog, maar de fijne art wordt dan grover getoond.
- Eigen gevechts-art: teken helden in frames van 80x80 (voeten op 40,77) en vijanden 2x zo groot
  als je ze op het scherm wilt hebben: vijanden worden altijd op de helft getoond.
- De statusvakken worden automatisch verdeeld over de ruimte tussen de D-pad en de B-knop.
  Bij 3 helden zijn ze 71 px breed, bij 4 helden 52 px.
- Een 4e held toevoegen: zet een extra blok in `HEROES` (met een eigen `battle_sprite`). Zonder
  eigen plaatje gebruikt het spel dat van Dennis.

---

## 6. Volgende stappen (suggesties)

1. **Dialogen & NPC's uitbreiden**
   - NPC's die rondlopen (gebruik dezelfde grid-code als de speler, met een timer).
   - Keuzes ("Ja / Nee") in het tekstvak, en een autoload `GameState.gd` met vlaggen
     (bv. `GameState.flags["oude_man_gesproken"] = true`) zodat NPC's iets anders zeggen.
2. **Menu** (zoals Lufia's ring-menu of een simpel lijstmenu)
   - Een `CanvasLayer` met `Control`-nodes: Items, Uitrusting, Status, Opslaan.
   - Voeg een actie `menu` toe (bv. Esc/X en een B-knop op het scherm).
3. **Gevechten uitbreiden**
   - Een herberg (NPC die je party geneest voor goud), een winkel voor Drankjes.
   - Spreuken/items die KO-helden weer tot leven wekken, statuseffecten (gif, slaap).
   - Lufia 2 heeft in dungeons zichtbare vijanden die **alleen bewegen als jij een stap zet**:
     koppel dat ook aan het signaal `stepped` van de speler.
   - Opslaan van `GameState.party` / `inventory` / `gold` (zie punt 6).
4. **Lufia-achtige dungeonpuzzels**
   - De **trap** op de wereldkaart is de plek voor de eerste dungeon: maak een map met
     *Encounters* aan en geef de MapExit `Trap` een *Target Map* (hoofdstuk 4).
   - Duwbare rotsblokken: een `CharacterBody2D` die 1 tile opschuift als de speler ertegenaan loopt
     (check vooraf met `test_move`, gebruik `bump()` net als de deur).
   - Schakelaars op de grond, deuren die opengaan, kamers die resetten als je ze verlaat.
   - Gereedschap zoals Lufia 2: pijl & boog (schakelaar op afstand), hookshot, bommen.
5. **Meer maps**: een binnenkamer voor het huis, meer dorpen. Zie hoofdstuk 4 (MapExit + MapSpawn).
6. **Opslaan/laden** van `GameState` met `FileAccess` + `JSON` in `user://`.
7. **Geluid**: `AudioStreamPlayer` voor muziek en een "blip" per letter in het tekstvak.

---

## 7. Exporteren naar Android (kort)

1. Installeer **OpenJDK 17** en de **Android SDK** (makkelijkst via Android Studio).
2. Godot: **Editor → Editor Settings → Export → Android**: vul het pad naar de *Java SDK* en
   *Android SDK* in. (Een debug-keystore maakt Godot meestal zelf aan.)
3. **Editor → Manage Export Templates → Download and Install** (eenmalig, moet dezelfde versie zijn als je Godot).
4. **Project → Export… → Add… → Android**. Laat *Gradle Build* uit voor een simpele APK.
   ETC2/ASTC-textures staan al aan in dit project.
5. Zet op je telefoon **Ontwikkelaarsopties → USB-foutopsporing** aan, sluit hem aan en klik op
   het **Android-icoontje** rechtsboven in de editor (*Remote Deploy*) om direct op je telefoon te spelen.
   Of klik **Export Project** voor een `.apk`-bestand.
6. Voor de Google Play Store heb je later een *release*-keystore en een `.aab` (Gradle build) nodig.

**Klaar in dit project (v0.10):** `export_presets.cfg` bevat een preset **"Android"** en een preset
**"Android arm64"** (alleen arm64-v8a, kleiner; export naar `../rpg_prototype_v0.11_arm64.apk`):
- pakket `com.dennis.rpgprototype`, app-naam *SAPIENTIA* (tot v0.12: *RPG Prototype*), versie 0.13 (code 15)
- arm64-v8a + armeabi-v7a, liggend (`window/handheld/orientation` = sensor landscape), immersive
- officiële sjabloon-APK (geen Gradle): min SDK 21, target SDK 34. Een eigen min SDK (bv. 24) kan
  alleen met *Gradle Build*
- niet in de APK: `tools/`, `docs/`, `*.md`, `scripts/debug_autotest.gd` en `scripts/debug_menutest.gd` (`map.gd` kijkt eerst
  of de tester bestaat)
- **Renderer op telefoons: `gl_compatibility`** (OpenGL ES 3.0), via de override
  `rendering/renderer/rendering_method.mobile`. Op de desktop blijft het "mobile". Godot 4.3 heeft
  nog geen automatische terugval van Vulkan naar OpenGL, en voor 2D-pixelart ziet het er hetzelfde
  uit. Zo werkt het op de meeste toestellen.
- F2 (gevecht forceren) werkt alleen in debug-builds (`OS.is_debug_build()`): in een release-APK
  staat hij uit.

Exporteren zonder editor (sleutel via omgevingsvariabelen, zodat er geen wachtwoord in het project staat):

```
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/pad/naar/release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<wachtwoord>
godot --headless --path . --export-release "Android" ../rpg_prototype.apk
```

Let op: een update kun je alleen over de oude versie heen installeren als hij met **dezelfde
sleutel** is ondertekend. Bewaar de keystore dus goed.

---

## 8. Automatische test (voor ontwikkelaars)

```
godot --headless --path . -- --autotest
```
Laat de speler zelf spelen:
- **In het dorp**: start voor het huis, deur op slot, botsing met de heg, bordje, NPC, touch.
  Daarna meer dan 50 stappen met 100x de encounter-kans, zonder gevecht. Dan de uitgang naar
  de wereldkaart.
- **Op de wereldkaart**:
  - het spawnpunt
  - zee en berg blokkeren, bos en zand zijn begaanbaar
  - een encounter op gras met een volledig gevecht: een ronde met Aanval + Vuur + Drankje,
    terug met B, winst met EXP/level-up, terug op dezelfde tile, veilige stappen
  - tikken op menuknoppen en vijanden, vluchten (F2)
  - de trap-tekst, de bos-achtergrond in het bos
  - het stad-icoon terug het dorp in en weer uit
  - game over + respawn in het dorp
Daarnaast test hij het gevechtsscherm:
- of de balken gelijk zijn aan de echte HP/MP
- tikken op een heldensprite en op een statusvak
- de inhoud van het overwinningsvenster
- dat niets onder de D-pad/A/B ligt
- een gevecht met 4 helden
- '16-bit plus': het gevecht rendert op 768x432, de scène staat op schaal 2, de heldenframes zijn
  80x80 op schaal 0.5, de vijanden zijn 2x zo fijn, de HD-vensters zijn actief (alleen met een echt
  venster) en de overworld staat na het gevecht weer op 384x216

Hij print `PASS`/`FAIL` per check.

**Veldmenu-test** (los, sneller):
```
godot --headless --path . -- --menutest
godot --path . -- --menutest --shots=/pad/naar/map     (met venster: screenshots 384x216 + 3x)
```
Opent het menu en loopt alle schermen door met gesimuleerde knoppen en tikken: Drankje op een
gewonde held (HP, begrenzing, aantal), Toverwater, grijze items, Status (EXP-formule, wisselen
van held, level-up), Genees buiten het gevecht, Bestiarium, Opties (tekstsnelheid, touch,
volume, CRT, autosave; `settings.cfg` geschreven en opnieuw ingelezen), Opslaan via het menu,
menu dicht = speler los, niet openen tijdens tekstvak/mapwissel, en automatisch opslaan (na
mapwissel, na winst, app naar achtergrond; niet tijdens gevecht/mapwissel/tekstvak of als het
uit staat; 'Doorgaan' laadt de nieuwste; kapotte/onvolledige saves laden zonder crash).
Beide tests gebruiken eigen bestanden (`user://autotest_*`), je echte save en opties blijven heel.

Met een echt venster kun je ook screenshots maken:
`godot --path . -- --autotest --screenshot=/tmp/shot.png --battle-shots=/tmp/battle --overview=/tmp/wereld.png`
(`--overview` tekent de hele wereldkaart in één plaatje van 960x720.)
Gevechts-screenshots worden op 1152x648 opgeslagen. Het fijne raster van 768x432 wordt daarbij
1,5x vergroot, dus niet elke pixel is even breed. Daarom komt er ook een `*_2x.png` bij: 1536x864,
precies 2x, met elke fijne pixel als 2x2.

---

## Licenties

- Alle plaatjes in `assets/` en `icon.png` zijn zelf gegenereerd met `tools/generate_art.py`
  (+ `tools/art_maps.py`, `tools/art_v7_*.py`, `tools/art_v8_*.py`; v6: `tools/art_battle.py`, `tools/art_battle_bg.py`) en vrij te gebruiken.
  De '16-bit plus' gevechts-art volgt alleen een stijlrichting (een AI-mockup die Dennis koos);
  er is niets van overgenomen. Het dorp en de wereldkaart volgen alleen de *stijl*
  van Lufia 2 (zie ARTSTYLE.md). Er is niets overgetekend.
- Het lettertype **Dauwpixel** is eigen werk (`tools/generate_font.py`) en ook vrij te gebruiken.
- **`docs/ref_*.png` zijn uitsneden uit een YouTube-video van Lufia 2.** Ze zijn alleen intern
  referentiemateriaal voor de stijlgids. **Niet meeleveren, niet publiceren en niet in het spel
  gebruiken.** De map `docs/` heeft een `.gdignore`, dus Godot importeert en exporteert hem niet.
  Haal die bestanden weg voordat je het project ooit openbaar deelt.
- Lufia is een merk van de respectievelijke eigenaren. Het spel zelf (`assets/`, `scenes/`,
  `scripts/`) bevat geen materiaal uit Lufia.
