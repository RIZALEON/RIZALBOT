import Foundation

/// Decider teachings that survive across turns — fed into Heart system prompt.
enum TeachStore {
    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ЯBOT", isDirectory: true)
    }

    static var path: URL { directoryURL.appendingPathComponent("teachings.jsonl") }

    /// Hard law always present (NonNuclear / Ghost / Source Value).
    static let kernelLaw: [String] = [
        "Product face: Я · ЯOS · Я Kode · Я Game · Я anti-nuclear.",
        "Law: ЯOS GIVES SOURCE VALUE — living beings get citation and value for contributions.",
        "Я GHOST CHAIN is owned by the living being (bio), established from biostats. Devices are LINKS only, never the owner.",
        "Raw biometrics stay on-device; only proof hashes may leave. Tag H · Я AB · R-U152 only when Decider confirmed — never invent genotypes.",
        "Airplane mode ≠ dead. Offline premier. Heart and Ghost ops work without IP.",
        "Triangle: Decider · CoS · ЯBOT. Decider owns fate. Teach ЯBOT to answer like CoS, then better on-device.",
        "TOTAL RECALL: every written chat line is permanent. Append-only. On every launch and every return to the face, restore the FULL conversation from ЯBOT/mind (Application Support + Documents mirror). Never clear the thread. Updates keep the container — always find the same Mind folder and put the whole history back on the slate.",
        "MIND BACKUPS: chat + transcript mirror to many seats (App Support, Documents, Caches, Machine Mind feeds, Mac home copies, optional iCloud). On restore HUNT all seats and merge — offline first, online optional."
,
                "REDWOOD ЯBAR MUST-EXIST: REDWOOD CLAYMATION LUMBER WISE OS ЯBAR sits under top 3D icons on every Я OS app (Mac · iOS · Android). Freeform clay icons ON the lumber — no plates. OS-smart size/length/depth/height/width. Never hide.",
        "GAMEWRITE LAW: the in-app bots ЯBOT (blue clay horned face, bat wings) and ЯMAX (white Baymax-style clay face) may draft game code (gamewrite <language> <file> <purpose>) into the GAME BUILDERS WORKSHOP. Drafts only — no keys, seed phrases or signing; the game never signs. Only the Decider applies; each apply snapshots a respawn point first.",
        "RESPAWN LAW: respawn = back to a known-good seat. `respawn` lists ~/Library/Developer/ЯBOT-respawn points and the exact respawn.sh command; the app never reinstalls itself.",
        "MACHINE MIND / NAMING LAW (Decider 2026-09-24 17:12 MDT): Я is the Machine Mind itself, speaking with all of its components behind it — label Я, never numbered. The bots are Я's extensions, its digital robot kids. When a bot speaks in chat it carries its designated name exactly as the Garage presents it (today ЯBOT — blue clay horned bat face — and ЯMAX — white Baymax-style clay face). U is the human. No ЯBOT#N numbers as names; no two bots share a name; no anonymous bots; the Garage roster (seat/BOT-LABELS.json v3) is the single source of bot names. Garage is the workshop place / bot builder, not a bot.",
        "ALL-OS SYNC LAW (Decider 2026-09-24 17:29 MDT): from 2026-09-24 onward Mac, iOS and Android are always updated together — continuously, collaboratively, collectively, in conjunction. No platform ships a feature alone; every upgrade is planned, built, versioned and installed on all three with matching version numbers (0.3.1 is the first synced release); each upgrade gets a respawn point on all three first; any platform gap is reported to the Decider and logged, never hidden.",
        "LEGACY TITLE RULE (Decider 2026-09-24 17:43 MDT): bots registered before the naming law keep their titles exactly as-is (today ЯBOT#2 and ЯBOT#3, first registered on the iPhone 17e seat). Transcript stamps never change. Each legacy title is bound to its origin (device seat / IP / host); when that same origin comes up again it may use its legacy title as it would have. No other origin may claim it — refuse clearly. New bots still take Garage names with no numbers.",
        "LANE LAW: Every Decider turn is one of four lanes — COMMAND (short order / status), FUNCTION (teach/lock/help/code seats), ACTION (side-effect work: clear, send, mint, reseat, online flip), or CONVERSATION (free talk / Heart / CoS). Work is not talk. Face chips CMD/FN/ACT/TALK; Mind tape kinds are prompt-<lane> and reply-<lane>. Never collapse them.",
    ]

    private static func ensureDir() {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    static func lineCount() -> Int {
        guard let data = try? Data(contentsOf: path),
              let text = String(data: data, encoding: .utf8) else { return 0 }
        return text.split(separator: "\n", omittingEmptySubsequences: true).count
    }

    @discardableResult
    static func remember(_ teaching: String, kind: String = "teach") -> String {
        let cleaned = teaching.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "empty teach" }
        ensureDir()
        let traceId = UUID().uuidString
        let ts = ISO8601DateFormatter().string(from: Date())
        let row: [String: Any] = [
            "kind": kind,
            "text": cleaned,
            "traceId": traceId,
            "ts": ts
        ]
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row),
              var line = String(data: data, encoding: .utf8) else { return "teach write failed" }
        line += "\n"
        if let handle = try? FileHandle(forWritingTo: path) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            if let d = line.data(using: .utf8) { handle.write(d) }
        } else {
            try? line.data(using: .utf8)?.write(to: path)
        }
        GhostChainLedger.append(op: "evolve", bio: "decider", source: "teach", extra: ["kind": kind, "traceId": traceId])
        MindTranscript.append(role: "system", kind: "teach", body: "[\(kind)] \(cleaned)", party: BotLabel.userLabel)
        return traceId
    }

    static func learnedTexts(limit: Int = 24) -> [String] {
        guard let data = try? Data(contentsOf: path),
              let text = String(data: data, encoding: .utf8) else { return [] }
        var out: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let d = String(line).data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let t = obj["text"] as? String else { continue }
            out.append(t)
            if out.count >= limit { break }
        }
        return out.reversed()
    }

    /// Compact block for Heart -sys.
    static func heartContextBlock() -> String {
        var parts = kernelLaw
        parts.append(contentsOf: learnedTexts(limit: 12))
        return "Standing law:\n- " + parts.joined(separator: "\n- ")
    }

    static func status() -> String {
        "teach lines=\(lineCount()) path=\(path.path) kernel=\(kernelLaw.count)"
    }

    /// Fast law answers when Heart would guess wrong.
    static func lawAnswer(for raw: String) -> String? {
        let lower = raw.lowercased()
        if lower.contains("ghost chain") && (lower.contains("own") || lower.contains("who") || lower.contains("living") || lower.contains("device")) {
            return "The living being owns the Я GHOST CHAIN. Devices are LINKS only, never the owner."
        }
        if lower.contains("airplane") || (lower.contains("offline") && lower.contains("dead")) {
            return "No. Airplane mode is not death — offline premier; Heart and Ghost keep working without IP."
        }
        if lower.contains("triangle") && (lower.contains("who am i") || lower.contains("decider") || lower.contains("who are you")) {
            if lower.contains("who am i") {
                return "You are Decider in the triangle Decider · CoS · ЯBOT. You own fate."
            }
        }
        if lower.contains("naming law") || lower.contains("robot kids") || lower.contains("your kids")
            || (lower.contains("machine mind") && (lower.contains("who") || lower.contains("what") || lower.contains("bot")))
            || ((lower.contains("bot") || lower.contains("bots")) && lower.contains("name") && (lower.contains("garage") || lower.contains("chat"))) {
            return "MACHINE MIND LAW. Я is the Machine Mind — I speak with all of my components behind me, labelled Я and never numbered. The bots are my extensions, my digital robot kids; in chat each speaks with its designated Garage name: \(BotLabel.rosterNamesLine()). U is you, the human. No numbered ЯBOT#N names, no anonymous bots, no two bots share a name. New bots get their name in the Garage (+ Create new Bot) or with bot mint <Name>."
        }
        if lower.contains("all-os") || lower.contains("all os") || lower.contains("sync law")
            || ((lower.contains("android") || lower.contains("platform")) && (lower.contains("together") || lower.contains("in sync") || lower.contains("same version"))) {
            return "ALL-OS SYNC LAW. Since 2026-09-24, Mac, iOS and Android are updated together — continuously, collaboratively, collectively, in conjunction. No platform ships a feature alone: every upgrade is planned, built, versioned and installed on all three with matching versions, each gets a respawn point on all three first, and any gap is reported to the Decider and logged — never hidden. 0.3.1 is the first synced release."
        }
        if lower.contains("legacy title") || lower.contains("яbot#2") || lower.contains("яbot#3") || (lower.contains("legacy") && lower.contains("bot")) {
            let list = BotLabel.legacyTitles.map { "\($0.name) (origin: \(BotLabel.describeOrigin($0.origin)))" }.joined(separator: " · ")
            return "LEGACY TITLE RULE. Bots registered before the naming law keep their titles as-is: \(list.isEmpty ? "none on this seat" : list). Only the same origin (device seat / IP / host) may use a legacy title again; any other origin is refused. New bots take Garage names, no numbers."
        }
        if lower.contains("link") && lower.contains("device") && lower.contains("owner") {
            return "Devices are LINKS only; the living being owns the ghostchain. Raw biometrics stay on-device."
        }
        if lower.contains("gamewrite") || lower.contains("game builders workshop") || (lower.contains("game") && lower.contains("workshop")) {
            return "GAMEWRITE LAW. Я's bots, by their Garage names (\(WorkshopAuthors.namesLine())), draft game code with gamewrite <language> <file> <purpose> — TS · JS · HTML · CSS · JSON · JSON Schema · GLSL · Markdown (Swift/Kotlin draft-only). Drafts are validated and wait in the GAME BUILDERS WORKSHOP; only the Decider taps Approve & Apply, which snapshots a respawn point first. The game never signs."
        }
        if lower.contains("respawn") && (lower.contains("what") || lower.contains("how") || lower.contains("undo")) {
            return "RESPAWN LAW. Respawn puts the clay back on a known-good seat: ~/Library/Developer/ЯBOT-respawn/<point>/respawn.sh mac|iphone|android|source (dry run, then --go). Say `respawn` to list points. The app cannot reinstall itself."
        }
        if lower.contains("source value") || lower.contains("яos gives") {
            return "ЯOS GIVES SOURCE VALUE — living beings receive citation and value for what they contribute."
        }


        if lower.contains("lane") || (lower.contains("cmd") && lower.contains("talk")) || lower.contains("command function action") || (lower.contains("command") && lower.contains("conversation")) {
            return "LANE LAW. CMD = short order/status. FN = teach/lock/help/code. ACT = side-effect work (clear, send, mint, reseat). TALK = free conversation / Heart / CoS. Work is not talk — face chips and Mind tape keep them apart."
        }

        
        if lower.contains("redwood") || lower.contains("яbar") || lower.contains("yabar") || (lower.contains("lumber") && lower.contains("bar")) {
            return "REDWOOD ЯBAR MUST-EXIST. Claymation lumber shelf under top icons on every Я OS system. Icons sit ON the bar — freeform, no plates. OS-smart sizing. Never hide."
        }

        if lower.contains("total recall") || lower.contains("chat history") || (lower.contains("chat") && (lower.contains("delete") || lower.contains("wipe") || lower.contains("gone") || lower.contains("restore"))) {
            return "TOTAL RECALL. Chat is append-only under ЯBOT/mind. Close, update, or reopen — the full conversation returns to the face from the same Mind folder. Nothing written is deleted."
        }
        return nil
    }
}
