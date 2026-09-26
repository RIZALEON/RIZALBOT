import Foundation
import Security
#if canImport(SolanaSwift)
import SolanaSwift
#endif

/// Я DEVICE WALLETS (0.3.3) — each device holds its OWN keypair in its own Keychain.
/// Seats (DeviceWalletSeat.json) store PUBKEYS + ATAs ONLY — never a secret, never in logs, never in git.
///   • DESKTOP WALLET = Mac seat · MOBILE WALLET = iPhone seat
///   • local  = this device's main key (Keychain account "main")
///   • sibling = the other device's pubkey (paste-pair, pubkey only)
///   • boomerang = optional second keypair on THIS device (Keychain account "boomerang") for one-device BANGЯANG
/// Keys are created only by the user's tap on the Wallet landing (with a confirm), never by chat words, links or bots.
enum YaDeviceWallets {
    static let mint = YaTwinChain.mint
    static let decimals: UInt8 = UInt8(YaTwinChain.decimals)
    static let tokenProgram = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let keychainService = "io.github.rizaleon.yaaim.devicewallet"

    enum Role: String { case main, boomerang }

    enum SyncStatus: String {
        case ok = "OK"
        case pasteNeeded = "PASTE_NEEDED"
        case ataPending = "PUBKEY_OK_ATA_PENDING"
        case keyNeeded = "KEY_NEEDED"
    }

    struct Seat: Equatable {
        var label: String
        var device: String
        var pubkey: String
        var ata: String
    }

    // MARK: - Platform labels

    static var localSeatName: String {
        #if os(macOS)
        return "desktop"
        #else
        return "mobile"
        #endif
    }
    static var siblingSeatName: String { localSeatName == "desktop" ? "mobile" : "desktop" }
    static func label(for seat: String) -> String {
        switch seat {
        case "desktop": return "DESKTOP WALLET"
        case "mobile": return "MOBILE WALLET"
        case "boomerang": return "BOOMERANG WALLET"
        default: return seat.uppercased()
        }
    }

    // MARK: - Seat file (pubkeys + ATAs only)

