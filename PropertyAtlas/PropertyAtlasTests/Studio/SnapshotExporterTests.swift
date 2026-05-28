#if targetEnvironment(macCatalyst)
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("SnapshotExporter")
struct SnapshotExporterTests {
    @Test("file name pattern includes district + timestamp")
    func filename() {
        let name = SnapshotExporter.makeFilename(
            district: "和平区",
            date: Date(timeIntervalSince1970: 1_716_700_000)
        )
        #expect(name.hasPrefix("和平区学片图_"))
        #expect(name.hasSuffix(".png"))
    }

    @Test("aspect 16:9 → 3840x2160")
    func aspectSize() {
        #expect(CanvasAspect.ratio16x9.pixelSize.width == 3840)
        #expect(CanvasAspect.ratio16x9.pixelSize.height == 2160)
    }
}
#endif
