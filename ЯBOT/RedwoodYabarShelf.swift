import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// REDWOOD CLAYMATION LUMBER WISE OS ЯBAR — MUST-EXIST vector shelf.
/// FACE-CONTAIN HARDCODE (Decider): no icon or button may sit off of or outside the face of the bar.
/// The bar is OS-smart: height / width / depth / icon size adjust so every control stays inside the lumber face.
enum RedwoodYabarMetrics {
    struct Spec: Equatable {
        var barHeight: CGFloat
        var barDepthHint: CGFloat
        /// Icon size is ALWAYS <= barHeight - 2*faceInset (clamped into the face).
        var iconSize: CGFloat
        /// Vertical inset from bar edge to icon edge (keeps clay inside the face).
        var faceInset: CGFloat
        var horizontalInset: CGFloat
        var topPadding: CGFloat
        var iconSpacing: CGFloat
    }

    /// OS-smart sizing in ONE place. Bar grows/shrinks with OS; icons clamp to face.
    /// Dual-seat: same Spec shape for macOS + iOS (numbers differ by seat only).
    static var current: Spec {
        #if os(macOS)
        let barH: CGFloat = 44
        let inset: CGFloat = 4
        return Spec(barHeight: barH, barDepthHint: 10,
                    iconSize: barH - inset * 2,
                    faceInset: inset,
                    horizontalInset: 16, topPadding: 8, iconSpacing: 8)
        #elseif os(iOS)
        let barH: CGFloat = 40
        let inset: CGFloat = 4
        return Spec(barHeight: barH, barDepthHint: 8,
                    iconSize: barH - inset * 2,
                    faceInset: inset,
                    horizontalInset: 10, topPadding: 6, iconSpacing: 6)
        #else
        let barH: CGFloat = 40
        let inset: CGFloat = 4
        return Spec(barHeight: barH, barDepthHint: 8,
                    iconSize: barH - inset * 2,
                    faceInset: inset,
                    horizontalInset: 10, topPadding: 6, iconSpacing: 6)
        #endif
    }

    static let assetName = "YabarLumberShelf"
    static let lawName = "REDWOOD CLAYMATION LUMBER WISE OS ЯBAR"
    static let aka = "Redwood ЯBAR"
    static let faceContainLaw = "FACE-CONTAIN: no icon/button outside lumber face"

    /// Exact top icon order ON the lumber (freeform, no plates) — all inside face.
    /// Bolte · Lab · Garage · Search · Home/ghost-heart (CENTER) · Vault · ClayFace · Online/Offline · Mind
    static let iconOrder: [String] = [
        "Bolte", "LabIcon", "BtnGarage", "BtnSearch", "BtnHome", "BtnWallet", "BtnClayFace", "BtnOnline", "BtnMind"
    ]

    /// Clamp any proposed icon size into the bar face.
    static func clampedIconSize(_ proposed: CGFloat, metrics: Spec = current) -> CGFloat {
        let maxFace = max(metrics.barHeight - metrics.faceInset * 2, 12)
        return min(max(proposed, 12), maxFace)
    }

    /// MAGNET UNDER BAR: landing tablets + chat seat sit BELOW the sticky ЯBAR.
    /// Never overlap the lumber face. Auto-adjusts with OS-smart barHeight/topPadding.
    /// SIZE LOCK: Mind / landings must use this clearance — they must NEVER grow barHeight.
    static var contentTopClearance: CGFloat {
        let m = current
        return m.topPadding + m.barHeight + 16
    }

    /// Fixed sticky chrome strip height (topPadding + barHeight). Toolbar outer frame uses this.
    static var chromeStripHeight: CGFloat {
        let m = current
        return m.topPadding + m.barHeight
    }
}

/// Background lumber layer — ALWAYS rendered. Clear glass dock; no plate behind icons.
struct RedwoodYabarShelf: View {
    var width: CGFloat
    var metrics: RedwoodYabarMetrics.Spec = RedwoodYabarMetrics.current

    var body: some View {
        // Continuous solid beam: opaque redwood ALWAYS under lumber art.
        // YabarLumberShelf.png has heavy center/right alpha — without underlay the
        // black clay background shows through around Home (transparent middle gap).
        ZStack {
            // Triple opaque stack — YabarLumberShelf mean alpha ~73; never let clay wall bleed.
            Color(red: 0.30, green: 0.09, blue: 0.06)
            proceduralRedwood
            if hasAsset {
                Image(RedwoodYabarMetrics.assetName)
                    .resizable()
                    .interpolation(.high)
                    // Stretch beam to FULL bar width/height — no aspectFit/center hole
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: max(width, 1), height: metrics.barHeight)
        .compositingGroup() // flatten to solid redwood face
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: metrics.barHeight * 0.28, style: .continuous))
        .shadow(color: Color.black.opacity(0.45), radius: metrics.barDepthHint * 0.45, y: metrics.barDepthHint * 0.35)
        .accessibilityLabel(RedwoodYabarMetrics.aka)
        .accessibilityAddTraits(.isImage)
    }

    private var hasAsset: Bool {
        #if canImport(AppKit)
        return NSImage(named: RedwoodYabarMetrics.assetName) != nil
        #elseif canImport(UIKit)
        return UIImage(named: RedwoodYabarMetrics.assetName) != nil
        #else
        return false
        #endif
    }

    private var proceduralRedwood: some View {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.14, blue: 0.10),
                Color(red: 0.28, green: 0.08, blue: 0.06),
                Color(red: 0.48, green: 0.18, blue: 0.12),
                Color(red: 0.22, green: 0.06, blue: 0.04)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
