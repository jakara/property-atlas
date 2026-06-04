#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct CameraSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [CameraPreset]

    private var dsPresets: [CameraPreset] {
        presets.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "机位预设", trailing: "\(dsPresets.count)")
            ForEach(dsPresets, id: \.id) { p in card(p) }
            AddRow("保存当前机位") { addPreset() }
        }
    }

    private func card(_ p: CameraPreset) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "video").font(.system(size: 14)).foregroundStyle(Studio.cool)
                    TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0
                        p.updatedAt = Date()
                    }))
                    .glassField()
                    Button(role: .destructive) { p.deleted = true
                        p.updatedAt = Date()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 10) {
                    numField("纬度", get: { p.centerLat }, set: { p.centerLat = $0
                        p.updatedAt = Date()
                    })
                    numField("经度", get: { p.centerLon }, set: { p.centerLon = $0
                        p.updatedAt = Date()
                    })
                }
                HStack(spacing: 10) {
                    numField("距离", get: { p.distance }, set: { p.distance = $0
                        p.updatedAt = Date()
                    })
                    numField("俯仰", get: { p.pitch }, set: { p.pitch = CameraFieldClamp.pitch($0)
                        p.updatedAt = Date()
                    })
                    numField("朝向", get: { p.heading }, set: { p.heading = CameraFieldClamp.heading($0)
                        p.updatedAt = Date()
                    })
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 12)
        }
    }

    private func numField(_ title: String, get: @escaping () -> Double, set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            TextField("0", text: Binding(get: { String(get()) }, set: { if let d = Double($0) { set(d) } }))
                .glassField()
                .font(Studio.mono(13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addPreset() {
        let p = CameraPreset(datasetId: datasetId, name: "新机位", centerLat: 39.12, centerLon: 117.2, distance: 15000)
        p.sortOrder = (dsPresets.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
