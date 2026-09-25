import Foundation

/// **SCOUT WALIS** — offline-only Lab Scout (Decider 2026-09-22).
/// "Walis" = broom/sweep: comb HARD drives only, then clean + organize scout folders
/// for function effectiveness + dynamism. Never flips ONLINE. Never invents genotypes.
enum LabScoutWalis {
    static let commandName = "SCOUT WALIS"
    static let schema = "LabScoutWalis.v1"
    static let teachRelpath = "lab/scaffolds/TEACH-SCOUT-WALIS.md"

    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
    }

    private static var scaffolds: URL {
        docs.appendingPathComponent("ЯBOT/lab/scaffolds")
    }

    private static var scoutRoot: URL {
        scaffolds.appendingPathComponent("scout")
    }

    private static var walisLog: URL {
        scoutRoot.appendingPathComponent("walis/WALIS-LAST.json")
    }

    /// Clay: `scout walis` · `SCOUT WALIS` · `walis` · `scout broom`
    static func handleClay(_ text: String) -> String? {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases = [
            "scout walis", "scoutwalis", "scout-walis",
            "scoot walis", // soft typo
            "walis", "lab walis", "scout broom", "broom scout",
        ]
        if aliases.contains(lower) { return run() }
        if lower.hasPrefix("scout walis ") || lower.hasPrefix("walis ") {
            return run()
        }
        return nil
    }

    /// Offline-only HARD comb + cleanup/organize. Forces stay OFFLINE for this verb.
    @discardableResult
    static func run() -> String {
        // Law: WALIS never flips green nerve
        if ModeStore.shared.isOnline {
            _ = ModeStore.shared.goOffline(reason: "scout-walis-offline-only")
        }

        var blocks: [String] = [
            "SCOUT WALIS · OFFLINE ONLY · HARD comb + cleanup",
            "Mode: OFFLINE premier (WALIS refuses WWW / green nerve)",
        ]

        let hard = combHard()
        blocks.append(contentsOf: hard.lines)

        let tidy = organizeFolders()
        blocks.append(contentsOf: tidy.lines)

        _ = ScoutMissingTeach.seatIntoHeart()
        LabScoutCommand.refreshMissionDeltaFromInventory()
        blocks.append(LabScoutCommand.missionDeltaClearLine)
        blocks.append("Tip: plain `scout` / `bScout` = offline-first; WWW only if HARD empty (way-out flip).")
        blocks.append("Teach: \(teachRelpath)")

        let previousHave = LabScoutCommand.missionDeltaPreviousHave
        let newHave = LabScoutCommand.missionDeltaNewHave
        let pdf = LabManualDesk.refreshLivingLeaf(
            note: "SCOUT WALIS · offline sweep · \(hard.hitCount) hard hits · tidy \(tidy.moved)",
            kind: "scout-have",
            previousTotal: previousHave,
            newTotal: newHave
        )
        blocks.append(pdf)

        persistLog(hardHits: hard.hitCount, moved: tidy.moved, notes: hard.notes + tidy.notes)
        _ = GhostChainLedger.append(op: "claim", bio: "lab-scout-walis", source: "hard", extra: [
            "schema": schema,
            "hits": hard.hitCount,
            "tidy_moved": tidy.moved,
            "online": false,
        ])

        return blocks.joined(separator: "\n")
    }

    // MARK: - HARD comb (offline)

    private struct CombResult {
        var lines: [String]
        var hitCount: Int
        var notes: [String]
    }

    private static func combHard() -> CombResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let roots: [(String, String)] = [
            ("Documents/ЯBOT", home + "/Documents/ЯBOT"),
            ("Documents/ЯBOT/lab", home + "/Documents/ЯBOT/lab"),
            ("lab/scaffolds/scout", home + "/Documents/ЯBOT/lab/scaffolds/scout"),
            ("Desktop/ЯTOOLBOX", home + "/Desktop/ЯTOOLBOX"),
            ("Hukbala lab", home + "/HukbalaHaplogroup AB/lab"),
            ("Downloads/GENO", home + "/Downloads/GENO"),
        ]
        var lines: [String] = ["HARD COMB"]
        var notes: [String] = []
        var hits = 0
        let interesting = ["SCOUT-INVENTORY.json", "SCOUT-MISSING-OF-40.json", "HOLOGRAM-LOCI-680.json",
                           "LOCKED_COUNTS.json", "HO_680_AMERICAS_SLICE.tsv", "WALIS-LAST.json"]
        for (label, path) in roots {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                hits += 1
                lines.append("  ✓ \(label)")
                // shallow name hits
                if let kids = try? fm.contentsOfDirectory(atPath: path) {
                    let match = kids.filter { name in interesting.contains(where: { name == $0 || name.hasSuffix($0) }) }
                    if !match.isEmpty {
                        lines.append("    seats: " + match.prefix(8).joined(separator: " · "))
                        hits += match.count
                    }
                }
            } else {
                notes.append("miss \(label)")
                lines.append("  · \(label) (absent)")
            }
        }
        // Inventory pulse
        let inv = LabScoutCommand.scout()
        lines.append("Inventory pulse · have \(inv.haveTotal) · missing \(inv.missingTotal) · new \(inv.newFound)")
        lines.append("Path: \(inv.inventoryPath)")
        if hits == 0 {
            lines.append("HARD empty under known seats — WALIS stays offline (no WWW). Use plain `bScout` / `scout out` for offline-first→online.")
        }
        return CombResult(lines: lines, hitCount: hits, notes: notes)
    }

    // MARK: - Cleanup + organize

    private struct TidyResult {
        var lines: [String]
        var moved: Int
        var notes: [String]
    }

    /// Sweep loose files into canonical scout folders; dedupe empty dirs; write index.
    private static func organizeFolders() -> TidyResult {
        let fm = FileManager.default
        var lines: [String] = ["WALIS TIDY · organize for dynamism"]
        var notes: [String] = []
        var moved = 0

        let canon: [(String, [String])] = [
            ("shots", ["SHOT-", ".png"]),
            ("obtain", ["HO_SLICE", "WAITING_HO", ".ho.gt", "online-one-"]),
            ("walis", ["WALIS-"]),
            ("mission-1", ["MISSION1", "TOP10_"]),
        ]

        // Ensure canon dirs
        for (dir, _) in canon {
            let url = scoutRoot.appendingPathComponent(dir)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }

        // Move loose SHOT pngs sitting on scout root → shots/
        if let kids = try? fm.contentsOfDirectory(at: scoutRoot, includingPropertiesForKeys: nil) {
            for child in kids {
                let name = child.lastPathComponent
                if name.hasPrefix("SHOT-"), name.lowercased().hasSuffix(".png") {
                    let dest = scoutRoot.appendingPathComponent("shots").appendingPathComponent(name)
                    if !fm.fileExists(atPath: dest.path) {
                        do {
                            try fm.moveItem(at: child, to: dest)
                            moved += 1
                            notes.append("shot→shots/\(name)")
                        } catch {
                            notes.append("skip \(name)")
                        }
                    }
                }
                // Loose obtain crumbs
                if name.hasPrefix("online-one-"), child.hasDirectoryPath == false {
                    // leave dirs; only files
                }
            }
        }

        // Index: list folder counts
        var index: [String: Any] = [
            "schema": "ScoutWalisIndex.v1",
            "ts": ISO8601DateFormatter().string(from: Date()),
            "folders": [:] as [String: Int],
        ]
        var folderCounts: [String: Int] = [:]
        if let kids = try? fm.contentsOfDirectory(at: scoutRoot, includingPropertiesForKeys: [.isDirectoryKey]) {
            for child in kids {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue {
                    let n = (try? fm.contentsOfDirectory(atPath: child.path))?.count ?? 0
                    folderCounts[child.lastPathComponent] = n
                }
            }
        }
        index["folders"] = folderCounts
        index["moved_this_run"] = moved
        let idxURL = scoutRoot.appendingPathComponent("walis/WALIS-INDEX.json")
        try? fm.createDirectory(at: idxURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: index, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            try? s.write(to: idxURL, atomically: true, encoding: .utf8)
        }

        lines.append("  moved \(moved) loose asset(s) into canon folders")
        let summary = folderCounts.sorted { $0.key < $1.key }.prefix(12).map { "\($0.key)=\($0.value)" }.joined(separator: " · ")
        lines.append("  index: \(summary.isEmpty ? "(empty)" : summary)")
        lines.append("  seat: lab/scaffolds/scout/walis/WALIS-INDEX.json")
        return TidyResult(lines: lines, moved: moved, notes: notes)
    }

    private static func persistLog(hardHits: Int, moved: Int, notes: [String]) {
        let row: [String: Any] = [
            "schema": schema,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "offline_only": true,
            "hard_hits": hardHits,
            "tidy_moved": moved,
            "notes": notes.prefix(40).map { $0 },
        ]
        try? FileManager.default.createDirectory(at: walisLog.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            try? s.write(to: walisLog, atomically: true, encoding: .utf8)
        }
    }
}
