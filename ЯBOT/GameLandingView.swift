import SwiftUI
import WebKit
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Я Game door — BtnClayFace opens this UNDER sticky Redwood ЯBAR.
/// Prefer local landing file when present; else online https://rizal.info/game/ (http fallback).
/// Decider owns the real landing page. NonNuclear: door only — no spend / auto-rewards / mint.
/// 0.3.0 game menu: Play (this landing) · GAME BUILDERS WORKSHOP (yabot://game/workshop).
struct GameLandingView: View {
    @Binding var isPresented: Bool
    var isOnline: Bool = false
    /// Game menu section: false = Play · true = GAME BUILDERS WORKSHOP.
    @Binding var showWorkshop: Bool

    @State private var sourceNote: String = "resolving…"
    @State private var loadURL: URL? = nil
    @State private var reloadToken: Int = 0

    var body: some View {
        ZStack {
            if showWorkshop {
                GameWorkshopView(isPresented: $isPresented, showWorkshop: $showWorkshop)
                    .transition(.opacity)
            } else {
                playSection
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showWorkshop)
    }

    /// Game menu chips (clay capsules, no plates).
    private var gameMenu: some View {
        HStack(spacing: 10) {
            GameMenuChip(title: "Play", active: !showWorkshop) { showWorkshop = false }
            GameMenuChip(title: "GAME BUILDERS WORKSHOP", active: showWorkshop) { showWorkshop = true }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private var playSection: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if ClayImage.exists("BtnClayFace") {
                        Image("BtnClayFace")
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "face.smiling.inverse")
                            .font(.system(size: 22))
                            .foregroundStyle(ClayTheme.offWhite)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Я Game")
                            .font(ClayTheme.clayFont(size: 20, weight: .bold))
                            .foregroundStyle(ClayTheme.offWhite)
                        Text(sourceNote)
                            .font(ClayTheme.clayFont(size: 11, weight: .medium))
                            .foregroundStyle(ClayTheme.offWhite.opacity(0.75))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Text(isOnline ? "ONLINE" : "OFFLINE")
                        .font(ClayTheme.clayFont(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isOnline ? Color.green.opacity(0.35) : Color.gray.opacity(0.35)))
                        .foregroundStyle(ClayTheme.offWhite)
                }
                .padding(.horizontal, 18)
                .padding(.top, RedwoodYabarMetrics.contentTopClearance)

                gameMenu

                GameWebDoor(url: loadURL, reloadToken: reloadToken)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.28), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)

                HStack(spacing: 12) {
                    ClayButton(asset: "BtnSearch", systemFallback: "arrow.clockwise",
                               width: 32, height: 32, help: "Retry resolve local / online") {
                        resolveSource(preferOnlineRetry: true)
                        reloadToken += 1
                    }
                    if isOnline {
                        ClayButton(asset: "BtnOnline", systemFallback: "safari",
                                   width: 32, height: 32, help: "Open rizal.info/game in browser") {
                            openExternal(Self.httpsURL)
                        }
                    }
                    Spacer()
                    ClayButton(asset: "BtnHomeHouse", systemFallback: "house.fill",
                               width: 48, height: 48, help: "Home — leave game door") {
                        withAnimation(.easeInOut(duration: 0.18)) { isPresented = false }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { resolveSource(preferOnlineRetry: false) }
        .onChange(of: isOnline) { _ in resolveSource(preferOnlineRetry: false); reloadToken += 1 }
    }

    static let httpsURL = URL(string: "https://rizal.info/game/")!
    static let httpURL = URL(string: "http://rizal.info/game/")!

    /// Drop Decider landing here (first hit wins).
    static var localCandidates: [URL] {
        var urls: [URL] = []
        let fm = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let docs = home.appendingPathComponent("Documents/ЯBOT/game/index.html", isDirectory: false)
        urls.append(docs)
        urls.append(home.appendingPathComponent("Documents/ЯBOT/ЯBOT/game/index.html", isDirectory: false))
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(support.appendingPathComponent("ЯBOT/game/index.html", isDirectory: false))
        }
        if let bundle = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "game") {
            urls.append(bundle)
        }
        // Same-folder resource (synchronized game/ under target)
        if let res = Bundle.main.resourceURL?.appendingPathComponent("game/index.html") {
            urls.append(res)
        }
        // 0.3.0 fix: Xcode's synchronized root copies ЯBOT/game/index.html FLAT into Resources/,
        // so the bundled page sits at the resource root. Look there last (Decider copies win).
        if let flat = Bundle.main.url(forResource: "index", withExtension: "html") {
            urls.append(flat)
        }
        return urls
    }

    private func resolveSource(preferOnlineRetry: Bool) {
        let fm = FileManager.default
        if !preferOnlineRetry || !isOnline {
            for u in Self.localCandidates {
                if fm.fileExists(atPath: u.path) {
                    loadURL = u
                    sourceNote = "local · \(u.path)"
                    return
                }
            }
        }
        if isOnline {
            loadURL = Self.httpsURL
            sourceNote = "online · https://rizal.info/game/ (http fallback in browser)"
            return
        }
        // Embedded minimal stub so offline never blanks
        let stub = Self.embeddedStubHTML
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("yabot-game-stub.html")
        try? stub.write(to: tmp, atomically: true, encoding: .utf8)
        loadURL = tmp
        sourceNote = "embedded stub — drop Decider page at Documents/ЯBOT/game/index.html"
    }

    private func openExternal(_ url: URL) {
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #elseif canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private static let embeddedStubHTML = """
    <!DOCTYPE html><html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
    <title>Я Game stub</title>
    <style>body{margin:0;background:#140e0a;color:#efe6d6;font:16px/1.4 system-ui,sans-serif;padding:24px}</style></head>
    <body><h1>Я Game · temporary stub</h1>
    <p>Decider owns the landing. Drop <code>Documents/ЯBOT/game/index.html</code> (or bundled <code>game/index.html</code>).</p>
    <p>Online: https://rizal.info/game/ · deep link yabot://game</p>
    <p>NonNuclear door only. Crown Я. Mint ref BB9uA5BuacDnWyDf5Npc9nMb9yFbyThsNrQPBYJ5Q1Lv</p>
    </body></html>
    """
}

/// Clay capsule chip for the game menu / workshop — tap only (no Button plate).
struct GameMenuChip: View {
    let title: String
    var active: Bool = false
    var tint: Color = .orange
    var action: () -> Void

    var body: some View {
        Text(title)
            .font(ClayTheme.clayFont(size: 12, weight: .bold))
            .foregroundStyle(ClayTheme.offWhite.opacity(active ? 1 : 0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? tint.opacity(0.45) : Color.black.opacity(0.55))
                    .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(active ? 0.8 : 0.35), lineWidth: 1))
            )
            .contentShape(Capsule())
            .onTapGesture { action() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(title)
    }
}

#if os(macOS)
private struct GameWebDoor: NSViewRepresentable {
    let url: URL?
    let reloadToken: Int

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.setValue(false, forKey: "drawsBackground")
        return v
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        guard let url else { return }
        if url.isFileURL {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        }
    }
}
#else
private struct GameWebDoor: UIViewRepresentable {
    let url: URL?
    let reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard let url else { return }
        if url.isFileURL {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        }
    }
}
#endif
