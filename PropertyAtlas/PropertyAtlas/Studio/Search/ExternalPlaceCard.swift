// PropertyAtlas/PropertyAtlas/Studio/Search/ExternalPlaceCard.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 外部搜索 POI 的详情卡(右抽屉位):展示 Apple 官方信息 + 「添加为 POI」。
struct ExternalPlaceCard: View {
    let place: ExternalPlaceSearch.PlaceHit
    let onAddPOI: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(alignment: .leading, spacing: 8) {
                if let category = place.category, !category.isEmpty {
                    infoRow(icon: "tag", text: category)
                }
                if let address = place.fullAddress ?? Optional(place.subtitle), !address.isEmpty {
                    infoRow(icon: "mappin.and.ellipse", text: address)
                }
                if let phone = place.phone, !phone.isEmpty {
                    infoRow(icon: "phone", text: phone)
                }
                if let url = place.url {
                    Link(destination: url) {
                        infoRow(icon: "link", text: url.absoluteString)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(action: onAddPOI) {
                HStack(spacing: 7) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加为 POI").font(Studio.sans(14, .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tbtn(.primary))
        }
        .padding(16).frame(width: 300)
        .glassSurface(Studio.glassStrong, radius: Studio.rPanel, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(Studio.sans(17, .bold)).foregroundStyle(Studio.on)
                Text("外部地点 · Apple").font(Studio.sans(11)).foregroundStyle(Studio.on3)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(Studio.on2)
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Studio.on3).frame(width: 16)
            Text(text).font(Studio.sans(13)).foregroundStyle(Studio.on2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
#endif
