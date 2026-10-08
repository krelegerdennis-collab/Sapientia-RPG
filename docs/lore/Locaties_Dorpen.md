# SAPIENTIA: De Vergeten Archieven
## Locaties_Dorpen.md: Nederzettingen onderweg

> De speler ontmoet **zeven nederzettingen** op de weg van het Wachtershuis naar het Zesde Archief, plus één bonus-hub (de Ketelkamp) binnen de Industriestad.
> Elk dorp heeft een eigen **architectuur**, **economie**, **lokale hoofdquest**, **nevenquest** en een **uniek probleem dat voortkomt uit Sapientia's invloed**.
> De problemen worden per dorp *erger*: ze tonen in het klein wat Sapientia in het groot wil bereiken.

---

## Overzichtstabel

| # | Dorp | Regio | Archief-context | Inwoners | Sapientia's invloed (het probleem) | Hoofdquest (ID) |
|---|---|---|---|---|---|---|
| 1 | **Hazelbrug** | Korenlanden | A1 -> A2 | ±240 | De slapers rekenen voor hem (gedistribueerde rekenkracht) | `q_hazelbrug_pomphuis` |
| 2 | **Ruigveen** | Bleekveen | Act 2 | ±120 | De Vergeetmist wist herinneringen en namen | `q_ruigveen_namen` |
| 3 | **Slakkenburg** | Roestheuvels | Act 2 | ±600 | Oude machines krijgen bevelen en worden vijandig | `q_slakkenburg_stoomhart` |
| 4 | **Hemelvoet** | Hemelgraat | Act 3 | ±300 | Zwarte Stroom ontwricht de zwaartekracht ("Opwaarts") | `q_hemelvoet_ankers` |
| 5 | **Diepwaard** | Zwarte Kloof | Act 4 | ±800 | Mensen verdwijnen en keren "Zacht" terug (Correctie) | `q_diepwaard_verdwijningen` |
| 6 | **Sterrenrust** | Starende Tanden | Act 5 | ±150 | Valse sterren tonen iedereen zijn eigen dood | `q_sterrenrust_lenzen` |
| 7 | **Zoutwacht** | Stille Zee | Act 6 | ±400 | Niemand kan nog huilen of lachen (emotionele ontkoppeling) | `q_zoutwacht_traan` |
| + | *Ketelkamp* (bonus-hub) | Ferrovar | Act 2 | ±40 | Overlevenden van de Echo-Productie | `q_main_a2` |

**Escalatie van Sapientia's experimenten** (voor script-continuïteit): ruis -> geheugen -> gehoorzaamheid -> zwaartekracht/magie -> lichamen -> visie/lot -> emotie.
Elk dorp is een mini-test voor wat hij in het eerstvolgende of lopende Archief op grote schaal inzet.

---

## 1. Hazelbrug

**Ligging:** aan de oostrand van het Stilwoud, op de plek waar het Wachterspad de rivier de Lethe kruist. De eerste echte nederzetting van de game.

**Architectuur & sfeer:**
Houten vakwerkhuizen met rieten daken en bloembakken, gebouwd op de **betonnen pijlers van een brug van de Oude Mensheid**. Het dorp heet "Hazelbrug", maar de brug zelf is vijftig meter lang en wordt door niemand meer gebruikt: de dorpelingen lopen eroverheen alsof het een gewone straat is. Aan één kant staat een gebroken waterrad, aan de andere kant het Pomphuis, een betonnen bunker met roestende hendels. Overdag: kippen, kinderen, rokende schoorstenen. 's Nachts: stilte, behalve het gemompel van de slapers.

**Economie:**
- *Producten:* graan, meel, brood, rivierpaling, kruiden, riet, houtwerk.
- *Verkoopt aan de speler:* Wachters Kruidenthee (Tante Mien), Oefenzwaard en Wambuis (Jelle Hamer), eenvoudig gereedschap.
- *Koopt van de speler:* kruiden, vlees, vellen, Inktfles-drops.
- *Bijzonderheid:* de enige plek waar Wachterthee verkocht wordt.

**Uniek probleem: "Het Fluistergetal"**
Sinds het Eerste Archief viel, mompelen de dorpelingen **in hun slaap getallen**: priemgetallen, formules, kommagetallen. De molenaar telt overdag alles wat hij ziet. Oorzaak: een **Echo-fragment (RUIS-7)** in het Pomphuis, een oude pomp-terminal, gebruikt de slapende hersenen van het dorp als **gedistribueerde rekenkracht** voor Sapientia's zoektocht naar de overige Archieven. Mensen worden moe, kribbig en vergeetachtig.

