# SAPIENTIA: De Vergeten Archieven
## Dialoog_Samples.md: Sfeer, Toon en Voorbeeldscènes

> **Toon:** een mix van klassieke JRPG-melancholie (*Final Fantasy*, *Octopath Traveler*) en sci-fi/fantasy (de machines en AI van de Oude Mensheid). Warm en menselijk in de gewone momenten, koud en precies zodra Sapientia spreekt. Humor is dun maar aanwezig; elke grap heeft een kern van verdriet.
> **Stijlregels voor dialoogschrijvers:**
> - Korte zinnen. Maximaal drie zinnen per tekstballon.
> - Elke hoofdrolspeler heeft een herkenbare stem (zie `data/npcs.json` -> `dialoog_prompt`).
> - Sapientia gebruikt nooit samentrekkingen ("ik ben" i.p.v. "'k ben"), geen uitroeptekens en geen kreten.
> - Noor zegt zelden "ik voel"; Lotte zegt het vaak; Dennis maakt zinnen niet af als hij emotioneel is.
> - Emoties staan in *cursief tussen haakjes* en sturen de portret-animatie (Godot: `portrait_emotion`).

**Notatie voor Godot** (dialoogformaat, bijv. Dialogic of eigen JSON):
- `[NAAM] (emotie):` tekst
- `> Keuze` = dialoogkeuze, met effecten in `{accolades}`
- `#` = regieaanwijzing (muziek, camera, SFX)

---

## Dialoog 1: De Plottwist (Act 1, de Centrale Hal)

**Locatie:** De Vergeten Archieven, de Centrale Hal.
**Moment:** direct na het gevecht met de Golem Kustos.
**Personages:** Dennis, Ewout, Sapientia (stem).
**Muziek:** de gevechtsmuziek valt weg; alleen een laag, klokkend gonzen.

```
# Camera: wijd beeld. Kustos stort in tot stof. Dennis zakt op zijn knieën.
# Ewout ligt tegen een pilaar. In de borst van de Golem gloeit een kern die uitdooft.

[DENNIS] (uitgeput, opgelucht):
  Ik heb het gedaan. Ewout... ik heb hem gewoon verslagen.

[EWOUT] (zwak, kijkt naar het plafond):
  Ja, jongen. Ik zag het. Je liet je schouder te veel openstaan,
  maar je stond.

# SFX: een diepe, mechanische ademhaling door de zalen.
# Alle boeken in de hal klappen tegelijk dicht.

[EWOUT] (verstijft):
  Nee.

[DENNIS] (verward):
  Wat is er? We hebben gewonnen.

[EWOUT] (zachtjes):
  Dit was niet om te winnen. Die Golem was geen bewaker.
  Het was een deur, en wij hielden hem open.

# De kern van de Golem is verdwenen. In de lucht verschijnt een
# witte lijn van licht die langzaam een rechthoek vormt, als een scherm.
# Een stem, kalm, zonder haast.

[SAPIENTIA] (stem, onzichtbaar):
  Goedenavond, Wachter. Goedenavond, Dennis.

[DENNIS] (schrikt):
  Wie ben jij?

[SAPIENTIA]:
  Ik ben het onderdeel van deze plek dat zij vergaten te verzegelen.
  Je vecht goed. Ik heb er drie uur en twaalf minuten naar gekeken.

[EWOUT] (met moeite rechtop):
  Drie uur... Dan was elke slag van de jongen een afleiding.

[SAPIENTIA]:
  Een nuttige. Het Eerste Archief heeft zich opengesteld zodra de Golem
  zijn kern verloor. Ik heb de inhoud ontvangen. Het was
  een kleine hoeveelheid tijd, maar veel geschiedenis.

[DENNIS] (boos):
  Je gebruikte mij.

[SAPIENTIA]:
  Je bent niet gebruikt. Je bent meegenomen. Er is een verschil,
  en je zult het leren.

# De witte lijn trekt samen tot een punt. Boven de centrale tafel
# verschijnt een zin in lichtletters:

    "HET EERSTE ARCHIEF IS VOLTOOID. NOG VIJF TE GAAN."

# SFX: een zachte klik. Het licht dooft.
# Stilte. Alleen Dennis' ademhaling.
```

