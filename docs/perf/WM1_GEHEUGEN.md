# WM1 geheugen- en textuurprofiel

Branch `cursor/wm1-geheugen-5034`. Scope: alleen WM1 (de 48 kaarten in `scenes/maps/` plus de WM1-gevechten), dieper niet groter:
geen nieuwe content, geen art aangeraakt (`tools/handwerk.txt` onaangeroerd), geen pixel veranderd. Focus op VRAM/RAM,
importinstellingen, dubbele en ongebruikte bestanden, en vooraf laden versus op aanvraag. De FPS-kant (draw calls, frametijd)
zit bij PR #216 (`agent/cursor/perf-wm1`); deze branch raakt daarom `game_state.gd`, `game_data.gd` en `dorp_ground.gd` niet.

## Meten (reproduceerbaar, headless)

```bash
GODOT=/pad/naar/Godot_v4.3-stable_linux.x86_64
$GODOT --headless --path . --import                       # eenmalig
GODOT=$GODOT tools/geheugen/wm1_meting.sh /tmp/meet/na      # ~6 min: opstart, 5 gevechten, 48 kaarten (elk een vers proces), sessie, texturen-audit
python3 tools/geheugen/rapport.py /tmp/meet/na /tmp/meet/voor   # markdown; met twee mappen een voor/na-tabel
GODOT=$GODOT tools/geheugen/run_tests.sh                    # 38 checks voor deze wijzigingen (zelfde PASS/FAIL/RESULT-formaat)
```

`tools/geheugen/wm1_meting.gd` (scene `wm1_meting.tscn`, geen test en geen gameplay) leest per kaart de Performance-monitors
(`RENDER_TEXTURE_MEM_USED`, `MEMORY_STATIC`, object-, resource- en nodetellers), telt de unieke texturen via een boomwandeling
(inclusief TileSets, SpriteFrames, scriptvariabelen) en meet in een aparte modus de echte GPU-kosten van elke png
(`--texaudit`: laden zonder cache, verschil van `RENDER_TEXTURE_MEM_USED`). Modi: `--start`, `--scene=<pad>`, `--sessie`,
`--battle=<terrein>`, `--texaudit`, `--pixels`, `--lijst`.

Beperkingen, lees dit voor je getallen vergelijkt:
- Godot 4.3-stable (zoals CI), `gl_compatibility` onder xvfb met software-GL (Mesa llvmpipe). Texturen- en objecttellers zijn
  deterministisch; RSS en tijden niet (RSS schommelt +-20 MB tussen identieke runs) en staan daarom niet in het rapport.
- `RENDER_TEXTURE_MEM_USED` is de boekhouding van de engine. In 4.3 telt de compatibility-renderer voor RGBA8-texturen een volledige
  mipmapketen mee (`get_image_data_size(..., mipmaps)` krijgt het aantal levels als bool), terwijl er niets wordt gealloceerd:
  echte kosten zijn breedte x hoogte x 4. RGB8-bestanden (de ondoorzichtige achtergronden) staan al op 4 bytes per pixel en
  kloppen. Absolute MB's van RGBA8-texturen zijn dus ~33% te hoog; verschillen blijven vergelijkbaar.
- Een nieuw spel, de wereldkaart-intro (video) staat uit, een kaart telt 12 frames na het laden. Dungeon100 krijgt een vaste seed.

## Resultaten

`main` = fb17c40 + alleen de meettool. "Deze PR" is wat er in deze branch staat. "+ #216" is lokaal samengevoegd met PR #216
(achtergronden op aanvraag, nog niet gemerged). "+ voorstel" is #216 plus het patchvoorstel hieronder (niet in deze PR).

