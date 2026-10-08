"""UI-vensters voor 'De Vergeten Bibliotheek' (v7): donker houtskool-grijs, dunne
lichtgrijze rand, afgeschuinde metalen hoekplaatjes met een klinknagel.

Elk venster bestaat twee keer:
  <naam>.png     1x  (overworld, 384x216)
  <naam>_hd.png  2x  (gevecht, 768x432; Godot toont hem op de halve maat, zie hd_ui.gd)
9-slice-marges (in 1x-pixels): window 5, panel_status 4, window_glass 5.
De ruis/glitch-textuur in het tekstvak wordt NIET hier getekend maar live door
scripts/ui/glitch_noise.gd (dan rekt hij niet mee met het venster).
"""
from PIL import Image

from art_v7_common import rgb


def _c(h, a=255):
    return rgb(h) + (a,)


def _frame(size, rings, fill, plate=0, rivet=True, chamfer=1):
    """rings: lijst (licht, schaduw) van buiten naar binnen. plate = maat van de metalen
    hoekplaatjes (0 = geen)."""
    S = size
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    p = im.load()
    for j in range(S):
        for i in range(S):
            cx, cy = min(i, S - 1 - i), min(j, S - 1 - j)
            r = min(cx, cy, cx + cy - chamfer)
            if r < 0:
                continue
            lit = (i + j) < S - 1
            p[i, j] = (rings[r][0] if lit else rings[r][1]) if r < len(rings) else fill
    if plate:
        for (ox, oy) in ((0, 0), (S - plate, 0), (0, S - plate), (S - plate, S - plate)):
            _plate(p, ox, oy, plate, rivet)
    return im


def _plate(p, ox, oy, n, rivet):
    """Afgeschuind metalen hoekplaatje (n x n) met klinknagel."""
    out, hi, mid, lo, dark = _c("050506"), _c("b8b8be"), _c("6a6a70"), _c("34343a"), _c("1c1c20")
    for j in range(n):
        for i in range(n):
            # schuine hoekjes
            if (i + j < 1) or (i + (n - 1 - j) < 1) or ((n - 1 - i) + j < 1) or ((n - 1 - i) + (n - 1 - j) < 1):
                continue
            edge = i == 0 or j == 0 or i == n - 1 or j == n - 1
            if edge:
                col = out
            elif i == 1 or j == 1:
                col = hi if (i + j) < n else mid
            elif i == n - 2 or j == n - 2:
                col = dark
            else:
                col = mid
                if n >= 8 and (i == 2 or j == 2):
                    col = _c("85858b")
            p[ox + i, oy + j] = col
    if rivet:
        c = n // 2
        if n >= 8:
            # 3x3 bolletje: licht linksboven, donker rechtsonder
            for (dx, dy, col) in ((-1, -1, _c("e6e6ea")), (0, -1, _c("c4c4c8")), (-1, 0, _c("c4c4c8")),
                                  (0, 0, _c("9a9aa0")), (1, 0, lo), (0, 1, lo), (1, 1, dark),
                                  (1, -1, _c("8a8a90")), (-1, 1, _c("8a8a90"))):
                p[ox + c + dx - (0 if n % 2 else 1) + 1, oy + c + dy - (0 if n % 2 else 1) + 1] = col
        else:
            p[ox + c, oy + c] = _c("e0e0e4")
            if c + 1 < n - 1:
                p[ox + c + 1, oy + c + 1] = lo


def make_ui():
    out = {}
    # tekstvensters (dialoog, menu): 16x16 / 32x32
    out["window"] = _frame(16, [
        (_c("050506"), _c("050506")),
        (_c("a6a6ac"), _c("66666c")),
        (_c("0a0a0c"), _c("0a0a0c")),
    ], _c("151518"), plate=5)
    out["window_hd"] = _frame(32, [
        (_c("050506"), _c("050506")),
        (_c("b4b4ba"), _c("6a6a70")),
        (_c("8a8a90"), _c("4a4a50")),
        (_c("08080a"), _c("08080a")),
        (_c("26262b"), _c("1a1a1e")),
    ], _c("141417"), plate=10, chamfer=2)
    # statusvak en tabjes: 12x12 / 24x24
    out["panel_status"] = _frame(12, [
        (_c("050506"), _c("050506")),
        (_c("8e8e94"), _c("55555b")),
        (_c("0a0a0c"), _c("0a0a0c")),
    ], _c("131316"))
    out["panel_status_hd"] = _frame(24, [
        (_c("050506"), _c("050506")),
        (_c("9a9aa0"), _c("5a5a60")),
        (_c("3c3c42"), _c("2a2a2f")),
        (_c("08080a"), _c("08080a")),
        (_c("1e1e22"), _c("17171a")),
    ], _c("121215"), plate=0, chamfer=2)
    # kleine hoekjes op het statusvak (zoals in de mockup)
    for im, n in ((out["panel_status_hd"], 24),):
        p = im.load()
        for (x, y) in ((3, 3), (n - 6, 3), (3, n - 6), (n - 6, n - 6)):
            for dy in range(3):
                for dx in range(3):
                    p[x + dx, y + dy] = _c("7a7a80") if (dx + dy) < 2 else _c("3a3a40")
    # half-doorzichtig venster (overwinning)
    out["window_glass"] = _frame(16, [
        (_c("050506", 220), _c("050506", 220)),
        (_c("a6a6ac"), _c("66666c")),
        (_c("0a0a0c", 220), _c("0a0a0c", 220)),
    ], _c("121215", 214), plate=5)
    out["window_glass_hd"] = _frame(32, [
        (_c("050506", 220), _c("050506", 220)),
        (_c("b4b4ba"), _c("6a6a70")),
        (_c("8a8a90", 235), _c("4a4a50", 235)),
        (_c("08080a", 220), _c("08080a", 220)),
        (_c("26262b", 214), _c("1a1a1e", 214)),
    ], _c("121215", 214), plate=10, chamfer=2)
    return out


def save_all(root):
    import os
    ui = os.path.join(root, "assets", "ui")
    os.makedirs(ui, exist_ok=True)
    for name, im in make_ui().items():
        im.save(os.path.join(ui, name + ".png"))


if __name__ == "__main__":
    import os
    save_all(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
