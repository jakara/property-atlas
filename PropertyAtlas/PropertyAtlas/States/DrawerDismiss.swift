import Foundation

/// ESC 关闭右侧抽屉:返回当前最上层应关的目标。纯逻辑,便于单测;RootView 据此关对应抽屉。
/// 优先级(高→低,按屏上层级):设置 > 新建 > 地点详情浮卡 > 实体详情。nil = 无可关。
enum DrawerDismiss {
    enum Target: Equatable { case settings, create, placeDetail, entity }

    static func topmost(settings: Bool, create: Bool, placeDetail: Bool, hasSelection: Bool) -> Target? {
        if settings { return .settings }
        if create { return .create }
        if placeDetail { return .placeDetail }
        if hasSelection { return .entity }
        return nil
    }
}
