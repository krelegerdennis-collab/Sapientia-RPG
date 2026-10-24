# Save/load hardening (WM1)

Taak: opslaan en laden "kogelvrij" maken **zonder** de bestaande besluiten te wijzigen:

- atomair schrijven (`.tmp` -> rename, `.bak` blijft, `game_saved(path, ok)`; PR #171) blijft zoals het is;
- de verplichte pauze-save (app naar de achtergrond, commit `0e9178b`) blijft; een autosave bij *suspend* komt **niet** terug;
- geen versienummers, geen wijzigingen aan `.github/workflows`.

Tests: `scripts/tests/save_hardening_tests.gd`, suite `--savehardeningtest` (127 PASS). De bestaande `save_tests.gd` is niet aangepast.

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64 .github/scripts/run_suite.sh savehardeningtest
```

## Wat de suite dekt

| Deel | Wat | Hoe |
|---|---|---|
| A | Corrupte of afgekapte save valt terug op `.bak`, met een duidelijke melding | afkappen op 0, 1, 1/4, 1/2, len-1 tekens; lege file, rommel, JSON-array/-getal/-null, `{}`, verkeerde types voor `map`/`party`; beide kapot (toestand blijft ongemoeid); goede `.bak` blijft staan na een save boven een corrupte hoofd-save; `.bak` zonder hoofd-save; achtergebleven volledig `.tmp` wordt genegeerd; onleesbaar slot/autosave blokkeert 'Doorgaan' niet; slotlijst zet onleesbare slots uit |
| B | Oudere saves / ontbrekende velden -> veilige standaardwaarden | elke optionele sleutel afzonderlijk weg; elke sleutel met 9 verkeerde types; elk heldveld afzonderlijk weg; helden met alleen een `id` (Dax, Seren, Vesper, Kael, Orion); letterlijke v0.11-save (`ruben`, Dennis/Noor-namen, geen `equip`/`base`/`mag`); nieuwere versie met onbekende velden; 5 actieve helden -> 4 + reserve; negatief/absurd goud en aantallen, level < 1, HP > max |
| C | Round-trip van alle voortgang | party Dax/Seren/Vesper/Kael + Orion in de reserve, levels, gedeeltelijke HP/MP, uitrusting, tas, goud, vlaggen en verhaalstap, Codex (2 vangsten, actieve bondgenoot, volgend uid), bestiarium, kern, uniek, scenes, muziek, puzzels, Koopman, Dungeon100 (ook midden in een run), archief2, gevechtsstijl, checkpoint, positie (map/tegel/kijkrichting), speeltijd. Vergelijking op de volledige `state_data()` (byte-voor-byte), ook via slot 1..4 en de autosave; save -> load -> save is idempotent |
| D | Opslaan tijdens gevecht / menu / cutscene | pauze-save geweigerd tijdens gevecht, mapwissel, cutscene (`Story.running`), dialoog en halverwege een stap; wel toegestaan met het veldmenu open (echte kaart `wilgendal`); veldmenu opent niet tijdens cutscene/dialoog/gevecht; proces-kill tijdens een gevecht laadt de toestand van vóór het gevecht (geen verbruikte spullen of buit mee) |
| E | Geen dubbele spullen of goud | 5x laden telt niet op; A -> B -> A laden vervangt i.p.v. optelt; uitrusten/afdoen + save/load (tas + gedragen blijft constant); kist (vlag eerst, dan buit) blijft na save/load leeg, en terugdraaien draait buit én vlag samen terug; Codex-uid's worden nooit hergebruikt; checkpoint-respawn geeft geen buit mee en het checkpoint nestelt niet; Dungeon100 levert permanente items maar één keer af, ook na 2x laden |

## Gevonden en minimaal opgelost

| # | Bug | Gevolg | Fix |
|---|---|---|---|
| 1 | `battle_style` met een verkeerd type (`null`, lijst, object) in de save | `int()` gaf een `SCRIPT ERROR` midden in `load_game`: de toestand was al toegepast, maar `load_game` gaf `null`, `game_loaded` kwam nooit | type controleren, anders Classic (`game_state.gd` `load_game`) |
| 2 | Terugval op `.bak` was stil (alleen `push_warning`) | de speler wist niet dat de laatste voortgang verloren was | `GameState.save_recovered(path, backup)`, `last_load_notice` en een Engelse melding in de kaart ("Your save file was damaged." / "It was restored from the backup copy."); slotlijst toont `(backup)` |
| 3 | Een onleesbaar nieuwste bestand (geen goede `.bak`) won van een goed slot in `newest_slot_record` | 'Doorgaan' / `read_newest_save` faalde terwijl een goed slot bestond | onleesbare records worden pas gekozen als er geen goed record is |
| 4 | Onleesbaar slot was aanklikbaar op het titelscherm / in Load; titelscherm zette `set_process(false)` en zette dat bij een mislukte load niet terug | stille mislukking, titel bleef half bevroren | knop uit (label "unreadable save" bestond al); `set_process(true)` als `continue_slot` mislukt |
| 5 | Geen grenzen op getallen uit een save: negatief goud, aantallen <= 0, `1e30` (int-overflow geeft `INT_MIN`), level < 1, HP > max | negatief goud/voorraad, kapotte stats | `MAX_GOLD` (999.999.999), `MAX_ITEM_STACK` (9999), aantallen < 1 vallen weg, level >= 1, HP/MP binnen 0..max |
| 6 | `JSON.parse_string` op een kapot bestand schrijft een `ERROR:`-regel per leesactie (slotlijst leest vaak) | ruis in het log, lastig te lezen CI-uitvoer | `JSON.new().parse()`; zelfde resultaat, geen foutregel |

## Gevonden, niet aangepast (besluit nodig)

- **Molen: Zingend Meel is per bezoek.** `scripts/village/molen.gd` onthoudt "meel gegeven" als meta op de *scène* ("een nieuw bezoek is een nieuwe scène"). Een save laden bouwt een nieuwe scène, dus *save -> meel krijgen -> opslaan -> laden -> opnieuw met Gerrit praten* geeft telkens +1 (genezing 40 HP, prijs 0; uit de code gelezen, niet met een test bewezen). Dat volgt het ontwerp ("per bezoek"), maar is onbeperkt te farmen, ook via een gewone deur. Als dat niet de bedoeling is: een `story_flags`-vlag (eenmalig) of een teller per bezoek in de save. Niet aangepast: ontwerpkeuze van Dennis/Forge.
- **Dubbele held-ids in een save** (zelfde `id` twee keer in `party`/`party_bank`) laden als twee helden. Via normaal spelen kan dat niet (`add_member` controleert `has_member`), alleen via een met de hand aangepast bestand. Een dedupe op `id` breekt bestaande fixtures (`partytest`, `warperkamertest` bouwen 5-6 helden met herhaalde ids), en die tests mogen niet worden aangepast. Niet opgelost; wel onderzocht.
- **Uitrusting zowel in de tas als aan een held** in dezelfde save kan het laden niet herkennen (het bestand zegt twee keer "ik heb dit"). Normaal ontstaat dat niet: uitrusten haalt het stuk uit de tas (`equipment.gd`). Wat niet past komt wél precies één keer terug in de tas (getest).
- **`save_game()` zelf weigert niet tijdens een gevecht.** Alleen de paden eromheen blokkeren (pauze-save via `can_autosave`, veldmenu opent niet; zie deel D). Er is geen UI-pad naar een handmatige save in een gevecht, dus er is geen guard toegevoegd.
- **Tijdstempel = systeemklok.** 'Nieuwste save' vergelijkt `saved_unix`. Zet iemand de klok terug, dan kan een oudere save als nieuwste gelden. Zeldzaam, niet aangepast.
- **Volgorde `give` -> `flag`** in een paar verhaalscripts (`marit_boeken`, `zingend_zaad_na`) met een `say` ertussen. Veilig in de praktijk: tijdens een cutscene en dialoog is zowel de pauze-save als het veldmenu geblokkeerd (deel D bewijst dat). Het zou fragiel worden als iemand dat ooit versoepelt.

## CI

`savehardeningtest` (en het bestaande `savetest`) staan **niet** in de matrix van `.github/workflows/tests.yml`; dat bestand is volgens de opdracht niet aangeraakt. RPG Forge: voeg `savehardeningtest` (en eventueel `savetest`) toe aan `strategy.matrix.suite`. De suite is geregistreerd in `scripts/game_state.gd` (`_ready`, testdispatch) en draait lokaal via `run_suite.sh`.

Lokaal gecontroleerd met Godot 4.3-stable (zoals CI) én 4.7.2; alle suites uit de CI-matrix plus `savetest` en `partytest` slagen.
