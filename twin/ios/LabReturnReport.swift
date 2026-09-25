import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Lab Return Report — hardcoded contract so Lab can always emit this PDF schema.
/// Extends MagnetizedContrast / LabScout Mission 1; does not invent genotypes.
enum LabReturnReport {
    static let schemaVersion = "LabReturnReport.v1"
    static let build = MagnetizedContrast.build // GRCh37
    static let kitBeltABO = MagnetizedContrast.kitBeltABO // AB+
    static let kennewickPolicy = "STOP_BAM"
    static let reportDate = "2026-09-22"

    /// Canonical Mac seat path for the PDF deliverable.
    static let macPDFPath =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-2026-09-22.pdf"

    /// Americas 10×5 compare PDF (Mission 1b unique roster / obtain status).
    static let macComparePDFPath =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-AMERICAS-10x5-COMPARE-2026-09-22.pdf"

    /// HO obtain / first3 slice seat (Documents-relative under ЯBOT).
    static let macObtainDir =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/obtain"
    static let macRunHoFirst3 =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/obtain/run-ho-first3.sh"
    static let macLabScoutRunJSON =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/obtain/LAB-SCOUT-RUN.json"
    static let macMission1bSummary =
        "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/mission-1b-5region/MISSION1B-SUMMARY.json"

    /// Hardcoded summary counts (seated 2026-09-22 — Decider honesty; do not invent).
    struct Summary: Equatable, Codable {
        var schema: String = LabReturnReport.schemaVersion
        var title: String = "ЯBOT Lab Return Report"
        var date: String = LabReturnReport.reportDate
        var build: String = LabReturnReport.build
        var kitBeltABO: String = LabReturnReport.kitBeltABO
        var kennewick: String = LabReturnReport.kennewickPolicy
        var pdfPath: String = LabReturnReport.macPDFPath
        var comparePdfPath: String = LabReturnReport.macComparePDFPath

        // USR1 HARD ∩ kit LEFT (HOLOGRAM-LOCI-680)
        var usr1MatchLit: Int = 192
        var usr1Diff: Int = 25
        var usr1KitOnly: Int = 460
        var usr1Missing: Int = 3
        var usr1DepthGt0: Int = 220
        var usr1MatchedLitOver680: String = "192/680"

        // USR2 ∩ kit (exact diploid magnetize)
        var usr2Compared: Int = 107
        var usr2Magnetized: Int = 48
        var usr2Different: Int = 59
        var usr2MissingUsr2: Int = 570
        var usr2MissingBoth: Int = 3

        // Kit archaic copy distribution (LEFT copies_label)
        var copiesBoth: Int = 283
        var copiesOne: Int = 215
        var copiesNone: Int = 179
        var copiesNA: Int = 3

        // Scout HO first3 magnetize vs kit LEFT (2026-09-22) — exact letter only
        // Label law: matches_exact · matches_copies_2 · matches_copies_1
        var anzickMatchesExact: Int = 30
        var anzickCopies2: Int = 14
        var anzickCopies1: Int = 7
        var anzickCompared: Int = 107
        var anzickLabel: String = "match 30 · c2 14 · c1 7"
        var ahur770cMatchesExact: Int = 28
        var ahur770cCopies2: Int = 15
        var ahur770cCopies1: Int = 4
        var ahur770cCompared: Int = 107
        var ahur770cLabel: String = "match 28 · c2 15 · c1 4"
        var ahur2064MatchesExact: Int = 26
        var ahur2064Copies2: Int = 12
        var ahur2064Copies1: Int = 7
        var ahur2064Compared: Int = 109
        var ahur2064Label: String = "match 26 · c2 12 · c1 7"
        var scoutHoMagnetizeLaw: String = "exact unordered diploid allele letters vs kit LEFT; HO 0/1/2 via snp allele1/allele2"

        // Mission 1 pools
        var mission1PoolNorth: Int = 186
        var mission1PoolCentral: Int = 392
        var mission1PoolSouth: Int = 389

        var laws: [String] = [
            "GRCh37 only",
            "no invented genotypes or tribal associations",
            "MICRO≠MACRO (never average 680↔673703)",
            "Kennewick STOP_BAM",
            "ABO belt AB+ (kit only; ancient ABO NOT_PUBLISHED)",
            "STR off 680 grid",
            "roster columns: matches_exact · matches_copies_2 · matches_copies_1",
            "scout HO returns magnetize exact letter only (no invent)",
        ]
    }

    struct Payload: Equatable {
        var pdfPath: String
        var pdfExists: Bool
        var summary: Summary
        var note: String
    }

