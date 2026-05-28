"""Smoke tests for build_zone_hulls.py — convex hull only (no alphashape dep)."""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_build_hulls_basic(tmp_path):
    schools = {
        "version": "2026.05.26",
        "source": "test",
        "count": 4,
        "items": [
            {"id": "sch_a000000000", "name": "A", "district": "和平区", "level": "primary",
             "source": "JM-PDF", "zone_id": "zon_a000000000",
             "is_private": False, "is_jiunian": False, "is_market_key": False,
             "lat": 39.13, "lon": 117.20},
            {"id": "sch_b000000000", "name": "B", "district": "和平区", "level": "primary",
             "source": "JM-PDF", "zone_id": "zon_a000000000",
             "is_private": False, "is_jiunian": False, "is_market_key": False,
             "lat": 39.14, "lon": 117.21},
            {"id": "sch_c000000000", "name": "C", "district": "和平区", "level": "primary",
             "source": "JM-PDF", "zone_id": "zon_a000000000",
             "is_private": False, "is_jiunian": False, "is_market_key": False,
             "lat": 39.13, "lon": 117.22},
            {"id": "sch_d000000000", "name": "D", "district": "和平区", "level": "primary",
             "source": "JM-PDF", "zone_id": "zon_a000000000",
             "is_private": False, "is_jiunian": False, "is_market_key": False,
             "lat": 39.12, "lon": 117.21},
        ],
    }
    zones = {
        "version": "2026.05.26", "source": "test", "count": 1,
        "items": [{"id": "zon_a000000000", "district": "和平区", "zone_name": "第一学片"}],
    }
    (tmp_path / "schools.json").write_text(json.dumps(schools, ensure_ascii=False))
    (tmp_path / "zones.json").write_text(json.dumps(zones, ensure_ascii=False))
    r = subprocess.run(
        [
            sys.executable, str(ROOT / "scripts" / "build_zone_hulls.py"),
            "--schools", str(tmp_path / "schools.json"),
            "--zones", str(tmp_path / "zones.json"),
        ],
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr
    out = json.loads((tmp_path / "zones.json").read_text())
    item = out["items"][0]
    assert item["geometry_stage"] == "hull"
    assert item["geometry"]["type"] == "Polygon"
    assert len(item["geometry"]["coordinates"][0]) >= 4


def test_preserves_raster_stage(tmp_path):
    """Zones already at stage=raster should not be overwritten."""
    schools = {
        "version": "2026.05.26", "source": "test", "count": 3,
        "items": [
            {"id": f"sch_{i:010x}", "name": f"S{i}", "district": "和平区", "level": "primary",
             "source": "JM-PDF", "zone_id": "zon_a000000000",
             "is_private": False, "is_jiunian": False, "is_market_key": False,
             "lat": 39.13 + i * 0.001, "lon": 117.20 + i * 0.001}
            for i in range(3)
        ],
    }
    zones = {
        "version": "2026.05.26", "source": "test", "count": 1,
        "items": [{
            "id": "zon_a000000000", "district": "和平区", "zone_name": "第一学片",
            "geometry_stage": "raster",
            "geometry": {
                "image": "和平区学片.png",
                "corners": [[39.13, 117.20], [39.13, 117.22], [39.12, 117.22], [39.12, 117.20]],
            },
        }],
    }
    (tmp_path / "schools.json").write_text(json.dumps(schools, ensure_ascii=False))
    (tmp_path / "zones.json").write_text(json.dumps(zones, ensure_ascii=False))
    r = subprocess.run(
        [
            sys.executable, str(ROOT / "scripts" / "build_zone_hulls.py"),
            "--schools", str(tmp_path / "schools.json"),
            "--zones", str(tmp_path / "zones.json"),
        ],
        capture_output=True, text=True,
    )
    assert r.returncode == 0
    out = json.loads((tmp_path / "zones.json").read_text())
    assert out["items"][0]["geometry_stage"] == "raster"
