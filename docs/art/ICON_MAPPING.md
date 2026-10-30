# Voorstel-mapping SAPIENTIA item_id -> icon (Item Icons v1.5, geremapt sap73)

Bron: /tmp/b2r @ 0839ad9 (2026-10-24 19:38 CEST), read-only. Iconen: `out/icons16/<naam>.png` / `out/icons32/<naam>.png`.

## Waar iconen nu in de game zitten

- Viewport 384x216 (x3 venster) → 16px is de natuurlijke maat; 32px is 1/7 van de schermhoogte.
- 27 eigen iconen 16x16 in `assets/ui/icons/` (items, uitrusting, `cat_*`, kernen). Maar in code worden er maar weinig gebruikt:
  - schatkist (`scripts/puzzle/treasure_chest.gd`): Sprite2D boven de kist, uit `"icon"` van het item (16px).
  - Codex-gevecht (`codex_battle.gd`, `codex_data.BOOK_ICON`): leeg_boek 16px.
  - kernfragmenten (`kern_data.gd`): golemkern/levenskern.
  - `"icon"`-veld staat alleen op leeg_boek, vonkzwaard, reisgewaad.
- Items-scherm, Uitrusting, Winkel, Koopman, Werkplaats, gevechts-itemlijst en buitmelding tonen nu **alleen tekst** (geen icoon-code). Iconen daar = code-werk voor RPG CODE.
- Geen materialen in de game (Werkplaats-recepten gebruiken drankjes). Slots `benen`/`laarzen` bestaan maar hebben 0 items → boot_* ongebruikt.

| item_id | naam | icon | opmerking |
|---|---|---|---|

## Verbruiksitems (ITEMS)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `drankje` | Potion | potion_red | bestaand 16px icoon; vervangen = keuze |
| `toverwater` | Magic Water | potion_cyan | bestaand |
| `kruid` | Healing Herb | mat_herb | bestaand |
| `sterk_drankje` | Strong Potion | potion_orange | rood al bezet; of potion_red + rand |
| `toverbrouwsel` | Magic Brew | potion_blue |  |
| `elixer` | Elixir | potion_elixir |  |
| `feniksveer` | Phoenix Feather | mat_feather | veer is neutraal, geen vuur; matig |
| `tegengif` | Antidote | potion_antidote |  |
| `stunbom` | Stun Bomb | — | GEEN: geen bom/orb in pack |
| `h5_notitie` | Faded Note | scroll_map | benadering (briefje); matig |
| `leeg_boek` | Blank Book | scroll_blank | bestaand eigen boek-icoon is beter; HOUDEN |
| `spreuk_vuur` | Scroll: Spark | scroll_fire |  |
| `spreuk_bliksem` | Scroll: Chain Lightning | scroll_spell | geen bliksemrol |
| `spreuk_genees` | Scroll: Minor Heal | scroll_heal |  |
| `spreuk_inferno` | Scroll: Inferno | scroll_fire | oud id |
| `spreuk_oerwoud` | Scroll: Primeval Forest | scroll_ancient | oud id |
| `spreuk_donderslag` | Scroll: Godstrike | scroll_spell | oud id |
| `spreuk_aureool` | Scroll: Aurora | scroll_heal | oud id |
| `spreuk_ijskern` | Scroll: Glacial | scroll_ice | oud id |
| `spreuk_g4_* (20 stuks)` | Grade-4-rollen | scroll_fire / scroll_ancient / scroll_spell / scroll_heal / scroll_ice per element | vuur: zonneslag, apocalyps, dageraad, zuiverende_vlam; natuur: zielenbloei, oerbos, moeder_aarde, wildgroei (ancient); donder: hemelval, donderslag, stormheer, zuiverende_donder (spell); heilig: wederopstanding, heilige_straal, aureool, zegen_der_goden (heal); ijs: eeuwige_winter, absolute_nul, ijskern, sneeuwkoningin (ice). Grade-4 visueel niet te onderscheiden van gewone rollen |
| `kruidenthee` | Herbal Tea | potion_green |  |
| `gloeiende_inktfles` | Glowing Ink | potion_black | of potion_purple |
| `smeerolie` | Forge Oil | potion_yellow |  |
| `windwater` | Wind Water | potion_white |  |
| `stroomdrank` | Current Tonic | potion_cyan | botst met toverwater -> evt potion_purple |
| `antiserum_nul` | Antiserum Zero | potion_empty | kleurloze ampul past |
| `regeneratie` | Regeneration | potion_pink |  |
| `sterrenelixer` | Star Elixir | potion_rainbow |  |
| `herinnering` | Remembrance | potion_white | botst met windwater; matig |
| `harttraan` | Heart Tear | — | GEEN goede (kristalfles/traan); noodoptie gem_moonstone |
| `zingend_meel` | Singing Flour | food_bread | meel≈brood; matig |

