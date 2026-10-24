#!/usr/bin/env python3
"""Schrijf docs/balance_wm1_report.md uit tools/wm1balans/wm1_runs.json.

De tabellen komen uit de JSON. De voorstellen zijn tekst bij deze meting
(seed 20261020, 200 runs per groep). Na een nieuwe run de voorstellen nalopen.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JSON_PATH = ROOT / "tools" / "wm1balans" / "wm1_runs.json"
OUT = ROOT / "docs" / "balance_wm1_report.md"

# Doel uit scripts/data/game_data.gd (power scaling v2): gewone gevechten ~10-20% HP,
# bazen ~60-90% winst. Vlaggen van de battlesim: HARD < 80%, NEAR < 50%,
# TRIVIAL = 100% winst, < 5% HP, <= 2 rondes.
BOSS_WIN = (0.60, 0.90)
TRASH_HP = (0.10, 0.20)


def pct(v: float) -> str:
    return f"{v * 100:.1f}%"


def num(v: float, d: int = 2) -> str:
    return f"{v:.{d}f}"


def flag(g: dict) -> str:
    if g["win_rate"] < 0.5:
        return "BIJNA ONMOGELIJK"
    if g["win_rate"] < 0.80:
        return "ZWAAR"
    if g["win_rate"] >= 1.0 and g["avg_hp_loss"] < 0.05 and g["avg_rounds"] <= 2.0:
        return "TRIVIAAL"
    return ""


def find(data, id_):
    for r in data:
        if r["id"] == id_:
            return r
    raise KeyError(id_)


def gfind(area, label):
    for g in area["groups"]:
        if g["label"] == label:
            return g
    raise KeyError(label)


def weighted(area, key):
    w = sum(g["weight"] for g in area["groups"])
    return sum(g[key] * g["weight"] for g in area["groups"]) / w


def row_area(r):
    return (
        f"| {r['name']} | {r['n']} | {len(r['groups'])} | {pct(r['win_rate'])} | "
        f"{num(r['avg_rounds'])} | {pct(r['avg_hp_loss'])} | {pct(r['p90_hp_loss'])} | "
        f"{num(r['avg_items'])} | {num(r['avg_mp'], 1)} | {num(r['avg_kos'])} | {flag(r)} |"
    )


def cell(s: str) -> str:
    return str(s).replace("|", "/")


def row_g(g):
    return (
        f"| {cell(g['label'])} | {g['weight']} | {g['n']} | {pct(g['win_rate'])} | "
        f"{num(g['avg_rounds'])} | {pct(g['avg_hp_loss'])} | {pct(g['p90_hp_loss'])} | "
        f"{num(g['avg_items'])} | {num(g['avg_mp'], 1)} | {num(g['avg_kos'])} | {flag(g)} |"
    )


def row_g_area(area_name: str, g: dict) -> str:
    # row_g begint met "| label | …"; de tweede cel is de encounter, niet het gebied.
    return f"| {cell(area_name)} | " + row_g(g)[2:]


HEAD_A = (
    "| Gebied | Runs | Groepen | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |\n"
    "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"
)
HEAD_G = (
    "| Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |\n"
    "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"
)
HEAD_GA = (
    "| Gebied | Encounter | Plaatsingen | Runs | Winst | Rondes | HP-verlies | p90 | Items | MP | KOs | Vlag |\n"
    "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"
)


def main() -> None:
    data = json.loads(JSON_PATH.read_text())
    for r in data:
        for g in r["groups"]:
            if g["n"] != 200:
                raise SystemExit(f"{r['id']} {g['label']} n={g['n']}")
        if r["timeouts"] != 0:
            raise SystemExit(f"timeouts in {r['id']}")

    fights = sum(r["n"] for r in data)
    groups = sum(len(r["groups"]) for r in data)
    route_ids = [r["id"] for r in data if not str(r["id"]).startswith("d100_")]
    d100 = [r for r in data if str(r["id"]).startswith("d100_")]

    wm = find(data, "wereldkaart1")
    moth3 = gfind(wm, "Glitch Moth + Glitch Moth + Glitch Moth")
    beast = gfind(wm, "The Knowledge Beast")
    beast2 = gfind(wm, "The Knowledge Beast + Paper Wraith")
    a1f4 = find(data, "archief1_v4")
    a1f1 = find(data, "archief1_v1")
    golem = find(data, "golem")
    woud = find(data, "woud")
    guard = gfind(woud, "Root Crawler + Root Crawler + Spore Cap (tier 4)")
    pair = gfind(woud, "Root Crawler + Spore Cap (tier 4)")
    spores = gfind(woud, "Spore Cap + Spore Cap + Mist Owl (tier 4)")
    spores2 = gfind(woud, "Spore Cap + Spore Cap (tier 4)")
    king = find(data, "wortelkoning")
    grot = find(data, "berggrot")
    a2f1 = find(data, "archief2_v1")
    a2f3 = find(data, "archief2_v3")
    lotte = find(data, "lotte")
    wurger = find(data, "a2boss_wurger")
    genezer = find(data, "a2boss_genezer")
    worm = find(data, "wm1extra_inktwurm")
    les = find(data, "wm1extra_les")
    zaad = find(data, "wm1extra_woudgeest")
    f5 = find(data, "d100_v5")
    f15 = find(data, "d100_v15")
    f95 = find(data, "d100_v95")
    f85 = find(data, "d100_v85")
    b20 = find(data, "d100_boss_20")
    b25 = find(data, "d100_boss_25")
    b50 = find(data, "d100_boss_50")
    b75 = find(data, "d100_boss_75")
    b99 = find(data, "d100_boss_99")
    b80 = find(data, "d100_boss_80")
    b90 = find(data, "d100_boss_90")
    b10 = find(data, "d100_boss_10")
    watch2 = gfind(f95, "Aureate Watcher + Aureate Watcher + Drip Slug (floor 95)")
    watch1 = gfind(f95, "Aureate Watcher (floor 95)")
    wolf = gfind(f85, "Scanline Wolf + Drip Slug + Scanline Wolf (floor 85)")

    L = []
    a = L.append
    a("# Balans WM1 — meting")
    a("")
    a("Meting met de bestaande headless battlesim (`tools/battlesim/battlesim.gd`, echte `scenes/battle/battle.tscn`).")
    a("Geen balansdata gewijzigd. De getallen hieronder komen uit `tools/wm1balans/wm1_runs.json`.")
    a("")
    a("## Hoe gemeten")
    a("")
    a(f"- Godot 4.3-stable (official), seed 20261020, runtime 273,5 s, {fights} gevechten, {groups} encountergroepen, {len(data)} gebieden.")
    a("- Elke unieke groep in een gebied is **200 keer** gevochten (elke groep even vaak). De gebiedsregel is het gemiddelde van die runs, dus een zeldzame groep telt even zwaar als een veelgeplaatste. De kolom Plaatsingen is het gewicht uit de kamer- of encounterdata (hoe vaak de groep op de kaart staat); die weegt de runs niet.")
    a("- Partij, level en uitrusting zijn die van `battlesim.gd` `scenarios()`: Act 1 Lv 1–13 en Act 2 Lv 14–19 uit `scripts/data/level_scale.gd`, doel-level 7 voor het Eerste Archief, Vesper sluit aan op Dax−1 na de Wortelkoning, Seren op Dax' level met de smeedset vanaf Archief 2 verdieping 3. De Diepe Grot gebruikt `d100_level`: verdieping 1 is vast Lv 1, daarboven Lv = afgerond(5 + 0,4 × verdieping), afgeleid van de canonregel HP = level × 50 op verdieping 25/50/75/99.")
    a("- Winst, rondes, HP-verlies, items, MP en KOs zijn de velden van de sim. HP-verlies is de party-HP aan het eind tegenover het begin, als deel van de maximale party-HP, na genezing; een KO telt als een lege balk. Items zijn verbruikte consumables. MP is uitgegeven MP. Een ronde is één beurt voor alle helden en vijanden. Een gevecht dat na 60 rondes niet af is, telt als verlies; dat kwam in deze run **0 keer** voor.")
    a("- De AI is `sim_battle.gd`: genezen onder 40% HP, een schade-spreuk alleen als die naar verwachting 15% beter is dan een aanval, anders de vijand met de minste HP. Bliksem en ijs slaan een beurt over met 30% per treffer, ook bij bazen. Geen Codex-bondgenoot, geen vluchten, geen verdedigen.")
    a("- Diepe Grot: de steekproefverdiepingen en 6 layout-seeds per verdieping zijn `D100_SAMPLE_FLOORS` en `D100_LAYOUTS` in `battlesim.gd`. Dit is elke groep uit die seeds, niet elke groep die de generator ooit kan leggen. De 12 baasverdiepingen zijn de vaste bazen uit `Dungeon100Scaling.BOSSES`.")
    a("- Drie gevechten zaten niet in de gebiedslijst en zijn in `tools/wm1balans/wm1_sim.gd` toegevoegd, met dezelfde party-bouwer: de proloogles (Moss Slime op 30 HP), de Inktwurm (na de Golem, Golemkern) en het Zingend Zaad (twee Wood Wraiths, basisstats).")
    a("- Standaard vechtstijl van een nieuw spel is Action. Deze meting is Classic (beurtgevecht). Bazen blijven ook in Action beurtgevechten, dus de baasregels gelden voor beide stijlen. De Action-factoren van Archief 1 (`SomData.ACTION_AREAS`) zitten niet in deze runs.")
    a("- WM2 en `wacht/` zijn niet meegenomen.")
    a("")
    a("Opnieuw draaien:")
    a("")
    a("```bash")
    a("xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/wm1balans/wm1_main.gd -- \\")
    a("    --seed=20261020 --fights=200 --json=res://tools/wm1balans/wm1_runs.json")
    a("python3 tools/wm1balans/schrijf_rapport.py")
    a("```")
    a("")
    a("Het doel waar de voorstellen aan afmeten staat in `game_data.gd` bij power scaling v2: gewone gevechten ongeveer 10–20% party-HP, bazen ongeveer 60–90% winst. De vlag in de tabellen is die van de sim: BIJNA ONMOGELIJK = winst onder 50%, ZWAAR = winst onder 80%, TRIVIAAL = 100% winst, minder dan 5% HP en hoogstens 2 rondes.")
    a("")
    a("## Party en tas")
    a("")
    for r in data:
        a(f"- **{r['name']}** (`{r['id']}`). {r['party']} Tas: `{json.dumps(r['inventory'], ensure_ascii=False)}`. {r['notes']}")
    a("")
    a("Bij het verhaalgevecht van Seren staat Vesper in de party-tekst, maar `archief2_party_filter` is `dennis`: alleen Dax vecht.")
    a("")
    a("## Samenvatting per gebied")
    a("")
    a("Elke groep even zwaar (200 runs per groep).")
    a("")
    a(HEAD_A)
    for r in data:
        a(row_area(r))
    a("")
    a(f"Wereldkaart, gewogen naar plaatsing (totaal gewicht {sum(g['weight'] for g in wm['groups'])}): winst {pct(weighted(wm, 'win_rate'))}, {num(weighted(wm, 'avg_rounds'))} rondes, {pct(weighted(wm, 'avg_hp_loss'))} HP, {num(weighted(wm, 'avg_items'))} items. De gelijke weging ({pct(wm['avg_hp_loss'])} HP) telt de zeldzame drie motten en het Kennis-Beest even zwaar als een enkele Moss Slime.")
    a("")
    a("## Elke encounter")
    a("")
    a("200 runs per regel. Plaatsingen = gewicht in de brondata.")
    a("")
    for r in data:
        a(f"### {r['name']}")
        a("")
        a(HEAD_G)
        for g in r["groups"]:
            a(row_g(g))
        a("")

    a("## Uitschieters")
    a("")
    a("### Te zwaar voor een gewone groep (winst onder 80%)")
    a("")
    a(HEAD_GA)
    n_hard = 0
    for r in data:
        if str(r["id"]).startswith("d100_boss") or r["id"] in ("golem", "wortelkoning", "lotte", "a2boss_wurger", "a2boss_genezer"):
            continue
        for g in r["groups"]:
            if g["win_rate"] < 0.80:
                n_hard += 1
                a(row_g_area(r["name"], g))
    a("")
    a(str(n_hard) + " gewone groepen zitten onder 80% winst. Op de WM1-route is dat er één: de bewaker in `woud_sporenkring` (Root Crawler + Root Crawler + Spore Cap, tier 4). De rest staat op verdieping 85 en 95 van de Diepe Grot.")
    a("")
    a("### Bazen buiten 60–90% winst, of een baas die in vier rondes voorbij is")
    a("")
    a(HEAD_A)
    for r in data:
        boss = str(r["name"]).startswith("BOSS") or r["id"] in ("golem", "wortelkoning", "lotte")
        if not boss:
            continue
        if r["win_rate"] < BOSS_WIN[0] or r["win_rate"] > BOSS_WIN[1] or r["avg_rounds"] <= 4.05:
            a(row_area(r))
    a("")
    a("De Golem (83,5%) en de Wortelkoning (76,0%) vallen binnen 60–90% en staan daarom niet in deze lijst. Wel in de volledige tabel hierboven.")
    a("")
    a("### Triviaal op de route")
    a("")
    a("100% winst, minder dan 5% HP, hoogstens 2 rondes. Diepe Grot staat hier niet regel voor regel; de vroege verdiepingen zijn bijna helemaal zo.")
    a("")
    a(HEAD_GA)
    n_triv_route = 0
    n_triv_d100 = 0
    for r in data:
        for g in r["groups"]:
            if flag(g) != "TRIVIAAL":
                continue
            if str(r["id"]).startswith("d100_"):
                n_triv_d100 += 1
            else:
                n_triv_route += 1
                a(row_g_area(r["name"], g))
    a("")
    a(f"Route: {n_triv_route} triviale groepen. Diepe Grot: {n_triv_d100} triviale groepen, geconcentreerd op verdieping 1, 5 en 15 (verdieping 5: gebiedsgemiddelde {pct(f5['avg_hp_loss'])} HP, {num(f5['avg_rounds'])} rondes, 100% winst).")
    a("")
    a("### Lang en duur, ook als de winst hoog is")
    a("")
    a(HEAD_GA)
    for r in data:
        for g in r["groups"]:
            if g["win_rate"] >= 0.95 and (g["avg_rounds"] >= 8 or g["avg_items"] >= 3 or g["avg_hp_loss"] >= 0.55):
                a(row_g_area(r["name"], g))
    a("")
    a(f"De Inktwurm wint altijd in {num(worm['avg_rounds'])} rondes en kost toch {pct(worm['avg_hp_loss'])} HP (p90 {pct(worm['p90_hp_loss'])}), zonder item. Korte piekschade, geen kans om te verliezen.")
    a("")
    a("## Voorstellen")
    a("")
    a("Voor RPG COMBAT en Dennis. Niks hiervan is doorgevoerd. Elke knop is één wijziging, daarna dezelfde sim opnieuw. Waar een lichtere samenstelling al in deze run zit, staat die regel erbij als gemeten vergelijking, niet als voorspelling.")
    a("")
    a("### 1. Wereldkaart — drie Glitch Moths van het gras af")
    a("")
    a(f"Dax Lv 3, startersset. Drie Glitch Moths (gewicht 1, geen `terrains` dus meegeloot op gras): {pct(moth3['win_rate'])} winst, {num(moth3['avg_rounds'])} rondes, {pct(moth3['avg_hp_loss'])} HP, p90 {pct(moth3['p90_hp_loss'])}. Het solo Kennis-Beest: {pct(beast['win_rate'])}, {num(beast['avg_rounds'])} rondes, {pct(beast['avg_hp_loss'])} HP. Kennis-Beest + Paper Wraith: {pct(beast2['win_rate'])}, {num(beast2['avg_rounds'])} rondes, {pct(beast2['avg_hp_loss'])} HP, {num(beast2['avg_items'])} items.")
    a("")
    a("Voorstel: in `GameData.ENCOUNTER_GROUPS` de groep `glitchmot+glitchmot+glitchmot` gewicht 1 → 0. Het solo Kennis-Beest (ongeveer 23% HP, zeldzaam) kan blijven. Kennis-Beest + Paper Wraith ook gewicht 0, of `terrains: [\"archief\"]`. Basis-HP en ATK van Glitch Moth (16 / 15) niet verhogen: die soort staat ook in Archief 1, en Action klemt daar de HP.")
    a("")
    a("### 2. Donker Woud — de bewaker in de Sporenkring inkorten")
    a("")
    a(f"`woud_sporenkring` tier 4, bewaker op tegel [14, 4], groep wortelkruiper + wortelkruiper + sporenzwam. Dax Lv 11 met Vonkzwaard, Kaftschild, IJzeren Helm en Golemkern: {pct(guard['win_rate'])} winst, {num(guard['avg_rounds'])} rondes, {pct(guard['avg_hp_loss'])} HP, {num(guard['avg_items'])} items, {num(guard['avg_kos'])} KOs. Dat is zwaarder dan de Golem ({pct(golem['win_rate'])} winst).")
    a("")
    a(f"Dezelfde verdieping heeft de groep Root Crawler + Spore Cap (tier 4) al gemeten: {pct(pair['win_rate'])} winst, {num(pair['avg_rounds'])} rondes, {pct(pair['avg_hp_loss'])} HP, {num(pair['avg_items'])} items. Voorstel: de bewaker wordt die groep (één Root Crawler eraf).")
    a("")
    a(f"Zelfde kamer, `m1` (Spore Cap + Spore Cap + Mist Owl): {pct(spores['win_rate'])} winst, {num(spores['avg_rounds'])} rondes, {pct(spores['avg_hp_loss'])} HP, {num(spores['avg_items'])} items. Spore Cap + Spore Cap (tier 4) zit ook in de run: {pct(spores2['win_rate'])}, {num(spores2['avg_rounds'])} rondes, {pct(spores2['avg_hp_loss'])} HP, {num(spores2['avg_items'])} items. Voorstel: de Mist Owl uit `m1` halen.")
    a("")
    a(f"De rest van het woud gemiddeld {pct(woud['avg_hp_loss'])} HP bij {pct(woud['win_rate'])} winst. Losse vijanden op tier 3 zijn triviaal; dat hoort bij de rand van het woud. Daar geen HP-verhoging op de soort.")
    a("")
    a("### 3. Golem en Wortelkoning — laten staan")
    a("")
    a(f"Golem, Dax Lv 8, Vonkzwaard, tas 5 drankjes / 2 toverwater / 2 kruid: {pct(golem['win_rate'])} winst, {num(golem['avg_rounds'])} rondes, {pct(golem['avg_hp_loss'])} HP, p90 {pct(golem['p90_hp_loss'])}, {num(golem['avg_items'])} items, {num(golem['avg_kos'])} KOs. Canonblok HP 360 / ATK 27 / DEF 15. Dat ligt in de band 60–90%.")
    a("")
    a(f"Wortelkoning, Dax Lv 12 solo met kern: {pct(king['win_rate'])} winst, {num(king['avg_rounds'])} rondes, {pct(king['avg_hp_loss'])} HP, {num(king['avg_items'])} items, {num(king['avg_kos'])} KOs. Baas-ATK 38. Ook in de band. Geen statwijziging.")
    a("")
    a("### 4. Inktwurm — meer HP, ATK laten")
    a("")
    a(f"Na de Golem, Dax Lv 8, zelfde set en kern, uniek, geen tier. Stats nu HP 74 / ATK 44 / DEF 17. Meting: {pct(worm['win_rate'])} winst, {num(worm['avg_rounds'])} rondes, {pct(worm['avg_hp_loss'])} HP, p90 {pct(worm['p90_hp_loss'])}, 0 items, 0 KOs.")
    a("")
    a("Voorstel: `max_hp` 74 → 130. ATK 44 blijft, zodat de klap het dreigende deel houdt en het gevecht langer duurt dan twee rondes. Daarna deze groep opnieuw meten. Geen wijziging aan de vangkans.")
    a("")
    a("### 5. Seren, de Wurger en de Genezer")
    a("")
    a(f"Seren (`lotte_glitch`, alleen Dax Lv 15, Vonkzwaard): {pct(lotte['win_rate'])} winst, {num(lotte['avg_rounds'])} rondes, {pct(lotte['avg_hp_loss'])} HP, 0 items. Baasblok HP 270 / ATK 32. Het gevecht gaat door bij winst én verlies. Voorstel, dit blok staat in de code als niet-canon: HP 270 → 420, ATK laten, hermeten. Doel van de hermeting: boven de 90% winst blijven (het verhaal moet door) en duidelijk boven de {pct(lotte['avg_hp_loss'])} HP van nu uitkomen.")
    a("")
    a(f"De Wurger, volle party Lv 16/15/16 met smeedset: {pct(wurger['win_rate'])} winst, {num(wurger['avg_rounds'])} rondes, {pct(wurger['avg_hp_loss'])} HP, {num(wurger['avg_mp'], 1)} MP, {num(wurger['avg_items'])} items, 0 KOs. Baasblok HP 700 / ATK 42 / DEF 28.")
    a("")
    a(f"De Genezer, zelfde party: {pct(genezer['win_rate'])} winst, {num(genezer['avg_rounds'])} rondes, {pct(genezer['avg_hp_loss'])} HP, {num(genezer['avg_mp'], 1)} MP, {num(genezer['avg_items'])} items.")
    a("")
    a("Power scaling v2 heeft Wurger en Genezer als canon onaangeroerd gelaten. Voorstel aan Dennis: die twee vrijgeven voor één HP-stap, ATK laten staan. Wurger HP 700 → 1400. Genezer HP 900 → 1350. `archief2_leech` pas aanraken na die hermeting. Zonder dat besluit blijven de stats zoals ze zijn; de meting zegt dan dat beide bazen een zeker drie- à vierrondengevecht zijn.")
    a("")
    a("### 6. Archief 1, berggrot, Archief 2-gangen, proloog, Zingend Zaad")
    a("")
    a(f"Archief 1 verdieping 1, Dax Lv 3: {pct(a1f1['win_rate'])} winst, {num(a1f1['avg_rounds'])} rondes, {pct(a1f1['avg_hp_loss'])} HP. Verdieping 4, Dax Lv 7 met Vonkzwaard: {pct(a1f4['win_rate'])}, {num(a1f4['avg_rounds'])} rondes, {pct(a1f4['avg_hp_loss'])} HP. Berggrot, Dax Lv 13 + Vesper Lv 12: {pct(grot['win_rate'])}, {num(grot['avg_rounds'])} rondes, {pct(grot['avg_hp_loss'])} HP, {num(grot['avg_mp'], 1)} MP. Archief 2 verdieping 1: {pct(a2f1['avg_hp_loss'])} HP in {num(a2f1['avg_rounds'])} rondes. Verdieping 3 met de smeedset: {pct(a2f3['avg_hp_loss'])} HP in {num(a2f3['avg_rounds'])} rondes. Allemaal 100% winst.")
    a("")
    a("Voorstel: TIERS, ARCHIEF_STAT_SCHAAL (0,7) en de berggrot-tier 7 niet wijzigen op basis van deze Classic-run. Verdieping 1 zit op de onderkant van 10–20% HP. Verdieping 4 zit er net onder, met het Vonkzwaard dat de sim op dit level al geeft. Basisstats van de Archief-1-soorten verhogen raakt de wereldkaart en de Action-HP-klem (`hp_hits` 2,5–3,0). Eerst `--archief1balans` als Action het gevoel van die gangen moet worden.")
    a("")
    a(f"Proloogles, Dax Lv 1, kort zwaard, leerlingmantel, lege tas, Moss Slime geforceerd op 30 HP: {pct(les['win_rate'])} winst, {num(les['avg_rounds'])} rondes, {pct(les['avg_hp_loss'])} HP. Voorstel: de les laten zoals hij is.")
    a("")
    a(f"Zingend Zaad, Dax Lv 12 + Vesper Lv 11, twee Wood Wraiths op basisstats (HP 12 / ATK 6): {pct(zaad['win_rate'])} winst, {num(zaad['avg_rounds'])} ronde, {pct(zaad['avg_hp_loss'])} HP, {num(zaad['avg_mp'], 1)} MP. Vesper's spreuk maakt het gevecht af voor de wraiths handelen. Voorstel: laten staan als het zaad een vondst is. Als het een woudgevecht moet zijn: HP 12 → 48 en ATK 6 → 14, en opnieuw meten. Tier 3 of 4 op deze basisstats haalt ze niet op het level van de Wortelkoning.")
    a("")
    a("### 7. Diepe Grot — vroege verdiepingen en de vier canonbazen")
    a("")
    a(f"Op het level uit `d100_level` zijn verdieping 5 ({pct(f5['avg_hp_loss'])} HP, {num(f5['avg_rounds'])} rondes) en verdieping 15 ({pct(f15['avg_hp_loss'])} HP, {num(f15['avg_rounds'])} rondes) triviaal, alle groepen 100% winst. Verdieping 35–65 lopen op naar de band 10–20% en er net over (verdieping 65: {pct(find(data, 'd100_v65')['avg_hp_loss'])} HP, {pct(find(data, 'd100_v65')['win_rate'])} winst).")
    a("")
    a(f"Canonbazen, HP = level × 50, party op het bijbehorende level met d100-uitrusting van die buit-tier. Schaduw van H-6 (verdieping 25): {pct(b25['win_rate'])}, {num(b25['avg_rounds'])} rondes, {pct(b25['avg_hp_loss'])} HP, {num(b25['avg_items'])} items. De Cyclus (50): {pct(b50['win_rate'])}, {num(b50['avg_rounds'])} rondes, {pct(b50['avg_hp_loss'])} HP. De Rechter (75): {pct(b75['win_rate'])}, {num(b75['avg_rounds'])} rondes, {pct(b75['avg_hp_loss'])} HP. De Stem (99): {pct(b99['win_rate'])}, {num(b99['avg_rounds'])} rondes, {pct(b99['avg_hp_loss'])} HP, {num(b99['avg_mp'], 1)} MP.")
    a("")
    a("Voorstel aan Dennis, de canon-HP niet stilletjes overschrijven. Twee keuzes, één ervan:")
    a("")
    a("1. Deze vier blijven een adempauze. De meting ondersteunt dat: vier rondes en ongeveer 20% HP, terwijl de niet-canon bazen eromheen 6–9 rondes en 44–86% HP kosten.")
    a("2. Ze moeten in de band 60–90%. Eerste proef, los van de andere knoppen: na `CANON_BOSS` de HP ×2, ATK en DEF laten, en alleen deze vier opnieuw meten.")
    a("")
    a(f"Vroege verdiepingen, als de canon-levels kloppen: `HP_LIN` 0,10 → 0,18 en `HP_FLAT` 2 → 4 in `dungeon100_scaling.gd`, daarna verdieping 5 en 15 opnieuw. `BOSS_MULT` en `CANON_BOSS` in diezelfde wijziging niet aanraken.")
    a("")
    a("### 8. Diepe Grot — stapels op verdieping 85–95, en de Glitch Queen")
    a("")
    a(f"Eén Aureate Watcher op verdieping 95: {pct(watch1['win_rate'])} winst, {num(watch1['avg_rounds'])} rondes, {pct(watch1['avg_hp_loss'])} HP. Twee Aureate Watchers + Drip Slug: {pct(watch2['win_rate'])} winst, {num(watch2['avg_rounds'])} rondes, {pct(watch2['avg_hp_loss'])} HP, {num(watch2['avg_kos'])} KOs. Scanline Wolf + Drip Slug + Scanline Wolf op verdieping 85: {pct(wolf['win_rate'])} winst, {num(wolf['avg_rounds'])} rondes, {pct(wolf['avg_hp_loss'])} HP, {num(wolf['avg_kos'])} KOs. Gebied 95, elke groep gelijk: {pct(f95['win_rate'])} winst, {pct(f95['avg_hp_loss'])} HP, {num(f95['avg_items'])} items, {num(f95['avg_kos'])} KOs. Naar plaatsing gewogen: {pct(weighted(f95, 'win_rate'))} winst, {pct(weighted(f95, 'avg_hp_loss'))} HP. Gebied 85: {pct(f85['win_rate'])} winst, {pct(f85['avg_hp_loss'])} HP.")
    a("")
    a("Voorstel: in de groepbouwer van de Diepe Grot hoogstens één `aureate_watcher` en hoogstens één `scanline_wolf` per gewone groep. Geen nieuwe soorten, geen hogere basis-HP. Daarna verdieping 85 en 95 opnieuw (zelfde 6 seeds, zelfde levels).")
    a("")
    a(f"Niet-canon bazen. Page Warden (10): {pct(b10['win_rate'])} winst, {pct(b10['avg_hp_loss'])} HP. Glitch Queen (20): {pct(b20['win_rate'])} winst, {num(b20['avg_rounds'])} rondes, {pct(b20['avg_hp_loss'])} HP, {num(b20['avg_kos'])} KOs, {num(b20['avg_items'])} items. Great Book Golem (80): {pct(b80['win_rate'])}, {num(b80['avg_rounds'])} rondes, {pct(b80['avg_hp_loss'])} HP, {num(b80['avg_kos'])} KOs. Root Emperor (90): {pct(b90['win_rate'])}, {num(b90['avg_rounds'])} rondes, {pct(b90['avg_hp_loss'])} HP, {num(b90['avg_kos'])} KOs.")
    a("")
    a("Voorstel: `BOSS_MULT` (HP ×3,0 / ATK ×1,34) laten. Verdieping 80 en 90 zitten in 60–90% winst; ze zijn duur (anderhalf tot twee KOs, vier items) maar binnen het doel. Alleen verdieping 20 zit eronder (58,0%). Eerste proef: na `boss_stats` de HP van verdieping 20 ×0,85, hermeten. De andere baasverdiepingen niet meeschalen.")
    a("")
    a("## Niet in deze meting")
    a("")
    a("- Action-gevechten (`--actionsim`, `--archief1balans`). Archief 1-gangen in Action hebben eigen schade- en cooldownfactoren.")
    a("- Mimics (blauwe kisten). Die zitten niet in de monstergroepen die de sim uit de kamers haalt.")
    a("- Codex-bondgenoten, vluchten, verdedigen, de `_nostun`-variant.")
    a("- WM2 en alles onder `wacht/`.")
    a("")

    text = "\n".join(L) + "\n"
    OUT.write_text(text)
    print(f"wrote {OUT} ({len(text)} bytes, {fights} fights)")


if __name__ == "__main__":
    main()
