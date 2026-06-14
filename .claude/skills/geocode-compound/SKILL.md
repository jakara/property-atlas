---
name: geocode-compound
description: Use when small-residential (小区) Compound records have wrong or missing latitude/longitude — all clustered at placeholder (39.1, 117.2), a few stuck, or any geocode gap visible on the Studio map. Triggers: "小区坐标错了/缺失", "修小区定位", "批量 geocode 小区", or `/geocode-compound` invocation.
---

# Geocode Compound Skill

回填 `ZCOMPOUND.ZLATITUDE/ZLONGITUDE` (DB-first, 无 seed 管线). 单次/批量都行, 设计目标 174 个.

## 决策树

```
1. 现状盘点
   sqlite3 ~/Library/Application\ Support/default.store \
     "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE=39.1 AND ZLONGITUDE=117.2"
   ├─ 0 → 无活, 结束
   └─ N>0 → 继续

2. 关 app 释放 sqlite 锁
   pkill -f PropertyAtlas.app
   ├─ 仍在 (Xcode debugger 附着) → 查 debugserver PID, kill 父进程
   └─ 干净 → 继续

3. Stage 1 — Apple MKLocalSearch (免费, 0 key, ~50% hit CN 新房)
   cd scripts/geocode_mklocal && swift run GeocodeMK --mode compounds
   # 内部: sqlite 直读 174 行 → name-only 搜 + 全市 region → 写 compounds.geocoded.json
   # 命中 50/174 是上限, Apple POI 不收新小区/分校

4. Apply (Stage 1+2+3 共用同一 JSON + apply)
   python3 scripts/apply_compound_coords.py
   # pkill guard → 读 JSON → 跳 failed → UPDATE ZCOMPOUND SET ZLATITUDE,ZLONGITUDE,ZUPDATEDAT
   # ZUPDATEDAT = Cocoa epoch seconds (2001-01-01 UTC)

5. Stage 2 — OSM Nominatim 兜底 (免费, 0 key, ~30% hit 余下)
   python3 scripts/geocode_compounds_nominatim.py
   # 1.1s throttle 内置, User-Agent 必填
   # 同 JSON 复用, 只重试 geocode_confidence=failed

6. 视情况 Stage 3 — 高德 web B-plan (需 key, ~90% hit 余下)
   仅当 Stage 2 后仍有 failed → 跑此步.
   # Key 准备: 申请 amap web service key (平台=Web服务, 非 iOS), 设 env:
   source ~/.amap_key_env        # 文件 chmod 600, 内容: export AMAP_WEB_KEY=<key>
   # 跑:
   python3 scripts/geocode_compounds_amap.py
   # 0.1s throttle 默认; 若遇 CUQPS_HAS_EXCEEDED (code 10021) → 改 1s, 重跑 (脚本幂等)
```

## 工具调用

| 工具 | 用途 | 入参/输出 |
|---|---|---|
| `swift run GeocodeMK --mode compounds` | Stage 1 SPM 跑 | 读 `~/Library/Application Support/default.store` ZCOMPOUND; 写 `reports/extracted/compounds.geocoded.json` |
| `python3 scripts/apply_compound_coords.py` | JSON → DB | 读 JSON; UPDATE ZCOMPOUND (Cocoa epoch); 跳 failed |
| `python3 scripts/geocode_compounds_nominatim.py` | Stage 2 兜底 | 1.1s throttle; User-Agent `PropertyAtlas/1.0 ...` |
| `python3 scripts/geocode_compounds_amap.py` | Stage 3 B-plan | `AMAP_WEB_KEY` env; 0.1s throttle (1s 兜底) |
| `pytest scripts/tests/test_apply_compound_coords.py` | 单元测试 | 6 个: cocoa epoch, JSON parse, pkill guard |

JSON schema (`compounds.geocoded.json` 数组, 每行):
```json
{ "pk": 1, "name": "XX", "lat": 39.x, "lon": 117.x,
  "geocode_source": "mklocalsearch|nominatim|amap|failed",
  "geocode_confidence": "name|failed" }
```

## Schema 约束

