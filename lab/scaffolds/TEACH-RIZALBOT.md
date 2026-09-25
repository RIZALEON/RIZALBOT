# Lab scaffolds — teach note (RIZALBOT)

## Two foundational scaffolds (GRCh37, AncestryDNA V1.0 kit AncestryDNA_V1_20260909)

| Scaffold | Count | Role |
|----------|------:|------|
| **MICRO** | **680** | Phenotype / feature pins (`gnome-pins.json`). Pole1 `rs870124`, #43 Duffy `rs12075`, #680 `rs7350355` (X). No Y. |
| **MACRO** | **673703** | Living relatedness grid — autosomal chr1–22 SNPs with both alleles called (≠0). |

**Never average MICRO and MACRO.** They are two separate scores / grids.

## Base union (positions only)

`673703 + 17365 (X) + 860 (Y) + 3 PIN_ONLY = 691931`

Layer tags: `GRID`, `PIN+GRID`, `X`, `PIN+X`, `Y`, `PIN_ONLY`. Pin rsid wins on chrom:pos overlap. Chrom 25 PAR dropped. No genotypes invented. No Kennewick. No GRCh38 lift.

## Ghost chain

Establish markers (append via GhostChainLedger):

- `LAB_SCAFFOLD_MICRO_680`
- `LAB_SCAFFOLD_MACRO_673703`
- `LAB_SCAFFOLD_BASE_UNION_691931`

Seed lines: `ghost-chain-scaffold-establish.jsonl` → Application Support `ghost-chain.jsonl` (or ledger path Documents/ЯBOT uses).

## Paths

- Box build: `/workspace/lab-scaffolds/`
- Mac Lab: `/Users/rizal/Documents/ЯBOT/lab/scaffolds/`
- App www: `/Users/rizal/Desktop/ЯTOOLBOX/PROJECTR/ios/YaAim/www/` (`gnome-pins.json` + macro manifest / compact tsv)
- Optional localbuild: `/Users/rizal/Library/Developer/ЯBOT-localbuild/` under `lab/` or `www/`
- Swift stub: `swift/LabScaffolds.swift` (Documents/ЯBOT)
