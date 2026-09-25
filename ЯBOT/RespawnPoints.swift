import Foundation

/// RESPAWN (0.3.0) — same meaning as ever: put the clay back on a known-good seat.
/// Purpose: one-step undo of a new build on every device (Mac · iPhone · Android · source trees).
/// Respawn points live on the Mac at ~/Library/Developer/ЯBOT-respawn/<point>/ with respawn.sh.
/// Honest limit: the app cannot reinstall itself. It lists the points and the exact command;
/// the Decider runs it (dry run first, then --go). NonNuclear: nothing self-applies.
/// The older template restore (ya-respawn.sh → official-templates) stays as `respawn template`.
enum RespawnPoints {
    static let folderName = "ЯBOT-respawn"

    struct Point {
        let name: String
        let path: String
        let targets: [String]
        let hasScript: Bool
    }

    static var rootPath: String {
        NSHomeDirectory() + "/Library/Developer/" + folderName
    }

    static func points() -> [Point] {
        #if os(macOS)
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: rootPath)) ?? []
        var out: [Point] = []
        for n in names.sorted().reversed() where !n.hasPrefix(".") && !n.hasPrefix("_") && !n.hasPrefix("restored-") {
            let p = rootPath + "/" + n
            var targets: [String] = []
            if fm.fileExists(atPath: p + "/mac/ЯBOT.app") { targets.append("mac") }
            if fm.fileExists(atPath: p + "/iphone/ЯBOT.app") { targets.append("iphone") }
            if fm.fileExists(atPath: p + "/android/app-debug.apk") { targets.append("android") }
            if fm.fileExists(atPath: p + "/source") { targets.append("source") }
            out.append(Point(name: n, path: p, targets: targets, hasScript: fm.fileExists(atPath: p + "/respawn.sh")))
        }
        return out
        #else
        return []
        #endif
    }

    /// `respawn` — list points + exact commands. Never runs anything.
    static func status() -> String {
        #if os(macOS)
        let ps = points()
        guard let newest = ps.first else {
            return """
            RESPAWN · no respawn points under \(rootPath) yet.
            Purpose: one-step undo of a new build. CoS seats one before every upgrade.
            Template restore (older meaning): respawn template
            """
        }
        var lines = [
            "RESPAWN · known-good seats (Decider runs; the app cannot reinstall itself)",
            "Purpose: undo a new build in one step on any device.",
        ]
        for p in ps.prefix(5) {
            lines.append("· \(p.name) — \(p.targets.joined(separator: " · "))\(p.hasScript ? "" : " (no respawn.sh)")")
        }
        let q = "\"\(newest.path)/respawn.sh\""
        lines.append("")
        lines.append("Newest: \(newest.name). In Terminal (dry run first — prints every action):")
        lines.append("  \(q) mac        # then add --go")
        lines.append("  \(q) iphone     # devicectl install (phone on USB/Wi-Fi)")
        lines.append("  \(q) android    # adb install -r -d to connected devices")
        lines.append("  \(q) source     # restores both trees to a SIDE folder")
        lines.append("  \(q) verify     # checksums")
        lines.append("Game projects have their own respawn inside the GAME BUILDERS WORKSHOP (yabot://game/workshop).")
        lines.append("Older template restore: respawn template")
        return lines.joined(separator: "\n")
        #else
        return """
        RESPAWN · the iPhone cannot reinstall its own build.
        On the Mac: ~/Library/Developer/ЯBOT-respawn/<point>/respawn.sh iphone (dry run, then --go).
        Game projects: GAME BUILDERS WORKSHOP → Respawn (yabot://game/workshop).
        """
        #endif
    }
}
