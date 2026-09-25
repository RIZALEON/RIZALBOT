import Foundation

/// GAME BUILDERS WORKSHOP — store for Я Game projects, bot drafts, Decider apply, per-project respawn.
/// Purpose: let Я's bots — by their Garage names (today ЯBOT · ЯMAX; roster = seat/BOT-LABELS.json) — evolve the game
/// along the way, while NOTHING a bot writes goes live without the Decider.
/// Flow (NonNuclear): bot proposes a draft → Decider previews → Decider taps Approve & Apply →
/// the previous project state is snapshotted into respawn/ first → draft copied into the project.
/// Every step is appended to EVOLUTION-LEDGER.jsonl (append-only, never rewritten).
/// Paths (Mac): ~/Documents/ЯBOT/game/workshop/  (App Support fallback until Documents is granted)
/// Paths (iOS): <app Documents>/ЯBOT/game/workshop/  (seeded from the bundled BLUEFACE-v1.html)
enum GameWorkshop {
    static let schema = "GameWorkshop.v1"
    static let seedProjectId = "blueface"
    static let seedProjectName = "BLUEFACE v1"
    static let ledgerName = "EVOLUTION-LEDGER.jsonl"

    // MARK: - Paths

    static var root: URL {
        #if os(macOS)
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if MindTreeRoot.documentsAccessGranted {
            return home.appendingPathComponent("Documents/ЯBOT/game/workshop", isDirectory: true)
        }
        return home.appendingPathComponent("Library/Application Support/ЯBOT/game/workshop", isDirectory: true)
        #else
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        return docs.appendingPathComponent("ЯBOT/game/workshop", isDirectory: true)
        #endif
    }

    static var projectsDir: URL { root.appendingPathComponent("projects", isDirectory: true) }
    static var draftsDir: URL { root.appendingPathComponent("drafts", isDirectory: true) }
    static var respawnDir: URL { root.appendingPathComponent("respawn", isDirectory: true) }
    static var ledgerURL: URL { root.appendingPathComponent(ledgerName) }

    static func projectDir(_ id: String) -> URL { projectsDir.appendingPathComponent(safeName(id), isDirectory: true) }

    // MARK: - Models

    struct Project: Identifiable, Equatable {
        let id: String
        var name: String
        var entry: String
        var dir: URL
        var entryURL: URL { dir.appendingPathComponent(entry) }
    }

    enum DraftStatus: String, Codable { case proposed, applied, rejected }

    struct Draft: Codable, Identifiable, Equatable {
        var id: String
        var project: String
        var file: String
        var language: String
        var author: String
        var authorDisplay: String
        var purpose: String
        var createdAt: String
        var status: DraftStatus
        var needsRebuild: Bool
        var source: String          // heart | starter | inline
        var bytes: Int
        var notes: [String]
        var appliedAt: String?
        var snapshot: String?
    }

    struct Snapshot: Identifiable, Equatable {
        let id: String      // folder name
        let project: String
        let createdAt: String
        let reason: String
        let dir: URL
    }

    // MARK: - Seat

    /// Make folders + seed BLUEFACE v1 once (from Documents copy on Mac, else bundle). Never overwrites.
    @discardableResult
    static func ensureSeated() -> String {
        let fm = FileManager.default
        for d in [root, projectsDir, draftsDir, respawnDir] {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: ledgerURL.path) {
            try? Data().write(to: ledgerURL)
        }
        WorkshopAuthors.ensureSeated()
        let seed = projectDir(seedProjectId)
        var note = "workshop seated · \(root.path)"
        if !fm.fileExists(atPath: seed.appendingPathComponent("live/index.html").path) {
            try? fm.createDirectory(at: seed.appendingPathComponent("live", isDirectory: true), withIntermediateDirectories: true)
            if let html = Bundle.main.url(forResource: "BLUEFACE-v1", withExtension: "html") {
                try? fm.copyItem(at: html, to: seed.appendingPathComponent("live/index.html"))
                note += " · seeded BLUEFACE v1 from bundle"
            }
            if let zip = Bundle.main.url(forResource: "blueface-ts-src", withExtension: "zip"),
               !fm.fileExists(atPath: seed.appendingPathComponent("blueface-ts-src.zip").path) {
                try? fm.copyItem(at: zip, to: seed.appendingPathComponent("blueface-ts-src.zip"))
            }
            writeProjectMeta(id: seedProjectId, name: seedProjectName, entry: "live/index.html")
            ledger(["event": "seed", "project": seedProjectId, "by": "system", "note": note])
        }
        return note
    }

