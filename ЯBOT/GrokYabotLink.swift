import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Same-phone Grok Bot ↔ ЯBOT handoff (online bonus only).
/// Core clay / Heart never depends on Grok. Open-URL first (works across teams).
/// Contract: Documents/ЯBOT/contracts/GROK-YABOT-IOS-LINK-0.1.md
enum GrokYabotLink {
    static let schemePrimary = "yabot"
    static let schemeAlias = "yaaim"
    static let schemes: Set<String> = ["yabot", "yaaim"]
    static let pasteboardTypeHint = "GrokYabotHandoff.v1"
    static let notificationName = Notification.Name("ЯBOT.GrokLink")
    static let statusDidChange = Notification.Name("ЯBOT.GrokLinkStatus")

    enum Action: String {
        case review
        case work
        case status
        case chat
        case mind
        case game
        case ping
        case lab // pass-through marker; ContentView keeps lab routes
    }

    struct Packet: Equatable {
        var action: Action
        var text: String
        var payload: String
        var callback: String
        var id: String
        var rawURL: String
        var botLabel: String = ""
    }

    enum Outcome {
        case review(Packet)
        case work(Packet)      // inject into main chat
        case status(Packet)    // show status sheet
        case mind
        case game
        case chat(String)      // text to inject
        case ping(Packet)
        case ignored
    }

    private static let lock = NSLock()
    private static var lastPacket: Packet?
    private static var lastStatus: [String: Any] = [
        "schema": "GrokYabotStatus.v1",
        "seat": "ЯBOT",
        "state": "idle",
        "online_bonus": true
    ]

    static var lastReceived: Packet? {
        lock.lock(); defer { lock.unlock() }
        return lastPacket
    }

    static func acceptsScheme(_ scheme: String?) -> Bool {
        guard let s = scheme?.lowercased() else { return false }
        return schemes.contains(s)
    }

    /// Parse yabot:// or yaaim:// open-URL into a packet outcome.
    static func parse(_ url: URL) -> Outcome {
        guard acceptsScheme(url.scheme) else { return .ignored }

        let host = (url.host ?? "").lowercased()
        let rawPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        func q(_ name: String) -> String {
            items.first(where: { $0.name.lowercased() == name })?.value?
                .removingPercentEncoding
                ?? items.first(where: { $0.name.lowercased() == name })?.value
                ?? ""
        }

        let text = q("text")
        let payload = decodePayload(q("payload"))
        let callback = q("callback")
        let id = q("id").isEmpty ? UUID().uuidString : q("id")
        let actionRaw = q("action").lowercased()

        // Route by host / path first (lab stays in ContentView).
        if host == "lab" || rawPath == "lab" || rawPath.hasPrefix("lab/") {
            return .ignored // ContentView owns lab
        }
        if host == "game" || rawPath == "game" || rawPath.hasPrefix("game/") {
            return .game
        }

        let routeHost: String = {
            if !host.isEmpty { return host }
            if rawPath.isEmpty { return "" }
            return rawPath.split(separator: "/").first.map(String.init) ?? rawPath
        }()

        let action: Action = {
            if let a = Action(rawValue: actionRaw), a != .lab { return a }
            switch routeHost {
            case "grok": return actionRaw.isEmpty ? .review : (Action(rawValue: actionRaw) ?? .review)
            case "chat": return .chat
            case "mind": return .mind
            case "game": return .game
            case "status": return .status
            case "ping": return .ping
            case "work": return .work
            case "review": return .review
            default:
                if !actionRaw.isEmpty, let a = Action(rawValue: actionRaw) { return a }
                return .chat
            }
        }()

        let bodyText: String = {
            if !text.isEmpty { return text }
            if !payload.isEmpty { return payload }
            // path after first segment: yabot://grok/hello → unused; path-form yabot:///chat/hi
            let parts = rawPath.split(separator: "/").map(String.init)
            if parts.count >= 2 { return parts.dropFirst().joined(separator: "/") }
            return ""
        }()

        let botLabelQ = {
            let a = q("label")
            if !a.isEmpty { return a }
            return q("bot")
        }()
        if !botLabelQ.isEmpty {
            // Legacy Title Rule: the joiner's origin = this device seat + link host / sender (+ ip if given).
            let senderQ = q("from").isEmpty ? q("sender") : q("from")
            _ = BotLabel.enter(botLabelQ, origin: .link(host: host, sender: senderQ, ip: q("ip")))
        }
        let packet = Packet(
            action: action,
            text: bodyText,
            payload: payload,
            callback: callback,
            id: id,
            rawURL: url.absoluteString,
            botLabel: botLabelQ
        )

        switch action {
        case .lab:
            return .ignored
        case .mind:
            return .mind
        case .game:
            return .game
        case .status:
            return .status(packet)
        case .ping:
            return .ping(packet)
        case .review:
            return .review(packet)
        case .work:
            return .work(packet)
        case .chat:
            let t = bodyText.isEmpty ? text : bodyText
            return t.isEmpty ? .ignored : .chat(t)
        }
    }

