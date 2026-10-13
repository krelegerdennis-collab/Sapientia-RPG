# PLAN — SAPIENTIA v0.20 → volgende fases

Bron: `TODO.md` (main, 13 okt 2026). Spelteksten Engels; dit plan Nederlands.

## Rollen
| Wie | Doet |
|---|---|
| RPG ART | enige maker van echte pixel-art. Levert losse PNG's + `HANDOFF` (maat, frames) in `/workspace/art_<naam>/out`. |
| RPG Forge | main-dev: art integreren, PR's reviewen/mergen, 27 testsuites lokaal, webbuild handmatig (`cursor/web-build-29ec`). Geen APK's, geen GitHub Actions-minuten. |
| RPG CODE | kleinere gameplay-taken in eigen clone, levert `HANDOFF`. |
| Cursor cloud-agents | grote systemen via branch `cursor/<taak>` + PR. **Geen definitieve art**: alleen placeholders, gemarkeerd (`PLACEHOLDER` + regel in `tools/placeholders_v17.txt`). |
| Dennis | verhaal (ECHO-twist, H-1..H-5, koopman), canon-vragen. |

## Art-inventaris (open)
Status: **PH** = placeholder staat in repo (zelfde maat); **—** = nog geen bestand.

| # | Bestand | Maat / frames | Status |
|---|---|---|---|
| 1 | assets/sprites/enemies/mimic.png | 80×64 | PH |
| 2 | assets/map_monsters/mimic.png | 32×64, 2×4 van 16×16 | PH |
| 3 | assets/sprites/dungeon100_warper.png | 64×16, 4 van 16×16 | — (code tint save_book.png) |
| 4 | assets/tiles/dungeon/kas_tiles.png | 256×80 | PH |
| 5 | assets/tiles/dungeon/kas_bibliotheek.png | 256×64 | PH |
| 6 | assets/puzzle/groei_plaat.png | 48×16, 3 van 16×16 | PH |
| 7 | assets/sprites/buiten/kas_ingang.png | 16×16 | PH |
| 8 | assets/tiles/dungeon/archief2_kas_tiles.png | 256×80 | PH |
| 9 | assets/sprites/archief2/lotte_veld.png | 48×96 (3×4 van 16×24) | ✅ RPG ART batch 3 (v0.21) |
| 10 | assets/sprites/archief2/lotte_glitch.png | 64×80 | PH |
| 11 | assets/sprites/archief2/genezer.png | 64×80 | PH |
| 12 | assets/sprites/archief2/wurger.png | 80×96 | PH |
| 13-15 | assets/sprites/archief2/plaat_{zaad,scheut,volgroeid}.png | 16×16 elk | PH |
| 16 | assets/ui/icons/levenskern.png | 16×16 | PH |
| 17 | assets/sprites/archief2/world_warper.png | 128×64 | PH |
| 18 | assets/sprites/archief2/echo.png | 32×48 | PH |
| 19 | assets/sprites/archief2/sapientia_glitch.png | 48×48 | PH |
| 20 | assets/map_monsters/lotte_glitch.png | 32×64, 2×4 | PH |
| 21 | assets/map_monsters/wurger.png | 32×64, 2×4 | PH |
| 22 | assets/map_monsters/genezer.png | 32×64, 2×4 | PH |
| 23 | assets/sprites/enemies/woudgeest.png | maat open (vgl. 90×94) | — (gebruikt mosslijm.png) |
| 24 | assets/sprites/enemies/woudgeest_rug.png | = vooraanzicht | — |
| 25 | assets/map_monsters/woudgeest.png | 32×64, 2×4 (alleen als hij gaat lopen) | — |
| 26 | world_warper/art/echo_placeholder.png | 48×96, 3×4 van 16×24 | PH |
| 27 | world_warper/art/party_placeholder.png | 48×96, 3×4 van 16×24 | PH |
| 28 | world_warper/art/pc_placeholder.png | 32×32 (main PC + terminal) | PH |
| 29 | world_warper/art/warp_platform.png | 32×16 | PH |
| 30 | world_warper/art/tafel_placeholder.png | 32×16 | PH |
| 31 | world_warper/art/toonbank_placeholder.png | 48×16 | PH |
| 32 | world_warper/art/bord_kamers.png | 32×16 | PH |
| 33 | world_warper/art/bord_hal.png | 32×16 | PH |
| 34 | world_warper/art/bord_warp.png | 48×16 | PH |
| 35 | world_warper/art/tiles_placeholder.png | 128×32, tegels 16×16 | PH |
| 36 | assets/bg/spiegel_kamer.png | 384×216 | PH |
| 37 | assets/bg/spiegel_kamer_gebroken.png | 384×216 | PH |
| 38 | assets/sprites/buiten/molen_wieken.png | 192×64, 4 van 48×64 | — |
| 39 | assets/tiles/dungeon/berggrot_tiles.png | 256×80 | PH |
| 40 | assets/tiles/dungeon/berggrot_bibliotheek.png | 256×64 | PH |
| 41-49 | steenluis / druipslak / adermot: enemy + _rug + map | 90×90, 90×90, 32×64 (2×4) | PH (alle 9) |
| 50 | Hanger-oplichteffect (paarse gloed `b07ae8`) | maat open (voorstel 16×16, 4 frames) | — (code kleurt) |
| 51 | UI wereldkaart-view WM1/WM2/WM3/dorp (knoppen) | maat open | PH (vlakke knoppen) |
| 52 | Loop-animaties party + Codex-monsters in hub | per figuur 48×96, 3×4 van 16×24 | PH (kleurvlakken) |
| 53 | 5 vijanden Archief 2: rankje, sporekop, doornige_loper, bloeiende_schrik, wortelgeest (Codex-vangbaar: sporekop, rankje, wortelgeest) | per vijand 90×90 voor + 90×90 rug + map 32×64 (2×4 frames van 16×16) | — |
| 54 | 6 kleurvarianten World Warper (grijs/groen/oranje/roze/blauw/rood + paars) | maat als warper-basis | — |

