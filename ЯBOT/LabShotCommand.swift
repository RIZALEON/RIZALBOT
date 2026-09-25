import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Lab function command **SHOT** — capture a screenshot into the Lab scout seat.
/// Local: macOS `screencapture` · iOS key recipe (no silent invent).
/// Extensions: `shot macos` / `shot ios` relay to the named seat (inbox + LAN/BT when live).
enum LabShotCommand {
    static let commandName = "SHOT"
    static let schema = "LabShotCommand.SHOT.v1"
    static let envelopeType = "ya.lab.shot"

    struct Result: Equatable {
        var text: String
        var path: String?
        var ok: Bool
    }

    enum Target: String {
        case local
        case macos
        case ios

        static func parse(_ raw: String) -> Target? {
            switch raw.lowercased() {
            case "macos", "mac", "osx", "desktop", "neo": return .macos
            case "ios", "iphone", "phone", "ipad": return .ios
            case "local", "here", "this": return .local
            default: return nil
            }
        }

        var label: String {
            switch self {
            case .local: return "local"
            case .macos: return "macos"
            case .ios: return "ios"
            }
        }
    }

    /// Entry from CompanionRouter — `mode` may be `full`, `select`, `window`,
    /// or target(+mode): `macos`, `ios`, `macos full`, `ios select`, …
    static func dispatch(_ raw: String = "full") -> Result {
        let parts = raw.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        var target: Target = .local
        var mode = "full"
        if parts.isEmpty {
            return shot(mode: mode)
        }
        if let t = Target.parse(parts[0]) {
            target = t
            if parts.count > 1 {
                mode = parts[1]
            }
        } else {
            mode = parts.joined(separator: " ")
        }
        if mode.isEmpty { mode = "full" }

        let here = localTarget()
        let effective: Target = (target == .local) ? here : target

        if effective == here {
            return shot(mode: mode)
        }
        return relay(to: effective, mode: mode)
    }

    static func localTarget() -> Target {
        #if os(iOS)
        return .ios
        #elseif os(macOS)
        return .macos
        #else
        return .local
        #endif
    }

    /// Verbs: `shot` · `SHOT` · `screenshot` · `lab shot` · `command shot`
    /// Modes: full (default) · `shot select` · `shot window`
    static func shot(mode: String = "full") -> Result {
        let seat = shotsDirectory()
        let stamp = Self.stamp()
        let filename = "SHOT-\(stamp).png"
        let dest = seat.appendingPathComponent(filename)
        let teach = teachBlock()

        #if os(macOS)
        let m = mode.lowercased()
        var args: [String] = ["-x"] // no shutter sound
        if m == "select" || m == "selection" || m == "region" {
            args.append("-i")
        } else if m == "window" {
            args.append(contentsOf: ["-w", "-i"])
        }
        args.append(dest.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if !FileManager.default.isExecutableFile(atPath: "/usr/sbin/screencapture") {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/screencapture")
        }
        proc.arguments = args
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return Result(
                text: "SHOT FAIL · could not launch screencapture\n\(error.localizedDescription)\n\(teach)",
                path: nil,
                ok: false
            )
        }
        let ok = FileManager.default.fileExists(atPath: dest.path)
        if ok {
            #if canImport(AppKit)
            NSWorkspace.shared.activateFileViewerSelecting([dest])
            #endif
            return Result(
                text: """
                SHOT · \(schema)
                Captured → \(dest.path)
                Mode: \(m) · seat: \(localTarget().label)
                Opened in Finder.
                \(teach)
                """,
                path: dest.path,
                ok: true
            )
        }
        return Result(
            text: """
            SHOT cancelled or empty (selection/window dismissed?).
            Seat folder: \(seat.path)
            \(teach)
            """,
            path: nil,
            ok: false
        )
        #else
        // iOS: no silent screencapture pipe — teach keys + seat path.
        _ = dest
        return Result(
            text: """
            SHOT · \(schema) · ios seat (no silent capture pipe).
            Keys: Side + Volume Up (or Side + Home) → edit → share into Files / Photos.
            Seat folder for handoff PNGs:
            \(seat.path)
            Or relay: `shot macos` to capture the live Mac desktop from this phone.
            \(teach)
            """,
            path: nil,
            ok: false
        )
        #endif
    }

