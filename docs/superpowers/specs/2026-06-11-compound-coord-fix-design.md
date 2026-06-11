# Compound Coord Fix Design

**Date**: 2026-06-11
**Status**: Draft
**Owner**: akara

## Problem

`ZCOMPOUND` 表 174 行, `ZLATITUDE/ZLONGITUDE` 全部 `(39.1, 117.2)` 兜底值. 来源
YH-XLSX(永辉选房 2026 新房清单)无原始坐标/街道/门牌, 只含 `行政区` + `项目名称`.
`Compound` @Model 也无 `district/address` 字段(实表确认无 `ZDISTRICT` 列,
`ZADDRESS` 全 NULL).

后果: 地图上所有小区 pin 叠在一个点; 学区图、片区、关联图全部失真.

## Goal

一次性 backfill 174 个小区的真实坐标, 优先复用现成 `geocode_mklocal`
(Apple MKLocalSearch), 0 成本 0 key.

不修学校(走 `auto_geocode.py` 旧路径, 已 OK); 不动学区/学校 schema.

## Non-Goals

- 增量/重跑(无 `geocode_source` 列持久化旧状态)
- 落空回退到 1-3km jitter(等于不修, 留坑给将来手填或 B 方案)
- 学校重新 geocode
- `Compound` @Model schema 改动(避 SwiftData 迁移)
- CloudKit 同步(延后)

## Approach

复用 `scripts/geocode_mklocal/` SPM, 新增 `--mode compounds` 分支:

1. SPM 读 sqlite `ZCOMPOUND` (`Z_PK, ZNAME`) → 174 行
2. 每行 name-only 搜 MKLocalSearch, region = 全市(`_TIANJIN_` 中心)
3. 命中 → 写 `compounds.geocoded.json` (id, lat, lon, source, confidence)
4. `apply_compound_coords.py` 读 JSON → `UPDATE ZCOMPOUND SET ZLATITUDE, ZLONGITUDE, ZUPDATEDAT WHERE Z_PK=?`
5. 落空 → JSON 标 `geocode_confidence=failed` + 不写 DB

**重要发现**:
- `ZDISTRICT` 列**不存在** (SQLite schema 确认), 无 district 缩小 region
- `ZADDRESS` 全 NULL, XLSX 无此字段, 只能 name 搜
- 无 `geocode_source`/`geocode_confidence` 列于 `ZCOMPOUND` → 元数据存 JSON 备查, 不入 DB

## Data Flow

```
~/Library/Application Support/default.store (ZCOMPOUND, 174 rows)
        │
        │ GeocodeMK --mode compounds
        ▼
MKLocalSearch (name + whole-Tianjin region)
        │
        │ Throttle 200ms
        ▼
reports/extracted/compounds.geocoded.json
        │
        │ apply_compound_coords.py
        ▼
UPDATE ZCOMPOUND SET ZLATITUDE, ZLONGITUDE, ZUPDATEDAT
```

## Components

### 1. `scripts/geocode_mklocal/Sources/GeocodeMK/main.swift`

- 新增 `mode` 解析: `--mode schools|compounds` (默认 schools, 向后兼容)
- 新增 `loadCompounds(path: String) -> [(pk: Int64, name: String)]`:
  - 用 `sqlite3` C API(SPM 加 `linkerSettings: ["-lsqlite3"]`)或进程内 shell `sqlite3` 命令
  - 优先: 进程内 `sqlite3_open` 直读, 避免并发
- 新增 `saveCompounds(_ results: [[String: Any]], to path: String)`: 写 `compounds.geocoded.json`
- 复用 `regions` map / `inTianjin` / `search(name,district)` 全部
- compounds mode 单 pass: `search(name: name, district: "_TIANJIN_")` (district 不是字段, 永远走全市 region)

### 2. `scripts/apply_compound_coords.py` (新)

