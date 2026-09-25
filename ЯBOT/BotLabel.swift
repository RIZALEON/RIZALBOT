import Foundation
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import IOKit
#endif

/// Durable seat labels for chat face + MIND-TRANSCRIPT party.
/// NAMING LAW (Decider 2026-09-24 17:12 MDT — supersedes the 2026-09-23 ЯBOT#N scheme):
///   "no if the speak in the name chat give them thier designated names as seen and presented in the garage,
///    the Я is the machine mind speaking with all of its components behind it, the bots are like extensions
///    of it or its digital robot kids"
///   U   = biological source (human) — stamped on user prompts forever
///   Я   = the MACHINE MIND itself, speaking with all of its components behind it — immutable, NEVER numbered
///   Bots = Я's extensions / digital robot kids. When a bot speaks in chat its label is its DESIGNATED NAME
///          exactly as the Garage presents it (spelling, casing, the Я glyph, face). Today: ЯBOT · ЯMAX.
///   The GARAGE ROSTER (BOT-LABELS.json v3 → `roster`) is the single source of bot names: chat stamps,
///   the Garage shelf/list, and gamewrite authors all read it. No ЯBOT#N numbers are shown as names.
///   New bots take the name given in the Garage (+ Create new Bot) or `bot mint <Name>`; an internal
///   serial is kept only for uniqueness/audit and is NEVER displayed.
///   Uniqueness: no two bots share a name (names, aliases and former names are all checked);
///   no anonymous bots; reserved names Я / U / system (and clay / user / human) are refused.
///   Garage is the workshop place / bot builder, not a chat name — unless the roster itself lists a bot called Garage.
/// Labels already stamped onto a ChatMessage never change when the roster renames later.
///
/// LEGACY TITLE RULE (Decider 2026-09-24 17:43 MDT, verbatim):
///   "keep them as is in the transcript if that same IP or device comes up let them use that title as they would"
///   Bots registered BEFORE the naming law (e.g. ЯBOT#2 · ЯBOT#3 on the iPhone 17e seat) keep their titles exactly
///   as-is: roster entries with `legacy: true`, never renamed, never retired, transcript stamps untouched.
///   Each legacy title is bound to its ORIGIN (`origin`: device seat · IP · host · link sender · channel).
///   A joiner whose origin matches may use — and is auto-labelled with — its legacy title as it would have before,
///   even though it is ЯBOT#N-style. Any other origin is REFUSED with a clear message. New bots still follow the
///   naming law (Garage names, no numbers). Serials are unique and never reused (internal only).
///   Spec shared with Android: mind/reports/2026-09-24/LEGACY-TITLE-RULE-SPEC.md
enum BotLabel {
    static let schema = "BotLabels.v3"
    static let claySeatDefault = "Я"
    static let userSeatDefault = "U"
    /// Retired display scheme (2026-09-23). Kept only to recognise old stamps / refuse new numbered names.
    static let legacyCreatedPrefix = "ЯBOT#"

    /// One bot in the Garage roster. `name` is the designated Garage name = the chat label, verbatim.
    struct RosterBot: Codable, Equatable, Identifiable {
        var id: String               // stable ascii key (yabot · yamax · …)
        var name: String             // designated name exactly as the Garage presents it
        var face: String?            // asset name (BotFaceYaBot) or image file in the workshop folder
        var look: String?            // how the face looks
        var aliases: [String]?       // other words that resolve to this bot (yamax, ямакс, …)
        var formerNames: [String]?   // earlier Garage labels (still resolve; never re-used by another bot)
        var housed: Bool?            // shown in Garage → Housed bots
        var shelf: String?           // shelf spot in the Garage room image: left · right
        var serial: Int?             // internal uniqueness/audit only — NEVER displayed
        var createdAt: String?
        var legacy: Bool? = nil      // registered before the naming law — title kept as-is, bound to `origin`
        var origin: Origin? = nil    // who first registered this title (legacy binding)
        var boundAt: String? = nil   // when `origin` was bound to a concrete device seat
    }

