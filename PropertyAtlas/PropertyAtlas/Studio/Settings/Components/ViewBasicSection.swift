#if targetEnvironment(macCatalyst)
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 视图设置「基本」组:名称/相机/图例/聚光/可见类型/出图文案/启用图层。
/// field 双列布局,紧凑减少纵向滚动。
struct ViewBasicSection: View {
    let mv: MapView
    @Environment(\.modelContext) private var modelContext
    @Query private var cameraPresets: [CameraPreset]
    @Query private var layers: [Layer]
    @State private var qrPickerItem: PhotosPickerItem?

    private let visTypes = [("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")]
    private let defaultVis = #"{"compound":true,"school":true,"poi":true,"area":true}"#

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard("基本") {
                VStack(alignment: .leading, spacing: 12) {
                    twoCol(
                        { field("名称") { TextField("名称", text: nameBinding).glassField() } },
                        { field("相机") { cameraPicker } }
                    )
                    twoCol(
                        { toggleRow("显示图例", legendBinding) },
                        { toggleRow("选中聚光", spotlightBinding) }
                    )
                    field("可见类型") { visChips }
                    SectionLabel(text: "出图文案")
                    twoCol(
                        { field("标题") { TextField("标题", text: optBinding(\.copyTitle)).glassField() } },
                        { field("副标题") { TextField("副标题", text: optBinding(\.copySubtitle)).glassField() } }
                    )
                    field("水印") { TextField("水印", text: optBinding(\.copyWatermark)).glassField() }
                    field("公众号二维码") { qrPicker }
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
            }
            SettingsCard("启用图层") { layerToggles }
        }
    }

    // MARK: - Layout helpers

    private func twoCol(
        @ViewBuilder _ left: () -> some View, @ViewBuilder _ right: () -> some View
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            left().frame(maxWidth: .infinity, alignment: .leading)
            right().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func field(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            content()
        }
    }

    private func toggleRow(_ label: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(Studio.sans(12)).foregroundStyle(Studio.on)
            Spacer(minLength: 4)
            Toggle("", isOn: value).labelsHidden().tint(Studio.cool)
        }
        .frame(height: 30)
    }

    /// 公众号二维码:相册/文件选图 → 存进 mv.watermarkQRData;已选展示缩略图 + 清除。
    private var qrPicker: some View {
        HStack(spacing: 10) {
            if let data = mv.watermarkQRData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 44, height: 44)
                    .background(.white, in: RoundedRectangle(cornerRadius: 6))
            }
            PhotosPicker(selection: $qrPickerItem, matching: .images) {
                Text(mv.watermarkQRData == nil ? "选择图片" : "更换")
                    .font(Studio.sans(12, .medium)).foregroundStyle(Studio.cool)
            }
            if mv.watermarkQRData != nil {
                Button("清除") {
                    mv.watermarkQRData = nil
                    mv.updatedAt = Date()
                }
                .font(Studio.sans(12)).foregroundStyle(Studio.bad)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: qrPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    mv.watermarkQRData = data
                    mv.updatedAt = Date()
                }
            }
        }
    }

    private var cameraPicker: some View {
        Picker("", selection: cameraBinding) {
            Text("无").tag(UUID?.none)
            ForEach(cameraPresets.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) {
                Text($0.name).tag($0.id as UUID?)
            }
        }.labelsHidden().tint(Studio.cool).lineLimit(1)
    }

    private var visChips: some View {
        HStack(spacing: 7) {
            ForEach(visTypes, id: \.0) { type, label in
                let on = decodeVis()[type] ?? true
                StudioChip(label, isOn: on) {
                    var dict = decodeVis()
                    dict[type] = !on
                    mv.visibilityJSON = encodeVis(dict)
                    mv.updatedAt = Date()
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var layerToggles: some View {
        let list = layers.filter { $0.datasetId == mv.datasetId && !$0.deleted }
        return VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, layer in
                if idx > 0 { RowDivider() }
                SettingsRow(title: layer.name) {
                    Toggle("", isOn: layerBinding(layer.id)).labelsHidden().tint(Studio.cool)
                }
            }
        }
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding(get: { mv.name }, set: { mv.name = $0
            mv.updatedAt = Date()
        })
    }

    private func optBinding(_ keyPath: ReferenceWritableKeyPath<MapView, String?>) -> Binding<String> {
        Binding(get: { mv[keyPath: keyPath] ?? "" }, set: { mv[keyPath: keyPath] = $0.isEmpty ? nil : $0
            mv.updatedAt = Date()
        })
    }

    private var legendBinding: Binding<Bool> {
        Binding(get: { mv.showLegend }, set: { mv.showLegend = $0
            mv.updatedAt = Date()
        })
    }

    private var spotlightBinding: Binding<Bool> {
        Binding(get: { mv.spotlightOnSelect }, set: { mv.spotlightOnSelect = $0
            mv.updatedAt = Date()
        })
    }

    private var cameraBinding: Binding<UUID?> {
        Binding(get: { mv.cameraPresetId }, set: { mv.cameraPresetId = $0
            mv.updatedAt = Date()
        })
    }

    private func layerBinding(_ id: UUID) -> Binding<Bool> {
        Binding(get: { mv.enabledLayerIds.contains(id) }, set: { on in
            var set = Set(mv.enabledLayerIds)
            if on { set.insert(id) } else { set.remove(id) }
            mv.enabledLayerIds = Array(set)
            mv.updatedAt = Date()
        })
    }

    // MARK: - Visibility JSON

    private func decodeVis() -> [String: Bool] {
        let fallback: [String: Bool] = ["compound": true, "school": true, "poi": true, "area": true]
        return (try? JSONSerialization.jsonObject(with: Data(mv.visibilityJSON.utf8)) as? [String: Bool]) ?? fallback
    }

    private func encodeVis(_ dict: [String: Bool]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return defaultVis }
        return str
    }
}
#endif
