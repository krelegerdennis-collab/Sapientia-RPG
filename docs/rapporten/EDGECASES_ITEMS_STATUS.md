# Edge-cases: items en status-effecten (WM1)

Branch `claude-trial/r4-6-edgecase-rapport`, basis `da0263f`. **Alleen een rapport, geen fixes.**
Scope: het beurtgevecht (`scripts/battle/battle.gd`), het veldmenu (`scripts/party_actions.gd`),
de Archief 2-vaardigheden (`scripts/data/archief2_vijanden.gd`) en het einde van een gevecht
(`scripts/game_state.gd`). De SoM-proef (`scripts/som/`) en WM2 vallen erbuiten.

## Hoe geverifieerd

- Code gelezen (regelnummers hieronder gelden voor `da0263f`).
- Een los proefscript (buiten de repo, niet toegevoegd) dat `battle.tscn` met het sim-script
  (`tools/battlesim/sim_battle.gd`, zelfde opzet als `combat_bugs_tests.gd`) opbouwt en `_execute`,
  `_tick_ailments`, `_apply_buffs` en `PartyActions.use_item` direct aanroept. Gevallen met
  **[proef]** zijn zo bevestigd; de rest volgt uit de code.
- Referentie: `-- --combatbugstest` → `RESULT OK (18 goed, 0 fouten)`.

## Hoe statussen werken (kort)

Statussen staan op de **combatant-wrapper** (`_make_combatant`, `battle.gd:361`), niet op de
held-dictionary `s` (= `GameState.party[i]`). Na het gevecht zijn ze dus vanzelf weg.

| status | sleutel | gezet in | telt af in |
|---|---|---|---|
| brand / gif (DoT) | `dots[] {pct, turns, gif?}` | `_apply_spell_status` `battle.gd:1562`, `Archief2Vijanden.apply` `archief2_vijanden.gd:41` | `_tick_ailments` `battle.gd:1584` (einde ronde) |
| genezing over tijd | `hots[] {amount, turns}` | `_add_hot` `battle.gd:1554` | `_tick_ailments` `battle.gd:1597` |
| buff (%) | `buffs[] {stat, pct, turns}` | `_apply_buffs` `battle.gd:1535` | `_tick_ailments` `battle.gd:1609` |
| oud buff-veld | `buff_<stat>` (vast getal) | `_apply_buffs` `battle.gd:1537` | **nooit** |
| beurt overslaan | `skip`, `skip_reden` | `battle.gd:1572`, `archief2_vijanden.gd:38` | alleen als de combatant aan de beurt komt (`battle.gd:1257`) |
| schild (vijand) | `guard`, `guard_mult` | `_guard_up` `battle.gd:1859` | `_guard_tick` `battle.gd:1869` |
| verdedigen | `defending` | `battle.gd:851` | reset einde ronde `battle.gd:866` |

Er bestaan in de data **geen debuffs** (alle `pct` in `scripts/data/spells.gd` zijn positief) en
vijanden **gebruiken geen items**.

## Overzicht

| # | geval | ernst | getest? |
|---|---|---|---|
| 1 | Faded Note (`h5_notitie`) is te gebruiken in het gevecht en verdwijnt zonder effect | **hoog** | nee |
| 2 | Genees-item op volle HP/MP in het gevecht wordt toch verbruikt | **midden** | nee (alleen het veld) |
| 3 | `skip` (binden/bevriezing) blijft staan door KO en revive heen | **midden** | nee |
| 4 | DoT/buffs/HoT blijven staan na KO + revive in dezelfde ronde | midden | nee |
| 5 | Buffs stapelen onbeperkt (5× Blessing = ATK ×2,49) | midden | nee |
| 6 | Gif stapelt onbeperkt (elke Sporekop-treffer +8%/ronde) | midden | deels |
| 7 | Revive-spreuk kost MP als niemand KO is | midden | nee |
| 8 | Held die door gif/brand KO gaat krijgt geen "is down!" | laag | nee |
| 9 | Genees-item op KO-doel wordt omgeleid naar een andere held | laag | nee |
| 10 | Elixir: melding "recovers 0 HP" terwijl MP wel herstelt | laag | nee |
| 11 | `_heal` in het gevecht kan HP verlagen als hp > max_hp | laag | nee |
| 12 | Stun Bomb in het gevecht: animatie + "uses", daarna "no effect" | laag | nee |
| 13 | Oud `buff_<stat>`-veld telt nooit af | laag (dode code) | nee |
| 14 | Gebonden/bevroren held kiest wel een commando, dat dan vervalt | laag | nee |
| 15 | DoT-tick negeert de "nooit KO"-regel van het oefengevecht | laag | nee |
| 16 | Gelijktijdige KO door DoT: winst gaat voor verlies | laag (ontwerp) | nee |
| 17 | HoT/buffs tellen af terwijl de held KO is | laag (ontwerp) | nee |
| 18 | Spreukrol in het gevecht: generieke "no effect" i.p.v. de reden | laag | nee |
| 19 | Inventaris houdt sleutels met aantal 0 na gebruik in het gevecht | laag | nee |
| 20 | Feniksveer-randgevallen (veld + gevecht) | ok | ja |
| 21 | Tegengif-randgevallen | ok | ja |
| 22 | Status bij einde gevecht / vluchten | ok | deels |
| 23 | Vijand-"items" (drain, buit) | ok | deels |