    /// Lab return-report method — hardcoded contract.
    /// Prefer disk PDF at Mac seat; always returns structured Summary even if PDF missing.
    static func returnReport() -> Payload {
        let summary = loadSummary() ?? Summary()
        let path = resolvePDFPath()
        let exists = FileManager.default.fileExists(atPath: path)
        let note: String
        if exists {
            note = "Lab return-report ready · \(summary.usr1MatchedLitOver680) USR1 MATCH_LIT · USR2 mag \(summary.usr2Magnetized) · Anzick \(summary.anzickLabel) · Spirit770c \(summary.ahur770cLabel) · Spirit2064 \(summary.ahur2064Label) · Kennewick STOP_BAM"
        } else {
            note = "Summary hardcoded; PDF not yet seated at \(path)"
        }
        return Payload(pdfPath: path, pdfExists: exists, summary: summary, note: note)
    }

    /// Open the PDF with the system viewer when present (macOS).
    @discardableResult
    static func revealOrOpenPDF() -> Bool {
        let p = returnReport()
        guard p.pdfExists else { return false }
        #if canImport(AppKit)
        return NSWorkspace.shared.open(URL(fileURLWithPath: p.pdfPath))
        #else
        return false
        #endif
    }

    // MARK: - Seats

    private static func resolvePDFPath() -> String {
        let candidates = [
            macPDFPath,
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-2026-09-22.pdf",
            Bundle.main.path(forResource: "LAB-RETURN-REPORT-2026-09-22", ofType: "pdf") ?? "",
        ]
        for c in candidates where !c.isEmpty {
            if FileManager.default.fileExists(atPath: c) { return c }
        }
        return macPDFPath
    }

    private static func loadSummary() -> Summary? {
        for url in summaryURLs() {
            if let data = try? Data(contentsOf: url),
               let s = try? JSONDecoder().decode(Summary.self, from: data) {
                return s
            }
        }
        // Hardcoded fallback — always available offline
        return Summary()
    }

    private static func summaryURLs() -> [URL] {
        var list: [URL] = []
        let home = URL(fileURLWithPath: NSHomeDirectory())
        list.append(home.appendingPathComponent(
            "Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json"))
        list.append(URL(fileURLWithPath:
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json"))
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            list.append(support.appendingPathComponent("ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json"))
        }
        if let bundle = Bundle.main.url(forResource: "LAB-RETURN-REPORT-SUMMARY", withExtension: "json") {
            list.append(bundle)
        }
        return list
    }

    // MARK: - Americas compare PDF

    static func resolveComparePDFPath() -> String {
        let candidates = [
            macComparePDFPath,
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-AMERICAS-10x5-COMPARE-2026-09-22.pdf",
            Bundle.main.path(forResource: "SCOUT-AMERICAS-10x5-COMPARE-2026-09-22", ofType: "pdf") ?? "",
        ]
        for c in candidates where !c.isEmpty {
            if FileManager.default.fileExists(atPath: c) { return c }
        }
        return macComparePDFPath
    }

    @discardableResult
    static func revealOrOpenComparePDF() -> Bool {
        let path = resolveComparePDFPath()
        guard FileManager.default.fileExists(atPath: path) else { return false }
        #if canImport(AppKit)
        return NSWorkspace.shared.open(URL(fileURLWithPath: path))
        #else
        return false
        #endif
    }

    /// Flexible Mission 1b dont_have / status counts for Lab list (nil if summary missing).
    static func mission1bDontHaveSummary() -> String? {
        let urls: [URL] = [
            URL(fileURLWithPath: macMission1bSummary),
            URL(fileURLWithPath: NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/mission-1b-5region/MISSION1B-SUMMARY.json"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/MISSION1B-SUMMARY.json"),
        ]
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let dh = obj["dont_have"] as? [String: Any] {
                let parts = dh.keys.sorted().map { "\($0) \(intAny(dh[$0]))" }
                return "dont_have · " + parts.joined(separator: " · ")
            }
            if let dh = obj["dont_have_counts"] as? [String: Any] {
                let parts = dh.keys.sorted().map { "\($0) \(intAny(dh[$0]))" }
                return "dont_have · " + parts.joined(separator: " · ")
            }
            if let sc = obj["status_counts"] as? [String: Any] {
                let keys = ["NEED_HO_SLICE", "NEED_ENA", "STOP_BAM", "HAVE_LOCAL", "KNOWN"]
                let parts = keys.compactMap { k -> String? in
                    guard let v = sc[k] else { return nil }
                    return "\(k) \(intAny(v))"
                }
                if !parts.isEmpty { return "mission-1b · " + parts.joined(separator: " · ") }
            }
            if let n = obj["dont_have_n"] as? Int {
                return "dont_have_n \(n)"
            }
        }
        return nil
    }

    private static func intAny(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String, let i = Int(s) { return i }
        return 0
    }

    // MARK: - Americas site matches (SCOUT sync)

