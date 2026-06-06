#if targetEnvironment(macCatalyst)
import SwiftUI

// ============================================================
// Studio · reusable form controls on dark glass (mirrors studio.css
// .inp / .seg / .chip / .sw / .stepper / .tbtn / .add-row)
// ============================================================

/// Inset field well — `.inp`. Apply to TextField/etc.
struct GlassFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(Studio.sans(14))
            .foregroundStyle(Studio.on)
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                    .strokeBorder(Studio.glassLine, lineWidth: 1)
            }
    }
}

extension View {
    func glassField() -> some View {
        textFieldStyle(GlassFieldStyle())
    }
}

/// Multi-pick pill chip — `.chip` / `.chip.on` (cool) / `.chip.amber.on`.
struct StudioChip: View {
    let label: String
    var systemImage: String?
    var isOn: Bool
    var amber: Bool = false
    var action: () -> Void

    init(_ label: String, systemImage: String? = nil, isOn: Bool, amber: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.isOn = isOn
        self.amber = amber
        self.action = action
    }

    var body: some View {
        let tint = amber ? Studio.amber : Studio.cool
        let soft = amber ? Studio.amberSoft : Studio.coolSoft
        let line = amber ? Studio.amberLine : Studio.coolLine
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 12)) }
                Text(label).font(Studio.sans(13, .medium))
            }
            .foregroundStyle(isOn ? tint : Studio.on2)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(isOn ? soft : .clear, in: Capsule())
            .overlay { Capsule().strokeBorder(isOn ? line : Studio.glassLine, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

/// Segmented control on glass — `.seg.full`.
struct GlassSegmented<T: Hashable>: View {
    let options: [(value: T, label: String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { opt in
                let on = selection == opt.value
                Button { selection = opt.value } label: {
                    Text(opt.label)
                        .font(Studio.sans(13, .medium))
                        .foregroundStyle(on ? Studio.on : Studio.on2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            on ? Studio.glassRaised : .clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .shadow(color: .black.opacity(on ? 0.25 : 0), radius: 1, y: 1)
                        // 整段可点:背景含 .clear,无 contentShape 时只有文字字形被命中,
                        // 段内空白成死区(点矩形部分无反应)。补成整 frame 命中。
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(3)
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
    }
}

/// Stepper well — `.stepper`.
struct GlassStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = .min ... .max
    var step: Int = 1
    var format: (Int) -> String = { String($0) }

    var body: some View {
        HStack(spacing: 0) {
            btn("minus") { value = max(range.lowerBound, value - step) }
            Text(format(value))
                .font(Studio.sans(14, .semibold).monospacedDigit())
                .foregroundStyle(Studio.on)
                .frame(minWidth: 52, minHeight: 36)
                .overlay(alignment: .leading) { Rectangle().fill(Studio.glassLine).frame(width: 1) }
                .overlay(alignment: .trailing) { Rectangle().fill(Studio.glassLine).frame(width: 1) }
            btn("plus") { value = min(range.upperBound, value + step) }
        }
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                .strokeBorder(Studio.glassLine, lineWidth: 1)
        }
    }

    private func btn(_ sym: String, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: sym).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Studio.on).frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

/// ---- text buttons — `.tbtn` ----
enum TBtnKind { case primary, cool, ghost, dangerGhost }

struct TBtnStyle: ButtonStyle {
    var kind: TBtnKind
    func makeBody(configuration: Configuration) -> some View {
        let (bg, fg, border): (Color, Color, Color?) = switch kind {
        case .primary: (Studio.amber, Studio.onAmber, nil)
        case .cool: (Studio.cool, Studio.onCool, nil)
        case .ghost: (Studio.glassHover, Studio.on, nil)
        case .dangerGhost: (.clear, Studio.bad, Studio.bad.opacity(0.4))
        }
        return configuration.label
            .font(Studio.sans(13, .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(bg, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension ButtonStyle where Self == TBtnStyle {
    static func tbtn(_ kind: TBtnKind = .ghost) -> TBtnStyle {
        TBtnStyle(kind: kind)
    }
}

/// Dashed add-row — `.add-row`.
struct AddRow: View {
    let label: String
    var action: () -> Void
    init(_ label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                Text(label).font(Studio.sans(13, .medium))
            }
            .foregroundStyle(Studio.cool)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Studio.glassLine)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
