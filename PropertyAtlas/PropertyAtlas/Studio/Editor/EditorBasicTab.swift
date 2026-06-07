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
            LayerPickerRow(ref: ref, datasetId: datasetId)
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
            case .string:
                StringFieldEditor(ref: ref, key: f.key)
            case .enumRef:
                EnumFieldEditor(ref: ref, key: f.key, scope: f.enumScope ?? "", datasetId: datasetId)
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

/// enum 字段:从 EnumOption(scope)拉可选值,渲染下拉选择器。值写入对应 base 列(.string)。
/// 枚举值由「设置 → 枚举」按 scope 自定义增删。当前值不在选项里也照常显示。
private struct EnumFieldEditor: View {
    let ref: EntityRef
    let key: String
    let scope: String
    let datasetId: UUID
    @Environment(\.modelContext) private var context
    @State private var selected = ""

    private var options: [String] {
        let ds = datasetId
        let sc = scope
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == ds && $0.scope == sc && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return ((try? context.fetch(fd)) ?? []).map(\.label)
    }

    var body: some View {
        Menu {
            Button("—（清空）") { write(nil) }
            ForEach(options, id: \.self) { o in
                Button { write(o) } label: {
                    Label(o, systemImage: o == selected ? "checkmark" : "circle")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.isEmpty ? "未设置" : selected)
                    .font(Studio.sans(14))
                    .foregroundStyle(selected.isEmpty ? Studio.on3 : Studio.on)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Studio.on3)
            }
            .glassField()
        }
        .menuStyle(.borderlessButton)
        .onAppear { if case let .string(v) = EntityReader.value(ref, key: key, in: context) { selected = v } }
    }

    private func write(_ v: String?) {
        selected = v ?? ""
        EntityWriter.setValue(ref, key: key, value: v.map { AnyJSON.string($0) } ?? .null, in: context)
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
