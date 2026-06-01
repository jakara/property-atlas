#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var aspect: CanvasAspect
    @Bindable var viewContext: MapViewContext

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                StudioToolbar(viewContext: viewContext, aspect: $aspect, onSnapshot: {})
                    .padding(.bottom, 24)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }
                .padding(16)
            }
        }
    }
}
#endif