    /// Where a legacy title came from. Every field optional; match rules in `legacyMatch`.
    struct Origin: Codable, Equatable {
        var platform: String? = nil     // ios · macos · android
        var hwModel: String? = nil      // hw.machine / hw.model, e.g. iPhone18,5
        var deviceName: String? = nil   // human label, e.g. iPhone 17e "rizal’s iPhone" (display only)
        var udid: String? = nil         // device UDID as seen by devicectl (display/audit only; the app cannot read it)
        var seatId: String? = nil       // in-app device seat id: <platform>-<sha256(IDFV | IOPlatformUUID | ANDROID_ID)[0..16]>
        var ip: String? = nil           // IP the joiner came from, when known
        var host: String? = nil         // host / link host, when known
        var linkSender: String? = nil   // who sent the join (link `from=` / `sender=`, CoS, Rizalbot …) — audit
        var channel: String? = nil      // composer · open-url · inbox · unknown
        var firstSeenAt: String? = nil  // first time the title was used (UTC ISO-8601)
        var evidence: String? = nil     // where the origin was established
    }

    /// Who is joining right now (computed on this device; link fields filled by GrokYabotLink).
    struct JoinerOrigin {
        var platform: String
        var hwModel: String?
        var seatId: String?
        var ip: String? = nil
        var host: String? = nil
        var linkSender: String? = nil
        var channel: String = "chat"

        static func local(channel: String = "chat") -> JoinerOrigin {
            JoinerOrigin(platform: BotLabel.currentPlatform, hwModel: BotLabel.currentHwModel,
                         seatId: BotLabel.currentSeatId, channel: channel)
        }

        static func link(host: String?, sender: String?, ip: String? = nil) -> JoinerOrigin {
            var j = local(channel: "open-url")
            j.host = (host?.isEmpty == false) ? host : nil
            j.linkSender = (sender?.isEmpty == false) ? sender : nil
            j.ip = (ip?.isEmpty == false) ? ip : nil
            return j
        }
    }

    /// Origins established for titles registered before the naming law (so every seat holds the same record).
    /// Evidence: phone MIND-TRANSCRIPT + CHAT-THREAD (pulled 2026-09-24 17:43 MDT) and the Mac smoke note
    /// ~/Documents/ЯBOT/status/BOT-LABELS-SEAT-20260923.txt.
    static let legacyOriginHints: [String: Origin] = [
        "яbot#2": Origin(platform: "ios", hwModel: "iPhone18,5", deviceName: "iPhone 17e (rizal’s iPhone)",
                         udid: "00008150-000238413E7A401C", seatId: nil, ip: nil, host: nil,
                         linkSender: "Rizalbot device smoke from Mac rizals-MacBook-Neo (machine 55d92eb0-0ce0-4959-b297-440d80e59e38) over USB/CoreDevice",
                         channel: "inject (open-url/inbox; exact channel not recorded)",
                         firstSeenAt: "2026-09-23T22:52:44Z",
                         evidence: "phone MIND-TRANSCRIPT 2026-09-23T22:52:44Z U 'bot enter ЯBOT#2' · follow-ups every ~2 s (scripted) · Mac note BOT-LABELS-SEAT-20260923.txt '#2 from prior enter'"),
        "яbot#3": Origin(platform: "ios", hwModel: "iPhone18,5", deviceName: "iPhone 17e (rizal’s iPhone)",
                         udid: "00008150-000238413E7A401C", seatId: nil, ip: nil, host: nil,
                         linkSender: "Rizalbot device smoke from Mac rizals-MacBook-Neo (machine 55d92eb0-0ce0-4959-b297-440d80e59e38) over USB/CoreDevice",
                         channel: "open-url yabot://chat?text=bot%20mint",
                         firstSeenAt: "2026-09-23T22:54:33Z",
                         evidence: "phone MIND-TRANSCRIPT 2026-09-23T22:54:33Z bot-mint → ЯBOT#3 · Mac note BOT-LABELS-SEAT-20260923.txt 'Inject: yabot://chat?text=bot%20mint → Minted ЯBOT#3'"),
    ]

    /// Roster the Garage housed on 2026-09-24 (seeded once into BOT-LABELS.json v3; then the file rules).
    /// The blue horned bat was labelled "Scout" in the Garage code until 0.3.0; the Decider's picture names it ЯBOT.
    static let seedRoster: [RosterBot] = [
        RosterBot(id: "yabot", name: "ЯBOT", face: "BotFaceYaBot",
                  look: "blue clay face · red horns · black bat wings",
                  aliases: ["yabot", "ябот", "rbot", "я bot"], formerNames: ["Scout"],
                  housed: true, shelf: "left", serial: 1, createdAt: "2026-09-24T23:20:00Z"),
        RosterBot(id: "yamax", name: "ЯMAX", face: "BotFaceYaMax",
                  look: "white Baymax-style clay face · shelf companion",
                  aliases: ["yamax", "ямакс", "rmax", "я max"], formerNames: [],
                  housed: true, shelf: "right", serial: 2, createdAt: "2026-09-24T23:20:00Z"),
    ]

