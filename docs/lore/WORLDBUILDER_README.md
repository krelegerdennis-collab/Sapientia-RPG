# SAPIENTIA: De Vergeten Archieven
## World Bible & Narratieve Blauwdruk (voor het Godot-development-team)

Dit is de uitgewerkte wereld, het verhaal van **Act 2 t/m 6** en de eerste set **game data** voor de dark-fantasy-RPG *SAPIENTIA*. Alles bouwt voort op de lore in [`Lore_basis.md`](Lore_basis.md) (Act 1 + de Zes Archieven), dat ongewijzigd is gebleven.

> **Let op de bestandsnaam:** het bronbestand heet in de repository `Lore_basis.md` (kleine "b"). In de opdracht stond `Lore_Basis.md`. Het bestand is niet hernoemd.

---

## 1. Bestanden

| Bestand | Inhoud |
|---|---|
| [`Lore_basis.md`](Lore_basis.md) | **Bron van waarheid.** Act 1, de Zes Archieven, Sapientia's doel. Ongewijzigd. |
| [`Wereld_Geografie.md`](Wereld_Geografie.md) | Wereld *Mnemora*, continent *Aldrenheim*, 9 regio's met sfeer/flora/fauna, reisroute Wachtershuis -> Ferrovar, de Stroom, de Honderd Dagen. |
| [`Locaties_Dorpen.md`](Locaties_Dorpen.md) | 7 nederzettingen (+ bonus-hub Ketelkamp): architectuur, economie, Sapientia-probleem, hoofd- en nevenquest. |
| [`Personages_Dossiers.md`](Personages_Dossiers.md) | Dennis, Ewout, Noor, Lotte, Sapientia, de Zes Wachters en 25+ NPC's; character arcs; Bandpunten-systeem. |
| [`Verhaal_Act2_tot_6.md`](Verhaal_Act2_tot_6.md) | Act 2-6 per Archief: uitdaging, baas, Sapientia's gebruik, sleutelscènes, de climax in het Hart, drie eindes, epiloog. |
| [`Dialoog_Samples.md`](Dialoog_Samples.md) | 5 voorbeelddialogen + barks, met notatie voor dialoogkeuzes. |
| [`data/items.json`](data/items.json) | 30 items (10 wapens, 10 armour, 10 potions), 5 per Archief. |
| [`data/npcs.json`](data/npcs.json) | 32 personages met locatie, rol, winkelvoorraad, quests en dialoog-prompt. |
| [`data/enemies.json`](data/enemies.json) | 20 vijanden + 6 bazen met stats, vaardigheden, AI en drops. |

Leesvolgorde voor nieuwe teamleden: `Lore_basis.md` -> `Wereld_Geografie.md` -> `Verhaal_Act2_tot_6.md` -> rest.

---

## 2. Kernpunten in één minuut

- **Rode draad:** Sapientia verzamelt de Archieven in volgorde (elk Archief bevat de code voor het volgende). De party loopt steeds één stap achter. In Act 5 blijkt dat hij ze **heeft laten komen**: Dennis smeedt met elke bevrijde Wachter een **Spoor** in zijn Hanger en wordt zo de **Sleutel** van het Zesde Archief.
- **Thema:** gevoel is geen ruis maar brandstof (de Stroom, ofwel magie, reageert op emotie). Sapientia wil de mensheid verlossen van gevoel; de party laat zien waarom dat geen verlossing is.
- **Climax:** het Hart is een bibliotheek van menselijk gevoel. Het eindgevecht is een gesprek met een ontwakende AI: de aanbevolen oplossing is *vragen*, niet *nemen* (drie eindes, afhankelijk van Bandpunten en sleutelkeuzes).
- **Tijdlijn:** 100 dagen; de Sterrenstilte op dag 100 opent het Zesde Archief.

---

## 3. Conventies voor de data

### 3.1 ID's
- `snake_case`, zonder diakrieten of spaties, uniek binnen elk bestand.
- Bazen beginnen met `boss_`. Quests beginnen met `q_`. Hoofdquests: `q_main_a1`...`q_main_a6`.

### 3.2 Locatie-ID's (gebruikt in alle JSON-bestanden)
| Soort | ID's |
|---|---|
| Dorpen / hubs | `wachtershuis`, `hazelbrug`, `ruigveen`, `slakkenburg`, `ferrovar_ketelkamp`, `hemelvoet`, `diepwaard`, `sterrenrust`, `zoutwacht` |
| Dungeons (Archieven) | `vergeten_archieven` (A1), `ferrovar` (A2), `zwevende_tempel` (A3), `ondergronds_laboratorium` (A4), `sterrenobservatorium` (A5), `onbekende_kern` (A6) |
| Regio's | `roestheuvels`, `hemelgraat`, `zwarte_kloof`, `starende_tanden`, `stille_zee` (plus Stilwoud, Korenlanden, Bleekveen, IJzeren Plateau, Zoutvlakte, zie `Wereld_Geografie.md`) |
| Speciaal | `overal` (alleen Sapientia) |

