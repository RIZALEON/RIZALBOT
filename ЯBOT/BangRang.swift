import Foundation

/// BANGЯANG (0.3.3) — superfunction on TRUEBLAST + TOKENBLAST + ping-pong.
/// Exactly 1.0 Я goes main wallet → boomerang wallet, then 1.0 Я comes straight back. Both legs are real
/// Solana mainnet SPL transfers of mint BB9uA5…Q1Lv (visible on Solscan/trackers). TOKENBLAST probes run
/// before, between and after; both legs (signature · slot · balances · verdict) land in the ghost chain ledger.
/// Verbs: bangrang · bangяang · boomerang · bang rang   [+ one | two | dry]  ·  bangrang return <leg-1 sig>
/// Modes:
///   one-device (default when a boomerang key is seated here): boomerang = second keypair in THIS device's Keychain.
///     ONE confirmation sheet lists both legs, both fees, any first-time ATA rent, network and total; that single tap
///     authorizes exactly those two transfers, once (leg 2 fee is paid by the main wallet so the boomerang needs no SOL).
///   two-device: boomerang = the sibling device seat. Leg 1 is signed here after the tap. The return leg is signed only
///     on the sibling device, after ITS OWN confirmation sheet (opened by `bangrang return <sig>` via paste-pair /
///     link). A message from another device can never make this device sign by itself.
/// No retries, no loops, no repeat sends without a new tap. Keys: created only by the user's tap, Keychain only.
enum BangRang {
    static let verbs = ["bangrang", "bangяang", "boomerang", "bang rang"]

    static func matches(_ lower: String) -> Bool {
        verbs.contains { lower == $0 || lower.hasPrefix($0 + " ") }
    }

    static func handle(_ raw: String) -> String {
        let lower = raw.lowercased()
        let words = lower.split(separator: " ").map(String.init)
        let online = ModeStore.shared.isOnline
        var out = ["BANGЯANG · \(TrueBlast.network)",
                   "Purpose: 1.0 Я out to the boomerang wallet and 1.0 Я straight back — two public legs, probes before/between/after.", ""]
        if words.contains("return") {
            let sig = raw.split(separator: " ").last.map(String.init) ?? ""
            return (out + [returnLeg(leg1Signature: sig, online: online)]).joined(separator: "\n")
        }
        let dry = words.contains("dry")
        guard online || dry else {
            out.append("LIVE refused — OFFLINE. Flip ONLINE. Seats:")
            out.append(YaDeviceWallets.seatsBlock())
            return out.joined(separator: "\n")
        }
        let wantTwo = words.contains("two") || (!words.contains("one") && YaDeviceWallets.boomerang == nil)
        let plan = wantTwo ? twoDeviceQuote() : oneDeviceQuote()
        switch plan {
        case .failure(let why):
            out.append("ROUND TRIP · not quoted (\(wantTwo ? "two-device" : "one-device")) — \(why)")
            out.append(YaDeviceWallets.seatsBlock())
        case .success(let q):
            out.append(q.summary)
            out.append(YaDeviceWallets.seatsBlock())
            if dry {
                out.append("DRY · nothing signed. Say `bangrang` for LIVE (one confirmation sheet for the round trip).")
                out.append(TokenBlastProbe.shortProbe(label: "dry").text)
            } else {
                BlastCenter.shared.present(q)
                out.append("LIVE · ONE confirmation sheet opened on the Wallet landing. Nothing is signed until you tap Confirm.")
            }
        }
        return out.joined(separator: "\n")
    }

