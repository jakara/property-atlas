#if targetEnvironment(macCatalyst)
import SwiftUI

/// Title card — part of the exported picture (`.titlecard`). 仅出图模式展示。
/// Kicker(编译期 BrandConfig)+ 32pt bold 标题 + 副标题。文案在视图设置「出图文案」配。
struct StudioTitleCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if BrandConfig.showBrandKicker {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1).fill(Studio.brandRaw)
                        .frame(width: 22, height: 2)
                    Text(BrandConfig.brandKicker)
                        .font(Studio.sans(12, .semibold)).tracking(1.6)
                        .foregroundStyle(Studio.brandRaw)
                }
            }
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color(hex: 0x2A2520))
                    .shadow(color: Color(hex: 0xFAF8F4, opacity: 0.6), radius: 18, y: 1)
            }
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x6B6155))
            }
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}
#endif
