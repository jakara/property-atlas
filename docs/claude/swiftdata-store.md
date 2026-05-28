# SwiftData store 路径 (Mac Catalyst, 调试)

**调试阶段固定路径** (CODE_SIGNING_ALLOWED=NO build, 无 sandbox entitlement, `ModelConfiguration` 默认 url):
```
/Users/fujie/Library/Application Support/default.store
/Users/fujie/Library/Application Support/default.store-wal
/Users/fujie/Library/Application Support/default.store-shm
```

App 启动会写 `/tmp/propertyatlas_paths.txt` (Home/AppSupport/StoreURL 三行), 可直接 `cat` 验证.

**路径会变 (3 种情况)**:
1. 启 sandbox entitlement → `~/Library/Containers/top.akara.propAtlas.PropertyAtlas/Data/Library/Application Support/default.store`
2. Release / signed / App Store 分发 → 通常自带 sandbox
3. 改 `ModelConfiguration` 显式 `url:` 参数

**DBeaver 连接** (调试):
- New Connection → SQLite
- Path: `/Users/fujie/Library/Application Support/default.store` (含空格, 不要引号)
- Driver properties: `open_mode=1` 只读 (避免和 app 写冲突)
- DBeaver 需 Full Disk Access (系统设置 → 隐私与安全)
- Finder 找不到: `~/Library` 默认隐藏 — ⌘⇧G 输 `~/Library/Application Support/` 跳转

**直接 sqlite3 命令**:
```bash
sqlite3 ~/Library/Application\ Support/default.store ".tables"
sqlite3 ~/Library/Application\ Support/default.store "SELECT Z_NAME FROM Z_PRIMARYKEY"
sqlite3 ~/Library/Application\ Support/default.store "SELECT * FROM ZSCHOOL LIMIT 3"
```

**清空 (强制重 import, schema 改后必跑)**:
```bash
pkill -f PropertyAtlas.app
rm -f ~/Library/Application\ Support/default.store*
```