**Totaal: 54 open art-items** (49 met vaste bestandsnaam; 5 nog zonder bestand/maat). Niet aanraken: bestanden in `tools/handwerk.txt`.

## Fase 1 — Act 1 / Worldmap 1 polish
- **RPG ART batch 1** (volgorde): steenluis (3 files), druipslak (3), adermot (3) als één set; berggrot_tiles 256×80; berggrot_bibliotheek 256×64; molen_wieken 192×64; mimic 80×64 + map 32×64.
- **Cursor-agent:** molen-animatie inbouwen met placeholder-sheet (4 frames 48×64, gemarkeerd).
- **RPG CODE:** RUN-knop boven CORE (toggle, 2 tegels/move, overal behalve gevecht); `"Rematch"`-tekst controleren (spel is Engels — zie beslissing).
- **Forge:** art integreren, 27 suites, webbuild.
- **Dennis:** maat/ontwerp woudgeest; wordt hij map-monster? Moet "Rematch" blijven (spel is nu Engels)?

## Fase 2 — Archief 2 (Levende Archief)
- **RPG ART batch 2:** kas_tiles 256×80; archief2_kas_tiles 256×80; kas_bibliotheek 256×64; groei_plaat 48×16 (3 frames) + plaat_zaad/scheut/volgroeid 16×16; kas_ingang 16×16; levenskern 16×16.
- **RPG ART batch 3:** lotte_veld 48×96; lotte_glitch 64×80 + map 32×64; wurger 80×96 + map; genezer 64×80 + map.
- **RPG ART batch 4:** 5 vijanden A2 (rankje, sporekop, doornige_loper, bloeiende_schrik, wortelgeest; 90×90 + rug + map 32×64); woudgeest (+rug/map).
- **Cursor-agent:** Codex-monsters A2 in `codex_data.gd` + placeholders; groene gloed/sfeerlicht kas (shader/CanvasModulate).
- **RPG CODE:** nieuwe vijanden in encountertabellen; bgm-hook kas.
- **Dennis:** lijst plant-vijanden + Codex-monsters (namen, element, lore); muziek-richting.

