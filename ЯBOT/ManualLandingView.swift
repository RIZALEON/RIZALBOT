import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// All-black tableta landing: ЯMANUAL / USER GIVEЯ MANUAL cover.
/// HARDCODE 2026-09-23: ЯMANUAL is the ONE fixed editable/openable manual in-app.
/// Top mascot (house) → dismiss to chat. Bottom mascot (arrow) → offline PDF export.
struct ManualLandingView: View {
    @Binding var isPresented: Bool
    @State private var exportNote: String? = nil
    #if canImport(UIKit)
    @State private var sharePDFURL: URL? = nil
    #endif

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Group {
                        if ClayImage.exists("ManualCover") {
                            Image("ManualCover")
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                        } else {
                            Color.black
                        }
                    }
                    .frame(maxWidth: size.width * 0.92, maxHeight: size.height * 0.92)
                    .frame(width: size.width, height: size.height)

                    // Percentage hotspots over cover mascots (scale with window)
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: size.height * 0.20)
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: size.height * 0.15)
                            .frame(maxWidth: size.width * 0.50)
                            .onTapGesture { isPresented = false }
                            .help("Return to chat")
                            .accessibilityLabel("Return to chat")
                        Spacer(minLength: 0)
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(height: size.height * 0.25)
                            .frame(maxWidth: size.width * 0.50)
                            .onTapGesture { exportManual() }
                            .help("Download ЯMANUAL")
                            .accessibilityLabel("Download ЯMANUAL")
                        Color.clear
                            .frame(height: size.height * 0.05)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }

            if let exportNote {
                VStack {
                    Spacer()
                    Text(exportNote)
                        .font(ClayTheme.clayFont(size: 12, weight: .bold))
                        .foregroundStyle(ClayTheme.offWhite)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(ClayTheme.charcoalDeep.opacity(0.92)))
                        .padding(.bottom, 28)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .modifier(FocusEffectOff())
        #if canImport(UIKit)
        .sheet(isPresented: Binding(
            get: { sharePDFURL != nil },
            set: { if !$0 { sharePDFURL = nil } }
        )) {
            if let sharePDFURL {
                YaActivityView(items: [sharePDFURL])
            }
        }
        #endif
    }

    private func exportManual() {
        guard let src = ManualPDFLocator.resolveSeatedPDF() else {
            exportNote = "YAMANUAL.pdf not seated in MACHINE MIND"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { exportNote = nil }
            return
        }
        ManualPDFLocator.seedMachineMind(from: src)

        #if canImport(AppKit)
        // MERGE 0.3.0 (Documents hunk): prefer open/view of the one fixed manual; export stays below.
        if NSWorkspace.shared.open(src) {
            exportNote = "Opened ЯMANUAL"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exportNote = nil }
            return
        }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let downloads {
            let dest = downloads.appendingPathComponent("YAMANUAL.pdf")
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: src, to: dest)
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                exportNote = "Saved to Downloads"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exportNote = nil }
                return
            } catch {
                // Sandbox may block Downloads — fall through to NSSavePanel
            }
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "YAMANUAL.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.title = "Export ЯMANUAL"
        panel.message = "Offline export from MACHINE MIND"
        if let downloads {
            panel.directoryURL = downloads
        }
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: src, to: dest)
                NSWorkspace.shared.activateFileViewerSelecting([dest])
                exportNote = "Exported"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exportNote = nil }
            } catch {
                exportNote = "Export failed"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { exportNote = nil }
            }
        }
        #else
        #if canImport(UIKit)
        do {
            let fm = FileManager.default
            let destDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? fm.temporaryDirectory
            let dest = destDir.appendingPathComponent("YAMANUAL.pdf")
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: src, to: dest)
            sharePDFURL = dest
            exportNote = "Download · pick Save to Files or share"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exportNote = nil }
        } catch {
            exportNote = "Export failed"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { exportNote = nil }
        }
        #else
        exportNote = "Manual seated · open from Files"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exportNote = nil }
        #endif
        #endif
    }
}

private struct FocusEffectOff: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

