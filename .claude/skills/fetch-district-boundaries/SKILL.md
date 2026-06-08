---
name: fetch-district-boundaries
description: 联网抓取行政区(区县)边界多边形 → 打包成 Area seed。用户说"获取/更新行政区边界""拉某市区县边界""刷新 district_boundaries"时用。源 = DataV.GeoAtlas(免 key, GCJ-02 原生)。
---

# Fetch District Boundaries

抓取**行政区(区县级)边界多边形**,产出 `district_boundaries.json`,app 首启动 seed 成 Area(`category="行政区"`)。

触发: "获取天津行政区边界" / "更新区县边界" / "拉 XX 市的区边界" / `/fetch-district-boundaries [adcode]`。

## 源 = DataV.GeoAtlas(免 key)

- URL: `https://geo.datav.aliyun.com/areas_v3/bound/{adcode}_full.json`
- `{adcode}_full.json` 返回该区域**子级** FeatureCollection。城市 adcode(天津 `120000`)→ 16 个区。
- **坐标 = GCJ-02 原生**(经点-在-多边形实测对齐 app 数据),**不转换**。见 [[coordinate-system-gcj02]]。
- **局限**: DataV 只到区县级,**不发街道/乡镇**(`{区adcode}_full.json` 全 404,实测北京/上海同样)。要街道得换源(高德 district API `subdistrict=1`,需 key)。

## 步骤

1. 跑脚本(默认天津 `120000`,换城市传 adcode):
   ```bash
   python3 scripts/fetch_district_boundaries.py [parent_adcode]
   ```
   脚本: 取 `{adcode}_full.json` → 每个子区 feature → 取最大环(MultiPolygon 取最大多边形外环,匹配 `GeoJSONHelper.decodePolygon` 只读 `coordinates[0]`)→ 写两份:
   - `PropertyAtlas/PropertyAtlas/Resources/Seeds/district_boundaries.json`(bundle)
   - `reports/extracted/district_boundaries.json`(留档)

2. **核对**: 脚本打印每区点数 + 样例坐标。确认落在目标城市经纬度(天津 ~117.x, ~39.x)、区数对(天津 16)。

3. **入库**: app 内 `SeedImporter.seedDistrictBoundariesIfNeeded` 按 `Dataset.districtBoundariesSeededV1` 闸门幂等 seed。**已 seed 的库不会重新读新 JSON** —— 要重灌须清 `districtBoundariesSeededV1`(或清库重迁)。新库直接生效。

## 输出 schema

```json
{"items":[{"adcode":120101,"name":"和平区",
           "geometry":{"type":"Polygon","coordinates":[[[lng,lat],...]]}}]}
```

## 注意

- 写文件前别空跑覆盖: 脚本失败(网络)时不写空 `{"items":[]}`,核对输出非空再用。
- 名字会被 app `AreaNameFormatter` 在 seed 时规范(见 migrator),这里保留 DataV 原名。
- 区名清洗/学片改名是 app 侧 `normalizeAreaNamesIfNeeded`,与本抓取无关。
