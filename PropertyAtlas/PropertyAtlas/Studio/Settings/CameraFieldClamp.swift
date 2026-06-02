import Foundation

/// CameraPreset 数字字段边界。
enum CameraFieldClamp {
    /// pitch 限 0…85 度。
    static func pitch(_ v: Double) -> Double {
        min(max(v, 0), 85)
    }

    /// heading 归一到 0…<360 度。
    static func heading(_ v: Double) -> Double {
        let m = v.truncatingRemainder(dividingBy: 360)
        return m < 0 ? m + 360 : m
    }
}
