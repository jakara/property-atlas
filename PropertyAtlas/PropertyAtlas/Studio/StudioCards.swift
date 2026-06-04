#if targetEnvironment(macCatalyst)
import SwiftUI

// ============================================================
// Studio · containers + badges on dark glass (mirrors studio.css
// .card / .row / .sec-label / .field / .disc / .entity-badge / .tierb)
// ============================================================

/// Uppercase section label — `.sec-label`.
struct SectionLabel: View {
    let text: String
    var trailing: String?
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(Studio.sans(10, .semibold)).tracking(1.1)
                .foregroundStyle(Studio.on3)
            if let trailing {
                Spacer()
                Text(trailing).font(Studio.sans(10, .medium)).foregroundStyle(Studio.on3)
            }
        }
    }
}

/// Form-group card well — `.card`. Provide rows separated by hairlines.
struct SettingsCard<Content: View>: View {
    var title: String?
    var trailing: AnyView?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || trailing != nil {
                HStack(spacing: 8) {
                    if let title {
                        Text(title).font(Studio.sans(13, .semibold)).foregroundStyle(Studio.on)
                    }
                    Spacer()
                    if let trailing { trailing }
                }
                .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 9)
            }
            content
        }
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
    }
}

/// Settings row — `.row` (title + optional subtitle | trailing value/control).
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Studio.sans(13)).foregroundStyle(Studio.on)
                if let subtitle {
                    Text(subtitle).font(Studio.sans(11)).foregroundStyle(Studio.on3)
                }
            }
            Spacer(minLength: 8)
            trailing.font(Studio.sans(13)).foregroundStyle(Studio.on2)
        }
        .padding(.horizontal, 13).padding(.vertical, 8)
        .frame(minHeight: 46)
    }
}

/// Hairline between rows inside a card.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(Studio.glassLine).frame(height: 1)
    }
}

/// Read field row — `.field` (76pt label | value).
struct FieldRow: View {
    let key: String
    let value: String
    var mono: Bool = false
    var muted: Bool = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key).font(Studio.sans(11)).foregroundStyle(Studio.on2)
                .frame(width: Studio.fieldW, alignment: .leading)
            Text(value)
                .font(mono ? Studio.mono(13) : Studio.sans(14, muted ? .regular : .medium))
                .foregroundStyle(muted ? Studio.on3 : Studio.on)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
    }
}

/// Entity type badge — `.entity-badge` variants.
struct EntityBadge: View {
    enum Kind { case compound, school, zone, poi }
    let kind: Kind
    var body: some View {
        let (bg, fg, sym, label): (Color, Color, String, String) = switch kind {
        case .compound: (Studio.coolSoft, Studio.cool, "building.2", "小区")
        case .school: (Studio.amberSoft, Studio.amber, "graduationcap", "学校")
        case .zone: (Color(hex: 0xA39C90, opacity: 0.2), Color(hex: 0xC7C0B4), "map", "片区")
        case .poi: (Color(hex: 0x86B08A, opacity: 0.16), Studio.ok, "mappin", "POI")
        }
        return HStack(spacing: 6) {
            Image(systemName: sym).font(.system(size: 10, weight: .semibold))
            Text(label).font(Studio.sans(11, .semibold)).tracking(0.3)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 9).frame(height: 24)
        .background(bg, in: Capsule())
    }
}

/// Inline tier badge — `.tierb`.
struct TierBadge: View {
    enum Tier { case top, good, reg, weak }
    let tier: Tier
    let label: String
    var body: some View {
        let (bg, fg): (Color, Color) = switch tier {
        case .top: (Color(hex: 0xD2A83C, opacity: 0.18), Color(hex: 0xE2C25E))
        case .good: (Color(hex: 0x6F95B8, opacity: 0.2), Color(hex: 0x93B7D6))
        case .reg: (Color(hex: 0xA39C90, opacity: 0.18), Color(hex: 0xC0B9AD))
        case .weak: (Color(hex: 0xC68A80, opacity: 0.18), Color(hex: 0xDCA095))
        }
        Text(label).font(Studio.sans(10, .semibold)).tracking(0.3)
            .foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(bg, in: Capsule())
    }
}

/// Out-of-zoom flag — `.zoom-flag`.
struct ZoomFlag: View {
    let text: String
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
            Text(text).font(Studio.mono(10))
        }
        .foregroundStyle(Studio.warn)
        .padding(.horizontal, 6).padding(.vertical, 1)
        .background(Studio.amberSoft, in: Capsule())
    }
}

/// Private note — `.lock-note`.
struct LockNote: View {
    let text: String
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill").font(.system(size: 13))
                .foregroundStyle(Studio.amber)
            Text(text).font(Studio.sans(12)).foregroundStyle(Color(hex: 0xE7C49E))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(Studio.amberSoft, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous)
                .strokeBorder(Studio.amberLine, lineWidth: 1)
        }
    }
}

/// Collapsible disclosure group — `.disc`.
struct StudioDisclosure<Content: View>: View {
    let title: String
    var summary: String?
    @State var open: Bool
    @ViewBuilder var content: Content

    init(_ title: String, summary: String? = nil, open: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.summary = summary
        _open = State(initialValue: open)
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.16)) { open.toggle() } } label: {
                HStack(spacing: 9) {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Studio.on2).rotationEffect(.degrees(open ? 90 : 0))
                    Text(title).font(Studio.sans(13, .semibold)).foregroundStyle(Studio.on)
                    Spacer()
                    if let summary { Text(summary).font(Studio.sans(11)).foregroundStyle(Studio.on3) }
                }
                .frame(height: 44).padding(.horizontal, 12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 4)
                    .overlay(alignment: .top) { Rectangle().fill(Studio.glassLine).frame(height: 1) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
    }
}
#endif
