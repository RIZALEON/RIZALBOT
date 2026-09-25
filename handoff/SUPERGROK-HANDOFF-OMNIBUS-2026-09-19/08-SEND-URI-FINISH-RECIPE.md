# SEND URI — finish recipe (Decider opened attempt at ~2%; blocked)

**Purpose:** put crown **Я** + gold coin image on Metaplex so Jupiter/mirrors show name/symbol/image.  
**Intent:** SuperGrok finishes on the Mac seat. **Never paste private keys into CHANNEL Я / chat.**

## Crown image (locked — this coin)
- Local: `~/Library/Developer/ЯBOT-localbuild/twin/assets/ya-crown-coin.jpg`
- Mirrored under handoff omnibus `assets/` and Application Support twin.
- On-chain `image` still empty until publicly hosted.

## Why Grok Bot could not finish
1. No `solana` / `metaboss` on PATH on this Mac right now.
2. No Decider keypair path confirmed on disk in a safe search (mint authority key must stay on Mac — Decider names the path; never paste JSON into chat).
3. No MACHINE MIND public host URL already seated for upload.
4. On-chain update needs a small SOL fee + live RPC + signer.

## Keys / logins — handoff WITHOUT leaking
- **Do not** paste keypair JSON, seeds, RPC secrets, or Pinata/NFT.Storage tokens into SuperGrok chat.
- SuperGrok (or Decider at Terminal) reads the keypair **by file path** on the Mac only.
- If a host API token is needed: store in Keychain / env on the Mac, or via Grok Bot secret card — never in the transcript.

## Finish steps (only when Decider says send URI + host ready)
1. Install Solana CLI + metaboss (or use existing Umi path in localbuild if present).
2. Host `twin/assets/ya-crown-coin.jpg` → `IMAGE_URI` (Decider-chosen host only).
3. Set `image` + `properties.files[0].uri` in `twin/я-metadata.json` to `IMAGE_URI`. Keep name/symbol **Я**.
4. Host `я-metadata.json` → `METADATA_URI`.
5. `metaboss decode mint -a <mint from WalletCard.json>`
6. `metaboss update uri -a <mint> -u "$METADATA_URI" -k /path/to/DECIDER-KEY.json` (path Decider confirms; no revoke/freeze flags).
7. Optional if on-chain name blank: update name/symbol to **Я** only.
8. Smoke: `tokenblast` ONLINE → Jupiter **Я** + coin image; freeze still on; no strangeness.
9. MANUAL: “Jupiter URI seated; crown Я; coin image live; freeze unchanged; explorers still mirrors.”

Gate 2 stays **WAIT** until those prerequisites exist and Decider repeats **send URI**.


## RESOLVED by Grok Bot (2026-09-19) — keypair path from mint setup

- **Mint-authority keypair path (PATH ONLY — never paste file contents into chat):**  
  `/Users/rizal/Documents/ЯBOT/courses/ROBOT-EVOLUTION-680/TWIN-SOLANA/keys/devnet-minter.json`  
  File is named `devnet-minter.json` but it is the signer used for the mainnet twin blast (scripts under `TWIN-SOLANA/mint/` read this path).
- **Host gap:** `mint/metadata-uri.txt` shows NFT.Storage uploads disabled (spam lockout). Decider must pick a **new** public host for crown JPG + metadata JSON before `send URI`.
- Still requires Decider words **send URI** before any on-chain spend.
