# HANDOFF – Glitch-fusie (Kernfragment stap 3) + de Inktwurm – RPG CODE (v0.19)

Basis: `/workspace/lufia_v18` (niet aangeraakt). Werkkopie `/workspace/code_fusie/` (kopie vr 9 okt 2026 17:18,
`.godot` verwijderd). Patch: `/workspace/code_fusie/code_fusie.patch` (unified diff, `a/` `b/`, gecontroleerd met
`cd /workspace/lufia_v18 && patch -p1 --dry-run < code_fusie.patch`; v18 is geen git-repo). Er zit GEEN art in de
patch (ook geen `.import`/`.uid`). Screenshots: `/workspace/code_fusie_shots/`. Testlogs: `/workspace/code_fusie_logs/`.

## 1. Bestanden

| Bestand | Wat |
|---|---|
| `scripts/data/codex_data.gd` | Inktwurm-soort; `FUSION_TABLE` + fusieregels (`fusion_rule`, `make_fusion_page`, `fusion_block_reason`, `is_fused`, `glitch_name`, `validate_fusion`); `glitch_name` per soort; nieuw: `base_level`, `capture_always`, kommagetal-groei, `ARCHIEF1_SPECIES`, `normal_stats_at()`, `average_growth()`; `capture_level(tier, soort)`; `clean_page` bewaart fusievelden; `give_exp` groeit via `stats_at` |
| `scripts/data/game_data.gd` | vijand `inktwurm` (uniek, Lv 5, art-paden van ART v19); `enemy_sprite()` / `enemy_sprite_is_placeholder()` + `PLACEHOLDER_ENEMY_SPRITE` (plaatsvervanger zolang de art ontbreekt) |
| `scripts/game_state.gd` | `codex_fusion_reason()`, `codex_fusion_preview()`, `codex_fuse()`; unieke monsters: `unique_done` (save-veld `"uniek"`), `is_unique()`, `unique_available()`, `unique_state()`, `unique_mark()`; `mark_defeated` markeert unieke; `--fusietest` geregistreerd; preload via `enemy_sprite()` |
| `scripts/ui/codex_screen.gd` | knop **Fusie** (en D-pad rechts), stappen kies 1 / kies 2 / voorbeeld / `Fuseren!`, paarse glitch-shader op het plaatje van een gefuseerd monster, roze naam, korte Crt-glitch na de fusie; hoofdheld-naam via `GameState.MAIN_HERO` (was 'Dennis' vast in de tekst) |
| `scripts/battle/codex_ally.gd`, `codex_battle.gd` | gefuseerde bondgenoot paars (`set_glitched`); vangen: `capture_level(tier, soort)` + `unique_mark(..., "gevangen")`; Codex-knop: `capture_hint()`, `current_ally_uid()`, `swap_choices()`, `can_swap()`, `swap_ally()`, `last_swap` |
| `scripts/battle/battle.gd` | vijand-plaatje via `GameData.enemy_sprite()`; uniek monster: geen kamer-`tier`, `level` = `encounter_level`; **Codex-knop** (§3c): `codex_command_shown()`, `_choose_codex()`, `_choose_swap()`, actie `codex_swap`, `in_battle()` (weggewisselde bondgenoot telt niet meer als doel/actor), doel-label per doel (`_select_enemy(label, prefix)`) |
| `scripts/battle/command_cross.gd` | 6e knop **Codex** (index 5, rechtsonder in het kruis), `hidden_cmds` / `is_shown()`, `open(..., hidden_list)`, D-pad: Vluchten → rechts = Codex; reserve-icoon (open boekje) zolang `assets/ui/knop_codex.png` ontbreekt |
| `scripts/battle/battle_menu.gd` | `open(..., row_h, rows_max)`: regelhoogte per menu (Codex: 16) en een venster met ▲/▼-regels (tikbaar) als de lijst langer is; `scroll()`, `row_button()` |
| `scripts/dungeon/dungeon_room.gd` | een monster in `"monsters"` waarvan `unique_available()` false is, verschijnt niet meer |
| `scripts/dungeon/map_monster.gd`, `scripts/ui/bestiary_screen.gd` | plaatsvervanger via `enemy_sprite()` als de gevechts-art ontbreekt |
| `scripts/kern/kern_kracht_veld.gd` | v0.19 haak `on_kernkracht_hit()` voor objecten (zie §3b) + `hook_target()` |
| `scripts/tests/kernkracht_tests.gd` | deel I: de haak (7 checks) |
| `scripts/tests/fusie_tests.gd` (nieuw) | `--fusietest` (deel A-G, zie §6) |
| `scripts/debug_autotest.gd`, `scripts/tests/dungeon_tests.gd` | art-checks: een vijand met `"art_pending": true` mag tijdelijk een plaatsvervanger hebben (anders faalden ze op de ontbrekende Inktwurm-art) |

