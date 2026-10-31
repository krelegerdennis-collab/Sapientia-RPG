# WM1 playtestscript (telefoon)

Speelscript voor **Dennis** — één doorloop van World Map 1 op je telefoon. Speltekst is **Engels**; dit document is **Nederlands**. Geen WM2/WM3 (`wacht/wm2/`). Route en vlaggen komen uit de repo (`story_data.gd`, `dungeon_rooms.gd`, `woud_rooms.gd`, `woud_beek.gd`, `berggrot_data.gd`, `archief2.gd`).

**Per stap:** voer de actie uit, controleer het verwachte resultaat, vink **OK** of **Bug**.

---

## Voorbereiding

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| V1 | Titelscherm → **New Game** (niet Beta Test / End State) | Start in `huis_wilgendal` als Dax, Lv1, 3 Potion + 1 Magic Water | ☐ | ☐ |
| V2 | **Settings > Session Log** op Auto (debug-build) | Log schrijft naar `user://logs/sessie_*.jsonl` | ☐ | ☐ |
| V3 | Touch: liggend, joystick links, A/B rechts | Geen dode zones; MENU-knop opent menu | ☐ | ☐ |

---

## 1. Wachtershuis-erf (proloog)

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 1.1 | Praat met Opa; kies één toon in het keuzemenu | Dialoog gaat door; mantel-event volgt | ☐ | ☐ |
| 1.2 | **Menu > Equipment** — mantel aantrekken | Zonder mantel geen zwaardles | ☐ | ☐ |
| 1.3 | Put (water) + kist (3 herbs) | Opa geeft pas daarna zwaardles | ☐ | ☐ |
| 1.4 | Zwaardles → gevecht **Moss Slime** (Action-stijl standaard) | Gevecht winbaar; uitleg leesbaar | ☐ | ☐ |
| 1.5 | Avond: aardbeving, Opa weg, deur op slot; kies Follow Grandpa | Pad naar archief/wereld nog geblokkeerd vóór nacht | ☐ | ☐ |
| 1.6 | Opslaan bij gloeiend boek op erf → app kill → **Continue** | Zelfde tegel, story, inventaris | ☐ | ☐ |
| 1.7 | App naar achtergrond 10 s → terug midden op erf | Geen crash, geen dubbele input | ☐ | ☐ |

---

## 2. Wereldkaart

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 2.1 | Na nacht: wereldkaart bereikbaar; korte cutscene eerste keer | Cutscene speelt één keer | ☐ | ☐ |
| 2.2 | Loop gras/hoog gras/zand/bos; laat 2–3 random gevechten komen | Encounters na veilige stappen; vluchten werkt | ☐ | ☐ |
| 2.3 | Ingangen zichtbaar: Archief, dorp, woud, grot (later kas) | Overgangen laden zonder zwart scherm > ~1 s | ☐ | ☐ |
| 2.4 | Scroll snel over de kaart | Framerate soepel (geen `gat` ≥3 s in log) | ☐ | ☐ |

---

## 3. Archief 1 (De Vergeten Archieven)

Route: ingang (save) → gang → zijkamers → zuilenhal → **puzzelkamer** (Vonkzwaard) → wachtersgang → voorhal → bibliotheek (save) → **golemhal**.

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 3.1 | Loop volledige route; los puzzelkamer op | Geheime deur + kist; geen softlock | ☐ | ☐ |
| 3.2 | **Golem** (Kustos): verlies één keer indien mogelijk, daarna win | Checkpoint/respawn logisch; win geeft kern + verhaal | ☐ | ☐ |
| 3.3 | Inktwurm uit kist in golemhal → Codex-tutorial | Uitgang warper dicht tot Inktwurm in Codex | ☐ | ☐ |
| 3.4 | Save/load in ingang én bibliotheek | `state_data` klopt; puzzel midden in kamer niet in save (bekend) | ☐ | ☐ |

---

## 4. Esdoorn

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 4.1 | Wereldkaart → Esdoorn (poort open na Golem) | Ontvoering Vesper; quest **Save Vesper from the Dark Wood** | ☐ | ☐ |
| 4.2 | Herberg: gratis rust | Tekst wijst naar opslagboek | ☐ | ☐ |
| 4.3 | Huis Noor + NPC's | Geen Nederlandse spelertekst | ☐ | ☐ |

---

## 5. Donker Woud (+ De Beek)

Route: `woud_rand` → `woud_pad` → `woud_mistpoel` → `woud_sporenkring` (save) → `woud_open_plek` (baas).  
Zijkamer: op **Wortelpad** struik-opening → **`woud_beek`** (Dark Wood - Brook) → terug via uitgang (spawn `beek` op pad).

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 5.1 | Loop hoofdroute; geen random encounters op fout terrein | Woud-vijanden (Wood Wraith e.d.) | ☐ | ☐ |
| 5.2 | Open struik → **De Beek**; loop brug/stapstenen/over de beek | Kaart laadt; terug naar pad op spawn `beek`; geen monsters (data) | ☐ | ☐ |
| 5.3 | **Root King** op open plek | Te winnen; Vesper (`noor_lid`) sluit aan na afloop | ☐ | ☐ |
| 5.4 | Zijquest **The Singing Grain**: Garrett (molenaar, Vesper nodig) → zaad-gevecht | Quest voortgang in Quest Log | ☐ | ☐ |
| 5.5 | **Menu > Party**: wissel actief/bank | Max 4 helden + 1 monster in gevecht | ☐ | ☐ |

