---
name: fetch-road-lines
description: 联网抓取命名道路折线(如天津三环十四射)→ 打包成 Area 折线 seed。用户说"获取道路 geo""拉某条/某些路的线""刷新 road_lines"时用。源 = OSM Overpass(免 key, WGS→GCJ 转换)。
---

# Fetch Road Lines

抓取**命名道路的折线**(LineString),产出 `road_lines.json`,app 首启动 seed 成 Area 折线(`geometryKind="line"`, `category="道路"`,环/射进 `tags`)。

触发: "获取天津三环十四射" / "拉 XX 路的线" / "更新道路 geo" / `/fetch-road-lines`。

## 源 = OSM Overpass(免 key 免额度)

- 端点: `https://overpass-api.de/api/interpreter`(POST `data=`,**必须带 User-Agent**,否则 406)。
- 按 `way["highway"]["name"~"<正则>"]` + bbox + `out geom;` 取 way 内联坐标。
- **坐标 = WGS-84 → 必须转 GCJ-02**(脚本内 `wgs2gcj`,标准 eviltransform 公式)。app/底图是 GCJ-02,见 [[coordinate-system-gcj02]]。
- 公共端点**限流**: 脚本每路间隔 6s + 失败指数退避;别并发狂刷(会空响应/429)。

### 为什么不用高德
高德普通 API(地理编码/POI/路径规划)**拿不到道路本身中线几何**——只给点或 OD 路线。能给道路折线的只有高德 `traffic/status/road`(GCJ 原生但按拥堵分段、需 key 占额度)。OSM 免额度更省,故默认 OSM。

## 关键: 道路在 OSM 是分段 + 命名浮动

- 环路按方向拆段: `中环东路`/`中环南路`/`中环西路`/`中环北路` 等 → 用正则 `^中环.*路$` 收全,脚本贪心按端点缝合成一条 LineString。
- 十四射名称**随版本/口径浮动**(老版 vs 2017 后),需按实际命中调。已知候选: 西青道、复康路、卫津(南)路、友谊(南)路、大沽(南)路、津滨大道、卫国道、新开路、中山北路、解放路、金钟河大街、津塘公路、新宜白大道 等。
- 先跑一遍看 report 哪些命中/空,空的改 `scripts/fetch_road_lines.py` 里 `ROADS` 的 `match` 正则(可先用 `name~"中环"` 探名: `out tags;` 看实际 name)再重跑。

## 步骤

1. (可选)探名: 改 bbox/正则单查某模式确认 OSM 实际道路名。
2. 跑脚本(`ROADS` 列表 + `BBOX` 在文件顶部,按需改):
   ```bash
   python3 scripts/fetch_road_lines.py
   ```
   每路: Overpass 查所有匹配 way → 贪心缝合 → WGS→GCJ → 写 `road_lines.json`(bundle + reports/extracted 两份)。打印每路命中段数/点数 + 样例坐标。
3. **核对**: 命中数合理、坐标落天津(~117.x, ~39.x);空的回 step 2 调正则。
4. **入库**: `SeedImporter.seedRoadLinesIfNeeded` 按 `Dataset.roadLinesSeededV1` 闸门幂等 seed。已 seed 的库要重灌须清该 flag(或清库)。新库直接生效。

## 输出 schema

```json
{"items":[{"name":"中环线","ring":"中环","radial":false,
           "geometry":{"type":"LineString","coordinates":[[lng,lat],...]}}]}
```
- `ring` = 内环/中环/外环 或 null;`radial=true` = 射线。两者 → app 的 Area `tags`(环名 / "射线")。

## 注意

- 缝合是贪心最近端点,跨断裂路可能接歪;report 看点数异常就单独查那条核对。
- 别空覆盖: 网络全失败时不要写空 JSON 顶掉已有好数据;核对非空再提交。
- 折线渲染走 `AreaOverlayFactory` line 分支 + `MKPolylineRenderer`(线色取 `fillHex`)。
