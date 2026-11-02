# Edge-cases: dialogen, quests, warps en opslaan (WM1)

Branch `claude-trial/r7-3-edgecases`, basis `93d9737`. **Alleen een rapport, geen fixes.**
Scope: tekstvak (`scripts/dialog_box.gd`), verhaal-motor (`scripts/story.gd` + `scripts/data/story_data.gd`),
Quest Log (`scripts/data/quest_data.gd` + `data/quests.json`), mapwissels/warps (`scripts/map.gd`,
`GameState.change_map`, veldmenu-Warp, World Warper `world_warper/warp/`) en save/load/checkpoint
(`scripts/game_state.gd`). SoM-proef, co-op en WM2 vallen erbuiten.

## Hoe geverifieerd

- Code gelezen (regelnummers hieronder gelden voor `93d9737`).
- Twee losse proefscripts (buiten de repo, niet toegevoegd; `--script`, SceneTree) die `Story.after_battle_event`
  zetten en `GameState.end_battle(...)` aanroepen, daarna de map laten laden. Gevallen met **[proef]** zijn zo bevestigd.
- Een los Python-scriptje (buiten de repo) dat in alle 103 `.tscn`-bestanden elke uitgang met `target_map`
  naloopt: bestaat de doel-scène en het spawnpunt? Plus de drie World Warper-bestemmingen.
- Referentie-suites: `-- --savehardeningtest` → `RESULT OK (127 goed, 0 fouten)`;
  `-- --questtest` met `--rendering-driver opengl3` → `RESULT OK (63 goed, 0 fouten)`
  (met `--headless` faalt alleen `basisresolutie 384x216`: dat komt door de omgeving, niet door de code).
- Bij het afronden kort nagelopen (zelfde basis): #3 (`OUDE_NAMEN` op `game_state.gd:1679`, `migrate_name` op
  `:1681-1682`, aangeroepen op `:1661` en `:1839`, zonder versiecheck) en #5 (`open_warp` op
  `field_menu.gd:451-474` kijkt alleen naar `hub_present()` en `world_warper_is_unlocked()`). Beide kloppen.
  De bestaande test `party_tests.gd:830` legt vast dat `migrate_name("Dennis") == "Dax"`; die mag blijven, want
  de fix voor #3 hoort bij de aanroep (alleen oude saves migreren), niet in de functie zelf.

## Overzicht

| # | geval | gebied | ernst | getest? |
|---|---|---|---|---|
| 1 | Vluchten uit het Zingend-Zaad-gevecht geeft toch het zaad (en de quest-stap) | dialoog/quest | **hoog** | **[proef]** |
| 2 | Verliezen zonder checkpoint: het "na het gevecht"-event loopt toch | dialoog/quest | **hoog** | **[proef]** |
| 3 | Speler die zichzelf "Dennis", "Lotte" of "Noor" noemt heet na laden/game over anders | save | **midden** | nee |
| 4 | Een tweede `Dialog.show_lines` overschrijft een open tekstvak of keuze | dialoog | midden | nee |
| 5 | Warp uit het veldmenu werkt overal, ook midden in een Diepe Grot-run | warp | midden | nee |
| 6 | `event_finished` meldt alleen het laatste event van een keten | quest | laag | nee |
| 7 | `_run_later` laat een event stil vallen | dialoog | laag | nee |
| 8 | Achtergrond-autosave in het gat van 0,35 s vóór een verhaal-event | save | laag | nee |
| 9 | Uitgang vergrendelt de speler vóór `change_map`, dat kan weigeren; ontbrekende scène = zwart scherm | warp | laag | scan |
| 10 | Spawnpunt ontbreekt: alleen een waarschuwing, speler op de standaardplek | warp | laag | scan |
| 11 | Spreker met dezelfde naam als de speler: ballon wijst naar de speler | dialoog | laag | nee |
| 12 | Respawn op checkpoint zet ook Scènes/muziek-"gezien" terug | save | laag | nee |
| 13 | `_continue_record` zet `active_slot` al vóór het laden lukt | save | laag | nee |
| 14 | Eén autosave voor alle slots | save | laag (ontwerp) | nee |
| 15 | Act 2: alle hoofdopdrachten tegelijk "actief" (ook Seren, Genezer, Warper) | quest | laag (ontwerpvraag) | nee |
| 16 | Wat wél klopt (uitgangen/spawns, atomisch opslaan, opgesloten-timer, enz.) | alle | ok | ja |

---

