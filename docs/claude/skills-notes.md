# Skills (project-level)

`.claude/skills/<name>/SKILL.md` — 自动加载.

## `add-school`
触发: `/add-school <校名> [区]` 或自然语 "添加 XX 小学". 流程:
1. 查 schools.json (完匹 + fuzzy bigram Jaccard ≥0.5)
2. 无匹配 → WebSearch **≥2 独立源** cross-check (强制)
3. 调 `scripts/add_school.py` 写入条目
4. `cd scripts/geocode_mklocal && swift run GeocodeMK` 补 lat/lon
5. 全自动 pipeline: validate + hulls + MD + cp seeds
6. 提示 app ⌘⇧R 重载

## Geocode 经验 (Apple MKLocalSearch)
- **search region 必须够宽** (>= 0.6° span 全市) — 否则窄区 (如和平区 0.04°) 搜不到跨区物理位置的校
- Apple POI 教育归属 ≠ 物理位置 — 模范小学 (和平归属, 校址南开华苑) / 第二耀华 (和平归属, 校址东丽登州路) / 三毛艺术 (和平归属, 校址河东和平村增产巷)
- query 用全 address ("中国天津市X区Y路Z号") + `resultTypes = [.pointOfInterest, .address]` 命中率高
- 约 350-500 校 mklocalsearch 命中, 其余分校/民办/小校 Apple POI 不收录 → fail, lat/lon=null → app 不渲染 pin
- `CLGeocoder` headless 卡死, 必须 NSApplication 上下文
