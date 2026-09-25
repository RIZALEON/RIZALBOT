import SwiftUI

/// Top chrome: MUST-EXIST Redwood ЯBAR with freeform clay icons ON the lumber FACE.
/// FACE-CONTAIN HARDCODE: no icon/button may sit off of or outside the face of the bar.
/// Layout rule: ZStack — lumber + three magnetic clusters share the SAME barHeight frame;
///   LEFT  = Bolte · Lab · Garage · Search   (icons ONLY — search field is NOT in this HStack)
///   CENTER = Home (ghost-heart) — NEVER translates when search opens
///   RIGHT = Vault · ClayFace · Online/Offline · Mind — NEVER pushed by left/search growth
/// Search field magnetizes TO the glass as an OVERLAY (zero layout width claim).
/// Dual-seat: shared by macOS + iOS (metrics via RedwoodYabarMetrics.current).
/// Whole-app magnetism doctrine: pieces snap/hold; no free-float shove.
struct YaResizableToolbar: View {
    @Binding var isOnline: Bool
    var showSearch: Bool
    var onBolte: () -> Void
    var onLab: () -> Void
    var onGarage: () -> Void
    var onSearch: () -> Void
    var onHome: () -> Void
    var onVault: () -> Void
    var onClayFace: () -> Void
    var onModeToggle: () -> Void
    var onMind: () -> Void
    var searchAccessory: AnyView? = nil

    private var m: RedwoodYabarMetrics.Spec { RedwoodYabarMetrics.current }
    private var iconS: CGFloat { RedwoodYabarMetrics.clampedIconSize(m.iconSize, metrics: m) }

    /// Sticky chrome height ONLY — never grows with Mind / search / landings.
    private var chromeHeight: CGFloat { m.topPadding + m.barHeight }

    var body: some View {
        GeometryReader { geo in
            let availW = max(geo.size.width, 1)
            let barW = max(availW - m.horizontalInset * 2, 120)
            let hPad = max(m.faceInset + 4, 8)
            // Left cluster width (4 icons + gaps + leading pad) — search overlays AFTER this.
            let leftClusterW = hPad + iconS * 4 + m.iconSpacing * 3
            // Hard stop before center Home face (gap 8pt).
            let centerGuard = barW * 0.5 - iconS * 0.5 - 8
            let searchMaxW = max(min(centerGuard - leftClusterW, 280), 72)

            ZStack(alignment: .center) {
                RedwoodYabarShelf(width: barW, metrics: m)
                    .zIndex(0)

                // CENTER magnet — geometric center; never in an HStack with search
                faceIcon("BtnHome", "house.fill", "Home — ghost heart", onHome)
                    .zIndex(5)

                // LEFT magnet — Bolte · Lab · Garage · Search icons ONLY (no accessory in-flow)
                HStack(alignment: .center, spacing: m.iconSpacing) {
                    faceIcon("Bolte", "bolt.heart.fill", "Clay landing — USER MANUAL", onBolte)
                    faceIcon("LabIcon", "flask.fill", "Lab Scout — Mission 1", onLab)
                    faceIcon("BtnGarage", "wrench.and.screwdriver.fill", "Garage — bot creation workshop", onGarage)
                    faceIcon("BtnSearch", "magnifyingglass", "Search chat", onSearch)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, hPad)
                .frame(width: barW, height: m.barHeight, alignment: .leading)
                .zIndex(1)

                // RIGHT magnet — Vault · ClayFace · Online/Offline · Mind (independent; search cannot shove)
                HStack(alignment: .center, spacing: m.iconSpacing) {
                    Spacer(minLength: 0)
                    faceIcon("BtnWallet", "creditcard.fill", "Я wallet — vault", onVault)
                    faceIcon("BtnClayFace", "face.smiling.inverse", "Я Game — TeraformЯ door", onClayFace)
                    ClayModeButton(isOnline: $isOnline, width: iconS, height: iconS, onToggle: onModeToggle)
                        .frame(width: iconS, height: iconS)
                        .clipped()
                    faceIcon("BtnMind", "brain.head.profile", "Clay landing — MACHINE MIND", onMind)
                }
                .padding(.horizontal, hPad)
                .frame(width: barW, height: m.barHeight, alignment: .trailing)
                .zIndex(1)

                // SEARCH glass overlay — magnetized after left icons; ZERO layout claim on magnets.
                // Caps before center Home so Home + right cluster never translate.
                if showSearch, let accessory = searchAccessory {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: leftClusterW)
                        accessory
                            .frame(width: searchMaxW, height: min(iconS + 4, m.barHeight - 4), alignment: .leading)
                            .clipped()
                        Spacer(minLength: 0)
                    }
                    .frame(width: barW, height: m.barHeight, alignment: .leading)
                    .zIndex(4)
                    .transition(.opacity)
                    .accessibilityLabel("Search field magnetized to ЯBAR glass")
                }
            }
            .frame(width: barW, height: m.barHeight)
            .compositingGroup()
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: m.barHeight * 0.28, style: .continuous))
            .padding(.top, m.topPadding)
            .padding(.horizontal, m.horizontalInset)
            .frame(width: availW, height: chromeHeight, alignment: .top)
            .accessibilityLabel("Redwood ЯBAR — search overlays glass; Home stays center; right cluster stays right")
        }
        .frame(maxWidth: .infinity)
        .frame(height: chromeHeight) // SIZE LOCK — identical with/without search or Mind
        .background(Color.clear)
        .accessibilityLabel(RedwoodYabarMetrics.faceContainLaw)
    }

    @ViewBuilder
    private func faceIcon(_ asset: String, _ fallback: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        ClayButton(asset: asset, systemFallback: fallback,
                   width: iconS, height: iconS,
                   help: help, action: action)
            .frame(width: iconS, height: iconS)
            .clipped()
    }
}
