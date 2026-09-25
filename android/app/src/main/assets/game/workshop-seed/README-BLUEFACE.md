# BLUEFACE · TeraformЯ — code-drawn hero (TypeScript + Phaser 4)

BLUEFACE is the claymation goblin terraformer from the reference video, rebuilt entirely **in code**:
every part (helmet, horns, ears, face, eyes, grin, tunic, epaulettes, arms, hands, belt, legs,
boots, axe/spade tool) is painted procedurally at startup into one Phaser CanvasTexture atlas.
No image files, fully offline.

## Run

```bash
npm install
npm run dev          # http://localhost:5173
```

## Build

```bash
npm run build        # typecheck + dist/ (multi-file) + dist-single/index.html (everything inlined)
```

* `dist/` — normal Vite build (serve over http).
* `dist-single/index.html` — one self-contained file (Phaser + game inlined, ~1.4 MB). Drop it into
  the app's game-door folder; it also works from `file://`.

## Controls

| Action | Keyboard | Touch |
|---|---|---|
| Walk | ← / → or A / D | ◀ ▶ (hold) |
| Dig / terraform | Space | DIG |
| Cheer | C | CHEER |
| "Yeah! Take that!" — axe morphs into a 2nd spade (press again to morph back) | T | TAKE THAT |

## Using the character

```ts
import { Blueface } from './character/Blueface';
const hero = new Blueface(scene, x, groundY, 0.92);
hero.idle(); hero.walk(1); hero.dig(); hero.cheer(); hero.takeThat(); hero.setFacing('left');
hero.on('dig', ({ x, y }) => { /* terraform the ground here */ });
const save = hero.getState();   // { v, name: 'BLUEFACE', crown: 'Я', position, facing, action, tool }
hero.applyState(save);
```

The scene moves the hero while walking (`hero.getWalkDir()`); the rig handles leg IK-free swing,
2-bone arm IK to the tool grips, auto foot grounding, blinking, breathing and grin pulses.

## Files

* `src/character/Blueface.ts` — rig + animations + state API
* `src/character/parts.ts` — procedural clay drawing for each body part
* `src/character/clay.ts` — clay shading helpers + atlas packer
* `src/character/palette.ts` — colors sampled from the reference frames (PIL)
* `src/character/state.ts` — `BluefaceState` type
* `src/main.ts` — demo scene (FIT scaling, keyboard + touch buttons)
* `scripts/shots.mjs` — headless Chromium screenshots + demo mp4 (`npm run shots`, needs ffmpeg)
* `scripts/compare.py` — reference vs render side-by-side (needs Pillow)

`window.__BF` exposes the scene/hero/state for automated checks.
