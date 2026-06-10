// PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift
import CoreLocation
import Foundation
import SwiftData

@MainActor
enum EntityReader {
    static func name(_ ref: EntityRef, in context: ModelContext) -> String? {
        styleEntity(ref, in: context).flatMap {
            if case let .string(v) = $0.field("name") { return v }
            return nil
        }
    }

    static func coordinate(_ ref: EntityRef, in context: ModelContext) -> CLLocationCoordinate2D? {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.coordinate
        case .school: fetch(School.self, ref.id, context)?.coordinate
        case .poi: fetch(POI.self, ref.id, context)?.coordinate
        case .area: nil // Area 无单点坐标
        }
    }

    static func layerId(_ ref: EntityRef, in context: ModelContext) -> UUID? {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.layerId
        case .school: fetch(School.self, ref.id, context)?.layerId
        case .poi: fetch(POI.self, ref.id, context)?.layerId
        case .area: fetch(Area.self, ref.id, context)?.layerId
        }
    }

    /// 自由文本标签(全实体通用)。
    static func tags(_ ref: EntityRef, in context: ModelContext) -> [String] {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.tags ?? []
        case .school: fetch(School.self, ref.id, context)?.tags ?? []
        case .poi: fetch(POI.self, ref.id, context)?.tags ?? []
        case .area: fetch(Area.self, ref.id, context)?.tags ?? []
        }
    }

    /// 通用字段读取（baseField 或 customField），经 styleEntity 统一映射。
    static func value(_ ref: EntityRef, key: String, in context: ModelContext) -> AnyJSON? {
        styleEntity(ref, in: context)?.field(key)
    }

    static func notes(_ ref: EntityRef, in context: ModelContext) -> (notes: String?, privateNotes: String?) {
        switch ref.kind {
        case .compound: let e = fetch(Compound.self, ref.id, context)
            return (e?.notes, e?.privateNotes)
        case .school: let e = fetch(School.self, ref.id, context)
            return (e?.notes, e?.privateNotes)
        case .poi: let e = fetch(POI.self, ref.id, context)
            return (e?.notes, e?.privateNotes)
        case .area: let e = fetch(Area.self, ref.id, context)
            return (e?.notes, e?.privateNotes)
        }
    }

    static func customFieldsJSON(_ ref: EntityRef, in context: ModelContext) -> String? {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.customFieldsJSON
        case .school: fetch(School.self, ref.id, context)?.customFieldsJSON
        case .poi: fetch(POI.self, ref.id, context)?.customFieldsJSON
        case .area: fetch(Area.self, ref.id, context)?.customFieldsJSON
        }
    }

    static func overrideStyle(_ ref: EntityRef, in context: ModelContext) -> OverrideStyle {
        switch ref.kind {
        case .compound:
            guard let entity = fetch(Compound.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(
                shape: entity.styleShape,
                fillHex: entity.styleFillHex,
                glyph: entity.styleGlyph,
                glyphHex: entity.styleGlyphHex,
                size: entity.styleSize,
                labelVisible: entity.styleLabelVisible
            )
        case .school:
            guard let entity = fetch(School.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(
                shape: entity.styleShape,
                fillHex: entity.styleFillHex,
                glyph: entity.styleGlyph,
                glyphHex: entity.styleGlyphHex,
                size: entity.styleSize,
                labelVisible: entity.styleLabelVisible
            )
        case .poi:
            guard let entity = fetch(POI.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(
                shape: entity.styleShape,
                fillHex: entity.styleFillHex,
                glyph: entity.styleGlyph,
                glyphHex: entity.styleGlyphHex,
                size: entity.styleSize,
                labelVisible: entity.styleLabelVisible
            )
        case .area:
            guard let entity = fetch(Area.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(
                shape: nil,
                fillHex: entity.styleFillHex,
                glyph: nil,
                glyphHex: nil,
                size: nil,
                labelVisible: entity.styleLabelVisible
            )
        }
    }

    private static func styleEntity(_ ref: EntityRef, in context: ModelContext) -> StyleEntity? {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.styleEntity
        case .school: fetch(School.self, ref.id, context)?.styleEntity
        case .poi: fetch(POI.self, ref.id, context)?.styleEntity
        case .area: fetch(Area.self, ref.id, context)?.styleEntity
        }
    }

    static func fetch(_ type: Compound.Type, _ id: UUID, _ context: ModelContext) -> Compound? {
        var fd = FetchDescriptor<Compound>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }

    static func fetch(_ type: School.Type, _ id: UUID, _ context: ModelContext) -> School? {
        var fd = FetchDescriptor<School>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }

    static func fetch(_ type: POI.Type, _ id: UUID, _ context: ModelContext) -> POI? {
        var fd = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }

    static func fetch(_ type: Area.Type, _ id: UUID, _ context: ModelContext) -> Area? {
        var fd = FetchDescriptor<Area>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }
}
