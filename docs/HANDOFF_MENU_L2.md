# HANDOFF – veldmenu in Lufia 2-stijl (pakket 'menu L2', RPG CODE)

Basis: **`/workspace/lufia_v13` zoals die was op 6 okt 2026 12:25 (Europe/Amsterdam); laatste
wijziging van Forge daarin: `README.md` om 12:21** (kopie van die stand:
`/workspace/.code_menu_l2_base2_v13`). Gewerkt alleen in `/workspace/code_menu_l2/`.
Niet aangeraakt: `lufia_v9` t/m `lufia_v13`, `scripts/battle/*`, `hd_ui.gd`, `ui_style.gd`,
`debug_autotest.gd`, de puzzel- en kerkertest, het verhaal en de autosave-regels.
Patch: `/workspace/code_menu_l2/code_menu_l2.patch` = `git diff --binary` tegen die v13-stand
(zonder `.godot/` en zonder `*.uid`). De vier portretten (PNG) zitten er **binair** in; zie §8
voor de lijst als je ze liever met de hand kopieert. Toepassen in een kopie van v13:
`git apply code_menu_l2.patch` (werkt ook buiten een git-repo).

**Rebase (6 okt):** ik begon op v13 van 4 okt ~00:16 (`/workspace/.code_menu_l2_pristine_v13`).
Twee keer bijgewerkt: eerst naar de stand van 4 okt 00:57 (palet 'Inkt & Perkament' in
`ui_style.gd`, thema laden in `game_state.gd`, `command_cross.gd`, gevechtsknoppen, titel
'SAPIENTIA' + glitch, nieuwe `player.png`/`wachter.png`), daarna naar 6 okt 12:25 (Forge's
Archief-ingang/kerker: `scripts/dungeon/`, `dungeon_rooms.gd`, `archief_ingang.tscn`,
wereldkaart, Mech. Wachter + nieuwe Golem-art, map-monsters, `--dungeontest`). Bestanden die
wij allebei veranderden (`README.md`, `game_state.gd`, `game_data.gd`) vielen met een
3-weg-merge **zonder conflict** samen; de rest is 1-op-1 van v13 overgenomen.
**Forge werkte op 6 okt nog actief in v13**: alles na 12:25 zit hier niet in (de patch valt
dan waarschijnlijk nog schoon, zie §9).
Controle: de patch is met `git apply` op een verse kopie van de 12:25-stand gezet; het resultaat
is bestand voor bestand gelijk aan `code_menu_l2` (ook de PNG's). Ook `git apply --check` op de
live v13 van 12:43 (Forge had toen o.a. `battle.gd`, `game_data.gd`, kaarten en tegels weer
veranderd) lukt zonder fouten; daarop is níet getest.

## 1. Wat er gebouwd is
- **Uitrusting** (nieuw commando in het veldmenu, na Magie; volgorde nu Items, Magie,
  Uitrusting, Status, Bestiarium, Opties, Opslaan, Sluiten).
  - Links: portret, naam, klasse + Lv, HP, MP en ATK, DEF, MAG, MDEF, SPD (SPD = `agi`).
  - Rechts: vakken Wapen, Schild, Helm, Harnas, Accessoire; daaronder het submenu
    **Uitrusten, Sterkste, Afdoen, Alles afdoen, Weggooien** (2 kolommen).
  - Uitrusten > vak > lijst met stukken uit de tas die in dat vak passen en die deze held mag
    dragen. Bij elk stuk: `oud ▸ nieuw` per stat met een getekend pijltje: **groen omhoog** =
    beter, **rood omlaag** = slechter, grijs = gelijk. Hulpregel: 'Dolk: ATK +4, SPD +1'.
  - Sterkste: per vak het beste stuk (tas + wat hij draagt); daarna tonen de pijlen het
    verschil voor/na. Afdoen / Alles afdoen: terug in de tas. Weggooien: vraagt eerst
    ('X weggooien?', Nee heeft focus); dan is het stuk echt weg.
  - Tik op een vak vanuit het submenu = meteen Uitrusten in dat vak. Links/rechts of `<` `>` =
    andere held. B = een stap terug.
- **Opslaan** = eigen scherm (Lufia 2): groep met kleine portretten (hoofd 44x44) + Lv/HP/MP, de plek,
  Tijd en Goud, en rechtsonder de vraag. Slot heeft al data: **'Overschrijven?' Ja/Nee** plus
  een regel 'In het slot: Kees Lv 2, Tijd 0:00:07'. Leeg slot: 'Hier opslaan?' Ja/Nee.
  Zelfde handmatige slot (`save_path`), menu-opslaan geneest nog steeds niet, autosave apart.
- **Status**: het **portret** van RPG ART, 64x80, naar voren (was: rugaanzicht uit `dennis_rug.png` in een vak van 76x96 met wazige filter). Erbij:
  MAG en MDEF, stats als '17 (+3)' (effectief + bonus van de uitrusting), rij Spreuken.
- **Portret-hulpje** (één bestand, gebruikt door Status, Uitrusting en Opslaan).
- **Kleuren**: uit het gedeelde palet 'Inkt & Perkament' van Forge (`UiStyle`), via
  `menu_colors.gd` (§6). Pixel-scherpe tekst (Dauwpixel 10 px), regels/knoppen 16 px hoog.

## 2. Bestanden
Nieuw:
| Bestand | Doel |
|---|---|
| `scripts/equipment.gd` | Alle uitrustingsregels (geen UI): effectieve stats, uitrusten/afdoen/sterkste/weggooien, tas <-> vakken, opslaan/laden + migratie |
| `scripts/ui/equipment_screen.gd` | Het scherm Uitrusting |
| `scripts/ui/save_screen.gd` | Het opslagscherm met 'Overschrijven? Ja/Nee' |
| `scripts/ui/hero_portrait.gd` | Eén hulpje voor het plaatje van een held (portret / vooraanzicht / reserve) |
| `scripts/ui/stat_arrow.gd` | Het pijltje oud > nieuw (pixel-getekend; het font heeft geen pijl omhoog) |
| `scripts/ui/menu_colors.gd` | ALLE menukleuren (zie §6) |
| `assets/ui/portrait_dennis.png`, `portrait_noor.png`, `portrait_lotte.png`, `portrait_wachter.png` (+ `.import`) | Portretten van RPG ART (64x80), gekopieerd uit `/workspace/art_ui_v13/portraits/out/` |
| `HANDOFF_MENU_L2.md`, `code_menu_l2.patch` | dit bestand en de patch |

Aangepast:
| Bestand | Wat |
|---|---|
| `scripts/data/game_data.gd` | Helden: `mag`, `mdef`, groei `mag`/`mdef`, `equip_type`, Dennis `field_sprite`. Nieuw: `EQUIP_SLOTS`, `EQUIP_SLOT_NAMES`, `EQUIP_STATS`, `STAT_LABELS`, `EQUIPMENT` (beginnersset), `STRONGEST_WEIGHTS`. `WEAPONS` is weg (zit nu in `EQUIPMENT`) |
| `scripts/game_state.gd` | `hero_template` maakt basis + lege vakken; `give_exp` groeit op de basis; `equip_weapon` via de uitrusting (oud wapen terug in de tas); **`effective_stat` / `effective_stats`**; save/load van `equip`/`base`/`mag`/`mdef` met migratie |
| `scripts/party_actions.gd` | Uitrusting in de tas: naam, uitleg, 'Wapen: ATK +3.', melding 'Uitrusting: kies 'Uitrusting' in het menu.'; `weapons()` uit `EQUIPMENT`; `LIST_NAME_COLS` 11 -> 13 |
| `scripts/ui/field_menu.gd` | Commando Uitrusting, Opslaan opent `save_screen.gd`, kleuren |
| `scripts/ui/status_screen.gd` | Portret via het hulpje, MAG/MDEF, '17 (+3)', Spreuken |
| `scripts/ui/items_screen.gd` | Uitrusting achteraan in de lijst, grijs, met vak + bonus; kleuren |
| `scripts/ui/save_prompt.gd` | `default_no` (Nee eerst), kleuren; nu gebruikt voor 'Weggooien?' |
| `scripts/ui/ui_menu.gd` | Zachte vensterstijl (`window_style`, nieuw `inner_style`), gouden selectie |
| `scripts/ui/menu_screen.gd`, `party_card.gd`, `magic_screen.gd`, `bestiary_screen.gd`, `options_screen.gd` | Alleen kleuren -> `menu_colors.gd` |
| `scripts/debug_menutest.gd` | Nieuwe tests (§7) en bijgewerkte verwachtingen (8 commando's, opslagscherm) |
| `README.md` | Korte paragraaf over dit pakket |

Bijwerking: `ui_menu.gd` wordt ook door het titelscherm en het naamscherm gebruikt. Omdat de
menukleuren nu uit `UiStyle` komen, ziet het titelmenu er hetzelfde uit als in v13 zelf
(screenshot-vergelijking: zelfde inkt-venster, gouden rand en '>').

## 3. Nieuwe datavelden (VOORSTEL uit `story/ITEMS_ELEMENTEN.md`)
Per held in `GameData.HEROES`: `mag`, `mdef` (Dennis 2/4, Noor 10/8, Lotte 7/9), groei
`mag`/`mdef` (Dennis +0/+1, Noor +2/+2, Lotte +2/+2), `equip_type` (`krijger`/`magier`/
`priester`, i.p.v. held-id's in de data) en bij Dennis `field_sprite` = `player.png`.

Per held in het spel (`GameState.party[i]`):
- `base` = `{atk, def, mag, mdef, agi}` basis zonder uitrusting
- `equip` = `{wapen, schild, helm, harnas, accessoire}` (id of `""`)
- `atk`, `def`, `mag`, `mdef`, `agi` = **effectieve** waarde (basis + uitrusting)
- `weapon` = kopie van `equip.wapen` (oud v0.11-veld, blijft voor oude code/saves)

`EQUIPMENT` (12 stukken, ids zonder trema): `kort_zwaard`, `eiken_staf`, `dolk`,
`houten_schild`, `kaftschild`, `leren_kap`, `ijzeren_helm`, `reisgewaad`, `leren_harnas`,
`malienkolder` ('Maliënkolder'), `bladwijzer` ('Zilveren Bladwijzer'), `groenring`.
Velden: `name`, `slot`, bonussen, `wie` (equip_type's; weg = iedereen), `price`, `desc`,
optioneel `short`. Uitrusting zit in dezelfde `GameState.inventory` als de items; het gevecht
toont alleen `GameData.ITEMS`, dus uitrusting verschijnt niet in het gevechtsmenu.

**Voorlopig** (in de code gemarkeerd met VOORSTEL/VOORLOPIG):
- `kort_zwaard` = ATK **+3** zoals nu in het spel (zwaardles). Het ontwerp zegt Kort Zwaard
  ATK +7 (winkel) en een apart Roestig Zwaard ATK +3 als startwapen. Daardoor is de Dolk (ATK +4,
  SPD +1) nu sterker dan het Kort zwaard.
- `kaftschild`: waarden uit 'Beginnersset' (DEF +3, MDEF +1), niet uit 'Gebied 1' (DEF +2).
- `groenring`: 'gif-immuun' nog niet gebouwd (er is nog geen gif).
- `STRONGEST_WEIGHTS` (hoe Sterkste scoort per soort held) is mijn eigen voorstel.
- Niet erin (minimaal gehouden): Roestig Zwaard, Reisjas (start-uitrusting), Vonkzwaard,
  elementen, winkel, icoontjes.

## 4. Effectieve stats – voor Forge
Eén functie: `Equipment.effective_stats(hero)` = basis + alle uitrusting (min. 0). In
`GameState`:
```gdscript
GameState.effective_stat(hero, "mag")    # -> int (atk/def/mag/mdef/agi; andere keys = waarde in de held)
GameState.effective_stats(hero)          # -> {"atk", "def", "mag", "mdef", "agi"}
```
`hero["atk"]`, `["def"]`, `["agi"]`, `["mag"]`, `["mdef"]` worden door `Equipment.refresh()`
altijd gelijk gehouden aan die waarde. **`battle.gd` hoeft dus niets te veranderen**: het leest
`s["atk"]`/`s["def"]`/`s["agi"]` al zo, en het wapen uit het verhaal telt mee zoals voorheen.
Voor nieuwe formules (spreuk met `mag`, `mdef` van het doel; ontwerp §5) graag de getter
gebruiken. Basis veranderen? Niet `h["atk"] += x` (wordt overschreven), maar
`Equipment.grow(h, {"atk": x})` of `h["base"]` + `Equipment.refresh(h)`. `GameState.give_exp`
(die het gevecht aanroept) doet dat al. Vijanden hebben (nog) geen `mag`/`mdef`: dan 0.

## 5. Save-sleutels en migratie
`SAVE_VERSION` blijft 1; alles werkt op 'sleutel aanwezig of niet'. Per held erbij:
`"mag"`, `"mdef"` (effectief), `"base": {...}`, `"equip": {...}` (`"atk"/"def"/"agi"` blijven
de effectieve waarde, zoals in v0.13). Laden (`Equipment.load_hero`):
- geen `equip`: alleen het oude `weapon` telt (wapenvak); geen `base`: basis = opgeslagen
  waarde min de bonus van wat hij draagt (oude saves hadden de wapenbonus al in `atk`)
- geen `mag`/`mdef`: startwaarde + groei x (level - 1)
- onbekend stuk, verkeerd vak of mag hij niet dragen: vak leeg, stuk **terug in de tas** (niets kwijt)
- kapotte getallen: standaardwaarde. Autosave en handmatige save hebben hetzelfde formaat.

## 6. Kleuren
Alles in **`scripts/ui/menu_colors.gd`** (`MenuColors.TEXT`, `ACCENT`, `BETTER`, ...); de
menucode gebruikt alleen die namen. Die constanten **verwijzen nu naar `UiStyle`**
(`ui_style.gd` van Forge, zelf niet aangepast):
| MenuColors | UiStyle |
|---|---|
| TEXT, TEXT_DIM, TEXT_OFF, SHADOW | TEXT, TEXT_DIM, TEXT_OFF, SHADOW |
| WINDOW, WINDOW_INNER | INK, INK_LIGHT |
| BORDER, BORDER_DARK, LINE | BORDER, BORDER_DIM, BORDER_DIM |
| ACCENT, TITLE, ACCENT_SOFT | HILITE, HILITE, HILITE_DIM |
| INFO, KO, SAME | TEAL, KO, TEXT_OFF |
| BAR_HP, BAR_MP, BAR_LOW, BAR_EMPTY, BAR_EDGE | BAR_HP, BAR_MP, BAR_HP_LOW, BAR_EMPTY, BAR_EDGE |
| `hero_color()` | `UiStyle.accent()` (Noor GLITCH-roze, Lotte TEAL, zoals in het gevecht) |

Eigen waarden (het palet heeft er geen): `BETTER` groen en `WORSE` rood (stat-pijlen),
`ACCENT_GREY` (grijs item met focus), `DIM` (waas over de map) en `WINDOW_ALPHA` 0.90
(iets dichter dan `UiStyle.PANEL_ALPHA` 0.82, voor de vele kleine tekst). Wil Forge die in het
palet, dan alleen die regels omzetten.

## 7. Testen
```
godot --headless --path . -- --menutest
godot --headless --path . -- --autotest
godot --headless --path . -- --puzzletest
xvfb-run -a godot --path . --rendering-driver opengl3 -- --menutest --shots=/workspace/code_menu_l2_shots
```
Nieuw in `--menutest` (o.a.): data (vakken, stats, MAG/MDEF), uitrusten/afdoen/sterkste/alles
afdoen/weggooien op data én via het scherm (D-pad, A, B, tikken), wie wat mag dragen, 'niets
dubbel of kwijt' (totaal per stuk = tas + gedragen, na elke stap), stat-pijlen (richting en
kleur, beter en slechter), level-up met uitrusting, save/laden met uitrusting, oude save zonder
uitrusting, kapotte uitrusting in de save, opslagscherm (leeg slot, 'Overschrijven?', Nee laat
het bestand gelijk, Ja overschrijft), portretten (de vier bestanden van RPG ART, Status/
Uitrusting precies 64x80 met NEAREST, 2x = precies 128x160, te groot = hele deler, ook
NEAREST; fallback zonder `portrait_<id>.png` naar het vooraanzicht, nooit rugaanzicht), en dat alles binnen het scherm staat zonder afgekapte tekst.

Uitslag op 6 okt 2026 (op v13 van 6 okt 12:25), headless:
| Test | Godot 4.3 | Godot 4.7.2 |
|---|---|---|
| menutest | 225 PASS, 0 FAIL | 225 PASS, 0 FAIL |
| autotest | 405 PASS, **2 FAIL** | 405 PASS, **2 FAIL** |
| puzzletest | 127 goed, 0 fouten | 127 goed, 0 fouten |
| dungeontest (nieuw van Forge) | 99 goed, 0 fouten | 99 goed, 0 fouten |

De twee autotest-fouten zijn **niet van dit pakket** en komen precies zo (405/2) op een schone
kopie van dezelfde v13-stand zonder deze patch: Forge heeft de Mech. Wachter als bestiarium-nr.
6 toegevoegd, maar `debug_autotest.gd` verwacht nog 5 nummers ('lijst op nummer' en 'kop telt
gezien/verslagen 3/5'). Dat bestand is van Forge; ik heb het niet aangepast.
(Eerder, op de v13-stand van 4 okt 00:57, faalde daar alleen 'menu rechtsonder' op het
titelscherm in headless; onder xvfb was het toen 399/0 op beide versies. Die check slaagt nu.)
(Vóór dit werk: menutest 130, autotest 356, puzzletest 127 – op de oude v13-stand.)

Screenshots (native 384x216 + `_3x`): `/workspace/code_menu_l2_shots/` – `menu_main`,
`menu_equip`, `menu_equip_list`, `menu_equip_list_worse`, `menu_equip_strongest`, `menu_save`,
`menu_save_overwrite`, `menu_status`, `menu_status_noor`, `menu_items`, `menu_items_uitrusting`,
`menu_items_target`, `menu_magic`, `menu_options`, `title_autosave`.

## 8. Portret
Bestanden (van RPG ART, `/workspace/art_ui_v13/portraits/out/`, **gekopieerd**, niet verplaatst)
naar `assets/ui/`: `portrait_dennis.png`, `portrait_noor.png`, `portrait_lotte.png`,
`portrait_wachter.png` (alle 64x80 RGBA), elk met een `.import` (Godot 4.3, standaard 2D:
geen mipmaps). `portrait_wachter.png` wordt (nog) door geen scherm gebruikt; staat klaar.

`scripts/ui/hero_portrait.gd`, gebruikt door Status, Uitrusting en Opslaan:
- `portrait(held)`: 1) `res://assets/ui/portrait_<held-id>.png`, 2) vooraanzicht = rij 0,
  kolom 0 van `field_sprite` (3x4 loop-sheet), 3) frame 0 van de gevechtssprite (`_rug` wordt
  overgeslagen). De id komt uit de held (`MAIN_HERO` = `dennis`), nergens hard 'ruben'.
- Tekenen (`show_in`): **altijd `TEXTURE_FILTER_NEAREST`** en altijd een heel getal (1x, 2x)
  of een hele deler (1/2, 1/3) – nooit een krom formaat. Status en Uitrusting hebben een vak
  van precies 64x80 -> portret op 1x = 64x80 (2x = 128x160 past niet in 216 px hoogte met
  de stats ernaast). Het oude vak van 76x96 met LINEAR is weg.
- Opslaan (`mini_sprite`): hoofd + hals uit het portret (`MINI_CROP` = Rect2(10, 4, 44, 44),
  1:1, NEAREST), zodat de hele groep er hetzelfde uitziet; zonder portret het loopframe
  (16x24), daarna het gevechtsframe.
- Held zonder portret (bv. een nieuwe held): automatisch het vooraanzicht uit de loop-sheet,
  anders het gevechtsframe – zoals vóór de portretten.

## 9. Open vragen / bekende punten
1. **Dennis**: Kort zwaard ATK +3 (spel) of +7 (ontwerp) + een apart Roestig Zwaard? Reisjas als
   start-uitrusting? Prijzen en de Sterkste-gewichten akkoord?
2. **Dennis**: Weggooien gooit het *gedragen* stuk weg (met vraag, Nee eerst). Ook uit de tas
   kunnen weggooien? Of Weggooien helemaal weg?
3. **RPG ART**: portretten zijn binnen en in gebruik (Dennis, Noor, Lotte; Wachter staat klaar).
   Noor en Lotte hebben nog **geen loop-sheet** (`field_sprite`); in de menu's maakt dat niet
   meer uit, op de kaart wel.
4. **Forge**: palet en v13 zijn verwerkt (zie 'Rebase' bovenaan). Spreukformules met `mag`/`mdef` zijn aan
   jou. Gezien in jullie eigen v13 (niet van mij, niet aangepast): op het titelscherm loopt de
   regel 'Kees 0:00:13 (autosave)' rechts buiten het scherm (ook in de schone v13-render), en
   de autotest verwacht nog 5 bestiarium-nummers (zie §7).
5. Het opslagboek (cyaan boek) vraagt nog via het tekstvak 'Voortgang opslaan?' en niet via
   het nieuwe opslagscherm. Moet dat ook het Lufia 2-scherm worden?
6. Versienummer/APK niet aangepast (dat beslist Forge).
