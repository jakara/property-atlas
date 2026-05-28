import SwiftData
import SwiftUI

struct SeedProgressView: View {
    @Environment(\.modelContext) private var context

    var onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var message: String = "准备…"
    @State private var error: String?
    @State private var started = false

    var body: some View {
        VStack(spacing: 18) {
            Text("PropertyAtlas")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(red: 181 / 255, green: 112 / 255, blue: 58 / 255))
            if let error {
                Text("Seed 导入失败").font(.headline)
                Text(error).font(.callout).foregroundStyle(.secondary)
                Button("重试") { runSeed() }
                Button("跳过 (dev)") { onComplete() }
            } else {
                ProgressView(value: progress)
                    .frame(width: 280)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .task {
            guard !started else { return }
            started = true
            runSeed()
        }
    }

    private func runSeed() {
        error = nil
        Task { @MainActor in
            do {
                try SeedImporter.runIfNeeded(into: context) { p, m in
                    progress = p
                    message = m
                }
                onComplete()
            } catch {
                self.error = String(describing: error)
            }
        }
    }
}
