#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct SchoolDetailCard: View {
    let schoolId: UUID
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var school: School?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header()
            Divider()
            ScrollView {
                if let s = school {
                    VStack(alignment: .leading, spacing: 14) {
                        group("基本", rows: [
                            ("name", s.name),
                            ("district", s.district),
                            ("type", s.type),
                            ("zone_name", s.zoneName),
                            ("address", s.address),
                            ("phone", s.phone),
                            ("campuses", s.campuses),
                            ("isPublic", String(s.isPublicSchool)),
                            ("isJiunian", String(s.isJiunian)),
                            ("is12Year", String(s.is12Year)),
                        ])
                        group("招生", rows: [
                            ("zoneId", s.zoneId?.uuidString),
                            ("tuition", s.tuition),
                            ("communitiesText", s.communitiesText),
                        ])
                        group("市场标签", rows: [
                            ("isMarketFive", String(s.isMarketFive)),
                            ("isMarketKey", String(s.isMarketKey)),
                        ])
                        group("梯队 (粗 3 档)", rows: [
                            ("tier", s.tier),
                        ])
                        group("地理坐标", rows: [
                            ("lat", s.lat.map { String(format: "%.6f", $0) }),
                            ("lon", s.lon.map { String(format: "%.6f", $0) }),
                            ("geocodeSource", s.geocodeSource),
                            ("geocodeConfidence", s.geocodeConfidence),
                        ])
                        group("标识", rows: [
                            ("id", s.id.uuidString),
                            ("sourceCode", s.sourceCode),
                        ])
                        sensitiveGroup(s)
                        if let n = s.notes, !n.isEmpty {
                            group("备注", rows: [("note", n)])
                        }
                    }
                    .padding(12)
                } else {
                    Text("加载中…").padding(12).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .task(id: schoolId) {
            await fetchSchool()
        }
    }

    private func fetchSchool() async {
        let id = schoolId
        var fd = FetchDescriptor<School>(predicate: #Predicate { $0.id == id })
        fd.fetchLimit = 1
        school = try? context.fetch(fd).first
    }

    private func header() -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(school?.name ?? "—")
                    .font(.system(size: 14, weight: .bold))
                Text("\(school?.district ?? "") · \(school?.type ?? "")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
    }

    private func group(_ title: String, rows: [(String, String?)]) -> some View {
        let visible = rows.filter { $0.1 != nil && !($0.1 ?? "").isEmpty }
        return Group {
            if !visible.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(visible, id: \.0) { k, v in
                        row(label: k, value: v ?? "")
                    }
                }
            }
        }
    }

    private func sensitiveGroup(_ s: School) -> some View {
        let rows: [(String, String?)] = [
            ("tier_letter", s.sensitiveTierLetter),
            ("tier_label", s.sensitiveTierLabel),
            ("rank_overall", s.sensitiveRankOverall.map(String.init)),
            ("top_percentile", s.sensitiveTopPercentile.map(String.init)),
            ("tier_rank", s.sensitiveTierRank.map(String.init)),
            ("comment", s.sensitiveComment),
            ("data_origin", s.sensitiveDataOrigin),
            ("source", s.sensitiveSource),
            ("source_url", s.sensitiveSourceUrl),
            ("note", s.sensitiveNote),
        ]
        let visible = rows.filter { $0.1 != nil && !($0.1 ?? "").isEmpty }
        return Group {
            if !visible.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("评级 (sensitive)")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9)).foregroundStyle(.orange)
                    }
                    ForEach(visible, id: \.0) { k, v in
                        row(label: k, value: v ?? "")
                    }
                }
            }
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label).font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
