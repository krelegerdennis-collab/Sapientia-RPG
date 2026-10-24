# UX-polish WM1 (release fase 6): audit en fixes

Scope: alleen WM1 (Wachtershuis-erf, Wilgendal, Esdoorn, Donker Woud, Archief 1, berggrot, Archief 2, World Warper-hub,
Diepe Grot) en de gedeelde UI. `wacht/wm2/` is niet gelezen. Alleen game-code en -data; geen art, geen bestaande tests,
geen workflow. Nieuwe suite: `--uxtest` (`scripts/tests/ux_tests.gd`, 175 checks, ~35 s).

## Hoe er gemeten is

- **48dp in eenheden.** Het venster is 216 eenheden hoog. Referentietoestel Galaxy S25 Ultra: 1440 px bij schaal 3,5 =
  412dp korte zijde, dus 1 eenheid = 1,91dp en 48dp = 25,2 eenheden. Minimum = **26 eenheden** (`UiTouch.MIN_UNITS`).
  Op een telefoon van 360dp is dat 29 (`UiTouch.min_units(360)`).
- **Scherm-audit.** `UiTouch.small_targets(root)` loopt over alle zichtbare knoppen en schuifregelaars. De suite opent
  titel, veldmenu met alle subschermen, opslaan, slotlijst, winkel, dialoogkeuzes, HUD, gevecht en meet ze.
- **Tekst-audit.** Alle string-constanten van 36 data- en UI-scripts (5600 strings), alle `.tscn` (`map_name`,
  `npc_name`, `lines`) en een lijst met 12 Nederlandse spelersnamen. Daarnaast een lijst van verwijderde regels
  (regressiebewaking). Er is geen `namen_engels.md` in de repo (BACKLOG A5); gebruikt is de lijst in
  `docs/lore/CANON.md` ("Engelse spelersnamen").
- **Ratio's.** De suite zet het venster op 1170x540 (19,5:9 = 468x216) en 1200x540 (20:9 = 480x216) en een
  nep-notch (`SafeArea.override`, 30 eenheden links en rechts).

## Bevindingen

### 1. Engelse tekst

| # | Vondst | Status |
|---|---|---|
| 1.1 | ECHO-warpmenu in Archief 2 volledig Nederlands: "Waarheen?", "Opslaan", "Wilgendal", "Archief-ingang", "Andere eilanden" | gefixt (`archief2_warp.gd`) |
| 1.2 | Wisselscherm Rustkamer: "Actief", "Bank", "(blijft)", "(gast)", "-> bank", "-> groep", kop "Rustkamer - wisselen is gratis" | gefixt (`party_wissel.gd`) |
| 1.3 | World Warper-gezelschap: "Niemand in het gezelschap.", "Sluiten"; ECHO-kisten "Uitrusting"/"Accessoire" | gefixt |
| 1.4 | Opslagscherm: "Hier opslaan?", "Overschrijven?", "Goud", hint "A: kies B: terug" | gefixt (`save_screen.gd`) |
| 1.5 | Gevechtsberichten: "Niemand is bewusteloos.", "is versterkt", "herstelt langzaam", "herstelt %d", "corrigeert"; doelkiezer "Doel"/"Wie?" | gefixt (`battle.gd`) |
| 1.6 | Spreukbeschrijving (Magic): "Geneest over tijd", "Versterkt" | gefixt (`party_actions.gd`) |
| 1.7 | Archief 2: bord "Een groei-plaat. Stap erop.", "Alleen Seren's licht ...", "Een Mosslijm vecht tijdelijk mee.", "%s vecht mee.", "Welk Codex-monster vecht mee?" | gefixt |
| 1.8 | Mengtaal "Archief 1 sent ... Archief 2 answered" (3 plekken) en "core of Archief 4" | gefixt ("Archive") |
| 1.9 | Codex "Erft:", fallback "Deze held", PvP-teamregels ("Gebalanceerd" e.d.), NPC-naam "Hendrik" naast "Foreman Henrik" | gefixt |
| 1.10 | Titel van het Opties-scherm "Options" terwijl het menu en de tutorial "Settings" zeggen | gefixt (kop = "Settings") |
| 1.11 | **Blijft Nederlands, vastgepind door bestaande tests:** "Dax leert geen magie." (`dungeon100_tests`, `todo_update_tests`), questtitel "Het Zingende Graan" (`woud_tests`), vaknamen "Benen"/"Laarzen" (`debug_menutest`), naam tijdelijke Codex-bondgenoot "Mosslijm" (`archief2_tests`), PvP-modi "Vroeg/Midden/Hoog" (`pvp_tests`) | **niet gefixt**: tekst en test moeten samen aangepast worden (RPG Forge). Voorstel: "Dax can't learn magic.", "The Singing Grain", "Legs"/"Boots", "Moss Slime", "Early/Mid/High". De suite bewaakt dat deze lijst niet groeit (`KNOWN_DUTCH_PINNED`). |

