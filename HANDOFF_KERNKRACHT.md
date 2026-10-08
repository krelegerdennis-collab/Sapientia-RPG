# HANDOFF – Kernkracht (revamp van Kernslag) – RPG CODE

Basis: `/workspace/lufia_v15` (met de Kernfragment-patch van Forge, thema archief_grijs).
Werkkopie: `/workspace/code_kernkracht/`, patch: `code_kernkracht.patch` (tegen v15, `git apply`).
lufia_v9..v16 zijn niet aangeraakt. Tutorial, blauwe Lufia-tekstballonnen, glitch per archief en de
stijl van het tekstvak (Forge, v16) zijn NIET aangeraakt; hd_ui.gd ook niet.

## 1. Naam
- In beeld heet de vaardigheid nu **Kernkracht** (gevechtsmenu, bericht "Dennis: Kernkracht!",
  statusscherm "Golemkern (Kernkracht)", absorptie-bericht).
- De interne id blijft **`kernslag`** (KERN_SKILLS-sleutel, `battle_skill` van de Golemkern,
  `kern_cd` in het gevecht). Hernoemen raakt saves/tests/Forge-code zonder winst; daarom stabiel gehouden.
- "Kernkracht" is 10 tekens: menu-regel nu `%-10s` en `KernData.SKILL_NAME_MAX = 10` (validate).

## 2. Gevecht (scripts/battle/battle.gd, minimale hook)
- Geen zwaardzwaai meer: `_kern_strike` roept bij `"fx": "vuurbal"` `_kern_fireball()` aan:
  held stapt naar voren, spreuk-pose (arm omhoog, `play_cast`), paarse vuurbal uit de opgeheven
  rechterhand (`head_position() + KERN_HAND (30,1)`) naar de vijand, dan de inslag op de vijand.
- De vijanden staan (van achter de held gezien) vlak boven/achter hem; een rechte lijn ging door zijn
  hoofd. Daarom vliegt de bal in een **boog** (16..52 eenheden hoog, hoger als het doel dichtbij is) en
  mikt hij op de zichtbare bovenkant van de vijand (`size * (0.5, 0.35)`).
- Bal x2 (`KERN_FX_SCALE`), 260 eenheden/s langs de boog (~0,35-0,5 s), inslag x2.
- **Formule en oplaadtijd ongewijzigd**: schade = ATK x 1,5 - DEF x 0,25 (+/-15%, baas-schaal via
  `_damage`), 3 rondes opladen, geen MP. Voorbeeld Lv10 (ATK 53) tegen Papiergeest (DEF 3): 67..92
  (test: 80); gewone aanval ~51.

## 3. Veld (scripts/kern/kern_kracht_veld.gd, node "KernKracht" in elke kaart via map.gd)
- **Vrijspelen**: alleen met de Golemkern, via het wereldvaardigheden-systeem: de Golemkern geeft nu
  een LIJST `["zware_blokken", "kernvuur"]` (`KernData.abilities_of()` leest id of lijst;
  `GameState.has_world_ability("kernvuur")`). Zonder kern: `can_fire() == "dicht"`, geen knop.
- **Knop (mobiel)**: paars **KERN**-pilletje (vuurbal-icoon uit de art + "KERN"), recht boven de
  A-knop, rechts uitgelijnd met A (`touch_controls.gd`: `show_kern`, `kern_rect()`, `kern_center()`).
  Alleen zichtbaar als het vrijgespeeld is en er geen tekstvak/menu/cutscene open is. De knop drukt
  de actie `kern` in. Toetsenbord: **K** (actie `kern` wordt bij het laden aangemaakt als
  project.godot hem niet kent: project.godot niet aangepast).
- **Baan**: vanaf de borst van de held, **precies 3 tegels** recht vooruit in de kijkrichting.
  Vrije baan: de bal dooft uit (kleinere inslag) midden op tegel 3.
