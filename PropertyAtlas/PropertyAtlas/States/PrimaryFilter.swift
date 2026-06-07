import Foundation

/// 主过滤器:绑定一个实体类型(entityType),条件 AND 后只约束该类型实体;
/// groupBy 分组染色也只作用于该类型。空 entityType = 不约束任何实体(向后兼容旧 JSON)。
struct PrimaryFilter: Codable, Equatable {
    var conditions: [FilterCondition]
    var groupBy: MapDimension?
    var entityType: String = ""

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
    enum CodingKeys: String, CodingKey { case conditions, groupBy, entityType }

    // 容错解码:旧库 JSON 无 entityType 字段时回退空串(否则合成 Codable 抛错 → 清空过滤器)。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conditions = try c.decodeIfPresent([FilterCondition].self, forKey: .conditions) ?? []
        groupBy = try c.decodeIfPresent(MapDimension.self, forKey: .groupBy)
        entityType = try c.decodeIfPresent(String.self, forKey: .entityType) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(conditions, forKey: .conditions)
        try c.encodeIfPresent(groupBy, forKey: .groupBy)
        try c.encode(entityType, forKey: .entityType)
    }
}

/// 普通过滤器(图例 chip + 计数):绑定一个实体类型,只对该类型实体生效。
struct NormalFilter: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var dimension: MapDimension
    var entityType: String = ""

    init(id: UUID = UUID(), name: String, dimension: MapDimension, entityType: String = "") {
        self.id = id
        self.name = name
        self.dimension = dimension
        self.entityType = entityType
    }
}

extension NormalFilter {
    enum CodingKeys: String, CodingKey { case id, name, dimension, entityType }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        dimension = try c.decode(MapDimension.self, forKey: .dimension)
        entityType = try c.decodeIfPresent(String.self, forKey: .entityType) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dimension, forKey: .dimension)
        try c.encode(entityType, forKey: .entityType)
    }
}