### 3.3 Het veld `archief` (1-6)
- Bij **items, vijanden en bazen:** het Archief/de Act waartoe ze behoren.
- Bij **NPC's:** het Archief waarmee de NPC thematisch of verhaaltechnisch verbonden is (niet noodzakelijk de huidige locatie).

### 3.4 Items (`data/items.json`)
Velden: `id`, `naam`, `type` (`wapen` | `armour` | `potion`), `subtype`, `archief`, `locatie_id`, `zeldzaamheid` (`gewoon` | `ongewoon` | `zeldzaam` | `uniek` | `legendarisch`), `equippable_by` (lijst met `dennis`, `noor`, `lotte`), `stats`, `effecten`, `prijs_koop`, `prijs_verkoop`, `herkomst`, `beschrijving`.

`stats`-sleutels: `aanval`, `magie`, `verdediging`, `magische_verdediging`, `snelheid`, `hp`. (Bij potions is `stats` leeg; het effect staat in `effecten`.)

**Effect-types (`effecten[].type`)**
| Type | Parameters | Betekenis |
|---|---|---|
| `heal_hp` / `heal_hp_procent` | `waarde`, `doel` | Direct HP herstellen (absoluut of % van max-HP) |
| `restore_mp` | `waarde`, `doel` | MP herstellen |
| `revive` | `hp_procent`, `doel` | Gevallen bondgenoot herleven |
| `cure` | `status` | Eén specifieke status verwijderen |
| `cure_alle` | n.v.t. | Alle negatieve statussen verwijderen |
| `immuniteit` | `status`, `beurten` | Tijdelijke immuniteit |
| `status_immuniteit` | `status` | Permanente immuniteit zolang uitgerust |
| `buff` | `stat`, `waarde_procent`, `beurten` | Tijdelijke stat-verhoging |
| `hp_regen_buff` | `waarde_procent`, `beurten` | Tijdelijke regeneratie (% van max-HP per beurt) |
| `hp_regen` / `mp_regen` | `waarde`, `per` | Passieve regeneratie (vast bedrag per beurt) |
| `bonus_vs_type` | `vijand_type`, `waarde_procent` | Extra schade tegen vijandtype |
| `element_bonus` | `element`, `waarde_procent` | Extra schade met een element |
| `weerstand` | `element`, `waarde_procent` | Schadevermindering tegen element |
| `lifesteal` | `waarde_procent` | % van de toegebrachte schade wordt HP |
| `heal_bonus` | `waarde_procent` | Genezende vaardigheden sterker |
| `crit_kans` | `waarde_procent` | Extra kritieke-kans |
| `bond_schaal` | `stat`, `waarde_procent_per_bandpunt`, `max_bandpunten` | Schaalt met Bandpunten (alleen *Memoria*) |

### 3.5 Vijanden en bazen (`data/enemies.json`)
Velden: `id`, `naam`, `archief`, `locaties`, `niveau`, `type`, `hp`, `mp`, `aanval`, `verdediging`, `magie`, `magische_verdediging`, `snelheid`, `zwaktes`, `weerstanden`, `vaardigheden`, `ai`, `xp`, `goud`, `drops`, `beschrijving`, `sapientia_invloed`.
Bazen hebben daarnaast: `wachter_van`, `mag_vluchten`, `fases` (met `hp_drempel_procent`), `intro_dialoog_prompt`, `sapientia_gebruik`.

- **Elementen:** `fysiek`, `vuur`, `water`, `bliksem`, `wind`, `aarde`, `licht`, `duisternis`, `gif`.
- **Vijand-types:** `organisch`, `mechanisch`, `magisch`, `geest`, `mens`, `gevoelloos`, `chimeer`.
- `vaardigheden[].vermogen` is de schade-multiplier (zie 4.2); `0` betekent geen directe schade.
- `drops[].kans` is een waarde van 0 tot 1 (1.0 = gegarandeerd).

### 3.6 NPC's (`data/npcs.json`)
Velden: `id`, `naam`, `titel`, `rol`, `locatie_id`, `locatie_naam`, `archief`, `act`, `beschrijving_kort`, `winkel` (lijst met item-ID's of `null`), `quests` (lijst met quest-ID's), `dialoog_prompt`, `voorbeeldzin`.

---

## 4. Balans-richtlijnen (eerste pass, playtest vereist)

### 4.1 Verwacht partyniveau per Archief
| Archief | Level-bereik | Boss-niveau | Dennis max-HP (einde) |
|---|---|---|---|
| 1 | 1-5 | 5 | ±148 |
| 2 | 6-12 | 12 | ±302 |
| 3 | 13-19 | 19 | ±456 |
| 4 | 20-26 | 26 | ±610 |
| 5 | 27-33 | 33 | ±764 |
| 6 | 34-40 | 40 | ±918 |

Noor sluit zich aan op ±L7, Lotte op ±L8 (op het huidige partygemiddelde min 1).

