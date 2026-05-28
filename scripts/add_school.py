#!/usr/bin/env python3
"""新增/更新 schools.json 学校条目.

调用方: claude code skill add-school. 不跑 validate (skill 显式 call).

例:
  python3 scripts/add_school.py --name 求真小学 --district 红桥区 \
      --address 天津市红桥区... --level primary \
      --tier 重点 --source-url https://... https://...
"""
import argparse
import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHOOLS = REPO / "reports/extracted/schools.json"

DISTRICTS = {
    "和平区", "河西区", "南开区", "河东区", "河北区", "红桥区",
    "北辰区", "西青区", "津南区", "东丽区",
    "武清区", "宝坻区", "静海区", "宁河区", "蓟州区", "滨海新区",
    "塘沽区", "大港区",
}
LEVELS = {"primary", "middle"}
TIER_LABELS = {
    "顶尖", "强校", "优质", "中上", "中档", "中下", "偏弱", "垫底",
    "新办", "未知", "重点", "区重点", "良好", "普通",
}


def gen_id(district: str, name: str) -> str:
    h = hashlib.md5(f"{district}{name}".encode("utf-8")).hexdigest()
    return f"sch_{h[:10]}"


def find_existing(items, name, district):
    for s in items:
        if s.get("name") == name and s.get("district") == district:
            return s
    return None


def _normalize_for_fuzzy(n: str) -> str:
    """去常见无关字符, 便于 char-set 比较."""
    for token in ["天津市", "天津",
                  "和平区", "河西区", "南开区", "河东区", "河北区", "红桥区",
                  "(民办)", "(公办)", "校区", "学校",
                  " ", "　"]:
        n = n.replace(token, "")
    return n


def _bigrams(s: str) -> set:
    if len(s) < 2:
        return {s}
    return {s[i: i + 2] for i in range(len(s) - 1)}


def fuzzy_candidates(items, name, district, threshold=0.5):
    """返回 (Jaccard score, item) 列表 ≥ threshold, 按 score 降排."""
    target = _bigrams(_normalize_for_fuzzy(name))
    if not target:
        return []
    results = []
    for s in items:
        if s.get("district") != district:
            continue
        cand = _bigrams(_normalize_for_fuzzy(s.get("name", "")))
        if not cand:
            continue
        inter = len(target & cand)
        union = len(target | cand)
        if union == 0:
            continue
        score = inter / union
        if score >= threshold:
            results.append((score, s))
    return sorted(results, key=lambda x: -x[0])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--district", required=True, choices=sorted(DISTRICTS))
    ap.add_argument("--level", choices=sorted(LEVELS), default="primary")
    ap.add_argument("--address")
    ap.add_argument("--phone")
    ap.add_argument("--is-private", action="store_true")
    ap.add_argument("--is-jiunian", action="store_true")
    ap.add_argument("--lat", type=float)
    ap.add_argument("--lon", type=float)
    ap.add_argument("--geocode-source", default="manual")
    ap.add_argument("--tier", choices=sorted(TIER_LABELS))
    ap.add_argument("--source-url", nargs="+", default=[],
                    help="≥2 url for cross-check (skill enforces)")
    ap.add_argument("--source", default="WebResearch",
                    help="信源缩写 (默认 WebResearch)")
    ap.add_argument("--note")
    ap.add_argument("--force", action="store_true",
                    help="跳过 fuzzy 去重检查 (确认是新校时用)")
    args = ap.parse_args()

    data = json.loads(SCHOOLS.read_text(encoding="utf-8"))
    items = data["items"]

    existing = find_existing(items, args.name, args.district)
    if existing is not None:
        action = "update"
        item = existing
    else:
        # Fuzzy 去重: 检查同区是否有近似名 (Jaccard bigram ≥ 0.5)
        if not args.force:
            cands = fuzzy_candidates(items, args.name, args.district)
            if cands:
                import sys
                print(f"⚠ 同区疑似重复 ({args.district} / {args.name}):", file=sys.stderr)
                for score, s in cands[:5]:
                    print(f"  [{score:.2f}] {s['id']} | {s['name']}", file=sys.stderr)
                print("→ 确认是新校 → 加 --force 重跑; 否则请用现有 id update", file=sys.stderr)
                sys.exit(2)
        action = "new"
        item = {
            "id": gen_id(args.district, args.name),
            "name": args.name,
            "district": args.district,
            "level": args.level,
            "source": "WebResearch",
        }
        items.append(item)

    if args.address is not None:
        item["address"] = args.address
    if args.phone is not None:
        item["phone"] = args.phone
    if args.is_private:
        item["is_private"] = True
    if args.is_jiunian:
        item["is_jiunian"] = True
    if args.lat is not None and args.lon is not None:
        item["lat"] = args.lat
        item["lon"] = args.lon
        item["geocode_source"] = args.geocode_source
        item["geocode_confidence"] = "manual" if args.geocode_source == "manual" else "name"

    if args.tier or args.source_url:
        sens = item.get("sensitive") or {}
        if args.tier:
            sens["tier_label"] = args.tier
        sens["source"] = args.source
        if args.source_url:
            sens["source_url"] = args.source_url[0]
            sens["note"] = (
                f"web-research; 多源核实({len(args.source_url)} 源); "
                f"全部源: {'; '.join(args.source_url)}"
            )
        if args.note:
            sens["note"] = args.note + " | " + sens.get("note", "")
        item["sensitive"] = sens

    # 保证 count 准确
    data["count"] = len(items)
    SCHOOLS.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"{action}: {item['id']} | {args.district} | {args.name}")


if __name__ == "__main__":
    main()