- **Blokkade**: de bal stopt bij het EERSTE obstakel en gaat nergens doorheen. Per tegel, in volgorde:
  1. map-monster (`covers`, ook halverwege een stap) -> "monster" (bal tot midden op het monster);
  2. alles met een botsing (physics-punt-query, speler uitgezonderd): muren/massieve tegels
     (TileMapLayer, losse muur-bodies) "muur", duwkast "block", kist "chest", NPC "npc", deur "door",
     poort "gate", hendel "lever", herstelsteen "reset", geheime deur "secret", boekpunt/savepunt
     "boek", meubel "meubel", zegel/verhaal-object "story_object", bord "sign", ...;
     leesplekken (Area2D met interact) tellen ook als object ("leesplek");
  3. puzzelkamer-model (`logic.is_solid`: dichte poort, kast, hendel, steen, rand);
  4. buiten de kaart -> "rand".
  Bij een object: inslag tegen de voorkant (midden tegel - 7 px in de vliegrichting).
  Open poort (botsing uit + logica open) laat hem door.
- **Geen spam / softlock**: tijdens het schot staat de speler op slot (opladen 0,1 s + vlucht
  <= ~0,25 s + inslag 0,35 s = ~0,7 s); daarna **0,6 s cooldown**. Tijdens het schot doet de knop niets
  ("bezig"), daarna "afkoelen". Niet tijdens lopen, tekst, menu, gevecht, mapwissel of cutscene.
  Na afloop wordt de speler alleen vrijgegeven als er niets anders (tekst, gevecht, story) loopt.
- Getallen: `RANGE 3`, `STUN_STEPS 10`, `SPEED 200 px/s`, `WIND_UP 0.1`, `COOLDOWN 0.6`.

## 4. Monsters en stun (onderzoek)
- v15 heeft **zichtbare map-monsters** (scripts/dungeon/map_monster.gd) in de dungeonkamers
  (DungeonRoom, `encounters = false`). Aanraken (jij of hij) = gevecht. Ze staan al stil zolang de
  speler op slot staat (`monsters_active()`), dus ook tijdens het schot.
- Op de **wereldkaart** zijn er alleen **random encounters** (geen zichtbare monsters). Daar vliegt de
  vuurbal wel (en botst hij), maar hij heeft geen effect. **Voorstel** (niet gebouwd): "stun" daar =
  N stappen (bv. 10) geen random encounter na een schot. Graag een besluit.
- **Stun** (MapMonster): `stun(n)`, `is_stunned()`, `step_tick()`, `stun_steps`.
  - Verlamd = geen nieuwe stap (een stap die al bezig was maakt hij af), geen animatie, paars
    pulserend + 3 paarse puntjes die boven zijn kop rondjes draaien.
  - Geen gevecht bij aanraken: `monster_touch` en het vangnet in `_process` slaan verlamde monsters
    over (ook A ervoor doet niets). Hij blijft wel een obstakel (je loopt er niet doorheen).
  - Telt af per **stap van de speler** (`player.stepped` in DungeonRoom); bij 0 weer normaal.
  - Blijft staan tijdens een gevecht met een ANDER monster (zit in `get_state()` voor de terugkeer).
  - **Niet in de save**: na laden wordt de kamer opnieuw gebouwd, niemand is verlamd.
  - **Baas** (`boss = true`, bv. de Golem): geen stun, geen effect (alleen de inslag); ook een directe
    `stun()` doet niets.

## 5. Art (RPG ART, `/workspace/art_kernkracht_v15/out/`, zie LEESMIJ daar)
| pad | maat | frames | gebruik |
|---|---|---|---|
| `res://assets/fx/kern_vuurbal.png` | 64x16 | 4 x 16x16, wijst naar RECHTS, kern (10,8) | loop 0,08 s/frame; `rotation` = vliegrichting |
| `res://assets/fx/kern_vuurbal_trail.png` | 48x16 | 3 x 16x16 | elke ~2 px een spoor-sprite, 0->1->2 (0,06 s), dan weg |
| `res://assets/fx/kern_vuurbal_inslag.png` | 96x24 | 4 x 24x24, midden (12,12) | 0,07 s/frame, NIET loopen |
- De PNG's zitten in de patch (de .import-bestanden niet: Godot maakt die zelf).
- `scripts/kern/kern_vuurbal.gd` laadt ze als ze bestaan; anders een placeholder in code met dezelfde
  maten/frames. Zachte gloed = additieve radial-gradient in code (de art zelf heeft alleen volle alpha).

