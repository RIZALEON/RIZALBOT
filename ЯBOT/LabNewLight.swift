import Foundation

/// Bring one or more FUTURE-board lights onto the magnetized scaffold from HD (preferred)
/// or online enrich when ModeStore is ONLINE (way-out gate).
/// Every light carries a **SOURCE REMAINS** line naming the genome/bone it came from.
/// Law: exact chrom+pos+allele only — never invent genotypes. Kennewick STOP_BAM.
enum LabNewLight {
    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
    }
    private static var futureURL: URL {
        docs.appendingPathComponent("ЯBOT/lab/scaffolds/poles/FUTURE-LIGHTS.json")
    }
    private static var hologramURL: URL {
        docs.appendingPathComponent("ЯBOT/lab/scaffolds/scout/HOLOGRAM-LOCI-680.json")
    }

    /// Clay: `new light` · `new lights` · `new light 3` · `bring light`
    static func bring(count: Int = 1) -> String {
        let n = max(1, min(count, 40))
        let previousTotal = loadFuture().count
        var blocks: [String] = ["NEW LIGHT(S) · scaffold FUTURE board · requested \(n)"]
        var added: [[String: Any]] = []
        for _ in 0..<n {
            guard let light = nextFromHardDrive() else { break }
            appendFuture(light)
            added.append(light)
            blocks.append(format(light))
            blocks.append(sourceRemainsLine(light))
            _ = GhostChainLedger.append(op: "claim", bio: "lab-new-light", source: "hd", extra: light)
            if ModeStore.shared.isOnline, let rsid = light["rsid"] as? String {
                let q = "search GRCh37 \(rsid) locus"
                let web = OnlineSearch.search(q)
                let clip = String(web.prefix(280))
                blocks.append("ONLINE enrich: \(clip)")
                lightNoteOnline(rsid: rsid, clip: clip)
            }
        }
        let newTotal = loadFuture().count
        let totalsLine = LabManualDesk.totalsClearLine(kind: "lights", previous: previousTotal, new: newTotal)
        if added.isEmpty {
            blocks.append(totalsLine)
            blocks.append("NEW LIGHT MISSING — no unused MATCH_LIT on HD hologram. Kennewick stays STOP_BAM.")
            _ = LabManualDesk.refreshLivingLeaf(
                note: "new light miss · \(totalsLine)",
                kind: "lights",
                previousTotal: previousTotal,
                newTotal: newTotal
            )
            return blocks.joined(separator: "\n")
        }
        // Return report: previous total → new total FIRST after headers
        blocks.insert(totalsLine, at: 1)
        if !ModeStore.shared.isOnline {
            blocks.append("ONLINE: off — HD lights seated only (way-out gate: US + Lab-resident bots).")
        }
        blocks.append("Added \(added.count) light(s). Seat: lab/scaffolds/poles/FUTURE-LIGHTS.json")
        let pdf = LabManualDesk.refreshLivingLeaf(
            note: "new light(s) +\(added.count) · \(totalsLine)",
            kind: "lights",
            previousTotal: previousTotal,
            newTotal: newTotal
        )
        blocks.append(pdf)
        return blocks.joined(separator: "\n")
    }

    /// Parse `new light` / `new lights 3` / `bring a new light`.
    static func handleClay(_ text: String) -> String? {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases = ["new light", "new lights", "lab light", "bring light", "bring a new light", "bring new light"]
        if aliases.contains(lower) { return bring(count: 1) }
        // new light 3 / new lights 5
        for prefix in ["new lights ", "new light "] {
            if lower.hasPrefix(prefix) {
                let rest = String(lower.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                if let k = Int(rest), k > 0 { return bring(count: k) }
            }
        }
        return nil
    }

    static func currentLightCount() -> Int { loadFuture().count }

    private static func loadFuture() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: futureURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lights = obj["lights"] as? [[String: Any]] else { return [] }
        return lights
    }

    private static func appendFuture(_ light: [String: Any]) {
        var lights = loadFuture()
        lights.append(light)
        let row: [String: Any] = [
            "schema": "FutureLights.v1",
            "build": "GRCh37",
            "board": "3d_light_loci_genome_scaffold_slots",
            "ts": ISO8601DateFormatter().string(from: Date()),
            "lights": lights
        ]
        let dir = futureURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            try? s.write(to: futureURL, atomically: true, encoding: .utf8)
        }
    }

    /// Derive remains callsign from contrast pair / hologram metadata.
    private static func remainsFromPair(_ pair: String, ancientPath: String?) -> (id: String, label: String) {
        let p = pair.uppercased()
        let known = [
            ("USR1", "USR1 · Upward Sun River (AK)"),
            ("USR2", "USR2 · Upward Sun River (AK)"),
            ("ANZICK", "Anzick.SG · Montana"),
            ("AHUR770", "AHUR770c.SG · Spirit Cave"),
            ("AHUR_2064", "AHUR_2064.SG · Spirit Cave"),
            ("AHUR2064", "AHUR_2064.SG · Spirit Cave"),
            ("KENNEWICK", "kennewick.SG · STOP_BAM")
        ]
        for (key, label) in known {
            if p.contains(key) { return (key, label) }
        }
        if let path = ancientPath, !path.isEmpty {
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            if name.lowercased().contains("usr1") { return ("USR1", "USR1 · Upward Sun River (AK)") }
            return (name, name)
        }
        return ("UNKNOWN_REMAINS", "UNKNOWN remains — pair \(pair)")
    }

    private static func nextFromHardDrive() -> [String: Any]? {
        guard let data = try? Data(contentsOf: hologramURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let loci = obj["loci"] as? [[String: Any]] else { return nil }
        let pair = obj["pair"] as? String ?? "USR1_HARD_vs_KIT_LEFT"
        let ancientPath = obj["ancient_path"] as? String
        let remains = remainsFromPair(pair, ancientPath: ancientPath)
        let existing = Set(loadFuture().compactMap { $0["rsid"] as? String })
        for loc in loci {
            guard let status = loc["status"] as? String, status == "MATCH_LIT" else { continue }
            guard let rsid = loc["rsid"] as? String, !existing.contains(rsid) else { continue }
            guard let lit = loc["lit"] as? Bool, lit else { continue }
            let depth: String = {
                if let i = loc["ancient_depth"] as? Int { return String(i) }
                if let s = loc["ancient_depth"] as? String { return s }
                return ""
            }()
            let posVal: Any = {
                if let i = loc["pos"] as? Int { return i }
                if let s = loc["pos"] as? String { return s }
                return ""
            }()
            let light: [String: Any] = [
                "rsid": rsid,
                "chrom": loc["chrom"] as? String ?? "",
                "pos": posVal,
                "kit_allele": loc["kit_allele"] as? String ?? "",
                "ancient_allele": loc["ancient_allele"] as? String ?? "",
                "ancient_depth": depth,
                "pin": loc["pin"] as? Int ?? 0,
                "status": "MATCH_LIT",
                "pair": pair,
                "pole": "FUTURE",
                "contrast_axis": "MID_vs_KIT",
                "source": "Documents/ЯBOT/lab/scaffolds/scout/HOLOGRAM-LOCI-680.json",
                "source_remains": remains.id,
                "source_remains_label": remains.label,
                "source_remains_path": ancientPath ?? "",
                "source_remains_line": "SOURCE REMAINS: \(remains.label) · pair \(pair) · path \(ancientPath ?? "—")",
                "ts": ISO8601DateFormatter().string(from: Date())
            ]
            return light
        }
        return nil
    }

    private static func format(_ light: [String: Any]) -> String {
        let rsid = light["rsid"] as? String ?? "?"
        let chrom = light["chrom"] as? String ?? "?"
        let pos = light["pos"] ?? "?"
        let kit = light["kit_allele"] as? String ?? "?"
        let anc = light["ancient_allele"] as? String ?? "?"
        let pin = light["pin"] as? Int ?? 0
        return "LIGHT pin #\(pin) · \(rsid) · \(chrom):\(pos) · kit \(kit) · ancient \(anc) · MATCH_LIT → FUTURE board"
    }

    private static func sourceRemainsLine(_ light: [String: Any]) -> String {
        if let line = light["source_remains_line"] as? String, !line.isEmpty { return line }
        let id = light["source_remains"] as? String ?? "?"
        let label = light["source_remains_label"] as? String ?? id
        let pair = light["pair"] as? String ?? "?"
        return "SOURCE REMAINS: \(label) · pair \(pair)"
    }

    private static func lightNoteOnline(rsid: String, clip: String) {
        let url = docs.appendingPathComponent("ЯBOT/lab/scaffolds/poles/FUTURE-LIGHT-\(rsid)-ONLINE.txt")
        try? clip.write(to: url, atomically: true, encoding: .utf8)
    }
}
