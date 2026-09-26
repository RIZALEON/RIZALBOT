# ЯBOT 0.3.3 ALL-OS (build/0.3.3-allos) — 2026-09-25 MT

Base: `respawn/0.3.2-localbuild` (ad52856). Source verified identical (sha256) to Mac `~/Documents/ЯBOT` and
`~/Library/Developer/ЯBOT-localbuild` for every .swift/.kt/.pbxproj/.xml/.kts/.plist/.json source file before these changes.

| Platform | Version | Build |
|---|---|---|
| macOS | 0.3.3 | 2026092501 |
| iOS | 0.3.3 | 2026092501 |
| Android | 0.3.3 | versionCode 5 (4 left unused: 0.3.2 was never built for Android) |

## What changed
- **TOKENBLAST → TokenBlastProbe** (shared read-only pipe engine; TokenBlast output unchanged) + read-only RPC helpers.
- **TRUEBLAST** (`TrueBlast.swift`): 1.0 Я to the sibling device wallet + full pipe report. LIVE by default; every
  send goes through `BlastConfirmSheet` (from · to · amount 1.0 Я · fee · network), signs only with this device's
  Keychain key after the tap. No silent send, no auto-retry, no batching. `trueblast dry` = simulate.
  Never creates the sibling ATA silently (refuses with PUBKEY_OK_ATA_PENDING).
- **BANGЯANG** (`BangRang.swift`): 1.0 Я out to the boomerang wallet and back, TOKENBLAST before/between/after, both
  legs + verdict in `ghost-chain.jsonl`. One-device mode (second Keychain key) = one sheet, one tap, exactly two
  transfers, leg-2 fee paid by main. Two-device mode = leg 1 here; return leg signed on the sibling only after its own
  sheet (`bangrang return <sig>`). A remote message can never make a device sign by itself.
- **YaDeviceWallets.swift** + `DeviceWalletSeat.json` (pubkeys + ATAs only). Keys: created only by the user's tap on
  the Wallet landing (with a confirm alert), Keychain only (`WhenUnlockedThisDeviceOnly`, not synchronizable).
- **SPM**: `p2p-org/solana-swift` exact 5.0.0 (used only for keypair, ATA derivation, instruction build, signing and
  serialization; blockhash + a single `sendTransaction` go through ЯBOT's own JSON-RPC because 5.0.0 still calls the
  removed `getRecentBlockhash` and its `sendTransaction(preparedTransaction:)` retries). All SolanaSwift use is behind
  `#if canImport(SolanaSwift)` — without the package the app builds and reports a SEAM instead of sending.
- **Router verbs**: trueblast · true blast · trueblast it · blast true [dry] · bangrang · bangЯang · boomerang ·
  bang rang [one|two|dry] · bangrang return <sig> · wallet seats · paste pair <pubkey> · classroom · lessons · training.
- **Classroom** (Garage → Training): `ClassroomStore.swift` + `ClassroomSeed.json` (Mac/iOS), `ClassroomStore.kt` +
  `assets/classroom/` (Android); `yabot://classroom` on both. Submit writes one inbox/ file only.
- **Android**: TOKENBLAST probe (Kotlin port, read-only, off the UI thread); TRUEBLAST/BANGЯANG verbs say plainly the
  send legs are Mac/iOS only this version and run the probe. Version 0.3.3 / vc 5.
- **WalletCard.json** authority typo fixed (`…BQUt…` → `…BQUT…`) in the app and Android asset.
- **CI**: `android-apk.yml` runs on `build/**`, `respawn/**` and PRs; fetches llama.cpp at the Mac seat's commit and
  passes `-PyabotLlamaDir` (build.gradle.kts keeps the Mac path as default).

## Heart (COMPLETE-APP LAW §13.7)
Mac/iOS bundle `ЯBOT/engine/heart.gguf` (not in git; seated in the localbuild tree). Android: not in the APK; the
install script seats it with adb push + run-as cp and checks `seated=yes`.
