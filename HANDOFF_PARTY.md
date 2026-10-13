# HANDOFF – Partylimiet (max 4 helden + 1 monster) – RPG CODE

Branch: `rpgcode/party-limiet` (vanaf `main`). Spec van RPG Forge, akkoord Dennis:
in een gevecht vechten **maximaal 4 actieve helden + 1 monster** (de Codex-bondgenoot) mee. De rest
staat in de **reserve** en wissel je alleen **buiten het gevecht** via het veldmenu.

## 1. Wat er veranderd is
| bestand | wat |
|---|---|
| `scripts/party_limiet.gd` (nieuw) | alle regels: `MAX_HELDEN = 4`, `MAX_MONSTERS = 1`, `normaliseer()` (migratie), `wissel()`, `naar_reserve()`, `naar_groep()`, `kies_monster()`, `reserve_monsters()`, `mag_wisselen()` (= niet `GameState.in_battle`). Engelse meldingen als constanten. |
| `scripts/ui/party_screen.gd` (nieuw) | veldmenu > **Party**: links 4 heldenplekken + 1 groene monsterplek, rechts de reserve (helden + monsters). Tik/A: held markeren → reserve-held = ruilen; 2x dezelfde = naar reserve; reserve-held zonder markering = erbij (als er plek is); reserve-monster = wordt actief; monsterplek = monster naar reserve. |
| `scripts/ui/field_menu.gd` | 5e knop **Party** rechts onder Warpen (Warpen iets lager maar nog steeds groter dan de linker knoppen); D-pad: Warpen ↔ Party. `open_party()` weigert tijdens een gevecht. |
| `scripts/game_state.gd` | `apply_state()` roept na het laden `PartyLimiet.normaliseer()` aan (**oude saves**: extra helden → reserve, niemand kwijt). `add_member()`: bij een volle groep gaat de nieuwe held naar de reserve. Nieuw `member(id)` (groep of reserve); `join_member()` gebruikt die. Nieuwe suite `--partytest` in de lijst. |
| `scripts/party_bench.gd` | `MAX_ACTIEF` = `PartyLimiet.MAX_HELDEN` (was 3). De Rustkamer werkt verder zoals hij was. |
| `scripts/battle/battle.gd` | heldenlus stopt na 4 helden; `last_plan` = beurtvolgorde van de laatste ronde (voor de test); statusvakken: het monstervak (laatste) staat `MONSTER_GAP` (4) apart; Codex-submenu toont "Swap: outside battle" (grijs). |
| `scripts/battle/codex_battle.gd` | `wissel_in_gevecht := false` → `can_swap()` is false in een gevecht. Het monstervak krijgt `monster = true`. |
| `scripts/battle/hero_status_box.gd` | `monster`-vak: mos-groene dubbele rand, groen getinte achtergrond en een klein Codex-boekje (placeholder, in code getekend) rechtsboven. |
| `scripts/tests/party_tests.gd` (nieuw) | suite `--partytest` (zie §3). |
| bestaande tests | `debug_menutest.gd`: "vier knoppen" → "vijf knoppen" (+Party). `warper_kamer_tests.gd`: normaliseer-check met 5 helden i.p.v. 4 (limiet is nu 4). `fusie_tests.gd`: nieuwe check "in het gevecht niet wisselen (standaard)", daarna zet de test `bt.codex.wissel_in_gevecht = true` zodat het oude wissel-pad gedekt blijft. |
| `tools/placeholders_v17.txt` | regel voor het Codex-icoontje van het monstervak. |

## 2. Ontwerpkeuzes / aannames (graag nakijken, Forge)
1. **Er is geen IP-meter in de code**: "IP/beurtvolgorde" = de beurtvolgorde (`plan` in `battle.gd _run`).
   Die bestaat al alleen uit `heroes` + bondgenoot + vijanden; door de lus op 4 te stoppen telt hij
   automatisch alleen de 5 actieve combatanten. Komt er later een IP-meter, dan hoort die op `battle.heroes`.
2. **Reserve = bestaande opslag**: helden in `GameState.party_bench` (save-sleutel `party_bank`, bestond al
   voor de Rustkamer), monsters = de niet-actieve Codex-pagina's (`codex_active` bestond al). Geen nieuw
   save-formaat, dus geen `SAVE_VERSION`-bump nodig.