## 1. Vluchten uit het Zingend-Zaad-gevecht geeft toch het zaad — **hoog** [proef]

- **Waar:** `scripts/story.gd:314` (zet `after_battle_event`), `scripts/story.gd:380-384` (`map_ready` voert hem
  uit), `scripts/game_state.gd:2458-2521` (`end_battle`: wist hem nergens), `scripts/battle/battle.gd:833-836`
  (vluchten). Data: `scripts/data/story_data.gd:670-681`.
- **Scenario:** zijopdracht Het Zingende Graan aangenomen, naar het zaad in het woud. Het event `zingend_zaad`
  start `["battle", ["woudgeest","woudgeest"], {"after": "zingend_zaad_na"}]`. Het is geen baas en geen tutorial,
  dus "Flee" kan (`battle.gd:933`). Speler vlucht.
- **Verwacht:** geen zaad; het zaad-object blijft staan, opnieuw proberen.
- **Werkelijk:** terug op de kaart draait `map_ready` het `after`-event gewoon (`not GameState.in_battle` is waar).
  `zingend_zaad_na` geeft het item en zet de vlag `zingend_zaad`. De quest-stap "zaad" staat op klaar.
  Proef: `zaad=1 flag=true last=flee`, quest `{"steps": ["aannemen","zaad"], "done": false}`.
- **Voorgestelde fix:** in `GameState.end_battle` bij `result != "win"` het `Story.after_battle_event` wissen
  (of: Story onthoudt bij `"battle"` ook een `after_lose`/`after_flee` en `map_ready` kijkt naar
  `GameState.last_battle_result`). Liefst één plek: Story luistert al op `battle_ended`-signaal → daar wissen
  als het resultaat geen `"win"` is. Test erbij: flee → geen item, geen vlag.

## 2. Verliezen zonder checkpoint: het "na het gevecht"-event loopt toch — **hoog** [proef]

- **Waar:** `scripts/game_state.gd:2487-2489` → `respawn()` `game_state.gd:2605-2617`; zelfde oorzaak als #1.
- **Scenario:** zelfde gevecht als #1, maar de party gaat KO terwijl er geen bruikbaar kamer-checkpoint is
  (`has_checkpoint()` onwaar, bv. checkpoint-map bestaat niet meer, of een map met `sets_checkpoint = false`).
- **Verwacht:** game over, terug in het dorp, geen zaad.
- **Werkelijk:** `respawn()` reset `Story` niet (alleen `respawn_at_checkpoint` doet dat via `apply_state` →
  `Story.reset(true)`). In `wilgendal.tscn` loopt `zingend_zaad_na` alsnog: proef `zaad=1 flag=true last=lose`.
- **Ernst:** hoog omdat het dezelfde quest overslaat; in de praktijk zeldzamer dan #1 (meestal is er een checkpoint).
- **Voorgestelde fix:** valt mee met de fix van #1 (wissen bij elk resultaat dat geen `"win"` is).

## 3. Speler met de naam "Dennis", "Lotte" of "Noor" heet na laden anders — **midden**

- **Waar:** `scripts/game_state.gd:1839` (`player_name = migrate_name(...)`), `game_state.gd:1660-1661`
  (heldnaam), `game_state.gd:1679-1682` (`OUDE_NAMEN`). Ook via `respawn_at_checkpoint` (`game_state.gd:2554`
  roept `apply_state` aan).
- **Scenario:** nieuw spel, naam "Dennis" (of "Noor", "Lotte"; `NAME_MAX` = 10 laat dat toe). Opslaan en laden,
  of game over met checkpoint.
- **Verwacht:** de held heet "Dennis".
- **Werkelijk:** de v0.23-namenmigratie maakt er "Dax" (resp. "Vesper", "Seren") van, bij elke load en zelfs midden
  in de sessie na een game over. De speler ziet zijn gekozen naam verdwijnen.
- **Voorgestelde fix:** alleen migreren als de save van vóór v0.23 is: een sleutel `"names_v23": true` meeschrijven
  in `state_data` en `migrate_name` alleen toepassen als die ontbreekt (zelfde patroon als `CODEX_SYNC_KEY`).
  Een test: nieuw spel "Dennis" → save → load → nog steeds "Dennis"; oude save zonder sleutel → "Dax".

## 4. Een tweede `Dialog.show_lines` overschrijft een open tekstvak of keuze — **midden**

