// PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift
import Foundation
import SwiftData

@MainActor
enum EntityWriter {
    static func createPin(
        kind: EntityKind,
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        in context: ModelContext
    ) -> EntityRef {
        // 图层归属已由 entityType + 过滤器派生(layer-centric),创建时不再指派图层。
        let id: UUID
        switch kind {
        case .compound:
            let e = Compound(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e)
            id = e.id
        case .school:
            let e = School(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e)
            id = e.id
        case .poi:
            let e = POI(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e)
            id = e.id
        case .area:
            let e = Area(datasetId: datasetId, name: name)
            context.insert(e)
            id = e.id
        }
        return EntityRef(id: id, kind: kind)
    }

    static func setTags(_ ref: EntityRef, _ v: [String], in context: ModelContext) {
        touch(ref, in: context) { $0.tags = v } s: { $0.tags = v } p: { $0.tags = v } a: { $0.tags = v }
    }

    static func setName(_ ref: EntityRef, _ name: String, in context: ModelContext) {
        touch(ref, in: context) { c in c.name = name } s: { $0.name = name } p: { $0.name = name } a: { $0.name = name }
    }

    static func setPrivateNotes(_ ref: EntityRef, _ v: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.privateNotes = v } s: { $0.privateNotes = v } p: { $0.privateNotes = v } a: { $0.privateNotes = v }
    }

    static func setNotes(_ ref: EntityRef, _ v: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.notes = v } s: { $0.notes = v } p: { $0.notes = v } a: { $0.notes = v }
    }

    static func setCoordinate(_ ref: EntityRef, lat: Double, lon: Double, in context: ModelContext) {
        touch(ref, in: context) { $0.latitude = lat
            $0.longitude = lon
        }
        s: { $0.latitude = lat
            $0.longitude = lon
        }
        p: { $0.latitude = lat
            $0.longitude = lon
        }
        a: { _ in } // Area 无单点
    }

    static func setOverrideStyle(_ ref: EntityRef, _ override: OverrideStyle, in context: ModelContext) {
        touch(ref, in: context) { compound in
            compound.styleShape = override.shape
            compound.styleFillHex = override.fillHex
            compound.styleGlyph = override.glyph
            compound.styleGlyphHex = override.glyphHex
            compound.styleSize = override.size
            compound.styleLabelVisible = override.labelVisible
        } s: { school in
            school.styleShape = override.shape
            school.styleFillHex = override.fillHex
            school.styleGlyph = override.glyph
            school.styleGlyphHex = override.glyphHex
            school.styleSize = override.size
            school.styleLabelVisible = override.labelVisible
        } p: { poi in
            poi.styleShape = override.shape
            poi.styleFillHex = override.fillHex
            poi.styleGlyph = override.glyph
            poi.styleGlyphHex = override.glyphHex
            poi.styleSize = override.size
            poi.styleLabelVisible = override.labelVisible
        } a: { area in
            area.styleFillHex = override.fillHex
            area.styleLabelVisible = override.labelVisible
        }
    }

    static func setCustomFieldsJSON(_ ref: EntityRef, _ json: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.customFieldsJSON = json } s: { $0.customFieldsJSON = json }
            p: { $0.customFieldsJSON = json } a: { $0.customFieldsJSON = json }
    }

    static func softDelete(_ ref: EntityRef, in context: ModelContext) {
        touch(ref, in: context) { $0.deleted = true } s: { $0.deleted = true } p: { $0.deleted = true } a: { $0.deleted = true }
    }

    /// 写单个 baseField（按 EntityFieldSchema 的 key）。未知 key 忽略。
    static func setValue(_ ref: EntityRef, key: String, value: AnyJSON, in context: ModelContext) {
        switch ref.kind {
        case .compound: if let e = EntityReader.fetch(Compound.self, ref.id, context) { applyCompound(e, key, value)
                e.updatedAt = Date()
            }
        case .school: if let e = EntityReader.fetch(School.self, ref.id, context) { applySchool(e, key, value)
                e.updatedAt = Date()
            }
        case .poi: if let e = EntityReader.fetch(POI.self, ref.id, context) { applyPOI(e, key, value)
                e.updatedAt = Date()
            }
        case .area: if let e = EntityReader.fetch(Area.self, ref.id, context) { applyArea(e, key, value)
                e.updatedAt = Date()
            }
        }
    }

    // MARK: - per-type field apply

    private static func str(_ v: AnyJSON) -> String? {
        if case let .string(s) = v { return s }
        return nil
    }

    private static func intv(_ v: AnyJSON) -> Int? {
        if case let .int(i) = v { return i }
        return nil
    }

    private static func boolv(_ v: AnyJSON) -> Bool? {
        if case let .bool(b) = v { return b }
        return nil
    }

    private static func applyCompound(_ e: Compound, _ k: String, _ v: AnyJSON) {
        switch k {
        case "buildYear": e.buildYear = intv(v)
        case "developer": e.developer = str(v)
        case "propertyMgmt": e.propertyMgmt = str(v)
        case "finishType": e.finishType = str(v)
        case "deliveryTime": e.deliveryTime = str(v)
        case "isNewHouse": e.isNewHouse = boolv(v) ?? e.isNewHouse
        case "areaSegments": e.areaSegments = str(v)
        case "priceSegments": e.priceSegments = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applySchool(_ e: School, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "grade": e.grade = str(v)
        case "form": e.form = str(v)
        case "foundYear": e.foundYear = intv(v)
        case "capacity": e.capacity = intv(v)
        case "communitiesText": e.communitiesText = str(v)
        case "phone": e.phone = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applyPOI(_ e: POI, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applyArea(_ e: Area, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "textDescription": e.textDescription = str(v)
        default: break
        }
    }

    /// 统一取出实体执行 mutation 并 bump updatedAt。
    private static func touch(
        _ ref: EntityRef,
        in context: ModelContext,
        _ c: (Compound) -> Void,
        s: (School) -> Void,
        p: (POI) -> Void,
        a: (Area) -> Void
    ) {
        switch ref.kind {
        case .compound: if let e = EntityReader.fetch(Compound.self, ref.id, context) { c(e)
                e.updatedAt = Date()
            }
        case .school: if let e = EntityReader.fetch(School.self, ref.id, context) { s(e)
                e.updatedAt = Date()
            }
        case .poi: if let e = EntityReader.fetch(POI.self, ref.id, context) { p(e)
                e.updatedAt = Date()
            }
        case .area: if let e = EntityReader.fetch(Area.self, ref.id, context) { a(e)
                e.updatedAt = Date()
            }
        }
    }
}