### 2. Tikdoelen (48dp = 26 eenheden)

| # | Plek | Voor | Na | Status |
|---|---|---|---|---|
| 2.1 | HUD MENU / RUN / KERN (tikvlak) | 46x22 / 50x18 / 54x25 | 38x26 / 46x26 / 46x26 (plaatje blijft) | gefixt (`touch_controls.gd`) |
| 2.2 | Action-knoppen Swap/Ring/Codex | 46x22 | 46x26 | gefixt (`SomData.TOP_BUTTON_SIZE`) |
| 2.3 | Back-knop van elk menuscherm; pijlknoppen `<` `>` | 16 hoog, 20 breed | 26 / 26 breed | gefixt (`menu_screen.gd`, `TOUCH_H`) |
| 2.4 | Veldmenu rechterkolom (Warp ... Load) | 20 hoog | 26 hoog (MENU-bord lager, melding/opdracht onder de linkerkolom) | gefixt |
| 2.5 | Titelscherm: New Game, Co-op, PvP, SoM, Beta Test, End State | 10-16 hoog | 26 hoog (kaartje blijft y 148..201; save-info boven het kaartje) | gefixt |
| 2.6 | Dialoogkeuzes (Yes/No, Next/Skip, acts) | ca. 11 hoog | 26 hoog; 2 keuzes naast elkaar, 3-6 in 2 kolommen, 7+ in 3 | gefixt (`dialog_box.gd`) |
| 2.7 | Bestiarium (rijen, Back), Scenes/Music-tabs, Quest Log-tabs, Items/Magic/Codex/Party-rijen | 10-24 | 26 | gefixt |
| 2.8 | Slotlijst (slots, autosave, Back), opslag-prompt, opslagscherm Yes/No | 10-18 | 26 (Yes/No naast elkaar) | gefixt |
| 2.9 | Winkels (Willowdale, Exchange, Merchant), Werkplaats | ca. 13 | 26, lange lijst scrolt | gefixt |
| 2.10 | Gevecht: kruisknoppen (24x24 art) | 24x24 | tikvlak 26x26 (plaatje en afstand 25 ongewijzigd) | gefixt (`cross_button.gd`) |
| 2.11 | Gevecht: Codex-menu (Capture/Swap) | 16 hoog, 5 regels | 26 hoog, wissel-lijst 2 regels + ▲/▼ | gefixt (`battle.gd`) |
| 2.11b | **Gevecht: Magic- en Item-lijstje** | 11 hoog | 11 hoog | **uitzondering**: de lijst staat boven het statusvak van de held; `debug_autotest` (`_check_submenu`) eist dat hij bij 3 regels niet over de helden valt. 3 regels van 26 (+ marge) zijn 90 hoog en raken de heldensprite. Voorstel: eigen volledig scherm of paginering. |
| 2.12 | Rustkamer-wisselscherm (Back, knoppen) | 22 / 18 | 26 | gefixt |
| 2.13 | Co-op lobby: minimum kwam uit het testvenster (16 eenheden = 34dp op een telefoon) | 16 | 26 | gefixt |
| 2.14 | Opties > Music-tab (sliders, mute, tracks) | 48 eenheden (ca. 92dp, `muziek_tests` eist >= 48) | ongewijzigd | bewust (te groot, wel ruim 48dp) |
| 2.15 | **Opties > General: 13 regels, `<` `>`** | 12 hoog | 12 hoog | **uitzondering**: `debug_menutest` ("alle regels in beeld") en `muziek_tests` eisen 13 regels tegelijk in 216 hoog; 13 x 26 past niet. De volumes staan ook op de Music-tab (26+). Voorstel: pagina's of scroll. |
| 2.16 | **Uitrusting: 7 vakken, submenu, itemlijst** | 16 hoog | 16 hoog | **uitzondering**: `debug_menutest` eist dat alles van het scherm (`_inside_screen`) binnen 384x216 ligt. Voorstel: vaklijst in een scroll of twee stappen. |
| 2.17 | PvP-lobby | n.v.t. | niet gemeten | buiten WM1 |

De uitzonderingen 2.15 en 2.16 zijn gemarkeerd met `touch_exempt` (`MenuScreen.META_EXEMPT`); de suite telt ze
(max 40 resp. 30) zodat er geen nieuwe bij kunnen komen zonder dat het opvalt.

### 3. Tutorials