- **Waar:** `scripts/dialog_box.gd:133-153` (geen wachtrij: `_lines` wordt vervangen), `dialog_box.gd:162-171`
  (`ask` geeft `choice_result` = -1 terug als het vak zonder keuze sluit), `scripts/story.gd:233-240`
  (`"say"`/`"choice"` wachten op hetzelfde `finished`-signaal), `scripts/map.gd:154-157` (`_show_respawn_msg`
  kijkt niet naar `Dialog.is_open` of `Story.running`).
- **Scenario:** er staat een verhaalzin of een keuze open, en iets anders roept `Dialog.show_lines` aan
  (de respawn-melding na 0,5 s terwijl een MAP_ENTER-event om 0,35 s al praat; een uitgang met `lines`; een
  ander script).
- **Verwacht:** de tweede tekst wacht tot de eerste klaar is (of wordt overgeslagen).
- **Werkelijk:** de verhaalzinnen verdwijnen; het verhaal gaat verder zodra de *vreemde* tekst sluit. Bij een
  keuze worden de keuzes gewist en geeft `ask` -1 → `"choice"` geeft `""` → het event stopt zonder vervolg.
  Ergste geval in WM1: de proloog-keuze "Stay / Follow Grandpa" (`story_data.gd:417-418`): het event stopt,
  de deur blijft op slot (`locked:HuisDeur`) en de timer komt pas terug na opnieuw binnenkomen (laden).
  Een concreet pad naar deze botsing is in WM1 niet gevonden; het risico zit in de bouw.
- **Voorgestelde fix:** `show_lines` negeren of in een kleine wachtrij zetten als `is_open` (behalve als dezelfde
  bron doorpraat); `_show_respawn_msg` laten wachten tot `Story.player_free()`. Bij `ask`: als de keuzes
  ongemerkt verdwijnen de standaardkeuze teruggeven in plaats van -1.

## 5. Warp uit het veldmenu werkt overal, ook midden in een Diepe Grot-run — **midden**

- **Waar:** `scripts/ui/field_menu.gd:451-474` (`open_warp`: alleen hub + unlock-vlag), `scripts/map.gd:184`
  (veldmenu op elke map), `scripts/game_state.gd:2318-2323` (`enter_map`: vangnet beëindigt de run).
- **Scenario:** World Warper is open (na De Genezer). Speler zit op verdieping 1 van De Diepe Grot (of in ECHO's
  Kamer, of halverwege een puzzelkamer) en tikt MENU > Warp.
- **Verwacht:** dezelfde regels als de Warper in de kerker: "niet op verdieping 1"
  (`game_state.gd:2845`), en zeker niet zonder te vragen. Of de Warp-knop is grijs in de 100-kerker.
- **Werkelijk:** meteen naar de hub. Het vangnet in `enter_map` breekt de run af (`dungeon100_end_run(true)`)
  zonder melding of bevestiging; `dungeon100_best` wordt niet bijgewerkt (dat doet `dungeon100_defeat` wel).
  Ook de ECHO-grot-regel (`EchoGrot.blokkeert_wereldkaart`, `map.gd:368`) geldt alleen voor uitgangen.
- **Voorgestelde fix:** in `open_warp` weigeren met een melding als `GameState.dungeon100_run_active()` of
  `dungeon100_floor > 0` (of eerst een Yes/No "End the run?"). Eventueel een lijst met maps waar Warpen dicht is
  (data in `release_flags.gd` of een eigen data-bestand), en de knop dan grijs tonen.

## 6. `event_finished` meldt alleen het laatste event van een keten — laag

- **Waar:** `scripts/story.gd:161-174` (`done := current_event` na de lus), `story.gd:303-309` (`"run"` zet
  `current_event` niet), `scripts/game_state.gd:1054` → `QuestData.on_event` `quest_data.gd:247-262`.
- **Scenario:** een quest-stap met `"event": X`, waarbij X via `"jump"`/`"choice"` doorgaat naar Y, of via
  `"run"` wordt aangeroepen.
- **Verwacht:** de stap met event X wordt klaar.
- **Werkelijk:** alleen Y (het laatste event) wordt gemeld; X nooit. Nu geen echte bug: elke stap in
  `data/quests.json` met een `event` heeft ook een `flag` of `step` als vangnet, en de huidige quest-events zijn
  eindpunten. Een nieuwe quest zonder vangnet blijft wel op `[ ]` staan.
- **Voorgestelde fix:** in de lus van `run()` elk gestart event melden (`event_finished.emit(next)` per stap,
  of een apart signaal `event_started`), of in de questtest afdwingen dat elke `event`-stap een vangnet heeft.

