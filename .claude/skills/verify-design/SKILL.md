---
name: verify-design
description: Check current implementation against the design spec and plan for drift. Invoke after completing any implementation task or at review checkpoints.
---

## verify-design

Compare what is currently implemented against the design spec and plan.

### Steps

1. Read all Swift source files under `TianjinHouse/`
2. Read the design spec: `@docs/superpowers/specs/2026-05-19-tianjin-house-design.md`
3. Read the implementation plan: `@docs/superpowers/plans/2026-05-20-tianjin-house-app.md`
4. Check each implemented component against its spec:
   - Does `RootView` use `ZStack` floating chrome (not `HStack` or `HSplitView`)?
   - Are color tokens from `Color+Hex.swift` used — not hardcoded hex values or generic SwiftUI colors?
   - Does drawer width equal `geo.size.width * 0.382 - 16`?
   - Are `pub_*` models excluded from CloudKit sync?
   - Does 初中 use zone-pool logic (not single-school assignment)?
   - Are all `@Model` properties using defaults or `?` optionals (required for CloudKit)?
   - Is Swift Testing used (not XCTest)?
   - Is `Map(position:)` used (not deprecated `Map(coordinateRegion:)`)?
5. Report findings as a checklist:
   - ✅ matches spec
   - ❌ deviates — cite `file:line` and the correct behavior per spec
6. Suggest concrete fixes for any ❌ items. Do not silently accept drift.