    /// One Americas sample's magnetize / MATCH_LIT readout — match · c2 · c1.
    struct SiteMatch: Equatable, Codable, Identifiable {
        var id: String
        var matchesExact: Int
        var matchesCopies2: Int
        var matchesCopies1: Int
        var label: String
        var source: String
        var build: String
        var compared: Int?
        var different: Int?
        var note: String?

        enum CodingKeys: String, CodingKey {
            case id
            case matchesExact = "matches_exact"
            case matchesCopies2 = "matches_copies_2"
            case matchesCopies1 = "matches_copies_1"
            case label, source, build, compared, different, note
        }

        var shortLabel: String { label.isEmpty ? "match \(matchesExact) · c2 \(matchesCopies2) · c1 \(matchesCopies1)" : label }
    }

    /// Hardcoded fallback when SCOUT inventory / SUMMARY missing (HO first3 + USR1/USR2).
    static let americasSiteMatchesFallback: [SiteMatch] = [
        SiteMatch(id: "USR1.SG", matchesExact: 192, matchesCopies2: 79, matchesCopies1: 60,
                  label: "match 192 · c2 79 · c1 60", source: "USR1_MATCH_LIT", build: "GRCh37",
                  compared: nil, different: nil, note: "MATCH_LIT pipeline"),
        SiteMatch(id: "USR2.SG", matchesExact: 48, matchesCopies2: 34, matchesCopies1: 1,
                  label: "match 48 · c2 34 · c1 1", source: "USR2_MAGNETIZE", build: "GRCh37",
                  compared: 107, different: 59, note: nil),
        SiteMatch(id: "Anzick.SG", matchesExact: 30, matchesCopies2: 14, matchesCopies1: 7,
                  label: "match 30 · c2 14 · c1 7", source: "SCOUT_HO_MAGNETIZE", build: "GRCh37",
                  compared: 107, different: 77, note: nil),
        SiteMatch(id: "AHUR770c.SG", matchesExact: 28, matchesCopies2: 15, matchesCopies1: 4,
                  label: "match 28 · c2 15 · c1 4", source: "SCOUT_HO_MAGNETIZE", build: "GRCh37",
                  compared: 107, different: 79, note: nil),
        SiteMatch(id: "AHUR_2064.SG", matchesExact: 26, matchesCopies2: 12, matchesCopies1: 7,
                  label: "match 26 · c2 12 · c1 7", source: "SCOUT_HO_MAGNETIZE", build: "GRCh37",
                  compared: 109, different: 83, note: nil),
    ]

    /// Live Americas site matches — prefers SUMMARY / SCOUT inventory; falls back to hardcoded.
    static var americasSiteMatches: [SiteMatch] {
        if let fromDisk = loadAmericasSiteMatches(), !fromDisk.isEmpty { return fromDisk }
        return americasSiteMatchesFallback
    }

    /// After each SCOUT mission: refresh return-report match · c2 · c1 from SCOUT inventory + magnetize JSON.
    @discardableResult
    static func refreshAmericasSiteMatchesFromScout() -> [SiteMatch] {
        var byId: [String: SiteMatch] = [:]
        for m in americasSiteMatchesFallback { byId[m.id] = m }

        // Prefer per-id magnetize files
        for dir in magnetizeDirs() {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for name in files where name.hasSuffix("_vs_KIT_LEFT.json") {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
                guard let data = try? Data(contentsOf: url),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = obj["id"] as? String else { continue }
                let exact = intAny(obj["matches_exact"])
                let c2 = intAny(obj["matches_copies_2"])
                let c1 = intAny(obj["matches_copies_1"])
                let label = (obj["label"] as? String) ?? "match \(exact) · c2 \(c2) · c1 \(c1)"
                byId[id] = SiteMatch(
                    id: id,
                    matchesExact: exact,
                    matchesCopies2: c2,
                    matchesCopies1: c1,
                    label: label,
                    source: "SCOUT_HO_MAGNETIZE",
                    build: (obj["build"] as? String) ?? "GRCh37",
                    compared: intOpt(obj["compared"]),
                    different: intOpt(obj["different"]),
                    note: nil
                )
            }
        }

        // Offline retain seats (e.g. I11974 MICRO_680) — magnetize gap noted until HO full slice
        for seat in micro680RetainSeats() {
            if byId[seat.id] == nil {
                byId[seat.id] = seat
            }
        }

        // Merge SCOUT inventory last_mission.new_labels / americasSiteMatches if present
        if let inv = loadScoutInventoryObject() {
            if let arr = inv["americasSiteMatches"] as? [[String: Any]] {
                for obj in arr {
                    guard let id = obj["id"] as? String else { continue }
                    let exact = intAny(obj["matches_exact"] ?? obj["matchesExact"])
                    let c2 = intAny(obj["matches_copies_2"] ?? obj["matchesCopies2"])
                    let c1 = intAny(obj["matches_copies_1"] ?? obj["matchesCopies1"])
                    let label = (obj["label"] as? String) ?? "match \(exact) · c2 \(c2) · c1 \(c1)"
                    byId[id] = SiteMatch(
                        id: id,
                        matchesExact: exact,
                        matchesCopies2: c2,
                        matchesCopies1: c1,
                        label: label,
                        source: (obj["source"] as? String) ?? "SCOUT",
                        build: (obj["build"] as? String) ?? "GRCh37",
                        compared: intOpt(obj["compared"]),
                        different: intOpt(obj["different"]),
                        note: obj["note"] as? String
                    )
                }
            }
        }

        // Stable order: USR1, USR2, then alpha
        let preferred = ["USR1.SG", "USR2.SG"]
        var ordered: [SiteMatch] = []
        for id in preferred {
            if let m = byId.removeValue(forKey: id) { ordered.append(m) }
        }
        ordered.append(contentsOf: byId.values.sorted { $0.id < $1.id })

        persistAmericasSiteMatches(ordered)
        return ordered
    }

