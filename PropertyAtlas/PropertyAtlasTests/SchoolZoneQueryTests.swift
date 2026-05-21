import SwiftData
import Testing

@MainActor
struct SchoolZoneQueryTests {
    var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: SchoolZone.self,
            School.self,
            Compound.self,
            configurations: config
        )
    }()

    @Test func primarySchoolLookup() throws {
        let ctx = container.mainContext
        let zone = SchoolZone(
            name: "和平一区",
            tier: "顶尖",
            primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.2,39.1],[117.3,39.1],[117.3,39.2],[117.2,39.1]]]}"#
        )
        let school = School(name: "实验小学", type: "小学", zoneId: zone.id, district: "和平区", tier: "顶尖")
        let compound = Compound(name: "珑璟台", district: "和平区", latitude: 39.15, longitude: 117.25)
        compound.zoneId = zone.id
        compound.primarySchoolId = school.id
        ctx.insert(zone)
        ctx.insert(school)
        ctx.insert(compound)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.id == compound.primarySchoolId! }
        ))
        #expect(fetched.first?.name == "实验小学")
    }

    @Test func middleSchoolsInZone() throws {
        let ctx = container.mainContext
        let zone = SchoolZone(
            name: "南开一区",
            tier: "优质",
            primaryDistrict: "南开区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.0],[117.2,39.0],[117.2,39.1],[117.1,39.0]]]}"#
        )
        let ms1 = School(name: "南开中学", type: "初中", zoneId: zone.id, district: "南开区", tier: "顶尖")
        let ms2 = School(name: "实验中学", type: "初中", zoneId: zone.id, district: "南开区", tier: "优质")
        let ps = School(name: "万全道小学", type: "小学", zoneId: zone.id, district: "南开区")
        ctx.insert(zone)
        ctx.insert(ms1)
        ctx.insert(ms2)
        ctx.insert(ps)
        try ctx.save()

        let middles = try ctx.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.zoneId == zone.id && $0.type == "初中" }
        ))
        #expect(middles.count == 2)
    }
}
