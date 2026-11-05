"""Tests voor maak_gpl.py en palet_check.py. Draaien: python3 -m pytest tools/art_audit"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import maak_gpl  # noqa: E402
import meet  # noqa: E402
import palet_check  # noqa: E402


def test_gpl_in_repo_loopt_gelijk_met_json() -> None:
    assert maak_gpl.main(["--check"]) == 0


def test_gpl_bevat_precies_de_json_kleuren(tmp_path: Path) -> None:
    ramps = maak_gpl.lees_bron()
    uit = tmp_path / "p.gpl"
    assert maak_gpl.main(["--uit", str(uit)]) == 0
    verwacht = {k for v in ramps.values() for k in v}
    assert meet.lees_gpl(uit) == verwacht
    assert len(verwacht) == 73


def test_fx_ramps_bestaan_in_bron() -> None:
    ramps = maak_gpl.lees_bron()
    for naam in maak_gpl.FX_RAMPS:
        assert naam in ramps, naam
    kleuren = {k for v in ramps.values() for k in v}
    for hex_ in ("40e0e8", "c8f4ff", "e040c0", "f07838", "a466f0", "8cc8a0"):
        assert tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4)) in kleuren, hex_


def test_check_mislukt_bij_afwijkend_gpl(tmp_path: Path) -> None:
    uit = tmp_path / "p.gpl"
    uit.write_text("GIMP Palette\n1 2 3\n", encoding="utf-8")
    assert maak_gpl.main(["--uit", str(uit), "--check"]) == 1


@pytest.fixture()
def assets(tmp_path: Path) -> Path:
    map_ = tmp_path / "assets"
    map_.mkdir()
    goed = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    goed.putpixel((0, 0), (16, 16, 24, 255))  # Ink/Dark 3
    goed.save(map_ / "goed.png")
    fout = Image.new("RGBA", (4, 4), (1, 2, 3, 255))
    fout.putpixel((1, 1), (4, 5, 6, 255))
    fout.save(map_ / "fout.png")
    return map_


def test_check_telt_kleuren_buiten_palet(assets: Path) -> None:
    palet = meet.lees_palet(palet_check.STANDAARD_PALET)
    rijen = palet_check.check(assets, palet)
    assert rijen[0] == ("assets/fout.png", 2, 2)
    assert rijen[1] == ("assets/goed.png", 0, 1)


def test_waarschuwt_maar_blokkeert_niet(assets: Path, capsys: pytest.CaptureFixture[str],
                                         monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GITHUB_ACTIONS", "true")
    assert palet_check.main(["--assets", str(assets)]) == 0
    uit = capsys.readouterr().out
    assert "::warning" in uit and "1 schoon, 1 met kleuren buiten" in uit
    assert palet_check.main(["--assets", str(assets), "--streng"]) == 1


def test_assets_blijven_ongewijzigd(assets: Path) -> None:
    voor = {p.name: p.read_bytes() for p in assets.iterdir()}
    palet_check.main(["--assets", str(assets)])
    assert {p.name: p.read_bytes() for p in assets.iterdir()} == voor
