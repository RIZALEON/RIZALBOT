import Foundation
import SwiftUI
#if canImport(SolanaSwift)
import SolanaSwift
#endif

/// TRUEBLAST (0.3.3) — from THIS device, fire exactly 1.0 Я (mint BB9uA5…Q1Lv) into the sibling device
/// wallet on Solana mainnet, then run the full TOKENBLAST pipe report.
/// Verbs: trueblast · true blast · trueblast it · blast true  [+ dry]
/// Mode: LIVE by default (Decider order 2026-09-25). NonNuclear rule kept in code:
///   • every live send shows an on-device confirmation sheet (from · to · amount 1.0 Я · fee · network)
///   • signs only with this device's own Keychain key, only after the user taps Confirm
///   • no silent send · no auto-retry · no batching · one tap = one quoted transfer
///   • OFFLINE refuses live and still prints seats · keys never in JSON / logs / git
/// Report shape: TRANSFER · DEVICE WALLETS · PIPES · ALONG THE WAY · VERDICT
enum TrueBlast {
    static let amountRaw: UInt64 = 1_000_000_000 // 1.0 Я at 9 decimals
    static let amountUI = "1.0 Я"
    static let network = "Solana mainnet-beta"

    static let verbs = ["trueblast", "true blast", "trueblast it", "blast true"]

    static func matches(_ lower: String) -> Bool {
        verbs.contains { lower == $0 || lower.hasPrefix($0 + " ") }
    }

    /// Router entry. Returns report text; a live request opens the confirmation sheet (nothing is sent here).
    static func handle(_ lower: String) -> String {
        let dry = lower.hasSuffix(" dry") || lower.contains(" dry ")
        let online = ModeStore.shared.isOnline
        var out: [String] = ["TRUEBLAST · \(network)", "Purpose: move exactly \(amountUI) from this device to the sibling device wallet, then read every mirror.",
                             "Mode: \(dry ? "DRY (simulate — nothing signed)" : "LIVE (confirmation sheet required)")", ""]
        guard online || dry else {
            out.append("LIVE refused — OFFLINE. Flip ONLINE to blast. Seats:")
            out.append(YaDeviceWallets.seatsBlock())
            return out.joined(separator: "\n")
        }
        switch BlastPlanner.trueBlastQuote() {
        case .failure(let why):
            out.append("TRANSFER · not quoted — \(why)")
            out.append("")
            out.append(YaDeviceWallets.seatsBlock())
            if online { out.append(""); out.append(TokenBlastProbe.report(mintArg: nil)) }
            return out.joined(separator: "\n")
        case .success(let q):
            out.append(q.summary)
            out.append("")
            out.append(YaDeviceWallets.seatsBlock())
            if dry {
                out.append("")
                out.append("DRY · no sheet, no key read, no signature. Say `trueblast` for LIVE.")
                out.append(TokenBlastProbe.report(mintArg: nil))
            } else {
                BlastCenter.shared.present(q)
                out.append("")
                out.append("LIVE · confirmation sheet opened on the Wallet landing. Nothing is signed until you tap Confirm.")
            }
            return out.joined(separator: "\n")
        }
    }
}

// MARK: - Quotes (read-only planning; no keys touched)

struct BlastLeg: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var fromLabel: String
    var fromOwner: String
    var fromATA: String
    var toLabel: String
    var toOwner: String
    var toATA: String
    var ownerRole: YaDeviceWallets.Role
    var feePayerRole: YaDeviceWallets.Role
    var createDestATA: Bool
    var feeLamports: UInt64
    var rentLamports: UInt64
    /// true when this leg is signed on ANOTHER device (two-device BANGЯANG return)
    var remote: Bool = false
}

struct BlastQuote: Identifiable, Equatable {
    enum Kind: String { case trueblast = "TRUEBLAST", bangrang = "BANGЯANG", bangrangReturn = "BANGЯANG RETURN" }
    let id = UUID()
    var kind: Kind
    var legs: [BlastLeg]
    var network: String = TrueBlast.network
    var note: String = ""
    var createdAt = Date()

    var localLegs: [BlastLeg] { legs.filter { !$0.remote } }
    var totalFeeLamports: UInt64 { localLegs.reduce(0) { $0 + $1.feeLamports } }
    var totalRentLamports: UInt64 { localLegs.reduce(0) { $0 + $1.rentLamports } }
    var totalLamports: UInt64 { totalFeeLamports + totalRentLamports }

    static func sol(_ l: UInt64) -> String { String(format: "%.9f SOL", Double(l) / 1_000_000_000) }