---

## Details

### 1. Faded Note verdwijnt in het gevecht — **hoog** [proef]
- **Waar:** `battle.gd:1100-1105` (`_available_items` neemt álle `GameData.ITEMS` met aantal > 0),
  `battle.gd:1415` (val-door naar `_heal(..., 0, 0)`); data `game_data.gd:627`.
- **Huidig:** `h5_notitie` (lore-voorwerp, 150 goud bij de Koopman, `koopman_winkel.gd:25`) staat in
  het Item-menu. Gebruiken: "Vesper uses Faded Note!", "Dax recovers 0 MP." en het briefje is weg
  (proef: aantal 1 → 0). `"field": false` blokkeert alleen het veldmenu.
- **Verwacht:** niet in het gevechtsmenu (of grijs), nooit verbruikt. Algemeen: een item zonder
  gevechtseffect (geen heal/revive/cure/capture/teach) hoort niet in `_available_items`.
- **Test:** nee.

### 2. Genees-item zonder effect wordt in het gevecht verbruikt — **midden** [proef]
- **Waar:** `battle.gd:1415` → `_heal` `battle.gd:1746`. Het veld controleert wel met
  `_would_help` (`party_actions.gd:159`, `:202`).
- **Huidig:** Potion op volle HP: "Dax recovers 0 HP.", Potion weg. Magic Water op volle MP: idem.
  De H3-regel ("pas afschrijven bij effect", `battle.gd:1373`) geldt alleen voor Feniksveer en Tegengif.
- **Verwacht:** zelfde regel als het veld: geen effect → "That has no effect right now." en niet
  verbruiken (of: bij de keuze waarschuwen). Let op: het doel kan tijdens de ronde schade krijgen,
  dus pas bij uitvoeren beslissen.
- **Test:** veld wel (`debug_menutest.gd:425`), gevecht niet.

### 3. `skip` overleeft KO en revive — **midden** [proef]
- **Waar:** `battle.gd:855-857` (KO-acteur wordt overgeslagen vóór `_execute`, dus `skip` telt niet
  af), `_revive_combatant` `battle.gd:1646` wist alleen `reported_ko`.
- **Huidig:** held gebonden (`skip=1`), daarna KO, daarna Feniksveer: eerste actie na de revive is
  "Dax is bound and skips a turn." Een ronde na opstaan dus nog een gestolen beurt.
- **Verwacht:** KO (of revive) wist `skip`/`skip_reden` (en `pulled_by`, `defending`).
- **Test:** nee (`archief2_tests.gd:1146` test alleen dat binden 1 beurt geeft).

### 4. DoT/buffs/HoT na KO + revive in dezelfde ronde — midden [proef]
- **Waar:** `_tick_ailments` `battle.gd:1586` gooit `dots` alleen weg als de held op het moment
  van de tick KO is; `_revive_combatant` `battle.gd:1646` raakt `dots`/`buffs`/`hots` niet aan.
- **Huidig:** KO en in dezelfde ronde opgewekt → gif (8%/ronde) en buffs staan er nog. Wordt hij
  pas in een latere ronde opgewekt, dan is de DoT wél weg (de tick wiste hem). Gedrag hangt dus af
  van de timing.
- **Verwacht:** één regel: KO wist alle tijdelijke statussen (dots, hots, buffs, skip, guard).
- **Test:** nee.

### 5. Buffs stapelen onbeperkt — midden [proef]
- **Waar:** `_apply_buffs` `battle.gd:1546` (altijd `append`), `_buff_mult` `battle.gd:1518`
  (vermenigvuldigt alle actieve rijen).
