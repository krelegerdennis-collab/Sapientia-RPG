# UI-polijst WM1 (touch, veilig gebied, leesbaarheid)

Doel: de bestaande WM1-schermen prettig bedienbaar maken op een Galaxy S25 Ultra (19,5:9) en op 16:9,
zonder nieuwe features en zonder pixel-art aan te raken. Alle speler-tekst blijft Engels; dit document is Nederlands.

## Maatafspraak (code: `scripts/ui/ui_touch.gd`)

Het spel rendert 384x216 eenheden over de hoogte van het scherm. Een telefoon in landschap is ~411 dp hoog
(S25 Ultra: 1080 px bij 2,625 px/dp, of 1440 px bij 3,5 px/dp), dus 1 eenheid = 1,9 dp.

| Maat | Eenheden | dp |
|---|---|---|
| `TOUCH_MIN` (knoppen die je moet raken) | 25 | 47,6 |
| `ROW_TOUCH` (lijstregels in winkel, Codex, tekstvak-keuzes, gevechtslijsten) | 25 | 47,6 |
| Commandokruis (RPG ART-art 24x24) | 24 | 45,7 |
| Gevechtslijstjes (Magic/Item/Swap), afhankelijk van de ruimte boven de helden | 16 tot 25 | 30 tot 48 |
| Gewone lijstregel (`menu_screen.ROW_H`) | 16 | 30 |

Het tikvlak mag groter zijn dan wat je ziet (`UiTouch.hit_rect`): de MENU/RUN/CORE-knoppen in de HUD hebben dezelfde
zichtbare art als eerst, maar tikken net erboven of eronder telt nu ook.

Veilig gebied: `UiTouch.insets()` geeft links/boven/rechts/onder in eenheden, uit `DisplayServer.get_display_safe_area()`
(Android: punch-hole, afgeronde hoeken, gebarenbalk; desktop/headless: nul, begrensd op 48). Tests en screenshots zetten
`UiTouch.insets_override`.

## Wat is er veranderd

Touch en tikmaat
- HUD (`touch_controls.gd`): joystick, A/B, MENU, RUN en CORE blijven binnen het veilige gebied; tikvlak van MENU/RUN/CORE >= 25 hoog.
- Alle menuschermen (`menu_screen.gd`, Bestiary): onzichtbaar tikvlak rond Back (>= 25 x 25, tot de schermrand), venster en inhoud binnen het veilige gebied.
- Veldmenu: rechterkolom (Warp ... Load) 20 -> 25 hoog.
- Tekstvak: keuzeregels 11 -> 25 hoog. Korte keuzes (Yes/No, Next/Skip) staan zoals altijd rechtsonder onder elkaar; langere
  keuzes (tot 3) staan op een rij onderin het vak, zodat het vak laag blijft en de speler niet bedekt (bestaande plaatsingstests);
  bij 4+ keuzes staan ze onder elkaar met 20 hoog. Tikken werkt op de hele regel; bij een rij werkt ook links/rechts.
- Gevecht: Magic/Item/Codex-lijsten 11 of 16 -> 25 per regel, maar nooit hoger dan er boven de helden past (de bestaande autotest
  eist dat het lijstje niet over de helden valt): 25 bij 1 tot 2 regels, 19 bij 3 regels, minimaal 16. Venster en pijlregels als er meer dan 5 zijn.
- Winkel (Wilgendal en Koopman): regels 16 -> 25, lijst scrolt met de vinger of de joystick.
- Codex: lijstregels, Fusion-knop en Back 16 -> 25.
- Opslaan: Yes/No 16 -> 25.
- Co-op lobby: knoppen 16 -> 25 en met zichtbaar kader.

Layout die buiten beeld viel
- Uitrusting: 7 vakken pasten niet meer; de hulpregel en 'Remove' vielen onder de rand. Marges aangescherpt.
- Opties: 13 regels op 216 hoog; hulpregel en laatste regels vielen onder de rand (de bestaande menutest ziet dat niet, hij vergelijkt alleen de regel met de hulpregel). Nu twee kolommen (7 + 6), regels 13 -> 19 hoog.
- Tekstvak met keuzes: de eerste plek kon boven het scherm vallen (naamtabje weg). Plekken die niet passen vallen af.
- Gevecht: label van de Codex-bondgenoot kapte "Moss Slime" af tot "Moss." (nu 76 breed).
- Veldmenu: opdrachtregel overlapt de rechterkolom niet meer bij een onderrand-inset.

Leesbaarheid
- Co-op lobby: tekst van 8 en 9 -> 10 (titels 12); het pixelfont is voor 10 gemaakt.
- Lettertekens die het pixelfont niet heeft (`…`, U+2011 in "Wi-Fi", `±`) vervangen door `...`, `-` en `~`.
- Bestiary, Codex, Items: de lijst scrolt nu mee met de focus (`follow_focus`); met de joystick verdween de cursor onder de rand.

