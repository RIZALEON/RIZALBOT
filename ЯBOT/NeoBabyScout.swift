import Foundation
import CoreLocation

/// Scout .01 Scout — left in Lab of Creations with RFID·GPS·NEO fused on Ghost chain.
/// Commands are **b-verbs** from ЯBOT APP: bPing · bWhere · bHome · bScout · bStatus ·
/// bSleep · bWake · bReport · bLink · bStop — fused into Lab scaffold search/scout/retrieve + beyond.
enum NeoBabyScout {
    static let schema = "NeoBabyScout.v2"
    static let babyId = "NEO-BABY-SCOUT-001"
    static let displayName = "Scout .01"
    static let rfidTag = BotRFIDMint.scout01RFID  // RFID-YA-SCOUT-01 patented mint
    static let neoFuseId = "NEO-FUSE-001"
    static let bio = "neo-baby-scout"
    static let homeRelpath = LabChamberPaths.canonRelpath
    static let homeDeepLink = LabChamberPaths.deepLink

    /// 10 b-commands Scout .01 recognizes from ЯBOT (hardcoded).
    /// Primary verb first; aliases follow.
    static let commands: [(Int, String, [String], String)] = [
        (1, "bPing", ["bping", "baby ping", "neo ping", "ping baby"],
         "Alive on Ghost chain + RFID/NEO heartbeat"),
        (2, "bWhere", ["bwhere", "baby where", "neo where", "locate baby", "track baby"],
         "Fused RFID·GPS·NEO locate — chamber or outside"),
        (3, "bHome", ["bhome", "baby home", "neo home", "return chamber"],
         "Return / mark home = Lab of Creations"),
        (4, "bScout", ["bscout", "baby scout", "neo scout", "baby go"],
         "Leave chamber · run Lab SCOUT COMB obtain path · tracker stays linked"),
        (5, "bStatus", ["bstatus", "baby status", "neo status"],
         "RFID·GPS·NEO·Ghost·in_room + Lab scaffold seat check"),
        (6, "bSleep", ["bsleep", "baby sleep", "neo sleep", "baby idle"],
         "Idle in chamber; tracker warm"),
        (7, "bWake", ["bwake", "baby wake", "neo wake"],
         "Wake in Lab of Creations; ready for Lab work"),
        (8, "bReport", ["breport", "baby report", "neo report", "scout report baby"],
         "Lab return: BEFORE→AFTER · missing-of-40 · americasSiteMatches"),
        (9, "bLink", ["blink", "baby link", "neo link", "ghost link baby"],
         "Re-fuse RFID·GPS·NEO on crypto Ghost chain"),
        (10, "bStop", ["bstop", "baby stop", "neo stop", "baby hold"],
         "Hold; detect-alive beacon; halt travel"),
    ]

