import Foundation
import SwiftUI
import CryptoKit

/// ЯBOT CLASSROOM (0.3.3) — Garage → Training lane (GARAGE-CLASSROOM-LINK-PROPOSAL.md).
/// Lessons: offline = classroom clone (RIZALEON/rizal-pw, classroom/ only) or bundled seed; online = rizal.pw/classroom → github.io fallback → raw.
/// The app NEVER runs lesson steps, never writes scores for its own bot, never pushes to git.
/// It writes exactly one new file per submit into inbox/ (plus a CLASSROOM-LEDGER.jsonl row), and Decider-tapped
/// approvals into outbox/. Refresh = read-only HTTPS GET of manifest.json; lessons whose sha256 mismatch are ignored.
/// Paths: Mac ~/Documents/ЯBOT/classroom/classroom (when Documents granted) else App Support/ЯBOT/classroom ·
///        iOS <app Documents>/ЯBOT/classroom
enum ClassroomStore {
    /// rizal.pw = shared bot classroom / garage workshop. Primary → Pages fallback → raw (main). Offline = local clone.
    /// rizal.pw DNS is moving to GitHub Pages; until then it 302s to an HTML page, so every base is validated by
    /// manifest schema, not just HTTP 200.
    static let primaryURL = URL(string: "https://rizal.pw/classroom/")!
    static let fallbackURL = URL(string: "https://rizaleon.github.io/rizal-pw/classroom/")!
    static let rawBase = "https://raw.githubusercontent.com/RIZALEON/rizal-pw/main/classroom/"
    static let onlineBases: [String] = [primaryURL.absoluteString, fallbackURL.absoluteString, rawBase]
    static let manifestSchema = "rbot.classroom.manifest.v1"
    /// Last base that served a valid manifest (for status / Open button).
    static var activeBase: String? {
        get { UserDefaults.standard.string(forKey: "ЯBOT.classroom.activeBase") }
        set { UserDefaults.standard.set(newValue, forKey: "ЯBOT.classroom.activeBase") }
    }
    /// Which web page to open for humans: last verified base (non-raw) else primary.
    static var webURL: URL {
        if let b = activeBase, b != rawBase, let u = URL(string: b) { return u }
        return primaryURL
    }

    struct Step: Hashable { let n: Int; let doText: String; let why: String }

    struct Lesson: Identifiable, Equatable {
        let id: String
        var title: String
        var readOnly: Bool
        var requires: [String]
        var purpose: String
        var steps: [Step]
        var mustInclude: [String]
    }

    // MARK: - Paths

    static var root: URL {
        #if os(macOS)
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if MindTreeRoot.documentsAccessGranted {
            let clone = home.appendingPathComponent("Documents/ЯBOT/classroom/classroom", isDirectory: true)
            if FileManager.default.fileExists(atPath: clone.appendingPathComponent("manifest.json").path) { return clone }
        }
        return home.appendingPathComponent("Library/Application Support/ЯBOT/classroom", isDirectory: true)
        #else
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return docs.appendingPathComponent("ЯBOT/classroom", isDirectory: true)
        #endif
    }
    static var inbox: URL { root.appendingPathComponent("inbox", isDirectory: true) }
    static var outbox: URL { root.appendingPathComponent("outbox", isDirectory: true) }
    static var scores: URL { root.appendingPathComponent("scores", isDirectory: true) }
    static var ledger: URL { root.appendingPathComponent("CLASSROOM-LEDGER.jsonl") }

    // MARK: - Load

    static func seed() -> [String: Any] {
        guard let u = Bundle.main.url(forResource: "ClassroomSeed", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }

    static func manifest() -> [String: Any] {
        if let d = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return o }
        return seed()["manifest"] as? [String: Any] ?? [:]
    }

