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

## 7. Update (besluit Dennis, 13-10 avond)
- **Monster niet meer in de statusrij.** De rij onderaan heeft alleen de 4 heldenvakken. Het Codex-monster
  is een kleine **zijspeler** boven de B-knop: groen label (52x11) met het icoon van RPG ART en de naam,
  **geen HP/MP-balken**, met de rug-sprite er vlak boven. Hij vecht, wordt geraakt en is tikbaar als
  doelwit zoals voorheen. Technisch heeft hij nog wel een element in `status_boxes` (zodat de indexen
  gelijk blijven aan `heroes`), maar dat element tekent `hero_status_box.gd` (`monster = true`) als label.
  `MONSTER_GAP` is weg; nu `SIDE_GAP` (ruimte label ↔ B-knop) en `HeroStatusBox.SIDE_SIZE`.
- **Icoon van RPG ART**: `assets/ui/icon_monstervak.png` (7x6), staat in `tools/handwerk.txt`, en de
  placeholder-regel is weg uit `tools/placeholders_v17.txt`. Ontbreekt het bestand, dan tekent de code
  het oude boekje (terugval).
- **Warpen-knop compact**: er is geen warp-knop in het gevecht zelf. Ik ga ervan uit dat de grote
  **Warpen**-knop van het menu bedoeld is (die opent tijdens het spelen met MENU). Die is nu
  96x24 (was ca. 210x60), met Party eronder in dezelfde maat. Tikhoogte >= 16 blijft. `menutest` controleert nu
  "compact" in plaats van "groter".
- partytest: nieuwe checks voor de zijspeler (klein, boven B, geen balken, sprite erboven), het
  icoon (7x6) en de compacte Warpen. Er is ook een screenshot `party_veldmenu.png` bij.
- **Magic weer direct in het veldmenu** (Dennis): knop **Magic** onderaan de linkerkolom
  (Uitrusting > Codex > Items > Magic). Een tik opent meteen het bestaande Magie-scherm, zonder
  tussenstap. Genezen buiten gevechten werkt zoals voorheen (`PartyActions.cast_spell`). Om ruimte te maken
  zijn de knoppen links iets lager (30 i.p.v. 34). D-pad: Uitrusting ↑ = Magic, Magic ↓ = Uitrusting.
  `menutest`/`codextest` verwachten nu 6 knoppen. partytest: Magic opent het scherm, Lotte geneest Dennis buiten het gevecht
  (screenshot `veldmenu_magic.png`).
- Ingekorte namen krijgen geen spatie meer voor het puntje ("Moss." i.p.v. "Moss .").
