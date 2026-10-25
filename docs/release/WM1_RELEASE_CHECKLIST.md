# WM1 Release-checklist (acht fases)

Roadmap naar een speelbare, ondertekende release van **Worldmap 1** (WM1). Fase 1 is `docs/release/WM1_CONTENT_LOCK.md`
(inventaris, ship/cut en freeze-regels); dit bestand is de werklijst voor alle acht fases. WM2 en WM3 staan on hold:
`wacht/wm2/` wordt niet gelezen, gebouwd of getest en zit niet in de export (`wacht/.gdignore`).

Basis: `main` op `61986e9`, 24 okt 2026. Cijfers uit `docs/BATTLE_BALANCE_REPORT.md` en `docs/BACKLOG_WM1.md` zijn
van die stand; meet opnieuw op de freeze-commit.

## Overzicht

| Fase | Naam | Eigenaar | Gate (klaar als) |
|---:|---|---|---|
| 1 | Freeze | Dennis, RPG Forge | lock gemerged, alle BESLIS-punten uit de lock beantwoord, CI groen op de freeze-commit |
| 2 | Art op palet | RPG ART, Dennis | alle WM1-assets binnen het masterpalet of met getekende uitzondering, geen placeholder in de route |
| 3 | Stabiliteit | RPG Forge, Cursor-agents | 0 crashes en 0 softlocks in de testroutes, alle suites groen op 4.3, export schoon |
| 4 | S25-performance | RPG Forge, Dennis | meetrapport op de S25 met alle doelen gehaald of bewust geaccepteerd |
| 5 | Balans (headless sim) | Cursor-agents, Dennis | geen onbedoelde HARD/TRIVIAL in WM1, bazen in het afgesproken venster |
| 6 | UX-polish | Cursor-agents, Dennis | tutorials, menu's, Engelse tekst, touch en audio afgevinkt |
| 7 | Playtest Dennis + fixronde | Dennis, Cursor-agents | 0 open P0/P1, Dennis geeft akkoord voor een release candidate |
| 8 | Release candidate | RPG Forge, Dennis | ondertekende APK, versienummer, changelog, groene CI, Dennis zegt go |

Alle fases gelden onder de freeze (lock sectie 4): alleen bugfix, polish, cut en goedgekeurde vervanging.
Een fase mag pas dicht als de gate gehaald is; een fout in een eerdere fase heropent die fase.

## Rollen en grenzen

- **Dennis:** keuzes, verhaal, tekst, playtest, laatste akkoord.
- **RPG Forge:** `main`, merge, CI-workflows, APK, versienummers, signing, changelog.
- **RPG ART:** alle definitieve pixel-art en alles in `tools/handwerk.txt`.
- **Cursor-agents:** losse taken per issue (label `cursor-agent`), één taak per branch `cursor/<korte-taak>`, kleine
  PR naar `main`. Geen art, geen versienummers, geen workflows, geen merge, geen secrets, geen APK/AAB/`.uid` in git.

---

## Fase 1: Freeze

**Doel:** vastleggen wat WM1 is en alles daarbuiten dichtzetten.

- [ ] Dennis en RPG Forge reviewen `docs/release/WM1_CONTENT_LOCK.md` en mergen de PR (de merge is het begin van de freeze).
- [ ] Dennis beantwoordt de BESLIS-punten uit lock sectie 3: H3 (hubkamers Training Hall tot Core), H11 (PvP en Co-op
  op het titelscherm), H13 (Koopman-fases) en keurt de overige SHIP/CUT-aanbevelingen goed of past ze aan.
- [ ] RPG Forge maakt de labels `wm1-bugfix`, `wm1-polish`, `wm1-cut`, `wm1-vervanging`, `wm1-lock` en vraagt ze
  bij elke PR (`.github/pull_request_template.md` uitbreiden mag alleen RPG Forge).
- [ ] RPG Forge zet de CI-matrix gelijk met `scripts/game_state.gd`: `sessiefixtest` ontbreekt nog (lokaal 30 PASS,
  0 FAIL op Godot 4.7.2). Agents wijzigen `.github/workflows/` niet.
