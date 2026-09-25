# Я / GAME BUILDERS WORKSHOP

**Purpose / intent:** the place inside ЯBOT where the game evolves along the way. Bots draft game code, the Decider previews it and applies it, and every change can be undone.

- **Where in the app:** Я Game (clay-face button on the ЯBAR) → game menu → **GAME BUILDERS WORKSHOP**. You can also say `workshop` or open `yabot://game/workshop` (alias `yabot://workshop`).
- **Room:** the white padded workshop (asset `WorkshopRoom`, the Decider's image).
- **Gamewrite authors:** Я's bots by their **Garage names**, **ЯBOT** (blue clay horned face with bat wings) and **ЯMAX** (white Baymax-style clay face). Names, faces and aliases come from the Garage roster (`seat/BOT-LABELS.json`, BotLabels.v3). [`authors.json`](authors.json) (WorkshopAuthors.v2) only lists which roster ids may gamewrite, plus the default author; edit it and there is no rebuild. Every draft and ledger row records the author's Garage name, and the face is shown beside it. Unknown authors (e.g. `as garage`) are refused.
- **Naming law (Decider 2026-09-24 17:12 MDT):** **Я** is the Machine Mind, with all of its components behind it (label `Я`, never numbered). The bots are its extensions / digital robot kids and speak in chat with their Garage names. No `ЯBOT#N` numbers. **Garage** is the workshop place / bot builder, not a bot.
- **Decider:** the only one who can Approve & Apply, Reject, or Respawn. These are taps plus a confirm in the Workshop, never chat words.

## Folders (this folder = `~/Documents/ЯBOT/game/workshop/`)

| Path | What |
|---|---|
| `projects/<id>/` | Live project files (`project.json`, `live/index.html`, `src/…`, `data/…`, `shaders/…`, `docs/…`, `native/…`) |
| `projects/blueface/` | Seed project **BLUEFACE v1**: `live/index.html` (single-file build, ~1.4 MB) + `blueface-ts-src.zip` + `src/` (unzipped TS source) |
| `drafts/<draftId>/` | `draft.json` (file, language, author, purpose, status, notes) + `content-<file>` (+ `preview.html` harness) |
| `respawn/<stamp>-<project>/` | Whole-project snapshot taken before every apply and every rollback (`SNAPSHOT.json` + `project/`) |
| `authors.json` | Which Garage-roster bots may gamewrite (`yabot` · `yamax`) + default author. Editable config (v2), read live by the app |
| `EVOLUTION-LEDGER.jsonl` | Append-only history: seed · propose · refused · approve · apply · reject · snapshot · respawn · project-create |

On iOS the same layout lives in the app's own Documents/ЯBOT/game/workshop. It is seeded from the bundled `BLUEFACE-v1.html`.

## Flow (NonNuclear)

1. **Propose:** `gamewrite <language> <file> <purpose>` in chat (FN/ACT lanes), or Workshop → Drafts → *Ask bot to draft* (author toggle ЯBOT / ЯMAX), or `… as yamax`.
2. **Validate on save:** allowed language/extension, relative path, ≤ 256 KB, JSON parses, no secrets/keys/seed phrases, no signing calls, no RPC/signing endpoints. Refusals are logged.
3. **Preview:** sandboxed web view (local files only, http(s)/ws(s) blocked, no native bridge).
4. **Approve & Apply (Decider):** re-validate → snapshot to `respawn/` → copy into the project → ledger + MIND-TRANSCRIPT.
5. **Respawn (Decider):** roll a project back to any snapshot. The current state is snapshotted first.

Languages: TypeScript · JavaScript · HTML · CSS · JSON · JSON Schema · GLSL · Markdown, plus Swift/Kotlin as draft-only wrapper code (flagged "needs rebuild").
Teach book: `mind/books/GAMEWRITE-FUNDAMENTALS-0.1.md`. The game never signs; wallet actions become proposals for the native wallet.
