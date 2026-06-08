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
            } else {
                geometryRow
            }
            LayerPickerRow(ref: ref, datasetId: datasetId)
            ForEach(EntityFieldSchema.fields(for: ref.kind), id: \.key) { f in
                fieldEditor(f)
            }
            TagsEditor(ref: ref)
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

    /// 区域几何类型只读展示(多边形/折线/栅格)。
    private var geometryRow: some View {
        let kind = (EntityReader.fetch(Area.self, ref.id, context)?.geometryKind) ?? ""
        let label: String = switch kind {
        case "polygon": "多边形"
        case "line": "折线"
        case "raster": "栅格"
        default: kind.isEmpty ? "—" : kind
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("几何类型 · 只读").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            FieldRow(key: "几何", value: label, muted: true)
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

/// 自由文本标签编辑器(全实体通用):chip 流式排列,× 删,输入框 + 回车/＋ 加。
private struct TagsEditor: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context
    @State private var tags: [String] = []
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("标签").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            if !tags.isEmpty {
                TagFlow(spacing: 6) {
                    ForEach(tags, id: \.self) { chip($0) }
                }
            }
            HStack(spacing: 6) {
                TextField("加标签", text: $draft).glassField().onSubmit(add)
                Button(action: add) { Image(systemName: "plus") }
                    .buttonStyle(.tbtn(.ghost))
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { tags = EntityReader.tags(ref, in: context) }
        .onChange(of: ref) { _, _ in tags = EntityReader.tags(ref, in: context) }
    }

    private func chip(_ t: String) -> some View {
        HStack(spacing: 4) {
            Text(t).font(Studio.sans(12)).foregroundStyle(Studio.on).lineLimit(1)
            Button { remove(t) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Studio.on2)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Studio.glassHover, in: Capsule())
        .overlay { Capsule().strokeBorder(Studio.glassLine, lineWidth: 1) }
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
        EntityWriter.setTags(ref, tags, in: context)
    }

    private func remove(_ t: String) {
        tags.removeAll { $0 == t }
        EntityWriter.setTags(ref, tags, in: context)
    }
}

/// 简单流式布局:子视图按行排,超宽换行。
private struct TagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW.isFinite ? maxW : x, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
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
