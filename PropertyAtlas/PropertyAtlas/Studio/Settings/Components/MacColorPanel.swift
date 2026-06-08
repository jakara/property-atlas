#if targetEnvironment(macCatalyst)
import Foundation

/// 经反射关闭 macOS 系统取色器(NSColorPanel,SwiftUI ColorPicker 弹出的浮窗)。
/// Catalyst 无 AppKit import,用 NSClassFromString + KVC/perform。取色器是独立浮窗,
/// 不随字段失焦自动消失 → 字段消失/手动按钮时主动 orderOut。
enum MacColorPanel {
    static func close() {
        guard let cls = NSClassFromString("NSColorPanel") as? NSObject.Type,
              let panel = cls.value(forKey: "sharedColorPanel") as? NSObject
        else { return }
        let sel = NSSelectorFromString("orderOut:")
        if panel.responds(to: sel) { panel.perform(sel, with: nil) }
    }
}
#endif
