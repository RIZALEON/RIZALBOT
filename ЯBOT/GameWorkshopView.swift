import SwiftUI
import WebKit
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// GAME BUILDERS WORKSHOP — found in the Я Game menu (Play · GAME BUILDERS WORKSHOP), deep link yabot://game/workshop.
/// Room: white padded workshop (asset WorkshopRoom, Decider's image). Opens UNDER the sticky Redwood ЯBAR.
/// Sections: Projects · Drafts (bots propose) · Preview (sandboxed web view) · Respawn · Ledger.
/// Gamewrite authors: Я's bots by their Garage names (ЯBOT · ЯMAX today). Only the Decider applies (taps + confirm).
struct GameWorkshopView: View {
    @Binding var isPresented: Bool
    @Binding var showWorkshop: Bool

    enum Section: String, CaseIterable { case projects = "Projects", drafts = "Drafts", preview = "Preview", respawn = "Respawn", ledger = "Ledger" }

    @State private var section: Section = .drafts
    @State private var projects: [GameWorkshop.Project] = []
    @State private var drafts: [GameWorkshop.Draft] = []
    @State private var selectedProject: String = GameWorkshop.seedProjectId
    @State private var selectedDraft: String? = nil
    @State private var previewURL: URL? = nil
    @State private var previewAllow: URL? = nil
    @State private var previewText: String = ""
    @State private var previewTitle: String = "Nothing loaded"
    @State private var snapshots: [GameWorkshop.Snapshot] = []
    @State private var ledgerLines: [String] = []
    @State private var note: String = ""
    @State private var askText: String = ""
    @State private var askAuthorId: String = ""
    private var askAuthor: WorkshopAuthors.Author? {
        WorkshopAuthors.all.first { $0.id == askAuthorId } ?? WorkshopAuthors.defaultAuthor
    }
    @State private var working: Bool = false
    @State private var newProjectName: String = ""
    @State private var confirmApply: Bool = false
    @State private var confirmRespawn: GameWorkshop.Snapshot? = nil
    @State private var showRespawnConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sectionChips
            ZStack(alignment: .topLeading) {
                panelBackground
                sectionContent
                    .padding(14)
            }
            .padding(.horizontal, 16)
            if !note.isEmpty {
                Text(note)
                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite)
                    .lineLimit(4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.black.opacity(0.7)))
                    .padding(.horizontal, 18)
            }
            Spacer(minLength: 8)
        }
        .padding(.top, RedwoodYabarMetrics.contentTopClearance)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            ZStack {
                Color(white: 0.93)
                if ClayImage.exists("WorkshopRoom") {
                    Image("WorkshopRoom")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear { refresh() }
        .alert("Decider · Approve & Apply?", isPresented: $confirmApply) {
            Button("Approve & Apply") { applySelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(applyMessage)
        }
        .alert("Decider · Respawn project?", isPresented: $showRespawnConfirm) {
            Button("Respawn") { respawnConfirmed() }
            Button("Cancel", role: .cancel) { confirmRespawn = nil }
        } message: {
            Text("Roll \(selectedProject) back to \(confirmRespawn?.id ?? "?")? The current state is snapshotted first, so this is undoable too.")
        }
        .accessibilityLabel("GAME BUILDERS WORKSHOP")
    }

    // MARK: - Header / chips

    private var header: some View {
        HStack(spacing: 10) {
            GameMenuChip(title: "◀ Play", active: false) { showWorkshop = false }
            VStack(alignment: .leading, spacing: 2) {
                Text("Я / GAME BUILDERS WORKSHOP")
                    .font(ClayTheme.clayFont(size: 18, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text("gamewrite authors: \(WorkshopAuthors.namesLine()) — drafts only · Decider applies")
                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            GameMenuChip(title: "↻", active: false) { refresh() }
        }
        .padding(.horizontal, 18)
    }

    private var sectionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Section.allCases, id: \.self) { s in
                    GameMenuChip(title: chipTitle(s), active: section == s) {
                        section = s
                        refresh()
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func chipTitle(_ s: Section) -> String {
        if s == .drafts {
            let n = drafts.filter { $0.status == .proposed }.count
            return n > 0 ? "Drafts (\(n))" : "Drafts"
        }
        return s.rawValue
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.black.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.orange.opacity(0.5), Color.cyan.opacity(0.35), Color.clear],
                                                 startPoint: .leading, endPoint: .trailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .projects: projectsSection
        case .drafts: draftsSection
        case .preview: previewSection
        case .respawn: respawnSection
        case .ledger: ledgerSection
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("PROJECTS · \(GameWorkshop.projectsDir.path)")
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(projects) { p in projectRow(p) }
                }
            }
            HStack(spacing: 8) {
                TextField("new project name", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                GameMenuChip(title: "Create (Decider)", active: false) {
                    let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    note = GameWorkshop.createProject(named: name)
                    newProjectName = ""
                    refresh()
                }
            }
        }
    }

    private func projectRow(_ p: GameWorkshop.Project) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(ClayTheme.clayFont(size: 14, weight: .bold)).foregroundStyle(ClayTheme.offWhite)
                Text("\(p.id) · entry \(p.entry)").font(ClayTheme.clayFont(size: 10, weight: .medium)).foregroundStyle(ClayTheme.offWhite.opacity(0.6))
            }
            Spacer()
            GameMenuChip(title: selectedProject == p.id ? "Selected" : "Select", active: selectedProject == p.id) {
                selectedProject = p.id
                refresh()
            }
            GameMenuChip(title: "Play live", active: false, tint: .cyan) {
                previewURL = p.entryURL
                previewAllow = p.dir
                previewText = ""
                previewTitle = "LIVE · \(p.name)"
                section = .preview
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }

    // MARK: - Drafts

    private var draftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            askBar
            HStack(alignment: .top, spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        if drafts.isEmpty {
                            Text("No drafts yet. Ask a bot above, or in chat: gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs")
                                .font(ClayTheme.clayFont(size: 12, weight: .medium))
                                .foregroundStyle(ClayTheme.offWhite.opacity(0.7))
                        }
                        ForEach(drafts) { d in draftRow(d) }
                    }
                }
                .frame(minWidth: 220, maxWidth: 340)
                draftDetail
            }
        }
    }

    private var askBar: some View {
        HStack(spacing: 8) {
            WorkshopAuthorFace(author: askAuthor?.display ?? "", size: 28)
            GameMenuChip(title: askAuthor?.display ?? "no author", active: true, tint: askAuthor?.id == "yamax" ? .cyan : .orange) {
                let list = WorkshopAuthors.all
                guard !list.isEmpty else { return }
                if let i = list.firstIndex(where: { $0.id == askAuthor?.id }) {
                    askAuthorId = list[(i + 1) % list.count].id
                } else {
                    askAuthorId = list.first?.id ?? ""
                }
            }
            TextField("<language> <file> <purpose>  e.g. typescript src/scenes/Dig.ts mound grows where BLUEFACE digs", text: $askText)
                .textFieldStyle(.roundedBorder)
            GameMenuChip(title: working ? "Drafting…" : "Ask bot to draft", active: false) { askBot() }
        }
    }

    private func draftRow(_ d: GameWorkshop.Draft) -> some View {
        let sel = selectedDraft == d.id
        return HStack(alignment: .top, spacing: 8) {
          WorkshopAuthorFace(author: d.authorDisplay, size: 26)
          VStack(alignment: .leading, spacing: 2) {
            Text("\(d.language) · \(d.file)").font(ClayTheme.clayFont(size: 12, weight: .bold)).foregroundStyle(ClayTheme.offWhite)
            Text("by \(d.authorDisplay) · \(d.status.rawValue)\(d.needsRebuild ? " · needs rebuild" : "")")
                .font(ClayTheme.clayFont(size: 10, weight: .medium))
                .foregroundStyle(statusColor(d.status))
            Text(d.purpose).font(ClayTheme.clayFont(size: 10, weight: .regular)).foregroundStyle(ClayTheme.offWhite.opacity(0.65)).lineLimit(2)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(sel ? Color.orange.opacity(0.25) : Color.white.opacity(0.06)))
        .contentShape(Rectangle())
        .onTapGesture { selectedDraft = d.id }
    }

    private func statusColor(_ s: GameWorkshop.DraftStatus) -> Color {
        switch s {
        case .proposed: return Color.yellow.opacity(0.9)
        case .applied: return Color.green.opacity(0.9)
        case .rejected: return Color.red.opacity(0.8)
        }
    }

    private var currentDraft: GameWorkshop.Draft? {
        guard let id = selectedDraft else { return drafts.first }
        return drafts.first { $0.id == id }
    }

    @ViewBuilder
    private var draftDetail: some View {
        if let d = currentDraft {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(d.id) · \(d.project)/\(d.file)").font(ClayTheme.clayFont(size: 13, weight: .bold)).foregroundStyle(ClayTheme.offWhite)
                Text("purpose / intent: \(d.purpose)").font(ClayTheme.clayFont(size: 11, weight: .medium)).foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                HStack(spacing: 6) {
                    WorkshopAuthorFace(author: d.authorDisplay, size: 22)
                    Text("author: \(d.authorDisplay) · language: \(d.language) · source: \(d.source) · \(d.bytes) B · \(d.createdAt)")
                        .font(ClayTheme.clayFont(size: 10, weight: .medium)).foregroundStyle(ClayTheme.offWhite.opacity(0.6))
                }
                if !d.notes.isEmpty {
                    Text("notes: " + d.notes.joined(separator: " · ")).font(ClayTheme.clayFont(size: 10, weight: .medium)).foregroundStyle(Color.yellow.opacity(0.85))
                }
                if let snap = d.snapshot {
                    Text("applied \(d.appliedAt ?? "") · respawn point \(snap)").font(ClayTheme.clayFont(size: 10, weight: .medium)).foregroundStyle(Color.green.opacity(0.85))
                }
                ScrollView([.vertical, .horizontal]) {
                    Text(GameWorkshop.diffText(d))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45)))
                HStack(spacing: 8) {
                    GameMenuChip(title: "Preview", active: false, tint: .cyan) { preview(d) }
                    if d.status == .proposed {
                        GameMenuChip(title: "Approve & Apply (Decider)", active: true, tint: .green) {
                            selectedDraft = d.id
                            confirmApply = true
                        }
                        GameMenuChip(title: "Reject", active: false, tint: .red) {
                            note = GameWorkshop.reject(d.id)
                            refresh()
                        }
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            Text("Select a draft").foregroundStyle(ClayTheme.offWhite.opacity(0.6))
        }
    }

    private var applyMessage: String {
        guard let d = currentDraft else { return "" }
        return "Apply \(d.id) by \(d.authorDisplay) → \(d.project)/\(d.file)?\nPurpose: \(d.purpose)\nA respawn snapshot of \(d.project) is taken first."
    }

    // MARK: - Preview (sandbox)

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("PREVIEW · \(previewTitle) · sandbox: local files only, network blocked, no native bridge")
            if let url = previewURL {
                WorkshopSandboxWeb(url: url, allowRead: previewAllow ?? url.deletingLastPathComponent())
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if !previewText.isEmpty {
                ScrollView([.vertical, .horizontal]) {
                    Text(previewText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Pick a draft → Preview, or Projects → Play live.").foregroundStyle(ClayTheme.offWhite.opacity(0.6))
            }
        }
    }

    private func preview(_ d: GameWorkshop.Draft) {
        let file = GameWorkshop.contentURL(d)
        let dir = file.deletingLastPathComponent()
        previewTitle = "DRAFT \(d.id) · \(d.language) · by \(d.authorDisplay)"
        previewText = ""
        previewURL = nil
        switch d.language {
        case "html":
            previewURL = file
            previewAllow = dir
        case "javascript":
            let html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>JS draft</title></head><body style=\"background:#140e0a;color:#efe6d6;font:14px system-ui\"><pre id=\"log\"></pre><script>const L=document.getElementById('log');const o=console.log;console.log=(...a)=>{L.textContent+=a.join(' ')+'\\n';o(...a)};window.onerror=(m)=>{L.textContent+='error: '+m+'\\n'};</script><script src=\"\(file.lastPathComponent)\"></script></body></html>"
            let h = dir.appendingPathComponent("preview.html")
            try? html.write(to: h, atomically: true, encoding: .utf8)
            previewURL = h
            previewAllow = dir
        case "css":
            let html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><link rel=\"stylesheet\" href=\"\(file.lastPathComponent)\"></head><body><div id=\"game\"><canvas width=\"320\" height=\"180\" style=\"background:#413f40\"></canvas></div><h1>TeraformЯ</h1><p>CSS draft preview</p></body></html>"
            let h = dir.appendingPathComponent("preview.html")
            try? html.write(to: h, atomically: true, encoding: .utf8)
            previewURL = h
            previewAllow = dir
        default:
            previewText = GameWorkshop.content(d)
        }
        section = .preview
    }

    // MARK: - Respawn

    private var respawnSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("RESPAWN · \(selectedProject) · every apply snapshots first · \(GameWorkshop.respawnDir.path)")
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if snapshots.isEmpty {
                        Text("No snapshots for \(selectedProject) yet (the first Approve & Apply creates one).")
                            .font(ClayTheme.clayFont(size: 12, weight: .medium)).foregroundStyle(ClayTheme.offWhite.opacity(0.7))
                    }
                    ForEach(snapshots) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.id).font(.system(size: 12, design: .monospaced)).foregroundStyle(ClayTheme.offWhite)
                                Text(s.reason).font(ClayTheme.clayFont(size: 10, weight: .medium)).foregroundStyle(ClayTheme.offWhite.opacity(0.6))
                            }
                            Spacer()
                            GameMenuChip(title: "Roll back (Decider)", active: false, tint: .red) {
                                confirmRespawn = s
                                showRespawnConfirm = true
                            }
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                    }
                    Text(RespawnPoints.status())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.55))
                        .textSelection(.enabled)
                        .padding(.top, 10)
                }
            }
        }
    }

    private func respawnConfirmed() {
        guard let s = confirmRespawn else { return }
        note = GameWorkshop.respawn(project: selectedProject, to: s.id)
        confirmRespawn = nil
        refresh()
    }

    // MARK: - Ledger

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("EVOLUTION LEDGER · append-only · \(GameWorkshop.ledgerURL.path)")
            ScrollView([.vertical, .horizontal]) {
                Text(ledgerLines.isEmpty ? "(empty)" : ledgerLines.joined(separator: "\n"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Actions

    private func label(_ t: String) -> some View {
        Text(t)
            .font(ClayTheme.clayFont(size: 10, weight: .bold))
            .foregroundStyle(Color.orange.opacity(0.9))
            .lineLimit(2)
    }

    private func refresh() {
        _ = GameWorkshop.ensureSeated()
        projects = GameWorkshop.projects()
        drafts = GameWorkshop.drafts()
        if !projects.contains(where: { $0.id == selectedProject }), let first = projects.first { selectedProject = first.id }
        snapshots = GameWorkshop.snapshots(project: selectedProject)
        ledgerLines = GameWorkshop.ledgerTail(120)
    }

    private func askBot() {
        let t = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !working else { return }
        guard let author = askAuthor else {
            note = "No gamewrite author — set gamewrite ids in authors.json (names come from the Garage roster)."
            return
        }
        working = true
        let who = author.id
        let project = selectedProject
        note = "\(author.display) is drafting…"
        DispatchQueue.global(qos: .userInitiated).async {
            let reply = GameWrite.handle("gamewrite \(t) as \(who) in project \(project)")
            DispatchQueue.main.async {
                note = reply
                working = false
                askText = ""
                refresh()
                selectedDraft = drafts.first?.id
            }
        }
    }

    private func applySelected() {
        guard let d = currentDraft else { return }
        note = GameWorkshop.approveAndApply(d.id)
        refresh()
    }
}

/// Sandboxed preview web view: local file access limited to one folder; http(s)/ws(s) blocked by a content rule list;
/// no script message handlers (no native bridge). Game code never reaches wallets from here.
#if os(macOS)
struct WorkshopSandboxWeb: NSViewRepresentable {
    let url: URL
    let allowRead: URL

    func makeCoordinator() -> WorkshopSandboxCoordinator { WorkshopSandboxCoordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let v = WKWebView(frame: .zero, configuration: WorkshopSandboxCoordinator.makeConfig())
        v.navigationDelegate = context.coordinator
        context.coordinator.attach(v)
        return v
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.load(url: url, allowRead: allowRead, in: view)
    }
}
#else
struct WorkshopSandboxWeb: UIViewRepresentable {
    let url: URL
    let allowRead: URL

    func makeCoordinator() -> WorkshopSandboxCoordinator { WorkshopSandboxCoordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView(frame: .zero, configuration: WorkshopSandboxCoordinator.makeConfig())
        v.navigationDelegate = context.coordinator
        context.coordinator.attach(v)
        return v
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.load(url: url, allowRead: allowRead, in: view)
    }
}
#endif

final class WorkshopSandboxCoordinator: NSObject, WKNavigationDelegate {
    private var loaded: URL?
    private var ruleReady = false
    private var pending: (URL, URL)?
    private weak var view: WKWebView?

    static let blockNetworkRules = """
    [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}}]
    """

    static func makeConfig() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        return cfg
    }

    func attach(_ v: WKWebView) {
        view = v
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "yabot-workshop-sandbox",
                                                               encodedContentRuleList: Self.blockNetworkRules) { [weak self] list, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let list { v.configuration.userContentController.add(list) }
                self.ruleReady = true
                if let p = self.pending { self.pending = nil; self.loaded = nil; self.load(url: p.0, allowRead: p.1, in: v) }
            }
        }
    }

    func load(url: URL, allowRead: URL, in view: WKWebView) {
        guard ruleReady else { pending = (url, allowRead); return }
        guard loaded != url else { return }
        loaded = url
        view.loadFileURL(url, allowingReadAccessTo: allowRead)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""
        decisionHandler(scheme == "file" || scheme == "about" || scheme == "blob" || scheme == "data" ? .allow : .cancel)
    }
}
