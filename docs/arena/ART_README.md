# SAPIENTIA – Colosseum / Arena art set (WM1)

Gemaakt door RPG ART op 2026-11-15 (v2: zelfde dag, ronde 2: NPC-zijaanzicht, banner, icoon, lobby-props, gecentreerde lobbypoort, fakkel 125 ms). Alle albedo-PNG's gebruiken alleen de 73 kleuren uit `docs/art/masterpalet.gpl`, met alpha 0 of 255.
`palet_check.py --streng --assets repo_drop --top 0` geeft EXIT 0 (17 PNG's, allemaal schoon).
De generators staan in `src/`: per asset een hand-gepixelde rij-string, plus `build.py` en `preview.py`.

## Mappen
| map | inhoud |
|---|---|
| `repo_drop/` | albedo + `_e` (emissive, palet) + `data/hd2d/*_arena.json`, repo-relatieve paden |
| `repo_drop_normals/` | `_n` normal maps (datatextuur, níét paletkunst; apart zodat de paletcheck schoon blijft) |
| `preview/` | losse 4x previews (geen zips) |
| `layouts.json` | referentie-tilemaps hal + lobby (atlas-indices, rij-voor-rij) |
| `DROPIN_FILES.txt`, `SHA256SUMS`, `HANDWERK_APPEND.txt` | drop-in lijst, hashes, regels voor `tools/handwerk.txt` |

## Assets
| bestand | maat | frames / timing | anker |
|---|---|---|---|
| `assets/tiles/wereld_v18_arena.png` | 64x32 (8 tiles 16x16) | – | tilegrid |
| `assets/ui/arena/icon_arena.png` | 16x16 | – | – |
| `assets/ui/arena/icon_arena_token.png` | 16x16 | – | – |
| `assets/tiles/arena/arena_tiles.png` | 256x144 (16x9 = 144 tiles; v1 256x96, v2 256x112; bestaande indices 0-111 ongewijzigd) | – | tilegrid |
| `assets/sprites/arena/arena_gate.png` | 144x48 = 3 frames 48x48 (v3; was 96x48) | f0 dicht, f1 open, **f2 dicht + geketend + hangslot met violette glitch-rune (glow)** = lobby-slot tot `noor_lid` | onder-midden |
| `assets/sprites/arena/arena_banner.png` | 16x32 | 1 frame (gem = glow) | onder-midden |
| `assets/sprites/arena/arena_torch.png` | 64x32 = 4 frames 16x32 | 125 ms per frame (8 fps, gelijk aan de lichtprops), loop 0-1-2-3 | onder-midden |
| `assets/sprites/arena/arena_counter.png` | 48x32 | 1 frame | onder-midden |
| `assets/sprites/arena/arena_weapon_rack.png` | 32x32 | 1 frame (speer, gladius, strijdbijl, tweede gladius aan het gevest, rond maroon schild) | onder-midden |
| `assets/sprites/arena/arena_notice_board.png` | 32x32 | 1 frame (arena-ladder-poster, notities, glitch-scanline op een gescheurd golfbericht; geen glow) | onder-midden |
| `assets/sprites/arena/arena_bench.png` | 32x16 | 1 frame (eiken bank, dikke zitting + afgeschuinde uiteinden, 1 groot opgevouwen maroon doek met goudstreep; helmpje geschrapt in handronde 3) | onder-midden |
| `assets/sprites/arena/arena_crates.png` | 32x32 | 1 frame (2 gestapelde kisten met arena-stempel + ton) | onder-midden |
| `assets/sprites/arena/arena_brazier.png` | 128x32 = 4 frames 32x32 | vuurschaal op bronzen driepoot, 125 ms per frame; vlammen = emissive | onder-midden |
| `assets/sprites/arena/arena_vip_loge.png` | 48x64 | 1 frame: VIP-loge ingebouwd in de oosttribune (open naar het veld/west). Handronde 3: borstwering in hetzelfde travertijn als de tribuneborstwering (loopt door) met gouden reling en maroon kleed; schuin oplopende, getrapte zijwangen (noord belicht, zuid in schaduw), transparant erbuiten zodat de tribunetegels doorlopen; gestreepte luifel met lichte voorplooi, donkere achterhelling, geschulpte franje, gouden pinakels en slagschaduw op de vloer; troon + echo-hoogwaardigheidsbekleder, 2 wachters, 1 glitch-scheur | onder-midden |
| `assets/sprites/arena/arena_sand_ring.png` | 64x64 | vloerdecal: platgelopen zandring rond het emblem (alpha 0 buiten de ring) | gecentreerd op het emblem; boven de vloer, onder alle y-sort-sprites |
| `assets/sprites/npc/arena_koopman_wm1_slim.png` | 72x128 = 3x4 frames 24x32 | rijen down/left/right/up, kol 0 stand, 1/2 stappen, `WALK_CYCLE [1,0,2,0]` (zoals koopman_veld/henrik) | voeten op y31, midden x12 |
| `assets/sprites/npc/arena_koopman_wm1_slim_idle.png` | 48x128 = 2x4 frames 24x32 | idle: rijen als boven, kol 0 rust, kol 1 adem (hoofd+torso 1px omlaag); 600 ms per frame | idem |

Props: `centered=false`, `offset=(-w/2,-h)` per frame (gate (-24,-48), torch (-8,-32), banner (-8,-32), counter (-24,-32), weapon_rack (-16,-32), notice_board (-16,-32), bench (-16,-16), crates (-16,-32), brazier (-16,-32), vip_loge (-24,-64)).
Collision-voeten (suggestie):
- gate: de pilasters, 2x(8x8) onderaan; f1 opent het midden (32 px).
- torch: 6x4 rond de voet.
- counter: 44x12 onderste strook.
- weapon_rack: 28x6 onderste strook (de plank).
- bench: 28x5 onderste strook; crates: 30x14 onderste strook; brazier: 10x6 rond de voet.
- vip_loge: de hele loge staat op de oosttribune (al niet begaanbaar), geen extra collision nodig.
- notice_board: 2x (4x4) onder de palen (x3-4 en x27-28); de rest is doorloopbaar achter/voor het bord volgens y-sort.
- NPC: 12x6 standaard.

### Karakter: de Arena-kwartiermeester
Een kale, gepensioneerde gladiator met:
- een maroon hoofdband (knoop achter)
- een donkere baard
- een stalen schouderstuk op links
- een maroon tabard met gouden V-hals en medaillon, en pteruges met gouden punten
- een riem met gouden gesp en een violette tokenbuidel

Het zijaanzicht (v2) heeft een echt profiel: platte schedel, wenkbrauw + oog, neus, oor, baard langs de kaak en de knoop van de hoofdband achter, consistent met voor- en achteraanzicht. Het palet sluit aan op de banners en de toonbank, zodat de NPC visueel bij de shop hoort.

### Arena-token
Een violette zeshoek met witte gekruiste zwaarden en gouden gevesten. Op 1x is hij duidelijk anders dan `cat_goud`: een andere vorm (hex in plaats van een stapel munten) en een andere kleur (violet in plaats van goud). De preview staat in `preview/icons_1x_4x_dark_ui.png`.

## Wereldkaart-atlas `wereld_v18_arena.png`
| atlas coord | tile | inhoud |
|---|---|---|
| (0,0) (1,0) (0,1) (1,1) | 0-3 | Colosseum **open** TL, TR, BL, BR |
| (2,0) (3,0) (2,1) (3,1) | 4-7 | Colosseum **locked** TL, TR, BL, BR |

Open en locked zijn even groot: 2x2 tiles = 32x32, zoals Mapleton.
- **Open** = de variant die altijd gebruikt wordt (sinds Dennis 16:31 is de lobby altijd bereikbaar): vaandel, pad, open poort, 2 brandende fakkels (glow, `tile_cells` in lights_arena.json).
- **Locked** (tiles 4-7) is **ongebruikt voor toegang**. Hij blijft in de atlas als optionele visual, bijvoorbeeld voor een latere "ruïne vóór ontdekking"-staat. CODE hoeft hem niet te koppelen.

**Belangrijk:** de omgeving van de tiles is transparant. De grasstiles van v14 zijn off-palette (≈51,67,43), dus ik kon geen gras inbakken. Je moet de tiles op een **overlay-TileMapLayer** boven Ground zetten, of als Sprite2D (zoals KasIngang en BerggrotIngang). Als je ze in de Ground-laag zelf zet, krijg je gaten.

**Plek (BEVESTIGD door Dennis, 2026-11-15):**
- 16:06: "plek van colosseum onder willowdale, gaat pas open na vesper"
- 16:20: "Doe hem nog 4 vakjes zuid"
- 16:23: "Doe maar nog 2 vakjes naar zuid"
- 16:31: "maak de coloseum zo dat je de lobby inkan voordat je vesper hebt maar nog niet verder naar binnen kan"

- De site staat op tiles **(30,32)-(31,33)**, linksboven (30,32), dus px (480,512)-(511,543) en midden px (496,528). De exit staat op (480,512).
- Dat is 6 tiles zuidelijker dan de eerste plek (30,26), onder het dorp Wilgendal/Willowdale. Dat dorp is `Exits/NaarWilgendal` in `wereldkaart.tscn`, tiles (30,23)-(31,24).
- Ondergrond: alle 4 tiles zijn v14 #0 (gras), niet solid.
- Omgeving:
  - noord: de as/grind-inham (27-31,31)
  - oost: gras op x32, bos op (33-34,32)
  - zuid: bos op (28-31,34); bos is begaanbaar
  - west: gras op (27-29,32) en (29,33), een bosje op (28,33), en bergen verder naar het westen (23-26)
  - water: het meer begint pas op rij 37 (x24-30), 3 rijen onder de site; niet aangrenzend
- Pad (gecontroleerd met een BFS over de Ground-laag, berg en zee solid): spawn `van_wilgendal` (30,25) → (31,25) (31,26) (31,27) (31,28) (31,29) → (30,29) (30,30) (30,31) → (30,32). Het pad loopt via kolom 31 langs de bergrand, want (30,28) is berg, en daarna door de as/grind-inham.
Overlay-tiles: altijd **open**, atlas coords (0,0) (1,0) (0,1) (1,1) → tiles (30,32) (31,32) (30,33) (31,33).

## Toegang (BEVESTIGD, Dennis 16:31)
1. **Wereldkaart → lobby: altijd open.** `map_exit` 2x2 op (480,512) → `arena_lobby.tscn`, zonder vlag of melding.
2. **Lobby → hal: op slot tot `noor_lid`.** De poort-prop in de lobby (192,48) staat op `arena_gate.png`:
   - **`noor_lid` NIET gezet:** frame **2** (geketend, hangslot met violette rune). De opening (48px, x168-216) is solid. Interactie/ertegenaan lopen geeft de melding **"The gate is closed."**.
   - **`noor_lid` gezet:** frame **1** (open). Dan wordt de opening een exit naar `arena_hal.tscn` (spawn bij de zuidpassage).
   - Optioneel kan de overgang 2→1 eenmalig met screenshake/geluid.
3. **Hal-poort (noord, monsterpoort):** frame 0 dicht, frame 1 open tijdens een golf. Daar zit geen vlag op.
4. De shop (koopman, toonbank) en de wachtruimte zijn dus vóór Vesper al bruikbaar.

Vlagnaam `noor_lid`: ik heb de naam gekozen omdat `berggrot_data.gd` hem ook gebruikt (`TUNNEL_VLAG`). Waar hij precies gezet wordt heb ik niet nagelopen.
De data staat in `placements_arena.json` → `toegang` en bij de lobby-gate-plaatsing (frames + melding).
De data hiervoor staat in `placements_arena.json` → `wereldkaart` en `layouts.json` → `wereldkaart`.
`wereld_v17_iconen.png` is niet aangeraakt.

## Interieur-atlas `arena_tiles.png` 256x144 (index = y*16 + x, 16x16)
| idx | tile |
|---|---|
| 0-1 | sand_a, sand_b |
| 2 | sand_scorch |
| 3 | sand_pebbles |
| 4 | sand_glitch_tear (glow) |
| 5 | sand_spear |
| 6-7 | flag_a, flag_b |
| 8 | flag_cracked |
| 9 | flag_glitch (glow) |
| 10 | flag_drain |
| 11 | flag_shadow_n |
| 12 | sand_shadow_n |
| 13 | flag_exit_dark |
| 14-15 | flag_shadow_w, flag_shadow_e |
| 16-19 | kerb n, s, w, e |
| 20-23 | kerb nw, ne, sw, se (buitenhoeken) |
| 24-27 | kerb_in nw, ne, sw, se (binnenhoeken) |
| 28-31 | emblem 2x2: TL, TR, BL, BR (messing ring, violette kern = glow) |
| 32-33 | cap_n, cap_n_b |
| 34-36 | cap_w, cap_e, cap_s |
| 37-38 | cap_sw, cap_se |
| 39-40 | cap_s_end_l, cap_s_end_r |
| 41-42 | face_up a/b |
| 43-44 | face_low a/b |
| 45 | face_up_shade_l |
| 46 | face_low_shade_l |
| 47 | face_up_shade_r |
| 48-49 | stand_n_back, +crowd |
| 50-52 | stand_n_mid, +crowd a/b |
| 53-54 | stand_n_front, +crowd |
| 55-57 | stand_n trap: back/mid/front |
| 58 | face_low_shade_r |
| 59-60 | arch_up, arch_low (raamnis) |
| 61-62 | pilaster up/low |
| 63 | void (zwart) |
| 64-67 | stand_w outer, mid, inner, mid_crowd |
| 68-71 | stand_e inner, mid, outer, mid_crowd |
| 72-74 | stand_w top-ends: outer, mid, inner |
| 75-77 | stand_s front, mid, back |
| 78-79 | stand_s mid_crowd, front_crowd |
| 80-88 | gate_recess 3x3 (80 + rij*3 + kol) |
| 89-91 | passage l/m/r |
| 92 | passage_m_end |
| 93-95 | stand_e top-ends: inner, mid, outer |
| 96-107 | **nieuw v2** gate_recess_c 4x3 (96 + rij*4 + kol): poortnis voor een poort gecentreerd tússen twee kolommen; 48px nis in het midden, buitenste 8px per kant = muurkap/-vlak met halve pilaster die de gate-prop omlijst |
| 108-109 | **nieuw v2** kerb_w_shadow_n, kerb_e_shadow_n (randen van de loper direct onder de poort) |
| 110-111 | **nieuw v2** flag_shadow_nw, flag_shadow_ne (hoekschaduw noordmuur + zijmuur) |
| 112-113 | **nieuw v3** flag_worn_a/b (gepolijste, uitgesleten tegels: toonbank, looproutes) |
| 114 | **v3** flag_crack_big (lange barst, afgebroken hoek) |
| 115 | **v3** flag_drain_round (ronde put met mos) |
| 116-117 | **v3** flag_sandspill_e / _w (zand van de loper over de kerb gelopen; _e links van de loper, _w rechts) |
| 118-119 | **v3** trophy_niche_up / _low (handronde 3: boven = lichte stalen kuifhelm op gouden plank, onder = rond maroon/goud schild over donkere gekruiste speren; elk eigen omlijning, leesbaar op 2x; vervangt in de lobby de raamnissen) |
| 120 | **v3** sand_worn (platgelopen zand) |
| 121 | **v3** sand_drag (sleepsporen noord-zuid) |
| 122 | **v3** sand_prints (voetstappen naar het noorden) |
| 123 | **v3** sand_soot (roetvlek onder fakkels/vuurschalen) |
| 124-127 | **v3** battle_scar 2x2: TL, TR, BL, BR (inslagkrater met barsten en een gebroken gladius) |
| 128-130 | **v3** stand_n back/mid/front _crowd_v (vol, gevarieerd publiek: zittend, armen omhoog, leunend; 4 tinten) |
| 131 | **v3** stand_n_mid_crowd_flags (met vlaggetjes) |
| 132-133 | **v3** stand_w_mid_crowd_v, _flags |
| 134-135 | **v3** stand_e_mid_crowd_v, _flags |
| 136-137 | **v3** stand_s mid/front _crowd_v (ruggen, soms armen omhoog) |
| 138-139 | **v3** stand_w_outer_crowd, stand_e_outer_crowd |
| 140-141 | **v3** stand_n_mid_crowd_glitch f0/f1: **animatie-tile** (2 frames naast elkaar, Godot TileSet `animation_columns=2`, 250 ms/frame), cyaan/magenta scan, geen emissive |
| 142 | **v3** stand_n_front_crowd_flags |
| 143 | **v3** stand_s_back_crowd |

Het publiek ("echo's": donkere silhouetten met een periwinkle highlight) is bewust **géén** glow. Zo krijg je geen lichtvlekken op de tribunes.
Glow-tiles (`tile_cells`) zijn 4, 9, 28-31 (emblem). De nieuwe v3-tiles hebben geen glow.

## Kamerlayouts (`layouts.json`, `src/rooms.py`)
- **Hal 30x20** (480x320 px):
  - Tribunes noord: rijen 0-2, met de poortnis op x13-15 en trappen op x7 en x22.
  - Tribunes west en oost: x0-2 en x27-29, voor y3-16.
  - Tribunes zuid: rijen 17-19, met de ingangspassage op x13-15.
  - Zandveld: 24x14 (x3-26, y3-16) met een kerb-ring, zandschaduw onder de poort en het emblem op (14-15, 9-10).
  - Decals: ≈2%.
  - **v3:**
    - Publiek: vol en gevarieerd op alle tribunes (128-143). Glitch-animatietile 140/141 op (4,1) en (25,1).
    - Zand: platgelopen plekken (120, ≈12%), sleepsporen (121) en voetstappen (122) van de zuidpassage naar de poort (x14-15).
    - Roet (123) onder fakkels en vuurschalen, en 2 slagveld-littekens (124-127) op (6-7,11-12) en (20-21,5-6).
    - Een zandring-decal rond het emblem.
    - VIP-loge op de oosttribune (x27-29, y8-11).
    - 4 vuurschalen langs de veldrand.
  - Noordpoort = monsterpoort (gate f0 dicht → f1 open bij gevechtsstart); zuidpassage = entree.
- **Lobby 24x14** (384x224 px), spiegel-symmetrisch rond x=192 (kolom c <-> 23-c):
  - Rij 0: muurkap.
  - Rijen 1-2: muurvlak met **trofeeënnissen** (118/119, x4 en x19; v3, vervangen de raamnissen), pilasters (x7, x16) en schaduwtiles (x1, x22).
  - Poortnis: de gecentreerde 4x3-set (tiles 96-107) op x10-13. De poort-prop staat **gecentreerd op x=192** (tussen kolom 11 en 12) en bedekt px 168-216. De zichtbare 8px links en rechts zijn de halve pilasters uit de set.
  - Vloer: slate-vloer met schaduwranden (hoeken 110/111) en een zandloper van 2 breed (x11-12) met kerbs op x10/x13 (onder de poort 108/12/12/109).
  - Rij 13: zuidkap, met de uitgang op x10-13 (cap-ends op x9 en x14).
  - **v3:**
    - Uitgesleten tegels (112/113) voor de toonbank en op looproutes.
    - Barsten (114) op (3,11), (20,5) en (21,10); ronde putten (115) op (6,11) en (17,8).
    - Zandranden langs de loper (116 op x9, 117 op x14, ≈70% van de rijen 4-11).
    - Wachtruimte in de onderste helft: 3 banken en 2 kistenstapels.
    - Een lichtschacht uit het plafond op de loper (data-licht, zie HD-2D).

Plaatsingen staan in `data/hd2d/placements_arena.json` (px, onder-midden):

| kamer | prop | posities | opmerking |
|---|---|---|---|
| hal | gate | (232,48) | f0 |
| hal | torches | (196,62), (268,62), (60,150), (60,262), (420,150), (420,262) | |
| hal | banners | (88,62), (152,62), (312,62), (376,62) | |
| hal | brazier (4f) | (120,76), (360,76), (104,268), (376,268) | v3, veldrand |
| hal | vip_loge | (456,192) | v3, oosttribune x27-29 y8-11 |
| hal | sand_ring | (240,192) | v3, decal gecentreerd op het emblem (240,160) |
| lobby | gate | (192,48) | **f2 tot `noor_lid`** ("The gate is closed."), daarna f1 = exit naar de hal; gecentreerd op x=192 over tiles 96-107 (x10-13) |
| lobby | banners | (144,46), (240,46) | |
| lobby | torches | (88,60), (296,60) | |
| lobby | notice_board | (344,62) | tegen de noordmuur, x20-21 |
| lobby | weapon_rack | (296,124) | vrijstaand, spiegelt de toonbank (88,120) |
| lobby | koopman (idle) | (88,98) | |
| lobby | counter | (88,120) | |
| lobby | bench | (64,186), (112,186), (296,186) | v3, wachtruimte |
| lobby | crates | (36,206), (348,206) | v3 |
| lobby | lichtschacht | (192,150) | v3, data-licht in `placements_arena.json` → `lights_extra` |

Scènepaden `res://scenes/maps/arena_hal.tscn` en `arena_lobby.tscn` zijn TIJDELIJKE AANNAMES (CODE kiest).

## HD-2D (conventie van art_hd2d wm1_full + lichtprops)
- Kopieer `_n` uit `repo_drop_normals/` en `_e` uit `repo_drop/` naar `assets/hd2d/<pad zonder assets/>`.
  - `_n` heeft G = omhoog, en zijn alpha is gelijk aan de albedo-alpha.
  - `_e` gebruikt alleen paletkleuren.
- Merge `data/hd2d/lights_arena.json` → `lights.json`. Doe hetzelfde met `maps_index_arena.json` → `maps_index.json`, `presets_arena.json` → `presets.json` en `placements_arena.json` → `placements.json`. Bij alle vier merge je op key, met hetzelfde schema.
- Fakkel: kind `fire`, family warm, energy 1.1, scale 1.5, height 24, flicker 1.2, warme halo 48. De lichtpositie is offset (8.4,22.2) vanaf linksboven van het frame; de halo zit op de vlam (8.4,6.2).
- Vuurschaal (v3): kind `fire`, family warm, energy 1.3, scale 1.8, height 20, flicker 1.0, warme halo 56, anker (16.3,20.4).
- Lichtschacht lobby (v3): data-only, `placements_arena.json` → `lights_extra.arena_lobby`. Het is een zachte ronde PointLight2D zonder flikker op (192,150), straal 72, kleur [1.0,0.93,0.80], energy 0.6.
- Gate- en banner-gem: kind `glow` (emissive + halo, nooit een PointLight2D). Dat geldt ook voor de rune op het hangslot in gate-frame 2.
- **Lichtbudget (v3):**
  - **Hal:** 6 fakkels + 4 vuurschalen = **10 vuurbronnen**, met de 4 hero-lights erbij 14 kandidaten tegen max. 8 PointLight2D. CODE merget: bijvoorbeeld noordpaar fakkels → 1, noord-vuurschalen → 1, zuid-vuurschalen + zuid-fakkels → 2, west/oost-fakkels → 1 per kant. Dat geeft 4 vuurlichten + 4 hero = 8; de rest werkt via halo/emissive.
  - **Lobby:** 2 fakkels + 1 lichtschacht = 3, met hero 7 ≤ 8. Geen merge nodig.
- Presets:
  - `arena_hal`: afgeleid van dorp_wilgendal, echte dag/nacht, groep "arena", 's nachts fire 1.5 en warme motes.
  - `arena_lobby`: afgeleid van archief_v1_gang, fixed, ambient [0.40,0.37,0.42], warme fill.

## Open vragen
1. De wereldkaart-tiles hebben een transparante omgeving (het v14-gras is off-palette). Ze moeten dus op een overlay-laag of als Sprite2D. CODE moet bevestigen welke.
2. Toegang is BEVESTIGD (Dennis 16:31): de wereldkaart is altijd open en de lobbypoort zit op slot tot `noor_lid`. CODE bevestigt de vlagnaam en bouwt de gate-collision, de melding en de exit naar de hal.
3. Het NPC-pad: de slim-lookup van KaartStijl in npc.gd verwacht een basis-sheet. Ik raad aan dat CODE direct naar `arena_koopman_wm1_slim.png` verwijst.
4. Lichtbudget hal: 10 vuurbronnen + 4 hero > 8, dus mergen (voorstel staat hierboven).
5. Atlas is nu 256x144 (rijen 6-8 nieuw); indices 0-111 zijn stabiel. Als de TileSet al bestaat, moet CODE de atlas-grootte, de nieuwe rijen en de animatie op 140/141 toevoegen.
6. `arena_gate.png` is nu 144x48 (3 frames). Bestaande `hframes=2`-instanties moeten naar `hframes=3`.
7. Scènepaden `arena_hal.tscn` / `arena_lobby.tscn` zijn aannames.
8. De `arena_sand_ring`-decal moet in een laag tussen de vloer en de y-sort.


## Handronde 3 (16:42)
VIP-loge, trofeeënnis (tegels 118/119) en bank opnieuw met de hand gepixeld. Formaten en indices ongewijzigd (48x64, 2x 16x16, 32x16); geen wijziging in layouts/placements/offsets. Voor/na: `preview/interior/v2/handronde3_voor_na_4x.png`.
