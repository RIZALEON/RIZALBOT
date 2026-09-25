import Foundation

/// Standing law: Mind lives under relative root `ЯBOT/mind` in MANY seats.
/// PRIMARY + automatic write seats: Application Support (+ Caches / Machine Mind).
/// Documents / iCloud are OPTIONAL mirrors — never create or probe them on launch
/// (macOS Files & Folders TCC has no "Always Allow"; probing ~/Documents every
/// relaunch re-prompts, and ad-hoc re-sign resets TCC identity).
enum MindTreeRoot {
    static let lawPath = "ЯBOT/mind"
    static let chatFile = "CHAT-THREAD.jsonl"
    static let transcriptFile = "MIND-TRANSCRIPT.txt"
    static let inboxFile = "INBOX-COMMANDS.txt"

    /// Set after Decider grants Documents (or explicitly opens a Documents seat).
    /// Until then, automatic paths stay off Documents so launch stays quiet.
    private static let documentsGrantKey = "ya.tcc.documents.granted"

    static var documentsAccessGranted: Bool {
        get { UserDefaults.standard.bool(forKey: documentsGrantKey) }
        set { UserDefaults.standard.set(newValue, forKey: documentsGrantKey) }
    }

    static func markDocumentsAccessGranted() {
        documentsAccessGranted = true
    }

    // MARK: - Core seats (always)

    static var appSupportMind: URL {
        seat(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
             ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"),
             create: true)
    }

    /// Path only — does NOT create directories (avoids TCC prompt).
    static var documentsMind: URL {
        seat(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
             ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents"),
             create: false)
    }

    static var cachesMind: URL {
        seat(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
             ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches"),
             create: true)
    }

    /// Machine Mind feeds — another offline copy beside vault feeds.
    static var machineMindFeedChat: URL {
        MachineMindVault.feeds.appendingPathComponent(chatFile)
    }