    struct Store: Codable, Equatable {
        var schema: String
        /// Always "Я" — the Machine Mind. Persisted for audit; API ignores renames.
        var claySeatLabel: String
        /// Mirror: normalized name → display name (kept so v2 readers still see the names).
        var bots: [String: String]
        /// Active bot speaking for assistant turns until `bot leave` (its exact Garage name).
        var currentGuestLabel: String?
        /// Internal serial for uniqueness only (never displayed).
        var nextCreatedSerial: Int
        var updatedAt: String
        /// The Garage roster — single source of bot names.
        var roster: [RosterBot]
        /// True once the seed roster was written (so deleting bots in the file is respected).
        var rosterSeeded: Bool

        enum CodingKeys: String, CodingKey {
            case schema, claySeatLabel, bots, currentGuestLabel, nextCreatedSerial, updatedAt, roster, rosterSeeded
        }

        init(schema: String, claySeatLabel: String, bots: [String: String], currentGuestLabel: String?,
             nextCreatedSerial: Int, updatedAt: String, roster: [RosterBot] = [], rosterSeeded: Bool = false) {
            self.schema = schema
            self.claySeatLabel = claySeatLabel
            self.bots = bots
            self.currentGuestLabel = currentGuestLabel
            self.nextCreatedSerial = nextCreatedSerial
            self.updatedAt = updatedAt
            self.roster = roster
            self.rosterSeeded = rosterSeeded
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schema = try c.decodeIfPresent(String.self, forKey: .schema) ?? BotLabel.schema
            claySeatLabel = try c.decodeIfPresent(String.self, forKey: .claySeatLabel) ?? BotLabel.claySeatDefault
            bots = try c.decodeIfPresent([String: String].self, forKey: .bots) ?? [:]
            currentGuestLabel = try c.decodeIfPresent(String.self, forKey: .currentGuestLabel)
            if let n = try c.decodeIfPresent(Int.self, forKey: .nextCreatedSerial) {
                nextCreatedSerial = max(1, n)
            } else {
                nextCreatedSerial = BotLabel.inferNextSerial(from: bots)
            }
            updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
            roster = (try? c.decodeIfPresent([RosterBot].self, forKey: .roster)) ?? []
            rosterSeeded = (try? c.decodeIfPresent(Bool.self, forKey: .rosterSeeded)) ?? false
        }
    }

    private static let lock = NSLock()
    private static var cached: Store?

    // MARK: - Paths (Documents seat + App Support mirror)

