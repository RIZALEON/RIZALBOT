import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Clay Lab Scout · Mission 1 landing — loads MISSION1-TARGETS.json from Documents seat.
/// BOTTOM-CHROME-STRIP: no stray Mind/EXIT bottom chrome (ЯBAR Home leaves landing).
/// ONLINE: Scout COMB HARD·CLOUD·WWW (no BAM download; Kennewick STOP_BAM).
/// OFFLINE: Reader/magnetize — exact letter only.
struct LabScoutView: View {
    @Environment(\.openURL) private var openURL
    @Binding var isPresented: Bool
    var isOnline: Bool = false
    /// Set by yabot://lab/scout/compare — open Americas compare PDF on appear.
    var revealCompareOnAppear: Bool = false

    @State private var pack: Mission1Pack = .load()
    @State private var note: String? = nil
    @State private var returnPayload: LabReturnReport.Payload? = nil
    @State private var mission1bLine: String? = nil
    @State private var scoutBusy: Bool = false
    @State private var showHelix: Bool = false
    var openHelixOnAppear: Binding<Bool> = .constant(false)
    @State private var lastQueueId: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                header
                modeBanner
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        metaCard
                        scoutActionRow
                        returnReportCard
                        ForEach(Mission1Region.allCases) { region in
                            regionCard(region)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let note {
                Text(note)
                    .font(ClayTheme.clayFont(size: 13, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(ClayTheme.charcoalDeep.opacity(0.94)))
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showHelix) {
                    GenomeHelixView(isPresented: $showHelix)
                }
                .onChange(of: openHelixOnAppear.wrappedValue) { _, open in
                    if open {
                        showHelix = true
                        openHelixOnAppear.wrappedValue = false
                    }
                }
                .onAppear {
            pack = .load()
            mission1bLine = LabReturnReport.mission1bDontHaveSummary()
            // Optional ghost establish if ledger API present (idempotent at file layer).
            _ = GhostChainLedger.establish(bio: pack.bio.isEmpty
                ? "LAB_SCOUT_MISSION_1_OLDEST_AMERICAS_10x3"
                : pack.bio)
            if revealCompareOnAppear {
                let ok = LabReturnReport.revealOrOpenComparePDF()
                note = ok ? "Opened Americas compare PDF" : "Compare PDF not seated yet"
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if ClayImage.exists("LabIcon") {
                Image("LabIcon")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
            } else {
                Image(systemName: "flask.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ClayTheme.offWhite)
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Lab Scout · Mission 1")
                    .font(ClayTheme.clayFont(size: 22, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                Text(pack.bio.isEmpty ? "Oldest Americas 10×3" : pack.bio)
                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer()
            Text(isOnline ? "ONLINE" : "OFFLINE")
                .font(ClayTheme.clayFont(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(isOnline ? Color.green.opacity(0.35) : Color.gray.opacity(0.35)))
                .foregroundStyle(ClayTheme.offWhite)
        }
        .padding(.horizontal, 20)
        // MAGNET UNDER BAR — scout tablet never overlaps sticky ЯBAR
        .padding(.top, RedwoodYabarMetrics.contentTopClearance)
    }

    private var modeBanner: some View {
        Text(isOnline
             ? "Scout COMB HARD·CLOUD·WWW · do NOT download BAM · Kennewick STOP_BAM"
             : "Reader/magnetize — exact letter only")
            .font(ClayTheme.clayFont(size: 12, weight: .bold))
            .foregroundStyle(isOnline ? Color.orange.opacity(0.95) : ClayTheme.gold)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Build", pack.build.isEmpty ? "GRCh37" : pack.build)
            row("Pools", pack.poolSummary)
            row("Top ages (BP)", pack.topAgesSummary)
            row("Laws", "GRCh37 · no invented geno/ABO · Kennewick STOP_BAM · USR1/2 HAVE_LOCAL · never average MICRO/MACRO")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(stroke: Color.cyan.opacity(0.35)))
    }

    private func regionCard(_ region: Mission1Region) -> some View {
        let rows = pack.targets(in: region)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(region.title)
                    .font(ClayTheme.clayFont(size: 14, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                Spacer()
                Text("n=\(rows.count)")
                    .font(ClayTheme.clayFont(size: 11, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.65))
            }
            ForEach(rows) { t in
                targetRow(t)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(stroke: Color.white.opacity(0.18)))
    }

    private func targetRow(_ t: Mission1Target) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%2d", t.rank))
                .font(ClayTheme.clayFont(size: 11, weight: .bold))
                .foregroundStyle(Color.cyan.opacity(0.9))
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(t.genetic_id)
                        .font(ClayTheme.clayFont(size: 12, weight: .bold))
                        .foregroundStyle(ClayTheme.offWhite)
                        .textSelection(.enabled)
                    Text(bpLabel(t.date_mean_BP))
                        .font(ClayTheme.clayFont(size: 11, weight: .medium))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.75))
                    Spacer(minLength: 4)
                    statusBadge(t.obtain_status)
                }
                Text(t.locality.isEmpty ? "—" : t.locality)
                    .font(ClayTheme.clayFont(size: 11, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.65))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func statusBadge(_ status: String) -> some View {
        let s = status.uppercased()
        let color: Color = {
            switch s {
            case "HAVE_LOCAL": return Color.green.opacity(0.55)
            case "STOP_BAM": return Color.red.opacity(0.55)
            case "KNOWN": return Color.blue.opacity(0.45)
            default: return Color.gray.opacity(0.4)
            }
        }()
        return Text(s.isEmpty ? "?" : s)
            .font(ClayTheme.clayFont(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
            .foregroundStyle(ClayTheme.offWhite)
    }


    /// Clay launch-bay: compare PDF + COMB obtain (ONLINE only). No BAM from UI.
    private var scoutActionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scout launch bay")
                .font(ClayTheme.clayFont(size: 14, weight: .bold))
                .foregroundStyle(ClayTheme.offWhite)
            Text("Send mini scouts from Lab · Kennewick STOP_BAM · no BAM download")
                .font(ClayTheme.clayFont(size: 11, weight: .medium))
                .foregroundStyle(ClayTheme.offWhite.opacity(0.7))
            if let mission1bLine {
                row("Mission 1b", mission1bLine)
            }
            HStack(spacing: 10) {
                clayActionChip(
                    title: "Open Americas compare PDF",
                    system: "doc.richtext",
                    enabled: true
                ) {
                    let ok = LabReturnReport.revealOrOpenComparePDF()
                    note = ok
                        ? "Opened \(LabReturnReport.resolveComparePDFPath())"
                        : "Compare PDF missing — seat SCOUT-AMERICAS-10x5-COMPARE-2026-09-22.pdf"
                }
                clayActionChip(
                    title: "Inspect 3D genome helix",
                    system: "circle.hexagongrid.fill",
                    enabled: true
                ) {
                    showHelix = true
                }
                clayActionChip(
                    title: "Missing of 40 · teach",
                    system: "questionmark.circle",
                    enabled: true
                ) {
                    note = ScoutMissingTeach.readout()
                }
                clayActionChip(
                    title: "Enter Lab Chamber",
                    system: "door.left.hand.open",
                    enabled: true
                ) {
                    // In-process — never openURL(yabot://) (macOS WindowGroup would spawn another window).
                    NotificationCenter.default.post(name: Notification.Name("ЯBOT.OpenLabChamber"), object: nil)
                }
                clayActionChip(
                    title: "SCOUT inventory",
                    system: "list.bullet.rectangle",
                    enabled: true
                ) {
                    let r = LabScoutCommand.scout()
                    note = r.text
                }
                clayActionChip(
                    title: scoutBusy ? "Scout COMB… running" : "Run Scout COMB obtain",
                    system: "paperplane.fill",
                    enabled: isOnline && !scoutBusy
                ) {
                    runScoutCombObtain()
                }
            }
            if let lastQueueId {
                row("Last queue", lastQueueId)
            }
            row("Compare PDF", LabReturnReport.resolveComparePDFPath())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(stroke: Color.green.opacity(0.4)))
    }

    private func clayActionChip(title: String, system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(ClayTheme.clayFont(size: 12, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(enabled ? ClayTheme.offWhite : ClayTheme.offWhite.opacity(0.4))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(enabled ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(enabled ? Color.cyan.opacity(0.45) : Color.gray.opacity(0.25), lineWidth: 1.1)
                )
        )
        .contentShape(Rectangle())
        .opacity(enabled ? 1 : 0.55)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0).onEnded { value in
                guard enabled else {
                    note = isOnline ? "Scout already running" : "ONLINE required for Scout COMB obtain"
                    return
                }
                let dx = abs(value.translation.width)
                let dy = abs(value.translation.height)
                if dx < 24 && dy < 24 { action() }
            }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
    }

    /// Write LAB-SCOUT-RUN.json (unique queue) + kick Documents-seated run-ho-first3.sh (or python fallback).
    private func runScoutCombObtain() {
        guard isOnline else {
            note = "ONLINE required — Scout COMB obtain stays in Lab launch bay"
            return
        }
        scoutBusy = true
        let queueId = UUID().uuidString.lowercased()
        lastQueueId = queueId
        let home = NSHomeDirectory()
        let obtainDir = home + "/Documents/ЯBOT/lab/scaffolds/scout/obtain"
        let runJSON = obtainDir + "/LAB-SCOUT-RUN.json"
        let script = obtainDir + "/run-ho-first3.sh"
        let outDir = obtainDir + "/ho-slice-first3"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try? fm.createDirectory(atPath: obtainDir, withIntermediateDirectories: true)

        let payload: [String: Any] = [
            "schema": "LabScoutRun.v1",
            "queue_id": queueId,
            "bio": "LAB_SCOUT_COMB_OBTAIN_HO_FIRST3",
            "ts": ISO8601DateFormatter().string(from: Date()),
            "build": "GRCh37",
            "mode": "COMB_OBTAIN",
            "targets": ["Anzick.SG", "AHUR770c.SG", "AHUR_2064.SG"],
            "kennewick": "STOP_BAM",
            "no_bam_download": true,
            "script": "lab/scaffolds/scout/obtain/run-ho-first3.sh",
            "out_dir": "lab/scaffolds/scout/obtain/ho-slice-first3/",
            "laws": [
                "GRCh37",
                "Kennewick STOP_BAM",
                "no BAM from UI",
                "HO slice only for first3",
                "no invented genotypes",
            ],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: runJSON), options: .atomic)
        }

        #if canImport(AppKit)
        let proc = Process()
        proc.currentDirectoryURL = URL(fileURLWithPath: home + "/Documents/ЯBOT")
        let q8 = String(queueId.prefix(8))
        let logPath = outDir + "/run-\(q8).log"
        fm.createFile(atPath: logPath, contents: nil)
        if let logFH = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
            proc.standardOutput = logFH
            proc.standardError = logFH
        }
        if fm.isExecutableFile(atPath: script) || fm.fileExists(atPath: script) {
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [script, queueId]
        } else {
            // Fallback: tiny python slice seated beside script (created by MAC-SEAT).
            let py = obtainDir + "/ho_slice_first3.py"
            if fm.fileExists(atPath: py) {
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                proc.arguments = [py, "--queue-id", queueId, "--out", outDir]
            } else {
                scoutBusy = false
                note = "run-ho-first3.sh not seated — place under lab/scaffolds/scout/obtain/"
                return
            }
        }
        proc.terminationHandler = { p in
            DispatchQueue.main.async {
                scoutBusy = false
                note = p.terminationStatus == 0
                    ? "Scout COMB obtain finished · queue \(queueId.prefix(8)) · Kennewick STOP_BAM"
                    : "Scout COMB exit \(p.terminationStatus) · see obtain/ho-slice-first3/"
                mission1bLine = LabReturnReport.mission1bDontHaveSummary()
            }
        }
        do {
            try proc.run()
            note = "Scout COMB launched · queue \(queueId.prefix(8)) · HO first3 · no BAM"
        } catch {
            scoutBusy = false
            note = "Failed to launch scout: \(error.localizedDescription)"
        }
        #else
        scoutBusy = false
        note = "Scout COMB obtain requires macOS Process"
        #endif
    }


    private var returnReportCard: some View {
        let payload = returnPayload ?? LabReturnReport.returnReport()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lab Return Report")
                    .font(ClayTheme.clayFont(size: 14, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                Spacer()
                Text(payload.pdfExists ? "PDF" : "SUMMARY")
                    .font(ClayTheme.clayFont(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(payload.pdfExists ? Color.green.opacity(0.45) : Color.orange.opacity(0.45)))
                    .foregroundStyle(ClayTheme.offWhite)
            }
            row("USR1 MATCH_LIT", payload.summary.usr1MatchedLitOver680)
            row("USR2 magnetized", "\(payload.summary.usr2Magnetized) / compared \(payload.summary.usr2Compared)")
            row("Anzick.SG HO", payload.summary.anzickLabel)
            row("AHUR770c.SG HO", payload.summary.ahur770cLabel)
            row("AHUR_2064.SG HO", payload.summary.ahur2064Label)
            row("Scout label law", "matches_exact · matches_copies_2 · matches_copies_1")
            ForEach(LabReturnReport.americasSiteMatches, id: \.id) { m in
                row(m.id, m.shortLabel)
            }
            row("Kit copies", "BOTH \(payload.summary.copiesBoth) · ONE \(payload.summary.copiesOne) · none \(payload.summary.copiesNone) · NA \(payload.summary.copiesNA)")
            row("Kennewick", payload.summary.kennewick)
            row("PDF seat", payload.pdfPath)
            row("Compare PDF", payload.summary.comparePdfPath)
            HStack(spacing: 10) {
                ClayButton(
                    asset: "BtnSearch",
                    systemFallback: "doc.richtext",
                    width: 40,
                    height: 40,
                    help: "Emit Lab return-report"
                ) {
                    let p = LabReturnReport.returnReport()
                    returnPayload = p
                    note = p.note
                }
                ClayButton(
                    asset: "BtnOnline",
                    systemFallback: "arrow.up.doc",
                    width: 40,
                    height: 40,
                    help: "Open Lab Return PDF"
                ) {
                    let ok = LabReturnReport.revealOrOpenPDF()
                    note = ok ? "Opened Lab Return PDF" : "PDF not seated yet — summary only"
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(stroke: Color.orange.opacity(0.4)))
        .onAppear { returnPayload = LabReturnReport.returnReport() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(ClayTheme.clayFont(size: 10, weight: .bold))
                .foregroundStyle(Color.cyan.opacity(0.85))
            Text(value)
                .font(ClayTheme.clayFont(size: 12, weight: .medium))
                .foregroundStyle(ClayTheme.offWhite)
                .textSelection(.enabled)
        }
    }

    private func cardBackground(stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(stroke, lineWidth: 1.2)
            )
    }

    private func bpLabel(_ bp: Double) -> String {
        if bp <= 0 { return "—" }
        if bp == floor(bp) { return "\(Int(bp)) BP" }
        return String(format: "%.0f BP", bp)
    }
}

// MARK: - Models

enum Mission1Region: String, CaseIterable, Identifiable {
    case north = "NORTH"
    case central = "CENTRAL"
    case south = "SOUTH"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .north: return "TOP10 · North America"
        case .central: return "TOP10 · Central America"
        case .south: return "TOP10 · South America"
        }
    }
}

struct Mission1Target: Identifiable, Equatable {
    var id: String { "\(region)-\(rank)-\(genetic_id)" }
    var rank: Int = 0
    var genetic_id: String = ""
    var region: String = ""
    var locality: String = ""
    var date_mean_BP: Double = 0
    var obtain_status: String = "KNOWN"
}

struct Mission1Pack: Equatable {
    var bio: String = "LAB_SCOUT_MISSION_1_OLDEST_AMERICAS_10x3"
    var build: String = "GRCh37"
    var poolNorth: Int = 0
    var poolCentral: Int = 0
    var poolSouth: Int = 0
    var topNorth: [Double] = []
    var topCentral: [Double] = []
    var topSouth: [Double] = []
    var targets: [Mission1Target] = []