## Sleutel-voorwerpen (KEY_ITEMS)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `emmer_water` | Bucket of Water | — | GEEN (emmer); bestaand icoon HOUDEN |
| `warp` | Warp Crystal | mat_crystal_shard | of scroll_teleport |
| `hanger` | Pendant | amulet_heart | hartvormige hanger: exact |
| `zingend_zaad` | Singing Seed | — | GEEN (zaad); noodoptie mat_herb |

## Kernfragmenten (kern_data.gd, eigen icoon)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `golemkern` | Golem Core | — | eigen story-icoon HOUDEN (gem_onyx als noodoptie) |
| `levenskern` | Life Core | — | eigen icoon (PH) HOUDEN of mat_essence_earth |

## Uitrusting (EQUIPMENT) – Act 1

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `kort_zwaard` | Short Sword | sword_iron | bestaand |
| `vonkzwaard` | Spark Sword | sword_flame | bestaand eigen icoon (Dennis' keuze) HOUDEN aanbevolen |
| `eiken_staf` | Oak Staff | staff_wood | bestaand |
| `dolk` | Dagger | sword_dagger | bestaand |
| `houten_schild` | Wooden Shield | shield_wood | bestaand |
| `kaftschild` | Cover Shield | shield_rune | boekkaft-schild; bestaand eigen icoon beter |
| `leren_kap` | Leather Hood | helm_hood | bestaand |
| `ijzeren_helm` | Iron Helm | helm_iron | bestaand |
| `reisgewaad` | Travel Robe | armor_cloth | bestaand |
| `leren_harnas` | Leather Armor | armor_leather | bestaand |
| `leerling_mantel` | Apprentice Cloak | armor_mage |  |
| `malienkolder` | Chain Mail | armor_chain | bestaand |
| `groenring` | Green Ring | ring_emerald | bestaand |

## Act 2 (industrie)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `wambuis` | Padded Jerkin | armor_leather | dubbel met leren_harnas |
| `ketelkling` | Kettle Blade | sword_cutlass |  |
| `rookstaf` | Smoke Staff | staff_shadow |  |
| `stemvork` | Tuning Fork | — | GEEN (stemvork) |
| `ketelschild` | Kettle Shield | shield_iron |  |
| `ketelhelm` | Kettle Helm | helm_visored |  |
| `rookkap` | Smoke Hood | helm_hood | dubbel met leren_kap |
| `schrootplaat` | Scrap Plate | armor_plate |  |
| `werkmantel` | Work Cloak | armor_ranger |  |
| `koperring` | Copper Ring | ring_plain | of ring_ember |

## Act 3 (tempel/lucht)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `ankerkling` | Anchor Blade | sword_claymore |  |
| `zweefstaf` | Hover Staff | staff_lightning |  |
| `gebedsstaf` | Prayer Staff | staff_holy |  |
| `ankerschild` | Anchor Shield | shield_tower |  |
| `tempelhelm` | Temple Helm | helm_knight |  |
| `windkap` | Wind Hood | helm_mage |  |
| `tempelplaat` | Temple Plate | armor_holy |  |
| `wolkgewaad` | Cloud Robe | armor_mage | dubbel met leerling_mantel |
| `stroomring` | Current Ring | ring_aquamarine |  |

## Act 4 (lab)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `incisie` | Incision | sword_rapier | scalpel-achtig; matig |
| `glazenstaf` | Glass Staff | staff_crystal |  |
| `levensstaf` | Life Staff | staff_nature |  |
| `kweekschild` | Growth Shield | shield_nature |  |
| `kweekhelm` | Growth Helm | helm_horn | matig |
| `glashelm` | Glass Helm | — | GEEN glazen helm; noodoptie helm_visored |
| `chitineharnas` | Chitin Armor | armor_scale |  |
| `labmantel` | Lab Coat | — | GEEN (labjas); noodoptie armor_cloth |
| `levensring` | Life Ring | ring_rose |  |

## Act 5 (sterren)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `perihelium` | Perihelion | sword_gold |  |
| `lichtstaf` | Light Staff | staff_sun |  |
| `maanschild` | Moon Shield | shield_ice | geen maanschild; matig |
| `sterrenhelm` | Star Helm | helm_crown | matig |
| `sterrenkap` | Star Hood | helm_mage | dubbel met windkap |
| `maanharnas` | Moon Armor | armor_gold | matig |
| `sterrenmantel` | Star Cloak | armor_dark | matig |
| `sterrenring` | Star Ring | ring_diamond |  |

## Act 6 (hart/zout)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `memoria` | Memoria | sword_crystal |  |
| `hartpsalm` | Heart Psalm | staff_moon | matig |
| `hartschild` | Heart Shield | shield_royal |  |
| `zouthelm` | Salt Helm | helm_dragon | matig |
| `traankap` | Tear Hood | helm_hood | dubbel |
| `tranenpantser` | Tearplate | armor_plate | dubbel met schrootplaat |
| `hartmantel` | Heart Cloak | armor_holy | dubbel |
| `hartring` | Heart Ring | ring_ruby |  |

## Dungeon100-buit (d100_*)

| item_id | naam | icon | opmerking |
|---|---|---|---|
| `d100_zwaard_2..5` | Archive/Rune/Glitch/Seal Sword | sword_steel / sword_sapphire / sword_dark / sword_holy |  |
| `d100_staf_2..5` | Archive/Rune/Glitch/Seal Staff | staff_arcane / staff_ice / staff_necro / staff_holy* | *staff_holy dubbel met gebedsstaf |
| `d100_schild_2..5` | …Shield | shield_kite / shield_rune / shield_dark / shield_holy |  |
| `d100_helm_2..5` | …Helm | helm_knight / helm_visored / helm_skull / helm_crown | dubbels met verhaalset |
| `d100_harnas_2..5` | …Armor | armor_chain / armor_scale / armor_dark / armor_gold | dubbels |
| `d100_ring_2..5` | …Ring | ring_sapphire / ring_amethyst / ring_ember / ring_gold |  |

## Zonder passend icoon

stunbom, harttraan, emmer_water, zingend_zaad, stemvork, glashelm, labmantel (+ golemkern/levenskern: eigen story-iconen houden). Zwakke matches ('matig'): feniksveer, h5_notitie, zingend_meel, incisie, kweekhelm, maanschild, sterrenhelm/-harnas/-mantel, hartpsalm, zouthelm.

Dubbels: verhaalset Act 2-6 en d100 hergebruiken ~15 iconen (bv. helm_hood 3x, armor_plate 2x). Veel drankjes delen kleuren (cyan, wit).

Totaal: 34 verbruik (incl. 20 g4-rollen) + 4 sleutel + 2 kern + 57 verhaal-uitrusting + 24 d100 = 121 ids; ~104 gemapt, 7 geen icoon, ~13 matig.
