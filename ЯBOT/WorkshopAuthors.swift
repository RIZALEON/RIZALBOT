import Foundation

/// GAMEWRITE AUTHORS — which of Я's bots may draft game code into the GAME BUILDERS WORKSHOP.
/// Names, faces and aliases come ONLY from the Garage roster (BotLabel.roster · seat/BOT-LABELS.json v3) —
/// the same designated names the bots speak with in chat (naming law 2026-09-24 17:12 MDT).
/// <workshop>/authors.json (v2) only says WHICH roster bots have gamewrite and who drafts by default:
///   {"schema":"WorkshopAuthors.v2","gamewrite":["yabot","yamax"],"defaultAuthor":"yabot"}
/// Edit it without a rebuild. Unknown names (e.g. "garage") are refused — never silently re-assigned.
enum WorkshopAuthors {
    static let fileName = "authors.json"
    static let schema = "WorkshopAuthors.v2"

    /// View model for a gamewrite author (built from a roster bot).
    struct Author: Identifiable, Equatable {
        var id: String
        var display: String      // = the bot's Garage name, verbatim
        var face: String?
        var look: String?
        var aliases: [String]
    }

    struct Config: Codable {
        var schema: String
        var note: String?
        var defaultAuthor: String?
        var gamewrite: [String]?
    }

    /// v1 files (2026-09-24 15:37) listed full author objects; only their ids are kept now.
    private struct LegacyV1: Codable {
        struct A: Codable { var id: String; var gamewrite: Bool? }
        var authors: [A]?
        var defaultAuthor: String?
    }

    static let defaults = Config(
        schema: schema,
        note: "Which Garage-roster bots have gamewrite (ids from seat/BOT-LABELS.json roster). Names and faces come from the Garage roster only. Edit freely; no rebuild.",
        defaultAuthor: "yabot",
        gamewrite: ["yabot", "yamax"])

    static var url: URL { GameWorkshop.root.appendingPathComponent(fileName) }

    private static func write(_ cfg: Config) {
        try? FileManager.default.createDirectory(at: GameWorkshop.root, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? enc.encode(cfg) { try? data.write(to: url, options: .atomic) }
    }

    /// Write authors.json once; migrate a v1 file to v2 (keeps its ids + default).
    static func ensureSeated() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { write(defaults); return }
        guard let data = try? Data(contentsOf: url) else { return }
        if let cfg = try? JSONDecoder().decode(Config.self, from: data), cfg.schema == schema { return }
        if let v1 = try? JSONDecoder().decode(LegacyV1.self, from: data), let a = v1.authors, !a.isEmpty {
            let ids = a.filter { $0.gamewrite != false }.map(\.id)
            write(Config(schema: schema, note: defaults.note, defaultAuthor: v1.defaultAuthor ?? defaults.defaultAuthor,
                         gamewrite: ids.isEmpty ? defaults.gamewrite : ids))
        }
    }

    static func load() -> Config {
        ensureSeated()
        guard let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return defaults }
        return cfg
    }

    private static func author(_ b: BotLabel.RosterBot) -> Author {
        Author(id: b.id, display: b.name, face: b.face, look: b.look,
               aliases: [b.id, b.name] + (b.aliases ?? []) + (b.formerNames ?? []))
    }

    /// Roster bots that have gamewrite now (order = roster order).
    static var all: [Author] {
        let ids = Set((load().gamewrite ?? []).map { BotLabel.normalizeKey($0) })
        return BotLabel.roster.filter { ids.contains(BotLabel.normalizeKey($0.id)) }.map(author)
    }

    /// Default author; nil if no roster bot has gamewrite.
    static var defaultAuthor: Author? {
        let list = all
        if let want = load().defaultAuthor.map(BotLabel.normalizeKey),
           let hit = list.first(where: { BotLabel.normalizeKey($0.id) == want || BotLabel.normalizeKey($0.display) == want }) { return hit }
        return list.first
    }

    /// "yamax" / "Яmax" / "ЯMAX" → ЯMAX. Empty → default author. Unknown or not-gamewrite → nil (refused).
    static func resolve(_ raw: String) -> Author? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return defaultAuthor }
        guard let bot = BotLabel.rosterBot(named: t) else { return nil }
        return all.first { $0.id == bot.id }
    }

    /// Why `raw` cannot draft (for the refusal message).
    static func refusal(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bot = BotLabel.rosterBot(named: t) {
            return "\(bot.name) is in the Garage but has no gamewrite (authors.json). Gamewrite authors: \(namesLine())."
        }
        if BotLabel.normalizeKey(t) == "garage" {
            return "'garage' is the Garage (the workshop / bot builder), not a bot. Gamewrite authors: \(namesLine())."
        }
        return "'\(t)' is not a bot in the Garage roster. Gamewrite authors: \(namesLine())."
    }

    /// Lookup for display (any roster bot, incl. former names) so old drafts still show a face.
    static func lookup(_ display: String) -> Author? {
        BotLabel.rosterBot(named: display).map(author)
    }

    /// "ЯBOT · ЯMAX"
    static func namesLine() -> String {
        let a = all
        return a.isEmpty ? "(none — set gamewrite ids in authors.json)" : a.map(\.display).joined(separator: " · ")
    }

    /// Every word that names a roster bot (for `as <name>` parsing).
    static func aliasWords() -> [String] {
        BotLabel.roster.flatMap { [$0.id, $0.name] + ($0.aliases ?? []) + ($0.formerNames ?? []) }
    }
}
