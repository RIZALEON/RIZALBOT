import Foundation

/// TOKENBLAST PROBE (0.3.3) — the shared, read-only pipe-report engine used by TOKENBLAST,
/// TRUEBLAST and BANGЯANG. RPC getAccountInfo/getTokenSupply · Jupiter lite · Dexscreener ·
/// GeckoTerminal → PERFECTION / PECULIARITY / STRANGENESS + VERDICT.
/// NonNuclear: reads only. No signing, no sends, no keys. Explorers are mirrors — clay owns source.
enum TokenBlastProbe {
    static let rpcURL = URL(string: "https://api.mainnet-beta.solana.com")!

    /// Full TOKENBLAST readout (identical text to the 0.3.2 TokenBlast.run).
    static func report(mintArg: String? = nil) -> String {
        let purpose = "Purpose: shove the twin through live digital plumbing and read every mirror."
        let intent = "Intent: track·trace·verify — report perfection / peculiarity / strangeness on the way back. No spend."

        let trimmed = mintArg?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mint = (trimmed?.isEmpty == false ? trimmed! : YaTwinChain.mint)

        guard mint.count >= 32, mint.count <= 44 else {
            return """
            TOKENBLAST FAIL
            \(purpose)
            \(intent)
            Mint looks wrong: \(mint)
            HOW: tokenblast   OR   tokenblast <mintAddress>
            """
        }

        let online = ModeStore.shared.isOnline
        var lines: [String] = [
            "TOKENBLAST · Solana mainnet",
            purpose,
            intent,
            "Target mint: \(mint)",
            "Crown seat: \(YaTwinChain.crownName) / \(YaTwinChain.crownSymbol)",
            "Mode: \(online ? "ONLINE (live pipes)" : "OFFLINE (hardcoded twin + local seats only)")",
            ""
        ]

        var perfect: [String] = []
        var peculiar: [String] = []
        var strange: [String] = []

        if mint == YaTwinChain.mint {
            perfect.append("Mint matches hardcoded YaTwinChain crown seat.")
        } else {
            peculiar.append("Blast mint ≠ seated crown twin. Citing Decider-pasted mint.")
        }

        if !online {
            lines.append("PIPE · offline")
            lines.append("  Skipped live RPC/Dex/Jupiter — flip ONLINE to blast the rails.")
            lines.append("  Local twin: supply \(YaTwinChain.supplyUI) · decimals \(YaTwinChain.decimals) · status \(YaTwinChain.status)")
            lines.append("  ATA \(YaTwinChain.ownerATA)")
            lines.append("  Mint tx \(YaTwinChain.mintSignature)")
            strange.append("Blast ran offline — mirrors not queried this turn.")
            return finish(lines: lines, perfect: perfect, peculiar: peculiar, strange: strange)
        }

        // RPC account
        let acct = rpc("getAccountInfo", params: [mint, ["encoding": "jsonParsed"]])
        if let value = ((acct?["result"] as? [String: Any])?["value"] as? [String: Any]) {
            let owner = value["owner"] as? String ?? "?"
            if owner.contains("Token") {
                perfect.append("RPC: mint account live under SPL Token program.")
            } else {
                strange.append("RPC: account owner is not Token program (\(owner.prefix(16))…).")
            }
            if let info = ((value["data"] as? [String: Any])?["parsed"] as? [String: Any])?["info"] as? [String: Any] {
                let dec = info["decimals"] as? Int ?? -1
                let supply = info["supply"] as? String ?? "?"
                let mintAuth = stringish(info["mintAuthority"])
                let freeze = stringish(info["freezeAuthority"])
                lines.append("PIPE · Solana RPC (getAccountInfo)")
                lines.append("  decimals \(dec) · supply_raw \(supply)")
                lines.append("  mintAuthority \(mintAuth)")
                lines.append("  freezeAuthority \(freeze)")
                if dec == YaTwinChain.decimals {
                    perfect.append("RPC decimals match crown seat (\(dec)).")
                } else {
                    peculiar.append("RPC decimals \(dec) ≠ crown \(YaTwinChain.decimals).")
                }
                if mintAuth == YaTwinChain.mintAuthority {
                    perfect.append("Mint authority matches crown seat.")
                } else if mintAuth == "null" {
                    peculiar.append("Mint authority renounced (null) — supply locked.")
                } else {
                    peculiar.append("Mint authority differs from crown seat.")
                }
                if freeze != "null" {
                    peculiar.append("Freeze authority still set.")
                } else {
                    perfect.append("Freeze authority null.")
                }
            }
        } else if let err = acct?["error"] {
            strange.append("RPC getAccountInfo error: \(err)")
            lines.append("PIPE · Solana RPC — FAIL")
        } else {
            strange.append("RPC returned no mint account — explorers may say not found.")
            lines.append("PIPE · Solana RPC — account NULL")
        }

        if let val = ((rpc("getTokenSupply", params: [mint])?["result"] as? [String: Any])?["value"] as? [String: Any]) {
            let ui = val["uiAmountString"] as? String ?? "\(val["uiAmount"] ?? "?")"
            lines.append("PIPE · Solana RPC (getTokenSupply) → \(ui)")
            if ui == YaTwinChain.supplyUI || ui.hasPrefix(YaTwinChain.supplyUI) {
                perfect.append("Supply \(ui) matches crown seat.")
            } else {
                peculiar.append("Supply \(ui) ≠ crown \(YaTwinChain.supplyUI).")
            }
        } else {
            strange.append("getTokenSupply empty/fail.")
        }

        lines.append("PIPE · Jupiter lite search")
        if let arr = getArray("https://lite-api.jup.ag/tokens/v2/search?query=\(mint)") {
            if let hit = arr.first(where: { ($0["id"] as? String) == mint }) ?? arr.first {
                let name = hit["name"] as? String ?? ""
                let sym = hit["symbol"] as? String ?? ""
                let circ = hit["circSupply"] ?? hit["totalSupply"] ?? "?"
                let holders = hit["holderCount"] ?? "?"
                let organic = hit["organicScore"] ?? "?"
                let tags = (hit["tags"] as? [String])?.joined(separator: ",") ?? ""
                lines.append("  name '\(name)' · symbol '\(sym)' · supply \(circ) · holders \(holders)")
                lines.append("  organicScore \(organic) · tags \(tags)")
                if name == "Я" || name == YaTwinChain.crownName {
                    perfect.append("Jupiter shows crown name Я.")
                } else if name.isEmpty {
                    peculiar.append("Jupiter indexes mint but name/symbol blank (URI empty or lag).")
                } else {
                    strange.append("Jupiter name '\(name)' ≠ crown Я.")
                }
                if let h = holders as? Int {
                    if h == 1 { perfect.append("Single holder — full supply on seat ATA (pre-pool).") }
                    else if h > 1 { peculiar.append("Holder count \(h) — twin moved beyond single seat.") }
                }
            } else {
                peculiar.append("Jupiter returned no exact mint hit yet.")
                lines.append("  (no exact hit)")
            }
        } else {
            strange.append("Jupiter lite unreachable from this seat.")
            lines.append("  unreachable")
        }

        lines.append("PIPE · Dexscreener")
        if let dex = getDict("https://api.dexscreener.com/latest/dex/tokens/\(mint)") {
            let pairs = dex["pairs"] as? [Any]
            if pairs == nil || pairs?.isEmpty == true {
                lines.append("  pairs: null/empty")
                perfect.append("Dexscreener quiet — no pool yet (expected).")
            } else {
                lines.append("  pairs: \(pairs!.count)")
                peculiar.append("Dexscreener has \(pairs!.count) pair(s) — market plumbing awake.")
            }
        } else {
            strange.append("Dexscreener unreachable.")
            lines.append("  unreachable")
        }

        lines.append("PIPE · GeckoTerminal")
        if let gecko = getDict("https://api.geckoterminal.com/api/v2/networks/solana/tokens/\(mint)") {
            if gecko["errors"] != nil {
                lines.append("  not listed / errors")
                perfect.append("GeckoTerminal unlisted — fine pre-pool.")
            } else {
                lines.append("  listed")
                peculiar.append("GeckoTerminal already lists this mint.")
            }
        } else {
            lines.append("  no clean payload (often 404)")
            peculiar.append("GeckoTerminal did not return a clean token payload.")
        }

        lines.append("PIPE · Clay seat (YaTwinChain)")
        lines.append("  ATA \(YaTwinChain.ownerATA)")
        lines.append("  mint tx \(YaTwinChain.mintSignature)")
        lines.append("  slot \(YaTwinChain.slot) · status \(YaTwinChain.status)")

        return finish(lines: lines, perfect: perfect, peculiar: peculiar, strange: strange)
    }

