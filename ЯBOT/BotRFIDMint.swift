import Foundation

/// Patented RFID mint for Lab bots — every bot gets a unique RFID-class tag
/// so Ghost chain + YaToken can distinguish which bot did what.
/// All new bots mint the same way.
enum BotRFIDMint {
    static let schema = "BotRFIDRegistry.v1"
    static let patentClaim = "CLAY-PATENT-RFID-BOT-ATTRIBUTION-v1"
    static let patentTitle = "RFID-class bot attribution mint for Lab scouts and companions"

    struct BotRecord: Codable, Equatable {
        var callsign: String
        var babyId: String
        var rfid: String
        var neo: String
        var kind: String
        var mintTrace: String
        var mintedAt: String
        var patentClaim: String
        var status: String

        enum CodingKeys: String, CodingKey {
            case callsign, rfid, neo, kind, status
            case babyId = "baby_id"
            case mintTrace = "mint_trace"
            case mintedAt = "minted_at"
            case patentClaim = "patent_claim"
        }
    }

    private static var registryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/ЯBOT/lab/rooms/BOT-RFID-REGISTRY.json")
    }

    /// Scout .01 — first patented scout RFID (hardcoded seat).
    static let scout01RFID = "RFID-YA-SCOUT-01"
    static let scout01Callsign = "Scout .01"
    static let scout01BabyId = "NEO-BABY-SCOUT-001"
    static let scout01Neo = "NEO-FUSE-001"

    /// Ensure Scout .01 patented RFID is minted + registered (idempotent).
    @discardableResult
    static func ensureScout01Minted() -> String {
        if let existing = find(callsign: scout01Callsign) ?? find(rfid: scout01RFID) {
            return "Scout .01 RFID already patented-minted · \(existing.rfid) · claim \(existing.patentClaim)"
        }
        return mintBot(
            callsign: scout01Callsign,
            babyId: scout01BabyId,
            kind: "scout",
            neo: scout01Neo,
            preferredRFID: scout01RFID
        )
    }

    /// Mint a patented RFID for any new bot — same path for all future bots.
    @discardableResult
    static func mintBot(
        callsign: String,
        babyId: String = "",
        kind: String = "bot",
        neo: String = "",
        preferredRFID: String? = nil
    ) -> String {
        _ = YaToken.ensureGenesisMinted()
        var reg = loadRegistry()
        let serial = reg.nextSerial
        let rfid: String
        if let pref = preferredRFID, !pref.isEmpty {
            rfid = pref
        } else if kind.lowercased() == "scout" {
            rfid = String(format: "RFID-YA-SCOUT-%02d", serial)
        } else {
            rfid = String(format: "RFID-YA-BOT-%03d", serial)
        }
        if reg.bots.contains(where: { $0.rfid == rfid || $0.callsign == callsign }) {
            return "Bot RFID already seated for \(callsign)"
        }
        let trace = UUID().uuidString
        let stamp = ISO8601DateFormatter().string(from: Date())
        let bid = babyId.isEmpty ? "BOT-\(serial)" : babyId
        let neoId = neo.isEmpty ? "NEO-FUSE-\(String(format: "%03d", serial))" : neo
        let rec = BotRecord(
            callsign: callsign,
            babyId: bid,
            rfid: rfid,
            neo: neoId,
            kind: kind,
            mintTrace: trace,
            mintedAt: stamp,
            patentClaim: patentClaim,
            status: "ACTIVE"
        )
        reg.bots.append(rec)
        reg.nextSerial = serial + 1
        saveRegistry(reg)

        // YaToken RFID-class UNIT mint (offline original)
        let unitNote = "PATENT MINT · \(callsign) · \(patentClaim) · bot attribution"
        _ = YaToken.mintUnit(brief: unitNote, utility: "bot_attribution")

        // Ghost chain — patent mint attribution
        _ = GhostChainLedger.append(
            op: "mint_bot_rfid",
            bio: bid,
            source: "bot-rfid-mint",
            extra: [
                "callsign": callsign,
                "rfid": rfid,
                "neo": neoId,
                "patent_claim": patentClaim,
                "patent_title": patentTitle,
                "mint_trace": trace,
                "kind": kind,
            ]
        )
        return """
        Patented RFID minted for \(callsign).
        rfid=\(rfid)
        neo=\(neoId)
        patent=\(patentClaim)
        trace=\(trace)
        law=Every bot · unique RFID · Ghost distinguishes who did what
        """
    }

    static func find(callsign: String) -> BotRecord? {
        loadRegistry().bots.first { $0.callsign.lowercased() == callsign.lowercased() }
    }

    static func find(rfid: String) -> BotRecord? {
        loadRegistry().bots.first { $0.rfid == rfid }
    }

    static func status() -> String {
        _ = ensureScout01Minted()
        let reg = loadRegistry()
        var lines = [
            "BOT RFID REGISTRY · patent \(patentClaim)",
            "bots \(reg.bots.count) · next_serial \(reg.nextSerial)",
        ]
        for b in reg.bots {
            lines.append("  \(b.callsign) · \(b.rfid) · \(b.kind) · \(b.status)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Registry IO

    private struct RegistryFile: Codable {
        var schema: String
        var patentClaim: String
        var bots: [BotRecord]
        var nextSerial: Int
        var ts: String

        enum CodingKeys: String, CodingKey {
            case schema, bots, ts
            case patentClaim = "patent_claim"
            case nextSerial = "next_serial"
        }
    }

    private static func loadRegistry() -> RegistryFile {
        let urls = [
            registryURL,
            URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/lab/rooms/BOT-RFID-REGISTRY.json"),
        ]
        for url in urls {
            if let data = try? Data(contentsOf: url),
               let reg = try? JSONDecoder().decode(RegistryFile.self, from: data) {
                return reg
            }
        }
        return RegistryFile(
            schema: schema,
            patentClaim: patentClaim,
            bots: [],
            nextSerial: 1,
            ts: ISO8601DateFormatter().string(from: Date())
        )
    }

    private static func saveRegistry(_ reg: RegistryFile) {
        var out = reg
        out.ts = ISO8601DateFormatter().string(from: Date())
        out.schema = schema
        out.patentClaim = patentClaim
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(out) else { return }
        try? FileManager.default.createDirectory(
            at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: registryURL, options: .atomic)
        let twin = URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/lab/rooms/BOT-RFID-REGISTRY.json")
        try? data.write(to: twin, options: .atomic)
    }
}