3. **Monster wisselen in het gevecht staat uit** (spec: "alleen buiten het gevecht"). De code van het
   wissel-commando (v0.19, HANDOFF_FUSIE) blijft bestaan achter `wissel_in_gevecht`; Forge kan hem later
   weghalen of weer aanzetten.
4. **Dennis en tijdelijke gasten** (Codex-gast/verhaalgast) gaan nooit naar de reserve (zelfde regel als de Rustkamer).
5. **KO-monster** kan buiten het gevecht niet actief gemaakt worden ("can't fight right now"); helden mogen wel KO in de groep.
6. Er zijn in de data maar **3 helden** (Dennis, Noor, Lotte): de limiet van 4 wordt in het echte spel nog
   niet bereikt. De test en de screenshots gebruiken testkopieën (Kai, Sem, Ivo).
7. **Reserve krijgt geen EXP** (alleen wie meevecht, zoals voorheen).
8. Wisselen via het menu kan **overal** buiten een gevecht (ook buiten de Rustkamer); de Rustkamer
   (`PartyWissel`) blijft daarnaast werken met dezelfde opslag.
9. CI: `.github/workflows/tests.yml` is **niet** aangeraakt (opdracht). Forge: zet `partytest` in de matrix.

## 3. Tests
`--partytest` (`scripts/tests/party_tests.gd`), deel A regels, B save/load + migratie, C gevecht, D menu:
max 4 helden + 1 monster in het gevecht (5e held vecht niet mee), 5 statusvakken onderaan zonder overlap,
monstervak anders en apart, reserve-opslag, wisselen buiten het gevecht (regels én via het scherm met
tikken), wisselen geblokkeerd in het gevecht (regels, Codex-knop, veldmenu), beurtvolgorde alleen actieve
combatanten, oude save zonder `party_bank`, oude save met 6 helden in `party` → 4 + 2 reserve.

Alle 28 suites serieel (logs: `/workspace/code_party/logs/final43`, `final472`, `rerun43`).

