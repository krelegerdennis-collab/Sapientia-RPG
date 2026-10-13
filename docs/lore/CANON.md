# SAPIENTIA: CANON (beslissingen van Dennis)

*Vastgelegd 8 okt 2026 (v0.18). Dit document gaat boven het worldbuilder-materiaal in deze map
(`Lore_basis.md`, `Personages_Dossiers.md`, `Wereld_Geografie.md`, `Locaties_Dorpen.md`,
`Verhaal_Act2_tot_6.md`, `Dialoog_Samples.md`, `data/*.json`). Botst iets daarmee, dan geldt
wat hier staat. Wat hier niet staat: dan geldt wat er in de game staat (`scripts/data/*.gd`,
`README.md`, `docs/HANDOFF_*.md`). De achtergrond van elke keuze staat in `BOTSINGEN.md`.*

## Beslissingen

1. **Noor** is alleen een dorpsmeisje uit **Esdoorn**. Brandwijk en het weeshuis (Huize
   Zeldenrust) zijn geschrapt.
2. **De Oude Man** blijft zoals nu: naamloos, 'Opa', en hij leeft. Er komt geen **Ewout Valk**.
3. **Dennis** krijgt **de Hanger** (= **de Sleutel**) EN is **Proefpersoon H-6** uit
   **Archief 4**. Dat is een twist die later in het verhaal onthuld wordt.
4. **Noor en Lotte**: uiterlijk, leeftijd en klasse blijven zoals nu (Noor jong, kastanje
   paardenstaart; Lotte blond met vlecht, Priester). Geen 'Luisteraarster'.
5. **Plaatsen**: onze plaatsen blijven (**Wachtershuis, Esdoorn, Donker Woud, Wilgendal**).
   Lore-namen (**Stilwoud, Hazelbrug, Ruigveen**) zijn er alleen voor latere gebieden.
6. **Noor** sluit aan zoals nu: na **de Wortelkoning** in het Donker Woud. **Lottes** plek
   wordt later gekozen.
7. **De Golem** blijft **'Het Kennis-Beest'** (van boeken en code, roze kern, zwak voor vuur),
   met **'Kustos'** als eigennaam.
8. **Monsters van Archief 1**: de **Inktwurm** komt erbij (art nog nodig). De **Papiergeest**
   is de **Dwalende Pagina**. De **Mech. Wachter** blijft.
9. **Magie**: roze = **'de Stroom'** (reageert op gevoel). Glitch = de invloed van
   **Sapientia**: de **'Zwarte Stroom'**.
10. **Stats en levels**: onze stats (`atk/def/mag/mdef/agi`) en onze levelschaal blijven.
    Lore-data (`data/*.json`: aanval/verdediging/magie/...) komt alleen via een **converter**
    in de game, daarna herbalanceren.
11. **Namen**: onze item- en NPC-namen blijven (Kort zwaard, Vonkzwaard, Geneeskrachtig kruid,
    Oude Bram, ...). **Vonkkling** en **Bram Holt** krijgen een andere naam zodra ze ingebouwd
    worden. Nieuwe lore-items (**Gloeiende Inktfles, Kruidenthee, Wambuis** e.d.) mogen erbij.

## Beslissingen 13 okt 2026

Taalregel: tekst in de game is Engels; tekst in de documenten is Nederlands.

12. **Grot-handelaar = H-5.** Vorige proefpersoon, 2-3 jaar vóór Dennis. Haalde verdieping 100
    niet en zit vast in de simulatie. Is zijn naam vergeten en noemt zichzelf **"de Koopman"**
    (in-game EN: **"the Merchant"**). Drie fases:
    - bezoek 1-3: vaag en afstandelijk;
    - bezoek 4-7 (na de H-6-onthulling): herkent Dennis en vertelt fragmenten;
    - bezoek 8+ (of na Archief 5): vertelt de waarheid en geeft **"H-5's Token"**
      (+10% stats tegen dienaren van Sapientia).
    Einde (optie A): hij blijft voor altijd in de Grot. Bij de nederlaag van Sapientia
    (Archief 6) lost de simulatie op en verdwijnt H-5 glimlachend: "Dank je. Eindelijk rust."
    (EN: "Thank you. Finally, rest.")
