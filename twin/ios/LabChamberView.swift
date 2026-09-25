import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Lab landing page — exact Lab of Creations scene + 3D floating icons at top.
/// Homepage LabIcon opens here. Desk tablet opens living LAB MANUAL PDF.
/// BOTTOM-CHROME-STRIP: no page EXIT/xmark (ЯBAR Home leaves landing).
struct LabChamberView: View {
    @Binding var isPresented: Bool
    var onOpenScout: (() -> Void)? = nil
    var onOpenHelix: (() -> Void)? = nil

    private let floatingIcons: [(title: String, system: String, action: String)] = [
        ("Scout", "paperplane.circle.fill", "scout"),
        ("Scout .01", "hare.fill", "baby"),
        ("Helix", "circle.hexagongrid.fill", "helix"),
        ("Manual", "book.closed.fill", "manual"),
        ("Status", "antenna.radiowaves.left.and.right", "status"),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                landingBackdrop
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    floatingIconBar(geo: geo)
                        // MAGNET UNDER BAR — floating icons sit below sticky ЯBAR
                        .padding(.top, RedwoodYabarMetrics.contentTopClearance)
                        .padding(.horizontal, 16)
                    Spacer()
                }

                // Desk tablet → LAB MANUAL PDF
                Button {
                    _ = LabManualDesk.openPDF()
                } label: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.cyan.opacity(0.01))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                        )
                        .overlay(
                            VStack {
                                Spacer()
                                Text("LAB MANUAL")
                                    .font(ClayTheme.clayFont(size: 9, weight: .bold))
                                    .foregroundStyle(Color.cyan.opacity(0.85))
                                    .padding(.bottom, 6)
                            }
                        )
                }
                .buttonStyle(.plain)
                .frame(width: max(70, geo.size.width * 0.13), height: max(88, geo.size.height * 0.16))
                .position(x: geo.size.width * 0.62, y: geo.size.height * 0.58)
                .accessibilityLabel("Open Lab Manual PDF")

                // Desk BotBaby sphere
                Button {
                    _ = NeoBabyScout.handle("bStatus")
                } label: {
                    Circle()
                        .fill(Color.cyan.opacity(0.01))
                        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(width: max(56, geo.size.width * 0.09), height: max(56, geo.size.width * 0.09))
                .position(x: geo.size.width * 0.42, y: geo.size.height * 0.56)
                .accessibilityLabel("Scout .01 on desk")

            }
            .onAppear { _ = NeoBabyScout.leaveInRoomToday() }
        }
    }

    private func floatingIconBar(geo: GeometryProxy) -> some View {
        HStack(spacing: max(10, geo.size.width * 0.025)) {
            ForEach(Array(floatingIcons.enumerated()), id: \.offset) { _, item in
                floatingIcon(title: item.title, system: item.system) {
                    runFloating(item.action)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func floatingIcon(title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.cyan.opacity(0.35),
                                    Color.black.opacity(0.85)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 28
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.cyan.opacity(0.55), radius: 10, y: 4)
                        .shadow(color: Color.black.opacity(0.7), radius: 8, y: 6)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), Color.cyan.opacity(0.2), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: system)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color.white, Color.cyan], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                }
                Text(title)
                    .font(ClayTheme.clayFont(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func runFloating(_ action: String) {
        switch action {
        case "scout": onOpenScout?()
        case "baby": _ = NeoBabyScout.handle("bStatus") ?? NeoBabyScout.introduce()
        case "helix": onOpenHelix?()
        case "manual": _ = LabManualDesk.openPDF()
        case "status": _ = NeoBabyScout.handle("bPing")
        default: break
        }
    }

    private var landingBackdrop: some View {
        Group {
            if let img = chamberImage() {
                img.resizable().scaledToFill()
            } else {
                Color.black
            }
        }
    }

    private func chamberImage() -> Image? {
        let prefer = [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/rooms/LAB-LANDING.jpg",
            "/Users/rizal/Documents/ЯBOT/lab/rooms/LAB-LANDING.jpg",
            NSHomeDirectory() + "/Documents/ЯBOT/hot-assets/LabLanding.png",
            NSHomeDirectory() + "/Documents/ЯBOT/lab/rooms/LAB-OF-CREATIONS.jpg",
            "/Users/rizal/Documents/ЯBOT/lab/rooms/LAB-OF-CREATIONS.jpg",
            NSHomeDirectory() + "/Documents/ЯBOT/hot-assets/LabOfCreations.png",
        ]
        for p in prefer {
            #if canImport(AppKit)
            if let ns = NSImage(contentsOfFile: p) { return Image(nsImage: ns) }
            #endif
            #if canImport(UIKit)
            if let ui = UIImage(contentsOfFile: p) { return Image(uiImage: ui) }
            #endif
        }
        for name in ["LabLanding", LabChamberPaths.bundleAsset, "LabChamber"] {
            if ClayImage.exists(name) {
                #if canImport(AppKit)
                if let ns = ClayImage.nsImage(named: name) { return Image(nsImage: ns) }
                #endif
                #if canImport(UIKit)
                if let ui = ClayImage.uiImage(named: name) { return Image(uiImage: ui) }
                #endif
            }
        }
        return nil
    }
}
