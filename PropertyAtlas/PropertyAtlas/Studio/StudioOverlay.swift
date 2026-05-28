#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var selectedPreset: CameraPreset
    @Binding var aspect: CanvasAspect
    @Binding var showZoneFill: Bool
    @Binding var showSchoolPins: Bool
    @Binding var showSchoolLabels: Bool
    @Binding var filter: PinFilter
    let visibleZones: [StudioLegend.VisibleZone]
    @Binding var selectedSchoolId: UUID?
    let onSnapshot: () -> Void
    var showToolbar: Bool = true

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    StudioLegend(filter: $filter, visibleZones: visibleZones)
                    Spacer()
                    if let id = selectedSchoolId {
                        SchoolDetailCard(schoolId: id, onClose: { selectedSchoolId = nil })
                    }
                }
                .padding(16)
                Spacer()
            }
            if showToolbar {
                VStack {
                    Spacer()
                    StudioToolbar(
                        selectedPreset: $selectedPreset,
                        aspect: $aspect,
                        showZoneFill: $showZoneFill,
                        showSchoolPins: $showSchoolPins,
                        showSchoolLabels: $showSchoolLabels,
                        onSnapshot: onSnapshot
                    )
                    .padding(.bottom, 24)
                }
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
