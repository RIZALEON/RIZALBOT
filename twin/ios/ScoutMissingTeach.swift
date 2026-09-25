import Foundation

/// Lab teach: what is still missing from unique Americas roster of 40, why, and how bots fix/find.
enum ScoutMissingTeach {
    static let schema = "LabScoutMissingTeach.v1"
    static let uniqueRosterN = 40

    /// Compact teach always available offline (also seated in TeachStore via seatIntoHeart()).
    static let teachText = """
LAB SCOUT MISSING-OF-40 TEACH (2026-09-22 Decider):
Unique Americas roster = 40. HAVE now 5 (USR1.SG, USR2.SG, Anzick.SG, AHUR770c.SG, AHUR_2064.SG). STILL MISSING 35 = 34 NEED_HO_SLICE + 1 STOP_BAM (kennewick.SG).
WHY NEED_HO_SLICE: AADR/HO index known (ho_ind) but geno column not yet sliced+magnetized vs kit LEFT — fix by HO slice (no BAM), then exact allele letter magnetize, hardcode match·c2·c1 into americasSiteMatches + SCOUT inventory + USER-MANUAL.
WHY STOP_BAM: Kennewick — knowledge OK, never download/body BAM on phone; leave forever missing from obtain.
FIX PATH for bots inside Lab: (1) next unique id from SCOUT-MISSING-OF-40.json by oldest BP (2) slice HO geno col by ho_ind (3) magnetize exact letter vs R680_KIT_LEFT (4) refresh LabReturnReport.americasSiteMatches + mission_delta BEFORE→AFTER (5) SCOUT reply + manual leaf (6) helix for locus detail. ONLINE only for COMB WWW/ENA when not on HO; OFFLINE Reader for magnetize. Laws: GRCh37 · no invent GT · MICRO≠MACRO · Kennewick STOP_BAM · unique AADR id not 50 slots.
Verb: scout missing · SCOUT · yabot://lab/scout
"""

    struct MissingRow: Equatable {
        var id: String
        var status: String
        var regions: [String]
        var dateBP: Double?
        var hoInd: String?
        var locality: String?
    }

    static func readout() -> String {
        _ = seatIntoHeart()
        let rows = loadMissing()
        let needHO = rows.filter { $0.status == "NEED_HO_SLICE" }
        let stop = rows.filter { $0.status == "STOP_BAM" }
        var lines: [String] = []
        lines.append("SCOUT MISSING-OF-40")
        lines.append(LabScoutCommand.missionDeltaClearLine)
        lines.append("Roster 40 · have \(LabScoutCommand.afterHave) · missing \(rows.count) · STOP_BAM \(stop.count) · NEED_HO_SLICE \(needHO.count)")
        lines.append("")
        lines.append("WHY")
        lines.append("  NEED_HO_SLICE — on HO index, not yet sliced+magnetized (no BAM)")
        lines.append("  STOP_BAM — Kennewick; knowledge OK; never obtain BAM body")
        lines.append("")
        lines.append("HOW BOTS FIX / FIND (Lab) — OFFLINE FIRST")
        if let next = needHO.first {
            lines.append("  NEXT SLICE: \(next.id) ho_ind=\(next.hoInd ?? "?") BP=\(next.dateBP.map { String(Int($0)) } ?? "?")")
            lines.append("  VERBS: HO SLICE \(next.id) · MAGNETIZE \(next.id) · HARDCODE MANUAL")
        }
        lines.append("  1 next oldest NEED_HO_SLICE from SCOUT-MISSING-OF-40.json")
        lines.append("  2 HO geno slice by ho_ind (Documents HO pack) — no BAM")
        lines.append("  3 magnetize exact letter vs kit LEFT → match·c2·c1")
        lines.append("  4 hardcode match·c2·c1 → americasSiteMatches + SCOUT + MANUAL")
        lines.append("  5 refresh BEFORE→AFTER · helix for locus detail")
        lines.append("")
        lines.append("MISSING (oldest first, top 12)")
        for r in needHO.prefix(12) {
            let bp = r.dateBP.map { String(Int($0)) } ?? "?"
            let reg = r.regions.joined(separator: ",")
            lines.append("  \(r.id) · \(reg) · BP \(bp) · ho \(r.hoInd ?? "?")")
        }
        if needHO.count > 12 {
            lines.append("  …+\(needHO.count - 12) more NEED_HO_SLICE")
        }
        if let k = stop.first {
            lines.append("  STOP forever: \(k.id)")
        }
        lines.append("")
        lines.append("Teach seated in Heart/TeachStore · file SCOUT-MISSING-OF-40.json")
        return lines.joined(separator: "\n")
    }

    @discardableResult
    static func seatIntoHeart() -> String {
        let learned = TeachStore.learnedTexts(limit: 40)
        if learned.contains(where: { $0.contains("LAB SCOUT MISSING-OF-40 TEACH") }) {
            return "already seated"
        }
        return TeachStore.remember(teachText, kind: "lock")
    }

    static func loadMissing() -> [MissingRow] {
        for path in [
            NSHomeDirectory() + "/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-MISSING-OF-40.json",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds/scout/SCOUT-MISSING-OF-40.json",
            Bundle.main.path(forResource: "SCOUT-MISSING-OF-40", ofType: "json") ?? "",
        ] where !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            guard let data = try? Data(contentsOf: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = obj["missing"] as? [[String: Any]] else { continue }
            return arr.compactMap { row -> MissingRow? in
                guard let id = row["id"] as? String else { return nil }
                let ho: String?
                if let s = row["ho_ind"] as? String { ho = s }
                else if let i = row["ho_ind"] as? Int { ho = String(i) }
                else { ho = nil }
                return MissingRow(
                    id: id,
                    status: (row["status"] as? String) ?? "NEED_HO_SLICE",
                    regions: (row["regions"] as? [String]) ?? [],
                    dateBP: row["date_BP"] as? Double,
                    hoInd: ho,
                    locality: row["locality"] as? String
                )
            }.sorted { ($0.dateBP ?? 0) > ($1.dateBP ?? 0) }
        }
        return [
            MissingRow(id: "I11974.SG", status: "NEED_HO_SLICE", regions: ["SOUTH"], dateBP: 11885, hoInd: "21882", locality: "Los Rieles"),
            MissingRow(id: "kennewick.SG", status: "STOP_BAM", regions: ["NORTH", "WEST"], dateBP: 8752, hoInd: "7723", locality: "Kennewick"),
        ]
    }
}