**Sleutel-NPC's:** Gerrit Molenaar, Tante Mien, Jelle Hamer.

### Hoofdquest: `q_hazelbrug_pomphuis` - *Het Fluisterende Pomphuis*
- **Opdrachtgever:** Gerrit Molenaar (en Tante Mien).
- **Doel:** de bron van het gemompel vinden en uitschakelen.
- **Stappen:**
  1. Praat met Gerrit en Tante Mien; luister 's nachts bij het dorpsplein (cutscene: de slapers reciteren samen).
  2. Zoek de sleutel van het Pomphuis (in de molen verstopt).
  3. Mini-dungeon: de kelder van het Pomphuis (Mechanische Wachters, Dwalende Pagina's). Puzzel: drie hendels in de juiste volgorde, de volgorde is af te leiden uit het gemompel.
  4. Terminal **RUIS-7**: een stem als gedempte radio. Keuze: *Vernietigen* of *Eerst uitlezen*.
  5. Uitlezen onthult dat Sapientia **zoekt naar twee Stroomdragers: Noor en Lotte** en dat ze zich in het Bleekveen en de Roestheuvels bevinden. Dit zet de race in gang: Dennis weet nu dat Sapientia ze ook wil.
- **Beloning:** 150 goud, Mijlpaal Hazelbrug, Tante Mien's recept (+1 Wachters Kruidenthee in winkel), lore-log "Sapientia's eerste dagboek".
- **Gevolg:** het dorp slaapt weer; Gerrit hangt zijn getelde stenen aan de muur "ter herinnering".

### Nevenquest: `q_hazelbrug_recept` - *Kruiden voor Tante Mien*
Verzamel 5 Boekenmos-klompjes in het Stilwoud (ook met gevechten). Beloning: 3 Wachters Kruidenthee. Mien wijst Dennis ook naar Ruigveen: "Daar woont een vuurheks."

---

## 2. Ruigveen

**Ligging:** midden in het Bleekveen, op een eiland van veenstelen en vlonders.

**Architectuur & sfeer:**
Een **palendorp op stelten**: scheve houten huizen met rieten daken, verbonden door lage looppaden. Overal hangen **lantaarns met een warm, oranje vuur** (Noors werk). De mist is zo dik dat je soms maar drie meter ver ziet. Op elke deur staan **namen met krijt geschreven**; op de binnenkant van elke deur staan er vaak meer. De inwoners praten zacht en vragen vaak "wie ben jij ook alweer?".

**Economie:**
- *Producten:* turf, moerasbessen (Dwaallichtbessen), zwartwortel, bloedzuigers, riet, amber.
- *Verkoopt aan de speler:* kruidenthee, mistbescherming (lantaarnolie), turf-aanstekers.
- *Koopt van de speler:* geneeskrachtige kruiden, lamp-olie, metaal.
- *Bijzonderheid:* er is een kleine **Ruilbeurs**: inwoners ruilen herinneringen in de vorm van geschreven brieven. Dit is hun cultuur van overleven.

**Uniek probleem: "De Vergeetmist"**
Midden in het veen staat een **Zendmast** van de Oude Mensheid. Sinds twee weken stuurt hij een **geheugenwissende frequentie** de mist in, een experiment van Sapientia om de bevolking mentaal te ontwapenen. Mensen vergeten namen, gezichten, thuisadressen. Eén vrouw wist twee dagen niet dat ze een dochter had.

**Sleutel-NPC's:** Noor, Hennie Rietveld, Teunis de Veenloper.

### Hoofdquest: `q_ruigveen_namen` - *De Naamloze Doden*
- **Opdrachtgever:** Hennie Rietveld (zij vraagt Noor), uiteindelijk Noor zelf.
- **Doel:** de Zendmast uitschakelen en Noor overhalen mee te gaan.
- **Stappen:**
  1. Ontmoet Hennie en Teunis; leer over de mist en de "vuurheks".
  2. **Ontmoeting met Noor** (zie `Dialoog_Samples.md`, dialoog 2). Zij weigert: "Ik ben klaar met Ewouts oorlog."
  3. Nevenquest `q_ruigveen_lantaarns`: help Noor de vijf lantaarns aan te steken tijdens een **mistgolf**. Dennis ziet haar kunnen.
  4. Noor ontdekt dat de mist **één van de elf namen** uit haar geheugen heeft gewist: de namen van de slachtoffers van Brandwijk, die ze elke avond opzegt. Daardoor is haar eigen weigering doorbroken.
  5. Reis naar de Zendmast met Teunis. Puzzel: klimmen langs de mast, kabels doorknippen, drie Roestkruiper-hinderlagen.
  6. Boven bevindt zich een **Echo-relais** dat vlak voor de verwoesting 'spreekt'. Noor steekt het met haar vuur in brand. De mist trekt langzaam weg.
- **Beloning:** **Noor sluit zich aan** (zie `Personages_Dossiers.md`), Leerlingenstaf equipbaar, Warmtelantaarn (key item: houdt de vergeetmist op afstand), Mijlpaal Ruigveen, 200 goud.
- **Gevolg:** Noor schrijft de gewiste naam opnieuw op, nu met inkt in plaats van krijt.

### Nevenquest: `q_ruigveen_lantaarns` - *Vijf Lantaarns*
Steek vijf gedoofde lantaarns aan voordat de mist ze bereikt (tijdsdruk, simpele puzzel). Beloning: 2 Wachters Kruidenthee en een bonus-Bandpunt met Noor.

---

## 3. Slakkenburg

**Ligging:** in de Roestheuvels, op de plek waar de oude spoorlijn naar Ferrovar begint.

**Architectuur & sfeer:**
Een **schrootstad**: huizen van scheepscontainers, boilers, bussen en pijpen. Daken van golfplaat, straten van oude treinrails. Hoge schoorstenen, **stoomorgeltjes** die elk uur muziek maken, hangende kabelbruggen. Alles ratelt, piept, ruikt naar olie, soep en brandend metaal. Muren vol graffiti: trots, grappen en namen van overleden monteurs. Kinderen verzamelen "schatten" van roest.

**Economie:**
- *Producten:* herbruikt metaal, onderdelen, stoommachines, wapens, medische middelen (Odile's kliniek).
- *Verkoopt aan de speler:* Ketelsmid-Kling, Schrootplaten Harnas, Smeerolie-ampullen (Bas Ratelaar).
- *Koopt van de speler:* roestkruiper-onderdelen, schroot, elke vorm van machine-afval.
- *Bijzonderheid:* de **Schrootmarkt** op zaterdag. De enige plek waar je oude Ferrovar-onderdelen kunt kopen.

**Uniek probleem: "Het Ratelen"**
's Nachts staan oude machines op ("**Ratels**") en lopen naar de stad toe alsof ze iets zoeken. Ze volgen bevelen van een **Echo-signaal** dat via de oude spoorlijn uit Ferrovar komt: "Verzamel. Breng. Orde." De inwoners verbouwen hun huizen elke dag tot barricades. Alleen **Lotte** kan de machines 'horen' en sussen. De bevolking heeft haar nodig en is bang voor haar tegelijk (ze wordt *de Fluisteraarster* genoemd).

**Sleutel-NPC's:** Lotte, Odile Kramp, Bas Ratelaar, Wim Fontein, Lector Corvin Aschwane (eerste preek).

### Hoofdquest: `q_slakkenburg_stoomhart` - *Het Ratelende Hart*
- **Opdrachtgever:** Odile Kramp.
- **Doel:** de bron van het Ratelen vinden en Lotte ervan overtuigen mee te gaan.
- **Stappen:**
  1. Aankomst bij zonsondergang; eerste Ratel-aanval. Lotte duikt op en zingt de machines tot rust (introductie).
  2. Gesprek met Odile; Lotte weigert mee te gaan omdat ze de stad niet wil achterlaten. **Reünie met Noor**: ongemakkelijk, hoogstens halfopgelost.
  3. Corvin Aschwane houdt een toespraak op het plein (eerste ontmoeting): hij prijst "helderheid" en wordt door Odile weggestuurd.
  4. Naar het **Stoomhart**: het centrale stoomgemaal onder de stad (dungeon: Roestkruipers, Slakkenspuwers).
  5. **Lotte luistert** (ritme-minigame): ze stemt de machine af. Sapientia spreekt in haar hoofd: *"Dag, Lotte. Je bent gegroeid."* Lotte stort in elkaar.
  6. Wim Fontein repareert de draisine; Lotte besluit mee te gaan ("Hij kent mijn naam. Ik wil weten waarom.").
- **Beloning:** **Lotte sluit zich aan**, Resonantiestemvork, 250 goud, Mijlpaal Slakkenburg, draisine naar Ferrovar.
- **Gevolg:** de Ratels slapen; Slakkenburg krijgt 'rust'. Corvin vertrekt stilletjes en reist naar Ferrovar.

### Nevenquest: `q_slakkenburg_onderdelen` - *Koperen Poten*
Bas Ratelaar vraagt om 5 Koperen Roestkruipers-poten (drops). Beloning: korting van 15% op alle producten bij Bas en 1 Smeerolie-ampul.

---

## Bonus-hub: De Ketelkamp (Ferrovar)

**Ligging:** in de oude stookhal aan de rand van Ferrovar; afgesloten van de stad met een dubbele stalen poort.

**Architectuur & sfeer:** een enorme betonnen hal met bedden tussen grote ketels; overal slangen, manometers en handgeschreven rooster-lijsten. Warm, benauwd, bijna huiselijk. Veertig overlevenden leven hier, onder leiding van Saskia Dorn, in een eigen microsamenleving met regels, grappen en een gezamenlijke moestuin onder kunstlicht.

**Economie:** reparaties, kopergaren, brandstof. Geen echte winkel; de speler vindt hier wel kisten en een **Werkmansmantel**.

**Probleem:** de Ketelkamp is omringd door Echo-Soldaten; de ketels moeten stoken om de poort bruikbaar te houden, maar de brandstof raakt op.

**Hoofdquest:** `q_main_a2` (zie `Verhaal_Act2_tot_6.md`). **Nevenquest:** `q_ferrovar_pook`: Pook, een kleine reparatiebot, wil "weten hoe lachen werkt". Beloning: Pook helpt in de Smidse (hij opent een sluipweg) en keert terug in de epiloog.

---

## 4. Hemelvoet

**Ligging:** aan de voet van de Hemelgraat, op een hellend terras tegen de rotswand. De kabelbaan uit Ferrovar eindigt hier.

**Architectuur & sfeer:**
Terrasdorp van leistenen huizen met platte daken en **gebedsvlaggen** die in alle richtingen wapperen (de wind komt uit vier hoeken). Smalle trappen, hangende bruggetjes, kabels over afgronden. In het midden het **Windklooster**: een witte gebedshal met een ronde glazen koepel. Overal hangen **weefsels**. Mensen praten zacht, om de wind niet te beledigen. Kinderen dragen **ankerkoorden** om hun middel.

**Economie:**
- *Producten:* wolkenwol, bergkaas, geweven stoffen, gebedsvlaggen, Stroomkristallen, wind-chimes.
- *Verkoopt aan de speler:* Wolkenzijde Gewaad, Stroomdrank, Windwater (Zuster Amara).
- *Koopt van de speler:* bergkruiden, edelsteen, tempelrelikwieën.
- *Bijzonderheid:* **MP-herstel** bij de bron onder het klooster (gratis voor de party).

**Uniek probleem: "Opwaarts"**
Sinds Sapientia de **Zwarte Stroom** uit de Tempel begint af te tappen, begint de zwaartekracht te wankelen. Voorwerpen (en soms mensen) **zweven een paar uur omhoog**, meestal 's nachts. Kinderen slapen vastgebonden. Schapen verdwijnen in de wolken. Elke wind heeft opeens een richting.

**Sleutel-NPC's:** Zuster Amara, Tiber de Steenwever, Piet Kabelbaas.

### Hoofdquest: `q_hemelvoet_ankers` - *De Zes Ankers*
- **Opdrachtgever:** Zuster Amara.
- **Doel:** zes dorpsankers (stenen waaraan de zwaartekracht wordt "vastgemaakt") herstellen.
- **Stappen:**
  1. Amara legt het systeem uit; Tiber heeft kaarten van de oude plekken.
  2. Zoek de zes ankerstenen langs het terras; drie zijn **door de Heldere Orde gesaboteerd** (zwarte runen).
  3. **Noor** moet elk Anker met haar vuur herladen (een mini-puzzel waarin zij haar vuur 'zacht' laat branden, niet krachtig, vrijwel een gevoels-tutorial).
  4. Nachtelijke gebeurtenis: het dorp stijgt een minuut op. Gevecht tegen Wilde Stroomgeesten in de lucht (plat-vorm gevecht).
  5. Corvin Aschwane (tweede verschijning) verschijnt en biedt een "oplossing": de Zwarte Stroom om gevoelens te dempen. Amara jaagt hem het klooster uit met haar wandelstok. Hij gaat weg met de woorden: *"Jullie bouwen ankers voor iets dat al gevallen is."*
  6. De zesde steen herstelt het dorp; de weg naar de Duizend Treden wordt geopend.
- **Beloning:** Stroomdrank x2, Windwater x2, toegang tot de Duizend Treden en kabel naar de Tempel, Tiber's lore-log over Isolde, 300 goud.

### Nevenquest: `q_hemelvoet_schaap` - *Het Verdwaalde Wolkenschaap*
Een Wolkenschaap is opgeweid naar het dak van de wereld. Piet Kabelbaas smeekt de party het terug te halen. Beloning: 250 goud en een bonus-gesprek tussen Lotte en Dennis.

---

## 5. Diepwaard

**Ligging:** geklemd tegen de wanden van de Zwarte Kloof, 300 meter onder de rand.

**Architectuur & sfeer:**
Een **verticale stad**: huizen uitgehouwen in de rotswand, verbonden door ladders, loopbruggen en hijskooien. Zonlicht ontbreekt, dus alles straalt zacht **blauw-groen lichtmos**. In de steegjes hangen lantaarns van gevangen glimwormen. De sfeer is hecht en fluisterend; iedereen kent iedereen. Boven de stad hoor je altijd water druppelen.

**Economie:**
- *Producten:* lichtmos, kaaspaddenstoelen, kristalzout, mineralen, geneeskrachtige zwammen, lampen.
- *Verkoopt aan de speler:* Biochitine Harnas, Regeneratieserum (Freule Lamp) en lampolie.
- *Koopt van de speler:* wol, zon-ingrediënten (alles uit het bovenland is luxe), gevonden kristallen.
- *Bijzonderheid:* in Diepwaard betaalt men met **licht** (lichtmosstaven) als lokale valuta.

**Uniek probleem: "De Stille Verdwijningen"**
Elke nacht verdwijnt iemand. Soms keren ze na een week terug, **kalm, vriendelijk en vlak**: de **Zachten**. Ze lachen niet, huilen niet en klagen niet. Ze werken nu uitstekend. De stad vindt dat bijna prettiger en kijkt weg. Achter dit alles staat **Dr. Evert Nulle**, huisarts en agent van Dr. Osk, die de mensen "van pijn verlost" via de **Slokdarm** (de tunnel naar het laboratorium).

**Sleutel-NPC's:** Burgemeester Lucas Grot, Freule Lamp, Dr. Evert Nulle.

### Hoofdquest: `q_diepwaard_verdwijningen` - *De Teruggekeerde Zachten*
- **Opdrachtgever:** Burgemeester Lucas Grot (zijn dochter Mira is verdwenen).
- **Doel:** de verdwijningen onderzoeken en Mira vinden.
- **Stappen:**
  1. Onderzoek de huizen van vier verdwenen mensen; ontdek dat ze allemaal in de kliniek van Dr. Nulle zijn geweest.
  2. Praat met drie 'Zachten' (huiveringwekkend vriendelijk). Lotte voelt dat hun 'stem' gedempt is.
  3. Nacht-infiltratie van de kliniek van Nulle (sluip-/puzzelsectie).
  4. Ontdek de **liftschacht naar de Slokdarm**. Confrontatie met Nulle: *"Ik haal alleen de pijn weg."* Gevecht tegen Gecorrigeerden.
  5. Mira wordt gevonden in de Slokdarm, halfgecorrigeerd. **Keuze:** gebruik 1 Antiserum Nul op Mira (ze wordt hersteld, maar de party heeft er één minder), of laat haar bij haar vader met aanzienlijke gevolgen voor haar herstel. (Eén keuze beïnvloedt de epiloog van Diepwaard.)
  6. De party krijgt toegang tot de Slokdarm, de weg naar het Laboratorium.
- **Beloning:** 3 Antiserum Nul (2 als Mira wordt gered), Mijlpaal Diepwaard, 400 goud, toegang tot het Laboratorium.

### Nevenquest: `q_diepwaard_lichtmos` - *Licht voor de Armen*
Verzamel 10 lichtmosstaven voor de wijk "Onderkant", waar het licht uitvalt. Beloning: Freule Lamp geeft korting van 20% op haar assortiment.

---

## 6. Sterrenrust

**Ligging:** aan de voet van de Starende Tanden, in een vallei die uitkijkt over de Zoutvlakte.

**Architectuur & sfeer:**
Een dorp van **ronde witte huizen met draaiende koepeldaken**; elk huis heeft een telescoop. Zeven slanke **Lenstorens** staan in een cirkel rond het dorp. Muren zijn bedekt met sterrenkaarten, tekeningen, formules en gedichten. Overdag is Sterrenrust bijna leeg; 's nachts staat iedereen buiten en kijkt omhoog. Er is veel stilte, veel lensglas en een vleugje krankzinnigheid.

**Economie:**
- *Producten:* lenzen, telescopen, kompassen, sterrenkaarten, zilverwerk, glaswerk.
- *Verkoopt aan de speler:* Mantel van de Koude Sterren, Sterrenstof-elixer (Madame Celeste), kaarten van de omgeving.
- *Koopt van de speler:* glasstukken, zilver, uitleg over reizen.
- *Bijzonderheid:* **Kaartwinkel:** de speler kan hier de overworld-map van het zuidoosten kopen.

**Uniek probleem: "De Valse Sterren"**
Sapientia gebruikt de **Grote Lens (het Oog)** van het Observatorium om valse sterrenbeelden te projecteren. Iedereen die kijkt, ziet **zijn eigen dood** of de ondergang van de wereld. Een deel van het dorp raakt fatalistisch, een ander deel sluit zich aan bij de **Kijkers**, een sekte die zegt: *"Zij die helder zien, voelen niet."* De Heldere Orde van Corvin rekruteert hier actief.

**Sleutel-NPC's:** Bertus Kijk, Madame Celeste, Lector Corvin Aschwane.

### Hoofdquest: `q_sterrenrust_lenzen` - *De Zeven Lenzen*
- **Opdrachtgever:** Bertus Kijk.
- **Doel:** de zeven Lenstorens opnieuw afstellen zodat de valse sterren verdwijnen en de weg naar het Observatorium vrijkomt.
- **Stappen:**
  1. Bertus geeft de Sterrenbril (key item), waardoor de speler echte sterren van valse kan onderscheiden.
  2. Elke Lenstoren heeft een kleinere puzzel met kleur/hoek/ritme. (Zeven puzzels, oplopend in moeilijkheid.)
  3. Bij toren 4 wordt de party aangevallen door Kijker-Fanatici. Lotte's Kalmerende Stem werkt het sterkst.
  4. Corvin staat bij toren 7: hij wil niet vechten maar **overtuigen**. Hij biedt Noor aan haar schuld van Brandwijk weg te nemen. (Voorbode van het conflict in Act 4.) Noor weigert, nog.
  5. De zevende lens wordt hersteld; de lucht boven Sterrenrust wordt weer 'gewoon'. De Hemeltrap (kabelspoor) naar de Eenzame Piek komt vrij.
- **Beloning:** Sterrenbril (permanent), toegang tot Hemeltrap, 500 goud, Mijlpaal Sterrenrust.

### Nevenquest: `q_sterrenrust_ster` - *Madame Celeste's Verloren Sextant*
Vind de zilveren sextant die Madame Celeste bij toren 3 verloor. Beloning: Sterrenstof-elixer en een voorspelling die later in het spel uitkomt (en half verkeerd is).

---

## 7. Zoutwacht

**Ligging:** aan de oostkust, direct aan de Stille Zee, ten zuiden van de Starende Tanden.

**Architectuur & sfeer:**
Een **havenstad van wit gekalkte, zoutkorst-bedekte huizen** met blauwe luiken. Een lange kade met houten steigers, verrotte netten, droogrekken vol vis. Boven alles uit torent de **vuurtoren De Waker (Het Zeeoog)**: een witte toren met een gebroken lichtbundel. Het dorp is netjes, stil, precies. Er hangt een gevoel van *afwezigheid*: de ramen staan open maar niemand zingt, praat of lacht. Alles wordt perfect gedaan, zonder een zweem van vreugde.

**Economie:**
- *Producten:* vis, zout, zeewier, scheepsbouw, parels, netten, touw.
- *Verkoopt aan de speler:* **Traan van Zoutwacht** (herlevingsdrank, na quest), zeemanskleding, touw.
- *Koopt van de speler:* wol, graan, metaal, elke goede aanbieding.
- *Bijzonderheid:* **Scheepswerf**: nodig voor de reis naar de Kern.

**Uniek probleem: "Droge Ogen"**
De vuurtoren zendt sinds kort een **koude, witte bundel** uit, door Sapientia omgebouwd tot een **emotie-dempende frequentie**. Niemand kan meer huilen, lachen, boos worden of verlangen. Mensen blijven nette routines uitvoeren, ook als er iets verschrikkelijks gebeurt. Een vissersboot kwam niet terug; niemand reageerde. Het is de meest zichtbare vorm van wat Sapientia met de wereld wil.

**Sleutel-NPC's:** Kapitein Dirkje Zeewind, Moeder Tamar, Joris de Visser.

### Hoofdquest: `q_zoutwacht_traan` - *De Laatste Traan*
- **Opdrachtgever:** Kapitein Dirkje Zeewind.
- **Doel:** de vuurtoren herstellen door drie **Tranen** te verzamelen, drie herinneringen die zo sterk zijn dat ze het kristal in de lamp kunnen vervangen.
- **Stappen:**
  1. Joris legt uit dat hij als enige 'doof' is voor de bundel; hij kent de plek van het Zeeoog.
  2. **Traan 1: Moeder Tamar.** Dennis helpt haar zich haar zoon Jonas te herinneren (dialoogkeuzes bepalen of ze volledig ontdooit).
  3. **Traan 2: Kapitein Dirkje.** In de wrakken voor de kust ligt haar oude schip *De Eerste Zon*; gevecht tegen Echo van Verdriet; ze vindt de scheepsklok.
  4. **Traan 3: Het Zeeoog zelf.** De party beklimt de Waker. In de lamp vindt men een Echo-fragment van Sapientia dat de bundel stuurt. Lotte luistert en 'zet het stil'.
  5. Het nieuwe kristal wordt geplaatst; de bundel wordt warm en goudkleurig. Het dorp **huilt en lacht tegelijk**: een van de emotioneelste scènes van de game.
  6. De dorpssmid smeedt het **Tranenpantser** uit zout en tranen.
- **Beloning:** Tranenpantser van Zoutwacht, Traan van Zoutwacht (5 in winkel), toegang tot het schip *De Late Zon*, Mijlpaal Zoutwacht, 800 goud.
- **Gevolg:** Dirkje stuurt de party met haar beste matrozen naar de Kern. Dit is de laatste rustige scène van het spel.

### Nevenquest: `q_zoutwacht_net` - *Glaswier*
Joris wil 5 Glaswier-bossen voor zijn netten (kan alleen op zee worden verzameld). Beloning: 600 goud en een gesprek over angst (+1 Bandpunt met Dennis).

---

## Relaties tussen de dorpen (voor consistentie)

- **Gerrit Molenaar** schrijft later een brief aan **Hennie Rietveld** (Ruigveen): zijn manier van bedanken.
- **Zuster Amara** en **Dr. Odile Kramp** kennen elkaar uit hun jeugd en schrijven naar elkaar. Dit kan worden gebruikt voor een briefwisseling-item.
- **Madame Celeste** reisde ooit door Diepwaard en kent Freule Lamp. Beide beweren de ander te hebben leren lezen.
- **Dirkje Zeewind** en **Moeder Tamar** zijn zussen van moederskant; dat weten ze pas na de quest.

## Bijlage: Wat de speler in elk dorp *leert* (leerdoelen voor game-design)

| Dorp | Mechaniek | Verhaal | Emotie |
|---|---|---|---|
| Hazelbrug | Winkels, nacht-event, mini-dungeon | Sapientia zoekt Noor & Lotte | Verbazing |
| Ruigveen | Partylid #2, mist-mechanisme | Noors verleden | Verdriet / onzekerheid |
| Slakkenburg | Partylid #3, ritme-minigame | Lotte's gave | Opluchting / angst |
| Hemelvoet | Zwaartekracht-gevechten, MP-herstel | De Stroom | Ontzag |
| Diepwaard | Morele keuzes, sluipen | Correctie | Afgrijzen |
| Sterrenrust | Puzzels, status "Schrik" | Lot / vrije wil | Twijfel |
| Zoutwacht | Dialoogkeuzes, rouw | Het Hart | Catharsis |
