// PropertyAtlas/PropertyAtlas/DataKit/EntityFieldSchema.swift
import Foundation

enum FieldKind { case string, int, bool, enumRef }

struct FieldDescriptor {
    let key: String
    let label: String
    let kind: FieldKind
    /// 仅 kind == .enumRef 时用：EnumOption.scope（如 "school.category"）
    let enumScope: String?

    init(_ key: String, _ label: String, _ kind: FieldKind, enumScope: String? = nil) {
        self.key = key
        self.label = label
        self.kind = kind
        self.enumScope = enumScope
    }
}

enum EntityFieldSchema {
    static func fields(for kind: EntityKind) -> [FieldDescriptor] {
        switch kind {
        case .compound:
            [
                FieldDescriptor("buildYear", "建成年份", .int),
                FieldDescriptor("developer", "开发商", .string),
                FieldDescriptor("propertyMgmt", "物业", .string),
                FieldDescriptor("finishType", "精装类型", .string, enumScope: "compound.finishType"),
                FieldDescriptor("deliveryTime", "交付时间", .string),
                FieldDescriptor("isNewHouse", "新房", .bool),
                FieldDescriptor("areaSegments", "面积段", .string),
                FieldDescriptor("priceSegments", "价格段", .string),
            ]
        case .school:
            [
                FieldDescriptor("category", "阶段", .enumRef, enumScope: "school.category"),
                FieldDescriptor("grade", "等级", .enumRef, enumScope: "school.grade"),
                FieldDescriptor("form", "学制", .enumRef, enumScope: "school.form"),
                FieldDescriptor("foundYear", "建校年份", .int),
                FieldDescriptor("capacity", "容量", .int),
                FieldDescriptor("communitiesText", "覆盖说明", .string),
                FieldDescriptor("phone", "电话", .string),
            ]
        case .poi:
            [
                FieldDescriptor("category", "POI 类型", .enumRef, enumScope: "poi.category"),
            ]
        case .area:
            [
                FieldDescriptor("category", "区域类型", .enumRef, enumScope: "area.category"),
                FieldDescriptor("textDescription", "描述", .string),
            ]
        }
    }
}
