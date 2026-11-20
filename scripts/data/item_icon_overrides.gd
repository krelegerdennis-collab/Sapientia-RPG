extends RefCounted
## Post-RC: extra icoon-koppelingen voor uitrusting die NIET in GameData staat (grade_gear.gd: blauwe kisten
## Diepe Grot; arena_shop_data.gd: arena-winkel). MAPPING.csv (RPG ART) blijft onaangeraakt; ItemIcons leest
## deze tabel na de csv. Waarde = bestandsnaam zonder .png in icons16/ en icons32/ (beide maten bestaan).
## Een id die al in MAPPING.csv staat wint altijd (de override vult alleen gaten).

const ICONS := {
	# nieuwe pack-iconen (post-rc/item-icons, RPG ART)
	"bg_g1_zwaard": "sword_bronze",
	"bg_g2_zwaard": "sword_obsidian",
	"bg_g3_zwaard": "sword_dark",
	"bg_g4_superzwaard": "sword_holy",
	"bg_g2_staf": "staff_ice",
	"bg_g3_staf": "staff_necro",
	"bg_g3_helm": "helm_skull",
	"bg_g1_laarzen": "boot_leather",
	"bg_g2_laarzen": "boot_iron",
	"bg_g3_laarzen": "boot_steel",
	"bg_g4_plated_laarzen": "boot_gold",
	"bg_g4_robes_laarzen": "boot_holy",
	"bg_g4_natuur_laarzen": "boot_mage",
	"bg_g4_ring_kracht": "ring_ember",
	"bg_g4_ring_wil": "ring_amethyst",
	"bg_g4_amulet": "amulet_rune",
	"arena_blade": "sword_bronze",
	# bestaande iconen hergebruikt
	"bg_g1_staf": "eiken_staf",
	"bg_g4_staf_noor": "levensstaf",
	"bg_g4_staf_lotte": "gebedsstaf",
	"bg_g1_helm": "leren_kap",
	"bg_g2_helm": "leren_kap",
	"arena_cap": "leren_kap",
	"bg_g4_plated_helm": "tempelhelm",
	"bg_g4_robes_helm": "windkap",
	"bg_g4_natuur_helm": "kweekhelm",
	"bg_g1_harnas": "leren_harnas",
	"bg_g2_harnas": "malienkolder",
	"arena_mail": "malienkolder",
	"bg_g3_harnas": "sterrenmantel",
	"bg_g4_plated_harnas": "schrootplaat",
	"bg_g4_robes_harnas": "hartmantel",
	"bg_g4_natuur_harnas": "werkmantel",
}

## Bewust zonder eigen icoon: houden het categorie-icoon (vraag aan Dennis via Forge).
const CATEGORY_ONLY: Array[String] = [
	"bg_g1_benen", "bg_g2_benen", "bg_g3_benen", "bg_g4_plated_benen", "bg_g4_robes_benen", "bg_g4_natuur_benen",
]
