#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var aspect: CanvasAspect
    @Bindable var viewContext: MapViewContext
    @Binding var showSettings: Bool
    @Binding var exportMode: Bool
    @Binding var showSafeFrame: Bool

    var body: some View {
        ZStack {
            // aspect export crop (dims outside the safe frame) — on in 出图模式, else opt-in
            if showSafeFrame || exportMode {
                SafeFrameOverlay(aspect: aspect)
                    .transition(.opacity)
            }

            // title card — top-leading, part of the picture
            VStack {
                HStack {
                    StudioTitleCard(title: $title, subtitle: $subtitle)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 40).padding(.leading, 24)

            // watermark — bottom-trailing, part of the picture
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }
            }
            .padding(16)

            // floating dock — hidden in 出图模式
            if !exportMode {
                VStack {
                    Spacer()
                    StudioToolbar(
                        viewContext: viewContext, aspect: $aspect,
                        onSnapshot: {}, showSettings: $showSettings, exportMode: $exportMode,
                        showSafeFrame: $showSafeFrame
                    )
                    .padding(.bottom, 22)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // tiny exit hint
                VStack {
                    Button { exportMode = false } label: {
                        HStack(spacing: 8) {
                            Text("出图模式").foregroundStyle(Studio.on2)
                            Text("退出").font(Studio.mono(11)).foregroundStyle(Studio.on)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 5))
                        }
                        .font(Studio.sans(13))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
                        .environment(\.colorScheme, .dark)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 22)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: exportMode)
    }
}

/// Aspect export crop — `.safe-frame`. Scrims outside, draws corner ticks + tag.
private struct SafeFrameOverlay: View {
    let aspect: CanvasAspect

    var body: some View {
        GeometryReader { geo in
            let frame = fitted(in: geo.size)
            ZStack {
                // scrim everything, then punch the safe rect clear
                Rectangle().fill(Color(hex: 0x14120F, opacity: 0.34))
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 2).frame(width: frame.width, height: frame.height)
                    }
                // frame outline + corners
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(.white.opacity(0.85), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .overlay(alignment: .topLeading) { tag.padding(8) }
                    .frame(width: frame.width, height: frame.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    private var tag: some View {
        Text(aspect.rawValue)
            .font(Studio.mono(11, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color(hex: 0x14120F, opacity: 0.55), in: RoundedRectangle(cornerRadius: 6))
    }

    private func fitted(in size: CGSize) -> CGSize {
        let margin: CGFloat = 56
        let avail = CGSize(width: size.width - margin * 2, height: size.height - margin * 2)
        let r = aspect.pixelSize.width / aspect.pixelSize.height
        var w = avail.width
        var h = w / r
        if h > avail.height { h = avail.height
            w = h * r
        }
        return CGSize(width: max(0, w), height: max(0, h))
    }
}

private extension View {
    func reverseMask(@ViewBuilder _ mask: () -> some View) -> some View {
        self.mask {
            Rectangle().overlay { mask().blendMode(.destinationOut) }
        }
    }
}
#endif