    private static func finish(lines: [String], perfect: [String], peculiar: [String], strange: [String]) -> String {
        var out = lines
        out.append("")
        out.append("ALONG THE WAY")
        out.append("  PERFECTION (\(perfect.count))")
        if perfect.isEmpty { out.append("    — none noted") }
        else { for p in perfect { out.append("    ✓ \(p)") } }
        out.append("  PECULIARITY (\(peculiar.count))")
        if peculiar.isEmpty { out.append("    — none noted") }
        else { for p in peculiar { out.append("    ~ \(p)") } }
        out.append("  STRANGENESS (\(strange.count))")
        if strange.isEmpty { out.append("    — none noted") }
        else { for s in strange { out.append("    ! \(s)") } }

        let verdict = verdictLine(perfect: perfect, peculiar: peculiar, strange: strange)
        out.append("")
        out.append(verdict)
        out.append("Law: explorers are mirrors — clay owns source. Crown Я.")
        return out.joined(separator: "\n")
    }

    /// VERDICT rule shared by every blast report.
    static func verdictLine(perfect: [String], peculiar: [String], strange: [String]) -> String {
        let verdict: String
        if !strange.isEmpty && perfect.isEmpty {
            verdict = "VERDICT: strange — twin may be missing or pipes clogged."
        } else if !strange.isEmpty {
            verdict = "VERDICT: mixed — live on rail, some mirrors clogged or lagging."
        } else if !peculiar.isEmpty {
            verdict = "VERDICT: peculiar-but-alive — on rail; oddities mostly index/pool lag."
        } else {
            verdict = "VERDICT: perfection path — mint live, seats agree, quiet markets as expected."
        }
        return verdict
    }

