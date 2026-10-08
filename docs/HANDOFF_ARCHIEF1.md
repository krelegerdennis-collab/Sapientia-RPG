# HANDOFF – Eerste Archief v0.14 (Forge -> RPG CODE)

Project: `/workspace/lufia_v14` (versie 0.14, code 16, geen APK). Plan: `story/ARCHIEF1_PLATTEGROND.md`.
Alle 5 testsuites groen op Godot 4.3. Geheime deur, runeplaat en schatkist van de puzzelkamer zijn
PLACEHOLDERS (met de echte art van RPG ART); de deur gaat in het spel NIET open. Boss-stats en het
Vonkzwaard-item zitten er niet in (RPG CODE).

## 1. Hookpunten in de puzzelkamer 3B (`scripts/data/puzzle_rooms.gd`, kamer `archief_puzzel`)
Scène `scenes/maps/archief_puzzel.tscn` (node `ArchiefPuzzel`). Kaart 18x19: rijen 0-5 = de schatkamer
(op DEZELFDE map), rij 6 = haar onderrand met de doorgang (16,6), rijen 6-18 = de puzzelkamer.

| Teken | Tile | Node (placeholder) | Script | Data nu |
|---|---|---|---|---|
| `G` geheime deur | (16,8) + tile erboven (16,7) | `Objects/PH_geheime_deur` | `scripts/puzzle/hooks/ph_geheime_deur.gd` | `{"type": "hook", "hook": "geheime_deur", "id": "geheime_deur", "solid": true, "needs": ["plaat_s", "poort_1"], "mode": "all", "latch": true, "style": "geheim", "hint": [...], "open_lines": [...]}` |
| `s` runeplaat | (15,9) | `PuzzleFloor/PH_plaat_s` | `.../hooks/ph_runeplaat.gd` | `{"type": "hook", "hook": "runeplaat", "id": "plaat_s", "solid": false, "heavy": true, "hidden": true}` |
| `T` schatkist | (13,3) | `Objects/PH_kist_vonkzwaard` | `.../hooks/ph_schatkist.gd` | `{"type": "hook", "hook": "schatkist", "id": "kist_vonkzwaard", "solid": true, "item": "vonkzwaard", "n": 1, "flag": "kist_vonkzwaard", "lines": [...]}` |
| afdekking | rect (9,0) 9x6 + muurtegels rij 6 x9..17 | `PH_SchatkamerDek` | `PuzzleRoom._build_cover` | `"dek"` in de kamerdata |

**Inpluggen = één regel per stuk**: in `archief_puzzel.objects` `"type": "hook"` vervangen door
`"type": "secret"` (G), `"plate"` (s) en `"chest"` (T) (de velden `hook`/`solid` mogen blijven of weg),
zodra jouw `puzzle_logic.gd`/`puzzle_room.gd`-uitbreidingen erin gemerged zijn. Alle andere velden
staan al in jouw formaat. Let op: in jouw kopie lag G op (16,5); hier is het **(16,8)** (rijen 3 lager
door de 3 schatkamer-rijen erboven + muur), s (15,9), T (13,3).

Schatkamer zichtbaar maken: óf je deur roept `room.reveal_hidden_area()` aan bij openen (fade 0,4 s;
`reveal_hidden_area(false)` = direct), óf je gebruikt jouw `,`-vloer: zet dan `,` op de schatkamervloer
+ (16,6)/(16,7) en haal `"dek"` weg (één regel).

Art (zelfde bestanden als RPG ART, andere namen hier): geheime deur `assets/puzzle/geheime_deur_archief.png`
(jouw kopie verwacht `assets/puzzle/geheime_deur.png` – pad aanpassen, niet het bestand overschrijven),
runeplaat `assets/puzzle/drukplaat_rune.png`, schatkist `assets/sprites/dungeon/schatkist.png` (3 frames),
icoon `assets/ui/icons/vonkzwaard.png`. Alle in `tools/handwerk.txt`.

