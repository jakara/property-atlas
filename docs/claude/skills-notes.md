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

## `geocode-compound`
触发: `/geocode-compound` 或自然语 "小区坐标错了 / 修小区定位 / 批量 geocode 小区". 详见 `.claude/skills/geocode-compound/SKILL.md`. 流程: MKLocalSearch (50%) → Nominatim (30%) → 高德 web B-plan (90%). 写 ZCOMPOUND, Cocoa epoch. DB-first 无 seed 管线.

## Geocode 经验 — 学校 (Apple MKLocalSearch)
- **search region 必须够宽** (>= 0.6° span 全市) — 否则窄区 (如和平区 0.04°) 搜不到跨区物理位置的校
- Apple POI 教育归属 ≠ 物理位置 — 模范小学 (和平归属, 校址南开华苑) / 第二耀华 (和平归属, 校址东丽登州路) / 三毛艺术 (和平归属, 校址河东和平村增产巷)
- query 用全 address ("中国天津市X区Y路Z号") + `resultTypes = [.pointOfInterest, .address]` 命中率高
- 约 350-500 校 mklocalsearch 命中, 其余分校/民办/小校 Apple POI 不收录 → fail, lat/lon=null → app 不渲染 pin
- `CLGeocoder` headless 卡死, 必须 NSApplication 上下文

## Geocode 经验 — 小区 (多源 pipeline)
- **Compound 无 district/address 字段**, XLSX 源亦无 → name-only 搜, region 必全市 (`_TIANJIN_` 中心)
- 三源命中率: MKLocalSearch 50/174, Nominatim 37/124 余下, 高德 87/87 (QPS 内近全 hit)
- **高德 key 必须 web service key** (平台=Web服务), iOS SDK key 走 HTTP API 拒
- **高德 QPS 限流**: 0.1s throttle 触发 `CUQPS_HAS_EXCEEDED_THE_LIMIT` (code 10021); 改 1s 兜底. 脚本幂等 (只重试 failed)
- **Nominatim 1.1s throttle + User-Agent** 是 ToS 要求, 缺 UA 被 403
- **Bash 含 key 会被 auto mode 拒** — 用 `/tmp/amap_key_env` (chmod 600) + `source`, 别 inline
- **Cocoa epoch 写错 → ZUPDATEDAT 异常** — Python: `(now - datetime(2001,1,1,tz=utc)).total_seconds()`
- **sqlite 锁**: pkill 后 `pgrep` 仍命中 = Xcode debugger 附着, 查 `debugserver` 父 PID kill
