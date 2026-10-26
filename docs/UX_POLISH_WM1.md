# UX-polish WM1 (release fase 6): audit en fixes

> **Samengevoegd met PR #219** (`docs/ui/polish/README.md`, `--uipolishtest`). Er is één maatstok: `scripts/ui/ui_touch.gd`
> van #219 (`TOUCH_MIN` = 25 eenheden = 47,6dp op 412dp) en zijn veilige gebied (`UiTouch.insets`, `insets_override`). Deze PR
> heeft daar geen tweede helper naast. #219 beslist de tikmaat van HUD, veldmenu, Back, tekstvak-keuzes, winkels, Codex,
> Opties, Uitrusting, gevechtslijsten en co-op lobby; deze PR houdt alleen over wat #219 niet doet (titelscherm,
> slotlijst, opslag-prompt, kruis-tikvlak, Rustkamer, Action-knoppen), de Engelse tekst, het UI-geluid, de
> instellingenbug en `--uxtest`.

Scope: alleen WM1 (Wachtershuis-erf, Wilgendal, Esdoorn, Donker Woud, Archief 1, berggrot, Archief 2, World Warper-hub,
Diepe Grot) en de gedeelde UI. `wacht/wm2/` is niet gelezen. Alleen game-code en -data; geen art, geen bestaande tests,
geen workflow. Nieuwe suite: `--uxtest` (`scripts/tests/ux_tests.gd`, 118 checks, ~30 s).

## Hoe er gemeten is

- **48dp in eenheden.** Het venster is 216 eenheden hoog. Referentietoestel Galaxy S25 Ultra: 412dp korte zijde, dus
  1 eenheid = 1,9dp en 48dp = 25,2 eenheden. Minimum = **25 eenheden** (`UiTouch.TOUCH_MIN` uit #219).
- **Scherm-audit.** `--uxtest` loopt over alle zichtbare knoppen van titel, veldmenu, opslaan, slotlijst, prompt,
  dialoogkeuzes, HUD en gevecht (eigen `small_targets` in de test, tegen `UiTouch.TOUCH_MIN`). De volledige schermen-
  en profielenmatrix (16:9, 19,5:9, notch, 21:9, 4:3) is `--uipolishtest` van #219.
- **Tekst-audit.** Alle string-constanten van 36 data- en UI-scripts (5600 strings), alle `.tscn` (`map_name`,
  `npc_name`, `lines`) en een lijst met 12 Nederlandse spelersnamen. Daarnaast een lijst van verwijderde regels
  (regressiebewaking). Er is geen `namen_engels.md` in de repo (BACKLOG A5); gebruikt is de lijst in
  `docs/lore/CANON.md` ("Engelse spelersnamen").
- **Ratio's.** De suite zet het venster op 1170x540 (19,5:9 = 468x216) en 1200x540 (20:9 = 480x216) en een
  nep-notch (`UiTouch.insets_override`, 30 eenheden links en rechts).

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

### 2. Tikdoelen (48dp = 25 eenheden, `UiTouch.TOUCH_MIN`)

| # | Plek | Voor | Na | Door |
|---|---|---|---|---|
| 2.1 | HUD MENU / RUN / CORE, A/B, joystick | 22 / 18 / 25 hoog | tikvlak >= 25 | #219 |
| 2.2 | Back van elk menuscherm, veldmenu rechterkolom, tekstvak-keuzes, winkels, Codex, Opties, Uitrusting, gevechtslijsten, co-op lobby | 10-20 | 19-25 (lijstregels bewust 16, zie #219 README) | #219 |
| 2.3 | Titelscherm: New Game, Co-op, PvP, SoM, Beta Test, End State | 10-16 hoog | 25 hoog (kaartje blijft y 148..201; save-info boven het kaartje) | deze PR |
| 2.4 | Slotlijst (slots, autosave, Back), opslag-prompt Yes/No | 10-18 | 25 | deze PR |
| 2.5 | Gevecht: kruisknoppen (24x24 art) | tikvlak 24x24 | tikvlak 26x26 (plaatje en afstand 25 ongewijzigd, `CrossButton._has_point`) | deze PR |
| 2.6 | Action-knoppen Swap/Ring/Codex (`SomData.TOP_BUTTON_SIZE`) | 46x22 | 46x25 | deze PR |
| 2.7 | Rustkamer-wisselscherm (Back, knoppen) | 22 / 18 | 25 | deze PR |
| 2.8 | Opties > Music-tab (sliders, mute, tracks) | 48 eenheden (ca. 92dp; `muziek_tests` eist >= 48) | ongewijzigd | bewust |
| 2.9 | PvP-lobby | n.v.t. | niet gemeten | buiten WM1 |

Wat #219 compact houdt (lijstregels van 16 eenheden = 30dp, kruisknoppen 24) is hun besluit; `--uipolishtest` bewaakt
de rest in vijf viewportprofielen. `--uxtest` herhaalt dat niet.

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
| 4.1 | Niets las `DisplayServer.get_display_safe_area()` | gefixt door #219 (`UiTouch.insets`) in HUD, menu's, veldmenu, tekstvak |
| 4.2 | Titelscherm (384-stage, gecentreerd), HUD, veldmenu en tekstvak met twee keuzes binnen de veilige zone op 468x216 en 480x216 (nep-notch 30/30 via `UiTouch.insets_override`) | geen fout; `--uxtest` test het titelscherm, #219 de rest |
| 4.3 | World Warper-schermen (vaste 384x216) en PvP-lobby houden geen rekening met de veilige zone | niet gefixt, niet in de WM1-hoofdroute |
| 4.4 | Of Android de veilige zone aan de app geeft hangt af van de cutout-instelling van de export (`export_presets.cfg`, niet aangeraakt) | RPG Forge: controleren op de S25 Ultra |

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
- HUD-knoppen MENU / RUN / CORE: varianten van 38x25 / 46x25 / 46x25 (nu 38x14 / 46x14 / 46x17 met een groter onzichtbaar tikvlak).
- Titelscherm: knopkader 118x25 (Continue/Load/New Game/Co-op/PvP/SoM/Beta); nu alleen tekst.

## Voor RPG Forge

- Voeg `uxtest` toe aan de matrix van `.github/workflows/tests.yml` (agents mogen die niet aanpassen).
- Besluit nodig over de vastgepinde Nederlandse regels (1.11): tekst en test samen aanpassen, daarna
  `KNOWN_DUTCH_PINNED` in `ux_tests.gd` bijwerken.
