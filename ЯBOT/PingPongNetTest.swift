import Foundation
#if canImport(Network)
import Network
#endif

/// Pingpong command tree — local device network TEST functions (Decider 2026-09-23).
/// NOT the companion heartbeat `ping` → `here`, and NOT the paused Rizalbot ping→pong mirror.
/// Verbs: ping (count-capped) · nslookup · dig-style DNS.
/// Seat: CompanionRouter routes matching lines here BEFORE Heart so offline premier never refuses.
enum PingPongNetTest {
    static let commandName = "PINGPONG"
    static let schema = "PingPongNetTest.v1"
    static let maxPingCount = 5
    static let defaultPingCount = 3
    static let processTimeoutSec: TimeInterval = 12

    struct Result: Equatable {
        var text: String
        var ok: Bool
    }

    // MARK: - Detection

    /// True when draft / line looks like a net-test verb (for Send smart hint + router).
    static func looksLikeNetTest(_ raw: String) -> Bool {
        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        if lines.count == 1 {
            return classifyLine(lines[0]) != nil
        }
        // Multi-line: majority (or any pingpong header) seats the tree
        let hits = lines.filter { classifyLine($0) != nil }.count
        if lines.contains(where: { $0.lowercased().hasPrefix("pingpong") || $0.lowercased().hasPrefix("ping pong") }) {
            return true
        }
        return hits >= 1 && hits * 2 >= lines.count
    }

