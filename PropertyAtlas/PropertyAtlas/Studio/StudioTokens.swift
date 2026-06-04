import SwiftUI

// ============================================================
// PropertyAtlas · Studio Mode — overlay design system
// Single source of truth for the DARK-GLASS floating-chrome
// layer that sits over a fullscreen map. Mirrors design/studio.css.
// All chrome is a ZStack overlay — never a split pane.
// ============================================================

extension Color {
    /// `#RRGGBB` hex, optional alpha override.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Studio design tokens — colors / radii / elevation / type / metrics.
enum Studio {
    // ---- dark-glass surfaces (over map) ----
    static let glass = Color(hex: 0x1E1C19, opacity: 0.72) // primary chrome fill
    static let glassStrong = Color(hex: 0x1A1815, opacity: 0.88) // sheets + menus
    static let glassRaised = Color(hex: 0x48433C, opacity: 0.96) // selected segment / raised
    static let glassInput = Color(hex: 0x000000, opacity: 0.26) // inset field wells
    static let glassHover = Color(hex: 0xFFFFFF, opacity: 0.07)
    static let glassPress = Color(hex: 0x000000, opacity: 0.20)
    static let glassLine = Color(hex: 0xFFFFFF, opacity: 0.10) // hairline divider
    static let glassRim = Color(hex: 0xFFFFFF, opacity: 0.16) // top inset highlight
    static let glassEdge = Color(hex: 0x000000, opacity: 0.48) // outer 0.5px border

    // ---- text/icon on glass ----
    static let on = Color(hex: 0xECE7DD) // primary
    static let on2 = Color(hex: 0xB7B0A4) // secondary / field labels
    static let on3 = Color(hex: 0x837C71) // tertiary / placeholder / disabled

    // ---- DUAL ACCENT ----
    static let amber = Color(hex: 0xD9965A) // brand / output / selection
    static let amberSoft = Color(hex: 0xD9965A, opacity: 0.16)
    static let amberLine = Color(hex: 0xD9965A, opacity: 0.42)
    static let amberHover = Color(hex: 0xE2A468)
    static let brandRaw = Color(hex: 0xB5703A) // title on LIGHT map
    static let cool = Color(hex: 0x6FA0C8) // functional UI
    static let coolSoft = Color(hex: 0x6FA0C8, opacity: 0.16)
    static let coolLine = Color(hex: 0x6FA0C8, opacity: 0.42)

    // ---- ink-on-accent (text laid over amber/cool fills) ----
    static let onAmber = Color(hex: 0x1C1B19)
    static let onCool = Color(hex: 0x11161A)

    // ---- tier palette (legend / zones) ----
    static let tierTop = Color(hex: 0xD2A83C)
    static let tierGood = Color(hex: 0x6F95B8)
    static let tierReg = Color(hex: 0xA39C90)
    static let tierWeak = Color(hex: 0xC68A80)

    // ---- semantic on glass ----
    static let warn = Color(hex: 0xD9965A)
    static let ok = Color(hex: 0x86B08A)
    static let bad = Color(hex: 0xC9897A)

    // ---- CONVERGED radii (3 steps + full) ----
    static let rControl: CGFloat = 8 // buttons · chips · segments · inputs
    static let rCard: CGFloat = 12 // cards · list rows · wells
    static let rPanel: CGFloat = 18 // drawers · sheets · toolbar pill
    static let rSheet: CGFloat = 22 // settings sheet

    // ---- metrics ----
    static let fieldW: CGFloat = 76 // unified field-label column
    static let hit: CGFloat = 44 // min touch target

    /// ---- type ladder ----
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// ============================================================
/// ELEVATION — 2 float steps (CSS --e-float / --e-pop)
/// ============================================================
enum GlassElevation {
    case float, pop

    var shadowRadius: CGFloat {
        self == .float ? 14 : 26
    }

    var shadowY: CGFloat {
        self == .float ? 8 : 18
    }

    var shadowOpacity: Double {
        self == .float ? 0.30 : 0.46
    }
}

/// ============================================================
/// GLASS SURFACE — material blur + dark tint + rim + edge + shadow
/// ============================================================
private struct GlassSurface: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var elevation: GlassElevation

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                shape
                    .fill(fill)
                    .background(.ultraThinMaterial, in: shape)
                    .environment(\.colorScheme, .dark)
            }
            // outer 0.5px dark edge (separation on light maps)
            .overlay { shape.strokeBorder(Studio.glassEdge, lineWidth: 0.5) }
            // inner top rim highlight (separation on dark maps)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Studio.glassRim, .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.75
                )
            }
            .shadow(
                color: .black.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowY
            )
    }
}

extension View {
    /// Dark-glass floating surface (panel / drawer / toolbar / sheet).
    func glassSurface(
        _ fill: Color = Studio.glass,
        radius: CGFloat = Studio.rPanel,
        elevation: GlassElevation = .float
    ) -> some View {
        modifier(GlassSurface(fill: fill, radius: radius, elevation: elevation))
    }

    /// Force the dark color scheme so SF Symbols / Dynamic Type read on glass.
    func onGlass() -> some View {
        environment(\.colorScheme, .dark).foregroundStyle(Studio.on)
    }
}
