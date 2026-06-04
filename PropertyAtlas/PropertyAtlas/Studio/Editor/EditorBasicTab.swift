// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import SwiftData
import SwiftUI

struct EditorBasicTab: View {
    let ref: EntityRef
    let datasetId: UUID
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ref.kind != .area {
                coordRow
            }
            ForEach(EntityFieldSchema.fields(for: ref.kind), id: \.key) { f in
                fieldEditor(f)
            }
            StyleOverrideSection(ref: ref)
        }
    }

    private var coordRow: some View {
        let c = EntityReader.coordinate(ref, in: context)
        return VStack(alignment: .leading, spacing: 6) {
            Text("坐标 · 只读（由地图定位）")
                .font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            FieldRow(
                key: "坐标",
                value: c.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? "—",
                mono: true,
                muted: true
            )
        }
    }

    private func fieldEditor(_ f: FieldDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(f.label).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            switch f.kind {
            case .string, .enumRef:
                StringFieldEditor(ref: ref, key: f.key)
            case .int:
                IntFieldEditor(ref: ref, key: f.key)
            case .bool:
                BoolFieldEditor(ref: ref, key: f.key)
            }
        }
    }
}

private struct StringFieldEditor: View {
    let ref: EntityRef
    let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""
    var body: some View {
        TextField("", text: $text)
            .glassField()
            .onAppear { if case let .string(v) = EntityReader.value(ref, key: key, in: context) { text = v } }
            .onSubmit { EntityWriter.setValue(ref, key: key, value: .string(text), in: context) }
    }
}

private struct IntFieldEditor: View {
    let ref: EntityRef
    let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""
    var body: some View {
        TextField("", text: $text)
            .glassField()
            .onAppear { if case let .int(v) = EntityReader.value(ref, key: key, in: context) { text = String(v) } }
            .onSubmit { if let n = Int(text) { EntityWriter.setValue(ref, key: key, value: .int(n), in: context) } }
    }
}

private struct BoolFieldEditor: View {
    let ref: EntityRef
    let key: String
    @Environment(\.modelContext) private var context
    @State private var on = false
    var body: some View {
        Toggle("", isOn: $on)
            .labelsHidden()
            .tint(Studio.cool)
            .onAppear { if case let .bool(v) = EntityReader.value(ref, key: key, in: context) { on = v } }
            .onChange(of: on) { _, v in EntityWriter.setValue(ref, key: key, value: .bool(v), in: context) }
    }
}
#endif
