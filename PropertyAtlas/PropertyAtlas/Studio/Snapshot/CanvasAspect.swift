#if targetEnvironment(macCatalyst)
import CoreGraphics

enum CanvasAspect: String, CaseIterable, Identifiable {
    case ratio16x9 = "16:9"
    case ratio1x1 = "1:1"
    case ratio4x5 = "4:5"
    case ratio9x16 = "9:16"
    case ratio3x4 = "3:4"
    case ratio2x1 = "2:1"
    var id: String {
        rawValue
    }

    var pixelSize: CGSize {
        switch self {
        case .ratio16x9: CGSize(width: 3840, height: 2160)
        case .ratio1x1: CGSize(width: 2560, height: 2560)
        case .ratio4x5: CGSize(width: 2560, height: 3200)
        case .ratio9x16: CGSize(width: 2160, height: 3840)
        case .ratio3x4: CGSize(width: 2560, height: 3413)
        case .ratio2x1: CGSize(width: 3840, height: 1920)
        }
    }
}
#endif