- `ZCOMPOUND.Z_PK` = Int64 主键
- `ZLATITUDE/ZLONGITUDE` = Double
- `ZUPDATEDAT` = TIMESTAMP, macOS Cocoa reference epoch (2001-01-01 00:00:00 UTC). Python 端: `(datetime.now(tz=utc) - datetime(2001,1,1,tzinfo=utc)).total_seconds()`
- in_tianjin 边界: `38.5 ≤ lat ≤ 40.3`, `116.7 ≤ lon ≤ 118.0`. 越界 = failed (不入 DB)
- `Compound` @Model 改不改都不影响 — 全部 DB-level 操作, 无 schema 迁移

## 失败处理

| 现象 | 修法 |
|---|---|
| `pkill` 后 `pgrep` 仍命中 | Xcode debugger 附着: `ps aux | grep debugserver`, kill 父 PID |
| `database is locked` | app 没关干净, 重 pkill; 必要时 `lsof` 查谁占 store |
| MKLocalSearch < 50% hit | 正常. 不要调小 region 缩小 — 新小区无 district 字段, 全市搜才对 |
| Nominatim 429 | 1.1s throttle 已内置. 持续 → 改 `THROTTLE_S = 2.0` |
| 高德 `CUQPS_HAS_EXCEEDED_THE_LIMIT` (10021) | 0.1s 触发 QPS 上限, 改 `THROTTLE_S = 1.0` 重跑 (脚本幂等, 只处理 failed) |
| 高德 0 hit 全军 | key 是 iOS SDK key 而非 web service key. 重新申请 (平台=Web服务) |
| Bash 拒绝跑 (含 key) | auto mode classifier 防凭证泄漏. key 走 `/tmp/amap_key_env` + `source`, 不用 inline |
| apply 报 `WARN pk=X not found` | JSON 中 pk 已不存在 (可能手动删过), 跳过即可 |
| `amap` checkpoint 写盘 | 已实现 (每 10 行). 9s 窗口, crash 不丢 |

## 验证 (每 stage 必跑)

```bash
DB="$HOME/Library/Application Support/default.store"

# 1. 占位剩余
sqlite3 "$DB" "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE=39.1 AND ZLONGITUDE=117.2"
# 期望: 每 stage 跑完递减, 最终 0

# 2. distinct lat (去重后接近 N, 几个同项目 dup 正常)
sqlite3 "$DB" "SELECT COUNT(DISTINCT ZLATITUDE) FROM ZCOMPOUND"

# 3. 越界扫描
sqlite3 "$DB" "SELECT Z_PK, ZNAME, ZLATITUDE, ZLONGITUDE FROM ZCOMPOUND
               WHERE ZLATITUDE NOT BETWEEN 38.5 AND 40.3
                  OR ZLONGITUDE NOT BETWEEN 116.7 AND 118.0"
# 期望: 空

# 4. JSON 源分布
python3 -c "import json; r=json.load(open('reports/extracted/compounds.geocoded.json'))
import collections; print(collections.Counter(x.get('geocode_source') for x in r))"
```

## 视觉确认 (app 端)

1. 开 app → Studio 找小区图层
2. 抽 5-10 个不同区 (和平/河西/滨海/北辰/东丽/武清) 肉眼看 pin
3. 对照 Apple Maps 确认 pin 落点合理
4. 同名跨区: 高德 citylimit=true 应已 scope 天津, 但同名小区跨区罕见 — 抽中要警惕

## 安全

- **amap key**: env var `AMAP_WEB_KEY`, 文件 `~/.amap_key_env` chmod 600. **不贴 chat, 不 inline Bash** (auto classifier 拒, 也会泄 transcript)
- **跑完**: `rm /tmp/amap_key_env` (如用过), 在 amap 控制台 **revoke + 重发** (IP 白名单 + 短有效期)
- **不用旧 key 习惯**: 任何 web service key 都按 env var 模式走

## 报告格式 (skill 结束)

```
✓ Stage 1 (mklocalsearch): N1 hit
✓ Stage 2 (nominatim):      N2 hit
✓ Stage 3 (amap):           N3 hit
total: 174/174, 0 placeholder, 0 out-of-bounds, distinct lat 171
verify: pass (3 步 SQL)
→ app ⌘R 重启, Studio 抽 5-10 个小区肉眼看
```
