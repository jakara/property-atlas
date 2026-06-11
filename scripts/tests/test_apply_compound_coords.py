"""Unit tests for apply_compound_coords.py."""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import apply_compound_coords as acc  # noqa: E402


def test_cocoa_timestamp_is_positive_and_close_to_now():
    ts = acc.cocoa_timestamp()
    # 2026-06-11 minus 2001-01-01 ≈ 25.5 years ≈ 8.05e8 seconds
    assert 7e8 < ts < 9e8


def test_cocoa_timestamp_matches_known_value():
    # 2001-01-01 00:00:01 UTC → 1.0
    fixed = datetime(2001, 1, 1, 0, 0, 1, tzinfo=timezone.utc)
    expected = (fixed - acc.COCOA_EPOCH).total_seconds()
    assert expected == pytest.approx(1.0, abs=1e-6)


def test_load_rows_parses_array(tmp_path: Path):
    p = tmp_path / "x.json"
    p.write_text(json.dumps([{"pk": 1, "lat": 39.1, "lon": 117.2, "geocode_confidence": "name"}]))
    rows = acc.load_rows(p)
    assert len(rows) == 1
    assert rows[0]["pk"] == 1


def test_load_rows_rejects_object(tmp_path: Path):
    p = tmp_path / "x.json"
    p.write_text(json.dumps({"items": []}))
    with pytest.raises(SystemExit):
        acc.load_rows(p)


def test_ensure_app_closed_exits_when_running(monkeypatch):
    # Simulate pgrep finding PropertyAtlas.app
    monkeypatch.setattr(subprocess, "run",
                        lambda *a, **kw: subprocess.CompletedProcess(args=(), returncode=0, stdout=b"1234\n"))
    with pytest.raises(SystemExit) as exc:
        acc.ensure_app_closed()
    assert exc.value.code == 2


def test_ensure_app_closed_passes_when_not_running(monkeypatch):
    # Simulate pgrep finding nothing
    monkeypatch.setattr(subprocess, "run",
                        lambda *a, **kw: subprocess.CompletedProcess(args=(), returncode=1, stdout=b""))
    # Should NOT raise
    acc.ensure_app_closed()