    var poolSummary: String {
        "N \(poolNorth) · C \(poolCentral) · S \(poolSouth)"
    }

    var topAgesSummary: String {
        func span(_ a: [Double]) -> String {
            guard let first = a.first, let last = a.last else { return "—" }
            return "\(Int(first))…\(Int(last))"
        }
        return "N \(span(topNorth)) · C \(span(topCentral)) · S \(span(topSouth))"
    }

    func targets(in region: Mission1Region) -> [Mission1Target] {
        targets
            .filter { $0.region.uppercased() == region.rawValue }
            .sorted { $0.rank < $1.rank }
    }

    static func load() -> Mission1Pack {
        let urls = seatURLs()
        for url in urls {
            if let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return fromJSON(obj)
            }
        }
        // Fallback: parse TOP10 TSVs from same seat folder
        if let fromTSV = loadFromTSVs() {
            return fromTSV
        }
        var empty = Mission1Pack()
        empty.bio = "(MISSION1-TARGETS.json not seated)"
        return empty
    }

    private static func seatURLs() -> [URL] {
        var list: [URL] = []
        let home = URL(fileURLWithPath: NSHomeDirectory())
        list.append(home.appendingPathComponent("Documents/ЯBOT/lab/scaffolds/scout/mission-1/MISSION1-TARGETS.json"))
        list.append(URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/mission-1/MISSION1-TARGETS.json"))
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            list.append(support.appendingPathComponent("ЯBOT/lab/scaffolds/scout/mission-1/MISSION1-TARGETS.json"))
        }
        if let bundle = Bundle.main.url(forResource: "MISSION1-TARGETS", withExtension: "json") {
            list.append(bundle)
        }
        return list
    }