| Meting (MB tenzij anders) | `main` | deze PR | + #216 | + voorstel |
|---|---:|---:|---:|---:|
| Opstart: texturen | 51.0 | 51.0 | 28.9 | 10.6 |
| Opstart: statisch geheugen | 46.9 | 46.9 | 46.9 | 46.8 |
| `wereldkaart` open: texturen | 51.1 | 50.9 | 28.8 | 10.5 |
| `wilgendal` open: texturen | 53.0 | 52.0 | 29.8 | 11.6 |
| `dorp_wilgendal` open: texturen | 71.2 | 63.6 | 41.5 | 23.3 |
| `esdoorn` open: texturen | 53.3 | 52.2 | 30.0 | 11.8 |
| `woud_pad` open: texturen | 54.3 | 52.3 | 30.2 | 11.9 |
| `archief_v1_gang` open: texturen | 53.8 | 52.2 | 30.1 | 11.8 |
| `berggrot_mond` open: texturen | 53.6 | 52.1 | 29.9 | 11.7 |
| Gemiddelde van de 48 kaarten: texturen | 53.4 | 52.1 | 30.0 | 11.8 |
| Sessie (48 kaarten achter elkaar): texturen | 55.6 | 52.9 | 30.7 | 12.5 |
| Sessie: statisch geheugen na afloop | 113.3 | 83.9 | 83.9 | 83.8 |
| Sessie: statisch geheugen piek | 153.3 | 146.1 | 145.7 | 145.7 |
| Gevecht `gras` open: texturen | 52.5 | 52.5 | 30.4 | 12.1 |
| Gevecht `woud` open: texturen | 52.5 | 52.5 | 30.4 | 14.3 |
| Gevecht `boss` open: texturen | 53.5 | 53.5 | 31.4 | 15.3 |
| Objecten na de sessie | 4539 | 4476 | 4464 | 4456 |
| Resources na de sessie | 377 | 368 | 358 | 350 |

Tegelatlas-bronnen met `use_texture_padding` (opgevulde kopie in het geheugen), som over alle kaarten: voor 108 van 108 (atlas 13.4 MB), na 0 van 108 (atlas 0.0 MB).

Wat zit waar:
- **Wilgendal-dorp -7,6 MB, Esdoorn -1,1 MB, Donker Woud -2,0 MB**: de opgevulde atlaskopieen (`AtlasZuinig`).
- **Elke kamer met Action-arena ~-1,5 MB**: `SomArena` laadt alleen de sheets van de party.
- **Sessie: -29,5 MB statisch geheugen**: de BGM-cache bewaarde elke bezochte track (2,4 tot 4,6 MB ogg) tot het einde van de sessie.
- De texturen op de wereldkaart, in gevechten en bij het opstarten veranderen in deze PR niet: dat zijn de ~46 MB aan voorgeladen
  gevechtsachtergronden en heldensheets (`GameState._preload_paths`), het terrein van #216 (zie "Niet in deze PR").

## Wat er gedaan is

1. **Tegelatlassen zonder opgevulde kopie** (`scripts/core/atlas_zuinig.gd`, een regel in `scripts/map.gd`). Elke
   `TileSetAtlasSource` maakt met `use_texture_padding` (standaard aan) een tweede, opgevulde `ImageTexture` van de hele atlas
   naast het geimporteerde origineel. Alle atlasbronnen in WM1 hadden dat (108 over de 48 kaarten; gedeelde TileSets tellen per kaart mee). `AtlasZuinig.toepassen()` zet het
   uit voor elk TileSet onder de kaart, na `KaartStijl.toepassen`. Bewust een centrale aanroep in plaats van elke `TileSetAtlasSource.new()`
   en elke `.tres` aan te passen: `dorp_ground.gd`/`dorp_opbouw.gd` worden ook door andere branches aangepast.
   De padding voorkomt alleen "bleeding" bij schalen, draaien of lineaire filtering. Hier: Nearest als standaardfilter, geen
   camerazoom, snap-to-pixel aan, stretch mode `viewport` (de kaart wordt 1:1 getekend, daarna opgeschaald). Die aannames
   staan als checks in `geheugen_tests.gd`, samen met "geen enkele WM1-kaart heeft nog een bron met padding en geen Camera2D met zoom".
   **Pixel-perfect bewijs**: `tools/geheugen/beeldcheck.py` vergelijkt opnames van alle 48 kaarten (3 camerastanden, waarvan twee met
   sub-pixel-positie, op 16:9 en op 19,5:9 zoals een S25 Ultra) voor en na, met `--fixed-fps 60`: alle 288 opnames zijn bit-identiek.
