import Foundation

/// Lab function command **SCOUT** — post-mission inventory readout.
/// After a scouting mission: how many new found+added, totals we still have,
/// and still missing by region (N·C·S·E·W). Does not invent genotypes.
enum LabScoutCommand {
    static let commandName = "SCOUT"
    static let schema = "LabScoutCommand.SCOUT.v1"

    /// Hardcoded clear before→after (refresh via refreshMissionDeltaFromInventory; always printed in reply).
    static var beforeHave: Int = 2
    static var beforeMatchSum: Int = 240
    static var afterHave: Int = 5
    static var afterMatchSum: Int = 324
    static var missionDeltaClearLine: String = "BEFORE 2 have / 240 matches  →  AFTER scout mission 5 have / 324 matches"
    static var missionDeltaPreviousHave: Int = 2
    static var missionDeltaNewHave: Int = 5
    static var missionDeltaPreviousMatches: Int = 240
    static var missionDeltaNewMatches: Int = 324
    static let helixInspectHint = "Inspect 3D genome helix light model for locus detail (GENOME-HOLOGRAM-680)"
    static let helixDeepLink = "yabot://lab/helix"
    static let helixAssetName = "GENOME-HOLOGRAM-680"

    struct Readout: Equatable {
        var text: String
        var newFound: Int
        var haveTotal: Int
        var missingTotal: Int
        var inventoryPath: String
    }

    /// Clay / Lab verb: `scout` · `SCOUT` · `lab scout`
    static func scout() -> Readout {
        // CoS lock: keep return-report match · c2 · c1 in sync with SCOUT inventory
        let synced = LabReturnReport.refreshAmericasSiteMatchesFromScout()
        // HARDCODE clear BEFORE→AFTER into reply + living USER-MANUAL + PDF every fire
        refreshMissionDeltaFromInventory(siteMatches: synced)
        _ = appendMissionDeltaToUserManual()
        _ = LabManualDesk.refreshLivingLeaf(
            note: "SCOUT desk refresh · \(missionDeltaClearLine)",
            kind: "scout-have",
            previousTotal: missionDeltaPreviousHave,
            newTotal: missionDeltaNewHave
        )
        let inv = loadInventory()
        let text = format(inv, siteMatches: synced)
        let last = inv["last_mission"] as? [String: Any]
        let totals = inv["totals"] as? [String: Any]
        return Readout(
            text: text,
            newFound: intAny(last?["new_found"]),
            haveTotal: intAny(totals?["have_local_n"]),
            missingTotal: intAny(totals?["missing_n"]),
            inventoryPath: resolveInventoryPath() ?? "(summary hardcoded offline)"
        )
    }


    /// Recompute BEFORE→AFTER from americasSiteMatches (USR1+USR2 = before; all = after).
    static func refreshMissionDeltaFromInventory(siteMatches: [LabReturnReport.SiteMatch]? = nil) {
        let matches = siteMatches ?? LabReturnReport.americasSiteMatches
        let baseline: Set<String> = ["USR1.SG", "USR2.SG"]
        let before = matches.filter { baseline.contains($0.id) }
        let beforeHaveN = max(before.count, 1)
        let beforeSum = before.reduce(0) { $0 + $1.matchesExact }
        let afterHaveN = matches.count
        let afterSum = matches.reduce(0) { $0 + $1.matchesExact }
        beforeHave = beforeHaveN
        beforeMatchSum = beforeSum
        afterHave = afterHaveN
        afterMatchSum = afterSum
        missionDeltaClearLine = "BEFORE \(beforeHaveN) have / \(beforeSum) matches  →  AFTER scout mission \(afterHaveN) have / \(afterSum) matches"
        missionDeltaPreviousHave = beforeHaveN
        missionDeltaNewHave = afterHaveN
        missionDeltaPreviousMatches = beforeSum
        missionDeltaNewMatches = afterSum
        persistMissionDelta(matches: matches)
    }