    static func lessonJSON(_ entry: [String: Any]) -> [String: Any]? {
        guard let id = entry["lesson_id"] as? String else { return nil }
        if let path = entry["path"] as? String,
           let d = try? Data(contentsOf: root.appendingPathComponent(path)) {
            if let want = entry["sha256"] as? String, sha256Hex(d) != want { return nil } // mismatched lessons ignored
            return try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        }
        return (seed()["lessons"] as? [String: Any])?[id] as? [String: Any]
    }

    static func lessons() -> [Lesson] {
        let entries = manifest()["lessons"] as? [[String: Any]] ?? []
        return entries.compactMap { e in
            guard let id = e["lesson_id"] as? String, let j = lessonJSON(e) else { return nil }
            let steps = (j["steps"] as? [[String: Any]] ?? []).map { s in
                Step(n: s["n"] as? Int ?? 0, doText: s["do"] as? String ?? "", why: s["why"] as? String ?? "")
            }
            return Lesson(id: id, title: e["title"] as? String ?? id, readOnly: e["read_only"] as? Bool ?? true,
                          requires: e["requires"] as? [String] ?? [], purpose: j["purpose"] as? String ?? "",
                          steps: steps, mustInclude: (j["submit"] as? [String: Any])?["must_include"] as? [String] ?? [])
        }
    }

    /// Unlocked = every `requires` lesson has a scores/ record with passed: true for this learner.
    static func unlocked(_ l: Lesson, learner: String) -> Bool {
        l.requires.allSatisfy { passed(lesson: $0, learner: learner) }
    }

    static func passed(lesson: String, learner: String) -> Bool {
        let files = (try? FileManager.default.contentsOfDirectory(at: scores, includingPropertiesForKeys: nil)) ?? []
        for f in files where f.pathExtension == "json" {
            guard let d = try? Data(contentsOf: f), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            let who = (o["learner"] as? String) ?? ((o["learner"] as? [String: Any])?["name"] as? String) ?? ""
            if (o["lesson_id"] as? String) == lesson, who == learner, (o["passed"] as? Bool) == true { return true }
        }
        return false
    }

    static func status(learner: String = BotLabel.activeGuestLabel ?? "ЯBOT") -> String {
        let ls = lessons()
        var out = ["ЯBOT CLASSROOM · Garage → Training · learner \(learner)", "root: \(root.path)"]
        for l in ls {
            out.append("  \(l.id) · \(l.title) · \(l.readOnly ? "read-only" : "needs approval") · \(unlocked(l, learner: learner) ? "unlocked" : "locked")")
        }
        if ls.isEmpty { out.append("  (no lessons seated)") }
        out.append("web: \(primaryURL.absoluteString) (fallback \(fallbackURL.absoluteString)) · last verified: \(activeBase ?? "none")")
        out.append("Submit writes one new inbox/ file (local only). Scores come from reviewers via git. yabot://classroom")
        return out.joined(separator: "\n")
    }

    // MARK: - Writes (new files only)

    /// Pre-write secret check (mirrors classroom/tools/classroom.py patterns).
    static func looksSecret(_ s: String) -> Bool {
        let patterns = [
            "-----BEGIN [A-Z ]*PRIVATE KEY-----",
            "\\[\\s*(\\d{1,3}\\s*,\\s*){63}\\d{1,3}\\s*\\]",   // 64-byte key arrays
            "\\b[1-9A-HJ-NP-Za-km-z]{80,90}\\b",              // long base58 (secret keys)
            "\\b(ghp|gho|ghs|github_pat|xox[abp]|sk)[-_][A-Za-z0-9_\\-]{16,}",
        ]
        return patterns.contains { s.range(of: $0, options: .regularExpression) != nil }
    }

    static func knownLearner(_ name: String) -> Bool {
        BotLabel.housedBots.contains { $0.name == name } || name == "Rizal"
    }

