import Foundation

/// Lab foundational scaffolds (GRCh37) — MICRO 680 + MACRO 673703.
/// Two scores; never averaged. Ghost markers registered on Lab open.
enum LabScaffolds {
    static let kit = "AncestryDNA_V1_20260909"
    static let build = "GRCh37"

    static let microMarker = "LAB_SCAFFOLD_MICRO_680"
    static let macroMarker = "LAB_SCAFFOLD_MACRO_673703"
    static let baseMarker = "LAB_SCAFFOLD_BASE_UNION_691931"

    static let microCount = 680
    static let macroCount = 673_703
    static let baseCount = 691_931

    /// Bundle resource names (copy beds/tsv/json into app target as needed).
    enum Resource {
        static let pinsJSON = "gnome-pins"
        static let macroTSVgz = "macro-scaffold"
        static let baseTSVgz = "base-scaffold"
        static let manifest = "SCAFFOLD-MANIFEST"
        static let locked = "LOCKED_COUNTS"
    }

    struct Pin: Codable {
        let n: Int
        let rsid: String
        let chrom: String
        let pos: Int
    }

    static func loadPinsFromBundle(_ bundle: Bundle = .main) -> [Pin]? {
        guard let url = bundle.url(forResource: Resource.pinsJSON, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Pin].self, from: data)
    }

    static func loadManifestFromBundle(_ bundle: Bundle = .main) -> [String: Any]? {
        guard let url = bundle.url(forResource: Resource.manifest, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    /// Call on Lab open. Parent wires GhostChainLedger.append.
    static func ghostEstablishPayloads(pinsHash: String, macroBedHash: String, baseBedHash: String) -> [[String: Any]] {
        [
            ["op": "establish", "bio": microMarker, "hash": pinsHash, "kit": kit, "build": build],
            ["op": "establish", "bio": macroMarker, "hash": macroBedHash, "kit": kit, "build": build],
            ["op": "establish", "bio": baseMarker, "hash": baseBedHash, "kit": kit, "build": build],
        ]
    }

    /// Register ghost markers if ledger callback provided. Does not invent genotypes.
    static func registerOnLabOpen(appendGhost: ([String: Any]) -> Void, pinsHash: String, macroBedHash: String, baseBedHash: String) {
        for rec in ghostEstablishPayloads(pinsHash: pinsHash, macroBedHash: macroBedHash, baseBedHash: baseBedHash) {
            appendGhost(rec)
        }
    }
}