    static func oneDeviceQuote() -> BlastPlanner.Plan {
        guard YaDeviceWallets.hasKey(.main), let me = YaDeviceWallets.local else { return .failure("main key not seated — Wallet landing → Seat device key.") }
        guard YaDeviceWallets.hasKey(.boomerang), let boom = YaDeviceWallets.boomerang else { return .failure("boomerang key not seated — Wallet landing → Seat boomerang key (your tap).") }
        let l1 = BlastPlanner.leg(title: "out", from: me, fromRole: .main, to: boom, feePayer: .main, signatures: 1, allowCreate: true)
        guard case .ok(let out) = l1 else { if case .no(let w) = l1 { return .failure(w) }; return .failure("?") }
        // leg 2: boomerang is owner, main pays fee (2 signatures). Balance is checked live between legs.
        let back = BlastLeg(title: "back", fromLabel: boom.label, fromOwner: boom.pubkey, fromATA: boom.ata,
                            toLabel: me.label, toOwner: me.pubkey, toATA: me.ata, ownerRole: .boomerang, feePayerRole: .main,
                            createDestATA: false, feeLamports: 2 * TokenBlastProbe.lamportsPerSignature, rentLamports: 0)
        var q = BlastQuote(kind: .bangrang, legs: [out, back])
        q.note = "one-device · both keys in this device's Keychain · leg 2 fee paid by \(me.label)"
        if let w = BlastPlanner.checkSOL(q, payer: me) { return .failure(w) }
        return .success(q)
    }

    static func twoDeviceQuote() -> BlastPlanner.Plan {
        guard YaDeviceWallets.hasKey(.main), let me = YaDeviceWallets.local else { return .failure("main key not seated — Wallet landing → Seat device key.") }
        guard let sib = YaDeviceWallets.sibling else { return .failure("sibling pubkey missing — paste-pair first (\(YaDeviceWallets.SyncStatus.pasteNeeded.rawValue)).") }
        let l1 = BlastPlanner.leg(title: "out", from: me, fromRole: .main, to: sib, feePayer: .main, signatures: 1, allowCreate: true)
        guard case .ok(let out) = l1 else { if case .no(let w) = l1 { return .failure(w) }; return .failure("?") }
        let back = BlastLeg(title: "back", fromLabel: sib.label, fromOwner: sib.pubkey, fromATA: sib.ata,
                            toLabel: me.label, toOwner: me.pubkey, toATA: me.ata, ownerRole: .main, feePayerRole: .main,
                            createDestATA: false, feeLamports: TokenBlastProbe.lamportsPerSignature, rentLamports: 0, remote: true)
        var q = BlastQuote(kind: .bangrang, legs: [out, back])
        q.note = "two-device · return leg is signed on \(sib.label) after its own tap (send it: bangrang return <leg-1 sig>)"
        if let w = BlastPlanner.checkSOL(q, payer: me) { return .failure(w) }
        return .success(q)
    }

    /// On the sibling device: leg 1 must be confirmed on-chain, then THIS device's own sheet quotes the 1.0 Я return.
    static func returnLeg(leg1Signature sig: String, online: Bool) -> String {
        guard online else { return "RETURN refused — OFFLINE." }
        guard sig.count >= 64, sig.count <= 90 else { return "HOW: bangrang return <leg-1 signature>" }
        guard let st = TokenBlastProbe.signatureStatus(sig), st.err == nil, st.status == "confirmed" || st.status == "finalized" else {
            return "RETURN refused — leg 1 \(YaDeviceWallets.short(sig)) is not confirmed on-chain."
        }
        guard YaDeviceWallets.hasKey(.main), let me = YaDeviceWallets.local else { return "RETURN refused — this device has no seated key." }
        guard let sib = YaDeviceWallets.sibling else { return "RETURN refused — sibling pubkey missing (paste-pair)." }
        switch BlastPlanner.leg(title: "back (return of \(YaDeviceWallets.short(sig)))", from: me, fromRole: .main, to: sib, feePayer: .main, signatures: 1, allowCreate: false) {
        case .no(let w): return "RETURN not quoted — \(w)"
        case .ok(let l):
            var q = BlastQuote(kind: .bangrangReturn, legs: [l])
            q.note = "return leg for \(sig)"
            if let w = BlastPlanner.checkSOL(q, payer: me) { return "RETURN not quoted — \(w)" }
            BlastCenter.shared.present(q)
            return q.summary + "\nConfirmation sheet opened on this device. Nothing is signed until you tap Confirm."
        }
    }
}
