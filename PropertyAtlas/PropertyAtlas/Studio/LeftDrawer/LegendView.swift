// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 一组图例(primary groupBy 或某个 normal filter):标题 + 维度键 + 行。
struct LegendSection: Identifiable {
    let title: String
    let dimensionKey: String
    let rows: [DimensionLegendCounter.Row]
    var id: String {
        dimensionKey
    }
}

struct LegendView: View {
    let sections: [LegendSection]
    @Bindable var filterState: DimensionFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "图例").padding(.horizontal, 8)
            if sections.allSatisfy(\.rows.isEmpty) {
                Text("拖动地图后显示").font(Studio.sans(11)).foregroundStyle(Studio.on3)
                    .padding(.horizontal, 8)
            }
            ForEach(Array(sections.enumerated()), id: \.element.id) { idx, section in
                if !section.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title).font(Studio.sans(11, .semibold)).foregroundStyle(Studio.on2)
                            .padding(.horizontal, 8)
                        ForEach(section.rows) { row in chip(section.dimensionKey, row) }
                    }
                    .padding(.top, idx == 0 ? 0 : 4)
                }
            }
        }
    }

    private func chip(_ dimensionKey: String, _ row: DimensionLegendCounter.Row) -> some View {
        let hidden = filterState.isHidden(dimensionKey: dimensionKey, value: row.value)
        return Button {
            filterState.toggle(dimensionKey: dimensionKey, value: row.value)
        } label: {
            HStack(spacing: 9) {
                Circle().fill(Color(uiColor: HexColor.parse(row.swatchHex) ?? .gray))
                    .frame(width: 12, height: 12)
                    .overlay { Circle().strokeBorder(.white.opacity(hidden ? 0 : 0.08), lineWidth: 2) }
                    .grayscale(hidden ? 0.6 : 0)
                Text(row.value).font(Studio.sans(13)).foregroundStyle(Studio.on).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(row.viewport) / \(row.total)")
                    .font(Studio.mono(11, .semibold)).foregroundStyle(Studio.on3)
            }
            .opacity(hidden ? 0.4 : 1)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