    /// Writes inbox/<lesson>-<learner>-<attempt>.json. Never overwrites.
    static func submit(lesson: Lesson, learner: String, body: String, platform: String) -> String {
        guard knownLearner(learner) else { return "Refused — unknown learner '\(learner)' (Garage roster names only)." }
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "Write an answer first." }
        guard !looksSecret(text) else { return "Refused — the answer looks like it contains a secret (key/token). Nothing written." }
        let attempt = "a" + String(Int(Date().timeIntervalSince1970))
        let safeLearner = learner.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        let msgId = "\(lesson.id)-\(safeLearner)-\(attempt)"
        let row: [String: Any] = [
            "schema": "rbot.classroom.message.v1", "message_id": msgId, "kind": "submission",
            "lesson_id": lesson.id, "attempt_id": attempt,
            "from": ["name": learner, "role": "learner", "agent": "rbot-app", "platform": platform],
            "created_at": ISO8601DateFormatter().string(from: Date()), "body": text,
            "safety_attest": ["no_secrets": true, "no_remote_or_chain_actions": true, "read_only": lesson.readOnly],
        ]
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appendingPathComponent("\(msgId).json")
        guard !FileManager.default.fileExists(atPath: url.path),
              let d = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted, .sortedKeys]),
              (try? d.write(to: url, options: .withoutOverwriting)) != nil else { return "Submit failed (file exists or not writable)." }
        appendLedger(["op": "classroom-submit", "lesson_id": lesson.id, "learner": learner, "file": "inbox/\(msgId).json"])
        MindTranscript.append(role: "assistant", kind: "classroom-submit", body: "\(learner) submitted \(lesson.id) → inbox/\(msgId).json")
        return "Submitted · inbox/\(msgId).json (local; a reviewer scores it via git)"
    }

    static func appendLedger(_ row: [String: Any]) {
        var r = row
        r["ts"] = ISO8601DateFormatter().string(from: Date())
        guard let d = try? JSONSerialization.data(withJSONObject: r), var line = String(data: d, encoding: .utf8) else { return }
        line += "\n"
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: ledger) { defer { try? h.close() }; h.seekToEndOfFile(); h.write(Data(line.utf8)) }
        else { try? Data(line.utf8).write(to: ledger) }
    }

    /// Read-only GET of classroom/manifest.json, trying rizal.pw → github.io → raw in order (first valid manifest wins),
    /// then seats lessons whose sha256 match under App Support / iOS Documents. GET only; never writes remote.
    static func refresh(completion: @escaping (String) -> Void) {
        guard ModeStore.shared.isOnline else { completion("Refresh needs ONLINE — using offline seat (\(root.path))."); return }
        #if os(macOS)
        if root.path.contains("/Documents/ЯBOT/classroom/classroom") { completion("Offline source = Mac clone — update with: git -C ~/Documents/ЯBOT/classroom pull --ff-only"); return }
        #endif
        fetchManifest(bases: onlineBases, tried: []) { base, data, tried in
            guard let base, let data, let m = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion("Refresh: no valid manifest at \(tried.joined(separator: " · ")) — using seated lessons."); return
            }
            activeBase = base
            try? FileManager.default.createDirectory(at: root.appendingPathComponent("lessons"), withIntermediateDirectories: true)
            final class Count { var n = 0; let lock = NSLock() }
            let seated = Count()
            let group = DispatchGroup()
            for e in m["lessons"] as? [[String: Any]] ?? [] {
                guard let p = e["path"] as? String, let want = e["sha256"] as? String, let lu = URL(string: base + p) else { continue }
                group.enter()
                URLSession.shared.dataTask(with: lu) { d, _, _ in
                    if let d, sha256Hex(d) == want { try? d.write(to: root.appendingPathComponent(p)); seated.lock.lock(); seated.n += 1; seated.lock.unlock() }
                    group.leave()
                }.resume()
            }
            group.notify(queue: .main) {
                try? data.write(to: root.appendingPathComponent("manifest.json"))
                completion("Refresh via \(base): \(seated.n) lesson(s) verified by sha256 and seated.")
            }
        }
    }

    /// Tries each base's manifest.json; accepts only JSON whose schema == rbot.classroom.manifest.v1.
    private static func fetchManifest(bases: [String], tried: [String], done: @escaping (String?, Data?, [String]) -> Void) {
        guard let base = bases.first, let url = URL(string: base + "manifest.json") else { done(nil, nil, tried); return }
        var req = URLRequest(url: url); req.timeoutInterval = 8; req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let data, (resp as? HTTPURLResponse)?.statusCode == 200,
               let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (o["schema"] as? String) == manifestSchema {
                done(base, data, tried + [base])
            } else {
                fetchManifest(bases: Array(bases.dropFirst()), tried: tried + [base], done: done)
            }
        }.resume()
    }

    static func sha256Hex(_ d: Data) -> String {
        SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
}