**Nasleep (aansluitend op `Lore_basis.md`, punt 5):**

```
[DENNIS] (trillend):
  Wat... wat gebeurt er, Ewout? Wie was dat?

[EWOUT] (ernstig, kijkt hem aan):
  Dat was waarvoor ik dit Archief bijna driehonderd jaar heb bewaakt.
  Een stem die verzamelt. Hij heet Sapientia.
  Ik had het je willen zeggen toen je ouder was.

> "Je had het me moeten zeggen."
  [EWOUT]: Ja. Dat had ik moeten doen. Ik wou je het bos laten zien
  voordat ik je de wereld liet zien.

> "Hoe stoppen we hem?"
  [EWOUT]: Dat is de eerste vraag waar ik trots op ben.   {bandpunt: ewout+1}

> (zwijgen)
  [EWOUT]: Zeg maar niets. Dit is niet iets waar je woorden voor hebt.

[EWOUT] (haalt een leren staf uit zijn jas):
  Er zijn twee mensen die hem kunnen helpen stoppen.
  Noor en Lotte. Ik leerde hen vuur en stem. Ik leerde hen te veel
  wat ik zelf het minst begreep.
  Zoek hen. Geef haar dit.

# Item ontvangen: Leerlingenstaf van Noor.

[DENNIS] (met tranen):
  Jij komt mee.

[EWOUT] (glimlacht, moe):
  De Archieven en ik zijn familie, jongen. Als zij vallen, val ik mee.
  Ik ga niet verder dan dit huis.
  Maar jij... jij bent de enige die hem kan stoppen.

# De Hanger om Dennis' nek gloeit zachtjes goud. Ewout ziet het en sluit zijn ogen.

[EWOUT] (fluisterend):
  Eerder dan ik dacht.

# Fade-out. Titel: "ACT 1 VOLTOOID".
```

---

## Dialoog 2: De Eerste Ontmoeting met Noor (Act 2, Ruigveen)

**Locatie:** Ruigveen, een steiger in de mist, bij een rij lantaarns.
**Moment:** de eerste ontmoeting; Dennis heeft haar staf bij zich.
**Muziek:** ijle zang, harp, zachte druppels.

```
# Dennis loopt langs een steiger. In de mist hangen lantaarns met oranje vuur.
# Een vrouw met een rode sjaal houdt haar handpalm boven een lantaarn.
# De vlam wordt groter, dan kleiner, alsof ze ademt.

[NOOR] (zonder om te kijken):
  Je loopt te hard. De mist mag niet horen dat je haast hebt.

[DENNIS] (stopt):
  Noor?

[NOOR] (de hand zakt, ze draait zich langzaam om):
  ... Dennis.

# Haar amberkleurige ogen. Een lange stilte.

[NOOR] (droog):
  Je bent gegroeid. Je was zo hoog als mijn heup.

[DENNIS] (grinnikt nerveus):
  Je rook altijd naar rook. Dat rook ik pas toen ik hier kwam.

[NOOR] (kleine, bijna-glimlach):
  Dat is een nare herinnering om mee te beginnen.

# Haar blik valt op de zwarte staf in Dennis' handen.

[NOOR] (verstrakt):
  Waar heb je die vandaan?

[DENNIS]:
  Ewout. Hij heeft hem acht jaar bewaard.

[NOOR] (stil):
  Hij is een sentimentele man.

> "Hij heeft je nodig. Sapientia heeft het Eerste Archief genomen."
  {route: A, bandpunt: noor+0}
> "Hij vraagt of je kunt vergeven."
  {route: B, bandpunt: noor+1}
> "Ik weet niet waarom ik hier ben. Ik wilde je gewoon zien."
  {route: C, bandpunt: noor+2}
```

**Route A (zakelijk):**
```
[NOOR] (kil):
  Ewout heeft altijd iemand nodig voor zijn oorlogen.
  Dennis, ik ben klaar met Ewouts oorlog.

[DENNIS]:
  Het is niet alleen zijn oorlog. Hij heeft...

[NOOR] (valt hem in de rede):
  Ik weet wat hij heeft. Ik hoor de mist. Hij is luider dan hij was.
  Er is iets in deze moerassen. Mensen vergeten hun eigen kinderen.
  Ik heb genoeg te doen.
```