## 2. Fusieregels (`CodexData.FUSION_TABLE`, `make_fusion_page`)

In het veldmenu > Codex: **Fusie** (rechtsboven, tikbaar, 44x16) of **rechts** op de D-pad →
1. kies pagina 1 → 2. kies pagina 2 (pagina 1 staat gemarkeerd met `1`; dezelfde nog eens = melding) →
3. **voorbeeld** rechts (naam, level, stats, vaardigheden, regel, wat hij erft) met `Fuseren!` / `Annuleren`.
B gaat telkens één stap terug. Na `Fuseren!`: korte glitch, melding "Fusie gelukt: X, Lv N!", de nieuwe pagina is gekozen.

| Regel | Waarde |
|---|---|
| Soort | eerste regel in `FUSION_TABLE` waarvan het ene label bij A en het andere bij B hoort (volgorde maakt niet uit). Geen regel → **glitch-variant van A**: soort van A, naam `glitch_name` (bv. Glitchwurm, Zwartmot), element van A, label `glitch` erbij |
| Level | `floor((Lv A + Lv B) / 2) + 1`, max 99 |
| Stats | stats van de soort op dat level + 10% per fusie-generatie (min +1, max 3 generaties = 30%); HP/MP vol |
| Vaardigheden | wat de soort op dat level kent + van A en van B elk de **laatst geleerde** die de nieuwe nog niet kent (`fusion.inherited`) |
| Ouders | A en B verdwijnen; de nieuwe krijgt een **nieuwe uid** (nooit hergebruikt) en komt op de plek van A |
| Bondgenoot | was A of B de bondgenoot → de nieuwe; anders blijft het zoals het was (ook 'Geen') |
| Kan niet | zelfde pagina 2x, minder dan 2 pagina's, onbekende uid, tijdens een gevecht. Codex vol (12) mag wel (daarna 11) |
| Save | `fusion: {generation, parents, parent_species, glitch, rule, inherited}`; naam, stats, vaardigheden, element/type/labels van een gefuseerde pagina blijven bij laden; kapotte fusie-data → generatie 0 |
| Uiterlijk | paars/roze: glitch-shader (verschoven banden + roze kleurrand) op het Codex-plaatje, roze naam in lijst en details, bondgenoot in het gevecht `FUSION_TINT` |

Fusietabel:

| Labels | Uitkomst | Voorbeeld |
|---|---|---|
| archief + inkt | Kennis-Beest | Mech. Wachter + Inktwurm (lore: zijn Alarm roept Inktwurmen op) |
| inkt + papier | Papiergeest | Inktwurm + Mistuil |
| inkt + ruis | Glitchmot | Inktwurm + Glitchmot |
| mos + wortel | Wortelkruiper | Mosslijm/Moskonijn + Wortelkruiper |
| mos + zwam | Sporenzwam | Mosslijm + Sporenzwam |
| vleugel + woud | Mistuil | Glitchmot/Mistuil + Wortelkruiper/Sporenzwam |
| metaal + boek | Kennis-Beest | Mech. Wachter + Kennis-Beest |

Atomair: `GameState.codex_fuse()` doet alles in één functie zonder `await`; een tweede `Fuseren!` (dubbel tikken) of
een fusie met verdwenen uids doet niets. Geen duplicatie via het scherm: het voorbeeld verandert niets (`codex_fusion_preview`).