## 6. Bestanden
- nieuw: `scripts/kern/kern_vuurbal.gd`, `scripts/kern/kern_kracht_veld.gd`,
  `scripts/tests/kernkracht_tests.gd`, `assets/fx/kern_vuurbal*.png` (3x), dit bestand.
- gewijzigd: `scripts/data/kern_data.gd` (naam, fx, kernvuur, `abilities_of`, `SKILL_NAME_MAX`),
  `scripts/game_state.gd` (wereldvaardigheden als lijst, `--kernkrachttest`),
  `scripts/kern/kern_absorption.gd` (bericht per wereldvaardigheid: nu 4 regels),
  `scripts/battle/battle.gd` (`_kern_fireball`, menu-breedte), `scripts/map.gd` (1 regel: KernKracht-node),
  `scripts/dungeon/map_monster.gd` (stun), `scripts/dungeon/dungeon_room.gd` (stun: aanraken, aftellen,
  terugkeer), `scripts/touch_controls.gd` (KERN-knop), `scripts/tests/kern_tests.gd` (nieuwe naam,
  4 absorptie-regels, lijst).

## 7. Tests
`--kernkrachttest` (scripts/tests/kernkracht_tests.gd, optioneel `--alleen=BDF` en `--shots=map`):
- A data + art (echte PNG's, geen placeholder; placeholder heeft dezelfde maten)
- B gevecht: menu, bericht, spreuk-pose, bal met art/rotatie/spoor, inslag niet loopend, schade
  binnen de formule, opladen (2)/(1)/klaar
- C zonder Golemkern: dicht, geen knop, actie doet niets
- D precies 3 tegels (tegel 4 = muur niet geraakt), alle tegels/richtingen max 3, rotatie, art,
  lock + cooldown, 6x drukken = 1 schot, speler kan daarna lopen, KERN-knop (tik = schot), niet
  tijdens tekst
- E blokkade per soort: muur, duwkast, hendel, poort, herstelsteen (archief_test); kist + geheime
  deur (archief_puzzel); kist + muur (1B gang); savepunt-boek (ingang); leesplek + meubel
  (bibliotheek); NPC + deur + verhaal-object (Wilgendal); open poort laat door (kern_demo)
- F stun: 10 stappen (na 9 nog verlamd), geen gevecht bij aanraken, blijft na een ander gevecht,
  daarna loopt hij weer en aanraken start weer een gevecht
- G baas (Golem): geen stun/effect, bal stopt op hem
- H save/load: geen "stun" in de save, na laden niemand verlamd, Kernkracht nog vrij, knop zichtbaar

TESTTABEL: zie onder (ingevuld na de volledige run).

## 8. Screenshots (`/workspace/code_kernkracht_shots/`, elk + `_3x` = 1152x648)
- `kk_gevecht_vlucht.png` (768x432) – vuurbal in de boog van de hand naar de Papiergeest
- `kk_gevecht_inslag.png` (768x432) – inslag op de Papiergeest
- `kk_veld_vlucht.png` (384x216) – vuurbal + spoor onderweg (archief_ingang)
- `kk_veld_geblokkeerd.png` – inslag tegen een duwkast (archief_test)
- `kk_veld_monster_verlamd.png` – verlamde Mosslijm (paars + puntjes)
- `kk_veld_knop.png` – KERN-knop boven A

## 9. Open punten
- Wereldkaart: stun-betekenis bij random encounters (voorstel hierboven) – besluit nodig.
- De baan wordt bij het afvuren bepaald. Monsters staan dan stil (speler op slot); een NPC die in die
  ~0,3 s de baan in loopt wordt niet meer meegenomen.
- Op de wereldkaart is de vuurbal niet apart getest (alleen dorp, puzzel- en dungeonkamers).
- Forge (v16): de tutorial kan de KERN-knop / toets K uitleggen; de absorptie-tekst noemt al
  "Druk op KERN".
