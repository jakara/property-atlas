import Foundation

/// 编译期品牌配置。改这里需重编译(刻意做成编译期常量,出图品牌不随运行时变)。
/// 控制左上角标题卡的品牌 kicker(原 "PROPERTYATLAS")是否展示、展示什么。
enum BrandConfig {
    /// 是否在标题卡顶部展示品牌 kicker。
    static let showBrandKicker = true
    /// 品牌 kicker 文案(全大写小标)。
    static let brandKicker = "PROPERTYATLAS"
}