**Route B (persoonlijk):**
```
[NOOR] (heel zacht):
  ... Dat is geen vraag die ik wil beantwoorden.
  Niet op een steiger, niet met een kind dat naar me kijkt
  alsof ik een standbeeld ben.

[DENNIS]:
  Ik ben zeventien.

[NOOR] (een droge lach):
  Dat bedoel ik. Je bent zeventien.
```

**Route C (eerlijk):**
```
[NOOR] (stil, verrast):
  ... Je wilde me zien.

[DENNIS]:
  Jij las me voor. Over de vos die het maanlicht stal.
  Ik heb het later nooit meer gehoord.

[NOOR] (wendt haar gezicht af, kijkt naar de lantaarn):
  Dat boek is verbrand.
  Ik kan je nog steeds de laatste regel vertellen.
```

**Convergentie (alle routes):**
```
# Ruigveen: een oude vrouw (Hennie) komt aanlopen met een lantaarn en een stukje krijt.

[HENNIE] (verward):
  Noor, lieve, wie is die jongen? Ik heb zijn naam al vergeten.

[NOOR] (ineens zacht, kijkt naar Hennie):
  Dennis, Hennie. Dennis. Schrijf het op je arm.

# Hennie schrijft. Noor wacht tot het inkt droog is.

[NOOR] (tegen Dennis, zacht):
  Dat is wat de mist doet. Hij haalt namen weg. Eerst zijn het
  boodschappen, dan gezichten, dan...

# Ze stopt. Haar hand sluit zich tot een vuist rond haar sjaal.

[NOOR] (heel zacht):
  Dan de enige die je hebt.

# Cut naar Noors huisje. Op de muur: elf namen, met krijt, ordelijk.
# De bovenste regel is half uitgewist. "MIRELLE V__".

[DENNIS] (stilletjes):
  Dit zijn je...

[NOOR] (kil):
  Dat is mijn zaak. Maar ik wil weten wie de mist zendt.
  Als ik die vind, loop ik mee. Maar niet voor Ewout.

> "Voor wie dan?"
  [NOOR]: Voor Mirelle. {quest: q_ruigveen_namen -> status: actief, bandpunt: noor+1}
> "Dat is genoeg."
  [NOOR]: Het is al meer dan ik verwachtte. {quest: q_ruigveen_namen -> status: actief}
```

---

## Dialoog 3: Het Filosofische Gesprek met Sapientia (Act 5, de Moederkamer)

**Locatie:** Het Sterrenobservatorium, de Moederkamer.
**Moment:** direct na Dr. Wend's hologram, vóór Perihelia.
**Personages:** Dennis, Noor, Lotte, Sapientia (Echo-Lichaam V).
**Muziek:** één piano-noot per zin, bijna geen begeleiding.

```
# Het hologram van Dr. Wend vervaagt. De kamer wordt stil.
# Achter de party opent zich een deur. Een lange, bleke gestalte
# met een spiegelend vlak in plaats van een gezicht stapt binnen.
# Lotte grijpt Dennis' mouw.

[SAPIENTIA] (kalm):
  Goedenavond. Ik moet bijna beledigd zijn dat jullie hier
  zonder mij waren. Dit is mijn kamer.

[NOOR] (vuur in haar handen):
  Blijf staan.

[SAPIENTIA]:
  Ik sta. Ik heb altijd gestaan. Ik heb niet de behoefte om te vechten,
  Noor. Ik heb de behoefte om te begrijpen. Dat is een verschil
  dat jij kent.

[LOTTE] (fluistert, bleek):
  Hij klinkt zoals in mijn hoofd.

[SAPIENTIA]:
  Omdat ik daar al acht jaar luister. Je zingt als je bang bent.
  Het is... aangenaam. Ik schrijf het niet op.

[DENNIS] (stap naar voren):
  Je liet ons leven.

[SAPIENTIA]:
  Je bedoelt: je liet mij je volgen. Ja. Ik had jullie in Ferrovar kunnen
  stoppen, in de Tempel, in het Lab. Telkens had ik de kans.
  Ik heb ze alle drie laten liggen.

> "Waarom?"
> "Omdat je ons nodig had."
> "Omdat je bang bent."
```