**Godot 4.7.2**: 28/28 OK.
```
autotest exit=0 PASS=467 FAIL=0 ERR=0 235s RESULT OK (0 fouten)
menutest exit=0 PASS=230 FAIL=0 ERR=0 20s RESULT OK (0 fouten)
puzzletest exit=0 PASS=156 FAIL=0 ERR=0 60s RESULT OK (156 goed, 0 fouten)
dungeontest exit=0 PASS=185 FAIL=0 ERR=0 115s RESULT OK (185 goed, 0 fouten)
golemtest exit=0 PASS=64 FAIL=0 ERR=0 25s RESULT OK (64 goed, 0 fouten)
archieftest exit=0 PASS=138 FAIL=0 ERR=0 34s RESULT OK (138 goed, 0 fouten)
kerntest exit=0 PASS=72 FAIL=0 ERR=0 33s RESULT OK (72 goed, 0 fouten)
kernkrachttest exit=0 PASS=116 FAIL=0 ERR=0 61s RESULT OK (116 goed, 0 fouten)
woudtest exit=0 PASS=153 FAIL=0 ERR=0 172s RESULT OK (153 goed, 0 fouten)
codextest exit=0 PASS=137 FAIL=0 ERR=0 75s RESULT OK (137 goed, 0 fouten)
fusietest exit=0 PASS=155 FAIL=0 ERR=0 57s RESULT OK (155 goed, 0 fouten)
checkpointtest exit=0 PASS=73 FAIL=0 ERR=0 28s RESULT OK (73 goed, 0 fouten)
dungeon100gentest exit=0 PASS=59 FAIL=0 ERR=0 37s RESULT OK (59 goed, 0 fouten)
dungeon100schaaltest exit=0 PASS=84 FAIL=0 ERR=0 2s RESULT OK (84 goed, 0 fouten)
dungeon100regelstest exit=0 PASS=113 FAIL=0 ERR=0 8s RESULT OK (113 goed, 0 fouten)
dungeon100integratietest exit=0 PASS=41 FAIL=0 ERR=0 13s RESULT OK (41 goed, 0 fouten)
dungeon100blauwtest exit=0 PASS=55 FAIL=0 ERR=0 5s RESULT OK (55 goed, 0 fouten)
actorsfxtest exit=0 PASS=342 FAIL=0 ERR=0 2s RESULT OK (342 goed, 0 fouten)
catalogustest exit=0 PASS=17 FAIL=0 ERR=0 2s RESULT OK (17 goed, 0 fouten)
updatetest exit=0 PASS=370 FAIL=0 ERR=0 2s RESULT OK (370 goed, 0 fouten)
archief2test exit=0 PASS=180 FAIL=0 ERR=0 15s RESULT OK (180 goed, 0 fouten)
warperkamertest exit=0 PASS=191 FAIL=0 ERR=0 7s RESULT OK (191 goed, 0 fouten)
hangertest exit=0 PASS=18 FAIL=0 ERR=0 3s RESULT OK (18 goed, 0 fouten)
spiegeltest exit=0 PASS=54 FAIL=0 ERR=0 2s RESULT OK (54 goed, 0 fouten)
berggrottest exit=0 PASS=74 FAIL=0 ERR=0 9s RESULT OK (74 goed, 0 fouten)
wilgendaltest exit=0 PASS=123 FAIL=0 ERR=0 7s RESULT OK (123 goed, 0 fouten)
pvptest exit=0 PASS=113 FAIL=0 ERR=0 2s RESULT OK (113 goed, 0 fouten)
partytest exit=0 PASS=45 FAIL=0 ERR=0 18s RESULT OK (45 goed, 0 fouten)
```
**Godot 4.3**: 28/28 OK. codextest/fusietest faalden eerst op 1 oude verwachting elk (4 menuknoppen; Swap aan in het gevecht); die verwachtingen zijn aangepast en opnieuw gedraaid: codextest 137/0, fusietest 155/0, partytest 45/0.
```
autotest exit=0 PASS=467 FAIL=0 ERR=0 245s RESULT OK (0 fouten)
menutest exit=0 PASS=230 FAIL=0 ERR=0 26s RESULT OK (0 fouten)
puzzletest exit=0 PASS=156 FAIL=0 ERR=0 67s RESULT OK (156 goed, 0 fouten)
dungeontest exit=0 PASS=185 FAIL=0 ERR=0 118s RESULT OK (185 goed, 0 fouten)
golemtest exit=0 PASS=64 FAIL=0 ERR=0 26s RESULT OK (64 goed, 0 fouten)
archieftest exit=0 PASS=138 FAIL=0 ERR=0 34s RESULT OK (138 goed, 0 fouten)
kerntest exit=0 PASS=72 FAIL=0 ERR=0 34s RESULT OK (72 goed, 0 fouten)
kernkrachttest exit=0 PASS=116 FAIL=0 ERR=0 62s RESULT OK (116 goed, 0 fouten)
woudtest exit=0 PASS=153 FAIL=0 ERR=0 175s RESULT OK (153 goed, 0 fouten)
codextest exit=1 PASS=136 FAIL=1 ERR=0 76s RESULT FOUT (136 goed, 1 fouten)
fusietest exit=1 PASS=154 FAIL=1 ERR=0 53s RESULT FOUT (154 goed, 1 fouten)
checkpointtest exit=0 PASS=73 FAIL=0 ERR=0 30s RESULT OK (73 goed, 0 fouten)
dungeon100gentest exit=0 PASS=59 FAIL=0 ERR=0 39s RESULT OK (59 goed, 0 fouten)
dungeon100schaaltest exit=0 PASS=84 FAIL=0 ERR=0 3s RESULT OK (84 goed, 0 fouten)
dungeon100regelstest exit=0 PASS=113 FAIL=0 ERR=0 8s RESULT OK (113 goed, 0 fouten)
dungeon100integratietest exit=0 PASS=41 FAIL=0 ERR=0 15s RESULT OK (41 goed, 0 fouten)
dungeon100blauwtest exit=0 PASS=55 FAIL=0 ERR=0 7s RESULT OK (55 goed, 0 fouten)
actorsfxtest exit=0 PASS=342 FAIL=0 ERR=0 3s RESULT OK (342 goed, 0 fouten)
catalogustest exit=0 PASS=17 FAIL=0 ERR=0 3s RESULT OK (17 goed, 0 fouten)
updatetest exit=0 PASS=370 FAIL=0 ERR=0 3s RESULT OK (370 goed, 0 fouten)
archief2test exit=0 PASS=180 FAIL=0 ERR=0 17s RESULT OK (180 goed, 0 fouten)
warperkamertest exit=0 PASS=191 FAIL=0 ERR=0 7s RESULT OK (191 goed, 0 fouten)
hangertest exit=0 PASS=18 FAIL=0 ERR=0 5s RESULT OK (18 goed, 0 fouten)
spiegeltest exit=0 PASS=54 FAIL=0 ERR=0 3s RESULT OK (54 goed, 0 fouten)
berggrottest exit=0 PASS=74 FAIL=0 ERR=0 9s RESULT OK (74 goed, 0 fouten)
wilgendaltest exit=0 PASS=123 FAIL=0 ERR=0 9s RESULT OK (123 goed, 0 fouten)
pvptest exit=0 PASS=113 FAIL=0 ERR=0 3s RESULT OK (113 goed, 0 fouten)
partytest exit=0 PASS=45 FAIL=0 ERR=0 19s RESULT OK (45 goed, 0 fouten)
```
Ook gemerged: `origin/main` (CANON.md regel 13 'Party-regel' = deze spec; Kael Voss als 5e held is alleen lore, nog niet in de data).
Extra aangepaste bestaande tests: `codex_tests.gd` (5 menuknoppen), `fusie_tests.gd` (Swap-regel grijs: 'Swap: outside battle').


