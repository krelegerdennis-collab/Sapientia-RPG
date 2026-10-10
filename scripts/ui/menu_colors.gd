extends RefCounted
## v0.14 (RPG CODE, menu L2) ALLE kleuren van het veldmenu op één plek.
## Sinds de rebase op v0.13 (palet 'Inkt & Perkament') verwijst bijna alles naar het gedeelde
## palet van Forge in scripts/ui/ui_style.gd (UiStyle). Dat bestand passen we hier NIET aan:
## verandert Forge daar een kleur, dan volgt het menu vanzelf.
## De rest van de menucode gebruikt ALLEEN deze namen (MenuColors.XXX).
## Alleen wat het palet (nog) niet kent staat hier als eigen waarde (gemarkeerd met 'eigen'):
## de stat-pijlen (BETTER/WORSE/SAME), ACCENT_GREY en de zachte waas DIM.
## (preload i.p.v. class_name, zoals de andere UI-hulpjes)

const UiStyle := preload("res://scripts/ui/ui_style.gd")

# ---------------------------------------------------------------- tekst
const TEXT := UiStyle.TEXT              # gewone tekst (crème)
const TEXT_DIM := UiStyle.TEXT_DIM      # labels ('ATK', 'Wapen', hulpregel)
const TEXT_OFF := UiStyle.TEXT_OFF      # uitgeschakeld / grijs item
const SHADOW := UiStyle.SHADOW          # 1 px tekstschaduw
const TITLE := UiStyle.HILITE           # schermtitel ('Uitrusting', 'Status')

# ---------------------------------------------------------------- vensters
const WINDOW := UiStyle.INK             # vensterkleur (diepe inkt)
const WINDOW_ALPHA := 0.90              # eigen: iets dichter dan UiStyle.PANEL_ALPHA (0.82),
                                        # want menu's hebben veel kleine tekst boven de map
const WINDOW_INNER := UiStyle.INK_LIGHT # vak in een venster (portret, lijst)
const BORDER := UiStyle.BORDER          # rand van een 'actief' venster / vraag (perkament-goud)
const BORDER_DARK := UiStyle.BORDER_DIM # gewone vensterrand
const LINE := UiStyle.BORDER_DIM        # scheidingslijn onder de titel
const DIM := Color(0.03, 0.02, 0.04, 0.5)   # eigen: waas over de map achter het menu

# ---------------------------------------------------------------- selectie / accent
const ACCENT := UiStyle.HILITE          # gekozen regel + '>' (warm goud)
const ACCENT_SOFT := UiStyle.HILITE_DIM # 'gekozen' terwijl je iets anders kiest
const ACCENT_GREY := Color("8c8270")    # eigen: grijs item met focus
const PERMANENT := Color("8cc4ff")      # eigen: permanent item uit een Blauwe Kist (Het Gesimuleerde Archief)
const PERMANENT_DIM := Color("5f8fc4")  # eigen: idem, grijs (niet te gebruiken) en zonder focus
const INFO := UiStyle.TEAL              # meldingen en effecten
const KO := UiStyle.KO                  # KO-held

# ---------------------------------------------------------------- stat-pijlen (uitrusting)
const BETTER := Color("8fd18b")         # eigen: beter = groen, pijl omhoog
const WORSE := Color("e3837a")          # eigen: slechter = rood, pijl omlaag
const SAME := UiStyle.TEXT_OFF          # gelijk: grijs pijltje

# ---------------------------------------------------------------- balken
## [licht bovenrandje, vulling, donkere onderrand] – dezelfde balken als in het gevecht
const BAR_HP := UiStyle.BAR_HP
const BAR_MP := UiStyle.BAR_MP
const BAR_LOW := UiStyle.BAR_HP_LOW
const BAR_EMPTY := UiStyle.BAR_EMPTY
const BAR_EDGE := UiStyle.BAR_EDGE


## Naamkleur van een held ("magenta" = Noor, "cyaan" = Lotte): zelfde accent als in het gevecht.
static func hero_color(accent_name: String) -> Color:
	return UiStyle.accent(accent_name)