    static func writeProjectMeta(id: String, name: String, entry: String) {
        let meta: [String: Any] = ["schema": schema, "id": id, "name": name, "entry": entry,
                                   "crown": "Я", "createdAt": isoNow()]
        let url = projectDir(id).appendingPathComponent("project.json")
        guard !FileManager.default.fileExists(atPath: url.path),
              let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func projects() -> [Project] {
        ensureSeated()
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: projectsDir.path)) ?? []
        var out: [Project] = []
        for n in names.sorted() where !n.hasPrefix(".") {
            let dir = projectsDir.appendingPathComponent(n, isDirectory: true)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            var name = n
            var entry = "live/index.html"
            if let d = try? Data(contentsOf: dir.appendingPathComponent("project.json")),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                name = (o["name"] as? String) ?? n
                entry = (o["entry"] as? String) ?? entry
            }
            out.append(Project(id: n, name: name, entry: entry, dir: dir))
        }
        return out
    }

    /// Decider "New project" — blank HTML shell from the fundamentals starter.
    static func createProject(named raw: String) -> String {
        let id = safeName(raw.lowercased())
        guard !id.isEmpty else { return "HOW: name the project" }
        let dir = projectDir(id)
        if FileManager.default.fileExists(atPath: dir.path) { return "Project \(id) already exists." }
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("live", isDirectory: true), withIntermediateDirectories: true)
        let html = GameWrite.starter(language: "html", file: "live/index.html", purpose: "New Я Game project \(raw)")
        try? html.write(to: dir.appendingPathComponent("live/index.html"), atomically: true, encoding: .utf8)
        writeProjectMeta(id: id, name: raw, entry: "live/index.html")
        ledger(["event": "project-create", "project": id, "by": "Decider", "note": raw])
        return "Project \(id) created."
    }

    // MARK: - Drafts (bots propose)

    /// Save a validated draft. Returns (draft, message). Invalid drafts are refused and logged.
    static func propose(project rawProject: String, file rawFile: String, language rawLang: String,
                        content: String, purpose: String, author: String, source: String) -> (Draft?, String) {
        ensureSeated()
        let project = safeName(rawProject.isEmpty ? seedProjectId : rawProject)
        guard FileManager.default.fileExists(atPath: projectDir(project).path) else {
            return (nil, "GAMEWRITE refused · no project '\(project)'. Projects: \(projects().map(\.id).joined(separator: ", "))")
        }
        let check = GameWrite.validate(language: rawLang, file: rawFile, content: content)
        let who = WorkshopAuthors.resolve(author)
        let authorLabel = who?.display ?? author.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorDisplay = authorLabel
        guard check.ok, let lang = check.language, let file = check.file else {
            ledger(["event": "refused", "project": project, "file": rawFile, "language": rawLang,
                    "author": authorDisplay, "purpose": purpose, "reasons": check.problems])
            return (nil, "GAMEWRITE refused (nothing saved):\n• " + check.problems.joined(separator: "\n• "))
        }
        guard who != nil else {
            ledger(["event": "refused", "project": project, "file": file, "author": authorLabel,
                    "reasons": ["author not in authors.json — gamewrite authors: \(WorkshopAuthors.namesLine())"]])
            return (nil, "GAMEWRITE refused (nothing saved) · " + WorkshopAuthors.refusal(authorLabel))
        }
        let stamp = compactStamp()
        let id = "d\(stamp)-\(String(UUID().uuidString.prefix(4)).lowercased())"
        let dir = draftsDir.appendingPathComponent(id, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try content.write(to: dir.appendingPathComponent(contentName(for: file)), atomically: true, encoding: .utf8)
        } catch {
            return (nil, "GAMEWRITE write failed: \(error.localizedDescription)")
        }
        let draft = Draft(id: id, project: project, file: file, language: lang, author: authorLabel,
                          authorDisplay: authorDisplay, purpose: purpose.isEmpty ? "(no purpose given)" : purpose,
                          createdAt: isoNow(), status: .proposed, needsRebuild: check.needsRebuild,
                          source: source, bytes: content.utf8.count, notes: check.warnings,
                          appliedAt: nil, snapshot: nil)
        saveMeta(draft)
        ledger(["event": "propose", "draft": id, "project": project, "file": file, "language": lang,
                "author": authorDisplay, "purpose": draft.purpose, "source": source,
                "bytes": draft.bytes, "needsRebuild": draft.needsRebuild])
        MindTranscript.append(role: "assistant", kind: "gamewrite-propose",
                              body: "draft \(id) · \(lang) · \(project)/\(file) · purpose: \(draft.purpose)",
                              party: authorLabel)
        var msg = """
        GAMEWRITE draft proposed · \(id)
        author: \(authorDisplay) · language: \(lang) · file: \(project)/\(file) · source: \(source)
        purpose: \(draft.purpose)
        status: proposed — NOT live. Decider: open GAME BUILDERS WORKSHOP (yabot://game/workshop) → Drafts → Preview → Approve & Apply.
        """
        if draft.needsRebuild { msg += "\nflag: needs rebuild (\(lang) wrapper code cannot compile in-app)." }
        if !check.warnings.isEmpty { msg += "\nnotes: " + check.warnings.joined(separator: " · ") }
        return (draft, msg)
    }

    static func drafts() -> [Draft] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: draftsDir.path)) ?? []
        let dec = JSONDecoder()
        var out: [Draft] = []
        for n in names where !n.hasPrefix(".") {
            let meta = draftsDir.appendingPathComponent(n).appendingPathComponent("draft.json")
            if let d = try? Data(contentsOf: meta), let dr = try? dec.decode(Draft.self, from: d) { out.append(dr) }
        }
        return out.sorted { $0.createdAt > $1.createdAt }
    }

    static func draft(_ id: String) -> Draft? { drafts().first { $0.id == id || $0.id.hasPrefix(id) } }

    static func contentURL(_ d: Draft) -> URL {
        draftsDir.appendingPathComponent(d.id).appendingPathComponent(contentName(for: d.file))
    }

    static func content(_ d: Draft) -> String {
        (try? String(contentsOf: contentURL(d), encoding: .utf8)) ?? ""
    }

    static func liveContent(_ d: Draft) -> String? {
        try? String(contentsOf: projectDir(d.project).appendingPathComponent(d.file), encoding: .utf8)
    }

    /// Line diff (draft vs live). New file → all lines added.
    static func diffText(_ d: Draft, maxLines: Int = 400) -> String {
        let new = content(d).components(separatedBy: "\n")
        guard let liveText = liveContent(d) else {
            return "NEW FILE \(d.project)/\(d.file)\n" + new.prefix(maxLines).map { "+ " + $0 }.joined(separator: "\n")
        }
        let old = liveText.components(separatedBy: "\n")
        if old.count > 6000 || new.count > 6000 {
            return "(large file: \(old.count) → \(new.count) lines; showing draft head)\n" + new.prefix(maxLines).joined(separator: "\n")
        }
        var lines: [String] = []
        for change in new.difference(from: old) {
            switch change {
            case let .remove(offset, element, _): lines.append("- [\(offset + 1)] \(element)")
            case let .insert(offset, element, _): lines.append("+ [\(offset + 1)] \(element)")
            }
            if lines.count >= maxLines { lines.append("… (truncated)"); break }
        }
        return lines.isEmpty ? "(no changes vs live)" : "DIFF \(d.project)/\(d.file)\n" + lines.joined(separator: "\n")
    }

    static func reject(_ id: String, by who: String = "Decider") -> String {
        guard var d = draft(id) else { return "No draft \(id)." }
        guard d.status == .proposed else { return "Draft \(d.id) is \(d.status.rawValue)." }
        d.status = .rejected
        saveMeta(d)
        ledger(["event": "reject", "draft": d.id, "project": d.project, "file": d.file, "by": who, "author": d.authorDisplay])
        return "Rejected \(d.id). Kept on disk for the record."
    }

    // MARK: - Decider apply + respawn

    /// Decider-only (called from the Workshop UI after an explicit confirm). Snapshot first, then copy.
    static func approveAndApply(_ id: String) -> String {
        guard var d = draft(id) else { return "No draft \(id)." }
        guard d.status == .proposed else { return "Draft \(d.id) is already \(d.status.rawValue)." }
        let recheck = GameWrite.validate(language: d.language, file: d.file, content: content(d))
        guard recheck.ok else { return "Apply refused — draft no longer validates:\n• " + recheck.problems.joined(separator: "\n• ") }
        ledger(["event": "approve", "draft": d.id, "project": d.project, "file": d.file, "by": "Decider",
                "author": d.authorDisplay, "purpose": d.purpose])
        guard let snap = snapshot(project: d.project, reason: "before apply \(d.id) → \(d.file)") else {
            return "Apply stopped — could not snapshot \(d.project) first (nothing changed)."
        }
        let fm = FileManager.default
        let dest = projectDir(d.project).appendingPathComponent(d.file)
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }  // prior version is inside the snapshot
            try fm.copyItem(at: contentURL(d), to: dest)
        } catch {
            return "Apply failed after snapshot \(snap.id): \(error.localizedDescription). Respawn it from the Respawn tab."
        }
        d.status = .applied
        d.appliedAt = isoNow()
        d.snapshot = snap.id
        saveMeta(d)
        ledger(["event": "apply", "draft": d.id, "project": d.project, "file": d.file, "by": "Decider",
                "author": d.authorDisplay, "purpose": d.purpose, "snapshot": snap.id, "needsRebuild": d.needsRebuild])
        MindTranscript.append(role: "system", kind: "gamewrite-apply",
                              body: "Decider applied \(d.id) (\(d.authorDisplay)) → \(d.project)/\(d.file) · respawn \(snap.id)",
                              party: BotLabel.userLabel)
        var msg = "Applied \(d.id) → \(d.project)/\(d.file)\nrespawn point: \(snap.id) (roll back any time)"
        if d.needsRebuild { msg += "\n\(d.language) wrapper: rebuild the app to use it." }
        return msg
    }

    /// Whole-project copy into respawn/<stamp>-<project>/ (APFS clones on Mac; small on disk).
    static func snapshot(project: String, reason: String) -> Snapshot? {
        let fm = FileManager.default
        let src = projectDir(project)
        guard fm.fileExists(atPath: src.path) else { return nil }
        try? fm.createDirectory(at: respawnDir, withIntermediateDirectories: true)
        let id = "\(compactStamp())-\(safeName(project))"
        let dir = respawnDir.appendingPathComponent(id, isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: src, to: dir.appendingPathComponent("project", isDirectory: true))
            let meta: [String: Any] = ["schema": schema, "id": id, "project": project, "reason": reason, "createdAt": isoNow()]
            let data = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: dir.appendingPathComponent("SNAPSHOT.json"), options: .atomic)
        } catch {
            return nil
        }
        ledger(["event": "snapshot", "project": project, "snapshot": id, "reason": reason])
        return Snapshot(id: id, project: project, createdAt: isoNow(), reason: reason, dir: dir)
    }

    static func snapshots(project: String? = nil) -> [Snapshot] {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: respawnDir.path)) ?? []
        var out: [Snapshot] = []
        for n in names where !n.hasPrefix(".") {
            let dir = respawnDir.appendingPathComponent(n, isDirectory: true)
            guard let d = try? Data(contentsOf: dir.appendingPathComponent("SNAPSHOT.json")),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let p = o["project"] as? String else { continue }
            if let project, p != project { continue }
            out.append(Snapshot(id: n, project: p, createdAt: (o["createdAt"] as? String) ?? "",
                                reason: (o["reason"] as? String) ?? "", dir: dir))
        }
        return out.sorted { $0.id > $1.id }
    }

    /// Decider-only: roll a project back. Current state is snapshotted first so the rollback is undoable too.
    static func respawn(project: String, to snapshotId: String) -> String {
        let fm = FileManager.default
        guard let snap = snapshots(project: project).first(where: { $0.id == snapshotId }) else {
            return "No snapshot \(snapshotId) for \(project)."
        }
        guard let pre = snapshot(project: project, reason: "before respawn → \(snapshotId)") else {
            return "Respawn stopped — could not snapshot current \(project) first."
        }
        let live = projectDir(project)
        let parked = respawnDir.appendingPathComponent(pre.id).appendingPathComponent("project", isDirectory: true)
        do {
            // Live state is already copied into `pre`; swap the snapshot copy in.
            try fm.removeItem(at: live)
            try fm.copyItem(at: snap.dir.appendingPathComponent("project", isDirectory: true), to: live)
        } catch {
            if !fm.fileExists(atPath: live.path) { try? fm.copyItem(at: parked, to: live) }
            return "Respawn failed: \(error.localizedDescription). Live project restored from \(pre.id)."
        }
        ledger(["event": "respawn", "project": project, "to": snapshotId, "by": "Decider", "undo": pre.id])
        MindTranscript.append(role: "system", kind: "workshop-respawn",
                              body: "Decider respawned \(project) → \(snapshotId) (undo point \(pre.id))",
                              party: BotLabel.userLabel)
        return "Respawned \(project) → \(snapshotId). Undo point: \(pre.id)."
    }

    // MARK: - Ledger (append-only jsonl)

    static func ledger(_ fields: [String: Any]) {
        var row = fields
        row["ts"] = isoNow()
        row["crown"] = "Я"
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let fm = FileManager.default
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: ledgerURL) {
            defer { try? h.close() }
            h.seekToEndOfFile()
            if let d = line.data(using: .utf8) { h.write(d) }
        } else {
            try? line.data(using: .utf8)?.write(to: ledgerURL)
        }
    }

    static func ledgerTail(_ n: Int = 80) -> [String] {
        guard let t = try? String(contentsOf: ledgerURL, encoding: .utf8) else { return [] }
        return Array(t.split(separator: "\n", omittingEmptySubsequences: true).suffix(n).map(String.init).reversed())
    }

    static func status() -> String {
        ensureSeated()
        let ds = drafts()
        let pending = ds.filter { $0.status == .proposed }.count
        return """
        GAME BUILDERS WORKSHOP · \(root.path)
        projects: \(projects().map { "\($0.name) (\($0.id))" }.joined(separator: ", "))
        drafts: \(ds.count) (\(pending) waiting on Decider) · respawn points: \(snapshots().count)
        gamewrite authors: \(WorkshopAuthors.namesLine()) · list: \(WorkshopAuthors.url.path)
        open: yabot://game/workshop · write: gamewrite <language> <file> <purpose>
        """
    }

    // MARK: - helpers

    static func saveMeta(_ d: Draft) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(d) else { return }
        try? data.write(to: draftsDir.appendingPathComponent(d.id).appendingPathComponent("draft.json"), options: .atomic)
    }

    static func contentName(for file: String) -> String {
        "content-" + (file as NSString).lastPathComponent
    }

    static func safeName(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let mapped = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        var s = String(mapped)
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return String(s.prefix(64))
    }

    static func isoNow() -> String { ISO8601DateFormatter().string(from: Date()) }

    static func compactStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
