"""Tests voor meet.py. Draaien: python3 -m pytest tools/art_audit

De drie test-PNG's worden in een tijdelijke map gemaakt, zodat er geen binaire
bestanden in de repo komen en Godot ze niet importeert.
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import meet  # noqa: E402

ROOD = (255, 0, 0, 255)
GROEN = (0, 255, 0, 255)
BLAUW = (0, 0, 255, 255)
LEEG = (0, 0, 0, 0)


@pytest.fixture()
def assets(tmp_path: Path) -> Path:
    map_ = tmp_path / "assets"
    (map_ / "sub").mkdir(parents=True)

    # 1) 16x16, alleen rood en groen, harde alpha
    tegel = Image.new("RGBA", (16, 16), ROOD)
    for x in range(8):
        tegel.putpixel((x, 0), GROEN)
    tegel.save(map_ / "tegel.png")

    # 2) 20x16, rood + blauw + transparant, 3 semi-transparante pixels
    sprite = Image.new("RGBA", (20, 16), LEEG)
    sprite.putpixel((0, 0), ROOD)
    sprite.putpixel((1, 0), BLAUW)
    sprite.putpixel((2, 0), (255, 0, 0, 128))
    sprite.putpixel((3, 0), (255, 0, 0, 1))
    sprite.putpixel((4, 0), (0, 0, 255, 254))
    sprite.save(map_ / "sub" / "sprite.png")

    # 3) 32x32 RGB zonder alpha, één kleur
    Image.new("RGB", (32, 32), (10, 20, 30)).save(map_ / "sub" / "vlak.png")
    return map_


def _meet(assets: Path, tmp_path: Path, palet: set | None = None) -> dict[str, dict[str, str]]:
    uit = tmp_path / "art_meting.csv"
    assert meet.meet_map(assets, uit, palet) == 3
    with uit.open(newline="", encoding="utf-8") as f:
        lezer = csv.DictReader(f)
        assert lezer.fieldnames == meet.KOLOMMEN
        return {rij["pad"]: rij for rij in lezer}


def test_meting_zonder_palet(assets: Path, tmp_path: Path) -> None:
    rijen = _meet(assets, tmp_path)
    assert sorted(rijen) == ["assets/sub/sprite.png", "assets/sub/vlak.png", "assets/tegel.png"]

    tegel = rijen["assets/tegel.png"]
    assert (tegel["breedte"], tegel["hoogte"], tegel["deelbaar_door_16"]) == ("16", "16", "ja")
    assert tegel["unieke_kleuren"] == "2"
    assert tegel["buiten_palet"] == ""
    assert (tegel["alpha_alleen_0_255"], tegel["semi_transparant"]) == ("ja", "0")

    sprite = rijen["assets/sub/sprite.png"]
    assert (sprite["breedte"], sprite["hoogte"], sprite["deelbaar_door_16"]) == ("20", "16", "nee")
    assert sprite["unieke_kleuren"] == "5"
    assert (sprite["alpha_alleen_0_255"], sprite["semi_transparant"]) == ("nee", "3")

    vlak = rijen["assets/sub/vlak.png"]
    assert (vlak["deelbaar_door_16"], vlak["unieke_kleuren"]) == ("ja", "1")
    assert (vlak["alpha_alleen_0_255"], vlak["semi_transparant"]) == ("ja", "0")


def test_palet_gpl_en_png(assets: Path, tmp_path: Path) -> None:
    gpl = tmp_path / "master.gpl"
    gpl.write_text("GIMP Palette\nName: test\nColumns: 2\n#\n255   0   0\trood\n  0 255   0\tgroen\n",
                   encoding="utf-8")
    png = tmp_path / "master.png"
    palet_img = Image.new("RGBA", (3, 1), LEEG)
    palet_img.putpixel((0, 0), ROOD)
    palet_img.putpixel((1, 0), GROEN)
    palet_img.save(png)

    assert meet.lees_palet(gpl) == {(255, 0, 0), (0, 255, 0)}
    assert meet.lees_palet(png) == {(255, 0, 0), (0, 255, 0)}

    rijen = _meet(assets, tmp_path, meet.lees_palet(gpl))
    assert rijen["assets/tegel.png"]["buiten_palet"] == "0"
    assert rijen["assets/sub/sprite.png"]["buiten_palet"] == "1"  # alleen blauw
    assert rijen["assets/sub/vlak.png"]["buiten_palet"] == "1"


def test_assets_worden_niet_gewijzigd(assets: Path, tmp_path: Path) -> None:
    voor = {p: (p.stat().st_mtime_ns, p.read_bytes()) for p in assets.rglob("*.png")}
    _meet(assets, tmp_path)
    assert {p: (p.stat().st_mtime_ns, p.read_bytes()) for p in assets.rglob("*.png")} == voor


def test_cli_schrijft_csv(assets: Path, tmp_path: Path) -> None:
    uit = tmp_path / "cli.csv"
    assert meet.main(["--assets", str(assets), "--uit", str(uit)]) == 0
    assert len(uit.read_text(encoding="utf-8").splitlines()) == 4
