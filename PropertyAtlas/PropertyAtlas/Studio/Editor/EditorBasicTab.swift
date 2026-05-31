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
        return HStack(spacing: 6) {
            Text("坐标").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(c.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? "—")
                .font(.system(size: 12)).textSelection(.enabled)
        }
    }

    private func fieldEditor(_ f: FieldDescriptor) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(f.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
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
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
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
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
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
            .onAppear { if case let .bool(v) = EntityReader.value(ref, key: key, in: context) { on = v } }
            .onChange(of: on) { _, v in EntityWriter.setValue(ref, key: key, value: .bool(v), in: context) }
    }
}
#endif

#if targetEnvironment(macCatalyst)
struct StyleOverrideSection: View { let ref: EntityRef
    var body: some View {
        EmptyView()
    }
}
#endif
