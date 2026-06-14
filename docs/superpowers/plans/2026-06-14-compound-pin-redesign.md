# 楼盘 Pin 重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 楼盘 pin 从灰色圆点改为「圆形 + 名称标签 + 现房绿/期房蓝/二手黄 + 字形 现/期/二」,信息一眼可读,机制与学校同构(图层持有 ViewEntityStyle + ViewStyleRule)。

**Architecture:** 视觉走现有样式链 `builtin → ViewEntityStyle(图层默认=期房底) → ViewStyleRule(现房/二手覆盖) → groupFill(楼盘层 groupBy=null,不参与) → override`。样式数据**直写 DB**(DB-first,学校样式同处)。两处小代码补缺:① 名称标签字色按底色亮度自适应(黄底可读);② 条件 codec 支持 bool 等值(否则二手规则永不命中)。

**Tech Stack:** SwiftUI · MapKit(Mac Catalyst 渲染)· SwiftData(Core Data sqlite store)· Swift Testing。

**Spec:** `docs/superpowers/specs/2026-06-14-compound-pin-redesign-design.md`

**关键事实(实施前已核实):**
- 测试运行:`cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests/<Struct> 2>&1 | tail -30`
- 构建:同上,`test ...` 换 `build`,可加 `CODE_SIGNING_ALLOWED=NO`。
- pbxproj 用 `PBXFileSystemSynchronizedRootGroup`(无显式 fileRef)→ **新建 .swift 放对目录即自动纳入 target,无需改 pbxproj**。
- DB 路径:`~/Library/Application Support/default.store`(Mac Catalyst 调试固定路径)。
- Core Data 内部:`ViewStyleRule` Z_ENT=20、`ViewStyleCondition` Z_ENT=19;`Z_PRIMARYKEY.Z_MAX` 当前 rule=4/cond=3(与 MAX(Z_PK) 同步)。楼盘图层 `ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0` 唯一一行;其 ViewEntityStyle 行已存在(当前全空)1 行。楼盘层 `primaryFilter.groupBy=null`(规则色不被 groupFill 覆盖)。
- `ConditionEvaluator.equals` 严格 `==`;`.contains` 用 string needle in string haystack。`isNewHouse` 字段求值为 `.bool`,`deliveryTime` 为 `.string`。

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `PropertyAtlas/PropertyAtlas/MapRender/ContrastText.swift` | 纯逻辑:底色 hex → 名称标签字色(亮度阈值) | 新建 |
| `PropertyAtlas/PropertyAtlasTests/MapRender/ContrastTextTests.swift` | ContrastText 单测 | 新建 |
| `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift` | 接入 ContrastText 设 nameLabel 字色 | 改 |
| `PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift` | equals/notEquals 支持 bool 值 | 改 |
| `PropertyAtlas/PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift` | codec bool 单测 | 改(追加) |
| `PropertyAtlas/PropertyAtlasTests/MapRender/ConditionEvaluatorTests.swift` | bool 条件匹配回归 | 改(追加) |
| `scripts/db/2026-06-14-compound-pin-style.sql` | 幂等 DB 写脚本(楼盘图层样式行) | 新建(入库) |

---

## Task 0: 建分支

当前在 `main`(默认分支),先开分支。

- [ ] **Step 1: 建并切分支**

```bash
cd /Users/fujie/projects/天津买房
git checkout -b feat/compound-pin-redesign
```

---

## Task 1: ContrastText 纯逻辑(名称标签字色)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/ContrastText.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/ContrastTextTests.swift`

- [ ] **Step 1: 写失败测试**

Create `PropertyAtlas/PropertyAtlasTests/MapRender/ContrastTextTests.swift`:

```swift
import Testing
@testable import PropertyAtlas

struct ContrastTextTests {
    @Test func yellowFillGetsDarkLabel() {
        #expect(ContrastText.labelHex(onFill: "#FFCC00") == "#1A1A1A")
    }

    @Test func blueFillGetsWhiteLabel() {
        #expect(ContrastText.labelHex(onFill: "#0A84FF") == "#FFFFFF")
    }

    @Test func greenFillGetsWhiteLabel() {
        #expect(ContrastText.labelHex(onFill: "#34C759") == "#FFFFFF")
    }

    @Test func schoolOrangeStaysWhiteLabel() {
        // 区重点橙 #FF9500 luma≈0.642 ≤0.7 → 仍白字,学校视觉不变
        #expect(ContrastText.labelHex(onFill: "#FF9500") == "#FFFFFF")
    }

    @Test func invalidHexFallsBackToWhite() {
        #expect(ContrastText.labelHex(onFill: "bogus") == "#FFFFFF")
    }
}
```