- **Huidig:** 5× Blessing (+20% ATK) = ATK ×1,2⁵ = **×2,49**; met Lotte (`buff_factor` 1,2 voor
  licht, `spell_rules.gd:84`) nog meer. Elke cast heeft een eigen teller (3 rondes).
- **Verwacht:** verversen i.p.v. stapelen (zelfde stat → hoogste pct, turns resetten) of een max
  (bv. 2 stapels). Balansbesluit voor Dennis.
- **Test:** nee (`battlesim_tests.gd:128` gebruikt `_buff_mult` alleen in een formulecheck).

### 6. Gif/brand stapelen onbeperkt — midden
- **Waar:** `archief2_vijanden.gd:46` en `battle.gd:1569` (altijd `append`).
- **Huidig:** elke Sporekop-giftreffer is een nieuwe rij van 8% max HP × 3 rondes; drie treffers =
  24%/ronde. Vuur/natuur-spreuken op een vijand idem (5%). Bevriezing/verlamming/binden gebruiken
  wél `maxi` (verversen, `battle.gd:1572`, `archief2_vijanden.gd:38`) — dus inconsistent.
- **Verwacht:** gif verversen (turns reset) of max-stack. Ontwerpkeuze.
- **Test:** deels — `archief2_tests.gd:1149`/`:1235` (één gifrij, tick), niet het stapelen.

### 7. Revive-spreuk kost MP zonder KO-doel — midden
- **Waar:** `battle.gd:1305` (MP eraf) vóór `battle.gd:1326` → `_revive` `battle.gd:1622`
  ("That has no effect right now.").
- **Huidig:** twee helden plannen dezelfde revive, of de held staat al op → MP weg, niets gebeurt.
  De item-variant (Feniksveer) is sinds H3 wél beschermd; de spreuk niet.
- **Verwacht:** eerst `_ko_target` controleren, pas dan MP aftrekken (zoals H3).
- **Test:** nee (`combat_bugs_tests.gd:103` test alleen een geslaagde revive-spreuk).

### 8. KO door DoT wordt niet gemeld — laag [proef]
- **Waar:** `_tick_ailments` `battle.gd:1592`, `:1618` (zet alleen de KO-pose), geen `_report_kos`.
- **Huidig:** held gaat dood aan gif: geen "Dax is down!", geen `dood`-geluid, `reported_ko` blijft
  false. (Vijanden worden in `_victory` `battle.gd:1934` nagemeld als bestiarium-kill, maar zonder
  wegfade/bericht.)
- **Verwacht:** na de ticks `_report_kos(heroes + enemies)` (melding + geluid + fade).
- **Test:** nee.

### 9. Genees-item op KO-doel wordt omgeleid — laag [proef]
- **Waar:** `_valid_ally` `battle.gd:1684-1689` (KO-doel → levende held met de laagste HP).
- **Huidig:** Potion op Dax, Dax gaat eerder in de ronde KO → Potion gaat naar Vesper (+5 HP) en is
  verbruikt. In het veld geeft dit "%s is unconscious." zonder verbruik (`party_actions.gd:183`).