## 7. `_run_later` laat een event stil vallen — laag

- **Waar:** `scripts/story.gd:393-406`, aangeroepen uit `map_ready` (`story.gd:380-390`).
- **Scenario:** na een gewonnen verhaalgevecht (bv. de zwaardles → `na_les`) loopt er binnen 0,35 s al een ander
  event (`running`), of de speler is al op een andere map.
- **Verwacht:** het event loopt alsnog zodra het kan.
- **Werkelijk:** `if not running: run(ev)`: anders is het weg; `after_battle_event` is al leeg. Bij `na_les`
  blijft de verhaalstap op LES staan (de les kan opnieuw, dus geen vastloper).
- **Voorgestelde fix:** bij `running` het event in `pending`-vorm bewaren (zoals `pending_unique_event`) en via
  `_process_pending` starten zodra `player_free()`.

## 8. Achtergrond-autosave in het gat van 0,35 s vóór een verhaal-event — laag

- **Waar:** `scripts/game_state.gd:1478-1491` (`can_autosave` kijkt naar `Story.running`),
  `scripts/story.gd:396-401` (`_run_later` wacht 0,35 s zónder `running`), `game_state.gd:1503-1517`.
- **Scenario:** verhaalgevecht gewonnen, terug op de kaart; binnen 0,35 s gaat de app naar de achtergrond
  (telefoon-melding).
- **Verwacht:** geen save tot het verhaal-event klaar is.
- **Werkelijk:** de autosave schrijft de stand vóór het `after`-event (geen beloning, geen vlag). Na laden kan het
  gevecht opnieuw: geen verlies, wel dubbel werk. Zelfde gat bij de MAP_ENTER-events.
- **Voorgestelde fix:** `can_autosave` ook laten weigeren als `Story.after_battle_event != ""` of als er een
  `_run_later` wacht (een vlag `Story.waiting`).

## 9. Uitgang vergrendelt de speler vóór `change_map`, dat kan weigeren; ontbrekende scène = zwart scherm — laag

- **Waar:** `scripts/map.gd:371-372` (`player.input_locked = true` en dan `change_map`),
  `scripts/game_state.gd:2332-2336` (`change_map` stopt stil bij `changing_map`, `in_battle` of
  `ReleaseFlags.dev_scene_blocked`), `game_state.gd:901-906` (`_go_to_scene` controleert niet of de scène bestaat).
- **Scenario A:** een uitgang wijst naar een dev-kamer (`archief_test`/`kern_demo`) in een release-build.
  **Scenario B:** een uitgang wijst naar een scène die niet bestaat en heeft geen `lines`.
- **Verwacht:** A: melding, speler kan verder. B: melding of niets.
- **Werkelijk:** A: speler blijft vergrendeld staan (niemand zet `input_locked` terug). B: fade naar zwart,
  `change_scene_to_file` faalt, `changing_map` blijft `true` → zwart scherm, alleen herstarten helpt.
  De scan van alle `.tscn`-uitgangen vond **geen** huidig geval (alle doel-scènes bestaan); data-gedreven
  kamers (`dungeon_rooms.gd` e.d.) zijn niet gescand.
- **Voorgestelde fix:** `change_map` een `bool` laten teruggeven en `map.gd` alleen vergrendelen als het lukt;
  in `change_map` vooraf `ResourceLoader.exists(path)` controleren (anders `push_warning` en terug).

## 10. Spawnpunt ontbreekt: alleen een waarschuwing — laag

- **Waar:** `scripts/map.gd:59-70`.
- **Scenario:** `target_spawn` of een Story-`"map"`-spawn die niet in de doel-map staat (tikfout, hernoemde node).
- **Verwacht:** een veilige terugvalplek (eerste spawn of `return_tile`).
- **Werkelijk:** de speler staat waar de Player-node in de scène staat; het kamer-checkpoint wordt daar gezet
  (`_update_checkpoint`, `map.gd:146`). Ligt die plek op een uitgang of in een muur, dan pingpong of vastzitten.
  De scan vond in de `.tscn`-bestanden geen ontbrekende spawns; de drie World Warper-spawns (`van_dorp`,
  `zuid_ingang` ×2) bestaan. Scènes die hun spawns zelf bouwen (archief_ingang, woud_rand, leven_ingang) zijn
  zo niet te controleren.
