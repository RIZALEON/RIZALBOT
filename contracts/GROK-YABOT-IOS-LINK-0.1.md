# GROK ↔ ЯBOT iOS Link 0.1

**Status:** seated · online bonus only · 100% offline remains standard  
**Stamp:** 2026-09-23 · America/Denver · localbuild  
**Bundle:** `io.github.rizaleon.yaaim`  
**Schemes:** `yabot://` (primary) · `yaaim://` (alias)  
**Law:** Core clay / Heart never depends on Grok Bot. Same-phone link is an **online bonus** when both apps are present (or ЯBOT can be opened via URL).

---

## What Decider can do TODAY from Grok Bot iOS

ЯBOT source owns **receive + respond**. We do **not** ship code inside Cursor’s Grok Bot iOS binary.

### Best path (works without patching Grok)

1. **Shortcuts → Open URL** (or Safari / Notes link / QR):
   - Review: `yabot://grok?action=review&text=Check%20this%20draft`
   - Work (inject + send into main chat / Heart): `yabot://grok?action=work&text=PING`
   - Status sheet: `yabot://grok?action=status`
   - Ping / pong status: `yabot://grok?action=ping`
   - Chat alias: `yabot://chat?text=hello`
   - Mind landing: `yabot://mind`
   - Alias scheme: replace `yabot` with `yaaim` (same paths).
2. If Grok Bot exposes **Share Sheet / Open URL / copy link**, paste any URI above.
3. Soft status back to Decider:
   - Pasteboard gets a line `GrokYabotHandoff.v1` + JSON status after each ack.
   - Files: `Documents/ЯBOT/peer/GROK-STATUS.json` and `GROK-HANDOFF.json` (App Support mirror under `Library/Application Support/ЯBOT/peer/`).
   - Optional callback: add `&callback=grokbot%3A%2F%2Fyabot-status` (or whatever scheme Grok registers). ЯBOT appends `from=yabot&state=…&id=…` and tries `UIApplication.open`. If Grok has **no** registered callback scheme, callback is a no-op — use pasteboard / status sheet / Copy.

### Smoke (Mac → device)

```bash
# With phone unlocked + ЯBOT installed:
xcrun devicectl device process launch \
  --device 00008150-000238413E7A401C \
  --start-stopped false \
  io.github.rizaleon.yaaim

# Open URL on device (devicectl / openurl tooling varies by Xcode):
xcrun devicectl device info apps --device 00008150-000238413E7A401C | head
# Prefer Shortcuts on-phone "Open URL" with the URIs above if openurl CLI is unavailable.
```

---

## Packet (RCODE-aligned, minimal)

| Param | Meaning |
|-------|---------|
| `action` | `review` \| `work` \| `status` \| `ping` \| (host `chat` / `mind`) |
| `text` | Plain UTF-8 work / review body (percent-encoded in URL) |
| `payload` | Optional; plain JSON/text or standard base64 UTF-8 |
| `callback` | Optional URL Grok registered for status bounce |
| `id` | Optional correlation id (UUID minted if absent) |

Examples:

```
yabot://grok?action=review&text=Review%20Lab%20Scout%20output
yabot://grok?action=work&text=SCOUT
yabot://grok?action=status
yaaim://grok?action=work&text=PING&callback=shortcuts%3A%2F%2Frun-shortcut
yabot://chat?text=tokenblast
yabot://mind
yabot://lab/scout
```

JSON peer file schema (`GROK-HANDOFF.json`):

```json
{
  "schema": "GrokYabotHandoff.v1",
  "ts": "ISO-8601",
  "from": "grok",
  "to": "yabot",
  "verb": "review|work|status|ping",
  "id": "…",
  "text": "…",
  "payload": "…",
  "callback": "…",
  "online_bonus": true
}
```

Status (`GROK-STATUS.json` / pasteboard):

```json
{
  "schema": "GrokYabotStatus.v1",
  "seat": "ЯBOT",
  "state": "review_open|work_queued|status_open|pong|dismissed|…",
  "id": "…",
  "action": "review",
  "ts": "ISO-8601",
  "online_bonus": true
}
```

---

## App Group (optional — not seated)

- Proposed: `group.io.github.rizaleon.yaaim.shared`
- **Not enabled:** requires matching team entitlement in **both** binaries. Grok Bot iOS is not under team `88HACKXHZL`; cross-team App Groups will not work.
- Prefer open-URL + pasteboard + Documents peer files until Decider controls both signing teams.

---

## Honest gaps (Grok Bot outbound)

- This seat does **not** patch Cursor Grok Bot iOS.
- If Grok Bot UI has **no** Open URL / Share / Shortcuts hook, Decider must leave Grok and run Shortcuts “Open URL”, tap a Note/QR, or paste the URI into Safari.
- Callback into Grok only works if Grok (or Shortcuts) registers a URL scheme Decider passes as `callback=`.
- No Share Extension in ЯBOT yet (receive is open-URL).
- Android untouched (CoS).

---

## Inventory (this seat)

| Surface | State |
|---------|--------|
| `yabot://` URL types | seated (+ `yaaim` alias) |
| Lab routes | existing (`lab`, `lab/scout`, `lab/helix`, chamber…) |
| `ClayCommandInbox` | file inbox (Mac/docs) — unchanged |
| App Groups | none |
| Share Extension | none |
| NativeX / WebShell bridges | none found in localbuild |

---

## Implementation files

- `ЯBOT/GrokYabotLink.swift` — parse / ack / pasteboard / peer JSON / soft callback  
- `ЯBOT/GrokReviewLandingView.swift` — Review + Status landings  
- `ЯBOT/ContentView.swift` — `onOpenURL` routes  
- `ЯBOT/Info.plist` — schemes `yabot`, `yaaim`

Mirrors: `_staging/GROK-YABOT-SAME-PHONE-LINK-0.1.md` · `localbuild/contracts/`