Consistent terug
- B (cancel) sluit elk menuscherm, gaat in de winkel eerst terug naar Buy, gaat in een gevechtslijst terug naar het kruis en in de lobby een stap terug. De suite test dit per scherm.

Engelse tekst
- Opslaan: "Save here?", "Overwrite?", "Gold", "A: choose   B: back" (waren Nederlands).
- Gevecht: "Nobody is knocked out." (was "Niemand is bewusteloos.").
- Codex-voorbeeld: "Inherits:" (was "Erft:").

## Screenshots (headless)

`before/` = `main` (c55b77b + de screenshot-tool), `after/` = deze branch. Per scherm een PNG per profiel:
`<scherm>_<profiel>.png`. Schermen zijn 1x spelpixels (384 tot 504 breed); gevechten staan op 0,75 van het fijne 2x-raster
(702 breed, 96 kleuren) om de bestanden klein te houden.

| Profiel | Viewport (eenheden) | Wat het nabootst |
|---|---|---|
| `16x9` | 384 x 216 | 16:9 |
| `19_5x9` | 468 x 216 | S25 Ultra (3120x1440 of 2340x1080) |
| `19_5x9_notch` | 468 x 216 + inset (22, 4, 10, 6) | idem, met gesimuleerde punch-hole links, hoeken en gebarenbalk |
| `21x9` | 504 x 216 | extra breed |
| `4x3_hoog` | 384 x 288 | tablet, 'hoog' |

Schermen: `title`, `hud`, `dialog_narrator`, `dialog_choices`, `menu_main`, `menu_items`, `menu_equipment`, `menu_magic`,
`menu_status`, `menu_codex`, `menu_bestiary`, `menu_party`, `menu_quests`, `menu_options`, `menu_save`, `shop_buy`,
`shop_sell`, `shop_merchant`, `lobby_menu`, `lobby_host`, `lobby_join`, `battle_cross`, `battle_magic`, `battle_target`.
De scanlines (CRT) staan uit in de screenshots, zodat tekst en randen goed te beoordelen zijn.

Opnieuw maken:

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
XDG_DATA_HOME=/tmp/xdg_ui xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --uishots --shots=/tmp/shots \
    [--profiles=16x9,19_5x9_notch] [--only=menu_main,hud]
```

Scenario's en profielen staan in `tools/ui_polish/ui_scenarios.gd`.

## Tests

`--uipolishtest` (`scripts/tests/ui_polish_tests.gd`): per profiel de echte schermen openen en meten: tikvlakken, binnen het
veilige gebied, geen afgekapte knoppen, geen ontbrekende glyphs, geen tekst kleiner dan 10 (lobby), B/Cancel per scherm.

```bash
GODOT=$GODOT .github/scripts/run_suite.sh uipolishtest
```

De suite staat nog niet in de CI-matrix (`.github/workflows/tests.yml` is niet voor agents): RPG Forge moet `uipolishtest` toevoegen.

## Bewust niet aangepast

- Titelscherm en `save_slot_list` (Co-op/PvP/SoM/Continue/Load/New Game zijn 16 hoog): de bestaande titeltests leggen het menu vast op y 148..200.
- Gewone lijstregels in Items, Magic, Status, Party, Quest Log en Bestiary blijven 16 (30 dp). Meer dan 6 regels per scherm vraagt scrollen; dat is een ontwerpkeuze voor Dennis.
- Commandokruis blijft 24 (RPG ART-maat, 45,7 dp).
- Action-HUD Swap/Ring (`SomData.TOP_BUTTON_SIZE` 46x22): `hud_tests` leunen op die maat.
- PvP-lobby (`pvp/`) en World Warper-hub (`world_warper/services`): niet in deze ronde.

## Open punten (bestaande tests blokkeren een fix)

`scripts/debug_menutest.gd` toetst letterlijk deze Nederlandse speler-tekst, dus de tekst kan pas mee als die test mee mag:
- Uitrusting: vaknamen "Benen" en "Laarzen" (`Equipment.slot_name`), test regel 1017 en 1156.
- World Warper Party-service: knop "Sluiten" (`world_warper/services/party_select.gd`), `echo_kisten.gd` ("Uitrusting", "Accessoire").
- PvP-schermen gebruiken `…` (niet in het pixelfont) en tekst van 8 (`pvp/scripts/ui/*`).
- De bestaande menutest "alle regels in beeld" (Opties) vergelijkt alleen de laatste regel met de hulpregel en ziet daardoor niet dat beide buiten beeld konden vallen.
