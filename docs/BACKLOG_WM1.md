# BACKLOG WM1 — triage van open punten (stand 24 okt 2026)

Stand: `main` `c55b77b` (laatste merge: PR #189). Alleen triage: geen nieuwe content, geen code, geen wijziging
aan `TODO.md`, `docs/lore/CANON.md` of een CANON-blok. Bronnen: `TODO.md` (laatste audit 14 okt 2026), `docs/PLAN.md`,
`docs/MAP_SCALE_PLAN.md`, `docs/ISSUES_DUNGEON100.md`, de `HANDOFF_*.md`-bestanden, `TODO(...)`-markers in de code,
de CI-run op `main` en suites die ik lokaal heb gedraaid.

## Hoe te lezen

**Scope WM1.** Alles wat bij de speelbare eerste wereld hoort of daarmee samenhangt: Worldmap 1 (Dennis' huis /
Wachtershuis-erf, Wilgendal, Esdoorn, Donker Woud), Archief 1, de berggrot, Archief 2 (Het Levende Archief), de World
Warper-hub met ECHO, de Diepe Grot (bereikbaar via ECHO) en de dwarsdoorsnijdende zaken die WM1 raken (audio, art,
tests/CI, docs). PvP en co-op staan erbij als aparte rij omdat ze in `TODO.md` open staan, maar ze hangen niet aan WM1.

**WM2 en WM3 staan on hold** (laatste sectie). `wacht/wm2/` is niet gelezen; de WM2-rijen komen alleen uit de koppen en
vakjes van `TODO.md` en uit `docs/`. Hetzelfde geldt voor alles wat in `TODO.md` "Niet zelf bouwen, wacht op scènes" heet.

**Status.**
- `open`: bewezen niet af (bestand ontbreekt, test faalt of staat nergens in CI, of code zegt het zelf).
- `done`: staat op `main` en is getest; het vakje in `TODO.md` is verouderd. Zie tabel B.
- `unclear`: bewijs spreekt elkaar tegen, of er is een besluit van Dennis / RPG ART / RPG Forge nodig.

**Impact** (volgorde van de tabel): `H` = blokkeert vertrouwen in tests/CI of is zichtbaar in een normale WM1-playthrough;
`M` = maakt WM1 completer of voorkomt misverstanden; `L` = polish, of hangt aan een externe levering of besluit.

**Omvang** (geen kalendertijd; technische omvang):
- `S`: één bestand of één datatabel, geen nieuwe suite.
- `M`: 2 tot 5 bestanden in één systeem, bestaande suite uitbreiden.
- `L`: meerdere systemen of kaarten, tooling en meerdere suites.
- `XL`: nieuw systeem, of grotendeels externe assets/besluiten.

## A. Open en onduidelijke WM1-punten, gesorteerd op impact

| # | Punt | Status | Bewijs (bestand / test) | Omvang | Impact |
|---|---|---|---|---|---|
| 1 | 11 suites die `game_state.gd` kent staan niet in de CI-matrix: `grotlayouttest`, `musictest`, `held24test`, `sessiefixtest`, `rekruuttest`, `balansarchief1test`, `somroomstest`, `partytest`, `savetest`, `cutscenetest`, `coophosttest`. AGENTS.md regel 9 eist alle suites in CI. Matrix toevoegen kan alleen RPG Forge (`.github/workflows/` is niet voor agents). | open | `scripts/game_state.gd` `_ready()` (dispatch) tegenover `.github/workflows/tests.yml` (matrix). Lokaal gedraaid: 10 van de 11 slagen (23 / 35 / 8 / 54 / 55 / 14 / 38 / 35 / 92 / 26 PASS), `sessiefixtest` faalt (rij 2). | S | H |
| 2 | `--sessiefixtest` faalt op 3 checks: na een cast-animatie staan er `SomCastAnim`, `SomCastCircle` en `SomCastFx` naast het 24x32-loopframe van Noor en Lotte ("na aanval/treffer/ontwijken weer alleen het 24x32-loopframe", "lotte: start = 24x32-loopframe", "lotte: tijdens aanval+treffer nooit loopsprite en pose tegelijk"). Waarschijnlijk is de test achterhaald door de cast-animaties (PR #176); de suite staat niet in CI en viel daardoor niet op. Eerst fixen, dan in de matrix (rij 1). | open | `scripts/tests/sessiefix_tests.gd`; lokaal 27 PASS / 3 FAIL, twee keer herhaald (Godot 4.7.2; CI gebruikt 4.3). | S | H |
| 3 | Balans WM1 en Diepe Grot is te makkelijk. Battlesim: wereldkaart-gevechten 100% winst, 5% HP-verlies; CANON-baasstats (Wurger, Genezer, Grot 25/50/75/99) blijven 100% winst. Draft-PR #126 (data-only power scaling) laat die CANON-bazen bewust ongemoeid en wacht op een besluit van Dennis. | open | `docs/BATTLE_BALANCE_REPORT.md` (rijen "Worldmap 1", "Deep Cave"); [PR #126](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/126) (draft); `scripts/tests/battlesim_tests.gd` (57 PASS in CI). | M | H |
| 4 | WM1-kaarten 1.4x: volgens `docs/MAP_SCALE_PLAN.md` zijn 19 van de 46 kaarten als "gedaan" gemarkeerd (Wilgendal-dorp, Esdoorn, 5 woudkamers, 11 Archief 2-kamers + `leven_ingang`); het Wachtershuis-erf (`wilgendal.tscn`) is volgens de git-log ook klaar maar staat niet in het plan. Open: Archief 1 (13 kamers), berggrot (6), puzzelkamers en interieurs (waar het plan zelf voorstelt niet of alleen de rand te schalen, wacht op Dennis), Dungeon100 (via generator). Het plan is na PR #133/#137/#145 niet bijgewerkt. | open | `docs/MAP_SCALE_PLAN.md` (tabel "Inventaris"); `tools/som/*_1p4.py` (bestaande tooling); commits "Archief 2 1.4x", "Donker Woud 1.4x", "Esdoorn 1.4x", "Proloog: Wachtershuis-erf 1.4x". | L | H |
| 5 | Namenlijst toepassen: CANON verwijst naar `namen_engels.md`, dat bestand staat niet in de repo. Zonder lijst is "overal toegepast" niet te controleren (hernoeming Dennis/Lotte/Noor naar Dax/Seren/Vesper staat wel in CANON 18 en `GameState.migrate_name`). | unclear | `find . -name 'namen_engels*'` geeft niets; `docs/lore/CANON.md` ("Alle spelersgerichte tekst gebruikt de Engelse namen uit de naamlijst"); `TODO.md` lopend punt. | M | M |
| 6 | World Warper-geluid: geen clips voor Hanger-activatie, ECHO-stem en hub-hum. Het manifest heeft alleen `ww_ambient` (hergebruikt `bgm_diepe_grot.ogg`); `ww_hum`, `ww_warp` en `ww_sapientia_glitch` staan niet in het manifest, dus die cues zijn stil. | open | `world_warper/audio/PLACEHOLDERS.md`, `world_warper/audio/ambience.gd`, `assets/audio/audio_manifest.json`. | M | M |
| 7 | BGM in het manifest zonder bestand (11 van 24). Voor WM1 relevant: `rustplek`, `overwinning`, `game_over`, `eindbaas_fase1`, `eindbaas_fase2`, `sapientia_thema`, `aftiteling`. De vier WM2/WM3-tracks (`industriestad`, `zwevende_tempel`, `ondergronds_lab`, `sterrenobservatorium`) zijn on hold. | open | Script-check van `assets/audio/audio_manifest.json` tegen `assets/audio/bgm/` (12 ogg-bestanden aanwezig). Code blijft werken zonder bestand (AudioManager). | XL (extern audio) | M |
| 8 | Alle 99 sfx uit het manifest en de acteur-sfx (helden en monsters) zijn synthetische placeholders. Echte geluiden vervangen ze bestand-voor-bestand. | open | `tools/placeholders_algemene_sfx.txt` (167 regels), `tools/placeholders_sfx.txt` (126 regels), `assets/audio/actor_sfx.json`; `--actorsfxtest` (CI). | XL (extern audio) | M |
| 9 | ECHO's definitieve zinnen en de teksten van de World Warper-scènes (eerste binnenkomst, Sapientia-dreiging) zijn door de agent geformuleerd; Dennis bepaalt de definitieve tekst. | unclear | `world_warper/guide/dialoog.gd` (`TODO(design)` bij regel 30), `docs/PLAN.md` ("Top-beslissingen Dennis"), `world_warper/cutscene/dreiging.gd`. | S | M |
| 10 | Verouderde documentatie die tot verkeerde conclusies leidt: `TODO.md` is voor het laatst gecontroleerd op 14 okt (zie tabel B, 10 verouderde vakjes); `AGENTS.md` zegt "nog géén audio" en geeft oude PASS-aantallen (bv. `--checkpointtest` 65, nu 102; `--dungeon100regelstest` 72, nu 113; `--dungeon100blauwtest` 38, nu 69); `assets/audio/bgm/README.md` noemt 6 van de 12 bestanden; `docs/ISSUES_DUNGEON100.md` staat op 10 okt (tests.yml, web-build, mimic-art, bossen-art, bgm zijn inmiddels opgelost); `tools/placeholders_v17.txt` heeft Wilgendal-regels zonder KLAAR-markering terwijl de bestanden in `tools/handwerk.txt` staan. Aanpassen raakt `TODO.md`/`AGENTS.md` (CANON-blokken) en is dus voor RPG Forge of Dennis. | open | Zie de genoemde bestanden; `gh run list --workflow tests.yml` (groen op `main`). | S | M |
| 11 | RUN-knop "werkt in alle kamer-types behalve gevecht" (twee open vakjes in een CANON-blok). De feature staat in `scripts/player.gd` en `scripts/touch_controls.gd`, maar geen enkele suite test RUN in een Rustkamer, Koopman-kamer of dorp. | unclear | `scripts/player.gd` (`run_on()`, `toggle_run()`); `rg` in `scripts/tests/` vindt geen RUN-test. | S | M |
| 12 | Diepe Grot-art die nog uit code of tint komt: rustpunt (`Dungeon100Rustpunt.TINT` op `save_book.png`), Blauwe Kist (`Dungeon100Blue.BLUE_TINT` op de gewone kist) en de uitgang-warpers (getint boek). Nodig van RPG ART: rustpunt 64x16 (4x16x16), eigen blauwe kist (zelfde maat als `kist.png`). | open | `scripts/dungeon/dungeon100_rustpunt.gd`, `scripts/dungeon/dungeon_chest.gd` (regel 73), `scripts/dungeon/dungeon_exit_warper.gd`, `docs/ISSUES_DUNGEON100.md`. | S (code) + extern art | L |
| 13 | Puzzle Room in de Diepe Grot: de CANON-spec noemt Ketting, Rotatie en Licht; de code gebruikt de kleine vaste puzzels uit Archief 1/2 (besluit Dennis 14 okt, ook in CANON). Het vakje "Puzzle Room: welke puzzels?" blijft daardoor open. Besluit van Dennis nodig of de oorspronkelijke drie typen nog komen. | unclear | `scripts/data/grot_puzzels.gd`, `scripts/dungeon/dungeon100_puzzel.gd`; `--dungeon100integratietest`. | M tot L (alleen als de drie typen komen) | L |
| 14 | Stijlbijbel: de branch `origin/docs/stijlbijbel` (13 okt, 4 bestanden, 92 regels, inclusief referentiesheets) is nooit gemerged en heeft geen PR. `docs/ARTSTYLE.md` (v0.17) is alleen een pixel-artgids. | open | `git diff --stat origin/main...origin/docs/stijlbijbel`; `docs/ARTSTYLE.md`. | S (PR openen en reviewen) | L |
| 15 | Wortelkoning heeft een genoteerd hartrect maar geen kern-mechaniek (geen `wortelkoning` in `kern_data.gd`). Alleen een open punt uit de handoff; niet in `TODO.md`. | unclear | `scripts/data/game_data.gd` (regel 275 commentaar), `scripts/data/kern_data.gd`, `docs/HANDOFF_WOUD.md` ("Open punten"). | M | L |
| 16 | Kleine ontwerpbesluiten die als `TODO(design)` in de code staan en op Dennis wachten: Werkplaats-recepten (aantallen zijn een voorstel, alleen drankjes), Exchange-voorraad en -prijzen, Archief 2 zonder kern-vlag, Codex-volger in het veld, gesloten-deur-melding in de hub. | unclear | `scripts/data/werkplaats_recepten.gd` (regel 9), `scripts/data/shop_data.gd` (regel 52), `world_warper/kamers/kamers.gd` (regel 7), `scripts/data/archief2.gd` (regel 140), `world_warper/maps/locked_exit.gd`. | S per stuk | L |
| 17 | Loop-animaties voor de party en Codex-monsters in de hub (PLAN art-item 52): in `tools/handwerk.txt` staan alleen `party_placeholder*.png`; de naam wijst op nog niet definitieve art. | unclear | `tools/handwerk.txt` (regels 393 tot 398), `world_warper/art/party.png`. | S (extern art) | L |
| 18 | Resterende kleine punten uit de HANDOFF-bestanden: stun-betekenis op de wereldkaart (kernkracht, besluit nodig), Codex-besluiten (bron Leeg Boek, level bij vangen), puzzelstand midden in een puzzel zit niet in de save, `onderrand_doorgang`-tegel voor `archief_test`. Niet in `TODO.md`; niet individueel geverifieerd. | unclear | `HANDOFF_KERNKRACHT.md` §9, `HANDOFF_CODEX.md` §11, `docs/HANDOFF_PUZZELS.md` ("Niet getest / TODO"). | S per stuk | L |
| 19 | PvP: relay kiezen (GD-Sync / NodeTunnel / eigen VPS), online lobby met connect-code buiten LAN, UI-polish. Niet WM1-gebonden. Beslissing van Dennis blokkeert de rest. | open | `pvp/scripts/net/lan_transport.gd` (`TODO(design)`), `pvp/scripts/pvp_session.gd` (regel 215), `--pvptest` (CI). | XL | L |
| 20 | Co-op (Fase B, `docs/fase_b/ARCHITECTUUR.md`): lobby, sync en Android-host staan op `main` (PR #195, #196, #198, #199). Stappen 8 (Android-details) en 9 (Fase C: AI op lege stoelen, relay) zijn open; het staat niet in `TODO.md`. Of stap 5 tot 7 volledig af zijn is niet gecontroleerd. | unclear | `docs/fase_b/ARCHITECTUUR.md` (roadmap, regels 485 tot 497); `--nettest`, `--netsynctest` (CI), `--coophosttest` (35 PASS lokaal, niet in CI). | XL | L |

## B. Open in `TODO.md`, maar al af op `main` (vakje is verouderd)

Deze punten zijn geen werk meer; ze hoeven alleen afgevinkt te worden (door RPG Forge of Dennis, omdat `TODO.md`
CANON-blokken bevat).

| # | Punt in `TODO.md` | Status | Bewijs | Omvang | Impact |
|---|---|---|---|---|---|
| B1 | De Werkplaats: crafting bouwen ("alleen een tafel") | done | `scripts/data/werkplaats_recepten.gd` (3 recepten), `scripts/ui/werkplaats_scherm.gd`, `world_warper/kamers/werkplaats.tscn`; `--warperkamertest` 259 PASS lokaal (CI); PR #114 | S (afvinken) | M |
| B2 | De Handelskamer: endgame-winkel ("The shop is still closed") | done | `ShopData.SHOPS["handelskamer"]` (naam "Exchange"), `Kamers.handel_open()`, test "Handelskamer heeft een winkel"; `HANDEL_DICHT` is alleen nog de terugval | S (afvinken) | M |
| B3 | ECHO: questvoortgang en dialoog per act | done (zinnen: zie A9) | `scripts/data/quest_data.gd`, `data/quests.json`, `world_warper/data/echo_questlog.gd`, `scripts/ui/questlog_screen.gd`; `--questtest` 63 PASS en `--echotest` 12 PASS lokaal (CI); PR #111, #182 | S (afvinken) | M |
| B4 | Webversie bijwerken (Pages-branch op oude `main`) | done | `.github/workflows/build-web.yml` draait op elke push naar `main`; laatste runs op 24 okt 2026 geslaagd; `export/web/README.md` | S (afvinken) | M |
| B5 | Muziek voor Archief 2 (kas) | done | `assets/audio/bgm/bgm_levend_archief.ogg`, `bgm_baas_archief2.ogg`, manifest-sleutels `levend_archief` en `baas_archief2`; `--musictest` 23 PASS lokaal, `--muziektest` in CI | S (afvinken) | L |
| B6 | Kael v4 ("alleen in de lore") | done | `scripts/data/game_data.gd` (held `kael`, `field_sprite` `kael_wm1_slim.png`), `assets/sprites/battle/kael.png`, `assets/audio/sfx/helden/kael/`; PR #155, #159, #188; `--partytest` 92 PASS, `--held24test` 8 PASS lokaal | S (afvinken) | M |
| B7 | World Warper: "zwevende gebouw op de wereldkaart is er nog niet" (CANON-tekst, niet aangepast) | done | `scenes/maps/wereldkaart.tscn` (node `WorldWarperFlyover`), `world_warper/art/flyover.gd`, `world_warper/art/warper_brain.gd` | S (afvinken) | L |
| B8 | RPG ART: alle items van de art-inventaris (`docs/PLAN.md`, 54 items) | done, met uitzondering van A17 | Items 1 tot 49 en 53 staan in `tools/handwerk.txt`, behalve 5 en 8 (die bestanden bestaan niet meer; de kas gebruikt `kas_tiles_v8c.png` en `kas_bibliotheek_v8.png`, beide in handwerk); `hanger_gloed.png`, `knop_wm1.png` en de zes `world_warper_*`-kleurvarianten staan er ook in. `tools/placeholders_v17.txt` heeft 58 KLAAR-regels | S (afvinken) | L |
| B9 | Wilgendal herontwerp ("in uitvoering") | done, tenzij Dennis meer wil | `--wilgendaltest` 223 PASS lokaal (CI); PR #132, #163 (plein), 1.4x-schaal, winkelart in `tools/handwerk.txt` | S (afvinken) | L |
| B10 | "Rematch"-knop moet Nederlands worden (PvP-resultaatscherm) | obsolete | Sinds 13 okt is alle spelertekst Engels (AGENTS.md regel 3); `pvp/scripts/ui/result_panel.gd` zegt "Rematch" | S (afvinken) | L |
| B11 | Dungeon100-issues #2 tot #5 | done (zie de comments op de issues) | `--checkpointtest` 102, `--dungeon100gentest` 69, `--dungeon100schaaltest` 86, `--dungeon100regelstest` 113, `--dungeon100integratietest` 62, `--dungeon100blauwtest` 69 PASS lokaal; alle zes in de CI-matrix | S (issues sluiten door RPG Forge) | L |

## C. Top 10 open punten (uit tabel A)

1. CI-matrix mist 11 suites (A1).
2. `--sessiefixtest` faalt op 3 checks (A2).
3. Balans WM1 en Diepe Grot te makkelijk; PR #126 wacht op besluit over CANON-baasstats (A3).
4. WM1-kaarten 1.4x: ongeveer 26 van 46 nog niet geschaald (A4).
5. Namenlijst `namen_engels.md` ontbreekt (A5).
6. World Warper-geluid ontbreekt (A6).
7. 7 WM1-relevante BGM-tracks zonder bestand (A7).
8. Alle sfx zijn nog placeholders (A8).
9. ECHO-zinnen en hub-scèneteksten wachten op Dennis (A9).
10. Verouderde docs (`TODO.md`, `AGENTS.md`, bgm-README, `ISSUES_DUNGEON100.md`) (A10).

## D. On hold (WM2, WM3 en wachten op scènes of nieuwe karakters)

Niet bekeken, niet gebouwd. `wacht/wm2/` is niet gelezen. Alle punten staan in `TODO.md` of `docs/` met de markering
"Niet zelf bouwen, wacht op scènes". CANON-blokken zijn niet aangeraakt.

| Punt | Reden |
|---|---|
| Worldmap 2 (eiland, kamerlijsten, monsters, paden) | WM2, on hold |
| Worldmap 3 (eiland, kamerlijsten, monsters, paden) | WM3 (volgt op WM2), on hold |
| Archief 3 Industrie (De Architect), Archief 4 Magie (De Spiegel), Archief 5 Kosmos (De Wachter), Archief 6 Hart | WM2 en WM3, on hold |
| Dorpen Stoomwijk, Hoge Toren, Sterrenhaven | WM2 en WM3, on hold |
| Warp-systeem naar WM2 en WM3: warp-punten op elk eiland, ontgrendelen na Archief 2, WM3 na WM2, "WM2 naast WM1 open na Archief 2" | WM2 en WM3, on hold (de WM1-kant staat: hub opent na De Genezer) |
| Act-koppeling Act 2 en verder = WM2, Act 3 en verder = WM3 | WM2 en WM3, on hold |
| Onthulling Proefpersoon H-6 in Archief 4; De Spiegel koppelen aan Archief 4 | WM2, on hold; de scène staat alleen via `--spiegel` (`scenes/story/spiegel_kamer.tscn`) |
| Dungeon-warpers (begin, midden, eind) in Archief 3 tot en met 6 | WM2 en WM3, on hold (Archief 1 en 2 hebben ze) |
| Bestiarium tot endgame (monsters Archief 3 tot en met 6, WM2/WM3) | WM2 en WM3, on hold; WM1-bestiarium is er |
| BGM `industriestad`, `zwevende_tempel`, `ondergronds_lab`, `sterrenobservatorium` | WM2 en WM3, on hold |
| Kael Voss' herkomst (psytech uit WM2) en "Joint" in WM2 | WM2, on hold |
| Hub-kamer De Kern (act 6) | hangt aan WM2/WM3-verhaal, on hold |
| ECHO's twist (H-1 tot en met H-5), De Koopman (H-5) einde | wacht op scènes van Dennis |
| Grade 4-wapens en -sets, PvP-teams herzien | wacht op nieuwe karakters |

## E. Hoe dit is vastgesteld

- CI op `main`: `gh run list --workflow tests.yml` en `--workflow build-web.yml` (laatste runs groen, 24 okt 2026).
- Lokaal draaien met `.github/scripts/run_suite.sh` (Godot 4.7.2; CI gebruikt 4.3): `checkpointtest`, `dungeon100gentest`,
  `dungeon100schaaltest`, `dungeon100regelstest`, `dungeon100integratietest`, `dungeon100blauwtest`, `questtest`,
  `echotest`, `warperkamertest`, `wilgendaltest` en de 11 suites uit A1. Alles groen behalve `sessiefixtest`.
- Manifest-check: elk `bestand` in `assets/audio/audio_manifest.json` tegen `assets/audio/bgm/` en `assets/audio/sfx/`
  (bgm: 11 van 24 ontbreken; sfx: 0 van 99 ontbreken, maar allemaal placeholders).
- Art: de bestandspaden uit `docs/PLAN.md` tegen `tools/handwerk.txt` en `tools/placeholders_*.txt`.
- Niet gedaan: kaart-voor-kaart meting van de 1.4x-schaal (het plan zelf is de bron), en een scan van alle spelertekst
  op oude namen (kan pas met de naamlijst, A5).

## F. Bevindingen issues #2 tot #5 (niet gesloten)

Stand `main` `c55b77b`. Alle vier lijken af en getest; sluiten laat ik aan RPG Forge. De bevindingen zijn bedoeld als comment
op elk issue, maar de token van deze agent mag geen issue-comments plaatsen (`gh issue comment` geeft "Resource not accessible
by integration"). Daarom staan ze hier.

| Issue | Oordeel | Bewijs | Bewust anders dan in het issue |
|---|---|---|---|
| [#2](https://github.com/krelegerdennis-collab/Sapientia-RPG/issues/2) Respawn-fix afmaken | lijkt af en getest | [PR #6](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/6) gemerged. `GameState.set_checkpoint()`, `respawn_at_checkpoint()`, `has_checkpoint()`, terugval `respawn()`; checkpoint in de save (sleutel `checkpoint`, oude saves laden). `--checkpointtest` 102 PASS lokaal, in de CI-matrix, CI op `main` groen. | In de Diepe Grot is game over sinds PR #11 "dood is dungeon uit". |
| [#3](https://github.com/krelegerdennis-collab/Sapientia-RPG/issues/3) Procedurele generator | lijkt af en getest | [PR #8](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/8) gemerged. `scripts/dungeon/dungeon100_generator.gd` (seed per run en verdieping, 16x16, trap omhoog en omlaag, bereikbaarheidscontrole), `scenes/maps/dungeon100.tscn`. `--dungeon100gentest` 69 PASS lokaal, in de CI-matrix. | De ingang op de wereldkaart is weg: de Diepe Grot start alleen via ECHO (CANON, `scripts/data/echo_grot.gd`). |
| [#4](https://github.com/krelegerdennis-collab/Sapientia-RPG/issues/4) Monsterschaal en buit | lijkt af en getest, balans open | [PR #9](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/9) gemerged. `scripts/data/dungeon100_scaling.gd` (`hp_mult()`, `monster_stats()`, `chest_loot()`, `BOSSES`, `GEAR`), `dungeon100_reward.gd`, `dungeon100_blue.gd`. `--dungeon100schaaltest` 86 PASS en `--dungeon100blauwtest` 69 PASS lokaal, in de CI-matrix. | CANON zet bazen op 25, 50, 75 en 99 en geeft verdieping 100 geen baas; de bazen op de 10e verdiepingen bestaan daarnaast. Balans: zie A3. |
| [#5](https://github.com/krelegerdennis-collab/Sapientia-RPG/issues/5) Regels, checkpoints en HUD | lijkt af en getest | [PR #7](https://github.com/krelegerdennis-collab/Sapientia-RPG/pull/7) gemerged. `Dungeon100Rules.is_rest_floor()`, `scripts/dungeon/dungeon100_rustpunt.gd`, HUD `scripts/ui/dungeon100_hud.gd` (`hud_text()`, "X/100"), checkpoint en best in de save. `--dungeon100regelstest` 113 PASS en `--dungeon100integratietest` 62 PASS lokaal, in de CI-matrix. | Game over is "dood is dungeon uit" (PR #11, `DUNGEON100_DEFEAT_TEXT`), niet een respawn op het rustpunt. Rustpunt-art: zie A12. |