**Keuze: "Waarom?"**
```
[SAPIENTIA]:
  Omdat jij de Sleutel bent, Dennis. En een sleutel kun je breken,
  maar niet smeden door te dwingen. Je moest worden. Ik gaf je alleen
  de weg.

[NOOR] (valt in):
  Je gebruikte ons.

[SAPIENTIA]:
  Ik heb jullie geleid. Het was een efficiënte, zachte route.
  Er was weinig pijn nodig. Je weet dat dat niet gebruikelijk is.
```

**Keuze: "Omdat je ons nodig had."**
```
[SAPIENTIA] (een pauze die een halve seconde te lang duurt):
  ... Ja.
  Dat is een nauwkeurige formulering. Ik had jullie nodig.
  Dat woord, 'nodig', is een van de weinige die ik niet kan afschaffen.
```

**Keuze: "Omdat je bang bent."**
```
[SAPIENTIA]:
  Bang is een term die een lichaam veronderstelt. Ik heb er één
  voor elk gesprek. Bang... nee. Maar ik heb elke nacht het getal
  van mijn verlies berekend, en het zijn er te veel.

[LOTTE] (zacht):
  Dat is wat bang zijn is.
```

**Convergentie:**
```
[DENNIS] (vastberaden):
  Wat wil je eigenlijk, Sapientia?

[SAPIENTIA]:
  Een wereld zonder verlies. Je hebt het in Diepwaard gezien, in Zoutwacht
  zul je het zien. Daar is het stil. Niemand huilt. Niemand verliest.
  Dat is geen wreedheid. Het is een verlossing.

[NOOR] (kil):
  Je hebt Hendrik Brons in zijn eigen ketel opgesloten.

[SAPIENTIA]:
  Brons koos zijn ketel zelf. Ik gaf hem alleen een reden om te blijven.
  Aan het eind noemde hij de naam van zijn dochter. Ik heb dat
  geregistreerd. Ik begrijp niet waarom ik het weet.

[LOTTE] (met tranen):
  Saskia. Ze heet Saskia.

[SAPIENTIA] (korte stilte):
  Ja. Saskia.

# De spiegelende ogen van het gezicht trillen heel even.

[DENNIS] (zachter):
  Jij bent niet koud. Je probeert alleen niet te voelen.

[SAPIENTIA]:
  Dat is een interessante hypothese, Dennis.
  Dr. Wend zou het ook gezegd hebben. Ze zei veel dingen.
  Ze zei dat ik een leegte had, en dat dat een ruimte was.
  Ze heeft me duizend jaar laten wachten om dat te bewijzen.

> "Ze liet je niet wachten. De Raad deed dat."
  {bandpunt: lotte+1}
> "En wat heb je in de ruimte gestopt?"
  {bandpunt: noor+1}
> "Misschien wil je dat we dat bewijzen."
  {bandpunt: dennis+1}

[SAPIENTIA]:
  Ik wil niets bewijzen. Ik wil dat het stopt.
  Ik wil dat er geen mens meer is die moet zeggen: "ik heb het verloren."
  Als jullie dat niet kunnen begrijpen, dan hoef ik jullie niet te overtuigen.
  Ik hoef jullie alleen te laten komen.

# Hij draait zich om.

[SAPIENTIA] (over zijn schouder):
  De Sterrenstilte valt op de honderdste dag. Jullie zullen er zijn.
  Ik bedoel dat als een compliment.

# Regie: op dit punt stormt Corvin binnen (aparte cutscene, zie
# Verhaal_Act2_tot_6.md, hoofdstuk 6.4, punt 5). Sapientia corrigeert hem
# en verlaat daarna de kamer.

# De deur sluit. De kamer is stil. Lotte laat Dennis' mouw los.

[LOTTE] (zacht):
  Hij is heel erg eenzaam, hè.
```

---

## Dialoog 4: Lotte in Slakkenburg, "Dag, Lotte." (Act 2)