```python
# 读 compounds.geocoded.json
# UPDATE ZCOMPOUND SET ZLATITUDE=?, ZLONGITUDE=?, ZUPDATEDAT=? WHERE Z_PK=?
# 跳过 geocode_confidence == "failed" 行
# ZUPDATEDAT = 当前时间 (Cocoa reference epoch: 978307200 秒后)
```

- 路径: `~/Library/Application Support/default.store` (硬编码, 同 `swiftdata-store.md`)
- 写前断言: 应用未在跑 (`pkill -f PropertyAtlas.app` exit 0)
- SwiftData 时间戳: macOS Cocoa reference date epoch (2001-01-01 00:00:00 UTC), 用 `datetime - COCOA_EPOCH` 转秒

### 3. `Compound.swift` — **不改**

## Concurrency

- SPM 跑前: `pkill -f PropertyAtlas.app` (释放 sqlite 锁)
- SPM 跑时: app 不可开
- SPM 跑后: 启 app, SwiftData 读新坐标, Studio 渲染新区位
- throttle: `Task.sleep(200ms)` 每行 (Apple POI 无文档限制, 礼貌性)

## Failure Handling

| 失败点 | 行为 |
|---|---|
| sqlite 打开失败 | SPM 退出码 1, stderr 报错 |
| MKLocalSearch 落空 | 写 `geocode_confidence=failed` 到 JSON, 不入 DB |
| 命中但越界 (out of Tianjin 38.5-40.3 / 116.7-118.0) | 跳过, 标 failed (`inTianjin` 已验) |
| apply script 时 app 在跑 | 退码 2 + stderr "app running, pkill first" |
| JSON 缺 pk | 跳过单行 + 计数 warn |

## Verification

**跑前**:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE=39.1 AND ZLONGITUDE=117.2"
# 期望 174
```

**跑 SPM**:
```bash
pkill -f PropertyAtlas.app
cd scripts/geocode_mklocal && swift run GeocodeMK --mode compounds
# ~5-10 min, 174 × 200ms
```

**跑 apply**:
```bash
python3 scripts/apply_compound_coords.py
# exit 0, 打印 "updated N / M"
```

**跑后**:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE=39.1 AND ZLONGITUDE=117.2"
# 期望 0 (除非有 hit 落空后未写, 即源 = failed)

sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(DISTINCT ZLATITUDE) FROM ZCOMPOUND"
# 期望 >> 1 (174 distinct 或 close)

sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT Z_PK, ZNAME, ZLATITUDE, ZLONGITUDE FROM ZCOMPOUND
   WHERE ZLATITUDE NOT BETWEEN 38.5 AND 40.3
      OR ZLONGITUDE NOT BETWEEN 116.7 AND 118.0"
# 期望 空
```

**肉眼抽检**: 启 app, Studio 找 5-10 个小区, 对照 Apple Maps 确认 pin 位置合理.

## Risks

- **命中率**: Apple MKLocalSearch CN 小区 POI 覆盖 ~70-85%, 落空 ~20-30% 留坑. 若命中率 <50% 改走 B 方案(高德 POI 搜索, 需 free key).
- **重复名**: 同名小区跨区罕见但有, name-only 全市搜可能取错. 落空/异常肉眼抽检捕捉.
- **Cocoa epoch**: SwiftData 时间戳是 macOS reference date. 写错 epoch → ZUPDATEDAT 异常, 不影响渲染但 sync 逻辑可能挂. 沿用现 SwiftData 写入路径 (Python 用 `datetime.utcnow() - datetime(2001,1,1,tzinfo=utc)`).
- **DB 锁**: SPM 跑时 app 必须关, 否则 sqlite `database is locked`.

## Out of Scope (deferred)

- B 方案 (高德/天地图 POI 搜索) — 留作命中率补救
- 学校重新 geocode — 不在本任务
- `geocode_source`/`geocode_confidence` 入 `ZCOMPOUND` — 需要 schema 迁移, 不做
- 增量 re-run (按 confidence=suboptimal 重跑) — 元数据无列, 不做
- 手动修正 UI — 留 P10+
