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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("相机机位").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addPreset() } label: { Label("新机位", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsPresets, id: \.id) { p in card(p) }
        }
    }

    private func card(_ p: CameraPreset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0
                    p.updatedAt = Date()
                })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { p.deleted = true
                    p.updatedAt = Date()
                } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                numField("纬度", get: { p.centerLat }, set: { p.centerLat = $0
                    p.updatedAt = Date()
                })
                numField("经度", get: { p.centerLon }, set: { p.centerLon = $0
                    p.updatedAt = Date()
                })
            }
            HStack {
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
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func numField(_ title: String, get: @escaping () -> Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("0", text: Binding(get: { String(get()) }, set: { if let d = Double($0) { set(d) } }))
                .font(.system(size: 12).monospaced()).frame(width: 70)
        }
    }

    private func addPreset() {
        let p = CameraPreset(datasetId: datasetId, name: "新机位", centerLat: 39.12, centerLon: 117.2, distance: 15000)
        p.sortOrder = (dsPresets.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
