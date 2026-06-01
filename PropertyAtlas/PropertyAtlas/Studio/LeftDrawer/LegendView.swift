// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 一组图例(primary groupBy 或某个 normal filter):标题 + 维度键 + 行。
struct LegendSection: Identifiable {
    let title: String
    let dimensionKey: String
    let rows: [DimensionLegendCounter.Row]
    var id: String { dimensionKey }
}

struct LegendView: View {
    let sections: [LegendSection]
    @Bindable var filterState: DimensionFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图例").font(.system(size: 12, weight: .bold))
            if sections.allSatisfy({ $0.rows.isEmpty }) {
                Text("拖动地图后显示").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(sections) { section in
                if !section.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        ForEach(section.rows) { row in chip(section.dimensionKey, row) }
                    }
                }
            }
        }
    }

    private func chip(_ dimensionKey: String, _ row: DimensionLegendCounter.Row) -> some View {
        let hidden = filterState.isHidden(dimensionKey: dimensionKey, value: row.value)
        return Button {
            filterState.toggle(dimensionKey: dimensionKey, value: row.value)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Color(uiColor: HexColor.parse(row.swatchHex) ?? .gray)).frame(width: 12, height: 12)
                Text(row.value).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(row.viewport) / \(row.total)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .opacity(hidden ? 0.35 : 1)
            .contentShape(Rectangle())
            .padding(.leading, 8)
        }.buttonStyle(.plain)
    }
}
#endif