    private static func loadAmericasSiteMatches() -> [SiteMatch]? {
        for url in summaryURLs() {
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["americasSiteMatches"] as? [[String: Any]] else { continue }
            let decoded: [SiteMatch] = arr.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                let exact = intAny(row["matches_exact"] ?? row["matchesExact"])
                let c2 = intAny(row["matches_copies_2"] ?? row["matchesCopies2"])
                let c1 = intAny(row["matches_copies_1"] ?? row["matchesCopies1"])
                let label = (row["label"] as? String) ?? "match \(exact) · c2 \(c2) · c1 \(c1)"
                return SiteMatch(
                    id: id,
                    matchesExact: exact,
                    matchesCopies2: c2,
                    matchesCopies1: c1,
                    label: label,
                    source: (row["source"] as? String) ?? "SCOUT",
                    build: (row["build"] as? String) ?? "GRCh37",
                    compared: intOpt(row["compared"]),
                    different: intOpt(row["different"]),
                    note: row["note"] as? String
                )
            }
            if !decoded.isEmpty { return decoded }
        }
        return nil
    }

    private static func persistAmericasSiteMatches(_ matches: [SiteMatch]) {
        // Write into SUMMARY.json when present on Mac Documents seat
        let paths = [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json",
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(matches),
              let arr = try? JSONSerialization.jsonObject(with: encoded) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        for path in paths {
            let url = URL(fileURLWithPath: path)
            var obj: [String: Any] = [:]
            if let data = try? Data(contentsOf: url),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                obj = existing
            }
            obj["americasSiteMatches"] = arr
            obj["americasSiteMatchesRefreshedAt"] = stamp
            obj["americasSiteMatchesSource"] = "SCOUT inventory sync"
            if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
                try? out.write(to: url, options: .atomic)
            }
        }
    }


    /// MICRO_680 retain seats (offline) — known HO index retained but may still need full HO slice+magnetize.
    private static func micro680RetainSeats() -> [SiteMatch] {
        let home = NSHomeDirectory()
        let candidates = [
            home + "/Documents/ЯBOT/lab/scaffolds/scout/obtain/online-one-I11974/MANIFEST.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/obtain/online-one-I11974/MANIFEST.json",
        ]
        var out: [SiteMatch] = []
        for path in candidates {
            guard FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let id = (obj["target"] as? String) ?? "I11974.SG"
            let called = intAny(obj["called"])
            let nLoci = intAny(obj["n_loci"])
            let status = (obj["status"] as? String) ?? "RETAINED_MICRO680"
            out.append(SiteMatch(
                id: id,
                matchesExact: called,
                matchesCopies2: 0,
                matchesCopies1: 0,
                label: "RETAINED_MICRO680 called \(called)/\(max(nLoci, 1)) · NEED full HO slice+magnetize",
                source: status,
                build: "GRCh37",
                compared: nLoci,
                different: nil,
                note: "HO index known; MICRO_680 retained offline; not yet sliced+magnetized to match·c2·c1"
            ))
            break
        }
        return out
    }

    private static func magnetizeDirs() -> [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Documents/ЯBOT/lab/scaffolds/scout/obtain/magnetize",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/obtain/magnetize",
        ]
    }

    private static func loadScoutInventoryObject() -> [String: Any]? {
        let paths = [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/obtain/SCOUT-INVENTORY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            Bundle.main.path(forResource: "SCOUT-INVENTORY", ofType: "json") ?? "",
        ]
        for path in paths where !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        return nil
    }

    private static func intOpt(_ any: Any?) -> Int? {
        if any == nil { return nil }
        let v = intAny(any)
        return v
    }

}
