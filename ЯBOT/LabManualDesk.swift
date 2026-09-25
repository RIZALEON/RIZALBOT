import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Living LAB MANUAL on the Lab of Creations desk — constantly updated.
/// Every bot return MUST refresh MD + rebuild PDF and include previous→new totals.
enum LabManualDesk {
    static let canonRelpath = "lab/rooms/desk/LAB-MANUAL.pdf"
    static let coverRelpath = "lab/rooms/desk/LAB-MANUAL-COVER.png"
    static let mdRelpath = "lab/rooms/desk/LAB-MANUAL.md"
    static let rebuildScriptRelpath = "lab/rooms/desk/rebuild_lab_manual_pdf.py"
    static let deepLink = "yabot://lab/manual"

    static func deskPDFPath() -> String {
        NSHomeDirectory() + "/Documents/ЯBOT/" + canonRelpath
    }

    static func deskRoot() -> String {
        NSHomeDirectory() + "/Documents/ЯBOT/lab/rooms/desk"
    }

    static func candidatePDFPaths() -> [String] {
        let home = NSHomeDirectory()
        return [
            home + "/Documents/ЯBOT/" + canonRelpath,
            "/Users/rizal/Documents/ЯBOT/" + canonRelpath,
            home + "/Documents/ЯBOT/lab/rooms/LAB-MANUAL.pdf",
            Bundle.main.path(forResource: "LAB-MANUAL", ofType: "pdf") ?? "",
        ].filter { !$0.isEmpty }
    }

    /// Clear PREVIOUS → NEW totals line for any return kind.
    static func totalsClearLine(kind: String, previous: Int, new: Int) -> String {
        "PREVIOUS \(kind) total \(previous)  →  NEW \(kind) total \(new)"
    }

    /// Refresh living leaf + ALWAYS rebuild desk PDF.
    /// Pass previous/new totals so every return report shows the delta.
    @discardableResult
    static func refreshLivingLeaf(
        note: String = "",
        kind: String = "return",
        previousTotal: Int? = nil,
        newTotal: Int? = nil
    ) -> String {
        let mdURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/ЯBOT/" + mdRelpath)
        var body = (try? String(contentsOf: mdURL, encoding: .utf8)) ?? defaultMarkdown()
        let stamp = ISO8601DateFormatter().string(from: Date())
        var totalsBlock = LabScoutCommand.missionDeltaClearLine
        if let p = previousTotal, let n = newTotal {
            totalsBlock = totalsClearLine(kind: kind, previous: p, new: n) + "\n" + LabScoutCommand.missionDeltaClearLine
        }
        let leaf = """

## Desk refresh — \(stamp)

\(totalsBlock)

\(note.isEmpty ? "Auto-refresh from Lab / bot return — PDF rebuilt." : note)

"""
        if let range = body.range(of: "\n## Desk refresh") {
            if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
                body = String(body[..<range.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
            } else {
                body = String(body[..<range.lowerBound]) + leaf + "\n\nHANDOFF RULE\n"
            }
        } else if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
            body = String(body[..<handoff.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
        } else {
            body += leaf + "\n\nHANDOFF RULE\n"
        }
        try? FileManager.default.createDirectory(at: mdURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? body.write(to: mdURL, atomically: true, encoding: .utf8)
        let twin = URL(fileURLWithPath: "/Users/rizal/Documents/ЯBOT/" + mdRelpath)
        try? body.write(to: twin, atomically: true, encoding: .utf8)

        // Also fold totals into USER-MANUAL when provided
        if let p = previousTotal, let n = newTotal {
            _ = appendTotalsToUserManual(kind: kind, previous: p, new: n, note: note)
        }

        let pdfMsg = rebuildPDF()
        return "LAB MANUAL desk leaf + PDF refreshed · \(deskPDFPath())\n\(pdfMsg)"
    }

    @discardableResult
    static func appendTotalsToUserManual(kind: String, previous: Int, new: Int, note: String) -> Bool {
        let candidates = [
            NSHomeDirectory() + "/Documents/ЯBOT/USER-MANUAL.md",
            "/Users/rizal/Documents/ЯBOT/USER-MANUAL.md",
        ]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return false }
        let url = URL(fileURLWithPath: path)
        guard var body = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = totalsClearLine(kind: kind, previous: previous, new: new)
        let leaf = """

## Return totals (auto) — \(stamp)

**\(line)**

\(note)

"""
        let marker = "\n## Return totals (auto)"
        if let range = body.range(of: marker) {
            if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
                body = String(body[..<range.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
            } else {
                body = String(body[..<range.lowerBound]) + leaf + "\n\nHANDOFF RULE\n"
            }
        } else if let handoff = body.range(of: "HANDOFF RULE", options: .backwards) {
            body = String(body[..<handoff.lowerBound]) + leaf + "\n\n" + String(body[handoff.lowerBound...])
        } else {
            body += leaf + "\n\nHANDOFF RULE\n"
        }
        try? body.write(to: url, atomically: true, encoding: .utf8)
        let twin = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/ЯBOT/ЯBOT/USER-MANUAL.md")
        try? body.write(to: twin, atomically: true, encoding: .utf8)
        return true
    }

    /// Always rebuild desk LAB-MANUAL.pdf from the living MD.
    @discardableResult
    static func rebuildPDF() -> String {
        #if os(macOS)
        let home = NSHomeDirectory()
        let script = home + "/Documents/ЯBOT/" + rebuildScriptRelpath
        let desk = deskRoot()
        let fallback = "/Users/rizal/Documents/ЯBOT/" + rebuildScriptRelpath
        let scriptPath = FileManager.default.fileExists(atPath: script) ? script : fallback
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            return "PDF rebuild MISSING script · \(rebuildScriptRelpath)"
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        proc.arguments = [scriptPath, desk]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if proc.terminationStatus == 0 {
                return "PDF rebuilt OK · \(out.isEmpty ? deskPDFPath() : out)"
            }
            return "PDF rebuild exit \(proc.terminationStatus) · \(out)"
        } catch {
            return "PDF rebuild failed · \(error.localizedDescription)"
        }
        #else
        return "PDF rebuild Mac-only (Process)"
        #endif
    }

    static func defaultMarkdown() -> String {
        """
        # Ya OPERATING SYSTEM - LAB MANUAL
        Living cover on the Lab desk.
        Seat: lab/rooms/desk/LAB-MANUAL.pdf
        HANDOFF RULE
        """
    }

    @discardableResult
    static func openPDF() -> Bool {
        for p in candidatePDFPaths() {
            if FileManager.default.fileExists(atPath: p) {
                #if canImport(AppKit)
                return NSWorkspace.shared.open(URL(fileURLWithPath: p))
                #else
                return true
                #endif
            }
        }
        return false
    }

    static func statusLine() -> String {
        let exists = candidatePDFPaths().contains { FileManager.default.fileExists(atPath: $0) }
        return "LAB MANUAL desk \(exists ? "SEATED" : "MISSING") · \(canonRelpath) · cover scientist mascot · living · PDF always rebuilt on return"
    }
}