    static var seatURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ЯBOT/twin/DeviceWalletSeat.json")
    }

    static func loadSeatFile() -> [String: Any] {
        if let d = try? Data(contentsOf: seatURL),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return o }
        if let u = Bundle.main.url(forResource: "DeviceWalletSeat", withExtension: "json"),
           let d = try? Data(contentsOf: u),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { return o }
        return ["schema": "ya.device-wallet-seat.v1", "mint": mint, "seats": [String: Any]()]
    }

    /// Writes ONLY public fields. Any key that looks secret is refused.
    @discardableResult
    static func saveSeat(_ name: String, pubkey: String, ata: String) -> Bool {
        guard isPlausiblePubkey(pubkey), ata.isEmpty || isPlausiblePubkey(ata) else { return false }
        var file = loadSeatFile()
        var seats = file["seats"] as? [String: Any] ?? [:]
        seats[name] = [
            "label": label(for: name),
            "device": name == "boomerang" ? localSeatName : name,
            "pubkey": pubkey,
            "ata": ata,
            "updated": ISO8601DateFormatter().string(from: Date()),
        ]
        file["seats"] = seats
        file["schema"] = "ya.device-wallet-seat.v1"
        file["mint"] = mint
        file["law"] = "Pubkeys + ATAs only. Private keys live in each device's Keychain and never leave it."
        guard let data = try? JSONSerialization.data(withJSONObject: file, options: [.prettyPrinted, .sortedKeys]) else { return false }
        try? FileManager.default.createDirectory(at: seatURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: seatURL, options: .atomic)) != nil
    }

    static func seat(_ name: String) -> Seat? {
        guard let s = (loadSeatFile()["seats"] as? [String: Any])?[name] as? [String: Any],
              let pk = s["pubkey"] as? String, !pk.isEmpty else { return nil }
        let ata = (s["ata"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (deriveATA(owner: pk) ?? "")
        return Seat(label: label(for: name), device: s["device"] as? String ?? name, pubkey: pk, ata: ata)
    }

    static var local: Seat? { seat(localSeatName) }
    static var sibling: Seat? { seat(siblingSeatName) }
    static var boomerang: Seat? { seat("boomerang") }

    /// Base58 shape check (32–44 chars, no 0 O I l). Also blocks pasting a 64-byte secret by length.
    static func isPlausiblePubkey(_ s: String) -> Bool {
        let allowed = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return (32...44).contains(s.count) && s.allSatisfy { allowed.contains($0) }
    }

    static func deriveATA(owner: String) -> String? {
        #if canImport(SolanaSwift)
        guard let o = try? PublicKey(string: owner), let m = try? PublicKey(string: mint),
              let tp = try? PublicKey(string: tokenProgram),
              let ata = try? PublicKey.associatedTokenAddress(walletAddress: o, tokenMintAddress: m, tokenProgramId: tp)
        else { return nil }
        return ata.base58EncodedString
        #else
        return nil
        #endif
    }

    // MARK: - Paste-pair (sibling pubkey only)

    static func pastePair(_ raw: String) -> String {
        let pk = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPlausiblePubkey(pk) else {
            return "PASTE-PAIR refused — paste the sibling's PUBLIC key (base58, 32–44 chars). Never paste a secret key."
        }
        if pk == local?.pubkey || pk == boomerang?.pubkey { return "PASTE-PAIR refused — that pubkey is already seated on this device." }
        let ata = deriveATA(owner: pk) ?? ""
        return saveSeat(siblingSeatName, pubkey: pk, ata: ata)
            ? "PASTE-PAIR OK · \(label(for: siblingSeatName)) \(short(pk)) · ATA \(ata.isEmpty ? "(derive after SolanaSwift seat)" : short(ata))"
            : "PASTE-PAIR failed to write seat file."
    }

    // MARK: - Keychain (secret bytes never leave this enum except into a signer in memory)

    private static func baseQuery(_ role: Role) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: role.rawValue,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
    }

    static func hasKey(_ role: Role) -> Bool {
        var q = baseQuery(role)
        q[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
    }

    fileprivate static func readSecret(_ role: Role) -> Data? {
        var q = baseQuery(role)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    private static func storeSecret(_ data: Data, role: Role) -> Bool {
        var q = baseQuery(role)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        q[kSecAttrLabel as String] = "ЯBOT \(role.rawValue) device wallet"
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    /// USER TAP ONLY (Wallet landing → "Seat … key" → confirm). Refuses if a key already exists (never overwrites).
    static func createKeyByUserTap(_ role: Role) -> String {
        #if canImport(SolanaSwift)
        if hasKey(role) { return "Key already seated for \(role.rawValue) — never overwritten." }
        guard let kp = try? KeyPair() else { return "Key creation failed (no key stored)." }
        guard storeSecret(kp.secretKey, role: role) else { return "Keychain refused the key (nothing stored)." }
        let pk = kp.publicKey.base58EncodedString
        let seatName = role == .main ? localSeatName : "boomerang"
        saveSeat(seatName, pubkey: pk, ata: deriveATA(owner: pk) ?? "")
        return "\(label(for: seatName)) seated · pubkey \(short(pk)) · secret stays in this device's Keychain."
        #else
        return "SEAM: SolanaSwift package not linked — keys cannot be created in this build."
        #endif
    }

    #if canImport(SolanaSwift)
    /// Loads a signer ONLY for a user-confirmed leg; checks it matches the seated pubkey.
    static func signer(_ role: Role) -> KeyPair? {
        guard let sk = readSecret(role), let kp = try? KeyPair(secretKey: sk) else { return nil }
        let expected = role == .main ? local?.pubkey : boomerang?.pubkey
        guard kp.publicKey.base58EncodedString == expected else { return nil }
        return kp
    }
    #endif

    // MARK: - Status

    static func status(of s: Seat?, needsKey: Role? = nil) -> SyncStatus {
        if let r = needsKey, !hasKey(r) { return .keyNeeded }
        guard let s else { return .pasteNeeded }
        return s.ata.isEmpty ? .ataPending : .ok
    }

    static func short(_ s: String) -> String { s.count > 12 ? "\(s.prefix(4))…\(s.suffix(4))" : s }

    static func seatsBlock() -> String {
        func line(_ name: String, _ s: Seat?, _ role: Role?) -> String {
            let st = status(of: s, needsKey: role)
            guard let s else { return "  \(label(for: name)): — · \(st.rawValue)" }
            return "  \(label(for: name)): \(short(s.pubkey)) · ATA \(s.ata.isEmpty ? "—" : short(s.ata)) · \(st.rawValue)"
        }
        return [
            "DEVICE WALLETS (pubkeys + ATAs only · keys stay in Keychain)",
            line(localSeatName, local, .main) + "  ← this device",
            line(siblingSeatName, sibling, nil),
            line("boomerang", boomerang, .boomerang),
        ].joined(separator: "\n")
    }
}
