#if targetEnvironment(macCatalyst)
import Foundation
import Testing
import UIKit
@testable import PropertyAtlas

struct PinShapePathTests {
    @Test func eachShapeProducesNonEmptyPath() {
        let rect = CGRect(x: 0, y: 0, width: 22, height: 22)
        for shape in PinShape.allCases {
            let path = PinShapePath.path(for: shape, in: rect)
            #expect(!path.isEmpty)
            #expect(path.bounds.width > 0)
            #expect(path.bounds.height > 0)
        }
    }

    @Test func circlePathFitsInRect() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let path = PinShapePath.path(for: .circle, in: rect)
        #expect(rect.contains(path.bounds))
    }
}
#endif