- **Verwacht:** verdedigbaar (veel JRPG's doen dit), maar dan niet verbruiken als ook het nieuwe
  doel er niets aan heeft (zie #2). Documenteren als bewuste keuze.
- **Test:** nee.

### 10. Elixir-melding toont alleen HP — laag [proef]
- **Waar:** `_heal` `battle.gd:1755-1760` (`if hp > 0` → alleen HP-tekst/getal).
- **Huidig:** Elixir op held met volle HP en 0 MP: MP 0 → 34, melding "Vesper recovers 0 HP.".
  Het veld heeft `_heal_text` met beide (`party_actions.gd:149`).
- **Verwacht:** alleen wat echt herstelde tonen ("recovers 34 MP." / "X HP and Y MP.").
- **Test:** nee.

### 11. `_heal` kan HP verlagen bij hp > max_hp — laag [proef]
- **Waar:** `battle.gd:1748` (`mini(hp, max - hp)` zonder ondergrens 0). Het veld clampt wel
  (`restore`, `party_actions.gd:142`).
- **Huidig:** hp 88 / max 78, Potion → hp 78 (−10 als "genezing"). Normaal kan hp > max niet
  (`Equipment._apply_pools` clampt, `equipment.gd:215`); alleen bij een kapotte/oude save.
- **Verwacht:** `maxi(0, ...)` zoals in `restore`.
- **Test:** nee.

### 12. Stun Bomb in het gevecht — laag [proef]
- **Waar:** `battle.gd:1385` (eerst −1), `battle.gd:1409-1414` (+1 terug).
- **Huidig:** niet verbruikt (goed), maar de held doet wel "uses Stun Bomb!" + cast-animatie en dan
  "That has no effect right now.". Staat ook in het Item-menu.
- **Verwacht:** niet in het gevechtsmenu (zie #1), of de check vóór het afschrijven (H3-blok).
- **Test:** nee (`koopman_tests.gd:549` test alleen het veld).

### 13. Oud `buff_<stat>`-veld telt nooit af — laag
- **Waar:** `battle.gd:1537-1539`, gelezen in `_defense_of` `battle.gd:1879`.
- **Huidig:** alleen voor spreuken met `buff_stat` en zonder `buffs`; die bestaan nu niet in
  `spells.gd` → dode code. Zou anders het hele gevecht blijven staan en optellen.
- **Verwacht:** weghalen of laten verlopen.
- **Test:** nee.

### 14. Gebonden held kiest toch een commando — laag
- **Waar:** `_choose_commands` `battle.gd:882` kijkt niet naar `skip`; `_execute` `battle.gd:1257`
  laat de actie vervallen.
- **Huidig:** held die vorige ronde gebonden/bevroren is (na zijn eigen beurt) kiest een actie die
  daarna vervalt. Gereserveerd item wordt niet verbruikt (reservering wordt einde ronde gewist,
  `battle.gd:878`) — dus geen verlies, wel verwarrend.
- **Verwacht:** held overslaan in de keuze of de menu-tip "is bound" tonen.
- **Test:** nee.

### 15. DoT negeert oefengevecht-bescherming — laag
- **Waar:** `_hit` `battle.gd:1700-1701` (oefengevecht: nooit KO) vs. `_tick_ailments`
  `battle.gd:1592` (geen check).
- **Huidig:** als er in een oefengevecht gif/brand op een held komt, kan hij toch KO gaan.
  Oefenvijanden hebben nu geen gif, dus theoretisch.
- **Verwacht:** zelfde clamp in de tick.
- **Test:** nee.

### 16. Gelijktijdige KO door DoT — laag (ontwerp)
- **Waar:** `battle.gd:865-877`.
- **Huidig:** alle ticks lopen eerst; daarna eerst de winst-check, dan verlies. Sterven de laatste
  vijand en de laatste held tegelijk aan DoT, dan wint de party (KO-helden staan op met 1 HP,
  `game_state.gd:2485-2487`). Midden in de ronde (`battle.gd:859-864`) idem: winst eerst.
- **Verwacht:** prima, maar vastleggen als regel ("gelijkspel = winst").
- **Test:** nee.

### 17. HoT/buffs tellen af terwijl de held KO is — laag (ontwerp) [proef]
- **Waar:** `battle.gd:1599-1617`.
- **Huidig:** HoT geneest niet tijdens KO maar de beurten lopen wel af; buffs ook. Na revive
  resteert dus een deel (en zie #4).
- **Verwacht:** consistent met #4: bij KO alles wissen.
- **Test:** nee.

### 18. Spreukrol in het gevecht: reden ontbreekt — laag
- **Waar:** `battle.gd:1358-1364` gebruikt `MSG_NO_EFFECT`; het veld geeft
  `SpellRules.block_reason` (`party_actions.gd:191`, bv. "Dax cannot learn magic.").
- **Huidig:** rol niet verbruikt (goed), maar de speler ziet niet waarom.
- **Verwacht:** zelfde tekst als in het veld.
- **Test:** nee.

### 19. Sleutels met aantal 0 in de inventaris — laag [proef]
- **Waar:** `battle.gd:1365`, `:1385` (`-= 1` zonder `erase`), vs. `_take` `party_actions.gd:211`.
- **Huidig:** na gevechtsgebruik blijft `{"drankje": 0}` staan. Alle lijsten filteren op > 0
  (`items_screen.gd:89`, `shop_data.gd:210`, `koopman_winkel.gd:228`), dus onzichtbaar; wel ruis in
  saves.
- **Verwacht:** `PartyActions._take` hergebruiken.
- **Test:** nee.

### 20. Feniksveer — ok
- Veld: alleen op KO (`party_actions.gd:171-176`), max_hp 1 → 1 HP [proef], op levende held
  "no effect" en niet verbruikt. Gevecht: kiezen alleen uit KO-helden (`_select_ko`
  `battle.gd:1155`, "Nobody is knocked out." als er geen is); bij uitvoeren `_ko_target`
  `battle.gd:1635` (gekozen doel al opgestaan → eerste andere KO-held; niemand KO → niet verbruikt);
  HP geclampt op max (`battle.gd:1647`); pose en `reported_ko` hersteld.
- Twee veren op hetzelfde doel in één ronde: reservering (`battle.gd:1095`, `_items_left`) voorkomt
  meer keuzes dan voorraad; de tweede gaat naar een andere KO-held of blijft in de tas.
- Restpunt: zie #3/#4 (statussen blijven na revive).
- **Test:** ja — `combat_bugs_tests.gd` H1-H3, `koopman_tests.gd:510-513`.

### 21. Tegengif — ok
- `battle.gd:1377-1408`: alleen verbruikt bij gif-DoT of binden; haalt alleen `gif`-rijen weg
  (brand van vuur/natuur blijft — klopt met de tekst "poison and binding"). Op KO-doel → omgeleid
  via `_valid_ally` (zie #9), maar alleen verbruikt als dát doel iets te genezen heeft.
  Bevriezing/verlamming wordt níet opgeheven (alleen `skip_reden == "binding"`) — verwacht.
- Kanttekening: de test zet een gifrij met `"amount"` (`combat_bugs_tests.gd:151`), de echte rij heeft
  `"pct"`; voor deze check maakt het niet uit.
- **Test:** ja — `combat_bugs_tests.gd:144-153`, veld `koopman_tests.gd:514`.

### 22. Status bij einde gevecht / vluchten — ok
- Statussen staan op de wrapper (`battle.gd:361-364`) en verdwijnen bij winst, verlies en vluchten.
  Blijvend is alleen wat op `s` staat: HP/MP en geleerde spreuken (rol, `battle.gd:1361`).
- Winst/vluchten: KO-helden en de Codex-bondgenoot staan op met 1 HP (`game_state.gd:2484-2491`);
  EXP alleen voor levende helden (`battle.gd:1960`). Verlies: respawn/checkpoint met volle HP.
- **Test:** deels (checkpoint-suite voor verlies; niet expliciet "statussen weg na gevecht").

### 23. Vijand-"items" — ok
- Vijanden gebruiken geen items. Wel: `drain` (Bloeiende Schrik) heelt zichzelf, geclampt op max HP
  en alleen als hij leeft (`archief2_vijanden.gd:49-56`). Buit: vaste baasbuit alleen voor verslagen,
  niet-gevangen vijanden (`battle.gd:2000`). Vijanden krijgen DoT/skip van spreuken; bazen niet
  immuun voor stun (`STUN_BOSS_IMMUNE = false`, `spell_rules.gd:95`) — ontwerp.
- **Test:** deels — `archief2_tests.gd` (drain/gif/binden), `debug_autotest.gd:745` (vuur geeft
  brand, geen skip).

## Negatieve / 0-waarden

- Items met `heal_hp`/`heal_mp` 0 → zie #1 en #2 (in het gevecht "recovers 0", toch verbruikt).
- `max_mp` 0 + Magic Water in het veld → "no effect", niet verbruikt [proef]; in het gevecht verbruikt (#2).
- `revive` met `max_hp` 1 → altijd ≥ 1 HP (`maxi(1, ...)`, `party_actions.gd:219`).
- Schade minimaal 1 (`battle.gd:1495-1498`), DoT minimaal 1 per rij (`battle.gd:1591`).
- Negatieve `pct` (debuff) bestaat niet in de data; als die er komt kan `_buff_mult` met
  `pct <= -1` op 0 of negatief uitkomen (`battle.gd:1524`) — dan clampen.

## Voorstel volgorde (voor RPG Forge/CODE)

1. #1 + #12: `_available_items` alleen items met gevechtseffect laten tonen.
2. #2 + #7: H3-regel ook voor genees-items en de revive-spreuk.
3. #3 + #4 + #17: bij KO alle tijdelijke statussen wissen (één helper naast `_revive_combatant`).
4. #5 + #6: besluit Dennis over stapelen (verversen of max-stack); daarna een balansrun.
5. De rest (laag) bij gelegenheid. Bij elke fix een check in `combat_bugs_tests.gd`.