13. **Vijanden van Archief 2** (allemaal element Natuur):

    | NL-naam | EN-naam (voorstel, Dennis beslist) | Zwak | Gedrag |
    |---|---|---|---|
    | Rankje | Tendril | Vuur | bindt speler, 1 beurt overslaan |
    | Sporekop | Sporehead | IJs | spuugt gif, 3 beurten |
    | Doornige Loper | Thorn Runner | Vuur/Bliksem | charge-aanval, verdubbelt schade |
    | Bloeiende Schrik | Blooming Dread | IJs | bijt + heelt zichzelf |
    | Wortelgeest | Rootghost | Vuur/Licht | trekt speler naar zich toe |

    Codex-vangbaar: **Sporekop** (als bondgenoot: vergiftigt vijanden), **Rankje** (bindt
    vijand, 1 beurt overslaan), **Wortelgeest** (trekt vijand + counter, als enige).
14. **World Warper-stijl: universeel**, met kleuraccent per Archief. Basis: paars licht,
    zwevend platform, hologram, hetzelfde icoon. Accenten: Archief 1 Kennis grijs+paars;
    2 Leven groen+paars; 3 Industrie oranje+paars; 4 Magie roze+paars; 5 Kosmos blauw+paars;
    6 Hart rood+paars. Cutscene-teksten (na De Genezer, eerste binnenkomst Hal,
    Sapientia-dreiging): *tekst volgt van Dennis*.

15. **5e party member: Kael Voss (WM2, psytech)**. **Kael Voss**, 19 jaar, is een
    psytech-dwaler uit **WM2**. Hij bestuurt **de Stroom** met zijn geest. Hij was
    **Proefpersoon K-7** in hetzelfde programma als **Dennis (H-6)**; **Sapientia**
    gebruikte hem als 'ontvanger' via een neurale kroon in zijn achterhoofd en keek
    door zijn ogen. Hij is ontsnapt, maar hoort haar stem nog als ruis. Hij vertrouwt
    alleen Dennis, die hij van vroeger herkent zonder te weten waarvan. Hij weet dingen
    over Dennis' verleden die **de Oude Man** verzwijgt, en brengt Sapientia's echte
    kant in het verhaal.
    - **Uiterlijk**: mager; zilvergrijs haar dat magenta glitcht bij slapen; gescheurde
      academische mantel over techsuit; gebarsten cyaan kroon-implantaat; drie zwevende
      prisma's (psyfocus).
    - **Rol**: psytech-caster, crowd control/debuffs; ruilt MP voor IP.
    - **Skills**: **Mindspike** (psychische schade, kans op Confuse); **Static Veil**
      (party-schild dat glitch absorbeert); **Overclock** (bondgenoot extra beurt, kost
      Kael HP); IP-skill **Sapientia's Echo** (glitch-schade op alle vijanden, daarna
      Kael zelf Confused).
    - **Joint**: in **WM2** (exact moment nog open).

16. **Party-regel**. Max **4 actieve helden** + **1 monster** (Codex-gevangen) in
    gevecht; overige helden in reserve, wisselbaar buiten gevecht. (Besluit Dennis
    2026-10-13.)

## Makkelijk over te nemen (botst niet)

Uit `BOTSINGEN.md`; dit mag zonder verdere beslissing gebruikt worden:

- Archieven 2-6 + Wachters (Brons, Isolde, Osk, Perihelia): sluit aan op ACT1_LORE.
- NPC's voor Wilgendal: Tante Mien (kruiden), Jelle Hamer (smid), Gerrit Molenaar.
- Vijanden: Inktwurm (Archieven), Roestkruiper/Echo-Soldaat (Industriestad).
- Items: Gloeiende Inktfles, Wambuis, Kruidenthee; statussen (roest, stilte...); de Hanger.