    private static func persistMissionDelta(matches: [LabReturnReport.SiteMatch]) {
        let baseline: Set<String> = ["USR1.SG", "USR2.SG"]
        let delta: [String: Any] = [
            "schema": "ScoutMissionDelta.v1",
            "before": [
                "have_local_n": beforeHave,
                "matches_exact_sum": beforeMatchSum,
                "have_ids": matches.filter { baseline.contains($0.id) }.map(\.id),
                "label": "BEFORE \(beforeHave) have · \(beforeMatchSum) match-sum",
            ],
            "after": [
                "have_local_n": afterHave,
                "matches_exact_sum": afterMatchSum,
                "have_ids": matches.map(\.id),
                "label": "AFTER \(afterHave) have · \(afterMatchSum) match-sum",
            ],
            "clear_line": missionDeltaClearLine,
            "helix_inspect": helixInspectHint,
            "helix_deeplink": helixDeepLink,
            "ts": ISO8601DateFormatter().string(from: Date()),
        ]
        let paths = [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/LAB-RETURN-REPORT-SUMMARY.json",
        ]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            var obj: [String: Any] = [:]
            if let data = try? Data(contentsOf: url),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                obj = existing
            }
            obj["mission_delta"] = delta
            if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
                try? out.write(to: url, options: .atomic)
            }
        }
    }

    /// Fold BEFORE→AFTER clear line into living USER-MANUAL.md every SCOUT fire.
    @discardableResult
    static func appendMissionDeltaToUserManual() -> Bool {
        let candidates = [
            NSHomeDirectory() + "/Documents/ЯBOT/USER-MANUAL.md",
            "/Users/rizal/Documents/ЯBOT/USER-MANUAL.md",
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return false }
        let url = URL(fileURLWithPath: path)
        guard var body = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let leaf = """

## SCOUT mission delta (auto) — \(stamp)

**HARDCODE in every SCOUT reply:**
`\(missionDeltaClearLine)`

**Detail:** \(helixInspectHint) · deep link `\(helixDeepLink)`

"""
        let marker = "\n## SCOUT mission delta (auto)"
        if let range = body.range(of: marker) {
            if let handoff = body.range(of: "\n\nHANDOFF RULE", options: .backwards) {
                body = String(body[..<range.lowerBound]) + leaf + String(body[handoff.lowerBound...])
            } else if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
                body = String(body[..<range.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
            } else {
                body = String(body[..<range.lowerBound]) + leaf + "\n\nHANDOFF RULE\n"
            }
        } else if let handoff = body.range(of: "\n\nHANDOFF RULE", options: .backwards) {
            body = String(body[..<handoff.lowerBound]) + leaf + String(body[handoff.lowerBound...])
        } else if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
            body = String(body[..<handoff.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
        } else {
            body += leaf + "\n\nHANDOFF RULE\n"
        }
        do {
            try body.write(to: url, atomically: true, encoding: .utf8)
            let twin = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/ЯBOT/ЯBOT/USER-MANUAL.md")
            try? body.write(to: twin, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Format

    private static func format(_ inv: [String: Any], siteMatches: [LabReturnReport.SiteMatch] = []) -> String {
        let last = inv["last_mission"] as? [String: Any] ?? [:]
        let totals = inv["totals"] as? [String: Any] ?? [:]
        let by = inv["by_region"] as? [String: Any] ?? [:]
        let newN = intAny(last["new_found"])
        let newIds = (last["new_ids"] as? [String]) ?? []
        let labels = last["new_labels"] as? [String: Any] ?? [:]
        var lines: [String] = []
        lines.append("SCOUT · Lab inventory")
        lines.append("Build GRCh37 · Kennewick STOP_BAM")
        lines.append("")
        lines.append("══════════════════════════════════")
        lines.append(missionDeltaClearLine)
        lines.append("══════════════════════════════════")
        lines.append("Detail → inspect 3D genome helix light model")
        lines.append("  \(helixInspectHint)")
        lines.append("  open \(helixDeepLink)")
        lines.append("")
        lines.append("LAST MISSION — new found + added: \(newN)")
        if newIds.isEmpty {
            lines.append("  (none yet this run)")
        } else {
            for id in newIds {
                let lab = labels[id] as? String
                if let lab, !lab.isEmpty {
                    lines.append("  + \(id) · \(lab)")
                } else {
                    lines.append("  + \(id)")
                }
            }
        }
        lines.append("")
                // LIVE totals from MISSING-OF-40 when present (inventory can lag after online-one retain)
        let liveMissing = ScoutMissingTeach.loadMissing()
        let liveNeed = liveMissing.filter { $0.status == "NEED_HO_SLICE" }.count
        let liveStop = liveMissing.filter { $0.status == "STOP_BAM" }.count
        let liveHave = max(ScoutMissingTeach.uniqueRosterN - liveMissing.count, intAny(totals["have_local_n"]))
        lines.append("TOTALS (unique AADR roster)")
        lines.append("  have \(liveHave) · missing \(liveMissing.count) · STOP_BAM \(liveStop) · NEED_HO_SLICE \(liveNeed) · roster \(ScoutMissingTeach.uniqueRosterN)")
        if let still = totals["still_out_queue"] {
            lines.append("  still-out queue \(still)")
        }
        if let haveIds = totals["have_ids"] as? [String], !haveIds.isEmpty {
            lines.append("  have: " + haveIds.joined(separator: ", "))
        }

lines.append("BY REGION — have / missing / new")
        for r in ["NORTH", "CENTRAL", "SOUTH", "EAST", "WEST"] {
            guard let block = by[r] as? [String: Any] else {
                lines.append("  \(r) · (no data)")
                continue
            }
            let h = intAny(block["have_n"])
            let m = intAny(block["missing_n"])
            let n = intAny(block["new_n"])
            lines.append("  \(r) · have \(h) · missing \(m) · new \(n)")
            if let miss = block["missing_ids"] as? [String], !miss.isEmpty {
                let shown = miss.prefix(8).joined(separator: ", ")
                let more = miss.count > 8 ? " …+\(miss.count - 8)" : ""
                lines.append("      missing: \(shown)\(more)")
            }
        }
        lines.append("")
        lines.append("AMERICAS SITE MATCHES (return-report sync)")
        let matches = siteMatches.isEmpty ? LabReturnReport.americasSiteMatches : siteMatches
        if matches.isEmpty {
            lines.append("  (none)")
        } else {
            for m in matches {
                lines.append("  \(m.id) · \(m.shortLabel)")
            }
        }
        lines.append("")
        lines.append("Label law: matches_exact · matches_copies_2 · matches_copies_1")
        lines.append("Verb: SCOUT · seats: SCOUT-INVENTORY.json")
        lines.append("")
        // LIVE offline intelligence — never hardcode stale 35 when MISSING-OF-40.json moved
        let missRows = ScoutMissingTeach.loadMissing()
        let needHO = missRows.filter { $0.status == "NEED_HO_SLICE" }
        let stopBam = missRows.filter { $0.status == "STOP_BAM" }
        let haveN = ScoutMissingTeach.uniqueRosterN - missRows.count
        lines.append("MISSING-OF-40: \(missRows.count) LEFT (\(needHO.count) NEED_HO_SLICE · \(stopBam.count) STOP_BAM)")
        lines.append("  have now \(max(haveN, 0)) / roster \(ScoutMissingTeach.uniqueRosterN)")
        if let next = needHO.first {
            let bp = next.dateBP.map { String(Int($0)) } ?? "?"
            let ho = next.hoInd ?? "?"
            let loc = next.locality ?? ""
            lines.append("  WHY: HO INDEX KNOWN BUT NOT SLICED+MAGNETIZED YET (KENNEWICK NEVER BAM)")
            lines.append("  NEXT: \(next.id) · ho_ind \(ho) · BP \(bp) · \(next.regions.joined(separator: ","))\(loc.isEmpty ? "" : " · \(loc)")")
            lines.append("  FIX: SCOUT MISSING → HO SLICE BY ho_ind \(ho) → MAGNETIZE EXACT LETTER vs kit LEFT → HARDCODE match·c2·c1 → MANUAL")
            lines.append("  VERBS: scout missing · HO SLICE \(next.id) · MAGNETIZE \(next.id) · HARDCODE MANUAL")
        } else if !stopBam.isEmpty {
            lines.append("  WHY: only STOP_BAM remains (\(stopBam.map(\.id).joined(separator: ", "))) — never BAM")
            lines.append("  FIX: leave STOP_BAM forever missing · roster complete for NEED_HO_SLICE")
        } else {
            lines.append("  WHY: roster complete offline")
            lines.append("  FIX: none — MATCH report current")
        }
        lines.append("  TIP: scout missing — FULL MISSING-OF-40 + FIX PATH TEACH")
        return lines.joined(separator: "\n")
    }

    // MARK: - Load

    private static func loadInventory() -> [String: Any] {
        for path in inventoryCandidatePaths() {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        return fallbackInventory()
    }

    private static func resolveInventoryPath() -> String? {
        for path in inventoryCandidatePaths() {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return nil
    }

    private static func inventoryCandidatePaths() -> [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            home + "/Documents/ЯBOT/lab/scaffolds/scout/obtain/SCOUT-INVENTORY.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-INVENTORY.json",
            Bundle.main.path(forResource: "SCOUT-INVENTORY", ofType: "json") ?? "",
        ].filter { !$0.isEmpty }
    }

    /// Offline hardcoded snapshot (HO first3 seated 2026-09-22) if JSON missing.
    private static func fallbackInventory() -> [String: Any] {
        [
            "schema": schema,
            "command": commandName,
            "last_mission": [
                "name": "HO first3 slice",
                "new_found": 3,
                "new_ids": ["Anzick.SG", "AHUR770c.SG", "AHUR_2064.SG"],
                "new_labels": [
                    "Anzick.SG": "match 30 · c2 14 · c1 7",
                    "AHUR770c.SG": "match 28 · c2 15 · c1 4",
                    "AHUR_2064.SG": "match 26 · c2 12 · c1 7",
                ],
            ],
            "totals": [
                "unique_roster_n": 40,
                "have_local_n": 5,
                "have_ids": ["AHUR770c.SG", "AHUR_2064.SG", "Anzick.SG", "USR1.SG", "USR2.SG"],
                "missing_n": 34,
                "stop_bam_n": 1,
                "still_out_queue": 24,
            ],
            "by_region": [
                "NORTH": ["have_n": 5, "missing_n": 5, "new_n": 3],
                "CENTRAL": ["have_n": 0, "missing_n": 10, "new_n": 0],
                "SOUTH": ["have_n": 0, "missing_n": 10, "new_n": 0],
                "EAST": ["have_n": 0, "missing_n": 10, "new_n": 0],
                "WEST": ["have_n": 5, "missing_n": 5, "new_n": 3],
            ],
        ]
    }

    private static func intAny(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String, let i = Int(s) { return i }
        return 0
    }
}