| # | Vondst | Status |
|---|---|---|
| 3.1 | Ink Worm-tutorial: 1x (vlag staat als eerste), Skip op elke pagina, B = Skip, geen pagina 3 na Skip, nooit opnieuw | geen fout; bestaand `tutorialtest` + 7 nieuwe runtime/data-checks |
| 3.2 | Tutorialtekst wees naar "MENU > Settings > Battle Style" terwijl het scherm "Options" heette | gefixt (kop "Settings"); de suite controleert nu elk "MENU > X > Y"-pad in alle verhaaltekst tegen het echte menu |
| 3.3 | Next/Skip waren ca. 11 hoog (te klein om te raken) | gefixt (2.6) |
| 3.4 | Proloog (mantel aandoen, oefengevecht): verplicht verhaal, niet te skippen; speelt niet opnieuw (stap AVOND) en geeft een nieuwe mantel als hij weg is | geen fout; nu getest. Skip hiervoor is een ontwerpkeuze (niet gebouwd). |

### 4. 19,5:9, 20:9 en veilige zone

| # | Vondst | Status |
|---|---|---|
| 4.1 | Niets las `DisplayServer.get_display_safe_area()`: HUD, menu's en dialoog liepen tot de schermrand (camera-gat) | gefixt: `SafeArea` (0 op PC/headless) in `touch_controls.gd`, `menu_screen.gd`, `field_menu.gd`, `dialog_box.gd` |
| 4.2 | Titel (384-stage, gecentreerd), veldmenu, Items/Equipment/Quest Log/Scenes en dialoog binnen de veilige zone op 468x216 en 480x216 (nep-notch 30/30) | geen fout; getest |
| 4.3 | Coop-/PvP-lobby (volle breedte met vaste marge) en de World Warper-schermen (vaste 384x216) houden geen rekening met de veilige zone | niet gefixt, niet in de WM1-hoofdroute |
| 4.4 | Export: of Android de veilige zone aan de app geeft hangt af van de cutout-instelling van de export (`export_presets.cfg`, niet aangeraakt) | RPG Forge: controleren op de S25 Ultra |

### 5. Geluid

| # | Vondst | Status |
|---|---|---|
| 5.1 | `AudioManager.play_sfx` werd door **geen enkele UI-actie** aangeroepen (alleen molen, hub-ambience, acteur-sfx): menu's, knoppen, dialoog en opslaan waren stil. Het manifest heeft de cues al | gefixt |
| 5.2 | Nieuw: knopdruk = `menu_click` (Back = `menu_cancel`, tab = `tab_switch`, grijs = `menu_error`); cursor in een lijst = `menu_hover` (alleen na stick/pijltje, niet bij het opbouwen); veldmenu open/dicht; dialoog doorklikken, keuze, letterblip bij een sprekend personage; opslaan/laden; item gebruiken, uitrusten/afdoen, kopen/verkopen; gevechtskruis, doelkeuze, gevechtsmenu | gefixt (`UiSfx`, `AudioManager.ui_press_sounds`/`ui_cursor_sounds`) |
| 5.3 | `auto_ui_sounds` (hover overal) blijft UIT (spam bij het opbouwen van schermen) | ongewijzigd |
| 5.4 | Volume: muziek, effecten en mute worden direct naar `user://settings.cfg` geschreven, herladen na een herstart en op de bussen toegepast (ook mute en volume 0) | geen fout; nu getest (ook via het Opties-scherm) |
| 5.5 | **Bug:** een instellingenbestand met tekst bij een aan/uit-instelling (bv. `audio_mute="ja"`, met de hand of door een kapot bestand) liet `Settings._sanitize` crashen (`bool("ja")` bestaat niet in GDScript). Het laden stopte halverwege: alle instellingen na die sleutel vielen terug op de standaard (en elke start gaf een scriptfout) | gefixt (`Settings._to_bool`); getest |

## Nodig van RPG ART (niets gedaan, geen placeholders)

Alles werkt met de bestaande art. Optioneel, voor een nette 48dp-uitstraling:

- `knop_<id>.png` (gevechtskruis): strook 78x26 (3 frames 26x26) i.p.v. 72x24, zodat het plaatje het hele tikvlak vult.
- HUD-knoppen MENU / RUN / KERN: varianten van 38x26 / 46x26 / 46x26 (nu 38x14 / 46x14 / 46x17 met een groter onzichtbaar tikvlak).
- Titelscherm: knopkader 118x26 (Continue/Load/New Game/Co-op/PvP/SoM/Beta); nu alleen tekst.

## Voor RPG Forge

- Voeg `uxtest` toe aan de matrix van `.github/workflows/tests.yml` (agents mogen die niet aanpassen).
- Besluit nodig over de vastgepinde Nederlandse regels (1.11) en de twee compacte schermen (2.15, 2.16): tekst en test
  samen aanpassen.
- Daarna `KNOWN_DUTCH_PINNED` en `EXEMPT_MAX` in `ux_tests.gd` bijwerken.