2. **BGM-cache van `AudioManager` begrensd op 3 tracks** (`BGM_CACHE_MAX`, `_bgm_cache_aanraken`). Alleen BGM; SFX (3 MB samen) blijft
   gecachet. De huidige, de vorige en de gevechtsmuziek blijven staan, dus heen en weer lopen en een gevecht herstarten hapert niet.
   Een losgelaten track speelt bij de volgende keer gewoon opnieuw (checks in `geheugen_tests.gd`).
3. **`SomArena` laadt alleen de kaart- en aanvalssheets van de party en de reserve** (en altijd Dax). Eerder laadde elke kamer de
   sheets van alle vijf helden, ook de rekruten die er niet zijn. `sheet_for(id)` laadt een ontbrekende held op aanvraag (co-op-peer, swap),
   dus gedrag en bestaande suites blijven gelijk; `attack_texs` bevat voor de party precies wat eerder erin zat.

## Wat is onderzocht en bewust niet aangepast

| Onderwerp | Bevinding | Besluit |
|---|---|---|
| Importinstellingen | 533 `.import`-bestanden, allemaal `compress/mode=0` (lossless), `mipmaps/generate=false`, `fix_alpha_border=true`; 206 png's hebben geen `.import` in git (Godot maakt dezelfde standaard aan bij de importstap). De standaardfilter staat op Nearest. | Niets te winnen zonder pixels te veranderen. VRAM-compressie (ETC2/ASTC) is lossy en dus uitgesloten voor pixel art. |
| Dubbele bestanden | 10 groepen met identieke pixels, samen 0,3 MB (bv. `party_24x32/dax_wm1.png` en `som/kaart/dax_wm1.png`). | Niet de moeite: ze staan zelden tegelijk in het geheugen. Samenvoegen zou paden in data en tests raken. |
| Ongebruikte bestanden | `tools/geheugen/ongebruikt.py`: 136 png's waarvan de bestandsnaam nergens voorkomt, samen 0,12 MB op schijf (deels dynamisch opgebouwde paden). | Nul RAM-effect (ze worden niet geladen), en verwijderen raakt handwerk-art. |
| Atlas van het dorp | `grond_v8.png` en `grond_v8_licht.png` (beide 1024x336), `wilgendal_grond_tileset.png` en `bos_rand.png`: samen ~5,5 MB echt. Alles staat op zichtbare nodes. | Art/bake-keuze van RPG ART (een gecombineerde atlas); geen codewinst. |
| Statisch geheugen bij het opstarten | 46,9 MB: scripts en data van de autoloads; per dungeonkamer +6 MB (scripts compileren en de BGM). | Geen lek of dubbel werk gevonden. |
| Per-frame allocaties | Geen groei zichtbaar in de sessie (objecten/resources na 48 kaarten: 4476/368 tegen 4539/377 voor). | Niets te doen. |

## Niet in deze PR (overlapt met #216), met cijfers