- [ ] **Step 2: 跑测试确认失败(编译错:找不到 ContrastText)**

Run:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests/ContrastTextTests 2>&1 | tail -30
```
Expected: 编译失败 `Cannot find 'ContrastText' in scope`。

- [ ] **Step 3: 写实现**

Create `PropertyAtlas/PropertyAtlas/MapRender/ContrastText.swift`:

```swift
import Foundation

/// 选 pin 名称标签字色:亮底用深字、暗底用白字。基于 sRGB luma。
/// 纯逻辑(无 UIKit),便于单测;PinAnnotationView 消费。
enum ContrastText {
    static let darkHex = "#1A1A1A"
    static let lightHex = "#FFFFFF"

    /// 名称标签字色 hex(随底色 fillHex)。解析失败回退白字。
    static func labelHex(onFill fillHex: String) -> String {
        isLight(fillHex) ? darkHex : lightHex
    }

    /// 底色是否"亮"(luma > 0.7)。阈值 0.7:黄(#FFCC00,0.769)算亮 → 深字;
    /// 学校红(0.456)/橙(0.642)/灰(0.557)≤0.7 仍算暗 → 白字不变。
    static func isLight(_ hex: String) -> Bool {
        guard let (r, g, b) = rgb(hex) else { return false }
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma > 0.7
    }