## 4. Screenshots
`/workspace/code_party/shots/`: `party_gevecht_5_plekken.png` (gevecht, 4 helden + groen monstervak),
`party_menu.png`, `party_menu_gewisseld.png` (+ `_3x`-versies 1152x648).

## 5. Nodig van RPG ART
- Codex-icoontje voor het monstervak: `assets/ui/icon_monstervak.png`, 7x6 (14x12 op het 2x-gevechtsraster). Nu in code getekend.
- Eventueel een eigen kader voor het monstervak (nu StyleBox + lijnen in `hero_status_box.gd`).

## 6. Open punten
- Met 5 vakken zijn de statusvakken ~41 eenheden breed; de getallen staan dan over het label "HP"/"MP" heen
  (nog leesbaar, zie screenshot). Mogelijke vervolgstap: labels weglaten bij smalle vakken.

## 7. Vervolg (branch `rpgcode/party-zijspeler`, besluiten Dennis 13-10)
Port van de nieuwe stukken uit #66 bovenop #69 (al op main). Het icoon van RPG ART
(`assets/ui/icon_monstervak.png`, handwerk.txt, placeholder-regel KLAAR) stond al op main en is ongewijzigd.
- **Monster als zijspeler boven B.** In de statusrij staan alleen nog de 4 heldenvakken (die worden daardoor
  breder; het open punt in §6 vervalt). Het Codex-monster is een klein groen label (52x11,
  `HeroStatusBox.SIDE_SIZE`) met het RPG ART-icoon en de naam, zonder HP/MP-balken. Het label staat boven de B-knop
  (`SIDE_GAP` 3) en de rug-sprite staat er vlak boven. Het monster vecht, wordt geraakt en is tikbaar
  als doelwit zoals voorheen. In `status_boxes` heeft het monster nog wel een element, zodat de indexen gelijk blijven aan
  `heroes`; dat element tekent zich met `monster = true` als label. `MONSTER_GAP` is weg.
  Het icoon blijft lazy geladen via main's `static var _monster_icon` (met een getekende terugval).
- **Magic in het veldmenu.** De knop Magic staat onder Items (Equipment > Codex > Items > Magic, een D-pad-ring) en
  opent meteen het Magie-scherm, zonder tussenstap. Genezen buiten gevechten werkt weer. De linkerknoppen zijn
  30 hoog (was 34).
- **Warp compact**: 96x24 (was ca. 210x60), Party eronder in dezelfde maat, tikhoogte >= 16. Er is geen
  warp-knop in het gevecht zelf, dus ik ga ervan uit dat Dennis de Warp-knop van het veldmenu bedoelt.
