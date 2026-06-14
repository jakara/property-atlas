import Testing
@testable import PropertyAtlas

@MainActor
struct DrawerDismissTests {
    @Test func settingsWinsOverAll() {
        #expect(
            DrawerDismiss.topmost(settings: true, create: true, placeDetail: true, hasSelection: true)
                == .settings
        )
    }

    @Test func createOverPlaceAndEntity() {
        #expect(
            DrawerDismiss.topmost(settings: false, create: true, placeDetail: true, hasSelection: true)
                == .create
        )
    }

    @Test func placeDetailOverEntity() {
        #expect(
            DrawerDismiss.topmost(settings: false, create: false, placeDetail: true, hasSelection: true)
                == .placeDetail
        )
    }

    @Test func entityWhenOnlySelection() {
        #expect(
            DrawerDismiss.topmost(settings: false, create: false, placeDetail: false, hasSelection: true)
                == .entity
        )
    }

    @Test func nilWhenNothingOpen() {
        #expect(
            DrawerDismiss.topmost(settings: false, create: false, placeDetail: false, hasSelection: false)
                == nil
        )
    }
}
