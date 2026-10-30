# Donker Woud: tegels 16x16 voor RPG ART (WM1 T2)

Besluit Dennis: tegels zijn **16x16**. Alles hieronder is nu **PLACEHOLDER** (`assets/placeholder/woud/`, gemaakt door
`tools/woud_tegels_placeholders.py`). De mapping tegel-id -> bestand staat in `data/woud_tegels.json`; de code
(`scripts/data/woud_tegels.gd`) leest alleen die JSON. **Echte art inwisselen = alleen `"file"` aanpassen** (zelfde maat).

Afspraken:
- Maat: 16x16 per frame. Meer frames = horizontaal naast elkaar (4 frames = 64x16). Animatie 4 fps (TEMPORARY ASSUMPTION).
- Laag `grond` = dekkend, onder de speler. Laag `overlay` = doorzichtig, boven de speler (kruinen, mist); nooit massief.
- `solid` = blokkeert lopen (botsing komt uit de mapping, niet uit het plaatje).
- Randen/overgangen: pad, water (oever) en bladerdak zijn autotegels: 3x3 (NW N NO / W midden O / ZW Z ZO)
  + 4 binnenhoeken. Letter = de kant waar het ANDERE terrein ligt (bv. `pad_n`: gras boven, pad onder).
- Bomen zijn 2 breed x 3 hoog: 2 rijen kruin (overlay) + 1 rij stamvoet (massief).
- De bestaande vijf woudkamers gebruiken de atlas `assets/tiles/dungeon/woud_tiles_v9b.png` (RPG ART, docs/WOUD_TILES.txt)
  en veranderen niet. Deze lijst geldt voor de nieuwe kamer `woud_beek` en latere woudkamers op de 16x16-mapping.