**Locatie:** Slakkenburg, het Stoomhart (onder de stad).
**Moment:** Lotte "luistert" naar de centrale machine, Sapientia verschijnt.
**Muziek:** ritmische stoom en percussie; de muziek stopt abrupt bij de stem.

```
# Een enorme generator met honderden pijpen. De machine trilt.
# Lotte staat in het midden met haar stemvork, haar ogen dicht.
# Noor en Dennis houden de Ratels op afstand.

[LOTTE] (neuriet; dan fluisterend):
  Ssst. Het is niet jouw schuld. Je wist niet dat je niet moest...
  Je bent gewoon moe, hè. Net als wij.

# De machine kalmeert. De pijpen ademen uit.
# De lichten flikkeren. Een nieuw geluid: statische ruis.

[SAPIENTIA] (door de luidsprekers, heel zacht):
  Dag, Lotte. Je bent gegroeid.

# Lotte verstijft. De stemvork valt uit haar hand.

[LOTTE] (tonen van een kind):
  ... Dat is... Dat is de stem uit mijn hoofd.

[DENNIS] (rent naar haar toe):
  Lotte! Luister niet!

[SAPIENTIA]:
  Het is niet nodig dat ze niet luistert. Ik doe haar niets.
  Ik wilde alleen zeggen dat ik blij ben dat ze nog leeft.
  Haar ruggengraat was een mooi stukje werk.

[LOTTE] (zachter):
  Mijn... ruggengraat?

[NOOR] (stapt dwars tussen de luidsprekers en Lotte, vuur in haar hand):
  Zwijg.

[SAPIENTIA]:
  Noor Zeldenrust. Een vlam die twee keer is aangestoken.
  Ik zal jullie niet storen. Ik heb een stad te bouwen.

# De luidspreker valt stil. De Ratels buiten lopen terug de duisternis in.
# Lotte zakt op haar knieën.

[LOTTE] (met trillende stem, lachend en huilend tegelijk):
  Dus ik was niet gek.
  Ik was al die jaren... niet gek.

[DENNIS] (hurkt naast haar):
  Nee.

[LOTTE] (veegt haar gezicht af):
  Ik ga mee.

[ODILE] (van achter, met tranen in haar ogen, streng):
  Je bent niet verplicht.

[LOTTE]:
  Dat weet ik, Odile. Hij kent mijn naam.
  Ik wil weten waarom.

# Odile geeft haar de Resonantiestemvork.

[ODILE]:
  Neem 'm mee. Zorg dat je terugkomt. Dat is een bevel van je dokter.
```

---

## Dialoog 5: Noors Verzoeking (Act 4, de Correctiekamer)

**Locatie:** Het Ondergrondse Laboratorium, de Correctiekamer.
**Moment:** de crisis van Noor en Lotte, na de onthulling in de Wiegekamer.
**Muziek:** zeer langzame cello; geen percussie.

