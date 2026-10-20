# HANDOFF — SoM-proef (realtime gevecht, Secret of Mana-stijl)

Proef, geen definitieve feature. Turn-based blijft het standaard en is nergens weggehaald.

## Aan/uit
- `scripts/data/som_data.gd`: `ENABLED` (hoofdschakelaar), `ROOMS` (alleen WM1-archiefkamers), alle getallen (lading, AI, bereik).
- Opties > **Battle Style: Classic / Action** (`Settings` key `battle_style`, user://settings.cfg, standaard Classic).
- Titelscherm > knop **SoM** (naast PvP): nieuwe losse voortgang (`user://som_save_1.json`), standaard-party
  (Dax lvl 3 + Vesper + Seren, vonkzwaard/houten schild/leren kap, 5 Potion, 3 Herb, 2 Magic Water) en meteen
  `archief_v1_gang` (Stoffige Gang). Zet `GameState.som_mode` (niet in de save; uit bij laden/nieuw spel/titel).
- Realtime geldt alleen als `SomData.room_enabled(room_id, som_mode or Settings.action_battles())`.

## Spelen
- **Analoge beweging** (alleen in Action): de D-pad wordt een joystick (8 richtingen, snelheid naar hoe ver je duwt,
  dode zone 20%), of pijltjes/WASD (8 richtingen). Vrije pixelbeweging met `move_and_slide` (glijdt langs muren),
  botsing 10x8 aan de voeten. `scripts/som/som_move.gd`, `player.gd set_analog()`, `touch_controls.gd joystick_mode`.
- **A** = slaan. Wapenmeter (balk boven de held + HUD) vult in **0,5 s**; slaan onder 100% = minder schade (25%..100%).
- **Party vecht mee** (`scripts/som/som_ally.gd`): Vesper en Seren volgen in formatie achter je, vallen vijanden bij je aan
  met een eigen meter, houden afstand onder 30% HP, gebruiken spreuken met MP (eerst genezen als iemand < 40% HP zit),
  teleporteren bij als ze vastzitten (1,5 s) of buiten beeld raken. Blokkeren je niet. KO = blijven liggen; opstaan met
  een item uit de ring (Phoenix Feather, 2 in de start-inventaris). Game over pas als iedereen KO is.
- **Swap** (knop naast Ring, of toets C) = besturing naar de volgende held (Dax -> Seren -> Vesper, KO overgeslagen);
  de vorige wordt AI, de camera glijdt mee, de HUD markeert de bestuurde held, de ring werkt voor hem.
  Bestuurde held KO -> automatisch wissel.
- Sprites: 24x32 WM1-kaartsprites (`assets/sprites/som/kaart/`: dax_wm1, seren_wm1, vesper), voeten op de tegelrand
  (offset (0,-8)); `SomData.SHEETS`.
- **Ring** (knop naast MENU, of Tab) = pauze: alles bevriest. Links/rechts kiezen, omhoog/omlaag Items <-> Skills,
  A kiezen, B sluiten. De keuze landt 0,35 s na het sluiten (items via `PartyActions.use_item`, spreuken uit `spells.gd`
  met MP van de caster; damage = dichtstbijzijnde/alle vijanden, heal = Dax; buffs nog niet).
- Vijanden (map-monsters uit `dungeon_rooms.gd`, stats uit `game_data.gd` + kamerniveau zoals het gevecht):
  achtervolgen binnen 7 tiles, telegraaf 0,55 s (rood knipperen + "!"), slag, cooldown 1,6 s.
- **Bazen blijven turn-based**: aanraken start het bestaande gevecht; na winst/verlies terug naar de kamer (HP/items gedeeld).
- Dax op 0 HP: "Dax has fallen..." en dezelfde afloop als een verloren gevecht (`GameState.end_battle("lose")`: checkpoint).
- Buit: EXP naar alle levende helden (`give_exp`), goud, kans-drops (`drops` chance) in de inventaris, bestiarium telt.

## Code
- `scripts/som/som_arena.gd` (SomArena: speler, AI, schade, ring-afhandeling, signalen)
- `scripts/som/som_ring.gd`, `som_hud.gd`, `som_fx.gd` (art van RPG ART, placeholder als een bestand ontbreekt)
- haakjes: `dungeon_room.gd` (`_setup_som`, `add_monster`, `monster_touch`), `game_state.gd` (`start_som_prototype`),
  `title_screen.gd` (knop), `settings.gd` + `options_screen.gd` (Battle Style).
- Tests: `scripts/tests/som_autotest.gd`, draait aan het eind van `--autotest`.
  Snel alleen SoM: `-- --## Art (RPG ART, aangesloten in v2.1) — `assets/sprites/som/{combat,fx,ui,monsters}/`
Ongewijzigd gekopieerd uit `/workspace/art_mapsprites_v4/out/combat_som/` (alleen de PNG's; `.import` wordt lokaal
gemaakt met `--import`). Monster-sheets staan in `som/monsters/` en niet in `assets/map_monsters/`, omdat bestaande
tests die map tellen. Ontbreekt een bestand, dan valt alles terug op de placeholder.
- **Aanval** (`SomData.ATTACK_ANIMS`): `<held>_attack.png` **288x192**, cellen 48x48, 6 frames x 4 rijen
  (onder, links, rechts, boven); lichaam staat op (12,16) in de cel, voeten op de onderrand (offset (0,-16)).
  Timings **120/180/50/110/90/160 ms** (totaal 710). **Schade valt op frame 4** (`hit_frame` 4 = begin van frame 4,
  350 ms na de start): `SomFx.Anim.hit` -> `SomArena._land` -> signaal `swing_landed(hero_id, hits)`.
  `attack()` geeft dan -1 terug (zonder sheet: meteen, het aantal treffers). Geldt ook voor de bondgenoten.
- **Spreuk** `seren_cast`/`vesper_cast` 144x192 (3x4), **getroffen** `<held>_hurt` 192x48 (4 richtingen),
  **KO** `<held>_ko` 48x48. **Ontwijken** `<held>_dodge` 192x48 staat in de repo maar is nog **niet aangesloten** (geen dodge-actie).
- **Monsters** (`<id>_attack` 48x64: telegraaf / uithaal 110 ms / terug 300 ms; `_hurt` 64x16; `_death` 64x16, 4x100 ms).
- **FX**: `fx_slash` 128x32, `fx_hit_spark` 64x16, `fx_telegraph` 8x8. **UI**: `dmg_digits` 50x21 (wit/rood/groen),
  gauge 18x4 + vulling 16x2 + glinster 36x4, `hud_frame` 72x20 per held, `ring_bg` 180x110, `ring_icons` 112x16 (7 iconen).
- Tests: framegrootte/rij, 350 ms-treffer (speltijd), 710 ms totaal, terug naar de loopsprite, slag landt via `swing_landed`.

### Batch ui2 (aangesloten)
- `fx/fx_heal_glow.png` 64x16 (4 x 16x16, 100 ms, anker (8,16)) op de voeten van wie geneest wordt (Minor Heal en items uit de ring).
- `fx/fx_spell_impact.png` 96x24 (4 x 24x24, 70 ms, anker (12,24)) op de voeten van elk doelwit van een aanvalsspreuk.
- `ui/btn_swap(_pressed).png`, `ui/btn_ring(_pressed).png` 38x14 als StyleBoxTexture op de Swap-/Ring-knop (de tekst zit in de art).
- `ui/joystick_ring.png` 60x60 (midden 30,30) + `joystick_knob(_pressed).png` 24x24; de knop reist max 18 art-px (`JOY_KNOB_TRAVEL`).
- `ui/ring_icons_8.png` 128x16, `RING_ICON["feniksveer"] = 7`; de oude `ring_icons.png` blijft als fallback.
- Ontbreekt een bestand: getekende placeholder (ring-effect, tekstknop, getekende joystick, 7-iconen-sheet).