    /// Entry from CompanionRouter — nil if not a pingpong / net-test utterance.
    static func handleClay(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        // Explicit tree root
        if lower == "pingpong" || lower == "ping pong" || lower == "pingpong help" || lower == "ping pong help" {
            return helpText()
        }
        if lower.hasPrefix("pingpong ") || lower.hasPrefix("ping pong ") {
            var rest = text
            for p in ["pingpong ", "PINGPONG ", "Pingpong ", "ping pong ", "PING PONG ", "Ping Pong "] {
                if rest.lowercased().hasPrefix(p.lowercased()) {
                    rest = String(rest.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            if rest.isEmpty { return helpText() }
            return runBlock(rest)
        }

        // Direct verbs / multi-line net tests (not bare companion ping)
        guard looksLikeNetTest(text) else { return nil }
        return runBlock(text)
    }

    // MARK: - Classify

    private enum Verb {
        case ping(host: String, count: Int)
        case nslookup(host: String)
        case dig(host: String)
    }

    private static func classifyLine(_ line: String) -> Verb? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()

        // Bare companion heartbeat — NEVER steal
        if lower == "ping" || lower == "utah ping" { return nil }

        // pingpong <sub…> already stripped by handleClay; here accept sub-lines
        if lower.hasPrefix("pingpong ") || lower.hasPrefix("ping pong ") {
            var rest = trimmed
            for p in ["pingpong ", "ping pong "] {
                if lower.hasPrefix(p) {
                    rest = String(trimmed.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            return classifyLine(rest)
        }

        let tokens = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard let head = tokens.first?.lowercased() else { return nil }

        if head == "ping" {
            return parsePing(tokens: Array(tokens.dropFirst()), original: trimmed)
        }
        if head == "nslookup" || head == "host" {
            guard tokens.count >= 2 else { return nil }
            let host = sanitizeHost(tokens[1])
            guard !host.isEmpty else { return nil }
            return .nslookup(host: host)
        }
        if head == "dig" {
            guard tokens.count >= 2 else { return nil }
            let host = sanitizeHost(tokens[1])
            guard !host.isEmpty else { return nil }
            return .dig(host: host)
        }
        return nil
    }

    /// ping [-c N] host   |   ping host -c N   |   PING -C 3 1.1.1.1
    private static func parsePing(tokens: [String], original: String) -> Verb? {
        var count = defaultPingCount
        var host: String?
        var i = 0
        while i < tokens.count {
            let t = tokens[i]
            let tl = t.lowercased()
            if tl == "-c" || tl == "-n" || tl == "--count" {
                if i + 1 < tokens.count, let n = Int(tokens[i + 1]) {
                    count = clampCount(n)
                    i += 2
                    continue
                }
            }
            if tl.hasPrefix("-c"), let n = Int(String(tl.dropFirst(2))), !tl.dropFirst(2).isEmpty {
                count = clampCount(n)
                i += 1
                continue
            }
            // skip other flags we don't seat
            if t.hasPrefix("-") {
                i += 1
                continue
            }
            if host == nil {
                host = sanitizeHost(t)
            }
            i += 1
        }
        guard let h = host, !h.isEmpty else { return nil }
        // Require an actual host arg so bare "ping" never arrives here
        _ = original
        return .ping(host: h, count: count)
    }

    private static func clampCount(_ n: Int) -> Int {
        max(1, min(maxPingCount, n))
    }

    private static func sanitizeHost(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip surrounding punctuation from chat paste
        while let c = s.first, "!.,;:\"'()[]{}".contains(c) { s.removeFirst() }
        while let c = s.last, "!.,;:\"'()[]{}".contains(c) { s.removeLast() }
        // Allow hostname / IPv4 / IPv6-ish — reject empty / path / URL schemes
        if s.isEmpty { return "" }
        if s.contains("://") || s.contains("/") || s.contains(" ") { return "" }
        let ok = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-:_"))
        if s.unicodeScalars.contains(where: { !ok.contains($0) }) { return "" }
        return s
    }

    // MARK: - Run

    private static func runBlock(_ text: String) -> String {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [String] = ["\(commandName) · \(schema) · local net-test (not Heart)"]
        var any = false
        for line in lines {
            guard let verb = classifyLine(line) else {
                out.append("SKIP · not a net-test verb: \(line)")
                continue
            }
            any = true
            out.append(runVerb(verb))
        }
        if !any {
            return helpText() + "\n(no runnable net-test line in input)"
        }
        return out.joined(separator: "\n\n")
    }

    private static func runVerb(_ verb: Verb) -> String {
        switch verb {
        case .ping(let host, let count):
            return ping(host: host, count: count)
        case .nslookup(let host):
            return dnsLookup(host: host, digStyle: false)
        case .dig(let host):
            return dnsLookup(host: host, digStyle: true)
        }
    }

    // MARK: - Ping

    private static func ping(host: String, count: Int) -> String {
        #if os(macOS)
        return runProcess(
            label: "PING · \(host) · count \(count)",
            launchPath: "/sbin/ping",
            alternate: "/usr/bin/ping",
            arguments: ["-c", "\(count)", "-W", "2000", host]
        )
        #else
        return iosReachabilityProbe(host: host, count: count)
        #endif
    }

    // MARK: - DNS

    private static func dnsLookup(host: String, digStyle: Bool) -> String {
        #if os(macOS)
        if digStyle {
            return runProcess(
                label: "DIG · \(host)",
                launchPath: "/usr/bin/dig",
                alternate: "/usr/bin/dig",
                arguments: ["+time=3", "+tries=1", "+short", host]
            )
        }
        return runProcess(
            label: "NSLOOKUP · \(host)",
            launchPath: "/usr/bin/nslookup",
            alternate: "/usr/bin/host",
            arguments: [host]
        )
        #else
        return iosDNSResolve(host: host, digStyle: digStyle)
        #endif
    }

    // MARK: - macOS Process

    #if os(macOS)
    private static func runProcess(
        label: String,
        launchPath: String,
        alternate: String,
        arguments: [String]
    ) -> String {
        let path: String
        if FileManager.default.isExecutableFile(atPath: launchPath) {
            path = launchPath
        } else if FileManager.default.isExecutableFile(atPath: alternate) {
            path = alternate
        } else {
            return "\(label)\nFAIL · tool missing (\(launchPath))"
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return "\(label)\nFAIL · launch: \(error.localizedDescription)"
        }

        let deadline = Date().addingTimeInterval(processTimeoutSec)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            return "\(label)\nFAIL · timed out after \(Int(processTimeoutSec))s"
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let code = proc.terminationStatus
        var body = out
        if body.isEmpty, !err.isEmpty { body = err }
        else if !err.isEmpty, err != out { body = (body.isEmpty ? err : body + "\n" + err) }
        if body.isEmpty { body = "(no output · exit \(code))" }
        let status = code == 0 ? "OK" : "EXIT \(code)"
        return "\(label) · \(status)\n\(body)"
    }
    #endif

    // MARK: - iOS stubs (platform APIs — same verbs)

    #if !os(macOS)
    private static func iosReachabilityProbe(host: String, count: Int) -> String {
        #if canImport(Network)
        let n = clampCount(count)
        var lines: [String] = ["PING · \(host) · count \(n) · ios NWConnection probe (no raw ICMP)"]
        let group = DispatchGroup()
        var ok = 0
        for i in 1...n {
            group.enter()
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: 443)
            let conn = NWConnection(to: endpoint, using: .tcp)
            let q = DispatchQueue(label: "ya.pingpong.\(i)")
            var finished = false
            let finish: (String) -> Void = { msg in
                guard !finished else { return }
                finished = true
                lines.append("seq \(i): \(msg)")
                if msg.hasPrefix("ok") { ok += 1 }
                conn.cancel()
                group.leave()
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish("ok · tcp/443 ready")
                case .failed(let e):
                    finish("fail · \(e.localizedDescription)")
                case .cancelled:
                    finish("cancelled")
                default:
                    break
                }
            }
            conn.start(queue: q)
            q.asyncAfter(deadline: .now() + 3.0) {
                finish("fail · timeout")
            }
            _ = group.wait(timeout: .now() + 4.0)
        }
        lines.append("--- \(n) probes, \(ok) ready · \(schema)")
        return lines.joined(separator: "\n")
        #else
        return "PING · \(host) · ios seat lacks Network framework"
        #endif
    }

    private static func iosDNSResolve(host: String, digStyle: Bool) -> String {
        let label = digStyle ? "DIG" : "NSLOOKUP"
        var results: [String] = []
        let hostRef = CFHostCreateWithName(kCFAllocatorDefault, host as CFString).takeRetainedValue()
        var resolved: DarwinBoolean = false
        let ok = CFHostStartInfoResolution(hostRef, .addresses, nil)
        if ok {
            if let addrs = CFHostGetAddressing(hostRef, &resolved)?.takeUnretainedValue() as? [Data] {
                for data in addrs {
                    data.withUnsafeBytes { raw in
                        guard let ptr = raw.bindMemory(to: sockaddr.self).baseAddress else { return }
                        var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let r = getnameinfo(ptr, socklen_t(data.count), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST)
                        if r == 0 {
                            results.append(String(cString: hostBuf))
                        }
                    }
                }
            }
        }
        if results.isEmpty {
            // getaddrinfo fallback
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var info: UnsafeMutablePointer<addrinfo>?
            let g = getaddrinfo(host, nil, &hints, &info)
            defer { if let info { freeaddrinfo(info) } }
            if g == 0, let first = info {
                var p: UnsafeMutablePointer<addrinfo>? = first
                while let cur = p {
                    var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if let addr = cur.pointee.ai_addr {
                        let r = getnameinfo(addr, cur.pointee.ai_addrlen, &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST)
                        if r == 0 {
                            let s = String(cString: hostBuf)
                            if !results.contains(s) { results.append(s) }
                        }
                    }
                    p = cur.pointee.ai_next
                }
            }
        }
        if results.isEmpty {
            return "\(label) · \(host) · FAIL · no addresses"
        }
        return "\(label) · \(host) · OK\n" + results.joined(separator: "\n")
    }
    #endif

    static func helpText() -> String {
        """
        \(commandName) · \(schema)
        Local device network TEST (offline-premier companion stays Heart; these are Decider test probes).
        Verbs:
          ping [-c N] <host>     count capped \(maxPingCount) (default \(defaultPingCount))
          nslookup <host>
          dig <host>
          pingpong <verb…>       explicit tree root
        Examples:
          PING -C 3 1.1.1.1
          NSLOOKUP APPLE.COM
          pingpong ping -c 2 127.0.0.1
        Note: bare `ping` still means companion heartbeat → here (not ICMP).
        """
    }
}
