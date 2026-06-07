#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

/// Bottom-right badge — part of the exported picture (`.watermark`)。出图/非出图均展示。
/// 公众号二维码(可选)在上,胶囊 `@handle · PropertyAtlas` 在下。
struct StudioWatermark: View {
    let text: String
    var qrData: Data?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let qrData, let image = UIImage(data: qrData) {
                Image(uiImage: image)
                    .resizable().interpolation(.none).scaledToFit()
                    .frame(width: 84, height: 84)
                    .padding(6)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Studio.glassRim, lineWidth: 0.5) }
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
            }
            capsule
        }
    }

    private var capsule: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Studio.amber)
                Image(systemName: "map.fill").font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Studio.onAmber)
            }
            .frame(width: 16, height: 16)
            handle
        }
        .padding(.leading, 10).padding(.trailing, 13).padding(.vertical, 7)
        .background(Studio.glass, in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Studio.glassRim, lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        .environment(\.colorScheme, .dark)
    }

    /// Split `@xxx · PropertyAtlas` so the handle reads amber, separator dim.
    @ViewBuilder private var handle: some View {
        let parts = text.components(separatedBy: " · ")
        HStack(spacing: 4) {
            Text(parts.first ?? text)
                .font(Studio.sans(13, .semibold))
                .foregroundStyle((parts.first ?? text).hasPrefix("@") ? Studio.amber : Studio.on)
            if parts.count > 1 {
                Text("·").foregroundStyle(Studio.on3)
                Text(parts[1]).font(Studio.sans(13, .semibold)).foregroundStyle(Studio.on)
            }
        }
    }
}
#endif