## 3. De Inktwurm

**BESLISSING (Dennis, 9 okt 2026)** – niet als aanname:
- **Uniek**: maar 1x in het hele spel, in een nieuwe geheime kamer in Archief 1 (**kamer + plaatsing: Forge**).
  Verslagen of gevangen = nooit meer terug, ook niet na opslaan/laden (save-veld `"uniek": {"inktwurm": "gevangen"|"verslagen"}`).
- **Vangkans 100%** (ook bij volle HP), maar je hebt wel een Leeg Boek nodig (het boek gaat op).
- **Gevechtsniveau 5**, stats = **2x een normaal monster op Lv 5**.
- **Groei in de Codex 1,5x** het gemiddelde.
- **Tot Lv 7 alleen een gewone aanval; Lv 8: Inktspuw** (element inkt). AI gebruikt de vaardigheid **niet altijd: 45%** van de
  beurten (`ai.skill_chance 0.45`), anders een gewone aanval; doelwit = zwakste (lore).

Hoe 'normaal Lv 5' is afgeleid (`CodexData.normal_stats_at(5)`): gemiddelde van `stats_at(soort, 5)` (basis uit ENEMIES +
4x Codex-groei) over de gewone Archief 1-soorten `ARCHIEF1_SPECIES` = mosslijm, moskonijn, papiergeest, glitchmot,
mech_wachter (de soorten in de Archief-kamers; Kennis-Beest = baas/zeldzaam, niet meegeteld).

| | Mosslijm | Moskonijn | Papiergeest | Glitchmot | Mech. Wachter | **gemiddeld** | **x2 = Inktwurm** |
|---|---|---|---|---|---|---|---|
| HP | 30 | 30 | 32 | 24 | 54 | 34,0 | **68** |
| ATK | 15 | 17 | 17 | 22 | 20 | 18,2 | **36** |
| DEF | 6 | 7 | 7 | 6 | 16 | 8,4 | **17** |
| SPD | 7 | 20 | 8 | 22 | 9 | 13,2 | **26** |

(afronden half naar even, `GameData.round_half_even`). Verder: MAG 0, MDEF 2, MP 0, EXP 60, goud 40, zwak: vuur,
drop: Toverwater 100%, bestiarium nr. 11, habitat archief. Als vijand (Lv 5) geen vaardigheden.

Groei (`average_growth()` x 1,5): gemiddeld HP 4,4 / ATK 2,2 / DEF 1,2 / SPD 1,4 → Inktwurm **6,6 / 3,3 / 1,8 / 2,1** per
level (kommagetallen; `stats_at` rondt af, `give_exp` telt het verschil, dus na 10 levels precies +66 HP i.p.v. +44).
Gevangen = Lv 5 met precies de gevechts-stats (`base_level: 5`); Lv 8 ≈ HP 88, ATK 46, DEF 22, SPD 32.
In de fusie: labels `inkt`, `worm`; glitch-variant `Glitchwurm`.

**API voor Forge (kaart)**:
- In een kamer van `dungeon_rooms.gd`: gewoon `{"id": "inktwurm", "enemy": "inktwurm", "group": ["inktwurm"], "tile": [x, y]}`
  in `"monsters"`. `dungeon_room.gd` laat hem vanzelf weg zodra hij verslagen of gevangen is. De `"tier"` van de kamer telt
  niet voor hem (vast Lv 5).
- Eigen plaatsing (story/object): `if GameState.unique_available("inktwurm"): ...`; `GameState.unique_state(id)` geeft
  `""`, `"verslagen"` of `"gevangen"`. Zelf markeren: `GameState.unique_mark(id, "verslagen")` (eerste uitkomst telt).
- Hij zit NIET in `ENCOUNTER_GROUPS` (geen random gevecht) en staat nog in geen enkele kamer.

## 3b. Haak voor de geheime Inktwurm-kast: `on_kernkracht_hit()`

