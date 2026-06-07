import MapKit

/// 底图 Apple 地点(POI)可选类别 —— 覆盖 iOS 17 `MKPointOfInterestCategory` 主要项。
/// 注意:大陆「小区/住宅」无公开 category,选不到;空选 = 显示全部类别。
enum StudioPOIOption: String, CaseIterable, Identifiable {
    case airport, amusementPark, aquarium, atm, bakery, bank, beach, brewery
    case cafe, campground, carRental, evCharger, fireStation, fitnessCenter, foodMarket, gasStation
    case hospital, hotel, laundry, library, marina, movieTheater, museum, nationalPark
    case nightlife, park, parking, pharmacy, police, postOffice, publicTransport, restaurant
    case restroom, school, stadium, store, theater, university, winery, zoo

    var id: String {
        rawValue
    }

    // swiftlint:disable:next cyclomatic_complexity
    var label: String {
        switch self {
        case .airport: "机场"
        case .amusementPark: "游乐园"
        case .aquarium: "水族馆"
        case .atm: "ATM"
        case .bakery: "烘焙"
        case .bank: "银行"
        case .beach: "海滩"
        case .brewery: "啤酒坊"
        case .cafe: "咖啡"
        case .campground: "露营地"
        case .carRental: "租车"
        case .evCharger: "充电桩"
        case .fireStation: "消防站"
        case .fitnessCenter: "健身"
        case .foodMarket: "菜场"
        case .gasStation: "加油站"
        case .hospital: "医院"
        case .hotel: "酒店"
        case .laundry: "洗衣"
        case .library: "图书馆"
        case .marina: "码头"
        case .movieTheater: "影院"
        case .museum: "博物馆"
        case .nationalPark: "国家公园"
        case .nightlife: "夜生活"
        case .park: "公园"
        case .parking: "停车场"
        case .pharmacy: "药店"
        case .police: "警局"
        case .postOffice: "邮局"
        case .publicTransport: "公交地铁"
        case .restaurant: "餐厅"
        case .restroom: "洗手间"
        case .school: "学校"
        case .stadium: "体育场"
        case .store: "商店"
        case .theater: "剧院"
        case .university: "大学"
        case .winery: "酒庄"
        case .zoo: "动物园"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    var category: MKPointOfInterestCategory {
        switch self {
        case .airport: .airport
        case .amusementPark: .amusementPark
        case .aquarium: .aquarium
        case .atm: .atm
        case .bakery: .bakery
        case .bank: .bank
        case .beach: .beach
        case .brewery: .brewery
        case .cafe: .cafe
        case .campground: .campground
        case .carRental: .carRental
        case .evCharger: .evCharger
        case .fireStation: .fireStation
        case .fitnessCenter: .fitnessCenter
        case .foodMarket: .foodMarket
        case .gasStation: .gasStation
        case .hospital: .hospital
        case .hotel: .hotel
        case .laundry: .laundry
        case .library: .library
        case .marina: .marina
        case .movieTheater: .movieTheater
        case .museum: .museum
        case .nationalPark: .nationalPark
        case .nightlife: .nightlife
        case .park: .park
        case .parking: .parking
        case .pharmacy: .pharmacy
        case .police: .police
        case .postOffice: .postOffice
        case .publicTransport: .publicTransport
        case .restaurant: .restaurant
        case .restroom: .restroom
        case .school: .school
        case .stadium: .stadium
        case .store: .store
        case .theater: .theater
        case .university: .university
        case .winery: .winery
        case .zoo: .zoo
        }
    }
}
