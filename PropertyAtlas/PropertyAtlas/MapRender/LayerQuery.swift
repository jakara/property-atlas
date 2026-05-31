// PropertyAtlas/PropertyAtlas/MapRender/LayerQuery.swift
import Foundation

struct LayerQuery {
    let staticRefs: [EntityRef]
    let dynamicType: String?
    let dynamicConditions: [StyleCondition]

    init(staticRefsJSON: String?, dynamicQueryJSON: String?) {
        var refs: [EntityRef] = []
        if let s = staticRefsJSON, !s.isEmpty,
           let arr: [[String: String]] = try? JSONHelpers.decode(s)
        {
            for item in arr {
                if let idStr = item["entityId"], let uuid = UUID(uuidString: idStr),
                   let typeStr = item["entityType"], let kind = EntityKind(rawValue: typeStr)
                {
                    refs.append(EntityRef(id: uuid, kind: kind))
                }
            }
        }
        staticRefs = refs

        var dType: String?
        var conds: [StyleCondition] = []
        if let d = dynamicQueryJSON, !d.isEmpty,
           let decoded: DynamicQueryDTO = try? JSONHelpers.decode(d)
        {
            dType = decoded.entityType
            conds = decoded.conditions ?? []
        }
        dynamicType = dType
        dynamicConditions = conds
    }

    private struct DynamicQueryDTO: Codable {
        let entityType: String
        let conditions: [StyleCondition]?
    }

    var isMatchAll: Bool {
        staticRefs.isEmpty && dynamicType == nil
    }

    /// match-all 返回空集（evaluator 特判）；否则返回该层覆盖的类型集。
    var coveredTypes: Set<String> {
        var set = Set(staticRefs.map(\.typeString))
        if let dynamicType { set.insert(dynamicType) }
        return set
    }
}