**BESLISSING (Dennis)**: de geheime kast naar de Inktwurm staat in de Golemhal (baaskamer Archief 1) en gaat alleen open
als de veld-vuurbal (Kernkracht) hem raakt, na de Golem. **Forge** bouwt de kast en de kamer; hier zit alleen de generieke haak.

- Signatuur: `func on_kernkracht_hit() -> void` (geen argumenten) op het object.
- Wanneer: in `kern_kracht_veld.gd` `fire()`, als de vuurbal door een node wordt **tegengehouden** (`trace()` →
  `hit` != null, het EERSTE obstakel binnen 3 tegels), **na de vlucht en vlak vóór de inslag**. Gezocht wordt op de geraakte node
  zelf, anders zijn **parent**, anders zijn **owner** (`hook_target()`); de eerste met de methode krijgt precies **1** aanroep per schot.
  `last_result["hook"]` = die node (voor tests).
- Niet: als de bal uitdooft zonder treffer (niets binnen bereik), bij een treffer op een muur/rand zonder methode, en nooit op
  iets achter het eerste obstakel.
- 'Na de baas': de vuurbal bestaat pas met de Golemkern (wereldvaardigheid `kernvuur`), dus de kast kan alleen na de Golem
  geraakt worden. Wil Forge het extra afdwingen: in de kast `if GameState.has_kern("golemkern")`.
- Ongewijzigd: monsters (verlamming), bazen (krijgen niets), gevecht-Kernkracht, wereldkaart en alle bestaande botsingen.
  Een map-monster met deze methode zou hem ook krijgen (geen enkel monster heeft hem).
- Voorbeeld voor de kast (Forge):
  ```gdscript
  func on_kernkracht_hit() -> void:
      if GameState.has_kern("golemkern") and not GameState.story_flags.has("inktwurm_kast_open"):
          GameState.story_flags["inktwurm_kast_open"] = true
          open()   # animatie, botsing weg
  ```

## 3c. Codex-knop in het gevecht (opdracht Dennis via Forge)

Het commandokruis heeft een 6e knop **Codex** rechtsonder (naast Vluchten, onder Verdedig), 24x24 zoals de rest,
binnen 384x216 en niet over andere knoppen. De oude knoppen 0-4 en hun D-pad-paden zijn ongewijzigd.

- **Zichtbaar**: alleen als de Codex ≥ 1 pagina OF de tas ≥ 1 Leeg Boek heeft, en NOOIT in het oefengevecht
  (`battle.tutorial`). Verborgen = niet getekend, niet te kiezen, niet te tikken. Grijs (wel zichtbaar) als er nu niets
  kan: geen boek meer over (ook niet na reserveringen van eerdere helden in deze ronde) én niet wisselen.
- **Besturing**: tikken op de knop; D-pad: vanaf Vluchten **rechts** → Codex; vanaf Codex **omhoog** → Verdedig,
  **links** → Vluchten; A = kiezen, B = terug.
- **Submenu 'Codex'** (regels 16 hoog): `Vangen  Boek xN` en `Wissel bondgenoot`. Grijs met reden:
  `Vangen: geen Leeg Boek`, `Wissel: Codex leeg` / `Wissel: alles KO`.
- **Vangen** → doel kiezen (pijltje, links/rechts of tik op de vijand); het label toont per doel de kans en de boeken:
  `Mosslijm 45% (2 boeken)`, of `te machtig` (baas), `past niet` (geen Codex-soort), `Codex vol`. Inktwurm = `100%`.
  De actie is precies dezelfde als Item > Leeg Boek (`{"type": "item", "item": "leeg_boek"}` → `codex.capture()`), dus
  dezelfde regels: weigeringen (baas, geen soort, Codex vol) geven het boek terug. Item > Leeg Boek werkt nog gewoon.
