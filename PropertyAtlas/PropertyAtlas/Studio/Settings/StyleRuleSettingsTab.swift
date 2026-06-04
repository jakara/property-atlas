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
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "样式规则", trailing: "\(dsRules.count)")
            ForEach(dsRules, id: \.id) { r in card(r) }
            AddRow("新建样式规则") { addRule() }
        }
    }

    private func card(_ r: StyleRule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            headerCard(r)
            StudioDisclosure("外观", open: false) { appliesBody(r) }
            conditionsSection(r)
        }
        .padding(.bottom, 4)
    }

    private func headerCard(_ r: StyleRule) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    TextField("名称", text: Binding(get: { r.name }, set: { r.name = $0
                        r.updatedAt = Date()
                    }))
                    .glassField()
                    Text("P\(r.priority)").font(Studio.sans(11, .semibold)).foregroundStyle(Studio.cool)
                    Button(role: .destructive) { r.deleted = true
                        r.updatedAt = Date()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                RowDivider()
                HStack(spacing: 10) {
                    Picker("实体", selection: Binding(get: { r.entityType }, set: { r.entityType = $0
                        r.updatedAt = Date()
                    })) {
                        ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
                    }.font(Studio.sans(12)).tint(Studio.cool)
                    Spacer()
                    Toggle("启用", isOn: Binding(get: { r.enabled }, set: { r.enabled = $0
                        r.updatedAt = Date()
                    })).font(Studio.sans(12)).foregroundStyle(Studio.on).tint(Studio.cool).fixedSize()
                    GlassStepper(value: Binding(get: { r.priority }, set: { r.priority = $0
                        r.updatedAt = Date()
                    }), range: 0...999)
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
            }
        }
    }

    @ViewBuilder
    private func appliesBody(_ r: StyleRule) -> some View {
        labeled("形状") {
            Picker("", selection: Binding(get: { r.appliesShape ?? "" }, set: { r.appliesShape = $0.isEmpty ? nil : $0
                r.updatedAt = Date()
            })) {
                Text("(无)").tag("")
                ForEach(shapes, id: \.self) { Text($0).tag($0) }
            }.labelsHidden().tint(Studio.cool)
        }
        labeled("填充模式") {
            GlassSegmented(
                options: [(value: "fixed", label: "固定色"), (value: "palette", label: "调色板")],
                selection: Binding(get: { r.appliesFillMode }, set: { r.appliesFillMode = $0
                    r.updatedAt = Date()
                })
            )
        }
        if r.appliesFillMode == "palette" {
            labeled("调色板") {
                Picker("", selection: Binding(get: { r.appliesPaletteId }, set: { r.appliesPaletteId = $0
                    r.updatedAt = Date()
                })) {
                    Text("无").tag(UUID?.none)
                    ForEach(dsPalettes, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.labelsHidden().tint(Studio.cool)
            }
            TextField("调色 key 字段", text: Binding(get: { r.appliesPaletteKeyField ?? "" }, set: { r.appliesPaletteKeyField = $0.isEmpty ? nil : $0
                r.updatedAt = Date()
            })).glassField()
        } else {
            ColorHexField(title: "填充色", hex: hexBinding(get: { r.appliesFillHex }, set: { r.appliesFillHex = $0
                r.updatedAt = Date()
            }))
        }
        ColorHexField(title: "描边色", hex: hexBinding(get: { r.appliesStrokeHex }, set: { r.appliesStrokeHex = $0
            r.updatedAt = Date()
        }))
        TextField("glyph", text: Binding(get: { r.appliesGlyph ?? "" }, set: { r.appliesGlyph = $0.isEmpty ? nil : $0
            r.updatedAt = Date()
        })).glassField()
        ColorHexField(title: "glyph 色", hex: hexBinding(get: { r.appliesGlyphHex }, set: { r.appliesGlyphHex = $0
            r.updatedAt = Date()
        }))
        HStack(spacing: 10) {
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
        labeled("标签") {
            GlassSegmented(
                options: [(value: 0, label: "默认"), (value: 1, label: "显示"), (value: 2, label: "隐藏")],
                selection: Binding(get: { labelTag(r.appliesLabelVisible) }, set: { r.appliesLabelVisible = labelValue($0)
                    r.updatedAt = Date()
                })
            )
        }
    }

    private func conditionsSection(_ r: StyleRule) -> some View {
        let conds = StyleConditionCodec.decode(r.conditionsJSON)
        return StudioDisclosure("条件", summary: "\(conds.count) 条", open: false) {
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
            AddRow("添加条件") { addCondition(r) }
        }
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            content()
        }
    }

    private func hexBinding(get: @escaping () -> String?, set: @escaping (String?) -> Void) -> Binding<String> {
        Binding(get: { get() ?? "" }, set: { set($0.isEmpty ? nil : ColorHexField.normalize($0)) })
    }

    private func optIntField(_ title: String, get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            TextField("—", text: Binding(get: { get().map(String.init) ?? "" }, set: { set($0.isEmpty ? nil : Int($0)) }))
                .glassField().font(Studio.mono(13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optDoubleField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            TextField("—", text: Binding(get: { get().map { String($0) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) }))
                .glassField().font(Studio.mono(13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
