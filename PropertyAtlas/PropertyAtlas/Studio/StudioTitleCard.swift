#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioTitleCard: View {
    @Binding var title: String
    @Binding var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("标题", text: $title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 181 / 255, green: 112 / 255, blue: 58 / 255))
                .textFieldStyle(.plain)
            TextField("副标题", text: $subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
#endif