- [ ] Baseline vastleggen: PASS-aantallen per suite uit de CI-samenvatting van de freeze-commit in een issue of in
  dit bestand (de tabel in `AGENTS.md` is verouderd).
- [ ] Lock-cijfers (lock sectie 0) nog eens tellen op de freeze-commit en zo nodig corrigeren met een `wm1-lock`-PR.
- [ ] Optioneel: RPG Forge tagt de freeze-commit (bijvoorbeeld `wm1-freeze`). Een tag is geen versienummer.

**Gate:** lock gemerged, elk H-punt heeft SHIP, CUT of BESLIS-uitkomst, CI groen op `main`.

**Niet in deze fase:** nieuwe content, versienummers, workflows (agents).

---

## Fase 2: Art op palet

**Doel:** alle art die WM1 laat zien staat in het masterpalet, zonder placeholder in de speelroute.

Achtergrond: batch 1 (PR #203, 24 okt 2026) bracht 13 bestanden naar het masterpalet, goedgekeurd door Dennis. Het
masterpalet-bestand zelf staat niet in de repo (`docs/palette.png` is de paletkaart van `docs/ARTSTYLE.md`).

- [ ] Dennis of RPG ART legt het masterpalet vast als `.gpl` of `.png` (pad in dit bestand noteren). Zonder dat
  bestand is "op palet" niet meetbaar.
- [ ] Meet alle PNG's (alleen lezen, schrijft nooit een asset):
  `python3 tools/art_audit/meet.py --palet <masterpalet> --assets assets --uit art_meting.csv`
  (kolommen: `buiten_palet`, `unieke_kleuren`, `alpha_alleen_0_255`, `semi_transparant`, `deelbaar_door_16`).
  Meet ook `art/` en `world_warper/art/` (aparte run met `--assets`). `art_meting.csv` is een werkbestand, niet committen.
- [ ] Filter de CSV op wat WM1 laat zien: alles in de lock-inventaris (kaarten, NPC's, vijanden, items, cutscenes,
  UI, hub). Bestanden uit WM2/WM3-context vallen af.
- [ ] RPG ART levert per batch (zoals batch 1): dezelfde bestandsnaam en maat, met een regel in `tools/handwerk.txt`
  en akkoord van Dennis. Cursor-agents tekenen en bewerken geen art.
- [ ] Open placeholders in de route wegwerken of bewust laten staan (lock H10): Action-gevecht (slagboog, meters,
  ringmenu), Diepe Grot-rustpunt, Blauwe Kist en uitgang-warpers.
  Bijwerken van `tools/placeholders_v17.txt` (regels zonder KLAAR-markering) is werk voor RPG Forge of RPG ART.
- [ ] Ontbrekende art melden met naam en maat onder "Nodig van RPG ART" in de PR.
- [ ] Na elke batch: `.github/scripts/run_suite.sh autotest`, `menutest`, `actorsfxtest` en de suite van het gebied
  (`wilgendaltest`, `woudtest`, `berggrottest`, `archief2test`, `warperkamertest`).
- [ ] Vergelijk screenshots (`--shots=<map>`) voor en na bij kaarten en gevechtsachtergronden.

**Gate:** `buiten_palet` is 0 voor de WM1-set, of er is een door Dennis getekende uitzonderingenlijst; geen
magenta-placeholder zichtbaar in een normale doorloop.

**Niet in deze fase:** nieuwe sprites, nieuwe tilesets, andere maten.

---

## Fase 3: Stabiliteit

**Doel:** geen crash, geen softlock, geen dataverlies, een schone export.

CI en suites
- [ ] Eén verse import zonder fouten: `godot --headless --path . --import` (Godot 4.3-stable, zoals CI).
- [ ] Alle suites uit `.github/workflows/tests.yml` groen op de freeze-commit, plus job `warper-runner`
  (`world_warper/tests/run.gd`), job `algemene-sfx` en `sessiefixtest` (lokaal:
  `GODOT=/pad/naar/godot .github/scripts/run_suite.sh <suite>`; exit 0 en `RESULT OK`).
- [ ] Geen `SCRIPT ERROR` in de logs (`run_suite.sh` faalt daar al op). Lokale runs op 4.7.2 kunnen afwijken van
  CI op 4.3: CI is leidend.

Speelroutes (handmatig of met een nieuwe regressietest per gevonden bug)
- [ ] Golden path van het begin tot de hub (lock sectie 1), minstens één keer per route: route A (kas) en route B (berggrot).
- [ ] Terugweg in Archief 2 na route B (lock H14: `archief_2_v2_gang` wijst terug naar `leven_v1_plaat`).
- [ ] Archief 2 zonder Vesper in de groep (lock H17): afmaken of netjes dicht.
- [ ] Golem Hall: uitgang op slot tot de Inktwurm in de Codex staat; Codex vol; Inktwurm al verslagen; zonder Blank Book.
- [ ] Zingend Graan: aannemen, weigeren, zaad vinden, terugbrengen; zaad in Clearing alleen tijdens de opdracht.
- [ ] Game over bij elke baas (Golem, Root King, Strangler, Mender): respawn in de kamer ervoor, geen goudverlies.
- [ ] Save en load bij elk type boek (save, HP, MP), autosave, oude saves laden (`savetest`), nieuw spel na een oude save.
- [ ] Hub: unlock na De Genezer, Rest Room (genezen, party wisselen, opslaan), rekruten (Kael Voss, Orion, volle groep),
  warp-ring (World 1 open, World 2 en 3 "Locked"), ECHO's Chamber, start en einde van een Diepe Grot-run.
- [ ] Diepe Grot: eerste 10 verdiepingen, een rustverdieping, warper op 1 en 25, dood = run voorbij, Blauwe Kist,
  Mimic, Koopman-bezoek 1 en 4.
- [ ] Classic en Action gevecht in elke kerker-soort; wisselen midden in een kamer.

Export en hygiëne
- [ ] H1 en H2 (testkamers, dichte hub-nissen) niet bereikbaar in een release-export; F3/F4-debugtoetsen doen niets
  (`OS.is_debug_build()` in `scripts/map.gd`).
- [ ] `wacht/` zit niet in de export (`wacht/.gdignore`); `export_presets.cfg` sluit `tools/*`, `docs/*`,
  `scripts/tests/*` en debugscripts uit. Aanpassen aan dat bestand doet alleen RPG Forge.
- [ ] Repo-hygiëne: `git ls-files | rg -i "\.(apk|aab|jks|keystore|uid)$|(^|/)\.env$"` geeft niets.
- [ ] Web-build (`build-web`) blijft groen op `main` (bewijs dat de export zonder editor werkt).

**Gate:** alle suites groen op 4.3, de routes hierboven zonder crash of softlock, bevindingen als issue met label
`bug` en een regressietest.

**Niet in deze fase:** refactors, nieuwe systemen, het savebestand-formaat wijzigen (behalve bugfix met migratie).

---

## Fase 4: S25-performance

**Doel:** soepel en koel op een Galaxy S25 (arm64, `gl_compatibility`, 384x216, `run/max_fps=60`).

Meetopstelling (RPG Forge of Dennis, op het echte toestel; geen emulator)
- [ ] Release-APK (niet debug) en een tweede run met debug voor logs. Telefoon op 100% helderheid, vliegtuigmodus uit
  alleen als Co-op getest wordt, batterij boven 50%.
- [ ] Per scène minstens 60 seconden lopen of vechten en noteren: gemiddelde fps, 1%-low fps, langste frame,
  RAM-piek en laadtijd van de kaart. Hulpmiddelen: `adb shell dumpsys gfxinfo com.dennis.rpgprototype`,
  `adb shell dumpsys meminfo com.dennis.rpgprototype`, `adb logcat -s godot`.
- [ ] Meetscènes: wereldkaart, Willowdale (90x56 tegels met molen, beek en veel props), Mapleton, elk Donker Woud-type
  (mist en overlay), Archief 1 (glitch-effect), berggrot, Archief 2, hub-hal, Diepe Grot (rustverdieping en een
  drukke verdieping), Classic- en Action-gevecht, de twee video's (`assets/video/*.ogv`, ca. 30 MB), menu's en
  Scenes & Music.
- [ ] 30 minuten achter elkaar spelen: temperatuur, throttling, batterijverbruik per uur.
- [ ] Opstarttijd (koude start tot titelscherm), laadtijd bij Continue, en grootte van de APK (assets 85 MB, waarvan
  audio 48 MB en video 30 MB).
- [ ] Bij Co-op of PvP als die meeleveren (lock H11): idle-verbruik van netwerk en discovery.

Voorgestelde doelen (Dennis en RPG Forge bevestigen)
- Gemiddeld 58 fps of meer in kaarten, 1%-low 45 fps of meer, geen frame langer dan 100 ms buiten laadmomenten
  en video's.
- Gevechten (Classic en Action) 55 fps of meer.
- RAM-piek onder de grens die Dennis kiest; geen groei over 30 minuten (lek).
- Kaartwissel zonder zichtbare hapering langer dan 1 seconde.

Toegestane fixes: performance zonder gedragsverandering (goedkopere shader of overlay, minder `_process` werk,
`preload` in plaats van `load`, kleiner of herbruikt effect). Geen kwaliteitsverlies in art zonder akkoord van Dennis.

- [ ] Regressiecheck na elke fix: `autotest`, `menutest`, de suite van het gebied.

**Gate:** meetrapport (tabel per scène) in dit bestand of als issue, alle doelen gehaald of door Dennis geaccepteerd.

**Niet in deze fase:** grafische upgrades, nieuwe effecten, resolutie of renderer wisselen.

---

## Fase 5: Balans (headless battle sim)

**Doel:** WM1 voelt eerlijk: geen onbedoeld triviale of onmogelijke stukken, bazen in een afgesproken venster.

Hulpmiddelen (alleen data-afstelling; de sim speelt het echte gevecht, `tools/battlesim/`)
- Volledig rapport (Classic): `xvfb-run -a godot --rendering-driver opengl3 --path . -- --battlesim --seed=20261020 --fights=2000`
  schrijft `docs/BATTLE_BALANCE_REPORT.md` (ca. 8 minuten). Optioneel `--only=id,id`, `--out=file.md`, `--json=file.json`.
- Per run (CSV, geen test): `-- --battlesim --party=dennis:5,noor:5 --enemy=all|enc<N>|<groep-id>|a+b --runs=N --seed=S --policy=simpel`
  schrijft `user://sim/battlesim_<policy>_s<seed>.csv`; samenvatting met `python3 tools/battlesim/rapport.py [csv|map]`.
- Action-stijl: `-- --actionsim` schrijft `docs/ACTION_BALANCE_REPORT.md`. Archief 1: `-- --archief1balans`.
- Bewaking in CI: `battlesimtest` en `balansarchief1test`; een steekproef met vaste seed zit in `autotest`.

Stand op `61986e9` (power scaling v2, PR #208), uit `docs/BATTLE_BALANCE_REPORT.md`

| Onderdeel | Winst | HP-verlies | Opmerking |
|---|---:|---:|---|
| Wereldkaart-gevechten | 100% | 16% | gezond |
| Archief 1 verdieping 1 tot 4 | 100% | 7 tot 10% | zacht, zoals bedoeld voor Act 1 |
| Boss Golem | 84% | 65% | binnen venster |
| Donker Woud | 96% | 30% | |
| Boss Root King | 82% | 75% | binnen venster |
| Berggrot | 100% | 13% | |
| Archief 2 verdieping 1 tot 4 | 100% | 9 tot 14% | |
| Boss The Strangler | 100% | 8% | triviaal (lock H16) |
| Boss The Mender | 100% | 22% | zacht (lock H16) |
| Diepe Grot verdieping 1, 5, 15 | 100% | 0 tot 4% | TRIVIAL-vlag |
| Diepe Grot-bazen 20, 30, 80, 90 | 58%, 80%, 71%, 65% | 61 tot 85% | HARD-vlag |

Taken
- [ ] Dennis kiest de doelvensters (voorstel: normale gevechten 10 tot 25% HP-verlies; bazen 60 tot 85% winst;
  Diepe Grot loopt op naar 60 tot 80% winst rond verdieping 80 tot 99). Noteer ze hier.
- [ ] Draai het volledige rapport op de freeze-commit en zet de afwijkingen in een tabel (hoger of lager dan het venster).
- [ ] Beslis per afwijking: afstellen (data-getal in `scripts/data/`, zoals `game_data.gd`, `archief2.gd`,
  `dungeon100_scaling.gd`) of laten staan. CANON-boss-stats (Golem, Strangler, Mender, Diepe Grot 25, 50, 75, 99)
  alleen met expliciet akkoord van Dennis; HP = level x 50 is vastgelegd in `scripts/data/archief2.gd`.
- [ ] Controleer de levelcurve: haalbaarheid van Lv 14 (Screening Room), Lv 20 (Training Hall en grade 3-magie),
  Lv 26, 32 en 37 (lock H3) via Diepe Grot-run-tijden.
- [ ] Controleer de economie met de CSV-modus: goud uit gevechten tegen prijzen in `scripts/data/shop_data.gd`
  (Willowdale), kist-buit en Diepe Grot-buit (`dungeon100_reward.gd`).
- [ ] Controleer Classic tegenover Action (zelfde doelen; Action-bazen via `SomData.ACTION_BOSS_MULT`).
- [ ] Na elke wijziging dezelfde seed opnieuw draaien en het rapport als bewijs in de PR zetten
  (zelfde seed en code geven dezelfde cijfers).
- [ ] Suites: `battlesimtest`, `balansarchief1test`, `dungeon100schaaltest`, `autotest`, `woudtest`, `archief2test`.

**Gate:** alle WM1-gebieden binnen het afgesproken venster of met een genoteerde reden, rapport bijgewerkt op de
release-candidate-commit.

**Niet in deze fase:** nieuwe vijanden, nieuwe vaardigheden, nieuwe mechanieken, CANON-wijzigingen zonder Dennis.

---

## Fase 6: UX-polish (tutorials, menu's, Engelse tekst, touch, audio)

**Doel:** een nieuwe speler begrijpt het spel zonder uitleg, op een telefoon.

Tutorials
- [ ] Opa's uitrusting-tutorial (MENU > Equipment > Armor, mantel aan, menu sluiten): niet te omzeilen, geen vastloper
  (mantel weggooien geeft een nieuwe).
- [ ] Inktwurm-tutorial (Classic/Action en Quest Log, 4 pagina's) en Codex-vang-tutorial (4 pagina's): Next, Skip,
  speelt één keer, ook na laden; teksten passen op 384x216 (`tutorialtest`).
- [ ] Is er uitleg voor RUN, partywissel in de Rest Room, de winkels en de Warp? Zo niet: beslis of een bestaande
  regel tekst volstaat (geen nieuwe tutorial, lock sectie 4).

Menu's en bediening
- [ ] Titel: Continue, Load, New Game, Co-op (LAN) en PvP volgens de keuze bij lock H11.
- [ ] Veldmenu: Equipment, Codex, Items, Magic, Bestiary, Warp, Party, Quest Log, Scenes & Music, Settings, Load.
  Elke knop bereikbaar met één duim; terug-knop en Android-terug doen hetzelfde.
- [ ] Veldmenu-melding "The warp hub cannot be reached yet." klopt met de hub-status.
- [ ] Opslaan en laden: duidelijke bevestiging, autosave-melding, geen verwarring tussen slot en autosave.
- [ ] Quest Log (ECHO): actieve en afgeronde opdrachten, huidige stap; titel van de zijopdracht (lock H7).

Engelse tekst (AGENTS.md regel 3)
- [ ] Alle punten uit lock H7 repareren (opdrachttitel, Archief 2-teksten, party-select, spreuk-blokkade, Benen en Laarzen).
- [ ] Volledige sweep: `rg -n -P '"[^"\n]*\b(het|een|niet|voor|naar|geen|Stap|Kies|Terug|Opslaan)\b[^"\n]*"' scripts world_warper pvp`
  en handmatig uitfilteren (commentaar, logregels en interne ids zijn Nederlands en blijven).
- [ ] Namen: `docs/lore/CANON.md` (Dax, Vesper, Seren). De "namenlijst" `namen_engels.md` bestaat niet in de repo
  (`docs/BACKLOG_WM1.md` A5): Dennis levert hem of verklaart CANON voldoende.
- [ ] Tekstfouten en afkapping in elke dialoogballon en menu op 384x216 (ballon is laag; max. 2 regels).
- [ ] Door Dennis goedgekeurde tekst (lock H8, ECHO-zinnen) verwerken als klasse "tekst door Dennis".

Touch
- [ ] Alle knoppen en tikdoelen minstens 48 dp op de S25 (`scripts/touch_controls.gd`, `scenes/ui/touch_controls.tscn`);
  reken viewport-pixels om op het echte toestel.
- [ ] RUN-knop in elke kamer-soort behalve gevecht (kerker, dorp, Rest Room, Koopman): geen suite dekt dit (backlog A11).
- [ ] Joystick en D-pad in Action-gevecht, ringmenu, Codex-knop.
- [ ] Veilige zone (camera-uitsparing, rand): niets belangrijks onder de rand.
- [ ] Meerdere vingers tegelijk, schermrotatie, app naar de achtergrond en terug (autosave bij focusverlies staat in
  `scripts/game_state.gd`), schermvergrendeling tijdens een cutscene of video.
- [ ] Video's overslaan met een tik; geen vastloper als video niet afspeelt (vangnet-timer).

Audio
- [ ] Per kaart de juiste track (`data/music_tracks.json`, kaartveld `music_track`) en geen dubbele of ontbrekende
  overgang (`musictest`, `muziektest`).
- [ ] Ontbrekende BGM bewust stil (lock H9): `rustplek`, `overwinning`, `game_over`, `sapientia_thema`. Dennis beslist of
  een bestaande track mag worden hergebruikt via het manifest.
- [ ] Volumeschuiven (Music, SFX) werken, mute onthouden, audio stopt netjes bij focusverlies.
- [ ] Placeholder-sfx (alle 99) acceptabel voor de RC, of Dennis levert vervangers bestand-voor-bestand
  (`tools/placeholders_algemene_sfx.txt`, `tools/placeholders_sfx.txt`; CI-job `algemene-sfx`).
- [ ] World Warper-cues zonder clip (`ww_hum`, `ww_warp`, `ww_sapientia_glitch`) zwijgen zonder fout.

**Gate:** alle vakjes afgevinkt of door Dennis als "bewust zo" getekend; `menutest`, `tutorialtest`, `musictest`,
`muziektest`, `actorsfxtest` groen.

**Niet in deze fase:** nieuwe tutorials, nieuwe menu's, nieuwe muziek, herontwerp van de UI.

---

## Fase 7: Dennis' playtest en fixronde

**Doel:** de echte speler vindt wat de tests niet vinden; alles blokkerends wordt gefixt.

- [ ] RPG Forge levert een playtest-APK (workflow `build-apk`, `build_type` debug of release; geen secrets in git).
  Sessielog aan voor deze ronde (`scripts/core/sessie_log.gd`; standaard uit in release, `Settings` sleutel
  `sessie_log`); noteer het build-id uit de startregel van het log in elk issue.
- [ ] Dennis speelt de golden path (lock sectie 1) van een nieuw spel tot de hub, daarna de Diepe Grot. Minstens één
  keer per route (A en B) en één keer Action in plaats van Classic.
- [ ] Bugs als GitHub-issue met label `bug` en het formaat: build-id, save-slot, stappen, verwacht, gekregen, ernst,
  screenshot of video.
- [ ] Ernst: **P0** crash of dataverlies; **P1** softlock of onmogelijke voortgang; **P2** fout gedrag met omweg;
  **P3** kosmetisch.
- [ ] Triage met RPG Forge: P0 en P1 gaan altijd in de fixronde; P2 alleen als de lock-klasse "bugfix" past; P3 mag
  blijven staan en komt in de known issues.
- [ ] Fixronde: elke fix een eigen branch `cursor/<korte-taak>`, kleine PR, met regressietest en label `wm1-bugfix`.
  Nieuwe wensen gaan naar de lijst voor na de release (lock sectie 4.3), niet in een PR.
- [ ] Na elke fix-batch: alle suites groen, korte herspeel van het stuk waar de bug zat.
- [ ] Tweede playtest op de gefixte build (maximaal twee rondes vóór de RC).

**Gate:** 0 open P0 en P1, P2's afgehandeld of bewust uitgesteld, Dennis zegt "dit is een release candidate".

**Niet in deze fase:** extra content naar aanleiding van feedback.

---

## Fase 8: Release candidate

**Doel:** één ondertekende APK die Dennis kan installeren en die bij een groene CI hoort.

Versie en changelog (RPG Forge)
- [ ] Versienummer kiezen en overal gelijk zetten. Nu staat `config/version="0.20"` in `project.godot`, terwijl de
  preset Android in `export_presets.cfg` `version/name="0.19"` en `version/code=22` heeft en `README.md` nog eerdere
  versielabels noemt. Alleen RPG Forge past dit aan; agents niet.
- [ ] `version/code` hoger dan de laatst geïnstalleerde APK, zodat updaten over een bestaande installatie werkt.
- [ ] Changelog schrijven: er is nog geen `CHANGELOG.md`. Inhoud: wat WM1 bevat (lock sectie 2), known issues (de
  open P2/P3-bugs en de SHIP-punten met lacune uit lock sectie 3), PvP en Co-op als experimenteel of verborgen
  (H11), bekende placeholders (H10, H9).
- [ ] `README.md` en `docs/BUILDS.md` kloppen met de RC (alleen RPG Forge).

Build en handtekening (RPG Forge)
- [ ] CI groen op de RC-commit: alle suites in `tests.yml`, `warper-runner`, `algemene-sfx` en `build-web`.
- [ ] APK via workflow `build-apk` met `build_type: release`. De keystore en wachtwoorden staan alleen als repository
  secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`);
  niets daarvan komt in git, issues of logs.
- [ ] Controle op de APK: `apksigner verify --print-certs sapientia.apk` (ondertekend met de release-sleutel, niet
  debug), `aapt dump badging sapientia.apk` (package `com.dennis.rpgprototype`, versieNaam en versieCode kloppen,
  arm64-v8a aanwezig), bestandsgrootte genoteerd.
- [ ] Rechten in de APK kloppen met de keuze bij H11 (`internet`, wifi-state, multicast staan nu aan in de preset).
- [ ] Installatietest op de S25: schone installatie en update over de vorige build met een bestaande save (saves blijven).
- [ ] Rookroute op de RC-APK: nieuw spel, proloog, wereldkaart, Willowdale-winkel, Archief 1 tot de Golem, opslaan,
  afsluiten, Continue. Daarna een korte hub-check met een testsave of vroege cheatloze doorloop.
- [ ] Repo-hygiëne opnieuw: geen APK/AAB/keystore/`.uid`/`.env` in git (zie fase 3), geen signing-velden in
  `export_presets.cfg`.
- [ ] Release-tag `v<versie>-rc1` door RPG Forge; artifact bewaren (retentie van `build-apk` is 14 dagen, dus
  downloaden en veilig opslaan).

Eindbeslissing
- [ ] Dennis speelt de RC-APK en zegt go of no-go. Bij no-go: alleen blokkerende fixes (P0 en P1) en een nieuwe RC.
- [ ] Na go: tag `v<versie>`, release-notities uit de changelog, `wacht/wm2/` blijft on hold tot een apart besluit.

**Gate:** ondertekende APK geïnstalleerd en gespeeld op de S25, versienummer en changelog kloppen, CI groen op
de release-commit, Dennis geeft go.

**Niet in deze fase:** nieuwe features of content; alleen P0- en P1-fixes na RC1.

---

## Voortgang

| Fase | Status | Datum | Akkoord |
|---:|---|---|---|
| 1 Freeze | open | | |
| 2 Art op palet | open | | |
| 3 Stabiliteit | open | | |
| 4 S25-performance | open | | |
| 5 Balans | open | | |
| 6 UX-polish | open | | |
| 7 Playtest en fixronde | open | | |
| 8 Release candidate | open | | |
