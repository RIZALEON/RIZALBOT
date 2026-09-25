# PAN-OS-TILE SMART OBJECT 0.1

**Seat law:** one clay face · magnetism · resizable · offline core untouched.

## Identity
| Field | Value |
|-------|-------|
| Asset id | `pan_os_tile` |
| Face | 3D claymation OS tile (gold frame · purple clay · bolt-monster · corner plus) |
| Label (user-visible) | **ЯBOT** (exact; never `ЯBOT ABOMEGA`) |
| Doctrine | Magnetism — fixed slot, zero shove; same clay face on every seat |

## Mac / iOS
- **No** separate SmartObject / imageset named PanOS / pan_os_tile.
- OS tile **is** `AppIcon.appiconset` (icon_1024.png clay face).
- Magnetism for in-app clay buttons lives in ЯBAR / ClayComposer magnets (BtnSend, Bolte, Lab, …) — not a floating Pan OS widget.
- **Do not churn Swift** for this train; AppIcon already is the tile.

## Android (this seat)
| Seat | Wiring |
|------|--------|
| Launcher | `AndroidManifest` `android:icon` / `roundIcon` → `@mipmap/ic_launcher(_round)` adaptive |
| Adaptive bg | `@color/ic_launcher_background` deep purple `#39294B` (tile interior) |
| Adaptive fg | `@drawable/ic_launcher_fg_bleed` = `pan_os_tile` inset **-32%** (gold frame fills mask) |
| Smart drawable | `res/drawable-nodpi/pan_os_tile.png` — **white corners → full transparency** |
| Legacy mipmaps | Density PNGs composited on deep purple (no white plate) |
| In-app slot | No dedicated Home/ЯBAR tile slot yet (ЯBAR already magnet-full). Reuse `@drawable/pan_os_tile` anywhere an ImageView needs the OS face. |

## Contract for future magnets
```
ImageView / Coil / Glide  →  R.drawable.pan_os_tile
scaleType = fitCenter | centerInside
contentDescription = "ЯBOT"
Never flatten to a second face; never recolor gold frame.
```

## Refs
- `_staging/PAN-OS-TILE-ref.png`
- `_staging/PAN-OS-TILE-ref-yabot.jpg` (iOS App Library labeled ЯBOT)
- `_staging/PAN-OS-TILE-transparent.png` (master alpha)

## Standing
Offline core / heart.gguf / LlamaBridge untouched. Mac/iOS Swift untouched this train.
