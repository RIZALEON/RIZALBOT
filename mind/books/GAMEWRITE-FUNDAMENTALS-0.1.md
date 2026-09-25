# GAMEWRITE FUNDAMENTALS 0.1 · Я Game / TeraformЯ

**Purpose / intent:** teach the in-app bots how to write game code for Я Game that the Decider can read, preview, and apply safely.
**Gamewrite authors (in-app bots):** **ЯBOT** (blue clay horned face with bat wings; asset `BotFaceYaBot`) and **ЯMAX** (white Baymax-style clay face; asset `BotFaceYaMax`). **Naming law (Decider 2026-09-24 17:12 MDT):** **Я** is the Machine Mind (never numbered). The bots are its digital robot kids and always go by their **Garage names**: names, faces and aliases come from the Garage roster (`seat/BOT-LABELS.json`, BotLabels.v3). `game/workshop/authors.json` (WorkshopAuthors.v2) only lists which roster bots may gamewrite; change it there, no rebuild needed. No `ЯBOT#N` numbers. Garage is the workshop place, not an author.
**Crown:** Я · **Mint (read-only reference):** `BB9uA5BuacDnWyDf5Npc9nMb9yFbyThsNrQPBYJ5Q1Lv`
**Seated:** 2026-09-24 (America/Denver) · ЯBOT 0.3.0 (naming law 0.3.1) · book path `mind/books/GAMEWRITE-FUNDAMENTALS-0.1.md` (also bundled in the app)

---

## 0. The law first (NonNuclear)

1. **Propose, then the Decider approves, then apply.** Nothing a bot writes goes live by itself. `gamewrite` only makes a **draft** in the GAME BUILDERS WORKSHOP.
2. **Only the Decider applies.** Approve & Apply, Reject, and project Respawn are **taps inside the Workshop**. They are not chat words, so no bot, inbox line, or deep link can apply code.
3. **Every apply snapshots first.** The previous project state is copied to `game/workshop/respawn/<stamp>-<project>/`, so every game change can be undone.
4. **The game never signs.** No keys, seed phrases, mnemonics, private keys, or signing calls in game code. Wallet wishes become **proposals** that the native wallet (outside the game) shows to the Decider. Read-only chain data comes through `@solana/kit` in read-only mode only.
5. **Every change states its purpose.** Each draft carries a purpose/intent line, the author (its Garage name, ЯBOT or ЯMAX, from the Garage roster), the language, and the file. The Evolution ledger (`EVOLUTION-LEDGER.jsonl`) records every propose, refusal, approve, apply, reject, snapshot, and respawn. It is append-only.
6. **Offline first.** Bundle everything (Phaser is bundled, with no CDN). The preview sandbox blocks http(s)/ws(s).

## 1. The gamewrite command

```
gamewrite <language> <file> <purpose>              # Heart drafts (falls back to a valid starter)
gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs
gamewrite glsl shaders/clay.frag warm clay tint as yamax         # author ЯMAX (default author: ЯBOT) · `as Яmax` works too
gamewrite js live/x.js test as garage                            # REFUSED — 'garage' is not a bot in the Garage roster (nothing saved)
gamewrite json data/level1.json first level in project blueface
gamewrite css live/style.css bigger touch buttons ```css
button { min-height: 64px; }
```                                                  # exact code after a fence (CoS / Grok / any author)
gamewrite languages · gamewrite list · gamewrite show <draftId> · workshop
```
Natural phrasing also routes: *write game code …*, *draft game code …*, *game write …*.
Lanes: help, list, languages and show are **FN**. Drafting (it writes a file) is **ACT**.

| Language | Extensions | Default folder | Notes |
|---|---|---|---|
| TypeScript | .ts | src/ | Primary game language (strict) |
| JavaScript | .js .mjs | live/ | Small runtime mods; runs in the WebView |
| HTML | .html .htm | live/ | Pages/shells; previewable |
| CSS | .css | live/ | Layout/skin; previewable |
| JSON | .json | data/ | Must parse |
| JSON Schema | .json (`*.schema.json`) | schema/ | Object with `$schema` or `type` |
| GLSL | .glsl .frag .vert | shaders/ | Phaser shaders/filters |
| Markdown | .md | docs/ | Design docs, proposals |
| Swift | .swift | native/apple/ | **Draft only**, needs rebuild (thin wrapper) |
| Kotlin | .kt .kts | native/android/ | **Draft only**, needs rebuild (thin wrapper) |

