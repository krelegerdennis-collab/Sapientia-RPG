# Balans WM1 — meting

Meting met de bestaande headless battlesim (`tools/battlesim/battlesim.gd`, echte `scenes/battle/battle.tscn`).
Geen balansdata gewijzigd. De getallen hieronder komen uit `tools/wm1balans/wm1_runs.json`.

## Hoe gemeten

- Godot 4.3-stable (official), seed 20261020, runtime 273,5 s, 69800 gevechten, 349 encountergroepen, 39 gebieden.
- Elke unieke groep in een gebied is **200 keer** gevochten (elke groep even vaak). De gebiedsregel is het gemiddelde van die runs, dus een zeldzame groep telt even zwaar als een veelgeplaatste. De kolom Plaatsingen is het gewicht uit de kamer- of encounterdata (hoe vaak de groep op de kaart staat); die weegt de runs niet.
- Partij, level en uitrusting zijn die van `battlesim.gd` `scenarios()`: Act 1 Lv 1–13 en Act 2 Lv 14–19 uit `scripts/data/level_scale.gd`, doel-level 7 voor het Eerste Archief, Vesper sluit aan op Dax−1 na de Wortelkoning, Seren op Dax' level met de smeedset vanaf Archief 2 verdieping 3. De Diepe Grot gebruikt `d100_level`: verdieping 1 is vast Lv 1, daarboven Lv = afgerond(5 + 0,4 × verdieping), afgeleid van de canonregel HP = level × 50 op verdieping 25/50/75/99.
- Winst, rondes, HP-verlies, items, MP en KOs zijn de velden van de sim. HP-verlies is de party-HP aan het eind tegenover het begin, als deel van de maximale party-HP, na genezing; een KO telt als een lege balk. Items zijn verbruikte consumables. MP is uitgegeven MP. Een ronde is één beurt voor alle helden en vijanden. Een gevecht dat na 60 rondes niet af is, telt als verlies; dat kwam in deze run **0 keer** voor.
- De AI is `sim_battle.gd`: genezen onder 40% HP, een schade-spreuk alleen als die naar verwachting 15% beter is dan een aanval, anders de vijand met de minste HP. Bliksem en ijs slaan een beurt over met 30% per treffer, ook bij bazen. Geen Codex-bondgenoot, geen vluchten, geen verdedigen.
- Diepe Grot: de steekproefverdiepingen en 6 layout-seeds per verdieping zijn `D100_SAMPLE_FLOORS` en `D100_LAYOUTS` in `battlesim.gd`. Dit is elke groep uit die seeds, niet elke groep die de generator ooit kan leggen. De 12 baasverdiepingen zijn de vaste bazen uit `Dungeon100Scaling.BOSSES`.
- Drie gevechten zaten niet in de gebiedslijst en zijn in `tools/wm1balans/wm1_sim.gd` toegevoegd, met dezelfde party-bouwer: de proloogles (Moss Slime op 30 HP), de Inktwurm (na de Golem, Golemkern) en het Zingend Zaad (twee Wood Wraiths, basisstats).
- Standaard vechtstijl van een nieuw spel is Action. Deze meting is Classic (beurtgevecht). Bazen blijven ook in Action beurtgevechten, dus de baasregels gelden voor beide stijlen. De Action-factoren van Archief 1 (`SomData.ACTION_AREAS`) zitten niet in deze runs.
- WM2 en `wacht/` zijn niet meegenomen.

Opnieuw draaien:

```bash
xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/wm1balans/wm1_main.gd -- \
    --seed=20261020 --fights=200 --json=res://tools/wm1balans/wm1_runs.json
python3 tools/wm1balans/schrijf_rapport.py
```

Het doel waar de voorstellen aan afmeten staat in `game_data.gd` bij power scaling v2: gewone gevechten ongeveer 10–20% party-HP, bazen ongeveer 60–90% winst. De vlag in de tabellen is die van de sim: BIJNA ONMOGELIJK = winst onder 50%, ZWAAR = winst onder 80%, TRIVIAAL = 100% winst, minder dan 5% HP en hoogstens 2 rondes.

## Party en tas