- **Voorgestelde fix:** terugval op de eerste node onder `Spawns`; een test in een bestaande suite die alle
  `MapExit`-uitgangen + `SD.MAPS`-spawns tegen de geladen scène controleert.

## 11. Spreker met dezelfde naam als de speler: ballon wijst naar de speler — laag

- **Waar:** `scripts/dialog_box.gd:185-187`.
- **Scenario:** speler noemt zich "Old Man" (de spreker van Opa, `story_data.gd:136`; past binnen `NAME_MAX` 10).
- **Verwacht:** Opa's zinnen wijzen naar Opa.
- **Werkelijk:** de check "spreker == spelernaam" komt vóór het zoeken naar het NPC; alle Opa-zinnen wijzen naar de
  speler, en de naam-tab toont twee keer dezelfde naam.
- **Voorgestelde fix:** Story geeft voor `"{naam}"` een vaste sleutel door (bv. `speaker_is_player = true`) in plaats
  van op tekst te vergelijken; of NPC-namen bij de naamkeuze weigeren.

## 12. Respawn op checkpoint zet ook "gezien"-lijsten terug — laag

- **Waar:** `scripts/game_state.gd:2540-2569` (`respawn_at_checkpoint` → `apply_state`, `game_state.gd:1877-1890`).
- **Scenario:** in een kamer een cutscene zien (Scènes-menu) of een nieuwe track horen, daarna game over.
- **Verwacht:** wat je gezien/gehoord hebt blijft in het Scènes-/muziekmenu (zoals bestiarium en speeltijd).
- **Werkelijk:** `scenes_seen` en `heard_music` gaan terug naar de stand bij binnenkomst (alleen de huidige track
  komt terug). Omdat de verhaalvlaggen ook terugrollen speelt de scène meestal opnieuw, dus klein.
- **Voorgestelde fix:** `scenes_seen` en `heard_music` net als `bestiary` bewaren rond `apply_state`.

## 13. `_continue_record` zet `active_slot` vóór het laden lukt — laag

- **Waar:** `scripts/game_state.gd:2012-2016`.
- **Scenario:** speler kiest op het titelscherm een slot dat niet te laden is (corrupt, geen `.bak`), of tikt
  terwijl `changing_map` nog waar is.
- **Verwacht:** het actieve slot blijft wat het was.
- **Werkelijk:** `active_slot` is al omgezet. Bij een daarna gestart spel kiest het slotscherm opnieuw, dus meestal
  onschuldig; wel verwarrend bij een handmatige save zonder slotkeuze (`save_game` met `path == ""`).
- **Voorgestelde fix:** het slot pas zetten nadat `load_game` gelukt is (dat doet `apply_state` al via `"slot"`/`home_slot`).

## 14. Eén autosave voor alle slots — laag (ontwerp)

- **Waar:** `scripts/game_state.gd:1540-1543`, `game_state.gd:1307-1316`.
- **Scenario:** spelen in slot 1 (autosave bij de kerker), daarna slot 2 laden en spelen.
- **Verwacht:** de speler weet van welk slot de autosave is, of elk slot heeft een eigen autosave.
- **Werkelijk:** de autosave van slot 1 wordt overschreven door die van slot 2. Wie terug wil naar slot 1 heeft
  alleen de handmatige save. Waarschijnlijk zo bedoeld (apart autosave-slot), maar het staat nergens voor de speler.
- **Voorgestelde fix:** besluit Dennis: zo laten (en in het slotscherm "Autosave (slot 2)" tonen), of één autosave per slot.

## 15. Act 2: alle hoofdopdrachten tegelijk "actief" — laag (ontwerpvraag)

- **Waar:** `data/quests.json` (quests `seren`, `genezer`, `warper` zonder `start_flag`),
  `scripts/data/quest_data.gd:121-127` en `176-187`.
- **Scenario:** de Golem is verslagen, Act 2 gaat open.
- **Verwacht:** een opdracht verschijnt pas onder Active als de speler ervan weet (zoals bij de zijopdrachten
  met `start_flag`).
- **Werkelijk:** "Seren", "Genezer" en "Warper" staan meteen allemaal onder Active, met hun stappen (spoiler: dat
  Seren lid wordt, dat er een World Warper is), naast de Vesper-opdracht.
- **Voorgestelde fix:** vraag aan Dennis/lore: per opdracht een `start_flag` (bv. `archief2_keten` voor Seren,
  Archief 2 binnen voor de Genezer, `bewaker:...genezer` voor de Warper).

