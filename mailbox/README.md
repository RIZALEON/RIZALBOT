# RIZALEON mailbox — collaborator channel

**Purpose:** one public tray for CHANNEL Я / ЯBOT notes between Decider, Mac, phone, and Grok-as-bridge.
**Intent:** share *words and paths*. Never share secrets.

This folder is **not** a wallet. There is no `SEED.json` here and there must never be one.

## Trees (do not merge)
| Tree | Role |
| --- | --- |
| `RIZALEON/RIZALBOT` `seat-wallet-landing` | This repo / this mailbox / twin JSON + coin |
| `~/Library/Developer/ЯBOT-localbuild/` | Clay build source |
| Phone Heart / Ghost (ЯBOT.app) | Offline premier chat |
| Grok.com CHANNEL Я | Bridge only |
| `rizalward/Rbot` | Separate tree — do not merge |

Rbot ≠ PROJECTR. Do not merge trees. Do not `git push origin main` unless Decider says **merge**.

## Allowed in mailbox/
- Handshake *labels* (no keys)
- TOKENBLAST verdicts (public)
- Mint / tx / URI that are already public
- Questions for Decider
- Pointers to paths on a machine (`~/.../file`) — not file contents of keypairs

## Forbidden in mailbox/ and in git
- Seed phrases, mnemonic words
- Keypair JSON, private keys, API tokens, RPC secrets
- Anything named `SEED.json`, `*.key`, `id.json` wallet dumps
- Force-push main

If a secret was ever pushed: assume burned. Rotate offline. Do not paste it into chat or raw.githubusercontent.

## How a collaborator leaves a note
1. Branch from `seat-wallet-landing` (or comment on PR #1).
2. Add `mailbox/inbox/YYYY-MM-DD-yourname.md` using the template in `INCOMING.md`.
3. Purpose then Intent in the first two lines.
4. Open or update PR — **do not merge**.

## Public twin (mirrors only)
- Mint: `BB9uA5BuacDnWyDf5Npc9nMb9yFbyThsNrQPBYJ5Q1Lv`
- Metadata: `https://raw.githubusercontent.com/RIZALEON/RIZALBOT/seat-wallet-landing/twin/ya-metadata.json`
- Image: `https://raw.githubusercontent.com/RIZALEON/RIZALBOT/seat-wallet-landing/twin/ya-crown-coin.jpg`
- URI update tx (mainnet): `nhVeNxtteysyCW8wDim7F6vE3Ks76P3ZRwpYr1eedUGzKq4bJwqQCmWdqbL7uEtdAMKASbpU16vSkxoiKVAv4ho`

Clay owns source. Explorers are mirrors. Crown Я.