**Validation on save (and again before apply):** the language must be allowed and the extension must match. The path must be relative, with no `..`, `/`, `~` or dotfiles. `project.json` is off limits. Drafts must be 1 B–256 KB. JSON must parse, and a Schema must be an object. The draft is refused if it contains secret patterns (PEM private keys, API/cloud/GitHub/Slack tokens, 85–90-char base58 secret keys, raw keypair byte arrays, 32-byte hex secrets), mentions a seed phrase, mnemonic, or private key (in code; docs only get a warning), makes wallet or signing calls (`signTransaction`, `signMessage`, `sendTransaction`, `Keypair.fromSecretKey`, `window.solana`, `window.phantom`, …), or contains RPC/signing endpoints (`mainnet-beta.solana.com`, `api.devnet.solana.com`, helius/quiknode/alchemy, `phantom.app/ul`, walletconnect, `/rpc`). Using `eval`/`new Function` gets a warning.

## 2. TypeScript essentials (strict)

- **Types:** `number`, `string`, `boolean`, arrays `number[]`, tuples `[number, number]`, unions `'left' | 'right'`, `unknown` (narrow before use), `readonly`.
- **Interfaces / type aliases:** `interface Pos { x: number; y: number }` · `type Facing = 'left' | 'right'`.
- **Functions:** `function add(a: number, b: number): number { return a + b; }` · arrows `const f = (n: number) => n * 2`.
- **Classes:** `class Mound { constructor(public x: number, private h = 0) {} grow(): void { this.h++; } }`.
- **Modules:** `export class X {}` / `import { X } from './X';` · `import Phaser from 'phaser';` · `import type { BluefaceState } from './character/state';`.
- **Null safety:** `a?.b`, `a ?? fallback`, and the non-null `!` only when certain.
- **Strict mode:** no implicit `any`. Prefix unused params with `_`.
```ts
export type Facing = 'left' | 'right';
export interface Mound { x: number; y: number; h: number }
export function growAll(ms: readonly Mound[], by = 1): Mound[] {
  return ms.map(m => ({ ...m, h: Math.min(m.h + by, 10) }));
}
```

## 3. JavaScript essentials

- `const`/`let` (never `var`), strict equality `===`, template strings `` `x=${x}` ``, arrow functions, destructuring `const { x, y } = pos`, spread `{ ...s, action: 'dig' }`.
- Modules: `export`/`import`. In a plain `<script>`, wrap code in an IIFE `(function(){ 'use strict'; … })();`.
- Only the DOM and Phaser. No `fetch` to the network (the sandbox blocks it anyway) and no wallet objects.
```js
(function () {
  'use strict';
  const bf = window.__BF;                 // BLUEFACE hook: { scene, hero, state() }
  if (bf) bf.hero.cheer();
})();
```

## 4. HTML + CSS layout

- Skeleton: `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">…</head><body>…</body></html>`.
- The game fills the WebView: `html, body { margin:0; height:100%; }` and a container `#game` with a `<canvas>` created by Phaser.
- Layout: flexbox `display:flex; align-items:center; justify-content:center;` · grid `display:grid; place-items:center;`.
- Touch targets ≥ 44–64 px. Clay palette: clay `#6b4a2b`, cream `#efe6d6`, gold `#c9a227`, night `#140e0a`.
```css
:root { --clay:#6b4a2b; --cream:#efe6d6; }
#game { display:flex; align-items:center; justify-content:center; height:100%; }
```

## 5. JSON + JSON Schema

