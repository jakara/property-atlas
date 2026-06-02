#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct StyleRuleSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [StyleRule]
    @Query private var palettes: [Palette]

    private let entityTypes = ["compound", "school", "poi", "area"]
    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    private var dsRules: [StyleRule] {
        rules.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.priority < $1.priority }
    }

    private var dsPalettes: [Palette] {
        palettes.filter { !$0.deleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("样式规则").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addRule() } label: { Label("新规则", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsRules, id: \.id) { r in card(r) }
        }
    }

    private func card(_ r: StyleRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { r.name }, set: { r.name = $0
                    r.updatedAt = Date()
                })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { r.deleted = true
                    r.updatedAt = Date()
                } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Picker("实体", selection: Binding(get: { r.entityType }, set: { r.entityType = $0
                    r.updatedAt = Date()
                })) {
                    ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                Toggle("启用", isOn: Binding(get: { r.enabled }, set: { r.enabled = $0
                    r.updatedAt = Date()
                })).font(.system(size: 12))
                Stepper("优先\(r.priority)", value: Binding(get: { r.priority }, set: { r.priority = $0
                    r.updatedAt = Date()
                }), in: 0...999).font(.system(size: 11))
            }
            appliesSection(r)
            conditionsSection(r)
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func appliesSection(_ r: StyleRule) -> some View {
        DisclosureGroup("样式") {
            VStack(alignment: .leading, spacing: 6) {
                Picker("形状", selection: Binding(get: { r.appliesShape ?? "" }, set: { r.appliesShape = $0.isEmpty ? nil : $0
                    r.updatedAt = Date()
                })) {
                    Text("(无)").tag("")
                    ForEach(shapes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                Picker("填充模式", selection: Binding(get: { r.appliesFillMode }, set: { r.appliesFillMode = $0
                    r.updatedAt = Date()
                })) {
                    Text("固定色").tag("fixed")
                    Text("调色板").tag("palette")
                }.pickerStyle(.segmented).font(.system(size: 11))
                if r.appliesFillMode == "palette" {
                    Picker("调色板", selection: Binding(get: { r.appliesPaletteId }, set: { r.appliesPaletteId = $0
                        r.updatedAt = Date()
                    })) {
                        Text("无").tag(UUID?.none)
                        ForEach(dsPalettes, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                    }.font(.system(size: 12))
                    TextField("调色 key 字段", text: Binding(get: { r.appliesPaletteKeyField ?? "" }, set: { r.appliesPaletteKeyField = $0.isEmpty ? nil : $0
                        r.updatedAt = Date()
                    })).font(.system(size: 12))
                } else {
                    ColorHexField(title: "填充色", hex: hexBinding(get: { r.appliesFillHex }, set: { r.appliesFillHex = $0
                        r.updatedAt = Date()
                    }))
                }
                ColorHexField(title: "描边色", hex: hexBinding(get: { r.appliesStrokeHex }, set: { r.appliesStrokeHex = $0
                    r.updatedAt = Date()
                }))
                HStack {
                    TextField("glyph", text: Binding(get: { r.appliesGlyph ?? "" }, set: { r.appliesGlyph = $0.isEmpty ? nil : $0
                        r.updatedAt = Date()
                    })).font(.system(size: 12))
                    ColorHexField(title: "glyph 色", hex: hexBinding(get: { r.appliesGlyphHex }, set: { r.appliesGlyphHex = $0
                        r.updatedAt = Date()
                    }))
                }
                HStack {
                    optIntField("尺寸", get: { r.appliesSize }, set: { r.appliesSize = $0
                        r.updatedAt = Date()
                    })
                    optDoubleField("描边宽", get: { r.appliesStrokeWidth }, set: { r.appliesStrokeWidth = $0
                        r.updatedAt = Date()
                    })
                    optDoubleField("不透明", get: { r.appliesFillOpacity }, set: { r.appliesFillOpacity = $0
                        r.updatedAt = Date()
                    })
                }
                Picker("标签", selection: Binding(get: { labelTag(r.appliesLabelVisible) }, set: { r.appliesLabelVisible = labelValue($0)
                    r.updatedAt = Date()
                })) {
                    Text("默认").tag(0)
                    Text("显示").tag(1)
                    Text("隐藏").tag(2)
                }.pickerStyle(.segmented).font(.system(size: 11))
            }
        }.font(.system(size: 12))
    }

    private func conditionsSection(_ r: StyleRule) -> some View {
        let conds = StyleConditionCodec.decode(r.conditionsJSON)
        return DisclosureGroup("条件 (\(conds.count))") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(conds.indices, id: \.self) { i in
                    StyleConditionRow(
                        condition: Binding(
                            get: { StyleConditionCodec.decode(r.conditionsJSON)[safe: i] ?? StyleCondition(field: "", op: .equals, value: .string("")) },
                            set: { newCond in
                                var arr = StyleConditionCodec.decode(r.conditionsJSON)
                                if arr.indices.contains(i) { arr[i] = newCond
                                    r.conditionsJSON = StyleConditionCodec.encode(arr)
                                    r.updatedAt = Date()
                                }
                            }
                        ),
                        onDelete: {
                            var arr = StyleConditionCodec.decode(r.conditionsJSON)
                            if arr.indices.contains(i) { arr.remove(at: i)
                                r.conditionsJSON = StyleConditionCodec.encode(arr)
                                r.updatedAt = Date()
                            }
                        }
                    )
                }
                Button { addCondition(r) } label: { Label("加条件", systemImage: "plus") }.font(.system(size: 11))
            }
        }.font(.system(size: 12))
    }

    private func hexBinding(get: @escaping () -> String?, set: @escaping (String?) -> Void) -> Binding<String> {
        Binding(get: { get() ?? "" }, set: { set($0.isEmpty ? nil : ColorHexField.normalize($0)) })
    }

    private func optIntField(_ title: String, get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map(String.init) ?? "" }, set: { set($0.isEmpty ? nil : Int($0)) })).font(.system(size: 12).monospaced()).frame(width: 44)
        }
    }

    private func optDoubleField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map { String($0) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) })).font(.system(size: 12).monospaced()).frame(width: 50)
        }
    }

    private func labelTag(_ v: Bool?) -> Int {
        v == nil ? 0 : (v == true ? 1 : 2)
    }

    private func labelValue(_ tag: Int) -> Bool? {
        tag == 0 ? nil : (tag == 1)
    }

    private func addCondition(_ r: StyleRule) {
        var arr = StyleConditionCodec.decode(r.conditionsJSON)
        arr.append(StyleCondition(field: "", op: .equals, value: .string("")))
        r.conditionsJSON = StyleConditionCodec.encode(arr)
        r.updatedAt = Date()
    }

    private func addRule() {
        let r = StyleRule(datasetId: datasetId, name: "新规则", entityType: "compound")
        r.priority = (dsRules.map(\.priority).max() ?? 0) + 1
        modelContext.insert(r)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
#endif