---

## 6. Wilgendal (dorp) + winkels

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 6.1 | `dorp_wilgendal`: vijf winkels (wapen, pantser, accessoire, magie, kruiden) | Kopen/verkopen/equip; prijzen passen bij gold | ☐ | ☐ |
| 6.2 | `wilgendal_binnen` in/uit | Juiste spawn bij terugkeer | ☐ | ☐ |
| 6.3 | Geen herberg in Wilgendal zelf | Rust blijft in Esdoorn (verwachting klopt) | ☐ | ☐ |

---

## 7. Berggrot

Keten: mond (save) → grendel (puzzel) → nerf → geheim (puzzel) → uitmond → Archief 2-ingang. Bouwplaats-tunnel: dicht zonder Vesper, open met Vesper.

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 7.1 | Beide puzzels oplossen | Permanente blokkade niet | ☐ | ☐ |
| 7.2 | Geen baas in grot | Alleen normale gevechten | ☐ | ☐ |
| 7.3 | Uitmond ↔ kas-entree retour | Wereldkaart-poort kas: Golem + Vesper in party | ☐ | ☐ |

---

## 8. Archief 2 (Het Levende Archief)

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 8.1 | Kas v1: groeiplaat-puzzel | Voortgang naar Seren/Lotte-gevecht | ☐ | ☐ |
| 8.2 | **Seren** (Lotte-glitch): win of verlies | Seren sluit aan; quest "Seren joins the party" | ☐ | ☐ |
| 8.3 | v3: **Strangler** + **Mender** (bazen) | Winbaar; Mender start hub-cutscene | ☐ | ☐ |
| 8.4 | BGM: `bgm_levend_archief` / baas-track hoorbaar (placeholder OK) | Geen stilte-crash | ☐ | ☐ |

---

## 9. World Warper-hub

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 9.1 | Na Mender: hub exterieur + hal | `world_warper_unlocked`; bewegen na cutscene | ☐ | ☐ |
| 9.2 | **Menu > Warp** | WM1-bestemmingen; WM2/WM3 dicht met duidelijke tekst | ☐ | ☐ |
| 9.3 | Rest Room, ECHO's Chamber | Party wissel; ECHO-tekst leesbaar (TODO_STORY bekend) | ☐ | ☐ |
| 9.4 | Dichte deuren (Training, Workshop, …) | Hint + geen softlock | ☐ | ☐ |

---

## 10. Action-combat: dodge, keten, charge

**Settings > Battle Style = Action.** Test in een normaal gevecht (wereldkaart of Archief-kamer) zodra Dax (en later Seren) beschikbaar zijn.

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 10.1 | **B** (touch rechtsonder) = dodge / `som_dodge` | Rol met i-frames; stamina daalt (~30 per dodge) | ☐ | ☐ |
| 10.2 | **A** drie keer binnen ketenvenster (Dax) | 3-slag keten + finisher (`som_chain_data`) | ☐ | ☐ |
| 10.3 | Houd **A** ingedrukt tot meter vol → loslaten | Opgeladen zware slag (hogere damage); geen charge in Classic | ☐ | ☐ |
| 10.4 | Zet Battle Style op **Classic**; herhaal één gevecht | Turn-based menu; geen dodge/keten/charge | ☐ | ☐ |
| 10.5 | Gevecht start → home → terug | Geen crash; gevecht hervat of netjes eindigt | ☐ | ☐ |

---

## 11. Dwarsdoorsnede (onderweg afvinken)

| # | Actie | Verwacht resultaat | OK | Bug |
|---|---|---|:---:|:---:|
| 11.1 | Save/load in ≥3 gebieden (erf, woud, hub) | Party, gold, quests, kaart kloppen | ☐ | ☐ |
| 11.2 | Autosave bij wereldkaart ↔ kerker wissel | Geen corrupt save | ☐ | ☐ |
| 11.3 | Alle menu's: Items, Magic, Codex, Bestiary, Quest Log, Settings | Engels; geen overflow | ☐ | ☐ |
| 11.4 | Touch-grootte/dekking in Settings aanpassen | Blijft na herstart | ☐ | ☐ |

---

## Eindcheck WM1

- ☐ Proloog → nacht zonder softlock  
- ☐ Golem + Inktwurm in Codex  
- ☐ Woud + **De Beek** + Root King + Vesper in party  
- ☐ Wilgendal-winkels  
- ☐ Berggrot + Archief 2 (Seren, Strangler, Mender)  
- ☐ Hub + Warp  
- ☐ Dodge / keten / charge (Action) getest  
- ☐ Log geëxporteerd (`Settings > Export Log`) + `python3 tools/sessielog/playtest_rapport.py …`

---

## Bug-template (kopieer per bug)

```
Gebied / kaart:
Stap #:
Build / versie:
Wat deed je:
Verwacht:
Werkelijk:
Herhaalbaar (ja/nee):
Ernst: blokkeert / hinderlijk / klein
Screenshot of logregel (optioneel):
```
