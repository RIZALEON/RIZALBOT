import Foundation

/// Decider-granted Lab function evolution.
/// Clay: `evolve function <name>: <spec>` after grant, or `functions` to list.
/// Persists under Documents/ЯBOT/lab/functions/EVOLVED-FUNCTIONS.jsonl
enum LabFunctionEvolve {
    static let grantFlag = "lab.evolve.functions.granted"
    static let registryRel = "Documents/ЯBOT/lab/functions/EVOLVED-FUNCTIONS.jsonl"
    static let grantRel = "Documents/ЯBOT/lab/functions/EVOLVE-GRANT.json"

    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
    }
    private static var registryURL: URL {
        docs.appendingPathComponent("ЯBOT/lab/functions/EVOLVED-FUNCTIONS.jsonl")
    }
    private static var grantURL: URL {
        docs.appendingPathComponent("ЯBOT/lab/functions/EVOLVE-GRANT.json")
    }

    static func isGranted() -> Bool {
        guard let data = try? Data(contentsOf: grantURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = obj["granted"] as? Bool else { return false }
        return ok
    }

    @discardableResult
    static func grant(by: String = "Decider") -> String {
        let dir = grantURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let row: [String: Any] = [
            "granted": true,
            "by": by,
            "scope": "lab_functions_only",
            "note": "May evolve NEW Lab clay functions. Not model self-fate. NonNuclear stands. No invented genotypes.",
            "ts": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            try? s.write(to: grantURL, atomically: true, encoding: .utf8)
        }
        _ = GhostChainLedger.append(op: "evolve", bio: "decider-grant", source: "lab-function-evolve", extra: [
            "scope": "lab_functions_only", "granted": true
        ])
        return "EVOLVE GRANT seated · Lab functions only · by \(by). Say: evolve function <name>: <what it does>"
    }

    static func list() -> String {
        let lines = (try? String(contentsOf: registryURL, encoding: .utf8))?
            .split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty } ?? []
        if lines.isEmpty {
            return "Evolved Lab functions: none yet. Grant=\(isGranted() ? "YES" : "NO")."
        }
        var out = ["Evolved Lab functions (\(lines.count)) grant=\(isGranted() ? "YES" : "NO"):"]
        for line in lines.suffix(20) {
            if let d = line.data(using: .utf8),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let name = o["name"] as? String {
                let spec = o["spec"] as? String ?? ""
                out.append(" · \(name) — \(spec)")
            }
        }
        return out.joined(separator: "\n")
    }

    /// Register a new clay function name + spec. Returns reply text.
    static func evolve(name rawName: String, spec: String) -> String {
        guard isGranted() else {
            return "Evolve is Decider-gated. Say: grant evolve lab functions — then evolve function <name>: <spec>"
        }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: " ", with: "-")
        let cleaned = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !cleaned.isEmpty else {
            return "HOW: evolve function <name>: <spec>"
        }
        let dir = registryURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let row: [String: Any] = [
            "name": name,
            "spec": cleaned,
            "ts": ISO8601DateFormatter().string(from: Date()),
            "source": "decider-evolve"
        ]
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row),
              var line = String(data: data, encoding: .utf8) else {
            return "evolve write failed"
        }
        line += "\n"
        if let h = try? FileHandle(forWritingTo: registryURL) {
            defer { try? h.close() }
            h.seekToEndOfFile()
            if let d = line.data(using: .utf8) { h.write(d) }
        } else {
            try? line.data(using: .utf8)?.write(to: registryURL)
        }
        _ = GhostChainLedger.append(op: "evolve", bio: "lab-function", source: "lab-function-evolve", extra: [
            "name": name, "spec": String(cleaned.prefix(160))
        ])
        // Built-in bind: new-light / lab-light
        if name == "new-light" || name == "lab-light" || name == "light" {
            return "EVOLVED function `\(name)` seated.\n\(cleaned)\nTry: new light   ·   lab light"
        }
        return "EVOLVED function `\(name)` seated in lab/functions/EVOLVED-FUNCTIONS.jsonl.\n\(cleaned)\nSay the function name to run it (built-ins: new light)."
    }

    /// Dispatch evolved / built-in Lab lights.
    static func handle(_ text: String) -> String? {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "grant evolve lab functions" || lower == "grant evolve functions" || lower == "you can evolve new functions" {
            return grant()
        }
        if lower == "functions" || lower == "evolved functions" || lower == "lab functions" {
            return list()
        }
        if lower.hasPrefix("evolve function ") {
            let rest = String(text.dropFirst("evolve function ".count))
            let parts = rest.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2 {
                return evolve(name: parts[0], spec: parts[1])
            }
            return "HOW: evolve function <name>: <spec>"
        }
        if let lightReply = LabNewLight.handleClay(text) {
            return lightReply
        }
        // Run by evolved name if registered
        if let hit = findRegistered(lower) {
            if hit == "new-light" || hit == "lab-light" || hit == "light" {
                return LabNewLight.bring()
            }
            return "Function `\(hit)` is seated (spec-only). Built-in runner not yet wired — use: new light"
        }
        return nil
    }

    private static func findRegistered(_ lower: String) -> String? {
        let lines = (try? String(contentsOf: registryURL, encoding: .utf8))?
            .split(whereSeparator: \.isNewline).map(String.init) ?? []
        for line in lines.reversed() {
            guard let d = line.data(using: .utf8),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let name = o["name"] as? String else { continue }
            if lower == name || lower == name.replacingOccurrences(of: "-", with: " ") {
                return name
            }
        }
        return nil
    }
}