    var summary: String {
        var s = ["TRANSFER · \(kind.rawValue) · \(network)"]
        for (i, l) in legs.enumerated() {
            s.append("  leg \(i + 1) \(l.title): \(TrueBlast.amountUI) · \(l.fromLabel) \(YaDeviceWallets.short(l.fromOwner)) → \(l.toLabel) \(YaDeviceWallets.short(l.toOwner))")
            s.append("    fee \(Self.sol(l.feeLamports))\(l.rentLamports > 0 ? " + ATA rent \(Self.sol(l.rentLamports)) (first-time)" : "")\(l.remote ? " · signed on the sibling device after ITS own tap" : "")")
        }
        s.append("  total from this device: \(Self.sol(totalLamports)) + \(localLegs.count == 2 ? "net 0 Я (round trip)" : TrueBlast.amountUI)")
        if !note.isEmpty { s.append("  note: \(note)") }
        return s.joined(separator: "\n")
    }
}

enum BlastPlanner {
    enum Plan { case success(BlastQuote), failure(String) }
    enum LegPlan { case ok(BlastLeg), no(String) }

    /// Checks one leg on-chain (read-only). allowCreate = may add first-time ATA creation (rent shown).
    static func leg(title: String, from: YaDeviceWallets.Seat, fromRole: YaDeviceWallets.Role,
                    to: YaDeviceWallets.Seat, feePayer: YaDeviceWallets.Role, signatures: UInt64,
                    allowCreate: Bool, remote: Bool = false, checkBalance: Bool = true) -> LegPlan {
        guard !from.ata.isEmpty, !to.ata.isEmpty else { return .no("ATA not derived yet (\(YaDeviceWallets.SyncStatus.ataPending.rawValue)).") }
        if !remote && checkBalance {
            guard let bal = TokenBlastProbe.tokenBalance(from.ata) else { return .no("\(from.label) Я account not found on-chain (fund it first).") }
            guard bal.raw >= TrueBlast.amountRaw else { return .no("\(from.label) holds \(bal.ui) Я — needs 1.0.") }
        }
        var create = false
        var rent: UInt64 = 0
        switch TokenBlastProbe.accountExists(to.ata) {
        case .some(true): break
        case .some(false):
            guard allowCreate else { return .no("\(to.label) Я account (ATA) does not exist yet — \(YaDeviceWallets.SyncStatus.ataPending.rawValue). TRUEBLAST never creates accounts silently.") }
            guard let r = TokenBlastProbe.tokenAccountRent() else { return .no("RPC rent read failed.") }
            create = true; rent = r
        case .none: return .no("RPC unreachable — cannot verify \(to.label) account.")
        }
        return .ok(BlastLeg(title: title, fromLabel: from.label, fromOwner: from.pubkey, fromATA: from.ata,
                                 toLabel: to.label, toOwner: to.pubkey, toATA: to.ata, ownerRole: fromRole,
                                 feePayerRole: feePayer, createDestATA: create,
                                 feeLamports: signatures * TokenBlastProbe.lamportsPerSignature, rentLamports: rent, remote: remote))
    }

    static func checkSOL(_ q: BlastQuote, payer: YaDeviceWallets.Seat) -> String? {
        guard let lamports = TokenBlastProbe.solBalance(payer.pubkey) else { return "RPC SOL balance read failed." }
        return lamports >= q.totalLamports ? nil : "\(payer.label) has \(BlastQuote.sol(lamports)); needs \(BlastQuote.sol(q.totalLamports)) for fees/rent."
    }

    static func trueBlastQuote() -> Plan {
        guard YaDeviceWallets.hasKey(.main), let me = YaDeviceWallets.local else { return .failure("this device has no seated key — Wallet landing → Seat device key (your tap).") }
        guard let sib = YaDeviceWallets.sibling else { return .failure("sibling pubkey missing — \(YaDeviceWallets.SyncStatus.pasteNeeded.rawValue) (Wallet landing → paste-pair).") }
        switch leg(title: "send", from: me, fromRole: .main, to: sib, feePayer: .main, signatures: 1, allowCreate: false) {
        case .no(let w): return .failure(w)
        case .ok(let l):
            let q = BlastQuote(kind: .trueblast, legs: [l])
            if let w = checkSOL(q, payer: me) { return .failure(w) }
            return .success(q)
        }
    }
}

// MARK: - Confirmation center (one tap = exactly the quoted legs, once)

final class BlastCenter: ObservableObject {
    static let shared = BlastCenter()
    @Published var pending: BlastQuote? = nil
    @Published var running = false
    @Published var log: String = ""
    private var consumed = Set<UUID>()
    private let lock = NSLock()

    func present(_ q: BlastQuote) {
        DispatchQueue.main.async {
            guard !self.running else { return }
            self.pending = q
            NotificationCenter.default.post(name: Notification.Name("ЯBOT.OpenWallet"), object: nil)
        }
    }