    private static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        return (
            Double((n >> 16) & 0xFF) / 255,
            Double((n >> 8) & 0xFF) / 255,
            Double(n & 0xFF) / 255
        )
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2 命令。
Expected: `TEST SUCCEEDED`(5 测试通过)。

- [ ] **Step 5: 提交**

```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/MapRender/ContrastText.swift PropertyAtlas/PropertyAtlasTests/MapRender/ContrastTextTests.swift
git commit -m "feat(pin): ContrastText — 名称标签字色按底色亮度自适应"
```

---

## Task 2: PinAnnotationView 接入 ContrastText

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift`(`refresh()` 内,labelVisible 分支)

说明:PinAnnotationView 是 `#if targetEnvironment(macCatalyst)` 的 UIKit view,不便单测;亮度逻辑已在 Task 1 单测覆盖。本任务靠**编译 + 后续手动验证**。

- [ ] **Step 1: 改 refresh() 设 nameLabel 字色**

当前(line 82-90)labelVisible 分支:
```swift
        if style.labelVisible, Self.labelsAllowed, !a.name.isEmpty {
            nameLabel.isHidden = false
            nameLabel.text = "  \(a.name)  "
            nameLabel.backgroundColor = fill.withAlphaComponent(0.92)
            let nameSize = nameLabel.intrinsicContentSize
```
在 `nameLabel.backgroundColor = ...` 行后插入一行,改为:
```swift
        if style.labelVisible, Self.labelsAllowed, !a.name.isEmpty {
            nameLabel.isHidden = false
            nameLabel.text = "  \(a.name)  "
            nameLabel.backgroundColor = fill.withAlphaComponent(0.92)
            nameLabel.textColor = HexColor.parse(ContrastText.labelHex(onFill: style.fillHex)) ?? .white
            let nameSize = nameLabel.intrinsicContentSize
```

(init 内 line 44 `nameLabel.textColor = .white` 保留作默认,refresh 每次按底色覆盖。)

- [ ] **Step 2: 编译确认通过**

Run:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -8
```
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: 提交**

```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift
git commit -m "feat(pin): 名称标签字色随底色亮度(黄底可读)"
```

---

## Task 3: ViewStyleConditionCodec 支持 bool 等值

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift`(`styleCondition` switch)
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift`(追加)
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/ConditionEvaluatorTests.swift`(追加)

背景:`styleCondition` 现把 `.equals` 一律 decode 成 `.string`;但 `isNewHouse` 字段是 `.bool` → 严格 `==` 永不命中。修复 decode:equals/notEquals 的 "true"/"false" → `.bool`(与已有 `columns(from:)` 把 `.bool` 编码成 "true"/"false" 对称)。

- [ ] **Step 1: 写失败测试(codec)**

在 `ViewStyleConditionCodecTests.swift` 末尾(`}` 前)追加:

```swift
    @Test func equalsFalseBuildsBoolCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "isNewHouse", op: .equals, valueString: "false", valueList: []
        )
        #expect(cond.value == .bool(false))
    }

    @Test func equalsTrueBuildsBoolCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "isNewHouse", op: .equals, valueString: "true", valueList: []
        )
        #expect(cond.value == .bool(true))
    }

    @Test func boolRoundTripThroughColumns() {
        let cols = ViewStyleConditionCodec.columns(from: .bool(false), op: .equals)
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "isNewHouse", op: .equals, valueString: cols.valueString, valueList: cols.valueList
        )
        #expect(cond.value == .bool(false))
    }

    @Test func equalsNonBoolStringStaysString() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "grade", op: .equals, valueString: "重点", valueList: []
        )
        #expect(cond.value == .string("重点"))
    }
```

- [ ] **Step 2: 写失败测试(evaluator 回归)**

在 `ConditionEvaluatorTests.swift` 内对应测试 struct 末尾追加(struct 名见文件首,通常 `ConditionEvaluatorTests`):

```swift
    @Test func boolEqualsConditionMatchesFalseEntity() {
        let entity = StyleEntity(
            entityType: "compound", id: UUID(),
            baseFields: ["isNewHouse": .bool(false)], customFields: [:]
        )
        let cond = StyleCondition(field: "isNewHouse", op: .equals, value: .bool(false))
        #expect(ConditionEvaluator.matches(entity: entity, condition: cond))
    }

    @Test func boolEqualsConditionRejectsTrueEntity() {
        let entity = StyleEntity(
            entityType: "compound", id: UUID(),
            baseFields: ["isNewHouse": .bool(true)], customFields: [:]
        )
        let cond = StyleCondition(field: "isNewHouse", op: .equals, value: .bool(false))
        #expect(!ConditionEvaluator.matches(entity: entity, condition: cond))
    }
```

- [ ] **Step 3: 跑测试确认失败**

Run:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests/ViewStyleConditionCodecTests 2>&1 | tail -30
```
Expected: `equalsFalseBuildsBoolCondition`/`equalsTrueBuildsBoolCondition`/`boolRoundTripThroughColumns` 失败(实得 `.string("false")` ≠ `.bool(false)`)。evaluator 两测此时应已通过(`.bool==.bool` 本就成立),但需 codec 修复后整体绿。

- [ ] **Step 4: 改 codec 实现**

`ViewStyleConditionCodec.swift` 的 `styleCondition` 中,把 switch 改为(在 `.gte, .lte` 之后、`default` 之前加 equals/notEquals 分支):

```swift
        let value: AnyJSON = switch op {
        case .inOp:
            .array(valueList.map { .string($0) })
        case .exists:
            .null
        case .gte, .lte:
            if let number = Double(valueString ?? "") {
                .double(number)
            } else {
                .string(valueString ?? "")
            }
        case .equals, .notEquals:
            switch valueString {
            case "true": .bool(true)
            case "false": .bool(false)
            default: .string(valueString ?? "")
            }
        default:
            .string(valueString ?? "")
        }
```

- [ ] **Step 5: 跑测试确认通过**

Run(两个 struct):
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests/ViewStyleConditionCodecTests -only-testing:PropertyAtlasTests/ConditionEvaluatorTests 2>&1 | tail -30
```
Expected: `TEST SUCCEEDED`(含原有 `equalsBuildsStringCondition` 仍绿)。

- [ ] **Step 6: SwiftLint + 提交**

```bash
cd /Users/fujie/projects/天津买房
swiftlint lint --quiet PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift || true
git add PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift PropertyAtlas/PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift PropertyAtlas/PropertyAtlasTests/MapRender/ConditionEvaluatorTests.swift
git commit -m "fix(style): condition codec 支持 bool 等值(isNewHouse 可匹配)"
```

---

## Task 4: 写楼盘图层样式行(DB,备份 + 幂等 SQL)

**Files:**
- Create: `scripts/db/2026-06-14-compound-pin-style.sql`

⚠️ **不可逆 + 改本机库**:严格按顺序。app 必须关闭;写前必须备份。

- [ ] **Step 1: 关 app + 备份库**

```bash
pkill -f PropertyAtlas.app 2>/dev/null; sleep 1
DB="$HOME/Library/Application Support/default.store"
TS=$(date +%Y%m%d-%H%M%S)
cp -p "$DB" "$DB.bak-$TS"
[ -f "$DB-wal" ] && cp -p "$DB-wal" "$DB-wal.bak-$TS"
[ -f "$DB-shm" ] && cp -p "$DB-shm" "$DB-shm.bak-$TS"
echo "backup tag: $TS"
```
Expected: 打印 backup tag;`$DB.bak-$TS` 存在。**记下 tag** 以便回滚。

- [ ] **Step 2: 预检(楼盘层唯一 + ViewEntityStyle 1 行 + 计数基线)**

```bash
DB="$HOME/Library/Application Support/default.store"
sqlite3 "$DB" "SELECT 'layers楼盘', COUNT(*) FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0;
SELECT 'compound ViewEntityStyle', COUNT(*) FROM ZVIEWENTITYSTYLE v JOIN ZLAYER l ON v.ZLAYERID=l.ZID WHERE l.ZNAME='楼盘' AND l.ZDELETED=0 AND v.ZDELETED=0;
SELECT 'compound count', COUNT(*) FROM ZCOMPOUND;
SELECT 'school rules', COUNT(*) FROM ZVIEWSTYLERULE WHERE ZENTITYTYPE='school' AND ZDELETED=0;"
```
Expected: `layers楼盘=1`、`compound ViewEntityStyle=1`、`compound count=174`、`school rules=4`。**任一不符则停,先排查**(脚本假设楼盘层唯一)。

- [ ] **Step 3: 写 SQL 脚本(入库)**

Create `scripts/db/2026-06-14-compound-pin-style.sql`:

```sql
-- 2026-06-14 楼盘 pin 重设计:写楼盘图层样式行(ViewEntityStyle 期房底 + 现房/二手 ViewStyleRule + 条件)。
-- 幂等:重跑结果一致。前置:app 关闭、库已备份。
-- Core Data: ViewStyleRule Z_ENT=20、ViewStyleCondition Z_ENT=19;UUID 列=16-byte blob(randomblob(16));
-- 时间=自 2001 秒(strftime('%s','now')-978307200);ZVALUELIST 复制现有空数组归档 blob。
BEGIN;

-- 1. 幂等清理:删楼盘图层现有条件 + 规则(首次 0 条)
DELETE FROM ZVIEWSTYLECONDITION
 WHERE ZRULEID IN (
   SELECT ZID FROM ZVIEWSTYLERULE
   WHERE ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1)
 );
DELETE FROM ZVIEWSTYLERULE
 WHERE ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1);

-- 2. 楼盘图层 ViewEntityStyle = 期房底样式(UPDATE 既有行)
UPDATE ZVIEWENTITYSTYLE
 SET ZSHAPE='circle', ZFILLHEX='#0A84FF', ZSTROKEHEX='#FFFFFF',
     ZGLYPH='期', ZGLYPHHEX='#FFFFFF', ZSIZE=24, ZLABELVISIBLE=1,
     ZUPDATEDAT=(strftime('%s','now')-978307200)
 WHERE ZLAYERID=(SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1)
   AND ZDELETED=0;

-- 3. 现房规则(priority 10):绿 + 现
INSERT INTO ZVIEWSTYLERULE
 (Z_ENT,Z_OPT,ZDELETED,ZENABLED,ZLABELVISIBLE,ZPRIORITY,ZSIZE,ZVERSION,
  ZCREATEDAT,ZFILLOPACITY,ZSTROKEWIDTH,ZUPDATEDAT,
  ZENTITYTYPE,ZFILLHEX,ZGLYPH,ZGLYPHHEX,ZSHAPE,ZSTROKEHEX,ZDATASETID,ZID,ZLAYERID)
 VALUES
 (20,1,0,1,NULL,10,NULL,1,
  (strftime('%s','now')-978307200),NULL,NULL,(strftime('%s','now')-978307200),
  'compound','#34C759','现','#FFFFFF',NULL,NULL,
  (SELECT ZDATASETID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1),
  randomblob(16),
  (SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1));

-- 4. 二手规则(priority 20):黄 + 二(深字)
INSERT INTO ZVIEWSTYLERULE
 (Z_ENT,Z_OPT,ZDELETED,ZENABLED,ZLABELVISIBLE,ZPRIORITY,ZSIZE,ZVERSION,
  ZCREATEDAT,ZFILLOPACITY,ZSTROKEWIDTH,ZUPDATEDAT,
  ZENTITYTYPE,ZFILLHEX,ZGLYPH,ZGLYPHHEX,ZSHAPE,ZSTROKEHEX,ZDATASETID,ZID,ZLAYERID)
 VALUES
 (20,1,0,1,NULL,20,NULL,1,
  (strftime('%s','now')-978307200),NULL,NULL,(strftime('%s','now')-978307200),
  'compound','#FFCC00','二','#4A3B00',NULL,NULL,
  (SELECT ZDATASETID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1),
  randomblob(16),
  (SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1));

-- 5. 现房条件:deliveryTime contains 现房
INSERT INTO ZVIEWSTYLECONDITION
 (Z_ENT,Z_OPT,ZDELETED,ZSORTORDER,ZCREATEDAT,ZUPDATEDAT,
  ZFIELD,ZOP,ZVALUESTRING,ZID,ZRULEID,ZVALUELIST)
 VALUES
 (19,1,0,0,(strftime('%s','now')-978307200),(strftime('%s','now')-978307200),
  'deliveryTime','contains','现房',randomblob(16),
  (SELECT ZID FROM ZVIEWSTYLERULE WHERE ZPRIORITY=10 AND ZENTITYTYPE='compound'
     AND ZLAYERID=(SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1) LIMIT 1),
  (SELECT ZVALUELIST FROM ZVIEWSTYLECONDITION WHERE ZVALUELIST IS NOT NULL LIMIT 1));

-- 6. 二手条件:isNewHouse equals false
INSERT INTO ZVIEWSTYLECONDITION
 (Z_ENT,Z_OPT,ZDELETED,ZSORTORDER,ZCREATEDAT,ZUPDATEDAT,
  ZFIELD,ZOP,ZVALUESTRING,ZID,ZRULEID,ZVALUELIST)
 VALUES
 (19,1,0,0,(strftime('%s','now')-978307200),(strftime('%s','now')-978307200),
  'isNewHouse','equals','false',randomblob(16),
  (SELECT ZID FROM ZVIEWSTYLERULE WHERE ZPRIORITY=20 AND ZENTITYTYPE='compound'
     AND ZLAYERID=(SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1) LIMIT 1),
  (SELECT ZVALUELIST FROM ZVIEWSTYLECONDITION WHERE ZVALUELIST IS NOT NULL LIMIT 1));

-- 7. 同步 Z_PRIMARYKEY.Z_MAX(防 Core Data 下次分配 Z_PK 冲突)
UPDATE Z_PRIMARYKEY SET Z_MAX=(SELECT MAX(Z_PK) FROM ZVIEWSTYLERULE) WHERE Z_NAME='ViewStyleRule';
UPDATE Z_PRIMARYKEY SET Z_MAX=(SELECT MAX(Z_PK) FROM ZVIEWSTYLECONDITION) WHERE Z_NAME='ViewStyleCondition';

COMMIT;

-- 8. 把 WAL 折叠进主库,避免 -wal/-shm 残留与 app 不一致
PRAGMA wal_checkpoint(TRUNCATE);
```

- [ ] **Step 4: 跑脚本**

```bash
DB="$HOME/Library/Application Support/default.store"
sqlite3 "$DB" < /Users/fujie/projects/天津买房/scripts/db/2026-06-14-compound-pin-style.sql
echo "exit=$?"
```
Expected: `exit=0`,无报错。

- [ ] **Step 5: 验证 DB(行内容 + 学校未动 + 计数不变)**

```bash
DB="$HOME/Library/Application Support/default.store"
echo "== 楼盘 ViewEntityStyle(期房底) =="
sqlite3 -header "$DB" "SELECT ZSHAPE,ZFILLHEX,ZGLYPH,ZGLYPHHEX,ZSIZE,ZLABELVISIBLE FROM ZVIEWENTITYSTYLE WHERE ZLAYERID=(SELECT ZID FROM ZLAYER WHERE ZNAME='楼盘' AND ZDELETED=0 LIMIT 1) AND ZDELETED=0;"
echo "== 楼盘规则(2) =="
sqlite3 -header "$DB" "SELECT ZPRIORITY,ZFILLHEX,ZGLYPH,ZGLYPHHEX FROM ZVIEWSTYLERULE WHERE ZENTITYTYPE='compound' AND ZDELETED=0 ORDER BY ZPRIORITY;"
echo "== 楼盘条件(2) =="
sqlite3 -header "$DB" "SELECT ZFIELD,ZOP,ZVALUESTRING FROM ZVIEWSTYLECONDITION WHERE ZRULEID IN (SELECT ZID FROM ZVIEWSTYLERULE WHERE ZENTITYTYPE='compound' AND ZDELETED=0);"
echo "== 学校未动(4 rule/3 cond) + 楼盘数(174) =="
sqlite3 "$DB" "SELECT 'school rules', COUNT(*) FROM ZVIEWSTYLERULE WHERE ZENTITYTYPE='school' AND ZDELETED=0;
SELECT 'school conds', COUNT(*) FROM ZVIEWSTYLECONDITION WHERE ZRULEID IN (SELECT ZID FROM ZVIEWSTYLERULE WHERE ZENTITYTYPE='school' AND ZDELETED=0);
SELECT 'compound count', COUNT(*) FROM ZCOMPOUND;
SELECT 'Z_MAX rule', Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME='ViewStyleRule';
SELECT 'maxPK rule', MAX(Z_PK) FROM ZVIEWSTYLERULE;"
```
Expected:
- ViewEntityStyle: `circle | #0A84FF | 期 | #FFFFFF | 24 | 1`
- 规则:`10|#34C759|现|#FFFFFF` 与 `20|#FFCC00|二|#4A3B00`
- 条件:`deliveryTime|contains|现房` 与 `isNewHouse|equals|false`
- school rules=4、school conds=3、compound count=174
- `Z_MAX rule` == `maxPK rule`(同步成功)

- [ ] **Step 6: 提交 SQL 脚本**

```bash
cd /Users/fujie/projects/天津买房
git add scripts/db/2026-06-14-compound-pin-style.sql
git commit -m "chore(db): 楼盘图层 pin 样式写入脚本(现房/期房/二手)"
```

回滚(如需):`pkill -f PropertyAtlas.app; DB="$HOME/Library/Application Support/default.store"; cp -p "$DB.bak-<tag>" "$DB"; rm -f "$DB-wal" "$DB-shm"`。

---

## Task 5: 整体验证(全测 + 跑 app 肉眼确认)

- [ ] **Step 1: 全量单测绿**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests 2>&1 | tail -15
```
Expected: `TEST SUCCEEDED`。

- [ ] **Step 2: SwiftLint 全绿(改动文件)**

```bash
cd /Users/fujie/projects/天津买房 && swiftlint lint --quiet 2>&1 | tail -15
```
Expected: 无新增 error(既有警告范围见 memory `swiftlint-scope-stale`,不追)。

- [ ] **Step 3: 构建 + 跑 app,肉眼确认**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
# 用 BUILT_PRODUCTS_DIR 启最新构建(避陈旧),见 memory p5-smoke-remigrate
APP=$(cd PropertyAtlas.xcodeproj/.. && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}' | head -1)
open "$APP/PropertyAtlas.app"
```
肉眼核对(放大到天津楼盘):
  - 楼盘=**圆形**,现房**绿/现**、期房**蓝/期**;名字标签可读(蓝/绿底白字)。
  - 无 yellow pin(现无二手数据)——符合预期。
  - 学校仍**方块**红/橙/灰 + 重/普,名字白字**不变**(未受 ContrastText 影响)。
  - 缩小:只剩圆点,名字隐藏(labelMinZoom 门控)。
  - 拖/缩流畅(无回归)。

Expected: 全部符合。若现房 pin 仍灰/无字 → 查 RootView 是否按楼盘 layerId 取了 ViewEntityStyle/规则(buildStylesByLayer/buildRulesByLayer);若全蓝无绿 → 查 deliveryTime contains 现房 命中(`SELECT COUNT(*) FROM ZCOMPOUND WHERE ZDELIVERYTIME LIKE '%现房%'` 应 ~75)。

- [ ] **Step 4: 完成分支**

调用 superpowers:finishing-a-development-branch 决定合并/PR/清理(用户偏好:仅 commit,push 需用户确认)。

---

## Self-Review(已对照 spec)

- **覆盖**:视觉(圆/期房底/现房/二手)→ Task 4;名称标签 → Task 1+2;bool 条件可匹配 → Task 3;备份+幂等+app关 → Task 4 Step 1/3;验证(单测/DB/跑app/计数不变)→ Task 5 + Task4 Step5。spec 全节有对应任务。
- **无占位符**:每步含实际代码/SQL/命令/期望输出。
- **类型一致**:`ContrastText.labelHex(onFill:)`/`isLight(_:)` 跨任务一致;`HexColor.parse` 沿用现有;codec `styleCondition`/`columns` 签名不变;`StyleCondition`/`StyleEntity`/`ConditionEvaluator.matches` 用现有签名。
- **注**:二手 yellow 规则现匹配 0 条(无二手数据),Task 5 不期望见黄 pin —— 符合 spec「先建好等将来数据」。