    /// Optional online amplifier — never touch on launch; only when granted.
    static var iCloudMind: URL? {
        guard documentsAccessGranted else { return nil }
        guard let ubi = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let dir = ubi.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(lawPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    #if os(macOS)
    /// Mac home Documents seat — path only unless granted.
    static var homeDocumentsMind: URL {
        seat(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents"), create: false)
    }
    static var homeAppSupportMind: URL {
        seat(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"), create: true)
    }
    #endif

    // MARK: - File URLs (primary names)

    static var chatThreadURL: URL { appSupportMind.appendingPathComponent(chatFile) }
    static var chatThreadDocumentsURL: URL { documentsMind.appendingPathComponent(chatFile) }
    static var mindTranscriptURL: URL { appSupportMind.appendingPathComponent(transcriptFile) }
    static var mindTranscriptDocumentsURL: URL { documentsMind.appendingPathComponent(transcriptFile) }
    /// Inbox lives in Application Support so CoS/device-smoke inject never forces Documents TCC.
    static var inboxURL: URL { appSupportMind.appendingPathComponent(inboxFile) }
    /// Legacy Documents inbox (hunt/drain only after grant).
    static var inboxDocumentsURL: URL { documentsMind.appendingPathComponent(inboxFile) }

    /// Every seat we WRITE chat into (append-only mirrors). Documents excluded until granted.
    static var chatWriteURLs: [URL] {
        var urls: [URL] = [
            chatThreadURL,
            cachesMind.appendingPathComponent(chatFile),
            machineMindFeedChat,
        ]
        #if os(macOS)
        urls.append(homeAppSupportMind.appendingPathComponent(chatFile))
        #endif
        if documentsAccessGranted {
            urls.append(chatThreadDocumentsURL)
            #if os(macOS)
            urls.append(homeDocumentsMind.appendingPathComponent(chatFile))
            #endif
            if let cloud = iCloudMind {
                urls.append(cloud.appendingPathComponent(chatFile))
            }
        }
        return uniqueURLs(urls)
    }

    /// Every seat we HUNT on restore. Documents hunted only after grant (else one Allow still sticky with stable codesign).
    static var chatHuntURLs: [URL] {
        var urls = chatWriteURLs
        let home = URL(fileURLWithPath: NSHomeDirectory())
        urls += [
            appSupportMind.appendingPathComponent("chat-thread.jsonl"),
            cachesMind.appendingPathComponent("chat-thread.jsonl"),
            home.appendingPathComponent("Library/Application Support/ЯBOT/CHAT-THREAD.jsonl"),
            home.appendingPathComponent("Library/Caches/ЯBOT/mind/CHAT-THREAD.jsonl"),
            home.appendingPathComponent("Library/Application Support/ЯBOT/mind/CHAT-THREAD.jsonl"),
        ]
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            urls.append(support.appendingPathComponent("ЯBOT/CHAT-THREAD.jsonl"))
            urls.append(support.appendingPathComponent("mind/CHAT-THREAD.jsonl"))
        }
        if documentsAccessGranted {
            urls += [
                documentsMind.appendingPathComponent("chat-thread.jsonl"),
                home.appendingPathComponent("Documents/ЯBOT/mind/CHAT-THREAD.jsonl"),
                chatThreadDocumentsURL,
            ]
            #if os(macOS)
            urls.append(homeDocumentsMind.appendingPathComponent(chatFile))
            #endif
            if let cloud = iCloudMind {
                urls.append(cloud.appendingPathComponent(chatFile))
                urls.append(cloud.appendingPathComponent("chat-thread.jsonl"))
            }
        }
        // Shared tmp backup (last-chance offline)
        urls.append(FileManager.default.temporaryDirectory
            .appendingPathComponent("ЯBOT-mind-backup", isDirectory: true)
            .appendingPathComponent(chatFile))
        return uniqueURLs(urls)
    }

    /// Transcript write mirrors (same multi-seat law — Documents only when granted).
    static var transcriptWriteURLs: [URL] {
        var urls: [URL] = [
            mindTranscriptURL,
            cachesMind.appendingPathComponent(transcriptFile),
            MachineMindVault.feeds.appendingPathComponent(transcriptFile),
        ]
        #if os(macOS)
        urls.append(homeAppSupportMind.appendingPathComponent(transcriptFile))
        #endif
        if documentsAccessGranted {
            urls.append(mindTranscriptDocumentsURL)
            #if os(macOS)
            urls.append(homeDocumentsMind.appendingPathComponent(transcriptFile))
            #endif
            if let cloud = iCloudMind {
                urls.append(cloud.appendingPathComponent(transcriptFile))
            }
        }
        return uniqueURLs(urls)
    }

    /// Backward-compatible alias.
    static var legacyChatCandidates: [URL] { chatHuntURLs }

    /// Launch seat: Application Support + Caches only. Never touch Documents / iCloud here.
    @discardableResult
    static func ensureSeated() -> String {
        let roots: [URL] = [
            appSupportMind,
            cachesMind,
        ] + {
            #if os(macOS)
            return [homeAppSupportMind]
            #else
            return [] as [URL]
            #endif
        }()
        for r in roots { _ = r }
        _ = MachineMindVault.feeds
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ЯBOT-mind-backup", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: inboxURL.path) {
            try? "".write(to: inboxURL, atomically: true, encoding: .utf8)
        }
        let docNote = documentsAccessGranted ? "documents=granted" : "documents=deferred"
        return "mind-tree seated root=\(lawPath) seats=\(chatWriteURLs.count) hunt=\(chatHuntURLs.count) \(docNote)"
    }

    // MARK: - helpers

    private static func seat(_ base: URL, create: Bool) -> URL {
        let dir = base.appendingPathComponent(lawPath, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var out: [URL] = []
        for u in urls {
            let key = u.standardizedFileURL.path
            if seen.insert(key).inserted { out.append(u) }
        }
        return out
    }
}