- **Wissel bondgenoot** → lijst met alleen niet-KO pagina's (`Naam LvN`, de huidige met `nu` en grijs) en onderaan
  `Geen` (grijs als er geen bondgenoot is). Lange lijst (volle Codex): 5 regels tegelijk + ▲/▼-regels; de D-pad scrolt mee.
  Kiezen **kost de beurt van de held** (actie `codex_swap`, op zijn snelheid in de ronde). Bij uitvoeren: de oude
  bondgenoot gaat terug in de Codex (HP/MP blijven op zijn pagina), de nieuwe komt op dezelfde plek (rij, statusvak) en
  wordt de actieve pagina (`GameState.codex_active`, blijft na het gevecht). De nieuwe bondgenoot handelt pas de
  VOLGENDE ronde; een actie van de oude die nog in deze ronde stond, vervalt. `Geen` = zonder bondgenoot verder.
- Art (optioneel, ART): `assets/ui/knop_codex.png` = strook 72x24 (3 frames 24x24: normaal, gekozen, uit), zoals de andere
  `knop_*.png`. Zonder dat bestand tekent de code een open boekje met paarse rug.

## 4. Art-paden voor ART (Inktwurm)

ART heeft geleverd in `/workspace/art_inktwurm_v19/out/` (LEESMIJ.txt). **Forge zet ze in het project** (niet in de patch):

| Bron (out/) | Doel in het project | Maat / anker |
|---|---|---|
| `inktwurm.png` | `res://assets/sprites/enemies/inktwurm.png` | 108x86, voeten (54, 80) = (w/2, h-6) |
| `inktwurm_rug.png` | `res://assets/sprites/enemies/inktwurm_rug.png` | zelfde canvas/anker (Codex-bondgenoot) |
| `inktwurm_idle.png` | `res://assets/sprites/enemies/inktwurm_idle.png` | 216x86, 2 frames, 0,55 s |
| `inktwurm_map.png` | `res://assets/map_monsters/inktwurm.png` (**hernoemen**) | 32x64, 2x4 frames van 16x16 |

Daarna: de 4 paden in `tools/handwerk.txt`, `"art_pending": true` (en eventueel `"sprite_placeholder"`) bij de Inktwurm in
`game_data.gd` weghalen, `--import`. Zolang de bestanden er niet zijn: gevecht/bestiarium/Codex tonen de Mosslijm als
plaatsvervanger, de kaart het verkleinde gevechtsplaatje met magenta hoekjes, de bondgenoot het gespiegelde vooraanzicht.
De screenshots zijn gemaakt MET de art (aparte kopie `/workspace/code_fusie_artcheck`, fusietest daar ook groen).

## 5. TIJDELIJKE AANNAMES

1. Fusie zit niet achter een voorwaarde (geen kern/item/plek nodig): kan altijd in het veldmenu met ≥ 2 pagina's.
2. Fusietabel, level-formule (gemiddelde + 1), +10% per generatie (max 30%), erfregel (laatst geleerde) en de glitch-namen.
3. Fusie kost niets en is niet terug te draaien; de nieuwe pagina krijgt volle HP/MP.
4. Het label `archief` van de Mech. Wachter + `inkt` → Kennis-Beest (sterkste uitkomst) – lore-knipoog naar Alarm.
5. Inktwurm: EXP 60 / goud 40 / drop Toverwater 100% (unieke beloning); MDEF 2; `resist` leeg (water bestaat niet als element).
6. Uniek 'verslagen' telt op het moment dat hij KO gaat (ook als je daarna verliest of vlucht). Vluchten vóór de KO = hij blijft.
7. Inktspuw als Codex-vaardigheid = schade x1,4 (inkt); het lore-effect 'nauwkeurigheid -20%' bestaat nog niet.
8. Een gefuseerde Inktwurm onder Lv 5 (glitch-variant met lage ouders) krijgt stats onder zijn Lv 5-waarden (lineair terug).
9. Codex-knop: plek rechtsonder in het kruis en de D-pad-route (Vluchten → rechts); wisselen gebeurt op de snelheid van de
   held (niet als eerste in de ronde); de nieuwe bondgenoot handelt pas de volgende ronde.
10. Codex-knop: de wissel-lijst toont de huidige bondgenoot grijs met `nu` (in plaats van hem weg te laten); KO-pagina's
    staan er niet in (ook de huidige niet als die KO is).
11. Codex-knop: in een baasgevecht staat de knop er gewoon (Vangen geeft 'te machtig' en kost geen boek; wisselen mag).