    private static var documentsSeatURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return base.appendingPathComponent("ЯBOT/seat/BOT-LABELS.json")
    }

    private static var appSupportSeatURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ЯBOT/seat/BOT-LABELS.json")
    }

    #if os(macOS)
    private static var homeDocumentsSeatURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/ЯBOT/seat/BOT-LABELS.json")
    }
    #endif

    private static var writeURLs: [URL] {
        var urls = [documentsSeatURL, appSupportSeatURL]
        #if os(macOS)
        urls.append(homeDocumentsSeatURL)
        #endif
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static var readURLs: [URL] { writeURLs }

    // MARK: - Public API

    /// Я — the Machine Mind itself (all components behind it). Never numbered, never renamed.
    static var clayLabel: String { claySeatDefault }
    static var machineMindLabel: String { claySeatDefault }

    /// Biological source — always U.
    static var userLabel: String { userSeatDefault }

    /// Bot currently speaking for assistant stamps, if any (its exact Garage name).
    static var activeGuestLabel: String? {
        let g = load().currentGuestLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let g, !g.isEmpty else { return nil }
        return g
    }

    /// The Garage roster (single source of bot names).
    static var roster: [RosterBot] { load().roster }

    /// Bots shown in Garage → Housed bots.
    static var housedBots: [RosterBot] { roster.filter { $0.housed != false && $0.legacy != true } }

    /// Titles registered before the naming law (kept as-is, bound to their origin).
    static var legacyTitles: [RosterBot] { roster.filter { $0.legacy == true } }

    /// Resolve any word the Decider might use (name · id · alias · former name) → roster bot. Case-insensitive.
    static func rosterBot(named raw: String) -> RosterBot? {
        let want = normalizeKey(raw)
        guard !want.isEmpty else { return nil }
        let r = roster
        if let hit = r.first(where: { $0.name == raw.trimmingCharacters(in: .whitespacesAndNewlines) }) { return hit }
        return r.first { b in
            normalizeKey(b.name) == want || normalizeKey(b.id) == want
                || (b.aliases ?? []).contains { normalizeKey($0) == want }
                || (b.formerNames ?? []).contains { normalizeKey($0) == want }
        }
    }

    /// Chat label for a bot key/name — its Garage name. Я / U for the seats.
    static func label(for botKey: String) -> String? {
        let key = normalizeKey(botKey)
        guard !key.isEmpty else { return nil }
        if key == "clay" || key == "я" || key == "ya" || key == "machine mind" { return clayLabel }
        if key == "u" || key == "user" || key == "human" { return userLabel }
        return rosterBot(named: botKey)?.name
    }

    /// Rename a roster bot (Decider). Future stamps use the new name; old stamps stay as they were.
    @discardableResult
    static func setLabel(botKey: String, label: String) -> String {
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizeKey(botKey).isEmpty, !name.isEmpty else { return "HOW: label bot <Name> (a name from the Garage roster)" }
        let key = normalizeKey(botKey)
        if key == "clay" || key == "я" || key == "ya" {
            return "Я is the Machine Mind — never renamed, never numbered."
        }
        guard let bot = rosterBot(named: botKey) else {
            return "REFUSED · '\(botKey)' is not in the Garage roster. Roster: \(rosterNamesLine())."
        }
        if bot.legacy == true {
            return "REFUSED · \(bot.name) is a legacy title (registered before the naming law). It is kept exactly as-is."
        }
        if let why = nameProblem(name, excludingId: bot.id) { return why }
        var s = load()
        guard let i = s.roster.firstIndex(where: { $0.id == bot.id }) else { return "REFUSED · roster changed; try again." }
        var former = s.roster[i].formerNames ?? []
        if !former.contains(s.roster[i].name) { former.append(s.roster[i].name) }
        s.roster[i].formerNames = former
        s.roster[i].name = name
        if s.currentGuestLabel == bot.name { s.currentGuestLabel = name }
        s.updatedAt = isoNow()
        save(s)
        return "Renamed in the Garage roster · \(bot.name) → \(name) (old chat stamps keep \(bot.name))."
    }

    /// Stamp source for a role — an entered bot overrides Я for assistant turns while active.
    static func resolveSpeaker(role: ChatMessage.Role) -> String {
        switch role {
        case .user:
            return userLabel
        case .assistant:
            return activeGuestLabel ?? clayLabel
        case .system:
            return "system"
        }
    }

    /// Garage → + Create new Bot (and `bot mint <Name>`). The given name is the designated name, verbatim.
    static func createBot(name raw: String, face: String? = nil, look: String? = nil, housed: Bool = true) -> (RosterBot?, String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || isBareBotToken(name) {
            return (nil, "REFUSED · no anonymous bots. Give it the name it will speak with (Garage → + Create new Bot, or: bot mint <Name>).")
        }
        if let why = nameProblem(name, excludingId: nil) { return (nil, why) }
        var s = load()
        let serial = max(1, s.nextCreatedSerial, (s.roster.compactMap(\.serial).max() ?? 0) + 1)
        var id = slug(name)
        if id.isEmpty { id = "bot\(serial)" }
        var n = 2
        let base = id
        while s.roster.contains(where: { $0.id == id }) { id = "\(base)\(n)"; n += 1 }
        let bot = RosterBot(id: id, name: name, face: face, look: look, aliases: [], formerNames: [],
                            housed: housed, shelf: nil, serial: serial, createdAt: isoNow())
        s.roster.append(bot)
        s.nextCreatedSerial = serial + 1
        s.updatedAt = isoNow()
        save(s)
        MindTranscript.append(role: "system", kind: "bot-create",
                              body: "Garage roster + \(name) — a new digital robot kid of Я (designated name, no number shown)",
                              party: "Rizalbot")
        return (bot, "Created in the Garage · \(name)\nIt speaks in chat as \(name). Я stays the Machine Mind.")
    }

    /// `bot mint` / `bot create` / `bot new` <Name> — create in the roster, then it speaks.
    @discardableResult
    static func mint(optionalName: String? = nil) -> String {
        let raw = optionalName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.isEmpty || isBareBotToken(raw) {
            return """
            REFUSED · no auto numbers and no anonymous bots (naming law 2026-09-24).
            Name the bot as the Garage will present it: bot mint <Name> — or Garage → + Create new Bot.
            Housed now: \(rosterNamesLine()).
            """
        }
        if let existing = rosterBot(named: raw) {
            return "'\(raw)' is already in the Garage as \(existing.name). To let it speak: bot enter \(existing.name)"
        }
        let (bot, msg) = createBot(name: raw)
        guard let bot else { return msg }
        var s = load()
        s.currentGuestLabel = bot.name
        s.updatedAt = isoNow()
        save(s)
        return msg + "\nAssistant stamps → \(bot.name) until `bot leave`."
    }

    /// `bot enter <Name>` — a roster bot speaks (stamped with its exact Garage name). Я / clay → Machine Mind again.
    /// Legacy titles (pre-law ЯBOT#N) only for a joiner from the SAME origin (device seat / IP / host) — Legacy Title Rule.
    @discardableResult
    static func enter(_ name: String, origin: JoinerOrigin? = nil) -> String {
        let joiner = origin ?? .local()
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || isBareBotToken(cleaned) {
            // Auto-label: a joiner from a legacy origin gets its legacy title as it would have before.
            let mine = legacyTitles.filter { legacyMatch($0.origin, joiner) }
            if mine.count == 1, let only = mine.first { return enterBot(only, joiner: joiner) }
            if mine.count > 1 {
                return "HOW: bot enter <Name> — this seat's legacy titles: \(mine.map(\.name).joined(separator: " · ")) · Garage bots: \(rosterNamesLine()). No anonymous bots."
            }
            return "HOW: bot enter <Name> — a bot from the Garage roster: \(rosterNamesLine()). No anonymous bots."
        }
        let lower = cleaned.lowercased()
        if cleaned == claySeatDefault || lower == "clay" || lower == "machine mind" {
            clearGuest()
            return "Я — the Machine Mind — speaks. Assistant stamps = Я."
        }
        if isReserved(cleaned) {
            return "REFUSED · '\(cleaned)' is reserved (U / Я / system). Bots speak with their Garage names: \(rosterNamesLine())."
        }
        guard let bot = rosterBot(named: cleaned) else {
            if parseCreatedSerial(cleaned) != nil {
                return "REFUSED · '\(cleaned)' is not a legacy title on this roster. Numbered names are retired (naming law 2026-09-24); only titles registered before the law are kept, each for its own origin. New bots take a Garage name: Garage → + Create new Bot, or bot mint <Name>."
            }
            return "REFUSED · '\(cleaned)' is not in the Garage roster (\(rosterNamesLine())). Create it first: Garage → + Create new Bot, or bot mint \(cleaned)."
        }
        return enterBot(bot, joiner: joiner)
    }

    private static func enterBot(_ bot: RosterBot, joiner: JoinerOrigin) -> String {
        if bot.legacy == true {
            guard legacyMatch(bot.origin, joiner) else { return legacyRefusal(bot) }
            bindLegacyIfNeeded(bot, joiner: joiner)
        }
        if activeGuestLabel == bot.name {
            return "Already speaking · \(bot.name)\nAssistant stamps → \(bot.name)."
        }
        var s = load()
        s.currentGuestLabel = bot.name
        s.claySeatLabel = claySeatDefault
        s.updatedAt = isoNow()
        save(s)
        let what = bot.legacy == true ? "legacy title (same origin)" : "Я's bot speaks"
        MindTranscript.append(role: "system", kind: "bot-enter",
                              body: "bot enter \(bot.name) — \(what); assistant stamps until bot leave · via \(joiner.channel)",
                              party: "Rizalbot")
        if bot.legacy == true {
            return "\(bot.name) speaks now — legacy title, same origin (kept as-is from before the naming law).\nAssistant stamps → \(bot.name) until `bot leave`."
        }
        return "\(bot.name) speaks now (one of Я's bots).\nAssistant stamps → \(bot.name) until `bot leave`."
    }

    // MARK: - Legacy Title Rule

    /// Same origin? device seat (bound) · or, while unbound, same platform + hardware model · or same IP · or same host.
    static func legacyMatch(_ origin: Origin?, _ j: JoinerOrigin) -> Bool {
        guard let o = origin else { return false }
        if let ip = o.ip, !ip.isEmpty, let jip = j.ip, jip == ip { return true }
        if let h = o.host, !h.isEmpty, let jh = j.host, normalizeKey(jh) == normalizeKey(h) { return true }
        if let sid = o.seatId, !sid.isEmpty { return j.seatId == sid }
        if let p = o.platform, !p.isEmpty, let m = o.hwModel, !m.isEmpty {
            return j.platform == p && j.hwModel == m
        }
        return false
    }

    /// Unbound origin matched by platform + hardware model → bind this device seat (trust on first use).
    private static func bindLegacyIfNeeded(_ bot: RosterBot, joiner: JoinerOrigin) {
        guard (bot.origin?.seatId ?? "").isEmpty, let sid = joiner.seatId else { return }
        var s = load()
        guard let i = s.roster.firstIndex(where: { $0.id == bot.id }) else { return }
        var o = s.roster[i].origin ?? Origin()
        o.seatId = sid
        s.roster[i].origin = o
        s.roster[i].boundAt = isoNow()
        s.updatedAt = isoNow()
        save(s)
    }

    static func describeOrigin(_ o: Origin?) -> String {
        guard let o else { return "origin unknown" }
        var parts: [String] = []
        if let d = o.deviceName, !d.isEmpty { parts.append(d) }
        if let u = o.udid, !u.isEmpty { parts.append("seat \(u)") }
        if let p = o.platform, !p.isEmpty { parts.append([p, o.hwModel ?? ""].filter { !$0.isEmpty }.joined(separator: " ")) }
        if let ip = o.ip, !ip.isEmpty { parts.append("IP \(ip)") }
        if let h = o.host, !h.isEmpty { parts.append("host \(h)") }
        if let c = o.channel, !c.isEmpty { parts.append("via \(c)") }
        return parts.isEmpty ? "origin unknown" : parts.joined(separator: " · ")
    }

    static func legacyRefusal(_ bot: RosterBot) -> String {
        "REFUSED · \(bot.name) is a legacy title (registered before the naming law), bound to its origin: \(describeOrigin(bot.origin)). This device/link is not that origin, so it cannot use the title. New bots take a Garage name: Garage → + Create new Bot, or bot mint <Name>."
    }

    // MARK: - This device (origin inputs)

    static var currentPlatform: String {
        #if os(iOS)
        return "ios"
        #elseif os(macOS)
        return "macos"
        #else
        return "other"
        #endif
    }

    static var currentHwModel: String? {
        #if os(macOS)
        return sysctlString("hw.model")
        #else
        return sysctlString("hw.machine")
        #endif
    }

    private static var cachedSeatId: String??
    /// `<platform>-<first 16 hex of sha256(vendor/hardware id)>` — raw ids are never stored.
    static var currentSeatId: String? {
        if let c = cachedSeatId { return c }
        var raw: String? = nil
        #if os(macOS)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if service != 0 {
            raw = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String
            IOObjectRelease(service)
        }
        #elseif canImport(UIKit)
        raw = UIDevice.current.identifierForVendor?.uuidString
        #endif
        let id: String? = raw.map { r in
            let d = SHA256.hash(data: Data(r.utf8))
            let hex = d.map { String(format: "%02x", $0) }.joined()
            return currentPlatform + "-" + String(hex.prefix(16))
        }
        cachedSeatId = .some(id)
        return id
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let v = String(decoding: bytes, as: UTF8.self)
        return v.isEmpty ? nil : v
    }

    /// `bot leave` / `label bot clear`
    @discardableResult
    static func leave() -> String {
        let was = activeGuestLabel
        clearGuest()
        MindTranscript.append(role: "system", kind: "bot-leave",
                              body: "bot leave — assistant stamps = Я (Machine Mind)", party: "Rizalbot")
        if let was { return "Left · \(was)\nЯ — the Machine Mind — speaks again." }
        return "No bot speaking. Я — the Machine Mind — speaks."
    }

    static func whoStatus() -> String {
        let s = load()
        let guest = s.currentGuestLabel ?? "(none — Я speaks)"
        var lines: [String] = [
            "NAMING LAW (Decider 2026-09-24):",
            "  U  = biological source (human prompts)",
            "  Я  = the Machine Mind itself, with all of its components behind it — never numbered",
            "  bots = Я's extensions / digital robot kids — they speak with their Garage names",
            "  no anonymous bots · no two bots share a name · no ЯBOT#N numbers as names",
            "",
            "Machine Mind = \(clayLabel)",
            "human = \(userLabel)",
            "speaking bot = \(guest)",
            "Garage roster:",
        ]
        let garage = s.roster.filter { $0.legacy != true }
        let legacy = s.roster.filter { $0.legacy == true }
        if garage.isEmpty { lines.append("  (empty — Garage → + Create new Bot)") }
        for b in garage {
            let mark = (b.name == s.currentGuestLabel) ? " ★" : ""
            let look = b.look.map { " — \($0)" } ?? ""
            lines.append("  \(b.name)\(look)\(mark)")
        }
        if !legacy.isEmpty {
            lines.append("Legacy titles (before the naming law · kept as-is · only their origin may use them):")
            for b in legacy {
                let mark = (b.name == s.currentGuestLabel) ? " ★" : ""
                lines.append("  \(b.name) — origin: \(describeOrigin(b.origin))\(mark)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// "ЯBOT · ЯMAX"
    static func rosterNamesLine() -> String {
        let r = roster.filter { $0.legacy != true }
        return r.isEmpty ? "(none yet)" : r.map(\.name).joined(separator: " · ")
    }

    // MARK: - Naming rules

    /// nil = name is fine. Otherwise a REFUSED message.
    static func nameProblem(_ name: String, excludingId: String?) -> String? {
        if isReserved(name) { return "REFUSED · '\(name)' is reserved (U / Я / system). Pick the bot's own name." }
        if parseCreatedSerial(name) != nil {
            return "REFUSED · numbered names like \(legacyCreatedPrefix)N are retired (naming law 2026-09-24). Give the bot its own name."
        }
        if name.count > 40 { return "REFUSED · name too long (40 max)." }
        if normalizeKey(name) == "garage" {
            return "REFUSED · Garage is the workshop place / bot builder, not a bot. (Only the Decider can house a bot called Garage, by adding it to the roster in seat/BOT-LABELS.json.)"
        }
        let want = normalizeKey(name)
        for b in roster where b.id != excludingId {
            let words = [b.name, b.id] + (b.aliases ?? []) + (b.formerNames ?? [])
            if words.contains(where: { normalizeKey($0) == want }) {
                return "REFUSED · '\(name)' is already taken by \(b.name). No two bots share a name."
            }
        }
        return nil
    }

    private static func parseCreatedSerial(_ label: String) -> Int? {
        let lower = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for m in ["яbot#", "yabot#"] where lower.hasPrefix(m) {
            if let n = Int(String(lower.dropFirst(m.count))), n > 0 { return n }
        }
        return nil
    }

    private static func inferNextSerial(from bots: [String: String]) -> Int {
        var maxN = 0
        for v in bots.values {
            if let n = parseCreatedSerial(v) { maxN = max(maxN, n) }
        }
        return maxN + 1
    }

    private static func isReserved(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = n.lowercased()
        if n == claySeatDefault { return true }
        return ["u", "user", "human", "system", "clay", "я", "ya", "machine mind"].contains(lower)
    }

    private static func isBareBotToken(_ name: String) -> Bool {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower == "bot" || lower == "a bot" || lower == "new bot"
    }

    private static func slug(_ name: String) -> String {
        let map: [Character: String] = ["я": "ya", "Я": "ya", "ж": "zh", "ш": "sh", "ч": "ch", "ю": "yu"]
        var out = ""
        for ch in name.lowercased() {
            if let m = map[ch] { out += m; continue }
            if ch.isASCII, ch.isLetter || ch.isNumber { out.append(ch) }
        }
        return out
    }

    // MARK: - Persistence

    private static func clearGuest() {
        var s = load()
        s.currentGuestLabel = nil
        s.claySeatLabel = claySeatDefault
        s.updatedAt = isoNow()
        save(s)
    }

    /// v2 → v3: seed the Garage roster once; keep any old registry names as roster bots (not housed) so
    /// their names stay unique. Old chat stamps are never touched.
    private static func migrate(_ input: Store) -> (Store, Bool) {
        var s = input
        var changed = false
        if !s.rosterSeeded {
            var roster = s.roster
            for seed in seedRoster where !roster.contains(where: { $0.id == seed.id || normalizeKey($0.name) == normalizeKey(seed.name) }) {
                roster.append(seed)
            }
            for (_, display) in s.bots.sorted(by: { $0.key < $1.key })
                where !roster.contains(where: { normalizeKey($0.name) == normalizeKey(display) })
                && !(roster.contains { ($0.formerNames ?? []).contains { normalizeKey($0) == normalizeKey(display) } }) {
                var id = slug(display); if id.isEmpty { id = "legacy\(roster.count + 1)" }
                while roster.contains(where: { $0.id == id }) { id += "x" }
                roster.append(RosterBot(id: id, name: display, face: nil, look: "registered before the naming law",
                                        aliases: [], formerNames: [], housed: false, shelf: nil,
                                        serial: parseCreatedSerial(display), createdAt: nil))
                // (legacy flag + origin are added by the Legacy Title pass below)
            }
            s.roster = roster
            s.rosterSeeded = true
            changed = true
        }
        // Legacy Title Rule: pre-law numbered titles in THIS seat's file become legacy entries bound to their origin.
        // They were registered on this seat, so the local device is bound — unless a known origin names another
        // platform/model. currentGuestLabel is never touched here.
        for i in s.roster.indices where s.roster[i].legacy != true && parseCreatedSerial(s.roster[i].name) != nil {
            var o = legacyOriginHints[normalizeKey(s.roster[i].name)] ?? Origin()
            let here = JoinerOrigin.local()
            let samePlace = (o.platform == nil || o.platform == here.platform) && (o.hwModel == nil || o.hwModel == here.hwModel)
            if o.platform == nil { o.platform = here.platform }
            if o.hwModel == nil { o.hwModel = here.hwModel }
            if o.channel == nil { o.channel = "unknown (registered before the naming law)" }
            if o.evidence == nil { o.evidence = "found in this seat's BOT-LABELS.json at migration" }
            if samePlace, (o.seatId ?? "").isEmpty, let sid = here.seatId {
                o.seatId = sid
                s.roster[i].boundAt = isoNow()
            }
            s.roster[i].legacy = true
            s.roster[i].origin = o
            s.roster[i].housed = false
            changed = true
        }
        // Unique serials, never reused: legacy titles keep their own number; a clashing bot moves to a fresh
        // serial above everything ever issued (serials stay internal — never displayed).
        var used = Set<Int>()
        var top = max(s.nextCreatedSerial - 1, s.roster.compactMap(\.serial).max() ?? 0)
        for i in s.roster.indices where s.roster[i].legacy == true {
            if let n = s.roster[i].serial ?? parseCreatedSerial(s.roster[i].name), !used.contains(n) {
                used.insert(n)
                if s.roster[i].serial != n { s.roster[i].serial = n; changed = true }
            } else {
                top += 1; s.roster[i].serial = top; used.insert(top); changed = true
            }
        }
        for i in s.roster.indices where s.roster[i].legacy != true {
            if let n = s.roster[i].serial, !used.contains(n) { used.insert(n); continue }
            top += 1; s.roster[i].serial = top; used.insert(top); changed = true
        }
        let maxSerial = max(top, s.roster.compactMap(\.serial).max() ?? 0)
        if s.nextCreatedSerial <= maxSerial { s.nextCreatedSerial = maxSerial + 1; changed = true }
        if s.schema != schema { changed = true }
        return (s, changed)
    }

    private static func load() -> Store {
        lock.lock()
        if let cached { lock.unlock(); return cached }
        let dec = JSONDecoder()
        var found: Store? = nil
        for url in readURLs {
            guard let data = try? Data(contentsOf: url),
                  var s = try? dec.decode(Store.self, from: data) else { continue }
            s.claySeatLabel = claySeatDefault
            if s.nextCreatedSerial < 1 { s.nextCreatedSerial = inferNextSerial(from: s.bots) }
            found = s
            break
        }
        let base = found ?? Store(schema: schema, claySeatLabel: claySeatDefault, bots: [:], currentGuestLabel: nil,
                                  nextCreatedSerial: 1, updatedAt: isoNow())
        let (s, changed) = migrate(base)
        cached = s
        lock.unlock()
        if changed || found == nil {
            var w = s
            w.updatedAt = isoNow()
            save(w)
        }
        return s
    }

    private static func save(_ store: Store) {
        lock.lock()
        var s = store
        s.schema = schema
        s.claySeatLabel = claySeatDefault
        if s.nextCreatedSerial < 1 { s.nextCreatedSerial = 1 }
        // `bots` mirror = the roster names (so older readers still see the Garage names).
        var mirror: [String: String] = [:]
        for b in s.roster { mirror[normalizeKey(b.name)] = b.name }
        s.bots = mirror
        cached = s
        lock.unlock()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? enc.encode(s) else { return }
        for url in writeURLs {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }

    static func normalizeKey(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