    private static func fromJSON(_ obj: [String: Any]) -> Mission1Pack {
        var p = Mission1Pack()
        p.bio = obj["bio"] as? String ?? p.bio
        p.build = obj["build"] as? String ?? "GRCh37"
        if let pools = obj["pool_counts_deduped_usable_geno"] as? [String: Any] {
            p.poolNorth = intVal(pools["NORTH"])
            p.poolCentral = intVal(pools["CENTRAL"])
            p.poolSouth = intVal(pools["SOUTH"])
        }
        if let tops = obj["top_ages_BP"] as? [String: Any] {
            p.topNorth = doubleArr(tops["NORTH"])
            p.topCentral = doubleArr(tops["CENTRAL"])
            p.topSouth = doubleArr(tops["SOUTH"])
        }
        if let arr = obj["targets"] as? [[String: Any]] {
            p.targets = arr.map { row in
                Mission1Target(
                    rank: intVal(row["rank"]),
                    genetic_id: row["genetic_id"] as? String ?? "",
                    region: (row["region"] as? String ?? "").uppercased(),
                    locality: row["locality"] as? String ?? "",
                    date_mean_BP: doubleVal(row["date_mean_BP"]),
                    obtain_status: (row["obtain_status"] as? String ?? "KNOWN").uppercased()
                )
            }
        }
        return p
    }

