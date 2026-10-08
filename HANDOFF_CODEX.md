# HANDOFF – De Codex (Kernfragment stap 2) – RPG CODE

Basis: `/workspace/lufia_v16`. Werkkopie: `/workspace/code_codex/`, patch: `code_codex.patch`
(tegen v16, `git apply`, ook de PNG's van RPG ART zitten erin; .import-bestanden niet, die maakt Godot).
lufia_v9..v16 zijn niet aangeraakt. hd_ui.gd, tutorial, tekstballonnen, glitch en dialoogstijl van
Forge zijn NIET aangeraakt. battle.gd heeft alleen kleine haakjes; de logica zit in eigen bestanden.

## 1. Wat het doet
- **Leeg Boek** (item) in een gevecht op een verzwakt monster: lukt het, dan verdwijnt het monster
  in het boek (inschrijf-effect) en staat het als **pagina** in de Codex (level, stats, vaardigheden).
- **Eén Codex-monster vecht mee** als AI-bondgenoot naast Dennis (zoals de capsule-monsters in
  Lufia 2): eigen statusvak, rugaanzicht, handelt zelf, kan geraakt/KO worden, krijgt EXP en levels.
- **Veldmenu > Codex**: pagina's bekijken en de actieve bondgenoot kiezen (of niemand).
- Alles data-gedreven in `scripts/data/codex_data.gd`; klaar voor fusie later (zie §6).

## 2. Leeg Boek en vangen
- Item `leeg_boek` in `GameData.ITEMS`: `"target": "enemy"`, `"capture": true`, `"field": false`
  (grijs in het veldmenu: "Dit kan alleen in een gevecht."), `"price": 60` (voor de winkel later).
- **Waar te krijgen: 3 stuks in de startvoorraad** (`START_INVENTORY`). Er is nog geen winkel.
- In het gevecht: Item > Leeg Boek > een vijand kiezen (pijltje, zoals Aanval).
- **Vangkans** (`CodexData.capture_chance`):
  `kans = clamp(0,02 + 0,93 x (1 - HP/maxHP)^1,5 ; 0 ; 0,95) x capture_rate`

  | HP over | 100% | 75% | 50% | 25% | 10% | 1 van 16 |
  |---|---|---|---|---|---|---|
  | kans | 2% | 14% | 35% | 62% | 81% | 86% |
  capture_rate: 1,0 (standaard), Mech. Wachter 0,8, Kennis-Beest 0,6. Nooit meer dan 95%.
- **Bazen** (gevecht met `GameState.pending_boss`, of een vijand met een kern): nooit.
  Melding "Het Kennis-Beest is te machtig! Een baas laat zich niet inschrijven. (Het boek blijft heel.)"
  Het boek wordt dan **niet** verbruikt (het is een weigering, geen poging). Zelfde bij "past niet in
  de Codex" (vijand zonder soort) en "De Codex is vol (12 pagina's)".
- **Mislukt**: het boek is op. "Het boek blijft leeg... Papiergeest glipt eruit! (kans 2%)".
- **Gelukt**: het boek is op; het monster vervaagt/krimpt tijdens frame 2-3 van het effect en is weg
  (HP 0, `captured`). Bericht "Mosslijm is ingeschreven in de Codex! Pagina 1: Lv 1, Slijmklodder."
  - Was het de laatste vijand, dan eindigt het gevecht als **winst** (overwinningsvenster, autosave,
    map-monster weg).
  - **EXP/goud**: een ingeschreven monster geeft GEEN EXP, goud of buit; de andere vijanden wel.
    Het telt niet als "verslagen" in het bestiarium (wel "gezien").
- **Level bij het vangen** = monsterniveau van de verdieping (`tier`), minimaal 1 (wereldkaart = Lv 1).
- **Dubbele soorten**: toegestaan. Elk gevangen exemplaar is een eigen pagina met een eigen unieke id
  (`codex_0001`, `codex_0002`, ...; nooit hergebruikt, ook niet na laden). Max **12** pagina's.
- De eerste pagina wordt meteen de actieve bondgenoot.

## 3. De bondgenoot in het gevecht
- Doet mee in elk gevecht (ook baasgevechten), **niet** in het oefengevecht (tutorial). Alleen als hij
  HP > 0 heeft. Staat rechts naast Dennis boven een eigen statusvak (naam, HP, MP).
- **Handelt zelf** (geen commando-kruis): na het kiezen van de helden krijgt hij een actie; volgorde
  op SPD zoals iedereen. AI (`ai` per soort, standaard `DEFAULT_AI`):
  1. kent hij een genees-vaardigheid en zit een held of hijzelf onder `heal_below` (Mosslijm 40%)
     van zijn HP: genezen (laagste % eerst), power + 2 x level HP;
  2. anders met kans `skill_chance` (30-40%) een willekeurige aanvalsvaardigheid;
  3. anders een gewone aanval (zelfde schadeformule als de helden: ATK x power - DEF/2, +/-15%).
  Doelwit: `target` = "zwakste" (laagste HP), "sterkste" of "willekeurig".
- Vlucht de party (ook als het mislukt), dan doet de bondgenoot die ronde niets.
  Zijn SPD telt mee in het gemiddelde voor de vluchtkans.
- **Doelwit**: vijanden kiezen willekeurig uit de levende helden + bondgenoot. Items/spreuken op
  "Op wie?" kunnen hem ook genezen.
- **KO**: grijs en plat, doet niets meer. Geen game over zolang Dennis staat; zijn alle echte helden
  KO, dan is het game over (ook als de bondgenoot nog staat).
  **Na het gevecht** (winst of vlucht) staat hij weer op met **1 HP** (zelfde regel als de helden).
  **Rusten**: HP-boek / savepunt-boek vult ook de Codex-monsters (ook KO); game over (respawn) ook.
- **EXP**: dezelfde EXP als elke held (alleen als hij nog staat), zelfde curve (`15 x (lv-1)^2`).
  Level-up: groei per soort, nieuwe vaardigheden per level; een eigen overwinningspagina
  "Mosslijm is nu level 3! / HP+5 ATK+2 DEF+1 SPD+1 / Mosslijm leert Mosheling!".
- Boss-kern, Kernkracht, vluchten, verdedigen: ongewijzigd (getest).

## 4. Veldmenu > Codex (`scripts/ui/codex_screen.gd`)
- 'Codex' staat na 'Status' zodra de Codex minstens één pagina heeft (zoals het capsule-menu in
  Lufia 2 pas verschijnt als je een monster hebt). Zonder pagina's is het menu precies als v16.
- Links de pagina's (`* Mosslijm     Lv3`, `*` = bondgenoot) en onderaan "Geen bondgenoot".
  Rechts naam + level, vooraanzicht, HP/MP, ATK/DEF/SPD, EXP + volgende level, element, vaardigheden.
- A / tik = deze vecht mee; "Geen bondgenoot" = niemand. B / MENU / Terug = terug (focus op Codex).
  Regels 16 hoog (duim), zelfde stijl als Items/Bestiarium (menu_screen.gd, menu_colors.gd).

## 5. Opslaan
- Save-sleutel `"codex": {"pages": [...], "active": uid, "next": teller}` (handmatig + autosave).
- Oude saves zonder `"codex"` laden met een lege Codex. Kapotte pagina's (onbekende soort, geen uid,
  dubbele uid, rare getallen) vallen weg of krijgen standaardwaarden; een onbekende actieve uid = geen
  bondgenoot; de teller komt altijd na de hoogste bestaande uid.

## 6. Data (`scripts/data/codex_data.gd`)
- Basis-stats komen uit `GameData.ENEMIES` (de gewone stats, niet de baas-stats) = level 1.
  Stats op level L = basis + groei x (L - 1).
- **Pagina** (gaat zo de save in): `uid, species, name, level, exp, hp, mp, max_hp, max_mp, atk, def,
  agi, skills, element, type, fusion_tags, fusion {generation: 0, parents: []}, caught {tier, play_time}`.
  Voor fusie later: unieke uid per exemplaar, element/type/fusion_tags per soort, `fusion.parents`.
- **Vaardigheden** (`SKILLS`): type `damage` (1 vijand), `all` (alle vijanden), `heal`, `guard`;
  `power`, `mp` (nu alles 0), `element` (info).

  | soort | element / type | groei HP/ATK/DEF/SPD | leert (level) | AI |
  |---|---|---|---|---|
  | mosslijm | natuur / slijm | 5/2/1/1 | Slijmklodder (1), Mosheling (3) | willekeurig, geneest < 40% |
  | moskonijn | natuur / dier | 4/2/1/2 | Bijtsprong (1) | zwakste |
  | papiergeest | inkt / geest | 4/2/1/1 | Fluisterblad (1), Papierstorm (4) | willekeurig |
  | glitchmot | ruis / insect | 3/3/1/2 | Ruisvleugel (1), Stoorsignaal (5) | zwakste |
  | mech_wachter | metaal / construct | 6/2/2/1 | Zegelslag (1), Schild omhoog (3) | sterkste, vangst x0,8 |
  | kennis_beest | kennis / golem | 7/3/2/1 (+1 MP) | Boekenhamer (1), Kennisgolf (6) | sterkste, vangst x0,6 |

### Nieuwe soort toevoegen (alleen data, geen code)
1. De vijand staat in `GameData.ENEMIES` (naam, `sprite`, stats). Voor het rugaanzicht:
   **`"sprite_back"`** in die vijand (afspraak Forge v17), bestand `<id>_rug.png`, zelfde
   canvas/anker als het vooraanzicht (voeten op (b/2, h-6)). Ontbreekt het, dan tekent de code een
   plaatsvervanger (vooraanzicht gespiegeld en donkerder).
2. Eén regel in `CodexData.SPECIES`. **Verplicht**: `"enemy"` (id in ENEMIES).
   **Optioneel** (anders standaard): `name`, `element` ("neutraal"), `type` ("monster"),
   `fusion_tags` ([]), `growth` ({max_hp 4, max_mp 0, atk 2, def 1, agi 1}), `learn`
   ({1: ["klauw"]}), `ai` ({skill_chance 0,35, heal_below 0,35, target "willekeurig"}),
   `ally_scale` (1.0), `fx_scale` (1.0), `capture_rate` (1.0), `capturable` (true).
   Nieuwe vaardigheden: een regel in `SKILLS`.
   Voorbeeld v17: `"wortelkruiper": {"enemy": "wortelkruiper", "element": "natuur", "type": "plant",
   "fusion_tags": ["wortel", "bos"], "learn": {1: ["klauw"]}}`.
3. Een soort die alleen baas is (De Wortelkoning): niets doen (bazen zijn nooit te vangen) of
   `"capturable": false` als hij ook als gewone vijand voorkomt maar niet te vangen mag zijn.
4. `--codextest` deel A controleert alles (`CodexData.validate()`).

## 7. Art (RPG ART, `/workspace/art_codex_v16/out/`, zie LEESMIJ.txt daar)
| pad | maat | gebruik |
|---|---|---|
| `res://assets/ui/icons/leeg_boek.png` | 16x16 | boekje dat naar het monster vliegt (+ item `icon`) |
| `res://assets/fx/inschrijf.png` | 192x48 = 4 x 48x48 | 0,1 s per frame, niet loopen, midden (24,24) op het midden van het monster; schaal 1 (Kennis-Beest 2, `fx_scale`) |
| `res://assets/sprites/enemies/<id>_rug.png` | = vooraanzicht | mosslijm 90x94, papiergeest 74x94, glitchmot 106x96, kennis_beest 196x182 |
- `"sprite_back"` staat in ENEMIES voor deze 4 (Forge vult het in v17 voor alle 8).
- Bondgenoot op heldenschaal (0,5 = 1 art-pixel per fijne pixel), anker (b/2, h-6) op de voeten.
  Het Kennis-Beest is 1:1 hoger dan Dennis (182 vs ~156 px): `ally_scale` 0,75.
- Zonder art (bestand weg) werkt alles met plaatsvervangers in code.

## 8. Bestanden
- nieuw: `scripts/data/codex_data.gd`, `scripts/battle/codex_battle.gd` (vangen, AI, EXP),
  `scripts/battle/codex_ally.gd` (bondgenoot-sprite), `scripts/ui/codex_screen.gd`,
  `scripts/tests/codex_tests.gd`, de 6 PNG's, dit bestand.
- gewijzigd:
  - `scripts/battle/battle.gd`: haakjes (bondgenoot erbij, actie per ronde, Item op een vijand,
    `codex_ally`/vangen in `_execute`, game over = alle echte helden KO, geen EXP voor ingeschreven
    monsters, EXP bondgenoot, kruis slaat de bondgenoot over).
  - `scripts/game_state.gd`: codex-staat, save/load, KO -> 1 HP, respawn, `--codextest`.
  - `scripts/data/game_data.gd`: item `leeg_boek`, startvoorraad, `sprite_back` (4x).
  - `scripts/ui/field_menu.gd`: commando 'Codex' + `open_codex()`.
  - `scripts/book_point.gd`: HP-/savepunt-boek vult ook de Codex-monsters.
  - `scripts/debug_menutest.gd`: 2 verwachtingen (itemlijst heeft nu "Leeg Boek x3").

## 9. Tests
`--codextest` (scripts/tests/codex_tests.gd, optioneel `--alleen=ABCDE`, `--shots=map`):
- A data: validate, 4 soorten (basis = ENEMIES, rug = sprite_back, zelfde maat als voor), art aanwezig,
  nieuwe soort met alleen `enemy`, vangkans-curve, baas 0, pagina's, dubbel, vol, item, EXP-groei
- B vangen: gelukt (effect, bericht, weg, winst, pagina, boek op, geen EXP), mislukt (boek op),
  baas weigert (boek blijft, bondgenoot doet mee, niet vluchten)
- C bondgenoot: naast Dennis, echte rug-art, anker, kruis alleen bij Dennis, zelf Slijmklodder,
  schade, geraakt, KO zonder game over, 1 HP na het gevecht, EXP + level-up-pagina + Mosheling,
  AI geneest Dennis, vluchten, Kennis-Beest kleiner
- D Codex-scherm: niet zonder pagina's, plek in het menu, lijst/details, A/tik kiezen, Geen, B terug
- E save/load, oude save, kapotte data, respawn, HP-boek

TESTTABEL (verse kopie van v16 + patch, run_tests_iso.sh, eigen save-map, niet tegelijk):
| Suite | 4.3 | 4.7.2 |
|---|---|---|
| autotest | 434/0 | 434/0 |
| menutest | 225/0 | 225/0 |
| puzzletest | 152/0 | 152/0 |
| dungeontest | 124/27 * | 124/27 * |
| golemtest | 62/0 | 62/0 |
| archieftest | 91/0 | 91/0 |
| kerntest | 72/0 | 72/0 |
| kernkrachttest | 102/0 | 102/0 |
| codextest | 76/0 | 76/0 |

(PASS/FAIL; run 8 okt 01:43-02:17 CEST, logs in `/workspace/.scratch/codex/full/`.)
\* dungeontest: op de ONGEWIJZIGDE v16 precies dezelfde 124/27 op 4.3 en 4.7.2 (regel voor regel
gelijk, alleen een gemeten tijd verschilt): kamers laden niet in deel D, daarna volgfouten in E/F/G.
Bestaand probleem in v16, niet door de Codex.

## 10. Screenshots (`/workspace/code_codex_shots/`, elk + `_3x` = 1152x648)
- `codex_boek_inschrijven.png` – Leeg Boek op de Mosslijm, inschrijf-effect (frame 3)
- `codex_gevangen.png` – "Mosslijm is ingeschreven in de Codex! Pagina 1: Lv 1, Slijmklodder."
- `codex_bondgenoot.png` – Mosslijm (rugaanzicht) naast Dennis, eigen statusvak
- `codex_bondgenoot_aanval.png` – "Mosslijm: Slijmklodder!" (bondgenoot valt aan)
- `codex_levelup.png` – level-up-pagina van de bondgenoot + nieuwe vaardigheid
- `codex_bondgenoot_kennisbeest.png` – Kennis-Beest als bondgenoot (0,75x)
- `codex_scherm.png` (384x216) – veldmenu > Codex, Glitchmot gekozen

## 11. Open punten / besluiten
- **Bron Leeg Boek**: nu 3 in de startvoorraad (winkel bestaat nog niet; `price` 60 staat klaar).
  Daardoor 2 verwachtingen in `debug_menutest.gd` aangepast. Besluit Dennis/Forge: winkel, kist, Opa?
- **Baas/geen soort/Codex vol**: boek blijft heel (weigering). Ook als poging tellen?
- Level bij vangen = tier (min. 1). Liever het level van de vijand / van Dennis?
- Bondgenoot in baasgevechten: ja (nu). Zo laten?
- Vaardigheden kosten nu geen MP (alle `mp` 0); MP-balk staat er wel.
- Geen hernoemen van pagina's, geen vrijlaten (Codex vol = 12). Fusie volgt later (velden klaar).
- dungeontest: 27 fouten (deel D/E/F/G: kamers laden niet) zijn **identiek op de ongewijzigde v16**
  (zelfde 124/27); niet door de Codex.

## 12. v0.17-versie (`code_codex_v17.patch`)
Voor v0.17 geldt `code_codex_v17.patch` (gebaseerd op een verse kopie van `/workspace/lufia_v17`).
`code_codex.patch` (v0.16) past niet op v0.17. Verschillen met de v0.16-patch:
- **Weggelaten:** de art-PNG's (`leeg_boek.png`, `inschrijf.png`, `*_rug.png`) en de `sprite_back`-regels
  in `game_data.gd`. Die staan al in v0.17. Mosslijm gebruikt in v0.17 `res://art/enemies/mosslijm_rug.png`;
  de Codex leest gewoon `ENEMIES[id].sprite_back`, het pad maakt dus niet uit.
- **Testerlijst in `game_state.gd`:** `--codextest` staat na `--woudtest`.
- **Woudmonsters als Codex-soorten (alleen data in `codex_data.gd`):**
  - `wortelkruiper` (natuur/plant)
  - `mistuil` (mist/vogel)
  - `sporenzwam` (natuur/zwam)
  - elk met `capture_rate` 0.8, eigen groei, AI en skills
  - nieuwe SKILLS: `wortelgreep`, `doornhaag`, `mistkreet`, `mistsluier`, `sporenwolk`, `zwamkuur`
- **Wortelkoning** is een baas en bewust **geen** soort, dus niet te vangen. Het boek wordt geweigerd en teruggegeven.
- **Moskonijn en Mech. Wachter** hebben nog geen rugaanzicht en tonen dus de placeholder (gespiegeld + donker).
- **Tests:**
  - de rug-check kijkt alleen of het pad eindigt op `/<id>_rug.png`
  - de check op de bondgenoot-textuur gebruikt `ENEMIES.sprite_back`
  - nieuwe checks voor de 3 woudsoorten en voor Wortelkoning (geen soort, baas)

| Suite (v0.17 + patch, Godot 4.3) | Goed | Fout |
|---|---|---|
| --codextest | 80 | 0 |
| --autotest | 442 | 0 |
| --menutest | 225 | 0 |
| --woudtest | 76 | 0 |
