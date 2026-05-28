#!/usr/bin/env python3
"""填充小学 tier_label (重点/区重点/普通) — 数据来源: 多源网络核实

源 (4 个跨核, 2025-05-28 抓取):
  - ruisi 2025 排名: https://ruisi.ruisichina.cn/hotnews/20096.html
  - JiXiao100 重点/优质: https://m.jixiao100.com/127482.html
  - QQ News 2023 排名: https://news.qq.com/rain/a/20231103A034A700
  - 智慧山 和平 6小强: https://www.zhihuishan.com/gushi-view-23729.html

规则:
  - 重点 = 多源公认第一梯队 (强 consensus)
  - 区重点 = 第二梯队 (≥1 源标 T2 且不与他源 T1 冲突)
  - 其余 = 不写 tier_label (DB 默认 普通, 保留 "无核实" 语义)

只填 市内6区 (其他区域无公开评级源).
"""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHOOLS = REPO / "reports/extracted/schools.json"

SOURCES = [
    "https://ruisi.ruisichina.cn/hotnews/20096.html",
    "https://m.jixiao100.com/127482.html",
    "https://news.qq.com/rain/a/20231103A034A700",
    "https://www.zhihuishan.com/gushi-view-23729.html",
]

# 多源 cross-check 后人工合并的市内6区分级 (2025-05-28 数据点)
KEY_PRIMARIES = {
    "和平区": {
        "重点": [
            "实验小学", "岳阳道小学", "昆明路小学",
            "中心小学(和平区中心小学)",  # 即"和平中心小学"
            "鞍山道小学", "万全小学",
        ],
        "区重点": [
            "模范小学",
            "逸阳梅江湾学校",  # 即"逸阳小学"
            "新星小学",
            "第二南开学校", "耀华小学",
            "新华南路小学", "二十中学附属小学", "西康路小学",
        ],
    },
    "河西区": {
        "重点": [
            "上海道小学", "台湾路小学",
            "天津师范大学第二附属小学", "中心小学", "闽侯路小学",
        ],
        "区重点": [
            # 注: 部分名校 DB 不含 (三水道/华江里 等); 跳过避免误匹配
        ],
    },
    "南开区": {
        "重点": [
            "中营小学", "五马路小学", "东方小学",
            "南大附小",   # 即"南开大学附属小学"
            "天大附小",   # 即"天津大学附属小学"
        ],
        "区重点": [
            "中心小学", "南开小学", "科技实验小学",
            "师大南开附小",  # 即"天津师范大学南开附属小学"
        ],
    },
    "河东区": {
        "重点": [
            "实验小学", "第一中心小学", "缘诚小学",
        ],
        "区重点": [
            "香山道小学", "互助道小学",
        ],
    },
    "河北区": {
        "重点": [
            "昆纬路第一小学", "实验小学", "扶轮小学", "育婴里小学",
        ],
        "区重点": [
            "光明小学", "育婴里第二小学",
        ],
    },
    "红桥区": {
        "重点": [
            "实验小学", "中心小学",
            "师范学校附属小学",
        ],
        "区重点": [
            "红桥小学", "雷锋小学",
        ],
    },
}


def normalize(name: str) -> str:
    """去前缀, 便于匹配 (如 '天津市河西区上海道小学' → '上海道小学')."""
    n = name
    for prefix in ["天津市", "天津", "和平区", "河西区", "南开区",
                   "河东区", "河北区", "红桥区"]:
        n = n.replace(prefix, "")
    return n.strip()


def find_school(items, district, target):
    target_n = normalize(target)
    candidates = [s for s in items
                  if s["district"] == district
                  and s["level"] == "primary"]
    # 精确
    for s in candidates:
        if normalize(s["name"]) == target_n:
            return s
    # 包含
    for s in candidates:
        n = normalize(s["name"])
        if target_n in n or n in target_n:
            return s
    return None


def main():
    data = json.loads(SCHOOLS.read_text(encoding="utf-8"))
    items = data["items"]

    matched, unmatched = 0, []
    for district, tiers in KEY_PRIMARIES.items():
        for tier_label, names in tiers.items():
            for nm in names:
                sch = find_school(items, district, nm)
                if sch is None:
                    unmatched.append((district, tier_label, nm))
                    continue
                sens = sch.get("sensitive") or {}
                sens["tier_label"] = tier_label
                sens["source"] = "WebResearch"
                sens["source_url"] = SOURCES[0]  # primary source
                note_parts = [
                    f"小学分级 web-research; 多源核实({len(SOURCES)} 源)",
                    f"全部源: {'; '.join(SOURCES)}",
                ]
                sens["note"] = " | ".join(note_parts)
                sch["sensitive"] = sens
                matched += 1

    SCHOOLS.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"matched: {matched}")
    print(f"unmatched: {len(unmatched)}")
    for u in unmatched:
        print(f"  ✗ {u[0]} / {u[1]} / {u[2]}")


if __name__ == "__main__":
    main()
