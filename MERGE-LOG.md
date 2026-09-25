# ЯBOT MERGE-LOG: 0.1 (two trees) → 0.3.0 (2026092401) · 2026-09-24

Trees merged:
- **LB** = `~/Library/Developer/ЯBOT-localbuild` (the tree that built the installed app)
- **DOC** = `~/Documents/ЯBOT` (git HEAD 170c267…, uncommitted)

The pre-merge state of both trees is saved at `~/Library/Developer/ЯBOT-respawn/2026-09-24-pre-workshop/`.
After the merge, `diff -rq LB/ЯBOT DOC/ЯBOT` (engine excluded) reports **TREES-EQUAL**, and `ЯBOT.xcodeproj/project.pbxproj` is identical in both trees.
Other records: the pre-merge diff (47 lines) is `~/yb-upgrade-work/pre-merge-diff.txt`, and the action log (162 lines) is `~/yb-upgrade-work/merge-actions.log`.
No git commit, push, reset, or stash was run, and nothing was deleted. Anything superseded is under `_bak/2026-09-24-pre-0.3.0/` in the tree it came from.

## Already identical before the merge (kept as-is)
52 top-level files:
BotRFIDMint, ChainSource.json, ChatThreadStore, ClayButtons, ClayComposer, ClayTheme, CoinCarrierHub, CoinPathScout, ContentView*, EssenceTrace, GameLandingView*, GarageWorkshopLandingView, GenomeHelixView, GhostChainLedger, GrokReviewLandingView, LabChamberPaths, LabFunctionEvolve, LabManualDesk, LabNewLight, LabReturnReport, LabScaffolds, LabScoutCommand, LabScoutWalis, LibLlama, MagnetizedContrast, MindClayCounterView, MindReseat, ModeStore, MyApp, NativeHeart*, NearLinkBluetooth, NearbyPlaces, NeoBabyScout, OnlineSearch, PingPongNetTest, PlaceSense, PlumbingClear, RedwoodYabarShelf, ScoutMissingTeach, SelfFix, TemplateRespawn, TokenBlast, TwinPipe, WalletCard.json, YAMANUAL.pdf, YaCode, YaCosVoice, YaResizableToolbar, YaToken, YaTwinChain, write-a-tiny-digitparse-helper…, ЯBOT.entitlements.
Also 161 asset files were identical.
(* = identical before the merge, then edited for 0.3.0 in both trees, as listed below.)