- **Worldmap 1 (grass, random encounters)** (`wereldkaart1`). Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -) Tas: `{"drankje": 3, "kruid": 2, "toverwater": 1}`. Random-encounter pool for terrain 'gras' (GameData.ENCOUNTER_GROUPS + weights). Dax solo, Lv 3.
- **First Archive floor 1** (`archief1_v1`). Dax Lv3 (HP 60 MP 0 ATK 23 DEF 17 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Apprentice Cloak; spells: -) Tas: `{"drankje": 3, "kruid": 2, "toverwater": 1}`. Map monsters of every floor-1 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).
- **First Archive floor 2** (`archief1_v2`). Dax Lv5 (HP 78 MP 0 ATK 29 DEF 23 AGI 13 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor; spells: -) Tas: `{"drankje": 3, "kruid": 2, "toverwater": 1}`. Map monsters of every floor-2 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).
- **First Archive floor 3** (`archief1_v3`). Dax Lv6 (HP 87 MP 0 ATK 41 DEF 26 AGI 14 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -) Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Map monsters of every floor-3 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).
- **First Archive floor 4** (`archief1_v4`). Dax Lv7 (HP 96 MP 0 ATK 44 DEF 28 AGI 15 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -) Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Map monsters of every floor-4 room (DungeonRooms.ROOMS), room tier, archief scaling (target Lv 7).
- **BOSS Golem (First Archive)** (`golem`). Dax Lv8 (HP 105 MP 0 ATK 47 DEF 30 AGI 16 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -) Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Golem Hall boss (kennis_beest + pink core). Dax Lv 8 with Spark Sword.
- **Dark Wood** (`woud`). Dax Lv11 (HP 132 MP 0 ATK 56 DEF 38 AGI 19 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Core: golemkern Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. All Dark Wood map monsters, room tier 3 (no archief scaling). Dax solo Lv 11 + Golem Core (Core Strike).
- **BOSS Root King (Dark Wood)** (`wortelkoning`). Dax Lv12 (HP 141 MP 0 ATK 59 DEF 40 AGI 20 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Core: golemkern Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Root King, Dax solo Lv 12 (Vesper joins after this fight).
- **Mountain Cave (Berggrot)** (`berggrot`). Dax Lv13 (HP 150 MP 0 ATK 62 DEF 42 AGI 21 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv12 (HP 83 MP 62 ATK 20 DEF 20 AGI 33 MAG 36; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Berggrot map monsters (tier 0). Dax Lv 13 + Vesper Lv 12 (joined at Dax-1).
- **Second Archive floor 1** (`archief2_v1`). Dax Lv14 (HP 159 MP 0 ATK 65 DEF 44 AGI 22 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv13 (HP 88 MP 66 ATK 21 DEF 21 AGI 35 MAG 38; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 map monsters floor 1 (tier from room, archief scaling). Dax Lv 14 + Vesper Lv 13.
- **Second Archive floor 2** (`archief2_v2`). Dax Lv14 (HP 159 MP 0 ATK 65 DEF 44 AGI 22 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv13 (HP 88 MP 66 ATK 21 DEF 21 AGI 35 MAG 38; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 map monsters floor 2 (tier from room, archief scaling). Dax Lv 14 + Vesper Lv 13.
- **STORY Seren/Lotte (Second Archive, Dax alone)** (`lotte`). Dax Lv15 (HP 168 MP 0 ATK 68 DEF 46 AGI 23 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv14 (HP 93 MP 70 ATK 22 DEF 22 AGI 37 MAG 40; Oak Staff, Leather Hood, Padded Jerkin; spells: Spark, Chain Lightning); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Story fight: only Dax fights (archief2_party_filter = dennis), no Codex ally. Win or lose both continue the story.
- **Second Archive floor 3** (`archief2_v3`). Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 floor 3. Full party: Dax 16, Vesper 15, Seren 16 (joins at Dax's level), Act-2 forge gear.
- **Second Archive floor 4** (`archief2_v4`). Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 floor 4. Full party: Dax 16, Vesper 15, Seren 16 (joins at Dax's level), Act-2 forge gear.
- **BOSS The Strangler (Second Archive)** (`a2boss_wurger`). Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 boss, same party as floors 3-4.
- **BOSS The Mender (Second Archive)** (`a2boss_genezer`). Dax Lv16 (HP 177 MP 0 ATK 77 DEF 65 AGI 23 MAG 2; Kettle Blade, Kettle Shield, Kettle Helm, Scrap Plate; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 23 DEF 26 AGI 39 MAG 46; Oak Staff, Leather Hood, Work Cloak; spells: Spark, Chain Lightning); Seren Lv16 (HP 122 MP 59 ATK 42 DEF 23 AGI 23 MAG 51; Tuning Fork, Leather Hood, Travel Robe; spells: Minor Heal, Icicle); Core: golemkern Tas: `{"drankje": 6, "kruid": 3, "toverwater": 3}`. Archief 2 boss, same party as floors 3-4.
- **Deep Cave (Dungeon100) floor 1** (`d100_v1`). Dax Lv1 (HP 42 MP 0 ATK 17 DEF 15 AGI 11 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Vesper Lv1 (HP 28 MP 18 ATK 9 DEF 6 AGI 13 MAG 14; Oak Staff, Leather Hood, Silver Bookmark; spells: -); Seren Lv1 (HP 32 MP 14 ATK 11 DEF 11 AGI 9 MAG 11; Oak Staff, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Core: golemkern Tas: `{"drankje": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 1, d100 gear tier 1, potions of loot tier 1 (3 each).
- **Deep Cave (Dungeon100) floor 5** (`d100_v5`). Dax Lv7 (HP 96 MP 0 ATK 35 DEF 27 AGI 17 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Vesper Lv7 (HP 58 MP 42 ATK 15 DEF 12 AGI 25 MAG 26; Oak Staff, Leather Hood, Silver Bookmark; spells: -); Seren Lv7 (HP 68 MP 32 ATK 23 DEF 17 AGI 15 MAG 23; Oak Staff, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Core: golemkern Tas: `{"drankje": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 7, d100 gear tier 1, potions of loot tier 1 (3 each).
- **Deep Cave (Dungeon100) floor 15** (`d100_v15`). Dax Lv11 (HP 132 MP 0 ATK 47 DEF 35 AGI 21 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Vesper Lv11 (HP 78 MP 58 ATK 19 DEF 16 AGI 33 MAG 34; Oak Staff, Leather Hood, Silver Bookmark; spells: Spark); Seren Lv11 (HP 92 MP 44 ATK 31 DEF 21 AGI 19 MAG 31; Oak Staff, Leather Hood, Leather Armor, Silver Bookmark; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 11, d100 gear tier 1, potions of loot tier 1 (3 each).
- **Deep Cave (Dungeon100) floor 35** (`d100_v35`). Dax Lv19 (HP 204 MP 0 ATK 88 DEF 63 AGI 30 MAG 2; Archive Sword, Archive Shield, Archive Helm, Archive Armor, Archive Ring; spells: -); Vesper Lv19 (HP 118 MP 90 ATK 30 DEF 36 AGI 50 MAG 56; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Spark, Chain Lightning); Seren Lv19 (HP 140 MP 68 ATK 50 DEF 37 AGI 28 MAG 53; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "kruid": 3, "sterk_drankje": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 19, d100 gear tier 2, potions of loot tier 2 (3 each).
- **Deep Cave (Dungeon100) floor 45** (`d100_v45`). Dax Lv23 (HP 240 MP 0 ATK 112 DEF 84 AGI 36 MAG 2; Rune Sword, Rune Shield, Rune Helm, Rune Armor, Rune Ring; spells: -); Vesper Lv23 (HP 138 MP 106 ATK 37 DEF 49 AGI 60 MAG 72; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Spark, Chain Lightning); Seren Lv23 (HP 164 MP 80 ATK 61 DEF 50 AGI 34 MAG 69; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Minor Heal); Core: golemkern Tas: `{"sterk_drankje": 3, "toverbrouwsel": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 23, d100 gear tier 3, potions of loot tier 3 (3 each).
- **Deep Cave (Dungeon100) floor 65** (`d100_v65`). Dax Lv31 (HP 312 MP 0 ATK 152 DEF 119 AGI 47 MAG 2; Glitch Sword, Glitch Shield, Glitch Helm, Glitch Armor, Glitch Ring; spells: -); Vesper Lv31 (HP 178 MP 138 ATK 49 DEF 70 AGI 79 MAG 100; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Spark, Chain Lightning); Seren Lv31 (HP 212 MP 104 ATK 81 DEF 71 AGI 45 MAG 97; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 3, "sterk_drankje": 3, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 31, d100 gear tier 4, potions of loot tier 4 (3 each).
- **Deep Cave (Dungeon100) floor 85** (`d100_v85`). Dax Lv39 (HP 384 MP 0 ATK 198 DEF 160 AGI 59 MAG 2; Seal Sword, Seal Shield, Seal Helm, Seal Armor, Seal Ring; spells: -); Vesper Lv39 (HP 218 MP 170 ATK 63 DEF 95 AGI 99 MAG 132; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Spark, Chain Lightning); Seren Lv39 (HP 260 MP 128 ATK 103 DEF 96 AGI 57 MAG 129; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 6, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 39, d100 gear tier 5, potions of loot tier 5 (3 each).
- **Deep Cave (Dungeon100) floor 95** (`d100_v95`). Dax Lv43 (HP 420 MP 0 ATK 210 DEF 168 AGI 63 MAG 2; Seal Sword, Seal Shield, Seal Helm, Seal Armor, Seal Ring; spells: -); Vesper Lv43 (HP 238 MP 186 ATK 67 DEF 99 AGI 107 MAG 140; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Spark, Chain Lightning); Seren Lv43 (HP 284 MP 140 ATK 111 DEF 100 AGI 61 MAG 137; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 6, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 43, d100 gear tier 5, potions of loot tier 5 (3 each).
- **BOSS Deep Cave floor 10 (Page Warden)** (`d100_boss_10`). Dax Lv9 (HP 114 MP 0 ATK 41 DEF 31 AGI 19 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Vesper Lv9 (HP 68 MP 50 ATK 17 DEF 14 AGI 29 MAG 30; Oak Staff, Leather Hood, Silver Bookmark; spells: Spark); Seren Lv9 (HP 80 MP 38 ATK 27 DEF 19 AGI 17 MAG 27; Oak Staff, Leather Hood, Leather Armor, Silver Bookmark; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 9, d100 gear tier 1, potions of loot tier 1 (3 each).
- **BOSS Deep Cave floor 20 (Glitch Queen)** (`d100_boss_20`). Dax Lv13 (HP 150 MP 0 ATK 53 DEF 39 AGI 23 MAG 2; Short Sword, Wooden Shield, Leather Hood, Leather Armor, Silver Bookmark; spells: -); Vesper Lv13 (HP 88 MP 66 ATK 21 DEF 18 AGI 37 MAG 38; Oak Staff, Leather Hood, Silver Bookmark; spells: Spark); Seren Lv13 (HP 104 MP 50 ATK 35 DEF 23 AGI 21 MAG 35; Oak Staff, Leather Hood, Leather Armor, Silver Bookmark; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 13, d100 gear tier 1, potions of loot tier 1 (3 each).
- **BOSS Deep Cave floor 25 (The Shadow of H-6)** (`d100_boss_25`). Dax Lv15 (HP 168 MP 0 ATK 76 DEF 55 AGI 26 MAG 2; Archive Sword, Archive Shield, Archive Helm, Archive Armor, Archive Ring; spells: -); Vesper Lv15 (HP 98 MP 74 ATK 26 DEF 32 AGI 42 MAG 48; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Spark); Seren Lv15 (HP 116 MP 56 ATK 42 DEF 33 AGI 24 MAG 45; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "kruid": 3, "sterk_drankje": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 15, d100 gear tier 2, potions of loot tier 2 (3 each).
- **BOSS Deep Cave floor 30 (Spore Lord)** (`d100_boss_30`). Dax Lv17 (HP 186 MP 0 ATK 82 DEF 59 AGI 28 MAG 2; Archive Sword, Archive Shield, Archive Helm, Archive Armor, Archive Ring; spells: -); Vesper Lv17 (HP 108 MP 82 ATK 28 DEF 34 AGI 46 MAG 52; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Spark, Chain Lightning); Seren Lv17 (HP 128 MP 62 ATK 46 DEF 35 AGI 26 MAG 49; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "kruid": 3, "sterk_drankje": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 17, d100 gear tier 2, potions of loot tier 2 (3 each).
- **BOSS Deep Cave floor 40 (Root Mother)** (`d100_boss_40`). Dax Lv21 (HP 222 MP 0 ATK 94 DEF 67 AGI 32 MAG 2; Archive Sword, Archive Shield, Archive Helm, Archive Armor, Archive Ring; spells: -); Vesper Lv21 (HP 128 MP 98 ATK 32 DEF 38 AGI 54 MAG 60; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Spark, Chain Lightning); Seren Lv21 (HP 152 MP 74 ATK 54 DEF 39 AGI 30 MAG 57; Archive Staff, Archive Helm, Archive Armor, Archive Ring; spells: Minor Heal); Core: golemkern Tas: `{"drankje": 3, "kruid": 3, "sterk_drankje": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 21, d100 gear tier 2, potions of loot tier 2 (3 each).
- **BOSS Deep Cave floor 50 (The Cycle)** (`d100_boss_50`). Dax Lv25 (HP 258 MP 0 ATK 118 DEF 88 AGI 38 MAG 2; Rune Sword, Rune Shield, Rune Helm, Rune Armor, Rune Ring; spells: -); Vesper Lv25 (HP 148 MP 114 ATK 39 DEF 51 AGI 64 MAG 76; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Spark, Chain Lightning); Seren Lv25 (HP 176 MP 86 ATK 65 DEF 52 AGI 36 MAG 73; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Minor Heal); Core: golemkern Tas: `{"sterk_drankje": 3, "toverbrouwsel": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 25, d100 gear tier 3, potions of loot tier 3 (3 each).
- **BOSS Deep Cave floor 60 (Mist Lord)** (`d100_boss_60`). Dax Lv29 (HP 294 MP 0 ATK 130 DEF 96 AGI 42 MAG 2; Rune Sword, Rune Shield, Rune Helm, Rune Armor, Rune Ring; spells: -); Vesper Lv29 (HP 168 MP 130 ATK 43 DEF 55 AGI 72 MAG 84; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Spark, Chain Lightning); Seren Lv29 (HP 200 MP 98 ATK 73 DEF 56 AGI 40 MAG 81; Rune Staff, Rune Helm, Rune Armor, Rune Ring; spells: Minor Heal); Core: golemkern Tas: `{"sterk_drankje": 3, "toverbrouwsel": 3, "toverwater": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 29, d100 gear tier 3, potions of loot tier 3 (3 each).
- **BOSS Deep Cave floor 70 (Seal Warden)** (`d100_boss_70`). Dax Lv33 (HP 330 MP 0 ATK 158 DEF 123 AGI 49 MAG 2; Glitch Sword, Glitch Shield, Glitch Helm, Glitch Armor, Glitch Ring; spells: -); Vesper Lv33 (HP 188 MP 146 ATK 51 DEF 72 AGI 83 MAG 104; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Spark, Chain Lightning); Seren Lv33 (HP 224 MP 110 ATK 85 DEF 73 AGI 47 MAG 101; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 3, "sterk_drankje": 3, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 33, d100 gear tier 4, potions of loot tier 4 (3 each).
- **BOSS Deep Cave floor 75 (The Judge)** (`d100_boss_75`). Dax Lv35 (HP 348 MP 0 ATK 164 DEF 127 AGI 51 MAG 2; Glitch Sword, Glitch Shield, Glitch Helm, Glitch Armor, Glitch Ring; spells: -); Vesper Lv35 (HP 198 MP 154 ATK 53 DEF 74 AGI 87 MAG 108; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Spark, Chain Lightning); Seren Lv35 (HP 236 MP 116 ATK 89 DEF 75 AGI 49 MAG 105; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 3, "sterk_drankje": 3, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 35, d100 gear tier 4, potions of loot tier 4 (3 each).
- **BOSS Deep Cave floor 80 (Great Book Golem)** (`d100_boss_80`). Dax Lv37 (HP 366 MP 0 ATK 170 DEF 131 AGI 53 MAG 2; Glitch Sword, Glitch Shield, Glitch Helm, Glitch Armor, Glitch Ring; spells: -); Vesper Lv37 (HP 208 MP 162 ATK 55 DEF 76 AGI 91 MAG 112; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Spark, Chain Lightning); Seren Lv37 (HP 248 MP 122 ATK 93 DEF 77 AGI 51 MAG 109; Glitch Staff, Glitch Helm, Glitch Armor, Glitch Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 3, "sterk_drankje": 3, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 37, d100 gear tier 4, potions of loot tier 4 (3 each).
- **BOSS Deep Cave floor 90 (Root Emperor)** (`d100_boss_90`). Dax Lv41 (HP 402 MP 0 ATK 204 DEF 164 AGI 61 MAG 2; Seal Sword, Seal Shield, Seal Helm, Seal Armor, Seal Ring; spells: -); Vesper Lv41 (HP 228 MP 178 ATK 65 DEF 97 AGI 103 MAG 136; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Spark, Chain Lightning); Seren Lv41 (HP 272 MP 134 ATK 107 DEF 98 AGI 59 MAG 133; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 6, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 41, d100 gear tier 5, potions of loot tier 5 (3 each).
- **BOSS Deep Cave floor 99 (The Voice)** (`d100_boss_99`). Dax Lv45 (HP 438 MP 0 ATK 216 DEF 172 AGI 65 MAG 2; Seal Sword, Seal Shield, Seal Helm, Seal Armor, Seal Ring; spells: -); Vesper Lv45 (HP 248 MP 194 ATK 69 DEF 101 AGI 111 MAG 144; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Spark, Chain Lightning); Seren Lv45 (HP 296 MP 146 ATK 115 DEF 102 AGI 63 MAG 141; Seal Staff, Seal Helm, Seal Armor, Seal Ring; spells: Minor Heal); Core: golemkern Tas: `{"elixer": 6, "toverbrouwsel": 3}`. Generated floor (Dungeon100Generator, 6 run seeds). Party Lv 45, d100 gear tier 5, potions of loot tier 5 (3 each).
- **PROLOGUE lesson (Moss Slime, scripted 30 HP)** (`wm1extra_les`). Dax Lv1 (HP 42 MP 0 ATK 17 DEF 10 AGI 9 MAG 2; Short Sword, Apprentice Cloak; spells: -) Tas: `{}`. story_data.gd les: Dax Lv 1, Short Sword just received, Apprentice Cloak, no bag. Moss Slime max HP forced to 30.
- **UNIQUE Ink Worm (Golem Hall, after the Golem)** (`wm1extra_inktwurm`). Dax Lv8 (HP 105 MP 0 ATK 47 DEF 30 AGI 16 MAG 2; Spark Sword, Cover Shield, Leather Hood, Leather Armor; spells: -); Core: golemkern Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. Cabinet opens only with the Golem Core (inktwurm_kast.gd). Same party as the Golem fight: Dax Lv 8, Spark Sword. Unique: no tier scaling, stats from GameData.
- **SIDE Singing Seed (two Wood Wraiths)** (`wm1extra_woudgeest`). Dax Lv12 (HP 141 MP 0 ATK 59 DEF 40 AGI 20 MAG 2; Spark Sword, Cover Shield, Iron Helm, Leather Armor; spells: -); Vesper Lv11 (HP 78 MP 58 ATK 19 DEF 16 AGI 31 MAG 34; Oak Staff, Travel Robe; spells: Spark, Chain Lightning); Core: golemkern Tas: `{"drankje": 5, "kruid": 2, "toverwater": 2}`. story_data.gd zingend_zaad, after Vesper joins (Dax-1) at the Root King party (Dax Lv 12). Base stats, no wood tier. Oak Staff and Travel Robe are her join gear.

Bij het verhaalgevecht van Seren staat Vesper in de party-tekst, maar `archief2_party_filter` is `dennis`: alleen Dax vecht.

## Samenvatting per gebied

Elke groep even zwaar (200 runs per groep).

| Gebied | Runs | Groepen | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Worldmap 1 (grass, random encounters) | 2000 | 10 | 100.0% | 2.27 | 19.6% | 60.0% | 0.01 | 0.0 | 0.00 |  |
| First Archive floor 1 | 1600 | 8 | 100.0% | 1.50 | 10.3% | 23.3% | 0.00 | 0.0 | 0.00 |  |
| First Archive floor 2 | 1600 | 8 | 100.0% | 2.14 | 10.8% | 23.1% | 0.00 | 0.0 | 0.00 |  |
| First Archive floor 3 | 1400 | 7 | 100.0% | 2.60 | 8.1% | 14.9% | 0.00 | 0.0 | 0.00 |  |
| First Archive floor 4 | 1400 | 7 | 100.0% | 3.19 | 8.8% | 18.8% | 0.00 | 0.0 | 0.00 |  |
| BOSS Golem (First Archive) | 200 | 1 | 83.5% | 15.44 | 65.4% | 100.0% | 5.01 | 0.0 | 0.17 |  |
| Dark Wood | 3000 | 15 | 96.4% | 4.09 | 28.8% | 67.4% | 0.99 | 0.0 | 0.04 |  |
| BOSS Root King (Dark Wood) | 200 | 1 | 76.0% | 12.71 | 75.9% | 100.0% | 6.08 | 0.0 | 0.24 | ZWAAR |
| Mountain Cave (Berggrot) | 600 | 3 | 100.0% | 1.82 | 13.2% | 21.5% | 0.01 | 7.6 | 0.00 |  |
| Second Archive floor 1 | 400 | 2 | 100.0% | 2.00 | 9.5% | 17.0% | 0.00 | 11.8 | 0.01 |  |
| Second Archive floor 2 | 400 | 2 | 100.0% | 2.02 | 8.9% | 15.4% | 0.03 | 12.5 | 0.00 |  |
| STORY Seren/Lotte (Second Archive, Dax alone) | 200 | 1 | 100.0% | 4.00 | 18.6% | 22.6% | 0.00 | 0.0 | 0.00 |  |
| Second Archive floor 3 | 200 | 1 | 100.0% | 2.01 | 12.0% | 21.4% | 0.05 | 15.1 | 0.01 |  |
| Second Archive floor 4 | 200 | 1 | 100.0% | 2.04 | 14.3% | 24.4% | 0.07 | 15.1 | 0.03 |  |
| BOSS The Strangler (Second Archive) | 200 | 1 | 100.0% | 3.00 | 7.6% | 14.6% | 0.01 | 24.0 | 0.00 |  |
| BOSS The Mender (Second Archive) | 200 | 1 | 100.0% | 4.00 | 22.6% | 26.7% | 0.07 | 29.8 | 0.00 |  |
| Deep Cave (Dungeon100) floor 1 | 2200 | 11 | 100.0% | 1.38 | 5.8% | 12.7% | 0.01 | 0.0 | 0.00 |  |
| Deep Cave (Dungeon100) floor 5 | 2200 | 11 | 100.0% | 1.28 | 1.0% | 4.5% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Deep Cave (Dungeon100) floor 15 | 4000 | 20 | 100.0% | 1.78 | 5.2% | 10.6% | 0.00 | 7.1 | 0.00 |  |
| Deep Cave (Dungeon100) floor 35 | 8600 | 43 | 100.0% | 2.04 | 8.8% | 18.4% | 0.05 | 14.0 | 0.00 |  |
| Deep Cave (Dungeon100) floor 45 | 7600 | 38 | 100.0% | 2.60 | 13.8% | 28.2% | 0.17 | 17.4 | 0.02 |  |
| Deep Cave (Dungeon100) floor 65 | 7400 | 37 | 99.7% | 4.23 | 24.7% | 45.0% | 0.85 | 22.1 | 0.13 |  |
| Deep Cave (Dungeon100) floor 85 | 11800 | 59 | 93.6% | 5.76 | 38.3% | 71.7% | 1.70 | 23.5 | 0.51 |  |
| Deep Cave (Dungeon100) floor 95 | 9200 | 46 | 88.8% | 6.71 | 45.4% | 100.0% | 2.33 | 24.1 | 0.77 |  |
| BOSS Deep Cave floor 10 (Page Warden) | 200 | 1 | 86.0% | 5.86 | 68.4% | 100.0% | 1.81 | 17.9 | 1.25 |  |
| BOSS Deep Cave floor 20 (Glitch Queen) | 200 | 1 | 58.0% | 6.85 | 85.5% | 100.0% | 2.53 | 19.5 | 2.04 | ZWAAR |
| BOSS Deep Cave floor 25 (The Shadow of H-6) | 200 | 1 | 100.0% | 4.01 | 18.9% | 28.5% | 0.26 | 15.8 | 0.03 |  |
| BOSS Deep Cave floor 30 (Spore Lord) | 200 | 1 | 80.0% | 6.99 | 59.5% | 100.0% | 3.15 | 21.0 | 1.14 |  |
| BOSS Deep Cave floor 40 (Root Mother) | 200 | 1 | 87.5% | 6.72 | 55.9% | 100.0% | 3.35 | 23.0 | 0.85 |  |
| BOSS Deep Cave floor 50 (The Cycle) | 200 | 1 | 100.0% | 4.00 | 17.4% | 25.8% | 0.31 | 16.0 | 0.01 |  |
| BOSS Deep Cave floor 60 (Mist Lord) | 200 | 1 | 85.0% | 7.62 | 58.4% | 100.0% | 2.94 | 28.4 | 0.89 |  |
| BOSS Deep Cave floor 70 (Seal Warden) | 200 | 1 | 88.5% | 8.08 | 44.2% | 100.0% | 3.12 | 25.5 | 0.80 |  |
| BOSS Deep Cave floor 75 (The Judge) | 200 | 1 | 100.0% | 4.00 | 20.0% | 26.2% | 0.43 | 16.0 | 0.00 |  |
| BOSS Deep Cave floor 80 (Great Book Golem) | 200 | 1 | 67.0% | 8.56 | 67.7% | 100.0% | 4.14 | 22.8 | 1.51 | ZWAAR |
| BOSS Deep Cave floor 90 (Root Emperor) | 200 | 1 | 64.0% | 9.31 | 69.3% | 100.0% | 3.88 | 21.3 | 1.68 | ZWAAR |
| BOSS Deep Cave floor 99 (The Voice) | 200 | 1 | 100.0% | 4.01 | 21.1% | 29.5% | 0.49 | 16.1 | 0.01 |  |
| PROLOGUE lesson (Moss Slime, scripted 30 HP) | 200 | 1 | 100.0% | 2.08 | 13.0% | 14.3% | 0.00 | 0.0 | 0.00 |  |
| UNIQUE Ink Worm (Golem Hall, after the Golem) | 200 | 1 | 100.0% | 1.85 | 50.8% | 60.0% | 0.00 | 0.0 | 0.00 |  |
| SIDE Singing Seed (two Wood Wraiths) | 200 | 1 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 8.0 | 0.00 | TRIVIAAL |

Wereldkaart, gewogen naar plaatsing (totaal gewicht 21): winst 100.0%, 2.01 rondes, 14.7% HP, 0.01 items. De gelijke weging (19.6% HP) telt de zeldzame drie motten en het Kennis-Beest even zwaar als een enkele Moss Slime.

## Elke encounter

200 runs per regel. Plaatsingen = gewicht in de brondata.

### Worldmap 1 (grass, random encounters)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Moss Slime | 3 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Slime | 2 | 200 | 100.0% | 2.00 | 2.6% | 3.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit | 2 | 200 | 100.0% | 1.00 | 7.3% | 10.0% | 0.00 | 0.0 | 0.00 |  |
| Moss Rabbit + Moss Slime | 2 | 200 | 100.0% | 2.00 | 16.1% | 20.0% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith | 3 | 200 | 100.0% | 1.29 | 2.8% | 10.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Paper Wraith + Paper Wraith | 3 | 200 | 100.0% | 2.60 | 17.3% | 30.0% | 0.00 | 0.0 | 0.00 |  |
| Glitch Moth + Paper Wraith | 3 | 200 | 100.0% | 2.35 | 22.9% | 30.0% | 0.00 | 0.0 | 0.00 |  |
| Glitch Moth + Glitch Moth + Glitch Moth | 1 | 200 | 100.0% | 3.00 | 64.9% | 66.7% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast | 1 | 200 | 100.0% | 3.00 | 22.7% | 31.7% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast + Paper Wraith | 1 | 200 | 100.0% | 4.46 | 39.9% | 55.0% | 0.12 | 0.0 | 0.00 |  |

### First Archive floor 1

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Moss Slime (tier 1) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit (tier 1) | 1 | 200 | 100.0% | 1.00 | 9.1% | 11.7% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith (tier 1) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Slime (tier 1) | 1 | 200 | 100.0% | 2.00 | 7.6% | 8.3% | 0.00 | 0.0 | 0.00 |  |
| Moss Rabbit + Moss Slime (tier 1) | 1 | 200 | 100.0% | 2.00 | 19.5% | 23.3% | 0.00 | 0.0 | 0.00 |  |
| Glitch Moth (tier 1) | 1 | 200 | 100.0% | 1.00 | 12.4% | 13.3% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Paper Wraith (tier 1) | 1 | 200 | 100.0% | 2.00 | 10.9% | 11.7% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Glitch Moth (tier 1) | 1 | 200 | 100.0% | 2.00 | 23.4% | 25.0% | 0.00 | 0.0 | 0.00 |  |

### First Archive floor 2

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Paper Wraith + Paper Wraith (tier 2) | 1 | 200 | 100.0% | 2.00 | 5.8% | 6.4% | 0.00 | 0.0 | 0.00 |  |
| Glitch Moth (tier 2) | 1 | 200 | 100.0% | 1.00 | 5.1% | 7.7% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden (tier 2) | 2 | 200 | 100.0% | 2.00 | 4.5% | 10.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Glitch Moth + Paper Wraith (tier 2) | 1 | 200 | 100.0% | 2.00 | 11.3% | 14.1% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Paper Wraith + Glitch Moth (tier 2) | 1 | 200 | 100.0% | 3.00 | 22.9% | 25.6% | 0.00 | 0.0 | 0.00 |  |
| Glitch Moth + Glitch Moth (tier 2) | 1 | 200 | 100.0% | 2.00 | 18.0% | 21.8% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden + Paper Wraith (tier 2) | 1 | 200 | 100.0% | 3.00 | 9.4% | 16.7% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast (tier 2) | 1 | 200 | 100.0% | 2.15 | 9.5% | 16.7% | 0.00 | 0.0 | 0.00 |  |

### First Archive floor 3

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Glitch Moth + Glitch Moth (tier 3) | 1 | 200 | 100.0% | 2.00 | 8.8% | 13.8% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden (tier 3) | 2 | 200 | 100.0% | 1.74 | 2.1% | 2.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Mech. Warden + Glitch Moth (tier 3) | 1 | 200 | 100.0% | 2.83 | 7.2% | 12.6% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast (tier 3) | 1 | 200 | 100.0% | 2.00 | 5.8% | 12.6% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Paper Wraith + Glitch Moth (tier 3) | 1 | 200 | 100.0% | 3.00 | 12.3% | 14.9% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden + Mech. Warden (tier 3) | 1 | 200 | 100.0% | 3.63 | 9.7% | 17.2% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast + Paper Wraith (tier 3) | 1 | 200 | 100.0% | 3.00 | 10.9% | 17.2% | 0.00 | 0.0 | 0.00 |  |

### First Archive floor 4

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mech. Warden (tier 4) | 1 | 200 | 100.0% | 2.00 | 1.8% | 7.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Glitch Moth + Glitch Moth + Glitch Moth (tier 4) | 1 | 200 | 100.0% | 3.00 | 15.4% | 20.8% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden + Glitch Moth (tier 4) | 1 | 200 | 100.0% | 3.00 | 4.3% | 8.3% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast (tier 4) | 2 | 200 | 100.0% | 2.17 | 6.7% | 13.5% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden + Mech. Warden (tier 4) | 1 | 200 | 100.0% | 4.00 | 6.4% | 11.5% | 0.00 | 0.0 | 0.00 |  |
| The Knowledge Beast + Mech. Warden (tier 4) | 1 | 200 | 100.0% | 4.19 | 18.2% | 29.2% | 0.00 | 0.0 | 0.00 |  |
| Mech. Warden + Paper Wraith + Glitch Moth (tier 4) | 1 | 200 | 100.0% | 4.00 | 9.2% | 14.6% | 0.00 | 0.0 | 0.00 |  |

### BOSS Golem (First Archive)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Knowledge Beast | 1 | 200 | 83.5% | 15.44 | 65.4% | 100.0% | 5.01 | 0.0 | 0.17 |  |

### Dark Wood

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Root Crawler (tier 3) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Mist Owl (tier 3) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Spore Cap (tier 3) | 1 | 200 | 100.0% | 1.32 | 2.6% | 6.8% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Root Crawler + Root Crawler (tier 3) | 1 | 200 | 100.0% | 3.00 | 21.4% | 27.3% | 0.00 | 0.0 | 0.00 |  |
| Mist Owl + Root Crawler (tier 3) | 1 | 200 | 100.0% | 2.36 | 12.0% | 19.7% | 0.00 | 0.0 | 0.00 |  |
| Spore Cap + Mist Owl (tier 3) | 1 | 200 | 100.0% | 2.65 | 17.0% | 31.8% | 0.00 | 0.0 | 0.00 |  |
| Root Crawler + Spore Cap (tier 3) | 1 | 200 | 100.0% | 3.36 | 27.5% | 43.9% | 0.01 | 0.0 | 0.00 |  |
| Mist Owl + Mist Owl (tier 3) | 1 | 200 | 100.0% | 2.31 | 11.1% | 15.9% | 0.00 | 0.0 | 0.00 |  |
| Mist Owl + Mist Owl (tier 4) | 1 | 200 | 100.0% | 3.00 | 18.9% | 23.5% | 0.00 | 0.0 | 0.00 |  |
| Spore Cap + Spore Cap (tier 4) | 1 | 200 | 100.0% | 4.00 | 35.6% | 45.5% | 0.01 | 0.0 | 0.00 |  |
| Root Crawler + Mist Owl + Root Crawler (tier 4) | 1 | 200 | 94.0% | 7.14 | 61.7% | 92.4% | 2.52 | 0.0 | 0.06 |  |
| Root Crawler + Spore Cap (tier 4) | 1 | 200 | 100.0% | 4.00 | 41.9% | 51.5% | 0.01 | 0.0 | 0.00 |  |
| Spore Cap + Spore Cap + Mist Owl (tier 4) | 1 | 200 | 99.5% | 11.69 | 64.5% | 87.1% | 5.72 | 0.0 | 0.01 |  |
| Root Crawler + Root Crawler + Spore Cap (tier 4) | 1 | 200 | 53.0% | 11.11 | 89.8% | 100.0% | 6.54 | 0.0 | 0.47 | ZWAAR |
| Mist Owl + Root Crawler (tier 4) | 1 | 200 | 100.0% | 3.47 | 28.2% | 43.2% | 0.00 | 0.0 | 0.00 |  |

### BOSS Root King (Dark Wood)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Root King | 1 | 200 | 76.0% | 12.71 | 75.9% | 100.0% | 6.08 | 0.0 | 0.24 | ZWAAR |

### Mountain Cave (Berggrot)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Stone Louse (tier 7) | 2 | 200 | 100.0% | 2.02 | 13.0% | 17.6% | 0.04 | 8.1 | 0.00 |  |
| Vein Moth (tier 7) | 2 | 200 | 100.0% | 1.46 | 10.0% | 18.0% | 0.00 | 6.8 | 0.00 |  |
| Drip Slug (tier 7) | 1 | 200 | 100.0% | 2.00 | 16.5% | 25.8% | 0.00 | 8.0 | 0.00 |  |

### Second Archive floor 1

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Tendril + Tendril (tier 5) | 1 | 200 | 100.0% | 2.01 | 7.5% | 14.6% | 0.00 | 11.7 | 0.00 |  |
| Thorn Runner + Root Crawler (tier 5) | 1 | 200 | 100.0% | 2.00 | 11.4% | 30.8% | 0.00 | 11.9 | 0.03 |  |

### Second Archive floor 2

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Thorn Runner + Tendril (tier 5) | 1 | 200 | 100.0% | 2.00 | 7.3% | 15.0% | 0.00 | 11.8 | 0.00 |  |
| Sporehead + Spore Cap (tier 5) | 1 | 200 | 100.0% | 2.05 | 10.5% | 20.6% | 0.05 | 13.2 | 0.01 |  |

### STORY Seren/Lotte (Second Archive, Dax alone)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Seren | 1 | 200 | 100.0% | 4.00 | 18.6% | 22.6% | 0.00 | 0.0 | 0.00 |  |

### Second Archive floor 3

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Blooming Dread + Sporehead (tier 6) | 1 | 200 | 100.0% | 2.01 | 12.0% | 21.4% | 0.05 | 15.1 | 0.01 |  |

### Second Archive floor 4

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Rootghost + Blooming Dread (tier 6) | 1 | 200 | 100.0% | 2.04 | 14.3% | 24.4% | 0.07 | 15.1 | 0.03 |  |

### BOSS The Strangler (Second Archive)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Strangler | 1 | 200 | 100.0% | 3.00 | 7.6% | 14.6% | 0.01 | 24.0 | 0.00 |  |

### BOSS The Mender (Second Archive)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Mender | 1 | 200 | 100.0% | 4.00 | 22.6% | 26.7% | 0.07 | 29.8 | 0.00 |  |

### Deep Cave (Dungeon100) floor 1

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Paper Wraith (floor 1) | 14 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime (floor 1) | 10 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit (floor 1) | 15 | 200 | 100.0% | 1.00 | 6.7% | 10.8% | 0.00 | 0.0 | 0.00 |  |
| Moss Rabbit + Moss Rabbit (floor 1) | 2 | 200 | 100.0% | 1.97 | 18.3% | 27.5% | 0.07 | 0.0 | 0.01 |  |
| Moss Rabbit + Paper Wraith (floor 1) | 2 | 200 | 100.0% | 1.66 | 9.5% | 14.7% | 0.00 | 0.0 | 0.00 |  |
| Moss Slime + Paper Wraith (floor 1) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Slime (floor 1) | 2 | 200 | 100.0% | 1.88 | 3.9% | 6.9% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Moss Slime (floor 1) | 1 | 200 | 100.0% | 1.00 | 7.0% | 10.8% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Paper Wraith (floor 1) | 1 | 200 | 100.0% | 2.00 | 8.3% | 10.8% | 0.00 | 0.0 | 0.00 |  |
| Paper Wraith + Moss Slime (floor 1) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Paper Wraith + Moss Rabbit (floor 1) | 2 | 200 | 100.0% | 1.71 | 9.8% | 14.7% | 0.00 | 0.0 | 0.00 |  |

### Deep Cave (Dungeon100) floor 5

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Moss Slime + Paper Wraith (floor 5) | 3 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Paper Wraith + Moss Slime (floor 5) | 4 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Paper Wraith (floor 5) | 17 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime (floor 5) | 7 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit (floor 5) | 18 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Rabbit (floor 5) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Paper Wraith (floor 5) | 1 | 200 | 100.0% | 1.57 | 2.6% | 5.9% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Slime (floor 5) | 4 | 200 | 100.0% | 1.96 | 2.0% | 3.6% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Moss Rabbit (floor 5) | 1 | 200 | 100.0% | 1.99 | 4.1% | 5.9% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Paper Wraith + Moss Rabbit (floor 5) | 3 | 200 | 100.0% | 1.62 | 2.7% | 5.9% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Moss Slime (floor 5) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |

### Deep Cave (Dungeon100) floor 15

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Glitch Moth (floor 15) | 13 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Moss Slime + Mech. Warden (floor 15) | 2 | 200 | 100.0% | 2.00 | 7.7% | 12.6% | 0.00 | 8.0 | 0.00 |  |
| Mech. Warden (floor 15) | 9 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Mech. Warden + Moss Rabbit (floor 15) | 2 | 200 | 100.0% | 2.00 | 8.8% | 13.2% | 0.01 | 8.0 | 0.00 |  |
| Paper Wraith (floor 15) | 10 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Moss Rabbit (floor 15) | 9 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Moss Rabbit (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.4% | 7.9% | 0.00 | 8.0 | 0.00 |  |
| Mech. Warden + Mech. Warden (floor 15) | 2 | 200 | 100.0% | 2.60 | 8.3% | 13.2% | 0.00 | 10.4 | 0.00 |  |
| Moss Slime (floor 15) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Mech. Warden + Moss Slime (floor 15) | 1 | 200 | 100.0% | 2.00 | 7.8% | 12.3% | 0.00 | 8.0 | 0.00 |  |
| Glitch Moth + Glitch Moth (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.7% | 8.6% | 0.00 | 8.0 | 0.00 |  |
| Moss Rabbit + Glitch Moth (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.6% | 8.3% | 0.00 | 8.0 | 0.00 |  |
| Glitch Moth + Moss Rabbit (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.5% | 8.3% | 0.00 | 8.0 | 0.00 |  |
| Mech. Warden + Paper Wraith (floor 15) | 1 | 200 | 100.0% | 2.00 | 9.9% | 14.2% | 0.00 | 8.0 | 0.00 |  |
| Glitch Moth + Paper Wraith (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.8% | 8.6% | 0.00 | 8.0 | 0.00 |  |
| Moss Slime + Paper Wraith (floor 15) | 1 | 200 | 100.0% | 2.00 | 4.4% | 6.0% | 0.00 | 8.0 | 0.00 | TRIVIAAL |
| Moss Slime + Glitch Moth (floor 15) | 1 | 200 | 100.0% | 2.00 | 4.0% | 5.6% | 0.00 | 8.0 | 0.00 | TRIVIAAL |
| Moss Rabbit + Paper Wraith (floor 15) | 1 | 200 | 100.0% | 2.00 | 6.4% | 7.6% | 0.00 | 8.0 | 0.00 |  |
| Paper Wraith + Moss Slime (floor 15) | 1 | 200 | 100.0% | 2.00 | 4.4% | 6.0% | 0.00 | 8.0 | 0.00 | TRIVIAAL |
| Glitch Moth + Mech. Warden (floor 15) | 1 | 200 | 100.0% | 2.00 | 10.2% | 14.6% | 0.02 | 8.0 | 0.00 |  |

### Deep Cave (Dungeon100) floor 35

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mech. Warden + Moss Rabbit (floor 35) | 2 | 200 | 100.0% | 2.00 | 7.5% | 14.3% | 0.01 | 16.0 | 0.00 |  |
| Mech. Warden (floor 35) | 5 | 200 | 100.0% | 2.00 | 5.2% | 8.0% | 0.00 | 9.7 | 0.00 |  |
| Moss Slime + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 6.5% | 13.4% | 0.00 | 14.4 | 0.00 |  |
| Paper Wraith + Mech. Warden (floor 35) | 2 | 200 | 100.0% | 2.00 | 8.0% | 14.5% | 0.01 | 16.0 | 0.00 |  |
| Paper Wraith (floor 35) | 5 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Root Crawler (floor 35) | 6 | 200 | 100.0% | 2.00 | 11.3% | 15.2% | 0.03 | 8.0 | 0.00 |  |
| Moss Rabbit (floor 35) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Glitch Moth + Glitch Moth (floor 35) | 1 | 200 | 100.0% | 2.00 | 5.7% | 9.3% | 0.00 | 12.0 | 0.00 |  |
| Wood Wraith + Paper Wraith (floor 35) | 2 | 200 | 100.0% | 2.00 | 5.1% | 11.5% | 0.00 | 14.3 | 0.00 |  |
| Glitch Moth (floor 35) | 3 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Wood Wraith (floor 35) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Wood Wraith + Mist Owl (floor 35) | 2 | 200 | 100.0% | 2.00 | 10.0% | 16.2% | 0.00 | 16.0 | 0.00 |  |
| Spore Cap (floor 35) | 5 | 200 | 100.0% | 2.00 | 9.6% | 14.3% | 0.06 | 8.0 | 0.00 |  |
| Moss Slime (floor 35) | 5 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Spore Cap + Mist Owl (floor 35) | 1 | 200 | 100.0% | 3.03 | 19.1% | 31.2% | 0.20 | 20.4 | 0.04 |  |
| Mech. Warden + Mist Owl (floor 35) | 1 | 200 | 100.0% | 2.08 | 9.6% | 17.1% | 0.07 | 16.3 | 0.00 |  |
| Moss Rabbit + Paper Wraith (floor 35) | 2 | 200 | 100.0% | 2.00 | 7.2% | 13.9% | 0.01 | 14.2 | 0.00 |  |
| Spore Cap + Wood Wraith (floor 35) | 1 | 200 | 100.0% | 2.06 | 8.5% | 15.2% | 0.07 | 16.3 | 0.00 |  |
| Root Crawler + Spore Cap (floor 35) | 1 | 200 | 100.0% | 3.08 | 19.1% | 32.9% | 0.33 | 20.7 | 0.04 |  |
| Paper Wraith + Spore Cap (floor 35) | 1 | 200 | 100.0% | 2.99 | 17.5% | 28.8% | 0.09 | 20.3 | 0.01 |  |
| Mist Owl + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 10.8% | 18.8% | 0.09 | 16.0 | 0.00 |  |
| Root Crawler + Wood Wraith (floor 35) | 1 | 200 | 100.0% | 2.03 | 9.0% | 16.7% | 0.12 | 16.2 | 0.00 |  |
| Mech. Warden + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 8.6% | 15.2% | 0.02 | 16.0 | 0.00 |  |
| Mist Owl + Moss Rabbit (floor 35) | 1 | 200 | 100.0% | 2.00 | 10.8% | 18.8% | 0.07 | 16.0 | 0.00 |  |
| Moss Rabbit + Glitch Moth (floor 35) | 1 | 200 | 100.0% | 2.00 | 6.3% | 9.5% | 0.00 | 12.2 | 0.00 |  |
| Mist Owl + Mech. Warden (floor 35) | 2 | 200 | 100.0% | 2.08 | 10.7% | 17.1% | 0.07 | 16.2 | 0.01 |  |
| Paper Wraith + Wood Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 4.8% | 10.6% | 0.00 | 14.2 | 0.00 | TRIVIAAL |
| Moss Slime + Moss Slime (floor 35) | 1 | 200 | 100.0% | 2.00 | 3.4% | 6.7% | 0.00 | 12.0 | 0.00 | TRIVIAAL |
| Mist Owl + Spore Cap (floor 35) | 2 | 200 | 100.0% | 3.00 | 20.5% | 32.5% | 0.17 | 20.6 | 0.01 |  |
| Glitch Moth + Mist Owl (floor 35) | 1 | 200 | 100.0% | 2.00 | 12.3% | 20.6% | 0.02 | 16.0 | 0.00 |  |
| Moss Slime + Mech. Warden (floor 35) | 1 | 200 | 100.0% | 2.00 | 7.3% | 13.4% | 0.00 | 16.0 | 0.00 |  |
| Moss Rabbit + Spore Cap (floor 35) | 1 | 200 | 100.0% | 2.74 | 15.7% | 27.5% | 0.11 | 19.2 | 0.01 |  |
| Moss Slime + Spore Cap (floor 35) | 1 | 200 | 100.0% | 2.05 | 10.2% | 17.5% | 0.05 | 16.2 | 0.00 |  |
| Paper Wraith + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 4.7% | 8.4% | 0.00 | 12.0 | 0.00 | TRIVIAAL |
| Wood Wraith + Mech. Warden (floor 35) | 1 | 200 | 100.0% | 2.00 | 6.0% | 11.9% | 0.00 | 16.0 | 0.00 |  |
| Mist Owl (floor 35) | 1 | 200 | 100.0% | 1.52 | 8.1% | 13.2% | 0.00 | 7.3 | 0.00 |  |
| Mech. Warden + Moss Slime (floor 35) | 1 | 200 | 100.0% | 2.00 | 7.6% | 13.9% | 0.00 | 16.0 | 0.00 |  |
| Glitch Moth + Root Crawler (floor 35) | 1 | 200 | 100.0% | 2.06 | 12.6% | 20.8% | 0.10 | 16.4 | 0.01 |  |
| Paper Wraith + Moss Rabbit (floor 35) | 1 | 200 | 100.0% | 2.00 | 7.3% | 14.9% | 0.04 | 14.3 | 0.00 |  |
| Glitch Moth + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.00 | 8.8% | 16.2% | 0.01 | 14.7 | 0.00 |  |
| Root Crawler + Mech. Warden (floor 35) | 1 | 200 | 100.0% | 2.94 | 13.5% | 23.6% | 0.11 | 20.2 | 0.00 |  |
| Spore Cap + Moss Rabbit (floor 35) | 1 | 200 | 100.0% | 2.75 | 14.8% | 27.5% | 0.11 | 19.3 | 0.01 |  |
| Root Crawler + Paper Wraith (floor 35) | 1 | 200 | 100.0% | 2.31 | 13.1% | 22.9% | 0.16 | 17.7 | 0.01 |  |

### Deep Cave (Dungeon100) floor 45

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Wood Wraith + Mech. Warden (floor 45) | 1 | 200 | 100.0% | 2.00 | 5.5% | 11.3% | 0.00 | 16.0 | 0.00 |  |
| Glitch Moth + Glitch Moth (floor 45) | 2 | 200 | 100.0% | 2.00 | 5.0% | 9.0% | 0.00 | 12.0 | 0.00 | TRIVIAAL |
| Mech. Warden (floor 45) | 8 | 200 | 100.0% | 2.00 | 5.3% | 7.9% | 0.00 | 8.0 | 0.00 |  |
| Spore Cap + Mech. Warden (floor 45) | 2 | 200 | 100.0% | 3.05 | 12.9% | 22.7% | 0.17 | 21.1 | 0.01 |  |
| Wood Wraith + Glitch Moth (floor 45) | 3 | 200 | 100.0% | 2.00 | 3.2% | 7.2% | 0.00 | 12.6 | 0.00 | TRIVIAAL |
| Wood Wraith (floor 45) | 4 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Root Crawler + Mist Owl (floor 45) | 1 | 200 | 100.0% | 3.03 | 18.6% | 31.2% | 0.22 | 20.2 | 0.03 |  |
| Mech. Warden + Root Crawler (floor 45) | 3 | 200 | 100.0% | 3.00 | 12.4% | 21.8% | 0.20 | 20.5 | 0.00 |  |
| Spore Cap (floor 45) | 4 | 200 | 100.0% | 2.04 | 9.5% | 13.7% | 0.07 | 8.2 | 0.00 |  |
| Wood Wraith + Spore Cap (floor 45) | 2 | 200 | 100.0% | 2.33 | 10.0% | 18.3% | 0.04 | 18.1 | 0.01 |  |
| Root Crawler (floor 45) | 4 | 200 | 100.0% | 2.00 | 10.6% | 13.8% | 0.04 | 8.0 | 0.00 |  |
| Mist Owl + Mist Owl (floor 45) | 1 | 200 | 100.0% | 2.90 | 17.6% | 29.9% | 0.12 | 20.3 | 0.02 |  |
| Mist Owl + Root Crawler + Root Crawler (floor 45) | 1 | 200 | 99.5% | 4.21 | 33.1% | 56.5% | 0.88 | 26.8 | 0.26 |  |
| Mist Owl (floor 45) | 5 | 200 | 100.0% | 1.92 | 10.3% | 13.3% | 0.00 | 8.6 | 0.00 |  |
| Wood Wraith + Mist Owl (floor 45) | 2 | 200 | 100.0% | 2.00 | 9.2% | 15.9% | 0.03 | 16.0 | 0.00 |  |
| Glitch Moth (floor 45) | 4 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Mech. Warden + Wood Wraith + Glitch Moth (floor 45) | 1 | 200 | 100.0% | 2.36 | 12.1% | 20.1% | 0.06 | 17.7 | 0.00 |  |
| Glitch Moth + Mist Owl + Glitch Moth (floor 45) | 1 | 200 | 100.0% | 2.75 | 18.4% | 30.1% | 0.30 | 20.1 | 0.01 |  |
| Spore Cap + Spore Cap (floor 45) | 2 | 200 | 100.0% | 4.00 | 25.1% | 39.3% | 0.32 | 24.6 | 0.04 |  |
| Mist Owl + Wood Wraith + Mist Owl (floor 45) | 1 | 200 | 100.0% | 2.93 | 21.0% | 34.9% | 0.21 | 20.6 | 0.04 |  |
| Mech. Warden + Spore Cap (floor 45) | 2 | 200 | 100.0% | 3.08 | 14.3% | 23.8% | 0.17 | 21.3 | 0.01 |  |
| Glitch Moth + Wood Wraith (floor 45) | 1 | 200 | 100.0% | 2.00 | 3.1% | 5.4% | 0.00 | 12.7 | 0.00 | TRIVIAAL |
| Mech. Warden + Mist Owl (floor 45) | 1 | 200 | 100.0% | 2.58 | 13.9% | 24.4% | 0.08 | 18.3 | 0.00 |  |
| Mech. Warden + Glitch Moth + Glitch Moth (floor 45) | 1 | 200 | 100.0% | 2.77 | 17.3% | 26.6% | 0.11 | 20.6 | 0.01 |  |
| Mech. Warden + Glitch Moth (floor 45) | 1 | 200 | 100.0% | 2.04 | 8.2% | 15.1% | 0.04 | 16.3 | 0.00 |  |
| Root Crawler + Spore Cap (floor 45) | 2 | 200 | 100.0% | 3.28 | 19.6% | 33.4% | 0.35 | 22.0 | 0.04 |  |
| Wood Wraith + Mist Owl + Mech. Warden (floor 45) | 1 | 200 | 100.0% | 2.96 | 18.3% | 28.8% | 0.17 | 20.9 | 0.01 |  |
| Wood Wraith + Root Crawler (floor 45) | 1 | 200 | 100.0% | 2.09 | 8.9% | 15.3% | 0.08 | 16.4 | 0.00 |  |
| Glitch Moth + Spore Cap (floor 45) | 1 | 200 | 100.0% | 3.00 | 14.7% | 25.3% | 0.21 | 19.9 | 0.01 |  |
| Glitch Moth + Mist Owl (floor 45) | 1 | 200 | 100.0% | 2.02 | 10.6% | 19.2% | 0.10 | 16.1 | 0.00 |  |
| Root Crawler + Root Crawler (floor 45) | 1 | 200 | 100.0% | 3.29 | 21.0% | 32.1% | 0.34 | 20.9 | 0.06 |  |
| Root Crawler + Wood Wraith (floor 45) | 1 | 200 | 100.0% | 2.06 | 9.4% | 16.4% | 0.06 | 16.3 | 0.00 |  |
| Mist Owl + Spore Cap + Glitch Moth (floor 45) | 1 | 200 | 100.0% | 3.91 | 27.1% | 41.7% | 0.72 | 26.1 | 0.12 |  |
| Glitch Moth + Root Crawler (floor 45) | 1 | 200 | 100.0% | 2.88 | 17.4% | 29.3% | 0.15 | 20.0 | 0.01 |  |
| Root Crawler + Mist Owl + Wood Wraith (floor 45) | 1 | 200 | 100.0% | 3.12 | 23.2% | 38.7% | 0.37 | 21.6 | 0.07 |  |
| Glitch Moth + Wood Wraith + Spore Cap (floor 45) | 1 | 200 | 100.0% | 3.02 | 18.8% | 31.4% | 0.20 | 21.4 | 0.03 |  |
| Spore Cap + Glitch Moth + Wood Wraith (floor 45) | 1 | 200 | 100.0% | 3.02 | 17.8% | 29.7% | 0.25 | 21.6 | 0.02 |  |
| Glitch Moth + Mech. Warden + Mist Owl (floor 45) | 1 | 200 | 100.0% | 3.12 | 19.7% | 31.9% | 0.41 | 21.6 | 0.04 |  |

### Deep Cave (Dungeon100) floor 65

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Spore Cap + Root Crawler + Vein Moth (floor 65) | 1 | 200 | 94.5% | 6.29 | 39.5% | 75.1% | 2.33 | 35.6 | 0.48 |  |
| Spore Cap + Spore Cap (floor 65) | 1 | 200 | 100.0% | 4.38 | 25.8% | 40.3% | 0.72 | 28.3 | 0.11 |  |
| Wood Wraith + Mist Owl (floor 65) | 1 | 200 | 100.0% | 2.77 | 13.9% | 24.8% | 0.07 | 19.9 | 0.01 |  |
| Stone Louse + Mist Owl (floor 65) | 1 | 200 | 100.0% | 4.83 | 34.9% | 51.6% | 1.44 | 18.7 | 0.32 |  |
| Drip Slug + Vein Moth (floor 65) | 1 | 200 | 100.0% | 5.43 | 34.2% | 52.8% | 1.44 | 25.5 | 0.22 |  |
| Vein Moth (floor 65) | 6 | 200 | 100.0% | 2.02 | 15.7% | 22.5% | 0.01 | 8.2 | 0.01 |  |
| Root Crawler + Wood Wraith (floor 65) | 1 | 200 | 100.0% | 3.03 | 14.3% | 26.2% | 0.25 | 20.2 | 0.01 |  |
| Mist Owl + Root Crawler (floor 65) | 1 | 200 | 100.0% | 3.46 | 22.5% | 36.5% | 0.40 | 23.5 | 0.10 |  |
| Root Crawler + Stone Louse (floor 65) | 2 | 200 | 99.5% | 5.18 | 34.0% | 53.3% | 1.47 | 23.4 | 0.29 |  |
| Wood Wraith + Drip Slug + Wood Wraith (floor 65) | 1 | 200 | 100.0% | 4.63 | 24.6% | 35.0% | 0.42 | 26.7 | 0.01 |  |
| Root Crawler (floor 65) | 2 | 200 | 100.0% | 2.03 | 11.1% | 13.1% | 0.05 | 8.1 | 0.00 |  |
| Spore Cap (floor 65) | 2 | 200 | 100.0% | 2.21 | 19.3% | 25.4% | 0.04 | 9.4 | 0.03 |  |
| Drip Slug (floor 65) | 1 | 200 | 100.0% | 3.10 | 20.0% | 25.9% | 0.12 | 12.5 | 0.00 |  |
| Drip Slug + Root Crawler + Mist Owl (floor 65) | 1 | 200 | 97.0% | 7.22 | 40.8% | 61.1% | 2.71 | 35.7 | 0.45 |  |
| Stone Louse + Wood Wraith (floor 65) | 2 | 200 | 100.0% | 4.00 | 22.2% | 34.0% | 0.49 | 15.7 | 0.04 |  |
| Spore Cap + Wood Wraith + Spore Cap (floor 65) | 1 | 200 | 100.0% | 5.01 | 28.8% | 46.4% | 1.07 | 32.2 | 0.16 |  |
| Vein Moth + Drip Slug (floor 65) | 2 | 200 | 100.0% | 5.47 | 31.8% | 48.9% | 1.54 | 25.8 | 0.17 |  |
| Wood Wraith (floor 65) | 3 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 4.0 | 0.00 | TRIVIAAL |
| Root Crawler + Vein Moth (floor 65) | 1 | 200 | 100.0% | 4.19 | 26.6% | 43.4% | 0.58 | 27.1 | 0.12 |  |
| Drip Slug + Wood Wraith (floor 65) | 1 | 200 | 100.0% | 4.00 | 20.2% | 28.9% | 0.49 | 16.0 | 0.00 |  |
| Stone Louse + Vein Moth (floor 65) | 2 | 200 | 100.0% | 5.07 | 31.7% | 46.2% | 0.80 | 28.8 | 0.10 |  |
| Stone Louse (floor 65) | 1 | 200 | 100.0% | 3.00 | 14.3% | 18.8% | 0.15 | 12.0 | 0.00 |  |
| Mist Owl (floor 65) | 3 | 200 | 100.0% | 2.00 | 9.9% | 12.7% | 0.01 | 8.0 | 0.00 |  |
| Vein Moth + Root Crawler (floor 65) | 1 | 200 | 100.0% | 4.12 | 24.0% | 39.5% | 0.58 | 27.7 | 0.07 |  |
| Drip Slug + Root Crawler (floor 65) | 1 | 200 | 100.0% | 5.62 | 35.5% | 55.6% | 1.71 | 22.6 | 0.36 |  |
| Vein Moth + Stone Louse (floor 65) | 3 | 200 | 100.0% | 5.02 | 28.9% | 45.2% | 0.91 | 29.0 | 0.07 |  |
| Spore Cap + Wood Wraith (floor 65) | 2 | 200 | 100.0% | 3.13 | 15.7% | 27.2% | 0.17 | 20.5 | 0.02 |  |
| Drip Slug + Mist Owl (floor 65) | 1 | 200 | 100.0% | 5.10 | 34.7% | 52.0% | 1.52 | 20.3 | 0.23 |  |
| Stone Louse + Drip Slug + Root Crawler (floor 65) | 1 | 200 | 98.0% | 8.46 | 42.5% | 66.4% | 3.02 | 40.4 | 0.51 |  |
| Spore Cap + Mist Owl (floor 65) | 1 | 200 | 100.0% | 3.79 | 21.6% | 35.6% | 0.61 | 27.0 | 0.05 |  |
| Spore Cap + Wood Wraith + Root Crawler (floor 65) | 1 | 200 | 100.0% | 4.76 | 28.6% | 47.2% | 1.09 | 30.7 | 0.23 |  |
| Spore Cap + Vein Moth (floor 65) | 1 | 200 | 100.0% | 4.25 | 22.4% | 36.5% | 0.61 | 28.3 | 0.04 |  |
| Wood Wraith + Drip Slug (floor 65) | 1 | 200 | 100.0% | 4.01 | 20.7% | 29.3% | 0.49 | 16.1 | 0.00 |  |
| Root Crawler + Drip Slug (floor 65) | 2 | 200 | 100.0% | 5.62 | 36.6% | 56.6% | 1.77 | 23.4 | 0.33 |  |
| Wood Wraith + Spore Cap (floor 65) | 1 | 200 | 100.0% | 3.20 | 15.1% | 25.8% | 0.23 | 20.7 | 0.01 |  |
| Spore Cap + Drip Slug (floor 65) | 1 | 200 | 100.0% | 5.75 | 34.5% | 56.7% | 1.66 | 25.2 | 0.29 |  |
| Mist Owl + Mist Owl (floor 65) | 1 | 200 | 100.0% | 3.17 | 16.7% | 27.9% | 0.32 | 20.6 | 0.01 |  |

### Deep Cave (Dungeon100) floor 85

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Stone Louse + Sporehead (floor 85) | 1 | 200 | 100.0% | 5.42 | 33.6% | 50.5% | 1.55 | 25.2 | 0.20 |  |
| Scanline Wolf (floor 85) | 3 | 200 | 100.0% | 2.83 | 27.1% | 39.9% | 0.12 | 10.6 | 0.28 |  |
| Drip Slug + Drip Slug (floor 85) | 1 | 200 | 100.0% | 7.52 | 37.7% | 56.1% | 2.29 | 26.0 | 0.27 |  |
| Sporehead + Tendril (floor 85) | 1 | 200 | 100.0% | 4.28 | 22.4% | 34.2% | 0.56 | 28.2 | 0.01 |  |
| Shard Codex (floor 85) | 1 | 200 | 100.0% | 2.40 | 18.9% | 25.6% | 0.08 | 9.5 | 0.03 |  |
| Blooming Dread + Stone Louse + Drip Slug (floor 85) | 1 | 200 | 96.0% | 10.42 | 43.0% | 70.0% | 3.96 | 48.4 | 0.60 |  |
| Vein Moth + Vein Moth (floor 85) | 1 | 200 | 100.0% | 5.22 | 36.2% | 53.7% | 1.34 | 19.1 | 0.24 |  |
| Scanline Wolf + Shard Codex (floor 85) | 1 | 200 | 78.5% | 7.34 | 63.4% | 100.0% | 2.51 | 15.4 | 1.48 | ZWAAR |
| Tendril + Sporehead (floor 85) | 2 | 200 | 100.0% | 4.30 | 22.0% | 34.1% | 0.59 | 28.3 | 0.03 |  |
| Stone Louse + Stone Louse (floor 85) | 3 | 200 | 100.0% | 6.83 | 39.6% | 58.6% | 2.13 | 24.6 | 0.26 |  |
| Sporehead + Drip Slug (floor 85) | 3 | 200 | 100.0% | 5.86 | 32.7% | 49.7% | 1.88 | 24.7 | 0.18 |  |
| Blooming Dread + Scanline Wolf (floor 85) | 1 | 200 | 84.5% | 7.32 | 60.7% | 100.0% | 2.65 | 15.9 | 1.42 |  |
| Stone Louse (floor 85) | 2 | 200 | 100.0% | 3.04 | 19.7% | 27.6% | 0.12 | 12.2 | 0.00 |  |
| Thorn Runner + Sporehead (floor 85) | 2 | 200 | 100.0% | 4.17 | 29.0% | 50.9% | 0.71 | 26.1 | 0.26 |  |
| Rootghost + Drip Slug (floor 85) | 2 | 200 | 100.0% | 5.97 | 36.2% | 54.4% | 1.89 | 21.6 | 0.24 |  |
| Shard Codex + Shard Codex (floor 85) | 2 | 200 | 99.5% | 6.39 | 42.7% | 67.7% | 2.19 | 16.2 | 0.66 |  |
| Blooming Dread + Shard Codex + Shard Codex (floor 85) | 1 | 200 | 63.5% | 8.51 | 68.7% | 100.0% | 3.22 | 32.7 | 1.58 | ZWAAR |
| Sporehead + Shard Codex (floor 85) | 1 | 200 | 100.0% | 4.93 | 29.9% | 46.2% | 1.01 | 25.9 | 0.10 |  |
| Vein Moth + Blooming Dread (floor 85) | 1 | 200 | 100.0% | 5.42 | 37.4% | 55.9% | 1.53 | 19.0 | 0.24 |  |
| Drip Slug + Scanline Wolf + Sporehead (floor 85) | 1 | 200 | 65.0% | 8.54 | 66.9% | 100.0% | 3.11 | 35.4 | 1.61 | ZWAAR |
| Tendril + Sporehead + Thorn Runner (floor 85) | 1 | 200 | 75.5% | 6.09 | 53.1% | 100.0% | 1.81 | 29.5 | 1.07 | ZWAAR |
| Stone Louse + Vein Moth (floor 85) | 1 | 200 | 100.0% | 6.27 | 37.4% | 56.1% | 2.02 | 22.6 | 0.30 |  |
| Shard Codex + Stone Louse + Shard Codex (floor 85) | 1 | 200 | 67.5% | 8.91 | 61.0% | 100.0% | 3.58 | 38.2 | 1.38 | ZWAAR |
| Scanline Wolf + Blooming Dread (floor 85) | 2 | 200 | 86.0% | 7.29 | 59.7% | 100.0% | 2.69 | 17.0 | 1.30 |  |
| Tendril + Thorn Runner (floor 85) | 1 | 200 | 100.0% | 4.18 | 23.4% | 36.8% | 0.41 | 23.2 | 0.10 |  |
| Rootghost + Vein Moth (floor 85) | 3 | 200 | 100.0% | 5.04 | 35.8% | 49.0% | 1.35 | 18.9 | 0.23 |  |
| Scanline Wolf + Scanline Wolf + Sporehead (floor 85) | 1 | 200 | 68.5% | 6.61 | 63.1% | 100.0% | 2.33 | 29.2 | 1.44 | ZWAAR |
| Vein Moth (floor 85) | 3 | 200 | 100.0% | 2.84 | 17.8% | 22.7% | 0.01 | 11.9 | 0.01 |  |
| Blooming Dread + Shard Codex (floor 85) | 1 | 200 | 99.5% | 6.45 | 42.9% | 66.9% | 2.33 | 18.1 | 0.55 |  |
| Thorn Runner + Tendril (floor 85) | 1 | 200 | 100.0% | 4.32 | 23.6% | 44.5% | 0.54 | 22.5 | 0.17 |  |
| Stone Louse + Scanline Wolf + Shard Codex (floor 85) | 1 | 200 | 58.5% | 8.04 | 68.7% | 100.0% | 2.99 | 31.0 | 1.62 | ZWAAR |
| Rootghost (floor 85) | 2 | 200 | 100.0% | 2.00 | 10.0% | 13.2% | 0.00 | 8.0 | 0.00 |  |
| Stone Louse + Thorn Runner (floor 85) | 2 | 200 | 96.5% | 6.09 | 43.8% | 72.3% | 1.89 | 21.0 | 0.71 |  |
| Tendril (floor 85) | 2 | 200 | 100.0% | 2.02 | 8.4% | 10.9% | 0.00 | 7.6 | 0.00 |  |
| Tendril + Drip Slug (floor 85) | 1 | 200 | 100.0% | 6.00 | 34.7% | 51.7% | 1.54 | 22.4 | 0.23 |  |
| Scanline Wolf + Vein Moth (floor 85) | 1 | 200 | 94.5% | 6.55 | 52.0% | 77.0% | 2.25 | 16.4 | 1.05 |  |
| Shard Codex + Blooming Dread (floor 85) | 1 | 200 | 100.0% | 6.15 | 39.3% | 58.2% | 2.06 | 18.4 | 0.46 |  |
| Blooming Dread + Drip Slug (floor 85) | 1 | 200 | 100.0% | 6.76 | 38.1% | 55.3% | 2.45 | 23.9 | 0.30 |  |
| Sporehead + Thorn Runner (floor 85) | 1 | 200 | 98.0% | 4.26 | 31.7% | 52.7% | 0.66 | 25.3 | 0.41 |  |
| Thorn Runner + Stone Louse (floor 85) | 1 | 200 | 95.0% | 5.95 | 45.8% | 76.2% | 1.82 | 21.5 | 0.74 |  |
| Vein Moth + Stone Louse (floor 85) | 1 | 200 | 100.0% | 6.34 | 37.3% | 58.2% | 1.97 | 21.8 | 0.35 |  |
| Drip Slug + Rootghost (floor 85) | 1 | 200 | 100.0% | 5.99 | 37.5% | 53.7% | 1.82 | 21.2 | 0.25 |  |
| Shard Codex + Vein Moth + Vein Moth (floor 85) | 1 | 200 | 97.0% | 8.20 | 41.5% | 70.3% | 3.10 | 37.3 | 0.58 |  |
| Drip Slug + Sporehead (floor 85) | 2 | 200 | 100.0% | 5.96 | 32.9% | 51.5% | 1.97 | 24.9 | 0.17 |  |
| Blooming Dread (floor 85) | 4 | 200 | 100.0% | 3.00 | 18.4% | 24.7% | 0.10 | 11.9 | 0.03 |  |
| Stone Louse + Drip Slug (floor 85) | 2 | 200 | 100.0% | 7.38 | 39.0% | 58.9% | 2.29 | 24.8 | 0.41 |  |
| Rootghost + Rootghost + Thorn Runner (floor 85) | 1 | 200 | 87.0% | 6.50 | 52.1% | 100.0% | 2.34 | 30.8 | 0.98 |  |
| Shard Codex + Tendril + Rootghost (floor 85) | 1 | 200 | 82.0% | 7.46 | 50.4% | 100.0% | 2.56 | 33.6 | 0.86 |  |
| Thorn Runner (floor 85) | 1 | 200 | 100.0% | 2.07 | 13.3% | 24.9% | 0.10 | 7.9 | 0.08 |  |
| Sporehead + Rootghost + Tendril (floor 85) | 1 | 200 | 98.5% | 6.51 | 33.7% | 57.7% | 2.21 | 39.0 | 0.27 |  |
| Thorn Runner + Vein Moth (floor 85) | 1 | 200 | 98.5% | 4.71 | 31.2% | 54.5% | 1.11 | 22.8 | 0.39 |  |
| Sporehead + Thorn Runner + Vein Moth (floor 85) | 1 | 200 | 91.0% | 6.73 | 43.8% | 85.4% | 2.25 | 35.2 | 0.68 |  |
| Vein Moth + Sporehead (floor 85) | 1 | 200 | 100.0% | 4.76 | 29.2% | 44.4% | 0.80 | 27.0 | 0.02 |  |
| Sporehead (floor 85) | 1 | 200 | 100.0% | 2.05 | 16.2% | 21.2% | 0.00 | 8.4 | 0.00 |  |
| Tendril + Shard Codex (floor 85) | 1 | 200 | 100.0% | 4.86 | 27.2% | 44.1% | 0.93 | 23.8 | 0.14 |  |
| Scanline Wolf + Drip Slug + Scanline Wolf (floor 85) | 1 | 200 | 60.0% | 7.62 | 71.0% | 100.0% | 2.87 | 30.5 | 1.77 | ZWAAR |
| Blooming Dread + Vein Moth (floor 85) | 1 | 200 | 100.0% | 5.82 | 41.0% | 60.8% | 1.94 | 20.9 | 0.35 |  |
| Tendril + Scanline Wolf + Tendril (floor 85) | 1 | 200 | 88.5% | 6.69 | 42.3% | 100.0% | 2.03 | 33.3 | 0.64 |  |
| Blooming Dread + Vein Moth + Blooming Dread (floor 85) | 1 | 200 | 96.0% | 8.76 | 43.5% | 76.9% | 3.56 | 38.3 | 0.63 |  |

### Deep Cave (Dungeon100) floor 95

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Rootghost + Thorn Runner + Rootghost (floor 95) | 1 | 200 | 77.5% | 6.80 | 59.3% | 100.0% | 2.60 | 32.4 | 1.23 | ZWAAR |
| Sporehead (floor 95) | 1 | 200 | 100.0% | 2.81 | 18.2% | 22.0% | 0.00 | 12.1 | 0.00 |  |
| Aureate Watcher (floor 95) | 2 | 200 | 100.0% | 3.06 | 21.9% | 30.1% | 0.42 | 12.1 | 0.08 |  |
| Thorn Runner + Rootghost (floor 95) | 1 | 200 | 95.0% | 5.58 | 48.0% | 74.7% | 1.76 | 16.4 | 0.76 |  |
| Drip Slug + Aureate Watcher (floor 95) | 2 | 200 | 96.0% | 8.46 | 49.0% | 75.2% | 3.23 | 22.3 | 0.91 |  |
| Thorn Runner (floor 95) | 1 | 200 | 100.0% | 2.13 | 15.6% | 32.2% | 0.08 | 8.1 | 0.14 |  |
| Vein Moth + Vein Moth + Drip Slug (floor 95) | 1 | 200 | 69.5% | 11.41 | 64.8% | 100.0% | 4.81 | 34.7 | 1.44 | ZWAAR |
| Sporehead + Sporehead + Blooming Dread (floor 95) | 1 | 200 | 86.0% | 7.74 | 50.0% | 100.0% | 3.22 | 39.7 | 0.77 |  |
| Aureate Watcher + Blooming Dread (floor 95) | 3 | 200 | 95.5% | 8.43 | 51.7% | 79.2% | 3.06 | 19.5 | 1.06 |  |
| Rootghost + Tendril (floor 95) | 1 | 200 | 100.0% | 4.64 | 25.3% | 37.5% | 0.91 | 25.0 | 0.04 |  |
| Thorn Runner + Aureate Watcher (floor 95) | 1 | 200 | 85.0% | 7.18 | 60.7% | 100.0% | 2.71 | 17.5 | 1.32 |  |
| Blooming Dread + Aureate Watcher + Aureate Watcher (floor 95) | 1 | 200 | 50.0% | 9.27 | 77.2% | 100.0% | 3.80 | 38.0 | 1.99 | ZWAAR |
| Aureate Watcher + Blooming Dread + Ledger Scarab (floor 95) | 1 | 200 | 50.0% | 8.19 | 75.4% | 100.0% | 3.25 | 34.4 | 1.93 | ZWAAR |
| Tendril + Rootghost (floor 95) | 1 | 200 | 100.0% | 4.64 | 25.1% | 39.0% | 0.90 | 24.6 | 0.05 |  |
| Vein Moth (floor 95) | 2 | 200 | 100.0% | 3.00 | 16.1% | 22.5% | 0.12 | 11.9 | 0.01 |  |
| Vein Moth + Vein Moth (floor 95) | 1 | 200 | 100.0% | 5.83 | 37.0% | 57.0% | 2.01 | 20.0 | 0.36 |  |
| Aureate Watcher + Ledger Scarab (floor 95) | 1 | 200 | 63.5% | 8.37 | 70.2% | 100.0% | 3.03 | 16.8 | 1.81 | ZWAAR |
| Stone Louse + Blooming Dread (floor 95) | 1 | 200 | 99.0% | 7.84 | 41.7% | 66.0% | 3.13 | 22.2 | 0.57 |  |
| Aureate Watcher + Aureate Watcher + Drip Slug (floor 95) | 1 | 200 | 30.0% | 9.22 | 88.0% | 100.0% | 4.14 | 29.7 | 2.40 | BIJNA ONMOGELIJK |
| Ledger Scarab + Stone Louse (floor 95) | 1 | 200 | 80.0% | 8.34 | 61.5% | 100.0% | 2.87 | 18.8 | 1.42 |  |
| Drip Slug + Ledger Scarab (floor 95) | 1 | 200 | 84.0% | 9.26 | 59.1% | 100.0% | 3.15 | 21.3 | 1.28 |  |
| Tendril (floor 95) | 2 | 200 | 100.0% | 2.09 | 9.5% | 13.5% | 0.00 | 8.2 | 0.00 |  |
| Blooming Dread + Sporehead (floor 95) | 1 | 200 | 100.0% | 6.53 | 39.2% | 65.6% | 2.56 | 20.8 | 0.47 |  |
| Blooming Dread + Vein Moth (floor 95) | 1 | 200 | 100.0% | 6.67 | 40.1% | 61.5% | 2.50 | 20.0 | 0.52 |  |
| Thorn Runner + Blooming Dread + Vein Moth (floor 95) | 1 | 200 | 77.5% | 8.23 | 60.5% | 100.0% | 3.05 | 32.6 | 1.30 | ZWAAR |
| Stone Louse (floor 95) | 4 | 200 | 100.0% | 3.17 | 21.8% | 29.1% | 0.17 | 12.7 | 0.01 |  |
| Tendril + Vein Moth (floor 95) | 1 | 200 | 100.0% | 4.79 | 28.4% | 42.1% | 0.83 | 26.1 | 0.07 |  |
| Stone Louse + Sporehead (floor 95) | 2 | 200 | 100.0% | 6.38 | 41.8% | 59.0% | 2.28 | 22.0 | 0.38 |  |
| Aureate Watcher + Stone Louse + Stone Louse (floor 95) | 1 | 200 | 66.0% | 10.47 | 66.5% | 100.0% | 4.26 | 46.9 | 1.53 | ZWAAR |
| Tendril + Stone Louse + Rootghost (floor 95) | 1 | 200 | 93.0% | 8.90 | 46.8% | 76.8% | 3.50 | 40.5 | 0.66 |  |
| Sporehead + Blooming Dread (floor 95) | 2 | 200 | 99.0% | 6.46 | 39.6% | 62.0% | 2.54 | 20.5 | 0.49 |  |
| Rootghost + Drip Slug (floor 95) | 1 | 200 | 100.0% | 6.50 | 36.5% | 54.1% | 2.37 | 23.5 | 0.26 |  |
| Stone Louse + Aureate Watcher (floor 95) | 1 | 200 | 95.5% | 8.01 | 47.1% | 77.4% | 3.06 | 22.7 | 0.79 |  |
| Thorn Runner + Drip Slug (floor 95) | 1 | 200 | 88.5% | 7.30 | 56.9% | 100.0% | 2.46 | 18.8 | 1.13 |  |
| Rootghost + Thorn Runner (floor 95) | 1 | 200 | 92.5% | 5.67 | 51.0% | 81.3% | 1.72 | 17.3 | 0.90 |  |
| Blooming Dread + Rootghost (floor 95) | 1 | 200 | 100.0% | 6.25 | 38.0% | 54.5% | 2.39 | 19.8 | 0.36 |  |
| Rootghost + Aureate Watcher (floor 95) | 1 | 200 | 99.0% | 6.89 | 45.2% | 71.7% | 2.52 | 18.8 | 0.76 |  |
| Thorn Runner + Tendril (floor 95) | 1 | 200 | 100.0% | 4.86 | 27.8% | 50.1% | 1.09 | 20.8 | 0.21 |  |
| Sporehead + Vein Moth + Aureate Watcher (floor 95) | 1 | 200 | 78.0% | 8.95 | 59.5% | 100.0% | 3.60 | 40.1 | 1.27 | ZWAAR |
| Vein Moth + Stone Louse + Tendril (floor 95) | 1 | 200 | 92.5% | 9.43 | 45.5% | 77.2% | 3.77 | 40.0 | 0.70 |  |
| Rootghost + Stone Louse (floor 95) | 1 | 200 | 100.0% | 6.48 | 41.1% | 65.8% | 2.21 | 21.2 | 0.41 |  |
| Drip Slug + Sporehead (floor 95) | 1 | 200 | 100.0% | 6.51 | 37.8% | 58.9% | 2.33 | 23.3 | 0.28 |  |
| Sporehead + Tendril (floor 95) | 1 | 200 | 100.0% | 4.71 | 26.1% | 42.3% | 0.93 | 25.6 | 0.04 |  |
| Thorn Runner + Stone Louse (floor 95) | 1 | 200 | 90.5% | 6.81 | 52.9% | 85.0% | 2.42 | 18.9 | 0.99 |  |
| Aureate Watcher + Vein Moth + Rootghost (floor 95) | 1 | 200 | 79.0% | 8.61 | 57.8% | 100.0% | 3.49 | 40.6 | 1.24 | ZWAAR |
| Thorn Runner + Tendril + Thorn Runner (floor 95) | 1 | 200 | 73.0% | 6.03 | 54.9% | 100.0% | 1.91 | 29.7 | 1.17 | ZWAAR |

### BOSS Deep Cave floor 10 (Page Warden)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Paper Wraith (floor 10) | 1 | 200 | 86.0% | 5.86 | 68.4% | 100.0% | 1.81 | 17.9 | 1.25 |  |

### BOSS Deep Cave floor 20 (Glitch Queen)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Glitch Moth (floor 20) | 1 | 200 | 58.0% | 6.85 | 85.5% | 100.0% | 2.53 | 19.5 | 2.04 | ZWAAR |

### BOSS Deep Cave floor 25 (The Shadow of H-6)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Glitch Moth (floor 25) | 1 | 200 | 100.0% | 4.01 | 18.9% | 28.5% | 0.26 | 15.8 | 0.03 |  |

### BOSS Deep Cave floor 30 (Spore Lord)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Spore Cap (floor 30) | 1 | 200 | 80.0% | 6.99 | 59.5% | 100.0% | 3.15 | 21.0 | 1.14 |  |

### BOSS Deep Cave floor 40 (Root Mother)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Root Crawler (floor 40) | 1 | 200 | 87.5% | 6.72 | 55.9% | 100.0% | 3.35 | 23.0 | 0.85 |  |

### BOSS Deep Cave floor 50 (The Cycle)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mech. Warden (floor 50) | 1 | 200 | 100.0% | 4.00 | 17.4% | 25.8% | 0.31 | 16.0 | 0.01 |  |

### BOSS Deep Cave floor 60 (Mist Lord)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mist Owl (floor 60) | 1 | 200 | 85.0% | 7.62 | 58.4% | 100.0% | 2.94 | 28.4 | 0.89 |  |

### BOSS Deep Cave floor 70 (Seal Warden)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mech. Warden (floor 70) | 1 | 200 | 88.5% | 8.08 | 44.2% | 100.0% | 3.12 | 25.5 | 0.80 |  |

### BOSS Deep Cave floor 75 (The Judge)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Mist Owl (floor 75) | 1 | 200 | 100.0% | 4.00 | 20.0% | 26.2% | 0.43 | 16.0 | 0.00 |  |

### BOSS Deep Cave floor 80 (Great Book Golem)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Knowledge Beast (floor 80) | 1 | 200 | 67.0% | 8.56 | 67.7% | 100.0% | 4.14 | 22.8 | 1.51 | ZWAAR |

### BOSS Deep Cave floor 90 (Root Emperor)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| The Root King (floor 90) | 1 | 200 | 64.0% | 9.31 | 69.3% | 100.0% | 3.88 | 21.3 | 1.68 | ZWAAR |

### BOSS Deep Cave floor 99 (The Voice)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Paper Wraith (floor 99) | 1 | 200 | 100.0% | 4.01 | 21.1% | 29.5% | 0.49 | 16.1 | 0.01 |  |

### PROLOGUE lesson (Moss Slime, scripted 30 HP)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Moss Slime | 1 | 200 | 100.0% | 2.08 | 13.0% | 14.3% | 0.00 | 0.0 | 0.00 |  |

### UNIQUE Ink Worm (Golem Hall, after the Golem)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Ink Worm | 1 | 200 | 100.0% | 1.85 | 50.8% | 60.0% | 0.00 | 0.0 | 0.00 |  |

### SIDE Singing Seed (two Wood Wraiths)

| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Wood Wraith + Wood Wraith | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 8.0 | 0.00 | TRIVIAAL |

## Uitschieters

### Te zwaar voor een gewone groep (winst onder 80%)

| Gebied | Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Dark Wood | Root Crawler + Root Crawler + Spore Cap (tier 4) | 1 | 200 | 53.0% | 11.11 | 89.8% | 100.0% | 6.54 | 0.0 | 0.47 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Scanline Wolf + Shard Codex (floor 85) | 1 | 200 | 78.5% | 7.34 | 63.4% | 100.0% | 2.51 | 15.4 | 1.48 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Blooming Dread + Shard Codex + Shard Codex (floor 85) | 1 | 200 | 63.5% | 8.51 | 68.7% | 100.0% | 3.22 | 32.7 | 1.58 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Drip Slug + Scanline Wolf + Sporehead (floor 85) | 1 | 200 | 65.0% | 8.54 | 66.9% | 100.0% | 3.11 | 35.4 | 1.61 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Tendril + Sporehead + Thorn Runner (floor 85) | 1 | 200 | 75.5% | 6.09 | 53.1% | 100.0% | 1.81 | 29.5 | 1.07 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Shard Codex + Stone Louse + Shard Codex (floor 85) | 1 | 200 | 67.5% | 8.91 | 61.0% | 100.0% | 3.58 | 38.2 | 1.38 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Scanline Wolf + Scanline Wolf + Sporehead (floor 85) | 1 | 200 | 68.5% | 6.61 | 63.1% | 100.0% | 2.33 | 29.2 | 1.44 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Stone Louse + Scanline Wolf + Shard Codex (floor 85) | 1 | 200 | 58.5% | 8.04 | 68.7% | 100.0% | 2.99 | 31.0 | 1.62 | ZWAAR |
| Deep Cave (Dungeon100) floor 85 | Scanline Wolf + Drip Slug + Scanline Wolf (floor 85) | 1 | 200 | 60.0% | 7.62 | 71.0% | 100.0% | 2.87 | 30.5 | 1.77 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Rootghost + Thorn Runner + Rootghost (floor 95) | 1 | 200 | 77.5% | 6.80 | 59.3% | 100.0% | 2.60 | 32.4 | 1.23 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Vein Moth + Vein Moth + Drip Slug (floor 95) | 1 | 200 | 69.5% | 11.41 | 64.8% | 100.0% | 4.81 | 34.7 | 1.44 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Blooming Dread + Aureate Watcher + Aureate Watcher (floor 95) | 1 | 200 | 50.0% | 9.27 | 77.2% | 100.0% | 3.80 | 38.0 | 1.99 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Blooming Dread + Ledger Scarab (floor 95) | 1 | 200 | 50.0% | 8.19 | 75.4% | 100.0% | 3.25 | 34.4 | 1.93 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Ledger Scarab (floor 95) | 1 | 200 | 63.5% | 8.37 | 70.2% | 100.0% | 3.03 | 16.8 | 1.81 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Aureate Watcher + Drip Slug (floor 95) | 1 | 200 | 30.0% | 9.22 | 88.0% | 100.0% | 4.14 | 29.7 | 2.40 | BIJNA ONMOGELIJK |
| Deep Cave (Dungeon100) floor 95 | Thorn Runner + Blooming Dread + Vein Moth (floor 95) | 1 | 200 | 77.5% | 8.23 | 60.5% | 100.0% | 3.05 | 32.6 | 1.30 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Stone Louse + Stone Louse (floor 95) | 1 | 200 | 66.0% | 10.47 | 66.5% | 100.0% | 4.26 | 46.9 | 1.53 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Sporehead + Vein Moth + Aureate Watcher (floor 95) | 1 | 200 | 78.0% | 8.95 | 59.5% | 100.0% | 3.60 | 40.1 | 1.27 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Vein Moth + Rootghost (floor 95) | 1 | 200 | 79.0% | 8.61 | 57.8% | 100.0% | 3.49 | 40.6 | 1.24 | ZWAAR |
| Deep Cave (Dungeon100) floor 95 | Thorn Runner + Tendril + Thorn Runner (floor 95) | 1 | 200 | 73.0% | 6.03 | 54.9% | 100.0% | 1.91 | 29.7 | 1.17 | ZWAAR |

20 gewone groepen zitten onder 80% winst. Op de WM1-route is dat er één: de bewaker in `woud_sporenkring` (Root Crawler + Root Crawler + Spore Cap, tier 4). De rest staat op verdieping 85 en 95 van de Diepe Grot.

### Bazen buiten 60–90% winst, of een baas die in vier rondes voorbij is

| Gebied | Runs | Groepen | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| STORY Seren/Lotte (Second Archive, Dax alone) | 200 | 1 | 100.0% | 4.00 | 18.6% | 22.6% | 0.00 | 0.0 | 0.00 |  |
| BOSS The Strangler (Second Archive) | 200 | 1 | 100.0% | 3.00 | 7.6% | 14.6% | 0.01 | 24.0 | 0.00 |  |
| BOSS The Mender (Second Archive) | 200 | 1 | 100.0% | 4.00 | 22.6% | 26.7% | 0.07 | 29.8 | 0.00 |  |
| BOSS Deep Cave floor 20 (Glitch Queen) | 200 | 1 | 58.0% | 6.85 | 85.5% | 100.0% | 2.53 | 19.5 | 2.04 | ZWAAR |
| BOSS Deep Cave floor 25 (The Shadow of H-6) | 200 | 1 | 100.0% | 4.01 | 18.9% | 28.5% | 0.26 | 15.8 | 0.03 |  |
| BOSS Deep Cave floor 50 (The Cycle) | 200 | 1 | 100.0% | 4.00 | 17.4% | 25.8% | 0.31 | 16.0 | 0.01 |  |
| BOSS Deep Cave floor 75 (The Judge) | 200 | 1 | 100.0% | 4.00 | 20.0% | 26.2% | 0.43 | 16.0 | 0.00 |  |
| BOSS Deep Cave floor 99 (The Voice) | 200 | 1 | 100.0% | 4.01 | 21.1% | 29.5% | 0.49 | 16.1 | 0.01 |  |

De Golem (83,5%) en de Wortelkoning (76,0%) vallen binnen 60–90% en staan daarom niet in deze lijst. Wel in de volledige tabel hierboven.

### Triviaal op de route

100% winst, minder dan 5% HP, hoogstens 2 rondes. Diepe Grot staat hier niet regel voor regel; de vroege verdiepingen zijn bijna helemaal zo.

| Gebied | Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Worldmap 1 (grass, random encounters) | Moss Slime | 3 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Worldmap 1 (grass, random encounters) | Moss Slime + Moss Slime | 2 | 200 | 100.0% | 2.00 | 2.6% | 3.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Worldmap 1 (grass, random encounters) | Paper Wraith | 3 | 200 | 100.0% | 1.29 | 2.8% | 10.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| First Archive floor 1 | Moss Slime (tier 1) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| First Archive floor 1 | Paper Wraith (tier 1) | 2 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| First Archive floor 2 | Mech. Warden (tier 2) | 2 | 200 | 100.0% | 2.00 | 4.5% | 10.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| First Archive floor 3 | Mech. Warden (tier 3) | 2 | 200 | 100.0% | 1.74 | 2.1% | 2.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| First Archive floor 4 | Mech. Warden (tier 4) | 1 | 200 | 100.0% | 2.00 | 1.8% | 7.3% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Dark Wood | Root Crawler (tier 3) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Dark Wood | Mist Owl (tier 3) | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| Dark Wood | Spore Cap (tier 3) | 1 | 200 | 100.0% | 1.32 | 2.6% | 6.8% | 0.00 | 0.0 | 0.00 | TRIVIAAL |
| SIDE Singing Seed (two Wood Wraiths) | Wood Wraith + Wood Wraith | 1 | 200 | 100.0% | 1.00 | 0.0% | 0.0% | 0.00 | 8.0 | 0.00 | TRIVIAAL |

Route: 12 triviale groepen. Diepe Grot: 38 triviale groepen, geconcentreerd op verdieping 1, 5 en 15 (verdieping 5: gebiedsgemiddelde 1.0% HP, 1.28 rondes, 100% winst).

### Lang en duur, ook als de winst hoog is

| Gebied | Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Worldmap 1 (grass, random encounters) | Glitch Moth + Glitch Moth + Glitch Moth | 1 | 200 | 100.0% | 3.00 | 64.9% | 66.7% | 0.00 | 0.0 | 0.00 |  |
| Dark Wood | Spore Cap + Spore Cap + Mist Owl (tier 4) | 1 | 200 | 99.5% | 11.69 | 64.5% | 87.1% | 5.72 | 0.0 | 0.01 |  |
| Deep Cave (Dungeon100) floor 65 | Stone Louse + Drip Slug + Root Crawler (floor 65) | 1 | 200 | 98.0% | 8.46 | 42.5% | 66.4% | 3.02 | 40.4 | 0.51 |  |
| Deep Cave (Dungeon100) floor 85 | Blooming Dread + Stone Louse + Drip Slug (floor 85) | 1 | 200 | 96.0% | 10.42 | 43.0% | 70.0% | 3.96 | 48.4 | 0.60 |  |
| Deep Cave (Dungeon100) floor 85 | Shard Codex + Vein Moth + Vein Moth (floor 85) | 1 | 200 | 97.0% | 8.20 | 41.5% | 70.3% | 3.10 | 37.3 | 0.58 |  |
| Deep Cave (Dungeon100) floor 85 | Blooming Dread + Vein Moth + Blooming Dread (floor 85) | 1 | 200 | 96.0% | 8.76 | 43.5% | 76.9% | 3.56 | 38.3 | 0.63 |  |
| Deep Cave (Dungeon100) floor 95 | Drip Slug + Aureate Watcher (floor 95) | 2 | 200 | 96.0% | 8.46 | 49.0% | 75.2% | 3.23 | 22.3 | 0.91 |  |
| Deep Cave (Dungeon100) floor 95 | Aureate Watcher + Blooming Dread (floor 95) | 3 | 200 | 95.5% | 8.43 | 51.7% | 79.2% | 3.06 | 19.5 | 1.06 |  |
| Deep Cave (Dungeon100) floor 95 | Stone Louse + Blooming Dread (floor 95) | 1 | 200 | 99.0% | 7.84 | 41.7% | 66.0% | 3.13 | 22.2 | 0.57 |  |
| Deep Cave (Dungeon100) floor 95 | Stone Louse + Aureate Watcher (floor 95) | 1 | 200 | 95.5% | 8.01 | 47.1% | 77.4% | 3.06 | 22.7 | 0.79 |  |

De Inktwurm wint altijd in 1.85 rondes en kost toch 50.8% HP (p90 60.0%), zonder item. Korte piekschade, geen kans om te verliezen.

## Voorstellen

Voor RPG COMBAT en Dennis. Niks hiervan is doorgevoerd. Elke knop is één wijziging, daarna dezelfde sim opnieuw. Waar een lichtere samenstelling al in deze run zit, staat die regel erbij als gemeten vergelijking, niet als voorspelling.

### 1. Wereldkaart — drie Glitch Moths van het gras af

Dax Lv 3, startersset. Drie Glitch Moths (gewicht 1, geen `terrains` dus meegeloot op gras): 100.0% winst, 3.00 rondes, 64.9% HP, p90 66.7%. Het solo Kennis-Beest: 100.0%, 3.00 rondes, 22.7% HP. Kennis-Beest + Paper Wraith: 100.0%, 4.46 rondes, 39.9% HP, 0.12 items.

Voorstel: in `GameData.ENCOUNTER_GROUPS` de groep `glitchmot+glitchmot+glitchmot` gewicht 1 → 0. Het solo Kennis-Beest (ongeveer 23% HP, zeldzaam) kan blijven. Kennis-Beest + Paper Wraith ook gewicht 0, of `terrains: ["archief"]`. Basis-HP en ATK van Glitch Moth (16 / 15) niet verhogen: die soort staat ook in Archief 1, en Action klemt daar de HP.

### 2. Donker Woud — de bewaker in de Sporenkring inkorten

`woud_sporenkring` tier 4, bewaker op tegel [14, 4], groep wortelkruiper + wortelkruiper + sporenzwam. Dax Lv 11 met Vonkzwaard, Kaftschild, IJzeren Helm en Golemkern: 53.0% winst, 11.11 rondes, 89.8% HP, 6.54 items, 0.47 KOs. Dat is zwaarder dan de Golem (83.5% winst).

Dezelfde verdieping heeft de groep Root Crawler + Spore Cap (tier 4) al gemeten: 100.0% winst, 4.00 rondes, 41.9% HP, 0.01 items. Voorstel: de bewaker wordt die groep (één Root Crawler eraf).

Zelfde kamer, `m1` (Spore Cap + Spore Cap + Mist Owl): 99.5% winst, 11.69 rondes, 64.5% HP, 5.72 items. Spore Cap + Spore Cap (tier 4) zit ook in de run: 100.0%, 4.00 rondes, 35.6% HP, 0.01 items. Voorstel: de Mist Owl uit `m1` halen.

De rest van het woud gemiddeld 28.8% HP bij 96.4% winst. Losse vijanden op tier 3 zijn triviaal; dat hoort bij de rand van het woud. Daar geen HP-verhoging op de soort.

### 3. Golem en Wortelkoning — laten staan

Golem, Dax Lv 8, Vonkzwaard, tas 5 drankjes / 2 toverwater / 2 kruid: 83.5% winst, 15.44 rondes, 65.4% HP, p90 100.0%, 5.01 items, 0.17 KOs. Canonblok HP 360 / ATK 27 / DEF 15. Dat ligt in de band 60–90%.

Wortelkoning, Dax Lv 12 solo met kern: 76.0% winst, 12.71 rondes, 75.9% HP, 6.08 items, 0.24 KOs. Baas-ATK 38. Ook in de band. Geen statwijziging.

### 4. Inktwurm — meer HP, ATK laten

Na de Golem, Dax Lv 8, zelfde set en kern, uniek, geen tier. Stats nu HP 74 / ATK 44 / DEF 17. Meting: 100.0% winst, 1.85 rondes, 50.8% HP, p90 60.0%, 0 items, 0 KOs.

Voorstel: `max_hp` 74 → 130. ATK 44 blijft, zodat de klap het dreigende deel houdt en het gevecht langer duurt dan twee rondes. Daarna deze groep opnieuw meten. Geen wijziging aan de vangkans.

### 5. Seren, de Wurger en de Genezer

Seren (`lotte_glitch`, alleen Dax Lv 15, Vonkzwaard): 100.0% winst, 4.00 rondes, 18.6% HP, 0 items. Baasblok HP 270 / ATK 32. Het gevecht gaat door bij winst én verlies. Voorstel, dit blok staat in de code als niet-canon: HP 270 → 420, ATK laten, hermeten. Doel van de hermeting: boven de 90% winst blijven (het verhaal moet door) en duidelijk boven de 18.6% HP van nu uitkomen.

De Wurger, volle party Lv 16/15/16 met smeedset: 100.0% winst, 3.00 rondes, 7.6% HP, 24.0 MP, 0.01 items, 0 KOs. Baasblok HP 700 / ATK 42 / DEF 28.

De Genezer, zelfde party: 100.0% winst, 4.00 rondes, 22.6% HP, 29.8 MP, 0.07 items.

Power scaling v2 heeft Wurger en Genezer als canon onaangeroerd gelaten. Voorstel aan Dennis: die twee vrijgeven voor één HP-stap, ATK laten staan. Wurger HP 700 → 1400. Genezer HP 900 → 1350. `archief2_leech` pas aanraken na die hermeting. Zonder dat besluit blijven de stats zoals ze zijn; de meting zegt dan dat beide bazen een zeker drie- à vierrondengevecht zijn.

### 6. Archief 1, berggrot, Archief 2-gangen, proloog, Zingend Zaad

Archief 1 verdieping 1, Dax Lv 3: 100.0% winst, 1.50 rondes, 10.3% HP. Verdieping 4, Dax Lv 7 met Vonkzwaard: 100.0%, 3.19 rondes, 8.8% HP. Berggrot, Dax Lv 13 + Vesper Lv 12: 100.0%, 1.82 rondes, 13.2% HP, 7.6 MP. Archief 2 verdieping 1: 9.5% HP in 2.00 rondes. Verdieping 3 met de smeedset: 12.0% HP in 2.01 rondes. Allemaal 100% winst.

Voorstel: TIERS, ARCHIEF_STAT_SCHAAL (0,7) en de berggrot-tier 7 niet wijzigen op basis van deze Classic-run. Verdieping 1 zit op de onderkant van 10–20% HP. Verdieping 4 zit er net onder, met het Vonkzwaard dat de sim op dit level al geeft. Basisstats van de Archief-1-soorten verhogen raakt de wereldkaart en de Action-HP-klem (`hp_hits` 2,5–3,0). Eerst `--archief1balans` als Action het gevoel van die gangen moet worden.

Proloogles, Dax Lv 1, kort zwaard, leerlingmantel, lege tas, Moss Slime geforceerd op 30 HP: 100.0% winst, 2.08 rondes, 13.0% HP. Voorstel: de les laten zoals hij is.

Zingend Zaad, Dax Lv 12 + Vesper Lv 11, twee Wood Wraiths op basisstats (HP 12 / ATK 6): 100.0% winst, 1.00 ronde, 0.0% HP, 8.0 MP. Vesper's spreuk maakt het gevecht af voor de wraiths handelen. Voorstel: laten staan als het zaad een vondst is. Als het een woudgevecht moet zijn: HP 12 → 48 en ATK 6 → 14, en opnieuw meten. Tier 3 of 4 op deze basisstats haalt ze niet op het level van de Wortelkoning.

### 7. Diepe Grot — vroege verdiepingen en de vier canonbazen

Op het level uit `d100_level` zijn verdieping 5 (1.0% HP, 1.28 rondes) en verdieping 15 (5.2% HP, 1.78 rondes) triviaal, alle groepen 100% winst. Verdieping 35–65 lopen op naar de band 10–20% en er net over (verdieping 65: 24.7% HP, 99.7% winst).

Canonbazen, HP = level × 50, party op het bijbehorende level met d100-uitrusting van die buit-tier. Schaduw van H-6 (verdieping 25): 100.0%, 4.01 rondes, 18.9% HP, 0.26 items. De Cyclus (50): 100.0%, 4.00 rondes, 17.4% HP. De Rechter (75): 100.0%, 4.00 rondes, 20.0% HP. De Stem (99): 100.0%, 4.01 rondes, 21.1% HP, 16.1 MP.

Voorstel aan Dennis, de canon-HP niet stilletjes overschrijven. Twee keuzes, één ervan:

1. Deze vier blijven een adempauze. De meting ondersteunt dat: vier rondes en ongeveer 20% HP, terwijl de niet-canon bazen eromheen 6–9 rondes en 44–86% HP kosten.
2. Ze moeten in de band 60–90%. Eerste proef, los van de andere knoppen: na `CANON_BOSS` de HP ×2, ATK en DEF laten, en alleen deze vier opnieuw meten.

Vroege verdiepingen, als de canon-levels kloppen: `HP_LIN` 0,10 → 0,18 en `HP_FLAT` 2 → 4 in `dungeon100_scaling.gd`, daarna verdieping 5 en 15 opnieuw. `BOSS_MULT` en `CANON_BOSS` in diezelfde wijziging niet aanraken.

### 8. Diepe Grot — stapels op verdieping 85–95, en de Glitch Queen

Eén Aureate Watcher op verdieping 95: 100.0% winst, 3.06 rondes, 21.9% HP. Twee Aureate Watchers + Drip Slug: 30.0% winst, 9.22 rondes, 88.0% HP, 2.40 KOs. Scanline Wolf + Drip Slug + Scanline Wolf op verdieping 85: 60.0% winst, 7.62 rondes, 71.0% HP, 1.77 KOs. Gebied 95, elke groep gelijk: 88.8% winst, 45.4% HP, 2.33 items, 0.77 KOs. Naar plaatsing gewogen: 90.7% winst, 42.7% HP. Gebied 85: 93.6% winst, 38.3% HP.

Voorstel: in de groepbouwer van de Diepe Grot hoogstens één `aureate_watcher` en hoogstens één `scanline_wolf` per gewone groep. Geen nieuwe soorten, geen hogere basis-HP. Daarna verdieping 85 en 95 opnieuw (zelfde 6 seeds, zelfde levels).

Niet-canon bazen. Page Warden (10): 86.0% winst, 68.4% HP. Glitch Queen (20): 58.0% winst, 6.85 rondes, 85.5% HP, 2.04 KOs, 2.53 items. Great Book Golem (80): 67.0%, 8.56 rondes, 67.7% HP, 1.51 KOs. Root Emperor (90): 64.0%, 9.31 rondes, 69.3% HP, 1.68 KOs.

Voorstel: `BOSS_MULT` (HP ×3,0 / ATK ×1,34) laten. Verdieping 80 en 90 zitten in 60–90% winst; ze zijn duur (anderhalf tot twee KOs, vier items) maar binnen het doel. Alleen verdieping 20 zit eronder (58,0%). Eerste proef: na `boss_stats` de HP van verdieping 20 ×0,85, hermeten. De andere baasverdiepingen niet meeschalen.

## Niet in deze meting

- Action-gevechten (`--actionsim`, `--archief1balans`). Archief 1-gangen in Action hebben eigen schade- en cooldownfactoren.
- Mimics (blauwe kisten). Die zitten niet in de monstergroepen die de sim uit de kamers haalt.
- Codex-bondgenoten, vluchten, verdedigen, de `_nostun`-variant.
- WM2 en alles onder `wacht/`.