    private static func loadFromTSVs() -> Mission1Pack? {
        let baseCandidates = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/ЯBOT/lab/scaffolds/scout/mission-1"),
            URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/mission-1")
        ]
        guard let base = baseCandidates.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("TOP10_NORTH_AMERICA.tsv").path)
        }) else { return nil }

        var p = Mission1Pack()
        p.build = "GRCh37"
        let files: [(Mission1Region, String)] = [
            (.north, "TOP10_NORTH_AMERICA.tsv"),
            (.central, "TOP10_CENTRAL_AMERICA.tsv"),
            (.south, "TOP10_SOUTH_AMERICA.tsv")
        ]
        for (region, name) in files {
            let url = base.appendingPathComponent(name)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            guard lines.count > 1 else { continue }
            let header = lines[0].split(separator: "\t").map(String.init)
            func idx(_ keys: [String]) -> Int? {
                for k in keys {
                    if let i = header.firstIndex(where: { $0.caseInsensitiveCompare(k) == .orderedSame }) {
                        return i
                    }
                }
                return nil
            }
            let iId = idx(["genetic_id", "Genetic_ID", "GeneticID"]) ?? 1
            let iBP = idx(["date_mean_BP", "Date_mean_BP", "BP"]) ?? 2
            let iLoc = idx(["locality", "Locality"]) ?? 3
            let iStat = idx(["obtain_status", "status", "Status"]) ?? header.count - 1
            for (n, line) in lines.dropFirst().enumerated() {
                let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                func col(_ i: Int) -> String { i < cols.count ? cols[i] : "" }
                let bp = Double(col(iBP)) ?? 0
                p.targets.append(Mission1Target(
                    rank: n + 1,
                    genetic_id: col(iId),
                    region: region.rawValue,
                    locality: col(iLoc),
                    date_mean_BP: bp,
                    obtain_status: col(iStat).uppercased().isEmpty ? "KNOWN" : col(iStat).uppercased()
                ))
                switch region {
                case .north: p.topNorth.append(bp)
                case .central: p.topCentral.append(bp)
                case .south: p.topSouth.append(bp)
                }
            }
        }
        return p.targets.isEmpty ? nil : p
    }

    private static func intVal(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String, let i = Int(s) { return i }
        return 0
    }

    private static func doubleVal(_ any: Any?) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String, let d = Double(s) { return d }
        return 0
    }

    private static func doubleArr(_ any: Any?) -> [Double] {
        if let a = any as? [Double] { return a }
        if let a = any as? [Int] { return a.map(Double.init) }
        if let a = any as? [Any] { return a.map { doubleVal($0) } }
        return []
    }
}