## Fase 3 — World Warper
- **RPG ART batch 5:** world_warper exterieur 128×64; tiles_placeholder 128×32; echo.png 32×48 + echo_placeholder 48×96; pc_placeholder 32×32; warp_platform 32×16; sapientia_glitch 48×48; Hanger-gloed.
- **RPG ART batch 5b:** 6 kleurvarianten warper per Archief.
- **RPG ART batch 6:** borden (bord_kamers/bord_hal 32×16, bord_warp 48×16), tafel 32×16, toonbank 48×16, party_placeholder 48×96, WM-view UI-knoppen.
- **Cursor-agents:** (a) cutscene na De Genezer: warper verschijnt in de lucht + zwevend gebouw; (b) Hanger-slot + systemen online per Hanger-signaal; (c) Sapientia-dreigingsscène (hologram/glitch, party-reactie); (d) ECHO-dialoog per act + questvoortgang.
- **RPG CODE:** party live verversen in hal (refresh); Hanger-geluid + ECHO-stem (sfx-hooks).
- **Dennis:** definitieve zinnen eerste binnenkomst/dreiging; hoeveel van ECHO-twist laten doorschemeren; universele warper-stijl of per Archief.

## Fase 4 — Diepe Grot
- **RPG ART batch 7:** dungeon100_warper 64×16 (4 frames); kamer-specifieke tegels (val, rust, koopman) zodra code ze vraagt.
- **Cursor-agents:** (a) kamer-type generator met kansen, vaste boss/100-kamers, balansregels, save/load; (b) push + chain-push bij stun (+ koppeling puzzel/trap).
- **RPG CODE:** loot table (minder consumables), blue-chest kans per bracket.
- **Dennis:** loot-ratio, blue-chest kansen, vallen zichtbaar/verborgen, puzzels + hint-systeem, Empty Room-lore, **koopman: welke H, verhaal, einde H-5**.

## Fase 5 — Bestiarium tot endgame
- **RPG ART:** endgame-bazen indien nog placeholder; loop-animaties Codex-monsters in hub.
- **Cursor-agent:** bestiarium-UI uitbreiden tot endgame (entries/stats uit monsterdata; Kustos-naam blijft "The Knowledge Beast").
- **Dennis:** lore-zinnen nieuwe monsters.

## Fase 6 — PvP + De Spiegel
- **RPG ART:** spiegel_kamer + spiegel_kamer_gebroken 384×216.
- **Cursor-agent:** relay + online lobby (fase 2), polish (fase 5). Spiegel-koppeling aan Archief 4 pas na scène.
- **Dennis:** relay-keuze (GD-Sync / NodeTunnel / VPS).

## Parallel (alleen code, geen art nodig)
- RUN-feature; push/chain-push; Diepe Grot-generator + balansregels; loot/blue-chest tuning (met placeholder-cijfers achter constants).
- Party live-refresh in hub; ECHO-flags per act; questlog-basis.
- PvP disconnect/reconnect-polish; relay-abstractie (interface, provider later).
- Placeholder-register bijwerken (`dungeon100_warper`, woudgeest, molen ontbreken in `placeholders_v17.txt`).
- Webbuild-script lokaal (Godot export) zodat Forge zonder Actions publiceert.

## Top-beslissingen Dennis
Beslist 13 okt 2026 (CANON 12-14): Koopman = H-5; Archief 2-roster; warper-stijl universeel met kleuraccent.
Nog open: cutscene-teksten World Warper (na De Genezer, eerste binnenkomst Hal, Sapientia-dreiging): tekst volgt van Dennis. EN-namen Archief 2-vijanden bevestigen.
