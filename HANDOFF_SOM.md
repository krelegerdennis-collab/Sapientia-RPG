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
- D-pad/pijltjes = lopen (bestaande tegelbeweging). **A** = slaan. Wapenmeter (balk boven Dax + linksboven) vult in 1 s;
  slaan onder 100% = minder schade (25%..100%).
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

## Art voor de volledige versie (RPG ART)
- Aanvalsanimatie per held (Dax, Vesper, Seren), veld-formaat: 4 richtingen x 4 frames, 32x32 per frame
  (wapen steekt buiten de 16x16-tegel) -> sheet 128x128 per held, voeten op dezelfde plek als player.png.
- Getroffen-pose per held: 4 richtingen x 1 frame 16x16 (64x16) + KO-pose 16x16.
- Per vijand (map-sprite 16x16, assets/map_monsters/): aanval 4 richtingen x 3 frames (opladen/telegraaf, uithaal, terug) = 48x64;
  getroffen 4x1 (16x64 of 64x16); doodgaan 4 frames 16x16 (64x16). Mosslijm, Moskonijn, Papiergeest, Glitchmot, Inktwurm als eerste.
- Slag-effect (zwaai) 32x32, 4 frames (128x32); treffer-vonk 16x16, 4 frames; telegraaf-icoon "!" 8x8.
- Schadecijfers-font: cijfers 0-9 5x7 px (wit/rood/groen) of een sheet 50x7.
- Wapenmeter: balk 18x4 + "vol"-glinster 2 frames; HUD-kader linksboven 72x20.
- Ringmenu: ringachtergrond ~180x110 + item/skill-iconen 16x16 (Potion, Herb, Magic Water, Spark, Minor Heal, ...).
