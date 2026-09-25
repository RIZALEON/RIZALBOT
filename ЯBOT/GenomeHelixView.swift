import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// 3D genome helix light model inspector — GENOME-HOLOGRAM-680 locus detail.
/// Open from SCOUT reply / Lab launch bay / yabot://lab/helix
struct GenomeHelixView: View {
    @Binding var isPresented: Bool
    var siteMatches: [LabReturnReport.SiteMatch] = LabReturnReport.americasSiteMatches

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("3D genome helix · light loci")
                        .font(ClayTheme.clayFont(size: 16, weight: .bold))
                        .foregroundStyle(ClayTheme.offWhite)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                Text(LabScoutCommand.missionDeltaClearLine)
                    .font(ClayTheme.clayFont(size: 12, weight: .bold))
                    .foregroundStyle(Color.cyan)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))

                helixVisual

                Text("Site matches · tap row for label (match · c2 · c1)")
                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.7))

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(siteMatches) { m in
                            HStack {
                                Circle()
                                    .fill(pinColor(for: m))
                                    .frame(width: 10, height: 10)
                                Text(m.id)
                                    .font(ClayTheme.clayFont(size: 12, weight: .bold))
                                    .foregroundStyle(ClayTheme.offWhite)
                                Spacer()
                                Text(m.shortLabel)
                                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                                    .foregroundStyle(Color.orange.opacity(0.95))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                        }
                    }
                }

                Text("Asset \(LabScoutCommand.helixAssetName) · GRCh37 · MagnetizedContrast exact letter only")
                    .font(ClayTheme.clayFont(size: 10, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.55))
            }
            .padding(20)
        }
    }

    private var helixVisual: some View {
        ZStack {
            // Fallback procedural helix if PNG missing
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let midX = size.width / 2
                    let midY = size.height / 2
                    for i in 0..<48 {
                        let phase = Double(i) / 48.0 * .pi * 4 + t * 0.6
                        let y = midY - size.height * 0.38 + CGFloat(i) / 48.0 * size.height * 0.76
                        let x1 = midX + CGFloat(cos(phase)) * size.width * 0.22
                        let x2 = midX + CGFloat(cos(phase + .pi)) * size.width * 0.22
                        var path = Path()
                        path.move(to: CGPoint(x: x1, y: y))
                        path.addLine(to: CGPoint(x: x2, y: y))
                        context.stroke(path, with: .color(.cyan.opacity(0.35)), lineWidth: 1.2)
                        context.fill(Path(ellipseIn: CGRect(x: x1 - 3, y: y - 3, width: 6, height: 6)), with: .color(.orange.opacity(0.85)))
                        context.fill(Path(ellipseIn: CGRect(x: x2 - 3, y: y - 3, width: 6, height: 6)), with: .color(.green.opacity(0.75)))
                    }
                }
            }
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.05, green: 0.08, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
            )

            // Prefer seated hologram PNG when present
            if let img = helixImage() {
                img
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(0.92)
            }
        }
    }

    private func helixImage() -> Image? {
        let paths = [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/GENOME-HOLOGRAM-680.png",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/GENOME-HOLOGRAM-680.png",
        ]
        for p in paths {
            #if canImport(AppKit)
            if let ns = NSImage(contentsOfFile: p) {
                return Image(nsImage: ns)
            }
            #elseif canImport(UIKit)
            if let ui = UIImage(contentsOfFile: p) {
                return Image(uiImage: ui)
            }
            #endif
        }
        if let url = Bundle.main.url(forResource: "GENOME-HOLOGRAM-680", withExtension: "png") {
            #if canImport(AppKit)
            if let ns = NSImage(contentsOf: url) {
                return Image(nsImage: ns)
            }
            #elseif canImport(UIKit)
            if let ui = UIImage(contentsOfFile: url.path) {
                return Image(uiImage: ui)
            }
            #endif
        }
        return nil
    }

    private func pinColor(for m: LabReturnReport.SiteMatch) -> Color {
        if m.id.hasPrefix("USR") { return .cyan }
        if m.matchesExact >= 30 { return .orange }
        return .green
    }
}
