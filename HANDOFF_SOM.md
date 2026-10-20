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
- `scripts/som/som_ring.gd`, `som_hud.gd`, `som_fx.gd` (placeholders)
- haakjes: `dungeon_room.gd` (`_setup_som`, `add_monster`, `monster_touch`), `game_state.gd` (`start_som_prototype`),
  `title_screen.gd` (knop), `settings.gd` + `options_screen.gd` (Battle Style).
- Tests: `scripts/tests/som_autotest.gd`, draait aan het eind van `--autotest`.
  Snel alleen SoM: `-- --autotest --som-only [--som-shots=/pad]`.

## Art voor de volledige versie (RPG ART) — basis 24x32-helden
Haakje: `SomData.ATTACK_ANIMS` (per held-id `sheet`, `frame`, `frames`, `fps`). Staat het bestand er, dan speelt het
automatisch i.p.v. de magenta placeholder-boog (`som_fx.gd attack_anim`). Geen code nodig, alleen het bestand.
- **Aanval per held** (Dax, Vesper, Seren): frames **48x48**, 4 rijen (onder, links, rechts, boven) x **4 frames**
  -> sheet **192x192**. `assets/sprites/som/aanval/dax_aanval.png`, `vesper_aanval.png`, `seren_aanval.png`.
  Anker: het 24x32-lichaam staat midden-onder in het 48x48-frame (x 12..36, y 16..48), **voeten op de onderrand**
  (zelfde voetlijn als de loopsheet); het wapen mag de 12 px links/rechts en 16 px boven gebruiken. 16 fps.
- **Getroffen** per held: 4 richtingen x 1 frame **24x32** (96x32). **KO**: 1 frame **32x24** (liggend), voeten/onderrand gelijk.
- **Spreuk-pose** (Vesper/Seren): 4 richtingen x 2 frames 24x32 (48x128).
- **Vijanden** (map-sprite 16x16): aanval 4 richtingen x 3 frames (telegraaf, uithaal, terug) = 48x64;
  getroffen 4x1 (16x64); doodgaan 4 frames 16x16 (64x16). Eerst Mosslijm, Moskonijn, Papiergeest, Glitchmot.
- **Effecten**: zwaai 32x32 x 4 (128x32); treffer-vonk 16x16 x 4 (64x16); telegraaf-"!" 8x8;
  genees-glans 16x16 x 4; spreuk-impact 24x24 x 4.
- **Schadecijfers**: cijfers 0-9 5x7 px (wit/rood/groen), sheet 50x7.
- **HUD**: kader per held 72x14 (normaal + actief), wapenmeter 18x4 + 2 frames "vol"-glinster, Swap/Ring-knoppen 38x14.
- **Joystick**: ring 60x60 + knop 24x24 (nu getekend in code).
- **Ringmenu**: ring ~180x110 + iconen 16x16 (Potion, Herb, Magic Water, Phoenix Feather, Spark, Minor Heal, ...).