    /// Queue remote capture on the named seat. Mac must be running ЯBOT (inbox drain / LAN / BT).
    static func relay(to target: Target, mode: String) -> Result {
        let m = mode.lowercased().isEmpty ? "full" : mode.lowercased()
        // Tagged so only the target seat executes when shared inboxes sync.
        let localCmd: String = {
            let body = (m == "full") ? "shot" : "shot \(m)"
            return "relay-\(target.label):\(body)"
        }()

        var lines: [String] = [
            "SHOT RELAY · \(schema)",
            "Target: \(target.label) · mode: \(m) · from: \(localTarget().label)",
        ]

        // 1) Shared mind inboxes (iCloud + Documents mirrors) — Mac ClayCommandInbox drains these.
        let written = enqueueRelayCommand(localCmd)
        lines.append("Inbox seats written: \(written)")

        // 2) Live carriers when already on (no forced spend / no new sessions).
        let envelope: [String: Any] = [
            "type": envelopeType,
            "v": 1,
            "schema": schema,
            "target": target.label,
            "mode": m,
            "command": (m == "full" ? "shot" : ("shot " + m)),
            "fromSeat": CoinPathScout.seatDevicePublic,
            "ts": Int(Date().timeIntervalSince1970),
            "pathId": UUID().uuidString,
        ]
        var carrierNotes: [String] = []
        for kind in [CoinCarrierHub.Kind.lan, .bluetooth] {
            let tx = CoinCarrierHub.transmit(kind: kind, envelope: envelope, dest: target.label)
            // Only keep short status lines (avoid dumping huge QR/share payloads).
            let short = tx.split(separator: "\n").prefix(2).joined(separator: " · ")
            carrierNotes.append("\(kind.rawValue): \(short)")
        }
        if !carrierNotes.isEmpty {
            lines.append("Carriers:")
            lines.append(contentsOf: carrierNotes.map { "  · \($0)" })
        }

        lines.append("HOW: other seat runs ЯBOT · allow Screen Recording on Mac · PNG → lab/scaffolds/scout/shots/")
        lines.append(teachBlock())

        return Result(text: lines.joined(separator: "\n"), path: nil, ok: true)
    }

    /// Inbound Multipeer / LAN / USB / QR envelope — run local shot when we are the target.
    @discardableResult
    static func handleRemoteEnvelope(_ obj: [String: Any], fromPeer: String) -> String {
        let typ = (obj["type"] as? String) ?? ""
        guard typ == envelopeType || typ == "ya.lab.shot" else { return "" }
        let targetRaw = ((obj["target"] as? String) ?? "").lowercased()
        let mode = ((obj["mode"] as? String) ?? "full").lowercased()
        let command = (obj["command"] as? String) ?? (mode == "full" ? "shot" : "shot \(mode)")
        let target = Target.parse(targetRaw) ?? .local
        let here = localTarget()
        if target != .local && target != here {
            return "SHOT RELAY ignored · for \(target.label) · this seat is \(here.label) · from=\(fromPeer)"
        }
        // Prefer inbox so clay face shows the same path as a typed shot.
        ClayCommandInbox.enqueue(command)
        return "SHOT RELAY accepted · queued `\(command)` · from=\(fromPeer) · seat=\(here.label)"
    }

    @discardableResult
    private static func enqueueRelayCommand(_ command: String) -> Int {
        // Tagged lines (relay-macos:/relay-ios:) — non-target seats ACK; target captures.
        var n = 0
        for url in relayInboxURLs() {
            let prev = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let next = prev.isEmpty ? (command + "\n") : (prev + command + "\n")
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try next.write(to: url, atomically: true, encoding: .utf8)
                n += 1
            } catch {
                continue
            }
        }
        return n
    }

    static func relayInboxURLs() -> [URL] {
        // App Support only by default — Documents/iCloud after Decider grants Files & Folders.
        var urls: [URL] = [ClayCommandInbox.url]
        #if os(macOS)
        urls.append(MindTreeRoot.homeAppSupportMind.appendingPathComponent(MindTreeRoot.inboxFile))
        #endif
        urls.append(MindTreeRoot.appSupportMind.appendingPathComponent(MindTreeRoot.inboxFile))
        if MindTreeRoot.documentsAccessGranted {
            #if os(macOS)
            urls.append(MindTreeRoot.homeDocumentsMind.appendingPathComponent(MindTreeRoot.inboxFile))
            #endif
            urls.append(MindTreeRoot.inboxDocumentsURL)
            if let cloud = MindTreeRoot.iCloudMind {
                urls.append(cloud.appendingPathComponent(MindTreeRoot.inboxFile))
            }
        }
        var seen = Set<String>()
        return urls.filter { u in
            let p = u.standardizedFileURL.path
            if seen.contains(p) { return false }
            seen.insert(p)
            return true
        }
    }

    static func shotsDirectory() -> URL {
        #if os(macOS)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home
            .appendingPathComponent("Documents/ЯBOT/lab/scaffolds/scout/shots", isDirectory: true)
        #else
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        let dir = docs
            .appendingPathComponent("ЯBOT/lab/scaffolds/scout/shots", isDirectory: true)
        #endif
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func teachBlock() -> String {
        """
        Keys forever: Cmd+Shift+3 full · Cmd+Shift+4 select · Cmd+Shift+5 options · hold Control → clipboard
        iOS: Side+Volume · Extensions: shot macos · shot ios · shot macos full
        Teach: Documents/ЯBOT/lab/scaffolds/TEACH-RBOT-SCREENSHOT-TERMINAL.md
        """
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Denver")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f.string(from: Date())
    }
}