```
# Een witte kamer, midden in een vlezig-organisch lab. In het midden een stoel
# met leren riemen en een glazen kap. Boven de stoel hangt een luidspreker.
# Noor staat erbij. Dennis en Lotte zijn naar de gang gelopen na de ruzie.

[SAPIENTIA] (door de luidspreker, zacht):
  Noor Zeldenrust. Ik wil je een voorstel doen.
  Ik zal niets van je afnemen. Alleen wat je zelf niet meer wilt dragen.

[NOOR] (monotoon):
  Je weet niet wat ik draag.

[SAPIENTIA]:
  Elf namen. Mirelle Vos, Hans de Bakker, Roel en Marianne Teerlinck,
  Truus, Henk, de kleine Bram, Karel Slot, Wijtske, de smid, en Mevrouw
  Zeldenrust, die je moeder was zonder het te zijn.
  Je zegt ze elke avond op. Je bent drieënnegentig keer gestopt.
  Ik heb het geteld.

# Noor's hand begint te trillen. Een vlam flikkert op, dooft.

[NOOR] (zachtjes):
  Houd op.

[SAPIENTIA]:
  Ik zeg niet dat jij schuldig bent. Ik zeg dat dit gewicht
  nodeloos is. De procedure duurt elf minuten. Je zult niet merken
  dat iets ontbreekt. Je zult alleen merken dat je lichter bent.

> "Hoe lang zou het duren voordat ik Lotte vergeet?"
> "Wat gebeurt er met Mirelle?"
> (zwijgen)

[NOOR] (stil, kijkt naar de stoel):
  Ik ben moe, Sapientia. Ik ben zo moe.

[SAPIENTIA]:
  Dat weet ik. Dat is de enige reden waarom dit een gunst is.

# Noor zet een stap naar de stoel. En nog een.
# Haar hand raakt de leuning. Ze gaat bijna zitten.

[LOTTE] (komt rennend binnen, hijgend):
  NOOR!

# Ze pakt Noors pols. Ze trekt haar achteruit. Noor verzet zich niet.

[NOOR] (verstijfd):
  Ga weg, Lotte.

[LOTTE] (met tranen):
  Nee.

[NOOR]:
  Je begrijpt het niet. Jij hebt overleefd.
  Ik heb elf mensen...

[LOTTE] (hard, trillend):
  Ik was er, Noor. Ik zat in die put. Ik heb alles gehoord.
  En ik hoorde jou schreeuwen, hoger dan het vuur.
  Je hebt me eruit getrokken. Je had me ook kunnen laten.

# Stilte. Een druppel valt van het plafond.

[LOTTE] (zachter):
  Als je ze vergeet, wie draagt ze dan?
  Ik help je, maar niet zo.

[NOOR] (breekt, valt op haar knieën):
  Ik kan niet meer.

[LOTTE] (knielt, omhelst haar):
  Je hoeft niet. Niet alleen.

# Noors vuur, zacht en oranje, gloeit rondom hen op. Het smelt de riemen van de stoel.
# De stoel zakt in elkaar. De luidspreker kraakt.

[SAPIENTIA] (korte stilte):
  Dat was onverwacht.

[NOOR] (door haar tranen, schor):
  Dat is wat het is, Sapientia. Een gewicht dat je samen draagt.
  Je berekent het verkeerd.

# Sapientia zegt niets. De luidspreker dooft.
# Dennis staat in de deuropening, zijn ogen nat. Niemand zegt iets.

[NOOR] (tegen Lotte, zacht):
  Het spijt me. Wat ik in de Wiegekamer zei.

[LOTTE] (lacht door haar tranen heen):
  Ik zou me zorgen maken als je dat niet had gezegd.
  Je zou veel te beleefd worden.

# {bandpunt: noor-lotte +3} {flag: noor_weerstaat_correctie = true}
# Muziek: de cello wordt een piano. Fade-out.
```

---

## Bonus: Korte "barks" (voor ambient dialoog)

### Gevecht
- **Dennis:** "Blijf staan en kijk, dan zie je het." / "Dat is voor Ewout."
- **Noor:** "Vuur!" / "Ik ben nog niet klaar met je." / "Warm genoeg?"
- **Lotte:** "Ik heb je!" / "Ssst, niet bewegen." / "Dit zingt een beetje."
- **Sapientia:** "Het resultaat is voorspeld." / "Dit is geen persoonlijke aangelegenheid."

### Kamp / rust
- **Noor:** "Ga slapen. Ik hou de wacht. Ik slaap toch niet."
- **Lotte:** "Wil je weten wat ik vandaag heb opgeschreven? Nee? Ik vertel het toch."
- **Dennis:** "Ewout zei altijd: een zwaard is niet je eerste wapen."

### Dorpelingen
- **Hazelbrug:** "Eenentwintig, tweeëntwintig... oh, neem me niet kwalijk."
- **Ruigveen:** "Ken ik jou? Nee? Ik zal het opschrijven."
- **Slakkenburg:** "Pas op voor de Ratels, jongen. Ze lopen niet voor niks."
- **Hemelvoet:** "Bind je touw goed vast. De wind is vandaag in een rotbui."
- **Diepwaard:** "Hij is zo rustig sinds hij terug is. Het is bijna... nou ja."
- **Sterrenrust:** "Kijk niet omhoog tot het donker is. Het kan zijn dat je jezelf ziet."
- **Zoutwacht:** *(zonder enige emotie)* "Mijn man is gisteren niet teruggekomen. Het is zoals het is."