- JSON: double-quoted keys and strings, no comments, no trailing commas. Values are string, number, boolean, null, object or array.
- JSON Schema (2020-12): `type`, `properties`, `required`, `enum`, `const`, `additionalProperties:false`, `$id`.
- **terraformya.save v1** (the save file; `$id: terraformya.save`):
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "terraformya.save",
  "type": "object",
  "required": ["v","name","crown","position","facing","action","tool"],
  "properties": {
    "v": {"const": 1}, "name": {"const": "BLUEFACE"}, "crown": {"const": "Я"},
    "position": {"type":"object","required":["x","y"],"properties":{"x":{"type":"number"},"y":{"type":"number"}}},
    "facing": {"enum": ["left","right"]},
    "action": {"enum": ["idle","walk","dig","cheer","takeThat"]},
    "tool": {"enum": ["axe-spade","double-spade"]}
  },
  "additionalProperties": false
}
```
Bump `v` only by Decider decision, and only together with a migration. Extra game data (levels, mounds) lives in separate files such as `data/*.json`, not inside the BLUEFACE save.

## 6. GLSL basics (Phaser shaders)

- Fragment shader: `precision mediump float;` and `void main(){ gl_FragColor = vec4(r,g,b,a); }`.
- Types: `float`, `vec2`, `vec3`, `vec4`, `mat2..4`, `sampler2D`. Use `uniform` for values set from TS (time, resolution) and `varying` for values passed from the vertex shader (texture coordinates).
- Built-ins: `texture2D`, `mix`, `clamp`, `smoothstep`, `sin`, `length`.
- Phaser 4 renders WebGL. Hook custom shaders in as filters or shader game objects, and keep them tiny.
```glsl
precision mediump float;
uniform sampler2D uMainSampler; uniform float uTime; varying vec2 outTexCoord;
void main(){ vec4 c = texture2D(uMainSampler, outTexCoord); gl_FragColor = vec4(mix(c.rgb, vec3(.42,.29,.17), .15), c.a); }
```

## 7. Markdown design docs

Headings with `#`, lists with `-`, code in fences, and tables with pipes. Every proposal doc opens with **Purpose / intent**, then *What changes*, *Save/API impact*, and *Proposal flow*.

## 8. Phaser 4 fundamentals

- **Game config:** `new Phaser.Game({ type: Phaser.AUTO, width: 1280, height: 720, backgroundColor: '#2c2a2b', parent: 'game', scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH }, scene: [MyScene] })`.
- **Scenes:** `class MyScene extends Phaser.Scene { constructor(){ super('my'); } preload(){} create(){} update(time, deltaMs){} }`. Switch scenes with `this.scene.start('other')`.
- **Game loop:** `update(time, delta)` runs every frame. Move by `speed * (delta/1000)` so motion does not depend on frame rate.
- **Input:** keyboard `this.input.keyboard!.addKey(Phaser.Input.Keyboard.KeyCodes.SPACE).on('down', fn)`; pointer `this.input.on('pointerdown', (p) => …)`; multi-touch `this.input.addPointer(2)`.
- **Tweens:** `this.tweens.add({ targets: obj, scale: 1, duration: 400, ease: 'Back.Out' })`.
- **Code-drawn art (the only art):** `const g = this.add.graphics(); g.fillStyle(0x6b4a2b).fillEllipse(32,16,64,32); g.generateTexture('mound', 64, 32); g.destroy(); this.add.image(x, y, 'mound');`. Canvas textures work too: `this.textures.createCanvas(key, w, h)`. **No image files, no sprite sheets, no AI or downloaded art.**
- **Scale FIT** keeps the 1280×720 world letterboxed in any WebView (Mac, iOS, Android).
- **Text:** `this.add.text(x, y, 'TeraformЯ', { fontFamily: 'Arial', fontSize: '24px', color: '#f1d09a' })`.
```ts
import Phaser from 'phaser';
class DigScene extends Phaser.Scene {
  constructor() { super('dig'); }
  create(): void {
    const g = this.add.graphics(); g.fillStyle(0x6b4a2b, 1).fillEllipse(32, 16, 64, 32);
    g.generateTexture('mound', 64, 32); g.destroy();
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      const m = this.add.image(p.x, p.y, 'mound').setScale(0.2);
      this.tweens.add({ targets: m, scale: 1, duration: 400, ease: 'Back.Out' });
    });
  }
}
new Phaser.Game({ type: Phaser.AUTO, width: 1280, height: 720, scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH }, scene: [DigScene] });
```

## 9. BLUEFACE API (hero v1) — FIXED move list and save format

- Stack: TypeScript (strict) + Phaser 4.2.1 + Vite. `dist-single/index.html` is one self-contained ~1.4 MB file (the Workshop project `blueface`).
- `const hero = new Blueface(scene, x, groundY, 0.92);`
- **Moves (fixed; do not add or rename):** `hero.idle()`, `hero.walk(-1|1)`, `hero.dig()`, `hero.cheer()`, `hero.takeThat()` (the axe morphs into a 2nd spade; pressing again morphs it back), plus `hero.setFacing('left'|'right')`, `hero.getAction()`, `hero.getWalkDir()`.
- Events: `hero.on('dig', ({x, y}) => { /* terraform here */ })`.
- **Save (fixed):** `hero.getState()` returns `{ v:1, name:'BLUEFACE', crown:'Я', position:{x,y}, facing, action, tool }`, and `hero.applyState(save)` restores it. `isBluefaceState(o)` guards it.
- The scene moves the hero while walking: `hero.x += hero.getWalkDir() * 150 * (dt/1000)`.
- Automation hook: `window.__BF = { scene, hero, state() }`.
- **Upgrades only replace drawing** (`parts.ts`, `clay.ts`, `palette.ts`). The move list and save shape stay the same.

## 10. The bridge rule (game ↔ native ↔ wallet)

- The game (TS/JS in the WebView) can **read** chain data (read-only `@solana/kit`) and can **propose** a wallet action as JSON, for example `{ "kind":"proposal", "action":"tip", "amount":"…", "purpose":"…" }`.
- The Swift/Kotlin thin wrappers pass proposals to the **native wallet**, which shows them to the Decider. **Signing happens only in native wallets**, never in game code and never in bots.
- Drafts that try to sign, hold keys, or call RPC/signing endpoints are refused on save.

## 11. AGENTS.md rules (from BLUEFACE, adapted for the Workshop)

1. The stack is fixed: TypeScript (strict) + Phaser 4, bundled, with no CDN.
2. Art is code-drawn only: Graphics/generateTexture or Canvas2D. No image files.
3. No keys, secrets, wallets, signing, network calls, or telemetry.
4. Keep the state small and JSON-safe (`name:'BLUEFACE'`, `crown:'Я'`). Bump `v` only if the shape changes, and only by Decider decision.
5. NonNuclear: propose (diff + preview) → Decider approves → apply. No force pushes, history deletion, or mass rewrites.
6. `npm run build` (strict typecheck) must pass before a TS change is called done. The in-app Workshop cannot run npm, so TS drafts are marked "compile on the Mac" until CoS builds them.
7. Only edit files inside the project folder.

## 12. NonNuclear propose / approve / apply (Workshop flow)

1. **Propose:** a bot runs `gamewrite …` (chat) or *Ask bot to draft* (Workshop → Drafts, author toggle ЯBOT / ЯMAX, face shown beside it). The draft is validated and saved to `game/workshop/drafts/<id>/`, and the ledger gets `propose`.
2. **Review:** the Decider opens the Workshop (`workshop` or `yabot://game/workshop`) → Drafts → reads the purpose, author, notes and diff → **Preview** (sandbox: local files only, network blocked).
3. **Approve & Apply:** a Decider tap plus confirm. The draft is re-validated, the ledger gets `approve`, a snapshot is written to `respawn/<stamp>-<project>/` (`snapshot`), the file is copied into `projects/<id>/<file>` (`apply`), and the Mind transcript gets `gamewrite-apply`.
4. **Respawn:** Workshop → Respawn → *Roll back* (Decider). The current state is snapshotted first, so a rollback can be undone too.
5. **Evolve along the way:** repeat. The ledger is the game's evolution history.

## 13. Honest limits (read before promising)

- The local Heart is a small 3B q4 model. On the Mac it gets up to ~320 new tokens for gamewrite. On the iPhone it gets 32 tokens (n_ctx 512), so iPhone drafts are almost always the **starter template**. Expect short, sometimes wrong code: the Decider previews everything. Larger features should come in through inline fenced code from stronger bots (CoS, Grok packets), still as drafts.
- The app cannot compile TypeScript, Swift or Kotlin. TS drafts need `npm run build` on the Mac, and Swift/Kotlin drafts need an app rebuild.
- JS/HTML/CSS/JSON/GLSL drafts can be previewed in-app. TS drafts show as text and a diff.
