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
        ZStack {
            Color(hex: 0x15140F).ignoresSafeArea()
            Group {
                if let error { errorState(error) } else { loadingState }
            }
            .padding(64)
        }
        .environment(\.colorScheme, .dark)
        .task {
            guard !started else { return }
            started = true
            runSeed()
        }
    }

    // MARK: states

    private var loadingState: some View {
        VStack(spacing: 0) {
            mark(systemImage: "map.fill", tint: Studio.amber, soft: Studio.amberSoft, line: Studio.amberLine)
            Text("PROPERTYATLAS")
                .font(Studio.sans(12, .semibold)).tracking(2)
                .foregroundStyle(Studio.amber).padding(.top, 24).padding(.bottom, 10)
            Text("正在准备地图数据")
                .font(.system(size: 28, weight: .bold)).foregroundStyle(Color(hex: 0xF4EFE4))
            Text("首次启动会把天津的小区、学校、区域导入本机数据库，稍候片刻。")
                .font(Studio.sans(14)).foregroundStyle(Studio.on2)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 380).padding(.top, 8)

            // active step line
            HStack(spacing: 12) {
                ProgressView().controlSize(.small).tint(Studio.amber)
                Text(message).font(Studio.sans(14)).foregroundStyle(Color(hex: 0xF4EFE4))
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 340).padding(.top, 38)

            // bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07))
                    Capsule().fill(Studio.amber).frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 340, height: 4).padding(.top, 20)

            Text("\(Int(progress * 100))%")
                .font(Studio.mono(12)).foregroundStyle(Studio.on2).padding(.top, 12)
        }
    }

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 0) {
            mark(
                systemImage: "exclamationmark.triangle",
                tint: Studio.bad,
                soft: Color(hex: 0xC9897A, opacity: 0.16),
                line: Color(hex: 0xC9897A, opacity: 0.4)
            )
            Text("Seed 导入失败")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(Color(hex: 0xF4EFE4))
                .padding(.top, 20)
            Text(error).font(Studio.sans(13)).foregroundStyle(Studio.on2)
                .multilineTextAlignment(.center).frame(maxWidth: 380).padding(.top, 8)
            HStack(spacing: 10) {
                seedBtn("重试", fill: Studio.amber, fg: Studio.onAmber) { runSeed() }
                seedBtn("跳过 (dev)", fill: Studio.glassHover, fg: Studio.on) { onComplete() }
            }
            .padding(.top, 28)
        }
    }

    private func mark(systemImage: String, tint: Color, soft: Color, line: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 32, weight: .light)).foregroundStyle(tint)
            .frame(width: 72, height: 72)
            .background(soft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(line, lineWidth: 1)
            }
    }

    private func seedBtn(_ label: String, fill: Color, fg: Color, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Text(label).font(Studio.sans(13, .semibold)).foregroundStyle(fg)
                .padding(.horizontal, 14).frame(height: 36)
                .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
