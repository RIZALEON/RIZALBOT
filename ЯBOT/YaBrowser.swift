import SwiftUI
import WebKit
import Combine
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// ЯBROWSER (0.3.3) — private full browser bar under the Я Game menu.
/// PRIVATE: its own WKWebViewConfiguration with WKWebsiteDataStore.nonPersistent() (cookies/cache/storage live only
/// in memory and die with the view). NO native bridge: no WKScriptMessageHandler, no user scripts, nothing from
/// save / wallet / chain.propose is reachable from pages loaded here. Popups open in the same view.
/// Quick buttons: offline game/index.html · https://rizal.info/game/ · https://rizal.pw/classroom/.
enum YaBrowserLinks {
    static let game = URL(string: "https://rizal.info/game/")!
    static let classroom = URL(string: "https://rizal.pw/classroom/")!
    static let classroomFallback = URL(string: "https://rizaleon.github.io/rizal-pw/classroom/")!
    /// Home = offline game page when present, else rizal.info/game/.
    static var home: URL { offlineGame ?? game }
    static var offlineGame: URL? {
        GameLandingView.localCandidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Address-bar text → URL. Bare words become an https host if they look like one, else a DuckDuckGo search.
    static func resolve(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let u = URL(string: s), let sc = u.scheme?.lowercased(), ["http", "https", "file"].contains(sc) { return u }
        if !s.contains(" "), s.contains("."), let u = URL(string: "https://" + s) { return u }
        var c = URLComponents(string: "https://duckduckgo.com/")!
        c.queryItems = [URLQueryItem(name: "q", value: s)]
        return c.url
    }
}

final class YaBrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var address: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var loading = false
    @Published var note: String = "private · nothing saved · no bridge"
    let webView: WKWebView

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()          // PRIVATE: in-memory only
        cfg.userContentController = WKUserContentController() // empty: no message handlers, no scripts
        #if os(iOS)
        cfg.allowsInlineMediaPlayback = true
        #endif
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #endif
    }

    func open(_ url: URL) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25))
        }
        address = url.isFileURL ? url.path : url.absoluteString
    }
    func go() { if let u = YaBrowserLinks.resolve(address) { open(u) } }
    func back() { webView.goBack() }
    func forward() { webView.goForward() }
    func reload() { webView.reload() }
    func home() { open(YaBrowserLinks.home) }

    /// Drop everything (called on close; the nonPersistent store dies with the view anyway).
    func wipe() {
        webView.stopLoading()
        webView.configuration.websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                          modifiedSince: .distantPast) {}
        webView.loadHTMLString("", baseURL: nil)
    }

    private func sync() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let u = webView.url { address = u.isFileURL ? u.path : u.absoluteString }
    }
    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { loading = true; sync() }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { loading = false; note = "private · nothing saved · no bridge"; sync() }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { loading = false; note = e.localizedDescription; sync() }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) {
        loading = false; note = e.localizedDescription; sync()
    }
    /// Only web schemes navigate in-view (no yabot:// or other app-scheme hand-offs from pages).
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let sc = a.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(["http", "https", "file", "about", "data", "blob"].contains(sc) ? .allow : .cancel)
    }
    /// target=_blank / window.open → same view (no extra windows, no shared config).
    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
        if let u = a.request.url { w.load(URLRequest(url: u)) }
        return nil
    }
}

struct YaBrowserView: View {
    var isOnline: Bool
    @StateObject private var m = YaBrowserModel()

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                bar("chevron.left", "Back", enabled: m.canGoBack) { m.back() }
                bar("chevron.right", "Forward", enabled: m.canGoForward) { m.forward() }
                bar(m.loading ? "xmark" : "arrow.clockwise", "Reload") { m.loading ? m.webView.stopLoading() : m.reload() }
                bar("house", "Home") { m.home() }
                TextField("ЯBROWSER · address or search", text: $m.address)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .onSubmit { m.go() }
                bar("arrow.right.circle.fill", "Go") { m.go() }
            }
            HStack(spacing: 8) {
                GameMenuChip(title: "Offline game", active: false) {
                    if let u = YaBrowserLinks.offlineGame { m.open(u) } else { m.note = "no offline game/index.html seated" }
                }
                GameMenuChip(title: "rizal.info/game", active: false, tint: .cyan) { m.open(YaBrowserLinks.game) }
                GameMenuChip(title: "rizal.pw/classroom", active: false, tint: .cyan) { m.open(YaBrowserLinks.classroom) }
                Spacer(minLength: 0)
                Text(isOnline ? m.note : "OFFLINE · web links need ONLINE")
                    .font(ClayTheme.clayFont(size: 10, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.7))
                    .lineLimit(1)
            }
            YaBrowserWeb(webView: m.webView)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        }
        .onAppear { if m.webView.url == nil { isOnline ? m.open(YaBrowserLinks.game) : m.home() } }
        .onDisappear { m.wipe() }
    }

    private func bar(_ sys: String, _ help: String, enabled: Bool = true, _ act: @escaping () -> Void) -> some View {
        Image(systemName: sys)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ClayTheme.offWhite.opacity(enabled ? 1 : 0.35))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .onTapGesture { if enabled { act() } }
            .help(help)
            .accessibilityLabel(help)
            .accessibilityAddTraits(.isButton)
    }
}

#if os(macOS)
private struct YaBrowserWeb: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ v: WKWebView, context: Context) {}
}
#else
private struct YaBrowserWeb: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ v: WKWebView, context: Context) {}
}
#endif
