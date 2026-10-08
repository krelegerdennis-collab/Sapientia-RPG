"""'De Vergeten Bibliotheek' (v7): gedeelde palet-ramps en hulpjes.

Stijl: glitch / digitaal verval + dark academia. Bijna alles grijs (houtskool, steen,
perkament, leer) en ontkleurd; neon (magenta #FF00FF-achtig, cyaan #00FFFF-achtig)
alleen als accent: magie, wapens, selectie, glitch-pixels. Zie docs/ARTSTYLE.md, hoofdstuk 13.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ramp(*hexes):
    return [rgb(h) for h in hexes]


# ---------------------------------------------------------------- neon (alleen accent!)
MAGENTA = rgb("ff1ee6")          # hoofdaccent (#FF00FF-achtig, een tikje warmer)
MAGENTA_HOT = rgb("ffb4f8")      # kern van een gloed
MAGENTA_DIM = rgb("8a0c84")
CYAN = rgb("19ecf6")             # tweede accent (#00FFFF-achtig)
CYAN_HOT = rgb("c8feff")
CYAN_DIM = rgb("08707a")
NEON_MAGENTA = ramp("2a0428", "5e0a5a", "a01298", "e01cd6", "ff5cf2", "ffc6fb")
NEON_CYAN = ramp("03282c", "075a62", "0b929e", "16d2de", "6ef2f8", "d2feff")

# ---------------------------------------------------------------- grijzen en ontkleurde materialen
CHARCOAL = ramp("08080a", "111114", "18181c", "202025", "2a2a30", "36363d")
STONE = ramp("1a1a1c", "2a2a2d", "3c3c40", "515155", "6a6a6e", "88888b", "a8a8aa", "c8c8c8")
SKIN = ramp("2c1e1e", "523834", "7c5a4c", "a07a66", "c09c86", "dcc2ae")
HAIR_BLACK = ramp("0a090c", "15131a", "211e26", "2e2a33", "3d3842", "524c56")
HAIR_BROWN = ramp("170f0c", "2b1d16", "432c20", "5c3e2c", "77543a", "93704e")
HAIR_ASH = ramp("25252a", "434349", "64646a", "88878c", "aaa9ac", "cdcccc")
CAPE_DARK = ramp("09090c", "121216", "1b1b21", "26262d", "33333b", "44444c")
ARMOR = ramp("121316", "25272b", "3e4146", "5d6066", "84878c", "b6b8ba")
LEATHER = ramp("140f0d", "261c17", "3a2b22", "4f3c2f", "675040", "806754")
CLOTH = ramp("0f0f12", "1b1b1f", "28282d", "36363c", "47474d", "5c5c62")
ROBE_PALE = ramp("26262b", "45454c", "68686f", "8e8e94", "b6b6ba", "dcdcde")
WOOD = ramp("150f0c", "271d17", "3c2e24", "524033", "6a5444", "836c5a")
BRONZE = ramp("1e1914", "3a3026", "5a4b3a", "7a6850", "998668", "b8a688")   # ontkleurd 'goud'
PARCHMENT = ramp("2a2620", "4a4438", "6e6656", "948a76", "b8ae98", "d8d0bc")
PAGE = ramp("38352f", "625e55", "8e897e", "b4afa3", "d4cfc4", "efebe2")
BOOK_BROWN = ramp("150e0c", "281b16", "3c2a22", "523a2e", "6a4c3c", "84604c")
BOOK_RED = ramp("170c0e", "2c161a", "432228", "5a3036", "724046", "8c5458")
BOOK_SLATE = ramp("0f1114", "1c2025", "2c3138", "3e444c", "525962", "6b727a")
BOOK_GREEN = ramp("0e110e", "1a201a", "283028", "374137", "485448", "5d6a5d")
CORE = ramp("0c040c", "1c0a1c", "2e1030", "441a46", "5c2460", "76307a")      # glitch-kern (paars-zwart)
OUTLINE = rgb("060608")

# ---------------------------------------------------------------- mini-cijfers 3x5 (voor binaire code)
DIGITS = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
}


def binary_text(draw_px, x, y, text, color, step=4):
    """Zet '0101...' als 3x5-pixelcijfers neer via draw_px(x, y, color)."""
    for k, ch in enumerate(text):
        g = DIGITS.get(ch)
        if not g:
            continue
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == "#":
                    draw_px(x + k * step + gx, y + gy, color)
