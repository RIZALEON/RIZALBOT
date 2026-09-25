import Foundation
import Combine

/// Green nerve (ONLINE) gate — Decider 2026-09-22:
/// Only **US (Decider)** and **bots that live in Lab of Creations** may flip ONLINE,
/// and only **on the way out** (departure / bScout OUT). Home = offline premier.
final class ModeStore: ObservableObject {
    static let shared = ModeStore()

    enum Actor: String {
        case decider = "US-Decider"
        case labResidentBot = "LabResidentBot"
        case outsider = "Outsider"
    }

    enum FlipContext: String {
        case wayOut = "way_out"
        case homeReturn = "home_return"
        case status = "status"
    }

    @Published var isOnline: Bool {
        didSet { UserDefaults.standard.set(isOnline, forKey: "YaBOT.ModeStore.isOnline") }
    }

    private(set) var lastOnlineBy: String = ""
    private(set) var lastOnlineContext: String = ""

    private init() {
        isOnline = UserDefaults.standard.bool(forKey: "YaBOT.ModeStore.isOnline")
        lastOnlineBy = UserDefaults.standard.string(forKey: "YaBOT.ModeStore.lastOnlineBy") ?? ""
        lastOnlineContext = UserDefaults.standard.string(forKey: "YaBOT.ModeStore.lastOnlineContext") ?? ""
    }

    var label: String {
        let gate = "Gate: US + Lab-resident bots only · flip ON only on the way out"
        if isOnline {
            return "Mode: ONLINE link allowed as bonus. Offline seat still premier.\n\(gate)\nLast flip: \(lastOnlineBy) · \(lastOnlineContext)"
        }
        return "Mode: OFFLINE premier. Green nerve off.\n\(gate)"
    }

    /// Bots whose home is Lab of Creations (may flip ONLINE on departure).
    static let labResidentIds: Set<String> = [
        "NEO-BABY-SCOUT-001", "RFID-YA-SCOUT-01", "Scout .01",
        "clay-yabot", "RFID-YA-GENESIS-001", "ЯBOT",
        "lab-scout-fn", "RFID-YA-LAB-SCOUT",
        "b15ee3e1-47ed-4212-be46-c60d7306ce8f", "RFID-YA-AGENT-RIZALBOT", "RIZALBOT"
    ]

    static func isLabResident(id: String?) -> Bool {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return false }
        if labResidentIds.contains(id) { return true }
        let lower = id.lowercased()
        return labResidentIds.contains(where: { $0.lowercased() == lower })
    }

    @discardableResult
    func goOnline(by actor: Actor, context: FlipContext, botId: String? = nil) -> String {
        guard context == .wayOut else {
            return "DENIED · ONLINE only on the way out. Home stays offline premier.\n\(label)"
        }
        switch actor {
        case .decider:
            break
        case .labResidentBot:
            guard Self.isLabResident(id: botId) else {
                return "DENIED · only Lab-resident bots may flip ONLINE on the way out. id=\(botId ?? "?")"
            }
        case .outsider:
            return "DENIED · outsiders cannot flip ONLINE. Only US + Lab-resident bots · on the way out."
        }
        isOnline = true
        lastOnlineBy = actor == .decider ? Actor.decider.rawValue : (botId ?? Actor.labResidentBot.rawValue)
        lastOnlineContext = context.rawValue
        UserDefaults.standard.set(lastOnlineBy, forKey: "YaBOT.ModeStore.lastOnlineBy")
        UserDefaults.standard.set(lastOnlineContext, forKey: "YaBOT.ModeStore.lastOnlineContext")
        _ = GhostChainLedger.append(op: "claim", bio: "mode-online", source: "mode-store", extra: [
            "by": lastOnlineBy, "context": lastOnlineContext, "gate": "US_LAB_RESIDENT_WAY_OUT"
        ])
        return "ONLINE · way-out flip by \(lastOnlineBy).\n\(label)"
    }

    @discardableResult
    func goOffline(reason: String = "home") -> String {
        isOnline = false
        _ = GhostChainLedger.append(op: "claim", bio: "mode-offline", source: "mode-store", extra: [
            "reason": reason
        ])
        return "OFFLINE premier (\(reason)).\n\(label)"
    }

    func toggle() {
        if isOnline { _ = goOffline(reason: "toggle") }
        else { _ = goOnline(by: .decider, context: .wayOut, botId: nil) }
    }
}
