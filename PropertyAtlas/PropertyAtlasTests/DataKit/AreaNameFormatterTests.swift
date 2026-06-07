import Testing
@testable import PropertyAtlas

struct AreaNameFormatterTests {
    @Test func schoolPianKeepsPian() {
        #expect(AreaNameFormatter.displayName(district: "和平区", zoneName: "第一学片") == "和平一片")
        #expect(AreaNameFormatter.displayName(district: "和平区", zoneName: "第三学片") == "和平三片")
    }

    @Test func schoolQuKeepsQu() {
        #expect(AreaNameFormatter.displayName(district: "河西区", zoneName: "第一学区") == "河西一区")
        #expect(AreaNameFormatter.displayName(district: "河东区", zoneName: "第五学区") == "河东五区")
    }

    @Test func parentheticalKept() {
        #expect(AreaNameFormatter.displayName(district: "南开区", zoneName: "第一学区(北片)") == "南开北片")
        #expect(AreaNameFormatter.displayName(district: "南开区", zoneName: "第二学区(中片)") == "南开中片")
        #expect(AreaNameFormatter.displayName(district: "南开区", zoneName: "第三学区(南片)") == "南开南片")
    }

    @Test func fullwidthParenthetical() {
        #expect(AreaNameFormatter.displayName(district: "南开区", zoneName: "第一学区（北片）") == "南开北片")
    }

    @Test func administrativeAreaJustShort() {
        #expect(AreaNameFormatter.displayName(district: "北辰区", zoneName: "行政区域") == "北辰")
        #expect(AreaNameFormatter.displayName(district: "滨海新区", zoneName: "行政区域") == "滨海")
    }

    @Test func stripsSelfDistrictPrefix() {
        #expect(AreaNameFormatter.displayName(district: "津南区", zoneName: "津南区-一") == "津南一区")
        #expect(AreaNameFormatter.displayName(district: "津南区", zoneName: "津南区-八") == "津南八区")
        #expect(AreaNameFormatter.displayName(district: "滨海新区", zoneName: "滨海新区-塘沽1") == "塘沽1")
        #expect(AreaNameFormatter.displayName(district: "滨海新区", zoneName: "滨海新区-生态城") == "生态城")
        #expect(AreaNameFormatter.displayName(district: "滨海新区", zoneName: "滨海新区-泰达管委会") == "泰达管委会")
    }

    @Test func fallbackPrefixesShort() {
        #expect(AreaNameFormatter.displayName(district: "和平区", zoneName: "全区招生") == "和平全区招生")
        #expect(AreaNameFormatter.displayName(district: "和平区", zoneName: "特殊学校") == "和平特殊学校")
    }

    @Test func districtShort() {
        #expect(AreaNameFormatter.districtShort("和平区") == "和平")
        #expect(AreaNameFormatter.districtShort("滨海新区") == "滨海")
        #expect(AreaNameFormatter.districtShort("蓟州区") == "蓟州")
    }
}
