# AGENTS.md — rules for any AI / bot working in the GAME BUILDERS WORKSHOP

This folder holds Я Game / TeraformЯ projects (first: **BLUEFACE v1**). Crown: **Я**.
Naming law (Decider 2026-09-24 17:12 MDT): **Я** is the Machine Mind (never numbered). The bots are its digital robot kids and go by their **Garage names**. Gamewrite authors: **ЯBOT** (blue clay horned face, bat wings) and **ЯMAX** (white Baymax-style clay face). Names come from the Garage roster (`seat/BOT-LABELS.json`), and `authors.json` lists which of them may gamewrite. Every draft and ledger row records the author's Garage name. Unknown authors (e.g. `garage`) are refused. No `ЯBOT#N` numbers; Garage is the workshop place, not a bot.

1. **Stack is fixed: TypeScript (strict) + Phaser 4**, bundled (no CDN), so it runs offline in the app's web view (Mac, iOS, Android, web). Swift/Kotlin are thin wrappers only (draft-only in-app; needs rebuild).
2. **Art is code-drawn only:** Phaser Graphics/`generateTexture` or Canvas2D. **No image files, no sprite sheets, no AI-generated or downloaded art.** (The Workshop *room* backdrop is app chrome, not game art.)
3. **No keys, secrets, seed phrases, wallets, signing, RPC endpoints, network calls, or telemetry** in game code. The game never signs. Wallet actions become JSON *proposals* for the native wallet. Read-only chain data only.
4. **BLUEFACE is fixed:** moves `idle · walk · dig · cheer · takeThat` and save `{v:1,name:'BLUEFACE',crown:'Я',position,facing,action,tool}`. Upgrades only replace drawing. Save schema: `terraformya.save` v1.
5. **NonNuclear change process:** *propose* a draft (purpose/intent + diff + preview), then the **Decider approves**, then *apply*. Bots never apply, reject, or respawn. Those are Decider taps in the Workshop. Every apply snapshots to `respawn/` first. No deleting history, no mass rewrites, no pushing to GitHub without the Decider's go-ahead.
6. Before calling a TS change done: `npm run build` must pass (strict typecheck) on the Mac, and screenshots must be looked at.
7. Only edit files inside `projects/<id>/` (through drafts). `EVOLUTION-LEDGER.jsonl` is append-only. `project.json` is Decider-owned.
8. Every recommendation leads with its purpose/intent.
9. **ALL-OS SYNC LAW (Decider 2026-09-24 17:29 MDT):** Mac · iOS · Android are always updated together: continuously, collaboratively, collectively, in conjunction. No platform ships a workshop/game feature alone. Upgrades carry matching version numbers on all three, each gets a respawn point on all three first, and any platform gap is reported to the Decider and logged, never hidden. (YAMANUAL §13.5)