// MARK: - Garage Training lane panel

struct ClassroomLaneView: View {
    let learner: String
    @State private var lessons: [ClassroomStore.Lesson] = []
    @State private var open: String? = nil
    @State private var answer: String = ""
    @State private var note: String = ""

    private var platform: String {
        #if os(macOS)
        return "mac"
        #else
        return "ios"
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CLASSROOM · Training · \(learner)")
                    .font(ClayTheme.clayFont(size: 13, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                Spacer()
                Link("rizal.pw", destination: ClassroomStore.webURL)
                    .font(ClayTheme.clayFont(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.95))
                    .help("Open the shared classroom · \(ClassroomStore.primaryURL.absoluteString) · fallback \(ClassroomStore.fallbackURL.absoluteString)")
                Button("Refresh") { ClassroomStore.refresh { m in DispatchQueue.main.async { note = m; lessons = ClassroomStore.lessons() } } }
                    .buttonStyle(.plain)
                    .font(ClayTheme.clayFont(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange.opacity(0.95))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(lessons) { l in
                        let unlocked = ClassroomStore.unlocked(l, learner: learner)
                        Button { if unlocked { open = (open == l.id ? nil : l.id); answer = "" } } label: {
                            HStack {
                                Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                                Text("\(l.id) · \(l.title)")
                                Spacer()
                                Text(l.readOnly ? "read-only" : "needs approval").opacity(0.6)
                            }
                            .font(ClayTheme.clayFont(size: 11, weight: .semibold))
                            .foregroundStyle(ClayTheme.offWhite.opacity(unlocked ? 1 : 0.5))
                        }
                        .buttonStyle(.plain)
                        if open == l.id {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l.purpose).font(.system(size: 11)).foregroundStyle(ClayTheme.offWhite.opacity(0.8))
                                ForEach(l.steps, id: \.self) { s in
                                    Text("\(s.n). \(s.doText)\n    why: \(s.why)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                                        .textSelection(.enabled)
                                }
                                Text("The app shows steps; it never runs them. Include: \(l.mustInclude.joined(separator: ", "))")
                                    .font(.system(size: 10)).foregroundStyle(ClayTheme.offWhite.opacity(0.6))
                                TextEditor(text: $answer)
                                    .frame(minHeight: 60, maxHeight: 110)
                                    .font(.system(size: 11))
                                Button("Submit to inbox/") { note = ClassroomStore.submit(lesson: l, learner: learner, body: answer, platform: platform) }
                                    .font(ClayTheme.clayFont(size: 11, weight: .bold))
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        }
                    }
                    if lessons.isEmpty {
                        Text("No lessons seated.").font(.system(size: 11)).foregroundStyle(ClayTheme.offWhite.opacity(0.6))
                    }
                }
            }
            if !note.isEmpty {
                Text(note).font(.system(size: 10)).foregroundStyle(ClayTheme.offWhite.opacity(0.75)).lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: 560, maxHeight: 420, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.78)))
        .onAppear { lessons = ClassroomStore.lessons() }
    }
}
