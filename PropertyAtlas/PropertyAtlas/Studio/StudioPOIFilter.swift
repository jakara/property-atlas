import MapKit

/// 底图 Apple 地点(POI)可选类别。注意:大陆「小区/住宅」无公开 MKPointOfInterestCategory,
/// 选不到;空选 = 显示全部类别。
enum StudioPOIOption: String, CaseIterable, Identifiable {
    case school, hospital, publicTransport, restaurant, cafe, store
    case park, bank, hotel, gasStation, pharmacy, fitnessCenter

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .school: "学校"
        case .hospital: "医院"
        case .publicTransport: "公交地铁"
        case .restaurant: "餐厅"
        case .cafe: "咖啡"
        case .store: "商店"
        case .park: "公园"
        case .bank: "银行"
        case .hotel: "酒店"
        case .gasStation: "加油站"
        case .pharmacy: "药店"
        case .fitnessCenter: "健身"
        }
    }

    var category: MKPointOfInterestCategory {
        switch self {
        case .school: .school
        case .hospital: .hospital
        case .publicTransport: .publicTransport
        case .restaurant: .restaurant
        case .cafe: .cafe
        case .store: .store
        case .park: .park
        case .bank: .bank
        case .hotel: .hotel
        case .gasStation: .gasStation
        case .pharmacy: .pharmacy
        case .fitnessCenter: .fitnessCenter
        }
    }
}