Placeholder-gedrag: deur blokkeert beide tiles, A = `hint`; `set_open(true)` alleen voor tests (dan beide
tiles beloopbaar, frame 3). Runeplaat: alleen plaatje, geen signaal. Kist: massief, 'De kist zit muurvast.
(komt later)'. Getest in `--puzzletest` deel C (oplossing -> X -> 3C, terug, debug-open -> schatkamer (16,5)).

Andere hookpunten:
- `PuzzleRoom.HOOK_SCRIPTS` (soort -> script met `setup(room, id, tile, data)`), `PuzzleLogic.hooks`.
- Vonkzwaard: `GameData.EQUIPMENT["vonkzwaard"]` bestaat nog NIET (jouw werk). Normale kisten
  (`DungeonChest`) geven ITEMS of EQUIPMENT; het archief-plan heeft geen gewone kist met het zwaard.
- Golem-balans: `GameData.ENEMIES["kennis_beest"]["boss"]` ongewijzigd (v13). De Golem staat in
  `DR.ROOMS["archief_golemhal"]` (baas, krijgt nooit een tier, bewaker = blijft weg na winst).
  `golem_tests.gd` laadt nu `archief_golemhal.tscn` spawn `zuid`. EXP-sim: 34 gevechten + oefengevecht =
  1311 EXP -> Lv 10 bij de Golem.
- Mech. Wachter-trucje: niets aan gedaan; tier komt bovenop zijn basis-stats in `battle.gd`
  (`GameData.apply_tier`, `GameState.pending_tier`).

## 2. Wat er verder gebouwd is (kort)
- `scripts/data/dungeon_rooms.gd`: 11 dungeonkamers (layouts uit `tools/gen_archief1_rooms.py`), `exits`
  (teken -> map+spawn), `spawns`, `tier`, `chests`, `books`, `props`, `signs`, bewakers (`guard`).
- `scripts/dungeon/dungeon_room.gd` (multi-exit, tiers, bewakers `bewaker:<kamer>/<id>` in story_flags,
  2 atlassen), `dungeon_chest.gd` (`kist:<id>`), `dungeon_prop.gd`, `dungeon_sign.gd`.
- Golemdeur (bibliotheek 4C): prop over (5,1)-(6,2), frame 1 open; bovenste rij muur, onderste rij =
  tegel 43 = uitgang `n` naar de Golemhal. Stilstaand ervoor + A: 'Achter deze deur bromt iets zwaars...'.
- `book_data.gd`: type `save_bibliotheek` (savepunt_bibliotheek.png, offset 0 op runenring 157).

## 3. Placeholder-art / openstaande art
Alle gevraagde art is geleverd (geen magenta placeholders nodig). Nog open / afwijkingen:
- Gevallen kasten (2A/2B, `o` in het plan): nu gewone decor-tegels 60/61 (geen eigen art besteld).
- Runeplaat s ligt op gewone vloer; tegel 11 (frame 0) is een zichtbare runenring, dus "verborgen tussen
  runentegels" is alleen zo als er meer runentegels omheen liggen (eventueel decor-keuze RPG ART).
- Bibliotheek: kandelaars staan op (1,7)/(10,7) i.p.v. (1,6)/(10,6): twee 16x32-kasten (rij 2-3 en 4-5)
  laten anders geen ruimte; de staande kast op rij 5 blokkeert ook rij 4.
- `leestafel.png` (los object) niet gebruikt: de tafel is tegels 138/139 uit bibliotheek_tiles.
- Niet gebruikt maar wel gekopieerd: `schatkist_2frames.png`, `zwaard_cyaan.png`, `kort_zwaard.png`,
  `onderrand_doorgang.png` (zit al als tegel 64 in `dungeon_tiles_v14.png`).

## 4. Item-iconen (RPG ART, art_iconen_v14)
24 iconen 16x16 in `assets/ui/icons/<id>.png` (ids = item/uitrusting-ids + `cat_*` categorieën), alle in
`tools/handwerk.txt`. Nog NIET in de menu's gekoppeld (optioneel). Vonkzwaard = de roze-oranje versie
(`vonkzwaard.png`, keuze Dennis); het EQUIPMENT-item `vonkzwaard` voegt RPG CODE toe.
