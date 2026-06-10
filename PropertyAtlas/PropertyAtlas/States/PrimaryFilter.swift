import Foundation

/// 主过滤器:条件 AND 后约束实体(类型由所属图层定);groupBy 用于分组染色。
struct PrimaryFilter: Codable, Equatable {
    var conditions: [FilterCondition]
    var groupBy: MapDimension?

    @MainActor
    func matches(_ input: MapDimension.Input) -> Bool {
        for c in conditions where !c.evaluate(input) {
            return false
        }
        return true
    }

    @MainActor
    func groupValues(_ input: MapDimension.Input) -> [String] {
        groupBy?.resolve(input) ?? []
    }
}

extension PrimaryFilter {
    enum CodingKeys: String, CodingKey { case conditions, groupBy }

    // 容错解码:旧 JSON 多出的 entityType 字段忽略。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conditions = try c.decodeIfPresent([FilterCondition].self, forKey: .conditions) ?? []
        groupBy = try c.decodeIfPresent(MapDimension.self, forKey: .groupBy)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(conditions, forKey: .conditions)
        try c.encodeIfPresent(groupBy, forKey: .groupBy)
    }
}

/// 普通过滤器(图例 chip + 计数):一个维度(实体类型由所属图层定)。
struct NormalFilter: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var dimension: MapDimension

    init(id: UUID = UUID(), name: String, dimension: MapDimension) {
        self.id = id
        self.name = name
        self.dimension = dimension
    }
}

extension NormalFilter {
    enum CodingKeys: String, CodingKey { case id, name, dimension }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        dimension = try c.decode(MapDimension.self, forKey: .dimension)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dimension, forKey: .dimension)
    }
}