    static func stringish(_ any: Any?) -> String {
        if any == nil || any is NSNull { return "null" }
        if let s = any as? String { return s }
        return "\(any!)"
    }

    static func rpc(_ method: String, params: [Any]) -> [String: Any]? {
        let body: [String: Any] = ["jsonrpc": "2.0", "id": 1, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: rpcURL, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        return sendDict(req)
    }

    static func getDict(_ urlString: String) -> [String: Any]? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("YaBOT-TOKENBLAST/1.0", forHTTPHeaderField: "User-Agent")
        return sendDict(req)
    }

    static func getArray(_ urlString: String) -> [[String: Any]]? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("YaBOT-TOKENBLAST/1.0", forHTTPHeaderField: "User-Agent")
        let sem = DispatchSemaphore(value: 0)
        var out: [[String: Any]]?
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { sem.signal() }
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            out = obj
        }.resume()
        _ = sem.wait(timeout: .now() + 14)
        return out
    }

    static func sendDict(_ req: URLRequest) -> [String: Any]? {
        let sem = DispatchSemaphore(value: 0)
        var out: [String: Any]?
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { sem.signal() }
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            out = obj
        }.resume()
        _ = sem.wait(timeout: .now() + 14)
        return out
    }

    // MARK: - Read-only RPC helpers shared by TRUEBLAST / BANGЯANG (no signing here)

    /// Base fee per signature on Solana mainnet (lamports). Priority fees are never added by ЯBOT.
    static let lamportsPerSignature: UInt64 = 5000

    /// `getLatestBlockhash` (finalized) → blockhash string.
    static func latestBlockhash() -> String? {
        let r = rpc("getLatestBlockhash", params: [["commitment": "finalized"]])
        return ((r?["result"] as? [String: Any])?["value"] as? [String: Any])?["blockhash"] as? String
    }

    /// true / false when the RPC answered; nil when the pipe failed.
    static func accountExists(_ address: String) -> Bool? {
        guard let r = rpc("getAccountInfo", params: [address, ["encoding": "base64"]]) else { return nil }
        if r["error"] != nil { return nil }
        guard let result = r["result"] as? [String: Any] else { return nil }
        return !(result["value"] is NSNull) && result["value"] != nil
    }

    /// SPL token account balance → (raw, ui string); nil when missing / pipe failed.
    static func tokenBalance(_ tokenAccount: String) -> (raw: UInt64, ui: String)? {
        guard let v = ((rpc("getTokenAccountBalance", params: [tokenAccount])?["result"] as? [String: Any])?["value"] as? [String: Any]),
              let amt = v["amount"] as? String, let raw = UInt64(amt) else { return nil }
        return (raw, v["uiAmountString"] as? String ?? amt)
    }

    /// Native SOL balance in lamports.
    static func solBalance(_ address: String) -> UInt64? {
        let r = rpc("getBalance", params: [address])
        if let n = (r?["result"] as? [String: Any])?["value"] as? NSNumber { return n.uint64Value }
        return nil
    }

    /// Rent-exempt minimum for an SPL token account (165 bytes).
    static func tokenAccountRent() -> UInt64? {
        let r = rpc("getMinimumBalanceForRentExemption", params: [165])
        return (r?["result"] as? NSNumber)?.uint64Value
    }

    /// Current slot (read-only).
    static func currentSlot() -> UInt64? {
        (rpc("getSlot", params: [["commitment": "confirmed"]])?["result"] as? NSNumber)?.uint64Value
    }

    /// One status read for a signature → (slot, confirmationStatus, err). Reading status is not a resend.
    static func signatureStatus(_ sig: String) -> (slot: UInt64, status: String, err: String?)? {
        let r = rpc("getSignatureStatuses", params: [[sig], ["searchTransactionHistory": true]])
        guard let arr = (r?["result"] as? [String: Any])?["value"] as? [Any],
              let first = arr.first as? [String: Any] else { return nil }
        let slot = (first["slot"] as? NSNumber)?.uint64Value ?? 0
        let st = first["confirmationStatus"] as? String ?? "processed"
        let err: String? = (first["err"] == nil || first["err"] is NSNull) ? nil : "\(first["err"]!)"
        return (slot, st, err)
    }

    /// Wait (read-only status reads, ≤ timeout) until a signature is confirmed/finalized.
    static func waitConfirmed(_ sig: String, timeout: TimeInterval = 60) -> (slot: UInt64, status: String, err: String?)? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let s = signatureStatus(sig), s.status == "confirmed" || s.status == "finalized" || s.err != nil { return s }
            Thread.sleep(forTimeInterval: 2)
        }
        return signatureStatus(sig)
    }

    /// Submit ONE already-signed transaction (base64). Called exactly once per confirmed leg — never looped here.
    /// Returns (signature, error text).
    static func submitSignedOnce(base64 tx: String) -> (sig: String?, error: String?) {
        let r = rpc("sendTransaction", params: [tx, ["encoding": "base64", "preflightCommitment": "confirmed"]])
        if let sig = r?["result"] as? String { return (sig, nil) }
        if let err = r?["error"] as? [String: Any] { return (nil, err["message"] as? String ?? "\(err)") }
        return (nil, "RPC unreachable — nothing known to be sent")
    }

    /// Short probe (for before / between / after legs): verdict + counts, same pipes.
    static func shortProbe(label: String) -> (verdict: String, text: String) {
        let full = report(mintArg: nil)
        let verdict = full.split(separator: "\n").last(where: { $0.hasPrefix("VERDICT:") }).map(String.init) ?? "VERDICT: (none)"
        let counts = full.split(separator: "\n").filter { $0.contains("PERFECTION (") || $0.contains("PECULIARITY (") || $0.contains("STRANGENESS (") }
            .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " · ")
        return (verdict, "PROBE \(label): \(counts)\n  \(verdict)")
    }
}
