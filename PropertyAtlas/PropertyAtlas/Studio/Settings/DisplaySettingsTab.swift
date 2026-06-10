#if targetEnvironment(macCatalyst)
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// 展示设置(dataset 级):底图样式 / 画幅 / Apple 地点 / 选中聚光 / 出图文案 / 公众号二维码。
/// 多图层同屏后这些全局设置从 MapView 上提到 Dataset。
struct DisplaySettingsTab: View {
    @Bindable var layerCtx: LayerContext
    @State private var qrPickerItem: PhotosPickerItem?

    private var ds: Dataset {
        layerCtx.dataset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsCard("底图 / 出图") {
                VStack(alignment: .leading, spacing: 12) {
                    twoCol(
                        { field("底图样式") { mapStylePicker } },
                        { field("画幅") { aspectPicker } }
                    )
                    toggleRow("显示 Apple 地点", poiEnabledBinding)
                    if ds.poiEnabled {
                        field("地点类别(空=全部)") { poiChips }
                    }
                    toggleRow("选中聚光", spotlightBinding)
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
            }
            SettingsCard("出图文案") {
                VStack(alignment: .leading, spacing: 12) {
                    twoCol(
                        { field("标题") { TextField("标题", text: optBinding(\.copyTitle)).glassField() } },
                        { field("副标题") { TextField("副标题", text: optBinding(\.copySubtitle)).glassField() } }
                    )
                    field("水印") { TextField("水印", text: optBinding(\.copyWatermark)).glassField() }
                    field("公众号二维码") { qrPicker }
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private var mapStylePicker: some View {
        Picker("", selection: Binding(
            get: { StudioMapStyle.resolve(ds.studioMapStyleRaw) },
            set: { ds.studioMapStyleRaw = $0.rawValue
                ds.updatedAt = Date()
            }
        )) {
            ForEach(StudioMapStyle.allCases) { Text($0.label).tag($0) }
        }.labelsHidden().tint(Studio.cool).lineLimit(1)
    }

    private var aspectPicker: some View {
        Picker("", selection: Binding(
            get: { CanvasAspect(rawValue: ds.canvasAspectRaw) ?? .ratio16x9 },
            set: { ds.canvasAspectRaw = $0.rawValue
                ds.updatedAt = Date()
            }
        )) {
            ForEach(CanvasAspect.allCases) { Text($0.rawValue).tag($0) }
        }.labelsHidden().tint(Studio.cool).lineLimit(1)
    }

    private var poiEnabledBinding: Binding<Bool> {
        Binding(get: { ds.poiEnabled }, set: { ds.poiEnabled = $0
            ds.updatedAt = Date()
        })
    }

    private var spotlightBinding: Binding<Bool> {
        Binding(get: { ds.spotlightOnSelect }, set: { ds.spotlightOnSelect = $0
            ds.updatedAt = Date()
        })
    }

    private var poiChips: some View {
        let sel = Set(ds.poiCategoriesRaw.split(separator: ",").map(String.init))
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 6
        ) {
            ForEach(StudioPOIOption.allCases) { opt in
                StudioChip(opt.label, isOn: sel.contains(opt.rawValue)) { togglePOI(opt) }
            }
        }
    }

    private func togglePOI(_ opt: StudioPOIOption) {
        var set = Set(ds.poiCategoriesRaw.split(separator: ",").map(String.init))
        if set.contains(opt.rawValue) { set.remove(opt.rawValue) } else { set.insert(opt.rawValue) }
        ds.poiCategoriesRaw = set.sorted().joined(separator: ",")
        ds.updatedAt = Date()
    }

    /// 公众号二维码:相册/文件选图 → 存进 ds.watermarkQRData;已选展示缩略图 + 清除。
    private var qrPicker: some View {
        HStack(spacing: 10) {
            if let data = ds.watermarkQRData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 44, height: 44)
                    .background(.white, in: RoundedRectangle(cornerRadius: 6))
            }
            PhotosPicker(selection: $qrPickerItem, matching: .images) {
                Text(ds.watermarkQRData == nil ? "选择图片" : "更换")
                    .font(Studio.sans(12, .medium)).foregroundStyle(Studio.cool)
            }
            if ds.watermarkQRData != nil {
                Button("清除") {
                    ds.watermarkQRData = nil
                    ds.updatedAt = Date()
                }
                .font(Studio.sans(12)).foregroundStyle(Studio.bad)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: qrPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    ds.watermarkQRData = data
                    ds.updatedAt = Date()
                }
            }
        }
    }

    // MARK: - Helpers

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

    private func optBinding(_ keyPath: ReferenceWritableKeyPath<Dataset, String?>) -> Binding<String> {
        Binding(
            get: { ds[keyPath: keyPath] ?? "" },
            set: { ds[keyPath: keyPath] = $0.isEmpty ? nil : $0
                ds.updatedAt = Date()
            }
        )
    }
}
#endif