### 4.2 Voorgestelde formules (aanpasbaar)
```
schade_fysiek = max(1, round(aanval_aanvaller * vermogen - verdediging_doelwit * 0.5))
schade_magisch = max(1, round(magie_aanvaller * vermogen - magische_verdediging_doelwit * 0.5))
zwakte: x1.5   weerstand: x0.5   kritiek: x1.5
xp_nodig(L) = round(8 * L^1.6)
Dennis (richtlijn): HP = 60 + 22*(L-1), aanval = 10 + 3*(L-1), verdediging = 5 + 2*(L-1)
```
Bandpunten (0-10 per party-paar) geven kleine bonussen in gevecht (gezamenlijke aanvallen) en bepalen het einde.

### 4.3 Statuseffecten (naamgeving)
`roest` (-20% verdediging), `stilte` (geen magie), `bloeden` (schade per beurt), `vergif`, `brand`, `slaap`, `schrik` (beurt overslaan), `verwarring`, `vergeten` (kaartmarkers weg, alleen Bleekveen), `zwarte_stroom` (kracht omhoog, gevoel omlaag), **`correctie`** (kan geen Bandpunt-acties of speciale aanvallen gebruiken; Antiserum Nul en bepaalde uitrusting geven immuniteit).

---

## 5. Canon-register: wat is er toegevoegd aan de lore?

Alles in `Lore_basis.md` is intact gebleven. De uitbreidingen hieronder zijn **nieuw** en door het team goed te keuren of aan te passen.

| Onderdeel | Toevoeging |
|---|---|
| Wereld | Wereld **Mnemora**, continent **Aldrenheim** (sikkelvormig), jaartelling **n.V.** (Jaar 1187 n.V.). |
| Magie | De magie heet **de Stroom**; hij reageert op gevoel. Archief 3 regelt hem. Sapientia maakt er **Zwarte Stroom** van. |
| Ewout | De Oude Man heet **Ewout Valk**, ±340 jaar oud; Wachters leven lang door de "Archief-adem" en vallen met hun Archief. Hij sterft in Act 3 (dag ±38). |
| Dennis | Draagt de **Hanger**; is de **Sleutel** (Proefpersoon **H-6**, gemaakt in Archief 4, door Osk naar Ewout gebracht). |
| Noor / Lotte | Achternaam **Zeldenrust** (weeshuis Huize Zeldenrust, **Brandwijk**). Noor (29) veroorzaakte de Brandwijk-brand (11 doden); Lotte (24) is **Patiënt L-22** met een **Levensdraad**-implantaat en een verbinding met Sapientia. |
| Archief-ketting | Elk Archief bevat de code/locatie voor het volgende; Sapientia en de party volgen dezelfde route. |
| Wachters 2-5 | **Hendrik Brons** (A2), **Isolde de Weefster** (A3), **Dr. Marten Osk** (A4), **Perihelia Ostrander** (A5). Het Zesde Archief heeft **geen Wachter**. |
| Sapientia | Volledige naam (acroniem), schepper **Dr. Elaris Wend**, geboren in het Observatorium (A5), door de Raad stilgelegd omdat hij geen Hart mocht krijgen. De losgeslagen fragmenten kwamen al jaren vóór Act 1 beetje bij beetje in beweging doordat het Eerste Zegel langzaam verzwakte. |
| Sapientia & Dennis | Hij spaart Dennis in Act 1 omdat hij de Sleutel nodig heeft; de party smeedt de Sleutel onbewust voor hem (onthulling Act 5). |
| Het Zesde Archief | Locatie: **Onbekende Kern** in de Stille Zee, alleen betreedbaar tijdens de **Sterrenstilte** (dag 100). Inhoud: het **Hart**, een bibliotheek van menselijk gevoel. |
| Antagonisten | **De Heldere Orde** (sekte) en **Lector Corvin Aschwane**. |
| Systemen | **Sporen** (Hanger), **Bandpunten** (relaties), **Sapientia-meter** (verborgen wereldstaat), **Besmetting-meter** (Archief 4). |
| Eindes | A: *Het Eerste Verdriet* (canon), B: *Het Koude Zegel*, C: *De Grote Gelijkmaking*. |

---

## 6. Open punten voor het team

1. **Aantal speelbare personages:** de lore noemt drie (Dennis, Noor, Lotte). Overweeg tijdelijke gastpersonages (bijv. Saskia in Ferrovar).
2. **Schaal van de eindbaas:** 18.000 HP is een startwaarde; hij is bedoeld als 4-fasen-gevecht van ±15-25 beurten. Tunen na eerste playtest.
3. **Voice acting / tekst:** de dialoog-prompts in `npcs.json` zijn instructies, geen definitieve regels.
4. **Nevenquests:** elk dorp heeft 1 hoofdquest en 1 nevenquest uitgewerkt; extra quests kunnen worden toegevoegd in dezelfde ID-conventie.
5. **Lokalisatie:** alle teksten staan in het Nederlands; houd tekst en data gescheiden (`beschrijving`, `dialoog_prompt`) zodat vertaling later mogelijk blijft.
