#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("CameraPresets")
struct CameraPresetsTests {
    @Test("seed contains all 6 inner districts")
    func sixDistricts() {
        let names = CameraPresets.seed.map(\.name)
        for d in ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"] {
            #expect(names.contains(d))
        }
    }

    @Test("all preset centers within Tianjin bbox")
    func bboxValid() {
        for p in CameraPresets.seed {
            #expect((38.5...40.3).contains(p.center.latitude))
            #expect((116.7...118.0).contains(p.center.longitude))
        }
    }
}
#endif
