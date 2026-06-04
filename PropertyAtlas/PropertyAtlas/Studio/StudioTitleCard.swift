#if targetEnvironment(macCatalyst)
import SwiftUI

/// Title card — part of the exported picture (`.titlecard`).
/// Kicker + 32pt bold brand title + subtitle. Tuned for a LIGHT map base.
struct StudioTitleCard: View {
    @Binding var title: String
    @Binding var subtitle: String
    var kicker: String = "PROPERTYATLAS"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(Studio.brandRaw)
                    .frame(width: 22, height: 2)
                Text(kicker)
                    .font(Studio.sans(12, .semibold)).tracking(1.6)
                    .foregroundStyle(Studio.brandRaw)
            }
            TextField("标题", text: $title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color(hex: 0x2A2520))
                .textFieldStyle(.plain)
                .shadow(color: Color(hex: 0xFAF8F4, opacity: 0.6), radius: 18, y: 1)
            TextField("副标题", text: $subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: 0x6B6155))
                .textFieldStyle(.plain)
        }
        .frame(maxWidth: 480, alignment: .leading)
    }
}
#endif