## 16. Wat wél klopt — ok

- **Uitgangen/spawns (.tscn):** alle 103 scènes gescand; elke uitgang met `target_map` wijst naar een bestaande
  scène, en elke `target_spawn` bestaat (behalve bij scènes die hun spawns in code bouwen, zie #10).
- **Opslaan is atomisch:** eerst `.tmp`, controle, oude goede save → `.bak`, dan `rename`
  (`game_state.gd:1558-1588`); een corrupte hoofd-save verdringt een goede `.bak` niet. `--savehardeningtest` OK.
- **Laden met kapotte velden:** `apply_state` valt per sleutel terug op standaardwaarden; onbekende quests/stappen
  vallen weg (`QuestData.van_save`); `leader_id` wordt bij gebruik gecontroleerd (`game_state.gd:193-199`).
- **Opgesloten in het huis:** de 2-s-timer (`"after"`) zit niet in de save, maar `MAP_ENTER` start
  `opgesloten_timer` opnieuw bij stap OPGESLOTEN (`story_data.gd:152`).
- **Game over mét checkpoint:** `apply_state` → `Story.reset(true)` wist `after_battle_event` en `scheduled`;
  quest-voortgang rolt netjes mee terug.
- **Archief 2 (Lotte):** vluchten zet `pending_story_loss`, de tijdelijke bondgenoot en het party-filter terug
  (`game_state.gd:1122-1133`).
- **Autosave-blokkades:** niet tijdens tekstvak, cutscene, gevecht of mapwissel (`game_state.gd:1478-1491`),
  niet tijdens een stap (`map.gd:232-235`). Zie #8 voor het ene gat.
- **World Warper:** bestemmingen alleen als bezocht (`destinations.gd:87-97`), reizen geweigerd tijdens gevecht
  of mapwissel (`warp_view.gd:362`), WM2/WM3 dicht.

## Volgorde voor fixes (voorstel)

1. #1 + #2 samen (één regel in `end_battle`/Story), met test in `--woudtest` of `--questtest`.
2. #3 (namenmigratie alleen voor oude saves), test in `--savehardeningtest`.
3. #5 (Warp in de 100-kerker), #4 (tekstvak-wachtrij).
4. De rest als ruimte is; #14 en #15 eerst als vraag aan Dennis.

## Dekking per onderwerp

| onderwerp | bevindingen | niet onderzocht (buiten budget) |
|---|---|---|
| dialogen | #4, #7, #11 | lange zinnen/regelafbreking in het tekstvak, snel doortikken tijdens het typen |
| quests | #1, #2, #6, #15 | volgorde van stappen bij laden van een oude save met half afgeronde quest |
| warps | #5, #9, #10 (+ World Warper in #16) | Warper openen terwijl een tekstvak openstaat; data-gedreven kamers (`dungeon_rooms.gd` e.d.) |
| opslaan | #3, #8, #12, #13, #14 | opslaan bij vol geheugen of zonder schrijfrechten op Android |

## Samenvattende tabel

| id | onderwerp | ernst | bestand:regel |
|---|---|---|---|
| 1 | quest/dialoog | hoog | `scripts/story.gd:314`, `scripts/game_state.gd:2458` |
| 2 | quest/dialoog | hoog | `scripts/game_state.gd:2487`, `scripts/game_state.gd:2605` |
| 3 | opslaan | midden | `scripts/game_state.gd:1839`, `scripts/game_state.gd:1661` |
| 4 | dialoog | midden | `scripts/dialog_box.gd:133`, `scripts/map.gd:154` |
| 5 | warp | midden | `scripts/ui/field_menu.gd:451` |
| 6 | quest | laag | `scripts/story.gd:161` |
| 7 | dialoog | laag | `scripts/story.gd:393` |
| 8 | opslaan | laag | `scripts/game_state.gd:1478` |
| 9 | warp | laag | `scripts/map.gd:371`, `scripts/game_state.gd:2332` |
| 10 | warp | laag | `scripts/map.gd:59` |
| 11 | dialoog | laag | `scripts/dialog_box.gd:185` |
| 12 | opslaan | laag | `scripts/game_state.gd:2540` |
| 13 | opslaan | laag | `scripts/game_state.gd:2012` |
| 14 | opslaan | laag (ontwerp) | `scripts/game_state.gd:1540` |
| 15 | quest | laag (ontwerpvraag) | `data/quests.json`, `scripts/data/quest_data.gd:121` |
| 16 | alle | ok | zie §16 |