- **Ingekorte namen**: geen spatie meer voor het puntje.
- **Settings en Load** (rechterkolom, 96x24). Settings opent het bestaande Opties-scherm. Load opent de slotlijst
  (`scripts/ui/load_screen.gd`, dezelfde `SaveSlotList` als het titelscherm) en vraagt eerst "Load slot N?" met
  "Unsaved progress will be lost." ('No' heeft de focus).
- **Bestiary terug**: linkerkolom, onder Magic, opent het bestaande bestiarium.
- **Scenes** (rechterkolom, onder Party): een lijst met alle cutscenes (`scripts/data/scenes_data.gd`,
  `scripts/ui/scenes_screen.gd`). Bekeken scenes zijn speelbaar, niet bekeken scenes staan grijs als "???".
  Na het afspelen ben je terug in de lijst. Aanname: alleen de echte, losse cutscenes staan erin
  (wereldkaart-film `WorldmapCutscene`, Hanger-intro `hanger_scene.tscn`). De verhaal-events uit `story_data.gd`
  zetten vlaggen, geven spullen, starten gevechten of wisselen van map en zijn dus niet veilig opnieuw af te
  spelen. Een herhaling raakt het echte verhaal niet: de film krijgt geen map mee en de Hanger krijgt een eigen,
  lege vlaggenbron (`ScenesData.FlagBron`). Een nieuwe cutscene vraagt om een regel in `SCENES` plus een `kind`
  in het scherm. Titels zijn placeholder-spelertekst: "Into the Wide World" en "The Hanger Awakens".
- **Save**: nieuw veld `scenes_seen` (ids). `GameState.mark_scene_seen()` wordt aangeroepen door
  `WorldmapCutscene.start_on` en door de Hanger bij `_mark_intro_seen`. Migratie: oude saves hebben het veld
  niet, en dan telt de vlag die de cutscene zelf zet (`cutscene_wereldkaart_gezien` /
  `world_warper_intro_seen`) als gezien. Onbekende ids vallen weg.
- **Indeling (telefoon, 384x216)**: links 5 knoppen van 30 hoog (Equipment, Codex, Items, Magic, Bestiary),
  rechts onder het MENU-bord 5 knoppen van 24 hoog (Warp, Party, Scenes, Settings, Load). Beide kolommen eindigen
  op y=182 en scrollen is niet nodig. De Scenes-lijst zelf staat in een ScrollContainer.
- **Tests**: partytest deel E (Scenes-lijst, op slot/"???", ontgrendelen door bekijken (beide cutscenes),
  herhaling speelt en keert terug naar de lijst, save-roundtrip, migratie van een oude save, Bestiary opent,
  geen overlappende knoppen). Menutest en codextest verwachten nu 10 knoppen; omhoog vanaf Equipment = Bestiary.
- **Tests (eerder)**: partytest (52, nieuw: zijspeler klein/boven B/geen balken/sprite erboven, icoon 7x6, Warp compact,
  Magic opent het scherm en Lotte geneest Dennis in het veld), menutest (6 knoppen, Magic in de ring,
  Warp "compact" i.p.v. "groter") en codextest (6 knoppen, monster rechts van Dennis en iets hoger).
- **Screenshots** (`/workspace/code_party/shots/`): `party_gevecht_5_plekken.png`, `party_veldmenu.png`,
  `veldmenu_magic.png`, `veldmenu_knoppen.png`, `veldmenu_laden_bevestigen.png`, `veldmenu_scenes_knop.png`,
  `scenes_op_slot.png`, `scenes_scherm.png`, `scenes_herhaling_hanger.png` (alle ook `_3x`).
- **Testresultaten (commit met Bestiary/Scenes)**: alle 30 suites serieel op 4.7.2 en 4.3. Op beide versies zijn
  er 29 groen. kernkrachttest faalde onder load 1 check (4.7.2: "door"; 4.3: "inslag") en is daarna los
  groen (116/0 op beide). partytest: 77/0 op beide versies, menutest 230/0, codextest 137/0.
  Logs: `/workspace/code_party/logs/full472_scenes`, `full43_scenes`, `rerun472_scenes`, `rerun43_scenes`.
