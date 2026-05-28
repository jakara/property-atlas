#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioWatermark: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.black.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.6), in: Capsule())
    }
}
#endif
