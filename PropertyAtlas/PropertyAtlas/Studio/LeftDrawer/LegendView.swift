// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LegendView: View {
    let rows: [LegendCounter.Row]
    @Bindable var filterState: FilterState

    private var byType: [(type: String, label: String)] {
        [("school", "学校"), ("compound", "小区"), ("poi", "POI"), ("area", "片区")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图例").font(.system(size: 12, weight: .bold))
            if rows.isEmpty {
                Text("拖动地图后显示").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(byType, id: \.type) { t in
                let typeRows = rows.filter { $0.entityType == t.type }
                if !typeRows.isEmpty { typeSection(label: t.label, rows: typeRows) }
            }
        }
    }

    private func typeSection(label: String, rows: [LegendCounter.Row]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            let groups = Dictionary(grouping: rows, by: { $0.fieldLabel })
            ForEach(groups.keys.sorted(by: { slot(groups[$0]) < slot(groups[$1]) }), id: \.self) { fieldLabel in
                Text(fieldLabel).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.leading, 4)
                ForEach(groups[fieldLabel] ?? []) { row in chip(row) }
            }
        }
    }

    private func slot(_ rows: [LegendCounter.Row]?) -> Int {
        rows?.first?.slot ?? 99
    }

    private func chip(_ row: LegendCounter.Row) -> some View {
        let hidden = filterState.isHidden(entityType: row.entityType, fieldKey: row.fieldKey, value: row.value)
        return Button {
            filterState.toggle(entityType: row.entityType, fieldKey: row.fieldKey, value: row.value)
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
