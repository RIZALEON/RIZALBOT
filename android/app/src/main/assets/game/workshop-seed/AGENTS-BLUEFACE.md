# AGENTS.md — rules for any AI / bot editing this repo

This is BLUEFACE, the hero of **Я Game / TeraformЯ**. Crown: **Я**.

1. **Stack is fixed: TypeScript (strict) + Phaser 4 only**, bundled with Vite. No other game engine,
   framework, or runtime. No CDN: Phaser is bundled so it runs offline in the app's web view
   (Mac, iOS, Android, web).
2. **Art is code-drawn only.** Every part is painted in `src/character/parts.ts` (Canvas2D inside a
   Phaser CanvasTexture atlas) or with Phaser Graphics/`generateTexture`. **No image files, no
   sprite sheets, no AI-generated art, no downloaded assets.** Colors come from `palette.ts`.
3. **No keys, secrets, wallets, signing or network calls** in this code. Nothing here touches
   crypto keys or signs anything. Don't add telemetry.
4. Keep `BluefaceState` (`src/character/state.ts`) small and JSON-safe: `name: 'BLUEFACE'`,
   `crown: 'Я'`. Bump `v` if you change its shape.
5. **NonNuclear change process:** *propose* (describe the diff + screenshots) → the **Decider
   approves** → then *apply*. No force pushes, no deleting history, no mass rewrites, no pushing to
   GitHub without the Decider's go-ahead.
6. Before you hand anything back: `npm run build` must pass (strict typecheck), then `npm run shots`
   and look at the PNGs yourself.
7. Only edit files inside this project folder.