/// Offline PDF seats: Bundle → Application Support MACHINE MIND → Documents/ЯBOT sibling.
enum ManualPDFLocator {
    /// HARDCODE 2026-09-23: one fixed app manual = ЯMANUAL (leaves stay contracts/sources).
    static let fileName = "YAMANUAL.pdf"
    static let displayName = "ЯMANUAL"
    static let mindFolderName = "MACHINE MIND"
    /// Bundle resource base names tried in order (first hit wins).
    static let bundleBases = ["YAMANUAL", "YAMANUAL-0.1"]

    static func machineMindDirectory() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support
            .appendingPathComponent("ЯBOT", isDirectory: true)
            .appendingPathComponent(mindFolderName, isDirectory: true)
    }

    static func resolveSeatedPDF() -> URL? {
        let fm = FileManager.default

        for base in bundleBases {
            if let bundleURL = Bundle.main.url(forResource: base, withExtension: "pdf"),
               fm.fileExists(atPath: bundleURL.path) {
                return bundleURL
            }
        }

        if let mind = machineMindDirectory() {
            for name in [fileName, "YAMANUAL-0.1.pdf"] {
                let mindPDF = mind.appendingPathComponent(name)
                if fm.fileExists(atPath: mindPDF.path) {
                    return mindPDF
                }
            }
        }

        let home = URL(fileURLWithPath: NSHomeDirectory())
        var seatCandidates: [URL] = [
            home.appendingPathComponent("Documents/ЯBOT/mind/books/YAMANUAL-0.1.pdf"),
            home.appendingPathComponent("Documents/ЯBOT/mind/books/YAMANUAL.pdf"),
            home.appendingPathComponent("Documents/ЯBOT/YAMANUAL-0.1.pdf"),
            home.appendingPathComponent("Documents/ЯBOT/YAMANUAL.pdf"),
            URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/mind/books/YAMANUAL-0.1.pdf"),
            URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/mind/books/YAMANUAL.pdf"),
            URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/YAMANUAL.pdf"),
        ]
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            seatCandidates.append(docs.appendingPathComponent("ЯBOT/mind/books/YAMANUAL-0.1.pdf"))
            seatCandidates.append(docs.appendingPathComponent("ЯBOT/mind/books/YAMANUAL.pdf"))
            seatCandidates.append(docs.appendingPathComponent("YAMANUAL.pdf"))
        }
        for url in seatCandidates where fm.fileExists(atPath: url.path) {
            // MERGE 0.3.0 (Documents hunk): a Documents hit means Files & Folders is granted.
            if url.path.contains("/Documents/") { MindTreeRoot.markDocumentsAccessGranted() }
            return url
        }
        return nil
    }

    /// Documents-tree name for the same opener (Bolte face → ЯMANUAL). MERGE 0.3.0.
    @discardableResult
    static func openSeatedPDF() -> Bool { openFixedManual() }

    /// Open the one fixed manual (macOS Preview / iOS share-ready URL).
    @discardableResult
    static func openFixedManual() -> Bool {
        guard let src = resolveSeatedPDF() else { return false }
        seedMachineMind(from: src)
        #if canImport(AppKit)
        return NSWorkspace.shared.open(src)
        #else
        return true
        #endif
    }

    @discardableResult
    static func seedMachineMind(from source: URL) -> URL? {
        guard let mind = machineMindDirectory() else { return nil }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: mind, withIntermediateDirectories: true)
            let dest = mind.appendingPathComponent(fileName)
            if fm.fileExists(atPath: dest.path) {
                let srcDate = (try? fm.attributesOfItem(atPath: source.path)[.modificationDate] as? Date) ?? .distantPast
                let dstDate = (try? fm.attributesOfItem(atPath: dest.path)[.modificationDate] as? Date) ?? .distantPast
                if srcDate > dstDate {
                    try fm.removeItem(at: dest)
                    try fm.copyItem(at: source, to: dest)
                }
            } else {
                try fm.copyItem(at: source, to: dest)
            }
            return dest
        } catch {
            return nil
        }
    }
}
