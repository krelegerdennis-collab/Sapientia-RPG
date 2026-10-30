# ITEM_AUDIT — WM1-itemdata

Gegenereerd door `tools/check_items.gd` (Godot 4.3-stable (official)). Het script repareert niets.

```
Godot --headless --path . res://tools/check_items.tscn -- --out=ITEM_AUDIT.md
```

## Gecontroleerd

| bron | aantal |
|---|---|
| ITEMS | 50 |
| KEY_ITEMS | 4 |
| EQUIPMENT | 85 |
| GradeGear | 36 |
| KERNFRAGMENTEN | 2 |
| Berggrot | 2 |
| MAPPING-rijen | 143 |
| "item"-verwijzingen | 43 |
| **catalogus totaal** | 179 |

## Samenvatting

| controle | FOUT | LET OP |
|---|---|---|
| 1. Unieke id's | 0 | 0 |
| 2. Iconen | 0 | 36 |
| 3. Prijzen | 0 | 124 |
| 4. Dubbele namen | 0 | 0 |
| 5. Engelse spelersnamen | 0 | 1 |
| 6. Verwijzingen naar items | 0 | 0 |
| **totaal** | **0** | **161** |

FOUT = in strijd met de regel. LET OP = afwijking die (waarschijnlijk) bewust is of alleen een terugval geeft.

## 1. Unieke id's

Geen bevindingen.

## 2. Iconen

| ernst | bestand:regel | id | probleem |
|---|---|---|---|
| LET OP | `scripts/data/grade_gear.gd:22` | `bg_g1_zwaard` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:23` | `bg_g1_staf` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:24` | `bg_g1_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:25` | `bg_g1_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:26` | `bg_g1_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:27` | `bg_g1_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:29` | `bg_g2_zwaard` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:30` | `bg_g2_staf` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:31` | `bg_g2_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:32` | `bg_g2_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:33` | `bg_g2_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:34` | `bg_g2_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:36` | `bg_g3_zwaard` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:38` | `bg_g3_staf` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:40` | `bg_g3_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:42` | `bg_g3_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:44` | `bg_g3_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:46` | `bg_g3_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:49` | `bg_g4_superzwaard` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:52` | `bg_g4_staf_noor` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:55` | `bg_g4_staf_lotte` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_wapen.png) |
| LET OP | `scripts/data/grade_gear.gd:59` | `bg_g4_plated_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:62` | `bg_g4_plated_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:65` | `bg_g4_plated_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:68` | `bg_g4_plated_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:71` | `bg_g4_robes_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:74` | `bg_g4_robes_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:77` | `bg_g4_robes_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:80` | `bg_g4_robes_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:83` | `bg_g4_natuur_helm` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:86` | `bg_g4_natuur_harnas` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:89` | `bg_g4_natuur_benen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:92` | `bg_g4_natuur_laarzen` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_harnas.png) |
| LET OP | `scripts/data/grade_gear.gd:96` | `bg_g4_ring_kracht` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_accessoire.png) |
| LET OP | `scripts/data/grade_gear.gd:98` | `bg_g4_ring_wil` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_accessoire.png) |
| LET OP | `scripts/data/grade_gear.gd:100` | `bg_g4_amulet` | geen rij in assets/ui/icons/items/MAPPING.csv: toont het categorie-icoon (cat_accessoire.png) |

## 3. Prijzen