    /// Record receipt, update status, optional pasteboard + callback.
    static func acknowledge(_ packet: Packet, state: String, note: String = "") {
        lock.lock()
        lastPacket = packet
        var status: [String: Any] = [
            "schema": "GrokYabotStatus.v1",
            "seat": "ЯBOT",
            "state": state,
            "id": packet.id,
            "action": packet.action.rawValue,
            "ts": isoNow(),
            "online_bonus": true,
            "note": note
        ]
        if !packet.text.isEmpty { status["text_len"] = packet.text.count }
        lastStatus = status
        lock.unlock()

        persistPeer(packet: packet, status: status)
        writePasteboardStatus(status)
        NotificationCenter.default.post(name: statusDidChange, object: nil, userInfo: status)

        if !packet.callback.isEmpty {
            openCallback(packet.callback, status: status)
        }
    }

    static func statusSnapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return lastStatus
    }

    static func statusJSONString() -> String {
        let snap = statusSnapshot()
        guard JSONSerialization.isValidJSONObject(snap),
              let data = try? JSONSerialization.data(withJSONObject: snap, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return #"{"schema":"GrokYabotStatus.v1","state":"unknown"}"#
        }
        return s
    }

    static func copyStatusToPasteboard() {
        writePasteboardStatus(statusSnapshot())
    }

    // MARK: - Internals

    private static func decodePayload(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        // Prefer plain UTF-8; if looks like URL-safe/standard base64, try decode.
        if t.hasPrefix("{") || t.hasPrefix("[") { return t }
        let padded: String = {
            let m = t.count % 4
            if m == 0 { return t }
            return t + String(repeating: "=", count: 4 - m)
        }()
        if let data = Data(base64Encoded: padded),
           let s = String(data: data, encoding: .utf8),
           !s.isEmpty {
            return s
        }
        return t.removingPercentEncoding ?? t
    }

    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func peerDir() -> URL {
        let base = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/ЯBOT/peer", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // Documents mirror (Decider / CoS readable on Mac + Files app)
        let docs = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/ЯBOT/peer", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return base
    }

    private static func persistPeer(packet: Packet, status: [String: Any]) {
        let dir = peerDir()
        let docs = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/ЯBOT/peer", isDirectory: true)
        let handoff: [String: Any] = [
            "schema": "GrokYabotHandoff.v1",
            "ts": isoNow(),
            "from": "grok",
            "to": "yabot",
            "verb": packet.action.rawValue,
            "id": packet.id,
            "text": packet.text,
            "payload": packet.payload,
            "callback": packet.callback,
            "raw_url": packet.rawURL,
            "online_bonus": true
        ]
        func write(_ obj: [String: Any], to url: URL) {
            guard JSONSerialization.isValidJSONObject(obj),
                  let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
            else { return }
            try? data.write(to: url, options: .atomic)
        }
        write(handoff, to: dir.appendingPathComponent("GROK-HANDOFF.json"))
        write(status, to: dir.appendingPathComponent("GROK-STATUS.json"))
        write(handoff, to: docs.appendingPathComponent("GROK-HANDOFF.json"))
        write(status, to: docs.appendingPathComponent("GROK-STATUS.json"))
    }

    private static func writePasteboardStatus(_ status: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(status),
              let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return }
        let line = "\(pasteboardTypeHint)\n\(s)"
        #if canImport(UIKit)
        UIPasteboard.general.string = line
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(line, forType: .string)
        #endif
    }

    private static func openCallback(_ callback: String, status: [String: Any]) {
        // Soft reply: only if Decider/Grok registered a callback URL scheme.
        // Never crash; ignore if unopenable.
        var comps = URLComponents(string: callback)
        if comps == nil { return }
        var items = comps?.queryItems ?? []
        items.append(URLQueryItem(name: "from", value: "yabot"))
        items.append(URLQueryItem(name: "state", value: "\(status["state"] ?? "ok")"))
        if let id = status["id"] as? String {
            items.append(URLQueryItem(name: "id", value: id))
        }
        comps?.queryItems = items
        guard let url = comps?.url else { return }
        #if canImport(UIKit)
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #elseif canImport(AppKit)
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