    func cancel() {
        if let q = pending { MindTranscript.append(role: "system", kind: "\(q.kind.rawValue.lowercased())-cancel", body: "User cancelled on the confirmation sheet. Nothing signed.") }
        pending = nil
    }

    /// Called ONLY by the sheet's Confirm button. A quote can be executed once; a new send needs a new quote + tap.
    func confirm(_ q: BlastQuote) {
        lock.lock()
        let fresh = !consumed.contains(q.id) && !running && Date().timeIntervalSince(q.createdAt) < 120
        if fresh { consumed.insert(q.id) }
        lock.unlock()
        pending = nil
        guard fresh else { log = "Confirmation expired or already used — ask again for a new quote."; return }
        running = true
        log = "\(q.kind.rawValue) · confirmed by tap · running…"
        DispatchQueue.global(qos: .userInitiated).async {
            let text = BlastExecutor.run(q)
            DispatchQueue.main.async {
                self.running = false
                self.log = text
                MindTranscript.append(role: "assistant", kind: q.kind.rawValue.lowercased(), body: text)
            }
        }
    }
}

// MARK: - Executor (runs only from BlastCenter.confirm)

enum BlastExecutor {
    struct LegResult { var sig: String?; var slot: UInt64; var status: String; var error: String? }

    static func run(_ q: BlastQuote) -> String {
        var out: [String] = ["\(q.kind.rawValue) · LIVE · \(q.network)"]
        let before = TokenBlastProbe.shortProbe(label: "before")
        out.append(before.text)
        var results: [LegResult] = []
        for (i, leg) in q.legs.enumerated() {
            if leg.remote {
                out.append("leg \(i + 1) \(leg.title): waits for the sibling device — it opens its own sheet from: bangrang return \(results.last?.sig ?? "")")
                continue
            }
            let r = sendLeg(leg)
            results.append(r)
            let preFrom = TokenBlastProbe.tokenBalance(leg.fromATA)?.ui ?? "?" // balances after the leg
            let preTo = TokenBlastProbe.tokenBalance(leg.toATA)?.ui ?? "?"
            out.append("leg \(i + 1) \(leg.title): \(r.sig.map { "sig \($0)" } ?? "NOT SENT") · slot \(r.slot) · \(r.status)\(r.error.map { " · \($0)" } ?? "")")
            if let s = r.sig { out.append("  https://solscan.io/tx/\(s)") }
            out.append("  balances now: \(leg.fromLabel) \(preFrom) Я · \(leg.toLabel) \(preTo) Я")
            GhostChainLedger.append(op: "\(q.kind.rawValue.lowercased())-leg\(i + 1)", bio: "\(TrueBlast.amountUI) \(leg.fromLabel)→\(leg.toLabel)",
                                    extra: ["mint": YaDeviceWallets.mint, "from": leg.fromOwner, "to": leg.toOwner,
                                            "signature": r.sig ?? "", "slot": r.slot, "status": r.status, "error": r.error ?? "",
                                            "balance_from_ui": preFrom, "balance_to_ui": preTo, "network": q.network,
                                            "quote": q.id.uuidString])
            // No retry, no continuation after a failed leg.
            guard r.sig != nil, r.error == nil, r.status == "confirmed" || r.status == "finalized" else {
                out.append("STOP · leg \(i + 1) not confirmed — no retry, no further legs. A new send needs a new tap.")
                break
            }
            if i < q.legs.count - 1 { out.append(TokenBlastProbe.shortProbe(label: "between").text) }
        }
        let after = TokenBlastProbe.shortProbe(label: "after")
        out.append(after.text)
        out.append("")
        out.append(YaDeviceWallets.seatsBlock())
        let ok = results.allSatisfy { $0.error == nil && $0.sig != nil }
        let verdict = ok ? "VERDICT: \(q.kind.rawValue) landed — twin moved in public · \(after.verdict)" : "VERDICT: \(q.kind.rawValue) incomplete — see STOP · \(after.verdict)"
        out.append(verdict)
        GhostChainLedger.append(op: "\(q.kind.rawValue.lowercased())-verdict", bio: verdict,
                                extra: ["quote": q.id.uuidString, "legs": results.count, "probe_before": before.verdict, "probe_after": after.verdict])
        out.append("Law: explorers are mirrors — clay owns source. Crown Я.")
        return out.joined(separator: "\n")
    }

