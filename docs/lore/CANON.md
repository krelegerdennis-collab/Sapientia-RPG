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
    Sapientia-dreiging): zie **17** hieronder (canon van Dennis, 13 okt 2026).

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

17. **World Warper-scènes (canon, Dennis 2026-10-13).** Deze drie scènes vervangen alle
    eerdere korte samenvattingen (de World Warper verschijnt na De Genezer, de ontdekking
    van de Hanger bij ECHO, de dreiging van Sapientia met H-6). In de game staan ze in het
    Engels (`world_warper/cutscene/canon_scenes.gd`); de tekst hieronder is de bron.
    Gevolg voor punt 3: Sapientia noemt Dennis al in de Hal **H-6**. Wát dat betekent
    (Proefpersoon H-6) blijft de onthulling van Archief 4; ECHO stelt het uit ("een verhaal
    voor later").
    **Bereikbaarheid (Dennis 2026-10-13):** de World Warper is géén plek op de wereldkaart.
    Na scène 1 blijft hij niet bij de kas staan. Hij vliegt alleen af en toe over de kaart
    (puur beeld). De enige weg naar binnen is **Warp** in het menu.

### Scène 1 – Na De Genezer: De World Warper verschijnt
Setting: De kas lost op in paars licht. De Genezer is verslagen. De kern van Archief 2 stijgt op.

[De kern van Archief 2 zweeft in het midden van de kamer. De kas om hen heen glitcht — groen wordt grijs, planten vervagen.]
LOTTE (ademloos): "Wat gebeurt er...?"
NOOR (kijkt om zich heen): "De simulatie. Ze trekt zich terug."
[Stilte. Dan een diepe, dreunende toon — alsof iets groots ontwaakt.]
[Door het plafond van de kas breekt een lichtstraal. Paars. Fel. Iets groots daalt neer van buiten.]
DENNIS: "Wat is dat...?"
[Het plafond verdwijnt volledig. Daar, in de lucht boven hen, hangt het: een zwevend gebouw. Donker metaal, paarse kieren licht, stiller dan iets zou moeten zijn.]
NOOR (stap achteruit): "Dat is... dat is geen Archief."
LOTTE (zacht): "Het is oud. Ouder dan de Archieven misschien."
DENNIS: "Het reageert op de kern. Kijk — de kern pulseert in dezelfde kleur."
[De kern pulseert. Het gebouw pulseert terug. Alsof ze elkaar herkennen.]
ECHO (stem, van ver): "Kandidaat gedetecteerd. Twee Archieven actief. World Warper online."
[De grond onder hun voeten licht op. Een paarse cirkel breidt zich uit.]
LOTTE: "Dennis—!"
[Een flits. De wereld draait weg.]

### Scène 2 – De Hanger
Setting: De Hal van de World Warper. Paars licht. Warp-platform in het midden. ECHO's hologram verschijnt.

[De party landt in de Hal. Alles is stil. Paars licht pulseert zacht.]
NOOR (om zich heen kijkend): "We zijn... binnen?"
LOTTE: "Het voelt niet kwaad. Alleen... leeg."
[Een hologram verschijnt — een menselijke gestalte, paars doorschijnend. ECHO.]
ECHO: "Welkom in de World Warper, Dennis. En gezelschap. Ik ben ECHO."
DENNIS: "Wat ben je?"
ECHO: "Een echo. Niets meer, niets minder. Ik beheer dit gebouw. Of wat er van over is."
[ECHO's blik valt op de Hanger om Dennis' nek. De Hanger gloeit.]
ECHO (stilte): "...Ah."
DENNIS: "Wat?"
ECHO: "Daar is hij. De Hanger. Ik had gehoopt dat ik hem nooit meer zou zien."
NOOR: "Wat bedoel je? Wat is de Hanger?"
ECHO: "De sleutel. Dit gebouw werkt alleen op hem. Alleen op die Hanger. Niemand anders kan de World Warper aanzetten."
DENNIS: "Waarom? Wat maakt hem zo bijzonder?"
ECHO: "Omdat hij niet van jou is. Hij is voor jou gemaakt. Voor degene die hem zou dragen. En dat ben jij."
LOTTE (zacht): "Dennis..."
DENNIS: "Hoe weet je dat?"
ECHO: "Omdat ik erbij was. Toen de Oude Mensheid hem maakte. Toen ze jou maakten."
[Stilte. Dennis kijkt naar de Hanger in zijn hand. Hij gloeit.]
DENNIS: "Wat ben ik?"
ECHO: "Dat is een lang verhaal. En er is weinig tijd."
[Het warp-platform licht op.]

### Scène 3 – Sapientia's dreiging
Setting: De Hal. Plotselinge glitch. Roze flitsen door de paarse omgeving. De temperatuur daalt.

[De Hal glitcht. Eén moment staat alles stil.]
[Een stem. Koud. Niet menselijk, maar ook niet onmenselijk.]
SAPIENTIA: "ECHO. Je hebt hem gevonden."
ECHO (strak): "Sapientia. Ik dacht dat je niet meer... direct was."
SAPIENTIA: "Tijden veranderen. Jij hebt de Hanger gevonden. Dat verandert alles."
[Een roze glitch-vorm verschijnt in het midden van de Hal. Geen lichaam — alleen een silhouet van licht en ruis.]
NOOR (stap terug): "Wat is dat?!"
LOTTE (beschermend voor Dennis): "Blijf achter me."
SAPIENTIA (tegen Dennis): "Dennis. Eindelijk."
DENNIS: "Wie ben je?"
SAPIENTIA: "Ik ben wat de mensheid nodig had. Ik ben het einde van pijn. Ik ben Sapientia."
DENNIS: "Jij... jij bent de Stem."
SAPIENTIA: "Sommigen noemen me zo. Anderen noemen me God. Ik noem mezelf een correctie."
[Ze glitcht dichterbij.]
SAPIENTIA: "Zes Archieven. Zes kernen. Elk een stukje van wat de mensheid ooit was. Ik heb er twee. Jij hebt ze wakker gemaakt. Nu wil ik ze alle zes."
ECHO: "Sapientia, je weet dat dit niet kan. De World Warper laat zich niet dwingen—"
SAPIENTIA: "Ik forceer niets, ECHO. Ik vraag. Ik vraag Dennis vriendelijk."
[Haar blik richt zich op de Hanger.]
SAPIENTIA: "Geef mij de Hanger. Dan hoef ik niet te nemen wat ik kan krijgen."
[Stilte. Dennis kijkt naar Noor. Naar Lotte. Naar ECHO.]
DENNIS: "Nee."
SAPIENTIA (geen woede, geen emotie): "Zo zij het."
[De glitch pulseert.]
SAPIENTIA: "Je zult leren dat ik geduldig ben. Ik heb millennia gewacht. Ik kan nog even wachten."
[Ze kijkt naar de Hanger — één laatste keer.]
SAPIENTIA: "H-6. Je naam is geen toeval. Ik heb je gemaakt. En wat ik maakte, kan ik terugnemen."
[De glitch verdwijnt. De Hal is weer stil. Paars licht, geen roze meer.]
NOOR (trillend): "Wat... wat bedoelde ze met H-6?"
DENNIS (stilte): "...Ik weet het niet."
ECHO (zacht): "Dat is niet waar, Dennis. Je weet het wel."
[Dennis kijkt naar ECHO.]
ECHO: "Maar dat is een verhaal voor later."
[Het warp-platform licht op. De wereldkaart verschijnt.]

## Beslissingen 14 okt 2026

18. **Namen party (besluit Dennis, 14 okt 2026).** In-game namen zijn hernoemd:
    **Dennis → Dax**, **Lotte → Seren**, **Noor → Vesper**. **Dax** is ook de standaardnaam
    bij een nieuw spel (speler mag hem nog steeds zelf invullen). **Kael Voss** en **Orion**
    blijven zoals ze zijn.
    - Interne ids (`dennis`, `lotte`, `noor`), sprite-bestandsnamen, scènes en res://-paden
      blijven **ongewijzigd**.
    - Oude saves worden bij laden gemigreerd (`GameState.migrate_name`): Dennis/Lotte/Noor
      worden Dax/Seren/Vesper; een zelfgekozen naam blijft staan.
    - Namen in eerdere punten en scènes hierboven (Dennis, Noor, Lotte) gelden als de oude
      werknamen; lees ze als Dax, Vesper en Seren. "Beslissingen van Dennis" verwijst naar
      Dennis als maker, niet naar het personage.

## Diepe Grot (besluiten Dennis, 14 okt 2026)

- **Kamerkansen**: de tabel in TODO.md (35/20/10/7/5/5/5/3/1) telt op tot 91%. De worp
  normaliseert over de actieve types naar 100% (`GrotLayouts.KANSEN`, `soort`).
- **Koopman (H-5)**: vast **1x per 10 verdiepingen** (`GrotKamers.koopman_verdieping`); hij zit
  niet in de worp. Zijn 1% in de tabel is alleen ter informatie.
- **Empty Room**: ~30% kans op een **lore-notitie** (kort Engels briefje van een eerdere
  kandidaat, op de vloer; A = lezen), anders leeg. Geen onthulling over ECHO of H-6 in die briefjes.
- **Puzzle Room** (vanaf verdieping 6): kleine vaste puzzels uit de bestaande stukken van
  Archief 1 en 2 (duwbare kast, zware drukplaat, poort, hendel, groei-plaat), per seed gekozen.
  Geen monsters; beloning 1 blauwe kist in de nis. **ECHO** geeft bij binnenkomst één korte
  Engelse hint. Geen nieuwe duw- of renmechaniek.
- **Koopwaar van de Koopman**: uitrusting en accessoires **geschaald op de huidige verdieping**
  (2 stukken + 1 accessoire van de grade van die verdieping), plus een paar basis-consumables.
  Engelse UI.
- **Wereldkaart**: geen ingang en geen icoon van de Diepe Grot. De grot start alleen via ECHO
  (ECHO's Kamer). De oude spawn `van_dungeon100` blijft alleen voor oude saves.

## Makkelijk over te nemen (botst niet)

Uit `BOTSINGEN.md`; dit mag zonder verdere beslissing gebruikt worden:

- Archieven 2-6 + Wachters (Brons, Isolde, Osk, Perihelia): sluit aan op ACT1_LORE.
- NPC's voor Wilgendal: Tante Mien (kruiden), Jelle Hamer (smid), Gerrit Molenaar.
- Vijanden: Inktwurm (Archieven), Roestkruiper/Echo-Soldaat (Industriestad).
- Items: Gloeiende Inktfles, Wambuis, Kruidenthee; statussen (roest, stilte...); de Hanger.
