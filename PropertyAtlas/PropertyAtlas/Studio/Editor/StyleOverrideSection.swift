// PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct StyleOverrideSection: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context
    @State private var expanded = false
    @State private var override = OverrideStyle()

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("形状").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { override.shape ?? "" },
                        set: { override.shape = $0.isEmpty ? nil : $0
                            persist()
                        }
                    )) {
                        Text("跟随").tag("")
                        ForEach(shapes, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
                HStack {
                    Text("Glyph").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    TextField("0/2", text: Binding(
                        get: { override.glyph ?? "" },
                        set: { override.glyph = $0.isEmpty ? nil : String($0.prefix(2))
                            persist()
                        }
                    )).textFieldStyle(.roundedBorder).frame(width: 60)
                }
                HStack {
                    Text("填色").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    TextField("#RRGGBB", text: Binding(
                        get: { override.fillHex ?? "" },
                        set: { override.fillHex = $0.isEmpty ? nil : $0
                            persist()
                        }
                    )).textFieldStyle(.roundedBorder).frame(width: 90)
                }
                Button("清空 → 跟随主题") {
                    override = OverrideStyle()
                    persist()
                }.font(.system(size: 11)).foregroundStyle(.red)
            }
            .padding(.top, 6)
        } label: {
            Text("样式 (默认跟随主题)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        }
        .onAppear { override = OverrideStyleCodec.decode(EntityReader.overrideStyleJSON(ref, in: context)) }
    }

    private func persist() {
        EntityWriter.setOverrideStyleJSON(ref, OverrideStyleCodec.encode(override), in: context)
    }
}
#endif