    private static var stateURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/ЯBOT/lab/rooms/NEO-BABY-STATE.json")
    }

    struct State: Codable {
        var inRoom: Bool
        var mission: String
        var lastLat: Double?
        var lastLon: Double?
        var lastPlace: String?
        var awake: Bool
        var lastCommand: String?
        var lastScoutNote: String?
        var updatedAt: String
    }

    static func loadState() -> State {
        if let data = try? Data(contentsOf: stateURL),
           let s = try? JSONDecoder().decode(State.self, from: data) {
            return s
        }
        return State(
            inRoom: true,
            mission: "HOME_IN_CHAMBER",
            lastLat: nil, lastLon: nil,
            lastPlace: "Lab of Creations",
            awake: true,
            lastCommand: "left_in_room",
            lastScoutNote: nil,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    static func saveState(_ s: State) {
        try? FileManager.default.createDirectory(
            at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(s) else { return }
        try? data.write(to: stateURL, options: .atomic)
        let twin = URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/lab/rooms/NEO-BABY-STATE.json")
        try? FileManager.default.createDirectory(
            at: twin.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: twin, options: .atomic)
    }

    @discardableResult
    static func leaveInRoomToday() -> String {
        _ = BotRFIDMint.ensureScout01Minted()
        var s = loadState()
        s.inRoom = true
        s.mission = "HOME_IN_CHAMBER"
        s.lastPlace = "Lab of Creations"
        s.awake = true
        s.lastCommand = "leave_in_room"
        s.updatedAt = ISO8601DateFormatter().string(from: Date())
        saveState(s)
        var extra: [String: Any] = [
            "baby_id": babyId, "rfid": rfidTag, "neo": neoFuseId,
            "tracker": "RFID_GPS_NEO_FUSED", "in_room": true,
            "patent_claim": BotRFIDMint.patentClaim,
            "room": LabChamberPaths.roomId, "place": s.lastPlace ?? "",
            "verbs": "bPing bWhere bHome bScout bStatus bSleep bWake bReport bLink bStop",
        ]
        if let (coord, label) = PlaceSense.shared.coordinate() {
            extra["lat"] = coord.latitude
            extra["lon"] = coord.longitude
            extra["place_label"] = label
        }
        let tid = GhostChainLedger.append(op: "establish", bio: bio, source: "lab-chamber", extra: extra)
        _ = GhostChainLedger.append(op: "beacon", bio: bio, source: "neo-fuse", extra: [
            "baby_id": babyId, "rfid": rfidTag, "in_room": true,
        ])
        return "Scout .01 (\(babyId)) IN Lab of Creations · RFID \(rfidTag) · NEO \(neoFuseId) · Ghost \(tid) · verbs b*"
    }

    static func handle(_ raw: String) -> String? {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // strip leading "b " typos
        for (n, primary, aliases, _) in commands {
            let all = [primary.lowercased()] + aliases.map { $0.lowercased() }
            for v in all {
                if lower == v || lower.hasPrefix(v + " ") || lower.hasPrefix(v + ":") {
                    return run(commandNumber: n, primary: primary, raw: lower)
                }
            }
        }
        return nil
    }

    static func run(commandNumber n: Int, primary: String, raw: String) -> String {
        var s = loadState()
        s.lastCommand = primary
        s.updatedAt = ISO8601DateFormatter().string(from: Date())
        if let (coord, label) = PlaceSense.shared.coordinate() {
            s.lastLat = coord.latitude
            s.lastLon = coord.longitude
            if s.lastPlace == nil || s.lastPlace?.isEmpty == true { s.lastPlace = label }
        }

        var lines: [String] = []
        lines.append("Scout .01 · \(primary) (\(n)/10)")
        lines.append("RFID \(rfidTag) · NEO \(neoFuseId) · Ghost \(bio)")

        switch n {
        case 1: // bPing
            s.awake = true
            _ = GhostChainLedger.append(op: "ping", bio: bio, extra: [
                "baby_id": babyId, "rfid": rfidTag, "in_room": s.inRoom, "verb": "bPing",
            ])
            lines.append("PONG · alive · in_room=\(s.inRoom) · place=\(s.lastPlace ?? "?")")
            lines.append(scaffoldPulse())

        case 2: // bWhere
            let fix = locateLine(s)
            _ = GhostChainLedger.append(op: "locate", bio: bio, extra: [
                "baby_id": babyId, "in_room": s.inRoom, "fix": fix, "verb": "bWhere",
            ])
            lines.append(fix)

        case 3: // bHome
            s.inRoom = true
            s.mission = "HOME_IN_CHAMBER"
            s.lastPlace = "Lab of Creations"
            let offlineHome = ModeStore.shared.goOffline(reason: "bHome")
            lines.append(offlineHome)
            lines.append("HOME · \(homeRelpath)")
            lines.append("open \(homeDeepLink)")
            lines.append(scaffoldPulse())

        case 4: // bScout — offline-first HARD; ONLINE only if HARD empty (Decider 2026-09-22)
            s.inRoom = false
            s.mission = "SCOUT_OUT_LAB"
            s.awake = true
            let scoutOut = fuseScoutObtain()
            _ = LabManualDesk.refreshLivingLeaf(note: "bScout desk refresh")
            s.lastScoutNote = scoutOut
            _ = GhostChainLedger.append(op: "beacon", bio: bio, extra: [
                "baby_id": babyId, "event": "bScout", "tracker": "RFID_GPS_NEO_FUSED",
            ])
            lines.append("bScout OUT · offline-first HARD comb")
            lines.append(scoutOut)
            let hardEmpty = scoutOut.contains("scaffolds not found") || scoutOut.contains("NEXT retrieve: (none")
            // Prefer HARD seats; flip ONLINE only when inventory pulse is barren
            let inv = LabScoutCommand.scout()
            if inv.haveTotal == 0 && inv.missingTotal == 0 {
                let onlineFlip = ModeStore.shared.goOnline(by: .labResidentBot, context: .wayOut, botId: babyId)
                lines.append("HARD empty → " + onlineFlip)
                lines.append("bScout WWW armed · green nerve way-out")
            } else {
                if ModeStore.shared.isOnline {
                    _ = ModeStore.shared.goOffline(reason: "bScout-hard-first")
                }
                lines.append("HARD hits present · stay OFFLINE premier (use `scout walis` for tidy-only)")
            }
            _ = hardEmpty // silence unused when inventory decides

        case 5: // bStatus
            lines.append(statusLine(s))
            lines.append(scaffoldPulse())
            lines.append(scaffoldBeyondPulse())

        case 6: // bSleep
            s.awake = false
            s.mission = s.inRoom ? "SLEEP_IN_CHAMBER" : "SLEEP_AWAY"
            lines.append("SLEEP · tracker warm · in_room=\(s.inRoom)")

        case 7: // bWake
            s.awake = true
            if s.inRoom { s.mission = "HOME_IN_CHAMBER" }
            lines.append("AWAKE · Lab of Creations · ready for scaffold work")
            lines.append(scaffoldPulse())

        case 8: // bReport — Lab return wisdom
            lines.append("bReport · Lab return fused")
            LabScoutCommand.refreshMissionDeltaFromInventory()
            _ = LabReturnReport.refreshAmericasSiteMatchesFromScout()
            lines.append(LabScoutCommand.missionDeltaClearLine)
            lines.append(LabManualDesk.totalsClearLine(
                kind: "scout-have",
                previous: LabScoutCommand.missionDeltaPreviousHave,
                new: LabScoutCommand.missionDeltaNewHave
            ))
            let lightsN = LabNewLight.currentLightCount()
            lines.append(LabManualDesk.totalsClearLine(kind: "FUTURE lights", previous: lightsN, new: lightsN))
            for m in LabReturnReport.americasSiteMatches.prefix(8) {
                lines.append("  \(m.id) · \(m.shortLabel)")
            }
            lines.append(ScoutMissingTeach.readout().split(separator: "\n").prefix(12).joined(separator: "\n"))
            lines.append("Mission \(s.mission) · in_room=\(s.inRoom)")
            let pdf = LabManualDesk.refreshLivingLeaf(
                note: "bReport return · \(LabScoutCommand.missionDeltaClearLine)",
                kind: "scout-have",
                previousTotal: LabScoutCommand.missionDeltaPreviousHave,
                newTotal: LabScoutCommand.missionDeltaNewHave
            )
            lines.append(pdf)

        case 9: // bLink
            let tid = GhostChainLedger.append(op: "claim", bio: bio, extra: [
                "baby_id": babyId, "rfid": rfidTag, "neo": neoFuseId,
                "fuse": "RFID_GPS_NEO", "in_room": s.inRoom, "verb": "bLink",
            ])
            lines.append("bLink · RFID·GPS·NEO fused on crypto Ghost chain · trace \(tid)")

        case 10: // bStop
            s.mission = "HOLD"
            _ = GhostChainLedger.append(op: "beacon", bio: bio, extra: [
                "baby_id": babyId, "event": "bStop", "in_room": s.inRoom,
            ])
            lines.append("bStop · HOLD · detect-alive beacon ON")

        default:
            lines.append("unknown")
        }

        saveState(s)
        lines.append("")
        lines.append(commandsMenu())
        return lines.joined(separator: "\n")
    }

    // MARK: - Lab scaffold fuse (search · scout · retrieve · beyond)

    /// Pulse: scaffolds seated? MICRO/MACRO/BASE ghosts + scout inventory.
    static func scaffoldPulse() -> String {
        let home = NSHomeDirectory()
        let roots = [
            home + "/Documents/ЯBOT/lab/scaffolds",
            "/Users/rizal/Documents/ЯBOT/lab/scaffolds",
        ]
        var bits: [String] = ["LAB SCAFFOLD"]
        for root in roots {
            let micro = FileManager.default.fileExists(atPath: root + "/LOCKED_COUNTS.json")
            let scout = FileManager.default.fileExists(atPath: root + "/scout/SCOUT-INVENTORY.json")
            let miss = FileManager.default.fileExists(atPath: root + "/scout/SCOUT-MISSING-OF-40.json")
            let mag = FileManager.default.fileExists(atPath: root + "/scout/obtain/magnetize/FIRST3_HARDCODE.json")
            if micro || scout {
                bits.append("seat \(root)")
                bits.append("LOCKED_COUNTS \(micro ? "YES" : "NO") · SCOUT \(scout ? "YES" : "NO") · MISSING40 \(miss ? "YES" : "NO") · MAG \(mag ? "YES" : "NO")")
                bits.append("ghosts MICRO_680 · MACRO_673703 · BASE_UNION_691931 · GRCh37")
                break
            }
        }
        if bits.count == 1 { bits.append("scaffolds not found under Documents/ЯBOT/lab/scaffolds") }
        return bits.joined(separator: " · ")
    }

    /// Beyond: next missing HO targets + magnetize law + helix + online green path.
    static func scaffoldBeyondPulse() -> String {
        var lines: [String] = ["BEYOND"]
        lines.append("next: scout missing → oldest NEED_HO_SLICE → HO slice by ho_ind → magnetize exact letter vs kit LEFT")
        lines.append("law: GRCh37 · no invent GT · Kennewick STOP_BAM · MICRO≠MACRO · unique AADR id")
        lines.append("helix: \(LabScoutCommand.helixDeepLink) · chamber: \(homeDeepLink)")
        lines.append("verbs: SCOUT · SCOUT WALIS · scout missing · bScout · bReport")
        return lines.joined(separator: "\n  ")
    }

    /// Fuse bScout into Lab SCOUT inventory refresh + missing teach seat + obtain queue hint.
    static func fuseScoutObtain() -> String {
        _ = LabReturnReport.refreshAmericasSiteMatchesFromScout()
        LabScoutCommand.refreshMissionDeltaFromInventory()
        _ = LabScoutCommand.appendMissionDeltaToUserManual()
        _ = ScoutMissingTeach.seatIntoHeart()
        let scout = LabScoutCommand.scout()
        let missing = ScoutMissingTeach.loadMissing().filter { $0.status == "NEED_HO_SLICE" }
        let next = missing.first
        var out: [String] = []
        out.append(LabScoutCommand.missionDeltaClearLine)
        out.append("SCOUT inventory refreshed · have \(scout.haveTotal) · missing \(scout.missingTotal) · new \(scout.newFound)")
        if let n = next {
            let bp = n.dateBP.map { String(Int($0)) } ?? "?"
            out.append("NEXT retrieve: \(n.id) · \(n.regions.joined(separator: ",")) · BP \(bp) · ho \(n.hoInd ?? "?")")
            out.append("path: HO geno slice → magnetize vs R680_KIT_LEFT → hardcode match·c2·c1 → americasSiteMatches")
        } else {
            out.append("NEXT retrieve: (none NEED_HO_SLICE) — check STOP_BAM only")
        }
        out.append(scaffoldPulse())
        return out.joined(separator: "\n")
    }

    static func statusLine(_ s: State? = nil) -> String {
        let st = s ?? loadState()
        let gps: String
        if let la = st.lastLat, let lo = st.lastLon {
            gps = String(format: "%.5f,%.5f", la, lo)
        } else {
            gps = PlaceSense.nowLine()
        }
        return "bStatus · RFID \(rfidTag) · GPS \(gps) · NEO \(neoFuseId) · Ghost ON · in_room=\(st.inRoom) · mission=\(st.mission) · awake=\(st.awake)"
    }

    static func locateLine(_ s: State) -> String {
        if s.inRoom {
            return "bWhere · IN Lab of Creations (\(homeRelpath)) · RFID near-field · GPS room seat"
        }
        let gps: String
        if let la = s.lastLat, let lo = s.lastLon {
            gps = String(format: "%.5f,%.5f", la, lo)
        } else {
            gps = "last fix pending — PlaceSense / place set"
        }
        return "bWhere · OUTSIDE chamber · GPS \(gps) · place=\(s.lastPlace ?? "?") · RFID·NEO on Ghost chain"
    }

    static func commandsMenu() -> String {
        var lines = ["10 b-COMMANDS (ЯBOT → Scout .01):"]
        for (n, primary, _, action) in commands {
            lines.append("  \(n). \(primary) — \(action)")
        }
        return lines.joined(separator: "\n")
    }

    static func introduce() -> String {
        _ = BotRFIDMint.ensureScout01Minted()
        let left = leaveInRoomToday()
        return """
        \(left)

        Scout .01 tracker: RFID · GPS · NEO FUSED → crypto Ghost chain.
        Fused mind: Lab scaffold search · scout · retrieve · beyond (SCOUT · missing-of-40 · magnetize · helix).
        Home: \(homeDeepLink)

        \(commandsMenu())
        """
    }
}