| ernst | bestand:regel | id | probleem |
|---|---|---|---|
| LET OP | `scripts/data/berggrot_data.gd:360` | `bergnerfstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/berggrot_data.gd:369` | `adersteen` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:605` | `drankje` | geen "price"-veld; winkelprijs via ShopData.list_price = 30 |
| LET OP | `scripts/data/game_data.gd:608` | `toverwater` | geen "price"-veld; winkelprijs via ShopData.list_price = 50 |
| LET OP | `scripts/data/game_data.gd:611` | `kruid` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:614` | `sterk_drankje` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:616` | `toverbrouwsel` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:618` | `elixer` | geen "price"-veld; alleen KoopmanWinkel.BASIS_PRIJS = 300 |
| LET OP | `scripts/data/game_data.gd:621` | `feniksveer` | geen "price"-veld; winkelprijs via ShopData.list_price = 200 |
| LET OP | `scripts/data/game_data.gd:623` | `tegengif` | geen "price"-veld; winkelprijs via ShopData.list_price = 40 |
| LET OP | `scripts/data/game_data.gd:625` | `stunbom` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:627` | `h5_notitie` | geen "price"-veld; alleen KoopmanWinkel.BASIS_PRIJS = 150 |
| LET OP | `scripts/data/game_data.gd:639` | `spreuk_vuur` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:641` | `spreuk_bliksem` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:643` | `spreuk_genees` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:646` | `spreuk_inferno` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:648` | `spreuk_oerwoud` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:650` | `spreuk_donderslag` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:652` | `spreuk_aureool` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:654` | `spreuk_ijskern` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:657` | `spreuk_g4_zonneslag` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:659` | `spreuk_g4_apocalyps` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:661` | `spreuk_g4_dageraad` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:663` | `spreuk_g4_zuiverende_vlam` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:665` | `spreuk_g4_zielenbloei` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:667` | `spreuk_g4_oerbos` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:669` | `spreuk_g4_moeder_aarde` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:671` | `spreuk_g4_wildgroei` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:673` | `spreuk_g4_hemelval` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:675` | `spreuk_g4_donderslag` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:677` | `spreuk_g4_stormheer` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:679` | `spreuk_g4_zuiverende_donder` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:681` | `spreuk_g4_wederopstanding` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:683` | `spreuk_g4_heilige_straal` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:685` | `spreuk_g4_aureool` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:687` | `spreuk_g4_zegen_der_goden` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:689` | `spreuk_g4_eeuwige_winter` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:691` | `spreuk_g4_absolute_nul` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:693` | `spreuk_g4_ijskern` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:695` | `spreuk_g4_sneeuwkoningin` | geen "price"-veld; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:702` | `kruidenthee` | "price": 0; winkelprijs via ShopData.list_price = 20 |
| LET OP | `scripts/data/game_data.gd:706` | `gloeiende_inktfles` | "price": 0; alleen KoopmanWinkel.BASIS_PRIJS = 80 |
| LET OP | `scripts/data/game_data.gd:710` | `smeerolie` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:714` | `windwater` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:717` | `stroomdrank` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:721` | `antiserum_nul` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:724` | `regeneratie` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:728` | `sterrenelixer` | "price": 0; alleen KoopmanWinkel.BASIS_PRIJS = 220 |
| LET OP | `scripts/data/game_data.gd:732` | `herinnering` | "price": 0; alleen KoopmanWinkel.BASIS_PRIJS = 350 |
| LET OP | `scripts/data/game_data.gd:735` | `harttraan` | "price": 0; alleen KoopmanWinkel.BASIS_PRIJS = 400 |
| LET OP | `scripts/data/game_data.gd:738` | `zingend_meel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:782` | `vonkzwaard` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:812` | `leerling_mantel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:829` | `wambuis` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:833` | `ketelkling` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:837` | `rookstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:841` | `stemvork` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:845` | `ketelschild` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:849` | `ketelhelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:853` | `rookkap` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:857` | `schrootplaat` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:862` | `werkmantel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:866` | `koperring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:870` | `ankerkling` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:874` | `zweefstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:878` | `gebedsstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:882` | `ankerschild` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:886` | `tempelhelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:890` | `windkap` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:894` | `tempelplaat` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:899` | `wolkgewaad` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:903` | `stroomring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:907` | `incisie` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:911` | `glazenstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:915` | `levensstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:919` | `kweekschild` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:923` | `kweekhelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:927` | `glashelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:931` | `chitineharnas` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:935` | `labmantel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:939` | `levensring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:943` | `perihelium` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:948` | `astrostaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:952` | `lichtstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:956` | `maanschild` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:960` | `sterrenhelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:964` | `sterrenkap` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:968` | `maanharnas` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:973` | `sterrenmantel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:977` | `sterrenring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:981` | `memoria` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:985` | `hartvuurstaf` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:989` | `hartpsalm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:993` | `hartschild` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:997` | `zouthelm` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1001` | `traankap` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1005` | `tranenpantser` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1010` | `hartmantel` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1014` | `hartring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1021` | `d100_zwaard_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1023` | `d100_zwaard_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1025` | `d100_zwaard_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1027` | `d100_zwaard_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1029` | `d100_staf_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1031` | `d100_staf_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1033` | `d100_staf_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1035` | `d100_staf_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1037` | `d100_schild_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1039` | `d100_schild_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1041` | `d100_schild_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1043` | `d100_schild_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1045` | `d100_helm_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1047` | `d100_helm_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1049` | `d100_helm_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1051` | `d100_helm_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1053` | `d100_harnas_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1055` | `d100_harnas_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1057` | `d100_harnas_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1059` | `d100_harnas_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1061` | `d100_ring_2` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1063` | `d100_ring_3` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1065` | `d100_ring_4` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1067` | `d100_ring_5` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |
| LET OP | `scripts/data/game_data.gd:1070` | `simulatie_ring` | "price": 0; niet te koop en niet te verkopen (verkoopprijs 0) |

## 4. Dubbele namen

Geen bevindingen.

## 5. Engelse spelersnamen

| ernst | bestand:regel | id | probleem |
|---|---|---|---|
| LET OP | `scripts/data/game_data.gd:981` | `memoria` | naam is gelijk aan het id: "Memoria" |

## 6. Verwijzingen naar items

Geen bevindingen.