| id | naam | functie | groep | laag | massief | frames | maat | varianten | rand/overgang |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `grond_a` | bosvloer, variant a | Grond | grond | nee | 1 | 16x16 | 4 | - |
| 1 | `grond_b` | bosvloer, variant b | Grond | grond | nee | 1 | 16x16 | 4 | - |
| 2 | `grond_c` | bosvloer, variant c | Grond | grond | nee | 1 | 16x16 | 4 | - |
| 3 | `grond_d` | bosvloer, variant d | Grond | grond | nee | 1 | 16x16 | 4 | - |
| 4 | `grond_blad_a` | bosvloer met dode bladeren, variant a | Grond | grond | nee | 1 | 16x16 | 2 | - |
| 5 | `grond_blad_b` | bosvloer met dode bladeren, variant b | Grond | grond | nee | 1 | 16x16 | 2 | - |
| 6 | `grond_schaduw_n` | vloer met schaduw onder de bosrand (boven) | Grond | grond | nee | 1 | 16x16 | 1 | N |
| 7 | `grond_schaduw_w` | vloer met schaduw langs de linkerrand | Grond | grond | nee | 1 | 16x16 | 1 | W |
| 8 | `grond_schaduw_nw` | vloer met schaduw in de hoek linksboven | Grond | grond | nee | 1 | 16x16 | 1 | NW |
| 9 | `pad_nw` | bospad, rand NW | Paden | grond | nee | 1 | 16x16 | 1 | NW |
| 10 | `pad_n` | bospad, rand N | Paden | grond | nee | 1 | 16x16 | 1 | N |
| 11 | `pad_no` | bospad, rand NO | Paden | grond | nee | 1 | 16x16 | 1 | NO |
| 12 | `pad_w` | bospad, rand W | Paden | grond | nee | 1 | 16x16 | 1 | W |
| 13 | `pad_m` | bospad, midden | Paden | grond | nee | 1 | 16x16 | 1 | M |
| 14 | `pad_o` | bospad, rand O | Paden | grond | nee | 1 | 16x16 | 1 | O |
| 15 | `pad_zw` | bospad, rand ZW | Paden | grond | nee | 1 | 16x16 | 1 | ZW |
| 16 | `pad_z` | bospad, rand Z | Paden | grond | nee | 1 | 16x16 | 1 | Z |
| 17 | `pad_zo` | bospad, rand ZO | Paden | grond | nee | 1 | 16x16 | 1 | ZO |
| 18 | `pad_binnen_nw` | bospad binnenhoek (alleen NW-hoekje gras) | Paden | grond | nee | 1 | 16x16 | 1 | NW |
| 19 | `pad_binnen_no` | bospad binnenhoek (alleen NO-hoekje gras) | Paden | grond | nee | 1 | 16x16 | 1 | NO |
| 20 | `pad_binnen_zw` | bospad binnenhoek (alleen ZW-hoekje gras) | Paden | grond | nee | 1 | 16x16 | 1 | ZW |
| 21 | `pad_binnen_zo` | bospad binnenhoek (alleen ZO-hoekje gras) | Paden | grond | nee | 1 | 16x16 | 1 | ZO |
| 22 | `pad_m_b` | bospad midden, variant B | Paden | grond | nee | 1 | 16x16 | 2 | - |
| 23 | `rand_top_nw` | bladerdak (bosrand-top), open NW | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | NW |
| 24 | `rand_top_n` | bladerdak (bosrand-top), open N | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | N |
| 25 | `rand_top_no` | bladerdak (bosrand-top), open NO | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | NO |
| 26 | `rand_top_w` | bladerdak (bosrand-top), open W | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | W |
| 27 | `rand_top_m` | bladerdak (bosrand-top), dicht midden | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | M |
| 28 | `rand_top_o` | bladerdak (bosrand-top), open O | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | O |
| 29 | `rand_top_zw` | bladerdak (bosrand-top), open ZW | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | ZW |
| 30 | `rand_top_z` | bladerdak (bosrand-top), open Z | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | Z |
| 31 | `rand_top_zo` | bladerdak (bosrand-top), open ZO | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | ZO |
| 32 | `rand_top_binnen_nw` | bladerdak binnenhoek (alleen NW open) | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | NW |
| 33 | `rand_top_binnen_no` | bladerdak binnenhoek (alleen NO open) | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | NO |
| 34 | `rand_top_binnen_zw` | bladerdak binnenhoek (alleen ZW open) | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | ZW |
| 35 | `rand_top_binnen_zo` | bladerdak binnenhoek (alleen ZO open) | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | ZO |
| 36 | `rand_stam_boven_links` | stammen onder het bladerdak, bovenste rij, links | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 37 | `rand_stam_onder_links` | stamvoeten, onderste rij, links | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 38 | `rand_stam_boven_midden` | stammen onder het bladerdak, bovenste rij, midden | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 39 | `rand_stam_onder_midden` | stamvoeten, onderste rij, midden | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 40 | `rand_stam_boven_rechts` | stammen onder het bladerdak, bovenste rij, rechts | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 41 | `rand_stam_onder_rechts` | stamvoeten, onderste rij, rechts | Bosrand (randen/muur van bomen) | grond | ja | 1 | 16x16 | 1 | - |
| 42 | `boom_eik_kruin_boven_l` | grote eik, kruin boven l (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 43 | `boom_eik_kruin_boven_r` | grote eik, kruin boven r (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 44 | `boom_eik_kruin_midden_l` | grote eik, kruin midden l (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 45 | `boom_eik_kruin_midden_r` | grote eik, kruin midden r (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 46 | `boom_eik_voet_l` | grote eik, stamvoet l (massief) | Bomen en struiken | grond | ja | 1 | 16x16 | 1 | - |
| 47 | `boom_eik_voet_r` | grote eik, stamvoet r (massief) | Bomen en struiken | grond | ja | 1 | 16x16 | 1 | - |
| 48 | `boom_den_kruin_boven_l` | donkere den, kruin boven l (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 49 | `boom_den_kruin_boven_r` | donkere den, kruin boven r (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 50 | `boom_den_kruin_midden_l` | donkere den, kruin midden l (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 51 | `boom_den_kruin_midden_r` | donkere den, kruin midden r (overlay) | Bomen en struiken | overlay | nee | 1 | 16x16 | 1 | - |
| 52 | `boom_den_voet_l` | donkere den, stamvoet l (massief) | Bomen en struiken | grond | ja | 1 | 16x16 | 1 | - |
| 53 | `boom_den_voet_r` | donkere den, stamvoet r (massief) | Bomen en struiken | grond | ja | 1 | 16x16 | 1 | - |
| 54 | `struik` | lage struik, 1 tegel (massief) | Bomen en struiken | grond | ja | 1 | 16x16 | 2 | - |
| 55 | `water_m` | beekwater midden (animatie 4 frames, horizontaal 64x16) | Water (beek) | grond | ja | 4 | 64x16 | 1 | - |
| 56 | `water_oever_n` | oever N (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | N |
| 57 | `water_oever_z` | oever Z (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | Z |
| 58 | `water_oever_w` | oever W (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | W |
| 59 | `water_oever_o` | oever O (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | O |
| 60 | `water_oever_nw` | oever NW (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | NW |
| 61 | `water_oever_no` | oever NO (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | NO |
| 62 | `water_oever_zw` | oever ZW (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | ZW |
| 63 | `water_oever_zo` | oever ZO (gras -> water, massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | ZO |
| 64 | `water_oever_binnen_nw` | oever binnenhoek NW (massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | NW |
| 65 | `water_oever_binnen_no` | oever binnenhoek NO (massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | NO |
| 66 | `water_oever_binnen_zw` | oever binnenhoek ZW (massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | ZW |
| 67 | `water_oever_binnen_zo` | oever binnenhoek ZO (massief) | Water (beek) | grond | ja | 4 | 64x16 | 1 | ZO |
| 68 | `stapsteen` | stapsteen in de beek (beloopbaar, water eromheen) | Water (beek) | grond | nee | 4 | 64x16 | 1 | - |
| 69 | `brug_links` | houten brug over de beek, horizontaal, links (beloopbaar) | Brug | grond | nee | 1 | 16x16 | 1 | - |
| 70 | `brug_midden` | houten brug over de beek, horizontaal, midden (beloopbaar) | Brug | grond | nee | 1 | 16x16 | 1 | - |
| 71 | `brug_rechts` | houten brug over de beek, horizontaal, rechts (beloopbaar) | Brug | grond | nee | 1 | 16x16 | 1 | - |
| 72 | `steen` | rotsblok (massief) | Props | grond | ja | 1 | 16x16 | 2 | - |
| 73 | `stronk` | boomstronk (massief) | Props | grond | ja | 1 | 16x16 | 1 | - |
| 74 | `stam_liggend_l` | liggende stam, linkerhelft (massief, 2 breed) | Props | grond | ja | 1 | 16x16 | 1 | - |
| 75 | `stam_liggend_r` | liggende stam, rechterhelft (massief, 2 breed) | Props | grond | ja | 1 | 16x16 | 1 | - |
| 76 | `varen` | varen (decor, beloopbaar) | Props | grond | nee | 1 | 16x16 | 2 | - |
| 77 | `paddenstoel` | paddenstoelen (decor, beloopbaar) | Props | grond | nee | 1 | 16x16 | 2 | - |
| 78 | `paddenstoel_gloed` | gloeiende magenta paddenstoel (decor, 2 frames gloed) | Props | grond | nee | 2 | 32x16 | 1 | - |
| 79 | `wegwijzer` | houten wegwijzer (massief, leesbaar) | Props | grond | ja | 1 | 16x16 | 1 | - |
| 80 | `mist` | mistsliert (overlay, horizontaal herhaalbaar) | Props | overlay | nee | 1 | 16x16 | 1 | - |
| 81 | `uitgang_pad` | bospad uit de kamer (beloopbaar, uitgangstegel) | Uitgang | grond | nee | 1 | 16x16 | 1 | - |
| 82 | `uitgang_rand_l` | bosrand links van de uitgang (massief) | Uitgang | grond | ja | 1 | 16x16 | 1 | - |
| 83 | `uitgang_rand_r` | bosrand rechts van de uitgang (massief) | Uitgang | grond | ja | 1 | 16x16 | 1 | - |

Totaal: 84 tegels.

Open vragen / TEMPORARY ASSUMPTIONS:
- Twee boomsoorten (`eik`, `den`); meer soorten = nieuwe namen in de JSON (en in deze lijst).
- Water: alleen een smalle beek (oevers massief, stapstenen en brug beloopbaar). Geen diep/ondiep-verschil.
- Pad-binnenhoeken en bladerdak-binnenhoeken worden nu nog niet in `woud_beek` gebruikt, maar horen bij de set.