    /// Signs and submits ONE leg exactly once.
    static func sendLeg(_ leg: BlastLeg) -> LegResult {
        #if canImport(SolanaSwift)
        guard let owner = YaDeviceWallets.signer(leg.ownerRole) else { return LegResult(sig: nil, slot: 0, status: "unsigned", error: "Keychain key missing or does not match seat") }
        let payer = leg.feePayerRole == leg.ownerRole ? owner : YaDeviceWallets.signer(leg.feePayerRole)
        guard let payer else { return LegResult(sig: nil, slot: 0, status: "unsigned", error: "fee-payer key missing") }
        guard let bh = TokenBlastProbe.latestBlockhash() else { return LegResult(sig: nil, slot: 0, status: "unsigned", error: "blockhash read failed — nothing sent") }
        do {
            let mint = try PublicKey(string: YaDeviceWallets.mint)
            let tp = try PublicKey(string: YaDeviceWallets.tokenProgram)
            let toOwner = try PublicKey(string: leg.toOwner)
            let source = try PublicKey(string: leg.fromATA)
            let destination = try PublicKey(string: leg.toATA)
            // Refuse if the signer is not the seated owner of the source account.
            guard owner.publicKey.base58EncodedString == leg.fromOwner else {
                return LegResult(sig: nil, slot: 0, status: "unsigned", error: "signer ≠ quoted sender")
            }
            var ixs: [TransactionInstruction] = []
            if leg.createDestATA {
                let create = try AssociatedTokenProgram.createAssociatedTokenAccountInstruction(
                    mint: mint, owner: toOwner, payer: payer.publicKey, tokenProgramId: tp)
                ixs.append(create)
            }
            let transfer = TokenProgram.transferCheckedInstruction(
                source: source, mint: mint, destination: destination,
                owner: owner.publicKey, multiSigners: [], amount: TrueBlast.amountRaw, decimals: YaDeviceWallets.decimals)
            ixs.append(transfer)
            var tx = SolanaSwift.Transaction(instructions: ixs, recentBlockhash: bh, feePayer: payer.publicKey)
            try tx.sign(signers: payer.publicKey == owner.publicKey ? [owner] : [payer, owner])
            let b64 = try tx.serialize().base64EncodedString()
            let sent = TokenBlastProbe.submitSignedOnce(base64: b64)
            guard let sig = sent.sig else { return LegResult(sig: nil, slot: 0, status: "rejected", error: sent.error) }
            let st = TokenBlastProbe.waitConfirmed(sig)
            return LegResult(sig: sig, slot: st?.slot ?? 0, status: st?.status ?? "unknown (check Solscan)", error: st?.err)
        } catch {
            return LegResult(sig: nil, slot: 0, status: "unsigned", error: "build/sign failed: \(error.localizedDescription)")
        }
        #else
        return LegResult(sig: nil, slot: 0, status: "unsigned", error: "SEAM: SolanaSwift (p2p-org/solana-swift) not linked in this build — no transfer possible")
        #endif
    }
}

// MARK: - Confirmation sheet (the ONLY path to a signature)

struct BlastConfirmSheet: View {
    let quote: BlastQuote
    @ObservedObject var center = BlastCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONFIRM \(quote.kind.rawValue)")
                .font(ClayTheme.clayFont(size: 18, weight: .bold))
            Text("Network: \(quote.network)")
                .font(ClayTheme.clayFont(size: 12, weight: .semibold))
            ForEach(Array(quote.legs.enumerated()), id: \.offset) { i, l in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Leg \(i + 1) · \(l.title)\(l.remote ? " (sibling device, its own tap)" : "")")
                        .font(ClayTheme.clayFont(size: 12, weight: .bold))
                    Text("From: \(l.fromLabel)  \(l.fromOwner)").font(.system(size: 11, design: .monospaced))
                    Text("To:   \(l.toLabel)  \(l.toOwner)").font(.system(size: 11, design: .monospaced))
                    Text("Amount: exactly \(TrueBlast.amountUI)  (mint \(YaDeviceWallets.short(YaDeviceWallets.mint)))").font(.system(size: 11))
                    Text("Fee: \(BlastQuote.sol(l.feeLamports))\(l.rentLamports > 0 ? "  + first-time ATA rent \(BlastQuote.sol(l.rentLamports))" : "")").font(.system(size: 11))
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
            }
            Text("Total from this device: \(BlastQuote.sol(quote.totalLamports))")
                .font(ClayTheme.clayFont(size: 12, weight: .bold))
            Text("Signs with this device's own Keychain key only. One tap = exactly these \(quote.localLegs.count) transfer(s), once. No retry.")
                .font(ClayTheme.clayFont(size: 10, weight: .medium))
                .opacity(0.8)
            HStack {
                Button("Cancel", role: .cancel) { center.cancel() }
                Spacer()
                Button("Confirm & sign") { center.confirm(quote) }
                    .buttonStyle(.borderedProminent)
                    .disabled(center.running)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}
