# ЯMANUAL app hardcode — iOS (0.1)

**Stamp:** 2026-09-23 · Decider HARDCODE via CoS → Rizalbot iOS seat

## Law
ЯMANUAL is the **one and only** fixed editable / openable / organizable manual in the apps.
Leaf contracts (USER-MANUAL.md, YA-GHOST, LAB-MANUAL desk, …) remain **sources**. User-facing open path = **YAMANUAL** only.

## iOS seat
- `ManualPDFLocator.fileName` = `YAMANUAL.pdf`
- Resolve order: Bundle `YAMANUAL` / `YAMANUAL-0.1` → MACHINE MIND → `Documents/ЯBOT/mind/books/` → app Documents twin
- Clay / Manual landing export names → `YAMANUAL.pdf`
- Base command `manual` / `yamanual` / `яmanual` → `ManualPDFLocator.openFixedManual()`
- Extension `lab manual` → Lab desk PDF (unchanged leaf)

## Bundle
`ЯBOT/YAMANUAL.pdf` (+ `YAMANUAL-0.1.pdf`) copied from `mind/books/YAMANUAL-0.1.pdf`