## 6. Tests

Runner: `/workspace/run_tests_iso.sh <project> <prefix> <suites>` (Godot 4.3 en 4.7.2 headless, sequentieel).
`--fusietest` (`scripts/tests/fusie_tests.gd`, `--alleen=ABCDEF`, `--shots=map`):
A data + regels, B randgevallen GameState (zelfde pagina 2x, maar 1 pagina, onbekende uid, vol, ouders weg, nieuwe uid,
bondgenoot A/B/geen, voorbeeld verandert niets, geen dubbele fusie, niet in gevecht), C save/load, D Codex-scherm
(tik + D-pad, B-stappen, layout: tikhoogte ≥ 16, alles binnen beeld, geen afgekapte tekst, lijst niet over de details),
E gevecht (paarse bondgenoot, Inktwurm als vijand), F Inktwurm-beslissing (100% vangen bij volle HP met slechtste worp,
boek gaat op, 2x-stats, geen tier, groei 1,5x, Inktspuw pas op Lv 8, uniek na vangen én na verslaan, save/load, oude/kapotte save,
kamer spawnt hem niet meer), G Codex-knop in het gevecht (verborgen bij 0 pagina's + 0 boeken en in het oefengevecht, plek
en D-pad, tik, submenu-regels ≥ 16 en binnen beeld, kans + boeken per doel, B-stappen, vangen kost 1 boek, wissel: alleen
niet-KO + 'Geen', kost de beurt, oude node/statusvak weg, 'Geen', volle Codex scrollt (D-pad + tik ▲), Codex vol → boek
blijft, Item > Leeg Boek werkt nog, 0 boeken → Vangen grijs, labels baas/niet-soort/Inktwurm 100%).

TESTTABEL

## 7. Screenshots (`/workspace/code_fusie_shots/`, 384x216 + `_3x`)

`fusie_kies2`, `fusie_voorbeeld`, `fusie_resultaat`, `fusie_codex` (Glitchkruiper), `fusie_bondgenoot` / `inktwurm_gevecht`
(Glitchwurm als paarse bondgenoot tegen Inktwurm + Papiergeest), `inktwurm_codex`, `codex_knop_menu` (kruis met Codex-knop +
submenu), `codex_knop_vangen` (doel-label `Mosslijm 45% (2 boeken)`), `codex_knop_wissel` (wissel-lijst).
Gevechts-shots zijn 768x432 (het gevecht rendert op een 2x-raster, = 384x216 spel-eenheden), Codex-scherm-shots 384x216.
Gemaakt met `xvfb-run -a Godot_v4.3 --rendering-driver opengl3 --path . -- --fusietest --shots=/workspace/code_fusie_shots`.
Bekeken: geen afgekapte tekst of overlap; de lange vaardighedenregel loopt netjes door op de volgende regel.

## 8. Open vragen voor Dennis

1. Moet fusie achter iets zitten (bv. pas na de Golemkern, alleen bij een savepunt-boek, of een item als kosten)?
2. Is de fusietabel goed, en mag je via fusie al een Kennis-Beest maken (Mech. Wachter + Inktwurm)?
3. Mag de unieke Inktwurm überhaupt gefuseerd worden (dan is hij weg), of moet hij beschermd zijn?
4. Inktwurm-beloning (EXP 60, goud 40, Toverwater) en 'water'-weerstand: element water toevoegen?
5. Moet Inktspuw ook het lore-effect (nauwkeurigheid -20%, 2 beurten) krijgen? Dat vraagt een nieuwe status in het gevecht.
6. Telt 'verslagen' ook als je na zijn KO het gevecht verliest (nu: ja, hij is weg)?
7. Codex-knop: moet wisselen meteen gebeuren (vóór de vijanden, zoals een 'snelle' actie) en moet de nieuwe bondgenoot nog
   in dezelfde ronde handelen? Nu: op de snelheid van de held, nieuwe bondgenoot vanaf de volgende ronde.
8. Codex-knop: mag in een baasgevecht gewisseld worden (nu: ja)? ART: komt er een `knop_codex.png`?