## LB won (Documents' version survives in the respawn clone and in git)
| File | Why |
|---|---|
| BotLabel.swift | Newer labels v2 (Я clay seat + ЯBOT#N minting) |
| ChatMessage.swift | Newer party/label fields |
| TeachStore.swift | Newer kernel law and teach entries |
| GrokYabotLink.swift | Newer |
| WalletLandingView.swift | Newer |
| LabScoutView.swift | Newer (includes the return report) |
| LabChamberView.swift | Newer |
| YaActivityView.swift | Newer |
| Info.plist | yaaim identity (io.github.rizaleon.yaaim) |
| ЯBOT.xcodeproj/project.pbxproj | The one that built the installed app; LB's pre-merge copy is in `_bak/…/project.pbxproj.pre-0.3.0` |
| USER-MANUAL.pdf | LB's newer render |
| Assets: BtnComposer.png, BtnMind.png, BtnSearch.png, BtnSend.png, BtnWallet.png | These are the plates the installed app shows |
| Assets Contents.json: Bolte, BtnComposer, BtnHomeHouse, BtnMind, BtnOffline, BtnOnline, BtnSearch, BtnWallet, LabIcon | Formatting only; kept LB's |
| LB-only: YAMANUAL-0.1.pdf, twin/last-mint-mainnet.json | Carried into DOC. (LB's unreferenced BtnComposer.BROKEN-1500x399.png was carried too, then moved to `_bak/` in both trees) |

## DOC won
| File | Why |
|---|---|
| MindTreeRoot.swift | TCC-sticky Documents guards (LB had no other changes) |
| MachineMindVault.swift | Same |
| LabShotCommand.swift | Same |
| Assets LabChamber.imageset, LabOfCreations.imageset | DOC only, and referenced by code |
| ЯBOT/USER-MANUAL.md, ЯBOT/YAMANUAL.md | DOC only; both are manual copies |
| ЯBOT/LAB-MANUAL.pdf | DOC only; LabManualDesk looks it up with Bundle |

## Hand-merged
| File | Result |
|---|---|
| MindTranscript.swift | LB base (BotLabel U/Я parties) + DOC's App-Support inbox note |
| ManualLandingView.swift | LB base (crown ЯMANUAL wording) + DOC's NSWorkspace.open-first in exportManual + `openSeatedPDF()` alias + markDocumentsAccessGranted on a Documents hit |
| ClayLandingView.swift | LB base + open-first + "Open ЯMANUAL" help |
| CompanionRouter.swift | LB base (keeps `manual`) + Bolte → ЯMANUAL + the new 0.3.0 commands below |

## Moved to _bak (not deleted)
- LB `_bak/2026-09-24-pre-0.3.0/`: ContentView/LibLlama/NativeHeart `.swift.bak-pre-dial-141628`, `project.pbxproj.pre-0.3.0`
- DOC `_bak/2026-09-24-pre-0.3.0/`: LabScoutView.swift.bak-pre-return-report, BtnComposer.BROKEN-1500x399.png.bak-plate, unreferenced BtnHomeHouse.png, ToolbarScaffoldDark/Light.imageset (no code references them)

## New for 0.3.0 (identical in both trees)
- **GameWorkshop.swift**: the workshop store (projects/drafts/respawn/EVOLUTION-LEDGER.jsonl), plus propose/approve/reject/snapshot/respawn/createProject/seed.
- **GameWrite.swift**: the `gamewrite` skill. Languages: TS, JS, HTML, CSS, JSON, JSON Schema, GLSL, Markdown; Swift and Kotlin are draft-only. Includes validation and Heart drafting. The author is **ЯBOT** or **ЯMAX** (`… as yamax`).
- **WorkshopAuthors.swift** + **WorkshopAuthorFace.swift**: gamewrite authors are read from `game/workshop/authors.json` (editable config, seeded once) and the author's face is shown beside each draft.
- `Assets.xcassets/BotFaceYaBot.imageset` and `BotFaceYaMax.imageset`: faces cropped from the Decider's image.
- **GameWorkshopView.swift**: the GAME BUILDERS WORKSHOP room, with a local-only sandbox preview and confirm alerts.
- **RespawnPoints.swift**: `respawn` lists build respawn points and exact restore commands.
- **GAMEWRITE-FUNDAMENTALS-0.1.md**: bundled, and also copied to mind/books and android assets in both trees.
- `game/workshop-seed/BLUEFACE-v1.html` and `blueface-ts-src.zip`; `Assets.xcassets/WorkshopRoom.imageset`.

## Edited for 0.3.0 (identical in both trees)
- **BotLabel**: **unchanged from LB** (a Garage=ЯBOT#1 edit was made, then reverted at the Decider's correction; numbering waits on the Decider).
- **TeachStore**: GAMEWRITE LAW + RESPAWN LAW.
- **CompanionRouter**: `workshop`, `gamewrite …`, `respawn` (lists points), `respawn template` / `respawn template confirm`. `game approve/apply/reject/respawn` point to the UI (only the Decider can tap them).
- **GameLandingView**: Play / GAME BUILDERS WORKSHOP menu, plus a flat-bundle `index.html` fallback, plus `NSHomeDirectory()` so iOS compiles.
- **ContentView**: workshop door, deep links `yabot://game/workshop` and `yabot://workshop`.
- **NativeHeart**: `maxNewTokens` parameter (Mac 16–512, default 96; iOS unchanged).
- **Version**: MARKETING_VERSION 0.3.0, CURRENT_PROJECT_VERSION 2026092401 (4× each).
- `BtnComposer.BROKEN-1500x399.png` (unreferenced junk carried from LB) was moved to `_bak/` in both trees.

## Seat data (not source)
- `~/Documents/ЯBOT/game/workshop/` created: README, AGENTS, projects/blueface, drafts, respawn, EVOLUTION-LEDGER.jsonl.
- `game/workshop/authors.json`: ЯBOT · ЯMAX (default ЯBOT).
- BOT-LABELS.json (App Support + Documents seat): **no net change**. A Garage=ЯBOT#1 registration made at 15:19 was withdrawn at 15:37 by a byte-exact restore from the respawn point (bots {}, nextCreatedSerial 1).