`GameState._preload_paths()` houdt nog ~46 MB aan voorgeladen textures de hele sessie vast. #216 brengt dat al terug van 51,0 naar 28,9 MB
(zes achtergronden blijven bij het opstarten staan, 6 x 2,2 MB). Wat daarna nog te winnen is, staat als patch in
`docs/perf/voorstel_wm1_boot_preload.patch` (op de samenvoeging met #216; twee bestanden, ~20 regels):

- `BACKDROPS_BOOT = ["grass"]`: alleen de standaardachtergrond vooraf (`debug_autotest` eist alleen `grass` en `BATTLE_SCENE`); de rest komt
  via `_prefetch_backdrop` tijdens de gevechtsflits, één tegelijk. Vijf achtergronden minder: -11 MB.
- Alleen de gevechtssprites van de party vooraf (nu staan ook Noor, Lotte, Kael en Orion vooraf, 4 x 1,8 MB, terwijl ze er bij het
  opstarten niet bij zijn); bij het gevecht worden de sprites van de party op de achtergrond aangevraagd. -7 MB.
  Samen met de achtergronden is dat de -18 MB tussen "+ #216" en "+ voorstel" (23,4 -> 5,2 MB aan vastgehouden preload-resources).

Opstarten gaat daarmee van 51,0 (main) naar 28,9 (#216) naar 10,6 MB (+ voorstel). Alle suites zijn met het voorstel gedraaid (zie PR).
Ik heb het niet in de branch gezet omdat #216 dezelfde regels wijzigt; toepassen na het mergen van #216 kan met `git apply`.

Verdere voorstellen (RPG Forge / RPG ART, geen codewijziging in deze PR):
- BGM-oggs (2,4 tot 4,6 MB per track) opnieuw encoderen op een lagere bitrate: de bovengrens van de BGM-cache is nu 3 tracks (~11 MB).
- Heldensheets (`dennis_rug.png` e.a., 2100x210, ~1,7 MB per stuk, 10 frames) en gevechtsachtergronden (1280x432) zijn groot door de art zelf.
- `tools/geheugen/geheugen_tests.tscn` in de dispatch van `game_state.gd` en in de matrix van `.github/workflows/tests.yml`
  (`--geheugentest`); dat heb ik niet gedaan omdat `game_state.gd` door meer branches wordt aangepast en de workflows niet voor agents zijn.
  Lokaal: `tools/geheugen/run_tests.sh`.
- `.import`-bestanden voor de 206 png's zonder (reproduceerbare exports).

## Bijlage: per kaart (verse proces, `main` -> deze PR)

### 2. Per WM1-kaart, verse proces (totaal met de kaart open; baseline = opstart)

| Kaart | Texturen MB voor | na | Δ | Statisch MB voor | na | Resources voor | na |
|---|---:|---:|---:|---:|---:|---:|---:|
| archief_2_v1_entree | 53.7 | 52.1 | -1.6 | 61.3 | 61.3 | 261 | 254 |
| archief_2_v1_plaat | 53.6 | 52.0 | -1.6 | 61.2 | 61.3 | 258 | 251 |
| archief_2_v2_gang | 53.6 | 52.0 | -1.6 | 61.2 | 61.3 | 260 | 253 |
| archief_2_v2_lotte | 53.6 | 52.0 | -1.6 | 61.2 | 61.2 | 259 | 252 |
| archief_2_v3_ketting | 53.6 | 52.0 | -1.6 | 61.3 | 61.3 | 259 | 252 |
| archief_2_v3_licht | 53.6 | 52.0 | -1.6 | 61.2 | 61.3 | 258 | 251 |
| archief_2_v3_tegen | 53.6 | 52.0 | -1.6 | 61.2 | 61.3 | 258 | 251 |
| archief_2_v3_wurger | 53.6 | 52.0 | -1.6 | 61.3 | 61.3 | 260 | 253 |
| archief_2_v4_genezer | 53.6 | 52.0 | -1.6 | 61.4 | 61.4 | 260 | 253 |
| archief_2_v4_hal | 53.6 | 52.0 | -1.6 | 61.2 | 61.2 | 259 | 252 |
| archief_2_warper | 53.6 | 52.1 | -1.6 | 61.3 | 61.3 | 260 | 253 |
| archief_bibliotheek | 53.8 | 52.2 | -1.6 | 59.9 | 59.9 | 252 | 245 |
| archief_golemhal | 53.8 | 52.2 | -1.6 | 59.9 | 59.9 | 252 | 245 |
| archief_ingang | 53.9 | 52.3 | -1.6 | 59.9 | 60.0 | 252 | 245 |
| archief_puzzel | 51.8 | 51.6 | -0.2 | 61.1 | 61.2 | 251 | 252 |
| archief_test | 51.2 | 51.2 | -0.0 | 54.1 | 54.1 | 242 | 243 |
| archief_v1_gang | 53.8 | 52.2 | -1.6 | 60.1 | 60.1 | 253 | 246 |
| archief_v2_kastenzaal | 53.8 | 52.2 | -1.6 | 60.0 | 60.0 | 251 | 244 |
| archief_v2_leeszaal | 53.8 | 52.2 | -1.6 | 60.1 | 60.1 | 252 | 245 |
| archief_v2_trapzaal | 53.8 | 52.2 | -1.6 | 59.9 | 59.9 | 252 | 245 |
| archief_v3_gang | 53.8 | 52.2 | -1.6 | 59.9 | 59.9 | 250 | 243 |
| archief_v3_zuilenhal | 53.9 | 52.3 | -1.6 | 60.1 | 60.2 | 255 | 248 |
| archief_v4_voorhal | 53.8 | 52.2 | -1.6 | 59.9 | 59.9 | 251 | 244 |
| archief_v4_wachtersgang | 53.8 | 52.2 | -1.6 | 60.1 | 60.1 | 252 | 245 |
| berggrot_bouwplaats | 51.4 | 51.2 | -0.3 | 54.5 | 54.5 | 211 | 212 |
| berggrot_geheim | 51.6 | 51.4 | -0.2 | 61.3 | 61.3 | 248 | 249 |
| berggrot_grendel | 51.6 | 51.4 | -0.2 | 61.0 | 61.0 | 246 | 247 |
| berggrot_mond | 53.6 | 52.1 | -1.6 | 60.1 | 60.2 | 251 | 244 |
| berggrot_nerf | 53.6 | 52.1 | -1.6 | 60.1 | 60.2 | 251 | 244 |
| berggrot_uitmond | 53.6 | 52.0 | -1.6 | 60.1 | 60.1 | 250 | 243 |
| dorp_wilgendal | 71.2 | 63.6 | -7.6 | 73.4 | 73.5 | 313 | 314 |
| dungeon100 | 51.6 | 51.4 | -0.2 | 63.1 | 63.1 | 251 | 252 |
| esdoorn | 53.3 | 52.2 | -1.1 | 54.8 | 54.8 | 215 | 216 |
| esdoorn_herberg | 51.3 | 51.2 | -0.0 | 54.3 | 54.4 | 203 | 204 |
| esdoorn_huis_noor | 51.2 | 51.2 | -0.0 | 54.3 | 54.3 | 203 | 204 |
| huis_wilgendal | 51.3 | 51.2 | -0.0 | 54.4 | 54.4 | 202 | 203 |
| kern_demo | 51.2 | 51.2 | -0.0 | 59.9 | 59.9 | 243 | 244 |
| leven_ingang | 53.6 | 52.0 | -1.6 | 60.6 | 60.7 | 250 | 243 |
| leven_v1_plaat | 51.6 | 51.4 | -0.2 | 61.7 | 61.8 | 243 | 244 |
| leven_v3_combi | 51.6 | 51.4 | -0.2 | 61.5 | 61.5 | 245 | 246 |
| wereldkaart | 51.1 | 50.9 | -0.3 | 55.8 | 55.8 | 200 | 201 |
| wilgendal | 53.0 | 52.0 | -1.0 | 56.8 | 56.9 | 207 | 208 |
| wilgendal_binnen | 51.2 | 51.2 | -0.0 | 55.1 | 55.1 | 211 | 212 |
| woud_mistpoel | 54.3 | 52.3 | -2.0 | 59.9 | 59.9 | 254 | 247 |
| woud_open_plek | 54.4 | 52.5 | -2.0 | 59.7 | 59.7 | 256 | 249 |
| woud_pad | 54.3 | 52.3 | -2.0 | 59.9 | 59.9 | 253 | 246 |
| woud_rand | 54.4 | 52.4 | -2.0 | 59.7 | 59.7 | 255 | 248 |
| woud_sporenkring | 54.3 | 52.3 | -2.0 | 59.7 | 59.7 | 253 | 246 |
| **Gemiddelde (48 kaarten)** | 53.4 | 52.1 | -1.3 | 59.8 | 59.8 | 246 | 242 |

Tegelatlas-bronnen met `use_texture_padding` (opgevulde kopie in het geheugen), som over alle kaarten: voor 108 van 108 (atlas 13.4 MB), na 0 van 108 (atlas 0.0 MB).


