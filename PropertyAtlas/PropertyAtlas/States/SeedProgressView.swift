import SwiftUI

struct SeedProgressView: View {
    var onComplete: () -> Void
    var body: some View {
        Button("Skip Seed (dev)") { onComplete() }
    }
}
